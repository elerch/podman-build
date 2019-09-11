#!/bin/sh

if [ ! -d /home/.local ]; then
  echo 'Must mount home directory as /home (docker run -v $HOME:/home ...)' >&2
  exit 1
fi

if [ ! "$(id -u)" = '0' ]; then
  echo 'This container *must* be run as root due to fusermount3 needing setuid' >&2
  exit 1
fi

if [ $# -ne 2 ]; then
  echo 'Need uid and gid passed on the command line' >&2
  exit 1
fi
cd /pd || exit 2 # Should never happen
chown -R "$1":"$2" ./*
printf 'Copying (overwriting) podman and associated data into $HOME/.local...'
cp -R usr/* /home/.local
chown 0:0 /home/.local/bin/fusermount3
chmod 755 /home/.local/bin/fusermount3
chmod u+s /home/.local/bin/fusermount3
echo 'done'

mkdir -p /home/.config/containers
cp etc/containers/* /home/.config/containers/
chown -R "$1":"$2" /home/.config/containers

# See https://www.scrivano.org/2018/07/13/fuse-overlayfs-moved-to-github-com-containers/
kernelmajor=$(uname -r |cut -d. -f1)
kernelminor=$(uname -r |cut -d. -f2)

overlaysupported=1
[ "$kernelmajor" -le 4 ] && overlaysupported=0
[ "$kernelmajor" -eq 4 ] && [ "$kernelminor" -lt 18 ] && overlaysupported=0
if [ $overlaysupported -eq 0 ]; then
  echo '***********************************************************************'
  echo 'WARNING: You should upgrade to linux kernel 4.18 or higher, otherwise'
  echo '         fuse support in user namespaces is not available and therefore'
  echo '         fuse-overlayfs will not work with podman. VFS is your only'
  echo '         option in this circumstance, and VFS is pretty suboptimal'
  echo '         Podman may not be worth using on this system, so we have not'
  echo '         bothered configuring it for VFS, but should you like to do so,'
  echo '         take a look at $HOME/.config/containers/storage.conf'
  echo '***********************************************************************'
fi
echo 'You need to install uidmap on this host'
