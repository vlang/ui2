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
            Rectangle { id: horizontal_track on_tap: "horizontal_track" clickable: true draggable: true cursor: "pointing_hand" x: 20 y: 66 width: horizontal_panel.width - 40 height: 24 background: #CBD5E1 corner_radius: 12
                Rectangle { x: 0 y: 0 width: app.horizontal_ratio * horizontal_track.width height: 24 background: #93C5FD corner_radius: 12 }
                Rectangle { x: app.horizontal_ratio * (horizontal_track.width - 22) y: 1 width: 22 height: 22 background: #2563EB corner_radius: 11 }
            }
            Label { text: "−20" x: 20 y: 96 width: 44 height: 18 color: #64748B font_size: 10 }
            Label { text: "100" x: horizontal_panel.width - 64 y: 96 width: 44 height: 18 align: right color: #64748B font_size: 10 }
        }

        Rectangle { id: vertical_panel x: 18 y: 210 width: card.width - 36 height: 260 background: #F8FAFC corner_radius: 9
            Label { text: "Vertical · −100 to −20" x: 18 y: 14 width: vertical_panel.width - 130 height: 22 color: #475569 font_size: 12 bold: true }
            TextField { id: vertical_input text: app.vertical_text on_change: "vertical_input" on_submit: "vertical_input" x: vertical_panel.width - 94 y: 10 width: 76 height: 34 background: app.vertical_valid ? #FFFFFF : #FEE2E2 corner_radius: 7 align: center keyboard: decimal }
            Rectangle { id: vertical_track on_tap: "vertical_track" clickable: true draggable: true cursor: "pointing_hand" x: 64 y: 48 width: 24 height: 180 background: #CBD5E1 corner_radius: 12
                Rectangle { x: 0 y: (1 - app.vertical_ratio) * vertical_track.height width: 24 height: app.vertical_ratio * vertical_track.height background: #86EFAC corner_radius: 12 }
                Rectangle { x: 1 y: (1 - app.vertical_ratio) * (vertical_track.height - 22) width: 22 height: 22 background: #16A34A corner_radius: 11 }
            }
            Label { text: "−20" x: 100 y: 48 width: 54 height: 18 color: #64748B font_size: 10 }
            Label { text: "−100" x: 100 y: 210 width: 54 height: 18 color: #64748B font_size: 10 }
            Label { text: "Text fields and slider thumbs" x: 184 y: 82 width: vertical_panel.width - 214 height: 22 color: #64748B font_size: 12 bold: true }
            Label { text: "stay synchronized." x: 184 y: 108 width: vertical_panel.width - 214 height: 22 color: #64748B font_size: 12 }
            Label { text: "Invalid input does not move the thumb." x: 184 y: 148 width: vertical_panel.width - 214 height: 22 color: #64748B font_size: 11 }
        }

        Label { id: slider_status text: app.status x: 18 y: card.height - 40 width: card.width - 36 height: 18 align: center color: app.horizontal_valid && app.vertical_valid ? #166534 : #991B1B font_size: 11 }
    }
}
