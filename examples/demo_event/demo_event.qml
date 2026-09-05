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

        Label { text: "Event inspector" x: 18 y: 14 width: 180 height: 28 color: #111827 font_size: 18 bold: true }
        Button { id: sample_button text: "Native event" on_tap: "sample_button" native: true x: card.width - 246 y: 14 width: 120 height: 34 }
        Button { id: clear_events text: "Clear" on_tap: "clear" native: true x: card.width - 114 y: 14 width: 96 height: 34 }

        Rectangle {
            id: event_surface
            on_tap: "event_surface"
            clickable: true
            draggable: true
            cursor: "pointing_hand"
            x: 18
            y: 62
            width: card.width - 36
            height: 120
            background: #DBEAFE
            corner_radius: 9

            Label { text: "Click or drag here" x: 16 y: 28 width: event_surface.width - 32 height: 28 align: center color: #1D4ED8 font_size: 17 bold: true }
            Label { text: "Keyboard events are captured when an editor is not focused." x: 16 y: 62 width: event_surface.width - 32 height: 20 align: center color: #3B82F6 font_size: 11 }
        }

        Rectangle { x: 18 y: 194 width: (card.width - 44) / 2 height: 52 background: #F8FAFC corner_radius: 7
            Label { text: "Pointer events" x: 10 y: 7 width: (card.width - 84) / 2 height: 16 align: center color: #64748B font_size: 10 }
            Label { text: "${app.pointer_events}" x: 10 y: 23 width: (card.width - 84) / 2 height: 22 align: center color: #111827 font_size: 16 bold: true }
        }
        Rectangle { x: 26 + (card.width - 44) / 2 y: 194 width: (card.width - 44) / 2 height: 52 background: #F8FAFC corner_radius: 7
            Label { text: "Key events" x: 10 y: 7 width: (card.width - 84) / 2 height: 16 align: center color: #64748B font_size: 10 }
            Label { text: "${app.key_events}" x: 10 y: 23 width: (card.width - 84) / 2 height: 22 align: center color: #111827 font_size: 16 bold: true }
        }

        Label { id: last_event text: app.last_event x: 18 y: 258 width: card.width - 36 height: 24 align: center color: #166534 font_size: 12 }
        TextArea { id: event_history text: app.history editable: false x: 18 y: 290 width: card.width - 36 height: card.height - 308 background: #FFFBEB color: #78350F font_family: "Courier New" font_size: 11 corner_radius: 7 }
    }
}
