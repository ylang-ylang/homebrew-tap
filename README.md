# Ylang's Homebrew tap

## rbw fork

```sh
brew install ylang-ylang/tap/rbw
```

`rbw` is built from the fixed `ylangs-fork/rbw` commit in `Formula/rbw.rb`, not
from upstream rbw. Published bottles cover Linux x86_64 and macOS 15 (Apple
Silicon and Intel; Homebrew may also use these on newer macOS releases).
Other platforms and `--HEAD` build from source. Bottles avoid installing the
Rust/LLVM build toolchain; the `pinentry` runtime dependency is still required.
Existing installations can use `brew reinstall ylang-ylang/tap/rbw` after updating
the tap. This does not automatically remove previously installed build tools.

To build from source instead:

```sh
brew install --build-from-source ylang-ylang/tap/rbw
```

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
gh attestation verify ./rbw-1.15.0.PLATFORM.bottle.tar.gz --repo ylang-ylang/homebrew-tap
```

An attestation proves build origin, not a security audit or reproducible build.
This tap is independently maintained, not an official Homebrew security review.
