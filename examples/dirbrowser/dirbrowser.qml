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

        Label { text: "Directory browser" x: 18 y: 14 width: card.width - 36 height: 28 color: #111827 font_size: 18 bold: true }
        Label { id: current_path text: app.path x: 18 y: 44 width: card.width - 36 height: 20 color: #64748B font_size: 11 }

        Button { id: parent text: "Parent folder" on_tap: app.go_parent() native: true x: 18 y: 74 width: 130 height: 34 }
        Button { id: choose text: "Choose current" on_tap: app.choose_current() native: true x: card.width - 158 y: 74 width: 140 height: 34 }

        Scroll {
            id: folder_list
            x: 18
            y: 120
            width: card.width - 36
            height: card.height - 174
            background: #F8FAFC

            Repeater {
                model: app.entries
                key: item.path

                Button {
                    text: "▸  ${item.name}"
                    on_tap: app.open_entry(item.id)
                    native: true
                    x: 8
                    y: 6 + index * 38
                    width: folder_list.width - 32
                    height: 32
                }
            }

            Label { hidden: app.entries.len > 0 text: "No child folders" x: 16 y: 30 width: folder_list.width - 32 height: 24 align: center color: #94A3B8 font_size: 13 }
        }

        Label { id: browser_status text: app.status x: 18 y: card.height - 40 width: card.width - 36 height: 18 align: center color: #166534 font_size: 11 }
    }
}
