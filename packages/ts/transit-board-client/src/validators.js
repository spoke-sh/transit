// Generated; no runtime code generation or eval.
import lengthModule from "ajv/dist/runtime/ucs2length.js";
const ucs2length = lengthModule.default ?? lengthModule;
"use strict";
export const Response = validate20;
const schema31 = {"type":"object","additionalProperties":false,"properties":{"observation":{"type":"object","additionalProperties":false,"properties":{"version":{"type":"integer","minimum":0,"maximum":4294967295},"realm":{"type":"integer","minimum":0,"maximum":9007199254740991},"resource":{"type":"string","enum":["processes","process","mailbox","outbox","effects","payloads","history"]},"pid":{"anyOf":[{"type":"integer","minimum":0,"maximum":9007199254740991},{"type":"null"}]},"cut":{"type":"object","additionalProperties":false,"properties":{"position":{"type":"integer","minimum":0,"maximum":9007199254740991},"policy_revision":{"type":"integer","minimum":0,"maximum":9007199254740991},"retained_from":{"type":"integer","minimum":0,"maximum":9007199254740991}},"required":["position","policy_revision","retained_from"]},"reader":{"type":"object","additionalProperties":false,"properties":{"principal":{"type":"integer","minimum":0,"maximum":255},"permissions":{"type":"integer","minimum":0,"maximum":65535},"pid":{"anyOf":[{"type":"integer","minimum":0,"maximum":9007199254740991},{"type":"null"}]}},"required":["principal","permissions","pid"]},"next":{"anyOf":[{"type":"integer","minimum":0,"maximum":9007199254740991},{"type":"null"}]},"complete":{"type":"boolean"},"history":{"type":"string","enum":["retained","prefix_reclaimed"]},"scanned":{"type":"integer","minimum":0,"maximum":65535},"processes":{"type":"array","minItems":16,"maxItems":16,"items":{"anyOf":[{"type":"object","additionalProperties":false,"properties":{"pid":{"type":"integer","minimum":0,"maximum":9007199254740991},"code":{"type":"integer","minimum":0,"maximum":4294967295},"allow_trim":{"type":"boolean"},"collection":{"type":"boolean"},"control":{"anyOf":[{"type":"object","additionalProperties":false,"properties":{"phase":{"type":"string","enum":["initializing","ready","suspended"]},"required":{"type":"array","minItems":4,"maxItems":4,"items":{"anyOf":[{"type":"string","pattern":"^(?:[0-9a-f]{2})*$","maxLength":512},{"type":"null"}]}},"resume_before_ms":{"anyOf":[{"type":"integer","minimum":0,"maximum":9007199254740991},{"type":"null"}]}},"required":["phase","required","resume_before_ms"]},{"type":"null"}]},"owner":{"anyOf":[{"type":"integer","minimum":0,"maximum":255},{"type":"null"}]},"generation":{"type":"integer","minimum":0,"maximum":9007199254740991},"lifecycle":{"type":"string","enum":["running","terminated","expired"]},"state":{"type":"string","pattern":"^(?:[0-9a-f]{2})*$","maxLength":512},"revision":{"type":"integer","minimum":0,"maximum":9007199254740991},"failure":{"anyOf":[{"type":"object","additionalProperties":false,"properties":{"input":{"type":"integer","minimum":0,"maximum":9007199254740991},"recorded_at":{"type":"integer","minimum":0,"maximum":9007199254740991}},"required":["input","recorded_at"]},{"type":"null"}]},"admitted":{"type":"integer","minimum":0,"maximum":9007199254740991},"consumed":{"type":"integer","minimum":0,"maximum":9007199254740991},"cancelled":{"type":"integer","minimum":0,"maximum":9007199254740991},"work_before_ms":{"anyOf":[{"type":"integer","minimum":0,"maximum":9007199254740991},{"type":"null"}]},"settle_before_ms":{"anyOf":[{"type":"integer","minimum":0,"maximum":9007199254740991},{"type":"null"}]},"turn_permit":{"anyOf":[{"type":"object","additionalProperties":false,"properties":{"id":{"type":"integer","minimum":0,"maximum":9007199254740991},"input":{"type":"integer","minimum":0,"maximum":9007199254740991}},"required":["id","input"]},{"type":"null"}]},"binding":{"anyOf":[{"type":"object","additionalProperties":false,"properties":{"revision":{"type":"integer","minimum":0,"maximum":9007199254740991},"operation":{"type":"integer","minimum":0,"maximum":9007199254740991},"instance":{"type":"array","minItems":16,"maxItems":16,"items":{"type":"integer","minimum":0,"maximum":255}},"resource":{"type":"array","minItems":32,"maxItems":32,"items":{"type":"integer","minimum":0,"maximum":255}},"workload":{"type":"array","minItems":32,"maxItems":32,"items":{"type":"integer","minimum":0,"maximum":255}},"incarnation":{"anyOf":[{"type":"array","minItems":16,"maxItems":16,"items":{"type":"integer","minimum":0,"maximum":255}},{"type":"null"}]},"desired":{"type":"string","enum":["running","stopped"]},"phase":{"type":"string","enum":["pending","unknown","ready","stopped"]},"upgrade_from":{"anyOf":[{"type":"array","minItems":32,"maxItems":32,"items":{"type":"integer","minimum":0,"maximum":255}},{"type":"null"}]},"activation":{"anyOf":[{"type":"object","additionalProperties":false,"properties":{"worker_incarnation":{"type":"array","minItems":16,"maxItems":16,"items":{"type":"integer","minimum":0,"maximum":255}},"generation":{"type":"integer","minimum":0,"maximum":9007199254740991}},"required":["worker_incarnation","generation"]},{"type":"null"}]},"last_worker_incarnation":{"anyOf":[{"type":"array","minItems":16,"maxItems":16,"items":{"type":"integer","minimum":0,"maximum":255}},{"type":"null"}]}},"required":["revision","operation","instance","resource","workload","incarnation","desired","phase","activation","last_worker_incarnation"]},{"type":"null"}]}},"required":["pid","code","allow_trim","collection","control","owner","generation","lifecycle","state","revision","failure","admitted","consumed","cancelled","work_before_ms","settle_before_ms","turn_permit","binding"]},{"type":"null"}]}},"events":{"type":"array","minItems":16,"maxItems":16,"items":{"anyOf":[{"type":"object","additionalProperties":false,"properties":{"position":{"type":"integer","minimum":0,"maximum":9007199254740991},"pid":{"type":"integer","minimum":0,"maximum":9007199254740991},"kind":{"type":"string","enum":["lifecycle","catalog_retention","collect","grant","revoke","spawn","own","runtime_intent","runtime_observe","activate","send","begin_turn","turn","deliver_next","deliver","dispatch","observe","close_effect","terminate","expire","inspect","checkpoint","declare_payload","payload_ready","retire_payload","payload_deleted","runtime_upgrade","state"]},"policy_revision":{"type":"integer","minimum":0,"maximum":9007199254740991},"input":{"anyOf":[{"type":"integer","minimum":0,"maximum":9007199254740991},{"type":"null"}]},"effect":{"anyOf":[{"type":"integer","minimum":0,"maximum":9007199254740991},{"type":"null"}]},"output":{"anyOf":[{"type":"integer","minimum":0,"maximum":9007199254740991},{"type":"null"}]},"value":{"anyOf":[{"type":"string","pattern":"^(?:[0-9a-f]{2})*$","maxLength":512},{"type":"null"}]},"failed":{"type":"boolean"},"generation":{"anyOf":[{"type":"integer","minimum":0,"maximum":9007199254740991},{"type":"null"}]},"mailbox_status":{"anyOf":[{"type":"string","enum":["pending","consumed","cancelled"]},{"type":"null"}]},"admitted":{"type":"boolean"},"unix_ms":{"anyOf":[{"type":"integer","minimum":0,"maximum":9007199254740991},{"type":"null"}]},"clock_error_ms":{"anyOf":[{"type":"integer","minimum":0,"maximum":4294967295},{"type":"null"}]}},"required":["position","pid","kind","policy_revision","input","effect","output","value","failed","generation","mailbox_status","admitted","unix_ms","clock_error_ms"]},{"type":"null"}]}},"outbox":{"type":"array","minItems":16,"maxItems":16,"items":{"anyOf":[{"type":"object","additionalProperties":false,"properties":{"id":{"type":"integer","minimum":0,"maximum":9007199254740991},"source":{"type":"integer","minimum":0,"maximum":9007199254740991},"turn":{"type":"integer","minimum":0,"maximum":9007199254740991},"index":{"type":"integer","minimum":0,"maximum":255},"destination":{"type":"integer","minimum":0,"maximum":9007199254740991},"value":{"type":"string","pattern":"^(?:[0-9a-f]{2})*$","maxLength":512},"phase":{"type":"string","enum":["pending","delivered","denied","expired","retired","cancelled"]},"resolved_at":{"anyOf":[{"type":"integer","minimum":0,"maximum":9007199254740991},{"type":"null"}]},"courier":{"anyOf":[{"type":"integer","minimum":0,"maximum":255},{"type":"null"}]},"policy_revision":{"anyOf":[{"type":"integer","minimum":0,"maximum":9007199254740991},{"type":"null"}]}},"required":["id","source","turn","index","destination","value","phase","resolved_at","courier","policy_revision"]},{"type":"null"}]}},"effects":{"type":"array","minItems":16,"maxItems":16,"items":{"anyOf":[{"type":"object","additionalProperties":false,"properties":{"id":{"type":"integer","minimum":0,"maximum":9007199254740991},"pid":{"type":"integer","minimum":0,"maximum":9007199254740991},"payload":{"type":"string","pattern":"^(?:[0-9a-f]{2})*$","maxLength":512},"phase":{"type":"string","enum":["pending","authorized","unknown","observed","cancelled","closed_unknown"]},"attempt":{"anyOf":[{"type":"integer","minimum":0,"maximum":9007199254740991},{"type":"null"}]},"executor":{"anyOf":[{"type":"integer","minimum":0,"maximum":255},{"type":"null"}]},"result":{"anyOf":[{"type":"string","pattern":"^(?:[0-9a-f]{2})*$","maxLength":512},{"type":"null"}]},"closed_at":{"anyOf":[{"type":"integer","minimum":0,"maximum":9007199254740991},{"type":"null"}]},"reconcile_before_ms":{"anyOf":[{"type":"integer","minimum":0,"maximum":9007199254740991},{"type":"null"}]},"max_observations":{"type":"integer","minimum":0,"maximum":65535},"observations":{"type":"integer","minimum":0,"maximum":65535}},"required":["id","pid","payload","phase","attempt","executor","result","closed_at","reconcile_before_ms","max_observations","observations"]},{"type":"null"}]}},"payloads":{"type":"array","minItems":16,"maxItems":16,"items":{"anyOf":[{"type":"object","additionalProperties":false,"properties":{"id":{"type":"integer","minimum":0,"maximum":9007199254740991},"pid":{"type":"integer","minimum":0,"maximum":9007199254740991},"publisher":{"type":"integer","minimum":0,"maximum":255},"sha256":{"type":"array","minItems":32,"maxItems":32,"items":{"type":"integer","minimum":0,"maximum":255}},"bytes":{"type":"integer","minimum":0,"maximum":4294967295},"allow_delete":{"type":"boolean"},"phase":{"type":"string","enum":["creating","ready","retiring","deleted"]},"retired_at":{"anyOf":[{"type":"integer","minimum":0,"maximum":9007199254740991},{"type":"null"}]},"deleted_at":{"anyOf":[{"type":"integer","minimum":0,"maximum":9007199254740991},{"type":"null"}]}},"required":["id","pid","publisher","sha256","bytes","allow_delete","phase","retired_at","deleted_at"]},{"type":"null"}]}}},"required":["version","realm","resource","pid","cut","reader","next","complete","history","scanned","processes","events","outbox","effects","payloads"]},"edges":{"type":"array","minItems":32,"maxItems":32,"items":{"anyOf":[{"type":"object","additionalProperties":false,"properties":{"from":{"type":"object","additionalProperties":false,"properties":{"realm":{"type":"integer","minimum":0,"maximum":9007199254740991},"pid":{"type":"integer","minimum":0,"maximum":9007199254740991},"kind":{"type":"string","enum":["input","turn","output","effect","event","state"]},"id":{"type":"integer","minimum":0,"maximum":9007199254740991}},"required":["realm","pid","kind","id"]},"to":{"type":"object","additionalProperties":false,"properties":{"realm":{"type":"integer","minimum":0,"maximum":9007199254740991},"pid":{"type":"integer","minimum":0,"maximum":9007199254740991},"kind":{"type":"string","enum":["input","turn","output","effect","event","state"]},"id":{"type":"integer","minimum":0,"maximum":9007199254740991}},"required":["realm","pid","kind","id"]},"relation":{"type":"string","enum":["input_to_turn","turn_to_effect","turn_to_output","output_to_admission","effect_to_observation"]},"from_coverage":{"type":"string","enum":["retained","reclaimed","current_state"]},"to_coverage":{"type":"string","enum":["retained","reclaimed","current_state"]}},"required":["from","to","relation","from_coverage","to_coverage"]},{"type":"null"}]}}},"required":["observation","edges"]};
const func1 = Object.prototype.hasOwnProperty;
const func3 = ucs2length;
const pattern4 = new RegExp("^(?:[0-9a-f]{2})*$", "u");

function validate20(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate20.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if(((data.observation === undefined) && (missing0 = "observation")) || ((data.edges === undefined) && (missing0 = "edges"))){
validate20.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "observation") || (key0 === "edges"))){
validate20.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.observation !== undefined){
let data0 = data.observation;
const _errs2 = errors;
if(errors === _errs2){
if(data0 && typeof data0 == "object" && !Array.isArray(data0)){
let missing1;
if((((((((((((((((data0.version === undefined) && (missing1 = "version")) || ((data0.realm === undefined) && (missing1 = "realm"))) || ((data0.resource === undefined) && (missing1 = "resource"))) || ((data0.pid === undefined) && (missing1 = "pid"))) || ((data0.cut === undefined) && (missing1 = "cut"))) || ((data0.reader === undefined) && (missing1 = "reader"))) || ((data0.next === undefined) && (missing1 = "next"))) || ((data0.complete === undefined) && (missing1 = "complete"))) || ((data0.history === undefined) && (missing1 = "history"))) || ((data0.scanned === undefined) && (missing1 = "scanned"))) || ((data0.processes === undefined) && (missing1 = "processes"))) || ((data0.events === undefined) && (missing1 = "events"))) || ((data0.outbox === undefined) && (missing1 = "outbox"))) || ((data0.effects === undefined) && (missing1 = "effects"))) || ((data0.payloads === undefined) && (missing1 = "payloads"))){
validate20.errors = [{instancePath:instancePath+"/observation",schemaPath:"#/properties/observation/required",keyword:"required",params:{missingProperty: missing1},message:"must have required property '"+missing1+"'"}];
return false;
}
else {
const _errs4 = errors;
for(const key1 in data0){
if(!(func1.call(schema31.properties.observation.properties, key1))){
validate20.errors = [{instancePath:instancePath+"/observation",schemaPath:"#/properties/observation/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key1},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs4 === errors){
if(data0.version !== undefined){
let data1 = data0.version;
const _errs5 = errors;
if(!(((typeof data1 == "number") && (!(data1 % 1) && !isNaN(data1))) && (isFinite(data1)))){
validate20.errors = [{instancePath:instancePath+"/observation/version",schemaPath:"#/properties/observation/properties/version/type",keyword:"type",params:{type: "integer"},message:"must be integer"}];
return false;
}
if(errors === _errs5){
if((typeof data1 == "number") && (isFinite(data1))){
if(data1 > 4294967295 || isNaN(data1)){
validate20.errors = [{instancePath:instancePath+"/observation/version",schemaPath:"#/properties/observation/properties/version/maximum",keyword:"maximum",params:{comparison: "<=", limit: 4294967295},message:"must be <= 4294967295"}];
return false;
}
else {
if(data1 < 0 || isNaN(data1)){
validate20.errors = [{instancePath:instancePath+"/observation/version",schemaPath:"#/properties/observation/properties/version/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"}];
return false;
}
}
}
}
var valid1 = _errs5 === errors;
}
else {
var valid1 = true;
}
if(valid1){
if(data0.realm !== undefined){
let data2 = data0.realm;
const _errs7 = errors;
if(!(((typeof data2 == "number") && (!(data2 % 1) && !isNaN(data2))) && (isFinite(data2)))){
validate20.errors = [{instancePath:instancePath+"/observation/realm",schemaPath:"#/properties/observation/properties/realm/type",keyword:"type",params:{type: "integer"},message:"must be integer"}];
return false;
}
if(errors === _errs7){
if((typeof data2 == "number") && (isFinite(data2))){
if(data2 > 9007199254740991 || isNaN(data2)){
validate20.errors = [{instancePath:instancePath+"/observation/realm",schemaPath:"#/properties/observation/properties/realm/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"}];
return false;
}
else {
if(data2 < 0 || isNaN(data2)){
validate20.errors = [{instancePath:instancePath+"/observation/realm",schemaPath:"#/properties/observation/properties/realm/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"}];
return false;
}
}
}
}
var valid1 = _errs7 === errors;
}
else {
var valid1 = true;
}
if(valid1){
if(data0.resource !== undefined){
let data3 = data0.resource;
const _errs9 = errors;
if(typeof data3 !== "string"){
validate20.errors = [{instancePath:instancePath+"/observation/resource",schemaPath:"#/properties/observation/properties/resource/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
if(!(((((((data3 === "processes") || (data3 === "process")) || (data3 === "mailbox")) || (data3 === "outbox")) || (data3 === "effects")) || (data3 === "payloads")) || (data3 === "history"))){
validate20.errors = [{instancePath:instancePath+"/observation/resource",schemaPath:"#/properties/observation/properties/resource/enum",keyword:"enum",params:{allowedValues: schema31.properties.observation.properties.resource.enum},message:"must be equal to one of the allowed values"}];
return false;
}
var valid1 = _errs9 === errors;
}
else {
var valid1 = true;
}
if(valid1){
if(data0.pid !== undefined){
let data4 = data0.pid;
const _errs11 = errors;
const _errs12 = errors;
let valid2 = false;
const _errs13 = errors;
if(!(((typeof data4 == "number") && (!(data4 % 1) && !isNaN(data4))) && (isFinite(data4)))){
const err0 = {instancePath:instancePath+"/observation/pid",schemaPath:"#/properties/observation/properties/pid/anyOf/0/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err0];
}
else {
vErrors.push(err0);
}
errors++;
}
if(errors === _errs13){
if((typeof data4 == "number") && (isFinite(data4))){
if(data4 > 9007199254740991 || isNaN(data4)){
const err1 = {instancePath:instancePath+"/observation/pid",schemaPath:"#/properties/observation/properties/pid/anyOf/0/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"};
if(vErrors === null){
vErrors = [err1];
}
else {
vErrors.push(err1);
}
errors++;
}
else {
if(data4 < 0 || isNaN(data4)){
const err2 = {instancePath:instancePath+"/observation/pid",schemaPath:"#/properties/observation/properties/pid/anyOf/0/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err2];
}
else {
vErrors.push(err2);
}
errors++;
}
}
}
}
var _valid0 = _errs13 === errors;
valid2 = valid2 || _valid0;
const _errs15 = errors;
if(data4 !== null){
const err3 = {instancePath:instancePath+"/observation/pid",schemaPath:"#/properties/observation/properties/pid/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err3];
}
else {
vErrors.push(err3);
}
errors++;
}
var _valid0 = _errs15 === errors;
valid2 = valid2 || _valid0;
if(!valid2){
const err4 = {instancePath:instancePath+"/observation/pid",schemaPath:"#/properties/observation/properties/pid/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err4];
}
else {
vErrors.push(err4);
}
errors++;
validate20.errors = vErrors;
return false;
}
else {
errors = _errs12;
if(vErrors !== null){
if(_errs12){
vErrors.length = _errs12;
}
else {
vErrors = null;
}
}
}
var valid1 = _errs11 === errors;
}
else {
var valid1 = true;
}
if(valid1){
if(data0.cut !== undefined){
let data5 = data0.cut;
const _errs17 = errors;
if(errors === _errs17){
if(data5 && typeof data5 == "object" && !Array.isArray(data5)){
let missing2;
if((((data5.position === undefined) && (missing2 = "position")) || ((data5.policy_revision === undefined) && (missing2 = "policy_revision"))) || ((data5.retained_from === undefined) && (missing2 = "retained_from"))){
validate20.errors = [{instancePath:instancePath+"/observation/cut",schemaPath:"#/properties/observation/properties/cut/required",keyword:"required",params:{missingProperty: missing2},message:"must have required property '"+missing2+"'"}];
return false;
}
else {
const _errs19 = errors;
for(const key2 in data5){
if(!(((key2 === "position") || (key2 === "policy_revision")) || (key2 === "retained_from"))){
validate20.errors = [{instancePath:instancePath+"/observation/cut",schemaPath:"#/properties/observation/properties/cut/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key2},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs19 === errors){
if(data5.position !== undefined){
let data6 = data5.position;
const _errs20 = errors;
if(!(((typeof data6 == "number") && (!(data6 % 1) && !isNaN(data6))) && (isFinite(data6)))){
validate20.errors = [{instancePath:instancePath+"/observation/cut/position",schemaPath:"#/properties/observation/properties/cut/properties/position/type",keyword:"type",params:{type: "integer"},message:"must be integer"}];
return false;
}
if(errors === _errs20){
if((typeof data6 == "number") && (isFinite(data6))){
if(data6 > 9007199254740991 || isNaN(data6)){
validate20.errors = [{instancePath:instancePath+"/observation/cut/position",schemaPath:"#/properties/observation/properties/cut/properties/position/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"}];
return false;
}
else {
if(data6 < 0 || isNaN(data6)){
validate20.errors = [{instancePath:instancePath+"/observation/cut/position",schemaPath:"#/properties/observation/properties/cut/properties/position/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"}];
return false;
}
}
}
}
var valid3 = _errs20 === errors;
}
else {
var valid3 = true;
}
if(valid3){
if(data5.policy_revision !== undefined){
let data7 = data5.policy_revision;
const _errs22 = errors;
if(!(((typeof data7 == "number") && (!(data7 % 1) && !isNaN(data7))) && (isFinite(data7)))){
validate20.errors = [{instancePath:instancePath+"/observation/cut/policy_revision",schemaPath:"#/properties/observation/properties/cut/properties/policy_revision/type",keyword:"type",params:{type: "integer"},message:"must be integer"}];
return false;
}
if(errors === _errs22){
if((typeof data7 == "number") && (isFinite(data7))){
if(data7 > 9007199254740991 || isNaN(data7)){
validate20.errors = [{instancePath:instancePath+"/observation/cut/policy_revision",schemaPath:"#/properties/observation/properties/cut/properties/policy_revision/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"}];
return false;
}
else {
if(data7 < 0 || isNaN(data7)){
validate20.errors = [{instancePath:instancePath+"/observation/cut/policy_revision",schemaPath:"#/properties/observation/properties/cut/properties/policy_revision/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"}];
return false;
}
}
}
}
var valid3 = _errs22 === errors;
}
else {
var valid3 = true;
}
if(valid3){
if(data5.retained_from !== undefined){
let data8 = data5.retained_from;
const _errs24 = errors;
if(!(((typeof data8 == "number") && (!(data8 % 1) && !isNaN(data8))) && (isFinite(data8)))){
validate20.errors = [{instancePath:instancePath+"/observation/cut/retained_from",schemaPath:"#/properties/observation/properties/cut/properties/retained_from/type",keyword:"type",params:{type: "integer"},message:"must be integer"}];
return false;
}
if(errors === _errs24){
if((typeof data8 == "number") && (isFinite(data8))){
if(data8 > 9007199254740991 || isNaN(data8)){
validate20.errors = [{instancePath:instancePath+"/observation/cut/retained_from",schemaPath:"#/properties/observation/properties/cut/properties/retained_from/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"}];
return false;
}
else {
if(data8 < 0 || isNaN(data8)){
validate20.errors = [{instancePath:instancePath+"/observation/cut/retained_from",schemaPath:"#/properties/observation/properties/cut/properties/retained_from/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"}];
return false;
}
}
}
}
var valid3 = _errs24 === errors;
}
else {
var valid3 = true;
}
}
}
}
}
}
else {
validate20.errors = [{instancePath:instancePath+"/observation/cut",schemaPath:"#/properties/observation/properties/cut/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
var valid1 = _errs17 === errors;
}
else {
var valid1 = true;
}
if(valid1){
if(data0.reader !== undefined){
let data9 = data0.reader;
const _errs26 = errors;
if(errors === _errs26){
if(data9 && typeof data9 == "object" && !Array.isArray(data9)){
let missing3;
if((((data9.principal === undefined) && (missing3 = "principal")) || ((data9.permissions === undefined) && (missing3 = "permissions"))) || ((data9.pid === undefined) && (missing3 = "pid"))){
validate20.errors = [{instancePath:instancePath+"/observation/reader",schemaPath:"#/properties/observation/properties/reader/required",keyword:"required",params:{missingProperty: missing3},message:"must have required property '"+missing3+"'"}];
return false;
}
else {
const _errs28 = errors;
for(const key3 in data9){
if(!(((key3 === "principal") || (key3 === "permissions")) || (key3 === "pid"))){
validate20.errors = [{instancePath:instancePath+"/observation/reader",schemaPath:"#/properties/observation/properties/reader/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key3},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs28 === errors){
if(data9.principal !== undefined){
let data10 = data9.principal;
const _errs29 = errors;
if(!(((typeof data10 == "number") && (!(data10 % 1) && !isNaN(data10))) && (isFinite(data10)))){
validate20.errors = [{instancePath:instancePath+"/observation/reader/principal",schemaPath:"#/properties/observation/properties/reader/properties/principal/type",keyword:"type",params:{type: "integer"},message:"must be integer"}];
return false;
}
if(errors === _errs29){
if((typeof data10 == "number") && (isFinite(data10))){
if(data10 > 255 || isNaN(data10)){
validate20.errors = [{instancePath:instancePath+"/observation/reader/principal",schemaPath:"#/properties/observation/properties/reader/properties/principal/maximum",keyword:"maximum",params:{comparison: "<=", limit: 255},message:"must be <= 255"}];
return false;
}
else {
if(data10 < 0 || isNaN(data10)){
validate20.errors = [{instancePath:instancePath+"/observation/reader/principal",schemaPath:"#/properties/observation/properties/reader/properties/principal/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"}];
return false;
}
}
}
}
var valid4 = _errs29 === errors;
}
else {
var valid4 = true;
}
if(valid4){
if(data9.permissions !== undefined){
let data11 = data9.permissions;
const _errs31 = errors;
if(!(((typeof data11 == "number") && (!(data11 % 1) && !isNaN(data11))) && (isFinite(data11)))){
validate20.errors = [{instancePath:instancePath+"/observation/reader/permissions",schemaPath:"#/properties/observation/properties/reader/properties/permissions/type",keyword:"type",params:{type: "integer"},message:"must be integer"}];
return false;
}
if(errors === _errs31){
if((typeof data11 == "number") && (isFinite(data11))){
if(data11 > 65535 || isNaN(data11)){
validate20.errors = [{instancePath:instancePath+"/observation/reader/permissions",schemaPath:"#/properties/observation/properties/reader/properties/permissions/maximum",keyword:"maximum",params:{comparison: "<=", limit: 65535},message:"must be <= 65535"}];
return false;
}
else {
if(data11 < 0 || isNaN(data11)){
validate20.errors = [{instancePath:instancePath+"/observation/reader/permissions",schemaPath:"#/properties/observation/properties/reader/properties/permissions/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"}];
return false;
}
}
}
}
var valid4 = _errs31 === errors;
}
else {
var valid4 = true;
}
if(valid4){
if(data9.pid !== undefined){
let data12 = data9.pid;
const _errs33 = errors;
const _errs34 = errors;
let valid5 = false;
const _errs35 = errors;
if(!(((typeof data12 == "number") && (!(data12 % 1) && !isNaN(data12))) && (isFinite(data12)))){
const err5 = {instancePath:instancePath+"/observation/reader/pid",schemaPath:"#/properties/observation/properties/reader/properties/pid/anyOf/0/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err5];
}
else {
vErrors.push(err5);
}
errors++;
}
if(errors === _errs35){
if((typeof data12 == "number") && (isFinite(data12))){
if(data12 > 9007199254740991 || isNaN(data12)){
const err6 = {instancePath:instancePath+"/observation/reader/pid",schemaPath:"#/properties/observation/properties/reader/properties/pid/anyOf/0/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"};
if(vErrors === null){
vErrors = [err6];
}
else {
vErrors.push(err6);
}
errors++;
}
else {
if(data12 < 0 || isNaN(data12)){
const err7 = {instancePath:instancePath+"/observation/reader/pid",schemaPath:"#/properties/observation/properties/reader/properties/pid/anyOf/0/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err7];
}
else {
vErrors.push(err7);
}
errors++;
}
}
}
}
var _valid1 = _errs35 === errors;
valid5 = valid5 || _valid1;
const _errs37 = errors;
if(data12 !== null){
const err8 = {instancePath:instancePath+"/observation/reader/pid",schemaPath:"#/properties/observation/properties/reader/properties/pid/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err8];
}
else {
vErrors.push(err8);
}
errors++;
}
var _valid1 = _errs37 === errors;
valid5 = valid5 || _valid1;
if(!valid5){
const err9 = {instancePath:instancePath+"/observation/reader/pid",schemaPath:"#/properties/observation/properties/reader/properties/pid/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err9];
}
else {
vErrors.push(err9);
}
errors++;
validate20.errors = vErrors;
return false;
}
else {
errors = _errs34;
if(vErrors !== null){
if(_errs34){
vErrors.length = _errs34;
}
else {
vErrors = null;
}
}
}
var valid4 = _errs33 === errors;
}
else {
var valid4 = true;
}
}
}
}
}
}
else {
validate20.errors = [{instancePath:instancePath+"/observation/reader",schemaPath:"#/properties/observation/properties/reader/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
var valid1 = _errs26 === errors;
}
else {
var valid1 = true;
}
if(valid1){
if(data0.next !== undefined){
let data13 = data0.next;
const _errs39 = errors;
const _errs40 = errors;
let valid6 = false;
const _errs41 = errors;
if(!(((typeof data13 == "number") && (!(data13 % 1) && !isNaN(data13))) && (isFinite(data13)))){
const err10 = {instancePath:instancePath+"/observation/next",schemaPath:"#/properties/observation/properties/next/anyOf/0/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err10];
}
else {
vErrors.push(err10);
}
errors++;
}
if(errors === _errs41){
if((typeof data13 == "number") && (isFinite(data13))){
if(data13 > 9007199254740991 || isNaN(data13)){
const err11 = {instancePath:instancePath+"/observation/next",schemaPath:"#/properties/observation/properties/next/anyOf/0/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"};
if(vErrors === null){
vErrors = [err11];
}
else {
vErrors.push(err11);
}
errors++;
}
else {
if(data13 < 0 || isNaN(data13)){
const err12 = {instancePath:instancePath+"/observation/next",schemaPath:"#/properties/observation/properties/next/anyOf/0/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
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
}
var _valid2 = _errs41 === errors;
valid6 = valid6 || _valid2;
const _errs43 = errors;
if(data13 !== null){
const err13 = {instancePath:instancePath+"/observation/next",schemaPath:"#/properties/observation/properties/next/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err13];
}
else {
vErrors.push(err13);
}
errors++;
}
var _valid2 = _errs43 === errors;
valid6 = valid6 || _valid2;
if(!valid6){
const err14 = {instancePath:instancePath+"/observation/next",schemaPath:"#/properties/observation/properties/next/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err14];
}
else {
vErrors.push(err14);
}
errors++;
validate20.errors = vErrors;
return false;
}
else {
errors = _errs40;
if(vErrors !== null){
if(_errs40){
vErrors.length = _errs40;
}
else {
vErrors = null;
}
}
}
var valid1 = _errs39 === errors;
}
else {
var valid1 = true;
}
if(valid1){
if(data0.complete !== undefined){
const _errs45 = errors;
if(typeof data0.complete !== "boolean"){
validate20.errors = [{instancePath:instancePath+"/observation/complete",schemaPath:"#/properties/observation/properties/complete/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"}];
return false;
}
var valid1 = _errs45 === errors;
}
else {
var valid1 = true;
}
if(valid1){
if(data0.history !== undefined){
let data15 = data0.history;
const _errs47 = errors;
if(typeof data15 !== "string"){
validate20.errors = [{instancePath:instancePath+"/observation/history",schemaPath:"#/properties/observation/properties/history/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
if(!((data15 === "retained") || (data15 === "prefix_reclaimed"))){
validate20.errors = [{instancePath:instancePath+"/observation/history",schemaPath:"#/properties/observation/properties/history/enum",keyword:"enum",params:{allowedValues: schema31.properties.observation.properties.history.enum},message:"must be equal to one of the allowed values"}];
return false;
}
var valid1 = _errs47 === errors;
}
else {
var valid1 = true;
}
if(valid1){
if(data0.scanned !== undefined){
let data16 = data0.scanned;
const _errs49 = errors;
if(!(((typeof data16 == "number") && (!(data16 % 1) && !isNaN(data16))) && (isFinite(data16)))){
validate20.errors = [{instancePath:instancePath+"/observation/scanned",schemaPath:"#/properties/observation/properties/scanned/type",keyword:"type",params:{type: "integer"},message:"must be integer"}];
return false;
}
if(errors === _errs49){
if((typeof data16 == "number") && (isFinite(data16))){
if(data16 > 65535 || isNaN(data16)){
validate20.errors = [{instancePath:instancePath+"/observation/scanned",schemaPath:"#/properties/observation/properties/scanned/maximum",keyword:"maximum",params:{comparison: "<=", limit: 65535},message:"must be <= 65535"}];
return false;
}
else {
if(data16 < 0 || isNaN(data16)){
validate20.errors = [{instancePath:instancePath+"/observation/scanned",schemaPath:"#/properties/observation/properties/scanned/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"}];
return false;
}
}
}
}
var valid1 = _errs49 === errors;
}
else {
var valid1 = true;
}
if(valid1){
if(data0.processes !== undefined){
let data17 = data0.processes;
const _errs51 = errors;
if(errors === _errs51){
if(Array.isArray(data17)){
if(data17.length > 16){
validate20.errors = [{instancePath:instancePath+"/observation/processes",schemaPath:"#/properties/observation/properties/processes/maxItems",keyword:"maxItems",params:{limit: 16},message:"must NOT have more than 16 items"}];
return false;
}
else {
if(data17.length < 16){
validate20.errors = [{instancePath:instancePath+"/observation/processes",schemaPath:"#/properties/observation/properties/processes/minItems",keyword:"minItems",params:{limit: 16},message:"must NOT have fewer than 16 items"}];
return false;
}
else {
var valid7 = true;
const len0 = data17.length;
for(let i0=0; i0<len0; i0++){
let data18 = data17[i0];
const _errs53 = errors;
const _errs54 = errors;
let valid8 = false;
const _errs55 = errors;
if(errors === _errs55){
if(data18 && typeof data18 == "object" && !Array.isArray(data18)){
let missing4;
if(((((((((((((((((((data18.pid === undefined) && (missing4 = "pid")) || ((data18.code === undefined) && (missing4 = "code"))) || ((data18.allow_trim === undefined) && (missing4 = "allow_trim"))) || ((data18.collection === undefined) && (missing4 = "collection"))) || ((data18.control === undefined) && (missing4 = "control"))) || ((data18.owner === undefined) && (missing4 = "owner"))) || ((data18.generation === undefined) && (missing4 = "generation"))) || ((data18.lifecycle === undefined) && (missing4 = "lifecycle"))) || ((data18.state === undefined) && (missing4 = "state"))) || ((data18.revision === undefined) && (missing4 = "revision"))) || ((data18.failure === undefined) && (missing4 = "failure"))) || ((data18.admitted === undefined) && (missing4 = "admitted"))) || ((data18.consumed === undefined) && (missing4 = "consumed"))) || ((data18.cancelled === undefined) && (missing4 = "cancelled"))) || ((data18.work_before_ms === undefined) && (missing4 = "work_before_ms"))) || ((data18.settle_before_ms === undefined) && (missing4 = "settle_before_ms"))) || ((data18.turn_permit === undefined) && (missing4 = "turn_permit"))) || ((data18.binding === undefined) && (missing4 = "binding"))){
const err15 = {instancePath:instancePath+"/observation/processes/" + i0,schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/required",keyword:"required",params:{missingProperty: missing4},message:"must have required property '"+missing4+"'"};
if(vErrors === null){
vErrors = [err15];
}
else {
vErrors.push(err15);
}
errors++;
}
else {
const _errs57 = errors;
for(const key4 in data18){
if(!(func1.call(schema31.properties.observation.properties.processes.items.anyOf[0].properties, key4))){
const err16 = {instancePath:instancePath+"/observation/processes/" + i0,schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key4},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err16];
}
else {
vErrors.push(err16);
}
errors++;
break;
}
}
if(_errs57 === errors){
if(data18.pid !== undefined){
let data19 = data18.pid;
const _errs58 = errors;
if(!(((typeof data19 == "number") && (!(data19 % 1) && !isNaN(data19))) && (isFinite(data19)))){
const err17 = {instancePath:instancePath+"/observation/processes/" + i0+"/pid",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/pid/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err17];
}
else {
vErrors.push(err17);
}
errors++;
}
if(errors === _errs58){
if((typeof data19 == "number") && (isFinite(data19))){
if(data19 > 9007199254740991 || isNaN(data19)){
const err18 = {instancePath:instancePath+"/observation/processes/" + i0+"/pid",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/pid/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"};
if(vErrors === null){
vErrors = [err18];
}
else {
vErrors.push(err18);
}
errors++;
}
else {
if(data19 < 0 || isNaN(data19)){
const err19 = {instancePath:instancePath+"/observation/processes/" + i0+"/pid",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/pid/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err19];
}
else {
vErrors.push(err19);
}
errors++;
}
}
}
}
var valid9 = _errs58 === errors;
}
else {
var valid9 = true;
}
if(valid9){
if(data18.code !== undefined){
let data20 = data18.code;
const _errs60 = errors;
if(!(((typeof data20 == "number") && (!(data20 % 1) && !isNaN(data20))) && (isFinite(data20)))){
const err20 = {instancePath:instancePath+"/observation/processes/" + i0+"/code",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/code/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err20];
}
else {
vErrors.push(err20);
}
errors++;
}
if(errors === _errs60){
if((typeof data20 == "number") && (isFinite(data20))){
if(data20 > 4294967295 || isNaN(data20)){
const err21 = {instancePath:instancePath+"/observation/processes/" + i0+"/code",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/code/maximum",keyword:"maximum",params:{comparison: "<=", limit: 4294967295},message:"must be <= 4294967295"};
if(vErrors === null){
vErrors = [err21];
}
else {
vErrors.push(err21);
}
errors++;
}
else {
if(data20 < 0 || isNaN(data20)){
const err22 = {instancePath:instancePath+"/observation/processes/" + i0+"/code",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/code/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
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
}
var valid9 = _errs60 === errors;
}
else {
var valid9 = true;
}
if(valid9){
if(data18.allow_trim !== undefined){
const _errs62 = errors;
if(typeof data18.allow_trim !== "boolean"){
const err23 = {instancePath:instancePath+"/observation/processes/" + i0+"/allow_trim",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/allow_trim/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"};
if(vErrors === null){
vErrors = [err23];
}
else {
vErrors.push(err23);
}
errors++;
}
var valid9 = _errs62 === errors;
}
else {
var valid9 = true;
}
if(valid9){
if(data18.collection !== undefined){
const _errs64 = errors;
if(typeof data18.collection !== "boolean"){
const err24 = {instancePath:instancePath+"/observation/processes/" + i0+"/collection",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/collection/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"};
if(vErrors === null){
vErrors = [err24];
}
else {
vErrors.push(err24);
}
errors++;
}
var valid9 = _errs64 === errors;
}
else {
var valid9 = true;
}
if(valid9){
if(data18.control !== undefined){
let data23 = data18.control;
const _errs66 = errors;
const _errs67 = errors;
let valid10 = false;
const _errs68 = errors;
if(errors === _errs68){
if(data23 && typeof data23 == "object" && !Array.isArray(data23)){
let missing5;
if((((data23.phase === undefined) && (missing5 = "phase")) || ((data23.required === undefined) && (missing5 = "required"))) || ((data23.resume_before_ms === undefined) && (missing5 = "resume_before_ms"))){
const err25 = {instancePath:instancePath+"/observation/processes/" + i0+"/control",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/control/anyOf/0/required",keyword:"required",params:{missingProperty: missing5},message:"must have required property '"+missing5+"'"};
if(vErrors === null){
vErrors = [err25];
}
else {
vErrors.push(err25);
}
errors++;
}
else {
const _errs70 = errors;
for(const key5 in data23){
if(!(((key5 === "phase") || (key5 === "required")) || (key5 === "resume_before_ms"))){
const err26 = {instancePath:instancePath+"/observation/processes/" + i0+"/control",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/control/anyOf/0/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key5},message:"must NOT have additional properties"};
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
if(_errs70 === errors){
if(data23.phase !== undefined){
let data24 = data23.phase;
const _errs71 = errors;
if(typeof data24 !== "string"){
const err27 = {instancePath:instancePath+"/observation/processes/" + i0+"/control/phase",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/control/anyOf/0/properties/phase/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err27];
}
else {
vErrors.push(err27);
}
errors++;
}
if(!(((data24 === "initializing") || (data24 === "ready")) || (data24 === "suspended"))){
const err28 = {instancePath:instancePath+"/observation/processes/" + i0+"/control/phase",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/control/anyOf/0/properties/phase/enum",keyword:"enum",params:{allowedValues: schema31.properties.observation.properties.processes.items.anyOf[0].properties.control.anyOf[0].properties.phase.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err28];
}
else {
vErrors.push(err28);
}
errors++;
}
var valid11 = _errs71 === errors;
}
else {
var valid11 = true;
}
if(valid11){
if(data23.required !== undefined){
let data25 = data23.required;
const _errs73 = errors;
if(errors === _errs73){
if(Array.isArray(data25)){
if(data25.length > 4){
const err29 = {instancePath:instancePath+"/observation/processes/" + i0+"/control/required",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/control/anyOf/0/properties/required/maxItems",keyword:"maxItems",params:{limit: 4},message:"must NOT have more than 4 items"};
if(vErrors === null){
vErrors = [err29];
}
else {
vErrors.push(err29);
}
errors++;
}
else {
if(data25.length < 4){
const err30 = {instancePath:instancePath+"/observation/processes/" + i0+"/control/required",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/control/anyOf/0/properties/required/minItems",keyword:"minItems",params:{limit: 4},message:"must NOT have fewer than 4 items"};
if(vErrors === null){
vErrors = [err30];
}
else {
vErrors.push(err30);
}
errors++;
}
else {
var valid12 = true;
const len1 = data25.length;
for(let i1=0; i1<len1; i1++){
let data26 = data25[i1];
const _errs75 = errors;
const _errs76 = errors;
let valid13 = false;
const _errs77 = errors;
if(errors === _errs77){
if(typeof data26 === "string"){
if(func3(data26) > 512){
const err31 = {instancePath:instancePath+"/observation/processes/" + i0+"/control/required/" + i1,schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/control/anyOf/0/properties/required/items/anyOf/0/maxLength",keyword:"maxLength",params:{limit: 512},message:"must NOT have more than 512 characters"};
if(vErrors === null){
vErrors = [err31];
}
else {
vErrors.push(err31);
}
errors++;
}
else {
if(!pattern4.test(data26)){
const err32 = {instancePath:instancePath+"/observation/processes/" + i0+"/control/required/" + i1,schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/control/anyOf/0/properties/required/items/anyOf/0/pattern",keyword:"pattern",params:{pattern: "^(?:[0-9a-f]{2})*$"},message:"must match pattern \""+"^(?:[0-9a-f]{2})*$"+"\""};
if(vErrors === null){
vErrors = [err32];
}
else {
vErrors.push(err32);
}
errors++;
}
}
}
else {
const err33 = {instancePath:instancePath+"/observation/processes/" + i0+"/control/required/" + i1,schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/control/anyOf/0/properties/required/items/anyOf/0/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err33];
}
else {
vErrors.push(err33);
}
errors++;
}
}
var _valid5 = _errs77 === errors;
valid13 = valid13 || _valid5;
const _errs79 = errors;
if(data26 !== null){
const err34 = {instancePath:instancePath+"/observation/processes/" + i0+"/control/required/" + i1,schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/control/anyOf/0/properties/required/items/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err34];
}
else {
vErrors.push(err34);
}
errors++;
}
var _valid5 = _errs79 === errors;
valid13 = valid13 || _valid5;
if(!valid13){
const err35 = {instancePath:instancePath+"/observation/processes/" + i0+"/control/required/" + i1,schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/control/anyOf/0/properties/required/items/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err35];
}
else {
vErrors.push(err35);
}
errors++;
}
else {
errors = _errs76;
if(vErrors !== null){
if(_errs76){
vErrors.length = _errs76;
}
else {
vErrors = null;
}
}
}
var valid12 = _errs75 === errors;
if(!valid12){
break;
}
}
}
}
}
else {
const err36 = {instancePath:instancePath+"/observation/processes/" + i0+"/control/required",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/control/anyOf/0/properties/required/type",keyword:"type",params:{type: "array"},message:"must be array"};
if(vErrors === null){
vErrors = [err36];
}
else {
vErrors.push(err36);
}
errors++;
}
}
var valid11 = _errs73 === errors;
}
else {
var valid11 = true;
}
if(valid11){
if(data23.resume_before_ms !== undefined){
let data27 = data23.resume_before_ms;
const _errs81 = errors;
const _errs82 = errors;
let valid14 = false;
const _errs83 = errors;
if(!(((typeof data27 == "number") && (!(data27 % 1) && !isNaN(data27))) && (isFinite(data27)))){
const err37 = {instancePath:instancePath+"/observation/processes/" + i0+"/control/resume_before_ms",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/control/anyOf/0/properties/resume_before_ms/anyOf/0/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err37];
}
else {
vErrors.push(err37);
}
errors++;
}
if(errors === _errs83){
if((typeof data27 == "number") && (isFinite(data27))){
if(data27 > 9007199254740991 || isNaN(data27)){
const err38 = {instancePath:instancePath+"/observation/processes/" + i0+"/control/resume_before_ms",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/control/anyOf/0/properties/resume_before_ms/anyOf/0/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"};
if(vErrors === null){
vErrors = [err38];
}
else {
vErrors.push(err38);
}
errors++;
}
else {
if(data27 < 0 || isNaN(data27)){
const err39 = {instancePath:instancePath+"/observation/processes/" + i0+"/control/resume_before_ms",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/control/anyOf/0/properties/resume_before_ms/anyOf/0/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
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
var _valid6 = _errs83 === errors;
valid14 = valid14 || _valid6;
const _errs85 = errors;
if(data27 !== null){
const err40 = {instancePath:instancePath+"/observation/processes/" + i0+"/control/resume_before_ms",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/control/anyOf/0/properties/resume_before_ms/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err40];
}
else {
vErrors.push(err40);
}
errors++;
}
var _valid6 = _errs85 === errors;
valid14 = valid14 || _valid6;
if(!valid14){
const err41 = {instancePath:instancePath+"/observation/processes/" + i0+"/control/resume_before_ms",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/control/anyOf/0/properties/resume_before_ms/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err41];
}
else {
vErrors.push(err41);
}
errors++;
}
else {
errors = _errs82;
if(vErrors !== null){
if(_errs82){
vErrors.length = _errs82;
}
else {
vErrors = null;
}
}
}
var valid11 = _errs81 === errors;
}
else {
var valid11 = true;
}
}
}
}
}
}
else {
const err42 = {instancePath:instancePath+"/observation/processes/" + i0+"/control",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/control/anyOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err42];
}
else {
vErrors.push(err42);
}
errors++;
}
}
var _valid4 = _errs68 === errors;
valid10 = valid10 || _valid4;
const _errs87 = errors;
if(data23 !== null){
const err43 = {instancePath:instancePath+"/observation/processes/" + i0+"/control",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/control/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err43];
}
else {
vErrors.push(err43);
}
errors++;
}
var _valid4 = _errs87 === errors;
valid10 = valid10 || _valid4;
if(!valid10){
const err44 = {instancePath:instancePath+"/observation/processes/" + i0+"/control",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/control/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err44];
}
else {
vErrors.push(err44);
}
errors++;
}
else {
errors = _errs67;
if(vErrors !== null){
if(_errs67){
vErrors.length = _errs67;
}
else {
vErrors = null;
}
}
}
var valid9 = _errs66 === errors;
}
else {
var valid9 = true;
}
if(valid9){
if(data18.owner !== undefined){
let data28 = data18.owner;
const _errs89 = errors;
const _errs90 = errors;
let valid15 = false;
const _errs91 = errors;
if(!(((typeof data28 == "number") && (!(data28 % 1) && !isNaN(data28))) && (isFinite(data28)))){
const err45 = {instancePath:instancePath+"/observation/processes/" + i0+"/owner",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/owner/anyOf/0/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err45];
}
else {
vErrors.push(err45);
}
errors++;
}
if(errors === _errs91){
if((typeof data28 == "number") && (isFinite(data28))){
if(data28 > 255 || isNaN(data28)){
const err46 = {instancePath:instancePath+"/observation/processes/" + i0+"/owner",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/owner/anyOf/0/maximum",keyword:"maximum",params:{comparison: "<=", limit: 255},message:"must be <= 255"};
if(vErrors === null){
vErrors = [err46];
}
else {
vErrors.push(err46);
}
errors++;
}
else {
if(data28 < 0 || isNaN(data28)){
const err47 = {instancePath:instancePath+"/observation/processes/" + i0+"/owner",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/owner/anyOf/0/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
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
}
var _valid7 = _errs91 === errors;
valid15 = valid15 || _valid7;
const _errs93 = errors;
if(data28 !== null){
const err48 = {instancePath:instancePath+"/observation/processes/" + i0+"/owner",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/owner/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err48];
}
else {
vErrors.push(err48);
}
errors++;
}
var _valid7 = _errs93 === errors;
valid15 = valid15 || _valid7;
if(!valid15){
const err49 = {instancePath:instancePath+"/observation/processes/" + i0+"/owner",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/owner/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err49];
}
else {
vErrors.push(err49);
}
errors++;
}
else {
errors = _errs90;
if(vErrors !== null){
if(_errs90){
vErrors.length = _errs90;
}
else {
vErrors = null;
}
}
}
var valid9 = _errs89 === errors;
}
else {
var valid9 = true;
}
if(valid9){
if(data18.generation !== undefined){
let data29 = data18.generation;
const _errs95 = errors;
if(!(((typeof data29 == "number") && (!(data29 % 1) && !isNaN(data29))) && (isFinite(data29)))){
const err50 = {instancePath:instancePath+"/observation/processes/" + i0+"/generation",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/generation/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err50];
}
else {
vErrors.push(err50);
}
errors++;
}
if(errors === _errs95){
if((typeof data29 == "number") && (isFinite(data29))){
if(data29 > 9007199254740991 || isNaN(data29)){
const err51 = {instancePath:instancePath+"/observation/processes/" + i0+"/generation",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/generation/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"};
if(vErrors === null){
vErrors = [err51];
}
else {
vErrors.push(err51);
}
errors++;
}
else {
if(data29 < 0 || isNaN(data29)){
const err52 = {instancePath:instancePath+"/observation/processes/" + i0+"/generation",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/generation/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err52];
}
else {
vErrors.push(err52);
}
errors++;
}
}
}
}
var valid9 = _errs95 === errors;
}
else {
var valid9 = true;
}
if(valid9){
if(data18.lifecycle !== undefined){
let data30 = data18.lifecycle;
const _errs97 = errors;
if(typeof data30 !== "string"){
const err53 = {instancePath:instancePath+"/observation/processes/" + i0+"/lifecycle",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/lifecycle/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err53];
}
else {
vErrors.push(err53);
}
errors++;
}
if(!(((data30 === "running") || (data30 === "terminated")) || (data30 === "expired"))){
const err54 = {instancePath:instancePath+"/observation/processes/" + i0+"/lifecycle",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/lifecycle/enum",keyword:"enum",params:{allowedValues: schema31.properties.observation.properties.processes.items.anyOf[0].properties.lifecycle.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err54];
}
else {
vErrors.push(err54);
}
errors++;
}
var valid9 = _errs97 === errors;
}
else {
var valid9 = true;
}
if(valid9){
if(data18.state !== undefined){
let data31 = data18.state;
const _errs99 = errors;
if(errors === _errs99){
if(typeof data31 === "string"){
if(func3(data31) > 512){
const err55 = {instancePath:instancePath+"/observation/processes/" + i0+"/state",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/state/maxLength",keyword:"maxLength",params:{limit: 512},message:"must NOT have more than 512 characters"};
if(vErrors === null){
vErrors = [err55];
}
else {
vErrors.push(err55);
}
errors++;
}
else {
if(!pattern4.test(data31)){
const err56 = {instancePath:instancePath+"/observation/processes/" + i0+"/state",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/state/pattern",keyword:"pattern",params:{pattern: "^(?:[0-9a-f]{2})*$"},message:"must match pattern \""+"^(?:[0-9a-f]{2})*$"+"\""};
if(vErrors === null){
vErrors = [err56];
}
else {
vErrors.push(err56);
}
errors++;
}
}
}
else {
const err57 = {instancePath:instancePath+"/observation/processes/" + i0+"/state",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/state/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err57];
}
else {
vErrors.push(err57);
}
errors++;
}
}
var valid9 = _errs99 === errors;
}
else {
var valid9 = true;
}
if(valid9){
if(data18.revision !== undefined){
let data32 = data18.revision;
const _errs101 = errors;
if(!(((typeof data32 == "number") && (!(data32 % 1) && !isNaN(data32))) && (isFinite(data32)))){
const err58 = {instancePath:instancePath+"/observation/processes/" + i0+"/revision",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/revision/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err58];
}
else {
vErrors.push(err58);
}
errors++;
}
if(errors === _errs101){
if((typeof data32 == "number") && (isFinite(data32))){
if(data32 > 9007199254740991 || isNaN(data32)){
const err59 = {instancePath:instancePath+"/observation/processes/" + i0+"/revision",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/revision/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"};
if(vErrors === null){
vErrors = [err59];
}
else {
vErrors.push(err59);
}
errors++;
}
else {
if(data32 < 0 || isNaN(data32)){
const err60 = {instancePath:instancePath+"/observation/processes/" + i0+"/revision",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/revision/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err60];
}
else {
vErrors.push(err60);
}
errors++;
}
}
}
}
var valid9 = _errs101 === errors;
}
else {
var valid9 = true;
}
if(valid9){
if(data18.failure !== undefined){
let data33 = data18.failure;
const _errs103 = errors;
const _errs104 = errors;
let valid16 = false;
const _errs105 = errors;
if(errors === _errs105){
if(data33 && typeof data33 == "object" && !Array.isArray(data33)){
let missing6;
if(((data33.input === undefined) && (missing6 = "input")) || ((data33.recorded_at === undefined) && (missing6 = "recorded_at"))){
const err61 = {instancePath:instancePath+"/observation/processes/" + i0+"/failure",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/failure/anyOf/0/required",keyword:"required",params:{missingProperty: missing6},message:"must have required property '"+missing6+"'"};
if(vErrors === null){
vErrors = [err61];
}
else {
vErrors.push(err61);
}
errors++;
}
else {
const _errs107 = errors;
for(const key6 in data33){
if(!((key6 === "input") || (key6 === "recorded_at"))){
const err62 = {instancePath:instancePath+"/observation/processes/" + i0+"/failure",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/failure/anyOf/0/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key6},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err62];
}
else {
vErrors.push(err62);
}
errors++;
break;
}
}
if(_errs107 === errors){
if(data33.input !== undefined){
let data34 = data33.input;
const _errs108 = errors;
if(!(((typeof data34 == "number") && (!(data34 % 1) && !isNaN(data34))) && (isFinite(data34)))){
const err63 = {instancePath:instancePath+"/observation/processes/" + i0+"/failure/input",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/failure/anyOf/0/properties/input/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err63];
}
else {
vErrors.push(err63);
}
errors++;
}
if(errors === _errs108){
if((typeof data34 == "number") && (isFinite(data34))){
if(data34 > 9007199254740991 || isNaN(data34)){
const err64 = {instancePath:instancePath+"/observation/processes/" + i0+"/failure/input",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/failure/anyOf/0/properties/input/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"};
if(vErrors === null){
vErrors = [err64];
}
else {
vErrors.push(err64);
}
errors++;
}
else {
if(data34 < 0 || isNaN(data34)){
const err65 = {instancePath:instancePath+"/observation/processes/" + i0+"/failure/input",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/failure/anyOf/0/properties/input/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err65];
}
else {
vErrors.push(err65);
}
errors++;
}
}
}
}
var valid17 = _errs108 === errors;
}
else {
var valid17 = true;
}
if(valid17){
if(data33.recorded_at !== undefined){
let data35 = data33.recorded_at;
const _errs110 = errors;
if(!(((typeof data35 == "number") && (!(data35 % 1) && !isNaN(data35))) && (isFinite(data35)))){
const err66 = {instancePath:instancePath+"/observation/processes/" + i0+"/failure/recorded_at",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/failure/anyOf/0/properties/recorded_at/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err66];
}
else {
vErrors.push(err66);
}
errors++;
}
if(errors === _errs110){
if((typeof data35 == "number") && (isFinite(data35))){
if(data35 > 9007199254740991 || isNaN(data35)){
const err67 = {instancePath:instancePath+"/observation/processes/" + i0+"/failure/recorded_at",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/failure/anyOf/0/properties/recorded_at/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"};
if(vErrors === null){
vErrors = [err67];
}
else {
vErrors.push(err67);
}
errors++;
}
else {
if(data35 < 0 || isNaN(data35)){
const err68 = {instancePath:instancePath+"/observation/processes/" + i0+"/failure/recorded_at",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/failure/anyOf/0/properties/recorded_at/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err68];
}
else {
vErrors.push(err68);
}
errors++;
}
}
}
}
var valid17 = _errs110 === errors;
}
else {
var valid17 = true;
}
}
}
}
}
else {
const err69 = {instancePath:instancePath+"/observation/processes/" + i0+"/failure",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/failure/anyOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err69];
}
else {
vErrors.push(err69);
}
errors++;
}
}
var _valid8 = _errs105 === errors;
valid16 = valid16 || _valid8;
const _errs112 = errors;
if(data33 !== null){
const err70 = {instancePath:instancePath+"/observation/processes/" + i0+"/failure",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/failure/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err70];
}
else {
vErrors.push(err70);
}
errors++;
}
var _valid8 = _errs112 === errors;
valid16 = valid16 || _valid8;
if(!valid16){
const err71 = {instancePath:instancePath+"/observation/processes/" + i0+"/failure",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/failure/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err71];
}
else {
vErrors.push(err71);
}
errors++;
}
else {
errors = _errs104;
if(vErrors !== null){
if(_errs104){
vErrors.length = _errs104;
}
else {
vErrors = null;
}
}
}
var valid9 = _errs103 === errors;
}
else {
var valid9 = true;
}
if(valid9){
if(data18.admitted !== undefined){
let data36 = data18.admitted;
const _errs114 = errors;
if(!(((typeof data36 == "number") && (!(data36 % 1) && !isNaN(data36))) && (isFinite(data36)))){
const err72 = {instancePath:instancePath+"/observation/processes/" + i0+"/admitted",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/admitted/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err72];
}
else {
vErrors.push(err72);
}
errors++;
}
if(errors === _errs114){
if((typeof data36 == "number") && (isFinite(data36))){
if(data36 > 9007199254740991 || isNaN(data36)){
const err73 = {instancePath:instancePath+"/observation/processes/" + i0+"/admitted",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/admitted/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"};
if(vErrors === null){
vErrors = [err73];
}
else {
vErrors.push(err73);
}
errors++;
}
else {
if(data36 < 0 || isNaN(data36)){
const err74 = {instancePath:instancePath+"/observation/processes/" + i0+"/admitted",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/admitted/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
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
}
var valid9 = _errs114 === errors;
}
else {
var valid9 = true;
}
if(valid9){
if(data18.consumed !== undefined){
let data37 = data18.consumed;
const _errs116 = errors;
if(!(((typeof data37 == "number") && (!(data37 % 1) && !isNaN(data37))) && (isFinite(data37)))){
const err75 = {instancePath:instancePath+"/observation/processes/" + i0+"/consumed",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/consumed/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err75];
}
else {
vErrors.push(err75);
}
errors++;
}
if(errors === _errs116){
if((typeof data37 == "number") && (isFinite(data37))){
if(data37 > 9007199254740991 || isNaN(data37)){
const err76 = {instancePath:instancePath+"/observation/processes/" + i0+"/consumed",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/consumed/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"};
if(vErrors === null){
vErrors = [err76];
}
else {
vErrors.push(err76);
}
errors++;
}
else {
if(data37 < 0 || isNaN(data37)){
const err77 = {instancePath:instancePath+"/observation/processes/" + i0+"/consumed",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/consumed/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err77];
}
else {
vErrors.push(err77);
}
errors++;
}
}
}
}
var valid9 = _errs116 === errors;
}
else {
var valid9 = true;
}
if(valid9){
if(data18.cancelled !== undefined){
let data38 = data18.cancelled;
const _errs118 = errors;
if(!(((typeof data38 == "number") && (!(data38 % 1) && !isNaN(data38))) && (isFinite(data38)))){
const err78 = {instancePath:instancePath+"/observation/processes/" + i0+"/cancelled",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/cancelled/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err78];
}
else {
vErrors.push(err78);
}
errors++;
}
if(errors === _errs118){
if((typeof data38 == "number") && (isFinite(data38))){
if(data38 > 9007199254740991 || isNaN(data38)){
const err79 = {instancePath:instancePath+"/observation/processes/" + i0+"/cancelled",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/cancelled/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"};
if(vErrors === null){
vErrors = [err79];
}
else {
vErrors.push(err79);
}
errors++;
}
else {
if(data38 < 0 || isNaN(data38)){
const err80 = {instancePath:instancePath+"/observation/processes/" + i0+"/cancelled",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/cancelled/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
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
}
var valid9 = _errs118 === errors;
}
else {
var valid9 = true;
}
if(valid9){
if(data18.work_before_ms !== undefined){
let data39 = data18.work_before_ms;
const _errs120 = errors;
const _errs121 = errors;
let valid18 = false;
const _errs122 = errors;
if(!(((typeof data39 == "number") && (!(data39 % 1) && !isNaN(data39))) && (isFinite(data39)))){
const err81 = {instancePath:instancePath+"/observation/processes/" + i0+"/work_before_ms",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/work_before_ms/anyOf/0/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err81];
}
else {
vErrors.push(err81);
}
errors++;
}
if(errors === _errs122){
if((typeof data39 == "number") && (isFinite(data39))){
if(data39 > 9007199254740991 || isNaN(data39)){
const err82 = {instancePath:instancePath+"/observation/processes/" + i0+"/work_before_ms",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/work_before_ms/anyOf/0/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"};
if(vErrors === null){
vErrors = [err82];
}
else {
vErrors.push(err82);
}
errors++;
}
else {
if(data39 < 0 || isNaN(data39)){
const err83 = {instancePath:instancePath+"/observation/processes/" + i0+"/work_before_ms",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/work_before_ms/anyOf/0/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err83];
}
else {
vErrors.push(err83);
}
errors++;
}
}
}
}
var _valid9 = _errs122 === errors;
valid18 = valid18 || _valid9;
const _errs124 = errors;
if(data39 !== null){
const err84 = {instancePath:instancePath+"/observation/processes/" + i0+"/work_before_ms",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/work_before_ms/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err84];
}
else {
vErrors.push(err84);
}
errors++;
}
var _valid9 = _errs124 === errors;
valid18 = valid18 || _valid9;
if(!valid18){
const err85 = {instancePath:instancePath+"/observation/processes/" + i0+"/work_before_ms",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/work_before_ms/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err85];
}
else {
vErrors.push(err85);
}
errors++;
}
else {
errors = _errs121;
if(vErrors !== null){
if(_errs121){
vErrors.length = _errs121;
}
else {
vErrors = null;
}
}
}
var valid9 = _errs120 === errors;
}
else {
var valid9 = true;
}
if(valid9){
if(data18.settle_before_ms !== undefined){
let data40 = data18.settle_before_ms;
const _errs126 = errors;
const _errs127 = errors;
let valid19 = false;
const _errs128 = errors;
if(!(((typeof data40 == "number") && (!(data40 % 1) && !isNaN(data40))) && (isFinite(data40)))){
const err86 = {instancePath:instancePath+"/observation/processes/" + i0+"/settle_before_ms",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/settle_before_ms/anyOf/0/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err86];
}
else {
vErrors.push(err86);
}
errors++;
}
if(errors === _errs128){
if((typeof data40 == "number") && (isFinite(data40))){
if(data40 > 9007199254740991 || isNaN(data40)){
const err87 = {instancePath:instancePath+"/observation/processes/" + i0+"/settle_before_ms",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/settle_before_ms/anyOf/0/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"};
if(vErrors === null){
vErrors = [err87];
}
else {
vErrors.push(err87);
}
errors++;
}
else {
if(data40 < 0 || isNaN(data40)){
const err88 = {instancePath:instancePath+"/observation/processes/" + i0+"/settle_before_ms",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/settle_before_ms/anyOf/0/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err88];
}
else {
vErrors.push(err88);
}
errors++;
}
}
}
}
var _valid10 = _errs128 === errors;
valid19 = valid19 || _valid10;
const _errs130 = errors;
if(data40 !== null){
const err89 = {instancePath:instancePath+"/observation/processes/" + i0+"/settle_before_ms",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/settle_before_ms/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err89];
}
else {
vErrors.push(err89);
}
errors++;
}
var _valid10 = _errs130 === errors;
valid19 = valid19 || _valid10;
if(!valid19){
const err90 = {instancePath:instancePath+"/observation/processes/" + i0+"/settle_before_ms",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/settle_before_ms/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err90];
}
else {
vErrors.push(err90);
}
errors++;
}
else {
errors = _errs127;
if(vErrors !== null){
if(_errs127){
vErrors.length = _errs127;
}
else {
vErrors = null;
}
}
}
var valid9 = _errs126 === errors;
}
else {
var valid9 = true;
}
if(valid9){
if(data18.turn_permit !== undefined){
let data41 = data18.turn_permit;
const _errs132 = errors;
const _errs133 = errors;
let valid20 = false;
const _errs134 = errors;
if(errors === _errs134){
if(data41 && typeof data41 == "object" && !Array.isArray(data41)){
let missing7;
if(((data41.id === undefined) && (missing7 = "id")) || ((data41.input === undefined) && (missing7 = "input"))){
const err91 = {instancePath:instancePath+"/observation/processes/" + i0+"/turn_permit",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/turn_permit/anyOf/0/required",keyword:"required",params:{missingProperty: missing7},message:"must have required property '"+missing7+"'"};
if(vErrors === null){
vErrors = [err91];
}
else {
vErrors.push(err91);
}
errors++;
}
else {
const _errs136 = errors;
for(const key7 in data41){
if(!((key7 === "id") || (key7 === "input"))){
const err92 = {instancePath:instancePath+"/observation/processes/" + i0+"/turn_permit",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/turn_permit/anyOf/0/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key7},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err92];
}
else {
vErrors.push(err92);
}
errors++;
break;
}
}
if(_errs136 === errors){
if(data41.id !== undefined){
let data42 = data41.id;
const _errs137 = errors;
if(!(((typeof data42 == "number") && (!(data42 % 1) && !isNaN(data42))) && (isFinite(data42)))){
const err93 = {instancePath:instancePath+"/observation/processes/" + i0+"/turn_permit/id",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/turn_permit/anyOf/0/properties/id/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err93];
}
else {
vErrors.push(err93);
}
errors++;
}
if(errors === _errs137){
if((typeof data42 == "number") && (isFinite(data42))){
if(data42 > 9007199254740991 || isNaN(data42)){
const err94 = {instancePath:instancePath+"/observation/processes/" + i0+"/turn_permit/id",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/turn_permit/anyOf/0/properties/id/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"};
if(vErrors === null){
vErrors = [err94];
}
else {
vErrors.push(err94);
}
errors++;
}
else {
if(data42 < 0 || isNaN(data42)){
const err95 = {instancePath:instancePath+"/observation/processes/" + i0+"/turn_permit/id",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/turn_permit/anyOf/0/properties/id/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err95];
}
else {
vErrors.push(err95);
}
errors++;
}
}
}
}
var valid21 = _errs137 === errors;
}
else {
var valid21 = true;
}
if(valid21){
if(data41.input !== undefined){
let data43 = data41.input;
const _errs139 = errors;
if(!(((typeof data43 == "number") && (!(data43 % 1) && !isNaN(data43))) && (isFinite(data43)))){
const err96 = {instancePath:instancePath+"/observation/processes/" + i0+"/turn_permit/input",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/turn_permit/anyOf/0/properties/input/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err96];
}
else {
vErrors.push(err96);
}
errors++;
}
if(errors === _errs139){
if((typeof data43 == "number") && (isFinite(data43))){
if(data43 > 9007199254740991 || isNaN(data43)){
const err97 = {instancePath:instancePath+"/observation/processes/" + i0+"/turn_permit/input",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/turn_permit/anyOf/0/properties/input/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"};
if(vErrors === null){
vErrors = [err97];
}
else {
vErrors.push(err97);
}
errors++;
}
else {
if(data43 < 0 || isNaN(data43)){
const err98 = {instancePath:instancePath+"/observation/processes/" + i0+"/turn_permit/input",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/turn_permit/anyOf/0/properties/input/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err98];
}
else {
vErrors.push(err98);
}
errors++;
}
}
}
}
var valid21 = _errs139 === errors;
}
else {
var valid21 = true;
}
}
}
}
}
else {
const err99 = {instancePath:instancePath+"/observation/processes/" + i0+"/turn_permit",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/turn_permit/anyOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err99];
}
else {
vErrors.push(err99);
}
errors++;
}
}
var _valid11 = _errs134 === errors;
valid20 = valid20 || _valid11;
const _errs141 = errors;
if(data41 !== null){
const err100 = {instancePath:instancePath+"/observation/processes/" + i0+"/turn_permit",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/turn_permit/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err100];
}
else {
vErrors.push(err100);
}
errors++;
}
var _valid11 = _errs141 === errors;
valid20 = valid20 || _valid11;
if(!valid20){
const err101 = {instancePath:instancePath+"/observation/processes/" + i0+"/turn_permit",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/turn_permit/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err101];
}
else {
vErrors.push(err101);
}
errors++;
}
else {
errors = _errs133;
if(vErrors !== null){
if(_errs133){
vErrors.length = _errs133;
}
else {
vErrors = null;
}
}
}
var valid9 = _errs132 === errors;
}
else {
var valid9 = true;
}
if(valid9){
if(data18.binding !== undefined){
let data44 = data18.binding;
const _errs143 = errors;
const _errs144 = errors;
let valid22 = false;
const _errs145 = errors;
if(errors === _errs145){
if(data44 && typeof data44 == "object" && !Array.isArray(data44)){
let missing8;
if(((((((((((data44.revision === undefined) && (missing8 = "revision")) || ((data44.operation === undefined) && (missing8 = "operation"))) || ((data44.instance === undefined) && (missing8 = "instance"))) || ((data44.resource === undefined) && (missing8 = "resource"))) || ((data44.workload === undefined) && (missing8 = "workload"))) || ((data44.incarnation === undefined) && (missing8 = "incarnation"))) || ((data44.desired === undefined) && (missing8 = "desired"))) || ((data44.phase === undefined) && (missing8 = "phase"))) || ((data44.activation === undefined) && (missing8 = "activation"))) || ((data44.last_worker_incarnation === undefined) && (missing8 = "last_worker_incarnation"))){
const err102 = {instancePath:instancePath+"/observation/processes/" + i0+"/binding",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/binding/anyOf/0/required",keyword:"required",params:{missingProperty: missing8},message:"must have required property '"+missing8+"'"};
if(vErrors === null){
vErrors = [err102];
}
else {
vErrors.push(err102);
}
errors++;
}
else {
const _errs147 = errors;
for(const key8 in data44){
if(!(func1.call(schema31.properties.observation.properties.processes.items.anyOf[0].properties.binding.anyOf[0].properties, key8))){
const err103 = {instancePath:instancePath+"/observation/processes/" + i0+"/binding",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/binding/anyOf/0/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key8},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err103];
}
else {
vErrors.push(err103);
}
errors++;
break;
}
}
if(_errs147 === errors){
if(data44.revision !== undefined){
let data45 = data44.revision;
const _errs148 = errors;
if(!(((typeof data45 == "number") && (!(data45 % 1) && !isNaN(data45))) && (isFinite(data45)))){
const err104 = {instancePath:instancePath+"/observation/processes/" + i0+"/binding/revision",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/binding/anyOf/0/properties/revision/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err104];
}
else {
vErrors.push(err104);
}
errors++;
}
if(errors === _errs148){
if((typeof data45 == "number") && (isFinite(data45))){
if(data45 > 9007199254740991 || isNaN(data45)){
const err105 = {instancePath:instancePath+"/observation/processes/" + i0+"/binding/revision",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/binding/anyOf/0/properties/revision/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"};
if(vErrors === null){
vErrors = [err105];
}
else {
vErrors.push(err105);
}
errors++;
}
else {
if(data45 < 0 || isNaN(data45)){
const err106 = {instancePath:instancePath+"/observation/processes/" + i0+"/binding/revision",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/binding/anyOf/0/properties/revision/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err106];
}
else {
vErrors.push(err106);
}
errors++;
}
}
}
}
var valid23 = _errs148 === errors;
}
else {
var valid23 = true;
}
if(valid23){
if(data44.operation !== undefined){
let data46 = data44.operation;
const _errs150 = errors;
if(!(((typeof data46 == "number") && (!(data46 % 1) && !isNaN(data46))) && (isFinite(data46)))){
const err107 = {instancePath:instancePath+"/observation/processes/" + i0+"/binding/operation",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/binding/anyOf/0/properties/operation/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err107];
}
else {
vErrors.push(err107);
}
errors++;
}
if(errors === _errs150){
if((typeof data46 == "number") && (isFinite(data46))){
if(data46 > 9007199254740991 || isNaN(data46)){
const err108 = {instancePath:instancePath+"/observation/processes/" + i0+"/binding/operation",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/binding/anyOf/0/properties/operation/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"};
if(vErrors === null){
vErrors = [err108];
}
else {
vErrors.push(err108);
}
errors++;
}
else {
if(data46 < 0 || isNaN(data46)){
const err109 = {instancePath:instancePath+"/observation/processes/" + i0+"/binding/operation",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/binding/anyOf/0/properties/operation/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err109];
}
else {
vErrors.push(err109);
}
errors++;
}
}
}
}
var valid23 = _errs150 === errors;
}
else {
var valid23 = true;
}
if(valid23){
if(data44.instance !== undefined){
let data47 = data44.instance;
const _errs152 = errors;
if(errors === _errs152){
if(Array.isArray(data47)){
if(data47.length > 16){
const err110 = {instancePath:instancePath+"/observation/processes/" + i0+"/binding/instance",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/binding/anyOf/0/properties/instance/maxItems",keyword:"maxItems",params:{limit: 16},message:"must NOT have more than 16 items"};
if(vErrors === null){
vErrors = [err110];
}
else {
vErrors.push(err110);
}
errors++;
}
else {
if(data47.length < 16){
const err111 = {instancePath:instancePath+"/observation/processes/" + i0+"/binding/instance",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/binding/anyOf/0/properties/instance/minItems",keyword:"minItems",params:{limit: 16},message:"must NOT have fewer than 16 items"};
if(vErrors === null){
vErrors = [err111];
}
else {
vErrors.push(err111);
}
errors++;
}
else {
var valid24 = true;
const len2 = data47.length;
for(let i2=0; i2<len2; i2++){
let data48 = data47[i2];
const _errs154 = errors;
if(!(((typeof data48 == "number") && (!(data48 % 1) && !isNaN(data48))) && (isFinite(data48)))){
const err112 = {instancePath:instancePath+"/observation/processes/" + i0+"/binding/instance/" + i2,schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/binding/anyOf/0/properties/instance/items/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err112];
}
else {
vErrors.push(err112);
}
errors++;
}
if(errors === _errs154){
if((typeof data48 == "number") && (isFinite(data48))){
if(data48 > 255 || isNaN(data48)){
const err113 = {instancePath:instancePath+"/observation/processes/" + i0+"/binding/instance/" + i2,schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/binding/anyOf/0/properties/instance/items/maximum",keyword:"maximum",params:{comparison: "<=", limit: 255},message:"must be <= 255"};
if(vErrors === null){
vErrors = [err113];
}
else {
vErrors.push(err113);
}
errors++;
}
else {
if(data48 < 0 || isNaN(data48)){
const err114 = {instancePath:instancePath+"/observation/processes/" + i0+"/binding/instance/" + i2,schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/binding/anyOf/0/properties/instance/items/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err114];
}
else {
vErrors.push(err114);
}
errors++;
}
}
}
}
var valid24 = _errs154 === errors;
if(!valid24){
break;
}
}
}
}
}
else {
const err115 = {instancePath:instancePath+"/observation/processes/" + i0+"/binding/instance",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/binding/anyOf/0/properties/instance/type",keyword:"type",params:{type: "array"},message:"must be array"};
if(vErrors === null){
vErrors = [err115];
}
else {
vErrors.push(err115);
}
errors++;
}
}
var valid23 = _errs152 === errors;
}
else {
var valid23 = true;
}
if(valid23){
if(data44.resource !== undefined){
let data49 = data44.resource;
const _errs156 = errors;
if(errors === _errs156){
if(Array.isArray(data49)){
if(data49.length > 32){
const err116 = {instancePath:instancePath+"/observation/processes/" + i0+"/binding/resource",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/binding/anyOf/0/properties/resource/maxItems",keyword:"maxItems",params:{limit: 32},message:"must NOT have more than 32 items"};
if(vErrors === null){
vErrors = [err116];
}
else {
vErrors.push(err116);
}
errors++;
}
else {
if(data49.length < 32){
const err117 = {instancePath:instancePath+"/observation/processes/" + i0+"/binding/resource",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/binding/anyOf/0/properties/resource/minItems",keyword:"minItems",params:{limit: 32},message:"must NOT have fewer than 32 items"};
if(vErrors === null){
vErrors = [err117];
}
else {
vErrors.push(err117);
}
errors++;
}
else {
var valid25 = true;
const len3 = data49.length;
for(let i3=0; i3<len3; i3++){
let data50 = data49[i3];
const _errs158 = errors;
if(!(((typeof data50 == "number") && (!(data50 % 1) && !isNaN(data50))) && (isFinite(data50)))){
const err118 = {instancePath:instancePath+"/observation/processes/" + i0+"/binding/resource/" + i3,schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/binding/anyOf/0/properties/resource/items/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err118];
}
else {
vErrors.push(err118);
}
errors++;
}
if(errors === _errs158){
if((typeof data50 == "number") && (isFinite(data50))){
if(data50 > 255 || isNaN(data50)){
const err119 = {instancePath:instancePath+"/observation/processes/" + i0+"/binding/resource/" + i3,schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/binding/anyOf/0/properties/resource/items/maximum",keyword:"maximum",params:{comparison: "<=", limit: 255},message:"must be <= 255"};
if(vErrors === null){
vErrors = [err119];
}
else {
vErrors.push(err119);
}
errors++;
}
else {
if(data50 < 0 || isNaN(data50)){
const err120 = {instancePath:instancePath+"/observation/processes/" + i0+"/binding/resource/" + i3,schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/binding/anyOf/0/properties/resource/items/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err120];
}
else {
vErrors.push(err120);
}
errors++;
}
}
}
}
var valid25 = _errs158 === errors;
if(!valid25){
break;
}
}
}
}
}
else {
const err121 = {instancePath:instancePath+"/observation/processes/" + i0+"/binding/resource",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/binding/anyOf/0/properties/resource/type",keyword:"type",params:{type: "array"},message:"must be array"};
if(vErrors === null){
vErrors = [err121];
}
else {
vErrors.push(err121);
}
errors++;
}
}
var valid23 = _errs156 === errors;
}
else {
var valid23 = true;
}
if(valid23){
if(data44.workload !== undefined){
let data51 = data44.workload;
const _errs160 = errors;
if(errors === _errs160){
if(Array.isArray(data51)){
if(data51.length > 32){
const err122 = {instancePath:instancePath+"/observation/processes/" + i0+"/binding/workload",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/binding/anyOf/0/properties/workload/maxItems",keyword:"maxItems",params:{limit: 32},message:"must NOT have more than 32 items"};
if(vErrors === null){
vErrors = [err122];
}
else {
vErrors.push(err122);
}
errors++;
}
else {
if(data51.length < 32){
const err123 = {instancePath:instancePath+"/observation/processes/" + i0+"/binding/workload",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/binding/anyOf/0/properties/workload/minItems",keyword:"minItems",params:{limit: 32},message:"must NOT have fewer than 32 items"};
if(vErrors === null){
vErrors = [err123];
}
else {
vErrors.push(err123);
}
errors++;
}
else {
var valid26 = true;
const len4 = data51.length;
for(let i4=0; i4<len4; i4++){
let data52 = data51[i4];
const _errs162 = errors;
if(!(((typeof data52 == "number") && (!(data52 % 1) && !isNaN(data52))) && (isFinite(data52)))){
const err124 = {instancePath:instancePath+"/observation/processes/" + i0+"/binding/workload/" + i4,schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/binding/anyOf/0/properties/workload/items/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err124];
}
else {
vErrors.push(err124);
}
errors++;
}
if(errors === _errs162){
if((typeof data52 == "number") && (isFinite(data52))){
if(data52 > 255 || isNaN(data52)){
const err125 = {instancePath:instancePath+"/observation/processes/" + i0+"/binding/workload/" + i4,schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/binding/anyOf/0/properties/workload/items/maximum",keyword:"maximum",params:{comparison: "<=", limit: 255},message:"must be <= 255"};
if(vErrors === null){
vErrors = [err125];
}
else {
vErrors.push(err125);
}
errors++;
}
else {
if(data52 < 0 || isNaN(data52)){
const err126 = {instancePath:instancePath+"/observation/processes/" + i0+"/binding/workload/" + i4,schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/binding/anyOf/0/properties/workload/items/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err126];
}
else {
vErrors.push(err126);
}
errors++;
}
}
}
}
var valid26 = _errs162 === errors;
if(!valid26){
break;
}
}
}
}
}
else {
const err127 = {instancePath:instancePath+"/observation/processes/" + i0+"/binding/workload",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/binding/anyOf/0/properties/workload/type",keyword:"type",params:{type: "array"},message:"must be array"};
if(vErrors === null){
vErrors = [err127];
}
else {
vErrors.push(err127);
}
errors++;
}
}
var valid23 = _errs160 === errors;
}
else {
var valid23 = true;
}
if(valid23){
if(data44.incarnation !== undefined){
let data53 = data44.incarnation;
const _errs164 = errors;
const _errs165 = errors;
let valid27 = false;
const _errs166 = errors;
if(errors === _errs166){
if(Array.isArray(data53)){
if(data53.length > 16){
const err128 = {instancePath:instancePath+"/observation/processes/" + i0+"/binding/incarnation",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/binding/anyOf/0/properties/incarnation/anyOf/0/maxItems",keyword:"maxItems",params:{limit: 16},message:"must NOT have more than 16 items"};
if(vErrors === null){
vErrors = [err128];
}
else {
vErrors.push(err128);
}
errors++;
}
else {
if(data53.length < 16){
const err129 = {instancePath:instancePath+"/observation/processes/" + i0+"/binding/incarnation",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/binding/anyOf/0/properties/incarnation/anyOf/0/minItems",keyword:"minItems",params:{limit: 16},message:"must NOT have fewer than 16 items"};
if(vErrors === null){
vErrors = [err129];
}
else {
vErrors.push(err129);
}
errors++;
}
else {
var valid28 = true;
const len5 = data53.length;
for(let i5=0; i5<len5; i5++){
let data54 = data53[i5];
const _errs168 = errors;
if(!(((typeof data54 == "number") && (!(data54 % 1) && !isNaN(data54))) && (isFinite(data54)))){
const err130 = {instancePath:instancePath+"/observation/processes/" + i0+"/binding/incarnation/" + i5,schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/binding/anyOf/0/properties/incarnation/anyOf/0/items/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err130];
}
else {
vErrors.push(err130);
}
errors++;
}
if(errors === _errs168){
if((typeof data54 == "number") && (isFinite(data54))){
if(data54 > 255 || isNaN(data54)){
const err131 = {instancePath:instancePath+"/observation/processes/" + i0+"/binding/incarnation/" + i5,schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/binding/anyOf/0/properties/incarnation/anyOf/0/items/maximum",keyword:"maximum",params:{comparison: "<=", limit: 255},message:"must be <= 255"};
if(vErrors === null){
vErrors = [err131];
}
else {
vErrors.push(err131);
}
errors++;
}
else {
if(data54 < 0 || isNaN(data54)){
const err132 = {instancePath:instancePath+"/observation/processes/" + i0+"/binding/incarnation/" + i5,schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/binding/anyOf/0/properties/incarnation/anyOf/0/items/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err132];
}
else {
vErrors.push(err132);
}
errors++;
}
}
}
}
var valid28 = _errs168 === errors;
if(!valid28){
break;
}
}
}
}
}
else {
const err133 = {instancePath:instancePath+"/observation/processes/" + i0+"/binding/incarnation",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/binding/anyOf/0/properties/incarnation/anyOf/0/type",keyword:"type",params:{type: "array"},message:"must be array"};
if(vErrors === null){
vErrors = [err133];
}
else {
vErrors.push(err133);
}
errors++;
}
}
var _valid13 = _errs166 === errors;
valid27 = valid27 || _valid13;
const _errs170 = errors;
if(data53 !== null){
const err134 = {instancePath:instancePath+"/observation/processes/" + i0+"/binding/incarnation",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/binding/anyOf/0/properties/incarnation/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err134];
}
else {
vErrors.push(err134);
}
errors++;
}
var _valid13 = _errs170 === errors;
valid27 = valid27 || _valid13;
if(!valid27){
const err135 = {instancePath:instancePath+"/observation/processes/" + i0+"/binding/incarnation",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/binding/anyOf/0/properties/incarnation/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err135];
}
else {
vErrors.push(err135);
}
errors++;
}
else {
errors = _errs165;
if(vErrors !== null){
if(_errs165){
vErrors.length = _errs165;
}
else {
vErrors = null;
}
}
}
var valid23 = _errs164 === errors;
}
else {
var valid23 = true;
}
if(valid23){
if(data44.desired !== undefined){
let data55 = data44.desired;
const _errs172 = errors;
if(typeof data55 !== "string"){
const err136 = {instancePath:instancePath+"/observation/processes/" + i0+"/binding/desired",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/binding/anyOf/0/properties/desired/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err136];
}
else {
vErrors.push(err136);
}
errors++;
}
if(!((data55 === "running") || (data55 === "stopped"))){
const err137 = {instancePath:instancePath+"/observation/processes/" + i0+"/binding/desired",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/binding/anyOf/0/properties/desired/enum",keyword:"enum",params:{allowedValues: schema31.properties.observation.properties.processes.items.anyOf[0].properties.binding.anyOf[0].properties.desired.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err137];
}
else {
vErrors.push(err137);
}
errors++;
}
var valid23 = _errs172 === errors;
}
else {
var valid23 = true;
}
if(valid23){
if(data44.phase !== undefined){
let data56 = data44.phase;
const _errs174 = errors;
if(typeof data56 !== "string"){
const err138 = {instancePath:instancePath+"/observation/processes/" + i0+"/binding/phase",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/binding/anyOf/0/properties/phase/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err138];
}
else {
vErrors.push(err138);
}
errors++;
}
if(!((((data56 === "pending") || (data56 === "unknown")) || (data56 === "ready")) || (data56 === "stopped"))){
const err139 = {instancePath:instancePath+"/observation/processes/" + i0+"/binding/phase",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/binding/anyOf/0/properties/phase/enum",keyword:"enum",params:{allowedValues: schema31.properties.observation.properties.processes.items.anyOf[0].properties.binding.anyOf[0].properties.phase.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err139];
}
else {
vErrors.push(err139);
}
errors++;
}
var valid23 = _errs174 === errors;
}
else {
var valid23 = true;
}
if(valid23){
if(data44.upgrade_from !== undefined){
let data57 = data44.upgrade_from;
const _errs176 = errors;
const _errs177 = errors;
let valid29 = false;
const _errs178 = errors;
if(errors === _errs178){
if(Array.isArray(data57)){
if(data57.length > 32){
const err140 = {instancePath:instancePath+"/observation/processes/" + i0+"/binding/upgrade_from",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/binding/anyOf/0/properties/upgrade_from/anyOf/0/maxItems",keyword:"maxItems",params:{limit: 32},message:"must NOT have more than 32 items"};
if(vErrors === null){
vErrors = [err140];
}
else {
vErrors.push(err140);
}
errors++;
}
else {
if(data57.length < 32){
const err141 = {instancePath:instancePath+"/observation/processes/" + i0+"/binding/upgrade_from",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/binding/anyOf/0/properties/upgrade_from/anyOf/0/minItems",keyword:"minItems",params:{limit: 32},message:"must NOT have fewer than 32 items"};
if(vErrors === null){
vErrors = [err141];
}
else {
vErrors.push(err141);
}
errors++;
}
else {
var valid30 = true;
const len6 = data57.length;
for(let i6=0; i6<len6; i6++){
let data58 = data57[i6];
const _errs180 = errors;
if(!(((typeof data58 == "number") && (!(data58 % 1) && !isNaN(data58))) && (isFinite(data58)))){
const err142 = {instancePath:instancePath+"/observation/processes/" + i0+"/binding/upgrade_from/" + i6,schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/binding/anyOf/0/properties/upgrade_from/anyOf/0/items/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err142];
}
else {
vErrors.push(err142);
}
errors++;
}
if(errors === _errs180){
if((typeof data58 == "number") && (isFinite(data58))){
if(data58 > 255 || isNaN(data58)){
const err143 = {instancePath:instancePath+"/observation/processes/" + i0+"/binding/upgrade_from/" + i6,schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/binding/anyOf/0/properties/upgrade_from/anyOf/0/items/maximum",keyword:"maximum",params:{comparison: "<=", limit: 255},message:"must be <= 255"};
if(vErrors === null){
vErrors = [err143];
}
else {
vErrors.push(err143);
}
errors++;
}
else {
if(data58 < 0 || isNaN(data58)){
const err144 = {instancePath:instancePath+"/observation/processes/" + i0+"/binding/upgrade_from/" + i6,schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/binding/anyOf/0/properties/upgrade_from/anyOf/0/items/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
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
}
var valid30 = _errs180 === errors;
if(!valid30){
break;
}
}
}
}
}
else {
const err145 = {instancePath:instancePath+"/observation/processes/" + i0+"/binding/upgrade_from",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/binding/anyOf/0/properties/upgrade_from/anyOf/0/type",keyword:"type",params:{type: "array"},message:"must be array"};
if(vErrors === null){
vErrors = [err145];
}
else {
vErrors.push(err145);
}
errors++;
}
}
var _valid14 = _errs178 === errors;
valid29 = valid29 || _valid14;
const _errs182 = errors;
if(data57 !== null){
const err146 = {instancePath:instancePath+"/observation/processes/" + i0+"/binding/upgrade_from",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/binding/anyOf/0/properties/upgrade_from/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err146];
}
else {
vErrors.push(err146);
}
errors++;
}
var _valid14 = _errs182 === errors;
valid29 = valid29 || _valid14;
if(!valid29){
const err147 = {instancePath:instancePath+"/observation/processes/" + i0+"/binding/upgrade_from",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/binding/anyOf/0/properties/upgrade_from/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err147];
}
else {
vErrors.push(err147);
}
errors++;
}
else {
errors = _errs177;
if(vErrors !== null){
if(_errs177){
vErrors.length = _errs177;
}
else {
vErrors = null;
}
}
}
var valid23 = _errs176 === errors;
}
else {
var valid23 = true;
}
if(valid23){
if(data44.activation !== undefined){
let data59 = data44.activation;
const _errs184 = errors;
const _errs185 = errors;
let valid31 = false;
const _errs186 = errors;
if(errors === _errs186){
if(data59 && typeof data59 == "object" && !Array.isArray(data59)){
let missing9;
if(((data59.worker_incarnation === undefined) && (missing9 = "worker_incarnation")) || ((data59.generation === undefined) && (missing9 = "generation"))){
const err148 = {instancePath:instancePath+"/observation/processes/" + i0+"/binding/activation",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/binding/anyOf/0/properties/activation/anyOf/0/required",keyword:"required",params:{missingProperty: missing9},message:"must have required property '"+missing9+"'"};
if(vErrors === null){
vErrors = [err148];
}
else {
vErrors.push(err148);
}
errors++;
}
else {
const _errs188 = errors;
for(const key9 in data59){
if(!((key9 === "worker_incarnation") || (key9 === "generation"))){
const err149 = {instancePath:instancePath+"/observation/processes/" + i0+"/binding/activation",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/binding/anyOf/0/properties/activation/anyOf/0/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key9},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err149];
}
else {
vErrors.push(err149);
}
errors++;
break;
}
}
if(_errs188 === errors){
if(data59.worker_incarnation !== undefined){
let data60 = data59.worker_incarnation;
const _errs189 = errors;
if(errors === _errs189){
if(Array.isArray(data60)){
if(data60.length > 16){
const err150 = {instancePath:instancePath+"/observation/processes/" + i0+"/binding/activation/worker_incarnation",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/binding/anyOf/0/properties/activation/anyOf/0/properties/worker_incarnation/maxItems",keyword:"maxItems",params:{limit: 16},message:"must NOT have more than 16 items"};
if(vErrors === null){
vErrors = [err150];
}
else {
vErrors.push(err150);
}
errors++;
}
else {
if(data60.length < 16){
const err151 = {instancePath:instancePath+"/observation/processes/" + i0+"/binding/activation/worker_incarnation",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/binding/anyOf/0/properties/activation/anyOf/0/properties/worker_incarnation/minItems",keyword:"minItems",params:{limit: 16},message:"must NOT have fewer than 16 items"};
if(vErrors === null){
vErrors = [err151];
}
else {
vErrors.push(err151);
}
errors++;
}
else {
var valid33 = true;
const len7 = data60.length;
for(let i7=0; i7<len7; i7++){
let data61 = data60[i7];
const _errs191 = errors;
if(!(((typeof data61 == "number") && (!(data61 % 1) && !isNaN(data61))) && (isFinite(data61)))){
const err152 = {instancePath:instancePath+"/observation/processes/" + i0+"/binding/activation/worker_incarnation/" + i7,schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/binding/anyOf/0/properties/activation/anyOf/0/properties/worker_incarnation/items/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err152];
}
else {
vErrors.push(err152);
}
errors++;
}
if(errors === _errs191){
if((typeof data61 == "number") && (isFinite(data61))){
if(data61 > 255 || isNaN(data61)){
const err153 = {instancePath:instancePath+"/observation/processes/" + i0+"/binding/activation/worker_incarnation/" + i7,schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/binding/anyOf/0/properties/activation/anyOf/0/properties/worker_incarnation/items/maximum",keyword:"maximum",params:{comparison: "<=", limit: 255},message:"must be <= 255"};
if(vErrors === null){
vErrors = [err153];
}
else {
vErrors.push(err153);
}
errors++;
}
else {
if(data61 < 0 || isNaN(data61)){
const err154 = {instancePath:instancePath+"/observation/processes/" + i0+"/binding/activation/worker_incarnation/" + i7,schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/binding/anyOf/0/properties/activation/anyOf/0/properties/worker_incarnation/items/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
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
}
var valid33 = _errs191 === errors;
if(!valid33){
break;
}
}
}
}
}
else {
const err155 = {instancePath:instancePath+"/observation/processes/" + i0+"/binding/activation/worker_incarnation",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/binding/anyOf/0/properties/activation/anyOf/0/properties/worker_incarnation/type",keyword:"type",params:{type: "array"},message:"must be array"};
if(vErrors === null){
vErrors = [err155];
}
else {
vErrors.push(err155);
}
errors++;
}
}
var valid32 = _errs189 === errors;
}
else {
var valid32 = true;
}
if(valid32){
if(data59.generation !== undefined){
let data62 = data59.generation;
const _errs193 = errors;
if(!(((typeof data62 == "number") && (!(data62 % 1) && !isNaN(data62))) && (isFinite(data62)))){
const err156 = {instancePath:instancePath+"/observation/processes/" + i0+"/binding/activation/generation",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/binding/anyOf/0/properties/activation/anyOf/0/properties/generation/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err156];
}
else {
vErrors.push(err156);
}
errors++;
}
if(errors === _errs193){
if((typeof data62 == "number") && (isFinite(data62))){
if(data62 > 9007199254740991 || isNaN(data62)){
const err157 = {instancePath:instancePath+"/observation/processes/" + i0+"/binding/activation/generation",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/binding/anyOf/0/properties/activation/anyOf/0/properties/generation/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"};
if(vErrors === null){
vErrors = [err157];
}
else {
vErrors.push(err157);
}
errors++;
}
else {
if(data62 < 0 || isNaN(data62)){
const err158 = {instancePath:instancePath+"/observation/processes/" + i0+"/binding/activation/generation",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/binding/anyOf/0/properties/activation/anyOf/0/properties/generation/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err158];
}
else {
vErrors.push(err158);
}
errors++;
}
}
}
}
var valid32 = _errs193 === errors;
}
else {
var valid32 = true;
}
}
}
}
}
else {
const err159 = {instancePath:instancePath+"/observation/processes/" + i0+"/binding/activation",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/binding/anyOf/0/properties/activation/anyOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err159];
}
else {
vErrors.push(err159);
}
errors++;
}
}
var _valid15 = _errs186 === errors;
valid31 = valid31 || _valid15;
const _errs195 = errors;
if(data59 !== null){
const err160 = {instancePath:instancePath+"/observation/processes/" + i0+"/binding/activation",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/binding/anyOf/0/properties/activation/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err160];
}
else {
vErrors.push(err160);
}
errors++;
}
var _valid15 = _errs195 === errors;
valid31 = valid31 || _valid15;
if(!valid31){
const err161 = {instancePath:instancePath+"/observation/processes/" + i0+"/binding/activation",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/binding/anyOf/0/properties/activation/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err161];
}
else {
vErrors.push(err161);
}
errors++;
}
else {
errors = _errs185;
if(vErrors !== null){
if(_errs185){
vErrors.length = _errs185;
}
else {
vErrors = null;
}
}
}
var valid23 = _errs184 === errors;
}
else {
var valid23 = true;
}
if(valid23){
if(data44.last_worker_incarnation !== undefined){
let data63 = data44.last_worker_incarnation;
const _errs197 = errors;
const _errs198 = errors;
let valid34 = false;
const _errs199 = errors;
if(errors === _errs199){
if(Array.isArray(data63)){
if(data63.length > 16){
const err162 = {instancePath:instancePath+"/observation/processes/" + i0+"/binding/last_worker_incarnation",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/binding/anyOf/0/properties/last_worker_incarnation/anyOf/0/maxItems",keyword:"maxItems",params:{limit: 16},message:"must NOT have more than 16 items"};
if(vErrors === null){
vErrors = [err162];
}
else {
vErrors.push(err162);
}
errors++;
}
else {
if(data63.length < 16){
const err163 = {instancePath:instancePath+"/observation/processes/" + i0+"/binding/last_worker_incarnation",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/binding/anyOf/0/properties/last_worker_incarnation/anyOf/0/minItems",keyword:"minItems",params:{limit: 16},message:"must NOT have fewer than 16 items"};
if(vErrors === null){
vErrors = [err163];
}
else {
vErrors.push(err163);
}
errors++;
}
else {
var valid35 = true;
const len8 = data63.length;
for(let i8=0; i8<len8; i8++){
let data64 = data63[i8];
const _errs201 = errors;
if(!(((typeof data64 == "number") && (!(data64 % 1) && !isNaN(data64))) && (isFinite(data64)))){
const err164 = {instancePath:instancePath+"/observation/processes/" + i0+"/binding/last_worker_incarnation/" + i8,schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/binding/anyOf/0/properties/last_worker_incarnation/anyOf/0/items/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err164];
}
else {
vErrors.push(err164);
}
errors++;
}
if(errors === _errs201){
if((typeof data64 == "number") && (isFinite(data64))){
if(data64 > 255 || isNaN(data64)){
const err165 = {instancePath:instancePath+"/observation/processes/" + i0+"/binding/last_worker_incarnation/" + i8,schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/binding/anyOf/0/properties/last_worker_incarnation/anyOf/0/items/maximum",keyword:"maximum",params:{comparison: "<=", limit: 255},message:"must be <= 255"};
if(vErrors === null){
vErrors = [err165];
}
else {
vErrors.push(err165);
}
errors++;
}
else {
if(data64 < 0 || isNaN(data64)){
const err166 = {instancePath:instancePath+"/observation/processes/" + i0+"/binding/last_worker_incarnation/" + i8,schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/binding/anyOf/0/properties/last_worker_incarnation/anyOf/0/items/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err166];
}
else {
vErrors.push(err166);
}
errors++;
}
}
}
}
var valid35 = _errs201 === errors;
if(!valid35){
break;
}
}
}
}
}
else {
const err167 = {instancePath:instancePath+"/observation/processes/" + i0+"/binding/last_worker_incarnation",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/binding/anyOf/0/properties/last_worker_incarnation/anyOf/0/type",keyword:"type",params:{type: "array"},message:"must be array"};
if(vErrors === null){
vErrors = [err167];
}
else {
vErrors.push(err167);
}
errors++;
}
}
var _valid16 = _errs199 === errors;
valid34 = valid34 || _valid16;
const _errs203 = errors;
if(data63 !== null){
const err168 = {instancePath:instancePath+"/observation/processes/" + i0+"/binding/last_worker_incarnation",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/binding/anyOf/0/properties/last_worker_incarnation/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err168];
}
else {
vErrors.push(err168);
}
errors++;
}
var _valid16 = _errs203 === errors;
valid34 = valid34 || _valid16;
if(!valid34){
const err169 = {instancePath:instancePath+"/observation/processes/" + i0+"/binding/last_worker_incarnation",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/binding/anyOf/0/properties/last_worker_incarnation/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err169];
}
else {
vErrors.push(err169);
}
errors++;
}
else {
errors = _errs198;
if(vErrors !== null){
if(_errs198){
vErrors.length = _errs198;
}
else {
vErrors = null;
}
}
}
var valid23 = _errs197 === errors;
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
}
}
}
else {
const err170 = {instancePath:instancePath+"/observation/processes/" + i0+"/binding",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/binding/anyOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err170];
}
else {
vErrors.push(err170);
}
errors++;
}
}
var _valid12 = _errs145 === errors;
valid22 = valid22 || _valid12;
const _errs205 = errors;
if(data44 !== null){
const err171 = {instancePath:instancePath+"/observation/processes/" + i0+"/binding",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/binding/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err171];
}
else {
vErrors.push(err171);
}
errors++;
}
var _valid12 = _errs205 === errors;
valid22 = valid22 || _valid12;
if(!valid22){
const err172 = {instancePath:instancePath+"/observation/processes/" + i0+"/binding",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/binding/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err172];
}
else {
vErrors.push(err172);
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
var valid9 = _errs143 === errors;
}
else {
var valid9 = true;
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
}
}
}
}
}
else {
const err173 = {instancePath:instancePath+"/observation/processes/" + i0,schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err173];
}
else {
vErrors.push(err173);
}
errors++;
}
}
var _valid3 = _errs55 === errors;
valid8 = valid8 || _valid3;
const _errs207 = errors;
if(data18 !== null){
const err174 = {instancePath:instancePath+"/observation/processes/" + i0,schemaPath:"#/properties/observation/properties/processes/items/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err174];
}
else {
vErrors.push(err174);
}
errors++;
}
var _valid3 = _errs207 === errors;
valid8 = valid8 || _valid3;
if(!valid8){
const err175 = {instancePath:instancePath+"/observation/processes/" + i0,schemaPath:"#/properties/observation/properties/processes/items/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err175];
}
else {
vErrors.push(err175);
}
errors++;
validate20.errors = vErrors;
return false;
}
else {
errors = _errs54;
if(vErrors !== null){
if(_errs54){
vErrors.length = _errs54;
}
else {
vErrors = null;
}
}
}
var valid7 = _errs53 === errors;
if(!valid7){
break;
}
}
}
}
}
else {
validate20.errors = [{instancePath:instancePath+"/observation/processes",schemaPath:"#/properties/observation/properties/processes/type",keyword:"type",params:{type: "array"},message:"must be array"}];
return false;
}
}
var valid1 = _errs51 === errors;
}
else {
var valid1 = true;
}
if(valid1){
if(data0.events !== undefined){
let data65 = data0.events;
const _errs209 = errors;
if(errors === _errs209){
if(Array.isArray(data65)){
if(data65.length > 16){
validate20.errors = [{instancePath:instancePath+"/observation/events",schemaPath:"#/properties/observation/properties/events/maxItems",keyword:"maxItems",params:{limit: 16},message:"must NOT have more than 16 items"}];
return false;
}
else {
if(data65.length < 16){
validate20.errors = [{instancePath:instancePath+"/observation/events",schemaPath:"#/properties/observation/properties/events/minItems",keyword:"minItems",params:{limit: 16},message:"must NOT have fewer than 16 items"}];
return false;
}
else {
var valid36 = true;
const len9 = data65.length;
for(let i9=0; i9<len9; i9++){
let data66 = data65[i9];
const _errs211 = errors;
const _errs212 = errors;
let valid37 = false;
const _errs213 = errors;
if(errors === _errs213){
if(data66 && typeof data66 == "object" && !Array.isArray(data66)){
let missing10;
if(((((((((((((((data66.position === undefined) && (missing10 = "position")) || ((data66.pid === undefined) && (missing10 = "pid"))) || ((data66.kind === undefined) && (missing10 = "kind"))) || ((data66.policy_revision === undefined) && (missing10 = "policy_revision"))) || ((data66.input === undefined) && (missing10 = "input"))) || ((data66.effect === undefined) && (missing10 = "effect"))) || ((data66.output === undefined) && (missing10 = "output"))) || ((data66.value === undefined) && (missing10 = "value"))) || ((data66.failed === undefined) && (missing10 = "failed"))) || ((data66.generation === undefined) && (missing10 = "generation"))) || ((data66.mailbox_status === undefined) && (missing10 = "mailbox_status"))) || ((data66.admitted === undefined) && (missing10 = "admitted"))) || ((data66.unix_ms === undefined) && (missing10 = "unix_ms"))) || ((data66.clock_error_ms === undefined) && (missing10 = "clock_error_ms"))){
const err176 = {instancePath:instancePath+"/observation/events/" + i9,schemaPath:"#/properties/observation/properties/events/items/anyOf/0/required",keyword:"required",params:{missingProperty: missing10},message:"must have required property '"+missing10+"'"};
if(vErrors === null){
vErrors = [err176];
}
else {
vErrors.push(err176);
}
errors++;
}
else {
const _errs215 = errors;
for(const key10 in data66){
if(!(func1.call(schema31.properties.observation.properties.events.items.anyOf[0].properties, key10))){
const err177 = {instancePath:instancePath+"/observation/events/" + i9,schemaPath:"#/properties/observation/properties/events/items/anyOf/0/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key10},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err177];
}
else {
vErrors.push(err177);
}
errors++;
break;
}
}
if(_errs215 === errors){
if(data66.position !== undefined){
let data67 = data66.position;
const _errs216 = errors;
if(!(((typeof data67 == "number") && (!(data67 % 1) && !isNaN(data67))) && (isFinite(data67)))){
const err178 = {instancePath:instancePath+"/observation/events/" + i9+"/position",schemaPath:"#/properties/observation/properties/events/items/anyOf/0/properties/position/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err178];
}
else {
vErrors.push(err178);
}
errors++;
}
if(errors === _errs216){
if((typeof data67 == "number") && (isFinite(data67))){
if(data67 > 9007199254740991 || isNaN(data67)){
const err179 = {instancePath:instancePath+"/observation/events/" + i9+"/position",schemaPath:"#/properties/observation/properties/events/items/anyOf/0/properties/position/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"};
if(vErrors === null){
vErrors = [err179];
}
else {
vErrors.push(err179);
}
errors++;
}
else {
if(data67 < 0 || isNaN(data67)){
const err180 = {instancePath:instancePath+"/observation/events/" + i9+"/position",schemaPath:"#/properties/observation/properties/events/items/anyOf/0/properties/position/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err180];
}
else {
vErrors.push(err180);
}
errors++;
}
}
}
}
var valid38 = _errs216 === errors;
}
else {
var valid38 = true;
}
if(valid38){
if(data66.pid !== undefined){
let data68 = data66.pid;
const _errs218 = errors;
if(!(((typeof data68 == "number") && (!(data68 % 1) && !isNaN(data68))) && (isFinite(data68)))){
const err181 = {instancePath:instancePath+"/observation/events/" + i9+"/pid",schemaPath:"#/properties/observation/properties/events/items/anyOf/0/properties/pid/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err181];
}
else {
vErrors.push(err181);
}
errors++;
}
if(errors === _errs218){
if((typeof data68 == "number") && (isFinite(data68))){
if(data68 > 9007199254740991 || isNaN(data68)){
const err182 = {instancePath:instancePath+"/observation/events/" + i9+"/pid",schemaPath:"#/properties/observation/properties/events/items/anyOf/0/properties/pid/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"};
if(vErrors === null){
vErrors = [err182];
}
else {
vErrors.push(err182);
}
errors++;
}
else {
if(data68 < 0 || isNaN(data68)){
const err183 = {instancePath:instancePath+"/observation/events/" + i9+"/pid",schemaPath:"#/properties/observation/properties/events/items/anyOf/0/properties/pid/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err183];
}
else {
vErrors.push(err183);
}
errors++;
}
}
}
}
var valid38 = _errs218 === errors;
}
else {
var valid38 = true;
}
if(valid38){
if(data66.kind !== undefined){
let data69 = data66.kind;
const _errs220 = errors;
if(typeof data69 !== "string"){
const err184 = {instancePath:instancePath+"/observation/events/" + i9+"/kind",schemaPath:"#/properties/observation/properties/events/items/anyOf/0/properties/kind/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err184];
}
else {
vErrors.push(err184);
}
errors++;
}
if(!((((((((((((((((((((((((((((data69 === "lifecycle") || (data69 === "catalog_retention")) || (data69 === "collect")) || (data69 === "grant")) || (data69 === "revoke")) || (data69 === "spawn")) || (data69 === "own")) || (data69 === "runtime_intent")) || (data69 === "runtime_observe")) || (data69 === "activate")) || (data69 === "send")) || (data69 === "begin_turn")) || (data69 === "turn")) || (data69 === "deliver_next")) || (data69 === "deliver")) || (data69 === "dispatch")) || (data69 === "observe")) || (data69 === "close_effect")) || (data69 === "terminate")) || (data69 === "expire")) || (data69 === "inspect")) || (data69 === "checkpoint")) || (data69 === "declare_payload")) || (data69 === "payload_ready")) || (data69 === "retire_payload")) || (data69 === "payload_deleted")) || (data69 === "runtime_upgrade")) || (data69 === "state"))){
const err185 = {instancePath:instancePath+"/observation/events/" + i9+"/kind",schemaPath:"#/properties/observation/properties/events/items/anyOf/0/properties/kind/enum",keyword:"enum",params:{allowedValues: schema31.properties.observation.properties.events.items.anyOf[0].properties.kind.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err185];
}
else {
vErrors.push(err185);
}
errors++;
}
var valid38 = _errs220 === errors;
}
else {
var valid38 = true;
}
if(valid38){
if(data66.policy_revision !== undefined){
let data70 = data66.policy_revision;
const _errs222 = errors;
if(!(((typeof data70 == "number") && (!(data70 % 1) && !isNaN(data70))) && (isFinite(data70)))){
const err186 = {instancePath:instancePath+"/observation/events/" + i9+"/policy_revision",schemaPath:"#/properties/observation/properties/events/items/anyOf/0/properties/policy_revision/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err186];
}
else {
vErrors.push(err186);
}
errors++;
}
if(errors === _errs222){
if((typeof data70 == "number") && (isFinite(data70))){
if(data70 > 9007199254740991 || isNaN(data70)){
const err187 = {instancePath:instancePath+"/observation/events/" + i9+"/policy_revision",schemaPath:"#/properties/observation/properties/events/items/anyOf/0/properties/policy_revision/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"};
if(vErrors === null){
vErrors = [err187];
}
else {
vErrors.push(err187);
}
errors++;
}
else {
if(data70 < 0 || isNaN(data70)){
const err188 = {instancePath:instancePath+"/observation/events/" + i9+"/policy_revision",schemaPath:"#/properties/observation/properties/events/items/anyOf/0/properties/policy_revision/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err188];
}
else {
vErrors.push(err188);
}
errors++;
}
}
}
}
var valid38 = _errs222 === errors;
}
else {
var valid38 = true;
}
if(valid38){
if(data66.input !== undefined){
let data71 = data66.input;
const _errs224 = errors;
const _errs225 = errors;
let valid39 = false;
const _errs226 = errors;
if(!(((typeof data71 == "number") && (!(data71 % 1) && !isNaN(data71))) && (isFinite(data71)))){
const err189 = {instancePath:instancePath+"/observation/events/" + i9+"/input",schemaPath:"#/properties/observation/properties/events/items/anyOf/0/properties/input/anyOf/0/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err189];
}
else {
vErrors.push(err189);
}
errors++;
}
if(errors === _errs226){
if((typeof data71 == "number") && (isFinite(data71))){
if(data71 > 9007199254740991 || isNaN(data71)){
const err190 = {instancePath:instancePath+"/observation/events/" + i9+"/input",schemaPath:"#/properties/observation/properties/events/items/anyOf/0/properties/input/anyOf/0/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"};
if(vErrors === null){
vErrors = [err190];
}
else {
vErrors.push(err190);
}
errors++;
}
else {
if(data71 < 0 || isNaN(data71)){
const err191 = {instancePath:instancePath+"/observation/events/" + i9+"/input",schemaPath:"#/properties/observation/properties/events/items/anyOf/0/properties/input/anyOf/0/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err191];
}
else {
vErrors.push(err191);
}
errors++;
}
}
}
}
var _valid18 = _errs226 === errors;
valid39 = valid39 || _valid18;
const _errs228 = errors;
if(data71 !== null){
const err192 = {instancePath:instancePath+"/observation/events/" + i9+"/input",schemaPath:"#/properties/observation/properties/events/items/anyOf/0/properties/input/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err192];
}
else {
vErrors.push(err192);
}
errors++;
}
var _valid18 = _errs228 === errors;
valid39 = valid39 || _valid18;
if(!valid39){
const err193 = {instancePath:instancePath+"/observation/events/" + i9+"/input",schemaPath:"#/properties/observation/properties/events/items/anyOf/0/properties/input/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err193];
}
else {
vErrors.push(err193);
}
errors++;
}
else {
errors = _errs225;
if(vErrors !== null){
if(_errs225){
vErrors.length = _errs225;
}
else {
vErrors = null;
}
}
}
var valid38 = _errs224 === errors;
}
else {
var valid38 = true;
}
if(valid38){
if(data66.effect !== undefined){
let data72 = data66.effect;
const _errs230 = errors;
const _errs231 = errors;
let valid40 = false;
const _errs232 = errors;
if(!(((typeof data72 == "number") && (!(data72 % 1) && !isNaN(data72))) && (isFinite(data72)))){
const err194 = {instancePath:instancePath+"/observation/events/" + i9+"/effect",schemaPath:"#/properties/observation/properties/events/items/anyOf/0/properties/effect/anyOf/0/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err194];
}
else {
vErrors.push(err194);
}
errors++;
}
if(errors === _errs232){
if((typeof data72 == "number") && (isFinite(data72))){
if(data72 > 9007199254740991 || isNaN(data72)){
const err195 = {instancePath:instancePath+"/observation/events/" + i9+"/effect",schemaPath:"#/properties/observation/properties/events/items/anyOf/0/properties/effect/anyOf/0/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"};
if(vErrors === null){
vErrors = [err195];
}
else {
vErrors.push(err195);
}
errors++;
}
else {
if(data72 < 0 || isNaN(data72)){
const err196 = {instancePath:instancePath+"/observation/events/" + i9+"/effect",schemaPath:"#/properties/observation/properties/events/items/anyOf/0/properties/effect/anyOf/0/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err196];
}
else {
vErrors.push(err196);
}
errors++;
}
}
}
}
var _valid19 = _errs232 === errors;
valid40 = valid40 || _valid19;
const _errs234 = errors;
if(data72 !== null){
const err197 = {instancePath:instancePath+"/observation/events/" + i9+"/effect",schemaPath:"#/properties/observation/properties/events/items/anyOf/0/properties/effect/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err197];
}
else {
vErrors.push(err197);
}
errors++;
}
var _valid19 = _errs234 === errors;
valid40 = valid40 || _valid19;
if(!valid40){
const err198 = {instancePath:instancePath+"/observation/events/" + i9+"/effect",schemaPath:"#/properties/observation/properties/events/items/anyOf/0/properties/effect/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err198];
}
else {
vErrors.push(err198);
}
errors++;
}
else {
errors = _errs231;
if(vErrors !== null){
if(_errs231){
vErrors.length = _errs231;
}
else {
vErrors = null;
}
}
}
var valid38 = _errs230 === errors;
}
else {
var valid38 = true;
}
if(valid38){
if(data66.output !== undefined){
let data73 = data66.output;
const _errs236 = errors;
const _errs237 = errors;
let valid41 = false;
const _errs238 = errors;
if(!(((typeof data73 == "number") && (!(data73 % 1) && !isNaN(data73))) && (isFinite(data73)))){
const err199 = {instancePath:instancePath+"/observation/events/" + i9+"/output",schemaPath:"#/properties/observation/properties/events/items/anyOf/0/properties/output/anyOf/0/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err199];
}
else {
vErrors.push(err199);
}
errors++;
}
if(errors === _errs238){
if((typeof data73 == "number") && (isFinite(data73))){
if(data73 > 9007199254740991 || isNaN(data73)){
const err200 = {instancePath:instancePath+"/observation/events/" + i9+"/output",schemaPath:"#/properties/observation/properties/events/items/anyOf/0/properties/output/anyOf/0/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"};
if(vErrors === null){
vErrors = [err200];
}
else {
vErrors.push(err200);
}
errors++;
}
else {
if(data73 < 0 || isNaN(data73)){
const err201 = {instancePath:instancePath+"/observation/events/" + i9+"/output",schemaPath:"#/properties/observation/properties/events/items/anyOf/0/properties/output/anyOf/0/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err201];
}
else {
vErrors.push(err201);
}
errors++;
}
}
}
}
var _valid20 = _errs238 === errors;
valid41 = valid41 || _valid20;
const _errs240 = errors;
if(data73 !== null){
const err202 = {instancePath:instancePath+"/observation/events/" + i9+"/output",schemaPath:"#/properties/observation/properties/events/items/anyOf/0/properties/output/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err202];
}
else {
vErrors.push(err202);
}
errors++;
}
var _valid20 = _errs240 === errors;
valid41 = valid41 || _valid20;
if(!valid41){
const err203 = {instancePath:instancePath+"/observation/events/" + i9+"/output",schemaPath:"#/properties/observation/properties/events/items/anyOf/0/properties/output/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err203];
}
else {
vErrors.push(err203);
}
errors++;
}
else {
errors = _errs237;
if(vErrors !== null){
if(_errs237){
vErrors.length = _errs237;
}
else {
vErrors = null;
}
}
}
var valid38 = _errs236 === errors;
}
else {
var valid38 = true;
}
if(valid38){
if(data66.value !== undefined){
let data74 = data66.value;
const _errs242 = errors;
const _errs243 = errors;
let valid42 = false;
const _errs244 = errors;
if(errors === _errs244){
if(typeof data74 === "string"){
if(func3(data74) > 512){
const err204 = {instancePath:instancePath+"/observation/events/" + i9+"/value",schemaPath:"#/properties/observation/properties/events/items/anyOf/0/properties/value/anyOf/0/maxLength",keyword:"maxLength",params:{limit: 512},message:"must NOT have more than 512 characters"};
if(vErrors === null){
vErrors = [err204];
}
else {
vErrors.push(err204);
}
errors++;
}
else {
if(!pattern4.test(data74)){
const err205 = {instancePath:instancePath+"/observation/events/" + i9+"/value",schemaPath:"#/properties/observation/properties/events/items/anyOf/0/properties/value/anyOf/0/pattern",keyword:"pattern",params:{pattern: "^(?:[0-9a-f]{2})*$"},message:"must match pattern \""+"^(?:[0-9a-f]{2})*$"+"\""};
if(vErrors === null){
vErrors = [err205];
}
else {
vErrors.push(err205);
}
errors++;
}
}
}
else {
const err206 = {instancePath:instancePath+"/observation/events/" + i9+"/value",schemaPath:"#/properties/observation/properties/events/items/anyOf/0/properties/value/anyOf/0/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err206];
}
else {
vErrors.push(err206);
}
errors++;
}
}
var _valid21 = _errs244 === errors;
valid42 = valid42 || _valid21;
const _errs246 = errors;
if(data74 !== null){
const err207 = {instancePath:instancePath+"/observation/events/" + i9+"/value",schemaPath:"#/properties/observation/properties/events/items/anyOf/0/properties/value/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err207];
}
else {
vErrors.push(err207);
}
errors++;
}
var _valid21 = _errs246 === errors;
valid42 = valid42 || _valid21;
if(!valid42){
const err208 = {instancePath:instancePath+"/observation/events/" + i9+"/value",schemaPath:"#/properties/observation/properties/events/items/anyOf/0/properties/value/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err208];
}
else {
vErrors.push(err208);
}
errors++;
}
else {
errors = _errs243;
if(vErrors !== null){
if(_errs243){
vErrors.length = _errs243;
}
else {
vErrors = null;
}
}
}
var valid38 = _errs242 === errors;
}
else {
var valid38 = true;
}
if(valid38){
if(data66.failed !== undefined){
const _errs248 = errors;
if(typeof data66.failed !== "boolean"){
const err209 = {instancePath:instancePath+"/observation/events/" + i9+"/failed",schemaPath:"#/properties/observation/properties/events/items/anyOf/0/properties/failed/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"};
if(vErrors === null){
vErrors = [err209];
}
else {
vErrors.push(err209);
}
errors++;
}
var valid38 = _errs248 === errors;
}
else {
var valid38 = true;
}
if(valid38){
if(data66.generation !== undefined){
let data76 = data66.generation;
const _errs250 = errors;
const _errs251 = errors;
let valid43 = false;
const _errs252 = errors;
if(!(((typeof data76 == "number") && (!(data76 % 1) && !isNaN(data76))) && (isFinite(data76)))){
const err210 = {instancePath:instancePath+"/observation/events/" + i9+"/generation",schemaPath:"#/properties/observation/properties/events/items/anyOf/0/properties/generation/anyOf/0/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err210];
}
else {
vErrors.push(err210);
}
errors++;
}
if(errors === _errs252){
if((typeof data76 == "number") && (isFinite(data76))){
if(data76 > 9007199254740991 || isNaN(data76)){
const err211 = {instancePath:instancePath+"/observation/events/" + i9+"/generation",schemaPath:"#/properties/observation/properties/events/items/anyOf/0/properties/generation/anyOf/0/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"};
if(vErrors === null){
vErrors = [err211];
}
else {
vErrors.push(err211);
}
errors++;
}
else {
if(data76 < 0 || isNaN(data76)){
const err212 = {instancePath:instancePath+"/observation/events/" + i9+"/generation",schemaPath:"#/properties/observation/properties/events/items/anyOf/0/properties/generation/anyOf/0/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err212];
}
else {
vErrors.push(err212);
}
errors++;
}
}
}
}
var _valid22 = _errs252 === errors;
valid43 = valid43 || _valid22;
const _errs254 = errors;
if(data76 !== null){
const err213 = {instancePath:instancePath+"/observation/events/" + i9+"/generation",schemaPath:"#/properties/observation/properties/events/items/anyOf/0/properties/generation/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err213];
}
else {
vErrors.push(err213);
}
errors++;
}
var _valid22 = _errs254 === errors;
valid43 = valid43 || _valid22;
if(!valid43){
const err214 = {instancePath:instancePath+"/observation/events/" + i9+"/generation",schemaPath:"#/properties/observation/properties/events/items/anyOf/0/properties/generation/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err214];
}
else {
vErrors.push(err214);
}
errors++;
}
else {
errors = _errs251;
if(vErrors !== null){
if(_errs251){
vErrors.length = _errs251;
}
else {
vErrors = null;
}
}
}
var valid38 = _errs250 === errors;
}
else {
var valid38 = true;
}
if(valid38){
if(data66.mailbox_status !== undefined){
let data77 = data66.mailbox_status;
const _errs256 = errors;
const _errs257 = errors;
let valid44 = false;
const _errs258 = errors;
if(typeof data77 !== "string"){
const err215 = {instancePath:instancePath+"/observation/events/" + i9+"/mailbox_status",schemaPath:"#/properties/observation/properties/events/items/anyOf/0/properties/mailbox_status/anyOf/0/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err215];
}
else {
vErrors.push(err215);
}
errors++;
}
if(!(((data77 === "pending") || (data77 === "consumed")) || (data77 === "cancelled"))){
const err216 = {instancePath:instancePath+"/observation/events/" + i9+"/mailbox_status",schemaPath:"#/properties/observation/properties/events/items/anyOf/0/properties/mailbox_status/anyOf/0/enum",keyword:"enum",params:{allowedValues: schema31.properties.observation.properties.events.items.anyOf[0].properties.mailbox_status.anyOf[0].enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err216];
}
else {
vErrors.push(err216);
}
errors++;
}
var _valid23 = _errs258 === errors;
valid44 = valid44 || _valid23;
const _errs260 = errors;
if(data77 !== null){
const err217 = {instancePath:instancePath+"/observation/events/" + i9+"/mailbox_status",schemaPath:"#/properties/observation/properties/events/items/anyOf/0/properties/mailbox_status/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err217];
}
else {
vErrors.push(err217);
}
errors++;
}
var _valid23 = _errs260 === errors;
valid44 = valid44 || _valid23;
if(!valid44){
const err218 = {instancePath:instancePath+"/observation/events/" + i9+"/mailbox_status",schemaPath:"#/properties/observation/properties/events/items/anyOf/0/properties/mailbox_status/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err218];
}
else {
vErrors.push(err218);
}
errors++;
}
else {
errors = _errs257;
if(vErrors !== null){
if(_errs257){
vErrors.length = _errs257;
}
else {
vErrors = null;
}
}
}
var valid38 = _errs256 === errors;
}
else {
var valid38 = true;
}
if(valid38){
if(data66.admitted !== undefined){
const _errs262 = errors;
if(typeof data66.admitted !== "boolean"){
const err219 = {instancePath:instancePath+"/observation/events/" + i9+"/admitted",schemaPath:"#/properties/observation/properties/events/items/anyOf/0/properties/admitted/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"};
if(vErrors === null){
vErrors = [err219];
}
else {
vErrors.push(err219);
}
errors++;
}
var valid38 = _errs262 === errors;
}
else {
var valid38 = true;
}
if(valid38){
if(data66.unix_ms !== undefined){
let data79 = data66.unix_ms;
const _errs264 = errors;
const _errs265 = errors;
let valid45 = false;
const _errs266 = errors;
if(!(((typeof data79 == "number") && (!(data79 % 1) && !isNaN(data79))) && (isFinite(data79)))){
const err220 = {instancePath:instancePath+"/observation/events/" + i9+"/unix_ms",schemaPath:"#/properties/observation/properties/events/items/anyOf/0/properties/unix_ms/anyOf/0/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err220];
}
else {
vErrors.push(err220);
}
errors++;
}
if(errors === _errs266){
if((typeof data79 == "number") && (isFinite(data79))){
if(data79 > 9007199254740991 || isNaN(data79)){
const err221 = {instancePath:instancePath+"/observation/events/" + i9+"/unix_ms",schemaPath:"#/properties/observation/properties/events/items/anyOf/0/properties/unix_ms/anyOf/0/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"};
if(vErrors === null){
vErrors = [err221];
}
else {
vErrors.push(err221);
}
errors++;
}
else {
if(data79 < 0 || isNaN(data79)){
const err222 = {instancePath:instancePath+"/observation/events/" + i9+"/unix_ms",schemaPath:"#/properties/observation/properties/events/items/anyOf/0/properties/unix_ms/anyOf/0/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err222];
}
else {
vErrors.push(err222);
}
errors++;
}
}
}
}
var _valid24 = _errs266 === errors;
valid45 = valid45 || _valid24;
const _errs268 = errors;
if(data79 !== null){
const err223 = {instancePath:instancePath+"/observation/events/" + i9+"/unix_ms",schemaPath:"#/properties/observation/properties/events/items/anyOf/0/properties/unix_ms/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err223];
}
else {
vErrors.push(err223);
}
errors++;
}
var _valid24 = _errs268 === errors;
valid45 = valid45 || _valid24;
if(!valid45){
const err224 = {instancePath:instancePath+"/observation/events/" + i9+"/unix_ms",schemaPath:"#/properties/observation/properties/events/items/anyOf/0/properties/unix_ms/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err224];
}
else {
vErrors.push(err224);
}
errors++;
}
else {
errors = _errs265;
if(vErrors !== null){
if(_errs265){
vErrors.length = _errs265;
}
else {
vErrors = null;
}
}
}
var valid38 = _errs264 === errors;
}
else {
var valid38 = true;
}
if(valid38){
if(data66.clock_error_ms !== undefined){
let data80 = data66.clock_error_ms;
const _errs270 = errors;
const _errs271 = errors;
let valid46 = false;
const _errs272 = errors;
if(!(((typeof data80 == "number") && (!(data80 % 1) && !isNaN(data80))) && (isFinite(data80)))){
const err225 = {instancePath:instancePath+"/observation/events/" + i9+"/clock_error_ms",schemaPath:"#/properties/observation/properties/events/items/anyOf/0/properties/clock_error_ms/anyOf/0/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err225];
}
else {
vErrors.push(err225);
}
errors++;
}
if(errors === _errs272){
if((typeof data80 == "number") && (isFinite(data80))){
if(data80 > 4294967295 || isNaN(data80)){
const err226 = {instancePath:instancePath+"/observation/events/" + i9+"/clock_error_ms",schemaPath:"#/properties/observation/properties/events/items/anyOf/0/properties/clock_error_ms/anyOf/0/maximum",keyword:"maximum",params:{comparison: "<=", limit: 4294967295},message:"must be <= 4294967295"};
if(vErrors === null){
vErrors = [err226];
}
else {
vErrors.push(err226);
}
errors++;
}
else {
if(data80 < 0 || isNaN(data80)){
const err227 = {instancePath:instancePath+"/observation/events/" + i9+"/clock_error_ms",schemaPath:"#/properties/observation/properties/events/items/anyOf/0/properties/clock_error_ms/anyOf/0/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err227];
}
else {
vErrors.push(err227);
}
errors++;
}
}
}
}
var _valid25 = _errs272 === errors;
valid46 = valid46 || _valid25;
const _errs274 = errors;
if(data80 !== null){
const err228 = {instancePath:instancePath+"/observation/events/" + i9+"/clock_error_ms",schemaPath:"#/properties/observation/properties/events/items/anyOf/0/properties/clock_error_ms/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err228];
}
else {
vErrors.push(err228);
}
errors++;
}
var _valid25 = _errs274 === errors;
valid46 = valid46 || _valid25;
if(!valid46){
const err229 = {instancePath:instancePath+"/observation/events/" + i9+"/clock_error_ms",schemaPath:"#/properties/observation/properties/events/items/anyOf/0/properties/clock_error_ms/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err229];
}
else {
vErrors.push(err229);
}
errors++;
}
else {
errors = _errs271;
if(vErrors !== null){
if(_errs271){
vErrors.length = _errs271;
}
else {
vErrors = null;
}
}
}
var valid38 = _errs270 === errors;
}
else {
var valid38 = true;
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
}
else {
const err230 = {instancePath:instancePath+"/observation/events/" + i9,schemaPath:"#/properties/observation/properties/events/items/anyOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err230];
}
else {
vErrors.push(err230);
}
errors++;
}
}
var _valid17 = _errs213 === errors;
valid37 = valid37 || _valid17;
const _errs276 = errors;
if(data66 !== null){
const err231 = {instancePath:instancePath+"/observation/events/" + i9,schemaPath:"#/properties/observation/properties/events/items/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err231];
}
else {
vErrors.push(err231);
}
errors++;
}
var _valid17 = _errs276 === errors;
valid37 = valid37 || _valid17;
if(!valid37){
const err232 = {instancePath:instancePath+"/observation/events/" + i9,schemaPath:"#/properties/observation/properties/events/items/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err232];
}
else {
vErrors.push(err232);
}
errors++;
validate20.errors = vErrors;
return false;
}
else {
errors = _errs212;
if(vErrors !== null){
if(_errs212){
vErrors.length = _errs212;
}
else {
vErrors = null;
}
}
}
var valid36 = _errs211 === errors;
if(!valid36){
break;
}
}
}
}
}
else {
validate20.errors = [{instancePath:instancePath+"/observation/events",schemaPath:"#/properties/observation/properties/events/type",keyword:"type",params:{type: "array"},message:"must be array"}];
return false;
}
}
var valid1 = _errs209 === errors;
}
else {
var valid1 = true;
}
if(valid1){
if(data0.outbox !== undefined){
let data81 = data0.outbox;
const _errs278 = errors;
if(errors === _errs278){
if(Array.isArray(data81)){
if(data81.length > 16){
validate20.errors = [{instancePath:instancePath+"/observation/outbox",schemaPath:"#/properties/observation/properties/outbox/maxItems",keyword:"maxItems",params:{limit: 16},message:"must NOT have more than 16 items"}];
return false;
}
else {
if(data81.length < 16){
validate20.errors = [{instancePath:instancePath+"/observation/outbox",schemaPath:"#/properties/observation/properties/outbox/minItems",keyword:"minItems",params:{limit: 16},message:"must NOT have fewer than 16 items"}];
return false;
}
else {
var valid47 = true;
const len10 = data81.length;
for(let i10=0; i10<len10; i10++){
let data82 = data81[i10];
const _errs280 = errors;
const _errs281 = errors;
let valid48 = false;
const _errs282 = errors;
if(errors === _errs282){
if(data82 && typeof data82 == "object" && !Array.isArray(data82)){
let missing11;
if(((((((((((data82.id === undefined) && (missing11 = "id")) || ((data82.source === undefined) && (missing11 = "source"))) || ((data82.turn === undefined) && (missing11 = "turn"))) || ((data82.index === undefined) && (missing11 = "index"))) || ((data82.destination === undefined) && (missing11 = "destination"))) || ((data82.value === undefined) && (missing11 = "value"))) || ((data82.phase === undefined) && (missing11 = "phase"))) || ((data82.resolved_at === undefined) && (missing11 = "resolved_at"))) || ((data82.courier === undefined) && (missing11 = "courier"))) || ((data82.policy_revision === undefined) && (missing11 = "policy_revision"))){
const err233 = {instancePath:instancePath+"/observation/outbox/" + i10,schemaPath:"#/properties/observation/properties/outbox/items/anyOf/0/required",keyword:"required",params:{missingProperty: missing11},message:"must have required property '"+missing11+"'"};
if(vErrors === null){
vErrors = [err233];
}
else {
vErrors.push(err233);
}
errors++;
}
else {
const _errs284 = errors;
for(const key11 in data82){
if(!(func1.call(schema31.properties.observation.properties.outbox.items.anyOf[0].properties, key11))){
const err234 = {instancePath:instancePath+"/observation/outbox/" + i10,schemaPath:"#/properties/observation/properties/outbox/items/anyOf/0/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key11},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err234];
}
else {
vErrors.push(err234);
}
errors++;
break;
}
}
if(_errs284 === errors){
if(data82.id !== undefined){
let data83 = data82.id;
const _errs285 = errors;
if(!(((typeof data83 == "number") && (!(data83 % 1) && !isNaN(data83))) && (isFinite(data83)))){
const err235 = {instancePath:instancePath+"/observation/outbox/" + i10+"/id",schemaPath:"#/properties/observation/properties/outbox/items/anyOf/0/properties/id/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err235];
}
else {
vErrors.push(err235);
}
errors++;
}
if(errors === _errs285){
if((typeof data83 == "number") && (isFinite(data83))){
if(data83 > 9007199254740991 || isNaN(data83)){
const err236 = {instancePath:instancePath+"/observation/outbox/" + i10+"/id",schemaPath:"#/properties/observation/properties/outbox/items/anyOf/0/properties/id/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"};
if(vErrors === null){
vErrors = [err236];
}
else {
vErrors.push(err236);
}
errors++;
}
else {
if(data83 < 0 || isNaN(data83)){
const err237 = {instancePath:instancePath+"/observation/outbox/" + i10+"/id",schemaPath:"#/properties/observation/properties/outbox/items/anyOf/0/properties/id/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err237];
}
else {
vErrors.push(err237);
}
errors++;
}
}
}
}
var valid49 = _errs285 === errors;
}
else {
var valid49 = true;
}
if(valid49){
if(data82.source !== undefined){
let data84 = data82.source;
const _errs287 = errors;
if(!(((typeof data84 == "number") && (!(data84 % 1) && !isNaN(data84))) && (isFinite(data84)))){
const err238 = {instancePath:instancePath+"/observation/outbox/" + i10+"/source",schemaPath:"#/properties/observation/properties/outbox/items/anyOf/0/properties/source/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err238];
}
else {
vErrors.push(err238);
}
errors++;
}
if(errors === _errs287){
if((typeof data84 == "number") && (isFinite(data84))){
if(data84 > 9007199254740991 || isNaN(data84)){
const err239 = {instancePath:instancePath+"/observation/outbox/" + i10+"/source",schemaPath:"#/properties/observation/properties/outbox/items/anyOf/0/properties/source/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"};
if(vErrors === null){
vErrors = [err239];
}
else {
vErrors.push(err239);
}
errors++;
}
else {
if(data84 < 0 || isNaN(data84)){
const err240 = {instancePath:instancePath+"/observation/outbox/" + i10+"/source",schemaPath:"#/properties/observation/properties/outbox/items/anyOf/0/properties/source/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err240];
}
else {
vErrors.push(err240);
}
errors++;
}
}
}
}
var valid49 = _errs287 === errors;
}
else {
var valid49 = true;
}
if(valid49){
if(data82.turn !== undefined){
let data85 = data82.turn;
const _errs289 = errors;
if(!(((typeof data85 == "number") && (!(data85 % 1) && !isNaN(data85))) && (isFinite(data85)))){
const err241 = {instancePath:instancePath+"/observation/outbox/" + i10+"/turn",schemaPath:"#/properties/observation/properties/outbox/items/anyOf/0/properties/turn/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err241];
}
else {
vErrors.push(err241);
}
errors++;
}
if(errors === _errs289){
if((typeof data85 == "number") && (isFinite(data85))){
if(data85 > 9007199254740991 || isNaN(data85)){
const err242 = {instancePath:instancePath+"/observation/outbox/" + i10+"/turn",schemaPath:"#/properties/observation/properties/outbox/items/anyOf/0/properties/turn/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"};
if(vErrors === null){
vErrors = [err242];
}
else {
vErrors.push(err242);
}
errors++;
}
else {
if(data85 < 0 || isNaN(data85)){
const err243 = {instancePath:instancePath+"/observation/outbox/" + i10+"/turn",schemaPath:"#/properties/observation/properties/outbox/items/anyOf/0/properties/turn/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err243];
}
else {
vErrors.push(err243);
}
errors++;
}
}
}
}
var valid49 = _errs289 === errors;
}
else {
var valid49 = true;
}
if(valid49){
if(data82.index !== undefined){
let data86 = data82.index;
const _errs291 = errors;
if(!(((typeof data86 == "number") && (!(data86 % 1) && !isNaN(data86))) && (isFinite(data86)))){
const err244 = {instancePath:instancePath+"/observation/outbox/" + i10+"/index",schemaPath:"#/properties/observation/properties/outbox/items/anyOf/0/properties/index/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err244];
}
else {
vErrors.push(err244);
}
errors++;
}
if(errors === _errs291){
if((typeof data86 == "number") && (isFinite(data86))){
if(data86 > 255 || isNaN(data86)){
const err245 = {instancePath:instancePath+"/observation/outbox/" + i10+"/index",schemaPath:"#/properties/observation/properties/outbox/items/anyOf/0/properties/index/maximum",keyword:"maximum",params:{comparison: "<=", limit: 255},message:"must be <= 255"};
if(vErrors === null){
vErrors = [err245];
}
else {
vErrors.push(err245);
}
errors++;
}
else {
if(data86 < 0 || isNaN(data86)){
const err246 = {instancePath:instancePath+"/observation/outbox/" + i10+"/index",schemaPath:"#/properties/observation/properties/outbox/items/anyOf/0/properties/index/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err246];
}
else {
vErrors.push(err246);
}
errors++;
}
}
}
}
var valid49 = _errs291 === errors;
}
else {
var valid49 = true;
}
if(valid49){
if(data82.destination !== undefined){
let data87 = data82.destination;
const _errs293 = errors;
if(!(((typeof data87 == "number") && (!(data87 % 1) && !isNaN(data87))) && (isFinite(data87)))){
const err247 = {instancePath:instancePath+"/observation/outbox/" + i10+"/destination",schemaPath:"#/properties/observation/properties/outbox/items/anyOf/0/properties/destination/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err247];
}
else {
vErrors.push(err247);
}
errors++;
}
if(errors === _errs293){
if((typeof data87 == "number") && (isFinite(data87))){
if(data87 > 9007199254740991 || isNaN(data87)){
const err248 = {instancePath:instancePath+"/observation/outbox/" + i10+"/destination",schemaPath:"#/properties/observation/properties/outbox/items/anyOf/0/properties/destination/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"};
if(vErrors === null){
vErrors = [err248];
}
else {
vErrors.push(err248);
}
errors++;
}
else {
if(data87 < 0 || isNaN(data87)){
const err249 = {instancePath:instancePath+"/observation/outbox/" + i10+"/destination",schemaPath:"#/properties/observation/properties/outbox/items/anyOf/0/properties/destination/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err249];
}
else {
vErrors.push(err249);
}
errors++;
}
}
}
}
var valid49 = _errs293 === errors;
}
else {
var valid49 = true;
}
if(valid49){
if(data82.value !== undefined){
let data88 = data82.value;
const _errs295 = errors;
if(errors === _errs295){
if(typeof data88 === "string"){
if(func3(data88) > 512){
const err250 = {instancePath:instancePath+"/observation/outbox/" + i10+"/value",schemaPath:"#/properties/observation/properties/outbox/items/anyOf/0/properties/value/maxLength",keyword:"maxLength",params:{limit: 512},message:"must NOT have more than 512 characters"};
if(vErrors === null){
vErrors = [err250];
}
else {
vErrors.push(err250);
}
errors++;
}
else {
if(!pattern4.test(data88)){
const err251 = {instancePath:instancePath+"/observation/outbox/" + i10+"/value",schemaPath:"#/properties/observation/properties/outbox/items/anyOf/0/properties/value/pattern",keyword:"pattern",params:{pattern: "^(?:[0-9a-f]{2})*$"},message:"must match pattern \""+"^(?:[0-9a-f]{2})*$"+"\""};
if(vErrors === null){
vErrors = [err251];
}
else {
vErrors.push(err251);
}
errors++;
}
}
}
else {
const err252 = {instancePath:instancePath+"/observation/outbox/" + i10+"/value",schemaPath:"#/properties/observation/properties/outbox/items/anyOf/0/properties/value/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err252];
}
else {
vErrors.push(err252);
}
errors++;
}
}
var valid49 = _errs295 === errors;
}
else {
var valid49 = true;
}
if(valid49){
if(data82.phase !== undefined){
let data89 = data82.phase;
const _errs297 = errors;
if(typeof data89 !== "string"){
const err253 = {instancePath:instancePath+"/observation/outbox/" + i10+"/phase",schemaPath:"#/properties/observation/properties/outbox/items/anyOf/0/properties/phase/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err253];
}
else {
vErrors.push(err253);
}
errors++;
}
if(!((((((data89 === "pending") || (data89 === "delivered")) || (data89 === "denied")) || (data89 === "expired")) || (data89 === "retired")) || (data89 === "cancelled"))){
const err254 = {instancePath:instancePath+"/observation/outbox/" + i10+"/phase",schemaPath:"#/properties/observation/properties/outbox/items/anyOf/0/properties/phase/enum",keyword:"enum",params:{allowedValues: schema31.properties.observation.properties.outbox.items.anyOf[0].properties.phase.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err254];
}
else {
vErrors.push(err254);
}
errors++;
}
var valid49 = _errs297 === errors;
}
else {
var valid49 = true;
}
if(valid49){
if(data82.resolved_at !== undefined){
let data90 = data82.resolved_at;
const _errs299 = errors;
const _errs300 = errors;
let valid50 = false;
const _errs301 = errors;
if(!(((typeof data90 == "number") && (!(data90 % 1) && !isNaN(data90))) && (isFinite(data90)))){
const err255 = {instancePath:instancePath+"/observation/outbox/" + i10+"/resolved_at",schemaPath:"#/properties/observation/properties/outbox/items/anyOf/0/properties/resolved_at/anyOf/0/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err255];
}
else {
vErrors.push(err255);
}
errors++;
}
if(errors === _errs301){
if((typeof data90 == "number") && (isFinite(data90))){
if(data90 > 9007199254740991 || isNaN(data90)){
const err256 = {instancePath:instancePath+"/observation/outbox/" + i10+"/resolved_at",schemaPath:"#/properties/observation/properties/outbox/items/anyOf/0/properties/resolved_at/anyOf/0/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"};
if(vErrors === null){
vErrors = [err256];
}
else {
vErrors.push(err256);
}
errors++;
}
else {
if(data90 < 0 || isNaN(data90)){
const err257 = {instancePath:instancePath+"/observation/outbox/" + i10+"/resolved_at",schemaPath:"#/properties/observation/properties/outbox/items/anyOf/0/properties/resolved_at/anyOf/0/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err257];
}
else {
vErrors.push(err257);
}
errors++;
}
}
}
}
var _valid27 = _errs301 === errors;
valid50 = valid50 || _valid27;
const _errs303 = errors;
if(data90 !== null){
const err258 = {instancePath:instancePath+"/observation/outbox/" + i10+"/resolved_at",schemaPath:"#/properties/observation/properties/outbox/items/anyOf/0/properties/resolved_at/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err258];
}
else {
vErrors.push(err258);
}
errors++;
}
var _valid27 = _errs303 === errors;
valid50 = valid50 || _valid27;
if(!valid50){
const err259 = {instancePath:instancePath+"/observation/outbox/" + i10+"/resolved_at",schemaPath:"#/properties/observation/properties/outbox/items/anyOf/0/properties/resolved_at/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err259];
}
else {
vErrors.push(err259);
}
errors++;
}
else {
errors = _errs300;
if(vErrors !== null){
if(_errs300){
vErrors.length = _errs300;
}
else {
vErrors = null;
}
}
}
var valid49 = _errs299 === errors;
}
else {
var valid49 = true;
}
if(valid49){
if(data82.courier !== undefined){
let data91 = data82.courier;
const _errs305 = errors;
const _errs306 = errors;
let valid51 = false;
const _errs307 = errors;
if(!(((typeof data91 == "number") && (!(data91 % 1) && !isNaN(data91))) && (isFinite(data91)))){
const err260 = {instancePath:instancePath+"/observation/outbox/" + i10+"/courier",schemaPath:"#/properties/observation/properties/outbox/items/anyOf/0/properties/courier/anyOf/0/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err260];
}
else {
vErrors.push(err260);
}
errors++;
}
if(errors === _errs307){
if((typeof data91 == "number") && (isFinite(data91))){
if(data91 > 255 || isNaN(data91)){
const err261 = {instancePath:instancePath+"/observation/outbox/" + i10+"/courier",schemaPath:"#/properties/observation/properties/outbox/items/anyOf/0/properties/courier/anyOf/0/maximum",keyword:"maximum",params:{comparison: "<=", limit: 255},message:"must be <= 255"};
if(vErrors === null){
vErrors = [err261];
}
else {
vErrors.push(err261);
}
errors++;
}
else {
if(data91 < 0 || isNaN(data91)){
const err262 = {instancePath:instancePath+"/observation/outbox/" + i10+"/courier",schemaPath:"#/properties/observation/properties/outbox/items/anyOf/0/properties/courier/anyOf/0/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err262];
}
else {
vErrors.push(err262);
}
errors++;
}
}
}
}
var _valid28 = _errs307 === errors;
valid51 = valid51 || _valid28;
const _errs309 = errors;
if(data91 !== null){
const err263 = {instancePath:instancePath+"/observation/outbox/" + i10+"/courier",schemaPath:"#/properties/observation/properties/outbox/items/anyOf/0/properties/courier/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err263];
}
else {
vErrors.push(err263);
}
errors++;
}
var _valid28 = _errs309 === errors;
valid51 = valid51 || _valid28;
if(!valid51){
const err264 = {instancePath:instancePath+"/observation/outbox/" + i10+"/courier",schemaPath:"#/properties/observation/properties/outbox/items/anyOf/0/properties/courier/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err264];
}
else {
vErrors.push(err264);
}
errors++;
}
else {
errors = _errs306;
if(vErrors !== null){
if(_errs306){
vErrors.length = _errs306;
}
else {
vErrors = null;
}
}
}
var valid49 = _errs305 === errors;
}
else {
var valid49 = true;
}
if(valid49){
if(data82.policy_revision !== undefined){
let data92 = data82.policy_revision;
const _errs311 = errors;
const _errs312 = errors;
let valid52 = false;
const _errs313 = errors;
if(!(((typeof data92 == "number") && (!(data92 % 1) && !isNaN(data92))) && (isFinite(data92)))){
const err265 = {instancePath:instancePath+"/observation/outbox/" + i10+"/policy_revision",schemaPath:"#/properties/observation/properties/outbox/items/anyOf/0/properties/policy_revision/anyOf/0/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err265];
}
else {
vErrors.push(err265);
}
errors++;
}
if(errors === _errs313){
if((typeof data92 == "number") && (isFinite(data92))){
if(data92 > 9007199254740991 || isNaN(data92)){
const err266 = {instancePath:instancePath+"/observation/outbox/" + i10+"/policy_revision",schemaPath:"#/properties/observation/properties/outbox/items/anyOf/0/properties/policy_revision/anyOf/0/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"};
if(vErrors === null){
vErrors = [err266];
}
else {
vErrors.push(err266);
}
errors++;
}
else {
if(data92 < 0 || isNaN(data92)){
const err267 = {instancePath:instancePath+"/observation/outbox/" + i10+"/policy_revision",schemaPath:"#/properties/observation/properties/outbox/items/anyOf/0/properties/policy_revision/anyOf/0/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err267];
}
else {
vErrors.push(err267);
}
errors++;
}
}
}
}
var _valid29 = _errs313 === errors;
valid52 = valid52 || _valid29;
const _errs315 = errors;
if(data92 !== null){
const err268 = {instancePath:instancePath+"/observation/outbox/" + i10+"/policy_revision",schemaPath:"#/properties/observation/properties/outbox/items/anyOf/0/properties/policy_revision/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err268];
}
else {
vErrors.push(err268);
}
errors++;
}
var _valid29 = _errs315 === errors;
valid52 = valid52 || _valid29;
if(!valid52){
const err269 = {instancePath:instancePath+"/observation/outbox/" + i10+"/policy_revision",schemaPath:"#/properties/observation/properties/outbox/items/anyOf/0/properties/policy_revision/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err269];
}
else {
vErrors.push(err269);
}
errors++;
}
else {
errors = _errs312;
if(vErrors !== null){
if(_errs312){
vErrors.length = _errs312;
}
else {
vErrors = null;
}
}
}
var valid49 = _errs311 === errors;
}
else {
var valid49 = true;
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
const err270 = {instancePath:instancePath+"/observation/outbox/" + i10,schemaPath:"#/properties/observation/properties/outbox/items/anyOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err270];
}
else {
vErrors.push(err270);
}
errors++;
}
}
var _valid26 = _errs282 === errors;
valid48 = valid48 || _valid26;
const _errs317 = errors;
if(data82 !== null){
const err271 = {instancePath:instancePath+"/observation/outbox/" + i10,schemaPath:"#/properties/observation/properties/outbox/items/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err271];
}
else {
vErrors.push(err271);
}
errors++;
}
var _valid26 = _errs317 === errors;
valid48 = valid48 || _valid26;
if(!valid48){
const err272 = {instancePath:instancePath+"/observation/outbox/" + i10,schemaPath:"#/properties/observation/properties/outbox/items/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err272];
}
else {
vErrors.push(err272);
}
errors++;
validate20.errors = vErrors;
return false;
}
else {
errors = _errs281;
if(vErrors !== null){
if(_errs281){
vErrors.length = _errs281;
}
else {
vErrors = null;
}
}
}
var valid47 = _errs280 === errors;
if(!valid47){
break;
}
}
}
}
}
else {
validate20.errors = [{instancePath:instancePath+"/observation/outbox",schemaPath:"#/properties/observation/properties/outbox/type",keyword:"type",params:{type: "array"},message:"must be array"}];
return false;
}
}
var valid1 = _errs278 === errors;
}
else {
var valid1 = true;
}
if(valid1){
if(data0.effects !== undefined){
let data93 = data0.effects;
const _errs319 = errors;
if(errors === _errs319){
if(Array.isArray(data93)){
if(data93.length > 16){
validate20.errors = [{instancePath:instancePath+"/observation/effects",schemaPath:"#/properties/observation/properties/effects/maxItems",keyword:"maxItems",params:{limit: 16},message:"must NOT have more than 16 items"}];
return false;
}
else {
if(data93.length < 16){
validate20.errors = [{instancePath:instancePath+"/observation/effects",schemaPath:"#/properties/observation/properties/effects/minItems",keyword:"minItems",params:{limit: 16},message:"must NOT have fewer than 16 items"}];
return false;
}
else {
var valid53 = true;
const len11 = data93.length;
for(let i11=0; i11<len11; i11++){
let data94 = data93[i11];
const _errs321 = errors;
const _errs322 = errors;
let valid54 = false;
const _errs323 = errors;
if(errors === _errs323){
if(data94 && typeof data94 == "object" && !Array.isArray(data94)){
let missing12;
if((((((((((((data94.id === undefined) && (missing12 = "id")) || ((data94.pid === undefined) && (missing12 = "pid"))) || ((data94.payload === undefined) && (missing12 = "payload"))) || ((data94.phase === undefined) && (missing12 = "phase"))) || ((data94.attempt === undefined) && (missing12 = "attempt"))) || ((data94.executor === undefined) && (missing12 = "executor"))) || ((data94.result === undefined) && (missing12 = "result"))) || ((data94.closed_at === undefined) && (missing12 = "closed_at"))) || ((data94.reconcile_before_ms === undefined) && (missing12 = "reconcile_before_ms"))) || ((data94.max_observations === undefined) && (missing12 = "max_observations"))) || ((data94.observations === undefined) && (missing12 = "observations"))){
const err273 = {instancePath:instancePath+"/observation/effects/" + i11,schemaPath:"#/properties/observation/properties/effects/items/anyOf/0/required",keyword:"required",params:{missingProperty: missing12},message:"must have required property '"+missing12+"'"};
if(vErrors === null){
vErrors = [err273];
}
else {
vErrors.push(err273);
}
errors++;
}
else {
const _errs325 = errors;
for(const key12 in data94){
if(!(func1.call(schema31.properties.observation.properties.effects.items.anyOf[0].properties, key12))){
const err274 = {instancePath:instancePath+"/observation/effects/" + i11,schemaPath:"#/properties/observation/properties/effects/items/anyOf/0/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key12},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err274];
}
else {
vErrors.push(err274);
}
errors++;
break;
}
}
if(_errs325 === errors){
if(data94.id !== undefined){
let data95 = data94.id;
const _errs326 = errors;
if(!(((typeof data95 == "number") && (!(data95 % 1) && !isNaN(data95))) && (isFinite(data95)))){
const err275 = {instancePath:instancePath+"/observation/effects/" + i11+"/id",schemaPath:"#/properties/observation/properties/effects/items/anyOf/0/properties/id/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err275];
}
else {
vErrors.push(err275);
}
errors++;
}
if(errors === _errs326){
if((typeof data95 == "number") && (isFinite(data95))){
if(data95 > 9007199254740991 || isNaN(data95)){
const err276 = {instancePath:instancePath+"/observation/effects/" + i11+"/id",schemaPath:"#/properties/observation/properties/effects/items/anyOf/0/properties/id/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"};
if(vErrors === null){
vErrors = [err276];
}
else {
vErrors.push(err276);
}
errors++;
}
else {
if(data95 < 0 || isNaN(data95)){
const err277 = {instancePath:instancePath+"/observation/effects/" + i11+"/id",schemaPath:"#/properties/observation/properties/effects/items/anyOf/0/properties/id/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err277];
}
else {
vErrors.push(err277);
}
errors++;
}
}
}
}
var valid55 = _errs326 === errors;
}
else {
var valid55 = true;
}
if(valid55){
if(data94.pid !== undefined){
let data96 = data94.pid;
const _errs328 = errors;
if(!(((typeof data96 == "number") && (!(data96 % 1) && !isNaN(data96))) && (isFinite(data96)))){
const err278 = {instancePath:instancePath+"/observation/effects/" + i11+"/pid",schemaPath:"#/properties/observation/properties/effects/items/anyOf/0/properties/pid/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err278];
}
else {
vErrors.push(err278);
}
errors++;
}
if(errors === _errs328){
if((typeof data96 == "number") && (isFinite(data96))){
if(data96 > 9007199254740991 || isNaN(data96)){
const err279 = {instancePath:instancePath+"/observation/effects/" + i11+"/pid",schemaPath:"#/properties/observation/properties/effects/items/anyOf/0/properties/pid/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"};
if(vErrors === null){
vErrors = [err279];
}
else {
vErrors.push(err279);
}
errors++;
}
else {
if(data96 < 0 || isNaN(data96)){
const err280 = {instancePath:instancePath+"/observation/effects/" + i11+"/pid",schemaPath:"#/properties/observation/properties/effects/items/anyOf/0/properties/pid/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err280];
}
else {
vErrors.push(err280);
}
errors++;
}
}
}
}
var valid55 = _errs328 === errors;
}
else {
var valid55 = true;
}
if(valid55){
if(data94.payload !== undefined){
let data97 = data94.payload;
const _errs330 = errors;
if(errors === _errs330){
if(typeof data97 === "string"){
if(func3(data97) > 512){
const err281 = {instancePath:instancePath+"/observation/effects/" + i11+"/payload",schemaPath:"#/properties/observation/properties/effects/items/anyOf/0/properties/payload/maxLength",keyword:"maxLength",params:{limit: 512},message:"must NOT have more than 512 characters"};
if(vErrors === null){
vErrors = [err281];
}
else {
vErrors.push(err281);
}
errors++;
}
else {
if(!pattern4.test(data97)){
const err282 = {instancePath:instancePath+"/observation/effects/" + i11+"/payload",schemaPath:"#/properties/observation/properties/effects/items/anyOf/0/properties/payload/pattern",keyword:"pattern",params:{pattern: "^(?:[0-9a-f]{2})*$"},message:"must match pattern \""+"^(?:[0-9a-f]{2})*$"+"\""};
if(vErrors === null){
vErrors = [err282];
}
else {
vErrors.push(err282);
}
errors++;
}
}
}
else {
const err283 = {instancePath:instancePath+"/observation/effects/" + i11+"/payload",schemaPath:"#/properties/observation/properties/effects/items/anyOf/0/properties/payload/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err283];
}
else {
vErrors.push(err283);
}
errors++;
}
}
var valid55 = _errs330 === errors;
}
else {
var valid55 = true;
}
if(valid55){
if(data94.phase !== undefined){
let data98 = data94.phase;
const _errs332 = errors;
if(typeof data98 !== "string"){
const err284 = {instancePath:instancePath+"/observation/effects/" + i11+"/phase",schemaPath:"#/properties/observation/properties/effects/items/anyOf/0/properties/phase/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err284];
}
else {
vErrors.push(err284);
}
errors++;
}
if(!((((((data98 === "pending") || (data98 === "authorized")) || (data98 === "unknown")) || (data98 === "observed")) || (data98 === "cancelled")) || (data98 === "closed_unknown"))){
const err285 = {instancePath:instancePath+"/observation/effects/" + i11+"/phase",schemaPath:"#/properties/observation/properties/effects/items/anyOf/0/properties/phase/enum",keyword:"enum",params:{allowedValues: schema31.properties.observation.properties.effects.items.anyOf[0].properties.phase.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err285];
}
else {
vErrors.push(err285);
}
errors++;
}
var valid55 = _errs332 === errors;
}
else {
var valid55 = true;
}
if(valid55){
if(data94.attempt !== undefined){
let data99 = data94.attempt;
const _errs334 = errors;
const _errs335 = errors;
let valid56 = false;
const _errs336 = errors;
if(!(((typeof data99 == "number") && (!(data99 % 1) && !isNaN(data99))) && (isFinite(data99)))){
const err286 = {instancePath:instancePath+"/observation/effects/" + i11+"/attempt",schemaPath:"#/properties/observation/properties/effects/items/anyOf/0/properties/attempt/anyOf/0/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err286];
}
else {
vErrors.push(err286);
}
errors++;
}
if(errors === _errs336){
if((typeof data99 == "number") && (isFinite(data99))){
if(data99 > 9007199254740991 || isNaN(data99)){
const err287 = {instancePath:instancePath+"/observation/effects/" + i11+"/attempt",schemaPath:"#/properties/observation/properties/effects/items/anyOf/0/properties/attempt/anyOf/0/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"};
if(vErrors === null){
vErrors = [err287];
}
else {
vErrors.push(err287);
}
errors++;
}
else {
if(data99 < 0 || isNaN(data99)){
const err288 = {instancePath:instancePath+"/observation/effects/" + i11+"/attempt",schemaPath:"#/properties/observation/properties/effects/items/anyOf/0/properties/attempt/anyOf/0/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err288];
}
else {
vErrors.push(err288);
}
errors++;
}
}
}
}
var _valid31 = _errs336 === errors;
valid56 = valid56 || _valid31;
const _errs338 = errors;
if(data99 !== null){
const err289 = {instancePath:instancePath+"/observation/effects/" + i11+"/attempt",schemaPath:"#/properties/observation/properties/effects/items/anyOf/0/properties/attempt/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err289];
}
else {
vErrors.push(err289);
}
errors++;
}
var _valid31 = _errs338 === errors;
valid56 = valid56 || _valid31;
if(!valid56){
const err290 = {instancePath:instancePath+"/observation/effects/" + i11+"/attempt",schemaPath:"#/properties/observation/properties/effects/items/anyOf/0/properties/attempt/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err290];
}
else {
vErrors.push(err290);
}
errors++;
}
else {
errors = _errs335;
if(vErrors !== null){
if(_errs335){
vErrors.length = _errs335;
}
else {
vErrors = null;
}
}
}
var valid55 = _errs334 === errors;
}
else {
var valid55 = true;
}
if(valid55){
if(data94.executor !== undefined){
let data100 = data94.executor;
const _errs340 = errors;
const _errs341 = errors;
let valid57 = false;
const _errs342 = errors;
if(!(((typeof data100 == "number") && (!(data100 % 1) && !isNaN(data100))) && (isFinite(data100)))){
const err291 = {instancePath:instancePath+"/observation/effects/" + i11+"/executor",schemaPath:"#/properties/observation/properties/effects/items/anyOf/0/properties/executor/anyOf/0/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err291];
}
else {
vErrors.push(err291);
}
errors++;
}
if(errors === _errs342){
if((typeof data100 == "number") && (isFinite(data100))){
if(data100 > 255 || isNaN(data100)){
const err292 = {instancePath:instancePath+"/observation/effects/" + i11+"/executor",schemaPath:"#/properties/observation/properties/effects/items/anyOf/0/properties/executor/anyOf/0/maximum",keyword:"maximum",params:{comparison: "<=", limit: 255},message:"must be <= 255"};
if(vErrors === null){
vErrors = [err292];
}
else {
vErrors.push(err292);
}
errors++;
}
else {
if(data100 < 0 || isNaN(data100)){
const err293 = {instancePath:instancePath+"/observation/effects/" + i11+"/executor",schemaPath:"#/properties/observation/properties/effects/items/anyOf/0/properties/executor/anyOf/0/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err293];
}
else {
vErrors.push(err293);
}
errors++;
}
}
}
}
var _valid32 = _errs342 === errors;
valid57 = valid57 || _valid32;
const _errs344 = errors;
if(data100 !== null){
const err294 = {instancePath:instancePath+"/observation/effects/" + i11+"/executor",schemaPath:"#/properties/observation/properties/effects/items/anyOf/0/properties/executor/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err294];
}
else {
vErrors.push(err294);
}
errors++;
}
var _valid32 = _errs344 === errors;
valid57 = valid57 || _valid32;
if(!valid57){
const err295 = {instancePath:instancePath+"/observation/effects/" + i11+"/executor",schemaPath:"#/properties/observation/properties/effects/items/anyOf/0/properties/executor/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err295];
}
else {
vErrors.push(err295);
}
errors++;
}
else {
errors = _errs341;
if(vErrors !== null){
if(_errs341){
vErrors.length = _errs341;
}
else {
vErrors = null;
}
}
}
var valid55 = _errs340 === errors;
}
else {
var valid55 = true;
}
if(valid55){
if(data94.result !== undefined){
let data101 = data94.result;
const _errs346 = errors;
const _errs347 = errors;
let valid58 = false;
const _errs348 = errors;
if(errors === _errs348){
if(typeof data101 === "string"){
if(func3(data101) > 512){
const err296 = {instancePath:instancePath+"/observation/effects/" + i11+"/result",schemaPath:"#/properties/observation/properties/effects/items/anyOf/0/properties/result/anyOf/0/maxLength",keyword:"maxLength",params:{limit: 512},message:"must NOT have more than 512 characters"};
if(vErrors === null){
vErrors = [err296];
}
else {
vErrors.push(err296);
}
errors++;
}
else {
if(!pattern4.test(data101)){
const err297 = {instancePath:instancePath+"/observation/effects/" + i11+"/result",schemaPath:"#/properties/observation/properties/effects/items/anyOf/0/properties/result/anyOf/0/pattern",keyword:"pattern",params:{pattern: "^(?:[0-9a-f]{2})*$"},message:"must match pattern \""+"^(?:[0-9a-f]{2})*$"+"\""};
if(vErrors === null){
vErrors = [err297];
}
else {
vErrors.push(err297);
}
errors++;
}
}
}
else {
const err298 = {instancePath:instancePath+"/observation/effects/" + i11+"/result",schemaPath:"#/properties/observation/properties/effects/items/anyOf/0/properties/result/anyOf/0/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err298];
}
else {
vErrors.push(err298);
}
errors++;
}
}
var _valid33 = _errs348 === errors;
valid58 = valid58 || _valid33;
const _errs350 = errors;
if(data101 !== null){
const err299 = {instancePath:instancePath+"/observation/effects/" + i11+"/result",schemaPath:"#/properties/observation/properties/effects/items/anyOf/0/properties/result/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err299];
}
else {
vErrors.push(err299);
}
errors++;
}
var _valid33 = _errs350 === errors;
valid58 = valid58 || _valid33;
if(!valid58){
const err300 = {instancePath:instancePath+"/observation/effects/" + i11+"/result",schemaPath:"#/properties/observation/properties/effects/items/anyOf/0/properties/result/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err300];
}
else {
vErrors.push(err300);
}
errors++;
}
else {
errors = _errs347;
if(vErrors !== null){
if(_errs347){
vErrors.length = _errs347;
}
else {
vErrors = null;
}
}
}
var valid55 = _errs346 === errors;
}
else {
var valid55 = true;
}
if(valid55){
if(data94.closed_at !== undefined){
let data102 = data94.closed_at;
const _errs352 = errors;
const _errs353 = errors;
let valid59 = false;
const _errs354 = errors;
if(!(((typeof data102 == "number") && (!(data102 % 1) && !isNaN(data102))) && (isFinite(data102)))){
const err301 = {instancePath:instancePath+"/observation/effects/" + i11+"/closed_at",schemaPath:"#/properties/observation/properties/effects/items/anyOf/0/properties/closed_at/anyOf/0/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err301];
}
else {
vErrors.push(err301);
}
errors++;
}
if(errors === _errs354){
if((typeof data102 == "number") && (isFinite(data102))){
if(data102 > 9007199254740991 || isNaN(data102)){
const err302 = {instancePath:instancePath+"/observation/effects/" + i11+"/closed_at",schemaPath:"#/properties/observation/properties/effects/items/anyOf/0/properties/closed_at/anyOf/0/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"};
if(vErrors === null){
vErrors = [err302];
}
else {
vErrors.push(err302);
}
errors++;
}
else {
if(data102 < 0 || isNaN(data102)){
const err303 = {instancePath:instancePath+"/observation/effects/" + i11+"/closed_at",schemaPath:"#/properties/observation/properties/effects/items/anyOf/0/properties/closed_at/anyOf/0/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err303];
}
else {
vErrors.push(err303);
}
errors++;
}
}
}
}
var _valid34 = _errs354 === errors;
valid59 = valid59 || _valid34;
const _errs356 = errors;
if(data102 !== null){
const err304 = {instancePath:instancePath+"/observation/effects/" + i11+"/closed_at",schemaPath:"#/properties/observation/properties/effects/items/anyOf/0/properties/closed_at/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err304];
}
else {
vErrors.push(err304);
}
errors++;
}
var _valid34 = _errs356 === errors;
valid59 = valid59 || _valid34;
if(!valid59){
const err305 = {instancePath:instancePath+"/observation/effects/" + i11+"/closed_at",schemaPath:"#/properties/observation/properties/effects/items/anyOf/0/properties/closed_at/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err305];
}
else {
vErrors.push(err305);
}
errors++;
}
else {
errors = _errs353;
if(vErrors !== null){
if(_errs353){
vErrors.length = _errs353;
}
else {
vErrors = null;
}
}
}
var valid55 = _errs352 === errors;
}
else {
var valid55 = true;
}
if(valid55){
if(data94.reconcile_before_ms !== undefined){
let data103 = data94.reconcile_before_ms;
const _errs358 = errors;
const _errs359 = errors;
let valid60 = false;
const _errs360 = errors;
if(!(((typeof data103 == "number") && (!(data103 % 1) && !isNaN(data103))) && (isFinite(data103)))){
const err306 = {instancePath:instancePath+"/observation/effects/" + i11+"/reconcile_before_ms",schemaPath:"#/properties/observation/properties/effects/items/anyOf/0/properties/reconcile_before_ms/anyOf/0/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err306];
}
else {
vErrors.push(err306);
}
errors++;
}
if(errors === _errs360){
if((typeof data103 == "number") && (isFinite(data103))){
if(data103 > 9007199254740991 || isNaN(data103)){
const err307 = {instancePath:instancePath+"/observation/effects/" + i11+"/reconcile_before_ms",schemaPath:"#/properties/observation/properties/effects/items/anyOf/0/properties/reconcile_before_ms/anyOf/0/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"};
if(vErrors === null){
vErrors = [err307];
}
else {
vErrors.push(err307);
}
errors++;
}
else {
if(data103 < 0 || isNaN(data103)){
const err308 = {instancePath:instancePath+"/observation/effects/" + i11+"/reconcile_before_ms",schemaPath:"#/properties/observation/properties/effects/items/anyOf/0/properties/reconcile_before_ms/anyOf/0/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err308];
}
else {
vErrors.push(err308);
}
errors++;
}
}
}
}
var _valid35 = _errs360 === errors;
valid60 = valid60 || _valid35;
const _errs362 = errors;
if(data103 !== null){
const err309 = {instancePath:instancePath+"/observation/effects/" + i11+"/reconcile_before_ms",schemaPath:"#/properties/observation/properties/effects/items/anyOf/0/properties/reconcile_before_ms/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err309];
}
else {
vErrors.push(err309);
}
errors++;
}
var _valid35 = _errs362 === errors;
valid60 = valid60 || _valid35;
if(!valid60){
const err310 = {instancePath:instancePath+"/observation/effects/" + i11+"/reconcile_before_ms",schemaPath:"#/properties/observation/properties/effects/items/anyOf/0/properties/reconcile_before_ms/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err310];
}
else {
vErrors.push(err310);
}
errors++;
}
else {
errors = _errs359;
if(vErrors !== null){
if(_errs359){
vErrors.length = _errs359;
}
else {
vErrors = null;
}
}
}
var valid55 = _errs358 === errors;
}
else {
var valid55 = true;
}
if(valid55){
if(data94.max_observations !== undefined){
let data104 = data94.max_observations;
const _errs364 = errors;
if(!(((typeof data104 == "number") && (!(data104 % 1) && !isNaN(data104))) && (isFinite(data104)))){
const err311 = {instancePath:instancePath+"/observation/effects/" + i11+"/max_observations",schemaPath:"#/properties/observation/properties/effects/items/anyOf/0/properties/max_observations/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err311];
}
else {
vErrors.push(err311);
}
errors++;
}
if(errors === _errs364){
if((typeof data104 == "number") && (isFinite(data104))){
if(data104 > 65535 || isNaN(data104)){
const err312 = {instancePath:instancePath+"/observation/effects/" + i11+"/max_observations",schemaPath:"#/properties/observation/properties/effects/items/anyOf/0/properties/max_observations/maximum",keyword:"maximum",params:{comparison: "<=", limit: 65535},message:"must be <= 65535"};
if(vErrors === null){
vErrors = [err312];
}
else {
vErrors.push(err312);
}
errors++;
}
else {
if(data104 < 0 || isNaN(data104)){
const err313 = {instancePath:instancePath+"/observation/effects/" + i11+"/max_observations",schemaPath:"#/properties/observation/properties/effects/items/anyOf/0/properties/max_observations/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err313];
}
else {
vErrors.push(err313);
}
errors++;
}
}
}
}
var valid55 = _errs364 === errors;
}
else {
var valid55 = true;
}
if(valid55){
if(data94.observations !== undefined){
let data105 = data94.observations;
const _errs366 = errors;
if(!(((typeof data105 == "number") && (!(data105 % 1) && !isNaN(data105))) && (isFinite(data105)))){
const err314 = {instancePath:instancePath+"/observation/effects/" + i11+"/observations",schemaPath:"#/properties/observation/properties/effects/items/anyOf/0/properties/observations/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err314];
}
else {
vErrors.push(err314);
}
errors++;
}
if(errors === _errs366){
if((typeof data105 == "number") && (isFinite(data105))){
if(data105 > 65535 || isNaN(data105)){
const err315 = {instancePath:instancePath+"/observation/effects/" + i11+"/observations",schemaPath:"#/properties/observation/properties/effects/items/anyOf/0/properties/observations/maximum",keyword:"maximum",params:{comparison: "<=", limit: 65535},message:"must be <= 65535"};
if(vErrors === null){
vErrors = [err315];
}
else {
vErrors.push(err315);
}
errors++;
}
else {
if(data105 < 0 || isNaN(data105)){
const err316 = {instancePath:instancePath+"/observation/effects/" + i11+"/observations",schemaPath:"#/properties/observation/properties/effects/items/anyOf/0/properties/observations/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err316];
}
else {
vErrors.push(err316);
}
errors++;
}
}
}
}
var valid55 = _errs366 === errors;
}
else {
var valid55 = true;
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
const err317 = {instancePath:instancePath+"/observation/effects/" + i11,schemaPath:"#/properties/observation/properties/effects/items/anyOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err317];
}
else {
vErrors.push(err317);
}
errors++;
}
}
var _valid30 = _errs323 === errors;
valid54 = valid54 || _valid30;
const _errs368 = errors;
if(data94 !== null){
const err318 = {instancePath:instancePath+"/observation/effects/" + i11,schemaPath:"#/properties/observation/properties/effects/items/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err318];
}
else {
vErrors.push(err318);
}
errors++;
}
var _valid30 = _errs368 === errors;
valid54 = valid54 || _valid30;
if(!valid54){
const err319 = {instancePath:instancePath+"/observation/effects/" + i11,schemaPath:"#/properties/observation/properties/effects/items/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err319];
}
else {
vErrors.push(err319);
}
errors++;
validate20.errors = vErrors;
return false;
}
else {
errors = _errs322;
if(vErrors !== null){
if(_errs322){
vErrors.length = _errs322;
}
else {
vErrors = null;
}
}
}
var valid53 = _errs321 === errors;
if(!valid53){
break;
}
}
}
}
}
else {
validate20.errors = [{instancePath:instancePath+"/observation/effects",schemaPath:"#/properties/observation/properties/effects/type",keyword:"type",params:{type: "array"},message:"must be array"}];
return false;
}
}
var valid1 = _errs319 === errors;
}
else {
var valid1 = true;
}
if(valid1){
if(data0.payloads !== undefined){
let data106 = data0.payloads;
const _errs370 = errors;
if(errors === _errs370){
if(Array.isArray(data106)){
if(data106.length > 16){
validate20.errors = [{instancePath:instancePath+"/observation/payloads",schemaPath:"#/properties/observation/properties/payloads/maxItems",keyword:"maxItems",params:{limit: 16},message:"must NOT have more than 16 items"}];
return false;
}
else {
if(data106.length < 16){
validate20.errors = [{instancePath:instancePath+"/observation/payloads",schemaPath:"#/properties/observation/properties/payloads/minItems",keyword:"minItems",params:{limit: 16},message:"must NOT have fewer than 16 items"}];
return false;
}
else {
var valid61 = true;
const len12 = data106.length;
for(let i12=0; i12<len12; i12++){
let data107 = data106[i12];
const _errs372 = errors;
const _errs373 = errors;
let valid62 = false;
const _errs374 = errors;
if(errors === _errs374){
if(data107 && typeof data107 == "object" && !Array.isArray(data107)){
let missing13;
if((((((((((data107.id === undefined) && (missing13 = "id")) || ((data107.pid === undefined) && (missing13 = "pid"))) || ((data107.publisher === undefined) && (missing13 = "publisher"))) || ((data107.sha256 === undefined) && (missing13 = "sha256"))) || ((data107.bytes === undefined) && (missing13 = "bytes"))) || ((data107.allow_delete === undefined) && (missing13 = "allow_delete"))) || ((data107.phase === undefined) && (missing13 = "phase"))) || ((data107.retired_at === undefined) && (missing13 = "retired_at"))) || ((data107.deleted_at === undefined) && (missing13 = "deleted_at"))){
const err320 = {instancePath:instancePath+"/observation/payloads/" + i12,schemaPath:"#/properties/observation/properties/payloads/items/anyOf/0/required",keyword:"required",params:{missingProperty: missing13},message:"must have required property '"+missing13+"'"};
if(vErrors === null){
vErrors = [err320];
}
else {
vErrors.push(err320);
}
errors++;
}
else {
const _errs376 = errors;
for(const key13 in data107){
if(!(func1.call(schema31.properties.observation.properties.payloads.items.anyOf[0].properties, key13))){
const err321 = {instancePath:instancePath+"/observation/payloads/" + i12,schemaPath:"#/properties/observation/properties/payloads/items/anyOf/0/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key13},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err321];
}
else {
vErrors.push(err321);
}
errors++;
break;
}
}
if(_errs376 === errors){
if(data107.id !== undefined){
let data108 = data107.id;
const _errs377 = errors;
if(!(((typeof data108 == "number") && (!(data108 % 1) && !isNaN(data108))) && (isFinite(data108)))){
const err322 = {instancePath:instancePath+"/observation/payloads/" + i12+"/id",schemaPath:"#/properties/observation/properties/payloads/items/anyOf/0/properties/id/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err322];
}
else {
vErrors.push(err322);
}
errors++;
}
if(errors === _errs377){
if((typeof data108 == "number") && (isFinite(data108))){
if(data108 > 9007199254740991 || isNaN(data108)){
const err323 = {instancePath:instancePath+"/observation/payloads/" + i12+"/id",schemaPath:"#/properties/observation/properties/payloads/items/anyOf/0/properties/id/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"};
if(vErrors === null){
vErrors = [err323];
}
else {
vErrors.push(err323);
}
errors++;
}
else {
if(data108 < 0 || isNaN(data108)){
const err324 = {instancePath:instancePath+"/observation/payloads/" + i12+"/id",schemaPath:"#/properties/observation/properties/payloads/items/anyOf/0/properties/id/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err324];
}
else {
vErrors.push(err324);
}
errors++;
}
}
}
}
var valid63 = _errs377 === errors;
}
else {
var valid63 = true;
}
if(valid63){
if(data107.pid !== undefined){
let data109 = data107.pid;
const _errs379 = errors;
if(!(((typeof data109 == "number") && (!(data109 % 1) && !isNaN(data109))) && (isFinite(data109)))){
const err325 = {instancePath:instancePath+"/observation/payloads/" + i12+"/pid",schemaPath:"#/properties/observation/properties/payloads/items/anyOf/0/properties/pid/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err325];
}
else {
vErrors.push(err325);
}
errors++;
}
if(errors === _errs379){
if((typeof data109 == "number") && (isFinite(data109))){
if(data109 > 9007199254740991 || isNaN(data109)){
const err326 = {instancePath:instancePath+"/observation/payloads/" + i12+"/pid",schemaPath:"#/properties/observation/properties/payloads/items/anyOf/0/properties/pid/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"};
if(vErrors === null){
vErrors = [err326];
}
else {
vErrors.push(err326);
}
errors++;
}
else {
if(data109 < 0 || isNaN(data109)){
const err327 = {instancePath:instancePath+"/observation/payloads/" + i12+"/pid",schemaPath:"#/properties/observation/properties/payloads/items/anyOf/0/properties/pid/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err327];
}
else {
vErrors.push(err327);
}
errors++;
}
}
}
}
var valid63 = _errs379 === errors;
}
else {
var valid63 = true;
}
if(valid63){
if(data107.publisher !== undefined){
let data110 = data107.publisher;
const _errs381 = errors;
if(!(((typeof data110 == "number") && (!(data110 % 1) && !isNaN(data110))) && (isFinite(data110)))){
const err328 = {instancePath:instancePath+"/observation/payloads/" + i12+"/publisher",schemaPath:"#/properties/observation/properties/payloads/items/anyOf/0/properties/publisher/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err328];
}
else {
vErrors.push(err328);
}
errors++;
}
if(errors === _errs381){
if((typeof data110 == "number") && (isFinite(data110))){
if(data110 > 255 || isNaN(data110)){
const err329 = {instancePath:instancePath+"/observation/payloads/" + i12+"/publisher",schemaPath:"#/properties/observation/properties/payloads/items/anyOf/0/properties/publisher/maximum",keyword:"maximum",params:{comparison: "<=", limit: 255},message:"must be <= 255"};
if(vErrors === null){
vErrors = [err329];
}
else {
vErrors.push(err329);
}
errors++;
}
else {
if(data110 < 0 || isNaN(data110)){
const err330 = {instancePath:instancePath+"/observation/payloads/" + i12+"/publisher",schemaPath:"#/properties/observation/properties/payloads/items/anyOf/0/properties/publisher/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err330];
}
else {
vErrors.push(err330);
}
errors++;
}
}
}
}
var valid63 = _errs381 === errors;
}
else {
var valid63 = true;
}
if(valid63){
if(data107.sha256 !== undefined){
let data111 = data107.sha256;
const _errs383 = errors;
if(errors === _errs383){
if(Array.isArray(data111)){
if(data111.length > 32){
const err331 = {instancePath:instancePath+"/observation/payloads/" + i12+"/sha256",schemaPath:"#/properties/observation/properties/payloads/items/anyOf/0/properties/sha256/maxItems",keyword:"maxItems",params:{limit: 32},message:"must NOT have more than 32 items"};
if(vErrors === null){
vErrors = [err331];
}
else {
vErrors.push(err331);
}
errors++;
}
else {
if(data111.length < 32){
const err332 = {instancePath:instancePath+"/observation/payloads/" + i12+"/sha256",schemaPath:"#/properties/observation/properties/payloads/items/anyOf/0/properties/sha256/minItems",keyword:"minItems",params:{limit: 32},message:"must NOT have fewer than 32 items"};
if(vErrors === null){
vErrors = [err332];
}
else {
vErrors.push(err332);
}
errors++;
}
else {
var valid64 = true;
const len13 = data111.length;
for(let i13=0; i13<len13; i13++){
let data112 = data111[i13];
const _errs385 = errors;
if(!(((typeof data112 == "number") && (!(data112 % 1) && !isNaN(data112))) && (isFinite(data112)))){
const err333 = {instancePath:instancePath+"/observation/payloads/" + i12+"/sha256/" + i13,schemaPath:"#/properties/observation/properties/payloads/items/anyOf/0/properties/sha256/items/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err333];
}
else {
vErrors.push(err333);
}
errors++;
}
if(errors === _errs385){
if((typeof data112 == "number") && (isFinite(data112))){
if(data112 > 255 || isNaN(data112)){
const err334 = {instancePath:instancePath+"/observation/payloads/" + i12+"/sha256/" + i13,schemaPath:"#/properties/observation/properties/payloads/items/anyOf/0/properties/sha256/items/maximum",keyword:"maximum",params:{comparison: "<=", limit: 255},message:"must be <= 255"};
if(vErrors === null){
vErrors = [err334];
}
else {
vErrors.push(err334);
}
errors++;
}
else {
if(data112 < 0 || isNaN(data112)){
const err335 = {instancePath:instancePath+"/observation/payloads/" + i12+"/sha256/" + i13,schemaPath:"#/properties/observation/properties/payloads/items/anyOf/0/properties/sha256/items/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err335];
}
else {
vErrors.push(err335);
}
errors++;
}
}
}
}
var valid64 = _errs385 === errors;
if(!valid64){
break;
}
}
}
}
}
else {
const err336 = {instancePath:instancePath+"/observation/payloads/" + i12+"/sha256",schemaPath:"#/properties/observation/properties/payloads/items/anyOf/0/properties/sha256/type",keyword:"type",params:{type: "array"},message:"must be array"};
if(vErrors === null){
vErrors = [err336];
}
else {
vErrors.push(err336);
}
errors++;
}
}
var valid63 = _errs383 === errors;
}
else {
var valid63 = true;
}
if(valid63){
if(data107.bytes !== undefined){
let data113 = data107.bytes;
const _errs387 = errors;
if(!(((typeof data113 == "number") && (!(data113 % 1) && !isNaN(data113))) && (isFinite(data113)))){
const err337 = {instancePath:instancePath+"/observation/payloads/" + i12+"/bytes",schemaPath:"#/properties/observation/properties/payloads/items/anyOf/0/properties/bytes/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err337];
}
else {
vErrors.push(err337);
}
errors++;
}
if(errors === _errs387){
if((typeof data113 == "number") && (isFinite(data113))){
if(data113 > 4294967295 || isNaN(data113)){
const err338 = {instancePath:instancePath+"/observation/payloads/" + i12+"/bytes",schemaPath:"#/properties/observation/properties/payloads/items/anyOf/0/properties/bytes/maximum",keyword:"maximum",params:{comparison: "<=", limit: 4294967295},message:"must be <= 4294967295"};
if(vErrors === null){
vErrors = [err338];
}
else {
vErrors.push(err338);
}
errors++;
}
else {
if(data113 < 0 || isNaN(data113)){
const err339 = {instancePath:instancePath+"/observation/payloads/" + i12+"/bytes",schemaPath:"#/properties/observation/properties/payloads/items/anyOf/0/properties/bytes/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err339];
}
else {
vErrors.push(err339);
}
errors++;
}
}
}
}
var valid63 = _errs387 === errors;
}
else {
var valid63 = true;
}
if(valid63){
if(data107.allow_delete !== undefined){
const _errs389 = errors;
if(typeof data107.allow_delete !== "boolean"){
const err340 = {instancePath:instancePath+"/observation/payloads/" + i12+"/allow_delete",schemaPath:"#/properties/observation/properties/payloads/items/anyOf/0/properties/allow_delete/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"};
if(vErrors === null){
vErrors = [err340];
}
else {
vErrors.push(err340);
}
errors++;
}
var valid63 = _errs389 === errors;
}
else {
var valid63 = true;
}
if(valid63){
if(data107.phase !== undefined){
let data115 = data107.phase;
const _errs391 = errors;
if(typeof data115 !== "string"){
const err341 = {instancePath:instancePath+"/observation/payloads/" + i12+"/phase",schemaPath:"#/properties/observation/properties/payloads/items/anyOf/0/properties/phase/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err341];
}
else {
vErrors.push(err341);
}
errors++;
}
if(!((((data115 === "creating") || (data115 === "ready")) || (data115 === "retiring")) || (data115 === "deleted"))){
const err342 = {instancePath:instancePath+"/observation/payloads/" + i12+"/phase",schemaPath:"#/properties/observation/properties/payloads/items/anyOf/0/properties/phase/enum",keyword:"enum",params:{allowedValues: schema31.properties.observation.properties.payloads.items.anyOf[0].properties.phase.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err342];
}
else {
vErrors.push(err342);
}
errors++;
}
var valid63 = _errs391 === errors;
}
else {
var valid63 = true;
}
if(valid63){
if(data107.retired_at !== undefined){
let data116 = data107.retired_at;
const _errs393 = errors;
const _errs394 = errors;
let valid65 = false;
const _errs395 = errors;
if(!(((typeof data116 == "number") && (!(data116 % 1) && !isNaN(data116))) && (isFinite(data116)))){
const err343 = {instancePath:instancePath+"/observation/payloads/" + i12+"/retired_at",schemaPath:"#/properties/observation/properties/payloads/items/anyOf/0/properties/retired_at/anyOf/0/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err343];
}
else {
vErrors.push(err343);
}
errors++;
}
if(errors === _errs395){
if((typeof data116 == "number") && (isFinite(data116))){
if(data116 > 9007199254740991 || isNaN(data116)){
const err344 = {instancePath:instancePath+"/observation/payloads/" + i12+"/retired_at",schemaPath:"#/properties/observation/properties/payloads/items/anyOf/0/properties/retired_at/anyOf/0/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"};
if(vErrors === null){
vErrors = [err344];
}
else {
vErrors.push(err344);
}
errors++;
}
else {
if(data116 < 0 || isNaN(data116)){
const err345 = {instancePath:instancePath+"/observation/payloads/" + i12+"/retired_at",schemaPath:"#/properties/observation/properties/payloads/items/anyOf/0/properties/retired_at/anyOf/0/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err345];
}
else {
vErrors.push(err345);
}
errors++;
}
}
}
}
var _valid37 = _errs395 === errors;
valid65 = valid65 || _valid37;
const _errs397 = errors;
if(data116 !== null){
const err346 = {instancePath:instancePath+"/observation/payloads/" + i12+"/retired_at",schemaPath:"#/properties/observation/properties/payloads/items/anyOf/0/properties/retired_at/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err346];
}
else {
vErrors.push(err346);
}
errors++;
}
var _valid37 = _errs397 === errors;
valid65 = valid65 || _valid37;
if(!valid65){
const err347 = {instancePath:instancePath+"/observation/payloads/" + i12+"/retired_at",schemaPath:"#/properties/observation/properties/payloads/items/anyOf/0/properties/retired_at/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err347];
}
else {
vErrors.push(err347);
}
errors++;
}
else {
errors = _errs394;
if(vErrors !== null){
if(_errs394){
vErrors.length = _errs394;
}
else {
vErrors = null;
}
}
}
var valid63 = _errs393 === errors;
}
else {
var valid63 = true;
}
if(valid63){
if(data107.deleted_at !== undefined){
let data117 = data107.deleted_at;
const _errs399 = errors;
const _errs400 = errors;
let valid66 = false;
const _errs401 = errors;
if(!(((typeof data117 == "number") && (!(data117 % 1) && !isNaN(data117))) && (isFinite(data117)))){
const err348 = {instancePath:instancePath+"/observation/payloads/" + i12+"/deleted_at",schemaPath:"#/properties/observation/properties/payloads/items/anyOf/0/properties/deleted_at/anyOf/0/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err348];
}
else {
vErrors.push(err348);
}
errors++;
}
if(errors === _errs401){
if((typeof data117 == "number") && (isFinite(data117))){
if(data117 > 9007199254740991 || isNaN(data117)){
const err349 = {instancePath:instancePath+"/observation/payloads/" + i12+"/deleted_at",schemaPath:"#/properties/observation/properties/payloads/items/anyOf/0/properties/deleted_at/anyOf/0/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"};
if(vErrors === null){
vErrors = [err349];
}
else {
vErrors.push(err349);
}
errors++;
}
else {
if(data117 < 0 || isNaN(data117)){
const err350 = {instancePath:instancePath+"/observation/payloads/" + i12+"/deleted_at",schemaPath:"#/properties/observation/properties/payloads/items/anyOf/0/properties/deleted_at/anyOf/0/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err350];
}
else {
vErrors.push(err350);
}
errors++;
}
}
}
}
var _valid38 = _errs401 === errors;
valid66 = valid66 || _valid38;
const _errs403 = errors;
if(data117 !== null){
const err351 = {instancePath:instancePath+"/observation/payloads/" + i12+"/deleted_at",schemaPath:"#/properties/observation/properties/payloads/items/anyOf/0/properties/deleted_at/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err351];
}
else {
vErrors.push(err351);
}
errors++;
}
var _valid38 = _errs403 === errors;
valid66 = valid66 || _valid38;
if(!valid66){
const err352 = {instancePath:instancePath+"/observation/payloads/" + i12+"/deleted_at",schemaPath:"#/properties/observation/properties/payloads/items/anyOf/0/properties/deleted_at/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err352];
}
else {
vErrors.push(err352);
}
errors++;
}
else {
errors = _errs400;
if(vErrors !== null){
if(_errs400){
vErrors.length = _errs400;
}
else {
vErrors = null;
}
}
}
var valid63 = _errs399 === errors;
}
else {
var valid63 = true;
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
const err353 = {instancePath:instancePath+"/observation/payloads/" + i12,schemaPath:"#/properties/observation/properties/payloads/items/anyOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err353];
}
else {
vErrors.push(err353);
}
errors++;
}
}
var _valid36 = _errs374 === errors;
valid62 = valid62 || _valid36;
const _errs405 = errors;
if(data107 !== null){
const err354 = {instancePath:instancePath+"/observation/payloads/" + i12,schemaPath:"#/properties/observation/properties/payloads/items/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err354];
}
else {
vErrors.push(err354);
}
errors++;
}
var _valid36 = _errs405 === errors;
valid62 = valid62 || _valid36;
if(!valid62){
const err355 = {instancePath:instancePath+"/observation/payloads/" + i12,schemaPath:"#/properties/observation/properties/payloads/items/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err355];
}
else {
vErrors.push(err355);
}
errors++;
validate20.errors = vErrors;
return false;
}
else {
errors = _errs373;
if(vErrors !== null){
if(_errs373){
vErrors.length = _errs373;
}
else {
vErrors = null;
}
}
}
var valid61 = _errs372 === errors;
if(!valid61){
break;
}
}
}
}
}
else {
validate20.errors = [{instancePath:instancePath+"/observation/payloads",schemaPath:"#/properties/observation/properties/payloads/type",keyword:"type",params:{type: "array"},message:"must be array"}];
return false;
}
}
var valid1 = _errs370 === errors;
}
else {
var valid1 = true;
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
}
}
else {
validate20.errors = [{instancePath:instancePath+"/observation",schemaPath:"#/properties/observation/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.edges !== undefined){
let data118 = data.edges;
const _errs407 = errors;
if(errors === _errs407){
if(Array.isArray(data118)){
if(data118.length > 32){
validate20.errors = [{instancePath:instancePath+"/edges",schemaPath:"#/properties/edges/maxItems",keyword:"maxItems",params:{limit: 32},message:"must NOT have more than 32 items"}];
return false;
}
else {
if(data118.length < 32){
validate20.errors = [{instancePath:instancePath+"/edges",schemaPath:"#/properties/edges/minItems",keyword:"minItems",params:{limit: 32},message:"must NOT have fewer than 32 items"}];
return false;
}
else {
var valid67 = true;
const len14 = data118.length;
for(let i14=0; i14<len14; i14++){
let data119 = data118[i14];
const _errs409 = errors;
const _errs410 = errors;
let valid68 = false;
const _errs411 = errors;
if(errors === _errs411){
if(data119 && typeof data119 == "object" && !Array.isArray(data119)){
let missing14;
if((((((data119.from === undefined) && (missing14 = "from")) || ((data119.to === undefined) && (missing14 = "to"))) || ((data119.relation === undefined) && (missing14 = "relation"))) || ((data119.from_coverage === undefined) && (missing14 = "from_coverage"))) || ((data119.to_coverage === undefined) && (missing14 = "to_coverage"))){
const err356 = {instancePath:instancePath+"/edges/" + i14,schemaPath:"#/properties/edges/items/anyOf/0/required",keyword:"required",params:{missingProperty: missing14},message:"must have required property '"+missing14+"'"};
if(vErrors === null){
vErrors = [err356];
}
else {
vErrors.push(err356);
}
errors++;
}
else {
const _errs413 = errors;
for(const key14 in data119){
if(!(((((key14 === "from") || (key14 === "to")) || (key14 === "relation")) || (key14 === "from_coverage")) || (key14 === "to_coverage"))){
const err357 = {instancePath:instancePath+"/edges/" + i14,schemaPath:"#/properties/edges/items/anyOf/0/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key14},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err357];
}
else {
vErrors.push(err357);
}
errors++;
break;
}
}
if(_errs413 === errors){
if(data119.from !== undefined){
let data120 = data119.from;
const _errs414 = errors;
if(errors === _errs414){
if(data120 && typeof data120 == "object" && !Array.isArray(data120)){
let missing15;
if(((((data120.realm === undefined) && (missing15 = "realm")) || ((data120.pid === undefined) && (missing15 = "pid"))) || ((data120.kind === undefined) && (missing15 = "kind"))) || ((data120.id === undefined) && (missing15 = "id"))){
const err358 = {instancePath:instancePath+"/edges/" + i14+"/from",schemaPath:"#/properties/edges/items/anyOf/0/properties/from/required",keyword:"required",params:{missingProperty: missing15},message:"must have required property '"+missing15+"'"};
if(vErrors === null){
vErrors = [err358];
}
else {
vErrors.push(err358);
}
errors++;
}
else {
const _errs416 = errors;
for(const key15 in data120){
if(!((((key15 === "realm") || (key15 === "pid")) || (key15 === "kind")) || (key15 === "id"))){
const err359 = {instancePath:instancePath+"/edges/" + i14+"/from",schemaPath:"#/properties/edges/items/anyOf/0/properties/from/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key15},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err359];
}
else {
vErrors.push(err359);
}
errors++;
break;
}
}
if(_errs416 === errors){
if(data120.realm !== undefined){
let data121 = data120.realm;
const _errs417 = errors;
if(!(((typeof data121 == "number") && (!(data121 % 1) && !isNaN(data121))) && (isFinite(data121)))){
const err360 = {instancePath:instancePath+"/edges/" + i14+"/from/realm",schemaPath:"#/properties/edges/items/anyOf/0/properties/from/properties/realm/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err360];
}
else {
vErrors.push(err360);
}
errors++;
}
if(errors === _errs417){
if((typeof data121 == "number") && (isFinite(data121))){
if(data121 > 9007199254740991 || isNaN(data121)){
const err361 = {instancePath:instancePath+"/edges/" + i14+"/from/realm",schemaPath:"#/properties/edges/items/anyOf/0/properties/from/properties/realm/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"};
if(vErrors === null){
vErrors = [err361];
}
else {
vErrors.push(err361);
}
errors++;
}
else {
if(data121 < 0 || isNaN(data121)){
const err362 = {instancePath:instancePath+"/edges/" + i14+"/from/realm",schemaPath:"#/properties/edges/items/anyOf/0/properties/from/properties/realm/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err362];
}
else {
vErrors.push(err362);
}
errors++;
}
}
}
}
var valid70 = _errs417 === errors;
}
else {
var valid70 = true;
}
if(valid70){
if(data120.pid !== undefined){
let data122 = data120.pid;
const _errs419 = errors;
if(!(((typeof data122 == "number") && (!(data122 % 1) && !isNaN(data122))) && (isFinite(data122)))){
const err363 = {instancePath:instancePath+"/edges/" + i14+"/from/pid",schemaPath:"#/properties/edges/items/anyOf/0/properties/from/properties/pid/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err363];
}
else {
vErrors.push(err363);
}
errors++;
}
if(errors === _errs419){
if((typeof data122 == "number") && (isFinite(data122))){
if(data122 > 9007199254740991 || isNaN(data122)){
const err364 = {instancePath:instancePath+"/edges/" + i14+"/from/pid",schemaPath:"#/properties/edges/items/anyOf/0/properties/from/properties/pid/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"};
if(vErrors === null){
vErrors = [err364];
}
else {
vErrors.push(err364);
}
errors++;
}
else {
if(data122 < 0 || isNaN(data122)){
const err365 = {instancePath:instancePath+"/edges/" + i14+"/from/pid",schemaPath:"#/properties/edges/items/anyOf/0/properties/from/properties/pid/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err365];
}
else {
vErrors.push(err365);
}
errors++;
}
}
}
}
var valid70 = _errs419 === errors;
}
else {
var valid70 = true;
}
if(valid70){
if(data120.kind !== undefined){
let data123 = data120.kind;
const _errs421 = errors;
if(typeof data123 !== "string"){
const err366 = {instancePath:instancePath+"/edges/" + i14+"/from/kind",schemaPath:"#/properties/edges/items/anyOf/0/properties/from/properties/kind/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err366];
}
else {
vErrors.push(err366);
}
errors++;
}
if(!((((((data123 === "input") || (data123 === "turn")) || (data123 === "output")) || (data123 === "effect")) || (data123 === "event")) || (data123 === "state"))){
const err367 = {instancePath:instancePath+"/edges/" + i14+"/from/kind",schemaPath:"#/properties/edges/items/anyOf/0/properties/from/properties/kind/enum",keyword:"enum",params:{allowedValues: schema31.properties.edges.items.anyOf[0].properties.from.properties.kind.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err367];
}
else {
vErrors.push(err367);
}
errors++;
}
var valid70 = _errs421 === errors;
}
else {
var valid70 = true;
}
if(valid70){
if(data120.id !== undefined){
let data124 = data120.id;
const _errs423 = errors;
if(!(((typeof data124 == "number") && (!(data124 % 1) && !isNaN(data124))) && (isFinite(data124)))){
const err368 = {instancePath:instancePath+"/edges/" + i14+"/from/id",schemaPath:"#/properties/edges/items/anyOf/0/properties/from/properties/id/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err368];
}
else {
vErrors.push(err368);
}
errors++;
}
if(errors === _errs423){
if((typeof data124 == "number") && (isFinite(data124))){
if(data124 > 9007199254740991 || isNaN(data124)){
const err369 = {instancePath:instancePath+"/edges/" + i14+"/from/id",schemaPath:"#/properties/edges/items/anyOf/0/properties/from/properties/id/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"};
if(vErrors === null){
vErrors = [err369];
}
else {
vErrors.push(err369);
}
errors++;
}
else {
if(data124 < 0 || isNaN(data124)){
const err370 = {instancePath:instancePath+"/edges/" + i14+"/from/id",schemaPath:"#/properties/edges/items/anyOf/0/properties/from/properties/id/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err370];
}
else {
vErrors.push(err370);
}
errors++;
}
}
}
}
var valid70 = _errs423 === errors;
}
else {
var valid70 = true;
}
}
}
}
}
}
}
else {
const err371 = {instancePath:instancePath+"/edges/" + i14+"/from",schemaPath:"#/properties/edges/items/anyOf/0/properties/from/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err371];
}
else {
vErrors.push(err371);
}
errors++;
}
}
var valid69 = _errs414 === errors;
}
else {
var valid69 = true;
}
if(valid69){
if(data119.to !== undefined){
let data125 = data119.to;
const _errs425 = errors;
if(errors === _errs425){
if(data125 && typeof data125 == "object" && !Array.isArray(data125)){
let missing16;
if(((((data125.realm === undefined) && (missing16 = "realm")) || ((data125.pid === undefined) && (missing16 = "pid"))) || ((data125.kind === undefined) && (missing16 = "kind"))) || ((data125.id === undefined) && (missing16 = "id"))){
const err372 = {instancePath:instancePath+"/edges/" + i14+"/to",schemaPath:"#/properties/edges/items/anyOf/0/properties/to/required",keyword:"required",params:{missingProperty: missing16},message:"must have required property '"+missing16+"'"};
if(vErrors === null){
vErrors = [err372];
}
else {
vErrors.push(err372);
}
errors++;
}
else {
const _errs427 = errors;
for(const key16 in data125){
if(!((((key16 === "realm") || (key16 === "pid")) || (key16 === "kind")) || (key16 === "id"))){
const err373 = {instancePath:instancePath+"/edges/" + i14+"/to",schemaPath:"#/properties/edges/items/anyOf/0/properties/to/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key16},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err373];
}
else {
vErrors.push(err373);
}
errors++;
break;
}
}
if(_errs427 === errors){
if(data125.realm !== undefined){
let data126 = data125.realm;
const _errs428 = errors;
if(!(((typeof data126 == "number") && (!(data126 % 1) && !isNaN(data126))) && (isFinite(data126)))){
const err374 = {instancePath:instancePath+"/edges/" + i14+"/to/realm",schemaPath:"#/properties/edges/items/anyOf/0/properties/to/properties/realm/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err374];
}
else {
vErrors.push(err374);
}
errors++;
}
if(errors === _errs428){
if((typeof data126 == "number") && (isFinite(data126))){
if(data126 > 9007199254740991 || isNaN(data126)){
const err375 = {instancePath:instancePath+"/edges/" + i14+"/to/realm",schemaPath:"#/properties/edges/items/anyOf/0/properties/to/properties/realm/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"};
if(vErrors === null){
vErrors = [err375];
}
else {
vErrors.push(err375);
}
errors++;
}
else {
if(data126 < 0 || isNaN(data126)){
const err376 = {instancePath:instancePath+"/edges/" + i14+"/to/realm",schemaPath:"#/properties/edges/items/anyOf/0/properties/to/properties/realm/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err376];
}
else {
vErrors.push(err376);
}
errors++;
}
}
}
}
var valid71 = _errs428 === errors;
}
else {
var valid71 = true;
}
if(valid71){
if(data125.pid !== undefined){
let data127 = data125.pid;
const _errs430 = errors;
if(!(((typeof data127 == "number") && (!(data127 % 1) && !isNaN(data127))) && (isFinite(data127)))){
const err377 = {instancePath:instancePath+"/edges/" + i14+"/to/pid",schemaPath:"#/properties/edges/items/anyOf/0/properties/to/properties/pid/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err377];
}
else {
vErrors.push(err377);
}
errors++;
}
if(errors === _errs430){
if((typeof data127 == "number") && (isFinite(data127))){
if(data127 > 9007199254740991 || isNaN(data127)){
const err378 = {instancePath:instancePath+"/edges/" + i14+"/to/pid",schemaPath:"#/properties/edges/items/anyOf/0/properties/to/properties/pid/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"};
if(vErrors === null){
vErrors = [err378];
}
else {
vErrors.push(err378);
}
errors++;
}
else {
if(data127 < 0 || isNaN(data127)){
const err379 = {instancePath:instancePath+"/edges/" + i14+"/to/pid",schemaPath:"#/properties/edges/items/anyOf/0/properties/to/properties/pid/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err379];
}
else {
vErrors.push(err379);
}
errors++;
}
}
}
}
var valid71 = _errs430 === errors;
}
else {
var valid71 = true;
}
if(valid71){
if(data125.kind !== undefined){
let data128 = data125.kind;
const _errs432 = errors;
if(typeof data128 !== "string"){
const err380 = {instancePath:instancePath+"/edges/" + i14+"/to/kind",schemaPath:"#/properties/edges/items/anyOf/0/properties/to/properties/kind/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err380];
}
else {
vErrors.push(err380);
}
errors++;
}
if(!((((((data128 === "input") || (data128 === "turn")) || (data128 === "output")) || (data128 === "effect")) || (data128 === "event")) || (data128 === "state"))){
const err381 = {instancePath:instancePath+"/edges/" + i14+"/to/kind",schemaPath:"#/properties/edges/items/anyOf/0/properties/to/properties/kind/enum",keyword:"enum",params:{allowedValues: schema31.properties.edges.items.anyOf[0].properties.to.properties.kind.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err381];
}
else {
vErrors.push(err381);
}
errors++;
}
var valid71 = _errs432 === errors;
}
else {
var valid71 = true;
}
if(valid71){
if(data125.id !== undefined){
let data129 = data125.id;
const _errs434 = errors;
if(!(((typeof data129 == "number") && (!(data129 % 1) && !isNaN(data129))) && (isFinite(data129)))){
const err382 = {instancePath:instancePath+"/edges/" + i14+"/to/id",schemaPath:"#/properties/edges/items/anyOf/0/properties/to/properties/id/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err382];
}
else {
vErrors.push(err382);
}
errors++;
}
if(errors === _errs434){
if((typeof data129 == "number") && (isFinite(data129))){
if(data129 > 9007199254740991 || isNaN(data129)){
const err383 = {instancePath:instancePath+"/edges/" + i14+"/to/id",schemaPath:"#/properties/edges/items/anyOf/0/properties/to/properties/id/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"};
if(vErrors === null){
vErrors = [err383];
}
else {
vErrors.push(err383);
}
errors++;
}
else {
if(data129 < 0 || isNaN(data129)){
const err384 = {instancePath:instancePath+"/edges/" + i14+"/to/id",schemaPath:"#/properties/edges/items/anyOf/0/properties/to/properties/id/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err384];
}
else {
vErrors.push(err384);
}
errors++;
}
}
}
}
var valid71 = _errs434 === errors;
}
else {
var valid71 = true;
}
}
}
}
}
}
}
else {
const err385 = {instancePath:instancePath+"/edges/" + i14+"/to",schemaPath:"#/properties/edges/items/anyOf/0/properties/to/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err385];
}
else {
vErrors.push(err385);
}
errors++;
}
}
var valid69 = _errs425 === errors;
}
else {
var valid69 = true;
}
if(valid69){
if(data119.relation !== undefined){
let data130 = data119.relation;
const _errs436 = errors;
if(typeof data130 !== "string"){
const err386 = {instancePath:instancePath+"/edges/" + i14+"/relation",schemaPath:"#/properties/edges/items/anyOf/0/properties/relation/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err386];
}
else {
vErrors.push(err386);
}
errors++;
}
if(!(((((data130 === "input_to_turn") || (data130 === "turn_to_effect")) || (data130 === "turn_to_output")) || (data130 === "output_to_admission")) || (data130 === "effect_to_observation"))){
const err387 = {instancePath:instancePath+"/edges/" + i14+"/relation",schemaPath:"#/properties/edges/items/anyOf/0/properties/relation/enum",keyword:"enum",params:{allowedValues: schema31.properties.edges.items.anyOf[0].properties.relation.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err387];
}
else {
vErrors.push(err387);
}
errors++;
}
var valid69 = _errs436 === errors;
}
else {
var valid69 = true;
}
if(valid69){
if(data119.from_coverage !== undefined){
let data131 = data119.from_coverage;
const _errs438 = errors;
if(typeof data131 !== "string"){
const err388 = {instancePath:instancePath+"/edges/" + i14+"/from_coverage",schemaPath:"#/properties/edges/items/anyOf/0/properties/from_coverage/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err388];
}
else {
vErrors.push(err388);
}
errors++;
}
if(!(((data131 === "retained") || (data131 === "reclaimed")) || (data131 === "current_state"))){
const err389 = {instancePath:instancePath+"/edges/" + i14+"/from_coverage",schemaPath:"#/properties/edges/items/anyOf/0/properties/from_coverage/enum",keyword:"enum",params:{allowedValues: schema31.properties.edges.items.anyOf[0].properties.from_coverage.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err389];
}
else {
vErrors.push(err389);
}
errors++;
}
var valid69 = _errs438 === errors;
}
else {
var valid69 = true;
}
if(valid69){
if(data119.to_coverage !== undefined){
let data132 = data119.to_coverage;
const _errs440 = errors;
if(typeof data132 !== "string"){
const err390 = {instancePath:instancePath+"/edges/" + i14+"/to_coverage",schemaPath:"#/properties/edges/items/anyOf/0/properties/to_coverage/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err390];
}
else {
vErrors.push(err390);
}
errors++;
}
if(!(((data132 === "retained") || (data132 === "reclaimed")) || (data132 === "current_state"))){
const err391 = {instancePath:instancePath+"/edges/" + i14+"/to_coverage",schemaPath:"#/properties/edges/items/anyOf/0/properties/to_coverage/enum",keyword:"enum",params:{allowedValues: schema31.properties.edges.items.anyOf[0].properties.to_coverage.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err391];
}
else {
vErrors.push(err391);
}
errors++;
}
var valid69 = _errs440 === errors;
}
else {
var valid69 = true;
}
}
}
}
}
}
}
}
else {
const err392 = {instancePath:instancePath+"/edges/" + i14,schemaPath:"#/properties/edges/items/anyOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err392];
}
else {
vErrors.push(err392);
}
errors++;
}
}
var _valid39 = _errs411 === errors;
valid68 = valid68 || _valid39;
const _errs442 = errors;
if(data119 !== null){
const err393 = {instancePath:instancePath+"/edges/" + i14,schemaPath:"#/properties/edges/items/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err393];
}
else {
vErrors.push(err393);
}
errors++;
}
var _valid39 = _errs442 === errors;
valid68 = valid68 || _valid39;
if(!valid68){
const err394 = {instancePath:instancePath+"/edges/" + i14,schemaPath:"#/properties/edges/items/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err394];
}
else {
vErrors.push(err394);
}
errors++;
validate20.errors = vErrors;
return false;
}
else {
errors = _errs410;
if(vErrors !== null){
if(_errs410){
vErrors.length = _errs410;
}
else {
vErrors = null;
}
}
}
var valid67 = _errs409 === errors;
if(!valid67){
break;
}
}
}
}
}
else {
validate20.errors = [{instancePath:instancePath+"/edges",schemaPath:"#/properties/edges/type",keyword:"type",params:{type: "array"},message:"must be array"}];
return false;
}
}
var valid0 = _errs407 === errors;
}
else {
var valid0 = true;
}
}
}
}
}
else {
validate20.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate20.errors = vErrors;
return errors === 0;
}
validate20.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

export const StateResponse = validate21;
const schema32 = {"type":"object","additionalProperties":false,"properties":{"observation":{"type":"object","additionalProperties":false,"properties":{"version":{"type":"integer","minimum":0,"maximum":4294967295},"realm":{"type":"integer","minimum":0,"maximum":9007199254740991},"principal_sequence":{"type":"integer","minimum":0,"maximum":9007199254740991},"reader":{"type":"object","additionalProperties":false,"properties":{"principal":{"type":"integer","minimum":0,"maximum":255},"permissions":{"type":"integer","minimum":0,"maximum":65535},"pid":{"anyOf":[{"type":"integer","minimum":0,"maximum":9007199254740991},{"type":"null"}]}},"required":["principal","permissions","pid"]},"kind":{"type":"string","enum":["capabilities","resources","associations","entries","view"]},"cut":{"type":"object","additionalProperties":false,"properties":{"position":{"type":"integer","minimum":0,"maximum":9007199254740991},"policy_revision":{"type":"integer","minimum":0,"maximum":9007199254740991},"retained_from":{"type":"integer","minimum":0,"maximum":9007199254740991}},"required":["position","policy_revision","retained_from"]},"capabilities":{"anyOf":[{"type":"object","additionalProperties":false,"properties":{"resources":{"type":"integer","minimum":0,"maximum":65535},"keys_per_resource":{"type":"integer","minimum":0,"maximum":65535},"associations":{"type":"integer","minimum":0,"maximum":65535},"active_views":{"type":"integer","minimum":0,"maximum":65535},"mutations_per_turn":{"type":"integer","minimum":0,"maximum":65535},"key_bytes":{"type":"integer","minimum":0,"maximum":65535},"value_bytes":{"type":"integer","minimum":0,"maximum":65535},"page_entries":{"type":"integer","minimum":0,"maximum":65535},"view_ms":{"type":"integer","minimum":0,"maximum":4294967295}},"required":["resources","keys_per_resource","associations","active_views","mutations_per_turn","key_bytes","value_bytes","page_entries","view_ms"]},{"type":"null"}]},"next":{"anyOf":[{"type":"integer","minimum":0,"maximum":65535},{"type":"null"}]},"resources":{"type":"array","minItems":8,"maxItems":8,"items":{"anyOf":[{"type":"object","additionalProperties":false,"properties":{"id":{"type":"integer","minimum":0,"maximum":9007199254740991},"writer":{"type":"integer","minimum":0,"maximum":9007199254740991},"owner":{"anyOf":[{"type":"integer","minimum":0,"maximum":9007199254740991},{"type":"null"}]},"revision":{"type":"integer","minimum":0,"maximum":9007199254740991},"deadline_ms":{"anyOf":[{"type":"integer","minimum":0,"maximum":9007199254740991},{"type":"null"}]},"history_ms":{"anyOf":[{"type":"integer","minimum":0,"maximum":4294967295},{"type":"null"}]},"changed_ms":{"type":"integer","minimum":0,"maximum":9007199254740991},"phase":{"type":"string","enum":["active","retired","reclaimed"]},"retired_at":{"anyOf":[{"type":"integer","minimum":0,"maximum":9007199254740991},{"type":"null"}]},"last_turn":{"anyOf":[{"type":"integer","minimum":0,"maximum":9007199254740991},{"type":"null"}]}},"required":["id","writer","owner","revision","deadline_ms","history_ms","changed_ms","phase","retired_at","last_turn"]},{"type":"null"}]}},"associations":{"type":"array","minItems":8,"maxItems":8,"items":{"anyOf":[{"type":"object","additionalProperties":false,"properties":{"pid":{"type":"integer","minimum":0,"maximum":9007199254740991},"name":{"type":"string","pattern":"^(?:[0-9a-f]{2})*$","maxLength":512},"resource":{"type":"integer","minimum":0,"maximum":9007199254740991},"revision":{"type":"integer","minimum":0,"maximum":9007199254740991},"required":{"type":"boolean"}},"required":["pid","name","resource","revision","required"]},{"type":"null"}]}},"entries":{"type":"array","minItems":8,"maxItems":8,"items":{"anyOf":[{"type":"object","additionalProperties":false,"properties":{"key":{"type":"string","pattern":"^(?:[0-9a-f]{2})*$","maxLength":512},"value":{"type":"string","pattern":"^(?:[0-9a-f]{2})*$","maxLength":512},"revision":{"type":"integer","minimum":0,"maximum":9007199254740991}},"required":["key","value","revision"]},{"type":"null"}]}},"view":{"anyOf":[{"type":"object","additionalProperties":false,"properties":{"id":{"type":"integer","minimum":0,"maximum":9007199254740991},"pid":{"type":"integer","minimum":0,"maximum":9007199254740991},"principal":{"type":"integer","minimum":0,"maximum":255},"generation":{"type":"integer","minimum":0,"maximum":9007199254740991},"input":{"type":"integer","minimum":0,"maximum":9007199254740991},"process_revision":{"type":"integer","minimum":0,"maximum":9007199254740991},"resource":{"type":"integer","minimum":0,"maximum":9007199254740991},"revision":{"type":"integer","minimum":0,"maximum":9007199254740991},"deadline_ms":{"type":"integer","minimum":0,"maximum":9007199254740991}},"required":["id","pid","principal","generation","input","process_revision","resource","revision","deadline_ms"]},{"type":"null"}]}},"required":["version","realm","principal_sequence","reader","kind","cut","capabilities","next","resources","associations","entries","view"]}},"required":["observation"]};

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
if((data.observation === undefined) && (missing0 = "observation")){
validate21.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(key0 === "observation")){
validate21.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.observation !== undefined){
let data0 = data.observation;
const _errs2 = errors;
if(errors === _errs2){
if(data0 && typeof data0 == "object" && !Array.isArray(data0)){
let missing1;
if(((((((((((((data0.version === undefined) && (missing1 = "version")) || ((data0.realm === undefined) && (missing1 = "realm"))) || ((data0.principal_sequence === undefined) && (missing1 = "principal_sequence"))) || ((data0.reader === undefined) && (missing1 = "reader"))) || ((data0.kind === undefined) && (missing1 = "kind"))) || ((data0.cut === undefined) && (missing1 = "cut"))) || ((data0.capabilities === undefined) && (missing1 = "capabilities"))) || ((data0.next === undefined) && (missing1 = "next"))) || ((data0.resources === undefined) && (missing1 = "resources"))) || ((data0.associations === undefined) && (missing1 = "associations"))) || ((data0.entries === undefined) && (missing1 = "entries"))) || ((data0.view === undefined) && (missing1 = "view"))){
validate21.errors = [{instancePath:instancePath+"/observation",schemaPath:"#/properties/observation/required",keyword:"required",params:{missingProperty: missing1},message:"must have required property '"+missing1+"'"}];
return false;
}
else {
const _errs4 = errors;
for(const key1 in data0){
if(!(func1.call(schema32.properties.observation.properties, key1))){
validate21.errors = [{instancePath:instancePath+"/observation",schemaPath:"#/properties/observation/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key1},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs4 === errors){
if(data0.version !== undefined){
let data1 = data0.version;
const _errs5 = errors;
if(!(((typeof data1 == "number") && (!(data1 % 1) && !isNaN(data1))) && (isFinite(data1)))){
validate21.errors = [{instancePath:instancePath+"/observation/version",schemaPath:"#/properties/observation/properties/version/type",keyword:"type",params:{type: "integer"},message:"must be integer"}];
return false;
}
if(errors === _errs5){
if((typeof data1 == "number") && (isFinite(data1))){
if(data1 > 4294967295 || isNaN(data1)){
validate21.errors = [{instancePath:instancePath+"/observation/version",schemaPath:"#/properties/observation/properties/version/maximum",keyword:"maximum",params:{comparison: "<=", limit: 4294967295},message:"must be <= 4294967295"}];
return false;
}
else {
if(data1 < 0 || isNaN(data1)){
validate21.errors = [{instancePath:instancePath+"/observation/version",schemaPath:"#/properties/observation/properties/version/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"}];
return false;
}
}
}
}
var valid1 = _errs5 === errors;
}
else {
var valid1 = true;
}
if(valid1){
if(data0.realm !== undefined){
let data2 = data0.realm;
const _errs7 = errors;
if(!(((typeof data2 == "number") && (!(data2 % 1) && !isNaN(data2))) && (isFinite(data2)))){
validate21.errors = [{instancePath:instancePath+"/observation/realm",schemaPath:"#/properties/observation/properties/realm/type",keyword:"type",params:{type: "integer"},message:"must be integer"}];
return false;
}
if(errors === _errs7){
if((typeof data2 == "number") && (isFinite(data2))){
if(data2 > 9007199254740991 || isNaN(data2)){
validate21.errors = [{instancePath:instancePath+"/observation/realm",schemaPath:"#/properties/observation/properties/realm/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"}];
return false;
}
else {
if(data2 < 0 || isNaN(data2)){
validate21.errors = [{instancePath:instancePath+"/observation/realm",schemaPath:"#/properties/observation/properties/realm/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"}];
return false;
}
}
}
}
var valid1 = _errs7 === errors;
}
else {
var valid1 = true;
}
if(valid1){
if(data0.principal_sequence !== undefined){
let data3 = data0.principal_sequence;
const _errs9 = errors;
if(!(((typeof data3 == "number") && (!(data3 % 1) && !isNaN(data3))) && (isFinite(data3)))){
validate21.errors = [{instancePath:instancePath+"/observation/principal_sequence",schemaPath:"#/properties/observation/properties/principal_sequence/type",keyword:"type",params:{type: "integer"},message:"must be integer"}];
return false;
}
if(errors === _errs9){
if((typeof data3 == "number") && (isFinite(data3))){
if(data3 > 9007199254740991 || isNaN(data3)){
validate21.errors = [{instancePath:instancePath+"/observation/principal_sequence",schemaPath:"#/properties/observation/properties/principal_sequence/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"}];
return false;
}
else {
if(data3 < 0 || isNaN(data3)){
validate21.errors = [{instancePath:instancePath+"/observation/principal_sequence",schemaPath:"#/properties/observation/properties/principal_sequence/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"}];
return false;
}
}
}
}
var valid1 = _errs9 === errors;
}
else {
var valid1 = true;
}
if(valid1){
if(data0.reader !== undefined){
let data4 = data0.reader;
const _errs11 = errors;
if(errors === _errs11){
if(data4 && typeof data4 == "object" && !Array.isArray(data4)){
let missing2;
if((((data4.principal === undefined) && (missing2 = "principal")) || ((data4.permissions === undefined) && (missing2 = "permissions"))) || ((data4.pid === undefined) && (missing2 = "pid"))){
validate21.errors = [{instancePath:instancePath+"/observation/reader",schemaPath:"#/properties/observation/properties/reader/required",keyword:"required",params:{missingProperty: missing2},message:"must have required property '"+missing2+"'"}];
return false;
}
else {
const _errs13 = errors;
for(const key2 in data4){
if(!(((key2 === "principal") || (key2 === "permissions")) || (key2 === "pid"))){
validate21.errors = [{instancePath:instancePath+"/observation/reader",schemaPath:"#/properties/observation/properties/reader/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key2},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs13 === errors){
if(data4.principal !== undefined){
let data5 = data4.principal;
const _errs14 = errors;
if(!(((typeof data5 == "number") && (!(data5 % 1) && !isNaN(data5))) && (isFinite(data5)))){
validate21.errors = [{instancePath:instancePath+"/observation/reader/principal",schemaPath:"#/properties/observation/properties/reader/properties/principal/type",keyword:"type",params:{type: "integer"},message:"must be integer"}];
return false;
}
if(errors === _errs14){
if((typeof data5 == "number") && (isFinite(data5))){
if(data5 > 255 || isNaN(data5)){
validate21.errors = [{instancePath:instancePath+"/observation/reader/principal",schemaPath:"#/properties/observation/properties/reader/properties/principal/maximum",keyword:"maximum",params:{comparison: "<=", limit: 255},message:"must be <= 255"}];
return false;
}
else {
if(data5 < 0 || isNaN(data5)){
validate21.errors = [{instancePath:instancePath+"/observation/reader/principal",schemaPath:"#/properties/observation/properties/reader/properties/principal/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"}];
return false;
}
}
}
}
var valid2 = _errs14 === errors;
}
else {
var valid2 = true;
}
if(valid2){
if(data4.permissions !== undefined){
let data6 = data4.permissions;
const _errs16 = errors;
if(!(((typeof data6 == "number") && (!(data6 % 1) && !isNaN(data6))) && (isFinite(data6)))){
validate21.errors = [{instancePath:instancePath+"/observation/reader/permissions",schemaPath:"#/properties/observation/properties/reader/properties/permissions/type",keyword:"type",params:{type: "integer"},message:"must be integer"}];
return false;
}
if(errors === _errs16){
if((typeof data6 == "number") && (isFinite(data6))){
if(data6 > 65535 || isNaN(data6)){
validate21.errors = [{instancePath:instancePath+"/observation/reader/permissions",schemaPath:"#/properties/observation/properties/reader/properties/permissions/maximum",keyword:"maximum",params:{comparison: "<=", limit: 65535},message:"must be <= 65535"}];
return false;
}
else {
if(data6 < 0 || isNaN(data6)){
validate21.errors = [{instancePath:instancePath+"/observation/reader/permissions",schemaPath:"#/properties/observation/properties/reader/properties/permissions/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"}];
return false;
}
}
}
}
var valid2 = _errs16 === errors;
}
else {
var valid2 = true;
}
if(valid2){
if(data4.pid !== undefined){
let data7 = data4.pid;
const _errs18 = errors;
const _errs19 = errors;
let valid3 = false;
const _errs20 = errors;
if(!(((typeof data7 == "number") && (!(data7 % 1) && !isNaN(data7))) && (isFinite(data7)))){
const err0 = {instancePath:instancePath+"/observation/reader/pid",schemaPath:"#/properties/observation/properties/reader/properties/pid/anyOf/0/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err0];
}
else {
vErrors.push(err0);
}
errors++;
}
if(errors === _errs20){
if((typeof data7 == "number") && (isFinite(data7))){
if(data7 > 9007199254740991 || isNaN(data7)){
const err1 = {instancePath:instancePath+"/observation/reader/pid",schemaPath:"#/properties/observation/properties/reader/properties/pid/anyOf/0/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"};
if(vErrors === null){
vErrors = [err1];
}
else {
vErrors.push(err1);
}
errors++;
}
else {
if(data7 < 0 || isNaN(data7)){
const err2 = {instancePath:instancePath+"/observation/reader/pid",schemaPath:"#/properties/observation/properties/reader/properties/pid/anyOf/0/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err2];
}
else {
vErrors.push(err2);
}
errors++;
}
}
}
}
var _valid0 = _errs20 === errors;
valid3 = valid3 || _valid0;
const _errs22 = errors;
if(data7 !== null){
const err3 = {instancePath:instancePath+"/observation/reader/pid",schemaPath:"#/properties/observation/properties/reader/properties/pid/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err3];
}
else {
vErrors.push(err3);
}
errors++;
}
var _valid0 = _errs22 === errors;
valid3 = valid3 || _valid0;
if(!valid3){
const err4 = {instancePath:instancePath+"/observation/reader/pid",schemaPath:"#/properties/observation/properties/reader/properties/pid/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err4];
}
else {
vErrors.push(err4);
}
errors++;
validate21.errors = vErrors;
return false;
}
else {
errors = _errs19;
if(vErrors !== null){
if(_errs19){
vErrors.length = _errs19;
}
else {
vErrors = null;
}
}
}
var valid2 = _errs18 === errors;
}
else {
var valid2 = true;
}
}
}
}
}
}
else {
validate21.errors = [{instancePath:instancePath+"/observation/reader",schemaPath:"#/properties/observation/properties/reader/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
var valid1 = _errs11 === errors;
}
else {
var valid1 = true;
}
if(valid1){
if(data0.kind !== undefined){
let data8 = data0.kind;
const _errs24 = errors;
if(typeof data8 !== "string"){
validate21.errors = [{instancePath:instancePath+"/observation/kind",schemaPath:"#/properties/observation/properties/kind/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
if(!(((((data8 === "capabilities") || (data8 === "resources")) || (data8 === "associations")) || (data8 === "entries")) || (data8 === "view"))){
validate21.errors = [{instancePath:instancePath+"/observation/kind",schemaPath:"#/properties/observation/properties/kind/enum",keyword:"enum",params:{allowedValues: schema32.properties.observation.properties.kind.enum},message:"must be equal to one of the allowed values"}];
return false;
}
var valid1 = _errs24 === errors;
}
else {
var valid1 = true;
}
if(valid1){
if(data0.cut !== undefined){
let data9 = data0.cut;
const _errs26 = errors;
if(errors === _errs26){
if(data9 && typeof data9 == "object" && !Array.isArray(data9)){
let missing3;
if((((data9.position === undefined) && (missing3 = "position")) || ((data9.policy_revision === undefined) && (missing3 = "policy_revision"))) || ((data9.retained_from === undefined) && (missing3 = "retained_from"))){
validate21.errors = [{instancePath:instancePath+"/observation/cut",schemaPath:"#/properties/observation/properties/cut/required",keyword:"required",params:{missingProperty: missing3},message:"must have required property '"+missing3+"'"}];
return false;
}
else {
const _errs28 = errors;
for(const key3 in data9){
if(!(((key3 === "position") || (key3 === "policy_revision")) || (key3 === "retained_from"))){
validate21.errors = [{instancePath:instancePath+"/observation/cut",schemaPath:"#/properties/observation/properties/cut/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key3},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs28 === errors){
if(data9.position !== undefined){
let data10 = data9.position;
const _errs29 = errors;
if(!(((typeof data10 == "number") && (!(data10 % 1) && !isNaN(data10))) && (isFinite(data10)))){
validate21.errors = [{instancePath:instancePath+"/observation/cut/position",schemaPath:"#/properties/observation/properties/cut/properties/position/type",keyword:"type",params:{type: "integer"},message:"must be integer"}];
return false;
}
if(errors === _errs29){
if((typeof data10 == "number") && (isFinite(data10))){
if(data10 > 9007199254740991 || isNaN(data10)){
validate21.errors = [{instancePath:instancePath+"/observation/cut/position",schemaPath:"#/properties/observation/properties/cut/properties/position/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"}];
return false;
}
else {
if(data10 < 0 || isNaN(data10)){
validate21.errors = [{instancePath:instancePath+"/observation/cut/position",schemaPath:"#/properties/observation/properties/cut/properties/position/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"}];
return false;
}
}
}
}
var valid4 = _errs29 === errors;
}
else {
var valid4 = true;
}
if(valid4){
if(data9.policy_revision !== undefined){
let data11 = data9.policy_revision;
const _errs31 = errors;
if(!(((typeof data11 == "number") && (!(data11 % 1) && !isNaN(data11))) && (isFinite(data11)))){
validate21.errors = [{instancePath:instancePath+"/observation/cut/policy_revision",schemaPath:"#/properties/observation/properties/cut/properties/policy_revision/type",keyword:"type",params:{type: "integer"},message:"must be integer"}];
return false;
}
if(errors === _errs31){
if((typeof data11 == "number") && (isFinite(data11))){
if(data11 > 9007199254740991 || isNaN(data11)){
validate21.errors = [{instancePath:instancePath+"/observation/cut/policy_revision",schemaPath:"#/properties/observation/properties/cut/properties/policy_revision/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"}];
return false;
}
else {
if(data11 < 0 || isNaN(data11)){
validate21.errors = [{instancePath:instancePath+"/observation/cut/policy_revision",schemaPath:"#/properties/observation/properties/cut/properties/policy_revision/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"}];
return false;
}
}
}
}
var valid4 = _errs31 === errors;
}
else {
var valid4 = true;
}
if(valid4){
if(data9.retained_from !== undefined){
let data12 = data9.retained_from;
const _errs33 = errors;
if(!(((typeof data12 == "number") && (!(data12 % 1) && !isNaN(data12))) && (isFinite(data12)))){
validate21.errors = [{instancePath:instancePath+"/observation/cut/retained_from",schemaPath:"#/properties/observation/properties/cut/properties/retained_from/type",keyword:"type",params:{type: "integer"},message:"must be integer"}];
return false;
}
if(errors === _errs33){
if((typeof data12 == "number") && (isFinite(data12))){
if(data12 > 9007199254740991 || isNaN(data12)){
validate21.errors = [{instancePath:instancePath+"/observation/cut/retained_from",schemaPath:"#/properties/observation/properties/cut/properties/retained_from/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"}];
return false;
}
else {
if(data12 < 0 || isNaN(data12)){
validate21.errors = [{instancePath:instancePath+"/observation/cut/retained_from",schemaPath:"#/properties/observation/properties/cut/properties/retained_from/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"}];
return false;
}
}
}
}
var valid4 = _errs33 === errors;
}
else {
var valid4 = true;
}
}
}
}
}
}
else {
validate21.errors = [{instancePath:instancePath+"/observation/cut",schemaPath:"#/properties/observation/properties/cut/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
var valid1 = _errs26 === errors;
}
else {
var valid1 = true;
}
if(valid1){
if(data0.capabilities !== undefined){
let data13 = data0.capabilities;
const _errs35 = errors;
const _errs36 = errors;
let valid5 = false;
const _errs37 = errors;
if(errors === _errs37){
if(data13 && typeof data13 == "object" && !Array.isArray(data13)){
let missing4;
if((((((((((data13.resources === undefined) && (missing4 = "resources")) || ((data13.keys_per_resource === undefined) && (missing4 = "keys_per_resource"))) || ((data13.associations === undefined) && (missing4 = "associations"))) || ((data13.active_views === undefined) && (missing4 = "active_views"))) || ((data13.mutations_per_turn === undefined) && (missing4 = "mutations_per_turn"))) || ((data13.key_bytes === undefined) && (missing4 = "key_bytes"))) || ((data13.value_bytes === undefined) && (missing4 = "value_bytes"))) || ((data13.page_entries === undefined) && (missing4 = "page_entries"))) || ((data13.view_ms === undefined) && (missing4 = "view_ms"))){
const err5 = {instancePath:instancePath+"/observation/capabilities",schemaPath:"#/properties/observation/properties/capabilities/anyOf/0/required",keyword:"required",params:{missingProperty: missing4},message:"must have required property '"+missing4+"'"};
if(vErrors === null){
vErrors = [err5];
}
else {
vErrors.push(err5);
}
errors++;
}
else {
const _errs39 = errors;
for(const key4 in data13){
if(!(func1.call(schema32.properties.observation.properties.capabilities.anyOf[0].properties, key4))){
const err6 = {instancePath:instancePath+"/observation/capabilities",schemaPath:"#/properties/observation/properties/capabilities/anyOf/0/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key4},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err6];
}
else {
vErrors.push(err6);
}
errors++;
break;
}
}
if(_errs39 === errors){
if(data13.resources !== undefined){
let data14 = data13.resources;
const _errs40 = errors;
if(!(((typeof data14 == "number") && (!(data14 % 1) && !isNaN(data14))) && (isFinite(data14)))){
const err7 = {instancePath:instancePath+"/observation/capabilities/resources",schemaPath:"#/properties/observation/properties/capabilities/anyOf/0/properties/resources/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err7];
}
else {
vErrors.push(err7);
}
errors++;
}
if(errors === _errs40){
if((typeof data14 == "number") && (isFinite(data14))){
if(data14 > 65535 || isNaN(data14)){
const err8 = {instancePath:instancePath+"/observation/capabilities/resources",schemaPath:"#/properties/observation/properties/capabilities/anyOf/0/properties/resources/maximum",keyword:"maximum",params:{comparison: "<=", limit: 65535},message:"must be <= 65535"};
if(vErrors === null){
vErrors = [err8];
}
else {
vErrors.push(err8);
}
errors++;
}
else {
if(data14 < 0 || isNaN(data14)){
const err9 = {instancePath:instancePath+"/observation/capabilities/resources",schemaPath:"#/properties/observation/properties/capabilities/anyOf/0/properties/resources/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
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
}
var valid6 = _errs40 === errors;
}
else {
var valid6 = true;
}
if(valid6){
if(data13.keys_per_resource !== undefined){
let data15 = data13.keys_per_resource;
const _errs42 = errors;
if(!(((typeof data15 == "number") && (!(data15 % 1) && !isNaN(data15))) && (isFinite(data15)))){
const err10 = {instancePath:instancePath+"/observation/capabilities/keys_per_resource",schemaPath:"#/properties/observation/properties/capabilities/anyOf/0/properties/keys_per_resource/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err10];
}
else {
vErrors.push(err10);
}
errors++;
}
if(errors === _errs42){
if((typeof data15 == "number") && (isFinite(data15))){
if(data15 > 65535 || isNaN(data15)){
const err11 = {instancePath:instancePath+"/observation/capabilities/keys_per_resource",schemaPath:"#/properties/observation/properties/capabilities/anyOf/0/properties/keys_per_resource/maximum",keyword:"maximum",params:{comparison: "<=", limit: 65535},message:"must be <= 65535"};
if(vErrors === null){
vErrors = [err11];
}
else {
vErrors.push(err11);
}
errors++;
}
else {
if(data15 < 0 || isNaN(data15)){
const err12 = {instancePath:instancePath+"/observation/capabilities/keys_per_resource",schemaPath:"#/properties/observation/properties/capabilities/anyOf/0/properties/keys_per_resource/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
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
}
var valid6 = _errs42 === errors;
}
else {
var valid6 = true;
}
if(valid6){
if(data13.associations !== undefined){
let data16 = data13.associations;
const _errs44 = errors;
if(!(((typeof data16 == "number") && (!(data16 % 1) && !isNaN(data16))) && (isFinite(data16)))){
const err13 = {instancePath:instancePath+"/observation/capabilities/associations",schemaPath:"#/properties/observation/properties/capabilities/anyOf/0/properties/associations/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err13];
}
else {
vErrors.push(err13);
}
errors++;
}
if(errors === _errs44){
if((typeof data16 == "number") && (isFinite(data16))){
if(data16 > 65535 || isNaN(data16)){
const err14 = {instancePath:instancePath+"/observation/capabilities/associations",schemaPath:"#/properties/observation/properties/capabilities/anyOf/0/properties/associations/maximum",keyword:"maximum",params:{comparison: "<=", limit: 65535},message:"must be <= 65535"};
if(vErrors === null){
vErrors = [err14];
}
else {
vErrors.push(err14);
}
errors++;
}
else {
if(data16 < 0 || isNaN(data16)){
const err15 = {instancePath:instancePath+"/observation/capabilities/associations",schemaPath:"#/properties/observation/properties/capabilities/anyOf/0/properties/associations/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err15];
}
else {
vErrors.push(err15);
}
errors++;
}
}
}
}
var valid6 = _errs44 === errors;
}
else {
var valid6 = true;
}
if(valid6){
if(data13.active_views !== undefined){
let data17 = data13.active_views;
const _errs46 = errors;
if(!(((typeof data17 == "number") && (!(data17 % 1) && !isNaN(data17))) && (isFinite(data17)))){
const err16 = {instancePath:instancePath+"/observation/capabilities/active_views",schemaPath:"#/properties/observation/properties/capabilities/anyOf/0/properties/active_views/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err16];
}
else {
vErrors.push(err16);
}
errors++;
}
if(errors === _errs46){
if((typeof data17 == "number") && (isFinite(data17))){
if(data17 > 65535 || isNaN(data17)){
const err17 = {instancePath:instancePath+"/observation/capabilities/active_views",schemaPath:"#/properties/observation/properties/capabilities/anyOf/0/properties/active_views/maximum",keyword:"maximum",params:{comparison: "<=", limit: 65535},message:"must be <= 65535"};
if(vErrors === null){
vErrors = [err17];
}
else {
vErrors.push(err17);
}
errors++;
}
else {
if(data17 < 0 || isNaN(data17)){
const err18 = {instancePath:instancePath+"/observation/capabilities/active_views",schemaPath:"#/properties/observation/properties/capabilities/anyOf/0/properties/active_views/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err18];
}
else {
vErrors.push(err18);
}
errors++;
}
}
}
}
var valid6 = _errs46 === errors;
}
else {
var valid6 = true;
}
if(valid6){
if(data13.mutations_per_turn !== undefined){
let data18 = data13.mutations_per_turn;
const _errs48 = errors;
if(!(((typeof data18 == "number") && (!(data18 % 1) && !isNaN(data18))) && (isFinite(data18)))){
const err19 = {instancePath:instancePath+"/observation/capabilities/mutations_per_turn",schemaPath:"#/properties/observation/properties/capabilities/anyOf/0/properties/mutations_per_turn/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err19];
}
else {
vErrors.push(err19);
}
errors++;
}
if(errors === _errs48){
if((typeof data18 == "number") && (isFinite(data18))){
if(data18 > 65535 || isNaN(data18)){
const err20 = {instancePath:instancePath+"/observation/capabilities/mutations_per_turn",schemaPath:"#/properties/observation/properties/capabilities/anyOf/0/properties/mutations_per_turn/maximum",keyword:"maximum",params:{comparison: "<=", limit: 65535},message:"must be <= 65535"};
if(vErrors === null){
vErrors = [err20];
}
else {
vErrors.push(err20);
}
errors++;
}
else {
if(data18 < 0 || isNaN(data18)){
const err21 = {instancePath:instancePath+"/observation/capabilities/mutations_per_turn",schemaPath:"#/properties/observation/properties/capabilities/anyOf/0/properties/mutations_per_turn/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err21];
}
else {
vErrors.push(err21);
}
errors++;
}
}
}
}
var valid6 = _errs48 === errors;
}
else {
var valid6 = true;
}
if(valid6){
if(data13.key_bytes !== undefined){
let data19 = data13.key_bytes;
const _errs50 = errors;
if(!(((typeof data19 == "number") && (!(data19 % 1) && !isNaN(data19))) && (isFinite(data19)))){
const err22 = {instancePath:instancePath+"/observation/capabilities/key_bytes",schemaPath:"#/properties/observation/properties/capabilities/anyOf/0/properties/key_bytes/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err22];
}
else {
vErrors.push(err22);
}
errors++;
}
if(errors === _errs50){
if((typeof data19 == "number") && (isFinite(data19))){
if(data19 > 65535 || isNaN(data19)){
const err23 = {instancePath:instancePath+"/observation/capabilities/key_bytes",schemaPath:"#/properties/observation/properties/capabilities/anyOf/0/properties/key_bytes/maximum",keyword:"maximum",params:{comparison: "<=", limit: 65535},message:"must be <= 65535"};
if(vErrors === null){
vErrors = [err23];
}
else {
vErrors.push(err23);
}
errors++;
}
else {
if(data19 < 0 || isNaN(data19)){
const err24 = {instancePath:instancePath+"/observation/capabilities/key_bytes",schemaPath:"#/properties/observation/properties/capabilities/anyOf/0/properties/key_bytes/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err24];
}
else {
vErrors.push(err24);
}
errors++;
}
}
}
}
var valid6 = _errs50 === errors;
}
else {
var valid6 = true;
}
if(valid6){
if(data13.value_bytes !== undefined){
let data20 = data13.value_bytes;
const _errs52 = errors;
if(!(((typeof data20 == "number") && (!(data20 % 1) && !isNaN(data20))) && (isFinite(data20)))){
const err25 = {instancePath:instancePath+"/observation/capabilities/value_bytes",schemaPath:"#/properties/observation/properties/capabilities/anyOf/0/properties/value_bytes/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err25];
}
else {
vErrors.push(err25);
}
errors++;
}
if(errors === _errs52){
if((typeof data20 == "number") && (isFinite(data20))){
if(data20 > 65535 || isNaN(data20)){
const err26 = {instancePath:instancePath+"/observation/capabilities/value_bytes",schemaPath:"#/properties/observation/properties/capabilities/anyOf/0/properties/value_bytes/maximum",keyword:"maximum",params:{comparison: "<=", limit: 65535},message:"must be <= 65535"};
if(vErrors === null){
vErrors = [err26];
}
else {
vErrors.push(err26);
}
errors++;
}
else {
if(data20 < 0 || isNaN(data20)){
const err27 = {instancePath:instancePath+"/observation/capabilities/value_bytes",schemaPath:"#/properties/observation/properties/capabilities/anyOf/0/properties/value_bytes/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err27];
}
else {
vErrors.push(err27);
}
errors++;
}
}
}
}
var valid6 = _errs52 === errors;
}
else {
var valid6 = true;
}
if(valid6){
if(data13.page_entries !== undefined){
let data21 = data13.page_entries;
const _errs54 = errors;
if(!(((typeof data21 == "number") && (!(data21 % 1) && !isNaN(data21))) && (isFinite(data21)))){
const err28 = {instancePath:instancePath+"/observation/capabilities/page_entries",schemaPath:"#/properties/observation/properties/capabilities/anyOf/0/properties/page_entries/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err28];
}
else {
vErrors.push(err28);
}
errors++;
}
if(errors === _errs54){
if((typeof data21 == "number") && (isFinite(data21))){
if(data21 > 65535 || isNaN(data21)){
const err29 = {instancePath:instancePath+"/observation/capabilities/page_entries",schemaPath:"#/properties/observation/properties/capabilities/anyOf/0/properties/page_entries/maximum",keyword:"maximum",params:{comparison: "<=", limit: 65535},message:"must be <= 65535"};
if(vErrors === null){
vErrors = [err29];
}
else {
vErrors.push(err29);
}
errors++;
}
else {
if(data21 < 0 || isNaN(data21)){
const err30 = {instancePath:instancePath+"/observation/capabilities/page_entries",schemaPath:"#/properties/observation/properties/capabilities/anyOf/0/properties/page_entries/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
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
var valid6 = _errs54 === errors;
}
else {
var valid6 = true;
}
if(valid6){
if(data13.view_ms !== undefined){
let data22 = data13.view_ms;
const _errs56 = errors;
if(!(((typeof data22 == "number") && (!(data22 % 1) && !isNaN(data22))) && (isFinite(data22)))){
const err31 = {instancePath:instancePath+"/observation/capabilities/view_ms",schemaPath:"#/properties/observation/properties/capabilities/anyOf/0/properties/view_ms/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err31];
}
else {
vErrors.push(err31);
}
errors++;
}
if(errors === _errs56){
if((typeof data22 == "number") && (isFinite(data22))){
if(data22 > 4294967295 || isNaN(data22)){
const err32 = {instancePath:instancePath+"/observation/capabilities/view_ms",schemaPath:"#/properties/observation/properties/capabilities/anyOf/0/properties/view_ms/maximum",keyword:"maximum",params:{comparison: "<=", limit: 4294967295},message:"must be <= 4294967295"};
if(vErrors === null){
vErrors = [err32];
}
else {
vErrors.push(err32);
}
errors++;
}
else {
if(data22 < 0 || isNaN(data22)){
const err33 = {instancePath:instancePath+"/observation/capabilities/view_ms",schemaPath:"#/properties/observation/properties/capabilities/anyOf/0/properties/view_ms/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err33];
}
else {
vErrors.push(err33);
}
errors++;
}
}
}
}
var valid6 = _errs56 === errors;
}
else {
var valid6 = true;
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
const err34 = {instancePath:instancePath+"/observation/capabilities",schemaPath:"#/properties/observation/properties/capabilities/anyOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err34];
}
else {
vErrors.push(err34);
}
errors++;
}
}
var _valid1 = _errs37 === errors;
valid5 = valid5 || _valid1;
const _errs58 = errors;
if(data13 !== null){
const err35 = {instancePath:instancePath+"/observation/capabilities",schemaPath:"#/properties/observation/properties/capabilities/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err35];
}
else {
vErrors.push(err35);
}
errors++;
}
var _valid1 = _errs58 === errors;
valid5 = valid5 || _valid1;
if(!valid5){
const err36 = {instancePath:instancePath+"/observation/capabilities",schemaPath:"#/properties/observation/properties/capabilities/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err36];
}
else {
vErrors.push(err36);
}
errors++;
validate21.errors = vErrors;
return false;
}
else {
errors = _errs36;
if(vErrors !== null){
if(_errs36){
vErrors.length = _errs36;
}
else {
vErrors = null;
}
}
}
var valid1 = _errs35 === errors;
}
else {
var valid1 = true;
}
if(valid1){
if(data0.next !== undefined){
let data23 = data0.next;
const _errs60 = errors;
const _errs61 = errors;
let valid7 = false;
const _errs62 = errors;
if(!(((typeof data23 == "number") && (!(data23 % 1) && !isNaN(data23))) && (isFinite(data23)))){
const err37 = {instancePath:instancePath+"/observation/next",schemaPath:"#/properties/observation/properties/next/anyOf/0/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err37];
}
else {
vErrors.push(err37);
}
errors++;
}
if(errors === _errs62){
if((typeof data23 == "number") && (isFinite(data23))){
if(data23 > 65535 || isNaN(data23)){
const err38 = {instancePath:instancePath+"/observation/next",schemaPath:"#/properties/observation/properties/next/anyOf/0/maximum",keyword:"maximum",params:{comparison: "<=", limit: 65535},message:"must be <= 65535"};
if(vErrors === null){
vErrors = [err38];
}
else {
vErrors.push(err38);
}
errors++;
}
else {
if(data23 < 0 || isNaN(data23)){
const err39 = {instancePath:instancePath+"/observation/next",schemaPath:"#/properties/observation/properties/next/anyOf/0/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
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
var _valid2 = _errs62 === errors;
valid7 = valid7 || _valid2;
const _errs64 = errors;
if(data23 !== null){
const err40 = {instancePath:instancePath+"/observation/next",schemaPath:"#/properties/observation/properties/next/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err40];
}
else {
vErrors.push(err40);
}
errors++;
}
var _valid2 = _errs64 === errors;
valid7 = valid7 || _valid2;
if(!valid7){
const err41 = {instancePath:instancePath+"/observation/next",schemaPath:"#/properties/observation/properties/next/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err41];
}
else {
vErrors.push(err41);
}
errors++;
validate21.errors = vErrors;
return false;
}
else {
errors = _errs61;
if(vErrors !== null){
if(_errs61){
vErrors.length = _errs61;
}
else {
vErrors = null;
}
}
}
var valid1 = _errs60 === errors;
}
else {
var valid1 = true;
}
if(valid1){
if(data0.resources !== undefined){
let data24 = data0.resources;
const _errs66 = errors;
if(errors === _errs66){
if(Array.isArray(data24)){
if(data24.length > 8){
validate21.errors = [{instancePath:instancePath+"/observation/resources",schemaPath:"#/properties/observation/properties/resources/maxItems",keyword:"maxItems",params:{limit: 8},message:"must NOT have more than 8 items"}];
return false;
}
else {
if(data24.length < 8){
validate21.errors = [{instancePath:instancePath+"/observation/resources",schemaPath:"#/properties/observation/properties/resources/minItems",keyword:"minItems",params:{limit: 8},message:"must NOT have fewer than 8 items"}];
return false;
}
else {
var valid8 = true;
const len0 = data24.length;
for(let i0=0; i0<len0; i0++){
let data25 = data24[i0];
const _errs68 = errors;
const _errs69 = errors;
let valid9 = false;
const _errs70 = errors;
if(errors === _errs70){
if(data25 && typeof data25 == "object" && !Array.isArray(data25)){
let missing5;
if(((((((((((data25.id === undefined) && (missing5 = "id")) || ((data25.writer === undefined) && (missing5 = "writer"))) || ((data25.owner === undefined) && (missing5 = "owner"))) || ((data25.revision === undefined) && (missing5 = "revision"))) || ((data25.deadline_ms === undefined) && (missing5 = "deadline_ms"))) || ((data25.history_ms === undefined) && (missing5 = "history_ms"))) || ((data25.changed_ms === undefined) && (missing5 = "changed_ms"))) || ((data25.phase === undefined) && (missing5 = "phase"))) || ((data25.retired_at === undefined) && (missing5 = "retired_at"))) || ((data25.last_turn === undefined) && (missing5 = "last_turn"))){
const err42 = {instancePath:instancePath+"/observation/resources/" + i0,schemaPath:"#/properties/observation/properties/resources/items/anyOf/0/required",keyword:"required",params:{missingProperty: missing5},message:"must have required property '"+missing5+"'"};
if(vErrors === null){
vErrors = [err42];
}
else {
vErrors.push(err42);
}
errors++;
}
else {
const _errs72 = errors;
for(const key5 in data25){
if(!(func1.call(schema32.properties.observation.properties.resources.items.anyOf[0].properties, key5))){
const err43 = {instancePath:instancePath+"/observation/resources/" + i0,schemaPath:"#/properties/observation/properties/resources/items/anyOf/0/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key5},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err43];
}
else {
vErrors.push(err43);
}
errors++;
break;
}
}
if(_errs72 === errors){
if(data25.id !== undefined){
let data26 = data25.id;
const _errs73 = errors;
if(!(((typeof data26 == "number") && (!(data26 % 1) && !isNaN(data26))) && (isFinite(data26)))){
const err44 = {instancePath:instancePath+"/observation/resources/" + i0+"/id",schemaPath:"#/properties/observation/properties/resources/items/anyOf/0/properties/id/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err44];
}
else {
vErrors.push(err44);
}
errors++;
}
if(errors === _errs73){
if((typeof data26 == "number") && (isFinite(data26))){
if(data26 > 9007199254740991 || isNaN(data26)){
const err45 = {instancePath:instancePath+"/observation/resources/" + i0+"/id",schemaPath:"#/properties/observation/properties/resources/items/anyOf/0/properties/id/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"};
if(vErrors === null){
vErrors = [err45];
}
else {
vErrors.push(err45);
}
errors++;
}
else {
if(data26 < 0 || isNaN(data26)){
const err46 = {instancePath:instancePath+"/observation/resources/" + i0+"/id",schemaPath:"#/properties/observation/properties/resources/items/anyOf/0/properties/id/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err46];
}
else {
vErrors.push(err46);
}
errors++;
}
}
}
}
var valid10 = _errs73 === errors;
}
else {
var valid10 = true;
}
if(valid10){
if(data25.writer !== undefined){
let data27 = data25.writer;
const _errs75 = errors;
if(!(((typeof data27 == "number") && (!(data27 % 1) && !isNaN(data27))) && (isFinite(data27)))){
const err47 = {instancePath:instancePath+"/observation/resources/" + i0+"/writer",schemaPath:"#/properties/observation/properties/resources/items/anyOf/0/properties/writer/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err47];
}
else {
vErrors.push(err47);
}
errors++;
}
if(errors === _errs75){
if((typeof data27 == "number") && (isFinite(data27))){
if(data27 > 9007199254740991 || isNaN(data27)){
const err48 = {instancePath:instancePath+"/observation/resources/" + i0+"/writer",schemaPath:"#/properties/observation/properties/resources/items/anyOf/0/properties/writer/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"};
if(vErrors === null){
vErrors = [err48];
}
else {
vErrors.push(err48);
}
errors++;
}
else {
if(data27 < 0 || isNaN(data27)){
const err49 = {instancePath:instancePath+"/observation/resources/" + i0+"/writer",schemaPath:"#/properties/observation/properties/resources/items/anyOf/0/properties/writer/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err49];
}
else {
vErrors.push(err49);
}
errors++;
}
}
}
}
var valid10 = _errs75 === errors;
}
else {
var valid10 = true;
}
if(valid10){
if(data25.owner !== undefined){
let data28 = data25.owner;
const _errs77 = errors;
const _errs78 = errors;
let valid11 = false;
const _errs79 = errors;
if(!(((typeof data28 == "number") && (!(data28 % 1) && !isNaN(data28))) && (isFinite(data28)))){
const err50 = {instancePath:instancePath+"/observation/resources/" + i0+"/owner",schemaPath:"#/properties/observation/properties/resources/items/anyOf/0/properties/owner/anyOf/0/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err50];
}
else {
vErrors.push(err50);
}
errors++;
}
if(errors === _errs79){
if((typeof data28 == "number") && (isFinite(data28))){
if(data28 > 9007199254740991 || isNaN(data28)){
const err51 = {instancePath:instancePath+"/observation/resources/" + i0+"/owner",schemaPath:"#/properties/observation/properties/resources/items/anyOf/0/properties/owner/anyOf/0/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"};
if(vErrors === null){
vErrors = [err51];
}
else {
vErrors.push(err51);
}
errors++;
}
else {
if(data28 < 0 || isNaN(data28)){
const err52 = {instancePath:instancePath+"/observation/resources/" + i0+"/owner",schemaPath:"#/properties/observation/properties/resources/items/anyOf/0/properties/owner/anyOf/0/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err52];
}
else {
vErrors.push(err52);
}
errors++;
}
}
}
}
var _valid4 = _errs79 === errors;
valid11 = valid11 || _valid4;
const _errs81 = errors;
if(data28 !== null){
const err53 = {instancePath:instancePath+"/observation/resources/" + i0+"/owner",schemaPath:"#/properties/observation/properties/resources/items/anyOf/0/properties/owner/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err53];
}
else {
vErrors.push(err53);
}
errors++;
}
var _valid4 = _errs81 === errors;
valid11 = valid11 || _valid4;
if(!valid11){
const err54 = {instancePath:instancePath+"/observation/resources/" + i0+"/owner",schemaPath:"#/properties/observation/properties/resources/items/anyOf/0/properties/owner/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err54];
}
else {
vErrors.push(err54);
}
errors++;
}
else {
errors = _errs78;
if(vErrors !== null){
if(_errs78){
vErrors.length = _errs78;
}
else {
vErrors = null;
}
}
}
var valid10 = _errs77 === errors;
}
else {
var valid10 = true;
}
if(valid10){
if(data25.revision !== undefined){
let data29 = data25.revision;
const _errs83 = errors;
if(!(((typeof data29 == "number") && (!(data29 % 1) && !isNaN(data29))) && (isFinite(data29)))){
const err55 = {instancePath:instancePath+"/observation/resources/" + i0+"/revision",schemaPath:"#/properties/observation/properties/resources/items/anyOf/0/properties/revision/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err55];
}
else {
vErrors.push(err55);
}
errors++;
}
if(errors === _errs83){
if((typeof data29 == "number") && (isFinite(data29))){
if(data29 > 9007199254740991 || isNaN(data29)){
const err56 = {instancePath:instancePath+"/observation/resources/" + i0+"/revision",schemaPath:"#/properties/observation/properties/resources/items/anyOf/0/properties/revision/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"};
if(vErrors === null){
vErrors = [err56];
}
else {
vErrors.push(err56);
}
errors++;
}
else {
if(data29 < 0 || isNaN(data29)){
const err57 = {instancePath:instancePath+"/observation/resources/" + i0+"/revision",schemaPath:"#/properties/observation/properties/resources/items/anyOf/0/properties/revision/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err57];
}
else {
vErrors.push(err57);
}
errors++;
}
}
}
}
var valid10 = _errs83 === errors;
}
else {
var valid10 = true;
}
if(valid10){
if(data25.deadline_ms !== undefined){
let data30 = data25.deadline_ms;
const _errs85 = errors;
const _errs86 = errors;
let valid12 = false;
const _errs87 = errors;
if(!(((typeof data30 == "number") && (!(data30 % 1) && !isNaN(data30))) && (isFinite(data30)))){
const err58 = {instancePath:instancePath+"/observation/resources/" + i0+"/deadline_ms",schemaPath:"#/properties/observation/properties/resources/items/anyOf/0/properties/deadline_ms/anyOf/0/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err58];
}
else {
vErrors.push(err58);
}
errors++;
}
if(errors === _errs87){
if((typeof data30 == "number") && (isFinite(data30))){
if(data30 > 9007199254740991 || isNaN(data30)){
const err59 = {instancePath:instancePath+"/observation/resources/" + i0+"/deadline_ms",schemaPath:"#/properties/observation/properties/resources/items/anyOf/0/properties/deadline_ms/anyOf/0/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"};
if(vErrors === null){
vErrors = [err59];
}
else {
vErrors.push(err59);
}
errors++;
}
else {
if(data30 < 0 || isNaN(data30)){
const err60 = {instancePath:instancePath+"/observation/resources/" + i0+"/deadline_ms",schemaPath:"#/properties/observation/properties/resources/items/anyOf/0/properties/deadline_ms/anyOf/0/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err60];
}
else {
vErrors.push(err60);
}
errors++;
}
}
}
}
var _valid5 = _errs87 === errors;
valid12 = valid12 || _valid5;
const _errs89 = errors;
if(data30 !== null){
const err61 = {instancePath:instancePath+"/observation/resources/" + i0+"/deadline_ms",schemaPath:"#/properties/observation/properties/resources/items/anyOf/0/properties/deadline_ms/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err61];
}
else {
vErrors.push(err61);
}
errors++;
}
var _valid5 = _errs89 === errors;
valid12 = valid12 || _valid5;
if(!valid12){
const err62 = {instancePath:instancePath+"/observation/resources/" + i0+"/deadline_ms",schemaPath:"#/properties/observation/properties/resources/items/anyOf/0/properties/deadline_ms/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err62];
}
else {
vErrors.push(err62);
}
errors++;
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
var valid10 = _errs85 === errors;
}
else {
var valid10 = true;
}
if(valid10){
if(data25.history_ms !== undefined){
let data31 = data25.history_ms;
const _errs91 = errors;
const _errs92 = errors;
let valid13 = false;
const _errs93 = errors;
if(!(((typeof data31 == "number") && (!(data31 % 1) && !isNaN(data31))) && (isFinite(data31)))){
const err63 = {instancePath:instancePath+"/observation/resources/" + i0+"/history_ms",schemaPath:"#/properties/observation/properties/resources/items/anyOf/0/properties/history_ms/anyOf/0/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err63];
}
else {
vErrors.push(err63);
}
errors++;
}
if(errors === _errs93){
if((typeof data31 == "number") && (isFinite(data31))){
if(data31 > 4294967295 || isNaN(data31)){
const err64 = {instancePath:instancePath+"/observation/resources/" + i0+"/history_ms",schemaPath:"#/properties/observation/properties/resources/items/anyOf/0/properties/history_ms/anyOf/0/maximum",keyword:"maximum",params:{comparison: "<=", limit: 4294967295},message:"must be <= 4294967295"};
if(vErrors === null){
vErrors = [err64];
}
else {
vErrors.push(err64);
}
errors++;
}
else {
if(data31 < 0 || isNaN(data31)){
const err65 = {instancePath:instancePath+"/observation/resources/" + i0+"/history_ms",schemaPath:"#/properties/observation/properties/resources/items/anyOf/0/properties/history_ms/anyOf/0/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err65];
}
else {
vErrors.push(err65);
}
errors++;
}
}
}
}
var _valid6 = _errs93 === errors;
valid13 = valid13 || _valid6;
const _errs95 = errors;
if(data31 !== null){
const err66 = {instancePath:instancePath+"/observation/resources/" + i0+"/history_ms",schemaPath:"#/properties/observation/properties/resources/items/anyOf/0/properties/history_ms/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err66];
}
else {
vErrors.push(err66);
}
errors++;
}
var _valid6 = _errs95 === errors;
valid13 = valid13 || _valid6;
if(!valid13){
const err67 = {instancePath:instancePath+"/observation/resources/" + i0+"/history_ms",schemaPath:"#/properties/observation/properties/resources/items/anyOf/0/properties/history_ms/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err67];
}
else {
vErrors.push(err67);
}
errors++;
}
else {
errors = _errs92;
if(vErrors !== null){
if(_errs92){
vErrors.length = _errs92;
}
else {
vErrors = null;
}
}
}
var valid10 = _errs91 === errors;
}
else {
var valid10 = true;
}
if(valid10){
if(data25.changed_ms !== undefined){
let data32 = data25.changed_ms;
const _errs97 = errors;
if(!(((typeof data32 == "number") && (!(data32 % 1) && !isNaN(data32))) && (isFinite(data32)))){
const err68 = {instancePath:instancePath+"/observation/resources/" + i0+"/changed_ms",schemaPath:"#/properties/observation/properties/resources/items/anyOf/0/properties/changed_ms/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err68];
}
else {
vErrors.push(err68);
}
errors++;
}
if(errors === _errs97){
if((typeof data32 == "number") && (isFinite(data32))){
if(data32 > 9007199254740991 || isNaN(data32)){
const err69 = {instancePath:instancePath+"/observation/resources/" + i0+"/changed_ms",schemaPath:"#/properties/observation/properties/resources/items/anyOf/0/properties/changed_ms/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"};
if(vErrors === null){
vErrors = [err69];
}
else {
vErrors.push(err69);
}
errors++;
}
else {
if(data32 < 0 || isNaN(data32)){
const err70 = {instancePath:instancePath+"/observation/resources/" + i0+"/changed_ms",schemaPath:"#/properties/observation/properties/resources/items/anyOf/0/properties/changed_ms/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err70];
}
else {
vErrors.push(err70);
}
errors++;
}
}
}
}
var valid10 = _errs97 === errors;
}
else {
var valid10 = true;
}
if(valid10){
if(data25.phase !== undefined){
let data33 = data25.phase;
const _errs99 = errors;
if(typeof data33 !== "string"){
const err71 = {instancePath:instancePath+"/observation/resources/" + i0+"/phase",schemaPath:"#/properties/observation/properties/resources/items/anyOf/0/properties/phase/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err71];
}
else {
vErrors.push(err71);
}
errors++;
}
if(!(((data33 === "active") || (data33 === "retired")) || (data33 === "reclaimed"))){
const err72 = {instancePath:instancePath+"/observation/resources/" + i0+"/phase",schemaPath:"#/properties/observation/properties/resources/items/anyOf/0/properties/phase/enum",keyword:"enum",params:{allowedValues: schema32.properties.observation.properties.resources.items.anyOf[0].properties.phase.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err72];
}
else {
vErrors.push(err72);
}
errors++;
}
var valid10 = _errs99 === errors;
}
else {
var valid10 = true;
}
if(valid10){
if(data25.retired_at !== undefined){
let data34 = data25.retired_at;
const _errs101 = errors;
const _errs102 = errors;
let valid14 = false;
const _errs103 = errors;
if(!(((typeof data34 == "number") && (!(data34 % 1) && !isNaN(data34))) && (isFinite(data34)))){
const err73 = {instancePath:instancePath+"/observation/resources/" + i0+"/retired_at",schemaPath:"#/properties/observation/properties/resources/items/anyOf/0/properties/retired_at/anyOf/0/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err73];
}
else {
vErrors.push(err73);
}
errors++;
}
if(errors === _errs103){
if((typeof data34 == "number") && (isFinite(data34))){
if(data34 > 9007199254740991 || isNaN(data34)){
const err74 = {instancePath:instancePath+"/observation/resources/" + i0+"/retired_at",schemaPath:"#/properties/observation/properties/resources/items/anyOf/0/properties/retired_at/anyOf/0/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"};
if(vErrors === null){
vErrors = [err74];
}
else {
vErrors.push(err74);
}
errors++;
}
else {
if(data34 < 0 || isNaN(data34)){
const err75 = {instancePath:instancePath+"/observation/resources/" + i0+"/retired_at",schemaPath:"#/properties/observation/properties/resources/items/anyOf/0/properties/retired_at/anyOf/0/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
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
var _valid7 = _errs103 === errors;
valid14 = valid14 || _valid7;
const _errs105 = errors;
if(data34 !== null){
const err76 = {instancePath:instancePath+"/observation/resources/" + i0+"/retired_at",schemaPath:"#/properties/observation/properties/resources/items/anyOf/0/properties/retired_at/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err76];
}
else {
vErrors.push(err76);
}
errors++;
}
var _valid7 = _errs105 === errors;
valid14 = valid14 || _valid7;
if(!valid14){
const err77 = {instancePath:instancePath+"/observation/resources/" + i0+"/retired_at",schemaPath:"#/properties/observation/properties/resources/items/anyOf/0/properties/retired_at/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err77];
}
else {
vErrors.push(err77);
}
errors++;
}
else {
errors = _errs102;
if(vErrors !== null){
if(_errs102){
vErrors.length = _errs102;
}
else {
vErrors = null;
}
}
}
var valid10 = _errs101 === errors;
}
else {
var valid10 = true;
}
if(valid10){
if(data25.last_turn !== undefined){
let data35 = data25.last_turn;
const _errs107 = errors;
const _errs108 = errors;
let valid15 = false;
const _errs109 = errors;
if(!(((typeof data35 == "number") && (!(data35 % 1) && !isNaN(data35))) && (isFinite(data35)))){
const err78 = {instancePath:instancePath+"/observation/resources/" + i0+"/last_turn",schemaPath:"#/properties/observation/properties/resources/items/anyOf/0/properties/last_turn/anyOf/0/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err78];
}
else {
vErrors.push(err78);
}
errors++;
}
if(errors === _errs109){
if((typeof data35 == "number") && (isFinite(data35))){
if(data35 > 9007199254740991 || isNaN(data35)){
const err79 = {instancePath:instancePath+"/observation/resources/" + i0+"/last_turn",schemaPath:"#/properties/observation/properties/resources/items/anyOf/0/properties/last_turn/anyOf/0/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"};
if(vErrors === null){
vErrors = [err79];
}
else {
vErrors.push(err79);
}
errors++;
}
else {
if(data35 < 0 || isNaN(data35)){
const err80 = {instancePath:instancePath+"/observation/resources/" + i0+"/last_turn",schemaPath:"#/properties/observation/properties/resources/items/anyOf/0/properties/last_turn/anyOf/0/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
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
}
var _valid8 = _errs109 === errors;
valid15 = valid15 || _valid8;
const _errs111 = errors;
if(data35 !== null){
const err81 = {instancePath:instancePath+"/observation/resources/" + i0+"/last_turn",schemaPath:"#/properties/observation/properties/resources/items/anyOf/0/properties/last_turn/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err81];
}
else {
vErrors.push(err81);
}
errors++;
}
var _valid8 = _errs111 === errors;
valid15 = valid15 || _valid8;
if(!valid15){
const err82 = {instancePath:instancePath+"/observation/resources/" + i0+"/last_turn",schemaPath:"#/properties/observation/properties/resources/items/anyOf/0/properties/last_turn/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err82];
}
else {
vErrors.push(err82);
}
errors++;
}
else {
errors = _errs108;
if(vErrors !== null){
if(_errs108){
vErrors.length = _errs108;
}
else {
vErrors = null;
}
}
}
var valid10 = _errs107 === errors;
}
else {
var valid10 = true;
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
const err83 = {instancePath:instancePath+"/observation/resources/" + i0,schemaPath:"#/properties/observation/properties/resources/items/anyOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err83];
}
else {
vErrors.push(err83);
}
errors++;
}
}
var _valid3 = _errs70 === errors;
valid9 = valid9 || _valid3;
const _errs113 = errors;
if(data25 !== null){
const err84 = {instancePath:instancePath+"/observation/resources/" + i0,schemaPath:"#/properties/observation/properties/resources/items/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err84];
}
else {
vErrors.push(err84);
}
errors++;
}
var _valid3 = _errs113 === errors;
valid9 = valid9 || _valid3;
if(!valid9){
const err85 = {instancePath:instancePath+"/observation/resources/" + i0,schemaPath:"#/properties/observation/properties/resources/items/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err85];
}
else {
vErrors.push(err85);
}
errors++;
validate21.errors = vErrors;
return false;
}
else {
errors = _errs69;
if(vErrors !== null){
if(_errs69){
vErrors.length = _errs69;
}
else {
vErrors = null;
}
}
}
var valid8 = _errs68 === errors;
if(!valid8){
break;
}
}
}
}
}
else {
validate21.errors = [{instancePath:instancePath+"/observation/resources",schemaPath:"#/properties/observation/properties/resources/type",keyword:"type",params:{type: "array"},message:"must be array"}];
return false;
}
}
var valid1 = _errs66 === errors;
}
else {
var valid1 = true;
}
if(valid1){
if(data0.associations !== undefined){
let data36 = data0.associations;
const _errs115 = errors;
if(errors === _errs115){
if(Array.isArray(data36)){
if(data36.length > 8){
validate21.errors = [{instancePath:instancePath+"/observation/associations",schemaPath:"#/properties/observation/properties/associations/maxItems",keyword:"maxItems",params:{limit: 8},message:"must NOT have more than 8 items"}];
return false;
}
else {
if(data36.length < 8){
validate21.errors = [{instancePath:instancePath+"/observation/associations",schemaPath:"#/properties/observation/properties/associations/minItems",keyword:"minItems",params:{limit: 8},message:"must NOT have fewer than 8 items"}];
return false;
}
else {
var valid16 = true;
const len1 = data36.length;
for(let i1=0; i1<len1; i1++){
let data37 = data36[i1];
const _errs117 = errors;
const _errs118 = errors;
let valid17 = false;
const _errs119 = errors;
if(errors === _errs119){
if(data37 && typeof data37 == "object" && !Array.isArray(data37)){
let missing6;
if((((((data37.pid === undefined) && (missing6 = "pid")) || ((data37.name === undefined) && (missing6 = "name"))) || ((data37.resource === undefined) && (missing6 = "resource"))) || ((data37.revision === undefined) && (missing6 = "revision"))) || ((data37.required === undefined) && (missing6 = "required"))){
const err86 = {instancePath:instancePath+"/observation/associations/" + i1,schemaPath:"#/properties/observation/properties/associations/items/anyOf/0/required",keyword:"required",params:{missingProperty: missing6},message:"must have required property '"+missing6+"'"};
if(vErrors === null){
vErrors = [err86];
}
else {
vErrors.push(err86);
}
errors++;
}
else {
const _errs121 = errors;
for(const key6 in data37){
if(!(((((key6 === "pid") || (key6 === "name")) || (key6 === "resource")) || (key6 === "revision")) || (key6 === "required"))){
const err87 = {instancePath:instancePath+"/observation/associations/" + i1,schemaPath:"#/properties/observation/properties/associations/items/anyOf/0/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key6},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err87];
}
else {
vErrors.push(err87);
}
errors++;
break;
}
}
if(_errs121 === errors){
if(data37.pid !== undefined){
let data38 = data37.pid;
const _errs122 = errors;
if(!(((typeof data38 == "number") && (!(data38 % 1) && !isNaN(data38))) && (isFinite(data38)))){
const err88 = {instancePath:instancePath+"/observation/associations/" + i1+"/pid",schemaPath:"#/properties/observation/properties/associations/items/anyOf/0/properties/pid/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err88];
}
else {
vErrors.push(err88);
}
errors++;
}
if(errors === _errs122){
if((typeof data38 == "number") && (isFinite(data38))){
if(data38 > 9007199254740991 || isNaN(data38)){
const err89 = {instancePath:instancePath+"/observation/associations/" + i1+"/pid",schemaPath:"#/properties/observation/properties/associations/items/anyOf/0/properties/pid/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"};
if(vErrors === null){
vErrors = [err89];
}
else {
vErrors.push(err89);
}
errors++;
}
else {
if(data38 < 0 || isNaN(data38)){
const err90 = {instancePath:instancePath+"/observation/associations/" + i1+"/pid",schemaPath:"#/properties/observation/properties/associations/items/anyOf/0/properties/pid/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err90];
}
else {
vErrors.push(err90);
}
errors++;
}
}
}
}
var valid18 = _errs122 === errors;
}
else {
var valid18 = true;
}
if(valid18){
if(data37.name !== undefined){
let data39 = data37.name;
const _errs124 = errors;
if(errors === _errs124){
if(typeof data39 === "string"){
if(func3(data39) > 512){
const err91 = {instancePath:instancePath+"/observation/associations/" + i1+"/name",schemaPath:"#/properties/observation/properties/associations/items/anyOf/0/properties/name/maxLength",keyword:"maxLength",params:{limit: 512},message:"must NOT have more than 512 characters"};
if(vErrors === null){
vErrors = [err91];
}
else {
vErrors.push(err91);
}
errors++;
}
else {
if(!pattern4.test(data39)){
const err92 = {instancePath:instancePath+"/observation/associations/" + i1+"/name",schemaPath:"#/properties/observation/properties/associations/items/anyOf/0/properties/name/pattern",keyword:"pattern",params:{pattern: "^(?:[0-9a-f]{2})*$"},message:"must match pattern \""+"^(?:[0-9a-f]{2})*$"+"\""};
if(vErrors === null){
vErrors = [err92];
}
else {
vErrors.push(err92);
}
errors++;
}
}
}
else {
const err93 = {instancePath:instancePath+"/observation/associations/" + i1+"/name",schemaPath:"#/properties/observation/properties/associations/items/anyOf/0/properties/name/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err93];
}
else {
vErrors.push(err93);
}
errors++;
}
}
var valid18 = _errs124 === errors;
}
else {
var valid18 = true;
}
if(valid18){
if(data37.resource !== undefined){
let data40 = data37.resource;
const _errs126 = errors;
if(!(((typeof data40 == "number") && (!(data40 % 1) && !isNaN(data40))) && (isFinite(data40)))){
const err94 = {instancePath:instancePath+"/observation/associations/" + i1+"/resource",schemaPath:"#/properties/observation/properties/associations/items/anyOf/0/properties/resource/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err94];
}
else {
vErrors.push(err94);
}
errors++;
}
if(errors === _errs126){
if((typeof data40 == "number") && (isFinite(data40))){
if(data40 > 9007199254740991 || isNaN(data40)){
const err95 = {instancePath:instancePath+"/observation/associations/" + i1+"/resource",schemaPath:"#/properties/observation/properties/associations/items/anyOf/0/properties/resource/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"};
if(vErrors === null){
vErrors = [err95];
}
else {
vErrors.push(err95);
}
errors++;
}
else {
if(data40 < 0 || isNaN(data40)){
const err96 = {instancePath:instancePath+"/observation/associations/" + i1+"/resource",schemaPath:"#/properties/observation/properties/associations/items/anyOf/0/properties/resource/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err96];
}
else {
vErrors.push(err96);
}
errors++;
}
}
}
}
var valid18 = _errs126 === errors;
}
else {
var valid18 = true;
}
if(valid18){
if(data37.revision !== undefined){
let data41 = data37.revision;
const _errs128 = errors;
if(!(((typeof data41 == "number") && (!(data41 % 1) && !isNaN(data41))) && (isFinite(data41)))){
const err97 = {instancePath:instancePath+"/observation/associations/" + i1+"/revision",schemaPath:"#/properties/observation/properties/associations/items/anyOf/0/properties/revision/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err97];
}
else {
vErrors.push(err97);
}
errors++;
}
if(errors === _errs128){
if((typeof data41 == "number") && (isFinite(data41))){
if(data41 > 9007199254740991 || isNaN(data41)){
const err98 = {instancePath:instancePath+"/observation/associations/" + i1+"/revision",schemaPath:"#/properties/observation/properties/associations/items/anyOf/0/properties/revision/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"};
if(vErrors === null){
vErrors = [err98];
}
else {
vErrors.push(err98);
}
errors++;
}
else {
if(data41 < 0 || isNaN(data41)){
const err99 = {instancePath:instancePath+"/observation/associations/" + i1+"/revision",schemaPath:"#/properties/observation/properties/associations/items/anyOf/0/properties/revision/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err99];
}
else {
vErrors.push(err99);
}
errors++;
}
}
}
}
var valid18 = _errs128 === errors;
}
else {
var valid18 = true;
}
if(valid18){
if(data37.required !== undefined){
const _errs130 = errors;
if(typeof data37.required !== "boolean"){
const err100 = {instancePath:instancePath+"/observation/associations/" + i1+"/required",schemaPath:"#/properties/observation/properties/associations/items/anyOf/0/properties/required/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"};
if(vErrors === null){
vErrors = [err100];
}
else {
vErrors.push(err100);
}
errors++;
}
var valid18 = _errs130 === errors;
}
else {
var valid18 = true;
}
}
}
}
}
}
}
}
else {
const err101 = {instancePath:instancePath+"/observation/associations/" + i1,schemaPath:"#/properties/observation/properties/associations/items/anyOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err101];
}
else {
vErrors.push(err101);
}
errors++;
}
}
var _valid9 = _errs119 === errors;
valid17 = valid17 || _valid9;
const _errs132 = errors;
if(data37 !== null){
const err102 = {instancePath:instancePath+"/observation/associations/" + i1,schemaPath:"#/properties/observation/properties/associations/items/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err102];
}
else {
vErrors.push(err102);
}
errors++;
}
var _valid9 = _errs132 === errors;
valid17 = valid17 || _valid9;
if(!valid17){
const err103 = {instancePath:instancePath+"/observation/associations/" + i1,schemaPath:"#/properties/observation/properties/associations/items/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err103];
}
else {
vErrors.push(err103);
}
errors++;
validate21.errors = vErrors;
return false;
}
else {
errors = _errs118;
if(vErrors !== null){
if(_errs118){
vErrors.length = _errs118;
}
else {
vErrors = null;
}
}
}
var valid16 = _errs117 === errors;
if(!valid16){
break;
}
}
}
}
}
else {
validate21.errors = [{instancePath:instancePath+"/observation/associations",schemaPath:"#/properties/observation/properties/associations/type",keyword:"type",params:{type: "array"},message:"must be array"}];
return false;
}
}
var valid1 = _errs115 === errors;
}
else {
var valid1 = true;
}
if(valid1){
if(data0.entries !== undefined){
let data43 = data0.entries;
const _errs134 = errors;
if(errors === _errs134){
if(Array.isArray(data43)){
if(data43.length > 8){
validate21.errors = [{instancePath:instancePath+"/observation/entries",schemaPath:"#/properties/observation/properties/entries/maxItems",keyword:"maxItems",params:{limit: 8},message:"must NOT have more than 8 items"}];
return false;
}
else {
if(data43.length < 8){
validate21.errors = [{instancePath:instancePath+"/observation/entries",schemaPath:"#/properties/observation/properties/entries/minItems",keyword:"minItems",params:{limit: 8},message:"must NOT have fewer than 8 items"}];
return false;
}
else {
var valid19 = true;
const len2 = data43.length;
for(let i2=0; i2<len2; i2++){
let data44 = data43[i2];
const _errs136 = errors;
const _errs137 = errors;
let valid20 = false;
const _errs138 = errors;
if(errors === _errs138){
if(data44 && typeof data44 == "object" && !Array.isArray(data44)){
let missing7;
if((((data44.key === undefined) && (missing7 = "key")) || ((data44.value === undefined) && (missing7 = "value"))) || ((data44.revision === undefined) && (missing7 = "revision"))){
const err104 = {instancePath:instancePath+"/observation/entries/" + i2,schemaPath:"#/properties/observation/properties/entries/items/anyOf/0/required",keyword:"required",params:{missingProperty: missing7},message:"must have required property '"+missing7+"'"};
if(vErrors === null){
vErrors = [err104];
}
else {
vErrors.push(err104);
}
errors++;
}
else {
const _errs140 = errors;
for(const key7 in data44){
if(!(((key7 === "key") || (key7 === "value")) || (key7 === "revision"))){
const err105 = {instancePath:instancePath+"/observation/entries/" + i2,schemaPath:"#/properties/observation/properties/entries/items/anyOf/0/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key7},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err105];
}
else {
vErrors.push(err105);
}
errors++;
break;
}
}
if(_errs140 === errors){
if(data44.key !== undefined){
let data45 = data44.key;
const _errs141 = errors;
if(errors === _errs141){
if(typeof data45 === "string"){
if(func3(data45) > 512){
const err106 = {instancePath:instancePath+"/observation/entries/" + i2+"/key",schemaPath:"#/properties/observation/properties/entries/items/anyOf/0/properties/key/maxLength",keyword:"maxLength",params:{limit: 512},message:"must NOT have more than 512 characters"};
if(vErrors === null){
vErrors = [err106];
}
else {
vErrors.push(err106);
}
errors++;
}
else {
if(!pattern4.test(data45)){
const err107 = {instancePath:instancePath+"/observation/entries/" + i2+"/key",schemaPath:"#/properties/observation/properties/entries/items/anyOf/0/properties/key/pattern",keyword:"pattern",params:{pattern: "^(?:[0-9a-f]{2})*$"},message:"must match pattern \""+"^(?:[0-9a-f]{2})*$"+"\""};
if(vErrors === null){
vErrors = [err107];
}
else {
vErrors.push(err107);
}
errors++;
}
}
}
else {
const err108 = {instancePath:instancePath+"/observation/entries/" + i2+"/key",schemaPath:"#/properties/observation/properties/entries/items/anyOf/0/properties/key/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err108];
}
else {
vErrors.push(err108);
}
errors++;
}
}
var valid21 = _errs141 === errors;
}
else {
var valid21 = true;
}
if(valid21){
if(data44.value !== undefined){
let data46 = data44.value;
const _errs143 = errors;
if(errors === _errs143){
if(typeof data46 === "string"){
if(func3(data46) > 512){
const err109 = {instancePath:instancePath+"/observation/entries/" + i2+"/value",schemaPath:"#/properties/observation/properties/entries/items/anyOf/0/properties/value/maxLength",keyword:"maxLength",params:{limit: 512},message:"must NOT have more than 512 characters"};
if(vErrors === null){
vErrors = [err109];
}
else {
vErrors.push(err109);
}
errors++;
}
else {
if(!pattern4.test(data46)){
const err110 = {instancePath:instancePath+"/observation/entries/" + i2+"/value",schemaPath:"#/properties/observation/properties/entries/items/anyOf/0/properties/value/pattern",keyword:"pattern",params:{pattern: "^(?:[0-9a-f]{2})*$"},message:"must match pattern \""+"^(?:[0-9a-f]{2})*$"+"\""};
if(vErrors === null){
vErrors = [err110];
}
else {
vErrors.push(err110);
}
errors++;
}
}
}
else {
const err111 = {instancePath:instancePath+"/observation/entries/" + i2+"/value",schemaPath:"#/properties/observation/properties/entries/items/anyOf/0/properties/value/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err111];
}
else {
vErrors.push(err111);
}
errors++;
}
}
var valid21 = _errs143 === errors;
}
else {
var valid21 = true;
}
if(valid21){
if(data44.revision !== undefined){
let data47 = data44.revision;
const _errs145 = errors;
if(!(((typeof data47 == "number") && (!(data47 % 1) && !isNaN(data47))) && (isFinite(data47)))){
const err112 = {instancePath:instancePath+"/observation/entries/" + i2+"/revision",schemaPath:"#/properties/observation/properties/entries/items/anyOf/0/properties/revision/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err112];
}
else {
vErrors.push(err112);
}
errors++;
}
if(errors === _errs145){
if((typeof data47 == "number") && (isFinite(data47))){
if(data47 > 9007199254740991 || isNaN(data47)){
const err113 = {instancePath:instancePath+"/observation/entries/" + i2+"/revision",schemaPath:"#/properties/observation/properties/entries/items/anyOf/0/properties/revision/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"};
if(vErrors === null){
vErrors = [err113];
}
else {
vErrors.push(err113);
}
errors++;
}
else {
if(data47 < 0 || isNaN(data47)){
const err114 = {instancePath:instancePath+"/observation/entries/" + i2+"/revision",schemaPath:"#/properties/observation/properties/entries/items/anyOf/0/properties/revision/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err114];
}
else {
vErrors.push(err114);
}
errors++;
}
}
}
}
var valid21 = _errs145 === errors;
}
else {
var valid21 = true;
}
}
}
}
}
}
else {
const err115 = {instancePath:instancePath+"/observation/entries/" + i2,schemaPath:"#/properties/observation/properties/entries/items/anyOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err115];
}
else {
vErrors.push(err115);
}
errors++;
}
}
var _valid10 = _errs138 === errors;
valid20 = valid20 || _valid10;
const _errs147 = errors;
if(data44 !== null){
const err116 = {instancePath:instancePath+"/observation/entries/" + i2,schemaPath:"#/properties/observation/properties/entries/items/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err116];
}
else {
vErrors.push(err116);
}
errors++;
}
var _valid10 = _errs147 === errors;
valid20 = valid20 || _valid10;
if(!valid20){
const err117 = {instancePath:instancePath+"/observation/entries/" + i2,schemaPath:"#/properties/observation/properties/entries/items/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err117];
}
else {
vErrors.push(err117);
}
errors++;
validate21.errors = vErrors;
return false;
}
else {
errors = _errs137;
if(vErrors !== null){
if(_errs137){
vErrors.length = _errs137;
}
else {
vErrors = null;
}
}
}
var valid19 = _errs136 === errors;
if(!valid19){
break;
}
}
}
}
}
else {
validate21.errors = [{instancePath:instancePath+"/observation/entries",schemaPath:"#/properties/observation/properties/entries/type",keyword:"type",params:{type: "array"},message:"must be array"}];
return false;
}
}
var valid1 = _errs134 === errors;
}
else {
var valid1 = true;
}
if(valid1){
if(data0.view !== undefined){
let data48 = data0.view;
const _errs149 = errors;
const _errs150 = errors;
let valid22 = false;
const _errs151 = errors;
if(errors === _errs151){
if(data48 && typeof data48 == "object" && !Array.isArray(data48)){
let missing8;
if((((((((((data48.id === undefined) && (missing8 = "id")) || ((data48.pid === undefined) && (missing8 = "pid"))) || ((data48.principal === undefined) && (missing8 = "principal"))) || ((data48.generation === undefined) && (missing8 = "generation"))) || ((data48.input === undefined) && (missing8 = "input"))) || ((data48.process_revision === undefined) && (missing8 = "process_revision"))) || ((data48.resource === undefined) && (missing8 = "resource"))) || ((data48.revision === undefined) && (missing8 = "revision"))) || ((data48.deadline_ms === undefined) && (missing8 = "deadline_ms"))){
const err118 = {instancePath:instancePath+"/observation/view",schemaPath:"#/properties/observation/properties/view/anyOf/0/required",keyword:"required",params:{missingProperty: missing8},message:"must have required property '"+missing8+"'"};
if(vErrors === null){
vErrors = [err118];
}
else {
vErrors.push(err118);
}
errors++;
}
else {
const _errs153 = errors;
for(const key8 in data48){
if(!(func1.call(schema32.properties.observation.properties.view.anyOf[0].properties, key8))){
const err119 = {instancePath:instancePath+"/observation/view",schemaPath:"#/properties/observation/properties/view/anyOf/0/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key8},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err119];
}
else {
vErrors.push(err119);
}
errors++;
break;
}
}
if(_errs153 === errors){
if(data48.id !== undefined){
let data49 = data48.id;
const _errs154 = errors;
if(!(((typeof data49 == "number") && (!(data49 % 1) && !isNaN(data49))) && (isFinite(data49)))){
const err120 = {instancePath:instancePath+"/observation/view/id",schemaPath:"#/properties/observation/properties/view/anyOf/0/properties/id/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err120];
}
else {
vErrors.push(err120);
}
errors++;
}
if(errors === _errs154){
if((typeof data49 == "number") && (isFinite(data49))){
if(data49 > 9007199254740991 || isNaN(data49)){
const err121 = {instancePath:instancePath+"/observation/view/id",schemaPath:"#/properties/observation/properties/view/anyOf/0/properties/id/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"};
if(vErrors === null){
vErrors = [err121];
}
else {
vErrors.push(err121);
}
errors++;
}
else {
if(data49 < 0 || isNaN(data49)){
const err122 = {instancePath:instancePath+"/observation/view/id",schemaPath:"#/properties/observation/properties/view/anyOf/0/properties/id/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
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
}
var valid23 = _errs154 === errors;
}
else {
var valid23 = true;
}
if(valid23){
if(data48.pid !== undefined){
let data50 = data48.pid;
const _errs156 = errors;
if(!(((typeof data50 == "number") && (!(data50 % 1) && !isNaN(data50))) && (isFinite(data50)))){
const err123 = {instancePath:instancePath+"/observation/view/pid",schemaPath:"#/properties/observation/properties/view/anyOf/0/properties/pid/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err123];
}
else {
vErrors.push(err123);
}
errors++;
}
if(errors === _errs156){
if((typeof data50 == "number") && (isFinite(data50))){
if(data50 > 9007199254740991 || isNaN(data50)){
const err124 = {instancePath:instancePath+"/observation/view/pid",schemaPath:"#/properties/observation/properties/view/anyOf/0/properties/pid/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"};
if(vErrors === null){
vErrors = [err124];
}
else {
vErrors.push(err124);
}
errors++;
}
else {
if(data50 < 0 || isNaN(data50)){
const err125 = {instancePath:instancePath+"/observation/view/pid",schemaPath:"#/properties/observation/properties/view/anyOf/0/properties/pid/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err125];
}
else {
vErrors.push(err125);
}
errors++;
}
}
}
}
var valid23 = _errs156 === errors;
}
else {
var valid23 = true;
}
if(valid23){
if(data48.principal !== undefined){
let data51 = data48.principal;
const _errs158 = errors;
if(!(((typeof data51 == "number") && (!(data51 % 1) && !isNaN(data51))) && (isFinite(data51)))){
const err126 = {instancePath:instancePath+"/observation/view/principal",schemaPath:"#/properties/observation/properties/view/anyOf/0/properties/principal/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err126];
}
else {
vErrors.push(err126);
}
errors++;
}
if(errors === _errs158){
if((typeof data51 == "number") && (isFinite(data51))){
if(data51 > 255 || isNaN(data51)){
const err127 = {instancePath:instancePath+"/observation/view/principal",schemaPath:"#/properties/observation/properties/view/anyOf/0/properties/principal/maximum",keyword:"maximum",params:{comparison: "<=", limit: 255},message:"must be <= 255"};
if(vErrors === null){
vErrors = [err127];
}
else {
vErrors.push(err127);
}
errors++;
}
else {
if(data51 < 0 || isNaN(data51)){
const err128 = {instancePath:instancePath+"/observation/view/principal",schemaPath:"#/properties/observation/properties/view/anyOf/0/properties/principal/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err128];
}
else {
vErrors.push(err128);
}
errors++;
}
}
}
}
var valid23 = _errs158 === errors;
}
else {
var valid23 = true;
}
if(valid23){
if(data48.generation !== undefined){
let data52 = data48.generation;
const _errs160 = errors;
if(!(((typeof data52 == "number") && (!(data52 % 1) && !isNaN(data52))) && (isFinite(data52)))){
const err129 = {instancePath:instancePath+"/observation/view/generation",schemaPath:"#/properties/observation/properties/view/anyOf/0/properties/generation/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err129];
}
else {
vErrors.push(err129);
}
errors++;
}
if(errors === _errs160){
if((typeof data52 == "number") && (isFinite(data52))){
if(data52 > 9007199254740991 || isNaN(data52)){
const err130 = {instancePath:instancePath+"/observation/view/generation",schemaPath:"#/properties/observation/properties/view/anyOf/0/properties/generation/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"};
if(vErrors === null){
vErrors = [err130];
}
else {
vErrors.push(err130);
}
errors++;
}
else {
if(data52 < 0 || isNaN(data52)){
const err131 = {instancePath:instancePath+"/observation/view/generation",schemaPath:"#/properties/observation/properties/view/anyOf/0/properties/generation/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err131];
}
else {
vErrors.push(err131);
}
errors++;
}
}
}
}
var valid23 = _errs160 === errors;
}
else {
var valid23 = true;
}
if(valid23){
if(data48.input !== undefined){
let data53 = data48.input;
const _errs162 = errors;
if(!(((typeof data53 == "number") && (!(data53 % 1) && !isNaN(data53))) && (isFinite(data53)))){
const err132 = {instancePath:instancePath+"/observation/view/input",schemaPath:"#/properties/observation/properties/view/anyOf/0/properties/input/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err132];
}
else {
vErrors.push(err132);
}
errors++;
}
if(errors === _errs162){
if((typeof data53 == "number") && (isFinite(data53))){
if(data53 > 9007199254740991 || isNaN(data53)){
const err133 = {instancePath:instancePath+"/observation/view/input",schemaPath:"#/properties/observation/properties/view/anyOf/0/properties/input/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"};
if(vErrors === null){
vErrors = [err133];
}
else {
vErrors.push(err133);
}
errors++;
}
else {
if(data53 < 0 || isNaN(data53)){
const err134 = {instancePath:instancePath+"/observation/view/input",schemaPath:"#/properties/observation/properties/view/anyOf/0/properties/input/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err134];
}
else {
vErrors.push(err134);
}
errors++;
}
}
}
}
var valid23 = _errs162 === errors;
}
else {
var valid23 = true;
}
if(valid23){
if(data48.process_revision !== undefined){
let data54 = data48.process_revision;
const _errs164 = errors;
if(!(((typeof data54 == "number") && (!(data54 % 1) && !isNaN(data54))) && (isFinite(data54)))){
const err135 = {instancePath:instancePath+"/observation/view/process_revision",schemaPath:"#/properties/observation/properties/view/anyOf/0/properties/process_revision/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err135];
}
else {
vErrors.push(err135);
}
errors++;
}
if(errors === _errs164){
if((typeof data54 == "number") && (isFinite(data54))){
if(data54 > 9007199254740991 || isNaN(data54)){
const err136 = {instancePath:instancePath+"/observation/view/process_revision",schemaPath:"#/properties/observation/properties/view/anyOf/0/properties/process_revision/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"};
if(vErrors === null){
vErrors = [err136];
}
else {
vErrors.push(err136);
}
errors++;
}
else {
if(data54 < 0 || isNaN(data54)){
const err137 = {instancePath:instancePath+"/observation/view/process_revision",schemaPath:"#/properties/observation/properties/view/anyOf/0/properties/process_revision/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err137];
}
else {
vErrors.push(err137);
}
errors++;
}
}
}
}
var valid23 = _errs164 === errors;
}
else {
var valid23 = true;
}
if(valid23){
if(data48.resource !== undefined){
let data55 = data48.resource;
const _errs166 = errors;
if(!(((typeof data55 == "number") && (!(data55 % 1) && !isNaN(data55))) && (isFinite(data55)))){
const err138 = {instancePath:instancePath+"/observation/view/resource",schemaPath:"#/properties/observation/properties/view/anyOf/0/properties/resource/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err138];
}
else {
vErrors.push(err138);
}
errors++;
}
if(errors === _errs166){
if((typeof data55 == "number") && (isFinite(data55))){
if(data55 > 9007199254740991 || isNaN(data55)){
const err139 = {instancePath:instancePath+"/observation/view/resource",schemaPath:"#/properties/observation/properties/view/anyOf/0/properties/resource/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"};
if(vErrors === null){
vErrors = [err139];
}
else {
vErrors.push(err139);
}
errors++;
}
else {
if(data55 < 0 || isNaN(data55)){
const err140 = {instancePath:instancePath+"/observation/view/resource",schemaPath:"#/properties/observation/properties/view/anyOf/0/properties/resource/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err140];
}
else {
vErrors.push(err140);
}
errors++;
}
}
}
}
var valid23 = _errs166 === errors;
}
else {
var valid23 = true;
}
if(valid23){
if(data48.revision !== undefined){
let data56 = data48.revision;
const _errs168 = errors;
if(!(((typeof data56 == "number") && (!(data56 % 1) && !isNaN(data56))) && (isFinite(data56)))){
const err141 = {instancePath:instancePath+"/observation/view/revision",schemaPath:"#/properties/observation/properties/view/anyOf/0/properties/revision/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err141];
}
else {
vErrors.push(err141);
}
errors++;
}
if(errors === _errs168){
if((typeof data56 == "number") && (isFinite(data56))){
if(data56 > 9007199254740991 || isNaN(data56)){
const err142 = {instancePath:instancePath+"/observation/view/revision",schemaPath:"#/properties/observation/properties/view/anyOf/0/properties/revision/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"};
if(vErrors === null){
vErrors = [err142];
}
else {
vErrors.push(err142);
}
errors++;
}
else {
if(data56 < 0 || isNaN(data56)){
const err143 = {instancePath:instancePath+"/observation/view/revision",schemaPath:"#/properties/observation/properties/view/anyOf/0/properties/revision/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err143];
}
else {
vErrors.push(err143);
}
errors++;
}
}
}
}
var valid23 = _errs168 === errors;
}
else {
var valid23 = true;
}
if(valid23){
if(data48.deadline_ms !== undefined){
let data57 = data48.deadline_ms;
const _errs170 = errors;
if(!(((typeof data57 == "number") && (!(data57 % 1) && !isNaN(data57))) && (isFinite(data57)))){
const err144 = {instancePath:instancePath+"/observation/view/deadline_ms",schemaPath:"#/properties/observation/properties/view/anyOf/0/properties/deadline_ms/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err144];
}
else {
vErrors.push(err144);
}
errors++;
}
if(errors === _errs170){
if((typeof data57 == "number") && (isFinite(data57))){
if(data57 > 9007199254740991 || isNaN(data57)){
const err145 = {instancePath:instancePath+"/observation/view/deadline_ms",schemaPath:"#/properties/observation/properties/view/anyOf/0/properties/deadline_ms/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"};
if(vErrors === null){
vErrors = [err145];
}
else {
vErrors.push(err145);
}
errors++;
}
else {
if(data57 < 0 || isNaN(data57)){
const err146 = {instancePath:instancePath+"/observation/view/deadline_ms",schemaPath:"#/properties/observation/properties/view/anyOf/0/properties/deadline_ms/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err146];
}
else {
vErrors.push(err146);
}
errors++;
}
}
}
}
var valid23 = _errs170 === errors;
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
}
else {
const err147 = {instancePath:instancePath+"/observation/view",schemaPath:"#/properties/observation/properties/view/anyOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err147];
}
else {
vErrors.push(err147);
}
errors++;
}
}
var _valid11 = _errs151 === errors;
valid22 = valid22 || _valid11;
const _errs172 = errors;
if(data48 !== null){
const err148 = {instancePath:instancePath+"/observation/view",schemaPath:"#/properties/observation/properties/view/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err148];
}
else {
vErrors.push(err148);
}
errors++;
}
var _valid11 = _errs172 === errors;
valid22 = valid22 || _valid11;
if(!valid22){
const err149 = {instancePath:instancePath+"/observation/view",schemaPath:"#/properties/observation/properties/view/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err149];
}
else {
vErrors.push(err149);
}
errors++;
validate21.errors = vErrors;
return false;
}
else {
errors = _errs150;
if(vErrors !== null){
if(_errs150){
vErrors.length = _errs150;
}
else {
vErrors = null;
}
}
}
var valid1 = _errs149 === errors;
}
else {
var valid1 = true;
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
validate21.errors = [{instancePath:instancePath+"/observation",schemaPath:"#/properties/observation/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
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

export const Capabilities = validate22;
const schema33 = {"type":"object","additionalProperties":false,"properties":{"version":{"type":"integer","minimum":0,"maximum":4294967295},"realm":{"type":"integer","minimum":0,"maximum":9007199254740991},"scope_pid":{"anyOf":[{"type":"integer","minimum":0,"maximum":9007199254740991},{"type":"null"}]},"read_only":{"type":"boolean"},"shared_principal":{"type":"boolean"},"page_size":{"type":"integer","minimum":0,"maximum":4294967295},"scan_limit":{"type":"integer","minimum":0,"maximum":4294967295},"max_edges":{"type":"integer","minimum":0,"maximum":4294967295},"min_refresh_ms":{"type":"integer","minimum":0,"maximum":4294967295},"max_request_bytes":{"type":"integer","minimum":0,"maximum":4294967295},"state_resources":{"type":"boolean"},"station":{"type":"boolean"},"http_connector":{"type":"boolean"},"push":{"type":"boolean"}},"required":["version","realm","scope_pid","read_only","shared_principal","page_size","scan_limit","max_edges","min_refresh_ms","max_request_bytes","state_resources","station","http_connector","push"]};

function validate22(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate22.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if(((((((((((((((data.version === undefined) && (missing0 = "version")) || ((data.realm === undefined) && (missing0 = "realm"))) || ((data.scope_pid === undefined) && (missing0 = "scope_pid"))) || ((data.read_only === undefined) && (missing0 = "read_only"))) || ((data.shared_principal === undefined) && (missing0 = "shared_principal"))) || ((data.page_size === undefined) && (missing0 = "page_size"))) || ((data.scan_limit === undefined) && (missing0 = "scan_limit"))) || ((data.max_edges === undefined) && (missing0 = "max_edges"))) || ((data.min_refresh_ms === undefined) && (missing0 = "min_refresh_ms"))) || ((data.max_request_bytes === undefined) && (missing0 = "max_request_bytes"))) || ((data.state_resources === undefined) && (missing0 = "state_resources"))) || ((data.station === undefined) && (missing0 = "station"))) || ((data.http_connector === undefined) && (missing0 = "http_connector"))) || ((data.push === undefined) && (missing0 = "push"))){
validate22.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(func1.call(schema33.properties, key0))){
validate22.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.version !== undefined){
let data0 = data.version;
const _errs2 = errors;
if(!(((typeof data0 == "number") && (!(data0 % 1) && !isNaN(data0))) && (isFinite(data0)))){
validate22.errors = [{instancePath:instancePath+"/version",schemaPath:"#/properties/version/type",keyword:"type",params:{type: "integer"},message:"must be integer"}];
return false;
}
if(errors === _errs2){
if((typeof data0 == "number") && (isFinite(data0))){
if(data0 > 4294967295 || isNaN(data0)){
validate22.errors = [{instancePath:instancePath+"/version",schemaPath:"#/properties/version/maximum",keyword:"maximum",params:{comparison: "<=", limit: 4294967295},message:"must be <= 4294967295"}];
return false;
}
else {
if(data0 < 0 || isNaN(data0)){
validate22.errors = [{instancePath:instancePath+"/version",schemaPath:"#/properties/version/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"}];
return false;
}
}
}
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.realm !== undefined){
let data1 = data.realm;
const _errs4 = errors;
if(!(((typeof data1 == "number") && (!(data1 % 1) && !isNaN(data1))) && (isFinite(data1)))){
validate22.errors = [{instancePath:instancePath+"/realm",schemaPath:"#/properties/realm/type",keyword:"type",params:{type: "integer"},message:"must be integer"}];
return false;
}
if(errors === _errs4){
if((typeof data1 == "number") && (isFinite(data1))){
if(data1 > 9007199254740991 || isNaN(data1)){
validate22.errors = [{instancePath:instancePath+"/realm",schemaPath:"#/properties/realm/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"}];
return false;
}
else {
if(data1 < 0 || isNaN(data1)){
validate22.errors = [{instancePath:instancePath+"/realm",schemaPath:"#/properties/realm/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"}];
return false;
}
}
}
}
var valid0 = _errs4 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.scope_pid !== undefined){
let data2 = data.scope_pid;
const _errs6 = errors;
const _errs7 = errors;
let valid1 = false;
const _errs8 = errors;
if(!(((typeof data2 == "number") && (!(data2 % 1) && !isNaN(data2))) && (isFinite(data2)))){
const err0 = {instancePath:instancePath+"/scope_pid",schemaPath:"#/properties/scope_pid/anyOf/0/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err0];
}
else {
vErrors.push(err0);
}
errors++;
}
if(errors === _errs8){
if((typeof data2 == "number") && (isFinite(data2))){
if(data2 > 9007199254740991 || isNaN(data2)){
const err1 = {instancePath:instancePath+"/scope_pid",schemaPath:"#/properties/scope_pid/anyOf/0/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"};
if(vErrors === null){
vErrors = [err1];
}
else {
vErrors.push(err1);
}
errors++;
}
else {
if(data2 < 0 || isNaN(data2)){
const err2 = {instancePath:instancePath+"/scope_pid",schemaPath:"#/properties/scope_pid/anyOf/0/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err2];
}
else {
vErrors.push(err2);
}
errors++;
}
}
}
}
var _valid0 = _errs8 === errors;
valid1 = valid1 || _valid0;
const _errs10 = errors;
if(data2 !== null){
const err3 = {instancePath:instancePath+"/scope_pid",schemaPath:"#/properties/scope_pid/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err3];
}
else {
vErrors.push(err3);
}
errors++;
}
var _valid0 = _errs10 === errors;
valid1 = valid1 || _valid0;
if(!valid1){
const err4 = {instancePath:instancePath+"/scope_pid",schemaPath:"#/properties/scope_pid/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err4];
}
else {
vErrors.push(err4);
}
errors++;
validate22.errors = vErrors;
return false;
}
else {
errors = _errs7;
if(vErrors !== null){
if(_errs7){
vErrors.length = _errs7;
}
else {
vErrors = null;
}
}
}
var valid0 = _errs6 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.read_only !== undefined){
const _errs12 = errors;
if(typeof data.read_only !== "boolean"){
validate22.errors = [{instancePath:instancePath+"/read_only",schemaPath:"#/properties/read_only/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"}];
return false;
}
var valid0 = _errs12 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.shared_principal !== undefined){
const _errs14 = errors;
if(typeof data.shared_principal !== "boolean"){
validate22.errors = [{instancePath:instancePath+"/shared_principal",schemaPath:"#/properties/shared_principal/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"}];
return false;
}
var valid0 = _errs14 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.page_size !== undefined){
let data5 = data.page_size;
const _errs16 = errors;
if(!(((typeof data5 == "number") && (!(data5 % 1) && !isNaN(data5))) && (isFinite(data5)))){
validate22.errors = [{instancePath:instancePath+"/page_size",schemaPath:"#/properties/page_size/type",keyword:"type",params:{type: "integer"},message:"must be integer"}];
return false;
}
if(errors === _errs16){
if((typeof data5 == "number") && (isFinite(data5))){
if(data5 > 4294967295 || isNaN(data5)){
validate22.errors = [{instancePath:instancePath+"/page_size",schemaPath:"#/properties/page_size/maximum",keyword:"maximum",params:{comparison: "<=", limit: 4294967295},message:"must be <= 4294967295"}];
return false;
}
else {
if(data5 < 0 || isNaN(data5)){
validate22.errors = [{instancePath:instancePath+"/page_size",schemaPath:"#/properties/page_size/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"}];
return false;
}
}
}
}
var valid0 = _errs16 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.scan_limit !== undefined){
let data6 = data.scan_limit;
const _errs18 = errors;
if(!(((typeof data6 == "number") && (!(data6 % 1) && !isNaN(data6))) && (isFinite(data6)))){
validate22.errors = [{instancePath:instancePath+"/scan_limit",schemaPath:"#/properties/scan_limit/type",keyword:"type",params:{type: "integer"},message:"must be integer"}];
return false;
}
if(errors === _errs18){
if((typeof data6 == "number") && (isFinite(data6))){
if(data6 > 4294967295 || isNaN(data6)){
validate22.errors = [{instancePath:instancePath+"/scan_limit",schemaPath:"#/properties/scan_limit/maximum",keyword:"maximum",params:{comparison: "<=", limit: 4294967295},message:"must be <= 4294967295"}];
return false;
}
else {
if(data6 < 0 || isNaN(data6)){
validate22.errors = [{instancePath:instancePath+"/scan_limit",schemaPath:"#/properties/scan_limit/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"}];
return false;
}
}
}
}
var valid0 = _errs18 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.max_edges !== undefined){
let data7 = data.max_edges;
const _errs20 = errors;
if(!(((typeof data7 == "number") && (!(data7 % 1) && !isNaN(data7))) && (isFinite(data7)))){
validate22.errors = [{instancePath:instancePath+"/max_edges",schemaPath:"#/properties/max_edges/type",keyword:"type",params:{type: "integer"},message:"must be integer"}];
return false;
}
if(errors === _errs20){
if((typeof data7 == "number") && (isFinite(data7))){
if(data7 > 4294967295 || isNaN(data7)){
validate22.errors = [{instancePath:instancePath+"/max_edges",schemaPath:"#/properties/max_edges/maximum",keyword:"maximum",params:{comparison: "<=", limit: 4294967295},message:"must be <= 4294967295"}];
return false;
}
else {
if(data7 < 0 || isNaN(data7)){
validate22.errors = [{instancePath:instancePath+"/max_edges",schemaPath:"#/properties/max_edges/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"}];
return false;
}
}
}
}
var valid0 = _errs20 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.min_refresh_ms !== undefined){
let data8 = data.min_refresh_ms;
const _errs22 = errors;
if(!(((typeof data8 == "number") && (!(data8 % 1) && !isNaN(data8))) && (isFinite(data8)))){
validate22.errors = [{instancePath:instancePath+"/min_refresh_ms",schemaPath:"#/properties/min_refresh_ms/type",keyword:"type",params:{type: "integer"},message:"must be integer"}];
return false;
}
if(errors === _errs22){
if((typeof data8 == "number") && (isFinite(data8))){
if(data8 > 4294967295 || isNaN(data8)){
validate22.errors = [{instancePath:instancePath+"/min_refresh_ms",schemaPath:"#/properties/min_refresh_ms/maximum",keyword:"maximum",params:{comparison: "<=", limit: 4294967295},message:"must be <= 4294967295"}];
return false;
}
else {
if(data8 < 0 || isNaN(data8)){
validate22.errors = [{instancePath:instancePath+"/min_refresh_ms",schemaPath:"#/properties/min_refresh_ms/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"}];
return false;
}
}
}
}
var valid0 = _errs22 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.max_request_bytes !== undefined){
let data9 = data.max_request_bytes;
const _errs24 = errors;
if(!(((typeof data9 == "number") && (!(data9 % 1) && !isNaN(data9))) && (isFinite(data9)))){
validate22.errors = [{instancePath:instancePath+"/max_request_bytes",schemaPath:"#/properties/max_request_bytes/type",keyword:"type",params:{type: "integer"},message:"must be integer"}];
return false;
}
if(errors === _errs24){
if((typeof data9 == "number") && (isFinite(data9))){
if(data9 > 4294967295 || isNaN(data9)){
validate22.errors = [{instancePath:instancePath+"/max_request_bytes",schemaPath:"#/properties/max_request_bytes/maximum",keyword:"maximum",params:{comparison: "<=", limit: 4294967295},message:"must be <= 4294967295"}];
return false;
}
else {
if(data9 < 0 || isNaN(data9)){
validate22.errors = [{instancePath:instancePath+"/max_request_bytes",schemaPath:"#/properties/max_request_bytes/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"}];
return false;
}
}
}
}
var valid0 = _errs24 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.state_resources !== undefined){
const _errs26 = errors;
if(typeof data.state_resources !== "boolean"){
validate22.errors = [{instancePath:instancePath+"/state_resources",schemaPath:"#/properties/state_resources/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"}];
return false;
}
var valid0 = _errs26 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.station !== undefined){
const _errs28 = errors;
if(typeof data.station !== "boolean"){
validate22.errors = [{instancePath:instancePath+"/station",schemaPath:"#/properties/station/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"}];
return false;
}
var valid0 = _errs28 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.http_connector !== undefined){
const _errs30 = errors;
if(typeof data.http_connector !== "boolean"){
validate22.errors = [{instancePath:instancePath+"/http_connector",schemaPath:"#/properties/http_connector/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"}];
return false;
}
var valid0 = _errs30 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.push !== undefined){
const _errs32 = errors;
if(typeof data.push !== "boolean"){
validate22.errors = [{instancePath:instancePath+"/push",schemaPath:"#/properties/push/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"}];
return false;
}
var valid0 = _errs32 === errors;
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
}
else {
validate22.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate22.errors = vErrors;
return errors === 0;
}
validate22.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

export const Error = validate23;
const schema34 = {"type":"object","additionalProperties":false,"properties":{"err":{"type":"string","enum":["Forbidden","NotFound","InvalidQuery","QueryExpired","HistoryReclaimed","Unavailable","RateLimited","InvalidOrigin","UnsafePrincipal","StateResourceExpired"]}},"required":["err"]};

function validate23(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate23.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((data.err === undefined) && (missing0 = "err")){
validate23.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(key0 === "err")){
validate23.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.err !== undefined){
let data0 = data.err;
if(typeof data0 !== "string"){
validate23.errors = [{instancePath:instancePath+"/err",schemaPath:"#/properties/err/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
if(!((((((((((data0 === "Forbidden") || (data0 === "NotFound")) || (data0 === "InvalidQuery")) || (data0 === "QueryExpired")) || (data0 === "HistoryReclaimed")) || (data0 === "Unavailable")) || (data0 === "RateLimited")) || (data0 === "InvalidOrigin")) || (data0 === "UnsafePrincipal")) || (data0 === "StateResourceExpired"))){
validate23.errors = [{instancePath:instancePath+"/err",schemaPath:"#/properties/err/enum",keyword:"enum",params:{allowedValues: schema34.properties.err.enum},message:"must be equal to one of the allowed values"}];
return false;
}
}
}
}
}
else {
validate23.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate23.errors = vErrors;
return errors === 0;
}
validate23.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};
