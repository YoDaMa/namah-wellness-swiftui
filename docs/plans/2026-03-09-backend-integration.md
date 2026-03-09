# Backend Integration Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Connect the iOS app to the existing Turso backend via SvelteKit API endpoints, with offline-first SwiftData caching and background sync.

**Architecture:** Add JSON API endpoints to the existing SvelteKit web app (`/api/v1/*`). iOS app authenticates via better-auth session tokens, stores token in Keychain. SwiftData remains the local cache — views keep using `@Query`. A SyncService pushes queued local changes and pulls fresh data on launch/foreground. Last-write-wins for conflicts.

**Tech Stack:** SvelteKit + Drizzle ORM (web API), Swift + URLSession + SwiftData + Keychain (iOS), better-auth (auth), Turso/libsql (database)

**Repos:**
- Web: `/Users/yosephmaguire/repos/namah-nutrition-page`
- iOS: `/Users/yosephmaguire/repos/namah-wellness-swiftui`

---

## Task 1: Auth helper for API routes (Web)

Create a reusable helper that extracts and validates bearer tokens from the `Authorization` header. All `/api/v1/*` endpoints will use this.

**Files:**
- Create: `src/lib/server/api-auth.ts` (in namah-nutrition-page repo)

**Step 1: Create the auth helper**

```typescript
// src/lib/server/api-auth.ts
import { db } from '$lib/server/db';
import { session, user } from '$lib/server/db/schema';
import { eq } from 'drizzle-orm';

export type ApiUser = {
  id: string;
  name: string;
  email: string;
};

export type AuthResult =
  | { ok: true; user: ApiUser }
  | { ok: false; response: Response };

export async function authenticateRequest(request: Request): Promise<AuthResult> {
  const authHeader = request.headers.get('authorization') ?? '';
  const token = authHeader.startsWith('Bearer ') ? authHeader.slice(7) : null;

  if (!token) {
    return {
      ok: false,
      response: new Response(JSON.stringify({ error: 'Missing authorization token' }), {
        status: 401,
        headers: { 'Content-Type': 'application/json' }
      })
    };
  }

  const [sessionRecord] = await db
    .select({ id: session.id, userId: session.userId, expiresAt: session.expiresAt })
    .from(session)
    .where(eq(session.token, token));

  if (!sessionRecord || new Date(sessionRecord.expiresAt) < new Date()) {
    return {
      ok: false,
      response: new Response(JSON.stringify({ error: 'Invalid or expired token' }), {
        status: 401,
        headers: { 'Content-Type': 'application/json' }
      })
    };
  }

  const [userRecord] = await db
    .select({ id: user.id, name: user.name, email: user.email })
    .from(user)
    .where(eq(user.id, sessionRecord.userId));

  if (!userRecord) {
    return {
      ok: false,
      response: new Response(JSON.stringify({ error: 'User not found' }), {
        status: 401,
        headers: { 'Content-Type': 'application/json' }
      })
    };
  }

  return { ok: true, user: userRecord };
}

export function jsonResponse(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { 'Content-Type': 'application/json' }
  });
}
```

**Step 2: Verify it builds**

Run: `cd /Users/yosephmaguire/repos/namah-nutrition-page && npm run check`
Expected: No type errors

**Step 3: Commit**

```bash
cd /Users/yosephmaguire/repos/namah-nutrition-page
git add src/lib/server/api-auth.ts
git commit -m "feat(api): add bearer token auth helper for API routes"
```

---

## Task 2: Content endpoint (Web)

Returns all shared content tables in a single response. iOS app calls this on sync to populate local SwiftData.

**Files:**
- Create: `src/routes/api/v1/content/+server.ts` (in namah-nutrition-page repo)

**Step 1: Create the content endpoint**

```typescript
// src/routes/api/v1/content/+server.ts
import { db } from '$lib/server/db';
import {
  phases, meals, groceryItems, workouts, workoutSessions,
  coreExercises, phaseReminders, phaseNutrients,
  supplementDefinitions, supplementNutrients
} from '$lib/server/db/schema';
import { authenticateRequest, jsonResponse } from '$lib/server/api-auth';
import { asc } from 'drizzle-orm';
import type { RequestHandler } from './$types';

export const GET: RequestHandler = async ({ request }) => {
  const auth = await authenticateRequest(request);
  if (!auth.ok) return auth.response;

  const [
    phasesData, mealsData, groceryData, workoutsData,
    sessionsData, exercisesData, remindersData, nutrientsData,
    supplementDefsData, supplementNutrientsData
  ] = await Promise.all([
    db.select().from(phases).orderBy(asc(phases.dayStart)),
    db.select().from(meals).orderBy(asc(meals.dayNumber)),
    db.select().from(groceryItems),
    db.select().from(workouts).orderBy(asc(workouts.dayOfWeek)),
    db.select().from(workoutSessions),
    db.select().from(coreExercises),
    db.select().from(phaseReminders),
    db.select().from(phaseNutrients),
    db.select().from(supplementDefinitions),
    db.select().from(supplementNutrients),
  ]);

  return jsonResponse({
    phases: phasesData,
    meals: mealsData,
    groceryItems: groceryData,
    workouts: workoutsData,
    workoutSessions: sessionsData,
    coreExercises: exercisesData,
    phaseReminders: remindersData,
    phaseNutrients: nutrientsData,
    supplementDefinitions: supplementDefsData,
    supplementNutrients: supplementNutrientsData,
  });
};
```

**Step 2: Verify it builds**

Run: `cd /Users/yosephmaguire/repos/namah-nutrition-page && npm run check`
Expected: No type errors

**Step 3: Commit**

```bash
cd /Users/yosephmaguire/repos/namah-nutrition-page
git add src/routes/api/v1/content/+server.ts
git commit -m "feat(api): add /api/v1/content endpoint for bulk content fetch"
```

---

## Task 3: Sync endpoint (Web)

GET returns all user-owned data. POST accepts an array of changes (upsert/delete) and returns the updated state.

**Files:**
- Create: `src/routes/api/v1/sync/+server.ts` (in namah-nutrition-page repo)

**Step 1: Create the sync endpoint**

```typescript
// src/routes/api/v1/sync/+server.ts
import { db } from '$lib/server/db';
import {
  cycleLogs, mealCompletions, workoutCompletions, symptomLogs,
  dailyNotes, groceryChecks, userSupplements, supplementLogs
} from '$lib/server/db/schema';
import { authenticateRequest, jsonResponse } from '$lib/server/api-auth';
import { eq, and } from 'drizzle-orm';
import type { RequestHandler } from './$types';

async function getUserData(userId: string) {
  const [logs, mealDone, workoutDone, symptoms, notes, checks, userSups, supLogs] =
    await Promise.all([
      db.select().from(cycleLogs).where(eq(cycleLogs.userId, userId)),
      db.select().from(mealCompletions).where(eq(mealCompletions.userId, userId)),
      db.select().from(workoutCompletions).where(eq(workoutCompletions.userId, userId)),
      db.select().from(symptomLogs).where(eq(symptomLogs.userId, userId)),
      db.select().from(dailyNotes).where(eq(dailyNotes.userId, userId)),
      db.select().from(groceryChecks).where(eq(groceryChecks.userId, userId)),
      db.select().from(userSupplements).where(eq(userSupplements.userId, userId)),
      db.select().from(supplementLogs).where(eq(supplementLogs.userId, userId)),
    ]);

  return {
    cycleLogs: logs,
    mealCompletions: mealDone,
    workoutCompletions: workoutDone,
    symptomLogs: symptoms,
    dailyNotes: notes,
    groceryChecks: checks,
    userSupplements: userSups,
    supplementLogs: supLogs,
  };
}

const tableMap = {
  cycleLogs: { table: cycleLogs, idCol: cycleLogs.id, userCol: cycleLogs.userId },
  mealCompletions: { table: mealCompletions, idCol: mealCompletions.id, userCol: mealCompletions.userId },
  workoutCompletions: { table: workoutCompletions, idCol: workoutCompletions.id, userCol: workoutCompletions.userId },
  symptomLogs: { table: symptomLogs, idCol: symptomLogs.id, userCol: symptomLogs.userId },
  dailyNotes: { table: dailyNotes, idCol: dailyNotes.id, userCol: dailyNotes.userId },
  groceryChecks: { table: groceryChecks, idCol: groceryChecks.id, userCol: groceryChecks.userId },
  userSupplements: { table: userSupplements, idCol: userSupplements.id, userCol: userSupplements.userId },
  supplementLogs: { table: supplementLogs, idCol: supplementLogs.id, userCol: supplementLogs.userId },
} as const;

type TableName = keyof typeof tableMap;

export const GET: RequestHandler = async ({ request }) => {
  const auth = await authenticateRequest(request);
  if (!auth.ok) return auth.response;

  const data = await getUserData(auth.user.id);
  return jsonResponse(data);
};

export const POST: RequestHandler = async ({ request }) => {
  const auth = await authenticateRequest(request);
  if (!auth.ok) return auth.response;

  const { changes } = await request.json() as {
    changes: Array<{ table: string; action: 'upsert' | 'delete'; data: Record<string, unknown> }>;
  };

  if (!Array.isArray(changes)) {
    return jsonResponse({ error: 'changes must be an array' }, 400);
  }

  for (const change of changes) {
    const tableName = change.table as TableName;
    const entry = tableMap[tableName];
    if (!entry) continue;

    if (change.action === 'delete') {
      await db.delete(entry.table)
        .where(and(eq(entry.idCol, change.data.id as string), eq(entry.userCol, auth.user.id)));
    } else if (change.action === 'upsert') {
      // Ensure userId is set to authenticated user
      const row = { ...change.data, userId: auth.user.id };

      // Try update first, insert if no rows affected
      const existing = await db.select({ id: entry.idCol })
        .from(entry.table)
        .where(and(eq(entry.idCol, row.id as string), eq(entry.userCol, auth.user.id)));

      if (existing.length > 0) {
        await db.update(entry.table).set(row).where(eq(entry.idCol, row.id as string));
      } else {
        await db.insert(entry.table).values(row);
      }
    }
  }

  // Return full current state after applying changes
  const data = await getUserData(auth.user.id);
  return jsonResponse(data);
};
```

**Step 2: Verify it builds**

Run: `cd /Users/yosephmaguire/repos/namah-nutrition-page && npm run check`
Expected: No type errors

**Step 3: Commit**

```bash
cd /Users/yosephmaguire/repos/namah-nutrition-page
git add src/routes/api/v1/sync/+server.ts
git commit -m "feat(api): add /api/v1/sync endpoint for user data push/pull"
```

---

## Task 4: Cycle and profile endpoints (Web)

**Files:**
- Create: `src/routes/api/v1/cycle/+server.ts`
- Create: `src/routes/api/v1/profile/+server.ts`

**Step 1: Create the cycle endpoint**

```typescript
// src/routes/api/v1/cycle/+server.ts
import { getCycleBundle } from '$lib/server/cycle';
import { authenticateRequest, jsonResponse } from '$lib/server/api-auth';
import type { RequestHandler } from './$types';

export const GET: RequestHandler = async ({ request }) => {
  const auth = await authenticateRequest(request);
  if (!auth.ok) return auth.response;

  const bundle = await getCycleBundle(auth.user.id);
  return jsonResponse(bundle);
};
```

**Step 2: Create the profile endpoint**

```typescript
// src/routes/api/v1/profile/+server.ts
import { db } from '$lib/server/db';
import { user } from '$lib/server/db/schema';
import { eq } from 'drizzle-orm';
import { authenticateRequest, jsonResponse } from '$lib/server/api-auth';
import type { RequestHandler } from './$types';

export const GET: RequestHandler = async ({ request }) => {
  const auth = await authenticateRequest(request);
  if (!auth.ok) return auth.response;

  const [profile] = await db.select({
    id: user.id,
    name: user.name,
    email: user.email,
    emailEnabled: user.emailEnabled,
    emailSendHour: user.emailSendHour,
  }).from(user).where(eq(user.id, auth.user.id));

  if (!profile) return jsonResponse({ error: 'User not found' }, 404);
  return jsonResponse(profile);
};

export const PATCH: RequestHandler = async ({ request }) => {
  const auth = await authenticateRequest(request);
  if (!auth.ok) return auth.response;

  const body = await request.json() as Record<string, unknown>;

  // Only allow updating specific fields
  const allowed: Record<string, unknown> = {};
  if ('name' in body && typeof body.name === 'string') allowed.name = body.name;
  if ('emailEnabled' in body && typeof body.emailEnabled === 'boolean') allowed.emailEnabled = body.emailEnabled;
  if ('emailSendHour' in body && typeof body.emailSendHour === 'number') allowed.emailSendHour = body.emailSendHour;

  if (Object.keys(allowed).length === 0) {
    return jsonResponse({ error: 'No valid fields to update' }, 400);
  }

  allowed.updatedAt = new Date();
  await db.update(user).set(allowed).where(eq(user.id, auth.user.id));

  const [updated] = await db.select({
    id: user.id,
    name: user.name,
    email: user.email,
    emailEnabled: user.emailEnabled,
    emailSendHour: user.emailSendHour,
  }).from(user).where(eq(user.id, auth.user.id));

  return jsonResponse(updated);
};
```

**Step 3: Allow API routes through hooks auth check**

In `src/hooks.server.ts`, the public paths list needs `/api/v1` added so the cookie-based redirect doesn't block bearer-token API calls:

```typescript
// In hooks.server.ts, find the public paths check and add /api/v1:
const publicPaths = ['/login', '/register', '/api/auth', '/api/unsubscribe', '/api/v1'];
```

**Step 4: Verify it builds**

Run: `cd /Users/yosephmaguire/repos/namah-nutrition-page && npm run check`
Expected: No type errors

**Step 5: Commit**

```bash
cd /Users/yosephmaguire/repos/namah-nutrition-page
git add src/routes/api/v1/cycle/+server.ts src/routes/api/v1/profile/+server.ts src/hooks.server.ts
git commit -m "feat(api): add /api/v1/cycle and /api/v1/profile endpoints"
```

---

## Task 5: Deploy and test API endpoints (Web)

**Step 1: Deploy to Cloudflare Pages**

```bash
cd /Users/yosephmaguire/repos/namah-nutrition-page
git push
```

Cloudflare Pages auto-deploys on push. Wait for deploy to complete.

**Step 2: Test auth helper with curl**

```bash
# Should return 401
curl -s https://namah.yosephmaguire.com/api/v1/content | jq .

# Log in to get a token (use your real credentials)
# The token comes from better-auth's sign-in response
```

**Step 3: Test content endpoint**

```bash
curl -s -H "Authorization: Bearer YOUR_TOKEN" https://namah.yosephmaguire.com/api/v1/content | jq 'keys'
# Expected: ["coreExercises","groceryItems","meals","phaseNutrients","phaseReminders","phases","supplementDefinitions","supplementNutrients","workoutSessions","workouts"]
```

**Step 4: Test sync endpoint**

```bash
curl -s -H "Authorization: Bearer YOUR_TOKEN" https://namah.yosephmaguire.com/api/v1/sync | jq 'keys'
# Expected: ["cycleLogs","dailyNotes","groceryChecks","mealCompletions","supplementLogs","symptomLogs","userSupplements","workoutCompletions"]
```

**Step 5: Test cycle endpoint**

```bash
curl -s -H "Authorization: Bearer YOUR_TOKEN" https://namah.yosephmaguire.com/api/v1/cycle | jq .
# Expected: { currentPhase: {...}, cycleStats: {...}, phaseRanges: {...} }
```

**Step 6: Commit any fixes if needed**

---

## Task 6: Add userId to iOS models

Add a `userId` field to the 9 user-data SwiftData models. The field defaults to empty string — it will be populated from the server response during sync.

**Files (all in namah-wellness-swiftui repo):**
- Modify: `NamahWellness/Models/CycleLog.swift`
- Modify: `NamahWellness/Models/Completion.swift` (MealCompletion, WorkoutCompletion, GroceryCheck)
- Modify: `NamahWellness/Models/SymptomLog.swift`
- Modify: `NamahWellness/Models/Supplement.swift` (UserSupplement, SupplementLog, SupplementDefinition)

**Step 1: Add userId to CycleLog**

In `NamahWellness/Models/CycleLog.swift`, add `var userId: String` after the `id` field:

```swift
@Model
final class CycleLog {
    @Attribute(.unique) var id: String
    var userId: String
    var periodStartDate: String
    var periodEndDate: String?
    var phaseOverride: String?
    var createdAt: Date

    init(
        id: String = UUID().uuidString,
        userId: String = "",
        periodStartDate: String,
        periodEndDate: String? = nil,
        phaseOverride: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.userId = userId
        self.periodStartDate = periodStartDate
        self.periodEndDate = periodEndDate
        self.phaseOverride = phaseOverride
        self.createdAt = createdAt
    }
}
```

**Step 2: Add userId to MealCompletion, WorkoutCompletion, GroceryCheck**

In `NamahWellness/Models/Completion.swift`:

```swift
@Model
final class MealCompletion {
    @Attribute(.unique) var id: String
    var userId: String
    var mealId: String
    var date: String
    var completedAt: Date

    init(id: String = UUID().uuidString, userId: String = "", mealId: String, date: String, completedAt: Date = Date()) {
        self.id = id
        self.userId = userId
        self.mealId = mealId
        self.date = date
        self.completedAt = completedAt
    }
}

@Model
final class WorkoutCompletion {
    @Attribute(.unique) var id: String
    var userId: String
    var workoutId: String
    var date: String
    var completedAt: Date

    init(id: String = UUID().uuidString, userId: String = "", workoutId: String, date: String, completedAt: Date = Date()) {
        self.id = id
        self.userId = userId
        self.workoutId = workoutId
        self.date = date
        self.completedAt = completedAt
    }
}

@Model
final class GroceryCheck {
    @Attribute(.unique) var id: String
    var userId: String
    var groceryItemId: String
    var checked: Bool
    var updatedAt: Date

    init(id: String = UUID().uuidString, userId: String = "", groceryItemId: String, checked: Bool = false, updatedAt: Date = Date()) {
        self.id = id
        self.userId = userId
        self.groceryItemId = groceryItemId
        self.checked = checked
        self.updatedAt = updatedAt
    }
}
```

**Step 3: Add userId to SymptomLog and DailyNote**

In `NamahWellness/Models/SymptomLog.swift`, add `var userId: String` after `id` in both models, with `userId: String = ""` in their inits.

**Step 4: Add userId to UserSupplement, SupplementLog, and createdByUserId to SupplementDefinition**

In `NamahWellness/Models/Supplement.swift`:
- Add `var createdByUserId: String?` to `SupplementDefinition` (after `isCustom`)
- Add `var userId: String` to `UserSupplement` (after `id`)
- Add `var userId: String` to `SupplementLog` (after `id`)

All with default `""` (or `nil` for the optional one) in their inits.

**Step 5: Build to verify**

```bash
xcodebuild -project NamahWellness.xcodeproj -scheme NamahWellness -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | tail -5
```
Expected: BUILD SUCCEEDED

**Step 6: Commit**

```bash
git add NamahWellness/Models/
git commit -m "feat(models): add userId field to 9 user-data SwiftData models"
```

---

## Task 7: Keychain helper and AuthService (iOS)

**Files:**
- Create: `NamahWellness/Services/KeychainHelper.swift`
- Create: `NamahWellness/Services/AuthService.swift`

**Step 1: Create Keychain helper**

```swift
// NamahWellness/Services/KeychainHelper.swift
import Foundation
import Security

enum KeychainHelper {
    static func save(_ data: Data, for key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrService as String: "com.namah.wellness",
        ]
        SecItemDelete(query as CFDictionary)

        var addQuery = query
        addQuery[kSecValueData as String] = data
        SecItemAdd(addQuery as CFDictionary, nil)
    }

    static func load(for key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrService as String: "com.namah.wellness",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        SecItemCopyMatching(query as CFDictionary, &result)
        return result as? Data
    }

    static func delete(for key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrService as String: "com.namah.wellness",
        ]
        SecItemDelete(query as CFDictionary)
    }

    static func saveString(_ value: String, for key: String) {
        guard let data = value.data(using: .utf8) else { return }
        save(data, for: key)
    }

    static func loadString(for key: String) -> String? {
        guard let data = load(for: key) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
```

**Step 2: Create AuthService**

```swift
// NamahWellness/Services/AuthService.swift
import Foundation

@Observable
final class AuthService {
    private(set) var isAuthenticated = false
    private(set) var userId: String?
    private(set) var userName: String?
    private(set) var userEmail: String?
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    var token: String? {
        KeychainHelper.loadString(for: "authToken")
    }

    init() {
        if let token = KeychainHelper.loadString(for: "authToken"), !token.isEmpty {
            isAuthenticated = true
            userId = KeychainHelper.loadString(for: "userId")
            userName = KeychainHelper.loadString(for: "userName")
            userEmail = KeychainHelper.loadString(for: "userEmail")
        }
    }

    @MainActor
    func signIn(email: String, password: String) async {
        isLoading = true
        errorMessage = nil

        do {
            let url = URL(string: "https://namah.yosephmaguire.com/api/auth/sign-in/email")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(["email": email, "password": password])

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                errorMessage = "Invalid response"
                isLoading = false
                return
            }

            if httpResponse.statusCode == 200 {
                let result = try JSONDecoder().decode(SignInResponse.self, from: data)
                KeychainHelper.saveString(result.token, for: "authToken")
                KeychainHelper.saveString(result.user.id, for: "userId")
                KeychainHelper.saveString(result.user.name, for: "userName")
                KeychainHelper.saveString(result.user.email, for: "userEmail")
                userId = result.user.id
                userName = result.user.name
                userEmail = result.user.email
                isAuthenticated = true
            } else {
                let body = try? JSONDecoder().decode(ErrorResponse.self, from: data)
                errorMessage = body?.message ?? "Sign in failed"
            }
        } catch {
            errorMessage = "Network error: \(error.localizedDescription)"
        }

        isLoading = false
    }

    func signOut() {
        KeychainHelper.delete(for: "authToken")
        KeychainHelper.delete(for: "userId")
        KeychainHelper.delete(for: "userName")
        KeychainHelper.delete(for: "userEmail")
        userId = nil
        userName = nil
        userEmail = nil
        isAuthenticated = false
    }

    func handleUnauthorized() {
        signOut()
    }
}

private struct SignInResponse: Decodable {
    let token: String
    let user: SignInUser
}

private struct SignInUser: Decodable {
    let id: String
    let name: String
    let email: String
}

private struct ErrorResponse: Decodable {
    let message: String?
}
```

**Step 3: Add files to project.yml if needed, then build**

```bash
xcodebuild -project NamahWellness.xcodeproj -scheme NamahWellness -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | tail -5
```
Expected: BUILD SUCCEEDED

**Step 4: Commit**

```bash
git add NamahWellness/Services/KeychainHelper.swift NamahWellness/Services/AuthService.swift
git commit -m "feat(auth): add KeychainHelper and AuthService for email/password login"
```

---

## Task 8: APIClient (iOS)

Generic HTTP client used by SyncService. Handles JSON encoding/decoding and auth headers.

**Files:**
- Create: `NamahWellness/Services/APIClient.swift`

**Step 1: Create APIClient**

```swift
// NamahWellness/Services/APIClient.swift
import Foundation

enum APIError: Error, LocalizedError {
    case unauthorized
    case networkError(Error)
    case serverError(Int, String?)
    case decodingError(Error)

    var errorDescription: String? {
        switch self {
        case .unauthorized: return "Session expired. Please sign in again."
        case .networkError(let e): return "Network error: \(e.localizedDescription)"
        case .serverError(let code, let msg): return msg ?? "Server error (\(code))"
        case .decodingError(let e): return "Data error: \(e.localizedDescription)"
        }
    }
}

final class APIClient {
    static let shared = APIClient()

    private let baseURL = "https://namah.yosephmaguire.com"
    private let session = URLSession.shared
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()
    private let encoder = JSONEncoder()

    private init() {}

    func get<T: Decodable>(path: String) async throws -> T {
        let request = try makeRequest(path: path, method: "GET")
        return try await perform(request)
    }

    func post<T: Decodable>(path: String, body: some Encodable) async throws -> T {
        var request = try makeRequest(path: path, method: "POST")
        request.httpBody = try encoder.encode(body)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        return try await perform(request)
    }

    func patch<T: Decodable>(path: String, body: some Encodable) async throws -> T {
        var request = try makeRequest(path: path, method: "PATCH")
        request.httpBody = try encoder.encode(body)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        return try await perform(request)
    }

    private func makeRequest(path: String, method: String) throws -> URLRequest {
        guard let url = URL(string: baseURL + path) else {
            throw APIError.networkError(URLError(.badURL))
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        if let token = KeychainHelper.loadString(for: "authToken") {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        return request
    }

    private func perform<T: Decodable>(_ request: URLRequest) async throws -> T {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw APIError.networkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.networkError(URLError(.badServerResponse))
        }

        if httpResponse.statusCode == 401 {
            throw APIError.unauthorized
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let body = String(data: data, encoding: .utf8)
            throw APIError.serverError(httpResponse.statusCode, body)
        }

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decodingError(error)
        }
    }
}
```

**Step 2: Build**

```bash
xcodebuild -project NamahWellness.xcodeproj -scheme NamahWellness -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | tail -5
```
Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add NamahWellness/Services/APIClient.swift
git commit -m "feat(network): add APIClient with bearer auth and JSON handling"
```

---

## Task 9: SyncChange model and SyncService (iOS)

The SyncService orchestrates pulling data from the server into SwiftData and pushing local changes.

**Files:**
- Create: `NamahWellness/Models/SyncChange.swift`
- Create: `NamahWellness/Services/SyncService.swift`
- Modify: `NamahWellness/App/NamahWellnessApp.swift` — add SyncChange to schema

**Step 1: Create SyncChange model**

```swift
// NamahWellness/Models/SyncChange.swift
import Foundation
import SwiftData

@Model
final class SyncChange {
    @Attribute(.unique) var id: String
    var tableName: String
    var action: String    // "upsert" or "delete"
    var payload: String   // JSON string
    var createdAt: Date

    init(
        id: String = UUID().uuidString,
        tableName: String,
        action: String,
        payload: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.tableName = tableName
        self.action = action
        self.payload = payload
        self.createdAt = createdAt
    }
}
```

**Step 2: Add SyncChange to model container in NamahWellnessApp.swift**

Add `SyncChange.self` to the schema array (after `UserProfile.self`).

**Step 3: Create SyncService**

```swift
// NamahWellness/Services/SyncService.swift
import Foundation
import SwiftData
import Network

enum SyncState: Equatable {
    case idle
    case syncing
    case error(String)
}

@Observable
final class SyncService {
    private(set) var syncState: SyncState = .idle
    private(set) var lastSyncDate: Date?

    private let apiClient = APIClient.shared
    private var modelContext: ModelContext?
    private let monitor = NWPathMonitor()
    private var isOnline = true

    func configure(modelContext: ModelContext) {
        self.modelContext = modelContext

        monitor.pathUpdateHandler = { [weak self] path in
            let wasOffline = !(self?.isOnline ?? true)
            self?.isOnline = path.status == .satisfied
            if wasOffline && path.status == .satisfied {
                Task { await self?.sync() }
            }
        }
        monitor.start(queue: DispatchQueue(label: "com.namah.network"))
    }

    @MainActor
    func sync() async {
        guard let modelContext, isOnline else { return }
        guard syncState != .syncing else { return }

        syncState = .syncing

        do {
            // 1. Push pending changes
            try await pushChanges(modelContext: modelContext)

            // 2. Pull content
            let content: ContentResponse = try await apiClient.get(path: "/api/v1/content")
            try upsertContent(content, modelContext: modelContext)

            // 3. Pull user data
            let userData: UserDataResponse = try await apiClient.get(path: "/api/v1/sync")
            try upsertUserData(userData, modelContext: modelContext)

            // 4. Pull cycle state
            let cycle: CycleBundleResponse = try await apiClient.get(path: "/api/v1/cycle")
            // CycleService will be updated by the caller after sync

            try modelContext.save()
            lastSyncDate = Date()
            syncState = .idle
        } catch let error as APIError where error == .unauthorized {
            syncState = .error("Session expired")
        } catch {
            syncState = .error(error.localizedDescription)
        }
    }

    func queueChange(table: String, action: String, data: some Encodable, modelContext: ModelContext) {
        guard let json = try? JSONEncoder().encode(data),
              let jsonString = String(data: json, encoding: .utf8) else { return }
        let change = SyncChange(tableName: table, action: action, payload: jsonString)
        modelContext.insert(change)
    }

    // MARK: - Push

    private func pushChanges(modelContext: ModelContext) async throws {
        let descriptor = FetchDescriptor<SyncChange>(sortBy: [SortDescriptor(\.createdAt)])
        let pending = try modelContext.fetch(descriptor)
        guard !pending.isEmpty else { return }

        struct ChangePayload: Encodable {
            let table: String
            let action: String
            let data: [String: AnyCodable]
        }

        struct SyncRequest: Encodable {
            let changes: [ChangePayload]
        }

        let changes: [ChangePayload] = pending.compactMap { change in
            guard let data = change.payload.data(using: .utf8),
                  let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
            return ChangePayload(
                table: change.tableName,
                action: change.action,
                data: dict.mapValues { AnyCodable($0) }
            )
        }

        let _: UserDataResponse = try await apiClient.post(
            path: "/api/v1/sync",
            body: SyncRequest(changes: changes)
        )

        // Clear pushed changes
        for change in pending {
            modelContext.delete(change)
        }
    }

    // MARK: - Pull Content

    private func upsertContent(_ content: ContentResponse, modelContext: ModelContext) throws {
        // Delete all existing content and replace with server data
        try modelContext.delete(model: Phase.self)
        try modelContext.delete(model: Meal.self)
        try modelContext.delete(model: GroceryItem.self)
        try modelContext.delete(model: Workout.self)
        try modelContext.delete(model: WorkoutSession.self)
        try modelContext.delete(model: CoreExercise.self)
        try modelContext.delete(model: PhaseReminder.self)
        try modelContext.delete(model: PhaseNutrient.self)
        try modelContext.delete(model: SupplementDefinition.self)
        try modelContext.delete(model: SupplementNutrient.self)

        for p in content.phases { modelContext.insert(p.toModel()) }
        for m in content.meals { modelContext.insert(m.toModel()) }
        for g in content.groceryItems { modelContext.insert(g.toModel()) }
        for w in content.workouts { modelContext.insert(w.toModel()) }
        for s in content.workoutSessions { modelContext.insert(s.toModel()) }
        for e in content.coreExercises { modelContext.insert(e.toModel()) }
        for r in content.phaseReminders { modelContext.insert(r.toModel()) }
        for n in content.phaseNutrients { modelContext.insert(n.toModel()) }
        for d in content.supplementDefinitions { modelContext.insert(d.toModel()) }
        for n in content.supplementNutrients { modelContext.insert(n.toModel()) }
    }

    // MARK: - Pull User Data

    private func upsertUserData(_ data: UserDataResponse, modelContext: ModelContext) throws {
        try modelContext.delete(model: CycleLog.self)
        try modelContext.delete(model: MealCompletion.self)
        try modelContext.delete(model: WorkoutCompletion.self)
        try modelContext.delete(model: SymptomLog.self)
        try modelContext.delete(model: DailyNote.self)
        try modelContext.delete(model: GroceryCheck.self)
        try modelContext.delete(model: UserSupplement.self)
        try modelContext.delete(model: SupplementLog.self)

        for l in data.cycleLogs { modelContext.insert(l.toModel()) }
        for m in data.mealCompletions { modelContext.insert(m.toModel()) }
        for w in data.workoutCompletions { modelContext.insert(w.toModel()) }
        for s in data.symptomLogs { modelContext.insert(s.toModel()) }
        for n in data.dailyNotes { modelContext.insert(n.toModel()) }
        for c in data.groceryChecks { modelContext.insert(c.toModel()) }
        for u in data.userSupplements { modelContext.insert(u.toModel()) }
        for l in data.supplementLogs { modelContext.insert(l.toModel()) }
    }
}

// MARK: - AnyCodable helper for JSON serialization

struct AnyCodable: Encodable {
    let value: Any

    init(_ value: Any) { self.value = value }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value {
        case let v as String: try container.encode(v)
        case let v as Int: try container.encode(v)
        case let v as Double: try container.encode(v)
        case let v as Bool: try container.encode(v)
        case is NSNull: try container.encodeNil()
        default: try container.encode(String(describing: value))
        }
    }
}
```

**Note:** The `ContentResponse`, `UserDataResponse`, `CycleBundleResponse` types and their `.toModel()` converters are created in Task 10.

**Step 4: Build** (will have errors until Task 10 — that's OK)

**Step 5: Commit**

```bash
git add NamahWellness/Models/SyncChange.swift NamahWellness/Services/SyncService.swift NamahWellness/App/NamahWellnessApp.swift
git commit -m "feat(sync): add SyncChange model and SyncService with push/pull"
```

---

## Task 10: API response types and model converters (iOS)

Decodable structs that map server JSON to SwiftData models.

**Files:**
- Create: `NamahWellness/Services/APITypes.swift`

**Step 1: Create API response types**

This file contains all the `Decodable` structs for JSON responses and `.toModel()` methods that convert them to SwiftData `@Model` objects. Each response struct mirrors the server's JSON shape. Each has a `toModel()` that creates the corresponding SwiftData model.

```swift
// NamahWellness/Services/APITypes.swift
import Foundation

// MARK: - Content Response

struct ContentResponse: Decodable {
    let phases: [PhaseDTO]
    let meals: [MealDTO]
    let groceryItems: [GroceryItemDTO]
    let workouts: [WorkoutDTO]
    let workoutSessions: [WorkoutSessionDTO]
    let coreExercises: [CoreExerciseDTO]
    let phaseReminders: [PhaseReminderDTO]
    let phaseNutrients: [PhaseNutrientDTO]
    let supplementDefinitions: [SupplementDefinitionDTO]
    let supplementNutrients: [SupplementNutrientDTO]
}

// MARK: - User Data Response

struct UserDataResponse: Decodable {
    let cycleLogs: [CycleLogDTO]
    let mealCompletions: [MealCompletionDTO]
    let workoutCompletions: [WorkoutCompletionDTO]
    let symptomLogs: [SymptomLogDTO]
    let dailyNotes: [DailyNoteDTO]
    let groceryChecks: [GroceryCheckDTO]
    let userSupplements: [UserSupplementDTO]
    let supplementLogs: [SupplementLogDTO]
}

// MARK: - Cycle Bundle Response

struct CycleBundleResponse: Decodable {
    let currentPhase: PhaseInfoDTO?
    let cycleStats: CycleStatsDTO
    let phaseRanges: PhaseRangesDTO
}

struct PhaseInfoDTO: Decodable {
    let phaseName: String
    let phaseSlug: String
    let cycleDay: Int
    let dayInPhase: Int
    let periodStartDate: String
    let isOverridden: Bool
    let color: String
    let colorSoft: String

    func toPhaseInfo() -> PhaseInfo {
        PhaseInfo(phaseName: phaseName, phaseSlug: phaseSlug, cycleDay: cycleDay,
                  dayInPhase: dayInPhase, periodStartDate: periodStartDate,
                  isOverridden: isOverridden, color: color, colorSoft: colorSoft)
    }
}

struct CycleStatsDTO: Decodable {
    let avgCycleLength: Int
    let avgPeriodLength: Int
    let cycleCount: Int

    func toCycleStats() -> CycleStats {
        CycleStats(avgCycleLength: avgCycleLength, avgPeriodLength: avgPeriodLength, cycleCount: cycleCount)
    }
}

struct PhaseRangeDTO: Decodable {
    let start: Int
    let end: Int

    func toPhaseRange() -> PhaseRange {
        PhaseRange(start: start, end: end)
    }
}

struct PhaseRangesDTO: Decodable {
    let menstrual: PhaseRangeDTO
    let follicular: PhaseRangeDTO
    let ovulatory: PhaseRangeDTO
    let luteal: PhaseRangeDTO

    func toPhaseRanges() -> PhaseRanges {
        PhaseRanges(menstrual: menstrual.toPhaseRange(), follicular: follicular.toPhaseRange(),
                    ovulatory: ovulatory.toPhaseRange(), luteal: luteal.toPhaseRange())
    }
}

// MARK: - Content DTOs

struct PhaseDTO: Decodable {
    let id: String; let name: String; let slug: String
    let dayStart: Int; let dayEnd: Int
    let calorieTarget: String?; let proteinTarget: String?
    let fatTarget: String?; let carbTarget: String?
    let heroEyebrow: String; let heroTitle: String; let heroSubtitle: String
    let description: String; let exerciseIntensity: String; let saNote: String
    let color: String; let colorSoft: String; let colorMid: String

    func toModel() -> Phase {
        Phase(id: id, name: name, slug: slug, dayStart: dayStart, dayEnd: dayEnd,
              calorieTarget: calorieTarget, proteinTarget: proteinTarget,
              fatTarget: fatTarget, carbTarget: carbTarget,
              heroEyebrow: heroEyebrow, heroTitle: heroTitle, heroSubtitle: heroSubtitle,
              phaseDescription: description, exerciseIntensity: exerciseIntensity, saNote: saNote,
              color: color, colorSoft: colorSoft, colorMid: colorMid)
    }
}

struct MealDTO: Decodable {
    let id: String; let phaseId: String; let dayNumber: Int; let dayLabel: String
    let dayCalories: String?; let mealType: String; let time: String
    let calories: String; let title: String; let description: String
    let saNote: String?; let proteinG: Int?; let carbsG: Int?; let fatG: Int?

    func toModel() -> Meal {
        Meal(id: id, phaseId: phaseId, dayNumber: dayNumber, dayLabel: dayLabel,
             dayCalories: dayCalories, mealType: mealType, time: time,
             calories: calories, title: title, mealDescription: description,
             saNote: saNote, proteinG: proteinG, carbsG: carbsG, fatG: fatG)
    }
}

struct GroceryItemDTO: Decodable {
    let id: String; let phaseId: String; let category: String; let name: String; let saFlag: String?

    func toModel() -> GroceryItem {
        GroceryItem(id: id, phaseId: phaseId, category: category, name: name, saFlag: saFlag)
    }
}

struct WorkoutDTO: Decodable {
    let id: String; let dayOfWeek: Int; let dayLabel: String; let dayFocus: String; let isRestDay: Bool

    func toModel() -> Workout {
        Workout(id: id, dayOfWeek: dayOfWeek, dayLabel: dayLabel, dayFocus: dayFocus, isRestDay: isRestDay)
    }
}

struct WorkoutSessionDTO: Decodable {
    let id: String; let workoutId: String; let timeSlot: String; let title: String; let description: String

    func toModel() -> WorkoutSession {
        WorkoutSession(id: id, workoutId: workoutId, timeSlot: timeSlot, title: title, sessionDescription: description)
    }
}

struct CoreExerciseDTO: Decodable {
    let id: String; let name: String; let description: String; let sets: String

    func toModel() -> CoreExercise {
        CoreExercise(id: id, name: name, exerciseDescription: description, sets: sets)
    }
}

struct PhaseReminderDTO: Decodable {
    let id: String; let phaseId: String; let icon: String; let text: String; let evidenceLevel: String?

    func toModel() -> PhaseReminder {
        PhaseReminder(id: id, phaseId: phaseId, icon: icon, text: text, evidenceLevel: evidenceLevel)
    }
}

struct PhaseNutrientDTO: Decodable {
    let id: String; let phaseId: String; let icon: String; let label: String

    func toModel() -> PhaseNutrient {
        PhaseNutrient(id: id, phaseId: phaseId, icon: icon, label: label)
    }
}

struct SupplementDefinitionDTO: Decodable {
    let id: String; let name: String; let brand: String?; let category: String
    let servingSize: Int; let servingUnit: String; let isCustom: Bool
    let createdByUserId: String?; let notes: String?

    func toModel() -> SupplementDefinition {
        SupplementDefinition(id: id, name: name, brand: brand, category: category,
                             servingSize: servingSize, servingUnit: servingUnit,
                             isCustom: isCustom, notes: notes)
    }
}

struct SupplementNutrientDTO: Decodable {
    let id: String; let supplementId: String; let nutrientKey: String; let amount: Double; let unit: String

    func toModel() -> SupplementNutrient {
        SupplementNutrient(id: id, supplementId: supplementId, nutrientKey: nutrientKey, amount: amount, unit: unit)
    }
}

// MARK: - User Data DTOs

struct CycleLogDTO: Decodable {
    let id: String; let userId: String; let periodStartDate: String
    let periodEndDate: String?; let phaseOverride: String?; let createdAt: String?

    func toModel() -> CycleLog {
        CycleLog(id: id, userId: userId, periodStartDate: periodStartDate,
                 periodEndDate: periodEndDate, phaseOverride: phaseOverride)
    }
}

struct MealCompletionDTO: Decodable {
    let id: String; let userId: String; let mealId: String; let date: String; let completedAt: String?

    func toModel() -> MealCompletion {
        MealCompletion(id: id, userId: userId, mealId: mealId, date: date)
    }
}

struct WorkoutCompletionDTO: Decodable {
    let id: String; let userId: String; let workoutId: String; let date: String; let completedAt: String?

    func toModel() -> WorkoutCompletion {
        WorkoutCompletion(id: id, userId: userId, workoutId: workoutId, date: date)
    }
}

struct SymptomLogDTO: Decodable {
    let id: String; let userId: String; let date: String
    let mood: Int?; let energy: Int?; let cramps: Int?; let bloating: Int?
    let fatigue: Int?; let acne: Int?; let headache: Int?; let breastTenderness: Int?
    let sleepQuality: Int?; let anxiety: Int?; let irritability: Int?
    let libido: Int?; let appetite: Int?; let flowIntensity: String?

    func toModel() -> SymptomLog {
        SymptomLog(id: id, date: date, mood: mood, energy: energy, cramps: cramps,
                   bloating: bloating, fatigue: fatigue, acne: acne, headache: headache,
                   breastTenderness: breastTenderness, sleepQuality: sleepQuality,
                   anxiety: anxiety, irritability: irritability, libido: libido,
                   appetite: appetite, flowIntensity: flowIntensity)
    }
}

struct DailyNoteDTO: Decodable {
    let id: String; let userId: String; let date: String; let content: String; let updatedAt: String?

    func toModel() -> DailyNote {
        DailyNote(id: id, date: date, content: content)
    }
}

struct GroceryCheckDTO: Decodable {
    let id: String; let userId: String; let groceryItemId: String; let checked: Bool; let updatedAt: String?

    func toModel() -> GroceryCheck {
        GroceryCheck(id: id, userId: userId, groceryItemId: groceryItemId, checked: checked)
    }
}

struct UserSupplementDTO: Decodable {
    let id: String; let userId: String; let supplementId: String
    let dosage: Double; let frequency: String; let timeOfDay: String
    let isActive: Bool; let startedAt: String?

    func toModel() -> UserSupplement {
        UserSupplement(id: id, userId: userId, supplementId: supplementId,
                       dosage: dosage, frequency: frequency, timeOfDay: timeOfDay, isActive: isActive)
    }
}

struct SupplementLogDTO: Decodable {
    let id: String; let userId: String; let userSupplementId: String
    let date: String; let taken: Bool; let loggedAt: String?

    func toModel() -> SupplementLog {
        SupplementLog(id: id, userId: userId, userSupplementId: userSupplementId, date: date, taken: taken)
    }
}
```

**Step 2: Build**

```bash
xcodebuild -project NamahWellness.xcodeproj -scheme NamahWellness -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | tail -5
```
Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add NamahWellness/Services/APITypes.swift
git commit -m "feat(sync): add API response types and DTO-to-model converters"
```

---

## Task 11: LoginView (iOS)

**Files:**
- Create: `NamahWellness/Views/Auth/LoginView.swift`

**Step 1: Create LoginView**

```swift
// NamahWellness/Views/Auth/LoginView.swift
import SwiftUI

struct LoginView: View {
    let authService: AuthService

    @State private var email = ""
    @State private var password = ""

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            VStack(spacing: 8) {
                Text("Namah")
                    .font(.heading(40))
                    .foregroundStyle(.primary)
                Text("Wellness, in rhythm")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 12) {
                TextField("Email", text: $email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .padding(14)
                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                SecureField("Password", text: $password)
                    .textContentType(.password)
                    .padding(14)
                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            if let error = authService.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            Button {
                Task {
                    await authService.signIn(email: email, password: password)
                }
            } label: {
                if authService.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(14)
                } else {
                    Text("Sign In")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(14)
                }
            }
            .foregroundStyle(.white)
            .background(email.isEmpty || password.isEmpty ? Color.secondary : Color.primary)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .disabled(email.isEmpty || password.isEmpty || authService.isLoading)

            Spacer()
            Spacer()
        }
        .padding(24)
        .background(Color(uiColor: .systemGroupedBackground))
    }
}
```

**Step 2: Build**

```bash
xcodebuild -project NamahWellness.xcodeproj -scheme NamahWellness -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | tail -5
```
Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add NamahWellness/Views/Auth/LoginView.swift
git commit -m "feat(auth): add LoginView with email/password form"
```

---

## Task 12: Wire up ContentView with auth gate and sync (iOS)

Update the app entry points to gate on authentication and trigger sync.

**Files:**
- Modify: `NamahWellness/App/ContentView.swift`
- Modify: `NamahWellness/App/NamahWellnessApp.swift`

**Step 1: Update NamahWellnessApp to create services**

```swift
// NamahWellness/App/NamahWellnessApp.swift
import SwiftUI
import SwiftData

@main
struct NamahWellnessApp: App {
    let modelContainer: ModelContainer
    @State private var authService = AuthService()
    @State private var syncService = SyncService()

    init() {
        do {
            let schema = Schema([
                Phase.self,
                Meal.self,
                GroceryItem.self,
                Workout.self,
                WorkoutSession.self,
                CoreExercise.self,
                PhaseReminder.self,
                PhaseNutrient.self,
                CycleLog.self,
                MealCompletion.self,
                WorkoutCompletion.self,
                GroceryCheck.self,
                SymptomLog.self,
                DailyNote.self,
                SupplementDefinition.self,
                SupplementNutrient.self,
                UserSupplement.self,
                SupplementLog.self,
                UserProfile.self,
                SyncChange.self,
            ])
            modelContainer = try ModelContainer(for: schema)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView(authService: authService, syncService: syncService)
        }
        .modelContainer(modelContainer)
    }
}
```

**Step 2: Update ContentView**

```swift
// NamahWellness/App/ContentView.swift
import SwiftUI
import SwiftData

struct ContentView: View {
    let authService: AuthService
    let syncService: SyncService

    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \CycleLog.createdAt, order: .reverse) private var cycleLogs: [CycleLog]
    @Query private var phases: [Phase]

    @State private var cycleService = CycleService()
    @State private var selectedTab = 0
    @State private var hasInitialSync = false

    var body: some View {
        Group {
            if authService.isAuthenticated {
                TabView(selection: $selectedTab) {
                    TodayView(cycleService: cycleService)
                        .tabItem {
                            Image(systemName: "sun.max")
                            Text("Today")
                        }
                        .tag(0)

                    MyCycleView(cycleService: cycleService)
                        .tabItem {
                            Image(systemName: "circle.dotted.circle")
                            Text("My Cycle")
                        }
                        .tag(1)

                    PlanView(cycleService: cycleService)
                        .tabItem {
                            Image(systemName: "list.bullet.rectangle")
                            Text("Plan")
                        }
                        .tag(2)

                    LearnView(cycleService: cycleService)
                        .tabItem {
                            Image(systemName: "book")
                            Text("Learn")
                        }
                        .tag(3)
                }
                .onAppear {
                    syncService.configure(modelContext: modelContext)
                    recalculate()
                    if !hasInitialSync {
                        hasInitialSync = true
                        Task { await syncService.sync(); recalculate() }
                    }
                }
                .onChange(of: cycleLogs.count) { recalculate() }
                .onChange(of: scenePhase) {
                    if scenePhase == .active {
                        Task { await syncService.sync(); recalculate() }
                    }
                }
            } else {
                LoginView(authService: authService)
            }
        }
    }

    private func recalculate() {
        cycleService.recalculate(logs: cycleLogs, phases: phases)
    }
}
```

**Step 3: Build**

```bash
xcodebuild -project NamahWellness.xcodeproj -scheme NamahWellness -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | tail -5
```
Expected: BUILD SUCCEEDED

**Step 4: Commit**

```bash
git add NamahWellness/App/ContentView.swift NamahWellness/App/NamahWellnessApp.swift
git commit -m "feat: wire auth gate and sync into app entry points"
```

---

## Task 13: Remove SeedService and migration code (iOS)

**Files:**
- Delete: `NamahWellness/Services/SeedService.swift`
- Modify: `NamahWellness/App/ContentView.swift` — remove seedIfNeeded and migration calls (already done in Task 12)

**Step 1: Delete SeedService**

```bash
rm NamahWellness/Services/SeedService.swift
```

**Step 2: Regenerate Xcode project** (XCGen)

```bash
xcodegen generate
```

**Step 3: Build**

```bash
xcodebuild -project NamahWellness.xcodeproj -scheme NamahWellness -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | tail -5
```
Expected: BUILD SUCCEEDED

**Step 4: Commit**

```bash
git add -A
git commit -m "chore: remove SeedService — data now fetched from API"
```

---

## Task 14: Add queueChange calls to user actions (iOS)

Wire up the existing action functions to queue sync changes when users toggle meals, log symptoms, etc.

**Files:**
- Modify: `NamahWellness/Views/Today/TodayView.swift` — toggleMeal, toggleSupplement, toggleExtraSupplement
- Modify: `NamahWellness/Views/Today/TodayView.swift` — SymptomsTabView actions
- Modify: `NamahWellness/Views/MyCycle/MyCycleView.swift` — cycle log actions
- Modify: `NamahWellness/Views/Plan/PlanView.swift` — grocery check actions

**Approach:** Each view needs access to a `SyncService` instance. Pass it down from ContentView, or access it from the environment. The simplest approach: add `SyncService` to the environment.

**Step 1: Make SyncService available via environment**

In `NamahWellness/App/ContentView.swift`, add `.environment(syncService)` to the TabView. Each child view that performs user actions adds `@Environment(SyncService.self) private var syncService`.

**Step 2: Update toggleMeal in TodayView**

After the existing SwiftData write, add:
```swift
private func toggleMeal(_ meal: Meal) {
    if let existing = mealCompletions.first(where: { $0.mealId == meal.id && $0.date == today }) {
        modelContext.delete(existing)
        syncService.queueChange(table: "mealCompletions", action: "delete",
                                data: ["id": existing.id], modelContext: modelContext)
    } else {
        let completion = MealCompletion(mealId: meal.id, date: today)
        modelContext.insert(completion)
        syncService.queueChange(table: "mealCompletions", action: "upsert",
                                data: ["id": completion.id, "mealId": meal.id, "date": today],
                                modelContext: modelContext)
    }
}
```

Apply the same pattern to all other action functions: `toggleSupplement`, `toggleExtraSupplement`, symptom saves, cycle log inserts, grocery check toggles.

**Step 3: Build and test**

```bash
xcodebuild -project NamahWellness.xcodeproj -scheme NamahWellness -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | tail -5
```
Expected: BUILD SUCCEEDED

**Step 4: Commit**

```bash
git add NamahWellness/Views/ NamahWellness/App/ContentView.swift
git commit -m "feat(sync): queue local changes for background sync to server"
```

---

## Task 15: Add sign-out to ProfileView (iOS)

**Files:**
- Modify: `NamahWellness/Views/Profile/ProfileView.swift`

**Step 1: Add sign-out button to ProfileView**

Add `@Environment(AuthService.self) private var authService` and a sign-out button at the bottom of the ScrollView content:

```swift
Button(role: .destructive) {
    authService.signOut()
} label: {
    HStack {
        Image(systemName: "rectangle.portrait.and.arrow.right")
        Text("Sign Out")
    }
    .frame(maxWidth: .infinity)
    .padding(14)
}
.buttonStyle(.bordered)
.tint(.red)
```

**Step 2: Build**

```bash
xcodebuild -project NamahWellness.xcodeproj -scheme NamahWellness -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | tail -5
```
Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add NamahWellness/Views/Profile/ProfileView.swift
git commit -m "feat(auth): add sign-out button to ProfileView"
```

---

## Summary

| Task | Repo | What |
|------|------|------|
| 1 | Web | Auth helper for bearer tokens |
| 2 | Web | `/api/v1/content` — bulk content fetch |
| 3 | Web | `/api/v1/sync` — user data push/pull |
| 4 | Web | `/api/v1/cycle` + `/api/v1/profile` |
| 5 | Web | Deploy and test endpoints |
| 6 | iOS | Add userId to 9 models |
| 7 | iOS | KeychainHelper + AuthService |
| 8 | iOS | APIClient |
| 9 | iOS | SyncChange model + SyncService |
| 10 | iOS | API response types + DTO converters |
| 11 | iOS | LoginView |
| 12 | iOS | Wire auth gate + sync into ContentView |
| 13 | iOS | Remove SeedService |
| 14 | iOS | Queue changes in action functions |
| 15 | iOS | Sign-out button in ProfileView |
