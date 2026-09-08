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

        Label { text: "Box layout inside a row" x: 20 y: 14 width: card.width - 40 height: 28 color: #111827 font_size: 18 bold: true }
        Label { text: "The outer inset behaves like the original row margin." x: 20 y: 42 width: card.width - 40 height: 20 color: #64748B font_size: 12 }

        Rectangle {
            id: stage
            x: 20
            y: 76
            width: card.width - 40
            height: card.height - 134
            background: #F8FAFC
            corner_radius: 8

            Rectangle {
                id: red_box
                x: 0
                y: 0
                width: stage.width * 0.3
                height: stage.height * 0.3
                background: #FF6464
                corner_radius: 8
            }

            Rectangle {
                id: green_box
                x: stage.width * 0.3
                y: stage.height * 0.3
                width: stage.width * 0.4
                height: stage.height * 0.4
                background: #86EFAC
                corner_radius: 8
            }

            TextArea {
                id: moving_text
                bind.text: app.text
                x: stage.width * (app.moved ? 0.8 : 0.7)
                y: stage.height * (app.moved ? 0.8 : 0.7)
                width: stage.width * (app.moved ? 0.2 : 0.3)
                height: stage.height * (app.moved ? 0.2 : 0.3)
                background: #FEF3C7
                color: #713F12
                font_size: 11
                corner_radius: 7
            }

            Button {
                id: move_text
                text: app.moved ? "Restore" : "Move text"
                on_tap: app.toggle_position()
                native: true
                x: stage.width * 0.7
                y: stage.height * 0.1
                width: stage.width * 0.25
                height: 36
            }
        }

        Label { id: layout_status text: app.status x: 20 y: card.height - 42 width: card.width - 40 height: 20 align: center color: #166534 font_size: 12 }
    }
}
