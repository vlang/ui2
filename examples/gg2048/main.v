module main

import ui2

const game_2048_width = 600
const game_2048_height = 680
const game_2048_qml_source = $embed_file('gg2048.qml').to_string()

pub struct GameCell {
pub:
	id     int
	key    string
	row    int
	column int
}

pub struct GameTile {
pub:
	id         int
	key        string
	row        int
	column     int
	value      int
	color      string
	text_color string
}

pub struct Game2048 {
pub:
	cells []GameCell
pub mut:
	board  []int
	tiles  []GameTile
	score  int
	moves  int
	status string = 'Use the arrow buttons to combine matching tiles.'
}

fn game_cells() []GameCell {
	mut cells := []GameCell{cap: 16}
	for row in 0 .. 4 {
		for column in 0 .. 4 {
			cells << GameCell{
				id: row * 4 + column
				key: 'cell-${row * 4 + column}'
				row: row
				column: column
			}
		}
	}
	return cells
}

fn initial_2048() Game2048 {
	mut app := Game2048{
		cells: game_cells()
		board: [2, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
	}
	app.update_tiles()
	return app
}

fn merge_2048_line(values []int) ([]int, int) {
	mut compact := []int{cap: 4}
	for value in values {
		if value != 0 {
			compact << value
		}
	}
	mut merged := []int{cap: 4}
	mut gained := 0
	mut index := 0
	for index < compact.len {
		if index + 1 < compact.len && compact[index] == compact[index + 1] {
			value := compact[index] * 2
			merged << value
			gained += value
			index += 2
		} else {
			merged << compact[index]
			index++
		}
	}
	for merged.len < 4 {
		merged << 0
	}
	return merged, gained
}

fn game_line_indexes(direction string, line int) []int {
	return match direction {
		'left' { [line * 4, line * 4 + 1, line * 4 + 2, line * 4 + 3] }
		'right' { [line * 4 + 3, line * 4 + 2, line * 4 + 1, line * 4] }
		'up' { [line, line + 4, line + 8, line + 12] }
		else { [line + 12, line + 8, line + 4, line] }
	}
}

fn tile_colors(value int) (string, string) {
	return match value {
		2 { '#EEE4DA', '#3F3A36' }
		4 { '#EDE0C8', '#3F3A36' }
		8 { '#F2B179', '#FFFFFF' }
		16 { '#F59563', '#FFFFFF' }
		32 { '#F67C5F', '#FFFFFF' }
		64 { '#F65E3B', '#FFFFFF' }
		128 { '#EDCF72', '#FFFFFF' }
		256 { '#EDCC61', '#FFFFFF' }
		512 { '#EDC850', '#FFFFFF' }
		1024 { '#EDC53F', '#FFFFFF' }
		else { '#EDC22E', '#FFFFFF' }
	}
}

fn (mut app Game2048) update_tiles() {
	mut tiles := []GameTile{}
	for index, value in app.board {
		if value == 0 {
			continue
		}
		color, text_color := tile_colors(value)
		tiles << GameTile{
			id: index
			key: 'tile-${index}'
			row: index / 4
			column: index % 4
			value: value
			color: color
			text_color: text_color
		}
	}
	app.tiles = tiles
}

fn (mut app Game2048) add_tile() {
	for index, value in app.board {
		if value == 0 {
			app.board[index] = if app.moves % 5 == 0 { 4 } else { 2 }
			return
		}
	}
}

fn (mut app Game2048) move(direction string) {
	before := app.board.clone()
	mut gained := 0
	for line in 0 .. 4 {
		indexes := game_line_indexes(direction, line)
		values := indexes.map(app.board[it])
		merged, line_score := merge_2048_line(values)
		gained += line_score
		for offset, board_index in indexes {
			app.board[board_index] = merged[offset]
		}
	}
	if app.board == before {
		app.status = 'No tiles moved.'
		return
	}
	app.moves++
	app.score += gained
	app.add_tile()
	app.update_tiles()
	app.status = 'Move ${app.moves} · score ${app.score}'
}

pub fn (mut app Game2048) move_left() {
	app.move('left')
}

pub fn (mut app Game2048) move_right() {
	app.move('right')
}

pub fn (mut app Game2048) move_up() {
	app.move('up')
}

pub fn (mut app Game2048) move_down() {
	app.move('down')
}

pub fn (mut app Game2048) new_game() {
	app.board = [2, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
	app.score = 0
	app.moves = 0
	app.status = 'New game started.'
	app.update_tiles()
}

fn main() {
	ui2.run_qml[Game2048](
		source: game_2048_qml_source
		model: initial_2048()
		title: '2048'
		width: game_2048_width
		height: game_2048_height
	) or {
		panic(err)
	}
}
