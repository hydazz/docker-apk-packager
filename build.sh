#!/bin/bash

# ~~~~~~~~~~~~~~~~~~~~~~~
# set colours
# ~~~~~~~~~~~~~~~~~~~~~~~

red='\033[1;31m'   # red
blue='\033[1;34m'  # blue
green='\033[1;32m' # Green
bold='\033[1;37m'  # white bold
nc='\033[0m'       # no colour

# ~~~~~~~~~~~~~~~~~~~~~~~
# get parameters from user
# ~~~~~~~~~~~~~~~~~~~~~~~

helpFunction() {
	echo ""
	echo -e "${bold}Usage: $0 -v <version> -a <arch> -k <key> -i <input> -o <output>"
	echo -e "\t-v ersion: Alpine version to use (Optional)"
	echo -e "\t-a rchitecture: Build architecture (Optional)"
	echo -e "\t-k ey: Full path to your private signing key"
	echo -e "\t-i nput: Path to the directory containing the APKBUILD file"
	echo -e "\t-o utput: Path to the output directory"
	echo -e "\t-t esting: Add the testing repository (Optional)${nc}"
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
ARCH=${ARCH:-os}

# print helpFunction in case parameters are empty
if [ -z "${ARCH}" ] || [ -z "${INPUT}" ] || [ -z "${OUTPUT}" ]; then
	echo -e "${red}>>> ERROR: ${bold}Some or all of the parameters are empty${nc}"
	helpFunction
fi

if [ "${TESTING}" = "true" ]; then
	echo -e "${green}>>> ${bold}Testing repository enabled${nc}"
	args="-e testing=true"
fi

# ~~~~~~~~~~~~~~~~~~~~~~~
# validate supplied parameters
# ~~~~~~~~~~~~~~~~~~~~~~~

if ! { [ "${ARCH}" = "amd64" ] || [ "${ARCH}" = "arm/v6" ] || [ "${ARCH}" = "arm/v7" ] || [ "${ARCH}" = "arm64" ] || [ "${ARCH}" = "386" ] || [ "${ARCH}" = "ppc64le" ] || [ "${ARCH}" = "s390x" ] || [ "${ARCH}" = "os" ]; }; then
	echo -e "${red}>>> ERROR: ${bold}${ARCH} is not a supported architecture${nc}"
	echo -e "${bold}Supported architectures: amd64, arm/v6, arm/v7, arm64, 386, ppc64le and s390x${nc}"
	exit 1
fi

if ! { [ "${VERSION}" = "latest" ] || [ "${VERSION}" = "edge" ] || [ "${VERSION}" = "3.13" ] || [ "${VERSION}" = "3.12" ]; }; then
	echo -e "${red}>>> ERROR: ${bold}${VERSION} is not a supported version${nc}"
	echo -e "${bold}Supported versions: edge, 3.13 and 3.12${nc}"
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
		echo -e "${red}>>> ERROR: ${bold}${KEY} is not a valid file${nc}"
		exit 1
	else
		args="${args} -v ${KEY}:/config/${key_name}"
	fi
else
	echo -e "${green}>>> ${bold}No private key supplied, a new signing key pair will be generated in ${OUTPUT} for you to use${nc}"
fi
if [ ! -d "${apkbuild_dir}" ]; then
	echo -e "${red}>>> ERROR: ${bold}${apkbuild_dir} is not a valid folder${nc}"
	exit 1
fi
if [ ! -d "${OUTPUT}" ]; then
	echo -e "${red}>>> ERROR: ${bold}${OUTPUT} is not a valid folder${nc}"
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

# buildx is not required when docker decideds architecture
if [ ! ${ARCH} = "os" ]; then
	ls=$(docker buildx ls) || buildx=false
fi

if [ "${docker}" = "false" ] || [ "${jq}" = "false" ] || [ "${buildx}" = "false" ]; then
	[[ "${docker}" = "false" ]] &&
		echo -e "${red}>>> ERROR: ${bold}docker is not installed${nc}"
	[[ "${buildx}" = "false" ]] &&
		echo -e "${red}>>> ERROR: ${bold}docker buildx is not installed${nc}"
	[[ "${jq}" = "false" ]] &&
		echo -e "${red}>>> ERROR: ${bold}jq is not installed${nc}"
	exit 1
fi

if ! docker info >/dev/null 2>&1; then
	echo -e "${red}>>> ERROR: ${bold}Cannot connect to the Docker daemon. Is the docker daemon running?${nc}"
	exit 1
fi

if [ ! ${ARCH} = "os" ]; then
	if ! echo "$ls" | grep -o "linux/${ARCH}" | sed -n 1p | grep -q "linux/${ARCH}"; then
		echo -e "${red}>>> ERROR: ${bold}Your system does not support ${ARCH} emulation!"
		echo -e "It is possible a qemu is not installed, see ${bold}https://github.com/hydazz/docker-apk-packager#setting-environment--dependencies-${nc}"
		exit 1
	fi
fi

# ~~~~~~~~~~~~~~~~~~~~~~~
# get absolute folder paths
# ~~~~~~~~~~~~~~~~~~~~~~~

# ~~~~~~~~~~~~~~~~~~~~~~~
# set build function
# ~~~~~~~~~~~~~~~~~~~~~~~

function build() {
	clear

	# hide 'Unable to find image locally'
	echo -e "${green}>>> ${bold}Pulling vcxpz/apk-packager:${VERSION} (${ARCH})"
	docker pull "${repo}" &>/dev/null

	echo -e "${green}>>> ${bold}Packaging... This may take a long time${nc}"
	echo ""
	# shellcheck disable=SC2086
	docker run -it --rm \
		-v "${apkbuild_dir}":/config/"${folder_name}" \
		-v "${OUTPUT}":/out \
		${args} \
		"${repo}"
}

# ~~~~~~~~~~~~~~~~~~~~~~~
# set architecture
# not my best work, i have no idea how to use jq
# ~~~~~~~~~~~~~~~~~~~~~~~

if [ ! ${ARCH} = "os" ]; then
	MANIFEST="$(docker buildx imagetools inspect vcxpz/apk-packager:${VERSION} --raw)" # 'cache' manifest

	[[ ${ARCH} = "amd64" ]] &&
		select="0"
	[[ ${ARCH} = "arm/v6" ]] &&
		select="1"
	[[ ${ARCH} = "arm/v7" ]] &&
		select="2"
	[[ ${ARCH} = "arm64" ]] &&
		select="3"
	[[ ${ARCH} = "386" ]] &&
		select="4"
	[[ ${ARCH} = "ppc64le" ]] &&
		select="5"
	[[ ${ARCH} = "s390x" ]] &&
		select="6"

	repo="docker.io/vcxpz/apk-packager:latest@$(echo "${MANIFEST}" | jq '.manifests['${select}'] .digest' | sed 's/"//g')"
else
	repo="vcxpz/apk-packager:${VERSION}"
	ARCH=$(arch)
fi

# ~~~~~~~~~~~~~~~~~~~~~~~
# finally build
# ~~~~~~~~~~~~~~~~~~~~~~~

if build; then
	echo ""
	echo -e "${green}>>> ${bold}Yipee! your package built successfully, files have been saved to ${OUTPUT}/apk-packager${nc}"
	exit 0
else
	echo ""
	echo -e "${red}>>> ERROR: ${bold}Uh-oh! something went wrong building your package, check above for possible errors${nc}"
	exit 1
fi
