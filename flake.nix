{
  description = "zig toolchain (zig + zls)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    zig-overlay.url = "github:mitchellh/zig-overlay";
    zls.url = "github:zigtools/zls/0.16.x";
  };

  outputs = { self, nixpkgs, zig-overlay, zls }:
  let
    version = "0.16.0";

    systems = builtins.attrNames zig-overlay.packages;
    forAllSystems = f: builtins.listToAttrs (map (system: {
      name = system;
      value = f system;
    }) systems);

    pkgsFor = system: import nixpkgs { inherit system; };

    # $HOME is fake/unwritable in nix build sandboxes, and zig defaults its
    # global cache dir under $HOME
    zigFor = system:
      let
        pkgs = pkgsFor system;
        zigReal = zig-overlay.packages.${system}.${version};
      in
      pkgs.symlinkJoin {
        name = "zig-${version}";
        paths = [ zigReal ];
        nativeBuildInputs = [ pkgs.makeWrapper ];
        postBuild = ''
          wrapProgram $out/bin/zig --run '
            : "''${ZIG_GLOBAL_CACHE_DIR:=''${TMPDIR:-/tmp}/zig-cache}"
            export ZIG_GLOBAL_CACHE_DIR
          '
        '';
      };

    zlsFor = system: zls.packages.${system}.default;

    mkZigPackage = { pkgs, zig, pname, src, zigArgs ? "" }:
      pkgs.stdenv.mkDerivation {
        name = pname;
        nativeBuildInputs = [ zig ];
        inherit src;
        buildPhase = ''
          zig build --release=fast ${zigArgs}
        '';
        installPhase = ''
          zig build --prefix "$out" --release=fast ${zigArgs}
        '';
      };

    mkZigShell = { pkgs, extraPackages ? [] }:
      pkgs.mkShell {
        packages = [ (zigFor pkgs.system) (zlsFor pkgs.system) ] ++ extraPackages;
      };
  in
  {
    inherit forAllSystems;

    packages = forAllSystems (system: {
      zig = zigFor system;
      zls = zlsFor system;
    });

    lib = {
      inherit pkgsFor mkZigPackage mkZigShell;
    };

    devShells = forAllSystems (system: {
      default = (pkgsFor system).mkShell {
        packages = [ (zigFor system) (zlsFor system) ];
      };
    });
  };
}
