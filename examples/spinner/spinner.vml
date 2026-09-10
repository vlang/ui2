Screen {
    id: root
    background: #F1F5F9

    Rectangle {
        x: (root.width - 328) / 2
        y: 16
        width: 328
        height: 158
        background: #FFFFFF
        corner_radius: 10

        Label {
            text: "Location"
            x: 16
            y: 14
            width: 296
            height: 26
            color: #111827
            font_size: 18
            bold: true
        }

        Spinner {
            id: location
            bind.text: app.selection
            on_text: app.selection_changed()
            x: 16
            y: 50
            width: 296
            height: 42
            background: #DBEAFE
            color: #1D4ED8
            corner_radius: 7

            Option { text: "Home" }
            Option { text: "Work" }
            Option { text: "Other" }
        }

        Label {
            id: selection-message
            text: app.message
            x: 16
            y: 108
            width: 296
            height: 24
            color: #166534
            align: center
        }
    }
}
