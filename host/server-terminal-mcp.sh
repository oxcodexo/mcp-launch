#!/usr/bin/env zsh

# Host-level terminal MCP exposed through supergateway on port 9002
# Requires:
#   - uv / uvx installed on the host  (https://docs.astral.sh/uv/getting-started/installation/)
#   - MCP_BEARER_TOKEN set in environment or in ../.env

# Load .env from project root if not already set
if [[ -z "${MCP_BEARER_TOKEN}" ]] && [[ -f "$(dirname $0)/../.env" ]]; then
  source "$(dirname $0)/../.env"
fi

: "${MCP_BEARER_TOKEN:=my_api_key}"

npx supergateway \
  --stdio "uvx terminal_controller" \
  --outputTransport streamableHttp \
  --streamableHttpPath /mcp \
  --port 9002 \
  --bearerToken "${MCP_BEARER_TOKEN}"
