import firebase_admin
from firebase_admin import firestore, credentials
import json
from pathlib import Path


# Build paths relative to this script's location to avoid working-directory issues.
BASE_DIR = Path(__file__).resolve().parent

# Credential JSON (adjust filename if yours differs)
cred_path = BASE_DIR / ''

if not cred_path.exists():
    raise FileNotFoundError(f"Firebase credential file not found at {cred_path}. Provide the path as the first argument or place the file next to this script.")

cred = credentials.Certificate(str(cred_path))
app = firebase_admin.initialize_app(cred)
db = firestore.client()

bankName = 'hardBank'  # Change this to your desired bank name

# JSON data file (relative to script dir)
json_path = BASE_DIR / f"{bankName}.json"
if not json_path.exists():
    raise FileNotFoundError(f"JSON data file not found at {json_path}.")

with json_path.open('r', encoding='utf-8') as f:
    data = json.load(f)

wrapped_data = {"questions": data}
# Add a new doc in collection 'questionBank' with ID 'easyBank'
db.collection('questionBank').document(bankName).set(wrapped_data)