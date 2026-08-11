export function greet(name: string): string {
  return `Hello, ${name}!`;
}

// Simple usage example if run directly:
if (import.meta.main) {
  console.log(greet("World"));
}
