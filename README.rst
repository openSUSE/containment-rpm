=====================================================================
                      openSUSE/containment-rpm
=====================================================================

`openSUSE/containment-rpm`_ is the authoritative source for
`Devel:StudioOnline:containment_common_packages/containment-rpm`_.
`image.spec.in`, `kiwi_post_run` and `containment-rpm.spec.in` are
the actual sources and metasources, `update-package` takes care of
updating the Build Service package from Github.

.. _openSUSE/containment: https://github.com/openSUSE/containment-rpm
.. _Devel:StudioOnline:containment_common_packages/containment-rpm:
  https://build.suse.de/package/show?package=containment-rpm&project=Devel:StudioOnline:containment_common_packages

Hacking
=======

* Commit desired changes and *tag* them, push to Github.
* Run `update-package` with the tag as its argument.
* `update-package` can be used with different BS projects,
  see `update-package -h`.

Example
=======

::

  git clone git@github.com:openSUSE/containment-rpm.git
  cd containment-rpm
  vi kiwi_post_run
  git commit -a
  git tag -a v42.69
  git push origin master v42.69
  ./update-package -p home:rneuhauser v42.69
