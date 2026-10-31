# Timezone fixtures

`new-york.tzif` and `utc.tzif` are public-domain TZif files generated from
[IANA tzdata 2025b](https://data.iana.org/time-zones/releases/tzdata2025b.tar.gz).
The source archive SHA-256 is
`11810413345fc7805017e27ea9fa4885fd74cd61b2911711ad038f5d28d71474`.

Generate with `zic -b fat -d zones northamerica europe etcetera` and copy
`zones/America/New_York` and `zones/Etc/UTC`. These are test data, not an
implicitly selected runtime timezone database. Tests check the exact 2025 DST
boundary and dates beyond the previous hardcoded 2024 rules. Loading owns
validation; queries borrow immutable validated bytes and require their content
identity. See [RFC 9636](https://www.rfc-editor.org/rfc/rfc9636.html) for TZif.
