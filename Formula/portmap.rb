class Portmap < Formula
  include Language::Python::Virtualenv

  desc "Unified local development gateway and split-DNS remote access"
  homepage "https://github.com/ylang-ylang/portmap"
  url "https://github.com/ylang-ylang/portmap/archive/refs/tags/v0.20.8.tar.gz"
  version "0.20.8"
  sha256 "0e52a05e0bfa37c034696c9a2b093952ae5117fd36fc857024f580a7356fecad"
  license "MIT"

  depends_on :linux
  depends_on "docker"
  depends_on "docker-compose"
  depends_on "python@3.12"

  allow_network_access! [:build, :postinstall]

  resource "brew-setup" do
    url "https://raw.githubusercontent.com/ylang-ylang/homebrew-tap/12f2701bcbfb39c4825e39e8ce612767ede4a16a/libexec/portmap_brew_setup.py"
    sha256 "bc68d3a6b182b9732cd6b4b9220cb6b676f8fda4adbc2a7e4568944e53b16575"
  end

  resource "brew-postinstall" do
    url "https://raw.githubusercontent.com/ylang-ylang/homebrew-tap/12f2701bcbfb39c4825e39e8ce612767ede4a16a/libexec/portmap_brew_postinstall.py"
    sha256 "03812f2fd81bbc2a35e4a6f2aee9473b8f8ea529fa594ad230aeff758ff00fe6"
  end

  def install
    virtualenv_install_with_resources without: ["brew-setup", "brew-postinstall"]
    resource("brew-setup").stage { libexec.install "portmap_brew_setup.py" }
    resource("brew-postinstall").stage { libexec.install "portmap_brew_postinstall.py" }
  end

  post_install_steps do
    run "bin/python",
        args: ["{{libexec}}/portmap_brew_postinstall.py",
               "--brew-prefix", "{{HOMEBREW_PREFIX}}",
               "--formula-prefix", "{{opt_prefix}}"],
        base: :libexec,
        print_stdout: true
  end

  def caveats
    <<~EOS
      Installation uses your existing local Docker or Podman API (Docker is
      preferred when both are available; explicit portmap settings take
      precedence). Homebrew supplies the Docker/Compose clients, never a
      container engine, and no Compose plugin wiring is needed: portmap
      locates the installed client itself. When setup runs, an unavailable
      API or failed setup is an error, never a ready gateway.

      Where a systemd user service manager runs the setup, successful
      installation serves http://127.0.0.1/ (or your configured HTTP port).
      Without one the install finishes honestly not started; run "portmap run"
      (foreground) or "portmap setup" yourself - Homebrew never leaves an
      unmanaged background process behind.

      Setup runs as your ordinary user and requests sudo only when resolver
      files or a retained legacy host adapter require it. Container publication
      uses the runtime's existing permissions; unavailable ports 53 or 80 fail
      without changing policy or silently selecting higher ports. Setup preserves
      saved connections and does not publish projects or enable boot services.
      After a rebuilt workspace or a changed runtime environment, rerun the
      same standard entry ("portmap setup" or "portmap run"): it re-verifies
      the container API before creating or changing portmap-owned containers.
      To repeat installation and recovery: brew reinstall ylang-ylang/tap/portmap
    EOS
  end

  test do
    ENV["PORTMAP_STATE_DIR"] = (testpath/"state").to_s
    (testpath/"compose.json").write '{"services":{"web":{"expose":["8000"]}}}'
    (testpath/".portmap").mkpath
    endpoint_config = testpath/".portmap/endpoints.toml"
    configured = <<~EOS
      [endpoints.web]
      kind = "http"
      service = "web"
      container_port = 8000
    EOS
    endpoint_config.write configured

    system bin/"portmap", "init",
           "--project-dir", testpath,
           "--compose-file", "compose.json"
    assert_equal configured, endpoint_config.read
    refute_path_exists testpath/"state/client/infrastructure.json"
  end
end
