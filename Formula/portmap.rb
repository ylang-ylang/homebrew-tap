class Portmap < Formula
  include Language::Python::Virtualenv

  desc "Branch-scoped port allocator and Traefik label generator for docker-compose"
  homepage "https://github.com/ylang-ylang/portmap"
  url "file:///home/ylang/ylangs_ws/portmap@wt/portmap@feat-docker-and-podman/dist/portmap-0.1.0.tar.gz"
  sha256 "dd5fcb39ba007d1a3de79b681decfc1f6de30b62db4ebec506c02f8be5ad2ac0"
  license "MIT"

  depends_on "python@3.12"

  def install
    virtualenv_install_with_resources
  end

  test do
    assert_match "portmap", shell_output("#{bin}/portmap --help")
  end
end
