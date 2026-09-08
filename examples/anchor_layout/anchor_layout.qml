Screen {
    id: root
    background: #F1F5F9

    Label {
        text: "Anchored controls"
        x: 20
        y: 16
        width: root.width - 40
        height: 32
        color: #0F172A
        font_size: 22
        bold: true
    }

    AnchorLayout {
        id: top_left
        x: 20
        y: 60
        width: 160
        height: 100
        anchor_x: left
        anchor_y: top
        padding: 10
        background: #FFFFFF
        corner_radius: 8
        Button { text: "Top left" width: 88 height: 34 background: #DBEAFE }
    }

    AnchorLayout {
        id: centered
        x: 200
        y: 60
        width: 160
        height: 100
        background: #FFFFFF
        corner_radius: 8
        Button { text: "Centered" width: 88 height: 34 background: #DCFCE7 }
    }

    AnchorLayout {
        id: bottom_right
        x: 20
        y: 180
        width: root.width - 40
        height: 100
        anchor_x: right
        anchor_y: bottom
        padding: 10
        background: #FFFFFF
        corner_radius: 8
        Button { text: "Bottom right" width: 112 height: 34 background: #FCE7F3 }
    }
}
