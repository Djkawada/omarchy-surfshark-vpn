import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Ui
import qs.Commons

BarWidget {
  id: root
  moduleName: "com.github.djkawada.surfshark-vpn"

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  readonly property string ctlPath: Qt.resolvedUrl("bin/surfshark-ctl").toString().replace(/^file:\/\//, "")
  readonly property string shPath: Qt.resolvedUrl("bin/surfshark-vpn.sh").toString().replace(/^file:\/\//, "")
  
  property string manualLang: ""
  readonly property string currentLang: {
    if (manualLang && (manualLang === "fr" || manualLang === "ja" || manualLang === "en")) return manualLang
    var loc = Qt.locale().name.toLowerCase()
    if (loc.startsWith("fr")) return "fr"
    if (loc.startsWith("ja") || loc.startsWith("jp")) return "ja"
    return "en"
  }

  readonly property var i18n: ({
    "fr": {
      "app_title": "Surfshark VPN",
      "connected": "Connecté",
      "disconnected": "Déconnecté",
      "connecting": "Connexion en cours...",
      "disconnecting": "Déconnexion...",
      "btn_connect": "⚡ Connexion Rapide",
      "btn_disconnect": "🔴 Déconnecter le VPN",
      "favorites": "Serveurs Favoris ⭐",
      "all_locations": "Tous les Emplacements",
      "connect_action": "Connexion",
      "active_badge": "CONNECTÉ",
      "no_profiles": "Aucun profil WireGuard (.conf) trouvé",
      "setup_hint": "Téléchargez vos fichiers .conf sur surfshark.com (VPN > Manuel > WireGuard) et placez-les dans ~/.config/surfshark-vpn/configs/",
      "open_folder": "Ouvrir dossier configs 📁",
      "open_control_center": "Ouvrir Surfshark Manager ↗",
      "public_ip": "IP Publique : ",
      "lang_label": "Langue"
    },
    "ja": {
      "app_title": "Surfshark VPN",
      "connected": "接続中",
      "disconnected": "未接続",
      "connecting": "接続処理中...",
      "disconnecting": "切断処理中...",
      "btn_connect": "⚡ クイック接続",
      "btn_disconnect": "🔴 VPNを切断する",
      "favorites": "お気に入りサーバー ⭐",
      "all_locations": "すべてのロケーション",
      "connect_action": "接続",
      "active_badge": "接続中",
      "no_profiles": "WireGuard設定ファイル (.conf) がありません",
      "setup_hint": "surfshark.com (VPN > 手動設定 > WireGuard) から .conf ファイルをダウンロードし、~/.config/surfshark-vpn/configs/ に配置してください。",
      "open_folder": "設定フォルダを開く 📁",
      "open_control_center": "Surfshark マネージャーを開く ↗",
      "public_ip": "パブリックIP : ",
      "lang_label": "言語 (Language)"
    },
    "en": {
      "app_title": "Surfshark VPN",
      "connected": "Connected",
      "disconnected": "Disconnected",
      "connecting": "Connecting...",
      "disconnecting": "Disconnecting...",
      "btn_connect": "⚡ Quick Connect",
      "btn_disconnect": "🔴 Disconnect VPN",
      "favorites": "Favorite Servers ⭐",
      "all_locations": "All Locations",
      "connect_action": "Connect",
      "active_badge": "CONNECTED",
      "no_profiles": "No WireGuard (.conf) profiles found",
      "setup_hint": "Download your .conf files from surfshark.com (VPN > Manual > WireGuard) and place them in ~/.config/surfshark-vpn/configs/",
      "open_folder": "Open configs folder 📁",
      "open_control_center": "Open Surfshark Manager ↗",
      "public_ip": "Public IP: ",
      "lang_label": "Language"
    }
  })

  function t(key) {
    var dict = i18n[currentLang] || i18n["en"]
    return dict[key] || key
  }

  property bool isConnected: false
  property string publicIp: "—"
  property string ipv4: "—"
  property string ipv6: "—"
  property var activeProfile: null
  property var profileList: []
  property var favoriteList: []
  property string configDir: ""
  // CORRIGÉ : on ne stocke plus jamais private_key dans le QML
  property var keys: ({ public_key: "", has_private_key: false })
  property bool panelOpen: false
  property bool controlCenterOpen: false
  property bool isConnecting: false
  property string pendingProfileId: ""

  Process {
    id: saveKeysProc
    onRunningChanged: {
      if (!running) root.refresh()
    }
  }

  // CORRIGÉ : la clé privée n'apparaît plus dans les arguments du binaire surfshark-ctl
  // On écrit dans un fichier temporaire 0600, le binaire le lit puis le supprime immédiatement.
  function saveKeys(pubKey, privKey) {
    saveKeysProc.running = false

    var tmpPath = "/tmp/ss-priv-" + Date.now() + "-" + Math.floor(Math.random() * 1e9) + ".key"

    saveKeysProc.command = [
      "bash", "-c",
      'umask 077; printf "%s" "$3" > "$1" && chmod 600 "$1" && ' +
      '"' + root.ctlPath + '" save-keys "$2" "$1"; ' +
      'rm -f "$1"',
      "bash",
      tmpPath,
      pubKey,
      privKey
    ]
    saveKeysProc.running = true
  }

  Process {
    id: actionProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: console.log("[Surfshark action stdout]: " + text)
    }
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: console.log("[Surfshark action stderr]: " + text)
    }
    onRunningChanged: {
      if (!running) {
        console.log("[Surfshark action finished]")
        root.isConnecting = false
        root.pendingProfileId = ""
        root.refresh()
      }
    }
  }

  Process {
    id: toggleFavProc
    onRunningChanged: {
      if (!running) root.refresh()
    }
  }

  Process { id: setLangProc }

  Process {
    id: openFolderProc
    command: ["xdg-open", root.configDir || (Quickshell.env("HOME") + "/.config/surfshark-vpn/configs")]
  }

  // Dismiss handler for PopupCard FocusGrab
  function close() {
    root.panelOpen = false
  }

  function refresh() {
    if (!statusProc.running) statusProc.running = true
  }

  function connectTo(profileId) {
    console.log("[Surfshark] connectTo called for: " + profileId)
    root.isConnecting = true
    root.pendingProfileId = profileId
    actionProc.running = false
    actionProc.command = ["systemd-run", "--user", "--pipe", root.shPath, "connect", profileId]
    actionProc.running = true
  }

  function disconnectVPN() {
    console.log("[Surfshark] disconnectVPN called")
    root.isConnected = false
    root.isConnecting = false
    root.pendingProfileId = ""
    actionProc.running = false
    actionProc.command = ["systemd-run", "--user", "--pipe", root.shPath, "disconnect"]
    actionProc.running = true
  }

  function toggleFavorite(profileId) {
    toggleFavProc.running = false
    toggleFavProc.command = [root.ctlPath, "toggle-favorite", profileId]
    toggleFavProc.running = true
  }

  function setLanguage(l) {
    root.manualLang = l
    setLangProc.running = false
    setLangProc.command = [root.ctlPath, "set-lang", l]
    setLangProc.running = true
  }

  function openControlCenter() {
    root.controlCenterOpen = true
  }

  function closeControlCenter() {
    root.controlCenterOpen = false
  }

  function openFolder() {
    openFolderProc.running = false
    openFolderProc.running = true
  }

  Component.onCompleted: refresh()

  Timer {
    interval: root.panelOpen ? 1500 : 4000
    running: true
    repeat: true
    onTriggered: root.refresh()
  }

  // --- Backend Status Monitor ---
  Process {
    id: statusProc
    command: [root.ctlPath, "status"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          var data = JSON.parse(text || "{}")
          console.log("[Surfshark] Status received: connected=" + data.connected + " ip=" + data.public_ip + " profs=" + (data.profiles ? data.profiles.length : 0))
          root.isConnected = Boolean(data.connected)
          if (root.isConnected) {
            root.isConnecting = false
            root.pendingProfileId = ""
          }
          root.publicIp = data.public_ip || "—"
          root.ipv4 = data.ipv4 || data.public_ip || "—"
          root.ipv6 = data.ipv6 || "—"
          root.activeProfile = data.active_profile || null
          root.profileList = data.profiles || []
          root.favoriteList = data.favorites || []
          root.configDir = data.config_dir || ""

          // CORRIGÉ : on n'accepte plus jamais private_key depuis le status
          if (data.keys) {
            root.keys = {
              public_key: data.keys.public_key || "",
              has_private_key: Boolean(data.keys.has_private_key)
            }
          }
          if (data.lang) root.manualLang = data.lang
        } catch (e) {
          console.log("[Surfshark] JSON parse error: " + e + " raw: " + text)
        }
      }
    }
  }

  Loader {
    id: controlCenterLoader
    active: root.controlCenterOpen
    sourceComponent: Component {
      SurfsharkControlCenter {
        pluginRoot: root
        visible: true
        onClosing: root.closeControlCenter()
      }
    }
  }

  // --- Status Bar Icon Button ---
  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    slotSize: Style.bar.statusSlot
    tooltipText: root.isConnected ? (root.t("app_title") + " : " + root.t("connected") + " 🟢\n" + (root.activeProfile ? root.activeProfile.display_name : "VPN Tunnel") + "\nIPv4: " + root.ipv4 + (root.ipv6 !== "—" ? ("\nIPv6: " + root.ipv6) : "")) : (root.t("app_title") + " : " + root.t("disconnected") + " ⚪\nIPv4: " + root.ipv4)

    iconComponent: Component {
      Item {
        anchors.fill: parent

        Image {
          anchors.centerIn: parent
          source: root.isConnected ? Qt.resolvedUrl("assets/surfshark-active.svg") : Qt.resolvedUrl("assets/surfshark-inactive.svg")
          sourceSize.width: Style.space(16)
          sourceSize.height: Style.space(16)
        }

        // Small glowing dot when VPN is active
        Rectangle {
          visible: root.isConnected
          width: Style.space(5)
          height: Style.space(5)
          radius: Style.space(2.5)
          color: "#16D2B6"
          anchors.right: parent.right
          anchors.bottom: parent.bottom
        }
      }
    }

    onPressed: function(b) {
      if (b === Qt.RightButton) {
        root.openControlCenter()
      } else {
        root.panelOpen = !root.panelOpen
        if (root.panelOpen) root.refresh()
      }
    }
  }

  // --- Flyout Popup Panel ---
  PopupCard {
    id: popupPanel
    anchorItem: button
    bar: root.bar
    owner: root
    open: root.panelOpen
    contentWidth: popupPanel.fittedContentWidth(Style.space(430))
    contentHeight: popupPanel.fittedContentHeight(Math.min(Style.space(600), contentColumn.implicitHeight))

    Column {
      id: contentColumn
      anchors.fill: parent
      spacing: Style.space(12)

      // Header
      Item {
        width: parent.width
        height: Style.space(38)

        Row {
          anchors.left: parent.left
          anchors.verticalCenter: parent.verticalCenter
          spacing: Style.space(10)

          Image {
            source: root.isConnected ? Qt.resolvedUrl("assets/surfshark-active.svg") : Qt.resolvedUrl("assets/surfshark-inactive.svg")
            sourceSize.width: Style.space(30)
            sourceSize.height: Style.space(30)
            anchors.verticalCenter: parent.verticalCenter
          }

          Column {
            spacing: Style.space(2)
            anchors.verticalCenter: parent.verticalCenter

            Text {
              text: root.t("app_title")
              font.family: Style.font.family
              font.pixelSize: 15
              font.bold: true
              color: Color.foreground
            }

            Text {
              text: root.isConnected ? (root.t("connected") + " • " + (root.activeProfile ? root.activeProfile.display_name : "WireGuard")) : root.t("disconnected")
              font.family: Style.font.family
              font.pixelSize: 12
              color: root.isConnected ? "#16D2B6" : Color.muted
            }
          }
        }
      }

      // Public IP Card (IPv4 + IPv6)
      Rectangle {
        width: parent.width
        implicitHeight: ipCol.implicitHeight + Style.space(16)
        color: root.isConnected ? "#0d2b27" : "#1a202c"
        radius: 6
        border.color: root.isConnected ? "#16D2B6" : "#2d3748"
        border.width: 1

        Column {
          id: ipCol
          anchors.centerIn: parent
          spacing: Style.space(4)

          Row {
            spacing: Style.space(8)
            anchors.horizontalCenter: parent.horizontalCenter

            Text {
              text: "IPv4 :"
              font.family: Style.font.family
              font.pixelSize: 12
              font.bold: true
              color: Color.muted
            }
            Text {
              text: root.ipv4
              font.family: "monospace"
              font.pixelSize: 12
              font.bold: true
              color: root.isConnected ? "#16D2B6" : Color.foreground
            }
          }

          Row {
            visible: root.ipv6 !== "—" && root.ipv6 !== ""
            spacing: Style.space(8)
            anchors.horizontalCenter: parent.horizontalCenter

            Text {
              text: "IPv6 :"
              font.family: Style.font.family
              font.pixelSize: 11
              font.bold: true
              color: Color.muted
            }
            Text {
              text: root.ipv6
              font.family: "monospace"
              font.pixelSize: 11
              font.bold: true
              color: root.isConnected ? "#16D2B6" : Color.foreground
            }
          }
        }
      }

      // Main Action Quick Connect / Disconnect Button
      Button {
        width: parent.width
        height: Style.space(40)
        text: root.isConnecting ? ("⏳ " + root.t("connecting")) : (root.isConnected ? root.t("btn_disconnect") : root.t("btn_connect"))
        selected: root.isConnected || root.isConnecting
        onClicked: {
          if (root.isConnected) {
            root.disconnectVPN()
          } else {
            if (root.favoriteList.length > 0) {
              root.connectTo(root.favoriteList[0].id)
            } else if (root.profileList.length > 0) {
              root.connectTo(root.profileList[0].id)
            }
          }
        }
      }

      PanelSeparator {}

      // Scrollable Profiles & Favorites Section
      ScrollView {
        id: serverScrollView
        width: parent.width
        height: Style.space(260)
        clip: true
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

        Column {
          width: serverScrollView.availableWidth
          spacing: Style.space(8)

          // --- FAVORITES SECTION ---
          PanelSectionHeader {
            visible: root.favoriteList.length > 0
            text: root.t("favorites") + " (" + root.favoriteList.length + ")"
          }

          Repeater {
            model: root.favoriteList

            Rectangle {
              id: favCard
              width: parent.width
              height: Style.space(46)
              radius: 8
              readonly property bool isActive: root.isConnected && root.activeProfile && root.activeProfile.id === modelData.id
              color: isActive ? "#0e342f" : (favMouse.containsMouse ? "#202b38" : "#161d26")
              border.color: isActive ? "#16D2B6" : (favMouse.containsMouse ? "#3b4a5d" : "#242f3d")
              border.width: 1

              // Star Button Area on Left
              Item {
                id: favStarArea
                width: Style.space(36)
                height: parent.height
                anchors.left: parent.left

                Text {
                  anchors.centerIn: parent
                  text: "⭐"
                  font.pixelSize: 16
                }

                MouseArea {
                  anchors.fill: parent
                  preventStealing: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.toggleFavorite(modelData.id)
                }
              }

              // Flag Item
              Item {
                id: favFlagArea
                width: Style.space(26)
                height: parent.height
                anchors.left: favStarArea.right

                Text {
                  anchors.centerIn: parent
                  text: modelData.flag || "🌐"
                  font.pixelSize: 18
                }
              }

              // Status Badge on Right
              Rectangle {
                id: favBadge
                anchors.right: parent.right
                anchors.rightMargin: Style.space(10)
                anchors.verticalCenter: parent.verticalCenter
                height: Style.space(26)
                radius: 6
                color: favCard.isActive ? "#0d3a33" : (favMouse.containsMouse ? "#1e3a4a" : "transparent")
                border.color: favCard.isActive ? "#16D2B6" : (favMouse.containsMouse ? "#16D2B6" : "#2d3748")
                border.width: 1
                width: favBadgeText.implicitWidth + Style.space(16)

                Text {
                  id: favBadgeText
                  anchors.centerIn: parent
                  text: favCard.isActive ? ("● " + root.t("active_badge")) : ((root.isConnecting && root.pendingProfileId === modelData.id) ? ("⏳ " + root.t("connecting")) : root.t("connect_action"))
                  font.family: Style.font.family
                  font.pixelSize: 12
                  font.bold: true
                  color: favCard.isActive ? "#16D2B6" : ((root.isConnecting && root.pendingProfileId === modelData.id) ? "#ffd700" : (favMouse.containsMouse ? "#ffffff" : Color.muted))
                }
              }

              // Country + City in Center
              Column {
                anchors.left: favFlagArea.right
                anchors.leftMargin: Style.space(8)
                anchors.right: favBadge.left
                anchors.rightMargin: Style.space(10)
                anchors.verticalCenter: parent.verticalCenter
                spacing: Style.space(2)

                Text {
                  text: modelData.country
                  font.family: Style.font.family
                  font.pixelSize: 14
                  font.bold: true
                  color: favCard.isActive ? "#16D2B6" : Color.foreground
                  elide: Text.ElideRight
                  width: parent.width
                }
                Text {
                  text: modelData.city
                  font.family: Style.font.family
                  font.pixelSize: 12
                  color: Color.muted
                  elide: Text.ElideRight
                  width: parent.width
                }
              }

              // Clickable Area
              MouseArea {
                id: favMouse
                anchors.left: favFlagArea.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                preventStealing: true
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  if (favCard.isActive) {
                    root.disconnectVPN()
                  } else {
                    root.connectTo(modelData.id)
                  }
                }
              }
            }
          }

          // --- ALL LOCATIONS SECTION ---
          PanelSectionHeader {
            text: root.t("all_locations") + " (" + root.profileList.length + ")"
          }

          Repeater {
            model: root.profileList

            Rectangle {
              id: allCard
              width: parent.width
              height: Style.space(46)
              radius: 8
              readonly property bool isActive: root.isConnected && root.activeProfile && root.activeProfile.id === modelData.id
              color: isActive ? "#0e342f" : (allMouse.containsMouse ? "#1a232e" : "#12171f")
              border.color: isActive ? "#16D2B6" : (allMouse.containsMouse ? "#323f50" : "#1f2733")
              border.width: 1

              // Star Button Area on Left
              Item {
                id: allStarArea
                width: Style.space(36)
                height: parent.height
                anchors.left: parent.left

                Text {
                  anchors.centerIn: parent
                  text: modelData.is_favorite ? "⭐" : "☆"
                  font.pixelSize: 16
                  color: modelData.is_favorite ? "#ffd700" : Color.muted
                }

                MouseArea {
                  anchors.fill: parent
                  preventStealing: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.toggleFavorite(modelData.id)
                }
              }

              // Flag Item
              Item {
                id: allFlagArea
                width: Style.space(26)
                height: parent.height
                anchors.left: allStarArea.right

                Text {
                  anchors.centerIn: parent
                  text: modelData.flag || "🌐"
                  font.pixelSize: 18
                }
              }

              // Status Badge on Right
              Rectangle {
                id: allBadge
                anchors.right: parent.right
                anchors.rightMargin: Style.space(10)
                anchors.verticalCenter: parent.verticalCenter
                height: Style.space(26)
                radius: 6
                color: allCard.isActive ? "#0d3a33" : (allMouse.containsMouse ? "#1e3a4a" : "transparent")
                border.color: allCard.isActive ? "#16D2B6" : (allMouse.containsMouse ? "#16D2B6" : "#2d3748")
                border.width: 1
                width: allBadgeText.implicitWidth + Style.space(16)

                Text {
                  id: allBadgeText
                  anchors.centerIn: parent
                  text: allCard.isActive ? ("● " + root.t("active_badge")) : ((root.isConnecting && root.pendingProfileId === modelData.id) ? ("⏳ " + root.t("connecting")) : root.t("connect_action"))
                  font.family: Style.font.family
                  font.pixelSize: 12
                  font.bold: true
                  color: allCard.isActive ? "#16D2B6" : ((root.isConnecting && root.pendingProfileId === modelData.id) ? "#ffd700" : (allMouse.containsMouse ? "#ffffff" : Color.muted))
                }
              }

              // Country + City in Center
              Column {
                anchors.left: allFlagArea.right
                anchors.leftMargin: Style.space(8)
                anchors.right: allBadge.left
                anchors.rightMargin: Style.space(10)
                anchors.verticalCenter: parent.verticalCenter
                spacing: Style.space(2)

                Text {
                  text: modelData.country
                  font.family: Style.font.family
                  font.pixelSize: 14
                  font.bold: true
                  color: allCard.isActive ? "#16D2B6" : Color.foreground
                  elide: Text.ElideRight
                  width: parent.width
                }
                Text {
                  text: modelData.city
                  font.family: Style.font.family
                  font.pixelSize: 12
                  color: Color.muted
                  elide: Text.ElideRight
                  width: parent.width
                }
              }

              // Clickable Area
              MouseArea {
                id: allMouse
                anchors.left: allFlagArea.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                preventStealing: true
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  if (allCard.isActive) {
                    root.disconnectVPN()
                  } else {
                    root.connectTo(modelData.id)
                  }
                }
              }
            }
          }

          // Empty state guide
          Rectangle {
            visible: root.profileList.length === 0
            width: parent.width
            color: "#161d26"
            radius: 8
            border.color: "#2d3748"
            border.width: 1
            implicitHeight: emptyCol.implicitHeight + Style.space(20)

            Column {
              id: emptyCol
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.top: parent.top
              anchors.margins: Style.space(10)
              spacing: Style.space(8)

              Text {
                text: root.t("no_profiles")
                font.family: Style.font.family
                font.pixelSize: 14
                font.bold: true
                color: "#e2e8f0"
              }

              Text {
                text: root.t("setup_hint")
                font.family: Style.font.family
                font.pixelSize: 12
                color: Color.muted
                wrapMode: Text.WordWrap
                width: parent.width
                lineHeight: 1.35
              }

              Button {
                width: parent.width
                text: root.t("open_folder")
                onClicked: root.openFolder()
              }
            }
          }
        }
      }

      // Language Switcher Row
      Row {
        width: parent.width
        spacing: Style.space(6)

        Text {
          text: root.t("lang_label")
          font.family: Style.font.family
          font.pixelSize: 12
          color: Color.muted
          anchors.verticalCenter: parent.verticalCenter
        }

        Item {
          width: Math.max(4, parent.width - parent.children[0].implicitWidth - (3 * Style.space(42) + 2 * Style.space(6)) - Style.space(10))
          height: 1
        }

        Button {
          text: "FR"
          selected: root.currentLang === "fr"
          width: Style.space(36)
          onClicked: root.setLanguage("fr")
        }
        Button {
          text: "EN"
          selected: root.currentLang === "en"
          width: Style.space(36)
          onClicked: root.setLanguage("en")
        }
        Button {
          text: "JA"
          selected: root.currentLang === "ja"
          width: Style.space(36)
          onClicked: root.setLanguage("ja")
        }
      }

      // Open Control Center button
      Button {
        width: parent.width
        text: root.t("open_control_center")
        onClicked: {
          root.panelOpen = false
          root.openControlCenter()
        }
      }
    }
  }
}
