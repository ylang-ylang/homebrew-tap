class CodoxearHub < Formula
  desc "DexGEM internal Codoxear — Hub service (accounts, permissions, routing) with hosted web frontend"
  homepage "https://github.com/DexGEM-Lab/codoxear-dexgem-internal"
  url "git@github.com:DexGEM-Lab/codoxear-dexgem-internal.git",
      using:    :git,
      revision: "4ec4758d2f7cf785b60993590c1b50457e7d7a29"
  version "0.1.0-preview.2"
  license "MIT"
  revision 4

  depends_on "python@3.13" => :build
  depends_on "node"

  def install
    cd "src/hub" do
      system "npm", "ci"
      system "npm", "run", "build"
      system "npm", "prune", "--omit=dev"
      (libexec/"hub").install "dist", "node_modules", "package.json"
    end
    cd "src/frontend" do
      system "npm", "ci"
      # LAN build: CSP allows plain-HTTP hubs (see build.mjs).
      with_env("CODOXEAR_LAN_CSP" => "1") do
        system "npm", "run", "build"
      end
      (share/"codoxear-hub/frontend-assets").install Dir["dist/client/*", "dist/hub", "dist/identity", "dist/workspace"]
    end

    (bin/"codoxear-hub").write <<~SH
      #!/bin/bash
      export CODOXEAR_HUB_CONFIG="${CODOXEAR_HUB_CONFIG:-#{var}/codoxear-hub/hub.json}"
      export CODOXEAR_FRONTEND_ASSETS_ROOT="${CODOXEAR_FRONTEND_ASSETS_ROOT:-#{opt_share}/codoxear-hub/frontend-assets}"
      cd "#{var}/codoxear-hub" || exit 1
      exec "#{Formula["node"].opt_bin}/node" "#{libexec}/hub/dist/main.js" "$@"
    SH

    (bin/"codoxear-hub-pair").write <<~SH
      #!/bin/bash
      # Issue a Computer pairing code without the web UI:
      #   codoxear-hub-pair <computer-name>
      set -euo pipefail
      CONF="${CODOXEAR_HUB_CONFIG:-#{var}/codoxear-hub/hub.json}"
      TOKEN="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1])).get("adminToken",""))' "$CONF")"
      ORIGIN="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["origin"])' "$CONF")"
      if [ -z "$TOKEN" ]; then echo "no adminToken in $CONF" >&2; exit 1; fi
      if [ $# -lt 1 ]; then echo "usage: codoxear-hub-pair <computer-name>" >&2; exit 2; fi
      curl -sf -X POST "$ORIGIN/api/admin/computers" \
        -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' \
        --data-binary @- <<JSON
      {"name": "$1"}
      JSON
      echo
    SH

    (bin/"codoxear-hub-init").write <<~SH
      #!/bin/bash
      set -euo pipefail
      DIR="#{var}/codoxear-hub"
      mkdir -p "$DIR/state"
      if [ -e "$DIR/hub.json" ]; then
        echo "hub.json already exists: $DIR/hub.json" >&2
        exit 1
      fi
      HOST="${1:-$(hostname -I 2>/dev/null | awk '{print $1}' || echo 127.0.0.1)}"
      PORT="${2:-17430}"
      INIT_TOKEN="$(openssl rand -hex 16)"
      HUB_ID="$(openssl rand -hex 8)"
      ADMIN_TOKEN="$(openssl rand -hex 24)"
      EXPIRES_AT="$(($(date +%s) * 1000 + 86400000))"
      cat > "$DIR/hub.json" <<JSON
      {
        "independent": true,
        "origin": "http://$HOST:$PORT",
        "hubId": "$HUB_ID",
        "name": "Local hub",
        "catalog": "./state/hub-catalog.sqlite",
        "database": "./state/hub-sessions.sqlite",
        "signingKey": "./state/hub-signing-key.json",
        "clientOrigins": ["http://$HOST:19520"],
        "clients": [
          { "id": "codoxear-web", "redirectUris": ["http://$HOST:19520/auth-callback"] }
        ],
        "listenHost": "0.0.0.0",
        "listenPort": $PORT,
        "secureCookies": false,
        "adminToken": "$ADMIN_TOKEN",
        "initialization": { "token": "$INIT_TOKEN", "expiresAt": $EXPIRES_AT },
        "providers": []
      }
      JSON
      chmod 600 "$DIR/hub.json"
      echo "wrote $DIR/hub.json"
      echo "initialization URL (private, first sign-in becomes Owner):"
      echo "  http://$HOST:$PORT/initialize?token=$INIT_TOKEN"
    SH
  end

  def post_install
    (var/"codoxear-hub/state").mkpath
  end

  service do
    run [opt_bin/"codoxear-hub"]
    working_dir var/"codoxear-hub"
    keep_alive true
    log_path var/"log/codoxear-hub.log"
    error_log_path var/"log/codoxear-hub.error.log"
  end

  def caveats
    <<~EOS
      Initialize the hub config once (prints the private Owner initialization URL):
        codoxear-hub-init [lan-ip] [port]

      Then run the hub:
        brew services start codoxear-hub

      Attach computers:
        codoxear-computer attach --hub http://<hub-ip>:17430 --code <pairing-code> --workspace <dir>

      This build serves the web frontend at the hub origin when frontend assets
      are present (they are, under #{opt_share}/codoxear-hub/frontend-assets).
      secureCookies is disabled in the generated LAN config (plain HTTP).
    EOS
  end

  test do
    assert_path_exists bin/"codoxear-hub"
    assert_path_exists bin/"codoxear-hub-init"
    assert_path_exists libexec/"hub/dist/main.js"
    assert_path_exists share/"codoxear-hub/frontend-assets/index.html"
  end
end
