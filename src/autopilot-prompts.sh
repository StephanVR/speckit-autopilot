#!/usr/bin/env bash
# autopilot-prompts.sh — Phase-specific prompt templates for claude -p invocations.
# Each function outputs a self-contained prompt string.
# Language-agnostic: all project-specific conventions are read from CLAUDE.md.

set -euo pipefail

# ─── Shared preamble ────────────────────────────────────────────────────────

_preamble() {
    local epic_num="$1" title="$2" repo_root="$3"
    cat <<PREAMBLE
IMPORTANT: Read .specify/memory/constitution.md and .specify/memory/architecture.md FIRST.
Internalize all principles, prohibitions, and current architecture. They are non-negotiable.

You are working on epic ${epic_num}: "${title}".
Working directory: ${repo_root}
PREAMBLE
}

# ─── Phase: Specify ─────────────────────────────────────────────────────────

prompt_specify() {
    local epic_num="$1" title="$2" epic_file="$3" repo_root="$4"
    cat <<EOF
$(_preamble "$epic_num" "$title" "$repo_root")

Read the epic file at ${epic_file} — extract ALL functional requirements and context.

Then invoke the Skill tool exactly once:
  skill = "speckit.specify"
  args  = the full epic description and functional requirements from the epic file

If the skill asks clarification questions, answer them AUTONOMOUSLY:
- Cross-reference with the epic requirements and constitution principles
- Always choose the option most aligned with the constitution
- Provide a brief one-line rationale for each choice
- Never ask the user — decide based on the available context

After the skill completes, verify that spec.md was created in the specs/ directory.
EOF
}

# ─── Phase: Clarify ─────────────────────────────────────────────────────────

prompt_clarify() {
    local epic_num="$1" title="$2" epic_file="$3" repo_root="$4" spec_dir="$5"
    local spec_dir_name
    spec_dir_name="$(basename "$spec_dir")"
    cat <<EOF
$(_preamble "$epic_num" "$title" "$repo_root")

Read the epic file at ${epic_file} for reference context, then read ${spec_dir}/spec.md.

Invoke the Skill tool ONCE:
  skill = "speckit.clarify"
  args  = "as a senior developer"

When the skill asks questions, answer AUTONOMOUSLY:
- Cross-reference with the epic file requirements and constitution
- Choose the option most aligned with constitution principles
- If equally valid, prefer the simpler approach (Constitution Principle VI)
- Provide a brief rationale for each answer

After the skill completes, carefully check the observations/findings reported:

If ZERO observations (the skill reports no issues or underspecified areas):
  1. Append this exact marker at the END of spec.md on its own line:
     <!-- CLARIFY_COMPLETE -->
  2. Commit:
     git add specs/${spec_dir_name}/
     git commit -m "docs(${epic_num}): clarify complete — zero observations"

If observations WERE found (the skill reported issues, questions, or underspecified areas):
  1. Ensure all fixes and answers have been applied to spec.md
  2. Do NOT add <!-- CLARIFY_COMPLETE -->
  3. Commit fixes:
     git add specs/${spec_dir_name}/
     git commit -m "fix(${epic_num}): resolve clarify observations"

The orchestrator will re-run /speckit.clarify in a fresh context until zero observations
are reported, up to a maximum of 5 rounds.
EOF
}

# ─── Phase: Clarify-Verify (fresh-context independent verification) ─────────

prompt_clarify_verify() {
    local epic_num="$1" title="$2" repo_root="$3" spec_dir="$4"
    local spec_dir_name
    spec_dir_name="$(basename "$spec_dir")"
    cat <<EOF
$(_preamble "$epic_num" "$title" "$repo_root")

The clarify phase has marked spec.md as complete. Your job is to INDEPENDENTLY
verify the spec quality in a fresh context — without invoking any speckit skills.

Read ${spec_dir}/spec.md carefully. Check for:
- Underspecified requirements (vague terms like "should handle", "as needed", "etc.")
- Missing acceptance criteria for user stories
- Ambiguous success metrics
- Undefined error handling behaviour
- Missing edge cases for key requirements
- Requirements that conflict with .specify/memory/constitution.md principles

If the spec is COMPREHENSIVE (zero significant issues found):
  1. Append this exact marker at the END of spec.md on its own line:
     <!-- CLARIFY_VERIFIED -->
  2. Commit:
     git add specs/${spec_dir_name}/
     git commit -m "docs(${epic_num}): clarify verified — spec is comprehensive"

If SIGNIFICANT issues are found:
  1. Remove the <!-- CLARIFY_COMPLETE --> marker from spec.md
  2. Add a comment block at the end of spec.md listing the issues found:
     <!-- VERIFY_FINDINGS: issue1; issue2; issue3 -->
  3. Commit:
     git add specs/${spec_dir_name}/
     git commit -m "fix(${epic_num}): clarify-verify found issues — returning to clarify"

The orchestrator will loop back to the clarify phase if you remove the marker.
Minor style or formatting issues do NOT count — only report substantive gaps.
EOF
}

# ─── Phase: Plan ─────────────────────────────────────────────────────────────

prompt_plan() {
    local epic_num="$1" title="$2" repo_root="$3"
    cat <<EOF
$(_preamble "$epic_num" "$title" "$repo_root")

Invoke the Skill tool:
  skill = "speckit.plan"

The skill will read the spec and generate design artifacts (plan.md, research.md, data-model.md, contracts/, quickstart.md).

After the skill completes, verify that plan.md was created.

Then perform a senior developer critique of the plan:
- Check for constitution violations
- Check task ordering and dependency issues
- Check for missing test coverage
- Check file size / complexity concerns (per CLAUDE.md conventions)
Apply any fixes directly to the artifacts.
EOF
}

# ─── Phase: Tasks ────────────────────────────────────────────────────────────

prompt_tasks() {
    local epic_num="$1" title="$2" repo_root="$3"
    cat <<EOF
$(_preamble "$epic_num" "$title" "$repo_root")

Invoke the Skill tool:
  skill = "speckit.tasks"

The skill will read the plan and spec to generate tasks.md with dependency-ordered, phased tasks.

After the skill completes, verify that tasks.md was created and contains Phase headers and task checkboxes.
EOF
}

# ─── Phase: Analyze (fix mode) ─────────────────────────────────────────────

prompt_analyze() {
    local epic_num="$1" title="$2" repo_root="$3" spec_dir="$4"
    local spec_dir_name
    spec_dir_name="$(basename "$spec_dir")"
    cat <<EOF
$(_preamble "$epic_num" "$title" "$repo_root")

Invoke the Skill tool ONCE:
  skill = "speckit.analyze"
  args  = "as a senior developer"

Review the analysis report carefully.

If ZERO issues are found (no CRITICAL, HIGH, MEDIUM, or LOW findings):
  1. Append this exact marker at the END of tasks.md on its own line:
     <!-- ANALYZED -->
  2. Commit:
     git add specs/${spec_dir_name}/
     git commit -m "docs(${epic_num}): spec artifacts ready for implementation"

If ANY issues are found:
  1. Fix ALL issues in the artifacts (spec.md, plan.md, tasks.md) directly
  2. Do NOT add <!-- ANALYZED -->
  3. Commit fixes:
     git add specs/${spec_dir_name}/
     git commit -m "fix(${epic_num}): resolve analysis findings"

The orchestrator will re-run /speckit.analyze in a fresh context until zero issues
are reported, up to a maximum of 5 rounds.
EOF
}

# ─── Phase: Analyze-Verify (fresh-context verification) ───────────────────

prompt_analyze_verify() {
    local epic_num="$1" title="$2" repo_root="$3" spec_dir="$4"
    local spec_dir_name
    spec_dir_name="$(basename "$spec_dir")"
    cat <<EOF
$(_preamble "$epic_num" "$title" "$repo_root")

Previous analysis found issues which were fixed.
Run /speckit.analyze ONCE to verify the fixes.

Invoke the Skill tool ONCE:
  skill = "speckit.analyze"
  args  = "as a senior developer"

If ANY issues remain:
  1. Remove the <!-- FIXES APPLIED --> line from tasks.md
  2. Commit:
     git add specs/${spec_dir_name}/
     git commit -m "fix(${epic_num}): reset analyze state — issues remain"
  The orchestrator will loop back to full analyze in a fresh context.

If zero issues:
  1. Replace <!-- FIXES APPLIED --> with <!-- ANALYZED --> in tasks.md
  2. Commit:
     git add specs/${spec_dir_name}/
     git commit -m "docs(${epic_num}): spec artifacts ready for implementation"
EOF
}

# ─── Phase: Implement (via /speckit.implement with subagent parallelism) ────

prompt_implement() {
    local epic_num="$1" title="$2" repo_root="$3" spec_dir="$4"
    cat <<EOF
$(_preamble "$epic_num" "$title" "$repo_root")

Read ALL design artifacts in ${spec_dir}/ to understand the full scope.
Also read CLAUDE.md for project conventions, reusable utilities, and patterns.

When launching Task subagents for parallel [P] tasks, include this instruction
in each subagent prompt:
  "Before writing code, read .specify/memory/architecture.md for module
  dependencies and CLAUDE.md for reusable utilities and patterns."

MCP tools available in this phase:
- Svelte: use mcp__svelte__* and mcp__plugin_svelte_svelte__* tools for docs lookup and code validation
- Pencil: use mcp__pencil__* tools for reading/writing .pen design files
- Playwright: use mcp__plugin_playwright_playwright__* tools for browser testing
Use the svelte-autofixer on every .svelte file you create or edit.
Use Pencil tools when working with .pen design files (never use Read/Grep on .pen files).

Then invoke the Skill tool:
  skill = "speckit.implement"
  args  = "all tasks using subagents for parallel [P] tasks"

The skill will:
- Read tasks.md and identify phases, dependencies, and [P] markers
- Dispatch independent [P] tasks as parallel subagents via the Task tool
- Execute sequential tasks in dependency order
- Follow strict TDD for each task (test first, implement, verify)
- Mark each task [x] in tasks.md after completion
- Commit after each task or logical group

After the skill completes, verify:
$(if [[ -n "$PROJECT_TEST_CMD" ]]; then echo "  cd ${repo_root}/${PROJECT_WORK_DIR} && ${PROJECT_TEST_CMD}"; fi)
$(if [[ -n "$PROJECT_LINT_CMD" ]]; then echo "  cd ${repo_root}/${PROJECT_WORK_DIR} && ${PROJECT_LINT_CMD}"; fi)
EOF
}

# ─── Phase: Review ───────────────────────────────────────────────────────────

prompt_review() {
    local epic_num="$1" title="$2" repo_root="$3" short_name="$4"
    cat <<EOF
$(_preamble "$epic_num" "$title" "$repo_root")

All implementation tasks are complete. Perform a senior code review.

1. List all changed files vs ${BASE_BRANCH}:
   git diff --name-only ${BASE_BRANCH}..HEAD

2. Read EVERY changed file. Check for:
   - Constitution compliance (all principles, all prohibitions)
   - Code style and lint compliance (per CLAUDE.md conventions)
   - Test quality (real assertions, no test theatre, edge cases covered)
   - File size limits and complexity thresholds (per CLAUDE.md)
   - Language-specific best practices (per CLAUDE.md)
   - Error handling (graceful degradation per constitution principles)
   - Observability (structured logging per constitution principles)
   - No hardcoded paths or credentials
   - No print() / console.log debug output (use proper logging)

3. Fix any issues found. Commit fixes:
   git add <specific files>
   git commit -m "fix(${epic_num}): code review — <what was fixed>"

4. Final validation:
$(if [[ -n "$PROJECT_TEST_CMD" ]]; then echo "   cd ${repo_root}/${PROJECT_WORK_DIR} && ${PROJECT_TEST_CMD}"; fi)
$(if [[ -n "$PROJECT_LINT_CMD" ]]; then echo "   cd ${repo_root}/${PROJECT_WORK_DIR} && ${PROJECT_LINT_CMD}"; fi)

5. If any issues remain, fix and commit again.

6. Commit ALL remaining changes (ensure clean working tree for merge):
   git status
   git add <all modified/new files relevant to this epic>
   git commit -m "feat(${epic_num}): final review changes" || echo "Nothing to commit"
   Verify: git status shows a CLEAN working tree with no uncommitted changes.

7. Report final summary:
   - Files changed (count)
   - Tests passing (count)
   - Lint status
   - Any remaining concerns
EOF
}

# ─── Phase: Crystallize (post-merge context update) ─────────────────────────

prompt_crystallize() {
    local epic_num="$1" title="$2" repo_root="$3" short_name="$4"
    cat <<EOF
$(_preamble "$epic_num" "$title" "$repo_root")

You just merged epic ${epic_num} ("${title}") to ${BASE_BRANCH}. Your job is to update
the project's compressed context files so the next epic starts with current
architectural understanding.

1. Read the merge diff to understand what changed:
   git diff HEAD~1..HEAD --stat
   git diff HEAD~1..HEAD

2. Read current context files:
   - CLAUDE.md (look at content between <!-- MANUAL ADDITIONS START --> and <!-- MANUAL ADDITIONS END -->)
   - .specify/memory/architecture.md (if it exists)

3. UPDATE these files to reflect the current codebase state:

   a) CLAUDE.md — edit ONLY the content between the MANUAL ADDITIONS markers:
      - Module map: one line per source module, grouped by layer/purpose
      - Reusable utilities: function signatures that agents MUST use instead of reinventing
      - Pattern rules: conventions agents MUST follow (DB access, error handling, output, testing)
      Keep under 50 lines between the markers. Do NOT modify anything outside the markers.

   b) .specify/memory/architecture.md:
      Create or update 2-4 mermaid diagrams that give a new AI agent immediate
      understanding of this codebase. Choose diagram types appropriate to this
      project's nature. The diagrams must answer:
        - How do modules/components relate? (dependency, layering, ownership)
        - How does data/state flow through the system? (sequences, pipelines, event chains)
        - What are the key entities and their lifecycle states? (state machines, ER diagrams)
        - Where would new functionality be added? (extension points, patterns)
      Keep the file under 120 lines total. Include a brief "Extension Points" prose section.

4. Commit all changes:
   git add CLAUDE.md .specify/memory/architecture.md
   git commit -m "chore(${epic_num}): crystallize context post-merge"
EOF
}

# ─── Phase: Finalize Fix (fix test/lint failures on base branch) ──────────

prompt_finalize_fix() {
    local repo_root="$1" test_output="$2" lint_output="$3"
    cat <<EOF
IMPORTANT: Read .specify/memory/constitution.md and .specify/memory/architecture.md FIRST.
Internalize all principles, prohibitions, and current architecture. They are non-negotiable.

You are on the ${BASE_BRANCH} branch. ALL epics have been merged. The full test suite or
linter is failing. Your ONLY job is to fix these failures.

Working directory: ${repo_root}

TEST FAILURES:
\`\`\`
${test_output}
\`\`\`

LINT ISSUES:
\`\`\`
${lint_output}
\`\`\`

Instructions:
1. Read the failing test output carefully. Identify root causes.
2. Read the relevant source files and test files.
3. Fix the issues. Prioritize minimal, targeted fixes — do NOT refactor.
4. After fixing, verify:
$(if [[ -n "$PROJECT_TEST_CMD" ]]; then echo "   ${PROJECT_TEST_CMD}"; fi)
$(if [[ -n "$PROJECT_LINT_CMD" ]]; then echo "   ${PROJECT_LINT_CMD}"; fi)
5. If issues remain, fix them in a second pass.
6. Commit all fixes:
   git add <specific files>
   git commit -m "fix(finalize): resolve test/lint failures on ${BASE_BRANCH}"
7. Verify clean working tree: git status
EOF
}

# ─── Phase: Finalize Review (cross-epic integration review) ──────────────

prompt_finalize_review() {
    local repo_root="$1"
    cat <<EOF
IMPORTANT: Read .specify/memory/constitution.md and .specify/memory/architecture.md FIRST.
Internalize all principles, prohibitions, and current architecture. They are non-negotiable.

You are on the ${BASE_BRANCH} branch. ALL epics have been merged and tests/lint pass.
Perform a CROSS-EPIC integration review of the complete codebase.

Working directory: ${repo_root}

1. Read CLAUDE.md to understand module map, reusable utilities, and patterns.
2. Read .specify/memory/architecture.md for dependency/flow diagrams.
3. List all source files in the project (check CLAUDE.md for project structure).
4. Read ALL source files. Check for:
   - Cross-module API consistency (function signatures, return types, error handling)
   - Duplicate utility functions that should be consolidated
   - Import cycles or unnecessary coupling between modules
   - Dead code from earlier epics that was superseded by later ones
   - Inconsistent logging patterns across modules
   - Missing or broken module exports
   - Inconsistent data access patterns
   - Constitution compliance across the full codebase
5. Fix any issues found. Commit:
   git add <specific files>
   git commit -m "fix(finalize): cross-epic integration fixes"
6. Final validation:
$(if [[ -n "$PROJECT_TEST_CMD" ]]; then echo "   ${PROJECT_TEST_CMD}"; fi)
$(if [[ -n "$PROJECT_LINT_CMD" ]]; then echo "   ${PROJECT_LINT_CMD}"; fi)
7. If tests/lint fail after your changes, fix them immediately.
8. Update .specify/memory/architecture.md with any structural changes.
9. Update CLAUDE.md MANUAL ADDITIONS section if patterns changed.
10. Commit documentation updates:
    git add CLAUDE.md .specify/memory/architecture.md
    git commit -m "docs(finalize): update architecture after integration review"
11. Final report:
    - Issues found and fixed (count)
    - Files modified (count)
    - Any remaining concerns or technical debt
EOF
}
