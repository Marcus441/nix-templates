import { useEffect, useState, type FormEvent } from "react";
import type { components } from "@app/contracts";
import { normalizeName } from "./validate";

type Item = components["schemas"]["Item"];

export default function App() {
  const [items, setItems] = useState<Item[]>([]);
  const [name, setName] = useState("");
  const [error, setError] = useState<string | null>(null);

  async function refresh() {
    const response = await fetch("/items");
    if (!response.ok) {
      setError(`GET /items failed: ${response.status}`);
      return;
    }
    setItems((await response.json()) as Item[]);
    setError(null);
  }

  useEffect(() => {
    void refresh();
  }, []);

  async function submit(event: FormEvent) {
    event.preventDefault();
    const normalized = normalizeName(name);
    if (normalized === null) {
      return;
    }
    const response = await fetch("/items", {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ name: normalized }),
    });
    if (!response.ok) {
      setError(`POST /items failed: ${response.status}`);
      return;
    }
    setName("");
    await refresh();
  }

  return (
    <main>
      <h1>items</h1>
      <form onSubmit={submit}>
        <input
          value={name}
          onChange={(event) => setName(event.target.value)}
          placeholder="name"
        />
        <button type="submit">add</button>
      </form>
      {error !== null && <p role="alert">{error}</p>}
      <ul>
        {items.map((item) => (
          <li key={item.id}>{item.name}</li>
        ))}
      </ul>
    </main>
  );
}
