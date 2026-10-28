# Ktemata vs Prepper Disk — pros and cons

Two offline libraries on Raspberry Pi hardware. They overlap in content and diverge in almost
everything else:

| | Ktemata r5 | Prepper Disk Premium |
|---|---|---|
| What it is | a **handheld computer**: screen, keyboard, battery, all in one rugged case | a **headless hotspot**: plug it in, join its Wi-Fi, browse from your own phone |
| Board | Pi 5, 4 GB, NVMe | Pi 4B, 2 GB, 512 GB microSD |
| Case | printed cassette inside a bought Peli 1200 | machined aluminium, 89 × 70 × 25 mm |
| Price | ≈ €635 built (`BOM.md`) | €270.95 (or €150.95 software-only) |
| Where the work goes | designing, printing, wiring, software | none — it arrives configured |
| Source | this repository, MIT-style DIY | closed product, proprietary UI on Internet-in-a-Box |

The honest summary: **the Prepper Disk is the better product; Ktemata is the better device for one
specific job.** The Prepper Disk wins on price, size, weight, power, polish and support — and on
serving a room *by default*, though Ktemata has the same radio and only disables it by policy. Ktemata wins on independence from other devices, on storage and upgradeability,
on being field-repairable, and on being a computer you can use *with no phone in the room*. Which of
those matters depends entirely on whether you expect to have a working phone and a charged laptop
with you.

## Where the Prepper Disk wins

**Price.** €271 against ≈ €635. Half the cost, and a quarter if you already own a Pi (€151 for the
card). The Ktemata BOM buys a Pi 5, a 143 mm display, a UPS HAT, 18650 cells, a mechanical keyboard,
an NVMe drive, a Peli case and a solar path; the Prepper Disk buys a Pi 4B, a card, and a milled
enclosure.

**Size and weight.** 89 × 70 × 25 mm, about 158 cm³ and ~200 g. Ktemata r5 in its Peli 1200 is
roughly 8.3 litres and ~1.6 kg — **53× the volume, 8× the mass**. If the criterion is "fits in a
glovebox, a jacket pocket, a go-bag lid", there is no contest. This is the single biggest practical
difference.

**Power and autonomy per reader.** Measured Pi 4B idle is 2.7 W (540 mA at 5 V, nothing on USB) plus
~0.35 W for its access point: **3.05 W, 73 Wh/day**. Ktemata r5 draws 4.0 W screen-off and 5.1 W with
the display lit — 96–139 Wh/day. On identical 24/7 duty the Prepper Disk uses about **a quarter
less energy** (73 against 96 Wh/day), and it needs no display.

![Power per reader](prepperdisk_served.png)

**It serves a room out of the box.** Up to 20 phones, tablets and laptops at once, over its own
Wi-Fi. At 3.05 W that is ~152 mW of server power per connected device, against 5.1 W for the person
holding the Ktemata.

This is worth stating precisely, because it is the one place where the two machines are **not**
technically different. **Ktemata's Pi 5 has the same dual-band Wi-Fi radio on board as the Prepper
Disk's Pi 4B.** r5 disables it by policy (`dtoverlay=disable-wifi` in `config.txt`, see the "Radios
off" row in `README.md`) because the project's brief is an offline device with no networking. That
is a **design choice, not a hardware limit**: `hostapd` + `dnsmasq` and a DHCP range turn it into a
hotspot in one configuration change, serving the same ZIM files to the same browsers. The cost is
about 0.4 W, which moves it to 4.4 W and **220 mW per connected device** — still in the Prepper
Disk's league, and the machine keeps its own screen and battery while doing it.

What the Prepper Disk still has over that mode is simplicity: the hotspot *is* the product, it is
already configured, and there is no laptop-and-SSH step to get there.

**No assembly, no printing, no wiring.** It arrives configured, tested, with a one-year warranty,
60-day returns, 7,000+ units shipped and a 4.8-star review base. Ktemata r5 requires a 3D printer,
a soldering iron for the pack leads, firmware flashing, an OpenSCAD toolchain, and the willingness to
debug a buck converter. That is the whole point of this repository, but it is not a product.

**Content is licensed and curated, and it updates.** Includes material you cannot assemble yourself:
Ky Furneaux field guides, original Prepper Disk books, MDWiki, RepeaterBook, a Morse decoder, an
emergency phrase translator, plus National Park trail maps for all 63 US parks. Ongoing content
updates are part of the offering. Ktemata's page deliberately stops at "download ZIMs yourself".

**Polish and support.** Custom UI over Internet-in-a-Box, 10.10.10.10 landing page, one-year hardware
warranty, US-based support from the founders. When it breaks, someone answers.

## Where Ktemata wins

**It works alone.** The Prepper Disk is useless without a charged client device. In a real grid-down
scenario — or just on a hike, in a tent, or three days into a power cut — the phone you were going to
browse from may be the first thing to die. Ktemata has a 720 × 1280 touchscreen, a keyboard with a
trackpad, and its own battery: open the lid and read, no second device, no Wi-Fi, no DHCP, no
browser tab. That is not a feature you can add to a headless hotspot.

**It carries its power.** The HAT (B) with 2× 18650 gives **3.3 h with the screen on, up to 4.2 h
screen-off**, and it charges from 8.4 V — so solar and the hand-crank generator (a separate,
published design) can top it up. The Prepper Disk **ships without a battery**: it expects mains or a
USB bank.

![Autonomy as shipped](prepperdisk_autonomy.png)

On a 20 Ah USB bank the Prepper Disk runs ~18 h, which is excellent — but that bank is another
€40–70, another 350 g, and a 5 V path that cannot feed Ktemata's HAT (the two power architectures are
not interchangeable).

**Storage is bigger and replaceable.** 512 GB NVMe in a standard M.2 socket, Gen2 link, 300 TBW, and
a 1 TB 2242 or SATA upgrade is a drive swap. The Prepper Disk's 512 GB is a **microSD card** — slower,
wear-limited, and the single most common failure point in Pi deployments. Its own FAQ lists a
"reliable 512 GB microSD" at $95–125 as the dominant cost of a DIY build. Note that *neither* holds
the full 833 GiB Ktemata library: 512 GB formats to ~477 GiB, so both are at roughly half.

**It is a general computer.** Pi 5 with 4 GB and a real SSD runs a desktop, a browser, Kiwix, a
terminal, `ssh`, Python, an editor. The Prepper Disk is an appliance: browse what it serves, and
that is the contract. If the library is one tool among many, a computer is the better shape.

**You can fix it.** Every part is off-the-shelf and documented: a standard Pi 5, a standard display,
a standard UPS HAT, a Peli case, printed parts with published STLs. A failed Pi is a €85 swap; a
failed screen is €60; a cracked shell is a reprint. The Prepper Disk's aluminium enclosure and
custom integration are not field-serviceable, and its warranty is one year against a lifetime of
expected use.

**No vendor, no licence, no dependency.** MIT-style CAD and firmware in this repo, ZIM files from the
Kiwix catalogue, no account, no content licence that can be withdrawn, no company that can stop
shipping. The Prepper Disk's exclusive content and curated UI are genuine value — and also a
dependency.

**It is repairable and inspectable at the source level.** The firmware in `firmware/` is 1,000 lines
you can read, with the I²C addresses, the UPS gauge protocol and the OLED screens all documented. A
battery-percentage bug is a pull request, not a support ticket.

## Head to head

| Criterion | Ktemata r5 | Prepper Disk | Edge |
|---|---|---|---|
| Price | ≈ €635 | €271 | **Prepper Disk** 2.3× cheaper |
| Volume / mass | ~8.3 L, ~1.6 kg | ~0.16 L, ~0.2 kg | **Prepper Disk** 53× smaller |
| Draw, 24/7 | 4.0–5.1 W | 3.05 W | **Prepper Disk** ~¼ less energy/day |
| Energy/day | 96–139 Wh | 73 Wh | **Prepper Disk** 1.3–1.9× |
| Autonomy as shipped | 3.3–4.2 h | none (mains/USB bank) | **Ktemata** |
| Readers served | 1 (20 as a hotspot, one config change) | up to 20 | tie, Prepper Disk by default |
| Needs another device | no | yes | **Ktemata** |
| Storage | 512 GB NVMe, upgradeable | 512 GB microSD, replaceable | **Ktemata** (durability) |
| Setup effort | print, wire, flash, debug | plug in | **Prepper Disk** |
| Repairability | any part, documented | warranty only | **Ktemata** |
| Content | whatever you download | curated, licensed, updated | **Prepper Disk** |
| Independence from a vendor | none | content and UI are proprietary | **Ktemata** |
| Ruggedness | IP67 Peli + printed cassette | milled aluminium, not IP-rated | tie (different threats) |

## Which to build or buy

- **Buy the Prepper Disk** if you want an offline library in a bag, will have phones or laptops with
  you, want it working in ten minutes, and would rather spend €271 than a weekend. It is the right
  answer for most people.
- **Build Ktemata** if the point is a self-contained reading and computing device that works with
  nothing else in the room, if you want to own and repair the hardware, if 512 GB of NVMe and the
  option to swap in a terabyte matters, or if the building is the point. If you also want the
  hotspot, enable the radio — it is already there.
- **Both** is not silly: €271 for the family hotspot plus a handheld for the person who walks out
  with the bag. They share the same ZIM files and the same Kiwix software, so the second copy costs
  only storage. Equally, one Ktemata can do both — enable the radio when a group needs it, leave it
  off when the point is to be unfindable.

## Sources and caveats

- Prepper Disk: [prepperdisk.com](https://www.prepperdisk.com/) product page (Pi 4B 2 GB, 512 GB,
  89 × 70 × 25 mm, 20 devices, €270.95, one-year warranty), its
  [DIY page](https://www.prepperdisk.com/pages/diy-prepper-disk-adv) for the parts-and-cost breakdown,
  and its product copy for the content list.
- Pi 4B idle draw: [Dramble power benchmarks](https://www.pidramble.com/wiki/benchmarks/power-consumption.html),
  540 mA at 5 V with nothing on USB. The 0.35 W (Prepper Disk) and 0.4 W (Ktemata) access-point
  figures are **estimates**, unmeasured; the Pi 5's radio draws at the same order as the Pi 4B's.
- Ktemata figures: `docs/POWER.md`, same 24/7 basis, same η = 0.88 / 0.85 DoD / 3.5 PSH / 0.65 derate
  assumptions. Prices from `BOM.md` (reconciled orders; r5's Peli 1200 is not yet in that total, so
  treat ≈ €635 as indicative).
- Volume and mass for Ktemata are computed from the Peli 1200's external dimensions plus the
  cassette; the Prepper Disk's from its published 3.5 × 2.75 × 1 in.
- The Prepper Disk's content list, review scores and shipping claims are the vendor's own; this page
  does not independently verify them.
- Reproduce every number here with `python3 work/scripts/power_chart.py --compare`.
