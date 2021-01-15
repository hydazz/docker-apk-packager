#!/bin/bash

# colours
RED='\033[1;31m'   # echo Red
BLUE='\033[1;34m'  # echo Blue
GREEN='\033[1;92m' # echo Green
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
	case "${opt}" in
	a) ARCH="${OPTARG}" ;;
	k) KEY="${OPTARG}" ;;
	i) INPUT="${OPTARG}" ;;
	o) OUTPUT="${OPTARG}" ;;
	t) TESTING="${OPTARG}" ;;
	?) helpFunction ;; # Print helpFunction in case parameter is non-existent
	esac
done

# Print helpFunction in case parameters are empty
if [ -z "${ARCH}" ] || [ -z "${KEY}" ] || [ -z "${INPUT}" ] || [ -z "${OUTPUT}" ]; then
	echo "Some or all of the parameters are empty"
	helpFunction
fi

[[ "${TESTING}" = "true" ]] &&
	ARGS="-e TESTING=true"

# validate supplied architecture
if [ "${ARCH}" = "amd64" ] || [ "${ARCH}" = "arm64" ] || [ "${ARCH}" = "armv7" ]; then
	:
else
	echo -e "${RED}Error: ${ARCH} is not a supported architecture"
	echo -e "${BOLD}Supported architectures: amd64, arm64, armv7${NC}"
	exit 1
fi

KEY_NAME=$(basename "${KEY}")
APKBUILD_DIR=${INPUT//APKBUILD/}
FOLDER_NAME=$(basename "${APKBUILD_DIR}")

# validate supplied folders/files
if [ ! -f "${KEY}" ]; then
	echo -e "${RED}Error: ${KEY} is not a valid file${NC}"
	exit 1
fi
if [ ! -d "${APKBUILD_DIR}" ]; then
	echo -e "${RED}Error: ${APKBUILD_DIR} is not a valid folder${NC}"
	exit 1
fi
if [ ! -d "${OUTPUT}" ]; then
	echo -e "${RED}Error: ${OUTPUT} is not a valid folder${NC}"
	exit 1
fi

# get absolute paths of folders
APKBUILD_DIR=$(
	cd "${APKBUILD_DIR}" || exit
	pwd
)
OUTPUT=$(
	cd "${OUTPUT}" || exit
	pwd
)

# not my best work, i have no idea how to use jq.
MANIFEST=$(docker buildx imagetools inspect vcxpz/apk-packager --raw) # 'cache' manifest
AMD64="docker.io/vcxpz/apk-packager:latest@$(echo "${MANIFEST}" | jq '.manifests[0] .digest' | sed 's/"//g')"
ARM64="docker.io/vcxpz/apk-packager:latest@$(echo "${MANIFEST}" | jq '.manifests[1] .digest' | sed 's/"//g')"
ARMV7="docker.io/vcxpz/apk-packager:latest@$(echo "${MANIFEST}" | jq '.manifests[2] .digest' | sed 's/"//g')"

function build() {
	clear
	echo -e "${BLUE}Packaging... This will take a while${NC}"
	# shellcheck disable=SC2086
	docker run --rm \
		-v "${KEY}":/config/"${KEY_NAME}" \
		-v "${APKBUILD_DIR}":/config/"${FOLDER_NAME}" \
		-v "${OUTPUT}":/out \
		${ARGS} \
		"${REPO}"
}

[[ ${ARCH} = "amd64" ]] &&
	REPO=$AMD64
[[ ${ARCH} = "arm64" ]] &&
	REPO=$ARM64
[[ ${ARCH} = "armv7" ]] &&
	REPO=$ARMV7

build
echo -e "${GREEN}If the package build successully you should see ${BOLD}"'">>> php7-smbclient: Signing the index..."'"${GREEN} above, if not check the build log for possible errors${NC}"
