{
  description = "project templates";

  outputs = {self}: {
    templates = {
      cpp = {
        path = ./cpp;
        description = "Dev environment for C/C++";
      };
      cpp-jetson = {
        path = ./cpp-jetson;
        description = "Dev Dev environment for C/C++ on the Jetson platform";
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
