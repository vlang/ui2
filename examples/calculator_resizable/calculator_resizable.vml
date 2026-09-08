Screen {
    id: root
    background: #1F2937

    // Nothing here is a fixed pixel count. Every measurement is a fraction of
    // the window, so the keypad fills whatever size the window is dragged to
    // and the type grows with it instead of stranding a panel in the middle.
    property f64 margin: root.width * 0.04
    property f64 gap: root.height * 0.02
    property f64 display_h: root.height * 0.16
    property f64 grid_top: root.margin + root.display_h + root.gap
    property f64 btn_w: (root.width - root.margin * 2 - root.gap * 3) / 4
    property f64 btn_h: (root.height - root.grid_top - root.margin - root.gap * 4) / 5
    property f64 btn_font: root.height / 20
    property f64 display_font: root.height / 10
    property f64 radius: root.btn_h * 0.25

    Rectangle {
        id: display_panel
        x: root.margin
        y: root.margin
        width: root.width - root.margin * 2
        height: root.display_h
        background: #F8FAFC
        corner_radius: root.radius

        Label {
            id: display
            text: app.display
            x: root.margin
            y: 0
            width: root.width - root.margin * 4
            height: root.display_h
            color: #111827
            font_size: root.display_font
            align: right
        }
    }

    Repeater {
        model: app.keys
        key: item.key

        Button {
            text: item.text
            on_tap: app.press(item.text)
            x: root.margin + item.column * (root.btn_w + root.gap)
            y: root.grid_top + item.row * (root.btn_h + root.gap)
            width: root.btn_w
            height: root.btn_h
            background: item.role == "clear" ? #EF4444 : item.role == "operator" ? #3478D4 : item.role == "utility" ? #64748B : #E2E8F0
            color: item.role == "digit" ? #111827 : #FFFFFF
            font_size: root.btn_font
            bold: item.text == "="
            align: center
            corner_radius: root.radius
        }
    }
}
