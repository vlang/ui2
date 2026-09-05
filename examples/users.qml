Screen {
    background: #F1F5F9

    Label {
        id: form-title
        text: "Add user"
        x: 16
        y: 8
        width: __FORM_WIDTH__
        height: 26
        font_size: 18
        bold: true
    }

    TextField {
        id: first-name
        text: __FIRST_NAME__
        placeholder: "First name"
        on_change: first-name
        x: 16
        y: 40
        width: __FORM_WIDTH__
        height: 32
        background: __INPUT_BACKGROUND__
        corner_radius: 6
    }

    TextField {
        id: last-name
        text: __LAST_NAME__
        placeholder: "Last name"
        on_change: last-name
        x: 16
        y: 80
        width: __FORM_WIDTH__
        height: 32
        background: __INPUT_BACKGROUND__
        corner_radius: 6
    }

    TextField {
        id: age
        text: __AGE__
        placeholder: "Age"
        on_change: age
        keyboard: decimal
        x: 16
        y: 120
        width: __FORM_WIDTH__
        height: 32
        background: __INPUT_BACKGROUND__
        corner_radius: 6
    }

    TextField {
        id: password
        text: __PASSWORD__
        placeholder: "Password"
        on_change: password
        secure: true
        x: 16
        y: 160
        width: __FORM_WIDTH__
        height: 32
        background: #FFFFFF
        corner_radius: 6
    }

    Checkbox {
        id: online-registration
        text: "Online registration"
        checked: __ONLINE_CHECKED__
        on_tap: online-registration
        x: 16
        y: 201
        width: __FORM_WIDTH__
        height: 30
        font_size: 13
    }

    Checkbox {
        id: subscribe
        text: "Subscribe to the newsletter"
        checked: __SUBSCRIBE_CHECKED__
        on_tap: subscribe
        x: 16
        y: 239
        width: __FORM_WIDTH__
        height: 30
        font_size: 13
    }

    Label {
        id: country-label
        text: "Country"
        x: 16
        y: 276
        width: __FORM_WIDTH__
        height: 18
        color: #475569
        font_size: 12
    }

    Dropdown {
        id: country
        text: __COUNTRY__
        on_change: country
        x: 16
        y: 296
        width: __FORM_WIDTH__
        height: 32
        background: #FFFFFF
        corner_radius: 6

        Option { text: "United States" }
        Option { text: "Canada" }
        Option { text: "United Kingdom" }
        Option { text: "Australia" }
    }

    Button {
        id: add-user
        text: "Add user"
        on_tap: add-user
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
        id: help
        text: "?"
        on_tap: help
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
        id: progress-track
        x: 16
        y: 371
        width: 170
        height: 16
        background: #D8DEE8
        corner_radius: 8

        Rectangle {
            id: progress-fill
            x: 0
            y: 0
            width: __PROGRESS_WIDTH__
            height: 16
            background: #3478D4
            corner_radius: 8
        }
    }

    Label {
        id: progress-label
        text: "__USER_COUNT__/__MAXIMUM_USERS__"
        x: 192
        y: 368
        width: __PROGRESS_LABEL_WIDTH__
        height: 22
        font_size: 13
    }

    Scroll {
        id: users-table
        x: __TABLE_LEFT__
        y: __TABLE_TOP__
        width: __TABLE_WIDTH__
        height: __TABLE_HEIGHT__
        background: #FFFFFF
        persistent: true

        Rectangle {
            id: table-header
            x: 0
            y: 0
            width: __TABLE_WIDTH__
            height: 32
            background: #334155

            Label {
                id: header-first
                text: "First name"
                x: __TABLE_FIRST_X__
                y: 0
                width: __TABLE_FIRST_WIDTH__
                height: 32
                color: #FFFFFF
                font_size: 13
                bold: true
            }

            Label {
                id: header-last
                text: "Last name"
                x: __TABLE_LAST_X__
                y: 0
                width: __TABLE_LAST_WIDTH__
                height: 32
                color: #FFFFFF
                font_size: 13
                bold: true
            }

            Label {
                id: header-age
                text: "Age"
                x: __TABLE_AGE_X__
                y: 0
                width: __TABLE_AGE_WIDTH__
                height: 32
                color: #FFFFFF
                font_size: 13
                bold: true
            }

            Label {
                id: header-country
                text: "Country"
                x: __TABLE_COUNTRY_X__
                y: 0
                width: __TABLE_COUNTRY_WIDTH__
                height: 32
                color: #FFFFFF
                font_size: 13
                bold: true
            }
        }

        __USER_ROWS__
    }

    Rectangle {
        id: logo-tile
        hidden: __LOGO_HIDDEN__
        x: __LOGO_X__
        y: 304
        width: 92
        height: 84
        background: #536B99
        corner_radius: 12

        Label {
            id: logo-letter
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
        id: validation-error
        hidden: __VALIDATION_HIDDEN__
        text: "First name, last name and age are required."
        x: __VALIDATION_LEFT__
        y: __VALIDATION_TOP__
        width: __VALIDATION_WIDTH__
        height: 24
        color: #B42318
        font_size: 13
    }

    Rectangle {
        id: help-panel
        hidden: __HELP_HIDDEN__
        x: __HELP_LEFT__
        y: 118
        width: 320
        height: 145
        background: #FFFFFF
        corner_radius: 10

        Label {
            id: help-title
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
            id: help-copy
            text: "Built with V, ui2 QML, and native controls."
            x: 20
            y: 52
            width: 280
            height: 24
            font_size: 14
            align: center
        }

        Button {
            id: close-help
            text: "Close"
            on_tap: close-help
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
