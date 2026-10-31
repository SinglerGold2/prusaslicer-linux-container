# Builds a PrusaSlicer binary for Linux that can be called from a script, a service
# or a container.
#
#   docker build --build-arg GUI=OFF -t prusaslicer-cli:2.9.6 .
#   docker build --build-arg GUI=ON  -t prusaslicer-gui:2.9.6 .
#
# The image is a build environment, not something to run. Copy the binary and the
# resources directory out of it:
#
#   id=$(docker create prusaslicer-cli:2.9.6)
#   docker cp "$id:/src/PrusaSlicer/build/src/prusa-slicer" ./prusa-slicer
#   docker cp "$id:/src/PrusaSlicer/resources" ./resources
#   docker rm "$id"

FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
# The dependency build extracts archives with non-ASCII names.
ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8

ARG PRUSASLICER_TAG=version_2.9.6
ARG GUI=OFF

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

WORKDIR /src
RUN git clone --depth 1 --branch "${PRUSASLICER_TAG}" \
        https://github.com/prusa3d/PrusaSlicer.git

# Dependencies first, statically linked, as the upstream guide describes.
WORKDIR /src/PrusaSlicer/deps
RUN mkdir -p build
WORKDIR /src/PrusaSlicer/deps/build
RUN cmake .. -DDEP_WX_GTK3=ON
RUN make -j"$(nproc)"

# Then PrusaSlicer itself. GUI=OFF only works up to 2.9.x; 3.0 refuses to configure
# without a GUI ("Non-GUI build is not supported yet").
WORKDIR /src/PrusaSlicer
RUN mkdir -p build
WORKDIR /src/PrusaSlicer/build
RUN if [ "$GUI" = "ON" ]; then \
        cmake .. -DSLIC3R_STATIC=1 -DSLIC3R_GTK=3 -DSLIC3R_PCH=OFF \
            -DCMAKE_PREFIX_PATH=/src/PrusaSlicer/deps/build/destdir/usr/local; \
    else \
        cmake .. -DSLIC3R_GUI=OFF -DSLIC3R_STATIC=1 -DSLIC3R_PCH=OFF \
            -DCMAKE_PREFIX_PATH=/src/PrusaSlicer/deps/build/destdir/usr/local; \
    fi
RUN make -j"$(nproc)"

RUN ./src/prusa-slicer --help > /dev/null && echo "binary built and executable"
