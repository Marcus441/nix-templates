// The global module fragment. Headers that have not adopted modules go here,
// and nothing in it is visible to code that imports this module.
module;

#include <string>
#include <string_view>

export module myproject.greeting;

export namespace myproject {

// Returns a greeting for `name`, e.g. "Hello, World!".
std::string Greeting(std::string_view name);

int Add(int a, int b);

}  // namespace myproject
