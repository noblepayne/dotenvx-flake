{
  system,
  stdenv,
  fetchFromGitHub,
  fetchNpmDeps,
  nodejs_18,
  cacert,
  autoPatchelfHook,
  ...
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "dotenvx";
  version = "v1.5.0";
  src = fetchFromGitHub {
    owner = "dotenvx";
    repo = "dotenvx";
    rev = finalAttrs.version;
    hash = "sha256-W2JnWRHwtEF/dw+oMgyZFQXBlw2QVNTYZnwQMAS0T8w=";
  };
  deps = fetchNpmDeps {
    inherit (finalAttrs) src version;
    pname = "dotenvx-deps";
    hash = "sha256-dQcIU0UjcBMqRw+Xk75HkKWG2b4Uq0YFnHcaF1jtGp8=";
  };
  node_modules = stdenv.mkDerivation {
    pname = "dotenvx-node_modules";
    inherit (finalAttrs) src version;
    buildInputs = [nodejs_18];
    buildPhase = ''
      runHook preBuild
      npm_config_cache=${finalAttrs.deps} npm install
      patchShebangs node_modules
      mkdir $out
      mv node_modules $out
      runHook postBuild
    '';
  };
  pkg-fetch-cache = stdenv.mkDerivation {
    pname = "dotenvx-pkg-fetch-cache";
    inherit (finalAttrs) src version;
    outputHash =
      if system == "x86_64-linux"
      then "sha256-pnEXmk3z2amfZbxaDRLOASRlib6cL7C7ZuxKLaLD61Y="
      else "";
    outputHashAlgo = "sha256";
    outputHashMode = "recursive";
    buildInputs = [cacert nodejs_18];
    buildPhase = ''
      runHook preBuild
      export HOME=$(mktemp -d)
      ${finalAttrs.node_modules}/node_modules/.bin/pkg-fetch
      mkdir $out
      mv $HOME/.pkg-cache $out
      runHook postBuild
    '';
  };
  patched-pkg-fetch-cache = stdenv.mkDerivation {
    pname = "dotenvx-patched-pkg-fetch-cache";
    inherit (finalAttrs) version;
    src = finalAttrs.pkg-fetch-cache;
    nativeBuildInputs = [autoPatchelfHook];
    buildInputs = [stdenv.cc.cc];
    buildPhase = ''
      runHook preBuild
      mkdir -p $out/.pkg-cache
      cp -rT .pkg-cache $out/.pkg-cache
      # pretend to be "built" to avoid pkg-fetch hash checking binary after patching
      mv $out/.pkg-cache/v3.4/{fetched-v18.5.0-linux-x64,built-v18.5.0-linux-x64}
      runHook postBuild
    '';
  };
  buildInputs = [nodejs_18];
  #export PKG_CACHE_PATH=$HOME/.pkg-cache
  #mkdir -p $PKG_CACHE_PATH
  # copy downloaded file to our homedir cache
  #cp -rT ${finalAttrs.patched-pkg-fetch-cache}/.pkg-cache $PKG_CACHE_PATH
  # chmod -R a+rwx $PKG_CACHE_PATH
  # patch to support nix/nixos
  # autoPatchelf $PKG_CACHE_PATH
  # rename to built to avoid pkg-fetch hash checking
  #mv $PKG_CACHE_PATH/v3.4/{fetched-v18.5.0-linux-x64,built-v18.5.0-linux-x64}

  buildPhase = ''
    runHook preBuild
    export HOME=$(mktemp -d)
    mkdir -p $out/bin
    # restore node_modules
    cp -r ${finalAttrs.node_modules}/node_modules .
    # setup pkg-fetch cache
    export PKG_CACHE_PATH="${finalAttrs.patched-pkg-fetch-cache}/.pkg-cache"
    # run pkg to build binary
    ./node_modules/.bin/pkg . --no-bytecode --pubic-packages "*" --public --target node18-linux-x64 --output $out/bin/dotenvx
    runHook postBuild
  '';
  # fixups seem to break the final binary. Instead we patch the node fetched by
  # pkg-fetch before running `pkg`.
  dontFixup = true;
})
