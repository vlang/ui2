Screen {
    id: root
    background: #F1F5F9

    property f64 sheet_width: root.width - 68
    property f64 cell_width: (root.sheet_width - 38) / 5

    Rectangle {
        id: card
        x: 16
        y: 16
        width: root.width - 32
        height: root.height - 32
        background: #FFFFFF
        corner_radius: 10

        Label { text: "Cells" x: 18 y: 14 width: 100 height: 28 color: #111827 font_size: 18 bold: true }
        Label { text: app.selected_address.len > 0 ? "Edit ${app.selected_address}" : "Select a cell" x: 126 y: 18 width: 92 height: 20 color: #64748B font_size: 11 }
        TextField { id: cell_input bind.text: app.edit_value on_submit: app.apply_edit() placeholder: "value or =sum(A1:B2)" x: 220 y: 12 width: card.width - 340 height: 38 background: #F8FAFC corner_radius: 7 font_family: "Courier New" font_size: 12 }
        Button { id: apply_cell text: "Apply" on_tap: app.apply_edit() native: true x: card.width - 108 y: 14 width: 90 height: 34 }

        Rectangle {
            id: sheet
            x: 18
            y: 64
            width: card.width - 36
            height: 280
            background: #CBD5E1
            corner_radius: 7

            Rectangle { x: 1 y: 1 width: 34 height: 32 background: #334155 }
            Repeater { model: app.columns key: item.label
                Rectangle { x: 37 + item.column * root.cell_width y: 1 width: root.cell_width - 2 height: 32 background: #334155
                    Label { text: item.label x: 0 y: 0 width: root.cell_width - 2 height: 32 align: center color: #FFFFFF font_size: 11 bold: true }
                }
            }
            Repeater { model: app.rows key: item.id
                Rectangle { x: 1 y: 35 + item.row * 40 width: 34 height: 38 background: #E2E8F0
                    Label { text: item.label x: 0 y: 0 width: 34 height: 38 align: center color: #475569 font_size: 10 bold: true }
                }
            }
            Repeater { model: app.cells key: item.address
                Button { text: item.formula ? "${item.display} ƒ" : item.display on_tap: app.select_cell(item.id) native: true x: 37 + item.column * root.cell_width y: 35 + item.row * 40 width: root.cell_width - 2 height: 38 background: item.id == app.selected_id ? #DBEAFE : #FFFFFF font_family: "Courier New" font_size: 10 }
            }
        }

        Rectangle { x: 18 y: 360 width: card.width - 36 height: 82 background: #F8FAFC corner_radius: 7
            Label { text: "Formula examples" x: 12 y: 10 width: 130 height: 18 color: #475569 font_size: 11 bold: true }
            Label { text: "B1 = sum(B2:C5, D2)" x: 12 y: 34 width: (card.width - 70) / 3 height: 20 color: #64748B font_family: "Courier New" font_size: 10 }
            Label { text: "C5 = sum(D2:D5)" x: 20 + (card.width - 70) / 3 y: 34 width: (card.width - 70) / 3 height: 20 color: #64748B font_family: "Courier New" font_size: 10 }
            Label { text: "A4 = sum(B4:D4)" x: 28 + (card.width - 70) * 0.66 y: 34 width: (card.width - 70) / 3 height: 20 color: #64748B font_family: "Courier New" font_size: 10 }
        }

        Label { id: cells_status text: app.status x: 18 y: card.height - 40 width: card.width - 36 height: 18 align: center color: #166534 font_size: 11 }
    }
}
