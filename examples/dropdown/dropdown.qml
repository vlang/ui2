Screen {
    id: root
    background: #F1F5F9

    property f64 card_width: root.width - 32 < 328 ? root.width - 32 : 328
    property f64 card_x: (root.width - root.card_width) / 2

    Rectangle {
        id: card
        x: root.card_x
        y: 16
        width: root.card_width
        height: 188
        background: #FFFFFF
        corner_radius: 10

        Label {
            text: "User actions"
            x: 16
            y: 16
            width: card.width - 32
            height: 26
            color: #111827
            font_size: 18
            bold: true
        }

        Dropdown {
            id: actions
            bind.text: app.selection
            on_change: app.selection_changed()
            x: 16
            y: 54
            width: card.width - 32
            height: 42
            background: #DBEAFE
            color: #1D4ED8
            corner_radius: 7

            Option { text: "Delete all users" }
            Option { text: "Export users" }
            Option { text: "Exit" }
        }

        Rectangle {
            x: 16
            y: 112
            width: card.width - 32
            height: 56
            background: #DCFCE7
            corner_radius: 7

            Label {
                id: selection-message
                text: app.message
                x: 10
                y: 13
                width: card.width - 52
                height: 30
                color: #166534
                font_size: 13
                align: center
            }
        }
    }
}
