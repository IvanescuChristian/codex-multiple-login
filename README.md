# Codex Multiple Login

Adds a `--login_new <profile>` flag to the `codex` CLI (OpenAI Codex) so you
can run a session under a different account, scoped to that one invocation,
without affecting any other running (or future) `codex` session.

## Why

`codex` keeps its login (`auth.json`) and state in one directory, by default
`~/.codex`, shared by every `codex` process. `CODEX_HOME` is an environment
variable codex already supports for pointing a process at a different
directory; this project wraps that into a single flag.

## How it works

`bin/codex` is a small bash wrapper that:
- passes everything through unchanged to the real `codex` when no
  `--login_new` flag is given;
- with `--login_new <profile>`, runs that one invocation with
  `CODEX_HOME=$HOME/.codex-profiles/<profile>/` (created if missing; codex
  refuses a `CODEX_HOME` that does not exist). The variable is passed only to
  that child process, never exported into your shell. `HOME` is NOT changed,
  so git, ssh and everything else behave normally.

## Install

```sh
./install.sh                          # installs bin/codex to ~/.local/bin
./install.sh /some/dir                # or a custom directory
./install.sh --uninstall [dir]
```

The wrapper must come BEFORE the real `codex` on `PATH`. If the real `codex`
is a plain file at the target path the installer refuses (it would overwrite
it); use another directory:

```sh
mkdir -p ~/bin-wrappers && ./install.sh ~/bin-wrappers
export PATH="$HOME/bin-wrappers:$PATH"     # add to your shell startup file
```

The installer records the real binary's path in `<dir>/.codex-real-bin`, and
warns if `codex` on your `PATH` does not resolve to the wrapper.

## Usage

```sh
# First time: creates the profile. Then sign in inside it, once:
codex --login_new work login                 # or: codex --login_new work login --device-auth

# Free sign-in check (no model call):
codex --login_new work login status

# Later: reuses the saved login.
codex --login_new work

codex --login_new            # no name: list profiles
codex --login_new --list     # profiles and login status
codex --login_new --help
codex                        # no flag: the real codex, untouched
```

Profiles live under `$HOME/.codex-profiles/<name>/` (override the base with
`CODEX_LOGIN_NEW_PROFILES_DIR`). Names may use letters, numbers, `.`, `_`,
`-`. `--list` reports "logged in" when `auth.json` exists in the profile.

## Tests

```sh
bash tests/test_wrappers.sh
```

Offline: it uses a fake `codex` and a temporary `HOME`; no network, no login.

## Limitations and what is NOT verified

- Bash only (Linux/macOS/WSL). No Windows port.
- Verified: under a scratch `CODEX_HOME`, `codex login status` reports "Not
  logged in" while the default home reports logged in, i.e. `CODEX_HOME`
  isolation takes effect.
- NOT VERIFIED: a completed login persisting in a profile, and two accounts
  running side by side (needs interactive logins).
- NOT VERIFIED: that `codex login` (as opposed to a first-run prompt) is the
  only way to sign in inside a profile.
- Use of multiple accounts is subject to the provider's terms of service.

## Credit / License

MIT licensed; see `LICENSE`. Copyright (c) 2026 IvanescuChristian. Keep the
copyright notice in copies. Not affiliated with OpenAI.
