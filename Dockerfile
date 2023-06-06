FROM alpine:3.18 AS download

# renovate: datasource=github-releases depName=syncthing/syncthing extractVersion=^v(?<version>.*)$
ARG SYNCTHING_VERSION=1.23.5
ARG SYNCTHING_TGZ=https://github.com/syncthing/syncthing/releases/download/v${SYNCTHING_VERSION}/syncthing-linux-amd64-v${SYNCTHING_VERSION}.tar.gz
ARG SYNCTHING_SHA=https://github.com/syncthing/syncthing/releases/download/v${SYNCTHING_VERSION}/sha256sum.txt.asc

WORKDIR /tmp

RUN apk add --no-cache curl gnupg gnupg-keyboxd coreutils tar

RUN gpg --keyserver hkp://keyserver.ubuntu.com --recv-keys D26E6ED000654A3E

RUN curl -LO "$SYNCTHING_TGZ" && \
    curl -LO "$SYNCTHING_SHA" && \
    gpg --verify sha256sum.txt.asc && \
    sha256sum --ignore-missing -c sha256sum.txt.asc && \
    tar xf ./*.tar.gz --strip 1

FROM alpine:3.18

RUN apk upgrade --no-cache

EXPOSE 8384 22050 21027/udp

COPY --from=download /tmp/syncthing /usr/local/bin/syncthing

RUN addgroup -g 1000 syncthing && \
    adduser -h /var/lib/syncthing -D -u 1000 -G syncthing syncthing

USER syncthing

HEALTHCHECK --interval=1m --timeout=10s \
  CMD nc -z localhost 8384 || exit 1

ENV STGUIADDRESS=0.0.0.0:8384
ENV STNODEFAULTFOLDER=1
ENV STNOUPGRADE=1

CMD ["syncthing", "-home", "/var/lib/syncthing/config"]
