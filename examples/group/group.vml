Screen {
    id: root
    background: #F1F5F9

    property f64 card_width: root.width - 32 < 348 ? root.width - 32 : 348
    property f64 card_x: (root.width - root.card_width) / 2

    Rectangle {
        id: group
        x: root.card_x
        y: 16
        width: root.card_width
        height: 310
        background: #FFFFFF
        corner_radius: 10

        Label {
            text: "Group Demo"
            x: 16
            y: 14
            width: group.width - 32
            height: 24
            color: #111827
            font_size: 18
            bold: true
        }

        TextField {
            id: first_name
            bind.text: app.first_name
            placeholder: "First name"
            x: 16
            y: 50
            width: group.width - 32
            height: 28
            background: #F8FAFC
            corner_radius: 7
        }

        TextField {
            id: last_name
            bind.text: app.last_name
            placeholder: "Last name"
            x: 16
            y: 88
            width: group.width - 32
            height: 28
            background: #F8FAFC
            corner_radius: 7
        }

        Checkbox {
            id: registration1
            text: "Online registration 1"
            bind.checked: app.registration1
            x: 16
            y: 128
            width: group.width - 32
            height: 24
        }
        Checkbox {
            id: registration2
            text: "Online registration 2"
            bind.checked: app.registration2
            x: 16
            y: 158
            width: group.width - 32
            height: 24
        }
        Checkbox {
            id: registration3
            text: "Online registration 3"
            bind.checked: app.registration3
            x: 16
            y: 188
            width: group.width - 32
            height: 24
        }

        Button {
            id: add_user
            text: "Add user"
            on_tap: app.submit()
            native: true
            x: 16
            y: 224
            width: group.width - 32
            height: 36
            background: #3478D4
            color: #FFFFFF
            corner_radius: 7
        }

        Label {
            id: message
            text: app.message
            x: 16
            y: 276
            width: group.width - 32
            height: 18
            color: #166534
            font_size: 13
            align: center
        }
    }
}
