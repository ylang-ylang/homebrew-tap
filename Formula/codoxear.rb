class Codoxear < Formula
  include Language::Python::Virtualenv

  desc "Unofficial mobile handoff for Codex TUI sessions"
  homepage "https://github.com/yiwenlu66/codoxear"
  # Temporarily tracks the federation fork branch until upstream merges
  # (ylang-ylang/codoxear tag v0.1.0-fed.1 = upstream e42cfe6 + federation).
  url "https://github.com/ylang-ylang/codoxear/archive/refs/tags/v0.1.0-fed.1.tar.gz"
  version "0.1.0.fed.1"
  sha256 "7595b47b98a43e0f53b4b8db7b298d7755536377f917db6e244ad1761d7e4100"
  license "MIT"
  head "https://github.com/yiwenlu66/codoxear.git", branch: "main"

  # maturin is only available as a platform wheel (linux x86_64); lift these
  # when adding on_arm/on_macos wheels.
  depends_on :linux
  depends_on arch: :x86_64
  depends_on "pkgconf" => :build
  depends_on "python-setuptools" => :build
  depends_on "rust" => :build # cryptography compiles a Rust extension (maturin is the frontend, cargo the compiler)
  depends_on "freetype"
  depends_on "jpeg-turbo"
  depends_on "libffi"
  depends_on "libpng"
  depends_on "libtiff"
  depends_on "openssl@3"
  depends_on "python@3.13"
  depends_on "webp"
  depends_on "zlib"

  # -- build backends as wheels: Homebrew's pip wrapper forces
  #    --no-binary=:all:, and self-hosting backends (flit-core, hatchling,
  #    poetry-core) cannot bootstrap from sdist with --no-build-isolation.
  #    Wheels need no build step and are installed directly in `install`.
  resource "flit-core" do
    url "https://files.pythonhosted.org/packages/d9/f0/e546c28b937f094b354ca29b9060c5f1dd5043a332b2905049a51420b7a2/flit_core-4.2.0-py3-none-any.whl"
    sha256 "2bee22dc8ba89c2e35b4e1ad575e596aac945c85672dd8f3cad21b629036e044"
  end

  resource "poetry-core" do
    url "https://files.pythonhosted.org/packages/b7/25/7ed0a2ea4fe12f7fd0394387b5debbcd6fdbd06e5ac9daab96ba11471da8/poetry_core-2.5.0-py3-none-any.whl"
    sha256 "98ee465b66f7e14bb9fbe68fb5e00d0cff184f036993ec94610ae4b5612f3add"
  end

  resource "hatchling" do
    url "https://files.pythonhosted.org/packages/32/64/4afe5dd77b2939a93e8c9513f8082dbd049ecba9c1484a379a0f6ae29d6b/hatchling-1.33.0-py3-none-any.whl"
    sha256 "415290b84f464d2884303fca8974d38e7b85579069fab02a15db0828fbb1446d"
  end

  resource "hatch-vcs" do
    url "https://files.pythonhosted.org/packages/5f/48/1f85cee4b7b4f40b9b814b1febbc661bda6ced9649e410a0b74f6e415dd0/hatch_vcs-0.5.0-py3-none-any.whl"
    sha256 "b49677dbdc597460cc22d01b27ab3696f5e16a21ecf2700fb01bc28e1f2a04a7"
  end

  resource "hatch-fancy-pypi-readme" do
    url "https://files.pythonhosted.org/packages/58/b4/ad71e051b34f1935783de37beffee16e343ff2514b204dc515f9e939d4af/hatch_fancy_pypi_readme-25.1.0-py3-none-any.whl"
    sha256 "ce0134c40d63d874ac48f48ccc678b8f3b62b8e50e9318520d2bffc752eedaf3"
  end

  resource "setuptools-scm" do
    url "https://files.pythonhosted.org/packages/da/f5/54538a1f17ea753c42b0928dc2e62986d463f8c393340b9a1e602f2d4dd9/setuptools_scm-10.3.4-py3-none-any.whl"
    sha256 "82f34c3e3084fc2b57d397200637cc13f2338004052d2fee47baa5f0e902464e"
  end

  resource "packaging" do
    url "https://files.pythonhosted.org/packages/63/34/ba1c580383c9eada3711951fef0795c80b829a078d72188184bcab9dd527/packaging-26.3-py3-none-any.whl"
    sha256 "d7193f7c8e4e93f444fde0262bf90af30e16fa0ad0ad44cb553c87339b23cd1c"
  end

  resource "pathspec" do
    url "https://files.pythonhosted.org/packages/f1/d9/7fb5aa316bc299258e68c73ba3bddbc499654a07f151cba08f6153988714/pathspec-1.1.1-py3-none-any.whl"
    sha256 "a00ce642f577bf7f473932318056212bc4f8bfdf53128c78bbd5af0b9b20b189"
  end

  resource "pluggy" do
    url "https://files.pythonhosted.org/packages/40/9e/2b38731e0fc536806f16490e1a12d7f0dc2a1235aa8cc07bcc75416a7daa/pluggy-1.7.0-py3-none-any.whl"
    sha256 "7dd7b0d8832ba3cb632c306926ded123429211b83641b35dc5c41ad2d34f9bec"
  end

  resource "trove-classifiers" do
    url "https://files.pythonhosted.org/packages/30/81/0da8afb52a71d0a4f2bd3152357b1a441e393b286374802b9d3addab4ab5/trove_classifiers-2026.9.21.13-py3-none-any.whl"
    sha256 "8b1ff4f9c191b1040b71c37f1e445ab99732911e3cd91de52838453a854d7a17"
  end

  resource "typing-extensions" do
    url "https://files.pythonhosted.org/packages/49/d3/b8441a820a491ddfc024b0b0cf0393375b75ea13866d9c66727e54c2fc80/typing_extensions-4.16.0-py3-none-any.whl"
    sha256 "481caa481374e813c1b176ada14e97f1f67a4539ce9cfeb3f350d78d6370c2e8"
  end

  resource "expandvars" do
    url "https://files.pythonhosted.org/packages/7f/e6/79c43f7a55264e479a9fbf21ddba6a73530b3ea8439a8bb7fa5a281721af/expandvars-1.1.2-py3-none-any.whl"
    sha256 "d1652fe4e61914f5b88ada93aaedb396446f55ae4621de45c8cb9f66e5712526"
  end

  resource "vcs-versioning" do
    url "https://files.pythonhosted.org/packages/73/1d/ad4064bf12f4503bf61e65d74c93c523672776d25ee0a06aaf42ae09ef3f/vcs_versioning-2.6.0-py3-none-any.whl"
    sha256 "f8bebd1302ebc12e67ceb30fc7dd698ec969414b6fa43b30c3f14ac9b1e72c41"
  end

  resource "pybind11" do
    url "https://files.pythonhosted.org/packages/33/fd/8762f7ee3e4e4be6d1d846cffb4916dd9bb02b2f800d3603718a0efe494c/pybind11-3.1.0-py3-none-any.whl"
    sha256 "b8488090f8acffbcb6b5d6a85571a6827a0a2981ffb75e5a0b27b87c4a6b7dd0"
  end

  resource "wheel" do
    url "https://files.pythonhosted.org/packages/2e/29/69cfbb602cd91690c55d38ba9fe53e6a7e76a6fa647bf38f19c138d25449/wheel-0.48.0-py3-none-any.whl"
    sha256 "3217dcc807155e45db462d7ef2431f5ddda0d7273b700d05a67b271ceb1287ab"
  end

  resource "maturin" do
    url "https://files.pythonhosted.org/packages/0a/dc/e77f490557cb5e045a75c3d18a7965425ac576235c970dfff4d903eb2c74/maturin-1.16.0-py3-none-manylinux2010_x86_64.manylinux_2_12_x86_64.musllinux_1_1_x86_64.whl"
    sha256 "837db2f4d93d4899c3ac393fb3cc9eebf35b6002336e5d574f4a4fb6c49fe283"
  end

  # -- sdists built with the backends above --
  resource "setuptools" do
    url "https://files.pythonhosted.org/packages/70/b3/c19426f783614d625699a4b247faf628ea9ab1db228674491767b417f9e1/setuptools-84.2.1.tar.gz"
    sha256 "3ff8b3b5492a0aa66960f4419365a86b84e013070d4313e4d4a6894f5d64d6bc"
  end

  resource "cython" do
    url "https://files.pythonhosted.org/packages/99/ca/18e324972e5cac914816fdd7bb03e19a455b90039c277a538f7781b50c85/cython-3.3.1.tar.gz"
    sha256 "e0e45989e821bef6aa9ae15c7d583ab5e055f7406c4b3624e49e06d24e90375a"
  end

  resource "aiohappyeyeballs" do
    url "https://files.pythonhosted.org/packages/ce/f4/eec0465c2f67b2664688d0240b3212d5196fd89e741df67ddb81f8d35658/aiohappyeyeballs-2.7.1.tar.gz"
    sha256 "065665c041c42a5938ed220bdcd7230f22527fbec085e1853d2402c8a3615d9d"
  end

  resource "aiohttp" do
    url "https://files.pythonhosted.org/packages/6c/4c/bdccd81e9ee225b69c60e7766c9a5b05364f118f4d383713b89a682d772d/aiohttp-3.14.5.tar.gz"
    sha256 "5558a7f5a05af9ecf744af91e5baefc436f93c9333e656c27ec253f9a6bbe178"
  end

  resource "aiosignal" do
    url "https://files.pythonhosted.org/packages/61/62/06741b579156360248d1ec624842ad0edf697050bbaf7c3e46394e106ad1/aiosignal-1.4.0.tar.gz"
    sha256 "f47eecd9468083c2029cc99945502cb7708b082c232f9aca65da147157b251c7"
  end

  resource "attrs" do
    url "https://files.pythonhosted.org/packages/9a/8e/82a0fe20a541c03148528be8cac2408564a6c9a0cc7e9171802bc1d26985/attrs-26.1.0.tar.gz"
    sha256 "d03ceb89cb322a8fd706d4fb91940737b6642aa36998fe130a9bc96c985eff32"
  end

  resource "certifi" do
    url "https://files.pythonhosted.org/packages/fd/11/b524cbd9bbdaca58608e4cf4053fd463417549e1959fa8d3aa18319f9555/certifi-2026.10.23.tar.gz"
    sha256 "a9895e6e2758b371e0545e321a3a8fd1fcfd9829ada8824a936dfb16aaaf36cd"
  end

  resource "cffi" do
    url "https://files.pythonhosted.org/packages/9e/ef/008a1939e372c06329a3fce4279c02f328488f3526744906eeec3da7ad5f/cffi-2.1.1.tar.gz"
    sha256 "dd31f52ea1086513bb9df30f8fcee9b8918323ae067a3d5b78bc826a000712be"
  end

  resource "charset-normalizer" do
    url "https://files.pythonhosted.org/packages/33/1c/f41d4e74c28ab327ff3acd36053f7ea506c55872d7a90b0fa71aa3ab0c89/charset_normalizer-3.5.2.tar.gz"
    sha256 "39de2a259fc954455c57274dc94c79d5842774e1247a016aff30bc0efed0f4ef"
  end

  # Installed before cryptography: its build imports cffi → pycparser.
  resource "pycparser" do
    url "https://files.pythonhosted.org/packages/cb/27/eeb9f307bf07060f3d9f9aa0fb8c15b01bdfded0a941e4b2719c7f94cacd/pycparser-3.12.tar.gz"
    sha256 "f03387877eab82ce01bbdfd0ba7252ee55a90b1c708d5129e2ce915475cf1db6"
  end

  resource "cryptography" do
    url "https://files.pythonhosted.org/packages/9d/af/182eb91b0df3fe75c4d9f26fe70684569566745f6ba7e5c9c73a862c5252/cryptography-50.0.2.tar.gz"
    sha256 "7b46165bb56eb4704e2eaaf86f3c940d19154535d9b0ca7d6d590b04060e00d5"
  end

  resource "frozenlist" do
    url "https://files.pythonhosted.org/packages/2d/f5/c831fac6cc817d26fd54c7eaccd04ef7e0288806943f7cc5bbf69f3ac1f0/frozenlist-1.8.0.tar.gz"
    sha256 "3ede829ed8d842f6cd48fc7081d7a41001a56f1f38603f9d49bf3020d59a31ad"
  end

  resource "http_ece" do
    url "https://files.pythonhosted.org/packages/7c/af/249d1576653b69c20b9ac30e284b63bd94af6a175d72d87813235caf2482/http_ece-1.2.1.tar.gz"
    sha256 "8c6ab23116bbf6affda894acfd5f2ca0fb8facbcbb72121c11c75c33e7ce8cff"
  end

  resource "idna" do
    url "https://files.pythonhosted.org/packages/f5/08/8eea9d4b8302028f3abb2c0813953f7aec26d33b7a8960ed760e65ff29fa/idna-3.20.tar.gz"
    sha256 "a7db850025b95ded1eae8a46181a1a6c56c92c96f0e2b005d9ff8dc0210cab44"
  end

  resource "multidict" do
    url "https://files.pythonhosted.org/packages/7b/6b/29ef8e752f5854dcc267ded0652c475bec99b86f255957a0d4fcad657b18/multidict-7.2.1.tar.gz"
    sha256 "e8af3e6f1bdbc31fd762b094133b478b89988eaebc63cbe82b1d9e3bbd15cede"
  end

  resource "pillow" do
    url "https://files.pythonhosted.org/packages/ce/a4/9cc30690a394a8305e8be4c9036aa16d0dfddadd09079860b582f562496d/pillow-13.0.0.tar.gz"
    sha256 "cdcd1ba258178f7356d74170c9a81ba4eab6a5d55748bc402a5a2a6fe6be3510"
  end

  resource "propcache" do
    url "https://files.pythonhosted.org/packages/b3/9a/9fbf4e4ec0c2d7f1c32519fff782ef467859b8faa9fbc5331a96f6395d43/propcache-0.5.4.tar.gz"
    sha256 "ff6b113f50bc066a698db5d944d2c6dc7507168dd3341e255a8892fd0715a558"
  end

  # py-vapid ships no sdist on PyPI (wheel only); pure Python, universal wheel.
  resource "py-vapid" do
    url "https://files.pythonhosted.org/packages/6b/46/8843d8e00eb4fcece8e12c109ecf5b17a3d4cc9355dab23c2585cb51ed3c/py_vapid-1.9.6-py2.py3-none-any.whl"
    sha256 "06d775951016f63f0d0d6dd8babd333fc2f831f0769fd5db2e1ec8cfbbccc70f"
  end

  resource "pywebpush" do
    url "https://files.pythonhosted.org/packages/54/ff/db9efe7454d329bfa6fe433e0f881eb9d28489fc4b8427ee2fbaedc5f42b/pywebpush-2.5.0.tar.gz"
    sha256 "8260f8e42d70ed95a3bd00527ffcb43b5b3df8983a4a48b059fe29b06dc3d92c"
  end

  resource "requests" do
    url "https://files.pythonhosted.org/packages/ac/c3/e2a2b89f2d3e2179abd6d00ebd70bff6273f37fb3e0cc209f48b39d00cbf/requests-2.34.2.tar.gz"
    sha256 "f288924cae4e29463698d6d60bc6a4da69c89185ad1e0bcc4104f584e960b9ed"
  end

  resource "urllib3" do
    url "https://files.pythonhosted.org/packages/e3/05/b17359e1cefb4f909b5e40b1b90a496d987258916dbbf88e842c729f510e/urllib3-2.8.0.tar.gz"
    sha256 "63bf2ead4c879426ebf22ef2a781eeb4aa3b4ae798a0435506f8687fd5bb9b63"
  end

  resource "websockets" do
    url "https://files.pythonhosted.org/packages/21/f7/bc3a25c5ec26ce62ce487690becc2f3710bbc7b33338f005ad390db0b986/websockets-16.1.1.tar.gz"
    sha256 "db234eda965dcce15df96bb9709f587cd87d4d52aaf0e80e2f34ec04c7670c57"
  end

  resource "yarl" do
    url "https://files.pythonhosted.org/packages/75/16/e8be8e2fb175bbf41a0680381a319f1199fae256588241a2ac8677eafb49/yarl-1.25.1.tar.gz"
    sha256 "03dd38de09bc213e9a8b29761eec33ee1d5318dac0e49d8af36e4d27830e23a7"
  end

  WHEEL_RESOURCES = %w[
    flit-core poetry-core hatchling hatch-vcs hatch-fancy-pypi-readme
    setuptools-scm packaging pathspec pluggy trove-classifiers
    typing-extensions expandvars vcs-versioning pybind11 wheel maturin py-vapid
  ].freeze

  # Bypass std_pip_args (--no-binary=:all:) for pure/platform wheels.
  # cached_download has Homebrew's hash-prefixed name without the .whl
  # suffix, which pip rejects — copy under the original filename first.
  def pip_wheel(res)
    wheel = buildpath/"brew_wheels"/res.downloader.basename
    wheel.dirname.mkpath
    cp res.cached_download, wheel
    system Formula["python@3.13"].opt_bin/"python3.13", "-m", "pip",
           "--python=#{libexec}/bin/python", "install", "--no-deps", wheel
  end

  def install
    venv = virtualenv_create(libexec, "python3.13")
    # Builds (e.g. cryptography's maturin step) invoke backend CLIs by name.
    ENV.prepend_path "PATH", libexec/"bin"
    venv.pip_install resource("setuptools"), build_isolation: false
    WHEEL_RESOURCES.each { |name| pip_wheel(resource(name)) }
    venv.pip_install resource("cython"), build_isolation: false
    resources.each do |r|
      next if WHEEL_RESOURCES.include?(r.name) || %w[setuptools cython].include?(r.name)

      venv.pip_install r, build_isolation: false
    end
    venv.pip_install_and_link buildpath, build_isolation: false

    # Upstream packaging bug: pyproject package-data omits static/dist/ and
    # most of static/vendor/, so pip installs a partial UI and the page stays
    # black. Merge the complete static tree from the source checkout (the /. form
    # copies contents; installing the dir itself would nest as static/static).
    cp_r "codoxear/static/.", libexec/"lib/python3.13/site-packages/codoxear/static"
  end

  def post_install
    (var/"codoxear").mkpath
  end

  service do
    run [opt_bin/"codoxear-server"]
    working_dir var/"codoxear"
    keep_alive true
    log_path var/"log/codoxear.log"
    error_log_path var/"log/codoxear.error.log"
  end

  def caveats
    <<~EOS
      codoxear-server reads a .env file from its working directory. To run it
      under `brew services`, create:
        #{var}/codoxear/.env
      containing at least CODEX_WEB_PASSWORD (see .env.example upstream).

      Optional system tools (LibreOffice previews, ffmpeg conversion, tmux
      sessions) are checked by:
        codoxear-doctor

      Upstream's scripts/deploy.sh remains the reference for snapshot-style
      systemd deployment; this formula is the brew-native alternative.
    EOS
  end

  test do
    # codoxear-server validates config before parsing flags: without a
    # password it exits 2 with this message — proof the venv imports cleanly.
    assert_match "CODEX_WEB_PASSWORD", shell_output("#{bin}/codoxear-server --help 2>&1", 2)
    assert_match "usage", shell_output("#{bin}/codoxear-doctor --help 2>&1")
  end
end
