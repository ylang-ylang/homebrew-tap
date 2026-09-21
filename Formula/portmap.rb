class Portmap < Formula
  include Language::Python::Virtualenv

  desc "Branch-scoped port allocator and Traefik label generator for docker-compose"
  homepage "https://github.com/ylang-ylang/portmap"
  url "https://github.com/ylang-ylang/portmap/archive/refs/tags/V0.4.tar.gz"
  sha256 "429a73e275629625143ee438d92114be328586814f1e6ad777f0102137e09b36"
  license "MIT"

  depends_on "python@3.12"

  def install
    virtualenv_install_with_resources
  end

  test do
    assert_match "portmap", shell_output("#{bin}/portmap --help")
  end
end
