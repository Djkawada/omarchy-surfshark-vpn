use serde::{Deserialize, Serialize};
use std::fs;
use std::path::{Path, PathBuf};
use std::process::Command;
use std::time::{SystemTime, UNIX_EPOCH};

#[derive(Serialize, Deserialize, Debug, Clone)]
struct State {
    lang: String,
    last_profile: Option<String>,
    last_ipv4: String,
    last_ipv6: String,
    last_ip: String,
    last_ip_check: u64,
    favorites: Vec<String>,
}

impl Default for State {
    fn default() -> Self {
        Self {
            lang: "en".to_string(),
            last_profile: None,
            last_ipv4: "—".to_string(),
            last_ipv6: "—".to_string(),
            last_ip: "—".to_string(),
            last_ip_check: 0,
            favorites: vec!["fr-par".to_string(), "jp-tok".to_string(), "us-nyc".to_string()],
        }
    }
}

#[derive(Serialize, Deserialize, Debug, Clone, Default)]
struct Keys {
    public_key: String,
    private_key: String,
}

#[derive(Serialize, Deserialize, Debug, Clone)]
struct ProfileInfo {
    id: String,
    key: String,
    filename: String,
    country: String,
    city: String,
    flag: String,
    is_favorite: bool,
    display_name: String,
}

#[derive(Serialize, Deserialize, Debug)]
struct ActiveConnection {
    r#type: String,
    name: String,
    device: String,
}

#[derive(Serialize, Deserialize, Debug)]
struct StatusOutput {
    connected: bool,
    active_connection: Option<ActiveConnection>,
    active_profile: Option<ProfileInfo>,
    public_ip: String,
    ipv4: String,
    ipv6: String,
    profiles_count: usize,
    profiles: Vec<ProfileInfo>,
    favorites: Vec<ProfileInfo>,
    keys: Keys,
    config_dir: String,
    lang: String,
}

fn get_config_dir() -> PathBuf {
    let home = std::env::var("HOME").unwrap_or_else(|_| "/home/pierre".to_string());
    PathBuf::from(home).join(".config").join("surfshark-vpn")
}

fn get_profiles_dir() -> PathBuf {
    get_config_dir().join("configs")
}

fn get_state_file() -> PathBuf {
    get_config_dir().join("state.json")
}

fn get_keys_file() -> PathBuf {
    get_config_dir().join("keys.json")
}

fn now_secs() -> u64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|d| d.as_secs())
        .unwrap_or(0)
}

fn load_state() -> State {
    let path = get_state_file();
    if path.exists() {
        if let Ok(content) = fs::read_to_string(&path) {
            if let Ok(state) = serde_json::from_str::<State>(&content) {
                return state;
            }
        }
    }
    State::default()
}

fn save_state(state: &State) {
    let dir = get_config_dir();
    let _ = fs::create_dir_all(&dir);
    let path = get_state_file();
    if let Ok(json) = serde_json::to_string_pretty(state) {
        let _ = fs::write(path, json);
    }
}

fn load_keys() -> Keys {
    let path = get_keys_file();
    if path.exists() {
        if let Ok(content) = fs::read_to_string(&path) {
            if let Ok(keys) = serde_json::from_str::<Keys>(&content) {
                return keys;
            }
        }
    }
    Keys::default()
}

fn save_keys_and_update_configs(pub_key: &str, priv_key: &str) {
    let keys = Keys {
        public_key: pub_key.trim().to_string(),
        private_key: priv_key.trim().to_string(),
    };
    let dir = get_config_dir();
    let _ = fs::create_dir_all(&dir);
    let path = get_keys_file();
    if let Ok(json) = serde_json::to_string_pretty(&keys) {
        let _ = fs::write(&path, json);
        #[cfg(unix)]
        {
            use std::os::unix::fs::PermissionsExt;
            let _ = fs::set_permissions(&path, fs::Permissions::from_mode(0o600));
        }
    }

    if !keys.private_key.is_empty() {
        let pdir = get_profiles_dir();
        if let Ok(entries) = fs::read_dir(pdir) {
            for entry in entries.flatten() {
                let p = entry.path();
                if p.extension().and_then(|e| e.to_str()) == Some("conf") {
                    if let Ok(content) = fs::read_to_string(&p) {
                        let mut new_lines = Vec::new();
                        for line in content.lines() {
                            if line.trim_start().starts_with("PrivateKey") {
                                new_lines.push(format!("PrivateKey = {}", keys.private_key));
                            } else {
                                new_lines.push(line.to_string());
                            }
                        }
                        let _ = fs::write(&p, new_lines.join("\n") + "\n");
                    }
                }
            }
        }
    }
}

fn location_meta(key: &str) -> (&'static str, &'static str, &'static str) {
    match key {
        "fr-par" => ("France", "Paris", "🇫🇷"),
        "fr-mrs" => ("France", "Marseille", "🇫🇷"),
        "fr-bod" => ("France", "Bordeaux", "🇫🇷"),
        "jp-tok" => ("Japan", "Tokyo", "🇯🇵"),
        "jp-osa" => ("Japan", "Osaka", "🇯🇵"),
        "us-nyc" => ("United States", "New York", "🇺🇸"),
        "us-lax" => ("United States", "Los Angeles", "🇺🇸"),
        "us-mia" => ("United States", "Miami", "🇺🇸"),
        "us-chi" => ("United States", "Chicago", "🇺🇸"),
        "us-sfo" => ("United States", "San Francisco", "🇺🇸"),
        "us-sea" => ("United States", "Seattle", "🇺🇸"),
        "de-fra" => ("Germany", "Frankfurt", "🇩🇪"),
        "de-ber" => ("Germany", "Berlin", "🇩🇪"),
        "gb-lon" => ("United Kingdom", "London", "🇬🇧"),
        "gb-man" => ("United Kingdom", "Manchester", "🇬🇧"),
        "ca-tor" => ("Canada", "Toronto", "🇨🇦"),
        "ca-mon" => ("Canada", "Montreal", "🇨🇦"),
        "ca-van" => ("Canada", "Vancouver", "🇨🇦"),
        "ch-zur" => ("Switzerland", "Zurich", "🇨🇭"),
        "nl-ams" => ("Netherlands", "Amsterdam", "🇳🇱"),
        "es-mad" => ("Spain", "Madrid", "🇪🇸"),
        "es-bcn" => ("Spain", "Barcelona", "🇪🇸"),
        "it-mil" => ("Italy", "Milan", "🇮🇹"),
        "it-rom" => ("Italy", "Rome", "🇮🇹"),
        "be-bru" => ("Belgium", "Brussels", "🇧🇪"),
        "se-sto" => ("Sweden", "Stockholm", "🇸🇪"),
        "no-osl" => ("Norway", "Oslo", "🇳🇴"),
        "fi-hel" => ("Finland", "Helsinki", "🇫🇮"),
        "sg-sin" | "sg-sng" => ("Singapore", "Singapore", "🇸🇬"),
        "au-syd" => ("Australia", "Sydney", "🇦🇺"),
        "au-mel" => ("Australia", "Melbourne", "🇦🇺"),
        "br-sao" => ("Brazil", "São Paulo", "🇧🇷"),
        _ => ("VPN Server", "Location", "🌐"),
    }
}

fn parse_profile_path(path: &Path, favorites: &[String]) -> ProfileInfo {
    let file_stem = path.file_stem().and_then(|s| s.to_str()).unwrap_or("vpn");
    let key = file_stem
        .replace("surfshark-", "")
        .replace("surfshark_", "")
        .replace("-wireguard", "")
        .replace("_wireguard", "");

    let (country, city, flag) = location_meta(&key);
    let is_favorite = favorites.contains(&key) || favorites.contains(&file_stem.to_string());

    ProfileInfo {
        id: key.clone(),
        key: key.clone(),
        filename: path.to_string_lossy().to_string(),
        country: country.to_string(),
        city: city.to_string(),
        flag: flag.to_string(),
        is_favorite,
        display_name: format!("{} {} - {}", flag, country, city),
    }
}

fn get_installed_profiles(favorites: &[String]) -> Vec<ProfileInfo> {
    let pdir = get_profiles_dir();
    let mut list = Vec::new();
    if let Ok(entries) = fs::read_dir(pdir) {
        for entry in entries.flatten() {
            let path = entry.path();
            if path.extension().and_then(|e| e.to_str()) == Some("conf") {
                list.push(parse_profile_path(&path, favorites));
            }
        }
    }
    list.sort_by(|a, b| {
        b.is_favorite
            .cmp(&a.is_favorite)
            .then_with(|| a.country.cmp(&b.country))
            .then_with(|| a.city.cmp(&b.city))
    });
    list
}

fn get_active_connection() -> Option<ActiveConnection> {
    if let Ok(output) = Command::new("nmcli")
        .args(["-t", "-f", "NAME,TYPE,DEVICE", "con", "show", "--active"])
        .output()
    {
        let stdout = String::from_utf8_lossy(&output.stdout);
        for line in stdout.lines() {
            let parts: Vec<&str> = line.split(':').collect();
            if parts.len() >= 2 {
                let name = parts[0];
                let ctype = parts[1];
                let device = parts.get(2).copied().unwrap_or("surfshark");
                if ctype == "wireguard" || name == "surfshark-vpn" {
                    return Some(ActiveConnection {
                        r#type: "nmcli".to_string(),
                        name: name.to_string(),
                        device: device.to_string(),
                    });
                }
            }
        }
    }
    if let Ok(output) = Command::new("wg").args(["show", "interfaces"]).output() {
        let stdout = String::from_utf8_lossy(&output.stdout);
        if let Some(iface) = stdout.split_whitespace().next() {
            return Some(ActiveConnection {
                r#type: "wg".to_string(),
                name: iface.to_string(),
                device: iface.to_string(),
            });
        }
    }
    None
}

fn fetch_ip_sync() {
    let handle_v4 = std::thread::spawn(|| {
        let urls = ["https://api.ipify.org", "https://ipv4.icanhazip.com", "https://v4.ident.me"];
        for url in urls {
            if let Ok(output) = Command::new("curl").args(["-4", "-s", "-m", "2", url]).output() {
                let ip = String::from_utf8_lossy(&output.stdout).trim().to_string();
                if !ip.is_empty() && ip.contains('.') {
                    return Some(ip);
                }
            }
        }
        None
    });

    let handle_v6 = std::thread::spawn(|| {
        let urls = ["https://api64.ipify.org", "https://ipv6.icanhazip.com", "https://v6.ident.me"];
        for url in urls {
            if let Ok(output) = Command::new("curl").args(["-6", "-s", "-m", "2", url]).output() {
                let ip = String::from_utf8_lossy(&output.stdout).trim().to_string();
                if !ip.is_empty() && ip.contains(':') {
                    return Some(ip);
                }
            }
        }
        None
    });

    let ipv4 = handle_v4.join().unwrap_or(None);
    let ipv6 = handle_v6.join().unwrap_or(None);

    let mut state = load_state();
    if let Some(v4) = ipv4 {
        state.last_ipv4 = v4.clone();
        state.last_ip = v4;
    }
    if let Some(v6) = ipv6 {
        state.last_ipv6 = v6;
    }
    state.last_ip_check = now_secs();
    save_state(&state);
}

fn trigger_ip_fetch_daemon() {
    if let Ok(exe) = std::env::current_exe() {
        let _ = Command::new(exe).arg("fetch-ip").spawn();
    }
}

fn cmd_status() {
    let state = load_state();
    let active_conn = get_active_connection();
    let is_connected = active_conn.is_some();
    let profiles = get_installed_profiles(&state.favorites);
    let keys = load_keys();

    let active_profile = if is_connected {
        if let Some(ref p_id) = state.last_profile {
            let pdir = get_profiles_dir();
            let conf = pdir.join(format!("{}.conf", p_id));
            Some(parse_profile_path(&conf, &state.favorites))
        } else if let Some(ref conn) = active_conn {
            let pdir = get_profiles_dir();
            let conf = pdir.join(format!("{}.conf", conn.name));
            Some(parse_profile_path(&conf, &state.favorites))
        } else {
            Some(ProfileInfo {
                id: "active".to_string(),
                key: "active".to_string(),
                filename: "".to_string(),
                country: "Surfshark".to_string(),
                city: "VPN Tunnel".to_string(),
                flag: "🔒".to_string(),
                is_favorite: false,
                display_name: "🔒 Surfshark VPN".to_string(),
            })
        }
    } else {
        None
    };

    if is_connected && (now_secs().saturating_sub(state.last_ip_check) > 30 || state.last_ipv4 == "—") {
        trigger_ip_fetch_daemon();
    }

    let fav_profiles: Vec<ProfileInfo> = profiles.iter().filter(|p| p.is_favorite).cloned().collect();

    let out = StatusOutput {
        connected: is_connected,
        active_connection: active_conn,
        active_profile,
        public_ip: if is_connected { state.last_ipv4.clone() } else { "—".to_string() },
        ipv4: if is_connected { state.last_ipv4 } else { "—".to_string() },
        ipv6: if is_connected { state.last_ipv6 } else { "—".to_string() },
        profiles_count: profiles.len(),
        profiles,
        favorites: fav_profiles,
        keys,
        config_dir: get_profiles_dir().to_string_lossy().to_string(),
        lang: state.lang,
    };

    println!("{}", serde_json::to_string(&out).unwrap_or_else(|_| "{}".to_string()));
}

fn cmd_toggle_favorite(profile_id: &str) {
    let mut state = load_state();
    let key = profile_id.replace("surfshark-", "").replace("surfshark_", "");
    if let Some(pos) = state.favorites.iter().position(|x| x == &key || x == profile_id) {
        state.favorites.remove(pos);
    } else {
        state.favorites.push(key);
    }
    save_state(&state);
    let favs_json = serde_json::to_string(&state.favorites).unwrap_or_else(|_| "[]".to_string());
    println!(r#"{{"success":true,"favorites":{}}}"#, favs_json);
}

fn cmd_set_lang(l: &str) {
    let mut state = load_state();
    state.lang = l.to_string();
    save_state(&state);
    println!(r#"{{"success":true,"lang":"{}"}}"#, l);
}

fn cmd_save_keys(pub_k: &str, priv_k: &str) {
    save_keys_and_update_configs(pub_k, priv_k);
    println!(r#"{{"success":true,"saved":true}}"#);
}

fn main() {
    let args: Vec<String> = std::env::args().collect();
    if args.len() < 2 || args[1] == "status" {
        cmd_status();
    } else {
        match args[1].as_str() {
            "fetch-ip" => fetch_ip_sync(),
            "toggle-favorite" if args.len() > 2 => cmd_toggle_favorite(&args[2]),
            "set-lang" if args.len() > 2 => cmd_set_lang(&args[2]),
            "save-keys" if args.len() > 3 => cmd_save_keys(&args[2], &args[3]),
            _ => println!("Usage: surfshark-ctl [status|fetch-ip|toggle-favorite <id>|set-lang <lang>|save-keys <pub> <priv>]"),
        }
    }
}
