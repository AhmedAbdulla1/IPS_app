import requests
import json

headers = {
    'apikey': 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImRxbm14bGxqcWlxZ3FtbnR6dmN4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODYyNjQwMzIsImV4cCI6MjEwMTg0MDAzMn0.RBcHQxjlZy3Cv-57gaRwM_BISoYaFJfTfJs9kxTLT7w',
    'Authorization': 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImRxbm14bGxqcWlxZ3FtbnR6dmN4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODYyNjQwMzIsImV4cCI6MjEwMTg0MDAzMn0.RBcHQxjlZy3Cv-57gaRwM_BISoYaFJfTfJs9kxTLT7w',
    'Content-Type': 'application/json',
    'Prefer': 'return=representation'
}

base_url = 'https://dqnmxlljqiqgqmntzvcx.supabase.co/rest/v1'

# 1. New Destinations to insert
new_destinations_data = [
    {
        "name_ar": "لجنة حقوق الانسان",
        "name_en": "Human Rights Committee",
        "node_id": 523,
        "aliases_ar": ["حقوق الانسان", "لجنة حقوق الإنسان", "حقوق الإنسان"],
        "aliases_en": ["Human Rights Committee", "Human Rights"]
    },
    {
        "name_ar": "لجنة القوى العاملة",
        "name_en": "Manpower Committee",
        "node_id": 525,
        "aliases_ar": ["القوى العاملة", "القوي العاملة", "لجنة القوي العاملة", "العمل"],
        "aliases_en": ["Manpower Committee", "Manpower", "Workforce Committee"]
    },
    {
        "name_ar": "حزب الجبهة الوطنية",
        "name_en": "National Front Party",
        "node_id": 527,
        "aliases_ar": ["الجبهة الوطنية", "الجبهه الوطنيه", "حزب الجبهه الوطنيه"],
        "aliases_en": ["National Front Party", "National Front"]
    },
    {
        "name_ar": "حزب حماة وطن",
        "name_en": "Homat Watan Party",
        "node_id": 531,
        "aliases_ar": ["حماة وطن", "حماة الوطن", "حزب حماة الوطن", "حماه وطن"],
        "aliases_en": ["Homat Watan Party", "Homat Watan", "Protectors of the Nation"]
    },
    {
        "name_ar": "لجنة الشئون الإقتصادية",
        "name_en": "Economic Affairs Committee",
        "node_id": 533,
        "aliases_ar": ["الشئون الاقتصادية", "اللجنة الاقتصادية", "لجنة الشئون الاقتصادية", "الاقتصاد"],
        "aliases_en": ["Economic Affairs Committee", "Economic Affairs", "Economy"]
    },
    {
        "name_ar": "لجنة السياحة والطيران",
        "name_en": "Tourism & Civil Aviation Committee",
        "node_id": 539,
        "aliases_ar": ["السياحة والطيران", "لجنة السياحة والطيران المدني", "السياحة", "الطيران"],
        "aliases_en": ["Tourism & Civil Aviation Committee", "Tourism", "Aviation"]
    },
    {
        "name_ar": "لجنة المشروعات الصغيرة والمتوسطة",
        "name_en": "Micro, Small & Medium Enterprises Committee",
        "node_id": 545,
        "aliases_ar": ["المشروعات الصغيرة", "المشروعات الصغيرة والمتوسطة", "لجنة المشروعات", "المشروعات"],
        "aliases_en": ["Micro, Small & Medium Enterprises Committee", "MSMEs Committee", "Small Business"]
    },
    {
        "name_ar": "لجنة الشئون الدينية",
        "name_en": "Religious Affairs Committee",
        "node_id": 547,
        "aliases_ar": ["الشئون الدينية", "اللجنة الدينية", "لجنة الشئون الدينية والأوقاف", "الاوقاف", "الأوقاف"],
        "aliases_en": ["Religious Affairs Committee", "Religious Affairs", "Endowments"]
    },
    {
        "name_ar": "لجنة الشباب والرياضة",
        "name_en": "Youth & Sports Committee",
        "node_id": 556,
        "aliases_ar": ["الشباب والرياضة", "الشباب والرياضه", "لجنة الشباب والرياضه", "الرياضة"],
        "aliases_en": ["Youth & Sports Committee", "Youth and Sports", "Sports"]
    },
    {
        "name_ar": "اللجنة العربية",
        "name_en": "Arab Affairs Committee",
        "node_id": 561,
        "aliases_ar": ["الشئون العربية", "لجنة الشئون العربية", "الشئون العربيه", "العربية"],
        "aliases_en": ["Arab Affairs Committee", "Arab Affairs"]
    },
    {
        "name_ar": "لجنة الطاقة والبيئة",
        "name_en": "Energy & Environment Committee",
        "node_id": 625,
        "aliases_ar": ["الطاقة والبيئة", "الطاقة والبيئه", "لجنة الطاقة والبيئه", "البيئة", "الطاقة"],
        "aliases_en": ["Energy & Environment Committee", "Energy and Environment", "Energy"]
    },
    {
        "name_ar": "لجنة الإعلام",
        "name_en": "Media Committee",
        "node_id": 633,
        "aliases_ar": ["الإعلام", "الاعلام", "لجنة الإعلام والثقافة والآثار", "لجنة الاعلام", "الثقافة والآثار"],
        "aliases_en": ["Media Committee", "Media, Culture & Antiquities", "Media"]
    },
    {
        "name_ar": "لجنة الصناعة",
        "name_en": "Industry Committee",
        "node_id": 647,
        "aliases_ar": ["الصناعة", "الصناعه", "لجنة الصناعه"],
        "aliases_en": ["Industry Committee", "Industry"]
    },
    {
        "name_ar": "لجنة الاتصالات والتكنولوجيا",
        "name_en": "Communications & IT Committee",
        "node_id": 656,
        "aliases_ar": ["الاتصالات", "الاتصالات وتكنولوجيا المعلومات", "لجنة الاتصالات", "تكنولوجيا المعلومات"],
        "aliases_en": ["Communications & IT Committee", "Telecom and IT", "Communications"]
    },
    {
        "name_ar": "لجنة الشئون الأفريقية",
        "name_en": "African Affairs Committee",
        "node_id": 747,
        "aliases_ar": ["الشئون الأفريقية", "الشئون الافريقية", "لجنة الشئون الافريقية", "افريقيا", "أفريقيا"],
        "aliases_en": ["African Affairs Committee", "African Affairs", "Africa Committee"]
    },
    {
        "name_ar": "لجنة العلاقات الخارجية",
        "name_en": "Foreign Affairs Committee",
        "node_id": 756,
        "aliases_ar": ["العلاقات الخارجية", "العلاقات الخارجيه", "لجنة العلاقات الخارجيه", "الخارجية"],
        "aliases_en": ["Foreign Affairs Committee", "Foreign Affairs"]
    }
]

# Check existing destinations first to avoid duplicate inserts
existing_dests = requests.get(f'{base_url}/destinations?select=*', headers=headers).json()
existing_names_ar = {d['name_ar']: d for d in existing_dests}

print("=== STEP 1: Updating Dest #49 ('حزب المؤتمر' / 'حزب النور') ===")
r_patch_49 = requests.patch(
    f'{base_url}/destinations?destination_id=eq.49',
    headers=headers,
    json={"name_ar": "حزب المؤتمر", "name_en": "Congress Party"}
)
print(f"Dest 49 update status: {r_patch_49.status_code}")

# Add aliases for Dest 49
aliases_49 = [
    {"destination_id": 49, "alias_text": "حزب المؤتمر", "lang": "ar"},
    {"destination_id": 49, "alias_text": "المؤتمر", "lang": "ar"},
    {"destination_id": 49, "alias_text": "حزب النور", "lang": "ar"},
    {"destination_id": 49, "alias_text": "النور", "lang": "ar"},
    {"destination_id": 49, "alias_text": "Congress Party", "lang": "en"},
    {"destination_id": 49, "alias_text": "Al-Nour Party", "lang": "en"}
]
# Check existing aliases for dest 49
existing_aliases = requests.get(f'{base_url}/destination_aliases?destination_id=eq.49', headers=headers).json()
existing_alias_texts = {a['alias_text'] for a in existing_aliases}
for a in aliases_49:
    if a['alias_text'] not in existing_alias_texts:
        res = requests.post(f'{base_url}/destination_aliases', headers=headers, json=a)
        print(f"  Added alias for Dest 49: {a['alias_text']} ({res.status_code})")

print("\n=== STEP 2: Adding missing elevator nodes to Dest #11 ===")
elevator_node_ids = [513, 535, 558, 613, 635, 658, 713, 735, 758]
existing_dn_11 = requests.get(f'{base_url}/destination_nodes?destination_id=eq.11', headers=headers).json()
existing_elevator_nodes = {dn['node_id'] for dn in existing_dn_11}

for nid in elevator_node_ids:
    if nid not in existing_elevator_nodes:
        res = requests.post(f'{base_url}/destination_nodes', headers=headers, json={"destination_id": 11, "node_id": nid})
        print(f"  Linked elevator Node {nid} to Dest 11: {res.status_code}")
    else:
        print(f"  Elevator Node {nid} already linked to Dest 11")

print("\n=== STEP 3: Inserting New Destinations & Linking Nodes ===")
for item in new_destinations_data:
    ar = item["name_ar"]
    en = item["name_en"]
    nid = item["node_id"]

    if ar in existing_names_ar:
        dest_id = existing_names_ar[ar]["destination_id"]
        print(f"Destination '{ar}' already exists with ID {dest_id}")
    else:
        dest_res = requests.post(
            f'{base_url}/destinations',
            headers=headers,
            json={"name_ar": ar, "name_en": en}
        )
        if dest_res.status_code in [200, 201]:
            dest_id = dest_res.json()[0]["destination_id"]
            print(f"Created Destination '{ar}' (en: '{en}') with ID {dest_id}")
        else:
            print(f"ERROR creating '{ar}': {dest_res.status_code} {dest_res.text}")
            continue

    # Link node in destination_nodes
    existing_dn = requests.get(
        f'{base_url}/destination_nodes?destination_id=eq.{dest_id}&node_id=eq.{nid}',
        headers=headers
    ).json()
    if not existing_dn:
        dn_res = requests.post(
            f'{base_url}/destination_nodes',
            headers=headers,
            json={"destination_id": dest_id, "node_id": nid}
        )
        print(f"  Linked to Node {nid}: status {dn_res.status_code}")
    else:
        print(f"  Node {nid} already linked to Dest {dest_id}")

    # Insert aliases
    existing_a = requests.get(f'{base_url}/destination_aliases?destination_id=eq.{dest_id}', headers=headers).json()
    existing_a_texts = {a['alias_text'] for a in existing_a}

    for alias in item.get("aliases_ar", []):
        if alias not in existing_a_texts:
            requests.post(f'{base_url}/destination_aliases', headers=headers, json={"destination_id": dest_id, "alias_text": alias, "lang": "ar"})
            print(f"    + alias (ar): {alias}")

    for alias in item.get("aliases_en", []):
        if alias not in existing_a_texts:
            requests.post(f'{base_url}/destination_aliases', headers=headers, json={"destination_id": dest_id, "alias_text": alias, "lang": "en"})
            print(f"    + alias (en): {alias}")

print("\n=== STEP 4: Updating nodes.name_en in nodes table ===")
nodes_en_updates = {
    501: "Congress Party",
    523: "Human Rights Committee",
    525: "Manpower Committee",
    527: "National Front Party",
    531: "Homat Watan Party",
    533: "Economic Affairs Committee",
    539: "Tourism & Civil Aviation Committee",
    545: "Micro, Small & Medium Enterprises Committee",
    547: "Religious Affairs Committee",
    556: "Youth & Sports Committee",
    561: "Arab Affairs Committee",
    625: "Energy & Environment Committee",
    633: "Media Committee",
    647: "Industry Committee",
    656: "Communications & IT Committee",
    747: "African Affairs Committee",
    756: "Foreign Affairs Committee",
}

for nid, name_en in nodes_en_updates.items():
    r_node = requests.patch(
        f'{base_url}/nodes?node_id=eq.{nid}',
        headers=headers,
        json={"name_en": name_en}
    )
    print(f"  Updated Node {nid} name_en to '{name_en}': {r_node.status_code}")

print("\n=== ALL UPDATES COMPLETED SUCCESSFULLY ===")
