cmake_minimum_required(VERSION 3.30.5)

project(ImageDBManager LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# 必须包含 ShaderTools
find_package(Qt6 REQUIRED COMPONENTS Core Quick QuickControls2)

qt_standard_project_setup()

qt_add_executable(ImageDBManager main.cpp)


# 添加资源（注意：不要把 GLSL_VERSION 等当文件加进来！）
qt_add_resources(ImageDBManager "image_resources"
    PREFIX "/assets"
    FILES
        1.jpg
        2.jpg
        3.jpg
        4.jpg
        Main.qml
        ImageTransition.qml
        shaders/qsb/transitions.frag.qsb
)

target_link_libraries(ImageDBManager PRIVATE Qt6::Core Qt6::Quick Qt6::QuickControls2)