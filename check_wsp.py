import json
with open('WrtingShedPro/Writing Shed Pro/Resources/The Republic of Heaven.wsp', 'r') as f:
    data = json.load(f)

print("=== POETRY COLLECTIONS ===")
for pc in data.get('poetryCollections', []):
    print(f"  Collection: '{pc.get('name')}' id={pc.get('id')} isInBodyMatter={pc.get('isInBodyMatter')} bodyMatterOrder={pc.get('bodyMatterOrder')}")

print()
print("=== POEMS FOLDER TEXT FILES (collection links) ===")
for folder in data['folders']:
    if folder.get('name') == 'Poems':
        files = folder.get('textFiles', [])
        print(f"  Total files in Poems folder: {len(files)}")
        for tf in files[:5]:
            print(f"  File: '{tf.get('name')}'")
            print(f"    poetryCollectionId: {tf.get('poetryCollectionId', 'MISSING')}")
            print(f"    poetryCollectionIds: {tf.get('poetryCollectionIds', 'MISSING')}")
            print(f"    includedInManuscript: {tf.get('includedInManuscript', 'MISSING')}")
        if len(files) > 5:
            print(f"  ... and {len(files) - 5} more files")
        break

print()
print("=== FOLDER STRUCTURE ===")
for folder in data['folders']:
    print(f"  Folder: '{folder.get('name')}'")
    for sub in folder.get('subfolders', []):
        sub_files = sub.get('textFiles', [])
        print(f"    Subfolder: '{sub.get('name')}' files={len(sub_files)}")
        for tf in sub_files[:3]:
            print(f"      File: '{tf.get('name')}' isCoverFile={tf.get('isCoverFile', False)}")
