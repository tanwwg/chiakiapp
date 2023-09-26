# What is this?

MacOS native chiaki app. Hardware video decoding and native GUI.

## Building pre-reqs

Install required libraries via homebrew in their default locations. The xcode project expects them there.
    
    brew install openssl
    brew install opus
    brew install protobuf-c    
    brew install cmake

Install python dependencies (python3)

    pip3 install protobuf

## Building

First, build the chiaki library submodule:

    mkdir chiaki/build && cd chiaki/build
    OPENSSL_ROOT_DIR=/opt/homebrew/opt/openssl cmake .. -DCHIAKI_ENABLE_FFMPEG_DECODER=OFF -DCHIAKI_ENABLE_GUI=OFF
    make

Then you should be able to build the project in xcode after configuring code signing.

