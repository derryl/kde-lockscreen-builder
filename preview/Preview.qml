import QtQuick
import QtQuick.Window

/*
 * Preview.qml - Development harness for the SDDM theme.
 *
 * A thin window shell that loads the theme's Main.qml via a Loader.
 * Mock SDDM context properties (sddm, config, userModel, sessionModel,
 * keyboard) are injected by preview-host.py as engine context properties,
 * so Main.qml works identically here and under the real SDDM greeter.
 *
 * Usage:  ./scripts/preview.sh [-theme <name>]
 */

Window {
    id: previewWindow
    width: 1920
    height: 1080
    visible: true
    title: "KDE Lockscreen Builder — Preview"

    // Keep config.screenWidth/Height in sync with this window's dimensions
    onWidthChanged:  config.screenWidth  = width
    onHeightChanged: config.screenHeight = height

    // ═══════════════════════════════════════════════════════════════
    //  Hot-reload Loader
    // ═══════════════════════════════════════════════════════════════

    Loader {
        id: themeLoader
        anchors.fill: parent

        onStatusChanged: {
            if (status === Loader.Error)
                console.log("[hot-reload] Error loading Main.qml — check for syntax errors")
        }
    }

    function loadTheme() {
        themeLoader.setSource("Main.qml")
    }

    function unloadTheme() {
        themeLoader.source = ""
    }

    Connections {
        target: typeof hotReloader !== "undefined" ? hotReloader : null
        function onUnloadRequested() { previewWindow.unloadTheme() }
        function onReloadRequested() { previewWindow.loadTheme() }
    }

    Component.onCompleted: {
        config.screenWidth  = width
        config.screenHeight = height
        loadTheme()
    }

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
