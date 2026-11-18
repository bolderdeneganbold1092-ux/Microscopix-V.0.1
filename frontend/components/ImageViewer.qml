import QtQuick

// One outline per annotation. Selected is blue, not yet reviewed is orange,
// accepted or flagged is green. Deleted annotations disappear.
// A drawn outline is a circle of points. Each point can be dragged.
// Wheel zooms toward the cursor. Drag on the picture pans.
Rectangle {
    id: root
    property url source
    property var annotations          // AnnotationModel
    property int currentIndex: -1
    property bool showBoxes: true
    property bool drawing: false
    property bool reshape: false
    property real zoom: 1
    signal annotationClicked(int index)
    signal outlineDrawn(real x, real y, real w, real h)

    color: "#000000"
    border.width: 4
    border.color: "#f4f4f4"
    clip: true

    onSourceChanged: zoom = 1

    function fit() {
        if (img.sourceSize.width <= 0 || gestures.width <= 0 || gestures.height <= 0)
            return
        var s = Math.min(gestures.width / img.sourceSize.width,
                         gestures.height / img.sourceSize.height)
        stage.baseW = img.sourceSize.width * s
        stage.baseH = img.sourceSize.height * s
        zoom = 1
        stage.x = (gestures.width - stage.baseW) / 2
        stage.y = (gestures.height - stage.baseH) / 2
    }

    function clampPan() {
        if (stage.width <= gestures.width)
            stage.x = (gestures.width - stage.width) / 2
        else
            stage.x = Math.min(0, Math.max(gestures.width - stage.width, stage.x))
        if (stage.height <= gestures.height)
            stage.y = (gestures.height - stage.height) / 2
        else
            stage.y = Math.min(0, Math.max(gestures.height - stage.height, stage.y))
    }

    Item {
        id: gestures
        anchors.fill: parent
        anchors.margins: 8
        clip: true

        MouseArea {
            id: pan
            anchors.fill: parent
            property real lastX: 0
            property real lastY: 0
            property bool sketching: false
            property real x1: 0
            property real y1: 0
            property real x2: 0
            property real y2: 0
            onPressed: function (mouse) {
                if (root.drawing) {
                    var p = mapToItem(stage, mouse.x, mouse.y)
                    sketching = true
                    x1 = p.x; y1 = p.y; x2 = p.x; y2 = p.y
                    return
                }
                lastX = mouse.x
                lastY = mouse.y
            }
            onPositionChanged: function (mouse) {
                if (!pressed)
                    return
                if (sketching) {
                    var p = mapToItem(stage, mouse.x, mouse.y)
                    x2 = p.x
                    y2 = p.y
                    sketch.requestPaint()
                    return
                }
                stage.x += mouse.x - lastX
                stage.y += mouse.y - lastY
                lastX = mouse.x
                lastY = mouse.y
                root.clampPan()
            }
            onReleased: function (mouse) {
                if (!sketching)
                    return
                sketching = false
                var s = overlay.s
                var nx = Math.min(x1, x2)
                var ny = Math.min(y1, y2)
                var nw = Math.abs(x2 - x1)
                var nh = Math.abs(y2 - y1)
                if (s <= 0 || nw < 8 || nh < 8)
                    return
                root.outlineDrawn(nx / s, ny / s, nw / s, nh / s)
            }

            Item {
                id: stage
                property real baseW: 0
                property real baseH: 0
                width: baseW * root.zoom
                height: baseH * root.zoom

                Image {
                    id: img
                    anchors.fill: parent
                    source: root.source
                    fillMode: Image.Stretch
                    smooth: root.zoom < 3
                    onStatusChanged: if (status === Image.Ready) root.fit()
                }

                Item {
                    id: overlay
                    anchors.fill: parent
                    property real s: img.sourceSize.width > 0 ? width / img.sourceSize.width : 1

                    Repeater {
                        model: root.showBoxes ? root.annotations : null
                        delegate: Item {
                            id: box
                            required property int index
                            required property string status
                            required property real boxX
                            required property real boxY
                            required property real boxW
                            required property real boxH
                            required property var outline

                            anchors.fill: parent
                            visible: status !== "deleted"

                            readonly property bool isCurrent: index === root.currentIndex
                            readonly property bool reviewed: status === "accepted" || status === "flagged"
                                                              || status === "corrected"
                            readonly property color lineColor: isCurrent ? "#3d7dff"
                                                             : reviewed ? "#3dcc57"
                                                             : "#ff9a1a"
                            property bool shaping: false
                            property var live: []
                            readonly property int pointCount: {
                                if (shaping)
                                    return live.length
                                return (outline && outline.length >= 3) ? outline.length : 12
                            }
                            property var shown: {
                                if (shaping)
                                    return live
                                var s = overlay.s
                                var pts = []
                                var i
                                if (outline && outline.length >= 3) {
                                    for (i = 0; i < outline.length; i++)
                                        pts.push({x: outline[i][0] * s, y: outline[i][1] * s})
                                    return pts
                                }
                                return ring(boxX * s, boxY * s, boxW * s, boxH * s)
                            }
                            readonly property real hitX: edge(0, true)
                            readonly property real hitY: edge(1, true)
                            readonly property real hitW: Math.max(8, edge(0, false) - hitX)
                            readonly property real hitH: Math.max(8, edge(1, false) - hitY)

                            function edge(axis, least) {
                                var pts = shown
                                if (!pts || pts.length === 0)
                                    return 0
                                var v = axis === 0 ? pts[0].x : pts[0].y
                                for (var i = 1; i < pts.length; i++) {
                                    var n = axis === 0 ? pts[i].x : pts[i].y
                                    v = least ? Math.min(v, n) : Math.max(v, n)
                                }
                                return v
                            }
                            function ring(x, y, w, h) {
                                var side = 3
                                var pts = []
                                var i
                                for (i = 0; i < side; i++)
                                    pts.push({x: x + w * i / side, y: y})
                                for (i = 0; i < side; i++)
                                    pts.push({x: x + w, y: y + h * i / side})
                                for (i = 0; i < side; i++)
                                    pts.push({x: x + w * (side - i) / side, y: y + h})
                                for (i = 0; i < side; i++)
                                    pts.push({x: x, y: y + h * (side - i) / side})
                                return pts
                            }
                            function copyPts(src) {
                                var out = []
                                for (var i = 0; i < src.length; i++)
                                    out.push({x: src[i].x, y: src[i].y})
                                return out
                            }
                            function beginShape() {
                                live = copyPts(shown)
                                shaping = true
                            }
                            function saveShape() {
                                var s = overlay.s
                                if (s > 0 && live.length >= 3) {
                                    var pairs = []
                                    for (var i = 0; i < live.length; i++)
                                        pairs.push([live[i].x / s, live[i].y / s])
                                    review.setOutline(index, pairs)
                                }
                                shaping = false
                            }

                            // Drawn in the visible window, not on the zoomed picture.
                            // A canvas the size of the zoomed image stops painting,
                            // and the picture then covers the outline.
                            Canvas {
                                id: stroke
                                parent: root
                                x: gestures.x
                                y: gestures.y
                                width: gestures.width
                                height: gestures.height
                                z: 10
                                visible: box.visible
                                onPaint: {
                                    var ctx = getContext("2d")
                                    ctx.clearRect(0, 0, width, height)
                                    var pts = box.shown
                                    if (!pts || pts.length < 3)
                                        return
                                    var ox = stage.x
                                    var oy = stage.y
                                    ctx.beginPath()
                                    ctx.moveTo(pts[0].x + ox, pts[0].y + oy)
                                    for (var i = 1; i < pts.length; i++)
                                        ctx.lineTo(pts[i].x + ox, pts[i].y + oy)
                                    ctx.closePath()
                                    ctx.lineWidth = 4
                                    ctx.strokeStyle = box.lineColor
                                    ctx.stroke()
                                }
                                onVisibleChanged: requestPaint()
                            }
                            onShownChanged: stroke.requestPaint()
                            onLineColorChanged: stroke.requestPaint()
                            Connections {
                                target: stage
                                function onXChanged() { stroke.requestPaint() }
                                function onYChanged() { stroke.requestPaint() }
                            }

                            MouseArea {
                                x: box.hitX
                                y: box.hitY
                                width: box.hitW
                                height: box.hitH
                                preventStealing: true
                                cursorShape: box.isCurrent && root.reshape ? Qt.SizeAllCursor : Qt.ArrowCursor
                                property point origin
                                property var dragStart: []
                                onPressed: function (mouse) {
                                    if (!box.isCurrent || !root.reshape) {
                                        root.annotationClicked(box.index)
                                        return
                                    }
                                    origin = mapToItem(overlay, mouse.x, mouse.y)
                                    box.beginShape()
                                    dragStart = box.copyPts(box.live)
                                }
                                onPositionChanged: function (mouse) {
                                    if (!pressed || !box.isCurrent || !box.shaping)
                                        return
                                    var p = mapToItem(overlay, mouse.x, mouse.y)
                                    var dx = p.x - origin.x
                                    var dy = p.y - origin.y
                                    var copy = []
                                    for (var i = 0; i < dragStart.length; i++) {
                                        copy.push({
                                            x: Math.max(0, Math.min(overlay.width, dragStart[i].x + dx)),
                                            y: Math.max(0, Math.min(overlay.height, dragStart[i].y + dy))
                                        })
                                    }
                                    box.live = copy
                                }
                                onReleased: if (box.isCurrent && box.shaping) box.saveShape()
                            }
                            Repeater {
                                model: box.isCurrent && root.reshape ? box.pointCount : 0
                                delegate: Rectangle {
                                    required property int index
                                    width: 8
                                    height: 8
                                    color: "#f4f4f4"
                                    border.width: 2
                                    border.color: "#000000"
                                    x: box.shown[index].x - 4
                                    y: box.shown[index].y - 4
                                    z: 2
                                    MouseArea {
                                        anchors.fill: parent
                                        preventStealing: true
                                        cursorShape: Qt.SizeAllCursor
                                        property point origin
                                        property real sx: 0
                                        property real sy: 0
                                        onPressed: function (mouse) {
                                            origin = mapToItem(overlay, mouse.x, mouse.y)
                                            box.beginShape()
                                            sx = box.live[index].x
                                            sy = box.live[index].y
                                        }
                                        onPositionChanged: function (mouse) {
                                            if (!pressed)
                                                return
                                            var p = mapToItem(overlay, mouse.x, mouse.y)
                                            var copy = box.copyPts(box.live)
                                            copy[index] = {
                                                x: Math.max(0, Math.min(overlay.width, sx + p.x - origin.x)),
                                                y: Math.max(0, Math.min(overlay.height, sy + p.y - origin.y))
                                            }
                                            box.live = copy
                                        }
                                        onReleased: box.saveShape()
                                    }
                                }
                            }
                        }
                    }
                }
                Canvas {
                    id: sketch
                    parent: root
                    x: gestures.x
                    y: gestures.y
                    width: gestures.width
                    height: gestures.height
                    visible: pan.sketching
                    z: 11
                    onPaint: {
                        var ctx = getContext("2d")
                        ctx.clearRect(0, 0, width, height)
                        var x = Math.min(pan.x1, pan.x2)
                        var y = Math.min(pan.y1, pan.y2)
                        var w = Math.abs(pan.x2 - pan.x1)
                        var h = Math.abs(pan.y2 - pan.y1)
                        if (w < 1 || h < 1)
                            return
                        var ox = stage.x
                        var oy = stage.y
                        var n = 12
                        ctx.beginPath()
                        for (var i = 0; i < n; i++) {
                            var a = -Math.PI / 2 + (2 * Math.PI * i) / n
                            var px = ox + x + w / 2 + (w / 2) * Math.cos(a)
                            var py = oy + y + h / 2 + (h / 2) * Math.sin(a)
                            if (i === 0)
                                ctx.moveTo(px, py)
                            else
                                ctx.lineTo(px, py)
                        }
                        ctx.closePath()
                        ctx.lineWidth = 4
                        ctx.strokeStyle = "#3d7dff"
                        ctx.stroke()
                    }
                }
            }
        }

        // Wheel is handled above the boxes so zoom works anywhere on the picture.
        MouseArea {
            anchors.fill: parent
            z: 2
            cursorShape: root.drawing ? Qt.CrossCursor : Qt.ArrowCursor
            onPressed: function (mouse) { mouse.accepted = false }
            onWheel: function (wheel) {
                var dy = wheel.angleDelta.y !== 0 ? wheel.angleDelta.y : wheel.pixelDelta.y
                if (dy === 0 || stage.baseW <= 0)
                    return
                // One mouse notch is 120 units. Scale by the real delta so a
                // short roll, especially on a trackpad, does not jump a full step.
                var next = Math.max(1, Math.min(8, root.zoom * Math.pow(1.06, dy / 120)))
                var relX = (wheel.x - stage.x) / stage.width
                var relY = (wheel.y - stage.y) / stage.height
                root.zoom = next
                stage.x = wheel.x - relX * stage.width
                stage.y = wheel.y - relY * stage.height
                root.clampPan()
            }
        }
    }
}
