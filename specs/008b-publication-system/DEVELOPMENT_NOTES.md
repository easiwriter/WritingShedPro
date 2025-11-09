# Development Notes - Feature 008b

**Date**: 9 November 2025  
**Branch**: 008-file-movement-system

---

## Build & Testing Notes

### iOS Version Requirements
⚠️ **IMPORTANT**: Always use **iOS 16** simulator or higher for testing
- Do NOT use iOS 15 simulators
- iOS 16 minimum ensures SwiftUI features work correctly
- EventKit APIs work properly on iOS 16+

### Testing Checklist
- [ ] Test on iOS 16.0 minimum
- [ ] Test on current iOS (iOS 17+)
- [ ] Test on iPad
- [ ] Test on Mac Catalyst

---

## Code Quality Requirements

### Localization
✅ **ALL user-facing strings MUST be localized**

```swift
// ❌ WRONG - Hard-coded string
Text("Publications")

// ✅ CORRECT - Localized string
Text("publications.title")

// ✅ CORRECT - Localized with comment
Text("publication.delete.confirm", 
     comment: "Confirmation message when deleting a publication")
```

**Where to apply**:
- All Text() views
- All Button labels
- All Alert messages
- All Error messages
- All placeholder text
- All accessibility labels

### Accessibility
✅ **ALL views MUST be accessible**

**Required for all interactive elements**:
```swift
Button("Delete") { }
    .accessibilityLabel(Text("accessibility.delete.publication"))
    .accessibilityHint(Text("accessibility.delete.publication.hint"))
```

**Required for custom views**:
```swift
.accessibilityElement(children: .combine)
.accessibilityLabel(Text("accessibility.publication.card"))
.accessibilityValue(Text("accessibility.deadline.approaching"))
```

**Required for images/icons**:
```swift
Image(systemName: "trash")
    .accessibilityLabel(Text("accessibility.icon.delete"))
```

**Where to apply**:
- All buttons and controls
- All custom interactive views
- All status indicators
- All icons (with descriptive labels)
- All gestures (with hints)

---

## Phase 2 Requirements

When implementing Publications UI, ensure:

### PublicationsListView
- [ ] All strings localized (titles, labels, empty states)
- [ ] VoiceOver navigation works
- [ ] Deadline status accessible (announces "approaching", "passed")
- [ ] Swipe actions have accessibility labels
- [ ] Empty state has accessibility description

### PublicationFormView
- [ ] Form field labels localized
- [ ] Validation errors localized
- [ ] All text fields have accessibility labels
- [ ] Date picker has accessibility label
- [ ] Type picker announces options clearly

### PublicationDetailView
- [ ] All section headers localized
- [ ] Statistics announced by VoiceOver
- [ ] Action buttons have labels and hints
- [ ] Submission list items accessible

---

## Localization Strategy

### File Structure
```
Resources/
  Localizations/
    en.lproj/
      Localizable.strings
      Localizable.stringsdict (for plurals)
```

### Key Naming Convention
Use dot notation for organization:
```
// Feature.Context.Element.Property
"publications.list.title"
"publications.form.deadline.label"
"publications.detail.stats.submissions"
"publications.empty.title"
"publications.empty.message"
```

### Plurals
Use stringsdict for plural forms:
```xml
<key>publications.count</key>
<dict>
    <key>NSStringLocalizedFormatKey</key>
    <string>%#@count@</string>
    <key>count</key>
    <dict>
        <key>NSStringFormatSpecTypeKey</key>
        <string>NSStringPluralRuleType</string>
        <key>NSStringFormatValueTypeKey</key>
        <string>d</string>
        <key>one</key>
        <string>1 publication</string>
        <key>other</key>
        <string>%d publications</string>
    </dict>
</dict>
```

---

## Accessibility Strategy

### VoiceOver Testing
For each view, test:
1. Can navigate to all elements
2. Elements announce correctly
3. Actions are clear
4. Status changes announced
5. Error states communicated

### Dynamic Type
- [ ] All text respects Dynamic Type
- [ ] Layout adapts to larger text sizes
- [ ] No text truncation at large sizes

### Color Contrast
- [ ] Status colors meet WCAG AA standards
- [ ] Text readable in light/dark mode
- [ ] Icons distinguishable without color

---

## Code Review Checklist

Before committing any Phase 2+ code:

### Localization
- [ ] No hard-coded user-facing strings
- [ ] All Text() uses localized keys
- [ ] All error messages localized
- [ ] Plurals handled with stringsdict

### Accessibility
- [ ] All buttons have .accessibilityLabel()
- [ ] Custom views have .accessibilityElement()
- [ ] Status indicators announce correctly
- [ ] Gestures have .accessibilityHint()
- [ ] Images have descriptive labels

### Testing
- [ ] Tested on iOS 16+ simulator
- [ ] Tested with VoiceOver enabled
- [ ] Tested with large text sizes
- [ ] Tested in dark mode

---

## Example: Proper Implementation

```swift
// ✅ CORRECT - Fully localized and accessible
struct PublicationRow: View {
    let publication: Publication
    
    var body: some View {
        HStack {
            Text(publication.type.icon)
                .accessibilityLabel(Text("accessibility.icon.\(publication.type.rawValue)"))
            
            VStack(alignment: .leading) {
                Text(publication.name)
                    .font(.headline)
                
                if let deadline = publication.deadline {
                    Text("publications.deadline.format \(deadline, format: .dateTime.month().day())")
                        .foregroundColor(deadlineColor)
                        .accessibilityLabel(Text("accessibility.deadline.label"))
                        .accessibilityValue(deadlineAccessibilityValue)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(publicationAccessibilityLabel)
    }
    
    private var deadlineColor: Color {
        publication.deadlineStatus == .approaching ? .orange : .primary
    }
    
    private var deadlineAccessibilityValue: Text {
        if publication.isDeadlinePassed {
            return Text("accessibility.deadline.passed")
        } else if publication.isDeadlineApproaching {
            return Text("accessibility.deadline.approaching")
        } else {
            return Text("accessibility.deadline.future")
        }
    }
    
    private var publicationAccessibilityLabel: Text {
        var components = [publication.name]
        components.append(publication.type.displayName)
        if let days = publication.daysUntilDeadline {
            components.append(String(localized: "accessibility.deadline.days \(days)"))
        }
        return Text(components.joined(separator: ", "))
    }
}
```

---

## Phase 2 TODO Additions

When starting Phase 2, create:
1. [ ] `Localizable.strings` with all Phase 2 strings
2. [ ] `Localizable.stringsdict` for plurals
3. [ ] Accessibility test plan
4. [ ] VoiceOver test scenarios

---

**Remember**: Every user-facing string and every interactive element MUST be:
1. ✅ Localized
2. ✅ Accessible
3. ✅ Tested on iOS 16+

**No exceptions!**
