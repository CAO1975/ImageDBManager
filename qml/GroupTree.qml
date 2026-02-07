import QtQuick
import QtQuick.Controls
import "ColorUtils.js" as ColorUtils

Item {
    property color customBackground: '#112233'
    property color customAccent: '#30638f'
    id: groupTree

    // 背景矩形
    Rectangle {
        anchors.fill: parent
        color: customBackground
        border.color: customAccent
        border.width: 1
        radius: 8
        z: -1
    }

    // 定义信号，用于通知父组件选择了分组
    signal groupSelected(int groupId)
    
    // 定义信号，用于通知父组件右键点击了分组
    signal groupRightClicked(int groupId, string groupName)
    
    // 定义属性，用于存储每个分组的展开状态
    property var expandedStates: ({})
    
    // 存储分组的父子关系映射，key: 子分组ID, value: 父分组ID
    property var groupParentMap: ({})
    
    // 存储当前正在折叠的分组ID，用于后续的选中项处理
    property int foldingGroupId: -1
    
    // 存储当前选中的分组ID
    property int currentSelectedGroupId: -1
    
    // 加载分组数据
    function loadGroups() {
        // 保存当前选中的分组ID
        var previouslySelectedId = currentSelectedGroupId;
        
        // 清空现有数据
        mainGroupListModel.clear()
        
        // 添加"未分组"选项
        mainGroupListModel.append({
            "name": "未分组",
            "id": -1,
            "depth": 0,
            "hasChildren": false,
            "expanded": true,
            "parentId": 0
        })
        
        // 从数据库加载分组数据
        var groups = database.getAllGroups()
        
        if (groups && groups.length > 0) {
            // 构建完整的树结构
        function buildTree(groupList, depth, parentId) {
            // 创建新的父子关系映射对象
            var newParentMap = {}
            
            // 递归构建树并生成父子关系映射
            function buildTreeRecursive(groups, parentGroupId) {
                for (var i = 0; i < groups.length; i++) {
                    var group = groups[i]
                    var hasChildren = !!(group.children && group.children.length > 0)
                    
                    // 确保ID是数字类型
                    var groupIdNum = Number(group.id)
                    
                    // 添加到父子关系映射
                    if (parentGroupId > 0) {
                        newParentMap[groupIdNum] = parentGroupId
                    }
                    
                    // 如果有子节点，则递归处理
                    if (hasChildren) {
                        buildTreeRecursive(group.children, groupIdNum)
                    }
                }
            }
            
            // 生成父子关系映射
            buildTreeRecursive(groupList, 0)
            
            // 更新全局的父子关系映射
            groupTree.groupParentMap = newParentMap
            
            // 构建模型
            for (var j = 0; j < groupList.length; j++) {
                var group = groupList[j]
                var hasChildren = !!(group.children && group.children.length > 0)
                
                // 确保ID是数字类型，并从expandedStates中读取状态
                var groupIdNum = Number(group.id)
                var isExpanded = groupTree.expandedStates[groupIdNum] !== undefined ? groupTree.expandedStates[groupIdNum] : true
                
                // 添加当前分组到模型
                mainGroupListModel.append({
                    "name": group.name || "Unknown",
                    "id": groupIdNum,
                    "depth": depth,
                    "hasChildren": hasChildren,
                    "expanded": isExpanded,
                    "parentId": parentId || 0
                })
                
                // 如果有子节点且当前节点是展开的，则递归添加子节点
                if (hasChildren && isExpanded) {
                    buildTree(group.children, depth + 1, groupIdNum)
                }
            }
        }
            
            // 开始构建树
            buildTree(groups, 0, 0)
        }
        
        // 恢复或调整选中状态
        updateSelectionAfterLoad(previouslySelectedId);
    }
    
    // 更新选中状态
    function updateSelectionAfterLoad(previouslySelectedId) {
        // 查找之前选中的分组是否在当前模型中
        var foundIndex = -1;
        for (var i = 0; i < mainGroupListModel.count; i++) {
            if (mainGroupListModel.get(i).id === previouslySelectedId) {
                foundIndex = i;
                break;
            }
        }

        // 如果找到了之前选中的分组，设置为当前选中项
        if (foundIndex !== -1) {
            groupListView.currentIndex = foundIndex;
            currentSelectedGroupId = previouslySelectedId;
        }
        // 如果没找到，且有正在折叠的分组ID
        else if (foldingGroupId !== -1) {
            // 查找被折叠分组在模型中的位置
            for (var j = 0; j < mainGroupListModel.count; j++) {
                if (mainGroupListModel.get(j).id === foldingGroupId) {
                    groupListView.currentIndex = j;
                    currentSelectedGroupId = foldingGroupId;
                    groupTree.groupSelected(foldingGroupId);
                    // 重置foldingGroupId
                    foldingGroupId = -1;
                    return;
                }
            }

            // 重置foldingGroupId
            foldingGroupId = -1;
        }
    }
    
    // 切换分组展开状态
    function toggleGroupExpanded(groupId) {
        // 确保groupId是数字类型
        groupId = Number(groupId)

        // 获取当前分组的展开状态，默认为true
        var currentState = groupTree.expandedStates[groupId] !== undefined ? groupTree.expandedStates[groupId] : true

        // 切换当前分组的展开状态
        var newExpandedState = !currentState

        // 创建新的对象以确保QML能检测到属性变化
        var newStates = {}
        for (var key in groupTree.expandedStates) {
            newStates[key] = groupTree.expandedStates[key]
        }
        newStates[groupId] = newExpandedState

        // 保存新的展开状态到expandedStates中
        groupTree.expandedStates = newStates

        // 如果是折叠操作，保存当前正在折叠的分组ID
        if (!newExpandedState) {
            foldingGroupId = groupId;
        } else {
            foldingGroupId = -1;
        }

        // 重新加载分组数据，应用新的展开状态
        loadGroups()
    }
    
    // 递归数据模型
    ListModel {
        id: mainGroupListModel
    }
    
    // 自定义委托组件
    Component {
        id: groupDelegate
        Item {
            id: delegateRoot
            width: ListView.view ? ListView.view.width : parent ? parent.width : 100
            height: 30
            
            // 选中状态背景
            Rectangle {
                id: backgroundRect
                anchors.fill: parent
                color: groupListView.currentIndex === index ? customAccent : "transparent"
                radius: 4
                border.color: groupListView.currentIndex === index ? customAccent : "transparent"
                border.width: groupListView.currentIndex === index ? 2 : 0
            }
            
            // 使用 Item 作为容器，手动布局子元素
            Item {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                height: 24  // 统一按钮和文本的高度
                
                // 缩进空间（视觉元素）
                Item {
                    width: model.depth * 20
                    height: 24
                }
                
                // 展开/折叠按钮
                Rectangle {
                    id: expandButton
                    x: model.depth * 20
                    width: model.hasChildren ? 24 : 0
                    height: 24
                    color: model.hasChildren ? customAccent : "transparent"
                    radius: 12
                    
                    Text {
                        text: model.expanded ? "⯆" : "⯈"
                        color: "white"
                        anchors.centerIn: parent
                        font.bold: true
                        font.pixelSize: 18
                        visible: model.hasChildren
                    }
                }
                
                // 分组名称
                Text {
                    id: groupNameText
                    x: model.depth * 20 + (model.hasChildren ? 25 : 5)
                    width: parent.width - x
                    height: 24
                    text: model.name
                    color: groupListView.currentIndex === index ? "#E8F4FD" : ColorUtils.getTextColor(customBackground)
                    font.pointSize: 12
                    verticalAlignment: Text.AlignVCenter
                    elide: Text.ElideRight  // 文本过长时显示省略号
                }
            }
            

            
            // 统一的鼠标事件处理区域
            MouseArea {
                anchors.fill: parent
                
                // 捕获所有按钮的点击事件
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                
                onClicked: function(mouse) {
                    // 只处理左键点击
                    if (mouse.button === Qt.LeftButton) {
                        // 计算按钮的 X 坐标范围
                        var buttonXStart = model.depth * 20
                        var buttonXEnd = buttonXStart + (model.hasChildren ? 20 : 0)

                        // 判断是否点击在展开/折叠按钮上
                        if (model.hasChildren && mouse.x >= buttonXStart && mouse.x <= buttonXEnd) {
                            // 切换分组展开状态
                            groupTree.toggleGroupExpanded(model.id)
                        } else {
                            // 否则认为是分组项点击
                            groupListView.currentIndex = index
                            // 只有当点击的分组ID与当前选中的分组ID不同时，才发送分组选择信号
                            if (model.id !== currentSelectedGroupId) {
                                // 更新当前选中的分组ID
                                currentSelectedGroupId = model.id
                                // 选择分组后发送信号，通知父组件
                                groupTree.groupSelected(model.id)
                            }
                        }
                    }
                }

                // 处理右键点击
                onReleased: function(mouse) {
                    if (mouse.button === Qt.RightButton) {
                        // 所有分组（包括未分组）都可以右键
                        // 发送右键点击信号给父组件
                        groupTree.groupRightClicked(model.id, model.name)
                    }
                }
            }
        }
    }
    
    // ListView组件
    ListView {
        id: groupListView
        anchors.fill: parent
        anchors.margins: 5
        model: mainGroupListModel
        delegate: groupDelegate
        clip: true

        ScrollBar.vertical: styledScrollBar.createObject(groupListView)
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
    
    // 组件加载完成后初始化数据
    Component.onCompleted: {
        // 初始化expandedStates为空对象
        groupTree.expandedStates = ({})
        // 加载分组数据
        loadGroups()
    }
}