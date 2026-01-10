#ifndef DATABASE_H
#define DATABASE_H

#include <QObject>
#include <QSqlDatabase>
#include <QSqlQuery>
#include <QSqlError>
#include <QImage>
#include <QUrl>
#include <QtConcurrent>
#include <QFutureWatcher>

class Database : public QObject
{
    Q_OBJECT

public:
    explicit Database(QObject *parent = nullptr);
    ~Database();

    Q_INVOKABLE bool initialize();
    Q_INVOKABLE bool insertImage(const QString &fileName, int groupId = -1);
    Q_INVOKABLE bool insertImage(const QUrl &fileUrl, int groupId = -1);
    bool insertImage(const QString &fileName, const QImage &image, int groupId = -1);
    Q_INVOKABLE QString getImageFilename(int id);
    Q_INVOKABLE QList<int> getAllImageIds(int groupId = -1);
    Q_INVOKABLE bool removeImage(int id);
    Q_INVOKABLE bool renameImage(int imageId, const QString &newFilename);
    Q_INVOKABLE bool updateImageGroup(int imageId, int newGroupId);
    Q_INVOKABLE QString getLastError() const;
    Q_INVOKABLE int getImageByteSize(int imageId);
    
    // 新增：供QQuickImageProvider使用的方法
    QImage getImageAsQImage(int id, bool useThumbnail = true);
    
    // 分组相关方法
    Q_INVOKABLE bool createGroup(const QString &name, int parentId = -1);
    Q_INVOKABLE QVariantList getAllGroups();
    Q_INVOKABLE QString getGroupName(int groupId);
    Q_INVOKABLE bool updateGroup(int groupId, const QString &name);
    Q_INVOKABLE bool updateGroupParent(int groupId, int newParentId); // 新增：更新分组的父分组ID
    Q_INVOKABLE bool deleteGroup(int groupId); // 删除分组（级联删除子分组和图片）
    Q_INVOKABLE int getSubgroupCount(int groupId); // 新增：获取子分组数量
    Q_INVOKABLE int getImageCountForGroup(int groupId); // 新增：获取分组下的图片数量
    Q_INVOKABLE int getGroupIdByName(const QString &name, int parentId = -1);

    Q_INVOKABLE QString getGroupPath(int groupId); // 新增：获取分组完整路径
    
    // 异步导入相关方法
    Q_INVOKABLE void startAsyncImport(const QList<QUrl> &fileUrls, int parentGroupId);
    Q_INVOKABLE void cancelAsyncImport();
    
    // 异步导出相关方法
    Q_INVOKABLE void startAsyncExport(int groupId, const QString &groupName, const QString &targetFolder);
    Q_INVOKABLE void cancelAsyncExport();
    
    // 用户设置相关方法
    Q_INVOKABLE bool saveSetting(const QString &key, const QString &value);
    Q_INVOKABLE QString getSetting(const QString &key, const QString &defaultValue = "");
    Q_INVOKABLE QVariantMap getAllSettings();

signals:
    // 异步导入信号
    void importProgress(int current, int total, const QString &currentFile, const QString &currentFolder);
    void importFinished(bool success, int importedCount, int totalCount);
    void importError(const QString &error);

    // 异步导出信号
    void exportProgress(int current, int total, const QString &currentFile, const QString &targetFolder);
    void exportFinished(bool success, int exportedCount, int totalCount, const QString &targetFolder);
    void exportError(const QString &error);

    // 图片尺寸信号（供ImageProvider使用）
    void imageSizeLoaded(int imageId, int width, int height);

private slots:
    // 内部槽函数
    void onImportFinished();
    void onExportFinished();

private:
    QSqlDatabase m_db;
    QString m_lastError;

    // 辅助方法
    QVariantList getGroupsRecursive(int parentId);
    bool createGroupsTable();
    
    // 异步导入相关成员
    QFutureWatcher<bool> *m_importWatcher;
    QList<QUrl> m_importFileUrls;
    int m_importParentGroupId;
    int m_importCurrentIndex;
    int m_importTotalCount;
    int m_importSuccessCount;
    bool m_importCancelled;
    QMap<QString, int> m_importCreatedGroups;
    
    // 异步导出相关成员
    QFutureWatcher<bool> *m_exportWatcher;
    int m_exportGroupId;
    QString m_exportGroupName;
    QString m_exportTargetFolder;
    QList<int> m_exportImageIds;
    int m_exportCurrentIndex;
    int m_exportTotalCount;
    int m_exportSuccessCount;
    bool m_exportCancelled;
};

#endif // DATABASE_H