FROM alpine:3.22 AS download

# renovate: datasource=github-releases depName=syncthing/syncthing extractVersion=^v(?<version>.*)$
ARG SYNCTHING_VERSION=1.29.7
ARG SYNCTHING_TGZ=https://github.com/syncthing/syncthing/releases/download/v${SYNCTHING_VERSION}/syncthing-linux-amd64-v${SYNCTHING_VERSION}.tar.gz
ARG SYNCTHING_SHA=https://github.com/syncthing/syncthing/releases/download/v${SYNCTHING_VERSION}/sha256sum.txt.asc

WORKDIR /tmp

RUN apk add --no-cache curl gpg gpg-agent coreutils tar

COPY release-key.txt /tmp/

RUN gpg --import /tmp/release-key.txt

# Note: something is wrong with the GPG signature in the sha256sum.txt.asc file
# It looks like the Go package the Syncthing team uses to generate the signature
# is incompatible with current gnupg. gpg exits with error code 2 even though
# the signature is verified successfully. As a workaround I just check for the
# good signature output for now. Ugh.
RUN curl -LO "$SYNCTHING_TGZ" && \
  curl -LO "$SYNCTHING_SHA" && \
  gpg --verify sha256sum.txt.asc 2>&1 | grep 'Good signature from "Syncthing Release Management <release@syncthing.net>"' && \
  sha256sum --ignore-missing -c sha256sum.txt.asc | grep "syncthing-linux-amd64-v${SYNCTHING_VERSION}.tar.gz: OK" && \
  tar xf ./*.tar.gz --strip 1

FROM alpine:3.22

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
