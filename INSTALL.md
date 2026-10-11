# Installing Emulated-3 (EIII Rack: VST3 and Audio Unit for macOS)

Emulated-3 runs the **original E-mu Emulator III software**: its boot ROMs and Operating System 2.42. **None of this
is included.** You need your own copies of:

| You need | Required? | What it is |
|---|---|---|
| the two **boot ROMs** | yes | the EIII's boot firmware, two 16 KiB EPROM dumps |
| an **OS 2.42 hard disk image** | yes | the internal SCSI hard disk with Operating System 2.42 on it |
| **CD-ROM images** | optional | EIII sound library discs (banks are loaded from them through the original Load Bank) |

This guide covers where these go, how to install the plugin, the first start, and what to do when something doesn't
work. Nothing here links to sources of E-mu files: use dumps of hardware and media you own.

---

## 1. Install the plugin

Requirements: macOS 11 or later, Apple silicon or Intel (the plugin is a universal binary). Any DAW that hosts VST3 or
Audio Unit instruments: Logic Pro and GarageBand use the AU, Ableton Live, Cubase, Bitwig, Reaper and Studio One
either.

**From the release zip** ([Releases](https://github.com/ekwipt/Emulated-3/releases)): unzip it, copy
`EIII Rack.vst3` to `~/Library/Audio/Plug-Ins/VST3/` and `EIII Rack.component` to
`~/Library/Audio/Plug-Ins/Components/`, then clear the download quarantine (the plugins are not notarized):

    xattr -dr com.apple.quarantine ~/Library/Audio/Plug-Ins/VST3/"EIII Rack.vst3" ~/Library/Audio/Plug-Ins/Components/"EIII Rack.component"

**Or build it** (Xcode or the Command Line Tools, and CMake; `brew install cmake ninja`):

    cmake -B build -G Ninja -DCMAKE_BUILD_TYPE=Release
    cmake --build build

The first configure downloads the CLAP SDK, clap-wrapper, the VST3 SDK and the AudioUnitSDK at pinned versions. Then
copy the two bundles to the per-user plug-in folders:

    mkdir -p ~/Library/Audio/Plug-Ins/VST3 ~/Library/Audio/Plug-Ins/Components
    cp -R "build/EIII-Rack_assets/VST3/EIII Rack.vst3" ~/Library/Audio/Plug-Ins/VST3/
    cp -R "build/EIII-Rack_assets/AUv2/EIII Rack.component" ~/Library/Audio/Plug-Ins/Components/

(Or configure with `-DEIII_INSTALL_AFTER_BUILD=ON` and every build copies them there.) Your DAW then lists **EIII
Rack** as an instrument (the AU appears under the manufacturer **eiii-core**). Rescan plugins if it doesn't show up.
To check the AU, `auval -v aumu E3rk Eiii` should end with `AU VALIDATION SUCCEEDED`.

A locally built plugin is ad-hoc signed and runs on the Mac that built it. To give it to someone else it must be
signed with a Developer ID and notarized, or they have to remove the quarantine attribute
(`xattr -dr com.apple.quarantine "EIII Rack.vst3"`).

---

## 2. Put your files in place

The simplest way is the default folders, which the plugin finds without any configuration:

    ~/Library/Application Support/EIII/
    ├── roms/      the two boot ROM files
    ├── hd/        your OS 2.42 hard disk image (if there are several, the first in alphabetical order is used)
    └── cd/        CD-ROM images (the first .iso is put in the CD drive; the drive menu lists all of them)

    mkdir -p ~/Library/Application\ Support/EIII/{roms,hd,cd}

If you already keep your files somewhere else, point the plugin at them with `eiii.conf` (section 3) or from the
plugin's menu bar (section 4). Nothing has to be copied.

### Boot ROMs

Two files. The plugin accepts either naming scheme, in any letter case:

| Half | MAME name | Common alternative | Size | CRC32 | SHA-1 |
|---|---|---|---|---|---|
| low byte (IC3, IP381A) | `e3-lsboot_ip381a_emu_systems_4088.ic3` | `EIII_IP381A_L.Bin` | 16384 bytes | `34e5283f` | `902c2a9a2b37b34331fb57d45b88ffabc1f12a53` |
| high byte (IC4, IP380A) | `e3-msboot_ip380a_emu_systems_4088.ic4` | `EIII_IP380A_R.Bin` | 16384 bytes | `1302c054` | `28b7e8991e72cc111ee0067c58bddafca70f3824` |

The checksums are the ones MAME lists for these chips. To check your files:

    shasum ~/Library/Application\ Support/EIII/roms/*

If the two halves are swapped (L/R mixed up), the unit won't boot: the display stays blank or shows garbage.

### OS 2.42 hard disk image

- A **raw image** of an EIII SCSI hard disk with OS 2.42 on it: every 512-byte sector in order, with no header. The size
  must be a multiple of 512 bytes. Common sizes are 96 MB, 239 MB, 464 MB and 953 MB. The file extension doesn't matter
  (`.img`, `.hd`, `.raw`; images that circulate as `.ISO` are raw disk images too).
- From a real EIII disk (on a SCSI or USB adapter): find it with `diskutil list`, then
  `sudo dd if=/dev/rdiskN of=eiii-os242.img bs=1m`. Make sure `diskN` is the right device, and don't let macOS
  initialise the disk when it asks.
- The image is opened **read-only and never modified**. What the OS writes (Save Bank, ...) is kept separately and
  saved with your DAW project. Each hard disk menu can also write the disk with those changes to a new image file.
- The OS must be on the image: the EIII loads its operating system from the hard disk at power-on. Floppy disks aren't
  emulated, so an OS on floppies can't be used.

### CD-ROM images

- **MODE1/2048 `.iso` files only**: 2048-byte sectors, size a multiple of 2048. BIN/CUE or other raw CD images
  (2352-byte sectors) are refused. Convert them to ISO first, for example with `bchunk` (`brew install bchunk`).
- **EIII sound library** discs work: the original E-mu EIII.xx series, and third-party EIII discs in the same format.
- Discs for the **EIIIX** ("EMULATOR 3X" banks, usually marked "X" in the bank list) and **ESI-32** discs mount, and
  the OS lists their banks, but loading them gives **"Not Enough Memory!"**. That is the original OS 2.42 refusing a
  format it doesn't support, not a fault of the emulator.

---

## 3. eiii.conf (optional)

`~/Library/Application Support/EIII/eiii.conf` sets the media a **new** plugin instance starts with. Environment variables (`EIII_ROM_DIR`,
`EIII_HD`, `EIII_CD`) override it, and it overrides the default folders. A complete example
([docs/eiii.conf.example](docs/eiii.conf.example)):

    # boot ROM folder (the two files, INSTALL.md section 2)
    rom_dir = /Users/me/EIII/roms
    # OS 2.42 hard disk image: SCSI ID 1, drive D1
    hd      = /Users/me/EIII/hd/EIII_OS242_96MB.img
    # CD-ROM image in the unit's CD drive: SCSI ID 3, drive D3 (leave empty for no disc)
    cd      = /Users/me/EIII/cd/EIII.01 Emulator Standards.iso
    # optional extra drives D4..D7: cd:PATH (CD drive with a disc), cd: (empty CD drive), hd:PATH (hard disk), none
    scsi4   = cd:/Users/me/EIII/cd/EIII.02 More Emulator Standards.iso
    # scsi5 = hd:/Users/me/EIII/hd/samples.img
    # analog voice model: v1 (default, MAME-matched) or v2 (CEM3387 circuit model)
    cem_model = v1
    # optional: after power-on, press Load Bank, Enter, <drive>, Enter, <bank>, Enter, <preset> on the panel
    # autoload_bank   = 44
    # autoload_drive  = 3
    # autoload_preset = 1

You don't have to write this file by hand. Set the drives up in the plugin, then choose
**Settings → Use these drives as defaults for new instances**.

---

## 4. First start

1. Add **EIII Rack** to an instrument track in your DAW and open its window.
2. The unit powers on and the original OS boots from D1. After about 5 seconds the display shows `P00 Untitled Preset`
   and `S00 Empty Song`.
3. The **menu bar** above the panel shows the drives:
   - **D1**: the OS hard disk.
   - **D3**: the CD-ROM. Insert, change or eject discs here; a disc change is immediate.
   - **D4–D7**: optional extra CD drives or hard disks. Adding one restarts the unit.
   - **Settings**: power, restart, analog model, display theme, boot ROM folder, and save as defaults.
   - Clicking the floppy drive on the panel also opens the D3 menu.
4. Load a bank exactly as on the real unit: **Load Bank** → **Enter** → **3** (the CD drive) → **Enter** → type the
   bank number (for example **4 4**) → **Enter**. Then choose a preset with the keypad.
5. Play: MIDI goes to the EIII's MIDI IN. **The factory banks receive on MIDI channel 14** (a setting stored in each
   bank), so set your track or keyboard to channel 14.

Your drive setup, the hard disk changes (saved banks), the analog model and the display settings are stored in the
DAW project.

### Sampling

The plugin has a stereo **Sample In** audio input. Route audio into it; how depends on your DAW. Then on the panel:
**SAMPLE** → **7** (Arm Sampling) → play the sound → **Enter** to stop. **6** (Place Sample) → **Enter** ×5 maps the
take onto keys around G2. The **Sample Input** slider sets the level; the OS shows "Sample Overload!" when a take
clips. **Save Bank** → **Enter** saves the bank to D1, and the saved bank is kept with the project.

---

## 5. Troubleshooting

| What you see | Cause and fix |
|---|---|
| The display shows a message instead of booting, like `boot ROM ... not found in ...` or `no boot ROM folder set` (also shown in the menu bar) | The ROMs aren't where the plugin looks. Put them in `~/Library/Application Support/EIII/roms` or set **Settings → Boot ROM folder…**. Check the names and sizes (section 2). |
| `no OS hard disk image set (D1)` or `cannot open hard disk image ...` | Choose the image in the **D1** menu, or put it in `~/Library/Application Support/EIII/hd`. |
| Blank display or garbage, no boot | The ROM halves are swapped or a dump is bad: compare the SHA-1 values in section 2. |
| Load Bank → D3 shows **"Invalid Drive"** | There's no CD drive at that ID. D3 always exists; D2 is never valid in OS 2.42. |
| Load Bank → D3 waits, then **"SCSI Hardware Error!"** | The CD drive is empty. Insert a disc from the D3 menu, press **Enter**, and choose the drive again. |
| **"No Banks On Drive!"** | The disk has no banks: an OS-only hard disk, or a non-EIII disc. |
| **"Not Enough Memory!"** when loading | An EIIIX / ESI-32 bank, or a bank bigger than the EIII's 8 MB sample memory (section 2, CD-ROM images). |
| A CD image is refused | It isn't a MODE1/2048 ISO (section 2). |
| No sound | Factory banks play on **MIDI channel 14**. Check that a bank is loaded, Master Volume is up, and power is on (Settings → Power). |
| The plugin doesn't appear in the DAW | Rescan plugins. For the AU, run `auval -v aumu E3rk Eiii`; for a copied (not locally built) plugin, remove the quarantine attribute (section 1). |

Messages from the plugin are also logged as `EIII Rack: ...`; see them in Console.app, or in the terminal when the DAW
is started from one.

