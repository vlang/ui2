Screen {
    id: root
    background: #F1F5F9

    Label { text: "Screen manager" x: 20 y: 14 width: root.width - 40 height: 30 color: #0F172A font_size: 20 bold: true }

    ScreenManager {
        id: navigation
        x: 20
        y: 56
        width: root.width - 40
        height: 240
        current: app.current
        background: #FFFFFF
        corner_radius: 10

        Screen {
            id: home
            Label { text: "Home" x: 24 y: 26 width: 240 height: 34 color: #0F172A font_size: 24 bold: true }
            Label { text: "Only this screen is mounted." x: 24 y: 68 width: 300 height: 24 color: #64748B }
            Button { text: "Open details" on_tap: app.show_details() x: 24 y: 116 width: 140 height: 38 background: #2563EB color: #FFFFFF corner_radius: 8 }
        }

        Screen {
            id: details
            background: #EFF6FF
            Label { text: "Details" x: 24 y: 26 width: 240 height: 34 color: #1E3A8A font_size: 24 bold: true }
            Label { text: "State-driven navigation keeps content isolated." x: 24 y: 68 width: 340 height: 24 color: #475569 }
            Button { text: "Back home" on_tap: app.show_home() x: 24 y: 116 width: 120 height: 38 background: #FFFFFF color: #1D4ED8 corner_radius: 8 }
        }
    }
}
