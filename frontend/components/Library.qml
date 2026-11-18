import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts

// Pictures in the review set. ADD TIFF copies a new .tif or .tiff into the set.
Rectangle {
    id: root
    property bool open: true
    implicitWidth: open ? 176 : 36
    color: "#161616"
    border.width: 4
    border.color: "#f4f4f4"
    clip: true

    Behavior on implicitWidth {
        NumberAnimation { duration: 160; easing.type: Easing.OutQuad }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 4
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 28
            Layout.alignment: Qt.AlignTop
            spacing: 6
            PixelText {
                visible: root.open
                Layout.alignment: Qt.AlignVCenter
                Layout.leftMargin: 6
                text: "LIBRARY"
                color: "#f4f4f4"
                pixel: 6
            }
            Item { Layout.fillWidth: true; visible: root.open }
            IconButton {
                Layout.preferredWidth: 28
                Layout.preferredHeight: 28
                Layout.alignment: Qt.AlignRight
                zoom: 1
                mark: root.open ? "fold" : "unfold"
                tip: root.open ? "FOLD" : "UNFOLD"
                onClicked: root.open = !root.open
            }
        }

        ListView {
            id: list
            visible: root.open
            Layout.fillWidth: true
            Layout.fillHeight: root.open
            Layout.maximumHeight: root.open ? 4096 : 0
            clip: true
            spacing: 4
            boundsBehavior: Flickable.StopAtBounds
            model: review.library
            delegate: Rectangle {
                required property int index
                required property string name
                required property bool current
                width: list.width
                height: 28
                color: current ? "#3d7dff" : "#000000"
                border.width: 2
                border.color: "#f4f4f4"
                Item {
                    anchors.fill: parent
                    anchors.leftMargin: 6
                    anchors.rightMargin: 6
                    clip: true
                    PixelText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: name
                        color: current ? "#ffffff" : "#f4f4f4"
                        pixel: 6
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: review.openImage(index)
                }
            }
        }

        RowLayout {
            visible: root.open
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredHeight: root.open ? 28 : 0
            Layout.maximumHeight: root.open ? 28 : 0
            spacing: 8
            IconButton {
                Layout.preferredWidth: 28
                Layout.preferredHeight: 28
                zoom: 1
                mark: "plus"
                tip: "ADD"
                onClicked: tiffDialog.open()
            }
            IconButton {
                Layout.preferredWidth: 28
                Layout.preferredHeight: 28
                zoom: 1
                mark: "cross"
                tip: "DELETE"
                onClicked: review.deleteImage()
            }
        }
    }

    FileDialog {
        id: tiffDialog
        title: "Add"
        fileMode: FileDialog.OpenFiles
        nameFilters: ["TIFF files (*.tif *.tiff)"]
        onAccepted: {
            for (var i = 0; i < selectedFiles.length; i++)
                review.addTiff(selectedFiles[i])
        }
    }

    Connections {
        target: review
        function onImageChanged() {
            list.positionViewAtIndex(review.imageIndex, ListView.Contain)
        }
    }
}
