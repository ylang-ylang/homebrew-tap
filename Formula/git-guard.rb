class GitGuard < Formula
  include Language::Python::Virtualenv

  desc "Enforce Git branch-flow policies from Mermaid documents"
  homepage "https://github.com/ylang-ylang/gitguard"
  url "https://github.com/ylang-ylang/gitguard/releases/download/V1.18/git_guard-1.18.tar.gz"
  version "1.18"
  sha256 "0316a093bda711e43786c4f9697fe258b5a2da7783adadde75c4e9f86789938f"
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
