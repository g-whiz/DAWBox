# base image: common deps for final image and for building yabridge
FROM quay.io/toolbx/ubuntu-toolbox:latest as base

#Let ubuntu/debian know we're running in noninteractive mode. (Aka "No questions, please!")
ARG DEBIAN_FRONTEND=noninteractive

RUN lsb_release -a

#Install wine-staging by setting up PPA
RUN dpkg --add-architecture i386; apt update -y; mkdir -pm755 /etc/apt/keyrings; \
	wget -O /etc/apt/keyrings/winehq-archive.key https://dl.winehq.org/wine-builds/winehq.key; \
	wget -NP /etc/apt/sources.list.d/ https://dl.winehq.org/wine-builds/ubuntu/dists/noble/winehq-noble.sources; \
	apt update -y; apt upgrade -y; apt install -y --install-recommends winehq-staging;

FROM base AS yabridge-build

# install deps to build yabridge
RUN apt install -y gcc meson pkg-config libxcb1-dev libdbus-1-dev wine-staging-dev cargo

# Build yabridge from source (current release is missing bug-fixes present in master)
RUN mkdir prefix
RUN export WINEPREFIX=/prefix

RUN git clone https://github.com/robbert-vdh/yabridge.git yabridge
WORKDIR /yabridge

RUN meson setup build --buildtype=release --cross-file=cross-wine.conf --unity=on --unity-size=1000
RUN ninja -C build
RUN strip build/*.so

# copy build artifacts into release dir
RUN mkdir lib
RUN cp build/*.so build/*.exe lib
RUN cp CHANGELOG.md README.md lib

# build yabridgectl and copy to export dir
RUN mkdir bin
RUN cd tools/yabridgectl; \
    cargo build --release; \
    strip target/release/yabridgectl; \
    cp target/release/yabridgectl ../../bin;


# Build final image
FROM base AS final

#Install winetricks + dependencies
RUN apt install -y cabextract winetricks zenity

# todo: copy built yabridge from yabridge-build image
RUN mkdir /usr/local/share/yabridge
COPY --from=yabridge-build /yabridge/lib/* /usr/lib
COPY --from=yabridge-build /yabridge/bin/* /usr/bin

#ENV PATH="${PATH}:/usr/local/share/yabridge"

#Install pipewire to ensure connection to audio server.
RUN apt install -y pipewire
