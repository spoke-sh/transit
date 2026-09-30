use std::{collections::BTreeSet, fs, path::Path};

// The installed Linux consumer observes actual loader mappings. Retaining a
// Rust wrapper alone does not establish that detached native exits remain safe.
pub fn mappings() -> BTreeSet<String> {
    let prefix = format!("/transit-rust-{}-", std::process::id());
    fs::read_to_string("/proc/self/maps")
        .unwrap()
        .lines()
        .filter_map(|line| line.split_whitespace().nth(5))
        .filter(|path| path.contains(&prefix) && path.ends_with(".so"))
        .map(str::to_owned)
        .collect()
}

pub fn retained(expected: &BTreeSet<String>) {
    assert!(!expected.is_empty());
    assert_eq!(&mappings(), expected, "native code was unloaded or duplicated");
    for path in expected {
        assert!(!Path::new(path).exists(), "private extraction was not removed");
    }
}
