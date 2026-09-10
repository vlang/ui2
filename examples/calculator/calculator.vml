Screen {
    id: root
    background: #F1F5F9

    property f64 outer_margin: 12
    property f64 available_width: root.width - root.outer_margin * 2
    property f64 panel_width: root.available_width < 260 ? root.available_width : 260
    property f64 panel_height: 340
    property f64 panel_x: root.width > root.panel_width ? (root.width - root.panel_width) / 2 : 0
    property f64 panel_y: root.height > root.panel_height ? (root.height - root.panel_height) / 2 : 0
    property f64 padding: 12
    property f64 spacing: 8
    property f64 content_width: root.panel_width - root.padding * 2
    property f64 button_width: (root.content_width - root.spacing * 3) / 4
    property f64 button_height: 44

    Rectangle {
        id: calculator
        x: root.panel_x
        y: root.panel_y
        width: root.panel_width
        height: root.panel_height
        background: #1F2937
        corner_radius: 12

        Rectangle {
            x: root.padding
            y: root.padding
            width: root.content_width
            height: 56
            background: #FFFFFF
            corner_radius: 8

            Label {
                id: display
                text: app.display
                x: 10
                y: 0
                width: root.content_width - 20
                height: 56
                color: #111827
                font_size: 28
                align: right
            }
        }

        Repeater {
            model: app.keys
            key: item.text

            Button {
                text: item.text
                on_tap: app.press(item.text)
                native: true
                x: root.padding + item.column * (root.button_width + root.spacing)
                y: 76 + item.row * (root.button_height + root.spacing)
                width: root.button_width
                height: root.button_height
                background: item.role == "clear" ? #EF4444 : item.role == "operator" ? #3478D4 : item.role == "utility" ? #CBD5E1 : #F8FAFC
                color: item.role == "clear" || item.role == "operator" ? #FFFFFF : #111827
                font_size: 18
                bold: item.text == "="
                align: center
                corner_radius: 8
            }
        }
    }
}
