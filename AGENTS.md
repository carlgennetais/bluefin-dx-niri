# Agent Instructions for bluefin-dx-niri

A custom [bootc](https://bootc-dev.github.io/bootc/) image built from
[ublue-os/image-template](https://github.com/ublue-os/image-template): the base
image is a published Universal Blue image (`ghcr.io/ublue-os/bluefin-dx`) and
everything in this repo is layered on top of it.

## Pre-Commit Checklist

Run before **every** commit:

1. `shellcheck -x build_files/*.sh` on any modified shell script
2. `just check` to verify Justfile syntax
3. `python3 -c "import yaml; yaml.safe_load(open('FILE'))"` on any modified YAML
4. Conventional commit message (see below)
5. **Confirm with the user before committing and pushing**

Never commit a file with a syntax error.

### Conventional Commits (required)

```
<type>[optional scope]: <description>
```

Valid types: `feat`, `fix`, `docs`, `chore`, `build`, `ci`, `refactor`, `test`.
Breaking changes add `!` or a `BREAKING CHANGE:` footer. See
`.github/commit-convention.md`.

### Attribution

AI agents disclose tool and model in a commit footer:

```text
Assisted-by: [Model Name] via [Tool Name]
```

## Repository Layout

```
Containerfile                 # base image + the single RUN that calls build.sh
image-template.env            # image name, org, description, default tag, BIB image
Justfile                      # local build / disk image / VM recipes
build_files/
  build.sh                    # main build script (system_files overlay, units)
  niri.sh                     # niri + DMS + greetd package installs
  copr-helpers.sh             # copr_install_isolated helper
system_files/                 # copied verbatim onto / during the build
disk_config/                  # bootc-image-builder configs (qcow2 / raw / ISO)
```

### Build flow

The `ctx` stage in the `Containerfile` copies `build_files/` to `/` and
`system_files/` to `/system_files`. A single `RUN` executes `/ctx/build.sh`,
which:

1. runs `/ctx/niri.sh` (package installs), **then**
2. `rsync -rvK /ctx/system_files/ /` — the overlay comes *after* the installs so
   shipped config wins over RPM defaults (e.g. `/etc/greetd/config.toml`).
   `-K` is required because some base image directories are symlinks, which
   `cp` refuses to overwrite with a directory.
3. enables systemd units.

Then `bootc container lint` validates the result. Lint requires that any user
created by an RPM scriptlet has a matching `sysusers.d` entry, and that `/var`
content created by scriptlets is declared in `tmpfiles.d`. Check whether the
package already ships those (`rpm -ql pkg | grep -E 'sysusers|tmpfiles'`) before
adding your own — `dms-greeter` ships both, and a second declaration of the same
user is a trap, not a fix. `system_files/usr/lib/tmpfiles.d/greetd-dms.conf`
covers what greetd itself leaves undeclared.

## Where to Add Things

| What | Where |
|---|---|
| System package (baked in) | `dnf5 install -y pkg` in `build_files/build.sh` |
| Package from a COPR | `copr_install_isolated "owner/repo" pkg` in `build_files/niri.sh` |
| Static config file | its real path under `system_files/` |
| CLI tool (runtime) | `system_files/usr/share/ublue-os/homebrew/default.Brewfile` |
| GUI app (first boot) | `system_files/usr/share/flatpak/preinstall.d/default.preinstall` |
| `ujust` recipe | `system_files/usr/share/ublue-os/just/60-custom.just` |
| systemd unit enable/mask | `build_files/build.sh` |

Prefer `system_files/` over writing files from a script — the overlay is
declarative and reviewable. Use a script only when the change patches a file
owned by the base image.

## Conventions

Follow [@ublue-os/bluefin](https://github.com/ublue-os/bluefin) patterns.
Confirm with the user before deviating.

- Use `dnf5` exclusively — never `dnf`, `yum`, or `rpm-ostree`
- Always pass `-y` for non-interactive installs
- COPRs: enable → **disable** → install with `--enablerepo=` (this is what
  `copr_install_isolated` does). A COPR left enabled persists into the image.
- Third-party repo files must be removed at the end of the script that adds them
- Never use `dnf5` in `60-custom.just` — ujust recipes are user-level shortcuts
  (Homebrew, Flatpak, system tasks), not package-manager wrappers
- Never commit `cosign.key` (it is in `.gitignore`)
- Flatpak app IDs must exist on [Flathub](https://flathub.org/) before being added
- `60-custom.just` is imported optionally by the base image's
  `/usr/share/ublue-os/just/00-entry.just` — the filename matters

## Branch and CI

- Work on a branch, never push directly to `main`
- `main` builds and pushes `:stable`; PRs build without pushing
- `renovate.yml` needs `RENOVATE_REPOSITORIES` set or it finds no repository and
  silently does nothing
- Image signing activates automatically once `SIGNING_SECRET` exists; without it
  the signing steps are skipped, not failed

## Documentation

**Always update the "What Makes this Different" section in `README.md`** when
packages or configuration change — including the *Last updated* date. Write it
for users of the image, explain *why* as well as *what*, and keep it brief.

Keep this file and `README.md` in sync with the actual layout. If they disagree
with the code, the code is right and the docs are a bug.
