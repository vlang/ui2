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

        Label { text: "Slider & textbox" x: 18 y: 14 width: 220 height: 28 color: #111827 font_size: 18 bold: true }
        Button { id: reset text: "Reset" on_tap: "reset" native: true x: card.width - 108 y: 13 width: 90 height: 34 }

        Rectangle { id: horizontal_panel x: 18 y: 60 width: card.width - 36 height: 132 background: #F8FAFC corner_radius: 9
            Label { text: "Horizontal · −20 to 100" x: 18 y: 14 width: horizontal_panel.width - 130 height: 22 color: #475569 font_size: 12 bold: true }
            TextField { id: horizontal_input text: app.horizontal_text on_change: "horizontal_input" on_submit: "horizontal_input" x: horizontal_panel.width - 94 y: 10 width: 76 height: 34 background: app.horizontal_valid ? #FFFFFF : #FEE2E2 corner_radius: 7 align: center keyboard: decimal }
            Slider { id: horizontal_slider on_change: "horizontal_slider" x: 20 y: 66 width: horizontal_panel.width - 40 height: 24 min: -20 max: 100 value: app.horizontal_value step: 1 padding: 11 value_track: true background: #CBD5E1 value_track_color: #93C5FD thumb_color: #2563EB thumb_size: 22 }
            Label { text: "−20" x: 20 y: 96 width: 44 height: 18 color: #64748B font_size: 10 }
            Label { text: "100" x: horizontal_panel.width - 64 y: 96 width: 44 height: 18 align: right color: #64748B font_size: 10 }
        }

        Rectangle { id: vertical_panel x: 18 y: 210 width: card.width - 36 height: 260 background: #F8FAFC corner_radius: 9
            Label { text: "Vertical · −100 to −20" x: 18 y: 14 width: vertical_panel.width - 130 height: 22 color: #475569 font_size: 12 bold: true }
            TextField { id: vertical_input text: app.vertical_text on_change: "vertical_input" on_submit: "vertical_input" x: vertical_panel.width - 94 y: 10 width: 76 height: 34 background: app.vertical_valid ? #FFFFFF : #FEE2E2 corner_radius: 7 align: center keyboard: decimal }
            Slider { id: vertical_slider on_change: "vertical_slider" x: 64 y: 48 width: 24 height: 180 min: -100 max: -20 value: app.vertical_value step: 1 orientation: vertical padding: 11 value_track: true background: #CBD5E1 value_track_color: #86EFAC thumb_color: #16A34A thumb_size: 22 }
            Label { text: "−20" x: 100 y: 48 width: 54 height: 18 color: #64748B font_size: 10 }
            Label { text: "−100" x: 100 y: 210 width: 54 height: 18 color: #64748B font_size: 10 }
            Label { text: "Text fields and slider thumbs" x: 184 y: 82 width: vertical_panel.width - 214 height: 22 color: #64748B font_size: 12 bold: true }
            Label { text: "stay synchronized." x: 184 y: 108 width: vertical_panel.width - 214 height: 22 color: #64748B font_size: 12 }
            Label { text: "Invalid input does not move the thumb." x: 184 y: 148 width: vertical_panel.width - 214 height: 22 color: #64748B font_size: 11 }
        }

        Label { id: slider_status text: app.status x: 18 y: card.height - 40 width: card.width - 36 height: 18 align: center color: app.horizontal_valid && app.vertical_valid ? #166534 : #991B1B font_size: 11 }
    }
}
