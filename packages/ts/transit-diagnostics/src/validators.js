// Generated; no runtime code generation or eval.
import lengthModule from "ajv/dist/runtime/ucs2length.js";
const ucs2length = lengthModule.default ?? lengthModule;
"use strict";
export const Diagnostic = validate53;
const schema20 = {"type":"object","additionalProperties":false,"properties":{"version":{"const":1},"definition":{"type":"string","enum":["9438134d5552df1afc0043aab73220112135bc05c260525d7598f6ba694cc31b"]},"code":{"type":"string","maxLength":96},"category":{"type":"string","enum":["syntax","binding","unsupported","constraint","access","conflict","limit","lifecycle","integrity","unavailable","internal"]},"stage":{"type":"string","enum":["input","parse","compile","bind","prepare","submit","admission","execute","read","decode","output","reconcile","cleanup","control"]},"outcome":{"type":"string","enum":["not_applicable","not_submitted","not_dispatched","prepared","unknown","pending","input_rejected","rejected","applied","completed","failed","cancelled","retired","closed_unknown"]},"evidence":{"type":"string","enum":["none","local_before_dispatch","saved_intent","native_receipt","domain_status"]},"message":{"type":"string","maxLength":384},"cause":{"anyOf":[{"type":"string","maxLength":96},{"type":"null"}]},"identity":{"$ref":"https://transit.invalid/generated-validator/4"},"location":{"anyOf":[{"$ref":"https://transit.invalid/generated-validator/7"},{"type":"null"}]},"facts":{"type":"array","minItems":16,"maxItems":16,"items":{"anyOf":[{"type":"object","additionalProperties":false,"properties":{"field":{"type":"string","enum":["object","name","table","native_input","affected_rows","argument","option","permissions","scope","column","qualifier","constraint","key","input_row","first_occurrence","parameter","parameter_use","expected_count","actual_count","expected_type","actual_type","supplied_value","expected_value","expression","source_kind","source_basis","source_key","source_row","field_path","byte_offset","expected_resource","actual_resource","expected_source","actual_source","expected_revision","actual_revision","expected_schema","actual_schema","expected_policy","actual_policy","budget","limit","required","unit","completed_statements","emitted_rows","emitted_segments","completion","proposal","step","generation","attachment","lease","schema_origin","sampling_records","operation","native_cause","expected_bytes","presence","published","subscription","expected_codec","actual_codec","observed_clock","expected_namespace","actual_namespace","attempt","executor","resolution_reason","principal","deadline","authorization_policy","resolution_policy","protocol_status","native_effect","dependency","dependency_kind","dependency_owner"]},"origin":{"type":"string","enum":["caller","execution","schema","authority","owner"]},"availability":{"type":"string","enum":["provided","truncated","unrecorded","unavailable","withheld","inapplicable"]},"value":{"anyOf":[{"oneOf":[{"type":"object","additionalProperties":false,"required":["text"],"properties":{"text":{"type":"string","maxLength":256}}},{"type":"object","additionalProperties":false,"required":["signed"],"properties":{"signed":{"type":"string","maxLength":20,"pattern":"^(0|-?[1-9][0-9]*)$"}}},{"type":"object","additionalProperties":false,"required":["unsigned"],"properties":{"unsigned":{"$ref":"https://transit.invalid/generated-validator/1"}}},{"type":"object","additionalProperties":false,"required":["boolean"],"properties":{"boolean":{"type":"boolean"}}},{"type":"object","additionalProperties":false,"required":["digest"],"properties":{"digest":{"type":"array","minItems":32,"maxItems":32,"items":{"type":"integer","minimum":0,"maximum":255}}}},{"type":"object","additionalProperties":false,"required":["location"],"properties":{"location":{"$ref":"https://transit.invalid/generated-validator/7"}}}]},{"type":"null"}]}},"required":["field","origin","availability","value"]},{"type":"null"}]}},"actions":{"type":"array","minItems":4,"maxItems":4,"items":{"anyOf":[{"type":"object","additionalProperties":false,"properties":{"kind":{"type":"string","enum":["correct_input","inspect_status","resume_exact","cancel_wait","cancel_mutation","refresh","recompile","retry_read","inspect_scope","reconcile_effect","contact_operator"]},"target":{"$ref":"https://transit.invalid/generated-validator/4"}},"required":["kind","target"]},{"type":"null"}]}}},"required":["version","definition","code","category","stage","outcome","evidence","message","cause","identity","location","facts","actions"]};
const func1 = Object.prototype.hasOwnProperty;
const func2 = ucs2length;
const schema21 = {"anyOf":[{"$ref":"https://transit.invalid/generated-validator/3"},{"type":"null"}]};
const schema22 = {"type":"object","additionalProperties":false,"properties":{"domain":{"$ref":"https://transit.invalid/generated-validator/0"},"id":{"$ref":"https://transit.invalid/generated-validator/1"},"realm":{"$ref":"https://transit.invalid/generated-validator/2"},"resource":{"$ref":"https://transit.invalid/generated-validator/2"},"sequence":{"$ref":"https://transit.invalid/generated-validator/2"}},"required":["domain","id","realm","resource","sequence"]};
const schema23 = {"type":"string","enum":["sql","query","mutation","catalog","application","publication","migration","reactive","serving","effect","exchange","transport","internal"]};

function validate56(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate56.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate56.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
if(!(((((((((((((data === "sql") || (data === "query")) || (data === "mutation")) || (data === "catalog")) || (data === "application")) || (data === "publication")) || (data === "migration")) || (data === "reactive")) || (data === "serving")) || (data === "effect")) || (data === "exchange")) || (data === "transport")) || (data === "internal"))){
validate56.errors = [{instancePath,schemaPath:"#/enum",keyword:"enum",params:{allowedValues: schema23.enum},message:"must be equal to one of the allowed values"}];
return false;
}
validate56.errors = vErrors;
return errors === 0;
}
validate56.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema24 = {"type":"string","maxLength":20,"pattern":"^(0|[1-9][0-9]*)$"};
const pattern3 = new RegExp("^(0|[1-9][0-9]*)$", "u");

function validate58(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate58.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(typeof data === "string"){
if(func2(data) > 20){
validate58.errors = [{instancePath,schemaPath:"#/maxLength",keyword:"maxLength",params:{limit: 20},message:"must NOT have more than 20 characters"}];
return false;
}
else {
if(!pattern3.test(data)){
validate58.errors = [{instancePath,schemaPath:"#/pattern",keyword:"pattern",params:{pattern: "^(0|[1-9][0-9]*)$"},message:"must match pattern \""+"^(0|[1-9][0-9]*)$"+"\""}];
return false;
}
}
}
else {
validate58.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
}
validate58.errors = vErrors;
return errors === 0;
}
validate58.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema25 = {"anyOf":[{"$ref":"https://transit.invalid/generated-validator/1"},{"type":"null"}]};

function validate60(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate60.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate58(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate58.errors : vErrors.concat(validate58.errors);
errors = vErrors.length;
}
var _valid0 = _errs1 === errors;
valid0 = valid0 || _valid0;
const _errs2 = errors;
if(data !== null){
const err0 = {instancePath,schemaPath:"#/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err0];
}
else {
vErrors.push(err0);
}
errors++;
}
var _valid0 = _errs2 === errors;
valid0 = valid0 || _valid0;
if(!valid0){
const err1 = {instancePath,schemaPath:"#/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err1];
}
else {
vErrors.push(err1);
}
errors++;
validate60.errors = vErrors;
return false;
}
else {
errors = _errs0;
if(vErrors !== null){
if(_errs0){
vErrors.length = _errs0;
}
else {
vErrors = null;
}
}
}
validate60.errors = vErrors;
return errors === 0;
}
validate60.evaluated = {"dynamicProps":false,"dynamicItems":false};


function validate55(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate55.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((((((data.domain === undefined) && (missing0 = "domain")) || ((data.id === undefined) && (missing0 = "id"))) || ((data.realm === undefined) && (missing0 = "realm"))) || ((data.resource === undefined) && (missing0 = "resource"))) || ((data.sequence === undefined) && (missing0 = "sequence"))){
validate55.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((((key0 === "domain") || (key0 === "id")) || (key0 === "realm")) || (key0 === "resource")) || (key0 === "sequence"))){
validate55.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.domain !== undefined){
const _errs2 = errors;
if(!(validate56(data.domain, {instancePath:instancePath+"/domain",parentData:data,parentDataProperty:"domain",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.id !== undefined){
const _errs3 = errors;
if(!(validate58(data.id, {instancePath:instancePath+"/id",parentData:data,parentDataProperty:"id",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate58.errors : vErrors.concat(validate58.errors);
errors = vErrors.length;
}
var valid0 = _errs3 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.realm !== undefined){
const _errs4 = errors;
if(!(validate60(data.realm, {instancePath:instancePath+"/realm",parentData:data,parentDataProperty:"realm",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate60.errors : vErrors.concat(validate60.errors);
errors = vErrors.length;
}
var valid0 = _errs4 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.resource !== undefined){
const _errs5 = errors;
if(!(validate60(data.resource, {instancePath:instancePath+"/resource",parentData:data,parentDataProperty:"resource",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate60.errors : vErrors.concat(validate60.errors);
errors = vErrors.length;
}
var valid0 = _errs5 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.sequence !== undefined){
const _errs6 = errors;
if(!(validate60(data.sequence, {instancePath:instancePath+"/sequence",parentData:data,parentDataProperty:"sequence",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate60.errors : vErrors.concat(validate60.errors);
errors = vErrors.length;
}
var valid0 = _errs6 === errors;
}
else {
var valid0 = true;
}
}
}
}
}
}
}
}
else {
validate55.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate55.errors = vErrors;
return errors === 0;
}
validate55.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate54(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate54.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate55(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate55.errors : vErrors.concat(validate55.errors);
errors = vErrors.length;
}
var _valid0 = _errs1 === errors;
valid0 = valid0 || _valid0;
if(_valid0){
var props0 = true;
}
const _errs2 = errors;
if(data !== null){
const err0 = {instancePath,schemaPath:"#/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err0];
}
else {
vErrors.push(err0);
}
errors++;
}
var _valid0 = _errs2 === errors;
valid0 = valid0 || _valid0;
if(!valid0){
const err1 = {instancePath,schemaPath:"#/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err1];
}
else {
vErrors.push(err1);
}
errors++;
validate54.errors = vErrors;
return false;
}
else {
errors = _errs0;
if(vErrors !== null){
if(_errs0){
vErrors.length = _errs0;
}
else {
vErrors = null;
}
}
}
validate54.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate54.evaluated = {"dynamicProps":true,"dynamicItems":false};

const schema26 = {"type":"object","additionalProperties":false,"properties":{"source":{"$ref":"https://transit.invalid/generated-validator/5"},"source_encoding":{"$ref":"https://transit.invalid/generated-validator/6"},"source_truncated":{"type":"boolean"},"statement":{"$ref":"https://transit.invalid/generated-validator/2"},"offset":{"$ref":"https://transit.invalid/generated-validator/1"},"length":{"$ref":"https://transit.invalid/generated-validator/1"},"line":{"$ref":"https://transit.invalid/generated-validator/1"},"byte_column":{"$ref":"https://transit.invalid/generated-validator/1"}},"required":["source","source_encoding","source_truncated","statement","offset","length","line","byte_column"]};
const schema27 = {"anyOf":[{"type":"string","maxLength":512},{"type":"null"}]};

function validate68(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate68.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(errors === _errs1){
if(typeof data === "string"){
if(func2(data) > 512){
const err0 = {instancePath,schemaPath:"#/anyOf/0/maxLength",keyword:"maxLength",params:{limit: 512},message:"must NOT have more than 512 characters"};
if(vErrors === null){
vErrors = [err0];
}
else {
vErrors.push(err0);
}
errors++;
}
}
else {
const err1 = {instancePath,schemaPath:"#/anyOf/0/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err1];
}
else {
vErrors.push(err1);
}
errors++;
}
}
var _valid0 = _errs1 === errors;
valid0 = valid0 || _valid0;
const _errs3 = errors;
if(data !== null){
const err2 = {instancePath,schemaPath:"#/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err2];
}
else {
vErrors.push(err2);
}
errors++;
}
var _valid0 = _errs3 === errors;
valid0 = valid0 || _valid0;
if(!valid0){
const err3 = {instancePath,schemaPath:"#/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err3];
}
else {
vErrors.push(err3);
}
errors++;
validate68.errors = vErrors;
return false;
}
else {
errors = _errs0;
if(vErrors !== null){
if(_errs0){
vErrors.length = _errs0;
}
else {
vErrors = null;
}
}
}
validate68.errors = vErrors;
return errors === 0;
}
validate68.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema28 = {"type":"string","enum":["utf8","escaped_bytes"]};

function validate70(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate70.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate70.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
if(!((data === "utf8") || (data === "escaped_bytes"))){
validate70.errors = [{instancePath,schemaPath:"#/enum",keyword:"enum",params:{allowedValues: schema28.enum},message:"must be equal to one of the allowed values"}];
return false;
}
validate70.errors = vErrors;
return errors === 0;
}
validate70.evaluated = {"dynamicProps":false,"dynamicItems":false};


function validate67(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate67.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if(((((((((data.source === undefined) && (missing0 = "source")) || ((data.source_encoding === undefined) && (missing0 = "source_encoding"))) || ((data.source_truncated === undefined) && (missing0 = "source_truncated"))) || ((data.statement === undefined) && (missing0 = "statement"))) || ((data.offset === undefined) && (missing0 = "offset"))) || ((data.length === undefined) && (missing0 = "length"))) || ((data.line === undefined) && (missing0 = "line"))) || ((data.byte_column === undefined) && (missing0 = "byte_column"))){
validate67.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((((((((key0 === "source") || (key0 === "source_encoding")) || (key0 === "source_truncated")) || (key0 === "statement")) || (key0 === "offset")) || (key0 === "length")) || (key0 === "line")) || (key0 === "byte_column"))){
validate67.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.source !== undefined){
const _errs2 = errors;
if(!(validate68(data.source, {instancePath:instancePath+"/source",parentData:data,parentDataProperty:"source",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate68.errors : vErrors.concat(validate68.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.source_encoding !== undefined){
const _errs3 = errors;
if(!(validate70(data.source_encoding, {instancePath:instancePath+"/source_encoding",parentData:data,parentDataProperty:"source_encoding",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate70.errors : vErrors.concat(validate70.errors);
errors = vErrors.length;
}
var valid0 = _errs3 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.source_truncated !== undefined){
const _errs4 = errors;
if(typeof data.source_truncated !== "boolean"){
validate67.errors = [{instancePath:instancePath+"/source_truncated",schemaPath:"#/properties/source_truncated/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"}];
return false;
}
var valid0 = _errs4 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.statement !== undefined){
const _errs6 = errors;
if(!(validate60(data.statement, {instancePath:instancePath+"/statement",parentData:data,parentDataProperty:"statement",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate60.errors : vErrors.concat(validate60.errors);
errors = vErrors.length;
}
var valid0 = _errs6 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.offset !== undefined){
const _errs7 = errors;
if(!(validate58(data.offset, {instancePath:instancePath+"/offset",parentData:data,parentDataProperty:"offset",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate58.errors : vErrors.concat(validate58.errors);
errors = vErrors.length;
}
var valid0 = _errs7 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.length !== undefined){
const _errs8 = errors;
if(!(validate58(data.length, {instancePath:instancePath+"/length",parentData:data,parentDataProperty:"length",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate58.errors : vErrors.concat(validate58.errors);
errors = vErrors.length;
}
var valid0 = _errs8 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.line !== undefined){
const _errs9 = errors;
if(!(validate58(data.line, {instancePath:instancePath+"/line",parentData:data,parentDataProperty:"line",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate58.errors : vErrors.concat(validate58.errors);
errors = vErrors.length;
}
var valid0 = _errs9 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.byte_column !== undefined){
const _errs10 = errors;
if(!(validate58(data.byte_column, {instancePath:instancePath+"/byte_column",parentData:data,parentDataProperty:"byte_column",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate58.errors : vErrors.concat(validate58.errors);
errors = vErrors.length;
}
var valid0 = _errs10 === errors;
}
else {
var valid0 = true;
}
}
}
}
}
}
}
}
}
}
}
else {
validate67.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate67.errors = vErrors;
return errors === 0;
}
validate67.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const pattern4 = new RegExp("^(0|-?[1-9][0-9]*)$", "u");

function validate53(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate53.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((((((((((((((data.version === undefined) && (missing0 = "version")) || ((data.definition === undefined) && (missing0 = "definition"))) || ((data.code === undefined) && (missing0 = "code"))) || ((data.category === undefined) && (missing0 = "category"))) || ((data.stage === undefined) && (missing0 = "stage"))) || ((data.outcome === undefined) && (missing0 = "outcome"))) || ((data.evidence === undefined) && (missing0 = "evidence"))) || ((data.message === undefined) && (missing0 = "message"))) || ((data.cause === undefined) && (missing0 = "cause"))) || ((data.identity === undefined) && (missing0 = "identity"))) || ((data.location === undefined) && (missing0 = "location"))) || ((data.facts === undefined) && (missing0 = "facts"))) || ((data.actions === undefined) && (missing0 = "actions"))){
validate53.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(func1.call(schema20.properties, key0))){
validate53.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.version !== undefined){
const _errs2 = errors;
if(1 !== data.version){
validate53.errors = [{instancePath:instancePath+"/version",schemaPath:"#/properties/version/const",keyword:"const",params:{allowedValue: 1},message:"must be equal to constant"}];
return false;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.definition !== undefined){
let data1 = data.definition;
const _errs3 = errors;
if(typeof data1 !== "string"){
validate53.errors = [{instancePath:instancePath+"/definition",schemaPath:"#/properties/definition/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
if(!(data1 === "9438134d5552df1afc0043aab73220112135bc05c260525d7598f6ba694cc31b")){
validate53.errors = [{instancePath:instancePath+"/definition",schemaPath:"#/properties/definition/enum",keyword:"enum",params:{allowedValues: schema20.properties.definition.enum},message:"must be equal to one of the allowed values"}];
return false;
}
var valid0 = _errs3 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.code !== undefined){
let data2 = data.code;
const _errs5 = errors;
if(errors === _errs5){
if(typeof data2 === "string"){
if(func2(data2) > 96){
validate53.errors = [{instancePath:instancePath+"/code",schemaPath:"#/properties/code/maxLength",keyword:"maxLength",params:{limit: 96},message:"must NOT have more than 96 characters"}];
return false;
}
}
else {
validate53.errors = [{instancePath:instancePath+"/code",schemaPath:"#/properties/code/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
}
var valid0 = _errs5 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.category !== undefined){
let data3 = data.category;
const _errs7 = errors;
if(typeof data3 !== "string"){
validate53.errors = [{instancePath:instancePath+"/category",schemaPath:"#/properties/category/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
if(!(((((((((((data3 === "syntax") || (data3 === "binding")) || (data3 === "unsupported")) || (data3 === "constraint")) || (data3 === "access")) || (data3 === "conflict")) || (data3 === "limit")) || (data3 === "lifecycle")) || (data3 === "integrity")) || (data3 === "unavailable")) || (data3 === "internal"))){
validate53.errors = [{instancePath:instancePath+"/category",schemaPath:"#/properties/category/enum",keyword:"enum",params:{allowedValues: schema20.properties.category.enum},message:"must be equal to one of the allowed values"}];
return false;
}
var valid0 = _errs7 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.stage !== undefined){
let data4 = data.stage;
const _errs9 = errors;
if(typeof data4 !== "string"){
validate53.errors = [{instancePath:instancePath+"/stage",schemaPath:"#/properties/stage/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
if(!((((((((((((((data4 === "input") || (data4 === "parse")) || (data4 === "compile")) || (data4 === "bind")) || (data4 === "prepare")) || (data4 === "submit")) || (data4 === "admission")) || (data4 === "execute")) || (data4 === "read")) || (data4 === "decode")) || (data4 === "output")) || (data4 === "reconcile")) || (data4 === "cleanup")) || (data4 === "control"))){
validate53.errors = [{instancePath:instancePath+"/stage",schemaPath:"#/properties/stage/enum",keyword:"enum",params:{allowedValues: schema20.properties.stage.enum},message:"must be equal to one of the allowed values"}];
return false;
}
var valid0 = _errs9 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.outcome !== undefined){
let data5 = data.outcome;
const _errs11 = errors;
if(typeof data5 !== "string"){
validate53.errors = [{instancePath:instancePath+"/outcome",schemaPath:"#/properties/outcome/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
if(!((((((((((((((data5 === "not_applicable") || (data5 === "not_submitted")) || (data5 === "not_dispatched")) || (data5 === "prepared")) || (data5 === "unknown")) || (data5 === "pending")) || (data5 === "input_rejected")) || (data5 === "rejected")) || (data5 === "applied")) || (data5 === "completed")) || (data5 === "failed")) || (data5 === "cancelled")) || (data5 === "retired")) || (data5 === "closed_unknown"))){
validate53.errors = [{instancePath:instancePath+"/outcome",schemaPath:"#/properties/outcome/enum",keyword:"enum",params:{allowedValues: schema20.properties.outcome.enum},message:"must be equal to one of the allowed values"}];
return false;
}
var valid0 = _errs11 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.evidence !== undefined){
let data6 = data.evidence;
const _errs13 = errors;
if(typeof data6 !== "string"){
validate53.errors = [{instancePath:instancePath+"/evidence",schemaPath:"#/properties/evidence/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
if(!(((((data6 === "none") || (data6 === "local_before_dispatch")) || (data6 === "saved_intent")) || (data6 === "native_receipt")) || (data6 === "domain_status"))){
validate53.errors = [{instancePath:instancePath+"/evidence",schemaPath:"#/properties/evidence/enum",keyword:"enum",params:{allowedValues: schema20.properties.evidence.enum},message:"must be equal to one of the allowed values"}];
return false;
}
var valid0 = _errs13 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.message !== undefined){
let data7 = data.message;
const _errs15 = errors;
if(errors === _errs15){
if(typeof data7 === "string"){
if(func2(data7) > 384){
validate53.errors = [{instancePath:instancePath+"/message",schemaPath:"#/properties/message/maxLength",keyword:"maxLength",params:{limit: 384},message:"must NOT have more than 384 characters"}];
return false;
}
}
else {
validate53.errors = [{instancePath:instancePath+"/message",schemaPath:"#/properties/message/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
}
var valid0 = _errs15 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.cause !== undefined){
let data8 = data.cause;
const _errs17 = errors;
const _errs18 = errors;
let valid1 = false;
const _errs19 = errors;
if(errors === _errs19){
if(typeof data8 === "string"){
if(func2(data8) > 96){
const err0 = {instancePath:instancePath+"/cause",schemaPath:"#/properties/cause/anyOf/0/maxLength",keyword:"maxLength",params:{limit: 96},message:"must NOT have more than 96 characters"};
if(vErrors === null){
vErrors = [err0];
}
else {
vErrors.push(err0);
}
errors++;
}
}
else {
const err1 = {instancePath:instancePath+"/cause",schemaPath:"#/properties/cause/anyOf/0/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err1];
}
else {
vErrors.push(err1);
}
errors++;
}
}
var _valid0 = _errs19 === errors;
valid1 = valid1 || _valid0;
const _errs21 = errors;
if(data8 !== null){
const err2 = {instancePath:instancePath+"/cause",schemaPath:"#/properties/cause/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err2];
}
else {
vErrors.push(err2);
}
errors++;
}
var _valid0 = _errs21 === errors;
valid1 = valid1 || _valid0;
if(!valid1){
const err3 = {instancePath:instancePath+"/cause",schemaPath:"#/properties/cause/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err3];
}
else {
vErrors.push(err3);
}
errors++;
validate53.errors = vErrors;
return false;
}
else {
errors = _errs18;
if(vErrors !== null){
if(_errs18){
vErrors.length = _errs18;
}
else {
vErrors = null;
}
}
}
var valid0 = _errs17 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.identity !== undefined){
const _errs23 = errors;
if(!(validate54(data.identity, {instancePath:instancePath+"/identity",parentData:data,parentDataProperty:"identity",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate54.errors : vErrors.concat(validate54.errors);
errors = vErrors.length;
}
var valid0 = _errs23 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.location !== undefined){
let data10 = data.location;
const _errs24 = errors;
const _errs25 = errors;
let valid2 = false;
const _errs26 = errors;
if(!(validate67(data10, {instancePath:instancePath+"/location",parentData:data,parentDataProperty:"location",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate67.errors : vErrors.concat(validate67.errors);
errors = vErrors.length;
}
var _valid1 = _errs26 === errors;
valid2 = valid2 || _valid1;
const _errs27 = errors;
if(data10 !== null){
const err4 = {instancePath:instancePath+"/location",schemaPath:"#/properties/location/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err4];
}
else {
vErrors.push(err4);
}
errors++;
}
var _valid1 = _errs27 === errors;
valid2 = valid2 || _valid1;
if(!valid2){
const err5 = {instancePath:instancePath+"/location",schemaPath:"#/properties/location/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err5];
}
else {
vErrors.push(err5);
}
errors++;
validate53.errors = vErrors;
return false;
}
else {
errors = _errs25;
if(vErrors !== null){
if(_errs25){
vErrors.length = _errs25;
}
else {
vErrors = null;
}
}
}
var valid0 = _errs24 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.facts !== undefined){
let data11 = data.facts;
const _errs29 = errors;
if(errors === _errs29){
if(Array.isArray(data11)){
if(data11.length > 16){
validate53.errors = [{instancePath:instancePath+"/facts",schemaPath:"#/properties/facts/maxItems",keyword:"maxItems",params:{limit: 16},message:"must NOT have more than 16 items"}];
return false;
}
else {
if(data11.length < 16){
validate53.errors = [{instancePath:instancePath+"/facts",schemaPath:"#/properties/facts/minItems",keyword:"minItems",params:{limit: 16},message:"must NOT have fewer than 16 items"}];
return false;
}
else {
var valid3 = true;
const len0 = data11.length;
for(let i0=0; i0<len0; i0++){
let data12 = data11[i0];
const _errs31 = errors;
const _errs32 = errors;
let valid4 = false;
const _errs33 = errors;
if(errors === _errs33){
if(data12 && typeof data12 == "object" && !Array.isArray(data12)){
let missing1;
if(((((data12.field === undefined) && (missing1 = "field")) || ((data12.origin === undefined) && (missing1 = "origin"))) || ((data12.availability === undefined) && (missing1 = "availability"))) || ((data12.value === undefined) && (missing1 = "value"))){
const err6 = {instancePath:instancePath+"/facts/" + i0,schemaPath:"#/properties/facts/items/anyOf/0/required",keyword:"required",params:{missingProperty: missing1},message:"must have required property '"+missing1+"'"};
if(vErrors === null){
vErrors = [err6];
}
else {
vErrors.push(err6);
}
errors++;
}
else {
const _errs35 = errors;
for(const key1 in data12){
if(!((((key1 === "field") || (key1 === "origin")) || (key1 === "availability")) || (key1 === "value"))){
const err7 = {instancePath:instancePath+"/facts/" + i0,schemaPath:"#/properties/facts/items/anyOf/0/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key1},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err7];
}
else {
vErrors.push(err7);
}
errors++;
break;
}
}
if(_errs35 === errors){
if(data12.field !== undefined){
let data13 = data12.field;
const _errs36 = errors;
if(typeof data13 !== "string"){
const err8 = {instancePath:instancePath+"/facts/" + i0+"/field",schemaPath:"#/properties/facts/items/anyOf/0/properties/field/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err8];
}
else {
vErrors.push(err8);
}
errors++;
}
if(!((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((data13 === "object") || (data13 === "name")) || (data13 === "table")) || (data13 === "native_input")) || (data13 === "affected_rows")) || (data13 === "argument")) || (data13 === "option")) || (data13 === "permissions")) || (data13 === "scope")) || (data13 === "column")) || (data13 === "qualifier")) || (data13 === "constraint")) || (data13 === "key")) || (data13 === "input_row")) || (data13 === "first_occurrence")) || (data13 === "parameter")) || (data13 === "parameter_use")) || (data13 === "expected_count")) || (data13 === "actual_count")) || (data13 === "expected_type")) || (data13 === "actual_type")) || (data13 === "supplied_value")) || (data13 === "expected_value")) || (data13 === "expression")) || (data13 === "source_kind")) || (data13 === "source_basis")) || (data13 === "source_key")) || (data13 === "source_row")) || (data13 === "field_path")) || (data13 === "byte_offset")) || (data13 === "expected_resource")) || (data13 === "actual_resource")) || (data13 === "expected_source")) || (data13 === "actual_source")) || (data13 === "expected_revision")) || (data13 === "actual_revision")) || (data13 === "expected_schema")) || (data13 === "actual_schema")) || (data13 === "expected_policy")) || (data13 === "actual_policy")) || (data13 === "budget")) || (data13 === "limit")) || (data13 === "required")) || (data13 === "unit")) || (data13 === "completed_statements")) || (data13 === "emitted_rows")) || (data13 === "emitted_segments")) || (data13 === "completion")) || (data13 === "proposal")) || (data13 === "step")) || (data13 === "generation")) || (data13 === "attachment")) || (data13 === "lease")) || (data13 === "schema_origin")) || (data13 === "sampling_records")) || (data13 === "operation")) || (data13 === "native_cause")) || (data13 === "expected_bytes")) || (data13 === "presence")) || (data13 === "published")) || (data13 === "subscription")) || (data13 === "expected_codec")) || (data13 === "actual_codec")) || (data13 === "observed_clock")) || (data13 === "expected_namespace")) || (data13 === "actual_namespace")) || (data13 === "attempt")) || (data13 === "executor")) || (data13 === "resolution_reason")) || (data13 === "principal")) || (data13 === "deadline")) || (data13 === "authorization_policy")) || (data13 === "resolution_policy")) || (data13 === "protocol_status")) || (data13 === "native_effect")) || (data13 === "dependency")) || (data13 === "dependency_kind")) || (data13 === "dependency_owner"))){
const err9 = {instancePath:instancePath+"/facts/" + i0+"/field",schemaPath:"#/properties/facts/items/anyOf/0/properties/field/enum",keyword:"enum",params:{allowedValues: schema20.properties.facts.items.anyOf[0].properties.field.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err9];
}
else {
vErrors.push(err9);
}
errors++;
}
var valid5 = _errs36 === errors;
}
else {
var valid5 = true;
}
if(valid5){
if(data12.origin !== undefined){
let data14 = data12.origin;
const _errs38 = errors;
if(typeof data14 !== "string"){
const err10 = {instancePath:instancePath+"/facts/" + i0+"/origin",schemaPath:"#/properties/facts/items/anyOf/0/properties/origin/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err10];
}
else {
vErrors.push(err10);
}
errors++;
}
if(!(((((data14 === "caller") || (data14 === "execution")) || (data14 === "schema")) || (data14 === "authority")) || (data14 === "owner"))){
const err11 = {instancePath:instancePath+"/facts/" + i0+"/origin",schemaPath:"#/properties/facts/items/anyOf/0/properties/origin/enum",keyword:"enum",params:{allowedValues: schema20.properties.facts.items.anyOf[0].properties.origin.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err11];
}
else {
vErrors.push(err11);
}
errors++;
}
var valid5 = _errs38 === errors;
}
else {
var valid5 = true;
}
if(valid5){
if(data12.availability !== undefined){
let data15 = data12.availability;
const _errs40 = errors;
if(typeof data15 !== "string"){
const err12 = {instancePath:instancePath+"/facts/" + i0+"/availability",schemaPath:"#/properties/facts/items/anyOf/0/properties/availability/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err12];
}
else {
vErrors.push(err12);
}
errors++;
}
if(!((((((data15 === "provided") || (data15 === "truncated")) || (data15 === "unrecorded")) || (data15 === "unavailable")) || (data15 === "withheld")) || (data15 === "inapplicable"))){
const err13 = {instancePath:instancePath+"/facts/" + i0+"/availability",schemaPath:"#/properties/facts/items/anyOf/0/properties/availability/enum",keyword:"enum",params:{allowedValues: schema20.properties.facts.items.anyOf[0].properties.availability.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err13];
}
else {
vErrors.push(err13);
}
errors++;
}
var valid5 = _errs40 === errors;
}
else {
var valid5 = true;
}
if(valid5){
if(data12.value !== undefined){
let data16 = data12.value;
const _errs42 = errors;
const _errs43 = errors;
let valid6 = false;
const _errs44 = errors;
const _errs45 = errors;
let valid7 = false;
let passing0 = null;
const _errs46 = errors;
if(errors === _errs46){
if(data16 && typeof data16 == "object" && !Array.isArray(data16)){
let missing2;
if((data16.text === undefined) && (missing2 = "text")){
const err14 = {instancePath:instancePath+"/facts/" + i0+"/value",schemaPath:"#/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/0/required",keyword:"required",params:{missingProperty: missing2},message:"must have required property '"+missing2+"'"};
if(vErrors === null){
vErrors = [err14];
}
else {
vErrors.push(err14);
}
errors++;
}
else {
const _errs48 = errors;
for(const key2 in data16){
if(!(key2 === "text")){
const err15 = {instancePath:instancePath+"/facts/" + i0+"/value",schemaPath:"#/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/0/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key2},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err15];
}
else {
vErrors.push(err15);
}
errors++;
break;
}
}
if(_errs48 === errors){
if(data16.text !== undefined){
let data17 = data16.text;
const _errs49 = errors;
if(errors === _errs49){
if(typeof data17 === "string"){
if(func2(data17) > 256){
const err16 = {instancePath:instancePath+"/facts/" + i0+"/value/text",schemaPath:"#/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/0/properties/text/maxLength",keyword:"maxLength",params:{limit: 256},message:"must NOT have more than 256 characters"};
if(vErrors === null){
vErrors = [err16];
}
else {
vErrors.push(err16);
}
errors++;
}
}
else {
const err17 = {instancePath:instancePath+"/facts/" + i0+"/value/text",schemaPath:"#/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/0/properties/text/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err17];
}
else {
vErrors.push(err17);
}
errors++;
}
}
}
}
}
}
else {
const err18 = {instancePath:instancePath+"/facts/" + i0+"/value",schemaPath:"#/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err18];
}
else {
vErrors.push(err18);
}
errors++;
}
}
var _valid4 = _errs46 === errors;
if(_valid4){
valid7 = true;
passing0 = 0;
var props2 = true;
}
const _errs51 = errors;
if(errors === _errs51){
if(data16 && typeof data16 == "object" && !Array.isArray(data16)){
let missing3;
if((data16.signed === undefined) && (missing3 = "signed")){
const err19 = {instancePath:instancePath+"/facts/" + i0+"/value",schemaPath:"#/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/1/required",keyword:"required",params:{missingProperty: missing3},message:"must have required property '"+missing3+"'"};
if(vErrors === null){
vErrors = [err19];
}
else {
vErrors.push(err19);
}
errors++;
}
else {
const _errs53 = errors;
for(const key3 in data16){
if(!(key3 === "signed")){
const err20 = {instancePath:instancePath+"/facts/" + i0+"/value",schemaPath:"#/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/1/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key3},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err20];
}
else {
vErrors.push(err20);
}
errors++;
break;
}
}
if(_errs53 === errors){
if(data16.signed !== undefined){
let data18 = data16.signed;
const _errs54 = errors;
if(errors === _errs54){
if(typeof data18 === "string"){
if(func2(data18) > 20){
const err21 = {instancePath:instancePath+"/facts/" + i0+"/value/signed",schemaPath:"#/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/1/properties/signed/maxLength",keyword:"maxLength",params:{limit: 20},message:"must NOT have more than 20 characters"};
if(vErrors === null){
vErrors = [err21];
}
else {
vErrors.push(err21);
}
errors++;
}
else {
if(!pattern4.test(data18)){
const err22 = {instancePath:instancePath+"/facts/" + i0+"/value/signed",schemaPath:"#/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/1/properties/signed/pattern",keyword:"pattern",params:{pattern: "^(0|-?[1-9][0-9]*)$"},message:"must match pattern \""+"^(0|-?[1-9][0-9]*)$"+"\""};
if(vErrors === null){
vErrors = [err22];
}
else {
vErrors.push(err22);
}
errors++;
}
}
}
else {
const err23 = {instancePath:instancePath+"/facts/" + i0+"/value/signed",schemaPath:"#/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/1/properties/signed/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err23];
}
else {
vErrors.push(err23);
}
errors++;
}
}
}
}
}
}
else {
const err24 = {instancePath:instancePath+"/facts/" + i0+"/value",schemaPath:"#/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/1/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err24];
}
else {
vErrors.push(err24);
}
errors++;
}
}
var _valid4 = _errs51 === errors;
if(_valid4 && valid7){
valid7 = false;
passing0 = [passing0, 1];
}
else {
if(_valid4){
valid7 = true;
passing0 = 1;
if(props2 !== true){
props2 = true;
}
}
const _errs56 = errors;
if(errors === _errs56){
if(data16 && typeof data16 == "object" && !Array.isArray(data16)){
let missing4;
if((data16.unsigned === undefined) && (missing4 = "unsigned")){
const err25 = {instancePath:instancePath+"/facts/" + i0+"/value",schemaPath:"#/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/2/required",keyword:"required",params:{missingProperty: missing4},message:"must have required property '"+missing4+"'"};
if(vErrors === null){
vErrors = [err25];
}
else {
vErrors.push(err25);
}
errors++;
}
else {
const _errs58 = errors;
for(const key4 in data16){
if(!(key4 === "unsigned")){
const err26 = {instancePath:instancePath+"/facts/" + i0+"/value",schemaPath:"#/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/2/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key4},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err26];
}
else {
vErrors.push(err26);
}
errors++;
break;
}
}
if(_errs58 === errors){
if(data16.unsigned !== undefined){
if(!(validate58(data16.unsigned, {instancePath:instancePath+"/facts/" + i0+"/value/unsigned",parentData:data16,parentDataProperty:"unsigned",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate58.errors : vErrors.concat(validate58.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err27 = {instancePath:instancePath+"/facts/" + i0+"/value",schemaPath:"#/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/2/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err27];
}
else {
vErrors.push(err27);
}
errors++;
}
}
var _valid4 = _errs56 === errors;
if(_valid4 && valid7){
valid7 = false;
passing0 = [passing0, 2];
}
else {
if(_valid4){
valid7 = true;
passing0 = 2;
if(props2 !== true){
props2 = true;
}
}
const _errs60 = errors;
if(errors === _errs60){
if(data16 && typeof data16 == "object" && !Array.isArray(data16)){
let missing5;
if((data16.boolean === undefined) && (missing5 = "boolean")){
const err28 = {instancePath:instancePath+"/facts/" + i0+"/value",schemaPath:"#/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/3/required",keyword:"required",params:{missingProperty: missing5},message:"must have required property '"+missing5+"'"};
if(vErrors === null){
vErrors = [err28];
}
else {
vErrors.push(err28);
}
errors++;
}
else {
const _errs62 = errors;
for(const key5 in data16){
if(!(key5 === "boolean")){
const err29 = {instancePath:instancePath+"/facts/" + i0+"/value",schemaPath:"#/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/3/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key5},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err29];
}
else {
vErrors.push(err29);
}
errors++;
break;
}
}
if(_errs62 === errors){
if(data16.boolean !== undefined){
if(typeof data16.boolean !== "boolean"){
const err30 = {instancePath:instancePath+"/facts/" + i0+"/value/boolean",schemaPath:"#/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/3/properties/boolean/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"};
if(vErrors === null){
vErrors = [err30];
}
else {
vErrors.push(err30);
}
errors++;
}
}
}
}
}
else {
const err31 = {instancePath:instancePath+"/facts/" + i0+"/value",schemaPath:"#/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/3/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err31];
}
else {
vErrors.push(err31);
}
errors++;
}
}
var _valid4 = _errs60 === errors;
if(_valid4 && valid7){
valid7 = false;
passing0 = [passing0, 3];
}
else {
if(_valid4){
valid7 = true;
passing0 = 3;
if(props2 !== true){
props2 = true;
}
}
const _errs65 = errors;
if(errors === _errs65){
if(data16 && typeof data16 == "object" && !Array.isArray(data16)){
let missing6;
if((data16.digest === undefined) && (missing6 = "digest")){
const err32 = {instancePath:instancePath+"/facts/" + i0+"/value",schemaPath:"#/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/4/required",keyword:"required",params:{missingProperty: missing6},message:"must have required property '"+missing6+"'"};
if(vErrors === null){
vErrors = [err32];
}
else {
vErrors.push(err32);
}
errors++;
}
else {
const _errs67 = errors;
for(const key6 in data16){
if(!(key6 === "digest")){
const err33 = {instancePath:instancePath+"/facts/" + i0+"/value",schemaPath:"#/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/4/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key6},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err33];
}
else {
vErrors.push(err33);
}
errors++;
break;
}
}
if(_errs67 === errors){
if(data16.digest !== undefined){
let data21 = data16.digest;
const _errs68 = errors;
if(errors === _errs68){
if(Array.isArray(data21)){
if(data21.length > 32){
const err34 = {instancePath:instancePath+"/facts/" + i0+"/value/digest",schemaPath:"#/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/4/properties/digest/maxItems",keyword:"maxItems",params:{limit: 32},message:"must NOT have more than 32 items"};
if(vErrors === null){
vErrors = [err34];
}
else {
vErrors.push(err34);
}
errors++;
}
else {
if(data21.length < 32){
const err35 = {instancePath:instancePath+"/facts/" + i0+"/value/digest",schemaPath:"#/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/4/properties/digest/minItems",keyword:"minItems",params:{limit: 32},message:"must NOT have fewer than 32 items"};
if(vErrors === null){
vErrors = [err35];
}
else {
vErrors.push(err35);
}
errors++;
}
else {
var valid13 = true;
const len1 = data21.length;
for(let i1=0; i1<len1; i1++){
let data22 = data21[i1];
const _errs70 = errors;
if(!(((typeof data22 == "number") && (!(data22 % 1) && !isNaN(data22))) && (isFinite(data22)))){
const err36 = {instancePath:instancePath+"/facts/" + i0+"/value/digest/" + i1,schemaPath:"#/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/4/properties/digest/items/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err36];
}
else {
vErrors.push(err36);
}
errors++;
}
if(errors === _errs70){
if((typeof data22 == "number") && (isFinite(data22))){
if(data22 > 255 || isNaN(data22)){
const err37 = {instancePath:instancePath+"/facts/" + i0+"/value/digest/" + i1,schemaPath:"#/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/4/properties/digest/items/maximum",keyword:"maximum",params:{comparison: "<=", limit: 255},message:"must be <= 255"};
if(vErrors === null){
vErrors = [err37];
}
else {
vErrors.push(err37);
}
errors++;
}
else {
if(data22 < 0 || isNaN(data22)){
const err38 = {instancePath:instancePath+"/facts/" + i0+"/value/digest/" + i1,schemaPath:"#/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/4/properties/digest/items/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err38];
}
else {
vErrors.push(err38);
}
errors++;
}
}
}
}
var valid13 = _errs70 === errors;
if(!valid13){
break;
}
}
}
}
}
else {
const err39 = {instancePath:instancePath+"/facts/" + i0+"/value/digest",schemaPath:"#/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/4/properties/digest/type",keyword:"type",params:{type: "array"},message:"must be array"};
if(vErrors === null){
vErrors = [err39];
}
else {
vErrors.push(err39);
}
errors++;
}
}
}
}
}
}
else {
const err40 = {instancePath:instancePath+"/facts/" + i0+"/value",schemaPath:"#/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/4/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err40];
}
else {
vErrors.push(err40);
}
errors++;
}
}
var _valid4 = _errs65 === errors;
if(_valid4 && valid7){
valid7 = false;
passing0 = [passing0, 4];
}
else {
if(_valid4){
valid7 = true;
passing0 = 4;
if(props2 !== true){
props2 = true;
}
}
const _errs72 = errors;
if(errors === _errs72){
if(data16 && typeof data16 == "object" && !Array.isArray(data16)){
let missing7;
if((data16.location === undefined) && (missing7 = "location")){
const err41 = {instancePath:instancePath+"/facts/" + i0+"/value",schemaPath:"#/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/5/required",keyword:"required",params:{missingProperty: missing7},message:"must have required property '"+missing7+"'"};
if(vErrors === null){
vErrors = [err41];
}
else {
vErrors.push(err41);
}
errors++;
}
else {
const _errs74 = errors;
for(const key7 in data16){
if(!(key7 === "location")){
const err42 = {instancePath:instancePath+"/facts/" + i0+"/value",schemaPath:"#/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/5/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key7},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err42];
}
else {
vErrors.push(err42);
}
errors++;
break;
}
}
if(_errs74 === errors){
if(data16.location !== undefined){
if(!(validate67(data16.location, {instancePath:instancePath+"/facts/" + i0+"/value/location",parentData:data16,parentDataProperty:"location",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate67.errors : vErrors.concat(validate67.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err43 = {instancePath:instancePath+"/facts/" + i0+"/value",schemaPath:"#/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/5/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err43];
}
else {
vErrors.push(err43);
}
errors++;
}
}
var _valid4 = _errs72 === errors;
if(_valid4 && valid7){
valid7 = false;
passing0 = [passing0, 5];
}
else {
if(_valid4){
valid7 = true;
passing0 = 5;
if(props2 !== true){
props2 = true;
}
}
}
}
}
}
}
if(!valid7){
const err44 = {instancePath:instancePath+"/facts/" + i0+"/value",schemaPath:"#/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf",keyword:"oneOf",params:{passingSchemas: passing0},message:"must match exactly one schema in oneOf"};
if(vErrors === null){
vErrors = [err44];
}
else {
vErrors.push(err44);
}
errors++;
}
else {
errors = _errs45;
if(vErrors !== null){
if(_errs45){
vErrors.length = _errs45;
}
else {
vErrors = null;
}
}
}
var _valid3 = _errs44 === errors;
valid6 = valid6 || _valid3;
const _errs76 = errors;
if(data16 !== null){
const err45 = {instancePath:instancePath+"/facts/" + i0+"/value",schemaPath:"#/properties/facts/items/anyOf/0/properties/value/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err45];
}
else {
vErrors.push(err45);
}
errors++;
}
var _valid3 = _errs76 === errors;
valid6 = valid6 || _valid3;
if(!valid6){
const err46 = {instancePath:instancePath+"/facts/" + i0+"/value",schemaPath:"#/properties/facts/items/anyOf/0/properties/value/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err46];
}
else {
vErrors.push(err46);
}
errors++;
}
else {
errors = _errs43;
if(vErrors !== null){
if(_errs43){
vErrors.length = _errs43;
}
else {
vErrors = null;
}
}
}
var valid5 = _errs42 === errors;
}
else {
var valid5 = true;
}
}
}
}
}
}
}
else {
const err47 = {instancePath:instancePath+"/facts/" + i0,schemaPath:"#/properties/facts/items/anyOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err47];
}
else {
vErrors.push(err47);
}
errors++;
}
}
var _valid2 = _errs33 === errors;
valid4 = valid4 || _valid2;
const _errs78 = errors;
if(data12 !== null){
const err48 = {instancePath:instancePath+"/facts/" + i0,schemaPath:"#/properties/facts/items/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err48];
}
else {
vErrors.push(err48);
}
errors++;
}
var _valid2 = _errs78 === errors;
valid4 = valid4 || _valid2;
if(!valid4){
const err49 = {instancePath:instancePath+"/facts/" + i0,schemaPath:"#/properties/facts/items/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err49];
}
else {
vErrors.push(err49);
}
errors++;
validate53.errors = vErrors;
return false;
}
else {
errors = _errs32;
if(vErrors !== null){
if(_errs32){
vErrors.length = _errs32;
}
else {
vErrors = null;
}
}
}
var valid3 = _errs31 === errors;
if(!valid3){
break;
}
}
}
}
}
else {
validate53.errors = [{instancePath:instancePath+"/facts",schemaPath:"#/properties/facts/type",keyword:"type",params:{type: "array"},message:"must be array"}];
return false;
}
}
var valid0 = _errs29 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.actions !== undefined){
let data24 = data.actions;
const _errs80 = errors;
if(errors === _errs80){
if(Array.isArray(data24)){
if(data24.length > 4){
validate53.errors = [{instancePath:instancePath+"/actions",schemaPath:"#/properties/actions/maxItems",keyword:"maxItems",params:{limit: 4},message:"must NOT have more than 4 items"}];
return false;
}
else {
if(data24.length < 4){
validate53.errors = [{instancePath:instancePath+"/actions",schemaPath:"#/properties/actions/minItems",keyword:"minItems",params:{limit: 4},message:"must NOT have fewer than 4 items"}];
return false;
}
else {
var valid15 = true;
const len2 = data24.length;
for(let i2=0; i2<len2; i2++){
let data25 = data24[i2];
const _errs82 = errors;
const _errs83 = errors;
let valid16 = false;
const _errs84 = errors;
if(errors === _errs84){
if(data25 && typeof data25 == "object" && !Array.isArray(data25)){
let missing8;
if(((data25.kind === undefined) && (missing8 = "kind")) || ((data25.target === undefined) && (missing8 = "target"))){
const err50 = {instancePath:instancePath+"/actions/" + i2,schemaPath:"#/properties/actions/items/anyOf/0/required",keyword:"required",params:{missingProperty: missing8},message:"must have required property '"+missing8+"'"};
if(vErrors === null){
vErrors = [err50];
}
else {
vErrors.push(err50);
}
errors++;
}
else {
const _errs86 = errors;
for(const key8 in data25){
if(!((key8 === "kind") || (key8 === "target"))){
const err51 = {instancePath:instancePath+"/actions/" + i2,schemaPath:"#/properties/actions/items/anyOf/0/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key8},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err51];
}
else {
vErrors.push(err51);
}
errors++;
break;
}
}
if(_errs86 === errors){
if(data25.kind !== undefined){
let data26 = data25.kind;
const _errs87 = errors;
if(typeof data26 !== "string"){
const err52 = {instancePath:instancePath+"/actions/" + i2+"/kind",schemaPath:"#/properties/actions/items/anyOf/0/properties/kind/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err52];
}
else {
vErrors.push(err52);
}
errors++;
}
if(!(((((((((((data26 === "correct_input") || (data26 === "inspect_status")) || (data26 === "resume_exact")) || (data26 === "cancel_wait")) || (data26 === "cancel_mutation")) || (data26 === "refresh")) || (data26 === "recompile")) || (data26 === "retry_read")) || (data26 === "inspect_scope")) || (data26 === "reconcile_effect")) || (data26 === "contact_operator"))){
const err53 = {instancePath:instancePath+"/actions/" + i2+"/kind",schemaPath:"#/properties/actions/items/anyOf/0/properties/kind/enum",keyword:"enum",params:{allowedValues: schema20.properties.actions.items.anyOf[0].properties.kind.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err53];
}
else {
vErrors.push(err53);
}
errors++;
}
var valid17 = _errs87 === errors;
}
else {
var valid17 = true;
}
if(valid17){
if(data25.target !== undefined){
const _errs89 = errors;
if(!(validate54(data25.target, {instancePath:instancePath+"/actions/" + i2+"/target",parentData:data25,parentDataProperty:"target",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate54.errors : vErrors.concat(validate54.errors);
errors = vErrors.length;
}
var valid17 = _errs89 === errors;
}
else {
var valid17 = true;
}
}
}
}
}
else {
const err54 = {instancePath:instancePath+"/actions/" + i2,schemaPath:"#/properties/actions/items/anyOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err54];
}
else {
vErrors.push(err54);
}
errors++;
}
}
var _valid5 = _errs84 === errors;
valid16 = valid16 || _valid5;
const _errs90 = errors;
if(data25 !== null){
const err55 = {instancePath:instancePath+"/actions/" + i2,schemaPath:"#/properties/actions/items/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err55];
}
else {
vErrors.push(err55);
}
errors++;
}
var _valid5 = _errs90 === errors;
valid16 = valid16 || _valid5;
if(!valid16){
const err56 = {instancePath:instancePath+"/actions/" + i2,schemaPath:"#/properties/actions/items/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err56];
}
else {
vErrors.push(err56);
}
errors++;
validate53.errors = vErrors;
return false;
}
else {
errors = _errs83;
if(vErrors !== null){
if(_errs83){
vErrors.length = _errs83;
}
else {
vErrors = null;
}
}
}
var valid15 = _errs82 === errors;
if(!valid15){
break;
}
}
}
}
}
else {
validate53.errors = [{instancePath:instancePath+"/actions",schemaPath:"#/properties/actions/type",keyword:"type",params:{type: "array"},message:"must be array"}];
return false;
}
}
var valid0 = _errs80 === errors;
}
else {
var valid0 = true;
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
else {
validate53.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate53.errors = vErrors;
return errors === 0;
}
validate53.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};
