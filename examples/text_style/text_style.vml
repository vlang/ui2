Screen {
    id: root
    background: #F1F5F9

    property f64 list_w: 240

    Rectangle {
        id: card
        x: 16
        y: 16
        width: root.width - 32
        height: root.height - 32
        background: #FFFFFF
        corner_radius: 10

        Label { text: "Text style" x: 18 y: 14 width: 260 height: 28 color: #111827 font_size: 18 bold: true }
        Label { text: "Every family below was found in this machine's font trees, the same ones ui2 resolves a declared family against." x: 18 y: 44 width: card.width - 36 height: 18 color: #64748B font_size: 11 }

        Scroll {
            id: font_list
            x: 18
            y: 74
            width: root.list_w
            height: card.height - 108
            background: #F8FAFC

            Repeater {
                model: app.fonts
                key: item.key

                Button {
                    text: item.family
                    on_tap: app.choose_font(item.id)
                    x: 8
                    y: 8 + index * 34
                    width: root.list_w - 32
                    height: 30
                    background: item.id == app.selected ? #2563EB : #FFFFFF
                    color: item.id == app.selected ? #FFFFFF : #1E293B
                    font_size: 12
                    corner_radius: 6
                }
            }
        }

        Dropdown {
            id: size_choice
            bind.text: app.size_choice
            on_change: app.size_changed()
            x: 34 + root.list_w
            y: 74
            width: 110
            height: 36
            background: #F1F5F9
            corner_radius: 7

            Option { text: "12" }
            Option { text: "18" }
            Option { text: "24" }
            Option { text: "30" }
            Option { text: "44" }
            Option { text: "64" }
        }
        Checkbox { id: bold text: "Bold" bind.checked: app.bold on_tap: app.emphasis_changed() x: 156 + root.list_w y: 80 width: 90 height: 26 color: #334155 font_size: 12 }
        Checkbox { id: italic text: "Italic" bind.checked: app.italic on_tap: app.emphasis_changed() x: 250 + root.list_w y: 80 width: 90 height: 26 color: #334155 font_size: 12 }

        TextField {
            id: sample_input
            bind.text: app.sample
            x: 34 + root.list_w
            y: 122
            width: card.width - root.list_w - 52
            height: 36
            background: #F8FAFC
            corner_radius: 7
        }

        Rectangle {
            id: preview
            x: 34 + root.list_w
            y: 172
            width: card.width - root.list_w - 52
            height: card.height - 260
            background: #FFFFFF
            corner_radius: 9

            Rectangle { x: 0 y: 0 width: card.width - root.list_w - 52 height: 2 background: #E2E8F0 }

            Label {
                id: preview_text
                text: app.sample
                x: 16
                y: 24
                width: card.width - root.list_w - 84
                height: app.font_size * 1.6
                color: #111827
                font_size: app.font_size
                font_family: app.family
                bold: app.bold
                italic: app.italic
            }

            Label { text: "The box above is the frame the label was given. A line wider than its frame is shortened, which is what the original demo drew a measured rectangle for." x: 16 y: app.font_size * 1.6 + 44 width: card.width - root.list_w - 84 height: 34 color: #94A3B8 font_size: 11 lines: 2 }

            Label { text: "Same text at a fixed 15 pt, for comparison:" x: 16 y: app.font_size * 1.6 + 92 width: card.width - root.list_w - 84 height: 18 color: #64748B font_size: 11 }
            Label { text: app.sample x: 16 y: app.font_size * 1.6 + 112 width: card.width - root.list_w - 84 height: 24 color: #334155 font_size: 15 font_family: app.family bold: app.bold italic: app.italic }
        }

        Label { id: text_style_status text: app.status x: 34 + root.list_w y: card.height - 42 width: card.width - root.list_w - 52 height: 20 color: #166534 font_size: 12 }
    }
}
