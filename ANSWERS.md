# Funngro - Mobile Engineering Assessment

Code:
- State management: **Bloc** (`flutter_bloc` + `bloc_concurrency`). Each feature has `bloc/` (events, immutable state, bloc) and a screen that only draws state and sends events.
- Part 1 rewrite: `lib/earnings/bloc/earnings_bloc.dart` + `lib/earnings/earnings_screen.dart`. `earnings_fakes.dart` holds stand-ins for `api`, `Earning`, `EarningTile`, and so on, so it runs on its own.
- Part 2: `lib/projects/bloc/projects_bloc.dart` + `lib/projects/projects_screen.dart` (the API is unchanged, in `projects_api.dart`). Unit tests: `test/projects_bloc_test.dart`.
- Run with `flutter pub get && flutter run`. Measure performance in `--profile` mode.

---

## Part 1 - Code review: Earnings screen

### 1.1 Problems, worst first

**1. Network call and stream subscription inside `build()` cause an endless request loop and growing subscriptions. (Crash, battery, data, backend load)**
- **What the user sees:** The phone heats up and mobile data drains while the screen is open. Earnings flicker, new earnings show up 2, 5 or 20 times, and the app eventually freezes or is killed.
- **Why:** `build()` is meant to be a pure description of the UI. Flutter calls it whenever the widget is marked dirty: after any `setState`, a parent rebuild, a `MediaQuery` change (keyboard, rotation) or a route transition. Here `build` calls `fetchEarnings`, and the `.then` calls `setState`. That marks the element dirty, so the next frame calls `build` again, which fetches again. The loop runs once per network round-trip for as long as the screen is open. On top of that, every `build` calls `walletUpdates().listen(...)` again and never cancels, so the number of subscriptions grows by one per build. One wallet event is then inserted N times and triggers N `setState`s, and each of those causes another rebuild, fetch and subscription. If `walletUpdates` returns the same single-subscription stream, the second `listen` throws `StateError: Stream has already been listened to`, which is an immediate crash. Either way it fails. At hundreds of thousands of daily users, this loop is also a self-inflicted DDoS on our backend.
- **Fix:** Start the fetch and the subscription once, in `initState` (or in an async_redux action dispatched on init). Keep the `StreamSubscription` and cancel it in `dispose`. `build()` should have no side effects.

**2. The whole 3,000-item list is built eagerly, with about 3 ms of formatting per row, which freezes the UI thread for roughly 9 seconds or more and triggers ANRs. (Jank, ANR)**
- **What the user sees:** The screen freezes on open, and again on every wallet update or tap. Android shows "App isn't responding" and the user force-closes.
- **Why:** `SingleChildScrollView` + `Column` is not lazy. `Column` builds, lays out and keeps in memory every child, so all 3,000 `EarningTile`s are built even though only about 10 fit on screen. Each one calls `formatCurrency` (about 3 ms because it re-parses locale data), and 3,000 × 3 ms is about 9 s of synchronous work on the UI thread per build. That's on a fast phone, and it's worse on an ₹8,000 one. The frame budget is 16 ms, and Android raises an ANR after about 5 s without responding to input. Because of bug 1 and the `setState` calls in `onTap` and the wallet listener, this cost is paid again on every rebuild. Memory for 3,000 element and render objects also adds GC pressure on low-RAM devices.
- **Fix:** Use `ListView.builder`, which builds only the visible rows plus the cache extent. Create the `NumberFormat` once and reuse it, so formatting takes microseconds instead of milliseconds. If `formatCurrency` itself can't change, memoize its output per item, computed lazily rather than for all 3,000 up front. Optionally set `itemExtent`/`prototypeItem` if the tile height is fixed, which makes scroll layout cheaper still.

**3. No `dispose` leads to leaks and to `setState()` being called after dispose, including use of a dead `BuildContext`. (Crashes, error noise, memory)**
- **What the user sees:** Memory use creeps up each time the screen is opened. There are random errors after leaving the screen, and occasionally a detail screen pushes after the user has already gone back.
- **Why:** The wallet subscriptions are never cancelled. The stream keeps the `State` alive, along with its 3,000-item list. That's a leak, and it compounds because this is one of the most-visited screens. Every later event, plus any pending `fetchEarnings().then`, calls `setState` on a disposed State, which throws "setState() called after dispose()". In `onTap`, after `await api.fetchDetail` the widget may be gone, and then both `setState` and `Navigator.push(context, ...)` run on an unmounted element ("Looking up a deactivated widget's ancestor is unsafe").
- **Fix:** Cancel the subscription in `dispose()`. After every `await`, check `if (!mounted) return;` before calling `setState` or using `context`.

**4. Missing loading, error and empty states. (Trust: support tickets saying "my money disappeared")**
- **What the user sees:** `loading` starts as `false`, so the first frame shows an empty list. A teenager sees no earnings and assumes their money is gone. If the fetch fails there's no `catchError`, so the screen stays blank forever with no retry, and the failure surfaces as an uncaught async error. A real "no earnings yet" user sees exactly the same blank screen.
- **Why:** There's no initial `loading = true` and no error branch, and an empty result isn't treated as its own state.
- **Fix:** Use an explicit status (`loading`, `error`, `loaded`). Show a spinner first, an error view with Retry, and a friendly empty state.

**5. The tap handler has a full rebuild, no feedback, double-tap pushes and no error handling. (Jank, duplicate screens)**
- **What the user sees:** The tap feels dead for about 1 s on a slow network, so the user taps again and gets two detail screens. If the request fails, nothing happens at all. With the original eager list, the `setState` before navigation also triggers another multi-second freeze.
- **Why:** `setState(() => e.detail = detail)` rebuilds the whole screen just to store data that nothing on this screen displays. It also mutates a shared model object in place. There's no in-flight guard or loading indicator, and no `try/catch`.
- **Fix:** Don't `setState` to store the detail. Cache details in a map, show a small progress bar, ignore taps while a request is in flight, show a SnackBar on error, and check `mounted` before navigating.

**6. A race between the initial fetch and live updates causes lost or duplicated earnings. (Wrong money shown)**
- **Why:** An update that arrives while `fetchEarnings` is in flight is inserted, then overwritten by `earnings = data`, so it's lost if the server snapshot predates it. If the snapshot already contains it, it shows up twice. The list is also mutated in place (`insert(0, ...)`) instead of being replaced, which makes change detection by reference (selectors, `==`) unreliable.
- **Fix:** Subscribe first and buffer updates until the fetch finishes, then merge and de-duplicate by `id`. Build a new list instead of mutating the old one.

**7. No keys on rows while inserting at index 0. (Wrong row state, extra work)**
- **Why:** Without keys, Flutter matches elements by position. Inserting at the top shifts every row, so any stateful tile (an expanded state, an image load, an animation) attaches to the wrong earning, and every visible row is updated.
- **Fix:** Set `key: ValueKey(earning.id)` on each tile.

**8. A change to `userId` is ignored (`didUpdateWidget`). (Can show another user's data)**
- **Why:** If a parent reuses this State with a different `userId` (for example after a profile switch), nothing reloads. The original only "works" because of the bug 1 loop. Once that's fixed, this becomes a real bug and a privacy issue.
- **Fix:** In `didUpdateWidget`, restart when `userId` changes, and ignore responses that belong to the old user.

**9. Hygiene.** Use `const` constructors and `super.key`, and avoid a global `api` singleton so the screen can be tested with an injected fake. Loading 3,000 items in one response also means a large JSON decode on the UI thread (see Questions).

### 1.2 Rewrite
See `lib/earnings/bloc/earnings_bloc.dart` and `lib/earnings/earnings_screen.dart`. The key points:
- **Data flow:** the UI sends events (`EarningsStarted`, `EarningTapped`, and so on), `EarningsBloc` talks to the API and the wallet stream, emits an immutable `EarningsState`, and `BlocBuilder` redraws. `build()` never fetches or subscribes.
- **Subscription lifecycle:** `BlocProvider` creates the bloc once per screen. The wallet stream is subscribed in `EarningsStarted` (before the fetch), updates are buffered during the fetch and then merged and de-duplicated by id, and the subscription is cancelled in `close()`, which `BlocProvider` calls automatically when the screen leaves.
- **No `mounted` checks needed:** if the screen leaves mid-request, the bloc is closed and Bloc ignores late `emit`s. Navigation and SnackBars run in `BlocListener`, which only fires while the widget is on screen.
- **Changed `userId`:** `BlocProvider` is keyed by `userId`, so a new user gets a fresh bloc and the old one is closed.
- **Smooth list:** `ListView.builder` with a `ValueKey` per row and one cached `NumberFormat`.
- **Detail taps:** `droppable()` ignores taps while a detail is loading. Details are cached, failures show a SnackBar, and navigation is a one-time `detailToOpen` signal handled by a listener.
- **Why Bloc:** it keeps the logic out of widgets and makes it unit-testable (see `test/projects_bloc_test.dart`), and events make the data flow explicit. The same structure maps directly to async_redux: events become actions, the bloc's handlers become `reduce()`, and the state lives in the store.

### 1.3 Guardrails for the other 59 screens
I'd turn on lints that catch these issues mechanically in CI (`cancel_subscriptions`, `close_sinks`, `use_build_context_synchronously`, `prefer_const_constructors`) and add a custom lint or review rule that `build()` must not call the API or `.listen`. I'd provide shared building blocks, an `AsyncView` (loading/error/empty/data) and a `PaginatedListView`, so the correct pattern is also the easiest one, and ban `Column` inside `SingleChildScrollView` for data-driven lists. Every list screen would get a performance check in profile mode on a reference low-end Android device before release, plus an integration test that scrolls a 3,000-item fixture and fails if frame build times exceed budget. A short PR checklist (lifecycle, `mounted`, states, keys) would cover the rest during review.

---

## Part 3 - Production scenario

### Message to the founder
> Recommend we **pause the 6.4.0 rollout now**. Pausing is one click and reversible; it only stops *new* users getting 6.4.0, and nobody loses ads or features - the 80% on 6.3 are unaffected. Crashing users went from ~0.4% to ~1.9% (≈5×), which is likely above Google Play's 1.09% bad-behaviour threshold for this group and can hurt our store visibility if it spreads. I'll have root cause + a plan by 1pm: either resume, or ship 6.4.1 to the same 20%.

### Investigation plan

**First, in Crashlytics (data before decisions):**
1. **Is it really new in 6.4.0?** Filter the issue by app version. Check whether it ever appeared in 6.3.x, and whether it appeared there as *non-fatal*. A `PlatformException` is a Dart exception. An uncaught one doesn't kill a Flutter app unless it's reported as fatal. So first check whether 6.4.0 changed crash reporting (for example `PlatformDispatcher.onError` / `recordError(..., fatal: true)`). The "crash" might be an existing error that's newly labelled fatal, or the app might really be dying.
2. **Stack trace and exception message/code:** Which ad SDK call fails (app-open ad on resume, `show()`, `load()`, consent/init)? Look at the breadcrumbs and logs leading up to the crash.
3. **Users vs events:** Is a small group crashing repeatedly, or are many users crashing once?

**Device and OS patterns to look for:**
- **Android version:** Is it concentrated on 14/15? That points to a `targetSdkVersion` bump in 6.4.0 changing behaviour.
- **Low-RAM devices and OEMs** (Xiaomi, Realme, Samsung budget phones): aggressive process killing means "resume" is often a restore after process death, and the ad SDK may be called before it's initialized.
- **WebView / Play Services version:** ad SDKs depend on these.
- **Time since launch / background duration:** does it only happen after a long time in the background?

**Code diff (the ad SDK wasn't updated, so something around it changed):**
- Diff the resolved Gradle dependencies between 6.3 and 6.4 (`./gradlew app:dependencies`). A transitive dependency such as Play Services Ads or a mediation adapter may have been bumped by another plugin even though we didn't touch the ad SDK.
- Check the Flutter/engine upgrade, `targetSdk`/`compileSdk`, R8/ProGuard rules, `MainActivity`/lifecycle changes, and any new code in `didChangeAppLifecycleState(resumed)`.

**Deciding between halt, hold at 20% and fix-forward:**
- **Halt (my default right now):** The rate is about 5× baseline, it's only in the new version, it's over the Play threshold and there's no instant mitigation. Halting is reversible and protects the other 80%.
- **Hold at 20%:** Only if the data shows it's narrow (one OEM or OS), it isn't a real process death (a reporting change), or a server-side lever can switch off the failing path for 6.4.0 users right away.
- **Fix-forward:** Once root cause is clear and the fix is small (for example, guard the resume ad call with try/catch plus a check that the SDK is initialized), ship 6.4.1 to the same 20%, watch crash-free users for 24 h, then expand. Halting doesn't help users who already have 6.4.0, so a fast 6.4.1 is the real fix for them. Play can't roll back to a lower version code.

**The lever I wish we had (and yes, I'd have shipped it):** A Remote Config kill switch per ad placement, for example `ads_app_open_on_resume_enabled`, targetable by app version, plus a flag around any lifecycle or ad-integration change. That would let us turn off resume ads for 6.4.0 users in minutes, trading a small slice of ad revenue for stability, instead of choosing between halting the release and leaving users crashing. Going forward: any change touching third-party SDKs or the app lifecycle ships behind a flag, with Crashlytics velocity alerts during staged rollouts.

---

## Assumptions
- `fetchEarnings` returns all entries newest-first, and each `Earning` has a stable unique `id`.
- `walletUpdates` only emits *new* events (no replay) and may overlap with the fetch snapshot, which is why I de-duplicate by id.
- I can replace `formatCurrency`'s internals with a cached `NumberFormat` (₹, `en_IN`). If I can't, I'd memoize its output per item lazily.
- `EarningTile` and `DetailScreen` keep their existing APIs. The fakes in `earnings_fakes.dart` exist only so the screen runs.
- Part 2: a page with fewer than 20 items (including an empty page) means the end of the list. A failed refresh keeps the old list and shows a SnackBar. A failed page load is not retried automatically on scroll; the user taps Retry.
- I used Bloc, which I know best, instead of async_redux, as the brief allows. The logic is in plain event handlers, so moving it to async_redux actions is mechanical.

## Questions I'd ask you
1. Does the earnings API support pagination or a summary endpoint? Sending 3,000 items to an ₹8,000 phone means a large JSON decode (on the UI thread unless moved to an isolate) on one of the most-visited screens.
2. Does `walletUpdates` replay recent events on subscribe, and can it emit an earning that's already in the fetch result?
3. Is `EarningTile` a fixed height? If so I'd add `itemExtent` for cheaper scrolling.
4. Is `formatCurrency` used elsewhere, and can I change it to cache its `NumberFormat`?
5. Part 2: should end-of-list come from a short page, an empty page, or a total count/`hasMore` from the server?
6. Part 3: did 6.4.0 change `targetSdk`, the Flutter version or the crash-reporting setup, and do we already have Remote Config in the app?
