# Heavyweight idle and smoother walk sheet

`heavyweight_idle_walk_inbetween_8dir_24x8_280x273.png` is a transparent RGBA sprite sheet with **24 columns × 8 rows**, **280 × 273 px** cells, **6720 × 2184 px** total size, and **0 px** spacing and offset.

Each row contains one facing direction. **Columns 0–7** are the unchanged eight-frame idle loop. **Columns 8–23** are a sixteen-frame walk loop. The original walk frames are at columns **8, 10, 12, 14, 16, 18, 20, 22**. Newly drawn passing-foot poses sit between them at columns **9, 11, 13, 15, 17, 19, 21, 23**; column 23 transitions back to column 8.

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

In Godot 4, use `AnimatedSprite2D` → `SpriteFrames` → **Add frames from a sprite sheet** with **24 horizontal** and **8 vertical** frames. For each direction, select columns 0–7 for `idle_<direction>` and columns 8–23 for `walk_<direction>`. Start idle at **5 FPS** and walk at **16 FPS** to retain the timing of the earlier eight-frame walk at 8 FPS; tune against actual movement speed. Set texture filtering to **Nearest**, disable **mipmaps**, and use **Lossless** compression.

The passing-foot poses are generated illustrations. Review each loop in Godot for motion polish before final release. The earlier 16 × 8 sheet remains available unchanged.
