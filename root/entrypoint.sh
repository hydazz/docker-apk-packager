#!/bin/bash

# ~~~~~~~~~~~~~~~~~~~~~~~
# set colours
# ~~~~~~~~~~~~~~~~~~~~~~~

red='\033[1;31m'   # red
green='\033[1;32m' # Green
bold='\033[1;37m'  # white bold
nc='\033[0m'       # no colour

# ~~~~~~~~~~~~~~~~~~~~~~~
# error out before starting
# ~~~~~~~~~~~~~~~~~~~~~~~

if [ -f /out/apk-packager/"$(cat /etc/apk/arch)"/APKINDEX.tar.gz ]; then
	echo -e "${red}>>> ERROR: ${bold}There is already an APKINDEX.tar.gz in the output directory, bad things can happen when this file is overwritten."
	echo -e "For help building multiple packages for one or multiple architecture see"
	echo -e "https://github.com/hydazz/docker-apk-packager#building-multiple-packages-for-one-or-multiple-architectures${nc}"
	exit 1
fi

# ~~~~~~~~~~~~~~~~~~~~~~~
# setup stage
# ~~~~~~~~~~~~~~~~~~~~~~~

# create directories
mkdir -p \
	/var/cache/distfiles \
	/config/.abuild \
	/config/abuild \
	/config/packages/config

# add testing repo if enabled by user
[[ -n "${testing}" ]] &&
	echo "http://dl-cdn.alpinelinux.org/alpine/edge/testing" >>/etc/apk/repositories

# ~~~~~~~~~~~~~~~~~~~~~~~
# find and set key
# ~~~~~~~~~~~~~~~~~~~~~~~

key="$(find /config -name "*.rsa")"
if [ ! "$(echo "${key}" | wc -l)" = "1" ]; then
	echo -e "${red}>>> ERROR: ${bold}Multiple signing keys have been found${nc}"
	echo -e "${bold}${key}${nc}"
	exit 1
fi
if [ -z "${key}" ]; then
	echo -e "${red}>>> ERROR: ${bold}Could not locate a signing key or no signing key specified${nc}"
	echo -e "${green}>>> ${bold}Generating a new signing key${nc}"
	abuild-keygen -n -q
	if [ -f /out/key.rsa ]; then
		echo -e "${red}>>> ERROR: ${bold}There is already a private key in the output directory, maybe try use that?${nc}"
		exit 1
	else
		mv /root/.abuild/*.rsa /out/key.rsa
	fi
	if [ -f /out/key.rsa.pub ]; then
		echo -e "${red}>>> ERROR: ${bold}There is already a public key in the output directory${nc}"
		exit 1
	else
		mv /root/.abuild/*.rsa.pub /out/key.rsa.pub
	fi
	echo -e "${green}>>> ${bold}Your new public and private signing keys are in the output directory${nc}"
	key=/out/key.rsa
fi

echo "PACKAGER_PRIVKEY=\"${key}\"" >/config/.abuild/abuild.conf

# ~~~~~~~~~~~~~~~~~~~~~~~
# find and set package location
# ~~~~~~~~~~~~~~~~~~~~~~~

apkbuild="$(find /config -name "APKBUILD" | sed s/APKBUILD//g)"
if [ ! "$(echo "${apkbuild}" | wc -l)" = "1" ]; then
	echo -e "${red}>>> ERROR: ${bold}Multiple APKBUILD files have been found${nc}"
	echo -e "${bold}${apkbuild}${nc}"
	exit 1
fi
if [ -z "${apkbuild}" ]; then
	echo -e "${red}>>> ERROR: ${bold}Could not locate an APKBUILD file${nc}"
	exit 1
fi

# ~~~~~~~~~~~~~~~~~~~~~~~
# build stage
# ~~~~~~~~~~~~~~~~~~~~~~~

# cleanup failed build attempts
[[ -d "${apkbuild}"/src ]] &&
	rm -rf "${apkbuild}"/src
[[ -d "${apkbuild}"/pkg ]] &&
	rm -rf "${apkbuild}"/pkg

# copy files to different location to prepair for build
cp -r "${apkbuild}"/* /config/abuild

# cd to package directory
cd /config/abuild || exit 1

apk update -q

# fix permissions
chown -R abc:abc \
	/config/abuild \
	/config/packages

# run checksum
if ! su abc -c "abuild checksum"; then
	exit 1
fi

# run build
if ! su abc -c "abuild -r"; then
	exit 1
fi

# ~~~~~~~~~~~~~~~~~~~~~~~
# finish stage
# make output folder and move packaged files to output
# ~~~~~~~~~~~~~~~~~~~~~~~

mkdir -p \
	/out/apk-packager
mv /config/packages/config/* /out/apk-packager/
