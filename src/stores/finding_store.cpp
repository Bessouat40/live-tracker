#include "finding_store.h"
#include <QSqlQuery>
#include <QSqlError>
#include <QVariant>
#include <QDateTime>
#include <QDebug>
#include <QFile>
#include <QUrl>
#include <QDir>
#include <QStandardPaths>

FindingStore::FindingStore(QObject *parent)
    : QAbstractListModel(parent)
{
    initDb();
    loadFromDb();
}

void FindingStore::initDb()
{
    const QString dir = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    if (dir.isEmpty() || !QDir().mkpath(dir)) {
        qWarning() << "FindingStore: cannot create data directory:" << dir;
        return;
    }

    m_db = QSqlDatabase::addDatabase("QSQLITE", "findings");
    m_db.setDatabaseName(QDir(dir).filePath("findings.db"));
    if (!m_db.open()) {
        qWarning() << "FindingStore: cannot open findings.db:" << m_db.lastError().text();
        return;
    }

    QSqlQuery q(m_db);
    q.exec("CREATE TABLE IF NOT EXISTS findings ("
           "id INTEGER PRIMARY KEY AUTOINCREMENT, "
           "timestamp INTEGER NOT NULL, "
           "latitude REAL, "
           "longitude REAL, "
           "label TEXT, "
           "confidence REAL, "
           "clip_path TEXT)");
}

void FindingStore::loadFromDb()
{
    if (!m_db.isOpen())
        return;

    QSqlQuery q("SELECT id, timestamp, latitude, longitude, label, confidence, clip_path "
                "FROM findings ORDER BY id ASC",
                m_db);
    while (q.next()) {
        Finding f;
        f.id = q.value(0).toLongLong();
        f.timestamp = q.value(1).toLongLong();
        f.latitude = q.value(2).toDouble();
        f.longitude = q.value(3).toDouble();
        f.label = q.value(4).toString();
        f.confidence = q.value(5).toDouble();
        f.videoPath = q.value(6).toString();
        m_items.push_back(f);
    }
}

int FindingStore::rowCount(const QModelIndex &parent) const
{
    if (parent.isValid())
        return 0;
    return static_cast<int>(m_items.size());
}

QVariant FindingStore::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() < 0 || index.row() >= m_items.size())
        return QVariant();

    const Finding &f = m_items.at(index.row());
    switch (role) {
    case FindingIdRole:  return QVariant::fromValue(f.id);
    case TimestampRole:  return QVariant::fromValue(f.timestamp);
    case LatitudeRole:   return f.latitude;
    case LongitudeRole:  return f.longitude;
    case LabelRole:      return f.label;
    case ConfidenceRole: return f.confidence;
    case VideoPathRole:  return f.videoPath;
    default:             return QVariant();
    }
}

QHash<int, QByteArray> FindingStore::roleNames() const
{
    return {
        { FindingIdRole,  "findingId" },
        { TimestampRole,  "timestamp" },
        { LatitudeRole,   "latitude" },
        { LongitudeRole,  "longitude" },
        { LabelRole,      "label" },
        { ConfidenceRole, "confidence" },
        { VideoPathRole,  "videoPath" }
    };
}

void FindingStore::addFinding(double latitude, double longitude,
                              const QString &label, const QString &videoPath,
                              double confidence)
{
    Finding f;
    f.timestamp = QDateTime::currentMSecsSinceEpoch();
    f.latitude = latitude;
    f.longitude = longitude;
    f.label = label;
    f.confidence = confidence;
    f.videoPath = videoPath;
    f.id = -1;

    if (m_db.isOpen()) {
        QSqlQuery q(m_db);
        q.prepare("INSERT INTO findings (timestamp, latitude, longitude, label, confidence, clip_path) "
                  "VALUES (?, ?, ?, ?, ?, ?)");
        q.addBindValue(f.timestamp);
        q.addBindValue(f.latitude);
        q.addBindValue(f.longitude);
        q.addBindValue(f.label);
        q.addBindValue(f.confidence);
        q.addBindValue(f.videoPath);
        if (!q.exec()) {
            qWarning() << "FindingStore: insert failed:" << q.lastError().text();
            return;
        }
        f.id = q.lastInsertId().toLongLong();
    }

    beginInsertRows(QModelIndex(), static_cast<int>(m_items.size()), static_cast<int>(m_items.size()));
    m_items.push_back(f);
    endInsertRows();
    emit countChanged();
}

QVariantMap FindingStore::get(int index) const
{
    QVariantMap map;
    if (index < 0 || index >= m_items.size())
        return map;

    const Finding &f = m_items.at(index);
    map["findingId"] = QVariant::fromValue(f.id);
    map["timestamp"] = QVariant::fromValue(f.timestamp);
    map["latitude"] = f.latitude;
    map["longitude"] = f.longitude;
    map["label"] = f.label;
    map["confidence"] = f.confidence;
    map["videoPath"] = f.videoPath;
    return map;
}

void FindingStore::remove(int index)
{
    if (index < 0 || index >= m_items.size())
        return;

    const qint64 id = m_items.at(index).id;
    if (m_db.isOpen() && id >= 0) {
        QSqlQuery q(m_db);
        q.prepare("DELETE FROM findings WHERE id = ?");
        q.addBindValue(id);
        if (!q.exec()) {
            qWarning() << "FindingStore: delete failed:" << q.lastError().text();
            return;
        }
    }

    beginRemoveRows(QModelIndex(), index, index);
    m_items.removeAt(index);
    endRemoveRows();
    emit countChanged();
}

bool FindingStore::exportClip(const QString &sourceUrl, const QUrl &destination) const
{
    // sourceUrl is stored as a file:// URL; accept a plain path too.
    const QUrl src(sourceUrl);
    const QString srcPath = src.isLocalFile() ? src.toLocalFile() : sourceUrl;
    const QString dstPath = destination.isLocalFile() ? destination.toLocalFile()
                                                      : destination.toString();

    if (srcPath.isEmpty() || dstPath.isEmpty()) {
        qWarning() << "FindingStore: exportClip missing path" << sourceUrl << destination;
        return false;
    }
    if (!QFile::exists(srcPath)) {
        qWarning() << "FindingStore: exportClip source not found:" << srcPath;
        return false;
    }

    const QString tmpPath = dstPath + QStringLiteral(".part");
    QFile::remove(tmpPath);

    if (!QFile::copy(srcPath, tmpPath)) {
        qWarning() << "FindingStore: exportClip copy failed:" << srcPath << "->" << dstPath;
        return false;
    }

    if (QFile::exists(dstPath) && !QFile::remove(dstPath)) {
        qWarning() << "FindingStore: exportClip cannot overwrite:" << dstPath;
        QFile::remove(tmpPath);
        return false;
    }

    if (!QFile::rename(tmpPath, dstPath)) {
        qWarning() << "FindingStore: exportClip cannot finalise:" << dstPath;
        QFile::remove(tmpPath);
        return false;
    }
    return true;
}
