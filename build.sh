#!/bin/bash

# ~~~~~~~~~~~~~~~~~~~~~~~
# set colours
# ~~~~~~~~~~~~~~~~~~~~~~~

red='\033[1;31m'   # echo Red
blue='\033[1;34m'  # echo Blue
green='\033[1;92m' # echo Green
bold='\033[1;37m'  # echo White Bold
nc='\033[0m'       # echo No Colour

# ~~~~~~~~~~~~~~~~~~~~~~~
# get parameters from user
# ~~~~~~~~~~~~~~~~~~~~~~~

helpFunction() {
	echo ""
	echo -e "${bold}Usage: $0 -a <arch> -k <key> -i <input> -o <output>"
	echo -e "\t-v ersion: Alpine version to use"
	echo -e "\t-a rchitecture: Build architecture"
	echo -e "\t-k ey: Full path to your private signing key"
	echo -e "\t-i nput: Path to the directory containing the APKBUILD file"
	echo -e "\t-o utput: Path to the output directory"
	echo -e "\t-t esting: Add the testing repository${nc}"
	exit 1
}

while getopts ":v:a:k:i:o:t" opt; do
	case "${opt}" in
	v) VERSION="${OPTARG}" ;;
	a) ARCH="${OPTARG}" ;;
	k) KEY="${OPTARG}" ;;
	i) INPUT="${OPTARG}" ;;
	o) OUTPUT="${OPTARG}" ;;
	t) TESTING="true" ;;
	?) helpFunction ;;
	esac
done
VERSION=${VERSION:-latest}
# print helpFunction in case parameters are empty
if [ -z "${ARCH}" ] || [ -z "${INPUT}" ] || [ -z "${OUTPUT}" ]; then
	echo -e "${red}Some or all of the parameters are empty${nc}"
	helpFunction
fi

if [ "${TESTING}" = "true" ]; then
	echo -e "${blue}Testing repository enabled${nc}"
	testing="-e testing=true"
fi

# ~~~~~~~~~~~~~~~~~~~~~~~
# validate supplied parameters
# ~~~~~~~~~~~~~~~~~~~~~~~

if [ "${ARCH}" = "amd64" ] || [ "${ARCH}" = "arm/v6" ] || [ "${ARCH}" = "arm/v7" ] || [ "${ARCH}" = "arm64" ] || [ "${ARCH}" = "386" ] || [ "${ARCH}" = "ppc64le" ] || [ "${ARCH}" = "s390x" ]; then
	:
else
	echo -e "${red}Error: ${ARCH} is not a supported architecture${nc}"
	echo -e "${bold}Supported architectures: amd64, arm/v6, arm/v7, arm64, 386, ppc64le, s390x${nc}"
	exit 1
fi

if [ "${VERSION}" = "latest" ] || [ "${VERSION}" = "edge" ] || [ "${VERSION}" = "3.13" ] || [ "${VERSION}" = "3.12" ]; then
	:
else
	echo -e "${red}Error: ${VERSION} is not a supported version${nc}"
	echo -e "${bold}Supported versions: edge, 3.13, 3.12${nc}"
	exit 1
fi

# ~~~~~~~~~~~~~~~~~~~~~~~
# validate supplied folder/file locations
# ~~~~~~~~~~~~~~~~~~~~~~~

key_name=$(basename "${KEY}")
apkbuild_dir=${INPUT//APKBUILD/}
folder_name=$(basename "${apkbuild_dir}")

if [ -n "${KEY}" ]; then
	if [ ! -f "${KEY}" ]; then
		echo -e "${red}Error: ${KEY} is not a valid file${nc}"
		exit 1
	else
		buildkey="-v ${KEY}:/config/${key_name}"
	fi
else
	echo -e "${blue}No private key supplied, a new signing key pair will be generated in ${OUTPUT} for you to use${nc}"
fi
if [ ! -d "${apkbuild_dir}" ]; then
	echo -e "${red}Error: ${apkbuild_dir} is not a valid folder${nc}"
	exit 1
fi
if [ ! -d "${OUTPUT}" ]; then
	echo -e "${red}Error: ${OUTPUT} is not a valid folder${nc}"
	exit 1
fi

#~~~~~~~~~~~~~~~~~~~~~~~
# check deps and arch support
# todo: auto install deps
#~~~~~~~~~~~~~~~~~~~~~~~

if ! command -v docker &>/dev/null; then
	docker="false"
fi

if ! command -v jq &>/dev/null; then
	jq="false"
fi

ls=$(docker buildx ls) || buildx=false

if [ "${docker}" = "false" ] || [ "${jq}" = "false" ] || [ "${buildx}" = "false" ]; then
	[[ "${docker}" = "false" ]] &&
		echo -e "${red}Error: docker is not installed${nc}"
	[[ "${buildx}" = "false" ]] &&
		echo -e "${red}Error: docker buildx is not installed${nc}"
	[[ "${jq}" = "false" ]] &&
		echo -e "${red}Error: jq is not installed${nc}"
	exit 1
fi

if ! docker info >/dev/null 2>&1; then
	echo -e "${red}Error: Cannot connect to the Docker daemon. Is the docker daemon running?${nc}"
	exit 1
fi

if ! echo "$ls" | grep -o "linux/${ARCH}" | sed -n 1p | grep -q "linux/${ARCH}"; then
	echo -e "${red}Error: Your system does not support ${ARCH} emulation${nc}"
	exit 1
fi

# ~~~~~~~~~~~~~~~~~~~~~~~
# get absolute folder paths
# ~~~~~~~~~~~~~~~~~~~~~~~

apkbuild_dir=$(
	cd "${apkbuild_dir}" || exit
	pwd
)
output=$(
	cd "${OUTPUT}" || exit
	pwd
)

# ~~~~~~~~~~~~~~~~~~~~~~~
# set architecture
# not my best work, i have no idea how to use jq
# ~~~~~~~~~~~~~~~~~~~~~~~

MANIFEST=$(docker buildx imagetools inspect vcxpz/apk-packager:"${VERSION}" --raw) # 'cache' manifest

[[ ${ARCH} = "amd64" ]] &&
	repo="docker.io/vcxpz/apk-packager:latest@$(echo "${MANIFEST}" | jq '.manifests[0] .digest' | sed 's/"//g')"
[[ ${ARCH} = "arm/v6" ]] &&
	repo="docker.io/vcxpz/apk-packager:latest@$(echo "${MANIFEST}" | jq '.manifests[1] .digest' | sed 's/"//g')"
[[ ${ARCH} = "arm/v7" ]] &&
	repo="docker.io/vcxpz/apk-packager:latest@$(echo "${MANIFEST}" | jq '.manifests[2] .digest' | sed 's/"//g')"
[[ ${ARCH} = "arm64" ]] &&
	repo="docker.io/vcxpz/apk-packager:latest@$(echo "${MANIFEST}" | jq '.manifests[3] .digest' | sed 's/"//g')"
[[ ${ARCH} = "386" ]] &&
	repo="docker.io/vcxpz/apk-packager:latest@$(echo "${MANIFEST}" | jq '.manifests[4] .digest' | sed 's/"//g')"
[[ ${ARCH} = "ppc64le" ]] &&
	repo="docker.io/vcxpz/apk-packager:latest@$(echo "${MANIFEST}" | jq '.manifests[5] .digest' | sed 's/"//g')"
[[ ${ARCH} = "s390x" ]] &&
	repo="docker.io/vcxpz/apk-packager:latest@$(echo "${MANIFEST}" | jq '.manifests[6] .digest' | sed 's/"//g')"

# ~~~~~~~~~~~~~~~~~~~~~~~
# set build function
# ~~~~~~~~~~~~~~~~~~~~~~~

function build() {
	clear
	echo -e "${blue}Packaging... This may take a long time${nc}"
	echo ""
	# shellcheck disable=SC2086
	docker run -it --rm \
		${buildkey} \
		-v "${apkbuild_dir}":/config/"${folder_name}" \
		-v "${output}":/out \
		${testing} \
		"${repo}"
}

# ~~~~~~~~~~~~~~~~~~~~~~~
# finally build
# ~~~~~~~~~~~~~~~~~~~~~~~

if build; then
	echo ""
	echo -e "${green}Build was successful! files have been saved to ${output}/apk-packager${nc}"
	exit 0
else
	echo ""
	echo -e "${red}Build failed! check above for possible errors${nc}"
	exit 1
fi
