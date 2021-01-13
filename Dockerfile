FROM alpine:edge

RUN \
   echo "**** install runtime packages ****" && \
   apk add --no-cache --upgrade \
      alpine-sdk \
      bash \
      sudo && \
   adduser -h /config -D -s /bin/bash abc && \
   echo "abc:abc" | chpasswd && \
   echo '%abc ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers && \
   addgroup abc abuild && \
   su abc -c "sudo mkdir -p \
   /var/cache/distfiles \
   /config/.abuild" && \
   su abc -c "sudo chmod a+w /var/cache/distfiles" && \
   echo 'PACKAGER_PRIVKEY="/config/key.rsa"' >/config/.abuild/abuild.conf
