# Cookbooks — Claude working notes

PowerShell (and CloudFormation) cookbooks that **bake and publish LANSA VM images** to AWS
and Azure Marketplace, plus the CloudFormation stack that hosts a LANSA MSI. See [README.md](README.md)
for the human overview and the baking entrypoint table.

## Mental model: local orchestration vs. remote execution

The single most important distinction when editing baking scripts:

- **Local code** runs on the machine driving the bake (`bake-scalable-*.ps1` →
  `bake-ide-ami.ps1` / `bake-IdeMsi` + the dot-sourced `Init-Baking-*` / `dot-*` helpers).
- **Remote code** is anything pushed to the target VM via `Execute-RemoteScript`,
  `Invoke-Command -Session`, or `Execute-RemoteBlock`. It runs on **the VM's own PowerShell**.

Consequences: a PowerShell-version or module concern (e.g. the 5.1→7 migration) only affects the
**local** call graph — remote blocks are unaffected. Conversely, image-hardening changes (TLS,
ciphers, installed software) must be made in the code that runs **on the VM**
(e.g. [scripts/install-lansa-base.ps1](scripts/install-lansa-base.ps1)), because that is what gets
baked into the published image.

## PowerShell runtime

- The local bake host now runs **PowerShell 7** (7.6.4, Core). The move off Windows PowerShell 5.1
  is done for the local host; some remote/CI paths may still be 5.1 — see the doc.
- Because of pwsh 7, **Az scripts run fine in the VS Code Integrated Console / F5.** The old
  `get_SerializationSettings` `TypeLoadException` only affected Windows PowerShell 5.1.
- Full detail, the parked 5.1→7 items, and the required Az module set:
  [docs/powershell-environment.md](docs/powershell-environment.md).

## Knowledge base

Deep-dives on hard-won, non-obvious behaviour (read the relevant one before touching that area):

- [docs/powershell-environment.md](docs/powershell-environment.md) — 5.1 vs 7, the VS Code
  Integrated Console / Az conflict, and the pwsh-7 migration status.
- [docs/chocolatey-feed.md](docs/chocolatey-feed.md) — the private `lansa` Chocolatey feed, why
  bake installs drift to the public feed, and the package internalizer.
- [docs/azure-sql-login.md](docs/azure-sql-login.md) — Azure SQL rejects `DEFAULT_DATABASE` on
  `CREATE LOGIN`; how the LANSA MSI's DB setup fails on Azure and the fix.
- [docs/marketplace-ingestion-api.md](docs/marketplace-ingestion-api.md) — managing the VM offer
  plans via the Product Ingestion API, auth, and the hard-won configure/write rules.
- [docs/tls-schannel-hardening.md](docs/tls-schannel-hardening.md) — the Marketplace security-scan
  TLS/cipher findings and the Schannel hardening baked into `install-lansa-base.ps1`.

## Marketplace tooling scripts

The `scripts/*.ps1` files driving the Product Ingestion API (`Export-MarketplaceOffer.ps1`,
`Update-VmPlanTechConfig.ps1`, `Add-Gen2ImageToPlans.ps1`, `Compare-PlanPricing.ps1`,
`Set-PlanPricing.ps1`, etc.) currently live on the **`debug/paas`** branch and are uncommitted.
Most are **dry-run by default** and require an explicit `-Submit` to write.
