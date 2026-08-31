export function normalizeName(raw: string): string | null {
  const name = raw.trim();
  return name.length === 0 ? null : name;
}
