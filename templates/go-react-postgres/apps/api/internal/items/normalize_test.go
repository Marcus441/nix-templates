package items

import "testing"

func TestNormalizeNameTrimsAndRejectsBlank(t *testing.T) {
	name, ok := NormalizeName("  smoke  ")
	if !ok || name != "smoke" {
		t.Fatalf(`NormalizeName("  smoke  ") = %q, %v; want "smoke", true`, name, ok)
	}

	if _, ok := NormalizeName("   "); ok {
		t.Fatal(`NormalizeName("   ") accepted a blank name`)
	}
}
