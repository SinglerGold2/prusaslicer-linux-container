# PrusaSlicer for Linux, built to be called

Builds PrusaSlicer from source with Docker and produces a binary you can run from a
script, a service or a container - no desktop, no Flatpak runtime.

Prusa stopped attaching Linux binaries to the GitHub releases with 2.8.1. From 2.9 on
the Linux download is a Flatpak, which needs a desktop session and a runtime. This
recipe builds a plain executable instead.

Two variants come out of the same Dockerfile:

```
variant   gui   size     needs                                   use
cli       off   ~70 MB   libpng16-16                             called by a program
gui       on    ~118 MB  libpng16, GTK3, WebKit, GL, hidapi      also opens a window
```

The `cli` variant is the one to take if something else calls the binary. It links only
`libc`, `libm`, `libstdc++`, `libz` and `libpng16` - nothing else.

Note: the CLI variant exists for 2.9.x. PrusaSlicer 3.0 refuses to configure without a
GUI (`Non-GUI build is not supported yet` in `src/CMakeLists.txt`), so this recipe stays
on the 2.9 line for the small variant.

## Ready-made build

A 2.9.6 CLI build is attached to the releases of this repository:

```
prusa-slicer-2.9.6-linux-x86_64.tar.gz
  prusa-slicer-2.9.6/bin/prusa-slicer
  prusa-slicer-2.9.6/resources/...
```

Unpack it wherever the calling program expects it, for example under `/srv/prusaslicer`,
and point the program at `.../prusa-slicer-2.9.6/bin/prusa-slicer`. The binary and the
resources directory have to stay together - see *Put it where the caller expects it*.

Building it yourself from the source below produces the same result and is the way to get
a different version.

## Requirements

```
Docker
about 10 GB free disk space for the dependency build
40 to 90 minutes on 16 threads
```

## Build

```sh
# CLI variant, 2.9.6 - no GUI, smallest set of runtime libraries
docker build --build-arg GUI=OFF -t prusaslicer-cli:2.9.6 .

# GUI variant, also usable as a command line tool
docker build --build-arg GUI=ON -t prusaslicer-gui:2.9.6 .

# another 2.9 release
docker build --build-arg GUI=OFF --build-arg PRUSASLICER_TAG=version_2.9.5 `
             -t prusaslicer-cli:2.9.5 .
```

## Get the files out

The image is a build environment, not something to run. Copy the binary and the
resources directory out of it:

```sh
id=$(docker create prusaslicer-cli:2.9.6)
docker cp "$id:/src/PrusaSlicer/build/src/prusa-slicer" ./prusa-slicer
docker cp "$id:/src/PrusaSlicer/resources" ./resources
docker rm "$id"
```

Keep the two together. PrusaSlicer looks for `resources` next to the binary
(`<binary>/../resources`); if you have to separate them, set `SLIC3R_RESOURCES`.

## Put it where the caller expects it

A program that runs inside a container can only call a file inside that container, so a
read-only bind mount is the usual way:

```yaml
services:
  your-service:
    volumes:
      - /srv/prusaslicer:/opt/prusaslicer:ro
```

The host side looks like this:

```
/srv/prusaslicer/bin/prusa-slicer
/srv/prusaslicer/resources/...
```

Inside the container the binary is then `/opt/prusaslicer/bin/prusa-slicer` - and that
path, not the host path, is the one to configure wherever the calling program asks for
the executable.

If your program runs on the host instead, put the same two items under
`/opt/prusaslicer/` and call `/opt/prusaslicer/bin/prusa-slicer`.

## Call it

```sh
/opt/prusaslicer/bin/prusa-slicer --help
/opt/prusaslicer/bin/prusa-slicer --export-gcode -o out.gcode project.3mf
```

The GUI variant accepts the same arguments and only opens a window when called without
them.

## Runtime libraries

```
cli    libpng16-16
gui    libpng16-16, libgl1, libglx-mesa0, libegl1, libdrm2, libgtk-3-0t64,
       libwebkit2gtk-4.1-0, libhidapi-hidraw0
```

On Ubuntu 24.04:

```sh
apt-get install -y libpng16-16                                        # cli
apt-get install -y libpng16-16 libgl1 libglx-mesa0 libegl1 libdrm2 \
                   libgtk-3-0t64 libwebkit2gtk-4.1-0 libhidapi-hidraw0 # gui
```

Missing libraries announce themselves one after another while loading: `libGL.so.1`,
then `libgtk-3.so.0`, then `libwebkit2gtk-4.1.so.0`, then `libhidapi-hidraw.so.0`. The
CLI variant never gets that far.

## Things that cost time while writing this

```
locale          build with LANG=C.UTF-8 and LC_ALL=C.UTF-8, otherwise extracting the
                Boost archive fails with "Pathname cannot be converted from UTF-8 to
                current locale"

unzip           the dependency build extracts .zip archives and needs it

automake        building MPFR runs autoreconf, which fails without it
libtool         same step
bison, flex     pulled in by several dependencies
libhidapi-dev   configure stops with "hidapi-libusb not found" without it

read-only path  --export-3mf writes next to the input file, so exporting from a
                read-only mount fails; copy the input to a writable directory first
```

## Placing objects

With the default profile the bed origin sits in a corner, not in the middle. Geometry
built around the origin ends up partly outside and slicing stops with:

```
All objects are outside of the print volume.
```

Save the project in PrusaSlicer - it places objects correctly - or put the geometry into
the positive quadrant. A 20 mm cube at (100, 100) with z from 0 to 20 slices as
expected.

## A note on 3MF input

A 3MF should be a PrusaSlicer project so it keeps its printer and print settings. A
hand-made 3MF with the same geometry loads, but programs that check the application
metadata inside the file will refuse it.

## License

PrusaSlicer is licensed under the AGPL-3.0. This repository only contains build
instructions; the source is at <https://github.com/prusa3d/PrusaSlicer>.

If you distribute a binary built from it, the AGPL applies: ship the licence and offer
the corresponding source - the version you built from, which is the tag named in the
Dockerfile.


