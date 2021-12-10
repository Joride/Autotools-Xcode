#!/bin/sh

# the configure scripts expects to be informed about:
# - platform ($PLATFORM_NAME)
# - architectures for that platform (`$ARCHS` for `Release` configuration; `$NATIVE_ARCH_64_BIT` for `Debug` configuration)
# - minimum deployment target ($LD_DEPLOYMENT_TARGET)
# - should debug information be included ($CONFIGURATION == "Debug"?)

INCLUDE_DEBUG=0
SDK=$PLATFORM_NAME

BUILD_ARCHS=$ARCHS

if [[ "$CONFIGURATION" == "Debug" ]]
then
    INCLUDE_DEBUG=1
    BUILD_ARCHS=$NATIVE_ARCH_64_BIT
    
    # This is a bit of a hack. `env` does not show any variables that identify the
    # active architecture (which in this project is YES for Debug config)
    # Comparing the env variables for simulator build for debug on an Intel mac
    # and an M1 mac, reveals that the $NATIVE_ARCH_64_BIT is 'x86_64' on Intel
    # and 'arm64e' on an M1 mac. So that looks usefull. BUT!
    # the app will be build for 'arm64' not 'arm64e', so the liberary won't be
    # able to be compiled into the app with it, so we manually change it here.
    # This is of course not very future proof, but ow well.
    if [[ "$BUILD_ARCHS" == "arm64e" ]]
    then
        BUILD_ARCHS="arm64"
    fi
elif [[ "$CONFIGURATION" == "Release" ]]
then
    INCLUDE_DEBUG=0
else
    echo "Unknown configuration '$CONFIGURATION': INCLUDE_DEBUG=0"
    INCLUDE_DEBUG=0
fi

if [[ "$PLATFORM_NAME" == "iphoneos" ]]
then
    # ok, just reassign (can't have an empty bodyu in shell
    SDK=$PLATFORM_NAME
elif [[ "$PLATFORM_NAME" == "iphonesimulator" ]]
then
        # ok, just reassign (can't have an empty body in shell apparently)
    SDK=$PLATFORM_NAME
else
    echo "Unknown platform name '$PLATFORM_NAME'. Using 'iphoneos'"
    SDK="iphoneos"
fi

echo "$(date)\nTARGETNAME: $TARGETNAME\tPLATFORM_NAME: $PLATFORM_NAME\tLD_DEPLOYMENT_TARGET: $LD_DEPLOYMENT_TARGET\tARCHS: $BUILD_ARCHS\tCONFIGURATION: $CONFIGURATION\tSRCROOT: $SRCROOT\tpwd: $(pwd)"

if (( $INCLUDE_DEBUG == 1 ))
then
    echo "$SRCROOT/../configure-xcrun.sh -s \"$SDK\" -a \"$BUILD_ARCHS\" -f $DEPLOYMENT_TARGET_CLANG_FLAG_NAME -t $LD_DEPLOYMENT_TARGET -c /"$SRCROOT/../libexif/\" -o \"$SRCROOT/../libexif-build\"  -l \"$SRCROOT/libexif-build-active\" -d"
    # >/dev/null 2>&1"

    # >/dev/null 2>&1
    $SRCROOT/../configure-xcrun.sh -s "$SDK" -a "$BUILD_ARCHS" -f $DEPLOYMENT_TARGET_CLANG_FLAG_NAME -t $LD_DEPLOYMENT_TARGET -c "$SRCROOT/../libexif/" -o "$SRCROOT/../libexif-build"  -l "$SRCROOT/libexif-build-active" -d

else
    echo "$SRCROOT/../configure-xcrun.sh -s \"$SDK\" -a \"$BUILD_ARCHS\" -f $DEPLOYMENT_TARGET_CLANG_FLAG_NAME -t $LD_DEPLOYMENT_TARGET -c \"$SRCROOT/../libexif/\" -o \"$SRCROOT/../libexif-build\" -l \"$SRCROOT/libexif-build-active\""
    # >/dev/null 2>&1"

    # >/dev/null 2>&1
        $SRCROOT/../configure-xcrun.sh -s "$SDK" -a "$BUILD_ARCHS" -f $DEPLOYMENT_TARGET_CLANG_FLAG_NAME -t $LD_DEPLOYMENT_TARGET -c "$SRCROOT/../libexif/" -o "$SRCROOT/../libexif-build" -l "$SRCROOT/libexif-build-active"
fi

