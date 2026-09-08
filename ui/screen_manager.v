module ui2

pub struct ManagedScreen {
pub:
	name    string
	content Element
}

pub struct ScreenManagerConfig {
pub:
	id      string
	frame   Rect
	box     BoxStyle
	current string
	screens []ManagedScreen
}

fn screen_manager_validate(config ScreenManagerConfig) ! {
	if config.frame.width < 0 || config.frame.height < 0 {
		return error('screen manager dimensions cannot be negative')
	}
	mut names := map[string]bool{}
	for managed in config.screens {
		if managed.name.len == 0 {
			return error('managed screen names cannot be empty')
		}
		if managed.name in names {
			return error('duplicate managed screen name `${managed.name}`')
		}
		names[managed.name] = true
	}
}

// screen_manager_index returns the selected screen. An empty current name
// selects the first screen; a non-empty unknown name is an error.
pub fn screen_manager_index(config ScreenManagerConfig) !int {
	screen_manager_validate(config)!
	if config.screens.len == 0 || config.current.len == 0 {
		return 0
	}
	for index, managed in config.screens {
		if managed.name == config.current {
			return index
		}
	}
	return error('unknown managed screen `${config.current}`')
}

pub fn screen_manager_current(config ScreenManagerConfig) !string {
	if config.screens.len == 0 {
		screen_manager_validate(config)!
		return ''
	}
	return config.screens[screen_manager_index(config)!].name
}

pub fn screen_manager_next(config ScreenManagerConfig) !string {
	if config.screens.len == 0 {
		screen_manager_validate(config)!
		return ''
	}
	index := screen_manager_index(config)!
	return config.screens[(index + 1) % config.screens.len].name
}

pub fn screen_manager_previous(config ScreenManagerConfig) !string {
	if config.screens.len == 0 {
		screen_manager_validate(config)!
		return ''
	}
	index := screen_manager_index(config)!
	previous := if index == 0 { config.screens.len - 1 } else { index - 1 }
	return config.screens[previous].name
}

pub fn screen_manager(config ScreenManagerConfig) !Element {
	screen_manager_validate(config)!
	mut children := []Element{}
	if config.screens.len > 0 {
		index := screen_manager_index(config)!
		children << Element{
			...config.screens[index].content
			frame: rect(0, 0, config.frame.width, config.frame.height)
		}
	}
	return view(config.id, config.frame, config.box, children)
}
