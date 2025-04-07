#!/bin/sh
set -e

./ios.sh -s -x \
  --target=17.0 \
  --disable-armv7 \
  --disable-armv7s \
  --disable-arm64-mac-catalyst \
  --disable-arm64e \
  --disable-i386 \
  --disable-x86-64-mac-catalyst \
  --enable-opus \
  --enable-libvpx \
  --enable-ios-audiotoolbox \
  --enable-ios-videotoolbox \
  --enable-ios-avfoundation \
  --enable-ios-zlib \
  --enable-ios-bzip2 \
  --enable-ios-libiconv \
  --enable-libwebp \
  --enable-dav1d \
  --enable-lame \
  --enable-libogg \
  --no-bitcode

FRAMEWORK_NAMES=(ffmpegkit libavcodec libavdevice libavfilter libavformat libavutil libswresample libswscale)
XROS_SIM_PLATFORM=xrossim
XROS_PLATFORM=xros
XROS_MINOS=1.0
XROS_SDK=1.0

PATCHED_FRAMEWORKS=prebuilt/patched-frameworks
PATCHED_XCFRAMEWORKS=prebuilt/patched-xcframeworks

rm -rf ${PATCHED_FRAMEWORKS} ${PATCHED_XCFRAMEWORKS}
mkdir -p ${PATCHED_FRAMEWORKS}

for FRAMEWORK in "${FRAMEWORK_NAMES[@]}"; do
  echo Processing $FRAMEWORK.framework

  IOS_ORIGINAL_FRAMEWORK="prebuilt/bundle-apple-xcframework-ios/${FRAMEWORK}.xcframework/ios-arm64/${FRAMEWORK}.framework"
  OUTPUT_FRAMEWORK=${PATCHED_FRAMEWORKS}/${FRAMEWORK}/xros/${FRAMEWORK}.framework

  rm -rf ${PATCHED_FRAMEWORKS}/${FRAMEWORK}

  # VisionOS
  OUTPUT_FRAMEWORK=${PATCHED_FRAMEWORKS}/${FRAMEWORK}/xros/${FRAMEWORK}.framework
  mkdir -p ${PATCHED_FRAMEWORKS}/${FRAMEWORK}/xros
  cp -r ${IOS_ORIGINAL_FRAMEWORK} ${OUTPUT_FRAMEWORK}
  rm ${OUTPUT_FRAMEWORK}/${FRAMEWORK}

  vtool \
    -set-build-version ${XROS_PLATFORM} ${XROS_MINOS} ${XROS_SDK} \
    -replace \
    -output ${OUTPUT_FRAMEWORK}/${FRAMEWORK} \
    ${IOS_ORIGINAL_FRAMEWORK}/${FRAMEWORK}

  # VisionOS Simulator
  OUTPUT_FRAMEWORK=${PATCHED_FRAMEWORKS}/${FRAMEWORK}/xros-sim/${FRAMEWORK}.framework
  mkdir -p ${PATCHED_FRAMEWORKS}/${FRAMEWORK}/xros-sim
  cp -r ${IOS_ORIGINAL_FRAMEWORK} ${OUTPUT_FRAMEWORK}
  rm ${OUTPUT_FRAMEWORK}/${FRAMEWORK}

  vtool \
    -set-build-version ${XROS_SIM_PLATFORM} ${XROS_MINOS} ${XROS_SDK} \
    -replace \
    -output ${OUTPUT_FRAMEWORK}/${FRAMEWORK} \
    ${IOS_ORIGINAL_FRAMEWORK}/${FRAMEWORK}
done

rm -rf prebuilt/patched-xcframeworks
mkdir -p prebuilt/patched-xcframeworks

LIST=()
for FRAMEWORK in "${FRAMEWORK_NAMES[@]}"; do
  XCFRAMEWORK="prebuilt/bundle-apple-xcframework-ios/${FRAMEWORK}.xcframework"

  xcodebuild -create-xcframework \
    -framework ${XCFRAMEWORK}/ios-arm64/${FRAMEWORK}.framework \
    -framework ${XCFRAMEWORK}/ios-arm64_x86_64-simulator/${FRAMEWORK}.framework \
    -framework ${PATCHED_FRAMEWORKS}/${FRAMEWORK}/xros/${FRAMEWORK}.framework \
    -framework ${PATCHED_FRAMEWORKS}/${FRAMEWORK}/xros-sim/${FRAMEWORK}.framework \
    -output prebuilt/patched-xcframeworks/${FRAMEWORK}.xcframework
  pushd prebuilt/patched-xcframeworks > /dev/null
    rm -rf ${FRAMEWORK}.xcframework.zip
    zip -q -r ${FRAMEWORK}.xcframework.zip ${FRAMEWORK}.xcframework
    HASH=$(sha256sum ${FRAMEWORK}.xcframework.zip | awk '{print $1}')
    LIST+=("\"${FRAMEWORK}\": \"${HASH}\",")
  popd > /dev/null
done

rm -rf prebuilt/patched-xcframeworks/*.xcframework

echo "["
for ITEM in "${LIST[@]}"; do
  echo "  ${ITEM}"
done
echo "]"
