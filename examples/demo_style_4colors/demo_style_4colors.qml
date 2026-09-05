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

        Label { text: "Four-color style" x: 18 y: 14 width: card.width - 36 height: 28 color: #111827 font_size: 18 bold: true }
        Label { text: "Choose a coordinated base, surface, accent, and text palette." x: 18 y: 42 width: card.width - 36 height: 20 color: #64748B font_size: 12 }

        Dropdown {
            id: palette
            bind.text: app.palette
            on_change: app.palette_changed()
            x: 18
            y: 72
            width: 180
            height: 38
            background: #F1F5F9
            color: #1E293B
            corner_radius: 7

            Option { text: "Classic" }
            Option { text: "Ocean" }
            Option { text: "Sunset" }
            Option { text: "Forest" }
        }

        Rectangle {
            id: swatch0
            x: 214
            y: 72
            width: (card.width - 250) / 4
            height: 38
            background: #CBD5E1
            corner_radius: 6
            Rectangle { id: color0 x: 1 y: 1 width: swatch0.width - 2 height: swatch0.height - 2 background: app.color0 corner_radius: 5 }
        }
        Rectangle {
            id: swatch1
            x: 222 + (card.width - 250) / 4
            y: 72
            width: (card.width - 250) / 4
            height: 38
            background: #CBD5E1
            corner_radius: 6
            Rectangle { id: color1 x: 1 y: 1 width: swatch1.width - 2 height: swatch1.height - 2 background: app.color1 corner_radius: 5 }
        }
        Rectangle {
            id: swatch2
            x: 230 + (card.width - 250) / 2
            y: 72
            width: (card.width - 250) / 4
            height: 38
            background: #CBD5E1
            corner_radius: 6
            Rectangle { id: color2 x: 1 y: 1 width: swatch2.width - 2 height: swatch2.height - 2 background: app.color2 corner_radius: 5 }
        }
        Rectangle {
            id: swatch3
            x: 238 + (card.width - 250) * 0.75
            y: 72
            width: (card.width - 250) / 4
            height: 38
            background: #CBD5E1
            corner_radius: 6
            Rectangle { id: color3 x: 1 y: 1 width: swatch3.width - 2 height: swatch3.height - 2 background: app.color3 corner_radius: 5 }
        }

        Rectangle {
            id: preview
            x: 18
            y: 132
            width: card.width - 36
            height: card.height - 202
            background: app.color0
            corner_radius: 9

            Rectangle {
                x: 18
                y: 18
                width: preview.width - 36
                height: preview.height - 36
                background: app.color1
                corner_radius: 8

                Label { text: "Styled preview" x: 16 y: 14 width: preview.width - 68 height: 26 color: app.color3 font_size: 17 bold: true }
                Label { text: "The four selected colors update this sample surface." x: 16 y: 42 width: preview.width - 68 height: 20 color: app.color3 font_size: 12 }

                Checkbox { id: sample_enabled text: "Example setting" bind.checked: app.enabled x: 16 y: 76 width: 180 height: 30 color: app.color3 font_size: 13 }

                Button {
                    id: apply_palette
                    text: "Apply palette"
                    on_tap: app.apply_palette()
                    native: true
                    x: preview.width - 180
                    y: preview.height - 86
                    width: 130
                    height: 36
                    background: app.color2
                    color: app.color3
                }
            }
        }

        Label { id: palette_status text: app.status x: 18 y: card.height - 42 width: card.width - 36 height: 20 align: center color: #166534 font_size: 12 }
    }
}
