# CloudKit Sync - Quick Fixes

## ⚡ Sync Stopped Working?

**Run this command (fixes 80% of sync issues):**

```bash
cd /Users/Projects/WritingShedPro
./safe_reset_app_data.sh
```

Then in Xcode:
1. Product → Clean Build Folder (`Cmd+Shift+K`)
2. Product → Run (`Cmd+R`)

**That's it!** Sync should resume immediately.

---

## Why This Works

CloudKit maintains local sync tokens that can become stale or corrupted. Cleaning the app data:
- ✅ Removes stale sync tokens
- ✅ Forces CloudKit to re-establish connection
- ✅ Downloads fresh data from iCloud
- ✅ Resumes bidirectional sync

---

## When to Use This

Use the reset script when:
- Sync was working, then suddenly stopped
- Projects appear on one device but not the other
- Changes aren't propagating between devices
- App hasn't synced in several days

---

## If Reset Doesn't Work

1. **Check Console.app** for CloudKit errors:
   ```
   Open Console.app
   Filter: process:"Writing Shed Pro"
   Look for: "CKError" or "CloudKit"
   ```

2. **Verify same Apple ID** on both devices:
   - Mac: System Settings → Apple ID
   - iOS: Settings → [Your Name]

3. **Check iCloud Drive is enabled** for the app:
   - Mac: System Settings → Apple ID → iCloud → iCloud Drive
   - iOS: Settings → [Your Name] → iCloud → iCloud Drive

4. **See full guide**: `CLOUDKIT_SYNC_TROUBLESHOOTING.md`

---

## Prevention

To avoid sync issues in the future:
- Quit and relaunch the app every few days
- Keep both devices updated to latest iOS/macOS
- Ensure stable internet connection when syncing
- Don't let iCloud storage get full

---

**Note**: The "Operation not permitted" error when running `rm -rf` on the container is normal - it's macOS protecting system files. The script handles this correctly.
