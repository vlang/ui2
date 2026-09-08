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

        Label { text: "Menu bar" x: 18 y: 14 width: card.width - 36 height: 28 color: #111827 font_size: 18 bold: true }
        Label { id: backend_note text: app.backend_note x: 18 y: 44 width: card.width - 36 height: 20 color: #64748B font_size: 12 }

        Rectangle { x: 18 y: 74 width: 150 height: 54 background: #EFF6FF corner_radius: 8
            Label { text: "Show Details" x: 12 y: 8 width: 126 height: 16 color: #1D4ED8 font_size: 11 }
            Label { id: details_state text: app.show_details ? "on" : "off" x: 12 y: 26 width: 126 height: 20 color: #1E3A8A font_size: 15 bold: true }
        }
        Rectangle { x: 178 y: 74 width: 150 height: 54 background: #EFF6FF corner_radius: 8
            Label { text: "Word Wrap" x: 12 y: 8 width: 126 height: 16 color: #1D4ED8 font_size: 11 }
            Label { id: wrap_state text: app.word_wrap ? "on" : "off" x: 12 y: 26 width: 126 height: 20 color: #1E3A8A font_size: 15 bold: true }
        }
        Rectangle { x: 338 y: 74 width: 150 height: 54 background: #EFF6FF corner_radius: 8
            Label { text: "Zoom" x: 12 y: 8 width: 126 height: 16 color: #1D4ED8 font_size: 11 }
            Label { id: zoom_state text: "${app.zoom}%" x: 12 y: 26 width: 126 height: 20 color: #1E3A8A font_size: 15 bold: true }
        }

        Rectangle { x: 18 y: 142 width: card.width - 36 height: 48 background: #DCFCE7 corner_radius: 8
            Label { id: last_action text: app.last_action x: 14 y: 0 width: card.width - 64 height: 48 color: #166534 font_size: 13 }
        }

        Label { text: "Chosen rows" x: 18 y: 202 width: card.width - 36 height: 18 color: #64748B font_size: 12 }

        TextArea {
            id: menu_log
            text: app.log
            editable: false
            x: 18
            y: 224
            width: card.width - 36
            height: card.height - 286
            background: #F8FAFC
            color: #334155
            font_size: 13
            corner_radius: 7
        }

        Button { id: reset text: "Clear log" on_tap: "reset" native: true enabled: app.chosen > 0 x: 18 y: card.height - 52 width: 110 height: 34 }
        Label { id: chosen_count text: "${app.chosen} chosen" x: 140 y: card.height - 46 width: card.width - 176 height: 22 color: #94A3B8 font_size: 12 }
    }
}
