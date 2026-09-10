Screen {
    id: root
    background: #F1F5F9

    Label { text: "Modal view" x: 20 y: 20 width: root.width - 40 height: 34 align: center color: #0F172A font_size: 24 bold: true }
    Label { text: app.status x: 20 y: 76 width: root.width - 40 height: 26 align: center color: #475569 }
    Button { text: "Open confirmation" on_tap: app.open_confirmation() x: (root.width - 170) / 2 y: 132 width: 170 height: 40 background: #2563EB color: #FFFFFF corner_radius: 8 }

    ModalView {
        id: confirmation
        width: root.width
        height: root.height
        open: app.confirming
        on_dismiss: app.close_confirmation()
        content_width: 340
        content_height: 190
        overlay_background: #475569
        background: #FFFFFF
        corner_radius: 12

        Label { text: "Confirm action" x: 24 y: 24 width: 292 height: 30 align: center color: #0F172A font_size: 20 bold: true }
        Label { text: "The backdrop can dismiss this modal." x: 24 y: 66 width: 292 height: 24 align: center color: #64748B }
        Button { text: "Cancel" on_tap: app.close_confirmation() x: 46 y: 126 width: 110 height: 38 background: #E2E8F0 color: #334155 corner_radius: 8 }
        Button { text: "Confirm" on_tap: app.confirm() x: 184 y: 126 width: 110 height: 38 background: #2563EB color: #FFFFFF corner_radius: 8 }
    }
}
