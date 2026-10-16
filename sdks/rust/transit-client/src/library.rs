use crate::{Error, ErrorKind, Result};
use std::{
    fs::{self, OpenOptions},
    io::Write,
    os::unix::fs::{DirBuilderExt, MetadataExt, OpenOptionsExt},
    path::{Path, PathBuf},
    sync::{
        Arc, Mutex,
        atomic::{AtomicU64, Ordering},
    },
};

static NEXT: AtomicU64 = AtomicU64::new(0);
// This bounds resident code images, not handles or durable Transit collections.
const MAX_LIBRARIES: usize = 16;
static LIBRARIES: Mutex<Vec<Loaded>> = Mutex::new(Vec::new());

enum Source {
    Embedded {
        filename: String,
        bytes: &'static [u8],
    },
    Override(PathBuf),
}
impl PartialEq for Source {
    fn eq(&self, other: &Self) -> bool {
        match (self, other) {
            (
                Self::Embedded {
                    filename: a,
                    bytes: x,
                },
                Self::Embedded {
                    filename: b,
                    bytes: y,
                },
            ) => a == b && (std::ptr::eq(*x, *y) || x == y),
            (Self::Override(a), Self::Override(b)) => a == b,
            _ => false,
        }
    }
}
#[derive(PartialEq)]
struct FileIdentity {
    device: u64,
    inode: u64,
    bytes: u64,
    modified: (i64, i64),
    changed: (i64, i64),
}
impl FileIdentity {
    fn read(path: &Path) -> Result<Self> {
        let meta = fs::metadata(path).map_err(|_| invalid("native-file"))?;
        if !meta.is_file() {
            return Err(invalid("native-file"));
        }
        Ok(Self {
            device: meta.dev(),
            inode: meta.ino(),
            bytes: meta.len(),
            modified: (meta.mtime(), meta.mtime_nsec()),
            changed: (meta.ctime(), meta.ctime_nsec()),
        })
    }
}
struct Loaded {
    source: Source,
    identity: Option<FileIdentity>,
    library: Arc<libloading::Library>,
}
fn invalid(phase: &'static str) -> Error {
    Error::new(ErrorKind::IncompatibleNative, phase)
}

/// Native code stays mapped until process exit. Closing a client still releases
/// its handles and joins owned work. The pinned Zig I/O pool signals completion
/// before its detached threads return through their library's exit code, so
/// handle destruction does not make dlclose safe.
pub struct Artifact {
    library: Arc<libloading::Library>,
}
impl Artifact {
    pub fn open(bytes: &'static [u8], filename: &str, directory: Option<&Path>) -> Result<Self> {
        if filename.is_empty()
            || Path::new(filename)
                .file_name()
                .and_then(|name| name.to_str())
                != Some(filename)
        {
            return Err(Error::new(ErrorKind::InvalidArgument, "artifact-name"));
        }
        let source = match directory {
            Some(directory) => Source::Override(
                std::path::absolute(directory.join(filename))
                    .map_err(|_| invalid("native-file"))?,
            ),
            None => Source::Embedded {
                filename: filename.into(),
                bytes,
            },
        };
        let identity = match &source {
            Source::Override(path) => Some(FileIdentity::read(path)?),
            Source::Embedded { .. } => None,
        };
        let mut loaded = LIBRARIES.lock().map_err(|_| invalid("native-loader"))?;
        if let Some(existing) = loaded.iter().find(|entry| entry.source == source) {
            if existing.identity != identity {
                return Err(invalid("native-file-changed"));
            }
            return Ok(Self {
                library: existing.library.clone(),
            });
        }
        if loaded.len() == MAX_LIBRARIES {
            return Err(invalid("native-library-capacity"));
        }
        let library = match &source {
            Source::Override(path) => {
                // Explicit trusted native code; never a fallback to embedded bytes.
                let library = unsafe { libloading::Library::new(path) }
                    .map_err(|_| invalid("load-artifact"))?;
                if Some(FileIdentity::read(path)?) != identity {
                    return Err(invalid("native-file-changed"));
                }
                library
            }
            Source::Embedded { .. } => {
                let temporary = Temporary::extract(bytes, filename)?;
                // The mapping is retained below; its private file can be removed
                // immediately. Repeated opens reuse the same image without I/O.
                unsafe { libloading::Library::new(&temporary.path) }
                    .map_err(|_| invalid("load-artifact"))?
            }
        };
        let library = Arc::new(library);
        loaded.push(Loaded {
            source,
            identity,
            library: library.clone(),
        });
        Ok(Self { library })
    }
    pub fn load(&self) -> Result<Arc<libloading::Library>> {
        Ok(self.library.clone())
    }
}

struct Temporary {
    directory: PathBuf,
    path: PathBuf,
}
impl Temporary {
    fn extract(bytes: &[u8], filename: &str) -> Result<Self> {
        for _ in 0..64 {
            let id = NEXT.fetch_add(1, Ordering::Relaxed);
            let directory =
                std::env::temp_dir().join(format!("transit-rust-{}-{id}", std::process::id()));
            match fs::DirBuilder::new().mode(0o700).create(&directory) {
                Ok(()) => {}
                Err(error) if error.kind() == std::io::ErrorKind::AlreadyExists => continue,
                Err(_) => return Err(invalid("extract-artifact")),
            }
            let temporary = Self {
                path: directory.join(filename),
                directory,
            };
            let mut file = OpenOptions::new()
                .write(true)
                .create_new(true)
                .mode(0o600)
                .open(&temporary.path)
                .map_err(|_| invalid("extract-artifact"))?;
            file.write_all(bytes)
                .map_err(|_| invalid("extract-artifact"))?;
            return Ok(temporary);
        }
        Err(invalid("extract-artifact"))
    }
}
impl Drop for Temporary {
    fn drop(&mut self) {
        let _ = fs::remove_dir_all(&self.directory);
    }
}
