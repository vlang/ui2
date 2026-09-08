Screen {
    id: root
    background: #F1F5F9

    Label { text: "Unified text input" x: 20 y: 14 width: root.width - 40 height: 30 color: #0F172A font_size: 20 bold: true }

    Label { text: "Title" x: 20 y: 56 width: 80 height: 24 color: #475569 font_size: 12 }
    TextInput {
        id: title
        multiline: false
        bind.text: app.title
        on_text_validate: app.save()
        hint_text: "Document title"
        x: 20
        y: 80
        width: root.width - 40
        height: 38
        background: #FFFFFF
        corner_radius: 7
    }

    Label { text: "Notes" x: 20 y: 132 width: 80 height: 24 color: #475569 font_size: 12 }
    TextInput {
        id: notes
        bind.text: app.notes
        hint_text: "Write notes"
        x: 20
        y: 156
        width: root.width - 40
        height: 108
        background: #FFFFFF
        corner_radius: 7
    }
}
