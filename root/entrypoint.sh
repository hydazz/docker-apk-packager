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

# pull pkgname from APKBUILD
source /config/apk-build/APKBUILD

# ~~~~~~~~~~~~~~~~~~~~~~~
# error out before starting
# ~~~~~~~~~~~~~~~~~~~~~~~

if [ -f /out/apk-packager/$pkgname/"$(cat /etc/apk/arch)"/APKINDEX.tar.gz ]; then
	echo_error "There is already an APKINDEX.tar.gz in the output directory, bad things can happen when this file is overwritten."
	echo_bold "For help building multiple packages for one or multiple architecture see"
	echo_bold "https://github.com/hydazz/docker-apk-packager#building-multiple-packages-for-one-or-multiple-architectures"
	exit 1
fi

# ~~~~~~~~~~~~~~~~~~~~~~~
# setup stage
# ~~~~~~~~~~~~~~~~~~~~~~~

# create directories
mkdir -p \
	/var/cache/distfiles \
	/config/{.abuild,abuild,packages/config} \
	/out/apk-packager/$pkgname

# add testing repo if enabled by user
[[ -n "${testing}" ]] &&
	echo "http://dl-cdn.alpinelinux.org/alpine/edge/testing" >>/etc/apk/repositories

# ~~~~~~~~~~~~~~~~~~~~~~~
# set or generate keys
# ~~~~~~~~~~~~~~~~~~~~~~~

key="/config/key.rsa"

if [ ! -f "${key}" ]; then
	echo_error "Could not find a private key at /config/key.rsa"
	echo_notice "Generating new signing keys"
	abuild-keygen -n -q
	mkdir -p /out/apk-packager/keys
	mv -f /root/.abuild/*.rsa /out/apk-packager/keys/key.rsa
	mv -f /root/.abuild/*.rsa.pub /out/apk-packager/keys/key.rsa.pub
	echo_notice "Your new public and private signing keys are in the output directory"
	key=/out/apk-packager/keys/key.rsa
fi

echo "PACKAGER_PRIVKEY=\"${key}\"" >/config/.abuild/abuild.conf

# ~~~~~~~~~~~~~~~~~~~~~~~
# find and set package location
# ~~~~~~~~~~~~~~~~~~~~~~~


if [ ! -f /config/apk-build/APKBUILD ]; then
	echo_error "Could not locate a APKBUILD file at /config/apk-build/APKBUILD"
	exit 1
fi

# ~~~~~~~~~~~~~~~~~~~~~~~
# build stage
# ~~~~~~~~~~~~~~~~~~~~~~~

# copy files to different location to prepair for build
cp -r /config/apk-build/* /config/abuild

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
# move packaged files to output
# ~~~~~~~~~~~~~~~~~~~~~~~

mv /config/packages/config/* /out/apk-packager/$pkgname
