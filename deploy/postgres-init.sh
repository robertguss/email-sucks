#!/usr/bin/env bash
set -euo pipefail
psql --username postgres --dbname postgres --set ON_ERROR_STOP=1 <<'SQL'
\getenv app_password DB_APP_PASSWORD
CREATE ROLE email_sucks LOGIN PASSWORD :'app_password';
CREATE DATABASE email_sucks_phase0 OWNER email_sucks;
SQL
