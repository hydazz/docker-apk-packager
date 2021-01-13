#!/bin/bash
#set -x
# ./package.sh <arch> <path to key> <path to apkbuild> <path to output>

# colours
RED='\033[1;31m'   # echo Red
BLUE='\033[1;34m'  # echo Blue
GREEN='\033[0;32m' # echo Green
BOLD='\033[1;37m'  # echo White Bold
NC='\033[0m'       # echo No Colour

helpFunction() {
	echo ""
	echo "Usage: $0 -a <arch> -k <key> -i <input> -o <output>"
	echo -e "\t-a Architecture: Build architecture; supported architectures are amd64, arm64 and armv7"
	echo -e "\t-k Key: FULL path to private signing key"
	echo -e "\t-i Input: FULL path to the folder containing the APKBUILD file"
	echo -e "\t-o Output: FULL path to the output folder"
	echo -e "\t-t Testing: add the testing repo to the apk repository"
	exit 1 # Exit script after printing help
}

while getopts "a:k:i:o:t:" opt; do
	case "$opt" in
	a) ARCH="$OPTARG" ;;
	k) KEY="$OPTARG" ;;
	i) INPUT="$OPTARG" ;;
	o) OUTPUT="$OPTARG" ;;
	t) TESTING="$OPTARG" ;;
	?) helpFunction ;; # Print helpFunction in case parameter is non-existent
	esac
done

# Print helpFunction in case parameters are empty
if [ -z "$ARCH" ] || [ -z "$KEY" ] || [ -z "$INPUT" ] || [ -z "$OUTPUT" ]; then
	echo "Some or all of the parameters are empty"
	helpFunction
fi

[[ $TESTING = "true" ]] &&
	ARGS="-e TESTING=true"

if [ "$ARCH" = "amd64" ] || [ "$ARCH" = "arm64" ] || [ "$ARCH" = "armv7" ]; then
	:
else
	echo -e "${RED}"
	echo "Error: $ARCH is not a supported architecture"
	echo -e "${BOLD}Supported architectures: amd64, arm64, armv7"
	echo -e "${NC}"
	exit 1
fi

KEY_NAME=$(basename $KEY)
APKBUILD_DIR=$(echo $INPUT | sed s/APKBUILD//g)
FOLDER_NAME=$(basename $APKBUILD_DIR)

# not my best work, i have no idea how to use jq.
MANIFEST=$(docker buildx imagetools inspect vcxpz/apk-packager --raw) # 'cache' manifest
AMD64="docker.io/vcxpz/apk-packager:latest@$(echo ${MANIFEST} | jq '.manifests[0] .digest' | sed 's/"//g')"
ARM64="docker.io/vcxpz/apk-packager:latest@$(echo ${MANIFEST} | jq '.manifests[1] .digest' | sed 's/"//g')"
ARMV7="docker.io/vcxpz/apk-packager:latest@$(echo ${MANIFEST} | jq '.manifests[2] .digest' | sed 's/"//g')"

function build() {
	docker run --rm \
		-v ${KEY}:/config/${KEY_NAME} \
		-v ${APKBUILD_DIR}:/config/${FOLDER_NAME} \
		-v ${OUTPUT}:/out \
		${ARGS} \
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

echo -e "${BLUE}Packaging... This will take a while${NC}"
build
