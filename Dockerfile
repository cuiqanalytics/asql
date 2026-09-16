# asql, containerized. No binary lives in this repo — the image fetches the same
# Linux release tarball the docs point users to, so `docker build` works from a clean
# checkout with nothing pre-staged locally.
FROM debian:trixie-slim AS fetch
RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates curl \
    && rm -rf /var/lib/apt/lists/*
RUN curl -fsSL https://github.com/cuiqanalytics/asql/releases/latest/download/asql-cli-linux-x86_64.tar.gz \
    | tar xz -C /opt \
    && mv /opt/asql-cli-linux-x86_64 /opt/asql

# The binary is dynamically linked against glibc, not statically linked or musl-based
# (static glibc breaks vduckdb's dlopen() of libduckdb.so - crashes at runtime instead of
# just failing to start) - so this image's glibc must be >= whatever version the release
# binary was built against, or you get "version `GLIBC_2.xx' not found". Pinned to
# trixie because that's what asql's own release-build machine runs; if that ever
# changes, bump this too (`ldd --version` on the build machine vs. in this image should
# never show the image behind).
FROM debian:trixie-slim
COPY --from=fetch /opt/asql/bin /usr/local/lib/asql/bin
RUN chmod +x /usr/local/lib/asql/bin/asql

# The layout is fixed here (unlike a native install, which resolves it relative to
# wherever the launcher script ends up), so LIBDUCKDB_DIR is just set once — no
# launcher script/symlink indirection needed in the container.
ENV LIBDUCKDB_DIR=/usr/local/lib/asql/bin
ENV PATH="/usr/local/lib/asql/bin:${PATH}"

# Reports are built against files in the caller's working directory, so the caller
# mounts it here: docker run --rm -v "$PWD:/work" ghcr.io/cuiqanalytics/asql build report.sql
WORKDIR /work
ENTRYPOINT ["asql"]
