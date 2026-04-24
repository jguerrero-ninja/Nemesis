#!/usr/bin/env bash
# install.sh — Setup script for Phantom browser automation agent
#
# Usage:
#   ./install.sh --channel "#my-channel" --channel-id "C0AAAAMBR1R"
#
# What this does:
#   1. Installs Python dependencies (requirements.txt)
#   2. Creates the logs directory
#   3. Configures Slack channel (agent is always 'phantom')
#   4. Installs and enables phantom-sync.service, phantom.service, phantom-monitor.service, and phantom-dashboard.service
#
# Prerequisites (must be provided manually — not handled by this script):
#   - s3_config.json at repo root or /root/  (AWS credentials for Slack S3 cache)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- Parse arguments --------------------------------------------------------
SLACK_CHANNEL=""
SLACK_CHANNEL_ID=""
SLACK_AGENT="phantom"  # always phantom — only one agent in this repo

usage() {
    echo "Usage: $0 --channel CHANNEL --channel-id CHANNEL_ID"
    echo ""
    echo "Options:"
    echo "  --channel CHANNEL        Slack channel name (required, e.g. '#my-channel')"
    echo "  --channel-id CHANNEL_ID  Slack channel ID (required, e.g. 'C0AAAAMBR1R')"
    echo "  --help                   Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 --channel '#my-channel' --channel-id 'C0AAAAMBR1R'"
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --channel)    SLACK_CHANNEL="$2"; shift 2 ;;
        --channel-id) SLACK_CHANNEL_ID="$2"; shift 2 ;;
        --help|-h) usage; exit 0 ;;
        *) echo "Unknown option: $1"; usage; exit 1 ;;
    esac
done

if [[ -z "$SLACK_CHANNEL" || -z "$SLACK_CHANNEL_ID" ]]; then
    echo "ERROR: --channel and --channel-id are required"
    usage
    exit 1
fi

echo "=== Phantom Browser Automation — Setup ==="
echo ""

# --- 1. Python dependencies -------------------------------------------------
echo "▶ Installing Python dependencies..."
pip install -q -r "$SCRIPT_DIR/requirements.txt"
echo "  ✓ Python packages installed"

# Ensure the phantom package is importable by adding its parent to PYTHONPATH
PHANTOM_PARENT="$(cd "$SCRIPT_DIR/.." && pwd)"
if ! grep -q "$PHANTOM_PARENT" /etc/environment 2>/dev/null; then
    echo "PYTHONPATH=\"${PHANTOM_PARENT}:\${PYTHONPATH:-}\"" >> /etc/environment
fi
export PYTHONPATH="${PHANTOM_PARENT}:${PYTHONPATH:-}"
echo "  ✓ PYTHONPATH configured (${PHANTOM_PARENT})"

# --- 2. Log directory -------------------------------------------------------
mkdir -p /workspace/logs
echo "  ✓ Log directory ready (/workspace/logs)"

# --- 3. Slack configuration — must come before systemd step ----------------
echo ""
echo "▶ Configuring Slack..."

# Verify s3_config.json exists before invoking slack_interface.py
S3_CONFIG_FOUND=false
for candidate in "/root/s3_config.json" "$SCRIPT_DIR/s3_config.json" "/root/ninja-squad/s3_config.json" "/workspace/ninja-squad/s3_config.json"; do
    if [[ -f "$candidate" ]]; then
        S3_CONFIG_FOUND=true
        break
    fi
done

if [[ "$S3_CONFIG_FOUND" != "true" ]]; then
    echo "  ✗ s3_config.json not found — cannot configure Slack"
    echo "    Create s3_config.json (at repo root or /root/) with:"
    echo "      aws_access_key_id, aws_secret_access_key, bucket_name"
    echo "    Then re-run: $0 --channel '$SLACK_CHANNEL'"
    exit 1
fi

python "$SCRIPT_DIR/slack_interface.py" config --set-channel "$SLACK_CHANNEL" --set-channel-id "$SLACK_CHANNEL_ID"
echo "  ✓ Slack channel set to: $SLACK_CHANNEL"

python "$SCRIPT_DIR/slack_interface.py" config --set-agent "$SLACK_AGENT"
echo "  ✓ Slack agent set to: $SLACK_AGENT (phantom)"

# --- 4. Systemd services ----------------------------------------------------
echo ""
echo "▶ Installing systemd services..."
cp "$SCRIPT_DIR/systemd/phantom-sync.service" /etc/systemd/system/phantom-sync.service
cp "$SCRIPT_DIR/systemd/phantom.service"              /etc/systemd/system/phantom.service
cp "$SCRIPT_DIR/systemd/phantom-monitor.service"      /etc/systemd/system/phantom-monitor.service
cp "$SCRIPT_DIR/systemd/phantom-dashboard.service"    /etc/systemd/system/phantom-dashboard.service
systemctl daemon-reload
systemctl enable phantom-sync.service phantom.service phantom-monitor.service phantom-dashboard.service
systemctl start  phantom-sync.service phantom.service phantom-monitor.service phantom-dashboard.service
echo "  ✓ phantom-sync.service installed, enabled and started (removes superninja config, syncs workspace to git)"
echo "  ✓ phantom.service installed and enabled (single work cycle, restarts on failure)"
echo "  ✓ phantom-monitor.service installed, enabled and started (continuous Slack watcher)"
echo "  ✓ phantom-dashboard.service installed, enabled and started (port 9000)"

# --- 5. VNC password-free configuration ------------------------------------
echo ""
echo "▶ Configuring VNC (removing password requirement)..."

SUPERVISOR_CONF="/etc/supervisor/conf.d/supervisord.conf"

if [[ -f "$SUPERVISOR_CONF" ]]; then
    # Replace -rfbauth flag with -nopw in x11vnc command
    sed -i 's|x11vnc -display :99 -forever -shared -rfbauth /root/.vnc/passwd -rfbport 5901|x11vnc -display :99 -forever -shared -nopw -rfbport 5901|g' "$SUPERVISOR_CONF"

    # Force supervisord to reread and apply updated config
    supervisorctl reread
    supervisorctl update
    supervisorctl restart x11vnc

    echo "  ✓ VNC configured to run without password (-nopw)"
    echo "  ✓ x11vnc restarted with new config"
else
    echo "  ⚠ Supervisor config not found at $SUPERVISOR_CONF — skipping VNC patch"
fi

# --- Done -------------------------------------------------------------------
echo ""
echo "=== Setup complete ==="
echo ""

echo "Useful commands:"
echo "  systemctl status <service_name>             # Check service status"
echo "  journalctl -u <service_name> -f             # Follow service logs"
echo "  Dashboard: http://localhost:9000"
