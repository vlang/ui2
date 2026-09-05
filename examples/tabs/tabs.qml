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

        Label { text: "Tabs" x: 18 y: 14 width: card.width - 36 height: 28 color: #111827 font_size: 18 bold: true }
        Label { text: "Switch between three component pages." x: 18 y: 42 width: card.width - 36 height: 20 color: #64748B font_size: 12 }

        Rectangle {
            id: tab_bar
            x: 18
            y: 74
            width: card.width - 36
            height: 44
            background: #F8FAFC
            corner_radius: 8

            Repeater {
                model: app.pages
                key: item.id

                Button {
                    text: item.id == app.active_tab ? "• ${item.title}" : item.title
                    on_tap: app.select_tab(item.id)
                    native: true
                    x: 8 + index * ((tab_bar.width - 16) / 3)
                    y: 5
                    width: (tab_bar.width - 16) / 3 - 8
                    height: 34
                }
            }
        }

        Rectangle {
            id: tab_stage
            x: 18
            y: 130
            width: card.width - 36
            height: card.height - 184
            background: #F8FAFC
            corner_radius: 9

            Repeater {
                model: app.pages
                key: item.id

                Rectangle {
                    hidden: item.id != app.active_tab
                    x: 8
                    y: 8
                    width: tab_stage.width - 16
                    height: tab_stage.height - 16
                    background: item.background
                    corner_radius: 8

                    Label { text: item.heading x: 20 y: 24 width: tab_stage.width - 56 height: 30 color: #111827 font_size: 20 bold: true }
                    Label { text: item.body x: 20 y: 66 width: tab_stage.width - 56 height: 46 color: #334155 font_size: 13 lines: 2 }
                    Label { text: "Page ${item.id} of ${app.pages.len}" x: 20 y: tab_stage.height - 54 width: tab_stage.width - 56 height: 20 align: right color: #64748B font_size: 11 }
                }
            }
        }

        Label { id: tab_status text: app.status x: 18 y: card.height - 40 width: card.width - 36 height: 18 align: center color: #166534 font_size: 12 }
    }
}
