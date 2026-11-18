import QtQuick

// Level sits in a ring that is empty at the start of a level and full when it is completed.
Item {
    id: root
    property int level: 1
    property int xp: 0
    property int xpIntoLevel: 0
    property int xpPerLevel: 20

    implicitWidth: levelWord.implicitWidth + 10 + 64
    implicitHeight: 64

    function showGain(amount) {
        popup.text = "+" + amount + " XP"
        popAnim.restart()
    }

    PixelText {
        id: levelWord
        anchors.verticalCenter: dial.verticalCenter
        anchors.right: dial.left
        anchors.rightMargin: 10
        text: "LEVEL"
        color: "#f4f4f4"
        pixel: 6
    }

    Canvas {
        id: dial
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: 64
        height: 64
        antialiasing: false
        property real progress: root.xpPerLevel > 0 ? root.xpIntoLevel / root.xpPerLevel : 0
        onProgressChanged: requestPaint()
        Component.onCompleted: requestPaint()
        onPaint: {
            var ctx = getContext("2d")
            ctx.reset()
            var cx = width / 2
            var cy = height / 2
            var radius = 22
            var steps = 28
            var lit = Math.round(steps * progress)
            ctx.fillStyle = "#f4f4f4"
            for (var i = 0; i < lit; i++) {
                var a = -Math.PI / 2 + (i / steps) * Math.PI * 2
                var x = Math.round(cx + Math.cos(a) * radius) - 3
                var y = Math.round(cy + Math.sin(a) * radius) - 3
                ctx.fillRect(x, y, 6, 6)
            }
        }
    }
    PixelText {
        anchors.centerIn: dial
        text: root.level
        color: "#f4f4f4"
        pixel: 7
    }
    PixelText {
        id: popup
        anchors.horizontalCenter: dial.horizontalCenter
        opacity: 0
        text: ""
        color: "#f4f4f4"
        pixel: 8
        ParallelAnimation {
            id: popAnim
            NumberAnimation { target: popup; property: "opacity"; from: 1; to: 0; duration: 900 }
            NumberAnimation { target: popup; property: "y"; from: 8; to: -14; duration: 900 }
        }
    }
}
