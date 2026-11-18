import QtQuick
import QtQuick.Layouts

// Details of the annotation currently selected, incl. its review status;
// shows the completion message instead once the image is done.
Item {
    id: root
    property string annotationId: ""
    property string label: ""
    property real confidence: 0
    property int objectX: 0
    property int objectY: 0
    property int objectWidth: 0
    property int objectHeight: 0
    property int objectCount: 0
    property string statusText: "Pending"
    property string statusKey: "pending"
    property bool complete: false
    property string completeText: ""

    implicitHeight: 360

    function statusColor(key) {
        if (key === "accepted" || key === "corrected") return "#3dcc57"
        if (key === "flagged") return "#e23b3b"
        if (key === "deleted") return "#777777"
        return "#ff9a1a"
    }

    component StatRow: RowLayout {
        property string name: ""
        property string value: ""
        Layout.fillWidth: true
        spacing: 12
        PixelText {
            text: name
            color: "#8a8a8a"
            pixel: 6
        }
        Item { Layout.fillWidth: true }
        PixelText {
            text: value
            color: "#f4f4f4"
            pixel: 6
        }
    }

    Rectangle { x: 4; y: 4; width: parent.width - 4; height: parent.height - 4; color: "#000000" }
    Rectangle {
        id: panel
        width: parent.width - 4
        height: parent.height - 4
        color: "#161616"
        border.width: 4
        border.color: "#f4f4f4"

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 18
            anchors.bottomMargin: 90
            spacing: 14
            visible: !root.complete

            PixelText {
                Layout.alignment: Qt.AlignLeft
                text: "OBJECT " + root.annotationId
                color: "#8a8a8a"
                pixel: 6
            }
            PixelText {
                Layout.alignment: Qt.AlignLeft
                Layout.fillWidth: true
                text: root.label.toUpperCase()
                color: "#f4f4f4"
                pixel: 9
            }
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 2
                color: "#f4f4f4"
            }
            StatRow {
                name: "CONFIDENCE"
                value: Math.round(root.confidence * 100) + "%"
            }
            StatRow {
                name: "POSITION"
                value: root.objectX + ", " + root.objectY
            }
            StatRow {
                name: "SIZE"
                value: root.objectWidth + " x " + root.objectHeight
            }
            StatRow {
                name: "COUNT"
                value: root.objectCount
            }
            Item { Layout.fillHeight: true }
            PixelText {
                Layout.alignment: Qt.AlignLeft
                text: "STATUS"
                color: "#8a8a8a"
                pixel: 6
            }
            PixelText {
                Layout.alignment: Qt.AlignLeft
                text: root.statusText.toUpperCase()
                color: root.statusColor(root.statusKey)
                pixel: 8
            }
        }

        PixelText {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: -28
            visible: root.complete
            text: root.completeText.toUpperCase()
            color: "#f4f4f4"
            pixel: 7
        }
    }
}
