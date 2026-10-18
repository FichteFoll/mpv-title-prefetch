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

1. Copy or symlink the `title-prefetch/` directory
   into `~/.config/mpv/scripts/`.
2. Optionally, copy `title-prefetch.conf`
   into `~/.config/mpv/script-opts/`.

yt-dlp is optional.
It is only needed for remote URLs
and is found the way `ytdl_hook` finds it,
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
| `cache_size` | `100` | maximum cached titles, FIFO; `0` = no cache, negative = unlimited |
| `concurrency` | `4` | maximum simultaneous subprocesses |
| `timeout` | `30` | seconds before a subprocess is aborted and counted as failed |
| `mpv_path` | `mpv` | executable used for the local probe |

## Commands

The script offers a single script message:

| message | arguments | effect |
|---|---|---|
| `resolve-more` | optional `count` (positive integer) or `all` | extends the effective range |

`count` is added to the effective range.
Without an argument, it defaults to the `range` option when that is positive,
and to 5 otherwise.
`all` resolves every entry.
The extension lasts until the `range` option changes.
It also works with `range=0`,
which enables resolution explicitly.

No key binding is registered by default.
Bind it in `input.conf`,
for example:

```
Ctrl+t script-message-to title_prefetch resolve-more
Ctrl+T script-message-to title_prefetch resolve-more all
```

Note that the script name in `script-message-to` has an underscore,
`title_prefetch`,
unlike the option prefix `title-prefetch`.

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
- Titles are cached FIFO up to `cache_size`.
  The cache entry of a file is refreshed whenever it is played.
  A playback that yields no title drops the cached title
  and marks the file as failed.
- A failed resolution is not retried during the session,
  unless the entry is played,
  which refreshes it.
- A yt-dlp candidate that cannot be started is not a failure.
  The entry is retried with the next candidate.
  If no candidate can be started,
  remote entries are skipped for the session,
  without being marked as failed.
- Local titles come from a headless `mpv` probe,
  so `mpv_path` must point to mpv.
  This reuses mpv's own demuxers and metadata rules.

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

`mise run lint` runs the LuaLS type check and `shellcheck`.
`types/` holds handwritten definitions of the parts of the mpv API that the code uses.

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

## License

MIT,
see `LICENSE`.
