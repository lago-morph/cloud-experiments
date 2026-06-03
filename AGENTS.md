# Agent Notes

## Docker in the Claude sandbox

Docker **is** available in the Claude sandbox — it just isn't running by default.
You don't need to install anything; you only have to start the Docker daemon
before using `docker` commands.

Start it with:

```bash
sudo dockerd > /tmp/dockerd.log 2>&1 &
```

Then wait a moment and verify it's up:

```bash
docker info
```

Once the daemon is running, `docker build`, `docker run`, etc. work as normal.

## Outbound TLS from inside containers (egress proxy CA)

The sandbox routes outbound traffic through an **egress TLS-inspection proxy**.
The proxy terminates and re-signs TLS with its own root CA
(`Anthropic … sandbox-egress-production TLS Inspection CA`). The host's trust
store already includes this CA, so `curl`/`apt`/`terraform` work from the host
shell — but **containers do not trust it by default**, so any TLS you do from
inside a container (or a `docker build` `RUN` step) fails with errors like:

```
curl failed to verify the legitimacy of the server ...
gpg: no valid OpenPGP data found
```

To fix it, **transplant the proxy's CA into the container's trust store.** The
proxy root CAs live on the host at:

```
/usr/local/share/ca-certificates/*.crt
```

In a Dockerfile, copy them in and refresh the trust store **before** any TLS
fetch (Debian/Ubuntu shown; on Alpine use `apk add ca-certificates` then
`update-ca-certificates`):

```dockerfile
COPY certs/ /usr/local/share/ca-certificates/   # contains the host's *.crt
RUN update-ca-certificates
```

A laptop-safe pattern is to keep a `certs/` dir holding only a `.gitkeep`
(committed) and copy the host CAs into it at build time (gitignored): the `COPY`
+ `update-ca-certificates` is a harmless no-op when the dir is empty, and picks
up the proxy CA inside the sandbox.

Notes:
- Use the **default bridge network** for builds/containers so traffic is routed
  through the proxy. `--network host` bypasses the proxy and just times out.
- This only matters when the container **verifies** the server certificate.
  Connections that skip verification (e.g. Postgres `sslmode=require`) work
  without the CA, since no validation is performed.
- For image pulls, set a registry mirror (`registry-mirrors:
  ["https://mirror.gcr.io"]` in `/etc/docker/daemon.json`) to avoid Docker Hub's
  anonymous rate limits.
