#ifndef MYPROJECT_GREETING_HPP_
#define MYPROJECT_GREETING_HPP_

#include <string>
#include <string_view>

namespace myproject {

// Returns a greeting for `name`, e.g. "Hello, World!".
std::string Greeting(std::string_view name);

int Add(int a, int b);

}  // namespace myproject

#endif  // MYPROJECT_GREETING_HPP_
