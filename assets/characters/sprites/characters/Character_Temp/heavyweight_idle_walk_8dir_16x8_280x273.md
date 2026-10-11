# Heavyweight idle and walk sheet

`heavyweight_idle_walk_8dir_16x8_280x273.png` is a transparent RGBA sprite sheet. It has **16 columns × 8 rows**, **280 × 273 px** cells, **4480 × 2184 px** total size, and **0 px** spacing and offset.

Each row contains one facing direction. **Columns 0–7 are the eight-frame idle loop**; **columns 8–15 are the eight-frame walk loop**. Frames read left to right.

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

For Godot 4 `AnimatedSprite2D`, choose **Add frames from a sprite sheet** with 16 horizontal and 8 vertical frames. Make separate `idle_<direction>` animations from columns 0–7 and `walk_<direction>` animations from columns 8–15. Start around **5 FPS** for idle and **8 FPS** for walk, then tune in game. Use **Nearest** texture filtering, **no mipmaps**, and **Lossless** compression.

The idle frames are newly generated subtle breathing/blinking poses. The walk frames are copied directly from the earlier eight-direction walk sheet without resampling. Review animation timing in Godot before production use.
