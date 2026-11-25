## Ktemata (R6 — Default Build)

R6 is the default build. Two variants: **R6** uses a perfboard with DC5521 charge management, and **R6 PCH** uses a custom power/charge carrier board. Both keep Wikipedia, maps and Gutenberg when power and networking are gone.

---

### R6 Perfboard Variant

The base R6 variant uses a flat perfboard for cost-effectiveness and rapid iteration. The DC5521 charge path feeds the Waveshare UPS Module 3S directly, eliminating the need for a separate carrier board while maintaining the rugged Peli 1200 enclosure design.

#### Target Hardware

- **Host Case:** Peli 1200 (rugged, IP67-rated)
- **Computer:** Raspberry Pi 5 (4 GB)
- **Display:** Waveshare 7" DSI LCD (C)
- **Keyboard:** Rii K06 Touch Keyboard
- **Storage:** NVMe SSD
- **Power:** Waveshare UPS Module 3S with three 18650 cells in 3S

#### Features

- Built-in Ktemata Admin at `:8081` for storage, library, power and AI
- UPS INA219 telemetry read by the Pi
- Wikipedia, maps, and Gutenberg content preservation
- Offline library access without networking

---

### R6 PCH Variant

The R6 PCH (Power/Charge Hub) variant uses a custom 63 × 66 mm two-layer carrier board for the UPS Module 3S, charge input and sense routing. It does not carry a separate microcontroller or display.

#### Target Hardware

- **Host Case:** Peli 1200 (rugged, IP67-rated)
- **Computer:** Raspberry Pi 5 (4 GB)
- **Display:** Waveshare 7" DSI LCD (C)
- **Keyboard:** Rii K06 Touch Keyboard
- **Storage:** NVMe SSD
- **Power:** UPS Module 3S with three 18650 cells

#### Features

- UPS Module 3S (3S 2×4 configuration) with integrated protection
- Charge-input routing and 12.6 V / 2 A input
- I²C routing for the UPS INA219
- Modular carrier for power and charge connections

#### Design Highlights

- **Power Management:** 12.6 V charge input and UPS carrier
- **I²C Integration:** INA219 routed to the Pi
- **Modular Design:** the carrier is serviceable without opening the case

---

### Build Instructions

#### Basic Setup

```bash
git clone https://github.com/jsoeterbroek/ktemata.git
cd ktemata
python3 -m venv .venv
source .venv/bin/activate
pip install -r packages.txt
```

#### Build Variants

1. **R6 (Perfboard)** — lower cost, faster iteration
2. **R6 PCH** — custom power/charge carrier

```bash
python3 cad/tools/export.py --variant R6_PERFBOARD
python3 cad/tools/export.py --variant R6_PCH
```

---

### Documentation

- [`docs/R6.md`](docs/R6.md) — R6 hardware and CAD specifications
- [`cad/kicad/r6/README.md`](cad/kicad/r6/README.md) — KiCad design rules and board documentation
- [`work/scripts/check_r6.sh`](work/scripts/check_r6.sh) — interference check script for R6 variants

---

### License

[Add license information here]
