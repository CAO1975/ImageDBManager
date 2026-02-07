# ImageDBManager

一款功能强大的图片数据库管理工具，支持分组管理、幻灯片播放和 80+ 种 GPU 加速的过渡效果。

![版本](https://img.shields.io/badge/version-1.0-blue)
![平台](https://img.shields.io/badge/platform-Windows%2010%2B-blue)
![协议](https://img.shields.io/badge/license-MIT-green)
![Qt](https://img.shields.io/badge/Qt-6.x-green)

## ✨ 功能特性

### 核心功能
- 📁 **分组管理** - 支持多级分组，无限层级嵌套
- 📥 **导入导出** - 批量导入图片，支持导出到指定文件夹
- 🖼️ **全屏浏览** - 支持滚轮缩放、键盘导航
- ▶️ **幻灯片播放** - 可自定义播放间隔时间

### 视觉体验
- 🎨 **80+ 种过渡效果** - 包括着色器特效（马赛克、水波、粒子等）
- ⚡ **GPU 加速** - 基于 OpenGL 着色器的高性能渲染
- 🎭 **自定义主题** - 支持背景和强调色自定义
- 🌙 **深色主题** - 护眼暗色界面设计

### 数据安全
- 💾 **SQLite 数据库** - 所有图片存储在单个数据库文件中
- 📦 **便携设计** - 可放置于 U 盘随身携带
- 🔄 **自动保存** - 窗口状态、主题设置自动记忆

## 📸 界面预览

> 此处可添加软件截图

## 📥 下载安装

### 系统要求
- Windows 10 或更高版本
- 支持 OpenGL 3.3 的显卡
- 存储空间：100MB+

### 下载方式

前往 [GitHub Releases](https://github.com/ABCCao/ImageDBManager/releases) 下载最新版本。

#### 方案一：便携版（推荐）
**ImageDBManager-v1.0-Portable.exe** - 单文件便携版

- 无需安装，双击即可运行
- 所有依赖已打包，适合放入 U 盘随身携带
- 首次启动可能稍慢（需要解压到内存）

#### 方案二：标准版
**ImageDBManager-v1.0.zip** - 完整依赖包

- 解压后运行 `ImageDBManager.exe`
- 包含所有 Qt6 依赖文件（DLL）
- 符合 LGPL 协议，可自行替换 Qt 库

> **提示**：便携版使用虚拟化打包技术。如需替换 Qt 库或遇到杀毒软件误报，请使用标准版。

### 编译构建

```bash
# 克隆仓库
git clone https://github.com/ABCCao/ImageDBManager.git
cd ImageDBManager

# 使用 Qt Creator 打开 CMakeLists.txt
# 或命令行构建
mkdir build && cd build
cmake ..
cmake --build . --config Release

# 编译着色器
compile_shader.bat
```

## 🚀 快速开始

1. 运行 `ImageDBManager.exe`
2. 点击「导入图片」按钮选择图片文件
3. 在左侧分组树创建分组（右键菜单）
4. 双击图片进入全屏浏览模式
5. 上下键切换图片，ESC 退出全屏

## 📂 项目结构

```
ImageDBManager/
├── main.cpp              # 程序入口
├── database.{h,cpp}      # 数据库操作模块
├── imageprovider.{h,cpp} # 图片加载与缓存
├── CMakeLists.txt        # CMake 构建配置
├── qml/                  # QML 界面文件
│   ├── Main.qml          # 主窗口
│   ├── ImageViewer.qml   # 图片查看器（含过渡动画）
│   ├── GroupTree.qml     # 分组树组件
│   ├── ImageList.qml     # 图片列表组件
│   └── ColorUtils.js     # 颜色工具函数
├── shaders/              # GLSL 着色器
│   └── transitions.frag  # 过渡效果着色器
└── build/                # 构建输出目录
```

## 🛠️ 技术栈

- **Qt 6.x** - 跨平台 GUI 框架
- **QML** - 声明式 UI 设计语言
- **OpenGL/GLSL** - 图形渲染与着色器
- **SQLite** - 嵌入式数据库
- **CMake** - 构建系统

## 🤝 参与贡献

欢迎提交 Issue 和 Pull Request！

1. Fork 本仓库
2. 创建特性分支 (`git checkout -b feature/AmazingFeature`)
3. 提交更改 (`git commit -m 'Add some AmazingFeature'`)
4. 推送分支 (`git push origin feature/AmazingFeature`)
5. 创建 Pull Request

## 📄 开源协议

本项目基于 [MIT](LICENSE) 协议开源。

## 🙏 致谢

- [Qt Framework](https://www.qt.io/) - 强大的跨平台开发框架
- 所有贡献者和用户

## 💖 支持开发者

如果这个软件对你有帮助，欢迎打赏支持！

> 此处可添加微信/支付宝收款二维码

---

**联系方式**
- QQ: 1920867856
- Email: abccao1975@163.com
