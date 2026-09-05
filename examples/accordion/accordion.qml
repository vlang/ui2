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

        Label { text: "Accordion" x: 18 y: 14 width: card.width - 36 height: 28 color: #111827 font_size: 18 bold: true }
        Label { text: "Open one component page at a time." x: 18 y: 42 width: card.width - 36 height: 20 color: #64748B font_size: 12 }

        Scroll {
            id: section_list
            x: 18
            y: 74
            width: card.width - 36
            height: card.height - 126
            background: #F8FAFC

            Repeater {
                model: app.sections
                key: item.id

                Rectangle {
                    x: 8
                    y: 8 + index * 48 + (app.open_id > 0 && item.id > app.open_id ? 120 : 0)
                    width: section_list.width - 32
                    height: item.id == app.open_id ? 160 : 40
                    background: #FFFFFF
                    corner_radius: 7

                    Button {
                        text: item.id == app.open_id ? "▾  ${item.title}" : "▸  ${item.title}"
                        on_tap: app.toggle_section(item.id)
                        native: true
                        x: 4
                        y: 3
                        width: section_list.width - 40
                        height: 34
                    }

                    Rectangle {
                        hidden: item.id != app.open_id
                        x: 8
                        y: 44
                        width: section_list.width - 48
                        height: 108
                        background: item.color
                        corner_radius: 7

                        Label { text: item.description x: 14 y: 16 width: section_list.width - 76 height: 24 color: #1E293B font_size: 14 bold: true }
                        Label { text: item.detail x: 14 y: 49 width: section_list.width - 76 height: 40 color: #475569 font_size: 12 lines: 2 }
                    }
                }
            }
        }

        Label { id: accordion_status text: app.status x: 18 y: card.height - 40 width: card.width - 36 height: 18 align: center color: #166534 font_size: 12 }
    }
}
