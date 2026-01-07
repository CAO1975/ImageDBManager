#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QDebug>
#include <QFile>
#include <QTextStream>
#include <QQuickStyle>
#include "database.h"
#include "imageprovider.h"

// 简单的日志写入函数
void writeLog(const QString &message)
{
    QFile logFile("debug.log");
    if (logFile.open(QIODevice::WriteOnly | QIODevice::Append | QIODevice::Text)) {
        QTextStream out(&logFile);
        out << message << "\n";
        logFile.close();
    }
}

// 自定义消息处理函数，用于捕获QML控制台输出
void messageHandler(QtMsgType type, const QMessageLogContext &context, const QString &msg)
{
    QString logMessage;
    switch (type) {
    case QtDebugMsg:
        logMessage = QString("DEBUG: %1").arg(msg);
        break;
    case QtInfoMsg:
        logMessage = QString("INFO: %1").arg(msg);
        break;
    case QtWarningMsg:
        logMessage = QString("WARNING: %1").arg(msg);
        break;
    case QtCriticalMsg:
        logMessage = QString("CRITICAL: %1").arg(msg);
        break;
    case QtFatalMsg:
        logMessage = QString("FATAL: %1").arg(msg);
        break;
    }
    writeLog(logMessage);
    // 同时输出到控制台
    fprintf(stderr, "%s\n", logMessage.toLocal8Bit().constData());
}

int main(int argc, char *argv[])
{
    // 安装自定义消息处理函数
    qInstallMessageHandler(messageHandler);
    
    QString logMessage = "Application starting...";
    qDebug() << logMessage;
    
    // 启用透明窗口支持
    QGuiApplication::setAttribute(Qt::AA_UseSoftwareOpenGL);
    
    QGuiApplication app(argc, argv);
    
    // 设置应用程序名称和版本
    app.setApplicationName("ImageDBManager");
    app.setApplicationVersion("1.0");
    
    // 设置Qt Quick Controls 2样式为Universal (Fluent Design)
    QQuickStyle::setStyle("Universal");
    
    logMessage = "Application object created successfully";
    qDebug() << logMessage;
    
    // 创建数据库实例
    Database* database = new Database();
    logMessage = "Database instance created successfully";
    qDebug() << logMessage;
    
    // 初始化数据库
    if (!database->initialize()) {
        logMessage = QString("Failed to initialize database: %1").arg(database->getLastError());
        qDebug() << logMessage;
        return 1;
    }
    logMessage = "Database initialized successfully";
    qDebug() << logMessage;
    
    // 创建QML引擎
    QQmlApplicationEngine engine;
    logMessage = "QML engine created successfully";
    qDebug() << logMessage;
    
    // 向QML注册C++类型和实例
    engine.rootContext()->setContextProperty("database", database);

    // 注册自定义图片提供器，QML可以通过image://imageprovider/imageId访问
    engine.addImageProvider("imageprovider", new ImageProvider(database));
    
    logMessage = "Database registered to QML context and ImageProvider added";
    qDebug() << logMessage;
    
    // 使用Qt6推荐的模块加载方式
    logMessage = "About to load QML module: ImageDBManager, Main.qml";
    qDebug() << logMessage;
    
    // 连接QML引擎的objectCreated信号
    QObject::connect(&engine, &QQmlApplicationEngine::objectCreated,
                     &app, [](QObject *obj, const QUrl &objUrl) {
        QString logMessage = QString("QML object created for URL: %1 Object: %2").arg(objUrl.toString()).arg(QString::number((quintptr)obj, 16));
        qDebug() << logMessage;
        if (!obj && objUrl.toString().contains("Main.qml")) {
            logMessage = "Failed to create QML object for main window, exiting...";
            qDebug() << logMessage;
            QCoreApplication::exit(-1);
        }
    }, Qt::QueuedConnection);
    
    // 连接QML引擎的warnings信号
    QObject::connect(&engine, &QQmlApplicationEngine::warnings,
                     &app, [](const QList<QQmlError> &warnings) {
        QString logMessage = QString("QML warnings count: %1").arg(warnings.count());
        qDebug() << logMessage;
        for (const QQmlError &warning : warnings) {
            logMessage = QString("QML Warning: %1").arg(warning.toString());
            qDebug() << logMessage;
        }
    });
    
    // 使用 loadFromModule 加载QML
    engine.loadFromModule("ImageDBManager", "Main");
    logMessage = "engine.loadFromModule() called successfully";
    qDebug() << logMessage;
    
    // 检查加载的根对象
    QList<QObject*> rootObjects = engine.rootObjects();
    logMessage = QString("Number of root objects loaded: %1").arg(rootObjects.count());
    qDebug() << logMessage;
    
    for (QObject* obj : rootObjects) {
        logMessage = QString("Root object: %1 Class name: %2").arg(QString::number((quintptr)obj, 16)).arg(obj->metaObject()->className());
        qDebug() << logMessage;
    }
    
    logMessage = "Entering event loop...";
    qDebug() << logMessage;
    int result = app.exec();
    logMessage = QString("Event loop exited with result: %1").arg(result);
    qDebug() << logMessage;
    
    // 释放资源
    logMessage = "Releasing resources...";
    qDebug() << logMessage;
    
    // 释放Database实例
    delete database;
    database = nullptr;
    
    logMessage = "Resources released successfully";
    qDebug() << logMessage;
    
    return result;
}