#!/bin/bash
#set -x
# ./package.sh <arch> <path to key> <path to apkbuild> <path to output>

# colours
RED='\033[1;31m'   # echo Red
BLUE='\033[1;34m'  # echo Blue
GREEN='\033[0;32m' # echo Green
BOLD='\033[1;37m'  # echo White Bold
NC='\033[0m'       # echo No Colour

# error out before continuing if something is not supplied
if [ -z $1 ] || [ -z $2 ] || [ -z $3 ] || [ -z $4 ]; then
	echo -e "${RED}"
	[[ -z $1 ]] &&
		echo "Error: No build architecture specified"
	[[ -z $2 ]] &&
		echo "Error: No key location specified"
	[[ -z $3 ]] &&
		echo "Error: No package path specified"
	[[ -z $4 ]] &&
		echo "Error: No output directory specified"
	echo -e "${NC}"
	echo -e "${BOLD}Usage: ./package.sh <amd64/arm64/armv7> /path/to/key.rsa /path/to/package/ /path/to/output/${NC}"
	exit 1
fi
if [ "$1" = "amd64" ] || [ "$1" = "arm64" ] || [ "$1" = "armv7" ]; then
	:
else
	echo -e "${RED}"
	echo "Error: $1 is not a supported architecture"
	echo -e "${BOLD}Supported architectures: amd64, arm64, armv7"
	echo -e "${NC}"
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

echo -e "${BLUE}This script will package ${FOLDER_NAME} for ${ARCH} and export the .apk files to ${OUTPUT}, press Ctrl+C within 5 seconds to cancel${NC}"
sleep 5

[[ ${ARCH} = "amd64" ]] &&
	REPO=$AMD64
[[ ${ARCH} = "arm64" ]] &&
	REPO=$ARM64
[[ ${ARCH} = "armv7" ]] &&
	REPO=$ARMV7

echo -e "${BLUE}Packaging... This will take a while, run 'tail -f ${PWD}/build.log' in a new terminal for a live build log${NC}"
build >build.log 2>&1

if cat build.log | grep -q "Build Failed"; then
	cat build.log
	echo -e "${RED}Error: Build failed. see above for more information.${NC}"
else
	echo -e "${GREEN}Done! Files saved to ${OUTPUT}.${NC}"
fi

# cleanup
rm -rf build.log
