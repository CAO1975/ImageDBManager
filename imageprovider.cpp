#include "imageprovider.h"

ImageProvider::ImageProvider(Database *database)
    : QQuickImageProvider(QQuickImageProvider::Image), m_database(database)
{
    // 构造函数，初始化数据库指针
}

QImage ImageProvider::requestImage(const QString &id, QSize *size, const QSize &requestedSize)
{
    // 解析请求ID：格式为 "id" 或 "id/original"
    QStringList parts = id.split("/");
    int imageId = parts[0].toInt();
    bool useThumbnail = (parts.size() == 1); // 默认使用缩略图
    
    if (parts.size() > 1 && parts[1] == "original") {
        useThumbnail = false; // 请求原始图片
    }
    
    // 从数据库获取图片
    QImage image = m_database->getImageAsQImage(imageId, useThumbnail);
    
    if (image.isNull()) {
        // 如果图片获取失败，返回一个默认的空图片
        image = QImage(100, 100, QImage::Format_RGB32);
        image.fill(Qt::red);
    }
    
    // 设置返回的图片大小
    if (size) {
        *size = image.size();
    }
    
    // 如果请求了特定大小，进行缩放
    if (requestedSize.width() > 0 && requestedSize.height() > 0) {
        image = image.scaled(requestedSize, Qt::KeepAspectRatio, Qt::SmoothTransformation);
    }
    
    return image;
}
