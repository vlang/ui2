Screen {
    id: root
    background: app.screen_background
    transparent: app.transparent_screen

    Rectangle {
        id: card_shadow
        x: 16
        y: 14
        width: root.width - 32
        height: 122
        background: #020617
        corner_radius: 22
    }

    Rectangle {
        id: card
        x: 12
        y: 10
        width: root.width - 32
        height: 122
        background: #111827
        corner_radius: 22
        border_color: #334155
        border_width: 1

        Rectangle {
            id: window_drag
            on_tap: "window_drag"
            clickable: true
            draggable: true
            x: 0
            y: 0
            width: card.width
            height: 48
            transparent: true

            Rectangle { x: 18 y: 18 width: 10 height: 10 background: #34D399 corner_radius: 5 }
            Label { text: "FOCUS WIDGET" x: 38 y: 13 width: 200 height: 22 color: #E2E8F0 font_size: 12 bold: true }
            Label { text: "drag anywhere on this header" x: 202 y: 14 width: card.width - 252 height: 20 align: right color: #64748B font_size: 10 }
        }

        Button { id: close text: "×" on_tap: "close" x: card.width - 42 y: 10 width: 30 height: 30 background: #7F1D1D corner_radius: 15 color: #FEE2E2 font_size: 18 bold: true accessibility_label: "Close widget" }
        Label { text: app.completed_label x: 20 y: 57 width: card.width - 40 height: 26 color: #F8FAFC font_size: 19 bold: true }
        Label { text: app.platform_note x: 20 y: 91 width: card.width - 40 height: 18 color: #94A3B8 font_size: 10 }
    }

    Rectangle {
        id: action_shadow
        x: root.width / 2 - 130
        y: 152
        width: 260
        height: 48
        background: #020617
        corner_radius: 24
    }

    Rectangle {
        id: actions
        x: root.width / 2 - 132
        y: 148
        width: 260
        height: 48
        background: #1E293B
        corner_radius: 24
        border_color: #475569
        border_width: 1

        Button { id: decrement text: "−" on_tap: "decrement" enabled: app.completed > 0 x: 8 y: 7 width: 50 height: 34 background: #334155 corner_radius: 17 color: #F8FAFC font_size: 18 bold: true accessibility_label: "Remove a completed session" }
        Button { id: reset text: app.completed x: 68 y: 7 width: 120 height: 34 background: #0F172A corner_radius: 17 color: #A7F3D0 font_size: 16 bold: true accessibility_label: "Reset completed sessions" on_tap: "reset" }
        Button { id: increment text: "+" on_tap: "increment" x: 198 y: 7 width: 54 height: 34 background: #047857 corner_radius: 17 color: #ECFDF5 font_size: 18 bold: true accessibility_label: "Complete a focus session" }
    }
}
