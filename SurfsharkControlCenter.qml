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
  implicitWidth: Style.space(1020)
  implicitHeight: Style.space(720)
  minimumSize: Qt.size(Style.space(860), Style.space(600))

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

  property bool showPrivKey: false

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

        // LEFT COLUMN: Controls & Profiles (46%)
        ScrollView {
          id: leftScroll
          anchors.top: parent.top
          anchors.bottom: parent.bottom
          anchors.left: parent.left
          width: (parent.width - Style.space(16)) * 0.46
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
                      Text { text: "IPv4 Publique"; font.pixelSize: Style.font.caption - 2; color: Color.muted; anchors.horizontalCenter: parent.horizontalCenter }
                      Text { text: rootWindow.pluginRoot ? rootWindow.pluginRoot.ipv4 : "—"; font.pixelSize: Style.font.caption; font.bold: true; color: (rootWindow.pluginRoot && rootWindow.pluginRoot.isConnected) ? "#16D2B6" : Color.foreground; anchors.horizontalCenter: parent.horizontalCenter }
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
                        if (rootWindow.pluginRoot.favoriteList.length > 0) {
                          rootWindow.pluginRoot.connectTo(rootWindow.pluginRoot.favoriteList[0].id)
                          rootWindow.addLog("Connexion vers " + rootWindow.pluginRoot.favoriteList[0].country + "...", "info")
                        } else if (rootWindow.pluginRoot.profileList.length > 0) {
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
                  PanelSectionHeader { text: (rootWindow.currentLang === "fr" ? "Emplacements Serveurs" : (rootWindow.currentLang === "ja" ? "サーバーロケーション" : "Server Locations")) + " (" + (rootWindow.pluginRoot ? rootWindow.pluginRoot.profileList.length : 0) + ")" }
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
                    height: Style.space(46)
                    radius: 8
                    readonly property bool isActive: rootWindow.pluginRoot && rootWindow.pluginRoot.activeProfile && rootWindow.pluginRoot.activeProfile.id === modelData.id
                    color: isActive ? "#0e342f" : (ccMouse.containsMouse ? "#1a232e" : "#12171f")
                    border.color: isActive ? "#16D2B6" : (ccMouse.containsMouse ? "#323f50" : "#1f2733")
                    border.width: 1

                    // Star Button Area on Left
                    Item {
                      id: ccStarArea
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
                        cursorShape: Qt.PointingHandCursor
                        onClicked: if (rootWindow.pluginRoot) rootWindow.pluginRoot.toggleFavorite(modelData.id)
                      }
                    }

                    // Flag Item
                    Item {
                      id: ccFlagArea
                      width: Style.space(26)
                      height: parent.height
                      anchors.left: ccStarArea.right

                      Text {
                        anchors.centerIn: parent
                        text: modelData.flag || "🌐"
                        font.pixelSize: 18
                      }
                    }

                    // Status Badge on Right
                    Rectangle {
                      id: ccBadge
                      anchors.right: parent.right
                      anchors.rightMargin: Style.space(10)
                      anchors.verticalCenter: parent.verticalCenter
                      height: Style.space(26)
                      radius: 6
                      color: ccCard.isActive ? "#0d3a33" : (ccMouse.containsMouse ? "#1e3a4a" : "transparent")
                      border.color: ccCard.isActive ? "#16D2B6" : (ccMouse.containsMouse ? "#16D2B6" : "#2d3748")
                      border.width: 1
                      width: ccBadgeText.implicitWidth + Style.space(16)

                      Text {
                        id: ccBadgeText
                        anchors.centerIn: parent
                        text: ccCard.isActive ? "● CONNECTÉ" : (rootWindow.currentLang === "fr" ? "Connexion" : (rootWindow.currentLang === "ja" ? "接続" : "Connect"))
                        font.family: Style.font.family
                        font.pixelSize: 12
                        font.bold: true
                        color: ccCard.isActive ? "#16D2B6" : (ccMouse.containsMouse ? "#ffffff" : Color.muted)
                      }
                    }

                    // Country + City in Center
                    Column {
                      anchors.left: ccFlagArea.right
                      anchors.leftMargin: Style.space(8)
                      anchors.right: ccBadge.left
                      anchors.rightMargin: Style.space(10)
                      anchors.verticalCenter: parent.verticalCenter
                      spacing: Style.space(2)

                      Text {
                        text: modelData.country
                        font.family: Style.font.family
                        font.pixelSize: 14
                        font.bold: true
                        color: ccCard.isActive ? "#16D2B6" : Color.foreground
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
                      id: ccMouse
                      anchors.left: ccFlagArea.left
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
                            rootWindow.addLog("Connexion vers " + modelData.country + " (" + modelData.city + ")...", "ok")
                          }
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        }

        // RIGHT COLUMN: WireGuard Key Configuration, 3-Lang Setup Guide & Event Logs (54%)
        ScrollView {
          id: rightScroll
          anchors.top: parent.top
          anchors.bottom: parent.bottom
          anchors.left: leftScroll.right
          anchors.leftMargin: Style.space(16)
          anchors.right: parent.right
          clip: true
          ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

          Column {
            width: rightScroll.availableWidth
            spacing: Style.space(12)

            // --- 1. WireGuard Key Pair Manager Card (CORRIGÉ) ---
            Rectangle {
              width: parent.width
              color: "#151b23"
              radius: 8
              border.color: "#2d3748"
              border.width: 1
              implicitHeight: keyCol.implicitHeight + Style.space(24)

              Column {
                id: keyCol
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Style.space(12)
                spacing: Style.space(10)

                Row {
                  width: parent.width
                  PanelSectionHeader {
                    text: rootWindow.currentLang === "fr" ? "🔑 Clés WireGuard Surfshark" : (rootWindow.currentLang === "ja" ? "🔑 Surfshark WireGuard 鍵設定" : "🔑 Surfshark WireGuard Key Pair")
                  }
                  Item { width: Math.max(4, parent.width - parent.children[0].implicitWidth - keyStatusBadge.implicitWidth); height: 1 }
                  Rectangle {
                    id: keyStatusBadge
                    height: Style.space(22)
                    radius: 4
                    // CORRIGÉ : utilise has_private_key au lieu du contenu du champ
                    color: (rootWindow.pluginRoot && rootWindow.pluginRoot.keys && rootWindow.pluginRoot.keys.has_private_key) ? "#0d3a33" : "#2a1b1b"
                    border.color: (rootWindow.pluginRoot && rootWindow.pluginRoot.keys && rootWindow.pluginRoot.keys.has_private_key) ? "#16D2B6" : "#e53e3e"
                    border.width: 1
                    width: keyStatusText.implicitWidth + Style.space(12)

                    Text {
                      id: keyStatusText
                      anchors.centerIn: parent
                      text: (rootWindow.pluginRoot && rootWindow.pluginRoot.keys && rootWindow.pluginRoot.keys.has_private_key)
                            ? (rootWindow.currentLang === "fr" ? "✓ Clé Active" : (rootWindow.currentLang === "ja" ? "✓ 鍵設定済み" : "✓ Key Active"))
                            : (rootWindow.currentLang === "fr" ? "⚠ Clé Manquante" : (rootWindow.currentLang === "ja" ? "⚠ 鍵なし" : "⚠ Key Missing"))
                      font.pixelSize: 11
                      font.bold: true
                      color: (rootWindow.pluginRoot && rootWindow.pluginRoot.keys && rootWindow.pluginRoot.keys.has_private_key) ? "#16D2B6" : "#fc8181"
                    }
                  }
                }

                // Public Key Field
                Column {
                  width: parent.width
                  spacing: Style.space(4)

                  Text {
                    text: rootWindow.currentLang === "fr" ? "Clé Publique (Public Key) :" : (rootWindow.currentLang === "ja" ? "公開鍵 (Public Key) :" : "Public Key :")
                    font.pixelSize: 12
                    font.bold: true
                    color: Color.muted
                  }

                  Rectangle {
                    width: parent.width
                    height: Style.space(36)
                    color: "#0d1117"
                    radius: 6
                    border.color: pubKeyField.activeFocus ? "#16D2B6" : "#2d3748"
                    border.width: 1

                    TextInput {
                      id: pubKeyField
                      anchors.fill: parent
                      anchors.margins: Style.space(8)
                      font.family: "monospace"
                      font.pixelSize: 12
                      color: Color.foreground
                      clip: true
                      selectByMouse: true
                      // Seulement la clé publique est restaurée depuis le status
                      text: rootWindow.pluginRoot && rootWindow.pluginRoot.keys ? (rootWindow.pluginRoot.keys.public_key || "") : ""
                    }
                  }
                }

                // Private Key Field – CORRIGÉ : jamais pré-rempli depuis le status
                Column {
                  width: parent.width
                  spacing: Style.space(4)

                  Text {
                    text: rootWindow.currentLang === "fr" ? "Clé Privée (Private Key) :" : (rootWindow.currentLang === "ja" ? "秘密鍵 (Private Key) :" : "Private Key :")
                    font.pixelSize: 12
                    font.bold: true
                    color: Color.muted
                  }

                  Rectangle {
                    width: parent.width
                    height: Style.space(36)
                    color: "#0d1117"
                    radius: 6
                    border.color: privKeyField.activeFocus ? "#16D2B6" : "#2d3748"
                    border.width: 1

                    Row {
                      anchors.fill: parent
                      anchors.margins: Style.space(6)
                      spacing: Style.space(6)

                      TextInput {
                        id: privKeyField
                        width: parent.width - eyeBtn.width - Style.space(8)
                        height: parent.height
                        font.family: "monospace"
                        font.pixelSize: 12
                        color: Color.foreground
                        clip: true
                        selectByMouse: true
                        echoMode: rootWindow.showPrivKey ? TextInput.Normal : TextInput.Password
                        text: ""

                        Text {
                          anchors.fill: parent
                          verticalAlignment: Text.AlignVCenter
                          font.family: "monospace"
                          font.pixelSize: 12
                          color: "#606d7e"
                          visible: privKeyField.text.length === 0
                          text: (rootWindow.pluginRoot && rootWindow.pluginRoot.keys && rootWindow.pluginRoot.keys.has_private_key)
                                ? "••••••••  (already set – paste new key to replace)"
                                : "Paste private key here"
                        }
                      }

                      Button {
                        id: eyeBtn
                        text: rootWindow.showPrivKey ? "🙈" : "👁️"
                        width: Style.space(32)
                        height: parent.height
                        onClicked: rootWindow.showPrivKey = !rootWindow.showPrivKey
                      }
                    }
                  }
                }

                // Save & Apply Button
                Button {
                  width: parent.width
                  height: Style.space(38)
                  text: rootWindow.currentLang === "fr" ? "💾 Enregistrer les Clés & Appliquer aux Profils (.conf)" : (rootWindow.currentLang === "ja" ? "💾 鍵を保存してすべての設定ファイルに適用" : "💾 Save Keys & Apply to all Configs (.conf)")
                  selected: true
                  onClicked: {
                    if (rootWindow.pluginRoot) {
                      if (privKeyField.text.length < 20) {
                        rootWindow.addLog(
                          rootWindow.currentLang === "fr" ? "Clé privée manquante ou trop courte." :
                          (rootWindow.currentLang === "ja" ? "秘密鍵が不足しているか短すぎます。" : "Private key missing or too short."),
                          "err"
                        )
                        return
                      }
                      rootWindow.pluginRoot.saveKeys(pubKeyField.text, privKeyField.text)
                      // CORRIGÉ : efface immédiatement la clé privée de l'UI après envoi
                      privKeyField.text = ""
                      rootWindow.addLog(
                        rootWindow.currentLang === "fr" ? "Clés enregistrées et injectées dans tous les profils .conf avec succès !" :
                        (rootWindow.currentLang === "ja" ? "鍵が保存され、すべての.confファイルに適用されました！" : "Keys saved and applied to all .conf profiles successfully!"),
                        "ok"
                      )
                    }
                  }
                }
              }
            }

            // --- 2. Step-by-Step 3-Language Visual Guide ---
            Rectangle {
              width: parent.width
              color: "#151b23"
              radius: 8
              border.color: "#2d3748"
              border.width: 1
              implicitHeight: guideCol.implicitHeight + Style.space(24)

              Column {
                id: guideCol
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Style.space(12)
                spacing: Style.space(10)

                PanelSectionHeader {
                  text: rootWindow.currentLang === "fr" ? "📘 Guide de Configuration en 4 Étapes" : (rootWindow.currentLang === "ja" ? "📘 4ステップ簡単設定ガイド" : "📘 4-Step Easy Setup Guide")
                }

                Column {
                  width: parent.width
                  spacing: Style.space(6)

                  // Step 1
                  Row {
                    width: parent.width
                    spacing: Style.space(8)
                    Text { text: "1️⃣"; font.pixelSize: 14 }
                    Text {
                      width: parent.width - Style.space(32)
                      text: rootWindow.currentLang === "fr" ? "Connectez-vous sur votre compte Surfshark (VPN > Configuration manuelle > WireGuard)." : (rootWindow.currentLang === "ja" ? "Surfshark Webサイト (VPN > 手動設定 > WireGuard) にアクセスします。" : "Log in to your Surfshark account (VPN > Manual setup > WireGuard).")
                      font.family: Style.font.family
                      font.pixelSize: Style.font.caption - 1
                      color: Color.foreground
                      wrapMode: Text.WordWrap
                    }
                  }

                  // Step 2
                  Row {
                    width: parent.width
                    spacing: Style.space(8)
                    Text { text: "2️⃣"; font.pixelSize: 14 }
                    Text {
                      width: parent.width - Style.space(32)
                      text: rootWindow.currentLang === "fr" ? "Cliquez sur « J'ai déjà une paire de clés » ou générez une nouvelle paire de clés WireGuard." : (rootWindow.currentLang === "ja" ? "「鍵ペアを持っています」を選択するか、新しいWireGuard鍵ペアを生成します。" : "Click “I already have a key pair” or generate a new WireGuard key pair.")
                      font.family: Style.font.family
                      font.pixelSize: Style.font.caption - 1
                      color: Color.foreground
                      wrapMode: Text.WordWrap
                    }
                  }

                  // Step 3
                  Row {
                    width: parent.width
                    spacing: Style.space(8)
                    Text { text: "3️⃣"; font.pixelSize: 14 }
                    Text {
                      width: parent.width - Style.space(32)
                      text: rootWindow.currentLang === "fr" ? "Collez votre Clé Publique et Clé Privée dans les champs ci-dessus et cliquez sur Enregistrer." : (rootWindow.currentLang === "ja" ? "上記の入力欄に公開鍵と秘密鍵を貼り付け、「保存して適用」をクリックします。" : "Paste your Public Key & Private Key in the fields above and click Save.")
                      font.family: Style.font.family
                      font.pixelSize: Style.font.caption - 1
                      color: Color.foreground
                      wrapMode: Text.WordWrap
                    }
                  }

                  // Step 4
                  Row {
                    width: parent.width
                    spacing: Style.space(8)
                    Text { text: "4️⃣"; font.pixelSize: 14 }
                    Text {
                      width: parent.width - Style.space(32)
                      text: rootWindow.currentLang === "fr" ? "Téléchargez les fichiers .conf de vos pays favoris et glissez-les dans le dossier configs !" : (rootWindow.currentLang === "ja" ? "接続したい国の設定ファイル (.conf) をダウンロードし、configsフォルダに配置します。" : "Download the .conf files for your favorite locations and drop them into the configs folder!")
                      font.family: Style.font.family
                      font.pixelSize: Style.font.caption - 1
                      color: Color.foreground
                      wrapMode: Text.WordWrap
                    }
                  }
                }

                Row {
                  width: parent.width
                  spacing: Style.space(8)

                  Button {
                    width: (parent.width - Style.space(8)) / 2
                    height: Style.space(34)
                    text: rootWindow.currentLang === "fr" ? "🌐 Ouvrir Surfshark.com ↗" : (rootWindow.currentLang === "ja" ? "🌐 Surfsharkを開く ↗" : "🌐 Open Surfshark.com ↗")
                    onClicked: {
                      Quickshell.execDetached(["xdg-open", "https://my.surfshark.com/vpn/manual-setup/main/wireguard"])
                      rootWindow.addLog("Ouverture du portail WireGuard Surfshark...", "info")
                    }
                  }

                  Button {
                    width: (parent.width - Style.space(8)) / 2
                    height: Style.space(34)
                    text: rootWindow.currentLang === "fr" ? "📁 Ouvrir Dossier Configs" : (rootWindow.currentLang === "ja" ? "📁 configsフォルダを開く" : "📁 Open Configs Folder")
                    onClicked: if (rootWindow.pluginRoot) rootWindow.pluginRoot.openFolder()
                  }
                }
              }
            }

            // --- 3. Live Event & Diagnostic Log Monitor ---
            Rectangle {
              width: parent.width
              height: Style.space(160)
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
                    text: rootWindow.currentLang === "fr" ? "Journal des Événements WireGuard" : (rootWindow.currentLang === "ja" ? "WireGuard イベントログ" : "WireGuard Event Log")
                  }

                  Button {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: rootWindow.currentLang === "fr" ? "Effacer" : (rootWindow.currentLang === "ja" ? "消去" : "Clear")
                    width: Style.space(60)
                    height: Style.space(22)
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
}
