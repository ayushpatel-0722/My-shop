import json
import urllib.request
import urllib.error

API_KEY = "AIzaSyDtmFalx3VDu2a-byx7hoxZKe1a2n9maG8"
PROJECT_ID = "myshop-8bd4d"
COMPANY_ID = "coffee-house-shop"

ADMIN_1_EMAIL = "work.ayushkumar112428@gmail.com"
ADMIN_1_PASS = "Ayush@112428@"

ADMIN_2_EMAIL = "mayurpatel07@gmail.com"
ADMIN_2_PASS = "Mayur@07@"

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
    # Try sign in first
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
            # Try sign up
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

print("==> Authenticating Admins...")
token_1, uid_1 = get_auth_token(ADMIN_1_EMAIL, ADMIN_1_PASS)
token_2, uid_2 = get_auth_token(ADMIN_2_EMAIL, ADMIN_2_PASS)

active_token = token_1
headers = {
    "Authorization": f"Bearer {active_token}",
    "Content-Type": "application/json"
}

def patch_doc(path, data, token=None):
    url = f"https://firestore.googleapis.com/v1/projects/{PROJECT_ID}/databases/(default)/documents/{path}"
    payload = to_fs_doc(data)
    h = headers.copy()
    if token:
        h["Authorization"] = f"Bearer {token}"
    req = urllib.request.Request(url, data=json.dumps(payload).encode(), headers=h, method="PATCH")
    try:
        res = urllib.request.urlopen(req)
        return json.loads(res.read().decode())
    except urllib.error.HTTPError as e:
        print(f"Error writing {path}: {e.code} - {e.read().decode()}")
        raise

def delete_doc(path):
    url = f"https://firestore.googleapis.com/v1/projects/{PROJECT_ID}/databases/(default)/documents/{path}"
    req = urllib.request.Request(url, headers=headers, method="DELETE")
    try:
        urllib.request.urlopen(req)
    except urllib.error.HTTPError as e:
        if e.code != 404:
            print(f"Error deleting {path}: {e.code} - {e.read().decode()}")

def list_subcollection(parent_path, subcol):
    url = f"https://firestore.googleapis.com/v1/projects/{PROJECT_ID}/databases/(default)/documents/{parent_path}/{subcol}?pageSize=100"
    req = urllib.request.Request(url, headers=headers)
    try:
        res = urllib.request.urlopen(req)
        data = json.loads(res.read().decode())
        return [doc["name"].split("/")[-1] for doc in data.get("documents", [])]
    except urllib.error.HTTPError as e:
        return []

# 1. Update / Create Company
print(f"==> Setting up Company: {COMPANY_ID}")
weekly_hours = [
    {"day": "Mon", "openTime": "08:00", "closeTime": "22:00", "isClosed": False},
    {"day": "Tue", "openTime": "08:00", "closeTime": "22:00", "isClosed": False},
    {"day": "Wed", "openTime": "08:00", "closeTime": "22:00", "isClosed": False},
    {"day": "Thu", "openTime": "08:00", "closeTime": "22:00", "isClosed": False},
    {"day": "Fri", "openTime": "08:00", "closeTime": "23:00", "isClosed": False},
    {"day": "Sat", "openTime": "08:00", "closeTime": "23:00", "isClosed": False},
    {"day": "Sun", "openTime": "09:00", "closeTime": "22:00", "isClosed": False},
]

company_data = {
    "id": COMPANY_ID,
    "name": "Coffee House",
    "slug": "coffee-house",
    "category": "Coffee & Beverages",
    "details": "Premium coffee products including roasted coffee beans, ground coffee, instant coffee, and specialty coffee.",
    "address": "101 Coffee Street, Ahmedabad, Gujarat 380015, India",
    "companyPassword": ADMIN_1_PASS,
    "currency": "INR",
    "deliveryTypes": ["self_pickup", "home_delivery"],
    "minOrderAmount": 200.0,
    "logoUrl": "https://images.unsplash.com/photo-1501339847302-ac426a4a7cbb?w=500&auto=format&fit=crop&q=80",
    "bannerUrl": "https://images.unsplash.com/photo-1495474472287-4d71bcdd2085?w=1200&auto=format&fit=crop&q=80",
    "profileImageUrl": "https://images.unsplash.com/photo-1447933601403-0c6688de566e?w=800&auto=format&fit=crop&q=80",
    "status": "active",
    "rating": 4.9,
    "reviewCount": 48,
    "followers": 320,
    "isVerified": True,
    "handlingMinutes": 20,
    "deliveryMinutes": 35,
    "weeklyHours": weekly_hours,
    "openingDate": "2026-10-07T08:00:00.000Z"
}

patch_doc(f"companies/{COMPANY_ID}", company_data)
print("Company saved successfully.")

# 2. Link Both Admins
print("==> Linking Admin Accounts...")
admin_records = [
    {
        "uid": uid_1,
        "token": token_1,
        "email": ADMIN_1_EMAIL,
        "name": "Ayush Kumar",
        "phone": "9876543210"
    },
    {
        "uid": uid_2,
        "token": token_2,
        "email": ADMIN_2_EMAIL,
        "name": "Mayur Patel",
        "phone": "9825012345"
    }
]

for adm in admin_records:
    # Subcollection admin doc
    adm_doc = {
        "id": adm["uid"],
        "companyId": COMPANY_ID,
        "name": adm["name"],
        "email": adm["email"],
        "mobileNumber": adm["phone"],
        "address": "101 Coffee Street, Ahmedabad, Gujarat, India",
        "gender": "male",
        "emailVerified": True
    }
    patch_doc(f"companies/{COMPANY_ID}/admins/{adm['uid']}", adm_doc, token=token_1)
    
    # Root user doc
    user_doc = {
        "id": adm["uid"],
        "role": "admin",
        "companyId": COMPANY_ID,
        "email": adm["email"],
        "name": adm["name"],
        "mobileNumber": adm["phone"]
    }
    patch_doc(f"users/{adm['uid']}", user_doc, token=adm["token"])
    print(f"Admin {adm['email']} successfully linked to {COMPANY_ID}!")

# 3. Clean up old categories and products in the company
print("==> Cleaning up previous categories and products...")
existing_cats = list_subcollection(f"companies/{COMPANY_ID}", "categories")
for cid in existing_cats:
    if cid not in ["cat-coffee-powder", "cat-coffee-beans", "cat-instant-coffee"]:
        delete_doc(f"companies/{COMPANY_ID}/categories/{cid}")
        print(f"Deleted outdated category: {cid}")

existing_prods = list_subcollection(f"companies/{COMPANY_ID}", "products")
expected_prod_ids = [
    f"chp-pow-{i:03d}" for i in range(1, 8)
] + [
    f"chp-bean-{i:03d}" for i in range(1, 8)
] + [
    f"chp-ins-{i:03d}" for i in range(1, 7)
]
for pid in existing_prods:
    if pid not in expected_prod_ids:
        delete_doc(f"companies/{COMPANY_ID}/products/{pid}")
        print(f"Deleted old product: {pid}")

# 4. Create Exactly 3 Main Categories
print("==> Creating 3 Main Categories...")
categories = [
    {
        "id": "cat-coffee-powder",
        "name": "Coffee Powder",
        "companyId": COMPANY_ID,
        "details": "Premium ground coffee products available in different roast levels, flavors, origins, and pack sizes. Suitable for espresso, French press, filter coffee, moka pot, and other brewing methods.",
        "type": "Coffee & Beverages",
        "iconUrl": "https://images.unsplash.com/photo-1587734195503-904fca47e0e9?w=400&auto=format&fit=crop&q=80",
        "sortOrder": 1,
        "productList": [f"chp-pow-{i:03d}" for i in range(1, 8)]
    },
    {
        "id": "cat-coffee-beans",
        "name": "Coffee Beans",
        "companyId": COMPANY_ID,
        "details": "Freshly roasted whole coffee beans sourced from premium coffee-growing regions and available in different roast profiles and flavor notes.",
        "type": "Coffee & Beverages",
        "iconUrl": "https://images.unsplash.com/photo-1559056199-641a0ac8b55e?w=400&auto=format&fit=crop&q=80",
        "sortOrder": 2,
        "productList": [f"chp-bean-{i:03d}" for i in range(1, 8)]
    },
    {
        "id": "cat-instant-coffee",
        "name": "Instant Coffee",
        "companyId": COMPANY_ID,
        "details": "Convenient instant coffee products made for quick preparation while maintaining rich aroma, flavor, and coffee intensity.",
        "type": "Coffee & Beverages",
        "iconUrl": "https://images.unsplash.com/photo-1514432324607-a09d9b4aefdd?w=400&auto=format&fit=crop&q=80",
        "sortOrder": 3,
        "productList": [f"chp-ins-{i:03d}" for i in range(1, 7)]
    }
]

for cat in categories:
    patch_doc(f"companies/{COMPANY_ID}/categories/{cat['id']}", cat)
    print(f"Created category: {cat['name']} with {len(cat['productList'])} products.")

# 5. Create 20 Packaged Coffee Products
print("==> Creating 20 Packaged Coffee Products...")

# Verified high quality e-commerce images of packaged coffee (jars, bags, pouches)
IMAGES = {
    1: ["https://images.unsplash.com/photo-1587734195503-904fca47e0e9?w=800&auto=format&fit=crop&q=80"],
    2: ["https://images.unsplash.com/photo-1611854779393-1b2da9d400fe?w=800&auto=format&fit=crop&q=80"],
    3: ["https://images.unsplash.com/photo-1589396575653-c09c794ff6a6?w=800&auto=format&fit=crop&q=80"],
    4: ["https://images.unsplash.com/photo-1518832553480-cd0e625ed3e6?w=800&auto=format&fit=crop&q=80"],
    5: ["https://images.unsplash.com/photo-1552346154-21d32810aba3?w=800&auto=format&fit=crop&q=80"],
    6: ["https://images.unsplash.com/photo-1588776814546-1ffcf47267a5?w=800&auto=format&fit=crop&q=80"],
    7: ["https://images.unsplash.com/photo-1563245372-f21724e3856d?w=800&auto=format&fit=crop&q=80"],
    8: ["https://images.unsplash.com/photo-1559056199-641a0ac8b55e?w=800&auto=format&fit=crop&q=80"],
    9: ["https://images.unsplash.com/photo-1524350876685-274059332603?w=800&auto=format&fit=crop&q=80"],
    10: ["https://images.unsplash.com/photo-1621263764928-df1444c5e859?w=800&auto=format&fit=crop&q=80"],
    11: ["https://images.unsplash.com/photo-1511920170033-f8396924c348?w=800&auto=format&fit=crop&q=80"],
    12: ["https://images.unsplash.com/photo-1561047029-3000c68339ca?w=800&auto=format&fit=crop&q=80"],
    13: ["https://images.unsplash.com/photo-1512568400610-62da28bc8a13?w=800&auto=format&fit=crop&q=80"],
    14: ["https://images.unsplash.com/photo-1525610553991-2bede1a236e2?w=800&auto=format&fit=crop&q=80"],
    15: ["https://images.unsplash.com/photo-1514432324607-a09d9b4aefdd?w=800&auto=format&fit=crop&q=80"],
    16: ["https://images.unsplash.com/photo-1517256064527-09c73fc73e38?w=800&auto=format&fit=crop&q=80"],
    17: ["https://images.unsplash.com/photo-1584735935682-2f2b69dff9d2?w=800&auto=format&fit=crop&q=80"],
    18: ["https://images.unsplash.com/photo-1541167760496-1628856ab772?w=800&auto=format&fit=crop&q=80"],
    19: ["https://images.unsplash.com/photo-1510591509098-f4fdc6d0ff04?w=800&auto=format&fit=crop&q=80"],
    20: ["https://images.unsplash.com/photo-1447933601403-0c6688de566e?w=800&auto=format&fit=crop&q=80"],
}

# Standard structured highlight generator
def make_highlights(items):
    return [{"title": it[0], "description": it[1], "order": idx} for idx, it in enumerate(items)]

def make_all_details(sections):
    res = []
    for s_idx, sec in enumerate(sections):
        s_obj = {
            "title": sec["title"],
            "type": sec["type"],
            "order": s_idx
        }
        if sec["type"] == "text":
            s_obj["content"] = sec["content"]
        else:
            s_obj["items"] = [{"key": k, "value": v} for k, v in sec["items"].items()]
        res.append(s_obj)
    return res

products_def = [
    # =========================================================================
    # CATEGORY 1: COFFEE POWDER (7 Products)
    # =========================================================================
    {
        "id": "chp-pow-001",
        "categoryId": "cat-coffee-powder",
        "name": "Classic Medium Roast Coffee Powder",
        "sku": "CHP-POW-001",
        "weight": 200.0,
        "unit": 200.0,
        "unitType": "g",
        "mrp": 349.0,
        "selling": 289.0,
        "stock": 80,
        "coffeeType": "Ground Coffee",
        "roast": "Medium Roast",
        "intensity": "Medium (3 / 5)",
        "flavor": "Smooth, balanced and aromatic with subtle caramel undertones",
        "suitableFor": "Filter, French Press, Moka Pot",
        "ingredients": "100% roasted coffee beans",
        "origin": "Chikmagalur, Karnataka, India",
        "img": IMAGES[1],
        "tags": ["Coffee", "Ground Coffee", "Coffee Powder", "Medium Roast", "Classic", "Artisanal"],
        # HAS VARIANTS: 100 g, 200 g, 500 g, 1 kg
        "has_variants": True,
        "variants": [
            {"id": "var-pow1-100", "sku": "CHP-POW-001-100G", "title": "100 g Pouch", "size": "100 g", "mrp": 199.0, "price": 169.0, "stock": 40, "unit": 100.0},
            {"id": "var-pow1-200", "sku": "CHP-POW-001-200G", "title": "200 g Standard Pack", "size": "200 g", "mrp": 349.0, "price": 289.0, "stock": 80, "unit": 200.0},
            {"id": "var-pow1-500", "sku": "CHP-POW-001-500G", "title": "500 g Value Pack", "size": "500 g", "mrp": 799.0, "price": 649.0, "stock": 35, "unit": 500.0},
            {"id": "var-pow1-1kg", "sku": "CHP-POW-001-1KG", "title": "1 kg Bulk Pack", "size": "1 kg", "mrp": 1499.0, "price": 1199.0, "stock": 20, "unit": 1000.0},
        ]
    },
    {
        "id": "chp-pow-002",
        "categoryId": "cat-coffee-powder",
        "name": "Premium Espresso Ground Coffee",
        "sku": "CHP-POW-002",
        "weight": 250.0,
        "unit": 250.0,
        "unitType": "g",
        "mrp": 420.0,
        "selling": 350.0,
        "stock": 65,
        "coffeeType": "Espresso Ground Coffee",
        "roast": "Dark Roast",
        "intensity": "Strong (4 / 5)",
        "flavor": "Bold, rich and intense with dark cocoa notes and thick crema",
        "suitableFor": "Espresso machines, Moka Pot, Aeropress",
        "ingredients": "100% roasted coffee beans (Fine Espresso Grind)",
        "origin": "Coorg & Baba Budangiri, India",
        "img": IMAGES[2],
        "tags": ["Coffee", "Espresso", "Ground Coffee", "Dark Roast", "Strong", "Crema"],
        # HAS VARIANTS: 100 g, 250 g, 500 g
        "has_variants": True,
        "variants": [
            {"id": "var-pow2-100", "sku": "CHP-POW-002-100G", "title": "100 g Tin", "size": "100 g", "mrp": 210.0, "price": 179.0, "stock": 30, "unit": 100.0},
            {"id": "var-pow2-250", "sku": "CHP-POW-002-250G", "title": "250 g Canister", "size": "250 g", "mrp": 420.0, "price": 350.0, "stock": 65, "unit": 250.0},
            {"id": "var-pow2-500", "sku": "CHP-POW-002-500G", "title": "500 g Family Pack", "size": "500 g", "mrp": 780.0, "price": 649.0, "stock": 25, "unit": 500.0},
        ]
    },
    {
        "id": "chp-pow-003",
        "categoryId": "cat-coffee-powder",
        "name": "South Indian Filter Coffee Powder",
        "sku": "CHP-POW-003",
        "weight": 500.0,
        "unit": 500.0,
        "unitType": "g",
        "mrp": 380.0,
        "selling": 319.0,
        "stock": 90,
        "coffeeType": "Filter Coffee Blend",
        "roast": "Medium-Dark Roast",
        "intensity": "Strong (4.5 / 5)",
        "flavor": "Rich, aromatic and traditional with intense body and lingering finish",
        "suitableFor": "Traditional South Indian Brass / Stainless Steel Filter",
        "ingredients": "80% Plantation Peaberry Coffee, 20% Roasted Chicory",
        "origin": "Wayanad & Coorg, South India",
        "img": IMAGES[3],
        "tags": ["Filter Coffee", "South Indian Coffee", "Coffee Powder", "Traditional", "Strong Coffee", "Chicory Blend"],
        # HAS VARIANTS: 250 g, 500 g, 1 kg
        "has_variants": True,
        "variants": [
            {"id": "var-pow3-250", "sku": "CHP-POW-003-250G", "title": "250 g Pouch", "size": "250 g", "mrp": 210.0, "price": 175.0, "stock": 50, "unit": 250.0},
            {"id": "var-pow3-500", "sku": "CHP-POW-003-500G", "title": "500 g Pack", "size": "500 g", "mrp": 380.0, "price": 319.0, "stock": 90, "unit": 500.0},
            {"id": "var-pow3-1kg", "sku": "CHP-POW-003-1KG", "title": "1 kg Value Pack", "size": "1 kg", "mrp": 720.0, "price": 599.0, "stock": 30, "unit": 1000.0},
        ]
    },
    {
        "id": "chp-pow-004",
        "categoryId": "cat-coffee-powder",
        "name": "French Roast Dark Coffee Powder",
        "sku": "CHP-POW-004",
        "weight": 250.0,
        "unit": 250.0,
        "unitType": "g",
        "mrp": 440.0,
        "selling": 369.0,
        "stock": 55,
        "coffeeType": "Ground Coffee",
        "roast": "Dark Roast",
        "intensity": "Very Strong (5 / 5)",
        "flavor": "Smoky, bold, dark chocolate notes with deep caramelized richness",
        "suitableFor": "French Press, Moka Pot, Drip Filter",
        "ingredients": "100% roasted coffee beans (Coarse-Medium Grind)",
        "origin": "Shevaroy Hills, Tamil Nadu, India",
        "img": IMAGES[4],
        "tags": ["French Roast", "Dark Roast", "Ground Coffee", "Smoky", "Extra Strong"],
        # HAS VARIANTS: 250 g, 500 g
        "has_variants": True,
        "variants": [
            {"id": "var-pow4-250", "sku": "CHP-POW-004-250G", "title": "250 g Fresh-Lock Pouch", "size": "250 g", "mrp": 440.0, "price": 369.0, "stock": 55, "unit": 250.0},
            {"id": "var-pow4-500", "sku": "CHP-POW-004-500G", "title": "500 g Value Pack", "size": "500 g", "mrp": 820.0, "price": 679.0, "stock": 25, "unit": 500.0},
        ]
    },
    {
        "id": "chp-pow-005",
        "categoryId": "cat-coffee-powder",
        "name": "Hazelnut Flavored Coffee Powder",
        "sku": "CHP-POW-005",
        "weight": 200.0,
        "unit": 200.0,
        "unitType": "g",
        "mrp": 399.0,
        "selling": 329.0,
        "stock": 60,
        "coffeeType": "Flavored Ground Coffee",
        "roast": "Medium Roast",
        "intensity": "Medium (3 / 5)",
        "flavor": "Nutty, sweet toasted hazelnut aroma with velvety coffee finish",
        "suitableFor": "French Press, Drip Coffee, Cold Brew, Milk Brew",
        "ingredients": "100% Pure Arabica Ground Coffee, Nature-Identical Roasted Hazelnut Flavors",
        "origin": "Araku Valley, Andhra Pradesh, India",
        "img": IMAGES[5],
        "tags": ["Flavored Coffee", "Hazelnut", "Ground Coffee", "Medium Roast", "Aromatic", "Dessert Coffee"],
        "has_variants": False
    },
    {
        "id": "chp-pow-006",
        "categoryId": "cat-coffee-powder",
        "name": "Mocha Chocolate Coffee Powder",
        "sku": "CHP-POW-006",
        "weight": 200.0,
        "unit": 200.0,
        "unitType": "g",
        "mrp": 399.0,
        "selling": 329.0,
        "stock": 60,
        "coffeeType": "Flavored Ground Coffee",
        "roast": "Medium-Dark Roast",
        "intensity": "Medium-Strong (3.5 / 5)",
        "flavor": "Decadent Dutch cocoa harmonized with rich roasted Arabica notes",
        "suitableFor": "French Press, Moka Pot, Iced Lattes, Drip Brew",
        "ingredients": "100% Arabica Coffee Powder, Natural Chocolate Flavor Extract",
        "origin": "Chikmagalur, Karnataka, India",
        "img": IMAGES[6],
        "tags": ["Mocha", "Chocolate Coffee", "Flavored Coffee", "Ground Coffee", "Sweet & Smooth"],
        "has_variants": False
    },
    {
        "id": "chp-pow-007",
        "categoryId": "cat-coffee-powder",
        "name": "Premium Arabica Ground Coffee",
        "sku": "CHP-POW-007",
        "weight": 250.0,
        "unit": 250.0,
        "unitType": "g",
        "mrp": 480.0,
        "selling": 399.0,
        "stock": 70,
        "coffeeType": "100% Arabica Ground Coffee",
        "roast": "Medium Roast",
        "intensity": "Medium (3 / 5)",
        "flavor": "Fruity citrus notes, honey sweetness, and a silky smooth finish",
        "suitableFor": "Pour-Over, Aeropress, French Press, Drip Machine",
        "ingredients": "100% Single-Estate Specialty Arabica Coffee Beans (Milled)",
        "origin": "Biligiriranga Hills (BR Hills), Karnataka, India",
        "img": IMAGES[7],
        "tags": ["Arabica", "Single Estate", "Premium Ground Coffee", "Medium Roast", "Specialty Coffee"],
        # HAS VARIANTS: 100 g, 250 g, 500 g
        "has_variants": True,
        "variants": [
            {"id": "var-pow7-100", "sku": "CHP-POW-007-100G", "title": "100 g Sampler", "size": "100 g", "mrp": 240.0, "price": 199.0, "stock": 35, "unit": 100.0},
            {"id": "var-pow7-250", "sku": "CHP-POW-007-250G", "title": "250 g Canister", "size": "250 g", "mrp": 480.0, "price": 399.0, "stock": 70, "unit": 250.0},
            {"id": "var-pow7-500", "sku": "CHP-POW-007-500G", "title": "500 g Pantry Pack", "size": "500 g", "mrp": 899.0, "price": 749.0, "stock": 25, "unit": 500.0},
        ]
    },

    # =========================================================================
    # CATEGORY 2: COFFEE BEANS (7 Products)
    # =========================================================================
    {
        "id": "chp-bean-001",
        "categoryId": "cat-coffee-beans",
        "name": "Premium Arabica Coffee Beans",
        "sku": "CHP-BEAN-001",
        "weight": 250.0,
        "unit": 250.0,
        "unitType": "g",
        "mrp": 550.0,
        "selling": 449.0,
        "stock": 75,
        "coffeeType": "Whole Coffee Beans",
        "roast": "Medium Roast",
        "intensity": "Medium (3 / 5)",
        "flavor": "Smooth, vibrant, red berry sweetness and subtle floral jasmine aroma",
        "suitableFor": "Home Grinders, Bean-to-Cup Machines, Espresso, Manual Pour-Over",
        "ingredients": "100% Grade-A Washed Arabica Whole Beans",
        "origin": "Chikmagalur, Western Ghats, India",
        "img": IMAGES[8],
        "tags": ["Coffee Beans", "Whole Beans", "Arabica", "Medium Roast", "Freshly Roasted", "Gourmet"],
        # HAS VARIANTS: 250 g, 500 g, 1 kg
        "has_variants": True,
        "variants": [
            {"id": "var-bean1-250", "sku": "CHP-BEAN-001-250G", "title": "250 g Degassing Pouch", "size": "250 g", "mrp": 550.0, "price": 449.0, "stock": 75, "unit": 250.0},
            {"id": "var-bean1-500", "sku": "CHP-BEAN-001-500G", "title": "500 g Zip-Lock Pouch", "size": "500 g", "mrp": 999.0, "price": 819.0, "stock": 40, "unit": 500.0},
            {"id": "var-bean1-1kg", "sku": "CHP-BEAN-001-1KG", "title": "1 kg Barista Bag", "size": "1 kg", "mrp": 1899.0, "price": 1549.0, "stock": 20, "unit": 1000.0},
        ]
    },
    {
        "id": "chp-bean-002",
        "categoryId": "cat-coffee-beans",
        "name": "Dark Roast Espresso Coffee Beans",
        "sku": "CHP-BEAN-002",
        "weight": 500.0,
        "unit": 500.0,
        "unitType": "g",
        "mrp": 980.0,
        "selling": 799.0,
        "stock": 60,
        "coffeeType": "Whole Coffee Beans",
        "roast": "Dark Roast",
        "intensity": "Strong (4.5 / 5)",
        "flavor": "Bold, dark chocolate, toasted walnut and syrupy crema profile",
        "suitableFor": "Commercial & Domestic Espresso Grinders, Moka Pot",
        "ingredients": "90% Dark Roasted Arabica, 10% Highland Robusta Whole Beans",
        "origin": "Coorg & Nilgiris, India",
        "img": IMAGES[9],
        "tags": ["Espresso Beans", "Dark Roast", "Whole Beans", "High Crema", "Intense"],
        # HAS VARIANTS: 250 g, 500 g, 1 kg
        "has_variants": True,
        "variants": [
            {"id": "var-bean2-250", "sku": "CHP-BEAN-002-250G", "title": "250 g Pouch", "size": "250 g", "mrp": 520.0, "price": 429.0, "stock": 45, "unit": 250.0},
            {"id": "var-bean2-500", "sku": "CHP-BEAN-002-500G", "title": "500 g Foil Bag", "size": "500 g", "mrp": 980.0, "price": 799.0, "stock": 60, "unit": 500.0},
            {"id": "var-bean2-1kg", "sku": "CHP-BEAN-002-1KG", "title": "1 kg Barista Bag", "size": "1 kg", "mrp": 1850.0, "price": 1499.0, "stock": 25, "unit": 1000.0},
        ]
    },
    {
        "id": "chp-bean-003",
        "categoryId": "cat-coffee-beans",
        "name": "Classic Arabica Robusta Coffee Beans",
        "sku": "CHP-BEAN-003",
        "weight": 500.0,
        "unit": 500.0,
        "unitType": "g",
        "mrp": 750.0,
        "selling": 629.0,
        "stock": 80,
        "coffeeType": "Whole Coffee Beans (Blend)",
        "roast": "Medium-Dark Roast",
        "intensity": "Strong (4 / 5)",
        "flavor": "Rich, earthy, balanced cocoa notes with robust lingering crema",
        "suitableFor": "Espresso, Stovetop Moka, Filter Coffee",
        "ingredients": "70% Roasted Arabica Beans, 30% Washed Robusta Beans",
        "origin": "Wayanad, Kerala & Chikmagalur, Karnataka",
        "img": IMAGES[10],
        "tags": ["Coffee Blend", "Arabica Robusta", "Whole Beans", "Balanced", "Daily Brew"],
        "has_variants": False
    },
    {
        "id": "chp-bean-004",
        "categoryId": "cat-coffee-beans",
        "name": "Colombian Style Premium Coffee Beans",
        "sku": "CHP-BEAN-004",
        "weight": 250.0,
        "unit": 250.0,
        "unitType": "g",
        "mrp": 620.0,
        "selling": 499.0,
        "stock": 50,
        "coffeeType": "Single Origin Whole Beans",
        "roast": "Medium Roast",
        "intensity": "Medium (3 / 5)",
        "flavor": "Fruity citrus brightness, caramelized toffee, roasted almonds",
        "suitableFor": "V60 Pour-Over, Chemex, Aeropress, French Press",
        "ingredients": "100% High-Elevation Supremo Arabica Beans",
        "origin": "Huila Region, Colombia (Imported & Hand-Roasted in India)",
        "img": IMAGES[11],
        "tags": ["Colombian Coffee", "Supremo", "Single Origin", "Specialty Coffee", "Whole Beans"],
        "has_variants": False
    },
    {
        "id": "chp-bean-005",
        "categoryId": "cat-coffee-beans",
        "name": "Italian Espresso Coffee Beans",
        "sku": "CHP-BEAN-005",
        "weight": 500.0,
        "unit": 500.0,
        "unitType": "g",
        "mrp": 1050.0,
        "selling": 849.0,
        "stock": 55,
        "coffeeType": "Espresso Whole Beans",
        "roast": "Dark Roast",
        "intensity": "Very Strong (5 / 5)",
        "flavor": "Bold, roasted, dark baker's chocolate, smoky malt and dense crema",
        "suitableFor": "Portafilter Espresso Machines, Super-Automatic Espresso Makers",
        "ingredients": "Authentic Milanese Blend (85% Arabica, 15% Gourmet Robusta)",
        "origin": "Northern Italian Roast Style (Crafted in India)",
        "img": IMAGES[12],
        "tags": ["Italian Espresso", "Dark Roast", "Whole Beans", "Crema King", "Barista Blend"],
        # HAS VARIANTS: 250 g, 500 g, 1 kg
        "has_variants": True,
        "variants": [
            {"id": "var-bean5-250", "sku": "CHP-BEAN-005-250G", "title": "250 g Pouch", "size": "250 g", "mrp": 560.0, "price": 459.0, "stock": 35, "unit": 250.0},
            {"id": "var-bean5-500", "sku": "CHP-BEAN-005-500G", "title": "500 g Bag", "size": "500 g", "mrp": 1050.0, "price": 849.0, "stock": 55, "unit": 500.0},
            {"id": "var-bean5-1kg", "sku": "CHP-BEAN-005-1KG", "title": "1 kg Barista Bag", "size": "1 kg", "mrp": 1950.0, "price": 1599.0, "stock": 20, "unit": 1000.0},
        ]
    },
    {
        "id": "chp-bean-006",
        "categoryId": "cat-coffee-beans",
        "name": "Mountain Roast Arabica Coffee Beans",
        "sku": "CHP-BEAN-006",
        "weight": 250.0,
        "unit": 250.0,
        "unitType": "g",
        "mrp": 650.0,
        "selling": 529.0,
        "stock": 45,
        "coffeeType": "High Altitude Specialty Whole Beans",
        "roast": "Medium Roast",
        "intensity": "Medium (3 / 5)",
        "flavor": "Floral jasmine, apricot sweetness, winey notes with clean honey finish",
        "suitableFor": "Siphon, Aeropress, Cold Drip, Manual Pour-Over",
        "ingredients": "100% Shade-Grown High Elevation Arabica Beans (1400m MSL)",
        "origin": "Bababudangiri Range, Karnataka, India",
        "img": IMAGES[13],
        "tags": ["Specialty Coffee", "Mountain Grown", "Whole Beans", "Floral", "Single Estate"],
        "has_variants": False
    },
    {
        "id": "chp-bean-007",
        "categoryId": "cat-coffee-beans",
        "name": "Strong Robusta Coffee Beans",
        "sku": "CHP-BEAN-007",
        "weight": 500.0,
        "unit": 500.0,
        "unitType": "g",
        "mrp": 680.0,
        "selling": 549.0,
        "stock": 70,
        "coffeeType": "Whole Coffee Beans (Robusta)",
        "roast": "Dark Roast",
        "intensity": "Very Strong (5 / 5)",
        "flavor": "Earthy, intense, full-bodied with cedarwood and dark molasses finish",
        "suitableFor": "Espresso Blend Base, Moka Pot, Cold Brew Concentrates",
        "ingredients": "100% Premium Robusta Parchment Whole Beans",
        "origin": "Wayanad, Kerala, India",
        "img": IMAGES[14],
        "tags": ["Robusta", "Whole Beans", "Dark Roast", "High Caffeine", "Heavy Body"],
        "has_variants": False
    },

    # =========================================================================
    # CATEGORY 3: INSTANT COFFEE (6 Products)
    # =========================================================================
    {
        "id": "chp-ins-001",
        "categoryId": "cat-instant-coffee",
        "name": "Classic Instant Coffee",
        "sku": "CHP-INS-001",
        "weight": 100.0,
        "unit": 100.0,
        "unitType": "g",
        "mrp": 320.0,
        "selling": 259.0,
        "stock": 100,
        "coffeeType": "Instant Coffee Granules",
        "roast": "Medium Roast",
        "intensity": "Medium (3 / 5)",
        "flavor": "Smooth, rich, aromatic cup with comforting milk chocolate notes",
        "suitableFor": "Dissolves instantly in hot water or milk for quick daily coffee",
        "ingredients": "100% Pure Agglomerated Soluble Instant Coffee",
        "origin": "India",
        "img": IMAGES[15],
        "tags": ["Instant Coffee", "Classic", "Quick Brew", "Aroma Lock", "Daily Coffee"],
        # HAS VARIANTS: 50 g, 100 g, 200 g
        "has_variants": True,
        "variants": [
            {"id": "var-ins1-50", "sku": "CHP-INS-001-50G", "title": "50 g Glass Jar", "size": "50 g", "mrp": 175.0, "price": 139.0, "stock": 60, "unit": 50.0},
            {"id": "var-ins1-100", "sku": "CHP-INS-001-100G", "title": "100 g Aroma-Lock Jar", "size": "100 g", "mrp": 320.0, "price": 259.0, "stock": 100, "unit": 100.0},
            {"id": "var-ins1-200", "sku": "CHP-INS-001-200G", "title": "200 g Economy Jar", "size": "200 g", "mrp": 599.0, "price": 489.0, "stock": 40, "unit": 200.0},
        ]
    },
    {
        "id": "chp-ins-002",
        "categoryId": "cat-instant-coffee",
        "name": "Espresso Intense Instant Coffee",
        "sku": "CHP-INS-002",
        "weight": 100.0,
        "unit": 100.0,
        "unitType": "g",
        "mrp": 390.0,
        "selling": 319.0,
        "stock": 85,
        "coffeeType": "Instant Espresso Style Granules",
        "roast": "Dark Roast",
        "intensity": "Very Strong (5 / 5)",
        "flavor": "Bold, intense, roasted caramel richness with velvety crema layer",
        "suitableFor": "Instant Espresso, Dalgona Coffee, Iced Americano, Frappes",
        "ingredients": "100% Pure Spray-Dried & Microground Arabica Coffee",
        "origin": "India",
        "img": IMAGES[16],
        "tags": ["Espresso Style", "Instant Coffee", "Dark Roast", "Intense", "Bold Coffee"],
        # HAS VARIANTS: 50 g, 100 g, 200 g
        "has_variants": True,
        "variants": [
            {"id": "var-ins2-50", "sku": "CHP-INS-002-50G", "title": "50 g Jar", "size": "50 g", "mrp": 210.0, "price": 169.0, "stock": 50, "unit": 50.0},
            {"id": "var-ins2-100", "sku": "CHP-INS-002-100G", "title": "100 g Glass Jar", "size": "100 g", "mrp": 390.0, "price": 319.0, "stock": 85, "unit": 100.0},
            {"id": "var-ins2-200", "sku": "CHP-INS-002-200G", "title": "200 g Value Jar", "size": "200 g", "mrp": 720.0, "price": 589.0, "stock": 35, "unit": 200.0},
        ]
    },
    {
        "id": "chp-ins-003",
        "categoryId": "cat-instant-coffee",
        "name": "Premium Freeze-Dried Coffee",
        "sku": "CHP-INS-003",
        "weight": 100.0,
        "unit": 100.0,
        "unitType": "g",
        "mrp": 450.0,
        "selling": 369.0,
        "stock": 70,
        "coffeeType": "Freeze-Dried Instant Coffee Crystals",
        "roast": "Medium Roast",
        "intensity": "Medium (3.5 / 5)",
        "flavor": "Smooth, aromatic, balanced with vibrant coffee bean aroma preserved at -40°C",
        "suitableFor": "Dissolves in hot water or warm milk in seconds",
        "ingredients": "100% Freeze-Dried Arabica Crystals",
        "origin": "Germany & India",
        "img": IMAGES[17],
        "tags": ["Freeze Dried", "Instant Coffee", "Gold Crystals", "Gourmet Instant", "Aromatic"],
        "has_variants": False
    },
    {
        "id": "chp-ins-004",
        "categoryId": "cat-instant-coffee",
        "name": "Strong Black Instant Coffee",
        "sku": "CHP-INS-004",
        "weight": 150.0,
        "unit": 150.0,
        "unitType": "g",
        "mrp": 360.0,
        "selling": 299.0,
        "stock": 75,
        "coffeeType": "Instant Soluble Coffee Granules",
        "roast": "Dark Roast",
        "intensity": "Strong (4.5 / 5)",
        "flavor": "Bold, punchy, full-bodied with zero sweetness and high caffeine kick",
        "suitableFor": "Quick morning black coffee, pre-workout black brew",
        "ingredients": "100% Dark Roasted Soluble Coffee",
        "origin": "India",
        "img": IMAGES[18],
        "tags": ["Black Coffee", "Instant Coffee", "Pre-workout", "Strong Coffee", "Sugar-Free"],
        "has_variants": False
    },
    {
        "id": "chp-ins-005",
        "categoryId": "cat-instant-coffee",
        "name": "Hazelnut Instant Coffee",
        "sku": "CHP-INS-005",
        "weight": 100.0,
        "unit": 100.0,
        "unitType": "g",
        "mrp": 380.0,
        "selling": 309.0,
        "stock": 65,
        "coffeeType": "Flavored Instant Coffee Crystals",
        "roast": "Medium Roast",
        "intensity": "Medium (3 / 5)",
        "flavor": "Nutty, sweet roasted hazelnut indulgence with velvety creamy finish",
        "suitableFor": "Hot hazelnut latte, iced coffee, dessert frappes",
        "ingredients": "100% Pure Freeze-Dried Coffee, Natural Hazelnut Flavor Extract",
        "origin": "India",
        "img": IMAGES[19],
        "tags": ["Flavored Coffee", "Hazelnut Instant", "Cafe Style", "Sweet Aroma", "Quick Latte"],
        "has_variants": False
    },
    {
        "id": "chp-ins-006",
        "categoryId": "cat-instant-coffee",
        "name": "Premium Mocha Instant Coffee",
        "sku": "CHP-INS-006",
        "weight": 100.0,
        "unit": 100.0,
        "unitType": "g",
        "mrp": 380.0,
        "selling": 309.0,
        "stock": 65,
        "coffeeType": "Flavored Instant Coffee Crystals",
        "roast": "Medium-Dark Roast",
        "intensity": "Medium-Strong (3.5 / 5)",
        "flavor": "Rich cocoa and dark roasted coffee harmony with smooth dessert finish",
        "suitableFor": "Mocha lattes, iced mocha coffee, iced frappes",
        "ingredients": "100% Instant Coffee Powder, Organic Dutch Cocoa Flavor",
        "origin": "India",
        "img": IMAGES[20],
        "tags": ["Mocha Instant", "Chocolate Coffee", "Instant Coffee", "Flavored Coffee", "Dessert Coffee"],
        "has_variants": False
    }
]

for p_data in products_def:
    prod_id = p_data["id"]
    
    # Specs
    specs = [
        {"key": "Brand", "value": "Coffee House"},
        {"key": "Coffee Type", "value": p_data["coffeeType"]},
        {"key": "Roast Level", "value": p_data["roast"]},
        {"key": "Intensity", "value": p_data["intensity"]},
        {"key": "Flavor Profile", "value": p_data["flavor"]},
        {"key": "Suitable For / Preparation", "value": p_data["suitableFor"]},
        {"key": "Ingredients", "value": p_data["ingredients"]},
        {"key": "Country of Origin", "value": p_data["origin"]},
        {"key": "Net Quantity", "value": f"{int(p_data['weight'])} g"},
        {"key": "Shelf Life", "value": "12 Months from Manufacturing Date"},
        {"key": "Storage Instructions", "value": "Store in a cool, dry place. Reseal tightly after opening to preserve fresh aroma."},
        {"key": "Packaging Type", "value": "Aroma-Lock Degassing Valve Zipper Pouch / Glass Jar"}
    ]
    
    # Highlights
    highlights = make_highlights([
        ("Premium Gourmet Coffee", f"{p_data['name']} curated from high-altitude estates."),
        ("Distinct Flavor Profile", p_data["flavor"]),
        ("Masterfully Roasted", f"{p_data['roast']} offering {p_data['intensity']}."),
        ("Versatile Brewing", f"Optimized for {p_data['suitableFor']}."),
        ("100% Pure & Packaged", "Packed in nitrogen-flushed freshness packaging for maximum aroma retention.")
    ])
    
    # All Details sections
    all_details = make_all_details([
        {
            "title": "Flavor & Aroma Profile",
            "type": "text",
            "content": f"Experience an exceptional cup with {p_data['flavor']}. Roasted carefully to a {p_data['roast']} profile delivering {p_data['intensity']} intensity and a long, pleasing aftertaste."
        },
        {
            "title": "Brewing & Preparation Guide",
            "type": "text",
            "content": f"Recommended preparation method: {p_data['suitableFor']}. Use freshly boiled filtered water (90-93°C) or hot milk. Adjust dosage according to preferred strength."
        },
        {
            "title": "Technical Specifications",
            "type": "keyValue",
            "items": {
                "Brand": "Coffee House",
                "Product Type": p_data["coffeeType"],
                "Roast Profile": p_data["roast"],
                "Caffeine Type": "Caffeinated",
                "Container": "Fresh-Lock Pouch / Jar",
                "Origin": p_data["origin"]
            }
        },
        {
            "title": "Packaging & Storage",
            "type": "keyValue",
            "items": {
                "Net Weight": f"{int(p_data['weight'])} g",
                "Shelf Life": "12 Months",
                "Storage": "Store away from direct sunlight, heat and moisture.",
                "Recyclable": "Yes (Eco-Friendly Foil Pouch / Recyclable Glass)"
            }
        }
    ])
    
    # Variants & Options
    options = []
    variants = []
    if p_data.get("has_variants"):
        options = [{"name": "Pack Size", "values": [v["size"] for v in p_data["variants"]]}]
        for v in p_data["variants"]:
            variants.append({
                "id": v["id"],
                "sku": v["sku"],
                "title": v["title"],
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
            
    doc = {
        "id": prod_id,
        "companyId": COMPANY_ID,
        "categoryId": p_data["categoryId"],
        "name": p_data["name"],
        "details": f"Artisanal {p_data['name']} packed in an airtight protective container. Delivers {p_data['flavor']}.",
        "subDetails": f"{p_data['coffeeType']} | {p_data['roast']} | {p_data['intensity']}",
        "type": "quantity_based",
        "unit": p_data["unit"],
        "unitType": p_data["unitType"],
        "amount": p_data["mrp"],
        "discountAmt": p_data["selling"],
        "sku": p_data["sku"],
        "color": "Coffee Brown",
        "stockQty": p_data["stock"],
        "isUnlimitedStock": False,
        "isRecommended": True,
        "policy": "10-day replacement policy for damaged or defective seals. Packaged food items are non-returnable once opened.",
        "images": p_data["img"],
        "options": options,
        "variants": variants,
        "specifications": specs,
        "highlights": highlights,
        "allDetails": all_details,
        "tags": p_data["tags"]
    }
    
    patch_doc(f"companies/{COMPANY_ID}/products/{prod_id}", doc)
    print(f"-> Saved product {prod_id}: {p_data['name']} (Variants: {len(variants)})")

print("\nSUCCESS: All 20 products and 3 categories created and linked to Coffee House!")
