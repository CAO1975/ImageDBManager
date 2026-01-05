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
