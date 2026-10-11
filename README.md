# Emulated-3

> **This fork is the macOS / Apple silicon version: plugins only, VST3 and Audio Unit (`.component`).**
> No standalone app, no CLAP and no Linux build. The emulator itself is
> [parguinsys/Emulated-3](https://github.com/parguinsys/Emulated-3) by its original author, unchanged in behaviour;
> this fork ports the plugin to macOS (native Cocoa GUI, macOS file dialogs) and wraps it as VST3 + AU with
> [clap-wrapper](https://github.com/free-audio/clap-wrapper). The binaries are universal (Apple silicon native, Intel
> also works). Download them from [Releases](https://github.com/ekwipt/Emulated-3/releases) or build them
> ([INSTALL.md](INSTALL.md)).

**Beta.** Expect rough edges, and please report what you find.

An unofficial emulator of the **E-mu Emulator III** sampler, as a **VST3 and Audio Unit instrument plugin for
macOS**. It runs the original EIII boot ROM and **Operating System 2.42** unmodified, from your own disk images.
You operate it from the original rack front panel (the panel is the instrument), MIDI goes to the emulated MIDI IN, and
the voice outputs are rendered through a model of the EIII's F-Chip and CEM3387 filter/VCA hardware.

![The EIII rack front panel in the plugin, with the drive menu bar](docs/screenshots/rack-panel.png)

> **No E-mu material is included.** This repository has no boot ROMs, no operating system, and no sample or bank data.
> To use it you need your own EIII boot ROM dumps, an OS 2.42 hard disk image and, optionally, EIII CD-ROM images.
>
> **Build and install it as described in [INSTALL.md](INSTALL.md)**, which also covers where the ROMs, the OS disk
> and CDs go, the first start, and troubleshooting.

## Features

- **The original OS, unmodified.** Boot, Load Bank, the sequencer and the modules all run the EIII's own code. The CPU,
  SCSI, MIDI and front-panel hardware are checked against MAME's behaviour by a regression suite (`make check`).
- **Front panel GUI.** Vector artwork at any size. Mouse-down/up on a button is the switch's make/break, and the sliders
  drive the ADC inputs. The 4 × 20 LCD and the 17 LEDs show the machine's own state.
- **Drives in a menu bar** (plugin):
  - **D1** OS hard disk, **D3** CD-ROM, plus extra CD-ROM drives or hard disks at **D4–D7**.
  - Insert, change or eject a CD while the unit runs: a hot swap the OS sees as a real disc change.
  - A one-click list of the other `.iso` files next to the discs in use.
  - Clicking the floppy drive opens the D3 menu; its eject button ejects the CD.
- **Sampling.** The plugin's stereo **Sample In** port is the EIII's line input. In the SAMPLE module, 7 (Arm Sampling)
  waits for the threshold, Enter stops, and 6 (Place Sample) maps the take onto keys. All of this runs the original
  sampling code at 44 053 / 33 333 Hz. The panel's Sample Input slider sets the level.
- **Saved banks stay with the project.** Disk images are never written. What the OS saves (Save Bank, ...) is kept as
  a change set inside the project, and can be written into a new image file or discarded.
- **Projects reopen with their setup.** The drives, the hard disk changes, the analog model and the display settings
  are saved in the DAW project.
- **Display themes.** Click the Contrast knob to cycle Stock STN, Blue/White, Amber/Red, VFD and OLED. Turning the knob
  sets each theme's level.

  | Amber/Red | VFD | OLED |
  |---|---|---|
  | ![Amber](docs/screenshots/display-amber.png) | ![VFD](docs/screenshots/display-vfd.png) | ![OLED](docs/screenshots/display-oled.png) |

- **Two analog models.** **V1** is MAME-matched; **V2** is a CEM3387 circuit model refined from the datasheet with the
  EIII's component values. Choose in Settings.
- **Several instances per project**, each with its own machine and thread. The audio thread never blocks or allocates.

![A drive menu](docs/screenshots/drive-menu.png)

## Status and platforms

| | |
|---|---|
| macOS 11+ (Apple silicon and Intel, universal binary) | VST3 and Audio Unit (AUv2) instrument, Cocoa GUI |
| Sampling into the instrument | working (beta): Sample In port → the EIII's own sampling code; saved banks kept with the project |

Validation: `auval -v aumu E3rk Eiii` passes (arm64 and x86_64), and the VST3 SDK validator passes all 47 tests.

The plugin is written against the CLAP API (`plugin/eiii_clap.cpp`) and turned into the VST3 and the AU by
[clap-wrapper](https://github.com/free-audio/clap-wrapper). No CLAP or standalone build is produced.

## Build

Xcode or the Command Line Tools, and CMake (`brew install cmake ninja`):

    cmake -B build -G Ninja -DCMAKE_BUILD_TYPE=Release
    cmake --build build
    # -> build/EIII-Rack_assets/VST3/EIII Rack.vst3
    #    build/EIII-Rack_assets/AUv2/EIII Rack.component

Add `-DEIII_INSTALL_AFTER_BUILD=ON` to copy both to `~/Library/Audio/Plug-Ins` after every build. The MAME device
sources the emulator uses (CPU, FPU, SCSI, serial) and Berkeley SoftFloat are vendored in `machine/third_party/mame`;
the MAME executable is not needed. CMake downloads the CLAP SDK, clap-wrapper, the VST3 SDK and the AudioUnitSDK at
pinned versions on the first configure.

## Media setup

See **[INSTALL.md](INSTALL.md)**: ROM file names and checksums, the OS 2.42 disk image, CD formats, the default
folders (`~/Library/Application Support/EIII/{roms,hd,cd}`), `eiii.conf` ([example](docs/eiii.conf.example)), the
first start, and troubleshooting.

The factory banks receive MIDI on **channel 14** (a setting stored in each bank).

## Repository layout

| Path | What |
|---|---|
| `runtime/` | one emulated EIII (`eiii::runtime`) and its engine thread for hosts with audio/GUI threads (`eiii::engine`) |
| `plugin/` | the plugin (CLAP API; wrapped as VST3 + AU by clap-wrapper, see `CMakeLists.txt`) |
| `machine/` | the EIII motherboard glue, MAME-derived device shim, vendored MAME subset |
| `fchip/`, `cem/`, `host/` | the EIII voice output hardware: F-Chip, CEM3387 models, analog backend |
| `panel/`, `ui/` | front-panel model, the software-rendered GUI, its Cocoa view and the macOS file dialogs |

## Legal

Emulated-3 is an independent project. It is **not affiliated with, endorsed by, or connected to E-mu Systems or
Creative Technology**. "E-mu", "Emulator" and "Emulator III" are trademarks of their respective owners and are used
here only to describe what this software emulates.

Emulated-3's own code is licensed under the **GNU General Public License v3.0** (see [LICENSE](LICENSE)).

Third-party code in this repository, each under its own licence:

| Component | Licence |
|---|---|
| MAME device sources (`machine/third_party/mame/src`) | BSD-3-Clause, see [PROVENANCE.md](machine/third_party/mame/PROVENANCE.md) |
| Berkeley SoftFloat 3e (`machine/third_party/mame/3rdparty/softfloat3`) | BSD-style, see its `COPYING.txt` |
| CLAP SDK, clap-wrapper, VST3 SDK (downloaded at build time) | MIT |
| AudioUnitSDK (downloaded at build time) | Apache-2.0 |
| stb_truetype / stb_image_write (`third_party/stb`) | public domain / MIT |
| Archivo Narrow, Noto Sans fonts (`third_party/fonts`) | SIL Open Font License 1.1. The fonts are compiled into the GUI and plugin, so their licence files must accompany binaries |

The LCD character set is an original drawing made for this project; no character ROM is included.

## Support

If Emulated-3 is useful to you, you can support its development:
**[Donate via PayPal](https://www.paypal.com/donate/?hosted_button_id=YGFGAJH5JSUV8)**
