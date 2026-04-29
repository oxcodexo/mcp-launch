# MCP Launch

A self-hosted, Docker-based stack for running MCP servers on your laptop and exposing them securely to any AI agent over the internet. New MCP servers plug in by adding a service and a single route — no changes to ngrok, Caddy, or any other part of the infrastructure.

## How It Works

```
AI Agent
  └── https://<NGROK_DOMAIN>/<server>/mcp
        └── ngrok  →  caddy :9876
                       ├── /sandbox/*  →  sandbox-mcp:9002
                       ├── /my-tool/*  →  my-tool-mcp:9003
                       └── ...more as needed
```

Each MCP server runs as an isolated Docker container. Caddy sits in front and routes by path prefix. ngrok gives every MCP a stable public HTTPS URL. A shared bearer token protects all endpoints — validated by `supergateway` on every incoming request, before any tool is executed.

## Prerequisites

- **Docker** — [Install Docker](https://docs.docker.com/get-docker/)
- **Docker Compose v2** — included with Docker Desktop; on Linux run `docker compose version` to confirm (requires v2.x)
- **ngrok account** — [Sign up free](https://ngrok.com). You need:
  - An auth token (from the [ngrok dashboard](https://dashboard.ngrok.com/get-started/your-authtoken))
  - A static domain (one free static domain per account — create yours at [ngrok dashboard → Domains](https://dashboard.ngrok.com/domains))

## Project Structure

```
mcp-launch/
├── docker/
│   └── sandbox/
│       └── Dockerfile        ← custom image for the sandbox MCP
├── docker-compose.yml        ← all services: caddy, ngrok, MCP servers
├── Caddyfile                 ← routing rules, one route per MCP server
├── .env                      ← secrets (gitignored)
├── .env.example              ← safe template to commit
├── .gitignore
└── README.md
```

## Infrastructure Services

These run once and never change when you add more MCPs:

| Service | Port | Description |
|---|---|---|
| `caddy` | 9876 | Reverse proxy — routes requests by path prefix to the right MCP container |
| `ngrok` | 4040 | Exposes Caddy to the internet at a stable HTTPS URL |

## MCP Servers

Currently included:

| Service | Endpoint | Description |
|---|---|---|
| `sandbox-mcp` | `/sandbox/mcp` | A self-contained Linux environment the agent can freely operate in — run shell commands, read and write files, execute scripts, and use installed tools. Isolated from the host OS; only the mounted `/workspace` directory is accessible. |

## Adding a New MCP Server

The stack is designed to grow. To add any MCP server:

> **Naming convention:** name your service `<name>-mcp` and use `/<name>/*` as its Caddy route prefix.
> The shared root (`<name>`) ties the service name, the route, and the public URL together.
> e.g. `my-tool-mcp` → `/my-tool/*` → `https://<NGROK_DOMAIN>/my-tool/mcp`

> **Port convention:** assign each new MCP server the next available internal port, starting from `9002`.
> `sandbox-mcp` uses `9002`, so the next server gets `9003`, then `9004`, and so on.
> Ports are internal only (`expose:`, not `ports:`) — they never conflict with anything on your host.

**1. Add the service in `docker-compose.yml`:**

```yaml
my-tool-mcp:
  image: ghcr.io/supercorp-ai/supergateway:latest
  command: >
    --stdio "npx @some-scope/my-tool-mcp"
    --outputTransport streamableHttp
    --streamableHttpPath /mcp
    --port 9003
    --bearerToken "${MCP_BEARER_TOKEN}"
  expose:
    - "9003"
  restart: unless-stopped
```

**2. Add the route in `Caddyfile`:**

```caddy
route /my-tool/* {
    uri strip_prefix /my-tool
    reverse_proxy my-tool-mcp:9003
}
```

**3. Restart:**

```bash
docker compose up -d
```

Your new MCP is now live at `https://<NGROK_DOMAIN>/my-tool/mcp`. Nothing else changes.

## Setup

### 1. Configure environment

```bash
cp .env.example .env
# edit .env with your values
```

| Variable | Description |
|---|---|
| `MCP_BEARER_TOKEN` | Shared secret required by all MCP endpoints |
| `NGROK_AUTHTOKEN` | From https://dashboard.ngrok.com/get-started/your-authtoken |
| `NGROK_DOMAIN` | Your static ngrok domain, e.g. `worthy-gorgeous-guppy.ngrok-free.app` |
| `SANDBOX_MOUNT_PATH` | Host directory mounted into `/workspace` inside the sandbox container |
| `UID` / `GID` | **Linux only.** Your host user's IDs — run `id -u` and `id -g` to get them. Passed as build args so files the sandbox creates in `/workspace` are owned by you, not root. Mac and Windows users can leave these unset. |

**Getting your ngrok static domain:**
1. Log in to the [ngrok dashboard](https://dashboard.ngrok.com)
2. Go to **Domains** → **New Domain** — your free static domain is created instantly
3. Copy the full domain (e.g. `worthy-gorgeous-guppy.ngrok-free.app`) into `NGROK_DOMAIN`

### 2. Build and start

```bash
docker compose up -d --build
```

### 3. Inspect ngrok

```bash
open http://localhost:4040
```

Confirm the tunnel shows **online** and the URL matches your `NGROK_DOMAIN`.

## Endpoints

| MCP Server | Public URL |
|---|---|
| Sandbox | `https://<NGROK_DOMAIN>/sandbox/mcp` |

All requests require: `Authorization: Bearer <MCP_BEARER_TOKEN>`

## Agent Config

```json
{
  "mcpServers": {
    "sandbox": {
      "url": "https://<NGROK_DOMAIN>/sandbox/mcp",
      "headers": { "Authorization": "Bearer <MCP_BEARER_TOKEN>" }
    }
  }
}
```

## Useful Commands

```bash
# Build and start
docker compose up -d --build

# Stop
docker compose down

# Tail all logs
docker compose logs -f

# Restart a single service
docker compose restart sandbox-mcp

# Pull latest images and restart
docker compose pull && docker compose up -d --build
```

## Troubleshooting

**ngrok tunnel is offline**
- Check `NGROK_AUTHTOKEN` is correct and not expired
- Confirm `NGROK_DOMAIN` exactly matches the domain in your ngrok dashboard — including the full subdomain
- Run `docker compose logs ngrok` for the raw error

**Agent gets a 401 Unauthorized**
- The bearer token is enforced by `supergateway` inside each MCP container, not by Caddy or ngrok
- Verify the `Authorization: Bearer <token>` header in your agent config matches `MCP_BEARER_TOKEN` in `.env` exactly (no extra spaces or quotes)
- Run `docker compose logs sandbox-mcp` to see rejected requests

**`uvx` or `supergateway` not found inside the container**
- This usually means the image wasn't rebuilt after a Dockerfile change
- Run `docker compose build sandbox-mcp` then `docker compose up -d`

**Port 9876 already in use on the host**
- Another process is using port 9876. Either stop it, or change the host port mapping in `docker-compose.yml`:
  ```yaml
  ports:
    - "9877:9876"  # change the left side only
  ```

**Files created by the sandbox are owned by root on the host (Linux only)**
- Set `UID` and `GID` in your `.env` to match your host user (`id -u` and `id -g`)
- Rebuild: `docker compose build sandbox-mcp && docker compose up -d`

## Security Notes

- All endpoints are protected by a bearer token — use a strong, unique `MCP_BEARER_TOKEN`. The token is validated by `supergateway` on every request before any tool is invoked; neither Caddy nor ngrok perform token checks
- The sandbox agent can fully read, write, and execute within `/workspace` only
- Mount only what the agent needs — do not mount your home directory or sensitive paths
- Never commit `.env` to git
- Keep your ngrok domain private to limit who can reach your endpoints

## License

MIT License — see [LICENSE](./LICENSE) for full details.

Copyright (c) 2026 oxcodexo
