package com.example.todo

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.unit.dp

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            MaterialTheme {
                Surface(modifier = Modifier.fillMaxSize()) {
                    TodoScreen()
                }
            }
        }
    }
}

@Composable
fun TodoScreen() {
    var items by remember { mutableStateOf(listOf<TodoItem>()) }
    var input by remember { mutableStateOf("") }
    var nextId by remember { mutableStateOf(0) }

    Column(modifier = Modifier.fillMaxSize().padding(16.dp)) {
        Text("Todo", style = MaterialTheme.typography.headlineMedium)
        Spacer(modifier = Modifier.height(16.dp))

        Row(verticalAlignment = Alignment.CenterVertically) {
            OutlinedTextField(
                value = input,
                onValueChange = { input = it },
                label = { Text("New task") },
                modifier = Modifier.weight(1f)
            )
            Spacer(modifier = Modifier.width(8.dp))
            Button(onClick = {
                if (input.isNotBlank()) {
                    items = addItem(items, nextId, input)
                    nextId += 1
                    input = ""
                }
            }) {
                Text("Add")
            }
        }

        Spacer(modifier = Modifier.height(16.dp))

        LazyColumn {
            items(items, key = { it.id }) { item ->
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(vertical = 6.dp)
                ) {
                    Checkbox(
                        checked = item.done,
                        onCheckedChange = { checked ->
                            items = toggleItem(items, item.id, checked)
                        }
                    )
                    Text(
                        text = item.text,
                        modifier = Modifier.weight(1f),
                        textDecoration = if (item.done) TextDecoration.LineThrough else null
                    )
                    TextButton(onClick = {
                        items = removeItem(items, item.id)
                    }) {
                        Text("Delete")
                    }
                }
            }
        }
    }
}
