FROM alpine:3.14 AS build
RUN apk add linux-headers jpeg-dev g++ make cmake git
RUN mkdir /code && git clone https://github.com/jacksonliam/mjpg-streamer /code
WORKDIR /code/mjpg-streamer-experimental
RUN make && make install

FROM alpine:3.14
RUN mkdir /usr/local/lib/mjpg-streamer && \
    mkdir /usr/local/share/mjpg-streamer
COPY --from=build /usr/local/lib/mjpg-streamer/ /usr/local/lib/mjpg-streamer/
COPY --from=build /usr/local/share/mjpg-streamer/ /usr/local/share/mjpg-streamer/
COPY --from=build /usr/local/bin/mjpg_streamer /usr/local/bin/mjpg_streamer
