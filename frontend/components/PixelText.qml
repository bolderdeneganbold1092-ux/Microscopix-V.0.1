import QtQuick

// Bitmap-style label: small text drawn once, then scaled without smoothing.
Item {
    id: root
    property string text: ""
    property color color: "#f4f4f4"
    property int pixel: 7
    property int zoom: 2
    property int weight: Font.Bold

    implicitWidth: Math.max(1, Math.ceil(glyph.implicitWidth)) * zoom
    implicitHeight: Math.max(1, Math.ceil(glyph.implicitHeight)) * zoom

    Item {
        width: Math.max(1, glyph.implicitWidth)
        height: Math.max(1, glyph.implicitHeight)
        scale: root.zoom
        transformOrigin: Item.TopLeft
        layer.enabled: true
        layer.smooth: false
        layer.mipmap: false
        Text {
            id: glyph
            text: root.text
            color: root.color
            font.family: "Courier"
            font.bold: true
            font.weight: root.weight
            font.pixelSize: root.pixel
            font.hintingPreference: Font.PreferFullHinting
            renderType: Text.NativeRendering
            horizontalAlignment: Text.AlignHCenter
        }
    }
}
