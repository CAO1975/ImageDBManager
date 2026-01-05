#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QString>
#include <QQuickStyle>
#include <QQmlContext>
#include <QSettings>
#include <QFileInfo>

class StyleManager : public QObject
{
    Q_OBJECT
public:
    explicit StyleManager(QObject *parent = nullptr) : QObject(parent) {
        settings = new QSettings("ImageDBManager", "StyleConfig", this);
    }

    Q_INVOKABLE void setStyle(const QString &style) {
        settings->setValue("style", style);
        settings->sync();
    }

    Q_INVOKABLE QString getStyle() const {
        return settings->value("style", "Windows").toString();
    }

private:
    QSettings *settings;
};

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);

    // 先从配置文件读取样式，设置后再加载 QML
    QSettings settings("ImageDBManager", "StyleConfig");
    QString style = settings.value("style", "Windows").toString();
    QQuickStyle::setStyle(style);

    qmlRegisterType<StyleManager>("StyleManager", 1, 0, "StyleManager");

    QQmlApplicationEngine engine;
    const QUrl url(QStringLiteral("qrc:/assets/Main.qml"));
    QObject::connect(
        &engine, &QQmlApplicationEngine::objectCreationFailed,
        &app, []() { QCoreApplication::exit(-1); },
        Qt::QueuedConnection);
    engine.load(url);

    return app.exec();
}

#include "main.moc"
