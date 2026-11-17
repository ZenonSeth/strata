# Licenses

- Code (Lua and any other source): LGPL-3.0-only
- Media (textures, models, sounds, etc.): CC BY-SA 3.0

Third-party assets, with their licenses and authors, are listed below.

## Credits

### Exo 2 (font)

- Author: Natanael Gama (www.ndiscovered.com)
- Copyright: (c) 2013, Natanael Gama, with Reserved Font Name 'Exo'
- Source: https://www.1001freefonts.com/exo-2.font
- Files (renamed so Luanti uses them as its default fonts, otherwise unmodified):
  - `mods/str_gui/fonts/regular.ttf` (Exo 2 Regular)
  - `mods/str_gui/fonts/bold.ttf` (Exo 2 Bold)
- License (SPDX): OFL-1.1
- Full text: `mods/str_gui/fonts/OFL.txt`

### "Mirage" (menu music)

- Author: Kevin MacLeod (incompetech.com)
- Source: http://incompetech.com
- Files: `menu/theme.ogg` (an edited, shortened excerpt of the original)
- License (SPDX): CC-BY-4.0 (http://creativecommons.org/licenses/by/4.0/)

### "Clean Soul" (on-foot music)

- Author: Kevin MacLeod (incompetech.com)
- Source: http://incompetech.com
- Files: `mods/str_audio/sounds/str_audio_music_foot.ogg` (an edited, shortened excerpt of the original)
- License (SPDX): CC-BY-4.0 (http://creativecommons.org/licenses/by/4.0/)

### "Comfortable Mystery" (underground music)

- Author: Kevin MacLeod (incompetech.com)
- Source: http://incompetech.com
- Files: `mods/str_audio/sounds/str_audio_music_underground_1.ogg`, `_2.ogg`, `_3.ogg` (edited, shortened excerpts of the original)
- License (SPDX): CC-BY-4.0 (http://creativecommons.org/licenses/by/4.0/)

### "Blue Feather" (underground music)

- Author: Kevin MacLeod (incompetech.com)
- Source: http://incompetech.com
- Files: `mods/str_audio/sounds/str_audio_music_underground_4.ogg`, `_5.ogg` (excerpts cut from the original, otherwise unmodified)
- License (SPDX): CC-BY-4.0 (http://creativecommons.org/licenses/by/4.0/)

### "Dark Star" (ending music)

- Author: Kevin MacLeod (incompetech.com)
- Source: http://incompetech.com
- Files: `mods/str_audio/sounds/str_audio_music_ending.ogg` (a cut version of the original, otherwise unmodified)
- License (SPDX): CC-BY-4.0 (http://creativecommons.org/licenses/by/4.0/)

### "Coins in Cloth 05" (shop purchase sound)

- Author: Anthousai (freesound.org)
- Source: https://freesound.org/people/Anthousai/sounds/336579/
- Files: `mods/str_company/sounds/str_company_register.ogg` (converted to mono Ogg Vorbis, otherwise unmodified)
- License (SPDX): CC0-1.0 (https://creativecommons.org/publicdomain/zero/1.0/)

### "crowbar falls on ground or metal iron hits blacksmith anvil.wav" (refinery craft sounds)

- Author: kyles (freesound.org)
- Source: https://freesound.org/people/kyles/sounds/452584/
- Files: `mods/str_refinery/sounds/str_refinery_craft.1.ogg`, `.2.ogg`, `.3.ogg`, `.4.ogg` (short clips cut from the original)
- License (SPDX): CC0-1.0 (https://creativecommons.org/publicdomain/zero/1.0/)

## Original work

Everything not listed under Credits above is original work by Zenon Seth, licensed CC BY-SA 3.0 (media) and LGPL-3.0-only (code). This includes:

- Sound effects (all generated with Python scripts, no third-party recordings or samples):
  - `mods/str_ambience/sounds/`
  - `mods/str_elevators/sounds/`
  - `mods/str_explosives/sounds/`
  - `mods/str_interior/sounds/`
  - `mods/str_lasers/sounds/`
  - `mods/str_machine/sounds/`
  - `mods/str_refuel/sounds/`
  - `mods/str_transmissions/sounds/`
  - `mods/str_upgrades/sounds/` (including the colour spray hiss, `str_upgrades_spray_hiss.ogg`)
- Textures:
  - `mods/str_manual/textures/` (the manual book and window, generated with a Python script, no third-party images)
  - `mods/str_machine/textures/`: the machine model textures `str_machine_chassis_*.png`, `str_machine_thruster_*.png`, `str_machine_right_tires.png`, `str_machine_noise.png`, `str_machine_drill_*.png` and `str_machine_hull_laser_mount.png` (generated with Python scripts, no third-party images)
  - `mods/str_company/textures/str_company_item.png` (generated with a Python script, no third-party images)
  - `mods/str_lasers/textures/str_lasers_laser_*.png` and `str_lasers_battery_*.png` (generated with a Python script, no third-party images)
- Models and schematics:
  - `mods/str_foot/models/str_foot_player.glb`
  - `mods/str_machine/models/digger1.glb`
  - `mods/str_nodes/models/str_nodes_rock_1.obj`, `str_nodes_rock_2.obj`, `str_nodes_rock_3.obj`
  - `mods/str_start/schems/shop_home.mts`
- Source art in `art/` (`.nbx`, `.kra` and `.png` files), the sources of the game textures. `art/drill_spiral_unwrap.png` (the drill cone groove pattern) is generated with a Python script.
