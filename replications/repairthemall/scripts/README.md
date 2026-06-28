# scripts/

Tooling for the Astor/Defects4J replication. Every script computes its own repl
root and can be run from anywhere; each has a `-h`/comment header with details.
The scripts are grouped into four subfolders by purpose:

```
scripts/
  run/         run Astor over bugs and collect results
  validate/    score local results against the reference
  jars/        compare candidate astor.jar revisions
  reference/   regenerate committed reference data (rarely)
```

The normal loop is **run → validate**, against a committed **reference**:

```
run/run-batch ─(run/collect-results)─▶ results/ ─▶ validate/validate-replication ─▶ pass/fail
                                                     ▲
                    reference/  ─────────────────────┘   (the published RepairThemAll results)
```

## `run/` — produce local results
| script | does |
|--------|------|
| `run-batch` | Run Astor over many bugs/modes (resumable), collecting each result into `results/`. |
| `run-batch-nohup` | Detach `run-batch` into the background (logs to `logs/`, resumable). |
| `collect-results` | Copy one finished run's artefacts from `work/` into `results/<Bug>/<Mode>/`. |

## `validate/` — score local runs against the reference
| script | does |
|--------|------|
| `validate-replication` | Corpus-wide OUTCOME / TRAJECTORY / EXACT check. The CI gate. |
| `compare-result` | Quick single-bug local-vs-reference spot check. |

## `jars/` — test the pinned jar (see reference/astor-jar-candidates.tsv)
| script | does |
|--------|------|
| `fetch-astor-jars` | Download + sha256-verify the candidate `astor.jar` revisions into `resources/astor-jars/`. |
| `validate-astor-jars` | Run the candidates side by side and score each against the reference. |
| `validate-astor-jars-nohup` | Detach `validate-astor-jars` into the background. |

## `reference/` — regenerate committed data (rarely; when bumping a pin)
| script | does |
|--------|------|
| `sync-reference-results` | Refresh `reference/Defects4J/` from the published experiment. |
| `audit-upstream-coverage` | Build the per-bug coverage evidence (`reference/coverage-jGenProg.csv`). |
| `gen-compliance-table` | Regenerate `resources/d4j-compliance.tsv` (per-bug `-javacompliancelevel`). |

Python: `validate/validate-replication`, `validate/compare-result`,
`jars/validate-astor-jars`. The rest are bash. `jars/validate-astor-jars` imports
`validate/validate-replication` so both score with the same OUTCOME/TRAJECTORY rules.
