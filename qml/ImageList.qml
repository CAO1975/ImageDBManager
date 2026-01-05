// ImageList.qml - 移除所有与主题相关的代码
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Controls.Universal

Item {
    property color customBackground: '#112233'
    property color customAccent: '#30638f'
    anchors.fill: parent
    
    // 添加背景色和边框，确保在任何容器中都有一致的外观
    Rectangle {
        anchors.fill: parent
        color: customBackground
        border.color: customAccent
        border.width: 1
        z: -1
        // 添加圆角效果
        radius: 8
    }
    
    ListModel {
        id: imageModel
    }
    
    MouseArea {
        anchors.fill: parent
        onClicked: listView.forceActiveFocus()
        onWheel: function(event) {
            if (event.angleDelta.y > 0) {
                if (listView.currentIndex > 0) {
                    listView.currentIndex--
                    selectedImageId = imageModel.get(listView.currentIndex).id
                    imageSelected(selectedImageId)
                }
            } else if (event.angleDelta.y < 0) {
                if (listView.currentIndex < imageModel.count - 1) {
                    listView.currentIndex++
                    selectedImageId = imageModel.get(listView.currentIndex).id
                    imageSelected(selectedImageId)
                }
            }
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
        // 保存当前分组ID
        currentGroupId = groupId || -1
        imageModel.clear()
        // 如果没有提供groupId，默认获取所有图片
        var imageIds = database.getAllImageIds(currentGroupId)
        
        for (var i = 0; i < imageIds.length; i++) {
            var imageId = imageIds[i]
            var filename = database.getImageFilename(imageId)
            
            if (filename) {
                imageModel.append({
                    "id": imageId,
                    "filename": filename,
                    "itemHeight": 140
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
        
        ScrollBar.vertical: ScrollBar {
            id: scrollBar
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            policy: ScrollBar.AlwaysOn
            active: true
            width: 8
            background: Rectangle { 
                color: customBackground
                radius: 4 
            }
            contentItem: Rectangle { 
                radius: 4
                color: customAccent
            }
        }

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
        
        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.NoButton
            
            onWheel: function(event) {
                if (event.angleDelta.y > 0) {
                    if (listView.currentIndex > 0) {
                        listView.currentIndex--
                        selectedImageId = imageModel.get(listView.currentIndex).id
                        imageSelected(selectedImageId)
                    }
                } else if (event.angleDelta.y < 0) {
                    if (listView.currentIndex < imageModel.count - 1) {
                        listView.currentIndex++
                        selectedImageId = imageModel.get(listView.currentIndex).id
                        imageSelected(selectedImageId)
                    }
                }
                event.accepted = true
            }
        }
    }
    
    // 右键菜单
    Menu {
        id: imageContextMenu
        
        MenuItem {
            text: "重命名图片文件"
            onClicked: {
                // 发射信号通知主界面打开重命名对话框
                imageRightClicked(contextImageId, contextImageFilename, "rename")
            }
        }
        
        MenuItem {
            text: "删除图片"
            onClicked: {
                // 发射信号通知主界面打开删除确认对话框
                imageRightClicked(contextImageId, contextImageFilename, "delete")
            }
        }
        
        MenuItem {
            text: "调整图片到指定分组"
            onClicked: {
                // 发射信号通知主界面打开调整分组对话框
                imageRightClicked(contextImageId, contextImageFilename, "move")
            }
        }
    }
    
    Component {
        id: imageDelegate
        Rectangle {
            width: listView.width - 10
            height: model.itemHeight
            
            radius: 8
            color: model.id === selectedImageId ? customAccent : customBackground
            border.color: "transparent"
            border.width: 1
            
            Behavior on height {
                NumberAnimation { duration: 200 }
            }
            
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
                        // 保存当前右键点击的图片信息
                        contextImageId = model.id
                        contextImageFilename = model.filename
                        imageContextMenu.popup()
                    }
                }
            }
            
            Row {
                anchors.fill: parent
                anchors.margins: 5
                spacing: 8
                
                Image {
                id: thumbnail
                width: 140
                height: parent.height - 8
                // 使用自定义图片提供器加载缩略图
                source: "image://imageprovider/" + model.id
                fillMode: Image.PreserveAspectFit
                anchors.verticalCenter: parent.verticalCenter
                
                onStatusChanged: {
                    if (status === Image.Ready) {
                        var aspectRatio = sourceSize.width / sourceSize.height
                        var calculatedHeight = Math.round(140 / aspectRatio) + 16
                        calculatedHeight = Math.max(60, Math.min(calculatedHeight, 200))
                        imageModel.setProperty(index, "itemHeight", calculatedHeight)
                        listView.forceLayout()
                    }
                }
            }
                
                Text {
                    anchors.left: thumbnail.right
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.leftMargin: 8
                    text: model.filename || "无文件名"
                    font.pointSize: 11
                    color: (0.299 * (model.id === selectedImageId ? customAccent.r : customBackground.r) + 0.587 * (model.id === selectedImageId ? customAccent.g : customBackground.g) + 0.114 * (model.id === selectedImageId ? customAccent.b : customBackground.b)) > 0.5 ? "#000000" : "#FFFFFF"
                    font.bold: true
                    elide: Text.ElideRight
                    verticalAlignment: Text.AlignVCenter
                }
            }
        }
    }
}