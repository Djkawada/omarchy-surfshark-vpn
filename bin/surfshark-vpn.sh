#!/usr/bin/env bash
set -euo pipefail

ACTION="${1:-status}"
ARG="${2:-}"
CONFIG_DIR="$HOME/.config/surfshark-vpn/configs"
STATE_FILE="$HOME/.config/surfshark-vpn/state.json"

case "$ACTION" in
  connect)
    if [ -z "$ARG" ]; then
      echo '{"success":false,"error":"No profile provided"}'
      exit 1
    fi
    PROFILE="${ARG#surfshark-}"
    PROFILE="${PROFILE#surfshark_}"
    CONF_FILE="$CONFIG_DIR/$PROFILE.conf"
    
    if [ ! -f "$CONF_FILE" ]; then
      echo "{\"success\":false,\"error\":\"File not found: $CONF_FILE\"}"
      exit 1
    fi
    
    # 1. Disconnect and delete any existing wireguard connections
    for c in $(nmcli -t -f NAME,TYPE connection show | grep ':wireguard$' | cut -d: -f1); do
      nmcli connection down "$c" >/dev/null 2>&1 || true
      nmcli connection delete "$c" >/dev/null 2>&1 || true
    done
    
    # 2. Import, configure and activate
    nmcli connection import type wireguard file "$CONF_FILE" >/dev/null
    nmcli connection modify "$PROFILE" connection.autoconnect no >/dev/null
    nmcli connection up "$PROFILE" >/dev/null
    
    # 3. Update state
    if [ -f "$STATE_FILE" ]; then
      sed -i 's/"last_profile": *"[^"]*"/"last_profile": "'"$PROFILE"'"/' "$STATE_FILE" 2>/dev/null || true
      sed -i 's/"last_profile": *null/"last_profile": "'"$PROFILE"'"/' "$STATE_FILE" 2>/dev/null || true
    fi
    
    echo "{\"success\":true,\"connected\":true,\"profile\":\"$PROFILE\"}"
    ;;
    
  disconnect)
    for c in $(nmcli -t -f NAME,TYPE connection show | grep ':wireguard$' | cut -d: -f1); do
      nmcli connection down "$c" >/dev/null 2>&1 || true
      nmcli connection delete "$c" >/dev/null 2>&1 || true
    done
    if [ -f "$STATE_FILE" ]; then
      sed -i 's/"last_profile": *"[^"]*"/"last_profile": null/' "$STATE_FILE" 2>/dev/null || true
      sed -i 's/"last_ip": *"[^"]*"/"last_ip": "—"/' "$STATE_FILE" 2>/dev/null || true
    fi
    echo '{"success":true,"connected":false}'
    ;;
esac
