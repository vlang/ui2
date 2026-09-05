Screen {
    id: root
    background: #F1F5F9

    property bool compact: root.width < 700
    property f64 form_width: root.compact ? root.width - 32 : 210
    property f64 table_left: root.compact ? 16 : 244
    property f64 table_top: root.compact ? 414 : 16
    property f64 table_width: root.compact ? root.form_width : root.width - 260
    property f64 table_height: root.compact && root.height - root.table_top - 16 > 220 ? root.height - root.table_top - 16 : 270
    property f64 first_width: root.table_width * 0.23
    property f64 last_width: root.table_width * 0.23
    property f64 age_width: root.table_width * 0.12
    property f64 country_width: root.table_width - root.first_width - root.last_width - root.age_width

    Label {
        text: "Add user"
        x: 16
        y: 8
        width: root.form_width
        height: 26
        font_size: 18
        bold: true
    }

    TextField {
        id: first_name
        bind.text: app.first_name
        on_change: app.clear_error()
        placeholder: "First name"
        x: 16
        y: 40
        width: root.form_width
        height: 32
        background: app.is_error ? #FFEEEE : #FFFFFF
        corner_radius: 6
    }

    TextField {
        bind.text: app.last_name
        on_change: app.clear_error()
        placeholder: "Last name"
        x: 16
        y: 80
        width: root.form_width
        height: 32
        background: app.is_error ? #FFEEEE : #FFFFFF
        corner_radius: 6
    }

    TextField {
        bind.text: app.age
        on_change: app.clear_error()
        placeholder: "Age"
        keyboard: decimal
        x: 16
        y: 120
        width: root.form_width
        height: 32
        background: app.is_error ? #FFEEEE : #FFFFFF
        corner_radius: 6
    }

    TextField {
        bind.text: app.password
        placeholder: "Password"
        secure: true
        x: 16
        y: 160
        width: root.form_width
        height: 32
        background: #FFFFFF
        corner_radius: 6
    }

    Checkbox {
        text: "Online registration"
        bind.checked: app.online_registration
        x: 16
        y: 201
        width: root.form_width
        height: 30
        font_size: 13
    }

    Checkbox {
        text: "Subscribe to the newsletter"
        bind.checked: app.subscribe
        x: 16
        y: 239
        width: root.form_width
        height: 30
        font_size: 13
    }

    Label {
        text: "Country"
        x: 16
        y: 276
        width: root.form_width
        height: 18
        color: #475569
        font_size: 12
    }

    Dropdown {
        bind.text: app.country
        x: 16
        y: 296
        width: root.form_width
        height: 32
        background: #FFFFFF
        corner_radius: 6

        Option { text: "United States" }
        Option { text: "Canada" }
        Option { text: "United Kingdom" }
        Option { text: "Australia" }
    }

    Button {
        text: "Add user"
        enabled: app.users.len < app.max_users
        on_tap: app.add_user()
        x: 16
        y: 337
        width: 140
        height: 32
        background: #3478D4
        color: #FFFFFF
        corner_radius: 6
        bold: true
        align: center
    }

    Button {
        text: "?"
        on_tap: app.open_help()
        tooltip: "About this example"
        x: 178
        y: 337
        width: 48
        height: 32
        background: #E2E8F0
        corner_radius: 16
        bold: true
        align: center
    }

    Rectangle {
        x: 16
        y: 371
        width: 170
        height: 16
        background: #D8DEE8
        corner_radius: 8

        Rectangle {
            x: 0
            y: 0
            width: 170 * app.users.len / app.max_users
            height: 16
            background: #3478D4
            corner_radius: 8
        }
    }

    Label {
        text: "${app.users.len}/${app.max_users}"
        x: 192
        y: 368
        width: root.form_width - 176
        height: 22
        font_size: 13
    }

    Scroll {
        id: users_table
        x: root.table_left
        y: root.table_top
        width: root.table_width
        height: root.table_height
        background: #FFFFFF
        persistent: true

        Rectangle {
            x: 0
            y: 0
            width: root.table_width
            height: 32
            background: #334155

            Label {
                text: "First name"
                x: 7
                y: 0
                width: root.first_width - 14
                height: 32
                color: #FFFFFF
                font_size: 13
                bold: true
            }
            Label {
                text: "Last name"
                x: root.first_width + 7
                y: 0
                width: root.last_width - 14
                height: 32
                color: #FFFFFF
                font_size: 13
                bold: true
            }
            Label {
                text: "Age"
                x: root.first_width + root.last_width + 7
                y: 0
                width: root.age_width - 14
                height: 32
                color: #FFFFFF
                font_size: 13
                bold: true
            }
            Label {
                text: "Country"
                x: root.first_width + root.last_width + root.age_width + 7
                y: 0
                width: root.country_width - 14
                height: 32
                color: #FFFFFF
                font_size: 13
                bold: true
            }
        }

        Repeater {
            model: app.users
            key: item.id

            Rectangle {
                x: 0
                y: 32 + index * 34
                width: root.table_width
                height: 32
                background: index % 2 == 0 ? #FFFFFF : #F1F5F9

                Label {
                    text: item.first_name
                    x: 7
                    y: 0
                    width: root.first_width - 14
                    height: 32
                    color: #1F2937
                    font_size: 13
                }
                Label {
                    text: item.last_name
                    x: root.first_width + 7
                    y: 0
                    width: root.last_width - 14
                    height: 32
                    color: #1F2937
                    font_size: 13
                }
                Label {
                    text: "${item.age}"
                    x: root.first_width + root.last_width + 7
                    y: 0
                    width: root.age_width - 14
                    height: 32
                    color: #1F2937
                    font_size: 13
                }
                Label {
                    text: item.country
                    x: root.first_width + root.last_width + root.age_width + 7
                    y: 0
                    width: root.country_width - 14
                    height: 32
                    color: #1F2937
                    font_size: 13
                }
            }
        }
    }

    Rectangle {
        hidden: root.compact
        x: root.table_left + root.table_width - 92
        y: 304
        width: 92
        height: 84
        background: #536B99
        corner_radius: 12

        Label {
            text: "V"
            x: 0
            y: 4
            width: 92
            height: 70
            color: #FFFFFF
            font_size: 52
            bold: true
            align: center
        }
    }

    Label {
        hidden: !app.is_error
        text: "First name, last name and age are required."
        x: root.compact ? 16 : root.table_left
        y: root.compact ? 390 : 302
        width: root.compact ? root.form_width : root.table_width - 112
        height: 24
        color: #B42318
        font_size: 13
    }

    Rectangle {
        hidden: !app.show_help
        x: root.width > 320 ? (root.width - 320) / 2 : 0
        y: 118
        width: 320
        height: 145
        background: #FFFFFF
        corner_radius: 10

        Label {
            text: "V UI Demo"
            x: 20
            y: 16
            width: 280
            height: 28
            font_size: 19
            bold: true
            align: center
        }
        Label {
            text: "Built with V, ui2 QML, and native controls."
            x: 20
            y: 52
            width: 280
            height: 24
            font_size: 14
            align: center
        }
        Button {
            text: "Close"
            on_tap: app.close_help()
            x: 100
            y: 94
            width: 120
            height: 34
            background: #3478D4
            color: #FFFFFF
            corner_radius: 6
            bold: true
            align: center
        }
    }
}
