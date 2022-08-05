FROM alpine:3.15 AS build
WORKDIR /code
RUN apk add --no-cache \
        alpine-sdk \
        perl \
        perl-date-format \
        autoconf \
        automake \
        openssl-dev \
    && rm -rf /var/cache/* \
    && mkdir /var/cache/apk

RUN git clone https://git.code.sf.net/p/isync/isync /code
RUN mkdir /app && ./autogen.sh && ./configure --prefix=/app && make && make install

FROM alpine:3.15
COPY --from=build /app/bin/ /usr/bin/