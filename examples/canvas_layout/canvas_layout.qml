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

        Label { text: "Canvas layout" x: 18 y: 18 width: 160 height: 26 color: #111827 font_size: 18 bold: true }
        Dropdown {
            id: theme_dropdown
            text: app.theme
            on_change: "theme_dropdown"
            x: 186
            y: 13
            width: 150
            height: 34
            background: #F1F5F9
            corner_radius: 7

            Option { text: "Classic" }
            Option { text: "Blue" }
            Option { text: "Red" }
            Option { text: "Green" }
            Option { text: "Slate" }
        }
        Button { id: about text: "About" on_tap: "about" native: true x: 346 y: 13 width: 96 height: 34 }
        Button { id: clear_notes text: "X" on_tap: "clear_notes" native: true x: 452 y: 13 width: 44 height: 34 }
        Button { id: add_note text: "Add" on_tap: "add_note" native: true x: 506 y: 13 width: 80 height: 34 }
        Button { id: reset_tile text: "Reset tile" on_tap: "reset_tile" native: true x: 596 y: 13 width: 110 height: 34 }
        Button { id: toggle_menu text: app.menu_label on_tap: "toggle_menu" native: true x: 716 y: 13 width: 120 height: 34 }

        Label { text: "The sheet is taller than its viewport: scroll it, drag the tile across it, and drag the sheet itself to read canvas coordinates." x: 18 y: 56 width: card.width - 36 height: 18 color: #64748B font_size: 11 }

        Scroll {
            id: canvas
            x: 18
            y: 84
            width: card.width - 36
            height: card.height - 140
            background: #E2E8F0

            Rectangle {
                id: sheet
                on_tap: "canvas_sheet"
                clickable: true
                draggable: true
                x: 0
                y: 0
                width: canvas.width
                height: 760
                background: #FFFFFF

                Label { text: "Sheet · 760 px tall" x: 20 y: 12 width: 240 height: 18 color: #94A3B8 font_size: 11 }

                TextArea {
                    id: canvas_text
                    text: app.text
                    x: sheet.width - 320
                    y: 40
                    width: 300
                    height: 150
                    background: #FEF9C3
                    color: #111827
                    font_size: 12
                    corner_radius: 8
                }

                Rectangle {
                    id: canvas_menu
                    hidden: app.menu_hidden
                    x: 240
                    y: 120
                    width: 220
                    height: 148
                    background: #0F172A
                    corner_radius: 8

                    Label { text: "Menu" x: 14 y: 10 width: 190 height: 18 color: #E2E8F0 font_size: 12 bold: true }
                    Button { id: menu_delete text: "Delete all users" on_tap: "menu_delete" native: true x: 12 y: 34 width: 196 height: 32 }
                    Button { id: menu_export text: "Export users" on_tap: "menu_export" native: true x: 12 y: 72 width: 196 height: 32 }
                    Button { id: menu_exit text: "Exit" on_tap: "menu_exit" native: true x: 12 y: 110 width: 196 height: 32 }
                }

                Repeater {
                    model: app.notes
                    key: item.key

                    Rectangle {
                        x: item.x
                        y: item.y
                        width: 132
                        height: 74
                        background: #F1F5F9
                        corner_radius: 8

                        Label { text: item.label x: 12 y: 10 width: 108 height: 18 color: #0F172A font_size: 12 bold: true }
                        Label { text: "keyed child" x: 12 y: 32 width: 108 height: 18 color: #64748B font_size: 11 }
                    }
                }

                Rectangle {
                    id: canvas_tile
                    on_tap: "canvas_tile"
                    clickable: true
                    draggable: true
                    cursor: "pointing_hand"
                    x: app.tile_x
                    y: app.tile_y
                    width: 150
                    height: 70
                    background: app.tile_color
                    corner_radius: 10

                    Label { text: app.theme x: 0 y: 14 width: 150 height: 22 align: center color: app.tile_text font_size: 15 bold: true }
                    Label { text: "drag me" x: 0 y: 38 width: 150 height: 18 align: center color: app.tile_text font_size: 11 }
                }

                Label { text: "Bottom of the sheet" x: 20 y: 716 width: 260 height: 18 color: #94A3B8 font_size: 11 }
            }
        }

        Rectangle { x: 18 y: card.height - 46 width: 120 height: 28 background: #F1F5F9 corner_radius: 7
            Label { id: pointer_readout text: app.pointer_text x: 0 y: 5 width: 120 height: 18 align: center color: #334155 font_size: 12 }
        }
        Label { id: canvas_status text: app.status x: 150 y: card.height - 41 width: card.width - 168 height: 18 color: #166534 font_size: 12 }
    }
}
