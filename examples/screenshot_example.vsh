#!/usr/bin/env -S v

// Renders one example with the custom renderer and writes a single frame to a
// PNG. It drives gg's own recorder rather than a desktop screenshot utility,
// so it needs neither a screen recording permission nor a human at the
// keyboard, and it captures exactly the window, without any surrounding
// desktop.
//
//   v run examples/screenshot_example.vsh message
//   v run examples/screenshot_example.vsh message --frame 30 --out /tmp/shots
//
// Extra arguments are passed through to the compiler, e.g.
//   v run examples/screenshot_example.vsh message -d my_flag

import os

const vexe = os.quoted_path(@VEXE)

fn usage() {
	eprintln('usage: v run examples/screenshot_example.vsh <example> [--frame N] [--out DIR] [extra v flags]')
}

fn arg_value(name string, index int) string {
	if index >= args.len {
		usage()
		eprintln('${name} needs a value')
		exit(1)
	}
	return args[index]
}

mut example := ''
// The first frames still have the window sizing itself, so wait for a settled
// one before reading the framebuffer.
mut frame := u64(5)
mut out_dir := join_path(temp_dir(), 'ui2-screenshots')
mut extra_flags := []string{}

mut i := 1
for i < args.len {
	arg := args[i]
	match arg {
		'--frame' {
			i++
			frame = arg_value('--frame', i).u64()
		}
		'--out' {
			i++
			out_dir = arg_value('--out', i)
		}
		'-h', '--help' {
			usage()
			exit(0)
		}
		else {
			if example == '' && !arg.starts_with('-') {
				example = arg
			} else {
				extra_flags << arg
			}
		}
	}
	i++
}

if example == '' {
	usage()
	exit(1)
}

example_dir := join_path(@VMODROOT, 'examples', example)
if !exists(join_path(example_dir, 'main.v')) {
	eprintln('no example named `${example}` in ${join_path(@VMODROOT, 'examples')}')
	exit(1)
}

mkdir_all(out_dir)!

build_dir := join_path(temp_dir(), 'ui2-screenshot-build')
mkdir_all(build_dir)!
defer {
	rmdir_all(build_dir) or {}
}

exe := join_path(build_dir, example + $if windows { '.exe' } $else { '' })

// gg_record adds the recorder to the frame callback; the custom renderer is
// what the recorder can read, since the native backends draw with the platform
// toolkit instead of gg.
mut flags := ['-d ui2_custom_rendering', '-d gg_record']
$if macos {
	// The recorder reads the presented framebuffer back, which only the GL
	// backend implements, so keep macOS off its default Metal backend.
	flags << '-d darwin_sokol_glcore33'
}

build_cmd := '${vexe} ${flags.join(' ')} ${extra_flags.join(' ')} -o ${quoted_path(exe)} ${quoted_path(example_dir)}'
println('building: ${build_cmd}')
build := execute(build_cmd)
if build.exit_code != 0 {
	eprintln(build.output)
	eprintln('failed to build ${example}')
	exit(1)
}

// The recorder names its files after the executable, and quits the app once it
// has passed the last requested frame.
recorded := join_path(out_dir, '${example}_${frame}.png')
rm(recorded) or {}
setenv('VGG_SCREENSHOT_OUTPUT', 'file', true)
setenv('VGG_SCREENSHOT_FOLDER', out_dir, true)
setenv('VGG_SCREENSHOT_FRAMES', frame.str(), true)
setenv('VGG_STOP_AT_FRAME', (frame + 1).str(), true)

run := execute(quoted_path(exe))
if run.exit_code != 0 {
	eprintln(run.output)
	eprintln('${example} exited with ${run.exit_code} before frame ${frame}')
	exit(1)
}

if !exists(recorded) {
	eprintln(run.output)
	eprintln('${example} never recorded frame ${frame}')
	exit(1)
}

screenshot := join_path(out_dir, '${example}.png')
mv(recorded, screenshot)!
println('wrote ${screenshot}')
