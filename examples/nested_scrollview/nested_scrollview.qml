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

        Label { text: "Nested scrollviews" x: 16 y: 14 width: card.width - 32 height: 28 color: #111827 font_size: 18 bold: true }
        Label { text: "Scroll the list, then scroll inside any text box." x: 16 y: 42 width: card.width - 32 height: 20 color: #64748B font_size: 12 }

        Scroll {
            id: outer_scroll
            x: 16
            y: 74
            width: card.width - 32
            height: card.height - 90
            background: #F8FAFC

            Repeater {
                model: app.boxes
                key: item.id

                Rectangle {
                    x: 8
                    y: 8 + index * 116
                    width: card.width - 64
                    height: 104
                    background: index % 2 == 0 ? #FFFFFF : #F1F5F9
                    corner_radius: 7

                    Label { text: item.title x: 12 y: 16 width: 82 height: 24 color: #334155 font_size: 13 bold: true }
                    Label { text: "8 lines" x: 12 y: 44 width: 82 height: 20 color: #94A3B8 font_size: 11 }

                    TextArea {
                        text: item.content
                        editable: false
                        x: 104
                        y: 16
                        width: card.width - 184
                        height: 72
                        background: #FCF4E4
                        color: #475569
                        font_size: 12
                        corner_radius: 6
                    }
                }
            }
        }
    }
}
