use crate::{ClientConfig, Credential, Error, ErrorKind, Result, abi, library::Artifact};
use serde_json::{Value, json};
use std::{fs::File, io::Read, ptr, slice};

pub struct Seed([u8; 32]);
struct SeedText(Vec<u8>);
impl Drop for SeedText {
    fn drop(&mut self) {
        for byte in &mut self.0 {
            unsafe {
                ptr::write_volatile(byte, 0);
            }
        }
        std::sync::atomic::compiler_fence(std::sync::atomic::Ordering::SeqCst);
    }
}
impl Seed {
    pub fn read(path: &std::path::Path) -> Result<Self> {
        let mut text = SeedText(Vec::with_capacity(129));
        File::open(path)
            .and_then(|file| file.take(129).read_to_end(&mut text.0))
            .map_err(|_| Error::new(ErrorKind::InvalidArgument, "read-credential"))?;
        let parsed = std::str::from_utf8(&text.0)
            .ok()
            .map(str::trim)
            .filter(|value| value.len() == 64)
            .and_then(|value| unhex(value, 32).ok());
        let mut seed = Self([0; 32]);
        let result = match parsed {
            Some(mut bytes) => {
                seed.0.copy_from_slice(&bytes);
                for byte in &mut bytes {
                    unsafe {
                        ptr::write_volatile(byte, 0);
                    }
                }
                Ok(seed)
            }
            None => Err(Error::new(ErrorKind::InvalidArgument, "read-credential")),
        };
        result
    }
    pub fn pointer(&self) -> *const u8 {
        self.0.as_ptr()
    }
}
impl Drop for Seed {
    fn drop(&mut self) {
        for byte in &mut self.0 {
            unsafe {
                ptr::write_volatile(byte, 0);
            }
        }
        std::sync::atomic::compiler_fence(std::sync::atomic::Ordering::SeqCst);
    }
}

pub fn hex(bytes: &[u8], bound: usize) -> Result<String> {
    if bytes.len() > bound {
        return Err(Error::new(ErrorKind::InvalidArgument, "byte-bound"));
    }
    const DIGITS: &[u8] = b"0123456789abcdef";
    let mut value = String::with_capacity(bytes.len() * 2);
    for byte in bytes {
        value.push(DIGITS[(byte >> 4) as usize] as char);
        value.push(DIGITS[(byte & 15) as usize] as char);
    }
    Ok(value)
}
pub fn unhex(text: &str, bound: usize) -> Result<Vec<u8>> {
    if text.len() > bound * 2 || !text.len().is_multiple_of(2) {
        return Err(Error::new(ErrorKind::InvalidArgument, "byte-bound"));
    }
    text.as_bytes()
        .chunks_exact(2)
        .map(|pair| {
            fn nibble(value: u8) -> Option<u8> {
                match value {
                    b'0'..=b'9' => Some(value - b'0'),
                    b'a'..=b'f' => Some(value - b'a' + 10),
                    b'A'..=b'F' => Some(value - b'A' + 10),
                    _ => None,
                }
            }
            nibble(pair[0])
                .zip(nibble(pair[1]))
                .map(|(a, b)| a * 16 + b)
                .ok_or_else(|| Error::new(ErrorKind::InvalidArgument, "hex"))
        })
        .collect()
}
pub fn number(value: &Value, phase: &'static str, zero: bool) -> Result<u64> {
    value
        .as_u64()
        .filter(|v| *v <= abi::MAX_COUNTER as u64 && (zero || *v != 0))
        .ok_or_else(|| Error::new(ErrorKind::IncompatibleNative, phase))
}
pub fn string<'a>(value: &'a Value, phase: &'static str) -> Result<&'a str> {
    value
        .as_str()
        .filter(|value| value.len() <= abi::MAX_BODY)
        .ok_or_else(|| Error::new(ErrorKind::IncompatibleNative, phase))
}
pub fn boolean(value: &Value, phase: &'static str) -> Result<bool> {
    value
        .as_bool()
        .ok_or_else(|| Error::new(ErrorKind::IncompatibleNative, phase))
}

struct Operation<'a> {
    pointer: *mut abi::transit_operation,
    api: &'a abi::Api,
}
impl Drop for Operation<'_> {
    fn drop(&mut self) {
        unsafe {
            (self.api.transit_operation_destroy)(self.pointer);
        }
    }
}
struct Buffer<'a> {
    pointer: *mut abi::transit_buffer,
    api: &'a abi::Api,
}
impl Drop for Buffer<'_> {
    fn drop(&mut self) {
        unsafe {
            (self.api.transit_buffer_destroy)(self.pointer);
        }
    }
}
impl Buffer<'_> {
    fn take(&self) -> Result<Vec<u8>> {
        if self.pointer.is_null() {
            return Ok(Vec::new());
        }
        let size = unsafe { (self.api.transit_buffer_size)(self.pointer) };
        if size > abi::MAX_BODY {
            return Err(Error::new(
                ErrorKind::IncompatibleNative,
                "native-buffer-bound",
            ));
        }
        if size == 0 {
            return Ok(Vec::new());
        }
        let pointer = unsafe { (self.api.transit_buffer_data)(self.pointer) };
        if pointer.is_null() {
            return Err(Error::new(ErrorKind::IncompatibleNative, "native-buffer"));
        }
        Ok(unsafe { slice::from_raw_parts(pointer, size) }.to_vec())
    }
}
pub struct Native {
    pointer: *mut abi::transit_client,
    api: abi::Api,
    _artifact: Artifact,
}
impl Native {
    pub fn open(config: &ClientConfig) -> Result<Self> {
        if !crate::worker::on_worker() {
            return Err(Error::new(
                ErrorKind::InvalidArgument,
                "native-worker-required",
            ));
        }
        if transit_native_client::VERSION != "0.2.0" {
            return Err(Error::new(ErrorKind::IncompatibleNative, "native-version"));
        }
        let artifact = Artifact::open(
            transit_native_client::LIBRARY,
            "libtransit_client.so",
            config.native_directory.as_deref(),
        )?;
        let api = unsafe { abi::Api::load(artifact.load()?) }
            .map_err(|_| Error::new(ErrorKind::IncompatibleNative, "native-symbols"))?;
        if unsafe {
            (api.transit_client_abi_definition_matches)(
                abi::ABI_DEFINITION.as_ptr(),
                abi::ABI_DEFINITION.len(),
            )
        } != 1
            || unsafe { (api.transit_client_abi_version)() } != abi::ABI_VERSION
            || unsafe { (api.transit_client_supports_kind)(6) } != 1
            || unsafe { (api.transit_client_supports_kind)(7) } != 1
        {
            return Err(Error::new(
                ErrorKind::UnsupportedCapability,
                "native-capabilities",
            ));
        }
        let mut pointer = ptr::null_mut();
        let status = unsafe {
            (api.transit_client_create)(
                abi::ABI_VERSION,
                config.url.as_ptr(),
                config.url.len(),
                config.timeout_ms,
                &mut pointer,
            )
        };
        if status != 0 {
            return Err(Error::native(status, None, "open-client"));
        }
        if pointer.is_null() {
            return Err(Error::new(ErrorKind::IncompatibleNative, "open-client"));
        }
        Ok(Self {
            pointer,
            api,
            _artifact: artifact,
        })
    }
    fn import(&self, bytes: &[u8]) -> Result<Operation<'_>> {
        if bytes.len() > abi::MAX_BODY {
            return Err(Error::new(ErrorKind::InvalidArgument, "import-bound"));
        }
        let mut operation = Operation {
            api: &self.api,
            pointer: ptr::null_mut(),
        };
        let status = unsafe {
            (self.api.transit_operation_import)(bytes.as_ptr(), bytes.len(), &mut operation.pointer)
        };
        if status != 0 {
            return Err(Error::native(status, None, "import-operation"));
        }
        if operation.pointer.is_null() {
            return Err(Error::new(
                ErrorKind::IncompatibleNative,
                "import-operation",
            ));
        }
        Ok(operation)
    }
    pub fn prepare(&self, kind: u32, credential: &Credential, value: &Value) -> Result<Vec<u8>> {
        let seed = Seed::read(credential.seed_file())?;
        let bytes = serde_json::to_vec(value)
            .map_err(|_| Error::new(ErrorKind::InvalidArgument, "prepare-json"))?;
        if bytes.len() > abi::MAX_BODY {
            return Err(Error::new(ErrorKind::InvalidArgument, "prepare-bound"));
        }
        let mut operation = Operation {
            api: &self.api,
            pointer: ptr::null_mut(),
        };
        let status = unsafe {
            (self.api.transit_operation_prepare)(
                kind,
                seed.pointer(),
                bytes.as_ptr(),
                bytes.len(),
                &mut operation.pointer,
            )
        };
        if status != 0 {
            return Err(Error::native(status, None, "prepare-operation"));
        }
        let mut buffer = Buffer {
            api: &self.api,
            pointer: ptr::null_mut(),
        };
        let status =
            unsafe { (self.api.transit_operation_export)(operation.pointer, &mut buffer.pointer) };
        if status != 0 {
            return Err(Error::native(status, None, "export-operation"));
        }
        buffer.take()
    }
    pub fn metadata(&self, bytes: &[u8]) -> Result<Value> {
        let operation = self.import(bytes)?;
        let mut buffer = Buffer {
            api: &self.api,
            pointer: ptr::null_mut(),
        };
        let status = unsafe {
            (self.api.transit_operation_metadata)(operation.pointer, &mut buffer.pointer)
        };
        if status != 0 {
            return Err(Error::native(status, None, "metadata"));
        }
        serde_json::from_slice(&buffer.take()?)
            .map_err(|_| Error::new(ErrorKind::IncompatibleNative, "metadata"))
    }
    pub fn call(&self, bytes: &[u8], mutation: bool) -> Result<Value> {
        let operation = self.import(bytes)?;
        let mut buffer = Buffer {
            api: &self.api,
            pointer: ptr::null_mut(),
        };
        let status = unsafe {
            (self.api.transit_client_call)(self.pointer, operation.pointer, &mut buffer.pointer)
        };
        let invalid = || {
            Error::new(
                if mutation {
                    ErrorKind::UnknownOutcome
                } else {
                    ErrorKind::ReadFailed
                },
                "response",
            )
        };
        let bytes = buffer.take().map_err(|_| invalid())?;
        let value: Value = if bytes.is_empty() {
            Value::Null
        } else {
            serde_json::from_slice(&bytes).map_err(|_| {
                if status == 0 {
                    return invalid();
                }
                let mut error = Error::native(status, None, "dispatch");
                error.diagnostic_invalid = true;
                error
            })?
        };
        if status != 0 {
            return Err(
                Error::native(status, Some(&value), "dispatch").with_diagnostic(
                    &value,
                    |bytes| unsafe {
                        (self.api.transit_diagnostic_validate)(bytes.as_ptr(), bytes.len()) == 1
                    },
                ),
            );
        }
        Ok(value)
    }
    pub fn capabilities(&self, credential: &Credential) -> Result<crate::Capabilities> {
        let bytes = self.prepare(7, credential, &json!({"realm":credential.realm(), "principal":credential.principal(), "kind":{"capabilities":{}}}))?;
        let value = self.call(&bytes, false)?;
        let caps = &value["body"]["capabilities"];
        if value["version"] != 1 || caps["version"] != 1 || caps["profile"] != "growing_v1" {
            return Err(Error::new(
                ErrorKind::UnsupportedCapability,
                "authority-capabilities",
            ));
        }
        let counter = |value: &Value, zero: bool| {
            crate::Counter::new(number(value, "authority-capabilities", zero)?)
        };
        Ok(crate::Capabilities {
            realm: counter(&value["realm"], false)?,
            observed_at: counter(&value["position"], true)?,
            principal_sequence: counter(&value["principal_sequence"], true)?,
            page_size: counter(&caps["page_entries"], false)?,
            mutations_per_turn: counter(&caps["mutation_budget"], false)?,
            outputs_per_turn: counter(&caps["output_budget"], false)?,
            retained_versions: boolean(&caps["retained_read_versions"], "authority-capabilities")?,
            association_lookup: boolean(&caps["association_lookup"], "authority-capabilities")?,
            scoped_retry: boolean(&caps["scoped_retry"], "authority-capabilities")?,
            station: boolean(&caps["station"], "authority-capabilities")?,
        })
    }
}
impl Drop for Native {
    fn drop(&mut self) {
        unsafe {
            (self.api.transit_client_destroy)(self.pointer);
        }
    }
}
