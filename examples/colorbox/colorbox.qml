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

        Label { text: "Color box" x: 18 y: 14 width: 220 height: 28 color: #111827 font_size: 18 bold: true }
        Button { id: store text: "Store in slot" on_tap: "store" native: true x: card.width - 148 y: 13 width: 130 height: 34 }

        Rectangle {
            id: hue_strip
            on_tap: "hue_strip"
            clickable: true
            draggable: true
            cursor: "pointing_hand"
            x: 18
            y: 60
            width: 32
            height: 256
            background: #FFFFFF

            Repeater {
                model: app.hue_cells
                key: item.key

                Rectangle { x: 0 y: item.index * 8 width: 32 height: 8 background: item.color }
            }

            Rectangle { x: 0 y: app.hue_marker - 2 width: 32 height: 4 background: #FFFFFF }
        }

        Rectangle {
            id: sv_square
            on_tap: "sv_square"
            clickable: true
            draggable: true
            cursor: "pointing_hand"
            x: 62
            y: 60
            width: 256
            height: 256
            background: app.hue_color

            Repeater {
                model: app.sv_cells
                key: item.key

                Rectangle { x: item.column * 16 y: item.row * 16 width: 16 height: 16 background: item.color }
            }

            Rectangle { x: app.sv_marker_x - 7 y: app.sv_marker_y - 7 width: 14 height: 14 background: #FFFFFF corner_radius: 7
                Rectangle { x: 3 y: 3 width: 8 height: 8 background: app.color corner_radius: 4 }
            }
        }

        Rectangle {
            id: swatch_grid
            on_tap: "swatch_grid"
            clickable: true
            cursor: "pointing_hand"
            x: 332
            y: 60
            width: 154
            height: 123
            background: #FFFFFF

            Repeater {
                model: app.swatches
                key: item.key

                Rectangle {
                    x: item.column * 80
                    y: item.row * 43
                    width: 74
                    height: 37
                    background: item.selected ? #0F172A : #E2E8F0
                    corner_radius: 7

                    Rectangle { x: 3 y: 3 width: 68 height: 31 background: item.color corner_radius: 5 }
                }
            }
        }

        Label { text: "Click a slot to recall it." x: 332 y: 192 width: 200 height: 18 color: #64748B font_size: 11 }

        Label { text: "R" x: 500 y: 64 width: 20 height: 20 color: #334155 font_size: 13 bold: true }
        TextField { id: red_input text: app.red_text on_change: "red_input" on_submit: "red_input" x: 524 y: 58 width: 84 height: 32 background: app.valid ? #FFFFFF : #FEE2E2 corner_radius: 7 align: center keyboard: decimal }
        Label { text: "G" x: 500 y: 104 width: 20 height: 20 color: #334155 font_size: 13 bold: true }
        TextField { id: green_input text: app.green_text on_change: "green_input" on_submit: "green_input" x: 524 y: 98 width: 84 height: 32 background: app.valid ? #FFFFFF : #FEE2E2 corner_radius: 7 align: center keyboard: decimal }
        Label { text: "B" x: 500 y: 144 width: 20 height: 20 color: #334155 font_size: 13 bold: true }
        TextField { id: blue_input text: app.blue_text on_change: "blue_input" on_submit: "blue_input" x: 524 y: 138 width: 84 height: 32 background: app.valid ? #FFFFFF : #FEE2E2 corner_radius: 7 align: center keyboard: decimal }

        Rectangle { id: current_color x: 500 y: 186 width: card.width - 518 height: 130 background: app.color corner_radius: 8
            Label { text: app.color x: 0 y: 104 width: card.width - 518 height: 18 align: center color: #FFFFFF font_size: 11 }
        }

        Rectangle { id: preview x: 18 y: 332 width: card.width - 36 height: 96 background: #F8FAFC corner_radius: 9
            Label { text: "Here a simple ui rectangle" x: 20 y: 28 width: card.width - 76 height: 44 color: app.color font_size: 30 }
        }

        Label { text: "The picked color drives the rectangle's text, exactly as the original colorbox connects its component to a rectangle style." x: 18 y: 440 width: card.width - 36 height: 18 color: #64748B font_size: 11 }
        Label { id: colorbox_status text: app.status x: 18 y: card.height - 40 width: card.width - 36 height: 18 align: center color: app.valid ? #166534 : #991B1B font_size: 12 }
    }
}
