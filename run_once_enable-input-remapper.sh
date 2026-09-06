#!/bin/bash
set -euo pipefail

if command -v input-remapper-service >/dev/null 2>&1 || systemctl list-unit-files | grep -q '^input-remapper'; then
    sudo systemctl enable --now input-remapper
fi
