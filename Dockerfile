FROM ubuntu:22.04

LABEL org.opencontainers.image.title="CODAL micro:bit V2 LLVM Toolchain"
LABEL org.opencontainers.image.description="Docker image with the LLVM toolchain to build micro:bit CODAL."
LABEL org.opencontainers.image.source="https://github.com/microbit-foundation/docker-codal-microbit-v2-llvm"

# Install dependencies from apt
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends wget git build-essential cmake ninja-build && \
    apt-get install -y --no-install-recommends python3 python3-pip && \
    update-alternatives --install /usr/bin/python python /usr/bin/python3 1 && \
    apt-get autoremove -y && apt-get clean -y && rm -rf /var/lib/apt/lists/*

# Installing Arm GCC
WORKDIR /opt/
RUN cd /opt/ && \
    wget -q https://developer.arm.com/-/media/Files/downloads/gnu-rm/10-2020q4/gcc-arm-none-eabi-10-2020-q4-major-x86_64-linux.tar.bz2 && \
    echo "8312c4c91799885f222f663fc81f9a31  gcc-arm-none-eabi-10-2020-q4-major-x86_64-linux.tar.bz2" >> MD5SUM && \
    md5sum -c MD5SUM && \
    rm MD5SUM && \
    tar -xf gcc-arm-none-eabi-10-2020-q4-major-x86_64-linux.tar.bz2 && \
    rm gcc-arm-none-eabi-10-2020-q4-major-x86_64-linux.tar.bz2
ENV PATH $PATH:/opt/gcc-arm-none-eabi-10-2020-q4-major/bin

# Installing LLVM
# TODO: add these steps


# GCC paths obtained running "echo | arm-none-eabi-gcc -xc++ -E -mcpu=cortex-m4 -mthumb -mfpu=fpv4-sp-d16 -mfloat-abi=softfp -v -"
# TODO: Add more info here, doesn't matter if it's long
ARG GCC_INCLUDES="-I/opt/gcc-arm-none-eabi-10-2020-q4-major/bin/../lib/gcc/arm-none-eabi/10.2.1/../../../../arm-none-eabi/include/c++/10.2.1 -I/opt/gcc-arm-none-eabi-10-2020-q4-major/bin/../lib/gcc/arm-none-eabi/10.2.1/../../../../arm-none-eabi/include/c++/10.2.1/arm-none-eabi/thumb/v7e-m+fp/softfp -I/opt/gcc-arm-none-eabi-10-2020-q4-major/bin/../lib/gcc/arm-none-eabi/10.2.1/../../../../arm-none-eabi/include/c++/10.2.1/backward -I/opt/gcc-arm-none-eabi-10-2020-q4-major/bin/../lib/gcc/arm-none-eabi/10.2.1/include -I/opt/gcc-arm-none-eabi-10-2020-q4-major/bin/../lib/gcc/arm-none-eabi/10.2.1/include-fixed -I/opt/gcc-arm-none-eabi-10-2020-q4-major/bin/../lib/gcc/arm-none-eabi/10.2.1/../../../../arm-none-eabi/include"
ENV GCC_INCLUDES_ENV=$GCC_INCLUDES


# Download and build codal with arm-none-eabi-gcc
RUN cd /home && \
    git clone https://github.com/lancaster-university/microbit-v2-samples microbit-v2-samples-gcc && \
    cd microbit-v2-samples-gcc && \
    python -c "import pathlib; f = pathlib.Path('codal.json'); f.write_text(f.read_text().replace('master', 'v0.2.59'))" && \
    cat codal.json && \
    python build.py


# Download and build codal with llvm
# TODO: Finish this
RUN cd /home && \
    git clone https://github.com/Johnn333/microbit-v2-samples-clang microbit-v2-samples-llvm && \
    cd microbit-v2-samples-llvm && \
    # TODO: These steps are needed until target-locked.json in codal-microbit-v2-clang is updated to point to specific commit hashses
    mkdir libraries && cd libraries && \
    git clone https://github.com/Johnn333/codal-microbit-v2-clang codal-microbit-v2 && \
    git clone https://github.com/Johnn333/codal-core-clang codal-core  && \
    git clone https://github.com/Johnn333/codal-nrf52-clang codal-nrf52 && \
    git clone https://github.com/Johnn333/codal-microbit-nrf5sdk-clang codal-microbit-nrf5sdk && \
    cd codal-microbit-nrf5sdk && \
    git checkout -b clang-compatibility origin/clang-compatibility && \
    cd ../codal-nrf52 && \
    git checkout -b clang-compatiability origin/clang-compatiability && \
    cd ../..
    # python build.py


WORKDIR /home/

# We need the additional flags to be added as part of the entry point in array form
# This is because these flags are needed for the build, and the users has to add
# aditional arguments to point to the file to compile.
# Docker ARG or ENV don't expand when using this format, only when using the shell
# ENTRYPOINT echo "$ENV_VARIABLE"     <-- This expands and cannot take extra user arguments
# ENTRYPOINT ["echo", $ENV_VARIABLE]  <-- This does not expands, but does take extra user arguments
ENTRYPOINT ["echo", \
            "-I/opt/gcc-arm-none-eabi-10-2020-q4-major/bin/../lib/gcc/arm-none-eabi/10.2.1/../../../../arm-none-eabi/include/c++/10.2.1 -I/opt/gcc-arm-none-eabi-10-2020-q4-major/bin/../lib/gcc/arm-none-eabi/10.2.1/../../../../arm-none-eabi/include/c++/10.2.1/arm-none-eabi/thumb/v7e-m+fp/softfp -I/opt/gcc-arm-none-eabi-10-2020-q4-major/bin/../lib/gcc/arm-none-eabi/10.2.1/../../../../arm-none-eabi/include/c++/10.2.1/backward -I/opt/gcc-arm-none-eabi-10-2020-q4-major/bin/../lib/gcc/arm-none-eabi/10.2.1/include -I/opt/gcc-arm-none-eabi-10-2020-q4-major/bin/../lib/gcc/arm-none-eabi/10.2.1/include-fixed -I/opt/gcc-arm-none-eabi-10-2020-q4-major/bin/../lib/gcc/arm-none-eabi/10.2.1/../../../../arm-none-eabi/include" \
]
