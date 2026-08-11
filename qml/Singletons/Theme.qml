pragma Singleton

import QtQuick

QtObject {
    // ---- Surfaces --------------------------------------------------------
    readonly property color backgroundDeep: "#020617" // Slate 950
    readonly property color background:     "#0f172a" // Slate 900
    readonly property color surface:        "#1e293b" // Slate 800
    readonly property color surfaceHover:   "#334155" // Slate 700
    readonly property color border:         "#334155" // Slate 700
    readonly property color overlay:        "#cc0f172a" // Slate 900 @ 80%

    // ---- Text ------------------------------------------------------------
    readonly property color text:         "#f8fafc" // Slate 50
    readonly property color textMuted:    "#94a3b8" // Slate 400
    readonly property color textFaint:    "#64748b" // Slate 500
    readonly property color textDisabled: "#475569" // Slate 600

    // ---- Accents ---------------------------------------------------------
    readonly property color accent:        "#38bdf8" // Sky 400
    readonly property color accentStrong:  "#0ea5e9" // Sky 500
    readonly property color accentPressed: "#0284c7" // Sky 600
    readonly property color active:        "#fbbf24" // Amber 400
    readonly property color success:       "#22c55e" // Green 500
    readonly property color danger:        "#ef4444" // Red 500
    readonly property color dangerSurface: "#2d1f2e"
    readonly property color textOnAccent:  "#ffffff"

    // ---- Radii -----------------------------------------------------------
    readonly property int radiusSm:   6
    readonly property int radiusMd:   8
    readonly property int radiusLg:   12
    readonly property int radiusPill: 24

    // ---- Spacing ---------------------------------------------------------
    readonly property int spacingXs:  4
    readonly property int spacingSm:  8
    readonly property int spacingMd:  12
    readonly property int spacingLg:  16
    readonly property int spacingXl:  20
    readonly property int spacingXxl: 24
}
