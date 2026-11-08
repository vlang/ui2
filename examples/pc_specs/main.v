module main

import os
import runtime
import time
import ui2

const pc_specs_width = 720
const pc_specs_height = 480
const pc_specs_vml_source = $embed_file('pc_specs.vml').to_string()

pub struct SpecRow {
pub:
	label string
	value string
pub mut:
	index int
}

pub struct PcSpecsDemo {
pub mut:
	rows   []SpecRow
	status string = 'Basic details about this machine.'
}

fn format_gigabytes(bytes u64) string {
	return '${f64(bytes) / (1024 * 1024 * 1024):.1f} GiB'
}

fn disk_path() string {
	$if windows {
		return 'C:\\'
	}
	return '/'
}

fn cpu_model() string {
	$if linux {
		content := os.read_file('/proc/cpuinfo') or { return 'Unknown' }
		for line in content.split_into_lines() {
			if line.starts_with('model name') && line.contains(':') {
				value := line.all_after_first(':').trim_space()
				if value.len > 0 {
					return value
				}
			}
		}
		return 'Unknown'
	}
	$if macos {
		return os.exec_opt(['sysctl', '-n', 'machdep.cpu.brand_string']) or {
			return 'Unknown'
		}.output.trim_space()
	}
	$if windows {
		return os.exec_opt(['powershell', '-NoProfile', '-Command',
			'(Get-CimInstance Win32_Processor).Name']) or {
			return 'Unknown'
		}.output.trim_space()
	}
	$if freebsd || netbsd || dragonfly || openbsd {
		return os.exec_opt(['sysctl', '-n', 'hw.model']) or {
			return 'Unknown'
		}.output.trim_space()
	}
	$if solaris {
		// kstat reports the CPU brand; the value follows the key and a tab.
		out := os.exec_opt(['kstat', '-p', 'cpu_info:0:cpu_info0:brand']) or {
			return 'Unknown'
		}
		fields := out.output.trim_space().split('\t')
		if fields.len > 1 {
			model := fields[1].trim_space()
			if model.len > 0 {
				return model
			}
		}
		return 'Unknown'
	}
	return 'Unknown'
}

fn total_memory() u64 {
	$if linux {
		content := os.read_file('/proc/meminfo') or { return 0 }
		for line in content.split_into_lines() {
			if line.starts_with('MemTotal:') {
				amount := line.all_after(':').trim_space().split(' ')[0]
				return amount.u64() * 1024
			}
		}
		return 0
	}
	$if macos {
		return os.exec_opt(['sysctl', '-n', 'hw.memsize']) or { return 0 }.output.trim_space().u64()
	}
	$if windows {
		return os.exec_opt(['powershell', '-NoProfile', '-Command',
			'(Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory']) or {
			return 0
		}.output.trim_space().u64()
	}
	$if freebsd || netbsd || dragonfly || openbsd {
		return os.exec_opt(['sysctl', '-n', 'hw.physmem']) or { return 0 }.output.trim_space().u64()
	}
	$if solaris {
		// system_pages:physmem counts pages; the page size turns them into bytes.
		out := os.exec_opt(['kstat', '-p', 'unix:0:system_pages:physmem']) or {
			return 0
		}
		fields := out.output.trim_space().split('\t')
		if fields.len > 1 {
			return fields[1].trim_space().u64() * u64(os.page_size())
		}
		return 0
	}
	return 0
}

// os_description names the distribution: illumos says it in /etc/release,
// Linux in /etc/os-release's PRETTY_NAME. The plain user_os falls back.
fn os_description() string {
	$if solaris {
		if lines := os.read_lines('/etc/release') {
			for line in lines {
				name := line.trim_space()
				if name.len > 0 {
					return name
				}
			}
		}
	}
	$if linux {
		if lines := os.read_lines('/etc/os-release') {
			for line in lines {
				if line.starts_with('PRETTY_NAME=') {
					name := line.all_after('=').trim_string_left('"').trim_string_right('"').trim_space()
					if name.len > 0 {
						return name
					}
				}
			}
		}
	}
	return os.user_os()
}

fn collect_rows() []SpecRow {
	uname := os.uname()
	memory := total_memory()
	path := disk_path()
	mut rows := [
		SpecRow{ label: 'Hostname', value: uname.nodename },
		SpecRow{ label: 'Operating system', value: os_description() },
		SpecRow{ label: 'Kernel', value: '${uname.sysname} ${uname.release}' },
		SpecRow{ label: 'Architecture', value: uname.machine },
		SpecRow{ label: 'CPU', value: cpu_model() },
		SpecRow{ label: 'Logical cores', value: runtime.nr_jobs().str() },
		SpecRow{
			label: 'Total memory'
			value: if memory > 0 { format_gigabytes(memory) } else { 'Unknown' }
		},
	]
	if usage := os.disk_usage(path) {
		rows << SpecRow{
			label: 'Disk ${path}'
			value: '${format_gigabytes(usage.available)} free of ${format_gigabytes(usage.total)}'
		}
	}
	for index in 0 .. rows.len {
		rows[index].index = index
	}
	return rows
}

pub fn (mut app PcSpecsDemo) refresh() {
	app.rows = collect_rows()
	app.status = 'Specs refreshed at ${time.now().format_ss()}.'
}

fn main() {
	mut app := PcSpecsDemo{
		rows: collect_rows()
	}
	// The bottom label carries the refresh date from the launch on: the model
	// is built here, so the stamp matches the rows it belongs to.
	app.status = 'Specs refreshed at ${time.now().format_ss()}.'
	ui2.run_vml[PcSpecsDemo](
		source: pc_specs_vml_source
		model:  app
		title:  'PC Specs'
		width:  pc_specs_width
		height: pc_specs_height
	) or { panic(err) }
}
