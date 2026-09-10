Screen {
    id: root
    background: #F1F5F9

    Label { text: "Profile: ${app.name}" x: 20 y: 52 width: root.width - 40 height: 34 align: center color: #0F172A font_size: 22 bold: true }
    Button { text: "Edit profile" on_tap: app.open_editor() x: (root.width - 140) / 2 y: 116 width: 140 height: 40 background: #2563EB color: #FFFFFF corner_radius: 8 }

    Popup {
        id: editor
        width: root.width
        height: root.height
        open: app.editing
        title: "Edit profile"
        on_dismiss: app.close_editor()
        content_width: 340
        content_height: 220
        title_height: 52
        separator_height: 1
        overlay_background: #475569
        background: #FFFFFF
        corner_radius: 12

        Label { text: "Display name" x: 24 y: 20 width: 292 height: 22 color: #475569 }
        TextInput { bind.text: app.name multiline: false x: 24 y: 48 width: 292 height: 38 background: #F8FAFC corner_radius: 7 }
        Button { text: "Cancel" on_tap: app.close_editor() x: 46 y: 112 width: 110 height: 38 background: #E2E8F0 color: #334155 corner_radius: 8 }
        Button { text: "Save" on_tap: app.save_editor() x: 184 y: 112 width: 110 height: 38 background: #2563EB color: #FFFFFF corner_radius: 8 }
    }
}
