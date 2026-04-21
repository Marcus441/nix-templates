// src/modules/my_module.cpp
module;
// Global module fragment — put legacy #includes here
// (anything that hasn't adopted modules yet)
#include <iostream>
#include <string_view>

export module my_module;

// Exported functions — visible to any translation unit that does `import my_module;`
export void Greet(std::string_view name) {
  std::cout << "Hello, " << name << "!\n";
}

export int Add(int a, int b) {
  return a + b;
}

export void PrintResult(std::string_view label, int value) {
  std::cout << label << " = " << value << "\n";
}
