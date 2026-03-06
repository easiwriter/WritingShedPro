#!/usr/bin/env python3
"""Check text file collection references in WSP."""
import json

with open('/Users/writingshedprod/Desktop/The Republic of Heaven.wsp', 'r') as f:
    data = json.load(f)

poems_folder = next((f for f in data['folders'] if f['name'] == 'Poems'), None)
if poems_folder:
    with_cid = []
    with_cids = []
    without = []
    
    for tf in poems_folder['textFiles']:
        cid = tf.get('poetryCollectionId')
        cids = tf.get('poetryCollectionIds')
        if cid or cids:
            print(f"  {tf['name']}: collectionId={cid}, collectionIds={cids}")
            if cid:
                with_cid.append(tf)
            if cids:
                with_cids.append(tf)
        else:
            without.append(tf)
    
    print(f"\nFiles with poetryCollectionId: {len(with_cid)}/{len(poems_folder['textFiles'])}")
    print(f"Files with poetryCollectionIds: {len(with_cids)}/{len(poems_folder['textFiles'])}")
    print(f"Files without any collection reference: {len(without)}")
    for tf in without[:5]:
        print(f"  - {tf['name']}")
