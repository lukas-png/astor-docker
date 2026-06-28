# Astor on Defects4J -- RepairThemAll replication

Runs the [Astor](https://github.com/SpoonLabs/astor) program-repair tool on
[Defects4J](https://github.com/rjust/defects4j) bugs, reproducing the Astor
part of the [RepairThemAll](https://github.com/program-repair/RepairThemAll)
experiment (Durieux et al., *Empirical Review of Java Program Repair Tools*,
ESEC/FSE 2019). The image adds Java 8 (Astor's runtime) and the pinned Astor jar
on top of [`defects4j-docker`](https://github.com/lukas-png/defects4j-docker);
bugs' tests run on Java 7, Astor on Java 8.

The folder contains `scripts/` (tooling; see [`scripts/README.md`](scripts/README.md)
for an index grouped by purpose), `resources/` (vendored jar, run
wrapper, and compliance table), `reference/` (the published results, committed),
`results/` (collected per-bug evidence), `work/` (scratch checkouts), and
`logs/` (per-run batch logs, created by `run-batch`).

## Astor jar selection

`RepairThemAll/repair_tools/astor.jar` has four revisions, and the one on
`master` today is not the one used in the experiment. The published Defects4J
runs are all dated Nov-Dec 2018, when `master` carried `e902cf5` (2018-11-04).
The later `edcbfc8` (2019-01-02) is a post-experiment rebuild. The two differ in
`fr.inria.astor` classes (for example Cardumen's context code), which changes the
results.

This replication therefore vendors `e902cf5` (RepairThemAll commit
`e902cf54f84a059379d9abfd6159d502963511cc`, sha256
`8ab2a8acc8bf263b62c77b594f0ea1ba8a61469d20b33f27aa76fadf563cf51a`), recorded and
checksum-verified in [`build.env`](build.env).

## Methodology (matches RepairThemAll's runner)

- **Modes:** `jGenProg`, `jKali`, `jMutRepair`, `cardumen` (via `MODE`). jGenProg
  is the primary mode here.
- **Defaults:** scope `local`, `seed` 0, `maxtime` 120 min, `maxgen` 1e6,
  `population` 1, `stopfirst` true; failing tests and folders from `defects4j
  export`.
- **Per-bug compliance:** `-javacompliancelevel` is each bug's Defects4J source
  level (Math-70 = 5), from [`resources/d4j-compliance.tsv`](resources/d4j-compliance.tsv).
  Matching it per bug reproduces the search trajectory, not only the final patch.
  Override with `-e COMPLIANCE=n`.
- **Determinism:** fixed locale/encoding/timezone; `run-astor` also unsets
  `_JAVA_OPTIONS` and `JAVA_TOOL_OPTIONS`, ships `jtestex7.jar` where Astor
  expects it, and passes test classes (not `Class::method`) to `-failing`. See
  its comments for details.

## Build

From the repo root (`repairthemall` is the default replication):

```bash
./build.sh                  # -> astor:1.4.0
./build.sh repairthemall --push
```

`astor.jar`, `jtestex7.jar` and `d4j-compliance.tsv` are committed (the jar's
sha256 is checked at build time); only the Zulu JDK 8 tarball is downloaded.

## Run one bug

```bash
docker run --rm -it astor:1.4.0 run-astor Math-70
```

`run-astor <Project>-<BugId>` checks out, compiles, and repairs the bug; on
success Astor prints a `PATCH_DIFF`. To keep output, mount this folder's `work/`.
On Fedora/rootless podman add `--userns=keep-id` and the `:z` label:

```bash
cd replications/repairthemall
podman run --rm --userns=keep-id -v "$PWD/work:/work:z" astor:1.4.0 run-astor Math-70
scripts/run/collect-results Math-70    # -> results/Math-70/jGenProg/{astor_output.json,astor.log,patches/}
```

`--userns=keep-id` is podman-only. With Docker it fails (`invalid USER mode`):
drop that flag and use `:Z` (or no label):

```bash
docker run --rm -v "$PWD/work:/work" astor:1.4.0 run-astor Math-70
```

## Reproducibility check

Each bug is checked against the published results at three tiers, ignoring
timestamps, paths, and timing:

- **OUTCOME:** same result (patched or not), and the same {fix location,
  operator, original->patched code} when patched. This is the CI gate.
- **TRAJECTORY:** additionally requires an identical generation count and
  good/bad compilation counts, i.e. a deterministic run.
- **EXACT** (report-only): for patched bugs also the modification-point fields
  (`LINE`, `SUSPICIOUNESS`, `MP_RANKING`, code-element types, ingredient
  scope/parent), and for every bug the terminal `OUTPUT_STATUS` (so timeout and
  error runs are checked too). Listed by field; does not affect the exit code.

```bash
scripts/run/run-batch                         # run all jGenProg bugs (resumable, 120-min budget)
scripts/validate/validate-replication --csv report.csv
# Output format (numbers illustrative, NOT a measured result):
#   OUTCOME    identical: 195/197  98.9%
#   TRAJECTORY identical: 193/195  99.0%
#   EXACT      identical:  31/31  100.0%   (report-only)
#   (mismatches listed by bug with the differing fields)
```

The committed reference covers the 197 of 395 Defects4J bugs the published
experiment produced a result for; `run-batch` with no arguments iterates exactly
those. The other 198 were *attempted* upstream but produced no result (the grid
killed them on walltime, or Astor crashed) -- our run reproduces the same outcome
per bug, so they are out of scope for this check rather than a failure of it. See
[`COVERAGE.md`](COVERAGE.md) and [`reference/coverage-jGenProg.csv`](reference/coverage-jGenProg.csv)
for the per-bug evidence.

`run-batch` is resumable (a (bug, mode) whose result already exists is skipped;
`--force` re-runs) and writes one log per run to `logs/<Bug>-<Mode>.log`, kept
even when a run fails. That log is the batch driver's capture of the container's
output; `collect-results` separately archives the in-run log to
`results/<Bug>/<Mode>/astor.log` on success. Useful flags: `--modes`,
`--maxtime N`, `--seed N`, `--limit N`, `--force`.

`validate-replication` exits non-zero on any outcome disagreement (CI gate);
`report.csv` is the per-bug evidence table. Flags: `--modes M` (subset or
`all`), `--csv FILE`, `--strict` (also fail on not-yet-run bugs), `--show N`
(cap the listed mismatches). Single-bug spot check: `scripts/validate/compare-result
Math-70`. Verified: `Math-70` jGenProg reproduces `STOP_BY_PATCH_FOUND` at
generation 17 (5 good / 12 bad compiles).

Other modes are opt-in: `scripts/run/run-batch --modes jKali,Cardumen` then
`scripts/validate/validate-replication --modes all`.

### Testing alternative Astor jars (trajectory diffs)

When a bug reproduces the OUTCOME but not the TRAJECTORY
(`MATCH_OUTCOME_TRAJ_DIFF`), the question is whether a *different* astor.jar
revision would reproduce the published search better. `scripts/jars/validate-astor-jars`
answers it empirically without touching the pin: it runs candidate jars side by
side and scores each with the same OUTCOME/TRAJECTORY definitions as
`validate-replication`.

The candidates are every revision of `repair_tools/astor.jar` in RepairThemAll's
history, recorded (commit + sha256 + how each differs from the pin) in
[`reference/astor-jar-candidates.tsv`](reference/astor-jar-candidates.tsv):

| key | date | vs pinned `e902cf5` |
|-----|------|---------------------|
| `afdd959` | 2018-10-28 | oldest; only 377 Astor classes (vs 853) — a genuinely older Astor, the one candidate that can move a **jGenProg** trajectory |
| `edb42d5` | 2018-10-29 | 3 setup/config classes differ, none on the jGenProg search path |
| `e902cf5` | 2018-11-04 | **pinned** — produced the published results |
| `edcbfc8` | 2019-01-02 | later master; 8 classes differ, mostly Cardumen context code (affects **Cardumen**, not jGenProg) |

`scripts/jars/fetch-astor-jars` streams each from a per-commit raw URL and sha256-checks
it into `resources/astor-jars/` (gitignored; not vendored — the pin stays
`resources/astor.jar`). `run-astor` honours `ASTOR_JAR` to run a mounted jar over
the baked-in one, so no image rebuild is needed. Per-jar output lands in
`results-jars/<key>/`.

```bash
# 1) find the trajectory-mismatch bugs, then test every jar on exactly those:
scripts/validate/validate-replication --csv report.csv
scripts/jars/validate-astor-jars --from-report report.csv

# or name bugs / a jar subset explicitly:
scripts/jars/validate-astor-jars --bugs Math-70,Lang-6 --jars afdd959,e902cf5

# score already-collected per-jar results without running anything:
scripts/jars/validate-astor-jars --bugs Math-70 --no-run
```

It prints a per-jar OUTCOME/TRAJECTORY match table plus a per-bug matrix
(`v`=matches published ref, `X`=differs, `-`=not run). Same `--maxtime`/`--seed`
caveats as `run-batch`: below 120 min the trajectory is not comparable. A real
sweep (bugs x jars x maxtime) runs for hours, so detach it like the batch:
`scripts/jars/validate-astor-jars-nohup --from-report report.csv` (backgrounds it, logs
to `logs/jars-<ts>.log`, resumable).

For jGenProg the class diff already tells you most of the answer: `edb42d5` and
`edcbfc8` touch no jGenProg search code, so they should match `e902cf5` exactly;
only `afdd959` can shift a jGenProg trajectory. Run the harness to confirm it.

### Host configuration (podman / docker)

`run-batch` auto-detects the engine (podman, else docker) and picks engine-safe
run flags: rootless podman gets `--userns=keep-id`, docker gets
`--user $(id -u):$(id -g)` so `work/` files stay host-owned and removable. To
force the engine:

```bash
ENGINE=docker scripts/run/run-batch
```

Override the defaults only if needed: `RUN_OPTS=<flags>` (per-run flags),
`VOL_SUFFIX=":z"`/`":Z"` for SELinux, or `VOL_SUFFIX=""` to disable relabeling.

## Tuning

`run-astor` reads env vars: `MODE` (jgenprog), `SCOPE` (local), `MAXTIME` (120),
`SEED` (0), `MAXGEN` (1000000), `POPULATION` (1), `STOPFIRST` (true), `PARAMETERS`
(x:x), `COMPLIANCE` (per-bug; `>7` runs tests on Java 8), `JAVA_ARGS`
(`-Xmx4g -Xms1g`).

```bash
docker run --rm -e MODE=cardumen -e MAXTIME=30 astor:1.4.0 run-astor Lang-6
```

## Maintenance / notes

- Refresh the committed reference subset: `scripts/reference/sync-reference-results`
  (pinned to `RepairThemAll_experiment@a59cd3c`, ~2k JSON files).
- Regenerate the coverage evidence: `scripts/reference/audit-upstream-coverage` (reads the
  upstream logs `sync-reference-results` skips) -> `reference/coverage-jGenProg.csv`;
  see [`COVERAGE.md`](COVERAGE.md) for the per-bug 197/198 breakdown.
- Rebuild the compliance table: `scripts/reference/gen-compliance-table`.
- Defects4J `1.4.0`; available projects are those in the base image (Chart,
  Closure, Lang, Math, Mockito, Time).
- Astor and Defects4J keep their own licenses; this folder is build/packaging only.
