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

        Label { text: "Box layout with a text box" x: 18 y: 14 width: card.width - 36 height: 28 color: #111827 font_size: 18 bold: true }
        Label { text: "Fixed, stretched, percentage-anchored, and nested content." x: 18 y: 42 width: card.width - 36 height: 20 color: #64748B font_size: 12 }

        Rectangle {
            id: canvas
            x: 18
            y: 74
            width: card.width - 36
            height: card.height - 132
            background: #F8FAFC
            corner_radius: 8

            Rectangle {
                id: fixed_red
                x: 0
                y: 0
                width: 58
                height: 58
                background: #FF6464
                corner_radius: 7
            }

            Rectangle {
                id: stretched_green
                x: 58
                y: 58
                width: canvas.width - 88
                height: canvas.height - 88
                background: #BBF7D0
                corner_radius: 8
            }

            TextArea {
                id: notes
                bind.text: app.text
                on_change: app.text_changed()
                x: canvas.width / 2
                y: canvas.height / 2
                width: canvas.width / 2
                height: canvas.height / 2
                background: #FEF3C7
                color: #713F12
                font_size: 12
                corner_radius: 7
            }

            Rectangle {
                id: corner_anchor
                x: canvas.width - 58
                y: canvas.height - 58
                width: 58
                height: 58
                background: #FFFFFF
                corner_radius: 7

                Rectangle { id: nested_anchor x: 10 y: 10 width: 38 height: 38 background: #334155 corner_radius: 6 }
            }

            Button {
                id: show_message
                text: "Show message"
                on_tap: app.show_message()
                native: true
                x: canvas.width * 0.68
                y: 18
                width: canvas.width * 0.28
                height: 36
            }
        }

        Label { id: status text: app.status x: 18 y: card.height - 42 width: card.width - 36 height: 20 align: center color: #166534 font_size: 12 }
    }
}
