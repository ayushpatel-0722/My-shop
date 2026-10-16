import urllib.request
import os
import json

REGISTRY_FILE = "scripts/spice_images_registry.json"

def upload_to_catbox(filepath):
    boundary = '----WebKitFormBoundary7MA4YWxkTrZu0gW'
    filename = os.path.basename(filepath)
    with open(filepath, 'rb') as f:
        file_bytes = f.read()

    body = (
        f'--{boundary}\r\n'
        f'Content-Disposition: form-data; name="reqtype"\r\n\r\n'
        f'fileupload\r\n'
        f'--{boundary}\r\n'
        f'Content-Disposition: form-data; name="fileToUpload"; filename="{filename}"\r\n'
        f'Content-Type: image/jpeg\r\n\r\n'
    ).encode('utf-8') + file_bytes + f'\r\n--{boundary}--\r\n'.encode('utf-8')

    req = urllib.request.Request(
        'https://catbox.moe/user/api.php',
        data=body,
        headers={
            'Content-Type': f'multipart/form-data; boundary={boundary}',
            'User-Agent': 'Mozilla/5.0'
        }
    )
    res = urllib.request.urlopen(req)
    url = res.read().decode('utf-8').strip()
    return url

if os.path.exists(REGISTRY_FILE):
    with open(REGISTRY_FILE, 'r') as f:
        registry = json.load(f)
else:
    registry = {}

print(f"Loaded registry with {len(registry)} images.")

