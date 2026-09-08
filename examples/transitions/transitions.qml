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

        Label { text: "Transitions" x: 18 y: 14 width: 180 height: 28 color: #111827 font_size: 18 bold: true }
        Label { text: app.target_label x: card.width - 286 y: 18 width: 150 height: 20 align: right color: #64748B font_size: 11 }
        Button { id: slide text: app.moving ? "Redirect" : "Slide" on_tap: "slide" native: true x: card.width - 126 y: 13 width: 108 height: 34 }

        Rectangle {
            id: stage
            x: 18
            y: 62
            width: card.width - 36
            height: card.height - 146
            background: #F8FAFC
            corner_radius: 9

            Rectangle { x: 24 y: 24 width: stage.width - 48 height: stage.height - 48 background: #FFFFFF corner_radius: 8 }
            Rectangle { id: moving_tile x: 24 y: 24 width: 82 height: 82 background: #4F6FA8 corner_radius: 14
                Label { text: "V" x: 0 y: 0 width: 82 height: 82 align: center color: #FFFFFF font_size: 34 bold: true }
            }
        }

        Rectangle { x: 18 y: card.height - 66 width: card.width - 36 height: 6 background: #E2E8F0 corner_radius: 3
            Rectangle { x: 0 y: 0 width: app.progress * (card.width - 36) height: 6 background: #60A5FA corner_radius: 3 }
        }
        Label { id: transition_status text: app.status x: 18 y: card.height - 48 width: card.width - 36 height: 20 align: center color: #166534 font_size: 11 }
    }
}
