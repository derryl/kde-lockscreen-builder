import QtQuick
import QtQuick.Window
import QtQuick.Controls

/*
 * Preview.qml - Development harness for the SDDM theme.
 *
 * Mocks all SDDM-provided globals (sddm, userModel, sessionModel,
 * screenModel, config) so Main.qml can be loaded with qml6 outside
 * of the real SDDM greeter.
 *
 * Usage:  qml6 preview/Preview.qml
 */

Window {
    id: previewWindow
    width: 1920
    height: 1080
    visible: true
    title: "SDDM Theme Preview"

    // ─── Mock: config ────────────────────────────────────────────
    // Reads theme.conf and exposes values the same way SDDM does.
    // SDDM's config object exposes every key from [General] as a
    // property accessible via config.<Key> in QML.
    QtObject {
        id: config

        // Background
        property string background: Qt.resolvedUrl("../assets/background.jpg")
        property string type: "image"
        property string color: "#1d99f3"

        // Colors
        property string PrimaryColor: "#ffffff"
        property string AccentColor: "#4a9eff"
        property string BackgroundOverlayColor: "#000000"
        property real BackgroundOverlayOpacity: 0.3

        // Typography
        property string FontFamily: ""
        property int FontPointSize: 12

        // Layout
        property string ClockVisible: "true"
        property string ClockFormat: "hh:mm"
        property string DateFormat: "dddd, MMMM d"

        // Screen (fallback)
        property int ScreenWidth: previewWindow.width
        property int ScreenHeight: previewWindow.height
    }

    // ─── Mock: sddm proxy ────────────────────────────────────────
    QtObject {
        id: sddm

        property string hostname: "preview-host"
        property bool canPowerOff: true
        property bool canReboot: true
        property bool canSuspend: true
        property bool canHibernate: true
        property bool canHybridSleep: false

        signal loginFailed()
        signal loginSucceeded()

        function login(user, password, sessionIndex) {
            console.log("[mock] sddm.login:", user, "session:", sessionIndex)
            if (password === "test") {
                console.log("[mock] Login succeeded")
                loginSucceeded()
            } else {
                console.log("[mock] Login failed (use password 'test' to simulate success)")
                loginFailed()
            }
        }
        function powerOff()     { console.log("[mock] sddm.powerOff()") }
        function reboot()       { console.log("[mock] sddm.reboot()") }
        function suspend()      { console.log("[mock] sddm.suspend()") }
        function hibernate()    { console.log("[mock] sddm.hibernate()") }
        function hybridSleep()  { console.log("[mock] sddm.hybridSleep()") }
    }

    // ─── Mock: userModel ─────────────────────────────────────────
    ListModel {
        id: userModel
        property string lastUser: "gitpusher"
        property int lastIndex: 0
        property int disableAvatarsThreshold: 7
        property bool containsAllUsers: true

        ListElement {
            name: "gitpusher"
            realName: "gitpusher"
            icon: ""
            needsPassword: true
        }
        ListElement {
            name: "guest"
            realName: "Guest User"
            icon: ""
            needsPassword: true
        }
    }

    // ─── Mock: sessionModel ──────────────────────────────────────
    ListModel {
        id: sessionModel
        property int lastIndex: 0

        ListElement { name: "Plasma (Wayland)"; comment: "KDE Plasma on Wayland" }
        ListElement { name: "Plasma (X11)"; comment: "KDE Plasma on X11" }
        ListElement { name: "GNOME"; comment: "GNOME Desktop" }
    }

    // ─── Mock: screenModel ───────────────────────────────────────
    ListModel {
        id: screenModel
        ListElement {
            name: "primary"
        }
        // geometry is accessed as geometry.x, geometry.y, etc.
        // We handle this in Main.qml's Repeater by using the window dimensions.
    }

    // ─── Mock: keyboard ──────────────────────────────────────────
    QtObject {
        id: keyboard
        property bool capsLock: false
        property bool numLock: true
        property int currentLayout: 0
        property var layouts: ListModel {
            ListElement { shortName: "us"; longName: "English (US)" }
        }
    }

    // ─── Load the actual theme ───────────────────────────────────
    Loader {
        id: themeLoader
        anchors.fill: parent
        source: Qt.resolvedUrl("../Main.qml")

        onStatusChanged: {
            if (status === Loader.Error) {
                console.error("Failed to load Main.qml:", themeLoader.sourceComponent?.errorString ?? "unknown error")
            }
        }
    }

    // ─── Preview controls overlay ────────────────────────────────
    Rectangle {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: 10
        width: controlsRow.width + 20
        height: controlsRow.height + 10
        color: "#80000000"
        radius: 6
        z: 1000
        visible: controlsMouseArea.containsMouse || controlsRow.hovered

        Row {
            id: controlsRow
            anchors.centerIn: parent
            spacing: 8
            property bool hovered: false

            Text {
                text: previewWindow.width + "x" + previewWindow.height
                color: "white"
                font.pointSize: 9
            }
            Text {
                text: "|"
                color: "#80ffffff"
                font.pointSize: 9
            }
            Text {
                text: "Preview Mode"
                color: "#ffcc00"
                font.pointSize: 9
                font.bold: true
            }
        }
    }

    MouseArea {
        id: controlsMouseArea
        anchors.top: parent.top
        anchors.right: parent.right
        width: 250
        height: 50
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
        z: 999
    }
}
