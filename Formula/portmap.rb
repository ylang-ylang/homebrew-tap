class Portmap < Formula
  include Language::Python::Virtualenv

  desc "Unified local development gateway and split-DNS remote access"
  homepage "https://github.com/ylang-ylang/portmap"
  url "https://github.com/ylang-ylang/portmap/archive/refs/tags/V0.10.tar.gz"
  version "0.10.0"
  sha256 "76f48ee53ca93fd4169f9da16fadeb190cf5aa1c37b5a8cf0e8d41140b48dbcb"
  license "MIT"

  depends_on "python@3.12"
  depends_on "coredns"
  depends_on "traefik"

  def install
    virtualenv_install_with_resources
  end

  test do
    (testpath/"compose.json").write '{"services":{"web":{"expose":["8000"]}}}'
    (testpath/"endpoints.toml").write <<~EOS
      [endpoints.web]
      kind = "http"
      service = "web"
      container_port = 8000
    EOS
    system bin/"portmap", "generate",
           "--compose-json", testpath/"compose.json",
           "--config", testpath/"endpoints.toml",
           "--project-dir", testpath,
           "--out-dir", testpath/"generated",
           "--repo-id", "brew-test",
           "--repo-name", "demo",
           "--branch", "test",
           "--host-ip", "127.0.0.1",
           "--http-port", "8080",
           "--domain-suffix", "brew.portmap"
    result = JSON.parse((testpath/"generated/state.json").read)
    assert_equal "http://web.test.demo.brew.portmap:8080",
                 result.fetch("endpoints").fetch("web").fetch("url")
  end
end
