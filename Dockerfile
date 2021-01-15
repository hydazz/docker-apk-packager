FROM alpine:edge

RUN \
   echo "**** install runtime packages ****" && \
   apk add --no-cache --upgrade \
      alpine-sdk \
      bash \
      sudo && \
   adduser -h /config -D -s /bin/bash abc && \
   echo '%abc ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers && \
   addgroup abc abuild

# add local files
COPY root/ /

ENTRYPOINT ["/entrypoint.sh"]
VOLUME /config /out
