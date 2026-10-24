# Supplied soundtrack

Imported from the user's shared Drive folder on 2026-10-24:
https://drive.google.com/drive/folders/16T5Lo1hsTuOPKG281qrmLcTpIqGkLbyW

- `angry-duck --mainmenu.mp3`: main menu and results.
- `rainbow-beat --lobby.mp3`: lobby, Practice, map selection, loading and preparation.
- `silly-duck --battle match.mp3`: active match above 60 seconds remaining.
- `dank-memes --intense battle match.mp3`: the final 60 seconds of an active match.
- `mr-snarky-destructoid --trailer music.mp3`: retained for trailer production;
  the game currently has no trailer playback scene.

Original filenames and MP3 bytes are preserved. Music loops and crossfades over
0.8 seconds at a default -12 dB through the Music audio bus. The music autoload's
volume, fade duration and closing-match threshold are editable in Godot.
Repeated snapshots or staying in the same context do not restart the track.
Playback is local to each PC, using the authoritative match timer for cue choice.
