# Feature Specification: OpenAI Integration

**Feature ID**: 015  
**Created**: 9 November 2025  
**Status**: Planning / Premium Feature  
**Priority**: Medium-High  
**Dependencies**: Pro subscription (Feature 014), Network access

---

## Overview

Integrate OpenAI's language models (GPT-4, etc.) to provide AI-powered writing assistance while maintaining user privacy and control.

---

## Goals

- Provide helpful AI writing assistance without replacing creativity
- Support multiple AI use cases (brainstorming, editing, feedback)
- Maintain user privacy (data not used for training)
- Control costs (limit free usage, Pro gets more)
- Clear disclosure of AI usage
- Optional feature (users can disable)
- Ethical AI usage guidelines

---

## Core Principles

### 1. **Assistance, Not Replacement**
AI suggests, user decides. Never auto-apply changes without explicit consent.

### 2. **Privacy First**
- User data sent to OpenAI only with permission
- Data not used to train OpenAI models
- Option to use local models in future
- Clear data handling disclosure

### 3. **Transparent Costs**
- Clear quota system
- Show costs/usage to Pro users
- Prevent surprise bills

### 4. **User Control**
- Can disable AI features entirely
- Granular control over what AI can access
- Review before applying suggestions

---

## AI Features

### 1. Brainstorming Assistant

**Use Case**: Generate ideas, prompts, story concepts

**Features**:
- Generate story ideas based on genre/themes
- Character name suggestions
- Plot twist ideas
- Dialogue suggestions
- Setting descriptions
- Title suggestions

**UI Example**:
```
┌─────────────────────────────────────┐
│ 💡 Brainstorm Ideas                 │
├─────────────────────────────────────┤
│ I need ideas for:                   │
│ [sci-fi short story about AI ]      │
│                                     │
│ [Generate Ideas]                    │
│                                     │
│ Generated Ideas:                    │
│ • AI therapist develops empathy     │
│ • Sentient spaceship befriends crew │
│ • AI poet struggles with emotion    │
│                                     │
│ [Use This]  [More Ideas]  [Refine]  │
└─────────────────────────────────────┘
```

### 2. Writing Coach / Feedback

**Use Case**: Get constructive feedback on writing

**Features**:
- Analyze story structure
- Identify pacing issues
- Highlight weak dialogue
- Suggest improvements to prose
- Check for consistency errors
- Evaluate character development

**Analysis Types**:
- **Quick check**: Basic grammar and flow
- **Deep analysis**: Structure, character arcs, themes
- **Style analysis**: Voice, tone, readability

**UI Example**:
```
┌─────────────────────────────────────┐
│ 📝 Writing Feedback                 │
├─────────────────────────────────────┤
│ Select text or analyze entire file  │
│                                     │
│ Analysis Type:                      │
│ ⦿ Quick Check                       │
│ ○ Deep Analysis                     │
│ ○ Style Analysis                    │
│                                     │
│ Focus on:                           │
│ ☑ Pacing                            │
│ ☑ Character Development             │
│ ☑ Dialogue                          │
│ ☐ Plot Structure                    │
│                                     │
│ [Analyze]                           │
│                                     │
│ Results:                            │
│ ✓ Strong opening hook               │
│ ⚠️ Middle section drags             │
│ ⚠️ Character motivation unclear     │
│ ✓ Satisfying ending                 │
│                                     │
│ [View Details]  [Apply Suggestions] │
└─────────────────────────────────────┘
```

### 3. Text Improvement Suggestions

**Use Case**: Refine specific passages

**Features**:
- Rewrite for clarity
- Make more concise
- Expand description
- Change tone (formal, casual, dramatic)
- Strengthen word choice
- Fix awkward phrasing

**Workflow**:
1. User selects text
2. Chooses improvement type
3. AI generates alternatives
4. User reviews and chooses (or rejects)

**UI Example**:
```
┌─────────────────────────────────────┐
│ ✨ Improve Text                     │
├─────────────────────────────────────┤
│ Original:                           │
│ "He walked into the room and        │
│ looked around."                     │
│                                     │
│ Improvements:                       │
│                                     │
│ ⦿ More descriptive:                 │
│   "He stepped cautiously into the   │
│   dimly lit room, his eyes scanning │
│   the shadows."                     │
│                                     │
│ ○ More concise:                     │
│   "He entered and surveyed the      │
│   room."                            │
│                                     │
│ ○ More dramatic:                    │
│   "He burst through the doorway,    │
│   eyes wild as he searched the      │
│   darkened room."                   │
│                                     │
│ [Use This]  [Keep Original]  [Retry]│
└─────────────────────────────────────┘
```

### 4. Character Development Helper

**Use Case**: Develop rich, consistent characters

**Features**:
- Generate character backstory from brief description
- Suggest character flaws/strengths
- Create character voice samples
- Identify character inconsistencies
- Generate character questionnaire answers

**Integration**: Works with Character Database (Feature 010)

**Example**:
```
┌─────────────────────────────────────┐
│ 🎭 Character Development            │
├─────────────────────────────────────┤
│ Character: Sarah Chen               │
│                                     │
│ Brief description:                  │
│ [28-year-old software engineer,     │
│  ambitious, struggles with work-    │
│  life balance]                      │
│                                     │
│ [Generate Backstory]                │
│                                     │
│ AI-Generated Backstory:             │
│ Sarah grew up in Silicon Valley...  │
│ [Full backstory text]               │
│                                     │
│ Suggested Traits:                   │
│ • Perfectionist                     │
│ • Fear of failure                   │
│ • Loyal to friends                  │
│                                     │
│ [Add to Character Profile]          │
└─────────────────────────────────────┘
```

### 5. Dialogue Polish

**Use Case**: Make dialogue more natural and distinct

**Features**:
- Make dialogue sound more natural
- Add distinct voice per character
- Suggest subtext
- Improve pacing of conversation
- Add action beats

**Example**:
```
Original dialogue:
"I don't want to go."
"Why not?"
"Because I'm tired."

AI suggestions:
• More natural:
  "I'm not going."
  "Come on, why not?"
  "Because I'm exhausted, okay?"

• With subtext:
  "I'd rather stay here."
  "Is this about yesterday?"
  [Beat] "Maybe."

• With action beats:
  She turned away. "I don't want to go."
  He grabbed his coat. "Why not?"
  She sighed. "Because I'm tired. Of all of this."
```

### 6. Grammar & Style Checking

**Use Case**: Catch errors AI is good at finding

**Features**:
- Grammar corrections
- Spelling (beyond spell check)
- Punctuation suggestions
- Consistency checking (tense, POV)
- Style guide compliance

**Note**: Supplements built-in spell check, not replacement

### 7. Plot Hole Detector

**Use Case**: Find logical inconsistencies

**Features**:
- Analyze entire manuscript for plot holes
- Check character knowledge consistency
- Timeline contradiction detection
- Object permanence (character has item they shouldn't have)
- Cause-effect logical flow

**Example Report**:
```
Plot Analysis Results:

✓ Timeline: No contradictions found
⚠️ Character Knowledge:
  - Ch 5: Sarah knows about the secret, but wasn't told until Ch 7
⚠️ Object Tracking:
  - Ch 3: Marcus has the key
  - Ch 6: Marcus still has the key but Sarah used it
✓ Cause-Effect: Logical progression maintained
```

### 8. Genre-Specific Tools

**Poetry**:
- Rhyme suggestions
- Meter analysis
- Metaphor suggestions

**Screenwriting**:
- Scene description improvement
- Dialogue polish
- Action line clarity

**Novel**:
- Chapter summary generation
- Pacing analysis
- Theme consistency

---

## Technical Implementation

### API Integration

```swift
import Foundation

class OpenAIService {
    private let apiKey: String
    private let baseURL = "https://api.openai.com/v1"
    
    // Initialize with API key (stored securely)
    init(apiKey: String) {
        self.apiKey = apiKey
    }
    
    // Generate text completion
    func complete(
        prompt: String,
        maxTokens: Int = 500,
        temperature: Double = 0.7
    ) async throws -> String {
        let endpoint = "\(baseURL)/chat/completions"
        
        let body: [String: Any] = [
            "model": "gpt-4",
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": prompt]
            ],
            "max_tokens": maxTokens,
            "temperature": temperature
        ]
        
        var request = URLRequest(url: URL(string: endpoint)!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw OpenAIError.requestFailed
        }
        
        let result = try JSONDecoder().decode(OpenAIResponse.self, from: data)
        return result.choices.first?.message.content ?? ""
    }
    
    // System prompt for writing assistant
    private var systemPrompt: String {
        """
        You are a helpful writing assistant for creative writers.
        Provide constructive, encouraging feedback.
        Focus on improvement suggestions, not criticism.
        Respect the writer's voice and creative choices.
        """
    }
}

struct OpenAIResponse: Codable {
    let choices: [Choice]
    
    struct Choice: Codable {
        let message: Message
    }
    
    struct Message: Codable {
        let content: String
    }
}

enum OpenAIError: Error {
    case requestFailed
    case invalidResponse
    case quotaExceeded
}
```

### Prompt Engineering

**Brainstorming Prompt**:
```
Generate 5 story ideas for a {genre} {format} about {theme}.
Each idea should be 1-2 sentences.
Make them unique and interesting.
```

**Feedback Prompt**:
```
Analyze this {format} excerpt for:
- Pacing
- Character development
- Dialogue quality
- Plot structure

Provide 3-5 specific, actionable suggestions for improvement.

Text:
{user_text}
```

**Improvement Prompt**:
```
Rewrite this passage to be more {style_goal}.
Maintain the original meaning and author's voice.
Provide 3 different versions.

Original:
{user_text}
```

---

## Usage Limits & Quotas

### Free Tier
- **0 AI requests** - Not available in free tier
- Prompts user to try Pro

### Pro Tier
- **100 AI requests/month** included
- ~20 brainstorming sessions
- ~30 text improvements
- ~10 deep analyses

### Usage Tracking

```swift
@Model
class AIUsage {
    var id: UUID
    var user: String          // User ID
    var month: Date           // Month of usage
    var requestCount: Int     // Number of requests
    var tokensUsed: Int       // Total tokens consumed
    var lastReset: Date       // When quota resets
}

class AIQuotaManager {
    func canMakeRequest(user: String) async -> Bool {
        let usage = await getUsageForCurrentMonth(user: user)
        let limit = user.isPro ? 100 : 0
        return usage.requestCount < limit
    }
    
    func incrementUsage(user: String, tokens: Int) async {
        let usage = await getUsageForCurrentMonth(user: user)
        usage.requestCount += 1
        usage.tokensUsed += tokens
        await save(usage)
    }
}
```

### Quota UI

```
┌─────────────────────────────────────┐
│ AI Usage This Month                 │
├─────────────────────────────────────┤
│ ━━━━━━━━━━━━━━━━━━━━ 47 / 100      │
│                                     │
│ Requests remaining: 53              │
│ Resets: Dec 1, 2025                 │
│                                     │
│ [View Usage History]                │
└─────────────────────────────────────┘
```

### Quota Exceeded

```
┌─────────────────────────────────────┐
│ AI Quota Reached                    │
├─────────────────────────────────────┤
│ You've used all 100 AI requests     │
│ for this month.                     │
│                                     │
│ Your quota resets Dec 1, 2025.      │
│                                     │
│ Need more? Contact us to discuss    │
│ increased limits.                   │
│                                     │
│ [OK]                                │
└─────────────────────────────────────┘
```

---

## Privacy & Data Handling

### Data Sent to OpenAI

**What is sent**:
- Selected text or file content (only when explicitly requested)
- Genre/format metadata
- Improvement goals (e.g., "make more concise")

**What is NOT sent**:
- Entire project database
- User personal information
- Files user hasn't explicitly analyzed

### User Consent

**First-time use**:
```
┌─────────────────────────────────────┐
│ Enable AI Features                  │
├─────────────────────────────────────┤
│ AI features use OpenAI's GPT models │
│ to provide writing assistance.      │
│                                     │
│ How it works:                       │
│ • Text is sent to OpenAI securely   │
│ • OpenAI does NOT use your data to  │
│   train their models                │
│ • You control what text is analyzed │
│ • You can disable this anytime      │
│                                     │
│ [Learn More]  [No Thanks]  [Enable] │
└─────────────────────────────────────┘
```

### Settings

```
┌─────────────────────────────────────┐
│ AI Settings                         │
├─────────────────────────────────────┤
│ ☑ Enable AI features                │
│                                     │
│ Data sent to OpenAI:                │
│ ⦿ Only selected text                │
│ ○ Full files when analyzing         │
│                                     │
│ AI Model:                           │
│ ⦿ GPT-4 (best quality)              │
│ ○ GPT-3.5 (faster, cheaper)         │
│                                     │
│ [View Privacy Policy]               │
│ [View OpenAI Terms]                 │
└─────────────────────────────────────┘
```

---

## Cost Management

### Server-Side API Key

**Approach**: App uses server-side API key, not user's own key

**Pros**:
- User doesn't need OpenAI account
- Centralized cost control
- Quota management easier
- Better security

**Cons**:
- Developer pays OpenAI costs
- Must limit usage to control costs

### Cost Estimation

**OpenAI Pricing** (as of 2025):
- GPT-4: ~$0.03 per 1K input tokens, ~$0.06 per 1K output tokens
- GPT-3.5: ~$0.001 per 1K tokens (cheaper)

**Estimated Costs**:
- Average request: ~500 tokens = $0.025 (GPT-4)
- 100 requests/user/month = $2.50/user
- Pro subscription: $4.99/month
- Margin: ~$2.50/user (50%)

**Cost Control**:
- Strict quota limits
- Use GPT-3.5 for simple tasks
- Cache common requests
- Monitor usage patterns

### Alternative: User-Provided API Key

**Option**: Let power users provide their own OpenAI API key

**Pros**:
- No cost to developer
- Unlimited usage for user
- User has full control

**Cons**:
- Extra setup complexity
- Most users won't do it
- Support burden

**Implementation**: Optional advanced setting

---

## Ethical Considerations

### Plagiarism Prevention

**Guidelines**:
- AI is for assistance, not ghostwriting
- User must edit and make AI output their own
- Disclosure when submitting to publications
- Educational messaging about ethical AI use

**In-App Messaging**:
```
Writing with AI
Writing Shed Pro's AI features are designed to
assist, not replace, your creativity. Always:
• Review and edit AI suggestions
• Make the writing your own
• Disclose AI use when required by publications
• Use AI ethically and responsibly
```

### Transparency

- Clear labeling of AI-generated content
- Option to see prompts sent to AI
- Explain AI limitations
- Encourage critical evaluation of suggestions

---

## Testing

### Test Scenarios

**Functional**:
- Generate ideas successfully
- Analyze text for feedback
- Improve selected text
- Handle quota limits
- Handle API errors
- Offline behavior

**Quality**:
- AI suggestions are relevant
- Feedback is constructive
- Improvements maintain voice
- No inappropriate content

**Performance**:
- Request latency < 5 seconds
- No UI blocking
- Graceful timeout handling

**Privacy**:
- Data sent only with permission
- API key stored securely
- No data leakage

---

## Implementation Phases

### Phase 1: Core Infrastructure
- OpenAI API integration
- Quota management system
- Basic UI for AI features
- Privacy consent flow

### Phase 2: Writing Tools
- Text improvement suggestions
- Grammar/style checking
- Simple brainstorming

### Phase 3: Advanced Features
- Deep manuscript analysis
- Character development helper
- Plot hole detection

### Phase 4: Optimization
- Caching for common requests
- Cost optimization (GPT-3.5 for simple tasks)
- A/B test prompt variations
- Usage analytics

---

## Open Questions

1. **API Key**: Server-side vs. user-provided?
2. **Quota**: Is 100 requests/month enough?
3. **Model choice**: GPT-4 always, or GPT-3.5 for some tasks?
4. **Offline**: Cache responses for offline access?
5. **Multi-language**: Support non-English?
6. **Custom models**: Eventually train custom model on writing?
7. **Local models**: Use on-device models (Apple Intelligence) in future?

---

## Dependencies

- **Feature 014**: Pro subscription required
- **Network access**: Internet required (no offline)
- **OpenAI account**: Developer needs OpenAI API access
- **Secure storage**: For API keys

---

## Success Metrics

- **Adoption**: > 50% of Pro users try AI features
- **Engagement**: Average 10-20 AI requests/active user/month
- **Satisfaction**: 4+ star rating for AI features
- **Retention**: AI users renew subscription at higher rate
- **Cost**: Stay under $2.50/user/month
- **Quota**: < 10% of users hit quota limit

---

## Related Resources

- OpenAI API Documentation: https://platform.openai.com/docs
- OpenAI Usage Policies: https://openai.com/policies/usage-policies
- Prompt engineering guides
- AI ethics in creative writing

---

**Status**: 📋 Specification Draft - Premium Feature  
**Next Steps**: Obtain OpenAI API access, prototype brainstorming feature, test prompt quality  
**Estimated Effort**: Large (6-8 weeks for full feature set)  
**Risk**: Medium (API costs, quality of AI output, ethical concerns)
