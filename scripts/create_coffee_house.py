import json
import urllib.request
import urllib.error

API_KEY = "AIzaSyDtmFalx3VDu2a-byx7hoxZKe1a2n9maG8"
PROJECT_ID = "myshop-8bd4d"
ADMIN_EMAIL = "mayurpatel07@gmail.com"
ADMIN_PASS = "Mayur@07@"

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

# 1. Authenticate Admin
print("--> Authenticating admin user...")
auth_url = f"https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key={API_KEY}"
auth_req = urllib.request.Request(
    auth_url,
    data=json.dumps({"email": ADMIN_EMAIL, "password": ADMIN_PASS, "returnSecureToken": True}).encode(),
    headers={"Content-Type": "application/json"}
)
auth_res = urllib.request.urlopen(auth_req)
auth_data = json.loads(auth_res.read().decode())
token = auth_data["idToken"]
admin_uid = auth_data["localId"]
print(f"Authenticated UID: {admin_uid}")

headers = {
    "Authorization": f"Bearer {token}",
    "Content-Type": "application/json"
}

def patch_doc(path, data):
    url = f"https://firestore.googleapis.com/v1/projects/{PROJECT_ID}/databases/(default)/documents/{path}"
    payload = to_fs_doc(data)
    req = urllib.request.Request(url, data=json.dumps(payload).encode(), headers=headers, method="PATCH")
    try:
        res = urllib.request.urlopen(req)
        return json.loads(res.read().decode())
    except urllib.error.HTTPError as e:
        print(f"Error writing {path}: {e.code} - {e.read().decode()}")
        raise

# 2. Create Company
COMPANY_ID = "coffee-house-shop"
print(f"--> Creating / Updating Company: {COMPANY_ID}")

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
    "category": "Coffee Shop",
    "details": "Specialty artisanal coffee shop offering hand-roasted gourmet beans, premium single-origin Arabica, signature espresso blends, and handcrafted cold brews.",
    "address": "101 Coffee Street, Ahmedabad, Gujarat, India",
    "companyPassword": ADMIN_PASS,
    "currency": "INR",
    "deliveryTypes": ["self_pickup", "home_delivery"],
    "minOrderAmount": 200.0,
    "logoUrl": "https://images.unsplash.com/photo-1501339847302-ac426a4a7cbb?w=500&auto=format&fit=crop&q=80",
    "bannerUrl": "https://images.unsplash.com/photo-1495474472287-4d71bcdd2085?w=1200&auto=format&fit=crop&q=80",
    "profileImageUrl": "https://images.unsplash.com/photo-1447933601403-0c6688de566e?w=800&auto=format&fit=crop&q=80",
    "status": "active",
    "rating": 4.8,
    "reviewCount": 18,
    "followers": 142,
    "isVerified": True,
    "handlingMinutes": 25,
    "deliveryMinutes": 30,
    "weeklyHours": weekly_hours,
    "openingDate": "2026-10-06T09:00:00.000Z"
}

patch_doc(f"companies/{COMPANY_ID}", company_data)
print("Company created successfully!")

# 3. Create Admin link
print(f"--> Linking Admin {ADMIN_EMAIL} to Company...")
admin_data = {
    "id": admin_uid,
    "companyId": COMPANY_ID,
    "email": ADMIN_EMAIL,
    "name": "Mayur Patel",
    "mobileNumber": "+919876543210",
    "address": "101 Coffee Street, Ahmedabad"
}
patch_doc(f"companies/{COMPANY_ID}/admins/{admin_uid}", admin_data)

user_data = {
    "id": admin_uid,
    "role": "admin",
    "companyId": COMPANY_ID,
    "email": ADMIN_EMAIL,
    "name": "Mayur Patel"
}
patch_doc(f"users/{admin_uid}", user_data)
print("Admin linked successfully!")

# 4. Create Categories
print("--> Creating Coffee Categories...")
categories = [
    {
        "id": "cat-instant-coffee",
        "name": "Instant Coffee",
        "companyId": COMPANY_ID,
        "details": "Rich and soluble everyday instant coffee granules",
        "type": "Coffee",
        "iconUrl": "https://images.unsplash.com/photo-1514432324607-a09d9b4aefdd?w=200&auto=format&fit=crop&q=80",
        "sortOrder": 1,
        "productList": ["prod-classic-instant", "prod-espresso-intense"]
    },
    {
        "id": "cat-espresso-roast",
        "name": "Espresso & Roast",
        "companyId": COMPANY_ID,
        "details": "Intense dark roasts and espresso-style blends",
        "type": "Coffee",
        "iconUrl": "https://images.unsplash.com/photo-1510591509098-f4fdc6d0ff04?w=200&auto=format&fit=crop&q=80",
        "sortOrder": 2,
        "productList": ["prod-espresso-intense", "prod-french-roast"]
    },
    {
        "id": "cat-arabica-beans",
        "name": "Gourmet Beans & Arabica",
        "companyId": COMPANY_ID,
        "details": "100% Single-origin Arabica and whole roasted beans",
        "type": "Coffee",
        "iconUrl": "https://images.unsplash.com/photo-1559056199-641a0ac8b55e?w=200&auto=format&fit=crop&q=80",
        "sortOrder": 3,
        "productList": ["prod-premium-arabica", "prod-luxury-espresso-beans"]
    },
    {
        "id": "cat-flavored-coffee",
        "name": "Flavored Coffee",
        "companyId": COMPANY_ID,
        "details": "Infused gourmet coffees with hazelnut and chocolate mocha notes",
        "type": "Coffee",
        "iconUrl": "https://images.unsplash.com/photo-1517256064527-09c73fc73e38?w=200&auto=format&fit=crop&q=80",
        "sortOrder": 4,
        "productList": ["prod-hazelnut-flavored", "prod-mocha-chocolate"]
    },
    {
        "id": "cat-cold-brew",
        "name": "Cold Brew",
        "companyId": COMPANY_ID,
        "details": "Coarse grounds crafted specifically for smooth cold extraction",
        "type": "Coffee",
        "iconUrl": "https://images.unsplash.com/photo-1517701550927-30cf4ba1dba5?w=200&auto=format&fit=crop&q=80",
        "sortOrder": 5,
        "productList": ["prod-cold-brew-premium"]
    }
]

for cat in categories:
    patch_doc(f"companies/{COMPANY_ID}/categories/{cat['id']}", cat)
    print(f"Created category: {cat['name']}")

# 5. Create 8 Products
print("--> Creating 8 Coffee Products with complete Flipkart-style details...")

products = [
    # 1. Classic Instant Coffee – 100 g
    {
        "id": "prod-classic-instant",
        "companyId": COMPANY_ID,
        "categoryId": "cat-instant-coffee",
        "name": "Classic Instant Coffee – 100 g",
        "details": "Rich and smooth everyday instant coffee crafted from premium roasted coffee beans. Delivers a perfectly balanced cup every morning.",
        "subDetails": "100% Pure Instant Soluble Coffee | Medium Roast | Balanced Intensity",
        "type": "quantity_based",
        "unit": 100.0,
        "unitType": "g",
        "amount": 320.0,       # MRP
        "discountAmt": 269.0, # Selling Price
        "sku": "CH-CIC-100G",
        "color": "Warm Amber",
        "stockQty": 75,
        "isUnlimitedStock": False,
        "isRecommended": True,
        "policy": "10-day replacement for damaged or unsealed jars. Food items non-returnable once opened.",
        "images": [
            "https://images.unsplash.com/photo-1514432324607-a09d9b4aefdd?w=800&auto=format&fit=crop&q=80",
            "https://images.unsplash.com/photo-1517256064527-09c73fc73e38?w=800&auto=format&fit=crop&q=80"
        ],
        "options": [
            {"name": "Pack Size", "values": ["100 g", "200 g"]}
        ],
        "variants": [
            {
                "id": "var-cic-100g",
                "sku": "CH-CIC-100G",
                "title": "100 g Jar",
                "size": "100 g",
                "color": "",
                "attributes": {"Pack Size": "100 g"},
                "stockQty": 75,
                "isUnlimitedStock": False,
                "priceOverride": 269.0,
                "mrpOverride": 320.0,
                "unitValue": 100.0,
                "unitType": "g"
            },
            {
                "id": "var-cic-200g",
                "sku": "CH-CIC-200G",
                "title": "200 g Value Pack",
                "size": "200 g",
                "color": "",
                "attributes": {"Pack Size": "200 g"},
                "stockQty": 45,
                "isUnlimitedStock": False,
                "priceOverride": 499.0,
                "mrpOverride": 599.0,
                "unitValue": 200.0,
                "unitType": "g"
            }
        ],
        "specifications": [
            {"key": "Brand", "value": "Coffee House"},
            {"key": "Roast Level", "value": "Medium Roast"},
            {"key": "Coffee Type", "value": "100% Pure Instant Soluble Coffee"},
            {"key": "Intensity", "value": "3 / 5 (Balanced)"},
            {"key": "Flavor Notes", "value": "Smooth Caramel & Mild Nutty"},
            {"key": "Container Type", "value": "Aroma-Lock Glass Jar"},
            {"key": "Shelf Life", "value": "24 Months"},
            {"key": "Country of Origin", "value": "India"}
        ],
        "highlights": [
            {"id": "h1", "title": "Coffee Type", "value": "100% Pure Soluble Coffee Granules", "order": 1},
            {"id": "h2", "title": "Roast & Intensity", "value": "Medium Roast | Balanced Intensity 3/5", "order": 2},
            {"id": "h3", "title": "Preparation", "value": "Suitable for hot brewed coffee and iced frappé", "order": 3},
            {"id": "h4", "title": "Packaging", "value": "Premium airtight glass jar locking in aroma", "order": 4}
        ],
        "allDetails": [
            {
                "id": "d1",
                "title": "Product Overview",
                "type": "text",
                "text": "Indulge in the rich aroma and velvety taste of Classic Instant Coffee. Sourced from the finest plantations, this blend offers a balanced flavor profile that dissolves effortlessly for a refreshing morning brew or a soothing evening cup. Perfect for hot coffee, cold coffee, and lattes.",
                "order": 1
            },
            {
                "id": "d2",
                "title": "Specifications",
                "type": "keyValue",
                "order": 2,
                "items": [
                    {"id": "s1", "title": "Brand", "value": "Coffee House", "order": 1},
                    {"id": "s2", "title": "Ingredients", "value": "100% Pure Soluble Coffee", "order": 2},
                    {"id": "s3", "title": "Roast", "value": "Medium Roast", "order": 3},
                    {"id": "s4", "title": "Serving Suggestion", "value": "1-2 tsp in hot/cold milk or water", "order": 4},
                    {"id": "s5", "title": "Storage", "value": "Store in a cool, dry place. Reseal tightly.", "order": 5}
                ]
            }
        ]
    },

    # 2. Espresso Intense Coffee – 100 g
    {
        "id": "prod-espresso-intense",
        "companyId": COMPANY_ID,
        "categoryId": "cat-espresso-roast",
        "name": "Espresso Intense Coffee – 100 g",
        "details": "Strong espresso-style dark roasted coffee delivering high intensity, rich aroma, and bold flavor with European cafe flair.",
        "subDetails": "Dark Roast Espresso | Intensity 5/5 | Rich Aroma & Bold Crema",
        "type": "quantity_based",
        "unit": 100.0,
        "unitType": "g",
        "amount": 475.0,
        "discountAmt": 389.0,
        "sku": "CH-EIC-100G",
        "color": "Deep Mahogany",
        "stockQty": 60,
        "isUnlimitedStock": False,
        "isRecommended": True,
        "policy": "10-day replacement for damaged or unsealed jars.",
        "images": [
            "https://images.unsplash.com/photo-1510591509098-f4fdc6d0ff04?w=800&auto=format&fit=crop&q=80",
            "https://images.unsplash.com/photo-1514432324607-a09d9b4aefdd?w=800&auto=format&fit=crop&q=80"
        ],
        "options": [
            {"name": "Pack Size", "values": ["100 g", "250 g"]}
        ],
        "variants": [
            {
                "id": "var-eic-100g",
                "sku": "CH-EIC-100G",
                "title": "100 g Jar",
                "size": "100 g",
                "attributes": {"Pack Size": "100 g"},
                "stockQty": 60,
                "priceOverride": 389.0,
                "mrpOverride": 475.0,
                "unitValue": 100.0,
                "unitType": "g"
            },
            {
                "id": "var-eic-250g",
                "sku": "CH-EIC-250G",
                "title": "250 g Tin",
                "size": "250 g",
                "attributes": {"Pack Size": "250 g"},
                "stockQty": 35,
                "priceOverride": 799.0,
                "mrpOverride": 999.0,
                "unitValue": 250.0,
                "unitType": "g"
            }
        ],
        "specifications": [
            {"key": "Brand", "value": "Coffee House"},
            {"key": "Roast Level", "value": "Dark Roast (Espresso 57 Inspired)"},
            {"key": "Coffee Type", "value": "Espresso-Style Soluble Coffee"},
            {"key": "Intensity", "value": "5 / 5 (High Intensity)"},
            {"key": "Flavor Notes", "value": "Dark Cocoa, Smoky Nut & Intense Crema"},
            {"key": "Shelf Life", "value": "24 Months"},
            {"key": "Country of Origin", "value": "India"}
        ],
        "highlights": [
            {"id": "h1", "title": "High Intensity", "value": "Robust 5/5 dark roast for intense espresso flavor", "order": 1},
            {"id": "h2", "title": "Crema & Body", "value": "Thick golden crema with velvety dark chocolate finish", "order": 2},
            {"id": "h3", "title": "No Chicory", "value": "100% Pure gourmet roasted coffee with zero fillers", "order": 3},
            {"id": "h4", "title": "Versatile", "value": "Exceptional as black espresso, Americano, or strong cappuccino", "order": 4}
        ],
        "allDetails": [
            {
                "id": "d1",
                "title": "Product Overview",
                "type": "text",
                "text": "Inspired by the European espresso tradition, Espresso Intense delivers an unapologetically bold, full-bodied coffee experience. Crafted from meticulously dark-roasted beans, it releases intense chocolatey undertones and a dense, golden crema.",
                "order": 1
            },
            {
                "id": "d2",
                "title": "Specifications",
                "type": "keyValue",
                "order": 2,
                "items": [
                    {"id": "s1", "title": "Brand", "value": "Coffee House", "order": 1},
                    {"id": "s2", "title": "Ingredients", "value": "100% Premium Arabica & Selection Robusta", "order": 2},
                    {"id": "s3", "title": "Form", "value": "Agglomerated Instant Granules", "order": 3},
                    {"id": "s4", "title": "Storage Instructions", "value": "Keep in a cool, dry place. Do not refrigerate.", "order": 4}
                ]
            }
        ]
    },

    # 3. Premium Arabica Coffee – 200 g
    {
        "id": "prod-premium-arabica",
        "companyId": COMPANY_ID,
        "categoryId": "cat-arabica-beans",
        "name": "Premium Arabica Coffee – 200 g",
        "details": "100% Single-origin Arabica beans, medium roasted to perfection for an extraordinarily smooth and aromatic cup.",
        "subDetails": "100% Arabica | Chikmagalur Single Origin | Floral & Caramel Notes",
        "type": "quantity_based",
        "unit": 200.0,
        "unitType": "g",
        "amount": 599.0,
        "discountAmt": 489.0,
        "sku": "CH-PAC-200G",
        "color": "Chestnut Brown",
        "stockQty": 45,
        "isUnlimitedStock": False,
        "isRecommended": True,
        "policy": "10-day replacement for damaged packaging.",
        "images": [
            "https://images.unsplash.com/photo-1559056199-641a0ac8b55e?w=800&auto=format&fit=crop&q=80",
            "https://images.unsplash.com/photo-1587734195503-904fca47e0e9?w=800&auto=format&fit=crop&q=80"
        ],
        "options": [
            {"name": "Grind Type", "values": ["Medium Ground", "Whole Beans"]}
        ],
        "variants": [
            {
                "id": "var-pac-ground",
                "sku": "CH-PAC-200G-G",
                "title": "Medium Ground 200 g",
                "size": "200 g",
                "attributes": {"Grind Type": "Medium Ground"},
                "stockQty": 45,
                "priceOverride": 489.0,
                "mrpOverride": 599.0,
                "unitValue": 200.0,
                "unitType": "g"
            },
            {
                "id": "var-pac-beans",
                "sku": "CH-PAC-200G-B",
                "title": "Whole Beans 200 g",
                "size": "200 g",
                "attributes": {"Grind Type": "Whole Beans"},
                "stockQty": 30,
                "priceOverride": 519.0,
                "mrpOverride": 649.0,
                "unitValue": 200.0,
                "unitType": "g"
            }
        ],
        "specifications": [
            {"key": "Brand", "value": "Coffee House"},
            {"key": "Bean Variety", "value": "100% Plantation Arabica AAA"},
            {"key": "Roast", "value": "Artisan Medium Roast"},
            {"key": "Origin", "value": "Chikmagalur, Karnataka, India"},
            {"key": "Elevation", "value": "3800 ft above sea level"},
            {"key": "Shelf Life", "value": "18 Months"}
        ],
        "highlights": [
            {"id": "h1", "title": "100% Arabica", "value": "Hand-picked high altitude plantation Arabica beans", "order": 1},
            {"id": "h2", "title": "Tasting Notes", "value": "Subtle floral aromatics with smooth caramel finish", "order": 2},
            {"id": "h3", "title": "Brew Methods", "value": "Pour-over, Drip machine, Aeropress, French press", "order": 3},
            {"id": "h4", "title": "Freshness Valve", "value": "Triple-layer barrier pouch with degassing aroma valve", "order": 4}
        ],
        "allDetails": [
            {
                "id": "d1",
                "title": "Product Story",
                "type": "text",
                "text": "Grown in shade at high altitudes in Chikmagalur, this 100% Arabica artisanal coffee boasts delicate floral aromatics with caramel undertones. Hand-picked beans undergo slow roasting to preserve delicate volatile oils, yielding an exceptionally smooth cup without harsh bitterness.",
                "order": 1
            },
            {
                "id": "d2",
                "title": "Specifications",
                "type": "keyValue",
                "order": 2,
                "items": [
                    {"id": "s1", "title": "Origin", "value": "Chikmagalur, India", "order": 1},
                    {"id": "s2", "title": "Processing", "value": "Washed / Sun-Dried", "order": 2},
                    {"id": "s3", "title": "Acidity", "value": "Gentle, pleasant citric acidity", "order": 3},
                    {"id": "s4", "title": "Body", "value": "Silky, medium-bodied", "order": 4}
                ]
            }
        ]
    },

    # 4. French Roast Dark Coffee – 200 g
    {
        "id": "prod-french-roast",
        "companyId": COMPANY_ID,
        "categoryId": "cat-espresso-roast",
        "name": "French Roast Dark Coffee – 200 g",
        "details": "Dark roasted coffee with a strong, smoky flavor profile, heavy body, and intense aroma. Ideal for espresso and French press.",
        "subDetails": "Extra Dark French Roast | Smoky Molasses Notes | Intensity 5/5",
        "type": "quantity_based",
        "unit": 200.0,
        "unitType": "g",
        "amount": 550.0,
        "discountAmt": 449.0,
        "sku": "CH-FRD-200G",
        "color": "Smoky Black",
        "stockQty": 50,
        "isUnlimitedStock": False,
        "isRecommended": False,
        "policy": "10-day replacement for damaged items.",
        "images": [
            "https://images.unsplash.com/photo-1587734195503-904fca47e0e9?w=800&auto=format&fit=crop&q=80",
            "https://images.unsplash.com/photo-1559056199-641a0ac8b55e?w=800&auto=format&fit=crop&q=80"
        ],
        "options": [],
        "variants": [],
        "specifications": [
            {"key": "Brand", "value": "Coffee House"},
            {"key": "Roast Style", "value": "French Roast (Second Crack)"},
            {"key": "Intensity", "value": "5 / 5 (Maximum Boldness)"},
            {"key": "Flavor Notes", "value": "Smoky Molasses, Toasted Oak & Dark Cocoa"},
            {"key": "Shelf Life", "value": "18 Months"},
            {"key": "Country of Origin", "value": "India"}
        ],
        "highlights": [
            {"id": "h1", "title": "Deep French Roast", "value": "Roasted to second crack for glistening, oil-rich beans", "order": 1},
            {"id": "h2", "title": "Low Acidity", "value": "Virtually zero acidity with deep smoky molasses undertones", "order": 2},
            {"id": "h3", "title": "Suitable Preparation", "value": "French press, Espresso machine, South Indian filter", "order": 3},
            {"id": "h4", "title": "Heavy Body", "value": "Thick, syrupy mouthfeel that stands up to milk and cream", "order": 4}
        ],
        "allDetails": [
            {
                "id": "d1",
                "title": "About This Roast",
                "type": "text",
                "text": "Our French Roast is roasted slowly to the second crack, bringing the natural coffee oils to the surface for a shiny, deep mahogany bean. It features a bold, smoky character with notes of molasses and toasted cedar, perfect for those who crave a heavy, robust body.",
                "order": 1
            },
            {
                "id": "d2",
                "title": "Specifications",
                "type": "keyValue",
                "order": 2,
                "items": [
                    {"id": "s1", "title": "Roast Master Notes", "value": "Deep, smoky and bittersweet", "order": 1},
                    {"id": "s2", "title": "Grind Consistency", "value": "Coarse to Medium", "order": 2},
                    {"id": "s3", "title": "Ingredients", "value": "100% Pure Roasted Coffee", "order": 3}
                ]
            }
        ]
    },

    # 5. Hazelnut Flavored Coffee – 100 g
    {
        "id": "prod-hazelnut-flavored",
        "companyId": COMPANY_ID,
        "categoryId": "cat-flavored-coffee",
        "name": "Hazelnut Flavored Coffee – 100 g",
        "details": "Smooth medium-roasted coffee naturally infused with warm, toasted hazelnut flavors and a delicate sweet nutty aroma.",
        "subDetails": "Toasted Hazelnut Infusion | Zero Added Sugar | Mild-to-Medium Intensity",
        "type": "quantity_based",
        "unit": 100.0,
        "unitType": "g",
        "amount": 399.0,
        "discountAmt": 329.0,
        "sku": "CH-HFC-100G",
        "color": "Golden Hazel",
        "stockQty": 80,
        "isUnlimitedStock": False,
        "isRecommended": True,
        "policy": "10-day replacement for sealed jars.",
        "images": [
            "https://images.unsplash.com/photo-1517256064527-09c73fc73e38?w=800&auto=format&fit=crop&q=80",
            "https://images.unsplash.com/photo-1541167760496-1628856ab772?w=800&auto=format&fit=crop&q=80"
        ],
        "options": [
            {"name": "Size", "values": ["100 g", "200 g"]}
        ],
        "variants": [
            {
                "id": "var-hfc-100g",
                "sku": "CH-HFC-100G",
                "title": "100 g Jar",
                "size": "100 g",
                "attributes": {"Size": "100 g"},
                "stockQty": 80,
                "priceOverride": 329.0,
                "mrpOverride": 399.0,
                "unitValue": 100.0,
                "unitType": "g"
            },
            {
                "id": "var-hfc-200g",
                "sku": "CH-HFC-200G",
                "title": "200 g Jar",
                "size": "200 g",
                "attributes": {"Size": "200 g"},
                "stockQty": 55,
                "priceOverride": 599.0,
                "mrpOverride": 749.0,
                "unitValue": 200.0,
                "unitType": "g"
            }
        ],
        "specifications": [
            {"key": "Brand", "value": "Coffee House"},
            {"key": "Flavor", "value": "Toasted Hazelnut"},
            {"key": "Added Sugar", "value": "0g (Zero Added Sugar)"},
            {"key": "Roast Level", "value": "Medium Roast"},
            {"key": "Intensity", "value": "3 / 5"},
            {"key": "Shelf Life", "value": "24 Months"},
            {"key": "Country of Origin", "value": "India"}
        ],
        "highlights": [
            {"id": "h1", "title": "Nutty Aroma", "value": "Warm, buttery toasted hazelnut infusion", "order": 1},
            {"id": "h2", "title": "Zero Added Sugar", "value": "Guilt-free dessert coffee without syrup or artificial sweeteners", "order": 2},
            {"id": "h3", "title": "Quick Dissolve", "value": "Dissolves instantly in hot milk, cold milk, or water", "order": 3},
            {"id": "h4", "title": "Café Experience", "value": "Enjoy a hazelnut latte from the comfort of your kitchen", "order": 4}
        ],
        "allDetails": [
            {
                "id": "d1",
                "title": "Product Overview",
                "type": "text",
                "text": "Elevate your daily routine with our decadent Hazelnut Flavored Coffee. We blend premium medium-roasted coffee with natural toasted hazelnut notes, creating a sweet, nutty, comforting beverage that tastes like a specialty coffeehouse dessert in every sip.",
                "order": 1
            },
            {
                "id": "d2",
                "title": "Nutritional & Ingredients",
                "type": "keyValue",
                "order": 2,
                "items": [
                    {"id": "s1", "title": "Ingredients", "value": "Pure Soluble Coffee, Nature-Identical Hazelnut Flavors", "order": 1},
                    {"id": "s2", "title": "Calories Per Cup", "value": "< 4 kcal", "order": 2},
                    {"id": "s3", "title": "Dietary", "value": "100% Vegetarian & Vegan Friendly", "order": 3}
                ]
            }
        ]
    },

    # 6. Mocha Chocolate Coffee – 100 g
    {
        "id": "prod-mocha-chocolate",
        "companyId": COMPANY_ID,
        "categoryId": "cat-flavored-coffee",
        "name": "Mocha Chocolate Coffee – 100 g",
        "details": "Indulgent coffee blend infused with rich Belgian cocoa and velvety mocha chocolate notes. Perfect for hot and iced coffee.",
        "subDetails": "Belgian Chocolate Infusion | Medium-Dark Roast | Creamy Taste",
        "type": "quantity_based",
        "unit": 100.0,
        "unitType": "g",
        "amount": 410.0,
        "discountAmt": 339.0,
        "sku": "CH-MCC-100G",
        "color": "Rich Cocoa",
        "stockQty": 70,
        "isUnlimitedStock": False,
        "isRecommended": True,
        "policy": "10-day replacement for damaged packaging.",
        "images": [
            "https://images.unsplash.com/photo-1541167760496-1628856ab772?w=800&auto=format&fit=crop&q=80",
            "https://images.unsplash.com/photo-1514432324607-a09d9b4aefdd?w=800&auto=format&fit=crop&q=80"
        ],
        "options": [],
        "variants": [],
        "specifications": [
            {"key": "Brand", "value": "Coffee House"},
            {"key": "Flavor", "value": "Belgian Dark Chocolate Mocha"},
            {"key": "Roast Level", "value": "Medium-Dark Roast"},
            {"key": "Intensity", "value": "3.5 / 5"},
            {"key": "Form", "value": "Instant Coffee Granules"},
            {"key": "Shelf Life", "value": "24 Months"},
            {"key": "Country of Origin", "value": "India"}
        ],
        "highlights": [
            {"id": "h1", "title": "Real Cocoa Notes", "value": "Blended with rich cocoa extracts for authentic mocha richness", "order": 1},
            {"id": "h2", "title": "Hot & Iced", "value": "Super creamy in hot lattes, refreshing in iced frappes", "order": 2},
            {"id": "h3", "title": "Zero Added Sugar", "value": "All the indulgence of chocolate without sugar spikes", "order": 3},
            {"id": "h4", "title": "Aroma Lock", "value": "Double-sealed luxury glass jar maintains freshness", "order": 4}
        ],
        "allDetails": [
            {
                "id": "d1",
                "title": "Flavor Journey",
                "type": "text",
                "text": "The timeless pairing of dark roasted coffee and velvety Belgian chocolate notes. Mocha Chocolate Coffee brings the luxury of a barista-crafted mocha right to your home. Rich, indulgent, and satisfying without any added syrup or sugar.",
                "order": 1
            },
            {
                "id": "d2",
                "title": "Specifications",
                "type": "keyValue",
                "order": 2,
                "items": [
                    {"id": "s1", "title": "Ingredients", "value": "100% Soluble Coffee, Natural Cocoa Extract, Flavoring", "order": 1},
                    {"id": "s2", "title": "Preparation", "value": "Whisk 1 tsp with hot milk for a silky café mocha", "order": 2},
                    {"id": "s3", "title": "Packaging", "value": "Hermetically sealed 100g glass jar", "order": 3}
                ]
            }
        ]
    },

    # 7. Cold Brew Premium Coffee – 250 g
    {
        "id": "prod-cold-brew-premium",
        "companyId": COMPANY_ID,
        "categoryId": "cat-cold-brew",
        "name": "Cold Brew Premium Coffee – 250 g",
        "details": "Specially formulated coarse ground blend for slow 18-hour cold steeping. Delivers a silky smooth, low-bitterness profile with notes of honey and chocolate.",
        "subDetails": "Coarse Ground for Cold Extraction | 65% Less Acidity | Naturally Sweet",
        "type": "quantity_based",
        "unit": 250.0,
        "unitType": "g",
        "amount": 650.0,
        "discountAmt": 549.0,
        "sku": "CH-CBP-250G",
        "color": "Muted Charcoal",
        "stockQty": 40,
        "isUnlimitedStock": False,
        "isRecommended": True,
        "policy": "10-day replacement for damaged pouches.",
        "images": [
            "https://images.unsplash.com/photo-1517701550927-30cf4ba1dba5?w=800&auto=format&fit=crop&q=80",
            "https://images.unsplash.com/photo-1559056199-641a0ac8b55e?w=800&auto=format&fit=crop&q=80"
        ],
        "options": [],
        "variants": [],
        "specifications": [
            {"key": "Brand", "value": "Coffee House"},
            {"key": "Grind Size", "value": "Extra Coarse (Cold Brew Calibrated)"},
            {"key": "Roast", "value": "Medium Roast"},
            {"key": "Acidity Level", "value": "Ultra-Low (65% lower than hot brew)"},
            {"key": "Flavor Notes", "value": "Dark Chocolate, Honeycomb & Dried Plum"},
            {"key": "Shelf Life", "value": "12 Months"},
            {"key": "Country of Origin", "value": "India"}
        ],
        "highlights": [
            {"id": "h1", "title": "Cold Brew Specific", "value": "Extra-coarse grinds engineered for slow 16-24 hr cold extraction", "order": 1},
            {"id": "h2", "title": "Naturally Sweet", "value": "Smooth, low-bitterness profile with high natural sweetness", "order": 2},
            {"id": "h3", "title": "Concentrate Yield", "value": "Makes up to 15-20 cups of concentrated cold brew elixir", "order": 3},
            {"id": "h4", "title": "Brewing Bag Included", "value": "Comes with a reusable organic cotton cold brew filter bag", "order": 4}
        ],
        "allDetails": [
            {
                "id": "d1",
                "title": "Cold Brew Guide",
                "type": "text",
                "text": "Designed from the ground up for cold extraction. Coarsely ground to allow slow 16-24 hour steep times without sediment or bitter over-extraction. The result is an ultra-smooth, naturally sweet, concentrated coffee liquor packed with chocolatey and fruity notes.",
                "order": 1
            },
            {
                "id": "d2",
                "title": "Brewing Steps",
                "type": "keyValue",
                "order": 2,
                "items": [
                    {"id": "s1", "title": "Step 1", "value": "Add 50g coffee to 500ml cold filtered water", "order": 1},
                    {"id": "s2", "title": "Step 2", "value": "Steep in refrigerator for 16-18 hours", "order": 2},
                    {"id": "s3", "title": "Step 3", "value": "Filter and serve over ice with milk or tonic", "order": 3},
                    {"id": "s4", "title": "Storage", "value": "Brewed concentrate keeps fresh for up to 10 days refrigerated", "order": 4}
                ]
            }
        ]
    },

    # 8. Luxury Espresso Coffee Beans – 500 g
    {
        "id": "prod-luxury-espresso-beans",
        "companyId": COMPANY_ID,
        "categoryId": "cat-arabica-beans",
        "name": "Luxury Espresso Coffee Beans – 500 g",
        "details": "Whole bean artisanal espresso roast with rich crema and complex chocolate-caramel profile. Master-roasted for espresso machines and connoisseurs.",
        "subDetails": "Whole Coffee Beans | Italian Dark Roast | Thick Crema Blend",
        "type": "quantity_based",
        "unit": 500.0,
        "unitType": "g",
        "amount": 1150.0,
        "discountAmt": 949.0,
        "sku": "CH-LEB-500G",
        "color": "Onyx Black",
        "stockQty": 35,
        "isUnlimitedStock": False,
        "isRecommended": True,
        "policy": "10-day replacement for damaged valve pouches.",
        "images": [
            "https://images.unsplash.com/photo-1550547660-d9450f859349?w=800&auto=format&fit=crop&q=80",
            "https://images.unsplash.com/photo-1559056199-641a0ac8b55e?w=800&auto=format&fit=crop&q=80"
        ],
        "options": [
            {"name": "Pack Size", "values": ["500 g", "1 kg"]}
        ],
        "variants": [
            {
                "id": "var-leb-500g",
                "sku": "CH-LEB-500G",
                "title": "500 g Foil Bag",
                "size": "500 g",
                "attributes": {"Pack Size": "500 g"},
                "stockQty": 35,
                "priceOverride": 949.0,
                "mrpOverride": 1150.0,
                "unitValue": 500.0,
                "unitType": "g"
            },
            {
                "id": "var-leb-1kg",
                "sku": "CH-LEB-1KG",
                "title": "1 kg Barista Bag",
                "size": "1 kg",
                "attributes": {"Pack Size": "1 kg"},
                "stockQty": 20,
                "priceOverride": 1799.0,
                "mrpOverride": 2200.0,
                "unitValue": 1000.0,
                "unitType": "g"
            }
        ],
        "specifications": [
            {"key": "Brand", "value": "Coffee House"},
            {"key": "Form", "value": "100% Whole Roasted Coffee Beans"},
            {"key": "Blend", "value": "80% Plantation Arabica, 20% Washed Robusta"},
            {"key": "Roast Level", "value": "Dark Italian Roast"},
            {"key": "Intensity", "value": "5 / 5"},
            {"key": "Flavor Notes", "value": "Dark Cacao, Molasses & Toasted Walnut"},
            {"key": "Shelf Life", "value": "18 Months"},
            {"key": "Country of Origin", "value": "India"}
        ],
        "highlights": [
            {"id": "h1", "title": "Whole Bean Freshness", "value": "Grind on demand for unmatched aromatic vibrancy", "order": 1},
            {"id": "h2", "title": "Barista Crema", "value": "Engineered blend produces thick hazelnut crema in espresso machines", "order": 2},
            {"id": "h3", "title": "Ethically Sourced", "value": "100% Rainforest Alliance certified estate beans", "order": 3},
            {"id": "h4", "title": "Degassing Valve", "value": "Protective valve releases CO2 while blocking oxygen", "order": 4}
        ],
        "allDetails": [
            {
                "id": "d1",
                "title": "Master Roaster Notes",
                "type": "text",
                "text": "The pinnacle of espresso craftsmanship. Our master roasters slow-roast top-grade Arabica and washed Indian Robusta beans to a gleaming dark roast. Specifically blended to yield a rich, persistent golden crema, syrup-like body, and notes of caramelized sugar and dark cocoa in traditional espresso machines.",
                "order": 1
            },
            {
                "id": "d2",
                "title": "Specifications",
                "type": "keyValue",
                "order": 2,
                "items": [
                    {"id": "s1", "title": "Suitable For", "value": "Espresso Machine, Moka Pot, Manual Lever, French Press", "order": 1},
                    {"id": "s2", "title": "Bean Composition", "value": "80% Arabica, 20% Robusta", "order": 2},
                    {"id": "s3", "title": "Storage", "value": "Store whole beans in valved bag in dark dry cabinet", "order": 3}
                ]
            }
        ]
    }
]

for p in products:
    patch_doc(f"companies/{COMPANY_ID}/products/{p['id']}", p)
    print(f"Created product: {p['name']} ({p['sku']}) - Rs. {p['discountAmt']} (MRP Rs. {p['amount']})")

print("\nSUCCESS: Coffee House shop, admin account, categories, and all 8 products configured successfully!")

