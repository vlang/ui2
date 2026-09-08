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

        Label { text: "Double listbox" x: 18 y: 14 width: card.width - 36 height: 28 color: #111827 font_size: 18 bold: true }
        Label { text: "Move values between the two collections." x: 18 y: 42 width: card.width - 36 height: 20 color: #64748B font_size: 12 }

        property f64 list_width: (card.width - 82) / 2

        Rectangle {
            id: available_panel
            x: 18
            y: 78
            width: card.list_width
            height: card.height - 154
            background: #F8FAFC
            corner_radius: 8

            Label { text: "Available (${app.available.len})" x: 14 y: 12 width: available_panel.width - 28 height: 22 color: #334155 font_size: 13 bold: true }
            Scroll {
                id: available_list
                x: 10
                y: 42
                width: available_panel.width - 20
                height: available_panel.height - 52
                background: #FFFFFF

                Repeater {
                    model: app.available
                    key: item.id

                    Button {
                        text: "${item.label}  →"
                        on_tap: app.move_right(item.id)
                        native: true
                        x: 8
                        y: 6 + index * 40
                        width: available_list.width - 32
                        height: 34
                    }
                }
            }
        }

        Rectangle {
            id: selected_panel
            x: 46 + card.list_width
            y: 78
            width: card.list_width
            height: card.height - 154
            background: #F8FAFC
            corner_radius: 8

            Label { text: "Selected (${app.selected.len})" x: 14 y: 12 width: selected_panel.width - 28 height: 22 color: #334155 font_size: 13 bold: true }
            Scroll {
                id: selected_list
                x: 10
                y: 42
                width: selected_panel.width - 20
                height: selected_panel.height - 52
                background: #FFFFFF

                Repeater {
                    model: app.selected
                    key: item.id

                    Button {
                        text: "←  ${item.label}"
                        on_tap: app.move_left(item.id)
                        native: true
                        x: 8
                        y: 6 + index * 40
                        width: selected_list.width - 32
                        height: 34
                    }
                }
            }
        }

        Button { id: reset_lists text: "Reset" on_tap: app.reset() native: true x: 18 y: card.height - 62 width: 100 height: 34 }
        Button { id: show_values text: "Get values" on_tap: app.show_values() native: true x: card.width - 138 y: card.height - 62 width: 120 height: 34 }
        Label { id: transfer_status text: app.status x: 132 y: card.height - 55 width: card.width - 284 height: 20 align: center color: #166534 font_size: 12 }
    }
}
