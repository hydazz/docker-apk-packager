#!/bin/bash

# ~~~~~~~~~~~~~~~~~~~~~~~
# set colours and echo templates
# ~~~~~~~~~~~~~~~~~~~~~~~

red='\033[1;31m'   # red
green='\033[1;32m' # green
bold='\033[1;37m'  # bold white
nc='\033[0m'       # no colour

function echo_error() {
	echo -e "${red}>>> ERROR: ${bold}$1${nc}"
}

function echo_notice() {
	echo -e "${green}>>> ${bold}$1${nc}"
}

function echo_bold() {
	echo -e "${bold}$1${nc}"
}

# ~~~~~~~~~~~~~~~~~~~~~~~
# get parameters from user
# ~~~~~~~~~~~~~~~~~~~~~~~

helpFunction() {
	echo ""
	echo_bold "Usage: $0 -v <version> -a <arch> -k <key> -i <input> -o <output>"
	echo_bold "\t-v Version: Alpine version to use (Optional)"
	echo_bold "\t-a Architecture: Build architecture (Optional)"
	echo_bold "\t-k Key: Full path to your private signing key"
	echo_bold "\t-i Input: Path to the directory containing the APKBUILD file"
	echo_bold "\t-o Output: Path to the output directory"
	echo_bold "\t-t Testing: Add the alpine testing repository (Optional)"
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

clear

if [ -z "${VERSION}" ]; then
	echo_notice "Defaulting version tag to :latest as it is not specified"
	VERSION="latest"
fi

if [ -z "${ARCH}" ]; then
	echo_notice "Defaulting build architecture to $(arch) as it is not specified"
	ARCH="os"
fi

# print helpFunction in case parameters are empty
if [ -z "${ARCH}" ] || [ -z "${INPUT}" ] || [ -z "${OUTPUT}" ]; then
	echo_error "Some or all of the parameters are empty"
	helpFunction
fi

if [ "${TESTING}" = "true" ]; then
	echo_notice "Testing repository enabled"
	args="-e testing=true"
fi

# ~~~~~~~~~~~~~~~~~~~~~~~
# validate supplied parameters
# ~~~~~~~~~~~~~~~~~~~~~~~

if ! { [ "${ARCH}" = "amd64" ] || [ "${ARCH}" = "arm/v6" ] || [ "${ARCH}" = "arm/v7" ] || [ "${ARCH}" = "arm64" ] || [ "${ARCH}" = "386" ] || [ "${ARCH}" = "ppc64le" ] || [ "${ARCH}" = "s390x" ] || [ "${ARCH}" = "os" ]; }; then
	echo_error "${ARCH} is not a supported architecture"
	echo_bold "Supported architectures: amd64, arm/v6, arm/v7, arm64, 386, ppc64le and s390x"
	exit 1
fi
if ! { [ "${VERSION}" = "latest" ] || [ "${VERSION}" = "edge" ] || [ "${VERSION}" = "dev" ] || [ "${VERSION}" = "3.14" ]; }; then
	echo_error "${VERSION} is not a supported version"
	echo_bold "Supported architectures: latest, edge, 3.14"
	exit 1
fi

if [ ${VERSION} == "dev" ]; then
	if [ ! "${ARCH}" == "os" ]; then
		echo_error "Architecture cannot be specified when using dev version"
		exit 1
	fi
fi

# ~~~~~~~~~~~~~~~~~~~~~~~
# validate supplied folder/file locations
# should probably add something to check for basename and dirname
# ~~~~~~~~~~~~~~~~~~~~~~~

# get absolute paths
function realpath {
	echo "$(
		cd "$(dirname "$1")" || exit
		pwd
	)"/"$(basename "$1")"
}

if [ -n "${KEY}" ]; then
	if [ -f "${KEY}" ]; then
		KEY=$(realpath $KEY)
		args="${args} -v ${KEY}:/config/key.rsa"
	else
		echo_error "${KEY} is not a valid file"
		exit 1
	fi
else
	echo_notice "No private key supplied, a new signing key pair will be generated in ${OUTPUT}/apk-packager/keys for you to use"
fi
if [ -d "${INPUT}" ]; then
	INPUT=$(realpath ${INPUT//APKBUILD/})
else
	echo_error "${INPUT} is not a valid folder"
	exit 1
fi
if [ -d "${OUTPUT}" ]; then
	OUTPUT=$(realpath $OUTPUT)
else
	echo_error "${OUTPUT} is not a valid folder"
	exit 1
fi

#~~~~~~~~~~~~~~~~~~~~~~~
# check deps and arch support
#~~~~~~~~~~~~~~~~~~~~~~~

if ! command -v docker &>/dev/null; then
	docker="false"
fi

if ! command -v jq &>/dev/null; then
	jq="false"
fi

ls=$(docker buildx ls) || buildx="false"

# error out if jq, docker or docker buildx is needed but not installed/working
if [ ! ${ARCH} = "os" ]; then
	if [ "${docker}" = "false" ] || [ "${jq}" = "false" ] || [ "${buildx}" = "false" ]; then
		[[ "${docker}" = "false" ]] &&
			echo_error "Docker is not installed"
		[[ "${buildx}" = "false" ]] &&
			echo_error "Docker buildx is not installed"
		[[ "${jq}" = "false" ]] &&
			echo_error "Jq is not installed"
		exit 1
	fi
# jq and buildx are not required when docker decideds architecture
elif [ "${jq}" = "false" ] || [ "${buildx}" = "false" ]; then
	[[ "${buildx}" = "false" ]] &&
		echo_notice "Docker buildx is not installed, but is not needed"
	[[ "${jq}" = "false" ]] &&
		echo_notice "Jq is not installed, but is not needed"
fi

# check if docker is running
if ! docker info >/dev/null 2>&1; then
	echo_error "Cannot connect to the docker daemon. Is the docker daemon running?"
	exit 1
fi

# check if os supports buildx emulation for specified build os
if [ ! ${ARCH} = "os" ]; then
	if ! echo "$ls" | grep -o "linux/${ARCH}" | sed -n 1p | grep -q "linux/${ARCH}"; then
		echo_error "Your system does not support ${ARCH} emulation"
		echo_bold "It is possible QEMU is not installed, try install qemu-user-static"
		exit 1
	fi
fi

# ~~~~~~~~~~~~~~~~~~~~~~~
# set build function
# ~~~~~~~~~~~~~~~~~~~~~~~

function build() {
	echo ""
	echo_notice "Pulling vcxpz/apk-packager:${VERSION} (${ARCH})"
	docker pull "${repo}"

	echo_notice "Packaging... This may take a long time"

	docker run -it --rm \
		-v "${INPUT}":/config/apk-build \
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

	if [[ ${ARCH} = "amd64" ]]; then
		select="0"
	elif [[ ${ARCH} = "arm/v6" ]]; then
		select="1"
	elif [[ ${ARCH} = "arm/v7" ]]; then
		select="2"
	elif [[ ${ARCH} = "arm64" ]]; then
		select="3"
	elif [[ ${ARCH} = "386" ]]; then
		select="4"
	elif [[ ${ARCH} = "ppc64le" ]]; then
		select="5"
	elif [[ ${ARCH} = "s390x" ]]; then
		select="6"
	fi

	repo="docker.io/vcxpz/apk-packager:${VERSION}@$(echo "${MANIFEST}" | jq '.manifests['${select}'] .digest' | sed 's/"//g')"
else
	repo="vcxpz/apk-packager:${VERSION}"
	ARCH=$(arch)
fi

# ~~~~~~~~~~~~~~~~~~~~~~~
# finally build
# ~~~~~~~~~~~~~~~~~~~~~~~

if build; then
	echo ""
	echo_notice "Yipee! Your package built successfully, files have been saved to ${OUTPUT}/apk-packager"
	exit 0
else
	code=$?
	echo ""
	echo_error "Uh-oh! Something went wrong building your package, check above for possible errors"
	exit $code
fi
