Screen {
    id: root
    background: #F1F5F9

    property f64 card_width: root.width - 32 < 288 ? root.width - 32 : 288
    property f64 card_x: (root.width - root.card_width) / 2

    Rectangle {
        id: card
        x: root.card_x
        y: 16
        width: root.card_width
        height: 128
        background: #FFFFFF
        corner_radius: 10

        Label {
            id: state
            text: app.enabled ? "Enabled" : "Disabled"
            x: 16
            y: 14
            width: card.width - 32
            height: 34
            color: app.enabled ? #166534 : #991B1B
            font_size: 20
            bold: true
        }

        Checkbox {
            id: switch-control
            text: "Feature enabled"
            bind.checked: app.enabled
            x: 16
            y: 62
            width: card.width - 32
            height: 42
            color: #111827
            font_size: 15
        }
    }
}
