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

        Label { text: "Raster view" x: 18 y: 14 width: card.width - 156 height: 28 color: #111827 font_size: 18 bold: true }
        Label { text: "Display a bitmap asset in a responsive frame." x: 18 y: 42 width: card.width - 36 height: 20 color: #64748B font_size: 12 }
        Button { id: toggle_details text: app.show_details ? "Hide details" : "Show details" on_tap: app.toggle_details() native: true x: card.width - 138 y: 16 width: 120 height: 34 }

        Rectangle {
            id: image_frame
            x: 18
            y: 76
            width: card.width - 36
            height: card.height - 134
            background: #F8FAFC
            corner_radius: 9

            Image {
                id: logo
                source: app.image_path
                x: (image_frame.width - 260) / 2
                y: (image_frame.height - 260) / 2
                width: 260
                height: 260
            }

            Rectangle {
                hidden: !app.show_details
                x: 14
                y: image_frame.height - 54
                width: image_frame.width - 28
                height: 40
                background: #FFFFFF
                corner_radius: 7
                Label { text: "260 × 260 preview • ${app.image_path}" x: 10 y: 10 width: image_frame.width - 48 height: 20 align: center color: #475569 font_size: 10 }
            }
        }

        Label { id: raster_status text: app.status x: 18 y: card.height - 40 width: card.width - 36 height: 18 align: center color: #166534 font_size: 11 }
    }
}
