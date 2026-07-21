# Marketplace security scan: TLS / Schannel hardening

Azure Marketplace VM image submissions run a security scan (AzCertify / Qualys). LANSA image
submissions have failed **200.5.8 Security scanning** with:

- **QID 38628** — server supports **TLS 1.0** (CVSSv3 6.2, an automatic PCI FAIL)
- **QID 38794** — server supports **TLS 1.1**

reported on **port 3389**. `Patchable: False` — these are **configuration** findings, not missing
hotfixes; no amount of Windows Update clears them.

## Root cause is base-OS Schannel defaults, not RDP

Port 3389 is where the scanner happened to catch **Schannel** offering the deprecated protocols; the
fix is machine-wide Schannel configuration, not an RDP setting. The finding depends on the base
image's OS defaults:

| Base OS | TLS 1.0 / 1.1 default | Scan result |
| - | - | - |
| Windows Server 2019 | **enabled** | **fails** — needs hardening |
| Windows Server 2022 Datacenter **Azure Edition** | disabled (hardened Schannel) | passes |
| Windows Server 2025 | disabled by default | passes |

So only Win2019 needs the change, but the hardening is applied **unconditionally** — it fixes
Win2019 and is an idempotent no-op on Win2022/2025.

Note: Win2019's Schannel supports **TLS 1.2** but **not TLS 1.3** (TLS 1.3 in Schannel arrived with
Server 2022). So the fix disables 1.0/1.1 and ensures **1.2**; there is no 1.3 to enable on 2019.

## The fix

Baked into [../scripts/install-lansa-base.ps1](../scripts/install-lansa-base.ps1), next to the
existing outbound-TLS line. **Two distinct things live there — don't confuse them:**

- `[Net.ServicePointManager]::SecurityProtocol = …` only controls **this PowerShell process's own
  outbound web requests** (the downloads in that script). It is process-scoped and does nothing for
  what the baked image *offers* to an inbound scanner. (A pre-existing bug there used the `-f`
  string-format operator instead of `-bor` to combine the flags; fixed.)
- The **Schannel registry** changes are what the scan cares about — machine-wide, persisted into the
  image:
  - **Protocols:** under `HKLM\…\SCHANNEL\Protocols`, disable `TLS 1.0` and `TLS 1.1` (Server +
    Client, `Enabled=0` / `DisabledByDefault=1`) and enable `TLS 1.2`.
  - **Ciphers:** disable RC4 (all four variants), `DES 56/56`, `Triple DES 168` (SWEET32), `NULL`,
    and the `MD5` hash; set Diffie-Hellman `ServerMinKeyBitLength = 2048` (Logjam / weak-DH). The
    cipher key names contain `/`, which the PowerShell registry provider mishandles, so these use
    the **.NET registry API** (`[Microsoft.Win32.Registry]::LocalMachine.CreateSubKey(...)`).

## Caveats

- **Reboot required.** Schannel reads these keys at boot, so the change only takes effect after the
  image reboots. In the bake flow that is fine (the scanned Marketplace VM boots fresh from the
  captured image); to verify on the baking box itself, reboot it first.
- **Cipher-suite ordering was deliberately not forced.** This clears the protocol + weak-algorithm
  findings. If a scan later asks for a specific suite order (ECDHE-AES-GCM led first), add it via the
  SSL cipher-suite-order policy key or `Disable-TlsCipherSuite` — but note a malformed suite-order
  list in a baked image disables everything not on it, so it is higher-risk than the targeted
  algorithm disables used here.

## Other Marketplace certification findings (same script)

Marketplace submission also runs feature/OS **certification** tests (aka.ms/Windows-testcases),
separate from the security scan above but fixed in the same place ([install-lansa-base.ps1]).

### Wireless LAN Service not supported by Azure

Win2025 plans (e.g. `[w25d-16-0, 16.0.22]`) failed with *"Wireless LAN Service feature is not
supported by Azure."* The **Wireless LAN Service** feature (`Wireless-Networking`) is on Azure's
unsupported list, and the WS2025 base image ships with it **installed** (WS2019/2022 don't — which is
why only the w25 plans failed). The fix is to **uninstall the feature** in the bake
(`Uninstall-WindowsFeature -Name Wireless-Networking`), guarded to run only when it's present so it's
a no-op on the other OS versions. The test checks the **feature**, so merely disabling the `Wlansvc`
service is not enough. Servers in Azure never use wireless, so removal is safe.
