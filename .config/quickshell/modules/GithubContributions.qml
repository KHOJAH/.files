import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

FloatingWindow {
    id: root
    property var colors
    property bool open: false

    title: "GitHub Contributions"
    implicitWidth: 490
    implicitHeight: 330
    minimumSize: Qt.size(460, 310)
    maximumSize: Qt.size(540, 360)
    color: "transparent"
    visible: root.open

    IpcHandler {
        target: "github"
        function toggle(): void { root.open = !root.open }
    }

    property string username: ""
    property int monthContributions: 0
    property int todayContributions: 0
    property int currentStreak: 0
    property int longestStreak: 0
    property string lastUpdated: ""
    property var monthLabels: []
    property var weeks: []
    property var hoveredDay: null
    property bool isRefreshing: false

    // Auto-refresh every 5 minutes while open
    Timer {
        id: autoRefreshTimer
        interval: 300000
        running: root.open
        repeat: true
        onTriggered: root.triggerRefresh(false)
    }

    function triggerRefresh(force) {
        root.isRefreshing = true
        if (force) {
            fetcher.command = ["python3", Quickshell.env("HOME") + "/.config/quickshell/scripts/github-contributions.py", "--refresh"]
        } else {
            fetcher.command = ["python3", Quickshell.env("HOME") + "/.config/quickshell/scripts/github-contributions.py"]
        }
        fetcher.running = true
    }

    Process {
        id: fetcher
        command: ["python3", Quickshell.env("HOME") + "/.config/quickshell/scripts/github-contributions.py"]
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                root.isRefreshing = false
                try {
                    var j = JSON.parse(text)
                    if (j) {
                        root.username = j.username || ""
                        root.monthContributions = j.monthContributions || 0
                        root.todayContributions = j.todayContributions || 0
                        root.currentStreak = j.currentStreak || 0
                        root.longestStreak = j.longestStreak || 0
                        root.monthLabels = j.monthLabels || []
                        root.weeks = j.weeks || []
                        root.lastUpdated = j.lastUpdated || Qt.formatTime(new Date(), "hh:mm:ss")
                    }
                } catch (e) {}
            }
        }
    }

    onOpenChanged: {
        if (open) {
            root.triggerRefresh(false)
        } else {
            root.hoveredDay = null
        }
    }

    function heatColor(lvl, isFuture) {
        if (isFuture) return colors.alpha(colors.outline, 0.04)
        if (lvl === 0) return colors.alpha(colors.outline, 0.10)
        if (lvl === 1) return colors.alpha(colors.primary, 0.32)
        if (lvl === 2) return colors.alpha(colors.primary, 0.58)
        if (lvl === 3) return colors.alpha(colors.primary, 0.80)
        return colors.primary
    }

    function formatDate(ds) {
        if (!ds) return ""
        try {
            var parts = ds.split("-")
            var d = new Date(parts[0], parts[1] - 1, parts[2])
            return d.toLocaleDateString(Qt.locale(), "ddd, MMM d, yyyy")
        } catch (e) {
            return ds
        }
    }

    Rectangle {
        id: card
        anchors.fill: parent
        radius: 16
        color: colors.alpha(colors.background, 0.96)
        border.width: 1
        border.color: colors.alpha(colors.outline, 0.14)
        scale: root.open ? 1 : 0.96
        opacity: root.open ? 1 : 0
        Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

        focus: root.open
        Keys.onEscapePressed: root.open = false

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 18
            spacing: 12

            // Top Header
            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Text {
                    text: "GITHUB CONTRIBUTIONS"
                    color: colors.primary
                    font.family: colors.fontSans
                    font.pixelSize: 11
                    font.weight: Font.ExtraBold
                    font.letterSpacing: 1.4
                }

                Text {
                    text: "@" + root.username
                    color: colors.alpha(colors.foreground, 0.6)
                    font.family: colors.fontSans
                    font.pixelSize: 10
                    font.weight: Font.Medium
                }

                Item { Layout.fillWidth: true }

                // Refresh Button
                Rectangle {
                    width: 24
                    height: 24
                    radius: 12
                    color: refreshMa.containsMouse ? colors.alpha(colors.primary, 0.15) : "transparent"
                    Text {
                        anchors.centerIn: parent
                        text: "󰑐"
                        color: root.isRefreshing ? colors.primary : (refreshMa.containsMouse ? colors.primary : colors.alpha(colors.outline, 0.7))
                        font.family: colors.fontSans
                        font.pixelSize: 12
                        rotation: root.isRefreshing ? 360 : 0
                        Behavior on rotation { NumberAnimation { duration: 500; loops: Animation.Infinite } }
                    }
                    MouseArea {
                        id: refreshMa
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: root.triggerRefresh(true)
                    }
                }

                // Close Button
                Rectangle {
                    width: 24
                    height: 24
                    radius: 12
                    color: closeMa.containsMouse ? colors.alpha(colors.surfaceVariant, 0.5) : "transparent"
                    Text {
                        anchors.centerIn: parent
                        text: "󰅖"
                        color: closeMa.containsMouse ? colors.foreground : colors.alpha(colors.outline, 0.7)
                        font.family: colors.fontSans
                        font.pixelSize: 12
                    }
                    MouseArea {
                        id: closeMa
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: root.open = false
                    }
                }
            }

            // Middle Content: Stats Panel (Left) + 5-Week Heatmap (Right)
            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 18

                // Left: Stats Column
                ColumnLayout {
                    Layout.preferredWidth: 140
                    Layout.fillHeight: true
                    spacing: 10

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 52
                        radius: 8
                        color: colors.alpha(colors.primary, 0.10)
                        border.width: 1
                        border.color: colors.alpha(colors.primary, 0.20)
                        Column {
                            anchors.centerIn: parent
                            spacing: 1
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "" + root.monthContributions
                                color: colors.primary
                                font.family: colors.fontSans
                                font.pixelSize: 18
                                font.weight: Font.Black
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "LAST 30 DAYS"
                                color: colors.alpha(colors.foreground, 0.6)
                                font.family: colors.fontSans
                                font.pixelSize: 8
                                font.weight: Font.Bold
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 46
                        radius: 8
                        color: colors.alpha(colors.secondary, 0.10)
                        border.width: 1
                        border.color: colors.alpha(colors.secondary, 0.20)
                        Column {
                            anchors.centerIn: parent
                            spacing: 1
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "" + root.todayContributions
                                color: colors.secondary
                                font.family: colors.fontSans
                                font.pixelSize: 15
                                font.weight: Font.Bold
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "TODAY"
                                color: colors.alpha(colors.foreground, 0.6)
                                font.family: colors.fontSans
                                font.pixelSize: 8
                                font.weight: Font.Bold
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 46
                        radius: 8
                        color: colors.alpha(colors.tertiary, 0.10)
                        border.width: 1
                        border.color: colors.alpha(colors.tertiary, 0.20)
                        Column {
                            anchors.centerIn: parent
                            spacing: 1
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "" + root.currentStreak + " Days"
                                color: colors.tertiary
                                font.family: colors.fontSans
                                font.pixelSize: 14
                                font.weight: Font.Bold
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "CURRENT STREAK"
                                color: colors.alpha(colors.foreground, 0.6)
                                font.family: colors.fontSans
                                font.pixelSize: 8
                                font.weight: Font.Bold
                            }
                        }
                    }
                }

                // Right: 5-Week Heatmap Grid
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 6

                        // Month label header
                        Row {
                            spacing: 12
                            Item { width: 28; height: 14 }
                            Repeater {
                                model: root.monthLabels
                                Text {
                                    text: modelData.name.toUpperCase()
                                    color: colors.alpha(colors.outline, 0.7)
                                    font.family: colors.fontSans
                                    font.pixelSize: 9
                                    font.weight: Font.Bold
                                    font.letterSpacing: 1.0
                                }
                            }
                        }

                        // Grid with Day labels
                        Row {
                            spacing: 8

                            // Day labels
                            Column {
                                spacing: 5
                                Repeater {
                                    model: ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
                                    Item {
                                        width: 26
                                        height: 20
                                        Text {
                                            anchors.centerIn: parent
                                            text: modelData
                                            color: colors.alpha(colors.outline, 0.55)
                                            font.family: colors.fontSans
                                            font.pixelSize: 8
                                            font.weight: Font.SemiBold
                                        }
                                    }
                                }
                            }

                            // 5 Columns of 7 Days
                            Row {
                                spacing: 6
                                Repeater {
                                    model: root.weeks
                                    Column {
                                        required property var modelData
                                        spacing: 5
                                        Repeater {
                                            model: modelData
                                            Rectangle {
                                                id: cellRect
                                                required property var modelData
                                                width: 20
                                                height: 20
                                                radius: 4
                                                color: root.heatColor(modelData.level, modelData.date > Qt.formatDate(new Date(), "yyyy-MM-dd"))
                                                border.width: (modelData.isToday ? 2 : (cellMa.containsMouse ? 1 : 0))
                                                border.color: (modelData.isToday ? colors.primary : colors.foreground)

                                                Text {
                                                    anchors.centerIn: parent
                                                    text: "" + modelData.dayNum
                                                    color: modelData.level >= 2 ? colors.background : colors.alpha(colors.foreground, 0.7)
                                                    font.family: colors.fontSans
                                                    font.pixelSize: 8
                                                    font.weight: Font.Bold
                                                }

                                                MouseArea {
                                                    id: cellMa
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    onEntered: root.hoveredDay = modelData
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Bottom Footer: Tooltip details + Update timestamp & Legend
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                // Dynamic Hover Tooltip
                Text {
                    text: root.hoveredDay ? (root.formatDate(root.hoveredDay.date) + " — " + (root.hoveredDay.count > 0 ? (root.hoveredDay.count + " contribution" + (root.hoveredDay.count > 1 ? "s" : "")) : "No contributions")) : "Hover over a day to view details"
                    color: root.hoveredDay ? colors.foreground : colors.alpha(colors.outline, 0.55)
                    font.family: colors.fontSans
                    font.pixelSize: 9
                    font.weight: root.hoveredDay ? Font.Medium : Font.Normal
                    Layout.fillWidth: true
                }

                // Update Frequency Timestamp
                Text {
                    text: root.lastUpdated ? ("Updated: " + root.lastUpdated) : "Syncing..."
                    color: colors.alpha(colors.outline, 0.55)
                    font.family: colors.fontSans
                    font.pixelSize: 8
                }

                // Legend
                Text {
                    text: "Less"
                    color: colors.alpha(colors.outline, 0.45)
                    font.family: colors.fontSans
                    font.pixelSize: 8
                }

                Row {
                    spacing: 3
                    Repeater {
                        model: [0, 1, 2, 3, 4]
                        Rectangle {
                            width: 10
                            height: 10
                            radius: 2
                            color: root.heatColor(modelData, false)
                        }
                    }
                }

                Text {
                    text: "More"
                    color: colors.alpha(colors.outline, 0.45)
                    font.family: colors.fontSans
                    font.pixelSize: 8
                }
            }
        }
    }
}
