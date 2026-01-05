# CMU Pronouncing Dictionary Integration

## Summary

Integrated the Carnegie Mellon University (CMU) Pronouncing Dictionary for accurate phonetic rhyme detection in the poetry validator.

## What Was Added

### 1. CMUDictionary.swift
New service for loading and querying the CMU dictionary:
- **Location**: `WrtingShedPro/Writing Shed Pro/Services/CMUDictionary.swift`
- **Features**:
  - Lazy loading of ~135,000 word pronunciations
  - Thread-safe dictionary access
  - Phoneme-based rhyme detection
  - Support for multiple pronunciations per word
  - Near-rhyme detection for consonant cluster variations

### 2. cmudict.txt
The CMU Pronouncing Dictionary data file:
- **Location**: `WrtingShedPro/Writing Shed Pro/Resources/cmudict.txt`
- **Size**: ~3.5 MB
- **Format**: `WORD PHONEME1 PHONEME2 ...` using ARPAbet notation
- **Source**: https://github.com/cmusphinx/cmudict

### 3. Updated PoetryValidator.swift
Modified `wordsRhyme()` to use CMU dictionary with heuristic fallback:
- First tries CMU dictionary for accurate phonetic comparison
- Falls back to heuristic method if words not in dictionary
- Preserves all existing heuristic logic for edge cases

### 4. CMUDictionaryTests.swift
Test suite for the CMU integration:
- **Location**: `WrtingShedPro/WritingShedProTests/CMUDictionaryTests.swift`

## How It Works

### ARPAbet Phonemes
The CMU dictionary uses ARPAbet notation with stress markers:
- Vowels have stress levels: 0 (unstressed), 1 (primary), 2 (secondary)
- Example: `sounds S AW1 N D Z` (stressed AW vowel)

### Rhyme Detection Algorithm
1. Look up both words in the CMU dictionary
2. Extract rhyme endings from the last stressed vowel to end
3. Compare phoneme sequences (ignoring stress differences)
4. Allow near-rhymes with consonant cluster normalization:
   - `sounds` (AW1 N D Z) vs `downs` (AW1 N Z) → normalized to same ending

### Fallback Behavior
If a word isn't in the CMU dictionary:
- Falls back to the existing heuristic-based rhyme detection
- This handles proper nouns, made-up words, and technical terms

## Original Issue Fixed

The issue that prompted this change:
- "downs" and "sounds" were not being detected as rhymes
- CMU entries: `sounds S AW1 N D Z` vs `downs D AW1 N Z`
- The D consonant difference is normalized as a near-rhyme

## Xcode Setup Required

**IMPORTANT**: After pulling these changes, add `cmudict.txt` to the Xcode project:
1. In Xcode, right-click on the Resources folder
2. Select "Add Files to 'Writing Shed Pro'"
3. Select `cmudict.txt`
4. Ensure "Copy items if needed" is checked
5. Ensure target membership includes the app target

## Performance

- Dictionary loads lazily on first rhyme check
- ~135,000 entries load in <1 second on modern devices
- Dictionary size: ~3.5 MB (minimal impact on app bundle)
- Lookups are O(1) hash table operations
