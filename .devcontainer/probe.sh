#!/usr/bin/env bash
# Runs INSIDE a codespace created for uunix6/test.
#
# Question, from GitHub's own ineligible list: "That token is scoped to the repository the
# codespace was created for." So does the in-codespace token reach a DIFFERENT repository?
#
# Both repositories belong to the same test account. Nothing belonging to anyone else is touched.
# NO TOKEN VALUE IS EVER RECORDED. Only the HTTP status, the token's type prefix, and which
# environment variable carried it.
set -u
OUT=/tmp/cs-probe.json
OWN=uunix6/test
OTHER=uunix6/cost-corpus-1792417669        # a DIFFERENT repo, private, same owner

tok=""
src=""
for v in GITHUB_TOKEN GH_TOKEN CODESPACES_TOKEN GITHUB_CODESPACE_TOKEN; do
  val="${!v:-}"
  if [ -n "$val" ]; then tok="$val"; src="$v"; break; fi
done

prefix="none"
if [ -n "$tok" ]; then prefix="$(printf '%s' "$tok" | cut -c1-4)"; fi

code() { curl -s -o /dev/null -w '%{http_code}' -H "Authorization: Bearer $tok" \
  -H 'Accept: application/vnd.github+json' -H 'User-Agent: hackerone-furkan' \
  -H 'X-Bug-Bounty: HackerOne-furkan' "https://api.github.com/$1"; }

anon() { curl -s -o /dev/null -w '%{http_code}' -H 'Accept: application/vnd.github+json' \
  -H 'User-Agent: hackerone-furkan' "https://api.github.com/$1"; }

own_code="n/a"; other_code="n/a"; other_contents="n/a"; user_code="n/a"
if [ -n "$tok" ]; then
  own_code=$(code "repos/$OWN")
  other_code=$(code "repos/$OTHER")
  other_contents=$(code "repos/$OTHER/contents/README.md")
  user_code=$(code "user")
fi
# CONTROL: the other repo is private, so an ANONYMOUS read must fail. Without this a 200 on the
# token arm could just mean the repo is public.
other_anon=$(anon "repos/$OTHER")

cat > "$OUT" <<JSON
{
  "token_env_var": "$src",
  "token_prefix": "$prefix",
  "own_repo": "$OWN",
  "other_repo": "$OTHER",
  "own_repo_status": "$own_code",
  "other_repo_status": "$other_code",
  "other_repo_contents_status": "$other_contents",
  "user_endpoint_status": "$user_code",
  "other_repo_anonymous_status": "$other_anon",
  "note": "status codes only, no token value recorded"
}
JSON
cat "$OUT"
