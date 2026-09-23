class Portmap < Formula
  include Language::Python::Virtualenv

  desc "Branch-scoped port allocator and Traefik label generator for docker-compose"
  homepage "https://github.com/ylang-ylang/portmap"
  url "https://github.com/ylang-ylang/portmap/archive/refs/tags/V0.6.tar.gz"
  sha256 "a8487b1a943f2f9a9e523bc4a922c5ce6f340031e5c3f2b33cd7f6d8207009d4"
  license "MIT"

  depends_on "python@3.12"
  depends_on "coredns"
  depends_on "traefik"

  def install
    virtualenv_install_with_resources
  end

  test do
    (testpath/"ssh_config").write <<~EOS
      Host known-test-vm
        HostName 192.0.2.10
      Host *.example
        User developer
    EOS
    ENV["PORTMAP_CLIENT_STATE_DIR"] = (testpath/"client-state").to_s
    result = JSON.parse(shell_output("#{bin}/portmap discover --ssh-config #{testpath}/ssh_config"))
    assert_equal ["known-test-vm"], result.fetch("ssh_hosts")
    assert_nil result.fetch("direct")
  end
end
