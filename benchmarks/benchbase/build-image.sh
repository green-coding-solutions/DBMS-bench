#!/usr/bin/env bash
# Builds the `benchbase` image used to drive the Wikipedia and YCSB scenarios.
#
# BenchBase (https://github.com/cmu-db/benchbase) builds one self-contained
# distribution per database profile (each bundles that engine's JDBC driver).
# This image bakes in a distribution for every engine we benchmark so a SINGLE
# image/container drives all databases of a benchmark — keeping the load
# generator identical across engines. Each profile lands in
# /benchbase/benchbase-<profile>/ inside the image; the usage scenarios cd into
# the right one and run `java -jar benchbase.jar ...`.
#
# Run this ONCE before running the Wikipedia/YCSB scenarios (after `docker login`):
#     ./benchmarks/benchbase/build-image.sh
# It builds and pushes the image to Docker Hub as ribalba/benchbase:latest, which
# the usage scenarios pull. Set NO_PUSH=1 to build only.
#
# For a reproducible paper build, pin BENCHBASE_REF to a commit SHA:
#     BENCHBASE_REF=<sha> ./benchmarks/benchbase/build-image.sh
set -euo pipefail

OUT_IMAGE="${OUT_IMAGE:-ribalba/benchbase:latest}"
# BenchBase has no GitHub releases. The default is pinned to the commit that `main`
# pointed at when the image of 3 September 2026 was built, so that a rebuild (for
# example with a new dialect file) changes nothing else; override via BENCHBASE_REF.
BENCHBASE_REF="${BENCHBASE_REF:-33c00473807ebd49304d114a6d769d2d2b2bbb34}"
# Engines we benchmark. BenchBase profile names (note: postgres->pg, mariadb->maria,
# sqlserver->mssql in this repo's directory naming). No Db2 profile exists.
BENCHBASE_PROFILES="${BENCHBASE_PROFILES:-postgres mysql mariadb sqlserver oracle cockroachdb}"
HERE="$(cd "$(dirname "$0")" && pwd)"

echo ">> building $OUT_IMAGE"
echo "   ref:      $BENCHBASE_REF"
echo "   profiles: $BENCHBASE_PROFILES"
docker build \
  --build-arg BENCHBASE_REF="$BENCHBASE_REF" \
  --build-arg BENCHBASE_PROFILES="$BENCHBASE_PROFILES" \
  -t "$OUT_IMAGE" \
  "$HERE"

if [ "${NO_PUSH:-0}" = 1 ]; then
  echo ">> built $OUT_IMAGE (push skipped via NO_PUSH=1)"
else
  echo ">> pushing $OUT_IMAGE to Docker Hub (requires prior 'docker login')"
  docker push "$OUT_IMAGE"
  echo ">> done: pushed $OUT_IMAGE"
fi
