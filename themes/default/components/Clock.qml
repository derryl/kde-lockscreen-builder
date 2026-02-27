import QtQuick

/*
 * Clock.qml - Minimal date/time display.
 *
 * Reads ClockFormat and DateFormat from theme.conf via the config object.
 */

Item {
    id: root

    property color textColor: "white"
    property int fontSize: 48
    property string timeFormat: "hh:mm"
    property string dateFormat: "dddd, MMMM d"

    implicitWidth: column.implicitWidth
    implicitHeight: column.implicitHeight

    Column {
        id: column
        anchors.centerIn: parent
        spacing: 4

        Text {
            id: timeLabel
            anchors.horizontalCenter: parent.horizontalCenter
            color: root.textColor
            font.pointSize: root.fontSize
            font.weight: Font.Light
            renderType: Text.NativeRendering
        }

        Text {
            id: dateLabel
            anchors.horizontalCenter: parent.horizontalCenter
            color: root.textColor
            opacity: 0.8
            font.pointSize: Math.round(root.fontSize * 0.3)
            font.weight: Font.Normal
            renderType: Text.NativeRendering
        }
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            var now = new Date()
            timeLabel.text = Qt.formatTime(now, root.timeFormat)
            dateLabel.text = Qt.formatDate(now, root.dateFormat)
        }
    }
}
