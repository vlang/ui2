module main

import ui2

fn find_2048_element(element ui2.Element, id string) ?ui2.Element {
	if element.id == id {
		return element
	}
	for child in element.children {
		if found := find_2048_element(child, id) {
			return found
		}
	}
	return none
}

fn test_2048_merge_line_combines_each_pair_once() {
	values, score := merge_2048_line([2, 2, 2, 2])
	assert values == [4, 4, 0, 0]
	assert score == 8
	values2, score2 := merge_2048_line([4, 0, 4, 4])
	assert values2 == [8, 4, 0, 0]
	assert score2 == 8
}

fn test_2048_moves_board_adds_tile_and_resets() {
	mut app := initial_2048()
	app.board = [2, 2, 4, 4, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
	app.update_tiles()
	app.move_left()
	assert app.board[..4] == [4, 8, 2, 0]
	assert app.score == 12
	assert app.moves == 1
	app.new_game()
	assert app.score == 0
	assert app.tiles.len == 2
}

fn test_2048_qml_builds_responsive_board_and_native_controls() {
	app := initial_2048()
	root := ui2.element_from_qml_model(game_2048_qml_source, app, ui2.rect(0, 0, game_2048_width, game_2048_height)) or { panic(err) }
	ui2.validate_element_tree(root) or { panic(err) }
	board := find_2048_element(root, 'board') or { panic('missing board') }
	assert board.children.len == 18
	assert board.children[16].key == 'tile-0'
	assert board.children[17].key == 'tile-5'
	assert (find_2048_element(root, 'move_left') or { panic('missing left') }).native_style
	assert (find_2048_element(root, 'new_game') or { panic('missing new game') }).native_style
}
