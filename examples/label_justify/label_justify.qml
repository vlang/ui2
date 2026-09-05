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
            text: "Label justification"
            x: 16
            y: 14
            width: card.width - 32
            height: 28
            color: #111827
            font_size: 18
            bold: true
        }

        Rectangle {
            x: 16
            y: 56
            width: card.width - 32
            height: 48
            background: #FEF3C7
            corner_radius: 7

            Label { id: left_label text: "Left aligned" x: 12 y: 0 width: card.width - 56 height: 48 align: left color: #78350F font_size: 13 }
        }

        Rectangle {
            x: 16
            y: 116
            width: card.width - 32
            height: 48
            background: #DBEAFE
            corner_radius: 7

            Label { id: center_label text: "Centered text" x: 12 y: 0 width: card.width - 56 height: 48 align: center color: #1E3A8A font_size: 13 }
        }

        Rectangle {
            x: 16
            y: 176
            width: card.width - 32
            height: 48
            background: #DCFCE7
            corner_radius: 7

            Label { id: right_label text: "Right aligned" x: 12 y: 0 width: card.width - 56 height: 48 align: right color: #14532D font_size: 13 }
        }

        Label {
            id: clipped_label
            text: "A deliberately long label is clipped to this narrow frame"
            x: 16
            y: 242
            width: 190
            height: 22
            color: #475569
            font_size: 12
            lines: 1
        }

        Rectangle {
            x: 214
            y: 252
            width: card.width - 230
            height: 1
            background: #CBD5E1
        }
    }
}
