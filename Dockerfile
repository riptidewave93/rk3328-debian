# Our AIO builder docker file
FROM debian:12

RUN mkdir /repo
COPY ./scripts/docker/setup_mkimage.sh /setup_mkimage.sh

RUN apt-get update && apt-get install -yq \
    autoconf \
    bc \
    binfmt-support \
    bison \
    bsdextrautils \
    build-essential \
    cpio \
    debootstrap \
    debhelper \
    device-tree-compiler \
    dosfstools \
    fakeroot \
    flex \
    genext2fs \
    git \
    kmod \
    kpartx \
    libconfuse-common \
    libconfuse-dev \
    libncurses-dev \
    libssl-dev \
    lvm2 \
    mtools \
    parted \
    pkg-config \
    python3-dev \
    python3-pyelftools \
    python3-setuptools \
    qemu-utils \
    qemu-user-static \
    rsync \
    swig \
    unzip \
    wget \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && /setup_mkimage.sh \
    && rm /setup_mkimage.sh