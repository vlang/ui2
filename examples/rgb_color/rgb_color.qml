Screen {
    id: root
    background: #F1F5F9

    property f64 card_width: root.width - 32 < 348 ? root.width - 32 : 348
    property f64 card_x: (root.width - root.card_width) / 2
    property f64 field_width: (root.card_width - 64) / 3

    Rectangle {
        id: card
        x: root.card_x
        y: 16
        width: root.card_width
        height: 290
        background: #FFFFFF
        corner_radius: 10

        Label {
            text: "RGB color"
            x: 16
            y: 14
            width: card.width - 32
            height: 24
            color: #111827
            font_size: 18
            bold: true
        }

        Rectangle {
            id: preview
            x: 16
            y: 50
            width: card.width - 32
            height: 100
            background: app.preview_color
            corner_radius: 8

            Label {
                text: app.valid ? "" : "Invalid RGB value"
                x: 8
                y: 41
                width: card.width - 48
                height: 18
                color: #991B1B
                font_size: 13
                bold: true
                align: center
            }
        }

        Label { text: "R" x: 16 y: 164 width: root.field_width height: 18 align: center color: #991B1B }
        Label { text: "G" x: 32 + root.field_width y: 164 width: root.field_width height: 18 align: center color: #166534 }
        Label { text: "B" x: 48 + root.field_width * 2 y: 164 width: root.field_width height: 18 align: center color: #1E40AF }

        TextField {
            id: red
            bind.text: app.red
            on_change: app.update_color()
            x: 16
            y: 184
            width: root.field_width
            height: 28
            background: app.valid ? #F8FAFC : #FEE2E2
            corner_radius: 7
        }
        TextField {
            id: green
            bind.text: app.green
            on_change: app.update_color()
            x: 32 + root.field_width
            y: 184
            width: root.field_width
            height: 28
            background: app.valid ? #F8FAFC : #FEE2E2
            corner_radius: 7
        }
        TextField {
            id: blue
            bind.text: app.blue
            on_change: app.update_color()
            x: 48 + root.field_width * 2
            y: 184
            width: root.field_width
            height: 28
            background: app.valid ? #F8FAFC : #FEE2E2
            corner_radius: 7
        }

        Button {
            id: show_color
            text: "Show RGB color"
            on_tap: app.show_color()
            native: true
            x: 16
            y: 224
            width: card.width - 32
            height: 34
            background: #3478D4
            color: #FFFFFF
            corner_radius: 7
        }

        Label {
            id: value
            text: app.message
            x: 16
            y: 266
            width: card.width - 32
            height: 18
            color: app.valid ? #166534 : #991B1B
            font_size: 13
            align: center
        }
    }
}
