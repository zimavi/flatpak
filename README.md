# zimavi's Flatpak repository

## Install

```sh
flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo  # runtimes
flatpak remote-add --if-not-exists zimavi https://flatpak.zimavi.net.ua/zimavi.flatpakrepo
flatpak install zimavi ua.net.zimavi.Shirabe//beta
```

| App | Id | Branches |
|---|---|---|
| [Shirabe](https://github.com/zimavi/Shirabe.Client) | `ua.net.zimavi.Shirabe` | `beta`; `stable` from its first final release |

x86_64 only. `beta` also receives final releases.

## How it works

Each `apps/<app-id>/<branch>.yml` is a Flatpak manifest that repackages a GitHub release; the file name is the branch,
so every `.yml` in an app folder is built. The other files of the folder are shared by its branches.

1. The app's repository runs `scripts/bump.sh` on a checkout of this one and opens a pull request that merges itself.
2. `check` builds the pull request.
3. After the merge, `publish` builds what changed, signs it and uploads it to Cloudflare R2.

Run `publish` by hand (Actions tab) to retry a failed upload.

By hand:

```sh
RELEASE_DATE=2026-01-31 scripts/bump.sh ua.net.zimavi.Shirabe <version> <url of the tar.gz> <sha256>
scripts/build.sh /tmp/repo   # needs flatpak-builder and the freedesktop SDK
```

To add an app, add its folder with a `beta.yml` (or `stable.yml`) like Shirabe's.

## Setup

Environment `publish` (limited to `main`):

| Name | Kind | Value |
|---|---|---|
| `R2_ACCESS_KEY_ID` | secret | R2 API token, *Object Read & Write*, this bucket only |
| `R2_SECRET_ACCESS_KEY` | secret | from the same token |
| `R2_ENDPOINT` | secret | `https://<account id>.r2.cloudflarestorage.com` |
| `GPG_PRIVATE_KEY` | secret | armored private signing key, without a passphrase |
| `R2_BUCKET` | variable | bucket name |

The bucket is served at `https://flatpak.zimavi.net.ua`. Do not add a "cache everything" rule for it: clients need a
fresh `repo/summary`.

An app repository needs a secret `FLATPAK_TOKEN`: a fine-grained token for this repository only, with *Contents* and
*Pull requests* read and write. **Whoever holds it can publish to every user.**

**Back up the signing key offline.** Without it, every user has to remove the remote and add it again.

BASS, bundled with Shirabe, is free for non-commercial use only.
