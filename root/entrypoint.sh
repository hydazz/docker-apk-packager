#!/bin/bash
apk update -q
mkdir -p \
	/out/package \
	/var/cache/distfiles \
	/config/.abuild

su abc -c "sudo chmod a+w /var/cache/distfiles"

# setup key
KEY=$(find /config -maxdepth 1 -name "*.rsa")
if [[ -z ${KEY} ]]; then
	echo "Error: No key is found"
	sleep infinity
fi
echo 'PACKAGER_PRIVKEY="'${KEY}'"' >/config/.abuild/abuild.conf

# build setup
APKBUILD=$(find /config -name "APKBUILD" | sed s/APKBUILD//g)
if [[ -z ${APKBUILD} ]]; then
	echo "Error: No APKBUILD is found"
	sleep infinity
fi
# support for packaging multiple packages in succession is theoretically possible
for build in ${APKBUILD}; do
	echo "Packaging ${build}APKBUILD for architecture: $(arch)"
	wait 5
	cd ${build}
	su abc -c "abuild checksum"
	su abc -c "abuild -r" || exit 1
done

mv /config/packages/config/* /out/package/
