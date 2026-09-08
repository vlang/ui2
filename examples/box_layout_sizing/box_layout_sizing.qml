Screen {
    id: root
    background: #F1F5F9

    Label {
        text: "Fixed and proportional sizing"
        x: 20
        y: 18
        width: root.width - 40
        height: 30
        color: #0F172A
        font_size: 20
        bold: true
    }

    BoxLayout {
        id: actions
        x: 20
        y: 68
        width: root.width - 40
        height: 96
        padding: 10
        spacing: 8
        background: #FFFFFF
        corner_radius: 10

        Button { text: "Fixed" width: 88 size_hint_x: -1 background: #E2E8F0 corner_radius: 6 }
        Button { text: "2 shares" size_hint_x: 2 background: #BFDBFE corner_radius: 6 }
        Button { text: "1 share" size_hint_x: 1 background: #DBEAFE corner_radius: 6 }
    }
}
