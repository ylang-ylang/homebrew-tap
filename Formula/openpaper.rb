class Openpaper < Formula
  include Language::Python::Virtualenv

  desc "Self-hosted AI research assistant"
  homepage "https://github.com/ylang-ylang/openpaper"
  url "https://github.com/ylang-ylang/openpaper/archive/refs/tags/V0.1.tar.gz"
  version "0.1"
  sha256 "d6d690a30c2ef5030ae31dabdfbf2c08a888ef8ebef405f34dfb5bb54b3907e5"
  license "AGPL-3.0-only"

  depends_on :linux
  depends_on arch: :x86_64
  depends_on "docker"
  depends_on "docker-buildx"
  depends_on "docker-compose"
  depends_on "python-setuptools" => :build
  depends_on "python@3.12"

  allow_network_access! :postinstall

  resource "pyyaml" do
    url "https://files.pythonhosted.org/packages/05/8e/961c0007c59b8dd7729d542c61a4d537767a59645b82a0b521206e1e25c2/pyyaml-6.0.3.tar.gz"
    sha256 "d76623373421df22fb4cf8817020cbb7ef15c725b9d5e45f17e189bfc384190f"
  end

  def install
    venv = virtualenv_create(libexec, "python3.12")
    venv.pip_install resource("pyyaml"), build_isolation: false

    app = libexec/"app"
    app.install "client", "server", "jobs", "compose.yml", "packaging", "LICENSE"
    (app/"docker").install "docker/local"

    compose = Formula["docker-compose"].opt_bin/"docker-compose"
    buildx = Formula["docker-buildx"].opt_bin/"docker-buildx"
    (bin/"openpaper").write <<~SH
      #!/bin/bash
      export OPENPAPER_DOCKER_COMPOSE="#{compose}"
      export OPENPAPER_DOCKER_BUILDX="#{buildx}"
      exec "#{libexec}/bin/python" "#{libexec}/app/packaging/openpaper.py" "$@"
    SH
    chmod 0755, bin/"openpaper"
  end

  post_install_steps do
    run "bin/python",
        args: ["{{libexec}}/app/packaging/openpaper.py", "brew-setup"],
        base: :libexec,
        env: {
          "OPENPAPER_DOCKER_COMPOSE" => (Formula["docker-compose"].opt_bin/"docker-compose").to_s,
          "OPENPAPER_DOCKER_BUILDX" => (Formula["docker-buildx"].opt_bin/"docker-buildx").to_s,
          "OPENPAPER_BREW_SKIP_SETUP" => ENV.fetch("OPENPAPER_BREW_SKIP_SETUP", "0"),
          "OPENPAPER_STATE_DIR" => ENV.fetch("OPENPAPER_STATE_DIR", ""),
        },
        print_stdout: true,
        network_access: true
  end

  def caveats
    <<~EOS
      OpenPaper uses an existing local Docker engine. Homebrew installs the
      Docker, Buildx, and Compose clients, but it does not install or start a
      container engine and never leaves an unmanaged background process.

      If Docker is unavailable during installation, OpenPaper remains honestly
      installed but not started. Start your Docker engine, then run:
        openpaper brew-setup

      Automated packaging can skip post-install startup without touching real
      state by setting OPENPAPER_BREW_SKIP_SETUP=1.
    EOS
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/openpaper --version")
    ENV["OPENPAPER_STATE_DIR"] = (testpath/"state").to_s
    system bin/"openpaper", "init"
    assert_path_exists testpath/"state/.env"
    assert_path_exists testpath/"state/compose.json"
  end
end
