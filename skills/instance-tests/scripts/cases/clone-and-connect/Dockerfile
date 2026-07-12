# Fresh Linux "machine" for the clone-and-connect instance test. Empty HOME; dev
# tools pre-installed (a developer's machine has them). The per-mode logic
# (probe.sh / entrypoint.sh) is mounted at runtime, so this image is mode-agnostic
# and cached after the first build.
#
# A PRIVATE https origin needs credentials the container can use — extend this
# image (or the case run.sh mounts) with a read-only token/netrc for your host;
# never bake a secret into a layer.
FROM ubuntu:24.04
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update -qq && apt-get install -y -qq \
      git curl ca-certificates jq python3 sudo less unzip \
  && rm -rf /var/lib/apt/lists/*

RUN useradd -m -s /bin/bash newdev \
  && echo 'newdev ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/newdev

USER newdev
WORKDIR /home/newdev
# Headless claude for agent mode (self-contained installer; unused by probe).
RUN curl -fsSL https://claude.ai/install.sh | bash
ENV PATH="/home/newdev/.local/bin:${PATH}"
RUN mkdir -p /home/newdev/work
