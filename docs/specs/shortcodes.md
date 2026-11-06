# Repository shortcode contract

**Status: VERIFIED 2026-11-06** against `akashdh11/skystream@master`:
`lib/core/extensions/services/repository_service.dart` and
`lib/core/cloudstream/cloudstream_repository.dart`.

A repository may be added by a **shortcode** instead of a URL. Codes are
resolved online, so new repositories work without an app update. Aero ships
**no** codes, no default repositories and no bundled sources — this document
describes only how a code the *user* types is resolved.

## Input shapes

Accepted by `parseRepoUrl` / `resolveUrl`, in this order:

| Shape | Handling |
|---|---|
| `https://…` / `http://…` | Use as-is; if the host is a known shortener, follow one hop |
| `skystream://host/path` | Rewrite scheme to `https` |
| `cloudstreamrepo://…`, `https://cs.repo/?…` | Strip the prefix, force `https` |
| Bare host (`raw.githubusercontent.com/…`, `github.com/user/repo`) | Prefix `https://` |
| Bare code, `^[a-zA-Z0-9!_-]+$` | Look up at the shorteners below |
| Anything else | Reject: "Invalid URL format" |

## Shortcode lookup order

Codes are **case-sensitive**, but a TV keyboard or a phone may capitalise the
first letter, so each spelling is tried as typed and then lowercased.

**SkyStream** — the namespaced form first, then the bare form:

1. `https://cutt.ly/sky-<CODE>`
2. `https://cutt.ly/sky-<code>`
3. `https://cutt.ly/<CODE>`
4. `https://cutt.ly/<code>`

Candidates are deduplicated, so an already-lowercase code yields two.
The namespaced form comes first because a bare `cutt.ly/Universe` belongs to
whoever registered it, not necessarily to a SkyStream repository.

**CloudStream** — no namespace, and `!` selects the second shortener:

* `<CODE>` → `https://cutt.ly/<CODE>`
* `!<CODE>` → `https://py.md/<CODE>`
* then the lowercased spelling of whichever applied

## Known shorteners

`cutt.ly`, `py.md`. A pasted link on either host is followed one hop, exactly
as a code is.

## Following one hop

Request with `followRedirects: false`, `ResponseType.plain`,
`validateStatus: status < 500`, and a **desktop browser User-Agent** — the
shorteners serve a different page to a bare HTTP client.

| Answer | Meaning |
|---|---|
| `3xx` + `Location` | The target |
| `404`, `410` | No such code — try the next spelling |
| `429` | Rate limited. **Not** "no such code"; surface "try again in a minute" |
| other `4xx`/`5xx` | Service error, distinct from a missing code |
| `200` + `<meta http-equiv="refresh" content="…url=TARGET">` | The target |
| `200` + `window.location` / `location` / `location.href` `= "TARGET"` or `'TARGET'` | The target |
| `200`, nothing recognised | Dead end — try the next spelling |

Meta-refresh and JS redirects matter: the shorteners increasingly answer `200`
with a page rather than a `302`.

## Validating the target (`_followable`)

* Resolve the target **against the short URL** — it may be a relative path.
* HTML-unescape `&amp;`, `&#39;`, `&quot;` first.
* Reject anything that is not `http`/`https`, and any empty host (`http:foo`).
* Reject the short link's own page again: same host **and** same path, i.e. a
  target that only changes the query or fragment.
* Reject dead ends: `cutt.ly/404…`, `cutt.ly`, `py.md/404…`, `py.md`, empty.
* Force the result to `https`.

That last rule is a security boundary, not cosmetic: a repository address
decides which code the app downloads and runs, so plain HTTP would let anyone
on the network swap it.

## Failure messages

* Nothing resolved, no transport error → "That shortcode doesn't exist"
* Transport error → "Could not reach the shortcode service: …"
* Empty input → "Enter a repository URL or code"

## Aero implementation notes

* Resolution happens **before** the SSRF guard sees the final URL, and the
  resolved URL must go through `IpGuard` like any other plugin destination —
  a shortcode is an untrusted redirect and must not be able to point at
  `127.0.0.1` or a link-local address.
* Only one hop is followed. A chain of shorteners is not chased.
* The short link a code was found at is worth keeping for display, so the user
  can see which repository a code actually installed.
