import QtQuick
import QtQuick.Window
import QtQuick.Controls
import QtQuick.Layouts
import StyleManager 1.0

Window {
    id: window
    width: 800
    height: 600
    visible: true
    title: "图片数据库管理器"

    // 图片资源路径
    readonly property var imageSources: [
        "qrc:/assets/1.jpg",
        "qrc:/assets/2.jpg",
        "qrc:/assets/3.jpg",
        "qrc:/assets/4.jpg"
    ]

    property int currentImageIndex: 0
    property StyleManager styleManager: StyleManager {}
    property string currentStyle: styleManager.getStyle()

    // 过渡效果类型映射
    readonly property var transitionNames: [
        "溶解", "马赛克", "波纹", "水波",
        "从左向右擦除", "从右向左擦除", "从上向下擦除", "从下向上擦除",
        "X轴窗帘", "Y轴窗帘",
        "故障",
        "旋转",
        "拉伸",
        "百叶窗"
    ]

    // 过渡时间选项（秒）
    readonly property var durationOptions: [0, 0.5, 1, 1.5, 2, 2.5, 3, 4, 5, 6, 7, 8, 9, 10]

    // 样式选项
    readonly property var styleNames: ["Basic", "Fusion", "Imagine", "Material", "Universal", "Windows"]

    // 主布局
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 10

        // 图片显示区域
        Item {
            id: imageContainer
            Layout.fillWidth: true
            Layout.fillHeight: true

            // 图片过渡效果组件 - 作为主要图片显示
            ImageTransition {
                id: imageTransition
                anchors.fill: parent
                transitionDuration: 5000  // 设置过渡时间为5秒
                onTransitionCompleted: {
                    // 过渡完成后的处理
                    console.log("Transition completed")
                }
            }
        }

        // 按钮区域
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 10

            Button {
                text: "上一张"
                onClicked: showPreviousImage()
            }

            Button {
                text: "下一张"
                onClicked: showNextImage()
            }

            ComboBox {
                id: effectCombo
                model: transitionNames
                currentIndex: 0
                onCurrentIndexChanged: {
                    imageTransition.transitionType = currentIndex
                }
            }

            ComboBox {
                id: durationCombo
                model: durationOptions
                currentIndex: durationOptions.indexOf(5)  // 默认5秒
                displayText: currentIndex >= 0 ? (currentIndex === 0 ? "无过渡" : durationOptions[currentIndex] + "秒") : ""
                onCurrentIndexChanged: {
                    if (currentIndex >= 0) {
                        imageTransition.transitionDuration = durationOptions[currentIndex] * 1000  // 转换为毫秒
                    }
                }
            }

            ComboBox {
                id: styleCombo
                model: styleNames
                currentIndex: styleNames.indexOf(currentStyle) >= 0 ? styleNames.indexOf(currentStyle) : 5
                displayText: styleNames[currentIndex] + (currentIndex >= 0 ? "" : "")
                onCurrentIndexChanged: {
                    if (currentIndex >= 0) {
                        styleManager.setStyle(styleNames[currentIndex])
                        // 提示用户需要重启应用才能生效
                        styleDialog.open()
                    }
                }
            }

            Dialog {
                id: styleDialog
                title: "样式切换提示"
                modal: true
                anchors.centerIn: parent

                Label {
                    text: "样式已保存，请重启应用程序以应用新样式。"
                    padding: 20
                }

                standardButtons: Dialog.Ok
            }
        }
    }

    // 切换到下一张图片
    function showNextImage() {
        var nextIndex = (currentImageIndex + 1) % imageSources.length
        showImage(nextIndex)
    }

    // 切换到上一张图片
    function showPreviousImage() {
        var prevIndex = (currentImageIndex - 1 + imageSources.length) % imageSources.length
        showImage(prevIndex)
    }

    // 显示指定索引的图片
    function showImage(index) {
        if (index < 0 || index >= imageSources.length) return

        // 开始过渡
        startTransition(index)
    }

    // 开始过渡动画
    function startTransition(index) {
        // 直接加载新图片并开始过渡（默认使用溶解效果）
        imageTransition.loadImage(imageSources[index])
        // 更新当前图片索引
        currentImageIndex = index
    }
}