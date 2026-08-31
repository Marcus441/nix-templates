package items

import "strings"

// NormalizeName trims surrounding whitespace and rejects a blank name — the
// same rule apps/web/src/validate.ts applies before it ever sends the POST.
func NormalizeName(raw string) (string, bool) {
	name := strings.TrimSpace(raw)
	if name == "" {
		return "", false
	}
	return name, true
}
