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

        Label { text: "Child window" x: 18 y: 14 width: 240 height: 28 color: #111827 font_size: 18 bold: true }
        Button { id: create text: "Create a window" on_tap: "create" native: true x: 18 y: 52 width: 170 height: 34 }
        TextField { id: parent_input placeholder: "Test textbox" text: app.parent_text on_change: "parent_input" x: 200 y: 52 width: card.width - 218 height: 34 background: #F8FAFC corner_radius: 7 }
        Label { text: "The panel below is the child window: it carries its own field, its own checkbox, and its own greeting." x: 18 y: 96 width: card.width - 36 height: 18 color: #64748B font_size: 11 }

        Rectangle {
            id: child_panel
            hidden: !app.open
            x: app.panel_x
            y: app.panel_y
            width: 320
            height: 232
            background: #E2E8F0
            corner_radius: 10

            Rectangle {
                id: child_titlebar
                on_tap: "child_titlebar"
                clickable: true
                draggable: true
                cursor: "pointing_hand"
                x: 0
                y: 0
                width: 320
                height: 38
                background: #334155
                corner_radius: 10

                Label { text: app.title x: 14 y: 10 width: 220 height: 18 color: #F8FAFC font_size: 13 bold: true }
            }
            Button { id: close text: "Close" on_tap: "close" native: true x: 236 y: 4 width: 74 height: 30 }

            TextField { id: child_name placeholder: "Name" text: app.name on_change: "child_name" x: 16 y: 56 width: 288 height: 34 background: #FFFFFF corner_radius: 7 }
            Checkbox { id: genre text: "Check me if woman" checked: app.woman on_tap: "genre" x: 16 y: 104 width: 288 height: 28 color: #334155 font_size: 12 }
            Button { id: greet text: "Greet me" on_tap: "greet" native: true x: 16 y: 144 width: 170 height: 34 }
            Label { text: "Drag the dark title bar." x: 16 y: 190 width: 288 height: 18 color: #64748B font_size: 11 }
        }

        Label { id: child_status text: app.status x: 18 y: card.height - 40 width: card.width - 36 height: 18 align: center color: #166534 font_size: 12 }
    }
}
