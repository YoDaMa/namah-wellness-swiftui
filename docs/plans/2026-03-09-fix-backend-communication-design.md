# Fix Backend Communication — Design

## Problem

Four issues prevent reliable backend sync:

1. **AnyCodable corrupts sync push payloads** — `AnyCodable.encode()` can't handle nested dictionaries from `JSONSerialization`. Falls through to `String(describing:)`, corrupting data. Backend silently skips changes, iOS deletes SyncChange records → permanent data loss.

2. **`isOnline` race condition blocks initial sync** — `isOnline` defaults to `false`. `sync()` returns immediately on first call. NWPathMonitor callback compensates but introduces unnecessary delay/fragility.

3. **401 doesn't sign out** — SyncService catches `.unauthorized` but has no reference to AuthService. User stays stuck on authenticated view with no data.

4. **No seed data fallback** — Deferred. Once sync is reliable, this is lower priority.

## Changes

### 1. Replace AnyCodable with JSONSerialization

**File**: `SyncService.swift`

- Remove `AnyCodable` struct entirely
- In `pushPendingChanges()`, build the push body as `[[String: Any]]` using native Foundation types
- Serialize with `JSONSerialization.data(withJSONObject:)` to get raw `Data`
- Add `APIClient.postRaw(path:body:)` that accepts raw `Data` instead of `Encodable`
- Remove `SyncPushBody` struct

### 2. Remove isOnline guard from sync()

**File**: `SyncService.swift`

- Remove `guard isOnline else { return }` from `sync()`
- Keep NWPathMonitor for auto-sync-on-reconnect behavior
- Let URLSession throw naturally if offline (caught by existing error handling)

### 3. Add AuthService reference to SyncService

**Files**: `SyncService.swift`, `ContentView.swift`

- Add `private weak var authService: AuthService?` to SyncService (weak to avoid retain cycle)
- Update `configure(modelContext:authService:)` to accept AuthService
- In sync() unauthorized catch, call `authService?.handleUnauthorized()`
- Update ContentView to pass authService in configure call

## Files Modified

- `NamahWellness/Services/SyncService.swift` — all 3 fixes
- `NamahWellness/Services/APIClient.swift` — add `postRaw` method
- `NamahWellness/App/ContentView.swift` — pass authService to configure()
