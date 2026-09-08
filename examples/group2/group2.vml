Screen {
    id: root
    background: #F1F5F9

    property f64 panel_width: (root.width - 64) / 2

    Rectangle {
        id: first_group
        x: 16
        y: 16
        width: root.panel_width
        height: root.height - 86
        background: #FFFFFF
        corner_radius: 10

        Label { text: "First group" x: 16 y: 14 width: first_group.width - 32 height: 28 color: #111827 font_size: 18 bold: true }
        TextField { id: first_ipsum bind.text: app.first_ipsum placeholder: "Lorem ipsum" x: 16 y: 58 width: first_group.width - 32 height: 34 background: #F8FAFC corner_radius: 7 font_size: 13 }
        TextField { id: second_ipsum bind.text: app.second_ipsum placeholder: "dolor sit amet" x: 16 y: 104 width: first_group.width - 32 height: 34 background: #F8FAFC corner_radius: 7 font_size: 13 }
        Button { id: more_ipsum text: "More ipsum!" on_tap: app.more_ipsum() native: true x: 16 y: 158 width: first_group.width - 32 height: 36 }
    }

    Rectangle {
        id: second_group
        x: 48 + root.panel_width
        y: 16
        width: root.panel_width
        height: root.height - 86
        background: #FFFFFF
        corner_radius: 10

        Label { text: "Second group" x: 16 y: 14 width: second_group.width - 32 height: 28 color: #111827 font_size: 18 bold: true }
        TextField { id: full_name bind.text: app.full_name placeholder: "Full name" x: 16 y: 58 width: second_group.width - 32 height: 34 background: #F8FAFC corner_radius: 7 font_size: 13 }
        Checkbox { id: likes_v text: "Do you like V?" bind.checked: app.likes_v x: 16 y: 108 width: second_group.width - 32 height: 26 font_size: 12 }
        Button { id: submit text: "Submit" on_tap: app.submit() native: true x: 16 y: 158 width: second_group.width - 32 height: 36 }
    }

    Label {
        id: status
        text: app.status
        x: 24
        y: root.height - 52
        width: root.width - 48
        height: 24
        color: #166534
        font_size: 12
        align: center
    }
}
