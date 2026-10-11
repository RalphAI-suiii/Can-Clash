# Heavyweight idle and refined walk sheet

`heavyweight_idle_walk_inbetween_8dir_24x8_280x273.png` is a transparent RGBA sprite sheet with **24 columns × 8 rows**, **280 × 273 px** cells, **6720 × 2184 px** total size, and **0 px** spacing and offset.

Each row contains one facing direction. **Columns 0–7** are an eight-frame idle loop. **Columns 8–23** are a newly redrawn sixteen-frame walk loop, read left to right. The walk includes contact, weight transfer, foot lift, passing, reach, and landing poses for both feet. Column 23 loops back to column 8.

| Row (top = 0) | Direction |
| --- | --- |
| 0 | Down |
| 1 | Down-left |
| 2 | Left |
| 3 | Up-left |
| 4 | Up |
| 5 | Up-right |
| 6 | Right |
| 7 | Down-right |

All 192 character drawings are normalized to **210 px tall** inside their cells, centered horizontally and grounded on the same baseline. Upper silhouette width varies by no more than about 3 px within a direction; leg and arm reach may change the overall width as the character walks.

In Godot 4, use `AnimatedSprite2D` → `SpriteFrames` → **Add frames from a sprite sheet** with **24 horizontal** and **8 vertical** frames. For each direction, select columns 0–7 for `idle_<direction>` and columns 8–23 for `walk_<direction>`. Start idle at **5 FPS** and walk at **16 FPS**, then tune against actual movement speed. Set texture filtering to **Nearest**, disable **mipmaps**, and use **Lossless** compression.

The walk poses are generated illustrations and have been scale-normalized. Review each loop in Godot for final motion polish. The earlier 16 × 8 sheet remains available unchanged.
