# make-oars.py: draws the club's crossed-oars ornament and writes the six SVG files the site uses.
#
#   images/oars-on-white.svg       regular pair, navy line, for white bands     (.oars-divider on white)
#   images/oars-on-paper.svg       regular pair, navy line, for paper bands     (404 page)
#   images/oars-on-navy.svg        regular pair, white line, for navy surfaces
#   images/oars-long-on-white.svg  long-handled pair, navy line, white bands    (home page .oars-row)
#   images/oars-long-on-paper.svg  long-handled pair, navy line, paper bands
#   images/oars-long-on-navy.svg   long-handled pair, white line, navy          (footer .footer-lockup)
#
# To regenerate (only needed to change the drawing): from the project folder run
#     python3 _tools/make-oars.py
# It needs Python 3 with Pillow (pip install pillow) and Google Chrome (headless, used to
# measure the drawing so each file is cropped tight). It overwrites the six files above in
# images/ and nothing else; this folder starts with "_" so Quarto never publishes it.
# Add --previews to also write large PNG proofs into _tools/previews/ (not published).
#
# The drawing: two crossed oars, hatchet blades at the raised ends hanging down over the other
# oar's handle; club paint (blue along the shaft side, green on the outer side, a white stripe
# from the neck to the far tip corner); a sleeve with a club-green collar.
#   ext  = extra length added to BOTH halves of each oar (blade moves out, handle end moves out)
#   grip = length of the thick handle grip
#   tilt = half-angle of the cross; longer oars need less tilt for the blade to clear the handle beneath it
import subprocess, tempfile, os, sys
from PIL import Image, ImageChops
BLUE, GREEN, NAVY, PAPER, WHITE = "#00B0F0", "#80C040", "#0A1F3C", "#F6F7F4", "#FFFFFF"
CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
DEFS = '''<filter id="wash" x="-10%" y="-10%" width="120%" height="120%"><feTurbulence type="fractalNoise" baseFrequency="0.035" numOctaves="2" seed="3" result="n"/><feDisplacementMap in="SourceGraphic" in2="n" scale="5"/></filter>
<filter id="ink" x="-3%" y="-3%" width="106%" height="106%"><feTurbulence type="fractalNoise" baseFrequency="0.9" numOctaves="1" seed="11" result="n"/><feDisplacementMap in="SourceGraphic" in2="n" scale="1.4"/></filter>'''
BLADE = ("M 236,8 C 300,14 400,26 478,30 Q 502,31 502,9 L 497,-96 Q 496,-118 474,-118 "
         "C 420,-118 364,-115 330,-106 C 286,-94 276,-34 236,-8 Z")
RIB = "M 236,-4.5 L 404,-1 Q 412,0 404,1 L 236,4.5 Z"
VARIANTS = {"regular": dict(ext=0, grip=160, tilt=12), "long": dict(ext=420, grip=250, tilt=5.6)}

def oar(ink, bg, sw, uid, ext, grip):
    end = -545 - ext                      # handle end
    g1 = end + grip                       # where the grip stops
    cx = end + 0.26 * (502 + ext - end)   # collar position, about a quarter of the way up from the handle
    blade = f'''<g transform="translate({ext},0)"><clipPath id="b{uid}"><path d="{BLADE}"/></clipPath>
  <path d="{BLADE}" fill="#FFFFFF"/>
  <g transform="translate(3,3)" filter="url(#wash)"><g clip-path="url(#b{uid})">
    <polygon points="230,-10.5 520,-133.5 520,-260 230,-260" fill="{GREEN}"/>
    <polygon points="230,10.5 520,-112.5 520,160 230,160" fill="{BLUE}"/></g></g>
  <path d="{BLADE}" fill="none" stroke="{ink}" stroke-width="{sw}" stroke-linejoin="round" stroke-linecap="round"/>
  <rect x="216" y="-11" width="26" height="22" rx="6" fill="{ink}"/>
  <path d="{RIB}" fill="{ink}"/></g>'''
    body = f'''<path d="M {g1-7},-6.5 L {226+ext},-5 L {226+ext},5 L {g1-7},6.5 Z" fill="{ink}" stroke="{ink}" stroke-width="{sw*.5}" stroke-linejoin="round"/>
  <rect x="{end}" y="-12.5" width="{grip}" height="25" rx="12.5" fill="{ink}"/>'''
    sleeve = f'''<rect x="{cx-18}" y="-10.5" width="122" height="21" rx="4" fill="{bg}" stroke="{ink}" stroke-width="{sw*.8}"/>
  <rect x="{cx}" y="-20" width="17" height="40" rx="5" fill="{GREEN}" stroke="{ink}" stroke-width="{sw*.8}"/>'''
    halo = f'<path d="M {g1},0 L {222+ext},0" fill="none" stroke="{bg}" stroke-width="{sw*5.5}"/>'
    return f"{halo}\n  {blade}\n  {body}\n  {sleeve}"

def scene(variant="regular", ink=NAVY, bg=WHITE, sw=4.5, box=True, view=None, W=2200, H=520):
    v = VARIANTS[variant]; vb = view or (0, 0, W, H)
    rect = f'<rect width="{W}" height="{H}" fill="{bg}"/>' if box else ''
    a = f'<g transform="rotate({v["tilt"]}) scale(-1,-1)">{oar(ink, bg, sw, "L", v["ext"], v["grip"])}</g>'
    b = f'<g transform="rotate({-v["tilt"]}) scale(1,-1)">{oar(ink, bg, sw, "R", v["ext"], v["grip"])}</g>'
    return f'''<svg xmlns="http://www.w3.org/2000/svg" width="{vb[2]}" height="{vb[3]}" viewBox="{vb[0]} {vb[1]} {vb[2]} {vb[3]}">
<defs>{DEFS}</defs>{rect}
<g transform="translate({W/2},{H/2})" filter="url(#ink)">{a}{b}</g></svg>'''

def render(svg_text, out_png, w, h):
    with tempfile.TemporaryDirectory() as td:
        f = os.path.join(td, 'x.svg'); open(f, 'w').write(svg_text)
        subprocess.run([CHROME, "--headless=new", "--disable-gpu", "--hide-scrollbars", "--force-device-scale-factor=1", f"--user-data-dir={td}/p",
                        f"--window-size={w},{h}", f"--screenshot={out_png}", "file://" + f], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=90)

def bbox(variant, sw, pad=12):
    with tempfile.TemporaryDirectory() as td:
        p = os.path.join(td, 'x.png'); render(scene(variant, sw=sw), p, 2200, 520)
        im = Image.open(p).convert("RGB"); b = ImageChops.difference(im, Image.new("RGB", im.size, (255, 255, 255))).getbbox()
    return (b[0] - pad, b[1] - pad, b[2] - b[0] + 2 * pad, b[3] - b[1] + 2 * pad)

if __name__ == "__main__":
    here = os.path.dirname(os.path.abspath(__file__))
    images = os.path.join(here, "..", "images")
    previews = os.path.join(here, "previews")
    for variant in VARIANTS:
        prefix = "oars" if variant == "regular" else "oars-long"
        if "--previews" in sys.argv:
            os.makedirs(previews, exist_ok=True)
            render(scene(variant), os.path.join(previews, f"{variant}-large.png"), 2200, 520)
            render(scene(variant, ink=WHITE, bg=NAVY), os.path.join(previews, f"{variant}-navy-large.png"), 2200, 520)
        vb = bbox(variant, 7)
        for surface, ink, bg, sw in (("white", NAVY, WHITE, 5.5), ("paper", NAVY, PAPER, 5.5), ("navy", WHITE, NAVY, 7)):
            out = os.path.join(images, f"{prefix}-on-{surface}.svg")
            open(out, "w").write(scene(variant, ink, bg, sw, box=False, view=vb))
            print("wrote", os.path.relpath(out))
        print(variant, "viewBox", vb, "aspect %.2f" % (vb[2] / vb[3]))
