#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2026 Damián Búho <damian.buho@proton.me>
#
# SPDX-License-Identifier: MIT

set -eou pipefail

# shellcheck source=/dev/null
. b19-i18n

I2P_DOT_DIR="${B19_HOME}/.i2p"
FAILURES=0

# Every entry the rendered config declares must be readable under the file the router actually loads from the router dir
check_dropins() {
  local source="$1" prefix="$2" suffix="$3" name_key="$4" dropin_dir="$5" keep_prefix="$6"
  local index=0 key name file line
  declare -A files=()
  while IFS= read -r line
  do
    [ -n "${line}" ] || continue
    index="${line#"${prefix}"}"
    name="${line#*=}"
    files["${index%%.*}"]="${name}"
  done < <(grep -E "^${prefix}[0-9]+\.${name_key}=" "${source}")
  for index in "${!files[@]}"
  do
    file="${dropin_dir}/$(printf '%02d' "${index}")-${files[${index}]}${suffix}"
    if [ ! -f "${file}" ]
    then
      b19-log bad "TEST.D" "$(_p "Drop-in not applied: %s" "${file}")"
      FAILURES=1
      continue
    fi
    while IFS= read -r line
    do
      key="${line#"${prefix}${index}."}"
      if [ "${keep_prefix}" = "yes" ]; then key="${prefix}0.${key}"; fi
      if ! grep --quiet --fixed-strings --line-regexp -- "${key}" "${file}"
      then
        b19-log bad "TEST.D" "$(_p "Applied drop-in lacks %s: %s" "${key}" "${file}")"
        FAILURES=1
      fi
    done < <(grep -E "^${prefix}${index}\." "${source}")
  done
}

check_dropins "${B19_HOME}/i2ptunnel.config" "tunnel." "-i2ptunnel.config" "name" "${I2P_DOT_DIR}/i2ptunnel.config.d" "no"
check_dropins "${B19_HOME}/clients.config" "clientApp." "-clients.config" "main" "${I2P_DOT_DIR}/clients.config.d" "yes"

# The router rewrites router.config on every boot, so an env-owned key it does not know survives and silently pins the router to first-boot values
while IFS= read -r line
do
  key="${line%%=*}"
  applied="$(sed -n "s/^${key}=//p" "${I2P_DOT_DIR}/router.config" | head -1)"
  if [ "${applied}" != "${line#*=}" ]
  then
    b19-log bad "TEST.D" "$(_p "Router dir has %s=%s, rendered config says %s" "${key}" "${applied}" "${line#*=}")"
    FAILURES=1
  fi
done < <(grep -E '^[A-Za-z0-9._]+=' "${B19_HOME}/router.config")

if [ "${FAILURES}" -ne 0 ]
then
  b19-log bad "TEST.D" "$(_ "The rendered config is not fully applied in the router dir")"
  exit 1
fi

b19-log good "TEST.D" "$(_p "Rendered config is applied in the router dir (%s)" "${I2P_DOT_DIR}")"