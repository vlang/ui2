# OpenUI Lang: generative UI in ui2

OpenUI Lang support lets a language model describe a UI as plain text and lets
`ui2` render that text straight to `ui2.Element`. The model never writes frame
math, style structs, or V code: it emits semantic statements, and the app's
component library decides how they look.

The pipeline is:

```
component library + tool definitions
        -> generate_system_prompt() -> LLM
        -> streamed OpenUI Lang text -> OpenuiRenderer
        -> Element tree -> ui2.run_window()
```

The renderer emits `Element` values directly, so the generated UI uses the same
event loop, state, styling, and native/custom backends as any other ui2 app.
There is no VML string in the middle and no web view.

This feature tracks [issue #122](https://github.com/vlang/ui2/issues/122) and
follows the [OpenUI Lang 1.0 specification](https://www.openui.com/docs/openui-lang/overview).

## Setup

### Requirements

- A recent V. ui2's CI builds V from source rather than using the 0.5.2 release
  binaries (see `.github/workflows/ci.yml`), so do the same unless a newer
  release is available:

  ```sh
  git clone --depth 1 https://github.com/vlang/v
  cd v
  make                 # macOS / Linux; on Windows: .\makev.bat
  ```

  Put the resulting `v` directory on your `PATH` and confirm `v version`.

- The ui2 checkout itself. From your projects directory (in a fresh shell, or
  after leaving the `v` directory), clone it and link the checkout into V's
  module directory so `import ui2` resolves to it:

  ```sh
  git clone https://github.com/vlang/ui2.git
  ln -s "$(pwd)/ui2" ~/.vmodules/ui2
  ```

  On Windows the equivalent is a directory junction or symlink; the exact
  command depends on whether developer mode is enabled. Check the resolved path
  before running the examples: a different `ui2` checkout earlier in the module
  search path makes the new API appear to be missing.

- On Linux and the BSDs, the X11/OpenGL/audio development packages used by the
  custom renderer, for example on Debian/Ubuntu:

  ```sh
  sudo apt-get install -y libx11-dev libxcursor-dev libxi-dev \
      libgl1-mesa-dev libasound2-dev xvfb
  ```

  A graphical session is needed to actually open a window; the tests build and
  run headlessly.

### Run the bundled examples

From the repository root (or from an app that has ui2 on its module path):

```sh
v run examples/openui_demo       # generated UI from a fixed response
v run examples/openui_custom     # extending the library with your own component
```

The demos use fixed response text, so they need no API key and no network. The
test suites are headless and are the fastest way to check your setup:

```sh
v test ui/openui_test.v
v test ui/openui_findings_test.v
v test examples/openui_demo
v test examples/openui_custom
```

## Quickstart

The smallest complete app registers tools, sets a response, and wires the
renderer into `run_window`:

```v okfmt
module main

import ui2

const response = 'root = Stack([heading, count, go])\n' +
	'heading = TextContent("Support tickets", "large-heavy")\n' +
	'count = TextContent("Open: " + @Count(open))\n' +
	'go = Button("Show all", @Set($filter, \"shut\"))\n' +
	'$filter = \"open\"\n' +
	'tickets = Query(\"list_tickets\", {}, {rows: []})\n' +
	'open = @Filter(tickets.rows, \"status\", \"==\", $filter)'

fn list_tickets(_ map[string]ui2.OpenuiValue) ui2.OpenuiValue {
	return ui2.openui_object({
		'rows': ui2.openui_list([
			ui2.openui_object({
				'title':  ui2.openui_string('Login fails')
				'status': ui2.openui_string('open')
			}),
			ui2.openui_object({
				'title':  ui2.openui_string('Dark mode')
				'status': ui2.openui_string('shut')
			}),
		])
	})
}

fn on_action(event ui2.OpenuiActionEvent) {
	println('assistant: ${event.message} (${event.kind})')
}

fn main() {
	mut renderer := ui2.new_openui_renderer(ui2.new_openui_default_library())
	// The root width comes from the renderer, not from run_window. Keep it
	// equal to the window width or long content is clipped.
	renderer.width = 640
	renderer.set_tool('list_tickets', list_tickets)
	renderer.on_action = on_action
	renderer.set_response(response, false) // false = final, non-streaming text
	ui2.run_window('OpenUI quickstart', 640, 480,
		fn [mut renderer] () ui2.Element {
			return renderer.root_element()
		},
		fn [mut renderer] (id string) {
			if renderer.handle_event(id) {
				ui2.refresh()
			}
		})
}
```

Three rules in that example matter everywhere:

1. Set `renderer.width` to the width passed to `run_window`.
2. Call `ui2.refresh()` only when `handle_event(id)` returns `true`.
3. Tools are ordinary V functions registered by name; OpenUI Lang refers to
   them by that name in `Query(...)` and `Mutation(...)`.

## The response language

A response is a sequence of `identifier = Expression` lines, one per line.
Names begin with a letter or `_`; `$name` declares or reads a state variable.
The `root` statement names the node to display. Statements may refer forward to
statements defined later, and a repeated name uses its last definition.

```text
// $ variables hold editable state and default values
$filter = "open"
// data comes from a host tool
data = Query("list_tickets", {}, {rows: []})
open = @Filter(data.rows, "status", "==", $filter)
// node statements build the tree; root is the entry point
root = Stack([heading, count])
heading = TextContent("Open tickets", "large-heavy")
count = TextContent("Count: " + @Count(open))
```

Blank lines and `//` comments are ignored. Undefined names are errors, not
silent text. Nesting limit is 256 while parsing and 512 while evaluating; a
flat chain of operators is bounded too, so untrusted model output cannot
exhaust the stack.

### Literals and operators

| Kind | Examples |
| --- | --- |
| String | `"text"`, `'text'`; escapes `\n`, `\t`, `\\`, `\"`, `\'` |
| Number | `12`, `-4`, `1.5` (stored as `f64`; `.5` is not valid) |
| Boolean / null | `true`, `false`, `null` |
| List | `[1, 2, 3]`, `[]` |
| Object | `{title: "Login fails", status: "open"}` |

Operators, from lowest to highest precedence: `? :`, `||`, `&&`, `==`/`!=`,
`<`/`<=`/`>`/`>=`, `+`/`-`, `*`/`/`/`%`, unary `!`/`-`, then `.` member access.
`+` concatenates when either operand is a string. `&&`, `||`, and `?:` are
short-circuiting. Division or modulo by zero reports `runtime-error`.

Member access reads an object field, or performs list *pluck*: `rows.title`
returns one value per object in `rows` (`null` where the field is missing).
`.len` is the item count of a list or the rune count of a string. There is no
index operator; use `@First`, `@Last`, `@Each`, or plucking instead.

### Built-in functions

Functions are prefixed with `@`. Components, `Action(...)`, `Query(...)`, and
`Mutation(...)` are bare calls and must *not* be prefixed with `@`.

| Function | Meaning |
| --- | --- |
| `@Count(list)` | Number of items |
| `@Sum(list)` | Sum of numeric items |
| `@Avg(list)` | Average of numeric items, or `null` when empty |
| `@Min(list)`, `@Max(list)` | Numeric extremes, or `null` |
| `@First(list)`, `@Last(list)` | End items, or `null` |
| `@Filter(list, "field", op, value)` | Keep items where `field op value` holds |
| `@Sort(list, "field", "asc"\|"desc")` | Sort by the field's string value |
| `@Round(n\|list, decimals?)`, `@Abs`, `@Floor`, `@Ceil` | Math, element-wise on lists |
| `@Each(list, "item", template)` | Evaluate `template` once per item |

`@Filter` accepts `==`, `!=`, `>`, `<`, `>=`, `<=`, and `contains`. `@Round`
clamps decimals to `0..15`. In `@Each`, the loop variable is a bare name or a
quoted string, not a `$variable`:

```text
items = ["Login fails", "Dark mode"]
root = Stack([list])
list = @Each(items, "t", TextContent(t))
```

### Components and child slots

Component calls are positional: arguments map to the component's parameters in
declaration order. `null` uses the default of an optional parameter; passing
`null` to a required one is an error. A node value can be used where a list of
children is expected as a one-element shorthand.

The default library (root component `Stack`) contains:

| Component | Signature |
| --- | --- |
| `Stack` | `Stack(children: Component[])` — transparent vertical container |
| `Card` | `Card(children: Component[])` — white rounded card |
| `TextContent` | `TextContent(text: string, style?: string)` — `small`, `large`, `heavy`/`bold` |
| `Button` | `Button(label: string, action?: ActionExpression)` |
| `Input` | `Input(value: $var, placeholder?: string, on_change?: ActionExpression)` |
| `Select` | `Select(value: $var, options: string[], on_select?: ActionExpression)` |
| `Table` | `Table(rows: any[], columns?: string[])` — columns inferred from object keys |
| `Chart` | `Chart(type: "bar"\|"line"\|"pie"\|"doughnut", labels: string[], values: number[], title?: string, series?: string)` |

`Table` caps display at 20 rows and 32 columns with a truncation footer.
`Chart` uses the first 1000 points. A `bind` parameter such as `Input.value`
requires a literal `$variable`; edits write back to that variable.

### Actions and state

An action is an ordered list of steps, written as a bare `Action([...])` call.
Step functions use `@`:

| Step | Effect |
| --- | --- |
| `@Set($var, value)` | Write state; later steps in the same action see the new value |
| `@Reset($a, $b, ...)` | Restore response defaults and clear the edit mark |
| `@Run(query_or_mutation)` | Refetch a `Query` or execute a `Mutation` |
| `@ToAssistant(message, context?)` | Emit a `continue_conversation` action event |
| `@OpenUrl(url)` | Emit an `open_url` action event |

```text
$q = "a"
root = Stack([go, back])
go = Button("Go", Action([@Set($q, "b"), @ToAssistant($q)]))
back = Button("Back", @Reset($q))
```

`on_action` receives an `OpenuiActionEvent` with `kind`, `message`, `params`,
and `form_state` (a snapshot of all `$variables`). A failed mutation stops the
remaining steps and reports an error.

### Data: tools, Query and Mutation

`Query` and `Mutation` are top-level statements only; nesting one inside an
expression reports `inline-reserved`.

```text
data = Query("list_tickets", {status: $filter}, {rows: []})
m = Mutation("close_ticket", {id: $selected})
```

- `Query(name, args, defaults, refresh?)` runs on load and when a `$variable`
  used in `args` changes. Results are memoized by tool name and effective
  arguments, so re-renders do not repeat tool calls.
- `Mutation(name, args)` evaluates to `{status: "idle"}`; it runs only when an
  action contains `@Run(m)`. An explicit `@Run` refetches even a cached query.
- Unknown tools report `tool-not-found`; a `Query` then uses its defaults.

A tool is a plain V function returning `OpenuiValue`. Build values with
`openui_string`, `openui_number`, `openui_bool`, `openui_null`, `openui_list`,
`openui_object`, and `openui_action`; read them with `string_value()`,
`truthy()`, and `numeric() !f64`.

### Stored message markers

Responses stored in chat history can carry section markers. They are not part
of the program and are stripped before parsing:

```text
]]>openui:content
root = Stack([hello])
hello = TextContent("Hello")
]]>openui:context
{"locale": "en"}
]]>openui:end
```

`parse_openui_stored(raw) OpenuiStoredMessage` returns `content`, `context`,
`finished`, and `has_stream`. `strip_openui_markers(raw) string` returns just the
program text; the renderer calls it for you. Among several content sections the
last non-empty one wins.

## Streaming

Pass model chunks as they arrive, then pass the final text with `streaming`
set to `false`:

```v okfmt
renderer.set_response(chunk_so_far, true) // while tokens are arriving
renderer.set_response(full_response, false) // final text; errors are strict
```

Each `set_response` only stores text; call `render()` or `root_element()` again
to rebuild while handling `ui2.refresh()`. While streaming:

- the renderer re-parses the whole response every time, so forward references
  resolve as their statements arrive;
- a chunk that ends inside a string or call replays the last program that
  parsed successfully instead of blanking the UI;
- `on_error` is suppressed, so partial text is not reported as an error. The
  final response is checked strictly.

`render()` never fails. It returns `(Element, OpenuiRenderInfo)`; inspect
`info.errors` and `info.orphaned` (statement names not reachable from the root)
in tests, or set `renderer.on_error`.

## Building a custom library

Start from the default library and add your own components, or create an empty
one with `new_openui_library(root: 'Stack', components: [...])`. Registration
replaces a component with the same name; `remove(name)` deletes one;
`extend(config)` returns a new library with additions, overrides, and removals
without mutating the original.

A component supplies semantic props and a render callback. The renderer passes
a `Rect` frame, pre-rendered children, and an id, so authors never compute
layout:

```v okfmt
fn render_badge(ctx ui2.OpenuiCtx) ui2.Element {
	return ui2.label(ctx.id, '★ ' + ctx.string_prop('text'), ctx.frame, ui2.TextStyle{
		bold:  true
		color: 0xb45309
	})
}

fn my_library() ui2.OpenuiLibrary {
	mut lib := ui2.new_openui_default_library()
	lib.register(ui2.OpenuiComponent{
		name:        'Badge'
		description: 'A small star-prefixed badge line.'
		params:      [
			ui2.OpenuiParam{
				name:   'text'
				schema: ui2.openui_string_schema()
			},
		]
		render:      render_badge
	})
	return lib
}
```

`OpenuiCtx` provides `id`, `props`, `children`, `frame`, and the helpers
`string_prop(name)`, `number_prop(name, fallback)`, `bool_prop(name)`,
`list_prop(name)`, `text_style()`, and `box_style()`. Schemas are built with
`openui_string_schema`, `openui_number_schema`, `openui_bool_schema`,
`openui_schema_enum`, `openui_list_schema`, `openui_node_schema`,
`openui_action_schema`, `openui_bind_schema`, `openui_any_schema`, and
`openui_optional(schema, default_value)`.

Custom functions (`set_function`) and custom actions (`library.actions`) use
the same schema types. Register a function to make `@Name(...)` available to
the model; declare an action to give `@Name(...)` a validated payload that
reaches `on_action`.

## Generating the system prompt

`generate_system_prompt(library, options)` is pure V: no network, no model.
It emits syntax rules, component signatures, built-ins, actions, data and state
sections, and your examples. Feed the returned string to your LLM client as the
system message.

```v okfmt
prompt := ui2.generate_system_prompt(lib, ui2.OpenuiPromptOptions{
	preamble:         'You output only OpenUI Lang.'
	tools:            ['list_tickets', 'close_ticket']
	examples:         ['root = Stack([n])\nn = TextContent("Hello")']
	additional_rules: ['Never mention frames or colors.']
})
```

`OpenuiPromptOptions` also has `tool_calls` and `bindings` (both default
`true`), `builtin_functions`, `edit_mode`, and `inline_mode`. Group components
with `library.groups` to present them to the model in sections; ungrouped
components are always included as well. `openui_library_spec(library)` returns
just the component signatures when you need a shorter prefix.

## Error codes

Errors returned by `render()` (and passed to `on_error`) carry `code`, `message`,
and `statement`:

| Code | Meaning |
| --- | --- |
| `unknown-component` | Component name is not in the library |
| `missing-required` / `null-required` | Required argument omitted or `null` |
| `type-mismatch` | Wrong argument type, bad bind, or bad built-in arguments |
| `excess-args` | More positional arguments than parameters |
| `unknown-function` | `@name` is neither a built-in nor registered |
| `unknown-reference` | Undefined statement name |
| `inline-reserved` | `Query`/`Mutation` used outside top level |
| `no-root` | No `root` statement; a fallback entry was used |
| `parse-failed` | Tokenizer or parser failure |
| `runtime-error` | Bad arithmetic, cycle, depth or render budget exceeded |
| `tool-not-found` | `Query`/`Mutation` names an unregistered tool |

## Renderer API at a glance

| Symbol | Purpose |
| --- | --- |
| `new_openui_renderer(library)` | Construct a renderer with default settings |
| `set_response(text, streaming)` | Store the current response text |
| `render() (Element, OpenuiRenderInfo)` | Build a tree and report errors/orphans |
| `root_element() Element` | Build callback for `run_window` |
| `handle_event(id) bool` | Dispatch a control action; true means handled |
| `set_tool(name, fn)` / `set_function(name, fn)` | Register host callbacks |
| `on_action` / `on_error` | Action and error callbacks |
| `width`, `state`, `response`, `streaming`, `live_text` | Public renderer fields |

## Scope and limitations

This first version includes synchronous `Query`/`Mutation` tools and hosts
re-render after an asynchronous fetch. The renderer emits `Element` directly;
there is no `editMode`/`inlineMode` renderer path yet. Predefined adapters
cover the Tier-1 components above; charts/forms/dialogs adapters, an async
tool re-fetch helper, and Gateway/autofix notes are follow-ups.

See also:

- [the demo](../../examples/openui_demo/main.v)
- [the custom component example](../../examples/openui_custom/main.v)
- [the unit tests](../../ui/openui_test.v)
- [tracking issue #122](https://github.com/vlang/ui2/issues/122)
- [OpenUI Lang specification](https://www.openui.com/docs/openui-lang/specification)