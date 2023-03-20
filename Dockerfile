FROM rust:1.68.0-alpine3.17 as build

ARG QUICHE_VERSION=0.16.0
ARG CURL_VERSION=curl-8_0_1

RUN apk add --no-cache git build-base cmake autoconf automake pkgconfig libtool nghttp2-dev nghttp2-static musl-dev && \
    mkdir /src &&\
    cd /src && \
    git clone --recursive --branch "$QUICHE_VERSION" https://github.com/cloudflare/quiche /src/quiche && \
    cd /src/quiche && \
    CARGO_REGISTRIES_CRATES_IO_PROTOCOL=sparse cargo build --package quiche --release --features ffi,pkg-config-meta,qlog && \
    mkdir quiche/deps/boringssl/src/lib && \
    ln -vnf $(find target/release -name libcrypto.a -o -name libssl.a) quiche/deps/boringssl/src/lib && \
    git clone --recursive --branch "$CURL_VERSION" https://github.com/curl/curl /src/curl && \
    cd /src/curl && \
    autoreconf -fi && \
    ./configure LDFLAGS="-Wl,-rpath,/src/quiche/target/release -static" PKG_CONFIG="pkg-config --static" --with-openssl=/src/quiche/quiche/deps/boringssl/src --with-quiche=/src/quiche/target/release --with-nghttp2 --disable-shared --enable-static && \
    make -j "$(nproc)" LDFLAGS="-Wl,-rpath,/src/quiche/target/release -L/src/quiche/quiche/deps/boringssl/src/lib -L/src/quiche/target/release -static -all-static" && \
    strip -s /src/curl/src/curl

FROM alpine:3.17.2
COPY --from=build /src/curl/src/curl /usr/local/bin/curl
RUN curl --http3 -sIL https://cloudflare-quic.com && \
    mkdir -vp /host

WORKDIR /host
ENTRYPOINT ["curl"]
CMD ["-V"]
