#!/usr/bin/env bash
set -euo pipefail

ACTION="${1:-status}"
ARG="${2:-}"
CONFIG_DIR="$HOME/.config/surfshark-vpn/configs"
STATE_FILE="$HOME/.config/surfshark-vpn/state.json"
CONN_PREFIX="surfshark-"

# Return only NetworkManager connections that belong to this plugin
owned_connections() {
  nmcli -t -f NAME,TYPE connection show 2>/dev/null \
    | grep ":wireguard$" \
    | cut -d: -f1 \
    | grep "^${CONN_PREFIX}" || true
}

down_and_delete_owned() {
  local name
  while IFS= read -r name; do
    [ -z "$name" ] && continue
    nmcli connection down "$name" >/dev/null 2>&1 || true
    nmcli connection delete "$name" >/dev/null 2>&1 || true
  done < <(owned_connections)
}

case "$ACTION" in
  connect)
    if [ -z "$ARG" ]; then
      echo '{"success":false,"error":"No profile provided"}'
      exit 1
    fi

    # Normalize profile id (strip any accidental prefix)
    PROFILE="${ARG#surfshark-}"
    PROFILE="${PROFILE#surfshark_}"
    CONF_FILE="$CONFIG_DIR/$PROFILE.conf"
    CONN_NAME="${CONN_PREFIX}${PROFILE}"

    if [ ! -f "$CONF_FILE" ]; then
      echo "{\"success\":false,\"error\":\"File not found: $CONF_FILE\"}"
      exit 1
    fi

    # Tear down ONLY our own connections
    down_and_delete_owned

    # Import → rename to our exclusive prefix → activate
    nmcli connection import type wireguard file "$CONF_FILE" >/dev/null

    # The imported name is the file stem; rename it to our owned name
    IMPORTED_NAME="$PROFILE"
    if nmcli -t -f NAME connection show | grep -qx "$IMPORTED_NAME"; then
      nmcli connection modify "$IMPORTED_NAME" connection.id "$CONN_NAME" >/dev/null 2>&1 || true
    fi

    # Safety: make sure the final name exists
    if ! nmcli -t -f NAME connection show | grep -qx "$CONN_NAME"; then
      # Fallback: try the original name
      CONN_NAME="$IMPORTED_NAME"
    fi

    nmcli connection modify "$CONN_NAME" connection.autoconnect no >/dev/null 2>&1 || true
    nmcli connection up "$CONN_NAME" >/dev/null

    # Persist last profile
    if [ -f "$STATE_FILE" ]; then
      sed -i 's/"last_profile": *"[^"]*"/"last_profile": "'"$PROFILE"'"/' "$STATE_FILE" 2>/dev/null || true
      sed -i 's/"last_profile": *null/"last_profile": "'"$PROFILE"'"/' "$STATE_FILE" 2>/dev/null || true
    fi

    echo "{\"success\":true,\"connected\":true,\"profile\":\"$PROFILE\"}"
    ;;

  disconnect)
    down_and_delete_owned
    if [ -f "$STATE_FILE" ]; then
      sed -i 's/"last_profile": *"[^"]*"/"last_profile": null/' "$STATE_FILE" 2>/dev/null || true
      sed -i 's/"last_ip": *"[^"]*"/"last_ip": "—"/' "$STATE_FILE" 2>/dev/null || true
    fi
    echo '{"success":true,"connected":false}'
    ;;

  *)
    echo '{"success":false,"error":"Unknown action"}'
    exit 1
    ;;
esac
