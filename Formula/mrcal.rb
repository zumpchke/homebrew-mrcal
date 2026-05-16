class Mrcal < Formula
  desc "Calibration routines, camera models, and photogrammetry"
  homepage "https://mrcal.secretsauce.net/"
  url "https://github.com/dkogan/mrcal/archive/refs/tags/v2.5.2.tar.gz"
  sha256 "f0a8471fc5dc3bba3719c2f8aaf968d6fa074903575ef35ddbae33ad5ea1ccc1"
  license "Apache-2.0"

  depends_on "libdogleg" # from this tap
  depends_on "gcc"
  depends_on "suite-sparse"
  depends_on "libpng"
  depends_on "jpeg"
  depends_on "numpy"
  depends_on "python@3.13"
  depends_on "re2c" => :build

  resource "mrbuild" do
    url "https://github.com/dkogan/mrbuild/archive/refs/tags/v1.16.tar.gz"
    sha256 "f2ae97ce0b6a2d5bfab132a27757c269cb378c22bc4b5e1e0e36380abc954433"
  end

  # stb is a single-header image library; no Homebrew formula exists.
  resource "stb" do
    url "https://raw.githubusercontent.com/nothings/stb/31c1ad37456438565541f4919958214b6e762fb4/stb_image.h"
    sha256 "594c2fe35d49488b4382dbfaec8f98366defca819d916ac95becf3e75f4200b3"
  end

  resource "numpysane" do
    url "https://files.pythonhosted.org/packages/source/n/numpysane/numpysane-0.42.tar.gz"
    sha256 "47f240cab2fd05a26776b91c0e07e03b1ebaf943005bcea0fc1585ded079b0bd"
  end

  def python3
    Formula["python@3.13"].opt_bin/"python3.13"
  end

  # cv2.solvePnP works fine with 4 coplanar points (AprilTag corners).
  # mrcal raised the minimum from 4 to 6 in Oct 2025 but that breaks
  # single-tag calibration objects.
  patch :DATA

  def install
    resource("mrbuild").stage { (buildpath/"mrbuild-1.16").install Dir["*"] }
    buildpath.install_symlink "mrbuild-1.16" => "mrbuild"

    # stb: expose as <stb/stb_image.h> from buildpath
    (buildpath/"stb").mkpath
    resource("stb").stage { cp "stb_image.h", buildpath/"stb" }

    gcc_major = Formula["gcc"].version.major.to_i
    ENV["CC"]  = Formula["gcc"].opt_bin/"gcc-#{gcc_major}"
    ENV["CXX"] = Formula["gcc"].opt_bin/"g++-#{gcc_major}"

    # mrbuild reads CFLAGS/LDFLAGS rather than CPPFLAGS; keg-only deps need
    # explicit paths, and linked deps need HOMEBREW_PREFIX added since mrbuild
    # won't see the standard CPPFLAGS
    ENV.append "CFLAGS",  "-I#{HOMEBREW_PREFIX}/include"
    ENV.append "CFLAGS",  "-I#{Formula["suite-sparse"].opt_include}"
    ENV.append "CFLAGS",  "-I#{Formula["jpeg"].opt_include}"
    ENV.append "LDFLAGS", "-L#{HOMEBREW_PREFIX}/lib"
    ENV.append "LDFLAGS", "-L#{Formula["suite-sparse"].opt_lib}"
    ENV.append "LDFLAGS", "-L#{Formula["jpeg"].opt_lib}"

    # Ensure code-generation scripts find python3.13, not the system python3
    ENV.prepend_path "PATH", Formula["python@3.13"].opt_bin

    # Install numpysane to a build-time prefix so mrcal-genpywrap.py can import it
    numpysane_buildprefix = buildpath/"numpysane_build"
    resource("numpysane").stage do
      system python3, "-m", "pip", "install", *std_pip_args(prefix: numpysane_buildprefix, build_isolation: false), "."
    end
    ENV.prepend_path "PYTHONPATH",
      numpysane_buildprefix/Language::Python.site_packages("python3.13")

    system "make", "PYTHON_VERSION_FOR_EXTENSIONS=3.13"

    # --- CLI tools (Python scripts) ---
    scripts = Dir["mrcal-*"].select { |f| File.executable?(f) && !File.directory?(f) }
    inreplace scripts, %r{^#!/usr/bin/env python3}, "#!#{python3}"
    bin.install scripts

    # --- Shared library ---
    lib.install Dir["libmrcal.dylib*"]

    # --- Headers ---
    (include/"mrcal").install Dir[
      "mrcal.h", "image.h", "internal.h", "basic-geometry.h",
      "poseutils.h", "triangulation.h", "types.h", "stereo.h",
      "heap.h", "python-cameramodel-converter.h"
    ]

    # --- Python extension package ---
    site_packages = prefix/Language::Python.site_packages("python3.13")
    (site_packages/"mrcal").install Dir["mrcal/*"]

    # --- numpysane: install to libexec to avoid conflicts with any
    #     system-installed numpysane, exposed via a .pth file ---
    resource("numpysane").stage do
      system python3, "-m", "pip", "install", *std_pip_args(prefix: libexec, build_isolation: false), "."
    end
    (site_packages/"mrcal-numpysane.pth").write "#{libexec/Language::Python.site_packages("python3.13")}\n"

    # --- Man pages ---
    # Built on demand; mrcal must be importable so each script can run --help
    man_targets = scripts.map { |f| "#{File.basename(f)}.1" }
    ENV.prepend_path "PYTHONPATH", buildpath
    system "make", "PYTHON_VERSION_FOR_EXTENSIONS=3.13", *man_targets
    man1.install Dir["*.1"]
  end

  test do
    system bin/"mrcal-calibrate-cameras", "--help"
    system python3, "-c", "import mrcal; mrcal.supported_lensmodels()"
  end
end

__END__
diff --git a/mrcal/calibration.py b/mrcal/calibration.py
--- a/mrcal/calibration.py
+++ b/mrcal/calibration.py
@@ -563,8 +563,8 @@
             (np.isfinite(observation_qxqy_pinhole[..., 1]))

-        if np.count_nonzero(i) < 6:
-            raise SolvePnPerror_toofew(f"Insufficient observations; need at least 6; got {np.count_nonzero(i)} instead. Cannot estimate initial extrinsics for {what}")
+        #if np.count_nonzero(i) < 6:
+        #    raise SolvePnPerror_toofew(f"Insufficient observations; need at least 6; got {np.count_nonzero(i)} instead. Cannot estimate initial extrinsics for {what}")

         observations_local = observation_qxqy_pinhole[i]
