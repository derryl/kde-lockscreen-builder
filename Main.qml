import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import "components"

/*
 * Main.qml - Root component for the gitpusher SDDM login theme.
 *
 * SDDM injects these as context properties (available globally):
 *   sddm          - proxy with login(), powerOff(), reboot(), suspend(), etc.
 *   userModel      - list model of system users
 *   sessionModel   - list model of desktop sessions
 *   screenModel    - list model of connected screens
 *   config         - values from theme.conf [General] section
 *   keyboard       - caps lock / num lock state
 */

Item {
    id: root

    width: config.screenWidth
    height: config.screenHeight

    property string notificationMessage: ""
    property int baseFontSize: config.fontPointSize ? parseInt(config.fontPointSize) : 12
    property string fontFamily: config.fontFamily || ""
    property color primaryColor: config.primaryColor || "#ffffff"
    property color accentColor: config.accentColor || "#4a9eff"

    // ── Background ───────────────────────────────────────────────

    Image {
        id: backgroundImage
        anchors.fill: parent
        source: config.background || ""
        fillMode: Image.PreserveAspectCrop
        asynchronous: true

        onStatusChanged: {
            if (status === Image.Error) {
                backgroundFallback.visible = true
            }
        }
    }

    Rectangle {
        id: backgroundFallback
        anchors.fill: parent
        color: config.color || "#1a1a2e"
        visible: backgroundImage.status !== Image.Ready
    }

    Rectangle {
        anchors.fill: parent
        color: config.backgroundOverlayColor || "#000000"
        opacity: parseFloat(config.backgroundOverlayOpacity) || 0.3
    }

    // ── Clock ────────────────────────────────────────────────────

    Clock {
        id: clock
        visible: config.clockVisible === "true"
        anchors {
            top: parent.top
            horizontalCenter: parent.horizontalCenter
            topMargin: root.height * 0.08
        }
        textColor: root.primaryColor
        fontSize: root.baseFontSize * 4
        timeFormat: config.clockFormat || "hh:mm"
        dateFormat: config.dateFormat || "dddd, MMMM d"
    }

    // ── Login Form ───────────────────────────────────────────────

    LoginForm {
        id: loginForm
        anchors.centerIn: parent
        width: 320

        textColor: root.primaryColor
        accentColor: root.accentColor
        fontSize: root.baseFontSize
        fontFamily: root.fontFamily
        defaultUsername: userModel.lastUser || ""
        notificationMessage: root.notificationMessage
        capsLockOn: keyboard.capsLock || false

        sessionIndex: sessionSelector.currentIndex

        onLoginRequest: function(username, password) {
            root.notificationMessage = ""
            sddm.login(username, password, sessionSelector.currentIndex)
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
            textColor: root.primaryColor
            fontSize: root.baseFontSize - 2
            fontFamily: root.fontFamily
            sessions: sessionModel
            Layout.preferredWidth: 180
            Layout.preferredHeight: 32
        }

        Item { Layout.fillWidth: true }

        PowerBar {
            id: powerBar
            textColor: root.primaryColor
            fontSize: root.baseFontSize - 2
            iconSize: root.baseFontSize + 6
            Layout.preferredHeight: 48

            canSuspend: sddm.canSuspend
            canReboot: sddm.canReboot
            canPowerOff: sddm.canPowerOff

            onSuspendClicked: sddm.suspend()
            onRebootClicked: sddm.reboot()
            onPowerOffClicked: sddm.powerOff()
        }
    }

    // ── SDDM Connections ─────────────────────────────────────────

    Connections {
        target: sddm

        function onLoginFailed() {
            root.notificationMessage = "Login Failed"
            loginForm.clearPassword()
        }

        function onLoginSucceeded() {
            root.notificationMessage = ""
            root.opacity = 0
        }
    }

    Behavior on opacity {
        NumberAnimation { duration: 300; easing.type: Easing.InOutQuad }
    }

    Timer {
        id: notificationTimer
        interval: 3000
        running: notificationMessage !== ""
        onTriggered: notificationMessage = ""
    }
}
