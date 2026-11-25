# YouTube script — first draft

**Working title:** *The Offline Library — knowledge that survives the internet*  
**Target length:** ~12 minutes  

## Important

- **No music.** Use room tone, latch clicks, keyboard, fan, drive and case handling. Keep the sound close and quiet.
- **Pace:** The script is a guide; do not read it like a list.
- **Tone:** practical, calm, curious. Not apocalyptic, not a product advert.

## Script

### 0:00
>
> What if the internet went down, and stayed down?
>
> Not for an hour. Not for a weekend. Long enough that the cloud, the streaming services and the search results were no longer available.
>
### 0:25
>
> Most of what we know now lives behind a connection. The books are digital. The maps are online. The manuals are a web page. If the connection and the grid both go, a lot of knowledge goes with them.
>
> This is Ktemata. A small, rugged, offline library. It is not a fantasy about the end of the world. It is a practical answer to a simpler question: what do you want to have readily available to you when the network is not?
>
### 0:50
>
> Knowledge has never survived by itself. It survives because someone copies it, carries it, and teaches it again.
>
> Ancient civilisations carved in stone and wrote on clay tablets. The Greeks wrote on papyrus. The famous Library of Alexandria tried to hold all the worlds' knowledge in one place. When it declined, the texts did not vanish all at once; they survived in fragments, in copies, in translations, in people who thought they were worth carrying and preserving.
>
### 1:20
>
> Medieval monks copied manuscripts laboriously by hand. Later, printed made copies became cheap enough to spread. Then modern science built its own record: observations, journals, textbooks, diagrams, instructions.
>
> Each step made knowledge easier to copy — and more dependent on a system. Today that system is a data centre somewhere else, a subscription, a working router and a power grid.
>
### 1:80
>
> A library that only exists online is a library with a single point of failure.
>
> Ktemata moves a useful slice of that record back into your hands. Wikipedia. Maps. Gutenberg books. Manuals. It runs on the device, from a local copy. No account. No cloud. No connection.
>
### 2:40
>
> Ktemata is a Raspberry Pi 5 in a Peli 1200 case. A 7-inch touch display. A compact keyboard. An NVMe SSD drive. And a Waveshare UPS Module with three large cells, so it keeps running when the plug is pulled.
>
> The rugged and waterproof case is the point as much as the computer in it. It is IP67-rated, it closes, and it can be carried. The electronics sit in a printed cassette; the display and Pi are one rigid assembly; the keyboard lives in the lid.
>
### 2:90
>
> It is deliberately simple. One computer. One display. One storage path. One battery system. No separate status microcontroller, no second screen, no extra radio. Every additional component is another thing to fail when nothing else works.
>
> The hard part is not the idea. The hard part is making the pieces fit, documenting them, and making the software install itself. That work is here.
>
### 3:40
>
> The build starts with the case and the printed parts. The tray carries the UPS and the power path; the display, the Raspberry Pi and NVMe hat hang from the deck as one stack.
>
> The power board is a Waveshare UPS Module 3S. Three matched batteries in series. It takes a 12.6-volt, 2-amp charge input and delivers 5 volts to the Pi. The gauge is an INA219 on the pack side, and the Pi reads it directly.
>
### 4:20
>
> The core component is a 4 GB Raspberry Pi 5. The display is a 7-inch DSI panel. Storage is an NVMe Base Duo with a 512 GB (or 1T) drive; the library lives there, not on a microSD card.
>
> The wireless keyboard is a Rii K06 complete with backlighting and a touch pad. It fits the lid recess and leaves the display free. The lid carries only the keyboard; there is no status display or button harness to route through the hinge.
>
### 6:00
>
> The admin power page shows whether it is on power or on battery, the charge, and the estimated runtime.
>
> The software is installed by a script. It sets up all local configuration, Kiwix, the local library service, the admin page, the Wi-Fi mode switch and the optional AI stack. The difficult integration is already done.
>
### 7:20
>
> The whole device runs from one 5-volt rail. At idle with the display on it draws about 6.2 watts. With the screen off, about 4 watts. The 3.0 Ah pack holds 33.3 watt-hours; 3.5 Ah cells hold 38.9.
>
> In practice that is roughly three to four hours of reading or idle screen-on use, and longer with the display off. Heavy CPU work is shorter. The point is not an all-day workstation. The point is a library that works for a session, and recharges.
>
### 7:50
>
> Charging is one 12.6-volt input. Mains through the supplied adapter, a suitable solar regulator, or hand crank. The UPS passes power through while it charges, so you can read with the panel connected.
>
> This is where the low power design earns its keep. A smaller pack, a smaller panel and a smaller charger are enough. The device is not trying to be a data centre. It is trying to be a book and a map when the data centre is gone.
>
### 8:45
>
> The device serves its own library. Connect to the hotspot, open the admin page, and everything is local.
>
> The top row is the state of the box: storage and archive count, the library index, and power. A new ZIM file is uploaded here. It is checked, written to the drive, and then published by rebuilding the library index. The same page starts and stops the library service.
>
### 9:30
>
> There is no terminal needed for normal use. The admin is deliberately plain: one page, a handful of actions, and clear states. Indexed, not indexed, indexing, error. The same four states appear for the library and for the optional AI indexes.
>
> The library itself is Kiwix on port 8080 ***(pronounced 'eighty-eighty')***. Wikipedia, Wiktionary, Gutenberg, maps, manuals — whatever ZIM files you choose to carry. Search, read, follow links. It behaves like a local website because it is one.
>
### 10:05
>
> No internet connection is involved. The optional hotspot is a local access point with no uplink. Clients cannot wander out through it, and the library does not need to phone home.
>
> This is the useful part: the person with the flat phone can still read. The library is not a subscription. It is a box with a battery.
>
### 10:50
>
> There is an optional local AI layer. It is not the reason to build the device, and it is not required for the library to work.
>
> A small language model can search the indexed documents and ZIM archives and answer with citations. On a Pi it is slow. It can be wrong even when the retrieval is right. It is useful as a librarian — “find the passage, show me the source” — not as an all-knowing oracle.
>
### 11:30
>
> That is the honest trade: a local model costs power, time and disk, and gives you a private way to ask questions about the shelf. If you do not want it, skip it. The books will still be available.

### 11:50

> Ktemata is Greek for “possessions”. Thucydides called his history *a possession for all time* — written down so that what happened would still be there for whoever came later.
>
> That is the whole idea. Not a bunker. Not a subscription. A documented, repairable, low-power box that keeps a library in the room when the network is not.
>
### 12:15
>
> It is a DIY build, but the difficult work is already done: the case, the 3D print files, the power path, the install scripts, the admin page, the documentation. You bring the parts, the patience and your own library.
>
> The build guide is at ktemata.org. The source, the models and the scripts are on GitHub. Start with one ZIM. Read something with the network off.

### 12:40
