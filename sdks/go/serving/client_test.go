package serving

import (
	"fmt"
	"strings"
	"testing"
)

func TestRecoveryMaterialIsRedacted(t *testing.T) {
	p := &Pending{saved: []byte("private-frozen-command")}
	for _, format := range []string{"%v", "%+v", "%#v", "%s", "%q"} {
		for _, value := range []any{p, *p} {
			if output := fmt.Sprintf(format, value); !strings.Contains(output, "private recovery material") || strings.Contains(output, "private-frozen-command") {
				t.Fatal("recovery material was not redacted")
			}
		}
	}
	exported := p.Export()
	exported[0] = 'x'
	if string(p.Export()) != "private-frozen-command" {
		t.Fatal("export aliases owned bytes")
	}
}

func TestOpenRejectsUnboundedConfiguration(t *testing.T) {
	base := Config{Executable: "/native/caller", Origin: "https://service.test", Realm: 1, Principal: 2, CredentialEpoch: 1, Ingress: 3, Service: 1, SeedFile: "/private/seed", TimeoutMS: 1000}
	if _, err := Open(base); err != nil {
		t.Fatal(err)
	}
	for _, mutate := range []func(*Config){
		func(c *Config) { c.Executable = "ambient-program" },
		func(c *Config) { c.SeedFile = "relative-seed" },
		func(c *Config) { c.TimeoutMS = 0 },
		func(c *Config) { c.TimeoutMS = 60001 },
		func(c *Config) { c.Principal = MaxCounter + 1 },
	} {
		c := base
		mutate(&c)
		if _, err := Open(c); err == nil {
			t.Fatal("invalid configuration admitted")
		}
	}
	var out boundedOutput
	if _, err := out.Write(make([]byte, MaxResponseBytes+1)); err == nil || !out.overflow || out.Len() != 0 {
		t.Fatal("output bound not enforced")
	}
}
