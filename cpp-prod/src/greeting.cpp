#include "myproject/greeting.hpp"

#include <string>
#include <string_view>

namespace myproject {

std::string Greeting(std::string_view name) {
  return "Hello, " + std::string(name) + "!";
}

int Add(int a, int b) {
  return a + b;
}

}  // namespace myproject
