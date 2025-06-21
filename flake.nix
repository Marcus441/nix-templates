{
  description = "project templates";

  outputs = {self}: {
    templates = {
      cpp = {
        path = ./cpp;
        description = "Dev environment for C/C++";
      };
      # rust = {
      #   path = ./rust;
      #   description = "Dev environment for rust";
      # };
    };
    defaultTemplate = self.templates.shell;
  };
}
