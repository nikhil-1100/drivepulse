# Privacy policy

**DrivePulse does not collect, transmit or sell any data.** This is enforced by
architecture, not only by policy.

## What the app stores on your device

| Data | Where | Why |
| --- | --- | --- |
| Preferences (theme, view, thresholds) | SharedPreferences | remember your choices |
| Activity log (transfers, ejects, scans) | app support `drivepulse/activity.json`, capped at 400 | local history |
| Authorised folder references | Android SAF grants; iOS security-scoped bookmarks | reopen folders you chose |
| Encrypted files | wherever you put them (`.dpv`) | your data |

## What the app never does

- No account, email, phone number or device identifier.
- No analytics, crash reporting or advertising SDK.
- No file contents or filenames leave the device.
- No network permission in the Android release manifest; the app cannot open a
  socket even if a dependency attempted to.
- No passphrase storage. Vault keys are derived in memory and discarded.

## Permissions

- **Android:** storage access is scoped. Drive enumeration uses the system
  `StorageManager`; browsing uses the Storage Access Framework after you grant a
  folder. No `MANAGE_EXTERNAL_STORAGE` is requested.
- **iOS:** the app sees its own Documents folder and folders you explicitly pick
  in the system document picker. iOS does not expose raw USB devices.

## Data deletion

- Clear history in **History → trash icon** or **Settings → Clear activity history**.
- Remove favourites individually.
- Uninstalling the app removes its preferences and history. Files you copied to
  drives remain on those drives.

## Children

The app has no accounts or user-generated content and collects no personal data.

## Contact

Open an issue at <https://github.com/nikhil-1100/drivepulse/issues>.
