Screen {
    id: root
    background: #F1F5F9

    // Declared properties resolve against the window, so the header, the rows,
    // and the editor strip all measure their columns the same way.
    property f64 grid_w: root.width - 68
    property f64 col_w: (root.width - 124) / 5
    // A single editor row needs room for its label, four fields, and the
    // worker checkbox. Below this width, split the fields across two rows so
    // native controls never draw over each other.
    property bool compact_editor: root.width < 680
    property f64 field_w: (root.width - 288) / 4
    property f64 compact_text_w: (root.width - 180) / 2
    property f64 compact_select_w: (root.width - 200) / 2
    property f64 editor_h: root.compact_editor ? 92 : 58
    property f64 header_y: root.compact_editor ? 174 : 140
    property f64 body_y: root.header_y + 36

    Rectangle {
        id: card
        x: 16
        y: 16
        width: root.width - 32
        height: root.height - 32
        background: #FFFFFF
        corner_radius: 10

        Label { text: "Grid 2" x: 18 y: 14 width: 200 height: 28 color: #111827 font_size: 18 bold: true }
        Button { id: reset_sort text: "Row order" on_tap: app.reset_sort() native: true x: card.width - 128 y: 13 width: 110 height: 34 }
        Label { text: "Typed columns: two text columns, two factor columns, and one boolean. Tap a header to sort, a row number to select, then edit the selected record below." x: 18 y: 44 width: card.width - 156 height: 18 color: #64748B font_size: 11 }

        Rectangle {
            id: editor
            x: 18
            y: 70
            width: card.width - 36
            height: root.editor_h
            background: #F8FAFC
            corner_radius: 8

            Label { text: "Row ${app.selected}" x: 14 y: 20 width: 70 height: 18 color: #334155 font_size: 12 bold: true }
            TextField { id: edit_v1 bind.text: app.edit_v1 on_change: app.apply_edits() x: 88 y: root.compact_editor ? 8 : 12 width: root.compact_editor ? root.compact_text_w : root.field_w height: 34 background: #FFFFFF corner_radius: 7 }
            TextField { id: edit_v2 bind.text: app.edit_v2 on_change: app.apply_edits() x: root.compact_editor ? 96 + root.compact_text_w : 96 + root.field_w y: root.compact_editor ? 8 : 12 width: root.compact_editor ? root.compact_text_w : root.field_w height: 34 background: #FFFFFF corner_radius: 7 }
            Dropdown {
                id: edit_sex
                bind.text: app.edit_sex
                on_change: app.apply_edits()
                x: root.compact_editor ? 14 : 104 + 2 * root.field_w
                y: root.compact_editor ? 50 : 12
                width: root.compact_editor ? root.compact_select_w : root.field_w
                height: 34
                background: #FFFFFF
                corner_radius: 7

                Option { text: "Male" }
                Option { text: "Female" }
            }
            Dropdown {
                id: edit_csp
                bind.text: app.edit_csp
                on_change: app.apply_edits()
                x: root.compact_editor ? 22 + root.compact_select_w : 112 + 3 * root.field_w
                y: root.compact_editor ? 50 : 12
                width: root.compact_editor ? root.compact_select_w : root.field_w
                height: 34
                background: #FFFFFF
                corner_radius: 7

                Option { text: "job1" }
                Option { text: "job2" }
                Option { text: "other" }
            }
            Checkbox { id: edit_worker text: "worker" bind.checked: app.edit_worker on_tap: app.apply_edits() x: root.compact_editor ? 30 + 2 * root.compact_select_w : 120 + 4 * root.field_w y: root.compact_editor ? 55 : 18 width: 90 height: 24 color: #334155 font_size: 12 }
        }

        Rectangle {
            id: header
            x: 18
            y: root.header_y
            width: card.width - 36
            height: 34
            background: #334155
            corner_radius: 6

            Label { text: "#" x: 0 y: 8 width: 56 height: 18 align: center color: #E2E8F0 font_size: 11 bold: true }

            Repeater {
                model: app.columns
                key: item.key

                Button {
                    text: item.label
                    on_tap: app.sort_by(item.key)
                    x: 58 + item.index * root.col_w
                    y: 3
                    width: root.col_w - 4
                    height: 28
                    background: #475569
                    color: #F8FAFC
                    font_size: 12
                    corner_radius: 5
                }
            }
        }

        Scroll {
            id: body
            x: 18
            y: root.body_y
            width: card.width - 36
            height: card.height - root.body_y - 60
            background: #E2E8F0
            persistent: true

            Repeater {
                model: app.rows
                key: item.key

                Rectangle {
                    x: 0
                    y: index * 32
                    width: root.grid_w
                    height: 31
                    background: item.selected ? #DBEAFE : item.stripe

                    Button { text: item.number on_tap: app.select_row(item.id) x: 4 y: 3 width: 48 height: 25 background: item.selected ? #2563EB : #E2E8F0 color: item.selected ? #FFFFFF : #334155 font_size: 11 corner_radius: 5 }
                    Label { text: item.v1 x: 66 y: 7 width: root.col_w - 16 height: 18 color: #0F172A font_size: 12 }
                    Label { text: item.v2 x: 66 + root.col_w y: 7 width: root.col_w - 16 height: 18 color: #0F172A font_size: 12 }
                    Label { text: item.sex x: 66 + 2 * root.col_w y: 7 width: root.col_w - 16 height: 18 color: #1D4ED8 font_size: 12 }
                    Label { text: item.worker x: 66 + 3 * root.col_w y: 7 width: root.col_w - 16 height: 18 color: item.worker == "yes" ? #15803D : #B91C1C font_size: 12 }
                    Label { text: item.csp x: 66 + 4 * root.col_w y: 7 width: root.col_w - 16 height: 18 color: #7C3AED font_size: 12 }
                }
            }
        }

        Label { id: grid2_status text: app.status x: 18 y: card.height - 44 width: card.width - 36 height: 20 align: center color: #166534 font_size: 12 }
    }
}
