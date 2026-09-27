//! Owned Document values around shared Zig. No merge or acceptance logic here.
use crate::{
    Runner, Turn,
    bridge::{counter, document_codec, field, signed, wide},
    turn::Access,
};
use serde_json::{Value, json};
use std::path::Path;
use transit_client::internal::{boolean, hex, number, string, unhex};
use transit_client::{Counter, Error, ErrorKind, ResourceRef, Result};

fn invalid() -> Error {
    Error::new(ErrorKind::InvalidArgument, "document-value")
}
fn malformed() -> Error {
    Error::new(ErrorKind::IncompatibleNative, "document-response")
}
#[derive(Clone, Copy, Debug, Default, PartialEq, Eq)]
pub struct DocumentDot {
    pub counter: u64,
    pub replica: u64,
}
impl DocumentDot {
    pub const ROOT: Self = Self {
        counter: 0,
        replica: 0,
    };
    fn wire(self) -> Result<Value> {
        if (self.counter == 0) != (self.replica == 0) {
            return Err(invalid());
        }
        Ok(json!({"counter":self.counter.to_string(),"replica":self.replica.to_string()}))
    }
    fn parse(v: &Value) -> Result<Self> {
        let out = Self {
            counter: wide(field(v, "counter")?)?,
            replica: wide(field(v, "replica")?)?,
        };
        out.wire()?;
        Ok(out)
    }
}
#[derive(Clone, PartialEq)]
pub enum DocumentValue {
    Null,
    Boolean(bool),
    Signed(i64),
    Unsigned(u64),
    Float(f64),
    String(String),
    Binary(Vec<u8>),
    Map,
    List,
    Text,
    Character(char),
}
impl DocumentValue {
    fn wire(&self) -> Result<Value> {
        Ok(match self {
            Self::Null => json!({"null_value":{}}),
            Self::Map => json!({"map":{}}),
            Self::List => json!({"list":{}}),
            Self::Text => json!({"text":{}}),
            Self::Boolean(v) => json!({"boolean":v}),
            Self::Signed(v) => json!({"signed":v.to_string()}),
            Self::Unsigned(v) => json!({"unsigned":v.to_string()}),
            Self::Float(v) if v.is_finite() => json!({"float_bits":hex(&v.to_le_bytes(),8)?}),
            Self::String(v) if v.len() <= 96 => json!({"string":v}),
            Self::Binary(v) => json!({"binary":hex(v,96)?}),
            Self::Character(v) => json!({"character":v.to_string()}),
            _ => return Err(invalid()),
        })
    }
    fn parse(v: &Value) -> Result<Self> {
        let fields = v.as_object().ok_or_else(malformed)?;
        if fields.len() != 1 {
            return Err(malformed());
        }
        let (kind, v) = fields.iter().next().ok_or_else(malformed)?;
        Ok(match kind.as_str() {
            "null_value" => Self::Null,
            "map" => Self::Map,
            "list" => Self::List,
            "text" => Self::Text,
            "boolean" => Self::Boolean(boolean(v, "document-boolean")?),
            "signed" => Self::Signed(signed(v)?),
            "unsigned" => Self::Unsigned(wide(v)?),
            "float_bits" => {
                let bytes: [u8; 8] = unhex(string(v, "document-float")?, 8)?
                    .try_into()
                    .map_err(|_| malformed())?;
                let value = f64::from_le_bytes(bytes);
                if !value.is_finite() {
                    return Err(malformed());
                }
                Self::Float(value)
            }
            "string" => {
                let text = string(v, "document-string")?;
                if text.len() > 96 {
                    return Err(malformed());
                }
                Self::String(text.to_owned())
            }
            "binary" => Self::Binary(unhex(string(v, "document-binary")?, 96)?),
            "character" => {
                let mut chars = string(v, "document-character")?.chars();
                let value = chars.next().ok_or_else(malformed)?;
                if chars.next().is_some() {
                    return Err(malformed());
                }
                Self::Character(value)
            }
            _ => return Err(malformed()),
        })
    }
}
#[derive(Clone)]
pub enum DocumentOperation {
    Assign {
        object: DocumentDot,
        field: String,
        observed: Vec<DocumentDot>,
        value: DocumentValue,
    },
    Remove {
        object: DocumentDot,
        field: String,
        observed: Vec<DocumentDot>,
    },
    Insert {
        object: DocumentDot,
        after: DocumentDot,
        value: DocumentValue,
    },
    SetElement {
        object: DocumentDot,
        element: DocumentDot,
        observed: Vec<DocumentDot>,
        value: DocumentValue,
    },
    DeleteElement {
        object: DocumentDot,
        element: DocumentDot,
    },
}
fn observed(values: &[DocumentDot]) -> Result<Vec<Value>> {
    if values.len() > 8 {
        return Err(invalid());
    }
    values.iter().map(|dot| dot.wire()).collect()
}
fn parsed_observed(v: &Value) -> Result<Vec<DocumentDot>> {
    let values = v.as_array().ok_or_else(malformed)?;
    if values.len() > 8 {
        return Err(malformed());
    }
    values.iter().map(DocumentDot::parse).collect()
}
impl DocumentOperation {
    fn wire(&self) -> Result<Value> {
        Ok(match self {
            Self::Assign {
                object,
                field,
                observed: dots,
                value,
            } => {
                json!({"assign":{"object":object.wire()?,"field":field,"observed":observed(dots)?,"value":value.wire()?}})
            }
            Self::Remove {
                object,
                field,
                observed: dots,
            } => {
                json!({"remove":{"object":object.wire()?,"field":field,"observed":observed(dots)?}})
            }
            Self::Insert {
                object,
                after,
                value,
            } => {
                json!({"insert":{"object":object.wire()?,"after":after.wire()?,"value":value.wire()?}})
            }
            Self::SetElement {
                object,
                element,
                observed: dots,
                value,
            } => {
                json!({"set_element":{"object":object.wire()?,"element":element.wire()?,"observed":observed(dots)?,"value":value.wire()?}})
            }
            Self::DeleteElement { object, element } => {
                json!({"delete_element":{"object":object.wire()?,"element":element.wire()?}})
            }
        })
    }
    fn parse(v: &Value) -> Result<Self> {
        let fields = v.as_object().ok_or_else(malformed)?;
        if fields.len() != 1 {
            return Err(malformed());
        }
        let (kind, v) = fields.iter().next().ok_or_else(malformed)?;
        let object = DocumentDot::parse(field(v, "object")?)?;
        Ok(match kind.as_str() {
            "assign" => Self::Assign {
                object,
                field: string(field(v, "field")?, "document-field")?.to_owned(),
                observed: parsed_observed(field(v, "observed")?)?,
                value: DocumentValue::parse(field(v, "value")?)?,
            },
            "remove" => Self::Remove {
                object,
                field: string(field(v, "field")?, "document-field")?.to_owned(),
                observed: parsed_observed(field(v, "observed")?)?,
            },
            "insert" => Self::Insert {
                object,
                after: DocumentDot::parse(field(v, "after")?)?,
                value: DocumentValue::parse(field(v, "value")?)?,
            },
            "set_element" => Self::SetElement {
                object,
                element: DocumentDot::parse(field(v, "element")?)?,
                observed: parsed_observed(field(v, "observed")?)?,
                value: DocumentValue::parse(field(v, "value")?)?,
            },
            "delete_element" => Self::DeleteElement {
                object,
                element: DocumentDot::parse(field(v, "element")?)?,
            },
            _ => return Err(malformed()),
        })
    }
}
#[derive(Clone)]
pub struct DocumentChange {
    pub document: u64,
    pub epoch: u64,
    pub type_revision: u32,
    pub replica: u64,
    pub previous: u64,
    pub first: u64,
    pub operations: Vec<DocumentOperation>,
}
impl DocumentChange {
    fn wire(&self) -> Result<Value> {
        if self.operations.is_empty() || self.operations.len() > 8 {
            return Err(invalid());
        }
        let ops: Vec<Value> = self
            .operations
            .iter()
            .map(DocumentOperation::wire)
            .collect::<Result<_>>()?;
        Ok(
            json!({"document":self.document.to_string(),"epoch":self.epoch.to_string(),"type_revision":self.type_revision,"replica":self.replica.to_string(),"previous":self.previous.to_string(),"first":self.first.to_string(),"operations":ops}),
        )
    }
    fn parse(v: &Value) -> Result<Self> {
        let ops = field(v, "operations")?.as_array().ok_or_else(malformed)?;
        if ops.is_empty() || ops.len() > 8 {
            return Err(malformed());
        }
        Ok(Self {
            document: wide(field(v, "document")?)?,
            epoch: wide(field(v, "epoch")?)?,
            type_revision: u32::try_from(number(
                field(v, "type_revision")?,
                "document-type",
                false,
            )?)
            .map_err(|_| malformed())?,
            replica: wide(field(v, "replica")?)?,
            previous: wide(field(v, "previous")?)?,
            first: wide(field(v, "first")?)?,
            operations: ops
                .iter()
                .map(DocumentOperation::parse)
                .collect::<Result<_>>()?,
        })
    }
}
#[derive(Clone)]
pub struct PreparedDocumentChange {
    document: u64,
    data: Vec<u8>,
}
impl PreparedDocumentChange {
    pub fn document(&self) -> u64 {
        self.document
    }
    pub fn data(&self) -> &[u8] {
        &self.data
    }
}
pub fn prepare_document(
    change: &DocumentChange,
    native_directory: Option<&Path>,
) -> Result<PreparedDocumentChange> {
    let out = document_codec(json!({"prepare":change.wire()?}), native_directory)?;
    Ok(PreparedDocumentChange {
        document: change.document,
        data: unhex(
            string(field(field(&out, "prepared")?, "bytes")?, "document-bytes")?,
            4096,
        )?,
    })
}
pub fn decode_document(bytes: &[u8], native_directory: Option<&Path>) -> Result<DocumentChange> {
    DocumentChange::parse(field(
        &document_codec(json!({"decode":hex(bytes,4096)?}), native_directory)?,
        "change",
    )?)
}
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct DocumentReference {
    resource: ResourceRef,
    document: u64,
    epoch: u64,
    type_revision: u32,
    revision: u64,
    data: [u8; 40],
}
impl DocumentReference {
    pub fn resource(&self) -> ResourceRef {
        self.resource
    }
    pub fn document(&self) -> u64 {
        self.document
    }
    pub fn epoch(&self) -> u64 {
        self.epoch
    }
    pub fn type_revision(&self) -> u32 {
        self.type_revision
    }
    pub fn revision(&self) -> u64 {
        self.revision
    }
    pub fn data(&self) -> &[u8] {
        &self.data
    }
    pub fn decode(realm: u64, bytes: &[u8], directory: Option<&Path>) -> Result<Self> {
        let response = document_codec(json!({"inspect_reference":hex(bytes,40)?}), directory)?;
        Self::from_native(realm, bytes, field(&response, "inspected_reference")?)
    }
    fn from_native(realm: u64, bytes: &[u8], v: &Value) -> Result<Self> {
        Ok(Self {
            resource: ResourceRef::new(
                realm,
                number(field(v, "resource")?, "document-resource", false)?,
            )?,
            document: wide(field(v, "document")?)?,
            epoch: wide(field(v, "epoch")?)?,
            type_revision: u32::try_from(number(
                field(v, "type_revision")?,
                "document-type",
                false,
            )?)
            .map_err(|_| malformed())?,
            revision: wide(field(v, "revision")?)?,
            data: bytes.try_into().map_err(|_| malformed())?,
        })
    }
}
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum DocumentStatus {
    Missing,
    Null,
    Scalar,
    Object,
    Conflict,
}
#[derive(Clone)]
pub struct DocumentAssignment {
    pub id: DocumentDot,
    pub value: DocumentValue,
}
#[derive(Clone)]
pub struct DocumentField {
    pub status: DocumentStatus,
    pub assignments: Vec<DocumentAssignment>,
}
impl DocumentField {
    pub fn observed(&self) -> Vec<DocumentDot> {
        self.assignments.iter().map(|v| v.id).collect()
    }
    fn parse(v: &Value) -> Result<Self> {
        let status = match string(field(v, "status")?, "document-status")? {
            "missing" => DocumentStatus::Missing,
            "null_value" => DocumentStatus::Null,
            "scalar" => DocumentStatus::Scalar,
            "object" => DocumentStatus::Object,
            "conflict" => DocumentStatus::Conflict,
            _ => return Err(malformed()),
        };
        let values = field(v, "assignments")?.as_array().ok_or_else(malformed)?;
        if values.len() > 8
            || (status == DocumentStatus::Missing) != values.is_empty()
            || (status == DocumentStatus::Conflict) != (values.len() > 1)
        {
            return Err(malformed());
        }
        let assignments = values
            .iter()
            .map(|v| {
                Ok(DocumentAssignment {
                    id: DocumentDot::parse(field(v, "id")?)?,
                    value: DocumentValue::parse(field(v, "value")?)?,
                })
            })
            .collect::<Result<_>>()?;
        Ok(Self {
            status,
            assignments,
        })
    }
}
pub struct DocumentDescription {
    pub reference: DocumentReference,
    pub source_revision: Counter,
    pub floor: u64,
    pub merge_window: u64,
    pub retired: bool,
    pub active_job: u64,
    pub change_format: u32,
}
pub struct DocumentPath {
    pub reference: DocumentReference,
    pub source_revision: Counter,
    pub field: DocumentField,
}
pub struct DocumentItem {
    pub id: DocumentDot,
    pub field: DocumentField,
}
pub struct DocumentPage {
    pub reference: DocumentReference,
    pub source_revision: Counter,
    pub items: Vec<DocumentItem>,
    pub next: Option<String>,
}
pub struct DocumentResynchronization {
    pub reference: DocumentReference,
    pub floor: u64,
    pub replica: u64,
    pub previous_counter: u64,
    pub clock: u64,
}
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum DocumentPhase {
    Progress,
    Accepted,
    Duplicate,
    CheckpointComplete,
}
#[derive(Clone, Copy, Debug)]
pub struct DocumentProgress {
    pub phase: DocumentPhase,
    pub revision: Option<u64>,
}
impl DocumentProgress {
    fn parse(v: &Value) -> Result<Self> {
        let phase = match string(field(v, "phase")?, "document-progress")? {
            "progress" => DocumentPhase::Progress,
            "accepted" => DocumentPhase::Accepted,
            "duplicate" => DocumentPhase::Duplicate,
            "checkpoint_complete" => DocumentPhase::CheckpointComplete,
            _ => return Err(malformed()),
        };
        let revision = match field(v, "revision")? {
            Value::Null => None,
            value => Some(wide(value)?),
        };
        if (phase == DocumentPhase::Progress) != revision.is_none() {
            return Err(malformed());
        }
        Ok(Self { phase, revision })
    }
}
#[derive(Clone, Copy, Debug)]
pub struct DocumentLimits {
    pub record_bytes: u32,
    pub staging_bytes: u64,
    pub staging_records: u32,
}
impl Default for DocumentLimits {
    fn default() -> Self {
        Self {
            record_bytes: 4096,
            staging_bytes: 8192,
            staging_records: 2,
        }
    }
}
pub struct DocumentOwner<'a> {
    access: &'a mut dyn Access,
    document: u64,
}
impl Turn<'_> {
    pub fn document(&mut self, document: u64) -> Result<DocumentOwner<'_>> {
        self.check()?;
        if document == 0 {
            return Err(invalid());
        }
        Ok(DocumentOwner {
            access: self,
            document,
        })
    }
}
impl DocumentOwner<'_> {
    fn apply(&mut self, action: Value) -> Result<Value> {
        self.access.check()?;
        if !self.access.caps().document_owner {
            return Err(Error::new(
                ErrorKind::UnsupportedCapability,
                "document-owner",
            ));
        }
        let result = self.access.apply(json!({"document":action}), false)?;
        Ok(field(&result, "document")?.clone())
    }
    pub fn create(&mut self, type_revision: u32, limits: DocumentLimits) -> Result<()> {
        self.apply(json!({"create":{"document":self.document.to_string(),"type_revision":type_revision,"record_bytes":limits.record_bytes,"staging_bytes":limits.staging_bytes.to_string(),"staging_records":limits.staging_records}}))?;
        Ok(())
    }
    pub fn stage(
        &mut self,
        job: u64,
        change: &PreparedDocumentChange,
        node_limit: u32,
    ) -> Result<DocumentProgress> {
        if change.document != self.document {
            return Err(invalid());
        }
        let v = self.apply(json!({"stage":{"document":self.document.to_string(),"job":job.to_string(),"change":hex(&change.data,4096)?,"node_limit":node_limit}}))?;
        DocumentProgress::parse(field(&v, "progress")?)
    }
    pub fn checkpoint(&mut self, job: u64) -> Result<DocumentProgress> {
        let v = self.apply(
            json!({"checkpoint":{"document":self.document.to_string(),"job":job.to_string()}}),
        )?;
        DocumentProgress::parse(field(&v, "progress")?)
    }
    pub fn merge_window(&mut self, revisions: u64) -> Result<()> {
        self.apply(json!({"merge_window":{"document":self.document.to_string(),"revisions":revisions.to_string()}}))?;
        Ok(())
    }
    pub fn reject(&mut self, job: u64, checkpoint: bool) -> Result<()> {
        self.apply(json!({"reject":{"document":self.document.to_string(),"job":job.to_string(),"checkpoint":checkpoint}}))?;
        Ok(())
    }
    pub fn collect(&mut self, job: u64, checkpoint: bool, retired: bool) -> Result<bool> {
        boolean(field(&self.apply(json!({"collect":{"document":self.document.to_string(),"job":job.to_string(),"checkpoint":checkpoint,"retired":retired}}))?,"collected")?,"document-collected")
    }
    pub fn retire(&mut self) -> Result<()> {
        self.apply(json!({"retire":self.document.to_string()}))?;
        Ok(())
    }
}
pub struct DocumentReader<'a, M: 'static> {
    pub(crate) runner: &'a mut Runner<M>,
    pub(crate) realm: u64,
}
impl<M: 'static> DocumentReader<'_, M> {
    fn identity(&self, resource: ResourceRef, document: u64) -> Result<Value> {
        if resource.realm() != self.realm || document == 0 {
            return Err(invalid());
        }
        Ok(json!({"resource":resource.resource(),"document":document.to_string()}))
    }
    fn encoded(&self, reference: &DocumentReference) -> Result<String> {
        if reference.resource.realm() != self.realm {
            return Err(invalid());
        }
        hex(&reference.data, 40)
    }
    fn reference(&mut self, value: &Value) -> Result<DocumentReference> {
        let bytes = unhex(string(value, "document-reference")?, 40)?;
        let v = self
            .runner
            .document_codec(json!({"inspect_reference":value}))?;
        DocumentReference::from_native(self.realm, &bytes, field(&v, "inspected_reference")?)
    }
    pub fn describe(
        &mut self,
        resource: ResourceRef,
        document: u64,
    ) -> Result<DocumentDescription> {
        let result = self.runner.document_read(
            self.realm,
            json!({"describe":self.identity(resource,document)?}),
        )?;
        let v = field(&result, "description")?;
        Ok(DocumentDescription {
            reference: self.reference(field(v, "reference")?)?,
            source_revision: counter(field(v, "source_revision")?, true)?,
            floor: wide(field(v, "floor")?)?,
            merge_window: wide(field(v, "merge_window")?)?,
            retired: boolean(field(v, "retired")?, "document-retired")?,
            active_job: wide(field(v, "active_job")?)?,
            change_format: u32::try_from(number(
                field(v, "change_format")?,
                "document-format",
                false,
            )?)
            .map_err(|_| malformed())?,
        })
    }
    pub fn path(&mut self, reference: &DocumentReference, names: &[&str]) -> Result<DocumentPath> {
        if names.is_empty() || names.len() > 16 || names.iter().any(|name| name.len() > 64) {
            return Err(invalid());
        }
        let encoded = self.encoded(reference)?;
        let result = self.runner.document_read(
            self.realm,
            json!({"path":{"reference":encoded,"names":names}}),
        )?;
        let v = field(&result, "field")?;
        if string(field(v, "reference")?, "document-reference")? != encoded {
            return Err(malformed());
        }
        Ok(DocumentPath {
            reference: reference.clone(),
            source_revision: counter(field(v, "source_revision")?, true)?,
            field: DocumentField::parse(field(v, "value")?)?,
        })
    }
    pub fn sequence(
        &mut self,
        reference: &DocumentReference,
        object: DocumentDot,
        cursor: Option<&str>,
    ) -> Result<DocumentPage> {
        if cursor.is_some_and(|v| v.len() > 1024) {
            return Err(invalid());
        }
        let encoded = self.encoded(reference)?;
        let result = self.runner.document_read(
            self.realm,
            json!({"sequence":{"reference":encoded,"object":object.wire()?,"cursor":cursor}}),
        )?;
        let v = field(&result, "page")?;
        if string(field(v, "reference")?, "document-reference")? != encoded {
            return Err(malformed());
        }
        let rows = field(v, "items")?.as_array().ok_or_else(malformed)?;
        if rows.len() > 8 {
            return Err(malformed());
        }
        let items = rows
            .iter()
            .map(|v| {
                Ok(DocumentItem {
                    id: DocumentDot::parse(field(v, "id")?)?,
                    field: DocumentField::parse(field(v, "values")?)?,
                })
            })
            .collect::<Result<_>>()?;
        let next = match field(v, "next")? {
            Value::Null => None,
            v => Some(string(v, "document-cursor")?.to_owned()),
        };
        Ok(DocumentPage {
            reference: reference.clone(),
            source_revision: counter(field(v, "source_revision")?, true)?,
            items,
            next,
        })
    }
    pub fn resynchronize(
        &mut self,
        resource: ResourceRef,
        document: u64,
        replica: u64,
    ) -> Result<DocumentResynchronization> {
        let result = self.runner.document_read(self.realm,json!({"resynchronize":{"identity":self.identity(resource,document)?,"replica":replica.to_string()}}))?;
        let v = field(&result, "resynchronization")?;
        Ok(DocumentResynchronization {
            reference: self.reference(field(v, "reference")?)?,
            floor: wide(field(v, "floor")?)?,
            replica: wide(field(v, "replica")?)?,
            previous_counter: wide(field(v, "previous_counter")?)?,
            clock: wide(field(v, "clock")?)?,
        })
    }
    pub fn accepted_change(&mut self, reference: &DocumentReference) -> Result<DocumentChange> {
        let v = self.runner.document_read(
            self.realm,
            json!({"accepted_change":self.encoded(reference)?}),
        )?;
        DocumentChange::parse(field(&v, "change")?)
    }
}
