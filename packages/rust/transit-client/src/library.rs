use crate::{Error, ErrorKind, Result};
use std::{
    fs::{self, OpenOptions},
    io::Write,
    os::unix::fs::{DirBuilderExt, OpenOptionsExt},
    path::{Path, PathBuf},
    sync::atomic::{AtomicU64, Ordering},
};

static NEXT: AtomicU64 = AtomicU64::new(0);
/// Owns the extracted artifact, kept alive until the generated API unloads it.
pub struct Artifact {
    directory: Option<PathBuf>,
    pub path: PathBuf,
}
impl Artifact {
    pub fn open(bytes: &[u8], filename: &str, directory: Option<&Path>) -> Result<Self> {
        if filename.is_empty()
            || Path::new(filename)
                .file_name()
                .and_then(|name| name.to_str())
                != Some(filename)
        {
            return Err(Error::new(ErrorKind::InvalidArgument, "artifact-name"));
        }
        if let Some(directory) = directory {
            return Ok(Self {
                directory: None,
                path: directory.join(filename),
            });
        }
        for _ in 0..64 {
            let id = NEXT.fetch_add(1, Ordering::Relaxed);
            let directory =
                std::env::temp_dir().join(format!("transit-rust-{}-{id}", std::process::id()));
            match fs::DirBuilder::new().mode(0o700).create(&directory) {
                Ok(()) => {}
                Err(error) if error.kind() == std::io::ErrorKind::AlreadyExists => continue,
                Err(_) => {
                    return Err(Error::new(
                        ErrorKind::IncompatibleNative,
                        "extract-artifact",
                    ));
                }
            }
            let artifact = Self {
                path: directory.join(filename),
                directory: Some(directory.clone()),
            };
            let mut file = OpenOptions::new()
                .write(true)
                .create_new(true)
                .mode(0o600)
                .open(&artifact.path)
                .map_err(|_| Error::new(ErrorKind::IncompatibleNative, "extract-artifact"))?;
            file.write_all(bytes)
                .map_err(|_| Error::new(ErrorKind::IncompatibleNative, "extract-artifact"))?;
            return Ok(artifact);
        }
        Err(Error::new(
            ErrorKind::IncompatibleNative,
            "extract-artifact",
        ))
    }
    /// Caller keeps this artifact alive until all loaded symbols and handles end.
    pub fn load(&self) -> Result<libloading::Library> {
        // Native code is an explicit trusted dependency, never application bytes.
        unsafe { libloading::Library::new(&self.path) }
            .map_err(|_| Error::new(ErrorKind::IncompatibleNative, "load-artifact"))
    }
}
impl Drop for Artifact {
    fn drop(&mut self) {
        if let Some(directory) = &self.directory {
            let _ = fs::remove_dir_all(directory);
        }
    }
}
