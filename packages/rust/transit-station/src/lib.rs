//! Owned handles over shared Zig semantics. Calls block; use a bounded worker
//! when integrating with an async executor. Dropping a future is not cancellation.
#[rustfmt::skip]
pub mod ffi;
pub use serde_json::Value;
use std::{ptr, slice};

/// Shared Debug native code needs the qualified Linux stack budget. Use this
/// bounded worker rather than an executor's smaller default blocking stack.
pub fn spawn<T: Send + 'static>(
    f: impl FnOnce() -> T + Send + 'static,
) -> std::io::Result<std::thread::JoinHandle<T>> {
    std::thread::Builder::new()
        .name("transit-native".into())
        .stack_size(ffi::MINIMUM_STACK_BYTES)
        .spawn(f)
}

#[derive(Debug)]
pub struct Error {
    pub status: u32,
    pub detail: Value,
}
impl std::fmt::Display for Error {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "Transit status {}: {}", self.status, self.detail)
    }
}
impl std::error::Error for Error {}
type Result<T> = std::result::Result<T, Error>;
fn error(status: u32) -> Error {
    Error {
        status,
        detail: Value::Null,
    }
}
struct StationBuffer(*mut ffi::station_buffer);
impl Drop for StationBuffer {
    fn drop(&mut self) {
        unsafe { ffi::station_buffer_destroy(self.0) }
    }
}
impl StationBuffer {
    fn text(&self) -> Result<String> {
        if self.0.is_null() {
            return Ok("null".into());
        }
        // Native data remains borrowed until this owned guard drops.
        let bytes = unsafe {
            slice::from_raw_parts(
                ffi::station_buffer_data(self.0),
                ffi::station_buffer_size(self.0),
            )
        };
        String::from_utf8(bytes.to_vec()).map_err(|_| error(8))
    }
}
fn station_result(status: u32, pointer: *mut ffi::station_buffer) -> Result<Value> {
    let text = StationBuffer(pointer).text()?;
    let value = serde_json::from_str(&text).map_err(|_| error(8))?;
    if status != 0 {
        return Err(Error {
            status,
            detail: value,
        });
    }
    Ok(value)
}
pub struct GenServer {
    pointer: *mut ffi::station_server,
}
// Native addresses are stable and have no caller-thread affinity. Ownership
// moves; &mut operations exclude concurrent calls/destruction. Deliberately !Sync.
unsafe impl Send for GenServer {}
impl Drop for GenServer {
    fn drop(&mut self) {
        unsafe { ffi::station_server_destroy(self.pointer) }
    }
}
impl GenServer {
    pub fn new(url: &str, seed: &[u8; 32], config: &Value) -> Result<Self> {
        let config = config.to_string();
        let mut pointer = ptr::null_mut();
        let status = unsafe {
            ffi::station_server_create(
                1,
                url.as_ptr(),
                url.len(),
                seed.as_ptr(),
                config.as_ptr(),
                config.len(),
                &mut pointer,
            )
        };
        if status != 0 {
            return Err(error(status));
        }
        Ok(Self { pointer })
    }
    pub fn next(&mut self, deadline_ms: u64) -> Result<Value> {
        let mut out = ptr::null_mut();
        let status = unsafe { ffi::station_server_next(self.pointer, deadline_ms, &mut out) };
        station_result(status, out)
    }
    pub fn apply(&mut self, action: &Value) -> Result<Value> {
        let json = action.to_string();
        let mut out = ptr::null_mut();
        let status =
            unsafe { ffi::station_server_apply(self.pointer, json.as_ptr(), json.len(), &mut out) };
        station_result(status, out)
    }
    pub fn finish(&mut self, failed: bool) -> Result<()> {
        let status = unsafe { ffi::station_server_finish(self.pointer, failed.into()) };
        if status != 0 {
            return Err(error(status));
        }
        Ok(())
    }
    pub fn pending(&mut self) -> Result<String> {
        let mut out = ptr::null_mut();
        let status = unsafe { ffi::station_server_pending(self.pointer, &mut out) };
        let buffer = StationBuffer(out);
        if status != 0 {
            return Err(error(status));
        }
        buffer.text()
    }
}
pub fn arrow_cell(ipc: &[u8], row: u32, column: u32) -> Result<Value> {
    let mut out = ptr::null_mut();
    let status = unsafe { ffi::station_arrow_cell(ipc.as_ptr(), ipc.len(), row, column, &mut out) };
    station_result(status, out)
}
struct Operation(*mut ffi::transit_operation);
impl Drop for Operation {
    fn drop(&mut self) {
        unsafe { ffi::transit_operation_destroy(self.0) }
    }
}
struct TransitBuffer(*mut ffi::transit_buffer);
impl Drop for TransitBuffer {
    fn drop(&mut self) {
        unsafe { ffi::transit_buffer_destroy(self.0) }
    }
}
impl TransitBuffer {
    fn text(&self) -> Result<String> {
        if self.0.is_null() {
            return Ok("null".into());
        }
        let bytes = unsafe {
            slice::from_raw_parts(
                ffi::transit_buffer_data(self.0),
                ffi::transit_buffer_size(self.0),
            )
        };
        String::from_utf8(bytes.to_vec()).map_err(|_| error(8))
    }
}
pub struct Client {
    pointer: *mut ffi::transit_client,
}
unsafe impl Send for Client {}
impl Drop for Client {
    fn drop(&mut self) {
        unsafe { ffi::transit_client_destroy(self.pointer) }
    }
}
impl Client {
    pub fn new(url: &str, timeout_ms: u32) -> Result<Self> {
        let mut pointer = ptr::null_mut();
        let status = unsafe {
            ffi::transit_client_create(1, url.as_ptr(), url.len(), timeout_ms, &mut pointer)
        };
        if status != 0 {
            return Err(error(status));
        }
        Ok(Self { pointer })
    }
    pub fn prepare(kind: u32, seed: &[u8; 32], document: &Value) -> Result<String> {
        let json = document.to_string();
        let mut pointer = ptr::null_mut();
        let status = unsafe {
            ffi::transit_operation_prepare(
                kind,
                seed.as_ptr(),
                json.as_ptr(),
                json.len(),
                &mut pointer,
            )
        };
        let operation = Operation(pointer);
        if status != 0 {
            return Err(error(status));
        }
        let mut buffer = ptr::null_mut();
        let status = unsafe { ffi::transit_operation_export(operation.0, &mut buffer) };
        let buffer = TransitBuffer(buffer);
        if status != 0 {
            return Err(error(status));
        }
        buffer.text()
    }
    pub fn call(&mut self, frozen: &str) -> Result<Value> {
        let mut pointer = ptr::null_mut();
        let status =
            unsafe { ffi::transit_operation_import(frozen.as_ptr(), frozen.len(), &mut pointer) };
        let operation = Operation(pointer);
        if status != 0 {
            return Err(error(status));
        }
        let mut buffer = ptr::null_mut();
        let status = unsafe { ffi::transit_client_call(self.pointer, operation.0, &mut buffer) };
        let buffer = TransitBuffer(buffer);
        let value = serde_json::from_str(&buffer.text()?).map_err(|_| error(8))?;
        if status != 0 {
            return Err(Error {
                status,
                detail: value,
            });
        }
        Ok(value)
    }
}
