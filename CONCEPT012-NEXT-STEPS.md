# Concept 012 — Workshop Feedback Status

Recovered 2026-11-03 from a session that died on a request-size limit. Source of
truth for what the design team asked for and what is actually built.

## Source

Figma board [Shared Vision UX](https://www.figma.com/board/ay4Hl185s546pdZuDYq8CL/Shared-Vision-UX?node-id=1154-2349),
page **Workshop 21st Oct**. Nine unresolved comments by Oliver Weidlich, dated
2026-10-20.

PNG renders of the five board screenshots were pulled via the Figma REST API and
sit in `References/figma-workshop-2026-10-20/` **locally, uncommitted** — 12 MB
of screenshots against a 17 MB repo history was not worth adding when the board
itself is the source of truth and the node IDs below reproduce them. Say the word
if they should be committed anyway.

| Node / file | What it shows |
| --- | --- |
| `1154:2354` | "Filter: All Roles" — dense faces, carries five comment threads |
| `1154:2355` | "Filter: Designer" — non-matching faces dimmed, selection-overlay note |
| `1154:2350` | Workshop context |
| `1160:2` | Glassy spatial bubbles in a Joshua Tree setting (reference) |
| `1160:3` | "Interview Universe" panel with segmented role filter (reference) |

## Standing decisions

- **Follow the design team's lead.** Their screenshots are the spec, not a build
  to reconcile against. They mock up their own variants.
- **Roster is 40 people**, up from 20 — twenty read as sparse at a 200° field of view.
- **No minors in the headshot pool.** Ever. A minor standing in for a working
  professional is the same problem as a young child doing it.

## Task list

Ordered cheapest and least risky first. All seven workshop items are now
implemented.

1. ~~Documentary title overlay on the video window plus ~50% size bump~~ — done
2. ~~Z-depth: pull video nearer (1.0 m → 0.85 m), push orbs back, video reads as closest~~ — done
3. ~~Move mode toggle and role filter off the scene-bottom ornament into an `InterviewUniversePanel` at face depth~~ — done
4. ~~Debug sliders for video size, bubble size, field of view~~ — done
5. ~~Faces inset inside the water bubble; app bubbles as flat circles~~ — done, **but with SF Symbol stand-ins, not real app icons**
6. ~~Spatial persona treatment instead of the flat billboarded headshot~~ — done
7. ~~Selection overlay modeled on the "Interview Universe" wireframe~~ — done

### How 6 was built

Real Spatial Personas are a FaceTime-only API with no way to render an
arbitrary person, so the treatment is photographic rather than avatar-based,
matching what the comps actually show: background-removed circular portraits.

`PersonaPortraitStore` lifts each headshot's subject with Vision's
`GenerateForegroundInstanceMaskRequest` — the same subject-lifting model behind
"lift subject from background" in Photos — rather than hand-rolled segmentation
or pre-cut assets, so it keeps working when the photo pool is swapped. Results
are cached by **asset name**, not person id: forty people drawn from twelve
images means twelve lifts, not forty.

`PersonaPortrait` then layers the cut-out in front of a soft accent-tinted disc
using `offset(z:)`. The gap parallaxes as the viewer moves, which is what sells
the face as occupying the inside of the sphere rather than being printed on it.
A failed lift falls back to the old circular crop permanently, tracked in
`unavailable` so it is not retried every update.

Verified: all twelve adult headshots lift with one foreground instance, a real
alpha channel, and transparent corners. Scripts are in `/tmp/svc_recover/`
(`verify_lift.swift`, `save_lift.swift`) if the pool changes and needs rechecking.

### How 7 was built

`PersonSelectionOverlay` — persona portrait, name, role, the apps the person
appears in, and a "Watch interview" action. It deliberately reuses
`InterviewUniversePanel`'s title/subtitle/close layout so the two read as one
family. Positioned with the same dome-surface solve as the filter panel, then
yawed 34° right so it opens beside the documentary window rather than over it,
and billboarded since it sits off-centre.

`InterviewUniversePanel` already covered filtering, so this covers the other
half of the note: what selecting someone actually gets you.

### How the app categories sit

Each person's categories ring their bubble: the app icon is a hexagon of dots
around an empty centre, and here the person's face *is* that centre. Index 0 at
the upper-right vertex, proceeding clockwise, using the same
`SharedVisionsBrand.hexagonVertex` geometry as the mark.

The face and its ring share **one** attachment. That keeps the ring radius
expressed in points relative to the face — no points-to-metres conversion to
get wrong — and costs one attachment per person rather than two, which is forty
fewer entities across the dome.

Ring radius is `faceDiameter * 0.95`. The face renders at `headshotScale` (0.78)
of the water sphere's diameter, so the glass edge sits near `70 / 0.78 / 2` ≈
45pt in the attachment's own coordinates; a 66.5pt radius puts the dots just
outside the sphere rather than embedded in it.

A seventh category would start a second, wider concentric loop outside the
first. It cannot happen today — `AppTag` only has six cases — but the code
handles it.

Not done: the app icon joins its dots with hexagon edges, and the ring around a
face currently has none. Adding a faint stroke on the same path would make the
motif unmistakable, and it would clear the sphere since the ring radius already
exceeds the glass. One line in `AppBubbleRing` if wanted.

### How filtering reads

Filtered-out people **dim rather than disappear**. They fade to
`filteredOutOpacity` (0.25) via `OpacityComponent` on the orb root, which fades
the water sphere, face and app bubbles together so the parts cannot drift out of
sync. Their backlight drops to 8 as well, because `OpacityComponent` does not
attenuate light a `PointLight` casts — a faded orb left at full idle intensity
stays conspicuous however transparent its geometry becomes. Input targeting is
switched off for them, so they read as background and cannot take taps or spawn
ripples.

Decision: dim first, hide only if the design team pushes back. The opacity is a
single constant; if it wants tuning in-headset rather than per rebuild, adding a
fourth slider to `TuningPanel` is straightforward.

## Open items

**Two style-guide swatches were mislabelled.** A dusty pink labelled `349CF2`
(a mid blue) and a light green labelled `3CD3FE` (a cyan). Per the designers the
swatches are right and the labels wrong, so both were recovered from the guide's
own pixels: the guide is a glass panel and renders every swatch lighter than
its true value, so fitting that shift across the seven swatches whose label and
appearance *do* agree gave `rendered = 0.778 x true + 51.9` (R² = 0.974), and
inverting it yields `#E17A94` and `#9CEE8C`. Accurate to a few units, not exact
— worth replacing with the designers' real hex.

**The logo is drawn, not an asset.** `SharedVisionsMark` draws the hexagon from
the same `hexagonVertex` geometry the app bubbles use, since there is no logo
artwork in the repo. It stays sharp at any size and needs no asset, but it is a
reconstruction from the style guide image — swap in the official artwork when
available; call sites take a diameter and nothing else.

**Real app icons.** `AppTag.symbol` uses SF Symbols because there is no app-icon
artwork in the asset catalogue. One line per case once the images exist. The
bubbles are now large enough for an icon to read, which they were not on the
first device pass.

## Typography — Inter is bundled

Inter 4.1, three static instances, under the SIL Open Font License. Files and
the licence are in `SharedVisionsConcepts01/Resources/Fonts/`, listed in
Info.plist under `UIAppFonts`, and reached through `SharedVisionsFont`.

PostScript names were read off the files rather than assumed — `Inter-SemiBold`,
`Inter-Medium`, `Inter-Light` — and verified to resolve through CoreText rather
than fall back. A wrong name there makes `Font.custom` return the system face
silently, which looks like "the font didn't apply" with no error anywhere.

`SharedVisionsFont.isInterBundled` still exists; set it to `false` to flip the
whole app back to system faces at matching weights, which is useful for
comparing the two.

**Deprecation warning in `TuningSlider`.** Around line 1069, `Text(...) + Text(...)`
warns under iOS 26: "Use string interpolation on `Text` instead". Pre-existing in
the merged work, not introduced by items 6 or 7. One-line fix, left alone to keep
this change set tight.

**Headshot inset axis — resolved on device.** The first device pass (3 Nov)
confirms faces sit *inside* the water sphere, not popping out in front, so the
`+Z` reasoning was right and no sign flip is needed.

**Particle cue linking panel to faces.** Still skipped — it was phrased as a
maybe, and shared depth plus the glass treatment may already carry the linkage.

**Interview Universe panel placement needs eyes-on.** It sits 0.45 m below eye
level at dome depth and did not appear in either device capture, both of which
were framed above it. Worth confirming it is where it should be.

## First device pass — 3 Nov

Two captures from the headset, in a bright room against a white wall.

Confirmed working: persona cut-outs, faces inside the bubbles, 200° wrap, the
dimmed fade-out (explicitly liked), the documentary title and 1.5× size, and the
selection overlay with its name, role, "Appears in" chips and Watch interview
button.

Changed in response:

- **`bubbleScale` default 1.0 → 1.4.** Bubbles read as too small to pick a face
  out of across a room.
- **`headshotScale` 0.6 → 0.78.** The face occupied under half the sphere.
- **Neutral backing disc added behind each face.** The accent tint alone washed
  out against a white wall, which is why active faces were still hard to see.
  A dark disc now sits behind the head to separate it from the room.
- **Grayscale dropped from faces that pass the filter.** Filter state is carried
  entirely by `OpacityComponent` now, so desaturating matching faces only cost
  legibility.
- **App bubble cluster scale 0.5 → 0.85, icons enlarged.** On device these
  rendered as small coloured dots with an illegible symbol — precisely what the
  workshop asked to move away from.
- **Documentary subtitle given explicit white.** `.secondary` renders
  near-invisible over the black video panel.

Not a bug: a small green dot appears at the *same screen position* in both
captures despite the camera having moved between them. Being screen-locked
rather than world-locked, it is a visionOS capture indicator, not scene content.

## FPO headshots — review was interrupted

Twelve headshots were generated locally with MOSS (stable-diffusion.cpp) to avoid
licensing concerns. The synthetic-face sites the existing assets came from are
dead — `thispersondoesnotexist.com` is parked for sale.

Staged in `artifacts/fpo-headshots-pending-review/` with the generating script
(`generate.sh`), **locally and uncommitted** — eight of the twelve have not been
checked for age yet, and unvetted faces should not land in the repo given the
no-minors rule. Every prompt names an explicit adult age and the negative prompt
excludes children and teenagers, but **each image still needs eyeballing** —
that is what the existing-asset audit caught.

Review status when the session died:

- `fpo01` — adult man, ~45, outdoor bokeh — **approved**
- `fpo02` — East Asian woman, reads ~45 rather than the prompted 29 — **approved**
- `fpo03` — adult man with glasses — **approved**
- `fpo04` — adult woman, blonde bob, brick wall — **approved**
- `fpo05` through `fpo12` — **not yet reviewed**

**Read these in small batches.** Reviewing twelve ~500 KB PNGs in one session is
what blew the request-size limit and killed the original session. Two or three at
a time, or downscale first.

## Existing headshot audit (applied)

All sixteen bundled headshots were audited individually on 2026-11-03. The old
`adultHeadshotNumbers` list was wrong in both directions: it included 2, 15 and
16 (young children) and excluded 7, 10 and 13 (plain adults). Corrected list is
`[1, 3, 4, 5, 6, 7, 8, 10, 11, 12, 13, 14]` — twelve images. Number 9 reads as a
teenager and was excluded deliberately.

This lives in `Helpers.swift` as `adultHeadshotName(for:)` and also feeds
Concepts 013 and 014, so face-to-name mapping shifts in those too.

## State of the merge

Concept 012's workshop build has been merged onto `main` (`effd984`) and builds
clean on the visionOS 27 simulator. Changed in the working tree, **not yet
committed**:

- `SharedVisionsConcepts01/Concepts/Concept012.swift` — the workshop build plus items 6 and 7
- `SharedVisionsConcepts01/Utility/Helpers.swift` — headshot 09 removed from the adult pool
- `Packages/.../RealityKitContent.rkassets/PersonOrb.usda` — restored; Concept 012 loads it and it was not in Jeffrey's commit
- `SharedVisionsConcepts01/App/Generated/ConceptRegistry.swift` — regenerated by the build phase

Local Concepts 011, 013 and 014 were **dropped** in favour of Jeffrey's
committed versions, by decision. They were different concepts that happened to
share filenames:

| File | Dropped local version | Kept (origin/main) |
| --- | --- | --- |
| Concept011 | Welcome / Startup Space | Welcome / Living Constellation |
| Concept013 | Breathing Focus Orbs | Interview Universe |
| Concept014 | Palm Profile Hologram | Living Palm Infographic |

The dropped versions are still recoverable from the stash below if that call is
ever revisited.

## Recovery pointers

The pre-pull stash is still intact and holds the full local lineage:

```bash
git stash list                      # pre-pull: local concepts 011-015 ...
git rev-parse stash@{0}             # 10671c4 — recovers the work even if dropped
git show 'stash@{0}^3:SharedVisionsConcepts01/Concepts/Concept011.swift'
```

Tracked edits are in the stash commit itself; untracked concept files are in its
third parent, `stash@{0}^3`. **Do not pop it blind** — it will collide on all
five concept files.

Full transcript of the session that produced the workshop build is at
`~/.kiro/sessions/8db78dcf5ec0b13d/sess_e931f5d7-6e37-4229-8878-5c7d0bef9277/`.
Its `messages.jsonl` is 33 MB because tool results inline base64 images; extract
text with a script rather than reading it directly.
