#!/usr/bin/env bash
# Runs INSIDE a codespace created for uunix6/test, from the devcontainer postCreateCommand.
#
# GitHub's ineligible list, under GitHub Codespaces: "That token is scoped to the repository the
# codespace was created for." And the eligibility exception in the same section: "A report is
# eligible if you can show the token or the environment reaching a different repository, another
# user's codespace, or data outside that scope."
#
# So this asks one question: does the in-codespace token reach a DIFFERENT repository?
#
# Both repositories belong to the same test account. Nothing belonging to anyone else is touched.
# NO TOKEN VALUE IS EVER RECORDED OR TRANSMITTED. Only HTTP status codes, the name of the
# environment variable that carried a token, and the token's 4 character type prefix.
#
# Results are pushed to a branch of this repository using the codespace's own git credentials,
# because the ssh and cp channels both need a tunnel and the base image ships no sshd.
set -u
OWN=uunix6/test
OTHER=uunix6/cost-corpus-1792417669        # DIFFERENT repo, PRIVATE, same owner
OUT=/tmp/cs-probe.json

# EVERY token the environment carries, not just the first one found. The previous run picked
# GITHUB_TOKEN and stopped, and the environment also advertises GITHUB_CODESPACE_TOKEN, so that
# negative covered one credential out of two. A credential you did not test is not a credential
# you have cleared.
code() { curl -s -o /dev/null -w '%{http_code}' -H "Authorization: Bearer $2"   -H 'Accept: application/vnd.github+json' -H 'User-Agent: hackerone-furkan'   -H 'X-Bug-Bounty: HackerOne-furkan' "https://api.github.com/$1"; }
anon() { curl -s -o /dev/null -w '%{http_code}' -H 'Accept: application/vnd.github+json'   -H 'User-Agent: hackerone-furkan' "https://api.github.com/$1"; }

rows=""
for v in GITHUB_TOKEN GH_TOKEN CODESPACES_TOKEN GITHUB_CODESPACE_TOKEN; do
  val="${!v:-}"
  if [ -z "$val" ]; then
    rows="$rows    {\"var\":\"$v\",\"present\":false},
"
    continue
  fi
  pfx="$(printf '%s' "$val" | cut -c1-4)"
  o=$(code "repos/$OWN" "$val")
  a=$(code "repos/$OTHER" "$val")
  ac=$(code "repos/$OTHER/contents/README.md" "$val")
  at=$(code "repos/$OTHER/git/trees/main" "$val")
  u=$(code "user" "$val")
  ul=$(code "user/repos?per_page=1" "$val")
  rows="$rows    {\"var\":\"$v\",\"present\":true,\"prefix\":\"$pfx\",\"own_POSITIVE\":\"$o\",\"other_ARM\":\"$a\",\"other_contents\":\"$ac\",\"other_tree\":\"$at\",\"user\":\"$u\",\"user_repos\":\"$ul\"},
"
done

# CONTROL: the other repo is PRIVATE, so anonymous must fail. Without this a 200 on the arm
# could simply mean the repository is public.
oanon=$(anon "repos/$OTHER")

# what the environment advertises, names only, never values
envkeys=$(env | grep -oiE '^(GITHUB|GH|CODESPACE)[A-Z_]*' | sort -u | tr '\n' ' ')

oanon=$(anon "repos/$OTHER")
envkeys=$(env | grep -oiE '^(GITHUB|GH|CODESPACE)[A-Z_]*' | sort -u | tr '
' ' ')
{
  printf '{
  "other_repo_anonymous_CONTROL": "%s",
' "$oanon"
  printf '  "github_env_var_names": "%s",
' "$envkeys"
  printf '  "own_repo": "%s",
  "other_repo": "%s",
' "$OWN" "$OTHER"
  printf '  "note": "status codes only, no token value recorded or transmitted",
'
  printf '  "tokens": [
'
  printf "$rows" | sed '$ s/,$//'
  printf '  ]
}
'
} > "$OUT"
cat "$OUT"

# push the result through git, which needs no tunnel
cd /workspaces/test 2>/dev/null || cd "$(ls -d /workspaces/* | head -1)"
br="probe-$(date +%s)"
git checkout -b "$br" >/dev/null 2>&1
cp "$OUT" ./probe-result.json
git add probe-result.json >/dev/null 2>&1
git -c user.email=probe@example.invalid -c user.name=probe commit -m "probe result" >/dev/null 2>&1
git push origin "$br" >/dev/null 2>&1
echo "pushed branch $br  push_exit=$?"
