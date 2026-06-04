# turbinobash — internal framework

This document explains **how `tb` works inside the repo**. Day-to-day hosting commands are in [README.md](../README.md).

## At a glance

**turbinobash** is not “a script collection”: it is a **small runtime** with two entry points:

| Entry | Role |
|-------|------|
| `tb_execution` | Run `tb <module> <path> …` — parse options, find script file, load module functions, **source** the script |
| `tb_completion` | Same routing on TAB — read `#C#` / `#C--#` comment lines in the target script and suggest words |

Commands are **files** under `modules/<module>/scripts/…` (often `scripts/sudo/…`). Paths containing `sudo/` re-run as root if needed. The same file is used for execution and completion.

**Why it feels different from argc/Bashly:** no code generation step; completion is driven by **comments in each script** (e.g. `#C# $(app_list)`), evaluated when you press TAB. Optional **domain overlays** (`modules/app.example.com/scripts/…`) and **profils/** hooks layer config without forking the whole tree.

Read **§2** for the call chain, **§4** for completion (`cindex`, `#C#`), **§5** for conventions when adding scripts.

---

## 1. Layout

```
/var/lib/turbinobash-web/          # TB_DIR (git clone)
├── modules/
│   ├── module/                    # core framework
│   │   ├── wrappers/              # /bin/tb entrypoints
│   │   ├── globals/funcs|confs/   # shared runtime (execution + completion)
│   │   └── scripts/               # meta commands (list, profils, …)
│   ├── app/                       # hosting applications
│   ├── mysql/                     # MariaDB/MySQL helpers
│   └── template/                  # joomla, pma, …
├── profils/                       # optional overlays (hostname/domain); may be empty
└── scripts/                       # host bootstrap (nginx.sh, …), not tb scripts
```

Each **module** is a directory under `modules/<name>/` with this convention:

| Path | Role |
|------|------|
| `scripts/<path>` | Runnable script (no `.sh` extension required) |
| `scripts/sudo/<path>` | Same, but requires root (auto `sudo` if caller is not root) |
| `funcs/execution` | Functions sourced before the script runs |
| `funcs/completion` | Extra completion helpers (usually sources `funcs/common`) |
| `confs/execution` | Variables sourced before the script (e.g. `d_apps=/apps`) |
| `confs/common` | Shared constants for the module |
| `templates/` | Config fragments (sed, nginx, …) |

Modules are discovered when a `scripts/` directory exists two levels below `modules/` (see `tb_complete_modules`).

---

## 2. Invocation chain

### 2.1 Install (`modules/module/wrappers/install`)

Run once as root (bootstrap scripts call it). It:

1. Resolves `TB_DIR` with `realpath`
2. Writes `/bin/tb` — a tiny launcher that sets `TB_DIR` and runs `tb_execution`
3. Writes `/etc/bash_completion.d/tb` — calls `tb_completion` with `COMP_WORDS`

Both runners use **`bash --norc --noprofile`** so behavior is predictable.

### 2.2 Execution (`tb_execution`)

Example: `tb app sudo/create myapp-v1 --certbot`

```
/bin/tb  →  tb_execution  →  resolve module + script  →  tb_to_include  →  source script
```

Steps:

1. **Parse** `A_PARAMS` (words not starting with `--`) and `A_OPTIONS` (`--foo`, `--bar=baz` → shell variables `foo=on`, `bar=baz` via `eval_long_options`).
2. **`TB_MODULE_NAME`** = first param (`app`).
3. **`TB_RUN_PATH`** = second param (`sudo/create`).
4. **`tb_run_place`** — hostname/domain/profil/“thing” context (see §4).
5. **`tb_run_path`** — locate script file (see §3).
6. **`--help`** — if present, print lines starting with `#H#` and exit.
7. **`sudo/` guard** — if path matches `sudo/` and UID ≠ 0, re-exec `sudo tb … --from-user=…`.
8. **`tb_to_include`** — load confs/funcs in a fixed order (profils + module + thing overlays).
9. **Run script** — `. $TB_RUN_FILE` with remaining `A_PARAMS` and options as arguments.

Scripts are **sourced**, not executed in a subshell: they can export state and use functions from `funcs/execution`.

### 2.3 Script path resolution (`tb_run_path`)

Looks for a file at:

```
$TB_MODULE_DIR<domain_suffix>/scripts/$TB_RUN_PATH
```

`<domain_suffix>` comes from **`domain_shrink_loop`**: for hostname `app.example.com` it tries ``, `.example.com`, `.com`, … until a file exists. This allows per-domain overrides:

```
modules/app/scripts/sudo/create
modules/app.example.com/scripts/sudo/create   # optional override
```

First existing file wins.

---

## 3. Context: hostname, domain, profils, “things”

### 3.1 `tb_run_place`

Builds context used by includes and some scripts:

| Variable | Meaning |
|----------|---------|
| `hostname` / `domain` | From `--hostname=`, `--domain=` or derived from system hostname |
| `TB_PROFIL` | Named profile under `profils/<name>/` if `--profil=` set |
| `TB_THING` | Third positional arg when path is `sudo/...` and a matching dir exists under `TB_DIR/<thing>s/` (legacy “things” layout; `app` uses `/apps` via `d_apps` instead) |

Include order in **`tb_to_include`** (simplified):

1. `profils/domain<pre|post>/` (+ hostname-specific pre/post)
2. `modules/<module>/` (+ domain suffix)
3. Thing/profil overlays when applicable
4. Module `confs/$TB_RAN` and `funcs/$TB_RAN` (`$TB_RAN` = `execution` or `completion`)

`TB_DIR_CURRENT` points at the module (or overlay) directory while sourcing each layer.

### 3.2 Profils (optional)

Under `TB_DIR/profils/` (often empty in a fresh clone):

- `domain/pre|post` — global hooks
- `hostname-<name>/pre|post` — per-host hooks
- `<profil>/confs|funcs/execution` — named profile

`tb module scripts/profils` manages them. Locks live in `profils/hostname-$(hostname)/locks/`.

---

## 4. Dynamic tab completion

Completion is a **second entry point**: same `TB_DIR`, but `TB_RAN=completion` and no script execution.

```
Tab  →  _tb()  →  tb_completion  →  compgen -W …  →  COMPREPLY
```

### 4.1 Word index (`cindex`)

Bash provides `COMP_WORDS` and `COMP_CWORD`. The wrapper sets:

- `CWORD` = current word being completed
- `CINDEX` = `COMP_CWORD - 1`

Options (`--certbot`, `--force`, …) are counted separately: they increment `i` but **not** `A_PARAMS`. Then:

```text
cindex = CINDEX - i    # index among non-option words only
```

| `cindex` | What is completed |
|----------|-------------------|
| `0` | Module names (`app`, `mysql`, `template`, `module`, …) |
| `1` | Script paths under `modules/<module>/…/scripts/` (e.g. `sudo/create`, `query`) |
| `≥ 2` | Values from the matching `#C#` line in the target script (see below) |

At `cindex ≥ 2`, the framework opens **`TB_RUN_FILE`** (same resolution as execution), reads annotation lines, and suggests words.

### 4.2 Annotation lines in scripts

Place these at the top of a script (comments, never executed):

#### `#C#` — positional argument completion

One line per **positional** argument **after** the script path.

```bash
#C# $(app_list)
#C# $(find /usr/bin/ -name "php*.*"| sed 's%/usr/bin/php%%')
#C--# --certbot --webdomain= --www
```

- Line 1 → first argument after `sudo/create` (e.g. app name).
- Line 2 → second argument (e.g. PHP version).
- Content after `#C#` is **evaluated in a shell subprocess** during completion: use command substitution `$(…)`, nested `$(tb mysql sudo/db/list)`, or static lists `All db app`.

The `All` keyword is a conventional literal offered to the user (e.g. backup all apps).

**Example** (`modules/mysql/scripts/sudo/db/dump`):

```bash
#C# $(mysql_db_list)
#C# $(mysql_table_list ${A_PARAMS[CINDEX-1]})
```

Here `${A_PARAMS[CINDEX-1]}` is the database name already typed on the command line, so table completion depends on the previous word.

#### `#C--#` — long options

Lists flags for this command. Shown when:

- completing `cindex == 1` (with script path), or
- the current `CWORD` starts with `-`

Options may be ` --flag` or ` --key=value` (tabs/spaces as separators in the comment).

#### `#H#` — help text

Shown when the user passes `--help` (execution path only):

```bash
#H# mode email webdomain php
```

#### `#C_JUMP#` — delegate completion to another script

If the selected `#C#` line is empty, completion can jump to another file’s `#C#` lines (rare; used for indirection).

#### Other tags

| Tag | Effect |
|-----|--------|
| `#DEBUG#` | Enable `shell_debug` tracing around script run |
| `#NO_DEBUG#` | Opposite / marker in meta scripts |
| `#C_LOOP#` | Appears in some `module` scripts; **not** interpreted by `tb_completion` today (reserved / legacy) |

### 4.3 Completion algorithm (positional)

When `cindex >= 2` and `TB_RUN_FILE` exists:

1. `completion_delta=1` (script path counts as one word).
2. Select line: `grep '^#C#' TB_RUN_FILE | sed "$(cindex - completion_delta)!d"` → keep one line.
3. Strip `#C#` prefix → `completion_list` (e.g. `$(app_list)`).
4. If `#C_JUMP#` set, repeat on jump target file.
5. **`compgenw "$completion_list"`** → `compgen -W` with expanded words.

Module-specific functions (`app_list`, `mysql_db_list`, …) must exist in sourced `funcs/completion` / `funcs/common` before evaluation.

### 4.4 Nested `tb` during completion

This is intentional:

```bash
#C# All $(app_list) $(tb mysql sudo/db/list)
```

While completing `tb app sudo/backup`, the shell runs `tb mysql sudo/db/list` to offer database names. Keep nested commands **fast** and non-destructive.

### 4.5 Permissions

`tb_complete_modules` lists all modules for root; non-root only sees modules whose `scripts/` tree is readable.

---

## 5. Conventions for writing scripts

### 5.1 Command line shape

```text
tb <module> <script-path> [positional args…] [--options]
```

- **Module**: directory name under `modules/`.
- **Script path**: path under `scripts/` without leading `scripts/` (e.g. `sudo/create`, `query`).
- **Positional args**: passed to the script after sourcing; order matters for `#C#` lines.
- **Options**: `--name` → `name=on`; `--name=value` → `name=value` (dash → underscore in variable names).

### 5.2 `tb_getopt` — declare expected parameters

Used at the start of scripts to bind positionals and flags to variables:

```bash
tb_getopt app php=8.3 - $@
# app = first positional, php defaults to 8.3, then - separates getopt-style flags
```

Rules:

- Before `-`: names with optional `default=` for positionals.
- After `-`: only `--long` options (mapped to variables).

Prefer **`tb_getopt`** over manual `$1/$2` so execution and completion stay aligned.

### 5.3 `sudo/` scripts

- Path contains `sudo/` → non-root users get automatic `sudo tb …`.
- Run sensitive operations only in these scripts (package install, vhost write, `userdel`, …).

### 5.4 Delegation between modules

Higher-level commands delegate to lower-level ones:

```bash
# modules/app/scripts/sudo/create
mode=$(cat /conf/mode)
tb app sudo/way/$mode/create $@
```

```bash
# modules/app/scripts/sudo/remove
tb app sudo/way/$mode/remove $@
```

`tb` is recursive: each call goes through `tb_execution` again.

### 5.5 Configuration on disk

| Location | Set by | Read by |
|----------|--------|---------|
| `/conf/mode`, `email`, `webdomain`, `php` | `tb app sudo/way/init` (bootstrap) | `app` create/remove |
| `/etc/tb/` | install wrapper | optional hooks |
| `/apps/<app>/` | `app` create | runtime, backups |
| Module `confs/*` | static in repo | all module scripts |

### 5.6 Naming

| Entity | Convention |
|--------|------------|
| App | `<name>-v<version>` e.g. `test-v1` |
| Linux user | same as app name |
| MariaDB DB/user | same as app name |
| Nginx/Apache site | `/etc/nginx/sites-enabled/10-<app>.conf` |
| PHP-FPM pool | `/etc/php/<ver>/fpm/pool.d/10-<app>.conf` |
| Socket | `/run/php/php-fpm-<app>.sock` |

### 5.7 Module responsibilities

| Module | Scope |
|--------|--------|
| `module` | Wrappers, completion engine, profils, shared funcs (`shell`, `file`, `system`, …) |
| `app` | Web apps, vhosts, FPM, SSL, backup, diskalert |
| `mysql` | Users, grants, DB create/remove, dump — thin layer over `mysql`/`mariadb` CLI |
| `template` | Download/install stock apps into `/apps/<app>/app/webroot` |

### 5.8 Templates (`template` module)

Template install scripts typically:

1. `tb_getopt app - $@`
2. Source `confs/base` (paths to stock archives)
3. Call `tb template sudo/<name>/download` if needed
4. Copy files into `webroot`
5. Call `tb app sudo/bulldozer` for permissions
6. Pipe SQL into `$MYSQL_CMD` (mariadb vs mysql detected in script)

Triggered from app create via `--template=pma` etc.

### 5.9 Error handling

- **`stop_err "message"`** — print red message, exit 1
- **`stop_ok "message"`** — print green message, exit 0
- **`ask_N_stop "question"`** — interactive yes/no before destructive ops
- Execution wrapper uses **`set -e`**

### 5.10 Changing the framework

After editing `modules/module/wrappers/tb_execution`, update the checksum if your install process uses it:

```text
modules/module/wrappers/tb_execution.md5
```

Re-run `modules/module/wrappers/install` on target hosts to refresh `/bin/tb`.

---

## 6. Mental model (diagram)

```text
                    ┌─────────────┐
                    │  /bin/tb    │
                    └──────┬──────┘
                           │
              ┌────────────┴────────────┐
              ▼                         ▼
     tb_execution                 tb_completion
              │                         │
     extract_params/options      cindex 0 → modules
              │                  cindex 1 → script paths
     tb_run_place + tb_run_path  cindex 2+ → #C# / #C--#
              │
     tb_to_include (profils + module funcs/confs)
              │
     source scripts/.../your-script
```

---

## 7. Quick reference — add a new script

1. Create `modules/<module>/scripts/sudo/mycommand` (or without `sudo/`).
2. Add headers:
   ```bash
   #C# $(my_thing_list)
   #C--# --force --dry-run
   #H# one line help for --help
   ```
3. Implement:
   ```bash
   tb_getopt thing=default - $@
   # work using $thing, $force, …
   return 0
   ```
4. Put helpers in `modules/<module>/funcs/common` and source them from `funcs/execution` / `funcs/completion`.
5. Open a **new shell**, test: `tb <module> sudo/mycommand <TAB><TAB>`.

---

## 8. Related files

| File | Purpose |
|------|---------|
| `modules/module/wrappers/tb_execution` | Main runner |
| `modules/module/wrappers/tb_completion` | Tab completion |
| `modules/module/globals/funcs/common` | `tb_run_path`, `tb_to_include`, `domain_shrink_loop` |
| `modules/module/globals/funcs/shell` | `tb_getopt`, `ask_N_stop`, `stop_err` |
| `modules/module/globals/funcs/completion` | `tb_complete_modules`, `tb_complete_scripts` |
