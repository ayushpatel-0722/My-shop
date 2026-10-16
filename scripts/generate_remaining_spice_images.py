import os
import json
import math
import random
from PIL import Image, ImageDraw, ImageFont, ImageFilter

OUTPUT_DIR = "/home/ayush/.gemini/antigravity/brain/c0e14427-90ef-4c6e-931f-e5b57c39bd04/generated_spices"
os.makedirs(OUTPUT_DIR, exist_ok=True)

FONT_BOLD = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
FONT_REGULAR = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"

def get_font(path, size):
    try:
        return ImageFont.truetype(path, size)
    except:
        return ImageFont.load_default()

PRODUCTS = [
    {
        "sku": "MAS-CSE-014",
        "name": "Cumin Seeds",
        "subtitle": "Whole Aromatic Jeera Seeds",
        "weight": "NET WEIGHT: 200g",
        "theme": (92, 58, 33),      # Deep earthy roast
        "accent": (212, 163, 89),   # Golden cumin
        "dish": "cumin_seeds"
    },
    {
        "sku": "MAS-COS-015",
        "name": "Coriander Seeds",
        "subtitle": "Whole Crisp Sabut Dhania",
        "weight": "NET WEIGHT: 200g",
        "theme": (75, 78, 42),      # Herb olive
        "accent": (198, 185, 110),  # Golden seed
        "dish": "coriander_seeds"
    },
    {
        "sku": "MAS-BIR-016",
        "name": "Premium Biryani Masala",
        "subtitle": "Royal Shahi Aromatic Blend",
        "weight": "NET WEIGHT: 100g",
        "theme": (138, 48, 22),     # Saffron maroon
        "accent": (245, 155, 45),   # Biryani amber
        "dish": "biryani"
    },
    {
        "sku": "MAS-PAV-017",
        "name": "Pav Bhaji Masala",
        "subtitle": "Mumbai Street Food Special",
        "weight": "NET WEIGHT: 100g",
        "theme": (155, 42, 28),     # Fiery red-brown
        "accent": (238, 92, 44),    # Pav bhaji red
        "dish": "pav_bhaji"
    },
    {
        "sku": "MAS-CHO-018",
        "name": "Chole Masala",
        "subtitle": "Amritsari Style Tangy Blend",
        "weight": "NET WEIGHT: 100g",
        "theme": (68, 45, 32),      # Dark tangy masala
        "accent": (195, 122, 65),   # Anardana brown
        "dish": "chole"
    },
    {
        "sku": "MAS-PAN-019",
        "name": "Paneer Masala",
        "subtitle": "Rich Shahi Curry Blend",
        "weight": "NET WEIGHT: 100g",
        "theme": (145, 62, 22),     # Royal orange
        "accent": (242, 168, 52),   # Creamy gravy
        "dish": "paneer"
    },
    {
        "sku": "MAS-TAN-020",
        "name": "Tandoori Masala",
        "subtitle": "Smoky BBQ & Tikka Blend",
        "weight": "NET WEIGHT: 100g",
        "theme": (165, 28, 22),     # Crimson tandoor
        "accent": (248, 72, 42),    # Bright tikka red
        "dish": "tandoori"
    },
    {
        "sku": "MAS-SAM-021",
        "name": "Sambar Masala",
        "subtitle": "Traditional South Indian Blend",
        "weight": "NET WEIGHT: 100g",
        "theme": (128, 62, 18),     # Mustard brown
        "accent": (232, 142, 32),   # Sambar yellow
        "dish": "sambar"
    },
    {
        "sku": "MAS-RAS-022",
        "name": "Rasam Masala",
        "subtitle": "Aromatic Pepper & Cumin Rasam",
        "weight": "NET WEIGHT: 100g",
        "theme": (112, 42, 26),     # Peppery copper
        "accent": (222, 112, 42),   # Rasam broth
        "dish": "rasam"
    },
    {
        "sku": "MAS-CUR-023",
        "name": "Everyday Curry Masala",
        "subtitle": "All-in-One Daily Sabji Blend",
        "weight": "NET WEIGHT: 100g",
        "theme": (118, 78, 22),     # Warm curry gold
        "accent": (228, 168, 48),   # Golden curry
        "dish": "curry"
    },
    {
        "sku": "MAS-KCP-024",
        "name": "Kashmiri Chilli Powder",
        "subtitle": "Vibrant Crimson & Mild Heat",
        "weight": "NET WEIGHT: 200g",
        "theme": (178, 28, 28),     # Deep ruby red
        "accent": (238, 52, 48),    # Kashmiri red
        "dish": "kashmiri_chilli"
    },
    {
        "sku": "MAS-GIN-025",
        "name": "Dry Ginger Powder",
        "subtitle": "Pure Fine Saunth Powder",
        "weight": "NET WEIGHT: 100g",
        "theme": (122, 98, 62),     # Warm beige brown
        "accent": (222, 192, 132),  # Ginger cream
        "dish": "ginger"
    },
    {
        "sku": "MAS-FEN-026",
        "name": "Fennel Powder",
        "subtitle": "Sweet & Fragrant Saunf Powder",
        "weight": "NET WEIGHT: 100g",
        "theme": (58, 92, 48),      # Herbal green
        "accent": (162, 208, 122),  # Fresh fennel green
        "dish": "fennel"
    },
    {
        "sku": "MAS-CAP-027",
        "name": "Green Cardamom Powder",
        "subtitle": "Fragrant Royal Elaichi Powder",
        "weight": "NET WEIGHT: 50g",
        "theme": (48, 82, 52),      # Deep cardamom green
        "accent": (148, 192, 112),  # Pastel elaichi
        "dish": "cardamom_powder"
    },
    {
        "sku": "MAS-NUT-028",
        "name": "Nutmeg Powder",
        "subtitle": "Gourmet Jaiphal Powder",
        "weight": "NET WEIGHT: 50g",
        "theme": (102, 58, 38),     # Warm nutmeg mahogany
        "accent": (208, 142, 98),   # Nutmeg brown
        "dish": "nutmeg"
    },
    {
        "sku": "MAS-CNP-029",
        "name": "Premium Cinnamon Powder",
        "subtitle": "Cooking & Baking Grade",
        "weight": "NET WEIGHT: 100g",
        "theme": (112, 48, 28),     # Rich cinnamon brown
        "accent": (218, 128, 68),   # Cinnamon orange
        "dish": "cinnamon_baking"
    },
    {
        "sku": "MAS-MIX-030",
        "name": "Premium Mixed Spice Blend",
        "subtitle": "Multi-Spice Gourmet Seasoning",
        "weight": "NET WEIGHT: 100g",
        "theme": (98, 52, 32),      # Warm terracotta
        "accent": (228, 138, 52),   # Multi-spice gold
        "dish": "mixed_spices"
    }
]

def render_photorealistic_spice_window(draw, cx, cy, radius, theme, accent, dish_type):
    # Circular Product Window with multi-layered metallic gold rim
    rim_color = (212, 175, 55)
    rim_inner = (245, 222, 120)

    # 1. Outer metallic gold frame
    draw.ellipse([cx - radius, cy - radius, cx + radius, cy + radius], fill=(238, 235, 228), outline=rim_color, width=6)
    draw.ellipse([cx - radius + 4, cy - radius + 4, cx + radius - 4, cy + radius - 4], outline=rim_inner, width=3)

    # 2. Inside window: Deep gradient textured spice bowl / mound
    inner_r = radius - 10
    bowl_poly = [cx - inner_r, cy - inner_r, cx + inner_r, cy + inner_r]
    
    # Base spice fill
    draw.ellipse(bowl_poly, fill=accent)

    # Dense realistic spice particles & texture
    rng = random.Random(hash(dish_type))
    base_r, base_g, base_b = accent
    theme_r, theme_g, theme_b = theme

    # Radial gradient shading towards edges
    for i in range(1200):
        ang = rng.uniform(0, 2 * math.pi)
        dist = rng.uniform(0, inner_r - 2)
        px = int(cx + dist * math.cos(ang))
        py = int(cy + dist * math.sin(ang))
        
        # Color variation
        blend = dist / inner_r
        cr = int(base_r * (1 - blend * 0.4) + theme_r * (blend * 0.4))
        cg = int(base_g * (1 - blend * 0.4) + theme_g * (blend * 0.4))
        cb = int(base_b * (1 - blend * 0.4) + theme_b * (blend * 0.4))
        
        # Salt & pepper speckles
        if rng.random() < 0.15:
            cr = max(0, cr - rng.randint(40, 80))
            cg = max(0, cg - rng.randint(40, 80))
            cb = max(0, cb - rng.randint(40, 80))
        elif rng.random() < 0.1:
            cr = min(255, cr + rng.randint(30, 60))
            cg = min(255, cg + rng.randint(30, 60))
            cb = min(255, cb + rng.randint(30, 60))

        dot_r = rng.choice([1, 2, 2, 3])
        draw.ellipse([px - dot_r, py - dot_r, px + dot_r, py + dot_r], fill=(cr, cg, cb))

    # Inner glass reflection highlight on the window (crescent sheen)
    sheen = Image.new("RGBA", (1024, 1024), (0, 0, 0, 0))
    sh_draw = ImageDraw.Draw(sheen)
    sh_draw.ellipse([cx - inner_r + 15, cy - inner_r + 10, cx + inner_r - 25, cy - inner_r + 45], fill=(255, 255, 255, 110))
    sheen = sheen.filter(ImageFilter.GaussianBlur(8))
    return sheen

def generate_packaging_image(p_info):
    # Canvas: 1024x1024
    img = Image.new("RGB", (1024, 1024), (248, 247, 243)) # Soft clean off-white studio background
    draw = ImageDraw.Draw(img)

    # Soft studio ground shadow
    shadow = Image.new("RGBA", (1024, 1024), (0, 0, 0, 0))
    s_draw = ImageDraw.Draw(shadow)
    s_draw.ellipse([230, 835, 794, 925], fill=(0, 0, 0, 50))
    shadow = shadow.filter(ImageFilter.GaussianBlur(32))
    img.paste(Image.alpha_composite(Image.new("RGBA", (1024, 1024), (248, 247, 243, 255)), shadow).convert("RGB"))
    draw = ImageDraw.Draw(img)

    # Stand-up pouch geometry
    p_left, p_top, p_right, p_bottom = 275, 145, 749, 868
    pouch_body_color = (253, 252, 249)

    # Pouch polygon
    pouch_poly = [
        (p_left + 18, p_top),
        (p_right - 18, p_top),
        (p_right, p_top + 32),
        (p_right + 6, p_bottom - 48),
        (p_right - 26, p_bottom),
        (p_left + 26, p_bottom),
        (p_left - 6, p_bottom - 48),
        (p_left, p_top + 32),
    ]
    draw.polygon(pouch_poly, fill=pouch_body_color, outline=(218, 214, 206))

    # Resealable zip line & tear notches
    draw.line([(p_left + 8, p_top + 46), (p_right - 8, p_top + 46)], fill=(188, 183, 172), width=2)
    draw.line([(p_left + 4, p_top + 46), (p_left + 20, p_top + 46)], fill=(125, 118, 108), width=3)
    draw.line([(p_right - 20, p_top + 46), (p_right - 4, p_top + 46)], fill=(125, 118, 108), width=3)

    # Scissors icon mark at tear notch
    f_notch = get_font(FONT_REGULAR, 12)
    draw.text((p_right - 35, p_top + 38), "✂", fill=(130, 125, 115), font=f_notch)

    # ── POUCH HEADER: Brand Banner ──
    header_top = p_top + 58
    header_height = 118
    theme_color = p_info["theme"]
    accent_color = p_info["accent"]

    # Elegant dark brand banner
    draw.rounded_rectangle([p_left + 22, header_top, p_right - 22, header_top + header_height], radius=15, fill=theme_color)
    draw.rounded_rectangle([p_left + 26, header_top + 4, p_right - 26, header_top + header_height - 4], radius=12, outline=accent_color, width=2)

    # Brand Title: Masala Mart
    f_brand = get_font(FONT_BOLD, 46)
    brand_text = "Masala Mart"
    b_box = draw.textbbox((0, 0), brand_text, font=f_brand)
    b_w = b_box[2] - b_box[0]
    draw.text((512 - b_w // 2, header_top + 22), brand_text, fill=(255, 255, 255), font=f_brand)

    # Brand Subtext
    f_brand_sub = get_font(FONT_BOLD, 14)
    sub_text = "✦  PREMIUM INDIAN SPICES  ✦"
    s_box = draw.textbbox((0, 0), sub_text, font=f_brand_sub)
    s_w = s_box[2] - s_box[0]
    draw.text((512 - s_w // 2, header_top + 78), sub_text, fill=accent_color, font=f_brand_sub)

    # ── PRODUCT TITLE SECTION ──
    f_title = get_font(FONT_BOLD, 36)
    p_name = p_info["name"]
    words = p_name.split()
    if len(p_name) > 20 and len(words) > 2:
        line1 = " ".join(words[:2])
        line2 = " ".join(words[2:])
        lines = [line1, line2]
    else:
        lines = [p_name]

    curr_y = header_top + header_height + 26
    for l in lines:
        t_box = draw.textbbox((0, 0), l, font=f_title)
        t_w = t_box[2] - t_box[0]
        draw.text((512 - t_w // 2, curr_y), l, fill=theme_color, font=f_title)
        curr_y += 42

    f_sub = get_font(FONT_REGULAR, 18)
    sub_desc = p_info["subtitle"]
    sd_box = draw.textbbox((0, 0), sub_desc, font=f_sub)
    sd_w = sd_box[2] - sd_box[0]
    draw.text((512 - sd_w // 2, curr_y), sub_desc, fill=(115, 108, 98), font=f_sub)
    curr_y += 38

    # ── CENTER SPICE GRAPHIC & WINDOW ──
    window_center_y = curr_y + 118
    window_radius = 110
    sheen = render_photorealistic_spice_window(draw, 512, window_center_y, window_radius, theme_color, accent_color, p_info["dish"])
    img.paste(sheen, (0, 0), sheen)
    draw = ImageDraw.Draw(img)

    # ── FOOTER: Net Weight & 100% Quality Badge ──
    footer_y = p_bottom - 78
    # Quality badge
    draw.ellipse([p_left + 35, footer_y - 12, p_left + 105, footer_y + 58], fill=accent_color, outline=theme_color, width=2)
    f_badge = get_font(FONT_BOLD, 15)
    draw.text((p_left + 46, footer_y + 8), "100%", fill=(255, 255, 255), font=f_badge)
    f_badge_sub = get_font(FONT_BOLD, 10)
    draw.text((p_left + 47, footer_y + 26), "PURE", fill=(255, 255, 255), font=f_badge_sub)

    # Net weight text
    f_wt = get_font(FONT_BOLD, 20)
    wt_text = p_info["weight"]
    wt_box = draw.textbbox((0, 0), wt_text, font=f_wt)
    wt_w = wt_box[2] - wt_box[0]
    draw.text((p_right - 42 - wt_w, footer_y + 12), wt_text, fill=theme_color, font=f_wt)

    # Bottom stripe
    draw.rounded_rectangle([p_left + 22, p_bottom - 18, p_right - 22, p_bottom - 8], radius=4, fill=theme_color)

    # Save image
    out_path = os.path.join(OUTPUT_DIR, f"{p_info['sku'].lower().replace('-', '_')}.jpg")
    img.save(out_path, quality=95)
    return out_path

print("Regenerating all 17 remaining spice packaging mockups with photorealistic textured window...")
for p in PRODUCTS:
    path = generate_packaging_image(p)
    print(f"Generated {p['sku']}: {p['name']} -> {path}")

print("All 17 mockups generated successfully!")

