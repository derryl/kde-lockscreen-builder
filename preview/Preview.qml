import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import QtQuick.Controls

import "../components"

/*
 * Preview.qml - Development harness for the SDDM theme.
 *
 * Mirrors the Main.qml layout but provides mock objects in place of
 * the SDDM context properties (sddm, userModel, sessionModel, config,
 * screenModel, keyboard).
 *
 * Components receive their dependencies as explicit properties, so they
 * work identically whether driven by SDDM or by this preview.
 *
 * Usage:  qml6 preview/Preview.qml
 *    or:  qmlscene6 preview/Preview.qml
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

    QtObject {
        id: mockConfig
        // Set to "" to use the solid fallback color, or provide a path
        // to an image (e.g. drop your own into assets/background.jpg).
        property string background: "assets/background.jpg"
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

    QtObject {
        id: mockSddm
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

    ListModel {
        id: mockUserModel
        property string lastUser: "user"
        property int lastIndex: 0
        property int disableAvatarsThreshold: 7
        property bool containsAllUsers: true

        ListElement { name: "user"; realName: "User"; icon: ""; needsPassword: true }
        ListElement { name: "guest"; realName: "Guest User"; icon: ""; needsPassword: true }
    }

    ListModel {
        id: mockSessionModel
        property int lastIndex: 0

        ListElement { name: "Plasma (Wayland)"; comment: "" }
        ListElement { name: "Plasma (X11)"; comment: "" }
        ListElement { name: "GNOME"; comment: "" }
    }

    QtObject {
        id: mockKeyboard
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
    //  Theme layout (identical to Main.qml)
    // ═══════════════════════════════════════════════════════════════

    // ── Background ───────────────────────────────────────────────
    Image {
        id: backgroundImage
        anchors.fill: parent
        source: mockConfig.background || ""
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        onStatusChanged: {
            if (status === Image.Error && source != "")
                console.log("Background image not found — using fallback color. " +
                    "Drop an image into assets/background.jpg or update theme.conf.")
        }
    }

    Rectangle {
        id: backgroundFallback
        anchors.fill: parent
        color: mockConfig.color || "#1a1a2e"
        visible: backgroundImage.status !== Image.Ready
    }

    Rectangle {
        anchors.fill: parent
        color: mockConfig.backgroundOverlayColor || "#000000"
        opacity: mockConfig.backgroundOverlayOpacity || 0.3
    }

    // ── Clock ────────────────────────────────────────────────────
    Clock {
        id: clock
        visible: mockConfig.clockVisible === "true"
        anchors {
            top: parent.top
            horizontalCenter: parent.horizontalCenter
            topMargin: previewWindow.height * 0.08
        }
        textColor: primaryColor
        fontSize: baseFontSize * 4
        timeFormat: mockConfig.clockFormat || "hh:mm"
        dateFormat: mockConfig.dateFormat || "dddd, MMMM d"
    }

    // ── Login form ───────────────────────────────────────────────
    LoginForm {
        id: loginForm
        anchors.centerIn: parent
        width: 320

        textColor: primaryColor
        accentColor: previewWindow.accentColor
        fontSize: baseFontSize
        fontFamily: previewWindow.fontFamily
        defaultUsername: mockUserModel.lastUser || ""
        notificationMessage: previewWindow.notificationMessage
        capsLockOn: mockKeyboard.capsLock

        sessionIndex: sessionSelector.currentIndex

        onLoginRequest: function(username, password) {
            previewWindow.notificationMessage = ""
            mockSddm.login(username, password, sessionSelector.currentIndex)
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
            fontFamily: previewWindow.fontFamily
            sessions: mockSessionModel
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

            canSuspend: mockSddm.canSuspend
            canReboot: mockSddm.canReboot
            canPowerOff: mockSddm.canPowerOff

            onSuspendClicked: mockSddm.suspend()
            onRebootClicked: mockSddm.reboot()
            onPowerOffClicked: mockSddm.powerOff()
        }
    }

    // ── SDDM connections ─────────────────────────────────────────
    Connections {
        target: mockSddm
        function onLoginFailed() {
            previewWindow.notificationMessage = "Login Failed"
            loginForm.clearPassword()
        }
        function onLoginSucceeded() {
            previewWindow.notificationMessage = ""
        }
    }

    Timer {
        interval: 3000
        running: notificationMessage !== ""
        onTriggered: notificationMessage = ""
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
                text: "Preview Mode"
                color: "#ffcc00"
                font.pointSize: 9
                font.bold: true
            }
        }
    }
}
