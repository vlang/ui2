module ui2

import os

// VmlDocument is the parsed file-level wrapper around a VML root. File-backed
// documents may declare one module name and import sibling modules before the
// root element.
struct VmlDocument {
	module_name string
	imports     []string
	root        &VNode = unsafe { nil }
}

// parse_document recognizes the optional module declaration and imports that
// precede a VML document's single root node. It lives beside the file importer
// so ordinary string-backed parse_vml keeps its existing parser contract.
fn (mut p Parser) parse_document() !VmlDocument {
	mut module_name := ''
	mut imports := []string{}
	for p.at().kind == .ident && (p.at().val == 'module' || p.at().val == 'import') {
		directive := p.eat(.ident)!
		name := p.eat(.ident)!
		if directive.val == 'module' {
			if module_name.len > 0 {
				return error('duplicate module declaration at line ${directive.line}')
			}
			module_name = name.val
		} else {
			if name.val in imports {
				return error('duplicate VML import `${name.val}` at line ${directive.line}')
			}
			imports << name.val
		}
	}
	root := p.parse_node()!
	p.eat(.eof)!
	return VmlDocument{
		module_name: module_name
		imports: imports
		root: root
	}
}

// parse_vml_file parses a VML document and expands its imports. An import maps
// a module name to a sibling .vml file; CamelCase names use snake_case file
// names, so `import PrimaryScreen` loads `primary_screen.vml`. A module file
// must start with the matching `module PrimaryScreen` declaration.
pub fn parse_vml_file(path string) !&VNode {
	mut stack := []string{}
	mut node := parse_vml_file_with_stack(path, '', mut stack)!
	assign_vml_paths(mut node, '0')
	return node
}

fn parse_vml_file_with_stack(path string, expected_module string, mut stack []string) !&VNode {
	file_path := os.abs_path(path)
	if file_path in stack {
		mut cycle := stack.clone()
		cycle << file_path
		return error('cyclic VML import: ${cycle.join(' -> ')}')
	}
	source := os.read_file(file_path) or {
		return error('could not read VML file `${file_path}`: ${err}')
	}
	tokens := tokenize(source) or {
		return error('could not parse VML file `${file_path}`: ${err}')
	}
	mut parser := Parser{
		tokens: tokens
	}
	document := parser.parse_document() or {
		return error('could not parse VML file `${file_path}`: ${err}')
	}
	if expected_module.len > 0 && document.module_name != expected_module {
		return error('VML import `${expected_module}` requires `${file_path}` to declare `module ${expected_module}`')
	}
	mut next_stack := stack.clone()
	next_stack << file_path
	mut components := map[string]&VNode{}
	for import_name in document.imports {
		import_path := vml_import_path(os.dir(file_path), import_name)!
		components[import_name] = parse_vml_file_with_stack(import_path, import_name, mut next_stack)!
	}
	mut root := document.root
	expand_vml_imports(mut root, components)!
	return root
}

fn vml_import_path(directory string, module_name string) !string {
	mut candidates := [os.join_path(directory, '${module_name}.vml')]
	snake_name := vml_module_file_name(module_name)
	if snake_name != module_name {
		candidates << os.join_path(directory, '${snake_name}.vml')
	}
	for candidate in candidates {
		if os.is_file(candidate) {
			return candidate
		}
	}
	return error('could not find VML import `${module_name}` (looked for ${candidates.join(', ')})')
}

fn vml_module_file_name(module_name string) string {
	mut out := ''
	for index, character in module_name {
		character_text := [u8(character)].bytestr()
		if character >= `A` && character <= `Z` {
			if index > 0 {
				out += '_'
			}
			out += character_text.to_lower()
		} else if character == `.` {
			out += os.path_separator
		} else {
			out += character_text
		}
	}
	return out
}

fn expand_vml_imports(mut node VNode, components map[string]&VNode) ! {
	mut children := []&VNode{cap: node.children.len}
	for child in node.children {
		if component := components[child.tag] {
			mut replacement := clone_vml_import_node(component)
			for key, value in child.props {
				replacement.props[key] = value
				if expression := child.expressions[key] {
					replacement.expressions[key] = expression
				}
			}
			if child.id.len > 0 {
				replacement.id = child.id
			}
			for passed_child in child.children {
				replacement.children << clone_vml_import_node(passed_child)
			}
			expand_vml_imports(mut replacement, components)!
			children << replacement
		} else {
			mut expanded := clone_vml_import_node(child)
			expand_vml_imports(mut expanded, components)!
			children << expanded
		}
	}
	node.children = children
}

fn clone_vml_import_node(node &VNode) &VNode {
	mut children := []&VNode{cap: node.children.len}
	for child in node.children {
		children << clone_vml_import_node(child)
	}
	return &VNode{
		tag: node.tag
		id: node.id
		props: node.props.clone()
		children: children
		expressions: node.expressions.clone()
		property_types: node.property_types.clone()
		property_order: node.property_order.clone()
		line: node.line
		path: node.path
	}
}

// element_from_vml_file is the file-backed counterpart to element_from_vml.
pub fn element_from_vml_file(path string, frame Rect) !Element {
	node := parse_vml_file(path)!
	return node_to_element(node, frame)!
}

// element_from_vml_model_file evaluates a file-backed VML document, including
// any modules imported relative to that file.
pub fn element_from_vml_model_file[T](path string, model T, frame Rect) !Element {
	template := parse_vml_file(path)!
	v_validate_template[T](template, model)!
	resolved, _ := v_evaluate_template(template, model, frame)!
	element := element_from_vnode(resolved, frame)!
	validate_element_tree(element)!
	return element
}

// new_vml_app_file creates an embeddable VML application from a file. Unlike
// new_vml_app, it can resolve imports declared by that document.
pub fn new_vml_app_file[T](path string, model T) !&VmlApp[T] {
	template := parse_vml_file(path)!
	v_validate_template[T](template, model)!
	probe := rect(0, 0, 1024, 768)
	resolved, _ := v_evaluate_template(template, model, probe)!
	validate_element_tree(element_from_vnode(resolved, probe)!)!
	return &VmlApp[T]{
		template: template
		model: model
	}
}

// VmlFileRunConfig is the file-backed counterpart to VmlRunConfig. Keeping the
// path-based entry point separate lets run_vml retain its existing source-only
// config while imports get a stable directory for relative resolution.
pub struct VmlFileRunConfig[T] {
pub:
	source_path string
	model       T
	title       string = 'App'
	width       int = 400
	height      int = 800
}

// run_vml_file owns one typed model for a file-backed VML window and resolves
// imports relative to source_path before validation and rendering.
pub fn run_vml_file[T](config VmlFileRunConfig[T]) ! {
	template := parse_vml_file(config.source_path)!
	v_validate_template[T](template, config.model)!
	initial_frame := rect(0, 0, f64(config.width), f64(config.height))
	resolved, events := v_evaluate_template(template, config.model, initial_frame)!
	validate_element_tree(element_from_vnode(resolved, initial_frame)!)!
	mut controller := &VmlController[T]{
		template: template
		model: config.model
		events: events
	}
	mut runtime := vml_runtime()
	runtime.controller = voidptr(controller)
	$if macos || windows || linux {
		run_window(config.title, config.width, config.height, vml_controller_build[T],
			vml_controller_handle[T])
	} $else {
		run(vml_controller_build[T], vml_controller_handle[T])
	}
}
