ARG R10K_VERSION=3.15.2
FROM docker.io/puppet/r10k:${R10K_VERSION}
USER 0

ARG SUPERCRONIC_VERSION=v0.2.33
ARG TARGETARCH

# Set Supercronic checksums based on architecture
RUN if [ "$TARGETARCH" = "amd64" ]; then \
    echo "feefa310da569c81b99e1027b86b27b51e6ee9ab647747b49099645120cfc671  supercronic" > /tmp/supercronic.sha256; \
    elif [ "$TARGETARCH" = "arm64" ]; then \
    echo "f1f8585c66de020fef494dd636058f99949d108f569fef00016a1c8b9eb145b3  supercronic" > /tmp/supercronic.sha256; \
    else \
    echo "Unsupported architecture: $TARGETARCH" && exit 1; \
    fi

WORKDIR /usr/local/bin/
RUN apk add --no-cache \
    ca-certificates \
    curl \
    tini \
    && curl -fsSL "https://github.com/aptible/supercronic/releases/download/${SUPERCRONIC_VERSION}/supercronic-linux-${TARGETARCH}" -o supercronic \
    && sha256sum -c /tmp/supercronic.sha256 \
    && chmod +x supercronic \
    && rm /tmp/supercronic.sha256 \
    # clean up dependencies
    && apk del --purge \
    ca-certificates \
    curl \
    && rm -rf /var/cache/apk/

USER 999
RUN echo "DONE"
