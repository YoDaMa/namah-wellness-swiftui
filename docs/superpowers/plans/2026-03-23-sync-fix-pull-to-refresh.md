# Sync Fix + Pull-to-Refresh Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix broken iOS ↔ backend sync (all upserts fail silently due to missing NOT NULL timestamp fields) and add Instagram-style pull-to-refresh.

**Architecture:** The backend sync POST handler is the single fix point — it injects default timestamps for any missing NOT NULL timestamp field before inserting/upserting. The iOS app does not need to change its payloads; the backend is resilient to partial data. Pull-to-refresh is added via `.refreshable()` on ScrollViews in TodayView and MyCycleView. After sync, SwiftData `@Query` change notifications automatically trigger `recalculate()` in ContentView via `onChange(of: cycleLogSnapshot)`.

**Tech Stack:** SvelteKit (TypeScript) + Drizzle ORM backend, SwiftUI + SwiftData iOS app

**Known limitation:** `bbtLogs` and `sexualActivityLogs` do not have backend tables — iOS queues sync changes for them, but the sync handler silently skips unknown table names. This is a pre-existing gap unrelated to this fix.

**Stale SyncChange records:** Existing queued changes from previous failed syncs will safely replay once the backend fix is deployed. The upsert pattern (select → insert or update) handles duplicates correctly.

---

## File Map

| File | Action | Purpose |
|------|--------|---------|
| `namah-nutrition-page/src/routes/api/v1/sync/+server.ts` | Modify | Add timestamp defaults for all user data tables |
| `namah-wellness-swiftui/NamahWellness/Views/Today/TodayView.swift` | Modify | Add `.refreshable()` |
| `namah-wellness-swiftui/NamahWellness/Views/MyCycle/MyCycleView.swift` | Modify | Add `.refreshable()` |

---

### Task 1: Backend — Add Timestamp Defaults in Sync Handler

**Files:**
- Modify: `../namah-nutrition-page/src/routes/api/v1/sync/+server.ts`

The root cause: every user data table has a NOT NULL timestamp field (createdAt, completedAt, updatedAt, startedAt, loggedAt, hiddenAt, selectedAt) that the iOS app never sends. The backend tries to insert without it → SQLite NOT NULL constraint violation → 500 error → sync dies silently.

- [ ] **Step 1: Add timestamp defaults map**

Add after the `tableMap` definition (after line 69):

```typescript
// ──────────────────────────────────────────────
// Timestamp fields that default to "now" if missing from client payload.
// Drizzle mode:'timestamp' columns expect Date objects.
// ──────────────────────────────────────────────

const timestampDefaults: Partial<Record<TableName, string[]>> = {
	cycleLogs: ['createdAt'],
	mealCompletions: ['completedAt'],
	workoutCompletions: ['completedAt'],
	dailyNotes: ['updatedAt'],
	groceryChecks: ['updatedAt'],
	userSupplements: ['startedAt'],
	supplementLogs: ['loggedAt'],
	userPlanSelections: ['selectedAt'],
	userPlanItems: ['createdAt'],
	userItemsHidden: ['hiddenAt'],
	planItemLogs: ['completedAt']
};
```

- [ ] **Step 2: Apply defaults in the POST handler before insert/update**

Replace the `else if (action === 'upsert')` block (lines 173-189) inside the `for (const change of changes)` loop:

```typescript
		} else if (action === 'upsert') {
			// Fill in missing NOT NULL timestamp fields with current time
			const defaults = timestampDefaults[tableName as TableName];
			if (defaults) {
				for (const field of defaults) {
					if (data[field] === undefined || data[field] === null) {
						data[field] = new Date();
					}
				}
			}

			const existing = await db
				.select({ id: idCol })
				.from(table)
				.where(and(eq(idCol, data.id as string), eq(userCol, userId)))
				.limit(1);

			const row = { ...data, userId } as typeof table.$inferInsert;

			if (existing.length > 0) {
				await db
					.update(table)
					.set(row)
					.where(and(eq(idCol, data.id as string), eq(userCol, userId)));
			} else {
				await db.insert(table).values(row);
			}
		}
```

- [ ] **Step 3: Build and verify**

```bash
cd ../namah-nutrition-page
npm run build   # verify no TypeScript errors
```

Expected: Build succeeds with no errors.

- [ ] **Step 4: Commit and deploy**

```bash
git add src/routes/api/v1/sync/+server.ts
git commit -m "fix: add timestamp defaults in sync handler — prevents NOT NULL constraint violations from iOS payloads"
```

Deploy to Cloudflare Pages (push to main or trigger deploy). The backend fix MUST be live before testing the iOS changes.

---

### Task 2: iOS — Add Pull-to-Refresh to TodayView

**Files:**
- Modify: `NamahWellness/Views/Today/TodayView.swift`

Add `.refreshable()` on the ScrollView so users can swipe down to force a sync. `syncService` is already available via `@Environment(SyncService.self)` — verify this exists in TodayView's properties before proceeding.

- [ ] **Step 1: Verify syncService environment access**

Check TodayView's properties for `@Environment(SyncService.self)`. If missing, add:

```swift
    @Environment(SyncService.self) private var syncService
```

ContentView already injects `syncService` into the environment at line 59: `.environment(syncService)`.

- [ ] **Step 2: Add `.refreshable()` modifier to the ScrollView**

Find the `ScrollView {` in TodayView's body (line ~260). Add `.refreshable()` after the ScrollView's closing brace, before `.navigationTitle` or other modifiers chained on the NavigationStack:

```swift
            .refreshable {
                await syncService.sync()
            }
```

`.refreshable()` must be inside the `NavigationStack` scope (on the ScrollView or its parent within NavigationStack) to show the standard pull-down spinner.

- [ ] **Step 3: Build and verify**

```bash
xcodebuild -project NamahWellness.xcodeproj -scheme NamahWellness -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | tail -5
```

Expected: BUILD SUCCEEDED

- [ ] **Step 4: Commit**

```bash
git add NamahWellness/Views/Today/TodayView.swift
git commit -m "feat: add pull-to-refresh to TodayView"
```

---

### Task 3: iOS — Add Pull-to-Refresh to MyCycleView

**Files:**
- Modify: `NamahWellness/Views/MyCycle/MyCycleView.swift`

Same pattern as TodayView.

- [ ] **Step 1: Verify syncService environment access**

Check MyCycleView's properties for `@Environment(SyncService.self)`. If missing, add:

```swift
    @Environment(SyncService.self) private var syncService
```

- [ ] **Step 2: Add `.refreshable()` modifier to the ScrollView**

Find the `ScrollView {` in MyCycleView's body (line ~137). Add `.refreshable()` after the ScrollView's closing brace, before other modifiers:

```swift
            .refreshable {
                await syncService.sync()
            }
```

- [ ] **Step 3: Build and verify**

```bash
xcodebuild -project NamahWellness.xcodeproj -scheme NamahWellness -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | tail -5
```

Expected: BUILD SUCCEEDED

- [ ] **Step 4: Commit**

```bash
git add NamahWellness/Views/MyCycle/MyCycleView.swift
git commit -m "feat: add pull-to-refresh to MyCycleView"
```

---

### Task 4: End-to-End Verification

- [ ] **Step 1: Confirm backend is deployed**

Verify Task 1's backend changes are live at `namah.yosephmaguire.com`.

- [ ] **Step 2: Test in simulator**

Option A (clean start): Delete and reinstall the app in the simulator, then sign in fresh with `yosephmaguire@protonmail.com`. This clears the stale SyncChange queue.

Option B (preserve state): Just run the app — the stale SyncChange records should now push through successfully since the backend accepts the previously-broken payloads.

- [ ] **Step 3: Test iOS → backend sync**

1. Log a new period in the iOS simulator
2. Pull down to refresh — verify the spinner appears and completes without error
3. Check Turso DB: `SELECT * FROM cycleLogs WHERE userId = '<your-user-id>'` — verify the row exists
4. Check the web app — verify the period shows up

- [ ] **Step 4: Test backend → iOS sync**

1. Log a period on the web app
2. Pull down to refresh in the iOS simulator
3. Verify the web-logged period appears in My Cycle view

- [ ] **Step 5: Test bidirectional**

1. Log a period on iOS (e.g., March 1)
2. Log a different period on web (e.g., March 5)
3. Pull down to refresh on iOS
4. Verify both periods appear correctly in both platforms
