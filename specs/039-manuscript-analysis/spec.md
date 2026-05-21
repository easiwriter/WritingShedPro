# Manuscript Analysis Specification

**Status**: Specification  
**Date**: 2026-05-20  
**Module**: Subscription Service  
**Backend**: CloudFlare Workers API

---

## 1. Overview

**Manuscript Analyst** is a subscription-gated AI-powered review service that provides critical feedback and improvement suggestions for WritingShedPro content. The service analyzes selected text files or entire manuscripts and delivers editorial insights without generating new text.

The analysis must be **project-type aware**. Poetry, prose, fiction, drama, short fiction, and verse novels should not be reviewed with the same assumptions or the same weighting of feedback categories.

### Purpose

- Enable writers to receive structured, professional-level editorial feedback.
- Identify areas for improvement using the appropriate lens for the work type: poetry, prose, fiction, drama, or hybrid forms such as verse novels.
- Provide actionable suggestions the writer implements manually.
- Leverage CloudFlare Workers for text analysis and AI prompt execution.

### Scope

- **In Scope**: Review/analysis, feedback generation, suggestion lists, per-file or manuscript-wide analysis, project-type-specific review profiles.
- **Out of Scope**: Text generation/rewriting, auto-correction, publishing assistance, proofreading.

---

## 2. Key Features

### 2.1 Analysis Modes

#### Per-File Review

- User selects a single `TextFile` such as a chapter, scene, poem, essay section, or script scene.
- AI analyzes content using the review profile appropriate to the parent project type.
- Returns feedback categorized by type, such as pacing and character consistency for fiction, or imagery and lineation for poetry.

#### Manuscript-Wide Review

- User selects an entire Project or Manuscript.
- Service aggregates all body-section files such as chapters, episodes, scenes, poems, or prose sections.
- Provides cross-file feedback using project-type-specific criteria.
- Examples: continuity and character arcs for fiction and drama, thematic and tonal coherence for poetry collections, argument or through-line consistency for prose.
- May prioritize key files to fit CloudFlare token and execution limits.

### 2.2 Analysis Profiles by Project Type

The service must select a review profile automatically from the project type and, where relevant, the fiction class.

#### Poetry

- Primary focus: imagery, diction, lineation, rhythm or meter, stanza architecture, sonic texture, repetition or refrain, and emotional coherence.
- De-emphasize fiction-centric feedback such as plot holes or character arcs unless the poem explicitly contains narrative elements.
- Manuscript-wide poetry review should support both single long-form poems and collections.
- For collections, review ordering, tonal range, thematic recurrence, and whether individual poems feel redundant or underdeveloped in relation to the whole.

#### Prose

- Primary focus: clarity, structure, transitions, essay or memoir shape, paragraph development, voice consistency, exposition density, and argumentative or reflective coherence.
- Do not assume character arcs, scene construction, or dramatic conflict are the main evaluation criteria.
- Manuscript-wide prose review should consider sequencing of sections or essays, repeated ideas, conceptual gaps, and pacing of reflection or exposition.

#### Fiction and Short Fiction

- Primary focus: plot logic, character motivation, scene effectiveness, pacing, tension, continuity, stakes, voice, and point-of-view control.
- Short fiction should weight compression, economy, and payoff more heavily than long-form pacing diagnostics.

#### Drama

- Primary focus: scene dynamics, dramatic tension, dialogue effectiveness, stage clarity, act structure, character objectives, and escalation.
- Give less weight to prose-style exposition concerns and more weight to performative clarity and conflict on the page.

#### Verse Novel

- Treat as a hybrid profile, not simply poetry and not simply fiction.
- Evaluate both narrative movement and poetic craft: plot progression, character continuity, scene clarity, lineation, imagery, rhythm, and compression.
- Highlight when poetic choices strengthen the narrative and when they obscure narrative comprehension.

### 2.3 Feedback Categories

Feedback is returned in structured categories, with weighting determined by the selected analysis profile:

- **Clarity & Language**: Confusing passages, unclear pronoun references, repetitive phrasing.
- **Pacing & Structure**: Rushed sections, unnecessary digressions, weak transitions.
- **Character Development**: Inconsistent behavior, underdeveloped arcs, missing motivations.
- **Narrative Consistency**: Plot holes, timeline conflicts, factual contradictions.
- **Tone & Voice**: Jarring shifts, POV inconsistencies, style breaks.
- **Engagement**: Low-tension sections, exposition dumps, reader hooks.
- **Technical Issues**: Formatting, dialogue punctuation, perspective violations.

Additional categories should be available when the profile requires them:

- **Poetic Form & Lineation**: Line breaks, stanza shape, refrain handling, visual structure.
- **Rhythm, Meter & Sound**: Meter consistency, sonic texture, repetition, internal echo, rhyme effectiveness.
- **Imagery & Precision**: Freshness, concreteness, over-explanation, mixed metaphors, abstract drift.
- **Essay / Reflective Structure**: Through-line, argument development, reflection depth, logical progression.
- **Dramatic Function**: Scene objective, conflict escalation, speakability, stage or action clarity.

### 2.4 Suggestion Format

Each suggestion includes:

- **Category**: Type of feedback from the active profile.
- **Severity**: High / Medium / Low to help prioritize effort.
- **Location**: Chapter, scene, poem, section reference, or line range when available.
- **Observation**: What the AI detected, ideally with a concrete example or excerpt.
- **Suggestion**: What could be improved, expressed as direction rather than rewritten text.
- **Rationale**: Why this matters for the piece.

---

## 3. Architecture

### 3.1 System Components

```text
┌─────────────────────────────────────────┐
│   WritingShedPro (iOS/macOS/Catalyst)   │
│  ┌───────────────────────────────────┐  │
│  │   ManuscriptAnalystService        │  │
│  │  (local coordination & caching)   │  │
│  └───────────┬───────────────────────┘  │
│              │                           │
│  ┌───────────▼───────────────────────┐  │
│  │  Subscription entitlement module  │  │
│  │  (active subscription check)      │  │
│  └───────────┬───────────────────────┘  │
└──────────────┼──────────────────────────┘
               │ HTTPS
               ▼
┌──────────────────────────────────────────┐
│   CloudFlare Worker API                  │
│  /api/manuscript-analyst/review          │
│  ┌────────────────────────────────────┐  │
│  │ • Request parsing & validation     │  │
│  │ • Token counting & chunking        │  │
│  │ • AI prompt assembly               │  │
│  │ • Model invocation (e.g., Claude)  │  │
│  │ • Response parsing & formatting    │  │
│  └────────────────────────────────────┘  │
│  ┌────────────────────────────────────┐  │
│  │ • Rate limiting & quotas           │  │
│  │ • Billing integration              │  │
│  │ • Logging & diagnostics            │  │
│  └────────────────────────────────────┘  │
└──────────────────────────────────────────┘
```

### 3.2 Local Service (`ManuscriptAnalystService`)

**Location**: `WrtingShedPro/Writing Shed Pro/Services/ManuscriptAnalystService.swift`

**Responsibilities**:

- Assemble file content, respecting any privacy or sensitivity flags added later.
- Infer the correct analysis profile from `Project.type` and `Project.fictionClass`.
- Validate active subscription status before sending to backend.
- Call the CloudFlare endpoint with the request payload.
- Handle response parsing and error recovery.
- Cache results locally per file or manuscript and invalidate on content modification.
- Present feedback to the user through `AnalystReviewView` or related UI.

**Key Methods**:

```swift
func reviewFile(_ textFile: TextFile) async throws -> ManuscriptReview
func reviewManuscript(_ project: Project) async throws -> ManuscriptReview
func clearReviewCache(for textFile: TextFile)
func clearReviewCache(for project: Project)
```

### 3.3 CloudFlare Endpoint

**Endpoint**: `POST /api/manuscript-analyst/review`

**Request Payload**:

```json
{
  "analysisMode": "file" | "manuscript",
  "projectType": "fiction" | "poetry" | "drama" | "prose",
  "fictionClass": "novel" | "shortFiction" | "verseNovel" | null,
  "analysisProfile": "poetry" | "prose" | "fiction" | "shortFiction" | "drama" | "verseNovel",
  "subscriptionTier": "analyst.monthly.5_99",
  "content": "full text content",
  "metadata": {
    "fileName": "Chapter 1",
    "fileCount": 1,
    "wordCount": 5000,
    "documentationVersion": "2.0"
  },
  "options": {
    "focusAreas": ["character", "pacing"],
    "severity": "all" | "high" | "medium_high"
  }
}
```

**Response Payload**:

```json
{
  "status": "success",
  "timestamp": "2026-05-20T14:30:00Z",
  "reviewId": "rev_abc123xyz",
  "analysis": {
    "summary": "Brief overview of key issues",
    "overallSentiment": "encouraging" | "mixed" | "critical",
    "analysisProfile": "verseNovel",
    "suggestedFocusOrder": ["narrative clarity", "lineation", "character"]
  },
  "suggestions": [
    {
      "id": "sug_001",
      "category": "Poetic Form & Lineation",
      "severity": "high",
      "location": "Poem 4, stanza 2",
      "observation": "The line breaks currently work against the sentence rhythm, so the emphasis lands on connective words rather than image-bearing words.",
      "suggestion": "Consider revising the lineation so the breaks land on stronger image or sound units, or let the sentence run more naturally before the break.",
      "rationale": "In poetry, line breaks shape emphasis and pacing. When the break point conflicts with the intended stress or image, the poem can feel less controlled."
    }
  ],
  "metadata": {
    "contentAnalyzed": 5000,
    "tokensUsed": 8500,
    "analysisTimeMs": 2400,
    "model": "claude-3-5-sonnet",
    "softCapState": "normal" | "approaching_limit" | "throttled"
  }
}
```

---

## 4. Data Models

### 4.1 Local Models (Swift)

```swift
@Model
final class ManuscriptReview {
    @Attribute(.unique) var reviewId: String
    var timestamp: Date
    var fileId: UUID?  // Null if manuscript-wide review
    var projectId: UUID
    var analysisMode: String  // "file" | "manuscript"

    var summary: String
    var overallSentiment: String  // "encouraging", "mixed", "critical"
    var suggestedFocusOrder: [String]?

    @Relationship(deleteRule: .cascade) var suggestions: [ReviewSuggestion] = []

    var metadata: ReviewMetadata?
}

@Model
final class ReviewSuggestion {
    var suggestionId: String
    var category: String
    var severity: String  // "high", "medium", "low"
    var location: String?
    var observation: String
    var suggestion: String
    var rationale: String
    var isAddressed: Bool = false
    var userNotes: String?
}

struct ReviewMetadata: Codable {
    let contentAnalyzed: Int
    let tokensUsed: Int
    let analysisTimeMs: Int
    let model: String
}
```

---

## 5. User Experience

### 5.1 Review UI Integration

**Entry Point**: Context menu or dedicated "Analyze" button on file detail view.

- "Review This File" shows a loading spinner and presents `AnalystReviewView`.
- "Review Entire Manuscript" performs multi-file assembly and then presents a summary view.
- The UI should explicitly display the active review profile, such as "Poetry Review", "Prose Review", or "Verse Novel Review".

**Review Presentation**:

- Summary card with overall sentiment, key focus areas, and word count analyzed.
- Grouped suggestion list by category using collapsible sections.
- Per-suggestion display: category badge, severity indicator, location, observation, suggestion, rationale.
- "Mark as Addressed" checkbox so the writer can track progress.
- "Save Review" option to export as text or PDF in a later phase.
- Category labels and explanatory copy should adapt to the selected profile so poetry users are not shown fiction-biased framing.

### 5.2 Subscription Gating

- Show an "Unlock Manuscript Analyst" call to action if the user does not have an active subscription.
- Use StoreKit 2 subscription entitlements before sending the request.
- Show a graceful error if the subscription is expired, revoked, in billing retry, or otherwise inactive.
- Clearly explain that Manuscript Analyst is an ongoing cloud-backed service billed as a subscription because each analysis incurs provider cost.
- Show renewal and manage-subscription paths in the paywall and settings UI.

---

## 6. Technical Constraints & Considerations

### 6.1 Token/Cost Limits

- **Per Request**: CloudFlare timeout around 30 seconds, with typical analysis in 5 to 15 seconds.
- **Content Ceiling**: Limit manuscript input to roughly 50K tokens or 15K to 20K words to stay within response time and token budget.
- **Chunking Strategy**: If manuscript input exceeds the ceiling, prioritize content differently by profile.
- Fiction / drama: first, turning-point, climax, and ending scenes.
- Poetry collections: a representative spread across opening, middle, and closing poems, plus any title poem or sequence-defining poems.
- Prose: opening, representative middle sections, and closing sections that establish the argument or reflective arc.

### 6.1.1 Subscription Model

- **Commercial Model**: Subscription only, not a non-consumable one-time purchase.
- **Rationale**: Each analysis request creates ongoing provider fees, so revenue must scale with usage over time.
- **Launch Price**: `$5.99/month` as the initial public pricing assumption.
- **Initial Offering**: Launch with a single monthly subscription product first.
- **Annual Plan**: Defer annual pricing until post-launch usage and provider-cost data confirm the margin profile.
- **Entitlement Rule**: An active subscription unlocks both per-file and manuscript-wide analysis, subject to soft-cap management and abuse controls.

### 6.1.2 Soft Caps and Usage Management

Soft caps are usage thresholds designed to control extreme cost without making the service feel like a rigid credit meter.

- **Soft Cap Principle**: The user is subscribing to access, not buying a fixed pack of credits, but the system may slow, defer, or temporarily limit unusually high usage.
- **Primary Meter**: Track monthly token consumption and review count per subscriber.
- **Normal State**: User is below the soft-cap threshold and receives full-speed access.
- **Approaching Limit State**: Show a lightweight warning that heavy usage may be slowed later in the billing period.
- **Throttled State**: Apply temporary cooldowns, lower concurrency, or manuscript-review deferral when usage exceeds the soft cap.
- **Hard Stop Avoidance**: Prefer cooldowns and manuscript-size restrictions over an abrupt "no more reviews this month" block unless abuse or extreme cost exposure requires it.
- **Reset Window**: Usage counters reset each billing period.
- **Server Enforcement**: Soft-cap state must be computed server-side, not trusted from the client.
- **Client UX**: The app should surface the current state clearly, for example "Heavy usage detected. Manuscript reviews may be delayed until tomorrow".
- **Escalation Path**: If soft-cap throttling proves too restrictive for legitimate users, introduce a higher subscription tier rather than weakening cost controls silently.

### 6.2 Privacy & Data Handling

- Content sent to CloudFlare is **not stored** in WritingShedPro servers, only processed by CloudFlare subject to worker log retention policy.
- Do not persist user content in logs. Only retain request metadata such as success/failure, tokens used, and timestamp.
- User retains full ownership and control of all feedback.
- Show an opt-in privacy notice in the IAP description and before the first review request.

### 6.3 Fallback & Error Handling

- **Network Offline**: Queue review request locally and retry on reconnect if background support allows it.
- **CloudFlare Error**: Surface a specific error such as timeout, rate limit, or API failure, with a retry action.
- **Invalid Content**: Reject empty files or files under 100 words with a user-facing message.
- **Subscription Inactive**: Show a renewal or resubscribe prompt if entitlement is no longer valid.
- **Soft-Cap Throttled**: Show a specific message that the subscription remains active, but heavy usage has temporarily slowed access.

### 6.4 Caching & Rate Limiting

- Cache review per `TextFile` and invalidate on file modification.
- Cache per Manuscript and invalidate if any constituent file changes.
- Apply a local rate limit such as no more than one review per file per hour, while still allowing a user-forced refresh if desired.
- Apply a server-side rate limit to be defined by product and billing model.

---

## 7. Implementation Roadmap

### Phase 1: MVP

- [ ] Define the initial Manuscript Analyst subscription product at `$5.99/month`.
- [ ] Implement `ManuscriptAnalystService` for local coordination.
- [ ] Build the CloudFlare endpoint at `/api/manuscript-analyst/review`.
- [ ] Create `AnalystReviewView` to display suggestions.
- [ ] Integrate StoreKit 2 subscription entitlement validation.
- [ ] Add per-file review UI entry point.
- [ ] Implement profile-specific prompt templates for poetry, prose, fiction, drama, and verse novel review.
- [ ] Implement server-side usage tracking and soft-cap state calculation.

### Phase 2: Enhancement

- [ ] Add manuscript-wide review mode.
- [ ] Add adjustable focus areas so users can prioritize selected categories.
- [ ] Add review history or comparison so users can track changes.
- [ ] Export review to text or PDF.
- [ ] Tune soft-cap thresholds from real provider-cost data.
- [ ] Evaluate whether annual pricing is viable after observing subscriber usage and provider cost trends.
- [ ] Add collection-aware poetry review and sequencing feedback.
- [ ] Add prose-specific modes for essay, memoir, or creative nonfiction if needed.
- [ ] Add manage-subscription and usage-status UI in settings.

### Phase 3: Future

- [ ] Add more granular analysis profiles for specific writing modes.
- [ ] Add inline suggestions within the editor as an optional highlight or comment layer.
- [ ] Add batch processing so reviews can complete in the background.
- [ ] Add advanced diagnostics such as readability score, pacing chart, or character consistency graph.

---

## 8. Success Metrics

- **Adoption**: Percentage of eligible users using Analyst at least once per month.
- **Engagement**: Average reviews per user and average suggestions marked as addressed.
- **Satisfaction**: User rating of Analyst feedback in-app on a 1 to 5 scale.
- **Performance**: Average review latency under 15 seconds and error rate under 2 percent.

---

## 9. Open Questions

1. **Subscription Packaging**: Keep as a standalone `$5.99/month` subscription, or later bundle into a broader premium tier?
2. **Batch Limits**: Maximum files per manuscript review and token budget per user per month?
3. **Customization**: Should users be able to specify focus areas such as "ignore pacing, focus on imagery"?
4. **History**: Should reviews be stored indefinitely or pruned after a retention period?
5. **Export**: Is review export a core feature or a later-phase enhancement?
6. **Privacy Notice**: Where in onboarding or UI should CloudFlare data handling be disclosed?
