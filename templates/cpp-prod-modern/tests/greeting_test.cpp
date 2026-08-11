#include <gmock/gmock.h>
#include <gtest/gtest.h>

import myproject.greeting;

namespace myproject {
namespace {

using ::testing::HasSubstr;
using ::testing::StartsWith;

TEST(GreetingTest, IncludesTheName) {
  EXPECT_THAT(Greeting("World"), HasSubstr("World"));
  EXPECT_THAT(Greeting("World"), StartsWith("Hello"));
}

TEST(GreetingTest, ExactFormat) {
  EXPECT_EQ(Greeting("World"), "Hello, World!");
}

TEST(GreetingTest, EmptyName) {
  EXPECT_EQ(Greeting(""), "Hello, !");
}

TEST(AddTest, PositiveNumbers) {
  EXPECT_EQ(Add(1, 2), 3);
  EXPECT_EQ(Add(40, 2), 42);
}

TEST(AddTest, NegativeNumbers) {
  EXPECT_EQ(Add(-1, -1), -2);
  EXPECT_EQ(Add(-10, 5), -5);
}

TEST(AddTest, Zero) {
  EXPECT_EQ(Add(0, 0), 0);
  EXPECT_EQ(Add(42, 0), 42);
}

}  // namespace
}  // namespace myproject
