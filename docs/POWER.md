# Power budget — Ktemata (r4) vs Project NOMAD, no AI

Two very different machines, so the comparison has to be made in the right unit. Ktemata is a
**handheld used 1–4 h/day on a 22–26 Wh pack**; a NOMAD box is a **station that stays on**. This page
gives both, in watts and in Wh/day, and then in the solar panel and battery each would need off-grid.

| | Ktemata r4 (Pi 5 handheld) | Project NOMAD, recommended build |
|---|---|---|
| Storage form | 2× 18650 in 2S, **22.2–25.9 Wh** usable pack | mains; a UPS only rides out outages |
| Typical draw | **5.1 W** idle with screen on, 3.5 W screen off | **7–9 W** idle, 80–90 W load |
| Duty cycle | handheld, 1–4 h/day | 24/7 if left on |
| Energy per day (typical) | **14–40 Wh** | **192 Wh** |
| Runtime on Ktemata's pack | 2.6–4.7 h (see below) | **2.1 h** at idle, 0.2 h at load |

## Ktemata (r4)

Components and their draws, from measured sources rather than datasheet maxima:

| Component | Idle | Load | Source |
|---|---|---|---|
| Pi 5 (4 GB) | ~3.0 W headless; ~3.6 W with Ethernet + USB + HDMI | ~8.8 W all-core; ~16 W with USB-SSD + 4K | [raspberry.tips Pi 5 measurements, Oct 2026](https://raspberry.tips/en/raspberrypi-tutorials/raspberry-pi-power-consumption-update-2026-all-models-compared) |
| Pi 5, soft-off | **1.7 W** (PMIC stays alive) | — | same |
| Touch Display 2, 5" | 1.4 W | 1.4 W | Pi product brief / this repo's BOM |
| NVMe (WD SN740) | 1–2 W | 4.7 W max | raspberry.tips accessory table; drive datasheet |
| FireBeetle 2 + OLED (radios off) | ~0.2 W | ~0.2 W | ESP32 ~40–50 mA @ 3.3 V + OLED, estimate |
| UPS HAT (B) conversion | — | η ≈ 0.88 assumed | **assumption**, not measured |

Resulting states. The pack column applies η = 0.88 and a usable depth of discharge of 0.85, so a
22.2 Wh pack yields ≈ 16.6 Wh at the 5 V rail:

| State | 5 V rail | at the pack | runtime, 22.2 Wh (3.0 Ah) | runtime, 25.9 Wh (3.5 Ah) |
|---|---|---|---|---|
| Screen off, Pi up | 3.5 W | 4.0 W | 4.7 h | 5.5 h |
| Idle, screen on | 5.1 W | 5.8 W | 3.3 h | 3.8 h |
| Reading / Kiwix, light touch | 6.5 W | 7.4 W | 2.6 h | 3.0 h |
| Browsing Wikipedia + maps | 8.7 W | 9.9 W | 1.9 h | 2.2 h |
| Heavy (video, CPU stress) | 12.5 W | 14.2 W | 1.3 h | 1.5 h |

`README.md` and `BOM.md` claim **2–2.5 h** of Pi 5 runtime. That holds: 22.2 Wh over 2–2.5 h is
8.9–11.1 W at the pack, i.e. the browsing/heavy rows. It is *not* the reading figure (2.6 h) and
badly understates screen-off use (4.7 h). Leave the claim as the conservative browsing number.

**Daily energy, duty-cycled** (this is the number that matters for a handheld):

| Use | Energy at the pack per day | Solar panel needed (3.5 peak-sun-hours, 0.7 derate) | Pack for 1 day autonomy |
|---|---|---|---|
| 1 h/day reading | 7 Wh | 2.9 W | 9 Wh |
| 2 h/day reading | 15 Wh | 6.1 W | 19 Wh |
| 2 h/day browsing | 20 Wh | 8.2 W | 25 Wh |
| 4 h/day browsing | 40 Wh | 16.3 W | 50 Wh |

So the r4 pack covers a normal day without any charging, and the repository's 20–30 W foldable
panel (≈ 49–74 Wh/day) refills it two to three times over. The panel sizing in `README.md` is
therefore generous for real use, and deliberately so for multi-day autonomy.

## Project NOMAD, no AI

NOMAD's AI is **optional by design** (their FAQ: the library works "without ever touching the AI"),
so "no AI" is a supported configuration, not a downgrade. It does not change the idle budget: the
box is the same and the OS/services stack still runs. It removes the inference bursts, which
matter only if the machine is loaded for long stretches.

From the [hardware page](https://www.projectnomad.us/hardware), the three tiers and what each is:

| Tier | Price | Hardware | Idle (measured) | Load (measured / vendor) |
|---|---|---|---|---|
| Budget | $150–300 | used OptiPlex Micro / ThinkCentre Tiny / EliteDesk Mini, i5/i7 8th gen+, 16–32 GB DDR4, 500 GB SSD | **11–18 W** | 35–65 W, NOMAD's "15–65 W" range |
| **Recommended** | $500–800 | Minisforum/Beelink, Ryzen 7/9 (8845HS, 780M), 32 GB DDR5, 1 TB NVMe | **7–9 W** | **80–90 W** |
| Power | $1,000+ | as above + RTX 3060 12 GB or better | ~30–40 W (inferred: a 3060 Ti alone idles at 11 W with screens off) | 200–300 W, inferred from GPU TBP + host |

Idle figures come from independent measurements, not vendor claims: OptiPlex 7060 Micro just over
18 W and 7070 Micro just over 13 W for six-core units ([ServeTheHome](https://www.servethehome.com/dell-optiplex-7070-micro-project-tinyminimicro-guide-and-review/3/));
ThinkCentre M710q 11–13 W, M920q 12–15 W, M75q Gen 2 ≈ 12 W (same series); Minisforum UM890 Pro
**7–9 W idle, 80–90 W load** ([ServeTheHome](https://www.servethehome.com/minisforum-um890-pro-review-re-architected-amd-ryzen-8945hs-mini-pc/4/)).
NOMAD's own guidance is "a mini PC draws **15–65 W** depending on load" — accurate for its budget
tier, conservative for the recommended one.

Note the shape of the recommended build: it idles *lower* than a refurbished SFF PC but loads far
higher. For an always-on knowledge library that is the better profile; for intermittent use neither
idle number matters much.

**Daily energy** at 24/7 (the honest assumption for a station you leave running):

| Build | Mid-idle | Wh/day | Panel for 1 day | Pack for 1 day (80 % DoD) |
|---|---|---|---|---|
| Budget | 14.5 W | 348 Wh | 142 W | 435 Wh |
| Recommended | 8.0 W | 192 Wh | 78 W | 240 Wh |
| Power | 35 W | 840 Wh | 343 W | 1050 Wh |

## The comparison

| | Ktemata r4, 2 h/day | Ktemata r4, 4 h/day | NOMAD recommended, 24/7 | NOMAD budget, 24/7 |
|---|---|---|---|---|
| Energy per day | 14–20 Wh | 29–40 Wh | **192 Wh** | **348 Wh** |
| Solar panel | 6–8 W | 12–16 W | 78 W | 142 W |
| Battery for 1 day (80 % DoD) | 19–25 Wh | 37–50 Wh | 240 Wh | 435 Wh |

- **Per hour of use, Ktemata is cheaper**: 5.1–8.7 W against 8–14.5 W idle, and it needs no
  monitor, access point or router on top.
- **Per day, Ktemata is 5–14× cheaper** (192 Wh against its 14–40 Wh), because it is off
  between sessions and a station is not; against the budget NOMAD it is up to 25×.
- **Per unit of work, NOMAD wins outright**: a Ryzen 8845HS serves several browser clients at once
  and hosts the full stack (dashboard, Kiwix, maps, courses), while the Pi 5 serves one handheld
  screen. Comparing watts per hour flatters the handheld; comparing watts per served user does not.
- **The packs are not interchangeable.** A 22.2 Wh pack runs a NOMAD box for 1.1 h (budget idle) or
  2.1 h (recommended idle) and 0.2 h under load. Ktemata's pack is a *session* buffer; a NOMAD
  deployment is a *station* buffer of 240–435 Wh minimum.
- **The 20–30 W panel in this repository cannot run a NOMAD station.** At 3.5 peak-sun-hours and a
  0.7 derate it delivers ≈ 49–74 Wh/day, i.e. 2.0–3.1 W continuous — enough for Ktemata's 2 h/day
  (20 Wh) with margin, but only a quarter to a third of a recommended NOMAD's daily need.

## Caveats

- **Assumptions, not measurements**: η = 0.88 for the HAT (B) buck converter, 0.85 usable depth of
  discharge for the 2S pack, 3.5 peak-sun-hours and 0.7 panel derate. Measure the pack side with an
  inline meter; the HAT (B) INA219 at 0x42 reports it directly once the firmware reads it.
- **Cell capacity drives everything.** The README's 23 Wh figure is a 3.0 Ah pair; 3.5 Ah cells give
  25.9 Wh (+17 %). Runtime scales linearly, so the tables above cover both.
- **Pi 5 soft-off is not off.** It draws ~1.7 W until the supply is cut. On r4 that means the pack
  drains even with the Pi shut down — the UPS keeps the 5 V rail alive. Use a real shutdown plus the
  HAT's output switch, or accept ~1.7 W of standby.
- **NOMAD's idle figures are x86 at the wall**, including the PSU; the Pi figures are at the board.
  With the HAT's conversion losses the two are close enough to compare directly, which is why the
  "at the pack" column above exists.
- **No AI, either side.** Ktemata has no inference at all; the NOMAD columns assume its AI is left
  off, which their FAQ supports. Both then do the same job — serve a local wiki — at very different
  scales: one handheld screen against a LAN server.
- **AI-off NOMAD still loads high when busy.** Installing content, transcoding video or compiling
  hits 65–90 W; the 240 Wh pack plus 78 W panel above assumes idle-dominated use.
