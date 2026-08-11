#include <iostream>

#include "greeting.hpp"

int main() {
  std::cout << Greeting("World") << "\n";
  std::cout << "40 + 2 = " << Add(40, 2) << "\n";
  return 0;
}
