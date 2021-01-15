#!/bin/bash
[[ -n ${TESTING} ]] &&
	echo "http://dl-cdn.alpinelinux.org/alpine/edge/testing" >>/etc/apk/repositories

apk update -q

mkdir -p \
	/out/package \
	/var/cache/distfiles \
	/config/.abuild

# setup key
KEY=$(find /config -name "*.rsa")
if [ ! "$(echo "${KEY}" | wc -l)" = "1" ]; then
	echo "Error: Multiple keys have been found"
	echo "${KEY}"
	exit 1
fi
if [ -z "${KEY}" ]; then
	echo "Error: Could not locate .rsa key"
	exit 1
fi
echo 'PACKAGER_PRIVKEY="'${KEY}'"' >/config/.abuild/abuild.conf

# build setup
APKBUILD=$(find /config -name "APKBUILD" | sed s/APKBUILD//g)
if [ ! "$(echo "${APKBUILD}" | wc -l)" = "1" ]; then
	echo "Error: Multiple APKBUILD files have been found"
	echo "${APKBUILD}"
	exit 1
fi
if [ -z "${APKBUILD}" ]; then
	echo "Error: Could not locate APKBUILD"
	exit 1
fi

# build n pack
cd "${APKBUILD}" || exit 1
su abc -c "abuild checksum" || exit 1
su abc -c "abuild -r" || exit 1

mv /config/packages/config/* /out/package/
