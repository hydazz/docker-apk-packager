#!/bin/bash
#set -x
# ./package.sh <arch> <path to key> <path to apkbuild> <path to output>

# error out before continuing if something is not supplied
if [ -z $1 ] || [ -z $2 ] || [ -z $3 ] || [ -z $4 ]; then
	[[ -z $1 ]] &&
		echo "Error: No arch is specified"

	[[ -z $2 ]] &&
		echo "Error: No key location specified"

	[[ -z $3 ]] &&
		echo "Error: No APKBUILD path is specified"

	[[ -z $4 ]] &&
		echo "Error: No output directory specified"
	echo "Usage: ./package.sh <amd64/arm64/armhf> /path/to/key.rsa /path/to/apkbuild/folder/ /path/to/output"
	exit 1
fi
if [ "$1" = "amd64" ] || [ "$1" = "arm64" ] || [ "$1" = "armv7" ]; then
	:
else
	echo "Error: $1 is not a supported architecture"
	echo "Supported architectures: amd64, arm64, armhf"
	exit 1
fi

# not my best work, i have no idea how to use jq.
MANIFEST=$(docker buildx imagetools inspect vcxpz/apk-packager --raw) # 'cache' manifest
AMD64="docker.io/vcxpz/apk-packager:latest@$(echo ${MANIFEST} | jq '.manifests[0] .digest' | sed 's/"//g')"
ARM64="docker.io/vcxpz/apk-packager:latest@$(echo ${MANIFEST} | jq '.manifests[1] .digest' | sed 's/"//g')"
ARMV7="docker.io/vcxpz/apk-packager:latest@$(echo ${MANIFEST} | jq '.manifests[2] .digest' | sed 's/"//g')"

ARCH=$1
KEY=$2
KEY_NAME=$(basename $2)
APKBUILD_DIR=$(echo $3 | sed s/APKBUILD//g)
FOLDER_NAME=$(basename $APKBUILD_DIR)
OUTPUT=$4

function build() {
	docker run --rm \
		-v ${KEY}:/config/${KEY_NAME} \
		-v ${APKBUILD_DIR}:/config/${FOLDER_NAME} \
		-v ${OUTPUT}:/out \
		${REPO}
}

echo "This script will package ${FOLDER_NAME} for ${ARCH} and export the .apk files to ${OUTPUT}, press Ctrl+C within 5 seconds to cancel"
sleep 5

[[ ${ARCH} = "amd64" ]] &&
	REPO=$AMD64

[[ ${ARCH} = "arm64" ]] &&
	REPO=$ARM64

[[ ${ARCH} = "armhf" ]] &&
	REPO=$ARMV7

build > build.log 2>&1

if cat build.log | grep -q "Build Failed"; then
	echo "Error: Build failed. see 'cat build.log' for more information."
else
     echo "Done! Files saved to ${OUTPUT}."
fi
