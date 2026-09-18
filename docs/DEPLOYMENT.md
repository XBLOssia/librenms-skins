# Deployment

Installing a skin on a LibreNMS host, and getting it back off again.

Written against LibreNMS master @ `63e0394`. Target host: `REDACTED-HOST`.

---

## Deployed instances

| Host | Skin | LibreNMS version | Installed | Mode |
|---|---|---|---|---|
| `REDACTED-HOST` | zerg | `26.8.1-147-g63e0394bd1` | 2026-09-18 | link |

The host version matches the commit the skins were developed and verified
against exactly, so there is no selector drift to account for.

Layout on that host:

```
/opt/librenms-skins                          repo, owned librenms:librenms
/opt/librenms/html/css/custom/zerg   ->      /opt/librenms-skins/skins/zerg
webui.custom_css                     =       ["css/custom/zerg/zerg.css"]
```

Files were uploaded over SFTP rather than cloned, because the repo is private
and that avoids putting a git credential on the monitoring host. The trade-off
is that `git pull` will not update it in place — re-upload, or add a deploy key
and convert `/opt/librenms-skins` into a real clone.

To switch the active skin on that host:

```bash
sudo -u librenms /opt/librenms-skins/scripts/install.sh terran
```

---

## Does this survive `daily.sh`?

**Yes, and unlike a core-file patch it does so by design rather than by luck.**

This was verified by reading `daily.sh` rather than assuming. The update path
uses only:

```
git pull --quiet
git checkout master | <branch> | ${latest_hash}
git checkout --quiet -- composer.json composer.lock
```

There is **no `git clean`** anywhere in `daily.sh` or `daily.php`. `git pull`
and `git checkout` do not delete untracked or ignored files, and
`html/css/custom/*` is in LibreNMS's own `.gitignore`. So the skin directory is
invisible to the updater.

The `webui.custom_css` setting lives in the database, not in a file, so it is
untouched by any code update.

### How this differs from the plugin project

`librenms-network-config`'s research notes record a one-line **core-file**
patch applied on this same host, with the warning:

> This is a core-file patch, not tracked by this repo's git. It will be
> silently reverted by any future `git pull`/LibreNMS update on that host.
> […] reapply this one-line patch after every LibreNMS update.

That hazard does not apply here. **These skins modify zero LibreNMS core
files.** There is no patch to reapply, and nothing to re-check after an update.
If a skin ever needs a core change to work, that is a bug in the skin.

### The one thing that *would* wipe it

`git clean -fdx` inside `/opt/librenms` deletes ignored files, which includes
`html/css/custom/`. That is not part of any normal update, but it is a common
"reset my checkout" reflex.

The `link` install mode below is the mitigation: the canonical skin files live
outside the LibreNMS tree entirely, so a `git clean` removes only a symlink,
and re-creating it is one command. This mirrors the pattern the plugin project
already uses for `/etc/librenms-network-config/`.

---

## Install

On the LibreNMS host, as a user that can write to `/opt/librenms/html/css/` and
run `lnms` (normally `librenms`):

```bash
sudo -u librenms git clone https://github.com/XBLOssia/librenms-skins.git /opt/librenms-skins
cd /opt/librenms-skins
./scripts/install.sh zerg
```

Then in the browser:

1. **Preferences → Theme → Dark.** The skins are an overlay on the stock dark
   theme; on the light base they look broken.
2. Hard-refresh (Ctrl-Shift-R).

Substitute `terran` or `protoss` for `zerg`. Preview first with `--dry-run`,
which changes nothing and prints every step.

### What the installer does

1. Reads the current `webui.custom_css` and saves it to
   `html/css/custom/.previous-custom_css` — **only on first install**, so
   switching skins later cannot clobber the true original.
2. Symlinks `html/css/custom/<skin>` → `/opt/librenms-skins/skins/<skin>`.
3. Sets `webui.custom_css` to `["css/custom/<skin>/<skin>.css"]`.
4. Verifies the stylesheet is readable, the webfonts are present, and the
   config took — and tells you to back out if any check fails.

It replaces `custom_css` rather than appending, because two skins loaded at
once cascade into mush. If you had your own custom CSS there, it is recorded in
step 1 and restored on uninstall.

### link vs copy

`--mode link` (default) symlinks. Updating a skin becomes `git pull` in
`/opt/librenms-skins`, and nothing under `/opt/librenms` is ever edited.
Apache's `html/.htaccess` sets `Options +FollowSymlinks` and nginx follows
symlinks by default, so this serves correctly.

`--mode copy` copies the directory instead. Use it if the repo lives somewhere
the webserver user cannot read.

Both are equally reversible.

### Updating a skin

```bash
cd /opt/librenms-skins && git pull
```

With `link` that is the whole update. With `copy`, re-run `install.sh`.

---

## Uninstall

```bash
cd /opt/librenms-skins
./scripts/uninstall.sh
```

That removes every skin directory or symlink from `html/css/custom/` and
restores `webui.custom_css` to whatever it was before the first install
(clearing it if it was empty). Then hard-refresh.

Options:

| Flag | Effect |
|---|---|
| `--dry-run` | Print every step, change nothing |
| `--skin zerg` | Remove one skin's files, leave `custom_css` alone |
| `--purge` | Clear `custom_css` outright, ignoring the saved value |
| `--librenms DIR` | Non-default install path |

The uninstaller also cleans up the older layout (a bare `<skin>.css` dropped
directly into `custom/`) in case you installed by hand before these scripts
existed.

### Manual removal

If the scripts are unavailable:

```bash
rm -rf /opt/librenms/html/css/custom/{terran,protoss,zerg}
lnms config:clear webui.custom_css
```

Then hard-refresh. That is genuinely all of it.

### What uninstall deliberately does *not* touch

Your **theme preference** (Preferences → Theme → Dark) is a per-user setting
the installer never changed, so the uninstaller leaves it alone. If you were on
Light before and want to go back, switch it yourself.

---

## Rollback confidence

| Question | Answer |
|---|---|
| Core files modified? | None |
| Database schema changed? | None |
| Files outside `html/css/custom/`? | None |
| Services restarted or installed? | None |
| Affects polling, discovery, alerting? | No — CSS only |
| Affects other users on the instance? | **Yes** — `custom_css` is instance-wide |
| Recoverable if the skin 500s the UI? | It cannot; CSS cannot break PHP. Worst case is an ugly page, fixed by `lnms config:clear webui.custom_css` |

The blast radius is one config row and one directory of static files.

### If something looks wrong

1. **Everything unstyled / stock dark** — theme is not set to Dark, or the
   browser cached the old CSS. Hard-refresh first.
2. **Fonts look generic** — the `fonts/` directory did not come along. Check
   `ls /opt/librenms/html/css/custom/<skin>/fonts/`. With `link` mode this
   usually means the webserver user cannot traverse into `/opt/librenms-skins`.
3. **Some components still stock-coloured** — expected. The skins cover 40 of
   92 components; see [ROADMAP.md](ROADMAP.md).
4. **Graphs look wrong** — expected and unfixable from CSS. RRDtool renders
   PNGs server-side; see [FINDINGS.md](FINDINGS.md) §5.

---

## Note on terminology

These are **not** a LibreNMS plugin. LibreNMS's plugin system exposes five
content-injection hooks and cannot carry CSS or assets at all — that is why
these ship as `custom_css` instead. Nothing here registers with
`PluginManager`, so nothing appears under the Plugins menu, and the plugin
uninstall path is not involved. See [FINDINGS.md](FINDINGS.md) §6.
