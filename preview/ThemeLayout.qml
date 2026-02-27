import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import "components"

/*
 * ThemeLayout.qml - Theme content loaded via Loader for hot reload.
 *
 * Accesses mock objects and derived properties from the parent Window
 * through the `preview` property, which must be set by the Loader.
 */

Item {
    id: layout
    anchors.fill: parent

    required property var preview

    // Convenience aliases
    property color primaryColor: preview.primaryColor
    property color accentColor: preview.accentColor
    property int baseFontSize: preview.baseFontSize
    property string fontFamily: preview.fontFamily

    // ── Background ───────────────────────────────────────────────
    Image {
        id: backgroundImage
        anchors.fill: parent
        source: preview.mockConfig.background || ""
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: false
        onStatusChanged: {
            if (status === Image.Error && source != "")
                console.log("Background image not found — using fallback color. " +
                    "Drop an image into assets/background.jpg or update theme.conf.")
        }
    }

    Rectangle {
        id: backgroundFallback
        anchors.fill: parent
        color: preview.mockConfig.color || "#1a1a2e"
        visible: backgroundImage.status !== Image.Ready
    }

    Rectangle {
        anchors.fill: parent
        color: preview.mockConfig.backgroundOverlayColor || "#000000"
        opacity: preview.mockConfig.backgroundOverlayOpacity || 0.3
    }

    // ── Clock ────────────────────────────────────────────────────
    Clock {
        id: clock
        visible: preview.mockConfig.clockVisible === "true"
        anchors {
            top: parent.top
            horizontalCenter: parent.horizontalCenter
            topMargin: preview.height * 0.08
        }
        textColor: primaryColor
        fontSize: baseFontSize * 4
        timeFormat: preview.mockConfig.clockFormat || "hh:mm"
        dateFormat: preview.mockConfig.dateFormat || "dddd, MMMM d"
    }

    // ── Login form ───────────────────────────────────────────────
    LoginForm {
        id: loginForm
        anchors.centerIn: parent
        width: 320

        textColor: primaryColor
        accentColor: layout.accentColor
        fontSize: baseFontSize
        fontFamily: layout.fontFamily
        defaultUsername: preview.mockUserModel.lastUser || ""
        notificationMessage: preview.notificationMessage
        capsLockOn: preview.mockKeyboard.capsLock

        sessionIndex: sessionSelector.currentIndex

        onLoginRequest: function(username, password) {
            preview.notificationMessage = ""
            preview.mockSddm.login(username, password, sessionSelector.currentIndex)
        }
    }

    // ── Footer ───────────────────────────────────────────────────
    RowLayout {
        id: footer
        anchors {
            bottom: parent.bottom
            left: parent.left
            right: parent.right
            margins: 16
        }
        height: 48

        SessionSelector {
            id: sessionSelector
            textColor: primaryColor
            fontSize: baseFontSize - 2
            fontFamily: layout.fontFamily
            sessions: preview.mockSessionModel
            Layout.preferredWidth: 180
            Layout.preferredHeight: 32
        }

        Item { Layout.fillWidth: true }

        PowerBar {
            id: powerBar
            textColor: primaryColor
            fontSize: baseFontSize - 2
            iconSize: baseFontSize + 6
            Layout.preferredHeight: 48

            canSuspend: preview.mockSddm.canSuspend
            canReboot: preview.mockSddm.canReboot
            canPowerOff: preview.mockSddm.canPowerOff

            onSuspendClicked: preview.mockSddm.suspend()
            onRebootClicked: preview.mockSddm.reboot()
            onPowerOffClicked: preview.mockSddm.powerOff()
        }
    }

    // ── SDDM connections ─────────────────────────────────────────
    Connections {
        target: preview.mockSddm
        function onLoginFailed() {
            preview.notificationMessage = "Login Failed"
            loginForm.clearPassword()
        }
        function onLoginSucceeded() {
            preview.notificationMessage = ""
        }
    }

    Timer {
        interval: 3000
        running: preview.notificationMessage !== ""
        onTriggered: preview.notificationMessage = ""
    }
}
