Screen {
    id: root
    background: #F1F5F9

    Label {
        text: "Parent-local coordinates"
        x: 20
        y: 16
        width: root.width - 40
        height: 30
        color: #0F172A
        font_size: 20
        bold: true
    }

    RelativeLayout {
        id: panel
        x: 70
        y: 64
        width: 260
        height: 150
        background: #FFFFFF
        corner_radius: 12

        Rectangle {
            x: 16
            y: 18
            width: 88
            height: 44
            size_hint_x: -1
            size_hint_y: -1
            background: #DBEAFE
            corner_radius: 8
        }

        Button {
            id: centered_action
            text: "Centered"
            width: 110
            height: 38
            size_hint_x: -1
            size_hint_y: -1
            pos_hint_center_x: 0.5
            pos_hint_center_y: 0.6
            background: #2563EB
            color: #FFFFFF
            corner_radius: 8
        }
    }
}
