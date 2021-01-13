#!/bin/bash
[[ -n ${TESTING} ]] &&
	echo "http://dl-cdn.alpinelinux.org/alpine/edge/testing" >>/etc/apk/repositories

apk update -q
mkdir -p \
	/out/package \
	/var/cache/distfiles \
	/config/.abuild

su abc -c "sudo chmod a+w /var/cache/distfiles"

# setup key
KEY=$(find /config -name "*.rsa")
if [[ -z ${KEY} ]]; then
	echo "Error: No key is found"
	exit 1
fi
echo 'PACKAGER_PRIVKEY="'${KEY}'"' >/config/.abuild/abuild.conf

# build setup
APKBUILD=$(find /config -name "APKBUILD" | sed s/APKBUILD//g)
if [[ -z ${APKBUILD} ]]; then
	echo "Error: No APKBUILD is found"
	exit 1
fi

# build n pack
cd ${APKBUILD} || exit 1
su abc -c "abuild checksum" || exit 1
su abc -c "abuild -r" || exit 1

mv /config/packages/config/* /out/package/
