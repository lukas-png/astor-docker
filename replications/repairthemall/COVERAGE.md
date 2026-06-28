# jGenProg coverage: what the published experiment actually produced

The published RepairThemAll experiment attempted all **395** Defects4J jGenProg
bugs (every bug has a `repair.log` + `grid5k.stderr.log` upstream) but produced a
parseable `result.json` for only **197**. The other **198** are therefore out of
scope for the reference comparison -- not because we skipped them, but because the
*original* run produced no result to compare against. This is established from
the upstream logs (which `sync-reference-results` deliberately omits) by
[`scripts/reference/audit-upstream-coverage`](scripts/reference/audit-upstream-coverage), whose output
is committed as [`reference/coverage-jGenProg.csv`](reference/coverage-jGenProg.csv).

## Per-bug faithful reproduction

Our local run reproduces the upstream outcome **per bug**, including the
failures. Cross-tabulating the audited upstream status against our own
categorisation of the same 395 runs gives a near-perfect 1:1 mapping:

| upstream outcome | n | our category | evidence |
|---|---:|---|---|
| `STOP_BY_PATCH_FOUND` | 31 | PATCH_FOUND | result.json |
| `TIME_OUT`            | 133 | NO_PATCH_TIMEOUT | result.json |
| `ERROR`              | 33 | ASTOR_ERROR | result.json |
| `CRASH` (Spoon `ModelBuildingException` x45, `NullPointerException` x5) | 50 | TOOL_CRASH | repair.log |
| `KILLED_GRID` (OAR job killed on walltime) | 141 | KILLED_NO_OUTPUT | grid5k.stderr.log |
| `INITIAL_TESTS_FAIL` (Astor: initial test suite run failed) | 5 | KILLED_NO_OUTPUT | repair.log |
| `TRUNCATED` (log ends without a terminal marker) | 2 | KILLED_NO_OUTPUT x1, other x1 | repair.log |

The 197 with a result are validated field-by-field by
[`scripts/validate/validate-replication`](scripts/validate/validate-replication) (OUTCOME /
TRAJECTORY / EXACT tiers). The 198 without a result are not fixable defects on our
side:

- **Timeouts (141 `KILLED_GRID` + 5 `INITIAL_TESTS_FAIL` + 1 `TRUNCATED` = 147):**
  Astor's `-maxtime` is soft (checked only between generations), so on large
  sources (Closure/Time/Math) a run overruns and is killed by the job scheduler
  before it can write a `TIME_OUT` result. The *original* was killed the same way
  -- its OAR grid logs the walltime kill explicitly (`## OAR [...] Job N KILLED ##`).
- **Crashes (50):** the original crashed with the *identical* exceptions --
  Spoon `ModelBuildingException` (Mockito/Lang, whose Gradle sources Spoon cannot
  model) and a GZoltar `NullPointerException` (Lang). These are Astor/Spoon limits
  on those sources, not environment faults introduced here.

Pushing past either (removing the timeout, patching the crashes) would produce
*more* than RepairThemAll did and is therefore an extension beyond the
replication, not a correction of it.

## Regenerating

```bash
scripts/reference/audit-upstream-coverage   # -> reference/coverage-jGenProg.csv (pinned @ a59cd3c)
```

Clones the pinned upstream blobless, inventories all 395 jGenProg bugs offline,
sparse-fetches only the logs of the bugs that lack a result, reads the terminal
outcome from them, and writes the CSV. Re-running must produce no diff unless the
pin is bumped.
