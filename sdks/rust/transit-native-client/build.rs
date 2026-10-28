fn main() {
    let path = std::env::var_os("TRANSIT_LIBRARY_DIR")
        .map(std::path::PathBuf::from)
        .unwrap_or_else(|| {
            std::path::PathBuf::from(std::env::var_os("CARGO_MANIFEST_DIR").unwrap()).join("lib")
        })
        .join("libtransit_client.so");
    if !path.is_file() {
        panic!(
            "Missing transit-native-client 0.0.1 artifact; build with just bindings::rust-build or supply TRANSIT_LIBRARY_DIR for source development"
        );
    }
    println!("cargo:rerun-if-env-changed=TRANSIT_LIBRARY_DIR");
    println!("cargo:rerun-if-changed={}", path.display());
    println!("cargo:rustc-env=TRANSIT_EMBEDDED_CLIENT={}", path.display());
}
