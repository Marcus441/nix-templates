// A Release build defines NDEBUG, which compiles assert() away to nothing --
// the suite would pass without executing a single check. Undefining it before
// <cassert> is included keeps the assertions live in every configuration.
#undef NDEBUG
#include <cassert>

#include <cstdio>

#include "greeting.hpp"

int main() {
  assert(Greeting("World") == "Hello, World!");
  assert(Greeting("") == "Hello, !");

  assert(Add(1, 2) == 3);
  assert(Add(40, 2) == 42);
  assert(Add(-1, -1) == -2);
  assert(Add(0, 0) == 0);

  std::puts("all tests passed");
  return 0;
}
