#!/usr/bin/env bash
# Builds the `hammerdb-db2` image used to benchmark a remote IBM Db2 server.
#
# A pure Dockerfile cannot do this: a Db2 client instance is created at runtime
# (not present in the db2_community image), so we spin up a throwaway
# db2_community container, let it initialise an instance, lift the install +
# instance + registry + services out of it, and bake them onto the hammerdb
# (Ubuntu) base. See Dockerfile.hammerdb-db2 for why it has to be this way.
#
# Run this ONCE before running the Db2 usage scenarios (after `docker login`):
#     ./db/db2/build-image.sh
# It builds the image and pushes it to Docker Hub as ribalba/hammerdb-db2:latest,
# which is the image the Db2 usage scenarios pull. Set NO_PUSH=1 to build only.
#
# Requires Docker with --privileged support (Db2 needs it to initialise).
set -euo pipefail

DB2_IMAGE="${DB2_IMAGE:-icr.io/db2_community/db2:latest}"
HDB_IMAGE="${HDB_IMAGE:-tpcorg/hammerdb:latest}"
OUT_IMAGE="${OUT_IMAGE:-ribalba/hammerdb-db2:latest}"
HERE="$(cd "$(dirname "$0")" && pwd)"
EXTRACT="db2_image_extract_$$"
CTX="$(mktemp -d)"
cleanup() { docker rm -f "$EXTRACT" >/dev/null 2>&1 || true; rm -rf "$CTX"; }
trap cleanup EXIT

echo ">> pulling base images"
docker pull "$DB2_IMAGE"
docker pull "$HDB_IMAGE"

echo ">> starting throwaway Db2 to initialise a client instance"
docker run -d --name "$EXTRACT" --privileged=true \
  -e LICENSE=accept -e DB2INST1_PASSWORD=ibmdb2 "$DB2_IMAGE" >/dev/null

echo -n ">> waiting for Db2 setup to complete"
for _ in $(seq 1 90); do
  if docker logs "$EXTRACT" 2>&1 | grep -q "Setup has completed"; then ok=1; break; fi
  echo -n "."; sleep 5
done
echo
[ "${ok:-}" = 1 ] || { echo "ERROR: Db2 did not finish initialising"; docker logs "$EXTRACT" | tail -20; exit 1; }

echo ">> extracting Db2 install + instance + registry + services"
DB2_VER="$(docker exec "$EXTRACT" bash -lc 'ls -d /opt/ibm/db2/V* | head -1 | xargs basename')"
docker cp "$EXTRACT:/opt/ibm/db2/$DB2_VER"        "$CTX/db2-install"
docker cp "$EXTRACT:/database/config/db2inst1"    "$CTX/db2inst1-home"
docker cp "$EXTRACT:/var/db2/global.reg"          "$CTX/global.reg"
docker exec "$EXTRACT" bash -lc 'grep -iE "db2c_db2inst1|DB2_db2inst1|db2j_db2inst1" /etc/services' > "$CTX/db2-services"
cp "$HERE/Dockerfile.hammerdb-db2" "$CTX/Dockerfile"

if [ "$DB2_VER" != "V12.1" ]; then
  echo ">> note: db2_community is $DB2_VER (Dockerfile expects V12.1); adjusting"
  sed -i "s#/opt/ibm/db2/V12.1#/opt/ibm/db2/$DB2_VER#g" "$CTX/Dockerfile"
fi

echo ">> building $OUT_IMAGE"
docker build --build-arg HDB_IMAGE="$HDB_IMAGE" -t "$OUT_IMAGE" "$CTX"

if [ "${NO_PUSH:-0}" = 1 ]; then
  echo ">> built $OUT_IMAGE (push skipped via NO_PUSH=1)"
else
  echo ">> pushing $OUT_IMAGE to Docker Hub (requires prior 'docker login')"
  docker push "$OUT_IMAGE"
  echo ">> done: pushed $OUT_IMAGE"
fi
