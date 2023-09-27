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

# Installing LLVM. Current version as of writing is "Ubuntu clang version 14.0.0-1ubuntu1.1 Target: x86_64-pc-linux-gnu"

ENV DEBIAN_FRONTEND=noninteractive
RUN apt update && apt install -y clang lld llvm && rm -rf /var/lib/apt/lists/*

# GCC paths obtained running:       "echo | arm-none-eabi-gcc -xc++ -E -mcpu=cortex-m4 -mthumb -mfpu=fpv4-sp-d16 -mfloat-abi=softfp -v -"
# We can fully extract these using: "echo | arm-none-eabi-gcc -xc++ -E -mcpu=cortex-m4 -mthumb -mfpu=fpv4-sp-d16 -mfloat-abi=softfp -v - 2>&1 | 
#                                          sed -n '/#include <...> search starts here:/,/End of search list/ {/#include <...> search starts here:/! {/End of search list/!p}}' | 
#                                          sed 's/^/-I/' | tr '\n' ' '"
# ARM-GCC Provides a multilib system which locates all header/library locations given the arhitecture on the command line, in this case we give the microbit build flags and view the return. 
# These need to be passed to clang (latching onto the ARM-GCC multilib system), so it can find the correct include paths for compilation otherwise it will fail. An example of what these will look like is below.
# Dynamically extracting these paths from the command above may be one of the reasons this breaks in the future upon updating ARM-GCC.
ARG GCC_INCLUDES="-I/opt/gcc-arm-none-eabi-10-2020-q4-major/bin/../lib/gcc/arm-none-eabi/10.2.1/../../../../arm-none-eabi/include/c++/10.2.1 -I/opt/gcc-arm-none-eabi-10-2020-q4-major/bin/../lib/gcc/arm-none-eabi/10.2.1/../../../../arm-none-eabi/include/c++/10.2.1/arm-none-eabi/thumb/v7e-m+fp/softfp -I/opt/gcc-arm-none-eabi-10-2020-q4-major/bin/../lib/gcc/arm-none-eabi/10.2.1/../../../../arm-none-eabi/include/c++/10.2.1/backward -I/opt/gcc-arm-none-eabi-10-2020-q4-major/bin/../lib/gcc/arm-none-eabi/10.2.1/include -I/opt/gcc-arm-none-eabi-10-2020-q4-major/bin/../lib/gcc/arm-none-eabi/10.2.1/include-fixed -I/opt/gcc-arm-none-eabi-10-2020-q4-major/bin/../lib/gcc/arm-none-eabi/10.2.1/../../../../arm-none-eabi/include"
ENV GCC_INCLUDES_ENV=$GCC_INCLUDES
# NOTE: The above variables ^^^, relating to include paths are not being used. The current system should be more dynamic than this.

# Default GCC codal build.
RUN cd /home && \
    git clone https://github.com/lancaster-university/microbit-v2-samples microbit-v2-samples-gcc && \
    cd microbit-v2-samples-gcc && \
    python -c "import pathlib; f = pathlib.Path('codal.json'); f.write_text(f.read_text().replace('master', 'v0.2.59'))" && \
    cat codal.json && \
    python build.py

# Download and build codal with llvm
RUN cd /home && \
    # Adds CMake clang definitions for ease. PR pending.
    git clone https://github.com/Johnn333/microbit-v2-samples-clang microbit-v2-samples-llvm && \
    cd microbit-v2-samples-llvm && \
    git switch clang-compatibility && \
    # TODO: These steps are needed until target-locked.json in codal-microbit-v2-clang is updated to point to specific commit hashses
    mkdir libraries && cd libraries && \
    git clone https://github.com/lancaster-university/codal-microbit-v2 codal-microbit-v2 && \
    git clone https://github.com/lancaster-university/codal-core codal-core  && \
    git clone https://github.com/microbit-foundation/codal-microbit-nrf5sdk codal-microbit-nrf5sdk && \
    git clone https://github.com/lancaster-university/codal-nrf52 codal-nrf52 && \
    cd codal-nrf52 && \
    git submodule init && \ 
    git submodule update && \
    cd .. && \
    
    cd /home/microbit-v2-samples-llvm/libraries/codal-microbit-v2 && \
    
    # Changing target-locked.json flags. 
    # Create a script to:
    # Extract GCC paths, save to $INCLUDE_FLAGS
    # Replace ARM_GCC with Clang to build instead with LLVM.
    # Replace GCC_ARM with CLANG (Note this is different to above).
    # Remove -Wl,--no-wchar-size-warning flag from linker_flags.
    # Add --target=arm-none-eabi to cpu_opts
    # Add $INCLUDE_FLAGS to cpp_flags & c_flags. Add -fshort-enums to both.
    echo '#!/bin/bash' > target-update.sh && \
    echo 'INCLUDE_FLAGS=$(echo | arm-none-eabi-gcc -xc++ -E -mcpu=cortex-m4 -mthumb -mfpu=fpv4-sp-d16 -mfloat-abi=softfp -v - 2>&1 | \
                   sed -n "/#include <...> search starts here:/,/End of search list/ {/#include <...> search starts here:/! {/End of search list/!p}}" | \
                   sed "s/ /-I/" | \
                   tr "\\n" " ")' >> target-update.sh && \
    echo 'sed -i "s/ARM_GCC/CLANG/g" target-locked.json' >> target-update.sh && \
    echo 'sed -i "s/GCC_ARM/CLANG/g" target-locked.json' >> target-update.sh && \
    echo 'sed -i "s/-Wl,--no-wchar-size-warning //g" target-locked.json' >> target-update.sh && \
    echo 'sed -i "s/\"cpu_opts\": \"\(.*\)\",/\"cpu_opts\": \"--target=arm-none-eabi \\1\",/" target-locked.json' >> target-update.sh && \
    # Choosing an obscure character (=) as the delimiter here. We dont know what $INCLUDE_FLAGS may contatin
    echo 'sed -i "s=\"cpp_flags\": \"\(.*\)\",=\"cpp_flags\": \"-fshort-enums $INCLUDE_FLAGS\\1\",=" target-locked.json' >> target-update.sh && \
    echo 'sed -i "s=\"c_flags\": \"\(.*\)\",=\"c_flags\": \"-fshort-enums $INCLUDE_FLAGS\\1\",=" target-locked.json' >> target-update.sh && \
    
    # Give script required permissions, Run it.
    chmod +x target-update.sh && \
    ./target-update.sh && \
    
    cd /home/microbit-v2-samples-llvm && \
    # BLE Test, left in incase wanting to replicate.
    # sed -i 's/out_of_box_experience();/ble_test();/' source/main.cpp && \
    # rm codal.json && \
    # mv codal.ble.json codal.json && \
    # sed -i 's/"MICROBIT_BLE_PARTIAL_FLASHING" : 1/"MICROBIT_BLE_PARTIAL_FLASHING" : 0/' codal.json && \
    mkdir build && cd build && \
    # Run MinSizeRel for highest optimisation and also dump compile_commands.json (For use in clangd browser.)
    cmake ../ -DCMAKE_BUILD_TYPE=MinSizeRel -DCMAKE_EXPORT_COMPILE_COMMANDS=1 && \
    make || true 
    # This will have failed upto this point as the link stage will not work. But libraries have been generated.
    
RUN cd /home/microbit-v2-samples-llvm/build && \
    # Extract the verbose link command 
    sed -i 's/<CMAKE_CXX_COMPILER>/arm-none-eabi-g++ -v/' ../utils/cmake/toolchains/CLANG/compiler-flags.cmake && \
    make > link_cmd.txt 2>&1 || true && \
    
    echo '#!/bin/bash' > link-exec.sh && \
    # Copy line containing "collect2", this invokes arm-none-eabi-ld, this will be our command
    grep 'collect2' link_cmd.txt | sed -n '/collect2/{p;q;}' >> link-exec.sh && \
    sed -i '0,/\/collect2/s/\/[^ ]*\/collect2/ld.lld/' link-exec.sh && \
    # Objcopy to produce final hex
    echo 'llvm-objcopy -O ihex MICROBIT MICROBIT.hex' >> link-exec.sh && \
    
    chmod +x link-exec.sh && \
    ./link-exec.sh 

RUN cd /home/ && \
    # Extract include directories
    echo '#!/bin/bash' > package-script.sh && \
    echo 'INCLUDE_DIRS=$(echo | arm-none-eabi-gcc -xc++ -E -mcpu=cortex-m4 -mthumb -mfpu=fpv4-sp-d16 -mfloat-abi=softfp -v - 2>&1 | \
                   sed -n "/#include <...> search starts here:/,/End of search list/ {/#include <...> search starts here:/! {/End of search list/!p}}" | \
                   tr "\\n" " ")' >> package-script.sh && \
    echo 'LIBRARY_PATH=$(echo | arm-none-eabi-gcc -xc++ -E -mcpu=cortex-m4 -mthumb -mfpu=fpv4-sp-d16 -mfloat-abi=softfp -v - 2>&1 | \
                   sed -n "s/^LIBRARY_PATH=\\(.*\\)/\\1/p" | \
                   sed "s/:/ /g")' >> package-script.sh && \
    echo 'tar cf archive.tar $INCLUDE_DIRS $LIBRARY_PATH' >> package-script.sh && \

    chmod +x package-script.sh && \
    ./package-script.sh 

WORKDIR /home/

# We need the additional flags to be added as part of the entry point in array form
# This is because these flags are needed for the build, and the users has to add
# aditional arguments to point to the file to compile.
# Docker ARG or ENV don't expand when using this format, only when using the shell
# ENTRYPOINT echo "$ENV_VARIABLE"     <-- This expands and cannot take extra user arguments
# ENTRYPOINT ["echo", $ENV_VARIABLE]  <-- This does not expands, but does take extra user arguments
#ENTRYPOINT ["echo", \
#            "-I/opt/gcc-arm-none-eabi-10-2020-q4-major/bin/../lib/gcc/arm-none-eabi/10.2.1/../../../../arm-none-eabi/include/c++/10.2.1 -I/opt/gcc-arm-none-eabi-10-2020-q4-major/bin/../lib/gcc/arm-none-eabi/10.2.1/../../../../arm-none-eabi/include/c++/10.2.1/arm-none-eabi/thumb/v7e-m+fp/softfp -I/opt/gcc-arm-none-eabi-10-2020-q4-major/bin/../lib/gcc/arm-none-eabi/10.2.1/../../../../arm-none-eabi/include/c++/10.2.1/backward -I/opt/gcc-arm-none-eabi-10-2020-q4-major/bin/../lib/gcc/arm-none-eabi/10.2.1/include -I/opt/gcc-arm-none-eabi-10-2020-q4-major/bin/../lib/gcc/arm-none-eabi/10.2.1/include-fixed -I/opt/gcc-arm-none-eabi-10-2020-q4-major/bin/../lib/gcc/arm-none-eabi/10.2.1/../../../../arm-none-eabi/include" \
#]
