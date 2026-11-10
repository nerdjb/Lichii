<!--
# SPDX-FileCopyrightText: Copyright 2025 Eden Emulator Project
# SPDX-License-Identifier: GPL-3.0-or-later

# SPDX-FileCopyrightText: 2018 yuzu Emulator Project
# SPDX-License-Identifier: GPL-2.0-or-later
-->

<h2 align="center">⚠️ Lichii has no official website ⚠️</h2>

> [!CAUTION]
> **Lichii has no official website.** The only site run by this project is the **game compatibility website, [lichii.zortos.me](https://lichii.zortos.me)**, for compatibility reports only. Download Lichii **only** from this repository's [releases page](https://github.com/zortos293/Lichii/releases). Any other "Lichii" website or download (such as lichii.org) is not ours and may contain malware ([#545](https://github.com/zortos293/Lichii/issues/545)).

<p align="center">
  <img src="dist/branding/lichii_icon_with_logo.png" alt="Lichii" width="600">
</p>

# Lichii

Lichii is an experimental, open-source Nintendo Switch and Switch 2 emulator written in C++. It builds on Eglantine, Eden, yuzu and Sudachi, preserving their contributions while developing this fork's game compatibility and renderer fixes.

This is an independent fork, not an official release of those upstream projects. Lichii is not affiliated with Nintendo.

Visit the [Lichii game compatibility website](https://lichii.zortos.me) to find games and compare community compatibility reports.

## This fork: AMD frame generation

This is a fork of [zortos293/Lichii](https://github.com/zortos293/Lichii) that carries the
frame-generation work from [chuppatricky/Lichii](https://github.com/chuppatricky/Lichii) on top of
current upstream `nx2`:

- **Large-motion frame generation.** The built-in FSR3-style generator now builds a brightness
  pyramid, searches and refines the motion field, and takes a median, so fast camera movement no
  longer produces a double image.
- **Paced generated frames.** Generated frames are spaced across the game frame's measured time
  instead of being shown in a burst.
- **Useful logs.** Frame generation now logs once whether it is running (and how many frames per
  game frame), or why it is off (missing `Lossless.dll`, or a display format the GPU cannot write
  from compute shaders).

The branch is [nerdjb/Lichii `nx2-amd-framegen`](https://github.com/nerdjb/Lichii/tree/nx2-amd-framegen).
It tracks upstream `nx2`: `tools/update-fork.sh --release` merges new upstream commits, pushes the
result, and publishes a fresh PGO build as the next `build-N` release, at most once per day. A
systemd user timer runs it daily on the machine that owns the fork, because GitHub disables Actions
here. Downloads are on the [releases page](https://github.com/nerdjb/Lichii/releases), and the
built-in updater follows them so it will not replace this build with an upstream one.

## Downloads and setup

Download the AMD frame-generation builds from [this fork's releases page](https://github.com/nerdjb/Lichii/releases). Upstream builds are on [zortos293/Lichii releases](https://github.com/zortos293/Lichii/releases) and do not include frame generation. Lichii has no other download site: archives offered elsewhere, such as lichii.org, are not built by this project, and one has been reported to install malware ([#545](https://github.com/zortos293/Lichii/issues/545)).

On Windows, extract the entire build archive and run **lichii.exe**. Only use games and system files you have legally obtained. Games, keys and firmware are not included.

### Existing saves and settings

Lichii uses its own profile: `%APPDATA%\lichii` on Windows, and the `lichii` directories under `$XDG_DATA_HOME`, `$XDG_CONFIG_HOME` and `$XDG_CACHE_HOME` on Linux and macOS. Without XDG overrides, these are `~/.local/share/lichii`, `~/.config/lichii` and `~/.cache/lichii`. An existing portable `user/` directory still takes priority and is not imported or changed by the wizard.

On the first non-portable GUI launch, Lichii offers to import Eden and other detected emulator profiles. Back up `%APPDATA%\eden` first on Windows, or the old data, config and cache directories on Unix, and close the source emulator. Choose **Keep Old Data** to copy without changing the source, then check your saves and relaunch. Existing destination data is retained in backup directories rather than merged. Move also retains a source backup until you remove it yourself; Link deliberately shares settings and saves. Paths outside the imported data root remain shared and unchanged. An interrupted import offers recovery on the next launch. `eden-cli`, including `--help` and `--version`, refuses to initialize configuration until you import or explicitly choose **Start fresh** in the GUI.

## Compatibility and issue reports

Compatibility and performance vary by game, hardware and driver. Rendering errors, stutters and crashes remain possible. Passing automated tests does not establish that a game renders correctly, and this project makes no universal frame-rate guarantee.

Browse [community compatibility reports](https://lichii.zortos.me/reports) for results with each player's build and setup.

Desktop reporting requires a build containing [PR #303](https://github.com/zortos293/Lichii/pull/303) and is not available in build 88. In builds that include it, play and stop a Switch 2 game, then right-click that game and choose **Submit compatibility report**. Only the latest session in the current Lichii process is eligible.

Confirm the matching website catalog entry and review the editable machine, game, setup, and enabled add-on details prefilled where available. Check the public preview and give explicit consent before submitting. Nothing uploads automatically, and the native v1 reporter does not read or upload logs or files.

When [reporting an issue](https://github.com/zortos293/Eglantine/issues), include:

- The exact build, game version, CPU, GPU and driver version.
- Relevant settings and steps to reproduce the problem.
- A screenshot and the log from the affected session, after checking it for personal information.

Do not upload game files, keys, firmware or private account information.

## Building and contributing

See the [build guide](docs/Build.md), [user documentation](docs/user/README.md) and [coding guidelines](docs/Coding.md). Some inherited documentation and internal build target names still use upstream names. The GUI build target remains `yuzu`; its output is `lichii.exe` on Windows and `lichii` on other desktop platforms.

Keep changes focused and distinguish code-level checks from actual gameplay testing.

## Artwork
Art created by YOB (yobslab)
The supplied Lichii logo, icon and library artwork are in [dist/branding](dist/branding). Windows, Linux and macOS icon resources are generated from that artwork by [Generate-LichiiIcons.ps1](tools/Generate-LichiiIcons.ps1).

## Credits and license

Lichii inherits the work of the Eglantine, Eden, yuzu and Sudachi projects and their contributors, including Eglantine's original developer Camille LaVey. Original copyright notices and third-party licenses are retained.

See [LICENSE.txt](LICENSE.txt) and the source files for applicable license terms.
