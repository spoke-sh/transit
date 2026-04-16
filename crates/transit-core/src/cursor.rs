#![allow(dead_code)] // Wired to the engine lifecycle API in a sibling story.

use crate::engine::{read_json, write_json_durable};
use crate::kernel::{Cursor, CursorId};
use anyhow::{Context, Result};
use std::collections::BTreeMap;
use std::fs;
use std::path::{Path, PathBuf};

pub(crate) const CURSORS_DIR: &str = "cursors";

/// Owns the on-disk cursor directory for one local engine root.
///
/// Each cursor is persisted as `<data_dir>/cursors/<cursor_id>.json`. The
/// store knows nothing about stream state or commit frontiers; the engine
/// layers those invariants on top when it calls into this collaborator.
#[derive(Debug)]
pub(crate) struct CursorStore {
    dir: PathBuf,
}

impl CursorStore {
    pub(crate) fn open(data_dir: &Path) -> Result<Self> {
        let dir = data_dir.join(CURSORS_DIR);
        fs::create_dir_all(&dir)
            .with_context(|| format!("create cursors directory at {}", dir.display()))?;
        Ok(Self { dir })
    }

    /// Return the full path this store would use for a given cursor id.
    fn path_for(&self, id: &CursorId) -> PathBuf {
        self.dir.join(format!("{}.json", file_slug(id.as_str())))
    }

    pub(crate) fn exists(&self, id: &CursorId) -> bool {
        self.path_for(id).exists()
    }

    pub(crate) fn get(&self, id: &CursorId) -> Result<Option<Cursor>> {
        let path = self.path_for(id);
        if !path.exists() {
            return Ok(None);
        }
        let cursor: Cursor = read_json(&path)?;
        Ok(Some(cursor))
    }

    pub(crate) fn put(&self, cursor: &Cursor) -> Result<()> {
        let path = self.path_for(&cursor.cursor_id);
        write_json_durable(&path, cursor)
    }

    pub(crate) fn delete(&self, id: &CursorId) -> Result<()> {
        let path = self.path_for(id);
        if path.exists() {
            fs::remove_file(&path)
                .with_context(|| format!("remove cursor file {}", path.display()))?;
        }
        Ok(())
    }

    /// Load every persisted cursor, sorted by id for deterministic iteration.
    pub(crate) fn load_all(&self) -> Result<Vec<Cursor>> {
        let mut cursors: BTreeMap<String, Cursor> = BTreeMap::new();
        if !self.dir.exists() {
            return Ok(Vec::new());
        }
        for entry in fs::read_dir(&self.dir)
            .with_context(|| format!("read cursors directory {}", self.dir.display()))?
        {
            let entry = entry.with_context(|| format!("read entry in {}", self.dir.display()))?;
            let path = entry.path();
            if path.extension().and_then(|ext| ext.to_str()) != Some("json") {
                continue;
            }
            let cursor: Cursor = read_json(&path)?;
            cursors.insert(cursor.cursor_id.as_str().to_owned(), cursor);
        }
        Ok(cursors.into_values().collect())
    }
}

/// Map a cursor id to a filesystem-safe slug.
///
/// CursorId already constrains the charset to ascii alphanumerics plus
/// `-`, `_`, `.`, `/`, and `:`. `/` and `:` are the only characters that
/// cannot be used as-is in file names on common filesystems, so we replace
/// them with `__` which cannot itself appear in a valid cursor id.
fn file_slug(id: &str) -> String {
    id.replace(['/', ':'], "__")
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::kernel::{LineageMetadata, Offset, StreamId};
    use tempfile::tempdir;

    fn make_cursor(id: &str, stream: &str, offset: u64) -> Cursor {
        Cursor::new(
            CursorId::new(id).expect("cursor id"),
            StreamId::new(stream).expect("stream id"),
            Offset::new(offset),
            LineageMetadata::default(),
            1_700_000_000,
        )
    }

    #[test]
    fn cursor_store_persists_and_reloads_records_after_restart() {
        let dir = tempdir().expect("tempdir");
        let cursor = make_cursor("consumer.analytics", "task.root", 42);

        {
            let store = CursorStore::open(dir.path()).expect("open store");
            store.put(&cursor).expect("put cursor");
            assert!(store.exists(&cursor.cursor_id));
        }

        // Simulate process restart by opening a brand new store at the same root.
        let restored = CursorStore::open(dir.path()).expect("reopen store");
        let loaded = restored
            .get(&cursor.cursor_id)
            .expect("get cursor")
            .expect("cursor present");
        assert_eq!(loaded, cursor);
    }

    #[test]
    fn cursor_store_load_all_returns_every_persisted_record_sorted_by_id() {
        let dir = tempdir().expect("tempdir");
        let store = CursorStore::open(dir.path()).expect("open store");

        store
            .put(&make_cursor("consumer.b", "task.root", 2))
            .expect("put b");
        store
            .put(&make_cursor("consumer.a", "task.root", 1))
            .expect("put a");
        store
            .put(&make_cursor("consumer.c", "task.root", 3))
            .expect("put c");

        let all = store.load_all().expect("load all");
        let ids: Vec<_> = all.iter().map(|c| c.cursor_id.as_str()).collect();
        assert_eq!(ids, vec!["consumer.a", "consumer.b", "consumer.c"]);
    }

    #[test]
    fn cursor_store_delete_removes_file() {
        let dir = tempdir().expect("tempdir");
        let store = CursorStore::open(dir.path()).expect("open store");
        let cursor = make_cursor("consumer.analytics", "task.root", 5);

        store.put(&cursor).expect("put cursor");
        assert!(store.exists(&cursor.cursor_id));

        store.delete(&cursor.cursor_id).expect("delete cursor");
        assert!(!store.exists(&cursor.cursor_id));
        assert!(store.get(&cursor.cursor_id).expect("get").is_none());
    }

    #[test]
    fn cursor_store_tolerates_ids_with_path_chars() {
        let dir = tempdir().expect("tempdir");
        let store = CursorStore::open(dir.path()).expect("open store");
        let cursor = make_cursor("tenant-a/consumer:analytics", "demo/main", 7);

        store.put(&cursor).expect("put cursor with path chars");
        let loaded = store
            .get(&cursor.cursor_id)
            .expect("get cursor")
            .expect("cursor present");
        assert_eq!(loaded, cursor);
    }
}
