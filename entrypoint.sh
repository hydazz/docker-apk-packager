#!/bin/bash

# ~~~~~~~~~~~~~~~~~~~~~~~
# set colours
# ~~~~~~~~~~~~~~~~~~~~~~~

RED='\033[1;31m'  # echo Red
BLUE='\033[1;34m' # echo Blue
BOLD='\033[1;37m' # echo White Bold
NC='\033[0m'      # echo No Colou

# ~~~~~~~~~~~~~~~~~~~~~~~
# setup stage
# ~~~~~~~~~~~~~~~~~~~~~~~

# create directories
mkdir -p \
	/var/cache/distfiles \
	/config/.abuild

# add testing repo if enabled by user
[[ -n "${TESTING}" ]] &&
	echo "http://dl-cdn.alpinelinux.org/alpine/edge/testing" >>/etc/apk/repositories

# find and set key
KEY=$(find /config -name "*.rsa")
if [ ! "$(echo "${KEY}" | wc -l)" = "1" ]; then
	echo -e "${RED}Error: Multiple signing keys have been found${NC}"
	echo -e "${BOLD}${KEY}${NC}"
	exit 1
fi
if [ -z "${KEY}" ]; then
	echo -e "${RED}Error: Could not locate a signing key${NC}"
	echo -e "${BLUE}Generating a new signing key${NC}"
	abuild-keygen -n -q
	if [ -f /out/keys.rsa ]; then
		echo -e "${RED}Error: There is already a private key in the output directory, maybe try use that?${NC}"
		exit 1
	else
		mv /root/.abuild/*.rsa /out/key.rsa
	fi
	if [ -f /out/key.rsa.pub ]; then
		echo -e "${RED}Error: There is already a public key in the output directory${NC}"
		exit 1
	else
		mv /root/.abuild/*.rsa.pub /out/key.rsa.pub
	fi
	echo -e "${BLUE}Your new public and private signing keys are in the output directory${NC}"
	KEY=/out/key.rsa
fi
echo "PACKAGER_PRIVKEY=\"${KEY}\"" >/config/.abuild/abuild.conf

# find and set package location
APKBUILD=$(find /config -name "APKBUILD" | sed s/APKBUILD//g)
if [ ! "$(echo "${APKBUILD}" | wc -l)" = "1" ]; then
	echo -e "${RED}Error: Multiple APKBUILD files have been found${NC}"
	echo -e "${APKBUILD}"
	exit 1
fi
if [ -z "${APKBUILD}" ]; then
	echo -e "${RED}Error: Could not locate an APKBUILD file${NC}"
	exit 1
fi

# ~~~~~~~~~~~~~~~~~~~~~~~
# build stage
# ~~~~~~~~~~~~~~~~~~~~~~~

# cd to package directory
if ! cd "${APKBUILD}"; then
	echo -e "${RED}Could not cd to ${APKBUILD}${NC}"
	exit 1
fi

apk update -q

# run checksum
if ! su abc -c "abuild checksum"; then
	echo -e "${RED}Error: command \"abuild checksum\" failed with error code: $?, see above for possible errors${NC}"
	exit 1
fi

# run build
if ! su abc -c "abuild -r"; then
	echo -e "${RED}Error: command \"abuild -r\" failed with error code: $?, see above for possible errors${NC}"
	exit 1
fi

# make output folder and move packaged files to output
mkdir -p \
	/out/apk-packager
mv /config/packages/config/* /out/apk-packager/
