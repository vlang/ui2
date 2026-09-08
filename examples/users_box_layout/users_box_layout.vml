Screen {
    id: root
    background: #F1F5F9

    // The form keeps a fixed width on the left while the table pane is anchored
    // to both edges, which is what the original box layout's "(220,20) -> (-5,-5)"
    // child expresses.
    property f64 form_w: 232
    property f64 table_x: root.form_w + 50
    property f64 table_w: root.width - root.form_w - 84

    Rectangle {
        id: card
        x: 16
        y: 16
        width: root.width - 32
        height: root.height - 32
        background: #FFFFFF
        corner_radius: 10

        Label { text: "Users" x: 18 y: 14 width: 200 height: 28 color: #111827 font_size: 18 bold: true }
        Label { text: "A fixed form column beside a table pane that grows with the window." x: 18 y: 44 width: card.width - 36 height: 18 color: #64748B font_size: 11 }

        Rectangle {
            id: form
            x: 18
            y: 70
            width: root.form_w
            height: card.height - 88
            background: #F8FAFC
            corner_radius: 9

            TextField { id: first_name placeholder: "First name" bind.text: app.first_name on_change: app.first_name_changed() x: 16 y: 16 width: root.form_w - 32 height: 34 background: app.is_error ? #FEE2E2 : #FFFFFF corner_radius: 7 }
            TextField { id: last_name placeholder: "Last name" bind.text: app.last_name on_change: app.last_name_changed() x: 16 y: 58 width: root.form_w - 32 height: 34 background: app.is_error ? #FEE2E2 : #FFFFFF corner_radius: 7 }
            TextField { id: age placeholder: "Age" bind.text: app.age on_change: app.age_changed() keyboard: decimal x: 16 y: 100 width: root.form_w - 32 height: 34 background: app.is_error ? #FEE2E2 : #FFFFFF corner_radius: 7 }
            TextField { id: password placeholder: "Password" bind.text: app.password secure: true x: 16 y: 142 width: root.form_w - 32 height: 34 background: #FFFFFF corner_radius: 7 }

            Checkbox { id: online text: "Online registration" checked: app.online on_tap: app.toggle_online() x: 16 y: 188 width: root.form_w - 32 height: 26 color: #1E293B font_size: 12 }
            Checkbox { id: subscribed text: "Subscribe to the newsletter" checked: app.subscribed on_tap: app.toggle_subscribed() x: 16 y: 216 width: root.form_w - 32 height: 26 color: #1E293B font_size: 12 }

            Label { text: "Country" x: 16 y: 252 width: root.form_w - 32 height: 18 color: #334155 font_size: 12 bold: true }

            Repeater {
                model: app.countries
                key: item.key

                Checkbox {
                    text: item.name
                    checked: item.name == app.country
                    on_tap: app.select_country(item.name)
                    x: 16
                    y: 274 + index * 28
                    width: root.form_w - 32
                    height: 26
                    color: #1E293B
                    font_size: 12
                }
            }

            Button { id: add_user text: "Add user" on_tap: app.add_user() native: true tooltip: "Required fields:\nFirst name, last name, age" x: 16 y: 396 width: 118 height: 34 }
            Button { id: about text: "?" on_tap: app.about() native: true tooltip: "about" x: 142 y: 396 width: 44 height: 34 }
            Button { id: reset text: "Clear" on_tap: app.reset() native: true x: root.form_w - 32 - 44 y: 396 width: 44 height: 34 }

            Rectangle { x: 16 y: 448 width: root.form_w - 32 height: 14 background: #E2E8F0 corner_radius: 7
                Rectangle { x: 0 y: 0 width: app.progress * (root.form_w - 32) height: 14 background: #2563EB corner_radius: 7 }
            }
            Label { id: progress_label text: app.progress_label x: 16 y: 468 width: root.form_w - 32 height: 18 align: center color: #334155 font_size: 11 }
        }

        Rectangle {
            id: table
            x: root.table_x
            y: 70
            width: root.table_w
            height: card.height - 88
            background: #FFF0F0
            corner_radius: 9

            Rectangle { x: 14 y: 14 width: root.table_w - 28 height: 28 background: #334155 corner_radius: 6
                Label { text: "First name" x: 10 y: 5 width: (root.table_w - 48) / 4 height: 18 color: #F8FAFC font_size: 11 bold: true }
                Label { text: "Last name" x: 10 + (root.table_w - 48) / 4 y: 5 width: (root.table_w - 48) / 4 height: 18 color: #F8FAFC font_size: 11 bold: true }
                Label { text: "Age" x: 10 + 2 * ((root.table_w - 48) / 4) y: 5 width: (root.table_w - 48) / 4 height: 18 color: #F8FAFC font_size: 11 bold: true }
                Label { text: "Country" x: 10 + 3 * ((root.table_w - 48) / 4) y: 5 width: (root.table_w - 48) / 4 height: 18 color: #F8FAFC font_size: 11 bold: true }
            }

            Scroll {
                id: user_rows
                x: 14
                y: 46
                width: root.table_w - 28
                height: card.height - 222
                background: #FFFFFF

                Repeater {
                    model: app.users
                    key: item.key

                    Rectangle {
                        x: 0
                        y: index * 30
                        width: root.table_w - 44
                        height: 29
                        background: item.stripe

                        Label { text: item.first_name x: 10 y: 6 width: (root.table_w - 64) / 4 height: 18 color: #0F172A font_size: 12 }
                        Label { text: item.last_name x: 10 + (root.table_w - 64) / 4 y: 6 width: (root.table_w - 64) / 4 height: 18 color: #0F172A font_size: 12 }
                        Label { text: item.age x: 10 + 2 * ((root.table_w - 64) / 4) y: 6 width: (root.table_w - 64) / 4 height: 18 color: #0F172A font_size: 12 }
                        Label { text: item.country x: 10 + 3 * ((root.table_w - 64) / 4) y: 6 width: (root.table_w - 64) / 4 height: 18 color: #475569 font_size: 12 }
                    }
                }
            }

            Image { id: users_logo source: app.logo_path x: root.table_w - 74 y: card.height - 164 width: 56 height: 56 }
            Label { id: users_status text: app.status x: 14 y: card.height - 158 width: root.table_w - 100 height: 20 color: app.is_error ? #991B1B : #166534 font_size: 12 }
        }
    }
}
