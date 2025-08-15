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
      node-rest-api = {
        path = ./node-rest-api;
        description = "Dev environment for a node.js rest api";
      };
      # rust = {
      #   path = ./rust;
      #   description = "Dev environment for rust";
      # };
    };
    defaultTemplate = self.templates.shell;
  };
}
