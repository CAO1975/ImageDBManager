// ImageViewer.qml - 图片查看器组件
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Controls.Universal

Item {
    property color customBackground: '#112233'
    property color customAccent: '#30638f'
    anchors.fill: parent

    // 双击信号
    signal imageDoubleClicked()

    // 辅助函数：设置旋转轴
    function setRotationAxis(rotationObj, x, y, z) {
        rotationObj.axis.x = x
        rotationObj.axis.y = y
        rotationObj.axis.z = z
    }

    // 辅助函数：重置所有旋转轴到默认值
    function resetRotationAxes() {
        currentRotation.axis.x = 0
        currentRotation.axis.y = 1
        currentRotation.axis.z = 0
        nextRotation.axis.x = 0
        nextRotation.axis.y = 1
        nextRotation.axis.z = 0
        currentRotationX.axis.x = 1
        currentRotationX.axis.y = 0
        currentRotationX.axis.z = 0
        nextRotationX.axis.x = 1
        nextRotationX.axis.y = 0
        nextRotationX.axis.z = 0
    }

    // 组件销毁时清理资源
    Component.onDestruction: {
        stopAllAnimations()
    }



    // 动画通用缓动属性
    readonly property var animEasing: Easing.InOutQuad

    // 使用内联 Rectangle 代替组件
    Rectangle {
        anchors.fill: parent
        color: customBackground
        border.color: customAccent
        border.width: 1
        radius: 8
        z: -1
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
    
    // 添加着色器过渡相关属性
    property int shaderEffectType: 0  // 0 = 溶解
    
    // 暂停所有动画（用于全屏切换时）
    function pauseAllAnimations() {
        if (fadeAnimation.running) fadeAnimation.pause()
        if (slideLeftAnimation.running) slideLeftAnimation.pause()
        if (slideRightAnimation.running) slideRightAnimation.pause()
        if (scaleAnimation.running) scaleAnimation.pause()
        if (fadeScaleAnimation.running) fadeScaleAnimation.pause()
        if (rotateAnimation.running) rotateAnimation.pause()
        if (rotateRightAnimation.running) rotateRightAnimation.pause()
        if (rotateLeft180Animation.running) rotateLeft180Animation.pause()
        if (rotateRight180Animation.running) rotateRight180Animation.pause()
        if (slideUpDownAnimation.running) slideUpDownAnimation.pause()
        if (slideDownUpAnimation.running) slideDownUpAnimation.pause()
        if (slideLeftDownToRightUpAnimation.running) slideLeftDownToRightUpAnimation.pause()
        if (slideRightUpToLeftDownAnimation.running) slideRightUpToLeftDownAnimation.pause()
        if (slideLeftUpToRightDownAnimation.running) slideLeftUpToRightDownAnimation.pause()
        if (slideRightDownToLeftUpAnimation.running) slideRightDownToLeftUpAnimation.pause()
        if (flipAnimation.running) flipAnimation.pause()
        if (flipReverseAnimation.running) flipReverseAnimation.pause()
        if (flipXDownAnimation.running) flipXDownAnimation.pause()
        if (flipXUpAnimation.running) flipXUpAnimation.pause()
        if (flipXTopAnimation.running) flipXTopAnimation.pause()
        if (flipXBottomAnimation.running) flipXBottomAnimation.pause()
        if (scaleTransitionAnimation.running) scaleTransitionAnimation.pause()
        if (flipDiagonalAnimation.running) flipDiagonalAnimation.pause()
        if (flipDiagonalReverseAnimation.running) flipDiagonalReverseAnimation.pause()
        if (flipYLeftAnimation.running) flipYLeftAnimation.pause()
        if (flipYRightAnimation.running) flipYRightAnimation.pause()
        if (spiralFlyAnimation.running) spiralFlyAnimation.pause()
        updateTimer.stop()
    }

    // 恢复/停止所有动画（用于退出全屏时）
    function stopAllAnimations() {
        fadeAnimation.stop()
        slideLeftAnimation.stop()
        slideRightAnimation.stop()
        scaleAnimation.stop()
        fadeScaleAnimation.stop()
        rotateAnimation.stop()
        rotateRightAnimation.stop()
        rotateLeft180Animation.stop()
        rotateRight180Animation.stop()
        slideUpDownAnimation.stop()
        slideDownUpAnimation.stop()
        slideLeftDownToRightUpAnimation.stop()
        slideRightUpToLeftDownAnimation.stop()
        slideLeftUpToRightDownAnimation.stop()
        slideRightDownToLeftUpAnimation.stop()
        flipAnimation.stop()
        flipReverseAnimation.stop()
        flipXDownAnimation.stop()
        flipXUpAnimation.stop()
        flipXTopAnimation.stop()
        flipXBottomAnimation.stop()
        scaleTransitionAnimation.stop()
        flipDiagonalAnimation.stop()
        flipDiagonalReverseAnimation.stop()
        flipYLeftAnimation.stop()
        flipYRightAnimation.stop()
        spiralFlyAnimation.stop()
        flipScaleAnimation.stop()
        flipScaleXAnimation.stop()
        pendulumAnimation.stop()
        horizontalRollAnimation.stop()
        verticalRollAnimation.stop()
        updateTimer.stop()
    }

    // 边界约束函数
    function constrainImageOffset() {
        // 使用 paintedWidth/paintedHeight 获取 Image.PreserveAspectFit 模式下的实际显示尺寸
        var actualImageWidth = currentImageItem.paintedWidth * scaleFactor
        var actualImageHeight = currentImageItem.paintedHeight * scaleFactor
        var overflowX = actualImageWidth - parent.width
        var overflowY = actualImageHeight - parent.height

        if (overflowX > 0) {
            var minX = -overflowX / 2
            var maxX = overflowX / 2
            imageOffset.x = Math.min(maxX, Math.max(minX, imageOffset.x))
        } else {
            // 图片宽度小于窗口，居中显示
            imageOffset.x = 0
        }

        if (overflowY > 0) {
            var minY = -overflowY / 2
            var maxY = overflowY / 2
            imageOffset.y = Math.min(maxY, Math.max(minY, imageOffset.y))
        } else {
            // 图片高度小于窗口，居中显示
            imageOffset.y = 0
        }
    }
    
    // 监听 currentImageId 变化，自动加载图片
    onCurrentImageIdChanged: {
        // 只有当ID有效且不是当前正在显示的图片时才加载
        if (currentImageId !== -1 && currentImageId !== newImageId) {
            // 检查currentImage的URL是否匹配当前ID
            var expectedUrl = "image://imageprovider/" + currentImageId + "/original"
            if (currentImage !== expectedUrl || nextImage !== expectedUrl) {
                // 只有可见时才执行过渡动画，不可见时静默加载（不执行动画）
                if (visible) {
                    loadImageWithTransition(currentImageId)
                } else {
                    // 不可见时只更新内部状态，不执行动画
                    currentImage = expectedUrl
                }
            }
        }
    }

    // 外部调用：直接加载图片（无过渡）
    function loadImage(imageId) {
        if (imageId === -1) return
        
        // 停止所有动画和过渡
        stopAllAnimations()
        transitioning = false
        
        // 直接设置图片
        var imageUrl = "image://imageprovider/" + imageId + "/original"
        currentImage = imageUrl
        currentImageItem.source = currentImage || ""
        currentImageItem.visible = true
        nextImageItem.visible = false
        currentImageItem.opacity = 1.0
        nextImageItem.opacity = 0.0
        
        resetTransform()
    }

    // 带过渡效果的图片加载
    function loadImageWithTransition(imageId) {
        if (imageId === -1) return
        
        // 避免重复加载正在过渡的同一图片
        if (transitioning && newImageId === imageId) return
        
        // 生成图片URL
        var imageUrl = "image://imageprovider/" + imageId + "/original"
        
        // 第一次加载（直接显示，无过渡）
        if (currentImage === null || currentImage === "") {
            currentImage = imageUrl
            currentImageItem.source = currentImage || ""
            currentImageItem.visible = true
            nextImageItem.visible = false
            currentImageItem.opacity = 1.0
            nextImageItem.opacity = 0.0
            resetTransform()
            return
        }
        
        // 停止所有动画
        stopAllAnimations()
        
        // 如果正在过渡，先结束
        if (transitioning) {
            endTransition()
        }
        
        // 无过渡时间：直接切换
        if (transitionDuration === 0) {
            currentImage = imageUrl
            currentImageItem.source = currentImage || ""
            currentImageItem.visible = true
            nextImageItem.visible = false
            currentImageItem.opacity = 1.0
            nextImageItem.opacity = 0.0
            resetTransform()
            return
        }
        
        // 开始过渡动画
        transitioning = true
        nextImage = imageUrl
        newImageId = imageId
        
        // 选择过渡效果
        var selectedTransition = transitionType
        if (selectedTransition === -1) {
            // 随机选择0-82（所有83个过渡效果）
            selectedTransition = Math.floor(Math.random() * 83)
        }
        
        resetTransform()
        
        // 重置位置和变换
        currentImageItem.opacity = 1.0
        currentImageItem.x = 0
        currentImageItem.y = 0
        currentImageItem.scale = 1.0
        currentImageItem.rotation = 0
        nextImageItem.x = 0
        nextImageItem.y = 0
        nextImageItem.scale = 1.0
        nextImageItem.rotation = 0
        
        // 设置图片源
        currentImageItem.source = currentImage || ""
        nextImageItem.source = nextImage || ""
        
        // 着色器过渡
        if (selectedTransition >= 32 && selectedTransition <= 82) {
            nextImageItem.opacity = 1.0
            currentImageItem.visible = true
            nextImageItem.visible = true

            var shaderEffectIndex = selectedTransition - 32
            shaderEffectType = shaderEffectIndex
            shaderTransition.visible = true
            currentImageItem.opacity = 1.0
            nextImageItem.opacity = 1.0

            updateTimer.start()
        } else {
            // 普通动画过渡
            shaderTransition.visible = false
            currentImageItem.visible = true
            nextImageItem.visible = true
            currentImageItem.opacity = 1.0
            nextImageItem.opacity = 0.0
            
            // 启动对应的动画
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
                case 26: spiralFlyAnimation.start(); break
                case 27: flipScaleAnimation.start(); break
                case 28: flipScaleXAnimation.start(); break
                case 29: pendulumAnimation.start(); break
                case 30: horizontalRollAnimation.start(); break
                case 31: verticalRollAnimation.start(); break
                default: fadeAnimation.start(); break
            }
        }
    }
    
    function resetTransform() {
        scaleFactor = 1.0; imageOffset = Qt.point(0, 0); isDragging = false
    }
    
    function endTransition() {
        transitioning = false
        
        // 更新当前图片（不修改currentImageId，因为它由外部绑定）
        if (newImageId !== -1) {
            currentImage = nextImage
        }
        nextImage = null
        newImageId = -1
        
        resetTransform()
        
        currentImageItem.source = currentImage || ""
        currentImageItem.opacity = 1.0; currentImageItem.rotation = 0
        currentRotation.angle = 0  // 重置Y轴旋转角度
        currentRotationX.angle = 0  // 重置X轴旋转角度
        currentImageItem.x = Qt.binding(function() { return imageOffset.x })
        currentImageItem.y = Qt.binding(function() { return imageOffset.y })
        currentImageItem.scale = Qt.binding(function() { return scaleFactor })
        // 重置旧图片的挤压变换
        currentHorizontalScale.xScale = 1.0
        currentHorizontalScale.yScale = 1.0
        currentVerticalScale.xScale = 1.0
        currentVerticalScale.yScale = 1.0
        // 重置新图片的挤压变换
        horizontalScale.xScale = 1.0
        horizontalScale.yScale = 1.0
        verticalScale.xScale = 1.0
        verticalScale.yScale = 1.0
        
        nextImageItem.opacity = 0.0; nextImageItem.rotation = 0
        nextRotation.angle = 0  // 重置Y轴旋转角度
        nextRotationX.angle = 0  // 重置X轴旋转角度
        nextImageItem.x = Qt.binding(function() { return imageOffset.x })
        nextImageItem.y = Qt.binding(function() { return imageOffset.y })
        // 重置z层级
        currentImageItem.z = -1
        nextImageItem.z = -1
        nextImageItem.scale = Qt.binding(function() { return scaleFactor })
        
        // 重置着色器过渡进度
        shaderEffectItem.transitionProgress = 0
        updateTimer.stop();  // 停止更新定时器
        // 隐藏着色器过渡组件，显示普通图片项
        shaderTransition.visible = false
        currentImageItem.visible = true  // 确保当前图片可见
        nextImageItem.visible = false  // 隐藏下一张图片
        currentImageItem.opacity = 1.0
        nextImageItem.opacity = 0.0  // 转换结束后隐藏下一张图片
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
            z: -1  // 降低z值，确保着色器在上面

            // 旋转变换 - 同时支持Y轴和X轴翻转
            transform: [
                Rotation {
                    id: currentRotation
                    origin.x: currentImageItem.width / 2
                    origin.y: currentImageItem.height / 2
                    axis { x: 0; y: 1; z: 0 }
                    angle: 0
                },
                Rotation {
                    id: currentRotationX
                    origin.x: currentImageItem.width / 2
                    origin.y: currentImageItem.height / 2
                    axis { x: 1; y: 0; z: 0 }
                    angle: 0
                },
                Scale {
                    id: currentHorizontalScale
                    origin.x: currentImageItem.width / 2
                    origin.y: currentImageItem.height / 2
                    xScale: 1.0
                    yScale: 1.0
                },
                Scale {
                    id: currentVerticalScale
                    origin.x: currentImageItem.width / 2
                    origin.y: currentImageItem.height / 2
                    xScale: 1.0
                    yScale: 1.0
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
            z: -1  // 降低z值，确保着色器在上面

            // 旋转变换 - 同时支持Y轴和X轴翻转
            transform: [
                Rotation {
                    id: nextRotation
                    origin.x: nextImageItem.width / 2
                    origin.y: nextImageItem.height / 2
                    axis { x: 0; y: 1; z: 0 }
                    angle: 0
                },
                Rotation {
                    id: nextRotationX
                    origin.x: nextImageItem.width / 2
                    origin.y: nextImageItem.height / 2
                    axis { x: 1; y: 0; z: 0 }
                    angle: 0
                },
                Scale {
                    id: horizontalScale
                    origin.x: 0
                    origin.y: nextImageItem.height / 2
                    xScale: 1.0
                    yScale: 1.0
                },
                Scale {
                    id: verticalScale
                    origin.x: nextImageItem.width / 2
                    origin.y: 0
                    xScale: 1.0
                    yScale: 1.0
                }
            ]
        }
        
        // 着色器过渡效果
        Item {
            id: shaderTransition
            anchors.fill: parent
            z: 2  // 确保着色器在图片之上
            visible: false  // 默认不可见，只在需要时使用

            // 着色器边框（圆角）
            Rectangle {
                anchors.fill: parent
                color: "transparent"
                border.color: customAccent
                border.width: 1
                radius: 8
                z: 1
            }

            ShaderEffect {
                id: shaderEffectItem
                anchors.fill: parent
                z: 0  // 着色器在边框之下

                // 指定着色器文件路径
                // 顶点着色器和片段着色器已编译到一个.qsb文件中
                // Qt会自动从同一个.qsb文件中读取顶点着色器
                fragmentShader: "qrc:/assets/shaders/qsb/transitions.frag.qsb"

                // ShaderEffectSource 用于捕获当前图片和下一张图片
                property variant currentSource: ShaderEffectSource {
                    id: currentSource
                    sourceItem: currentImageItem
                    hideSource: false  // 设置为false，避免隐藏源图像
                    live: true
                    sourceRect: Qt.rect(0, 0, imageContainer.width, imageContainer.height)
                }

                property variant nextSource: ShaderEffectSource {
                    id: nextSource
                    sourceItem: nextImageItem
                    hideSource: false  // 设置为false，避免隐藏源图像
                    live: true
                    sourceRect: Qt.rect(0, 0, imageContainer.width, imageContainer.height)
                }

                // 过渡参数
                property real transitionProgress: 0

                // 添加调试信息
                Component.onCompleted: {
                    // 着色器加载完成
                }

                // 将图片源传递给着色器
                property variant from: currentSource
                property variant to: nextSource

                // 将QML属性映射到着色器uniform变量
                // 着色器中使用progress和effectType作为uniform变量
                property real progress: transitionProgress
                property int effectType: shaderEffectType
                property vector3d backgroundColor: Qt.vector3d(customBackground.r, customBackground.g, customBackground.b)

                // 监听状态变化
                onStatusChanged: {
                    // 状态变化处理
                }
            }
        }
        
        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
            z: 100  // 确保在最上层

        onDoubleClicked: function(mouse) {
            // 双击进入全屏模式
            imageDoubleClicked()
        }

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
                    imageOffset = Qt.point(imageOffset.x + delta.x, imageOffset.y + delta.y)
                    lastMousePos = Qt.point(mouseX, mouseY)
                    
                    // 应用边界约束
                    constrainImageOffset()
                }
            }
            
            onWheel: function(event) {
                if (!transitioning) {
                    var scaleDelta = event.angleDelta.y > 0 ? 0.9 : 1.1
                    scaleFactor *= scaleDelta
                    scaleFactor = Math.max(minScale, Math.min(maxScale, scaleFactor))
                    
                    // 应用边界约束
                    constrainImageOffset()
                }
                event.accepted = true
            }
        }
    }
    
    // 动画定义
    ParallelAnimation {
        id: fadeAnimation
        NumberAnimation { target: currentImageItem; property: "opacity"; from: 1.0; to: 0.0; duration: transitionDuration; easing.type: animEasing }
        NumberAnimation { target: nextImageItem; property: "opacity"; from: 0.0; to: 1.0; duration: transitionDuration; easing.type: animEasing }
        onRunningChanged: { if (!running && transitioning) endTransition() }
    }

    ParallelAnimation {
        id: rotateRightAnimation
        NumberAnimation { target: currentImageItem; property: "rotation"; from: 0; to: 90; duration: transitionDuration; easing.type: animEasing }
        NumberAnimation { target: nextImageItem; property: "rotation"; from: -90; to: 0; duration: transitionDuration; easing.type: animEasing }
        NumberAnimation { target: currentImageItem; property: "opacity"; from: 1.0; to: 0.0; duration: transitionDuration; easing.type: animEasing }
        NumberAnimation { target: nextImageItem; property: "opacity"; from: 0.0; to: 1.0; duration: transitionDuration; easing.type: animEasing }
        onRunningChanged: { if (!running && transitioning) endTransition() }
    }

    ParallelAnimation {
        id: rotateLeft180Animation
        NumberAnimation { target: currentImageItem; property: "rotation"; from: 0; to: -180; duration: transitionDuration; easing.type: animEasing }
        NumberAnimation { target: nextImageItem; property: "rotation"; from: 180; to: 0; duration: transitionDuration; easing.type: animEasing }
        NumberAnimation { target: currentImageItem; property: "opacity"; from: 1.0; to: 0.0; duration: transitionDuration; easing.type: animEasing }
        NumberAnimation { target: nextImageItem; property: "opacity"; from: 0.0; to: 1.0; duration: transitionDuration; easing.type: animEasing }
        onRunningChanged: { if (!running && transitioning) endTransition() }
    }

    ParallelAnimation {
        id: rotateRight180Animation
        NumberAnimation { target: currentImageItem; property: "rotation"; from: 0; to: 180; duration: transitionDuration; easing.type: animEasing }
        NumberAnimation { target: nextImageItem; property: "rotation"; from: -180; to: 0; duration: transitionDuration; easing.type: animEasing }
        NumberAnimation { target: currentImageItem; property: "opacity"; from: 1.0; to: 0.0; duration: transitionDuration; easing.type: animEasing }
        NumberAnimation { target: nextImageItem; property: "opacity"; from: 0.0; to: 1.0; duration: transitionDuration; easing.type: animEasing }
        onRunningChanged: { if (!running && transitioning) endTransition() }
    }

    ParallelAnimation {
        id: rotateAnimation
        NumberAnimation { target: currentImageItem; property: "rotation"; from: 0; to: -90; duration: transitionDuration; easing.type: animEasing }
        NumberAnimation { target: nextImageItem; property: "rotation"; from: 90; to: 0; duration: transitionDuration; easing.type: animEasing }
        NumberAnimation { target: currentImageItem; property: "opacity"; from: 1.0; to: 0.0; duration: transitionDuration; easing.type: animEasing }
        NumberAnimation { target: nextImageItem; property: "opacity"; from: 0.0; to: 1.0; duration: transitionDuration; easing.type: animEasing }
        onRunningChanged: { if (!running && transitioning) endTransition() }
    }

    ParallelAnimation {
        id: slideLeftAnimation
        NumberAnimation { target: currentImageItem; property: "x"; from: 0; to: -500; duration: transitionDuration; easing.type: animEasing }
        NumberAnimation { target: nextImageItem; property: "x"; from: 500; to: 0; duration: transitionDuration; easing.type: animEasing }
        NumberAnimation { target: currentImageItem; property: "opacity"; from: 1.0; to: 0.0; duration: transitionDuration; easing.type: animEasing }
        NumberAnimation { target: nextImageItem; property: "opacity"; from: 0.0; to: 1.0; duration: transitionDuration; easing.type: animEasing }
        onRunningChanged: { if (!running && transitioning) endTransition() }
    }

    ParallelAnimation {
        id: slideRightAnimation
        NumberAnimation { target: currentImageItem; property: "x"; from: 0; to: 500; duration: transitionDuration; easing.type: animEasing }
        NumberAnimation { target: nextImageItem; property: "x"; from: -500; to: 0; duration: transitionDuration; easing.type: animEasing }
        NumberAnimation { target: currentImageItem; property: "opacity"; from: 1.0; to: 0.0; duration: transitionDuration; easing.type: animEasing }
        NumberAnimation { target: nextImageItem; property: "opacity"; from: 0.0; to: 1.0; duration: transitionDuration; easing.type: animEasing }
        onRunningChanged: { if (!running && transitioning) endTransition() }
    }

    ParallelAnimation {
        id: scaleAnimation
        NumberAnimation { target: currentImageItem; property: "scale"; from: 1.0; to: 0.3; duration: transitionDuration; easing.type: animEasing }
        NumberAnimation { target: nextImageItem; property: "scale"; from: 3.0; to: 1.0; duration: transitionDuration; easing.type: animEasing }
        NumberAnimation { target: currentImageItem; property: "opacity"; from: 1.0; to: 0.0; duration: transitionDuration; easing.type: animEasing }
        NumberAnimation { target: nextImageItem; property: "opacity"; from: 0.0; to: 1.0; duration: transitionDuration; easing.type: animEasing }
        onRunningChanged: { if (!running && transitioning) endTransition() }
    }

    ParallelAnimation {
        id: fadeScaleAnimation
        NumberAnimation { target: currentImageItem; property: "scale"; from: 1.0; to: 0.9; duration: transitionDuration; easing.type: animEasing }
        NumberAnimation { target: nextImageItem; property: "scale"; from: 1.1; to: 1.0; duration: transitionDuration; easing.type: animEasing }
        NumberAnimation { target: currentImageItem; property: "opacity"; from: 1.0; to: 0.0; duration: transitionDuration; easing.type: animEasing }
        NumberAnimation { target: nextImageItem; property: "opacity"; from: 0.0; to: 1.0; duration: transitionDuration; easing.type: animEasing }
        onRunningChanged: { if (!running && transitioning) endTransition() }
    }

    // 上滑淡出，下滑入淡入效果
    ParallelAnimation {
        id: slideUpDownAnimation
        NumberAnimation { target: currentImageItem; property: "y"; from: 0; to: -500; duration: transitionDuration; easing.type: animEasing }
        NumberAnimation { target: nextImageItem; property: "y"; from: 500; to: 0; duration: transitionDuration; easing.type: animEasing }
        NumberAnimation { target: currentImageItem; property: "opacity"; from: 1.0; to: 0.0; duration: transitionDuration; easing.type: animEasing }
        NumberAnimation { target: nextImageItem; property: "opacity"; from: 0.0; to: 1.0; duration: transitionDuration; easing.type: animEasing }
        onRunningChanged: { if (!running && transitioning) endTransition() }
    }

    // 下滑淡出，上滑入淡入效果
    ParallelAnimation {
        id: slideDownUpAnimation
        NumberAnimation { target: currentImageItem; property: "y"; from: 0; to: 500; duration: transitionDuration; easing.type: animEasing }
        NumberAnimation { target: nextImageItem; property: "y"; from: -500; to: 0; duration: transitionDuration; easing.type: animEasing }
        NumberAnimation { target: currentImageItem; property: "opacity"; from: 1.0; to: 0.0; duration: transitionDuration; easing.type: animEasing }
        NumberAnimation { target: nextImageItem; property: "opacity"; from: 0.0; to: 1.0; duration: transitionDuration; easing.type: animEasing }
        onRunningChanged: { if (!running && transitioning) endTransition() }
    }

    // 左下向右上滑入效果 - 旧图右上滑出，新图右下向左上滑入（缩放+滑动）
    ParallelAnimation {
        id: slideLeftDownToRightUpAnimation
        NumberAnimation { target: nextImageItem; property: "z"; from: 0; to: 2; duration: 1 }
        NumberAnimation { target: currentImageItem; property: "x"; from: 0; to: 500; duration: transitionDuration; easing.type: animEasing }
        NumberAnimation { target: currentImageItem; property: "y"; from: 0; to: -500; duration: transitionDuration; easing.type: animEasing }
        NumberAnimation { target: currentImageItem; property: "scale"; from: 1.0; to: 0.3; duration: transitionDuration; easing.type: animEasing }
        NumberAnimation { target: currentImageItem; property: "opacity"; from: 1.0; to: 0.0; duration: transitionDuration; easing.type: animEasing }
        NumberAnimation { target: nextImageItem; property: "x"; from: 500; to: 0; duration: transitionDuration; easing.type: animEasing }
        NumberAnimation { target: nextImageItem; property: "y"; from: 500; to: 0; duration: transitionDuration; easing.type: animEasing }
        NumberAnimation { target: nextImageItem; property: "scale"; from: 0.3; to: 1.0; duration: transitionDuration; easing.type: animEasing }
        NumberAnimation { target: nextImageItem; property: "opacity"; from: 0.0; to: 1.0; duration: transitionDuration; easing.type: animEasing }
        onRunningChanged: { if (!running && transitioning) endTransition() }
    }

    // 右上向左下滑入效果 - 旧图左下滑出，新图左上向右下滑入（缩放+滑动）
    ParallelAnimation {
        id: slideRightUpToLeftDownAnimation
        NumberAnimation { target: nextImageItem; property: "z"; from: 0; to: 2; duration: 1 }
        NumberAnimation { target: currentImageItem; property: "x"; from: 0; to: -500; duration: transitionDuration; easing.type: animEasing }
        NumberAnimation { target: currentImageItem; property: "y"; from: 0; to: 500; duration: transitionDuration; easing.type: animEasing }
        NumberAnimation { target: currentImageItem; property: "scale"; from: 1.0; to: 0.3; duration: transitionDuration; easing.type: animEasing }
        NumberAnimation { target: currentImageItem; property: "opacity"; from: 1.0; to: 0.0; duration: transitionDuration; easing.type: animEasing }
        NumberAnimation { target: nextImageItem; property: "x"; from: -500; to: 0; duration: transitionDuration; easing.type: animEasing }
        NumberAnimation { target: nextImageItem; property: "y"; from: -500; to: 0; duration: transitionDuration; easing.type: animEasing }
        NumberAnimation { target: nextImageItem; property: "scale"; from: 0.3; to: 1.0; duration: transitionDuration; easing.type: animEasing }
        NumberAnimation { target: nextImageItem; property: "opacity"; from: 0.0; to: 1.0; duration: transitionDuration; easing.type: animEasing }
        onRunningChanged: { if (!running && transitioning) endTransition() }
    }

    // 左上向右下滑入效果 - 旧图右下滑出，新图左上向右下滑入（缩放+滑动）
    ParallelAnimation {
        id: slideLeftUpToRightDownAnimation
        NumberAnimation { target: nextImageItem; property: "z"; from: 0; to: 2; duration: 1 }
        NumberAnimation { target: currentImageItem; property: "x"; from: 0; to: 500; duration: transitionDuration; easing.type: animEasing }
        NumberAnimation { target: currentImageItem; property: "y"; from: 0; to: 500; duration: transitionDuration; easing.type: animEasing }
        NumberAnimation { target: currentImageItem; property: "scale"; from: 1.0; to: 0.3; duration: transitionDuration; easing.type: animEasing }
        NumberAnimation { target: currentImageItem; property: "opacity"; from: 1.0; to: 0.0; duration: transitionDuration; easing.type: animEasing }
        NumberAnimation { target: nextImageItem; property: "x"; from: -500; to: 0; duration: transitionDuration; easing.type: animEasing }
        NumberAnimation { target: nextImageItem; property: "y"; from: -500; to: 0; duration: transitionDuration; easing.type: animEasing }
        NumberAnimation { target: nextImageItem; property: "scale"; from: 0.3; to: 1.0; duration: transitionDuration; easing.type: animEasing }
        NumberAnimation { target: nextImageItem; property: "opacity"; from: 0.0; to: 1.0; duration: transitionDuration; easing.type: animEasing }
        onRunningChanged: { if (!running && transitioning) endTransition() }
    }

    // 右下向左上滑入效果 - 旧图左上滑出，新图右下向左上滑入（缩放+滑动）
    ParallelAnimation {
        id: slideRightDownToLeftUpAnimation
        NumberAnimation { target: nextImageItem; property: "z"; from: 0; to: 2; duration: 1 }
        NumberAnimation { target: currentImageItem; property: "x"; from: 0; to: -500; duration: transitionDuration; easing.type: animEasing }
        NumberAnimation { target: currentImageItem; property: "y"; from: 0; to: -500; duration: transitionDuration; easing.type: animEasing }
        NumberAnimation { target: currentImageItem; property: "scale"; from: 1.0; to: 0.3; duration: transitionDuration; easing.type: animEasing }
        NumberAnimation { target: currentImageItem; property: "opacity"; from: 1.0; to: 0.0; duration: transitionDuration; easing.type: animEasing }
        NumberAnimation { target: nextImageItem; property: "x"; from: 500; to: 0; duration: transitionDuration; easing.type: animEasing }
        NumberAnimation { target: nextImageItem; property: "y"; from: 500; to: 0; duration: transitionDuration; easing.type: animEasing }
        NumberAnimation { target: nextImageItem; property: "scale"; from: 0.3; to: 1.0; duration: transitionDuration; easing.type: animEasing }
        NumberAnimation { target: nextImageItem; property: "opacity"; from: 0.0; to: 1.0; duration: transitionDuration; easing.type: animEasing }
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
                    setRotationAxis(currentRotation, 1, 0, 0)
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
                    setRotationAxis(nextRotation, 1, 0, 0)
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
                resetRotationAxes()
                endTransition()
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
                    setRotationAxis(currentRotation, 1, 0, 0)
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
                    setRotationAxis(nextRotation, 1, 0, 0)
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
                resetRotationAxes()
                endTransition()
            }
        }
    }
    
    // 弹性缩放动画效果 - 旧图弹性缩小消失，新图弹性放大出现（弹跳效果明显）
    SequentialAnimation {
        id: scaleTransitionAnimation

        // 第一阶段：旧图弹性缩小消失
        ParallelAnimation {
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
                duration: transitionDuration * 0.6
                easing.type: Easing.OutElastic
                easing.amplitude: 2.0
                easing.period: 0.4
            }
            NumberAnimation {
                target: currentImageItem
                property: "opacity"
                from: 1.0
                to: 0.0
                duration: transitionDuration * 0.5
                easing.type: Easing.OutQuad
            }
        }

        // 第二阶段：新图弹性放大出现（弹跳效果）
        ParallelAnimation {
            NumberAnimation {
                target: nextImageItem
                property: "scale"
                from: 0.0
                to: 1.0
                duration: transitionDuration * 0.7
                easing.type: Easing.OutElastic
                easing.amplitude: 2.5
                easing.period: 0.5
            }
            NumberAnimation {
                target: nextImageItem
                property: "opacity"
                from: 0.0
                to: 1.0
                duration: transitionDuration * 0.4
                easing.type: Easing.OutQuad
            }
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
                    setRotationAxis(currentRotation, 1, 1, 0)
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
                    setRotationAxis(nextRotation, 1, 1, 0)
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
                resetRotationAxes()
                endTransition()
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
                    setRotationAxis(currentRotation, 1, -1, 0)
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
                    setRotationAxis(nextRotation, 1, -1, 0)
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
                resetRotationAxes()
                endTransition()
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
                setRotationAxis(currentRotation, 0, 1, 0)
                currentRotation.origin.y = currentImageItem.height / 2
                setRotationAxis(nextRotation, 0, 1, 0)
                nextRotation.origin.y = nextImageItem.height / 2
                endTransition()
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
                    setRotationAxis(currentRotation, 1, 0, 0)
                    currentRotation.origin.y = currentImageItem.height
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
                setRotationAxis(currentRotation, 0, 1, 0)
                currentRotation.origin.y = currentImageItem.height / 2
                setRotationAxis(nextRotation, 0, 1, 0)
                nextRotation.origin.y = nextImageItem.height / 2
                endTransition()
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
                    setRotationAxis(currentRotation, 0, 1, 0)
                    currentRotation.origin.x = 0
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
                    setRotationAxis(currentRotation, 0, 1, 0)
                    currentRotation.origin.x = currentImageItem.width
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
                    setRotationAxis(nextRotation, 0, 1, 0)
                    nextRotation.origin.x = nextImageItem.width
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

    // 螺旋飞出飞入动画 - 旧图片蓄力后加速旋转甩出，新图片减速旋转飞入后惯性摆动
    SequentialAnimation {
        id: spiralFlyAnimation

        // 第一阶段：旧图片蓄力 + 加速旋转甩出（无淡出，直接旋转消失）
        ParallelAnimation {
            // 蓄力后拉（短促有力）
            NumberAnimation {
                target: currentImageItem
                property: "rotation"
                from: 0
                to: -25
                duration: transitionDuration / 6
                easing.type: Easing.OutQuad
            }
            NumberAnimation {
                target: currentImageItem
                property: "scale"
                from: 1.0
                to: 0.9
                duration: transitionDuration / 6
                easing.type: Easing.OutQuad
            }
        }

        // 第二阶段：旧图片加速甩出（旋转+缩小+位移同时，无淡出）
        ParallelAnimation {
            NumberAnimation {
                target: currentImageItem
                property: "scale"
                from: 0.9
                to: 0.0
                duration: transitionDuration / 2.5
                easing.type: Easing.InCubic
            }
            NumberAnimation {
                target: currentImageItem
                property: "rotation"
                from: -25
                to: 540  // 1.5圈，流畅的旋转
                duration: transitionDuration / 2.5
                easing.type: Easing.InCubic
            }
            // 螺旋轨迹（使用正弦曲线模拟自然弧线）
            NumberAnimation {
                target: currentImageItem
                property: "x"
                from: 0
                to: 0
                duration: transitionDuration / 2.5
                easing.type: Easing.InOutSine
            }
            NumberAnimation {
                target: currentImageItem
                property: "y"
                from: 0
                to: 0
                duration: transitionDuration / 2.5
                easing.type: Easing.InOutSine
            }
        }

        // 第三阶段：新图片飞入（从高速旋转减速，包含惯性摆动，无停顿）
        ParallelAnimation {
            NumberAnimation {
                target: nextImageItem
                property: "z"
                from: 0
                to: 2
                duration: 1
            }
            NumberAnimation {
                target: nextImageItem
                property: "scale"
                from: 0.0
                to: 1.0
                duration: transitionDuration / 2
                easing.type: Easing.OutCubic
            }
            // 旋转飞入带惯性摆动（连续动画，无停顿）
            SequentialAnimation {
                // 主旋转减速到位
                NumberAnimation {
                    target: nextImageItem
                    property: "rotation"
                    from: -540
                    to: 8
                    duration: transitionDuration / 2.5
                    easing.type: Easing.OutCubic
                }
                // 第一次回摆（过冲）
                NumberAnimation {
                    target: nextImageItem
                    property: "rotation"
                    from: 8
                    to: -4
                    duration: transitionDuration / 8
                    easing.type: Easing.OutQuad
                }
                // 第二次回摆（衰减）
                NumberAnimation {
                    target: nextImageItem
                    property: "rotation"
                    from: -4
                    to: 2
                    duration: transitionDuration / 8
                    easing.type: Easing.OutQuad
                }
                // 最终稳定
                NumberAnimation {
                    target: nextImageItem
                    property: "rotation"
                    from: 2
                    to: 0
                    duration: transitionDuration / 8
                    easing.type: Easing.OutQuad
                }
            }
            // 配合旋转的缩放摆动（同步进行）
            SequentialAnimation {
                NumberAnimation {
                    target: nextImageItem
                    property: "scale"
                    from: 0.0
                    to: 1.02
                    duration: transitionDuration / 2.5
                    easing.type: Easing.OutCubic
                }
                NumberAnimation {
                    target: nextImageItem
                    property: "scale"
                    from: 1.02
                    to: 0.99
                    duration: transitionDuration / 8
                    easing.type: Easing.OutQuad
                }
                NumberAnimation {
                    target: nextImageItem
                    property: "scale"
                    from: 0.99
                    to: 1.005
                    duration: transitionDuration / 8
                    easing.type: Easing.OutQuad
                }
                NumberAnimation {
                    target: nextImageItem
                    property: "scale"
                    from: 1.005
                    to: 1.0
                    duration: transitionDuration / 8
                    easing.type: Easing.OutQuad
                }
            }
            NumberAnimation {
                target: nextImageItem
                property: "opacity"
                from: 0.0
                to: 1.0
                duration: transitionDuration / 4
                easing.type: Easing.OutQuad
            }
        }

        onRunningChanged: {
            if (!running && transitioning) {
                endTransition();
            }
        }
    }

    // 钟摆摆动效果 - 旧图片像钟摆一样摆动淡出，新图片摆动进入
    SequentialAnimation {
        id: pendulumAnimation

        // 初始化
        ScriptAction {
            script: {
                nextImageItem.x = 0
                nextImageItem.y = 0
                nextImageItem.opacity = 0.0
                nextImageItem.scale = 1.0
                nextImageItem.rotation = -35
                currentImageItem.opacity = 1.0
                currentImageItem.rotation = 0
            }
        }

        // 第一阶段：旧图片钟摆摆动（向右-向左-向右然后消失）
        ParallelAnimation {
            NumberAnimation {
                target: currentImageItem
                property: "rotation"
                from: 0
                to: 35
                duration: transitionDuration / 6
                easing.type: Easing.InOutSine
            }
        }
        ParallelAnimation {
            NumberAnimation {
                target: currentImageItem
                property: "rotation"
                from: 35
                to: -30
                duration: transitionDuration / 5
                easing.type: Easing.InOutSine
            }
        }
        ParallelAnimation {
            NumberAnimation {
                target: currentImageItem
                property: "rotation"
                from: -30
                to: 25
                duration: transitionDuration / 5
                easing.type: Easing.InOutSine
            }
            NumberAnimation {
                target: currentImageItem
                property: "opacity"
                from: 1.0
                to: 0.0
                duration: transitionDuration / 5
                easing.type: Easing.OutQuad
            }
        }

        // 第二阶段：新图片钟摆摆动进入（从另一侧开始）
        ParallelAnimation {
            NumberAnimation {
                target: nextImageItem
                property: "z"
                from: 0
                to: 2
                duration: 1
            }
            NumberAnimation {
                target: nextImageItem
                property: "rotation"
                from: -35
                to: 30
                duration: transitionDuration / 5
                easing.type: Easing.InOutSine
            }
            NumberAnimation {
                target: nextImageItem
                property: "opacity"
                from: 0.0
                to: 1.0
                duration: transitionDuration / 6
                easing.type: Easing.InQuad
            }
        }
        ParallelAnimation {
            NumberAnimation {
                target: nextImageItem
                property: "rotation"
                from: 30
                to: -20
                duration: transitionDuration / 5
                easing.type: Easing.InOutSine
            }
        }
        ParallelAnimation {
            NumberAnimation {
                target: nextImageItem
                property: "rotation"
                from: -20
                to: 10
                duration: transitionDuration / 6
                easing.type: Easing.InOutSine
            }
        }
        ParallelAnimation {
            NumberAnimation {
                target: nextImageItem
                property: "rotation"
                from: 10
                to: 0
                duration: transitionDuration / 6
                easing.type: Easing.InOutSine
            }
        }

        onRunningChanged: {
            if (!running && transitioning) {
                endTransition();
            }
        }
    }

    // 挤压（横向）效果 - 旧图片从右向左被挤压消失，新图片从左向右展开
    SequentialAnimation {
        id: horizontalRollAnimation

        // 初始化
        ScriptAction {
            script: {
                nextImageItem.x = 0
                nextImageItem.y = 0
                nextImageItem.opacity = 1.0
                nextImageItem.scale = 1.0
                // 新图片：原点左侧，横向缩放为0（从左边展开）
                horizontalScale.origin.x = 0
                horizontalScale.origin.y = nextImageItem.height / 2
                horizontalScale.xScale = 0.001
                horizontalScale.yScale = 1.0
                // 旧图片：原点右侧，正常状态（向左挤压消失）
                currentHorizontalScale.origin.x = currentImageItem.width
                currentHorizontalScale.origin.y = currentImageItem.height / 2
                currentHorizontalScale.xScale = 1.0
                currentHorizontalScale.yScale = 1.0
            }
        }

        // 同时进行：旧图片被挤压消失，新图片展开
        ParallelAnimation {
            // 新图片从左向右横向展开
            NumberAnimation {
                target: horizontalScale
                property: "xScale"
                from: 0.001
                to: 1.0
                duration: transitionDuration
                easing.type: Easing.OutCubic
            }
            // 旧图片从左向右被挤压消失
            NumberAnimation {
                target: currentHorizontalScale
                property: "xScale"
                from: 1.0
                to: 0.001
                duration: transitionDuration
                easing.type: Easing.OutCubic
            }
        }

        onRunningChanged: {
            if (!running && transitioning) {
                endTransition()
            }
        }
    }

    // 挤压（纵向）效果 - 旧图片从上向下被挤压消失，新图片从上向下展开
    SequentialAnimation {
        id: verticalRollAnimation

        // 初始化
        ScriptAction {
            script: {
                nextImageItem.x = 0
                nextImageItem.y = 0
                nextImageItem.opacity = 1.0
                nextImageItem.scale = 1.0
                // 新图片：原点顶部，纵向缩放为0（从上展开）
                verticalScale.origin.x = nextImageItem.width / 2
                verticalScale.origin.y = 0
                verticalScale.xScale = 1.0
                verticalScale.yScale = 0.001
                // 旧图片：原点底部，正常状态（向上挤压消失）
                currentVerticalScale.origin.x = currentImageItem.width / 2
                currentVerticalScale.origin.y = currentImageItem.height
                currentVerticalScale.xScale = 1.0
                currentVerticalScale.yScale = 1.0
            }
        }

        // 同时进行：旧图片被挤压消失，新图片展开
        ParallelAnimation {
            // 新图片从上向下纵向展开
            NumberAnimation {
                target: verticalScale
                property: "yScale"
                from: 0.001
                to: 1.0
                duration: transitionDuration
                easing.type: Easing.OutCubic
            }
            // 旧图片从上向下被挤压消失
            NumberAnimation {
                target: currentVerticalScale
                property: "yScale"
                from: 1.0
                to: 0.001
                duration: transitionDuration
                easing.type: Easing.OutCubic
            }
        }

        onRunningChanged: {
            if (!running && transitioning) {
                endTransition()
            }
        }
    }

    // 定时器用于更新着色器属性
    Timer {
        id: updateTimer
        interval: 16  // 约60 FPS
        running: false
        repeat: true
        property real startTime: 0
        onTriggered: {
            var elapsed = Date.now() - startTime
            var duration = transitionDuration
            var t = Math.min(elapsed / duration, 1.0)

            // 使用缓动函数
            var easeT = t < 0.5 ? 2 * t * t : 1 - Math.pow(-2 * t + 2, 2) / 2;

            // 直接更新着色器的progress属性
            shaderEffectItem.transitionProgress = easeT

            if (t >= 1.0) {
                updateTimer.stop()
                endTransition()
            }
        }

        onRunningChanged: {
            if (running) {
                startTime = Date.now()
            }
        }
    }

    // Y轴翻转2圈动画效果 - 旧图Y轴翻转2圈+变小消失，新图从中心点变大+Y轴翻转2圈复原
    SequentialAnimation {
        id: flipScaleAnimation

        // 第一阶段：旧图片翻转+变小→中心点消失
        ParallelAnimation {
            // 确保新图片在旧图片上面
            NumberAnimation {
                target: nextImageItem
                property: "z"
                from: 0
                to: 2
                duration: 1
            }

            // 翻转：Y轴旋转360度（easeOut让翻转更自然）
            NumberAnimation {
                target: currentRotation
                property: "angle"
                from: 0
                to: -360
                duration: transitionDuration / 2
                easing.type: Easing.OutCubic
            }

            // 变小：scale从1降到0（easeOut让变小过程更平滑）
            NumberAnimation {
                target: currentImageItem
                property: "scale"
                from: 1.0
                to: 0.0
                duration: transitionDuration / 2
                easing.type: Easing.OutCubic
            }

            // 透明度：逐渐消失
            NumberAnimation {
                target: currentImageItem
                property: "opacity"
                from: 1.0
                to: 0.0
                duration: transitionDuration / 2
                easing.type: Easing.OutCubic
            }
        }

        // 第二阶段：新图片从中心点→翻转+变大→复原
        ParallelAnimation {
            // 翻转：从360度翻转到0度（easeIn让翻转更自然）
            NumberAnimation {
                target: nextRotation
                property: "angle"
                from: 360
                to: 0
                duration: transitionDuration / 2
                easing.type: Easing.InCubic
            }

            // 变大：scale从0增大到1（easeIn让变大过程更自然）
            NumberAnimation {
                target: nextImageItem
                property: "scale"
                from: 0.0
                to: 1.0
                duration: transitionDuration / 2
                easing.type: Easing.InCubic
            }

            // 透明度：逐渐显现
            NumberAnimation {
                target: nextImageItem
                property: "opacity"
                from: 0.0
                to: 1.0
                duration: transitionDuration / 2
                easing.type: Easing.InCubic
            }
        }

        onRunningChanged: {
            if (!running && transitioning) {
                endTransition()
            }
        }
    }

    // X轴翻转2圈动画效果 - 旧图X轴翻转2圈+变小消失，新图从中心点变大+X轴翻转2圈复原
    SequentialAnimation {
        id: flipScaleXAnimation

        // 第一阶段：旧图片X轴翻转2圈+变小→中心点消失
        ParallelAnimation {
            // 确保新图片在旧图片上面
            NumberAnimation {
                target: nextImageItem
                property: "z"
                from: 0
                to: 2
                duration: 1
            }

            // X轴翻转：X轴旋转360度（easeOut让翻转更自然）
            NumberAnimation {
                target: currentRotationX
                property: "angle"
                from: 0
                to: -360
                duration: transitionDuration / 2
                easing.type: Easing.OutCubic
            }

            // 变小：scale从1降到0（easeOut让变小过程更平滑）
            NumberAnimation {
                target: currentImageItem
                property: "scale"
                from: 1.0
                to: 0.0
                duration: transitionDuration / 2
                easing.type: Easing.OutCubic
            }

            // 透明度：逐渐消失
            NumberAnimation {
                target: currentImageItem
                property: "opacity"
                from: 1.0
                to: 0.0
                duration: transitionDuration / 2
                easing.type: Easing.OutCubic
            }
        }

        // 第二阶段：新图片从中心点→X轴翻转2圈+变大→复原
        ParallelAnimation {
            // X轴翻转：从360度翻转到0度（easeIn让翻转更自然）
            NumberAnimation {
                target: nextRotationX
                property: "angle"
                from: 360
                to: 0
                duration: transitionDuration / 2
                easing.type: Easing.InCubic
            }

            // 变大：scale从0增大到1（easeIn让变大过程更自然）
            NumberAnimation {
                target: nextImageItem
                property: "scale"
                from: 0.0
                to: 1.0
                duration: transitionDuration / 2
                easing.type: Easing.InCubic
            }

            // 透明度：逐渐显现
            NumberAnimation {
                target: nextImageItem
                property: "opacity"
                from: 0.0
                to: 1.0
                duration: transitionDuration / 2
                easing.type: Easing.InCubic
            }
        }

        onRunningChanged: {
            if (!running && transitioning) {
                endTransition()
            }
        }
    }
}