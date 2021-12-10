#!/bin/sh
#-xe

helpFunction()
{
   echo ""
   echo "Usage: $0 -s PLATFORM -a ARCHITECTURES -t DEPLOYMENT_TARGET -o OUTPUT_DIR [-l SYMLINK_PATH] [-d]"
   echo -e "\t-s \"iphoneos\" or \"iphonesimulator\""
   echo -e "\t-a CPU architecture(s). E.g. to specify both arm64 and x84_64 architetures: \"arm64 x86_64\""
   echo -e "\t-t Minimum deployment target. E.g. 14.1 or 15.0"
   echo -e "\t-f Deployment target clang flag name. E.g. 'mios-simulator-version-min' or 'miphoneos-version-min'"
   echo -e "\t-o The directory into which to place the build artefacts"
   echo -e "\t-o Optional. If present, a symlink will be create at that path that points to the directory containing the `lib` `share` and `include ` directories"
   echo -e "\t-d Optional flag. When set, debug information is enabled"
   exit 1 # Exit script after printing help
}


# information on how getopts works: https://stackoverflow.com/a/18414407/2358592
# key info: getopts will look for the letters specified. A colon indicates the
# flag is expected to have an argument
while getopts "s:a:t:f:c:o:l:d" opt
do
   case "$opt" in
      s ) SDK="$OPTARG" ;;
      a ) ARCHS="$OPTARG" ;;
      t ) MIN_DEPLOYMENT_TARGET="$OPTARG" ;;
      f ) DEPLOYMENT_TARGET_FLAG_NAME="$OPTARG" ;;
      c ) LIB_SRC_DIR="$OPTARG" ;;
      o ) OUTPUT_DIR="$OPTARG" ;;
      l ) SYMLINK_PATH="$OPTARG" ;;
      d ) DEBUG=1 ;;
      ? ) helpFunction ;; # Print helpFunction in case parameter is empty
   esac
done

# Print helpFunction in case parameters are empty
if [ -z "$SDK" ] || [ -z "$ARCHS" ] || [ -z "$MIN_DEPLOYMENT_TARGET" ] || [ -z "$DEPLOYMENT_TARGET_FLAG_NAME" ] || [ -z "$LIB_SRC_DIR" ] || [ -z "$OUTPUT_DIR" ]
then
   echo "Some or all of the required parameters are empty. These are the required parameters and the values I got:";
    echo "-s: $SDK"
    echo "-a: $ARCHS"
    echo "-t: $MIN_DEPLOYMENT_TARGET"
    echo "-f: $DEPLOYMENT_TARGET_FLAG_NAME"
    echo "-c: $LIB_SRC_DIR"
    echo "-o: $OUTPUT_DIR"
    
   helpFunction
   exit 1
#else
#    echo "All required parameters set!";
#    echo "SDK=$SDK"
#    echo "ARCHS=$ARCHS"
#    echo "MIN_DEPLOYMENT_TARGET=$MIN_DEPLOYMENT_TARGET"
#    echo "DEPLOYMENT_TARGET_FLAG_NAME=$DEPLOYMENT_TARGET_FLAG_NAME"
#    echo "LIB_SRC_DIR: $LIB_SRC_DIR"
#    echo "OUTPUT_DIR=$OUTPUT_DIR"
#    echo "[DEBUG]=$DEBUG"
fi

doMake()
{
    make clean
    make -j${MAKE_JOBS}
    make install
}

# cd into the source dir. `./configure` needs to be called from there
cd $LIB_SRC_DIR

# path to cached arguments file
CACHED_ARGS_FILE="$OUTPUT_DIR/configure_args_cache.txt"

# load previously stored arguments
CACHED_ARGS=$(cat "$CACHED_ARGS_FILE")

# delete previous build artefacts (inlcuding the cached arguments
rm -rf "$OUTPUT_DIR"

# (re-)create the directory to place the cachec arguments in
mkdir -p "$OUTPUT_DIR"

CURRENT_ARGS="SDK=$SDK;$ARCHS=$ARCHS;MIN_DEPLOYMENT_TARGET=$MIN_DEPLOYMENT_TARGET;DEPLOYMENT_TARGET_FLAG_NAME=$DEPLOYMENT_TARGET_FLAG_NAME;LIB_SRC_DIR: $LIB_SRC_DIR;OUTPUT_DIR=$OUTPUT_DIR;[DEBUG]=$DEBUG"

# store current arguments in a file (overwriting the existing value)
echo "$CURRENT_ARGS" > "$CACHED_ARGS_FILE"

# if a cache is present and equal to the current set of args, only do build, skip configure
# AND there is only one architecture
ARCH_COUNT=$(echo "$ARCHS" | wc -w)
if [ ! -z "$CACHED_ARGS" ] && [ "$CACHED_ARGS" == "$CURRENT_ARGS" ] &&  (( $ARCH_COUNT == 1 ))
then
    # cached args are present, they are the same as previous and, and there
    # is only  single architecture. No need to run configure.
    echo "Not calling 'configure', same args as previous build. Only calling make."
    doMake
    exit
fi

# adapted from the script found here:
# https://stackoverflow.com/a/26812514/2358592

# `-Os`            : optimize for size
# `-fembed-bitcode`: embed llvm bitcode
# `-g3`            : produce debugging information
if [ -z "$DEBUG" ]
then
    DEBUG_POSTFIX=""
    OPT_FLAGS="-Os -fembed-bitcode"
else
    DEBUG_POSTFIX="-debug"
    OPT_FLAGS="-Os -fembed-bitcode -g3"
fi

## on M1 Macbook Air there are 8 cores, so that seems an appropriate number
MAKE_JOBS=8



doConfigure()
{
    export CC="$(xcrun -find -sdk ${SDK} cc)"
#    export CXX="$(xcrun -find -sdk ${SDK} cxx)"
    export CPP="$(xcrun -find -sdk ${SDK} cpp)"
    export CFLAGS="${HOST_FLAGS} ${OPT_FLAGS}"
    export CXXFLAGS="${HOST_FLAGS} ${OPT_FLAGS}"
    export LDFLAGS="${HOST_FLAGS}"
    
    ./configure --host=${CHOST} --prefix=${PREFIX} --enable-static --disable-shared
}

if (( ${#ARCHS[@]} > 0 ))
then
    echo "Building '$SDK' with min deployment target $MIN_DEPLOYMENT_TARGET..."
    for arch in $ARCHS; do
        echo "\t...for $arch"
        ARCH_FLAGS="-arch $arch"
        HOST_FLAGS="${ARCH_FLAGS} -$DEPLOYMENT_TARGET_FLAG_NAME=$MIN_DEPLOYMENT_TARGET -isysroot $(xcrun -sdk ${SDK} --show-sdk-path)"
        CHOST="arm-apple-darwin"
        PREFIX="$OUTPUT_DIR/$SDK-$arch$DEBUG_POSTFIX"
        doConfigure
        doMake
        OUTPUT_PATHS[${#OUTPUT_PATHS[@]}]="$PREFIX"
    done
fi

BUILD_DIR="$PREFIX"
if (( ${#OUTPUT_PATHS[@]} > 1 ))
then
    # create universal ('fat') binary of all architectures combined
    UNIVERSAL_OUTPUT_DIR="$OUTPUT_DIR/$SDK-universal$DEBUG_POSTFIX"
    
    # create a folder for the universal build
    mkdir -p "$UNIVERAL_OUTPUT_DIR"
    
    # copy the contents of one of the earlier builds there
    cp -R "${OUTPUT_PATHS[1]}/" "$UNIVERSAL_OUTPUT_DIR/"
    
    # delete the contents the 'lib' folder in that copied contents
    rm -rf "$UNIVERSAL_OUTPUT_DIR/lib/"
    
    mkdir -p "$UNIVERSAL_OUTPUT_DIR/lib/"
    
    # about indexing into arrays:
    # accessing n items at index i:
    # ${OUTPUT_PATHS[@]:i:n}"
    # so, accessing 1 item at index 3 would be:
    # # ${OUTPUT_PATHS[@]:3:1}"
    
    # build the argument list for the `lipo` command
    ARCH_LIBS=""
    for OUTPUT_PATH in ${OUTPUT_PATHS[@]}
    do
        LIB_SOURCE_PATH="$OUTPUT_PATH/lib/libexif.a"
        ARCH_LIBS+=" $LIB_SOURCE_PATH"
    done

    # run `lipo` with those arguments
    lipo -create $ARCH_LIBS -output "$UNIVERSAL_OUTPUT_DIR/lib/libexif.a"
    
    # delete the two separate build directories, since the universal one
    # created above is the only one used by the project
    for OUTPUT_PATH in ${OUTPUT_PATHS[@]}
    do
        rm -rf "$OUTPUT_PATH"
    done
  
    # set the build this to this newly create directory
    BUILD_DIR="$UNIVERSAL_OUTPUT_DIR"
fi

# create a symlink inside the project pointing to this new build if a path for
# symlink was provided
if [ ! -z "$SYMLINK_PATH" ]
then
    rm "$SYMLINK_PATH"
    ln -s "$BUILD_DIR" "$SYMLINK_PATH"
fi
