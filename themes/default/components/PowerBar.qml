import QtQuick
import QtQuick.Layouts

/*
 * PowerBar.qml - Row of power action buttons.
 *
 * Emits signals for each action. The parent wires these to sddm.
 */

Item {
    id: root

    property color textColor: "white"
    property int fontSize: 12
    property int iconSize: 24

    property bool canSuspend: false
    property bool canReboot: false
    property bool canPowerOff: false

    signal suspendClicked()
    signal rebootClicked()
    signal powerOffClicked()

    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 48

        PowerButton {
            icon: "\u23FB"   // ⏻
            label: "Suspend"
            visible: root.canSuspend
            onClicked: root.suspendClicked()
        }

        PowerButton {
            icon: "\u21BB"   // ↻
            label: "Reboot"
            visible: root.canReboot
            onClicked: root.rebootClicked()
        }

        PowerButton {
            icon: "\u2B58"   // ⭘
            label: "Shut Down"
            visible: root.canPowerOff
            onClicked: root.powerOffClicked()
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

                Behavior on color { ColorAnimation { duration: 120 } }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: btn.label
                color: mouseArea.containsMouse ? root.textColor : Qt.rgba(1, 1, 1, 0.5)
                font.pointSize: root.fontSize - 2
                renderType: Text.NativeRendering

                Behavior on color { ColorAnimation { duration: 120 } }
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
