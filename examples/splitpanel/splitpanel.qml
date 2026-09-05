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

        Label { text: "Split panel" x: 18 y: 14 width: 150 height: 28 color: #111827 font_size: 18 bold: true }
        Label { id: split_status text: app.status x: 176 y: 18 width: card.width - 470 height: 20 align: center color: #64748B font_size: 11 }
        Button { text: "Top −" on_tap: app.top_less() native: true x: card.width - 282 y: 12 width: 60 height: 32 }
        Button { text: "Top +" on_tap: app.top_more() native: true x: card.width - 216 y: 12 width: 60 height: 32 }
        Button { text: "Left −" on_tap: app.left_less() native: true x: card.width - 150 y: 12 width: 60 height: 32 }
        Button { text: "Left +" on_tap: app.left_more() native: true x: card.width - 84 y: 12 width: 66 height: 32 }
        Button { id: reset_splits text: "Reset" on_tap: app.reset_splits() native: true x: 18 y: 52 width: 92 height: 32 }

        Rectangle {
            id: stage
            x: 18
            y: 94
            width: card.width - 36
            height: card.height - 112
            background: #CBD5E1
            corner_radius: 8

            Rectangle {
                id: top_panel
                x: 1
                y: 1
                width: stage.width - 2
                height: (stage.height - 10) * app.top_weight
                background: #DCFCE7
                corner_radius: 7
                Label { text: "Top pane" x: 14 y: 12 width: top_panel.width - 28 height: 22 color: #166534 font_size: 15 bold: true }
                Label { text: "A responsive panel spanning the full width." x: 14 y: 38 width: top_panel.width - 28 height: 20 color: #15803D font_size: 11 }
            }

            Rectangle {
                id: lower_panel
                x: 1
                y: (stage.height - 10) * app.top_weight + 9
                width: stage.width - 2
                height: stage.height - (stage.height - 10) * app.top_weight - 10
                background: #CBD5E1

                TextArea {
                    id: split_notes
                    bind.text: app.notes
                    x: 0
                    y: 0
                    width: (lower_panel.width - 8) * app.left_weight
                    height: lower_panel.height
                    background: #FEF3C7
                    color: #713F12
                    font_size: 12
                    corner_radius: 7
                }

                Scroll {
                    id: split_grid
                    x: (lower_panel.width - 8) * app.left_weight + 8
                    y: 0
                    width: lower_panel.width - (lower_panel.width - 8) * app.left_weight - 8
                    height: lower_panel.height
                    background: #F8FAFC

                    Rectangle { x: 0 y: 0 width: split_grid.width - 16 height: 32 background: #334155
                        Label { text: "Name" x: 10 y: 6 width: (split_grid.width - 36) * 0.34 height: 20 color: #FFFFFF font_size: 11 bold: true }
                        Label { text: "Role" x: (split_grid.width - 36) * 0.34 y: 6 width: (split_grid.width - 36) * 0.38 height: 20 color: #FFFFFF font_size: 11 bold: true }
                        Label { text: "Team" x: (split_grid.width - 36) * 0.72 y: 6 width: (split_grid.width - 36) * 0.28 height: 20 color: #FFFFFF font_size: 11 bold: true }
                    }

                    Repeater {
                        model: app.rows
                        key: item.id
                        Rectangle { x: 0 y: 34 + index * 34 width: split_grid.width - 16 height: 32 background: index == 1 || index == 3 ? #F1F5F9 : #FFFFFF
                            Label { text: item.name x: 10 y: 6 width: (split_grid.width - 36) * 0.34 height: 20 color: #1E293B font_size: 11 }
                            Label { text: item.role x: (split_grid.width - 36) * 0.34 y: 6 width: (split_grid.width - 36) * 0.38 height: 20 color: #1E293B font_size: 11 }
                            Label { text: item.team x: (split_grid.width - 36) * 0.72 y: 6 width: (split_grid.width - 36) * 0.28 height: 20 color: #1E293B font_size: 11 }
                        }
                    }
                }
            }
        }
    }
}
