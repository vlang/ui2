Screen {
    id: root
    background: #F1F5F9

    Rectangle {
        id: card
        x: 16
        y: 16
        width: root.width - 32
        height: root.height - 32
        background: #FFFFFF
        corner_radius: 10

        Label {
            id: centered_label
            text: "Centered text"
            x: 24
            y: 24
            width: card.width - 48
            height: card.height - 48
            color: #1E293B
            font_size: 20
            bold: true
            align: center
        }
    }
}
