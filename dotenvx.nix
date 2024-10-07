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
  version = "v1.15.0";
  # some things that vary by system and may need to be overridden
  pkgFetchOutputHash = "sha256-lUjoy0njP2zmK2qATlk7SjgJW4zililqwf0KkqoWEvA=";
  nodeTarget = "node18-linux-x64";
  # fetch src and npmDeps
  src = fetchFromGitHub {
    owner = "dotenvx";
    repo = "dotenvx";
    rev = finalAttrs.version;
    hash = "sha256-WDICrM1Ry3IUpt7cA8Qz+UkEQ81H+DnfDwvbXCTncQ8=";
  };
  npmDeps = fetchNpmDeps {
    inherit (finalAttrs) src;
    hash = "sha256-jgebn59pgNiO5/8A/GLT2pLFrC9C7khgLeDQvyIkikc=";
  };
  # setup node_modules folder from fetched npmDeps
  node_modules = stdenv.mkDerivation {
    pname = "dotenvx-node_modules";
    inherit (finalAttrs) src version;
    nativeBuildInputs = [nodejs_18];
    buildPhase = ''
      runHook preBuild
      npm_config_cache=${finalAttrs.npmDeps} npm install
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
    nativeBuildInputs = [cacert nodejs_18];
    buildPhase = ''
      runHook preBuild
      mkdir $out
      export PKG_CACHE_PATH="$out"
      node ${finalAttrs.node_modules}/node_modules/.bin/pkg-fetch
      runHook postBuild
    '';
  };
  # patch customer node binary to run on nix
  patched-pkg-fetch-cache = stdenv.mkDerivation {
    pname = "dotenvx-patched-pkg-fetch-cache";
    inherit (finalAttrs) version;
    src = finalAttrs.pkg-fetch-cache;
    nativeBuildInputs = [autoPatchelfHook];
    buildInputs = [stdenv.cc.cc];  # node wants to link with libstdc++.so
    buildPhase = ''
      runHook preBuild
      mkdir -p $out
      fetchedBin=$(find . -iname 'fetched*')                # This might be something like `./v3.4/fetched-v18.5.0-linux-x64`
      builtBin=$(echo $fetchedBin | sed 's/fetched/built/') # but we want `./v3.4/built-v18.5.0-linux-x64`
      mv $fetchedBin $builtBin                              # pretend to be "built" to avoid pkg-fetch hash checking binary after patching
      cp -rT . $out                                         # copy to store, keeping expected dir structure
      runHook postBuild
    '';
  };
  # build dotenvx binary using `pkg`
  nativeBuildInputs = [nodejs_18];
  buildPhase = ''
    runHook preBuild
    cp -r ${finalAttrs.node_modules}/node_modules .               # restore node_modules, needed for pkg build
    export PKG_CACHE_PATH="${finalAttrs.patched-pkg-fetch-cache}" # setup pkg-fetch cache
    mkdir -p $out/bin                                             # make output dirs and run pkg to build binary
    node ./node_modules/.bin/pkg . \
      --no-bytecode \
      --pubic-packages "*" \
      --public \
      --target ${finalAttrs.nodeTarget} \
      --output $out/bin/${finalAttrs.pname}
    runHook postBuild
  '';
  # fixups seem to break the final binary. Instead we patch the node fetched by
  # pkg-fetch before running `pkg`.
  dontFixup = true;
})
