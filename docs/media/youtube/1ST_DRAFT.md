# YouTube script — first draft

**Working title:** *The Offline Library — knowledge that survives the internet*  
**Target length:** 10–12 minutes  
**Format:** voice-over + hands-only build footage, archival stills/animation and screen recordings. No music. No face on camera.  
**Status:** draft 1 for review; timings are targets, not locked.

## Original brief

- About 10–12 minutes, no music.
- Use photos and video of the assembly and the final result.
- Show only hands, never a face.
- Strong thumbnail with the text **“Offline Library”** and the question: *“What if one day the Internet goes down (permanently) and all our accumulated knowledge is no longer available to restart society?”*
- Possible scenario: the internet and electricity are down for a long time.
- Open with the story of human knowledge: ancient Greece, parchments, stone tablets, the Library of Alexandria, medieval monks copying manuscripts, the rise of modern science, modern textbooks.
- First ~30%: introduction, features, stills/animation.
- Second ~30%: components, building and connecting, video.
- A short optional AI section: pros and cons, slowness, a local “librarian” for the library.
- Third ~30%: using the admin interface and Kiwix in a desktop browser, screen recording.
- Closing: big display name as on the stickers.
- Emphasise low power, solar/hand-crank charging, KISS/robustness and DIY — the hard work is already done.

---

## Thumbnail

**Frame:** 1280 × 720. The open Ktemata on a dark table, screen glowing, seen from a low three-quarter angle. A hand rests on the keyboard; no face. The background is out of focus and cold.

**Text, left side, two blocks:**

> **OFFLINE  
> LIBRARY**

Then, smaller beneath it:

> *What if one day the Internet goes down — permanently — and all our accumulated knowledge is no longer available to restart society?*

**Right side:** the device, not a stock photo. Use the real build. The words must remain readable at phone size; do not put text over the screen. Keep the palette warm amber/cream on near-black.

---

## Script

### 0:00–0:50 — Cold open

**[VISUAL]** Black. A cursor blinks in an empty browser address bar. Type a familiar address; “This site can’t be reached.” Cut to a wall socket switched off, then a dark room. Slow push-in on the closed Peli case. A hand flips the latches; the lid opens; the screen and keyboard are there. Hold on the screen.

**[VO]**
> What if the internet went down, and stayed down?
>
> Not for an hour. Not for a weekend. Long enough that the cloud, the streaming services and the search results were no longer part of the room.
>
> Most of what we know now lives behind a connection. The books are digital. The maps are online. The manuals are a web page. If the connection and the grid both go, a lot of knowledge goes with them.
>
> This is Ktemata. A small, rugged, offline library. It is not a fantasy about the end of the world. It is a practical answer to a simpler question: what do you want to have in the room when the network is not?

**[ON-SCREEN]** *Ktemata — offline library. No network required.*

---

### 0:50–2:40 — Knowledge is a chain of copies

**[VISUAL]** Archival/animated sequence, slow and tactile: Greek papyrus and carved stone; a stylised Library of Alexandria; a monk’s hand copying a manuscript by candlelight; a printing press; a 19th-century scientific notebook; a stack of modern textbooks. Keep it quiet and physical — paper, ink, stone, dust. No glossy stock “cyber” imagery.

**[VO]**
> Knowledge has never survived by itself. It survives because someone copies it, carries it, and teaches it again.
>
> The Greeks wrote on papyrus and carved in stone. The Library of Alexandria tried to hold the world in one place. When it declined, the texts did not vanish all at once; they survived in fragments, in copies, in translations, in people who thought they were worth carrying.
>
> Medieval monks copied manuscripts by hand. Later, print made copies cheap enough to spread. Then science built its own record: observations, journals, textbooks, diagrams, instructions.
>
> Each step made knowledge easier to copy — and more dependent on a system. Today that system is a data centre somewhere else, a subscription, a working router and a power grid.
>
> A library that only exists online is a library with a single point of failure.

**[VISUAL]** Cut back to the hands opening a ZIM archive on the laptop, then the same content in the Ktemata browser. Show the library loading with the network cable unplugged.

**[VO]**
> Ktemata moves a useful slice of that record back into the room. Wikipedia. Maps. Gutenberg books. Manuals. It runs on the device, from a local copy. No account. No cloud. No connection.

---

### 2:40–3:40 — What it is

**[VISUAL]** Slow orbit of the finished device on a table; close-ups of the display, keyboard, latches, ports and the UPS board. Cut to a hand carrying it by the handle. Then a simple animated block diagram: **Pi 5 → display / storage / keyboard / UPS**, with **offline only** around it.

**[VO]**
> Ktemata is a Raspberry Pi 5 in a Peli 1200 case. A 7-inch touch display. A compact keyboard. An NVMe drive. And a Waveshare UPS Module 3S with three 18650 cells, so it keeps running when the plug is pulled.
>
> The case is the point as much as the computer. It is IP67-rated, it closes, and it can be carried. The electronics sit in a printed cassette; the display and Pi are one rigid assembly; the keyboard lives in the lid.
>
> It is deliberately simple. One computer. One display. One storage path. One battery system. No separate status microcontroller, no second screen, no extra radio. Every additional board is another thing to fail when nothing else works.
>
> The hard part is not the idea. The hard part is making the pieces fit, documenting them, and making the software install itself. That work is here.

**[ON-SCREEN]** *Pi 5 · 7″ DSI · NVMe · UPS 3S · 3 × 18650 · Peli 1200*

---

### 3:40–7:20 — Components and build

**[VISUAL]** Hands-only build montage. Keep shots long enough to see what is happening. Suggested order:

1. Empty Peli case, foam, printed tray and deck.
2. Test-fit the UPS Module 3S and three cells. **Do not show unsafe pack handling.**
3. Mount the display/Pi/NVMe stack; show the standoffs and the deck.
4. Connect the DSI and touch leads; route them through the deck slot.
5. Fit the PCH/perfboard power path; connect the 12.6 V charge lead and UPS harness.
6. Insert the cells; show the insulating rings and polarity check.
7. Fit the keyboard into the lid; close the latches; first boot.
8. Final result, open and closed.

**[VO]**
> The build starts with the case and the printed parts. The tray carries the UPS and the power path; the display, Pi and NVMe hang from the deck as one stack.
>
> The power board is a Waveshare UPS Module 3S. Three matched 18650 cells in series. It takes a 12.6-volt, 2-amp charge input and delivers 5 volts to the Pi. The gauge is an INA219 on the pack side, and the Pi reads it directly.
>
> The Pi is a 4 GB Raspberry Pi 5. The display is a 7-inch DSI panel. Storage is an NVMe Base Duo with a 512 GB drive; the library lives there, not on a microSD card.
>
> The keyboard is a Rii K06. It fits the lid recess and leaves the display free. The lid carries only the keyboard; there is no status display or button harness to route through the hinge.
>
> The battery is the part to slow down for. Matched cells, correct polarity, insulating rings, the supplied harness, and the UPS output switch off while you work. Do not assemble or rewire the pack powered. The point is a device you can trust, not a race.

**[VISUAL]** Close-up of `vcgencmd get_throttled` returning `0x0`; then the admin Power box showing **On power**, battery percentage and runtime.

**[VO]**
> First boot is a check, not a victory lap. The display comes up. The NVMe is detected. The UPS gauge answers. The power page shows whether it is on power or on battery, the charge, and the estimated runtime.
>
> The software is installed by a script. It sets up Kiwix, the local library service, the admin page, the Wi-Fi mode switch and the optional AI stack. The difficult integration is already packaged.

---

### 7:20–8:45 — Power, solar and the hand crank

**[VISUAL]** Power-path animation: **12.6 V charge input → UPS Module 3S → 5 V rail → Pi/display/NVMe**. Then a solar panel on a table, a hand-crank generator turning, and the admin Power box. Use real footage where possible; label animations clearly.

**[VO]**
> The whole device runs from one 5-volt rail. At idle with the display on it draws about 6.2 watts. With the screen off, about 4 watts. The 3.0 Ah pack holds 33.3 watt-hours; 3.5 Ah cells hold 38.9.
>
> In practice that is roughly three to four hours of reading or idle screen-on use, and longer with the display off. Heavy CPU work is shorter. The point is not an all-day workstation. The point is a library that works for a session, and recharges.
>
> Charging is one 12.6-volt input. Mains through the supplied adapter, a suitable solar regulator, or the hand crank. The UPS passes power through while it charges, so you can read with the panel connected.
>
> This is where the low power design earns its keep. A smaller pack, a smaller panel and a smaller charger are enough. The device is not trying to be a data centre. It is trying to be a book and a map when the data centre is gone.

**[ON-SCREEN]** *≈ 6.2 W screen-on idle · ≈ 4.0 W screen-off · 33.3/38.9 Wh · 12.6 V / 2 A charge*

---

### 8:45–10:50 — Admin and the library

**[VISUAL]** Screen recording. Laptop connects to the Ktemata hotspot; browser opens `http://10.10.10.1:8081`. Log in. Show the four boxes; upload a ZIM; rebuild the library index; show the archive table and the AI-index column. Then open `http://10.10.10.1:8080`, search Wikipedia, open an article, use a map/book. Keep the cursor deliberate.

**[VO]**
> The device serves its own library. Connect to the Ktemata hotspot, open the admin page, and everything is local.
>
> The top row is the state of the box: storage and archive count, the library index, and power. A new ZIM is uploaded here. It is checked, written to the drive, and then published by rebuilding the library index. The same page starts and stops the library service.
>
> There is no terminal needed for normal use. The admin is deliberately plain: one page, a handful of actions, and clear states. Indexed, not indexed, indexing, error. The same four states appear for the library and for the optional AI indexes.
>
> The library itself is Kiwix on port 8080. Wikipedia, Wiktionary, Gutenberg, maps, manuals — whatever ZIM files you choose to carry. Search, read, follow links. It behaves like a local website because it is one.
>
> No internet connection is involved. The hotspot is a local access point with no uplink. Clients cannot wander out through it, and the library does not need to phone home.

**[VISUAL]** Show a phone or laptop in airplane mode, still connected to the Ktemata hotspot, reading an article. Cut to the case closed and the screen off.

**[VO]**
> This is the useful part: the person with the flat phone can still read. The library is not a subscription. It is a box with a battery.

---

### 10:50–11:50 — The optional AI librarian

**[VISUAL]** Screen recording of the admin Ask box: choose **Documents** or **All indexed ZIMs**, ask a question, show the answer and sources. Cut to a terminal running `ktemata-ai zim-ask`. Keep the response time visible and honest.

**[VO]**
> There is an optional local AI layer. It is not the reason to build the device, and it is not required for the library to work.
>
> A small language model can search the indexed documents and ZIM archives and answer with citations. On a Pi it is slow. It can be wrong even when the retrieval is right. It is useful as a librarian — “find the passage, show me the source” — not as an oracle.
>
> That is the honest trade: a local model costs power, time and disk, and gives you a private way to ask questions about the shelf. If you do not want it, skip it. The books still open.

**[ON-SCREEN]** *Optional · local only · slow · sources are the useful part*

---

### 11:50–12:40 — Close

**[VISUAL]** Return to the device on the table. Cut to the sticker graphics: **KTEMATA** and **κτῆμα ἐς ἀεί**. Then the device open with a book on screen, then the case closed. End on the logo/URL card.

**[VO]**
> Ktemata is Greek for “possessions”. Thucydides called his history *a possession for all time* — written down so that what happened would still be there for whoever came later.
>
> That is the whole idea. Not a bunker. Not a subscription. A documented, repairable, low-power box that keeps a library in the room when the network is not.
>
> It is a DIY build, but the difficult work is already done: the case, the power path, the install scripts, the admin page, the documentation. You bring the parts, the patience and your own library.
>
> The build guide is at ktemata.org. The source, the models and the scripts are on GitHub. Start with one ZIM. Read something with the network off.

**[ON-SCREEN]** *ktemata.org · github.com/jsoeterbroek/ktemata · κτῆμα ἐς ἀεί*

---

## Shot list / assets

- **Real build footage, hands only:** case opening, tray/deck, UPS and cells, display/Pi stack, DSI/touch leads, keyboard, first boot, final closed case.
- **Detail stills:** UPS Module 3S, INA219, 18650 cells with insulating rings, NVMe drive, display connector, case latches.
- **Screen recordings:** admin `:8081` (storage, upload, index rebuild, power, AI index), Kiwix `:8080` (search, article, map/book), optional Ask box, terminal `ktemata-ai`.
- **Archival/animation:** papyrus/stone, Library of Alexandria, manuscript copying, printing press, 19th-century science, textbooks. Use public-domain sources and a consistent paper/ink treatment.
- **Diagrams:** power path, offline topology, four admin states. Build them as simple line animations; do not use glossy stock 3D.
- **Closing graphics:** KTEMATA wordmark, Greek phrase, URL/GitHub card.

## Production notes

- **No music.** Use room tone, latch clicks, keyboard, fan, drive and case handling. Keep the sound close and quiet.
- **No face.** Hands, device and screen only.
- **Pace:** let the build shots breathe. Cut on actions, not on every word. The script is a guide; do not read it like a list.
- **Captions:** include on-screen numbers for power and runtime; keep them visible long enough to read.
- **Accuracy:** current R6 hardware, UPS Module 3S, three 18650 cells, 7-inch DSI display. Do not reuse R5 footage without labelling it as an earlier revision.
- **Safety:** show correct cell polarity, insulating rings and the UPS output switch off during assembly. Do not imply that a 5 V USB-C charger can charge the 3S pack.
- **Tone:** practical, calm, curious. Not apocalyptic, not a product advert.
- **Thumbnail copy:** exact question from the brief; do not turn it into a claim that the internet *will* permanently fail. It is a thought experiment that motivates the build.

## Open questions for review

1. Do we have enough real R6 assembly footage for the 3½-minute build section, or do we need a dedicated shoot?
2. Should the cultural-knowledge opening use licensed archival footage or original animation? Animation is safer and more consistent.
3. Is the AI section staying in the main cut, or becoming a separate follow-up video?
4. Final runtime target: 10 minutes (tighter) or 12 minutes (more build detail)?
