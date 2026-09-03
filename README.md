# Vinyl Cue Sheet

A REAPER ReaScript that generates a **vinyl cue sheet** (HTML + PDF) from your
project's regions/markers, laid out in ruler lanes.

![example](examples/Borehead%20-%200004%20-%20Cue%20Sheet.pdf)

## Requirements

- **REAPER v7+** (uses the ruler-lane API).
- A **PDF converter** on the system (optional but recommended):
  [`wkhtmltopdf`](https://wkhtmltopdf.org/) or headless **Google Chrome / Edge /
  Chromium**. Without one, the cue sheet is written as HTML that you can open and
  "Save as PDF" from your browser.
- **ReaImGui** (optional) for the graphical settings editor. Without it, settings
  are edited through a native dialog.

## Install (ReaPack)

1. Extensions → ReaPack → Import repositories.
2. Paste:

   ```
   https://github.com/jg-wright/reaper-vinyl-cue-sheet/raw/main/index.xml
   ```

3. Browse packages → install **Vinyl Cue Sheet**.

This installs two actions:

- **Vinyl Cue Sheet** — generate the cue sheet for the current project.
- **Vinyl Cue Sheet: Settings** — edit the persistent global settings.

## Project setup

The script reads two configurable **ruler lanes** (managed via REAPER's Ruler
Lane Manager). Lanes can be referenced by number (default) or by name.

- **Sides lane** (default lane `1`): one region per side. A region counts as a
  side only when it is assigned at least one track in REAPER's **Region Render
  Matrix**; its region name is used verbatim (e.g. name it `Side A`).
- **Tracks lane** (default lane `0`): one region or marker per track. Each track
  is assigned to the side whose time range contains it; numbering and timecodes
  reset at the start of each side.

Auto-filled from the project:

| Cue sheet field | Source |
| --- | --- |
| Title | `$project - Cue Sheet` |
| Artist | `$author` |
| Album | `$title` |
| Audio format | render settings (container + sample rate + bit depth) |

Everything else (Pre-Master, Engineer, Phone, Email, Client) comes from settings.

## Usage

1. Arrange side/track regions in the two lanes.
2. Run **Vinyl Cue Sheet**. It writes `"<project> - Cue Sheet".html` (and a
   `.pdf` if a converter is available) next to the project file, and opens the
   result when *Open after export* is enabled.

## Settings

Edit with **Vinyl Cue Sheet: Settings** (persisted via REAPER ExtState):

| Setting | Purpose |
| --- | --- |
| Pre-Master, Engineer, Phone, Email, Client | Header details |
| Sides lane / Tracks lane | Lane number or name |
| Timecode | Frames (`h:m:s:f`, default), Time, Seconds, Measures.beats |
| Render filename pattern | Per-side filename (see tokens below) |
| Audio format override | Used if auto-detection is incomplete |
| Output directory | Defaults to the project folder |
| PDF converter template | Custom converter command using `{in}` / `{out}` |
| Open after export | Open the result when done |

### Render-filename tokens

`$author` `$title` `$project` `$side` (side region name) `$region` (same) `$ext`

Default: `$author_$title_$side_MASTER.$ext`

## Development

Pure-Lua modules are unit-tested without REAPER:

```sh
luac -p "Vinyl Cue Sheet"/*.lua "Vinyl Cue Sheet"/lib/*.lua   # syntax check
for t in render_format model html pdf; do lua "Vinyl Cue Sheet/test/${t}_spec.lua"; done
```

See [PLAN.md](PLAN.md) for the design and milestones.

## License

[MIT](LICENSE) © John Wright
