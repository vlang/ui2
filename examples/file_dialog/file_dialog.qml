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

        Label { text: "Native file and folder dialogs" x: 20 y: 22 width: card.width - 40 height: 28 color: #111827 font_size: 20 bold: true }
        Label { text: "Each action opens the operating system picker and blocks until it closes." x: 20 y: 56 width: card.width - 40 height: 20 color: #64748B font_size: 12 }

        Button { id: open_source text: "Open source" on_tap: app.open_source() native: true x: 20 y: 98 width: 160 height: 38 }
        Button { id: save_text text: "Save text" on_tap: app.save_text() native: true x: 194 y: 98 width: 160 height: 38 }
        Button { id: choose_folder text: "Choose folder" on_tap: app.choose_folder() native: true x: 368 y: 98 width: 160 height: 38 }

        Label { id: selection text: app.selection x: 20 y: 166 width: card.width - 40 height: 48 color: #166534 font_size: 12 }
    }
}
