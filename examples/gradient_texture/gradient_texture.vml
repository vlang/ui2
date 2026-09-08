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

        Label { text: "Gradient texture" x: 18 y: 14 width: 220 height: 28 color: #111827 font_size: 18 bold: true }
        Button { id: previous_hue text: "Previous" on_tap: app.previous_hue() native: true x: card.width - 220 y: 13 width: 92 height: 34 }
        Button { id: next_hue text: "Next" on_tap: app.next_hue() native: true x: card.width - 118 y: 13 width: 100 height: 34 }

        Rectangle {
            id: gradient
            x: 18
            y: 64
            width: card.width - 36
            height: card.height - 132
            background: #111827
            corner_radius: 0

            Repeater { model: app.cells key: item.id
                Rectangle {
                    x: item.column * gradient.width / 20
                    y: item.row * gradient.height / 14
                    width: gradient.width / 20 + 1
                    height: gradient.height / 14 + 1
                    background: item.color
                }
            }
        }

        Rectangle { x: 18 y: card.height - 50 width: 18 height: 18 background: app.hue_color corner_radius: 9 }
        Label { text: app.status x: 46 y: card.height - 52 width: card.width - 64 height: 22 color: #475569 font_size: 11 }
    }
}
