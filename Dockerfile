#builder for the image
FROM debian:bookworm-slim AS builder
SHELL ["/bin/bash", "-c"]

RUN echo 'Acquire::Retries 5;' > /etc/apt/apt.conf.d/99-retry && \
    apt update && DEBIAN_FRONTEND=noninteractive apt install -y --no-install-recommends git curl python3 sudo cmake ninja-build pkg-config clang llvm lld nasm libsdl2-dev libepoxy-dev libssl-dev python3-dev libstdc++-12-dev squashfs-tools squashfuse

WORKDIR /tmp
# pinned to 2605 for stability
RUN git clone --recurse-submodules --branch FEX-2605 --depth 1 https://github.com/FEX-Emu/FEX.git

WORKDIR /tmp/FEX
#CMAKE exclusive to ampere CPUs
RUN mkdir Build && cd Build && \
        CC=clang CXX=clang++ cmake -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_BUILD_TYPE=Release -DUSE_LINKER=lld -DENABLE_LTO=True -DBUILD_TESTS=False -DENABLE_ASSERTIONS=False \
        -DCMAKE_C_FLAGS="-mcpu=neoverse-n1 -O3 -fno-math-errno" -DCMAKE_CXX_FLAGS="-mcpu=neoverse-n1 -O3 -fno-math-errno" -DCMAKE_INTERPROCEDURAL_OPTIMIZATION=True \
        -G Ninja .. && ninja && ninja install
# might downgrade to -O2 if enough issues come up

#actual image properties
FROM debian:bookworm-slim
SHELL ["/bin/bash", "-c"]

RUN echo 'Acquire::Retries 5;' > /etc/apt/apt.conf.d/99-retry && \
    apt update && DEBIAN_FRONTEND=noninteractive apt install -y --no-install-recommends curl python3 sudo locales unzip libsdl2-2.0-0 libepoxy0 libssl3 libstdc++6 squashfs-tools squashfuse gosu jq procps && rm -rf /var/lib/apt/lists/*

RUN echo "de_DE.UTF-8 UTF-8" > /etc/locale.gen && \
    locale-gen de_DE.UTF-8
ENV LANG=de_DE.UTF-8
ENV LANGUAGE=de_DE:de
ENV LC_ALL=de_DE.UTF-8
ENV TZ=Europe/Berlin
RUN ln -snf /usr/share/zoneinfo/Europe/Berlin /etc/localtime && echo Europe/Berlin > /etc/timezone

COPY --from=builder /usr/bin/FEX* /usr/bin/
COPY --from=builder /usr/lib/aarch64-linux-gnu/libFEXCore* /usr/lib/aarch64-linux-gnu/
COPY --from=builder /usr/share/fex-emu /usr/share/fex-emu

RUN useradd -m steam

USER root

RUN mkdir -p /cs2-data /home/steam/.fex-emu && \
    chown -R 1000:1000 /cs2-data /home/steam/.fex-emu

COPY --chown=steam:steam --chmod=755 init-server.sh /home/steam/init-server.sh

USER steam

WORKDIR /home/steam/Steam
RUN curl -sqL "https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz" | tar zxvf - && chown -R steam:steam /home/steam

WORKDIR /home/steam
ENTRYPOINT ["/home/steam/init-server.sh"]
