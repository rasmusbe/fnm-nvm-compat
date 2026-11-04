# fnm-nvm-compat: an `nvm` command that translates nvm commands to fnm.
#
# This file does not install or set up fnm. It expects `fnm` to be on PATH
# and already initialized by your own shell configuration.

_nvm_compat_usage() {
  cat <<'EOF'
nvm (fnm-nvm-compat): nvm commands translated to fnm

Usage:
  nvm install [<version>|--lts|--latest]   Install a version and switch to it
  nvm uninstall <version>                  Uninstall a version
  nvm use [<version>]                      Switch version (reads .nvmrc without args)
  nvm current                              Print the active version
  nvm ls | list                            List installed versions and aliases
  nvm ls-remote | list-remote [<pattern>] [--lts[=<name>]]
                                           List remote versions
  nvm version-remote [<pattern>] [--lts]   Print the newest remote version matching
  nvm alias [<name> <version>]             Create an alias, or list aliases
  nvm alias default [<version>]            Set or print the default version
  nvm unalias <name>                       Remove an alias
  nvm run <version> [<args>...]            Run node from <version>
  nvm exec <version> <command> [<args>...] Run <command> with <version> on PATH
  nvm which [current|<version>]            Print the path to the node binary
  nvm version [current|<version>]          Resolve a version to an installed one
  nvm cache clear                          No-op (fnm keeps no download cache)
  nvm --version                            Print the fnm version
EOF
}

nvm() {
  if [[ $# -eq 0 ]]; then
    _nvm_compat_usage
    return 0
  fi

  local cmd="${1}"
  shift

  case "${cmd}" in
    help|--help|-h)
      _nvm_compat_usage
      return 0
      ;;
  esac

  # fnm must already be installed and set up by the user's shell config.
  # `command -v` also finds a shell function named fnm.
  if ! command -v fnm >/dev/null 2>&1; then
    echo "[nvm-compat] fnm not found. Install fnm and set it up in your shell" >&2
    echo "[nvm-compat] (see https://github.com/Schniz/fnm#shell-setup)." >&2
    return 127
  fi

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
