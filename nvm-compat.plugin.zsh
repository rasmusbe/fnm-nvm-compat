#!/usr/bin/env bash
# nvm-compat: Drop-in nvm wrapper that delegates to fnm
# Usage: source this file, or add to your shell rc

nvm() {
  local cmd="${1}"
  shift

  case "${cmd}" in

    # ── Identical passthrough ──────────────────────────────────────────────
    install|uninstall|use|current|ls|list|ls-remote|list-remote|unalias)
      fnm "${cmd}" "$@"
      ;;

    # ── version / --version ───────────────────────────────────────────────
    version|--version)
      fnm --version
      ;;

    # ── alias ─────────────────────────────────────────────────────────────
    # nvm:  alias <name> <version>
    # fnm:  alias <version> <name>   ← args are reversed!
    # Special case: nvm alias default <ver> → fnm default <ver>
    alias)
      local name="${1}"
      local ver="${2}"
      if [[ "${name}" == "default" ]]; then
        fnm default "${ver}"
      elif [[ -z "${name}" ]]; then
        # nvm alias with no args lists aliases — fnm has no direct equivalent
        echo "[nvm-compat] fnm has no 'list aliases' command." >&2
        return 1
      else
        fnm alias "${ver}" "${name}"
      fi
      ;;

    # ── run ───────────────────────────────────────────────────────────────
    # nvm:  run <version> [args...]
    # fnm:  exec --using=<version> -- node [args...]
    run)
      local ver="${1}"
      shift
      fnm exec --using="${ver}" -- node "$@"
      ;;

    # ── exec ──────────────────────────────────────────────────────────────
    # nvm:  exec <version> <command> [args...]
    # fnm:  exec --using=<version> -- <command> [args...]
    exec)
      local ver="${1}"
      shift
      fnm exec --using="${ver}" -- "$@"
      ;;

    # ── which ─────────────────────────────────────────────────────────────
    # nvm which <version>  →  fnm which (always prints current node path)
    # Approximation: use + which
    which)
      local ver="${1}"
      if [[ -n "${ver}" ]]; then
        echo "[nvm-compat] 'nvm which <version>' approximated: switching temporarily not supported." >&2
        echo "[nvm-compat] Run 'fnm use ${ver} && fnm which' manually." >&2
        return 1
      fi
      fnm which
      ;;

    # ── deactivate ────────────────────────────────────────────────────────
    deactivate)
      echo "[nvm-compat] 'nvm deactivate' has no fnm equivalent." >&2
      echo "[nvm-compat] You can unset PATH entries manually or start a new shell." >&2
      return 1
      ;;

    # ── reinstall-packages ────────────────────────────────────────────────
    reinstall-packages)
      echo "[nvm-compat] 'nvm reinstall-packages' has no fnm equivalent." >&2
      return 1
      ;;

    # ── cache clear ───────────────────────────────────────────────────────
    cache)
      if [[ "${1}" == "clear" ]]; then
        echo "[nvm-compat] 'nvm cache clear' has no fnm equivalent." >&2
        echo "[nvm-compat] Manually remove: $(fnm env | grep FNM_DIR | cut -d= -f2)" >&2
      else
        echo "[nvm-compat] Unknown nvm cache subcommand: ${1}" >&2
      fi
      return 1
      ;;

    # ── version-remote ────────────────────────────────────────────────────
    version-remote)
      local pattern="${1}"
      echo "[nvm-compat] Approximating with 'fnm ls-remote' filtered by '${pattern}':" >&2
      fnm ls-remote | grep "${pattern}"
      ;;

    # ── unload ────────────────────────────────────────────────────────────
    unload)
      echo "[nvm-compat] 'nvm unload' has no fnm equivalent. Start a new shell." >&2
      return 1
      ;;

    # ── Fallback ──────────────────────────────────────────────────────────
    *)
      echo "[nvm-compat] Unknown or unsupported nvm command: '${cmd}'" >&2
      echo "[nvm-compat] Attempting passthrough to fnm..." >&2
      fnm "${cmd}" "$@"
      ;;
  esac
}
