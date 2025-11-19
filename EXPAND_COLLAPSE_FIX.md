# Expand/Collapse All Button Fix

**Date:** November 18, 2025  
**Issue:** When collapsing all sections, then navigating back and returning, it remembered the last expanded section instead of defaulting to all expanded

## Problem

**Scenario:**
1. User opens folder with sections A, B, C (all expanded by default)
2. User manually collapses B (A and C remain expanded)
3. User clicks "Collapse All" button
4. User navigates back and returns to folder
5. **Bug**: Only section A is expanded (the last manually opened section)
6. **Expected**: All sections should be expanded (fresh start)

**Root Cause:**
- When "Collapse All" was clicked, it cleared `lastOpenedSection` variable
- But it didn't clear the UserDefaults saved preference
- On return, `loadLastOpenedSection()` found the saved preference and restored it
- Result: User saw their old preference instead of a clean slate

## Solution

When "Collapse All" is clicked:
1. Clear expanded sections ✅ (already worked)
2. Clear `lastOpenedSection` variable ✅ (already worked)  
3. **NEW**: Clear UserDefaults preference ✅ (fixed)

```swift
if allExpanded {
    // Collapse all
    expandedSections.removeAll()
    lastOpenedSection = nil
    // Clear saved preference so next visit defaults to expanded
    UserDefaults.standard.removeObject(forKey: storageKey)
}
```

When "Expand All" is clicked:
- Expand all sections ✅
- **Don't save preference** - let it default to expanded naturally next time

## Behavior After Fix

### Scenario 1: User manually opens/closes sections
- Opens A, closes B, opens C
- Last opened section (C) is saved
- Next visit: Section C is expanded (remembers preference) ✅

### Scenario 2: User clicks "Collapse All"
- All sections collapse
- Saved preference is **cleared**
- Next visit: **All sections expanded** (fresh start) ✅

### Scenario 3: User clicks "Expand All"  
- All sections expand
- **No preference saved**
- Next visit: **All sections expanded** (default behavior) ✅

### Scenario 4: First time visitor
- No saved preference exists
- Next visit: **All sections expanded** (default behavior) ✅

## Logic Summary

**Save preference when:**
- User manually taps a section header to expand it
- This indicates intentional focus on that section
- Preserves user's workflow on return

**Clear preference when:**
- User clicks "Collapse All" button
- This indicates they want a clean slate
- Next visit should default to all expanded

**Don't save preference when:**
- User clicks "Expand All" button
- User is a first-time visitor
- Let natural default (all expanded) take over

## Result

The expand/collapse behavior is now intuitive:
- **Manual section taps** = "Remember what I focused on"
- **Collapse All button** = "Start fresh next time"  
- **Expand All button** = "Show me everything, and start fresh next time"
- **First visit** = "Show me everything"

This provides the best balance between:
- Convenience (remembering focused sections)
- Predictability (collapse all = true reset)
- Discoverability (first-timers see everything)
