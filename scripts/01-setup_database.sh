#!/bin/bash
set -euo pipefail
[ "${PFB_DEBUG}" -eq "1" ] && set -x

PFB_AUTOVACUUM="${PFB_AUTOVACUUM:-off}"
# Set defaults for overridable configuration params
PFB_CHECKPOINT_COMPLETION="${PFB_CHECKPOINT_COMPLETION:-0.8}"
# Since WAL size is deliberately small, suppress the checkpoint warnings
# Default postgresql setting is 30, units are seconds
PFB_CHECKPOINT_WARNING_INTERVAL="${PFB_CHECKPOINT_WARNING_INTERVAL:-0}"
# Disable to improve performance, if disabled, data loss occurs on server crash (ok for analysis)
PFB_FSYNC="${PFB_FSYNC:-on}"
# Only one process at a time, can be higher, set to 1/4 of available system memory
PFB_MAINTENANCE_WORK_MEM="${PFB_MAINTENANCE_WORK_MEM:-1024MB}"
# WAL is not useful for us, so keep small to limit disk usage
PFB_MAX_WAL_SIZE="${PFB_MAX_WAL_SIZE:-256MB}"
# Set to ~1/4 of available system memory
PFB_SHARED_BUFFERS="${PFB_SHARED_BUFFERS:-1024MB}"
# Disable to improve performance, _slightly_ safer than fsync=off
PFB_SYNCHRONOUS_COMMIT="${PFB_SYNCHRONOUS_COMMIT:-off}"
# Limits disk usage of query temp tables, set to ~1/2 of available disk space in KB, default 10GB
PFB_TEMP_FILE_LIMIT="${PFB_TEMP_FILE_LIMIT:-10485760}"
# Setting to at least a few MB can improve write performance on a server with many commits at once
PFB_WAL_BUFFERS="${PFB_WAL_BUFFERS:-8192}"
# This is per operation, so can't be massive. For analysis, 1/8 of available system memory
PFB_WORK_MEM="${PFB_WORK_MEM:-512MB}"

# Set configuration parameters
psql <<EOF
ALTER SYSTEM SET autovacuum TO ${PFB_AUTOVACUUM};
ALTER SYSTEM SET checkpoint_completion_target TO ${PFB_CHECKPOINT_COMPLETION};
ALTER SYSTEM SET checkpoint_warning TO ${PFB_CHECKPOINT_WARNING_INTERVAL};
ALTER SYSTEM SET fsync TO ${PFB_FSYNC};
ALTER SYSTEM SET maintenance_work_mem TO '${PFB_MAINTENANCE_WORK_MEM}';
ALTER SYSTEM SET max_wal_size TO '${PFB_MAX_WAL_SIZE}';
ALTER SYSTEM SET shared_buffers TO '${PFB_SHARED_BUFFERS}';
ALTER SYSTEM SET synchronous_commit TO ${PFB_SYNCHRONOUS_COMMIT};
ALTER SYSTEM SET temp_file_limit TO '${PFB_TEMP_FILE_LIMIT}';
ALTER SYSTEM SET wal_buffers TO ${PFB_WAL_BUFFERS};
ALTER SYSTEM SET work_mem TO '${PFB_WORK_MEM}';
EOF

# install extensions
psql <<EOF
CREATE EXTENSION "uuid-ossp";
CREATE EXTENSION "hstore";
CREATE EXTENSION "plpython3u";
CREATE EXTENSION "pgrouting";
CREATE EXTENSION "quantile";
CREATE SCHEMA IF NOT EXISTS generated AUTHORIZATION ${PGUSER};
CREATE SCHEMA IF NOT EXISTS received AUTHORIZATION ${PGUSER};
CREATE SCHEMA IF NOT EXISTS scratch AUTHORIZATION ${PGUSER};
ALTER USER ${PGUSER} SET search_path TO generated,received,scratch,"\$user",public;
EOF
