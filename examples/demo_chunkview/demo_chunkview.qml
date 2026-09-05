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

        Label { text: "Chunk view" x: 18 y: 14 width: 160 height: 28 color: #111827 font_size: 18 bold: true }
        Checkbox { id: first_open text: "First chunk" bind.checked: app.first_open on_tap: app.sections_changed() x: 190 y: 14 width: 120 height: 30 color: #334155 font_size: 11 }
        Checkbox { id: second_open text: "Second chunk" bind.checked: app.second_open on_tap: app.sections_changed() x: 316 y: 14 width: 130 height: 30 color: #334155 font_size: 11 }
        Dropdown { id: alignment bind.text: app.alignment on_change: app.alignment_changed() x: card.width - 234 y: 12 width: 112 height: 36 background: #F1F5F9 corner_radius: 7
            Option { text: "Left" }
            Option { text: "Center" }
            Option { text: "Right" }
        }
        Button { id: reset_chunks text: "Reset" on_tap: app.reset_chunks() native: true x: card.width - 112 y: 13 width: 94 height: 34 }

        Rectangle {
            id: chunk_stage
            x: 18
            y: 62
            width: card.width - 36
            height: card.height - 118
            background: #F8FAFC
            corner_radius: 9

            Rectangle {
                id: first_chunk
                hidden: !app.first_open
                x: 16
                y: 16
                width: chunk_stage.width - 32
                height: (chunk_stage.height - 48) / 2
                background: #FEF3C7
                corner_radius: 9

                Label { text: "RowChunk with ParaChunk" x: 16 y: 14 width: first_chunk.width - 32 height: 28 align: app.text_align color: #92400E font_size: 18 bold: true italic: true }
                Label { text: "Red text" x: 16 y: 54 width: (first_chunk.width - 48) / 3 height: 24 align: app.text_align color: #DC2626 font_size: 15 bold: true }
                Label { text: "Blue text" x: 24 + (first_chunk.width - 48) / 3 y: 54 width: (first_chunk.width - 48) / 3 height: 24 align: app.text_align color: #2563EB font_size: 17 italic: true }
                Label { text: "😻 🥰 😬 🪬 😴  ✔️ 💾" x: 32 + (first_chunk.width - 48) * 0.66 y: 50 width: (first_chunk.width - 48) / 3 height: 32 align: center color: #111827 font_size: 18 }
                Label { text: "Nested labels preserve independent font, color, emphasis, and alignment." x: 16 y: first_chunk.height - 40 width: first_chunk.width - 32 height: 22 align: app.text_align color: #78350F font_size: 11 }
            }

            Rectangle {
                id: second_chunk
                hidden: !app.second_open
                x: 16
                y: 32 + (chunk_stage.height - 48) / 2
                width: chunk_stage.width - 32
                height: (chunk_stage.height - 48) / 2
                background: #334155
                corner_radius: 9

                Label { text: "A second nested paragraph" x: 18 y: 16 width: second_chunk.width - 36 height: 28 align: app.text_align color: #F8FAFC font_size: 18 bold: true }
                Label { text: "toto titi tata · tutu tete" x: 18 y: 54 width: second_chunk.width - 36 height: 24 align: app.text_align color: #FCA5A5 font_family: "Courier New" font_size: 14 }
                Label { text: "Chunk composition remains responsive when the window is resized." x: 18 y: second_chunk.height - 42 width: second_chunk.width - 36 height: 22 align: app.text_align color: #BFDBFE font_size: 11 underline: true }
            }
        }

        Label { id: chunk_status text: app.status x: 18 y: card.height - 40 width: card.width - 36 height: 18 align: center color: #166534 font_size: 11 }
    }
}
