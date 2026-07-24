package com.example.todo

import org.junit.Assert.assertEquals
import org.junit.Test

class TodoLogicTest {
    @Test
    fun `addItem appends a trimmed item`() {
        val items = addItem(emptyList(), id = 0, text = "  buy milk  ")
        assertEquals(listOf(TodoItem(0, "buy milk")), items)
    }

    @Test
    fun `addItem ignores blank input`() {
        val items = listOf(TodoItem(0, "a"))
        assertEquals(items, addItem(items, id = 1, text = "   "))
    }

    @Test
    fun `toggleItem only changes the matching item`() {
        val items = listOf(TodoItem(0, "a"), TodoItem(1, "b"))
        val toggled = toggleItem(items, id = 1, done = true)
        assertEquals(listOf(TodoItem(0, "a"), TodoItem(1, "b", done = true)), toggled)
    }

    @Test
    fun `toggleItem can un-complete an item`() {
        val items = listOf(TodoItem(0, "a", done = true))
        assertEquals(listOf(TodoItem(0, "a", done = false)), toggleItem(items, id = 0, done = false))
    }

    @Test
    fun `removeItem drops only the matching item`() {
        val items = listOf(TodoItem(0, "a"), TodoItem(1, "b"))
        assertEquals(listOf(TodoItem(1, "b")), removeItem(items, id = 0))
    }

    @Test
    fun `removeItem with unknown id is a no-op`() {
        val items = listOf(TodoItem(0, "a"))
        assertEquals(items, removeItem(items, id = 99))
    }
}
