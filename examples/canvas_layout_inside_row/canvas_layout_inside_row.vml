Screen {
    id: root
    background: #F1F5F9

    property f64 canvas_w: root.width - 300

    Rectangle {
        id: card
        x: 16
        y: 16
        width: root.width - 32
        height: root.height - 32
        background: #FFFFFF
        corner_radius: 10

        Label { text: "Canvas layout inside a row" x: 18 y: 14 width: 320 height: 28 color: #111827 font_size: 18 bold: true }
        Button { id: rotate text: "Rotate" on_tap: "rotate" native: true x: card.width - 246 y: 13 width: 96 height: 34 }
        Button { id: return text: "Return to tray" on_tap: "return" native: true x: card.width - 142 y: 13 width: 124 height: 34 }
        Label { text: "The row gives each pane its own origin. Drag the logo across the divider and watch the same position read differently in each." x: 18 y: 44 width: card.width - 266 height: 18 color: #64748B font_size: 11 }

        Rectangle {
            id: tray
            x: 18
            y: 96
            width: 220
            height: card.height - 156
            background: #E2E8F0
            corner_radius: 9

            Label { text: "Tray pane" x: 14 y: 12 width: 192 height: 18 color: #334155 font_size: 12 bold: true }
            Label { text: "origin (0, 0)" x: 14 y: 32 width: 192 height: 16 color: #64748B font_size: 10 }
            Rectangle { x: 14 y: tray.height - 54 width: 192 height: 40 background: #F8FAFC corner_radius: 7
                Label { text: "tray ${app.tray_text}" x: 0 y: 11 width: 192 height: 18 align: center color: app.over_canvas ? #94A3B8 : #1D4ED8 font_size: 12 bold: true }
            }
        }

        Rectangle {
            id: canvas
            x: 250
            y: 96
            width: root.canvas_w
            height: card.height - 156
            background: #F8FAFC
            corner_radius: 9

            Label { text: "Canvas pane" x: 16 y: 12 width: 260 height: 18 color: #334155 font_size: 12 bold: true }
            Label { text: "origin (0, 0), a different one" x: 16 y: 32 width: 260 height: 16 color: #64748B font_size: 10 }

            Rectangle { x: 16 y: 60 width: 1 height: canvas.height - 130 background: #CBD5E1 }
            Rectangle { x: 16 y: 60 width: root.canvas_w - 32 height: 1 background: #CBD5E1 }

            Rectangle { x: 16 y: canvas.height - 54 width: 220 height: 40 background: #FFFFFF corner_radius: 7
                Label { text: "canvas ${app.canvas_text}" x: 0 y: 11 width: 220 height: 18 align: center color: app.over_canvas ? #15803D : #94A3B8 font_size: 12 bold: true }
            }
        }

        Image {
            id: logo
            source: app.logo_path
            on_tap: "logo"
            clickable: true
            draggable: true
            cursor: "pointing_hand"
            tooltip: "Drag me across the divider"
            rotation: app.rotation
            x: app.logo_x
            y: app.logo_y
            width: 72
            height: 72
        }

        Label { id: inside_row_status text: app.status x: 18 y: card.height - 42 width: card.width - 36 height: 20 align: center color: #166534 font_size: 12 }
    }
}
