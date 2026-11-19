# Ylang's Homebrew tap

## rbwBio

```sh
brew install ylang-ylang/tap/rbwbio
```

If Homebrew requires tap trust, trust only this formula:

```sh
brew trust --formula ylang-ylang/tap/rbwbio
```

**rbwBio** is built from the fixed `ylangs-fork/rbw` commit in
`Formula/rbwbio.rb`, not from upstream rbw. The repository and crate keep their
existing names; the commands remain `rbw` and `rbw-agent`. Configuration,
encrypted vault data, `RBW_PROFILE` profiles and existing integrations are preserved.

Existing installations of this tap's `rbw` formula migrate with ordinary
`brew update` and `brew upgrade` through `formula_renames.json`. `rbwbio`
conflicts with other `rbw` formulas because they install the same binaries.
Do not delete your configuration or vault data to migrate.

Precompiled rbwBio bottles are published for Linux x86_64 and macOS 15 Apple
Silicon (Homebrew may use these on newer macOS). Supported installations avoid
the Rust build toolchain. Both platforms are built, tested and reinstalled in
public CI, with SHA-256 checksums and GitHub build-provenance attestations.
Other platforms and `--HEAD` build from source. The `pinentry` runtime dependency
is still required; upgrading does not remove previously installed build tools.

To build from source instead:

```sh
brew install --build-from-source ylang-ylang/tap/rbwbio
```

### Linux face setup

Log in normally after installing:

```sh
rbw login
```

The interactive login asks **Enable face authorization for rbw? [y/N]** once.
Enter keeps ordinary rbw behavior. Yes deploys the precompiled runtime installed
by Brew, selects the IR camera, enrolls and verifies your face, checks desktop
notifications, and updates the agent without losing the unlocked session.

The GNU/Linux x86_64 face runtime requires glibc 2.35 or newer (Ubuntu
22.04/24.04 or compatible Manjaro x86_64) and includes Python, dlib, OpenCV,
models and native libraries. It reuses the published 1.17.0 runtime unchanged.
Only opt-in deployment avoids package installation, downloads and compilation;
it may request sudo. Missing matching artifacts fail explicitly. Unknown
`rbw-device-auth` policies and all sudo/login PAM policies are never overwritten.
Every face authorization delivers a secret-free desktop notification while
recognition runs; failed recognition or notification delivery denies the operation.
Master Password remains required for cold unlock. Real camera matching and
spoof resistance are not established by the no-hardware smoke.

Pipelines never prompt. Use `rbw setup --apply` only to opt in later or repair
enrollment, and `rbw setup --check` for read-only diagnostics.
macOS requester/remote operation remains supported; local Howdy is Linux-only.

The Linux package carries a private PAM library configured to read `/etc`,
not the user-writable Homebrew `etc` directory. Brew installation alone does not
install system face components or replace the operating system's PAM library;
the opt-in wizard separately provisions its isolated Howdy module.

### Publishing rbwBio bottles

1. Update the pinned source revision/version in `Formula/rbwbio.rb` through a PR.
   Remove the old bottle block when changing the source.
2. Run the **rbwbio-bottles** workflow on `main`. It builds the exact tap commit,
   exercises the CLI and agent, packages and reinstalls each bottle, and records
   GitHub build-provenance attestations. All platform builds must pass before a
   release is published. Release URLs are unique to each run and attempt.
3. Download the release's bottle JSON files, then run in this tap's checkout:

   ```sh
   brew bottle --merge --write --no-commit ./rbwbio--*.bottle.json
   ```

4. Review the generated `bottle do` block (source commit, release URL, platform
   tags, Cellar compatibility, SHA-256 checksums) and merge it through a PR.
   Publishing a release alone does not change the binaries users install.
5. Verify a normal installation uses the published bottle, and that
   `brew deps ylang-ylang/tap/rbwbio` does not include Rust/LLVM.

Build records and binaries are public under this repository's Actions and
Releases. To verify a downloaded bottle's provenance:

```sh
gh attestation verify ./rbwbio-1.17.1.PLATFORM.bottle.tar.gz --repo ylang-ylang/homebrew-tap
```

An attestation proves build origin, not a security audit or reproducible build.
This tap is independently maintained, not an official Homebrew security review.
