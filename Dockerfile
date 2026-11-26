# syntax=docker/dockerfile:1
FROM --platform=$BUILDPLATFORM debian:trixie-slim AS tor-build

ARG TARGETARCH
ARG DEBIAN_FRONTEND=noninteractive

RUN groupadd -g 101 tor && \
    useradd -u 101 -g 101 -m -d /home/tor tor

COPY install-multiarch-dependencies.sh /home/tor/
RUN bash /home/tor/install-multiarch-dependencies.sh ${TARGETARCH}

USER tor
WORKDIR /home/tor

COPY build-tor-multiarch.sh /home/tor/
RUN bash build-tor-multiarch.sh ${TARGETARCH} tor-0.4.9.17

WORKDIR /home/tor/tor

USER root
RUN make install

FROM --platform=$BUILDPLATFORM golang:1.27.4-trixie AS obfs4-build

ARG TARGETOS
ARG TARGETARCH

RUN git clone -b lyrebird-0.10.0 --single-branch https://gitlab.torproject.org/tpo/anti-censorship/pluggable-transports/lyrebird.git
WORKDIR /go/lyrebird/
RUN CGO_ENABLED=0 GOOS=$TARGETOS GOARCH=$TARGETARCH go build -trimpath -o out/lyrebird ./lyrebird

FROM debian:trixie-slim AS final

ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    libcap2-bin \
    libevent-2.1-7t64 \
    zlib1g \
    libssl3t64 \
    liblzma5 \
    libzstd1 \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

RUN groupadd -g 101 tor && \
    useradd -m -u 101 -g 101 -s /bin/false -d /var/lib/tor tor && \
    mkdir -p /etc/tor \
             /usr/local/share/tor \
             /var/log/tor \
    && chown -R 101:101 /var/log/tor /usr/local/share/tor /etc/tor

COPY --from=tor-build /usr/local/bin/* /usr/local/bin/
COPY --from=tor-build /usr/local/share/tor/* /usr/local/share/tor/
COPY --from=obfs4-build /go/lyrebird/out/lyrebird /usr/local/bin/lyrebird

RUN setcap cap_net_bind_service=+ep /usr/local/bin/lyrebird

COPY start-tor.sh /usr/local/bin/
RUN chmod 0755 /usr/local/bin/start-tor.sh

COPY get-bridge-line /usr/local/bin/
RUN chmod 0755 /usr/local/bin/get-bridge-line

USER tor

CMD [ "/usr/local/bin/start-tor.sh" ]
