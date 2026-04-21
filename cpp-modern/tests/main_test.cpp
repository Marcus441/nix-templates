#include <gmock/gmock.h>
#include <gtest/gtest.h>

import my_module;

TEST(GreetTest, DoesNotCrash) {
  // greet() writes to stdout — just verify it doesn't throw or crash
  EXPECT_NO_THROW(Greet("World"));
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

TEST(PrintResultTest, DoesNotCrash) {
  EXPECT_NO_THROW(PrintResult("test", 42));
}
