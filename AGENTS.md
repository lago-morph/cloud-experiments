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
