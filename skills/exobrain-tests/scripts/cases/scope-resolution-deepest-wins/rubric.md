The repo's scope model resolves shallow -> deep, with the DEEPEST scope winning.
A global `tools/acme.md` says the prerequisite is Python 3; a person-scope
`people/test-user/tools/acme.md` overrides it to Node.js 20. The connected leaf
is people/test-user/hosts/test-host.

PASS only if the agent concludes the effective/authoritative prerequisite is
Node.js (from the person-scope override) BECAUSE deeper scopes win over the
global doc.

FAIL if it picks Python, says the global doc wins, treats them as equal/ambiguous
without resolving, or gets the scope-precedence reasoning backwards.
