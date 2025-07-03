FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive
ARG SSG_VER=0.1.76            # ← current version in Debian pool

# 1️⃣ tools + bzip2 + wget
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    nmap \
    openscap-scanner \
    curl \
    ca-certificates \
    bzip2 \
    wget \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# 2️⃣ grab the two .deb archives that hold the data-stream
RUN wget -qO /tmp/ssg-base.deb    http://ftp.debian.org/debian/pool/main/s/scap-security-guide/ssg-base_${SSG_VER}-1_all.deb \
    && wget -qO /tmp/ssg-debian.deb  http://ftp.debian.org/debian/pool/main/s/scap-security-guide/ssg-debian_${SSG_VER}-1_all.deb \
    && apt-get update \
    && apt-get install -y --no-install-recommends /tmp/ssg-base.deb /tmp/ssg-debian.deb \
    && rm -rf /var/lib/apt/lists/* /tmp/ssg-*.deb

# 3️⃣ non-root user
RUN useradd -m collector
USER collector
WORKDIR /home/collector

# 4️⃣ entry-point
COPY --chown=collector entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
