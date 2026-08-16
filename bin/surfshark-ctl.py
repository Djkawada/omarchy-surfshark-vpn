#!/usr/bin/env python3
"""
Surfshark Native WireGuard & NetworkManager Controller for Omarchy Linux.
Provides zero-bloat VPN management, live IP/status monitoring, and multi-location switching.
"""

import sys
import os
import glob
import json
import subprocess
import time
import urllib.request
import urllib.error

CONFIG_DIR = os.path.expanduser("~/.config/surfshark-vpn")
PROFILES_DIR = os.path.join(CONFIG_DIR, "configs")
STATE_FILE = os.path.join(CONFIG_DIR, "state.json")

# Country & City dictionary for Surfshark location codes
LOCATION_DB = {
    "fr-par": {"country": "France", "city": "Paris", "flag": "🇫🇷"},
    "fr-mrs": {"country": "France", "city": "Marseille", "flag": "🇫🇷"},
    "fr-bod": {"country": "France", "city": "Bordeaux", "flag": "🇫🇷"},
    "jp-tok": {"country": "Japan", "city": "Tokyo", "flag": "🇯🇵"},
    "jp-osa": {"country": "Japan", "city": "Osaka", "flag": "🇯🇵"},
    "us-nyc": {"country": "United States", "city": "New York", "flag": "🇺🇸"},
    "us-lax": {"country": "United States", "city": "Los Angeles", "flag": "🇺🇸"},
    "us-mia": {"country": "United States", "city": "Miami", "flag": "🇺🇸"},
    "us-chi": {"country": "United States", "city": "Chicago", "flag": "🇺🇸"},
    "us-sfo": {"country": "United States", "city": "San Francisco", "flag": "🇺🇸"},
    "us-sea": {"country": "United States", "city": "Seattle", "flag": "🇺🇸"},
    "de-fra": {"country": "Germany", "city": "Frankfurt", "flag": "🇩🇪"},
    "de-ber": {"country": "Germany", "city": "Berlin", "flag": "🇩🇪"},
    "gb-lon": {"country": "United Kingdom", "city": "London", "flag": "🇬🇧"},
    "gb-man": {"country": "United Kingdom", "city": "Manchester", "flag": "🇬🇧"},
    "ca-tor": {"country": "Canada", "city": "Toronto", "flag": "🇨🇦"},
    "ca-mon": {"country": "Canada", "city": "Montreal", "flag": "🇨🇦"},
    "ca-van": {"country": "Canada", "city": "Vancouver", "flag": "🇨🇦"},
    "ch-zur": {"country": "Switzerland", "city": "Zurich", "flag": "🇨🇭"},
    "nl-ams": {"country": "Netherlands", "city": "Amsterdam", "flag": "🇳🇱"},
    "es-mad": {"country": "Spain", "city": "Madrid", "flag": "🇪🇸"},
    "es-bcn": {"country": "Spain", "city": "Barcelona", "flag": "🇪🇸"},
    "it-mil": {"country": "Italy", "city": "Milan", "flag": "🇮🇹"},
    "it-rom": {"country": "Italy", "city": "Rome", "flag": "🇮🇹"},
    "be-bru": {"country": "Belgium", "city": "Brussels", "flag": "🇧🇪"},
    "se-sto": {"country": "Sweden", "city": "Stockholm", "flag": "🇸🇪"},
    "no-osl": {"country": "Norway", "city": "Oslo", "flag": "🇳🇴"},
    "fi-hel": {"country": "Finland", "city": "Helsinki", "flag": "🇫🇮"},
    "sg-sin": {"country": "Singapore", "city": "Singapore", "flag": "🇸🇬"},
    "sg-sng": {"country": "Singapore", "city": "Singapore", "flag": "🇸🇬"},
    "au-syd": {"country": "Australia", "city": "Sydney", "flag": "🇦🇺"},
    "au-mel": {"country": "Australia", "city": "Melbourne", "flag": "🇦🇺"},
    "br-sao": {"country": "Brazil", "city": "São Paulo", "flag": "🇧🇷"}
}

def ensure_dirs():
    os.makedirs(PROFILES_DIR, exist_ok=True)

def load_state():
    ensure_dirs()
    if os.path.exists(STATE_FILE):
        try:
            with open(STATE_FILE, "r") as f:
                return json.load(f)
        except Exception:
            pass
    return {"lang": "en", "last_profile": None, "last_ip": "—", "last_ip_check": 0}

def save_state(state):
    ensure_dirs()
    try:
        with open(STATE_FILE, "w") as f:
            json.dump(state, f, indent=2)
    except Exception:
        pass

def parse_profile_name(filename):
    base = os.path.basename(filename)
    name = os.path.splitext(base)[0].lower()
    # Normalize (e.g. surfshark_fr-par or fr-par_wireguard)
    key = name.replace("surfshark-", "").replace("surfshark_", "").replace("-wireguard", "").replace("_wireguard", "")
    info = LOCATION_DB.get(key, None)
    if not info:
        # Try country prefix
        parts = key.split("-")
        if len(parts) >= 2:
            c_code = parts[0]
            info = {"country": c_code.upper(), "city": parts[1].capitalize(), "flag": "🌐"}
        else:
            info = {"country": name.capitalize(), "city": "VPN Server", "flag": "🔒"}
    return {
        "id": name,
        "key": key,
        "filename": filename,
        "country": info["country"],
        "city": info["city"],
        "flag": info["flag"],
        "display_name": f"{info['flag']} {info['country']} - {info['city']}"
    }

def get_installed_profiles():
    ensure_dirs()
    confs = glob.glob(os.path.join(PROFILES_DIR, "*.conf"))
    profiles = [parse_profile_name(c) for c in confs]
    profiles.sort(key=lambda p: (p["country"], p["city"]))
    return profiles

def get_active_connection():
    # 1. Check nmcli active connections
    try:
        res = subprocess.run(["nmcli", "-t", "-f", "NAME,TYPE,DEVICE", "con", "show", "--active"],
                             capture_output=True, text=True, timeout=2)
        if res.returncode == 0:
            for line in res.stdout.strip().split("\n"):
                if not line:
                    continue
                parts = line.split(":")
                if len(parts) >= 2:
                    cname, ctype = parts[0], parts[1]
                    if ctype == "wireguard" or "surfshark" in cname.lower():
                        return {"type": "nmcli", "name": cname, "device": parts[2] if len(parts) > 2 else "wg0"}
    except Exception:
        pass

    # 2. Check wg show
    try:
        res = subprocess.run(["wg", "show", "interfaces"], capture_output=True, text=True, timeout=2)
        if res.returncode == 0 and res.stdout.strip():
            ifaces = res.stdout.strip().split()
            if ifaces:
                return {"type": "wg", "name": ifaces[0], "device": ifaces[0]}
    except Exception:
        pass

    return None

def fetch_public_ip():
    urls = [
        "https://api.surfshark.com/v1/server/user",
        "https://api.myip.com",
        "https://ipinfo.io/json"
    ]
    for u in urls:
        try:
            req = urllib.request.Request(u, headers={"User-Agent": "Omarchy-Surfshark-Plugin/1.0"})
            with urllib.request.urlopen(req, timeout=3) as resp:
                data = json.loads(resp.read().decode("utf-8"))
                ip = data.get("ip", data.get("ipAddress", None))
                if ip:
                    country = data.get("country", data.get("country_name", ""))
                    city = data.get("city", "")
                    return {"ip": ip, "country": country, "city": city}
        except Exception:
            continue
    return {"ip": "—", "country": "", "city": ""}

def cmd_status():
    state = load_state()
    active_conn = get_active_connection()
    is_connected = active_conn is not None
    profiles = get_installed_profiles()

    active_profile_info = None
    if is_connected and active_conn:
        cname = active_conn["name"].replace("surfshark-", "").replace("surfshark_", "")
        active_profile_info = parse_profile_name(cname)

    # Check IP if connected or if last check is older than 60s
    now = time.time()
    if is_connected and (now - state.get("last_ip_check", 0) > 30 or state.get("last_ip") == "—"):
        ip_info = fetch_public_ip()
        state["last_ip"] = ip_info["ip"]
        state["last_ip_check"] = now
        save_state(state)

    result = {
        "connected": is_connected,
        "active_connection": active_conn,
        "active_profile": active_profile_info,
        "public_ip": state.get("last_ip", "—"),
        "profiles_count": len(profiles),
        "profiles": profiles,
        "config_dir": PROFILES_DIR,
        "lang": state.get("lang", "en")
    }
    print(json.dumps(result))

def cmd_connect(profile_name):
    ensure_dirs()
    state = load_state()
    
    # Locate .conf
    conf_path = os.path.join(PROFILES_DIR, f"{profile_name}.conf")
    if not os.path.exists(conf_path):
        # Search by base name
        matches = glob.glob(os.path.join(PROFILES_DIR, f"*{profile_name}*.conf"))
        if matches:
            conf_path = matches[0]
        else:
            print(json.dumps({"success": False, "error": f"Profile '{profile_name}' not found."}))
            return

    conn_name = f"surfshark-{os.path.splitext(os.path.basename(conf_path))[0]}"

    # Disconnect existing connection first
    cmd_disconnect(silent=True)

    # 1. Try NetworkManager import & up
    try:
        # Check if already imported
        show_res = subprocess.run(["nmcli", "connection", "show", conn_name],
                                  capture_output=True, text=True)
        if show_res.returncode != 0:
            # Import wireguard profile
            import_res = subprocess.run(["nmcli", "connection", "import", "type", "wireguard", "file", conf_path],
                                        capture_output=True, text=True)
            if import_res.returncode != 0:
                pass

        # Bring connection UP
        up_res = subprocess.run(["nmcli", "connection", "up", conn_name],
                                capture_output=True, text=True, timeout=10)
        if up_res.returncode == 0:
            state["last_profile"] = profile_name
            state["last_ip_check"] = 0  # Force IP refresh
            save_state(state)
            print(json.dumps({"success": True, "connected": True, "profile": profile_name}))
            return
    except Exception as e:
        pass

    # 2. Fallback to wg-quick if available
    try:
        res = subprocess.run(["wg-quick", "up", conf_path], capture_output=True, text=True, timeout=10)
        if res.returncode == 0:
            state["last_profile"] = profile_name
            state["last_ip_check"] = 0
            save_state(state)
            print(json.dumps({"success": True, "connected": True, "profile": profile_name}))
            return
    except Exception:
        pass

    print(json.dumps({"success": False, "error": "Failed to activate connection."}))

def cmd_disconnect(silent=False):
    state = load_state()
    active_conn = get_active_connection()
    if active_conn:
        if active_conn["type"] == "nmcli":
            subprocess.run(["nmcli", "connection", "down", active_conn["name"]],
                           capture_output=True, text=True)
        elif active_conn["type"] == "wg":
            subprocess.run(["wg-quick", "down", active_conn["name"]],
                           capture_output=True, text=True)

    state["last_ip_check"] = 0
    save_state(state)
    if not silent:
        print(json.dumps({"success": True, "connected": False}))

def cmd_set_lang(l):
    state = load_state()
    state["lang"] = l
    save_state(state)
    print(json.dumps({"success": True, "lang": l}))

def cmd_create_samples():
    ensure_dirs()
    readme_file = os.path.join(PROFILES_DIR, "README_SETUP.txt")
    if not os.path.exists(readme_file):
        with open(readme_file, "w") as f:
            f.write("""Surfshark WireGuard Configuration Setup
=======================================
1. Log in to your Surfshark account at https://surfshark.com
2. Go to: VPN -> Manual setup -> WireGuard
3. Click "I don't have a key pair" -> Generate a new key pair.
4. Select your preferred locations (e.g., France - Paris, Japan - Tokyo, USA, etc.)
5. Download the .conf files and place them into this folder:
   ~/.config/surfshark-vpn/configs/

The Omarchy Surfshark VPN plugin will automatically detect them instantly!
""")

def main():
    cmd_create_samples()
    if len(sys.argv) < 2 or sys.argv[1] == "status":
        cmd_status()
    elif sys.argv[1] == "connect" and len(sys.argv) > 2:
        cmd_connect(sys.argv[2])
    elif sys.argv[1] == "disconnect":
        cmd_disconnect()
    elif sys.argv[1] == "set-lang" and len(sys.argv) > 2:
        cmd_set_lang(sys.argv[2])
    else:
        print("Usage: surfshark-ctl.py [status|connect <profile>|disconnect|set-lang <fr/en/ja>]")

if __name__ == "__main__":
    main()
