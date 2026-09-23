class Portmap < Formula
  include Language::Python::Virtualenv

  desc "Branch-scoped port allocator and Traefik label generator for docker-compose"
  homepage "https://github.com/ylang-ylang/portmap"
  url "https://github.com/ylang-ylang/portmap/archive/refs/tags/V0.5.tar.gz"
  sha256 "8278eb2868c17d73fc7115f3fa6c5fc74c2169e2a45fa6b330278eef06ceea0c"
  license "MIT"

  depends_on "python@3.12"

  def install
    virtualenv_install_with_resources
  end

  test do
    assert_match "portmap", shell_output("#{bin}/portmap --help")
  end
end
