# MCP Stack

A self-hosted MCP server stack that runs on your laptop and exposes AI tools to any agent over the internet via ngrok. Each MCP server is accessible at a dedicated path behind a shared Caddy reverse proxy, all protected by a bearer token.

## Project Structure

```
mcp-stack/
├── docker/
│   ├── docker-compose.yml       ← filesystem MCP + caddy + ngrok
│   └── Caddyfile                ← reverse proxy routing rules
├── host/
│   ├── server-terminal-mcp.sh  ← run terminal MCP natively on the host
│   ├── mcp-terminal.service.template  ← systemd service template
│   └── install.sh              ← one-time setup script
├── .env                     ← secrets (gitignored)
├── .env.example             ← safe template to commit
├── .gitignore
└── README.md
```

## Architecture

```
Internet
  └── ngrok (your-domain.ngrok-free.app)
        └── caddy :9876
              ├── /filesystem/mcp  →  mcp-filesystem container (Docker, :9001)
              └── /terminal/mcp    →  terminal MCP process (host, :9002)
```

Each MCP server runs behind Caddy as a reverse proxy. Caddy routes requests by path prefix, strips it, and forwards to the appropriate upstream. ngrok tunnels the entire gateway to a stable public URL.

## Services

| Service | Where | Port | Description |
|---|---|---|---|
| `mcp-filesystem` | Docker bridge | 9001 | Scoped filesystem access via `@modelcontextprotocol/server-filesystem` |
| `mcp-terminal` | Host process | 9002 | Real laptop shell access via `uvx terminal_controller` |
| `caddy` | Docker bridge | 9876 | Reverse proxy, single entry point for all MCPs |
| `ngrok` | Docker bridge | 4040 | Tunnels caddy:9876 to a public HTTPS URL |

## Why Terminal MCP Runs on the Host (Not in Docker)

Most MCP servers run inside Docker containers — isolated, reproducible, and easy to manage. The terminal MCP is the exception.

The terminal MCP works by executing shell commands on behalf of the agent. If it runs inside a Docker container, it can only execute commands inside that container — a stripped-down environment with no access to your actual laptop, your installed tools, your home directory, or your running processes. That defeats the entire purpose.

To give the agent real shell access to the host machine, the terminal MCP must run as a native process directly on your laptop. Caddy then proxies `/terminal/mcp` to it via `host.docker.internal:9002`, bridging the Docker network and the host seamlessly.

> **This is optional.** If you don't need the agent to run shell commands on your laptop, you can skip the `host/` setup entirely. The Docker stack runs fine without it — just remove the `/terminal/*` route from the `Caddyfile`.

## Adding More MCP Servers

All other MCP servers (databases, APIs, browser tools, etc.) should run inside Docker — just add a new service to `docker/docker-compose.yml` and a new route in `docker/Caddyfile`.

### Example: adding a new MCP

**1. Add the service in `docker/docker-compose.yml`:**

```yaml
mcp-my-tool:
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

**2. Add the route in `docker/Caddyfile`:**

```
route /my-tool/* {
    uri strip_prefix /my-tool
    reverse_proxy mcp-my-tool:9003
}
```

**3. Restart the stack:**

```bash
cd docker/ && docker compose up -d
```

Your new MCP is now live at `/my-tool/mcp` — no changes to ngrok or anything else needed.

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
| `NGROK_DOMAIN` | Your static ngrok domain (e.g. `worthy-gorgeous-guppy.ngrok-free.app`) |

### 2. Start the Docker stack

```bash
cd docker/ && docker compose up -d
```

### 3. (Optional) Install the host terminal MCP

Skip this if you don't need shell access from the agent.

```bash
chmod +x ./host/install.sh && ./host/install.sh
```

This script resolves the project directory, generates the systemd service file from the template, and enables it. After install:

```bash
systemctl --user status mcp-terminal
```

### 4. Get your public ngrok URL

```bash
# Dashboard
open http://localhost:4040

# Or from logs
cd docker/ && docker compose logs ngrok | grep url
```

## Endpoints

| MCP Server | Local URL | Public URL |
|---|---|---|
| Filesystem | `http://localhost:9876/filesystem/mcp` | `https://<NGROK_DOMAIN>/filesystem/mcp` |
| Terminal *(optional)* | `http://localhost:9876/terminal/mcp` | `https://<NGROK_DOMAIN>/terminal/mcp` |

All endpoints require: `Authorization: Bearer <MCP_BEARER_TOKEN>`

## Agent Config

```json
{
  "mcpServers": {
    "filesystem": {
      "url": "https://<NGROK_DOMAIN>/filesystem/mcp",
      "headers": { "Authorization": "Bearer <MCP_BEARER_TOKEN>" }
    },
    "terminal": {
      "url": "https://<NGROK_DOMAIN>/terminal/mcp",
      "headers": { "Authorization": "Bearer <MCP_BEARER_TOKEN>" }
    }
  }
}
```

## Useful Commands

```bash
# Start / stop Docker stack
cd docker/ && docker compose up -d
cd docker/ && docker compose down

# View logs
cd docker/ && docker compose logs -f

# Restart a single service
cd docker/ && docker compose restart mcp-filesystem

# Update all images
cd docker/ && docker compose pull && docker compose up -d

# Terminal MCP (host)
systemctl --user status mcp-terminal
systemctl --user restart mcp-terminal
journalctl --user -u mcp-terminal -f
```

## Security Notes

- The terminal MCP has real shell access to your laptop — only expose it if you trust the agent and the network path
- Never commit `.env` or the generated `host/mcp-terminal.service` to git (both are gitignored)
- Use a strong, unique `MCP_BEARER_TOKEN`
- Keep your ngrok domain private to limit who can reach your endpoints
