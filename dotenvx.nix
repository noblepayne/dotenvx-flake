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
    outputHash = "sha256-lUjoy0njP2zmK2qATlk7SjgJW4zililqwf0KkqoWEvA=";
    outputHashAlgo = "sha256";
    outputHashMode = "recursive";
    buildInputs = [cacert];
    buildPhase = ''
      runHook preBuild
      export HOME=$(mktemp -d)
      ${finalAttrs.node_modules}/node_modules/.bin/pkg-fetch
      mkdir $out
      cp -rT $HOME/.pkg-cache $out
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
      mkdir -p $out
      fetchedBin=$(find . -iname 'fetched*')
      builtBin=$(echo $fetchedBin | sed 's/fetched/built/')
      # pretend to be "built" to avoid pkg-fetch hash checking binary after patching
      mv $fetchedBin $builtBin
      # copy to store, keeping expected path
      cp -rT . $out
      runHook postBuild
    '';
  };
  buildPhase = ''
    runHook preBuild
    export HOME=$(mktemp -d)
    mkdir -p $out/bin
    # restore node_modules
    cp -r ${finalAttrs.node_modules}/node_modules .
    # setup pkg-fetch cache
    export PKG_CACHE_PATH="${finalAttrs.patched-pkg-fetch-cache}"
    # run pkg to build binary
    ./node_modules/.bin/pkg . --no-bytecode --pubic-packages "*" --public --target node18-linux-x64 --output $out/bin/dotenvx
    runHook postBuild
  '';
  # fixups seem to break the final binary. Instead we patch the node fetched by
  # pkg-fetch before running `pkg`.
  dontFixup = true;
})
