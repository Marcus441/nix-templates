{
  description = "project templates";

  outputs = {self}: {
    templates = {
      # `nix flake init` with no -t copies templates.default
      default = self.templates.shell;

      cpp = {
        path = ./cpp;
        description = "Dev environment for C/C++";
      };
      cpp-jetson = {
        path = ./cpp-jetson;
        description = "Dev environment for C/C++ on the Jetson platform";
      };
      cpp-modern = {
        path = ./cpp-modern;
        description = "Dev environment for modern C++ with modules support";
      };
      dotnet = {
        path = ./dotnet;
        description = "Dev environment with dotnet sdk and runtime";
      };
      node = {
        path = ./node;
        description = "Dev environment for node.js";
      };
      node-rest-api = {
        path = ./node-rest-api;
        description = "Dev environment for a node.js rest api";
      };
      python-jetson = {
        path = ./python-jetson;
        description = "Dev Environment for Python on the jetson platform";
      };
      shell = {
        path = ./shell;
        description = "Minimal dev shell to fill in";
      };
      typst = {
        path = ./typst;
        description = "Dev environment for typst documents";
      };
    };
  };
}
