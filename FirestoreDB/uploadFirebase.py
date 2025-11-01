import firebase_admin
from firebase_admin import firestore, credentials
import json
from pathlib import Path


# Build paths relative to this script's location to avoid working-directory issues.
BASE_DIR = Path(__file__).resolve().parent

# Credential JSON (adjust '' with personal private key. In Project Overview -> Service Accounts -> Generate new private key)
cred_path = BASE_DIR / 'firebase-adminsdk.json'

if not cred_path.exists():
    raise FileNotFoundError(f"Firebase credential file not found at {cred_path}. Provide the path as the first argument or place the file next to this script.")

cred = credentials.Certificate(str(cred_path))
app = firebase_admin.initialize_app(cred)
db = firestore.client()


def upload_questions_file(filename: str, collection: str = 'questionBank', doc_id: str | None = None) -> None:
    """Upload a JSON file containing questions to the questionBank collection.

    If the top-level JSON is a list, it will be written as {"questions": <list>} to keep parity
    """
    path = BASE_DIR / filename
    if not path.exists():
        print(f"questions file not found: {path}. Skipping upload.")
        return

    with path.open('r', encoding='utf-8') as f:
        payload = json.load(f)

    if isinstance(payload, list):
        wrapped = {"questions": payload}
    else:
        wrapped = payload

    target_id = doc_id or path.stem
    db.collection(collection).document(target_id).set(wrapped)
    print(f"Uploaded {path} -> collection='{collection}', doc='{target_id}'")


def upload_sequence_doc(filename: str = 'sequenceDoc.json', collection: str = 'gameData', doc_id: str = 'sequenceDoc') -> None:
    """Upload the sequence document JSON to the gameData collection under `sequenceDoc`.

    The JSON file is expected to contain an object/dict representing the document.
    """
    path = BASE_DIR / filename
    if not path.exists():
        print(f"sequence doc file not found: {path}. Skipping upload.")
        return

    with path.open('r', encoding='utf-8') as f:
        payload = json.load(f)

    if not isinstance(payload, dict):
        # If a list was provided, wrap it under a key; this keeps uploads predictable.
        payload = {"sequence": payload}

    db.collection(collection).document(doc_id).set(payload)
    print(f"Uploaded {path} -> collection='{collection}', doc='{doc_id}'")


if __name__ == '__main__':
    # Legacy upload behavior for questions.json
    collectionName = 'gameData' 
    legacy_path = BASE_DIR / f"{collectionName}.json"
    if legacy_path.exists():
        with legacy_path.open('r', encoding='utf-8') as f:
            data = json.load(f)
        wrapped_data = {"questions": data}
        db.collection('questionBank').document(collectionName).set(wrapped_data)

    # Upload questions.json if present
    upload_questions_file('questions.json', collectionName)

    # Upload sequenceDoc.json into the gameData collection under document id 'sequenceDoc'
    upload_sequence_doc('sequenceDoc.json', collectionName)