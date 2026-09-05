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

        Label { text: "Expression calculator" x: 18 y: 14 width: card.width - 36 height: 28 color: #111827 font_size: 18 bold: true }
        Label { text: "Enter arithmetic with parentheses, decimals, and + − × ÷." x: 18 y: 42 width: card.width - 36 height: 20 color: #64748B font_size: 12 }

        TextField { id: expression bind.text: app.expression on_submit: app.evaluate() x: 18 y: 76 width: card.width - 148 height: 40 background: #F8FAFC corner_radius: 7 font_family: "Courier New" font_size: 14 }
        Button { id: evaluate text: "Evaluate" on_tap: app.evaluate() native: true x: card.width - 118 y: 79 width: 100 height: 34 }

        Rectangle { x: 18 y: 132 width: card.width - 36 height: 88 background: app.has_error ? #FEE2E2 : #DCFCE7 corner_radius: 8
            Label { text: "Result" x: 14 y: 10 width: card.width - 64 height: 18 align: center color: app.has_error ? #991B1B : #166534 font_size: 11 }
            Label { id: result text: app.result x: 14 y: 31 width: card.width - 64 height: 40 align: center color: app.has_error ? #991B1B : #14532D font_family: "Courier New" font_size: 24 bold: true }
        }

        Label { text: "Examples" x: 18 y: 236 width: 80 height: 20 color: #475569 font_size: 11 }
        Button { text: "33.3 ÷ 4 − 3" on_tap: app.load_example(0) native: true x: 92 y: 230 width: (card.width - 130) / 3 height: 34 }
        Button { text: "3 + 22 ÷ 2" on_tap: app.load_example(1) native: true x: 100 + (card.width - 130) / 3 y: 230 width: (card.width - 130) / 3 height: 34 }
        Button { text: "Nested" on_tap: app.load_example(2) native: true x: 108 + (card.width - 130) * 0.66 y: 230 width: (card.width - 130) / 3 height: 34 }

        Label { id: calculation_status text: app.status x: 18 y: card.height - 38 width: card.width - 36 height: 18 align: center color: app.has_error ? #B91C1C : #166534 font_size: 11 }
    }
}
