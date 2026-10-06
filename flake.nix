{
  description = "nixcentre: an offline home server (Wikipedia, movies & TV, books, audiobooks) on a ThinkCentre Tiny";

  # The NixOS release channel rather than the GitHub branch: the channel only moves
  # after Hydra has built and tested everything, so every package is already in the
  # binary cache when you update over a (metered) phone connection.
  inputs.nixpkgs.url = "https://channels.nixos.org/nixos-26.05/nixexprs.tar.xz";

  outputs =
    { nixpkgs, ... }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
    in
    {
      nixosConfigurations.nixcentre = nixpkgs.lib.nixosSystem {
        modules = [
          ./hosts/nixcentre
          { nixpkgs.hostPlatform = system; }
        ];
      };

      # `nix flake check` boots the server in VMs and tests it (slow without KVM).
      checks.${system} = {
        vm = pkgs.testers.runNixOSTest ./tests/vm.nix;
        wifi = pkgs.testers.runNixOSTest ./tests/wifi.nix;
      };

      formatter.${system} = pkgs.nixfmt-tree;
    };
}
