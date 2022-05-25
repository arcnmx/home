{ ... }: {
  config = {
    /*targets.shanghai = { # TODO
      nodeNames = [ "shanghai" ];
    };*/
    nodes.shanghai = { ... }: {
      imports = [
        ./.
      ];
    };
  };
}
