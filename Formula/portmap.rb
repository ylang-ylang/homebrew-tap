class Portmap < Formula
  include Language::Python::Virtualenv

  desc "Unified local development gateway and split-DNS remote access"
  homepage "https://github.com/ylang-ylang/portmap"
  url "https://github.com/ylang-ylang/portmap/archive/d410fcee4dac50c044e28f27b1e1499ac5e4618f.tar.gz"
  version "0.13.0"
  sha256 "81cdea3b179c0b603d6509a81982143b0fe40f2c3b83529bd21f7aba9d237be7"
  license "MIT"

  depends_on :linux
  depends_on "docker"
  depends_on "docker-compose"
  depends_on "python@3.12"

  allow_network_access! [:build, :postinstall]

  resource "brew-setup" do
    url "https://raw.githubusercontent.com/ylang-ylang/homebrew-tap/3488ca8a13aef7250f65b6d2d31386c13efd50f9/libexec/portmap_brew_setup.py"
    sha256 "b8cc345efd08c4ff1ac945e091f1a9f2c7f6922ed061aa3746832e8e230dfadd"
  end

  resource "brew-postinstall" do
    url "https://raw.githubusercontent.com/ylang-ylang/homebrew-tap/3488ca8a13aef7250f65b6d2d31386c13efd50f9/libexec/portmap_brew_postinstall.py"
    sha256 "909b2a593059a316c68b722bcc05e36ae1160b2d6baeddcf8593c762b493d45e"
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
      Installation initializes portmap using your existing local Docker or Podman API.
      Docker is preferred when both are available; explicit portmap settings take precedence.
      Brew supplies Docker/Compose clients, not a container engine. An unavailable API
      or failed setup makes installation fail rather than reporting a ready gateway.

      Successful installation serves http://127.0.0.1/ (or your configured HTTP port).
      Setup runs as your ordinary user, requesting sudo only for scoped DNS/HTTP setup.
      It preserves saved connections and does not publish projects or enable boot services.
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
