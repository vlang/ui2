Screen {
    id: root
    background: #F1F5F9

    Rectangle {
        id: card
        x: 16
        y: 16
        width: root.width - 32
        height: root.height - 32
        background: #FFFFFF
        corner_radius: 10

        Label { text: "Log view" x: 16 y: 14 width: card.width - 32 height: 28 color: #111827 font_size: 18 bold: true }
        Label { id: status text: app.status x: 16 y: 42 width: card.width - 32 height: 20 color: #64748B font_size: 12 }

        TextArea {
            id: log
            text: app.log
            editable: false
            x: 16
            y: 72
            width: card.width - 32
            height: card.height - 134
            background: #FCF4E4
            color: #334155
            font_size: 13
            corner_radius: 7
        }

        Button { id: start_scan text: "Start scan" on_tap: app.start_scan() native: true x: 16 y: card.height - 50 width: 130 height: 34 }
        Button { id: clear text: "Clear" on_tap: app.clear() native: true enabled: app.log.len > 0 x: card.width - 106 y: card.height - 50 width: 90 height: 34 }
    }
}
