import QtQuick

Item {
    id: transitionItem

    property url currentSource: ""
    property url nextSource: ""
    property int transitionDuration: 5000  // 过渡持续时间，延长到5秒
    property bool transitioning: false  // 是否正在过渡
    property int transitionType: 0  // 过渡效果类型：0=溶解, 1=马赛克, 2=波纹, 3=水波, 4=从左向右擦除, 5=从右向左擦除, 6=从上向下擦除, 7=从下向上擦除, 8=X轴窗帘, 9=Y轴窗帘, 10=故障, 11=旋转, 12=拉伸, 13=百叶窗
    property string shaderPath: "qrc:/assets/shaders/qsb/transitions.frag.qsb"  // 着色器路径
    signal transitionCompleted

    // 溶解过渡进度属性
    property real progress: 0.0

    // 调试：显示过渡进度和着色器状态
    Text {
        id: debugText
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.margins: 10
        color: "white"
        font.pixelSize: 14
        text: "Progress: " + progress.toFixed(2) + "\nEffect: " + transitionType
        z: 10
        visible: true
        style: Text.Outline
        styleColor: "black"
    }

    // 源图像容器
    Item {
        id: fromContainer
        anchors.fill: parent
        visible: false  // 隐藏源项

        // 白色背景，填充非图片区域
        Rectangle {
            anchors.fill: parent
            color: "white"
        }

        Image {
            id: fromImage
            anchors.centerIn: parent
            fillMode: Image.PreserveAspectFit
            width: Math.min(parent.width, parent.height * (sourceSize.width / Math.max(sourceSize.height, 1)))
            height: Math.min(parent.height, parent.width / (sourceSize.width / Math.max(sourceSize.height, 1)))
            asynchronous: true
        }
    }

    // 目标图像容器
    Item {
        id: toContainer
        anchors.fill: parent
        visible: false  // 隐藏源项

        // 白色背景，填充非图片区域
        Rectangle {
            anchors.fill: parent
            color: "white"
        }

        Image {
            id: toImage
            anchors.centerIn: parent
            fillMode: Image.PreserveAspectFit
            width: Math.min(parent.width, parent.height * (sourceSize.width / Math.max(sourceSize.height, 1)))
            height: Math.min(parent.height, parent.width / (sourceSize.width / Math.max(sourceSize.height, 1)))
            asynchronous: true
        }
    }

    // 源图像的着色器源
    ShaderEffectSource {
        id: fromTex
        sourceItem: fromContainer
        hideSource: true
        layer.enabled: true
        layer.samples: 4
        layer.mipmap: false
        anchors.fill: parent
        live: true
        Component.onCompleted: console.log("fromTex initialized")
    }

    // 目标图像的着色器源
    ShaderEffectSource {
        id: toTex
        sourceItem: toContainer
        hideSource: true
        layer.enabled: true
        layer.samples: 4
        layer.mipmap: false
        anchors.fill: parent
        live: true
        Component.onCompleted: console.log("toTex initialized")
    }
    
    // 过渡效果 - 使用通用着色器支持多种效果
    ShaderEffect {
        id: dissolveEffect
        anchors.fill: parent
        visible: transitioning  // 只在过渡时显示
        z: 10

        // 设置着色器源文件
        fragmentShader: transitionItem.shaderPath

        // 着色器输入参数 - 分别使用两个着色器源
        property var from: fromTex
        property var to: toTex

        // 添加自定义 uniform
        property real progress: transitionItem.progress
        property int effectType: transitionItem.transitionType

        // 支持高DPI缩放
        supportsAtlasTextures: false

        // 调试：当着色器加载失败时显示备用效果
        Component.onCompleted: {
            console.log("=== ShaderEffect Debug ===")
            console.log("fragmentShader:", fragmentShader)
            console.log("effectType:", effectType)
            console.log("fromTex.sourceItem:", fromTex.sourceItem)
            console.log("toTex.sourceItem:", toTex.sourceItem)
            console.log("fromTex.valid:", fromTex.sourceItem !== undefined)
            console.log("toTex.valid:", toTex.sourceItem !== undefined)
            console.log("========================")
        }

        // 监听着色器错误
        onLogChanged: {
            if (log && log.length > 0) {
                console.log("=== ShaderEffect Log ===")
                console.log(log)
                console.log("========================")
            }
        }

        // 监听状态
        onStatusChanged: {
            console.log("ShaderEffect status:", status)
        }
    }

    // 备用效果：使用两个 Image + opacity 动画
    // 只在不过渡时显示
    Image {
        id: fromImageFallback
        anchors.fill: parent
        fillMode: Image.PreserveAspectFit
        source: fromImage.source
        opacity: transitioning ? 0 : 1
        visible: !transitioning
        z: 5
    }

    Image {
        id: toImageFallback
        anchors.fill: parent
        fillMode: Image.PreserveAspectFit
        source: toImage.source
        opacity: transitioning ? 0 : 1
        visible: !transitioning
        z: 5
    }
    
    // 过渡动画 - 使用Timer手动更新progress
    Timer {
        id: transitionTimer
        interval: 16 // 约60fps
        repeat: true
        property real startTime: 0
        onTriggered: {
            var elapsed = Date.now() - startTime
            var duration = transitionItem.transitionDuration
            var t = Math.min(elapsed / duration, 1.0)
            // 使用缓动函数
            var easeT = easeInOutQuad(t)
            transitionItem.progress = easeT
            console.log("Progress updated:", easeT.toFixed(2))
            if (t >= 1.0) {
                transitionTimer.stop()
                transitionItem.endTransition()
            }
        }
    }
    
    // InOutQuad缓动函数
    function easeInOutQuad(t) {
        return t < 0.5 ? 2 * t * t : 1 - Math.pow(-2 * t + 2, 2) / 2;
    }
    
    

    // 启动过渡
    function loadImage(newSource) {
        console.log("loadImage called:", newSource)

        if (transitioning) {
            // 如果正在过渡，立即停止当前过渡并开始新过渡
            console.log("Interrupting current transition")
            stopAnimations()

            // 中断时，fromImage 应该使用当前正在显示的图片（也就是 toImage）
            // 因为当前正在从 currentSource 过渡到 nextSource
            // 但实际上当前显示的是两者的混合状态，更接近 nextSource
            // 所以我们更新 currentSource 为 nextSource，然后继续新的过渡
            console.log("Before interrupt - currentSource:", currentSource, ", nextSource:", nextSource)
            currentSource = nextSource
            console.log("After interrupt - currentSource:", currentSource)
            transitioning = false
        }

        if (currentSource === "") {
            // 第一次加载图片
            console.log("First load, no transition")
            currentSource = newSource
            fromImage.source = currentSource
            toImage.source = currentSource
            // 设置 fallback 图片
            fromImageFallback.source = currentSource
            fromImageFallback.opacity = 0
            toImageFallback.source = currentSource
            toImageFallback.opacity = 1
            return
        }

        // 设置新图片源
        nextSource = newSource

        // 检查新图片和当前图片是否相同
        if (currentSource === newSource) {
            // 如果新图片和当前图片相同，不需要过渡
            return
        }

        // 设置图像源
        fromImage.source = currentSource
        toImage.source = nextSource

        console.log("Set image sources:")
        console.log("  currentSource:", currentSource)
        console.log("  nextSource:", nextSource)
        console.log("  fromImage.source:", fromImage.source)
        console.log("  toImage.source:", toImage.source)

        // 重置进度并恢复 shader
        progress = 0.0
        resetShader()

        // 开始过渡
        transitioning = true

        // 启动过渡动画 - 使用Timer
        console.log("Starting transition timer")
        transitionTimer.startTime = Date.now()
        transitionTimer.start()
    }
    
    // 监听progress变化
    onProgressChanged: {
        console.log("Progress changed: " + progress.toFixed(2))
    }

    // 结束过渡
    function endTransition() {
        // 更新当前图片源
        currentSource = nextSource

        // 重置状态
        progress = 0.0
        transitioning = false

        // 更新两个图像都为新图片
        fromImage.source = currentSource
        toImage.source = currentSource

        // 更新 fallback 图片
        fromImageFallback.source = currentSource
        fromImageFallback.opacity = 0
        toImageFallback.source = currentSource
        toImageFallback.opacity = 1

        transitionCompleted()
    }

    // 强制结束过渡（用于中断）
    function forceEndTransition() {
        // 直接更新到新图片，不完成当前动画
        currentSource = nextSource

        // 重置状态
        progress = 0.0
        transitioning = false

        // 更新两个图像都为新图片
        fromImage.source = currentSource
        toImage.source = currentSource

        // 更新 fallback 图片
        fromImageFallback.source = currentSource
        fromImageFallback.opacity = 0
        toImageFallback.source = currentSource
        toImageFallback.opacity = 1
    }

    function resetShader() {
        dissolveEffect.visible = true
        fromImageFallback.opacity = 1.0 - transitionItem.progress
        toImageFallback.opacity = transitionItem.progress
    }

    // 停止所有动画
    function stopAnimations() {
        transitionTimer.stop()
    }
}