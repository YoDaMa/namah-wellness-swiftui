# Backend Integration Design

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Connect the iOS app to the existing Turso backend so users share data between web and mobile, with offline support.

**Decisions:**
- Auth: email/password via existing better-auth
- Offline: yes — SwiftData remains local cache, sync on launch/foreground
- Conflicts: last write wins
- Content source: server (remove local SeedService)
- API location: SvelteKit `/api/v1/*` routes in the existing web app
- Sync strategy: API-first with SwiftData cache — views keep using `@Query`, sync layer pulls/pushes in background

---

## 1. Authentication

### Web side
better-auth already supports JSON sign-in at `/api/auth/sign-in/email`. The response includes a session token. No new endpoints needed for auth itself — just ensure the token is returned in the JSON body (not only as a Set-Cookie).

### iOS side
**AuthService** (@Observable):
- Holds auth state: `.loggedOut`, `.authenticated(userId, token)`
- Token stored in Keychain (persists across launches, secure)
- On login: POST email/password → receive session token + user object
- All API calls include `Authorization: Bearer <token>`
- On 401 from any call → clear token, show login screen
- Session lifetime: 30 days (matches web config), refreshed on use

**New views:**
- `LoginView` — email, password, sign-in button, error state
- `ContentView` gates on `AuthService.isAuthenticated` — shows LoginView or TabView

---

## 2. API Endpoints (SvelteKit)

All endpoints require `Authorization: Bearer <token>`. All return JSON.

### Content (read-only, shared data)

| Endpoint | Method | Returns |
|----------|--------|---------|
| `/api/v1/content` | GET | All content: phases, meals, groceryItems, workouts, workoutSessions, coreExercises, phaseReminders, phaseNutrients, supplementDefinitions, supplementNutrients |

Single bulk endpoint — content is ~50KB total. Avoids 10 separate requests on launch.

### User data (per-user)

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/api/v1/sync` | GET | Pull all user data: cycleLogs, mealCompletions, workoutCompletions, symptomLogs, dailyNotes, groceryChecks, userSupplements, supplementLogs |
| `/api/v1/sync` | POST | Push array of changes. Each: `{ table, action: "upsert"|"delete", data }`. Returns full current state after applying |

### Cycle calculation

| Endpoint | Method | Returns |
|----------|--------|---------|
| `/api/v1/cycle` | GET | Computed: currentPhase, cycleStats, phaseRanges — reuses `getCycleBundle()` |

### Profile

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/api/v1/profile` | PATCH | Update user name, email preferences |

---

## 3. iOS Networking Layer

### APIClient (class)
```
APIClient
├── baseURL: "https://namah.yosephmaguire.com"
├── token: String? (from Keychain)
├── get<T: Decodable>(path:) async throws -> T
├── post<T: Decodable>(path:body:) async throws -> T
├── patch<T: Decodable>(path:body:) async throws -> T
└── Error enum: unauthorized, networkError, serverError(Int), decodable
```

Uses `URLSession` directly — no third-party dependencies.

### SyncService (@Observable)
```
SyncService
├── syncState: .idle | .syncing | .error(String)
├── lastSyncDate: Date?
├── sync() — full push+pull cycle
├── queueChange(table:action:data:) — records pending change
└── pendingChanges: [SyncChange] — persisted in SwiftData
```

### Sync flow (launch / foreground):
1. Push pending local changes → `POST /api/v1/sync`
2. Pull content → `GET /api/v1/content` → upsert into SwiftData
3. Pull user data → `GET /api/v1/sync` → upsert into SwiftData
4. Pull cycle state → `GET /api/v1/cycle` → update CycleService

### Change queueing
Existing action functions (toggleMeal, saveSymptoms, etc.) continue writing to SwiftData for instant UI. They also call `syncService.queueChange(...)` which creates a `SyncChange` record.

### SyncChange model (new SwiftData @Model)
```
SyncChange
├── id: String
├── table: String
├── action: String ("upsert" | "delete")
├── payload: String (JSON)
├── createdAt: Date
```

### Network monitoring
`NWPathMonitor` detects connectivity changes. When online after being offline → trigger sync automatically.

---

## 4. iOS Model Changes

### Add `userId` to 9 models
- CycleLog
- MealCompletion
- WorkoutCompletion
- SymptomLog
- DailyNote
- GroceryCheck
- UserSupplement
- SupplementLog
- SupplementDefinition (as `createdByUserId`)

Fields used for API round-tripping only — local `@Query` doesn't filter by userId since only one user's data is stored locally.

### UserProfile mapping
Maps to better-auth `user` table. Sync pulls name, email, emailEnabled, emailSendHour. Local-only fields: `dailyReminderEnabled`, `dailyReminderTime` (iOS push notification prefs).

### CycleService changes
Accepts server-computed cycle state from `/api/v1/cycle` instead of computing locally. Falls back to local computation from SwiftData CycleLogs when offline with no cached state.

### Remove SeedService
No longer needed — all content fetched from server. Remove `SeedService.swift` and the `migrateIconsToSFSymbols` call in ContentView.

---

## 5. App Startup Flow

```
App Launch
├── Check Keychain for token
├── No token → LoginView
└── Has token → TabView with cached SwiftData data
    └── Background: SyncService.sync()
        ├── Push queued changes
        ├── Pull content + user data + cycle
        └── SwiftData updated → @Query views auto-refresh
```

User sees cached data instantly. First-ever login shows loading state during initial pull.

---

## 6. File Changes Summary

### Web app (namah-nutrition-page) — new:
- `src/routes/api/v1/content/+server.ts`
- `src/routes/api/v1/sync/+server.ts`
- `src/routes/api/v1/cycle/+server.ts`
- `src/routes/api/v1/profile/+server.ts`

### iOS app — new:
- `NamahWellness/Services/APIClient.swift`
- `NamahWellness/Services/SyncService.swift`
- `NamahWellness/Services/AuthService.swift`
- `NamahWellness/Models/SyncChange.swift`
- `NamahWellness/Views/Auth/LoginView.swift`

### iOS app — modified:
- 9 models: add userId field
- `ContentView.swift`: gate on auth, inject SyncService
- `NamahWellnessApp.swift`: add SyncChange to ModelContainer
- `CycleService.swift`: accept server cycle state, keep local fallback
- Action functions: add queueChange() calls
- `UserProfile.swift`: map to server user fields

### iOS app — removed:
- `SeedService.swift`
- SF Symbol migration code in ContentView
