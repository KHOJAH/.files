import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

FloatingWindow {
    id: root
    property var colors
    property bool open: false

    title: "Activity Dashboard"
    implicitWidth: 840
    implicitHeight: 310
    minimumSize: Qt.size(840, 310)
    maximumSize: Qt.size(840, 310)
    color: "transparent"
    visible: root.open

    IpcHandler {
        target: "activity"
        function toggle(): void { root.open = !root.open }
    }

    IpcHandler {
        target: "github"
        function toggle(): void { root.open = !root.open }
    }

    property string lastUpdated: ""
    property var ghData: ({ username: "", totalCount: 0, todayCount: 0, currentStreak: 0, longestStreak: 0, monthLabels: [], weeks: [], status: "ok", statusMessage: "" })
    property var stData: ({ totalFormatted: "0m", todayFormatted: "0m", dailyAvgFormatted: "0m", currentStreak: 0, activeDays: 0, topApps: [], monthLabels: [], weeks: [] })
    property var hoveredGhDay: null
    property var hoveredStDay: null
    property bool isRefreshing: false

    // Debounced hover clearing so mouse movement across 3px cell gaps doesn't flicker
    Timer {
        id: ghClearTimer
        interval: 90
        repeat: false
        onTriggered: root.hoveredGhDay = null
    }

    Timer {
        id: stClearTimer
        interval: 90
        repeat: false
        onTriggered: root.hoveredStDay = null
    }

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
            fetcher.command = ["python3", Quickshell.env("HOME") + "/.config/quickshell/scripts/activity-dashboard.py", "--refresh"]
        } else {
            fetcher.command = ["python3", Quickshell.env("HOME") + "/.config/quickshell/scripts/activity-dashboard.py"]
        }
        fetcher.running = true
    }

    Process {
        id: fetcher
        command: ["python3", Quickshell.env("HOME") + "/.config/quickshell/scripts/activity-dashboard.py"]
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                root.isRefreshing = false
                try {
                    var j = JSON.parse(text)
                    if (j) {
                        root.lastUpdated = j.lastUpdated || Qt.formatTime(new Date(), "hh:mm:ss")
                        if (j.github) root.ghData = j.github
                        if (j.screentime) root.stData = j.screentime
                    }
                } catch (e) {}
            }
        }
    }

    onOpenChanged: {
        if (open) {
            root.triggerRefresh(false)
        } else {
            ghClearTimer.stop()
            stClearTimer.stop()
            root.hoveredGhDay = null
            root.hoveredStDay = null
        }
    }

    function ghHeatColor(lvl, isFuture) {
        if (isFuture) return colors.alpha(colors.outline, 0.04)
        if (lvl === 0) return colors.alpha(colors.outline, 0.10)
        if (lvl === 1) return colors.alpha(colors.primary, 0.32)
        if (lvl === 2) return colors.alpha(colors.primary, 0.58)
        if (lvl === 3) return colors.alpha(colors.primary, 0.80)
        return colors.primary
    }

    function stHeatColor(lvl, isFuture) {
        if (isFuture) return colors.alpha(colors.outline, 0.04)
        if (lvl === 0) return colors.alpha(colors.outline, 0.10)
        if (lvl === 1) return colors.alpha(colors.secondary, 0.32)
        if (lvl === 2) return colors.alpha(colors.secondary, 0.58)
        if (lvl === 3) return colors.alpha(colors.secondary, 0.80)
        return colors.secondary
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
        width: 840
        height: 310
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
            anchors.margins: 16
            spacing: 10

            // Top Header: Global Title, Last Updated & Close
            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                Text {
                    text: "ACTIVITY DASHBOARD"
                    color: colors.primary
                    font.family: colors.fontSans
                    font.pixelSize: 11
                    font.weight: Font.ExtraBold
                    font.letterSpacing: 1.4
                }

                Text {
                    text: "Last 3 Months"
                    color: colors.alpha(colors.foreground, 0.55)
                    font.family: colors.fontSans
                    font.pixelSize: 9
                    font.weight: Font.Medium
                }

                Item { Layout.fillWidth: true }

                // Frequency / Last Updated pill
                Row {
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 6

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.lastUpdated ? ("Last updated: " + root.lastUpdated) : "Updating..."
                        color: colors.alpha(colors.outline, 0.65)
                        font.family: colors.fontSans
                        font.pixelSize: 9
                        font.weight: Font.Medium
                    }

                    // Refresh Button
                    Rectangle {
                        width: 22
                        height: 22
                        radius: 11
                        color: refreshMa.containsMouse ? colors.alpha(colors.primary, 0.15) : "transparent"
                        Text {
                            anchors.centerIn: parent
                            text: "󰑐"
                            color: root.isRefreshing ? colors.primary : (refreshMa.containsMouse ? colors.primary : colors.alpha(colors.outline, 0.7))
                            font.family: colors.fontSans
                            font.pixelSize: 11
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
                }

                // Close Button
                Rectangle {
                    Layout.alignment: Qt.AlignVCenter
                    width: 22
                    height: 22
                    radius: 11
                    color: closeMa.containsMouse ? colors.alpha(colors.surfaceVariant, 0.5) : "transparent"
                    Text {
                        anchors.centerIn: parent
                        text: "󰅖"
                        color: closeMa.containsMouse ? colors.foreground : colors.alpha(colors.outline, 0.7)
                        font.family: colors.fontSans
                        font.pixelSize: 11
                    }
                    MouseArea {
                        id: closeMa
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: root.open = false
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: colors.alpha(colors.outline, 0.10)
            }

            // Side-by-Side Content Panels: Physically decoupled 50/50 split
            Item {
                id: splitArea
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredWidth: 808

                // Center Vertical Divider — fixed at exact horizontal center
                Rectangle {
                    id: centerDivider
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: 1
                    color: colors.alpha(colors.outline, 0.12)
                }

                // ── LEFT: GitHub Panel ──
                Item {
                    id: leftPanel
                    anchors.left: parent.left
                    anchors.right: centerDivider.left
                    anchors.rightMargin: 12
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    clip: true

                    ColumnLayout {
                        anchors.fill: parent
                        spacing: 8

                        // Section Subheader
                        Item {
                            Layout.fillWidth: true
                            height: 22

                            Row {
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 6

                                Text {
                                    text: "GITHUB"
                                    color: colors.primary
                                    font.family: colors.fontSans
                                    font.pixelSize: 10
                                    font.weight: Font.Bold
                                    font.letterSpacing: 1.0
                                }

                                Text {
                                    text: {
                                        if (root.ghData.status === "auth_required") return "• login needed (gh auth login)"
                                        if (root.ghData.status === "not_installed") return "• gh not found"
                                        if (root.ghData.status === "error") return "• connection error"
                                        if (root.ghData.username) return "@" + root.ghData.username
                                        return ""
                                    }
                                    color: (root.ghData.status && root.ghData.status !== "ok" && root.ghData.status !== "loading") ? colors.error : colors.alpha(colors.foreground, 0.55)
                                    font.family: colors.fontSans
                                    font.pixelSize: 9
                                }
                            }

                            Row {
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 4

                                Text {
                                    text: "" + (root.ghData.totalCount || 0)
                                    color: colors.primary
                                    font.family: colors.fontSans
                                    font.pixelSize: 9
                                    font.weight: Font.Bold
                                }

                                Text {
                                    text: "contributions"
                                    color: colors.alpha(colors.foreground, 0.6)
                                    font.family: colors.fontSans
                                    font.pixelSize: 8
                                }

                                Text {
                                    text: "• " + (root.ghData.currentStreak || 0) + "d streak"
                                    color: colors.alpha(colors.foreground, 0.5)
                                    font.family: colors.fontSans
                                    font.pixelSize: 8
                                }
                            }
                        }

                        // 13-week Heatmap Grid
                        Item {
                            Layout.alignment: Qt.AlignHCenter
                            Layout.preferredWidth: 26 + (13 * 13) + (12 * 3)
                            Layout.preferredHeight: 14 + (7 * 13) + (6 * 3)

                            // Month labels precisely positioned over column start
                            Item {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                height: 14

                                Repeater {
                                    model: root.ghData.monthLabels || []
                                    Text {
                                        required property var modelData
                                        x: 26 + (modelData.col * 16)
                                        text: (modelData.name || "").toUpperCase()
                                        color: colors.alpha(colors.outline, 0.65)
                                        font.family: colors.fontSans
                                        font.pixelSize: 8
                                        font.weight: Font.Bold
                                    }
                                }
                            }

                            // Day labels on left, vertically centered per row
                            Item {
                                x: 0
                                y: 15
                                width: 22
                                height: 109

                                Item {
                                    y: 16; width: 22; height: 13
                                    Text { anchors.verticalCenter: parent.verticalCenter; text: "Mon"; color: colors.alpha(colors.outline, 0.5); font.family: colors.fontSans; font.pixelSize: 8 }
                                }
                                Item {
                                    y: 48; width: 22; height: 13
                                    Text { anchors.verticalCenter: parent.verticalCenter; text: "Wed"; color: colors.alpha(colors.outline, 0.5); font.family: colors.fontSans; font.pixelSize: 8 }
                                }
                                Item {
                                    y: 80; width: 22; height: 13
                                    Text { anchors.verticalCenter: parent.verticalCenter; text: "Fri"; color: colors.alpha(colors.outline, 0.5); font.family: colors.fontSans; font.pixelSize: 8 }
                                }
                            }

                            // 13 Columns of 7 Days
                            Row {
                                x: 26
                                y: 15
                                spacing: 3
                                Repeater {
                                    model: root.ghData.weeks || []
                                    Column {
                                        required property var modelData
                                        spacing: 3
                                        Repeater {
                                            model: modelData
                                            Rectangle {
                                                required property var modelData
                                                width: 13
                                                height: 13
                                                radius: 3
                                                color: root.ghHeatColor(modelData.level, modelData.date > Qt.formatDate(new Date(), "yyyy-MM-dd"))
                                                border.width: modelData.isToday ? 2 : (ghMa.containsMouse ? 1 : 0)
                                                border.color: modelData.isToday ? colors.primary : (ghMa.containsMouse ? colors.foreground : "transparent")

                                                MouseArea {
                                                    id: ghMa
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    onEntered: {
                                                        ghClearTimer.stop()
                                                        root.hoveredGhDay = modelData
                                                    }
                                                    onExited: {
                                                        ghClearTimer.restart()
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // GitHub Footer: Tooltip + Fixed Legend (Rock-solid layout)
                        Item {
                            Layout.fillWidth: true
                            height: 18

                            Text {
                                anchors.left: parent.left
                                anchors.right: ghLegend.left
                                anchors.rightMargin: 10
                                anchors.verticalCenter: parent.verticalCenter
                                elide: Text.ElideRight
                                maximumLineCount: 1
                                text: root.hoveredGhDay ? (root.formatDate(root.hoveredGhDay.date) + " — " + (root.hoveredGhDay.count > 0 ? (root.hoveredGhDay.count + (root.hoveredGhDay.count === 1 ? " contribution" : " contributions")) : "No commits")) : (root.ghData.status === "auth_required" ? "GitHub CLI login required — run 'gh auth login' in terminal" : (root.ghData.status === "not_installed" ? "GitHub CLI not found — install github-cli" : (root.ghData.status === "error" ? (root.ghData.statusMessage || "GitHub API error — click refresh to retry") : "Hover day for details")))
                                color: root.hoveredGhDay ? colors.foreground : colors.alpha(colors.outline, 0.55)
                                font.family: colors.fontSans
                                font.pixelSize: 9
                                font.weight: Font.Medium
                            }

                            Row {
                                id: ghLegend
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 4

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "Less"
                                    color: colors.alpha(colors.outline, 0.45)
                                    font.family: colors.fontSans
                                    font.pixelSize: 8
                                }
                                Row {
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 2
                                    Repeater {
                                        model: [0, 1, 2, 3, 4]
                                        Rectangle {
                                            required property var modelData
                                            width: 8
                                            height: 8
                                            radius: 2
                                            color: root.ghHeatColor(modelData, false)
                                        }
                                    }
                                }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "More"
                                    color: colors.alpha(colors.outline, 0.45)
                                    font.family: colors.fontSans
                                    font.pixelSize: 8
                                }
                            }
                        }
                    }
                }

                // ── RIGHT: Screen Time Panel ──
                Item {
                    id: rightPanel
                    anchors.left: centerDivider.right
                    anchors.leftMargin: 12
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    clip: true

                    ColumnLayout {
                        anchors.fill: parent
                        spacing: 8

                        // Section Subheader
                        Item {
                            Layout.fillWidth: true
                            height: 22

                            Row {
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 6

                                Text {
                                    text: "SCREEN TIME"
                                    color: colors.secondary
                                    font.family: colors.fontSans
                                    font.pixelSize: 10
                                    font.weight: Font.Bold
                                    font.letterSpacing: 1.0
                                }
                            }

                            Row {
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 4

                                Text {
                                    text: root.stData.totalFormatted || "0m"
                                    color: colors.secondary
                                    font.family: colors.fontSans
                                    font.pixelSize: 9
                                    font.weight: Font.Bold
                                }

                                Text {
                                    text: "total"
                                    color: colors.alpha(colors.foreground, 0.6)
                                    font.family: colors.fontSans
                                    font.pixelSize: 8
                                }

                                Text {
                                    text: "• today: " + (root.stData.todayFormatted || "0m")
                                    color: colors.alpha(colors.foreground, 0.5)
                                    font.family: colors.fontSans
                                    font.pixelSize: 8
                                }
                            }
                        }

                        // 13-week Heatmap Grid
                        Item {
                            Layout.alignment: Qt.AlignHCenter
                            Layout.preferredWidth: 26 + (13 * 13) + (12 * 3)
                            Layout.preferredHeight: 14 + (7 * 13) + (6 * 3)

                            // Month labels precisely positioned over column start
                            Item {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                height: 14

                                Repeater {
                                    model: root.stData.monthLabels || []
                                    Text {
                                        required property var modelData
                                        x: 26 + (modelData.col * 16)
                                        text: (modelData.name || "").toUpperCase()
                                        color: colors.alpha(colors.outline, 0.65)
                                        font.family: colors.fontSans
                                        font.pixelSize: 8
                                        font.weight: Font.Bold
                                    }
                                }
                            }

                            // Day labels on left, vertically centered per row
                            Item {
                                x: 0
                                y: 15
                                width: 22
                                height: 109

                                Item {
                                    y: 16; width: 22; height: 13
                                    Text { anchors.verticalCenter: parent.verticalCenter; text: "Mon"; color: colors.alpha(colors.outline, 0.5); font.family: colors.fontSans; font.pixelSize: 8 }
                                }
                                Item {
                                    y: 48; width: 22; height: 13
                                    Text { anchors.verticalCenter: parent.verticalCenter; text: "Wed"; color: colors.alpha(colors.outline, 0.5); font.family: colors.fontSans; font.pixelSize: 8 }
                                }
                                Item {
                                    y: 80; width: 22; height: 13
                                    Text { anchors.verticalCenter: parent.verticalCenter; text: "Fri"; color: colors.alpha(colors.outline, 0.5); font.family: colors.fontSans; font.pixelSize: 8 }
                                }
                            }

                            // 13 Columns of 7 Days
                            Row {
                                x: 26
                                y: 15
                                spacing: 3
                                Repeater {
                                    model: root.stData.weeks || []
                                    Column {
                                        required property var modelData
                                        spacing: 3
                                        Repeater {
                                            model: modelData
                                            Rectangle {
                                                required property var modelData
                                                width: 13
                                                height: 13
                                                radius: 3
                                                color: root.stHeatColor(modelData.level, modelData.date > Qt.formatDate(new Date(), "yyyy-MM-dd"))
                                                border.width: modelData.isToday ? 2 : (stMa.containsMouse ? 1 : 0)
                                                border.color: modelData.isToday ? colors.secondary : (stMa.containsMouse ? colors.foreground : "transparent")

                                                MouseArea {
                                                    id: stMa
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    onEntered: {
                                                        stClearTimer.stop()
                                                        root.hoveredStDay = modelData
                                                    }
                                                    onExited: {
                                                        stClearTimer.restart()
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // ScreenTime Footer: Tooltip + Fixed Legend (Rock-solid layout)
                        Item {
                            Layout.fillWidth: true
                            height: 18

                            Text {
                                anchors.left: parent.left
                                anchors.right: stLegend.left
                                anchors.rightMargin: 10
                                anchors.verticalCenter: parent.verticalCenter
                                elide: Text.ElideRight
                                maximumLineCount: 1
                                text: root.hoveredStDay ? (root.formatDate(root.hoveredStDay.date) + " — " + (root.hoveredStDay.seconds > 0 ? (root.hoveredStDay.formatted + " active") : "No activity")) : "Hover day for details"
                                color: root.hoveredStDay ? colors.foreground : colors.alpha(colors.outline, 0.55)
                                font.family: colors.fontSans
                                font.pixelSize: 9
                                font.weight: Font.Medium
                            }

                            Row {
                                id: stLegend
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 4

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "Less"
                                    color: colors.alpha(colors.outline, 0.45)
                                    font.family: colors.fontSans
                                    font.pixelSize: 8
                                }
                                Row {
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 2
                                    Repeater {
                                        model: [0, 1, 2, 3, 4]
                                        Rectangle {
                                            required property var modelData
                                            width: 8
                                            height: 8
                                            radius: 2
                                            color: root.stHeatColor(modelData, false)
                                        }
                                    }
                                }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "More"
                                    color: colors.alpha(colors.outline, 0.45)
                                    font.family: colors.fontSans
                                    font.pixelSize: 8
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
