use serde::Serialize;
use std::path::Path;

const REQUIRED_DOCS: &[&str] = &[
    "README.md",
    "ARCHITECTURE.md",
    "CONSTITUTION.md",
    "CONFIGURATION.md",
    "GUIDE.md",
    "EVALUATIONS.md",
    "RELEASE.md",
    "AGENTS.md",
];

const REQUIRED_WORKSPACE_FILES: &[&str] = &[
    "Cargo.toml",
    "Justfile",
    "flake.nix",
    "rust-toolchain.toml",
    "crates/transit-core/Cargo.toml",
    "crates/transit-cli/Cargo.toml",
];

const REQUIRED_KERNEL_FILES: &[&str] = &[
    "crates/transit-core/src/kernel.rs",
    "crates/transit-core/src/storage.rs",
    "crates/transit-core/src/engine.rs",
];

#[derive(Debug, Clone, Serialize, PartialEq, Eq)]
pub struct ArtifactStatus {
    pub path: String,
    pub present: bool,
}

#[derive(Debug, Clone, Serialize, PartialEq, Eq)]
pub struct MissionStatus {
    pub project: &'static str,
    pub version: &'static str,
    pub verification_recipe: &'static str,
    pub object_store_backend: &'static str,
    pub docs: Vec<ArtifactStatus>,
    pub workspace_files: Vec<ArtifactStatus>,
    pub kernel_files: Vec<ArtifactStatus>,
    pub ready: bool,
}

impl MissionStatus {
    pub fn docs_present(&self) -> usize {
        self.docs.iter().filter(|artifact| artifact.present).count()
    }

    pub fn workspace_files_present(&self) -> usize {
        self.workspace_files
            .iter()
            .filter(|artifact| artifact.present)
            .count()
    }

    pub fn kernel_files_present(&self) -> usize {
        self.kernel_files
            .iter()
            .filter(|artifact| artifact.present)
            .count()
    }

    pub fn summary(&self) -> &'static str {
        if self.ready {
            "durable local engine verified"
        } else {
            "durable local engine incomplete"
        }
    }

    pub fn missing_paths(&self) -> Vec<&str> {
        self.docs
            .iter()
            .chain(self.workspace_files.iter())
            .chain(self.kernel_files.iter())
            .filter(|artifact| !artifact.present)
            .map(|artifact| artifact.path.as_str())
            .collect()
    }
}

pub fn collect_mission_status(repo_root: impl AsRef<Path>) -> MissionStatus {
    let repo_root = repo_root.as_ref();
    let docs = collect_artifacts(repo_root, REQUIRED_DOCS);
    let workspace_files = collect_artifacts(repo_root, REQUIRED_WORKSPACE_FILES);
    let kernel_files = collect_artifacts(repo_root, REQUIRED_KERNEL_FILES);
    let ready = docs.iter().all(|artifact| artifact.present)
        && workspace_files.iter().all(|artifact| artifact.present)
        && kernel_files.iter().all(|artifact| artifact.present);

    MissionStatus {
        project: "transit",
        version: env!("CARGO_PKG_VERSION"),
        verification_recipe: "just screen",
        object_store_backend: "object_store + filesystem backend",
        docs,
        workspace_files,
        kernel_files,
        ready,
    }
}

fn collect_artifacts(repo_root: &Path, relative_paths: &[&str]) -> Vec<ArtifactStatus> {
    relative_paths
        .iter()
        .map(|relative_path| ArtifactStatus {
            path: (*relative_path).to_owned(),
            present: repo_root.join(relative_path).exists(),
        })
        .collect()
}

#[cfg(test)]
mod tests {
    use super::collect_mission_status;
    use std::fs;
    use tempfile::tempdir;

    #[test]
    fn mission_status_marks_ready_when_required_files_exist() {
        let repo_root = tempdir().expect("temporary repo root");

        for file in [
            "README.md",
            "ARCHITECTURE.md",
            "CONSTITUTION.md",
            "CONFIGURATION.md",
            "GUIDE.md",
            "EVALUATIONS.md",
            "RELEASE.md",
            "AGENTS.md",
            "Cargo.toml",
            "Justfile",
            "flake.nix",
            "rust-toolchain.toml",
            "crates/transit-core/Cargo.toml",
            "crates/transit-cli/Cargo.toml",
            "crates/transit-core/src/kernel.rs",
            "crates/transit-core/src/storage.rs",
            "crates/transit-core/src/engine.rs",
        ] {
            let path = repo_root.path().join(file);
            if let Some(parent) = path.parent() {
                fs::create_dir_all(parent).expect("parent directory");
            }
            fs::write(path, "").expect("bootstrap artifact");
        }

        let status = collect_mission_status(repo_root.path());
        assert!(status.ready);
        assert_eq!(status.docs_present(), 8);
        assert_eq!(status.workspace_files_present(), 6);
        assert_eq!(status.kernel_files_present(), 3);
        assert!(status.missing_paths().is_empty());
    }

    #[test]
    fn mission_status_surfaces_missing_files() {
        let repo_root = tempdir().expect("temporary repo root");

        fs::write(repo_root.path().join("README.md"), "").expect("readme");

        let status = collect_mission_status(repo_root.path());
        assert!(!status.ready);
        assert!(status.missing_paths().contains(&"ARCHITECTURE.md"));
        assert!(status.missing_paths().contains(&"Cargo.toml"));
        assert!(
            status
                .missing_paths()
                .contains(&"crates/transit-core/src/kernel.rs")
        );
    }
}
