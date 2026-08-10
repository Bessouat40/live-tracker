pragma Singleton

import QtQuick

/*
    One ticking clock for the whole app, so any component (delegates included)
    can render "2 min ago" without reaching up to the window for it.
*/
QtObject {
    id: clock

    property double now: Date.now()

    property Timer ticker: Timer {
        interval: 30000
        running: true
        repeat: true
        onTriggered: clock.now = Date.now()
    }

    function timeAgo(ts) {
        let diff = Math.max(0, (clock.now - ts) / 1000)
        if (diff < 60)
            return qsTr("just now")
        if (diff < 3600)
            return qsTr("%1 min ago").arg(Math.floor(diff / 60))
        if (diff < 86400)
            return qsTr("%1 h ago").arg(Math.floor(diff / 3600))
        return Qt.formatDateTime(new Date(ts), "dd MMM hh:mm")
    }
}
