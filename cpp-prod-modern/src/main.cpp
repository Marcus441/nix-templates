#include <iostream>

import myproject.greeting;

int main() {
  std::cout << myproject::Greeting("World") << "\n";
  std::cout << "40 + 2 = " << myproject::Add(40, 2) << "\n";
  return 0;
}
