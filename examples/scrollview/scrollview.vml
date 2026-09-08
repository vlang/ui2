Screen {
    id: root
    background: #F1F5F9

    property f64 pane_width: (root.width - 80) / 2

    Rectangle {
        id: card
        x: 16
        y: 16
        width: root.width - 32
        height: root.height - 32
        background: #FFFFFF
        corner_radius: 10

        Label { text: "Scrollview" x: 16 y: 14 width: card.width - 32 height: 28 color: #111827 font_size: 18 bold: true }
        Label { text: "Information" x: 16 y: 52 width: root.pane_width height: 20 color: #475569 font_size: 12 }
        Label { text: "Generated lines" x: 32 + root.pane_width y: 52 width: root.pane_width height: 20 color: #475569 font_size: 12 }

        TextArea {
            id: info
            text: app.info
            editable: false
            x: 16
            y: 76
            width: root.pane_width
            height: card.height - 92
            background: #F8FAFC
            color: #334155
            font_size: 13
            corner_radius: 7
        }

        TextArea {
            id: text
            text: app.text
            editable: false
            x: 32 + root.pane_width
            y: 76
            width: root.pane_width
            height: card.height - 92
            background: #FCF4E4
            color: #334155
            font_size: 13
            corner_radius: 7
        }
    }
}
