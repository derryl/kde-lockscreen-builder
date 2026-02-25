import QtQuick
import QtQuick.Layouts

/*
 * PowerBar.qml - Row of power action buttons (suspend, reboot, shutdown).
 *
 * Each button is gated by the corresponding sddm.can* property.
 * Uses Unicode symbols for icons to avoid dependency on icon themes.
 */

Item {
    id: root

    property color textColor: "white"
    property int fontSize: 10
    property int iconSize: 22

    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 24

        PowerButton {
            icon: "\u23FB"    // Power symbol (⏻)
            label: "Suspend"
            visible: sddm.canSuspend
            onClicked: sddm.suspend()
        }

        PowerButton {
            icon: "\u21BB"    // Clockwise arrow (↻)
            label: "Reboot"
            visible: sddm.canReboot
            onClicked: sddm.reboot()
        }

        PowerButton {
            icon: "\u2B58"    // Heavy circle (⭘)
            label: "Shut Down"
            visible: sddm.canPowerOff
            onClicked: sddm.powerOff()
        }
    }

    component PowerButton: Item {
        id: btn

        property string icon: ""
        property string label: ""
        signal clicked()

        width: btnColumn.implicitWidth + 16
        height: btnColumn.implicitHeight + 8

        Column {
            id: btnColumn
            anchors.centerIn: parent
            spacing: 4

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: btn.icon
                color: mouseArea.containsMouse ? root.textColor : Qt.rgba(1, 1, 1, 0.7)
                font.pointSize: root.iconSize
                renderType: Text.NativeRendering

                Behavior on color {
                    ColorAnimation { duration: 120 }
                }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: btn.label
                color: mouseArea.containsMouse ? root.textColor : Qt.rgba(1, 1, 1, 0.5)
                font.pointSize: root.fontSize - 2
                renderType: Text.NativeRendering

                Behavior on color {
                    ColorAnimation { duration: 120 }
                }
            }
        }

        MouseArea {
            id: mouseArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: btn.clicked()
        }
    }
}
