Screen {
    id: root
    background: #F1F5F9

    Label {
        text: "Responsive box layout"
        x: 20
        y: 14
        width: root.width - 40
        height: 28
        color: #111827
        font_size: 18
        bold: true
    }

    Rectangle {
        id: canvas
        x: 16
        y: 54
        width: root.width - 32
        height: root.height - 70
        background: #FFFFFF
        corner_radius: 10

        Rectangle {
            id: red
            x: 16
            y: 16
            width: 72
            height: 72
            background: #FF6464
            corner_radius: 8

            Label { text: "fixed" x: 0 y: 0 width: red.width height: red.height align: center color: #5F1111 font_size: 12 }
        }

        Rectangle {
            id: green
            x: 104
            y: 48
            width: canvas.width - 136
            height: canvas.height - 80
            background: #D9F99D
            corner_radius: 10

            Label { text: "stretches with the window" x: 12 y: 12 width: green.width - 24 height: 22 color: #365314 font_size: 13 }
        }

        Rectangle {
            id: blue
            x: canvas.width / 2
            y: canvas.height / 2
            width: canvas.width / 2 - 16
            height: canvas.height / 2 - 16
            background: #BFDBFE
            corner_radius: 10

            // The corner anchor block below overlaps this rectangle's last 56
            // pixels, so the right-aligned label stops short of it instead of
            // being painted over.
            Label { id: blue_caption text: "50% anchored" x: 12 y: blue.height - 32 width: blue.width - 80 height: 20 align: right color: #1E3A8A font_size: 12 }
        }

        Rectangle {
            id: white_anchor
            x: canvas.width - 72
            y: canvas.height - 72
            width: 56
            height: 56
            background: #FFFFFF
            corner_radius: 8

            Rectangle {
                id: black_anchor
                x: 8
                y: 8
                width: 40
                height: 40
                background: #111827
                corner_radius: 6
            }
        }
    }
}
