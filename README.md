# 🦈 Surfshark VPN for Omarchy Linux

An **ultra-lightweight, zero-bloat, native WireGuard VPN manager and status monitor** for Surfshark users on Omarchy Linux (Hyprland / Quickshell).

---

## 🎯 Why This Plugin Exists

The official Surfshark Linux client is often problematic on Arch Linux and Wayland/Hyprland environments (heavy Electron background processes consuming ~300 MB RAM, broken tray icons, and flaky systemd service bindings).

**Surfshark VPN for Omarchy** provides:
- **Instant Connection (< 50ms)**: Powered by standard Linux kernel WireGuard integration (`NetworkManager` / `nmcli` / `wg-quick`).
- **Zero Background Overhead**: 0 MB RAM idle, zero background daemons.
- **100% Native Quickshell & Qt Quick**: Fluid desktop integration matching your Omarchy theme and monitor refresh rate.
- **Dynamic Status & Public IP Monitor**: Automatic lookup of your external IP and active VPN location.
- **One-Click Location Switching**: Switch between server profiles (France 🇫🇷, Japan 🇯🇵, USA 🇺🇸, Germany 🇩🇪, Switzerland 🇨🇭, etc.) with a single click.
- **Tri-Lingual Localization**: Instant one-click switching between **English 🇬🇧**, **Français 🇫🇷**, and **日本語 🇯🇵**.

---

## 🚀 Getting Started with WireGuard

### 1. Download Your WireGuard Configs from Surfshark
1. Log in to your Surfshark account at [surfshark.com](https://surfshark.com).
2. Go to **VPN** > **Manual setup** > **WireGuard**.
3. Generate a key pair if you haven't already.
4. Download the `.conf` configuration files for your desired locations (e.g. `fr-par.conf`, `jp-tok.conf`, `us-nyc.conf`).
5. Place them into:
   ```bash
   mkdir -p ~/.config/surfshark-vpn/configs
   cp ~/Downloads/*.conf ~/.config/surfshark-vpn/configs/
   ```

### 2. Install the Plugin
```bash
git clone https://github.com/Djkawada/omarchy-surfshark-vpn.git ~/.config/omarchy/plugins/com.github.djkawada.surfshark-vpn
```

### 3. Add to Your Bar & Reload
In `~/.config/omarchy/shell.json`, add `"com.github.djkawada.surfshark-vpn"` to your `bar.layout.right` section, then run:

```bash
omarchy restart shell
```

---

## 🗑️ Removal / Uninstall

```bash
rm -rf ~/.config/omarchy/plugins/com.github.djkawada.surfshark-vpn
omarchy restart shell
```

---

## 🛠️ Technology Stack & Dependencies

- **Network Engine**: Standard Linux Kernel WireGuard via `NetworkManager` (`nmcli`) or `wg-quick`.
- **UI Framework**: [Quickshell](https://quickshell.outfoxxed.me/) / Qt Quick / QML (`qs.Ui`, `qs.Commons`).
- **Dependencies**: None! Uses only standard Linux tools (`nmcli`, Python 3 standard library).

---

## 📄 License

Distributed under the **MIT License**. Created by [Pierre (Djkawada)](https://github.com/Djkawada).
