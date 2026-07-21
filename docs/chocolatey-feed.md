# Private Chocolatey feed & package internalizing

The bake curates a private Chocolatey feed (Azure DevOps Artifacts, named **`lansa`**) of vetted
package versions. `publish-lansa-packages.ps1` (supersedes the older `choco-push.ps1`) publishes the
vetted set: FoxitReader, git, vscode, jre8, GoogleChrome, DotNet4.5.2, kdiff3,
chocolatey-core.extension, etc.

## Design intent: LANSA artefacts fully independent

Relying on Chocolatey's community feed for bake installs caused four long-standing problems:

1. The community feed can **throttle or reject** installs.
2. A **latest version may have a bug**.
3. A **version-pinned older release becomes unavailable upstream** over time (community feeds delist
   old versions).
4. LANSA's artefacts **depend on external servers**, which eventually go offline or rotate their URLs.

**Internalising** the vetted set onto LANSA's own `lansa` feed — the installer binary embedded in the
`.nupkg`, no vendor CDN touched at install time — resolves **1, 3, and 4** outright: installs come
from LANSA's feed, each package is self-contained, and any version LANSA has published stays
installable for as long as LANSA keeps it. This is *enforced* by `Install-ChocoCheckedLansa` (below),
which throws if any install came from a non-`lansa` source or pulled a binary from a URL.

**Policy: publish and install the LATEST version.** Staying current matters more than freezing a
version. Because the artefacts are independently hosted, a version *can* be pinned whenever needed
and it will remain installable indefinitely — so pinning is available as a tool but is used only
**reactively, when forced**: problem 2 (a specific latest version has a bug) is handled by dropping
back to a known-good older version until it's fixed, and no longer. Pinning is not pre-emptive and is
not a goal.

## Root-cause gotcha: installs drift to the public community feed

`getchoco.ps1` runs `choco source add -n=lansa -s=<AzDO v2 nuget url>` but **does not disable the
default public `chocolatey` community source**. Most bake `choco install` calls (e.g. in
`install-lansa-base.ps1`) pass neither `--source` nor `--version`, so choco searches **both** feeds
and installs the **highest version found** — pulling unvetted community versions over the vetted
`lansa` ones.

**Concrete failure:** `choco install FoxitReader -y` resolved to a *newer* community version whose
installer downloads from a **dead Foxit CDN URL** (TCP 443 connects but HTTPS times out). Choco's
download timeout is 2,700,000 ms (45 min), so a dead URL **hangs** rather than failing fast — no
installer process ever starts. The stop-gap was a `--version … --source lansa` pin; the current
approach (below) instead installs the **internalised** package from the `lansa` feed with an
enforced source guard and no version pin.

**Decision:** keep the public `chocolatey` source **enabled** as a fallback (do **not** disable it
in `getchoco.ps1`), and instead **internalize** the whole vetted set at latest versions so installs
resolve to the private feed. The `lansa` feed allows anonymous read, so bake VMs install without a
PAT. Pinning fixes *which* package installs but not *where its binary downloads from* — bulletproof
means embedding the installer in the nupkg (internalizing), not just pinning.

## Enforcement: `Install-ChocoCheckedLansa` (in `dot-CommonTools.ps1`)

Because the public `chocolatey` source stays enabled, the bake doesn't rely on a plain
`choco install` doing the right thing — it goes through the `Install-ChocoCheckedLansa` wrapper
(used for FoxitReader, googlechrome, jre8, vscode, git, jdk8, …). The caller must pass `-s=lansa`
(or `--source lansa`). The wrapper clears the choco log so it holds only this install, echoes the
whole log, then **throws** if either guard fails:
1. **Source guard** — any package/dependency not obtained from the private `lansa` source (matched
   against the feed URL containing `lansa`).
2. **Internalisation guard** — any installer binary downloaded from a URL (i.e. the feed package was
   not internalised).

Bakes run headless and emit many warnings, so a wrong source is made a **hard error**, not a warning
that scrolls past. This is why FoxitReader is installed as
`Install-ChocoCheckedLansa @('FoxitReader','-y','--no-progress','--source','lansa')` with **no
version pin** — the vetted, internalised version lives on the feed. (Note the capitalised package id
`FoxitReader`; lowercase `foxitreader` is the old 10.x package.)

## `scripts/Internalize-ChocoPackage.ps1`

Open-source equivalent of `choco download --internalize`: downloads a community package, embeds its
installer binary into `tools\`, rewrites the URL literals to the local path, repacks, and pushes to
the private feed. Notes:
- Re-hosts meta/extension packages (chocolatey-core.extension, git, vscode) unchanged when there's
  no binary to embed; pushes via `nuget push -Source Lansa` (not `choco push`).
- `-Version` optional (omit = resolve latest community version via `choco search --exact
  --limit-output`). Only handles **static URL literals**; dynamic-URL packages must be done by hand.
- **AzDO 500 MB limit / 64-bit only:** Azure Artifacts rejects packages > 500 MB (the original
  reason installers were CDN-hosted). LANSA supports 64-bit Windows only, so the script infers each
  URL's arch from its assigning key (`url64`/`url64bit`=64, `url32`/bare `url`=32) and **skips the
  32-bit installer when a 64-bit URL exists**. Validated: jre8 129→66 MB, FoxitReader ~690→~376 MB.
- **Uninstall-bug repair:** community packages can ship a `chocolateyUninstall.ps1` whose
  `silentArgs` is single-quoted but contains `$(...)` (e.g. an MSI log path). Single quotes don't
  expand `$()`, so msiexec gets a literal `$($env:TEMP)` → uninstall fails with exit 1622.
  `Repair-SilentArgsExpansion` converts such single-quoted silentArgs to double-quoted (preserving
  `` `" `` escapes) in both install and uninstall scripts. The bake never uninstalls, so this only
  matters for testing / baked-image users. Immediate unblock on an already-installed package: edit
  `C:\ProgramData\chocolatey\lib\<id>\tools\chocolateyUninstall.ps1` (single→double quotes) then
  `choco uninstall`.

## `scripts/publish-lansa-packages.ps1`

Loops the vetted set through `Internalize-ChocoPackage.ps1` (latest versions by default), reports
per-package failures in a summary (re-run with `-Only <ids>`), `-PackOnly` builds without pushing.

## Publishing setup

Publishing to AzDO from a dev PC needs `nuget.exe` + a PAT with **Packaging: Read & write**. The
`Lansa` nuget source is defined in `scripts/nuget.config` (v3 index, with `<clear/>`), so it is only
visible when nuget runs from `scripts\` or below (nuget config resolves upward, not into subfolders)
— or add it to the user config to use it anywhere. **PAT credentials must not go in
`scripts/nuget.config`** (it is committed); store them in the user config
(`nuget sources add -Name Lansa -Source <v3 url> -Username lansa -Password <PAT>`, DPAPI-encrypted).
AzDO ignores the `-ApiKey` value. Re-pushing an existing version requires a **permanent delete** in
AzDO (unlist is not enough).
