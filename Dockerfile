# anyremote-rdv — servidor de encuentro (rendezvous) + relay de anyremote.
# Imagen multi-etapa: build en Rust (cachea dependencias mientras no cambien
# Cargo.toml/Cargo.lock) y runtime mínimo debian-slim (sin OpenSSL: todo es
# Rust puro — ed25519-dalek/curve25519 son Rust).
FROM rust:1-bookworm AS builder
WORKDIR /build

# 1) Capa de dependencias (se reutiliza mientras solo cambie src/): se deja
#    el árbol compilado de deps; al tocar src/ recompila solo el paquete.
COPY Cargo.toml Cargo.lock ./
RUN mkdir -p src \
    && echo 'pub fn placeholder() {}' > src/lib.rs \
    && echo 'fn main() {}' > src/main.rs \
    && cargo build --release --locked \
    && rm -rf src

# 2) Código real.
COPY src ./src
RUN touch src/lib.rs src/main.rs && cargo build --release --locked

FROM debian:bookworm-slim
LABEL org.opencontainers.image.title="serveremote" \
      org.opencontainers.image.description="anyremote rendezvous + relay (anyremote-rdv-v1)"
COPY --from=builder /build/target/release/serveremote /usr/local/bin/serveremote

EXPOSE 21120/tcp
# Vive en memoria (sin volumen): los hosts re-registran cada 30 s → el
# reinicio se auto-sanita. Usa --restart unless-stopped en producción.
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s \
  CMD timeout 2 bash -c '</dev/tcp/127.0.0.1/21120' || exit 1

ENTRYPOINT ["/usr/local/bin/serveremote", "--bind", "0.0.0.0:21120"]
