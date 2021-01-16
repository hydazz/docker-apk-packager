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
	echo -e "\t-a Architecture: Build architecture"
	echo -e "\t-k Key: Full path to your private signing key"
	echo -e "\t-i Input: Path to the folder containing the APKBUILD file"
	echo -e "\t-o Output: Path to the output folder"
	echo -e "\t-t Testing: Add the testing repository"
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
if [ -z "${ARCH}" ] || [ -z "${INPUT}" ] || [ -z "${OUTPUT}" ]; then
	echo "Some or all of the parameters are empty"
	helpFunction
fi

[[ "${TESTING}" = "true" ]] &&
	TESTING="-e TESTING=true"

# validate supplied architecture
if [ "${ARCH}" = "amd64" ] || [ "${ARCH}" = "armv6" ] || [ "${ARCH}" = "armv7" ] || [ "${ARCH}" = "armv8" ] || [ "${ARCH}" = "i386" ] || [ "${ARCH}" = "ppc64le" ] || [ "${ARCH}" = "s390x" ]; then
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
if [ -n "${KEY}" ]; then
	if [ ! -f "${KEY}" ]; then
		echo -e "${RED}Error: ${KEY} is not a valid file${NC}"
	else
		BUILDKEY="-v ${KEY}:/config/${KEY_NAME}"
	fi
else
	echo -e "${BLUE}No private key supplied, a new signing key will be generated in ${OUTPUT} for you to use${NC}"
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
# assumes [0]=amd64 [1]=arm64 [2]=armv7
MANIFEST=$(docker buildx imagetools inspect vcxpz/apk-packager --raw) # 'cache' manifest
AMD64="docker.io/vcxpz/apk-packager:latest@$(echo "${MANIFEST}" | jq '.manifests[0] .digest' | sed 's/"//g')"
ARMV6="docker.io/vcxpz/apk-packager:latest@$(echo "${MANIFEST}" | jq '.manifests[1] .digest' | sed 's/"//g')"
ARMV7="docker.io/vcxpz/apk-packager:latest@$(echo "${MANIFEST}" | jq '.manifests[2] .digest' | sed 's/"//g')"
ARMV8="docker.io/vcxpz/apk-packager:latest@$(echo "${MANIFEST}" | jq '.manifests[3] .digest' | sed 's/"//g')"
I386="docker.io/vcxpz/apk-packager:latest@$(echo "${MANIFEST}" | jq '.manifests[4] .digest' | sed 's/"//g')"
PPC64LE="docker.io/vcxpz/apk-packager:latest@$(echo "${MANIFEST}" | jq '.manifests[5] .digest' | sed 's/"//g')"
S390X="docker.io/vcxpz/apk-packager:latest@$(echo "${MANIFEST}" | jq '.manifests[6] .digest' | sed 's/"//g')"

function build() {
	clear
	echo -e "${BLUE}Packaging... This may take a long time${NC}"
	# shellcheck disable=SC2086
	docker run -it --rm \
		${BUILDKEY} \
		-v "${APKBUILD_DIR}":/config/"${FOLDER_NAME}" \
		-v "${OUTPUT}":/out \
		${TESTING} \
		"${REPO}"
}

# set architecture
[[ ${ARCH} = "amd64" ]] &&
	REPO=$AMD64
[[ ${ARCH} = "armv6" ]] &&
	REPO=$ARMV6
[[ ${ARCH} = "armv7" ]] &&
	REPO=$ARMV7
[[ ${ARCH} = "armv8" ]] &&
	REPO=$ARMV8
[[ ${ARCH} = "i386" ]] &&
	REPO=$I386
[[ ${ARCH} = "ppc64le" ]] &&
	REPO=$PPC64LE
[[ ${ARCH} = "s390x" ]] &&
	REPO=$S390X

if build; then
	echo -e "${GREEN}Build successful! files have been saved to \"${OUTPUT}/apk-packager\"${NC}"
else
	echo -e "${RED}Build failed! check the build log for possible errors${NC}"
fi
