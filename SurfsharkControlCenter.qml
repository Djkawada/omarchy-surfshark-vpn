import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Ui
import qs.Commons

FloatingWindow {
  id: rootWindow
  title: "Surfshark VPN Manager"
  color: Color.background
  implicitWidth: Style.space(980)
  implicitHeight: Style.space(680)
  minimumSize: Qt.size(Style.space(820), Style.space(560))

  property var pluginRoot: null
  signal closing()

  readonly property string currentLang: pluginRoot ? pluginRoot.currentLang : "en"
  function t(key) { return pluginRoot ? pluginRoot.t(key) : key }

  function requestClose() {
    rootWindow.visible = false
    rootWindow.closing()
  }

  onVisibleChanged: {
    if (!visible) {
      rootWindow.closing()
    }
  }

  // Console Logs
  property var logEntries: []

  function addLog(msg, type) {
    var time = Qt.formatTime(new Date(), "hh:mm:ss")
    var entry = "[" + time + "] " + msg
    var arr = rootWindow.logEntries.slice(0, 100)
    arr.unshift({ text: entry, type: type || "info" })
    rootWindow.logEntries = arr
  }

  Component.onCompleted: {
    addLog(currentLang === "fr" ? "Surfshark VPN Manager démarré (Moteur WireGuard natif)." : (currentLang === "ja" ? "Surfshark VPN マネージャー起動完了 (WireGuard ネイティブ)。" : "Surfshark VPN Manager started (Native WireGuard)."), "ok")
  }

  FocusScope {
    anchors.fill: parent
    focus: true

    Keys.onPressed: function(event) {
      if (event.key === Qt.Key_Escape) {
        rootWindow.requestClose()
        event.accepted = true
      }
    }

    Item {
      anchors.fill: parent
      anchors.margins: Style.space(16)

      // --- Top Header ---
      Item {
        id: headerRow
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: Style.space(48)

        Row {
          anchors.left: parent.left
          anchors.verticalCenter: parent.verticalCenter
          spacing: Style.space(12)

          Image {
            source: (pluginRoot && pluginRoot.isConnected) ? Qt.resolvedUrl("assets/surfshark-active.svg") : Qt.resolvedUrl("assets/surfshark-inactive.svg")
            sourceSize.width: Style.space(32)
            sourceSize.height: Style.space(32)
            anchors.verticalCenter: parent.verticalCenter
          }

          Column {
            spacing: Style.space(2)
            anchors.verticalCenter: parent.verticalCenter

            Text {
              text: "Surfshark VPN Manager"
              font.family: Style.font.family
              font.pixelSize: Style.font.title
              font.bold: true
              color: Color.foreground
            }

            Text {
              text: (pluginRoot && pluginRoot.isConnected) ? ("🟢 " + rootWindow.t("connected") + " • " + (pluginRoot.activeProfile ? pluginRoot.activeProfile.display_name : "WireGuard")) : ("⚪ " + rootWindow.t("disconnected") + " • Omarchy Linux")
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
              color: (pluginRoot && pluginRoot.isConnected) ? "#16D2B6" : Color.muted
            }
          }
        }

        Row {
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          spacing: Style.space(8)

          // Language Switcher
          Rectangle {
            color: "#1a202c"
            radius: 6
            border.color: "#2d3748"
            border.width: 1
            width: langRowLayout.implicitWidth + Style.space(6)
            height: Style.space(34)
            anchors.verticalCenter: parent.verticalCenter

            Row {
              id: langRowLayout
              anchors.centerIn: parent
              spacing: Style.space(4)

              Button {
                text: "FR"
                selected: rootWindow.currentLang === "fr"
                width: Style.space(36)
                onClicked: if (rootWindow.pluginRoot) rootWindow.pluginRoot.setLanguage("fr")
              }
              Button {
                text: "EN"
                selected: rootWindow.currentLang === "en"
                width: Style.space(36)
                onClicked: if (rootWindow.pluginRoot) rootWindow.pluginRoot.setLanguage("en")
              }
              Button {
                text: "JA"
                selected: rootWindow.currentLang === "ja"
                width: Style.space(36)
                onClicked: if (rootWindow.pluginRoot) rootWindow.pluginRoot.setLanguage("ja")
              }
            }
          }

          // Close Button
          Button {
            text: "✕"
            width: Style.space(36)
            height: Style.space(34)
            anchors.verticalCenter: parent.verticalCenter
            onClicked: rootWindow.requestClose()
          }
        }
      }

      Rectangle {
        id: headerSep
        anchors.top: headerRow.bottom
        anchors.topMargin: Style.space(8)
        anchors.left: parent.left
        anchors.right: parent.right
        height: 1
        color: "#2d3748"
      }

      // --- Main Dual Column Content ---
      Item {
        anchors.top: headerSep.bottom
        anchors.topMargin: Style.space(12)
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom

        // LEFT COLUMN: Controls & Profiles (48%)
        ScrollView {
          id: leftScroll
          anchors.top: parent.top
          anchors.bottom: parent.bottom
          anchors.left: parent.left
          width: (parent.width - Style.space(16)) * 0.48
          clip: true
          ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

          Column {
            width: leftScroll.availableWidth
            spacing: Style.space(12)

            // Connection Status Card
            Rectangle {
              width: parent.width
              color: "#151b23"
              radius: 8
              border.color: (rootWindow.pluginRoot && rootWindow.pluginRoot.isConnected) ? "#16D2B6" : "#2d3748"
              border.width: 1
              implicitHeight: connCol.implicitHeight + Style.space(24)

              Column {
                id: connCol
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Style.space(12)
                spacing: Style.space(10)

                PanelSectionHeader { text: rootWindow.currentLang === "fr" ? "État du Tunnel VPN" : (rootWindow.currentLang === "ja" ? "VPNトンネル状態" : "VPN Tunnel State") }

                Row {
                  width: parent.width
                  spacing: Style.space(8)

                  Rectangle {
                    width: (parent.width - Style.space(8)) / 2
                    height: Style.space(52)
                    color: "#101315"
                    radius: 6
                    border.color: "#2d3748"
                    border.width: 1

                    Column {
                      anchors.centerIn: parent
                      spacing: 2
                      Text { text: "IP Publique"; font.pixelSize: Style.font.caption - 2; color: Color.muted; anchors.horizontalCenter: parent.horizontalCenter }
                      Text { text: rootWindow.pluginRoot ? rootWindow.pluginRoot.publicIp : "—"; font.pixelSize: Style.font.caption; font.bold: true; color: (rootWindow.pluginRoot && rootWindow.pluginRoot.isConnected) ? "#16D2B6" : Color.foreground; anchors.horizontalCenter: parent.horizontalCenter }
                    }
                  }

                  Rectangle {
                    width: (parent.width - Style.space(8)) / 2
                    height: Style.space(52)
                    color: "#101315"
                    radius: 6
                    border.color: "#2d3748"
                    border.width: 1

                    Column {
                      anchors.centerIn: parent
                      spacing: 2
                      Text { text: "Protocole"; font.pixelSize: Style.font.caption - 2; color: Color.muted; anchors.horizontalCenter: parent.horizontalCenter }
                      Text { text: "WireGuard (Kernel)"; font.pixelSize: Style.font.caption; font.bold: true; color: "#00ff66"; anchors.horizontalCenter: parent.horizontalCenter }
                    }
                  }
                }

                Button {
                  width: parent.width
                  height: Style.space(40)
                  text: (rootWindow.pluginRoot && rootWindow.pluginRoot.isConnected) ? ("🔴 " + rootWindow.t("btn_disconnect")) : ("⚡ " + rootWindow.t("btn_connect"))
                  selected: rootWindow.pluginRoot && rootWindow.pluginRoot.isConnected
                  onClicked: {
                    if (rootWindow.pluginRoot) {
                      if (rootWindow.pluginRoot.isConnected) {
                        rootWindow.pluginRoot.disconnectVPN()
                        rootWindow.addLog("Déconnexion demandée...", "info")
                      } else {
                        if (rootWindow.pluginRoot.profileList.length > 0) {
                          rootWindow.pluginRoot.connectTo(rootWindow.pluginRoot.profileList[0].id)
                          rootWindow.addLog("Connexion vers " + rootWindow.pluginRoot.profileList[0].country + "...", "info")
                        }
                      }
                    }
                  }
                }
              }
            }

            // Installed Profiles Card
            Rectangle {
              width: parent.width
              color: "#151b23"
              radius: 8
              border.color: "#2d3748"
              border.width: 1
              implicitHeight: profCol.implicitHeight + Style.space(24)

              Column {
                id: profCol
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Style.space(12)
                spacing: Style.space(10)

                Row {
                  width: parent.width
                  PanelSectionHeader { text: rootWindow.t("locations") + " (" + (rootWindow.pluginRoot ? rootWindow.pluginRoot.profileList.length : 0) + ")" }
                  Item { width: Math.max(4, parent.width - parent.children[0].implicitWidth - openBtn.implicitWidth); height: 1 }
                  Button {
                    id: openBtn
                    text: rootWindow.t("open_folder")
                    height: Style.space(24)
                    onClicked: if (rootWindow.pluginRoot) rootWindow.pluginRoot.openFolder()
                  }
                }

                Repeater {
                  model: rootWindow.pluginRoot ? rootWindow.pluginRoot.profileList : []

                  Rectangle {
                    id: ccCard
                    width: parent.width
                    height: Style.space(42)
                    radius: 6
                    readonly property bool isActive: rootWindow.pluginRoot && rootWindow.pluginRoot.activeProfile && rootWindow.pluginRoot.activeProfile.id === modelData.id
                    color: isActive ? "#0e342f" : (ccMouse.containsMouse ? "#1a232e" : "#12171f")
                    border.color: isActive ? "#16D2B6" : (ccMouse.containsMouse ? "#323f50" : "#1f2733")
                    border.width: 1

                    // Star Button Area on Left
                    Item {
                      id: ccStarArea
                      width: Style.space(34)
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
                        onClicked: if (rootWindow.pluginRoot) rootWindow.pluginRoot.toggleFavorite(modelData.id)
                      }
                    }

                    // Clickable Server Card (Middle + Right)
                    MouseArea {
                      id: ccMouse
                      anchors.left: ccStarArea.right
                      anchors.right: parent.right
                      anchors.top: parent.top
                      anchors.bottom: parent.bottom
                      hoverEnabled: true
                      cursorShape: Qt.PointingHandCursor
                      onClicked: {
                        if (rootWindow.pluginRoot) {
                          if (ccCard.isActive) {
                            rootWindow.pluginRoot.disconnectVPN()
                            rootWindow.addLog("Déconnexion de " + modelData.country, "info")
                          } else {
                            rootWindow.pluginRoot.connectTo(modelData.id)
                            rootWindow.addLog("Connexion à " + modelData.country + " (" + modelData.city + ")...", "ok")
                          }
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
                            color: ccCard.isActive ? "#16D2B6" : Color.foreground
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
                          width: Math.max(2, parent.width - parent.children[0].implicitWidth - parent.children[1].implicitWidth - ccBadge.implicitWidth - Style.space(16))
                          height: 1
                        }

                        // Status Badge or Connect Hint
                        Rectangle {
                          id: ccBadge
                          anchors.verticalCenter: parent.verticalCenter
                          height: Style.space(22)
                          radius: 4
                          color: ccCard.isActive ? "#0d3a33" : (ccMouse.containsMouse ? "#1e3a4a" : "transparent")
                          border.color: ccCard.isActive ? "#16D2B6" : (ccMouse.containsMouse ? "#16D2B6" : "#2d3748")
                          border.width: 1
                          width: ccBadgeText.implicitWidth + Style.space(12)

                          Text {
                            id: ccBadgeText
                            anchors.centerIn: parent
                            text: ccCard.isActive ? "● CONNECTÉ" : "Connecter"
                            font.family: Style.font.family
                            font.pixelSize: Style.font.caption - 2
                            font.bold: true
                            color: ccCard.isActive ? "#16D2B6" : (ccMouse.containsMouse ? "#ffffff" : Color.muted)
                          }
                        }
                      }
                    }
                  }
                }

                // Empty state box
                Rectangle {
                  visible: !rootWindow.pluginRoot || rootWindow.pluginRoot.profileList.length === 0
                  width: parent.width
                  color: "#161d26"
                  radius: 8
                  border.color: "#2d3748"
                  border.width: 1
                  implicitHeight: emptyGuide.implicitHeight + Style.space(20)

                  Column {
                    id: emptyGuide
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: Style.space(10)
                    spacing: Style.space(8)

                    Text { text: "Guide de configuration WireGuard :"; font.bold: true; color: "#16D2B6"; font.pixelSize: Style.font.caption }
                    Text {
                      text: "1. Connectez-vous sur surfshark.com (VPN > Manuel > WireGuard)\n2. Générez une clé WireGuard en 1 clic\n3. Téléchargez vos pays préférés (ex: fr-par.conf, jp-tok.conf)\n4. Glissez-déposez-les dans le dossier configs !"
                      color: Color.muted
                      font.pixelSize: Style.font.caption - 1
                      lineHeight: 1.4
                    }
                    Button {
                      width: parent.width
                      text: "Ouvrir le dossier ~/.config/surfshark-vpn/configs/"
                      onClicked: if (rootWindow.pluginRoot) rootWindow.pluginRoot.openFolder()
                    }
                  }
                }
              }
            }
          }
        }

        // RIGHT COLUMN: Quick Guide & Real-Time Event Logs (52%)
        Column {
          anchors.top: parent.top
          anchors.bottom: parent.bottom
          anchors.left: leftScroll.right
          anchors.leftMargin: Style.space(16)
          anchors.right: parent.right
          spacing: Style.space(12)

          // Performance & Security Notice Card
          Rectangle {
            width: parent.width
            color: "#151b23"
            radius: 8
            border.color: "#2d3748"
            border.width: 1
            implicitHeight: noticeCol.implicitHeight + Style.space(24)

            Column {
              id: noticeCol
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.top: parent.top
              anchors.margins: Style.space(12)
              spacing: Style.space(8)

              PanelSectionHeader { text: rootWindow.currentLang === "fr" ? "Avantages WireGuard sous Omarchy" : (rootWindow.currentLang === "ja" ? "WireGuardのメリット" : "WireGuard Advantages") }

              Text {
                text: rootWindow.currentLang === "fr" ? "⚡ Intégré au noyau Linux : Débit maximal, 0% CPU en veille.\n🔒 Cryptographie de pointe (ChaCha20, Poly1305, Curve25519).\n🌐 Roaming instantané : Aucune coupure en cas de changement de réseau.\n🚀 Zéro dépendance : Pas d'application Electron lourde en arrière-plan." : (rootWindow.currentLang === "ja" ? "⚡ Linuxカーネル直接統合：超高速・低遅延、待機時CPU使用率0%。\n🔒 最新の暗号化プロトコル (ChaCha20, Poly1305, Curve25519)。\n🌐 高速ローミング：ネットワーク切り替え時も切断なし。\n🚀 完全軽量：重いElectronアプリ不要。" : "⚡ Kernel-integrated: Maximum fiber speed, 0% idle CPU.\n🔒 Modern cryptography (ChaCha20, Poly1305, Curve25519).\n🌐 Seamless roaming: Instant reconnect when switching networks.\n🚀 Zero bloat: No heavy Electron background apps.")
                font.family: Style.font.family
                font.pixelSize: Style.font.caption - 1
                color: Color.muted
                lineHeight: 1.45
              }
            }
          }

          // Live Event & Diagnostic Log Monitor
          Rectangle {
            width: parent.width
            height: parent.height - noticeCol.implicitHeight - Style.space(24) - Style.space(12)
            color: "#151b23"
            radius: 8
            border.color: "#2d3748"
            border.width: 1
            clip: true

            Column {
              anchors.fill: parent
              anchors.margins: Style.space(12)
              spacing: Style.space(8)

              Item {
                width: parent.width
                height: Style.space(24)

                PanelSectionHeader {
                  anchors.left: parent.left
                  anchors.verticalCenter: parent.verticalCenter
                  text: rootWindow.currentLang === "fr" ? "Journal des Événements & Trames WireGuard" : (rootWindow.currentLang === "ja" ? "イベント＆WireGuardログ" : "WireGuard Event & Packet Logs")
                }

                Button {
                  anchors.right: parent.right
                  anchors.verticalCenter: parent.verticalCenter
                  text: rootWindow.currentLang === "fr" ? "Effacer" : (rootWindow.currentLang === "ja" ? "消去" : "Clear")
                  width: Style.space(60)
                  height: Style.space(24)
                  onClicked: rootWindow.logEntries = []
                }
              }

              ListView {
                width: parent.width
                height: parent.height - Style.space(34)
                clip: true
                model: rootWindow.logEntries

                delegate: Text {
                  width: parent.width
                  text: modelData.text
                  font.family: "monospace"
                  font.pixelSize: 10
                  color: modelData.type === "ok" ? "#16D2B6" : (modelData.type === "err" ? "#ff4444" : Color.muted)
                  wrapMode: Text.Wrap
                }
              }
            }
          }
        }
      }
    }
  }
}
