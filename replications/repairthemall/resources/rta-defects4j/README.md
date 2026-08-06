# RepairThemAll Defects4J project metadata (vendored)

Verbatim copies of `data/benchmarks/defects4j/*.json` from
[program-repair/RepairThemAll](https://github.com/program-repair/RepairThemAll)
at commit `195df8e068cfbbeb0a0f1126a2e1bef51fbefdba` (2018-11-30) -- the last
revision *before* `4a98bc108c` (2018-12-01, "improve classpath defects4j")
rewrote `Defects4J.classpath()` in the middle of the experiment window. The
published jGenProg runs all carry `cobertura-2.0.3.jar` on their classpath,
which only the pre-`4a98bc1` algorithm produces, so this revision is the one
that generated the reference results (see ../../FINDINGS.md).

`run-astor` replicates that algorithm and reads these files' `classpath`
(per-bug-range working-dir entries) and `libs` (framework project-lib jar
names) via the generated table `../rta-classpath.tsv`
(`scripts/reference/gen-rta-classpath-table`). Do not edit the JSONs; refetch
from the pinned commit instead (recorded in ../../build.env).
