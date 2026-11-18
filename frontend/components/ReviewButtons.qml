import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Accept (→) for 1 XP / Flag (←) for 2 XP while reviewing;
// "Next image" (Enter) once the image is done.
ColumnLayout {
    id: root

    property bool reviewing: true
    property bool canReview: true
    property bool canAdvance: false
    property bool fixing: false
    property string nextText: "Next image  →"
    property int xpAccept: 1
    property int xpFlag: 2

    signal accepted()
    signal flagged()
    signal nextRequested()
    signal renamed()
    signal deleted()

    spacing: 12

    component PixelButton: Button {
        id: btn
        property color fill: "#f4f4f4"
        property color labelColor: "#000000"
        property int shift: btn.down ? 4 : 0
        Layout.fillWidth: true
        leftPadding: 8
        rightPadding: 8
        topPadding: 6
        bottomPadding: 10
        background: Item {
            implicitHeight: 72
            Rectangle {
                x: 4
                y: 4
                width: parent.width - 4
                height: parent.height - 4
                color: "#000000"
            }
            Rectangle {
                x: btn.shift
                y: btn.shift
                width: parent.width - 4
                height: parent.height - 4
                color: !btn.enabled ? "#2a2a2a" : btn.fill
                border.width: 4
                border.color: "#000000"
                Rectangle {
                    visible: btn.enabled && !btn.down
                    x: 4
                    y: 4
                    width: parent.width - 8
                    height: 4
                    color: "#ffffff"
                    opacity: 0.45
                }
            }
        }
        contentItem: Item {
            PixelText {
                anchors.centerIn: parent
                anchors.horizontalCenterOffset: btn.shift
                anchors.verticalCenterOffset: btn.shift
                text: btn.text
                color: btn.enabled ? btn.labelColor : "#666666"
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        visible: root.reviewing
        spacing: 12

        PixelButton {
            fill: "#3dcc57"
            labelColor: "#06210c"
            enabled: root.canReview
            text: "ACCEPT"
            onClicked: root.accepted()
        }
        PixelButton {
            fill: "#e23b3b"
            labelColor: "#2a0606"
            enabled: root.canReview
            text: "FLAG"
            onClicked: root.flagged()
        }
    }
    PixelButton {
        visible: root.canAdvance && !root.fixing
        text: root.nextText.toUpperCase()
        onClicked: root.nextRequested()
    }
    RowLayout {
        Layout.fillWidth: true
        visible: root.fixing
        spacing: 12
        PixelButton {
            text: "RENAME"
            onClicked: root.renamed()
        }
        PixelButton {
            fill: "#e23b3b"
            labelColor: "#2a0606"
            text: "DELETE"
            onClicked: root.deleted()
        }
    }

    Shortcut { sequence: "Right"; enabled: root.reviewing && root.canReview; onActivated: root.accepted() }
    Shortcut { sequence: "Left";  enabled: root.reviewing && root.canReview; onActivated: root.flagged() }
    Shortcut { sequences: ["Return", "Enter"]; enabled: root.canAdvance; onActivated: root.nextRequested() }
}
