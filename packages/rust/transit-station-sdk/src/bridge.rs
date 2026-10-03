use crate::{Codec, FailurePolicy, FrozenMutation, Purpose, ServiceConfig, abi, types::encode};
use serde_json::{Value, json};
use std::{
    path::Path,
    ptr, slice,
    time::{SystemTime, UNIX_EPOCH},
};
use transit_client::internal::{
    Artifact, MAX_BODY, Native, Worker, boolean, credential_seed, mutation_info, native_error,
    number, settings, string, unhex,
};
use transit_client::{Counter, Error, ErrorKind, Result};

pub(crate) fn counter(value: &Value, zero: bool) -> Result<Counter> {
    Counter::new(number(value, "native-counter", zero)?)
}
pub(crate) fn size(value: &Value, zero: bool) -> Result<usize> {
    Ok(number(value, "native-bound", zero)? as usize)
}
pub(crate) fn wide(value: &Value) -> Result<u64> {
    let text = string(value, "native-u64")?;
    text.parse::<u64>()
        .ok()
        .filter(|v| v.to_string() == text)
        .ok_or_else(|| Error::new(ErrorKind::IncompatibleNative, "native-u64"))
}
pub(crate) fn signed(value: &Value) -> Result<i64> {
    let text = string(value, "native-i64")?;
    text.parse::<i64>()
        .ok()
        .filter(|v| v.to_string() == text)
        .ok_or_else(|| Error::new(ErrorKind::IncompatibleNative, "native-i64"))
}
pub(crate) fn field<'a>(value: &'a Value, tag: &str) -> Result<&'a Value> {
    value
        .get(tag)
        .ok_or_else(|| Error::new(ErrorKind::IncompatibleNative, "native-action-result"))
}
pub(crate) fn digest(value: &Value) -> Result<[u8; 32]> {
    let items = value
        .as_array()
        .filter(|items| items.len() == 32)
        .ok_or_else(|| Error::new(ErrorKind::IncompatibleNative, "native-digest"))?;
    let mut bytes = [0; 32];
    for (byte, value) in bytes.iter_mut().zip(items) {
        *byte = value
            .as_u64()
            .and_then(|v| u8::try_from(v).ok())
            .ok_or_else(|| Error::new(ErrorKind::IncompatibleNative, "native-digest"))?;
    }
    Ok(bytes)
}
#[derive(Clone, Copy)]
pub(crate) struct Caps {
    pub message: usize,
    pub value: usize,
    pub key: usize,
    pub cell: usize,
    pub name: usize,
    pub page: usize,
    pub segment: usize,
    pub queries: bool,
    pub http_requests: bool,
    pub http_replay: bool,
    pub http_release: bool,
    pub http_followup: bool,
    pub document_codecs: bool,
    pub document_owner: bool,
    pub document_reads: bool,
    pub grpc_requests: bool,
    pub grpc_replay: bool,
    pub grpc_release: bool,
    pub grpc_followup: bool,
}
struct Buffer<'a> {
    pointer: *mut abi::station_buffer,
    api: &'a abi::Api,
}
impl Drop for Buffer<'_> {
    fn drop(&mut self) {
        unsafe {
            (self.api.station_buffer_destroy)(self.pointer);
        }
    }
}
impl Buffer<'_> {
    fn bytes(&self) -> Result<Vec<u8>> {
        if self.pointer.is_null() {
            return Ok(Vec::new());
        }
        let size = unsafe { (self.api.station_buffer_size)(self.pointer) };
        if size > MAX_BODY {
            return Err(Error::new(
                ErrorKind::IncompatibleNative,
                "native-buffer-bound",
            ));
        }
        if size == 0 {
            return Ok(Vec::new());
        }
        let data = unsafe { (self.api.station_buffer_data)(self.pointer) };
        if data.is_null() {
            return Err(Error::new(ErrorKind::IncompatibleNative, "native-buffer"));
        }
        Ok(unsafe { slice::from_raw_parts(data, size) }.to_vec())
    }
    fn result(&self, status: u32, phase: &'static str, mutation: bool) -> Result<Value> {
        let invalid = || {
            Error::new(
                if mutation {
                    ErrorKind::UnknownOutcome
                } else {
                    ErrorKind::ReadFailed
                },
                phase,
            )
        };
        let bytes = self.bytes().map_err(|_| invalid())?;
        let value = if bytes.is_empty() {
            Value::Null
        } else {
            serde_json::from_slice(&bytes).map_err(|_| {
                if status == 0 {
                    return invalid();
                }
                let mut error = native_error(status, None, phase);
                error.diagnostic_invalid = true;
                error
            })?
        };
        if status != 0 {
            return Err(native_error(status, Some(&value), phase).with_diagnostic(
                &value,
                |bytes| unsafe {
                    (self.api.station_diagnostic_validate)(bytes.as_ptr(), bytes.len()) == 1
                },
            ));
        }
        Ok(value)
    }
}
struct Local {
    api: abi::Api,
    _artifact: Artifact,
    caps: Caps,
}
impl Local {
    fn open(directory: Option<&Path>) -> Result<Self> {
        if transit_native_station::VERSION != "0.2.0" {
            return Err(Error::new(ErrorKind::IncompatibleNative, "native-version"));
        }
        let artifact = Artifact::open(
            transit_native_station::LIBRARY,
            "libtransit_station.so",
            directory,
        )?;
        let api = unsafe { abi::Api::load(artifact.load()?) }
            .map_err(|_| Error::new(ErrorKind::IncompatibleNative, "station-symbols"))?;
        if unsafe {
            (api.station_abi_definition_matches)(
                abi::ABI_DEFINITION.as_ptr(),
                abi::ABI_DEFINITION.len(),
            )
        } != 1
            || unsafe { (api.station_abi_version)() } != abi::ABI_VERSION
        {
            return Err(Error::new(ErrorKind::IncompatibleNative, "station-version"));
        }
        let caps;
        {
            let mut buffer = Buffer {
                api: &api,
                pointer: ptr::null_mut(),
            };
            let status = unsafe { (api.station_growing_capabilities)(&mut buffer.pointer) };
            let value = buffer.result(status, "native-capabilities", false)?;
            if value["version"] != 1 || value["profile"] != "native_v1" {
                return Err(Error::new(
                    ErrorKind::UnsupportedCapability,
                    "native-profile",
                ));
            }
            for name in [
                "gated_dispatch",
                "retained_confirmation",
                "scoped_turns",
                "paged_state",
                "tables",
                "retained_sources",
            ] {
                if !boolean(&value[name], "native-capabilities")? {
                    return Err(Error::new(
                        ErrorKind::UnsupportedCapability,
                        "native-capabilities",
                    ));
                }
            }
            caps = Caps {
                message: size(&value["message_bytes"], false)?,
                value: size(&value["value_bytes"], false)?,
                key: size(&value["key_bytes"], false)?,
                cell: size(&value["table_cell_bytes"], false)?,
                name: size(&value["table_name_bytes"], false)?,
                page: size(&value["page_entries"], false)?,
                segment: size(&value["query_segment_bytes"], false)?,
                queries: boolean(&value["query_results"], "native-capabilities")?,
                http_requests: boolean(&value["http_requests"], "native-capabilities")?,
                http_replay: boolean(&value["http_replay"], "native-capabilities")?,
                http_release: value["http_release"].as_bool().unwrap_or(false),
                http_followup: value["http_followup"].as_bool().unwrap_or(false),
                document_codecs: value["document_codecs"].as_bool().unwrap_or(false),
                document_owner: value["document_owner"].as_bool().unwrap_or(false),
                document_reads: value["document_reads"].as_bool().unwrap_or(false),
                grpc_requests: boolean(&value["grpc_requests"], "native-capabilities")?,
                grpc_replay: boolean(&value["grpc_replay"], "native-capabilities")?,
                grpc_release: value["grpc_release"].as_bool().unwrap_or(false),
                grpc_followup: value["grpc_followup"].as_bool().unwrap_or(false),
            };
        }
        Ok(Self {
            api,
            _artifact: artifact,
            caps,
        })
    }
}
pub(crate) struct Bridge {
    pointer: *mut abi::station_growing_server,
    local: Local,
    raw: Native,
    pub caps: Caps,
}
impl Bridge {
    pub fn open(config: &ServiceConfig, failure: FailurePolicy) -> Result<Self> {
        let (url, timeout, directory) = settings(&config.client);
        let local = Local::open(directory)?;
        if config.association.len() > local.caps.key || config.query_results && !local.caps.queries
        {
            return Err(Error::new(
                ErrorKind::UnsupportedCapability,
                "runner-capabilities",
            ));
        }
        let raw = Native::open(&config.client)?;
        let authority = raw.capabilities(&config.activation.credential)?;
        if !authority.association_lookup || !authority.scoped_retry || !authority.retained_versions
        {
            return Err(Error::new(
                ErrorKind::UnsupportedCapability,
                "authority-capabilities",
            ));
        }
        let key = credential_seed(&config.activation.credential)?;
        let value = json!({"profile":"native_v1", "realm":config.activation.process.realm(), "principal":config.activation.credential.principal(),
            "pid":config.activation.process.pid(), "generation":config.activation.generation.get(), "association":config.association, "timeout_ms":timeout,
            "failure_policy":if failure == FailurePolicy::Stop { "stop" } else { "block_input" }, "query_results":config.query_results});
        let bytes = serde_json::to_vec(&value)
            .map_err(|_| Error::new(ErrorKind::InvalidArgument, "runner-configuration"))?;
        let mut pointer = ptr::null_mut();
        let status = unsafe {
            (local.api.station_growing_create)(
                abi::ABI_VERSION,
                url.as_ptr(),
                url.len(),
                key.pointer(),
                bytes.as_ptr(),
                bytes.len(),
                &mut pointer,
            )
        };
        if status != 0 {
            return Err(native_error(status, None, "open-runner"));
        }
        if pointer.is_null() {
            return Err(Error::new(ErrorKind::IncompatibleNative, "open-runner"));
        }
        let caps = local.caps;
        Ok(Self {
            pointer,
            local,
            raw,
            caps,
        })
    }
    pub fn prepare(&mut self) -> Result<Value> {
        let now = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .map_err(|_| Error::new(ErrorKind::ReadFailed, "clock"))?
            .as_millis();
        let deadline =
            u64::try_from(now + 30000).map_err(|_| Error::new(ErrorKind::ReadFailed, "clock"))?;
        let mut buffer = Buffer {
            api: &self.local.api,
            pointer: ptr::null_mut(),
        };
        let status = unsafe {
            (self.local.api.station_growing_prepare)(self.pointer, deadline, &mut buffer.pointer)
        };
        buffer.result(status, "prepare-turn", false)
    }
    pub fn apply(&mut self, scope: u64, action: &Value) -> Result<Value> {
        let bytes = serde_json::to_vec(action)
            .map_err(|_| Error::new(ErrorKind::InvalidArgument, "action"))?;
        if bytes.len() > MAX_BODY {
            return Err(Error::new(ErrorKind::InvalidArgument, "action-bound"));
        }
        let mut buffer = Buffer {
            api: &self.local.api,
            pointer: ptr::null_mut(),
        };
        let status = unsafe {
            (self.local.api.station_growing_apply)(
                self.pointer,
                scope,
                bytes.as_ptr(),
                bytes.len(),
                &mut buffer.pointer,
            )
        };
        buffer.result(status, "apply", false)
    }
    pub fn finish(&mut self, scope: u64, failed: bool) -> Result<()> {
        let mut buffer = Buffer {
            api: &self.local.api,
            pointer: ptr::null_mut(),
        };
        let status = unsafe {
            (self.local.api.station_growing_finish_result)(
                self.pointer,
                scope,
                failed.into(),
                &mut buffer.pointer,
            )
        };
        buffer.result(status, "finish", false).map(|_| ())
    }
    pub fn http_read(&mut self, action: Value) -> Result<Value> {
        if !self.caps.http_replay {
            return Err(Error::new(ErrorKind::UnsupportedCapability, "http-replay"));
        }
        let bytes = serde_json::to_vec(&action)
            .map_err(|_| Error::new(ErrorKind::InvalidArgument, "http-read"))?;
        if bytes.len() > 2048 {
            return Err(Error::new(ErrorKind::InvalidArgument, "http-read-bound"));
        }
        let mut buffer = Buffer {
            api: &self.local.api,
            pointer: ptr::null_mut(),
        };
        let status = unsafe {
            (self.local.api.station_growing_http_read)(
                self.pointer,
                bytes.as_ptr(),
                bytes.len(),
                &mut buffer.pointer,
            )
        };
        buffer.result(status, "http-read", false)
    }
    pub fn document_read(&mut self, action: Value) -> Result<Value> {
        if !self.caps.document_reads {
            return Err(Error::new(
                ErrorKind::UnsupportedCapability,
                "document-read",
            ));
        }
        let bytes = serde_json::to_vec(&action)
            .map_err(|_| Error::new(ErrorKind::InvalidArgument, "document-read"))?;
        if bytes.len() > 4096 {
            return Err(Error::new(
                ErrorKind::InvalidArgument,
                "document-read-bound",
            ));
        }
        let mut buffer = Buffer {
            api: &self.local.api,
            pointer: ptr::null_mut(),
        };
        let status = unsafe {
            (self.local.api.station_growing_document_read)(
                self.pointer,
                bytes.as_ptr(),
                bytes.len(),
                &mut buffer.pointer,
            )
        };
        buffer.result(status, "document-read", false)
    }
    pub fn document_codec(&mut self, action: Value) -> Result<Value> {
        document_codec_local(&self.local, action)
    }
    pub fn grpc_read(&mut self, action: Value) -> Result<Value> {
        if !self.caps.grpc_replay {
            return Err(Error::new(ErrorKind::UnsupportedCapability, "grpc-replay"));
        }
        let bytes = serde_json::to_vec(&action)
            .map_err(|_| Error::new(ErrorKind::InvalidArgument, "grpc-read"))?;
        if bytes.len() > 2048 {
            return Err(Error::new(ErrorKind::InvalidArgument, "grpc-read-bound"));
        }
        let mut buffer = Buffer {
            api: &self.local.api,
            pointer: ptr::null_mut(),
        };
        let status = unsafe {
            (self.local.api.station_growing_grpc_read)(
                self.pointer,
                bytes.as_ptr(),
                bytes.len(),
                &mut buffer.pointer,
            )
        };
        buffer.result(status, "grpc-read", false)
    }
    pub fn discard(&mut self, scope: u64) -> Result<()> {
        let status = unsafe { (self.local.api.station_growing_discard)(self.pointer, scope) };
        if status != 0 {
            return Err(native_error(status, None, "discard"));
        }
        Ok(())
    }
    pub fn pending(&mut self, event: &Value) -> Result<FrozenMutation> {
        let purpose = match string(&event["pending_kind"], "pending-purpose")? {
            "permit" => Purpose::Permit,
            "open" => Purpose::Open,
            "commit" => Purpose::Commit,
            _ => return Err(Error::new(ErrorKind::IncompatibleNative, "pending-purpose")),
        };
        let input = counter(&event["pending_input"], false)?;
        let mut buffer = Buffer {
            api: &self.local.api,
            pointer: ptr::null_mut(),
        };
        let status =
            unsafe { (self.local.api.station_growing_pending)(self.pointer, &mut buffer.pointer) };
        if status != 0 {
            return Err(native_error(status, None, "pending"));
        }
        let bytes = buffer.bytes()?;
        let metadata = mutation_info(&self.raw.metadata(&bytes)?)?;
        if !match purpose {
            Purpose::Permit => metadata.command == "begin_turn",
            Purpose::Open => metadata.command == "open_view",
            Purpose::Commit => matches!(metadata.command.as_str(), "turn" | "turn_with_versions"),
        } {
            return Err(Error::new(ErrorKind::IncompatibleNative, "pending-purpose"));
        }
        Ok(FrozenMutation {
            identity: metadata.identity,
            purpose,
            input,
            bytes: bytes.into_boxed_slice(),
        })
    }
    pub fn dispatch(&mut self) -> Result<Value> {
        let mut buffer = Buffer {
            api: &self.local.api,
            pointer: ptr::null_mut(),
        };
        let status =
            unsafe { (self.local.api.station_growing_dispatch)(self.pointer, &mut buffer.pointer) };
        buffer.result(status, "dispatch", true)
    }
    pub fn confirmation(&mut self, pending: &FrozenMutation) -> Result<Option<Value>> {
        let mut buffer = Buffer {
            api: &self.local.api,
            pointer: ptr::null_mut(),
        };
        let status = unsafe {
            (self.local.api.station_growing_confirmation)(self.pointer, &mut buffer.pointer)
        };
        let value = match buffer.result(status, "observe-confirmation", false) {
            Ok(value) => value,
            Err(error) if error.kind == ErrorKind::TurnExpired => return Ok(None),
            Err(error) => return Err(error),
        };
        if value["confirmation"]["kind"] == pending.purpose.native()
            && value["confirmation"]["input"] == pending.input.get()
        {
            Ok(Some(value))
        } else {
            Ok(None)
        }
    }
}
impl Drop for Bridge {
    fn drop(&mut self) {
        unsafe {
            (self.local.api.station_growing_destroy)(self.pointer);
        }
    }
}

pub fn encode_cast<T: 'static>(
    value: &T,
    codec: &dyn Codec<T>,
    native_directory: Option<&Path>,
) -> Result<Box<[u8]>> {
    let directory = native_directory.map(Path::to_owned);
    let mut worker = Worker::open(abi::MINIMUM_STACK_BYTES, move || {
        Local::open(directory.as_deref())
    })?;
    let bound = worker.call(|local| Ok(local.caps.message))?;
    let bytes = encode(codec, value, bound)?;
    let output = worker.call(move |local| {
        let mut buffer = Buffer {
            api: &local.api,
            pointer: ptr::null_mut(),
        };
        let status = unsafe {
            (local.api.station_frame_encode)(1, 0, bytes.as_ptr(), bytes.len(), &mut buffer.pointer)
        };
        if status != 0 {
            return Err(native_error(status, None, "encode-cast"));
        }
        let value: Value = serde_json::from_slice(&buffer.bytes()?)
            .map_err(|_| Error::new(ErrorKind::IncompatibleNative, "encode-cast"))?;
        Ok(unhex(string(&value, "encoded-frame")?, local.caps.message + 13)?.into_boxed_slice())
    })?;
    worker.close()?;
    Ok(output)
}

pub(crate) fn http_codec(
    action: Value,
    native_directory: Option<&Path>,
    release: bool,
) -> Result<Value> {
    let bytes = serde_json::to_vec(&action)
        .map_err(|_| Error::new(ErrorKind::InvalidArgument, "http-codec"))?;
    if bytes.len() > MAX_BODY {
        return Err(Error::new(ErrorKind::InvalidArgument, "http-codec-bound"));
    }
    let directory = native_directory.map(Path::to_owned);
    let mut worker = Worker::open(abi::MINIMUM_STACK_BYTES, move || {
        Local::open(directory.as_deref())
    })?;
    let result = worker.call(move |local| {
        if !local.caps.http_requests || release && !local.caps.http_release {
            return Err(Error::new(
                ErrorKind::UnsupportedCapability,
                "http-requests",
            ));
        }
        let mut buffer = Buffer {
            api: &local.api,
            pointer: ptr::null_mut(),
        };
        let status = unsafe {
            (local.api.station_http_codec)(bytes.as_ptr(), bytes.len(), &mut buffer.pointer)
        };
        buffer.result(status, "http-codec", false)
    });
    worker.close()?;
    result
}

pub(crate) fn grpc_codec(
    action: Value,
    native_directory: Option<&Path>,
    release: bool,
) -> Result<Value> {
    let bytes = serde_json::to_vec(&action)
        .map_err(|_| Error::new(ErrorKind::InvalidArgument, "grpc-codec"))?;
    if bytes.len() > MAX_BODY {
        return Err(Error::new(ErrorKind::InvalidArgument, "grpc-codec-bound"));
    }
    let directory = native_directory.map(Path::to_owned);
    let mut worker = Worker::open(abi::MINIMUM_STACK_BYTES, move || {
        Local::open(directory.as_deref())
    })?;
    let result = worker.call(move |local| {
        if !local.caps.grpc_requests || release && !local.caps.grpc_release {
            return Err(Error::new(
                ErrorKind::UnsupportedCapability,
                "grpc-requests",
            ));
        }
        let mut buffer = Buffer {
            api: &local.api,
            pointer: ptr::null_mut(),
        };
        let status = unsafe {
            (local.api.station_grpc_codec)(bytes.as_ptr(), bytes.len(), &mut buffer.pointer)
        };
        buffer.result(status, "grpc-codec", false)
    });
    worker.close()?;
    result
}

fn document_codec_local(local: &Local, action: Value) -> Result<Value> {
    if !local.caps.document_codecs {
        return Err(Error::new(
            ErrorKind::UnsupportedCapability,
            "document-codec",
        ));
    }
    let bytes = serde_json::to_vec(&action)
        .map_err(|_| Error::new(ErrorKind::InvalidArgument, "document-codec"))?;
    if bytes.len() > 32768 {
        return Err(Error::new(
            ErrorKind::InvalidArgument,
            "document-codec-bound",
        ));
    }
    let mut buffer = Buffer {
        api: &local.api,
        pointer: ptr::null_mut(),
    };
    let status = unsafe {
        (local.api.station_document_codec)(bytes.as_ptr(), bytes.len(), &mut buffer.pointer)
    };
    buffer.result(status, "document-codec", false)
}
pub(crate) fn document_codec(action: Value, native_directory: Option<&Path>) -> Result<Value> {
    let directory = native_directory.map(Path::to_owned);
    let mut worker = Worker::open(abi::MINIMUM_STACK_BYTES, move || {
        Local::open(directory.as_deref())
    })?;
    let result = worker.call(move |local| document_codec_local(local, action));
    worker.close()?;
    result
}

pub(crate) fn unified_codec(action: Value, native_directory: Option<&Path>) -> Result<Value> {
    let directory = native_directory.map(Path::to_owned);
    let mut worker = Worker::open(abi::MINIMUM_STACK_BYTES, move || {
        Local::open(directory.as_deref())
    })?;
    let result = worker.call(move |local| {
        let bytes = serde_json::to_vec(&action)
            .map_err(|_| Error::new(ErrorKind::InvalidArgument, "query-codec"))?;
        if bytes.len() > MAX_BODY {
            return Err(Error::new(ErrorKind::InvalidArgument, "query-codec-bound"));
        }
        let mut buffer = Buffer {
            api: &local.api,
            pointer: ptr::null_mut(),
        };
        let status = unsafe {
            (local.api.station_unified_query_codec)(
                bytes.as_ptr(),
                bytes.len(),
                &mut buffer.pointer,
            )
        };
        buffer.result(status, "query-codec", false)
    });
    worker.close()?;
    result
}

pub(crate) struct QueryNative {
    local: Local,
    pointer: *mut abi::station_query_client,
}
impl QueryNative {
    pub fn open(
        config: &transit_client::ClientConfig,
        credential: &transit_client::Credential,
        connection: &crate::unified::Connection,
    ) -> Result<Self> {
        let (url, timeout, directory) = settings(config);
        let local = Local::open(directory)?;
        let key = credential_seed(credential)?;
        let bytes = serde_json::to_vec(
            &json!({"connection":connection.wire(credential.principal()),"timeout_ms":timeout}),
        )
        .map_err(|_| Error::new(ErrorKind::InvalidArgument, "query-config"))?;
        let mut pointer = ptr::null_mut();
        let status = unsafe {
            (local.api.station_unified_query_create)(
                abi::ABI_VERSION,
                url.as_ptr(),
                url.len(),
                key.pointer(),
                bytes.as_ptr(),
                bytes.len(),
                &mut pointer,
            )
        };
        if status != 0 {
            return Err(native_error(status, None, "open-query"));
        }
        if pointer.is_null() {
            return Err(Error::new(ErrorKind::IncompatibleNative, "open-query"));
        }
        let mut out = Self { local, pointer };
        let caps = out.call(json!({"capabilities":{}}))?;
        let caps = field(&caps, "capabilities")?;
        if caps["version"] != 1
            || ["kv", "table", "document"]
                .iter()
                .any(|name| caps[name] != true)
        {
            return Err(Error::new(
                ErrorKind::UnsupportedCapability,
                "query-capabilities",
            ));
        }
        Ok(out)
    }
    pub fn call(&mut self, action: Value) -> Result<Value> {
        let mutation = action.get("submit").is_some();
        let bytes = serde_json::to_vec(&action)
            .map_err(|_| Error::new(ErrorKind::InvalidArgument, "query-action"))?;
        if bytes.len() > MAX_BODY {
            return Err(Error::new(ErrorKind::InvalidArgument, "query-action-bound"));
        }
        let mut buffer = Buffer {
            api: &self.local.api,
            pointer: ptr::null_mut(),
        };
        let status = unsafe {
            (self.local.api.station_unified_query_call)(
                self.pointer,
                bytes.as_ptr(),
                bytes.len(),
                &mut buffer.pointer,
            )
        };
        buffer.result(status, "query-action", mutation)
    }
}
impl Drop for QueryNative {
    fn drop(&mut self) {
        unsafe { (self.local.api.station_unified_query_destroy)(self.pointer) };
    }
}

pub(crate) struct MutationNative {
    local: Local,
    pointer: *mut abi::station_mutation_client,
}
impl MutationNative {
    pub fn open(
        config: &transit_client::ClientConfig,
        credential: &transit_client::Credential,
        connection: &crate::mutations::Connection,
    ) -> Result<Self> {
        let (url, timeout, directory) = settings(config);
        let local = Local::open(directory)?;
        let key = credential_seed(credential)?;
        let bytes = serde_json::to_vec(
            &json!({"connection":connection.wire(credential.principal()),"timeout_ms":timeout}),
        )
        .map_err(|_| Error::new(ErrorKind::InvalidArgument, "mutation-config"))?;
        let mut pointer = ptr::null_mut();
        let status = unsafe {
            (local.api.station_table_mutation_create)(
                abi::ABI_VERSION,
                url.as_ptr(),
                url.len(),
                key.pointer(),
                bytes.as_ptr(),
                bytes.len(),
                &mut pointer,
            )
        };
        if status != 0 {
            return Err(native_error(status, None, "open-mutation"));
        }
        if pointer.is_null() {
            return Err(Error::new(ErrorKind::IncompatibleNative, "open-mutation"));
        }
        let mut out = Self { local, pointer };
        let caps = out.call(json!({"capabilities":{}}))?;
        let caps = field(&caps, "capabilities")?;
        if caps["version"] != 1
            || caps["max_rows"] != 3
            || caps["max_request_bytes"] != 799
            || caps["max_saved_bytes"] != 8192
            || ["insert", "update_primary_key", "delete_primary_key"]
                .iter()
                .any(|name| caps[name] != true)
        {
            return Err(Error::new(
                ErrorKind::UnsupportedCapability,
                "mutation-capabilities",
            ));
        }
        Ok(out)
    }
    pub fn call(&mut self, action: Value) -> Result<Value> {
        let mutation = action.get("submit").is_some();
        let bytes = serde_json::to_vec(&action)
            .map_err(|_| Error::new(ErrorKind::InvalidArgument, "mutation-action"))?;
        if bytes.len() > MAX_BODY {
            return Err(Error::new(
                ErrorKind::InvalidArgument,
                "mutation-action-bound",
            ));
        }
        let mut buffer = Buffer {
            api: &self.local.api,
            pointer: ptr::null_mut(),
        };
        let status = unsafe {
            (self.local.api.station_table_mutation_call)(
                self.pointer,
                bytes.as_ptr(),
                bytes.len(),
                &mut buffer.pointer,
            )
        };
        buffer.result(status, "mutation-action", mutation)
    }
}
impl Drop for MutationNative {
    fn drop(&mut self) {
        unsafe { (self.local.api.station_table_mutation_destroy)(self.pointer) };
    }
}

pub(crate) struct CatalogNative {
    local: Local,
    pointer: *mut abi::station_catalog_client,
}
impl CatalogNative {
    pub fn open(
        config: &transit_client::ClientConfig,
        credential: &transit_client::Credential,
        connection: &crate::catalog::Connection,
    ) -> Result<Self> {
        let (url, timeout, directory) = settings(config);
        let local = Local::open(directory)?;
        let key = credential_seed(credential)?;
        let bytes = serde_json::to_vec(
            &json!({"connection":connection.wire(credential.principal()),"timeout_ms":timeout}),
        )
        .map_err(|_| Error::new(ErrorKind::InvalidArgument, "catalog-config"))?;
        let mut pointer = ptr::null_mut();
        let status = unsafe {
            (local.api.station_catalog_create)(
                abi::ABI_VERSION,
                url.as_ptr(),
                url.len(),
                key.pointer(),
                bytes.as_ptr(),
                bytes.len(),
                &mut pointer,
            )
        };
        if status != 0 {
            return Err(native_error(status, None, "open-catalog"));
        }
        if pointer.is_null() {
            return Err(Error::new(ErrorKind::IncompatibleNative, "open-catalog"));
        }
        let mut out = Self { local, pointer };
        let caps = out.call(json!({"capabilities":{}}))?;
        let caps = field(&caps, "capabilities")?;
        if caps["version"] != 1
            || caps["definition"] != abi::ABI_DEFINITION
            || caps["table_columns"] != 2
            || caps["max_saved_bytes"] != 8192
            || [
                "initialize",
                "create_table",
                "conditional_policy",
                "current_metadata",
            ]
            .iter()
            .any(|name| caps[name] != true)
        {
            return Err(Error::new(
                ErrorKind::UnsupportedCapability,
                "catalog-capabilities",
            ));
        }
        Ok(out)
    }
    pub fn call(&mut self, action: Value) -> Result<Value> {
        let mutation = action.get("submit").is_some();
        let bytes = serde_json::to_vec(&action)
            .map_err(|_| Error::new(ErrorKind::InvalidArgument, "catalog-action"))?;
        if bytes.len() > MAX_BODY {
            return Err(Error::new(
                ErrorKind::InvalidArgument,
                "catalog-action-bound",
            ));
        }
        let mut buffer = Buffer {
            api: &self.local.api,
            pointer: ptr::null_mut(),
        };
        let status = unsafe {
            (self.local.api.station_catalog_call)(
                self.pointer,
                bytes.as_ptr(),
                bytes.len(),
                &mut buffer.pointer,
            )
        };
        buffer.result(status, "catalog-action", mutation)
    }
}
impl Drop for CatalogNative {
    fn drop(&mut self) {
        unsafe { (self.local.api.station_catalog_destroy)(self.pointer) };
    }
}
