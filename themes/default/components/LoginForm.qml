import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

/*
 * LoginForm.qml - Username/password entry and login trigger.
 *
 * Expects these context properties from the parent:
 *   - sddm          (proxy object with login() function)
 *   - userModel      (list model with name, realName, icon, needsPassword)
 *   - sessionModel   (list model with session names)
 *   - config         (theme configuration)
 */

Item {
    id: root

    property color textColor: "white"
    property color accentColor: "#4a9eff"
    property int fontSize: 12
    property string fontFamily: ""

    property string notificationMessage: ""
    property bool capsLockOn: false

    // Which session index to pass to sddm.login()
    property int sessionIndex: 0

    // The username to pre-fill (from userModel)
    property string defaultUsername: ""

    signal loginRequest(string username, string password)

    implicitWidth: formColumn.implicitWidth
    implicitHeight: formColumn.implicitHeight

    Column {
        id: formColumn
        anchors.centerIn: parent
        width: 320
        spacing: 16

        // ── User greeting ────────────────────────────
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Welcome"
            color: root.textColor
            font.pointSize: root.fontSize + 8
            font.weight: Font.Light
            font.family: root.fontFamily
            renderType: Text.NativeRendering
        }

        // ── Username field ───────────────────────────
        TextField {
            id: usernameField
            width: parent.width
            height: 44
            placeholderText: "Username"
            text: root.defaultUsername
            font.pointSize: root.fontSize
            font.family: root.fontFamily

            color: root.textColor
            placeholderTextColor: Qt.rgba(1, 1, 1, 0.5)

            background: Rectangle {
                color: Qt.rgba(1, 1, 1, 0.12)
                radius: 8
                border.color: usernameField.activeFocus ? root.accentColor : Qt.rgba(1, 1, 1, 0.2)
                border.width: usernameField.activeFocus ? 2 : 1
            }

            leftPadding: 14
            rightPadding: 14

            Keys.onReturnPressed: passwordField.forceActiveFocus()
            Keys.onEnterPressed: passwordField.forceActiveFocus()
        }

        // ── Password field ───────────────────────────
        TextField {
            id: passwordField
            width: parent.width
            height: 44
            placeholderText: "Password"
            echoMode: TextInput.Password
            font.pointSize: root.fontSize
            font.family: root.fontFamily

            color: root.textColor
            placeholderTextColor: Qt.rgba(1, 1, 1, 0.5)

            background: Rectangle {
                color: Qt.rgba(1, 1, 1, 0.12)
                radius: 8
                border.color: passwordField.activeFocus ? root.accentColor : Qt.rgba(1, 1, 1, 0.2)
                border.width: passwordField.activeFocus ? 2 : 1
            }

            leftPadding: 14
            rightPadding: 14

            Keys.onReturnPressed: doLogin()
            Keys.onEnterPressed: doLogin()
        }

        // ── Caps Lock warning ────────────────────────
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Caps Lock is on"
            color: "#ffcc00"
            font.pointSize: root.fontSize - 2
            visible: root.capsLockOn
            renderType: Text.NativeRendering
        }

        // ── Login button ─────────────────────────────
        Button {
            id: loginButton
            width: parent.width
            height: 44
            text: "Log In"
            font.pointSize: root.fontSize
            font.family: root.fontFamily

            contentItem: Text {
                text: loginButton.text
                font: loginButton.font
                color: "white"
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                renderType: Text.NativeRendering
            }

            background: Rectangle {
                color: loginButton.down ? Qt.darker(root.accentColor, 1.2) :
                       loginButton.hovered ? Qt.lighter(root.accentColor, 1.1) :
                       root.accentColor
                radius: 8

                Behavior on color {
                    ColorAnimation { duration: 120 }
                }
            }

            onClicked: doLogin()
        }

        // ── Notification / error message ─────────────
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.notificationMessage
            color: "#ff6b6b"
            font.pointSize: root.fontSize - 1
            visible: text !== ""
            renderType: Text.NativeRendering

            Behavior on opacity {
                NumberAnimation { duration: 200 }
            }
        }
    }

    function doLogin() {
        root.loginRequest(usernameField.text, passwordField.text)
    }

    // Reset password field on failed login (called externally)
    function clearPassword() {
        passwordField.text = ""
        passwordField.forceActiveFocus()
    }

    // Focus management
    Component.onCompleted: {
        if (usernameField.text === "")
            usernameField.forceActiveFocus()
        else
            passwordField.forceActiveFocus()
    }
}
