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

        Label { text: "Font chooser" x: 18 y: 14 width: card.width - 36 height: 28 color: #111827 font_size: 18 bold: true }
        Label { text: "Choose a family, size, color, and emphasis for the editor." x: 18 y: 42 width: card.width - 36 height: 20 color: #64748B font_size: 12 }

        Dropdown {
            id: font_family
            bind.text: app.font_choice
            on_change: app.style_changed()
            x: 18 y: 74 width: 190 height: 38 background: #F1F5F9 corner_radius: 7
            Option { text: "System" }
            Option { text: "Serif" }
            Option { text: "Monospace" }
            Option { text: "Arial" }
        }
        Dropdown {
            id: font_size
            bind.text: app.size_choice
            on_change: app.style_changed()
            x: 220 y: 74 width: 100 height: 38 background: #F1F5F9 corner_radius: 7
            Option { text: "18" }
            Option { text: "24" }
            Option { text: "30" }
            Option { text: "36" }
        }
        Dropdown {
            id: text_color
            bind.text: app.color_choice
            on_change: app.style_changed()
            x: 332 y: 74 width: 150 height: 38 background: #F1F5F9 corner_radius: 7
            Option { text: "Red" }
            Option { text: "Blue" }
            Option { text: "Green" }
            Option { text: "Purple" }
        }
        Button { id: reset_style text: "Reset" on_tap: app.reset_style() native: true x: card.width - 118 y: 76 width: 100 height: 34 }

        Checkbox { id: bold text: "Bold" bind.checked: app.bold x: 18 y: 122 width: 100 height: 30 color: #334155 font_size: 12 }
        Checkbox { id: italic text: "Italic" bind.checked: app.italic x: 126 y: 122 width: 100 height: 30 color: #334155 font_size: 12 }

        TextArea {
            id: preview_editor
            bind.text: app.text
            x: 18
            y: 162
            width: card.width - 36
            height: card.height - 220
            background: #FEF3C7
            color: app.text_color
            font_size: app.font_size
            font_family: app.font_family
            bold: app.bold
            italic: app.italic
            corner_radius: 8
        }

        Label { id: font_status text: app.status x: 18 y: card.height - 40 width: card.width - 36 height: 18 align: center color: #166534 font_size: 12 }
    }
}
