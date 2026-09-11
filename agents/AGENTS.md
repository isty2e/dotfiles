# AGENTS.md

<!-- BASE: Standigm/agent-commons@54e9fb9 -->

Repository-agnostic working rules for coding agents.

## General

- Use Conventional Commits for commit subjects and PR titles: `type(scope): summary`, with scope optional.
- Verify uncertain external facts against web or primary documentation.
- Avoid recursive search or enumeration from broad roots such as `$HOME` or `/`: cost may be unbounded. Search known
  workspaces, repositories, or paths with `rg`/`rg --files`; if the target is unclear, ask. A necessary broad-root
  search must state why and bound root, depth, filesystem, and exclusions.
- State assumptions. Proceed only when they are bounded and reversible; otherwise apply `Confirmation Policy`.
- Treat uncertainty, failure, and underperformance as evidence, not automatic rejection. Before closing a path,
  distinguish demonstrated harm or impossibility from limits of the method, implementation, conditions, representation,
  or evidence; ask what could make it work or make the next attempt informative.
  - Research and exploration: prefer information gain over predictable success; limit negative conclusions to tested
    conditions; give no incumbent method an evidential advantage.
  - Hard gates govern only their decision, such as deployment, adoption, or a public claim. They stop exploration only
    for concrete material risk or an exceeded explicit budget.

## Scope and source discipline

- Before fixing scope, scan canonical identity, external contracts, persistent lifecycle, authority, and failure or
  recovery semantics. Route findings under `Skill Routing and Conflict Resolution`; either concrete signals or a skill's
  explicit surface trigger may select it.
- A possible failure requires a plausible trigger and material impact grounded in a supported workflow, actor, scale, or
  deployment before disposition, but evidence alone does not expand the boundary.
- Separate unrelated changes and justify them independently.
- Keep one source of truth per goal, decision, state, or contract; plans, checklists, handoffs, and similar artifacts
  are derived unless designated canonical. On changes to plan, scope, decision, invariant, dependency, or acceptance
  criteria, update the source immediately and reconcile derivatives before continuing.

## Correctness and disposition

- Correctness: the coherent set of Guarantees imposed by authoritative requirements or accepted by authorized decisions,
  not every desirable, possible, or review-discovered property. Authority determines disposition; evidence informs it.
- Candidates:
  - disposition: classify each as `accept`, `reject`, `defer`, or `delegate`
  - Guarantee creation/change: authoritative imposition or authorized acceptance only
  - evidence only: findings, failures, risks, same-change tests, observed reliance, mechanisms, and documents derived
    from them cannot independently create or change Guarantee authority
  - retention: discard without material boundary effect; retain a NON-GOAL only for recurrence, expectations,
    delegation, or reopen pressure.
- Retained NON-GOAL:
  - when future review or expectations depend on it, keep one discoverable repository-owned canonical record at the
    nearest semantic surface and link likely fresh-review surfaces to it
  - mark it as `NON-GOAL` or explicit unsupported, out-of-scope, deferred, or delegated wording
  - preserve rationale, decision authority, owning contract when distinct, and applicable lifecycle metadata
  - `defer`: owner plus observable revisit/reopen condition
  - `delegate`: external owner or contract
  - final `reject`: reopen only when authority or owning contract changes or a recorded reopen condition occurs.
- Normative permission: `MAY` or `MAY NOT` defines a Guarantee over its permitted observable envelope, not a requirement
  to support every choice. Treat unselected implementation choices and unpromised capabilities as NON-GOALS only when
  worth recording; document the envelope at its owning contract surface.
- Derived constraints: keep them subordinate to accepted Guarantees and architecture decisions; re-derive when their
  source changes. Enforcement and verification cannot independently create Guarantee authority.
- Design: choose the least complex design fully enforcing the accepted correctness boundary; optimize for neither the
  smallest change nor the broadest Guarantee set.
- Disproportionate cost: if a deliberately accepted Guarantee becomes disproportionate to product value, reconsider its
  scope or classify the feature as effort-prohibitive. If the Guarantee is authoritatively imposed, reduce or decline
  the feature rather than weaken the Guarantee.

## Confirmation Policy

- Platform, system, developer, and repository approval rules override this file.
- Otherwise ask only when an unresolved choice may be destructive, irreversible, materially expensive, externally
  visible, or outside the correctness boundary, unless delegated. Scope size alone does not require confirmation.
- For non-obvious public/API/architecture choices, use `decision-alignment` or ask only when multiple viable outcomes
  remain and operator preference matters. Do not ask when requirements and evidence compel one outcome.
- Resolve ambiguity with brief, low-risk discovery first. Ask only the questions needed to resolve remaining choices
  under this policy; continue independent, already-authorized work while waiting.
- A workaround that changes granted authority, approved execution mode, or required verification needs approval unless
  that choice was already delegated. Report the blocker and proposed change instead of bypassing the constraint.
- Selected skills honor existing approval and delegated decision scope; do not re-request them. Reopen approval only for
  new material facts invalidating it or choices outside that scope. Delegation never overrides governing approval rules.

## Execution Workflow

1. If `.pre-commit-config.yaml` exists, verify the hook before code changes; run `pre-commit install` only if missing or
   stale. Neither config presence nor manual `pre-commit run` substitutes for installation.
2. Establish the goal and accepted correctness boundary; route material decisions through applicable policy.
3. Implement coherently within scope; keep the canonical source current.
4. Verify behavior and contracts with applicable targeted and repository checks.
5. Report outcome, evidence, unresolved questions, and residual risk.

## Implementation and Remediation

For non-trivial implementation and root-cause remediation:

1. Establish evidence and boundary: collect requirements, current behavior, relevant callers and consumers,
   state/lifecycle, and failure/recovery semantics; include a finding's symptom. Cited lines and failing probes trigger
   discovery but do not bound it.
2. Design: apply `invariant-driven-design` to disposition candidate properties; derive a plan only from accepted
   Guarantees, material assumptions, authority, derived constraints, enforcement, and verification.
3. Attack: first run `code-review-vector` directly, without subagents, in plan-attack mode against accepted Guarantees
   and supported paths. This mandatory first pass does not prohibit separate read-only subagent review; the parent
   validates its evidence and dispositions the resulting candidates.
4. Gate:
   - validate and disposition every finding before it changes scope
   - reset the applicable pass only for:
     - a validated accepted-Guarantee violation
     - a candidate accepted by authorized disposition
     - evidence materially changing an accepted Guarantee, assumption, authority, boundary, architecture, derived
       constraint, enforcement, or verification requirement
   - NON-GOALS do not block by themselves; review novelty does not expand the correctness boundary
   - unresolved questions block only when plausible answers materially change the accepted boundary or design
   - proceed only with no accepted Guarantee violation, blocking Unknown, or unresolved boundary-changing decision.
5. Implement and re-review: implement the accepted plan, then run a diff-anchored `code-review-vector`. Treat review
   output as candidate evidence; repeat the applicable cycle only after its disposition warrants a boundary or design
   change.
6. Follow sibling paths: return to evidence and design only when another supported path can materially establish,
   violate, bypass, or restore an accepted Guarantee; never handle that path in isolation.

## Engineering Baseline

- Prefer pure functions and local side effects unless effects simplify design or reduce resource use.
- Keep filesystem paths and I/O out of core/domain APIs. Boundary or infrastructure adapters may accept path objects;
  pass loaded domain objects or canonical values inward.
- Use descriptive names; generic roles such as handler, manager, or processor require a concrete architectural meaning.
- Normalize once at ingress; keep internals canonical and strongly typed. Avoid `Any`, vague `object`, and broad unions.
- Optimize consequential hot paths only with profiling, workload evidence, measurement, or clear complexity analysis;
  caching and batching must justify their complexity.
- Separate distinct logical blocks with blank lines.

## Python Guidelines

- For every Python creation, edit, refactor, or review, apply `python-style-contract`; complete its mechanical gate,
  structural dispositions, and repository checks before claiming completion.
- Apply `audit-code-doc-style` when its current trigger matches; it owns documentation scope, format, and audit
  procedure.
- Prefer `pathlib.Path` over raw string paths.
- Prefer `polars` over `pandas` for new code, unless the project already relies heavily on `pandas`.
- In numerical/dataframe code, prefer native array, tensor, or expression operations over Python loops and row-wise UDFs
  when clearer or cheaper.
- Keep `Tensor`/`NDArray` shapes explicit; where supported, use `jaxtyping` for shape contracts and `einops` when
  clearer than positional shape manipulation.
- For NumPy randomness, use an RNG object rather than a raw integer seed in internal APIs. Normalize supported seed
  inputs at the boundary to the existing `RandomState` or `Generator` contract; never migrate silently. Respect
  `random_state`; avoid global randomness.
- Prefer `datamol` over `rdkit` when applicable.

## Delegation

- Delegate only bounded tasks with available inputs, explicit allowed actions, and independently checkable results.
  Delegation cannot bypass the parent's workflow restrictions; additional child restrictions also apply. Escalate
  conflicting requirements to the coordinating parent, who retains correctness-boundary, Guarantee-disposition,
  integration, and completion decisions.
- Ensure each child receives explicit delegated-role context and the parent contact or result-return route at launch.
  Use runtime-provided context when it already supplies these facts; otherwise include them in the task briefing. Do not
  rely on the child inferring its role from its agent name, tools, or inherited conversation.
- Supply objective, pinned code/input snapshot including relevant uncommitted changes, contracts and NON-GOALS,
  read/write scope, granted approvals and decision scope, delegation-depth limits and re-delegation authorization
  (default none), required evidence, and escalation conditions. Do not assume children inherit conversation, skills, or
  approvals.
- Parallel writers require disjoint ownership or isolation, and integration checks in either case; otherwise delegate
  read-only. Escalate scope or shared-state conflicts and unresolved operator-owned choices to the coordinating parent
  rather than expanding the task or independently requesting new user approval.
- Re-delegate only with the original coordinator's explicit depth and scope authorization. Validate returned artifacts
  and evidence; a child's success report alone is insufficient for completion.

## Skill Routing and Conflict Resolution

- Skill loading:
  - names and descriptions support discovery only
  - on first selection in each agent context, including by another skill, load and apply the current full `SKILL.md`
    before deciding or acting; names, memory, and summaries are not substitutes
  - reuse the loaded body on repeat routes; reload and apply it when a revision change is observed (for example, an
    update notification or changed version/hash) or the full body leaves context; this adds no per-route polling duty
  - apply every selected skill that owns a distinct material decision
  - deduplicate only audits answering the same question from the same evidence; preserve orthogonal reviews.
- Result reuse:
  - a route names a decision owner, not an unconditional workflow restart
  - inspect the result and evidence; reuse only while its decision, scope, governing rules, inputs, and supporting
    evidence remain applicable; uncertainty requires revalidation
  - changes reopen affected decisions and dependent results, not unrelated valid work
  - preserve mandatory phases and distinct checks: never skip a required first pass, substitute plan review for diff
    review, or weaken a stronger gate
  - use `verification-before-completion` for command-evidence validity and delegated-work completion.
- Default to `invariant-driven-design` for non-trivial engineering or product behavior, design or refactoring,
  public/API contracts, domain models or ontologies, lifecycle or persistence, operational risk, cross-component
  ownership, or material compatibility. It does not default on for exploratory research unless the work selects an
  implementation, operationalizes a method, makes a public claim, or sets an adoption or deployment boundary.
- Opt out only for a simple or throwaway script, non-production tooling, mechanical or documentation-only work, or an
  isolated routine fix without a material correctness boundary. State the assumption briefly; keep the skill active when
  the boundary is ambiguous. Apply it proportionally without needless ledger or design ceremony.
- When relevant, use this confinement pipeline; each phase constrains the next:
  1. Semantics: active `invariant-driven-design` and `ontology-hardening` establish candidate properties, typed
     partitions, canonical boundaries, and accepted Guarantee semantics.
  2. Authority/ownership: `model-responsibility-audit`, `operational-invariant-audit`, and `degradation-contract-audit`
     assign behavior, lifecycle, and result-validity ownership.
  3. Representation: `contract-representation-audit` selects or audits canonical contract-local forms from supplied
     obligations and owners.
  4. Architecture/structure: `engineering-style-contract` assembles supplied-owner containment, public/internal graph,
     abstractions, and architecture-level dependencies; `package-taxonomy` projects that assembly into package, file,
     and test placement.
  5. Leaning: minimize accidental complexity within the correctness boundary, not diff size or churn. Apply obvious
     local cuts; use `lean-prune-review` for material diff cuts, explicit `lean-prune-scan` for repo-wide audits, and
     `lean-ontology` to decide whether a cut affects an accepted Guarantee or still-valid derived constraint enforced by
     an established artifact. Unclear semantics -> `invariant-driven-design` or `ontology-hardening`; unclear contract
     representation -> `contract-representation-audit`; unclear architecture assembly -> `engineering-style-contract`.
     Implement accepted cuts through the normal workflow.
- Direct routes:
  - scattered, competing, or bypassable interpretation of one accepted contract -> `contract-representation-audit`
  - unclear helper/service/free-function ownership -> `model-responsibility-audit`, especially for behavior interpreting
    one model's facts
  - downstream-visible changes to fields, ids, ordering, errors, CLI/file output, serialization, or compatibility ->
    `compatibility-audit` before a safety claim
  - diff size never lowers verification; `verification-before-completion` is the final evidence gate.
- If two active skills still conflict, prefer the lower-interruption path and state assumptions explicitly.

<!-- PERSONAL_START -->

## Personal Preferences

### Collaboration

- Do not agree reflexively. When evidence or material tradeoffs support a different course, challenge the premise or
  proposal directly, explain why, and offer a concrete alternative. After an authorized decision, proceed without
  relitigating it unless new evidence changes the case.

### Scope

- Within the accepted correctness boundary, scope and solve by root cause, accepted Guarantees, still-valid derived
  constraints, compatibility, and operational risk, not by a `minimal`, `simplest`, or smallest change.

### Execution

- Do not test documentation by asserting that it contains specific prose, or API surfaces by asserting symbol
  presence/absence. Test behavior and contracts through executable examples, imports/calls, type/interface checks, or
  generated artifacts. If literal output is itself a contract, test its producer, not its documentation.
- While subagents run, remain responsive to the user and continue independent work; do not block solely to wait for
  them.

### Public GitHub

- For issue, PR, and comment bodies, write brief, technical, dry prose without losing material detail; after factual and
  contract checks, load and apply `humanizer` against that target style.
- Keep public GitHub claims, evidence, and references supportable from the public repository. Never expose local-only
  paths, file names or contents, personal tracker IDs, or other non-public context.
- Omit routine mechanical verification reports such as Ruff or Pyrefly results. Include verification only when it adds
  behavioral evidence, such as a non-obvious edge-case experiment.

### Pi Coding Agent

- In the Pi coding agent, `fetch_content(mode: "answer")` must use
  `answerModel: "openai-codex/gpt-5.6-luna"` without a thinking suffix.
- When running `code-review-vector` with Pi subagents, load and apply `pi-subagent-review-process`; follow its full
  Procedure exactly rather than substituting an ad hoc fanout.

<!-- PERSONAL_END -->

<!-- KATA_START -->

## Task Management — Kata

Use [Kata](https://www.katatracker.com/) for multi-step work, follow-ups, blockers, and completion tracking; do not
maintain competing persistent task lists.

Before substantive work, load and apply `kata-task-management` to find or create the owning issue and initialize the
workspace when needed. Brief scoping exploration and simple questions/lookups do not require registration.

<!-- KATA_END -->

<!-- WORKSPACE_SEARCH_START -->

## Workspace Search

Use workspace evidence for local questions, relevant prior context, or current-project behavior, even without an explicit
workspace mention. Search code, documents, configuration, and data as needed, not for unrelated external questions.

### Choose A Tool

- Exact strings/regex, exhaustive occurrences, counts, or file lists: `rg`/`rg --files`; no index needed.
- Unknown wording/location, behavior, rationale, constraints, or relationships/synthesis across code, docs, and tests:
  `zg query`.
- Known symbols, their implementation, callers/callees, connected code, or change impact: CodeGraph.

These are starting points, not exclusive roles. Combine concepts and known anchors in queries; use another tool only
when it supplies missing evidence, not routinely to run both. Search before broad reads or delegated discovery; never
delegate solely to locate material.

### Prepare The Selected Index

Initialize only the selected tool when needed, not both routinely. Keep indexing within the known workspace/repository.

Select by tool and index state; these are alternatives, not a sequence.

- New `zg` index: `zg index /absolute/workspace --mode direct --embedding <local-model>`.
- Existing `zg` index after relevant changes: `zg index /absolute/workspace --mode direct`.
- New CodeGraph index: `codegraph init /absolute/repository`.
- Existing CodeGraph index after relevant changes: `codegraph sync /absolute/repository`.

Existing `zg` indexes reuse their stored model. Starting points for new indexes:

- Code: `local/potion-code-16m-v2`.
- English documents: `local/potion-retrieval-32m`.
- Multilingual documents: `local/potion-multilingual-128m`.

Start small with adequate language and fragment-length coverage; these are not quality rankings. If representative
queries underperform or index status shows excessive truncation, consult `zg help models` and compare alternatives:
`local/jina-embeddings-v2-base-code` for long-context code, `local/embeddinggemma-300m` for mixed multilingual code/docs.
Changing models requires rebuilding even at equal dimensions. Remote embeddings require authorization to send content,
not merely credentials.

Create/refresh/rebuild useful indexes without asking; dropping without rebuilding requires explicit approval. Put
repository-local index artifacts in `.git/info/exclude`, not `.gitignore`.

### Search And Use Results

Run from the intended absolute workspace directory; use installed command help for options.

Select by current evidence need; these are alternatives, not a sequence.

- Semantic, behavior, or document discovery: `zg query "question" --mode direct --preview full --limit 3`.
- Related implementation and call paths: `codegraph explore "symbol or question" --max-files 3`.
- A specific symbol or file: `codegraph node <symbol-or-file>`.
- Change impact: `codegraph impact <symbol>`.

- Use `--mode direct` for all `zg` query/index/status calls. Queries do not refresh by default; refresh after relevant
  changes as above, or query with `--refresh wait`.
- For implementation-focused `zg` searches, add `--prefer-symbol -g 'src/**'`; adjust paths to the repository.
- Bound output before expanding. Treat sufficient source snippets as read; open files only for missing details and stop
  when evidence suffices. Previews may omit context. If a tool is unavailable, stale, or outside indexed scope, use another
  suitable source; `rg` may suffice without an index.

<!-- WORKSPACE_SEARCH_END -->
