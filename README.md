# PrusaSlicer for Linux as a single binary

Builds a self-contained PrusaSlicer executable with Docker. The result is a plain
binary you can call from a script, a service or any other place where a GUI is not
available and a Flatpak runtime cannot be used.

Prusa stopped attaching Linux binaries to the GitHub releases with 2.8.1. From 2.9
on, the Linux download is a Flatpak. If you need a real executable instead, this
recipe builds one from the official source.

## What you get

```
prusa-slicer        about 120 MB, statically linked against its own dependencies
resources/          profiles, fonts, icons and localisation
```

The build follows the upstream instructions ("How to build - Linux et al"): the
`deps` project is compiled first, then PrusaSlicer is linked against it statically.
Only a handful of system libraries remain dynamic - see *Runtime libraries* below.

## Requirements

```
Docker
about 10 GB free disk space
about 40 to 60 minutes on 16 threads
```

## Build

```sh
docker build -t prusaslicer-builder:2.9.6 .
```

The Dockerfile pins the tag `version_2.9.6`. Change it for another version.

## Get the binary out

The build image is disposable; copy the two things you need:

```sh
id=$(docker create prusaslicer-builder:2.9.6)
docker cp "$id:/src/PrusaSlicer/build/src/prusa-slicer" ./prusa-slicer
docker cp "$id:/src/PrusaSlicer/resources" ./resources
docker rm "$id"
```

## Run

PrusaSlicer looks for its `resources` directory relative to the binary, so keep the
layout:

```
/opt/prusaslicer/prusa-slicer
/opt/prusaslicer/resources/
```

Then:

```sh
/opt/prusaslicer/prusa-slicer --help
/opt/prusaslicer/prusa-slicer --export-gcode -o out.gcode model.3mf
```

If you must place the resources elsewhere, point `SLIC3R_RESOURCES` at them.

## Runtime libraries

The binary is statically linked against Boost, wxWidgets, OpenCASCADE, TBB, CGAL and
the rest of the `deps` bundle, but it still links a few system libraries. On
Ubuntu 24.04 these packages are enough:

```sh
apt-get install -y \
    libgl1 libglx-mesa0 libegl1 libdrm2 \
    libgtk-3-0t64 libwebkit2gtk-4.1-0 \
    libhidapi-hidraw0
```

Without them the loader fails with messages like `libGL.so.1: cannot open shared
object file`, then `libgtk-3.so.0`, then `libwebkit2gtk-4.1.so.0`, then
`libhidapi-hidraw.so.0`. Installing them one at a time also works, but doing it in
one step saves three rounds.

## Things that cost time while writing this

```
Locale          the build container must run with LANG=C.UTF-8
                otherwise extracting the Boost archive fails with
                "Pathname cannot be converted from UTF-8 to current locale"

unzip           the dependency build extracts .zip archives and needs it

automake        building MPFR runs autoreconf, which fails without it
libtool         same step
bison, flex     pulled in by several dependencies
libhidapi-dev   configure stops with "hidapi-libusb not found" without it

read-only path  --export-3mf writes next to the input file, so exporting from a
                read-only mount fails; copy the input to a writable directory first
```

## Placing objects

Slicing from the command line uses the project's own coordinates. With the default
profile the bed origin sits in a corner, not in the middle, so a model built around
the origin ends up partly outside:

```
All objects are outside of the print volume.
```

Either save the project in PrusaSlicer - which places objects correctly - or put the
geometry into the positive quadrant. A 20 mm cube centred at (100, 100) with z from
0 to 20 slices as expected.

## A note on 3MF input

A 3MF has to be a PrusaSlicer project to keep its printer and print settings. A
hand-made 3MF with the same geometry loads, but tools that check for the application
metadata will refuse it. Export the project from PrusaSlicer once and reuse it as a
template.

## License

PrusaSlicer is licensed under the AGPL-3.0. This repository only contains build
instructions; the source is at <https://github.com/prusa3d/PrusaSlicer>.

If you distribute the resulting binary, the AGPL applies: ship the licence, and
offer the corresponding source - the version you built from, which is the tag named
in the Dockerfile.
