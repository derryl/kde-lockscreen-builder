import QtQuick
import QtQuick.Controls

/*
 * SessionSelector.qml - Desktop session dropdown.
 *
 * Binds to sessionModel and exposes the selected index.
 */

Item {
    id: root

    property color textColor: "white"
    property int fontSize: 10
    property string fontFamily: ""
    property alias currentIndex: sessionCombo.currentIndex

    implicitWidth: sessionCombo.implicitWidth
    implicitHeight: sessionCombo.implicitHeight

    ComboBox {
        id: sessionCombo
        anchors.fill: parent

        model: sessionModel
        currentIndex: sessionModel.lastIndex
        textRole: "name"

        font.pointSize: root.fontSize
        font.family: root.fontFamily || undefined

        contentItem: Text {
            leftPadding: 10
            rightPadding: sessionCombo.indicator.width + 10
            text: sessionCombo.displayText
            font: sessionCombo.font
            color: root.textColor
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
            renderType: Text.NativeRendering
        }

        background: Rectangle {
            implicitWidth: 180
            implicitHeight: 32
            color: Qt.rgba(1, 1, 1, 0.1)
            radius: 6
            border.color: Qt.rgba(1, 1, 1, 0.2)
            border.width: 1
        }

        indicator: Text {
            x: sessionCombo.width - width - 10
            anchors.verticalCenter: parent.verticalCenter
            text: "\u25BE"  // small down triangle
            color: root.textColor
            font.pointSize: root.fontSize
        }

        popup: Popup {
            y: sessionCombo.height + 2
            width: sessionCombo.width
            implicitHeight: contentItem.implicitHeight + 4
            padding: 2

            contentItem: ListView {
                clip: true
                implicitHeight: contentHeight
                model: sessionCombo.popup.visible ? sessionCombo.delegateModel : null
                currentIndex: sessionCombo.highlightedIndex
            }

            background: Rectangle {
                color: "#2a2a2a"
                radius: 6
                border.color: Qt.rgba(1, 1, 1, 0.2)
            }
        }

        delegate: ItemDelegate {
            width: sessionCombo.width
            height: 32

            contentItem: Text {
                text: model.name
                color: highlighted ? "#ffffff" : "#cccccc"
                font.pointSize: root.fontSize
                verticalAlignment: Text.AlignVCenter
                leftPadding: 10
                renderType: Text.NativeRendering
            }

            background: Rectangle {
                color: highlighted ? Qt.rgba(1, 1, 1, 0.15) : "transparent"
                radius: 4
            }

            highlighted: sessionCombo.highlightedIndex === index
        }
    }
}
