# Signing the build

Builds come out of CI **unsigned** (the `iOS Build (unsigned)` workflow → artifact
`OpenClaw-unsigned`). The `Re-sign IPA` workflow signs that artifact with **your**
certificate and provisioning profile and produces an installable `OpenClaw-signed` IPA.

## One-time: add your signing secrets

Set three repository secrets (done once; reused for every sign). You need your
`.p12` certificate, its password, and a `.mobileprovision` whose App ID matches
`ai.openclawfoundation.app` (a **wildcard** profile is easiest — it also covers the
app extensions / Watch app if you don't strip them).

### Windows (PowerShell)

```powershell
# from the folder holding cert.p12 and profile.mobileprovision
$p12  = [Convert]::ToBase64String([IO.File]::ReadAllBytes("cert.p12"))
$prof = [Convert]::ToBase64String([IO.File]::ReadAllBytes("profile.mobileprovision"))
$p12  | gh secret set SIGNING_P12_BASE64 --repo <owner>/<repo>
$prof | gh secret set SIGNING_MOBILEPROVISION_BASE64 --repo <owner>/<repo>
gh secret set SIGNING_P12_PASSWORD --repo <owner>/<repo> --body "YOUR_P12_PASSWORD"
```

### macOS / Linux

```bash
base64 -i cert.p12                 | gh secret set SIGNING_P12_BASE64
base64 -i profile.mobileprovision  | gh secret set SIGNING_MOBILEPROVISION_BASE64
gh secret set SIGNING_P12_PASSWORD --body "YOUR_P12_PASSWORD"
```

## Each time you want a signed build

1. Let `iOS Build (unsigned)` finish (runs on every push, or trigger it manually).
   It publishes the unsigned IPA to the **`ci-unsigned`** release.
2. Run the **Re-sign IPA** workflow (Actions tab → *Re-sign IPA* → *Run workflow*).
   - `strip_extensions`: leave **on** unless your profile is a wildcard that also
     covers `…app.share`, `…app.activitywidget`, and `…app.watchkitapp`.
3. Download `OpenClaw-signed.ipa` from the **`ci-signed`** release (Releases page)
   and install it (SideStore / your tool).

> Builds are delivered via **GitHub Releases** (`ci-unsigned` / `ci-signed`) rather
> than Actions artifacts, because the account's Actions artifact-storage quota is
> full. Releases use separate storage and give a stable download URL.

Nothing is signed or stored locally on your machine; secrets live only in GitHub.
