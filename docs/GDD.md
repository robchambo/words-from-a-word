# Слова из Слова — Game Design Document

The single source of truth for what the game is, who it's for, and how it works. Built iteratively through discussion; sections are drafted one at a time.

Companion docs:
- `CLAUDE.md` — dev-facing cheat sheet (architecture, commands, conventions)
- `docs/DECISIONS.md` — why key choices were made (D-entries)
- `docs/FLUTTER_HANDOVER.md` — historical; original Manus AI spec

---

## Status

| # | Section | Status |
|---|---|---|
| 1 | Vision & pitch | _drafted_ |
| 2 | Target audience | _drafted_ |
| 3 | Core gameplay loop | _drafted_ |
| 4 | Mechanics | _drafted_ |
| 5 | Content & progression | _drafted_ |
| 6 | Meta systems | _drafted_ |
| 7 | UX & visual design | _drafted_ |
| 8 | Monetisation | _drafted_ |
| 9 | Technical architecture | _drafted_ |
| 10 | Analytics & KPIs | _drafted_ |
| 11 | Accessibility & localisation | _drafted_ |
| 12 | Roadmap | _drafted_ |
| 13 | Open questions | _living list_ |

Working order: current-state sections first (3, 4, 5, 7, 9), then forward-looking (2, 1, 6, 8, 10, 11, 12).

---

## 1. Vision & pitch

### 1.1 Elevator pitch

> **A warm, bilingual Russian/English word puzzle for the diaspora — make words from one big one, on what feels like your grandmother's notebook.**

### 1.2 Emotional promise

Two feelings, held in the same hand:

- **Familiarity and comfort.** The Soviet Notebook page — cream paper, navy ink, a crimson stamp — and the familiar shape of a «слова из слов» puzzle evoke a specific cultural memory for Russian-speaking players. For those who grew up with it, the app feels immediately like home. Everything in §7 design serves this feeling.
- **Family connection.** The app is a low-stakes bridge between generations. An immigrant parent polishes their English; their adult child polishes their Russian; both quietly build toward being more fluent in the other's world. The bilingual toggle isn't a feature — it's the product (§2.2).

Secondary feelings the game also delivers — gentle cognitive exercise and a quiet, no-fail escape — are common to the casual word-game genre. They are welcome but not the wedge.

### 1.3 What we refuse to be

This is a companion, not a challenge. It does not shame a broken streak, penalise slow play, or stack "beat your friends" leaderboards. Its warmth comes from restraint.

### 1.4 Success criteria

**Not yet set.** Quantitative targets (downloads, revenue, retention) will be chosen once §10 analytics define what we can measure and once early real-world usage tells us what a "good" curve looks like for this audience. A qualitative anchor does hold regardless: *Russian-speaking families genuinely use the app to bond or to practice.* If that isn't happening at 6 months post-launch, the product hasn't worked even if the numbers look fine.

### Decisions captured in this section
- **Pitch is locked.** Use verbatim as the first line of store copy, website headers, and any external comms unless/until a deliberate rewrite.
- **Dominant emotional promise: familiarity + family connection.** All design, copy, and marketing decisions should ladder up to one of these two.
- **Qualitative north star: "families genuinely use it to bond or practice."** Quantitative targets deferred until analytics and early usage exist.

### Open questions raised by this section
- **[§1.4 / §10] Quantitative success targets** — deferred until analytics land. Likely candidates: D1/D7/D30 retention, sessions per active user per week, RU/EN mode split.
- **[§1.4] How we know the qualitative target is being hit** — needs a feedback channel (in-app prompt, app-store review mining, a small Russian-speaking user panel). Revisit post-launch.

## 2. Target audience

### 2.1 Core audience

**The Russian-speaking diaspora**, with the initial wedge being **Russian immigrants in the United States** and their first- and second-generation children.

Two user stories sit at the heart of the product:

1. **The immigrant parent.** Came to the US as an adult; Russian is the comfortable, native language but English is the daily working language. Wants a familiar, culturally-resonant puzzle experience — *and* wants to keep sharpening English vocabulary in small daily doses.
2. **The diaspora child or grandchild.** Grew up in the US with English as the dominant language and Russian at home. Wants to strengthen Russian to talk with parents, grandparents, relatives still in Russia or elsewhere. The app is a low-stakes way to keep the language alive.

Both user stories share a single underlying need: **vocabulary reinforcement in the less-dominant language, wrapped in a casual game.**

### 2.2 Why bilingual is central, not optional

This is the key positioning insight. Russian and English modes aren't serving two different audiences — they are serving the **same** bilingual household, each member reaching for the language they want to *strengthen*. That's why:

- In-game language switching must feel fluid (the bottom-sheet toggle from v1.0 stays).
- Both modes must feel equally first-class in content volume and difficulty shape (§5.4 parity).
- Neither mode is a translation of the other — the level sets are authored separately in each language (§5.1).

This framing also makes the app distinct from single-language competitors: those serve monolingual word-game players. Слова из Слова serves *the household*.

### 2.3 Secondary audiences

Expansion beyond the US wedge, in rough order of opportunity:

- **Russian-speaking communities elsewhere** — Israel, Germany, UK, Canada, Australia. Same product, same framing, different distribution.
- **Monolingual Russian speakers in Russia and CIS states** who want a polished casual word game in their own language. They're a bonus audience the product doesn't require but won't turn away. Most-likely discovery path: app-store search on «слова из слов».
- **Monolingual English speakers** browsing for a casual word game. They'll find the English mode perfectly playable but won't be moved by the Soviet Notebook aesthetic. Tolerable, not targeted.

### 2.4 Who it's *not* for

- **Hardcore word-game enthusiasts** wanting high difficulty, leaderboards, competitive modes. This is a gentle puzzle, not a skill test (§3: no fail state).
- **Children under ~8** — the word complexity in both languages assumes literacy and some vocabulary breadth.
- **Players who don't value the cultural aesthetic** — the Soviet Notebook feel is core to the product, not a skinnable theme. If that's off-putting, there are larger competitors that aren't.

### 2.5 Reference games

The product sits in the **casual "make-words-from-letters"** genre. Nearest references:

- **Слова из Слов** (existing RU genre staple) — the obvious genre predecessor and the direct comparison Russian-speaking players will make. Slova's form is our form; we differentiate on aesthetic, bilingual support, and hint design (§4.5).
- **Wordscapes / Words of Wonders** (EN mass-market leaders) — the shape of our core loop. Casual, progressive levels, ad-supported. Our tone is quieter and more literary.
- **NYT Spelling Bee** (tasteful brainy reference) — not the same mechanic, but a tonal north star: word games can be warm, short-session, literary. Our design philosophy (§7.1) leans closer to this than to Wordscapes.

**Positioning statement.** *"Слова из Слов, but beautiful, bilingual, and built for the family."*

### 2.6 Implications for design and content

- **Aesthetic is the wedge.** The Soviet Notebook feel is what earns a download from the core audience over Slova. Don't dilute it.
- **Content parity matters.** An EN-mode player married to a RU-mode player should not feel their experience is an afterthought (§5.4). Launch bar is parity.
- **Translation is not the content strategy.** Each language gets native-authored levels, not ports.
- **Tone in both languages must be warm.** No aggressive "streak broken" shaming (Duolingo-style). The app is a companion.

### Decisions captured in this section
- **Initial wedge: Russian immigrants in the US and their children/grandchildren.**
- **Positioning: "Слова из Слов, but beautiful, bilingual, and built for the family."**
- **Both language modes serve the same bilingual household**, not two distinct audiences.
- **Content parity between RU and EN is a first-class requirement**, not a nice-to-have.
- **Monolingual RU (in Russia/CIS) is a welcomed bonus audience**, not a targeted one.

### Open questions raised by this section
- **[§2.1] Age skew** — unconfirmed. Intuition says 30–65, but no data. Worth a small audience survey pre-launch.
- **[§2.3] Geographic launch order** — US only at launch, or global-RU-diaspora at launch? Affects §12 roadmap and §8 monetisation (regional ad CPMs vary wildly).
- **[§2.3] ASO / localisation strategy for monolingual RU audience** — do we pursue it explicitly (keyword optimisation on «слова из слов» in the Russia store), or leave it as passive discovery?

## 3. Core gameplay loop

A session is one or more levels in a single sitting, typically 2–5 minutes each. The player opens the app, is taken straight to the game in their previously chosen language (first launch asks Russian/English, subsequent launches remember), sees the source word at the top of a grid-paper page, and taps letter tiles to form shorter words. Correct words light up in slots grouped by length; incorrect guesses shake. When all required words are found, a full-screen level-complete overlay fires with confetti — the payoff moment — and offers "next level" to continue or dismiss to stop. The player decides when to walk away.

**Target feeling on session close: pride at a level cleared.** Every design decision inside the loop — the stamp badge for the level number, the confetti, the found-word slots filling in — serves that moment. Words longer than three letters carry score bonuses so players feel rewarded for ambition, not just completion.

**No failure state.** The player cannot lose a level, run out of time, or have progress taken away. This is deliberate — it keeps the game a low-stakes companion rather than a skill test, and matches the casual-puzzle genre norms (Wordscapes, Words of Wonders, NYT Spelling Bee).

**Re-entry.** A returning player is dropped directly into the game in their last-used language, ready to tap. No mandatory home screen.

### Open questions raised by this section
- v1.0 ships a home screen that asks for language every launch, despite `SettingsProvider` persisting the choice. Changing re-entry to "straight into the last-used language" is a v1.1 scope item → captured below.
- Does "straight into the game" mean last-played level, or always level 1? (Relates to §6 meta — session persistence.)

## 4. Mechanics

### 4.1 Tile selection

The source word's letters are rendered as a grid of 48×48 tiles. The player taps tiles one at a time; selected tiles animate (scale + shadow) and their letters appear in an input bar, left-to-right, in tap order. A tapped tile that is already selected triggers a **cascading deselect** — that tile and every tile selected after it are removed from the input. This mirrors "undo the last N taps."

Supporting actions on screen:
- **Clear** — wipes the current input back to empty.
- **Shuffle** — re-orders the source tiles on the grid. Purely cosmetic; letter set unchanged.
- **Hint** — see §4.5.

Feedback: a light haptic (`selectionClick`) on every tap. No sound (no audio system yet — see §7).

### 4.2 Word submission

Submission is **manual only** — an explicit Submit button. The button is disabled while the input is shorter than three letters. Auto-submit on valid-match is deliberately avoided: the commit tap is the player's act of ambition, and removing it would flatten the loop.

- **Valid word, first find:** medium haptic, word lights up in its slot, score updates, input clears, the word flashes briefly (1.5 s) as a confirmation.
- **Valid word, already found:** shake (400 ms) + heavy haptic. No score.
- **Invalid word:** same shake + heavy haptic. Input is preserved so the player can adjust.

### 4.3 Validation

A word is valid if and only if it appears in the current level's `targetWords` list (either required or bonus). There is no open-ended dictionary; see `DECISIONS.md` D1. This gives the level designer full control over what counts and keeps the asset bundle light.

### 4.4 Scoring

**Required words** use the v1.0 formula: `points = word.length × 10 + lengthBonus`.

| Length | Length bonus |
|---|---|
| 3 | 0 |
| 4 | +10 |
| 5 | +20 |
| 6+ | +30 |

A 3-letter required find is 30 pts; a 6-letter required find is 90 pts.

**Bonus words** score a **flat 15 pts each**, regardless of length. The design intent: bonus words are not point fountains. Their real reward is **progress toward a free hint** (§4.5). A completed level with no bonuses always produces roughly the same headline score; bonus-hunting is a differentiator without being a farming loophole. The 15 pt value is provisional — revisit once analytics land.

**Hints have no score cost.** The cost of a hint is either a rewarded ad or a free-hint slot (§4.5). No additional point penalty is applied. This was considered and rejected — double-charging (ad + score penalty) would suppress hint usage and ad revenue.

**Pending-and-bank scoring.** Points earned on found words during a level are **pending** until the level is completed. On level-complete, pending points bank into the session score. If the player leaves a level unfinished (returns to home, switches language, closes the app), pending points are **discarded without further penalty**. This closes a v1.0 issue where partial-level farming could inflate session score.

**Scope.** Session score is session-only — it does not persist across app restarts. (Cross-session persistence of other data — free-hint slot, bonus counter — is covered in §4.5 and §6.)

### 4.5 Hints

**Purpose.** A hint reveals a letter from the source word that appears in as many unfound required words as possible, **but never the final missing letter of any unfound required word.** Hints narrow the search space; they never spoil an answer.

**Budget.** A hard cap of **three hints per level**. Budget resets every level.

**Cost per hint press — waterfall.** The same for free and premium players, but with different slot capacities (see below):
1. **Free-hint slot** ≥ 1 → spend it, no ad. Decrements by 1.
2. Else **purchased-hint pool** ≥ 1 → spend one, no ad.
3. Else a **rewarded video ad** is offered. On successful ad completion, the hint fires. Available to both free and premium players — ads are always player-initiated and optional past step 2 (§8.1 non-revenue commitments).
4. If the ad is dismissed/failed/refused: nothing changes — no hint consumed, no state mutation.

The level cap (3) and the safety rule always apply independently of cost.

**Safe-letter algorithm.**
1. Compute unfound required words `U_req` (`isFound == false && isBonus == false`).
2. For each distinct source letter `L` not already revealed, count how many words in `U_req` contain it → *frequency*.
3. Drop any `L` that is the single remaining unrevealed letter of some word in `U_req` — those would complete a word.
4. From the survivors, pick the highest-frequency letter. Ties broken by longest containing word, then alphabetical.
5. Add `L` to the revealed set.

**Availability guarantee.** The safe-letter computation runs before the hint button is pressed. The button is enabled iff a safe letter exists **and** `hintsUsedThisLevel < 3`. An ad never plays unless a reveal is already guaranteed — a player watching an ad is always rewarded.

**Reveal style — slot pre-fill.** The chosen letter is filled into every matching position of every unfound word slot (required and bonus). The pre-filled letter is visually distinct from a player-found letter so the player can see which letters are theirs. Exact treatment (italic, underline, or muted amber) is a §7 question.

**Bonus words.** Not considered in the safety check (completing a bonus word is not a spoiler), but included in slot pre-fill so reveals look consistent across the page.

#### Free-hint slot — capacity & refill rules

**Capacity:** the slot holds up to **1 hint** for free players, **3 hints** for premium players (§8). It persists across app restarts (§6 meta).

**Refill routes:**

| Route | Trigger | Behaviour |
|---|---|---|
| **Daily gift** | Device-local midnight. On the first app foreground of the new day, the slot **tops up to its cap** (1 for free, 3 for premium). | Unused hints don't stack beyond cap. No "additive" behaviour — just a top-up. Skipped if slot is already at cap. |
| **Bonus-word accumulator** | When the running counter hits 10 bonus words found, slot gains +1 (up to cap), counter resets to 0. Counter persists cross-session. | **Counter freezes at 9 when slot is at cap.** No further progress until a hint is spent. Once spent, counter resumes; next bonus word advances to 10 → refill. Accumulator rate is the same for free and premium players — 10-to-1. |

**Celebratory popup.** When the counter crosses 10 and the slot refills, a lightweight popup fires (e.g. "Free hint earned!"). One celebration per refill event. No popup for the daily gift — that's passive.

**No per-level first-free-hint.** v1.0's "×3 hints, first is always free each level" model is replaced entirely by the slot system. Players entering a level with an empty slot fall through to purchased pool or rewarded ad.

#### UI surfacing

- **Hint button:** standard in two states — enabled / disabled — driven by availability + cap. No visible differentiation between "free" and "ad" state prior to press; the player finds out when they tap (the ad either plays or it doesn't). Rationale: keeps the button simple; less decision fatigue.
- **Subtle top-of-screen strip:** shows bonus-word progress toward the next refill and current slot state when either is in flight. Example copy: *"3 bonus words to free hint · 1 hint banked"*. Hidden when counter == 0 and slot == 0.
- **Celebratory popup:** fires on bonus-word refill event only. Does not fire on the daily gift — that's passive.

#### State

`GameState` changes:
- Drop `hintsRemaining: int`.
- Add `revealedLetters: Set<String>` (per-level).
- Add `hintsUsedThisLevel: int` (per-level).

**New cross-session persistence** (new provider — proposed `RewardsProvider`, backed by `shared_preferences`):
- `freeHintSlot: int` (0..cap; cap is 1 for free, 3 for premium)
- `bonusWordCounter: int` (0..9; clamps at 9 when slot is at cap)
- `purchasedHintCount: int` (0..∞; §8)
- `premium: bool` (§8)
- `lastDailyClaimedOn: Date` (device-local date string, YYYY-MM-DD)

This is the first cross-session persistence in the app beyond the language mode. Architectural detail in §9.

#### Ad integration

An `AdGateway` seam defines `Future<bool> showRewardedAd()`. A `NoopAdGateway` resolves true immediately for dev and tests; a `MobileAdsGateway` backed by AdMob replaces it in the ads sprint. On `showRewardedAd() → false` (dismissed or failed), no state mutates — no hint consumed, no letter revealed, no score change.

### 4.6 Level completion

A level is complete when every **required** word is found. Bonus words are never required. On completion, a full-screen overlay fires with confetti, the final level score, and "next level" / "home" options.

Unfound bonus words are left behind when the player advances — the session moves on and those points are gone. Whether this should change (a "keep playing for bonuses" prompt, or a completion-tier system) is an open question below.

### Decisions captured in this section
- **Cascading deselect is canonical.** A mid-input tap deselects that tile and every tile after it.
- **No auto-submit.** Submission is always an explicit button press.
- **Minimum word length is 3 by default**, but can be overridden per level to shape difficulty.
- **Validation stays closed-world** (level list only, per D1). No open-ended dictionary in v1.x.
- **No completion tiers.** Bonus words award points but never block completion; unfound bonus words at level-complete are forfeited silently.
- **Required-word scoring** unchanged from v1.0 (`length × 10 + length bonus`).
- **Bonus words score a flat 15 pts** and their real reward is progress toward a free hint.
- **Hints carry no score cost** — the cost is an ad or a free-hint slot.
- **Pending-and-bank scoring** — mid-level points are provisional; they bank on level-complete, discard on abandon.
- **Hints per level: hard cap 3.** No per-level free hint.
- **Free-hint slot capacity** is **1 for free players, 3 for premium players**, cross-session persistent.
- **Bonus-word accumulator** is 10-to-1; counter freezes at 9 when slot is at cap. Same rate for free and premium.
- **Daily gift** tops slot up to its cap at device-local midnight; unused hints don't stack beyond cap.
- **Rewarded ads remain available to all players** (free and premium) as an optional fallback when other hint sources are empty.

### Open questions raised by this section
- **[§4.1] Shuffle button** — genuinely useful or holdover? Keep canonical in v1.x, revisit with analytics.
- **[§4.4] Scoring numbers** — `×10`, length bonuses, 15 pt flat bonus, and the 10-bonus refill threshold are all provisional. Revisit after analytics.
- **[§4.5] Slot pre-fill visual treatment** — resolved in §7.5: **underline** as default, revisit in playtest.
- **[§7.5] Top-strip counter layout** — sketched, needs real design pass.
- **[§7.6] SFX asset sourcing** — freesound / Kenney / custom, decide at build time.
- **[§7.6] Settings screen home** — no settings surface exists yet; mute toggle needs one.
- **[§7] Rules modal copy refresh** — RU/EN rewrite during v1.1 implementation.
- **[§9.6 / §6] Level progress persistence** — open until §6 meta decides resume behaviour.
- **[§9.8 / §12] CI/CD pipeline** — no CI today. Pre-launch item, low-effort.
- **[§9.1 / §12] Binary size audit** — post-ads/audio packages, pre-launch.
- **[§2.1] Age skew** — unconfirmed; worth a small pre-launch audience survey.
- **[§2.3] Geographic launch order** — US-only or global-diaspora at launch?
- **[§2.3] ASO strategy for monolingual RU audience in Russia store** — passive vs active.
- **[§1.4 / §10] Quantitative success targets** — deferred until analytics land.
- **[§1.4] Qualitative target feedback channel** — how we'll know families are actually using it to bond/practice.
- **[§6.5] Themed special-level content pipeline** — post-launch content ops question.
- **[§6.6] Retroactive achievement backfill** on v1.0 → v1.1 upgrade.
- **[§6.7 / §12] Leaderboard timing** — tentatively v1.3+.
- **[§8.6 / §7.6] Settings screen home** — shared with audio mute question; both need a surface.
- **[§8.3] Interstitial first-launch exemption scope** — first session ever vs each launch?
- **[§8.5] Mediation decision** — revisit 2–4 weeks post-launch.
- **[§8.8 / §12] Russia market release posture** — ad-only reality, do we still ship there at launch?
- **[§10.2 KPI 8] Store-review tagging workflow** — manual now, revisit automation later.
- **[§10.5] Remote Config refresh on foreground** — eager vs default hourly; revisit if needed.
- **[§10.6] A/B test priority order** — data-driven call post-launch.
- **[§11.2] Accent-on-body-text audit** — v1.1 kickoff action.
- **[§11.3] Action-button tap-target audit** — pre-launch check.
- **[§11.4] Large-text first-launch explainer** — toast / rules-modal / silent.
- **[§11.7] Screen-reader user panel** — post-launch feasibility.
- **[§12.3 / §9.8] CI tooling** — GitHub Actions default; confirm.
- **[§12.8] OTA level drops via Remote Config / Firebase Hosting** — v1.2 experiment.
- **[§12.7] Geographic expansion order post-launch** — Israel first likely.
- **[§4.5] Daily-gift claim trigger** — grant on app foreground, or lazily on first hint press of the day? Behavioural tradeoff; probably app foreground for responsiveness. Revisit when building.

## 5. Content & progression

### 5.1 Level library — current state

v1.0 ships **23 Russian levels and 20 English levels** as bundled JSON assets (`assets/data/russian_levels.json`, `assets/data/english_levels.json`). Every word was audited against its source word's letter multiset before release; the English set required corrections against the original Manus spec (see `DECISIONS.md` D7).

Level JSON schema:

```json
{
  "sourceWord": "strawberry",
  "required": ["bar", "star", "straw"],
  "bonus": ["berry"]
}
```

Each level's ID is derived from its array position by `LevelLoader.generateLevel(levelNumber)` — the JSON does not carry an explicit `id` field (see `DECISIONS.md` D17).

`LevelLoader` validates every word at load time using `GameEngine.canFormWord()` and caps required words at 12 per level (historical — the 12-cap was D5 on `main`; on v2 required-word counts are governed by difficulty profiles per D16, and D5 has been removed). Words beyond the cap are silently dropped, not demoted to bonus.

### 5.2 Difficulty

A `difficulty` field will be added to the level schema. Proposed scale: **1 (easy) → 5 (hard)**, carried in JSON per level. It's a categorisation signal only in v1.x — no gameplay effect — but gives the content team a vocabulary and sets up future features (difficulty filters, progression pacing, daily-challenge selection).

The signal is informed by, but not reducible to: source-word length, required-word count, rarity of letters, overlap between required words, and minimum-word-length for the level (per §4.2 override).

This field is optional until the library is re-audited; levels without it are treated as difficulty `unknown` at runtime.

### 5.3 Ordering

The current ordering in the JSON is **arbitrary** — it reflects authoring order, not a deliberate difficulty curve. A pass to re-order levels by the new `difficulty` field (easier first, ramping up) is a content-side task and will be tracked in §12.

### 5.4 Russian / English parity

Russian and English are intended to be **comparable experiences**, not translations of each other. Each language has its own word pool, its own source words, and its own level set, but they match on:
- Level count (target: 50 minimum, 100 ideal — see §5.6)
- Difficulty distribution across the 1–5 scale
- Core mechanics (§4) are identical

There is no cross-language shared state — `score`, `revealedLetters`, and progression are per-language.

### 5.5 Content authoring

Currently **in flux**. v1.0 levels were authored by hand in JSON and validated by a Node.js script run against the English spec before release. No tool replaces that yet. A proper authoring pipeline (word-list upload, automatic required/bonus partitioning, per-letter multiset checks, difficulty auto-scoring) is a post-launch topic; this GDD will be updated when it exists.

Until then, adding a level means: edit the JSON, run the validation script, verify in-game.

### 5.6 Launch bar

The game will not ship to stores below **50 levels per language**. The target is **100 levels per language**; that's the benchmark where daily-challenge rotation and difficulty-filtered selection start to feel meaningful (§6).

### 5.7 End-of-library behaviour

**v1.0 state (known bug):** `LevelLoader.generateLevel` does `(levelNumber - 1) % defs.length`, so a player who finishes level 23 (RU) or 20 (EN) and taps "Next level" silently starts level 1 again with the same session score. This is unintentional — the wrap was never a product decision.

**v1.1 decision:** Replace the silent wrap with explicit end-of-library handling.
- `LevelLoader.generateLevel` throws a sentinel (or returns `null` — engineer's call) when `levelNumber > defs.length`.
- `GameProvider.nextLevel` detects the sentinel and transitions to a **library-complete screen** instead of starting a new level.
- The library-complete screen shows: celebration copy, lifetime score, streak, and two actions — "Replay levels" (opens the level picker filtered to completed levels) and "Close" (back to home).
- Replaying a completed level enters **free mode**: score is not added to lifetime, best score is not updated, hints and bonus-word accumulator still function normally (so replay is useful for hint farming but doesn't inflate stats).
- Once 100 levels are live per §5.6, this screen is rarely reached but must still exist.

**Scope:** Implemented alongside Phase 3 progression UI (`docs/V1_1_ROADMAP.md`).

### Decisions captured in this section
- `difficulty: 1..5` field is being added to the level schema.
- RU and EN will reach parity in level count and difficulty shape.
- Launch bar is 50 levels per language, 100 ideal.
- Level JSON does not carry an explicit `id` field; ID is derived from array position (D17).
- End-of-library is a library-complete screen + free-mode replay of completed levels (§5.7).

### Open questions raised by this section
- **[§5.2] Difficulty auto-scoring vs manual** — does the level designer tag each level 1–5 by hand, or do we compute it from signals (word length, count, etc.)? A hybrid (compute a suggestion, designer overrides) is probably right.
- **[§5.5] Authoring tool** — what does a proper authoring pipeline look like? Deferred.
- **[§6] Daily challenges** — flagged here, owned by §6 meta.

## 6. Meta systems

Everything that sits on top of single-level gameplay: re-entry, progression, scoring surfaces, streaks, daily challenges, achievements. This section also names the explicit non-goals that keep v1.x focused.

### 6.1 Re-entry

A returning player lands directly in the game in their last-used language (§3). They resume at **the start of the level they were on when they left** — not mid-level, not the next level. This works cleanly with pending-and-bank scoring (§4.4): pending points on an abandoned level are already discarded, so restarting the level from scratch is expected behaviour, not a loss.

**First launch** and **language change** both route via the home screen for language selection; subsequent launches skip it.

### 6.2 Progression

Progression is **linear by default with browse override** (hybrid).

- **Linear flow:** the game always opens on the player's current level. Clearing a level advances to the next. This is the 90% path.
- **Browse surface:** a level-picker screen, reachable from a menu button, lists every level in the current language. Cleared levels are marked with the crimson stamp; the current level is highlighted; locked levels are greyed.
- **Replay:** tapping a cleared level replays it. A replay updates the **per-level best score** (§6.3) and accumulates into lifetime score. Replays do not affect streak, daily challenge, or any "first-time" achievement triggers.

**Per-language progression.** RU and EN progress independently. Switching languages does not advance or reset anything in the other.

### 6.3 Scoring surfaces

Three scores live at once, each with its own place in the UI:

| Score | Scope | Persistence | Surfaces |
|---|---|---|---|
| **Session score** | This sitting | In-memory, resets on app close | Top strip on the game screen (§7.3) |
| **Per-level best** | One specific level, one language | Persisted per `(language, levelId)` | Level-complete overlay ("new best!" celebration when beaten), level-picker tiles |
| **Lifetime total** | All time, one language | Persisted per language | Browse screen header, profile-like surface later if one arrives |

**Persistence additions** (to §9.6):

| Key | Type |
|---|---|
| `currentLevel.{ru,en}` | int |
| `highestCompletedLevel.{ru,en}` | int |
| `levelBestScore.{ru,en}.{levelId}` | int |
| `lifetimeScore.{ru,en}` | int |

### 6.4 Streaks

A daily-play streak. **Celebrate forward, never punish a break.**

- **Increment** when the player completes *any level* on a day they hadn't already played (device-local day, matches daily-gift rules from §4.5).
- **Reset quietly** if two or more full days pass without play. No angry modal, no shame copy. The counter simply starts again.
- **Display**: a small flame-or-stamp icon with a number, tucked into the top strip. Optional micro-celebration at thresholds (3, 7, 30, 100 days).

Replays do not increment streak; only completions of the player's current level count.

**Persistence:**
- `streakCount: int`
- `streakLastPlayedOn: String` (ISO date)

### 6.5 Daily challenge (v1.2+, parked for launch)

A single level designated as "today's challenge," the **same for every player on a given day** (deterministic from date so no backend needed). Completing it awards a small reward — probably a free-hint-slot refill (same shape as the daily gift, just earned) or a streak-style badge.

**Picking today's level** — options:
- **Deterministic pick from the library** (e.g. `levels[hashOf(today) % levels.length]`). Simple, no new content pipeline.
- **Themed special levels** — source words tied to books, authors, holidays, or cultural moments (Tolstoy day, Pushkin's birthday, Victory Day, New Year, Thanksgiving). Source word is a themed proper noun or relevant term. These come and go — they're available the day of, and may re-appear annually. Adds content work but meaningful retention hook and emotional resonance with the audience.

**Lean:** start with deterministic library pick in v1.2; layer themed specials on top once the library is bigger and the content pipeline settles.

**Not in v1.1.** Flagged here so the data model can accommodate it later (specifically the `lastDailyChallengeCompletedOn` key if/when added).

### 6.6 Achievements

A small set of collectable badges. Local-only — no Game Center, no Play Games Services — in v1.x. A dedicated "trophies" screen reachable from the menu. Unlocking an achievement fires a quiet toast (not a blocking modal).

**Starter set, grouped:**

*Progression*
- **First Steps** — complete level 1 (either language).
- **Ten Down** — complete 10 levels in either language.
- **Halfway** — complete 25 levels in either language.
- **Library Cleared (RU)** — complete every Russian level.
- **Library Cleared (EN)** — complete every English level.

*Skill*
- **Clean Solve** — clear a level with no hints used.
- **Flawless** — clear a level with no invalid submissions.
- **Bonus Hunter** — find every bonus word in a single level.
- **Long Word** — find a 7+ letter word.

*Bilingual (the ones unique to this product)*
- **Both Tongues** — complete your first level in each language.
- **Family Table** — complete 10 levels in each language.

*Meta*
- **First Hint** — use a hint for the first time.
- **Earned It** — redeem a free hint earned from bonus-word progress.
- **Week Strong** — reach a 7-day streak.

That's 14 to start. Balances easy early hits (First Steps, First Hint) with long-tail goals (Library Cleared, Family Table). Can be expanded over time. Achievement state persists as a boolean flag per ID.

**Persistence:**
- `achievementsUnlocked: Set<String>` (stored as JSON array in shared_preferences)

### 6.7 Non-goals for v1.x

- **Leaderboards.** Parked for post-launch. When they arrive, the plan is **Game Center (iOS) + Google Play Games Services (Android)** — free platform-native leaderboards and identity, no custom backend, no account screen, no GDPR exposure. Single API call per score submit; display via platform native UI or a tasteful in-app list. This avoids the "no backend" commitment in §9.1 becoming a blocker. No custom profile system; players use their existing Apple/Google identity when they choose to submit.
- **User accounts / profiles.** Deliberately absent in v1.x. Removes authentication, password reset, email handling, GDPR user-rights flows.
- **Cloud save / cross-device sync.** Deferred with accounts. Day-one workaround if requested: Apple Keychain + Android Backup Service can ferry `shared_preferences` across reinstalls without an account, but it's off-the-shelf platform behaviour, not a built feature.
- **Friends / social / invite-to-play.** Out of scope indefinitely — contradicts the quiet-companion tone (§1.3).
- **Monetised cosmetics, level packs, season passes.** Ads are the only planned monetisation for v1.x (§8).

### Decisions captured in this section
- **Re-entry resumes at the start of the last-played level**, same language.
- **Progression is hybrid**: linear flow with a browse picker accessible via menu.
- **Three scoring surfaces**: session, per-level best, lifetime total per language.
- **Streaks are included in v1.1**, gentle framing, no punishment on break.
- **Daily challenges deferred to v1.2+**; when they arrive, they start with deterministic library-pick and evolve into themed special levels.
- **Achievements included in v1.1**, 14-badge starter set, local only.
- **Leaderboards explicitly deferred post-launch**; when implemented, use **Game Center + Play Games Services** — no custom backend, no profile.
- **No user accounts or cloud save in v1.x.**

### Open questions raised by this section
- **[§6.5] Themed special levels** — when does the content pipeline support this (tied to §5.5)? How do we handle level availability after the themed day passes — archived, or removed?
- **[§6.6] Achievement polish** — icon design, celebration animation, placement of the trophies screen in the navigation. Design pass during v1.1 implementation.
- **[§6.6] Retroactive unlocking** — if a player hits the conditions before v1.1 ships (e.g. has already completed 10 levels on v1.0), do we backfill those badges on first v1.1 launch? Lean yes for goodwill — requires reading state from §9.6 persistence and applying rules once.
- **[§6.7 / §12] Leaderboard timing** — pencilled for v1.3+; confirm when roadmap is drafted.

## 7. UX & visual design

### 7.1 Design philosophy — Soviet Notebook

The whole visual language is "a well-worn Soviet-era school exercise book." Warm cream page with a subtle grid, deep navy ink for type, crimson red for CTAs and authority marks (stamps, progress bars), amber gold for rewards and bonus content. Serif (Playfair Display) for display headings — the elegant handwriting of a patient teacher. Sans-serif condensed (Roboto Condensed) for labels and tile letters — the mechanical, stamped quality of a printed form. No drop shadows, no gradients, no skeuomorphism beyond what a real notebook has: paper texture, ink, and occasional wear.

### 7.2 Design tokens

All values live in `lib/theme/app_theme.dart`. Never hardcode.

#### Colour

| Token | Hex | Role |
|---|---|---|
| `background` | `#FFFEF0` | App background (cream paper) |
| `foreground` | `#1D2B38` | Primary text, tile letters (navy ink) |
| `primary` | `#B22030` | Crimson — CTAs, stamps, progress bar, invalid-word shake |
| `primaryFg` | `#FEFEF8` | Text on crimson surfaces |
| `accent` | `#F5A234` | Amber gold — bonus words, level-complete rewards |
| `muted` | `#EDE9DC` | Disabled states |
| `mutedFg` | `#7A8A96` | Disabled/secondary text |
| `border` | `#C8D0D8` | Dividers, grid paper lines |
| `tileBg` | `#F5F2E8` | Letter tile background |
| `slotEmpty` | `#D8DDE3` | Empty word-slot placeholder |
| `slotFilled` | `#1D2B38` | Filled word-slot text |
| `card` | `#F7F4EC` | Modal / overlay surfaces |

#### Typography

Loaded at runtime via `google_fonts` (D2 — not bundled). Cached after first fetch.

| Style | Font / size / weight | Usage |
|---|---|---|
| `displayLarge` | Playfair Display, large, bold | Home screen title |
| `displayMedium` | Playfair Display 24 / bold | Source word at top of level |
| `displayItalic` | Playfair Display italic | Decorative accents |
| `condensedBold` | Roboto Condensed bold | Section headers |
| `condensedLabel` | Roboto Condensed 10 / 3px tracking | Small labels, tags |
| `tileLabel` | Roboto Condensed 18 / bold | Letter tile glyphs |

#### Surface details

- **Grid paper background** (`grid_paper_background.dart`): 20px grid, `border`-coloured strokes, painted as a `CustomPainter` on the cream `background`. Low opacity — present but never loud.
- **Stamp badge** (`stamp_badge.dart`): circular crimson stamp used for the level number. Feels like a teacher's date stamp.
- **Tile**: 48×48 square, `tileBg` fill, subtle border, letter in `tileLabel`. On select: scale + drop shadow for depth.

### 7.3 Screens (current state)

The app today has a minimal two-screen structure plus overlays.

| Screen / surface | File | Role |
|---|---|---|
| Home | `screens/home_screen.dart` | Language selection (RU / EN), rules button, decorative tiles. **Re-entry v1.1:** dropped in favour of going straight to the game in the last-used language (§3). |
| Game | `screens/game_screen.dart` | Top bar (stamp badge + score + hint button), source word, grouped word slots, input bar, tile picker, action buttons. |
| Level complete | `widgets/level_complete_overlay.dart` | Full-screen overlay, confetti, final level score, next / home buttons. |
| Rules modal | `widgets/rules_modal.dart` | Bottom-sheet rules explanation; opens from home or in-game menu. Needs update for new hint system. |
| Language toggle | _bottom sheet in `game_screen.dart`_ | Switch RU ↔ EN mid-game. Survives into v1.1. |

#### Game-screen layout, top to bottom
1. **Top strip** — stamp badge (level #), session score, new in v1.1: *"3 bonus words to free hint · 1 hint banked"* mini-counter (hidden when both are zero).
2. **Source word** — the level's long word in Playfair Display Medium.
3. **Word slots** — grouped by length, with bonus words in their own amber-accented section below required.
4. **Input bar** — the tiles you've tapped, left-to-right, with Clear affordance.
5. **Tile picker** — the source letters in a wrapped grid, tappable.
6. **Action row** — Shuffle · Hint · Submit.

### 7.4 Motion & animation

All animations use `flutter_animate`. Timings and feel are deliberately understated — this is a notebook, not a slot machine.

| Event | Animation | Duration |
|---|---|---|
| Tile tap (select) | Scale up (1 → 1.05), soft shadow appears | ~120 ms ease-out |
| Tile deselect (via input or cascade) | Scale back, shadow fades | ~120 ms |
| Valid word submitted | Slot's letters reveal left-to-right, one by one; last-found word flashes briefly near the input | ~400 ms cascade; flash holds 1500 ms |
| Invalid / already-found submit | Horizontal shake of input bar | 400 ms |
| Level complete | Full-screen fade-in of overlay; confetti burst from top | ~500 ms fade; confetti ~2 s |
| **Hint reveal (new)** | Target letters **fade in** across all unfound slots simultaneously, with a light pulse on each; same navy ink, with the chosen visual treatment from §7.5 | ~250 ms fade; ~200 ms pulse |
| **Bonus-word refill earned (new)** | Small toast-style popup slides down from the top strip, holds, slides back up. Amber accent border. | ~300 ms in; ~2 s hold; ~300 ms out |

### 7.5 Open visual questions

#### Slot pre-fill treatment (hint reveal)

The pre-filled letter needs to be visibly the-game's-not-mine. Three candidates, same navy ink (readability), differing by secondary cue:

| Candidate | How it reads | Risk |
|---|---|---|
| **A. Italic** | Same glyph, angled | Subtle; may not register |
| **B. Underline** | Thin teacher's underline below the letter | **Lean.** Matches the notebook metaphor — a mark left by a helpful hand |
| **C. Muted amber** | Slightly warmer colour (between `foreground` and `accent`) | Risk of clashing with bonus-word amber elsewhere |

**Proposal:** **B (underline)** as default, revisit in playtest.

#### Top-of-screen counter strip

Needs to feel part of the notebook, not a HUD. Sketch target:

```
  [🎯1]  2·3·4         Score 240         [💡×1]
  —— 3 bonus words to free hint ——
```

- Left: level stamp.
- Centre: session score.
- Right: hint button with a subtle `×1` badge when a free hint is banked.
- Below (thin strip, `condensedLabel` type): progress-to-next-free-hint text; hides when counter is 0 and slot is 0.

This is a first sketch, not a commitment.

#### Rules-modal copy

Needs rewriting in both `StringsRu` and `StringsEn` to reflect:
- 3 hints per level cap (no per-level free).
- Safe-letter hint behaviour ("narrows without spoiling").
- Daily free hint, bonus-word accumulator, celebratory popup.

Draft copy lives with the implementation PR, not this doc.

### 7.6 Haptics & audio

#### Haptics (catalogue)

Using `HapticFeedback` from `package:flutter/services.dart` (D3 — not `flutter_vibrate`).

| Event | Haptic |
|---|---|
| Tile tap | `selectionClick` |
| Valid word submit | `mediumImpact` |
| Invalid / already-found submit | `heavyImpact` |
| Hint reveal | `mediumImpact` (new) |
| Free-hint refill earned | `mediumImpact` (new) |
| Level complete | `heavyImpact` (new — v1.0 has no haptic here) |

#### Audio (new in v1.1 — basic SFX scaffold)

v1.0 has no audio. v1.1 introduces a minimal SFX layer; music is out of scope for v1.x.

**Design principles:**
- **Short, dry, paper-adjacent.** Pencil ticks, paper rustles, a soft stamp. Nothing electronic, nothing musical.
- **Every sound is optional.** Respect device silent mode. Add a master mute toggle in-settings (v1.1 or v1.2).
- **Keep assets tiny.** Each clip < 50 KB (OGG or short MP3). Total audio asset budget < 500 KB.

**SFX catalogue:**

| Event | Tone | Notes |
|---|---|---|
| `tile_tap` | Soft pencil tick | Pitched very slightly to differentiate from silence; fires on every tap |
| `word_valid` | Short upward chime (two notes) | Wholesome confirmation |
| `word_invalid` | Dull muted thud (paper-crumple adjacent) | Never sharp or punitive |
| `hint_reveal` | Gentle page-flip or eraser brush | Quieter than word_valid |
| `free_hint_earned` | Same chime as word_valid, slightly longer | Rewarding moment |
| `level_complete` | Short celebratory flourish (still dry — a rubber stamp + paper rustle, not fanfare) | Paired with confetti |

**Package recommendation:** `audioplayers` (mature, cross-platform, cheap to initialise). Alternative: `flutter_soundpool` for lower-latency taps if `audioplayers` proves laggy on tile-tap.

**Asset sourcing:** freesound.org CC0 clips, Kenney's UI pack, or custom Foley. Author's call. Mark as content-pipeline task.

**State:** a new `AudioService` singleton, initialised in `main.dart`, owns the clip map and the mute flag. Mute flag persisted in `SettingsProvider` (existing).

### Decisions captured in this section
- **Soviet Notebook language preserved**; no visual-identity changes in v1.x.
- **Hint reveal visual:** underline under navy letters, as default (revisit in playtest).
- **Top-strip counter:** present when bonus counter > 0 or slot > 0; hidden otherwise.
- **SFX shipped in v1.1, music out of scope.** Respect silent mode, master mute toggle in settings.
- **Haptics extended**: hint reveal, free-hint earned, level complete.

### Open questions raised by this section
- **[§7.5] Final hint-reveal treatment** — confirm underline after first playtest, else fall back to italic.
- **[§7.5] Top-strip layout** — the sketch above needs a real design pass (fonts, spacing, where the counter line sits).
- **[§7.6] SFX asset sourcing** — freesound / Kenney / custom? Decide when building.
- **[§7.6] Settings screen** — mute toggle needs a home. v1.0 has no settings screen; do we surface it in the rules modal, as a gear icon on the home screen, or as a bottom sheet from the game top strip?
- **[§7] Rules modal copy** — needs rewriting in RU/EN to reflect new hint system; draft during v1.1 implementation.

## 8. Monetisation

### 8.1 Revenue model

Three revenue streams, all introduced in v1.1:

| Stream | Price | Type | Role |
|---|---|---|---|
| **Rewarded video ads** | $0 | Ad unit | Optional path to extra hints. Player-initiated, available to everyone (free & premium) |
| **Interstitial ads** | $0 | Ad unit | Fire between completed levels on a frequency cap. Stripped by premium |
| **Hint pack** | $0.99 | IAP, consumable | Adds 5 hints to the purchased-hint pool. Available to free & premium |
| **Premium** | $2.99 | IAP, non-consumable | Strips interstitial ads and triples the daily hint gift |

**Premium store copy** (locked):
> **Premium — $2.99**
> Skip the ads between levels. Triple your daily hints. Rewarded ads for extra hints stay optional.

No banners. No season passes. No subscriptions. No level-pack IAPs. No cosmetic IAPs. The audience and tone don't invite those mechanisms.

### 8.2 The hint waterfall

Hints flow from three possible sources, checked in order when the player presses Hint. The same waterfall applies to free and premium players — what differs is the **capacity of the free-hint slot** (1 vs 3).

1. **Free-hint slot** (cap 1 for free, 3 for premium). Refilled by daily gift (tops up to cap at local midnight) or bonus-word accumulator (10-to-1, same rate for all). Persists cross-session. Details in §4.5.
2. **Purchased-hint pool** (unbounded count). Bought in packs of 5 for $0.99. Persists cross-session. Carries the full real-world value of the purchase.
3. **Rewarded ad**. Offered only when the two pools above are empty. Available to **both free and premium players** — an ad is always player-initiated, never forced. A premium player's "no ads" promise is about *forced* ads (interstitials); rewarded ads are a voluntary tool to push past their daily allowance.
4. If the ad is dismissed or fails: no state changes. No hint, no progress, nothing.

The hard cap of **3 hints per level** and the **safe-letter algorithm** apply regardless of source. A player cannot exceed 3 hints per level or reveal an unsafe letter, no matter how many hint packs, daily refills, or ads they have.

**Persistence:**
- `purchasedHintCount: int` — consumable balance; never below 0.
- `premium: bool` — non-consumable entitlement.

**How the two IAPs interact.** Premium gives a bigger daily floor (3 hints/day) and removes interstitials. Hint packs give bulk hint balance. Both remain useful together:
- A casual premium player rarely needs hint packs — 3 hints/day plus bonus accumulator usually covers them.
- A premium power-user who burns their 3 daily quickly can buy packs for convenience, rather than watching rewarded ads.
- A free player who doesn't want to watch ads can buy packs to skip them altogether.
- Rewarded ads remain the free-forever fallback for anyone not wanting to spend.

### 8.3 Interstitial ads

Fire on the transition from **level-complete overlay dismissal → next level**. Not during active play, never covering gameplay content.

**Frequency cap:** every **2 completed levels**, never on levels 1–2 of a player's first session. Prevents an ad on the very first "next level" press. Counter persists cross-session so a returning player doesn't eat back-to-back ads.

**Persistence:**
- `levelsSinceLastInterstitial: int`
- `firstSessionLevelsCompleted: int` (used for the 1–2 exemption; caps at 2 and stops incrementing)

**Premium bypass:** interstitials are not shown to premium players, ever.

### 8.4 Rewarded ad placement & pacing

Only one rewarded placement in v1.x: the hint waterfall's step 3 (§8.2), when the player has no free or purchased hints and chooses to watch an ad rather than stop.

**Pacing cap:** no more than one rewarded ad per **30 seconds**, regardless of player action. Prevents tap-spamming into multiple ads.

**Ad never plays without reward** — already guaranteed by the availability rule in §4.5.

**Premium behaviour:** rewarded ads remain available to premium players as an optional path. The difference from free players is that premium rarely reaches this step — their cap-3 daily gift usually covers hint demand. When they do choose to watch an ad, no state or setting prevents it.

### 8.5 Ad provider

**AdMob only for v1.1.** Meta Audience Network / mediation layer (ironSource, AppLovin MAX) are deferred to post-launch — CPM analysis after 2–4 weeks of live data determines whether the engineering lift for mediation is justified.

Technical boundary remains the `AdGateway` abstraction (§9.3). `MobileAdsGateway` is the concrete v1.1 implementation. Swapping in a mediated provider later means replacing the gateway, not touching game code.

`AdGateway` grows from a single method to two (`adsEnabled` is dropped — premium gating is explicit at call sites, not inside the gateway, because rewarded ads remain available to premium players):

```dart
abstract class AdGateway {
  Future<bool> showRewardedAd();
  Future<void> showInterstitial();  // fire-and-forget; failures are silent
}
```

Call-site logic for interstitials checks `RewardsProvider.premium` directly before invoking the gateway. Rewarded ads are never gated on premium status — they're always offered at step 3 of the hint waterfall for any player who reaches it.

### 8.6 IAP implementation notes

- Package: `in_app_purchase` (Flutter official).
- Products:
  - `hint_pack_5` — consumable, $0.99 / equivalent tiers. Localised title + description in EN and RU.
  - `premium` — non-consumable, $2.99 / equivalent tiers. Localised title + description in EN and RU. Use the store-copy wording from §8.1 verbatim (translated faithfully to Russian — not a literal translation, an equivalent-tone rewrite).
- Both App Store Connect and Google Play Console need the products configured with localised copy in English and Russian before submission.
- **"Restore purchases" button** is required by both stores for non-consumable IAPs. Goes in a settings surface (see §7.6 open question — settings screen needs a home).
- **Receipt validation** — v1.1 relies on platform-level receipts surfaced by `in_app_purchase`. No server-side validation (no backend). Accept the cost: a motivated user could side-load or jailbreak to fake premium. Not worth fighting at this scale.
- **Premium entitlement sync** — on app launch, query `in_app_purchase` for current entitlements and refresh the `premium` flag in `shared_preferences`. Handles reinstalls via platform restore.

### 8.7 Privacy, compliance, rating

- App declared **not directed at children**. Content rating 13+.
- **Personalised ads on by default** via AdMob, gated by the platform consent dialogs (ATT on iOS, UMP / Consent Mode on Android).
- **Data safety declaration** on both stores: no data collection tied to identity, ad SDK advertising ID access disclosed per AdMob guidance.
- No custom analytics collecting PII (v1.1 analytics — §10 — is firmly anonymous).
- GDPR / UK-GDPR / CCPA: because there is no user account and no server-side storage, the compliance surface is limited to ad SDK handling. AdMob's consent flows handle the regional logic.

### 8.8 Price points (international)

US baseline: $0.99 and $2.99. Rely on App Store / Play Store regional pricing tiers to localise — no custom logic. Russian-language markets (Russia, Israel, Germany, UK) receive pricing at the store's auto-computed local tier.

**Note for the Russia store specifically:** IAP via Apple and Google in Russia has been disrupted since 2022; many players cannot complete purchases. This makes the Russia store an **ad-only revenue market** in practice. Plan accordingly — IAP forecasts for that market should be ≈ zero.

### 8.9 Non-revenue commitments

- **No ads ever during active gameplay** (mid-level). Only at level-complete transitions and player-initiated hint presses.
- **No dark patterns.** No "ads you must watch to continue" disguised as rewarded. No fake X-button interstitials. No confirmshaming around premium purchases.
- **Premium is forever.** Not a time-limited subscription, not a "premium tier with still some ads." The only ads a premium player ever sees are rewarded ads they voluntarily request.
- **Rewarded ads are always optional**, for every player. Never the only way forward. When a free player has no free-hint slot, no purchased pool, and doesn't want to watch an ad, they can simply stop and play elsewhere — the level is still beatable without any hint (§4.5 safety rule guarantees hints never complete a word anyway).
- **No monetisation of content not yet built.** No pre-selling of post-launch packs.

### Decisions captured in this section
- **Two IAPs:** hint pack ($0.99, 5 consumable hints) and Premium ($2.99, permanent).
- **Premium's perks:** no interstitials, free-hint slot cap raised from 1 to 3 (triple the daily gift). Bonus-word accumulator rate unchanged.
- **Rewarded ads remain available to premium players** as an optional path past the daily cap. The "no ads" promise covers forced ads only.
- **Hint waterfall (free & premium, same order):** free-hint slot → purchased pool → rewarded ad. No hint ever exceeds the 3/level cap or violates the safe-letter rule.
- **Interstitial ads at level-complete, every 2 levels**, skipped on first-session levels 1–2. Stripped entirely by premium.
- **Premium store copy locked** (EN): *"Skip the ads between levels. Triple your daily hints. Rewarded ads for extra hints stay optional."* Russian translation is equivalent-tone, not literal.
- **AdMob only at launch.**
- **Not directed at children, 13+, personalised ads on** behind platform consent.
- **No server-side receipt validation**, no backend; platform receipts are trusted.

### Open questions raised by this section
- **[§8.6] Settings screen location** — remove-ads purchase button, restore-purchases button, hint-pack store, and the audio mute toggle (§7.6) all need a surface that doesn't exist yet.
- **[§8.3] Interstitial suppression on first level of any future sessions** — is the 1-2 levels exemption first-session-only (current plan), or per-app-launch? First-session-only is cleaner but may feel abrupt for occasional players.
- **[§8.5] Mediation decision post-launch** — revisit at 2–4 weeks based on CPM data.
- **[§8.8] Russia market ad-only posture** — do we still release in Russia given the IAP friction, or hold? Affects §12 launch plan.

## 9. Technical architecture

A summary of how the app is built. For day-to-day dev, `CLAUDE.md` remains the authoritative cheat sheet — this section is the GDD view of the same ground, plus the v1.1 additions implied by earlier sections.

### 9.1 Platform & stack

- **Flutter** (Dart SDK `>=3.3.0 <4.0.0`), iOS + Android. **No web**, no desktop.
- **Portrait only** — locked in `main.dart`.
- **No backend.** All level data bundled as JSON assets; no network dependency post-install (except Google Fonts on first run, per D2).

**Core packages (v1.0, from `pubspec.yaml`):**
- `provider` — state management (ChangeNotifier-based)
- `flutter_animate` — declarative animation (also used to home-roll the level-complete confetti in `level_complete_overlay.dart` — no separate `confetti` package)
- `google_fonts` — runtime font loading (D2)
- `shared_preferences` — persistent settings
- `flutter_localizations` — date/locale formatting

**New packages for v1.1:**
- `google_mobile_ads` — rewarded + interstitial ads, currently commented out in `pubspec.yaml` (§8)
- `in_app_purchase` — premium + hint-pack IAPs (§8)
- `audioplayers` — SFX playback (§7.6)
- `firebase_core`, `firebase_analytics`, `firebase_remote_config`, `firebase_crashlytics` — analytics, tuning, crash reporting (§10)
- `app_tracking_transparency` — iOS ATT consent prompt (§8.7)

### 9.2 Directory layout

```
lib/
├── main.dart                  # Entry, portrait lock, provider tree
├── app.dart                   # MaterialApp + theme + home
├── engine/                    # Pure static logic
│   ├── game_engine.dart       # letterCount, canFormWord, validateWord, scoreWord, isLevelComplete
│   └── level_loader.dart      # JSON load + validation + cache
├── models/                    # Immutable data
│   ├── game_state.dart        # LetterTile, TargetWord, GameLevel, GameState
│   └── language_mode.dart
├── providers/                 # Mutable state
│   ├── game_provider.dart
│   └── settings_provider.dart
├── screens/
│   ├── home_screen.dart
│   └── game_screen.dart
├── theme/
│   └── app_theme.dart         # Single source of truth for colour + type
├── widgets/                   # Reusable UI (tile, slots, overlay, background, etc.)
└── l10n/
    ├── strings_ru.dart
    └── strings_en.dart
```

For every file's role see `CLAUDE.md`.

### 9.3 State management

**Pattern.** Each provider owns a slice of mutable state as an immutable object. Mutations go through `copyWith` + `notifyListeners`. UI reads via `context.watch<T>()` in `build`, `context.read<T>()` in callbacks.

**Current providers (v1.0):**
- `GameProvider` — tile selection, word submission, hints, level advance. Holds a `GameState`.
- `SettingsProvider` — language mode. Persists to `shared_preferences`.

**New services for v1.1:**
- **`RewardsProvider`** (new) — cross-session rewards + entitlement economy. Owns `freeHintSlot: int` (0..cap), `bonusWordCounter: int` (0..9), `lastDailyClaimedOn: String` (ISO date), `purchasedHintCount: int`, `premium: bool`. Derives current slot cap from `premium`. Persists to `shared_preferences`. Exposes `claimDailyIfDue()`, `incrementBonusCounter()`, `consumeFreeHint()`, `consumePurchasedHint()`, `addPurchasedHints(count)`, `setPremium(bool)`.
- **`AdGateway`** (new, abstract) — `Future<bool> showRewardedAd()`. `NoopAdGateway` for dev/tests; `MobileAdsGateway` for production (binds to `google_mobile_ads`).
- **`AudioService`** (new, singleton) — plays SFX clips keyed by event. Mute flag read from `SettingsProvider`. Initialised in `main.dart`.

### 9.4 Engine layer

`engine/game_engine.dart` is **pure static functions** with no side effects. New v1.1 additions:

- `pickSafeHintLetter({targetWords, revealedLetters}) → String?` — the safe-letter algorithm (§4.5). Returns null when no safe letter exists.
- `scoreRequiredWord(word) → int` — explicit function for clarity; same formula as v1.0.
- `scoreBonusWord(word) → int` — flat 15 in v1.1.

All new functions testable without touching providers.

### 9.5 Data assets

- `assets/data/russian_levels.json`
- `assets/data/english_levels.json`

Schema per §5.1 (existing) plus `difficulty: 1..5` (§5.2, new). `LevelLoader` validates all words against the source word via `GameEngine.canFormWord()` at load, caps required words at 12 (historical — D5 removed on v2; required-word counts now governed by difficulty profiles per D16), drops overflow silently.

No runtime mutation of level data. No network fetch. Fonts are the only runtime dependency, and they cache after first use.

### 9.6 Persistence

`shared_preferences` is the only storage medium. Keys:

| Key | Today | v1.1 addition |
|---|---|---|
| `languageMode` | ✓ (existing) | — |
| `freeHintSlot` | — | ✓ (0..1 free, 0..3 premium) |
| `purchasedHintCount` | — | ✓ |
| `premium` | — | ✓ |
| `bonusWordCounter` | — | ✓ |
| `lastDailyClaimedOn` | — | ✓ |
| `audioMuted` | — | ✓ |
| `highestCompletedLevel.{ru,en}` | — | **Parked** — depends on §6 meta decisions |

No SQLite, no secure storage, no cloud sync in v1.x.

### 9.7 Testing

- `test/` holds 10 unit tests today; all pass. `flutter analyze` is zero-issue on `main`.
- **New tests needed for v1.1:**
  - `pickSafeHintLetter` picks highest-frequency safe letter; never returns a completing letter; returns null when every candidate is unsafe.
  - Bonus words are ignored in the safety check but included in slot pre-fill.
  - `RewardsProvider` daily-gift logic: grants on day flip, skips when slot is full.
  - `RewardsProvider` bonus counter: increments, freezes at 9, resets on refill.
  - `GameProvider` pending-and-bank scoring: banks on level-complete, discards on abandon.
  - `AdGateway` contract: `showRewardedAd() → false` mutates no state.

### 9.8 Build, release, CI

- Local builds via `flutter build apk --release` (Android) and `flutter build ios --release` (iOS).
- No CI/CD pipeline configured yet. This is a pre-launch gap — tests exist but nothing gates a merge on them.
- App icon and splash screen are still Flutter defaults (flagged in CLAUDE.md as pending).

### 9.9 Conventions (reference)

Reiterated from `CLAUDE.md` for completeness:
- Models immutable, mutated via `copyWith`.
- Engine methods pure static.
- No inline colours or font sizes outside `app_theme.dart`.
- All user-visible strings via `StringsRu` or `StringsEn`.
- `context.watch` in `build`; `context.read` in callbacks.
- `flutter analyze` must be zero-issue before any commit.

### Decisions captured in this section
- **`RewardsProvider` is the home for cross-session hint economy state** (slot, counter, daily timestamp).
- **`AdGateway` is the boundary for monetisation code**; game logic never touches the ad SDK directly.
- **`AudioService` is a singleton**, not a Provider — it has no observable state the UI cares about beyond the global mute flag, which lives in `SettingsProvider`.

### Open questions raised by this section
- **[§9.6] Per-language level progress persistence** — depends on §6 meta decision about resuming last played level. If yes, add `highestCompletedLevel.{ru,en}` keys.
- **[§9.8] CI/CD** — do we want a GitHub Action running `flutter analyze && flutter test` on every PR before launch? Low-effort, high-value. Flag for roadmap (§12).
- **[§9.1] Dependency audit pre-launch** — `google_mobile_ads` and `audioplayers` both add binary weight. Worth a size audit before store submission.

## 10. Analytics & KPIs

### 10.1 Provider

**Firebase** is the analytics + tuning + crash-reporting platform for v1.1. Specifically:

- **Firebase Analytics** — event stream, user properties, audience definitions.
- **Firebase Remote Config** — post-launch tuning of every provisional number (§10.5).
- **Firebase A/B Testing** — sits on Remote Config, runs controlled experiments.
- **Firebase Crashlytics** — crash reporting. Free, essential pre-launch.

Adding Firebase is also a strategic choice — it establishes the only server-side relationship the app has, without contradicting the "no backend" posture in §9.1. Everything Firebase offers is client-to-Google, not a server we own.

**Packages:** `firebase_core`, `firebase_analytics`, `firebase_remote_config`, `firebase_crashlytics`.

### 10.2 Primary KPIs — the dashboard

Eight metrics define "is this working." Reviewed weekly in the first 90 days, monthly thereafter.

| # | KPI | Definition | Casual-word-game benchmark | What it tells us |
|---|---|---|---|---|
| 1 | **Retention D1 / D7 / D30** | % of installers returning at each horizon. Split by `language_mode`. | D1 40–45%, D7 15–20%, D30 5–10% | Stickiness; per-language product-market fit |
| 2 | **Sessions per WAU per week** | Sessions / weekly active users | 3–7 is healthy; < 2 = not habit-forming | Does the game earn its spot on the home screen |
| 3 | **Avg session length** | App open → background | 3–8 min | Session health |
| 4 | **Levels completed per WAU per week** | Sum of `level_complete` / weekly active users | ≥ 4–5 | Pacing vs difficulty |
| 5 | **Hint adoption rate** | % of sessions with ≥ 1 `hint_delivered` | 30–55% sweet spot | Economy + difficulty health |
| 6 | **Ad fill rate / eCPM** | Rewarded + interstitial, from AdMob | Fill ≥ 95%; eCPM $5–15 US | Revenue infrastructure + audience value |
| 7 | **IAP conversion rate** | % of DAU completing a purchase, split by product | Hint pack 1–3%, Premium 0.5–2% | Monetisation economy |
| 8 | **Qualitative anchor** | Monthly sample of 50 store reviews tagged for family / learning / bonding themes | No numeric benchmark; rising trend = win | Tracks the §1.4 qualitative success criterion |

### 10.3 Secondary metrics — auto-logged, surfaced on demand

Available in the raw event stream, not on the default dashboard:

- Free-hint slot utilisation (% sessions ending with slot full)
- Avg bonus words found per level, per language
- Replay rate (% `level_complete` events that are replays)
- Streak distribution (median + p90 of active streaks)
- Per-achievement unlock rate
- Funnel: `iap_viewed → iap_started → iap_completed`
- Geographic split of each primary KPI

### 10.4 Event taxonomy

Fired from the app, prefixed where helpful. Firebase auto-logs `first_open`, `session_start`, `session_end`, `screen_view`, `app_update`.

#### Session / lifecycle
| Event | Parameters |
|---|---|
| `app_open` | `language_mode`, `is_premium`, `streak_count` |
| `language_changed` | `from`, `to` |

#### Gameplay
| Event | Parameters |
|---|---|
| `level_start` | `level_id`, `language`, `difficulty`, `attempt_number` |
| `level_complete` | `level_id`, `language`, `duration_sec`, `hints_used`, `bonus_words_found`, `invalid_submissions`, `score_banked`, `is_replay` |
| `level_abandoned` | `level_id`, `language`, `duration_sec`, `words_found`, `required_remaining`, `hints_used` |
| `word_submitted` | `result` (valid / invalid / already_found), `word_length`, `is_bonus` |

#### Hint economy
| Event | Parameters |
|---|---|
| `hint_requested` | `level_id`, `hints_used_this_level` |
| `hint_delivered` | `source` (free_slot / purchased / ad), `level_id`, `revealed_letter` |
| `hint_unavailable_pressed` | `reason` (cap / no_safe_letter) — defect signal, shouldn't fire if button state is correct |
| `free_hint_earned` | `source` (daily_gift / bonus_accumulator) |
| `bonus_counter_progress` | `counter_value` — sampled on increment |

#### Ads
| Event | Parameters |
|---|---|
| `ad_requested` | `placement` (hint / interstitial), `ad_unit_id` |
| `ad_shown` | `placement` |
| `ad_completed` | `placement` |
| `ad_dismissed` | `placement`, `dismiss_time_sec` |
| `ad_failed` | `placement`, `error_code` |

#### Monetisation
| Event | Parameters |
|---|---|
| `iap_viewed` | `product_id`, `surface` (home / shop / upsell) |
| `iap_started` | `product_id` |
| `iap_completed` | `product_id`, `price_localised`, `currency` |
| `iap_cancelled` | `product_id` |
| `iap_failed` | `product_id`, `error_code` |
| `premium_restored` | _(no params)_ |

#### Meta
| Event | Parameters |
|---|---|
| `achievement_unlocked` | `achievement_id` |
| `streak_day` | `streak_count`, `is_new_high` |
| `daily_challenge_attempted` | `date`, `level_id` _(v1.2+)_ |

#### User properties (set once or on change)
- `language_mode_current` (ru / en)
- `is_premium` (bool)
- `highest_level_ru` (int)
- `highest_level_en` (int)
- `lifetime_hints_used` (int, bucketed)

### 10.5 Remote Config — tunable parameters

Every provisional number in §4–§8 is fetched from Remote Config at launch, with a hardcoded fallback. Cache refreshes hourly; first-launch uses the fallback until the first successful fetch.

#### Scoring tunables
| Key | Default | §Ref |
|---|---|---|
| `score_required_multiplier` | 10 | §4.4 |
| `score_length_bonus_4` | 10 | §4.4 |
| `score_length_bonus_5` | 20 | §4.4 |
| `score_length_bonus_6plus` | 30 | §4.4 |
| `score_bonus_word_flat` | 15 | §4.4 |

#### Hint economy tunables
| Key | Default | §Ref |
|---|---|---|
| `hints_per_level_cap` | 3 | §4.5 |
| `free_slot_cap_free` | 1 | §4.5 |
| `free_slot_cap_premium` | 3 | §4.5 / §8.2 |
| `bonus_accumulator_threshold` | 10 | §4.5 |
| `hint_pack_size` | 5 | §8.2 |

#### Ad pacing tunables
| Key | Default | §Ref |
|---|---|---|
| `interstitial_every_n_levels` | 2 | §8.3 |
| `interstitial_first_session_exempt_levels` | 2 | §8.3 |
| `rewarded_ad_cooldown_sec` | 30 | §8.4 |

#### Feature flags (emergency off-switches)
| Key | Default |
|---|---|
| `feature_streaks_enabled` | `true` |
| `feature_achievements_enabled` | `true` |
| `feature_daily_challenge_enabled` | `false` (v1.1) → `true` (v1.2+) |
| `feature_audio_enabled` | `true` |

All tunables have a runtime default in code; Remote Config overrides if fetch succeeds. Offline or first-run behaviour always uses the hardcoded defaults — the app never blocks on a fetch.

### 10.6 A/B testing

Firebase A/B Testing rides on Remote Config. Experiments we'd want to run in the first 90 days post-launch:

1. **Interstitial cadence** — every 2 vs every 3 levels, measured against D7 retention and total ad revenue per DAU.
2. **Bonus-word threshold** — 8 vs 10 vs 12, measured against hint-adoption rate and IAP conversion.
3. **Daily gift cap, free tier** — 1 vs 2, measured against retention and ad impressions.
4. **Premium price** — $2.99 vs $3.99, measured against conversion × price for total ARPDAU.

Each experiment: 7–14 day run, minimum detectable effect ≈ 10%, sample size guard (don't cut before audience is big enough).

### 10.7 Crashlytics

Crash reporting wired from day one of v1.1.

- Non-fatal errors logged for the ad gateway, IAP, and Remote Config fetch paths — these are the surfaces most likely to fail silently.
- Custom keys set per session: `language_mode`, `is_premium`, `current_level`. Helps triage crash grouping.
- Pre-launch: **zero crashes in internal testing** is the gate. Post-launch: crash-free-sessions > 99.5% as a health target.

### 10.8 Privacy & compliance

- Firebase Analytics collects pseudonymous device identifiers (Firebase Installation ID). No PII collected by the app itself.
- AdMob's personalised-ads path handles consent (ATT on iOS, UMP on Android per §8.7). Analytics events continue to fire under non-consent — Firebase is not an ad tracker.
- **Data safety declarations** on both stores disclose: analytics (app activity), crash logs (diagnostics), purchase history (financial). All covered by Firebase + AdMob standard declarations.
- Children / COPPA: declared not directed at children (§8.7), so no special handling required.
- Retention: Firebase raw event data retained for default 14 months; aggregate dashboards retained indefinitely.

### Decisions captured in this section
- **Firebase is the full analytics + RC + A/B + Crashlytics stack** for v1.1.
- **Eight-KPI dashboard locked**, reviewed weekly then monthly.
- **Full event taxonomy locked**; shipped v1.1, never retroactively recoverable if we don't log it.
- **Every provisional number** in §4–§8 is Remote-Config-tunable with hardcoded fallback.
- **Four priority A/B tests queued** for the first 90 days post-launch.
- **Crashlytics is a pre-launch gate** — internal builds must be crash-free before store submission.

### Open questions raised by this section
- **[§10.6] A/B test priority order** — which experiment runs first is a post-launch call based on what the data shows needs tuning soonest.
- **[§10.2 KPI 8] Review-tagging workflow** — manual sample of 50 reviews / month is fine for v1.1 but gets expensive. Consider automating with keyword-matching once language parity data matters.
- **[§10.5] Remote Config caching** — hourly default, but should some values (feature flags) be fetched eagerly on foreground? Lean no — simplicity wins. Revisit if an incident demands fast rollback.

## 11. Accessibility & localisation

### 11.1 Accessibility commitment

**Target: best-effort WCAG 2.1 Level AA**, held to high standards internally, without pursuing formal third-party certification. The audience includes older immigrants and second-gen children; accessibility here isn't compliance theatre, it's audience fit.

### 11.2 Contrast & colour

All text and interactive elements meet **WCAG AA contrast ratios**: 4.5:1 for normal text (< 18pt or < 14pt bold), 3:1 for large text and non-text UI (borders, icons).

Current palette audit against AppTheme tokens (§7.2):

| Pair | Ratio | Status |
|---|---|---|
| `foreground` on `background` | ~15:1 | ✅ AA+ |
| `primary` on `background` | ~5.8:1 | ✅ AA |
| `primaryFg` on `primary` | ~5.6:1 | ✅ AA |
| `accent` on `background` | ~2.4:1 | ⚠ Fails normal text — **bonus-word amber must never be used for text under 18pt.** Use amber only as an accent (borders, slot outlines, tile badges). Any text-carrying amber surface must fall back to a darker variant. |
| `mutedFg` on `background` | ~3.5:1 | ✅ large text only; never for body |
| `slotFilled` on `background` | ~15:1 | ✅ AA+ |

**Action item for v1.1:** audit all existing uses of `accent` in widgets to confirm none are carrying body text. If any are found, swap to `foreground` or introduce a new `accentText` token with AA-compliant contrast.

**Never conveys meaning with colour alone.** Bonus vs required words are distinguished by section header + placement, not just colour. Errors are shake + heavy haptic, not red-only.

### 11.3 Tap targets

Minimum **44×44 logical pixels** for every interactive element. Current state:

- Letter tiles: 48×48. ✅
- Action buttons (Shuffle, Hint, Submit, Clear): need to audit. Any below 44×44 padding to be padded up.
- Level-picker tiles: design to ≥ 56×56 for an older-thumb-friendly experience.
- Modal close buttons: 44×44 minimum with a clear hit zone.

### 11.4 Dynamic type

Respect the OS text-size preference on both platforms. Ships in v1.1.

**Scaling rules:**
- Body and label text: scales with `MediaQuery.textScaler`.
- Source word headline: scales, but capped at 1.3× to preserve layout stability (the word must fit on one line on the smallest supported device).
- Tile letters: **fixed size** — the grid layout depends on predictable tile footprint. This is a deliberate a11y exception and is documented in-app on the first launch if the player has a large text-size preference.
- Level-complete overlay score + labels: scales freely.

**Minimum supported device:** iPhone SE (2020) / Android 360dp width. Layout must not break at 200% text scale on these devices.

### 11.5 Reduced motion

Respect `MediaQuery.disableAnimations` (derived from iOS Reduce Motion and Android Remove Animations). When enabled:

| Animation | Reduced-motion behaviour |
|---|---|
| Confetti on level-complete | Replaced with a single static amber burst + static "Level Complete" banner |
| Slot letter-reveal cascade | Instant fill, no stagger |
| Invalid-submit shake | Replaced with a one-frame highlight (border flash) + heavy haptic |
| Tile scale-on-tap | Reduced amplitude (scale stops at 1.02, no shadow animation) |
| Hint reveal fade + pulse | Instant fill, no pulse |
| Free-hint-earned popup | Slides disabled → instant show + instant hide, full duration preserved so player has time to read |

Implementation pattern: wrap every animation call in a helper `maybeAnimate(context, builder)` that checks `MediaQuery.of(context).disableAnimations` and either returns the animated widget or its end-state equivalent.

### 11.6 Screen readers

**v1.1: minimum viable.** All critical interactions work with VoiceOver (iOS) and TalkBack (Android).

Scope for v1.1:
- Letter tiles have semantic labels: *"Letter С, tap to add to word"* (RU) / *"Letter S, tap to add to word"* (EN).
- Word slots: *"Three-letter word, empty"* / *"Three-letter word, filled: bar"*.
- Source word announced on level start.
- Submit / Clear / Shuffle / Hint buttons have full labels including their current state (*"Hint button, disabled: no safe letter available"*).
- Level-complete overlay is announced with the full score and next-action prompts.
- Hint reveal: announce *"Letter A revealed, appearing in 2 slots"*.

**v1.2: full pass.** Formal screen-reader walk-through covering:
- Focus order across the whole game screen.
- Gesture customisation (double-tap to submit without reaching Submit button).
- Achievement / streak / daily-challenge announcements.
- Rules modal accessibility.

All semantic labels flow through `StringsRu` / `StringsEn` alongside visible copy — no hardcoded a11y text.

### 11.7 A11y testing plan

**Pre-v1.1-launch gate:**
1. **Manual audit on minimum device** (iPhone SE + a ~360dp Android). Every screen at 100% and 200% text scale, reduced-motion on and off.
2. **VoiceOver walkthrough** (iOS) and **TalkBack walkthrough** (Android) — one full session per language (4 walkthroughs total). Complete at least one level per walkthrough without touching the screen visually.
3. **Contrast audit** — every token pair checked with a contrast tool (e.g. Stark in Figma or an online checker). Produce a one-page report stored in `docs/a11y/contrast.md`.
4. **Colour-blindness simulation** — run the game screen through deuteranopia and protanopia filters (Xcode / Android Studio built-in tools); confirm bonus vs required distinction still reads.
5. **Tap-target audit** — overlay a 44×44 grid on every screen screenshot; flag any misses.

**Ongoing:**
- Every PR touching UI includes an a11y note in the description: *"Verified: contrast, tap targets, semantic labels."*
- CI (§9.8, when it exists) runs `flutter test` including accessibility-focused widget tests — at minimum, Semantics-tree snapshots for key screens.

**Post-launch:**
- Track `screen_reader_active` property if Firebase can surface it (device-level signal). Light-touch — just to know the audience proportion.
- Invite 2–3 screen-reader users from the audience for informal feedback post-launch.

### 11.8 Localisation — current and ongoing

**Approach (unchanged from v1.0, D9):** hand-authored `StringsRu` and `StringsEn` Dart constant classes. Simple, type-safe, no codegen or ARB pipeline.

Scope of localised content:
- All user-visible UI text
- Rules modal copy (to be rewritten for v1.1, §7.5)
- Screen-reader semantic labels (§11.6)
- Level data — authored natively in each language, not translated (§5.4)
- Store listing copy (both languages on both stores from day one)
- IAP product titles and descriptions (§8.6)

**Pluralisation and gender.** Russian is a pluralisation-heavy language (1 / 2–4 / 5+ forms). Any UI string with a count needs a dedicated helper that returns the right form. `StringsRu` will gain a small `plural(count, singular, few, many)` utility for this. Examples: "1 слово найдено" / "2 слова найдены" / "5 слов найдено." English stays with the simple `count == 1 ? singular : plural` rule.

### 11.9 Not supported

- **Right-to-left layout.** Neither RU nor EN is RTL, and no future languages are planned. Mirroring infrastructure not introduced.
- **Additional languages beyond RU and EN.** Locked. The product's identity is bilingual-for-the-diaspora; more languages would dilute, not broaden.

### Decisions captured in this section
- **Best-effort WCAG 2.1 AA**, internal standards high; no third-party audit.
- **Dynamic type supported in v1.1**, with tile letters as a documented fixed-size exception.
- **Reduced motion supported in v1.1** with specific reductions per animation.
- **Screen readers: minimum viable v1.1**, full pass in v1.2.
- **No further languages beyond RU and EN**; no RTL support.
- **Russian pluralisation helper** added to `StringsRu`.
- **Pre-launch a11y testing plan locked** (5-step gate + ongoing PR discipline).

### Open questions raised by this section
- **[§11.2] Accent-on-body-text audit** — action item in v1.1 kickoff; may produce a new `accentText` token.
- **[§11.3] Action-button tap-target audit** — small check but must happen before v1.1 ships.
- **[§11.4] Large-text first-launch explainer** — how do we briefly tell a player that their very-large-text preference doesn't scale the tiles? Toast, hint in rules, or silently accept the tile-label mismatch? Lean: subtle one-time message.
- **[§11.7] Post-launch screen-reader user panel** — worth the effort and who organises it?

## 12. Roadmap

### 12.1 Release philosophy

**One big pre-launch release (v1.1), then incremental post-launch.** v1.1 *is* the launch version — everything in this GDD that is not flagged as post-launch lands together before store submission. After launch, releases are smaller and driven by analytics + user feedback rather than a master plan.

### 12.2 v1.0 — shipped

Already on `main`. Full v1.0 scope documented in `CLAUDE.md`. Summary:

- 23 RU + 20 EN levels, all validated
- Full core gameplay (tile selection, word submission, scoring, hints `×3`, level complete)
- Soviet Notebook design system
- Bilingual UI (RU / EN)
- Home screen with language selection, in-game language toggle
- No ads, no IAP, no analytics, no persistence beyond language mode
- Flutter analyze zero-issue, 10 unit tests passing

### 12.3 v1.1 — launch version

Everything in this GDD except items explicitly flagged as v1.2+. Grouped by workstream:

#### Product
- **Re-entry flow** — straight into game in last-used language, resuming at start of last-played level (§3, §6.1)
- **Level picker** — hybrid progression surface (§6.2)
- **Three scoring surfaces** — session, per-level best, lifetime total per language (§6.3)
- **Streaks** with gentle framing (§6.4)
- **Achievements** — 14-badge starter set (§6.6)

#### Scoring & hint economy rework
- Bonus words to flat 15 pts (§4.4)
- Pending-and-bank scoring (§4.4)
- Safe-letter hint algorithm (§4.5)
- Free-hint slot (cap 1 free / 3 premium), daily gift, bonus-word accumulator (§4.5, §8.2)
- Slot pre-fill reveal style with underline treatment (§4.5, §7.5)
- Celebratory popup + top-strip progress indicator (§4.5, §7.5)

#### Monetisation
- AdMob integration — rewarded + interstitial (§8.3, §8.4, §8.5)
- IAPs: Premium ($2.99) and Hint pack ($0.99 × 5) via `in_app_purchase` (§8.6)
- Consent flows (ATT / UMP) and store compliance declarations (§8.7)
- Restore-purchases UI and entitlement sync (§8.6)

#### Analytics + tuning
- Firebase Analytics full event taxonomy (§10.4)
- Firebase Remote Config on every provisional number (§10.5)
- Firebase Crashlytics with zero-crash pre-launch gate (§10.7)

#### Content
- **Launch bar: 50 / 50 levels** per language (§12.8)
- Add `difficulty: 1..5` field to level schema; tag all existing levels (§5.2)
- Re-order levels into a deliberate difficulty curve (§5.3)

#### Accessibility (§11)
- Dynamic type support with tile-letter exception
- Reduced-motion fallbacks per animation
- Screen-reader MVP (tiles, slots, source word, hint reveals, level-complete)
- WCAG AA contrast audit — resolve the `accent`-on-body-text issue (§11.2)
- 44×44 tap-target audit
- Pre-launch a11y testing plan executed (§11.7)

#### Audio (new — §7.6)
- 6-event SFX catalogue via `audioplayers`
- Mute toggle in settings surface (see v1.1 infrastructure)

#### Infrastructure
- New **settings screen** — home for mute toggle, remove-ads/restore purchases, rules, language. Resolves multiple open questions (§7.6, §8.6, §11.4).
- New **`RewardsProvider`** with `shared_preferences` persistence for the full state set in §9.6
- **`AdGateway`** abstraction with `MobileAdsGateway` + `NoopAdGateway` implementations (§9.3)
- **`AudioService`** singleton (§9.3)
- **Persistence additions** per §9.6 table
- **Russian pluralisation helper** in `StringsRu` (§11.8)
- **App icon and splash screen** — final assets replace Flutter defaults
- Rules modal copy rewritten in RU and EN (§7.5)

#### Quality gates
- CI on every PR running `flutter analyze && flutter test` (§9.8)
- Internal test pass on iPhone SE + small Android before submission
- Zero-crash pre-launch per Crashlytics (§10.7)

### 12.4 v1.2 — first post-launch

Target: ship 6–12 weeks after v1.1 launch, driven by what analytics reveal.

- **Daily challenges** — deterministic pick from library, small completion reward (§6.5)
- **Screen-reader full pass** — focus order, gesture shortcuts, achievement/streak announcements, rules modal (§11.6)
- **Content growth: 50 → 100 levels per language** (§12.8)
- **Remote Config tunes** applied from observed data (§10.5)
- **Retroactive achievement backfill** for players upgrading from v1.1 (§6.6)
- **First round of A/B experiments** (interstitial cadence, bonus threshold) reported and acted on (§10.6)

### 12.5 v1.3+ — post-launch horizon

Not planned, only flagged. Priorities set by post-launch data.

- **Leaderboards** via Game Center + Play Games Services — no custom backend (§6.7)
- **Themed special levels** (Pushkin, Tolstoy, holidays, cultural moments) as Daily Challenge evolution (§6.5)
- **Ad mediation** (AdMob + Meta Audience Network or AppLovin MAX) if CPM analysis justifies (§8.5)
- **Social sharing** — "I scored X on level Y" card generation for outbound messaging apps
- **Authoring tool** for levels — semi-formal pipeline (§5.5)
- **Geographic expansion** — major Russian-speaking diaspora markets outside the US (§12.7)

### 12.6 Explicit non-goals (reiterated)

These are not on any roadmap. Listing them here prevents scope creep via "when are we going to…?" requests.

- User accounts / profiles (§6.7)
- Cloud save / cross-device sync (§6.7)
- Friends, invites, social multiplayer (§6.7)
- RTL layout (§11.9)
- Additional languages beyond RU / EN (§11.9)
- Pre-paid content packs / season passes (§8.1)
- Real-money competitive play
- Dictionary-backed open word entry (§4.3 — only revisited if post-launch data shows strong player demand)

### 12.7 Launch geography

**US only at launch.** Target is Russian speakers *in the US* — the diaspora wedge in §2.1. App Store and Play Store listings live in US stores with both EN and RU copy available.

Explicitly **not** at launch:
- Russia (IAP disrupted since 2022 per §8.8; revisit post-launch with ad-only posture)
- Israel, Germany, UK, Canada, Australia (v1.3+ geographic expansion)

### 12.8 Launch content bar

**50 levels per language minimum**, grown to **100 per language across the first 90 days post-launch.**

- v1.1 ship blocker: **50 / 50**. Non-negotiable.
- Weekly-to-bi-weekly content updates in the first 90 days adding levels toward the 100 target.
- Level additions are content-only, shipped via OTA where possible (level JSON is already a bundled asset, but can migrate to Remote Config hosting if we want OTA level drops without store submissions — explicit v1.2 experiment).

### 12.9 Launch checklist summary

A one-page snapshot of what must be true before v1.1 goes to stores. Detailed requirements in the referenced sections.

- [ ] 50 RU + 50 EN levels, all validated, difficulty-tagged, ordered (§5)
- [ ] Hint economy rework live and unit-tested (§4.5, §9.7)
- [ ] Premium + Hint pack IAPs configured in both stores with localised copy (§8.6)
- [ ] AdMob live with rewarded + interstitial units; consent flows implemented (§8.5, §8.7)
- [ ] Firebase Analytics + Remote Config + Crashlytics wired (§10)
- [ ] App icon + splash screen (§12.3)
- [ ] Rules modal rewritten in RU / EN (§7.5)
- [ ] Settings screen built (mute, remove-ads, restore, rules, language) (§12.3)
- [ ] A11y pre-launch gate passed (§11.7)
- [ ] CI on every PR (§9.8)
- [ ] Zero crashes in internal Crashlytics for 2+ weeks prior to submission (§10.7)
- [ ] Data safety declarations filed on both stores (§8.7, §10.8)
- [ ] Store listing copy in EN and RU, screenshots prepared in both languages

### Decisions captured in this section
- **v1.1 is the launch version**; no split release pre-launch.
- **US only at launch.** Russia explicitly held; other diaspora markets deferred to v1.3+.
- **Content launch bar: 50 / 50**, grown to 100 / 100 across the first 90 days.
- **v1.2 scope** pencilled: daily challenges + screen-reader full pass + content growth + retroactive achievements + first A/B experiment outcomes applied.
- **Explicit non-goals listed** to prevent scope creep.

### Open questions raised by this section
- **[§12.3 / §9.8] CI tooling** — GitHub Actions is the default assumption. Any preference otherwise?
- **[§12.8] OTA level drops** — ship level JSON via Firebase hosting or Remote Config rather than store submissions? Experiment worth running in v1.2.
- **[§12.7] Geographic expansion sequencing** — when v1.3 adds markets, which first? Likely Israel (largest RU-speaking diaspora outside Russia), then Germany.
- **[§12.9] Final launch checklist review** — to be run through in a single session close to submission; this list is a draft.

---

## 13. Open questions

Running list of things we flagged but haven't decided. Each gets resolved when its home section is drafted.

- **[§3] Home screen re-entry flow.** v1.0 shows the language picker every launch. Intent (§3) is to drop returning users straight into the game in their last-used language. v1.1 behaviour change; belongs with ads/hints sprint or its own small PR.
- **[§3 / §6] Resume last level?** If re-entry skips the home screen, do we resume on the level the player last reached, or always start at level 1? Resolved when §6 (meta systems) is drafted.
- **[§4.1] Shuffle** — keep in v1.x canonical or deprecate if unused? Revisit with analytics.
- **[§4.3 / §12] Dictionary-backed bonus entry** — parked. Level-only validation for v1.x; revisit post-launch.
- **[§4.4 / §4.5] Scoring & hint-economy tunables** — bonus flat value (15), refill threshold (10), required-word length bonuses (`×10, +0/+10/+20/+30`), and daily-gift claim trigger all need analytics-informed review post-launch.
