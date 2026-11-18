import QtQuick

// Progress fill that grows in whole pixel steps.
Item {
    id: root
    property real from: 0
    property real to: 1
    property real value: 0
    implicitHeight: 22

    readonly property real span: Math.max(1, to - from)
    readonly property int cells: Math.max(1, Math.floor((width - 8) / 10))
    readonly property int filled: Math.round(cells * Math.max(0, Math.min(1, (value - from) / span)))

    Rectangle {
        anchors.fill: parent
        color: "#141414"
        border.width: 4
        border.color: "#000000"
    }
    Row {
        x: 4
        y: 4
        spacing: 2
        Repeater {
            model: root.cells
            Rectangle {
                width: 8
                height: 14
                color: index < root.filled ? "#f4f4f4" : "#2a2a2a"
            }
        }
    }
}
