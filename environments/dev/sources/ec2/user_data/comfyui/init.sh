#!/bin/bash
set -euo pipefail

COMFY_DIR="/home/ubuntu/ComfyUI"

# ===== enable systemd service =====
if [ -d "${COMFY_DIR}" ]; then
  echo "[init] ComfyUI directory found. Enabling systemd service..."
  systemctl daemon-reload
  systemctl enable comfyui
  systemctl start comfyui
else
  echo "[init] ComfyUI directory not found. Skipping systemd setup."
fi
