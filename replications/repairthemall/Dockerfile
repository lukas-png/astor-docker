# =============================================================================
# Astor program-repair on top of Defects4J — RepairThemAll replication image.
#
# Layers Java 8 (Astor's runtime) and the Astor jar shipped by RepairThemAll
# onto the lukas-png/defects4j-docker image. The base provides Defects4J and
# Zulu OpenJDK 7 (needed to execute the old D4J bugs' test suites).
#
# Build with the repository root as build context (so resources/ is reachable):
#   docker build -t astor:1.4.0 --build-arg D4J_VERSION=1.4.0 .
# or just: ./build.sh
# =============================================================================
ARG D4J_VERSION=1.4.0
FROM ghcr.io/lukas-png/defects4j-docker:${D4J_VERSION}
LABEL org.opencontainers.image.source=https://github.com/lukas-png/docker-astor
LABEL org.opencontainers.image.licenses=MIT

USER root

# -----------------------------------------------------------------------------
# Java 8 (Astor's own runtime). The base image ships only Zulu 7, which is used
# to *execute* the bugs' tests. We add Zulu 8 via tarball (distro-independent;
# mirrors how the base installs Zulu 7) rather than relying on apt openjdk-8.
# -----------------------------------------------------------------------------
ENV ZULU8_TGZ=zulu8.78.0.19-ca-jdk8.0.412-linux_x64.tar.gz
COPY resources/${ZULU8_TGZ} /tmp/
RUN mkdir -p /opt/jdks && \
    tar -xzf /tmp/${ZULU8_TGZ} -C /opt/jdks && \
    rm /tmp/${ZULU8_TGZ}

ENV JAVA7_HOME=/opt/jdks/zulu7.56.0.11-ca-jdk7.0.352-linux_x64
ENV JAVA8_HOME=/opt/jdks/zulu8.78.0.19-ca-jdk8.0.412-linux_x64
ENV ASTOR_HOME=/opt/astor

# -----------------------------------------------------------------------------
# Astor (the exact pinned jar used by RepairThemAll) + run wrapper.
# jtestex7.jar must precede astor.jar on the classpath at runtime.
# d4j-compliance.tsv lets run-astor pass each bug's Defects4J source compliance to
# -javacompliancelevel, matching the experiment's per-bug invocation.
# -----------------------------------------------------------------------------
COPY resources/astor.jar          /opt/astor/astor.jar
COPY resources/jtestex7.jar       /opt/astor/lib/jtestex7.jar
COPY resources/d4j-compliance.tsv /opt/astor/d4j-compliance.tsv
COPY resources/run-astor          /usr/local/bin/run-astor
RUN chmod +x /usr/local/bin/run-astor

USER user
WORKDIR /work
CMD ["bash"]
