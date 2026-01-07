// Main.qml - 稳定深色主题版本（无主题切换，分隔条可拖拽）
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Controls.Universal
import QtQuick.Dialogs


ApplicationWindow {
    id: window
    visible: true
    width: 1388
    height: 818
    minimumWidth: 850
    minimumHeight: 580
    title: "ImageDBManager"

    // 🔑 关键：设置窗口背景透明
    color: "transparent"


    // 使用Universal暗色主题
    Universal.theme: Universal.Dark

    // 自定义颜色属性，用于动态修改
    property color customBackground: '#0d1a28'
    property color customAccent: '#30638f'

    // 右键菜单上下文属性
    property int contextMenuGroupId: -1
    property string contextMenuGroupName: ""

    // 当前选中的分组ID
    property int currentGroupId: -1

    // 标题栏显示信息
    property string groupPath: ""
    property int imageCount: 0
    property string currentImageInfo: ""
    
    // 图片尺寸缓存
    property var imageSizeCache: ({})
    
    // 连接数据库的图片尺寸信号
    Connections {
        target: database
        function onImageSizeLoaded(imageId, width, height) {
            console.log("Image size loaded:", imageId, width, "x", height)
            imageSizeCache[imageId] = { width: width, height: height }
        }
    }

    // 可复用组件：标题栏分隔符
    component TitleBarSeparator: Rectangle {
        width: 1
        height: 20
        color: (0.299 * window.customBackground.r + 0.587 * window.customBackground.g + 0.114 * window.customBackground.b) > 0.5 ? "#000000" : "#FFFFFF"
        opacity: 0.3
        Layout.alignment: Qt.AlignVCenter
        Layout.leftMargin: 8
        Layout.rightMargin: 8
    }

    // 可复用组件：主题颜色选择按钮（带悬停效果）
    component ThemeColorButton: Button {
        id: btn
        property color bgColor: window.customBackground
        property color hoverColor: window.customAccent

        Layout.preferredWidth: 80
        Layout.preferredHeight: 28
        hoverEnabled: true

        background: Rectangle {
            id: btnBackground
            color: btn.bgColor
            border.color: window.customAccent
            border.width: 1
            radius: 4

            Behavior on color {
                ColorAnimation { duration: 200 }
            }
        }

        contentItem: Text {
            id: btnText
            text: btn.text
            color: (0.299 * window.customBackground.r + 0.587 * window.customBackground.g + 0.114 * window.customBackground.b) > 0.5 ? "#000000" : "#FFFFFF"
            font.pointSize: 11
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }

        onHoveredChanged: {
            if (hovered) {
                btnBackground.color = btn.hoverColor
                btnText.color = "white"
            } else {
                btnBackground.color = btn.bgColor
                btnText.color = (0.299 * window.customBackground.r + 0.587 * window.customBackground.g + 0.114 * window.customBackground.b) > 0.5 ? "#000000" : "#FFFFFF"
            }
        }
    }

    // 可复用组件：主题化ComboBox
    component StyledComboBox: ComboBox {
        id: root
        property color textColor: (0.299 * window.customBackground.r + 0.587 * window.customBackground.g + 0.114 * window.customBackground.b) > 0.5 ? "#000000" : "#FFFFFF"
        property string placeholderText: ""

        Layout.preferredHeight: 28

        contentItem: Text {
            text: root.displayText !== "" ? root.displayText : root.placeholderText
            color: root.textColor
            font.pointSize: 11
            padding: 8
            verticalAlignment: Text.AlignVCenter
        }

        background: Rectangle {
            color: window.customBackground
            border.color: window.customAccent
            border.width: 1
            radius: 6
        }

        delegate: ItemDelegate {
            text: modelData
            width: root.width
            height: 30
            contentItem: Text {
                text: modelData
                color: (0.299 * window.customBackground.r + 0.587 * window.customBackground.g + 0.114 * window.customBackground.b) > 0.5 ? "#000000" : "#FFFFFF"
                font.pointSize: 11
                padding: 10
                verticalAlignment: Text.AlignVCenter
            }
            highlighted: root.highlightedIndex === index
            background: Rectangle {
                color: highlighted ? window.customAccent : window.customBackground
            }
        }

        popup: Popup {
            y: root.height
            width: root.width
            implicitHeight: contentItem.implicitHeight
            padding: 1

            background: Rectangle {
                color: window.customBackground
                border.color: window.customAccent
                border.width: 1
                radius: 4
            }

            contentItem: ListView {
                clip: true
                implicitHeight: Math.min(contentHeight, 360)
                model: root.delegateModel
                currentIndex: root.highlightedIndex
                spacing: 1

                ScrollBar.vertical: StyledScrollBar {}
            }
        }
    }

    // 可复用组件：主题化TextField
    component StyledTextField: TextField {
        id: root
        property color textColor: (0.299 * window.customBackground.r + 0.587 * window.customBackground.g + 0.114 * window.customBackground.b) > 0.5 ? "#000000" : "#FFFFFF"

        Layout.preferredHeight: 28

        placeholderTextColor: (0.299 * window.customBackground.r + 0.587 * window.customBackground.g + 0.114 * window.customBackground.b) > 0.5 ? "#666666" : "#888888"
        color: root.textColor
        font.pointSize: 11

        background: Rectangle {
            color: window.customBackground
            border.color: window.customAccent
            border.width: 1
            radius: 6
        }
    }

    // 可复用组件：主题化ScrollBar
    component StyledScrollBar: ScrollBar {
        property color backgroundColor: window.customBackground
        property color accentColor: window.customAccent

        width: 8
        policy: ScrollBar.AlwaysOn
        active: true

        background: Rectangle {
            color: backgroundColor
            radius: 4
        }

        contentItem: Rectangle {
            radius: 4
            color: accentColor
        }
    }

    // 隐藏原生标题栏，添加支持透明背景的标志
    flags: Qt.Window | Qt.FramelessWindowHint | Qt.WindowTitleHint | 
           Qt.WindowSystemMenuHint | Qt.WindowMinMaxButtonsHint | Qt.WindowCloseButtonHint
    
    // 获取分组完整路径
    function getFullGroupPath(groupId) {
        if (groupId === -1) {
            return "未分组";
        }
        
        var fullPath = database.getGroupPath(groupId);
        console.log("Group path for ID " + groupId + ": " + fullPath);
        return fullPath;
    }
    
    // 获取当前分组图片数量
    function updateImageCount(groupId) {
        var imageIds = database.getAllImageIds(groupId);
        console.log("Image IDs for group " + groupId + ": " + JSON.stringify(imageIds));
        var count = imageIds.length;
        console.log("Image count for group " + groupId + ": " + count);
        return count;
    }
    
    // 初始化标题栏信息
    function initializeTitleBarInfo() {
        groupPath = getFullGroupPath(currentGroupId);
        imageCount = updateImageCount(currentGroupId);
        currentImageInfo = "";
        console.log("Title bar info initialized: groupPath=" + groupPath + ", imageCount=" + imageCount);
    }

    // 获取当前图片详细信息
    function getCurrentImageInfo(imageId) {
        if (imageId === -1) {
            console.log("No image selected");
            return "";
        }
        
        console.log("Getting info for image ID " + imageId);
        var filename = database.getImageFilename(imageId);
        console.log("Filename: " + filename);
        
        var byteSize = database.getImageByteSize(imageId);
        console.log("Byte size: " + byteSize);
        
        // 从缓存获取图片尺寸，如果缓存中没有则使用默认值
        var imageSize = imageSizeCache[imageId] || { width: 0, height: 0 };
        console.log("Image size: " + JSON.stringify(imageSize));
        
        // 格式化字节大小
        var formattedSize = "";
        if (byteSize < 1024) {
            formattedSize = byteSize + " B";
        } else if (byteSize < 1024 * 1024) {
            formattedSize = (byteSize / 1024).toFixed(2) + " KB";
        } else {
            formattedSize = (byteSize / (1024 * 1024)).toFixed(2) + " MB";
        }
        
        // 格式化尺寸（使用缓存的尺寸）
        var formattedDimensions = imageSize.width > 0 ? (imageSize.width + "×" + imageSize.height) : "未知尺寸";
        
        var info = filename + " - " + formattedSize + " - " + formattedDimensions;
        console.log("Current image info: " + info);
        return info;
    }
    
    onVisibilityChanged: {
        if (window.visibility === Window.Maximized) {
            maxIcon.text = "❐"
        } else {
            maxIcon.text = "□"
        }
    }
    
    // 窗口关闭前保存设置
    onClosing: {
        saveSettings()
    }
    
    // 组件加载完成后初始化数据
    Component.onCompleted: {
        // 主界面初始化完成
        console.log("Main window initialized")
        
        // 加载设置
        loadSettings()
    }
    
    // 加载设置
    function loadSettings() {
        // 读取过渡效果设置
        let transValue = database.getSetting("QTtrans", "0")
        transitionComboBox.currentIndex = parseInt(transValue)
        if (transitionComboBox.currentIndex === 0) {
            // 随机模式
            imageViewer.transitionType = -1
        } else {
            // 所有过渡效果（包括普通和着色器）：transitionType = currentIndex - 1
            imageViewer.transitionType = transitionComboBox.currentIndex - 1
        }
        
        // 读取过渡时间设置
        let transTimeValue = database.getSetting("QTtransTime", "2")
        durationComboBox.currentIndex = parseInt(transTimeValue)
        let durationValues = [0, 500, 1000, 2000, 3000, 4000, 5000, 6000, 7000, 8000]
        imageViewer.transitionDuration = durationValues[parseInt(transTimeValue)]
        
        // 读取窗口位置和大小
        let windowLeft = database.getSetting("WindowLeft", "100")
        let windowTop = database.getSetting("WindowTop", "100")
        let windowWidth = database.getSetting("WindowWidth", "1388")
        let windowHeight = database.getSetting("WindowHeight", "818")
        let windowState = database.getSetting("WindowState", "0")
        
        window.x = parseInt(windowLeft)
        window.y = parseInt(windowTop)
        window.width = parseInt(windowWidth)
        window.height = parseInt(windowHeight)
        
        // 设置窗口状态
        if (windowState === "1") {
            window.visibility = Window.Maximized
        } else {
            window.visibility = Window.Windowed
        }
        
        // 读取分组树和图片列表宽度
        let groupTreeWidth = database.getSetting("GroupTreeWidth", "200")
        let imageListWidth = database.getSetting("ImageListWidth", "200")
        
        // 设置SplitView的分隔条位置
        groupTreeContainer.SplitView.preferredWidth = parseInt(groupTreeWidth)
        imageListContainer.SplitView.preferredWidth = parseInt(imageListWidth)
        
        // 读取自定义背景色和强调色
        let bgColor = database.getSetting("CustomBackground", '#0d1a28')
        let accentColor = database.getSetting("CustomAccent", '#30638f')
        customBackground = bgColor
        customAccent = accentColor
    }
    
    // 保存设置
    function saveSettings() {
        // 保存过渡效果设置
        database.saveSetting("QTtrans", transitionComboBox.currentIndex.toString())
        
        // 保存过渡时间设置
        database.saveSetting("QTtransTime", durationComboBox.currentIndex.toString())
        
        // 保存窗口位置和大小（仅当窗口不是最大化状态时）
        if (window.visibility === Window.Windowed) {
            database.saveSetting("WindowLeft", window.x.toString())
            database.saveSetting("WindowTop", window.y.toString())
            database.saveSetting("WindowWidth", window.width.toString())
            database.saveSetting("WindowHeight", window.height.toString())
        }
        
        // 保存窗口状态
        let windowState = window.visibility === Window.Maximized ? "1" : "0"
        database.saveSetting("WindowState", windowState)
        
        // 保存分组树和图片列表宽度
        database.saveSetting("GroupTreeWidth", groupTreeContainer.width.toString())
        database.saveSetting("ImageListWidth", imageListContainer.width.toString())
        
        // 保存自定义背景色和强调色
        database.saveSetting("CustomBackground", customBackground.toString())
        database.saveSetting("CustomAccent", customAccent.toString())
    }
    
    // 边缘调整大小（8个方向）
    MouseArea { height: 8; anchors { top: parent.top; left: parent.left; right: parent.right }
        cursorShape: Qt.SizeVerCursor; z: 100
        onPressed: function(mouse) { if (mouse.button === Qt.LeftButton) window.startSystemResize(Qt.TopEdge) }
    }
    MouseArea { height: 8; anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
        cursorShape: Qt.SizeVerCursor; z: 100
        onPressed: function(mouse) { if (mouse.button === Qt.LeftButton) window.startSystemResize(Qt.BottomEdge) }
    }
    MouseArea { width: 8; anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
        cursorShape: Qt.SizeHorCursor; z: 100
        onPressed: function(mouse) { if (mouse.button === Qt.LeftButton) window.startSystemResize(Qt.LeftEdge) }
    }
    
    // 导入进度对话框
    Dialog {
        id: importProgressDialog
        title: "导入图片进度"
        width: 600
        height: 200
        modal: true
        anchors.centerIn: parent
        closePolicy: Popup.NoAutoClose
        standardButtons: Dialog.NoButton
        
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 20
            
            // 导入信息显示
            ColumnLayout {
                spacing: 10
                
                Text {
                    id: currentFolderText
                    text: "正在导入到分组: 准备中..."
                    color: Universal.foreground
                    font.pointSize: 12
                    horizontalAlignment: Text.AlignHCenter
                    Layout.fillWidth: true
                }
                
                Text {
                    id: currentImageText
                    text: "正在导入: 准备中..."
                    color: Universal.foreground
                    font.pointSize: 12
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideMiddle
                    Layout.fillWidth: true
                }
            }
            
            // 导入图片进度条
            ProgressBar {
                id: importProgressBar
                Layout.fillWidth: true
                Layout.preferredHeight: 30
                from: 0
                to: 100
                value: 0
                
                // 添加进度条动画
                Behavior on value {
                    NumberAnimation {
                        duration: 300
                        easing.type: Easing.OutQuad
                    }
                }
                
                background: Rectangle {
                    color: window.customBackground
                    border.color: window.customAccent
                    border.width: 1
                    radius: 6
                    
                    // 进度填充
                    Rectangle {
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: parent.width * (importProgressBar.value / 100)
                        color: window.customAccent
                        radius: 5
                    }
                    
                    // 进度文本
                    Text {
                        id: progressText
                        anchors.centerIn: parent
                        text: "导入图片: 0/0 (0%)"
                        color: Universal.foreground
                        font.pointSize: 11
                        z: 1
                    }
                }
                
                // 移除自定义contentItem，使用默认的contentItem但设置为透明
                contentItem: Rectangle {
                    color: "transparent"
                }
            }
        }
    }
    
    // 导出进度对话框
    Dialog {
        id: exportProgressDialog
        title: "导出图片进度"
        width: 600
        height: 200
        modal: true
        anchors.centerIn: parent
        closePolicy: Popup.NoAutoClose
        standardButtons: Dialog.NoButton
        
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 20
            
            // 导出信息显示
            ColumnLayout {
                spacing: 10
                
                Text {
                    id: currentExportFolderText
                    text: "正在导出到: 准备中..."
                    color: Universal.foreground
                    font.pointSize: 12
                    horizontalAlignment: Text.AlignHCenter
                    Layout.fillWidth: true
                }
                
                Text {
                    id: currentExportImageText
                    text: "正在导出: 准备中..."
                    color: Universal.foreground
                    font.pointSize: 12
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideMiddle
                    Layout.fillWidth: true
                }
            }
            
            // 导出图片进度条
            ProgressBar {
                id: exportProgressBar
                Layout.fillWidth: true
                Layout.preferredHeight: 30
                from: 0
                to: 100
                value: 0
                
                // 添加进度条动画
                Behavior on value {
                    NumberAnimation {
                        duration: 300
                        easing.type: Easing.OutQuad
                    }
                }
                
                background: Rectangle {
                    color: window.customBackground
                    border.color: window.customAccent
                    border.width: 1
                    radius: 6
                    
                    // 进度填充
                    Rectangle {
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: parent.width * (exportProgressBar.value / 100)
                        color: window.customAccent
                        radius: 5
                    }
                    
                    // 进度文本
                    Text {
                        id: exportProgressText
                        anchors.centerIn: parent
                        text: "导出图片: 0/0 (0%)"
                        color: Universal.foreground
                        font.pointSize: 11
                        z: 1
                    }
                }
                
                // 移除自定义contentItem，使用默认的contentItem但设置为透明
                contentItem: Rectangle {
                    color: "transparent"
                }
            }
        }
    }
    
    
    
    // 连接database的异步导入和导出信号
    Connections {
        target: database
        
        // 处理导入进度更新
        function onImportProgress(current, total, currentFile, currentFolder) {
            let progress = (current / total) * 100
            importProgressBar.value = progress
            progressText.text = "导入图片: " + current + "/" + total + " (" + Math.round(progress) + "%)"
            currentImageText.text = "正在导入: " + currentFile
            currentFolderText.text = "正在导入到分组: " + currentFolder
        }
        
        // 处理导入完成
        function onImportFinished(success, importedCount, totalCount) {
            importProgressDialog.close()
            console.log("图片导入完成，共导入" + importedCount + "/" + totalCount + "张图片")
            
            // 重置进度条值，确保下次打开时没有回退动画
            importProgressBar.value = 0
            progressText.text = "导入图片: 0/0 (0%)"
            currentImageText.text = "正在导入: 准备中..."
            currentFolderText.text = "正在导入到分组: 准备中..."
            
            // 首先，确保分组树已经完全加载
            groupTree.loadGroups();
        }
        
        // 处理导入错误
        function onImportError(error) {
            console.error("导入错误: " + error)
            importProgressDialog.close()
            
            // 重置进度条值，确保下次打开时没有回退动画
            importProgressBar.value = 0
            progressText.text = "导入图片: 0/0 (0%)"
            currentImageText.text = "正在导入: 准备中..."
            currentFolderText.text = "正在导入到分组: 准备中..."
        }
        
        // 处理导出进度更新
        function onExportProgress(current, total, currentFile, targetFolder) {
            let progress = (current / total) * 100
            exportProgressBar.value = progress
            exportProgressText.text = "导出图片: " + current + "/" + total + " (" + Math.round(progress) + "%)"
            currentExportImageText.text = "正在导出: " + currentFile
            currentExportFolderText.text = "正在导出到: " + targetFolder
        }
        
        // 处理导出完成
        function onExportFinished(success, exportedCount, totalCount, targetFolder) {
            exportProgressDialog.close()
            
            // 重置进度条值，确保下次打开时没有回退动画
            exportProgressBar.value = 0
            exportProgressText.text = "导出图片: 0/0 (0%)"
            currentExportImageText.text = "正在导出: 准备中..."
            currentExportFolderText.text = "正在导出到: 准备中..."
            
            // 显示导出完成提示
            showInfoDialog("导出完成", "成功导出 " + exportedCount + "/" + totalCount + " 张图片到文件夹: " + targetFolder)
        }
        
        // 处理导出错误
        function onExportError(error) {
            console.error("导出错误: " + error)
            exportProgressDialog.close()
            
            // 重置进度条值，确保下次打开时没有回退动画
            exportProgressBar.value = 0
            exportProgressText.text = "导出图片: 0/0 (0%)"
            currentExportImageText.text = "正在导出: 准备中..."
            currentExportFolderText.text = "正在导出到: 准备中..."
            
            // 显示导出错误提示
            showInfoDialog("导出错误", "导出过程中发生错误: " + error)
        }
    }
    MouseArea { width: 8; anchors { right: parent.right; top: parent.top; bottom: parent.bottom }
        cursorShape: Qt.SizeHorCursor; z: 100
        onPressed: function(mouse) { if (mouse.button === Qt.LeftButton) window.startSystemResize(Qt.RightEdge) }
    }
    MouseArea { width: 8; height: 8; anchors { top: parent.top; left: parent.left }
        cursorShape: Qt.SizeFDiagCursor; z: 100
        onPressed: function(mouse) { if (mouse.button === Qt.LeftButton) window.startSystemResize(Qt.TopEdge | Qt.LeftEdge) }
    }
    MouseArea { width: 8; height: 8; anchors { top: parent.top; right: parent.right }
        cursorShape: Qt.SizeBDiagCursor; z: 100
        onPressed: function(mouse) { if (mouse.button === Qt.LeftButton) window.startSystemResize(Qt.TopEdge | Qt.RightEdge) }
    }
    MouseArea { width: 8; height: 8; anchors { bottom: parent.bottom; left: parent.left }
        cursorShape: Qt.SizeBDiagCursor; z: 100
        onPressed: function(mouse) { if (mouse.button === Qt.LeftButton) window.startSystemResize(Qt.BottomEdge | Qt.LeftEdge) }
    }
    MouseArea { width: 8; height: 8; anchors { bottom: parent.bottom; right: parent.right }
        cursorShape: Qt.SizeFDiagCursor; z: 100
        onPressed: function(mouse) { if (mouse.button === Qt.LeftButton) window.startSystemResize(Qt.BottomEdge | Qt.RightEdge) }
    }
    
    // 主内容容器 - 实现圆角效果
    Rectangle {
        anchors.fill: parent
        color: Universal.theme === Universal.Dark ? window.customBackground : window.customAccent
        border.color: window.customAccent
        border.width: 1
        
        // 🔑 设置圆角
        radius: 12
        
        // 标题栏
        Rectangle {
            id: customTitleBar
            height: 36
            color: window.customBackground
            anchors { top: parent.top; left: parent.left; right: parent.right }
            anchors.topMargin: 1
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            anchors.bottomMargin: 0
            
            RowLayout {
                anchors.fill: parent; anchors.margins: 8
                
                // 左侧：窗口标题
                Text {
                    text: window.title; color: (0.299 * window.customBackground.r + 0.587 * window.customBackground.g + 0.114 * window.customBackground.b) > 0.5 ? "#000000" : "#FFFFFF"
                    font.pointSize: 11; font.bold: true
                    verticalAlignment: Text.AlignVCenter
                }

                // 自适应宽度的分隔符
                TitleBarSeparator {}

                // 第一段：分组完整路径
                Text {
                    text: window.groupPath; color: (0.299 * window.customBackground.r + 0.587 * window.customBackground.g + 0.114 * window.customBackground.b) > 0.5 ? "#000000" : "#FFFFFF"
                    font.pointSize: 10
                    verticalAlignment: Text.AlignVCenter
                    elide: Text.ElideMiddle
                    Layout.maximumWidth: parent.width * 0.3
                }

                // 自适应宽度的分隔符
                TitleBarSeparator {}

                // 第二段：当前分组图片数量
                Text {
                    text: "图片数量: " + window.imageCount; color: (0.299 * window.customBackground.r + 0.587 * window.customBackground.g + 0.114 * window.customBackground.b) > 0.5 ? "#000000" : "#FFFFFF"
                    font.pointSize: 10
                    verticalAlignment: Text.AlignVCenter
                }

                // 自适应宽度的分隔符
                TitleBarSeparator {}

                // 第三段：当前图片详细信息
                Text {
                    text: window.currentImageInfo; color: (0.299 * window.customBackground.r + 0.587 * window.customBackground.g + 0.114 * window.customBackground.b) > 0.5 ? "#000000" : "#FFFFFF"
                    font.pointSize: 10
                    verticalAlignment: Text.AlignVCenter
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
                
                // 右侧：窗口控制按钮
                RowLayout {
                    Layout.alignment: Qt.AlignRight; spacing: 4
                    
                    Rectangle {
                        id: minButton
                        width: 28; height: 28; radius: 6; color: "transparent"
                        Text { text: "—"; color: (0.299 * window.customBackground.r + 0.587 * window.customBackground.g + 0.114 * window.customBackground.b) > 0.5 ? "#000000" : "#FFFFFF"; font.pointSize: 12; anchors.centerIn: parent }
                        
                        MouseArea {
                            anchors.fill: parent; hoverEnabled: true
                            onEntered: minButton.color = window.customAccent
                            onExited: minButton.color = "transparent"
                            onClicked: window.visibility = Window.Minimized
                        }
                    }
                    
                    Rectangle {
                        id: maxButton
                        width: 28; height: 28; radius: 6; color: "transparent"
                        Text { id: maxIcon; text: "□"; color: (0.299 * window.customBackground.r + 0.587 * window.customBackground.g + 0.114 * window.customBackground.b) > 0.5 ? "#000000" : "#FFFFFF"; font.pointSize: 12; anchors.centerIn: parent }
                        
                        MouseArea {
                            anchors.fill: parent; hoverEnabled: true
                            onEntered: maxButton.color = window.customAccent
                            onExited: maxButton.color = "transparent"
                            onClicked: window.visibility = window.visibility === Window.Maximized ? Window.Windowed : Window.Maximized
                        }
                    }
                    
                    Rectangle {
                        id: closeButton
                        width: 28; height: 28; radius: 6; color: "transparent"
                        Text { text: "✕"; color: (0.299 * window.customBackground.r + 0.587 * window.customBackground.g + 0.114 * window.customBackground.b) > 0.5 ? "#000000" : "#FFFFFF"; font.pointSize: 12; font.bold: true; anchors.centerIn: parent }
                        
                        MouseArea {
                            anchors.fill: parent; hoverEnabled: true
                            onEntered: closeButton.color = "#E81123"
                            onExited: closeButton.color = "transparent"
                            onClicked: Qt.quit()
                        }
                    }
                }
            }
            
            MouseArea {
                width: parent.width - 90; height: parent.height; anchors.left: parent.left
                acceptedButtons: Qt.LeftButton | Qt.RightButton; z: 2
                
                onPressed: function(mouse) {
                    if (mouse.button === Qt.LeftButton) window.startSystemMove()
                    else if (mouse.button === Qt.RightButton) window.startSystemMenu()
                }
                onDoubleClicked: window.visibility = window.visibility === Window.Maximized ? Window.Windowed : Window.Maximized
            }
        }
        
        // 工具栏
        Frame {
            id: toolbar
            anchors.top: customTitleBar.bottom
            anchors.left: parent.left; anchors.right: parent.right
            anchors.topMargin: 1
            anchors.leftMargin: 8
            anchors.rightMargin: 8
            anchors.bottomMargin: 1
            width: parent.width - 2 * 10
            height: 38
            padding: 0
            background: Rectangle {
                color: window.customBackground
                border.width: 0
            }
            
            RowLayout {
                anchors { fill: parent; leftMargin: 8; rightMargin: 8; topMargin: 0; bottomMargin: 0 }
                spacing: 10
                
                // 颜色选择按钮
                RowLayout {
                    spacing: 8
                    
                    // 背景色选择按钮
                    ThemeColorButton {
                        text: "背景色"
                        bgColor: customBackground
                        onClicked: backgroundColorDialog.open()
                    }

                    // 强调色选择按钮
                    ThemeColorButton {
                        text: "强调色"
                        onClicked: accentColorDialog.open()
                    }

                    // 预设主题颜色ComboBox
                    StyledComboBox {
                        id: themeComboBox
                        Layout.preferredWidth: 120
                        placeholderText: "预设主题"
                        model: [
                            "紫色调",
                            "粉色调",
                            "棕色调",
                            "深绿色调",
                            "浅色调",
                            "深蓝色调"
                        ]
                        currentIndex: -1

                        onCurrentIndexChanged: {
                            if (currentIndex >= 0) {
                                switch(currentIndex) {
                                    case 0: // 紫色调
                                        customBackground = "#181925"
                                        customAccent = "#645a87"
                                        break
                                    case 1: // 粉色调
                                        customBackground = "#25181e"
                                        customAccent = "#875a6e"
                                        break
                                    case 2: // 棕色调
                                        customBackground = "#3a2b26"
                                        customAccent = "#937960"
                                        break
                                    case 3: // 深绿色调
                                        customBackground = "#1e6d72"
                                        customAccent = "#6cb1af"
                                        break
                                    case 4: // 浅色调
                                        customBackground = "#cdcdd8"
                                        customAccent = "#445870"
                                        break
                                    case 5: // 深蓝色调
                                        customBackground = "#0d1a28"
                                        customAccent = "#30638f"
                                        break
                                }
                                // 重置selectedIndex为-1，以便可以再次选择同一主题
                                themeComboBox.currentIndex = -1
                            }
                        }
                    }
                }
                
                Item { Layout.fillWidth: true }

                StyledComboBox {
                    id: transitionComboBox
                    Layout.preferredWidth: 200
                    Layout.alignment: Qt.AlignVCenter
                    model: ["随机",
                           // 普通过渡效果（0-25）
                           "淡入淡出", "向左滑动", "向右滑动", "缩放", "淡入淡出+缩放",
                           "向左旋转90°", "向右旋转90°", "向左旋转180°", "向右旋转180°", "上滑下滑", "下滑上滑",
                           "左下向右上", "右上向左下", "左上向右下", "右下向左上", "翻转", "反向翻转", "上下翻转", "上翻转", "缩放过渡", "对角线翻转", "反向对角线翻转", "顶端X轴翻转", "底端X轴翻转", "左侧Y轴翻转", "右侧Y轴翻转",
                           // 着色器过渡效果（26-55）
                           "溶解（着色器）", "马赛克（着色器）", "水波扭曲（着色器）", "从左向右擦除（着色器）", "从右向左擦除（着色器）",
                           "从上向下擦除（着色器）", "从下向上擦除（着色器）", "X轴窗帘（着色器）", "Y轴窗帘（着色器）", "故障艺术（着色器）",
                           "旋转效果（着色器）", "拉伸效果（着色器）", "百叶窗效果（着色器）", "扭曲呼吸（着色器）", "涟漪扩散（着色器）",
                           "鱼眼（着色器）", "切片（着色器）", "反色（着色器）", "模糊渐变（着色器）", "破碎（着色器）",
                           "雷达扫描（着色器）", "万花筒（着色器）", "火焰燃烧（着色器）", "水墨晕染（着色器）",
                           "粒子爆炸（着色器）", "极光流动（着色器）", "赛博朋克故障（着色器）", "黑洞吞噬（着色器）",
                           "全息投影（着色器）", "光速穿越（着色器）"]
                    currentIndex: 0

                    popup {
                        height: 380
                    }

                    onCurrentIndexChanged: {
                        if (currentIndex === 0) {
                            // 随机模式
                            imageViewer.transitionType = -1
                        } else {
                            // 所有过渡效果（包括普通和着色器）：transitionType = currentIndex - 1
                            // 普通过渡：1-26 → 0-25
                            // 着色器过渡：27-56 → 26-55
                            imageViewer.transitionType = currentIndex - 1
                        }
                    }
                }
                
                StyledComboBox {
                    id: durationComboBox
                    Layout.preferredWidth: 120
                    Layout.alignment: Qt.AlignVCenter
                    model: ["无过渡", "0.5秒", "1秒", "2秒", "3秒", "4秒", "5秒", "6秒", "7秒", "8秒"]
                    currentIndex: 2

                    onCurrentIndexChanged: {
                        var durationValues = [0, 500, 1000, 2000, 3000, 4000, 5000, 6000, 7000, 8000]
                        imageViewer.transitionDuration = durationValues[currentIndex]
                    }
                }
                
                ThemeColorButton {
                    id: importButton
                    text: qsTr("导入图片")
                    Layout.preferredWidth: 100
                    Layout.preferredHeight: 28
                    onClicked: importImages()
                }
            }
        }
        
        // 重新实现可拖拽分隔条：使用基本的SplitView组件
        SplitView {
            id: splitView
            anchors.top: toolbar.bottom
            anchors.bottom: parent.bottom
            anchors.left: parent.left; anchors.right: parent.right
            anchors.topMargin: 1
            anchors.leftMargin: 8
            anchors.rightMargin: 8
            anchors.bottomMargin: 8
            width: parent.width - 2 * 8
            orientation: Qt.Horizontal
            
            // 自定义分隔条样式，匹配主题
            handle: Rectangle {
                implicitWidth: 6
                color: customBackground
                
                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.SizeHorCursor
                    
                    onEntered: parent.color = window.customAccent
                    onExited: parent.color = window.customBackground
                }
            }
            
            // 左侧面板：分组树
            Rectangle {
                id: groupTreeContainer
                SplitView.minimumWidth: 200
                SplitView.preferredWidth: 200
                SplitView.maximumWidth: 600
                color: window.customBackground
                border.color: window.customAccent
                border.width: 0
                
                // 使用GroupTree组件实现分组树
                GroupTree {
                    id: groupTree
                    anchors.fill: parent
                    customBackground: window.customBackground
                    customAccent: window.customAccent
                    
                    // 处理分组选择信号
                    onGroupSelected: {
                        // 保存当前选中的分组ID
                        currentGroupId = groupId
                        console.log("Group selected: " + groupId)
                        
                        // 更新标题栏信息
                        groupPath = getFullGroupPath(groupId)
                        console.log("Updated group path: " + groupPath)
                        
                        imageCount = updateImageCount(groupId)
                        console.log("Updated image count: " + imageCount)
                        
                        // 选择分组后刷新图片列表，只显示该分组下的图片
                        // 注意：loadImages函数会自动选中第一张图片并发送imageSelected信号
                        // imageSelected信号处理函数会更新currentImageInfo，所以这里不需要清空
                        imageList.loadImages(groupId)
                    }
                    
                    // 分组树加载完成后初始化标题栏信息
                    Component.onCompleted: {
                        initializeTitleBarInfo()
                    }
                    
                    // 处理右键点击信号
                    onGroupRightClicked: {
                        // 保存上下文信息
                        contextMenuGroupId = groupId
                        contextMenuGroupName = groupName
                        // 显示右键菜单
                        groupContextMenu.popup()
                    }
                }

            }
            
            // 中间面板：图片列表
            Rectangle {
                id: imageListContainer
                SplitView.minimumWidth: 200
                SplitView.preferredWidth: 200
                SplitView.maximumWidth: 800
                color: window.customBackground
                border.color: window.customAccent
                border.width: 0
                
                ImageList {
                    id: imageList
                    anchors.fill: parent
                    anchors.margins: 1
                    customBackground: window.customBackground
                    customAccent: window.customAccent
                    onImageSelected: function(imageId) {
                        imageViewer.loadImage(imageId)
                        // 更新标题栏当前图片信息
                        currentImageInfo = getCurrentImageInfo(imageId)
                    }
                    onImageRightClicked: function(imageId, filename, action) {
                        if (action === "rename") {
                            // 打开重命名对话框，设置为图片模式
                            renameDialog.title = "重命名图片文件"
                            renameDialog.selectedGroupId = imageId // 复用selectedGroupId存储图片ID
                            renameDialog.initialText = filename // 设置初始文本
                            renameDialog.isForImage = true // 添加图片模式标识
                            renameDialog.open()
                        } else if (action === "delete") {
                            // 打开删除确认对话框
                            confirmDeleteDialog.deleteType = "image"
                            confirmDeleteDialog.itemId = imageId
                            confirmDeleteDialog.itemName = filename
                            confirmDeleteDialog.open()
                        } else if (action === "move") {
                            // 打开分组对话框，设置为图片调整模式
                            groupDialog.dialogMode = "moveImage"
                            groupDialog.imageToMoveId = imageId
                            groupDialog.open()
                        }
                    }
                }
            }
            
            // 右侧面板：图片查看器
            Rectangle {
                SplitView.fillWidth: true
                color: window.customBackground
                border.color: window.customAccent
                border.width: 0
                
                ImageViewer {
                    id: imageViewer
                    anchors.fill: parent
                    anchors.margins: 1
                    customBackground: window.customBackground
                    customAccent: window.customAccent
                }
            }
        }
    }
    
    // 通用分组选择对话框
    Dialog {
        id: groupDialog
        title: dialogMode === "moveGroup" ? "调整分组到目标分组" : dialogMode === "moveImage" ? "调整图片到指定分组" : "选择或创建分组"
        width: 480
        height: 500 // 调整为更紧凑的尺寸
        modal: true
        anchors.centerIn: parent
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutsideOfArea
        standardButtons: Dialog.Ok | Dialog.Cancel

        // 基础属性
        property int selectedGroupId: -1
        property int selectedParentGroupId: -1
        property string dialogMode: "import" // "import"、"moveGroup"或"moveImage"

        // 导入图片相关属性
        property var selectedFiles: []

        // 调整分组相关属性
        property int groupToMoveId: -1 // 要调整的分组ID
        property int imageToMoveId: -1 // 要调整的图片ID
        
        ColumnLayout {
            anchors.fill: parent
            spacing: 10
            
            // 使用GroupTree组件代替ListView
            GroupTree {
                id: dialogGroupTree
                Layout.fillWidth: true
                Layout.fillHeight: true // 让GroupTree填充剩余的高度
                customBackground: window.customBackground
                customAccent: window.customAccent
                
                onGroupSelected: {
                    groupDialog.selectedGroupId = groupId;
                    groupDialog.selectedParentGroupId = groupId;
                    console.log("Selected group in dialog: " + groupId);
                }
            }
            
            // 新建分组输入框和按钮的水平容器
            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 28
                spacing: 10
                
                // 新建分组输入框
                StyledTextField {
                    id: groupNameInput
                    placeholderText: "输入分组名称"
                    Layout.fillWidth: true
                }
                
                // 新建分组按钮
                ThemeColorButton {
                    text: "新建分组"
                    Layout.preferredHeight: 28
                    Layout.preferredWidth: 100

                    onClicked: {
                        let groupName = groupNameInput.text.trim()
                        if (groupName === "") {
                            // 提示用户输入分组名称
                            console.log("请输入分组名称")
                            return
                        }
                        
                        let parentId = groupDialog.selectedParentGroupId
                        // 处理根分组和子分组的创建逻辑
                        if (parentId === 0) {
                            // 选择了"根分组"选项，创建新的根分组（parent_id=0）
                            console.log("Creating root group: " + groupName)
                            parentId = 0
                        } else if (parentId === -1) {
                            // 没有选择分组或选择了"未分组"，默认创建根分组
                            console.log("Creating root group by default: " + groupName)
                            parentId = 0
                        } else {
                            // 选择了其他分组，创建该分组下的子分组
                            console.log("Creating subgroup: " + groupName + " under parent group ID: " + parentId)
                        }
                        
                        // 调用createGroup函数，传入选中的分组ID作为父分组ID
                        let success = database.createGroup(groupName, parentId)
                        if (success) {
                            console.log("Group created successfully")
                            // 刷新GroupTree
                            dialogGroupTree.loadGroups()
                            // 清空输入框
                            groupNameInput.text = ""
                        } else {
                            console.log("Failed to create group: " + database.getLastError())
                        }
                    }
                }
            }
        }
        
        // 使用默认的标准按钮，移除自定义按钮区域
        
        // 对话框打开时刷新分组树数据
        onOpened: {
            dialogGroupTree.loadGroups()
            console.log("=== Group dialog opened, refreshed group tree ===")
        }
        
        onAccepted: {
            // 确保selectedGroupId有效
            if (groupDialog.selectedGroupId === -1) {
                groupDialog.selectedGroupId = -1 // 未分组
            }
            
            // 根据不同模式执行不同逻辑
            switch (groupDialog.dialogMode) {
                case "moveGroup":
                case "moveImage":
                    handleMoveGroup()
                    break
                case "import":
                    handleImportImages()
                    break
                default:
                    console.error("Unknown dialog mode: " + groupDialog.dialogMode)
            }
        }
        
        // 处理调整分组到目标分组
        function handleMoveGroup() {
            if (groupDialog.dialogMode === "moveImage") {
                // 调整图片分组
                let imageToMove = groupDialog.imageToMoveId
                let targetGroup = groupDialog.selectedGroupId
                
                console.log("=== Move image called: " + imageToMove + " -> " + targetGroup)
                
                // 1. 验证参数有效性
                if (imageToMove === -1) {
                    console.error("Invalid image to move: " + imageToMove)
                    return
                }
                
                // 2. 如果选择了"未分组"，将其设置为-1
                if (targetGroup === -1) {
                    console.log("=== Changed target group from -1 to -1 (ungrouped) ===")
                }
                
                // 3. 执行图片分组调整
                database.updateImageGroup(imageToMove, targetGroup)
                // 4. 重新加载图片列表
                imageList.loadImages()
                console.log("=== Image move completed: " + imageToMove + " -> " + targetGroup + " ===")
            } else {
                // 调整分组
                let groupToMove = groupDialog.groupToMoveId
                let targetGroup = groupDialog.selectedGroupId
                
                console.log("=== Move group called: " + groupToMove + " -> " + targetGroup)
                
                // 1. 验证参数有效性
                if (groupToMove === -1) {
                    console.error("Invalid group to move: " + groupToMove)
                    return
                }
                
                // 2. 禁止将分组调整到自己
                if (groupToMove === targetGroup) {
                    console.error("Cannot move group to itself: " + groupToMove)
                    return
                }
                
                // 3. 如果选择了未分组，将其调整为根分组（parent_id=0）
                if (targetGroup === -1) {
                    targetGroup = 0
                    console.log("=== Changed target group from -1 to 0 (root group) ===")
                }
                
                // 4. 执行分组调整
                database.updateGroupParent(groupToMove, targetGroup)
                // 5. 重新加载分组数据
                groupTree.loadGroups()
                console.log("=== Group move completed: " + groupToMove + " -> " + targetGroup + " ===")
            }
        }
        
        // 处理导入图片
        function handleImportImages() {
            let selectedFiles = groupDialog.selectedFiles
            let totalFiles = selectedFiles.length
            let parentGroupId = groupDialog.selectedGroupId
            
            console.log("=== 开始异步导入图片 ===")
            console.log("总文件数: " + totalFiles)
            console.log("选择的父分组ID: " + parentGroupId)
            
            // 重置进度条值
            importProgressBar.value = 0
            // 重置进度文本
            progressText.text = "导入图片: 0/0 (0%)"
            currentImageText.text = "正在导入: 准备中..."
            currentFolderText.text = "正在导入到分组: 准备中..."
            
            // 显示进度对话框
            importProgressDialog.open()
            
            // 使用database的异步导入方法
            database.startAsyncImport(selectedFiles, parentGroupId)
            console.log("异步导入已启动")
        }
    }

    // 右键菜单
    Menu {
        id: groupContextMenu
        // 使用默认位置，或者从事件中获取位置
        
        MenuItem {
            text: "重命名分组"
            onClicked: {
                renameDialog.title = "重命名分组"
                renameDialog.selectedGroupId = contextMenuGroupId
                renameDialog.initialText = contextMenuGroupName
                renameDialog.isForImage = false // 明确设置为分组模式
                renameDialog.open()
            }
        }
        
        MenuItem {
            text: "删除分组"
            onClicked: {
                // 显示确认删除对话框
                confirmDeleteDialog.deleteType = "group"
                confirmDeleteDialog.itemId = contextMenuGroupId
                confirmDeleteDialog.itemName = contextMenuGroupName
                confirmDeleteDialog.open()
            }
        }
        
        MenuItem {
            text: "调整分组到目标分组"
            onClicked: {
                // 设置对话框模式为移动分组
                groupDialog.dialogMode = "moveGroup"
                groupDialog.groupToMoveId = contextMenuGroupId
                groupDialog.open()
            }
        }
        
        MenuItem {
            text: "将分组内的图片导出"
            onClicked: {
                // 实现分组内图片导出功能
                var imageCount = database.getImageCountForGroup(contextMenuGroupId);
                if (imageCount > 0) {
                    // 弹出文件夹选择对话框
                    exportFolderDialog.open();
                }
            }
        }
    }
    
    // 重命名对话框 - 使用标准Dialog组件
    Dialog {
        id: renameDialog
        title: "重命名分组"
        modal: true
        anchors.centerIn: parent
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutsideOfArea
        standardButtons: Dialog.Ok | Dialog.Cancel
        
        // 对话框属性
        property string newName: ""
        property int selectedGroupId: -1
        property bool isForImage: false
        property string initialText: ""
        
        onOpened: {
            // 打开对话框时，重置输入框内容
            renameTextField.text = initialText
            // 确保输入框获得焦点
            Qt.callLater(function() {
                renameTextField.forceActiveFocus()
                renameTextField.selectAll()
            })
        }
        
        onAccepted: {
            if (renameTextField.text.trim() !== "") {
                if (isForImage) {
                    // 调用数据库方法重命名图片
                    database.renameImage(selectedGroupId, renameTextField.text.trim())
                    // 重新加载图片列表 - 传递当前分组ID
                    imageList.loadImages(window.currentGroupId)
                } else {
                    // 调用数据库方法更新分组名称
                    database.updateGroup(selectedGroupId, renameTextField.text.trim())
                    // 重新加载分组数据
                    groupTree.loadGroups()
                }
            }
        }
        
        ColumnLayout {
            spacing: 15
            width: implicitWidth
            height: implicitHeight
            
            // 提示文本
            Text {
                text: isForImage ? "输入新的图片文件名" : "输入新的分组名称"
                color: Universal.foreground
                font.pointSize: 12
                horizontalAlignment: Text.AlignHCenter
                Layout.fillWidth: true
                Layout.minimumWidth: 350
            }
            
            // 输入框
            StyledTextField {
                id: renameTextField
                placeholderText: "输入新名称"
                padding: 8
                Layout.fillWidth: true
                Layout.minimumWidth: 350
            }
        }
    }
    
    // 通用确认删除对话框
    Dialog {
        id: confirmDeleteDialog
        title: deleteType === "group" ? "删除分组确认" : "删除图片确认"
        modal: true
        anchors.centerIn: parent
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutsideOfArea
        standardButtons: Dialog.Ok | Dialog.Cancel
        
        // 对话框属性
        property string deleteType: "group" // "group" 或 "image"
        property int itemId: -1
        property string itemName: ""
        
        // 显示的消息文本
        function getMessage() {
            if (deleteType === "group") {
                // 获取分组的子分组数量和图片数量
                var subgroupCount = database.getSubgroupCount(itemId);
                var imageCount = database.getImageCountForGroup(itemId);
                
                // 构建消息文本
                var msg = "确定要删除分组 \"" + itemName + "\" 吗？\n\n";
                msg += "该分组下包含：\n";
                msg += "- " + subgroupCount + " 个子分组\n";
                msg += "- " + imageCount + " 张图片\n\n";
                msg += "删除后将无法恢复！";
                return msg;
            } else {
                return "确定要删除图片 \"" + itemName + "\" 吗？\n\n删除后将无法恢复！";
            }
        }
        
        ColumnLayout {
            // 直接使用默认布局，让Dialog组件自动管理尺寸
            spacing: 15
            width: implicitWidth
            height: implicitHeight
            
            // 消息文本
            Text {
                // 使用函数来获取消息文本
                text: confirmDeleteDialog.getMessage()
                color: Universal.foreground
                font.pointSize: 12
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
                Layout.fillWidth: true
                Layout.minimumWidth: 350
            }
        }
        
        // 确认删除操作
        onAccepted: {
            if (deleteType === "group") {
                // 删除分组
                database.deleteGroup(itemId)
                // 重新加载分组数据
                groupTree.loadGroups()
                // 重新加载图片列表
                imageList.loadImages()
            } else if (deleteType === "image") {
                // 删除图片
                database.removeImage(itemId)
                // 重新加载图片列表
                imageList.loadImages()
            }
        }
    }
    
    // 文件选择对话框
    FileDialog {
        id: fileDialog
        title: "选择图片文件"
        nameFilters: ["图片文件 (*.bmp *.cur *.ico *.jfif *.jpeg *.jpg *.pbm *.pgm *.png *.ppm *.webp *.xbm *.xpm)"]
        fileMode: FileDialog.OpenFiles
        
        onAccepted: {
            // 保存选中的文件
            groupDialog.selectedFiles = fileDialog.selectedFiles
            groupDialog.dialogMode = "import"
            // 打开分组选择对话框
            groupDialog.open()
        }
    }
    
    // 信息对话框
    Dialog {
        id: infoDialog
        title: "提示"
        width: 400
        height: 200
        modal: true
        anchors.centerIn: parent
        standardButtons: Dialog.Ok
        
        Text {
            id: infoDialogText
            text: ""
            color: Universal.foreground
            font.pointSize: 14
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            anchors.fill: parent
            anchors.margins: 20
            wrapMode: Text.WrapAtWordBoundaryOrAnywhere
        }
    }
    
    // 显示信息对话框
    function showInfoDialog(title, message) {
        infoDialog.title = title
        infoDialogText.text = message
        infoDialog.open()
    }
    
    // 导出文件夹选择对话框
    FolderDialog {
        id: exportFolderDialog
        title: "选择导出目标文件夹"
        
        onAccepted: {
            // 实现图片导出逻辑
            var targetFolderUrl = exportFolderDialog.selectedFolder
            // 确保将URL转换为本地文件路径
            var targetFolder = String(targetFolderUrl)
            // 使用replace方法处理URL，确保正确转换为本地文件路径
            targetFolder = targetFolder.replace(/^file:\/\//, "")
            targetFolder = targetFolder.replace(/^\//, "") // 移除多余的斜杠
            var groupId = contextMenuGroupId
            var groupName = contextMenuGroupName
            
            // 打开导出进度对话框
            exportProgressDialog.open()
            
            // 调用异步导出函数
            database.startAsyncExport(groupId, groupName, targetFolder)
        }
    }
    
    function importImages() {
        fileDialog.open();
    }
    
    // 背景色选择对话框
    ColorDialog {
        id: backgroundColorDialog
        title: "选择背景色"
        selectedColor: window.customBackground        
        
        onAccepted: {
            window.customBackground = selectedColor
        }
    }
    
    // 强调色选择对话框
    ColorDialog {
        id: accentColorDialog
        title: "选择强调色"
        selectedColor: window.customAccent        
        
        onAccepted: {
            window.customAccent = selectedColor
        }
    }
}