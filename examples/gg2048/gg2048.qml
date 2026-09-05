Screen {
    id: root
    background: #FAF8EF

    property f64 board_size: root.width - 48 < 440 ? root.width - 48 : 440
    property f64 board_x: (root.width - root.board_size) / 2
    property f64 cell_size: (root.board_size - 50) / 4

    Label { text: "2048" x: root.board_x y: 18 width: 150 height: 50 color: #776E65 font_size: 36 bold: true }
    Rectangle { x: root.board_x + root.board_size - 150 y: 20 width: 150 height: 48 background: #BBADA0 corner_radius: 7
        Label { text: "SCORE" x: 8 y: 4 width: 134 height: 16 align: center color: #EEE4DA font_size: 10 bold: true }
        Label { id: score text: "${app.score}" x: 8 y: 19 width: 134 height: 24 align: center color: #FFFFFF font_size: 17 bold: true }
    }

    Rectangle {
        id: board
        x: root.board_x
        y: 82
        width: root.board_size
        height: root.board_size
        background: #BBADA0
        corner_radius: 10

        Repeater { model: app.cells key: item.key
            Rectangle { x: 10 + item.column * (root.cell_size + 10) y: 10 + item.row * (root.cell_size + 10) width: root.cell_size height: root.cell_size background: #CDC1B4 corner_radius: 7 }
        }
        Repeater { model: app.tiles key: item.key
            Rectangle { x: 10 + item.column * (root.cell_size + 10) y: 10 + item.row * (root.cell_size + 10) width: root.cell_size height: root.cell_size background: item.color corner_radius: 7
                Label { text: "${item.value}" x: 4 y: 0 width: root.cell_size - 8 height: root.cell_size align: center color: item.text_color font_size: item.value > 512 ? 18 : item.value > 64 ? 22 : 28 bold: true }
            }
        }
    }

    Button { id: move_up text: "↑" on_tap: app.move_up() native: true x: root.width / 2 - 42 y: 536 width: 84 height: 34 }
    Button { id: move_left text: "←" on_tap: app.move_left() native: true x: root.width / 2 - 132 y: 576 width: 84 height: 34 }
    Button { id: move_down text: "↓" on_tap: app.move_down() native: true x: root.width / 2 - 42 y: 576 width: 84 height: 34 }
    Button { id: move_right text: "→" on_tap: app.move_right() native: true x: root.width / 2 + 48 y: 576 width: 84 height: 34 }
    Button { id: new_game text: "New game" on_tap: app.new_game() native: true x: root.board_x + root.board_size - 110 y: 622 width: 110 height: 34 }
    Label { id: game_status text: app.status x: root.board_x y: 626 width: root.board_size - 126 height: 22 color: #776E65 font_size: 11 }
}
