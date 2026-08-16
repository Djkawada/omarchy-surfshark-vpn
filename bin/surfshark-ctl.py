#!/usr/bin/env python3
"""
Surfshark Native WireGuard & NetworkManager Controller for Omarchy Linux.
Provides zero-bloat VPN management, favorites system, async IP monitoring, and location switching.
"""

import sys
import os
import glob
import json
import subprocess
import time
import threading
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
    return {"lang": "en", "last_profile": None, "last_ip": "—", "last_ip_check": 0, "favorites": ["fr-par", "jp-tok"]}

def save_state(state):
    ensure_dirs()
    try:
        with open(STATE_FILE, "w") as f:
            json.dump(state, f, indent=2)
    except Exception:
        pass

def parse_profile_name(filename, favorites=None):
    if favorites is None:
        favorites = []
    base = os.path.basename(filename)
    name = os.path.splitext(base)[0].lower()
    key = name.replace("surfshark-", "").replace("surfshark_", "").replace("-wireguard", "").replace("_wireguard", "")
    info = LOCATION_DB.get(key, None)
    if not info:
        parts = key.split("-")
        if len(parts) >= 2:
            c_code = parts[0]
            info = {"country": c_code.upper(), "city": parts[1].capitalize(), "flag": "🌐"}
        else:
            info = {"country": name.capitalize(), "city": "VPN Server", "flag": "🔒"}
    
    is_fav = (key in favorites) or (name in favorites)
    return {
        "id": name,
        "key": key,
        "filename": filename,
        "country": info["country"],
        "city": info["city"],
        "flag": info["flag"],
        "is_favorite": is_fav,
        "display_name": f"{info['flag']} {info['country']} - {info['city']}"
    }

def get_installed_profiles(favorites=None):
    ensure_dirs()
    confs = glob.glob(os.path.join(PROFILES_DIR, "*.conf"))
    profiles = [parse_profile_name(c, favorites) for c in confs]
    profiles.sort(key=lambda p: (not p["is_favorite"], p["country"], p["city"]))
    return profiles

def get_active_connection():
    try:
        res = subprocess.run(["nmcli", "-t", "-f", "NAME,TYPE,DEVICE", "con", "show", "--active"],
                             capture_output=True, text=True, timeout=1.2)
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

    try:
        res = subprocess.run(["wg", "show", "interfaces"], capture_output=True, text=True, timeout=1.0)
        if res.returncode == 0 and res.stdout.strip():
            ifaces = res.stdout.strip().split()
            if ifaces:
                return {"type": "wg", "name": ifaces[0], "device": ifaces[0]}
    except Exception:
        pass

    return None

def fetch_public_ip():
    urls = [
        "https://api.myip.com",
        "https://api.surfshark.com/v1/server/user",
        "https://ipinfo.io/json"
    ]
    for u in urls:
        try:
            req = urllib.request.Request(u, headers={"User-Agent": "Omarchy-Surfshark-Plugin/1.0"})
            with urllib.request.urlopen(req, timeout=2.0) as resp:
                data = json.loads(resp.read().decode("utf-8"))
                ip = data.get("ip", data.get("ipAddress", None))
                if ip:
                    country = data.get("country", data.get("country_name", ""))
                    city = data.get("city", "")
                    return {"ip": ip, "country": country, "city": city}
        except Exception:
            continue
    return {"ip": "—", "country": "", "city": ""}

def async_ip_check():
    ip_info = fetch_public_ip()
    if ip_info and ip_info.get("ip") and ip_info["ip"] != "—":
        state = load_state()
        state["last_ip"] = ip_info["ip"]
        state["last_ip_check"] = time.time()
        save_state(state)

def cmd_status():
    state = load_state()
    active_conn = get_active_connection()
    is_connected = active_conn is not None
    favs = state.get("favorites", ["fr-par", "jp-tok"])
    profiles = get_installed_profiles(favs)

    active_profile_info = None
    if is_connected and active_conn:
        cname = active_conn["name"].replace("surfshark-", "").replace("surfshark_", "")
        active_profile_info = parse_profile_name(cname, favs)

    now = time.time()
    if is_connected:
        if now - state.get("last_ip_check", 0) > 30 or state.get("last_ip") == "—":
            threading.Thread(target=async_ip_check, daemon=True).start()
    else:
        state["last_ip"] = "—"

    fav_profiles = [p for p in profiles if p["is_favorite"]]

    result = {
        "connected": is_connected,
        "active_connection": active_conn,
        "active_profile": active_profile_info,
        "public_ip": state.get("last_ip", "—"),
        "profiles_count": len(profiles),
        "profiles": profiles,
        "favorites": fav_profiles,
        "config_dir": PROFILES_DIR,
        "lang": state.get("lang", "en")
    }
    print(json.dumps(result))

def cmd_toggle_favorite(profile_id):
    state = load_state()
    favs = state.get("favorites", ["fr-par", "jp-tok"])
    key = profile_id.replace("surfshark-", "").replace("surfshark_", "")
    if key in favs:
        favs.remove(key)
    elif profile_id in favs:
        favs.remove(profile_id)
    else:
        favs.append(key)
    state["favorites"] = favs
    save_state(state)
    print(json.dumps({"success": True, "favorites": favs}))

def cmd_connect(profile_name):
    ensure_dirs()
    state = load_state()
    
    conf_path = os.path.join(PROFILES_DIR, f"{profile_name}.conf")
    if not os.path.exists(conf_path):
        matches = glob.glob(os.path.join(PROFILES_DIR, f"*{profile_name}*.conf"))
        if matches:
            conf_path = matches[0]
        else:
            print(json.dumps({"success": False, "error": f"Profile '{profile_name}' not found."}))
            return

    base_name = os.path.splitext(os.path.basename(conf_path))[0]

    # Disconnect existing connection first
    cmd_disconnect(silent=True)

    try:
        # Import wireguard profile (NetworkManager creates connection named base_name)
        subprocess.run(["nmcli", "connection", "import", "type", "wireguard", "file", conf_path],
                       capture_output=True, text=True, timeout=4)

        for target in [base_name, f"surfshark-{base_name}"]:
            up_res = subprocess.run(["nmcli", "connection", "up", target],
                                    capture_output=True, text=True, timeout=5)
            if up_res.returncode == 0:
                state["last_profile"] = profile_name
                state["last_ip_check"] = 0
                save_state(state)
                # Kick off immediate async IP update
                threading.Thread(target=async_ip_check, daemon=True).start()
                print(json.dumps({"success": True, "connected": True, "profile": profile_name}))
                return
    except Exception:
        pass

    try:
        res = subprocess.run(["wg-quick", "up", conf_path], capture_output=True, text=True, timeout=5)
        if res.returncode == 0:
            state["last_profile"] = profile_name
            state["last_ip_check"] = 0
            save_state(state)
            threading.Thread(target=async_ip_check, daemon=True).start()
            print(json.dumps({"success": True, "connected": True, "profile": profile_name}))
            return
    except Exception:
        pass

    print(json.dumps({"success": False, "error": "Failed to activate connection."}))

def cmd_disconnect(silent=False):
    state = load_state()
    try:
        res = subprocess.run(["nmcli", "-t", "-f", "NAME,TYPE", "con", "show", "--active"],
                             capture_output=True, text=True, timeout=2)
        if res.returncode == 0:
            for line in res.stdout.strip().split("\n"):
                if not line:
                    continue
                parts = line.split(":")
                if len(parts) >= 2 and (parts[1] == "wireguard" or "surfshark" in parts[0].lower()):
                    subprocess.run(["nmcli", "connection", "down", parts[0]],
                                   capture_output=True, text=True, timeout=3)
    except Exception:
        pass

    try:
        res = subprocess.run(["wg", "show", "interfaces"], capture_output=True, text=True, timeout=2)
        if res.returncode == 0 and res.stdout.strip():
            for iface in res.stdout.strip().split():
                subprocess.run(["wg-quick", "down", iface], capture_output=True, text=True, timeout=3)
    except Exception:
        pass

    state["last_profile"] = None
    state["last_ip"] = "—"
    state["last_ip_check"] = 0
    save_state(state)
    if not silent:
        print(json.dumps({"success": True, "connected": False}))

def cmd_set_lang(l):
    state = load_state()
    state["lang"] = l
    save_state(state)
    print(json.dumps({"success": True, "lang": l}))

def main():
    if len(sys.argv) < 2 or sys.argv[1] == "status":
        cmd_status()
    elif sys.argv[1] == "connect" and len(sys.argv) > 2:
        cmd_connect(sys.argv[2])
    elif sys.argv[1] == "disconnect":
        cmd_disconnect()
    elif sys.argv[1] == "toggle-favorite" and len(sys.argv) > 2:
        cmd_toggle_favorite(sys.argv[2])
    elif sys.argv[1] == "set-lang" and len(sys.argv) > 2:
        cmd_set_lang(sys.argv[2])
    else:
        print("Usage: surfshark-ctl.py [status|connect <profile>|disconnect|toggle-favorite <profile_id>|set-lang <fr/en/ja>]")

if __name__ == "__main__":
    main()
