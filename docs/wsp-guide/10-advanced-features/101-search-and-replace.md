# Search and Replace

Writing Shed Pro provides powerful search and replace functionality. Find text in a single file, across a collection, or throughout your entire project.

## Search Scope

### Single File
Search within the currently open file.

### Collection
Search all files in a specific collection.

### Entire Project
Search all files in your project.

## Basic Search

### Opening Search
- **Keyboard**: ⌘F (Mac/iPad with keyboard)
- **Toolbar**: Tap the search icon
- **Menu**: Edit → Find

### Finding Text
1. Open search
2. Type your search term
3. Matches highlight in the document
4. Use arrows to navigate between matches

### Match Navigation
- **Next match**: ⌘G or tap the down arrow
- **Previous match**: ⌘⇧G or tap the up arrow
- Match counter shows "3 of 12" style progress

## Search Options

### Case Sensitive
- Off (default): "Hello" matches "hello", "HELLO", etc.
- On: Only exact case matches

### Whole Word
- Off (default): "the" matches "the", "there", "other"
- On: "the" only matches "the" as a complete word

### Regular Expressions
- Off (default): Search terms are literal
- On: Use regex patterns for complex searches

Toggle these options in the search bar.

## Replace

### Opening Replace
- **Keyboard**: ⌘⌥F (Mac/iPad with keyboard)
- Expand the search bar to show replace field

### Replacing Text
1. Enter search term
2. Enter replacement text
3. Navigate to a match
4. Click **Replace** to replace current match
5. Or click **Replace All** to replace all matches

### Replace Options
- **Replace**: Replace current match only
- **Replace All**: Replace all matches in scope
- **Replace All confirmation**: Shows count before replacing

## Project-Wide Search

### Opening Project Search
1. From project view, access Search
2. Or use keyboard shortcut
3. Search bar expands to show scope options

### Setting Scope
Choose from:
- **Current File**: Just this file
- **Collection**: Select which collection
- **Project**: Entire project

### Viewing Results
Project search shows:
- Results grouped by file
- Context around each match
- Match count per file
- Total match count

### Navigating Results
- Tap a result to open that file
- The match is highlighted and scrolled into view
- Continue searching or editing

## Project-Wide Replace

### How It Works
1. Enter search and replace terms
2. Set scope to Collection or Project
3. Click **Find All** to see matches
4. Review matches (select/deselect files)
5. Click **Replace All in Selected**
6. Confirm the replacement

### Safety Features
- Preview before replacing
- File-by-file selection
- Confirmation with count
- Undo support

## Regular Expressions

For power users, regex enables complex patterns:

### Basic Patterns
| Pattern | Matches |
|---------|---------|
| `.` | Any single character |
| `*` | Zero or more of previous |
| `+` | One or more of previous |
| `?` | Zero or one of previous |
| `^` | Start of line |
| `$` | End of line |
| `\d` | Any digit |
| `\w` | Any word character |
| `\s` | Any whitespace |

### Examples
| Find | Purpose |
|------|---------|
| `\bthe\b` | "the" as whole word |
| `\d{3}-\d{4}` | Phone number pattern |
| `^#.*` | Lines starting with # |
| `\s+` | Multiple spaces |

### Capture Groups
Use parentheses to capture and reuse:
- Find: `(\w+)@(\w+)\.com`
- Replace: `$1 at $2 dot com`
- Result: "user@example.com" → "user at example dot com"

## Search Tips

### Start Broad
Begin with simple searches, then add constraints if needed.

### Check Options
Wrong case sensitivity or whole-word setting can cause missed matches.

### Preview Results
For replace, always review what will change before confirming.

### Use Undo
If a replace goes wrong, Undo immediately.

### Break Up Large Replaces
For complex changes, consider replacing in steps rather than one massive operation.

## Common Use Cases

### Changing a Character Name
1. Search for "John" (whole word)
2. Replace with "James"
3. Replace all in project

### Fixing Repeated Errors
1. Search for "teh" (case insensitive)
2. Replace with "the"
3. Replace all

### Finding Specific Phrases
1. Search for exact phrase
2. Navigate through occurrences
3. Edit as needed

### Updating Terminology
1. Search across project
2. Review each instance
3. Replace appropriately (some may need context-specific changes)

## Troubleshooting

### No Matches Found
- Check spelling
- Check case sensitivity setting
- Check whole word setting
- Broaden your search

### Too Many Matches
- Use more specific search terms
- Enable whole word
- Use regex for precision

### Wrong Things Replaced
- Undo immediately
- Be more specific next time
- Use Find/Replace one at a time for sensitive changes

## See Also
- [The Editor](../4-writing/41-the-editor.md)
- [Keyboard Shortcuts](../11-reference/111-keyboard-shortcut-list.md)

---
