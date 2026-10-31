# Builds a self-contained PrusaSlicer binary for Linux.
#
# The result is not meant to run as a container. Copy the binary and the
# resources directory out of the image and use them on the host:
#
#   id=$(docker create prusaslicer-builder:2.9.6)
#   docker cp "$id:/src/PrusaSlicer/build/src/prusa-slicer" ./prusa-slicer
#   docker cp "$id:/src/PrusaSlicer/resources" ./resources
#   docker rm "$id"

FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
# The dependency build extracts archives with non-ASCII names.
ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8

RUN apt-get update && apt-get install -y --no-install-recommends \
        git \
        build-essential \
        autoconf \
        automake \
        libtool \
        libtool-bin \
        cmake \
        libglu1-mesa-dev \
        libgtk-3-dev \
        libdbus-1-dev \
        libwebkit2gtk-4.1-dev \
        libhidapi-dev \
        texinfo \
        unzip \
        bison \
        flex \
        gettext \
        patch \
        pkg-config \
        ca-certificates \
        curl \
    && rm -rf /var/lib/apt/lists/*

ARG PRUSASLICER_TAG=version_2.9.6

WORKDIR /src
RUN git clone --depth 1 --branch "${PRUSASLICER_TAG}" \
        https://github.com/prusa3d/PrusaSlicer.git

# Dependencies first, statically linked, as the upstream guide describes.
WORKDIR /src/PrusaSlicer/deps
RUN mkdir -p build
WORKDIR /src/PrusaSlicer/deps/build
RUN cmake .. -DDEP_WX_GTK3=ON
RUN make -j"$(nproc)"

# Then PrusaSlicer itself.
WORKDIR /src/PrusaSlicer
RUN mkdir -p build
WORKDIR /src/PrusaSlicer/build
RUN cmake .. -DSLIC3R_STATIC=1 -DSLIC3R_GTK=3 -DSLIC3R_PCH=OFF \
        -DCMAKE_PREFIX_PATH=/src/PrusaSlicer/deps/build/destdir/usr/local
RUN make -j"$(nproc)"

RUN /src/PrusaSlicer/build/src/prusa-slicer --help > /dev/null \
    && echo "binary built and executable"
