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
        Label { text: "Native alerts belong to the system; the drawn one stays in the window." x: 16 y: 50 width: root.width - 64 height: 22 color: #64748B font_size: 13 }

        Button {
            id: show_native_message
            text: "Show native message"
            on_tap: app.show_native_message()
            native: true
            x: 16
            y: 92
            width: root.width - 64
            height: 36
        }

        Button {
            id: ask_native_question
            text: "Ask a native question"
            on_tap: app.ask_native_question()
            native: true
            x: 16
            y: 136
            width: root.width - 64
            height: 36
        }

        Button {
            id: show_message
            text: "Show drawn message"
            on_tap: app.show_message()
            native: true
            x: 16
            y: 180
            width: root.width - 64
            height: 36
        }

        Label { id: answer text: app.answer x: 16 y: 228 width: root.width - 64 height: 22 color: #475569 font_size: 13 }
    }

    MessageBox {
        id: overlay
        hidden: !app.visible
        title: "Hello World"
        text: "This message came from the ui example."

        Button {
            id: close_message
            text: "OK"
            on_tap: app.close_message()
        }
    }
}
