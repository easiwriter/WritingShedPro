# Feature 008: File Movement System (SPLIT)

**Original Feature**: Combined file movement and publication tracking  
**Status**: Split into two manageable features  
**Date Split**: 2025-11-07  

---

## ⚠️ This Feature Has Been Split

The original Feature 008 specification grew to 829 lines covering two distinct capabilities. For manageable implementation, it has been split into:

### ✅ [008a-file-movement](../008a-file-movement/) - Ready for Implementation
**Status**: Specification Complete + Implementation Plan  
**Effort**: 2.5 weeks (12 days)  
**Priority**: Implement First

**What it delivers:**
- Move files between source folders (Draft, Ready, Set Aside)
- Multi-file selection via Edit Mode
- Quick single-file actions via swipe gestures
- Smart Trash with Put Back functionality
- CloudKit sync across devices

**Start here:** [008a Implementation Plan](../008a-file-movement/plan.md)

---

### ⏸️ [008b-publication-system](../008b-publication-system/) - Deferred to Phase 2
**Status**: Specification Complete (awaiting 008a completion)  
**Effort**: 3-4 weeks  
**Priority**: Implement After 008a

**What it delivers:**
- Publication entities (magazines, competitions)
- Submission tracking with version references
- Status management (pending/accepted/rejected)
- Published folder (auto-populated with accepted work)
- Submission history

**Read more:** [008b Specification](../008b-publication-system/spec.md)

---

## Why the Split?

**Problem**: Implementing both capabilities together would take 5-6 weeks with high complexity and significant risk.

**Solution**: Phase-based approach reduces risk and delivers value incrementally:
1. **008a (2.5 weeks)**: Core file organization capability users need immediately
2. **008b (3-4 weeks)**: Professional publication tracking builds on 008a's foundation

**Benefits:**
- ✅ Reduced complexity per phase
- ✅ Earlier delivery of file movement
- ✅ 008b reuses 008a's FileListView and Edit Mode patterns
- ✅ Focused testing per feature
- ✅ Lower risk of integration issues

---

## What's in This Folder?

This folder retains the **original comprehensive specification** as historical reference:

- **[spec.md](./spec.md)** - Original 829-line specification showing full vision
- **[checklists/requirements.md](./checklists/requirements.md)** - Requirements validation
- **[spec-review-draft.md](./spec-review-draft.md)** - User review document

**Purpose:** Preserve design decisions, user requirements, and UX research.

**⚠️ Do Not Use for Implementation**: Use [008a](../008a-file-movement/) and [008b](../008b-publication-system/) specs instead.

---

## Feature Relationship

```
┌─────────────────────────────────────┐
│  008a: File Movement                │
│  (Implement Now - 2.5 weeks)        │
│                                     │
│  ✓ Move between folders             │
│  ✓ Edit Mode for multi-select       │
│  ✓ Trash with Put Back              │
│  ✓ FileListView component           │
└──────────────┬──────────────────────┘
               │ Foundation for
               ↓
┌─────────────────────────────────────┐
│  008b: Publication System           │
│  (Phase 2 - 3-4 weeks)              │
│                                     │
│  ✓ Reuses Edit Mode pattern         │
│  ✓ Reuses FileListView component    │
│  ✓ Adds Publication/Submission      │
│  ✓ Adds Published folder view       │
└─────────────────────────────────────┘
```

**Why This Order:**
- 008a creates reusable UI patterns (Edit Mode, FileListView)
- 008b leverages these patterns for submission workflows
- Users get immediate value from file organization
- Professional tracking layer added on solid foundation

---

## Original User Request

**Initial Request**: "Moving on I want to allow the user to move files from one place to another. Typically in a poetry project to move files into the Ready or SetAside folder."

**How Scope Evolved:**
1. Started as simple file movement between folders
2. User clarified need for professional publication tracking
3. Spec expanded to include Publication/Submission/SubmittedFile models
4. Recognized combined scope too large → Split decision

**Key Clarifications Provided:**
- **Copy vs Move**: Use reference model (files stay in source folders, tracked via metadata)
- **Published Folder**: Auto-populated computed view (not physical folder)
- **Put Back**: Default to Draft if original folder deleted
- **All Folder**: Removed from scope
- **Multi-Selection UX**: Edit Mode (primary) + Swipe Actions (secondary)

---

## Next Steps

### Immediate (Day 1)
1. **Read** [008a-file-movement/plan.md](../008a-file-movement/plan.md)
2. **Start** Phase 0: Research iOS edit mode patterns
3. **Create** research.md documenting findings

### Short Term (Weeks 1-3)
4. **Implement** Feature 008a following 7-phase plan
5. **Test** comprehensively (unit, integration, UI tests)
6. **Deploy** file movement capability

### Future (After 008a Complete)
7. **Create** 008b implementation plan
8. **Implement** publication tracking system
9. **Integrate** with 008a's FileListView component

---

## Resources

### Implementation Guides
- **[008a Specification](../008a-file-movement/spec.md)** - Complete requirements for file movement
- **[008a Implementation Plan](../008a-file-movement/plan.md)** - 7-phase development guide
- **[008a README](../008a-file-movement/README.md)** - Quick reference

### Future Phase
- **[008b Specification](../008b-publication-system/spec.md)** - Complete requirements for publications
- **[008b README](../008b-publication-system/README.md)** - Quick reference

### Historical Reference
- **[Original Comprehensive Spec](./spec.md)** - Full 829-line specification
- **[Requirements Checklist](./checklists/requirements.md)** - Validation document

---

**Current Status**: � **Ready to begin Feature 008a implementation**  
**Next Action**: Start [Phase 0: Research & Planning](../008a-file-movement/plan.md#phase-0-research--planning-day-1)
