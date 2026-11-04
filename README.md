# fnm-nvm-compat

A zsh plugin that defines an `nvm` command and translates it to
[fnm](https://github.com/Schniz/fnm) (Fast Node Manager). Muscle memory,
scripts and project docs that say `nvm use 20` or `nvm install --lts` keep
working on a machine that runs fnm.

```console
$ nvm install 22        # fnm install 22, then fnm use 22
$ nvm alias default 22  # fnm default 22
$ nvm which 20          # path to node 20, resolved through fnm exec
```

## What this plugin does not do

It does not install fnm. If `fnm` is missing, `nvm` prints an error and exits
with status 127.

It does not set up fnm either. The plugin never runs `fnm env` and never
changes `PATH`; fnm's [shell setup](https://github.com/Schniz/fnm#shell-setup)
stays in your own config.

There is no real nvm inside: no `nvm.sh`, no `NVM_DIR`, no `nvm_*` helper
functions.

## Requirements

- zsh (tested with 5.9). The `nvm` function also works in bash (tested with
  5.3); completion is zsh-only.
- fnm on `PATH` and initialized by your shell config. Tested with fnm 1.39.0.
  A shell function named `fnm` also works; the plugin calls `fnm`, not
  `command fnm`, so your own wrapper keeps running.

The check for fnm happens each time `nvm` runs, not when the plugin loads, so
load order relative to your fnm setup does not matter.

## Installation

### oh-my-zsh

```sh
git clone https://github.com/rasmusbe/fnm-nvm-compat.git \
  "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/fnm-nvm-compat"
```

Then add it to `plugins` in `~/.zshrc`:

```sh
plugins=(... fnm-nvm-compat)
```

Do not enable oh-my-zsh's built-in `nvm` plugin at the same time (see
[Conflict with oh-my-zsh's nvm plugin](#conflict-with-oh-my-zshs-nvm-plugin)).

### Manual `source`

```sh
git clone https://github.com/rasmusbe/fnm-nvm-compat.git ~/.zsh/fnm-nvm-compat
```

```sh
# ~/.zshrc
source ~/.zsh/fnm-nvm-compat/fnm-nvm-compat.plugin.zsh
```

The plugin adds its own directory to `fpath`. If you source it after
`compinit`, it also registers the completion with `compdef`.

### zinit

```sh
zinit light rasmusbe/fnm-nvm-compat
```

### antidote

```sh
# ~/.zsh_plugins.txt
rasmusbe/fnm-nvm-compat
```

## Command mapping

| nvm | fnm | Notes |
| --- | --- | --- |
| `nvm install <v>` | `fnm install <v>`, then `fnm use <v>` | nvm switches to the new version after installing. fnm 1.39.0's `install --use` skips the switch for an already installed version when corepack is enabled, so the plugin runs `fnm use` itself. |
| `nvm install` | `fnm install`, then `fnm use` | Reads `.nvmrc` / `.node-version`. |
| `nvm install --lts` | `fnm install --lts`, then `fnm use lts-latest` | `lts-latest` is the alias `fnm install --lts` creates. |
| `nvm install node` / `stable` / `latest` | `fnm install --latest`, then `fnm use latest` | fnm reads these words as alias names and cannot install them. |
| `nvm uninstall <v>` | `fnm uninstall <v>` | |
| `nvm use <v>` | `fnm use <v>` | |
| `nvm use node` / `stable` | `fnm use latest` | `latest` is the alias `fnm install --latest` creates. |
| `nvm current` | `fnm current` | |
| `nvm ls`, `nvm list` | `fnm ls`, `fnm list` | |
| `nvm ls-remote` | `fnm list-remote` | |
| `nvm ls-remote <pattern>` | `fnm list-remote --filter <pattern>` | fnm has no positional pattern. The pattern is a version or semver range. |
| `nvm ls-remote --lts[=<name>]` | `fnm list-remote --lts[=<name>]` | Flags pass through unchanged. `--no-colors` is dropped. |
| `nvm version-remote [<pattern>]` | `fnm list-remote [--filter <pattern>] --latest` | Prints the version only. Without a pattern this is whatever fnm reports as latest, which can be a pre-release. |
| `nvm alias` | `fnm ls` | fnm has no command that lists only aliases; `fnm ls` shows aliases next to each version. |
| `nvm alias <name> <v>` | `fnm alias <v> <name>` | Argument order is reversed in fnm. |
| `nvm alias default <v>` | `fnm default <v>` | |
| `nvm alias default` | `fnm default` | Prints the default. |
| `nvm unalias <name>` | `fnm unalias <name>` | |
| `nvm run <v> [args]` | `fnm exec --using=<v> -- node [args]` | |
| `nvm exec <v> <cmd> [args]` | `fnm exec --using=<v> -- <cmd> [args]` | |
| `nvm which`, `nvm which current` | (none) `command -v node` | fnm has no `which` command, and `fnm current` prints a version, not a path. |
| `nvm which <v>` | (none) `fnm exec --using=<v> -- sh -c 'command -v node'` | |
| `nvm which system` | (none) first `node` on `PATH` outside fnm's multishell directories | `fnm exec --using=system` keeps fnm's multishell `bin` on `PATH`, so `command -v node` would find fnm's active version. |
| `nvm version [current]` | `fnm current` | |
| `nvm version <v>` | `fnm exec --using=<v> -- node --version` | Resolves `<v>` to an installed version. |
| `nvm --version` | `fnm --version` | Prints fnm's version, not an nvm version. |
| `nvm cache clear` | (none) | No-op. fnm's directory (`$FNM_DIR`) holds only installed versions and aliases, no download cache. |

Any other command is passed to fnm as is, with a warning on stderr.

## Not supported

These print an error and return 1 without calling fnm:

- `nvm deactivate`: fnm has no way to remove its Node from `PATH` in the
  current shell. Start a new shell, or `nvm use system`.
- `nvm unload`: there is no nvm to unload. Remove the plugin from your config
  and start a new shell.
- `nvm reinstall-packages`: fnm has no equivalent. Reinstall global packages
  with npm.

Also not translated:

- `nvm ls <pattern>`: `fnm ls` takes no pattern, so fnm rejects it.
- `nvm run` and `nvm exec` without a version: nvm falls back to `.nvmrc`, but
  this plugin needs the version as the first argument.
- `nvm install` options such as `--reinstall-packages-from`, `-s` or
  `--default`. They are passed to fnm, which rejects what it does not know.
- `nvm cache dir`, `nvm install-latest-npm`, `nvm set-colors`.

## Conflict with oh-my-zsh's nvm plugin

oh-my-zsh ships a plugin called `nvm` that loads the real nvm by sourcing
`$NVM_DIR/nvm.sh`. That defines an `nvm` function, so the two plugins
overwrite each other and whichever loads last wins. In lazy mode
(`zstyle ':omz:plugins:nvm' lazy yes`) it also wraps `node`, `npm`, `npx`,
`pnpm`, `yarn` and `corepack` in functions that try to load nvm on first use.
Its autoload option calls nvm internals such as `nvm_find_nvmrc`, which this
plugin does not provide. Enable only one of them.

If you use fnm's `--use-on-cd` for automatic version switching, you do not
need the oh-my-zsh plugin's autoload feature.

## Completion

`nvm <TAB>` completes the supported subcommands. Version arguments complete
from `fnm ls`:

- `use`, `uninstall`, `run`, `exec`, `which` and `version`: installed versions
  and aliases (`which` and `version` also offer `current`).
- `alias`: alias names first, then versions.
- `unalias`: alias names.
- `install`: `lts/*`, `latest`, `node`, `--lts` and `--latest`. No network
  calls.

## Tests

```sh
zsh tests/run.zsh
```

The tests run `nvm` against a fake `fnm` (`tests/stub/fnm`) that logs its
arguments, and compare each call with the expected fnm command. They need
neither a real fnm nor network access.

- The mapping tests run in zsh, and again in bash when bash is installed.
- The completion tests are zsh-only. They start an interactive zsh through the
  `zsh/zpty` module and capture what `compadd` receives.
- The `fpath` handling in the plugin uses zsh-only syntax and is skipped in
  bash.

## License

[MIT](LICENSE)
