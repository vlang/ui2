Screen {
    id: root
    background: #F1F5F9

    Label {
        text: "Independent positioning"
        x: 20
        y: 16
        width: root.width - 40
        height: 30
        color: #0F172A
        font_size: 20
        bold: true
    }

    FloatLayout {
        id: canvas
        x: 20
        y: 60
        width: root.width - 40
        height: 170
        background: #FFFFFF
        corner_radius: 10

        Rectangle {
            size_hint_x: 0.72
            size_hint_y: 0.55
            pos_hint_center_x: 0.5
            pos_hint_center_y: 0.5
            background: #DBEAFE
            corner_radius: 12
        }

        Button {
            id: center_action
            text: "Centered"
            width: 120
            height: 42
            size_hint_x: -1
            size_hint_y: -1
            pos_hint_center_x: 0.5
            pos_hint_center_y: 0.5
            background: #2563EB
            color: #FFFFFF
            corner_radius: 8
        }

        Label {
            text: "bottom right"
            width: 96
            height: 24
            size_hint_x: -1
            size_hint_y: -1
            pos_hint_right: 0.96
            pos_hint_bottom: 0.94
            color: #475569
            font_size: 12
            align: right
        }
    }
}
