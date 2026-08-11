// A module implementation unit. It is an ordinary source file in the library
// target, not part of the CXX_MODULES file set -- which is why the library can
// hold both and never needs a guard around the module half.
module;

#include <string>
#include <string_view>

module myproject.greeting;

namespace myproject {

std::string Greeting(std::string_view name) {
  return "Hello, " + std::string(name) + "!";
}

int Add(int a, int b) {
  return a + b;
}

}  // namespace myproject
