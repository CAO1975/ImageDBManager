// ImageList.qml - 图片列表组件（已注释掉CoverFlow 3D效果）
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Controls.Universal

Item {
    property color customBackground: '#112233'
    property color customAccent: '#30638f'
    anchors.fill: parent

    // 可复用组件：主题化Rectangle
    component ThemedRectangle: Rectangle {
        property color bgColor: customBackground
        property color accentColor: customAccent
        property int borderWidth: 1
        property real borderRadius: 8

        color: bgColor
        border.color: accentColor
        border.width: borderWidth
        radius: borderRadius
    }

    ThemedRectangle {
        anchors.fill: parent
        z: -1
    }

    // 根据背景颜色计算合适的文字颜色
    function getTextColor(backgroundColor) {
        let brightness = 0.299 * backgroundColor.r + 0.587 * backgroundColor.g + 0.114 * backgroundColor.b
        return brightness > 0.5 ? "#000000" : "#FFFFFF"
    }

    // 导航函数：根据滚轮方向切换图片
    function navigateWithWheel(delta) {
        if (delta > 0) {
            if (listView.currentIndex > 0) {
                listView.currentIndex--
                selectedImageId = imageModel.get(listView.currentIndex).id
                imageSelected(selectedImageId)
            }
        } else if (delta < 0) {
            if (listView.currentIndex < imageModel.count - 1) {
                listView.currentIndex++
                selectedImageId = imageModel.get(listView.currentIndex).id
                imageSelected(selectedImageId)
            }
        }
    }

    ListModel { id: imageModel }
    
    MouseArea {
        anchors.fill: parent
        onClicked: listView.forceActiveFocus()
        onWheel: function(event) {
            navigateWithWheel(event.angleDelta.y)
            event.accepted = true
        }
    }
    
    property int selectedImageId: -1
    property int contextImageId: -1
    property string contextImageFilename: ""
    signal imageSelected(int imageId)
    signal imageRightClicked(int imageId, string filename, string action)

    Component.onCompleted: loadImages()

    property int currentGroupId: -1

    function loadImages(groupId) {
        currentGroupId = groupId || -1
        imageModel.clear()
        var imageIds = database.getAllImageIds(currentGroupId)

        for (var i = 0; i < imageIds.length; i++) {
            var imageId = imageIds[i]
            var filename = database.getImageFilename(imageId)

            if (filename) {
                imageModel.append({
                    "id": imageId,
                    "filename": filename
                })
            }
        }

        if (imageModel.count > 0) {
            selectedImageId = imageModel.get(0).id
            imageSelected(selectedImageId)
        }
    }
    
    ListView {
        id: listView
        anchors.fill: parent
        anchors.margins: 5
        model: imageModel
        delegate: imageDelegate
        clip: true
        cacheBuffer: 100
        
        focus: true
        Keys.enabled: true
        
        Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Up) {
                event.accepted = true
                if (currentIndex > 0) {
                    currentIndex--
                    selectedImageId = imageModel.get(currentIndex).id
                    imageSelected(selectedImageId)
                }
            } else if (event.key === Qt.Key_Down) {
                event.accepted = true
                if (currentIndex < count - 1) {
                    currentIndex++
                    selectedImageId = imageModel.get(currentIndex).id
                    imageSelected(selectedImageId)
                }
            }
        }
        
        ScrollBar.vertical: ScrollBar {
            width: 8
            policy: ScrollBar.AlwaysOn
            active: true
            background: Rectangle {
                color: customBackground
                radius: 4
            }
            contentItem: Rectangle {
                radius: 4
                color: customAccent
            }
        }
        
        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.NoButton

            onWheel: function(event) {
                navigateWithWheel(event.angleDelta.y)
                event.accepted = true
            }
        }
    }
    
    Menu {
        id: imageContextMenu
        MenuItem {
            text: "重命名图片文件"
            onClicked: imageRightClicked(contextImageId, contextImageFilename, "rename")
        }
        MenuItem {
            text: "删除图片"
            onClicked: imageRightClicked(contextImageId, contextImageFilename, "delete")
        }
        MenuItem {
            text: "调整图片到指定分组"
            onClicked: imageRightClicked(contextImageId, contextImageFilename, "move")
        }
    }
    
    Component {
        id: imageDelegate
        Rectangle {
            id: cardRoot
            width: listView.width - 10

            // ===== CoverFlow 3D 变换核心 =====
            // 注释掉3D效果，使用普通列表显示
            /*
            property real rawHeight: Math.max(80, Math.min(250, model.itemHeight))
            property real centerOffset: y - listView.contentY - listView.height/2 + rawHeight/2
            property real distanceRatio: Math.min(1.0, Math.abs(centerOffset) / (listView.height/2))
            property real maxTiltAngle: 50
            property real tiltAngle: maxTiltAngle * Math.pow(distanceRatio, 0.5)
            property real heightCompensation: distanceRatio > 0.01 ? 1.0 / Math.cos(tiltAngle * Math.PI / 180) : 1.0

            height: rawHeight

            transform: [
                Rotation {
                    origin.x: cardRoot.width/2
                    origin.y: cardRoot.height/2
                    axis: Qt.vector3d(1, 0, 0)
                    angle: -tiltAngle * Math.sign(centerOffset)
                },
                Scale {
                    origin.x: cardRoot.width/2
                    origin.y: cardRoot.height/2
                    xScale: 1.2 - distanceRatio * 0.3
                    yScale: 1.2 - distanceRatio * 0.3
                }
            ]

            z: -Math.abs(centerOffset)
            */

            property real thumbnailWidth: 110
            property real thumbnailHeight: thumbnail.implicitHeight || 140

            height: thumbnailHeight + 10

            radius: 8
            color: model.id === selectedImageId ? customAccent : customBackground
            border.color: "transparent"
            border.width: 1

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: {
                    selectedImageId = model.id
                    listView.currentIndex = index
                    if (mouse.button === Qt.LeftButton) {
                        imageSelected(model.id)
                        listView.forceActiveFocus()
                    } else if (mouse.button === Qt.RightButton) {
                        contextImageId = model.id
                        contextImageFilename = model.filename
                        imageContextMenu.popup()
                    }
                }
            }

            // ===== 修复：使用 RowLayout 替代 Row =====
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 5
                anchors.rightMargin: 5
                anchors.topMargin: 0
                anchors.bottomMargin: 0
                spacing: 8

                Image {
                    id: thumbnail
                    width: thumbnailWidth
                    height: parent.height - 10
                    source: "image://imageprovider/" + model.id
                    fillMode: Image.PreserveAspectFit
                    Layout.alignment: Qt.AlignVCenter
                }

                Text {
                    Layout.fillWidth: true    // 填充剩余宽度
                    Layout.alignment: Qt.AlignVCenter

                    text: model.filename || "无文件名"
                    font.pointSize: 11
                    font.bold: true
                    elide: Text.ElideRight
                    verticalAlignment: Text.AlignVCenter

                    color: model.id === selectedImageId ? getTextColor(customAccent) : getTextColor(customBackground)
                }
            }
        }
    }
}