#!/usr/bin/env python3
"""Write preview.html: every *.ans here, shown in the site's own fTelnet
client as its splash screen (exactly what thebeanboard.com/bbs would show
before Connect).

  python3 make_preview.py
  python3 -m http.server 8000      # then open http://localhost:8000/preview.html

It needs a local server, not file://: fTelnet draws with a font image, and
browsers block that image for pages opened from disk. The first run copies
the few fTelnet files it needs from thebeanboard.com into ./ftelnet/.
"""
import base64, glob, html, json, os, urllib.request

FTELNET = 'https://thebeanboard.com/bbs/'
ASSETS = ['ftelnet.norip.xfer.min.js', 'ftelnet.css', 'keyboard/keyboard-720.min.css',
          'fonts/CP437_9x16.png', 'fonts/CP437_8x16.png']

here = os.path.dirname(os.path.abspath(__file__))
for a in ASSETS:
    dest = os.path.join(here, 'ftelnet', a)
    if not os.path.exists(dest):
        os.makedirs(os.path.dirname(dest), exist_ok=True)
        try:
            # Cloudflare turns away urllib's default user agent.
            req = urllib.request.Request(FTELNET + a, headers={'User-Agent': 'Mozilla/5.0 (bean-board-ansi preview)'})
            with urllib.request.urlopen(req) as r, open(dest, 'wb') as f:
                f.write(r.read())
        except Exception as e:
            print('could not fetch', a, '-', e)
arts = {}
for path in sorted(glob.glob(os.path.join(here, '*.ans'))):
    data = open(path, 'rb').read()
    data = data.split(b'\x1a')[0]          # SAUCE isn't screen content
    arts[os.path.basename(path)] = base64.b64encode(b'\x1b[0m\x1b[2J\x1b[H' + data).decode()

buttons = ''.join(f'<button data-k="{html.escape(k)}">{html.escape(k)}</button>' for k in arts)
page = f"""<!DOCTYPE html>
<html lang="en"><head><meta charset="utf-8"><title>Bean Board ANSI preview</title>
<style>
  body {{ background:#0f0d0a; color:#f4ecdc; font-family:-apple-system,sans-serif; margin:24px; }}
  .bar {{ display:flex; gap:8px; flex-wrap:wrap; align-items:center; margin-bottom:14px; }}
  button {{ font:inherit; padding:7px 14px; border-radius:20px; border:1px solid #6b5a48; background:#1e1913; color:#f4ecdc; cursor:pointer; }}
  button.on {{ background:#50b450; border-color:#50b450; color:#0f0d0a; font-weight:700; }}
  label {{ margin-left:12px; color:#b8a68f; }}
  #fTelnetContainer {{ display:inline-block; }}
</style></head><body>
<div class="bar">{buttons}<label><input type="checkbox" id="rows"> 50-row screen</label></div>
<div id="fTelnetContainer"></div>
<script src="ftelnet/ftelnet.norip.xfer.min.js" id="fTelnetScript"></script>
<script>
  var ARTS = {json.dumps(arts)};
  var current = Object.keys(ARTS)[0];
  function show(k) {{
    current = k;
    document.querySelectorAll('button').forEach(function (b) {{ b.classList.toggle('on', b.dataset.k === k); }});
    var c = document.getElementById('fTelnetContainer'); c.innerHTML = '';
    var o = new fTelnetOptions();
    o.SplashScreen = ARTS[k];
    o.ScreenRows = document.getElementById('rows').checked ? 50 : 25;
    window.Client = new fTelnetClient('fTelnetContainer', o);
  }}
  document.querySelectorAll('button').forEach(function (b) {{ b.onclick = function () {{ show(b.dataset.k); }}; }});
  document.getElementById('rows').onchange = function () {{ show(current); }};
  show(current);
</script></body></html>
"""
open(os.path.join(here, 'preview.html'), 'w').write(page)
print('wrote', os.path.join(here, 'preview.html'), 'with', ', '.join(arts))
