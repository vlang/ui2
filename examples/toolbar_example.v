import ui
import ui/toolbar_statusbar

fn main() {
	// Setup basic styles
	style_btn := ui.TextStyle{
		size: 13.0
		color: 0x333333
	}
	box_btn := ui.BoxStyle{
		transparent: true
	}
	style_status := ui.TextStyle{
		size: 12.0
		color: 0x666666
	}

	// Application layout
	app := ui.screen(0xffffff, [
		// Toolbar at the top
		toolbar('main_toolbar', ui.rect(0, 0, 600, 40), [
			ui.button('btn_new', 'New', ui.rect(5, 5, 60, 30), box_btn, style_btn),
			ui.button('btn_open', 'Open', ui.rect(70, 5, 60, 30), box_btn, style_btn),
			ui.button('btn_save', 'Save', ui.rect(135, 5, 60, 30), box_btn, style_btn),
		]),

		// Main Content Area
		ui.view('content', ui.rect(0, 40, 600, 320), ui.BoxStyle{transparent: true}, [
			ui.label('lbl_welcome', 'Welcome to UI2 Editor', ui.rect(20, 20, 200, 20), ui.TextStyle{
				size: 18.0
				bold: true
			}),
			ui.text_area('editor', 'Type something here...', ui.rect(20, 50, 560, 250), ui.BoxStyle{
				border_color: 0xcccccc
				border_left: 1.0
				border_top: 1.0
				border_right: 1.0
				border_bottom: 1.0
			}, style_btn),
		]),

		// Statusbar at the bottom
		statusbar('main_status', ui.rect(0, 360, 600, 25), [
			ui.label('status_text', 'Ready', ui.rect(5, 0, 200, 25), style_status),
		]),
	])

	// Start the application (assuming a standard ui2 runner exists)
	// ui.run(app) 
}
