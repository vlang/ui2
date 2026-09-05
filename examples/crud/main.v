module main

import ui2

const crud_width = 620
const crud_height = 390
const crud_qml_source = $embed_file('crud.qml').to_string()

pub struct CrudPerson {
pub:
	id      int
	name    string
	surname string
	display string
}

pub struct CrudDemo {
pub mut:
	filter         string
	name           string
	surname        string
	message        string = 'Select a person or create a new one.'
	people         []CrudPerson
	visible_people []CrudPerson
	selected_id    int = -1
	next_id        int = 7
}

fn crud_person(id int, name string, surname string) CrudPerson {
	return CrudPerson{
		id: id
		name: name
		surname: surname
		display: '${surname}, ${name}'
	}
}

fn initial_crud() CrudDemo {
	people := [
		crud_person(1, 'Iron', 'Man'),
		crud_person(2, 'Bat', 'Man'),
		crud_person(3, 'James', 'Bond'),
		crud_person(4, 'Super', 'Man'),
		crud_person(5, 'Cat', 'Woman'),
		crud_person(6, 'Wonder', 'Woman'),
	]
	return CrudDemo{
		people: people
		visible_people: people.clone()
	}
}

fn (mut app CrudDemo) refresh_visible_people() {
	prefix := app.filter.trim_space().to_lower()
	if prefix.len == 0 {
		app.visible_people = app.people.clone()
		return
	}
	app.visible_people = app.people.filter(it.display.to_lower().starts_with(prefix))
}

pub fn (mut app CrudDemo) filter_changed() {
	app.refresh_visible_people()
}

pub fn (mut app CrudDemo) select_person(id int) {
	for person in app.people {
		if person.id == id {
			app.selected_id = id
			app.name = person.name
			app.surname = person.surname
			app.message = 'Selected ${person.display}.'
			return
		}
	}
}

pub fn (mut app CrudDemo) create_person() {
	name := app.name.trim_space()
	surname := app.surname.trim_space()
	if name.len == 0 || surname.len == 0 {
		app.message = 'Name and surname are required.'
		return
	}
	for person in app.people {
		if person.name.to_lower() == name.to_lower()
			&& person.surname.to_lower() == surname.to_lower() {
			app.message = '${surname}, ${name} already exists.'
			return
		}
	}
	person := crud_person(app.next_id, name, surname)
	app.people << person
	app.next_id++
	app.selected_id = person.id
	app.message = 'Created ${person.display}.'
	app.refresh_visible_people()
}

pub fn (mut app CrudDemo) update_person() {
	if app.selected_id < 0 {
		app.message = 'Select a person to update.'
		return
	}
	name := app.name.trim_space()
	surname := app.surname.trim_space()
	if name.len == 0 || surname.len == 0 {
		app.message = 'Name and surname are required.'
		return
	}
	for index, person in app.people {
		if person.id == app.selected_id {
			app.people[index] = crud_person(person.id, name, surname)
			app.message = 'Updated ${surname}, ${name}.'
			app.refresh_visible_people()
			return
		}
	}
}

pub fn (mut app CrudDemo) delete_person() {
	if app.selected_id < 0 {
		app.message = 'Select a person to delete.'
		return
	}
	id := app.selected_id
	app.people = app.people.filter(it.id != id)
	app.selected_id = -1
	app.name = ''
	app.surname = ''
	app.message = 'Deleted the selected person.'
	app.refresh_visible_people()
}

fn main() {
	ui2.run_qml[CrudDemo](
		source: crud_qml_source
		model: initial_crud()
		title: 'CRUD'
		width: crud_width
		height: crud_height
	) or { panic(err) }
}
