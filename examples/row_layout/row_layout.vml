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

        Label { text: "Row layout" x: 18 y: 14 width: card.width - 36 height: 28 color: #111827 font_size: 18 bold: true }
        Label { text: "Change proportional widths, margin, spacing, and height." x: 18 y: 42 width: card.width - 36 height: 20 color: #64748B font_size: 12 }

        Label { text: "Widths" x: 18 y: 72 width: 116 height: 18 color: #475569 font_size: 11 }
        Label { text: "Margin" x: 146 y: 72 width: 100 height: 18 color: #475569 font_size: 11 }
        Label { text: "Spacing" x: 258 y: 72 width: 100 height: 18 color: #475569 font_size: 11 }
        Label { text: "Height" x: 370 y: 72 width: 100 height: 18 color: #475569 font_size: 11 }

        Dropdown { id: widths bind.text: app.width_choice on_change: app.layout_changed() x: 18 y: 92 width: 116 height: 38 background: #F1F5F9 corner_radius: 7
            Option { text: "30 / 70" }
            Option { text: "50 / 50" }
            Option { text: "70 / 30" }
        }
        Dropdown { id: margin bind.text: app.margin_choice on_change: app.layout_changed() x: 146 y: 92 width: 100 height: 38 background: #F1F5F9 corner_radius: 7
            Option { text: "12" }
            Option { text: "24" }
            Option { text: "40" }
        }
        Dropdown { id: spacing bind.text: app.spacing_choice on_change: app.layout_changed() x: 258 y: 92 width: 100 height: 38 background: #F1F5F9 corner_radius: 7
            Option { text: "8" }
            Option { text: "20" }
            Option { text: "36" }
        }
        Dropdown { id: height bind.text: app.height_choice on_change: app.layout_changed() x: 370 y: 92 width: 100 height: 38 background: #F1F5F9 corner_radius: 7
            Option { text: "32" }
            Option { text: "44" }
            Option { text: "60" }
        }
        Button { id: reset_layout text: "Reset" on_tap: app.reset_layout() native: true x: card.width - 118 y: 94 width: 100 height: 34 }

        Rectangle {
            id: row_stage
            x: 18
            y: 150
            width: card.width - 36
            height: card.height - 206
            background: #ECFCCB
            corner_radius: 8

            Button { id: first_button text: "Button 1" native: true x: app.row_margin y: (row_stage.height - app.button_height) / 2 width: (card.width - 36 - app.row_margin * 2 - app.row_spacing) * app.first_ratio height: app.button_height }
            Button { id: second_button text: "Button 2" native: true x: app.row_margin + (card.width - 36 - app.row_margin * 2 - app.row_spacing) * app.first_ratio + app.row_spacing y: (row_stage.height - app.button_height) / 2 width: (card.width - 36 - app.row_margin * 2 - app.row_spacing) * (1 - app.first_ratio) height: app.button_height }
        }

        Label { id: row_status text: app.status x: 18 y: card.height - 40 width: card.width - 36 height: 18 align: center color: #166534 font_size: 11 }
    }
}
