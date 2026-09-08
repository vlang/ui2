# VML build benchmark

This benchmark compares steady-state tree construction through a parsed,
typed `VmlApp` with the direct `ui2.Element` code emitted by `$vml`. The runtime
baseline parses `form.vml` once before timing, matching `run_vml`; parsing time
is not included in either measurement.

From the UI2 repository root, using a v3 compiler that contains `$vml` support:

```sh
/path/to/vnew -nocache -prod \
    -path "$(dirname "$PWD")|@vlib|@vmodules" \
    -o /tmp/ui2-vml-build-bench benchmarks/vml_build/main.v
/tmp/ui2-vml-build-bench
```

On an Apple M5 Max (arm64 macOS), seven runs of 10,000 builds produced a median
paired speedup of **31.15x**. The independent median totals were 1,198.299 ms
for runtime VML and 38.755 ms for compiled VML, or about 119.8 µs versus 3.9 µs
per tree build.
