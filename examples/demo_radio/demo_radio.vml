Screen {
    id: root
    background: #F1F5F9

    property f64 card_width: root.width - 32 < 648 ? root.width - 32 : 648
    property f64 card_x: (root.width - root.card_width) / 2

    Rectangle {
        id: card
        x: root.card_x
        y: 16
        width: root.card_width
        height: root.height - 32
        background: #FFFFFF
        corner_radius: 10

        Label { text: "Country" x: 18 y: 14 width: card.width - 36 height: 28 color: #111827 font_size: 18 bold: true }
        Label { text: "Exclusive choices using ui2's portable selection controls." x: 18 y: 42 width: card.width - 36 height: 20 color: #64748B font_size: 12 }

        Checkbox {
            id: compact_switch
            text: "Compact horizontal layout"
            bind.checked: app.compact
            x: 18
            y: 72
            width: card.width - 36
            height: 30
            color: #334155
            font_size: 13
        }

        Rectangle {
            id: choices
            x: 18
            y: 112
            width: card.width - 36
            height: app.compact ? 66 : 158
            background: #F8FAFC
            corner_radius: 8

            Repeater {
                model: app.countries
                key: item.id

                Checkbox {
                    text: item.name
                    checked: item.name == app.selected_country
                    on_tap: app.select_country(item.name)
                    x: app.compact ? 12 + index * ((choices.width - 24) / 4) : 16
                    y: app.compact ? 18 : 10 + index * 36
                    width: app.compact ? (choices.width - 24) / 4 : choices.width - 32
                    height: 30
                    color: #1E293B
                    font_size: 12
                }
            }
        }

        Rectangle {
            x: 18
            y: app.compact ? 192 : 284
            width: card.width - 36
            height: 42
            background: #DCFCE7
            corner_radius: 7

            Label { id: selected_country text: app.message x: 10 y: 11 width: card.width - 56 height: 20 align: center color: #166534 font_size: 13 }
        }
    }
}
