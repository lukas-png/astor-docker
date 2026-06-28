# Program-repair replication images

Container images that replicate program-repair experiments. Each replication is a
self-contained package under `replications/`; the top-level `build.sh` builds any
of them.

```
build.sh                 # ./build.sh <replication> [version] [--push]
replications/
  repairthemall/         # Astor on Defects4J — the RepairThemAll 2019 experiment
```

`build.sh` reads `replications/<name>/build.env` (image tag, versions, vendored
artefacts with sha256, on-demand downloads) and builds with `podman` or `docker`
(`ENGINE=docker` to force). To add a replication, drop a folder with a
`Dockerfile`, `resources/`, and a `build.env`.

See **[replications/repairthemall/README.md](replications/repairthemall/README.md)**
for the Astor replication: usage, the pinned Astor version and why, and the
automated reproducibility check against the published results.
