FROM debian:buster-slim AS build-base

# WARNING: ARGS get cleared after FROM, so this list is worthless. Define these
#          below: https://github.com/moby/moby/issues/34129
#
#
# ARG SLIRP4NETNS_VERSION=v0.4.1
# ARG CONMON_VERSION=v2.0.0
# ARG LIBFUSE_VERSION=fuse-3.6.2
# ARG FUSE_OVERLAYFS_VERSION=v0.6.1
# ARG RUNC_VERSION=v1.0.0-rc8
# ARG LIBPOD_VERSION=v1.5.1
# ARG CNI_VERSION=v0.8.2

# Build base: automake through libcap-dev is specific to slirp4netns
RUN true && \
    apt-get update && apt-get --no-install-recommends -y install \
      libglib2.0-dev=2.58.3-2 \
      git=1:2.20.1-2 \
      ca-certificates=20190110 \
      make=4.2.1-1.2 \
      gcc=4:8.3.0-1 \
    && rm -rf /var/lib/apt/lists/*

FROM build-base AS conmon

ARG CONMON_VERSION=v2.0.0
# Build conman: monitors active containers
RUN git clone https://github.com/containers/conmon /conmon
WORKDIR /conmon
RUN git checkout "${CONMON_VERSION}" && make

# /conmon/bin/conman

# Build slirp4netns: allows networking in rootless containers
FROM build-base AS slirp4netns

ARG SLIRP4NETNS_VERSION=v0.4.1
RUN true && \
    apt-get update && apt-get --no-install-recommends -y install \
      automake=1:1.16.1-4 \
      autotools-dev=20180224.1 \
      libseccomp-dev=2.3.3-4 \
      libcap-dev=1:2.25-2 \
    && rm -rf /var/lib/apt/lists/* && \
    git clone https://github.com/rootless-containers/slirp4netns

WORKDIR /slirp4netns
RUN git checkout "${SLIRP4NETNS_VERSION}" && \
    ./autogen.sh && ./configure && make

# /slirp4netns/slirp4netns
# /slirp4netns/slirp4netns.1

# Build fuse-overlayfs so we don't have to VFS in rootless mode
FROM build-base AS fuse-overlayfs

ARG LIBFUSE_VERSION=fuse-3.6.2
ARG FUSE_OVERLAYFS_VERSION=v0.6.1
# glibc-static was listed...
RUN true && \
    apt-get update && apt-get --no-install-recommends -y install \
      automake=1:1.16.1-4 \
      autoconf=2.69-11 \
      meson=0.49.2-1 \
      ninja-build=1.8.2-1 \
      clang=1:7.0-47 \
      udev=241-5 \
      libfuse3-dev=3.4.1-1 \
    && rm -rf /var/lib/apt/lists/* && \
    git clone https://github.com/libfuse/libfuse

WORKDIR /libfuse

RUN true && \
    git checkout "${LIBFUSE_VERSION}"

WORKDIR /libfuse/build

RUN true && \
    LDFLAGS="-lpthread" meson --prefix /usr -D default_library=static .. && \
    ninja && \
    ninja install

WORKDIR /fuse-overlayfs

RUN true && \
    git clone https://github.com/containers/fuse-overlayfs . && \
    git checkout "${FUSE_OVERLAYFS_VERSION}" && \
    sh autogen.sh && \
    LIBS="-ldl" LDFLAGS="-static" ./configure --prefix /usr && \
    make && \
    make install

# Libfuse
#
# Installing lib/libfuse3.a to /usr/lib64
# Installing util/fusermount3 to /usr/bin
# Installing util/mount.fuse3 to /usr/sbin
# Installing /libfuse/include/fuse.h to /usr/include/fuse3
# Installing /libfuse/include/fuse_common.h to /usr/include/fuse3
# Installing /libfuse/include/fuse_lowlevel.h to /usr/include/fuse3
# Installing /libfuse/include/fuse_opt.h to /usr/include/fuse3
# Installing /libfuse/include/cuse_lowlevel.h to /usr/include/fuse3
# Installing /libfuse/doc/fusermount3.1 to /usr/share/man/man1
# Installing /libfuse/doc/mount.fuse3.8 to /usr/share/man/man8
# Installing /libfuse/build/meson-private/fuse3.pc to /usr/lib64/pkgconfig
# Running custom install script '/libfuse/util/install_helper.sh /etc /usr/bin /lib/udev/rules.d true'

# Fuse-overlayfs
#
# /fuse-overlayfs/fuse-overlayfs.1
# /fuse-overlayfs/fuse-overlayfs


# Pull runc: It's golang, so we just need to grab the correct binary
FROM scratch AS runc
ARG RUNC_VERSION=v1.0.0-rc8
ADD https://github.com/opencontainers/runc/releases/download/${RUNC_VERSION}/runc.amd64 /runc

# Build podman - minimum requirement will be glibc 2.24
FROM golang:1.12.9-stretch AS podman

ARG LIBPOD_VERSION=v1.5.1

# golang-go \
      #libbtrfs-dev= \
RUN apt-get update && apt-get --no-install-recommends -y install \
      git=1:2.11.0-3+deb9u4 \
      libc6-dev=2.24-11+deb9u4 \
      pkg-config=0.29-4+b1 \
      btrfs-progs=4.7.3-1 \
      go-md2man=1.0.6+ds-1+b1 \
      iptables=1.6.0+snapshot20161117-6 \
      libassuan-dev=2.4.3-2 \
      libdevmapper-dev=2:1.02.137-2 \
      libglib2.0-dev=2.50.3-2 \
      libgpgme-dev=1.8.0-3+b2 \
      libgpg-error-dev=1.26-2 \
      libostree-dev=2016.15-5 \
      libprotobuf-dev=3.0.0-9 \
      libprotobuf-c-dev=1.2.1-2 \
      libseccomp-dev=2.3.1-2.1+deb9u1 \
      libselinux1-dev=2.6-3+b3 \
      libsystemd-dev=232-25+deb9u11 \
      uidmap=1:4.4-4.1 \
    && rm -rf /var/lib/apt/lists/* && \
    echo 'uidmap must be installed on host' && \
    git clone https://github.com/containers/libpod/ "$GOPATH/src/github.com/containers/libpod"

WORKDIR $GOPATH/src/github.com/containers/libpod

RUN true && \
    git checkout "${LIBPOD_VERSION}" && \
    make BUILDTAGS="selinux seccomp apparmor"

FROM busybox:1.31.0-glibc AS cni
ARG CNI_VERSION=v0.8.2
ADD https://github.com/containernetworking/plugins/releases/download/${CNI_VERSION}/cni-plugins-linux-amd64-${CNI_VERSION}.tgz /
WORKDIR /cni
RUN tar xzf /cni-plugins-linux-amd64-${CNI_VERSION}.tgz

# Use busybox/glibc for this. Small and has same libc as host
FROM busybox:1.31.0-glibc
ARG LIBPOD_BASE=/go/src/github.com/containers/libpod
COPY --from=conmon         /conmon/bin/conmon                                     /pd/usr/bin/
COPY --from=slirp4netns    /slirp4netns/slirp4netns                               /pd/usr/bin/
COPY --from=slirp4netns    /slirp4netns/slirp4netns.1                             /pd/usr/share/man/man1/
COPY --from=fuse-overlayfs /usr/lib/libfuse3.a                                    /pd/usr/lib/
COPY --from=fuse-overlayfs /usr/bin/fusermount3                                   /pd/usr/bin/
COPY --from=fuse-overlayfs /usr/sbin/mount.fuse3                                  /pd/usr/sbin/
COPY --from=fuse-overlayfs /usr/include/fuse3/fuse.h                              /pd/usr/include/
COPY --from=fuse-overlayfs /usr/include/fuse3/fuse_common.h                       /pd/usr/include/fuse3/
COPY --from=fuse-overlayfs /usr/include/fuse3/fuse_lowlevel.h                     /pd/usr/include/fuse3/
COPY --from=fuse-overlayfs /usr/include/fuse3/fuse_opt.h                          /pd/usr/include/fuse3/
COPY --from=fuse-overlayfs /usr/include/fuse3/cuse_lowlevel.h                     /pd/usr/include/fuse3/
COPY --from=fuse-overlayfs /usr/share/man/man1/fusermount3.1                      /pd/usr/share/man/man1/
COPY --from=fuse-overlayfs /usr/share/man/man8/mount.fuse3.8                      /pd/usr/share/man/man8/
COPY --from=fuse-overlayfs /usr/lib/pkgconfig/fuse3.pc                            /pd/usr/lib/pkgconfig/
COPY --from=fuse-overlayfs /fuse-overlayfs/fuse-overlayfs.1                       /pd/usr/share/man/man1/
COPY --from=fuse-overlayfs /fuse-overlayfs/fuse-overlayfs                         /pd/usr/bin/
COPY --from=runc           /runc                                                  /pd/usr/bin/
COPY --from=podman         ${LIBPOD_BASE}/bin/podman                              /pd/usr/bin/
COPY --from=podman         ${LIBPOD_BASE}/bin/podman-remote                       /pd/usr/bin/
COPY --from=podman         ${LIBPOD_BASE}/docs/links/*                            /pd/usr/share/man/man1/
COPY --from=podman         ${LIBPOD_BASE}/completions/zsh/_podman                 /pd/usr/share/zsh/site-functions/
COPY --from=podman         ${LIBPOD_BASE}/completions/bash/podman                 /pd/usr/share/bash-completion/completions/
COPY --from=podman         ${LIBPOD_BASE}/cni/87-podman-bridge.conflist           /pd/etc/cni/net.d/
COPY --from=podman         ${LIBPOD_BASE}/test/policy.json                        /pd/etc/containers/
COPY --from=podman         ${LIBPOD_BASE}/test/registries.conf                    /pd/etc/containers/
COPY --from=cni            /cni/*                                                 /pd/usr/libexec/cni/
COPY                       rootless-install.sh                                    /
WORKDIR /pd
RUN chmod 777 /pd/usr/bin/runc
ENTRYPOINT ["/rootless-install.sh"]
# On host:
  # apt-get install -y \
  # libapparmor-dev
