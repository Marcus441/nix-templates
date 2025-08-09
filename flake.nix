{
  description = "project templates";

  outputs = {self}: {
    templates = {
      cpp = {
        path = ./cpp;
        description = "Dev environment for C/C++";
      };
      node = {
        path = ./node;
        description = "Dev environment for node.js";
      };
      # rust = {
      #   path = ./rust;
      #   description = "Dev environment for rust";
      # };
    };
    defaultTemplate = self.templates.shell;
  };
}
