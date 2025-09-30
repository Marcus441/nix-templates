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
      typst = {
        path = ./typst;
        description = "Dev environment for typst documents";
      };
    };
    defaultTemplate = self.templates.shell;
  };
}
