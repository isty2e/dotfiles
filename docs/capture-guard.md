# Non-interactive capture guard

The source includes the command and policy below. Real-home adoption is separate:
review and apply the configuration before using the
[guarded editing workflow](manifest-management.md).

## Responsibility

`dotfiles-capture` will collect eligible local configuration edits
without asking about every file. It must not overwrite a changed desired source
merely because the live file differs. It will leave ambiguous cases for an
explicit decision, not merge them or infer intent from Git cleanliness.

The guard owns selection, comparison and reporting. Chezmoi continues to own
source naming, target rendering, permissions, capture writes and recorded state.
The guard has no baseline database, backup store, automatic Git operations,
installer or background watcher.

## Command and declaration

```sh
dotfiles-capture --check
dotfiles-capture
dotfiles-capture ~/.zshrc ~/.config/zed
```

`--check` performs preflight only. It does not call `re-add --dry-run` or update
recorded state. Positional paths narrow the configured selection; they cannot
enroll unmanaged files or expand the policy. Relative paths refer to chezmoi's
destination, not the caller's working directory. Paths select an exact target
or its managed descendants; there is no glob or shell expansion inside the tool.

The declaration belongs in `home/.chezmoidata.toml`:

```toml
[capture]
paths = ["."]
```

`.` selects all eligible managed files. A narrower list can use destination-relative
paths such as `.zshrc`, `.config/mise/config.toml` or `.config/zed`. This is an
automatic-capture policy, not another inventory: chezmoi still determines which
files are managed. The policy is source-side control data, like `.chezmoiignore`,
not a copied application setting. Native data resolution owns any machine-local
override. Missing or malformed policy stops the command without capture.
`paths` is the only supported policy key; unknown keys are rejected.
`paths` must be nonempty. An explicit selector that matches no eligible managed
target is an error, never a fallback to the whole home directory.

Automatic scope is ordinary copied files, including executable, private, empty
and read-only file attributes. Templates, encrypted files, external entries,
symlink recipes, create-once files, modify scripts and removal actions stay with
their native/manual workflows. Report exclusions; an explicit request for an
excluded or unmanaged target is an error. A missing, unreadable or non-regular
live/source file in the eligible set blocks capture rather than propagating a
deletion or following a final symlink.

## One canonical file state

Compare this tuple, matching native file semantics:

```text
FileState = (regular-file kind, POSIX rwx permission bits, SHA-256 of exact bytes)
```

Modification times and inode identities detect observations changing during
preflight; they do not determine which version is newer. Do not parse JSON/TOML
contents or normalize whitespace, line endings or Unicode content.

For each target, obtain:

| Value | Owner and acquisition |
| --- | --- |
| Recorded state | Native `state get-bucket --bucket=entryState --format=json` |
| Desired state | Native target archive: exact member bytes and permissions |
| Live state | Read the mapped live regular file; hash its bytes and inspect its permissions |

Chezmoi's JSON inventory maps a target-relative name to `absolute`,
`sourceAbsolute` and `sourceRelative`. Use its absolute spelling to look up the
recorded entry. Do not call `realpath` and substitute another state key: two
spellings of one directory can have different native records. Missing records
must not be recovered by guessing another alias or using Git HEAD as a baseline.

The native adapter validates file kind, numeric mode and a 32-byte digest before
constructing `FileState`. Directory, script, remove and symlink records are not
file baselines. An omitted file mode has native value zero; a missing or invalid
content digest is not a valid baseline. Compare the native rwx bits, not ownership,
ACLs or extended attributes; those are outside this capture contract.

## Decision table

Validate source/live kinds and baseline availability before treating equal bytes
as a no-op.

| Condition | Decision |
| --- | --- |
| Baseline absent or not an admitted file state | Block: first apply/adoption is required |
| Desired source differs from baseline, live is unchanged | Block: source update has not been applied |
| Desired and live both differ from baseline and from each other | Block: reconcile the two versions |
| Desired and live match, but baseline is older | Block: native apply must acknowledge the matching state |
| Desired, live and baseline match | Unchanged |
| Desired equals baseline, live differs in bytes or permissions | Capture |

The matching-but-unrecorded case is intentionally strict. A no-op native apply
records a baseline, while a no-op `re-add` does not establish one. The guard must
not initialize or repair native records itself.

Classify the whole selected set first. If any eligible file is blocked, do not
start capture for the other files. Unrelated dirty Git files do not block an
otherwise valid collection; this is a per-target comparison, not a clean-tree
requirement.

The pure decision function accepts only the three normalized file states, with
an optional recorded state. It returns `UNCHANGED`, `CAPTURE`, `NEEDS_APPLY` or
`SOURCE_CHANGED`; it does no path lookup, subprocess work or state repair.
Selection and native decoding failures are preflight errors, not missing file
states passed into that function.

## Native adapter and execution

Resolve one real chezmoi executable and retain the same invocation environment
and working directory for all queries. Read its effective configuration rather
than inferring a source checkout from the current directory. Check copy mode,
source/destination roots, umask, Git automation and mutation hooks.
The full effective configuration dump is retained and compared, including umask;
the guard does not keep a separate history of the umask used by earlier applies.
Desired permissions use the current effective umask. If it differs from the one
used for the recorded apply, `SOURCE_CHANGED` can mean a desired-output permission
change even when source bytes are untouched. Review effective settings as well
as source edits; the diagnostic is not proof that a repository file was edited.

The initial compatibility target is chezmoi **2.73.3**. A version outside the
adapter's tested set, an unknown data shape or an inconsistent mapping blocks
capture. Add versions through the native compatibility tests, not a force flag
or a runtime download. This is an explicit maintenance cost of reading native
recorded state; no separate state format is introduced to avoid it. Bootstrap
still installs the latest release when chezmoi is missing and reuses an existing
provider; there is no automatic Homebrew pin or downgrade. Upgrades can therefore
temporarily disable capture. The explicit-target
[manual capture fallback](manifest-management.md#capture-local-edits) remains
available after review.

When admitting a new version, update the supported set, native-test version
selection and CI's installer tag in the same change. Run the native compatibility
cases without skips; changing the CI tag alone does not validate a version that
the fixture still skips. Do not widen the supported set without those results.

Read only the capture policy through a fixed native template expression, and
obtain the eligible mapping with:

```sh
chezmoi execute-template '{{ .capture | toJson }}'
chezmoi managed --include=files --exclude=externals,encrypted,templates --path-style=all --format=json
```

Exclude `create_` and `modify_` recipes using the native grammar's leading type
prefix, before requesting desired contents. Do not infer their kind from output
bytes or build a general source-name transformer. Native filters own template,
encryption and external classification, including literal-name handling.

Request desired contents with `archive --format=tar --recursive=false`, passing
the exact eligible absolute file targets and the native subtype exclusions.
Do not pass directories or use archive's `--include` in the 2.73.3 adapter. Read
tar members in memory without extracting them. Require exactly one regular member
per requested target; reject duplicate, unexpected or escaping member names.
This preserves binary bytes as well as text, unlike hashing JSON string output.

Execution has five stages:

1. Resolve context, policy and native mappings; reject unknown or excluded
   explicit targets. Reject enabled native `git.autoadd`, `git.autocommit` or
   `git.autopush`, and configured `re-add` mutation hooks.
2. Read all baselines, desired states, live states and source-file observations.
   Classify all eligible files. On a block, report paths/reasons and exit.
3. Re-read the effective selection/context and relevant states immediately before
   capture. If inputs, bindings or observed files changed, stop without calling
   `re-add`. Reject hardlinked sources even when only one target is selected,
   and reject duplicate observed source identities rather than guessing an owner.
4. Invoke native `re-add` **only with the Capture target list**, using argument
   arrays, non-recursive operation and interactive prompting disabled. Never
   invoke unrestricted `re-add`, `apply`, `update`, `add` or Git from this phase.
   If the list is empty, return success without invoking `re-add` at all: an
   empty native target list means unrestricted capture, not a no-op.
5. Re-read native state and mappings. A successful capture must leave baseline,
   desired and live states equal for each captured target. Permission capture can
   rename the source entry, so refresh its native binding instead of retaining
   the former source filename.

The capture invocation uses `--exclude=externals,encrypted,templates`, `--recursive=false`,
`--interactive=false`, `--keep-going=false` and `--no-tty`, followed by `--` and
the exact absolute targets. There is no pass-through force or initialization flag.
Native subprocesses read stdin from `/dev/null` as well as using `--no-tty`;
caller input is not forwarded through the guard.
Do not override `re-add`'s include set: native permission-driven source renaming
needs its removal actions to clean up the former source filename. Eligibility is
enforced by preflight and the exact, non-recursive target list instead.

Do not print file contents, archive data, hashes or raw subprocess output. Print
escaped target paths, decisions and native exit status. A query failure is not an
empty inventory. The existing source and native queries remain trusted inputs:
this guard is not a sandbox for custom chezmoi hooks, data generators or binaries.

## Failure and recovery

| Exit | Meaning |
| --- | --- |
| `0` | All selected files were unchanged, or capture and post-check succeeded |
| `2` | Invalid request, unsupported context, failed query or preflight block; no capture attempted |
| `1` | Native capture or post-check failed; source/state may be partly changed |

On a capture failure, report that partial changes are possible. Do not retry,
roll back source files, clear native records or continue automatically. Inspect
the source diff, reconcile it, then run a new preflight. An explicit native apply
can re-establish a stale baseline after review; the guard cannot do that silently.

## Limits

- Prevents direction mistakes for stable observed inputs, not malicious activity
  or every possible concurrent write. Do not save selected files or modify their
  source, policy or chezmoi configuration while capture runs, or run another
  chezmoi/Git writer at the same time. Rechecks and post-checks detect many changes but do
  not close the gap before a native write.
- A native multi-file capture is not atomic. Validation-before-write does not
  turn later I/O failures into all-or-nothing behavior.
- Does not protect a later `apply` of an older revision. Save captured edits in
  Git before changing revisions. Native apply conflict options and private
  backups are separate protections.
- Does not detect secrets in an otherwise legitimate local edit. The
  [Gitleaks commit check](../setup.md#commit-checks) is separate and bypassable.
- Does not intercept direct native commands or other editors/Git operations.
  Using this command is the scope of the guard, not a system-wide safety boundary.

## Why a command, not a pre-hook?

Use one explicit capture entry point in v1. Native pre-hooks can query recorded
state in the tested configuration, but `CHEZMOI_ARGS` is not a structured argv
interface and does not reliably preserve boundaries for paths containing spaces.
Parsing it would add another interpretation of native invocation and selection.
Checking every file regardless of the caller's requested subset would instead
block unrelated work. Revisit a hook if chezmoi exposes structured arguments or
the selected target set; its existence alone is not enough to choose it.

## Implementation and acceptance

- `home/dot_local/bin/executable_dotfiles_capture.py`: one Python 3.9+ stdlib-only
  implementation, with the native `symlink_dotfiles-capture` command alias beside
  it. The `.py` file supports direct imports and normal Python tooling; the alias
  stays inside the installed binary directory, not linked to the source checkout.
  This needs no new global Python provider and installs no interpreter. Linux may
  use an existing compatible Python, including its Pixi environment.
- `home/.chezmoidata.toml`: policy only, resolved by chezmoi rather than a second
  TOML parser in the executable.
- Native ignore rules exclude Python bytecode caches; importing the source for
  tests must not turn generated bytecode into deployed or captured configuration.
- `tests/capture/`: pure comparison tests and optional native integration tests.
  Keep CLI/native I/O apart from canonical file-state values and the pure decision function within
  the executable; do not create a generic synchronization package.

Selection, native adaptation, comparison, execution and failure reporting are
tested together. Source-only delivery and real-home adoption remain separate.
Native baseline coverage includes:

1. Live-only edits, source-only edits, both-side edits, missing/stale baselines,
   and matching-but-unrecorded files. Include committed and uncommitted source
   changes without relying on Git as the oracle.
2. No-op apply, partial apply, `edit --apply` and no-op re-add record behavior.
3. Permission-only capture and native source renaming; unchanged data/state for
   a blocked batch and for `--check`; no native capture invocation for an empty plan.
4. Binary bytes, Unicode/space/newline paths, alternate destination spellings,
   missing files, final symlinks, unreadable files and source type changes.
5. Policy narrowing, unmanaged/unsupported targets, literal names, generators,
   template/encrypted/external exclusion and malformed native data.
6. Input changes between observations, partial native failure and failed
   post-checks. Assert preserved contents and explicit failure, not incidental
   third-party error wording or documentation text.
7. Native Git automation/hook rejection, unavailable tools, and compatible-version
   decoding. Pure tests run without chezmoi; native tests skip when absent.

Primary references: native [recorded state](https://github.com/twpayne/chezmoi/blob/v2.73.3/internal/chezmoi/entrystate.go),
[inventory filters](https://github.com/twpayne/chezmoi/blob/v2.73.3/internal/chezmoi/entrytypeset.go),
[source attributes](https://github.com/twpayne/chezmoi/blob/v2.73.3/internal/chezmoi/attr.go),
[archive implementation](https://github.com/twpayne/chezmoi/blob/v2.73.3/internal/cmd/archivecmd.go)
and [hook interface](https://www.chezmoi.io/reference/configuration-file/hooks/).
