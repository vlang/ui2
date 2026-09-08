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

        Label { text: "File browser" x: 18 y: 14 width: card.width - 36 height: 28 color: #111827 font_size: 18 bold: true }
        Label { id: current_path text: app.path x: 18 y: 42 width: card.width - 36 height: 20 color: #64748B font_size: 11 }
        Button { id: parent text: "Parent folder" on_tap: app.go_parent() native: true x: 18 y: 70 width: 130 height: 34 }
        Label { text: app.selected_name.len > 0 ? "Selected: ${app.selected_name}" : "Select a file" x: 164 y: 77 width: card.width - 182 height: 20 align: right color: #475569 font_size: 12 }

        Scroll {
            id: browser_list
            x: 18
            y: 116
            width: card.width - 36
            height: card.height - 188
            background: #F8FAFC

            Repeater {
                model: app.entries
                key: item.path

                Button {
                    text: item.directory ? "▸  ${item.name}" : "${item.name}"
                    on_tap: app.activate(item.id)
                    native: true
                    x: 8
                    y: 6 + index * 38
                    width: browser_list.width - 32
                    height: 32
                    background: item.path == app.selected_path ? #DBEAFE : #FFFFFF
                }
            }

            Label { hidden: app.entries.len > 0 text: "This folder is empty" x: 16 y: 30 width: browser_list.width - 32 height: 24 align: center color: #94A3B8 font_size: 13 }
        }

        Label { id: browser_status text: app.status x: 18 y: card.height - 62 width: card.width - 256 height: 20 color: #166534 font_size: 11 }
        Button { id: cancel text: "Cancel" on_tap: app.cancel_selection() native: true x: card.width - 222 y: card.height - 68 width: 96 height: 34 }
        Button { id: open text: "Open" on_tap: app.confirm_selection() native: true x: card.width - 114 y: card.height - 68 width: 96 height: 34 }
    }
}
