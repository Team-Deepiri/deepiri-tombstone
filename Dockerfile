ARG BASE=ubuntu:24.04

FROM $BASE AS build
ENV DEBIAN_FRONTEND=noninteractive
WORKDIR /src

RUN apt-get update -qq && apt-get install -y -qq \
    curl jq gcc gforth gnucobol gfortran python3 make binutils xz-utils \
    clang-18 llvm-18-linker-tools libcurl4-openssl-dev \
    && rm -rf /var/lib/apt/lists/*

COPY . .

RUN mkdir -p vendor/llvm/usr/bin && \
    ln -s /usr/bin/clang-18 vendor/llvm/usr/bin/clang-18 && \
    mkdir -p vendor/llvm/usr/lib/x86_64-linux-gnu && \
    ln -s /usr/lib/x86_64-linux-gnu/libclang-cpp.so.18 vendor/llvm/usr/lib/x86_64-linux-gnu/ 2>/dev/null || true

RUN ARCH=$(uname -m); case "$ARCH" in \
      x86_64) DEB_ARCH=amd64 ;; aarch64) DEB_ARCH=arm64 ;; *) echo "unsupported $ARCH"; exit 1 ;; \
    esac && \
    curl -fsSL "https://github.com/sergev/blang/releases/download/v0.1/blang_0.1-1_${DEB_ARCH}.deb" -o /tmp/blang.deb && \
    TMPDIR=$(mktemp -d) && dpkg-deb -x /tmp/blang.deb "$TMPDIR" && \
    cp "$TMPDIR/usr/bin/blang" vendor/blang && \
    cp "$TMPDIR/usr/lib/libb.a" vendor/libb.a && \
    chmod +x vendor/blang && rm -rf "$TMPDIR"

RUN make -j"$(nproc)" all

FROM $BASE AS runtime
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update -qq && apt-get install -y -qq --no-install-recommends \
    curl jq gforth perl gawk python3 ca-certificates zstd libcurl4 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /opt/deepiri-tombstone
COPY --from=build /src/bin/ bin/
COPY --from=build /src/scripts/ scripts/
COPY --from=build /src/fixtures/ fixtures/
COPY --from=build /src/src/ src/
COPY --from=build /src/tests/ tests/
COPY --from=build /src/docs/ docs/
COPY --from=build /src/vendor/ vendor/
COPY --from=build /src/Makefile .
COPY --from=build /src/VERSION .
COPY --from=build /src/deepiri-tombstone ./deepiri-tombstone
COPY --from=build /src/.env.example .

RUN mkdir -p reports
ENV PATH="/opt/deepiri-tombstone/bin:/opt/deepiri-tombstone/scripts:${PATH}"
ENV DEEPIRI_TOMBSTONE_HOST=127.0.0.1:11434
ENV DEEPIRI_TOMBSTONE_MODEL=llama3.2

ENTRYPOINT ["bash", "/opt/deepiri-tombstone/deepiri-tombstone"]
CMD ["--help"]
