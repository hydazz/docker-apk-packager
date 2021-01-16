FROM alpine:3.13

RUN \
   echo "**** install runtime packages ****" && \
   apk add --no-cache --upgrade \
      alpine-sdk \
      bash \
      sudo && \
   adduser -h /config -D abc && \
   echo 'abc ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers && \
   addgroup abc abuild && \
   echo "**** cleanup ****" && \
   rm -rf \
      /tmp/*

# add local files
COPY root/ /

ENTRYPOINT ["/entrypoint.sh"]
VOLUME /config /out
