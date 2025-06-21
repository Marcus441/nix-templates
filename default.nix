{
  flake.templates = {
    c = {
      path = ./c;
      description = "Dev environment for C/C++";
    };

    rust = {
      path = ./rust;
      description = "Dev environment for rust";
    };
  };
}
