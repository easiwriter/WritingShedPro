# iCloud Sync

Writing Shed Pro uses iCloud to keep your projects synchronized across all your Apple devices. This guide explains how sync works and how to troubleshoot issues.

## How iCloud Sync Works

When you enable iCloud:
- All projects are stored in iCloud Drive
- Changes sync automatically, but not instantly
- Your work is backed up continuously
- Devices must be signed into the same Apple ID

### What Syncs
- All projects and their contents
- Folder structure
- File content and formatting
- Images embedded in documents
- Version history
- Settings and preferences

### What Doesn't Sync
- Local cache and temporary files
- Undo history beyond the current session

## Enabling iCloud

### Check iCloud Status
1. Open **Settings** (iPhone/iPad) or **System Settings** (Mac)
2. Tap your **Apple ID** at the top
3. Tap **iCloud**
4. Ensure **iCloud Drive** is On
5. Scroll down and ensure **Writing Shed Pro** is On

### First-Time Setup
When you first open Writing Shed Pro with iCloud enabled:
1. The app creates a container in iCloud Drive
2. Existing projects (if any) upload to iCloud
3. Projects from other devices appear automatically

## Syncing Multiple Devices

For seamless sync across devices:
1. Install Writing Shed Pro on each device
2. Sign into the same Apple ID on all devices
3. Enable iCloud Drive on all devices
4. Enable Writing Shed Pro in iCloud settings on all devices

### Sync Speed
Sync is automatic, but it is not instant. Small edits may appear on another device quickly, while larger projects, first-time setup, images, imports, or a device that has been offline can take several minutes to catch up.

- Local changes are saved instantly
- Cloud sync often completes quickly, but can take several minutes
- Large files (with many images) may take longer
- Wi-Fi is faster than cellular

## Working Offline

Writing Shed Pro works fully offline:
- All recent projects are available locally
- You can read and edit without internet
- Changes are queued for sync
- When you reconnect, changes upload automatically

### Offline Indicators
- A cloud icon may indicate pending sync
- Check the project list for sync status

## Conflict Resolution

If you edit the same file on two devices before sync completes:

1. **Both versions are preserved**: No data is lost
2. **Most recent wins**: The latest change becomes the current version
3. **Other changes saved**: Earlier changes are available in version history

### Avoiding Conflicts
- Wait for sync to finish before switching devices, especially after larger edits or imports
- Ensure sync has completed (no pending upload indicators)
- If in doubt, wait for the cloud icon to clear

## Managing iCloud Storage

Projects count toward your iCloud storage quota.

### Check Usage
1. Settings → [Your Name] → iCloud → Manage Account Storage
2. Look for Writing Shed Pro

### Reducing Usage
- Delete old projects you no longer need
- Empty the Trash in each project
- Export and archive completed work

## Turning Off iCloud

If you need to disable iCloud sync:

**Warning**: This will remove Writing Shed Pro data from iCloud. Projects on other devices may no longer be accessible.

1. Settings → [Your Name] → iCloud → Apps Using iCloud
2. Toggle **Writing Shed Pro** Off
3. Choose whether to keep or delete local copies

## Troubleshooting

### Projects Not Appearing
1. Verify you're signed into the correct Apple ID
2. Check that iCloud Drive is enabled
3. Check that Writing Shed Pro is enabled in iCloud settings
4. Wait a few minutes for initial sync
5. Check internet connection
6. Restart the app

### Sync Seems Slow
1. Check your internet connection speed
2. Large projects with many images take longer
3. Initial sync of a new device may take time
4. Try switching from cellular to Wi-Fi

### Changes Not Syncing
1. Check for a cloud icon indicating pending upload
2. Ensure the device has internet access
3. Force-quit and reopen the app
4. Restart the device
5. Check iCloud system status at apple.com/support/systemstatus

### "This file is being edited on another device"
This message appears when there's a potential conflict:
1. Save your work
2. Wait a moment for sync
3. Reload the file
4. Your changes and the other device's changes will both be preserved

### Recovering Lost Data
If data appears to be missing:
1. Check iCloud.com in a web browser
2. Look in iCloud Drive → Writing Shed Pro
3. Check the Trash folder in your projects
4. Restore from iCloud backup if necessary

## Privacy and Security

Your writing in iCloud is protected by:
- End-to-end encryption in transit
- Encryption at rest on Apple servers
- Your Apple ID password
- Optional two-factor authentication (highly recommended)

Writing Shed Pro never has access to your Apple ID password. All sync is handled securely by the system.

## See Also
- [Installation](21-installation.md)
- [Troubleshooting](../12-reference/113-troubleshooting.md)

---
