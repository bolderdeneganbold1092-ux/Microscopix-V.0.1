import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Title screen. Log in and Sign in are only buttons for now.
Rectangle {
    id: root
    color: "#000000"
    signal start()
    property bool muted: false
    signal muteToggled()

    Repeater {
        model: 48
        delegate: Rectangle {
            width: 2
            height: 2
            color: index % 4 === 0 ? "#6a6a6a" : "#2a2a2a"
            x: (index * 137 + 40) % Math.max(1, root.width - 4)
            y: (index * 89 + 20) % Math.max(1, root.height - 4)
        }
    }

    IconButton {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.margins: 22
        width: 44
        height: 44
        zoom: 1
        mark: root.muted ? "mute" : "sound"
        tip: root.muted ? "SOUND" : "MUTE"
        onClicked: root.muteToggled()
    }

    Row {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: 22
        spacing: 10
        OutlineButton { text: "LOG IN" }
        OutlineButton { text: "SIGN IN" }
    }

    Column {
        anchors.centerIn: parent
        spacing: 18
        width: Math.min(parent.width - 40, 640)

        PixelText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "WELCOME TO"
            color: "#8a8a8a"
            pixel: 6
        }
        PixelText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "MICROSCOPIX"
            color: "#f4f4f4"
            pixel: 16
        }

        Item {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 168
            height: 168
            Rectangle { x: 18; y: 142; width: 132; height: 8; color: "#8a8a8a" }
            Rectangle { x: 8; y: 150; width: 152; height: 14; color: "#f4f4f4" }
            Rectangle { x: 46; y: 124; width: 78; height: 12; color: "#f4f4f4" }
            Rectangle { x: 72; y: 62; width: 24; height: 64; color: "#f4f4f4" }
            Rectangle { x: 38; y: 36; width: 18; height: 88; color: "#5a5a5a" }
            Rectangle { x: 38; y: 36; width: 58; height: 16; color: "#5a5a5a" }
            Rectangle { x: 80; y: 10; width: 30; height: 34; color: "#d8d8d8" }
            Rectangle { x: 88; y: 0; width: 14; height: 16; color: "#f4f4f4" }
            Rectangle { x: 124; y: 52; width: 8; height: 8; color: "#f4f4f4" }
            Rectangle { x: 22; y: 96; width: 8; height: 8; color: "#8a8a8a" }
        }

        PixelText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "ENTER THE LAB"
            color: "#f4f4f4"
            pixel: 7
        }
        PixelText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "REVIEW. ANALYZE. DISCOVER."
            color: "#8a8a8a"
            pixel: 5
        }
        OutlineButton {
            anchors.horizontalCenter: parent.horizontalCenter
            wide: true
            text: "START PLAY"
            onClicked: root.start()
        }
    }

    component OutlineButton: Button {
        id: btn
        property bool wide: false
        hoverEnabled: true
        implicitWidth: wide ? 220 : 118
        implicitHeight: wide ? 52 : 32
        leftPadding: 10
        rightPadding: 10
        background: Item {
            Rectangle { x: 3; y: 3; width: parent.width - 3; height: parent.height - 3; color: "#000000" }
            Rectangle {
                x: btn.down ? 3 : 0
                y: btn.down ? 3 : 0
                width: parent.width - 3
                height: parent.height - 3
                color: btn.hovered ? "#161616" : "#000000"
                border.width: 2
                border.color: "#f4f4f4"
            }
        }
        contentItem: Item {
            PixelText {
                anchors.centerIn: parent
                anchors.horizontalCenterOffset: btn.down ? 3 : 0
                anchors.verticalCenterOffset: btn.down ? 3 : 0
                text: btn.text
                color: "#f4f4f4"
                pixel: btn.wide ? 7 : 5
            }
        }
    }
}
