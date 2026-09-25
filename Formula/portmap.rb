class Portmap < Formula
  include Language::Python::Virtualenv

  desc "Branch-scoped port allocator and Traefik label generator for docker-compose"
  homepage "https://github.com/ylang-ylang/portmap"
  url "https://github.com/ylang-ylang/portmap/archive/refs/tags/V0.7.tar.gz"
  sha256 "17eed25e0a58d6c7b7337bc5cf73c206053534d325bc5535fbd97f5ce513288d"
  license "MIT"

  depends_on "python@3.12"

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
