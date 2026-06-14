---
id: 0018
title: Strip inherited proxy env from a hook's LLM engine call
date: 2026-06-14
tags: [authoring-review, hooks, proxy]
touches_invariant: false
files: [scripts/authoring-review.sh]
---

## Problem

A pre-push hook that calls an LLM (e.g. the authoring review) can silently degrade to
"no engine" when the push runs through a network proxy. Pushing to an internal Git host
often needs a SOCKS/HTTP proxy in the environment; the hook inherits it and routes the
LLM call through that internal proxy, which can't reach the model API. The review then
skips on every such push — a silent failure that looks like "no engine installed."

## Pattern

A hook's LLM engine talks to its own API directly, so strip inherited proxy vars from
the engine subprocess. Removing an unset var is a no-op, so it is safe whether or not a
proxy is set. Make the degrade-open message distinguish "no engine on PATH" from "engine
errored / timed out" so the real cause is legible.

Bonus, upstream of the bug: configure the proxy *per-remote* in git
(`http.<url>.proxy`) so plain `git push` / `git fetch` never need the env at all — only
tools that don't read git config need it. That keeps the polluting env off the hook in
the first place.

## Reference (illustration only)

Wrap the engine invocation with `env -u ALL_PROXY -u HTTPS_PROXY -u HTTP_PROXY` (plus the
lowercase variants) ahead of any timeout/CLI wrapper.

## Adapt notes

Applies to any hook or script that runs in a proxied push/CI context but must reach an
external API. Don't strip the proxy from the parts that genuinely need it (the git
transport itself). No invariant is touched.
