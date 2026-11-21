## Ktemata (R6 — Default Build)

R6 is the default build. Two variants: 'R6' uses a perfboard with DC5521 charge management, and 'R6 PCH' uses the custom PCH carrier board with FireBeetle 2 integration. Both keep Wikipedia, maps and Gutenberg when power and networking are gone.

---

### R6 Perfboard Variant

The base R6 variant uses a flat perfboard for cost-effectiveness and rapid iteration. The DC5521 charge IC manages the charging interface directly from the supplied USB-C lead, eliminating the need for a separate carrier board while maintaining the rugged Peli 1200 enclosure design.

#### Target Hardware

- **Host Case:** Peli 1200 (rugged, IP67-rated)
- **Microcontroller:** FireBeetle 2 ESP32-UE (N16R2)
- **Display:** Waveshare 7" DSI LCD
- **Keyboard:** Rii K06 Touch Keyboard
- **Storage:** NVMe SSD
- **Charging:** USB-C with DC5521 charge management

#### Features

- FireBeetle 2 firmware for battery monitoring and system status
- I²C OLED display for quick status checks
- Integrated charge sense circuit using DC5521
- Wikipedia, maps, and Gutenberg content preservation
- Offline library access without networking

---

### R6 PCH Variant

The R6 PCH (Power/Communication Hub) variant uses a custom 63 × 66 mm two-layer carrier board that integrates the FireBeetle 2 ESP32-UE with charge management and I²C routing. This board provides a robust, socketed interface for easy board replacement and firmware updates.

#### Target Hardware

- **Host Case:** Peli 1200 (rugged, IP67-rated)
- **Microcontroller:** FireBeetle 2 ESP32-UE (N16R2) via socketed J9/J10
- **Display:** Waveshare 7" DSI LCD
- **Keyboard:** Rii K06 Touch Keyboard
- **Storage:** NVMe SSD
- **Charging:** USB-C with DC5521 charge management via UPS Module 3S

#### Features

- Socketed FireBeetle 2 integration for easy firmware updates
- I²C bus routing to OLED and system components
- Charge-sense divider (R2/R3/C1) for precise battery monitoring
- UPS Module 3S (3S 2×4 configuration) with integrated protection
- Dual FireBeetle 2 sockets for hot-swapping capability
- Full I²C routing for status OLED and peripherals

#### Design Highlights

The PCH carrier board provides a complete power and communication hub:

- **Power Management:** DC5521 handles charge sense and management from the USB-C input
- **I²C Integration:** Dedicated trace routing to OLED, status displays, and sensors
- **Dual FireBeetle Support:** Two socketed FireBeetle 2 ESP32-UE chips enable hot-swapping and failover
- **Modular Design:** Detachable modules allow for firmware upgrades without case modification

---

### Build Instructions

#### Basic Setup

```bash
# Clone repository
git clone https://github.com/<your-org>/ktemata.git
cd ktemata

# Install dependencies
python3 -m venv .venv
source .venv/bin/activate
pip install kicad-cli openscad

# Export the desired variant
python3 cad/tools/export.py --variant R6
```

#### Build Variants

1. **R6 (Perfboard)** — Lower cost, faster iteration
   - Simple 3-layer perfboard with DC5521 charge management
   - No carrier board overhead
   - Ideal for prototyping and early development

2. **R6 PCH** — Production-ready integration
   - Custom carrier board with socketed FireBeetle 2
   - Integrated I²C routing and charge management
   - Production-grade design with failover capability

---

### Documentation

- [`docs/R6.md`](docs/R6.md) — R6 variant hardware and CAD specifications
- [`cad/kicad/r6/README.md`](cad/kicad/r6/README.md) — KiCad design rules and board documentation
- [`work/scripts/check_r6.sh`](work/scripts/check_r6.sh) — Interference check script for R6 variants

---

### License

[Add license information here]
