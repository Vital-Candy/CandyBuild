# Native C++ (games / JNI)

`candybuild new` can scaffold a `cpp/` folder with a JNI bridge
(`stringFromJNI()`) wired into `MainActivity`. This is a starting point
for game/engine code, not a game engine itself — CandyBuild does not
provide a game loop, `SurfaceView`, or `GameActivity`. You write that on
top of this.

## Why you need `ndk-sysroot` (or a full NDK), not just `clang`

Termux's own `clang` compiles binaries that link against **Termux's own
libc** (`$PREFIX/lib`). A `.so` built that way loads fine inside Termux,
but **will not load inside a normal Android app process** — the app uses
the system's Bionic libc, a different, incompatible environment.
`System.loadLibrary()` on such a `.so` fails with a linker error at
runtime, after a build that reported success — the exact "looks fine,
crashes on the device" trap this project tries to avoid elsewhere.

To produce a real Android `.so`, install one of:

```
pkg install clang ndk-sysroot
```

or point `ANDROID_NDK_HOME` at a full Android NDK if you have one
installed. `candybuild doctor` reports which one (if either) it found.

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

## Known limitations

- No CMake, no `Android.mk` — just every `.cpp` under `cpp/` compiled
  and linked into one `.so`. Multiple libraries or subfolders with their
  own build config aren't supported; keep it flat.
- No STL beyond what `-llog` needs; if you use `std::` containers
  heavily you may need `-static-libstdc++` or similar — add flags to
  `compiler/native.sh` directly if so.
- JNI function name mangling assumes an underscore-free package name.
  An underscore in your package/class name needs manual `_1` escaping
  per the JNI spec.
