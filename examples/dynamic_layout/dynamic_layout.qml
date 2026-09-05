Screen {
    id: root
    background: #F1F5F9

    property f64 controls_width: 190

    Rectangle {
        id: controls
        x: 16
        y: 16
        width: root.controls_width
        height: root.height - 32
        background: #FFFFFF
        corner_radius: 10

        Label { text: "Controls" x: 16 y: 14 width: controls.width - 32 height: 28 color: #111827 font_size: 18 bold: true }

        Button { id: add_last text: "Add last" on_tap: app.add_last() native: true x: 16 y: 56 width: controls.width - 32 height: 34 }
        Button { id: add_two text: "Add two" on_tap: app.add_two() native: true x: 16 y: 98 width: controls.width - 32 height: 34 }
        Button { id: remove_last text: "Remove last" on_tap: app.remove_last() native: true enabled: app.items.len > 0 x: 16 y: 140 width: controls.width - 32 height: 34 }
        Button { id: remove_second text: "Remove second" on_tap: app.remove_second() native: true enabled: app.items.len > 1 x: 16 y: 182 width: controls.width - 32 height: 34 }
        Button { id: move_first text: "Move first to end" on_tap: app.move_first() native: true enabled: app.items.len > 1 x: 16 y: 224 width: controls.width - 32 height: 34 }
        Button { id: toggle_items text: app.items_hidden ? "Show buttons" : "Hide buttons" on_tap: app.toggle_items() native: true x: 16 y: 266 width: controls.width - 32 height: 34 }

        Label { text: app.status x: 16 y: controls.height - 42 width: controls.width - 32 height: 20 align: center color: #64748B font_size: 12 }
    }

    Rectangle {
        id: stage
        x: 222
        y: 16
        width: root.width - 238
        height: root.height - 32
        background: #FFFFFF
        corner_radius: 10

        Label { text: "Live layout" x: 16 y: 14 width: stage.width - 32 height: 28 color: #111827 font_size: 18 bold: true }
        Label { text: "Click a generated button to rename it." x: 16 y: 42 width: stage.width - 32 height: 20 color: #64748B font_size: 12 }

        Scroll {
            id: item_list
            hidden: app.items_hidden
            x: 16
            y: 76
            width: stage.width - 32
            height: stage.height - 92
            background: #F8FAFC

            Repeater {
                model: app.items
                key: item.id

                Button {
                    text: item.label
                    on_tap: app.rename(item.id)
                    native: true
                    x: 12
                    y: 10 + index * 44
                    width: stage.width - 72
                    height: 34
                }
            }
        }

        Label {
            id: hidden_message
            hidden: !app.items_hidden
            text: "Generated buttons are hidden"
            x: 16
            y: stage.height / 2 - 10
            width: stage.width - 32
            height: 20
            align: center
            color: #64748B
            font_size: 13
        }
    }
}
