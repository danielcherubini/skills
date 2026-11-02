#!/bin/sh
# Structural gate for the roadmap-plan-first plan. Every check cites the approved spec
# (docs/roadmap/roadmap-plan-first.md): "Flow Step N", "Decision N", or "Removed".
# Usage:  sh docs/roadmap/roadmap-plan-first-gate.sh [T1|T2|T3|T4|T5]
# T5 reads a scenario trace: SCENARIO=<path> sh ... T5. Without SCENARIO it reports SKIPPED, never ok.
# Exit 0 = every selected check passed. These are text checks; they do not prove behaviour (see T5).

only="$1"; fail=0; n=0; skipped=0
R=skills/roadmap/SKILL.md
S=skills/roadmap/status-file-template.md
G=skills/implement/guides/guide-parallel-execution.md
I=skills/implement/SKILL.md
P=skills/specify/SKILL.md
PG=skills/specify/guides/guide-parallelisation.md
X="${SCENARIO:-}"

run() { # tag, description, function
  [ -n "$only" ] && [ "$only" != "$1" ] && return 0
  n=$((n+1))
  if "$3" >/dev/null 2>&1; then echo "ok   [$1] $2"; else echo "FAIL [$1] $2"; fail=1; fi
}

# ---- T1  skills/roadmap/SKILL.md  (spec: Flow Steps 0-8; Removed)
t1_steps()   { for k in 0 1 2 3 4 5 6 7 8; do grep -q "^## Step $k " "$R" || return 1; done; }      # Flow
t1_nopipe()  { ! grep -qi 'pipelin' "$R"; }                                                       # Removed
t1_short()   { [ "$(wc -l < "$R")" -lt 347 ]; }                                                   # done-when
t1_planner() { grep -qF 'read_skill specify' "$R" && grep -qF 'SPECIFY CONSUMED MODE' "$R" \
               && grep -qF 'Builds on:' "$R" && grep -qF 'target: docs/roadmap/' "$R"; }          # Flow Step 3
t1_ground()  { grep -qF 'Will touch' "$R" && grep -qF 'Needs from other areas' "$R"; }            # Flow Step 1
t1_nowidth() { ! grep -qiE 'width 1 is your call|width-1 decision|isolate when you intend' "$R"; } # Removed
t1_devi()    { grep -qF 'DEVIATION:' "$R"; }                                                      # Flow Step 5
t1_link()    { grep -qF '../implement/guides/guide-parallel-execution.md' "$R" && [ -f "$G" ]; }  # regression
t1_front()   { [ "$(git show main:"$R" | sed -n 1,4p)" = "$(sed -n 1,4p "$R")" ]; }                # regression
run T1 "Steps 0-8 headings"                       t1_steps
run T1 "no pipelining text"                       t1_nopipe
run T1 "shorter than 347 lines"                   t1_short
run T1 "literal planner dispatch template"        t1_planner
run T1 "grounding contract: Will touch / Needs"   t1_ground
run T1 "no width-1 worktree decision"             t1_nowidth
run T1 "DEVIATION rule"                           t1_devi
run T1 "wave-protocol link resolves"              t1_link
run T1 "front-matter unchanged (regression)"      t1_front

# ---- T2  status template, READMEs, entry skills  (spec: Flow Step 2, Step 7, Decision 7)
t2_blocked() { grep -qF '`blocked`' "$S"; }                                                       # Flow Step 7
t2_nostep4() { ! grep -qF "roadmap's Step 4" "$S"; }                                              # renumbering
t2_nopipe()  { ! grep -qi 'pipelin' "$S"; }                                                       # Removed
t2_nowidth() { ! grep -qF 'width 1 is a decision' "$S"; }                                         # Removed
t2_readme()  { ! grep -qF 'commits each task by pathspec' README.md; }                            # Decision 7
t2_entry()   { ! grep -qF 'Step 0 entry confirmation' skills/discuss/SKILL.md skills/codebase-improvement/SKILL.md; } # renumbering
t2_diagram() { ! grep -qF '( specify → implement per task, in waves )' README.md skills/README.md; } # Flow
run T2 "status vocabulary has blocked"            t2_blocked
run T2 "no stale 'roadmap's Step 4' mapping"      t2_nostep4
run T2 "no pipelining text in template"           t2_nopipe
run T2 "no width-1 decision in template"          t2_nowidth
run T2 "README drops 'commits each task by pathspec'" t2_readme
run T2 "entry skills drop 'Step 0 entry confirmation'" t2_entry
run T2 "READMEs drop old flow diagram"            t2_diagram

# ---- T3  implement wave protocol  (spec: Decision 6; Files affected)
t3_nofull()  { ! grep -qF 'FULL suite' "$G" "$I" && ! grep -qF 'runs the **full** suite' "$I"; }   # Decision 6
t3_nojudge() { ! grep -qi 'judgement' "$G"; }                                                      # Removed
t3_nopipe()  { ! grep -qi 'pipelin' "$G" "$I"; }                                                   # Removed
t3_owntests() { grep -qF 'own test files' "$G" && grep -qF 'own test files' "$I"; }               # Decision 6
run T3 "children no longer run the full suite"    t3_nofull
run T3 "width-1 judgement removed from guide"     t3_nojudge
run T3 "no pipelining text in guide or implement" t3_nopipe
run T3 "children run their own test files"       t3_owntests

# ---- T4  specify  (spec: Flow Step 3 template; Decision 6; Files affected)
t4_builds()  { grep -qF 'Builds on:' "$P"; }                                                      # Flow Step 3
t4_nocontra(){ ! grep -qF 'must NOT commit' "$P"; }                                               # pre-existing contradiction, see plan
t4_nofull()  { ! grep -qE 'child (now )?runs the full suite|full-suite run is a genuine' "$P" "$PG"; } # Decision 6
run T4 "consumed mode accepts Builds on:"         t4_builds
run T4 "no wave-tasks-must-not-commit contradiction" t4_nocontra
run T4 "children no longer run the full suite"    t4_nofull

# ---- T5  scenario trace  (spec: Flow Steps 1, 3, 4, 5; Decision 1). Needs SCENARIO=<trace>.
if [ -z "$only" ] || [ "$only" = T5 ]; then
  if [ -z "$X" ] || [ ! -s "$X" ]; then
    echo "SKIP [T5] scenario trace not run (set SCENARIO=<trace>) — behaviour is UNTESTED"; skipped=1
  else
    t5_fan()     { grep -E '^R[0-9]+:' "$X" | grep -F 'ask*1' | grep -F 'explore*1' | grep -q 'researcher\*'; }
    t5_planall() { grep -qE 'researcher\*4 \(plan\)' "$X"; }
    t5_vet()     { grep -qE 'reviewer\*4 \(vet\)' "$X"; }
    t5_order()   { p=$(grep -nE 'researcher\*4 \(plan\)' "$X" | head -1 | cut -d: -f1); g=$(grep -nE 'general\*' "$X" | head -1 | cut -d: -f1); [ -n "$p" ] && [ -n "$g" ] && [ "$p" -lt "$g" ]; }
    t5_waves()   { grep -qE 'general\*1 \(implement\)' "$X" && grep -qE 'general\*3 \(implement\)' "$X"; }
    t5_nomix()   { ! grep -E '^R[0-9]+:' "$X" | grep 'general\*' | grep -qE 'researcher\*|reviewer\*'; }
    n=$((n+1)); run T5 "ask + baseline child + grounders in one response" t5_fan
    run T5 "all 4 tasks planned in one response"      t5_planall
    run T5 "all 4 plans vetted in one response"       t5_vet
    run T5 "planning precedes any implementer"        t5_order
    run T5 "waves: 1 then 3 implementers"             t5_waves
    run T5 "no reader alongside implementers"         t5_nomix
  fi
fi

echo "$n checks run, $skipped skipped"
exit $fail
