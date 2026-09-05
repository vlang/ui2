Screen {
    id: root
    background: #F1F5F9

    property f64 card_width: root.width - 32 < 368 ? root.width - 32 : 368
    property f64 card_x: (root.width - root.card_width) / 2
    property bool return_flight: app.flight_type == "return flight"
    property bool can_book: app.departure_valid && (!root.return_flight || app.return_valid)

    Rectangle {
        id: card
        x: root.card_x
        y: 16
        width: root.card_width
        height: 358
        background: #FFFFFF
        corner_radius: 10

        Label {
            text: "Book a flight"
            x: 16
            y: 14
            width: card.width - 32
            height: 28
            color: #111827
            font_size: 20
            bold: true
        }

        Dropdown {
            id: flight-type
            bind.text: app.flight_type
            on_change: app.flight_type_changed()
            x: 16
            y: 52
            width: card.width - 32
            height: 40
            background: #F8FAFC
            color: #111827
            corner_radius: 7

            Option { text: "one-way flight" }
            Option { text: "return flight" }
        }

        Label {
            text: "Departure (DD.MM.YYYY)"
            x: 16
            y: 106
            width: card.width - 32
            height: 18
            color: #475569
            font_size: 12
        }

        TextField {
            id: departure
            bind.text: app.departure
            on_change: app.validate_departure()
            x: 16
            y: 128
            width: card.width - 32
            height: 28
            background: app.departure_valid ? #F8FAFC : #FED7AA
            color: #111827
            corner_radius: 7
        }

        Label {
            text: "Return (DD.MM.YYYY)"
            x: 16
            y: 180
            width: card.width - 32
            height: 18
            color: root.return_flight ? #475569 : #94A3B8
            font_size: 12
        }

        TextField {
            id: return-date
            bind.text: app.return_date
            on_change: app.validate_return()
            enabled: root.return_flight
            x: 16
            y: 202
            width: card.width - 32
            height: 28
            background: app.return_valid ? #F8FAFC : #FED7AA
            color: #111827
            corner_radius: 7
        }

        Button {
            id: book
            text: "Book"
            on_tap: app.book()
            enabled: root.can_book
            x: 16
            y: 258
            width: card.width - 32
            height: 40
            background: root.can_book ? #3478D4 : #CBD5E1
            color: #FFFFFF
            bold: true
            align: center
            corner_radius: 7
        }

        Label {
            id: confirmation
            text: app.confirmation
            hidden: app.confirmation.len == 0
            x: 16
            y: 310
            width: card.width - 32
            height: 34
            color: #166534
            font_size: 13
            lines: 2
        }
    }
}
