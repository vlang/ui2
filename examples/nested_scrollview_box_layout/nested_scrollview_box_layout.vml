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

        Label { text: "Nested scrollviews in a box layout" x: 16 y: 14 width: card.width - 32 height: 28 color: #111827 font_size: 18 bold: true }
        Label { text: "The outer canvas and every text box scroll independently." x: 16 y: 42 width: card.width - 32 height: 20 color: #64748B font_size: 12 }

        Scroll {
            id: box_grid
            x: 16
            y: 74
            width: card.width - 32
            height: card.height - 90
            background: #FEF9C3

            Repeater {
                model: app.boxes
                key: item.id

                TextArea {
                    text: item.content
                    x: 8 + item.column * ((box_grid.width - 16) / 5)
                    y: 8 + item.row * 112
                    width: (box_grid.width - 16) / 5 - 8
                    height: 104
                    background: #FFFFFF
                    color: #475569
                    font_size: 11
                    corner_radius: 6
                }
            }
        }
    }
}
