import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtMultimedia
import "components"

ApplicationWindow {
    id: win
    visible: true
    width: 1180; height: 760
    title: "Microscopix"
    property bool playing: false
    property bool drawMode: false
    property bool reshapeMode: false
    property bool muted: false
    color: "#000000"
    palette: Palette {
        window: "#000000"
        windowText: "#ffffff"
        base: "#111111"
        alternateBase: "#1a1a1a"
        text: "#ffffff"
        button: "#ffffff"
        buttonText: "#000000"
        highlight: "#ffffff"
        highlightedText: "#000000"
        mid: "#666666"
        dark: "#222222"
        light: "#dddddd"
        midlight: "#333333"
        shadow: "#000000"
        brightText: "#ffffff"
        placeholderText: "#888888"
        toolTipBase: "#ffffff"
        toolTipText: "#000000"
    }

    // Chill/Calming Chiptune Loop by Reganati, Pixabay Content License.
    // https://pixabay.com/music/electronic-chillcalming-chiptune-loop-527182/
    MediaPlayer {
        id: theme
        source: Qt.resolvedUrl("assets/chiptune-loop.mp3")
        audioOutput: AudioOutput { volume: win.muted ? 0 : 0.28 }
        loops: MediaPlayer.Infinite
        Component.onCompleted: play()
    }

    function showBanner(text) {
        banner.text = bannerAnim.running ? banner.text + "   ·   " + text : text
        bannerAnim.restart()
    }

    Connections {                        // 7. scoring updates -> interface
        target: review
        function onXpGained(amount) { xpDisplay.showGain(amount) }
        function onLevelUp(lvl) { win.showBanner("Level up! You are now level " + lvl) }
        function onFixChanged() { nameField.text = review.fixLabel }
    }

    ColumnLayout {
        visible: win.playing
        anchors.fill: parent
        anchors.margins: 20
        spacing: 16

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 48
            color: "#161616"
            border.width: 4
            border.color: "#f4f4f4"

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                spacing: 8

                PixelText {
                    Layout.alignment: Qt.AlignVCenter
                    text: "TOOLS"
                    color: "#f4f4f4"
                    pixel: 7
                    weight: Font.Black
                }
                Rectangle {
                    Layout.preferredWidth: 2
                    Layout.preferredHeight: 18
                    Layout.alignment: Qt.AlignVCenter
                    color: "#f4f4f4"
                }
                IconButton {
                    Layout.preferredWidth: 26
                    Layout.preferredHeight: 26
                    Layout.alignment: Qt.AlignVCenter
                    zoom: 0.5
                    tipBelow: true
                    mark: "draw"
                    tip: "DRAW"
                    active: win.drawMode
                    onClicked: {
                        win.drawMode = !win.drawMode
                        if (win.drawMode)
                            win.reshapeMode = false
                    }
                }
                IconButton {
                    Layout.preferredWidth: 26
                    Layout.preferredHeight: 26
                    Layout.alignment: Qt.AlignVCenter
                    visible: !review.fixing
                    zoom: 0.5
                    tipBelow: true
                    mark: "reshape"
                    tip: "EDIT"
                    active: win.reshapeMode
                    onClicked: {
                        win.reshapeMode = !win.reshapeMode
                        if (win.reshapeMode)
                            win.drawMode = false
                    }
                }
                Rectangle {
                    Layout.preferredWidth: 2
                    Layout.preferredHeight: 14
                    Layout.alignment: Qt.AlignVCenter
                    color: "#3a3a3a"
                }
                IconButton {
                    Layout.preferredWidth: 26
                    Layout.preferredHeight: 26
                    Layout.alignment: Qt.AlignVCenter
                    zoom: 0.5
                    tipBelow: true
                    mark: "undo"
                    tip: "UNDO"
                    onClicked: review.undo()
                }
                IconButton {
                    Layout.preferredWidth: 26
                    Layout.preferredHeight: 26
                    Layout.alignment: Qt.AlignVCenter
                    zoom: 0.5
                    tipBelow: true
                    mark: "redo"
                    tip: "REDO"
                    onClicked: review.redo()
                }
                IconButton {
                    Layout.preferredWidth: 26
                    Layout.preferredHeight: 26
                    Layout.alignment: Qt.AlignVCenter
                    zoom: 0.5
                    tipBelow: true
                    mark: "reset"
                    tip: "RESET"
                    onClicked: review.reset()
                }
                Rectangle {
                    Layout.preferredWidth: 2
                    Layout.preferredHeight: 14
                    Layout.alignment: Qt.AlignVCenter
                    color: "#3a3a3a"
                }
                IconButton {
                    Layout.preferredWidth: 26
                    Layout.preferredHeight: 26
                    Layout.alignment: Qt.AlignVCenter
                    zoom: 0.5
                    tipBelow: true
                    mark: win.muted ? "mute" : "sound"
                    tip: win.muted ? "SOUND" : "MUTE"
                    onClicked: win.muted = !win.muted
                }
                Item { Layout.fillWidth: true }
                IconButton {
                    Layout.preferredWidth: 26
                    Layout.preferredHeight: 26
                    Layout.alignment: Qt.AlignVCenter
                    zoom: 0.5
                    tipBelow: true
                    mark: "menu"
                    tip: "MENU"
                    onClicked: {
                        win.drawMode = false
                        win.reshapeMode = false
                        win.playing = false
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 16

            Library {
                id: library
                Layout.preferredWidth: library.implicitWidth
                Layout.fillHeight: true
            }

            ImageViewer {
                Layout.fillWidth: true
                Layout.fillHeight: true
                source: review.fixing ? review.cropUrl : review.imageUrl
                showBoxes: !review.fixing
                drawing: win.drawMode && !review.fixing
                reshape: win.reshapeMode && !review.fixing
                annotations: review.model
                currentIndex: review.currentIndex
                onAnnotationClicked: (i) => review.select(i)
                onOutlineDrawn: function (x, y, w, h) {
                    review.addBox(x, y, w, h)
                    win.drawMode = false
                }
            }

            Item {
                Layout.preferredWidth: 228
                Layout.fillHeight: true

                AnnotationInfo {
                    anchors.fill: parent
                    visible: !review.fixing
                    annotationId: review.currentId
                    label: review.currentLabel
                    confidence: review.currentConfidence
                    objectX: review.currentX
                    objectY: review.currentY
                    objectWidth: review.currentWidth
                    objectHeight: review.currentHeight
                    objectCount: review.currentCount
                    statusText: review.currentStatus
                    statusKey: review.currentStatusKey
                    complete: review.imageComplete
                    completeText: review.completeText
                }

                Rectangle {
                    anchors.fill: parent
                    visible: review.fixing
                    color: "#161616"
                    border.width: 4
                    border.color: "#f4f4f4"

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 18
                        spacing: 14
                        PixelText { text: "FLAGGED"; color: "#e23b3b"; pixel: 6 }
                        PixelText { text: review.fixProgress; color: "#f4f4f4"; pixel: 8 }
                        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 2; color: "#f4f4f4" }
                        PixelText { text: "NEW NAME"; color: "#8a8a8a"; pixel: 6 }
                        TextField {
                            id: nameField
                            Layout.fillWidth: true
                            font.family: "Courier New"
                            font.bold: true
                            font.pixelSize: 16
                            color: "#f4f4f4"
                            placeholderText: "name"
                            background: Rectangle {
                                color: "#000000"
                                border.width: 2
                                border.color: "#f4f4f4"
                            }
                        }
                        Item { Layout.fillHeight: true }
                    }
                }

                XPDisplay {
                    id: xpDisplay
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.margins: 18
                    z: 2
                    level: review.level
                    xp: review.xp
                    xpIntoLevel: review.xpIntoLevel
                    xpPerLevel: review.xpPerLevel
                }
            }
        }

        ReviewButtons {
            Layout.fillWidth: true
            reviewing: !review.imageComplete
            fixing: review.fixing
            canReview: review.canReview
            canAdvance: review.canAdvance
            nextText: review.nextText
            xpAccept: review.reward("accept")
            xpFlag: review.reward("flag")
            onAccepted: review.accept()
            onFlagged: review.flag()
            onNextRequested: review.nextImage()
            onRenamed: review.renameFlagged(nameField.text)
            onDeleted: review.deleteFlagged()
        }
    }

    StartScreen {
        anchors.fill: parent
        muted: win.muted
        onMuteToggled: win.muted = !win.muted
        visible: !win.playing
        z: 2
        onStart: win.playing = true
    }

    Item {
        id: bannerBox
        width: banner.implicitWidth + 36
        height: 52
        anchors.horizontalCenter: parent.horizontalCenter
        y: -height
        Rectangle { x: 4; y: 4; width: parent.width - 4; height: parent.height - 4; color: "#000000" }
        Rectangle {
            width: parent.width - 4; height: parent.height - 4
            color: "#f4f4f4"
            border.width: 4; border.color: "#000000"
        }
        PixelText {
            id: banner
            anchors.centerIn: parent
            anchors.verticalCenterOffset: -2
            text: ""
            color: "#000000"
            pixel: 6
        }
        SequentialAnimation {
            id: bannerAnim
            NumberAnimation { target: bannerBox; property: "y"; to: 12; duration: 250 }
            PauseAnimation { duration: 1800 }
            NumberAnimation { target: bannerBox; property: "y"; to: -bannerBox.height; duration: 250 }
        }
    }
}
