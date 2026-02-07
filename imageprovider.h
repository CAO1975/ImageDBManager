/**
 * @file imageprovider.h
 * @brief 自定义图片提供器 - 供 QML 异步加载图片
 *
 * 注册为 "imageprovider"，QML 中通过 image://imageprovider/<id> 访问
 * 实现图片的懒加载和缓存，支持缩略图生成
 */

#ifndef IMAGEPROVIDER_H
#define IMAGEPROVIDER_H

#include <QQuickImageProvider>
#include "database.h"

class ImageProvider : public QQuickImageProvider
{
public:
    ImageProvider(Database *database);
    
    // 重写requestImage方法，处理图片请求
    QImage requestImage(const QString &id, QSize *size, const QSize &requestedSize) override;
    
private:
    Database *m_database; // 数据库指针，用于获取图片数据
};

#endif // IMAGEPROVIDER_H
