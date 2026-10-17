#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2026 Damián Búho <damian.buho@proton.me>
#
# SPDX-License-Identifier: MIT

set -eou pipefail

# shellcheck source=/dev/null
. b19-i18n

# A var no template or script reads is a knob that does nothing; a var a template reads with no Dockerfile default and no j2 fallback renders empty and leaves the config at its build-time value
TEMPLATES=()
mapfile -t TEMPLATES < <(find /app -maxdepth 1 -name '*.j2')
SOURCES=()
mapfile -t SOURCES < <(find /entrypoint.d /healthcheck.d /test.d /command.d /tools.d -type f 2>/dev/null)
FAILURES=0

while IFS= read -r declared
do
  if ! grep --quiet --fixed-strings -- "${declared}" "${TEMPLATES[@]}" "${SOURCES[@]}" 2>/dev/null
  then
    b19-log bad "TEST.D" "$(_p "Declared but never read: %s" "${declared}")"
    FAILURES=1
  fi
done < <(env | sed -n 's/^\(F5M_I2P_[A-Z0-9_]*\)=.*/\1/p' | LC_ALL=C sort)

while IFS= read -r reference
do
  if ! printenv "${reference}" >/dev/null 2>&1 && ! grep --quiet --regexp="ENV\.${reference}[[:space:]]*|[[:space:]]*default" "${TEMPLATES[@]}" 2>/dev/null
  then
    b19-log bad "TEST.D" "$(_p "Read but never declared: %s" "${reference}")"
    FAILURES=1
  fi
done < <(grep --only-matching --no-filename --regexp='ENV\.F5M_I2P_[A-Z0-9_]*' "${TEMPLATES[@]}" | sed 's/^ENV\.//' | LC_ALL=C sort --unique)

if [ "${FAILURES}" -ne 0 ]
then
  b19-log bad "TEST.D" "$(_ "The declared environment surface and its readers disagree")"
  exit 1
fi

b19-log good "TEST.D" "$(_p "Router var surface agrees with its readers (%s templates)" "${#TEMPLATES[@]}")"