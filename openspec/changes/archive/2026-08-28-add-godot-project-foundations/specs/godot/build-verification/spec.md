## Purpose

Defines the contract of the standing verification suite — what it must check, what
it must refuse to do, and how fast it must be — so that every later change has one
trustworthy command that says whether the project is sound.

## ADDED Requirements

### Requirement: The standing suite is headless and display-free

The standing suite SHALL run without a display server, so it can run over a remote
shell without a virtual framebuffer.

#### Scenario: The suite runs with no display available

- **WHEN** the standing suite is run in an environment with no display server
- **THEN** it completes and reports a pass or a fail
- **AND** it does not fail for want of a display

#### Scenario: Screen capture is excluded from the standing suite

- **WHEN** the standing suite's steps are enumerated
- **THEN** none of them captures an image or opens a window
- **AND** visual verification is available as a separate, explicitly windowed command

### Requirement: The suite refuses an untrustworthy environment

The suite SHALL fail loudly rather than run against an environment whose tool
versions are not the recorded ones.

#### Scenario: No virtual environment present

- **WHEN** the standing suite is run and the project's virtual environment is absent
- **THEN** the suite exits non-zero without running any check
- **AND** it prints the commands that create the environment

#### Scenario: Virtual environment present but incomplete

- **WHEN** the standing suite is run and the virtual environment exists but is missing a required package
- **THEN** the suite exits non-zero without running any check
- **AND** it names what is missing rather than failing later inside a check

#### Scenario: System tooling is never silently substituted

- **WHEN** the standing suite runs any tool that has a version-pinned dependency
- **THEN** it uses the project's own recorded environment
- **AND** it never falls back to a system-wide installation

### Requirement: The suite touches nothing outside itself

The suite SHALL NOT reach the network or write to any location a player's data could
occupy.

#### Scenario: No network access

- **WHEN** the standing suite runs
- **THEN** it opens no network connection

#### Scenario: A real save file is never used

- **WHEN** any check writes persistent data
- **THEN** it writes to a location supplied for testing
- **AND** a file the player would own is never read or overwritten

### Requirement: Documentation gates fail on the rot they guard

The suite SHALL include documentation checks, and each check SHALL be demonstrated to
fail when what it guards is deliberately broken — a check that has never failed is
not known to work.

#### Scenario: A broken document link is caught

- **WHEN** a relative link in a Markdown file is changed to point at a path that does not exist
- **THEN** the standing suite fails
- **AND** it names the file and the unresolvable link

#### Scenario: A stale section reference is caught

- **WHEN** a cross-reference names a section number whose title no longer matches
- **THEN** the standing suite fails
- **AND** it names the reference and the mismatch

#### Scenario: The checks cover the documents that live above the project

- **WHEN** the constraints and roadmap documents at the repository root are checked
- **THEN** they are within the checks' scope
- **AND** the checks do not pass by finding no files to examine

### Requirement: Single-source facts are asserted, not maintained by hand

Where a fact is recorded in one authoritative place and restated elsewhere — the
engine version, the design document's tuning constants — the suite SHALL verify
the restatements against the source rather than trusting them to stay in step.

#### Scenario: A restated fact that has drifted is caught

- **WHEN** a governing document or data file states a value that disagrees with its
  authoritative source
- **THEN** the standing suite fails
- **AND** it names the file, the value found, and the value expected

#### Scenario: The check covers values, not only names

- **WHEN** a transcribed constant carries the right name but the wrong number
- **THEN** the standing suite fails
- **AND** any constant the check cannot attribute automatically is reported as
  unattributable rather than silently passed over

### Requirement: The suite is fast enough to be run every time

The standing suite SHALL complete within 60 seconds on the reference machine, because
a gate slow enough to skip stops being run.

#### Scenario: The suite completes within budget

- **WHEN** the standing suite is run on the reference machine from a warm checkout
- **THEN** it completes in 60 seconds or less

### Requirement: Fast checks run before every commit

A commit hook SHALL run the cheap checks on staged files, so that the errors most
easily introduced are caught at the moment they are made rather than at the next
time someone remembers to run the suite.

#### Scenario: A commit with staged violations is refused

- **WHEN** a commit is attempted with a staged file carrying trailing whitespace, a
  missing end-of-file newline, unformatted GDScript, a lint error, or a physics-body
  symbol
- **THEN** the commit is refused
- **AND** the output names the file and the specific violation

#### Scenario: Every way of staging a change is covered

- **WHEN** a violation reaches the index as a plain addition, as a modification whose
  working-tree copy has since been cleaned, or as a rename carrying an edit
- **THEN** the commit is refused in every case
- **AND** no way of staging content lets it reach a commit unexamined

#### Scenario: Content that cannot be read is a failure, not a pass

- **WHEN** the staged content of a file cannot be retrieved for checking
- **THEN** the commit is refused naming that file
- **AND** the file is never treated as empty and therefore clean

#### Scenario: A clean commit is not delayed

- **WHEN** a commit is attempted with no violation in the staged files
- **THEN** the hook exits without complaint
- **AND** it completes fast enough that bypassing it offers no meaningful saving

#### Scenario: The hook is reviewable like source

- **WHEN** the hook's behavior is inspected or changed
- **THEN** it is read from a committed file in the repository, not from a
  developer's local git directory
- **AND** an installer places it so every contributor runs the same checks

#### Scenario: The hook does not stand in for the full suite

- **WHEN** the hook passes
- **THEN** that is not treated as evidence the standing suite would pass
- **AND** the standing suite remains the gate that decides whether work is done

### Requirement: A failing check is visible as a failure

The standing suite SHALL exit non-zero and surface the failing check's own output,
so that a failure is attributable without re-deriving it.

#### Scenario: A broken check fails the whole run

- **WHEN** any check in the standing suite exits non-zero
- **THEN** the suite exits non-zero
- **AND** it does not report success
- **AND** the failing check's message is present in the output
