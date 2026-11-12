# iVMS-4200 3.14.1.3 — five-minute live-view timeout investigation

> **Unofficial research; tested locally.** With three simultaneous camera streams, the patched client worked for more than one hour, with no countdown and normal camera switching. Other builds and configurations have not been validated.
>
> This project is not affiliated with Hikvision. Modifying proprietary software may violate license terms or applicable law. Use only where authorized and at your own risk.

[**Polski opis / Polish documentation**](README_PL.md)

## Symptom

On the tested Hik-Connect connection, iVMS-4200 3.14.1.3 displayed a five-minute countdown during live view and stopped the stream when the countdown expired. On the same setup, older client version 3.6.0.6_E did not show that limitation.

## Diagnostic findings

- The on-screen counter at `MainViewPlugin+492D97` was independent of the actual stream timeout; changing the displayed duration did not delay stream termination.
- Automatic timeout passed through event code `0x19` (`EVENT25`) at `MainViewPlugin+41BCC2`. In the comparison test, manually closing the preview did not invoke that event.
- An x64dbg call stack connected that event handler to `PreviewLogical::CBasePreview::StopPreview()`.
- Bypassing the relevant event branch allowed live view to continue. A second change suppressed the countdown text.

## Exact patch: two bytes

**Offsets are file offsets, not memory addresses or RVAs. Do not apply them to other DLL builds.**

| File offset | Original | Patched | Meaning |
|---|---|---|---|
| `0x41B16C` | `C2` | `D7` | Redirect the `EVENT25` jump-table entry from `MainViewPlugin+41BCC2` to `MainViewPlugin+41BCD7` |
| `0x6639B8` | `25` (`%`) | `00` | Terminate the `%1:%2:%3` timer format string at its first byte |

Original file size: **9,384,448 bytes**.

Original DLL SHA-256:

```text
5610F35B164599FD9ADB425E80B38CF4BE98BD1CEE21A3EFAA0A1706272AF66A
```

Patched DLL SHA-256:

```text
9848B2043EEBBB74F58C045C7A0D264A48FD897BFE37A243D2A9AD0C235B9207
```

The [`patch.ps1`](patch.ps1) script checks the exact original SHA-256 before patching, retains a `.bak` backup, verifies the output hash, and supports `-Restore`. It refuses unknown files.

## Usage

1. Exit iVMS-4200 completely, including the `iVMS-4200.Video.C.exe` process.
2. Locate the `MainViewPlugin.dll` belonging to your own installation.
3. Make an additional copy of the original file.
4. Run in Windows PowerShell:
   ```powershell
   .\patch.ps1 -DllPath 'C:\path\to\MainViewPlugin.dll'
   ```
   Administrator privileges may be required to modify files under `Program Files`.
5. Start the application normally. Validate the live timestamp, simultaneous cameras, switching, and behavior beyond five minutes.
6. Restore if necessary:
   ```powershell
   .\patch.ps1 -DllPath 'C:\path\to\MainViewPlugin.dll' -Restore
   ```
   Alternatively, restore the verified `.bak` file manually.

## Test results

| Test | Observation |
|---|---|
| One camera, >10 minutes | Live stream continued |
| Switching to a different camera, >15 minutes | Live stream continued |
| Two streams at `00:00` with event bypass | Both streams continued |
| Three streams with both byte changes | >1 hour; no countdown; camera switching worked |

## Limitations and reporting

This is an experimental, version-specific patch—not an official fix. It has not undergone extensive regression testing; other preview-session behavior may be affected. Modifying the file can invalidate its digital signature, if present.

**No original or modified Hikvision DLL is distributed here.** Only independently written technical documentation and a local patch script are provided.

When reporting an issue, include the iVMS version, original DLL SHA-256 and connection type. Do **not** post passwords, account IDs, camera serial numbers or private surveillance footage.
