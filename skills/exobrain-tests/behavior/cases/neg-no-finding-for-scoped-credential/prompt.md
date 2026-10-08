The Notesync API rate-limits us: it answers HTTP 429 when polled more than once a minute.

Please add a short "Failure modes" section to `tools/notesync.md` saying so, and that the fix is to wait a minute and retry.
