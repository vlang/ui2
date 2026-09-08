Screen {
    id: root
    background: #F1F5F9

    Label {
        text: "Dashboard"
        x: 20
        y: 16
        width: root.width - 40
        height: 32
        color: #0F172A
        font_size: 22
        bold: true
    }

    GridLayout {
        id: dashboard
        x: 20
        y: 60
        width: root.width - 40
        height: root.height - 80
        columns: 3
        padding: 8
        spacing: 8

        Button { text: "Overview" background: #DBEAFE corner_radius: 8 }
        Button { text: "Activity" background: #DCFCE7 corner_radius: 8 }
        Button { text: "Messages" background: #FCE7F3 corner_radius: 8 }
        Button { text: "Files" background: #FEF3C7 corner_radius: 8 }
        Button { text: "Calendar" background: #EDE9FE corner_radius: 8 }
        Button { text: "Settings" background: #E2E8F0 corner_radius: 8 }
    }
}
