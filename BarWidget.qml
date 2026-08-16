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
      "btn_connect": "Connexion Rapide",
      "btn_disconnect": "Déconnecter le VPN",
      "favorites": "Serveurs Favoris ⭐",
      "all_locations": "Tous les Emplacements",
      "click_to_connect": "Cliquer pour connecter",
      "active_badge": "CONNECTÉ",
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
      "btn_connect": "クイック接続",
      "btn_disconnect": "VPNを切断する",
      "favorites": "お気に入りサーバー ⭐",
      "all_locations": "すべてのロケーション",
      "click_to_connect": "クリックして接続",
      "active_badge": "接続中",
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
      "btn_connect": "Quick Connect",
      "btn_disconnect": "Disconnect VPN",
      "favorites": "Favorite Servers ⭐",
      "all_locations": "All Locations",
      "click_to_connect": "Click to connect",
      "active_badge": "CONNECTED",
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
  property var favoriteList: []
  property string configDir: ""
  property bool panelOpen: false
  property bool controlCenterOpen: false

  // Dismiss handler for PopupCard FocusGrab
  function close() {
    root.panelOpen = false
  }

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

  function toggleFavorite(profileId) {
    toggleFavProc.command = [root.ctlPath, "toggle-favorite", profileId]
    toggleFavProc.running = true
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
          root.favoriteList = data.favorites || []
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

  Process {
    id: toggleFavProc
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
    contentWidth: popupPanel.fittedContentWidth(Style.space(380))
    contentHeight: popupPanel.fittedContentHeight(Math.min(Style.space(560), contentColumn.implicitHeight))

    Column {
      id: contentColumn
      anchors.fill: parent
      spacing: Style.space(10)

      // Header
      Row {
        spacing: Style.space(10)
        width: parent.width

        Image {
          source: root.isConnected ? Qt.resolvedUrl("assets/surfshark-active.svg") : Qt.resolvedUrl("assets/surfshark-inactive.svg")
          sourceSize.width: Style.space(28)
          sourceSize.height: Style.space(28)
          anchors.verticalCenter: parent.verticalCenter
        }

        Column {
          spacing: Style.space(2)
          anchors.verticalCenter: parent.verticalCenter
          width: parent.width - Style.space(38)

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

      // Main Action Quick Connect / Disconnect Button
      Button {
        width: parent.width
        height: Style.space(38)
        text: root.isConnected ? ("🔴 " + root.t("btn_disconnect")) : ("⚡ " + root.t("btn_connect"))
        selected: root.isConnected
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
        width: parent.width
        height: Style.space(250)
        clip: true
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

        Column {
          width: parent.width
          spacing: Style.space(6)

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
              height: Style.space(40)
              radius: 6
              readonly property bool isActive: root.isConnected && root.activeProfile && root.activeProfile.id === modelData.id
              color: isActive ? "#0e342f" : (favMouse.containsMouse ? "#202b38" : "#161d26")
              border.color: isActive ? "#16D2B6" : (favMouse.containsMouse ? "#3b4a5d" : "#242f3d")
              border.width: 1

              // Star Button Area on Left
              Item {
                id: favStarArea
                width: Style.space(32)
                height: parent.height
                anchors.left: parent.left

                Text {
                  anchors.centerIn: parent
                  text: "⭐"
                  font.pixelSize: 14
                }

                MouseArea {
                  anchors.fill: parent
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.toggleFavorite(modelData.id)
                }
              }

              // Clickable Server Card (Middle + Right)
              MouseArea {
                id: favMouse
                anchors.left: favStarArea.right
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  if (favCard.isActive) {
                    root.disconnectVPN()
                  } else {
                    root.connectTo(modelData.id)
                  }
                }

                Row {
                  anchors.fill: parent
                  anchors.rightMargin: Style.space(8)
                  spacing: Style.space(8)

                  Text {
                    text: modelData.flag || "🌐"
                    font.pixelSize: 16
                    anchors.verticalCenter: parent.verticalCenter
                  }

                  Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 1
                    width: parent.width - Style.space(130)

                    Text {
                      text: modelData.country
                      font.family: Style.font.family
                      font.pixelSize: Style.font.body - 1
                      font.bold: true
                      color: favCard.isActive ? "#16D2B6" : Color.foreground
                      elide: Text.ElideRight
                    }
                    Text {
                      text: modelData.city
                      font.family: Style.font.family
                      font.pixelSize: Style.font.caption - 1
                      color: Color.muted
                      elide: Text.ElideRight
                    }
                  }

                  Item {
                    width: Math.max(2, parent.width - parent.children[0].implicitWidth - parent.children[1].implicitWidth - favBadge.implicitWidth - Style.space(16))
                    height: 1
                  }

                  // Status Badge or Connect Hint
                  Rectangle {
                    id: favBadge
                    anchors.verticalCenter: parent.verticalCenter
                    height: Style.space(22)
                    radius: 4
                    color: favCard.isActive ? "#0d3a33" : (favMouse.containsMouse ? "#1e3a4a" : "transparent")
                    border.color: favCard.isActive ? "#16D2B6" : (favMouse.containsMouse ? "#16D2B6" : "#2d3748")
                    border.width: 1
                    width: favBadgeText.implicitWidth + Style.space(12)

                    Text {
                      id: favBadgeText
                      anchors.centerIn: parent
                      text: favCard.isActive ? ("● " + root.t("active_badge")) : "Connecter"
                      font.family: Style.font.family
                      font.pixelSize: Style.font.caption - 2
                      font.bold: true
                      color: favCard.isActive ? "#16D2B6" : (favMouse.containsMouse ? "#ffffff" : Color.muted)
                    }
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
              height: Style.space(40)
              radius: 6
              readonly property bool isActive: root.isConnected && root.activeProfile && root.activeProfile.id === modelData.id
              color: isActive ? "#0e342f" : (allMouse.containsMouse ? "#1a232e" : "#12171f")
              border.color: isActive ? "#16D2B6" : (allMouse.containsMouse ? "#323f50" : "#1f2733")
              border.width: 1

              // Star Button Area on Left
              Item {
                id: allStarArea
                width: Style.space(32)
                height: parent.height
                anchors.left: parent.left

                Text {
                  anchors.centerIn: parent
                  text: modelData.is_favorite ? "⭐" : "☆"
                  font.pixelSize: 14
                  color: modelData.is_favorite ? "#ffd700" : Color.muted
                }

                MouseArea {
                  anchors.fill: parent
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.toggleFavorite(modelData.id)
                }
              }

              // Clickable Server Card (Middle + Right)
              MouseArea {
                id: allMouse
                anchors.left: allStarArea.right
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  if (allCard.isActive) {
                    root.disconnectVPN()
                  } else {
                    root.connectTo(modelData.id)
                  }
                }

                Row {
                  anchors.fill: parent
                  anchors.rightMargin: Style.space(8)
                  spacing: Style.space(8)

                  Text {
                    text: modelData.flag || "🌐"
                    font.pixelSize: 16
                    anchors.verticalCenter: parent.verticalCenter
                  }

                  Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 1
                    width: parent.width - Style.space(130)

                    Text {
                      text: modelData.country
                      font.family: Style.font.family
                      font.pixelSize: Style.font.body - 1
                      font.bold: true
                      color: allCard.isActive ? "#16D2B6" : Color.foreground
                      elide: Text.ElideRight
                    }
                    Text {
                      text: modelData.city
                      font.family: Style.font.family
                      font.pixelSize: Style.font.caption - 1
                      color: Color.muted
                      elide: Text.ElideRight
                    }
                  }

                  Item {
                    width: Math.max(2, parent.width - parent.children[0].implicitWidth - parent.children[1].implicitWidth - allBadge.implicitWidth - Style.space(16))
                    height: 1
                  }

                  // Status Badge or Connect Hint
                  Rectangle {
                    id: allBadge
                    anchors.verticalCenter: parent.verticalCenter
                    height: Style.space(22)
                    radius: 4
                    color: allCard.isActive ? "#0d3a33" : (allMouse.containsMouse ? "#1e3a4a" : "transparent")
                    border.color: allCard.isActive ? "#16D2B6" : (allMouse.containsMouse ? "#16D2B6" : "#2d3748")
                    border.width: 1
                    width: allBadgeText.implicitWidth + Style.space(12)

                    Text {
                      id: allBadgeText
                      anchors.centerIn: parent
                      text: allCard.isActive ? ("● " + root.t("active_badge")) : "Connecter"
                      font.family: Style.font.family
                      font.pixelSize: Style.font.caption - 2
                      font.bold: true
                      color: allCard.isActive ? "#16D2B6" : (allMouse.containsMouse ? "#ffffff" : Color.muted)
                    }
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
