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

        Label { text: "Resizable menu window" x: 18 y: 14 width: card.width - 36 height: 28 color: #111827 font_size: 18 bold: true }
        Label { text: "Toggle fixed menu width and invoke native context-menu actions." x: 18 y: 42 width: card.width - 36 height: 20 color: #64748B font_size: 12 }

        Checkbox { id: compact text: "Compact menu width" bind.checked: app.compact x: 18 y: 76 width: card.width - 36 height: 30 color: #334155 font_size: 13 }

        Rectangle {
            id: menu_stage
            x: 18
            y: 120
            width: card.width - 36
            height: 112
            background: #FEE2E2
            corner_radius: 8

            Button {
                id: actions
                text: "Actions"
                on_tap: app.open_actions()
                native: true
                x: 14
                y: 16
                width: app.compact ? 190 : menu_stage.width - 28
                height: 36

                MenuItem { text: "Delete all developers" on_tap: app.delete_developers() }
                MenuItem { text: "Delete users" on_tap: app.delete_users() }
                MenuItem { text: "Export users" on_tap: app.export_users() }
                MenuItem { text: "Exit" on_tap: app.exit_selected() }
            }

            Button { id: add_user text: "Add user" on_tap: app.add_user() native: true x: 14 y: 62 width: menu_stage.width - 28 height: 36 }
        }

        Rectangle {
            x: 18
            y: 246
            width: card.width - 36
            height: 48
            background: #DCFCE7
            corner_radius: 7
            Label { id: menu_status text: app.status x: 10 y: 14 width: card.width - 56 height: 20 align: center color: #166534 font_size: 12 }
        }
    }
}
