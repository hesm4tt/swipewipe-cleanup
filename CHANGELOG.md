# Changelog

## 1.0.3 — 2026-10-02

- Added on-device diagnostic logs for displayed photos, decisions, review-queue changes, and deletion requests.
- Added stable card identity so the next photo cannot inherit a prior photo's thumbnail state.

## 1.0.2 — 2026-10-02

- Fixed keep/delete handling so only photos explicitly marked for deletion enter the deletion queue.
- Added Random 40 and month navigation during a session.
- Cleared stale pre-fix decisions on upgrade while preserving bookmarks and cleanup totals.

## 1.0.1 — 2026-10-02

- Fixed swipe progression when the counter advanced but the displayed photo did not.
- Cancelled the previous thumbnail request and reset thumbnail state when photos change.

## 1.0.0 — 2026-10-02

- First public build of the native iOS photo cleanup app.
