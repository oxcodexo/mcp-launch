# MCP Stack

A self-hosted MCP server stack running on your laptop, exposed to the internet via ngrok.

## Architecture

```
Internet
  └── ngrok (public HTTPS URL)
        └── caddy :9876
              ├── /filesystem/mcp  →  mcp-filesystem container (bridge)
              └── /terminal/mcp    →  mcp-terminal (host network, port 9002)
```

## Services

| Service | Network | Port | Description |
|---|---|---|---|
| `mcp-filesystem` | bridge | 9001 (internal) | Obsidian KB read-only via `@modelcontextprotocol/server-filesystem` |
| `mcp-terminal` | **host** | 9002 | Real laptop shell access via `@GongRzhe/terminal-controller-mcp` |
| `caddy` | bridge | 9876 (public) | Reverse proxy, routes by path |
| `ngrok` | bridge | 4040 (dashboard) | Exposes caddy:9876 to the internet |

## Setup

### 1. Fill in `.env`

```bash
cp .env .env  # already created, just edit it
```

Set your values:
- `MCP_BEARER_TOKEN` — shared secret used by all MCP endpoints
- `NGROK_AUTHTOKEN` — from https://dashboard.ngrok.com/get-started/your-authtoken

### 2. Linux: enable `host.docker.internal`

On Linux, `host.docker.internal` doesn't resolve automatically.
Add this to your `docker-compose.yml` under the `caddy` service if needed:

```yaml
extra_hosts:
  - "host.docker.internal:host-gateway"
```

Or add to `/etc/hosts`:
```
172.17.0.1  host.docker.internal
```

### 3. Start the stack

```bash
docker compose up -d
```

### 4. Get your public ngrok URL

```bash
# Option A: dashboard
open http://localhost:4040

# Option B: CLI
docker compose logs ngrok | grep "url="
```

## Endpoints

| MCP Server | Local URL | Public URL |
|---|---|---|
| Filesystem | `http://localhost:9876/filesystem/mcp` | `https://<ngrok-id>.ngrok-free.app/filesystem/mcp` |
| Terminal | `http://localhost:9876/terminal/mcp` | `https://<ngrok-id>.ngrok-free.app/terminal/mcp` |

All endpoints require: `Authorization: Bearer <MCP_BEARER_TOKEN>`

## Agent Config (Claude Desktop / Cursor)

```json
{
  "mcpServers": {
    "obsidian-kb": {
      "url": "https://<ngrok-id>.ngrok-free.app/filesystem/mcp",
      "headers": { "Authorization": "Bearer my_api_key" }
    },
    "laptop-terminal": {
      "url": "https://<ngrok-id>.ngrok-free.app/terminal/mcp",
      "headers": { "Authorization": "Bearer my_api_key" }
    }
  }
}
```

## Useful Commands

```bash
# Start
docker compose up -d

# Stop
docker compose down

# View logs
docker compose logs -f

# Restart a single service
docker compose restart mcp-filesystem

# Pull latest images
docker compose pull && docker compose up -d
```

## Security Notes

- `mcp-terminal` uses `network_mode: host` — it has full access to your laptop's filesystem and processes
- Never share your `MCP_BEARER_TOKEN` or commit `.env` to git
- Consider using a [ngrok static domain](https://ngrok.com/docs/network-edge/domains/) to keep a stable public URL
