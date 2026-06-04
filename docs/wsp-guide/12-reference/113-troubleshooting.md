# Troubleshooting

Solutions to common issues in Writing Shed Pro.

## Sync Issues

Writing Shed Pro keeps your projects in sync across all your devices using iCloud. Sync happens automatically in the background — you don't need to do anything to keep devices up to date. Most sync delays resolve on their own within a few minutes.

### How Sync Works

When you create or edit a project on one device, the changes are uploaded to iCloud. Your other devices download those changes when they are online and the app is running (or shortly after you open it). There is no manual sync button you need to press in normal use.

Because iCloud is a cloud service, sync speed depends on your internet connection, Apple's servers, and how much has changed. After a long period offline, a device may take several minutes to catch up.

### Projects or Changes Not Appearing on Another Device

**Before troubleshooting**: Wait at least 5–10 minutes with the app open and a good Wi-Fi connection. Most delays resolve on their own.

If changes still don't appear:

1. **Check internet** — Confirm both devices have a working Wi-Fi or cellular connection.
2. **Check iCloud** — Go to Settings → [your name] → iCloud and confirm iCloud Drive is turned on. Check that Writing Shed Pro is allowed to use iCloud.
3. **Check iCloud storage** — If your iCloud storage is full, sync will stop. Free up space or upgrade your plan.
4. **Confirm the same Apple ID** — Both devices must be signed in to the same Apple ID.
5. **Force quit and reopen** — On the device that seems behind, force-quit the app and reopen it. This triggers a fresh sync check.
6. **Check Apple's system status** — Visit [apple.com/support/systemstatus](https://apple.com/support/systemstatus) to see if iCloud is experiencing a known outage.

### Using Sync Troubleshooting

If normal steps haven't helped, Writing Shed Pro has a built-in recovery tool. Go to **Settings → Sync Troubleshooting**.

The screen shows you:

- **iCloud Sync Status** — A green checkmark means recent syncs succeeded. An orange warning means sync may need attention.
- **Sync Actions** — Steps you can take to nudge or reset sync.
- **Guided Recovery** — A one-tap recovery sequence that safely resolves most persistent sync problems.

#### Run Guided Recovery

**Guided Recovery** is the recommended first step for any stubborn sync issue. Tap **Run Guided Recovery** and the app will:

1. Clear any rate-limiting backoff so sync can proceed at full speed.
2. Ask iCloud to deliver any pending changes immediately.
3. Wait for the sync activity to settle.
4. Check whether your projects match the expected state and report any mismatches.

This process takes 1–2 minutes. A status message tells you what happened. If projects are now fully synced, the status will show a green "Converged" result. If a problem was found, the status message describes it.

After Guided Recovery completes, you can tap **Copy Guided Recovery Report** to copy a detailed report to your clipboard. This report is useful if you need to contact support.

#### Force Sync Now

If you want to manually trigger an iCloud check without running the full Guided Recovery, tap **Force Sync Now**. This tells iCloud to deliver pending changes immediately. It is safe to use at any time.

#### Reset Sync Backoff State

If the app has encountered repeated network errors, it temporarily slows down sync attempts to avoid overloading iCloud. **Reset Sync Backoff State** clears this delay so normal sync speed resumes. This button only appears when a backoff is active.

#### Reset Sync Database

> **Warning: this deletes all local data on this device.** Only use this as a last resort.

**Reset Sync Database** removes the local copy of your data and re-downloads everything fresh from iCloud. Your iCloud data is not affected — nothing is deleted from iCloud. After resetting, the app will re-import all your projects from iCloud when it next launches.

Use this only when:
- Guided Recovery has not fixed the problem.
- You are confident that iCloud holds a complete, up-to-date copy of your data.
- Support has advised this step.

After tapping Reset Sync Database, quit and relaunch the app. Re-import begins automatically. Depending on how much data you have, it may take a few minutes.

### A Project Disappeared

If a project that existed on one device doesn't appear on another:

1. Scroll through the full project list — it may have moved.
2. Check the Trash within the app (swipe left on a project or use the project menu).
3. Wait a few minutes and check again — the project may still be syncing.
4. Open **Sync Troubleshooting → Run Guided Recovery** and check the result.

If the project is still missing after Guided Recovery, tap **Copy Guided Recovery Report** and [contact support](115-contact-support.md) with the report attached.

### Duplicate Projects Appearing

Occasionally iCloud can deliver the same project twice during a sync catch-up. Writing Shed Pro detects and removes true duplicates automatically. If you see duplicates:

1. Wait a few minutes — automatic deduplication usually runs within a minute or two of opening the app.
2. Force-quit and reopen the app to trigger deduplication immediately.
3. If duplicates persist after several minutes, delete the one with older or fewer changes.

### "Sync is temporarily rate-limited" Message

iCloud limits how often apps can send updates when a large volume of changes is being processed. The app shows this message and slows down sync automatically. **No action is needed** — rate limiting clears by itself, usually within a few minutes to an hour. Avoid force-quitting and relaunching repeatedly, as this can reset the clock.

### After Reinstalling the App

After reinstalling Writing Shed Pro, your projects re-import from iCloud automatically when you open the app. This can take several minutes depending on how much data you have. Keep the app in the foreground with a good Wi-Fi connection while the import completes.

If projects are missing after 10–15 minutes:

1. Force-quit and reopen the app.
2. If still missing, try **rebooting your device** — this restarts the iCloud sync service and often resolves stalled imports.
3. If still missing, open **Sync Troubleshooting → Run Guided Recovery**.

### Sync Conflicts

**Symptoms**: Duplicate files appear, or you see a message about conflicting versions.

**Solutions**:

1. Open both versions and compare.
2. Keep the one with the correct content.
3. Delete the other.

To avoid conflicts in future, wait for the sync indicator to clear before switching devices after making large edits.

## App Performance

### App Running Slowly

**Solutions**:
1. Close other apps
2. Restart the app
3. Restart your device
4. Check available storage space
5. Large projects may need more time

### App Crashes

**Solutions**:
1. Update to latest app version
2. Update iOS/macOS
3. Restart device
4. If persists, contact support with steps to reproduce

### App Won't Open

**Solutions**:
1. Force quit and try again
2. Restart device
3. Check for app updates
4. Reinstall the app (your data is in iCloud)

## Editing Issues

### Text Not Appearing

**Solutions**:
1. Check zoom level (⌘0 to reset)
2. Check text color vs background color
3. Scroll to cursor position
4. Force quit and reopen

### Formatting Lost

**Solutions**:
1. Undo (⌘Z) immediately
2. Check file version history
3. Formatting might be in style, not inline

### Undo Not Working

**Solutions**:
1. Undo has limits—can't undo everything
2. After save/close, undo resets
3. Check file versions for recovery

### Cursor Jumping

**Solutions**:
1. May be auto-scroll behavior
2. Check for accidental touches
3. Disable autocorrect if it's interfering

## Export and Print Issues

### PDF Looks Wrong

**Solutions**:
1. Check Page Setup settings
2. Preview in Pagination View before export
3. Check font availability
4. Try different export options

### Print Problems

**Solutions**:
1. Check printer is connected
2. Check paper size matches Page Setup
3. Check printer margins
4. Try Print to PDF first to verify

### Export Fails

**Solutions**:
1. Check available storage
2. Try exporting to a different location
3. Check permissions on destination folder
4. Try smaller file/fewer pages

## iCloud Issues

### Can't Enable iCloud

**Solutions**:
1. Sign into iCloud in device Settings
2. Ensure iCloud Drive is enabled
3. Ensure app is allowed to use iCloud
4. Check iCloud storage isn't full

### Files Missing

**Solutions**:
1. Check Trash within app
2. Check Recently Deleted in Files app
3. Check iCloud Drive in Files app
4. Files may still be downloading

### Files Stuck Downloading

**Solutions**:
1. Tap to force download
2. Check internet connection
3. Check iCloud storage
4. Wait—large files take time

## Poetry Features

### Syllable Count Wrong

**Solutions**:
1. Check word pronunciation
2. Custom words may need dictionary additions
3. Some words have multiple valid counts
4. Trust your ear for edge cases

### Rhyme Not Detected

**Solutions**:
1. Check spelling of both words
2. Some rhymes are imperfect/slant
3. Proper nouns may not be in dictionary
4. Regional pronunciation differences

## Fiction Features

### Scenes Not Linking

**Solutions**:
1. Check both scene and plot element exist
2. Link from scene settings
3. Save after making links

### Word Count Wrong

**Solutions**:
1. Count may exclude certain text
2. Check settings for what's counted
3. Footnotes/comments may be separate

## Drama Features

### DML Not Formatting

**Solutions**:
1. Check prefix syntax (`>` for action, etc.)
2. Character names must be ALL CAPS
3. Check for extra spaces
4. View in Preview to debug

### Output Format Wrong

**Solutions**:
1. Check Film vs Stage setting
2. Settings are per-project
3. Toggle and toggle back if stuck

## Recovery

### Lost Work

**Solutions**:
1. Check undo history
2. Check file versions (if available)
3. Check other devices for synced versions
4. Check Time Machine backup (Mac)
5. iCloud keeps some file versions

### Deleted File Recovery

1. Check Trash in app
2. Empty Trash must be confirmed
3. iCloud may retain deleted files briefly
4. Contact Apple Support for iCloud recovery

## Getting More Help

### Before Contacting Support

Collect this information:
- Device model and OS version
- App version
- Steps to reproduce issue
- Screenshots or screen recordings
- Error messages (exact text)

### Contact Methods

- In-app: Settings → Support
- Email: support@example.com
- Website: example.com/support

### Known Issues

Check the app's website for known issues and workarounds.

## See Also
- [FAQ](114-faq.md)
- [Contact Support](115-contact-support.md)
- [iCloud Sync](../3-getting-started/24-icloud-sync.md)

---
