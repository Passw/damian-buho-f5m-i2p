#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2026 Damián Búho <damian.buho@proton.me>
#
# SPDX-License-Identifier: MIT

set -eou pipefail

# shellcheck source=/dev/null
. b19-i18n

FRAGMENT="${B19_ENTRYPOINT_PATH}/200-prepare-eepsites.sh"
WORK_DIR="$(mktemp --directory)"
trap 'rm --recursive --force "${WORK_DIR}"' EXIT

fail() { b19-log bad "TEST.D" "$*"; exit 1; }

# render <mirrors dir> <default target> <tag> — source the eepsite fragment
# against a throwaway home and print the drop-ins it rendered into the router dir
render() {
  local mirrors_dir="$1" default_target="$2" tag="$3"
  (
    B19_HOME="${WORK_DIR}/home-${tag}"
    XDG_DATA_HOME="${WORK_DIR}/home-${tag}/data"
    F5M_I2P_EEPSITE_ENABLED=true
    F5M_I2P_EEPSITE_TARGET="localhost:8080"
    F5M_I2P_EEPSITE_KEY_FILE="${XDG_DATA_HOME}/eepsite/eepPriv.dat"
    F5M_I2P_EEPSITE_SPOOFED_HOST=""
    F5M_I2P_EEPSITE_INBOUND_LENGTH=3
    F5M_I2P_EEPSITE_INBOUND_QUANTITY=2
    F5M_I2P_EEPSITE_OUTBOUND_LENGTH=3
    F5M_I2P_EEPSITE_OUTBOUND_QUANTITY=2
    F5M_I2P_I2CP_BIND=127.0.0.1
    F5M_I2P_MIRROR_TARGET="${default_target}"
    F5M_I2P_MIRRORS_DIR="${mirrors_dir}"
    export B19_HOME XDG_DATA_HOME
    export F5M_I2P_EEPSITE_ENABLED F5M_I2P_EEPSITE_TARGET F5M_I2P_EEPSITE_KEY_FILE F5M_I2P_EEPSITE_SPOOFED_HOST
    export F5M_I2P_EEPSITE_INBOUND_LENGTH F5M_I2P_EEPSITE_INBOUND_QUANTITY F5M_I2P_EEPSITE_OUTBOUND_LENGTH F5M_I2P_EEPSITE_OUTBOUND_QUANTITY
    export F5M_I2P_I2CP_BIND F5M_I2P_MIRROR_TARGET F5M_I2P_MIRRORS_DIR
    mkdir -p "${B19_HOME}/.i2p"
    # shellcheck source=/dev/null
    . "${FRAGMENT}"
    ls -1 "${B19_HOME}/.i2p/i2ptunnel.config.d" 2>/dev/null || true
    cat "${B19_HOME}/.i2p/i2ptunnel.config.d"/*.config 2>/dev/null || true
  )
}

EMPTY_DIR="${WORK_DIR}/empty"
mkdir -p "${EMPTY_DIR}"
EMPTY_DROPINS="$(render "${EMPTY_DIR}" "" empty)"
[[ "${EMPTY_DROPINS}" == *site.config* ]] || fail "an empty mirrors dir must fall back to the env-driven site: ${EMPTY_DROPINS}"
[[ "${EMPTY_DROPINS}" == *"targetHost=localhost"* ]] || fail "the env-driven site must publish to F5M_I2P_EEPSITE_TARGET"

TWO_DIR="${WORK_DIR}/two"
mkdir -p "${TWO_DIR}"
printf 'target=forgejo:3000\n' > "${TWO_DIR}/kiota.conf"
printf '# dbuho.me routes by Host\n' > "${TWO_DIR}/dbuho.conf"
TWO_DROPINS="$(render "${TWO_DIR}" "mirrors:80" two)"
[[ "${TWO_DROPINS}" == *"targetHost=forgejo"* && "${TWO_DROPINS}" == *"targetPort=3000"* ]] || fail "site kiota does not publish to its own target"
[[ "${TWO_DROPINS}" == *"targetHost=mirrors"* && "${TWO_DROPINS}" == *"targetPort=80"* ]] || fail "a target-less file must fall back to the mirror target"
[[ "${TWO_DROPINS}" != *site.config* ]] || fail "mirrors.d replaces the env-driven site, it does not add to it"

BROKEN_DIR="${WORK_DIR}/broken"
mkdir -p "${BROKEN_DIR}"
printf 'target=forgejo:3000\n' > "${BROKEN_DIR}/kiota.conf"
printf 'listen 80\n' > "${BROKEN_DIR}/broken.conf"
BROKEN_DROPINS="$(render "${BROKEN_DIR}" "" broken)"
[[ "${BROKEN_DROPINS}" == *kiota.config* ]] || fail "a malformed file must not take the other sites down"
[[ "${BROKEN_DROPINS}" != *broken.config* ]] || fail "a malformed file must be skipped, not published"

b19-log good "TEST.D" "$(_ "mirrors.d eepsites: empty, two sites and a malformed file behave as declared")"
