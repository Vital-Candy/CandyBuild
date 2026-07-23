# Native C++ (games / JNI)

`candybuild new` can scaffold a `cpp/` folder with a JNI bridge
(`stringFromJNI()`) wired into `MainActivity`. This is a starting point
for game/engine code, not a game engine itself — CandyBuild does not
provide a game loop, `SurfaceView`, or `GameActivity`. You write that on
top of this.

## Setup

```
pkg install clang ndk-sysroot
```

`install.sh` does this for you automatically. `ndk-sysroot` merges the
Android NDK's headers into `$PREFIX/include` and libs into `$PREFIX/lib`
— it doesn't create a separate folder, it becomes part of Termux's own
`clang++` search path. `candybuild doctor` checks for it via
`$PREFIX/include/android/log.h`, a file that package installs.

Once it's installed, `compiler/native.sh` compiles with
`clang++ -target aarch64-linux-android<api> ...` (no extra `--sysroot`
needed — that's already covered by the merge above), where `<api>` comes
from your project's `min_sdk`.

If you have a full Android NDK instead (`ANDROID_NDK_HOME` pointing at
one), CandyBuild prefers that and uses its own per-ABI `clang++` wrapper.

## What gets built

- One shared library per project: `lib<native_lib_name>.so`
  (`native_lib_name` in `Candy.toml`, default `native`).
- Only for the ABI matching the device you're building on (`arm64-v8a`
  on virtually all modern phones) — CandyBuild builds *on* the device
  you're building *for*. There's no cross-ABI build here; if you need
  multiple ABIs for a Play Store upload, you'd need a device/emulator
  per ABI, which is out of scope for this tool.
- Skipped entirely if the project has no `cpp/*.cpp` files — existing
  projects are unaffected.

## If `System.loadLibrary()` fails at runtime with a linker error

This usually means your `.so` depends on a shared C++ runtime
(`libc++_shared.so`) that isn't reachable from your app's own process —
Termux's own copy lives under Termux's private data directory, which a
different app can't read. Two ways around it:

- Link the C++ runtime statically instead of dynamically, so the `.so`
  has no external runtime dependency, or
- Copy the matching `libc++_shared.so` into your project's own `libs/<abi>/`
  so it gets packaged into your APK and found there instead.

If you hit this, tell me which one and I'll wire the right flag into
`compiler/native.sh` — the correct flag can depend on your clang/NDK
version, so it's worth confirming on your actual build first rather than
guessing here.

## Known limitations

- No CMake, no `Android.mk` — just every `.cpp` under `cpp/` compiled
  and linked into one `.so`. Multiple libraries or subfolders with their
  own build config aren't supported; keep it flat.
- JNI function name mangling assumes an underscore-free package name.
  An underscore in your package/class name needs manual `_1` escaping
  per the JNI spec.
