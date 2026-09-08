# QML build benchmark

This benchmark compares steady-state tree construction through a parsed,
typed `QmlApp` with the direct `ui2.Element` code emitted by `$qml`. The runtime
baseline parses `form.qml` once before timing, matching `run_qml`; parsing time
is not included in either measurement.

From the UI2 repository root, using a v3 compiler that contains `$qml` support:

```sh
/path/to/vnew -nocache -prod \
    -path "$(dirname "$PWD")|@vlib|@vmodules" \
    -o /tmp/ui2-qml-build-bench benchmarks/qml_build/main.v
/tmp/ui2-qml-build-bench
```

On an Apple M5 Max (arm64 macOS), seven runs of 10,000 builds produced a median
paired speedup of **31.15x**. The independent median totals were 1,198.299 ms
for runtime QML and 38.755 ms for compiled QML, or about 119.8 µs versus 3.9 µs
per tree build.
