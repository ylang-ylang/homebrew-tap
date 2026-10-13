class Portmap < Formula
  include Language::Python::Virtualenv

  desc "Unified local development gateway and split-DNS remote access"
  homepage "https://github.com/ylang-ylang/portmap"
  url "https://github.com/ylang-ylang/portmap/archive/refs/tags/V0.12.tar.gz"
  version "0.12.0"
  sha256 "c03cbb8ba07a9acf3567e5fe4da727ec117880ba573a7dc240283b337a43aa64"
  license "MIT"

  depends_on "python@3.12"

  def install
    virtualenv_install_with_resources
  end

  def caveats
    <<~EOS
      Setup requires a running Docker or rootless Podman API and a Docker Compose v2 client.
      DNS and HTTP engines run in containers; no host CoreDNS or Traefik is required.
      Installation does not configure DNS, publish projects, or enable boot services.
      Run `portmap setup` as your ordinary login user before `portmap up`.
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
