# IMAGE NAMING STANDARD — VL (LANSA)

## Purpose

Defines how VL (Visual LANSA) container images are:
- Named
- Versioned
- Tagged
- Published

Ensures:
- Deterministic deployments
- Clear product identity
- Explicit OS compatibility
- Consistent CI/CD behaviour

---

## TL;DR

### Repository
lansalpc/vlbase-<variant>

Examples:
- lansalpc/vlbase-servercore
- lansalpc/vlbase-nanoserver

---

### Tags

Each image is published with TWO tags:

Numeric (immutable, for systems):
<major>.<sp>.<image>-<ltsc>

Human-readable (floating, for convenience):
v<major><ga|spX>-<ltsc>

Example:
16.2.3-ltsc2025
v16sp2-ltsc2025

---

### Versioning

<major>.<servicepack>.<image>

- Major → VL version
- SP → Product release level
- Image → Rebuild iteration (OS updates, fixes)

Example:
16.2.0 → initial SP2 release  
16.2.3 → rebuilt with updates  

---

### Critical Rules

- Numeric tags are IMMUTABLE
- Label tags are FLOATING within a version line
- No `latest`, no `ltsc` tags
- Every build produces BOTH tags
- Tags MUST reference the same image

---

### ⚠️ Important

Label tags (e.g. v16sp2-ltsc2025):

- Move over time
- Include OS updates implicitly
- Are NOT reproducible

Use numeric tags for production:
lansalpc/vlbase-servercore:16.2.3-ltsc2025

---

### Base Image Behaviour

- Windows base images are pinned at BUILD TIME
- No automatic OS updates
- Rebuild required to pick up patches

---

## Scope

Applies to:
- All VL base images
- All OS variants (servercore, nanoserver)
- All LTSC versions

---

## See Below

Full specification follows.

Below is the **final consolidated documentation (v3.2)** plus a **production-ready example Dockerfile** aligned with everything we’ve defined.

---

# 🧱 LANSA Container Image Naming & Versioning Standard (v3.2)

## 1. Overview

LANSA publishes base container images for **VL (Visual LANSA)** designed for customer extension.

This standard provides:

* Deterministic deployments (no unintended upgrades)
* Clear separation of product vs container versioning
* Explicit Windows OS compatibility
* Dual tagging for human and machine use
* Alignment with container ecosystem best practices

---

## 2. Registry & Naming

### Registry (namespace)

```text
lansalpc
```

* Technical identifier used for all images

---

### Company

```text
LANSA
```

* Used in branding and OCI metadata

---

### Product

* Canonical (technical): **VL**
* Descriptive: **Visual LANSA**

---

## 3. Repository Structure

Repositories represent:

> **Product (VL) + OS variant**

---

### Standard repositories

```text
lansalpc/vlbase-servercore
lansalpc/vlbase-nanoserver
```

---

## 4. Versioning Model

A **3-part numeric version** is used:

```text
<major>.<servicepack>.<image>
```

---

### Meaning

| Component    | Meaning                     |
| ------------ | --------------------------- |
| Major        | VL version                  |
| Service Pack | Product release level       |
| Image        | Container rebuild iteration |

---

### Examples

```text
16.0.0   ← V16 GA
16.0.1   ← rebuild

16.2.0   ← V16 SP2
16.2.3   ← rebuilds
```

---

### Key Principle

> Product version is stable
> Image version increments on rebuild (e.g. OS updates)

---

## 5. Tag Structure

Each image is published with **two tags**:

---

### Numeric tag (immutable)

```text
<major>.<sp>.<image>-<ltsc>
```

Example:

```text
16.2.3-ltsc2025
```

---

### Label tag (floating)

```text
v<major><ga|spX>-<ltsc>
```

Example:

```text
v16sp2-ltsc2025
```

---

### Tag pairing

```text
16.2.3-ltsc2025
v16sp2-ltsc2025
```

Both tags refer to the same image at release time.

---

## 6. Tag Behaviour

| Tag Type | Behaviour                    |
| -------- | ---------------------------- |
| Numeric  | Immutable                    |
| Label    | Floating within release line |

---

## 7. Tag Restrictions

The following are **not used**:

```text
latest
ltsc
ltsc2025
```

---

## 8. Base Image Behaviour (Windows)

```dockerfile
ARG WINDOWS_VERSION=windowsservercore-ltsc2025
FROM mcr.microsoft.com/windows/servercore/iis:${WINDOWS_VERSION}
```

---

### Behaviour

* Base image tag resolves at **build time**
* Image is pinned to a **specific digest**
* Runtime does **not** re-resolve tags

---

### Implication

* No automatic OS updates
* Rebuild required to pick up patches

---

## 9. Dimensions

Each image is defined by:

* Product → VL
* OS Variant → servercore / nanoserver
* Product Version → 16.x
* Image Version → .x
* OS Version → ltsc2022 / ltsc2025

---

## 10. Immutability

* Numeric tags are immutable
* Label tags move within version line

---

## 11. OCI Labels

### Required

```dockerfile
LABEL org.opencontainers.image.title="VL Base Image"
LABEL org.opencontainers.image.description="VL (Visual LANSA) base container image for Windows"
LABEL org.opencontainers.image.vendor="LANSA"
LABEL org.opencontainers.image.version="16.2.3"
LABEL org.opencontainers.image.revision="<git-sha>"
LABEL org.opencontainers.image.created="<iso-8601-timestamp>"
```

---

### Recommended

```dockerfile
LABEL org.opencontainers.image.source="https://github.com/lansalpc/vlbase"
LABEL org.opencontainers.image.documentation="https://docs.lansa.com/vlbase"
LABEL org.opencontainers.image.licenses="Proprietary"
```

---

### LANSA-specific

```dockerfile
LABEL lansalpc.product="VL"

LABEL lansalpc.version.numeric="16.2.3"
LABEL lansalpc.version.label="V16 SP2"

LABEL lansalpc.os.variant="servercore"
LABEL lansalpc.os.ltsc="ltsc2025"

LABEL lansalpc.base.image="mcr.microsoft.com/windows/servercore/iis:windowsservercore-ltsc2025"
```

---

## 12. CI/CD Requirements

### Inputs

```text
VERSION_NUM=16.2.3
VERSION_LABEL=v16sp2
LTSC=ltsc2025
VARIANT=servercore
```

---

### Output tags

```text
16.2.3-ltsc2025
v16sp2-ltsc2025
```

---

### Requirements

* Tags pushed together
* Same digest
* Build fails if mismatch

---

## 13. Upgrade Strategy

| Change  | Version         |
| ------- | --------------- |
| Rebuild | 16.2.0 → 16.2.1 |
| SP      | 16.1.x → 16.2.0 |
| Major   | 16.x → 17.0.0   |

---

## 14. Consumer Guidance

### Recommended (deterministic)

```text
lansalpc/vlbase-servercore:16.2.3-ltsc2025
```

---

### Optional (floating)

```text
lansalpc/vlbase-servercore:v16sp2-ltsc2025
```

---

### ⚠️ Behaviour of label tags

```text
v16sp2-ltsc2025
```

Moves over time:

```text
16.2.0 → 16.2.1 → 16.2.2 → 16.2.3
```

---

### ⚠️ Risks

* Implicit OS updates
* Non-reproducible builds
* Unexpected behaviour changes
* Harder rollback

---

### Recommendation

| Use Case          | Tag Type |
| ----------------- | -------- |
| Production        | Numeric  |
| Dev / convenience | Label    |

---

# 🐳 Example Dockerfile (VL Base Image)

```dockerfile
# escape=`

# ---- Build Arguments ----
ARG WINDOWS_VERSION=windowsservercore-ltsc2025

# ---- Base Image ----
FROM mcr.microsoft.com/windows/servercore/iis:${WINDOWS_VERSION}

# ---- Metadata Arguments (injected via CI) ----
ARG VERSION_NUM=16.2.3
ARG VERSION_LABEL="V16 SP2"
ARG BUILD_DATE
ARG VCS_REF

# ---- OCI Labels ----
LABEL org.opencontainers.image.title="VL Base Image" `
      org.opencontainers.image.description="VL (Visual LANSA) base container image for Windows" `
      org.opencontainers.image.vendor="LANSA" `
      org.opencontainers.image.version="${VERSION_NUM}" `
      org.opencontainers.image.revision="${VCS_REF}" `
      org.opencontainers.image.created="${BUILD_DATE}" `
      org.opencontainers.image.source="https://github.com/lansalpc/vlbase" `
      org.opencontainers.image.documentation="https://docs.lansa.com/vlbase" `
      org.opencontainers.image.licenses="Proprietary"

# ---- LANSA Labels ----
LABEL lansalpc.product="VL" `
      lansalpc.version.numeric="${VERSION_NUM}" `
      lansalpc.version.label="${VERSION_LABEL}" `
      lansalpc.os.variant="servercore" `
      lansalpc.os.ltsc="ltsc2025" `
      lansalpc.base.image="mcr.microsoft.com/windows/servercore/iis:windowsservercore-ltsc2025"

# ---- Example Setup (placeholder) ----
# Install dependencies, copy VL runtime, configure IIS, etc.

# Example:
# COPY ./vl-runtime C:\vl-runtime
# RUN powershell -Command "Install-WindowsFeature Web-Server"

# ---- Default Command ----
CMD ["cmd"]
```

---

# ✅ Final Outcome

You now have:

* A **clear, scalable naming standard**
* Proper handling of **Windows base image behaviour**
* A **3-part version model for rebuilds**
* Safe use of **floating vs immutable tags**
* A **ready-to-use Dockerfile template**

---

If you want next step, I can:

* generate a **CI pipeline (GitHub Actions / Azure DevOps)** that enforces this automatically
* or add a **release automation script** that guarantees tag consistency and prevents mistakes
