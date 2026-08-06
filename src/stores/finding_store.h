#pragma once
#include <QAbstractListModel>
#include <QVariantMap>
#include <QString>
#include <QUrl>
#include <QtQml/qqmlregistration.h>
#include <QSqlDatabase>

// Persistent, SQLite-backed model of tracked findings.
// Single source of truth shared by the detection list and the map.
class FindingStore : public QAbstractListModel
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON
    Q_PROPERTY(int count READ count NOTIFY countChanged)

public:
    enum Roles {
        FindingIdRole = Qt::UserRole + 1,
        TimestampRole,
        LatitudeRole,
        LongitudeRole,
        LabelRole,
        ConfidenceRole,
        VideoPathRole
    };

    explicit FindingStore(QObject *parent = nullptr);

    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    int count() const { return static_cast<int>(m_items.size()); }

    Q_INVOKABLE void addFinding(double latitude, double longitude,
                                const QString &label, const QString &videoPath,
                                double confidence);
    Q_INVOKABLE QVariantMap get(int index) const;
    Q_INVOKABLE void remove(int index);

    // Copies a recorded clip (a file:// URL) to a user-chosen destination.
    // Returns true on success.
    Q_INVOKABLE bool exportClip(const QString &sourceUrl, const QUrl &destination) const;

signals:
    void countChanged();

private:
    struct Finding {
        qint64 id;
        qint64 timestamp; // epoch milliseconds
        double latitude;
        double longitude;
        QString label;
        double confidence;
        QString videoPath;
    };

    void initDb();
    void loadFromDb();

    QSqlDatabase m_db;
    QList<Finding> m_items;
};
