#!/usr/bin/env zsh

# Installs mcp-terminal as a systemd user service.
# Run once after cloning the repo.
#
# Usage:
#   cd /path/to/mcp-stack
#   chmod +x ./host/install.sh && ./host/install.sh

set -e

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SERVICE_NAME="mcp-terminal"
SYSTEMD_DIR="${HOME}/.config/systemd/user"
SERVICE_DEST="${SYSTEMD_DIR}/${SERVICE_NAME}.service"

echo "→ Project directory: ${PROJECT_DIR}"

# Ensure systemd user dir exists
mkdir -p "${SYSTEMD_DIR}"

# Substitute {{PROJECT_DIR}} in the template and write the service file
sed "s|{{PROJECT_DIR}}|${PROJECT_DIR}|g" \
  "${PROJECT_DIR}/host/${SERVICE_NAME}.service.template" \
  > "${SERVICE_DEST}"

echo "✓ Service file written to ${SERVICE_DEST}"

# Make the launch script executable
chmod +x "${PROJECT_DIR}/host/server-terminal-mcp.sh"

# Reload and enable
systemctl --user daemon-reload
systemctl --user enable --now "${SERVICE_NAME}"

echo "✓ ${SERVICE_NAME} enabled and started"
echo ""
echo "Useful commands:"
echo "  systemctl --user status ${SERVICE_NAME}"
echo "  journalctl --user -u ${SERVICE_NAME} -f"
echo "  systemctl --user restart ${SERVICE_NAME}"
