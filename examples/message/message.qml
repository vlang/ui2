Screen {
    id: root
    background: #F1F5F9

    Rectangle {
        x: 16
        y: 16
        width: root.width - 32
        height: root.height - 32
        background: #FFFFFF
        corner_radius: 10

        Label { text: "Message" x: 16 y: 14 width: root.width - 64 height: 28 color: #111827 font_size: 18 bold: true }
        Label { text: "Open a simple in-window dialog." x: 16 y: 50 width: root.width - 64 height: 22 color: #64748B font_size: 13 }

        Button {
            id: show_message
            text: "Show message"
            on_tap: app.show_message()
            native: true
            x: 16
            y: 92
            width: root.width - 64
            height: 36
        }
    }

    Rectangle {
        id: overlay
        hidden: !app.visible
        x: 0
        y: 0
        width: root.width
        height: root.height
        background: #CBD5E1

        Rectangle {
            id: dialog
            x: (overlay.width - 300) / 2
            y: (overlay.height - 150) / 2
            width: 300
            height: 150
            background: #FFFFFF
            corner_radius: 12

            Label { text: "Hello World" x: 20 y: 20 width: dialog.width - 40 height: 28 color: #111827 font_size: 18 bold: true }
            Label { text: "This message came from the ui example." x: 20 y: 54 width: dialog.width - 40 height: 22 color: #475569 font_size: 12 }

            Button {
                id: close_message
                text: "OK"
                on_tap: app.close_message()
                native: true
                x: dialog.width - 100
                y: dialog.height - 52
                width: 80
                height: 32
            }
        }
    }
}
