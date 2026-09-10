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

        Label { text: "Tree view" x: 18 y: 14 width: card.width - 36 height: 28 color: #111827 font_size: 18 bold: true }
        Label { text: "Expand nested folders and select leaf files." x: 18 y: 42 width: card.width - 36 height: 20 color: #64748B font_size: 12 }

        Scroll {
            id: tree_list
            x: 18
            y: 76
            width: card.width - 36
            height: card.height - 130
            background: #F8FAFC

            Repeater {
                model: app.visible
                key: item.id

                Button {
                    text: item.folder ? (item.expanded ? "▾  ${item.title}" : "▸  ${item.title}") : "•  ${item.title}"
                    on_tap: app.select_node(item.id)
                    native: true
                    x: 8 + item.depth * 24
                    y: 6 + index * 38
                    width: tree_list.width - 32 - item.depth * 24
                    height: 32
                }
            }
        }

        Label { id: tree_status text: app.status x: 18 y: card.height - 40 width: card.width - 36 height: 18 align: center color: #166534 font_size: 12 }
    }
}
