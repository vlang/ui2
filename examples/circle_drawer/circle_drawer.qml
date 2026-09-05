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

        Label { text: "Circle drawer" x: 18 y: 14 width: 180 height: 28 color: #111827 font_size: 18 bold: true }
        Button { id: undo text: "Undo" on_tap: "undo" enabled: app.can_undo native: true x: card.width - 346 y: 13 width: 82 height: 34 }
        Button { id: redo text: "Redo" on_tap: "redo" enabled: app.can_redo native: true x: card.width - 256 y: 13 width: 82 height: 34 }
        Button { id: radius_less text: "Radius −" on_tap: "radius_less" enabled: app.selected_id >= 0 native: true x: card.width - 166 y: 13 width: 82 height: 34 }
        Button { id: radius_more text: "+" on_tap: "radius_more" enabled: app.selected_id >= 0 native: true x: card.width - 76 y: 13 width: 58 height: 34 }

        Rectangle {
            id: circle_canvas
            on_tap: "circle_canvas"
            clickable: true
            cursor: "pointing_hand"
            x: 18
            y: 76
            width: card.width - 36
            height: card.height - 132
            background: #F8FAFC
            corner_radius: 9

            Label { hidden: app.circles.len > 0 text: "Click anywhere to add the first circle" x: 20 y: (circle_canvas.height - 24) / 2 width: circle_canvas.width - 40 height: 24 align: center color: #94A3B8 font_size: 13 }

            Repeater { model: app.circles key: item.id
                Rectangle { x: item.x - item.radius - 3 y: item.y - item.radius - 3 width: item.radius * 2 + 6 height: item.radius * 2 + 6 background: item.id == app.selected_id ? #2563EB : #FFFFFF corner_radius: item.radius + 3
                    Rectangle { x: 3 y: 3 width: item.radius * 2 height: item.radius * 2 background: item.color corner_radius: item.radius
                        Label { text: "${item.id}" x: 0 y: 0 width: item.radius * 2 height: item.radius * 2 align: center color: #1E293B font_size: 11 bold: true }
                    }
                }
            }
        }

        Label { id: circle_status text: app.status x: 18 y: card.height - 40 width: card.width - 130 height: 18 color: #166534 font_size: 11 }
        Label { text: app.radius_label x: card.width - 116 y: card.height - 40 width: 98 height: 18 align: right color: #64748B font_size: 11 }
    }
}
