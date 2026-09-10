Screen {
    id: root
    background: #F1F5F9

    property f64 card_width: root.width - 32 < 328 ? root.width - 32 : 328
    property f64 card_x: (root.width - root.card_width) / 2
    property f64 row_x: (root.card_width - 286) / 2

    Rectangle {
        id: card
        x: root.card_x
        y: 16
        width: root.card_width
        height: 140
        background: #FFFFFF
        corner_radius: 10

        Label {
            text: "Four rectangles"
            x: 16
            y: 14
            width: card.width - 32
            height: 24
            color: #111827
            font_size: 18
            bold: true
            align: center
        }

        Rectangle {
            id: red
            x: root.row_x
            y: 54
            width: 64
            height: 64
            background: #FF6464
        }
        Rectangle {
            id: green
            x: root.row_x + 74
            y: 54
            width: 64
            height: 64
            background: #64FF64
        }
        Rectangle {
            id: blue
            x: root.row_x + 148
            y: 54
            width: 64
            height: 64
            background: #6464FF
        }
        Rectangle {
            id: magenta
            x: root.row_x + 222
            y: 54
            width: 64
            height: 64
            background: #FF64FF
        }
    }
}
