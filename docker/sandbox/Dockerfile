FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

# Build-time UID/GID — match your host user so files created in /workspace
# are owned by you on the host (not root). Pass with:
#   docker compose build (reads from .env automatically via docker-compose.yml args)
ARG UID=1000
ARG GID=1000

# Core tools the agent can use inside the sandbox
RUN apt-get update && apt-get install -y \
    curl \
    git \
    zsh \
    vim \
    jq \
    wget \
    unzip \
    build-essential \
    python3 \
    python3-pip \
    nodejs \
    npm \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Install supergateway globally
RUN npm install -g supergateway

# Create a non-root user matching the host UID/GID
RUN groupadd --non-unique -g ${GID} sandbox && \
    useradd --non-unique -m -u ${UID} -g ${GID} -s /bin/bash sandbox

# Switch to the sandbox user for all remaining steps
USER sandbox
WORKDIR /home/sandbox

# Install uv into the sandbox user's home so it's accessible at runtime
RUN curl -LsSf https://astral.sh/uv/install.sh | sh
ENV PATH="/home/sandbox/.local/bin:$PATH"

# Pre-warm uvx cache for terminal_controller so first run is instant
RUN uvx terminal_controller --help > /dev/null 2>&1 || true

WORKDIR /workspace

ENTRYPOINT ["supergateway"]
