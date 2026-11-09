class Codoxear < Formula
  desc "Codoxear HTTPS agent node with symmetric pinned links"
  homepage "https://github.com/DexGEM-Lab/codoxear-dexgem-internal"
  url "git@github.com:DexGEM-Lab/codoxear-dexgem-internal.git",
      using:    :git,
      revision: "1f5108d0bea4a1d31bcc7b21ac577606387becdc"
  version "0.2.0-preview.1"
  license "MIT"

  depends_on "gcc" => :build # node-pty/koffi native builds
  depends_on "pkgconf" => :build
  depends_on "python@3.13" => :build # node-gyp
  depends_on "node"

  def install
    # The node build bundles its protocol/shared libraries and executable host entries.
    cd "src/node" do
      system "npm", "ci"
      system "npm", "prune", "--omit=dev", "--prefix", "host/runtime/oar"
      system "npm", "run", "build"
      system "npm", "prune", "--omit=dev"
      (libexec/"node").install "dist", "node_modules", "package.json"
    end
    cd "src/frontend" do
      system "npm", "ci"
      system "npm", "run", "build"
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
  end

  def post_install
    # Service logs live in a private directory; they may contain deployment output.
    private_dir = var/"codoxear"
    private_dir.mkpath
    private_dir.chmod 0700
  end

  # Installed but NOT started: `brew services start codoxear` is the single deliberate action.
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

      Then open https://<this machine's LAN address>:17430 in a browser.
      Check the address and accept this node's self-signed certificate once.
      Sign in with the starting password admin, then choose a new password
      of 8 or more characters (no other rule). Complete first use before
      exposing the node to a network you do not trust.

      Open the Graph page to create or accept invitations. Linked nodes
      can fully control each other's agents, including shell commands.
      Compare the name, address and certificate fingerprint before confirming.
      Use Share in a session for temporary control of only that session.
    EOS
  end

  test do
    assert_path_exists libexec/"node/dist/index.js"
    assert_path_exists libexec/"node/dist/host/native/broker.js"
    assert_path_exists libexec/"frontend/dist/node/login.html"
    assert_path_exists libexec/"pi/node_modules/.bin/pi"
  end
end
