#!/usr/bin/env python3
"""Run the Android JNI bridge on a mock JVM using real NDK JNI declarations.

Usage: python3 tests/platform_android/run.py /path/to/android-ndk
Or set ANDROID_NDK_HOME / ANDROID_NDK_ROOT. Requires a host C compiler.
"""
import os
from pathlib import Path
import subprocess
import sys
import tempfile

ndk = Path(sys.argv[1] if len(sys.argv) > 1 else
           os.environ.get("ANDROID_NDK_HOME", os.environ.get("ANDROID_NDK_ROOT", "")))
headers = list(ndk.glob("toolchains/llvm/prebuilt/*/sysroot/usr/include/jni.h"))
if not headers:
    sys.exit("Pass an Android NDK directory or set ANDROID_NDK_HOME.")
with tempfile.TemporaryDirectory(prefix="ui2-platform-jni-") as directory:
    root = Path(directory)
    (root / "android").mkdir()
    # Only the fields used by the bridge are needed in this host-only fixture.
    # Production is separately compiled against the NDK's ANativeActivity.
    (root / "android/native_activity.h").write_text(
        "#include <jni.h>\n#include <stdint.h>\n"
        "typedef struct { JavaVM *vm; jobject clazz; int32_t sdkVersion; } ANativeActivity;\n")
    binary = root / "test"
    subprocess.run([os.environ.get("CC", "cc"), "-std=c11", "-Wall", "-Wextra", "-Werror",
                    "-g", "-fsanitize=address,undefined", "-fno-omit-frame-pointer",
                    "-I", str(root), "-idirafter", str(headers[0].parent),
                    str(Path(__file__).with_name("main.c")), "-o", str(binary)], check=True)
    subprocess.run([str(binary)], check=True)
