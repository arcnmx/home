{ config, lib, ... }: with lib; {
  hardware.display = mapAttrs (_: monitors: {
    inherit monitors;
  }) (import ./displays.nix { inherit lib; }).layouts;
}
