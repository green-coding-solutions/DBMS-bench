# BenchBase load-driver image for the Wikipedia and YCSB scenarios.
#
# BenchBase builds one self-contained distribution per database profile (each
# bundles that engine's JDBC driver), so we build every profile we need and copy
# them all into one runtime image. A scenario then runs:
#   cd /benchbase/benchbase-<profile> && java -jar benchbase.jar -b <bench> -c <cfg> ...
#
# Build via ./benchmarks/benchbase/build-image.sh (sets the build args below).
# syntax=docker/dockerfile:1

# --- build stage: compile each requested profile from source ---------------
# BenchBase's pom.xml pins Java 23 (maven.compiler.release=23). This base stays PINNED
# while everything in compose.yml floats on `:latest`: it is a build-time toolchain,
# not a measured runtime, and `eclipse-temurin:latest` (JDK 25+) does NOT build
# BenchBase — its fmt-maven-plugin (google-java-format) reaches into internal javac
# APIs and dies with:
#   Failed to execute goal com.spotify.fmt:fmt-maven-plugin:2.25:format ...
#   An API incompatibility was encountered ...: java.lang.NoSuchMethodError: null
# Verified 2026-09-03. Revisit when upstream BenchBase moves off Java 23.
FROM eclipse-temurin:23-jdk AS build

# Moving default; pin a commit SHA via build-image.sh for a reproducible build.
ARG BENCHBASE_REF=main
# Space-separated BenchBase Maven profiles to bake in.
ARG BENCHBASE_PROFILES="postgres mysql mariadb sqlserver oracle cockroachdb"

RUN apt-get update \
 && apt-get install -y --no-install-recommends git ca-certificates \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /src
RUN git clone https://github.com/cmu-db/benchbase.git . \
 && git checkout "${BENCHBASE_REF}"

# Patch an upstream Wikipedia data-generator bug: UpdatePage truncates the
# generated revComment to 254 chars before writing revision.rev_comment, but
# writes the *untruncated* value into recentchanges.rc_comment (also
# varchar(255)). On any strict engine (PostgreSQL, and MySQL/MariaDB/Oracle/
# SQL Server in their default strict modes) the occasional >255-char comment
# makes the rc_comment insert fail with "value too long" (SQLSTATE 22001),
# silently dropping that UpdatePage txn. We apply the same substring truncation
# already used for rev_comment. Anchored on the `// rc_comment` trailing comment
# so it survives line-number drift; the grep guard fails the build loudly if
# upstream changes shape and the patch silently no-ops.
# Upstream: https://github.com/cmu-db/benchbase  (procedures/UpdatePage.java)
RUN set -eux; \
    f=src/main/java/com/oltpbenchmark/benchmarks/wikipedia/procedures/UpdatePage.java; \
    sed -i 's|revComment); // rc_comment|revComment.substring(0, Math.min(revComment.length(), 255 - 1))); // rc_comment|' "$f"; \
    grep -q 'revComment.substring(0, Math.min(revComment.length(), 255 - 1))); // rc_comment' "$f"; \
    ! grep -q 'param++, revComment); // rc_comment' "$f"

# Patch the upstream Oracle Wikipedia DDL: five varchar2 columns (ipb_timestamp,
# page_touched, rev_timestamp, user_touched, user_token) carry a MySQL-style
# binary default of N literal NUL bytes written as '\0\0...'. Oracle does not
# process backslash escapes in string literals, so it reads each '\0' as the two
# characters backslash+zero -- e.g. varchar2(14) DEFAULT '\0\0\0\0\0\0\0\0\0\0\0\0\0\0'
# is a 28-char default into a 14-char column, which fails CREATE TABLE with
# ORA-01401 (inserted value too large for column). The sibling timestamp columns
# in the same file use DEFAULT '', so we normalise every varchar2 NUL-byte
# default to ''. The grep guard fails the build loudly if upstream changes shape
# and the patch silently no-ops.
# Upstream: https://github.com/cmu-db/benchbase  (benchmarks/wikipedia/ddl-oracle.sql)
RUN set -eux; \
    f=src/main/resources/benchmarks/wikipedia/ddl-oracle.sql; \
    sed -i "s/\(varchar2([0-9]*)\) DEFAULT '[\\0]*'/\1 DEFAULT ''/g" "$f"; \
    ! grep -qF "\0" "$f"

# Build each profile and unpack its tarball into /dist/benchbase-<profile>/.
# The Maven dependency cache (~/.m2) persists across profiles within this layer,
# so only the first profile pays the full download cost. Tests are skipped.
RUN set -eux; \
    mkdir -p /dist; \
    for p in ${BENCHBASE_PROFILES}; do \
      echo ">> building BenchBase profile: $p"; \
      ./mvnw -q -B clean package -P "$p" -DskipTests; \
      tar -xzf "target/benchbase-$p.tgz" -C /dist; \
    done; \
    ls -d /dist/benchbase-*

# --- runtime stage: JRE + the unpacked distributions -----------------------
FROM eclipse-temurin:23-jre
LABEL org.opencontainers.image.source="https://github.com/cmu-db/benchbase" \
      org.opencontainers.image.description="CMU BenchBase, multi-profile, load driver for DBMS-bench"

WORKDIR /benchbase
COPY --from=build /dist/ /benchbase/
# Fail the build early if no profile made it in.
RUN ls -d /benchbase/benchbase-* >/dev/null

# Stay alive so GMT can exec each flow step (create+load, then execute) into the
# running container, the same way it drives the hammerdb container.
CMD ["sleep", "infinity"]
