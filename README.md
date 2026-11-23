<p align="center">
  <img src="Media/Logo.png" alt="BananaFarm" width="300">
</p>

# BananaFarm

Lasher farming helper for Dire Maul East on OctoWoW (Vanilla 1.12 client with SuperWoW and Nampower). Part of [BananaForge](https://github.com/BananaForge).

English and German, switch with `/bf lang en|de|auto`.

Version 0.7.1

## Getting started

1. **Setup:** On first start you pick your language and the modules you want. Then you enter your twink (bank alt) and your mail characters. Both can be skipped.
2. **Start a session:** Button in the small bar or in the main window (`/bf`). From now on BananaFarm counts time, loot, gold per hour and resets.
3. **Farm:** New items are sorted automatically. If an item has no AH price, a small pop-up asks where it should go.
4. **Open a vendor or mailbox:** The vendor list is sold, the mail list is sent to your bank alt after a confirmation.

Everything else is in **Settings**. Hover over an option for an explanation.

## Features

### Session and gold per hour
- Start/stop in the bar or the main window, stopping asks for confirmation. The bar shows gold for the current run (since the last reset), for the session and per hour, plus duration, resets and pulls.
- Every item counts exactly once, when you loot it: with its vendor value, or with its AH price if it is on the mail list. Gold from selling is not counted twice.
- Short offline time while relogging for a reset counts, so gold per hour matches real time (breaks over 15 minutes do not count).
- Repair costs at a vendor (e.g. Repairbot) are subtracted.
- Disenchanting: the disenchanted item leaves the statistics, the materials count with their AH price.
- Warning when your bags are almost full.

### Lists and sorting
- Four lists: **Vendor** (sold), **Mail** (sent to your bank alt), **Never touch** (never sold or mailed), **Unsorted** (no decision yet).
- Default rule: AH price at least x times the vendor value (default 1.5) and above the minimum price goes to Mail, otherwise Vendor. Gray items go to Vendor. Manual assignments always win.
- **Sort automatically:** button in the Unsorted list. Everything with an AH price is sorted by the default rule. With several mail characters, BananaFarm asks for the recipient per item.
- Alt+click an item in your bags to choose its list. In the list, colored buttons move an item.
- AH scan at the auction house: targeted search for known items, full market price. Unknown item names are fetched from the server first.

### Vendor
- Opening a vendor sells the vendor list automatically.
- **Price check:** every item is sold once on its own the first time. BananaFarm compares the gold received with the vendor table and uses the real OctoWoW price from then on. Differences: `/bf prices`.
- **Sell protection:** during a session you can only sell by hand what is on the vendor list. Alt+right-click sells anyway.

### Mail
- At a mailbox BananaFarm asks and then sends the mail list to your bank alt.
- **Package mail:** several stacks per mail, grouped by recipient and item. If that does not work on a client (e.g. with TurtleMail), it falls back to sending one by one.
- Several mail targets: each item on the mail list can have its own recipient.

### Resets
- Instance resets are detected and stored with their time, this survives relogs and character switches.
- The bar shows `n/5` and a countdown until the oldest reset drops out of the hour.
- On the twink, the **Reset inst.** button resets the instance (same way as the portrait menu) and shows the server's answer in chat.

### Pull counter and hunter mode (needs SuperWoW)
- Counts mobs fighting you or your pet. With nameplates on (V key), mobs that only chase you are counted too.
- **Hunter mode** (on automatically for hunters): corpses count, and you get a warning at the limit (default 80).

### Sync with your twink
- Lists, all known items (also unsorted), AH prices and resets are kept in sync with your twink. Enter the twink on the farm character only, pairing is automatic. Both have to be in a group.
- Checksums instead of history: a comparison costs one message, only differences are sent, lost messages are repaired on the next comparison. Manual changes go out after 2 seconds. `/bf sync status` shows the state.

### Speedrun
- **Fully automatic:** start a session and enter Dire Maul, lap 1 starts. Every instance reset (also by your twink, also while you are logged out) ends the lap at the exact reset time and starts the next one. Logging out does not stop the clock.
- **Heat:** 5 laps (reset limit). After that, the next lap 1 starts at the portal again. Stopping the session deletes an incomplete heat.
- The bar shows `Lap 1 xx:xx | Lap 2 xx:xx | ...`, the running lap in gold.
- Dashboard with tiles, the current heat (discard button), recent heats with Whip Lasher kills and loot per lap, and posting to chat.
- **Lap check:** after every reset BananaFarm checks the lap (at least 2 minutes, 78 Whip Lashers, 2g loot, no second character in the instance) and tells you right away if it does not count. Invalid laps do not count for best times.
- **Rules:** a rules window appears when you turn on the Speedrun module and before you join an event, and via the "Rules" button.
- **Lap data:** `/bf lapstats` or the "Lap data" button shows time, Whip Lasher kills, all kills, loot and looted corpses per lap as text to copy.

### Guild Tournament (optional)
- Leaderboards with your guild: fastest heat, week, month and overall, sortable by heats, best time or gold (gold only if you share it).
- Every Sunday a pop-up shows the weekly winners.

### Lasher Championships (optional, global event)

<p align="center">
  <img src="Media/Event.jpg" alt="Lasher Championships" width="480">
</p>

- A global event across guilds (and factions, thanks to OctoWoW's cross-faction chat). The addon joins its own hidden channel `BananaFarmLC`, addon messages cannot use the World chat.
- Only Bareg and Lumihunt can create an event: time frame, ranking (best time, number of heats or gold), max participants, registration until start or end, minimum lap time, minimum Whip Lashers and minimum loot per lap, and whether heats without other witnesses count.
- Players join with a fighter name (free text or random). The overview shows fighter name, character, class, guild, value and witnesses.
- **Witnesses:** every client in the channel records when a participant's heat starts and ends. Others pass this on when someone comes online, so the organizer does not have to be online. A heat whose claimed time is clearly shorter than what witnesses saw does not count.
- The event ends with a winners pop-up.
- Version 0.7.1 has no entry fee and no prize money. That part will only come after written approval from the OctoWoW team.

### Wish list
- Shift-click an item into the list, enter mob name and drop rate. BananaFarm counts your kills and shows your chance so far and how many kills are still needed.

### Support
- In the donation window (`/bf donate` or Settings) you can set up a one-time donation or a subscription (per session or per run). Nothing is sent until you confirm at a mailbox, at most 100g per mail. Donations go to Bareg on N'Zoth.

## Installation

**Octo Launcher:** add this repository as an addon: `https://github.com/BananaForge/BananaFarm`

**Manually:** [download the ZIP](https://github.com/BananaForge/BananaFarm/archive/refs/heads/main.zip), unpack it and rename the folder to `BananaFarm` (GitHub adds `-main`). Copy it to `Interface/AddOns/`.

## Commands

| Command | Effect |
| --- | --- |
| `/bf` | open or close the window |
| `/bf start`, `/bf stop` | start or end a farm session |
| `/bf alt Name` | set the twink (bank alt) and pair with it |
| `/bf mail` | send the mail list at a mailbox |
| `/bf sell` | sell the vendor list at a vendor |
| `/bf prices` | vendor price check result (`/bf prices reset`: check again) |
| `/bf reset` | reset instances (gets counted) |
| `/bf sync` | sync with the twink (`status`: state, `debug`: show messages) |
| `/bf lapstats` | lap data (Whip Lashers, loot) to copy |
| `/bf event` | open the Lasher Championships view |
| `/bf wish Item` | add a wish item (shift-click a link) |
| `/bf scan` | fetch AH prices (at the auction house) |
| `/bf bar` | show or hide the small bar (also via key binding) |
| `/bf donate` | open the donation window |
| `/bf lang en\|de\|auto` | switch language |
| `/bf probe` | check client mods (for the developers) |

## License

MIT, see `LICENSE`. The vendor values in `VendorData.lua` come from ShaguTweaks (MIT, Copyright 2021 Eric Mauser), the license text is in the file.
