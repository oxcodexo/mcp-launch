FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

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

# Install uv (provides uvx for running MCP tools)
RUN curl -LsSf https://astral.sh/uv/install.sh | sh
ENV PATH="/root/.local/bin:$PATH"

# Install supergateway globally
RUN npm install -g supergateway

# Pre-warm uvx cache for terminal_controller so first run is instant
RUN uvx terminal_controller --help > /dev/null 2>&1 || true

WORKDIR /workspace

ENTRYPOINT ["supergateway"]
