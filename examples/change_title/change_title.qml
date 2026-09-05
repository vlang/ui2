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

        Label { text: "Change title" x: 18 y: 14 width: card.width - 36 height: 28 color: #111827 font_size: 18 bold: true }
        Label { text: "Current title: ${app.applied_title}" x: 18 y: 48 width: card.width - 36 height: 20 color: #64748B font_size: 12 }

        TextField { id: title bind.text: app.title on_submit: app.apply_title() placeholder: "Please enter a new title" x: 18 y: 82 width: card.width - 154 height: 38 background: app.valid ? #F8FAFC : #FEE2E2 corner_radius: 7 font_size: 13 }
        Button { id: apply_title text: "Change title" on_tap: app.apply_title() native: true x: card.width - 126 y: 84 width: 108 height: 34 }

        Rectangle { x: 18 y: 138 width: card.width - 36 height: 48 background: app.valid ? #DCFCE7 : #FEE2E2 corner_radius: 8
            Label { id: title_status text: app.status x: 12 y: 0 width: card.width - 60 height: 48 align: center color: app.valid ? #166534 : #991B1B font_size: 12 }
        }
    }
}
