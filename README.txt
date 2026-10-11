Bean Board ANSI art (generated from ansi-example.png)

  bean-board-wide.ans    76x30, largest; needs a 50-row screen or scrolls on 80x25
  bean-board-splash.ans  56x22, fits an 80x24 screen

Preview exactly as the site would show it (fTelnet, the BBS web client):
  cd ~/Downloads/bean-board-ansi
  python3 -m http.server 8000
  open http://localhost:8000/preview.html     (Ctrl-C the server when done)
Click a file name to switch; tick "50-row screen" for the tall one.

Quick look in a terminal (Terminal.app's colours aren't VGA, so approximate):
  iconv -f CP437 -t UTF-8 bean-board-wide.ans | sed $'s/\x1a.*//'

Regenerate / tweak (Pillow via uv, nothing installed globally):
  uvx --with pillow python make_ansi.py ../ansi-example.png out.ans --cols 76 [--saturation 2.2]
  uvx --with pillow python make_ansi.py ../ansi-example.png out.ans --rows 22
  python3 make_preview.py      # rebuilds preview.html with every *.ans here

What the converter does by default: strips the logo's white sticker outline,
snaps to the 16 VGA colours, and re-letters the sign with a bold pixel font
("BEAN" white on a red plate, "BOARD" white with a dark shadow). Use
--keep-outline / --no-reletter to see the logo's original edges or lettering.
