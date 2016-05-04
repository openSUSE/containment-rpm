=====================================================================
                      openSUSE/containment-rpm
=====================================================================

This repository provides files which facilitate the building (via the
`Open Build Service`_) of *containment rpms*.  A containment rpm is an
rpm package which contains one or more files generated as the result
of another package build within the same Build Service.  `.iso` files,
`.qcow2` images, and Vagrant `.box` files are all typical examples of
files contained within a containment rpm.

.. _`Open Build Service`: http://openbuildservice.org/



"Customers"
===========

Users of a version of this repository include:

- SUSE Studio, via the `Devel:StudioOnline:containment_common_packages/containment-rpm`_
  project.  For more information, see
  https://github.com/SUSE/studio/wiki/Containment-guidelines
  and https://github.com/SUSE/studio/tree/master/containment-rpm.

- SUSE Cloud, via the `Devel:Cloud:Shared:11-SP3:Update`_ project.

However the code is not yet being properly shared and co-maintained.

.. _Devel:StudioOnline:containment_common_packages/containment-rpm:
  https://build.suse.de/package/show?package=containment-rpm&project=Devel:StudioOnline:containment_common_packages
.. _Devel:Cloud:Shared:11-SP3:Update:
  https://build.suse.de/package/show/home:aspiers:branches:Devel:Cloud:Shared:11-SP3:Update/containment-rpm


Contents
========

* ``containment-rpm.spec.in`` is the template for the spec file which
  enables kiwi build environments to build containment rpms.
* ``kiwi_post_run`` is the hook which gets executed at the end of the
  kiwi image building process.  This script will wrap the image
  newly built by kiwi inside a containment rpm, and move it to the
  right location so that the Build Service will consider it a build
  artefact which can be published or used in other builds.
* ``image.spec.in`` is the spec file used by ``kiwi_post_run`` to build
  the containment rpm.


Hacking
=======

* Commit desired changes and *tag* them, push to Github.
* Run ``update-package`` with the tag as its argument.
* ``update-package`` can be used with different BS projects;
  see ``update-package -h``.


Example
-------

::

  git clone git@github.com:openSUSE/containment-rpm.git
  cd containment-rpm
  vi kiwi_post_run
  git commit -a
  git tag -a v42.69
  git push origin master v42.69
  ./update-package -p home:rneuhauser v42.69


Explaining the magic
====================

Everything starts with the user creating a package (in the build service
terminology, we are not talking about `.rpm` files) that contains all the KIWI
sources required to build the appliance.

The build service will look at these files, figure out the operating system
of the target and provision a build VM of the same type. To make it clear, if
the user uploaded the sources of a SLE11 SP3 appliance then the build service
is going to provision a SLE11 SP3 virtual machine to run the build inside of
it.

The build service will install all the packages required to run KIWI. It will
also download all the packages required by the appliance inside of the build
system. Then it will start the KIWI process like a normal KIWI user would do.
However once KIWI successfully completes the creation of the appliance the build
service is going to trigger a post build hook.

The post build hook will look for a file named `kiwi_post_run` located inside
of the `/usr/lib/build` directory. If the file exists and is executable then
the build service will invoke it. The `kiwi_post_run` script is where we
trigger the build of a new rpm containing the output of the kiwi process.

Obviously we must make the `kiwi_post_run` file available on the build host. The
solution is simple: create a package containing our script plus other resources
and ask the build service to install this package inside of the build environment.
The package containing the post build hook is usually called `containment-rpm`.

The package contains basically two files:

* The post build script (`kiwi_post_run`): it can be written in any language
  you want. If you use an interpreted language make sure to add it as a
  runtime dependency inside of the `containment-rpm` spec file.
* The `.spec` file used to build the package containing the output of the kiwi
  build. This file is usually a template which is later customized by the
  `kiwi_post_run` script to hold the right values (e.g.: the build version).

This is basically all you need to know.

How to prepare a project on the build service
=============================================

It is recommended to have a build service project dedicated to building
the Docker images.

The project must have at least two repositories:

* A KIWI repository, this is called 'images' by default by the build service.
* A repository to build the containment-rpm-docker binary.

If you plan to build a docker images for different version of SLE then you have
to make sure you build the containment rpm also for these targets. You have to
do that because the build host will have the same OS of the target (see previous
section).

You need to edit the project config: `osc meta -e prjconf` and make sure you
have something like that:

::

  %if "%_repository" == "images"
  Type: kiwi
  Repotype: rpm-md
  Patterntype: none
  Required: containment-rpm-docker
  %endif

We changed `Repotype` because the repository is going to have also the rpm
containing the output produced by KIWI.

We added the `Required` statement to have the `containment-rpm-docker` and all
its dependencies installed inside of the build environment used by the build
service.

Next we need to edit the project metadata: `osc meta -e prj`. We have to add
the repository containing the `containment-rpm` to the list of repositories
available by the `images` target at build time.

::

  <repository name="images">
    <path project="Devel:Docker:Images" repository="SLE_12"/>
    <arch>x86_64</arch>
  </repository>

So in the end the project will have just two packages (again, build service
terminology not `.rpm` files):

* `my-appliance`: this is where the KIWI sources are placed.
* `containment-rpm`: this is the package containing the script called by the
  post build hook.

As you can notice there is no definition of the package containing the output
of the KIWI process. Whenever the `my-appliance` package is built the rpm
containing its output is going to be created. Note well: this rpm is going
to be published by the build service inside of the `images` repository.


Using a special kiwi version
----------------------------

If you want to use a special version of KIWI to build your images you can either
have a `kiwi` package inside of your project or you can reference the `kiwi`
package from another repository.

Custom kiwi package inside of the project
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

This requires you to copy/link the `kiwi` package from somewhere to your project.

Then you have to add your repository to the list of repositories available for the
`images` one. This is what we have already done previously to make it possible to
install the `containment-rpm` inside of the build environment:

::

  <repository name="images">
    <path project="Devel:Docker:Images" repository="SLE_12"/>
    <arch>x86_64</arch>
  </repository>

kiwi package from an external project
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

This is the only sane way to have a recent version of KIWI on an old system like
SLE11 SP3.

First of all we have to make edit the project metadata: `osc meta -e prj`.

Add the path to the project containing the `kiwi` package to the `images` repository:

::

  <repository name="images">
    <path project="openSUSE.org:Virtualization:Appliances" repository="SLE_12"/>
    <path project="Devel:Docker:Images" repository="SLE_12"/>
    <arch>x86_64</arch>
  </repository>

Then add the same repository to your KIWI source file (the `.kiwi` file).

