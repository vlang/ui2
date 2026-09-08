Screen {
    id: root
    background: #F1F5F9

    Rectangle {
        x: (root.width - 308) / 2
        y: 16
        width: 308
        height: 148
        background: #FFFFFF
        corner_radius: 10

        Label {
            text: "Formatting"
            x: 16
            y: 14
            width: 276
            height: 28
            color: #111827
            font_size: 18
            bold: true
        }

        ToggleButton {
            id: bold
            text: "Bold"
            bind.pressed: app.bold
            x: 16
            y: 54
            width: 112
            height: 40
            background: #E2E8F0
            color: #1E293B
            down_background: #1D4ED8
            down_color: #FFFFFF
            corner_radius: 7
        }

        Label {
            id: state
            text: app.bold ? "Pressed" : "Released"
            x: 144
            y: 54
            width: 148
            height: 40
            color: app.bold ? #1D4ED8 : #64748B
            align: center
        }
    }
}
