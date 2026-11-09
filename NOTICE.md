# Notice

**Warhold** is a modified version of **RoWorld** (by Snick Co., <https://github.com/lukechatton/roworld>), which is
itself a modified version of **OpenFront**.

- © OpenFront and Contributors.
- Changes © 2026 Snick Co. (RoWorld).
- Changes © 2026 the Warhold developers.

This program is free software: you can redistribute it and/or modify it under the terms of the **GNU Affero General
Public License, version 3**, with the additional terms (AGPL section 7) at the end of the [LICENSE](LICENSE) file:

1. **Copyright preservation (7(b)):** the notice "© OpenFront and Contributors" must stay visible in the game. Warhold
   shows it in the title screen's footer and in the Field Guide's Credits and source.
2. **No misrepresentation (7(c)):** this is not OpenFront and is not RoWorld, and neither endorses it. Do not use
   "OpenFront" as the title or imply official endorsement.

It comes with ABSOLUTELY NO WARRANTY.

## Third-party material

- **Interface and map icons:** most are from **game-icons.net**, under **CC BY 3.0**
  (<https://creativecommons.org/licenses/by/3.0/>), by Lorc, Delapouite, Skoll, HeavenlyDog and Pierre Leducq. The
  originals and their licence are in `tools/art/game-icons/`. They are recoloured and fitted to the game's glyph grid
  (`tools/art/gi_import.py`), and credited in the game's Field Guide.
- **Real-world maps:** Natural Earth and NOAA ETOPO1, both public domain. `tools/maps/make_maps.py` downloads them.
- **Font:** Builder Sans and Montserrat ship with Roblox. Only their kerning and widths are measured here
  (`tools/uikit/`, `tools/art/make_font_*.py`).
- **Sounds and music** are Roblox assets uploaded by the Warhold developers. The game refers to them by id
  (`src/shared/Assets/`).
