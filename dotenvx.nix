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
  # essential attrs
  pname = "dotenvx";
  version = "v1.5.0";
  # some things that vary by system and may need to be overridden
  pkgFetchOutputHash = "sha256-lUjoy0njP2zmK2qATlk7SjgJW4zililqwf0KkqoWEvA=";
  nodeTarget = "node18-linux-x64";
  # fetch src and deps
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
  # setup node_modules folder from fetched deps
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
  # run `pkg-fetch` to download custom node binary
  pkg-fetch-cache = stdenv.mkDerivation {
    pname = "dotenvx-pkg-fetch-cache";
    inherit (finalAttrs) src version;
    outputHash = finalAttrs.pkgFetchOutputHash;
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
  # patch customer node binary to run on nix
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
  # build dotenvx binary using `pkg`
  buildPhase = ''
    runHook preBuild
    export HOME=$(mktemp -d)
    mkdir -p $out/bin
    # restore node_modules
    cp -r ${finalAttrs.node_modules}/node_modules .
    # setup pkg-fetch cache
    export PKG_CACHE_PATH="${finalAttrs.patched-pkg-fetch-cache}"
    # run pkg to build binary
    ./node_modules/.bin/pkg . --no-bytecode --pubic-packages "*" --public --target ${finalAttrs.nodeTarget} --output $out/bin/dotenvx
    runHook postBuild
  '';
  # fixups seem to break the final binary. Instead we patch the node fetched by
  # pkg-fetch before running `pkg`.
  dontFixup = true;
})
