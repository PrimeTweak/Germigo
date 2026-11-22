# Motion

How things move in Germily. The characters carry the life of the app; the interface stays calm and answers what the person does.

## Principles

1. Every motion has a reason: it answers a touch, shows that something changed, or gives a character its personality.
2. Characters move on their own; controls never do.
3. Neighbors never make the same move at the same time. A hop is one move among many, not the default.
4. One character leads a screen or a group: it is the only one that makes accents. In lists, the others breathe or stand still.
5. Reduce Motion stills everything that is not needed to understand a change.

## Characters

Three kinds of characters move: the household (eight looks), the germs (the cards and the mascot) and the props (the run bar's runner and chaser, the record keepers on Family).

A moving character has three layers:

- **Breath**: always on, a 3 % squash over 3.2 s, shifted per character so neighbors do not breathe together.
- **Rest**: what it does while nothing happens. Germs move all the time; a household character that leads makes one accent every 7 s.
- **Reaction**: what it does when touched or when its state changes.

Amplitudes below are in points for a 70-point character and scale with its size, up to one and a half times. Scale and tilt are anchored at the bottom. The math lives in `App/Design/CharacterPose.swift`.

### Household, healthy: one accent per look

| Look | Character | Accent | Motion |
|---|---|---|---|
| 0 | Curl | Bounce | Two quick squash-and-stretch beats in place, 8 %, 0.7 s |
| 1 | Buns | Wiggle | A shimmy of ±6°, three swings fading out, 0.7 s |
| 2 | Beanie | Nod | Dips 4 pt and tips 4° forward, twice, 1 s |
| 3 | Crown | Puff | Grows 9 % taller, holds, settles with a small squash, 1.3 s |
| 4 | Bow | Sway | Leans 5° left, then right, then back, 1.6 s |
| 5 | Curls | Tilt | Tilts 9° to one side, holds, comes back, 1.4 s |
| 6 | Glasses | Look | Slides 6 pt left, pauses, 6 pt right, comes back, leaning into it, 1.8 s |
| 7 | Cap | Hop | One jump of 10 pt, 0.5 s |

The cap is the only healthy character that hops at rest.

### Household, sick: one routine per look

The routine runs all the time while the person is sick. It replaces the accent.

| Look | Routine | Motion |
|---|---|---|
| 0 | Feverish | Slow sway of 2.5° over 3.6 s, slightly flattened |
| 1 | Wobbly | Rocks ±4° over 1.8 s |
| 2 | Sniffly | Two small sniffs of 5 pt every 2.8 s |
| 3 | Dizzy | Circles: ±7° and ±3 pt over 2.8 s |
| 4 | Sneezy | Winds up, sneezes forward, every 3.2 s |
| 5 | Weary | Sags 3.5 % and lifts over 5 s |
| 6 | Coughing | Two short forward jolts of 4° every 3 s |
| 7 | Shivering | Fast tremble of ±1.6 pt |

### Germs: by where they live

A germ's rest follows its shelf in the Guide, so the motion says something about the germ.

| Shelf | Rest | Motion |
|---|---|---|
| Nose, throat and lungs | Float | Rises and falls 4 pt, tilting ±2°, over 3.6 s |
| Skin, eyes and hair | Creep | Stretches 7 % wide toward one side and pulls back in, every 3 s |
| Tummy and others | Jiggle | A jelly wobble of 6 %, width then height, fading over 0.9 s, every 2.4 s |

Germs also have four moods for particular places:

- **Resting**: breath only. The mascot asleep, on a calm Today and in the Guide once the week is done.
- **Stalking**: tilts ±3° over 2.4 s. A germ watching the household: the suspects, the trophies, the quiz, the germ after you on Today.
- **Sick**: shakes and jumps every 3.4 s. The germ on Today while someone is sick, the only germ that jumps.
- **Dizzy**: circles. A defeated germ on Victory.

### The mascot

Asleep, it snores. Elsewhere, a tap wakes it for 2.4 s. Awake, it stalks. It never hops.

On a calm Today it has tricks to find. Each face is an image, `mascot-<face>`, from `MascotFace`; the timings live in `App/Design/MascotMind.swift`.

| Trick | Touch | What it does | Haptic |
|---|---|---|---|
| Pop a z | Tap a letter of the snore | The letter bursts and stays away until its next rise; the mascot sleeps on | Tick |
| Grumpy wake-up | Tap it asleep | One eye, then both, 0.7 s; awake about 6 s after the last touch, drowsy for 0.8 s, then asleep | Tap |
| Squish | Tap it awake | Squish with a giggle face, 0.5 s; the fourth tap within 3 s makes it dizzy, spiral eyes, 1.6 s | Tap, thud |
| Tickle | Keep a finger still on it for 0.35 s | Giggles, beat after beat; after 2 s it laughs and the pacifier flies out in an arc and lands on the counter | Ticks, thud |
| Pacifier | Tap the pacifier on the counter | Back in the mouth in 0.3 s, with a giggle; it comes back by itself after 20 s | Tick |
| Pull | Drag it | Up to 40 % taller and 30° toward the finger, squashed by a finger below; springs back with Pop | Tap |
| Sneeze | Rub back and forth: three turns of 14 pt within 1.2 s | Breathes in 0.55 s, sneezes forward; puffs and three small germs fly off and fade in 1.2 s | Thud |
| Tilt | Lean the phone, mascot awake | Leans up to 14° the same way and looks there | None |
| Night | From 10 PM to 7 AM, touch it asleep | Opens one eye and says "Shh… it's late." for 2.5 s, still asleep; a second touch then wakes it | Tick |

Finding all ten tricks, dizzy counted on its own, earns the secret Ticklish badge: a toast, the success haptic and the badge sound, without the reward screen. With Reduce Motion the faces still change and the haptics stay; the mascot does not move, the pacifier lies on the counter at once, and the tilt is not read. VoiceOver offers Wake up, Tickle, Make it sneeze and Give back the pacifier.

### Props

- Runner and chaser: a two-frame run cycle, 0.22 s per frame, on the run bar only.
- Record keepers (album, doctor's file, logbook): still. They wiggle once when something new lands in them, as soon as Family is back on screen.
- The soup of the tip jar: breath and its steam.

### Touch

| Who | First, second and third tap | Fourth tap within 3 s |
|---|---|---|
| Household, healthy | Giggle: squashes 10 % and stretches back, twice, 0.5 s | Dizzy for 1.6 s |
| Household, sick | Ouch: a small shiver, 0.3 s | Dizzy for 1.6 s |
| Germ | Squish: drops to 80 % height and 115 % width, rebounds past its shape, 0.6 s | Dizzy for 1.6 s |
| Mascot asleep | Wakes up | Wakes up |
| Mascot awake, on Today | Squish, like any germ | Dizzy for 1.6 s |

Each tap gives the tap haptic and dizzy gives the thud; the mascot's other tricks have their own, above. Touch never plays a sound. A character inside a button or a link does not react to touch.

### Groups take turns

In a group (the couch, a row of suspects, the podium), accents are spread evenly: with n characters, character i starts its 7 s cycle at i × 7 / n s. Continuous routines are shifted by each character's own phase.

### Where characters move

- The lead character of a screen, a card or a group has breath, its rest and touch.
- In lists and grids, a healthy character only breathes; a sick one keeps its routine, because it tells something. On Family, the couch carries the motion and the cards stand still.
- Characters under 40 pt stand still.

## State changes

| Event | Motion | Haptic | Sound |
|---|---|---|---|
| Someone gets sick | The art swaps with a 0.4 s shake, then the sick routine starts | Thud | None |
| Someone gets better | A hop of joy of 16 pt with sparkles, then the healthy accent | Success | None |
| A photo is saved | Pops into the album | Success | None |
| A germ is caught in the Guide | Its color fills in and it pops | Tap | Reveal |
| A badge, a level or a milestone | The reward screen, with confetti | Success | Badge |
| A boss is defeated | Victory: the germ goes dizzy, with confetti | Success | Badge |
| A number changes | Rolls to its value | None | None |
| Progress | Fills with the reveal curve | None | None |

## Interface

Six curves cover everything; in code they are `Tempo`. Nothing else is used.

| Name | Curve | For |
|---|---|---|
| Press | Ease out, 0.15 s | The 0.96 press of a button |
| Quick | Snappy | Toggles, chips, a selection, small layout changes |
| Settle | Spring, response 0.42, damping 0.74 | Cards moving, lists reordering, entrances |
| Pop | Spring, response 0.38, damping 0.55 | Something arriving: a chip, a photo, a badge |
| Reveal | Ease out, 0.8 s | Rings, bars and numbers that count up |
| Scene | Spring, response 0.6, damping 0.85 | Content that swaps in place: a day sliding, a step of a flow |

- Lists enter with `cascadeIn`, 0.06 s apart, eight steps at most.
- SF Symbols: `bounce` confirms a change, `wiggle` calls attention once, `replace` swaps a symbol, `pulse` only marks something urgent.
- Confetti only on the reward screen, on Victory and on the thank-you of the tip jar.
- Two effects keep their own curve because they imitate a device: the flap counter falls (ease in, 0.34 s) and the camera flash on a day's photos blinks.
- The light on the Season Pass ticket crosses it once when it appears.

## Reduce Motion

- Characters stand still. A tap still gives its haptic.
- Transitions become fades (`motionTransition`). No confetti.
- Numbers, rings and bars show their value at once. The run bar stands still with its characters in place.

## Performance

- Rest routines draw at most 30 frames a second and stop when they leave the screen.
- No more than eight moving characters on a screen.

## Adding a motion

1. Name its reason: a touch, a change or a personality. No reason, no motion.
2. Reuse a curve and a move from this page before adding one, and add it here when nothing fits.
3. Look at it next to its neighbors: nobody makes the same move at the same time.
4. Look at it with Reduce Motion on.
