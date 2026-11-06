class CodoxearWeb < Formula
  desc "DexGEM internal Codoxear — web client (static host for the browser app)"
  homepage "https://github.com/DexGEM-Lab/codoxear-dexgem-internal"
  url "git@github.com:DexGEM-Lab/codoxear-dexgem-internal.git",
      using:    :git,
      revision: "181dfbb90980876db08be596a274345a565d177d"
  version "0.1.0-preview.3"
  license "MIT"

  depends_on "python@3.13" => :build
  depends_on "node"

  def install
    cd "src/frontend" do
      system "npm", "ci"
      # LAN build: CSP allows plain-HTTP hubs (see build.mjs).
      system({ "CODOXEAR_LAN_CSP" => "1" }, "npm", "run", "build")
      (libexec/"frontend").install "serve.mjs"
      (libexec/"frontend").install "dist"
    end

    (bin/"codoxear-web").write <<~SH
      #!/bin/bash
      export CODOXEAR_CLIENT_PORT="${CODOXEAR_CLIENT_PORT:-19520}"
      export CODOXEAR_CLIENT_HOST="${CODOXEAR_CLIENT_HOST:-0.0.0.0}"
      exec "#{Formula["node"].opt_bin}/node" "#{libexec}/frontend/serve.mjs" "$@"
    SH
  end

  service do
    run [opt_bin/"codoxear-web"]
    keep_alive true
    log_path var/"log/codoxear-web.log"
    error_log_path var/"log/codoxear-web.error.log"
  end

  def caveats
    <<~EOS
      Serves the browser client on CODOXEAR_CLIENT_PORT (default 19520).
      Point your hub's clientOrigins at http://<this-host>:19520
      (codoxear-hub-init already does).
    EOS
  end

  test do
    assert_path_exists bin/"codoxear-web"
    assert_path_exists libexec/"frontend/dist/client/index.html"
  end
end
