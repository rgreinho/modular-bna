#!/bin/bash
set -euo pipefail
[ -n "${PFB_DEBUG}" ] && set -x

# Wait for database to become available.
timeout 90s bash -c "until pg_isready ; do sleep 5 ; done"

# Run the analysis.
/opt/pfb/analysis/scripts/run_analysis.sh

# Display the completion status.
update_status "COMPLETE" "Finished analysis"

# Use official environment variables instead:
# PGHOST behaves the same as the host connection parameter.
# PGHOSTADDR behaves the same as the hostaddr connection parameter. This can be
#   set instead of or in addition to PGHOST to avoid DNS lookup overhead.
# PGPORT behaves the same as the port connection parameter.
# PGDATABASE behaves the same as the dbname connection parameter.
# PGUSER behaves the same as the user connection parameter.
# PGPASSWORD behaves the same as the password connection parameter. Use of this
#   environment variable is not recommended for security reasons, as some
#   operating systems allow non-root users to see process environment variables
#   via ps; instead consider using a password file (see Section 34.16).
