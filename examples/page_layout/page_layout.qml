Screen {
    id: root
    background: #F1F5F9

    Label {
        text: "Paged content"
        x: 20
        y: 14
        width: root.width - 40
        height: 30
        color: #0F172A
        font_size: 20
        bold: true
    }

    PageLayout {
        id: pager
        x: 20
        y: 54
        width: root.width - 40
        height: 160
        page: app.page
        border: 24
        background: #CBD5E1
        corner_radius: 10

        Rectangle {
            background: #DBEAFE
            Label { text: "Page one" x: 24 y: 52 width: 240 height: 40 color: #1E3A8A font_size: 24 bold: true }
        }
        Rectangle {
            background: #DCFCE7
            Label { text: "Page two" x: 24 y: 52 width: 240 height: 40 color: #14532D font_size: 24 bold: true }
        }
        Rectangle {
            background: #FCE7F3
            Label { text: "Page three" x: 24 y: 52 width: 240 height: 40 color: #831843 font_size: 24 bold: true }
        }
    }

    Button { id: previous text: "Previous" on_tap: app.previous() x: 20 y: 226 width: 110 height: 38 }
    Label { text: "${app.page + 1} / 3" x: 160 y: 226 width: 100 height: 38 align: center color: #475569 }
    Button { id: next text: "Next" on_tap: app.next() x: root.width - 130 y: 226 width: 110 height: 38 }
}
