class Codoxear < Formula
  desc "DexGEM internal Codoxear — Computer service (agent host for a Hub)"
  homepage "https://github.com/DexGEM-Lab/codoxear-dexgem-internal"
  url "git@github.com:DexGEM-Lab/codoxear-dexgem-internal.git",
      using:    :git,
      revision: "4ec4758d2f7cf785b60993590c1b50457e7d7a29"
  version "0.1.0-preview.2"
  license "MIT"

  depends_on "gcc" => :build # node-pty/koffi native builds
  depends_on "pkgconf" => :build
  depends_on "python@3.13" => :build # node-gyp
  depends_on "node"

  def install
    cd "src/computer" do
      # npm's allowScripts policy blocks the two native deps' install scripts;
      # approve them declaratively before npm ci so node-gyp runs.
      inreplace "package.json",
                '"exports": {',
                '"allowScripts": { "@lydell/node-pty@1.2.0-beta.15": true, "koffi@3.3.2": true }, "exports": {'
      system "npm", "ci"
      system "npm", "run", "build"
      system "npm", "prune", "--omit=dev"
      system "npm", "prune", "--omit=dev", "--prefix", "runtime/oar"
      libexec.install "dist", "node_modules", "runtime", "package.json"
    end

    ["codoxear-computer", "codoxear"].each do |name|
      (bin/name).write <<~SH
        #!/bin/bash
        exec "#{Formula["node"].opt_bin}/node" "#{libexec}/dist/main.js" "$@"
      SH
    end
  end

  def post_install
    (var/"codoxear").mkpath
  end

  service do
    run [opt_bin/"codoxear-computer", "start"]
    working_dir var/"codoxear"
    keep_alive true
    log_path var/"log/codoxear-computer.log"
    error_log_path var/"log/codoxear-computer.error.log"
  end

  def caveats
    <<~EOS
      This is the v2 Computer service (DexGEM internal architecture), replacing
      the standalone v1 server. The web UI is served by your Hub (production:
      https://codoxear.dex-gem.ai:1443), not by this machine.

      Attach this Computer to a Hub first (pairing code comes from the Hub web
      UI: create a Computer record, then):
        codoxear-computer attach --hub <hub-origin> --code <code> --workspace <dir>

      Then start the service:
        brew services start codoxear

      Useful: codoxear-computer status | doctor | provider list | help
    EOS
  end

  test do
    assert_match "Codoxear Computer", shell_output("#{bin}/codoxear-computer help")
    assert_match "Codoxear Computer", shell_output("#{bin}/codoxear help")
  end
end
