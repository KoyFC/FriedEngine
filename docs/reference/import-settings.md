# Import settings

An asset can have a sidecar file next to it that says how it is prepared for each platform. The sidecar of `sprite.png` is `sprite.png.import`, in JSON. Without one the asset is copied as it is. The editor writes the sidecar from the inspector, but it is plain text and can be edited by hand.

```json
{
  "image": { "maxSize": 1024, "filter": "default", "format": "rgba8" },
  "audio": { "mono": false, "sampleRate": 0, "bits": 0 },
  "platforms": {
    "3ds": { "image": { "maxSize": 256 } }
  }
}
```

The top level applies to every platform. A block under `platforms`, named as in the `platforms` list of the [project file](project-file.md) (`pc`, `vita`, `switch`, `3ds`, `nds`, `cg50`, `web`), is laid over it for that platform, field by field.

## Images

Only PNG files are converted.

| Field | Values | What it does |
|---|---|---|
| `maxSize` | a power of two, or `0` | The image is halved, averaging each four pixels, until neither side is over it. `0` keeps the size. A sprite still draws and measures as the source did, only blurrier. |
| `filter` | `default`, `nearest` or `linear` | How the texture is filtered when it is scaled. `default` follows the project's `display.filter`. The DS and the fx-CG50 never filter. |
| `format` | `rgba8`, `rgba4` or `rgb565` | The depth of the colors. `rgba4` keeps 4 bits a channel and `rgb565` has 5, 6 and 5 and no transparency, so a transparent pixel becomes opaque. |

The converted file is a PNG with an extra chunk, `frIm`, that holds the size of the source, the filter and the format. The engine reads it when it loads the file. The fx-CG50 and the bottom screen of the DS draw every texture at the size of its source, so on them a smaller image is stretched back when it loads and `maxSize` saves nothing in memory.

## Sounds

Only PCM WAV files of 8 or 16 bits are converted. Other formats are copied as they are.

| Field | Values | What it does |
|---|---|---|
| `mono` | `true` or `false` | Mixes the channels down to one. |
| `sampleRate` | a rate in Hz, or `0` | Resamples, linearly. `0` keeps the rate. |
| `bits` | `8`, `16` or `0` | The depth of each sample. `0` keeps it. |

## When it runs

`tools/fried_import` is built for the machine doing the build, with any C++17 compiler, and runs at configure time and before each build, so the copy of the assets that is staged next to the executable, packed into the VPK, the romfs or the page is the converted one. It writes under `imported/` in the build folder, only touches what changed, and removes what no longer comes from an asset. The editor's player reads the assets as they are, so the editor shows the sources.

A setting that does not fit a file, as `mono` on an Ogg, is reported when it is built and the file is copied as it is.
