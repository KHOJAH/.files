import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

FloatingWindow {
    id: root
    property var colors
    property bool open: false

    title: "Screen Time Activity"
    implicitWidth: 840
    implicitHeight: 295
    minimumSize: Qt.size(800, 260)
    maximumSize: Qt.size(900, 340)
    color: "transparent"
    visible: root.open

    IpcHandler {
        target: "screentime"
        function toggle(): void { root.open = !root.open }
    }

    property string formattedTotal: "0m"
    property string dailyAverage: "0m"
    property int currentStreak: 0
    property int longestStreak: 0
    property int activeDays: 0
    property var topApps: []
    property var monthLabels: []
    property var weeks: []
    property var hoveredDay: null

    Process {
        id: fetcher
        command: ["python3", Quickshell.env("HOME") + "/.config/quickshell/scripts/screentime-calendar.py"]
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                try {
                    var j = JSON.parse(text)
                    if (j) {
                        root.formattedTotal = j.formattedTotal || "0m"
                        root.dailyAverage = j.dailyAverage || "0m"
                        root.currentStreak = j.currentStreak || 0
                        root.longestStreak = j.longestStreak || 0
                        root.activeDays = j.activeDays || 0
                        root.topApps = j.topApps || []
                        root.monthLabels = j.monthLabels || []
                        root.weeks = j.weeks || []
                    }
                } catch (e) {}
            }
        }
    }

    onOpenChanged: {
        if (open) {
            fetcher.running = true
        } else {
            root.hoveredDay = null
        }
    }

    function heatColor(lvl) {
        if (lvl === 0) return colors.alpha(colors.outline, 0.08)
        if (lvl === 1) return colors.alpha(colors.secondary, 0.30)
        if (lvl === 2) return colors.alpha(colors.secondary, 0.55)
        if (lvl === 3) return colors.alpha(colors.secondary, 0.78)
        return colors.secondary
    }

    function formatDate(ds) {
        if (!ds) return ""
        try {
            var parts = ds.split("-")
            var d = new Date(parts[0], parts[1] - 1, parts[2])
            return d.toLocaleDateString(Qt.locale(), "dddd, MMM d, yyyy")
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
            spacing: 11

            // Top Header: Title, Stats & Close
            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                Text {
                    text: "SCREEN TIME ACTIVITY"
                    color: colors.secondary
                    font.family: colors.fontSans
                    font.pixelSize: 11
                    font.weight: Font.ExtraBold
                    font.letterSpacing: 1.4
                }

                Item { Layout.fillWidth: true }

                // Stat Pills
                Row {
                    spacing: 8

                    Rectangle {
                        height: 22
                        width: statCol1.width + 16
                        radius: 6
                        color: colors.alpha(colors.secondary, 0.10)
                        border.width: 1
                        border.color: colors.alpha(colors.secondary, 0.20)
                        Row {
                            id: statCol1
                            anchors.centerIn: parent
                            spacing: 4
                            Text { text: root.formattedTotal; color: colors.secondary; font.family: colors.fontSans; font.pixelSize: 10; font.weight: Font.Bold }
                            Text { text: "total"; color: colors.alpha(colors.foreground, 0.65); font.family: colors.fontSans; font.pixelSize: 9 }
                        }
                    }

                    Rectangle {
                        height: 22
                        width: statCol2.width + 16
                        radius: 6
                        color: colors.alpha(colors.primary, 0.10)
                        border.width: 1
                        border.color: colors.alpha(colors.primary, 0.20)
                        Row {
                            id: statCol2
                            anchors.centerIn: parent
                            spacing: 4
                            Text { text: root.dailyAverage; color: colors.primary; font.family: colors.fontSans; font.pixelSize: 10; font.weight: Font.Bold }
                            Text { text: "avg/day"; color: colors.alpha(colors.foreground, 0.65); font.family: colors.fontSans; font.pixelSize: 9 }
                        }
                    }

                    Rectangle {
                        height: 22
                        width: statCol3.width + 16
                        radius: 6
                        color: colors.alpha(colors.tertiary, 0.10)
                        border.width: 1
                        border.color: colors.alpha(colors.tertiary, 0.20)
                        Row {
                            id: statCol3
                            anchors.centerIn: parent
                            spacing: 4
                            Text { text: "" + root.currentStreak + "d"; color: colors.tertiary; font.family: colors.fontSans; font.pixelSize: 10; font.weight: Font.Bold }
                            Text { text: "streak"; color: colors.alpha(colors.foreground, 0.65); font.family: colors.fontSans; font.pixelSize: 9 }
                        }
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

            // Calendar Grid Container (53 weeks)
            Item {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: 26 + (53 * 10) + (52 * 3)
                Layout.preferredHeight: 14 + (7 * 10) + (6 * 3)

                // Month labels across top
                Row {
                    x: 28
                    y: 0
                    spacing: 0
                    Repeater {
                        model: root.monthLabels
                        Item {
                            required property var modelData
                            width: (modelData.col === 0 ? 32 : 55)
                            height: 14
                            Text {
                                text: modelData.name
                                color: colors.alpha(colors.outline, 0.65)
                                font.family: colors.fontSans
                                font.pixelSize: 8
                                font.weight: Font.SemiBold
                            }
                        }
                    }
                }

                // Day of week labels on left
                Column {
                    x: 0
                    y: 16
                    spacing: 3
                    Item { width: 22; height: 10 } // Sun
                    Item {
                        width: 22; height: 10
                        Text { anchors.left: parent.left; text: "Mon"; color: colors.alpha(colors.outline, 0.5); font.family: colors.fontSans; font.pixelSize: 8 }
                    }
                    Item { width: 22; height: 10 } // Tue
                    Item {
                        width: 22; height: 10
                        Text { anchors.left: parent.left; text: "Wed"; color: colors.alpha(colors.outline, 0.5); font.family: colors.fontSans; font.pixelSize: 8 }
                    }
                    Item { width: 22; height: 10 } // Thu
                    Item {
                        width: 22; height: 10
                        Text { anchors.left: parent.left; text: "Fri"; color: colors.alpha(colors.outline, 0.5); font.family: colors.fontSans; font.pixelSize: 8 }
                    }
                    Item { width: 22; height: 10 } // Sat
                }

                // 53 Columns of 7 Day cells
                Row {
                    x: 26
                    y: 16
                    spacing: 3
                    Repeater {
                        model: root.weeks
                        Column {
                            required property var modelData
                            spacing: 3
                            Repeater {
                                model: modelData
                                Rectangle {
                                    id: cellRect
                                    required property var modelData
                                    width: 10
                                    height: 10
                                    radius: 2
                                    color: root.heatColor(modelData.level)
                                    border.width: cellMa.containsMouse ? 1 : 0
                                    border.color: colors.foreground

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

            // Bottom Footer: Tooltip status & Legend
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                // Dynamic Hover Tooltip
                Text {
                    text: root.hoveredDay ? (root.formatDate(root.hoveredDay.date) + " — " + (root.hoveredDay.seconds > 0 ? (root.hoveredDay.formatted + " active") : "No activity recorded")) : "Hover over a day to view details"
                    color: root.hoveredDay ? colors.foreground : colors.alpha(colors.outline, 0.5)
                    font.family: colors.fontSans
                    font.pixelSize: 9
                    font.weight: root.hoveredDay ? Font.Medium : Font.Normal
                    Layout.fillWidth: true
                }

                // Legend
                Text {
                    text: "Less"
                    color: colors.alpha(colors.outline, 0.5)
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
                            color: root.heatColor(modelData)
                        }
                    }
                }

                Text {
                    text: "More"
                    color: colors.alpha(colors.outline, 0.5)
                    font.family: colors.fontSans
                    font.pixelSize: 8
                }
            }

            // Top Applications Pill Row
            Row {
                Layout.fillWidth: true
                spacing: 6
                visible: root.topApps.length > 0

                Text {
                    text: "Top Apps:"
                    color: colors.alpha(colors.outline, 0.6)
                    font.family: colors.fontSans
                    font.pixelSize: 8
                    font.weight: Font.Bold
                    anchors.verticalCenter: parent.verticalCenter
                }

                Repeater {
                    model: root.topApps.slice(0, 4)
                    Rectangle {
                        required property var modelData
                        height: 18
                        width: appRow.width + 12
                        radius: 4
                        color: colors.alpha(colors.surfaceVariant, 0.4)
                        Row {
                            id: appRow
                            anchors.centerIn: parent
                            spacing: 4
                            Text { text: modelData.app; color: colors.foreground; font.family: colors.fontSans; font.pixelSize: 8; font.weight: Font.SemiBold }
                            Text { text: modelData.formatted; color: colors.alpha(colors.secondary, 0.85); font.family: colors.fontSans; font.pixelSize: 8 }
                        }
                    }
                }
            }
        }
    }
}
