#!/bin/bash
# CI/CD Deployment Script for Abbott DAB Bundle
# Usage: ./cicd/deploy.sh <target>
# Example: ./cicd/deploy.sh dev
#          ./cicd/deploy.sh qa

set -e

# ─── Configuration ───────────────────────────────────────────────────────────
TARGET="${1:-dev}"
VALID_TARGETS=("dev" "qa")

# ─── Service Principal Auth Variables ────────────────────────────────────────
# Set these in your CI/CD pipeline secrets (GitHub Actions, Azure DevOps, etc.)
# Do NOT hardcode credentials here.
export DATABRICKS_HOST="${DATABRICKS_HOST}"
export DATABRICKS_CLIENT_ID="${DATABRICKS_CLIENT_ID}"
export DATABRICKS_CLIENT_SECRET="${DATABRICKS_CLIENT_SECRET}"

# Target-specific workspace URLs (override DATABRICKS_HOST per environment)
declare -A WORKSPACE_HOSTS
WORKSPACE_HOSTS["dev"]="https://e2-demo-field-eng.cloud.databricks.com"
WORKSPACE_HOSTS["qa"]="https://e2-demo-field-eng.cloud.databricks.com"

# ─── Functions ───────────────────────────────────────────────────────────────
log() {
  echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"
}

error() {
  echo "[ERROR] $1" >&2
  exit 1
}

# ─── Validate target ────────────────────────────────────────────────────────
if [[ ! " ${VALID_TARGETS[*]} " =~ " ${TARGET} " ]]; then
  error "Invalid target '${TARGET}'. Must be one of: ${VALID_TARGETS[*]}"
fi

log "Starting deployment to target: ${TARGET}"

# ─── Pre-flight: Ensure Databricks CLI is authenticated ─────────────────────
# Authentication priority:
#   1. Service Principal OAuth (recommended for CI/CD)
#      - DATABRICKS_CLIENT_ID
#      - DATABRICKS_CLIENT_SECRET
#   2. Personal Access Token (for local dev only)
#      - DATABRICKS_TOKEN

if [[ -n "${DATABRICKS_CLIENT_ID}" && -n "${DATABRICKS_CLIENT_SECRET}" ]]; then
  log "Authenticating with Service Principal OAuth (client_id: ${DATABRICKS_CLIENT_ID})"
elif [[ -n "${DATABRICKS_TOKEN}" ]]; then
  log "Authenticating with Personal Access Token"
else
  error "Authentication not configured. Set DATABRICKS_CLIENT_ID/DATABRICKS_CLIENT_SECRET (recommended) or DATABRICKS_TOKEN."
fi

# Set workspace host based on target if not explicitly overridden
if [[ -z "${DATABRICKS_HOST}" ]]; then
  export DATABRICKS_HOST="${WORKSPACE_HOSTS[${TARGET}]}"
fi

if [[ -z "${DATABRICKS_HOST}" ]]; then
  error "DATABRICKS_HOST is not set and no workspace URL configured for target '${TARGET}'."
fi

log "Workspace: ${DATABRICKS_HOST}"

# ─── Step 1: Validate ───────────────────────────────────────────────────────
log "Validating bundle for target: ${TARGET}"
databricks bundle validate --target "${TARGET}"

if [[ $? -ne 0 ]]; then
  error "Bundle validation failed for target: ${TARGET}"
fi
log "Validation passed."

# ─── Step 2: Deploy ─────────────────────────────────────────────────────────
log "Deploying bundle to target: ${TARGET}"
databricks bundle deploy --target "${TARGET}"

if [[ $? -ne 0 ]]; then
  error "Bundle deployment failed for target: ${TARGET}"
fi
log "Deployment to '${TARGET}' completed successfully."

# ─── Step 3 (Optional): Run a specific resource ────────────────────────────
# Uncomment and replace <resource_name> to trigger a run after deploy:
# log "Running resource on target: ${TARGET}"
# databricks bundle run --target "${TARGET}" <resource_name>

log "Done."
