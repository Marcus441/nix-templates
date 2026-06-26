#include <gmock/gmock.h>
#include <gtest/gtest.h>

TEST(BasicTest, AssertionTrue) {
  EXPECT_TRUE(true);
}

TEST(BasicTest, Addition) {
  EXPECT_EQ(1 + 1, 2);
}
