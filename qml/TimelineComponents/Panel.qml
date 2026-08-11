import QtQuick

// The rounded, clipped surface used for every framed block in the app.
Rectangle {
    radius: Theme.radiusLg
    color: Theme.background
    border.color: Theme.surface
    border.width: 1
    clip: true
}
