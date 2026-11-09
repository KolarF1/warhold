# Warhold

A real-time territory strategy game for Roblox: spawn, expand, fight and hold the world. This is the game's complete
source, published under the GNU AGPL v3 with additional terms. See [LICENSE](LICENSE) and [NOTICE.md](NOTICE.md).

## What is here

| Path | What |
|---|---|
| `src/` | The game: `shared/` (simulation, data, art data), `server/` (match servers, saves, the maps' data), `client/` (map drawing, interface, sound). |
| `release.project.json` | How the published place is assembled from `src/`. |
| `tools/art/` | The scripts that draw the game's art into `src/shared/Art/`: shape lists, packing, map sprites, effects, Standards, map thumbnails. The game-icons originals are in `tools/art/game-icons/`. |
| `tools/maps/`, `tools/data/` | The scripts that build the maps in `src/server/MapData/`, `src/shared/Data/Maps/`, `src/shared/Data/Provinces/` and the start dates' realms. |
| `tools/uikit/`, `tools/art/make_font_*.py` | The scripts that measure the fonts' kerning and widths for `src/client/UI/`. |

## Building the place

You need [Rojo](https://rojo.space) 7:

```
rojo build release.project.json -o Warhold.rbxl
```

Open `Warhold.rbxl` in Roblox Studio. The map and the art are drawn with EditableImage, so the experience needs
**Game Settings > Security > Enable Mesh / Image APIs**, or the screen stays blank.

## Running the generators

The Luau generators run with [Lune](https://lune-org.github.io/docs) from the repository root, for example
`lune run tools/art/icons.luau`. The Python ones need Python 3 with numpy, scipy, Pillow, zstandard, fontTools and svgelements, for example
`python tools/maps/make_maps.py`. Each script says at its top what it reads and which file in `src/` it writes.
