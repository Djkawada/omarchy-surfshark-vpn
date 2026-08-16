import QtQuick
import Quickshell
import Quickshell.Io
import qs.Ui
import qs.Commons

BarWidget {
  id: root
  moduleName: "com.github.djkawada.surfshark-vpn"

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  readonly property string ctlPath: Qt.resolvedUrl("bin/surfshark-ctl.py").toString().replace(/^file:\/\//, "")
  
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
      "btn_connect": "Se connecter",
      "btn_disconnect": "Déconnecter",
      "locations": "Emplacements & Serveurs",
      "no_profiles": "Aucun profil WireGuard (.conf) trouvé",
      "setup_hint": "Téléchargez vos fichiers .conf sur surfshark.com (VPN > Manuel > WireGuard) et placez-les dans ~/.config/surfshark-vpn/configs/",
      "open_folder": "Ouvrir dossier configs 📁",
      "open_control_center": "Ouvrir Surfshark Manager ↗",
      "public_ip": "IP Publique : ",
      "lang_label": "Langue",
      "quick_connect": "Connexion Rapide"
    },
    "ja": {
      "app_title": "Surfshark VPN",
      "connected": "接続中",
      "disconnected": "未接続",
      "connecting": "接続処理中...",
      "disconnecting": "切断処理中...",
      "btn_connect": "接続する",
      "btn_disconnect": "切断する",
      "locations": "ロケーション＆サーバー",
      "no_profiles": "WireGuard設定ファイル (.conf) がありません",
      "setup_hint": "surfshark.com (VPN > 手動設定 > WireGuard) から .conf ファイルをダウンロードし、~/.config/surfshark-vpn/configs/ に配置してください。",
      "open_folder": "設定フォルダを開く 📁",
      "open_control_center": "Surfshark マネージャーを開く ↗",
      "public_ip": "パブリックIP : ",
      "lang_label": "言語 (Language)",
      "quick_connect": "クイック接続"
    },
    "en": {
      "app_title": "Surfshark VPN",
      "connected": "Connected",
      "disconnected": "Disconnected",
      "connecting": "Connecting...",
      "disconnecting": "Disconnecting...",
      "btn_connect": "Connect",
      "btn_disconnect": "Disconnect",
      "locations": "Locations & Servers",
      "no_profiles": "No WireGuard (.conf) profiles found",
      "setup_hint": "Download your .conf files from surfshark.com (VPN > Manual > WireGuard) and place them in ~/.config/surfshark-vpn/configs/",
      "open_folder": "Open configs folder 📁",
      "open_control_center": "Open Surfshark Manager ↗",
      "public_ip": "Public IP: ",
      "lang_label": "Language",
      "quick_connect": "Quick Connect"
    }
  })

  function t(key) {
    var dict = i18n[currentLang] || i18n["en"]
    return dict[key] || key
  }

  property bool isConnected: false
  property string publicIp: "—"
  property var activeProfile: null
  property var profileList: []
  property string configDir: ""
  property bool panelOpen: false
  property bool controlCenterOpen: false

  function refresh() {
    if (!statusProc.running) statusProc.running = true
  }

  function connectTo(profileId) {
    connectProc.command = [root.ctlPath, "connect", profileId]
    connectProc.running = true
  }

  function disconnectVPN() {
    disconnectProc.command = [root.ctlPath, "disconnect"]
    disconnectProc.running = true
  }

  function setLanguage(l) {
    root.manualLang = l
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
    openFolderProc.running = true
  }

  Component.onCompleted: refresh()

  Timer {
    interval: root.panelOpen ? 1500 : 4000
    running: true
    repeat: true
    onTriggered: root.refresh()
  }

  // --- Backend Process Handlers ---
  Process {
    id: statusProc
    command: [root.ctlPath, "status"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          var data = JSON.parse(text || "{}")
          root.isConnected = Boolean(data.connected)
          root.publicIp = data.public_ip || "—"
          root.activeProfile = data.active_profile || null
          root.profileList = data.profiles || []
          root.configDir = data.config_dir || ""
          if (data.lang) root.manualLang = data.lang
        } catch (e) {}
      }
    }
  }

  Process {
    id: connectProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.refresh()
    }
  }

  Process {
    id: disconnectProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.refresh()
    }
  }

  Process { id: setLangProc }

  Process {
    id: openFolderProc
    command: ["xdg-open", root.configDir || "/home/pierre/.config/surfshark-vpn/configs"]
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
    tooltipText: root.isConnected ? (root.t("app_title") + " : " + root.t("connected") + " 🟢\n" + (root.activeProfile ? root.activeProfile.display_name : "VPN Tunnel") + "\n" + root.t("public_ip") + root.publicIp) : (root.t("app_title") + " : " + root.t("disconnected") + " ⚪\n" + root.t("public_ip") + root.publicIp)

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
    contentWidth: popupPanel.fittedContentWidth(Style.space(340))
    contentHeight: popupPanel.fittedContentHeight(contentColumn.implicitHeight)

    Column {
      id: contentColumn
      anchors.fill: parent
      spacing: Style.space(12)

      // Header
      Row {
        spacing: Style.space(10)
        width: parent.width

        Image {
          source: root.isConnected ? Qt.resolvedUrl("assets/surfshark-active.svg") : Qt.resolvedUrl("assets/surfshark-inactive.svg")
          sourceSize.width: Style.space(26)
          sourceSize.height: Style.space(26)
          anchors.verticalCenter: parent.verticalCenter
        }

        Column {
          spacing: Style.space(2)
          anchors.verticalCenter: parent.verticalCenter
          width: parent.width - Style.space(36)

          Text {
            text: root.t("app_title")
            font.family: Style.font.family
            font.pixelSize: Style.font.body
            font.bold: true
            color: Color.foreground
          }

          Text {
            text: root.isConnected ? (root.t("connected") + " • " + (root.activeProfile ? root.activeProfile.display_name : "WireGuard")) : root.t("disconnected")
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            color: root.isConnected ? "#16D2B6" : Color.muted
          }
        }
      }

      // Public IP Pill
      Rectangle {
        width: parent.width
        height: Style.space(30)
        color: root.isConnected ? "#0d2b27" : "#1a202c"
        radius: 6
        border.color: root.isConnected ? "#16D2B6" : "#2d3748"
        border.width: 1

        Row {
          anchors.centerIn: parent
          spacing: Style.space(6)

          Text {
            text: "IP :"
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            color: Color.muted
          }
          Text {
            text: root.publicIp
            font.family: "monospace"
            font.pixelSize: Style.font.caption
            font.bold: true
            color: root.isConnected ? "#16D2B6" : Color.foreground
          }
        }
      }

      // Main Action Toggle Button
      Button {
        width: parent.width
        height: Style.space(38)
        text: root.isConnected ? ("🔴 " + root.t("btn_disconnect")) : ("⚡ " + root.t("btn_connect"))
        selected: root.isConnected
        onClicked: {
          if (root.isConnected) {
            root.disconnectVPN()
          } else {
            if (root.profileList.length > 0) {
              root.connectTo(root.profileList[0].id)
            } else {
              root.refresh()
            }
          }
        }
      }

      PanelSeparator {}

      // Location / Server List Header
      PanelSectionHeader {
        text: root.t("locations") + " (" + root.profileList.length + ")"
      }

      // Profile List or Setup Guide
      Column {
        width: parent.width
        spacing: Style.space(6)

        Repeater {
          model: root.profileList.slice(0, 6)

          Rectangle {
            width: parent.width
            height: Style.space(36)
            color: (root.activeProfile && root.activeProfile.id === modelData.id) ? "#0e342f" : "#181f2a"
            radius: 6
            border.color: (root.activeProfile && root.activeProfile.id === modelData.id) ? "#16D2B6" : "#283446"
            border.width: 1

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                if (root.activeProfile && root.activeProfile.id === modelData.id) {
                  root.disconnectVPN()
                } else {
                  root.connectTo(modelData.id)
                }
              }
            }

            Row {
              anchors.fill: parent
              anchors.margins: Style.space(8)
              spacing: Style.space(8)

              Text {
                text: modelData.flag || "🌐"
                font.pixelSize: 14
                anchors.verticalCenter: parent.verticalCenter
              }

              Text {
                text: modelData.country + " (" + modelData.city + ")"
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                font.bold: (root.activeProfile && root.activeProfile.id === modelData.id)
                color: (root.activeProfile && root.activeProfile.id === modelData.id) ? "#16D2B6" : Color.foreground
                anchors.verticalCenter: parent.verticalCenter
              }

              Item { width: Math.max(4, parent.width - parent.children[0].implicitWidth - parent.children[1].implicitWidth - statusDot.implicitWidth - Style.space(24)); height: 1 }

              Rectangle {
                id: statusDot
                width: Style.space(8)
                height: Style.space(8)
                radius: Style.space(4)
                color: (root.activeProfile && root.activeProfile.id === modelData.id) ? "#16D2B6" : "#3b4758"
                anchors.verticalCenter: parent.verticalCenter
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
              font.pixelSize: Style.font.caption
              font.bold: true
              color: "#e2e8f0"
            }

            Text {
              text: root.t("setup_hint")
              font.family: Style.font.family
              font.pixelSize: Style.font.caption - 1
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

      // Language Switcher Row
      Row {
        width: parent.width
        spacing: Style.space(6)

        Text {
          text: root.t("lang_label")
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
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
          width: Style.space(42)
          onClicked: root.setLanguage("fr")
        }
        Button {
          text: "EN"
          selected: root.currentLang === "en"
          width: Style.space(42)
          onClicked: root.setLanguage("en")
        }
        Button {
          text: "JA"
          selected: root.currentLang === "ja"
          width: Style.space(42)
          onClicked: root.setLanguage("ja")
        }
      }

      PanelSeparator {}

      // Action Button for Large Control Center
      Button {
        width: parent.width
        text: root.t("open_control_center")
        bordered: true
        onClicked: {
          root.panelOpen = false
          root.openControlCenter()
        }
      }
    }
  }
}
