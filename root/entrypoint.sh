#!/bin/bash

# ~~~~~~~~~~~~~~~~~~~~~~~
# set colours
# ~~~~~~~~~~~~~~~~~~~~~~~

red='\033[1;31m'  # echo red
blue='\033[1;34m' # echo blue
bold='\033[1;37m' # echo White bold
nc='\033[0m'      # echo No Colou

# ~~~~~~~~~~~~~~~~~~~~~~~
# setup stage
# ~~~~~~~~~~~~~~~~~~~~~~~

# create directories
mkdir -p \
	/var/cache/distfiles \
	/config/.abuild

# add testing repo if enabled by user
[[ -n "${testing}" ]] &&
	echo "http://dl-cdn.alpinelinux.org/alpine/edge/testing" >>/etc/apk/repositories

# ~~~~~~~~~~~~~~~~~~~~~~~
# find and set key
# ~~~~~~~~~~~~~~~~~~~~~~~

key=$(find /config -name "*.rsa")
if [ ! "$(echo "${key}" | wc -l)" = "1" ]; then
	echo -e "${red}Error: Multiple signing keys have been found${nc}"
	echo -e "${bold}${key}${nc}"
	exit 1
fi
if [ -z "${key}" ]; then
	echo -e "${red}Error: Could not locate a signing key or no signing key specified${nc}"
	echo -e "${blue}Generating a new signing key${nc}"
	abuild-keygen -n -q
	if [ -f /out/key.rsa ]; then
		echo -e "${red}Error: There is already a private key in the output directory, maybe try use that?${nc}"
		exit 1
	else
		mv /root/.abuild/*.rsa /out/key.rsa
	fi
	if [ -f /out/key.rsa.pub ]; then
		echo -e "${red}Error: There is already a public key in the output directory${nc}"
		exit 1
	else
		mv /root/.abuild/*.rsa.pub /out/key.rsa.pub
	fi
	echo -e "${blue}Your new public and private signing keys are in the output directory${nc}"
	key=/out/key.rsa
fi

echo "PACKAGER_PRIVKEY=\"${key}\"" >/config/.abuild/abuild.conf

# ~~~~~~~~~~~~~~~~~~~~~~~
# find and set package location
# ~~~~~~~~~~~~~~~~~~~~~~~

apkbuild=$(find /config -name "APKBUILD" | sed s/APKBUILD//g)
if [ ! "$(echo "${apkbuild}" | wc -l)" = "1" ]; then
	echo -e "${red}Error: Multiple APKBUILD files have been found${nc}"
	echo -e "${apkbuild}"
	exit 1
fi
if [ -z "${apkbuild}" ]; then
	echo -e "${red}Error: Could not locate an APKBUILD file${nc}"
	exit 1
fi

# ~~~~~~~~~~~~~~~~~~~~~~~
# build stage
# ~~~~~~~~~~~~~~~~~~~~~~~

# cd to package directory
if ! cd "${apkbuild}"; then
	echo -e "${red}Could not cd to ${apkbuild}${nc}"
	exit 1
fi

apk update -q

# run checksum
if ! su abc -c "abuild checksum"; then
	echo -e "${red}Error: command \"abuild checksum\" failed, see above for possible errors${nc}"
	exit 1
fi

# run build
if ! su abc -c "abuild -r"; then
	echo -e "${red}Error: command \"abuild -r\" failed, see above for possible errors${nc}"
	exit 1
fi

# ~~~~~~~~~~~~~~~~~~~~~~~
# finish stage
# make output folder and move packaged files to output
# ~~~~~~~~~~~~~~~~~~~~~~~

mkdir -p \
	/out/apk-packager
mv /config/packages/config/* /out/apk-packager/
