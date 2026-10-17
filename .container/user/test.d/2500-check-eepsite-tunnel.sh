#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2026 Damián Búho <damian.buho@proton.me>
#
# SPDX-License-Identifier: MIT

set -eou pipefail

# shellcheck source=/dev/null
. b19-i18n

# The eepsite is an I2P-only service whose tunnel reverse-proxies to a webserver, so nothing local answers on the target unless one is wired — CI and a bare run have none
if [ "${F5M_I2P_EEPSITE_ENABLED:-false}" != "true" ]; then
  b19-log warn "TEST.D" "$(_ "Eepsite disabled, skipping tunnel check")"
  exit 0
fi

# The router reads the drop-ins in the router dir, not the rendered file in the base dir, and one drop-in per declared site
EEPSITE_DROPIN_DIR="${B19_HOME}/.i2p/i2ptunnel.config.d"
FOUND=0

while IFS= read -r EEPSITE_TUNNEL
do
  FOUND=$((FOUND + 1))
  # A relative key path resolves against the router dir, so I2P mints a throwaway identity
  key_file="$(sed -n 's/^privKeyFile=//p' "${EEPSITE_TUNNEL}")"
  if [ "${key_file#/}" = "${key_file}" ]; then
    b19-log bad "TEST.D" "$(_p "Eepsite key file is not absolute: %s" "${key_file}")"
    exit 1
  fi
  b19-log good "TEST.D" "$(_p "Eepsite tunnel %s is configured with an absolute key path (%s)" "$(basename "${EEPSITE_TUNNEL}")" "${key_file}")"
done < <(grep -l --regexp '^type=httpserver$' "${EEPSITE_DROPIN_DIR}"/*.config 2>/dev/null || true)

if [ "${FOUND}" -eq 0 ]; then
  b19-log bad "TEST.D" "$(_p "No eepsite tunnel applied in %s" "${EEPSITE_DROPIN_DIR}")"
  exit 1
fi

b19-log good "TEST.D" "$(_p "Eepsite tunnels are applied in the router dir (%s)" "${FOUND}")"
