# PocketTerm35 as a parts donor for Ktemata r2 — feasibility

**Bottom line: not recommended as a donor for the current 5" r2 design.** The PocketTerm35 is a complete
3.5" HDMI terminal with a 1S 5000 mAh UPS; its screen is much smaller and HDMI-based, its display/glass is
optically bonded to the PocketTerm front shell, and there is no room for the r2 UPS HAT (E), 4× 21700 pack or
NVMe. It is a plausible **alternative device** if you accept a 3.5" screen and a much smaller battery, and the
**keyboard is the one part worth prototyping separately**.

Research date: 2026-10-20. Sources at the end.

---

## What the PocketTerm35 actually is

| Item | PocketTerm35 |
|---|---|
| Product / SKU | PocketTerm35, `PocketTerm35-RPI-ACCE-EN` = accessory kit (SKU 34031/34032) |
| Body | 93.5 × 168.5 × 37 mm |
| Display | **3.5" IPS, 640 × 480 (4:3), HDMI**, optical bonding, G+G toughened glass, 6H |
| Touch | Goodix **GT911**, 5-point capacitive, **I²C 0x5d** (some Waveshare overlays wrongly probe 0x14) |
| Keyboard | **67-key QWERTY silicone keyboard + D-pad/gamepad cluster**, ~93.5 mm body width |
| Keyboard controller | **RP2040 Pico, USB HID** `1209:0001`; open/reflashable firmware exists |
| Power | Onboard UPS, **1S 5000 mAh LiPo ≈ 18.5 Wh**, USB-C in, charge/use simultaneously |
| Pi support | Pi 4B / Pi 5, HDMI + USB; internal add-on height above the Pi is only **2.5 mm** |
| Price | Accessory kit from **$87.99** (without Pi/battery; check current option price); Pi 5 kit up to $181.99 |

Key facts from the official docs and community ports:
- The display is **plain HDMI 640×480**; the Waveshare device-tree overlays contain **only the GT911 touch
  node**, no display node. This is confirmed by the `therezor` OS boot notes.
- The touch controller answers at **0x5d**; the stock `waveshare-35dpi-4b` overlay expects 0x14, which is why
  touch fails until the overlay is patched.
- The keyboard is a **USB Pico HID device**; community firmware replaces the stock CircuitPython code and
  exposes keyboard + gamepad. The matrix is 7 rows × 10 columns, with backlight/audio PWM on the RP2040.
- The official assembly guide removes the **back cover only** (6 screws) to install the Pi and cables. It
  gives no procedure for removing the front glass, panel or keyboard.

---

## Reusing the screen

**Technically possible, but it changes the product.**

- It is a **3.5" 4:3** panel (active area ≈ 71 × 53 mm), versus the r2 DFR0550-V2's 120.7 × 75.8 mm module
  (≈ 108 × 65 mm active, 16:9). You would need a completely new face plate and a much smaller screen window.
- Video is **HDMI**, not DSI. The Pi 5 has micro-HDMI, so an adapter/cable works, but the current r2 case has
  no HDMI opening or cable route. The PocketTerm kit includes a micro-HDMI adapter and a 120 mm HDMI cable.
- Touch is **I²C GT911 at 0x5d**. The r2 design deliberately has no Pi I²C header (no 40-pin header), and the
  FireBeetle is the sensor I²C master. To use the touchscreen you would need to expose Pi I²C on GPIO2/3
  (soldered 4-pin header or a USB-I²C bridge) and add the GT911 overlay. The FireBeetle could read it, but
  forwarding touch events to the Pi is extra firmware work.
- Brightness is not specified by Waveshare. The r2 target is a 550 cd/m² sunlight-readable 5" panel; there is
  no evidence the PocketTerm 3.5" panel matches that.
- The display is **optically bonded to the front glass**, and the glass/panel are part of the PocketTerm front
  shell. The official guide does not describe separating them. Pulling the bonded assembly out of the shell
  is likely to damage the panel, the bonding or the shell. Reusing the **whole front assembly** is more
  realistic than extracting the bare panel, but then you are reusing the PocketTerm front, not building the
  r2 face.

**Verdict:** the screen does not drop into the r2 case. If you use it, you are designing a new 3.5" device.

---

## Reusing the keyboard

**This is the most promising part.**

- The keyboard is a **standalone USB HID device** (RP2040 Pico), not a raw matrix that needs the PocketTerm
  mainboard. It can be unplugged and connected to a Pi USB port. Community firmware (Pico SDK, TinyGo,
  CircuitPython) is available and the stock firmware can be replaced.
- It provides 67 keys with Ctrl, Alt, Fn, Tab, arrows, etc., plus a gamepad/D-pad. For terminal work it is
  usable, but the key pitch is small and the layout is not a full-size keyboard. The D-pad/gamepad cluster
  takes space that could otherwise be keys.
- The keyboard is only about **93.5 mm wide** (body width), versus the r2 `KB_PCB` footprint of **137 × 72 mm**
  and the 130 × 67 mm key window. It will not fill the existing face; you need a new bezel/face plate and a
  new keyboard support. The keyboard height and exact mounting hole pattern must be measured from a real unit.
- The 4-pin keyboard cable is **USB** on the Pico versions; the assembly guide warns not to plug it into the
  audio connector. Verify the pinout before applying power. If you only use the keyboard, you lose the
  PocketTerm mainboard's backlight/audio control path; the Fn brightness keys may not control an external
  display without rewiring.

**Verdict:** feasible as a keyboard donor if you are willing to design a new face/bezel around it. It solves
the “where do I buy a compact wired USB keyboard?” problem, but not the 5" screen problem.

---

## Reusing the RP2040 / mainboard

- The RP2040 is **soldered** to the keyboard/mainboard; there is no module to lift out. Reusing it means
  reusing the keyboard PCB or the whole PocketTerm mainboard.
- The PocketTerm mainboard also carries the HDMI display bridge, touch, audio, UPS and power management. If
  you reuse it, you are effectively using the complete PocketTerm front end. That can be a coherent device,
  but it is not a set of loose parts for the r2 case.
- The r2 design already has a **FireBeetle 2 ESP32-UE** for the status OLED and sensors; a second RP2040 is not
  needed unless you keep the PocketTerm keyboard.

**Verdict:** no meaningful cost saving from the MCU alone; use the keyboard PCB or the whole mainboard, not
the bare chip.

---

## Fit against the r2 requirements

| Requirement | Ktemata r2 | PocketTerm35 | Compatible? |
|---|---|---|---|
| Screen | 5" 800×480 DSI, 550 cd/m² target | 3.5" 640×480 HDMI, unknown nits | **No** — new face/case, different interface |
| Keyboard | 137 × 72 wired USB PCB | 67-key + gamepad, ~93.5 mm wide, USB HID | **Partial** — new bezel/mount |
| Power | UPS HAT (E) + 4× 21700 ≈ 72 Wh, solar/crank | 1S 5000 mAh ≈ 18.5 Wh | **No** — much smaller, no 4×21700 |
| Storage | 1 TB NVMe on M.2 BASE | 2.5 mm add-on height; optional PCIe-to-M.2 E | **No/limited** |
| Sensors | BME688, optional SEN66, trackball | Not designed for them | **No** — new internal layout |
| Case | 150 × 205 × 46.5 mm rugged | 93.5 × 168.5 × 37 mm plastic | **No** — different geometry |
| Glass | Face plate + display | G+G 6H optical bonding | **Only if using the 3.5" front assembly** |
| Cost | Core BOM ≈ €555–625 | $87.99 + Pi + battery | Cheaper only as a different device |

The PocketTerm has only **2.5 mm** of space above the Pi for add-ons. The r2 UPS HAT (E) + 4× 21700 stack is
tens of millimetres thick, so it cannot be fitted inside the PocketTerm. Conversely, a 3.5" screen and a
93 mm keyboard leave a lot of empty space in the 150 × 205 mm r2 case unless you redesign/shrink it.

---

## Cost view

The accessory kit at roughly **$88** includes the 3.5" HDMI screen, keyboard, mainboard, UPS, case, cables and
screws. That looks cheap compared with the r2 screen + UPS + cells + keyboard, but:

- You still need the Pi 5, a battery (if not included), and the r2-specific UPS/cells/NVMe/sensors.
- As a donor you would use the screen, keyboard and maybe the glass; the case, UPS and most of the mainboard
  become spare parts. The effective saving is much smaller than the kit price.
- The screen is smaller and HDMI; the battery is ~4× smaller; there is no room for 4×21700 or a proper NVMe
  stack.
- If you actually want the PocketTerm form factor, buying the **complete PocketTerm35-Pi5 kit** and using it
  as-is is the sensible cost-saving route — but it is a different product from the Ktemata r2.

---

## Recommendation

1. **Do not use the PocketTerm35 as a parts donor for the current 5" r2 design.** The display interface/size,
   power architecture, internal height and front-shell bonding are all working against it.
2. **Prototype the keyboard only** if keyboard sourcing is the blocker: buy the accessory kit, test the
   keyboard as a USB HID device on the Pi, reflash the open RP2040 firmware if needed, measure the keyboard
   outline/holes, and design a new 93.5 mm-wide face bezel. Treat the screen, glass, UPS and case as unused
   (or keep the PocketTerm as a second device).
3. **If cost and the 3.5" screen are acceptable**, buy a complete PocketTerm35-Pi5 kit as an alternative
   handheld; it is a coherent 3.5" terminal, but it does not meet the r2 5" / 4×21700 / solar / NVMe goals.
4. **For a toughened 5" panel**, source a 5" display with G+G glass/optical bonding. The PocketTerm glass is
   bonded to its 3.5" panel and cannot be transferred to the DFR0550.

---

## Sources

- Waveshare product page: <https://www.waveshare.com/pocketterm35.htm>
- PocketTerm35 docs: <https://docs.waveshare.com/PocketTerm35>
- Assembly guide (back cover only): <https://docs.waveshare.com/PocketTerm35/Assembly-Guide>
- Hardware/OS notes confirming HDMI 640×480 and GT911 0x5d:
  <https://github.com/therezor/PocketTerm35-OS/blob/main/boot/README.md>
- RP2040 keyboard firmware, matrix pins, USB HID:
  <https://github.com/black-ghost-off/pocketTerm35-keyboard-firmware>
- Hardware notes (keyboard Pico, display HDMI-A-1, backlight PWM):
  <https://github.com/eltony81/pocketterm35-tinygo/blob/main/POCKETTERM35_HARDWARE_NOTES.md>
- Touch 0x5d confirmation and trackball add-on:
  <https://github.com/H3llawts/PocketTerm35-Zynthian> and
  <https://github.com/H3llawts/PocketTerm35-Addons>
