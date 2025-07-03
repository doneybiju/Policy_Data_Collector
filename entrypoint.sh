#!/usr/bin/env bash
set -euo pipefail

# ---------- CONFIG via env vars ----------
TARGETS=${SCAN_TARGETS:-"127.0.0.1"}
DS_FILE=${DS_FILE:-"/usr/share/xml/scap/ssg/content/ssg-debian12-ds.xml"}
PROFILE=${PROFILE:-"xccdf_org.ssgproject.content_profile_standard"}
TAILORING_FILE=${TAILORING_FILE:-""}
OSCAP_OPTS=${OSCAP_OPTS:---fetch-remote-resources}
UPLOAD_URL=${UPLOAD_URL:-""}
API_KEY=${API_KEY:-""}

: "${NMAP_OPTS:=-sS}"
TARGET_ROOT=${HOST_ROOT:-""}

# ---------- WORKDIR ----------
ts=$(date -u +"%Y%m%dT%H%M%SZ")
WORKDIR="/tmp/results-${ts}"
mkdir -p "${WORKDIR}"

# ---------- NMAP SCAN ----------
echo "[*] Running Nmap ${NMAP_OPTS} on ${TARGETS}"
nmap ${NMAP_OPTS} -T4 -oX "${WORKDIR}/nmap.xml" ${TARGETS}

# ---------- OpenSCAP SCAN (host vs. container) ----------
BASE_DS="${DS_FILE}"
if [[ -n "${TARGET_ROOT}" ]] && [[ -f "${TARGET_ROOT}${DS_FILE}" ]]; then
    echo "[*] Host SCAP datastream found at ${TARGET_ROOT}${DS_FILE}"
    BASE_DS="${TARGET_ROOT}${DS_FILE}"
    echo "[*] Running OpenSCAP on host FS at ${TARGET_ROOT}"
else
    if [[ -n "${TARGET_ROOT}" ]]; then
    echo "[!] Host SCAP datastream not found at ${TARGET_ROOT}${DS_FILE}, falling back to container"
    else
    echo "[*] No HOST_ROOT set; running OpenSCAP inside container"
    fi
fi

echo "[*] Invoking oscap xccdf eval ${OSCAP_OPTS} --profile ${PROFILE}"
oscap xccdf eval ${OSCAP_OPTS} \
    --profile "${PROFILE}" \
    ${TAILORING_FILE:+--tailoring-file "${TAILORING_FILE}"} \
    --results-arf "${WORKDIR}/oscap-results.xml" \
    "${BASE_DS}"

# ---------- PACKAGE RESULTS ----------
TARBALL="/tmp/scan-${ts}.tar.gz"
tar -czf "${TARBALL}" -C "${WORKDIR}" .

# ---------- UPLOAD or FINISH ----------
if [[ -n "${UPLOAD_URL}" ]]; then
    echo "[*] Uploading results to ${UPLOAD_URL}"
    curl -fsSL -X POST \
        -H "Authorization: Bearer ${API_KEY}" \
        -F "file=@${TARBALL}" \
        "${UPLOAD_URL}"
    echo "[+] Upload complete"
else
    echo "[!] No UPLOAD_URL provided; archive at ${TARBALL}"
fi
