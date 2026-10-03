// Generated; no runtime code generation or eval.
import lengthModule from "ajv/dist/runtime/ucs2length.js";
const ucs2length = lengthModule.default ?? lengthModule;
"use strict";
export const Diagnostic = validate21;
const schema32 = {"type":"object","additionalProperties":false,"properties":{"version":{"const":1},"definition":{"type":"string","enum":["4dab48676c92875019edb9a3c8e3e6e9071ebfe22000fe513c5efe66b16734f6"]},"code":{"type":"string","maxLength":96},"category":{"type":"string","enum":["syntax","binding","unsupported","constraint","access","conflict","limit","lifecycle","integrity","unavailable","internal"]},"stage":{"type":"string","enum":["input","parse","compile","bind","prepare","submit","admission","execute","read","decode","output","reconcile","cleanup","control"]},"outcome":{"type":"string","enum":["not_applicable","not_submitted","not_dispatched","prepared","unknown","pending","input_rejected","rejected","applied","completed","failed","cancelled","retired","closed_unknown"]},"evidence":{"type":"string","enum":["none","local_before_dispatch","saved_intent","native_receipt","domain_status"]},"message":{"type":"string","maxLength":384},"cause":{"anyOf":[{"type":"string","maxLength":96},{"type":"null"}]},"identity":{"anyOf":[{"type":"object","additionalProperties":false,"properties":{"domain":{"type":"string","enum":["sql","query","mutation","catalog","application","publication","migration","reactive","serving","effect","exchange","transport","internal"]},"id":{"type":"string","maxLength":20,"pattern":"^(0|[1-9][0-9]*)$"},"realm":{"anyOf":[{"type":"string","maxLength":20,"pattern":"^(0|[1-9][0-9]*)$"},{"type":"null"}]},"resource":{"anyOf":[{"type":"string","maxLength":20,"pattern":"^(0|[1-9][0-9]*)$"},{"type":"null"}]},"sequence":{"anyOf":[{"type":"string","maxLength":20,"pattern":"^(0|[1-9][0-9]*)$"},{"type":"null"}]}},"required":["domain","id","realm","resource","sequence"]},{"type":"null"}]},"location":{"anyOf":[{"type":"object","additionalProperties":false,"properties":{"source":{"anyOf":[{"type":"string","maxLength":512},{"type":"null"}]},"source_encoding":{"type":"string","enum":["utf8","escaped_bytes"]},"source_truncated":{"type":"boolean"},"statement":{"anyOf":[{"type":"string","maxLength":20,"pattern":"^(0|[1-9][0-9]*)$"},{"type":"null"}]},"offset":{"type":"string","maxLength":20,"pattern":"^(0|[1-9][0-9]*)$"},"length":{"type":"string","maxLength":20,"pattern":"^(0|[1-9][0-9]*)$"},"line":{"type":"string","maxLength":20,"pattern":"^(0|[1-9][0-9]*)$"},"byte_column":{"type":"string","maxLength":20,"pattern":"^(0|[1-9][0-9]*)$"}},"required":["source","source_encoding","source_truncated","statement","offset","length","line","byte_column"]},{"type":"null"}]},"facts":{"type":"array","minItems":16,"maxItems":16,"items":{"anyOf":[{"type":"object","additionalProperties":false,"properties":{"field":{"type":"string","enum":["object","name","table","native_input","affected_rows","argument","option","permissions","scope","column","qualifier","constraint","key","input_row","first_occurrence","parameter","parameter_use","expected_count","actual_count","expected_type","actual_type","supplied_value","expected_value","expression","source_kind","source_basis","source_key","source_row","field_path","byte_offset","expected_resource","actual_resource","expected_source","actual_source","expected_revision","actual_revision","expected_schema","actual_schema","expected_policy","actual_policy","budget","limit","required","unit","completed_statements","emitted_rows","emitted_segments","completion","proposal","step","generation","attachment","lease","schema_origin","sampling_records","operation","native_cause","expected_bytes","presence","published","subscription","expected_codec","actual_codec","observed_clock","expected_namespace","actual_namespace","attempt","executor","resolution_reason","principal","deadline","authorization_policy","resolution_policy","protocol_status","native_effect"]},"origin":{"type":"string","enum":["caller","execution","schema","authority","owner"]},"availability":{"type":"string","enum":["provided","truncated","unrecorded","unavailable","withheld","inapplicable"]},"value":{"anyOf":[{"oneOf":[{"type":"object","additionalProperties":false,"required":["text"],"properties":{"text":{"type":"string","maxLength":256}}},{"type":"object","additionalProperties":false,"required":["signed"],"properties":{"signed":{"type":"string","maxLength":20,"pattern":"^(0|-?[1-9][0-9]*)$"}}},{"type":"object","additionalProperties":false,"required":["unsigned"],"properties":{"unsigned":{"type":"string","maxLength":20,"pattern":"^(0|[1-9][0-9]*)$"}}},{"type":"object","additionalProperties":false,"required":["boolean"],"properties":{"boolean":{"type":"boolean"}}},{"type":"object","additionalProperties":false,"required":["digest"],"properties":{"digest":{"type":"array","minItems":32,"maxItems":32,"items":{"type":"integer","minimum":0,"maximum":255}}}},{"type":"object","additionalProperties":false,"required":["location"],"properties":{"location":{"type":"object","additionalProperties":false,"properties":{"source":{"anyOf":[{"type":"string","maxLength":512},{"type":"null"}]},"source_encoding":{"type":"string","enum":["utf8","escaped_bytes"]},"source_truncated":{"type":"boolean"},"statement":{"anyOf":[{"type":"string","maxLength":20,"pattern":"^(0|[1-9][0-9]*)$"},{"type":"null"}]},"offset":{"type":"string","maxLength":20,"pattern":"^(0|[1-9][0-9]*)$"},"length":{"type":"string","maxLength":20,"pattern":"^(0|[1-9][0-9]*)$"},"line":{"type":"string","maxLength":20,"pattern":"^(0|[1-9][0-9]*)$"},"byte_column":{"type":"string","maxLength":20,"pattern":"^(0|[1-9][0-9]*)$"}},"required":["source","source_encoding","source_truncated","statement","offset","length","line","byte_column"]}}}]},{"type":"null"}]}},"required":["field","origin","availability","value"]},{"type":"null"}]}},"actions":{"type":"array","minItems":4,"maxItems":4,"items":{"anyOf":[{"type":"object","additionalProperties":false,"properties":{"kind":{"type":"string","enum":["correct_input","inspect_status","resume_exact","cancel_wait","cancel_mutation","refresh","recompile","retry_read","inspect_scope","reconcile_effect","contact_operator"]},"target":{"anyOf":[{"type":"object","additionalProperties":false,"properties":{"domain":{"type":"string","enum":["sql","query","mutation","catalog","application","publication","migration","reactive","serving","effect","exchange","transport","internal"]},"id":{"type":"string","maxLength":20,"pattern":"^(0|[1-9][0-9]*)$"},"realm":{"anyOf":[{"type":"string","maxLength":20,"pattern":"^(0|[1-9][0-9]*)$"},{"type":"null"}]},"resource":{"anyOf":[{"type":"string","maxLength":20,"pattern":"^(0|[1-9][0-9]*)$"},{"type":"null"}]},"sequence":{"anyOf":[{"type":"string","maxLength":20,"pattern":"^(0|[1-9][0-9]*)$"},{"type":"null"}]}},"required":["domain","id","realm","resource","sequence"]},{"type":"null"}]}},"required":["kind","target"]},{"type":"null"}]}}},"required":["version","definition","code","category","stage","outcome","evidence","message","cause","identity","location","facts","actions"]};
const func1 = Object.prototype.hasOwnProperty;
const func2 = ucs2length;
const pattern4 = new RegExp("^(0|[1-9][0-9]*)$", "u");
const pattern13 = new RegExp("^(0|-?[1-9][0-9]*)$", "u");

function validate21(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate21.evaluated;
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
validate21.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(func1.call(schema32.properties, key0))){
validate21.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.version !== undefined){
const _errs2 = errors;
if(1 !== data.version){
validate21.errors = [{instancePath:instancePath+"/version",schemaPath:"#/properties/version/const",keyword:"const",params:{allowedValue: 1},message:"must be equal to constant"}];
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
validate21.errors = [{instancePath:instancePath+"/definition",schemaPath:"#/properties/definition/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
if(!(data1 === "4dab48676c92875019edb9a3c8e3e6e9071ebfe22000fe513c5efe66b16734f6")){
validate21.errors = [{instancePath:instancePath+"/definition",schemaPath:"#/properties/definition/enum",keyword:"enum",params:{allowedValues: schema32.properties.definition.enum},message:"must be equal to one of the allowed values"}];
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
validate21.errors = [{instancePath:instancePath+"/code",schemaPath:"#/properties/code/maxLength",keyword:"maxLength",params:{limit: 96},message:"must NOT have more than 96 characters"}];
return false;
}
}
else {
validate21.errors = [{instancePath:instancePath+"/code",schemaPath:"#/properties/code/type",keyword:"type",params:{type: "string"},message:"must be string"}];
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
validate21.errors = [{instancePath:instancePath+"/category",schemaPath:"#/properties/category/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
if(!(((((((((((data3 === "syntax") || (data3 === "binding")) || (data3 === "unsupported")) || (data3 === "constraint")) || (data3 === "access")) || (data3 === "conflict")) || (data3 === "limit")) || (data3 === "lifecycle")) || (data3 === "integrity")) || (data3 === "unavailable")) || (data3 === "internal"))){
validate21.errors = [{instancePath:instancePath+"/category",schemaPath:"#/properties/category/enum",keyword:"enum",params:{allowedValues: schema32.properties.category.enum},message:"must be equal to one of the allowed values"}];
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
validate21.errors = [{instancePath:instancePath+"/stage",schemaPath:"#/properties/stage/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
if(!((((((((((((((data4 === "input") || (data4 === "parse")) || (data4 === "compile")) || (data4 === "bind")) || (data4 === "prepare")) || (data4 === "submit")) || (data4 === "admission")) || (data4 === "execute")) || (data4 === "read")) || (data4 === "decode")) || (data4 === "output")) || (data4 === "reconcile")) || (data4 === "cleanup")) || (data4 === "control"))){
validate21.errors = [{instancePath:instancePath+"/stage",schemaPath:"#/properties/stage/enum",keyword:"enum",params:{allowedValues: schema32.properties.stage.enum},message:"must be equal to one of the allowed values"}];
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
validate21.errors = [{instancePath:instancePath+"/outcome",schemaPath:"#/properties/outcome/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
if(!((((((((((((((data5 === "not_applicable") || (data5 === "not_submitted")) || (data5 === "not_dispatched")) || (data5 === "prepared")) || (data5 === "unknown")) || (data5 === "pending")) || (data5 === "input_rejected")) || (data5 === "rejected")) || (data5 === "applied")) || (data5 === "completed")) || (data5 === "failed")) || (data5 === "cancelled")) || (data5 === "retired")) || (data5 === "closed_unknown"))){
validate21.errors = [{instancePath:instancePath+"/outcome",schemaPath:"#/properties/outcome/enum",keyword:"enum",params:{allowedValues: schema32.properties.outcome.enum},message:"must be equal to one of the allowed values"}];
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
validate21.errors = [{instancePath:instancePath+"/evidence",schemaPath:"#/properties/evidence/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
if(!(((((data6 === "none") || (data6 === "local_before_dispatch")) || (data6 === "saved_intent")) || (data6 === "native_receipt")) || (data6 === "domain_status"))){
validate21.errors = [{instancePath:instancePath+"/evidence",schemaPath:"#/properties/evidence/enum",keyword:"enum",params:{allowedValues: schema32.properties.evidence.enum},message:"must be equal to one of the allowed values"}];
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
validate21.errors = [{instancePath:instancePath+"/message",schemaPath:"#/properties/message/maxLength",keyword:"maxLength",params:{limit: 384},message:"must NOT have more than 384 characters"}];
return false;
}
}
else {
validate21.errors = [{instancePath:instancePath+"/message",schemaPath:"#/properties/message/type",keyword:"type",params:{type: "string"},message:"must be string"}];
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
validate21.errors = vErrors;
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
let data9 = data.identity;
const _errs23 = errors;
const _errs24 = errors;
let valid2 = false;
const _errs25 = errors;
if(errors === _errs25){
if(data9 && typeof data9 == "object" && !Array.isArray(data9)){
let missing1;
if((((((data9.domain === undefined) && (missing1 = "domain")) || ((data9.id === undefined) && (missing1 = "id"))) || ((data9.realm === undefined) && (missing1 = "realm"))) || ((data9.resource === undefined) && (missing1 = "resource"))) || ((data9.sequence === undefined) && (missing1 = "sequence"))){
const err4 = {instancePath:instancePath+"/identity",schemaPath:"#/properties/identity/anyOf/0/required",keyword:"required",params:{missingProperty: missing1},message:"must have required property '"+missing1+"'"};
if(vErrors === null){
vErrors = [err4];
}
else {
vErrors.push(err4);
}
errors++;
}
else {
const _errs27 = errors;
for(const key1 in data9){
if(!(((((key1 === "domain") || (key1 === "id")) || (key1 === "realm")) || (key1 === "resource")) || (key1 === "sequence"))){
const err5 = {instancePath:instancePath+"/identity",schemaPath:"#/properties/identity/anyOf/0/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key1},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err5];
}
else {
vErrors.push(err5);
}
errors++;
break;
}
}
if(_errs27 === errors){
if(data9.domain !== undefined){
let data10 = data9.domain;
const _errs28 = errors;
if(typeof data10 !== "string"){
const err6 = {instancePath:instancePath+"/identity/domain",schemaPath:"#/properties/identity/anyOf/0/properties/domain/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err6];
}
else {
vErrors.push(err6);
}
errors++;
}
if(!(((((((((((((data10 === "sql") || (data10 === "query")) || (data10 === "mutation")) || (data10 === "catalog")) || (data10 === "application")) || (data10 === "publication")) || (data10 === "migration")) || (data10 === "reactive")) || (data10 === "serving")) || (data10 === "effect")) || (data10 === "exchange")) || (data10 === "transport")) || (data10 === "internal"))){
const err7 = {instancePath:instancePath+"/identity/domain",schemaPath:"#/properties/identity/anyOf/0/properties/domain/enum",keyword:"enum",params:{allowedValues: schema32.properties.identity.anyOf[0].properties.domain.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err7];
}
else {
vErrors.push(err7);
}
errors++;
}
var valid3 = _errs28 === errors;
}
else {
var valid3 = true;
}
if(valid3){
if(data9.id !== undefined){
let data11 = data9.id;
const _errs30 = errors;
if(errors === _errs30){
if(typeof data11 === "string"){
if(func2(data11) > 20){
const err8 = {instancePath:instancePath+"/identity/id",schemaPath:"#/properties/identity/anyOf/0/properties/id/maxLength",keyword:"maxLength",params:{limit: 20},message:"must NOT have more than 20 characters"};
if(vErrors === null){
vErrors = [err8];
}
else {
vErrors.push(err8);
}
errors++;
}
else {
if(!pattern4.test(data11)){
const err9 = {instancePath:instancePath+"/identity/id",schemaPath:"#/properties/identity/anyOf/0/properties/id/pattern",keyword:"pattern",params:{pattern: "^(0|[1-9][0-9]*)$"},message:"must match pattern \""+"^(0|[1-9][0-9]*)$"+"\""};
if(vErrors === null){
vErrors = [err9];
}
else {
vErrors.push(err9);
}
errors++;
}
}
}
else {
const err10 = {instancePath:instancePath+"/identity/id",schemaPath:"#/properties/identity/anyOf/0/properties/id/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err10];
}
else {
vErrors.push(err10);
}
errors++;
}
}
var valid3 = _errs30 === errors;
}
else {
var valid3 = true;
}
if(valid3){
if(data9.realm !== undefined){
let data12 = data9.realm;
const _errs32 = errors;
const _errs33 = errors;
let valid4 = false;
const _errs34 = errors;
if(errors === _errs34){
if(typeof data12 === "string"){
if(func2(data12) > 20){
const err11 = {instancePath:instancePath+"/identity/realm",schemaPath:"#/properties/identity/anyOf/0/properties/realm/anyOf/0/maxLength",keyword:"maxLength",params:{limit: 20},message:"must NOT have more than 20 characters"};
if(vErrors === null){
vErrors = [err11];
}
else {
vErrors.push(err11);
}
errors++;
}
else {
if(!pattern4.test(data12)){
const err12 = {instancePath:instancePath+"/identity/realm",schemaPath:"#/properties/identity/anyOf/0/properties/realm/anyOf/0/pattern",keyword:"pattern",params:{pattern: "^(0|[1-9][0-9]*)$"},message:"must match pattern \""+"^(0|[1-9][0-9]*)$"+"\""};
if(vErrors === null){
vErrors = [err12];
}
else {
vErrors.push(err12);
}
errors++;
}
}
}
else {
const err13 = {instancePath:instancePath+"/identity/realm",schemaPath:"#/properties/identity/anyOf/0/properties/realm/anyOf/0/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err13];
}
else {
vErrors.push(err13);
}
errors++;
}
}
var _valid2 = _errs34 === errors;
valid4 = valid4 || _valid2;
const _errs36 = errors;
if(data12 !== null){
const err14 = {instancePath:instancePath+"/identity/realm",schemaPath:"#/properties/identity/anyOf/0/properties/realm/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err14];
}
else {
vErrors.push(err14);
}
errors++;
}
var _valid2 = _errs36 === errors;
valid4 = valid4 || _valid2;
if(!valid4){
const err15 = {instancePath:instancePath+"/identity/realm",schemaPath:"#/properties/identity/anyOf/0/properties/realm/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err15];
}
else {
vErrors.push(err15);
}
errors++;
}
else {
errors = _errs33;
if(vErrors !== null){
if(_errs33){
vErrors.length = _errs33;
}
else {
vErrors = null;
}
}
}
var valid3 = _errs32 === errors;
}
else {
var valid3 = true;
}
if(valid3){
if(data9.resource !== undefined){
let data13 = data9.resource;
const _errs38 = errors;
const _errs39 = errors;
let valid5 = false;
const _errs40 = errors;
if(errors === _errs40){
if(typeof data13 === "string"){
if(func2(data13) > 20){
const err16 = {instancePath:instancePath+"/identity/resource",schemaPath:"#/properties/identity/anyOf/0/properties/resource/anyOf/0/maxLength",keyword:"maxLength",params:{limit: 20},message:"must NOT have more than 20 characters"};
if(vErrors === null){
vErrors = [err16];
}
else {
vErrors.push(err16);
}
errors++;
}
else {
if(!pattern4.test(data13)){
const err17 = {instancePath:instancePath+"/identity/resource",schemaPath:"#/properties/identity/anyOf/0/properties/resource/anyOf/0/pattern",keyword:"pattern",params:{pattern: "^(0|[1-9][0-9]*)$"},message:"must match pattern \""+"^(0|[1-9][0-9]*)$"+"\""};
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
else {
const err18 = {instancePath:instancePath+"/identity/resource",schemaPath:"#/properties/identity/anyOf/0/properties/resource/anyOf/0/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err18];
}
else {
vErrors.push(err18);
}
errors++;
}
}
var _valid3 = _errs40 === errors;
valid5 = valid5 || _valid3;
const _errs42 = errors;
if(data13 !== null){
const err19 = {instancePath:instancePath+"/identity/resource",schemaPath:"#/properties/identity/anyOf/0/properties/resource/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err19];
}
else {
vErrors.push(err19);
}
errors++;
}
var _valid3 = _errs42 === errors;
valid5 = valid5 || _valid3;
if(!valid5){
const err20 = {instancePath:instancePath+"/identity/resource",schemaPath:"#/properties/identity/anyOf/0/properties/resource/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err20];
}
else {
vErrors.push(err20);
}
errors++;
}
else {
errors = _errs39;
if(vErrors !== null){
if(_errs39){
vErrors.length = _errs39;
}
else {
vErrors = null;
}
}
}
var valid3 = _errs38 === errors;
}
else {
var valid3 = true;
}
if(valid3){
if(data9.sequence !== undefined){
let data14 = data9.sequence;
const _errs44 = errors;
const _errs45 = errors;
let valid6 = false;
const _errs46 = errors;
if(errors === _errs46){
if(typeof data14 === "string"){
if(func2(data14) > 20){
const err21 = {instancePath:instancePath+"/identity/sequence",schemaPath:"#/properties/identity/anyOf/0/properties/sequence/anyOf/0/maxLength",keyword:"maxLength",params:{limit: 20},message:"must NOT have more than 20 characters"};
if(vErrors === null){
vErrors = [err21];
}
else {
vErrors.push(err21);
}
errors++;
}
else {
if(!pattern4.test(data14)){
const err22 = {instancePath:instancePath+"/identity/sequence",schemaPath:"#/properties/identity/anyOf/0/properties/sequence/anyOf/0/pattern",keyword:"pattern",params:{pattern: "^(0|[1-9][0-9]*)$"},message:"must match pattern \""+"^(0|[1-9][0-9]*)$"+"\""};
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
const err23 = {instancePath:instancePath+"/identity/sequence",schemaPath:"#/properties/identity/anyOf/0/properties/sequence/anyOf/0/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err23];
}
else {
vErrors.push(err23);
}
errors++;
}
}
var _valid4 = _errs46 === errors;
valid6 = valid6 || _valid4;
const _errs48 = errors;
if(data14 !== null){
const err24 = {instancePath:instancePath+"/identity/sequence",schemaPath:"#/properties/identity/anyOf/0/properties/sequence/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err24];
}
else {
vErrors.push(err24);
}
errors++;
}
var _valid4 = _errs48 === errors;
valid6 = valid6 || _valid4;
if(!valid6){
const err25 = {instancePath:instancePath+"/identity/sequence",schemaPath:"#/properties/identity/anyOf/0/properties/sequence/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err25];
}
else {
vErrors.push(err25);
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
var valid3 = _errs44 === errors;
}
else {
var valid3 = true;
}
}
}
}
}
}
}
}
else {
const err26 = {instancePath:instancePath+"/identity",schemaPath:"#/properties/identity/anyOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err26];
}
else {
vErrors.push(err26);
}
errors++;
}
}
var _valid1 = _errs25 === errors;
valid2 = valid2 || _valid1;
const _errs50 = errors;
if(data9 !== null){
const err27 = {instancePath:instancePath+"/identity",schemaPath:"#/properties/identity/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err27];
}
else {
vErrors.push(err27);
}
errors++;
}
var _valid1 = _errs50 === errors;
valid2 = valid2 || _valid1;
if(!valid2){
const err28 = {instancePath:instancePath+"/identity",schemaPath:"#/properties/identity/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err28];
}
else {
vErrors.push(err28);
}
errors++;
validate21.errors = vErrors;
return false;
}
else {
errors = _errs24;
if(vErrors !== null){
if(_errs24){
vErrors.length = _errs24;
}
else {
vErrors = null;
}
}
}
var valid0 = _errs23 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.location !== undefined){
let data15 = data.location;
const _errs52 = errors;
const _errs53 = errors;
let valid7 = false;
const _errs54 = errors;
if(errors === _errs54){
if(data15 && typeof data15 == "object" && !Array.isArray(data15)){
let missing2;
if(((((((((data15.source === undefined) && (missing2 = "source")) || ((data15.source_encoding === undefined) && (missing2 = "source_encoding"))) || ((data15.source_truncated === undefined) && (missing2 = "source_truncated"))) || ((data15.statement === undefined) && (missing2 = "statement"))) || ((data15.offset === undefined) && (missing2 = "offset"))) || ((data15.length === undefined) && (missing2 = "length"))) || ((data15.line === undefined) && (missing2 = "line"))) || ((data15.byte_column === undefined) && (missing2 = "byte_column"))){
const err29 = {instancePath:instancePath+"/location",schemaPath:"#/properties/location/anyOf/0/required",keyword:"required",params:{missingProperty: missing2},message:"must have required property '"+missing2+"'"};
if(vErrors === null){
vErrors = [err29];
}
else {
vErrors.push(err29);
}
errors++;
}
else {
const _errs56 = errors;
for(const key2 in data15){
if(!((((((((key2 === "source") || (key2 === "source_encoding")) || (key2 === "source_truncated")) || (key2 === "statement")) || (key2 === "offset")) || (key2 === "length")) || (key2 === "line")) || (key2 === "byte_column"))){
const err30 = {instancePath:instancePath+"/location",schemaPath:"#/properties/location/anyOf/0/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key2},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err30];
}
else {
vErrors.push(err30);
}
errors++;
break;
}
}
if(_errs56 === errors){
if(data15.source !== undefined){
let data16 = data15.source;
const _errs57 = errors;
const _errs58 = errors;
let valid9 = false;
const _errs59 = errors;
if(errors === _errs59){
if(typeof data16 === "string"){
if(func2(data16) > 512){
const err31 = {instancePath:instancePath+"/location/source",schemaPath:"#/properties/location/anyOf/0/properties/source/anyOf/0/maxLength",keyword:"maxLength",params:{limit: 512},message:"must NOT have more than 512 characters"};
if(vErrors === null){
vErrors = [err31];
}
else {
vErrors.push(err31);
}
errors++;
}
}
else {
const err32 = {instancePath:instancePath+"/location/source",schemaPath:"#/properties/location/anyOf/0/properties/source/anyOf/0/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err32];
}
else {
vErrors.push(err32);
}
errors++;
}
}
var _valid6 = _errs59 === errors;
valid9 = valid9 || _valid6;
const _errs61 = errors;
if(data16 !== null){
const err33 = {instancePath:instancePath+"/location/source",schemaPath:"#/properties/location/anyOf/0/properties/source/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err33];
}
else {
vErrors.push(err33);
}
errors++;
}
var _valid6 = _errs61 === errors;
valid9 = valid9 || _valid6;
if(!valid9){
const err34 = {instancePath:instancePath+"/location/source",schemaPath:"#/properties/location/anyOf/0/properties/source/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err34];
}
else {
vErrors.push(err34);
}
errors++;
}
else {
errors = _errs58;
if(vErrors !== null){
if(_errs58){
vErrors.length = _errs58;
}
else {
vErrors = null;
}
}
}
var valid8 = _errs57 === errors;
}
else {
var valid8 = true;
}
if(valid8){
if(data15.source_encoding !== undefined){
let data17 = data15.source_encoding;
const _errs63 = errors;
if(typeof data17 !== "string"){
const err35 = {instancePath:instancePath+"/location/source_encoding",schemaPath:"#/properties/location/anyOf/0/properties/source_encoding/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err35];
}
else {
vErrors.push(err35);
}
errors++;
}
if(!((data17 === "utf8") || (data17 === "escaped_bytes"))){
const err36 = {instancePath:instancePath+"/location/source_encoding",schemaPath:"#/properties/location/anyOf/0/properties/source_encoding/enum",keyword:"enum",params:{allowedValues: schema32.properties.location.anyOf[0].properties.source_encoding.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err36];
}
else {
vErrors.push(err36);
}
errors++;
}
var valid8 = _errs63 === errors;
}
else {
var valid8 = true;
}
if(valid8){
if(data15.source_truncated !== undefined){
const _errs65 = errors;
if(typeof data15.source_truncated !== "boolean"){
const err37 = {instancePath:instancePath+"/location/source_truncated",schemaPath:"#/properties/location/anyOf/0/properties/source_truncated/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"};
if(vErrors === null){
vErrors = [err37];
}
else {
vErrors.push(err37);
}
errors++;
}
var valid8 = _errs65 === errors;
}
else {
var valid8 = true;
}
if(valid8){
if(data15.statement !== undefined){
let data19 = data15.statement;
const _errs67 = errors;
const _errs68 = errors;
let valid10 = false;
const _errs69 = errors;
if(errors === _errs69){
if(typeof data19 === "string"){
if(func2(data19) > 20){
const err38 = {instancePath:instancePath+"/location/statement",schemaPath:"#/properties/location/anyOf/0/properties/statement/anyOf/0/maxLength",keyword:"maxLength",params:{limit: 20},message:"must NOT have more than 20 characters"};
if(vErrors === null){
vErrors = [err38];
}
else {
vErrors.push(err38);
}
errors++;
}
else {
if(!pattern4.test(data19)){
const err39 = {instancePath:instancePath+"/location/statement",schemaPath:"#/properties/location/anyOf/0/properties/statement/anyOf/0/pattern",keyword:"pattern",params:{pattern: "^(0|[1-9][0-9]*)$"},message:"must match pattern \""+"^(0|[1-9][0-9]*)$"+"\""};
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
else {
const err40 = {instancePath:instancePath+"/location/statement",schemaPath:"#/properties/location/anyOf/0/properties/statement/anyOf/0/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err40];
}
else {
vErrors.push(err40);
}
errors++;
}
}
var _valid7 = _errs69 === errors;
valid10 = valid10 || _valid7;
const _errs71 = errors;
if(data19 !== null){
const err41 = {instancePath:instancePath+"/location/statement",schemaPath:"#/properties/location/anyOf/0/properties/statement/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err41];
}
else {
vErrors.push(err41);
}
errors++;
}
var _valid7 = _errs71 === errors;
valid10 = valid10 || _valid7;
if(!valid10){
const err42 = {instancePath:instancePath+"/location/statement",schemaPath:"#/properties/location/anyOf/0/properties/statement/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err42];
}
else {
vErrors.push(err42);
}
errors++;
}
else {
errors = _errs68;
if(vErrors !== null){
if(_errs68){
vErrors.length = _errs68;
}
else {
vErrors = null;
}
}
}
var valid8 = _errs67 === errors;
}
else {
var valid8 = true;
}
if(valid8){
if(data15.offset !== undefined){
let data20 = data15.offset;
const _errs73 = errors;
if(errors === _errs73){
if(typeof data20 === "string"){
if(func2(data20) > 20){
const err43 = {instancePath:instancePath+"/location/offset",schemaPath:"#/properties/location/anyOf/0/properties/offset/maxLength",keyword:"maxLength",params:{limit: 20},message:"must NOT have more than 20 characters"};
if(vErrors === null){
vErrors = [err43];
}
else {
vErrors.push(err43);
}
errors++;
}
else {
if(!pattern4.test(data20)){
const err44 = {instancePath:instancePath+"/location/offset",schemaPath:"#/properties/location/anyOf/0/properties/offset/pattern",keyword:"pattern",params:{pattern: "^(0|[1-9][0-9]*)$"},message:"must match pattern \""+"^(0|[1-9][0-9]*)$"+"\""};
if(vErrors === null){
vErrors = [err44];
}
else {
vErrors.push(err44);
}
errors++;
}
}
}
else {
const err45 = {instancePath:instancePath+"/location/offset",schemaPath:"#/properties/location/anyOf/0/properties/offset/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err45];
}
else {
vErrors.push(err45);
}
errors++;
}
}
var valid8 = _errs73 === errors;
}
else {
var valid8 = true;
}
if(valid8){
if(data15.length !== undefined){
let data21 = data15.length;
const _errs75 = errors;
if(errors === _errs75){
if(typeof data21 === "string"){
if(func2(data21) > 20){
const err46 = {instancePath:instancePath+"/location/length",schemaPath:"#/properties/location/anyOf/0/properties/length/maxLength",keyword:"maxLength",params:{limit: 20},message:"must NOT have more than 20 characters"};
if(vErrors === null){
vErrors = [err46];
}
else {
vErrors.push(err46);
}
errors++;
}
else {
if(!pattern4.test(data21)){
const err47 = {instancePath:instancePath+"/location/length",schemaPath:"#/properties/location/anyOf/0/properties/length/pattern",keyword:"pattern",params:{pattern: "^(0|[1-9][0-9]*)$"},message:"must match pattern \""+"^(0|[1-9][0-9]*)$"+"\""};
if(vErrors === null){
vErrors = [err47];
}
else {
vErrors.push(err47);
}
errors++;
}
}
}
else {
const err48 = {instancePath:instancePath+"/location/length",schemaPath:"#/properties/location/anyOf/0/properties/length/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err48];
}
else {
vErrors.push(err48);
}
errors++;
}
}
var valid8 = _errs75 === errors;
}
else {
var valid8 = true;
}
if(valid8){
if(data15.line !== undefined){
let data22 = data15.line;
const _errs77 = errors;
if(errors === _errs77){
if(typeof data22 === "string"){
if(func2(data22) > 20){
const err49 = {instancePath:instancePath+"/location/line",schemaPath:"#/properties/location/anyOf/0/properties/line/maxLength",keyword:"maxLength",params:{limit: 20},message:"must NOT have more than 20 characters"};
if(vErrors === null){
vErrors = [err49];
}
else {
vErrors.push(err49);
}
errors++;
}
else {
if(!pattern4.test(data22)){
const err50 = {instancePath:instancePath+"/location/line",schemaPath:"#/properties/location/anyOf/0/properties/line/pattern",keyword:"pattern",params:{pattern: "^(0|[1-9][0-9]*)$"},message:"must match pattern \""+"^(0|[1-9][0-9]*)$"+"\""};
if(vErrors === null){
vErrors = [err50];
}
else {
vErrors.push(err50);
}
errors++;
}
}
}
else {
const err51 = {instancePath:instancePath+"/location/line",schemaPath:"#/properties/location/anyOf/0/properties/line/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err51];
}
else {
vErrors.push(err51);
}
errors++;
}
}
var valid8 = _errs77 === errors;
}
else {
var valid8 = true;
}
if(valid8){
if(data15.byte_column !== undefined){
let data23 = data15.byte_column;
const _errs79 = errors;
if(errors === _errs79){
if(typeof data23 === "string"){
if(func2(data23) > 20){
const err52 = {instancePath:instancePath+"/location/byte_column",schemaPath:"#/properties/location/anyOf/0/properties/byte_column/maxLength",keyword:"maxLength",params:{limit: 20},message:"must NOT have more than 20 characters"};
if(vErrors === null){
vErrors = [err52];
}
else {
vErrors.push(err52);
}
errors++;
}
else {
if(!pattern4.test(data23)){
const err53 = {instancePath:instancePath+"/location/byte_column",schemaPath:"#/properties/location/anyOf/0/properties/byte_column/pattern",keyword:"pattern",params:{pattern: "^(0|[1-9][0-9]*)$"},message:"must match pattern \""+"^(0|[1-9][0-9]*)$"+"\""};
if(vErrors === null){
vErrors = [err53];
}
else {
vErrors.push(err53);
}
errors++;
}
}
}
else {
const err54 = {instancePath:instancePath+"/location/byte_column",schemaPath:"#/properties/location/anyOf/0/properties/byte_column/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err54];
}
else {
vErrors.push(err54);
}
errors++;
}
}
var valid8 = _errs79 === errors;
}
else {
var valid8 = true;
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
const err55 = {instancePath:instancePath+"/location",schemaPath:"#/properties/location/anyOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err55];
}
else {
vErrors.push(err55);
}
errors++;
}
}
var _valid5 = _errs54 === errors;
valid7 = valid7 || _valid5;
const _errs81 = errors;
if(data15 !== null){
const err56 = {instancePath:instancePath+"/location",schemaPath:"#/properties/location/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err56];
}
else {
vErrors.push(err56);
}
errors++;
}
var _valid5 = _errs81 === errors;
valid7 = valid7 || _valid5;
if(!valid7){
const err57 = {instancePath:instancePath+"/location",schemaPath:"#/properties/location/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err57];
}
else {
vErrors.push(err57);
}
errors++;
validate21.errors = vErrors;
return false;
}
else {
errors = _errs53;
if(vErrors !== null){
if(_errs53){
vErrors.length = _errs53;
}
else {
vErrors = null;
}
}
}
var valid0 = _errs52 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.facts !== undefined){
let data24 = data.facts;
const _errs83 = errors;
if(errors === _errs83){
if(Array.isArray(data24)){
if(data24.length > 16){
validate21.errors = [{instancePath:instancePath+"/facts",schemaPath:"#/properties/facts/maxItems",keyword:"maxItems",params:{limit: 16},message:"must NOT have more than 16 items"}];
return false;
}
else {
if(data24.length < 16){
validate21.errors = [{instancePath:instancePath+"/facts",schemaPath:"#/properties/facts/minItems",keyword:"minItems",params:{limit: 16},message:"must NOT have fewer than 16 items"}];
return false;
}
else {
var valid11 = true;
const len0 = data24.length;
for(let i0=0; i0<len0; i0++){
let data25 = data24[i0];
const _errs85 = errors;
const _errs86 = errors;
let valid12 = false;
const _errs87 = errors;
if(errors === _errs87){
if(data25 && typeof data25 == "object" && !Array.isArray(data25)){
let missing3;
if(((((data25.field === undefined) && (missing3 = "field")) || ((data25.origin === undefined) && (missing3 = "origin"))) || ((data25.availability === undefined) && (missing3 = "availability"))) || ((data25.value === undefined) && (missing3 = "value"))){
const err58 = {instancePath:instancePath+"/facts/" + i0,schemaPath:"#/properties/facts/items/anyOf/0/required",keyword:"required",params:{missingProperty: missing3},message:"must have required property '"+missing3+"'"};
if(vErrors === null){
vErrors = [err58];
}
else {
vErrors.push(err58);
}
errors++;
}
else {
const _errs89 = errors;
for(const key3 in data25){
if(!((((key3 === "field") || (key3 === "origin")) || (key3 === "availability")) || (key3 === "value"))){
const err59 = {instancePath:instancePath+"/facts/" + i0,schemaPath:"#/properties/facts/items/anyOf/0/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key3},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err59];
}
else {
vErrors.push(err59);
}
errors++;
break;
}
}
if(_errs89 === errors){
if(data25.field !== undefined){
let data26 = data25.field;
const _errs90 = errors;
if(typeof data26 !== "string"){
const err60 = {instancePath:instancePath+"/facts/" + i0+"/field",schemaPath:"#/properties/facts/items/anyOf/0/properties/field/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err60];
}
else {
vErrors.push(err60);
}
errors++;
}
if(!(((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((data26 === "object") || (data26 === "name")) || (data26 === "table")) || (data26 === "native_input")) || (data26 === "affected_rows")) || (data26 === "argument")) || (data26 === "option")) || (data26 === "permissions")) || (data26 === "scope")) || (data26 === "column")) || (data26 === "qualifier")) || (data26 === "constraint")) || (data26 === "key")) || (data26 === "input_row")) || (data26 === "first_occurrence")) || (data26 === "parameter")) || (data26 === "parameter_use")) || (data26 === "expected_count")) || (data26 === "actual_count")) || (data26 === "expected_type")) || (data26 === "actual_type")) || (data26 === "supplied_value")) || (data26 === "expected_value")) || (data26 === "expression")) || (data26 === "source_kind")) || (data26 === "source_basis")) || (data26 === "source_key")) || (data26 === "source_row")) || (data26 === "field_path")) || (data26 === "byte_offset")) || (data26 === "expected_resource")) || (data26 === "actual_resource")) || (data26 === "expected_source")) || (data26 === "actual_source")) || (data26 === "expected_revision")) || (data26 === "actual_revision")) || (data26 === "expected_schema")) || (data26 === "actual_schema")) || (data26 === "expected_policy")) || (data26 === "actual_policy")) || (data26 === "budget")) || (data26 === "limit")) || (data26 === "required")) || (data26 === "unit")) || (data26 === "completed_statements")) || (data26 === "emitted_rows")) || (data26 === "emitted_segments")) || (data26 === "completion")) || (data26 === "proposal")) || (data26 === "step")) || (data26 === "generation")) || (data26 === "attachment")) || (data26 === "lease")) || (data26 === "schema_origin")) || (data26 === "sampling_records")) || (data26 === "operation")) || (data26 === "native_cause")) || (data26 === "expected_bytes")) || (data26 === "presence")) || (data26 === "published")) || (data26 === "subscription")) || (data26 === "expected_codec")) || (data26 === "actual_codec")) || (data26 === "observed_clock")) || (data26 === "expected_namespace")) || (data26 === "actual_namespace")) || (data26 === "attempt")) || (data26 === "executor")) || (data26 === "resolution_reason")) || (data26 === "principal")) || (data26 === "deadline")) || (data26 === "authorization_policy")) || (data26 === "resolution_policy")) || (data26 === "protocol_status")) || (data26 === "native_effect"))){
const err61 = {instancePath:instancePath+"/facts/" + i0+"/field",schemaPath:"#/properties/facts/items/anyOf/0/properties/field/enum",keyword:"enum",params:{allowedValues: schema32.properties.facts.items.anyOf[0].properties.field.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err61];
}
else {
vErrors.push(err61);
}
errors++;
}
var valid13 = _errs90 === errors;
}
else {
var valid13 = true;
}
if(valid13){
if(data25.origin !== undefined){
let data27 = data25.origin;
const _errs92 = errors;
if(typeof data27 !== "string"){
const err62 = {instancePath:instancePath+"/facts/" + i0+"/origin",schemaPath:"#/properties/facts/items/anyOf/0/properties/origin/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err62];
}
else {
vErrors.push(err62);
}
errors++;
}
if(!(((((data27 === "caller") || (data27 === "execution")) || (data27 === "schema")) || (data27 === "authority")) || (data27 === "owner"))){
const err63 = {instancePath:instancePath+"/facts/" + i0+"/origin",schemaPath:"#/properties/facts/items/anyOf/0/properties/origin/enum",keyword:"enum",params:{allowedValues: schema32.properties.facts.items.anyOf[0].properties.origin.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err63];
}
else {
vErrors.push(err63);
}
errors++;
}
var valid13 = _errs92 === errors;
}
else {
var valid13 = true;
}
if(valid13){
if(data25.availability !== undefined){
let data28 = data25.availability;
const _errs94 = errors;
if(typeof data28 !== "string"){
const err64 = {instancePath:instancePath+"/facts/" + i0+"/availability",schemaPath:"#/properties/facts/items/anyOf/0/properties/availability/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err64];
}
else {
vErrors.push(err64);
}
errors++;
}
if(!((((((data28 === "provided") || (data28 === "truncated")) || (data28 === "unrecorded")) || (data28 === "unavailable")) || (data28 === "withheld")) || (data28 === "inapplicable"))){
const err65 = {instancePath:instancePath+"/facts/" + i0+"/availability",schemaPath:"#/properties/facts/items/anyOf/0/properties/availability/enum",keyword:"enum",params:{allowedValues: schema32.properties.facts.items.anyOf[0].properties.availability.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err65];
}
else {
vErrors.push(err65);
}
errors++;
}
var valid13 = _errs94 === errors;
}
else {
var valid13 = true;
}
if(valid13){
if(data25.value !== undefined){
let data29 = data25.value;
const _errs96 = errors;
const _errs97 = errors;
let valid14 = false;
const _errs98 = errors;
const _errs99 = errors;
let valid15 = false;
let passing0 = null;
const _errs100 = errors;
if(errors === _errs100){
if(data29 && typeof data29 == "object" && !Array.isArray(data29)){
let missing4;
if((data29.text === undefined) && (missing4 = "text")){
const err66 = {instancePath:instancePath+"/facts/" + i0+"/value",schemaPath:"#/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/0/required",keyword:"required",params:{missingProperty: missing4},message:"must have required property '"+missing4+"'"};
if(vErrors === null){
vErrors = [err66];
}
else {
vErrors.push(err66);
}
errors++;
}
else {
const _errs102 = errors;
for(const key4 in data29){
if(!(key4 === "text")){
const err67 = {instancePath:instancePath+"/facts/" + i0+"/value",schemaPath:"#/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/0/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key4},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err67];
}
else {
vErrors.push(err67);
}
errors++;
break;
}
}
if(_errs102 === errors){
if(data29.text !== undefined){
let data30 = data29.text;
const _errs103 = errors;
if(errors === _errs103){
if(typeof data30 === "string"){
if(func2(data30) > 256){
const err68 = {instancePath:instancePath+"/facts/" + i0+"/value/text",schemaPath:"#/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/0/properties/text/maxLength",keyword:"maxLength",params:{limit: 256},message:"must NOT have more than 256 characters"};
if(vErrors === null){
vErrors = [err68];
}
else {
vErrors.push(err68);
}
errors++;
}
}
else {
const err69 = {instancePath:instancePath+"/facts/" + i0+"/value/text",schemaPath:"#/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/0/properties/text/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err69];
}
else {
vErrors.push(err69);
}
errors++;
}
}
}
}
}
}
else {
const err70 = {instancePath:instancePath+"/facts/" + i0+"/value",schemaPath:"#/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err70];
}
else {
vErrors.push(err70);
}
errors++;
}
}
var _valid10 = _errs100 === errors;
if(_valid10){
valid15 = true;
passing0 = 0;
var props2 = true;
}
const _errs105 = errors;
if(errors === _errs105){
if(data29 && typeof data29 == "object" && !Array.isArray(data29)){
let missing5;
if((data29.signed === undefined) && (missing5 = "signed")){
const err71 = {instancePath:instancePath+"/facts/" + i0+"/value",schemaPath:"#/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/1/required",keyword:"required",params:{missingProperty: missing5},message:"must have required property '"+missing5+"'"};
if(vErrors === null){
vErrors = [err71];
}
else {
vErrors.push(err71);
}
errors++;
}
else {
const _errs107 = errors;
for(const key5 in data29){
if(!(key5 === "signed")){
const err72 = {instancePath:instancePath+"/facts/" + i0+"/value",schemaPath:"#/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/1/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key5},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err72];
}
else {
vErrors.push(err72);
}
errors++;
break;
}
}
if(_errs107 === errors){
if(data29.signed !== undefined){
let data31 = data29.signed;
const _errs108 = errors;
if(errors === _errs108){
if(typeof data31 === "string"){
if(func2(data31) > 20){
const err73 = {instancePath:instancePath+"/facts/" + i0+"/value/signed",schemaPath:"#/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/1/properties/signed/maxLength",keyword:"maxLength",params:{limit: 20},message:"must NOT have more than 20 characters"};
if(vErrors === null){
vErrors = [err73];
}
else {
vErrors.push(err73);
}
errors++;
}
else {
if(!pattern13.test(data31)){
const err74 = {instancePath:instancePath+"/facts/" + i0+"/value/signed",schemaPath:"#/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/1/properties/signed/pattern",keyword:"pattern",params:{pattern: "^(0|-?[1-9][0-9]*)$"},message:"must match pattern \""+"^(0|-?[1-9][0-9]*)$"+"\""};
if(vErrors === null){
vErrors = [err74];
}
else {
vErrors.push(err74);
}
errors++;
}
}
}
else {
const err75 = {instancePath:instancePath+"/facts/" + i0+"/value/signed",schemaPath:"#/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/1/properties/signed/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err75];
}
else {
vErrors.push(err75);
}
errors++;
}
}
}
}
}
}
else {
const err76 = {instancePath:instancePath+"/facts/" + i0+"/value",schemaPath:"#/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/1/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err76];
}
else {
vErrors.push(err76);
}
errors++;
}
}
var _valid10 = _errs105 === errors;
if(_valid10 && valid15){
valid15 = false;
passing0 = [passing0, 1];
}
else {
if(_valid10){
valid15 = true;
passing0 = 1;
if(props2 !== true){
props2 = true;
}
}
const _errs110 = errors;
if(errors === _errs110){
if(data29 && typeof data29 == "object" && !Array.isArray(data29)){
let missing6;
if((data29.unsigned === undefined) && (missing6 = "unsigned")){
const err77 = {instancePath:instancePath+"/facts/" + i0+"/value",schemaPath:"#/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/2/required",keyword:"required",params:{missingProperty: missing6},message:"must have required property '"+missing6+"'"};
if(vErrors === null){
vErrors = [err77];
}
else {
vErrors.push(err77);
}
errors++;
}
else {
const _errs112 = errors;
for(const key6 in data29){
if(!(key6 === "unsigned")){
const err78 = {instancePath:instancePath+"/facts/" + i0+"/value",schemaPath:"#/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/2/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key6},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err78];
}
else {
vErrors.push(err78);
}
errors++;
break;
}
}
if(_errs112 === errors){
if(data29.unsigned !== undefined){
let data32 = data29.unsigned;
const _errs113 = errors;
if(errors === _errs113){
if(typeof data32 === "string"){
if(func2(data32) > 20){
const err79 = {instancePath:instancePath+"/facts/" + i0+"/value/unsigned",schemaPath:"#/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/2/properties/unsigned/maxLength",keyword:"maxLength",params:{limit: 20},message:"must NOT have more than 20 characters"};
if(vErrors === null){
vErrors = [err79];
}
else {
vErrors.push(err79);
}
errors++;
}
else {
if(!pattern4.test(data32)){
const err80 = {instancePath:instancePath+"/facts/" + i0+"/value/unsigned",schemaPath:"#/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/2/properties/unsigned/pattern",keyword:"pattern",params:{pattern: "^(0|[1-9][0-9]*)$"},message:"must match pattern \""+"^(0|[1-9][0-9]*)$"+"\""};
if(vErrors === null){
vErrors = [err80];
}
else {
vErrors.push(err80);
}
errors++;
}
}
}
else {
const err81 = {instancePath:instancePath+"/facts/" + i0+"/value/unsigned",schemaPath:"#/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/2/properties/unsigned/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err81];
}
else {
vErrors.push(err81);
}
errors++;
}
}
}
}
}
}
else {
const err82 = {instancePath:instancePath+"/facts/" + i0+"/value",schemaPath:"#/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/2/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err82];
}
else {
vErrors.push(err82);
}
errors++;
}
}
var _valid10 = _errs110 === errors;
if(_valid10 && valid15){
valid15 = false;
passing0 = [passing0, 2];
}
else {
if(_valid10){
valid15 = true;
passing0 = 2;
if(props2 !== true){
props2 = true;
}
}
const _errs115 = errors;
if(errors === _errs115){
if(data29 && typeof data29 == "object" && !Array.isArray(data29)){
let missing7;
if((data29.boolean === undefined) && (missing7 = "boolean")){
const err83 = {instancePath:instancePath+"/facts/" + i0+"/value",schemaPath:"#/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/3/required",keyword:"required",params:{missingProperty: missing7},message:"must have required property '"+missing7+"'"};
if(vErrors === null){
vErrors = [err83];
}
else {
vErrors.push(err83);
}
errors++;
}
else {
const _errs117 = errors;
for(const key7 in data29){
if(!(key7 === "boolean")){
const err84 = {instancePath:instancePath+"/facts/" + i0+"/value",schemaPath:"#/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/3/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key7},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err84];
}
else {
vErrors.push(err84);
}
errors++;
break;
}
}
if(_errs117 === errors){
if(data29.boolean !== undefined){
if(typeof data29.boolean !== "boolean"){
const err85 = {instancePath:instancePath+"/facts/" + i0+"/value/boolean",schemaPath:"#/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/3/properties/boolean/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"};
if(vErrors === null){
vErrors = [err85];
}
else {
vErrors.push(err85);
}
errors++;
}
}
}
}
}
else {
const err86 = {instancePath:instancePath+"/facts/" + i0+"/value",schemaPath:"#/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/3/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err86];
}
else {
vErrors.push(err86);
}
errors++;
}
}
var _valid10 = _errs115 === errors;
if(_valid10 && valid15){
valid15 = false;
passing0 = [passing0, 3];
}
else {
if(_valid10){
valid15 = true;
passing0 = 3;
if(props2 !== true){
props2 = true;
}
}
const _errs120 = errors;
if(errors === _errs120){
if(data29 && typeof data29 == "object" && !Array.isArray(data29)){
let missing8;
if((data29.digest === undefined) && (missing8 = "digest")){
const err87 = {instancePath:instancePath+"/facts/" + i0+"/value",schemaPath:"#/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/4/required",keyword:"required",params:{missingProperty: missing8},message:"must have required property '"+missing8+"'"};
if(vErrors === null){
vErrors = [err87];
}
else {
vErrors.push(err87);
}
errors++;
}
else {
const _errs122 = errors;
for(const key8 in data29){
if(!(key8 === "digest")){
const err88 = {instancePath:instancePath+"/facts/" + i0+"/value",schemaPath:"#/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/4/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key8},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err88];
}
else {
vErrors.push(err88);
}
errors++;
break;
}
}
if(_errs122 === errors){
if(data29.digest !== undefined){
let data34 = data29.digest;
const _errs123 = errors;
if(errors === _errs123){
if(Array.isArray(data34)){
if(data34.length > 32){
const err89 = {instancePath:instancePath+"/facts/" + i0+"/value/digest",schemaPath:"#/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/4/properties/digest/maxItems",keyword:"maxItems",params:{limit: 32},message:"must NOT have more than 32 items"};
if(vErrors === null){
vErrors = [err89];
}
else {
vErrors.push(err89);
}
errors++;
}
else {
if(data34.length < 32){
const err90 = {instancePath:instancePath+"/facts/" + i0+"/value/digest",schemaPath:"#/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/4/properties/digest/minItems",keyword:"minItems",params:{limit: 32},message:"must NOT have fewer than 32 items"};
if(vErrors === null){
vErrors = [err90];
}
else {
vErrors.push(err90);
}
errors++;
}
else {
var valid21 = true;
const len1 = data34.length;
for(let i1=0; i1<len1; i1++){
let data35 = data34[i1];
const _errs125 = errors;
if(!(((typeof data35 == "number") && (!(data35 % 1) && !isNaN(data35))) && (isFinite(data35)))){
const err91 = {instancePath:instancePath+"/facts/" + i0+"/value/digest/" + i1,schemaPath:"#/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/4/properties/digest/items/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err91];
}
else {
vErrors.push(err91);
}
errors++;
}
if(errors === _errs125){
if((typeof data35 == "number") && (isFinite(data35))){
if(data35 > 255 || isNaN(data35)){
const err92 = {instancePath:instancePath+"/facts/" + i0+"/value/digest/" + i1,schemaPath:"#/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/4/properties/digest/items/maximum",keyword:"maximum",params:{comparison: "<=", limit: 255},message:"must be <= 255"};
if(vErrors === null){
vErrors = [err92];
}
else {
vErrors.push(err92);
}
errors++;
}
else {
if(data35 < 0 || isNaN(data35)){
const err93 = {instancePath:instancePath+"/facts/" + i0+"/value/digest/" + i1,schemaPath:"#/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/4/properties/digest/items/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err93];
}
else {
vErrors.push(err93);
}
errors++;
}
}
}
}
var valid21 = _errs125 === errors;
if(!valid21){
break;
}
}
}
}
}
else {
const err94 = {instancePath:instancePath+"/facts/" + i0+"/value/digest",schemaPath:"#/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/4/properties/digest/type",keyword:"type",params:{type: "array"},message:"must be array"};
if(vErrors === null){
vErrors = [err94];
}
else {
vErrors.push(err94);
}
errors++;
}
}
}
}
}
}
else {
const err95 = {instancePath:instancePath+"/facts/" + i0+"/value",schemaPath:"#/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/4/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err95];
}
else {
vErrors.push(err95);
}
errors++;
}
}
var _valid10 = _errs120 === errors;
if(_valid10 && valid15){
valid15 = false;
passing0 = [passing0, 4];
}
else {
if(_valid10){
valid15 = true;
passing0 = 4;
if(props2 !== true){
props2 = true;
}
}
const _errs127 = errors;
if(errors === _errs127){
if(data29 && typeof data29 == "object" && !Array.isArray(data29)){
let missing9;
if((data29.location === undefined) && (missing9 = "location")){
const err96 = {instancePath:instancePath+"/facts/" + i0+"/value",schemaPath:"#/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/5/required",keyword:"required",params:{missingProperty: missing9},message:"must have required property '"+missing9+"'"};
if(vErrors === null){
vErrors = [err96];
}
else {
vErrors.push(err96);
}
errors++;
}
else {
const _errs129 = errors;
for(const key9 in data29){
if(!(key9 === "location")){
const err97 = {instancePath:instancePath+"/facts/" + i0+"/value",schemaPath:"#/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/5/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key9},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err97];
}
else {
vErrors.push(err97);
}
errors++;
break;
}
}
if(_errs129 === errors){
if(data29.location !== undefined){
let data36 = data29.location;
const _errs130 = errors;
if(errors === _errs130){
if(data36 && typeof data36 == "object" && !Array.isArray(data36)){
let missing10;
if(((((((((data36.source === undefined) && (missing10 = "source")) || ((data36.source_encoding === undefined) && (missing10 = "source_encoding"))) || ((data36.source_truncated === undefined) && (missing10 = "source_truncated"))) || ((data36.statement === undefined) && (missing10 = "statement"))) || ((data36.offset === undefined) && (missing10 = "offset"))) || ((data36.length === undefined) && (missing10 = "length"))) || ((data36.line === undefined) && (missing10 = "line"))) || ((data36.byte_column === undefined) && (missing10 = "byte_column"))){
const err98 = {instancePath:instancePath+"/facts/" + i0+"/value/location",schemaPath:"#/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/5/properties/location/required",keyword:"required",params:{missingProperty: missing10},message:"must have required property '"+missing10+"'"};
if(vErrors === null){
vErrors = [err98];
}
else {
vErrors.push(err98);
}
errors++;
}
else {
const _errs132 = errors;
for(const key10 in data36){
if(!((((((((key10 === "source") || (key10 === "source_encoding")) || (key10 === "source_truncated")) || (key10 === "statement")) || (key10 === "offset")) || (key10 === "length")) || (key10 === "line")) || (key10 === "byte_column"))){
const err99 = {instancePath:instancePath+"/facts/" + i0+"/value/location",schemaPath:"#/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/5/properties/location/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key10},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err99];
}
else {
vErrors.push(err99);
}
errors++;
break;
}
}
if(_errs132 === errors){
if(data36.source !== undefined){
let data37 = data36.source;
const _errs133 = errors;
const _errs134 = errors;
let valid24 = false;
const _errs135 = errors;
if(errors === _errs135){
if(typeof data37 === "string"){
if(func2(data37) > 512){
const err100 = {instancePath:instancePath+"/facts/" + i0+"/value/location/source",schemaPath:"#/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/5/properties/location/properties/source/anyOf/0/maxLength",keyword:"maxLength",params:{limit: 512},message:"must NOT have more than 512 characters"};
if(vErrors === null){
vErrors = [err100];
}
else {
vErrors.push(err100);
}
errors++;
}
}
else {
const err101 = {instancePath:instancePath+"/facts/" + i0+"/value/location/source",schemaPath:"#/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/5/properties/location/properties/source/anyOf/0/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err101];
}
else {
vErrors.push(err101);
}
errors++;
}
}
var _valid11 = _errs135 === errors;
valid24 = valid24 || _valid11;
const _errs137 = errors;
if(data37 !== null){
const err102 = {instancePath:instancePath+"/facts/" + i0+"/value/location/source",schemaPath:"#/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/5/properties/location/properties/source/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err102];
}
else {
vErrors.push(err102);
}
errors++;
}
var _valid11 = _errs137 === errors;
valid24 = valid24 || _valid11;
if(!valid24){
const err103 = {instancePath:instancePath+"/facts/" + i0+"/value/location/source",schemaPath:"#/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/5/properties/location/properties/source/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err103];
}
else {
vErrors.push(err103);
}
errors++;
}
else {
errors = _errs134;
if(vErrors !== null){
if(_errs134){
vErrors.length = _errs134;
}
else {
vErrors = null;
}
}
}
var valid23 = _errs133 === errors;
}
else {
var valid23 = true;
}
if(valid23){
if(data36.source_encoding !== undefined){
let data38 = data36.source_encoding;
const _errs139 = errors;
if(typeof data38 !== "string"){
const err104 = {instancePath:instancePath+"/facts/" + i0+"/value/location/source_encoding",schemaPath:"#/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/5/properties/location/properties/source_encoding/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err104];
}
else {
vErrors.push(err104);
}
errors++;
}
if(!((data38 === "utf8") || (data38 === "escaped_bytes"))){
const err105 = {instancePath:instancePath+"/facts/" + i0+"/value/location/source_encoding",schemaPath:"#/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/5/properties/location/properties/source_encoding/enum",keyword:"enum",params:{allowedValues: schema32.properties.facts.items.anyOf[0].properties.value.anyOf[0].oneOf[5].properties.location.properties.source_encoding.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err105];
}
else {
vErrors.push(err105);
}
errors++;
}
var valid23 = _errs139 === errors;
}
else {
var valid23 = true;
}
if(valid23){
if(data36.source_truncated !== undefined){
const _errs141 = errors;
if(typeof data36.source_truncated !== "boolean"){
const err106 = {instancePath:instancePath+"/facts/" + i0+"/value/location/source_truncated",schemaPath:"#/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/5/properties/location/properties/source_truncated/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"};
if(vErrors === null){
vErrors = [err106];
}
else {
vErrors.push(err106);
}
errors++;
}
var valid23 = _errs141 === errors;
}
else {
var valid23 = true;
}
if(valid23){
if(data36.statement !== undefined){
let data40 = data36.statement;
const _errs143 = errors;
const _errs144 = errors;
let valid25 = false;
const _errs145 = errors;
if(errors === _errs145){
if(typeof data40 === "string"){
if(func2(data40) > 20){
const err107 = {instancePath:instancePath+"/facts/" + i0+"/value/location/statement",schemaPath:"#/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/5/properties/location/properties/statement/anyOf/0/maxLength",keyword:"maxLength",params:{limit: 20},message:"must NOT have more than 20 characters"};
if(vErrors === null){
vErrors = [err107];
}
else {
vErrors.push(err107);
}
errors++;
}
else {
if(!pattern4.test(data40)){
const err108 = {instancePath:instancePath+"/facts/" + i0+"/value/location/statement",schemaPath:"#/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/5/properties/location/properties/statement/anyOf/0/pattern",keyword:"pattern",params:{pattern: "^(0|[1-9][0-9]*)$"},message:"must match pattern \""+"^(0|[1-9][0-9]*)$"+"\""};
if(vErrors === null){
vErrors = [err108];
}
else {
vErrors.push(err108);
}
errors++;
}
}
}
else {
const err109 = {instancePath:instancePath+"/facts/" + i0+"/value/location/statement",schemaPath:"#/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/5/properties/location/properties/statement/anyOf/0/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err109];
}
else {
vErrors.push(err109);
}
errors++;
}
}
var _valid12 = _errs145 === errors;
valid25 = valid25 || _valid12;
const _errs147 = errors;
if(data40 !== null){
const err110 = {instancePath:instancePath+"/facts/" + i0+"/value/location/statement",schemaPath:"#/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/5/properties/location/properties/statement/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err110];
}
else {
vErrors.push(err110);
}
errors++;
}
var _valid12 = _errs147 === errors;
valid25 = valid25 || _valid12;
if(!valid25){
const err111 = {instancePath:instancePath+"/facts/" + i0+"/value/location/statement",schemaPath:"#/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/5/properties/location/properties/statement/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err111];
}
else {
vErrors.push(err111);
}
errors++;
}
else {
errors = _errs144;
if(vErrors !== null){
if(_errs144){
vErrors.length = _errs144;
}
else {
vErrors = null;
}
}
}
var valid23 = _errs143 === errors;
}
else {
var valid23 = true;
}
if(valid23){
if(data36.offset !== undefined){
let data41 = data36.offset;
const _errs149 = errors;
if(errors === _errs149){
if(typeof data41 === "string"){
if(func2(data41) > 20){
const err112 = {instancePath:instancePath+"/facts/" + i0+"/value/location/offset",schemaPath:"#/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/5/properties/location/properties/offset/maxLength",keyword:"maxLength",params:{limit: 20},message:"must NOT have more than 20 characters"};
if(vErrors === null){
vErrors = [err112];
}
else {
vErrors.push(err112);
}
errors++;
}
else {
if(!pattern4.test(data41)){
const err113 = {instancePath:instancePath+"/facts/" + i0+"/value/location/offset",schemaPath:"#/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/5/properties/location/properties/offset/pattern",keyword:"pattern",params:{pattern: "^(0|[1-9][0-9]*)$"},message:"must match pattern \""+"^(0|[1-9][0-9]*)$"+"\""};
if(vErrors === null){
vErrors = [err113];
}
else {
vErrors.push(err113);
}
errors++;
}
}
}
else {
const err114 = {instancePath:instancePath+"/facts/" + i0+"/value/location/offset",schemaPath:"#/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/5/properties/location/properties/offset/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err114];
}
else {
vErrors.push(err114);
}
errors++;
}
}
var valid23 = _errs149 === errors;
}
else {
var valid23 = true;
}
if(valid23){
if(data36.length !== undefined){
let data42 = data36.length;
const _errs151 = errors;
if(errors === _errs151){
if(typeof data42 === "string"){
if(func2(data42) > 20){
const err115 = {instancePath:instancePath+"/facts/" + i0+"/value/location/length",schemaPath:"#/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/5/properties/location/properties/length/maxLength",keyword:"maxLength",params:{limit: 20},message:"must NOT have more than 20 characters"};
if(vErrors === null){
vErrors = [err115];
}
else {
vErrors.push(err115);
}
errors++;
}
else {
if(!pattern4.test(data42)){
const err116 = {instancePath:instancePath+"/facts/" + i0+"/value/location/length",schemaPath:"#/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/5/properties/location/properties/length/pattern",keyword:"pattern",params:{pattern: "^(0|[1-9][0-9]*)$"},message:"must match pattern \""+"^(0|[1-9][0-9]*)$"+"\""};
if(vErrors === null){
vErrors = [err116];
}
else {
vErrors.push(err116);
}
errors++;
}
}
}
else {
const err117 = {instancePath:instancePath+"/facts/" + i0+"/value/location/length",schemaPath:"#/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/5/properties/location/properties/length/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err117];
}
else {
vErrors.push(err117);
}
errors++;
}
}
var valid23 = _errs151 === errors;
}
else {
var valid23 = true;
}
if(valid23){
if(data36.line !== undefined){
let data43 = data36.line;
const _errs153 = errors;
if(errors === _errs153){
if(typeof data43 === "string"){
if(func2(data43) > 20){
const err118 = {instancePath:instancePath+"/facts/" + i0+"/value/location/line",schemaPath:"#/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/5/properties/location/properties/line/maxLength",keyword:"maxLength",params:{limit: 20},message:"must NOT have more than 20 characters"};
if(vErrors === null){
vErrors = [err118];
}
else {
vErrors.push(err118);
}
errors++;
}
else {
if(!pattern4.test(data43)){
const err119 = {instancePath:instancePath+"/facts/" + i0+"/value/location/line",schemaPath:"#/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/5/properties/location/properties/line/pattern",keyword:"pattern",params:{pattern: "^(0|[1-9][0-9]*)$"},message:"must match pattern \""+"^(0|[1-9][0-9]*)$"+"\""};
if(vErrors === null){
vErrors = [err119];
}
else {
vErrors.push(err119);
}
errors++;
}
}
}
else {
const err120 = {instancePath:instancePath+"/facts/" + i0+"/value/location/line",schemaPath:"#/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/5/properties/location/properties/line/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err120];
}
else {
vErrors.push(err120);
}
errors++;
}
}
var valid23 = _errs153 === errors;
}
else {
var valid23 = true;
}
if(valid23){
if(data36.byte_column !== undefined){
let data44 = data36.byte_column;
const _errs155 = errors;
if(errors === _errs155){
if(typeof data44 === "string"){
if(func2(data44) > 20){
const err121 = {instancePath:instancePath+"/facts/" + i0+"/value/location/byte_column",schemaPath:"#/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/5/properties/location/properties/byte_column/maxLength",keyword:"maxLength",params:{limit: 20},message:"must NOT have more than 20 characters"};
if(vErrors === null){
vErrors = [err121];
}
else {
vErrors.push(err121);
}
errors++;
}
else {
if(!pattern4.test(data44)){
const err122 = {instancePath:instancePath+"/facts/" + i0+"/value/location/byte_column",schemaPath:"#/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/5/properties/location/properties/byte_column/pattern",keyword:"pattern",params:{pattern: "^(0|[1-9][0-9]*)$"},message:"must match pattern \""+"^(0|[1-9][0-9]*)$"+"\""};
if(vErrors === null){
vErrors = [err122];
}
else {
vErrors.push(err122);
}
errors++;
}
}
}
else {
const err123 = {instancePath:instancePath+"/facts/" + i0+"/value/location/byte_column",schemaPath:"#/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/5/properties/location/properties/byte_column/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err123];
}
else {
vErrors.push(err123);
}
errors++;
}
}
var valid23 = _errs155 === errors;
}
else {
var valid23 = true;
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
const err124 = {instancePath:instancePath+"/facts/" + i0+"/value/location",schemaPath:"#/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/5/properties/location/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err124];
}
else {
vErrors.push(err124);
}
errors++;
}
}
}
}
}
}
else {
const err125 = {instancePath:instancePath+"/facts/" + i0+"/value",schemaPath:"#/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/5/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err125];
}
else {
vErrors.push(err125);
}
errors++;
}
}
var _valid10 = _errs127 === errors;
if(_valid10 && valid15){
valid15 = false;
passing0 = [passing0, 5];
}
else {
if(_valid10){
valid15 = true;
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
if(!valid15){
const err126 = {instancePath:instancePath+"/facts/" + i0+"/value",schemaPath:"#/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf",keyword:"oneOf",params:{passingSchemas: passing0},message:"must match exactly one schema in oneOf"};
if(vErrors === null){
vErrors = [err126];
}
else {
vErrors.push(err126);
}
errors++;
}
else {
errors = _errs99;
if(vErrors !== null){
if(_errs99){
vErrors.length = _errs99;
}
else {
vErrors = null;
}
}
}
var _valid9 = _errs98 === errors;
valid14 = valid14 || _valid9;
const _errs157 = errors;
if(data29 !== null){
const err127 = {instancePath:instancePath+"/facts/" + i0+"/value",schemaPath:"#/properties/facts/items/anyOf/0/properties/value/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err127];
}
else {
vErrors.push(err127);
}
errors++;
}
var _valid9 = _errs157 === errors;
valid14 = valid14 || _valid9;
if(!valid14){
const err128 = {instancePath:instancePath+"/facts/" + i0+"/value",schemaPath:"#/properties/facts/items/anyOf/0/properties/value/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err128];
}
else {
vErrors.push(err128);
}
errors++;
}
else {
errors = _errs97;
if(vErrors !== null){
if(_errs97){
vErrors.length = _errs97;
}
else {
vErrors = null;
}
}
}
var valid13 = _errs96 === errors;
}
else {
var valid13 = true;
}
}
}
}
}
}
}
else {
const err129 = {instancePath:instancePath+"/facts/" + i0,schemaPath:"#/properties/facts/items/anyOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err129];
}
else {
vErrors.push(err129);
}
errors++;
}
}
var _valid8 = _errs87 === errors;
valid12 = valid12 || _valid8;
const _errs159 = errors;
if(data25 !== null){
const err130 = {instancePath:instancePath+"/facts/" + i0,schemaPath:"#/properties/facts/items/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err130];
}
else {
vErrors.push(err130);
}
errors++;
}
var _valid8 = _errs159 === errors;
valid12 = valid12 || _valid8;
if(!valid12){
const err131 = {instancePath:instancePath+"/facts/" + i0,schemaPath:"#/properties/facts/items/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err131];
}
else {
vErrors.push(err131);
}
errors++;
validate21.errors = vErrors;
return false;
}
else {
errors = _errs86;
if(vErrors !== null){
if(_errs86){
vErrors.length = _errs86;
}
else {
vErrors = null;
}
}
}
var valid11 = _errs85 === errors;
if(!valid11){
break;
}
}
}
}
}
else {
validate21.errors = [{instancePath:instancePath+"/facts",schemaPath:"#/properties/facts/type",keyword:"type",params:{type: "array"},message:"must be array"}];
return false;
}
}
var valid0 = _errs83 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.actions !== undefined){
let data45 = data.actions;
const _errs161 = errors;
if(errors === _errs161){
if(Array.isArray(data45)){
if(data45.length > 4){
validate21.errors = [{instancePath:instancePath+"/actions",schemaPath:"#/properties/actions/maxItems",keyword:"maxItems",params:{limit: 4},message:"must NOT have more than 4 items"}];
return false;
}
else {
if(data45.length < 4){
validate21.errors = [{instancePath:instancePath+"/actions",schemaPath:"#/properties/actions/minItems",keyword:"minItems",params:{limit: 4},message:"must NOT have fewer than 4 items"}];
return false;
}
else {
var valid26 = true;
const len2 = data45.length;
for(let i2=0; i2<len2; i2++){
let data46 = data45[i2];
const _errs163 = errors;
const _errs164 = errors;
let valid27 = false;
const _errs165 = errors;
if(errors === _errs165){
if(data46 && typeof data46 == "object" && !Array.isArray(data46)){
let missing11;
if(((data46.kind === undefined) && (missing11 = "kind")) || ((data46.target === undefined) && (missing11 = "target"))){
const err132 = {instancePath:instancePath+"/actions/" + i2,schemaPath:"#/properties/actions/items/anyOf/0/required",keyword:"required",params:{missingProperty: missing11},message:"must have required property '"+missing11+"'"};
if(vErrors === null){
vErrors = [err132];
}
else {
vErrors.push(err132);
}
errors++;
}
else {
const _errs167 = errors;
for(const key11 in data46){
if(!((key11 === "kind") || (key11 === "target"))){
const err133 = {instancePath:instancePath+"/actions/" + i2,schemaPath:"#/properties/actions/items/anyOf/0/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key11},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err133];
}
else {
vErrors.push(err133);
}
errors++;
break;
}
}
if(_errs167 === errors){
if(data46.kind !== undefined){
let data47 = data46.kind;
const _errs168 = errors;
if(typeof data47 !== "string"){
const err134 = {instancePath:instancePath+"/actions/" + i2+"/kind",schemaPath:"#/properties/actions/items/anyOf/0/properties/kind/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err134];
}
else {
vErrors.push(err134);
}
errors++;
}
if(!(((((((((((data47 === "correct_input") || (data47 === "inspect_status")) || (data47 === "resume_exact")) || (data47 === "cancel_wait")) || (data47 === "cancel_mutation")) || (data47 === "refresh")) || (data47 === "recompile")) || (data47 === "retry_read")) || (data47 === "inspect_scope")) || (data47 === "reconcile_effect")) || (data47 === "contact_operator"))){
const err135 = {instancePath:instancePath+"/actions/" + i2+"/kind",schemaPath:"#/properties/actions/items/anyOf/0/properties/kind/enum",keyword:"enum",params:{allowedValues: schema32.properties.actions.items.anyOf[0].properties.kind.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err135];
}
else {
vErrors.push(err135);
}
errors++;
}
var valid28 = _errs168 === errors;
}
else {
var valid28 = true;
}
if(valid28){
if(data46.target !== undefined){
let data48 = data46.target;
const _errs170 = errors;
const _errs171 = errors;
let valid29 = false;
const _errs172 = errors;
if(errors === _errs172){
if(data48 && typeof data48 == "object" && !Array.isArray(data48)){
let missing12;
if((((((data48.domain === undefined) && (missing12 = "domain")) || ((data48.id === undefined) && (missing12 = "id"))) || ((data48.realm === undefined) && (missing12 = "realm"))) || ((data48.resource === undefined) && (missing12 = "resource"))) || ((data48.sequence === undefined) && (missing12 = "sequence"))){
const err136 = {instancePath:instancePath+"/actions/" + i2+"/target",schemaPath:"#/properties/actions/items/anyOf/0/properties/target/anyOf/0/required",keyword:"required",params:{missingProperty: missing12},message:"must have required property '"+missing12+"'"};
if(vErrors === null){
vErrors = [err136];
}
else {
vErrors.push(err136);
}
errors++;
}
else {
const _errs174 = errors;
for(const key12 in data48){
if(!(((((key12 === "domain") || (key12 === "id")) || (key12 === "realm")) || (key12 === "resource")) || (key12 === "sequence"))){
const err137 = {instancePath:instancePath+"/actions/" + i2+"/target",schemaPath:"#/properties/actions/items/anyOf/0/properties/target/anyOf/0/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key12},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err137];
}
else {
vErrors.push(err137);
}
errors++;
break;
}
}
if(_errs174 === errors){
if(data48.domain !== undefined){
let data49 = data48.domain;
const _errs175 = errors;
if(typeof data49 !== "string"){
const err138 = {instancePath:instancePath+"/actions/" + i2+"/target/domain",schemaPath:"#/properties/actions/items/anyOf/0/properties/target/anyOf/0/properties/domain/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err138];
}
else {
vErrors.push(err138);
}
errors++;
}
if(!(((((((((((((data49 === "sql") || (data49 === "query")) || (data49 === "mutation")) || (data49 === "catalog")) || (data49 === "application")) || (data49 === "publication")) || (data49 === "migration")) || (data49 === "reactive")) || (data49 === "serving")) || (data49 === "effect")) || (data49 === "exchange")) || (data49 === "transport")) || (data49 === "internal"))){
const err139 = {instancePath:instancePath+"/actions/" + i2+"/target/domain",schemaPath:"#/properties/actions/items/anyOf/0/properties/target/anyOf/0/properties/domain/enum",keyword:"enum",params:{allowedValues: schema32.properties.actions.items.anyOf[0].properties.target.anyOf[0].properties.domain.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err139];
}
else {
vErrors.push(err139);
}
errors++;
}
var valid30 = _errs175 === errors;
}
else {
var valid30 = true;
}
if(valid30){
if(data48.id !== undefined){
let data50 = data48.id;
const _errs177 = errors;
if(errors === _errs177){
if(typeof data50 === "string"){
if(func2(data50) > 20){
const err140 = {instancePath:instancePath+"/actions/" + i2+"/target/id",schemaPath:"#/properties/actions/items/anyOf/0/properties/target/anyOf/0/properties/id/maxLength",keyword:"maxLength",params:{limit: 20},message:"must NOT have more than 20 characters"};
if(vErrors === null){
vErrors = [err140];
}
else {
vErrors.push(err140);
}
errors++;
}
else {
if(!pattern4.test(data50)){
const err141 = {instancePath:instancePath+"/actions/" + i2+"/target/id",schemaPath:"#/properties/actions/items/anyOf/0/properties/target/anyOf/0/properties/id/pattern",keyword:"pattern",params:{pattern: "^(0|[1-9][0-9]*)$"},message:"must match pattern \""+"^(0|[1-9][0-9]*)$"+"\""};
if(vErrors === null){
vErrors = [err141];
}
else {
vErrors.push(err141);
}
errors++;
}
}
}
else {
const err142 = {instancePath:instancePath+"/actions/" + i2+"/target/id",schemaPath:"#/properties/actions/items/anyOf/0/properties/target/anyOf/0/properties/id/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err142];
}
else {
vErrors.push(err142);
}
errors++;
}
}
var valid30 = _errs177 === errors;
}
else {
var valid30 = true;
}
if(valid30){
if(data48.realm !== undefined){
let data51 = data48.realm;
const _errs179 = errors;
const _errs180 = errors;
let valid31 = false;
const _errs181 = errors;
if(errors === _errs181){
if(typeof data51 === "string"){
if(func2(data51) > 20){
const err143 = {instancePath:instancePath+"/actions/" + i2+"/target/realm",schemaPath:"#/properties/actions/items/anyOf/0/properties/target/anyOf/0/properties/realm/anyOf/0/maxLength",keyword:"maxLength",params:{limit: 20},message:"must NOT have more than 20 characters"};
if(vErrors === null){
vErrors = [err143];
}
else {
vErrors.push(err143);
}
errors++;
}
else {
if(!pattern4.test(data51)){
const err144 = {instancePath:instancePath+"/actions/" + i2+"/target/realm",schemaPath:"#/properties/actions/items/anyOf/0/properties/target/anyOf/0/properties/realm/anyOf/0/pattern",keyword:"pattern",params:{pattern: "^(0|[1-9][0-9]*)$"},message:"must match pattern \""+"^(0|[1-9][0-9]*)$"+"\""};
if(vErrors === null){
vErrors = [err144];
}
else {
vErrors.push(err144);
}
errors++;
}
}
}
else {
const err145 = {instancePath:instancePath+"/actions/" + i2+"/target/realm",schemaPath:"#/properties/actions/items/anyOf/0/properties/target/anyOf/0/properties/realm/anyOf/0/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err145];
}
else {
vErrors.push(err145);
}
errors++;
}
}
var _valid15 = _errs181 === errors;
valid31 = valid31 || _valid15;
const _errs183 = errors;
if(data51 !== null){
const err146 = {instancePath:instancePath+"/actions/" + i2+"/target/realm",schemaPath:"#/properties/actions/items/anyOf/0/properties/target/anyOf/0/properties/realm/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err146];
}
else {
vErrors.push(err146);
}
errors++;
}
var _valid15 = _errs183 === errors;
valid31 = valid31 || _valid15;
if(!valid31){
const err147 = {instancePath:instancePath+"/actions/" + i2+"/target/realm",schemaPath:"#/properties/actions/items/anyOf/0/properties/target/anyOf/0/properties/realm/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err147];
}
else {
vErrors.push(err147);
}
errors++;
}
else {
errors = _errs180;
if(vErrors !== null){
if(_errs180){
vErrors.length = _errs180;
}
else {
vErrors = null;
}
}
}
var valid30 = _errs179 === errors;
}
else {
var valid30 = true;
}
if(valid30){
if(data48.resource !== undefined){
let data52 = data48.resource;
const _errs185 = errors;
const _errs186 = errors;
let valid32 = false;
const _errs187 = errors;
if(errors === _errs187){
if(typeof data52 === "string"){
if(func2(data52) > 20){
const err148 = {instancePath:instancePath+"/actions/" + i2+"/target/resource",schemaPath:"#/properties/actions/items/anyOf/0/properties/target/anyOf/0/properties/resource/anyOf/0/maxLength",keyword:"maxLength",params:{limit: 20},message:"must NOT have more than 20 characters"};
if(vErrors === null){
vErrors = [err148];
}
else {
vErrors.push(err148);
}
errors++;
}
else {
if(!pattern4.test(data52)){
const err149 = {instancePath:instancePath+"/actions/" + i2+"/target/resource",schemaPath:"#/properties/actions/items/anyOf/0/properties/target/anyOf/0/properties/resource/anyOf/0/pattern",keyword:"pattern",params:{pattern: "^(0|[1-9][0-9]*)$"},message:"must match pattern \""+"^(0|[1-9][0-9]*)$"+"\""};
if(vErrors === null){
vErrors = [err149];
}
else {
vErrors.push(err149);
}
errors++;
}
}
}
else {
const err150 = {instancePath:instancePath+"/actions/" + i2+"/target/resource",schemaPath:"#/properties/actions/items/anyOf/0/properties/target/anyOf/0/properties/resource/anyOf/0/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err150];
}
else {
vErrors.push(err150);
}
errors++;
}
}
var _valid16 = _errs187 === errors;
valid32 = valid32 || _valid16;
const _errs189 = errors;
if(data52 !== null){
const err151 = {instancePath:instancePath+"/actions/" + i2+"/target/resource",schemaPath:"#/properties/actions/items/anyOf/0/properties/target/anyOf/0/properties/resource/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err151];
}
else {
vErrors.push(err151);
}
errors++;
}
var _valid16 = _errs189 === errors;
valid32 = valid32 || _valid16;
if(!valid32){
const err152 = {instancePath:instancePath+"/actions/" + i2+"/target/resource",schemaPath:"#/properties/actions/items/anyOf/0/properties/target/anyOf/0/properties/resource/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err152];
}
else {
vErrors.push(err152);
}
errors++;
}
else {
errors = _errs186;
if(vErrors !== null){
if(_errs186){
vErrors.length = _errs186;
}
else {
vErrors = null;
}
}
}
var valid30 = _errs185 === errors;
}
else {
var valid30 = true;
}
if(valid30){
if(data48.sequence !== undefined){
let data53 = data48.sequence;
const _errs191 = errors;
const _errs192 = errors;
let valid33 = false;
const _errs193 = errors;
if(errors === _errs193){
if(typeof data53 === "string"){
if(func2(data53) > 20){
const err153 = {instancePath:instancePath+"/actions/" + i2+"/target/sequence",schemaPath:"#/properties/actions/items/anyOf/0/properties/target/anyOf/0/properties/sequence/anyOf/0/maxLength",keyword:"maxLength",params:{limit: 20},message:"must NOT have more than 20 characters"};
if(vErrors === null){
vErrors = [err153];
}
else {
vErrors.push(err153);
}
errors++;
}
else {
if(!pattern4.test(data53)){
const err154 = {instancePath:instancePath+"/actions/" + i2+"/target/sequence",schemaPath:"#/properties/actions/items/anyOf/0/properties/target/anyOf/0/properties/sequence/anyOf/0/pattern",keyword:"pattern",params:{pattern: "^(0|[1-9][0-9]*)$"},message:"must match pattern \""+"^(0|[1-9][0-9]*)$"+"\""};
if(vErrors === null){
vErrors = [err154];
}
else {
vErrors.push(err154);
}
errors++;
}
}
}
else {
const err155 = {instancePath:instancePath+"/actions/" + i2+"/target/sequence",schemaPath:"#/properties/actions/items/anyOf/0/properties/target/anyOf/0/properties/sequence/anyOf/0/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err155];
}
else {
vErrors.push(err155);
}
errors++;
}
}
var _valid17 = _errs193 === errors;
valid33 = valid33 || _valid17;
const _errs195 = errors;
if(data53 !== null){
const err156 = {instancePath:instancePath+"/actions/" + i2+"/target/sequence",schemaPath:"#/properties/actions/items/anyOf/0/properties/target/anyOf/0/properties/sequence/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err156];
}
else {
vErrors.push(err156);
}
errors++;
}
var _valid17 = _errs195 === errors;
valid33 = valid33 || _valid17;
if(!valid33){
const err157 = {instancePath:instancePath+"/actions/" + i2+"/target/sequence",schemaPath:"#/properties/actions/items/anyOf/0/properties/target/anyOf/0/properties/sequence/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err157];
}
else {
vErrors.push(err157);
}
errors++;
}
else {
errors = _errs192;
if(vErrors !== null){
if(_errs192){
vErrors.length = _errs192;
}
else {
vErrors = null;
}
}
}
var valid30 = _errs191 === errors;
}
else {
var valid30 = true;
}
}
}
}
}
}
}
}
else {
const err158 = {instancePath:instancePath+"/actions/" + i2+"/target",schemaPath:"#/properties/actions/items/anyOf/0/properties/target/anyOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err158];
}
else {
vErrors.push(err158);
}
errors++;
}
}
var _valid14 = _errs172 === errors;
valid29 = valid29 || _valid14;
const _errs197 = errors;
if(data48 !== null){
const err159 = {instancePath:instancePath+"/actions/" + i2+"/target",schemaPath:"#/properties/actions/items/anyOf/0/properties/target/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err159];
}
else {
vErrors.push(err159);
}
errors++;
}
var _valid14 = _errs197 === errors;
valid29 = valid29 || _valid14;
if(!valid29){
const err160 = {instancePath:instancePath+"/actions/" + i2+"/target",schemaPath:"#/properties/actions/items/anyOf/0/properties/target/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err160];
}
else {
vErrors.push(err160);
}
errors++;
}
else {
errors = _errs171;
if(vErrors !== null){
if(_errs171){
vErrors.length = _errs171;
}
else {
vErrors = null;
}
}
}
var valid28 = _errs170 === errors;
}
else {
var valid28 = true;
}
}
}
}
}
else {
const err161 = {instancePath:instancePath+"/actions/" + i2,schemaPath:"#/properties/actions/items/anyOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err161];
}
else {
vErrors.push(err161);
}
errors++;
}
}
var _valid13 = _errs165 === errors;
valid27 = valid27 || _valid13;
const _errs199 = errors;
if(data46 !== null){
const err162 = {instancePath:instancePath+"/actions/" + i2,schemaPath:"#/properties/actions/items/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err162];
}
else {
vErrors.push(err162);
}
errors++;
}
var _valid13 = _errs199 === errors;
valid27 = valid27 || _valid13;
if(!valid27){
const err163 = {instancePath:instancePath+"/actions/" + i2,schemaPath:"#/properties/actions/items/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err163];
}
else {
vErrors.push(err163);
}
errors++;
validate21.errors = vErrors;
return false;
}
else {
errors = _errs164;
if(vErrors !== null){
if(_errs164){
vErrors.length = _errs164;
}
else {
vErrors = null;
}
}
}
var valid26 = _errs163 === errors;
if(!valid26){
break;
}
}
}
}
}
else {
validate21.errors = [{instancePath:instancePath+"/actions",schemaPath:"#/properties/actions/type",keyword:"type",params:{type: "array"},message:"must be array"}];
return false;
}
}
var valid0 = _errs161 === errors;
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
validate21.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate21.errors = vErrors;
return errors === 0;
}
validate21.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};
