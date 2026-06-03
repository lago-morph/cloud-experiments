# Tiny load generator: psql in a loop. Uses the official postgres image purely
# for a known-good psql client.
FROM postgres:16-alpine

COPY run-load.sh /usr/local/bin/run-load.sh
RUN chmod +x /usr/local/bin/run-load.sh

ENTRYPOINT ["/usr/local/bin/run-load.sh"]
