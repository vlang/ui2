Screen {
    id: root
    background: #F1F5F9

    // The tracks all start after the same label gutter, so their width is one
    // expression shared by the three rows and by the pointer conversion in V.
    property f64 track_w: root.width - 232

    Rectangle {
        id: card
        x: 16
        y: 16
        width: root.width - 32
        height: root.height - 32
        background: #FFFFFF
        corner_radius: 10

        Label { text: "Accent color" x: 18 y: 14 width: 260 height: 28 color: #111827 font_size: 18 bold: true }
        Button { id: reset text: "Reset" on_tap: "reset" native: true x: card.width - 118 y: 13 width: 100 height: 34 }
        Label { text: "Drag the three channels. Every other color on this card is derived from the accent they make." x: 18 y: 44 width: card.width - 148 height: 18 color: #64748B font_size: 11 }

        Label { text: "R ${app.red}" x: 18 y: 78 width: 54 height: 20 color: #B91C1C font_size: 12 bold: true }
        Rectangle { id: track_red on_tap: "track_red" clickable: true draggable: true cursor: "pointing_hand" x: 76 y: 76 width: root.track_w height: 24 background: #E2E8F0 corner_radius: 12
            Rectangle { x: 0 y: 0 width: app.red_ratio * root.track_w height: 24 background: #FCA5A5 corner_radius: 12 }
            Rectangle { x: app.red_ratio * (root.track_w - 22) y: 1 width: 22 height: 22 background: #DC2626 corner_radius: 11 }
        }

        Label { text: "G ${app.green}" x: 18 y: 114 width: 54 height: 20 color: #15803D font_size: 12 bold: true }
        Rectangle { id: track_green on_tap: "track_green" clickable: true draggable: true cursor: "pointing_hand" x: 76 y: 112 width: root.track_w height: 24 background: #E2E8F0 corner_radius: 12
            Rectangle { x: 0 y: 0 width: app.green_ratio * root.track_w height: 24 background: #86EFAC corner_radius: 12 }
            Rectangle { x: app.green_ratio * (root.track_w - 22) y: 1 width: 22 height: 22 background: #16A34A corner_radius: 11 }
        }

        Label { text: "B ${app.blue}" x: 18 y: 150 width: 54 height: 20 color: #1D4ED8 font_size: 12 bold: true }
        Rectangle { id: track_blue on_tap: "track_blue" clickable: true draggable: true cursor: "pointing_hand" x: 76 y: 148 width: root.track_w height: 24 background: #E2E8F0 corner_radius: 12
            Rectangle { x: 0 y: 0 width: app.blue_ratio * root.track_w height: 24 background: #93C5FD corner_radius: 12 }
            Rectangle { x: app.blue_ratio * (root.track_w - 22) y: 1 width: 22 height: 22 background: #2563EB corner_radius: 11 }
        }

        Rectangle { id: accent_preview x: card.width - 122 y: 76 width: 104 height: 96 background: app.accent corner_radius: 9
            Label { text: app.accent x: 0 y: 38 width: 104 height: 20 align: center color: app.font_color font_size: 12 bold: true }
        }

        Repeater {
            model: app.swatches
            key: item.key

            Rectangle {
                x: 18 + item.index * ((card.width - 36) / 4)
                y: 192
                width: (card.width - 36) / 4 - 8
                height: 62
                background: item.color
                corner_radius: 8

                Label { text: item.label x: 0 y: 21 width: (card.width - 36) / 4 - 8 height: 20 align: center color: item.role == "font" ? #111111 : app.font_color font_size: 12 bold: true }
            }
        }

        Rectangle {
            id: demo_stack
            x: 18
            y: 272
            width: card.width - 36
            height: card.height - 330
            background: app.tint
            corner_radius: 10

            Rectangle { x: 0 y: 0 width: card.width - 36 height: 44 background: app.shade corner_radius: 10
                Label { text: "Controls painted with the derived scheme" x: 16 y: 12 width: card.width - 68 height: 20 color: app.font_color font_size: 13 bold: true }
            }

            Button { id: accent_action text: "Primary action" x: 16 y: 64 width: 170 height: 38 background: app.accent color: app.font_color font_size: 13 corner_radius: 8 }
            Checkbox { id: subscribe text: "Subscribe" checked: app.subscribed on_tap: "subscribe" x: 202 y: 70 width: 150 height: 26 color: app.shade font_size: 12 }
            TextField { id: sample_input text: app.sample on_change: "sample_input" x: 16 y: 116 width: 336 height: 36 background: #FFFFFF color: app.shade corner_radius: 8 }
            Label { text: "Body text sits on the tint and reads in the shade." x: 16 y: 164 width: card.width - 68 height: 20 color: app.shade font_size: 12 }
            Label { text: app.on_dark ? "The accent is dark, so the font color is white." : "The accent is light, so the font color is black." x: 16 y: 188 width: card.width - 68 height: 20 color: app.shade font_size: 11 }
        }

        Label { id: accent_status text: app.status x: 18 y: card.height - 42 width: card.width - 36 height: 20 align: center color: #166534 font_size: 12 }
    }
}
