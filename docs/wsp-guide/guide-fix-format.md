# Guide Fix Format

When amendments are needed to the user guide markdown files, changes are marked using HTML comments so they are invisible in rendered output but trackable in the source.

## Comment Format

### Removing Text

Wrap the text to be removed in a removal comment:

```markdown
<!-- Copilot remove
text to be removed
-->
```

### Adding Text

Insert an addition comment where the new text should appear:

```markdown
<!-- Copilot add
text to be added
-->
```

### Creating Text

Instructions about what to create

```markdown
<!-- Copilot create
Instructions for copilot
-->
```

### Rewriting Text

Instructions about how to rewrite followed by the text to be rewritten:

```markdown
<!-- Copilot rewrite
[Instructions for copilot]
Code to be rewritten
-->
```

## Processing

Once the amendments have been applied (text removed/added as marked), the HTML comments should be deleted so they don't accumulate in the source files.
