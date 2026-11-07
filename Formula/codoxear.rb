class Codoxear < Formula
  desc "Codoxear agent node: hub, computer and web in one service"
  homepage "https://github.com/DexGEM-Lab/codoxear-dexgem-internal"
  url "git@github.com:DexGEM-Lab/codoxear-dexgem-internal.git",
      using:    :git,
      revision: "610b019e885012d42559bbf5c70ef7d8c27f813b"
  version "0.2.0-preview.1"
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
      (libexec/"computer").install "dist", "node_modules", "runtime", "package.json"
    end
    cd "src/hub" do
      system "npm", "ci"
      system "npm", "run", "build"
      system "npm", "prune", "--omit=dev"
      (libexec/"hub").install "dist", "node_modules", "package.json"
    end
    cd "src/frontend" do
      system "npm", "ci"
      # LAN build: CSP allows plain-HTTP hubs (see src/frontend/build.mjs).
      with_env(CODOXEAR_LAN_CSP: "1") { system "npm", "run", "build" }
      (libexec/"frontend").install "dist"
    end
    libexec.install "deploy/node.mjs"

    # Agent runtime used by the in-app Feedback session; bundled so users install nothing else.
    system "npm", "install", "--prefix", libexec/"pi", "--no-audit", "--no-fund",
           "@earendil-works/pi-coding-agent@1.0.0"

    node = Formula["node"].opt_bin/"node"
    (bin/"codoxear").write <<~SH
      #!/bin/bash
      export PI_BIN="${PI_BIN:-#{opt_libexec}/pi/node_modules/.bin/pi}"
      exec "#{node}" "#{opt_libexec}/node.mjs" "$@"
    SH
    (bin/"codoxear-computer").write <<~SH
      #!/bin/bash
      export PI_BIN="${PI_BIN:-#{opt_libexec}/pi/node_modules/.bin/pi}"
      exec "#{node}" "#{opt_libexec}/computer/dist/main.js" "$@"
    SH
  end

  def post_install
    # Service logs live in a private directory; they may contain deployment output.
    private_dir = var/"codoxear"
    private_dir.mkpath
    private_dir.chmod 0700
  end

  # Installed but NOT started: `brew services start codoxear` is the single deliberate action.
  # Role (hub / node) derives from connections at runtime; nothing to configure.
  service do
    run [opt_bin/"codoxear", "start"]
    working_dir var/"codoxear"
    keep_alive true
    log_path var/"codoxear/service.log"
    error_log_path var/"codoxear/service.error.log"
  end

  def caveats
    <<~EOS
      Start this node (the only step):
        brew services start codoxear

      Then open http://<this machine's LAN address>:17430 in a browser and sign in
      as admin / admin. You are asked to choose a new password right away, and
      whoever completes that first sign-in becomes the Owner, so do it before
      exposing the node to a network you do not trust.

      The Network page connects upstream (attach to another node) or downstream
      (issue a pairing code). The node derives its role from its connections;
      there is nothing else to configure.

      CLI: codoxear-computer status | doctor | attach | provider
    EOS
  end

  test do
    assert_match "Codoxear Computer", shell_output("#{bin}/codoxear-computer help")
    assert_path_exists libexec/"hub/dist/server.js"
    assert_path_exists libexec/"computer/dist/local-control.js"
    assert_path_exists libexec/"frontend/dist/client"
    assert_path_exists libexec/"pi/node_modules/.bin/pi"
  end
end
