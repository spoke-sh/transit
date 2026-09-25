fn main() {
    let directory = std::env::var("TRANSIT_LIBRARY_DIR")
        .expect("Set TRANSIT_LIBRARY_DIR to the native libraries");
    println!("cargo:rerun-if-env-changed=TRANSIT_LIBRARY_DIR");
    println!("cargo:rustc-link-search=native={directory}");
    println!("cargo:rustc-link-lib=dylib=transit_station");
    println!("cargo:rustc-link-lib=dylib=transit_client");
    println!("cargo:rustc-link-arg=-Wl,-rpath,{directory}");
}
