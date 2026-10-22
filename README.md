# title-prefetch

An mpv user script that resolves the titles of playlist entries
before they are played.

It writes the titles into the native `playlist/N/title` property,
so that any OSC or playlist UI benefits without knowing about this script,
[uosc](https://github.com/tomasklaen/uosc) for example.

The script only resolves titles.
It renders no UI, registers no key bindings
and prints no OSD output.

- For remote URLs, it uses the title that yt-dlp reports,
  which is what mpv's `ytdl_hook` uses as well.
- For local files, it uses the title from the file's metadata,
  as mpv itself would show it after loading the file.

By default, it resolves the 5 entries before
and the 5 entries after the current one,
nearest first.
Resolution follows `playlist-pos`.

## Requirements

mpv with [PR #18599](https://github.com/mpv-player/mpv/pull/18599),
which makes the property `playlist/N/title` writable.
That means a build from master once the PR is merged,
or the next release after v0.41.0.

On older builds,
the script logs one error
and disables itself for the session.

## Installation

Download `title-prefetch.zip`
from the [snapshot pre-release](https://github.com/FichteFoll/mpv-title-prefetch/releases/tag/snapshot),
which is rebuilt from `main` on every push,
or from a versioned release,
and extract it into the mpv config directory.
That is `~/.config/mpv/` on Linux and macOS,
and `%APPDATA%/mpv/` or `portable_config/` on Windows.
For example:

```
curl -L -o /tmp/title-prefetch.zip https://github.com/FichteFoll/mpv-title-prefetch/releases/download/snapshot/title-prefetch.zip && unzip -o /tmp/title-prefetch.zip -d ~/.config/mpv
```

The example config ships as `script-opts/title-prefetch.conf.example`,
so that extracting an update never overwrites an existing `title-prefetch.conf`.
To use it,
rename or copy it to `title-prefetch.conf`.

From a git checkout instead:

1. Copy or symlink the `title-prefetch/` directory
   into `~/.config/mpv/scripts/`.
   `mise run link` creates the symlink,
   honoring `MPV_HOME` and `XDG_CONFIG_HOME`.
2. Optionally, copy `title-prefetch.conf`
   into `~/.config/mpv/script-opts/`.

yt-dlp is optional.
It is required for remote URLs only,
and youtube-dl is not supported.
yt-dlp is found the way `ytdl_hook` finds it,
including its `ytdl_path` option.
`ytdl-raw-options` are honored,
so cookies and proxies apply.
Remote entries are only resolved while mpv's `ytdl` option is enabled,
and toggling it at runtime is picked up.
`ytdl_hook`'s own `exclude` and `try_ytdl_first` options are not mirrored.

## Options

Options are read from `script-opts/title-prefetch.conf`
and from `--script-opts=title-prefetch-<key>=<value>`.
Booleans accept `yes` and `no`.
Changes at runtime take effect immediately.

| key | default | meaning |
|---|---|---|
| `range` | `5` | entries before and after the current one; `-1` (any negative) = all, `0` = off |
| `resolve_remote` | `yes` | resolve `http(s)://` and `ytdl://` entries via yt-dlp |
| `resolve_local` | `yes` | resolve local files via an mpv probe |
| `cache_size` | `500` | maximum cached titles, FIFO; `0` = no cache, negative = unlimited |
| `cache_dir` | `~~cache/title-prefetch` | directory of the title cache, see below; empty = no cache |
| `concurrency` | `5` | maximum simultaneous subprocesses; a yt-dlp batch counts as one |
| `timeout` | `30` | seconds before a subprocess is aborted and counted as failed; a yt-dlp batch counts as one |
| `mpv_path` | `mpv` | executable used for the local probe |
| `ytdl_extractor_args` | `default` | yt-dlp `--extractor-args` for title lookups, whitespace-separated `IE_KEY:ARGS` entries; `default` = a built-in set that skips YouTube requests a title does not need, see `DEFAULT_EXTRACTOR_ARGS` in `lib/ytdl.lua`; empty = none |
| `ytdl_batch_size` | `5` | remote URLs resolved by one yt-dlp process, which saves its startup time; `1` (or less) = no batching |

A `ytdl_extractor_args` value containing commas
has to be given as `--script-opts-append=title-prefetch-ytdl_extractor_args=...`
or in brackets on the command line,
as in `--script-opts=title-prefetch-ytdl_extractor_args=[...]`,
because a plain `--script-opts=` splits at the comma.
The config file is not affected.
`default` can be combined with other entries,
for example `generic:impersonate default`.
An `extractor-args` entry in `ytdl-raw-options` for the same extractor
replaces the built-in one,
because yt-dlp keeps only the last `--extractor-args` per extractor.

## Commands

The script registers no key bindings
and offers a single script message:

| message | arguments | effect |
|---|---|---|
| `resolve-range` | `first` and optional `last`, 0-based indices | resolves the entries at `first` to `last` |

The indices are those of `playlist/N`, inclusive,
and `last` is clamped to the playlist.
A single argument requests one entry,
so `resolve-range 3` and `resolve-range 3 3` both request index 3, the fourth entry.
The message is intended for playlist UIs,
which send it for the entries scrolled into view.
It works independently of `range`, including `range=0`.
Requested entries are resolved before the window,
the latest request first,
and earlier requests are kept until their entries are resolved, fail or leave the playlist.
The indices are mapped to entries when the message arrives,
so a request follows its entries when the playlist is reordered.
The current entry is left to mpv,
but its cached title is written to untitled duplicates of it.

A display script sends it like this:

```lua
mp.commandv("script-message-to", "title_prefetch", "resolve-range", tostring(first), tostring(last))
```

`script-message-to` uses the script name `title_prefetch` with an underscore,
unlike the option prefix `title-prefetch`.

The `range` option can be changed at runtime,
which takes effect immediately.
So bindings in `input.conf` can widen the window,
for example:

```
Ctrl+t change-list script-opts append title-prefetch-range=20
Ctrl+T change-list script-opts append title-prefetch-range=-1
```

## Behavior

- Existing titles are never overwritten,
  whether they come from the playlist file,
  from `ytdl_hook`,
  from a previous playback
  or from the user.
- The current entry is left to mpv.
  Nothing is resolved until mpv has picked the entry to play,
  for example from `--playlist-start`, `--shuffle` or a watch-later resume.
  While mpv is idle with a playlist,
  the window is centered on the first entry,
  and that entry is resolved as well.
- Titles are cached on disk in `cache_dir`,
  one JSON file per entry,
  so they survive restarts
  and are shared by mpv instances running at the same time.
  `~~cache` is `~/.cache/mpv` on Linux.
  It does not resolve with `--no-config`,
  where the cache is disabled with a warning,
  as for any relative path.
- The cache holds up to `cache_size` titles, FIFO.
  Each instance enforces the limit on the entries it knows,
  so the directory can briefly exceed it
  while several instances run.
  The cache entry of a file is refreshed whenever it is played.
  A playback that yields no title drops the cached title
  and marks the file as failed.
- A failed resolution is not retried during the session,
  unless the entry is played,
  which refreshes it.
- Remote entries are resolved with `--ignore-no-formats-error`,
  so videos without playable formats still get their titles.
  This includes age-gated, members-only and geo-blocked videos,
  ended live streams and upcoming premieres.
  For private, removed and non-existent videos,
  yt-dlp only reports a generic `<extractor> video #<id>` title,
  which counts as no title.
- Remote entries are resolved in batches
  of up to `ytdl_batch_size` per yt-dlp process,
  in priority order.
  A failed URL fails only its own entry.
  On a timeout,
  entries whose results yt-dlp had already printed keep their titles,
  and the others count as failed.
- A yt-dlp candidate that cannot be started is not a failure.
  The entry is retried with the next candidate.
  If no candidate can be started,
  the script warns once
  and skips remote entries for the session,
  without marking them as failed.
- Local titles come from a headless `mpv` probe,
  so `mpv_path` must point to mpv.
  This reuses mpv's own demuxers and metadata rules.
  If `mpv_path` cannot be started,
  the script warns once
  and skips local files,
  without marking them as failed,
  until `mpv_path` changes.
- A local playlist file or archive gets no title and counts as failed,
  because mpv replaces it by its items when it is played,
  and the title of its first item is not its own.

## Logging

By default, the script only prints warnings and errors:

- an mpv build without writable `playlist/N/title`,
- an unusable `cache_dir`,
- a failed cache write,
- a probe or yt-dlp executable that cannot be started
  (mpv itself also prints `Subprocess failed: init` for each attempt),
- a subprocess that hits the `timeout`,
  listing every entry of the aborted process,
- an invalid `resolve-range` argument.

Individual resolution failures,
including yt-dlp's error messages,
are not shown by default.

`--msg-level=title_prefetch=v` adds one line per resolved entry,
with the title or the reason it failed,
and the cache directory in use.
At this level, mpv itself also logs the command line of every subprocess
under the script's prefix,
and `Subprocess failed: killed` for one that hits the `timeout`.

`--msg-level=title_prefetch=debug` adds the scheduling details:
`resolve-range` requests,
passes that do work,
started and dropped jobs,
cache evictions
and ignored cache files.

## Development

```
mise install
mise run build-mpv
mise run test
```

`mise run build-mpv` builds the mpv commit that contains PR #18599 into `.cache/mpv/`.
The tests need it,
plus `ffmpeg` for the fixtures.
`mise run test` accepts test names as arguments to run a subset.

`mise run lint` runs the LuaLS type check, `shellcheck`
and `actionlint` over `.github/workflows/`.
`types/` holds handwritten definitions of the parts of the mpv API that the code uses.

`mise.lock` is committed,
and CI installs the tools from it in locked mode.
After changing a tool in `mise.toml`,
run `mise lock`.

`mise run package` builds the release zip into `.cache/dist/title-prefetch.zip`,
and `mise run test-package` checks its layout.

CI lints and tests every push and pull request.
Pushes to `main` update the `snapshot` pre-release.
Tags matching `v*` create a draft release with generated notes,
to be reviewed and published by hand.

`user-data/title-prefetch/idle` is a hook for tests and debugging,
not a stable interface.

## Prior art

[playlistmanager](https://github.com/jonniek/mpv-playlistmanager) also resolves titles,
but keeps them in its own table for its own OSD.
It resolves the whole playlist with no window
and never writes the native property.
For local files,
it uses `ffprobe`
and matches `title=` case-sensitively.

This script instead writes `playlist/N/title`,
limits the work to a window around the current entry,
and asks mpv itself for local titles,
so it matches mpv's own results.

## AI Assistance

This project was developed with the assistance of large language models,
specifically Anthropic's Claude,
which contributed to the code, tests and documentation.
Commits with such contributions
carry a `Co-Authored-By` trailer naming the model.

## License

MIT,
see `LICENSE`.
