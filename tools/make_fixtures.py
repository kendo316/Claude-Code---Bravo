"""Draws six made-up screenshots for the automated simulator run.
Each carries the same 'Screenshot' tag a real iPhone screenshot has, so Photos files it as one."""
import pathlib
from PIL import Image, ImageDraw, ImageFont

OUT = pathlib.Path(__file__).resolve().parent.parent / "Tests/Fixtures"
W, H = 1206, 2622
BOLD = "/usr/share/fonts/opentype/inter/Inter-Bold.otf"
REG = "/usr/share/fonts/opentype/inter/Inter-Regular.otf"

SHOTS = [
    ("1-recipe", "2019:06:02 18:20:11", (250, 246, 238), (30, 30, 30), "Skillet Cornbread", [
        "Ingredients", "2 tbsp butter", "1/2 cup cornmeal", "1 cup buttermilk", "2 eggs", "",
        "Preheat oven to 425 degrees.", "Bake 20 minutes until golden.", "Makes 8 servings."]),
    ("2-taqueria", "2021:09:14 12:05:40", (255, 255, 255), (20, 40, 30), "Casa Verde Taqueria", [
        "Tacos, tortas and a long menu of salsas", "", "Open Tuesday to Sunday", "11:00 AM to 9:00 PM", "",
        "410 Elm Street", "Columbia, MO 65201", "", "Happy hour 3 to 6", "Reservation recommended"]),
    ("3-dutch-oven", "2023:01:22 21:47:03", (245, 247, 250), (25, 25, 35), "Enamel Dutch Oven, 5.5 qt", [
        "$89.00", "In stock", "Free shipping on orders over $50", "", "Add to cart", "", "Color: Marigold",
        "Checkout takes one minute"]),
    ("4-concert", "2026:11:10 09:15:27", (18, 18, 24), (240, 240, 240), "Night Owls Quartet", [
        "Live at The Lantern Room", "", "Friday, December 11, 2026 at 8:00 PM", "Doors 7:00 PM", "",
        "123 Main Street", "Columbia, MO 65201", "", "Tickets: https://example.com/tickets", "General admission $25"]),
    ("5-thread", "2026:11:14 22:31:09", (255, 255, 255), (20, 20, 20), "Group chat", [
        "Did you see the size of that zucchini", "haha it needs its own zip code", "lol bring it Saturday",
        "Delivered"]),
    ("6-plain", "2026:11:16 07:02:55", (32, 60, 92), (220, 230, 240), "", ["9:41", "5G"]),
]

XMP = """<x:xmpmeta xmlns:x="adobe:ns:meta/"><rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
<rdf:Description rdf:about="" xmlns:exif="http://ns.adobe.com/exif/1.0/" xmlns:photoshop="http://ns.adobe.com/photoshop/1.0/">
<exif:UserComment>Screenshot</exif:UserComment><photoshop:DateCreated>{iso}</photoshop:DateCreated>
</rdf:Description></rdf:RDF></x:xmpmeta>"""

for name, stamp, bg, fg, title, lines in SHOTS:
    img = Image.new("RGB", (W, H), bg)
    d = ImageDraw.Draw(img)
    d.text((70, 60), "9:41", font=ImageFont.truetype(BOLD, 48), fill=fg)
    y = 330
    if title:
        d.text((70, y), title, font=ImageFont.truetype(BOLD, 96), fill=fg)
        y += 190
    for line in lines:
        if line:
            d.text((70, y), line, font=ImageFont.truetype(REG, 58), fill=fg)
        y += 100
    exif = Image.Exif()
    exif[0x0132] = stamp                                   # DateTime
    sub = exif.get_ifd(0x8769)
    sub[0x9003] = stamp                                    # DateTimeOriginal
    sub[0x9286] = b"ASCII\x00\x00\x00Screenshot"           # UserComment, exactly as iOS writes it
    sub[0xA002], sub[0xA003] = W, H
    iso = stamp[:10].replace(":", "-") + "T" + stamp[11:]
    from PIL.PngImagePlugin import PngInfo
    info = PngInfo()
    info.add_itxt("XML:com.adobe.xmp", XMP.format(iso=iso))
    img.save(OUT / f"{name}.png", exif=exif, pnginfo=info, dpi=(144, 144), optimize=True)
print("fixtures:", sorted(p.name for p in OUT.glob("*.png")))
