#!/usr/bin/env zsh
# Test runner for fnm-nvm-compat.
#
# Runs `nvm ...` against a fake fnm (tests/stub/fnm) that logs its arguments,
# and checks that each nvm command becomes the expected fnm call. Needs no real
# fnm and no network.
#
# The mapping tests run in zsh, and also in bash when bash is installed (bash
# support is a bonus, not a requirement). The completion tests are zsh-only:
# they drive an interactive zsh through zsh/zpty.
#
# Usage: zsh tests/run.zsh

emulate -L zsh
setopt err_return no_unset pipe_fail

ROOT=${0:A:h:h}
PLUGIN=$ROOT/fnm-nvm-compat.plugin.zsh
STUB=$ROOT/tests/stub
TMP=$(mktemp -d)
trap 'rm -rf -- $TMP' EXIT

integer passed=0 failed=0
SHELL_NAME=
SHELL_CMD=()

# Resolve shells before PATH is restricted in the child.
ZSH_BIN=${commands[zsh]}
BASH_BIN=${commands[bash]-}

# run_nvm <nvm args...>: run nvm in a clean child shell. Sets $out, $err, $rc
# and $calls (the fnm stub log).
run_nvm() {
  local log=$TMP/fnm.log
  : >| $log
  rc=0
  env -i HOME=$TMP PATH=$STUB:/usr/bin:/bin FNM_STUB_LOG=$log \
    $SHELL_CMD -c 'source "$1"; shift; nvm "$@"' nvm-test $PLUGIN "$@" \
    >| $TMP/out 2>| $TMP/err || rc=$?
  out=$(<$TMP/out)
  err=$(<$TMP/err)
  calls=$(<$log)
}

pass() { (( ++passed )); print -r -- "ok   [$SHELL_NAME] $1"; }
fail() {
  (( ++failed ))
  print -r -- "FAIL [$SHELL_NAME] $1"
  shift
  print -rl -- "     "$^@
}

# expect <expected fnm calls> <nvm args...>
# Expected calls are newline-separated lines in the stub's [arg][arg] format;
# an empty string means fnm must not be called.
expect() {
  local want=$1; shift
  run_nvm "$@"
  if [[ $calls == $want ]]; then
    pass "nvm $*"
  else
    fail "nvm $*" "want: ${want:-<no fnm call>}" "got:  ${calls:-<no fnm call>}" "stderr: $err"
  fi
}

# expect_out <expected stdout> <nvm args...>
expect_out() {
  local want=$1; shift
  run_nvm "$@"
  if [[ $out == $want ]]; then
    pass "nvm $* prints '$want'"
  else
    fail "nvm $* output" "want: $want" "got:  $out" "stderr: $err"
  fi
}

# expect_rc <expected exit code> <nvm args...>
expect_rc() {
  local want=$1; shift
  run_nvm "$@"
  if [[ $rc == $want ]]; then
    pass "nvm $* exits $want"
  else
    fail "nvm $* exit code" "want: $want" "got:  $rc" "stderr: $err"
  fi
}

mapping_tests() {
  # No command: usage, and no failing `shift`.
  expect '' ; expect_rc 0
  run_nvm
  [[ $out == *Usage:* ]] && pass "nvm prints usage" || fail "nvm prints usage" "got: $out"
  expect '' help

  # install, then use: fnm install --use skips the switch for an installed
  # version when corepack is enabled.
  expect $'[install][20]\n[use][20]'           install 20
  expect $'[install]\n[use]'                   install
  expect $'[install][--lts]\n[use][lts-latest]' install --lts
  expect $'[install][lts/iron]\n[use][lts/iron]' install lts/iron
  expect $'[install][--latest]\n[use][latest]' install node
  expect $'[install][--latest]\n[use][latest]' install stable
  expect $'[install][--latest]\n[use][latest]' install latest
  expect $'[install][--latest]\n[use][latest]' install --latest

  expect '[uninstall][18]'                uninstall 18

  # use: node/stable become the `latest` alias.
  expect '[use][20]'                      use 20
  expect '[use]'                          use
  expect '[use][latest]'                  use node
  expect '[use][lts/*]'                   use 'lts/*'

  expect '[current]'                      current
  expect '[ls]'                           ls
  expect '[list]'                         list

  # ls-remote: flags pass through, a bare pattern becomes --filter.
  expect '[list-remote]'                  ls-remote
  expect '[list-remote]'                  list-remote
  expect '[list-remote][--lts]'           ls-remote --lts
  expect '[list-remote][--lts=iron]'      ls-remote --lts=iron
  expect '[list-remote][--filter][22]'    ls-remote 22
  expect '[list-remote][--filter][22][--lts]' ls-remote 22 --lts
  expect '[list-remote]'                  ls-remote --no-colors

  expect '[list-remote][--filter][20][--latest]' version-remote 20
  expect '[list-remote][--lts][--latest]' version-remote --lts
  expect_out 'v20.11.1'                   version-remote 20

  # alias: nvm takes <name> <version>, fnm takes <version> <name>.
  expect '[alias][20][myproject]'         alias myproject 20
  expect '[default][20]'                  alias default 20
  expect '[default]'                      alias default
  expect '[ls]'                           alias
  expect '[unalias][myproject]'           unalias myproject

  expect '[exec][--using=20][--][node][app.js][--flag]' run 20 app.js --flag
  expect '[exec][--using=20][--][npm][test]'            exec 20 npm test

  # which: no fnm which; PATH lookup or fnm exec.
  expect ''                               which
  expect_out "$STUB/node"                 which
  expect ''                               which current
  expect '[exec][--using=20][--][sh][-c][command -v node]' which 20
  expect_out "$STUB/node"                 which 20

  expect '[current]'                      version
  expect '[current]'                      version current
  expect '[exec][--using=20][--][node][--version]' version 20
  expect '[--version]'                    --version

  # cache clear: no fnm call, no fnm env parsing, success.
  expect ''                               cache clear
  expect_rc 0                             cache clear

  # Unsupported commands fail without calling fnm.
  expect ''                               deactivate
  expect_rc 1                             deactivate
  expect_rc 1                             unload
  expect_rc 1                             reinstall-packages 20

  # Missing fnm: clear error, exit 127, no setup attempt.
  local saved_stub=$STUB
  STUB=$TMP/empty
  mkdir -p $STUB
  expect_rc 127 ls
  [[ $err == *"fnm not found"* ]] && pass "missing fnm message" || fail "missing fnm message" "got: $err"
  STUB=$saved_stub
}

# ── Completion (zsh only) ───────────────────────────────────────────────────
# Start an interactive `zsh -f` in a pty, load compinit and the plugin, press
# Tab after a partial command line, and collect what compadd receives.

comp_init() {
  zmodload zsh/zpty
  mkdir -p $TMP/zdot
  # The setup goes in a .zshrc so it is not typed through zle.
  cat >| $TMP/zdot/.zshrc <<EOF
PS1='> '
unsetopt zle_bracketed_paste 2>/dev/null
autoload -Uz compinit && compinit -u -D
source ${(q)PLUGIN}
# Print each match compadd would add, prefixed with <M>. Calls that only
# collect or filter (-O, -A, -D) go to the real compadd.
compadd() {
  if [[ \${\${@[1,(i)(-|--)]}} == *-(O|A|D)\\ * ]]; then builtin compadd "\$@"; return; fi
  local -a __hits
  builtin compadd -A __hits "\$@"
  (( \$#__hits )) && print -rl -- "<M>"\${^__hits}
  return 0
}
comp-capture() {
  _main_complete
  compstate[insert]=''
  compstate[list]=''
  print -r -- '<END>'
}
zle -C comp-capture complete-word comp-capture
bindkey '^I' comp-capture
print -r -- '<READY>'
EOF
  zpty comp env -i HOME=$TMP ZDOTDIR=$TMP/zdot TERM=dumb PATH=$STUB:/usr/bin:/bin \
    FNM_STUB_LOG=$TMP/comp.log $ZSH_BIN -d -i
  comp_read '<READY>'
}

# comp_read <marker>: read pty output into $buf until <marker> shows up
# (or about 5 seconds pass).
comp_read() {
  local chunk
  integer tries=0
  buf=
  while [[ $buf != *"$1"* ]] && (( tries < 50 )); do
    if zpty -r -t comp chunk; then
      buf+=$chunk
    else
      (( ++tries ))
      sleep 0.1
    fi
  done
}

# complete <partial command line>: sets $matches.
complete() {
  local buf line
  matches=()
  zpty -w -n comp "$1"$'\t'
  comp_read '<END>'
  # The first match can share a line with the echoed command line. Matches
  # arrive quoted for insertion (lts/\*), so unquote them.
  for line in ${(f)buf//$'\r'/}; do
    [[ $line == *'<M>'* ]] && matches+=(${(Q)${line##*<M>}})
  done
  # Clear the line for the next test.
  zpty -w -n comp $'\C-u'
}

expect_match() {
  local input=$1; shift
  complete "$input"
  local m missing=()
  for m in "$@"; do
    (( ${matches[(Ie)$m]} )) || missing+=($m)
  done
  if (( $#missing == 0 )); then
    pass "complete '$input' offers $*"
  else
    fail "complete '$input'" "missing: $missing" "got: $matches"
  fi
}

completion_tests() {
  local -a matches
  local buf
  comp_init
  if [[ $buf != *'<READY>'* ]]; then
    fail "completion shell did not start" "$buf"
    zpty -d comp
    return 0
  fi

  expect_match 'nvm '            install use ls alias which exec run
  expect_match 'nvm use '        v18.19.0 v20.11.1 default lts-iron system
  expect_match 'nvm uninstall '  v18.19.0 v20.11.1
  expect_match 'nvm which '      current v20.11.1
  expect_match 'nvm run '        v20.11.1 default
  expect_match 'nvm exec '       v20.11.1 default
  expect_match 'nvm alias '      default lts-iron
  expect_match 'nvm alias foo '  v20.11.1 lts-iron
  expect_match 'nvm unalias '    lts-iron
  expect_match 'nvm install '    'lts/*' latest node --lts
  expect_match 'nvm cache '      clear
  zpty -d comp
}

fpath_test() {
  local dir
  dir=$(env -i HOME=$TMP PATH=$STUB:/usr/bin:/bin $ZSH_BIN -f -c \
    'source "$1"; print -r -- $fpath[1]' t $PLUGIN)
  [[ $dir == $ROOT ]] && pass "plugin dir is first on fpath" \
    || fail "plugin dir on fpath" "want: $ROOT" "got: $dir"
}

no_fnm_env_test() {
  if grep -nE 'fnm[[:space:]]+env' $PLUGIN $ROOT/_nvm >/dev/null; then
    fail "plugin calls fnm env" "$(grep -nE 'fnm[[:space:]]+env' $PLUGIN $ROOT/_nvm)"
  else
    pass "plugin does not call fnm env"
  fi
}

SHELL_NAME=zsh SHELL_CMD=($ZSH_BIN -f)
mapping_tests
fpath_test
no_fnm_env_test
completion_tests

if [[ -n $BASH_BIN ]]; then
  SHELL_NAME=bash SHELL_CMD=($BASH_BIN --noprofile --norc)
  mapping_tests
else
  print -r -- "skip [bash] bash not installed"
fi

print -r -- ""
print -r -- "$passed passed, $failed failed"
(( failed == 0 ))
