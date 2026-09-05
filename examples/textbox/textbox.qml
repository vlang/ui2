Screen {
    id: root
    background: #F1F5F9

    property f64 card_width: root.width - 32
    property f64 editor_width: (root.card_width - 48) / 2

    Rectangle {
        id: card
        x: 16
        y: 16
        width: root.card_width
        height: root.height - 32
        background: #FFFFFF
        corner_radius: 10

        Label {
            text: "Textbox Demo"
            x: 16
            y: 14
            width: card.width - 32
            height: 24
            color: #111827
            font_size: 18
            bold: true
        }

        TextField {
            id: title
            bind.text: app.title
            placeholder: "Document title"
            x: 16
            y: 50
            width: card.width - 32
            height: 28
            background: #F8FAFC
            corner_radius: 7
        }

        Label { text: "Editable" x: 16 y: 94 width: root.editor_width height: 18 color: #475569 }
        Label { text: "Read-only preview" x: 32 + root.editor_width y: 94 width: root.editor_width height: 18 color: #475569 }

        TextArea {
            id: notes
            bind.text: app.notes
            on_change: app.update_status()
            x: 16
            y: 116
            width: root.editor_width
            height: card.height - 176
            background: #FCF4E4
            color: #111827
            font_size: 15
            corner_radius: 7
        }

        TextArea {
            id: preview
            text: app.notes
            editable: false
            hidden: !app.show_preview
            x: 32 + root.editor_width
            y: 116
            width: root.editor_width
            height: card.height - 176
            background: #F8FAFC
            color: #334155
            font_size: 15
            corner_radius: 7
        }

        Checkbox {
            id: show_preview
            text: "Show preview"
            bind.checked: app.show_preview
            x: 16
            y: card.height - 48
            width: 150
            height: 24
        }

        Label {
            id: status
            text: app.status
            x: 174
            y: card.height - 45
            width: card.width - 296
            height: 18
            color: #64748B
            font_size: 13
            align: center
        }

        Button {
            id: clear
            text: "Clear"
            on_tap: app.clear()
            native: true
            x: card.width - 106
            y: card.height - 52
            width: 90
            height: 32
            background: #E2E8F0
            corner_radius: 7
        }
    }
}
