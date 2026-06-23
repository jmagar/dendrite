#!/usr/bin/env bash
set -euo pipefail

json=0
run_checks=0
offline=0
base_ref=""
pr_ref=""

usage() {
  cat <<'EOF'
Usage: merge-status.sh [--json] [--run-checks] [--offline] [--base <ref>] [--pr <number-or-url>]

Collect read-only merge-readiness evidence for the current branch/worktree.
By default this prints a human summary. Use --json for machine-readable output.
Local lint/test commands are inventoried but only executed with --run-checks.
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --json) json=1 ;;
    --run-checks) run_checks=1 ;;
    --offline) offline=1 ;;
    --base)
      shift
      base_ref="${1:-}"
      ;;
    --pr)
      shift
      pr_ref="${1:-}"
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
  shift
done

need() {
  command -v "$1" >/dev/null 2>&1
}

jq_available=0
if need jq; then
  jq_available=1
fi

repo_root=$(git rev-parse --show-toplevel)
cd "$repo_root"

branch=$(git branch --show-current || true)
head_sha=$(git rev-parse HEAD)
upstream=$(git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null || true)

if [ -z "$base_ref" ]; then
  if git rev-parse --verify origin/main >/dev/null 2>&1; then
    base_ref="origin/main"
  elif git rev-parse --verify origin/master >/dev/null 2>&1; then
    base_ref="origin/master"
  elif git symbolic-ref --quiet refs/remotes/origin/HEAD >/dev/null 2>&1; then
    base_ref=$(git symbolic-ref --short refs/remotes/origin/HEAD)
  else
    base_ref="${upstream:-HEAD}"
  fi
fi

fetch_status="skipped"
if [ "$offline" -eq 0 ] && git remote get-url origin >/dev/null 2>&1; then
  if git fetch --quiet --prune origin; then
    fetch_status="ok"
  else
    fetch_status="failed"
  fi
fi

status_short=$(git status --short --branch)
status_v2=$(git status --porcelain=v2 --branch)
dirty_total=$(printf '%s\n' "$status_v2" | awk 'substr($0,1,1) != "#" && length($0) > 0 {count++} END {print count+0}')
staged_count=$(printf '%s\n' "$status_v2" | awk '($1 == "1" || $1 == "2") && substr($2,1,1) != "." {count++} END {print count+0}')
unstaged_count=$(printf '%s\n' "$status_v2" | awk '($1 == "1" || $1 == "2") && substr($2,2,1) != "." {count++} END {print count+0}')
untracked_count=$(printf '%s\n' "$status_v2" | awk '$1 == "?" {count++} END {print count+0}')

ahead=$(printf '%s\n' "$status_v2" | awk '/^# branch.ab / {print $3}' | sed 's/+//')
behind=$(printf '%s\n' "$status_v2" | awk '/^# branch.ab / {print $4}' | sed 's/-//')
ahead=${ahead:-0}
behind=${behind:-0}

merge_base=""
changed_files=""
if git rev-parse --verify "$base_ref" >/dev/null 2>&1; then
  merge_base=$(git merge-base "$base_ref" HEAD 2>/dev/null || true)
  changed_files=$(git diff --name-only "$base_ref"...HEAD 2>/dev/null || true)
fi
status_files=$(git status --porcelain | sed -E 's/^...//; s/^.* -> //' | sed '/^$/d' || true)
changed_files=$(printf '%s\n%s\n' "$changed_files" "$status_files" | sed '/^$/d' | sort -u)

conflict_markers=$(git grep -n -E '^(<<<<<<< |=======$|>>>>>>> )' -- . ':!*.lock' 2>/dev/null || true)

merge_result="unverified"
merge_detail="base ref unavailable"
if [ -n "$merge_base" ]; then
  merge_output=$(mktemp)
  if git merge-tree --write-tree "$base_ref" HEAD >"$merge_output" 2>&1; then
    merge_result="clean"
    merge_detail="git merge-tree --write-tree succeeded"
  else
    merge_result="conflicts_or_error"
    merge_detail=$(tr '\n' ' ' <"$merge_output" | cut -c1-300)
  fi
  rm -f "$merge_output"
fi

worktrees=$(git worktree list --porcelain)
other_worktree_overlaps=""
if [ -n "$changed_files" ]; then
  current_path=$(pwd -P)
  while IFS= read -r wt_path; do
    [ -n "$wt_path" ] || continue
    [ "$(cd "$wt_path" 2>/dev/null && pwd -P || true)" != "$current_path" ] || continue
    wt_branch=$(git -C "$wt_path" branch --show-current 2>/dev/null || true)
    [ -n "$wt_branch" ] || continue
    wt_base="$base_ref"
    git -C "$wt_path" rev-parse --verify "$wt_base" >/dev/null 2>&1 || wt_base="HEAD"
    wt_files=$(git -C "$wt_path" diff --name-only "$wt_base"...HEAD 2>/dev/null || true)
    overlap=$(comm -12 \
      <(printf '%s\n' "$changed_files" | sed '/^$/d' | sort -u) \
      <(printf '%s\n' "$wt_files" | sed '/^$/d' | sort -u) || true)
    if [ -n "$overlap" ]; then
      other_worktree_overlaps="${other_worktree_overlaps}${wt_branch} (${wt_path}): $(printf '%s' "$overlap" | paste -sd ',' -)"$'\n'
    fi
  done < <(printf '%s\n' "$worktrees" | awk '/^worktree / {sub(/^worktree /, ""); print}')
fi

pr_json=""
pr_url=""
ci_summary="unavailable"
review_summary="unavailable"
pr_state="unavailable"
pr_draft="unavailable"
pr_mergeable="unavailable"
ci_unready=0
if [ "$offline" -eq 0 ] && need gh; then
  if [ -n "$pr_ref" ]; then
    pr_target="$pr_ref"
  else
    pr_target=""
  fi
  if pr_json=$(gh pr view ${pr_target:+"$pr_target"} --json number,url,headRefName,baseRefName,state,isDraft,mergeable,reviewDecision,statusCheckRollup 2>/dev/null); then
    if [ "$jq_available" -eq 1 ]; then
      pr_url=$(printf '%s' "$pr_json" | jq -r '.url // ""')
      review_summary=$(printf '%s' "$pr_json" | jq -r '.reviewDecision // "unknown"')
      pr_state=$(printf '%s' "$pr_json" | jq -r '.state // "unknown"')
      pr_draft=$(printf '%s' "$pr_json" | jq -r '.isDraft // "unknown"')
      pr_mergeable=$(printf '%s' "$pr_json" | jq -r '.mergeable // "unknown"')
      ci_summary=$(printf '%s' "$pr_json" | jq -r '[.statusCheckRollup[]? | .conclusion // .status // "unknown"] | group_by(.) | map("\(.[0])=\(length)") | if length == 0 then "none" else join(", ") end')
      if printf '%s' "$pr_json" | jq -e '.statusCheckRollup[]? | (.conclusion // .status // "unknown") | test("^(SUCCESS|SKIPPED|NEUTRAL|none)$") | not' >/dev/null; then
        ci_unready=1
      fi
    else
      ci_summary="unavailable"
      review_summary="unavailable"
      pr_state="unavailable"
      pr_draft="unavailable"
      pr_mergeable="unavailable"
    fi
  fi
fi

check_inventory=""
if [ -x plugins/scripts/check-all ]; then
  check_inventory="${check_inventory}plugins/scripts/check-all"$'\n'
fi
if [ -f package.json ] && need jq; then
  for script_name in lint test typecheck build; do
    if jq -e --arg s "$script_name" '.scripts[$s]?' package.json >/dev/null 2>&1; then
      check_inventory="${check_inventory}npm run ${script_name}"$'\n'
    fi
  done
fi
if [ -f Cargo.toml ]; then
  check_inventory="${check_inventory}cargo test"$'\n'
fi

check_results=""
if [ "$run_checks" -eq 1 ]; then
  while IFS= read -r check_cmd; do
    [ -n "$check_cmd" ] || continue
    output=$(mktemp)
    if bash -lc "$check_cmd" >"$output" 2>&1; then
      check_results="${check_results}${check_cmd}: pass"$'\n'
    else
      check_results="${check_results}${check_cmd}: fail ($(tail -20 "$output" | tr '\n' ' ' | cut -c1-240))"$'\n'
    fi
    rm -f "$output"
  done < <(printf '%b' "$check_inventory")
fi

docs_config_hints=""
if printf '%s\n' "$changed_files" | grep -Eq '(^|/)(README|CHANGELOG|CONTRIBUTING|docs/|.*\.md$|.*\.json$|.*\.toml$|.*\.ya?ml$|.*example.*|.*template.*)'; then
  docs_config_hints="docs_or_config_related_changes_detected"
fi

status="ready_to_merge"
required_fixes=""
if [ "$dirty_total" -gt 0 ]; then
  status="not_ready"
  required_fixes="${required_fixes}working tree has ${dirty_total} dirty entries"$'\n'
fi
if [ "$merge_result" != "clean" ]; then
  status="not_ready"
  required_fixes="${required_fixes}merge simulation is ${merge_result}"$'\n'
fi
if [ -n "$conflict_markers" ]; then
  status="not_ready"
  required_fixes="${required_fixes}conflict markers found"$'\n'
fi
if [ -n "$other_worktree_overlaps" ]; then
  [ "$status" = "ready_to_merge" ] && status="unverified"
  required_fixes="${required_fixes}overlap with other worktrees needs review"$'\n'
fi
if [ "$run_checks" -eq 0 ]; then
  [ "$status" = "ready_to_merge" ] && status="unverified"
  required_fixes="${required_fixes}local checks inventoried but not run; pass --run-checks before merge-ready"$'\n'
elif printf '%b' "$check_results" | grep -q ': fail'; then
  status="not_ready"
  required_fixes="${required_fixes}one or more local checks failed"$'\n'
fi
if [ "$ci_summary" = "unavailable" ]; then
  [ "$status" = "ready_to_merge" ] && status="unverified"
  required_fixes="${required_fixes}CI status unavailable"$'\n'
elif [ "$ci_unready" -eq 1 ] || printf '%s' "$ci_summary" | grep -Eiq 'FAILURE|CANCELLED|TIMED_OUT|ACTION_REQUIRED|PENDING|IN_PROGRESS|QUEUED|REQUESTED|WAITING|EXPECTED|failed|failure|pending|progress|queued'; then
  status="not_ready"
  required_fixes="${required_fixes}CI has failing, pending, or unknown checks"$'\n'
fi
if [ -n "$pr_url" ]; then
  if [ "$pr_state" != "OPEN" ]; then
    status="not_ready"
    required_fixes="${required_fixes}PR state is ${pr_state}"$'\n'
  fi
  if [ "$pr_draft" = "true" ]; then
    status="not_ready"
    required_fixes="${required_fixes}PR is still draft"$'\n'
  fi
  if [ "$pr_mergeable" != "MERGEABLE" ]; then
    status="not_ready"
    required_fixes="${required_fixes}PR mergeability is ${pr_mergeable}"$'\n'
  fi
  case "$review_summary" in
    APPROVED|"")
      ;;
    unavailable|unknown)
      [ "$status" = "ready_to_merge" ] && status="unverified"
      required_fixes="${required_fixes}PR review decision is ${review_summary}"$'\n'
      ;;
    *)
      status="not_ready"
      required_fixes="${required_fixes}PR review decision is ${review_summary}"$'\n'
      ;;
  esac
fi

if [ "$json" -eq 1 ]; then
  if [ "$jq_available" -ne 1 ]; then
    echo "--json requires jq" >&2
    exit 2
  fi
  jq -n \
    --arg status "$status" \
    --arg repo_root "$repo_root" \
    --arg branch "$branch" \
    --arg head "$head_sha" \
    --arg upstream "$upstream" \
    --arg base "$base_ref" \
    --arg fetch_status "$fetch_status" \
    --arg pr_url "$pr_url" \
    --arg ci_summary "$ci_summary" \
    --arg review_summary "$review_summary" \
    --arg pr_state "$pr_state" \
    --arg pr_draft "$pr_draft" \
    --arg pr_mergeable "$pr_mergeable" \
    --arg merge_result "$merge_result" \
    --arg merge_detail "$merge_detail" \
    --argjson dirty_total "$dirty_total" \
    --argjson staged "$staged_count" \
    --argjson unstaged "$unstaged_count" \
    --argjson untracked "$untracked_count" \
    --argjson ahead "$ahead" \
    --argjson behind "$behind" \
    --arg status_short "$status_short" \
    --arg changed_files "$changed_files" \
    --arg overlaps "$other_worktree_overlaps" \
    --arg conflict_markers "$conflict_markers" \
    --arg check_inventory "$check_inventory" \
    --arg check_results "$check_results" \
    --arg docs_config_hints "$docs_config_hints" \
    --arg required_fixes "$required_fixes" \
    '{
      status: $status,
      repo_root: $repo_root,
      branch: $branch,
      head: $head,
      upstream: $upstream,
      base: $base,
      fetch_status: $fetch_status,
      pr_url: $pr_url,
      ci_summary: $ci_summary,
      review_summary: $review_summary,
      pr: {
        url: $pr_url,
        state: $pr_state,
        is_draft: $pr_draft,
        mergeable: $pr_mergeable,
        review_decision: $review_summary
      },
      dirty: {
        total: $dirty_total,
        staged: $staged,
        unstaged: $unstaged,
        untracked: $untracked,
        ahead: $ahead,
        behind: $behind,
        status_short: $status_short
      },
      merge: { result: $merge_result, detail: $merge_detail },
      changed_files: ($changed_files | split("\n") | map(select(length > 0))),
      worktree_overlaps: ($overlaps | split("\n") | map(select(length > 0))),
      conflict_markers: ($conflict_markers | split("\n") | map(select(length > 0))),
      check_inventory: ($check_inventory | split("\n") | map(select(length > 0))),
      check_results: ($check_results | split("\n") | map(select(length > 0))),
      docs_config_hints: $docs_config_hints,
      required_fixes: ($required_fixes | split("\n") | map(select(length > 0)))
    }'
  exit 0
fi

cat <<EOF
status: $status
branch: ${branch:-detached}
head: $head_sha
base: $base_ref
upstream: ${upstream:-none}
pr: ${pr_url:-none}
fetch: $fetch_status

dirty:
$(printf '%s\n' "$status_short" | sed 's/^/  /')
  staged=$staged_count unstaged=$unstaged_count untracked=$untracked_count ahead=$ahead behind=$behind

merge:
  result: $merge_result
  detail: $merge_detail

ci:
  checks: $ci_summary
  review: $review_summary
  pr_state: $pr_state
  pr_draft: $pr_draft
  pr_mergeable: $pr_mergeable

changed files:
$(printf '%s\n' "${changed_files:-none}" | sed 's/^/  /')

worktree overlaps:
$(printf '%b' "${other_worktree_overlaps:-none}" | sed 's/^/  /')

conflict markers:
$(printf '%s\n' "${conflict_markers:-none}" | sed 's/^/  /')

check inventory:
$(printf '%b' "${check_inventory:-none}" | sed 's/^/  /')

check results:
$(printf '%b' "${check_results:-not run; pass --run-checks}" | sed 's/^/  /')

docs/config hints:
  ${docs_config_hints:-none}

required fixes:
$(printf '%b' "${required_fixes:-none}" | sed 's/^/  /')

live config notice:
  If config examples, templates, or runtime settings changed, update the matching live .env, config.toml, or equivalent local config outside the repo.
EOF
