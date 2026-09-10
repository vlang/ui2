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

        Label { text: "Editor" x: 18 y: 14 width: 100 height: 28 color: #111827 font_size: 18 bold: true }
        Checkbox { id: sidebar_open text: "Files" bind.checked: app.sidebar_open x: 126 y: 14 width: 76 height: 30 color: #334155 font_size: 11 }
        Label { text: app.current_name.len > 0 ? (app.dirty ? "${app.current_name} •" : app.current_name) : "No file open" x: 212 y: 18 width: card.width - 462 height: 20 align: center color: app.dirty ? #B45309 : #64748B font_size: 11 }
        TextField { id: new_name bind.text: app.new_name on_submit: app.create_file() placeholder: "new_file.v" x: card.width - 242 y: 12 width: 128 height: 36 background: #F8FAFC corner_radius: 7 font_size: 11 }
        Button { id: create_file text: "New" on_tap: app.create_file() native: true x: card.width - 108 y: 13 width: 42 height: 34 }
        Button { id: save_file text: "Save" on_tap: app.save_file() enabled: app.current_path.len > 0 native: true x: card.width - 60 y: 13 width: 42 height: 34 }

        Rectangle {
            id: file_panel
            hidden: !app.sidebar_open
            x: 18
            y: 62
            width: 190
            height: card.height - 118
            background: #F8FAFC
            corner_radius: 8

            Label { text: app.root_path x: 10 y: 8 width: file_panel.width - 20 height: 18 color: #64748B font_size: 9 }
            Scroll { id: editor_files x: 8 y: 32 width: file_panel.width - 16 height: file_panel.height - 40 background: #F8FAFC
                Repeater { model: app.files key: item.path
                    Button { text: item.name on_tap: app.open_file(item.id) native: true x: 2 y: index * 36 width: editor_files.width - 20 height: 30 background: item.path == app.current_path ? #DBEAFE : #FFFFFF font_size: 10 }
                }
            }
        }

        TextArea {
            id: editor_text
            bind.text: app.text
            on_change: app.mark_dirty()
            x: app.sidebar_open ? 220 : 18
            y: 62
            width: app.sidebar_open ? card.width - 238 : card.width - 36
            height: card.height - 118
            background: #FFFBEB
            color: #1E293B
            font_family: "Courier New"
            font_size: 12
            corner_radius: 8
        }

        Label { id: editor_status text: app.status x: 18 y: card.height - 40 width: card.width - 36 height: 18 align: center color: app.dirty ? #B45309 : #166534 font_size: 10 }
    }
}
