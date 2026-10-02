# Swipewipe Cleanup (iOS)

An unofficial native SwiftUI photo-cleanup app based on the interaction shown in the supplied Swipewipe webarchive.

## Included

- Month-by-month photo review, sorted by capture date.
- A Random 40 mode that shuffles a selection of up to 40 photos from the library.
- Swipe right to keep and swipe left to queue for deletion; both actions have buttons too.
- Undo the last swipe and bookmark a photo for later.
- Final deletion review grid where a photo can be removed from the queue.
- Return to the month picker during a session and open any month again.
- Keep decisions are excluded from the deletion review and delete request.
- Confirmed deletion through Apple's Photos framework, plus per-session and all-time storage totals.
- “On This Day,” saved bookmarks, and persistent month progress.

Photos remain untouched until the user confirms deletion from the review screen. The app only handles still images, matching the supplied page's image-focused flow.

## Download and install

- [Download the latest IPA](https://github.com/hesm4tt/swipewipe-cleanup/releases/latest/download/SwipewipeCleanup.ipa)
- [Install directly in LiveContainer](livecontainer://install?url=https%3A%2F%2Fgithub.com%2Fhesm4tt%2Fswipewipe-cleanup%2Freleases%2Flatest%2Fdownload%2FSwipewipeCleanup.ipa)

## Build an IPA

The included Xcode project targets iOS 16 and uses only system frameworks. On a Mac with full Xcode installed, run `./build-ipa.sh` to create an unsigned IPA at `SwipewipeCleanup.ipa`. LiveContainer can run unsigned guest apps with JIT; its JIT-less mode signs guest apps with the certificate configured in LiveContainer.

LiveContainer can install an app from a direct IPA URL. The scheme URL above encodes the release download URL as its `url` parameter.

```text
livecontainer://install?url=<percent-encoded-https-ipa-url>
```

This Mac has Xcode 27 beta installed, while `xcode-select` points to Command Line Tools. The build script detects an installed Xcode when the selected developer directory cannot build iOS apps.
