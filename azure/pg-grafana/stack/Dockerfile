# Single image bundling the Grafana metrics stack: Mimir + Alloy + Grafana,
# run together under supervisord.
FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        ca-certificates curl gnupg supervisor libfontconfig1

# Trust any extra CA certs placed in ./certs (e.g. a TLS-inspection egress
# proxy's root CA). The directory holds only .gitkeep by default, so this is a
# harmless no-op on a normal laptop. See the repo-root AGENTS.md for why this is
# needed inside the Claude sandbox.
COPY certs/ /usr/local/share/ca-certificates/
RUN update-ca-certificates

# Grafana + Alloy from the Grafana apt repo; Mimir from GitHub releases.
RUN mkdir -p /etc/apt/keyrings && \
    curl -fsSL https://apt.grafana.com/gpg.key | gpg --dearmor -o /etc/apt/keyrings/grafana.gpg && \
    echo "deb [signed-by=/etc/apt/keyrings/grafana.gpg] https://apt.grafana.com stable main" \
        > /etc/apt/sources.list.d/grafana.list && \
    apt-get update && \
    apt-get install -y --no-install-recommends grafana alloy && \
    rm -rf /var/lib/apt/lists/*

ARG MIMIR_VERSION=2.14.2
RUN curl -fsSL -o /usr/local/bin/mimir \
        "https://github.com/grafana/mimir/releases/download/mimir-${MIMIR_VERSION}/mimir-linux-amd64" && \
    chmod +x /usr/local/bin/mimir && \
    mkdir -p /data/mimir /var/lib/alloy

COPY mimir.yaml /etc/mimir/mimir.yaml
COPY alloy/config.alloy /etc/alloy/config.alloy
COPY grafana/provisioning /etc/grafana/provisioning
COPY grafana/dashboards /var/lib/grafana/dashboards
COPY supervisord.conf /etc/supervisor/conf.d/stack.conf

EXPOSE 3000
CMD ["/usr/bin/supervisord", "-n", "-c", "/etc/supervisor/supervisord.conf"]
