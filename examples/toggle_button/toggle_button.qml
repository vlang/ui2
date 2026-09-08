Screen {
    id: root
    background: #F1F5F9

    Rectangle {
        x: (root.width - 308) / 2
        y: 16
        width: 308
        height: 164
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
            group: formatting
            allow_no_selection: false
            x: 16
            y: 54
            width: 80
            height: 40
            background: #E2E8F0
            color: #1E293B
            down_background: #1D4ED8
            down_color: #FFFFFF
            corner_radius: 7
        }

        ToggleButton {
            id: italic
            text: "Italic"
            bind.pressed: app.italic
            group: formatting
            allow_no_selection: false
            x: 104
            y: 54
            width: 80
            height: 40
            background: #E2E8F0
            color: #1E293B
            down_background: #1D4ED8
            down_color: #FFFFFF
            corner_radius: 7
        }

        Label {
            id: state
            text: app.bold ? "Bold" : "Italic"
            x: 200
            y: 54
            width: 92
            height: 40
            color: #1D4ED8
            align: center
        }
    }
}
