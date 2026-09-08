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

        Label {
            text: "Grid"
            x: 16
            y: 14
            width: card.width - 32
            height: 28
            color: #111827
            font_size: 18
            bold: true
        }

        Label {
            text: "A small responsive table"
            x: 16
            y: 42
            width: card.width - 32
            height: 20
            color: #64748B
            font_size: 12
        }

        Rectangle {
            id: table
            x: 16
            y: 76
            width: card.width - 32
            height: 132
            background: #CBD5E1
            corner_radius: 7

            Repeater {
                model: app.cells
                key: item.id

                Rectangle {
                    x: 1 + item.column * ((table.width - 2) / 3)
                    y: 1 + item.row * 43
                    width: (table.width - 2) / 3 - 1
                    height: 42
                    background: item.header ? #334155 : (item.row == 1 ? #FFFFFF : #F8FAFC)

                    Label {
                        text: item.text
                        x: 10
                        y: 0
                        width: (table.width - 2) / 3 - 21
                        height: 42
                        color: item.header ? #FFFFFF : #1E293B
                        font_size: item.header ? 13 : 12
                        bold: item.header
                    }
                }
            }
        }

        Label {
            text: "3 columns · 2 data rows"
            x: 16
            y: 224
            width: card.width - 32
            height: 20
            color: #64748B
            font_size: 12
            align: right
        }
    }
}
