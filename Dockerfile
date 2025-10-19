# Build args to specify branch & version of wine to install
ARG WINE_VERSION=9.21
ARG WINE_BRANCH=staging

#Let ubuntu/debian know we're running in noninteractive mode. (Aka "No questions, please!")
ARG DEBIAN_FRONTEND=noninteractive

# base image: common deps for final image and for building yabridge
FROM quay.io/toolbx/ubuntu-toolbox:latest as base
SHELL ["/bin/bash", "-c"]

ARG WINE_VERSION
ARG WINE_BRANCH
ARG DEBIAN_FRONTEND

RUN lsb_release -a

# Set up wine-staging PPA
RUN dpkg --add-architecture i386; \
    apt-get update -y; \
    apt-get upgrade -y; \
    mkdir -pm755 /etc/apt/keyrings; \
    wget -O /etc/apt/keyrings/winehq-archive.key https://dl.winehq.org/wine-builds/winehq.key; \
    wget -NP /etc/apt/sources.list.d/ https://dl.winehq.org/wine-builds/ubuntu/dists/noble/winehq-noble.sources; \
    apt-get update -y;



# Install wine
RUN export codename=$(shopt -s nullglob; awk '/^deb https:\/\/dl\.winehq\.org/ { print $3; exit 0 } END { exit 1 }' /etc/apt/sources.list /etc/apt/sources.list.d/*.list || awk '/^Suites:/ { print $2; exit }' /etc/apt/sources.list /etc/apt/sources.list.d/wine*.sources); \
    export suffix=$(dpkg --compare-versions "$WINE_VERSION" ge 6.1 && ((dpkg --compare-versions "$WINE_VERSION" eq 6.17 && echo "-2") || echo "-1")); \
    apt-get install --install-recommends -y "wine-$WINE_BRANCH-amd64"="$WINE_VERSION~$codename$suffix" "wine-$WINE_BRANCH-i386"="$WINE_VERSION~$codename$suffix" "wine-$WINE_BRANCH"="$WINE_VERSION~$codename$suffix" "winehq-$WINE_BRANCH"="$WINE_VERSION~$codename$suffix"; 

# Prevent Wine from being udated
RUN sudo apt-mark hold winehq-staging;

# Build yabridge from source (why: latest release is missing bug-fixes present in master)
FROM base AS yabridge-build

ARG WINE_VERSION
ARG WINE_BRANCH
ARG DEBIAN_FRONTEND

# install deps to build yabridge
RUN export codename=$(shopt -s nullglob; awk '/^deb https:\/\/dl\.winehq\.org/ { print $3; exit 0 } END { exit 1 }' /etc/apt/sources.list /etc/apt/sources.list.d/*.list || awk '/^Suites:/ { print $2; exit }' /etc/apt/sources.list /etc/apt/sources.list.d/wine*.sources); \
    export suffix=$(dpkg --compare-versions "$WINE_VERSION" ge 6.1 && ((dpkg --compare-versions "$WINE_VERSION" eq 6.17 && echo "-2") || echo "-1")); \
    apt-get install --install-recommends -y "wine-$WINE_BRANCH-dev"="$WINE_VERSION~$codename$suffix"

RUN apt-get install -y gcc meson pkg-config libxcb1-dev libdbus-1-dev cargo


# Build arg to specify yabridge branch/tag to checkout when building it. Defaults to HEAD of master branch.
ARG YABRIDGE_VERSION=master
RUN git clone --branch $YABRIDGE_VERSION https://github.com/robbert-vdh/yabridge.git yabridge
WORKDIR /yabridge

RUN meson setup build --buildtype=release --cross-file=cross-wine.conf --unity=on --unity-size=1000
RUN ninja -C build
RUN strip build/*.so

# copy build artifacts into release dir
RUN mkdir lib
RUN mkdir bin
RUN cp build/libyabridge*.so lib
RUN cp build/yabridge-host.exe build/yabridge-host.exe.so bin

# build yabridgectl and copy to export dir
RUN cd tools/yabridgectl; \
    cargo build --release; \
    strip target/release/yabridgectl; \
    cp target/release/yabridgectl ../../bin;

# Assemble final image using the yabridge binaries that we just built
FROM base AS final

ARG DEBIAN_FRONTEND

#Install winetricks + dependencies
RUN apt-get install -y cabextract winetricks zenity

# todo: copy built yabridge from yabridge-build image
RUN mkdir /usr/local/share/yabridge
COPY --from=yabridge-build /yabridge/lib/* /usr/lib
COPY --from=yabridge-build /yabridge/bin/* /usr/bin

#Install pipewire to ensure connection to audio server.
RUN apt-get install -y pipewire

ARG BITWIG_VERSION
RUN if [[ -z "$BITWIG_VERSION" ]] ; then \
      echo "Skipping Bitwig install (no version specified)."; \
    else \
      cd /tmp; \
      export BITWIG_DEB_URL=$(printf "https://www.bitwig.com/dl/Bitwig%%20Studio/%s/installer_linux/" $BITWIG_VERSION); \
      curl -L "$BITWIG_DEB_URL" -o bitwig.deb; \
      apt-get install -y --install-recommends ./bitwig.deb; \
      rm bitwig.deb; \
    fi

