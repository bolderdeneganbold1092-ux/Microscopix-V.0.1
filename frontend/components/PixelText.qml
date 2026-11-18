import QtQuick

// Monospace label. Drawn at its real size so Windows can show the letters.
// A missing Courier face, scaled up from a few pixels, comes out as blocks.
Item {
    id: root
    property string text: ""
    property color color: "#f4f4f4"
    property int pixel: 7
    property int zoom: 2
    property int weight: Font.Bold

    readonly property int drawn: Math.max(12, pixel * zoom)
    readonly property string face: {
        var have = Qt.fontFamilies()
        var want = ["Courier New", "Consolas", "Lucida Console", "Menlo", "Monaco"]
        for (var i = 0; i < want.length; i++) {
            if (have.indexOf(want[i]) !== -1)
                return want[i]
        }
        return "Courier New"
    }

    implicitWidth: Math.max(1, glyph.implicitWidth)
    implicitHeight: Math.max(1, glyph.implicitHeight)

    Text {
        id: glyph
        text: root.text
        color: root.color
        font.family: root.face
        font.bold: true
        font.weight: root.weight
        font.pixelSize: root.drawn
        font.hintingPreference: Font.PreferVerticalHinting
        renderType: Text.QtRendering
        horizontalAlignment: Text.AlignHCenter
    }
}
