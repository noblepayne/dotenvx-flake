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
    pname = "node-modules";
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
    pname = "pkg-fetch-cache";
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
  nativeBuildInputs = [autoPatchelfHook];
  buildInputs = [nodejs_18 stdenv.cc.cc];
  #export PKG_CACHE_PATH="${finalAttrs.pkg-fetch-cache}/.pkg-cache"
  buildPhase = ''
    runHook preBuild
    export HOME=$(mktemp -d)
    mkdir -p $out/bin
    # restore node_modules
    cp -r ${finalAttrs.node_modules}/node_modules .
    # setup pkg-fetch cache
    export PKG_CACHE_PATH=$HOME/.pkg-cache
    mkdir -p $PKG_CACHE_PATH
    # copy downloaded file to our homedir cache
    cp -rT ${finalAttrs.pkg-fetch-cache}/.pkg-cache $PKG_CACHE_PATH
    chmod -R a+rwx $PKG_CACHE_PATH
    # patch to support nix/nixos
    autoPatchelf $PKG_CACHE_PATH
    # rename to built to avoid pkg-fetch hash checking
    mv $PKG_CACHE_PATH/v3.4/{fetched-v18.5.0-linux-x64,built-v18.5.0-linux-x64}
    # run pkg to build binary
    ./node_modules/.bin/pkg . --no-bytecode --pubic-packages "*" --public --target node18-linux-x64 --output $out/bin/dotenvx
    runHook postBuild
  '';
  # fixups seem to break the final binary. Instead we patch the node fetched by
  # pkg-fetch before running `pkg`.
  dontFixup = true;
})
