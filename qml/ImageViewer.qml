// ImageViewer.qml - 保持不变（已经是深色主题）
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
    
    property int currentImageId: -1
    property var currentImage: null
    property int newImageId: -1
    property var nextImage: null
    property int transitionType: -1
    property int transitionDuration: 1000
    property bool transitioning: false
    property real scaleFactor: 1.0
    property real minScale: 0.1
    property real maxScale: 10.0
    property bool isDragging: false
    property point lastMousePos: Qt.point(0, 0)
    property point imageOffset: Qt.point(0, 0)
    
    function loadImage(imageId) {
        if (imageId === currentImageId && !transitioning) return
        if (transitioning && imageId === newImageId) return
        
        // 生成图片URL，使用自定义图片提供器加载原始图片
        var imageUrl = "image://imageprovider/" + imageId + "/original"
        
        if (currentImageId === -1) {
            currentImageId = imageId
            currentImage = imageUrl
            currentImageItem.source = currentImage || ""
            resetTransform()
            return
        }
        
        // 停止所有动画
        fadeAnimation.stop(); slideLeftAnimation.stop(); slideRightAnimation.stop()
        scaleAnimation.stop(); fadeScaleAnimation.stop(); rotateAnimation.stop()
        rotateRightAnimation.stop(); rotateLeft180Animation.stop(); rotateRight180Animation.stop()
        slideUpDownAnimation.stop(); slideDownUpAnimation.stop()
        slideLeftDownToRightUpAnimation.stop(); slideRightUpToLeftDownAnimation.stop()
        slideLeftUpToRightDownAnimation.stop(); slideRightDownToLeftUpAnimation.stop()
        flipAnimation.stop(); flipReverseAnimation.stop(); flipXDownAnimation.stop(); flipXUpAnimation.stop(); flipXTopAnimation.stop(); flipXBottomAnimation.stop()
        scaleTransitionAnimation.stop(); flipDiagonalAnimation.stop(); flipDiagonalReverseAnimation.stop(); flipYLeftAnimation.stop(); flipYRightAnimation.stop()
        
        if (transitioning) endTransition()
        
        if (transitionDuration === 0) {
            currentImageId = imageId
            currentImage = imageUrl
            currentImageItem.source = currentImage || ""
            resetTransform()
            newImageId = -1
            nextImage = null
        } else {
            transitioning = true
            newImageId = imageId
            nextImage = imageUrl
            
            var selectedTransition = transitionType
            if (selectedTransition === -1) selectedTransition = Math.floor(Math.random() * 26)
            
            resetTransform()
            
            currentImageItem.opacity = 1.0; currentImageItem.x = 0; currentImageItem.y = 0
            currentImageItem.scale = 1.0; currentImageItem.rotation = 0
            nextImageItem.x = 0; nextImageItem.y = 0
            nextImageItem.scale = 1.0; nextImageItem.rotation = 0
            
            // 对于随机点过渡效果，需要确保两张图片都可见
            if (selectedTransition === 26) {
                nextImageItem.opacity = 1.0;
                currentImageItem.visible = true;
                nextImageItem.visible = true;
            } else {
                nextImageItem.opacity = 0.0;
            }
            
            currentImageItem.source = currentImage || ""; nextImageItem.source = nextImage || ""
            
            switch(selectedTransition) {
                case 0: fadeAnimation.start(); break
                case 1: slideLeftAnimation.start(); break
                case 2: slideRightAnimation.start(); break
                case 3: scaleAnimation.start(); break
                case 4: fadeScaleAnimation.start(); break
                case 5: rotateAnimation.start(); break
                case 6: rotateRightAnimation.start(); break
                case 7: rotateLeft180Animation.start(); break
                case 8: rotateRight180Animation.start(); break
                case 9: slideUpDownAnimation.start(); break
                case 10: slideDownUpAnimation.start(); break
                case 11: slideLeftDownToRightUpAnimation.start(); break
                case 12: slideRightUpToLeftDownAnimation.start(); break
                case 13: slideLeftUpToRightDownAnimation.start(); break
                case 14: slideRightDownToLeftUpAnimation.start(); break
                case 15: flipAnimation.start(); break
                case 16: flipReverseAnimation.start(); break
                case 17: flipXDownAnimation.start(); break
                case 18: flipXUpAnimation.start(); break
                case 19: scaleTransitionAnimation.start(); break
                case 20: flipDiagonalAnimation.start(); break
                case 21: flipDiagonalReverseAnimation.start(); break
                case 22: flipXTopAnimation.start(); break
                case 23: flipXBottomAnimation.start(); break
                case 24: flipYLeftAnimation.start(); break
                case 25: flipYRightAnimation.start(); break
                default: fadeAnimation.start(); break
            }
        }
    }
    
    function resetTransform() {
        scaleFactor = 1.0; imageOffset = Qt.point(0, 0); isDragging = false
    }
    
    function endTransition() {
        transitioning = false
        currentImageId = newImageId
        currentImage = nextImage
        nextImage = null
        
        resetTransform()
        
        currentImageItem.source = currentImage || ""
        currentImageItem.opacity = 1.0; currentImageItem.rotation = 0
        currentRotation.angle = 0  // 重置Y轴旋转角度
        currentImageItem.x = Qt.binding(function() { return imageOffset.x })
        currentImageItem.y = Qt.binding(function() { return imageOffset.y })
        currentImageItem.scale = Qt.binding(function() { return scaleFactor })
        
        nextImageItem.opacity = 0.0; nextImageItem.rotation = 0
        nextRotation.angle = 0  // 重置Y轴旋转角度
        nextImageItem.x = Qt.binding(function() { return imageOffset.x })
        nextImageItem.y = Qt.binding(function() { return imageOffset.y })
        nextImageItem.scale = Qt.binding(function() { return scaleFactor })
    }
    
    // UI结构 - 背景已在组件顶部定义，包含圆角和边框
    
    // UI结构 - 图片容器
    Item {
        id: imageContainer
        anchors.fill: parent
        clip: true
        
        Image {
            id: currentImageItem
            width: parent.width
            height: parent.height
            source: currentImage || ""
            fillMode: Image.PreserveAspectFit
            opacity: 1.0
            x: imageOffset.x; y: imageOffset.y; scale: scaleFactor
            transformOrigin: Item.Center
            z: 1
            
            // 旋转变换 - 同时支持Y轴和X轴翻转
            transform: [
                Rotation {
                    id: currentRotation
                    origin.x: currentImageItem.width / 2
                    origin.y: currentImageItem.height / 2
                    axis { x: 0; y: 1; z: 0 }  // 默认绕Y轴旋转
                    angle: 0
                }
            ]
        }
        
        Image {
            id: nextImageItem
            width: parent.width
            height: parent.height
            source: nextImage || ""
            fillMode: Image.PreserveAspectFit
            opacity: 0.0
            x: imageOffset.x; y: imageOffset.y; scale: scaleFactor
            transformOrigin: Item.Center
            z: 0
            
            // 旋转变换 - 同时支持Y轴和X轴翻转
            transform: [
                Rotation {
                    id: nextRotation
                    origin.x: nextImageItem.width / 2
                    origin.y: nextImageItem.height / 2
                    axis { x: 0; y: 1; z: 0 }  // 默认绕Y轴旋转
                    angle: 0
                }
            ]
        }
        
        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
            
            onPressed: {
                if (!transitioning) {
                    isDragging = true
                    lastMousePos = Qt.point(mouseX, mouseY)
                    cursorShape = Qt.ClosedHandCursor
                }
            }
            
            onReleased: {
                isDragging = false
                cursorShape = Qt.OpenHandCursor
            }
            
            onPositionChanged: {
                if (isDragging && !transitioning) {
                    var delta = Qt.point(mouseX - lastMousePos.x, mouseY - lastMousePos.y)
                    var newX = imageOffset.x + delta.x
                    var newY = imageOffset.y + delta.y
                    imageOffset = Qt.point(newX, newY)
                    lastMousePos = Qt.point(mouseX, mouseY)
                    
                    var actualImageWidth = currentImageItem.width * currentImageItem.scale
                    var actualImageHeight = currentImageItem.height * currentImageItem.scale
                    var overflowX = actualImageWidth - parent.width
                    var overflowY = actualImageHeight - parent.height
                    
                    if (overflowX > 0) {
                        var minX = -overflowX / 2
                        var maxX = overflowX / 2
                        imageOffset.x = Math.min(maxX, Math.max(minX, imageOffset.x))
                    } else imageOffset.x = 0
                    
                    if (overflowY > 0) {
                        var minY = -overflowY / 2
                        var maxY = overflowY / 2
                        imageOffset.y = Math.min(maxY, Math.max(minY, imageOffset.y))
                    } else imageOffset.y = 0
                }
            }
            
            onWheel: function(event) {
                if (!transitioning) {
                    var scaleDelta = event.angleDelta.y > 0 ? 1.1 : 0.9
                    scaleFactor *= scaleDelta
                    scaleFactor = Math.max(minScale, Math.min(maxScale, scaleFactor))
                    
                    var actualImageWidth = currentImageItem.width * scaleFactor
                    var actualImageHeight = currentImageItem.height * scaleFactor
                    var overflowX = actualImageWidth - parent.width
                    var overflowY = actualImageHeight - parent.height
                    
                    if (overflowX > 0) {
                        var minX = -overflowX / 2
                        var maxX = overflowX / 2
                        imageOffset.x = Math.min(maxX, Math.max(minX, imageOffset.x))
                    } else imageOffset.x = 0
                    
                    if (overflowY > 0) {
                        var minY = -overflowY / 2
                        var maxY = overflowY / 2
                        imageOffset.y = Math.min(maxY, Math.max(minY, imageOffset.y))
                    } else imageOffset.y = 0
                }
                event.accepted = true
            }
        }
    }
    
    // 动画定义
    ParallelAnimation {
        id: fadeAnimation
        NumberAnimation { target: currentImageItem; property: "opacity"; from: 1.0; to: 0.0; duration: transitionDuration; easing.type: Easing.InOutQuad }
        NumberAnimation { target: nextImageItem; property: "opacity"; from: 0.0; to: 1.0; duration: transitionDuration; easing.type: Easing.InOutQuad }
        onRunningChanged: { if (!running && transitioning) endTransition() }
    }
    
    ParallelAnimation {
        id: rotateRightAnimation
        NumberAnimation { target: currentImageItem; property: "rotation"; from: 0; to: 90; duration: transitionDuration; easing.type: Easing.InOutQuad }
        NumberAnimation { target: nextImageItem; property: "rotation"; from: -90; to: 0; duration: transitionDuration; easing.type: Easing.InOutQuad }
        NumberAnimation { target: currentImageItem; property: "opacity"; from: 1.0; to: 0.0; duration: transitionDuration; easing.type: Easing.InOutQuad }
        NumberAnimation { target: nextImageItem; property: "opacity"; from: 0.0; to: 1.0; duration: transitionDuration; easing.type: Easing.InOutQuad }
        onRunningChanged: { if (!running && transitioning) endTransition() }
    }
    
    ParallelAnimation {
        id: rotateLeft180Animation
        NumberAnimation { target: currentImageItem; property: "rotation"; from: 0; to: -180; duration: transitionDuration; easing.type: Easing.InOutQuad }
        NumberAnimation { target: nextImageItem; property: "rotation"; from: 180; to: 0; duration: transitionDuration; easing.type: Easing.InOutQuad }
        NumberAnimation { target: currentImageItem; property: "opacity"; from: 1.0; to: 0.0; duration: transitionDuration; easing.type: Easing.InOutQuad }
        NumberAnimation { target: nextImageItem; property: "opacity"; from: 0.0; to: 1.0; duration: transitionDuration; easing.type: Easing.InOutQuad }
        onRunningChanged: { if (!running && transitioning) endTransition() }
    }
    
    ParallelAnimation {
        id: rotateRight180Animation
        NumberAnimation { target: currentImageItem; property: "rotation"; from: 0; to: 180; duration: transitionDuration; easing.type: Easing.InOutQuad }
        NumberAnimation { target: nextImageItem; property: "rotation"; from: -180; to: 0; duration: transitionDuration; easing.type: Easing.InOutQuad }
        NumberAnimation { target: currentImageItem; property: "opacity"; from: 1.0; to: 0.0; duration: transitionDuration; easing.type: Easing.InOutQuad }
        NumberAnimation { target: nextImageItem; property: "opacity"; from: 0.0; to: 1.0; duration: transitionDuration; easing.type: Easing.InOutQuad }
        onRunningChanged: { if (!running && transitioning) endTransition() }
    }
    
    ParallelAnimation {
        id: rotateAnimation
        NumberAnimation { target: currentImageItem; property: "rotation"; from: 0; to: -90; duration: transitionDuration; easing.type: Easing.InOutQuad }
        NumberAnimation { target: nextImageItem; property: "rotation"; from: 90; to: 0; duration: transitionDuration; easing.type: Easing.InOutQuad }
        NumberAnimation { target: currentImageItem; property: "opacity"; from: 1.0; to: 0.0; duration: transitionDuration; easing.type: Easing.InOutQuad }
        NumberAnimation { target: nextImageItem; property: "opacity"; from: 0.0; to: 1.0; duration: transitionDuration; easing.type: Easing.InOutQuad }
        onRunningChanged: { if (!running && transitioning) endTransition() }
    }
    
    ParallelAnimation {
        id: slideLeftAnimation
        NumberAnimation { target: currentImageItem; property: "x"; from: 0; to: -500; duration: transitionDuration; easing.type: Easing.InOutQuad }
        NumberAnimation { target: nextImageItem; property: "x"; from: 500; to: 0; duration: transitionDuration; easing.type: Easing.InOutQuad }
        NumberAnimation { target: currentImageItem; property: "opacity"; from: 1.0; to: 0.0; duration: transitionDuration; easing.type: Easing.InOutQuad }
        NumberAnimation { target: nextImageItem; property: "opacity"; from: 0.0; to: 1.0; duration: transitionDuration; easing.type: Easing.InOutQuad }
        onRunningChanged: { if (!running && transitioning) endTransition() }
    }
    
    ParallelAnimation {
        id: slideRightAnimation
        NumberAnimation { target: currentImageItem; property: "x"; from: 0; to: 500; duration: transitionDuration; easing.type: Easing.InOutQuad }
        NumberAnimation { target: nextImageItem; property: "x"; from: -500; to: 0; duration: transitionDuration; easing.type: Easing.InOutQuad }
        NumberAnimation { target: currentImageItem; property: "opacity"; from: 1.0; to: 0.0; duration: transitionDuration; easing.type: Easing.InOutQuad }
        NumberAnimation { target: nextImageItem; property: "opacity"; from: 0.0; to: 1.0; duration: transitionDuration; easing.type: Easing.InOutQuad }
        onRunningChanged: { if (!running && transitioning) endTransition() }
    }
    
    ParallelAnimation {
        id: scaleAnimation
        NumberAnimation { target: currentImageItem; property: "scale"; from: 1.0; to: 0.3; duration: transitionDuration; easing.type: Easing.InOutQuad }
        NumberAnimation { target: nextImageItem; property: "scale"; from: 2.0; to: 1.0; duration: transitionDuration; easing.type: Easing.InOutQuad }
        NumberAnimation { target: currentImageItem; property: "opacity"; from: 1.0; to: 0.0; duration: transitionDuration; easing.type: Easing.InOutQuad }
        NumberAnimation { target: nextImageItem; property: "opacity"; from: 0.0; to: 1.0; duration: transitionDuration; easing.type: Easing.InOutQuad }
        onRunningChanged: { if (!running && transitioning) endTransition() }
    }
    
    ParallelAnimation {
        id: fadeScaleAnimation
        NumberAnimation { target: currentImageItem; property: "scale"; from: 1.0; to: 0.9; duration: transitionDuration; easing.type: Easing.InOutQuad }
        NumberAnimation { target: nextImageItem; property: "scale"; from: 1.1; to: 1.0; duration: transitionDuration; easing.type: Easing.InOutQuad }
        NumberAnimation { target: currentImageItem; property: "opacity"; from: 1.0; to: 0.0; duration: transitionDuration; easing.type: Easing.InOutQuad }
        NumberAnimation { target: nextImageItem; property: "opacity"; from: 0.0; to: 1.0; duration: transitionDuration; easing.type: Easing.InOutQuad }
        onRunningChanged: { if (!running && transitioning) endTransition() }
    }
    
    // 上滑淡出，下滑入淡入效果
    ParallelAnimation {
        id: slideUpDownAnimation
        NumberAnimation { target: currentImageItem; property: "y"; from: 0; to: -500; duration: transitionDuration; easing.type: Easing.InOutQuad }
        NumberAnimation { target: nextImageItem; property: "y"; from: 500; to: 0; duration: transitionDuration; easing.type: Easing.InOutQuad }
        NumberAnimation { target: currentImageItem; property: "opacity"; from: 1.0; to: 0.0; duration: transitionDuration; easing.type: Easing.InOutQuad }
        NumberAnimation { target: nextImageItem; property: "opacity"; from: 0.0; to: 1.0; duration: transitionDuration; easing.type: Easing.InOutQuad }
        onRunningChanged: { if (!running && transitioning) endTransition() }
    }
    
    // 下滑淡出，上滑入淡入效果
    ParallelAnimation {
        id: slideDownUpAnimation
        NumberAnimation { target: currentImageItem; property: "y"; from: 0; to: 500; duration: transitionDuration; easing.type: Easing.InOutQuad }
        NumberAnimation { target: nextImageItem; property: "y"; from: -500; to: 0; duration: transitionDuration; easing.type: Easing.InOutQuad }
        NumberAnimation { target: currentImageItem; property: "opacity"; from: 1.0; to: 0.0; duration: transitionDuration; easing.type: Easing.InOutQuad }
        NumberAnimation { target: nextImageItem; property: "opacity"; from: 0.0; to: 1.0; duration: transitionDuration; easing.type: Easing.InOutQuad }
        onRunningChanged: { if (!running && transitioning) endTransition() }
    }
    
    // 左下向右上滑入效果 - 旧图右上滑出，新图右下向左上滑入（缩放+滑动）
    ParallelAnimation {
        id: slideLeftDownToRightUpAnimation
        NumberAnimation { target: nextImageItem; property: "z"; from: 0; to: 2; duration: 1 }
        NumberAnimation { target: currentImageItem; property: "x"; from: 0; to: 500; duration: transitionDuration; easing.type: Easing.InOutQuad }
        NumberAnimation { target: currentImageItem; property: "y"; from: 0; to: -500; duration: transitionDuration; easing.type: Easing.InOutQuad }
        NumberAnimation { target: currentImageItem; property: "scale"; from: 1.0; to: 0.3; duration: transitionDuration; easing.type: Easing.InOutQuad }
        NumberAnimation { target: currentImageItem; property: "opacity"; from: 1.0; to: 0.0; duration: transitionDuration; easing.type: Easing.InOutQuad }
        NumberAnimation { target: nextImageItem; property: "x"; from: 500; to: 0; duration: transitionDuration; easing.type: Easing.InOutQuad }
        NumberAnimation { target: nextImageItem; property: "y"; from: 500; to: 0; duration: transitionDuration; easing.type: Easing.InOutQuad }
        NumberAnimation { target: nextImageItem; property: "scale"; from: 0.3; to: 1.0; duration: transitionDuration; easing.type: Easing.InOutQuad }
        NumberAnimation { target: nextImageItem; property: "opacity"; from: 0.0; to: 1.0; duration: transitionDuration; easing.type: Easing.InOutQuad }
        onRunningChanged: { if (!running && transitioning) endTransition() }
    }
    
    // 右上向左下滑入效果 - 旧图左下滑出，新图左上向右下滑入（缩放+滑动）
    ParallelAnimation {
        id: slideRightUpToLeftDownAnimation
        NumberAnimation { target: nextImageItem; property: "z"; from: 0; to: 2; duration: 1 }
        NumberAnimation { target: currentImageItem; property: "x"; from: 0; to: -500; duration: transitionDuration; easing.type: Easing.InOutQuad }
        NumberAnimation { target: currentImageItem; property: "y"; from: 0; to: 500; duration: transitionDuration; easing.type: Easing.InOutQuad }
        NumberAnimation { target: currentImageItem; property: "scale"; from: 1.0; to: 0.3; duration: transitionDuration; easing.type: Easing.InOutQuad }
        NumberAnimation { target: currentImageItem; property: "opacity"; from: 1.0; to: 0.0; duration: transitionDuration; easing.type: Easing.InOutQuad }
        NumberAnimation { target: nextImageItem; property: "x"; from: -500; to: 0; duration: transitionDuration; easing.type: Easing.InOutQuad }
        NumberAnimation { target: nextImageItem; property: "y"; from: -500; to: 0; duration: transitionDuration; easing.type: Easing.InOutQuad }
        NumberAnimation { target: nextImageItem; property: "scale"; from: 0.3; to: 1.0; duration: transitionDuration; easing.type: Easing.InOutQuad }
        NumberAnimation { target: nextImageItem; property: "opacity"; from: 0.0; to: 1.0; duration: transitionDuration; easing.type: Easing.InOutQuad }
        onRunningChanged: { if (!running && transitioning) endTransition() }
    }
    
    // 左上向右下滑入效果 - 旧图右下滑出，新图左上向右下滑入（缩放+滑动）
    ParallelAnimation {
        id: slideLeftUpToRightDownAnimation
        NumberAnimation { target: nextImageItem; property: "z"; from: 0; to: 2; duration: 1 }
        NumberAnimation { target: currentImageItem; property: "x"; from: 0; to: 500; duration: transitionDuration; easing.type: Easing.InOutQuad }
        NumberAnimation { target: currentImageItem; property: "y"; from: 0; to: 500; duration: transitionDuration; easing.type: Easing.InOutQuad }
        NumberAnimation { target: currentImageItem; property: "scale"; from: 1.0; to: 0.3; duration: transitionDuration; easing.type: Easing.InOutQuad }
        NumberAnimation { target: currentImageItem; property: "opacity"; from: 1.0; to: 0.0; duration: transitionDuration; easing.type: Easing.InOutQuad }
        NumberAnimation { target: nextImageItem; property: "x"; from: -500; to: 0; duration: transitionDuration; easing.type: Easing.InOutQuad }
        NumberAnimation { target: nextImageItem; property: "y"; from: -500; to: 0; duration: transitionDuration; easing.type: Easing.InOutQuad }
        NumberAnimation { target: nextImageItem; property: "scale"; from: 0.3; to: 1.0; duration: transitionDuration; easing.type: Easing.InOutQuad }
        NumberAnimation { target: nextImageItem; property: "opacity"; from: 0.0; to: 1.0; duration: transitionDuration; easing.type: Easing.InOutQuad }
        onRunningChanged: { if (!running && transitioning) endTransition() }
    }
    
    // 右下向左上滑入效果 - 旧图左上滑出，新图右下向左上滑入（缩放+滑动）
    ParallelAnimation {
        id: slideRightDownToLeftUpAnimation
        NumberAnimation { target: nextImageItem; property: "z"; from: 0; to: 2; duration: 1 }
        NumberAnimation { target: currentImageItem; property: "x"; from: 0; to: -500; duration: transitionDuration; easing.type: Easing.InOutQuad }
        NumberAnimation { target: currentImageItem; property: "y"; from: 0; to: -500; duration: transitionDuration; easing.type: Easing.InOutQuad }
        NumberAnimation { target: currentImageItem; property: "scale"; from: 1.0; to: 0.3; duration: transitionDuration; easing.type: Easing.InOutQuad }
        NumberAnimation { target: currentImageItem; property: "opacity"; from: 1.0; to: 0.0; duration: transitionDuration; easing.type: Easing.InOutQuad }
        NumberAnimation { target: nextImageItem; property: "x"; from: 500; to: 0; duration: transitionDuration; easing.type: Easing.InOutQuad }
        NumberAnimation { target: nextImageItem; property: "y"; from: 500; to: 0; duration: transitionDuration; easing.type: Easing.InOutQuad }
        NumberAnimation { target: nextImageItem; property: "scale"; from: 0.3; to: 1.0; duration: transitionDuration; easing.type: Easing.InOutQuad }
        NumberAnimation { target: nextImageItem; property: "opacity"; from: 0.0; to: 1.0; duration: transitionDuration; easing.type: Easing.InOutQuad }
        onRunningChanged: { if (!running && transitioning) endTransition() }
    }
    
    // 翻转动画效果 - 旧图向左翻转出，新图向右翻转入
    SequentialAnimation {
        id: flipAnimation
        
        // 第一阶段：旧图向左翻转90度并淡出
        ParallelAnimation {
            NumberAnimation {
                target: nextImageItem
                property: "z"
                from: 0
                to: 2
                duration: 1
            }
            NumberAnimation {
                target: currentRotation
                property: "angle"
                from: 0
                to: -90
                duration: transitionDuration/2
                easing.type: Easing.InQuad
            }
            NumberAnimation {
                target: currentImageItem
                property: "opacity"
                from: 1.0
                to: 0.0
                duration: transitionDuration/2
                easing.type: Easing.InQuad
            }
        }
        
        // 第二阶段：新图向右翻转90度并淡入，淡入和翻转同步进行
        ParallelAnimation {
            NumberAnimation {
                target: nextImageItem
                property: "opacity"
                from: 0.0
                to: 1.0
                duration: transitionDuration/2
                easing.type: Easing.OutQuad
            }
            NumberAnimation {
                target: nextRotation
                property: "angle"
                from: 90
                to: 0
                duration: transitionDuration/2
                easing.type: Easing.OutQuad
            }
        }
        
        onRunningChanged: { if (!running && transitioning) endTransition() }
    }
    
    // 翻转动画效果（反方向） - 旧图向右翻转出，新图向左翻转入
    SequentialAnimation {
        id: flipReverseAnimation
        
        // 第一阶段：旧图向右翻转90度并淡出
        ParallelAnimation {
            NumberAnimation {
                target: nextImageItem
                property: "z"
                from: 0
                to: 2
                duration: 1
            }
            NumberAnimation {
                target: currentRotation
                property: "angle"
                from: 0
                to: 90
                duration: transitionDuration/2
                easing.type: Easing.InQuad
            }
            NumberAnimation {
                target: currentImageItem
                property: "opacity"
                from: 1.0
                to: 0.0
                duration: transitionDuration/2
                easing.type: Easing.InQuad
            }
        }
        
        // 第二阶段：新图向左翻转90度并淡入，淡入和翻转同步进行
        ParallelAnimation {
            NumberAnimation {
                target: nextImageItem
                property: "opacity"
                from: 0.0
                to: 1.0
                duration: transitionDuration/2
                easing.type: Easing.OutQuad
            }
            NumberAnimation {
                target: nextRotation
                property: "angle"
                from: -90
                to: 0
                duration: transitionDuration/2
                easing.type: Easing.OutQuad
            }
        }
        
        onRunningChanged: { if (!running && transitioning) endTransition() }
    }
    
    // X轴翻转动画效果 - 旧图向上翻转出，新图向下翻转入
    SequentialAnimation {
        id: flipXDownAnimation
        
        // 第一阶段：旧图向上翻转90度并淡出
        ParallelAnimation {
            NumberAnimation {
                target: nextImageItem
                property: "z"
                from: 0
                to: 2
                duration: 1
            }
            ScriptAction {
                script: {
                    // 设置绕X轴旋转
                    currentRotation.axis.x = 1;
                    currentRotation.axis.y = 0;
                    currentRotation.axis.z = 0;
                }
            }
            NumberAnimation {
                target: currentRotation
                property: "angle"
                from: 0
                to: -90
                duration: transitionDuration/2
                easing.type: Easing.InQuad
            }
            NumberAnimation {
                target: currentImageItem
                property: "opacity"
                from: 1.0
                to: 0.0
                duration: transitionDuration/2
                easing.type: Easing.InQuad
            }
        }
        
        // 第二阶段：新图向下翻转90度并淡入，淡入和翻转同步进行
        ParallelAnimation {
            ScriptAction {
                script: {
                    // 设置绕X轴旋转
                    nextRotation.axis.x = 1;
                    nextRotation.axis.y = 0;
                    nextRotation.axis.z = 0;
                }
            }
            NumberAnimation {
                target: nextImageItem
                property: "opacity"
                from: 0.0
                to: 1.0
                duration: transitionDuration/2
                easing.type: Easing.OutQuad
            }
            NumberAnimation {
                target: nextRotation
                property: "angle"
                from: 90
                to: 0
                duration: transitionDuration/2
                easing.type: Easing.OutQuad
            }
        }
        
        onRunningChanged: {
            if (!running && transitioning) {
                // 恢复默认绕Y轴旋转
                currentRotation.axis.x = 0;
                currentRotation.axis.y = 1;
                nextRotation.axis.x = 0;
                nextRotation.axis.y = 1;
                endTransition();
            }
        }
    }
    
    // X轴翻转动画效果（反方向） - 旧图向下翻转出，新图向上翻转入
    SequentialAnimation {
        id: flipXUpAnimation
        
        // 第一阶段：旧图向下翻转90度并淡出
        ParallelAnimation {
            NumberAnimation {
                target: nextImageItem
                property: "z"
                from: 0
                to: 2
                duration: 1
            }
            ScriptAction {
                script: {
                    // 设置绕X轴旋转
                    currentRotation.axis.x = 1;
                    currentRotation.axis.y = 0;
                    currentRotation.axis.z = 0;
                }
            }
            NumberAnimation {
                target: currentRotation
                property: "angle"
                from: 0
                to: 90
                duration: transitionDuration/2
                easing.type: Easing.InQuad
            }
            NumberAnimation {
                target: currentImageItem
                property: "opacity"
                from: 1.0
                to: 0.0
                duration: transitionDuration/2
                easing.type: Easing.InQuad
            }
        }
        
        // 第二阶段：新图向上翻转90度并淡入，淡入和翻转同步进行
        ParallelAnimation {
            ScriptAction {
                script: {
                    // 设置绕X轴旋转
                    nextRotation.axis.x = 1;
                    nextRotation.axis.y = 0;
                    nextRotation.axis.z = 0;
                }
            }
            NumberAnimation {
                target: nextImageItem
                property: "opacity"
                from: 0.0
                to: 1.0
                duration: transitionDuration/2
                easing.type: Easing.OutQuad
            }
            NumberAnimation {
                target: nextRotation
                property: "angle"
                from: -90
                to: 0
                duration: transitionDuration/2
                easing.type: Easing.OutQuad
            }
        }
        
        onRunningChanged: {
            if (!running && transitioning) {
                // 恢复默认绕Y轴旋转
                currentRotation.axis.x = 0;
                currentRotation.axis.y = 1;
                nextRotation.axis.x = 0;
                nextRotation.axis.y = 1;
                endTransition();
            }
        }
    }
    
    // 缩放过渡动画效果 - 旧图缩小到0，新图放大到正常大小
    ParallelAnimation {
        id: scaleTransitionAnimation
        NumberAnimation {
            target: nextImageItem
            property: "z"
            from: 0
            to: 2
            duration: 1
        }
        NumberAnimation {
            target: currentImageItem
            property: "scale"
            from: 1.0
            to: 0.0
            duration: transitionDuration
            easing.type: Easing.InOutQuad
        }
        NumberAnimation {
            target: currentImageItem
            property: "opacity"
            from: 1.0
            to: 0.0
            duration: transitionDuration
            easing.type: Easing.InOutQuad
        }
        NumberAnimation {
            target: nextImageItem
            property: "scale"
            from: 0.0
            to: 1.0
            duration: transitionDuration
            easing.type: Easing.InOutQuad
        }
        NumberAnimation {
            target: nextImageItem
            property: "opacity"
            from: 0.0
            to: 1.0
            duration: transitionDuration
            easing.type: Easing.InOutQuad
        }
        onRunningChanged: { if (!running && transitioning) endTransition() }
    }
    
    // 对角线翻转动画效果 - 左上右下对角线翻转
    SequentialAnimation {
        id: flipDiagonalAnimation
        
        // 第一阶段：旧图沿左上右下对角线翻转90度并淡出
        ParallelAnimation {
            NumberAnimation {
                target: nextImageItem
                property: "z"
                from: 0
                to: 2
                duration: 1
            }
            ScriptAction {
                script: {
                    // 设置沿左上右下对角线旋转
                    currentRotation.axis.x = 1;
                    currentRotation.axis.y = 1;
                    currentRotation.axis.z = 0;
                }
            }
            NumberAnimation {
                target: currentRotation
                property: "angle"
                from: 0
                to: -90
                duration: transitionDuration/2
                easing.type: Easing.InQuad
            }
            NumberAnimation {
                target: currentImageItem
                property: "opacity"
                from: 1.0
                to: 0.0
                duration: transitionDuration/2
                easing.type: Easing.InQuad
            }
        }
        
        // 第二阶段：新图沿左上右下对角线翻转入并淡入
        ParallelAnimation {
            ScriptAction {
                script: {
                    // 设置沿左上右下对角线旋转
                    nextRotation.axis.x = 1;
                    nextRotation.axis.y = 1;
                    nextRotation.axis.z = 0;
                }
            }
            NumberAnimation {
                target: nextImageItem
                property: "opacity"
                from: 0.0
                to: 1.0
                duration: transitionDuration/2
                easing.type: Easing.OutQuad
            }
            NumberAnimation {
                target: nextRotation
                property: "angle"
                from: 90
                to: 0
                duration: transitionDuration/2
                easing.type: Easing.OutQuad
            }
        }
        
        onRunningChanged: {
            if (!running && transitioning) {
                // 恢复默认绕Y轴旋转
                currentRotation.axis.x = 0;
                currentRotation.axis.y = 1;
                nextRotation.axis.x = 0;
                nextRotation.axis.y = 1;
                endTransition();
            }
        }
    }
    
    // 对角线翻转动画效果 - 右上左下对角线翻转
    SequentialAnimation {
        id: flipDiagonalReverseAnimation
        
        // 第一阶段：旧图沿右上左下对角线翻转90度并淡出
        ParallelAnimation {
            NumberAnimation {
                target: nextImageItem
                property: "z"
                from: 0
                to: 2
                duration: 1
            }
            ScriptAction {
                script: {
                    // 设置沿右上左下对角线旋转
                    currentRotation.axis.x = 1;
                    currentRotation.axis.y = -1;
                    currentRotation.axis.z = 0;
                }
            }
            NumberAnimation {
                target: currentRotation
                property: "angle"
                from: 0
                to: -90
                duration: transitionDuration/2
                easing.type: Easing.InQuad
            }
            NumberAnimation {
                target: currentImageItem
                property: "opacity"
                from: 1.0
                to: 0.0
                duration: transitionDuration/2
                easing.type: Easing.InQuad
            }
        }
        
        // 第二阶段：新图沿右上左下对角线翻转入并淡入
        ParallelAnimation {
            ScriptAction {
                script: {
                    // 设置沿右上左下对角线旋转
                    nextRotation.axis.x = 1;
                    nextRotation.axis.y = -1;
                    nextRotation.axis.z = 0;
                }
            }
            NumberAnimation {
                target: nextImageItem
                property: "opacity"
                from: 0.0
                to: 1.0
                duration: transitionDuration/2
                easing.type: Easing.OutQuad
            }
            NumberAnimation {
                target: nextRotation
                property: "angle"
                from: 90
                to: 0
                duration: transitionDuration/2
                easing.type: Easing.OutQuad
            }
        }
        
        onRunningChanged: {
            if (!running && transitioning) {
                // 恢复默认绕Y轴旋转
                currentRotation.axis.x = 0;
                currentRotation.axis.y = 1;
                nextRotation.axis.x = 0;
                nextRotation.axis.y = 1;
                endTransition();
            }
        }
    }
    
    // X轴翻转动画效果 - 以图片顶端为轴的翻转
    SequentialAnimation {
        id: flipXTopAnimation
        
        // 第一阶段：旧图以顶端为轴X轴翻转90度并淡出
        ParallelAnimation {
            NumberAnimation {
                target: nextImageItem
                property: "z"
                from: 0
                to: 2
                duration: 1
            }
            ScriptAction {
                script: {
                    // 设置以图片顶端为轴X轴旋转
                    currentRotation.axis.x = 1;
                    currentRotation.axis.y = 0;
                    currentRotation.axis.z = 0;
                    // 设置旋转原点为图片顶端
                    currentRotation.origin.y = 0;
                }
            }
            NumberAnimation {
                target: currentRotation
                property: "angle"
                from: 0
                to: -90
                duration: transitionDuration/2
                easing.type: Easing.InQuad
            }
            NumberAnimation {
                target: currentImageItem
                property: "opacity"
                from: 1.0
                to: 0.0
                duration: transitionDuration/2
                easing.type: Easing.InQuad
            }
        }
        
        // 第二阶段：新图以顶端为轴X轴翻转入并淡入
        ParallelAnimation {
            ScriptAction {
                script: {
                    // 设置以图片顶端为轴X轴旋转
                    nextRotation.axis.x = 1;
                    nextRotation.axis.y = 0;
                    nextRotation.axis.z = 0;
                    // 设置旋转原点为图片顶端
                    nextRotation.origin.y = 0;
                }
            }
            NumberAnimation {
                target: nextImageItem
                property: "opacity"
                from: 0.0
                to: 1.0
                duration: transitionDuration/2
                easing.type: Easing.OutQuad
            }
            NumberAnimation {
                target: nextRotation
                property: "angle"
                from: 90
                to: 0
                duration: transitionDuration/2
                easing.type: Easing.OutQuad
            }
        }
        
        onRunningChanged: {
            if (!running && transitioning) {
                // 恢复默认设置
                currentRotation.axis.x = 0;
                currentRotation.axis.y = 1;
                currentRotation.origin.y = currentImageItem.height / 2;
                nextRotation.axis.x = 0;
                nextRotation.axis.y = 1;
                nextRotation.origin.y = nextImageItem.height / 2;
                endTransition();
            }
        }
    }
    
    // X轴翻转动画效果 - 以图片底端为轴的翻转
    SequentialAnimation {
        id: flipXBottomAnimation
        
        // 第一阶段：旧图以底端为轴X轴翻转90度并淡出
        ParallelAnimation {
            NumberAnimation {
                target: nextImageItem
                property: "z"
                from: 0
                to: 2
                duration: 1
            }
            ScriptAction {
                script: {
                    // 设置以图片底端为轴X轴旋转
                    currentRotation.axis.x = 1;
                    currentRotation.axis.y = 0;
                    currentRotation.axis.z = 0;
                    // 设置旋转原点为图片底端
                    currentRotation.origin.y = currentImageItem.height;
                }
            }
            NumberAnimation {
                target: currentRotation
                property: "angle"
                from: 0
                to: 90
                duration: transitionDuration/2
                easing.type: Easing.InQuad
            }
            NumberAnimation {
                target: currentImageItem
                property: "opacity"
                from: 1.0
                to: 0.0
                duration: transitionDuration/2
                easing.type: Easing.InQuad
            }
        }
        
        // 第二阶段：新图以底端为轴X轴翻转入并淡入
        ParallelAnimation {
            ScriptAction {
                script: {
                    // 设置以图片底端为轴X轴旋转
                    nextRotation.axis.x = 1;
                    nextRotation.axis.y = 0;
                    nextRotation.axis.z = 0;
                    // 设置旋转原点为图片底端
                    nextRotation.origin.y = nextImageItem.height;
                }
            }
            NumberAnimation {
                target: nextImageItem
                property: "opacity"
                from: 0.0
                to: 1.0
                duration: transitionDuration/2
                easing.type: Easing.OutQuad
            }
            NumberAnimation {
                target: nextRotation
                property: "angle"
                from: -90
                to: 0
                duration: transitionDuration/2
                easing.type: Easing.OutQuad
            }
        }
        
        onRunningChanged: {
            if (!running && transitioning) {
                // 恢复默认设置
                currentRotation.axis.x = 0;
                currentRotation.axis.y = 1;
                currentRotation.origin.y = currentImageItem.height / 2;
                nextRotation.axis.x = 0;
                nextRotation.axis.y = 1;
                nextRotation.origin.y = nextImageItem.height / 2;
                endTransition();
            }
        }
    }
    
    // Y轴翻转动画效果 - 以图片左侧为轴的翻转
    SequentialAnimation {
        id: flipYLeftAnimation
        
        // 第一阶段：旧图以左侧为轴Y轴翻转90度并淡出
        ParallelAnimation {
            NumberAnimation {
                target: nextImageItem
                property: "z"
                from: 0
                to: 2
                duration: 1
            }
            ScriptAction {
                script: {
                    // 设置以图片左侧为轴Y轴旋转
                    currentRotation.axis.x = 0;
                    currentRotation.axis.y = 1;
                    currentRotation.axis.z = 0;
                    // 设置旋转原点为图片左侧
                    currentRotation.origin.x = 0;
                }
            }
            NumberAnimation {
                target: currentRotation
                property: "angle"
                from: 0
                to: -90
                duration: transitionDuration/2
                easing.type: Easing.InQuad
            }
            NumberAnimation {
                target: currentImageItem
                property: "opacity"
                from: 1.0
                to: 0.0
                duration: transitionDuration/2
                easing.type: Easing.InQuad
            }
        }
        
        // 第二阶段：新图以左侧为轴Y轴翻转入并淡入
        ParallelAnimation {
            ScriptAction {
                script: {
                    // 设置以图片左侧为轴Y轴旋转
                    nextRotation.axis.x = 0;
                    nextRotation.axis.y = 1;
                    nextRotation.axis.z = 0;
                    // 设置旋转原点为图片左侧
                    nextRotation.origin.x = 0;
                }
            }
            NumberAnimation {
                target: nextImageItem
                property: "opacity"
                from: 0.0
                to: 1.0
                duration: transitionDuration/2
                easing.type: Easing.OutQuad
            }
            NumberAnimation {
                target: nextRotation
                property: "angle"
                from: 90
                to: 0
                duration: transitionDuration/2
                easing.type: Easing.OutQuad
            }
        }
        
        onRunningChanged: {
            if (!running && transitioning) {
                // 恢复默认设置
                currentRotation.origin.x = currentImageItem.width / 2;
                nextRotation.origin.x = nextImageItem.width / 2;
                endTransition();
            }
        }
    }
    
    // Y轴翻转动画效果 - 以图片右侧为轴的翻转
    SequentialAnimation {
        id: flipYRightAnimation
        
        // 第一阶段：旧图以右侧为轴Y轴翻转90度并淡出
        ParallelAnimation {
            NumberAnimation {
                target: nextImageItem
                property: "z"
                from: 0
                to: 2
                duration: 1
            }
            ScriptAction {
                script: {
                    // 设置以图片右侧为轴Y轴旋转
                    currentRotation.axis.x = 0;
                    currentRotation.axis.y = 1;
                    currentRotation.axis.z = 0;
                    // 设置旋转原点为图片右侧
                    currentRotation.origin.x = currentImageItem.width;
                }
            }
            NumberAnimation {
                target: currentRotation
                property: "angle"
                from: 0
                to: 90
                duration: transitionDuration/2
                easing.type: Easing.InQuad
            }
            NumberAnimation {
                target: currentImageItem
                property: "opacity"
                from: 1.0
                to: 0.0
                duration: transitionDuration/2
                easing.type: Easing.InQuad
            }
        }
        
        // 第二阶段：新图以右侧为轴Y轴翻转入并淡入
        ParallelAnimation {
            ScriptAction {
                script: {
                    // 设置以图片右侧为轴Y轴旋转
                    nextRotation.axis.x = 0;
                    nextRotation.axis.y = 1;
                    nextRotation.axis.z = 0;
                    // 设置旋转原点为图片右侧
                    nextRotation.origin.x = nextImageItem.width;
                }
            }
            NumberAnimation {
                target: nextImageItem
                property: "opacity"
                from: 0.0
                to: 1.0
                duration: transitionDuration/2
                easing.type: Easing.OutQuad
            }
            NumberAnimation {
                target: nextRotation
                property: "angle"
                from: -90
                to: 0
                duration: transitionDuration/2
                easing.type: Easing.OutQuad
            }
        }
        
        onRunningChanged: {
            if (!running && transitioning) {
                // 恢复默认设置
                currentRotation.origin.x = currentImageItem.width / 2;
                nextRotation.origin.x = nextImageItem.width / 2;
                endTransition();
            }
        }
    }
}