# Getting an Android platform jar (android.jar)

CandyBuild never touches Gradle or Android Studio, but it still needs
one file from an official Android SDK: `android.jar` for whatever API
level your project targets. This was previously a silent requirement —
`candybuild doctor` now checks for it explicitly.

## Option 1 — you already have an SDK somewhere

If you (or a PC you use) already have an Android SDK installed, copy
`platforms/android-<API>/android.jar` from that SDK onto your device,
then point CandyBuild at the folder that contains it:

```
export ANDROID_HOME=/path/to/that/folder
```

Add that line to `~/.bashrc` so it persists.

## Option 2 — install just the command-line tools in Termux

Google's official "Command line tools" package includes `sdkmanager`,
which can fetch individual platform jars without installing the rest of
Android Studio. Download it from the official page
(developer.android.com/studio → "Command line tools only"), unpack it
in Termux, then run something like:

```
sdkmanager --sdk_root="$HOME/.candybuild/sdk" "platforms;android-34"
export ANDROID_HOME="$HOME/.candybuild/sdk"
```

## Checking it worked

Run:

```
candybuild doctor
```

It will report whether an `android.jar` can currently be found, and for
which path — this is the single check that used to be missing, and the
most common reason builds failed for new users.
