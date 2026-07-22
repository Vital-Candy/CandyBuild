# Dependencies (Maven) & Jetpack Compose

## Declaring a dependency

In a project's `Candy.toml`, add one `dependency` line per artifact:

```
dependency="androidx.compose.material:material:1.6.7"
dependency="androidx.activity:activity-compose:1.9.0"
```

`candybuild build` resolves these (and their transitive dependencies) from
Maven Central at build time, caches everything under
`~/.candybuild/cache/maven`, and merges classes + resources into the
build automatically. This step needs network access and `curl`/`unzip`
(installed by `install.sh`).

## Jetpack Compose

`candybuild new` offers `ui=compose` for Kotlin projects. This requires
**Kotlin 2.0 or newer**, because the Compose compiler plugin is fetched
to match your installed `kotlinc` version exactly
(`org.jetbrains.kotlin:kotlin-compose-compiler-plugin-embeddable`). If
`kotlinc -version` reports 1.x, the build stops with a clear error
instead of silently producing broken output.

## Known limitations of the resolver (`lib/maven.sh`)

This is a small dependency-fetcher, not a Maven/Gradle reimplementation:

- **No parent-POM inheritance.** Properties or dependencies declared in a
  library's `<parent>` POM are not seen.
- **No `<dependencyManagement>` / BOM imports.** Version alignment via a
  BOM (e.g. the Compose BOM) won't work — pin versions explicitly.
- **No version ranges** (`[1.0,2.0)`).
- **"First seen wins"** on version conflicts between transitive
  dependencies, not real nearest-wins/highest-wins resolution. If two
  libraries need different versions of the same artifact, pin the one
  you want directly as a `dependency` line in `Candy.toml` — direct
  dependencies are resolved first.
- **No manifest merging.** If a library's AAR needs manifest entries
  (permissions, providers, services), add them to your own
  `AndroidManifest.xml` by hand.

If a build fails with "could not resolve version" or "could not fetch
POM", the fastest fix is almost always to add the missing artifact as an
explicit `dependency` line with a known-good version.
