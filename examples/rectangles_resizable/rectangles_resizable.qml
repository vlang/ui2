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

        Label { text: "Resizable rectangles" x: 18 y: 14 width: card.width - 36 height: 28 align: center color: #111827 font_size: 18 bold: true }
        Label { text: "Each rounded box takes an equal share of the available row." x: 18 y: 42 width: card.width - 36 height: 18 align: center color: #64748B font_size: 11 }

        Repeater {
            model: app.colors
            key: item.id

            Rectangle {
                x: 18 + index * ((card.width - 62) / 4 + 8)
                y: 72
                width: (card.width - 62) / 4
                height: card.height - 90
                background: item.color
                corner_radius: 10

                Label { text: item.name x: 0 y: (card.height - 110) / 2 width: (card.width - 62) / 4 height: 20 align: center color: item.text_color font_size: 13 bold: true }
            }
        }
    }
}
