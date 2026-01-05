#include "database.h"
#include <QCoreApplication>
#include <QSqlDatabase>
#include <QSqlQuery>
#include <QSqlError>
#include <QBuffer>
#include <QFileInfo>
#include <QDateTime>
#include <QImage>
#include <QByteArray>
#include <QString>
#include <QStandardItem>

Database::Database(QObject *parent)
    : QObject(parent),
      m_importWatcher(nullptr),
      m_importCurrentIndex(0),
      m_importTotalCount(0),
      m_importSuccessCount(0),
      m_importCancelled(false),
      m_exportWatcher(nullptr),
      m_exportCurrentIndex(0),
      m_exportTotalCount(0),
      m_exportSuccessCount(0),
      m_exportCancelled(false)
{
    // 初始化异步导入相关成员
    m_importWatcher = new QFutureWatcher<bool>(this);
    connect(m_importWatcher, &QFutureWatcher<bool>::finished, this, &Database::onImportFinished);
    
    // 初始化异步导出相关成员
    m_exportWatcher = new QFutureWatcher<bool>(this);
    connect(m_exportWatcher, &QFutureWatcher<bool>::finished, this, &Database::onExportFinished);
}

Database::~Database()
{
    if (m_db.isOpen()) {
        m_db.close();
    }
    
    // 清理异步导入资源
    if (m_importWatcher) {
        cancelAsyncImport();
        m_importWatcher->deleteLater();
    }
    
    // 清理异步导出资源
    if (m_exportWatcher) {
        cancelAsyncExport();
        m_exportWatcher->deleteLater();
    }
}

bool Database::initialize()
{
    m_db = QSqlDatabase::addDatabase("QSQLITE");
    
    // 获取应用程序所在目录，将数据库文件保存在应用程序目录下
    QString appDir = QCoreApplication::applicationDirPath();
    QString dbPath = appDir + "/ImageCollection.db";
    m_db.setDatabaseName(dbPath);

    if (!m_db.open()) {
        m_lastError = m_db.lastError().text();
        return false;
    }

    // 开启外键约束和性能优化设置
    QSqlQuery query;
    
    // 设置外键约束
    if (!query.exec("PRAGMA foreign_keys = ON")) {
        m_lastError = query.lastError().text();
        return false;
    }
    
    // 设置缓存大小为30000页
    if (!query.exec("PRAGMA cache_size = 30000")) {
        m_lastError = query.lastError().text();
        return false;
    }
    
    // 使用内存作为临时存储
    if (!query.exec("PRAGMA temp_store = MEMORY")) {
        m_lastError = query.lastError().text();
        return false;
    }
    
    // 设置页面大小为8192字节
    if (!query.exec("PRAGMA page_size = 8192")) {
        m_lastError = query.lastError().text();
        return false;
    }
    
    // 设置内存映射大小为1GB（适合16GB内存的64位程序）
    if (!query.exec("PRAGMA mmap_size = 1073741824")) {
        m_lastError = query.lastError().text();
        return false;
    }
    
    // 设置自动清理模式为增量模式
    if (!query.exec("PRAGMA auto_vacuum = INCREMENTAL")) {
        m_lastError = query.lastError().text();
        return false;
    }

    // 创建分组表
    if (!createGroupsTable()) {
        return false;
    }

    // 创建图片表
    QString createImagesTable = R"(
        CREATE TABLE IF NOT EXISTS images (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            filename TEXT NOT NULL,
            image_data BLOB NOT NULL,
            image_format TEXT NOT NULL DEFAULT 'JPG',
            thumbnail BLOB,
            group_id INTEGER,
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (group_id) REFERENCES groups(id) ON DELETE SET NULL
        )
    )";

    if (!query.exec(createImagesTable)) {
        m_lastError = query.lastError().text();
        return false;
    }

    // 为filename创建索引
    if (!query.exec("CREATE INDEX IF NOT EXISTS idx_images_filename ON images(filename)")) {
        m_lastError = query.lastError().text();
        return false;
    }
    
    // 为group_id创建索引
    if (!query.exec("CREATE INDEX IF NOT EXISTS idx_images_group_id ON images(group_id)")) {
        m_lastError = query.lastError().text();
        return false;
    }

    // 创建user_settings表
    QString createUserSettingsTable = R"(
        CREATE TABLE IF NOT EXISTS user_settings (
            setting_key TEXT PRIMARY KEY,
            setting_value TEXT NOT NULL,
            updated_time DATETIME DEFAULT CURRENT_TIMESTAMP
        )
    )";

    if (!query.exec(createUserSettingsTable)) {
        m_lastError = query.lastError().text();
        return false;
    }

    return true;
}

bool Database::createGroupsTable()
{
    QSqlQuery query;
    QString createGroupsTable = R"(
        CREATE TABLE IF NOT EXISTS groups (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            parent_id INTEGER,
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (parent_id) REFERENCES groups(id) ON DELETE CASCADE
        )
    )";

    if (!query.exec(createGroupsTable)) {
        m_lastError = query.lastError().text();
        return false;
    }

    return true;
}

// 用户设置相关方法实现

// 保存单个设置
bool Database::saveSetting(const QString &key, const QString &value)
{
    QSqlQuery query;
    
    // 使用UPSERT语法（SQLite 3.24.0+支持）
    QString sql = R"(
        INSERT INTO user_settings (setting_key, setting_value, updated_time)
        VALUES (:key, :value, CURRENT_TIMESTAMP)
        ON CONFLICT(setting_key) DO UPDATE SET
            setting_value = :value,
            updated_time = CURRENT_TIMESTAMP
    )";
    
    query.prepare(sql);
    query.bindValue(":key", key);
    query.bindValue(":value", value);
    
    if (!query.exec()) {
        m_lastError = query.lastError().text();
        return false;
    }
    
    return true;
}

// 获取单个设置
QString Database::getSetting(const QString &key, const QString &defaultValue)
{
    QSqlQuery query;
    
    QString sql = "SELECT setting_value FROM user_settings WHERE setting_key = :key";
    query.prepare(sql);
    query.bindValue(":key", key);
    
    if (!query.exec()) {
        m_lastError = query.lastError().text();
        return defaultValue;
    }
    
    if (query.next()) {
        return query.value(0).toString();
    }
    
    return defaultValue;
}

// 保存多个设置
bool Database::saveAllSettings(const QVariantMap &settings)
{
    // 开始事务以提高性能
    if (!m_db.transaction()) {
        m_lastError = m_db.lastError().text();
        return false;
    }
    
    QSqlQuery query;
    QString sql = R"(
        INSERT INTO user_settings (setting_key, setting_value, updated_time)
        VALUES (:key, :value, CURRENT_TIMESTAMP)
        ON CONFLICT(setting_key) DO UPDATE SET
            setting_value = :value,
            updated_time = CURRENT_TIMESTAMP
    )";
    
    query.prepare(sql);
    
    for (auto it = settings.constBegin(); it != settings.constEnd(); ++it) {
        query.bindValue(":key", it.key());
        query.bindValue(":value", it.value().toString());
        
        if (!query.exec()) {
            m_db.rollback();
            m_lastError = query.lastError().text();
            return false;
        }
    }
    
    // 提交事务
    if (!m_db.commit()) {
        m_lastError = m_db.lastError().text();
        return false;
    }
    
    return true;
}

// 获取所有设置
QVariantMap Database::getAllSettings()
{
    QVariantMap settings;
    QSqlQuery query;
    
    QString sql = "SELECT setting_key, setting_value FROM user_settings";
    if (!query.exec(sql)) {
        m_lastError = query.lastError().text();
        return settings;
    }
    
    while (query.next()) {
        QString key = query.value(0).toString();
        QString value = query.value(1).toString();
        settings.insert(key, value);
    }
    
    return settings;
}

bool Database::insertImage(const QString &fileName, int groupId)
{
    // 正常导入单个图片
    QImage image(fileName);
    if (image.isNull()) {
        m_lastError = "Failed to load image: " + fileName;
        return false;
    }
    
    return insertImage(fileName, image, groupId);
}

bool Database::insertImage(const QUrl &fileUrl, int groupId)
{
    // 处理URL类型的文件路径
    QString fileName = fileUrl.toLocalFile();
    if (fileName.isEmpty()) {
        m_lastError = "Invalid file URL: " + fileUrl.toString();
        return false;
    }
    
    return insertImage(fileName, groupId);
}

bool Database::insertImage(const QString &fileName, const QImage &image, int groupId)
{
    // 1. 获取原始图片格式
    QString fileExtension = QFileInfo(fileName).suffix().toUpper();
    QString imageFormat = "JPG"; // 默认格式
    
    // 根据文件扩展名设置图片格式
    if (fileExtension == "PNG") {
        imageFormat = "PNG";
    } else if (fileExtension == "BMP") {
        imageFormat = "BMP";
    } else if (fileExtension == "GIF") {
        imageFormat = "GIF";
    } else if (fileExtension == "JPG" || fileExtension == "JPEG") {
        imageFormat = "JPG";
    } else if (fileExtension == "WEBP") {
        imageFormat = "WEBP";
    }
    
    // 2. 直接从文件读取原始图片数据，避免重新编码导致的质量损失和性能问题
    QFile file(fileName);
    if (!file.open(QIODevice::ReadOnly)) {
        m_lastError = "Failed to open file: " + fileName;
        return false;
    }
    QByteArray byteArray = file.readAll();
    file.close();
    
    // 3. 生成缩略图（宽度固定为140px，高度自适应，保持比例）
    QImage thumbnail = image.scaled(
        140, // 固定宽度
        140 * 2, // 最大高度
        Qt::KeepAspectRatio, // 保持比例
        Qt::FastTransformation // 快速缩放，缩略图不需要平滑算法，提高生成速度
    );
    
    QByteArray thumbnailData;
    QBuffer thumbnailBuffer(&thumbnailData);
    thumbnailBuffer.open(QIODevice::WriteOnly);
    thumbnail.save(&thumbnailBuffer, "JPG", 85); // 缩略图统一使用JPG格式，质量85
    
    // 4. 准备SQL语句并添加绑定值
    QSqlQuery query;
    if (groupId > 0) {
        query.prepare("INSERT INTO images (filename, image_data, image_format, thumbnail, group_id) VALUES (?, ?, ?, ?, ?)");
        query.addBindValue(QFileInfo(fileName).fileName());
        query.addBindValue(byteArray);
        query.addBindValue(imageFormat);
        query.addBindValue(thumbnailData);
        query.addBindValue(groupId);
    } else {
        query.prepare("INSERT INTO images (filename, image_data, image_format, thumbnail) VALUES (?, ?, ?, ?)");
        query.addBindValue(QFileInfo(fileName).fileName());
        query.addBindValue(byteArray);
        query.addBindValue(imageFormat);
        query.addBindValue(thumbnailData);
    }
    
    if (!query.exec()) {
        m_lastError = query.lastError().text();
        return false;
    }
    
    return true;
}

QString Database::getImage(int id)
{
    QSqlQuery query;
    // 优先使用缩略图数据，提高加载速度
    query.prepare("SELECT thumbnail, image_format FROM images WHERE id = ?");
    query.addBindValue(id);
    
    if (!query.exec() || !query.next()) {
        m_lastError = query.lastError().text();
        return QString();
    }
    
    QByteArray imageData = query.value(0).toByteArray();
    QString imageFormat = query.value(1).toString();
    
    // 如果缩略图不存在，回退到原始图片
    if (imageData.isEmpty()) {
        query.prepare("SELECT image_data, image_format FROM images WHERE id = ?");
        query.addBindValue(id);
        if (!query.exec() || !query.next()) {
            return QString();
        }
        imageData = query.value(0).toByteArray();
        imageFormat = query.value(1).toString();
    }
    
    // 设置正确的MIME类型
    QString mimeType = "image/jpeg";
    if (imageFormat == "PNG") {
        mimeType = "image/png";
    } else if (imageFormat == "BMP") {
        mimeType = "image/bmp";
    } else if (imageFormat == "GIF") {
        mimeType = "image/gif";
    } else if (imageFormat == "WEBP") {
        mimeType = "image/webp";
    }
    
    // 将图片数据转换为Base64编码的Data URI字符串
    QString base64Image = QString::fromLatin1(imageData.toBase64());
    QString dataUri = QString("data:%1;base64,%2").arg(mimeType).arg(base64Image);
    
    return dataUri;
}

QString Database::getOriginalImage(int id)
{
    QSqlQuery query;
    // 直接获取原始图片数据和格式
    query.prepare("SELECT image_data, image_format FROM images WHERE id = ?");
    query.addBindValue(id);
    
    if (!query.exec() || !query.next()) {
        m_lastError = query.lastError().text();
        return QString();
    }
    
    QByteArray imageData = query.value(0).toByteArray();
    QString imageFormat = query.value(1).toString();
    
    // 设置正确的MIME类型
    QString mimeType = "image/jpeg";
    if (imageFormat == "PNG") {
        mimeType = "image/png";
    } else if (imageFormat == "BMP") {
        mimeType = "image/bmp";
    } else if (imageFormat == "GIF") {
        mimeType = "image/gif";
    } else if (imageFormat == "WEBP") {
        mimeType = "image/webp";
    }
    
    // 将图片数据转换为Base64编码的Data URI字符串
    QString base64Image = QString::fromLatin1(imageData.toBase64());
    QString dataUri = QString("data:%1;base64,%2").arg(mimeType).arg(base64Image);
    
    return dataUri;
}

QString Database::getImageFilename(int id)
{
    QSqlQuery query;
    query.prepare("SELECT filename FROM images WHERE id = ?");
    query.addBindValue(id);
    
    if (!query.exec() || !query.next()) {
        m_lastError = query.lastError().text();
        return QString();
    }
    
    return query.value(0).toString();
}

QList<int> Database::getAllImageIds(int groupId)
{
    QList<int> ids;
    QSqlQuery query;
    
    if (groupId > 0) {
        // 返回指定分组的图片
        query.prepare("SELECT id FROM images WHERE group_id = ? ORDER BY id");
        query.addBindValue(groupId);
    } else if (groupId == -1) {
        // 返回未分组的图片（group_id为NULL或-1）
        query.prepare("SELECT id FROM images WHERE group_id IS NULL OR group_id = -1 ORDER BY id");
    } else {
        // 返回所有图片（如果需要的话）
        query.prepare("SELECT id FROM images ORDER BY id");
    }
    
    if (!query.exec()) {
        m_lastError = query.lastError().text();
        return ids;
    }
    
    while (query.next()) {
        ids.append(query.value(0).toInt());
    }
    
    return ids;
}

// 分组相关方法实现
bool Database::createGroup(const QString &name, int parentId)
{
    QSqlQuery query;
    
    if (parentId > 0) {
        query.prepare("INSERT INTO groups (name, parent_id) VALUES (?, ?)");
        query.addBindValue(name);
        query.addBindValue(parentId);
    } else {
        query.prepare("INSERT INTO groups (name) VALUES (?)");
        query.addBindValue(name);
    }
    
    if (!query.exec()) {
        m_lastError = query.lastError().text();
        return false;
    }
    
    return true;
}

QVariantList Database::getAllGroups()
{
    qDebug() << "Database::getAllGroups() called";
    QVariantList result = getGroupsRecursive(-1);
    qDebug() << "Database::getAllGroups() returning" << result.size() << "groups";
    // 输出结果的详细信息
    for (int i = 0; i < result.size(); ++i) {
        QVariantMap group = result.at(i).toMap();
        qDebug() << "Group" << i << ":" << group["name"].toString() << "ID:" << group["id"].toInt();
        if (group.contains("children")) {
            qDebug() << "  Children count:" << group["children"].toList().size();
        }
    }
    return result;
}

QVariantList Database::getGroupsRecursive(int parentId)
{
    QVariantList groups;
    QSqlQuery query;
    
    if (parentId > 0) {
        query.prepare("SELECT id, name FROM groups WHERE parent_id = ? ORDER BY name");
        query.addBindValue(parentId);
    } else if (parentId == 0) {
        // 根分组的parent_id=0
        query.prepare("SELECT id, name FROM groups WHERE parent_id = 0 ORDER BY name");
    } else {
        // parentId == -1 时，查询所有根分组（parent_id IS NULL）
        query.prepare("SELECT id, name FROM groups WHERE parent_id IS NULL ORDER BY name");
    }
    
    if (!query.exec()) {
        m_lastError = query.lastError().text();
        qDebug() << "Database::getGroupsRecursive() query error:" << m_lastError;
        return groups;
    }
    
    while (query.next()) {
        QVariantMap group;
        int id = query.value(0).toInt();
        group["id"] = id;
        group["name"] = query.value(1).toString();
        
        qDebug() << "Database::getGroupsRecursive() found group:" << group["name"].toString() << "with id:" << id;
        
        // 获取子分组
        QVariantList children = getGroupsRecursive(id);
        if (!children.isEmpty()) {
            group["children"] = children;
            qDebug() << "Group" << group["name"].toString() << "has" << children.size() << "children";
        }
        
        groups.append(group);
    }
    
    qDebug() << "Database::getGroupsRecursive() returning" << groups.size() << "groups for parent" << parentId;
    return groups;
}

QString Database::getGroupName(int groupId)
{
    QSqlQuery query;
    query.prepare("SELECT name FROM groups WHERE id = ?");
    query.addBindValue(groupId);
    
    if (!query.exec() || !query.next()) {
        m_lastError = query.lastError().text();
        return QString();
    }
    
    return query.value(0).toString();
}

int Database::getGroupIdByName(const QString &name, int parentId)
{
    QSqlQuery query;
    
    if (parentId == -1) {
        // 查询根分组（parent_id为NULL）
        query.prepare("SELECT id FROM groups WHERE name = ? AND parent_id IS NULL");
        query.addBindValue(name);
    } else {
        // 查询指定父分组下的子分组
        query.prepare("SELECT id FROM groups WHERE name = ? AND parent_id = ?");
        query.addBindValue(name);
        query.addBindValue(parentId);
    }
    
    if (!query.exec() || !query.next()) {
        // 分组不存在
        return -1;
    }
    
    return query.value(0).toInt();
}

bool Database::updateGroup(int groupId, const QString &name)
{
    QSqlQuery query;
    query.prepare("UPDATE groups SET name = ? WHERE id = ?");
    query.addBindValue(name);
    query.addBindValue(groupId);
    
    if (!query.exec()) {
        m_lastError = query.lastError().text();
        return false;
    }
    
    return true;
}

bool Database::updateGroupParent(int groupId, int newParentId)
{
    QSqlQuery query;
    
    // 如果newParentId为0，表示移动到根分组（parent_id=NULL）
    if (newParentId == 0) {
        query.prepare("UPDATE groups SET parent_id = NULL WHERE id = ?");
        query.addBindValue(groupId);
    } else {
        query.prepare("UPDATE groups SET parent_id = ? WHERE id = ?");
        query.addBindValue(newParentId);
        query.addBindValue(groupId);
    }
    
    if (!query.exec()) {
        m_lastError = query.lastError().text();
        return false;
    }
    
    return true;
}

QVariantList Database::getChildGroups(int parentId)
{
    QVariantList groups;
    QSqlQuery query;
    
    if (parentId > 0) {
        query.prepare("SELECT id, name FROM groups WHERE parent_id = ? ORDER BY name");
        query.addBindValue(parentId);
    } else {
        query.prepare("SELECT id, name FROM groups WHERE parent_id IS NULL ORDER BY name");
    }
    
    if (!query.exec()) {
        m_lastError = query.lastError().text();
        return groups;
    }
    
    while (query.next()) {
        QVariantMap group;
        group["id"] = query.value(0).toInt();
        group["name"] = query.value(1).toString();
        groups.append(group);
    }
    
    return groups;
}

QStandardItemModel* Database::getGroupModel()
{
    if (!m_groupModel) {
        m_groupModel = new QStandardItemModel(this);
        m_groupModel->setColumnCount(2);
        m_groupModel->setHorizontalHeaderLabels({"name", "id"});
        buildGroupModel();
    }
    return m_groupModel;
}

void Database::buildGroupModel()
{
    if (!m_groupModel)
        return;

    m_groupModel->removeRows(0, m_groupModel->rowCount());

    QVariantList groups = getAllGroups();

    std::function<void(const QVariantList&, QStandardItem*)> addRecursive;
    addRecursive = [&](const QVariantList &list, QStandardItem *parent){
        for (const QVariant &v : list) {
            QVariantMap gm = v.toMap();
            QString name = gm.value("name").toString();
            int id = gm.value("id").toInt();

            QStandardItem *nameItem = new QStandardItem(name);
            QStandardItem *idItem = new QStandardItem(QString::number(id));

            if (parent) {
                parent->appendRow(QList<QStandardItem*>() << nameItem << idItem);
            } else {
                m_groupModel->appendRow(QList<QStandardItem*>() << nameItem << idItem);
            }

            if (gm.contains("children")) {
                QVariantList children = gm.value("children").toList();
                if (!children.isEmpty()) {
                    addRecursive(children, nameItem);
                }
            }
        }
    };

    addRecursive(groups, nullptr);
}

void Database::refreshGroupModel()
{
    if (!m_groupModel) {
        // ensure model exists
        getGroupModel();
        return;
    }
    buildGroupModel();
}

bool Database::removeImage(int id)
{
    QSqlQuery query;
    query.prepare("DELETE FROM images WHERE id = ?");
    query.addBindValue(id);
    
    if (!query.exec()) {
        m_lastError = query.lastError().text();
        return false;
    }
    
    return true;
}

bool Database::renameImage(int imageId, const QString &newFilename)
{
    QSqlQuery query;
    query.prepare("UPDATE images SET filename = ? WHERE id = ?");
    query.addBindValue(newFilename);
    query.addBindValue(imageId);
    
    if (!query.exec()) {
        m_lastError = query.lastError().text();
        return false;
    }
    
    return true;
}

bool Database::updateImageGroup(int imageId, int newGroupId)
{
    QSqlQuery query;
    query.prepare("UPDATE images SET group_id = ? WHERE id = ?");
    
    // 如果newGroupId == -1，则设置为NULL，表示未分组
    if (newGroupId == -1) {
        query.addBindValue(QVariant()); // 使用默认构造的QVariant表示NULL值
    } else {
        query.addBindValue(newGroupId);
    }
    
    query.addBindValue(imageId);
    
    if (!query.exec()) {
        m_lastError = query.lastError().text();
        return false;
    }
    
    return true;
}

bool Database::deleteGroup(int groupId)
{
    // 开始事务
    if (!m_db.transaction()) {
        m_lastError = m_db.lastError().text();
        return false;
    }
    
    QSqlQuery query;
    
    try {
        // 1. 使用递归CTE查询获取所有子分组ID（包括当前分组）
        QString groupQuery = QString(R"(
            WITH RECURSIVE all_groups AS (
                SELECT id FROM groups WHERE id = %1
                UNION ALL
                SELECT g.id FROM groups g
                JOIN all_groups ag ON g.parent_id = ag.id
            )
            SELECT id FROM all_groups
        )").arg(groupId);
        
        if (!query.exec(groupQuery)) {
            throw query.lastError().text();
        }
        
        // 收集所有分组ID
        QStringList groupIdStrings;
        while (query.next()) {
            groupIdStrings.append(QString::number(query.value(0).toInt()));
        }
        
        // 2. 删除这些分组下的所有图片
        if (!groupIdStrings.isEmpty()) {
            QString groupIdsJoined = groupIdStrings.join(",");
            QString imageQuery = QString(R"(
                DELETE FROM images
                WHERE group_id IN (%1)
            )").arg(groupIdsJoined);
            
            if (!query.exec(imageQuery)) {
                throw query.lastError().text();
            }
            
            qDebug() << "Deleted images for groups:" << groupIdsJoined << "Deleted count:" << query.numRowsAffected();
        }
        
        // 3. 删除所有子分组（包括当前分组）
        if (!groupIdStrings.isEmpty()) {
            QString groupIdsJoined = groupIdStrings.join(",");
            QString deleteGroupQuery = QString(R"(
                DELETE FROM groups
                WHERE id IN (%1)
            )").arg(groupIdsJoined);
            
            if (!query.exec(deleteGroupQuery)) {
                throw query.lastError().text();
            }
            
            qDebug() << "Deleted groups:" << groupIdsJoined << "Deleted count:" << query.numRowsAffected();
        }
        
        // 提交事务
        if (!m_db.commit()) {
            throw m_db.lastError().text();
        }
        
        return true;
    } catch (const QString &error) {
        // 回滚事务
        m_db.rollback();
        m_lastError = error;
        qDebug() << "Delete group failed:" << error;
        return false;
    }
}

int Database::getSubgroupCount(int groupId)
{
    // 计算指定分组的所有子分组数量（包括嵌套子分组）
    int count = 0;
    QSqlQuery query;
    
    // 使用递归CTE查询获取所有子分组
    QString recursiveQuery = QString(R"(
        WITH RECURSIVE subgroups AS (
            SELECT id FROM groups WHERE parent_id = %1
            UNION ALL
            SELECT g.id FROM groups g
            JOIN subgroups s ON g.parent_id = s.id
        )
        SELECT COUNT(*) FROM subgroups
    )").arg(groupId);
    
    if (!query.exec(recursiveQuery)) {
        m_lastError = query.lastError().text();
        return 0;
    }
    
    if (query.next()) {
        count = query.value(0).toInt();
    }
    
    return count;
}

int Database::getImageCountForGroup(int groupId)
{
    // 计算指定分组及其所有子分组下的图片数量
    int count = 0;
    QSqlQuery query;
    
    // 使用递归CTE查询获取所有子孙分组ID，包括当前分组
    QString recursiveQuery = QString(R"(
        WITH RECURSIVE all_groups AS (
            SELECT id FROM groups WHERE id = %1
            UNION ALL
            SELECT g.id FROM groups g
            JOIN all_groups ag ON g.parent_id = ag.id
        )
        SELECT COUNT(*) FROM images 
        WHERE group_id IN (SELECT id FROM all_groups)
    )").arg(groupId);
    
    if (!query.exec(recursiveQuery)) {
        m_lastError = query.lastError().text();
        return 0;
    }
    
    if (query.next()) {
        count = query.value(0).toInt();
    }
    
    return count;
}

QImage Database::getImageAsQImage(int id, bool useThumbnail)
{
    QSqlQuery query;
    QByteArray imageData;
    QString imageFormat;
    
    if (useThumbnail) {
        // 优先使用缩略图数据，提高加载速度
        query.prepare("SELECT thumbnail, image_format FROM images WHERE id = ?");
        query.addBindValue(id);
        
        if (!query.exec() || !query.next()) {
            return QImage();
        }
        
        imageData = query.value(0).toByteArray();
        imageFormat = query.value(1).toString();
        
        // 如果缩略图不存在，回退到原始图片
        if (imageData.isEmpty()) {
            useThumbnail = false;
        }
    }
    
    if (!useThumbnail) {
        // 获取原始图片
        query.prepare("SELECT image_data, image_format FROM images WHERE id = ?");
        query.addBindValue(id);
        if (!query.exec() || !query.next()) {
            return QImage();
        }
        
        imageData = query.value(0).toByteArray();
        imageFormat = query.value(1).toString();
    }
    
    // 从字节数组创建QImage
    QImage image;
    // 缩略图统一使用JPG格式解码，原始图片使用实际格式解码
    QString decodeFormat = useThumbnail ? "JPG" : imageFormat;
    image.loadFromData(imageData, decodeFormat.toUtf8());
    
    return image;
}

QString Database::getLastError() const
{
    return m_lastError;
}

int Database::getImageByteSize(int imageId)
{
    QSqlQuery query;
    query.prepare("SELECT LENGTH(image_data) FROM images WHERE id = ?");
    query.addBindValue(imageId);
    
    if (!query.exec() || !query.next()) {
        m_lastError = query.lastError().text();
        return 0;
    }
    
    return query.value(0).toInt();
}

QSize Database::getImageSize(int imageId)
{
    QSqlQuery query;
    query.prepare("SELECT image_data FROM images WHERE id = ?");
    query.addBindValue(imageId);
    
    if (!query.exec() || !query.next()) {
        m_lastError = query.lastError().text();
        return QSize();
    }
    
    QByteArray imageData = query.value(0).toByteArray();
    QImage image;
    if (image.loadFromData(imageData)) {
        return image.size();
    }
    
    return QSize();
}

QString Database::getGroupPath(int groupId)
{
    if (groupId <= 0) {
        return QString();
    }
    
    QStringList pathParts;
    int currentId = groupId;
    
    // 从当前分组向上查询，直到根节点
    while (currentId > 0) {
        QSqlQuery query;
        query.prepare("SELECT name, parent_id FROM groups WHERE id = ?");
        query.addBindValue(currentId);
        
        if (!query.exec() || !query.next()) {
            m_lastError = query.lastError().text();
            break;
        }
        
        QString name = query.value(0).toString();
        pathParts.prepend(name);
        
        currentId = query.value(1).toInt();
    }
    
    return pathParts.join("\\");
}



// 异步导出实现
void Database::startAsyncExport(int groupId, const QString &groupName, const QString &targetFolder)
{
    // 在主线程中获取所有需要导出的图片数据
    QList<QPair<int, QByteArray>> exportData;
    QStringList filenames;
    
    // 获取分组内的所有图片ID
    QList<int> imageIds = getAllImageIds(groupId);
    int totalCount = imageIds.size();
    
    if (totalCount == 0) {
        emit exportFinished(true, 0, 0, targetFolder);
        return;
    }
    
    // 重置导出状态
    m_exportGroupId = groupId;
    m_exportGroupName = groupName;
    m_exportTargetFolder = targetFolder;
    m_exportImageIds = imageIds;
    m_exportCurrentIndex = 0;
    m_exportTotalCount = totalCount;
    m_exportSuccessCount = 0;
    m_exportCancelled = false;
    
    // 在主线程中获取所有图片数据
    for (int imageId : imageIds) {
        QSqlQuery query(m_db);
        query.prepare("SELECT image_data, filename FROM images WHERE id = ?");
        query.addBindValue(imageId);
        
        if (query.exec() && query.next()) {
            QByteArray imageData = query.value(0).toByteArray();
            QString filename = query.value(1).toString();
            exportData.append(qMakePair(imageId, imageData));
            filenames.append(filename);
        }
    }
    
    // 使用QtConcurrent在后台线程执行导出
    auto exportFunction = [this, exportData, filenames, totalCount, groupName, targetFolder]() {
        try {
            int successCount = 0;
            
            for (int i = 0; i < totalCount; ++i) {
                if (m_exportCancelled) {
                    break;
                }
                
                QString filename = filenames[i];
                QByteArray imageData = exportData[i].second;
                
                // 构建完整的目标文件路径
                QString targetFilePath = targetFolder + "/" + groupName + "/" + filename;
                
                // 确保目标文件夹存在
                QString targetDir = QFileInfo(targetFilePath).absolutePath();
                QDir dir;
                if (!dir.exists(targetDir)) {
                    if (!dir.mkpath(targetDir)) {
                        emit exportError(QString("无法创建目标文件夹: %1").arg(targetDir));
                        return false;
                    }
                }
                
                // 写入图片数据到文件
                QFile file(targetFilePath);
                if (file.open(QIODevice::WriteOnly)) {
                    qint64 bytesWritten = file.write(imageData);
                    file.close();
                    
                    if (bytesWritten == imageData.size()) {
                        successCount++;
                    }
                }
                
                // 发出进度信号
                emit exportProgress(i + 1, totalCount, filename, targetFolder);
                
                // 短暂延迟，避免UI卡顿
                QThread::msleep(10);
            }
            
            // 更新成功计数
            m_exportSuccessCount = successCount;
        } catch (const std::exception &e) {
            emit exportError(QString("导出过程中发生异常: %1").arg(e.what()));
            return false;
        } catch (...) {
            emit exportError("导出过程中发生未知异常");
            return false;
        }
        
        return true;
    };
    
    // 开始异步导出
    QFuture<bool> future = QtConcurrent::run(exportFunction);
    m_exportWatcher->setFuture(future);
}

void Database::cancelAsyncExport()
{
    m_exportCancelled = true;
    
    if (m_exportWatcher && m_exportWatcher->isRunning()) {
        m_exportWatcher->waitForFinished();
    }
}

void Database::onExportFinished()
{
    emit exportFinished(!m_exportCancelled, m_exportSuccessCount, m_exportTotalCount, m_exportTargetFolder);
}

// 异步导入实现
void Database::startAsyncImport(const QList<QUrl> &fileUrls, int parentGroupId)
{
    // 重置导入状态
    m_importFileUrls = fileUrls;
    m_importParentGroupId = parentGroupId;
    m_importCurrentIndex = 0;
    m_importTotalCount = fileUrls.size();
    m_importSuccessCount = 0;
    m_importCancelled = false;
    m_importCreatedGroups.clear();
    
    if (m_importTotalCount == 0) {
        emit importFinished(true, 0, 0);
        return;
    }
    
    // 使用QtConcurrent在后台线程执行导入
    auto importFunction = [this, parentGroupId]() {
        try {
            for (int i = 0; i < m_importTotalCount; ++i) {
                if (m_importCancelled) {
                    break;
                }
                
                const QUrl &fileUrl = m_importFileUrls[i];
                QString fileName = fileUrl.toLocalFile();
                
                // 提取文件夹名
                QString folderName = "默认分组";
                QString urlString = fileUrl.toString();
                int lastSeparatorIndex = std::max(urlString.lastIndexOf("\\"), urlString.lastIndexOf("/"));
                if (lastSeparatorIndex != -1) {
                    QString filePath = urlString.left(lastSeparatorIndex);
                    int folderSeparatorIndex = std::max(filePath.lastIndexOf("\\"), filePath.lastIndexOf("/"));
                    if (folderSeparatorIndex != -1) {
                        folderName = QUrl::fromPercentEncoding(filePath.mid(folderSeparatorIndex + 1).toUtf8());
                    } else {
                        folderName = QUrl::fromPercentEncoding(filePath.toUtf8());
                    }
                }
                
                // 准备分组
                QString groupKey = QString("%1:%2").arg(parentGroupId).arg(folderName);
                int targetGroupId = parentGroupId;
                
                // 在主线程中执行数据库操作，确保线程安全
                QMetaObject::invokeMethod(this, [this, folderName, parentGroupId, groupKey, &targetGroupId]() {
                    // 检查是否已经创建过该分组
                    if (!m_importCreatedGroups.contains(groupKey)) {
                        int existingGroupId = getGroupIdByName(folderName, parentGroupId);
                        if (existingGroupId > 0) {
                            targetGroupId = existingGroupId;
                        } else {
                            // 创建新分组
                            bool createSuccess = createGroup(folderName, parentGroupId);
                            if (createSuccess) {
                                targetGroupId = getGroupIdByName(folderName, parentGroupId);
                                if (targetGroupId <= 0) {
                                    targetGroupId = parentGroupId;
                                }
                            }
                        }
                        m_importCreatedGroups.insert(groupKey, targetGroupId);
                    } else {
                        targetGroupId = m_importCreatedGroups.value(groupKey);
                    }
                }, Qt::BlockingQueuedConnection);
                
                // 导入图片
                bool success = false;
                QMetaObject::invokeMethod(this, [this, fileUrl, targetGroupId, &success]() {
                    success = insertImage(fileUrl, targetGroupId);
                }, Qt::BlockingQueuedConnection);
                
                if (success) {
                    m_importSuccessCount++;
                } else {
                    QString error = "Failed to import image: " + fileName + ", Error: " + getLastError();
                    emit importError(error);
                }
                
                // 发送进度更新信号
                QString currentFileName = QFileInfo(fileName).fileName();
                emit importProgress(i + 1, m_importTotalCount, currentFileName, folderName);
            }
            
        } catch (const std::exception &e) {
            QString error = "Exception in import thread: " + QString::fromStdString(e.what());
            emit importError(error);
            return false;
        } catch (...) {
            emit importError("Unknown exception in import thread");
            return false;
        }
        
        return !m_importCancelled;
    };
    
    // 启动异步导入
    m_importWatcher->setFuture(QtConcurrent::run(importFunction));
}

void Database::cancelAsyncImport()
{
    m_importCancelled = true;
    if (m_importWatcher->isRunning()) {
        m_importWatcher->waitForFinished();
    }
}

void Database::onImportFinished()
{
    bool success = m_importWatcher->result();
    emit importFinished(success, m_importSuccessCount, m_importTotalCount);
}