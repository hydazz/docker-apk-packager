ARG TAG=latest
FROM alpine:${TAG}

ENV TERM="xterm"

RUN \
	echo "**** install runtime packages ****" && \
	apk add --no-cache \
		alpine-sdk \
		bash \
		sudo && \
	echo "**** create abc user and setup sudo ****" && \
	adduser -h /config -D abc && \
	echo 'abc ALL=(ALL) NOPASSWD:ALL' >>/etc/sudoers && \
	addgroup abc abuild && \
	echo "**** cleanup ****" && \
	rm -rf \
		/tmp/*

# add local files
COPY root/ /

ENTRYPOINT ["/entrypoint.sh"]
VOLUME /config /out
