# Ylang's Homebrew tap

## rbw fork

```sh
brew install ylang-ylang/tap/rbw
```

If Homebrew requires tap trust, trust only this formula:

```sh
brew trust --formula ylang-ylang/tap/rbw
```

`rbw` is built from the fixed `ylangs-fork/rbw` commit in `Formula/rbw.rb`, not
from upstream rbw. Published bottles cover Linux x86_64 and macOS 15 Apple
Silicon (Homebrew may also use these on newer macOS releases).
Other platforms and `--HEAD` build from source. Intel macOS is not bottled:
Homebrew has retired its Intel build-toolchain bottles. Bottles avoid installing the
Rust/LLVM build toolchain; the `pinentry` runtime dependency is still required.
Existing installations can use `brew reinstall ylang-ylang/tap/rbw` after updating
the tap. This does not automatically remove previously installed build tools.

To build from source instead:

```sh
brew install --build-from-source ylang-ylang/tap/rbw
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

The Linux x86_64 face runtime targets Ubuntu 22.04/24.04 and includes Python,
dlib, OpenCV, models and native runtime libraries. Opt-in deployment may request
sudo, but never apt/pip, network downloads or a local compiler. Missing matching
precompiled artifacts fail explicitly; no sudo/login PAM policies are changed.
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

### Publishing rbw bottles

1. Update the pinned source revision/version in `Formula/rbw.rb` through a PR.
   Remove the old bottle block when changing the source.
2. Run the **rbw-bottles** workflow on `main`. It builds the exact tap commit,
   exercises the CLI and agent, packages and reinstalls each bottle, and records
   GitHub build-provenance attestations. All platform builds must pass before a
   release is published. Release URLs are unique to each run and attempt.
3. Download the release's bottle JSON files, then run in this tap's checkout:

   ```sh
   brew bottle --merge --write --no-commit ./rbw--*.bottle.json
   ```

4. Review the generated `bottle do` block (source commit, release URL, platform
   tags, Cellar compatibility, SHA-256 checksums) and merge it through a PR.
   Publishing a release alone does not change the binaries users install.
5. Verify a normal installation uses the published bottle, and that
   `brew deps ylang-ylang/tap/rbw` does not include Rust/LLVM.

Build records and binaries are public under this repository's Actions and
Releases. To verify a downloaded bottle's provenance:

```sh
gh attestation verify ./rbw-1.16.0.PLATFORM.bottle.1.tar.gz --repo ylang-ylang/homebrew-tap
```

An attestation proves build origin, not a security audit or reproducible build.
This tap is independently maintained, not an official Homebrew security review.
