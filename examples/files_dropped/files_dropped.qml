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

        Label { text: "Dropped files" x: 18 y: 14 width: card.width - 36 height: 28 color: #111827 font_size: 18 bold: true }
        Label { id: drop_status text: app.status x: 18 y: 43 width: card.width - 36 height: 20 color: #64748B font_size: 12 }

        Scroll {
            id: file_list
            x: 18
            y: 76
            width: card.width - 36
            height: card.height - 94
            background: #F8FAFC

            Repeater {
                model: app.files
                key: item.id

                Rectangle {
                    x: 8
                    y: 8 + index * 58
                    width: file_list.width - 32
                    height: 50
                    background: index % 2 == 0 ? #FFFFFF : #F1F5F9
                    corner_radius: 7

                    Label { text: item.name x: 12 y: 7 width: file_list.width - 64 height: 20 color: #1E293B font_size: 13 bold: true }
                    Label { text: item.path x: 12 y: 27 width: file_list.width - 64 height: 17 color: #64748B font_size: 10 }
                }
            }

            Label {
                id: empty_hint
                hidden: app.files.len > 0
                text: "Drag files here"
                x: 20
                y: (file_list.height - 24) / 2
                width: file_list.width - 40
                height: 24
                align: center
                color: #94A3B8
                font_size: 15
            }
        }
    }
}
