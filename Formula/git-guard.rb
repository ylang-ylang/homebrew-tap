class GitGuard < Formula
  include Language::Python::Virtualenv

  desc "Enforce Git branch-flow policies from Mermaid documents"
  homepage "https://github.com/ylang-ylang/gitguard"
  url "https://github.com/ylang-ylang/gitguard/releases/download/V1.19/git_guard-1.19.tar.gz"
  version "1.19"
  sha256 "1c10ab3c593bc483e1580006c5b9db829304b5471024288c14c14f31081b722e"
  license "AGPL-3.0-only"

  depends_on "python-setuptools" => :build
  depends_on "python@3.13"
  depends_on "git"
  depends_on "bash"
  depends_on :linux
  depends_on arch: :x86_64

  def install
    virtualenv_install_with_resources
  end

  test do
    assert_equal "git-guard #{version}", shell_output("#{bin}/git-guard --version").strip
    system "git", "init", "-b", "main", testpath
    system "git", "config", "user.name", "Homebrew Test"
    system "git", "config", "user.email", "test@example.invalid"
    system "git", "-c", "commit.gpgsign=false", "commit", "--allow-empty", "-m", "initial"
    original = shell_output("git rev-parse HEAD").strip
    system "git", "branch", "dev"
    system bin/"git-guard", "install", "--repo", testpath, "--config", "dev-only"
    assert_path_exists testpath/".git-guard/policy.json"
    rejection = shell_output("git update-ref -d refs/heads/main 2>&1", 128)
    assert_match "PROTECTED_REF_DELETE", rejection
    assert_equal original, shell_output("git rev-parse refs/heads/main").strip
  end
end
