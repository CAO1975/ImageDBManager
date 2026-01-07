cmake_minimum_required(VERSION 3.30.5)  # 降低版本要求
project(ImageDBManager VERSION 1.0 LANGUAGES CXX)

# 设置并行构建线程数
set(CMAKE_BUILD_PARALLEL_LEVEL 8)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# 设置为发布版本
set(CMAKE_BUILD_TYPE Release)

# 添加编译优化选项，减小exe体积
set(CMAKE_CXX_FLAGS_RELEASE "${CMAKE_CXX_FLAGS_RELEASE} -O3 -march=native -fdata-sections -ffunction-sections -fno-ident -static")
set(CMAKE_EXE_LINKER_FLAGS_RELEASE "${CMAKE_EXE_LINKER_FLAGS_RELEASE} -Wl,--gc-sections -Wl,--strip-all -Wl,--as-needed -static")
set(CMAKE_SHARED_LINKER_FLAGS_RELEASE "${CMAKE_SHARED_LINKER_FLAGS_RELEASE} -static")

# 禁用调试信息
set(CMAKE_CXX_FLAGS_RELEASE "${CMAKE_CXX_FLAGS_RELEASE} -g0")

# 优化Qt库的使用
set(QT_NO_LINK_QTMAIN TRUE)

# 简化Qt路径设置
set(CMAKE_PREFIX_PATH "D:/Programming/QT/6.10.1/mingw_64")

# 禁用不必要的Qt特性（必须在find_package之前设置）
set(QT_FEATURE_opengl OFF CACHE BOOL "Disable OpenGL support" FORCE)
set(QT_FEATURE_widgets OFF CACHE BOOL "Disable Widgets support" FORCE)
set(QT_FEATURE_testlib OFF CACHE BOOL "Disable Testlib support" FORCE)
set(QT_FEATURE_gui_opengl OFF CACHE BOOL "Disable OpenGL in GUI" FORCE)

# 仅链接使用的Controls样式
set(QT_QUICK_CONTROLS_STYLE "Universal" CACHE STRING "Qt Quick Controls style" FORCE)

# 查找Qt组件（移除QmlCompiler和不必要的组件）
find_package(Qt6 REQUIRED COMPONENTS 
    Core Gui Sql Quick Qml QuickControls2 Concurrent
)

set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)
set(CMAKE_AUTOUIC ON)

# 创建可执行文件
add_executable(${PROJECT_NAME}
    main.cpp
    database.cpp
    database.h
    imageprovider.cpp
    imageprovider.h
)

# 最简QML模块配置
qt_add_qml_module(${PROJECT_NAME}
    URI ImageDBManager
    VERSION 1.0
    RESOURCE_PREFIX "/"           # 关键修复！使用根路径
    NO_GENERATE_PLUGIN_SOURCE
    QML_FILES
        qml/Main.qml
        qml/GroupTree.qml
        qml/ImageList.qml
        qml/ImageViewer.qml
)

qt_add_resources(${PROJECT_NAME} "image_resources"
    PREFIX "/assets"
    FILES
        shaders/qsb/transitions.frag.qsb
)

# 启用QML编译器，减少运行时依赖和提高性能
set_property(TARGET ${PROJECT_NAME} PROPERTY QT_QML_COMPILER ON)

# 禁用QML调试和Profiler，减小依赖体积
target_compile_definitions(${PROJECT_NAME} PRIVATE 
    QT_NO_QML_DEBUG 
    QT_NO_QML_PROFILER 
    QT_NO_DEBUG_OUTPUT
    QT_QML_SKIP_ELEMENT_REGISTRATION
    QT_QUICK_CONTROLS_STYLE="Universal"
)

# 链接Qt库
target_link_libraries(${PROJECT_NAME} PRIVATE
    Qt6::Core
    Qt6::Gui
    Qt6::Sql
    Qt6::Quick
    Qt6::Qml
    Qt6::QuickControls2
    Qt6::Concurrent
)

# 创建 Windows 资源文件以设置图标
if(WIN32)
    set(RC_FILE "${CMAKE_CURRENT_SOURCE_DIR}/resource.rc")
    target_sources(${PROJECT_NAME} PRIVATE ${RC_FILE})
endif()

