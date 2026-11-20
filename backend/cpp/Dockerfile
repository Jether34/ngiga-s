FROM ubuntu:24.04 AS build
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential ca-certificates cmake curl git ninja-build pkg-config tar unzip zip \
    && rm -rf /var/lib/apt/lists/*
RUN git clone --depth 1 https://github.com/microsoft/vcpkg.git /opt/vcpkg \
    && /opt/vcpkg/bootstrap-vcpkg.sh -disableMetrics
WORKDIR /src
COPY backend/cpp ./backend/cpp
RUN cmake -S backend/cpp -B /build -G Ninja \
    -DCMAKE_TOOLCHAIN_FILE=/opt/vcpkg/scripts/buildsystems/vcpkg.cmake \
    -DVCPKG_TARGET_TRIPLET=x64-linux -DCMAKE_BUILD_TYPE=Release \
    && cmake --build /build --parallel

FROM ubuntu:24.04 AS runtime
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates curl libstdc++6 \
    && rm -rf /var/lib/apt/lists/*
COPY --from=build /build/stockroom_api /usr/local/bin/stockroom_api
COPY --from=build /opt/vcpkg/installed/x64-linux/lib/ /usr/local/lib/
COPY --from=build /opt/vcpkg/installed/x64-linux/plugins/libmariadb/ /usr/local/lib/mariadb/plugins/
RUN ldconfig
ENV MARIADB_PLUGIN_DIR=/usr/local/lib/mariadb/plugins
ENV PORT=8000
EXPOSE 8000
ENTRYPOINT ["/usr/local/bin/stockroom_api"]
