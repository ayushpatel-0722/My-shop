import json
import os
import urllib.request
import urllib.error

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
with open(os.path.join(SCRIPT_DIR, "spice_images_registry.json"), "r") as f:
    SPICE_IMAGE_MAP = json.load(f)

API_KEY = "AIzaSyDtmFalx3VDu2a-byx7hoxZKe1a2n9maG8"
PROJECT_ID = "myshop-8bd4d"
COMPANY_ID = "masala-mart"

ADMIN_EMAIL = "ayushpatel112428@gmail.com"
ADMIN_PASS = "Ayushpatel@112428@"
ADMIN_NAME = "Ayush Patel"
ADMIN_PHONE = "9876543210"

def to_fs_val(v):
    if v is None:
        return {'nullValue': None}
    elif isinstance(v, bool):
        return {'booleanValue': v}
    elif isinstance(v, int):
        return {'integerValue': str(v)}
    elif isinstance(v, float):
        return {'doubleValue': v}
    elif isinstance(v, str):
        return {'stringValue': v}
    elif isinstance(v, list):
        return {'arrayValue': {'values': [to_fs_val(x) for x in v]} if v else {}}
    elif isinstance(v, dict):
        return {'mapValue': {'fields': {k: to_fs_val(val) for k, val in v.items()}} if v else {}}
    else:
        return {'stringValue': str(v)}

def to_fs_doc(d):
    return {'fields': {k: to_fs_val(v) for k, v in d.items()}}

def get_auth_token(email, password):
    auth_url = f"https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key={API_KEY}"
    payload = json.dumps({"email": email, "password": password, "returnSecureToken": True}).encode()
    req = urllib.request.Request(auth_url, data=payload, headers={"Content-Type": "application/json"})
    try:
        res = urllib.request.urlopen(req)
        data = json.loads(res.read().decode())
        print(f"Signed in {email} -> UID: {data['localId']}")
        return data["idToken"], data["localId"]
    except urllib.error.HTTPError as e:
        err = json.loads(e.read().decode())
        msg = err.get("error", {}).get("message", "")
        if "EMAIL_NOT_FOUND" in msg or "INVALID_PASSWORD" in msg or "INVALID_LOGIN_CREDENTIALS" in msg:
            signup_url = f"https://identitytoolkit.googleapis.com/v1/accounts:signUp?key={API_KEY}"
            s_req = urllib.request.Request(signup_url, data=payload, headers={"Content-Type": "application/json"})
            try:
                s_res = urllib.request.urlopen(s_req)
                s_data = json.loads(s_res.read().decode())
                print(f"Created new auth user {email} -> UID: {s_data['localId']}")
                return s_data["idToken"], s_data["localId"]
            except urllib.error.HTTPError as se:
                print(f"Sign up error for {email}: {se.read().decode()}")
                raise
        else:
            print(f"Auth error for {email}: {msg}")
            raise

print("==> Authenticating Admin for Masala Mart...")
token, uid = get_auth_token(ADMIN_EMAIL, ADMIN_PASS)

headers = {
    "Authorization": f"Bearer {token}",
    "Content-Type": "application/json"
}

def patch_doc(path, data, auth_token=None):
    url = f"https://firestore.googleapis.com/v1/projects/{PROJECT_ID}/databases/(default)/documents/{path}"
    payload = to_fs_doc(data)
    h = headers.copy()
    if auth_token:
        h["Authorization"] = f"Bearer {auth_token}"
    req = urllib.request.Request(url, data=json.dumps(payload).encode(), headers=h, method="PATCH")
    try:
        res = urllib.request.urlopen(req)
        return json.loads(res.read().decode())
    except urllib.error.HTTPError as e:
        print(f"Error writing {path}: {e.code} - {e.read().decode()}")
        raise

# 1. Company Setup
print(f"==> Setting up Company: {COMPANY_ID}")
weekly_hours = [
    {"day": "Mon", "openTime": "08:00", "closeTime": "21:00", "isClosed": False},
    {"day": "Tue", "openTime": "08:00", "closeTime": "21:00", "isClosed": False},
    {"day": "Wed", "openTime": "08:00", "closeTime": "21:00", "isClosed": False},
    {"day": "Thu", "openTime": "08:00", "closeTime": "21:00", "isClosed": False},
    {"day": "Fri", "openTime": "08:00", "closeTime": "21:00", "isClosed": False},
    {"day": "Sat", "openTime": "08:00", "closeTime": "22:00", "isClosed": False},
    {"day": "Sun", "openTime": "09:00", "closeTime": "20:00", "isClosed": False},
]

company_data = {
    "id": COMPANY_ID,
    "name": "Masala Mart",
    "slug": "masala-mart",
    "type": "Spices & Masala",
    "category": "Grocery / Spices & Cooking Ingredients",
    "details": "Premium Indian spices, authentic masala blends, whole spices and aromatic cooking ingredients for everyday Indian cooking.",
    "address": "Plot 42, Spices Market, Ring Road, Unjha, Gujarat 384170, India",
    "companyPassword": ADMIN_PASS,
    "currency": "INR",
    "deliveryTypes": ["self_pickup", "home_delivery"],
    "minOrderAmount": 600.0,
    "minOrder": 600.0,
    "minOrderAmt": 600.0,
    "logoUrl": "https://images.unsplash.com/photo-1596040033229-a9821ebd058d?w=500&auto=format&fit=crop&q=80",
    "bannerUrl": "https://images.unsplash.com/photo-1532336414038-cf19250c5757?w=1200&auto=format&fit=crop&q=80",
    "profileImageUrl": "https://images.unsplash.com/photo-1509358271058-acd22cc93898?w=800&auto=format&fit=crop&q=80",
    "status": "active",
    "rating": 4.95,
    "reviewCount": 86,
    "followers": 512,
    "isVerified": True,
    "handlingMinutes": 15,
    "deliveryMinutes": 45,
    "weeklyHours": weekly_hours,
    "openingDate": "2026-10-08T08:00:00.000Z"
}

patch_doc(f"companies/{COMPANY_ID}", company_data)
print("Company saved successfully.")

# 2. Link Admin
print("==> Linking Admin Account...")
adm_doc = {
    "id": uid,
    "companyId": COMPANY_ID,
    "name": ADMIN_NAME,
    "email": ADMIN_EMAIL,
    "mobileNumber": ADMIN_PHONE,
    "address": "Plot 42, Spices Market, Ring Road, Unjha, Gujarat, India",
    "gender": "male",
    "emailVerified": True
}
patch_doc(f"companies/{COMPANY_ID}/admins/{uid}", adm_doc, auth_token=token)

user_doc = {
    "id": uid,
    "role": "admin",
    "companyId": COMPANY_ID,
    "companyName": "Masala Mart",
    "email": ADMIN_EMAIL,
    "name": ADMIN_NAME,
    "mobileNumber": ADMIN_PHONE,
    "isActive": True
}
patch_doc(f"users/{uid}", user_doc, auth_token=token)
print(f"Admin {ADMIN_EMAIL} successfully linked to {COMPANY_ID}!")

# 3. Create 4 Categories
print("==> Creating 4 Categories...")
categories = [
    {
        "id": "cat-masala-powders",
        "name": "Masala Powders",
        "companyId": COMPANY_ID,
        "details": "Authentic Indian masala powders prepared from carefully selected spices to add rich aroma, flavor and depth to everyday cooking.",
        "type": "Grocery / Spices & Cooking Ingredients",
        "iconUrl": "https://files.catbox.moe/tu69lj.jpg",
        "sortOrder": 1,
        "productList": [
            "mas-gar-001", "mas-tur-002", "mas-chi-003", "mas-cor-004",
            "mas-cum-005", "mas-kkm-006", "mas-cha-007", "mas-bpp-008"
        ]
    },
    {
        "id": "cat-whole-spices",
        "name": "Whole Spices",
        "companyId": COMPANY_ID,
        "details": "Premium whole spices selected for freshness and aroma, suitable for traditional Indian cooking, tempering and spice blends.",
        "type": "Grocery / Spices & Cooking Ingredients",
        "iconUrl": "https://files.catbox.moe/73bt8g.jpg",
        "sortOrder": 2,
        "productList": [
            "mas-cin-009", "mas-cnp-010", "mas-car-011", "mas-clo-012",
            "mas-bpw-013", "mas-cse-014", "mas-cos-015"
        ]
    },
    {
        "id": "cat-specialty-blended",
        "name": "Specialty & Blended Masala",
        "companyId": COMPANY_ID,
        "details": "Carefully balanced spice blends created for popular Indian dishes and regional recipes.",
        "type": "Grocery / Spices & Cooking Ingredients",
        "iconUrl": "https://files.catbox.moe/19kxsd.jpg",
        "sortOrder": 3,
        "productList": [
            "mas-bir-016", "mas-pav-017", "mas-cho-018", "mas-pan-019",
            "mas-tan-020", "mas-sam-021", "mas-ras-022", "mas-cur-023"
        ]
    },
    {
        "id": "cat-premium-flavoured",
        "name": "Premium & Flavoured Spices",
        "companyId": COMPANY_ID,
        "details": "Premium aromatic spices and specialty ingredients for cooking, baking and beverages.",
        "type": "Grocery / Spices & Cooking Ingredients",
        "iconUrl": "https://files.catbox.moe/o5nqkz.jpg",
        "sortOrder": 4,
        "productList": [
            "mas-kcp-024", "mas-gin-025", "mas-fen-026", "mas-cap-027",
            "mas-nut-028", "mas-cnp-029", "mas-mix-030"
        ]
    }
]

for cat in categories:
    patch_doc(f"companies/{COMPANY_ID}/categories/{cat['id']}", cat)
print("Categories saved successfully.")

# Helper builders
def make_specs(items):
    return [{"name": k, "value": v} for k, v in items.items()]

def make_highlights(items):
    return [{"title": t, "description": d} for t, d in items]

def make_all_details(sections):
    res = []
    for s in sections:
        if s["type"] == "text":
            res.append({"title": s["title"], "type": "text", "content": s["content"]})
        elif s["type"] == "keyValue":
            res.append({"title": s["title"], "type": "keyValue", "items": make_specs(s["items"])})
    return res

# 4. Products Definition (30 Products)
products_data = [
    # ── CATEGORY 1: MASALA POWDERS (8) ──
    {
        "id": "mas-gar-001",
        "sku": "MAS-GAR-001",
        "name": "Premium Garam Masala Powder",
        "categoryId": "cat-masala-powders",
        "productType": "Masala Powder",
        "basePack": "100 g",
        "profile": "Warm, aromatic and balanced",
        "intensity": "Medium-Strong",
        "mrp": 120.0,
        "selling": 99.0,
        "stock": 180,
        "img": ["https://images.unsplash.com/photo-1596040033229-a9821ebd058d?w=800&auto=format&fit=crop&q=80"],
        "variants": [
            {"id": "v-gar-50", "sku": "MAS-GAR-001-50G", "size": "50 g", "unit": 50, "mrp": 65.0, "price": 55.0, "stock": 80},
            {"id": "v-gar-100", "sku": "MAS-GAR-001-100G", "size": "100 g", "unit": 100, "mrp": 120.0, "price": 99.0, "stock": 180},
            {"id": "v-gar-200", "sku": "MAS-GAR-001-200G", "size": "200 g", "unit": 200, "mrp": 230.0, "price": 189.0, "stock": 120},
            {"id": "v-gar-500", "sku": "MAS-GAR-001-500G", "size": "500 g", "unit": 500, "mrp": 540.0, "price": 449.0, "stock": 50},
        ],
        "tags": ["Garam Masala", "Indian Spices", "Spice Powder", "Masala Mart", "Aromatic Blend", "Curry Masala"]
    },
    {
        "id": "mas-tur-002",
        "sku": "MAS-TUR-002",
        "name": "Pure Turmeric Powder",
        "categoryId": "cat-masala-powders",
        "productType": "Spice Powder",
        "basePack": "200 g",
        "profile": "Earthy and aromatic",
        "intensity": "Medium",
        "mrp": 95.0,
        "selling": 79.0,
        "stock": 250,
        "img": ["https://images.unsplash.com/photo-1615485290382-441e4d049cb5?w=800&auto=format&fit=crop&q=80"],
        "variants": [
            {"id": "v-tur-100", "sku": "MAS-TUR-002-100G", "size": "100 g", "unit": 100, "mrp": 50.0, "price": 42.0, "stock": 100},
            {"id": "v-tur-200", "sku": "MAS-TUR-002-200G", "size": "200 g", "unit": 200, "mrp": 95.0, "price": 79.0, "stock": 250},
            {"id": "v-tur-500", "sku": "MAS-TUR-002-500G", "size": "500 g", "unit": 500, "mrp": 220.0, "price": 179.0, "stock": 150},
            {"id": "v-tur-1kg", "sku": "MAS-TUR-002-1KG", "size": "1 kg", "unit": 1000, "mrp": 420.0, "price": 339.0, "stock": 70},
        ],
        "tags": ["Turmeric", "Haldi", "Pure Turmeric", "Indian Spices", "Golden Spice", "Masala Mart"]
    },
    {
        "id": "mas-chi-003",
        "sku": "MAS-CHI-003",
        "name": "Premium Red Chilli Powder",
        "categoryId": "cat-masala-powders",
        "productType": "Chilli Powder",
        "basePack": "200 g",
        "profile": "Rich colour with balanced heat",
        "intensity": "Medium-Hot",
        "mrp": 110.0,
        "selling": 89.0,
        "stock": 220,
        "img": ["https://images.unsplash.com/photo-1596040033229-a9821ebd058d?w=800&auto=format&fit=crop&q=80"],
        "variants": [
            {"id": "v-chi-100", "sku": "MAS-CHI-003-100G", "size": "100 g", "unit": 100, "mrp": 60.0, "price": 49.0, "stock": 90},
            {"id": "v-chi-200", "sku": "MAS-CHI-003-200G", "size": "200 g", "unit": 200, "mrp": 110.0, "price": 89.0, "stock": 220},
            {"id": "v-chi-500", "sku": "MAS-CHI-003-500G", "size": "500 g", "unit": 500, "mrp": 260.0, "price": 209.0, "stock": 110},
            {"id": "v-chi-1kg", "sku": "MAS-CHI-003-1KG", "size": "1 kg", "unit": 1000, "mrp": 490.0, "price": 399.0, "stock": 60},
        ],
        "tags": ["Chilli Powder", "Mirchi", "Red Chilli", "Spicy", "Indian Spices", "Masala Mart"]
    },
    {
        "id": "mas-cor-004",
        "sku": "MAS-COR-004",
        "name": "Coriander Powder",
        "categoryId": "cat-masala-powders",
        "productType": "Ground Spice",
        "basePack": "200 g",
        "profile": "Fresh, citrusy and earthy",
        "intensity": "Mild-Medium",
        "mrp": 85.0,
        "selling": 69.0,
        "stock": 190,
        "img": ["https://images.unsplash.com/photo-1532336414038-cf19250c5757?w=800&auto=format&fit=crop&q=80"],
        "variants": [
            {"id": "v-cor-100", "sku": "MAS-COR-004-100G", "size": "100 g", "unit": 100, "mrp": 45.0, "price": 38.0, "stock": 90},
            {"id": "v-cor-200", "sku": "MAS-COR-004-200G", "size": "200 g", "unit": 200, "mrp": 85.0, "price": 69.0, "stock": 190},
            {"id": "v-cor-500", "sku": "MAS-COR-004-500G", "size": "500 g", "unit": 500, "mrp": 199.0, "price": 159.0, "stock": 100},
            {"id": "v-cor-1kg", "sku": "MAS-COR-004-1KG", "size": "1 kg", "unit": 1000, "mrp": 380.0, "price": 299.0, "stock": 50},
        ],
        "tags": ["Coriander", "Dhania", "Dhania Powder", "Indian Spices", "Ground Spice", "Masala Mart"]
    },
    {
        "id": "mas-cum-005",
        "sku": "MAS-CUM-005",
        "name": "Roasted Cumin Powder",
        "categoryId": "cat-masala-powders",
        "productType": "Ground Spice",
        "basePack": "100 g",
        "profile": "Smoky, earthy and aromatic",
        "intensity": "Medium",
        "mrp": 90.0,
        "selling": 75.0,
        "stock": 160,
        "img": ["https://images.unsplash.com/photo-1596040033229-a9821ebd058d?w=800&auto=format&fit=crop&q=80"],
        "variants": [
            {"id": "v-cum-50", "sku": "MAS-CUM-005-50G", "size": "50 g", "unit": 50, "mrp": 50.0, "price": 42.0, "stock": 70},
            {"id": "v-cum-100", "sku": "MAS-CUM-005-100G", "size": "100 g", "unit": 100, "mrp": 90.0, "price": 75.0, "stock": 160},
            {"id": "v-cum-200", "sku": "MAS-CUM-005-200G", "size": "200 g", "unit": 200, "mrp": 175.0, "price": 142.0, "stock": 90},
            {"id": "v-cum-500", "sku": "MAS-CUM-005-500G", "size": "500 g", "unit": 500, "mrp": 420.0, "price": 339.0, "stock": 40},
        ],
        "tags": ["Cumin", "Jeera", "Roasted Jeera", "Jeera Powder", "Indian Spices", "Masala Mart"]
    },
    {
        "id": "mas-kkm-006",
        "sku": "MAS-KKM-006",
        "name": "Kitchen King Masala",
        "categoryId": "cat-masala-powders",
        "productType": "Blended Masala",
        "basePack": "100 g",
        "profile": "Rich, aromatic and savoury",
        "intensity": "Medium",
        "mrp": 115.0,
        "selling": 92.0,
        "stock": 175,
        "img": ["https://images.unsplash.com/photo-1615485290382-441e4d049cb5?w=800&auto=format&fit=crop&q=80"],
        "variants": [
            {"id": "v-kkm-50", "sku": "MAS-KKM-006-50G", "size": "50 g", "unit": 50, "mrp": 62.0, "price": 52.0, "stock": 80},
            {"id": "v-kkm-100", "sku": "MAS-KKM-006-100G", "size": "100 g", "unit": 100, "mrp": 115.0, "price": 92.0, "stock": 175},
            {"id": "v-kkm-200", "sku": "MAS-KKM-006-200G", "size": "200 g", "unit": 200, "mrp": 220.0, "price": 175.0, "stock": 110},
        ],
        "tags": ["Kitchen King", "All-in-one Masala", "Curry Blend", "Indian Spices", "Masala Mart"]
    },
    {
        "id": "mas-cha-007",
        "sku": "MAS-CHA-007",
        "name": "Chaat Masala",
        "categoryId": "cat-masala-powders",
        "productType": "Masala Blend",
        "basePack": "100 g",
        "profile": "Tangy, salty and aromatic",
        "intensity": "Medium",
        "mrp": 85.0,
        "selling": 69.0,
        "stock": 210,
        "img": ["https://images.unsplash.com/photo-1532336414038-cf19250c5757?w=800&auto=format&fit=crop&q=80"],
        "variants": [
            {"id": "v-cha-50", "sku": "MAS-CHA-007-50G", "size": "50 g", "unit": 50, "mrp": 48.0, "price": 39.0, "stock": 90},
            {"id": "v-cha-100", "sku": "MAS-CHA-007-100G", "size": "100 g", "unit": 100, "mrp": 85.0, "price": 69.0, "stock": 210},
            {"id": "v-cha-200", "sku": "MAS-CHA-007-200G", "size": "200 g", "unit": 200, "mrp": 160.0, "price": 129.0, "stock": 130},
        ],
        "tags": ["Chaat Masala", "Tangy Spice", "Street Food Masala", "Indian Spices", "Masala Mart"]
    },
    {
        "id": "mas-bpp-008",
        "sku": "MAS-BPP-008",
        "name": "Black Pepper Powder",
        "categoryId": "cat-masala-powders",
        "productType": "Ground Spice",
        "basePack": "100 g",
        "profile": "Sharp, warm and peppery",
        "intensity": "Hot",
        "mrp": 140.0,
        "selling": 115.0,
        "stock": 140,
        "img": ["https://images.unsplash.com/photo-1509358271058-acd22cc93898?w=800&auto=format&fit=crop&q=80"],
        "variants": [
            {"id": "v-bpp-50", "sku": "MAS-BPP-008-50G", "size": "50 g", "unit": 50, "mrp": 75.0, "price": 62.0, "stock": 70},
            {"id": "v-bpp-100", "sku": "MAS-BPP-008-100G", "size": "100 g", "unit": 100, "mrp": 140.0, "price": 115.0, "stock": 140},
            {"id": "v-bpp-200", "sku": "MAS-BPP-008-200G", "size": "200 g", "unit": 200, "mrp": 270.0, "price": 219.0, "stock": 80},
        ],
        "tags": ["Black Pepper", "Kali Mirch", "Pepper Powder", "Ground Spice", "Masala Mart"]
    },

    # ── CATEGORY 2: WHOLE SPICES (7) ──
    {
        "id": "mas-cin-009",
        "sku": "MAS-CIN-009",
        "name": "Premium Cinnamon Sticks",
        "categoryId": "cat-whole-spices",
        "productType": "Whole Spice",
        "basePack": "100 g",
        "profile": "Sweet, warm and woody",
        "intensity": "Medium",
        "mrp": 150.0,
        "selling": 125.0,
        "stock": 130,
        "img": ["https://images.unsplash.com/photo-1509358271058-acd22cc93898?w=800&auto=format&fit=crop&q=80"],
        "variants": [
            {"id": "v-cin-50", "sku": "MAS-CIN-009-50G", "size": "50 g", "unit": 50, "mrp": 80.0, "price": 68.0, "stock": 60},
            {"id": "v-cin-100", "sku": "MAS-CIN-009-100G", "size": "100 g", "unit": 100, "mrp": 150.0, "price": 125.0, "stock": 130},
            {"id": "v-cin-250", "sku": "MAS-CIN-009-250G", "size": "250 g", "unit": 250, "mrp": 350.0, "price": 289.0, "stock": 70},
            {"id": "v-cin-500", "sku": "MAS-CIN-009-500G", "size": "500 g", "unit": 500, "mrp": 670.0, "price": 549.0, "stock": 40},
        ],
        "tags": ["Cinnamon", "Dalchini", "Cinnamon Sticks", "Whole Spices", "Masala Mart"]
    },
    {
        "id": "mas-cnp-010",
        "sku": "MAS-CNP-010",
        "name": "Pure Cinnamon Powder",
        "categoryId": "cat-whole-spices",
        "productType": "Ground Cinnamon",
        "basePack": "100 g",
        "profile": "Sweet, warm and aromatic",
        "intensity": "Medium",
        "mrp": 135.0,
        "selling": 110.0,
        "stock": 140,
        "img": ["https://images.unsplash.com/photo-1596040033229-a9821ebd058d?w=800&auto=format&fit=crop&q=80"],
        "variants": [
            {"id": "v-cnp-50", "sku": "MAS-CNP-010-50G", "size": "50 g", "unit": 50, "mrp": 72.0, "price": 59.0, "stock": 70},
            {"id": "v-cnp-100", "sku": "MAS-CNP-010-100G", "size": "100 g", "unit": 100, "mrp": 135.0, "price": 110.0, "stock": 140},
            {"id": "v-cnp-200", "sku": "MAS-CNP-010-200G", "size": "200 g", "unit": 200, "mrp": 260.0, "price": 209.0, "stock": 80},
        ],
        "tags": ["Cinnamon Powder", "Dalchini Powder", "Cooking & Baking", "Aromatic Spice", "Masala Mart"]
    },
    {
        "id": "mas-car-011",
        "sku": "MAS-CAR-011",
        "name": "Green Cardamom",
        "categoryId": "cat-whole-spices",
        "productType": "Whole Spice",
        "basePack": "50 g",
        "profile": "Sweet, floral and refreshing",
        "intensity": "Strong",
        "mrp": 220.0,
        "selling": 185.0,
        "stock": 110,
        "img": ["https://images.unsplash.com/photo-1509358271058-acd22cc93898?w=800&auto=format&fit=crop&q=80"],
        "variants": [
            {"id": "v-car-25", "sku": "MAS-CAR-011-25G", "size": "25 g", "unit": 25, "mrp": 115.0, "price": 99.0, "stock": 60},
            {"id": "v-car-50", "sku": "MAS-CAR-011-50G", "size": "50 g", "unit": 50, "mrp": 220.0, "price": 185.0, "stock": 110},
            {"id": "v-car-100", "sku": "MAS-CAR-011-100G", "size": "100 g", "unit": 100, "mrp": 420.0, "price": 349.0, "stock": 75},
            {"id": "v-car-250", "sku": "MAS-CAR-011-250G", "size": "250 g", "unit": 250, "mrp": 990.0, "price": 820.0, "stock": 35},
        ],
        "tags": ["Cardamom", "Elaichi", "Green Elaichi", "Premium Whole Spices", "Masala Mart"]
    },
    {
        "id": "mas-clo-012",
        "sku": "MAS-CLO-012",
        "name": "Whole Cloves",
        "categoryId": "cat-whole-spices",
        "productType": "Whole Spice",
        "basePack": "100 g",
        "profile": "Warm, strong and aromatic",
        "intensity": "Strong",
        "mrp": 190.0,
        "selling": 155.0,
        "stock": 125,
        "img": ["https://images.unsplash.com/photo-1509358271058-acd22cc93898?w=800&auto=format&fit=crop&q=80"],
        "variants": [
            {"id": "v-clo-50", "sku": "MAS-CLO-012-50G", "size": "50 g", "unit": 50, "mrp": 100.0, "price": 82.0, "stock": 65},
            {"id": "v-clo-100", "sku": "MAS-CLO-012-100G", "size": "100 g", "unit": 100, "mrp": 190.0, "price": 155.0, "stock": 125},
            {"id": "v-clo-250", "sku": "MAS-CLO-012-250G", "size": "250 g", "unit": 250, "mrp": 450.0, "price": 369.0, "stock": 50},
        ],
        "tags": ["Cloves", "Laung", "Whole Cloves", "Aromatic Spice", "Masala Mart"]
    },
    {
        "id": "mas-bpw-013",
        "sku": "MAS-BPW-013",
        "name": "Whole Black Pepper",
        "categoryId": "cat-whole-spices",
        "productType": "Whole Spice",
        "basePack": "100 g",
        "profile": "Sharp, spicy and earthy",
        "intensity": "Hot",
        "mrp": 160.0,
        "selling": 130.0,
        "stock": 150,
        "img": ["https://images.unsplash.com/photo-1509358271058-acd22cc93898?w=800&auto=format&fit=crop&q=80"],
        "variants": [
            {"id": "v-bpw-50", "sku": "MAS-BPW-013-50G", "size": "50 g", "unit": 50, "mrp": 85.0, "price": 69.0, "stock": 70},
            {"id": "v-bpw-100", "sku": "MAS-BPW-013-100G", "size": "100 g", "unit": 100, "mrp": 160.0, "price": 130.0, "stock": 150},
            {"id": "v-bpw-250", "sku": "MAS-BPW-013-250G", "size": "250 g", "unit": 250, "mrp": 380.0, "price": 309.0, "stock": 80},
            {"id": "v-bpw-500", "sku": "MAS-BPW-013-500G", "size": "500 g", "unit": 500, "mrp": 720.0, "price": 589.0, "stock": 45},
        ],
        "tags": ["Black Pepper", "Kali Mirch", "Whole Peppercorns", "Whole Spices", "Masala Mart"]
    },
    {
        "id": "mas-cse-014",
        "sku": "MAS-CSE-014",
        "name": "Cumin Seeds",
        "categoryId": "cat-whole-spices",
        "productType": "Whole Spice",
        "basePack": "200 g",
        "profile": "Earthy, warm and aromatic",
        "intensity": "Medium",
        "mrp": 130.0,
        "selling": 105.0,
        "stock": 210,
        "img": ["https://images.unsplash.com/photo-1509358271058-acd22cc93898?w=800&auto=format&fit=crop&q=80"],
        "variants": [
            {"id": "v-cse-100", "sku": "MAS-CSE-014-100G", "size": "100 g", "unit": 100, "mrp": 70.0, "price": 58.0, "stock": 90},
            {"id": "v-cse-200", "sku": "MAS-CSE-014-200G", "size": "200 g", "unit": 200, "mrp": 130.0, "price": 105.0, "stock": 210},
            {"id": "v-cse-500", "sku": "MAS-CSE-014-500G", "size": "500 g", "unit": 500, "mrp": 310.0, "price": 249.0, "stock": 110},
            {"id": "v-cse-1kg", "sku": "MAS-CSE-014-1KG", "size": "1 kg", "unit": 1000, "mrp": 590.0, "price": 479.0, "stock": 60},
        ],
        "tags": ["Cumin Seeds", "Jeera", "Whole Jeera", "Tempering", "Masala Mart"]
    },
    {
        "id": "mas-cos-015",
        "sku": "MAS-COS-015",
        "name": "Coriander Seeds",
        "categoryId": "cat-whole-spices",
        "productType": "Whole Spice",
        "basePack": "200 g",
        "profile": "Fresh, citrusy and earthy",
        "intensity": "Mild",
        "mrp": 90.0,
        "selling": 72.0,
        "stock": 180,
        "img": ["https://images.unsplash.com/photo-1509358271058-acd22cc93898?w=800&auto=format&fit=crop&q=80"],
        "variants": [
            {"id": "v-cos-100", "sku": "MAS-COS-015-100G", "size": "100 g", "unit": 100, "mrp": 50.0, "price": 40.0, "stock": 80},
            {"id": "v-cos-200", "sku": "MAS-COS-015-200G", "size": "200 g", "unit": 200, "mrp": 90.0, "price": 72.0, "stock": 180},
            {"id": "v-cos-500", "sku": "MAS-COS-015-500G", "size": "500 g", "unit": 500, "mrp": 210.0, "price": 169.0, "stock": 95},
            {"id": "v-cos-1kg", "sku": "MAS-COS-015-1KG", "size": "1 kg", "unit": 1000, "mrp": 390.0, "price": 315.0, "stock": 50},
        ],
        "tags": ["Coriander Seeds", "Dhania Seeds", "Whole Spices", "Indian Cooking", "Masala Mart"]
    },

    # ── CATEGORY 3: SPECIALTY & BLENDED MASALA (8) ──
    {
        "id": "mas-bir-016",
        "sku": "MAS-BIR-016",
        "name": "Premium Biryani Masala",
        "categoryId": "cat-specialty-blended",
        "productType": "Blended Masala",
        "basePack": "100 g",
        "profile": "Aromatic, rich and warm",
        "suitableFor": "Vegetable, chicken and meat biryani",
        "intensity": "Medium-Strong",
        "mrp": 130.0,
        "selling": 105.0,
        "stock": 200,
        "img": ["https://images.unsplash.com/photo-1596040033229-a9821ebd058d?w=800&auto=format&fit=crop&q=80"],
        "variants": [
            {"id": "v-bir-50", "sku": "MAS-BIR-016-50G", "size": "50 g", "unit": 50, "mrp": 70.0, "price": 58.0, "stock": 90},
            {"id": "v-bir-100", "sku": "MAS-BIR-016-100G", "size": "100 g", "unit": 100, "mrp": 130.0, "price": 105.0, "stock": 200},
            {"id": "v-bir-200", "sku": "MAS-BIR-016-200G", "size": "200 g", "unit": 200, "mrp": 250.0, "price": 199.0, "stock": 120},
        ],
        "tags": ["Biryani Masala", "Dum Biryani", "Specialty Masala", "Indian Spices", "Masala Mart"]
    },
    {
        "id": "mas-pav-017",
        "sku": "MAS-PAV-017",
        "name": "Pav Bhaji Masala",
        "categoryId": "cat-specialty-blended",
        "productType": "Blended Masala",
        "basePack": "100 g",
        "profile": "Tangy, spicy and aromatic",
        "suitableFor": "Pav Bhaji",
        "intensity": "Medium",
        "mrp": 110.0,
        "selling": 89.0,
        "stock": 180,
        "img": ["https://images.unsplash.com/photo-1615485290382-441e4d049cb5?w=800&auto=format&fit=crop&q=80"],
        "variants": [
            {"id": "v-pav-50", "sku": "MAS-PAV-017-50G", "size": "50 g", "unit": 50, "mrp": 60.0, "price": 49.0, "stock": 80},
            {"id": "v-pav-100", "sku": "MAS-PAV-017-100G", "size": "100 g", "unit": 100, "mrp": 110.0, "price": 89.0, "stock": 180},
            {"id": "v-pav-200", "sku": "MAS-PAV-017-200G", "size": "200 g", "unit": 200, "mrp": 210.0, "price": 169.0, "stock": 110},
        ],
        "tags": ["Pav Bhaji Masala", "Mumbai Pav Bhaji", "Blended Masala", "Street Food", "Masala Mart"]
    },
    {
        "id": "mas-cho-018",
        "sku": "MAS-CHO-018",
        "name": "Chole Masala",
        "categoryId": "cat-specialty-blended",
        "productType": "Blended Masala",
        "basePack": "100 g",
        "profile": "Tangy, earthy and spicy",
        "suitableFor": "Chole / Chickpea Curry",
        "intensity": "Medium",
        "mrp": 110.0,
        "selling": 89.0,
        "stock": 170,
        "img": ["https://images.unsplash.com/photo-1596040033229-a9821ebd058d?w=800&auto=format&fit=crop&q=80"],
        "variants": [
            {"id": "v-cho-50", "sku": "MAS-CHO-018-50G", "size": "50 g", "unit": 50, "mrp": 60.0, "price": 49.0, "stock": 75},
            {"id": "v-cho-100", "sku": "MAS-CHO-018-100G", "size": "100 g", "unit": 100, "mrp": 110.0, "price": 89.0, "stock": 170},
            {"id": "v-cho-200", "sku": "MAS-CHO-018-200G", "size": "200 g", "unit": 200, "mrp": 210.0, "price": 169.0, "stock": 100},
        ],
        "tags": ["Chole Masala", "Amritsari Chole", "Chickpea Curry", "Specialty Masala", "Masala Mart"]
    },
    {
        "id": "mas-pan-019",
        "sku": "MAS-PAN-019",
        "name": "Paneer Masala",
        "categoryId": "cat-specialty-blended",
        "productType": "Blended Masala",
        "basePack": "100 g",
        "profile": "Rich, creamy and aromatic",
        "suitableFor": "Paneer dishes",
        "intensity": "Medium",
        "mrp": 115.0,
        "selling": 94.0,
        "stock": 190,
        "img": ["https://images.unsplash.com/photo-1615485290382-441e4d049cb5?w=800&auto=format&fit=crop&q=80"],
        "variants": [
            {"id": "v-pan-50", "sku": "MAS-PAN-019-50G", "size": "50 g", "unit": 50, "mrp": 62.0, "price": 52.0, "stock": 85},
            {"id": "v-pan-100", "sku": "MAS-PAN-019-100G", "size": "100 g", "unit": 100, "mrp": 115.0, "price": 94.0, "stock": 190},
            {"id": "v-pan-200", "sku": "MAS-PAN-019-200G", "size": "200 g", "unit": 200, "mrp": 220.0, "price": 179.0, "stock": 115},
        ],
        "tags": ["Paneer Masala", "Shahi Paneer", "Paneer Butter Masala", "Curry Blend", "Masala Mart"]
    },
    {
        "id": "mas-tan-020",
        "sku": "MAS-TAN-020",
        "name": "Tandoori Masala",
        "categoryId": "cat-specialty-blended",
        "productType": "Blended Masala",
        "basePack": "100 g",
        "profile": "Smoky, spicy and aromatic",
        "suitableFor": "Tandoori and grilled recipes",
        "intensity": "Medium-Hot",
        "mrp": 125.0,
        "selling": 99.0,
        "stock": 160,
        "img": ["https://images.unsplash.com/photo-1596040033229-a9821ebd058d?w=800&auto=format&fit=crop&q=80"],
        "variants": [
            {"id": "v-tan-50", "sku": "MAS-TAN-020-50G", "size": "50 g", "unit": 50, "mrp": 68.0, "price": 55.0, "stock": 70},
            {"id": "v-tan-100", "sku": "MAS-TAN-020-100G", "size": "100 g", "unit": 100, "mrp": 125.0, "price": 99.0, "stock": 160},
            {"id": "v-tan-200", "sku": "MAS-TAN-020-200G", "size": "200 g", "unit": 200, "mrp": 240.0, "price": 189.0, "stock": 95},
        ],
        "tags": ["Tandoori Masala", "Tikka", "Barbeque", "Smoky Spice", "Masala Mart"]
    },
    {
        "id": "mas-sam-021",
        "sku": "MAS-SAM-021",
        "name": "Sambar Masala",
        "categoryId": "cat-specialty-blended",
        "productType": "Blended Masala",
        "basePack": "100 g",
        "profile": "Spicy, earthy and aromatic",
        "suitableFor": "Sambar",
        "intensity": "Medium",
        "mrp": 105.0,
        "selling": 85.0,
        "stock": 210,
        "img": ["https://images.unsplash.com/photo-1532336414038-cf19250c5757?w=800&auto=format&fit=crop&q=80"],
        "variants": [
            {"id": "v-sam-50", "sku": "MAS-SAM-021-50G", "size": "50 g", "unit": 50, "mrp": 58.0, "price": 47.0, "stock": 90},
            {"id": "v-sam-100", "sku": "MAS-SAM-021-100G", "size": "100 g", "unit": 100, "mrp": 105.0, "price": 85.0, "stock": 210},
            {"id": "v-sam-200", "sku": "MAS-SAM-021-200G", "size": "200 g", "unit": 200, "mrp": 200.0, "price": 162.0, "stock": 130},
            {"id": "v-sam-500", "sku": "MAS-SAM-021-500G", "size": "500 g", "unit": 500, "mrp": 480.0, "price": 389.0, "stock": 60},
        ],
        "tags": ["Sambar Masala", "South Indian", "Lentil Curry", "Traditional Spices", "Masala Mart"]
    },
    {
        "id": "mas-ras-022",
        "sku": "MAS-RAS-022",
        "name": "Rasam Masala",
        "categoryId": "cat-specialty-blended",
        "productType": "Blended Masala",
        "basePack": "100 g",
        "profile": "Tangy, peppery and aromatic",
        "suitableFor": "Rasam",
        "intensity": "Medium-Hot",
        "mrp": 105.0,
        "selling": 85.0,
        "stock": 170,
        "img": ["https://images.unsplash.com/photo-1596040033229-a9821ebd058d?w=800&auto=format&fit=crop&q=80"],
        "variants": [
            {"id": "v-ras-50", "sku": "MAS-RAS-022-50G", "size": "50 g", "unit": 50, "mrp": 58.0, "price": 47.0, "stock": 75},
            {"id": "v-ras-100", "sku": "MAS-RAS-022-100G", "size": "100 g", "unit": 100, "mrp": 105.0, "price": 85.0, "stock": 170},
            {"id": "v-ras-200", "sku": "MAS-RAS-022-200G", "size": "200 g", "unit": 200, "mrp": 200.0, "price": 162.0, "stock": 100},
        ],
        "tags": ["Rasam Masala", "Pepper Rasam", "South Indian", "Aromatic Blend", "Masala Mart"]
    },
    {
        "id": "mas-cur-023",
        "sku": "MAS-CUR-023",
        "name": "Everyday Curry Masala",
        "categoryId": "cat-specialty-blended",
        "productType": "Blended Masala",
        "basePack": "100 g",
        "profile": "Balanced, warm and aromatic",
        "suitableFor": "Everyday vegetable and curry dishes",
        "intensity": "Medium",
        "mrp": 100.0,
        "selling": 80.0,
        "stock": 230,
        "img": ["https://images.unsplash.com/photo-1615485290382-441e4d049cb5?w=800&auto=format&fit=crop&q=80"],
        "variants": [
            {"id": "v-cur-50", "sku": "MAS-CUR-023-50G", "size": "50 g", "unit": 50, "mrp": 55.0, "price": 44.0, "stock": 100},
            {"id": "v-cur-100", "sku": "MAS-CUR-023-100G", "size": "100 g", "unit": 100, "mrp": 100.0, "price": 80.0, "stock": 230},
            {"id": "v-cur-200", "sku": "MAS-CUR-023-200G", "size": "200 g", "unit": 200, "mrp": 190.0, "price": 152.0, "stock": 140},
            {"id": "v-cur-500", "sku": "MAS-CUR-023-500G", "size": "500 g", "unit": 500, "mrp": 450.0, "price": 359.0, "stock": 70},
        ],
        "tags": ["Curry Masala", "Sabji Masala", "Daily Cooking", "Vegetable Curry", "Masala Mart"]
    },

    # ── CATEGORY 4: PREMIUM & FLAVOURED SPICES (7) ──
    {
        "id": "mas-kcp-024",
        "sku": "MAS-KCP-024",
        "name": "Kashmiri Chilli Powder",
        "categoryId": "cat-premium-flavoured",
        "productType": "Chilli Powder",
        "basePack": "200 g",
        "profile": "Mild heat with rich red colour",
        "intensity": "Mild-Medium",
        "mrp": 180.0,
        "selling": 149.0,
        "stock": 220,
        "img": ["https://images.unsplash.com/photo-1596040033229-a9821ebd058d?w=800&auto=format&fit=crop&q=80"],
        "variants": [
            {"id": "v-kcp-100", "sku": "MAS-KCP-024-100G", "size": "100 g", "unit": 100, "mrp": 95.0, "price": 79.0, "stock": 110},
            {"id": "v-kcp-200", "sku": "MAS-KCP-024-200G", "size": "200 g", "unit": 200, "mrp": 180.0, "price": 149.0, "stock": 220},
            {"id": "v-kcp-500", "sku": "MAS-KCP-024-500G", "size": "500 g", "unit": 500, "mrp": 420.0, "price": 349.0, "stock": 85},
        ],
        "tags": ["Kashmiri Chilli", "Degi Mirch", "Natural Colour", "Mild Heat", "Masala Mart"]
    },
    {
        "id": "mas-gin-025",
        "sku": "MAS-GIN-025",
        "name": "Dry Ginger Powder",
        "categoryId": "cat-premium-flavoured",
        "productType": "Ground Spice",
        "basePack": "100 g",
        "profile": "Warm, sharp and aromatic",
        "intensity": "Medium-Strong",
        "mrp": 120.0,
        "selling": 99.0,
        "stock": 140,
        "img": ["https://images.unsplash.com/photo-1532336414038-cf19250c5757?w=800&auto=format&fit=crop&q=80"],
        "variants": [
            {"id": "v-gin-50", "sku": "MAS-GIN-025-50G", "size": "50 g", "unit": 50, "mrp": 65.0, "price": 54.0, "stock": 70},
            {"id": "v-gin-100", "sku": "MAS-GIN-025-100G", "size": "100 g", "unit": 100, "mrp": 120.0, "price": 99.0, "stock": 140},
            {"id": "v-gin-200", "sku": "MAS-GIN-025-200G", "size": "200 g", "unit": 200, "mrp": 230.0, "price": 189.0, "stock": 80},
        ],
        "tags": ["Dry Ginger", "Sonth", "Ginger Powder", "Tea Spice", "Baking", "Masala Mart"]
    },
    {
        "id": "mas-fen-026",
        "sku": "MAS-FEN-026",
        "name": "Fennel Powder",
        "categoryId": "cat-premium-flavoured",
        "productType": "Ground Spice",
        "basePack": "100 g",
        "profile": "Sweet, fresh and aromatic",
        "intensity": "Mild",
        "mrp": 95.0,
        "selling": 79.0,
        "stock": 160,
        "img": ["https://images.unsplash.com/photo-1509358271058-acd22cc93898?w=800&auto=format&fit=crop&q=80"],
        "variants": [
            {"id": "v-fen-50", "sku": "MAS-FEN-026-50G", "size": "50 g", "unit": 50, "mrp": 52.0, "price": 42.0, "stock": 75},
            {"id": "v-fen-100", "sku": "MAS-FEN-026-100G", "size": "100 g", "unit": 100, "mrp": 95.0, "price": 79.0, "stock": 160},
            {"id": "v-fen-200", "sku": "MAS-FEN-026-200G", "size": "200 g", "unit": 200, "mrp": 180.0, "price": 149.0, "stock": 90},
        ],
        "tags": ["Fennel Powder", "Saunf", "Sweet Spice", "Digestive Flavor", "Masala Mart"]
    },
    {
        "id": "mas-cap-027",
        "sku": "MAS-CAP-027",
        "name": "Green Cardamom Powder",
        "categoryId": "cat-premium-flavoured",
        "productType": "Ground Spice",
        "basePack": "50 g",
        "profile": "Sweet, floral and refreshing",
        "intensity": "Strong",
        "mrp": 240.0,
        "selling": 199.0,
        "stock": 90,
        "img": ["https://images.unsplash.com/photo-1509358271058-acd22cc93898?w=800&auto=format&fit=crop&q=80"],
        "variants": [
            {"id": "v-cap-25", "sku": "MAS-CAP-027-25G", "size": "25 g", "unit": 25, "mrp": 125.0, "price": 105.0, "stock": 50},
            {"id": "v-cap-50", "sku": "MAS-CAP-027-50G", "size": "50 g", "unit": 50, "mrp": 240.0, "price": 199.0, "stock": 90},
            {"id": "v-cap-100", "sku": "MAS-CAP-027-100G", "size": "100 g", "unit": 100, "mrp": 460.0, "price": 380.0, "stock": 60},
        ],
        "tags": ["Cardamom Powder", "Elaichi Powder", "Dessert Spice", "Chai Masala", "Masala Mart"]
    },
    {
        "id": "mas-nut-028",
        "sku": "MAS-NUT-028",
        "name": "Nutmeg Powder",
        "categoryId": "cat-premium-flavoured",
        "productType": "Ground Spice",
        "basePack": "50 g",
        "profile": "Warm, sweet and woody",
        "intensity": "Strong",
        "mrp": 190.0,
        "selling": 159.0,
        "stock": 85,
        "img": ["https://images.unsplash.com/photo-1509358271058-acd22cc93898?w=800&auto=format&fit=crop&q=80"],
        "variants": [
            {"id": "v-nut-25", "sku": "MAS-NUT-028-25G", "size": "25 g", "unit": 25, "mrp": 100.0, "price": 84.0, "stock": 50},
            {"id": "v-nut-50", "sku": "MAS-NUT-028-50G", "size": "50 g", "unit": 50, "mrp": 190.0, "price": 159.0, "stock": 85},
            {"id": "v-nut-100", "sku": "MAS-NUT-028-100G", "size": "100 g", "unit": 100, "mrp": 370.0, "price": 305.0, "stock": 55},
        ],
        "tags": ["Nutmeg Powder", "Jaiphal", "Sweet Spice", "Baking Spice", "Masala Mart"]
    },
    {
        "id": "mas-cnp-029",
        "sku": "MAS-CNP-029",
        "name": "Premium Cinnamon Powder",
        "categoryId": "cat-premium-flavoured",
        "productType": "Ground Spice",
        "basePack": "100 g",
        "profile": "Sweet, warm and aromatic",
        "suitableFor": "Cooking and baking",
        "intensity": "Medium",
        "mrp": 145.0,
        "selling": 119.0,
        "stock": 130,
        "img": ["https://images.unsplash.com/photo-1596040033229-a9821ebd058d?w=800&auto=format&fit=crop&q=80"],
        "variants": [
            {"id": "v-cnp2-50", "sku": "MAS-CNP-029-50G", "size": "50 g", "unit": 50, "mrp": 78.0, "price": 64.0, "stock": 65},
            {"id": "v-cnp2-100", "sku": "MAS-CNP-029-100G", "size": "100 g", "unit": 100, "mrp": 145.0, "price": 119.0, "stock": 130},
            {"id": "v-cnp2-200", "sku": "MAS-CNP-029-200G", "size": "200 g", "unit": 200, "mrp": 280.0, "price": 229.0, "stock": 75},
        ],
        "tags": ["Cinnamon Powder", "Baking Spice", "Dalchini", "Desserts", "Masala Mart"]
    },
    {
        "id": "mas-mix-030",
        "sku": "MAS-MIX-030",
        "name": "Premium Mixed Spice Blend",
        "categoryId": "cat-premium-flavoured",
        "productType": "Spice Blend",
        "basePack": "100 g",
        "profile": "Aromatic, warm and balanced",
        "suitableFor": "Cooking, marinades and seasoning",
        "intensity": "Medium",
        "mrp": 160.0,
        "selling": 129.0,
        "stock": 115,
        "img": ["https://images.unsplash.com/photo-1532336414038-cf19250c5757?w=800&auto=format&fit=crop&q=80"],
        "variants": [
            {"id": "v-mix-50", "sku": "MAS-MIX-030-50G", "size": "50 g", "unit": 50, "mrp": 85.0, "price": 69.0, "stock": 60},
            {"id": "v-mix-100", "sku": "MAS-MIX-030-100G", "size": "100 g", "unit": 100, "mrp": 160.0, "price": 129.0, "stock": 115},
            {"id": "v-mix-200", "sku": "MAS-MIX-030-200G", "size": "200 g", "unit": 200, "mrp": 310.0, "price": 249.0, "stock": 70},
        ],
        "tags": ["Mixed Spice", "All Spice", "Seasoning", "Marinade", "Masala Mart"]
    }
]

print(f"==> Uploading {len(products_data)} Products...")
for p in products_data:
    pid = p["id"]
    suitable = p.get("suitableFor", "Everyday Indian cooking and seasoning")
    
    specs = {
        "Brand": "Masala Mart",
        "Product Type": p["productType"],
        "Form": "Whole" if "Whole" in p["productType"] else "Powder",
        "Spice Level": p["intensity"],
        "Flavor Profile": p["profile"],
        "Net Quantity": p["basePack"],
        "Packaging": "Airtight Resealable Foil Pouch",
        "Country of Origin": "India",
        "Shelf Life": "12 Months",
        "Suitable For": suitable,
        "Storage": "Store in a cool, dry place away from direct sunlight"
    }

    highlights = [
        ("Authentic Purity", f"Authentically curated by Masala Mart for pristine taste and aroma."),
        ("Distinct Profile", f"{p['profile']} featuring vibrant flavors."),
        ("Aroma Retaining Pack", "Triple-layered airtight zipper pouch prevents oxidation and moisture."),
        ("Versatile Kitchen Essential", f"Optimized for {suitable}."),
        ("Free from Additives", "No artificial colors, added MSG, or synthetic fillers.")
    ]

    all_details = [
        {
            "title": "Flavor & Aroma Profile",
            "type": "text",
            "content": f"{p['name']} features a distinguished {p['profile']} with an intensity of {p['intensity']}. Specially processed at low temperatures to lock in volatile essential spice oils."
        },
        {
            "title": "Usage & Culinary Guide",
            "type": "text",
            "content": f"Recommended for: {suitable}. Add towards the tempering stage or simmer gently into gravies and marinades to maximize flavor extraction."
        },
        {
            "title": "Technical Specifications",
            "type": "keyValue",
            "items": specs
        },
        {
            "title": "Packaging & Storage",
            "type": "keyValue",
            "items": {
                "Pack Format": "Resealable Aroma-Lock Pouch",
                "Shelf Life": "12 Months from packaging date",
                "Storage Instructions": "Store in a cool, dry place. Seal zip tightly after each opening.",
                "Country of Origin": "India"
            }
        }
    ]

    options = [{"name": "Pack Size", "values": [v["size"] for v in p["variants"]]}]
    variants = []
    for v in p["variants"]:
        variants.append({
            "id": v["id"],
            "sku": v["sku"],
            "title": v["size"],
            "size": v["size"],
            "color": "",
            "attributes": {"Pack Size": v["size"]},
            "stockQty": v["stock"],
            "isUnlimitedStock": False,
            "priceOverride": v["price"],
            "mrpOverride": v["mrp"],
            "unitValue": v["unit"],
            "unitType": "g"
        })

    prod_doc = {
        "id": pid,
        "companyId": COMPANY_ID,
        "categoryId": p["categoryId"],
        "name": p["name"],
        "details": f"Authentic {p['name']} curated by Masala Mart. Boasts a {p['profile']} aroma, perfectly suited for {suitable}. Packed in high-barrier freshness packaging.",
        "subDetails": f"{p['productType']} | {p['profile']} | {p['intensity']}",
        "type": "quantity_based",
        "unit": 100 if "100" in p["basePack"] else (200 if "200" in p["basePack"] else 50),
        "unitType": "g",
        "amount": p["mrp"],
        "discountAmt": p["selling"],
        "sku": p["sku"],
        "color": "Spiced Gold",
        "stockQty": p["stock"],
        "isUnlimitedStock": False,
        "isRecommended": True,
        "policy": "10-day replacement policy for damaged or defective seals. Packaged food items are non-returnable once opened.",
        "images": [SPICE_IMAGE_MAP.get(p["sku"], p["img"][0])],
        "options": options,
        "variants": variants,
        "specifications": make_specs(specs),
        "highlights": make_highlights(highlights),
        "allDetails": make_all_details(all_details),
        "tags": p["tags"]
    }

    patch_doc(f"companies/{COMPANY_ID}/products/{pid}", prod_doc)
    print(f"-> Saved product {pid}: {p['name']} (Variants: {len(variants)})")

print("All 30 products saved successfully.")

# 5. Create 4 Promotional Banners
print("==> Creating 4 Promotional Banners...")
banners = [
    {
        "id": "banner-masala-1",
        "companyId": COMPANY_ID,
        "image": "https://images.unsplash.com/photo-1596040033229-a9821ebd058d?w=1200&auto=format&fit=crop&q=80",
        "targetCatId": "cat-masala-powders",
        "actionType": "category",
        "priority": 1,
        "title": "Authentic Indian Spices for Every Kitchen",
        "subtitle": "Premium spices and masala blends made for everyday cooking.",
        "cta": "Shop Now"
    },
    {
        "id": "banner-masala-2",
        "companyId": COMPANY_ID,
        "image": "https://images.unsplash.com/photo-1615485290382-441e4d049cb5?w=1200&auto=format&fit=crop&q=80",
        "targetCatId": "cat-specialty-blended",
        "actionType": "category",
        "priority": 2,
        "title": "Bring More Flavor to Every Meal",
        "subtitle": "Discover our collection of aromatic Indian masalas.",
        "cta": "Explore Masalas"
    },
    {
        "id": "banner-masala-3",
        "companyId": COMPANY_ID,
        "image": "https://images.unsplash.com/photo-1509358271058-acd22cc93898?w=1200&auto=format&fit=crop&q=80",
        "targetCatId": "cat-whole-spices",
        "actionType": "category",
        "priority": 3,
        "title": "Pure Spices. Rich Aroma.",
        "subtitle": "Discover premium whole spices selected for your kitchen.",
        "cta": "Shop Whole Spices"
    },
    {
        "id": "banner-masala-4",
        "companyId": COMPANY_ID,
        "image": "https://images.unsplash.com/photo-1532336414038-cf19250c5757?w=1200&auto=format&fit=crop&q=80",
        "targetCatId": "cat-premium-flavoured",
        "actionType": "category",
        "priority": 4,
        "title": "Spice Up Your Kitchen",
        "subtitle": "Get special savings on selected spice products.",
        "cta": "View Offers"
    }
]

for b in banners:
    patch_doc(f"companies/{COMPANY_ID}/banners/{b['id']}", b)
    print(f"-> Banner {b['id']} saved.")

# 6. Create 2 Vouchers
print("==> Creating 2 Promotional Vouchers...")
vouchers = [
    {
        "id": "voucher-spice10",
        "companyId": COMPANY_ID,
        "code": "SPICE10",
        "codeUpper": "SPICE10",
        "discountType": "percentage",
        "discountValue": 10.0,
        "minOrderAmt": 999.0,
        "appliesTo": "all_categories",
        "productIds": [],
        "categoryIds": [],
        "perUserLimit": 5,
        "maxUses": 100,
        "expiryDate": "2027-12-31T23:59:59.000Z",
        "firstTimeOnly": False,
        "isActive": True,
        "usedOrderIds": [],
        "usageByUser": {},
        "usageCount": 0
    },
    {
        "id": "voucher-welcome100",
        "companyId": COMPANY_ID,
        "code": "WELCOME100",
        "codeUpper": "WELCOME100",
        "discountType": "fixed_amount",
        "discountValue": 100.0,
        "minOrderAmt": 1200.0,
        "appliesTo": "all_categories",
        "productIds": [],
        "categoryIds": [],
        "perUserLimit": 1,
        "maxUses": 100,
        "expiryDate": "2027-12-31T23:59:59.000Z",
        "firstTimeOnly": True,
        "isActive": True,
        "usedOrderIds": [],
        "usageByUser": {},
        "usageCount": 0
    }
]

for v in vouchers:
    patch_doc(f"companies/{COMPANY_ID}/vouchers/{v['id']}", v)
    print(f"-> Voucher {v['code']} saved.")

print("\nSUCCESS: Masala Mart store, admin, 4 categories, 30 products, 4 banners and 2 vouchers fully created!")

