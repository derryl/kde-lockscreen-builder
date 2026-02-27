import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Qt5Compat.GraphicalEffects

/*
 * LoginForm.qml - Password entry and login trigger.
 *
 * Username is not shown; it uses defaultUsername (from userModel.lastUser).
 * The login button is a small icon button inline to the right of the field.
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

    // The username to submit (from userModel)
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

        // ── Password row (field + icon login button) ─
        Row {
            id: passwordRow
            width: parent.width
            spacing: 8

            TextField {
                id: passwordField
                width: parent.width - loginButton.width - passwordRow.spacing
                height: 44
                placeholderText: "Password"
                echoMode: TextInput.Password
                font.pointSize: root.fontSize
                font.family: root.fontFamily

                color: root.textColor
                placeholderTextColor: Qt.rgba(1, 1, 1, 0.35)

                background: Item {
                    // Outer dark ring — acts as the inset shadow edge
                    Rectangle {
                        anchors.fill: parent
                        radius: 8
                        color: "transparent"
                        border.color: Qt.rgba(0, 0, 0, 0.5)
                        border.width: 1
                    }
                    // Inner fill — dark slate with subtle light rim
                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 1
                        radius: 7
                        color: "#1e293b"
                        border.color: Qt.rgba(255, 255, 255, 0.06)
                        border.width: 1
                    }
                }

                leftPadding: 14
                rightPadding: 14

                layer.enabled: true
                layer.effect: DropShadow {
                    horizontalOffset: 0
                    verticalOffset: 1
                    radius: 6.0
                    samples: 13
                    color: "#30000000"
                    transparentBorder: true
                }

                Keys.onReturnPressed: doLogin()
                Keys.onEnterPressed: doLogin()
            }

            // Small icon button to the right of password field
            Button {
                id: loginButton
                width: 44
                height: 44

                contentItem: Text {
                    text: "\u25B6"  // ▶
                    font.pointSize: root.fontSize + 2
                    font.family: root.fontFamily
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
        root.loginRequest(root.defaultUsername, passwordField.text)
    }

    // Reset password field on failed login (called externally)
    function clearPassword() {
        passwordField.text = ""
        passwordField.forceActiveFocus()
    }

    // Focus management
    Component.onCompleted: {
        passwordField.forceActiveFocus()
    }
}
