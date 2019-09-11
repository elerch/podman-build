Podman builder
==============

This dockerfile sets up a deterministic multi-stage build for podman and
related components for use in a rootless environment. This includes:

* [Podman (libpod)](https://podman.io)
* [conmon](https://github.com/containers/conmon): Podman uses this to monitor
  containers
* [slirp4netns](https://github.com/rootless-containers/slirp4netns): Enables
  rootless networking
* [libfuse](https://github.com/libfuse/libfuse) and
  [fuse-overlayfs](https://github.com/containers/fuse-overlayfs/): Enables use
  of overlayfs in rootless mode. VFS is not ideal so this is pretty much a
  requirement for rootless containers IMHO
* [runc](https://github.com/opencontainers/runc): This is simply downloaded
  from linux amd64 release. This actually launches the downloaded containers
* [cni plugins](https://github.com/containernetworking/plugins): Standard
  plugins for container networking. Used by podman to setup container networks

Usage
-----

After cloning the repo, run ``docker build -t podman-builder .``. After the
multi-stage build completes (this could take a while), run
``docker run --rm -v $HOME:/home podman-build $(id -u) $(id -g)``. This
command will mount your home directory into the container, allowing the
rootless-install.sh entrypoint to copy all the files into place in your
$HOME/.local path. Note that $HOME/.local/bin/fusermount3 will be owned by
root, executable with setuid bit set. This is normal/expected and needed
for overlayfs to work on rootless containers.

Alternatively, this build has been completed and the results uploaded as
a tarball as a release on github. Beware that files in the tarball will
overwrite files on extraction, but if you're looking for the easy button,
download the podman.tgz from the repo release and ``tar -C $HOME xzf podman.tgz``

Other Host Setup
----------------

This should be done by the script, but it's reasonable to double-check
that $HOME/.local/bin/fusermount3 is owned by root with setuid. If you copy
files around later outside the process above, this may be necessary:

```sh
sudo chown root:root fusermount3
sudo chmod 4755 fusermount3
```

Debian Buster:

The following command will install packages required for Debian 10 (buster).
This is currently (2019-09-05) the only mainstream distro with linux
kernel >=4.18 in stable (4.19) to enable rootless containers with overlayfs

``sudo apt install libgpgme11 libglib2.0-0 uidmap``

At this point, conmon should work. If not, you'll get an unintelligible error
from podman. You can check with:

``conmon --version``

Podman Proper:

Podman needs to use unprivileged user namespaces in order to work in rootless
mode. In debian, this can be enabled with:

```sh
sudo sysctl kernel.unprivileged_userns_clone=1 # running system
echo kernel.unprivileged_userns_clone=1 | sudo tee /etc/sysctl.d/00-local-userns.conf # make changes persistent
```

Podman should work at this point, just use as you would docker. If not, reboot

If there's something wrong, check out:

* /etc/subuid
* /etc/subgid

They should have your user with 65k subids defined
Also, the commands "newuidmap" and "newuidmap" should exist, be root owned
and have setuid/setgid respectively
