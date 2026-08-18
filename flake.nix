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

    zigFor = system: zig-overlay.packages.${system}.${version};
    zlsFor = system: zls.packages.${system}.default;
  in
  {
    inherit forAllSystems;

    packages = forAllSystems (system: {
      zig = zigFor system;
      zls = zlsFor system;
    });

    # $HOME is fake/unwritable in nix build sandboxes. zig defaults its
    # global cache dir under $HOME, so point it at $TMPDIR instead.
    # use it as
    #   preBuild = zig-toolchain.lib.zigCacheFix;
    lib.zigCacheFix = ''
      export ZIG_GLOBAL_CACHE_DIR="$TMPDIR/zig-cache"
    '';

    devShells = forAllSystems (system:
      let pkgs = import nixpkgs { inherit system; };
      in {
        default = pkgs.mkShell {
          packages = [ (zigFor system) (zlsFor system) ];
          ZIG_GLOBAL_CACHE_DIR = ".zig-cache";
        };
      });

    # legacy alias for `devShell` (i.e. without -s)
    devShell = forAllSystems (system: self.devShells.${system}.default);
  };
}
