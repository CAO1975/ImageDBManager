#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QDebug>
#include <QFile>
#include <QTextStream>
#include <QQuickStyle>
#include "database.h"
#include "imageprovider.h"

// 自定义消息处理函数，用于捕获QML控制台输出
void messageHandler(QtMsgType type, const QMessageLogContext &context, const QString &msg)
{
    const char *typeStr;
    switch (type) {
    case QtDebugMsg:    typeStr = "DEBUG"; break;
    case QtInfoMsg:     typeStr = "INFO"; break;
    case QtWarningMsg:  typeStr = "WARNING"; break;
    case QtCriticalMsg: typeStr = "CRITICAL"; break;
    case QtFatalMsg:    typeStr = "FATAL"; break;
    default:            typeStr = "UNKNOWN"; break;
    }
    
    QString logMessage = QString("%1: %2").arg(typeStr).arg(msg);
    // 输出到控制台
    fprintf(stderr, "%s\n", logMessage.toLocal8Bit().constData());
    fflush(stderr);
}

int main(int argc, char *argv[])
{
    // 安装自定义消息处理函数
    qInstallMessageHandler(messageHandler);
    qDebug() << "Application starting...";
    
    // 启用透明窗口支持
    QGuiApplication::setAttribute(Qt::AA_UseSoftwareOpenGL);
    
    QGuiApplication app(argc, argv);
    
    // 设置应用程序名称和版本
    app.setApplicationName("ImageDBManager");
    app.setApplicationVersion("1.0");
    
    // 设置Qt Quick Controls 2样式为Universal (Fluent Design)
    QQuickStyle::setStyle("Universal");
    qDebug() << "Application initialized";
    
    // 创建数据库实例
    Database* database = new Database();
    qDebug() << "Database instance created";
    
    // 初始化数据库
    if (!database->initialize()) {
        qCritical() << "Failed to initialize database:" << database->getLastError();
        delete database;
        return 1;
    }
    qDebug() << "Database initialized successfully";
    
    // 创建QML引擎
    QQmlApplicationEngine engine;
    
    // 向QML注册C++类型和实例
    engine.rootContext()->setContextProperty("database", database);

    // 注册自定义图片提供器，QML可以通过image://imageprovider/imageId访问
    engine.addImageProvider("imageprovider", new ImageProvider(database));
    qDebug() << "QML engine configured";
    
    // 连接QML引擎的objectCreated信号
    QObject::connect(&engine, &QQmlApplicationEngine::objectCreated,
                     &app, [](QObject *obj, const QUrl &objUrl) {
        qDebug() << "QML object created:" << objUrl.toString();
        if (!obj && objUrl.toString().contains("Main.qml")) {
            qCritical() << "Failed to create QML object for main window";
            QCoreApplication::exit(-1);
        }
    }, Qt::QueuedConnection);
    
    // 连接QML引擎的warnings信号
    QObject::connect(&engine, &QQmlApplicationEngine::warnings,
                     &app, [](const QList<QQmlError> &warnings) {
        qWarning() << "QML warnings count:" << warnings.count();
        for (const QQmlError &warning : warnings) {
            qWarning() << "QML Warning:" << warning.toString();
        }
    });
    
    // 使用 loadFromModule 加载QML
    engine.loadFromModule("ImageDBManager", "Main");
    qDebug() << "QML module loaded";
    
    // 检查加载的根对象
    const auto rootObjects = engine.rootObjects();
    qDebug() << "Root objects loaded:" << rootObjects.count();
    
    // 进入事件循环
    int result = app.exec();
    qDebug() << "Application exiting with result:" << result;
    
    // 释放资源 - database 会通过 parent 自动释放，但这里显式释放更清晰
    delete database;
    
    return result;
}