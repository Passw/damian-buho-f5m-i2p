#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2026 Damián Búho <damian.buho@proton.me>
#
# SPDX-License-Identifier: MIT

# Sourced by the entrypoint harness (set -e): fall off the end, never exit.
  I2P_DOT_DIR="${B19_HOME}/.i2p"
  # I2P reads only the per-entry drop-ins in <router dir>/<config>.config.d/ once that directory exists, so a config copied back into the router dir is ignored and every env var keeps the value of the first boot; the fifth argument is the key form I2P itself writes, since a tunnel drop-in drops the tunnel.N. prefix while a client drop-in keeps it renumbered to clientApp.0. The sixth is a manifest of drop-ins the image renders outside the rendered config (one per eepsite site), so they are not reported as unreviewed.
  _ac_project_dropins() {
    local _ac_source="$1" _ac_prefix="$2" _ac_suffix="$3" _ac_name_key="$4" _ac_keep_prefix="$5" _ac_manifest="$6"
    local _ac_dir="${I2P_DOT_DIR}/${_ac_source##*/}.d" _ac_written _ac_owned
    if [ ! -r "${_ac_source}" ]
    then
      b19-log error "I2P" "$(_p "Rendered config missing, cannot apply it: %s" "${_ac_source}")"
      return 1
    fi
    mkdir -p "${_ac_dir}"
    _ac_written="$(awk -v prefix="${_ac_prefix}" -v namekey="${_ac_name_key}" -v suffix="${_ac_suffix}" -v dir="${_ac_dir}" -v keep="${_ac_keep_prefix}" '
      index($0, "=") > 1 && index($0, prefix) == 1 {
        head = substr($0, length(prefix) + 1)
        dot = index(head, ".")
        eq = index(head, "=")
        idx = substr(head, 1, dot - 1)
        key = substr(head, dot + 1, eq - dot - 1)
        entry[idx] = entry[idx] (keep == "yes" ? prefix "0." : "") key "=" substr(head, eq + 1) "\n"
        if (key == namekey) name[idx] = substr(head, eq + 1)
        next
      }
      END {
        failed = 0
        for (idx in name) {
          file = dir "/" sprintf("%02d", idx) "-" name[idx] suffix
          printf "%s", entry[idx] > file
          close(file)
          print file
          written++
        }
        for (idx in entry) {
          if (!(idx in name)) {
            printf "%s%s.%s declares no %s key in %s\n", prefix, idx, suffix, namekey, ARGV[1] > "/dev/stderr"
            failed = 1
          }
        }
        if (failed) exit 1
      }
    ' "${_ac_source}")"
    _ac_owned="$(mktemp)"
    printf '%s\n' "${_ac_written}" | sed -e "s|^${_ac_dir}/||" > "${_ac_owned}"
    if [ -f "${_ac_manifest}" ]
    then
      cat "${_ac_manifest}" >> "${_ac_owned}"
    fi
    LC_ALL=C sort --unique --output "${_ac_owned}" "${_ac_owned}"
    while IFS= read -r _ac_stale
    do
      b19-log warn "I2P" "$(_p "Drop-in not rendered by this image, review it: %s" "${_ac_stale}")"
    done < <(find "${_ac_dir}" -maxdepth 1 -name '*.config' -printf '%f\n' | LC_ALL=C sort | comm -23 - "${_ac_owned}")
    rm -f "${_ac_owned}"
    b19-log info "I2P" "$(_p "Applied %s rendered entries as drop-ins in %s" "$(printf '%s\n' "${_ac_written}" | grep --count .)" "${_ac_dir}")"
  }
  # The router rewrites its own router.config on every start, so an env-owned key it does not know survives; re-apply ours over it and keep every key it wrote
  _ac_apply_router_keys() {
    local _ac_source="${B19_HOME}/router.config" _ac_target="${I2P_DOT_DIR}/router.config"
    local _ac_keys _ac_tmp
    if [ ! -r "${_ac_source}" ]
    then
      b19-log error "I2P" "$(_p "Rendered config missing, cannot apply it: %s" "${_ac_source}")"
      return 1
    fi
    if [ ! -f "${_ac_target}" ]
    then
      cp "${_ac_source}" "${_ac_target}"
      b19-log info "I2P" "$(_p "Seeded %s from the rendered config" "${_ac_target}")"
    fi
    _ac_keys="$(grep --count -E '^[A-Za-z0-9._]+=' "${_ac_source}")"
    _ac_tmp="$(mktemp)"
    awk -v source="${_ac_source}" '
      {
        eq = index($0, "=")
        key = (eq > 1) ? substr($0, 1, eq - 1) : ""
        if (FILENAME == source) {
          if (key != "") env[key] = substr($0, eq + 1)
          next
        }
        if (key != "" && key in env) {
          print key "=" env[key]
          delete env[key]
          next
        }
        print
      }
      END {
        for (key in env) print key "=" env[key]
      }
    ' "${_ac_source}" "${_ac_target}" > "${_ac_tmp}"
    cat "${_ac_tmp}" > "${_ac_target}"
    rm -f "${_ac_tmp}"
    chmod 0600 "${_ac_target}"
    b19-log info "I2P" "$(_p "Re-applied %s env-owned keys to %s" "${_ac_keys}" "${_ac_target}")"
  }
  _ac_project_dropins "${B19_HOME}/i2ptunnel.config" "tunnel." "-i2ptunnel.config" "name" "no" "${I2P_DOT_DIR}/eepsites.list"
  _ac_project_dropins "${B19_HOME}/clients.config" "clientApp." "-clients.config" "main" "yes" ""
  _ac_apply_router_keys
