Screen {
    id: root
    background: #F1F5F9

    property f64 card_width: root.width - 32 < 248 ? root.width - 32 : 248
    property f64 card_x: (root.width - root.card_width) / 2
    property f64 card_y: (root.height - 64) / 2

    Rectangle {
        id: card
        x: root.card_x
        y: root.card_y
        width: root.card_width
        height: 64
        background: #FFFFFF
        corner_radius: 10

        Rectangle {
            x: 12
            y: 12
            width: card.width - 128
            height: 40
            background: #F8FAFC
            corner_radius: 7

            Label {
                id: count
                text: app.count
                x: 8
                y: 0
                width: card.width - 144
                height: 40
                color: #111827
                font_size: 20
                align: right
            }
        }

        Button {
            id: increment
            text: "Count"
            on_tap: app.increment()
            native: true
            x: card.width - 108
            y: 12
            width: 96
            height: 40
            background: #3478D4
            color: #FFFFFF
            bold: true
            align: center
            corner_radius: 7
        }
    }
}
