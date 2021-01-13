FROM alpine:edge

# add local files
COPY root/ /

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
   chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
