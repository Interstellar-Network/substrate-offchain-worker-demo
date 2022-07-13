################################################################################

# podman build -f Dockerfile -t ocw_demo:dev --volume ~/.cargo:/root/.cargo:rw --volume $(pwd)/target/release:/usr/src/app/target/release:rw .
# NOTE: it CAN work with Docker but it less than ideal b/c it can not reuse the host's cache
# NOTE: when dev/test: if you get "ninja: error: loading 'build.ninja': No such file or directory"
# -> FIX: find target/release/ -type d -name "*-wrapper-*" -exec rm -rf {} \;
# b/c docker build has no support for volume contrary to podman/buildah
# docker run -it --name ocw_demo --rm -p 3001:3000 --env RUST_LOG="warn,info,debug" ocw_demo:dev

FROM ghcr.io/interstellar-network/ci-images/ci-base-rust:dev as builder

WORKDIR /usr/src/app

# "error: 'rustfmt' is not installed for the toolchain '1.59.0-x86_64-unknown-linux-gnu'"
RUN rustup component add rustfmt

RUN apt-get update && apt-get install -y \
    libboost-dev \
    && rm -rf /var/lib/apt/lists/*

COPY . .
# MUST select a specific crate else "error: found a virtual manifest at `/usr/src/app/Cargo.toml` instead of a package manifest"
# node/ is indeed the only executable
RUN cargo install --path node

################################################################################

FROM ubuntu:20.04

EXPOSE 3000

ENV APP_NAME ocw_demo

ENV LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/local/lib

RUN apt-get update && apt-get install -y \
    libfreetype6 \
    && rm -rf /var/lib/apt/lists/*

# NOTE if "no shared libs to copy" above; we  MUST add a random file else COPY fails with:
# "copier: stat: ["/usr/local/lib/*.so"]: no such file or directory"
# cf https://stackoverflow.com/questions/31528384/conditional-copy-add-in-dockerfile
COPY --from=builder /usr/local/lib/no_shared_lib_to_copy /usr/local/lib/*.so /usr/local/lib/
COPY --from=builder /usr/local/cargo/bin/$APP_NAME /usr/local/bin/$APP_NAME
# TODO use CMake install and DO NOT hardcode a path
COPY --from=builder /usr/src/app/lib_garble_wrapper/deps/lib_garble/data /usr/src/app/lib_garble_wrapper/deps/lib_garble/data/

CMD ["sh", "-c", "$APP_NAME"]