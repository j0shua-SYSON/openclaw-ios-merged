AGENTS.md

## Embedding an app as an OpenClaw "mode"

If the task is "embed <app>", read **`Modes/EMBEDDING_HANDOFF.md` first** — before touching any
code. It is the cross-cutting playbook: the user's hard constraints (drive/storage), where the
copyright line sits (some past "embed this" requests were declined on principle and should stay
declined), the framework-conversion pattern, and a catalogue of runtime crashes that every mode so
far has hit. Most of it is not derivable from the code, and each entry cost a full
build → sign → OTA → device-crash cycle to learn.

Per-mode specifics live in `Modes/<Mode>/INTEGRATION.md`.
