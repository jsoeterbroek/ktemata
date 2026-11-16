# KiCad 10.0

## CLI
Use the cli to edit, create kicad filesm, kicad-cli location:
/Applications/KiCad/KiCad.app/Contents/MacOS/kicad-cli

## Design rules check
Check design rules after each edit, eg.:
/Applications/KiCad/KiCad.app/Contents/MacOS/kicad-cli pcb drc pch_layout.kicad_pcb
# Design for Power Distribution & Communication Hub (PCH) carrier board.

This board will serve as the central nervous system for the Ktemata r6, providing structured power rails, a centralized sensing circuit, and the required safety/control features.

### Design Specifications

1. Input & Switching (Charging Circuit):
  - DC-099 Jack: The primary input for the 12.6V source.
  - 16mm Latching Switch (J3): Controls the CHG_12V6 rail.
  - Power Indicator: An LED (fed from UPS_5V) that reflects the switching state.
  - Charging Sense: A voltage divider (47k / 10k) and capacitor (100nF) to sense the CHG_12V6 rail and report status to the FireBeetle.
2. Battery & Safety:
  - 3S Battery Connector (J4): For the 3x 18650 pack.
  - 5A Fuse: Integrated into the BATT_3S_P line to protect the internal circuitry.
  - UPS Integration: The UPS_5V and AUX_5V rails are derived from the Waveshare UPS Module (which is connected to the battery).
3. System Rails & Connectivity (Pin Rails):
  - 3.3V Rail: Powering the FireBeetle, RTC, and OLED.
  - 5V Rail: Powering the Raspberry Pi 5 and the 7" Display.
  - I2C Bus: Shared between the FireBeetle and the DS3231 RTC.
  - PCIE Header: Standard for the NVMe Base Duo.
  - USB Header: Dedicated for the Rii K06 keyboard.
