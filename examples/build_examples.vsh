#!/usr/bin/env -S v

// Compiles every example under examples/ and reports all failures at once.
// Extra arguments are passed through to the compiler, e.g.
//   v run examples/build_examples.vsh -d ui2_custom_rendering

import os

const vexe = os.quoted_path(@VEXE)

fn println_one_of_many(msg string, entry_idx int, entries_len int) {
	eprintln('${entry_idx + 1:2}/${entries_len:-2} ${msg}')
}

println('v executable: ${vexe}')
print('v version: ${execute('${vexe} version').output}')

extra_flags := args#[1..].join(' ')

examples_dir := join_path(@VMODROOT, 'examples')

build_dir := join_path(temp_dir(), 'ui2-examples-build')

mkdir_all(build_dir)!

defer {
	rmdir_all(build_dir) or {}
}

mut entries := []string{}

for entry in ls(examples_dir)! {
	dir := join_path(examples_dir, entry)
	if !is_dir(dir) {
		continue
	}
	if !exists(join_path(dir, 'main.v')) {
		eprintln('skipping ${dir}, it has no main.v')
		continue
	}
	entries << dir
}

entries.sort()

if entries.len == 0 {
	eprintln('no examples found in ${examples_dir}')
	exit(1)
}

mut failures := []string{}

for entry_idx, entry in entries {
	out := join_path(build_dir, file_name(entry) + $if windows { '.exe' } $else { '' })
	cmd := '${vexe} -N -W ${extra_flags} -o ${quoted_path(out)} ${quoted_path(entry)}'
	println_one_of_many('compile with: ${cmd}', entry_idx, entries.len)
	ret := execute(cmd)
	if ret.exit_code != 0 {
		failures << cmd
		eprintln('>>> FAILURE')
		eprintln('----------------------------------------------------------------------------------')
		eprintln(ret.output)
		eprintln('----------------------------------------------------------------------------------')
	}
}

if failures.len > 0 {
	for failure in failures {
		eprintln('> failed compilation cmd: ${failure}')
	}
	err_count := if failures.len == 1 { '1 error' } else { '${failures.len} errors' }
	eprintln('\nFailed with ${err_count}.')
	exit(1)
}

println('\nAll ${entries.len} examples compiled successfully.')
