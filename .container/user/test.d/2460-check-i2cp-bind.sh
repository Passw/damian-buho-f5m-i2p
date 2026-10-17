#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2026 Damián Búho <damian.buho@proton.me>
#
# SPDX-License-Identifier: MIT

set -eou pipefail

# shellcheck source=/dev/null
. b19-i18n

I2P_I2CP_BIND="${F5M_I2P_I2CP_BIND:-127.0.0.1}"
ROUTER_CONFIG="${B19_HOME}/.i2p/router.config"
TUNNELS_DIR="${B19_HOME}/.i2p/i2ptunnel.config.d"
FAILURES=0

# I2CP carries no authentication, so the socket the tunnels dial must stay on the address the operator asked for and nowhere else
EXPECTED_BIND_ALL="false"
[ "${I2P_I2CP_BIND}" = "127.0.0.1" ] || EXPECTED_BIND_ALL="true"

if ! grep --quiet --line-regexp "i2cp.tcp.bindAllInterfaces=${EXPECTED_BIND_ALL}" "${ROUTER_CONFIG}"; then
  b19-log bad "TEST.D" "$(_p "I2CP is not bound as %s asked in %s" "${I2P_I2CP_BIND}" "${ROUTER_CONFIG}")"
  FAILURES=1
fi

while IFS= read -r line
do
  if [ "${line}" != "i2cpHost=${I2P_I2CP_BIND}" ]
  then
    b19-log bad "TEST.D" "$(_p "Tunnel dials I2CP at %s, expected %s" "${line#i2cpHost=}" "${I2P_I2CP_BIND}")"
    FAILURES=1
  fi
done < <(grep --recursive --no-filename --include='*-i2ptunnel.config' '^i2cpHost=' "${TUNNELS_DIR}" 2>/dev/null)

if [ "${FAILURES}" -ne 0 ]
then
  b19-log bad "TEST.D" "$(_ "The I2CP bind address is not applied consistently")"
  exit 1
fi

b19-log good "TEST.D" "$(_p "I2CP is bound to %s everywhere (%s)" "${I2P_I2CP_BIND}" "${ROUTER_CONFIG}")"