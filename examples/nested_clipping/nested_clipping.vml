Screen {
    id: root
    background: #F1F5F9

    // Declared properties resolve against the window, so the box grid keeps the
    // same math the stage frame below uses.
    property f64 cell_w: (root.width - 88) / 4
    property f64 cell_h: (root.height - 226) / 4

    Rectangle {
        id: card
        x: 16
        y: 16
        width: root.width - 32
        height: root.height - 32
        background: #FFFFFF
        corner_radius: 10

        Label { text: "Nested clipping" x: 18 y: 14 width: 260 height: 28 color: #111827 font_size: 18 bold: true }
        Button { id: clip_all text: "Clip all" on_tap: app.clip_all() native: true x: card.width - 226 y: 13 width: 100 height: 34 }
        Button { id: clip_none text: "Clip none" on_tap: app.clip_none() native: true x: card.width - 118 y: 13 width: 100 height: 34 }
        Label { text: "Every box paints bars that reach past its own frame. A clipped box keeps them inside; an unclipped one spills over its neighbours until a later box paints on top." x: 18 y: 44 width: card.width - 36 height: 20 color: #64748B font_size: 12 }

        Button { id: quadrant1 text: "Quadrant 1" on_tap: app.toggle_quadrant(1) native: true x: 18 y: 72 width: 112 height: 30 }
        Button { id: quadrant2 text: "Quadrant 2" on_tap: app.toggle_quadrant(2) native: true x: 138 y: 72 width: 112 height: 30 }
        Button { id: quadrant3 text: "Quadrant 3" on_tap: app.toggle_quadrant(3) native: true x: 258 y: 72 width: 112 height: 30 }
        Button { id: quadrant4 text: "Quadrant 4" on_tap: app.toggle_quadrant(4) native: true x: 378 y: 72 width: 112 height: 30 }

        Rectangle {
            id: stage
            x: 18
            y: 114
            width: card.width - 36
            height: card.height - 174
            background: #0F172A
            corner_radius: 8

            Repeater {
                model: app.boxes
                key: item.key

                Rectangle {
                    x: 10 + item.column * root.cell_w
                    y: 10 + item.row * root.cell_h
                    width: root.cell_w - 10
                    height: root.cell_h - 10
                    background: #FFFFFF
                    corner_radius: 6

                    Scroll {
                        hidden: !item.clipping
                        x: 0
                        y: 0
                        width: root.cell_w - 10
                        height: root.cell_h - 10
                        background: #FFFFFF

                        Rectangle { x: -70 y: 40 width: root.cell_w + 130 height: 16 background: item.color }
                        Rectangle { x: root.cell_w - 48 y: -36 width: 16 height: root.cell_h - 48 background: item.color }
                    }

                    Rectangle { hidden: item.clipping x: -70 y: 40 width: root.cell_w + 130 height: 16 background: item.color }
                    Rectangle { hidden: item.clipping x: root.cell_w - 48 y: -36 width: 16 height: root.cell_h - 48 background: item.color }

                    Label { text: "drawn ${item.order}" x: 8 y: 4 width: root.cell_w - 26 height: 16 color: #0F172A font_size: 10 }
                    Label { text: item.clipping ? "clip: yes" : "clip: no" x: 8 y: 20 width: root.cell_w - 26 height: 16 color: #475569 font_size: 10 }
                    Button { text: item.clipping ? "Unclip" : "Clip" on_tap: app.toggle_box(item.id) native: true x: 8 y: root.cell_h - 44 width: 86 height: 28 }
                }
            }
        }

        Label { id: clip_status text: app.status x: 18 y: card.height - 42 width: card.width - 36 height: 20 align: center color: #166534 font_size: 12 }
    }
}
