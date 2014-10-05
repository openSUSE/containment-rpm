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
* ``update-package`` can be used with different BS projects,
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
