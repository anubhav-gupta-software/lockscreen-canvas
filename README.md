# Doodl

A shared page for two people. You pair with an invite code, draw or write, and the same drawing shows up in the app on the other phone and, once sharing is turned on, on their Lock Screen and Home Screen.

The name on the iPhone is Doodl. The Xcode project, schemes, and bundle ids still use the LockscreenCanvas names so an existing install keeps working.

## What you can do

- Start a Doodl and get a 6-character code, or join someone else's.
- Draw with a pen, an eraser, and a few brush sizes and colors. Undo, redo, and clear are there, and you can drop text on the page.
- Keep the drawing on one iPhone with no account and no keys. That is the default.
- Sync between two phones by pasting a Firebase Realtime Database URL. There is no Firebase SDK and no API key. The URL is the whole setup.
- Add a WidgetKit widget: Home Screen small, medium, and large, plus Lock Screen circular, rectangular, and inline.

The page is square, so a mark you make in the editor lands in the same place on the widget.

## Requirements

- Mac with Xcode 16 or later
- iPhone running iOS 17 or later
- A free Apple ID, the personal team Xcode creates for you

A paid Apple Developer Program membership is only needed for two things, both optional until you want them:

- The widget actually showing the live drawing (App Groups)
- TestFlight or the App Store

## Install it on your iPhone with a free Apple ID

1. Install Xcode from the Mac App Store and open it once so it can finish installing the extra components.
2. Plug in the iPhone, unlock it, and tap Trust on the “Trust This Computer?” prompt.
3. On the iPhone, turn on Developer Mode: Settings → Privacy & Security → Developer Mode. The phone will restart.
4. Clone this repo and open `LockscreenCanvas.xcodeproj`.
5. Leave the scheme set to **LockscreenCanvas**. That scheme builds the Personal configuration, which does not ask for the App Group entitlement. A free personal team can sign it.
6. In the toolbar, set the run destination to your iPhone, not a simulator. A simulator is fine for a look, but widgets and free-account install are a device thing.
7. Select the **LockscreenCanvas** target, open Signing & Capabilities, check “Automatically manage signing”, and choose your Personal Team. Then select the **LockscreenCanvasWidget** target and choose the same team. Both targets have to be signed or the install fails.
8. If Xcode says the bundle id is already registered, change the app’s bundle id to something you own, such as `com.yourname.lockscreen-canvas`, and set the widget’s bundle id to that same id plus `.widget`. The widget id has to be a child of the app id.
9. Press Run. The first install usually takes a minute.
10. If the phone says the developer is untrusted, open Settings → General → VPN & Device Management (on some versions it is just Device Management), tap your Apple ID, and tap Trust.

A free provisioning profile lasts about 7 days. When the app stops opening, plug the phone back in and press Run again.

Do not add the App Groups capability from the Signing tab while you are on a free team. Xcode will try to sign an entitlement the personal team does not have, and the build will fail. The shared scheme below is the switch for that, after you have a paid account.

### Add the widget

Touch and hold the Lock Screen, tap Customize, tap the area under the clock or a circular complication, and add **Doodl**. The same widget is in the Home Screen widget gallery in small, medium, and large.

On a free Apple ID the widget installs, but it cannot read the drawing. iOS only lets the app and the widget share files through an App Group, and Apple sells that capability with the paid program. The app will say so on the home screen. Drawing, invite codes, and phone-to-phone sync in the app all work without it.

## Sync between two phones

Local mode is the default. `Shared/SyncConfig.swift` ships with this placeholder:

```swift
static let placeholderDatabaseURL = "https://YOUR_PROJECT-default-rtdb.firebaseio.com"
```

While that placeholder is still there, and Settings has no database URL, nothing leaves the phone.

To sync:

1. Create a free Firebase project and add a Realtime Database. The console gives you a URL like `https://your-project-default-rtdb.firebaseio.com` or a `firebasedatabase.app` host. Either one works.
2. Open the Rules tab and, for a private demo between friends, allow read and write. The invite code is the only secret, so treat the database like a shared notebook, not a vault. The stored path is `/canvases/{code}`, which is an internal name and not the one on the phone:

```json
{
  "rules": {
    "canvases": {
      "$code": {
        ".read": true,
        ".write": true
      }
    }
  }
}
```

3. On both phones, open Settings in the app and paste the database root. You can instead replace the placeholder string in `SyncConfig.swift` and rebuild, which also lets the widget refresh from the network once the App Group is on.
4. One person taps Start a Doodl and shares the code. The other taps Join with a code.

Drawings merge by stroke and text. If you both draw at the same time, both marks stay. Undo removes your mark without wiping theirs. The app polls every few seconds while it is open and pushes shortly after each stroke.

You do not need `GoogleService-Info.plist`, CocoaPods, or a server you host. CloudKit would also work as a backend, but the iCloud capability needs a paid developer account, so it is not wired up.

## Let the Lock Screen show the drawing

This is the paid-account step.

1. Enroll in the [Apple Developer Program](https://developer.apple.com/programs/).
2. In Certificates, Identifiers & Profiles, register an App Group with the id `group.com.anubhavgupta.lockscreen-canvas`. If you changed the bundle id, pick a group id of your own and put the same string in both entitlements files and in `AppGroup.identifier` in `Shared/AppGroup.swift`.
3. Make sure the App IDs for `com.anubhavgupta.lockscreen-canvas` and `com.anubhavgupta.lockscreen-canvas.widget` both have the App Groups capability and that group selected.
4. In Xcode, switch the scheme to **LockscreenCanvas Shared**, select your paid team on both targets, and press Run.

Debug and Release sign `LockscreenCanvas/LockscreenCanvas.entitlements` and the widget’s matching file. Personal, which is what the default scheme runs and archives, signs `Config/Empty.entitlements` so a free team never sees the capability.

After this, strokes are written to the shared container and the widget reloads. The widget also fetches the shared drawing on its own timeline (about every 15 minutes) if a database URL is set, so the Lock Screen can catch up while the app is closed.

## TestFlight later

TestFlight needs the paid program. A free Apple ID cannot upload a build.

1. In App Store Connect, create an app with the bundle id `com.anubhavgupta.lockscreen-canvas`.
2. Finish the App Group setup in the previous section. Archive with the **LockscreenCanvas Shared** scheme so the build is Release and includes the entitlement. Product → Archive, then Distribute App → App Store Connect → Upload.
3. The widget extension is embedded in the app, so it goes up with the same archive. It does not get its own App Store listing.
4. When the build finishes processing, open TestFlight, add yourself as an internal tester, and install from the TestFlight app. External testers need a short beta review.
5. `ITSAppUsesNonExemptEncryption` is already false, so the export-compliance question should stay out of the way. The privacy manifest in `Shared/PrivacyInfo.xcprivacy` says the app does not track.

The default scheme archives without the App Group on purpose, so a free account can still produce an install. Use the Shared scheme for anything you send to TestFlight.

## Project layout

```
project.yml                          XcodeGen spec
LockscreenCanvas.xcodeproj           generated project, checked in
LockscreenCanvas/                    app UI, signing plist, icon
LockscreenCanvasWidget/              Home Screen and Lock Screen widgets
Shared/                              model, merge, store, Firebase REST, renderer
Config/Empty.entitlements            signed by the free-account configuration
Tests/check_canvas.swift             model checks, not part of the Xcode target
```

Regenerate the project after you change `project.yml`:

```sh
brew install xcodegen
xcodegen generate
```

The drawing model can be checked without Xcode, from a machine with a Swift toolchain:

```sh
swiftc -o /tmp/check-canvas \
  Shared/AppGroup.swift \
  Shared/InviteCode.swift \
  Shared/SyncConfig.swift \
  Shared/CanvasJSON.swift \
  Shared/CanvasDocument.swift \
  Shared/DrawingModel.swift \
  Shared/SharedStore.swift \
  Shared/RESTTransport.swift \
  Shared/SampleCanvas.swift \
  Tests/check_canvas.swift
/tmp/check-canvas
```

## Troubleshooting

- **Signing requires a development team.** Pick your Personal Team on both the app and the widget.
- **Personal development teams do not support the App Groups capability.** You are building the Shared scheme, or App Groups got toggled on in Signing & Capabilities. Switch back to the LockscreenCanvas scheme.
- **The widget installs but stays blank or says sharing is off.** Expected on a free team. The section above turns it on.
- **Join says you need a database URL.** Local mode cannot see a Doodl that was started on another phone. Add the Firebase URL on both phones, or start one on this phone.
- **The database refused the update.** The Realtime Database rules are still locked. Use the rules above, and paste the database root, not a `?auth=` URL.
- **The app will not open after a week.** Run it from Xcode again to refresh the free profile.
- **Bundle id is not available.** Change both bundle ids together, widget last component `.widget`.
