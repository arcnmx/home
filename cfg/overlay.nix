self: super: {
  terraform-providers = super.terraform-providers // {
    tailscale = self.terraform-providers.mkProvider rec {
      owner = "tailscale";
      provider-source-address = "registry.terraform.io/${owner}/${owner}";
      repo = "terraform-provider-tailscale";
      rev = "v${version}";
      sha256 = "sha256-/qC8TOtoVoBTWeAFpt2TYE8tlYBCCcn/mzVQ/DN51YQ=";
      vendorSha256 = "sha256-8EIxqKkVO706oejlvN79K8aEZAF5H2vZRdr5vbQa0l4=";
      version = "0.13.5";
    };
  };
}
