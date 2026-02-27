import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import QtQuick.Controls

/*
 * Preview.qml - Development harness for the SDDM theme.
 *
 * Provides mock objects in place of the SDDM context properties, then loads
 * the theme layout through a Loader.  A file-watcher timer detects changes
 * (via a signal file touched by entr) and reloads the Loader in-place,
 * keeping the window open for a true live-preview experience.
 *
 * Usage:  ./scripts/preview.sh [-theme <name>]
 */

Window {
    id: previewWindow
    width: 1920
    height: 1080
    visible: true
    title: "KDE Lockscreen Builder — Preview"

    // ═══════════════════════════════════════════════════════════════
    //  Mock objects
    // ═══════════════════════════════════════════════════════════════

    property QtObject mockConfig: QtObject {
        property string background: Qt.resolvedUrl("assets/background.jpg")
        property string type: "image"
        property string color: "#1a1a2e"
        property string primaryColor: "#ffffff"
        property string accentColor: "#4a9eff"
        property string backgroundOverlayColor: "#000000"
        property real backgroundOverlayOpacity: 0.3
        property string fontFamily: ""
        property int fontPointSize: 12
        property string clockVisible: "true"
        property string clockFormat: "hh:mm"
        property string dateFormat: "dddd, MMMM d"
        property int screenWidth: previewWindow.width
        property int screenHeight: previewWindow.height
    }

    property QtObject mockSddm: QtObject {
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
                console.log("[mock] Login failed (use 'test' as password)")
                loginFailed()
            }
        }
        function powerOff()    { console.log("[mock] sddm.powerOff()") }
        function reboot()      { console.log("[mock] sddm.reboot()") }
        function suspend()     { console.log("[mock] sddm.suspend()") }
        function hibernate()   { console.log("[mock] sddm.hibernate()") }
        function hybridSleep() { console.log("[mock] sddm.hybridSleep()") }
    }

    property ListModel mockUserModel: ListModel {
        property string lastUser: "user"
        property int lastIndex: 0
        property int disableAvatarsThreshold: 7
        property bool containsAllUsers: true

        ListElement { name: "user"; realName: "User"; icon: ""; needsPassword: true }
        ListElement { name: "guest"; realName: "Guest User"; icon: ""; needsPassword: true }
    }

    property ListModel mockSessionModel: ListModel {
        property int lastIndex: 0

        ListElement { name: "Plasma (Wayland)"; comment: "" }
        ListElement { name: "Plasma (X11)"; comment: "" }
        ListElement { name: "GNOME"; comment: "" }
    }

    property QtObject mockKeyboard: QtObject {
        property bool capsLock: false
        property bool numLock: true
    }

    // ═══════════════════════════════════════════════════════════════
    //  Derived properties (mirrors Main.qml logic)
    // ═══════════════════════════════════════════════════════════════

    property string notificationMessage: ""
    property int baseFontSize: mockConfig.fontPointSize || 12
    property string fontFamily: mockConfig.fontFamily || ""
    property color primaryColor: mockConfig.primaryColor || "#ffffff"
    property color accentColor: mockConfig.accentColor || "#4a9eff"

    // ═══════════════════════════════════════════════════════════════
    //  Hot-reload Loader
    // ═══════════════════════════════════════════════════════════════

    // Hot-reload: `hotReloader` is a context property injected by
    // preview-host.py.  Reload is a 3-phase process orchestrated by Python:
    //   1. unloadRequested  → QML destroys all component instances
    //   2. Python clears the now-unreferenced component cache
    //   3. reloadRequested  → QML reloads components from disk
    //
    // When hotReloader is not present (e.g. launched via plain qml6),
    // the theme loads once without hot-reload.

    Loader {
        id: themeLoader
        anchors.fill: parent

        onStatusChanged: {
            if (status === Loader.Error)
                console.log("[hot-reload] Error loading ThemeLayout.qml — check for syntax errors")
        }
    }

    function loadTheme() {
        themeLoader.setSource("ThemeLayout.qml", { "preview": previewWindow })
    }

    function unloadTheme() {
        themeLoader.source = ""
    }

    Connections {
        target: typeof hotReloader !== "undefined" ? hotReloader : null
        function onUnloadRequested() { previewWindow.unloadTheme() }
        function onReloadRequested() { previewWindow.loadTheme() }
    }

    Component.onCompleted: loadTheme()

    // ── Preview overlay ──────────────────────────────────────────
    Rectangle {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: 10
        width: infoRow.width + 20
        height: infoRow.height + 10
        color: "#80000000"
        radius: 6
        z: 1000

        Row {
            id: infoRow
            anchors.centerIn: parent
            spacing: 8

            Text {
                text: previewWindow.width + " x " + previewWindow.height
                color: "white"
                font.pointSize: 9
            }
            Text { text: "|"; color: "#80ffffff"; font.pointSize: 9 }
            Text {
                text: "Live Preview"
                color: "#00ff88"
                font.pointSize: 9
                font.bold: true
            }
        }
    }
}
