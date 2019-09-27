{ config }: {
  schemes = with config.base16.alias; [ dark light ];
  alias.light = "atelier.atelier-sulphurpool-light";
  alias.dark = "unclaimed.monokai";
}
