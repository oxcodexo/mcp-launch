# AGENTS.md

This file describes the MCP servers available in this stack and the conventions agents should follow when using them.

## Overview

This stack exposes one or more MCP servers over a single stable HTTPS URL provided by ngrok. Each server is reachable at a distinct path prefix and protected by a shared bearer token.

```
https://<NGROK_DOMAIN>/<server>/mcp
```

## Authentication

Every request must include the bearer token:

```
Authorization: Bearer <MCP_BEARER_TOKEN>
```

The token is validated by `supergateway` before any tool is invoked. Requests without a valid token are rejected immediately.

## MCP Servers

### sandbox-mcp

**Endpoint:** `https://<NGROK_DOMAIN>/sandbox/mcp`

A self-contained Linux environment. The agent can run shell commands, read and write files, execute scripts, and use installed tools. All activity is confined to the `/workspace` directory, which is bind-mounted from the host.

**Available tools inside the sandbox:**

| Tool | Purpose |
|---|---|
| `bash`, `zsh` | Shell execution |
| `git` | Version control |
| `curl`, `wget` | HTTP requests and file downloads |
| `python3`, `pip` | Python scripting |
| `node`, `npm` | JavaScript / Node.js |
| `uvx` | Run Python tools via `uv` |
| `jq` | JSON processing |
| `vim` | File editing |
| `unzip` | Archive extraction |
| `build-essential` | C/C++ compilation toolchain |

**Workspace conventions:**
- `/workspace` is the only accessible path — nothing outside it is reachable
- Files written to `/workspace` persist on the host after the container stops
- Always read a file before modifying it
- Verify changes by reading back or running the result after every write

## Conventions

These apply across all MCP servers in this stack:

- **Never assume tool output** — only report results that were actually returned by a tool call
- **Plan before implementing** — for non-trivial changes, describe what will change and wait for explicit approval before executing
- **Targeted edits over full rewrites** — change only what needs to change; avoid rewriting files wholesale unless the scope requires it
