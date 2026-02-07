// ImageList.qml - 图片列表组件
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "ColorUtils.js" as ColorUtils

Item {
    property color customBackground: '#112233'
    property color customAccent: '#30638f'
    anchors.fill: parent

    // 背景矩形
    Rectangle {
        anchors.fill: parent
        color: customBackground
        border.color: customAccent
        border.width: 1
        radius: 8
        z: -1
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
        
        ScrollBar.vertical: styledScrollBar.createObject(listView)
        
        // 覆盖默认滚轮行为，用滚轮切换选中项
        MouseArea {
            anchors.fill: parent
            propagateComposedEvents: true
            onWheel: function(event) {
                navigateWithWheel(event.angleDelta.y)
                event.accepted = true
            }
            onClicked: function(mouse) {
                mouse.accepted = false
            }
        }
    }

    // 可复用组件：主题化ScrollBar
    Component {
        id: styledScrollBar
        ScrollBar {
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
                onClicked: function(mouse) {
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

                    color: model.id === selectedImageId ? ColorUtils.getTextColor(customAccent) : ColorUtils.getTextColor(customBackground)
                }
            }
        }
    }
}