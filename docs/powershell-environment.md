# PowerShell environment: 5.1 → 7 and the VS Code console

Applies to the **local** bake orchestration host only (see the local-vs-remote model in
[../CLAUDE.md](../CLAUDE.md)). Remote blocks run on the target VM's own PowerShell and are
unaffected.

## Az modules fail in the VS Code PowerShell Integrated Console (WinPS 5.1 only)

**Status: resolved on the current bake host** — it runs **PowerShell 7.6.4 (Core)**, which isolates
assemblies per load context, so Az scripts run fine in the VS Code Integrated Console and under F5.
Everything below applies **only** to a host still on Windows PowerShell 5.1.

Running Az-module scripts (e.g. `scripts/AzureLogin.ps1`, `scripts/test.ps1`) in the VS Code
**PowerShell Integrated Console** (host name `Visual Studio Code Host`) under **Windows PowerShell
5.1** throws:

```
TypeLoadException: Method 'get_SerializationSettings' in type '...ResourceManagementClient'
does not have an implementation
```

**Root cause** — not module version skew on disk. WinPS 5.1 has a single assembly load context, and
PowerShell Editor Services (the engine behind the Integrated Console) preloads its own
`Newtonsoft.Json` (13.0.3, from the `ms-vscode.powershell` extension's
`PowerShellEditorServices\bin\Common\`) before Az loads. Az's client DLLs then bind against the
wrong shared copy → signature mismatch. A plain `powershell.exe` (host `ConsoleHost`) never loads
PSES's copies, so Az works there. Because the VS Code debugger (F5/breakpoints) *is* PSES, on 5.1
you cannot have both the graphical debugger and working Az.

**If you are on 5.1:**
- The fix is to use **PowerShell 7** as the extension's default — pwsh 7 isolates assemblies per load
  context so Az and PSES no longer collide. (This is what the current host does.)
- Otherwise, run Az scripts in a plain Windows PowerShell terminal (the `+` terminal, profile
  "Windows PowerShell"), not the Integrated Console / F5. This is a convention, not enforced —
  `AzureLogin.ps1` is just a service-principal login switch and has no host guard.
- Quick diagnosis: `$Host.Name`, and
  `([AppDomain]::CurrentDomain.GetAssemblies() | ? { $_.GetName().Name -like 'Microsoft.Azure*' }).Count`
  — non-zero at startup in the Integrated Console, zero in a plain terminal.

## 5.1 → 7 migration of the baking scripts

Audit target: `bake-ide-ami.ps1` (`bake-IdeMsi`) and its locally dot-sourced helpers
(`Init-Baking-*`, `dot-*`).

**Required Az sub-modules on the pwsh-7 bake machine:** `Az.Accounts`, `Az.Compute`, `Az.Network`,
`Az.Resources`, `Az.Storage`, `Az.KeyVault`. (`Az.KeyVault` is only used for the WinRM-cert secret
in `bake-ide-ami.ps1` but is easy to miss → `Get-AzKeyVaultSecret not recognized`.) Installing the
full `Az` meta-module avoids gaps. No other Az module is referenced in the local graph.

**Fixed:**
- `bake-ide-ami.ps1` `Get-Content -Encoding Byte` → `[System.IO.File]::ReadAllBytes((Convert-Path $fileName))`.
- `Remove-AzrVirtualMachine.ps1` `Login-AzAccount` → `Connect-AzAccount` (+ `Import-Module Az.Accounts` in the Start-Job init).
- `bake-ide-ami.ps1` `Get-AzureStorageKey` → `Get-AzStorageAccountKey`, resource group discovered at
  runtime via `Get-AzStorageAccount | Where StorageAccountName -eq` (throws if not found in the
  current subscription — note `lansalpcmsdn` may live in a different subscription than LPC's).
- Removed dead classic `Select-AzureSubscription` / `Set-AzureSubscription`.
- Pinned `-Encoding ascii` on all `LansaSettings.txt` writes in `dot-CommonTools.ps1` and the temp
  `.ps1` writes in `dot-Send-RemotingFile.ps1` (`ascii` is valid on both 5.1 and 7; these helpers
  can build files that matter on a remote 5.1 VM).
- **AzCopy v8 → v10** for the Azure DVD-upload path in `bake-ide-ami.ps1` (`Copy-DvdImage` helper):
  `cmd /c AzCopy /Source /Dest /DestKey` → `azcopy copy` with a short-lived account SAS (4h,
  HttpsOnly, `racwl`, Blob Container+Object) minted via `New-AzStorageContext` /
  `New-AzStorageAccountSASToken`. Flag mapping: `/S`→`--recursive=true`, `/XO`→
  `--overwrite=ifSourceNewer`, `/Y`→default. Added `$LASTEXITCODE` throw + azcopy-present guard.
  **The bake machine needs AzCopy v10 (`azcopy`) on PATH**, not the v8 `AzCopy.exe`.

**Parked (not yet done):**
- **AWS path only** (does not affect Azure/LPC bakes): the legacy monolithic `AWSPowerShell` module
  won't load in PS7. Affects all `Get-EC2*`/`New-EC2*`/`Remove-EC2*`/security-group/`*-SSMCommand`
  calls in `dot-AWSTools.ps1`, `dot-Create-EC2Instance.ps1`, `dot-Wait-EC2State.ps1`,
  `dot-CommonTools.ps1` (`Run-SSMCommand`) and the AWS branches of `bake-ide-ami.ps1`. Dot-sourcing
  is fine (function definitions); it only breaks when an AWS function is *called*. Fix = install
  modular `AWS.Tools.EC2/.SimpleSystemsManagement/.SecurityToken/.Common` (+`.S3`); cmdlet names and
  `Amazon.EC2.Model.*` types are identical. The CI `AWSPowerShellModuleScript@1` task also needs
  updating for a pwsh-7 agent.

**Verified non-issues (don't re-investigate):**
- pwsh 7.6.x defaults to **STA** on Windows, so `MessageBox` / `WScript.Shell.Popup` / WinForms
  dialogs behave as on 5.1 in a plain terminal. (MTA risk only if a bake runs inside the VS Code
  Integrated Console — don't.)
- Remote-only concerns, out of scope unless the baked image itself moves to PS7: SMO/WMI in
  `dot-DBTools.ps1`, `X509Certificate2.PrivateKey.CspKeyContainerInfo` in
  `dot-map-licensetouser.ps1` / `dot-createlicense.ps1`, `LoadWithPartialName`, the bundled
  `NTFSSecurity` module, remote `Get-SSMParameter`.
