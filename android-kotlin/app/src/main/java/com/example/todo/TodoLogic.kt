package com.example.todo

data class TodoItem(val id: Int, val text: String, val done: Boolean = false)

fun addItem(items: List<TodoItem>, id: Int, text: String): List<TodoItem> =
    if (text.isBlank()) items else items + TodoItem(id, text.trim())

fun toggleItem(items: List<TodoItem>, id: Int, done: Boolean): List<TodoItem> =
    items.map { if (it.id == id) it.copy(done = done) else it }

fun removeItem(items: List<TodoItem>, id: Int): List<TodoItem> =
    items.filterNot { it.id == id }
