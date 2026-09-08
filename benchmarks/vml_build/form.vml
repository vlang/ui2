Screen {
    id: root
    background: #F1F5F9

    property f64 panel_width: root.width - 24
    property f64 cell_width: (root.panel_width - 30) / 4

    Rectangle {
        x: 12
        y: 12
        width: root.panel_width
        height: root.height - 24
        background: #1F2937
        corner_radius: 12

        Label {
            text: app.display
            x: 10
            y: 8
            width: root.panel_width - 20
            height: 48
            color: #FFFFFF
            font_size: 28
            align: right
        }

        Repeater {
            model: app.keys
            key: item.text

            Button {
                text: item.text
                x: 6 + item.column * (root.cell_width + 6)
                y: 64 + item.row * 50
                width: root.cell_width
                height: 44
                background: item.role == "operator" ? #3478D4 : #F8FAFC
                color: item.role == "operator" ? #FFFFFF : #111827
                font_size: 18
                bold: item.text == "="
                align: center
                corner_radius: 8
            }
        }
    }
}
