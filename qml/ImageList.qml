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
        if (delta > 0 && listView.currentIndex > 0) {
            listView.currentIndex--
        } else if (delta < 0 && listView.currentIndex < imageModel.count - 1) {
            listView.currentIndex++
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
    // 暴露 currentIndex 给外部，与内部 listView 双向同步
    property alias currentIndex: listView.currentIndex
    signal imageSelected(int imageId)
    signal imageRightClicked(int imageId, string filename, string action)

    // 监听 currentIndex 变化，触发图片加载（用于键盘/滚轮/全屏切换）
    onCurrentIndexChanged: {
        if (currentIndex >= 0 && currentIndex < imageModel.count) {
            var item = imageModel.get(currentIndex)
            if (item && item.id !== undefined) {
                selectedImageId = item.id
                imageSelected(item.id)
            }
        }
    }

    Component.onCompleted: loadImages()

    property int currentGroupId: -1

    function loadImages(groupId) {
        currentGroupId = groupId || -1
        // 重置选中状态，确保新分组的图片能正常加载
        selectedImageId = -1
        currentIndex = -1
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
            currentIndex = 0
        }
    }

    // 供外部调用获取当前图片数量
    function imageCount() {
        return imageModel.count
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
                }
            } else if (event.key === Qt.Key_Down) {
                event.accepted = true
                if (currentIndex < count - 1) {
                    currentIndex++
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
                    if (mouse.button === Qt.LeftButton) {
                        listView.currentIndex = index
                        listView.forceActiveFocus()
                    } else if (mouse.button === Qt.RightButton) {
                        selectedImageId = model.id
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