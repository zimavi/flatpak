# zimavi's Flatpak repository

## Install

```sh
flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo  # runtimes
flatpak remote-add --if-not-exists zimavi https://flatpak.zimavi.net.ua/zimavi.flatpakrepo
flatpak install zimavi <app-id>
```

x86_64 only.

## Applications

| App | Id | License notes |
|---|---|---|
| [Shirabe](https://github.com/zimavi/Shirabe.Client) | `ua.net.zimavi.Shirabe` | Bundles BASS, which is free for non-commercial use only |

`flatpak remote-ls zimavi` lists the branches that are currently published.

## Branches

`stable` is the default and has final releases. `beta` has pre-releases and also receives final releases. An app may
have only one of them, or additional branches. To pick one:

```sh
flatpak install zimavi <app-id>//beta
```

## How it works

Each `apps/<app-id>/<branch>.yml` is a Flatpak manifest that repackages a GitHub release; the file name is the branch,
so every `.yml` in an app folder is built. The other files of the folder are shared by its branches.

1. The app's repository runs `scripts/bump.sh` on a checkout of this one and opens a pull request that merges itself.
2. `check` builds the pull request.
3. After the merge, `publish` builds what changed, signs it and uploads it to Cloudflare R2.

Run `publish` by hand (Actions tab) to retry a failed upload.

By hand:

```sh
RELEASE_DATE=<YYYY-MM-DD> scripts/bump.sh <app-id> <version> <url of the release file> <sha256> [branch...]
scripts/build.sh /tmp/repo   # needs flatpak-builder and the SDKs the manifests name
```

`RELEASE_DATE` defaults to today. Which manifests `bump.sh` updates:

| Call | Updated |
|---|---|
| Pre-release such as `1.0.0-beta.1` | `beta` |
| Final release | `stable`, and `beta` if the app has it, unless `beta` is newer |
| With branch names | Exactly those; pre-releases are refused for `stable` |

A missing `stable.yml` or `beta.yml` is created from the other one. Any other branch needs its manifest first. A
version older than the one in the release's own branch, or in a named branch, is refused.

## Adding an app

Create `apps/<app-id>/` with:

- `beta.yml` or `stable.yml`, the manifest. With only `beta.yml`, the first final release creates `stable.yml`.
- The files the manifest installs, such as the desktop entry, AppStream metainfo and icon.

For `bump.sh` to update a manifest:

- It must have exactly one line each starting with `VERSION:`, `RELEASE_DATE:`, `url:` and `sha256:`, with the first two
  quoted in single quotes.
- The release URL must be under `https://github.com/zimavi/`.

Then add the app to the [table above](#applications).

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
