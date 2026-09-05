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

        Label {
            text: "People"
            x: 16
            y: 14
            width: 210
            height: 28
            color: #111827
            font_size: 17
            bold: true
        }

        Label { text: "Filter prefix" x: 16 y: 48 width: 210 height: 20 color: #475569 font_size: 12 }
        TextField {
            id: filter
            bind.text: app.filter
            on_change: app.filter_changed()
            placeholder: "Surname prefix"
            x: 16
            y: 70
            width: 210
            height: 32
            background: #F8FAFC
            corner_radius: 7
            font_size: 13
        }

        Scroll {
            id: people_list
            x: 16
            y: 112
            width: 210
            height: card.height - 176
            background: #F8FAFC

            Repeater {
                model: app.visible_people
                key: item.id

                Button {
                    text: item.id == app.selected_id ? "✓ ${item.display}" : item.display
                    on_tap: app.select_person(item.id)
                    native: true
                    x: 8
                    y: index * 34
                    width: 178
                    height: 30
                    background: item.id == app.selected_id ? #DBEAFE : #FFFFFF
                    color: #111827
                    corner_radius: 6
                    font_size: 13
                }
            }
        }

        Label {
            text: "Edit person"
            x: 246
            y: 14
            width: card.width - 262
            height: 28
            color: #111827
            font_size: 17
            bold: true
        }
        Label { text: "Name" x: 246 y: 48 width: card.width - 262 height: 20 color: #475569 font_size: 12 }
        TextField {
            id: name
            bind.text: app.name
            placeholder: "Name"
            x: 246
            y: 70
            width: card.width - 262
            height: 32
            background: #F8FAFC
            corner_radius: 7
            font_size: 13
        }
        Label { text: "Surname" x: 246 y: 114 width: card.width - 262 height: 20 color: #475569 font_size: 12 }
        TextField {
            id: surname
            bind.text: app.surname
            placeholder: "Surname"
            x: 246
            y: 136
            width: card.width - 262
            height: 32
            background: #F8FAFC
            corner_radius: 7
            font_size: 13
        }

        Button {
            id: create
            text: "Create"
            on_tap: app.create_person()
            native: true
            x: 246
            y: 184
            width: (card.width - 278) / 3
            height: 34
            background: #3478D4
            color: #FFFFFF
            corner_radius: 7
        }
        Button {
            id: update
            text: "Update"
            on_tap: app.update_person()
            native: true
            enabled: app.selected_id >= 0
            x: 254 + (card.width - 278) / 3
            y: 184
            width: (card.width - 278) / 3
            height: 34
            background: #E2E8F0
            corner_radius: 7
        }
        Button {
            id: delete
            text: "Delete"
            on_tap: app.delete_person()
            native: true
            enabled: app.selected_id >= 0
            x: 262 + (card.width - 278) / 3 * 2
            y: 184
            width: (card.width - 278) / 3
            height: 34
            background: #FEE2E2
            color: #991B1B
            corner_radius: 7
        }

        Label {
            id: message
            text: app.message
            x: 246
            y: 234
            width: card.width - 262
            height: 40
            color: #166534
            font_size: 13
            lines: 2
        }

        Label {
            text: "${app.visible_people.len}/${app.people.len} people"
            x: 16
            y: card.height - 42
            width: 210
            height: 18
            color: #64748B
            font_size: 13
            align: center
        }
    }
}
