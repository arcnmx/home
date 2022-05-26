{ lib, trusted, ... }: with lib; {
  imports = trusted.import.nixos "default";
}
