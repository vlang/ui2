Screen {
    id: root
    background: #F1F5F9

    property f64 card_width: root.width - 32 < 568 ? root.width - 32 : 568
    property f64 card_x: (root.width - root.card_width) / 2
    property f64 field_width: (root.card_width - 48) / 2

    Rectangle {
        id: card
        x: root.card_x
        y: 16
        width: root.card_width
        height: 136
        background: #FFFFFF
        corner_radius: 10

        Label {
            text: "Temperature Converter"
            x: 16
            y: 12
            width: card.width - 32
            height: 26
            color: #111827
            font_size: 18
            bold: true
        }

        Label {
            text: "Celsius"
            x: 16
            y: 48
            width: root.field_width
            height: 18
            color: #475569
            font_size: 12
        }

        TextField {
            id: celsius
            bind.text: app.celsius
            on_change: app.update_from_celsius()
            placeholder: "0"
            keyboard: decimal
            x: 16
            y: 70
            width: root.field_width
            height: 42
            background: app.celsius_valid ? #F8FAFC : #FED7AA
            color: #111827
            corner_radius: 7
        }

        Label {
            text: "Fahrenheit"
            x: root.field_width + 32
            y: 48
            width: root.field_width
            height: 18
            color: #475569
            font_size: 12
        }

        TextField {
            id: fahrenheit
            bind.text: app.fahrenheit
            on_change: app.update_from_fahrenheit()
            placeholder: "32"
            keyboard: decimal
            x: root.field_width + 32
            y: 70
            width: root.field_width
            height: 42
            background: app.fahrenheit_valid ? #F8FAFC : #FED7AA
            color: #111827
            corner_radius: 7
        }
    }
}
