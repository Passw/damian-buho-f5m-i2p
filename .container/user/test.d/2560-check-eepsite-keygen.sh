#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2026 Damián Búho <damian.buho@proton.me>
#
# SPDX-License-Identifier: MIT

set -eou pipefail

# shellcheck source=/dev/null
. b19-i18n

WORK_DIR="$(mktemp --directory)"
trap 'rm --recursive --force "${WORK_DIR}"' EXIT

fail() { b19-log bad "TEST.D" "$*"; exit 1; }

generate-eepsite-key >"${WORK_DIR}/key" 2>"${WORK_DIR}/stderr"

SIZE="$(stat --format %s "${WORK_DIR}/key")"
CERT="$(dd if="${WORK_DIR}/key" bs=1 skip=384 count=7 status=none | od --address-radix=n --format=x1 | tr --delete ' \n')"
b19-log info "TEST.D" "eepsite key: ${SIZE} bytes, certificate ${CERT}"

# Ed25519 key certificate: type 5, length 4, sig type 7, enc type 0 (679-byte eepPriv.dat)
[ "${SIZE}" -eq 679 ] || fail "eepsite key is ${SIZE} bytes, expected 679"
[ "${CERT}" = "05000400070000" ] || fail "eepsite key certificate is ${CERT}, expected Ed25519 05000400070000"
grep --quiet --ignore-case 'private key' "${WORK_DIR}/stderr" && fail "generate-eepsite-key printed private key material"
extract-b32-address "${WORK_DIR}/key" >/dev/null || fail "extract-b32-address cannot read the generated key"

b19-log good "TEST.D" "eepsite key is Ed25519 (${SIZE} bytes), no key material on stderr"
