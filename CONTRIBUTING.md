# Contributing

Thanks for helping improve Swipewipe Cleanup.

## Bug reports

Open an issue with your iOS version, install method, the steps that led to the problem, and what you expected to happen. If relevant, attach the in-app diagnostic log exported from the app. Logs contain hashed asset references and decision events, not photo contents or raw Photos identifiers; review the exported file before sharing it.

## Changes

Keep changes focused and explain the user-visible behavior they affect. For changes to photo decisions or deletion, describe how the change preserves the rule that only photos explicitly queued and confirmed by the user can be deleted.

Build the project with full Xcode and the iOS SDK using:

```sh
./build-ipa.sh
```

Please do not include personal photos, signing certificates, provisioning profiles, or private keys in commits or issue attachments.
