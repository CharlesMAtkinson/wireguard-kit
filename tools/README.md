Hook scripts
============

Copy tools/git-store-meta/hooks-for-wireguard-kit/* to .git/hooks

create_tarballs.sh
==================

Before running create_tarballs.sh
* Ensure source/usr/lib/wireguard-kit/version contains the new version
  Example
  1v0.0
* Ensure the working tree is tagged with the current wireguard-kit version, example 1.0.0

To run create_tarballs.sh,
* Change directory to the root of the git working tree
* Run tools/create_tarballs.sh -c tools/create_tarballs.conf

The tarballs are created in the parent directory
