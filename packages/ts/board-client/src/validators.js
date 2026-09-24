// Generated; no runtime code generation or eval.
import lengthModule from "ajv/dist/runtime/ucs2length.js";
const ucs2length = lengthModule.default ?? lengthModule;
"use strict";
export const Response = validate20;
const schema31 = {"type":"object","additionalProperties":false,"properties":{"observation":{"type":"object","additionalProperties":false,"properties":{"version":{"type":"integer","minimum":0,"maximum":4294967295},"realm":{"type":"integer","minimum":0,"maximum":9007199254740991},"resource":{"type":"string","enum":["processes","process","mailbox","outbox","effects","payloads","history"]},"pid":{"anyOf":[{"type":"integer","minimum":0,"maximum":9007199254740991},{"type":"null"}]},"cut":{"type":"object","additionalProperties":false,"properties":{"position":{"type":"integer","minimum":0,"maximum":9007199254740991},"policy_revision":{"type":"integer","minimum":0,"maximum":9007199254740991},"retained_from":{"type":"integer","minimum":0,"maximum":9007199254740991}},"required":["position","policy_revision","retained_from"]},"reader":{"type":"object","additionalProperties":false,"properties":{"principal":{"type":"integer","minimum":0,"maximum":255},"permissions":{"type":"integer","minimum":0,"maximum":65535},"pid":{"anyOf":[{"type":"integer","minimum":0,"maximum":9007199254740991},{"type":"null"}]}},"required":["principal","permissions","pid"]},"next":{"anyOf":[{"type":"integer","minimum":0,"maximum":9007199254740991},{"type":"null"}]},"complete":{"type":"boolean"},"history":{"type":"string","enum":["retained","prefix_reclaimed"]},"scanned":{"type":"integer","minimum":0,"maximum":65535},"processes":{"type":"array","minItems":16,"maxItems":16,"items":{"anyOf":[{"type":"object","additionalProperties":false,"properties":{"pid":{"type":"integer","minimum":0,"maximum":9007199254740991},"code":{"type":"integer","minimum":0,"maximum":4294967295},"allow_trim":{"type":"boolean"},"owner":{"anyOf":[{"type":"integer","minimum":0,"maximum":255},{"type":"null"}]},"generation":{"type":"integer","minimum":0,"maximum":9007199254740991},"lifecycle":{"type":"string","enum":["running","terminated","expired"]},"state":{"type":"string","pattern":"^(?:[0-9a-f]{2})*$","maxLength":512},"revision":{"type":"integer","minimum":0,"maximum":9007199254740991},"failure":{"anyOf":[{"type":"object","additionalProperties":false,"properties":{"input":{"type":"integer","minimum":0,"maximum":9007199254740991},"recorded_at":{"type":"integer","minimum":0,"maximum":9007199254740991}},"required":["input","recorded_at"]},{"type":"null"}]},"admitted":{"type":"integer","minimum":0,"maximum":9007199254740991},"consumed":{"type":"integer","minimum":0,"maximum":9007199254740991},"cancelled":{"type":"integer","minimum":0,"maximum":9007199254740991},"work_before_ms":{"anyOf":[{"type":"integer","minimum":0,"maximum":9007199254740991},{"type":"null"}]},"settle_before_ms":{"anyOf":[{"type":"integer","minimum":0,"maximum":9007199254740991},{"type":"null"}]},"turn_permit":{"anyOf":[{"type":"object","additionalProperties":false,"properties":{"id":{"type":"integer","minimum":0,"maximum":9007199254740991},"input":{"type":"integer","minimum":0,"maximum":9007199254740991}},"required":["id","input"]},{"type":"null"}]},"binding":{"anyOf":[{"type":"object","additionalProperties":false,"properties":{"revision":{"type":"integer","minimum":0,"maximum":9007199254740991},"operation":{"type":"integer","minimum":0,"maximum":9007199254740991},"instance":{"type":"array","minItems":16,"maxItems":16,"items":{"type":"integer","minimum":0,"maximum":255}},"resource":{"type":"array","minItems":32,"maxItems":32,"items":{"type":"integer","minimum":0,"maximum":255}},"workload":{"type":"array","minItems":32,"maxItems":32,"items":{"type":"integer","minimum":0,"maximum":255}},"incarnation":{"anyOf":[{"type":"array","minItems":16,"maxItems":16,"items":{"type":"integer","minimum":0,"maximum":255}},{"type":"null"}]},"desired":{"type":"string","enum":["running","stopped"]},"phase":{"type":"string","enum":["pending","unknown","ready","stopped"]},"activation":{"anyOf":[{"type":"object","additionalProperties":false,"properties":{"worker_incarnation":{"type":"array","minItems":16,"maxItems":16,"items":{"type":"integer","minimum":0,"maximum":255}},"generation":{"type":"integer","minimum":0,"maximum":9007199254740991}},"required":["worker_incarnation","generation"]},{"type":"null"}]},"last_worker_incarnation":{"anyOf":[{"type":"array","minItems":16,"maxItems":16,"items":{"type":"integer","minimum":0,"maximum":255}},{"type":"null"}]}},"required":["revision","operation","instance","resource","workload","incarnation","desired","phase","activation","last_worker_incarnation"]},{"type":"null"}]}},"required":["pid","code","allow_trim","owner","generation","lifecycle","state","revision","failure","admitted","consumed","cancelled","work_before_ms","settle_before_ms","turn_permit","binding"]},{"type":"null"}]}},"events":{"type":"array","minItems":16,"maxItems":16,"items":{"anyOf":[{"type":"object","additionalProperties":false,"properties":{"position":{"type":"integer","minimum":0,"maximum":9007199254740991},"pid":{"type":"integer","minimum":0,"maximum":9007199254740991},"kind":{"type":"string","enum":["grant","revoke","spawn","own","runtime_intent","runtime_observe","activate","send","begin_turn","turn","deliver","dispatch","observe","close_effect","terminate","expire","inspect","checkpoint","declare_payload","payload_ready","retire_payload","payload_deleted"]},"policy_revision":{"type":"integer","minimum":0,"maximum":9007199254740991},"input":{"anyOf":[{"type":"integer","minimum":0,"maximum":9007199254740991},{"type":"null"}]},"effect":{"anyOf":[{"type":"integer","minimum":0,"maximum":9007199254740991},{"type":"null"}]},"output":{"anyOf":[{"type":"integer","minimum":0,"maximum":9007199254740991},{"type":"null"}]},"value":{"anyOf":[{"type":"string","pattern":"^(?:[0-9a-f]{2})*$","maxLength":512},{"type":"null"}]},"failed":{"type":"boolean"},"generation":{"anyOf":[{"type":"integer","minimum":0,"maximum":9007199254740991},{"type":"null"}]},"mailbox_status":{"anyOf":[{"type":"string","enum":["pending","consumed","cancelled"]},{"type":"null"}]},"admitted":{"type":"boolean"},"unix_ms":{"anyOf":[{"type":"integer","minimum":0,"maximum":9007199254740991},{"type":"null"}]},"clock_error_ms":{"anyOf":[{"type":"integer","minimum":0,"maximum":4294967295},{"type":"null"}]}},"required":["position","pid","kind","policy_revision","input","effect","output","value","failed","generation","mailbox_status","admitted","unix_ms","clock_error_ms"]},{"type":"null"}]}},"outbox":{"type":"array","minItems":16,"maxItems":16,"items":{"anyOf":[{"type":"object","additionalProperties":false,"properties":{"id":{"type":"integer","minimum":0,"maximum":9007199254740991},"source":{"type":"integer","minimum":0,"maximum":9007199254740991},"turn":{"type":"integer","minimum":0,"maximum":9007199254740991},"index":{"type":"integer","minimum":0,"maximum":255},"destination":{"type":"integer","minimum":0,"maximum":9007199254740991},"value":{"type":"string","pattern":"^(?:[0-9a-f]{2})*$","maxLength":512},"phase":{"type":"string","enum":["pending","delivered","denied","expired","retired","cancelled"]},"resolved_at":{"anyOf":[{"type":"integer","minimum":0,"maximum":9007199254740991},{"type":"null"}]},"courier":{"anyOf":[{"type":"integer","minimum":0,"maximum":255},{"type":"null"}]},"policy_revision":{"anyOf":[{"type":"integer","minimum":0,"maximum":9007199254740991},{"type":"null"}]}},"required":["id","source","turn","index","destination","value","phase","resolved_at","courier","policy_revision"]},{"type":"null"}]}},"effects":{"type":"array","minItems":16,"maxItems":16,"items":{"anyOf":[{"type":"object","additionalProperties":false,"properties":{"id":{"type":"integer","minimum":0,"maximum":9007199254740991},"pid":{"type":"integer","minimum":0,"maximum":9007199254740991},"payload":{"type":"string","pattern":"^(?:[0-9a-f]{2})*$","maxLength":512},"phase":{"type":"string","enum":["pending","authorized","unknown","observed","cancelled","closed_unknown"]},"attempt":{"anyOf":[{"type":"integer","minimum":0,"maximum":9007199254740991},{"type":"null"}]},"executor":{"anyOf":[{"type":"integer","minimum":0,"maximum":255},{"type":"null"}]},"result":{"anyOf":[{"type":"string","pattern":"^(?:[0-9a-f]{2})*$","maxLength":512},{"type":"null"}]},"closed_at":{"anyOf":[{"type":"integer","minimum":0,"maximum":9007199254740991},{"type":"null"}]},"reconcile_before_ms":{"anyOf":[{"type":"integer","minimum":0,"maximum":9007199254740991},{"type":"null"}]},"max_observations":{"type":"integer","minimum":0,"maximum":65535},"observations":{"type":"integer","minimum":0,"maximum":65535}},"required":["id","pid","payload","phase","attempt","executor","result","closed_at","reconcile_before_ms","max_observations","observations"]},{"type":"null"}]}},"payloads":{"type":"array","minItems":16,"maxItems":16,"items":{"anyOf":[{"type":"object","additionalProperties":false,"properties":{"id":{"type":"integer","minimum":0,"maximum":9007199254740991},"pid":{"type":"integer","minimum":0,"maximum":9007199254740991},"publisher":{"type":"integer","minimum":0,"maximum":255},"sha256":{"type":"array","minItems":32,"maxItems":32,"items":{"type":"integer","minimum":0,"maximum":255}},"bytes":{"type":"integer","minimum":0,"maximum":4294967295},"allow_delete":{"type":"boolean"},"phase":{"type":"string","enum":["creating","ready","retiring","deleted"]},"retired_at":{"anyOf":[{"type":"integer","minimum":0,"maximum":9007199254740991},{"type":"null"}]},"deleted_at":{"anyOf":[{"type":"integer","minimum":0,"maximum":9007199254740991},{"type":"null"}]}},"required":["id","pid","publisher","sha256","bytes","allow_delete","phase","retired_at","deleted_at"]},{"type":"null"}]}}},"required":["version","realm","resource","pid","cut","reader","next","complete","history","scanned","processes","events","outbox","effects","payloads"]},"lens":{"anyOf":[{"type":"object","additionalProperties":false,"properties":{"kind":{"type":"string","maxLength":256},"version":{"type":"integer","minimum":0,"maximum":4294967295},"provenance":{"type":"string","enum":["operator_mapping"]},"status":{"type":"string","enum":["applied","unknown","malformed"]},"source":{"type":"object","additionalProperties":false,"properties":{"realm":{"type":"integer","minimum":0,"maximum":9007199254740991},"pid":{"type":"integer","minimum":0,"maximum":9007199254740991},"kind":{"type":"string","enum":["input","turn","output","effect","event","state"]},"id":{"type":"integer","minimum":0,"maximum":9007199254740991}},"required":["realm","pid","kind","id"]},"count":{"anyOf":[{"type":"integer","minimum":-9007199254740991,"maximum":9007199254740991},{"type":"null"}]}},"required":["kind","version","provenance","status","source","count"]},{"type":"null"}]},"edges":{"type":"array","minItems":32,"maxItems":32,"items":{"anyOf":[{"type":"object","additionalProperties":false,"properties":{"from":{"type":"object","additionalProperties":false,"properties":{"realm":{"type":"integer","minimum":0,"maximum":9007199254740991},"pid":{"type":"integer","minimum":0,"maximum":9007199254740991},"kind":{"type":"string","enum":["input","turn","output","effect","event","state"]},"id":{"type":"integer","minimum":0,"maximum":9007199254740991}},"required":["realm","pid","kind","id"]},"to":{"type":"object","additionalProperties":false,"properties":{"realm":{"type":"integer","minimum":0,"maximum":9007199254740991},"pid":{"type":"integer","minimum":0,"maximum":9007199254740991},"kind":{"type":"string","enum":["input","turn","output","effect","event","state"]},"id":{"type":"integer","minimum":0,"maximum":9007199254740991}},"required":["realm","pid","kind","id"]},"relation":{"type":"string","enum":["input_to_turn","turn_to_effect","turn_to_output","output_to_admission","effect_to_observation"]},"from_coverage":{"type":"string","enum":["retained","reclaimed","current_state"]},"to_coverage":{"type":"string","enum":["retained","reclaimed","current_state"]}},"required":["from","to","relation","from_coverage","to_coverage"]},{"type":"null"}]}}},"required":["observation","lens","edges"]};
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
if((((data.observation === undefined) && (missing0 = "observation")) || ((data.lens === undefined) && (missing0 = "lens"))) || ((data.edges === undefined) && (missing0 = "edges"))){
validate20.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "observation") || (key0 === "lens")) || (key0 === "edges"))){
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
if(((((((((((((((((data18.pid === undefined) && (missing4 = "pid")) || ((data18.code === undefined) && (missing4 = "code"))) || ((data18.allow_trim === undefined) && (missing4 = "allow_trim"))) || ((data18.owner === undefined) && (missing4 = "owner"))) || ((data18.generation === undefined) && (missing4 = "generation"))) || ((data18.lifecycle === undefined) && (missing4 = "lifecycle"))) || ((data18.state === undefined) && (missing4 = "state"))) || ((data18.revision === undefined) && (missing4 = "revision"))) || ((data18.failure === undefined) && (missing4 = "failure"))) || ((data18.admitted === undefined) && (missing4 = "admitted"))) || ((data18.consumed === undefined) && (missing4 = "consumed"))) || ((data18.cancelled === undefined) && (missing4 = "cancelled"))) || ((data18.work_before_ms === undefined) && (missing4 = "work_before_ms"))) || ((data18.settle_before_ms === undefined) && (missing4 = "settle_before_ms"))) || ((data18.turn_permit === undefined) && (missing4 = "turn_permit"))) || ((data18.binding === undefined) && (missing4 = "binding"))){
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
if(data18.owner !== undefined){
let data22 = data18.owner;
const _errs64 = errors;
const _errs65 = errors;
let valid10 = false;
const _errs66 = errors;
if(!(((typeof data22 == "number") && (!(data22 % 1) && !isNaN(data22))) && (isFinite(data22)))){
const err24 = {instancePath:instancePath+"/observation/processes/" + i0+"/owner",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/owner/anyOf/0/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err24];
}
else {
vErrors.push(err24);
}
errors++;
}
if(errors === _errs66){
if((typeof data22 == "number") && (isFinite(data22))){
if(data22 > 255 || isNaN(data22)){
const err25 = {instancePath:instancePath+"/observation/processes/" + i0+"/owner",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/owner/anyOf/0/maximum",keyword:"maximum",params:{comparison: "<=", limit: 255},message:"must be <= 255"};
if(vErrors === null){
vErrors = [err25];
}
else {
vErrors.push(err25);
}
errors++;
}
else {
if(data22 < 0 || isNaN(data22)){
const err26 = {instancePath:instancePath+"/observation/processes/" + i0+"/owner",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/owner/anyOf/0/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err26];
}
else {
vErrors.push(err26);
}
errors++;
}
}
}
}
var _valid4 = _errs66 === errors;
valid10 = valid10 || _valid4;
const _errs68 = errors;
if(data22 !== null){
const err27 = {instancePath:instancePath+"/observation/processes/" + i0+"/owner",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/owner/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err27];
}
else {
vErrors.push(err27);
}
errors++;
}
var _valid4 = _errs68 === errors;
valid10 = valid10 || _valid4;
if(!valid10){
const err28 = {instancePath:instancePath+"/observation/processes/" + i0+"/owner",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/owner/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err28];
}
else {
vErrors.push(err28);
}
errors++;
}
else {
errors = _errs65;
if(vErrors !== null){
if(_errs65){
vErrors.length = _errs65;
}
else {
vErrors = null;
}
}
}
var valid9 = _errs64 === errors;
}
else {
var valid9 = true;
}
if(valid9){
if(data18.generation !== undefined){
let data23 = data18.generation;
const _errs70 = errors;
if(!(((typeof data23 == "number") && (!(data23 % 1) && !isNaN(data23))) && (isFinite(data23)))){
const err29 = {instancePath:instancePath+"/observation/processes/" + i0+"/generation",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/generation/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err29];
}
else {
vErrors.push(err29);
}
errors++;
}
if(errors === _errs70){
if((typeof data23 == "number") && (isFinite(data23))){
if(data23 > 9007199254740991 || isNaN(data23)){
const err30 = {instancePath:instancePath+"/observation/processes/" + i0+"/generation",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/generation/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"};
if(vErrors === null){
vErrors = [err30];
}
else {
vErrors.push(err30);
}
errors++;
}
else {
if(data23 < 0 || isNaN(data23)){
const err31 = {instancePath:instancePath+"/observation/processes/" + i0+"/generation",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/generation/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err31];
}
else {
vErrors.push(err31);
}
errors++;
}
}
}
}
var valid9 = _errs70 === errors;
}
else {
var valid9 = true;
}
if(valid9){
if(data18.lifecycle !== undefined){
let data24 = data18.lifecycle;
const _errs72 = errors;
if(typeof data24 !== "string"){
const err32 = {instancePath:instancePath+"/observation/processes/" + i0+"/lifecycle",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/lifecycle/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err32];
}
else {
vErrors.push(err32);
}
errors++;
}
if(!(((data24 === "running") || (data24 === "terminated")) || (data24 === "expired"))){
const err33 = {instancePath:instancePath+"/observation/processes/" + i0+"/lifecycle",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/lifecycle/enum",keyword:"enum",params:{allowedValues: schema31.properties.observation.properties.processes.items.anyOf[0].properties.lifecycle.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err33];
}
else {
vErrors.push(err33);
}
errors++;
}
var valid9 = _errs72 === errors;
}
else {
var valid9 = true;
}
if(valid9){
if(data18.state !== undefined){
let data25 = data18.state;
const _errs74 = errors;
if(errors === _errs74){
if(typeof data25 === "string"){
if(func3(data25) > 512){
const err34 = {instancePath:instancePath+"/observation/processes/" + i0+"/state",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/state/maxLength",keyword:"maxLength",params:{limit: 512},message:"must NOT have more than 512 characters"};
if(vErrors === null){
vErrors = [err34];
}
else {
vErrors.push(err34);
}
errors++;
}
else {
if(!pattern4.test(data25)){
const err35 = {instancePath:instancePath+"/observation/processes/" + i0+"/state",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/state/pattern",keyword:"pattern",params:{pattern: "^(?:[0-9a-f]{2})*$"},message:"must match pattern \""+"^(?:[0-9a-f]{2})*$"+"\""};
if(vErrors === null){
vErrors = [err35];
}
else {
vErrors.push(err35);
}
errors++;
}
}
}
else {
const err36 = {instancePath:instancePath+"/observation/processes/" + i0+"/state",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/state/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err36];
}
else {
vErrors.push(err36);
}
errors++;
}
}
var valid9 = _errs74 === errors;
}
else {
var valid9 = true;
}
if(valid9){
if(data18.revision !== undefined){
let data26 = data18.revision;
const _errs76 = errors;
if(!(((typeof data26 == "number") && (!(data26 % 1) && !isNaN(data26))) && (isFinite(data26)))){
const err37 = {instancePath:instancePath+"/observation/processes/" + i0+"/revision",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/revision/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err37];
}
else {
vErrors.push(err37);
}
errors++;
}
if(errors === _errs76){
if((typeof data26 == "number") && (isFinite(data26))){
if(data26 > 9007199254740991 || isNaN(data26)){
const err38 = {instancePath:instancePath+"/observation/processes/" + i0+"/revision",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/revision/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"};
if(vErrors === null){
vErrors = [err38];
}
else {
vErrors.push(err38);
}
errors++;
}
else {
if(data26 < 0 || isNaN(data26)){
const err39 = {instancePath:instancePath+"/observation/processes/" + i0+"/revision",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/revision/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
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
var valid9 = _errs76 === errors;
}
else {
var valid9 = true;
}
if(valid9){
if(data18.failure !== undefined){
let data27 = data18.failure;
const _errs78 = errors;
const _errs79 = errors;
let valid11 = false;
const _errs80 = errors;
if(errors === _errs80){
if(data27 && typeof data27 == "object" && !Array.isArray(data27)){
let missing5;
if(((data27.input === undefined) && (missing5 = "input")) || ((data27.recorded_at === undefined) && (missing5 = "recorded_at"))){
const err40 = {instancePath:instancePath+"/observation/processes/" + i0+"/failure",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/failure/anyOf/0/required",keyword:"required",params:{missingProperty: missing5},message:"must have required property '"+missing5+"'"};
if(vErrors === null){
vErrors = [err40];
}
else {
vErrors.push(err40);
}
errors++;
}
else {
const _errs82 = errors;
for(const key5 in data27){
if(!((key5 === "input") || (key5 === "recorded_at"))){
const err41 = {instancePath:instancePath+"/observation/processes/" + i0+"/failure",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/failure/anyOf/0/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key5},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err41];
}
else {
vErrors.push(err41);
}
errors++;
break;
}
}
if(_errs82 === errors){
if(data27.input !== undefined){
let data28 = data27.input;
const _errs83 = errors;
if(!(((typeof data28 == "number") && (!(data28 % 1) && !isNaN(data28))) && (isFinite(data28)))){
const err42 = {instancePath:instancePath+"/observation/processes/" + i0+"/failure/input",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/failure/anyOf/0/properties/input/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err42];
}
else {
vErrors.push(err42);
}
errors++;
}
if(errors === _errs83){
if((typeof data28 == "number") && (isFinite(data28))){
if(data28 > 9007199254740991 || isNaN(data28)){
const err43 = {instancePath:instancePath+"/observation/processes/" + i0+"/failure/input",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/failure/anyOf/0/properties/input/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"};
if(vErrors === null){
vErrors = [err43];
}
else {
vErrors.push(err43);
}
errors++;
}
else {
if(data28 < 0 || isNaN(data28)){
const err44 = {instancePath:instancePath+"/observation/processes/" + i0+"/failure/input",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/failure/anyOf/0/properties/input/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
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
}
var valid12 = _errs83 === errors;
}
else {
var valid12 = true;
}
if(valid12){
if(data27.recorded_at !== undefined){
let data29 = data27.recorded_at;
const _errs85 = errors;
if(!(((typeof data29 == "number") && (!(data29 % 1) && !isNaN(data29))) && (isFinite(data29)))){
const err45 = {instancePath:instancePath+"/observation/processes/" + i0+"/failure/recorded_at",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/failure/anyOf/0/properties/recorded_at/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err45];
}
else {
vErrors.push(err45);
}
errors++;
}
if(errors === _errs85){
if((typeof data29 == "number") && (isFinite(data29))){
if(data29 > 9007199254740991 || isNaN(data29)){
const err46 = {instancePath:instancePath+"/observation/processes/" + i0+"/failure/recorded_at",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/failure/anyOf/0/properties/recorded_at/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"};
if(vErrors === null){
vErrors = [err46];
}
else {
vErrors.push(err46);
}
errors++;
}
else {
if(data29 < 0 || isNaN(data29)){
const err47 = {instancePath:instancePath+"/observation/processes/" + i0+"/failure/recorded_at",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/failure/anyOf/0/properties/recorded_at/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
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
var valid12 = _errs85 === errors;
}
else {
var valid12 = true;
}
}
}
}
}
else {
const err48 = {instancePath:instancePath+"/observation/processes/" + i0+"/failure",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/failure/anyOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err48];
}
else {
vErrors.push(err48);
}
errors++;
}
}
var _valid5 = _errs80 === errors;
valid11 = valid11 || _valid5;
const _errs87 = errors;
if(data27 !== null){
const err49 = {instancePath:instancePath+"/observation/processes/" + i0+"/failure",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/failure/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err49];
}
else {
vErrors.push(err49);
}
errors++;
}
var _valid5 = _errs87 === errors;
valid11 = valid11 || _valid5;
if(!valid11){
const err50 = {instancePath:instancePath+"/observation/processes/" + i0+"/failure",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/failure/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err50];
}
else {
vErrors.push(err50);
}
errors++;
}
else {
errors = _errs79;
if(vErrors !== null){
if(_errs79){
vErrors.length = _errs79;
}
else {
vErrors = null;
}
}
}
var valid9 = _errs78 === errors;
}
else {
var valid9 = true;
}
if(valid9){
if(data18.admitted !== undefined){
let data30 = data18.admitted;
const _errs89 = errors;
if(!(((typeof data30 == "number") && (!(data30 % 1) && !isNaN(data30))) && (isFinite(data30)))){
const err51 = {instancePath:instancePath+"/observation/processes/" + i0+"/admitted",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/admitted/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err51];
}
else {
vErrors.push(err51);
}
errors++;
}
if(errors === _errs89){
if((typeof data30 == "number") && (isFinite(data30))){
if(data30 > 9007199254740991 || isNaN(data30)){
const err52 = {instancePath:instancePath+"/observation/processes/" + i0+"/admitted",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/admitted/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"};
if(vErrors === null){
vErrors = [err52];
}
else {
vErrors.push(err52);
}
errors++;
}
else {
if(data30 < 0 || isNaN(data30)){
const err53 = {instancePath:instancePath+"/observation/processes/" + i0+"/admitted",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/admitted/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
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
}
var valid9 = _errs89 === errors;
}
else {
var valid9 = true;
}
if(valid9){
if(data18.consumed !== undefined){
let data31 = data18.consumed;
const _errs91 = errors;
if(!(((typeof data31 == "number") && (!(data31 % 1) && !isNaN(data31))) && (isFinite(data31)))){
const err54 = {instancePath:instancePath+"/observation/processes/" + i0+"/consumed",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/consumed/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err54];
}
else {
vErrors.push(err54);
}
errors++;
}
if(errors === _errs91){
if((typeof data31 == "number") && (isFinite(data31))){
if(data31 > 9007199254740991 || isNaN(data31)){
const err55 = {instancePath:instancePath+"/observation/processes/" + i0+"/consumed",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/consumed/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"};
if(vErrors === null){
vErrors = [err55];
}
else {
vErrors.push(err55);
}
errors++;
}
else {
if(data31 < 0 || isNaN(data31)){
const err56 = {instancePath:instancePath+"/observation/processes/" + i0+"/consumed",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/consumed/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
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
}
var valid9 = _errs91 === errors;
}
else {
var valid9 = true;
}
if(valid9){
if(data18.cancelled !== undefined){
let data32 = data18.cancelled;
const _errs93 = errors;
if(!(((typeof data32 == "number") && (!(data32 % 1) && !isNaN(data32))) && (isFinite(data32)))){
const err57 = {instancePath:instancePath+"/observation/processes/" + i0+"/cancelled",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/cancelled/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err57];
}
else {
vErrors.push(err57);
}
errors++;
}
if(errors === _errs93){
if((typeof data32 == "number") && (isFinite(data32))){
if(data32 > 9007199254740991 || isNaN(data32)){
const err58 = {instancePath:instancePath+"/observation/processes/" + i0+"/cancelled",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/cancelled/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"};
if(vErrors === null){
vErrors = [err58];
}
else {
vErrors.push(err58);
}
errors++;
}
else {
if(data32 < 0 || isNaN(data32)){
const err59 = {instancePath:instancePath+"/observation/processes/" + i0+"/cancelled",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/cancelled/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err59];
}
else {
vErrors.push(err59);
}
errors++;
}
}
}
}
var valid9 = _errs93 === errors;
}
else {
var valid9 = true;
}
if(valid9){
if(data18.work_before_ms !== undefined){
let data33 = data18.work_before_ms;
const _errs95 = errors;
const _errs96 = errors;
let valid13 = false;
const _errs97 = errors;
if(!(((typeof data33 == "number") && (!(data33 % 1) && !isNaN(data33))) && (isFinite(data33)))){
const err60 = {instancePath:instancePath+"/observation/processes/" + i0+"/work_before_ms",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/work_before_ms/anyOf/0/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err60];
}
else {
vErrors.push(err60);
}
errors++;
}
if(errors === _errs97){
if((typeof data33 == "number") && (isFinite(data33))){
if(data33 > 9007199254740991 || isNaN(data33)){
const err61 = {instancePath:instancePath+"/observation/processes/" + i0+"/work_before_ms",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/work_before_ms/anyOf/0/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"};
if(vErrors === null){
vErrors = [err61];
}
else {
vErrors.push(err61);
}
errors++;
}
else {
if(data33 < 0 || isNaN(data33)){
const err62 = {instancePath:instancePath+"/observation/processes/" + i0+"/work_before_ms",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/work_before_ms/anyOf/0/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err62];
}
else {
vErrors.push(err62);
}
errors++;
}
}
}
}
var _valid6 = _errs97 === errors;
valid13 = valid13 || _valid6;
const _errs99 = errors;
if(data33 !== null){
const err63 = {instancePath:instancePath+"/observation/processes/" + i0+"/work_before_ms",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/work_before_ms/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err63];
}
else {
vErrors.push(err63);
}
errors++;
}
var _valid6 = _errs99 === errors;
valid13 = valid13 || _valid6;
if(!valid13){
const err64 = {instancePath:instancePath+"/observation/processes/" + i0+"/work_before_ms",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/work_before_ms/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err64];
}
else {
vErrors.push(err64);
}
errors++;
}
else {
errors = _errs96;
if(vErrors !== null){
if(_errs96){
vErrors.length = _errs96;
}
else {
vErrors = null;
}
}
}
var valid9 = _errs95 === errors;
}
else {
var valid9 = true;
}
if(valid9){
if(data18.settle_before_ms !== undefined){
let data34 = data18.settle_before_ms;
const _errs101 = errors;
const _errs102 = errors;
let valid14 = false;
const _errs103 = errors;
if(!(((typeof data34 == "number") && (!(data34 % 1) && !isNaN(data34))) && (isFinite(data34)))){
const err65 = {instancePath:instancePath+"/observation/processes/" + i0+"/settle_before_ms",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/settle_before_ms/anyOf/0/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err65];
}
else {
vErrors.push(err65);
}
errors++;
}
if(errors === _errs103){
if((typeof data34 == "number") && (isFinite(data34))){
if(data34 > 9007199254740991 || isNaN(data34)){
const err66 = {instancePath:instancePath+"/observation/processes/" + i0+"/settle_before_ms",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/settle_before_ms/anyOf/0/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"};
if(vErrors === null){
vErrors = [err66];
}
else {
vErrors.push(err66);
}
errors++;
}
else {
if(data34 < 0 || isNaN(data34)){
const err67 = {instancePath:instancePath+"/observation/processes/" + i0+"/settle_before_ms",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/settle_before_ms/anyOf/0/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err67];
}
else {
vErrors.push(err67);
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
const err68 = {instancePath:instancePath+"/observation/processes/" + i0+"/settle_before_ms",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/settle_before_ms/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err68];
}
else {
vErrors.push(err68);
}
errors++;
}
var _valid7 = _errs105 === errors;
valid14 = valid14 || _valid7;
if(!valid14){
const err69 = {instancePath:instancePath+"/observation/processes/" + i0+"/settle_before_ms",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/settle_before_ms/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err69];
}
else {
vErrors.push(err69);
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
var valid9 = _errs101 === errors;
}
else {
var valid9 = true;
}
if(valid9){
if(data18.turn_permit !== undefined){
let data35 = data18.turn_permit;
const _errs107 = errors;
const _errs108 = errors;
let valid15 = false;
const _errs109 = errors;
if(errors === _errs109){
if(data35 && typeof data35 == "object" && !Array.isArray(data35)){
let missing6;
if(((data35.id === undefined) && (missing6 = "id")) || ((data35.input === undefined) && (missing6 = "input"))){
const err70 = {instancePath:instancePath+"/observation/processes/" + i0+"/turn_permit",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/turn_permit/anyOf/0/required",keyword:"required",params:{missingProperty: missing6},message:"must have required property '"+missing6+"'"};
if(vErrors === null){
vErrors = [err70];
}
else {
vErrors.push(err70);
}
errors++;
}
else {
const _errs111 = errors;
for(const key6 in data35){
if(!((key6 === "id") || (key6 === "input"))){
const err71 = {instancePath:instancePath+"/observation/processes/" + i0+"/turn_permit",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/turn_permit/anyOf/0/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key6},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err71];
}
else {
vErrors.push(err71);
}
errors++;
break;
}
}
if(_errs111 === errors){
if(data35.id !== undefined){
let data36 = data35.id;
const _errs112 = errors;
if(!(((typeof data36 == "number") && (!(data36 % 1) && !isNaN(data36))) && (isFinite(data36)))){
const err72 = {instancePath:instancePath+"/observation/processes/" + i0+"/turn_permit/id",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/turn_permit/anyOf/0/properties/id/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err72];
}
else {
vErrors.push(err72);
}
errors++;
}
if(errors === _errs112){
if((typeof data36 == "number") && (isFinite(data36))){
if(data36 > 9007199254740991 || isNaN(data36)){
const err73 = {instancePath:instancePath+"/observation/processes/" + i0+"/turn_permit/id",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/turn_permit/anyOf/0/properties/id/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"};
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
const err74 = {instancePath:instancePath+"/observation/processes/" + i0+"/turn_permit/id",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/turn_permit/anyOf/0/properties/id/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
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
var valid16 = _errs112 === errors;
}
else {
var valid16 = true;
}
if(valid16){
if(data35.input !== undefined){
let data37 = data35.input;
const _errs114 = errors;
if(!(((typeof data37 == "number") && (!(data37 % 1) && !isNaN(data37))) && (isFinite(data37)))){
const err75 = {instancePath:instancePath+"/observation/processes/" + i0+"/turn_permit/input",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/turn_permit/anyOf/0/properties/input/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err75];
}
else {
vErrors.push(err75);
}
errors++;
}
if(errors === _errs114){
if((typeof data37 == "number") && (isFinite(data37))){
if(data37 > 9007199254740991 || isNaN(data37)){
const err76 = {instancePath:instancePath+"/observation/processes/" + i0+"/turn_permit/input",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/turn_permit/anyOf/0/properties/input/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"};
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
const err77 = {instancePath:instancePath+"/observation/processes/" + i0+"/turn_permit/input",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/turn_permit/anyOf/0/properties/input/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
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
var valid16 = _errs114 === errors;
}
else {
var valid16 = true;
}
}
}
}
}
else {
const err78 = {instancePath:instancePath+"/observation/processes/" + i0+"/turn_permit",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/turn_permit/anyOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err78];
}
else {
vErrors.push(err78);
}
errors++;
}
}
var _valid8 = _errs109 === errors;
valid15 = valid15 || _valid8;
const _errs116 = errors;
if(data35 !== null){
const err79 = {instancePath:instancePath+"/observation/processes/" + i0+"/turn_permit",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/turn_permit/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err79];
}
else {
vErrors.push(err79);
}
errors++;
}
var _valid8 = _errs116 === errors;
valid15 = valid15 || _valid8;
if(!valid15){
const err80 = {instancePath:instancePath+"/observation/processes/" + i0+"/turn_permit",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/turn_permit/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err80];
}
else {
vErrors.push(err80);
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
var valid9 = _errs107 === errors;
}
else {
var valid9 = true;
}
if(valid9){
if(data18.binding !== undefined){
let data38 = data18.binding;
const _errs118 = errors;
const _errs119 = errors;
let valid17 = false;
const _errs120 = errors;
if(errors === _errs120){
if(data38 && typeof data38 == "object" && !Array.isArray(data38)){
let missing7;
if(((((((((((data38.revision === undefined) && (missing7 = "revision")) || ((data38.operation === undefined) && (missing7 = "operation"))) || ((data38.instance === undefined) && (missing7 = "instance"))) || ((data38.resource === undefined) && (missing7 = "resource"))) || ((data38.workload === undefined) && (missing7 = "workload"))) || ((data38.incarnation === undefined) && (missing7 = "incarnation"))) || ((data38.desired === undefined) && (missing7 = "desired"))) || ((data38.phase === undefined) && (missing7 = "phase"))) || ((data38.activation === undefined) && (missing7 = "activation"))) || ((data38.last_worker_incarnation === undefined) && (missing7 = "last_worker_incarnation"))){
const err81 = {instancePath:instancePath+"/observation/processes/" + i0+"/binding",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/binding/anyOf/0/required",keyword:"required",params:{missingProperty: missing7},message:"must have required property '"+missing7+"'"};
if(vErrors === null){
vErrors = [err81];
}
else {
vErrors.push(err81);
}
errors++;
}
else {
const _errs122 = errors;
for(const key7 in data38){
if(!(func1.call(schema31.properties.observation.properties.processes.items.anyOf[0].properties.binding.anyOf[0].properties, key7))){
const err82 = {instancePath:instancePath+"/observation/processes/" + i0+"/binding",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/binding/anyOf/0/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key7},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err82];
}
else {
vErrors.push(err82);
}
errors++;
break;
}
}
if(_errs122 === errors){
if(data38.revision !== undefined){
let data39 = data38.revision;
const _errs123 = errors;
if(!(((typeof data39 == "number") && (!(data39 % 1) && !isNaN(data39))) && (isFinite(data39)))){
const err83 = {instancePath:instancePath+"/observation/processes/" + i0+"/binding/revision",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/binding/anyOf/0/properties/revision/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err83];
}
else {
vErrors.push(err83);
}
errors++;
}
if(errors === _errs123){
if((typeof data39 == "number") && (isFinite(data39))){
if(data39 > 9007199254740991 || isNaN(data39)){
const err84 = {instancePath:instancePath+"/observation/processes/" + i0+"/binding/revision",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/binding/anyOf/0/properties/revision/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"};
if(vErrors === null){
vErrors = [err84];
}
else {
vErrors.push(err84);
}
errors++;
}
else {
if(data39 < 0 || isNaN(data39)){
const err85 = {instancePath:instancePath+"/observation/processes/" + i0+"/binding/revision",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/binding/anyOf/0/properties/revision/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
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
var valid18 = _errs123 === errors;
}
else {
var valid18 = true;
}
if(valid18){
if(data38.operation !== undefined){
let data40 = data38.operation;
const _errs125 = errors;
if(!(((typeof data40 == "number") && (!(data40 % 1) && !isNaN(data40))) && (isFinite(data40)))){
const err86 = {instancePath:instancePath+"/observation/processes/" + i0+"/binding/operation",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/binding/anyOf/0/properties/operation/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err86];
}
else {
vErrors.push(err86);
}
errors++;
}
if(errors === _errs125){
if((typeof data40 == "number") && (isFinite(data40))){
if(data40 > 9007199254740991 || isNaN(data40)){
const err87 = {instancePath:instancePath+"/observation/processes/" + i0+"/binding/operation",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/binding/anyOf/0/properties/operation/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"};
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
const err88 = {instancePath:instancePath+"/observation/processes/" + i0+"/binding/operation",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/binding/anyOf/0/properties/operation/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
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
var valid18 = _errs125 === errors;
}
else {
var valid18 = true;
}
if(valid18){
if(data38.instance !== undefined){
let data41 = data38.instance;
const _errs127 = errors;
if(errors === _errs127){
if(Array.isArray(data41)){
if(data41.length > 16){
const err89 = {instancePath:instancePath+"/observation/processes/" + i0+"/binding/instance",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/binding/anyOf/0/properties/instance/maxItems",keyword:"maxItems",params:{limit: 16},message:"must NOT have more than 16 items"};
if(vErrors === null){
vErrors = [err89];
}
else {
vErrors.push(err89);
}
errors++;
}
else {
if(data41.length < 16){
const err90 = {instancePath:instancePath+"/observation/processes/" + i0+"/binding/instance",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/binding/anyOf/0/properties/instance/minItems",keyword:"minItems",params:{limit: 16},message:"must NOT have fewer than 16 items"};
if(vErrors === null){
vErrors = [err90];
}
else {
vErrors.push(err90);
}
errors++;
}
else {
var valid19 = true;
const len1 = data41.length;
for(let i1=0; i1<len1; i1++){
let data42 = data41[i1];
const _errs129 = errors;
if(!(((typeof data42 == "number") && (!(data42 % 1) && !isNaN(data42))) && (isFinite(data42)))){
const err91 = {instancePath:instancePath+"/observation/processes/" + i0+"/binding/instance/" + i1,schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/binding/anyOf/0/properties/instance/items/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err91];
}
else {
vErrors.push(err91);
}
errors++;
}
if(errors === _errs129){
if((typeof data42 == "number") && (isFinite(data42))){
if(data42 > 255 || isNaN(data42)){
const err92 = {instancePath:instancePath+"/observation/processes/" + i0+"/binding/instance/" + i1,schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/binding/anyOf/0/properties/instance/items/maximum",keyword:"maximum",params:{comparison: "<=", limit: 255},message:"must be <= 255"};
if(vErrors === null){
vErrors = [err92];
}
else {
vErrors.push(err92);
}
errors++;
}
else {
if(data42 < 0 || isNaN(data42)){
const err93 = {instancePath:instancePath+"/observation/processes/" + i0+"/binding/instance/" + i1,schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/binding/anyOf/0/properties/instance/items/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
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
var valid19 = _errs129 === errors;
if(!valid19){
break;
}
}
}
}
}
else {
const err94 = {instancePath:instancePath+"/observation/processes/" + i0+"/binding/instance",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/binding/anyOf/0/properties/instance/type",keyword:"type",params:{type: "array"},message:"must be array"};
if(vErrors === null){
vErrors = [err94];
}
else {
vErrors.push(err94);
}
errors++;
}
}
var valid18 = _errs127 === errors;
}
else {
var valid18 = true;
}
if(valid18){
if(data38.resource !== undefined){
let data43 = data38.resource;
const _errs131 = errors;
if(errors === _errs131){
if(Array.isArray(data43)){
if(data43.length > 32){
const err95 = {instancePath:instancePath+"/observation/processes/" + i0+"/binding/resource",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/binding/anyOf/0/properties/resource/maxItems",keyword:"maxItems",params:{limit: 32},message:"must NOT have more than 32 items"};
if(vErrors === null){
vErrors = [err95];
}
else {
vErrors.push(err95);
}
errors++;
}
else {
if(data43.length < 32){
const err96 = {instancePath:instancePath+"/observation/processes/" + i0+"/binding/resource",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/binding/anyOf/0/properties/resource/minItems",keyword:"minItems",params:{limit: 32},message:"must NOT have fewer than 32 items"};
if(vErrors === null){
vErrors = [err96];
}
else {
vErrors.push(err96);
}
errors++;
}
else {
var valid20 = true;
const len2 = data43.length;
for(let i2=0; i2<len2; i2++){
let data44 = data43[i2];
const _errs133 = errors;
if(!(((typeof data44 == "number") && (!(data44 % 1) && !isNaN(data44))) && (isFinite(data44)))){
const err97 = {instancePath:instancePath+"/observation/processes/" + i0+"/binding/resource/" + i2,schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/binding/anyOf/0/properties/resource/items/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err97];
}
else {
vErrors.push(err97);
}
errors++;
}
if(errors === _errs133){
if((typeof data44 == "number") && (isFinite(data44))){
if(data44 > 255 || isNaN(data44)){
const err98 = {instancePath:instancePath+"/observation/processes/" + i0+"/binding/resource/" + i2,schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/binding/anyOf/0/properties/resource/items/maximum",keyword:"maximum",params:{comparison: "<=", limit: 255},message:"must be <= 255"};
if(vErrors === null){
vErrors = [err98];
}
else {
vErrors.push(err98);
}
errors++;
}
else {
if(data44 < 0 || isNaN(data44)){
const err99 = {instancePath:instancePath+"/observation/processes/" + i0+"/binding/resource/" + i2,schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/binding/anyOf/0/properties/resource/items/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
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
var valid20 = _errs133 === errors;
if(!valid20){
break;
}
}
}
}
}
else {
const err100 = {instancePath:instancePath+"/observation/processes/" + i0+"/binding/resource",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/binding/anyOf/0/properties/resource/type",keyword:"type",params:{type: "array"},message:"must be array"};
if(vErrors === null){
vErrors = [err100];
}
else {
vErrors.push(err100);
}
errors++;
}
}
var valid18 = _errs131 === errors;
}
else {
var valid18 = true;
}
if(valid18){
if(data38.workload !== undefined){
let data45 = data38.workload;
const _errs135 = errors;
if(errors === _errs135){
if(Array.isArray(data45)){
if(data45.length > 32){
const err101 = {instancePath:instancePath+"/observation/processes/" + i0+"/binding/workload",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/binding/anyOf/0/properties/workload/maxItems",keyword:"maxItems",params:{limit: 32},message:"must NOT have more than 32 items"};
if(vErrors === null){
vErrors = [err101];
}
else {
vErrors.push(err101);
}
errors++;
}
else {
if(data45.length < 32){
const err102 = {instancePath:instancePath+"/observation/processes/" + i0+"/binding/workload",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/binding/anyOf/0/properties/workload/minItems",keyword:"minItems",params:{limit: 32},message:"must NOT have fewer than 32 items"};
if(vErrors === null){
vErrors = [err102];
}
else {
vErrors.push(err102);
}
errors++;
}
else {
var valid21 = true;
const len3 = data45.length;
for(let i3=0; i3<len3; i3++){
let data46 = data45[i3];
const _errs137 = errors;
if(!(((typeof data46 == "number") && (!(data46 % 1) && !isNaN(data46))) && (isFinite(data46)))){
const err103 = {instancePath:instancePath+"/observation/processes/" + i0+"/binding/workload/" + i3,schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/binding/anyOf/0/properties/workload/items/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err103];
}
else {
vErrors.push(err103);
}
errors++;
}
if(errors === _errs137){
if((typeof data46 == "number") && (isFinite(data46))){
if(data46 > 255 || isNaN(data46)){
const err104 = {instancePath:instancePath+"/observation/processes/" + i0+"/binding/workload/" + i3,schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/binding/anyOf/0/properties/workload/items/maximum",keyword:"maximum",params:{comparison: "<=", limit: 255},message:"must be <= 255"};
if(vErrors === null){
vErrors = [err104];
}
else {
vErrors.push(err104);
}
errors++;
}
else {
if(data46 < 0 || isNaN(data46)){
const err105 = {instancePath:instancePath+"/observation/processes/" + i0+"/binding/workload/" + i3,schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/binding/anyOf/0/properties/workload/items/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err105];
}
else {
vErrors.push(err105);
}
errors++;
}
}
}
}
var valid21 = _errs137 === errors;
if(!valid21){
break;
}
}
}
}
}
else {
const err106 = {instancePath:instancePath+"/observation/processes/" + i0+"/binding/workload",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/binding/anyOf/0/properties/workload/type",keyword:"type",params:{type: "array"},message:"must be array"};
if(vErrors === null){
vErrors = [err106];
}
else {
vErrors.push(err106);
}
errors++;
}
}
var valid18 = _errs135 === errors;
}
else {
var valid18 = true;
}
if(valid18){
if(data38.incarnation !== undefined){
let data47 = data38.incarnation;
const _errs139 = errors;
const _errs140 = errors;
let valid22 = false;
const _errs141 = errors;
if(errors === _errs141){
if(Array.isArray(data47)){
if(data47.length > 16){
const err107 = {instancePath:instancePath+"/observation/processes/" + i0+"/binding/incarnation",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/binding/anyOf/0/properties/incarnation/anyOf/0/maxItems",keyword:"maxItems",params:{limit: 16},message:"must NOT have more than 16 items"};
if(vErrors === null){
vErrors = [err107];
}
else {
vErrors.push(err107);
}
errors++;
}
else {
if(data47.length < 16){
const err108 = {instancePath:instancePath+"/observation/processes/" + i0+"/binding/incarnation",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/binding/anyOf/0/properties/incarnation/anyOf/0/minItems",keyword:"minItems",params:{limit: 16},message:"must NOT have fewer than 16 items"};
if(vErrors === null){
vErrors = [err108];
}
else {
vErrors.push(err108);
}
errors++;
}
else {
var valid23 = true;
const len4 = data47.length;
for(let i4=0; i4<len4; i4++){
let data48 = data47[i4];
const _errs143 = errors;
if(!(((typeof data48 == "number") && (!(data48 % 1) && !isNaN(data48))) && (isFinite(data48)))){
const err109 = {instancePath:instancePath+"/observation/processes/" + i0+"/binding/incarnation/" + i4,schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/binding/anyOf/0/properties/incarnation/anyOf/0/items/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err109];
}
else {
vErrors.push(err109);
}
errors++;
}
if(errors === _errs143){
if((typeof data48 == "number") && (isFinite(data48))){
if(data48 > 255 || isNaN(data48)){
const err110 = {instancePath:instancePath+"/observation/processes/" + i0+"/binding/incarnation/" + i4,schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/binding/anyOf/0/properties/incarnation/anyOf/0/items/maximum",keyword:"maximum",params:{comparison: "<=", limit: 255},message:"must be <= 255"};
if(vErrors === null){
vErrors = [err110];
}
else {
vErrors.push(err110);
}
errors++;
}
else {
if(data48 < 0 || isNaN(data48)){
const err111 = {instancePath:instancePath+"/observation/processes/" + i0+"/binding/incarnation/" + i4,schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/binding/anyOf/0/properties/incarnation/anyOf/0/items/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err111];
}
else {
vErrors.push(err111);
}
errors++;
}
}
}
}
var valid23 = _errs143 === errors;
if(!valid23){
break;
}
}
}
}
}
else {
const err112 = {instancePath:instancePath+"/observation/processes/" + i0+"/binding/incarnation",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/binding/anyOf/0/properties/incarnation/anyOf/0/type",keyword:"type",params:{type: "array"},message:"must be array"};
if(vErrors === null){
vErrors = [err112];
}
else {
vErrors.push(err112);
}
errors++;
}
}
var _valid10 = _errs141 === errors;
valid22 = valid22 || _valid10;
const _errs145 = errors;
if(data47 !== null){
const err113 = {instancePath:instancePath+"/observation/processes/" + i0+"/binding/incarnation",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/binding/anyOf/0/properties/incarnation/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err113];
}
else {
vErrors.push(err113);
}
errors++;
}
var _valid10 = _errs145 === errors;
valid22 = valid22 || _valid10;
if(!valid22){
const err114 = {instancePath:instancePath+"/observation/processes/" + i0+"/binding/incarnation",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/binding/anyOf/0/properties/incarnation/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err114];
}
else {
vErrors.push(err114);
}
errors++;
}
else {
errors = _errs140;
if(vErrors !== null){
if(_errs140){
vErrors.length = _errs140;
}
else {
vErrors = null;
}
}
}
var valid18 = _errs139 === errors;
}
else {
var valid18 = true;
}
if(valid18){
if(data38.desired !== undefined){
let data49 = data38.desired;
const _errs147 = errors;
if(typeof data49 !== "string"){
const err115 = {instancePath:instancePath+"/observation/processes/" + i0+"/binding/desired",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/binding/anyOf/0/properties/desired/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err115];
}
else {
vErrors.push(err115);
}
errors++;
}
if(!((data49 === "running") || (data49 === "stopped"))){
const err116 = {instancePath:instancePath+"/observation/processes/" + i0+"/binding/desired",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/binding/anyOf/0/properties/desired/enum",keyword:"enum",params:{allowedValues: schema31.properties.observation.properties.processes.items.anyOf[0].properties.binding.anyOf[0].properties.desired.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err116];
}
else {
vErrors.push(err116);
}
errors++;
}
var valid18 = _errs147 === errors;
}
else {
var valid18 = true;
}
if(valid18){
if(data38.phase !== undefined){
let data50 = data38.phase;
const _errs149 = errors;
if(typeof data50 !== "string"){
const err117 = {instancePath:instancePath+"/observation/processes/" + i0+"/binding/phase",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/binding/anyOf/0/properties/phase/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err117];
}
else {
vErrors.push(err117);
}
errors++;
}
if(!((((data50 === "pending") || (data50 === "unknown")) || (data50 === "ready")) || (data50 === "stopped"))){
const err118 = {instancePath:instancePath+"/observation/processes/" + i0+"/binding/phase",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/binding/anyOf/0/properties/phase/enum",keyword:"enum",params:{allowedValues: schema31.properties.observation.properties.processes.items.anyOf[0].properties.binding.anyOf[0].properties.phase.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err118];
}
else {
vErrors.push(err118);
}
errors++;
}
var valid18 = _errs149 === errors;
}
else {
var valid18 = true;
}
if(valid18){
if(data38.activation !== undefined){
let data51 = data38.activation;
const _errs151 = errors;
const _errs152 = errors;
let valid24 = false;
const _errs153 = errors;
if(errors === _errs153){
if(data51 && typeof data51 == "object" && !Array.isArray(data51)){
let missing8;
if(((data51.worker_incarnation === undefined) && (missing8 = "worker_incarnation")) || ((data51.generation === undefined) && (missing8 = "generation"))){
const err119 = {instancePath:instancePath+"/observation/processes/" + i0+"/binding/activation",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/binding/anyOf/0/properties/activation/anyOf/0/required",keyword:"required",params:{missingProperty: missing8},message:"must have required property '"+missing8+"'"};
if(vErrors === null){
vErrors = [err119];
}
else {
vErrors.push(err119);
}
errors++;
}
else {
const _errs155 = errors;
for(const key8 in data51){
if(!((key8 === "worker_incarnation") || (key8 === "generation"))){
const err120 = {instancePath:instancePath+"/observation/processes/" + i0+"/binding/activation",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/binding/anyOf/0/properties/activation/anyOf/0/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key8},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err120];
}
else {
vErrors.push(err120);
}
errors++;
break;
}
}
if(_errs155 === errors){
if(data51.worker_incarnation !== undefined){
let data52 = data51.worker_incarnation;
const _errs156 = errors;
if(errors === _errs156){
if(Array.isArray(data52)){
if(data52.length > 16){
const err121 = {instancePath:instancePath+"/observation/processes/" + i0+"/binding/activation/worker_incarnation",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/binding/anyOf/0/properties/activation/anyOf/0/properties/worker_incarnation/maxItems",keyword:"maxItems",params:{limit: 16},message:"must NOT have more than 16 items"};
if(vErrors === null){
vErrors = [err121];
}
else {
vErrors.push(err121);
}
errors++;
}
else {
if(data52.length < 16){
const err122 = {instancePath:instancePath+"/observation/processes/" + i0+"/binding/activation/worker_incarnation",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/binding/anyOf/0/properties/activation/anyOf/0/properties/worker_incarnation/minItems",keyword:"minItems",params:{limit: 16},message:"must NOT have fewer than 16 items"};
if(vErrors === null){
vErrors = [err122];
}
else {
vErrors.push(err122);
}
errors++;
}
else {
var valid26 = true;
const len5 = data52.length;
for(let i5=0; i5<len5; i5++){
let data53 = data52[i5];
const _errs158 = errors;
if(!(((typeof data53 == "number") && (!(data53 % 1) && !isNaN(data53))) && (isFinite(data53)))){
const err123 = {instancePath:instancePath+"/observation/processes/" + i0+"/binding/activation/worker_incarnation/" + i5,schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/binding/anyOf/0/properties/activation/anyOf/0/properties/worker_incarnation/items/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err123];
}
else {
vErrors.push(err123);
}
errors++;
}
if(errors === _errs158){
if((typeof data53 == "number") && (isFinite(data53))){
if(data53 > 255 || isNaN(data53)){
const err124 = {instancePath:instancePath+"/observation/processes/" + i0+"/binding/activation/worker_incarnation/" + i5,schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/binding/anyOf/0/properties/activation/anyOf/0/properties/worker_incarnation/items/maximum",keyword:"maximum",params:{comparison: "<=", limit: 255},message:"must be <= 255"};
if(vErrors === null){
vErrors = [err124];
}
else {
vErrors.push(err124);
}
errors++;
}
else {
if(data53 < 0 || isNaN(data53)){
const err125 = {instancePath:instancePath+"/observation/processes/" + i0+"/binding/activation/worker_incarnation/" + i5,schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/binding/anyOf/0/properties/activation/anyOf/0/properties/worker_incarnation/items/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
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
var valid26 = _errs158 === errors;
if(!valid26){
break;
}
}
}
}
}
else {
const err126 = {instancePath:instancePath+"/observation/processes/" + i0+"/binding/activation/worker_incarnation",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/binding/anyOf/0/properties/activation/anyOf/0/properties/worker_incarnation/type",keyword:"type",params:{type: "array"},message:"must be array"};
if(vErrors === null){
vErrors = [err126];
}
else {
vErrors.push(err126);
}
errors++;
}
}
var valid25 = _errs156 === errors;
}
else {
var valid25 = true;
}
if(valid25){
if(data51.generation !== undefined){
let data54 = data51.generation;
const _errs160 = errors;
if(!(((typeof data54 == "number") && (!(data54 % 1) && !isNaN(data54))) && (isFinite(data54)))){
const err127 = {instancePath:instancePath+"/observation/processes/" + i0+"/binding/activation/generation",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/binding/anyOf/0/properties/activation/anyOf/0/properties/generation/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err127];
}
else {
vErrors.push(err127);
}
errors++;
}
if(errors === _errs160){
if((typeof data54 == "number") && (isFinite(data54))){
if(data54 > 9007199254740991 || isNaN(data54)){
const err128 = {instancePath:instancePath+"/observation/processes/" + i0+"/binding/activation/generation",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/binding/anyOf/0/properties/activation/anyOf/0/properties/generation/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"};
if(vErrors === null){
vErrors = [err128];
}
else {
vErrors.push(err128);
}
errors++;
}
else {
if(data54 < 0 || isNaN(data54)){
const err129 = {instancePath:instancePath+"/observation/processes/" + i0+"/binding/activation/generation",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/binding/anyOf/0/properties/activation/anyOf/0/properties/generation/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err129];
}
else {
vErrors.push(err129);
}
errors++;
}
}
}
}
var valid25 = _errs160 === errors;
}
else {
var valid25 = true;
}
}
}
}
}
else {
const err130 = {instancePath:instancePath+"/observation/processes/" + i0+"/binding/activation",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/binding/anyOf/0/properties/activation/anyOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err130];
}
else {
vErrors.push(err130);
}
errors++;
}
}
var _valid11 = _errs153 === errors;
valid24 = valid24 || _valid11;
const _errs162 = errors;
if(data51 !== null){
const err131 = {instancePath:instancePath+"/observation/processes/" + i0+"/binding/activation",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/binding/anyOf/0/properties/activation/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err131];
}
else {
vErrors.push(err131);
}
errors++;
}
var _valid11 = _errs162 === errors;
valid24 = valid24 || _valid11;
if(!valid24){
const err132 = {instancePath:instancePath+"/observation/processes/" + i0+"/binding/activation",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/binding/anyOf/0/properties/activation/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err132];
}
else {
vErrors.push(err132);
}
errors++;
}
else {
errors = _errs152;
if(vErrors !== null){
if(_errs152){
vErrors.length = _errs152;
}
else {
vErrors = null;
}
}
}
var valid18 = _errs151 === errors;
}
else {
var valid18 = true;
}
if(valid18){
if(data38.last_worker_incarnation !== undefined){
let data55 = data38.last_worker_incarnation;
const _errs164 = errors;
const _errs165 = errors;
let valid27 = false;
const _errs166 = errors;
if(errors === _errs166){
if(Array.isArray(data55)){
if(data55.length > 16){
const err133 = {instancePath:instancePath+"/observation/processes/" + i0+"/binding/last_worker_incarnation",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/binding/anyOf/0/properties/last_worker_incarnation/anyOf/0/maxItems",keyword:"maxItems",params:{limit: 16},message:"must NOT have more than 16 items"};
if(vErrors === null){
vErrors = [err133];
}
else {
vErrors.push(err133);
}
errors++;
}
else {
if(data55.length < 16){
const err134 = {instancePath:instancePath+"/observation/processes/" + i0+"/binding/last_worker_incarnation",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/binding/anyOf/0/properties/last_worker_incarnation/anyOf/0/minItems",keyword:"minItems",params:{limit: 16},message:"must NOT have fewer than 16 items"};
if(vErrors === null){
vErrors = [err134];
}
else {
vErrors.push(err134);
}
errors++;
}
else {
var valid28 = true;
const len6 = data55.length;
for(let i6=0; i6<len6; i6++){
let data56 = data55[i6];
const _errs168 = errors;
if(!(((typeof data56 == "number") && (!(data56 % 1) && !isNaN(data56))) && (isFinite(data56)))){
const err135 = {instancePath:instancePath+"/observation/processes/" + i0+"/binding/last_worker_incarnation/" + i6,schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/binding/anyOf/0/properties/last_worker_incarnation/anyOf/0/items/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err135];
}
else {
vErrors.push(err135);
}
errors++;
}
if(errors === _errs168){
if((typeof data56 == "number") && (isFinite(data56))){
if(data56 > 255 || isNaN(data56)){
const err136 = {instancePath:instancePath+"/observation/processes/" + i0+"/binding/last_worker_incarnation/" + i6,schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/binding/anyOf/0/properties/last_worker_incarnation/anyOf/0/items/maximum",keyword:"maximum",params:{comparison: "<=", limit: 255},message:"must be <= 255"};
if(vErrors === null){
vErrors = [err136];
}
else {
vErrors.push(err136);
}
errors++;
}
else {
if(data56 < 0 || isNaN(data56)){
const err137 = {instancePath:instancePath+"/observation/processes/" + i0+"/binding/last_worker_incarnation/" + i6,schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/binding/anyOf/0/properties/last_worker_incarnation/anyOf/0/items/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
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
var valid28 = _errs168 === errors;
if(!valid28){
break;
}
}
}
}
}
else {
const err138 = {instancePath:instancePath+"/observation/processes/" + i0+"/binding/last_worker_incarnation",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/binding/anyOf/0/properties/last_worker_incarnation/anyOf/0/type",keyword:"type",params:{type: "array"},message:"must be array"};
if(vErrors === null){
vErrors = [err138];
}
else {
vErrors.push(err138);
}
errors++;
}
}
var _valid12 = _errs166 === errors;
valid27 = valid27 || _valid12;
const _errs170 = errors;
if(data55 !== null){
const err139 = {instancePath:instancePath+"/observation/processes/" + i0+"/binding/last_worker_incarnation",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/binding/anyOf/0/properties/last_worker_incarnation/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err139];
}
else {
vErrors.push(err139);
}
errors++;
}
var _valid12 = _errs170 === errors;
valid27 = valid27 || _valid12;
if(!valid27){
const err140 = {instancePath:instancePath+"/observation/processes/" + i0+"/binding/last_worker_incarnation",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/binding/anyOf/0/properties/last_worker_incarnation/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err140];
}
else {
vErrors.push(err140);
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
var valid18 = _errs164 === errors;
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
}
}
}
}
}
else {
const err141 = {instancePath:instancePath+"/observation/processes/" + i0+"/binding",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/binding/anyOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err141];
}
else {
vErrors.push(err141);
}
errors++;
}
}
var _valid9 = _errs120 === errors;
valid17 = valid17 || _valid9;
const _errs172 = errors;
if(data38 !== null){
const err142 = {instancePath:instancePath+"/observation/processes/" + i0+"/binding",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/binding/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err142];
}
else {
vErrors.push(err142);
}
errors++;
}
var _valid9 = _errs172 === errors;
valid17 = valid17 || _valid9;
if(!valid17){
const err143 = {instancePath:instancePath+"/observation/processes/" + i0+"/binding",schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/properties/binding/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err143];
}
else {
vErrors.push(err143);
}
errors++;
}
else {
errors = _errs119;
if(vErrors !== null){
if(_errs119){
vErrors.length = _errs119;
}
else {
vErrors = null;
}
}
}
var valid9 = _errs118 === errors;
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
else {
const err144 = {instancePath:instancePath+"/observation/processes/" + i0,schemaPath:"#/properties/observation/properties/processes/items/anyOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err144];
}
else {
vErrors.push(err144);
}
errors++;
}
}
var _valid3 = _errs55 === errors;
valid8 = valid8 || _valid3;
const _errs174 = errors;
if(data18 !== null){
const err145 = {instancePath:instancePath+"/observation/processes/" + i0,schemaPath:"#/properties/observation/properties/processes/items/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err145];
}
else {
vErrors.push(err145);
}
errors++;
}
var _valid3 = _errs174 === errors;
valid8 = valid8 || _valid3;
if(!valid8){
const err146 = {instancePath:instancePath+"/observation/processes/" + i0,schemaPath:"#/properties/observation/properties/processes/items/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err146];
}
else {
vErrors.push(err146);
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
let data57 = data0.events;
const _errs176 = errors;
if(errors === _errs176){
if(Array.isArray(data57)){
if(data57.length > 16){
validate20.errors = [{instancePath:instancePath+"/observation/events",schemaPath:"#/properties/observation/properties/events/maxItems",keyword:"maxItems",params:{limit: 16},message:"must NOT have more than 16 items"}];
return false;
}
else {
if(data57.length < 16){
validate20.errors = [{instancePath:instancePath+"/observation/events",schemaPath:"#/properties/observation/properties/events/minItems",keyword:"minItems",params:{limit: 16},message:"must NOT have fewer than 16 items"}];
return false;
}
else {
var valid29 = true;
const len7 = data57.length;
for(let i7=0; i7<len7; i7++){
let data58 = data57[i7];
const _errs178 = errors;
const _errs179 = errors;
let valid30 = false;
const _errs180 = errors;
if(errors === _errs180){
if(data58 && typeof data58 == "object" && !Array.isArray(data58)){
let missing9;
if(((((((((((((((data58.position === undefined) && (missing9 = "position")) || ((data58.pid === undefined) && (missing9 = "pid"))) || ((data58.kind === undefined) && (missing9 = "kind"))) || ((data58.policy_revision === undefined) && (missing9 = "policy_revision"))) || ((data58.input === undefined) && (missing9 = "input"))) || ((data58.effect === undefined) && (missing9 = "effect"))) || ((data58.output === undefined) && (missing9 = "output"))) || ((data58.value === undefined) && (missing9 = "value"))) || ((data58.failed === undefined) && (missing9 = "failed"))) || ((data58.generation === undefined) && (missing9 = "generation"))) || ((data58.mailbox_status === undefined) && (missing9 = "mailbox_status"))) || ((data58.admitted === undefined) && (missing9 = "admitted"))) || ((data58.unix_ms === undefined) && (missing9 = "unix_ms"))) || ((data58.clock_error_ms === undefined) && (missing9 = "clock_error_ms"))){
const err147 = {instancePath:instancePath+"/observation/events/" + i7,schemaPath:"#/properties/observation/properties/events/items/anyOf/0/required",keyword:"required",params:{missingProperty: missing9},message:"must have required property '"+missing9+"'"};
if(vErrors === null){
vErrors = [err147];
}
else {
vErrors.push(err147);
}
errors++;
}
else {
const _errs182 = errors;
for(const key9 in data58){
if(!(func1.call(schema31.properties.observation.properties.events.items.anyOf[0].properties, key9))){
const err148 = {instancePath:instancePath+"/observation/events/" + i7,schemaPath:"#/properties/observation/properties/events/items/anyOf/0/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key9},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err148];
}
else {
vErrors.push(err148);
}
errors++;
break;
}
}
if(_errs182 === errors){
if(data58.position !== undefined){
let data59 = data58.position;
const _errs183 = errors;
if(!(((typeof data59 == "number") && (!(data59 % 1) && !isNaN(data59))) && (isFinite(data59)))){
const err149 = {instancePath:instancePath+"/observation/events/" + i7+"/position",schemaPath:"#/properties/observation/properties/events/items/anyOf/0/properties/position/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err149];
}
else {
vErrors.push(err149);
}
errors++;
}
if(errors === _errs183){
if((typeof data59 == "number") && (isFinite(data59))){
if(data59 > 9007199254740991 || isNaN(data59)){
const err150 = {instancePath:instancePath+"/observation/events/" + i7+"/position",schemaPath:"#/properties/observation/properties/events/items/anyOf/0/properties/position/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"};
if(vErrors === null){
vErrors = [err150];
}
else {
vErrors.push(err150);
}
errors++;
}
else {
if(data59 < 0 || isNaN(data59)){
const err151 = {instancePath:instancePath+"/observation/events/" + i7+"/position",schemaPath:"#/properties/observation/properties/events/items/anyOf/0/properties/position/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err151];
}
else {
vErrors.push(err151);
}
errors++;
}
}
}
}
var valid31 = _errs183 === errors;
}
else {
var valid31 = true;
}
if(valid31){
if(data58.pid !== undefined){
let data60 = data58.pid;
const _errs185 = errors;
if(!(((typeof data60 == "number") && (!(data60 % 1) && !isNaN(data60))) && (isFinite(data60)))){
const err152 = {instancePath:instancePath+"/observation/events/" + i7+"/pid",schemaPath:"#/properties/observation/properties/events/items/anyOf/0/properties/pid/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err152];
}
else {
vErrors.push(err152);
}
errors++;
}
if(errors === _errs185){
if((typeof data60 == "number") && (isFinite(data60))){
if(data60 > 9007199254740991 || isNaN(data60)){
const err153 = {instancePath:instancePath+"/observation/events/" + i7+"/pid",schemaPath:"#/properties/observation/properties/events/items/anyOf/0/properties/pid/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"};
if(vErrors === null){
vErrors = [err153];
}
else {
vErrors.push(err153);
}
errors++;
}
else {
if(data60 < 0 || isNaN(data60)){
const err154 = {instancePath:instancePath+"/observation/events/" + i7+"/pid",schemaPath:"#/properties/observation/properties/events/items/anyOf/0/properties/pid/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
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
var valid31 = _errs185 === errors;
}
else {
var valid31 = true;
}
if(valid31){
if(data58.kind !== undefined){
let data61 = data58.kind;
const _errs187 = errors;
if(typeof data61 !== "string"){
const err155 = {instancePath:instancePath+"/observation/events/" + i7+"/kind",schemaPath:"#/properties/observation/properties/events/items/anyOf/0/properties/kind/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err155];
}
else {
vErrors.push(err155);
}
errors++;
}
if(!((((((((((((((((((((((data61 === "grant") || (data61 === "revoke")) || (data61 === "spawn")) || (data61 === "own")) || (data61 === "runtime_intent")) || (data61 === "runtime_observe")) || (data61 === "activate")) || (data61 === "send")) || (data61 === "begin_turn")) || (data61 === "turn")) || (data61 === "deliver")) || (data61 === "dispatch")) || (data61 === "observe")) || (data61 === "close_effect")) || (data61 === "terminate")) || (data61 === "expire")) || (data61 === "inspect")) || (data61 === "checkpoint")) || (data61 === "declare_payload")) || (data61 === "payload_ready")) || (data61 === "retire_payload")) || (data61 === "payload_deleted"))){
const err156 = {instancePath:instancePath+"/observation/events/" + i7+"/kind",schemaPath:"#/properties/observation/properties/events/items/anyOf/0/properties/kind/enum",keyword:"enum",params:{allowedValues: schema31.properties.observation.properties.events.items.anyOf[0].properties.kind.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err156];
}
else {
vErrors.push(err156);
}
errors++;
}
var valid31 = _errs187 === errors;
}
else {
var valid31 = true;
}
if(valid31){
if(data58.policy_revision !== undefined){
let data62 = data58.policy_revision;
const _errs189 = errors;
if(!(((typeof data62 == "number") && (!(data62 % 1) && !isNaN(data62))) && (isFinite(data62)))){
const err157 = {instancePath:instancePath+"/observation/events/" + i7+"/policy_revision",schemaPath:"#/properties/observation/properties/events/items/anyOf/0/properties/policy_revision/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err157];
}
else {
vErrors.push(err157);
}
errors++;
}
if(errors === _errs189){
if((typeof data62 == "number") && (isFinite(data62))){
if(data62 > 9007199254740991 || isNaN(data62)){
const err158 = {instancePath:instancePath+"/observation/events/" + i7+"/policy_revision",schemaPath:"#/properties/observation/properties/events/items/anyOf/0/properties/policy_revision/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"};
if(vErrors === null){
vErrors = [err158];
}
else {
vErrors.push(err158);
}
errors++;
}
else {
if(data62 < 0 || isNaN(data62)){
const err159 = {instancePath:instancePath+"/observation/events/" + i7+"/policy_revision",schemaPath:"#/properties/observation/properties/events/items/anyOf/0/properties/policy_revision/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err159];
}
else {
vErrors.push(err159);
}
errors++;
}
}
}
}
var valid31 = _errs189 === errors;
}
else {
var valid31 = true;
}
if(valid31){
if(data58.input !== undefined){
let data63 = data58.input;
const _errs191 = errors;
const _errs192 = errors;
let valid32 = false;
const _errs193 = errors;
if(!(((typeof data63 == "number") && (!(data63 % 1) && !isNaN(data63))) && (isFinite(data63)))){
const err160 = {instancePath:instancePath+"/observation/events/" + i7+"/input",schemaPath:"#/properties/observation/properties/events/items/anyOf/0/properties/input/anyOf/0/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err160];
}
else {
vErrors.push(err160);
}
errors++;
}
if(errors === _errs193){
if((typeof data63 == "number") && (isFinite(data63))){
if(data63 > 9007199254740991 || isNaN(data63)){
const err161 = {instancePath:instancePath+"/observation/events/" + i7+"/input",schemaPath:"#/properties/observation/properties/events/items/anyOf/0/properties/input/anyOf/0/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"};
if(vErrors === null){
vErrors = [err161];
}
else {
vErrors.push(err161);
}
errors++;
}
else {
if(data63 < 0 || isNaN(data63)){
const err162 = {instancePath:instancePath+"/observation/events/" + i7+"/input",schemaPath:"#/properties/observation/properties/events/items/anyOf/0/properties/input/anyOf/0/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err162];
}
else {
vErrors.push(err162);
}
errors++;
}
}
}
}
var _valid14 = _errs193 === errors;
valid32 = valid32 || _valid14;
const _errs195 = errors;
if(data63 !== null){
const err163 = {instancePath:instancePath+"/observation/events/" + i7+"/input",schemaPath:"#/properties/observation/properties/events/items/anyOf/0/properties/input/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err163];
}
else {
vErrors.push(err163);
}
errors++;
}
var _valid14 = _errs195 === errors;
valid32 = valid32 || _valid14;
if(!valid32){
const err164 = {instancePath:instancePath+"/observation/events/" + i7+"/input",schemaPath:"#/properties/observation/properties/events/items/anyOf/0/properties/input/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err164];
}
else {
vErrors.push(err164);
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
var valid31 = _errs191 === errors;
}
else {
var valid31 = true;
}
if(valid31){
if(data58.effect !== undefined){
let data64 = data58.effect;
const _errs197 = errors;
const _errs198 = errors;
let valid33 = false;
const _errs199 = errors;
if(!(((typeof data64 == "number") && (!(data64 % 1) && !isNaN(data64))) && (isFinite(data64)))){
const err165 = {instancePath:instancePath+"/observation/events/" + i7+"/effect",schemaPath:"#/properties/observation/properties/events/items/anyOf/0/properties/effect/anyOf/0/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err165];
}
else {
vErrors.push(err165);
}
errors++;
}
if(errors === _errs199){
if((typeof data64 == "number") && (isFinite(data64))){
if(data64 > 9007199254740991 || isNaN(data64)){
const err166 = {instancePath:instancePath+"/observation/events/" + i7+"/effect",schemaPath:"#/properties/observation/properties/events/items/anyOf/0/properties/effect/anyOf/0/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"};
if(vErrors === null){
vErrors = [err166];
}
else {
vErrors.push(err166);
}
errors++;
}
else {
if(data64 < 0 || isNaN(data64)){
const err167 = {instancePath:instancePath+"/observation/events/" + i7+"/effect",schemaPath:"#/properties/observation/properties/events/items/anyOf/0/properties/effect/anyOf/0/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err167];
}
else {
vErrors.push(err167);
}
errors++;
}
}
}
}
var _valid15 = _errs199 === errors;
valid33 = valid33 || _valid15;
const _errs201 = errors;
if(data64 !== null){
const err168 = {instancePath:instancePath+"/observation/events/" + i7+"/effect",schemaPath:"#/properties/observation/properties/events/items/anyOf/0/properties/effect/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err168];
}
else {
vErrors.push(err168);
}
errors++;
}
var _valid15 = _errs201 === errors;
valid33 = valid33 || _valid15;
if(!valid33){
const err169 = {instancePath:instancePath+"/observation/events/" + i7+"/effect",schemaPath:"#/properties/observation/properties/events/items/anyOf/0/properties/effect/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
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
var valid31 = _errs197 === errors;
}
else {
var valid31 = true;
}
if(valid31){
if(data58.output !== undefined){
let data65 = data58.output;
const _errs203 = errors;
const _errs204 = errors;
let valid34 = false;
const _errs205 = errors;
if(!(((typeof data65 == "number") && (!(data65 % 1) && !isNaN(data65))) && (isFinite(data65)))){
const err170 = {instancePath:instancePath+"/observation/events/" + i7+"/output",schemaPath:"#/properties/observation/properties/events/items/anyOf/0/properties/output/anyOf/0/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err170];
}
else {
vErrors.push(err170);
}
errors++;
}
if(errors === _errs205){
if((typeof data65 == "number") && (isFinite(data65))){
if(data65 > 9007199254740991 || isNaN(data65)){
const err171 = {instancePath:instancePath+"/observation/events/" + i7+"/output",schemaPath:"#/properties/observation/properties/events/items/anyOf/0/properties/output/anyOf/0/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"};
if(vErrors === null){
vErrors = [err171];
}
else {
vErrors.push(err171);
}
errors++;
}
else {
if(data65 < 0 || isNaN(data65)){
const err172 = {instancePath:instancePath+"/observation/events/" + i7+"/output",schemaPath:"#/properties/observation/properties/events/items/anyOf/0/properties/output/anyOf/0/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err172];
}
else {
vErrors.push(err172);
}
errors++;
}
}
}
}
var _valid16 = _errs205 === errors;
valid34 = valid34 || _valid16;
const _errs207 = errors;
if(data65 !== null){
const err173 = {instancePath:instancePath+"/observation/events/" + i7+"/output",schemaPath:"#/properties/observation/properties/events/items/anyOf/0/properties/output/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err173];
}
else {
vErrors.push(err173);
}
errors++;
}
var _valid16 = _errs207 === errors;
valid34 = valid34 || _valid16;
if(!valid34){
const err174 = {instancePath:instancePath+"/observation/events/" + i7+"/output",schemaPath:"#/properties/observation/properties/events/items/anyOf/0/properties/output/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err174];
}
else {
vErrors.push(err174);
}
errors++;
}
else {
errors = _errs204;
if(vErrors !== null){
if(_errs204){
vErrors.length = _errs204;
}
else {
vErrors = null;
}
}
}
var valid31 = _errs203 === errors;
}
else {
var valid31 = true;
}
if(valid31){
if(data58.value !== undefined){
let data66 = data58.value;
const _errs209 = errors;
const _errs210 = errors;
let valid35 = false;
const _errs211 = errors;
if(errors === _errs211){
if(typeof data66 === "string"){
if(func3(data66) > 512){
const err175 = {instancePath:instancePath+"/observation/events/" + i7+"/value",schemaPath:"#/properties/observation/properties/events/items/anyOf/0/properties/value/anyOf/0/maxLength",keyword:"maxLength",params:{limit: 512},message:"must NOT have more than 512 characters"};
if(vErrors === null){
vErrors = [err175];
}
else {
vErrors.push(err175);
}
errors++;
}
else {
if(!pattern4.test(data66)){
const err176 = {instancePath:instancePath+"/observation/events/" + i7+"/value",schemaPath:"#/properties/observation/properties/events/items/anyOf/0/properties/value/anyOf/0/pattern",keyword:"pattern",params:{pattern: "^(?:[0-9a-f]{2})*$"},message:"must match pattern \""+"^(?:[0-9a-f]{2})*$"+"\""};
if(vErrors === null){
vErrors = [err176];
}
else {
vErrors.push(err176);
}
errors++;
}
}
}
else {
const err177 = {instancePath:instancePath+"/observation/events/" + i7+"/value",schemaPath:"#/properties/observation/properties/events/items/anyOf/0/properties/value/anyOf/0/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err177];
}
else {
vErrors.push(err177);
}
errors++;
}
}
var _valid17 = _errs211 === errors;
valid35 = valid35 || _valid17;
const _errs213 = errors;
if(data66 !== null){
const err178 = {instancePath:instancePath+"/observation/events/" + i7+"/value",schemaPath:"#/properties/observation/properties/events/items/anyOf/0/properties/value/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err178];
}
else {
vErrors.push(err178);
}
errors++;
}
var _valid17 = _errs213 === errors;
valid35 = valid35 || _valid17;
if(!valid35){
const err179 = {instancePath:instancePath+"/observation/events/" + i7+"/value",schemaPath:"#/properties/observation/properties/events/items/anyOf/0/properties/value/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err179];
}
else {
vErrors.push(err179);
}
errors++;
}
else {
errors = _errs210;
if(vErrors !== null){
if(_errs210){
vErrors.length = _errs210;
}
else {
vErrors = null;
}
}
}
var valid31 = _errs209 === errors;
}
else {
var valid31 = true;
}
if(valid31){
if(data58.failed !== undefined){
const _errs215 = errors;
if(typeof data58.failed !== "boolean"){
const err180 = {instancePath:instancePath+"/observation/events/" + i7+"/failed",schemaPath:"#/properties/observation/properties/events/items/anyOf/0/properties/failed/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"};
if(vErrors === null){
vErrors = [err180];
}
else {
vErrors.push(err180);
}
errors++;
}
var valid31 = _errs215 === errors;
}
else {
var valid31 = true;
}
if(valid31){
if(data58.generation !== undefined){
let data68 = data58.generation;
const _errs217 = errors;
const _errs218 = errors;
let valid36 = false;
const _errs219 = errors;
if(!(((typeof data68 == "number") && (!(data68 % 1) && !isNaN(data68))) && (isFinite(data68)))){
const err181 = {instancePath:instancePath+"/observation/events/" + i7+"/generation",schemaPath:"#/properties/observation/properties/events/items/anyOf/0/properties/generation/anyOf/0/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err181];
}
else {
vErrors.push(err181);
}
errors++;
}
if(errors === _errs219){
if((typeof data68 == "number") && (isFinite(data68))){
if(data68 > 9007199254740991 || isNaN(data68)){
const err182 = {instancePath:instancePath+"/observation/events/" + i7+"/generation",schemaPath:"#/properties/observation/properties/events/items/anyOf/0/properties/generation/anyOf/0/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"};
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
const err183 = {instancePath:instancePath+"/observation/events/" + i7+"/generation",schemaPath:"#/properties/observation/properties/events/items/anyOf/0/properties/generation/anyOf/0/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
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
var _valid18 = _errs219 === errors;
valid36 = valid36 || _valid18;
const _errs221 = errors;
if(data68 !== null){
const err184 = {instancePath:instancePath+"/observation/events/" + i7+"/generation",schemaPath:"#/properties/observation/properties/events/items/anyOf/0/properties/generation/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err184];
}
else {
vErrors.push(err184);
}
errors++;
}
var _valid18 = _errs221 === errors;
valid36 = valid36 || _valid18;
if(!valid36){
const err185 = {instancePath:instancePath+"/observation/events/" + i7+"/generation",schemaPath:"#/properties/observation/properties/events/items/anyOf/0/properties/generation/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err185];
}
else {
vErrors.push(err185);
}
errors++;
}
else {
errors = _errs218;
if(vErrors !== null){
if(_errs218){
vErrors.length = _errs218;
}
else {
vErrors = null;
}
}
}
var valid31 = _errs217 === errors;
}
else {
var valid31 = true;
}
if(valid31){
if(data58.mailbox_status !== undefined){
let data69 = data58.mailbox_status;
const _errs223 = errors;
const _errs224 = errors;
let valid37 = false;
const _errs225 = errors;
if(typeof data69 !== "string"){
const err186 = {instancePath:instancePath+"/observation/events/" + i7+"/mailbox_status",schemaPath:"#/properties/observation/properties/events/items/anyOf/0/properties/mailbox_status/anyOf/0/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err186];
}
else {
vErrors.push(err186);
}
errors++;
}
if(!(((data69 === "pending") || (data69 === "consumed")) || (data69 === "cancelled"))){
const err187 = {instancePath:instancePath+"/observation/events/" + i7+"/mailbox_status",schemaPath:"#/properties/observation/properties/events/items/anyOf/0/properties/mailbox_status/anyOf/0/enum",keyword:"enum",params:{allowedValues: schema31.properties.observation.properties.events.items.anyOf[0].properties.mailbox_status.anyOf[0].enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err187];
}
else {
vErrors.push(err187);
}
errors++;
}
var _valid19 = _errs225 === errors;
valid37 = valid37 || _valid19;
const _errs227 = errors;
if(data69 !== null){
const err188 = {instancePath:instancePath+"/observation/events/" + i7+"/mailbox_status",schemaPath:"#/properties/observation/properties/events/items/anyOf/0/properties/mailbox_status/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err188];
}
else {
vErrors.push(err188);
}
errors++;
}
var _valid19 = _errs227 === errors;
valid37 = valid37 || _valid19;
if(!valid37){
const err189 = {instancePath:instancePath+"/observation/events/" + i7+"/mailbox_status",schemaPath:"#/properties/observation/properties/events/items/anyOf/0/properties/mailbox_status/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err189];
}
else {
vErrors.push(err189);
}
errors++;
}
else {
errors = _errs224;
if(vErrors !== null){
if(_errs224){
vErrors.length = _errs224;
}
else {
vErrors = null;
}
}
}
var valid31 = _errs223 === errors;
}
else {
var valid31 = true;
}
if(valid31){
if(data58.admitted !== undefined){
const _errs229 = errors;
if(typeof data58.admitted !== "boolean"){
const err190 = {instancePath:instancePath+"/observation/events/" + i7+"/admitted",schemaPath:"#/properties/observation/properties/events/items/anyOf/0/properties/admitted/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"};
if(vErrors === null){
vErrors = [err190];
}
else {
vErrors.push(err190);
}
errors++;
}
var valid31 = _errs229 === errors;
}
else {
var valid31 = true;
}
if(valid31){
if(data58.unix_ms !== undefined){
let data71 = data58.unix_ms;
const _errs231 = errors;
const _errs232 = errors;
let valid38 = false;
const _errs233 = errors;
if(!(((typeof data71 == "number") && (!(data71 % 1) && !isNaN(data71))) && (isFinite(data71)))){
const err191 = {instancePath:instancePath+"/observation/events/" + i7+"/unix_ms",schemaPath:"#/properties/observation/properties/events/items/anyOf/0/properties/unix_ms/anyOf/0/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err191];
}
else {
vErrors.push(err191);
}
errors++;
}
if(errors === _errs233){
if((typeof data71 == "number") && (isFinite(data71))){
if(data71 > 9007199254740991 || isNaN(data71)){
const err192 = {instancePath:instancePath+"/observation/events/" + i7+"/unix_ms",schemaPath:"#/properties/observation/properties/events/items/anyOf/0/properties/unix_ms/anyOf/0/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"};
if(vErrors === null){
vErrors = [err192];
}
else {
vErrors.push(err192);
}
errors++;
}
else {
if(data71 < 0 || isNaN(data71)){
const err193 = {instancePath:instancePath+"/observation/events/" + i7+"/unix_ms",schemaPath:"#/properties/observation/properties/events/items/anyOf/0/properties/unix_ms/anyOf/0/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err193];
}
else {
vErrors.push(err193);
}
errors++;
}
}
}
}
var _valid20 = _errs233 === errors;
valid38 = valid38 || _valid20;
const _errs235 = errors;
if(data71 !== null){
const err194 = {instancePath:instancePath+"/observation/events/" + i7+"/unix_ms",schemaPath:"#/properties/observation/properties/events/items/anyOf/0/properties/unix_ms/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err194];
}
else {
vErrors.push(err194);
}
errors++;
}
var _valid20 = _errs235 === errors;
valid38 = valid38 || _valid20;
if(!valid38){
const err195 = {instancePath:instancePath+"/observation/events/" + i7+"/unix_ms",schemaPath:"#/properties/observation/properties/events/items/anyOf/0/properties/unix_ms/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err195];
}
else {
vErrors.push(err195);
}
errors++;
}
else {
errors = _errs232;
if(vErrors !== null){
if(_errs232){
vErrors.length = _errs232;
}
else {
vErrors = null;
}
}
}
var valid31 = _errs231 === errors;
}
else {
var valid31 = true;
}
if(valid31){
if(data58.clock_error_ms !== undefined){
let data72 = data58.clock_error_ms;
const _errs237 = errors;
const _errs238 = errors;
let valid39 = false;
const _errs239 = errors;
if(!(((typeof data72 == "number") && (!(data72 % 1) && !isNaN(data72))) && (isFinite(data72)))){
const err196 = {instancePath:instancePath+"/observation/events/" + i7+"/clock_error_ms",schemaPath:"#/properties/observation/properties/events/items/anyOf/0/properties/clock_error_ms/anyOf/0/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err196];
}
else {
vErrors.push(err196);
}
errors++;
}
if(errors === _errs239){
if((typeof data72 == "number") && (isFinite(data72))){
if(data72 > 4294967295 || isNaN(data72)){
const err197 = {instancePath:instancePath+"/observation/events/" + i7+"/clock_error_ms",schemaPath:"#/properties/observation/properties/events/items/anyOf/0/properties/clock_error_ms/anyOf/0/maximum",keyword:"maximum",params:{comparison: "<=", limit: 4294967295},message:"must be <= 4294967295"};
if(vErrors === null){
vErrors = [err197];
}
else {
vErrors.push(err197);
}
errors++;
}
else {
if(data72 < 0 || isNaN(data72)){
const err198 = {instancePath:instancePath+"/observation/events/" + i7+"/clock_error_ms",schemaPath:"#/properties/observation/properties/events/items/anyOf/0/properties/clock_error_ms/anyOf/0/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err198];
}
else {
vErrors.push(err198);
}
errors++;
}
}
}
}
var _valid21 = _errs239 === errors;
valid39 = valid39 || _valid21;
const _errs241 = errors;
if(data72 !== null){
const err199 = {instancePath:instancePath+"/observation/events/" + i7+"/clock_error_ms",schemaPath:"#/properties/observation/properties/events/items/anyOf/0/properties/clock_error_ms/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err199];
}
else {
vErrors.push(err199);
}
errors++;
}
var _valid21 = _errs241 === errors;
valid39 = valid39 || _valid21;
if(!valid39){
const err200 = {instancePath:instancePath+"/observation/events/" + i7+"/clock_error_ms",schemaPath:"#/properties/observation/properties/events/items/anyOf/0/properties/clock_error_ms/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err200];
}
else {
vErrors.push(err200);
}
errors++;
}
else {
errors = _errs238;
if(vErrors !== null){
if(_errs238){
vErrors.length = _errs238;
}
else {
vErrors = null;
}
}
}
var valid31 = _errs237 === errors;
}
else {
var valid31 = true;
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
const err201 = {instancePath:instancePath+"/observation/events/" + i7,schemaPath:"#/properties/observation/properties/events/items/anyOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err201];
}
else {
vErrors.push(err201);
}
errors++;
}
}
var _valid13 = _errs180 === errors;
valid30 = valid30 || _valid13;
const _errs243 = errors;
if(data58 !== null){
const err202 = {instancePath:instancePath+"/observation/events/" + i7,schemaPath:"#/properties/observation/properties/events/items/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err202];
}
else {
vErrors.push(err202);
}
errors++;
}
var _valid13 = _errs243 === errors;
valid30 = valid30 || _valid13;
if(!valid30){
const err203 = {instancePath:instancePath+"/observation/events/" + i7,schemaPath:"#/properties/observation/properties/events/items/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err203];
}
else {
vErrors.push(err203);
}
errors++;
validate20.errors = vErrors;
return false;
}
else {
errors = _errs179;
if(vErrors !== null){
if(_errs179){
vErrors.length = _errs179;
}
else {
vErrors = null;
}
}
}
var valid29 = _errs178 === errors;
if(!valid29){
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
var valid1 = _errs176 === errors;
}
else {
var valid1 = true;
}
if(valid1){
if(data0.outbox !== undefined){
let data73 = data0.outbox;
const _errs245 = errors;
if(errors === _errs245){
if(Array.isArray(data73)){
if(data73.length > 16){
validate20.errors = [{instancePath:instancePath+"/observation/outbox",schemaPath:"#/properties/observation/properties/outbox/maxItems",keyword:"maxItems",params:{limit: 16},message:"must NOT have more than 16 items"}];
return false;
}
else {
if(data73.length < 16){
validate20.errors = [{instancePath:instancePath+"/observation/outbox",schemaPath:"#/properties/observation/properties/outbox/minItems",keyword:"minItems",params:{limit: 16},message:"must NOT have fewer than 16 items"}];
return false;
}
else {
var valid40 = true;
const len8 = data73.length;
for(let i8=0; i8<len8; i8++){
let data74 = data73[i8];
const _errs247 = errors;
const _errs248 = errors;
let valid41 = false;
const _errs249 = errors;
if(errors === _errs249){
if(data74 && typeof data74 == "object" && !Array.isArray(data74)){
let missing10;
if(((((((((((data74.id === undefined) && (missing10 = "id")) || ((data74.source === undefined) && (missing10 = "source"))) || ((data74.turn === undefined) && (missing10 = "turn"))) || ((data74.index === undefined) && (missing10 = "index"))) || ((data74.destination === undefined) && (missing10 = "destination"))) || ((data74.value === undefined) && (missing10 = "value"))) || ((data74.phase === undefined) && (missing10 = "phase"))) || ((data74.resolved_at === undefined) && (missing10 = "resolved_at"))) || ((data74.courier === undefined) && (missing10 = "courier"))) || ((data74.policy_revision === undefined) && (missing10 = "policy_revision"))){
const err204 = {instancePath:instancePath+"/observation/outbox/" + i8,schemaPath:"#/properties/observation/properties/outbox/items/anyOf/0/required",keyword:"required",params:{missingProperty: missing10},message:"must have required property '"+missing10+"'"};
if(vErrors === null){
vErrors = [err204];
}
else {
vErrors.push(err204);
}
errors++;
}
else {
const _errs251 = errors;
for(const key10 in data74){
if(!(func1.call(schema31.properties.observation.properties.outbox.items.anyOf[0].properties, key10))){
const err205 = {instancePath:instancePath+"/observation/outbox/" + i8,schemaPath:"#/properties/observation/properties/outbox/items/anyOf/0/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key10},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err205];
}
else {
vErrors.push(err205);
}
errors++;
break;
}
}
if(_errs251 === errors){
if(data74.id !== undefined){
let data75 = data74.id;
const _errs252 = errors;
if(!(((typeof data75 == "number") && (!(data75 % 1) && !isNaN(data75))) && (isFinite(data75)))){
const err206 = {instancePath:instancePath+"/observation/outbox/" + i8+"/id",schemaPath:"#/properties/observation/properties/outbox/items/anyOf/0/properties/id/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err206];
}
else {
vErrors.push(err206);
}
errors++;
}
if(errors === _errs252){
if((typeof data75 == "number") && (isFinite(data75))){
if(data75 > 9007199254740991 || isNaN(data75)){
const err207 = {instancePath:instancePath+"/observation/outbox/" + i8+"/id",schemaPath:"#/properties/observation/properties/outbox/items/anyOf/0/properties/id/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"};
if(vErrors === null){
vErrors = [err207];
}
else {
vErrors.push(err207);
}
errors++;
}
else {
if(data75 < 0 || isNaN(data75)){
const err208 = {instancePath:instancePath+"/observation/outbox/" + i8+"/id",schemaPath:"#/properties/observation/properties/outbox/items/anyOf/0/properties/id/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err208];
}
else {
vErrors.push(err208);
}
errors++;
}
}
}
}
var valid42 = _errs252 === errors;
}
else {
var valid42 = true;
}
if(valid42){
if(data74.source !== undefined){
let data76 = data74.source;
const _errs254 = errors;
if(!(((typeof data76 == "number") && (!(data76 % 1) && !isNaN(data76))) && (isFinite(data76)))){
const err209 = {instancePath:instancePath+"/observation/outbox/" + i8+"/source",schemaPath:"#/properties/observation/properties/outbox/items/anyOf/0/properties/source/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err209];
}
else {
vErrors.push(err209);
}
errors++;
}
if(errors === _errs254){
if((typeof data76 == "number") && (isFinite(data76))){
if(data76 > 9007199254740991 || isNaN(data76)){
const err210 = {instancePath:instancePath+"/observation/outbox/" + i8+"/source",schemaPath:"#/properties/observation/properties/outbox/items/anyOf/0/properties/source/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"};
if(vErrors === null){
vErrors = [err210];
}
else {
vErrors.push(err210);
}
errors++;
}
else {
if(data76 < 0 || isNaN(data76)){
const err211 = {instancePath:instancePath+"/observation/outbox/" + i8+"/source",schemaPath:"#/properties/observation/properties/outbox/items/anyOf/0/properties/source/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err211];
}
else {
vErrors.push(err211);
}
errors++;
}
}
}
}
var valid42 = _errs254 === errors;
}
else {
var valid42 = true;
}
if(valid42){
if(data74.turn !== undefined){
let data77 = data74.turn;
const _errs256 = errors;
if(!(((typeof data77 == "number") && (!(data77 % 1) && !isNaN(data77))) && (isFinite(data77)))){
const err212 = {instancePath:instancePath+"/observation/outbox/" + i8+"/turn",schemaPath:"#/properties/observation/properties/outbox/items/anyOf/0/properties/turn/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err212];
}
else {
vErrors.push(err212);
}
errors++;
}
if(errors === _errs256){
if((typeof data77 == "number") && (isFinite(data77))){
if(data77 > 9007199254740991 || isNaN(data77)){
const err213 = {instancePath:instancePath+"/observation/outbox/" + i8+"/turn",schemaPath:"#/properties/observation/properties/outbox/items/anyOf/0/properties/turn/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"};
if(vErrors === null){
vErrors = [err213];
}
else {
vErrors.push(err213);
}
errors++;
}
else {
if(data77 < 0 || isNaN(data77)){
const err214 = {instancePath:instancePath+"/observation/outbox/" + i8+"/turn",schemaPath:"#/properties/observation/properties/outbox/items/anyOf/0/properties/turn/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err214];
}
else {
vErrors.push(err214);
}
errors++;
}
}
}
}
var valid42 = _errs256 === errors;
}
else {
var valid42 = true;
}
if(valid42){
if(data74.index !== undefined){
let data78 = data74.index;
const _errs258 = errors;
if(!(((typeof data78 == "number") && (!(data78 % 1) && !isNaN(data78))) && (isFinite(data78)))){
const err215 = {instancePath:instancePath+"/observation/outbox/" + i8+"/index",schemaPath:"#/properties/observation/properties/outbox/items/anyOf/0/properties/index/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err215];
}
else {
vErrors.push(err215);
}
errors++;
}
if(errors === _errs258){
if((typeof data78 == "number") && (isFinite(data78))){
if(data78 > 255 || isNaN(data78)){
const err216 = {instancePath:instancePath+"/observation/outbox/" + i8+"/index",schemaPath:"#/properties/observation/properties/outbox/items/anyOf/0/properties/index/maximum",keyword:"maximum",params:{comparison: "<=", limit: 255},message:"must be <= 255"};
if(vErrors === null){
vErrors = [err216];
}
else {
vErrors.push(err216);
}
errors++;
}
else {
if(data78 < 0 || isNaN(data78)){
const err217 = {instancePath:instancePath+"/observation/outbox/" + i8+"/index",schemaPath:"#/properties/observation/properties/outbox/items/anyOf/0/properties/index/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err217];
}
else {
vErrors.push(err217);
}
errors++;
}
}
}
}
var valid42 = _errs258 === errors;
}
else {
var valid42 = true;
}
if(valid42){
if(data74.destination !== undefined){
let data79 = data74.destination;
const _errs260 = errors;
if(!(((typeof data79 == "number") && (!(data79 % 1) && !isNaN(data79))) && (isFinite(data79)))){
const err218 = {instancePath:instancePath+"/observation/outbox/" + i8+"/destination",schemaPath:"#/properties/observation/properties/outbox/items/anyOf/0/properties/destination/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err218];
}
else {
vErrors.push(err218);
}
errors++;
}
if(errors === _errs260){
if((typeof data79 == "number") && (isFinite(data79))){
if(data79 > 9007199254740991 || isNaN(data79)){
const err219 = {instancePath:instancePath+"/observation/outbox/" + i8+"/destination",schemaPath:"#/properties/observation/properties/outbox/items/anyOf/0/properties/destination/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"};
if(vErrors === null){
vErrors = [err219];
}
else {
vErrors.push(err219);
}
errors++;
}
else {
if(data79 < 0 || isNaN(data79)){
const err220 = {instancePath:instancePath+"/observation/outbox/" + i8+"/destination",schemaPath:"#/properties/observation/properties/outbox/items/anyOf/0/properties/destination/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err220];
}
else {
vErrors.push(err220);
}
errors++;
}
}
}
}
var valid42 = _errs260 === errors;
}
else {
var valid42 = true;
}
if(valid42){
if(data74.value !== undefined){
let data80 = data74.value;
const _errs262 = errors;
if(errors === _errs262){
if(typeof data80 === "string"){
if(func3(data80) > 512){
const err221 = {instancePath:instancePath+"/observation/outbox/" + i8+"/value",schemaPath:"#/properties/observation/properties/outbox/items/anyOf/0/properties/value/maxLength",keyword:"maxLength",params:{limit: 512},message:"must NOT have more than 512 characters"};
if(vErrors === null){
vErrors = [err221];
}
else {
vErrors.push(err221);
}
errors++;
}
else {
if(!pattern4.test(data80)){
const err222 = {instancePath:instancePath+"/observation/outbox/" + i8+"/value",schemaPath:"#/properties/observation/properties/outbox/items/anyOf/0/properties/value/pattern",keyword:"pattern",params:{pattern: "^(?:[0-9a-f]{2})*$"},message:"must match pattern \""+"^(?:[0-9a-f]{2})*$"+"\""};
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
else {
const err223 = {instancePath:instancePath+"/observation/outbox/" + i8+"/value",schemaPath:"#/properties/observation/properties/outbox/items/anyOf/0/properties/value/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err223];
}
else {
vErrors.push(err223);
}
errors++;
}
}
var valid42 = _errs262 === errors;
}
else {
var valid42 = true;
}
if(valid42){
if(data74.phase !== undefined){
let data81 = data74.phase;
const _errs264 = errors;
if(typeof data81 !== "string"){
const err224 = {instancePath:instancePath+"/observation/outbox/" + i8+"/phase",schemaPath:"#/properties/observation/properties/outbox/items/anyOf/0/properties/phase/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err224];
}
else {
vErrors.push(err224);
}
errors++;
}
if(!((((((data81 === "pending") || (data81 === "delivered")) || (data81 === "denied")) || (data81 === "expired")) || (data81 === "retired")) || (data81 === "cancelled"))){
const err225 = {instancePath:instancePath+"/observation/outbox/" + i8+"/phase",schemaPath:"#/properties/observation/properties/outbox/items/anyOf/0/properties/phase/enum",keyword:"enum",params:{allowedValues: schema31.properties.observation.properties.outbox.items.anyOf[0].properties.phase.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err225];
}
else {
vErrors.push(err225);
}
errors++;
}
var valid42 = _errs264 === errors;
}
else {
var valid42 = true;
}
if(valid42){
if(data74.resolved_at !== undefined){
let data82 = data74.resolved_at;
const _errs266 = errors;
const _errs267 = errors;
let valid43 = false;
const _errs268 = errors;
if(!(((typeof data82 == "number") && (!(data82 % 1) && !isNaN(data82))) && (isFinite(data82)))){
const err226 = {instancePath:instancePath+"/observation/outbox/" + i8+"/resolved_at",schemaPath:"#/properties/observation/properties/outbox/items/anyOf/0/properties/resolved_at/anyOf/0/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err226];
}
else {
vErrors.push(err226);
}
errors++;
}
if(errors === _errs268){
if((typeof data82 == "number") && (isFinite(data82))){
if(data82 > 9007199254740991 || isNaN(data82)){
const err227 = {instancePath:instancePath+"/observation/outbox/" + i8+"/resolved_at",schemaPath:"#/properties/observation/properties/outbox/items/anyOf/0/properties/resolved_at/anyOf/0/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"};
if(vErrors === null){
vErrors = [err227];
}
else {
vErrors.push(err227);
}
errors++;
}
else {
if(data82 < 0 || isNaN(data82)){
const err228 = {instancePath:instancePath+"/observation/outbox/" + i8+"/resolved_at",schemaPath:"#/properties/observation/properties/outbox/items/anyOf/0/properties/resolved_at/anyOf/0/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err228];
}
else {
vErrors.push(err228);
}
errors++;
}
}
}
}
var _valid23 = _errs268 === errors;
valid43 = valid43 || _valid23;
const _errs270 = errors;
if(data82 !== null){
const err229 = {instancePath:instancePath+"/observation/outbox/" + i8+"/resolved_at",schemaPath:"#/properties/observation/properties/outbox/items/anyOf/0/properties/resolved_at/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err229];
}
else {
vErrors.push(err229);
}
errors++;
}
var _valid23 = _errs270 === errors;
valid43 = valid43 || _valid23;
if(!valid43){
const err230 = {instancePath:instancePath+"/observation/outbox/" + i8+"/resolved_at",schemaPath:"#/properties/observation/properties/outbox/items/anyOf/0/properties/resolved_at/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err230];
}
else {
vErrors.push(err230);
}
errors++;
}
else {
errors = _errs267;
if(vErrors !== null){
if(_errs267){
vErrors.length = _errs267;
}
else {
vErrors = null;
}
}
}
var valid42 = _errs266 === errors;
}
else {
var valid42 = true;
}
if(valid42){
if(data74.courier !== undefined){
let data83 = data74.courier;
const _errs272 = errors;
const _errs273 = errors;
let valid44 = false;
const _errs274 = errors;
if(!(((typeof data83 == "number") && (!(data83 % 1) && !isNaN(data83))) && (isFinite(data83)))){
const err231 = {instancePath:instancePath+"/observation/outbox/" + i8+"/courier",schemaPath:"#/properties/observation/properties/outbox/items/anyOf/0/properties/courier/anyOf/0/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err231];
}
else {
vErrors.push(err231);
}
errors++;
}
if(errors === _errs274){
if((typeof data83 == "number") && (isFinite(data83))){
if(data83 > 255 || isNaN(data83)){
const err232 = {instancePath:instancePath+"/observation/outbox/" + i8+"/courier",schemaPath:"#/properties/observation/properties/outbox/items/anyOf/0/properties/courier/anyOf/0/maximum",keyword:"maximum",params:{comparison: "<=", limit: 255},message:"must be <= 255"};
if(vErrors === null){
vErrors = [err232];
}
else {
vErrors.push(err232);
}
errors++;
}
else {
if(data83 < 0 || isNaN(data83)){
const err233 = {instancePath:instancePath+"/observation/outbox/" + i8+"/courier",schemaPath:"#/properties/observation/properties/outbox/items/anyOf/0/properties/courier/anyOf/0/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err233];
}
else {
vErrors.push(err233);
}
errors++;
}
}
}
}
var _valid24 = _errs274 === errors;
valid44 = valid44 || _valid24;
const _errs276 = errors;
if(data83 !== null){
const err234 = {instancePath:instancePath+"/observation/outbox/" + i8+"/courier",schemaPath:"#/properties/observation/properties/outbox/items/anyOf/0/properties/courier/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err234];
}
else {
vErrors.push(err234);
}
errors++;
}
var _valid24 = _errs276 === errors;
valid44 = valid44 || _valid24;
if(!valid44){
const err235 = {instancePath:instancePath+"/observation/outbox/" + i8+"/courier",schemaPath:"#/properties/observation/properties/outbox/items/anyOf/0/properties/courier/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err235];
}
else {
vErrors.push(err235);
}
errors++;
}
else {
errors = _errs273;
if(vErrors !== null){
if(_errs273){
vErrors.length = _errs273;
}
else {
vErrors = null;
}
}
}
var valid42 = _errs272 === errors;
}
else {
var valid42 = true;
}
if(valid42){
if(data74.policy_revision !== undefined){
let data84 = data74.policy_revision;
const _errs278 = errors;
const _errs279 = errors;
let valid45 = false;
const _errs280 = errors;
if(!(((typeof data84 == "number") && (!(data84 % 1) && !isNaN(data84))) && (isFinite(data84)))){
const err236 = {instancePath:instancePath+"/observation/outbox/" + i8+"/policy_revision",schemaPath:"#/properties/observation/properties/outbox/items/anyOf/0/properties/policy_revision/anyOf/0/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err236];
}
else {
vErrors.push(err236);
}
errors++;
}
if(errors === _errs280){
if((typeof data84 == "number") && (isFinite(data84))){
if(data84 > 9007199254740991 || isNaN(data84)){
const err237 = {instancePath:instancePath+"/observation/outbox/" + i8+"/policy_revision",schemaPath:"#/properties/observation/properties/outbox/items/anyOf/0/properties/policy_revision/anyOf/0/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"};
if(vErrors === null){
vErrors = [err237];
}
else {
vErrors.push(err237);
}
errors++;
}
else {
if(data84 < 0 || isNaN(data84)){
const err238 = {instancePath:instancePath+"/observation/outbox/" + i8+"/policy_revision",schemaPath:"#/properties/observation/properties/outbox/items/anyOf/0/properties/policy_revision/anyOf/0/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err238];
}
else {
vErrors.push(err238);
}
errors++;
}
}
}
}
var _valid25 = _errs280 === errors;
valid45 = valid45 || _valid25;
const _errs282 = errors;
if(data84 !== null){
const err239 = {instancePath:instancePath+"/observation/outbox/" + i8+"/policy_revision",schemaPath:"#/properties/observation/properties/outbox/items/anyOf/0/properties/policy_revision/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err239];
}
else {
vErrors.push(err239);
}
errors++;
}
var _valid25 = _errs282 === errors;
valid45 = valid45 || _valid25;
if(!valid45){
const err240 = {instancePath:instancePath+"/observation/outbox/" + i8+"/policy_revision",schemaPath:"#/properties/observation/properties/outbox/items/anyOf/0/properties/policy_revision/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err240];
}
else {
vErrors.push(err240);
}
errors++;
}
else {
errors = _errs279;
if(vErrors !== null){
if(_errs279){
vErrors.length = _errs279;
}
else {
vErrors = null;
}
}
}
var valid42 = _errs278 === errors;
}
else {
var valid42 = true;
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
const err241 = {instancePath:instancePath+"/observation/outbox/" + i8,schemaPath:"#/properties/observation/properties/outbox/items/anyOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err241];
}
else {
vErrors.push(err241);
}
errors++;
}
}
var _valid22 = _errs249 === errors;
valid41 = valid41 || _valid22;
const _errs284 = errors;
if(data74 !== null){
const err242 = {instancePath:instancePath+"/observation/outbox/" + i8,schemaPath:"#/properties/observation/properties/outbox/items/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err242];
}
else {
vErrors.push(err242);
}
errors++;
}
var _valid22 = _errs284 === errors;
valid41 = valid41 || _valid22;
if(!valid41){
const err243 = {instancePath:instancePath+"/observation/outbox/" + i8,schemaPath:"#/properties/observation/properties/outbox/items/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err243];
}
else {
vErrors.push(err243);
}
errors++;
validate20.errors = vErrors;
return false;
}
else {
errors = _errs248;
if(vErrors !== null){
if(_errs248){
vErrors.length = _errs248;
}
else {
vErrors = null;
}
}
}
var valid40 = _errs247 === errors;
if(!valid40){
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
var valid1 = _errs245 === errors;
}
else {
var valid1 = true;
}
if(valid1){
if(data0.effects !== undefined){
let data85 = data0.effects;
const _errs286 = errors;
if(errors === _errs286){
if(Array.isArray(data85)){
if(data85.length > 16){
validate20.errors = [{instancePath:instancePath+"/observation/effects",schemaPath:"#/properties/observation/properties/effects/maxItems",keyword:"maxItems",params:{limit: 16},message:"must NOT have more than 16 items"}];
return false;
}
else {
if(data85.length < 16){
validate20.errors = [{instancePath:instancePath+"/observation/effects",schemaPath:"#/properties/observation/properties/effects/minItems",keyword:"minItems",params:{limit: 16},message:"must NOT have fewer than 16 items"}];
return false;
}
else {
var valid46 = true;
const len9 = data85.length;
for(let i9=0; i9<len9; i9++){
let data86 = data85[i9];
const _errs288 = errors;
const _errs289 = errors;
let valid47 = false;
const _errs290 = errors;
if(errors === _errs290){
if(data86 && typeof data86 == "object" && !Array.isArray(data86)){
let missing11;
if((((((((((((data86.id === undefined) && (missing11 = "id")) || ((data86.pid === undefined) && (missing11 = "pid"))) || ((data86.payload === undefined) && (missing11 = "payload"))) || ((data86.phase === undefined) && (missing11 = "phase"))) || ((data86.attempt === undefined) && (missing11 = "attempt"))) || ((data86.executor === undefined) && (missing11 = "executor"))) || ((data86.result === undefined) && (missing11 = "result"))) || ((data86.closed_at === undefined) && (missing11 = "closed_at"))) || ((data86.reconcile_before_ms === undefined) && (missing11 = "reconcile_before_ms"))) || ((data86.max_observations === undefined) && (missing11 = "max_observations"))) || ((data86.observations === undefined) && (missing11 = "observations"))){
const err244 = {instancePath:instancePath+"/observation/effects/" + i9,schemaPath:"#/properties/observation/properties/effects/items/anyOf/0/required",keyword:"required",params:{missingProperty: missing11},message:"must have required property '"+missing11+"'"};
if(vErrors === null){
vErrors = [err244];
}
else {
vErrors.push(err244);
}
errors++;
}
else {
const _errs292 = errors;
for(const key11 in data86){
if(!(func1.call(schema31.properties.observation.properties.effects.items.anyOf[0].properties, key11))){
const err245 = {instancePath:instancePath+"/observation/effects/" + i9,schemaPath:"#/properties/observation/properties/effects/items/anyOf/0/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key11},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err245];
}
else {
vErrors.push(err245);
}
errors++;
break;
}
}
if(_errs292 === errors){
if(data86.id !== undefined){
let data87 = data86.id;
const _errs293 = errors;
if(!(((typeof data87 == "number") && (!(data87 % 1) && !isNaN(data87))) && (isFinite(data87)))){
const err246 = {instancePath:instancePath+"/observation/effects/" + i9+"/id",schemaPath:"#/properties/observation/properties/effects/items/anyOf/0/properties/id/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err246];
}
else {
vErrors.push(err246);
}
errors++;
}
if(errors === _errs293){
if((typeof data87 == "number") && (isFinite(data87))){
if(data87 > 9007199254740991 || isNaN(data87)){
const err247 = {instancePath:instancePath+"/observation/effects/" + i9+"/id",schemaPath:"#/properties/observation/properties/effects/items/anyOf/0/properties/id/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"};
if(vErrors === null){
vErrors = [err247];
}
else {
vErrors.push(err247);
}
errors++;
}
else {
if(data87 < 0 || isNaN(data87)){
const err248 = {instancePath:instancePath+"/observation/effects/" + i9+"/id",schemaPath:"#/properties/observation/properties/effects/items/anyOf/0/properties/id/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err248];
}
else {
vErrors.push(err248);
}
errors++;
}
}
}
}
var valid48 = _errs293 === errors;
}
else {
var valid48 = true;
}
if(valid48){
if(data86.pid !== undefined){
let data88 = data86.pid;
const _errs295 = errors;
if(!(((typeof data88 == "number") && (!(data88 % 1) && !isNaN(data88))) && (isFinite(data88)))){
const err249 = {instancePath:instancePath+"/observation/effects/" + i9+"/pid",schemaPath:"#/properties/observation/properties/effects/items/anyOf/0/properties/pid/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err249];
}
else {
vErrors.push(err249);
}
errors++;
}
if(errors === _errs295){
if((typeof data88 == "number") && (isFinite(data88))){
if(data88 > 9007199254740991 || isNaN(data88)){
const err250 = {instancePath:instancePath+"/observation/effects/" + i9+"/pid",schemaPath:"#/properties/observation/properties/effects/items/anyOf/0/properties/pid/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"};
if(vErrors === null){
vErrors = [err250];
}
else {
vErrors.push(err250);
}
errors++;
}
else {
if(data88 < 0 || isNaN(data88)){
const err251 = {instancePath:instancePath+"/observation/effects/" + i9+"/pid",schemaPath:"#/properties/observation/properties/effects/items/anyOf/0/properties/pid/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
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
}
var valid48 = _errs295 === errors;
}
else {
var valid48 = true;
}
if(valid48){
if(data86.payload !== undefined){
let data89 = data86.payload;
const _errs297 = errors;
if(errors === _errs297){
if(typeof data89 === "string"){
if(func3(data89) > 512){
const err252 = {instancePath:instancePath+"/observation/effects/" + i9+"/payload",schemaPath:"#/properties/observation/properties/effects/items/anyOf/0/properties/payload/maxLength",keyword:"maxLength",params:{limit: 512},message:"must NOT have more than 512 characters"};
if(vErrors === null){
vErrors = [err252];
}
else {
vErrors.push(err252);
}
errors++;
}
else {
if(!pattern4.test(data89)){
const err253 = {instancePath:instancePath+"/observation/effects/" + i9+"/payload",schemaPath:"#/properties/observation/properties/effects/items/anyOf/0/properties/payload/pattern",keyword:"pattern",params:{pattern: "^(?:[0-9a-f]{2})*$"},message:"must match pattern \""+"^(?:[0-9a-f]{2})*$"+"\""};
if(vErrors === null){
vErrors = [err253];
}
else {
vErrors.push(err253);
}
errors++;
}
}
}
else {
const err254 = {instancePath:instancePath+"/observation/effects/" + i9+"/payload",schemaPath:"#/properties/observation/properties/effects/items/anyOf/0/properties/payload/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err254];
}
else {
vErrors.push(err254);
}
errors++;
}
}
var valid48 = _errs297 === errors;
}
else {
var valid48 = true;
}
if(valid48){
if(data86.phase !== undefined){
let data90 = data86.phase;
const _errs299 = errors;
if(typeof data90 !== "string"){
const err255 = {instancePath:instancePath+"/observation/effects/" + i9+"/phase",schemaPath:"#/properties/observation/properties/effects/items/anyOf/0/properties/phase/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err255];
}
else {
vErrors.push(err255);
}
errors++;
}
if(!((((((data90 === "pending") || (data90 === "authorized")) || (data90 === "unknown")) || (data90 === "observed")) || (data90 === "cancelled")) || (data90 === "closed_unknown"))){
const err256 = {instancePath:instancePath+"/observation/effects/" + i9+"/phase",schemaPath:"#/properties/observation/properties/effects/items/anyOf/0/properties/phase/enum",keyword:"enum",params:{allowedValues: schema31.properties.observation.properties.effects.items.anyOf[0].properties.phase.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err256];
}
else {
vErrors.push(err256);
}
errors++;
}
var valid48 = _errs299 === errors;
}
else {
var valid48 = true;
}
if(valid48){
if(data86.attempt !== undefined){
let data91 = data86.attempt;
const _errs301 = errors;
const _errs302 = errors;
let valid49 = false;
const _errs303 = errors;
if(!(((typeof data91 == "number") && (!(data91 % 1) && !isNaN(data91))) && (isFinite(data91)))){
const err257 = {instancePath:instancePath+"/observation/effects/" + i9+"/attempt",schemaPath:"#/properties/observation/properties/effects/items/anyOf/0/properties/attempt/anyOf/0/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err257];
}
else {
vErrors.push(err257);
}
errors++;
}
if(errors === _errs303){
if((typeof data91 == "number") && (isFinite(data91))){
if(data91 > 9007199254740991 || isNaN(data91)){
const err258 = {instancePath:instancePath+"/observation/effects/" + i9+"/attempt",schemaPath:"#/properties/observation/properties/effects/items/anyOf/0/properties/attempt/anyOf/0/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"};
if(vErrors === null){
vErrors = [err258];
}
else {
vErrors.push(err258);
}
errors++;
}
else {
if(data91 < 0 || isNaN(data91)){
const err259 = {instancePath:instancePath+"/observation/effects/" + i9+"/attempt",schemaPath:"#/properties/observation/properties/effects/items/anyOf/0/properties/attempt/anyOf/0/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err259];
}
else {
vErrors.push(err259);
}
errors++;
}
}
}
}
var _valid27 = _errs303 === errors;
valid49 = valid49 || _valid27;
const _errs305 = errors;
if(data91 !== null){
const err260 = {instancePath:instancePath+"/observation/effects/" + i9+"/attempt",schemaPath:"#/properties/observation/properties/effects/items/anyOf/0/properties/attempt/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err260];
}
else {
vErrors.push(err260);
}
errors++;
}
var _valid27 = _errs305 === errors;
valid49 = valid49 || _valid27;
if(!valid49){
const err261 = {instancePath:instancePath+"/observation/effects/" + i9+"/attempt",schemaPath:"#/properties/observation/properties/effects/items/anyOf/0/properties/attempt/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err261];
}
else {
vErrors.push(err261);
}
errors++;
}
else {
errors = _errs302;
if(vErrors !== null){
if(_errs302){
vErrors.length = _errs302;
}
else {
vErrors = null;
}
}
}
var valid48 = _errs301 === errors;
}
else {
var valid48 = true;
}
if(valid48){
if(data86.executor !== undefined){
let data92 = data86.executor;
const _errs307 = errors;
const _errs308 = errors;
let valid50 = false;
const _errs309 = errors;
if(!(((typeof data92 == "number") && (!(data92 % 1) && !isNaN(data92))) && (isFinite(data92)))){
const err262 = {instancePath:instancePath+"/observation/effects/" + i9+"/executor",schemaPath:"#/properties/observation/properties/effects/items/anyOf/0/properties/executor/anyOf/0/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err262];
}
else {
vErrors.push(err262);
}
errors++;
}
if(errors === _errs309){
if((typeof data92 == "number") && (isFinite(data92))){
if(data92 > 255 || isNaN(data92)){
const err263 = {instancePath:instancePath+"/observation/effects/" + i9+"/executor",schemaPath:"#/properties/observation/properties/effects/items/anyOf/0/properties/executor/anyOf/0/maximum",keyword:"maximum",params:{comparison: "<=", limit: 255},message:"must be <= 255"};
if(vErrors === null){
vErrors = [err263];
}
else {
vErrors.push(err263);
}
errors++;
}
else {
if(data92 < 0 || isNaN(data92)){
const err264 = {instancePath:instancePath+"/observation/effects/" + i9+"/executor",schemaPath:"#/properties/observation/properties/effects/items/anyOf/0/properties/executor/anyOf/0/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err264];
}
else {
vErrors.push(err264);
}
errors++;
}
}
}
}
var _valid28 = _errs309 === errors;
valid50 = valid50 || _valid28;
const _errs311 = errors;
if(data92 !== null){
const err265 = {instancePath:instancePath+"/observation/effects/" + i9+"/executor",schemaPath:"#/properties/observation/properties/effects/items/anyOf/0/properties/executor/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err265];
}
else {
vErrors.push(err265);
}
errors++;
}
var _valid28 = _errs311 === errors;
valid50 = valid50 || _valid28;
if(!valid50){
const err266 = {instancePath:instancePath+"/observation/effects/" + i9+"/executor",schemaPath:"#/properties/observation/properties/effects/items/anyOf/0/properties/executor/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err266];
}
else {
vErrors.push(err266);
}
errors++;
}
else {
errors = _errs308;
if(vErrors !== null){
if(_errs308){
vErrors.length = _errs308;
}
else {
vErrors = null;
}
}
}
var valid48 = _errs307 === errors;
}
else {
var valid48 = true;
}
if(valid48){
if(data86.result !== undefined){
let data93 = data86.result;
const _errs313 = errors;
const _errs314 = errors;
let valid51 = false;
const _errs315 = errors;
if(errors === _errs315){
if(typeof data93 === "string"){
if(func3(data93) > 512){
const err267 = {instancePath:instancePath+"/observation/effects/" + i9+"/result",schemaPath:"#/properties/observation/properties/effects/items/anyOf/0/properties/result/anyOf/0/maxLength",keyword:"maxLength",params:{limit: 512},message:"must NOT have more than 512 characters"};
if(vErrors === null){
vErrors = [err267];
}
else {
vErrors.push(err267);
}
errors++;
}
else {
if(!pattern4.test(data93)){
const err268 = {instancePath:instancePath+"/observation/effects/" + i9+"/result",schemaPath:"#/properties/observation/properties/effects/items/anyOf/0/properties/result/anyOf/0/pattern",keyword:"pattern",params:{pattern: "^(?:[0-9a-f]{2})*$"},message:"must match pattern \""+"^(?:[0-9a-f]{2})*$"+"\""};
if(vErrors === null){
vErrors = [err268];
}
else {
vErrors.push(err268);
}
errors++;
}
}
}
else {
const err269 = {instancePath:instancePath+"/observation/effects/" + i9+"/result",schemaPath:"#/properties/observation/properties/effects/items/anyOf/0/properties/result/anyOf/0/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err269];
}
else {
vErrors.push(err269);
}
errors++;
}
}
var _valid29 = _errs315 === errors;
valid51 = valid51 || _valid29;
const _errs317 = errors;
if(data93 !== null){
const err270 = {instancePath:instancePath+"/observation/effects/" + i9+"/result",schemaPath:"#/properties/observation/properties/effects/items/anyOf/0/properties/result/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err270];
}
else {
vErrors.push(err270);
}
errors++;
}
var _valid29 = _errs317 === errors;
valid51 = valid51 || _valid29;
if(!valid51){
const err271 = {instancePath:instancePath+"/observation/effects/" + i9+"/result",schemaPath:"#/properties/observation/properties/effects/items/anyOf/0/properties/result/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err271];
}
else {
vErrors.push(err271);
}
errors++;
}
else {
errors = _errs314;
if(vErrors !== null){
if(_errs314){
vErrors.length = _errs314;
}
else {
vErrors = null;
}
}
}
var valid48 = _errs313 === errors;
}
else {
var valid48 = true;
}
if(valid48){
if(data86.closed_at !== undefined){
let data94 = data86.closed_at;
const _errs319 = errors;
const _errs320 = errors;
let valid52 = false;
const _errs321 = errors;
if(!(((typeof data94 == "number") && (!(data94 % 1) && !isNaN(data94))) && (isFinite(data94)))){
const err272 = {instancePath:instancePath+"/observation/effects/" + i9+"/closed_at",schemaPath:"#/properties/observation/properties/effects/items/anyOf/0/properties/closed_at/anyOf/0/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err272];
}
else {
vErrors.push(err272);
}
errors++;
}
if(errors === _errs321){
if((typeof data94 == "number") && (isFinite(data94))){
if(data94 > 9007199254740991 || isNaN(data94)){
const err273 = {instancePath:instancePath+"/observation/effects/" + i9+"/closed_at",schemaPath:"#/properties/observation/properties/effects/items/anyOf/0/properties/closed_at/anyOf/0/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"};
if(vErrors === null){
vErrors = [err273];
}
else {
vErrors.push(err273);
}
errors++;
}
else {
if(data94 < 0 || isNaN(data94)){
const err274 = {instancePath:instancePath+"/observation/effects/" + i9+"/closed_at",schemaPath:"#/properties/observation/properties/effects/items/anyOf/0/properties/closed_at/anyOf/0/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err274];
}
else {
vErrors.push(err274);
}
errors++;
}
}
}
}
var _valid30 = _errs321 === errors;
valid52 = valid52 || _valid30;
const _errs323 = errors;
if(data94 !== null){
const err275 = {instancePath:instancePath+"/observation/effects/" + i9+"/closed_at",schemaPath:"#/properties/observation/properties/effects/items/anyOf/0/properties/closed_at/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err275];
}
else {
vErrors.push(err275);
}
errors++;
}
var _valid30 = _errs323 === errors;
valid52 = valid52 || _valid30;
if(!valid52){
const err276 = {instancePath:instancePath+"/observation/effects/" + i9+"/closed_at",schemaPath:"#/properties/observation/properties/effects/items/anyOf/0/properties/closed_at/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err276];
}
else {
vErrors.push(err276);
}
errors++;
}
else {
errors = _errs320;
if(vErrors !== null){
if(_errs320){
vErrors.length = _errs320;
}
else {
vErrors = null;
}
}
}
var valid48 = _errs319 === errors;
}
else {
var valid48 = true;
}
if(valid48){
if(data86.reconcile_before_ms !== undefined){
let data95 = data86.reconcile_before_ms;
const _errs325 = errors;
const _errs326 = errors;
let valid53 = false;
const _errs327 = errors;
if(!(((typeof data95 == "number") && (!(data95 % 1) && !isNaN(data95))) && (isFinite(data95)))){
const err277 = {instancePath:instancePath+"/observation/effects/" + i9+"/reconcile_before_ms",schemaPath:"#/properties/observation/properties/effects/items/anyOf/0/properties/reconcile_before_ms/anyOf/0/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err277];
}
else {
vErrors.push(err277);
}
errors++;
}
if(errors === _errs327){
if((typeof data95 == "number") && (isFinite(data95))){
if(data95 > 9007199254740991 || isNaN(data95)){
const err278 = {instancePath:instancePath+"/observation/effects/" + i9+"/reconcile_before_ms",schemaPath:"#/properties/observation/properties/effects/items/anyOf/0/properties/reconcile_before_ms/anyOf/0/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"};
if(vErrors === null){
vErrors = [err278];
}
else {
vErrors.push(err278);
}
errors++;
}
else {
if(data95 < 0 || isNaN(data95)){
const err279 = {instancePath:instancePath+"/observation/effects/" + i9+"/reconcile_before_ms",schemaPath:"#/properties/observation/properties/effects/items/anyOf/0/properties/reconcile_before_ms/anyOf/0/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err279];
}
else {
vErrors.push(err279);
}
errors++;
}
}
}
}
var _valid31 = _errs327 === errors;
valid53 = valid53 || _valid31;
const _errs329 = errors;
if(data95 !== null){
const err280 = {instancePath:instancePath+"/observation/effects/" + i9+"/reconcile_before_ms",schemaPath:"#/properties/observation/properties/effects/items/anyOf/0/properties/reconcile_before_ms/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err280];
}
else {
vErrors.push(err280);
}
errors++;
}
var _valid31 = _errs329 === errors;
valid53 = valid53 || _valid31;
if(!valid53){
const err281 = {instancePath:instancePath+"/observation/effects/" + i9+"/reconcile_before_ms",schemaPath:"#/properties/observation/properties/effects/items/anyOf/0/properties/reconcile_before_ms/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err281];
}
else {
vErrors.push(err281);
}
errors++;
}
else {
errors = _errs326;
if(vErrors !== null){
if(_errs326){
vErrors.length = _errs326;
}
else {
vErrors = null;
}
}
}
var valid48 = _errs325 === errors;
}
else {
var valid48 = true;
}
if(valid48){
if(data86.max_observations !== undefined){
let data96 = data86.max_observations;
const _errs331 = errors;
if(!(((typeof data96 == "number") && (!(data96 % 1) && !isNaN(data96))) && (isFinite(data96)))){
const err282 = {instancePath:instancePath+"/observation/effects/" + i9+"/max_observations",schemaPath:"#/properties/observation/properties/effects/items/anyOf/0/properties/max_observations/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err282];
}
else {
vErrors.push(err282);
}
errors++;
}
if(errors === _errs331){
if((typeof data96 == "number") && (isFinite(data96))){
if(data96 > 65535 || isNaN(data96)){
const err283 = {instancePath:instancePath+"/observation/effects/" + i9+"/max_observations",schemaPath:"#/properties/observation/properties/effects/items/anyOf/0/properties/max_observations/maximum",keyword:"maximum",params:{comparison: "<=", limit: 65535},message:"must be <= 65535"};
if(vErrors === null){
vErrors = [err283];
}
else {
vErrors.push(err283);
}
errors++;
}
else {
if(data96 < 0 || isNaN(data96)){
const err284 = {instancePath:instancePath+"/observation/effects/" + i9+"/max_observations",schemaPath:"#/properties/observation/properties/effects/items/anyOf/0/properties/max_observations/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err284];
}
else {
vErrors.push(err284);
}
errors++;
}
}
}
}
var valid48 = _errs331 === errors;
}
else {
var valid48 = true;
}
if(valid48){
if(data86.observations !== undefined){
let data97 = data86.observations;
const _errs333 = errors;
if(!(((typeof data97 == "number") && (!(data97 % 1) && !isNaN(data97))) && (isFinite(data97)))){
const err285 = {instancePath:instancePath+"/observation/effects/" + i9+"/observations",schemaPath:"#/properties/observation/properties/effects/items/anyOf/0/properties/observations/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err285];
}
else {
vErrors.push(err285);
}
errors++;
}
if(errors === _errs333){
if((typeof data97 == "number") && (isFinite(data97))){
if(data97 > 65535 || isNaN(data97)){
const err286 = {instancePath:instancePath+"/observation/effects/" + i9+"/observations",schemaPath:"#/properties/observation/properties/effects/items/anyOf/0/properties/observations/maximum",keyword:"maximum",params:{comparison: "<=", limit: 65535},message:"must be <= 65535"};
if(vErrors === null){
vErrors = [err286];
}
else {
vErrors.push(err286);
}
errors++;
}
else {
if(data97 < 0 || isNaN(data97)){
const err287 = {instancePath:instancePath+"/observation/effects/" + i9+"/observations",schemaPath:"#/properties/observation/properties/effects/items/anyOf/0/properties/observations/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err287];
}
else {
vErrors.push(err287);
}
errors++;
}
}
}
}
var valid48 = _errs333 === errors;
}
else {
var valid48 = true;
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
const err288 = {instancePath:instancePath+"/observation/effects/" + i9,schemaPath:"#/properties/observation/properties/effects/items/anyOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err288];
}
else {
vErrors.push(err288);
}
errors++;
}
}
var _valid26 = _errs290 === errors;
valid47 = valid47 || _valid26;
const _errs335 = errors;
if(data86 !== null){
const err289 = {instancePath:instancePath+"/observation/effects/" + i9,schemaPath:"#/properties/observation/properties/effects/items/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err289];
}
else {
vErrors.push(err289);
}
errors++;
}
var _valid26 = _errs335 === errors;
valid47 = valid47 || _valid26;
if(!valid47){
const err290 = {instancePath:instancePath+"/observation/effects/" + i9,schemaPath:"#/properties/observation/properties/effects/items/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err290];
}
else {
vErrors.push(err290);
}
errors++;
validate20.errors = vErrors;
return false;
}
else {
errors = _errs289;
if(vErrors !== null){
if(_errs289){
vErrors.length = _errs289;
}
else {
vErrors = null;
}
}
}
var valid46 = _errs288 === errors;
if(!valid46){
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
var valid1 = _errs286 === errors;
}
else {
var valid1 = true;
}
if(valid1){
if(data0.payloads !== undefined){
let data98 = data0.payloads;
const _errs337 = errors;
if(errors === _errs337){
if(Array.isArray(data98)){
if(data98.length > 16){
validate20.errors = [{instancePath:instancePath+"/observation/payloads",schemaPath:"#/properties/observation/properties/payloads/maxItems",keyword:"maxItems",params:{limit: 16},message:"must NOT have more than 16 items"}];
return false;
}
else {
if(data98.length < 16){
validate20.errors = [{instancePath:instancePath+"/observation/payloads",schemaPath:"#/properties/observation/properties/payloads/minItems",keyword:"minItems",params:{limit: 16},message:"must NOT have fewer than 16 items"}];
return false;
}
else {
var valid54 = true;
const len10 = data98.length;
for(let i10=0; i10<len10; i10++){
let data99 = data98[i10];
const _errs339 = errors;
const _errs340 = errors;
let valid55 = false;
const _errs341 = errors;
if(errors === _errs341){
if(data99 && typeof data99 == "object" && !Array.isArray(data99)){
let missing12;
if((((((((((data99.id === undefined) && (missing12 = "id")) || ((data99.pid === undefined) && (missing12 = "pid"))) || ((data99.publisher === undefined) && (missing12 = "publisher"))) || ((data99.sha256 === undefined) && (missing12 = "sha256"))) || ((data99.bytes === undefined) && (missing12 = "bytes"))) || ((data99.allow_delete === undefined) && (missing12 = "allow_delete"))) || ((data99.phase === undefined) && (missing12 = "phase"))) || ((data99.retired_at === undefined) && (missing12 = "retired_at"))) || ((data99.deleted_at === undefined) && (missing12 = "deleted_at"))){
const err291 = {instancePath:instancePath+"/observation/payloads/" + i10,schemaPath:"#/properties/observation/properties/payloads/items/anyOf/0/required",keyword:"required",params:{missingProperty: missing12},message:"must have required property '"+missing12+"'"};
if(vErrors === null){
vErrors = [err291];
}
else {
vErrors.push(err291);
}
errors++;
}
else {
const _errs343 = errors;
for(const key12 in data99){
if(!(func1.call(schema31.properties.observation.properties.payloads.items.anyOf[0].properties, key12))){
const err292 = {instancePath:instancePath+"/observation/payloads/" + i10,schemaPath:"#/properties/observation/properties/payloads/items/anyOf/0/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key12},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err292];
}
else {
vErrors.push(err292);
}
errors++;
break;
}
}
if(_errs343 === errors){
if(data99.id !== undefined){
let data100 = data99.id;
const _errs344 = errors;
if(!(((typeof data100 == "number") && (!(data100 % 1) && !isNaN(data100))) && (isFinite(data100)))){
const err293 = {instancePath:instancePath+"/observation/payloads/" + i10+"/id",schemaPath:"#/properties/observation/properties/payloads/items/anyOf/0/properties/id/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err293];
}
else {
vErrors.push(err293);
}
errors++;
}
if(errors === _errs344){
if((typeof data100 == "number") && (isFinite(data100))){
if(data100 > 9007199254740991 || isNaN(data100)){
const err294 = {instancePath:instancePath+"/observation/payloads/" + i10+"/id",schemaPath:"#/properties/observation/properties/payloads/items/anyOf/0/properties/id/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"};
if(vErrors === null){
vErrors = [err294];
}
else {
vErrors.push(err294);
}
errors++;
}
else {
if(data100 < 0 || isNaN(data100)){
const err295 = {instancePath:instancePath+"/observation/payloads/" + i10+"/id",schemaPath:"#/properties/observation/properties/payloads/items/anyOf/0/properties/id/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err295];
}
else {
vErrors.push(err295);
}
errors++;
}
}
}
}
var valid56 = _errs344 === errors;
}
else {
var valid56 = true;
}
if(valid56){
if(data99.pid !== undefined){
let data101 = data99.pid;
const _errs346 = errors;
if(!(((typeof data101 == "number") && (!(data101 % 1) && !isNaN(data101))) && (isFinite(data101)))){
const err296 = {instancePath:instancePath+"/observation/payloads/" + i10+"/pid",schemaPath:"#/properties/observation/properties/payloads/items/anyOf/0/properties/pid/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err296];
}
else {
vErrors.push(err296);
}
errors++;
}
if(errors === _errs346){
if((typeof data101 == "number") && (isFinite(data101))){
if(data101 > 9007199254740991 || isNaN(data101)){
const err297 = {instancePath:instancePath+"/observation/payloads/" + i10+"/pid",schemaPath:"#/properties/observation/properties/payloads/items/anyOf/0/properties/pid/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"};
if(vErrors === null){
vErrors = [err297];
}
else {
vErrors.push(err297);
}
errors++;
}
else {
if(data101 < 0 || isNaN(data101)){
const err298 = {instancePath:instancePath+"/observation/payloads/" + i10+"/pid",schemaPath:"#/properties/observation/properties/payloads/items/anyOf/0/properties/pid/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err298];
}
else {
vErrors.push(err298);
}
errors++;
}
}
}
}
var valid56 = _errs346 === errors;
}
else {
var valid56 = true;
}
if(valid56){
if(data99.publisher !== undefined){
let data102 = data99.publisher;
const _errs348 = errors;
if(!(((typeof data102 == "number") && (!(data102 % 1) && !isNaN(data102))) && (isFinite(data102)))){
const err299 = {instancePath:instancePath+"/observation/payloads/" + i10+"/publisher",schemaPath:"#/properties/observation/properties/payloads/items/anyOf/0/properties/publisher/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err299];
}
else {
vErrors.push(err299);
}
errors++;
}
if(errors === _errs348){
if((typeof data102 == "number") && (isFinite(data102))){
if(data102 > 255 || isNaN(data102)){
const err300 = {instancePath:instancePath+"/observation/payloads/" + i10+"/publisher",schemaPath:"#/properties/observation/properties/payloads/items/anyOf/0/properties/publisher/maximum",keyword:"maximum",params:{comparison: "<=", limit: 255},message:"must be <= 255"};
if(vErrors === null){
vErrors = [err300];
}
else {
vErrors.push(err300);
}
errors++;
}
else {
if(data102 < 0 || isNaN(data102)){
const err301 = {instancePath:instancePath+"/observation/payloads/" + i10+"/publisher",schemaPath:"#/properties/observation/properties/payloads/items/anyOf/0/properties/publisher/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err301];
}
else {
vErrors.push(err301);
}
errors++;
}
}
}
}
var valid56 = _errs348 === errors;
}
else {
var valid56 = true;
}
if(valid56){
if(data99.sha256 !== undefined){
let data103 = data99.sha256;
const _errs350 = errors;
if(errors === _errs350){
if(Array.isArray(data103)){
if(data103.length > 32){
const err302 = {instancePath:instancePath+"/observation/payloads/" + i10+"/sha256",schemaPath:"#/properties/observation/properties/payloads/items/anyOf/0/properties/sha256/maxItems",keyword:"maxItems",params:{limit: 32},message:"must NOT have more than 32 items"};
if(vErrors === null){
vErrors = [err302];
}
else {
vErrors.push(err302);
}
errors++;
}
else {
if(data103.length < 32){
const err303 = {instancePath:instancePath+"/observation/payloads/" + i10+"/sha256",schemaPath:"#/properties/observation/properties/payloads/items/anyOf/0/properties/sha256/minItems",keyword:"minItems",params:{limit: 32},message:"must NOT have fewer than 32 items"};
if(vErrors === null){
vErrors = [err303];
}
else {
vErrors.push(err303);
}
errors++;
}
else {
var valid57 = true;
const len11 = data103.length;
for(let i11=0; i11<len11; i11++){
let data104 = data103[i11];
const _errs352 = errors;
if(!(((typeof data104 == "number") && (!(data104 % 1) && !isNaN(data104))) && (isFinite(data104)))){
const err304 = {instancePath:instancePath+"/observation/payloads/" + i10+"/sha256/" + i11,schemaPath:"#/properties/observation/properties/payloads/items/anyOf/0/properties/sha256/items/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err304];
}
else {
vErrors.push(err304);
}
errors++;
}
if(errors === _errs352){
if((typeof data104 == "number") && (isFinite(data104))){
if(data104 > 255 || isNaN(data104)){
const err305 = {instancePath:instancePath+"/observation/payloads/" + i10+"/sha256/" + i11,schemaPath:"#/properties/observation/properties/payloads/items/anyOf/0/properties/sha256/items/maximum",keyword:"maximum",params:{comparison: "<=", limit: 255},message:"must be <= 255"};
if(vErrors === null){
vErrors = [err305];
}
else {
vErrors.push(err305);
}
errors++;
}
else {
if(data104 < 0 || isNaN(data104)){
const err306 = {instancePath:instancePath+"/observation/payloads/" + i10+"/sha256/" + i11,schemaPath:"#/properties/observation/properties/payloads/items/anyOf/0/properties/sha256/items/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err306];
}
else {
vErrors.push(err306);
}
errors++;
}
}
}
}
var valid57 = _errs352 === errors;
if(!valid57){
break;
}
}
}
}
}
else {
const err307 = {instancePath:instancePath+"/observation/payloads/" + i10+"/sha256",schemaPath:"#/properties/observation/properties/payloads/items/anyOf/0/properties/sha256/type",keyword:"type",params:{type: "array"},message:"must be array"};
if(vErrors === null){
vErrors = [err307];
}
else {
vErrors.push(err307);
}
errors++;
}
}
var valid56 = _errs350 === errors;
}
else {
var valid56 = true;
}
if(valid56){
if(data99.bytes !== undefined){
let data105 = data99.bytes;
const _errs354 = errors;
if(!(((typeof data105 == "number") && (!(data105 % 1) && !isNaN(data105))) && (isFinite(data105)))){
const err308 = {instancePath:instancePath+"/observation/payloads/" + i10+"/bytes",schemaPath:"#/properties/observation/properties/payloads/items/anyOf/0/properties/bytes/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err308];
}
else {
vErrors.push(err308);
}
errors++;
}
if(errors === _errs354){
if((typeof data105 == "number") && (isFinite(data105))){
if(data105 > 4294967295 || isNaN(data105)){
const err309 = {instancePath:instancePath+"/observation/payloads/" + i10+"/bytes",schemaPath:"#/properties/observation/properties/payloads/items/anyOf/0/properties/bytes/maximum",keyword:"maximum",params:{comparison: "<=", limit: 4294967295},message:"must be <= 4294967295"};
if(vErrors === null){
vErrors = [err309];
}
else {
vErrors.push(err309);
}
errors++;
}
else {
if(data105 < 0 || isNaN(data105)){
const err310 = {instancePath:instancePath+"/observation/payloads/" + i10+"/bytes",schemaPath:"#/properties/observation/properties/payloads/items/anyOf/0/properties/bytes/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err310];
}
else {
vErrors.push(err310);
}
errors++;
}
}
}
}
var valid56 = _errs354 === errors;
}
else {
var valid56 = true;
}
if(valid56){
if(data99.allow_delete !== undefined){
const _errs356 = errors;
if(typeof data99.allow_delete !== "boolean"){
const err311 = {instancePath:instancePath+"/observation/payloads/" + i10+"/allow_delete",schemaPath:"#/properties/observation/properties/payloads/items/anyOf/0/properties/allow_delete/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"};
if(vErrors === null){
vErrors = [err311];
}
else {
vErrors.push(err311);
}
errors++;
}
var valid56 = _errs356 === errors;
}
else {
var valid56 = true;
}
if(valid56){
if(data99.phase !== undefined){
let data107 = data99.phase;
const _errs358 = errors;
if(typeof data107 !== "string"){
const err312 = {instancePath:instancePath+"/observation/payloads/" + i10+"/phase",schemaPath:"#/properties/observation/properties/payloads/items/anyOf/0/properties/phase/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err312];
}
else {
vErrors.push(err312);
}
errors++;
}
if(!((((data107 === "creating") || (data107 === "ready")) || (data107 === "retiring")) || (data107 === "deleted"))){
const err313 = {instancePath:instancePath+"/observation/payloads/" + i10+"/phase",schemaPath:"#/properties/observation/properties/payloads/items/anyOf/0/properties/phase/enum",keyword:"enum",params:{allowedValues: schema31.properties.observation.properties.payloads.items.anyOf[0].properties.phase.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err313];
}
else {
vErrors.push(err313);
}
errors++;
}
var valid56 = _errs358 === errors;
}
else {
var valid56 = true;
}
if(valid56){
if(data99.retired_at !== undefined){
let data108 = data99.retired_at;
const _errs360 = errors;
const _errs361 = errors;
let valid58 = false;
const _errs362 = errors;
if(!(((typeof data108 == "number") && (!(data108 % 1) && !isNaN(data108))) && (isFinite(data108)))){
const err314 = {instancePath:instancePath+"/observation/payloads/" + i10+"/retired_at",schemaPath:"#/properties/observation/properties/payloads/items/anyOf/0/properties/retired_at/anyOf/0/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err314];
}
else {
vErrors.push(err314);
}
errors++;
}
if(errors === _errs362){
if((typeof data108 == "number") && (isFinite(data108))){
if(data108 > 9007199254740991 || isNaN(data108)){
const err315 = {instancePath:instancePath+"/observation/payloads/" + i10+"/retired_at",schemaPath:"#/properties/observation/properties/payloads/items/anyOf/0/properties/retired_at/anyOf/0/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"};
if(vErrors === null){
vErrors = [err315];
}
else {
vErrors.push(err315);
}
errors++;
}
else {
if(data108 < 0 || isNaN(data108)){
const err316 = {instancePath:instancePath+"/observation/payloads/" + i10+"/retired_at",schemaPath:"#/properties/observation/properties/payloads/items/anyOf/0/properties/retired_at/anyOf/0/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
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
var _valid33 = _errs362 === errors;
valid58 = valid58 || _valid33;
const _errs364 = errors;
if(data108 !== null){
const err317 = {instancePath:instancePath+"/observation/payloads/" + i10+"/retired_at",schemaPath:"#/properties/observation/properties/payloads/items/anyOf/0/properties/retired_at/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err317];
}
else {
vErrors.push(err317);
}
errors++;
}
var _valid33 = _errs364 === errors;
valid58 = valid58 || _valid33;
if(!valid58){
const err318 = {instancePath:instancePath+"/observation/payloads/" + i10+"/retired_at",schemaPath:"#/properties/observation/properties/payloads/items/anyOf/0/properties/retired_at/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err318];
}
else {
vErrors.push(err318);
}
errors++;
}
else {
errors = _errs361;
if(vErrors !== null){
if(_errs361){
vErrors.length = _errs361;
}
else {
vErrors = null;
}
}
}
var valid56 = _errs360 === errors;
}
else {
var valid56 = true;
}
if(valid56){
if(data99.deleted_at !== undefined){
let data109 = data99.deleted_at;
const _errs366 = errors;
const _errs367 = errors;
let valid59 = false;
const _errs368 = errors;
if(!(((typeof data109 == "number") && (!(data109 % 1) && !isNaN(data109))) && (isFinite(data109)))){
const err319 = {instancePath:instancePath+"/observation/payloads/" + i10+"/deleted_at",schemaPath:"#/properties/observation/properties/payloads/items/anyOf/0/properties/deleted_at/anyOf/0/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err319];
}
else {
vErrors.push(err319);
}
errors++;
}
if(errors === _errs368){
if((typeof data109 == "number") && (isFinite(data109))){
if(data109 > 9007199254740991 || isNaN(data109)){
const err320 = {instancePath:instancePath+"/observation/payloads/" + i10+"/deleted_at",schemaPath:"#/properties/observation/properties/payloads/items/anyOf/0/properties/deleted_at/anyOf/0/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"};
if(vErrors === null){
vErrors = [err320];
}
else {
vErrors.push(err320);
}
errors++;
}
else {
if(data109 < 0 || isNaN(data109)){
const err321 = {instancePath:instancePath+"/observation/payloads/" + i10+"/deleted_at",schemaPath:"#/properties/observation/properties/payloads/items/anyOf/0/properties/deleted_at/anyOf/0/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err321];
}
else {
vErrors.push(err321);
}
errors++;
}
}
}
}
var _valid34 = _errs368 === errors;
valid59 = valid59 || _valid34;
const _errs370 = errors;
if(data109 !== null){
const err322 = {instancePath:instancePath+"/observation/payloads/" + i10+"/deleted_at",schemaPath:"#/properties/observation/properties/payloads/items/anyOf/0/properties/deleted_at/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err322];
}
else {
vErrors.push(err322);
}
errors++;
}
var _valid34 = _errs370 === errors;
valid59 = valid59 || _valid34;
if(!valid59){
const err323 = {instancePath:instancePath+"/observation/payloads/" + i10+"/deleted_at",schemaPath:"#/properties/observation/properties/payloads/items/anyOf/0/properties/deleted_at/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err323];
}
else {
vErrors.push(err323);
}
errors++;
}
else {
errors = _errs367;
if(vErrors !== null){
if(_errs367){
vErrors.length = _errs367;
}
else {
vErrors = null;
}
}
}
var valid56 = _errs366 === errors;
}
else {
var valid56 = true;
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
const err324 = {instancePath:instancePath+"/observation/payloads/" + i10,schemaPath:"#/properties/observation/properties/payloads/items/anyOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err324];
}
else {
vErrors.push(err324);
}
errors++;
}
}
var _valid32 = _errs341 === errors;
valid55 = valid55 || _valid32;
const _errs372 = errors;
if(data99 !== null){
const err325 = {instancePath:instancePath+"/observation/payloads/" + i10,schemaPath:"#/properties/observation/properties/payloads/items/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err325];
}
else {
vErrors.push(err325);
}
errors++;
}
var _valid32 = _errs372 === errors;
valid55 = valid55 || _valid32;
if(!valid55){
const err326 = {instancePath:instancePath+"/observation/payloads/" + i10,schemaPath:"#/properties/observation/properties/payloads/items/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err326];
}
else {
vErrors.push(err326);
}
errors++;
validate20.errors = vErrors;
return false;
}
else {
errors = _errs340;
if(vErrors !== null){
if(_errs340){
vErrors.length = _errs340;
}
else {
vErrors = null;
}
}
}
var valid54 = _errs339 === errors;
if(!valid54){
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
var valid1 = _errs337 === errors;
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
if(data.lens !== undefined){
let data110 = data.lens;
const _errs374 = errors;
const _errs375 = errors;
let valid60 = false;
const _errs376 = errors;
if(errors === _errs376){
if(data110 && typeof data110 == "object" && !Array.isArray(data110)){
let missing13;
if(((((((data110.kind === undefined) && (missing13 = "kind")) || ((data110.version === undefined) && (missing13 = "version"))) || ((data110.provenance === undefined) && (missing13 = "provenance"))) || ((data110.status === undefined) && (missing13 = "status"))) || ((data110.source === undefined) && (missing13 = "source"))) || ((data110.count === undefined) && (missing13 = "count"))){
const err327 = {instancePath:instancePath+"/lens",schemaPath:"#/properties/lens/anyOf/0/required",keyword:"required",params:{missingProperty: missing13},message:"must have required property '"+missing13+"'"};
if(vErrors === null){
vErrors = [err327];
}
else {
vErrors.push(err327);
}
errors++;
}
else {
const _errs378 = errors;
for(const key13 in data110){
if(!((((((key13 === "kind") || (key13 === "version")) || (key13 === "provenance")) || (key13 === "status")) || (key13 === "source")) || (key13 === "count"))){
const err328 = {instancePath:instancePath+"/lens",schemaPath:"#/properties/lens/anyOf/0/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key13},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err328];
}
else {
vErrors.push(err328);
}
errors++;
break;
}
}
if(_errs378 === errors){
if(data110.kind !== undefined){
let data111 = data110.kind;
const _errs379 = errors;
if(errors === _errs379){
if(typeof data111 === "string"){
if(func3(data111) > 256){
const err329 = {instancePath:instancePath+"/lens/kind",schemaPath:"#/properties/lens/anyOf/0/properties/kind/maxLength",keyword:"maxLength",params:{limit: 256},message:"must NOT have more than 256 characters"};
if(vErrors === null){
vErrors = [err329];
}
else {
vErrors.push(err329);
}
errors++;
}
}
else {
const err330 = {instancePath:instancePath+"/lens/kind",schemaPath:"#/properties/lens/anyOf/0/properties/kind/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err330];
}
else {
vErrors.push(err330);
}
errors++;
}
}
var valid61 = _errs379 === errors;
}
else {
var valid61 = true;
}
if(valid61){
if(data110.version !== undefined){
let data112 = data110.version;
const _errs381 = errors;
if(!(((typeof data112 == "number") && (!(data112 % 1) && !isNaN(data112))) && (isFinite(data112)))){
const err331 = {instancePath:instancePath+"/lens/version",schemaPath:"#/properties/lens/anyOf/0/properties/version/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err331];
}
else {
vErrors.push(err331);
}
errors++;
}
if(errors === _errs381){
if((typeof data112 == "number") && (isFinite(data112))){
if(data112 > 4294967295 || isNaN(data112)){
const err332 = {instancePath:instancePath+"/lens/version",schemaPath:"#/properties/lens/anyOf/0/properties/version/maximum",keyword:"maximum",params:{comparison: "<=", limit: 4294967295},message:"must be <= 4294967295"};
if(vErrors === null){
vErrors = [err332];
}
else {
vErrors.push(err332);
}
errors++;
}
else {
if(data112 < 0 || isNaN(data112)){
const err333 = {instancePath:instancePath+"/lens/version",schemaPath:"#/properties/lens/anyOf/0/properties/version/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err333];
}
else {
vErrors.push(err333);
}
errors++;
}
}
}
}
var valid61 = _errs381 === errors;
}
else {
var valid61 = true;
}
if(valid61){
if(data110.provenance !== undefined){
let data113 = data110.provenance;
const _errs383 = errors;
if(typeof data113 !== "string"){
const err334 = {instancePath:instancePath+"/lens/provenance",schemaPath:"#/properties/lens/anyOf/0/properties/provenance/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err334];
}
else {
vErrors.push(err334);
}
errors++;
}
if(!(data113 === "operator_mapping")){
const err335 = {instancePath:instancePath+"/lens/provenance",schemaPath:"#/properties/lens/anyOf/0/properties/provenance/enum",keyword:"enum",params:{allowedValues: schema31.properties.lens.anyOf[0].properties.provenance.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err335];
}
else {
vErrors.push(err335);
}
errors++;
}
var valid61 = _errs383 === errors;
}
else {
var valid61 = true;
}
if(valid61){
if(data110.status !== undefined){
let data114 = data110.status;
const _errs385 = errors;
if(typeof data114 !== "string"){
const err336 = {instancePath:instancePath+"/lens/status",schemaPath:"#/properties/lens/anyOf/0/properties/status/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err336];
}
else {
vErrors.push(err336);
}
errors++;
}
if(!(((data114 === "applied") || (data114 === "unknown")) || (data114 === "malformed"))){
const err337 = {instancePath:instancePath+"/lens/status",schemaPath:"#/properties/lens/anyOf/0/properties/status/enum",keyword:"enum",params:{allowedValues: schema31.properties.lens.anyOf[0].properties.status.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err337];
}
else {
vErrors.push(err337);
}
errors++;
}
var valid61 = _errs385 === errors;
}
else {
var valid61 = true;
}
if(valid61){
if(data110.source !== undefined){
let data115 = data110.source;
const _errs387 = errors;
if(errors === _errs387){
if(data115 && typeof data115 == "object" && !Array.isArray(data115)){
let missing14;
if(((((data115.realm === undefined) && (missing14 = "realm")) || ((data115.pid === undefined) && (missing14 = "pid"))) || ((data115.kind === undefined) && (missing14 = "kind"))) || ((data115.id === undefined) && (missing14 = "id"))){
const err338 = {instancePath:instancePath+"/lens/source",schemaPath:"#/properties/lens/anyOf/0/properties/source/required",keyword:"required",params:{missingProperty: missing14},message:"must have required property '"+missing14+"'"};
if(vErrors === null){
vErrors = [err338];
}
else {
vErrors.push(err338);
}
errors++;
}
else {
const _errs389 = errors;
for(const key14 in data115){
if(!((((key14 === "realm") || (key14 === "pid")) || (key14 === "kind")) || (key14 === "id"))){
const err339 = {instancePath:instancePath+"/lens/source",schemaPath:"#/properties/lens/anyOf/0/properties/source/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key14},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err339];
}
else {
vErrors.push(err339);
}
errors++;
break;
}
}
if(_errs389 === errors){
if(data115.realm !== undefined){
let data116 = data115.realm;
const _errs390 = errors;
if(!(((typeof data116 == "number") && (!(data116 % 1) && !isNaN(data116))) && (isFinite(data116)))){
const err340 = {instancePath:instancePath+"/lens/source/realm",schemaPath:"#/properties/lens/anyOf/0/properties/source/properties/realm/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err340];
}
else {
vErrors.push(err340);
}
errors++;
}
if(errors === _errs390){
if((typeof data116 == "number") && (isFinite(data116))){
if(data116 > 9007199254740991 || isNaN(data116)){
const err341 = {instancePath:instancePath+"/lens/source/realm",schemaPath:"#/properties/lens/anyOf/0/properties/source/properties/realm/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"};
if(vErrors === null){
vErrors = [err341];
}
else {
vErrors.push(err341);
}
errors++;
}
else {
if(data116 < 0 || isNaN(data116)){
const err342 = {instancePath:instancePath+"/lens/source/realm",schemaPath:"#/properties/lens/anyOf/0/properties/source/properties/realm/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err342];
}
else {
vErrors.push(err342);
}
errors++;
}
}
}
}
var valid62 = _errs390 === errors;
}
else {
var valid62 = true;
}
if(valid62){
if(data115.pid !== undefined){
let data117 = data115.pid;
const _errs392 = errors;
if(!(((typeof data117 == "number") && (!(data117 % 1) && !isNaN(data117))) && (isFinite(data117)))){
const err343 = {instancePath:instancePath+"/lens/source/pid",schemaPath:"#/properties/lens/anyOf/0/properties/source/properties/pid/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err343];
}
else {
vErrors.push(err343);
}
errors++;
}
if(errors === _errs392){
if((typeof data117 == "number") && (isFinite(data117))){
if(data117 > 9007199254740991 || isNaN(data117)){
const err344 = {instancePath:instancePath+"/lens/source/pid",schemaPath:"#/properties/lens/anyOf/0/properties/source/properties/pid/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"};
if(vErrors === null){
vErrors = [err344];
}
else {
vErrors.push(err344);
}
errors++;
}
else {
if(data117 < 0 || isNaN(data117)){
const err345 = {instancePath:instancePath+"/lens/source/pid",schemaPath:"#/properties/lens/anyOf/0/properties/source/properties/pid/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
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
var valid62 = _errs392 === errors;
}
else {
var valid62 = true;
}
if(valid62){
if(data115.kind !== undefined){
let data118 = data115.kind;
const _errs394 = errors;
if(typeof data118 !== "string"){
const err346 = {instancePath:instancePath+"/lens/source/kind",schemaPath:"#/properties/lens/anyOf/0/properties/source/properties/kind/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err346];
}
else {
vErrors.push(err346);
}
errors++;
}
if(!((((((data118 === "input") || (data118 === "turn")) || (data118 === "output")) || (data118 === "effect")) || (data118 === "event")) || (data118 === "state"))){
const err347 = {instancePath:instancePath+"/lens/source/kind",schemaPath:"#/properties/lens/anyOf/0/properties/source/properties/kind/enum",keyword:"enum",params:{allowedValues: schema31.properties.lens.anyOf[0].properties.source.properties.kind.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err347];
}
else {
vErrors.push(err347);
}
errors++;
}
var valid62 = _errs394 === errors;
}
else {
var valid62 = true;
}
if(valid62){
if(data115.id !== undefined){
let data119 = data115.id;
const _errs396 = errors;
if(!(((typeof data119 == "number") && (!(data119 % 1) && !isNaN(data119))) && (isFinite(data119)))){
const err348 = {instancePath:instancePath+"/lens/source/id",schemaPath:"#/properties/lens/anyOf/0/properties/source/properties/id/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err348];
}
else {
vErrors.push(err348);
}
errors++;
}
if(errors === _errs396){
if((typeof data119 == "number") && (isFinite(data119))){
if(data119 > 9007199254740991 || isNaN(data119)){
const err349 = {instancePath:instancePath+"/lens/source/id",schemaPath:"#/properties/lens/anyOf/0/properties/source/properties/id/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"};
if(vErrors === null){
vErrors = [err349];
}
else {
vErrors.push(err349);
}
errors++;
}
else {
if(data119 < 0 || isNaN(data119)){
const err350 = {instancePath:instancePath+"/lens/source/id",schemaPath:"#/properties/lens/anyOf/0/properties/source/properties/id/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
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
var valid62 = _errs396 === errors;
}
else {
var valid62 = true;
}
}
}
}
}
}
}
else {
const err351 = {instancePath:instancePath+"/lens/source",schemaPath:"#/properties/lens/anyOf/0/properties/source/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err351];
}
else {
vErrors.push(err351);
}
errors++;
}
}
var valid61 = _errs387 === errors;
}
else {
var valid61 = true;
}
if(valid61){
if(data110.count !== undefined){
let data120 = data110.count;
const _errs398 = errors;
const _errs399 = errors;
let valid63 = false;
const _errs400 = errors;
if(!(((typeof data120 == "number") && (!(data120 % 1) && !isNaN(data120))) && (isFinite(data120)))){
const err352 = {instancePath:instancePath+"/lens/count",schemaPath:"#/properties/lens/anyOf/0/properties/count/anyOf/0/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err352];
}
else {
vErrors.push(err352);
}
errors++;
}
if(errors === _errs400){
if((typeof data120 == "number") && (isFinite(data120))){
if(data120 > 9007199254740991 || isNaN(data120)){
const err353 = {instancePath:instancePath+"/lens/count",schemaPath:"#/properties/lens/anyOf/0/properties/count/anyOf/0/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"};
if(vErrors === null){
vErrors = [err353];
}
else {
vErrors.push(err353);
}
errors++;
}
else {
if(data120 < -9007199254740991 || isNaN(data120)){
const err354 = {instancePath:instancePath+"/lens/count",schemaPath:"#/properties/lens/anyOf/0/properties/count/anyOf/0/minimum",keyword:"minimum",params:{comparison: ">=", limit: -9007199254740991},message:"must be >= -9007199254740991"};
if(vErrors === null){
vErrors = [err354];
}
else {
vErrors.push(err354);
}
errors++;
}
}
}
}
var _valid36 = _errs400 === errors;
valid63 = valid63 || _valid36;
const _errs402 = errors;
if(data120 !== null){
const err355 = {instancePath:instancePath+"/lens/count",schemaPath:"#/properties/lens/anyOf/0/properties/count/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err355];
}
else {
vErrors.push(err355);
}
errors++;
}
var _valid36 = _errs402 === errors;
valid63 = valid63 || _valid36;
if(!valid63){
const err356 = {instancePath:instancePath+"/lens/count",schemaPath:"#/properties/lens/anyOf/0/properties/count/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err356];
}
else {
vErrors.push(err356);
}
errors++;
}
else {
errors = _errs399;
if(vErrors !== null){
if(_errs399){
vErrors.length = _errs399;
}
else {
vErrors = null;
}
}
}
var valid61 = _errs398 === errors;
}
else {
var valid61 = true;
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
const err357 = {instancePath:instancePath+"/lens",schemaPath:"#/properties/lens/anyOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err357];
}
else {
vErrors.push(err357);
}
errors++;
}
}
var _valid35 = _errs376 === errors;
valid60 = valid60 || _valid35;
const _errs404 = errors;
if(data110 !== null){
const err358 = {instancePath:instancePath+"/lens",schemaPath:"#/properties/lens/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err358];
}
else {
vErrors.push(err358);
}
errors++;
}
var _valid35 = _errs404 === errors;
valid60 = valid60 || _valid35;
if(!valid60){
const err359 = {instancePath:instancePath+"/lens",schemaPath:"#/properties/lens/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err359];
}
else {
vErrors.push(err359);
}
errors++;
validate20.errors = vErrors;
return false;
}
else {
errors = _errs375;
if(vErrors !== null){
if(_errs375){
vErrors.length = _errs375;
}
else {
vErrors = null;
}
}
}
var valid0 = _errs374 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.edges !== undefined){
let data121 = data.edges;
const _errs406 = errors;
if(errors === _errs406){
if(Array.isArray(data121)){
if(data121.length > 32){
validate20.errors = [{instancePath:instancePath+"/edges",schemaPath:"#/properties/edges/maxItems",keyword:"maxItems",params:{limit: 32},message:"must NOT have more than 32 items"}];
return false;
}
else {
if(data121.length < 32){
validate20.errors = [{instancePath:instancePath+"/edges",schemaPath:"#/properties/edges/minItems",keyword:"minItems",params:{limit: 32},message:"must NOT have fewer than 32 items"}];
return false;
}
else {
var valid64 = true;
const len12 = data121.length;
for(let i12=0; i12<len12; i12++){
let data122 = data121[i12];
const _errs408 = errors;
const _errs409 = errors;
let valid65 = false;
const _errs410 = errors;
if(errors === _errs410){
if(data122 && typeof data122 == "object" && !Array.isArray(data122)){
let missing15;
if((((((data122.from === undefined) && (missing15 = "from")) || ((data122.to === undefined) && (missing15 = "to"))) || ((data122.relation === undefined) && (missing15 = "relation"))) || ((data122.from_coverage === undefined) && (missing15 = "from_coverage"))) || ((data122.to_coverage === undefined) && (missing15 = "to_coverage"))){
const err360 = {instancePath:instancePath+"/edges/" + i12,schemaPath:"#/properties/edges/items/anyOf/0/required",keyword:"required",params:{missingProperty: missing15},message:"must have required property '"+missing15+"'"};
if(vErrors === null){
vErrors = [err360];
}
else {
vErrors.push(err360);
}
errors++;
}
else {
const _errs412 = errors;
for(const key15 in data122){
if(!(((((key15 === "from") || (key15 === "to")) || (key15 === "relation")) || (key15 === "from_coverage")) || (key15 === "to_coverage"))){
const err361 = {instancePath:instancePath+"/edges/" + i12,schemaPath:"#/properties/edges/items/anyOf/0/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key15},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err361];
}
else {
vErrors.push(err361);
}
errors++;
break;
}
}
if(_errs412 === errors){
if(data122.from !== undefined){
let data123 = data122.from;
const _errs413 = errors;
if(errors === _errs413){
if(data123 && typeof data123 == "object" && !Array.isArray(data123)){
let missing16;
if(((((data123.realm === undefined) && (missing16 = "realm")) || ((data123.pid === undefined) && (missing16 = "pid"))) || ((data123.kind === undefined) && (missing16 = "kind"))) || ((data123.id === undefined) && (missing16 = "id"))){
const err362 = {instancePath:instancePath+"/edges/" + i12+"/from",schemaPath:"#/properties/edges/items/anyOf/0/properties/from/required",keyword:"required",params:{missingProperty: missing16},message:"must have required property '"+missing16+"'"};
if(vErrors === null){
vErrors = [err362];
}
else {
vErrors.push(err362);
}
errors++;
}
else {
const _errs415 = errors;
for(const key16 in data123){
if(!((((key16 === "realm") || (key16 === "pid")) || (key16 === "kind")) || (key16 === "id"))){
const err363 = {instancePath:instancePath+"/edges/" + i12+"/from",schemaPath:"#/properties/edges/items/anyOf/0/properties/from/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key16},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err363];
}
else {
vErrors.push(err363);
}
errors++;
break;
}
}
if(_errs415 === errors){
if(data123.realm !== undefined){
let data124 = data123.realm;
const _errs416 = errors;
if(!(((typeof data124 == "number") && (!(data124 % 1) && !isNaN(data124))) && (isFinite(data124)))){
const err364 = {instancePath:instancePath+"/edges/" + i12+"/from/realm",schemaPath:"#/properties/edges/items/anyOf/0/properties/from/properties/realm/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err364];
}
else {
vErrors.push(err364);
}
errors++;
}
if(errors === _errs416){
if((typeof data124 == "number") && (isFinite(data124))){
if(data124 > 9007199254740991 || isNaN(data124)){
const err365 = {instancePath:instancePath+"/edges/" + i12+"/from/realm",schemaPath:"#/properties/edges/items/anyOf/0/properties/from/properties/realm/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"};
if(vErrors === null){
vErrors = [err365];
}
else {
vErrors.push(err365);
}
errors++;
}
else {
if(data124 < 0 || isNaN(data124)){
const err366 = {instancePath:instancePath+"/edges/" + i12+"/from/realm",schemaPath:"#/properties/edges/items/anyOf/0/properties/from/properties/realm/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err366];
}
else {
vErrors.push(err366);
}
errors++;
}
}
}
}
var valid67 = _errs416 === errors;
}
else {
var valid67 = true;
}
if(valid67){
if(data123.pid !== undefined){
let data125 = data123.pid;
const _errs418 = errors;
if(!(((typeof data125 == "number") && (!(data125 % 1) && !isNaN(data125))) && (isFinite(data125)))){
const err367 = {instancePath:instancePath+"/edges/" + i12+"/from/pid",schemaPath:"#/properties/edges/items/anyOf/0/properties/from/properties/pid/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err367];
}
else {
vErrors.push(err367);
}
errors++;
}
if(errors === _errs418){
if((typeof data125 == "number") && (isFinite(data125))){
if(data125 > 9007199254740991 || isNaN(data125)){
const err368 = {instancePath:instancePath+"/edges/" + i12+"/from/pid",schemaPath:"#/properties/edges/items/anyOf/0/properties/from/properties/pid/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"};
if(vErrors === null){
vErrors = [err368];
}
else {
vErrors.push(err368);
}
errors++;
}
else {
if(data125 < 0 || isNaN(data125)){
const err369 = {instancePath:instancePath+"/edges/" + i12+"/from/pid",schemaPath:"#/properties/edges/items/anyOf/0/properties/from/properties/pid/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err369];
}
else {
vErrors.push(err369);
}
errors++;
}
}
}
}
var valid67 = _errs418 === errors;
}
else {
var valid67 = true;
}
if(valid67){
if(data123.kind !== undefined){
let data126 = data123.kind;
const _errs420 = errors;
if(typeof data126 !== "string"){
const err370 = {instancePath:instancePath+"/edges/" + i12+"/from/kind",schemaPath:"#/properties/edges/items/anyOf/0/properties/from/properties/kind/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err370];
}
else {
vErrors.push(err370);
}
errors++;
}
if(!((((((data126 === "input") || (data126 === "turn")) || (data126 === "output")) || (data126 === "effect")) || (data126 === "event")) || (data126 === "state"))){
const err371 = {instancePath:instancePath+"/edges/" + i12+"/from/kind",schemaPath:"#/properties/edges/items/anyOf/0/properties/from/properties/kind/enum",keyword:"enum",params:{allowedValues: schema31.properties.edges.items.anyOf[0].properties.from.properties.kind.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err371];
}
else {
vErrors.push(err371);
}
errors++;
}
var valid67 = _errs420 === errors;
}
else {
var valid67 = true;
}
if(valid67){
if(data123.id !== undefined){
let data127 = data123.id;
const _errs422 = errors;
if(!(((typeof data127 == "number") && (!(data127 % 1) && !isNaN(data127))) && (isFinite(data127)))){
const err372 = {instancePath:instancePath+"/edges/" + i12+"/from/id",schemaPath:"#/properties/edges/items/anyOf/0/properties/from/properties/id/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err372];
}
else {
vErrors.push(err372);
}
errors++;
}
if(errors === _errs422){
if((typeof data127 == "number") && (isFinite(data127))){
if(data127 > 9007199254740991 || isNaN(data127)){
const err373 = {instancePath:instancePath+"/edges/" + i12+"/from/id",schemaPath:"#/properties/edges/items/anyOf/0/properties/from/properties/id/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"};
if(vErrors === null){
vErrors = [err373];
}
else {
vErrors.push(err373);
}
errors++;
}
else {
if(data127 < 0 || isNaN(data127)){
const err374 = {instancePath:instancePath+"/edges/" + i12+"/from/id",schemaPath:"#/properties/edges/items/anyOf/0/properties/from/properties/id/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err374];
}
else {
vErrors.push(err374);
}
errors++;
}
}
}
}
var valid67 = _errs422 === errors;
}
else {
var valid67 = true;
}
}
}
}
}
}
}
else {
const err375 = {instancePath:instancePath+"/edges/" + i12+"/from",schemaPath:"#/properties/edges/items/anyOf/0/properties/from/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err375];
}
else {
vErrors.push(err375);
}
errors++;
}
}
var valid66 = _errs413 === errors;
}
else {
var valid66 = true;
}
if(valid66){
if(data122.to !== undefined){
let data128 = data122.to;
const _errs424 = errors;
if(errors === _errs424){
if(data128 && typeof data128 == "object" && !Array.isArray(data128)){
let missing17;
if(((((data128.realm === undefined) && (missing17 = "realm")) || ((data128.pid === undefined) && (missing17 = "pid"))) || ((data128.kind === undefined) && (missing17 = "kind"))) || ((data128.id === undefined) && (missing17 = "id"))){
const err376 = {instancePath:instancePath+"/edges/" + i12+"/to",schemaPath:"#/properties/edges/items/anyOf/0/properties/to/required",keyword:"required",params:{missingProperty: missing17},message:"must have required property '"+missing17+"'"};
if(vErrors === null){
vErrors = [err376];
}
else {
vErrors.push(err376);
}
errors++;
}
else {
const _errs426 = errors;
for(const key17 in data128){
if(!((((key17 === "realm") || (key17 === "pid")) || (key17 === "kind")) || (key17 === "id"))){
const err377 = {instancePath:instancePath+"/edges/" + i12+"/to",schemaPath:"#/properties/edges/items/anyOf/0/properties/to/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key17},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err377];
}
else {
vErrors.push(err377);
}
errors++;
break;
}
}
if(_errs426 === errors){
if(data128.realm !== undefined){
let data129 = data128.realm;
const _errs427 = errors;
if(!(((typeof data129 == "number") && (!(data129 % 1) && !isNaN(data129))) && (isFinite(data129)))){
const err378 = {instancePath:instancePath+"/edges/" + i12+"/to/realm",schemaPath:"#/properties/edges/items/anyOf/0/properties/to/properties/realm/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err378];
}
else {
vErrors.push(err378);
}
errors++;
}
if(errors === _errs427){
if((typeof data129 == "number") && (isFinite(data129))){
if(data129 > 9007199254740991 || isNaN(data129)){
const err379 = {instancePath:instancePath+"/edges/" + i12+"/to/realm",schemaPath:"#/properties/edges/items/anyOf/0/properties/to/properties/realm/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"};
if(vErrors === null){
vErrors = [err379];
}
else {
vErrors.push(err379);
}
errors++;
}
else {
if(data129 < 0 || isNaN(data129)){
const err380 = {instancePath:instancePath+"/edges/" + i12+"/to/realm",schemaPath:"#/properties/edges/items/anyOf/0/properties/to/properties/realm/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err380];
}
else {
vErrors.push(err380);
}
errors++;
}
}
}
}
var valid68 = _errs427 === errors;
}
else {
var valid68 = true;
}
if(valid68){
if(data128.pid !== undefined){
let data130 = data128.pid;
const _errs429 = errors;
if(!(((typeof data130 == "number") && (!(data130 % 1) && !isNaN(data130))) && (isFinite(data130)))){
const err381 = {instancePath:instancePath+"/edges/" + i12+"/to/pid",schemaPath:"#/properties/edges/items/anyOf/0/properties/to/properties/pid/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err381];
}
else {
vErrors.push(err381);
}
errors++;
}
if(errors === _errs429){
if((typeof data130 == "number") && (isFinite(data130))){
if(data130 > 9007199254740991 || isNaN(data130)){
const err382 = {instancePath:instancePath+"/edges/" + i12+"/to/pid",schemaPath:"#/properties/edges/items/anyOf/0/properties/to/properties/pid/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"};
if(vErrors === null){
vErrors = [err382];
}
else {
vErrors.push(err382);
}
errors++;
}
else {
if(data130 < 0 || isNaN(data130)){
const err383 = {instancePath:instancePath+"/edges/" + i12+"/to/pid",schemaPath:"#/properties/edges/items/anyOf/0/properties/to/properties/pid/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err383];
}
else {
vErrors.push(err383);
}
errors++;
}
}
}
}
var valid68 = _errs429 === errors;
}
else {
var valid68 = true;
}
if(valid68){
if(data128.kind !== undefined){
let data131 = data128.kind;
const _errs431 = errors;
if(typeof data131 !== "string"){
const err384 = {instancePath:instancePath+"/edges/" + i12+"/to/kind",schemaPath:"#/properties/edges/items/anyOf/0/properties/to/properties/kind/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err384];
}
else {
vErrors.push(err384);
}
errors++;
}
if(!((((((data131 === "input") || (data131 === "turn")) || (data131 === "output")) || (data131 === "effect")) || (data131 === "event")) || (data131 === "state"))){
const err385 = {instancePath:instancePath+"/edges/" + i12+"/to/kind",schemaPath:"#/properties/edges/items/anyOf/0/properties/to/properties/kind/enum",keyword:"enum",params:{allowedValues: schema31.properties.edges.items.anyOf[0].properties.to.properties.kind.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err385];
}
else {
vErrors.push(err385);
}
errors++;
}
var valid68 = _errs431 === errors;
}
else {
var valid68 = true;
}
if(valid68){
if(data128.id !== undefined){
let data132 = data128.id;
const _errs433 = errors;
if(!(((typeof data132 == "number") && (!(data132 % 1) && !isNaN(data132))) && (isFinite(data132)))){
const err386 = {instancePath:instancePath+"/edges/" + i12+"/to/id",schemaPath:"#/properties/edges/items/anyOf/0/properties/to/properties/id/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err386];
}
else {
vErrors.push(err386);
}
errors++;
}
if(errors === _errs433){
if((typeof data132 == "number") && (isFinite(data132))){
if(data132 > 9007199254740991 || isNaN(data132)){
const err387 = {instancePath:instancePath+"/edges/" + i12+"/to/id",schemaPath:"#/properties/edges/items/anyOf/0/properties/to/properties/id/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"};
if(vErrors === null){
vErrors = [err387];
}
else {
vErrors.push(err387);
}
errors++;
}
else {
if(data132 < 0 || isNaN(data132)){
const err388 = {instancePath:instancePath+"/edges/" + i12+"/to/id",schemaPath:"#/properties/edges/items/anyOf/0/properties/to/properties/id/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err388];
}
else {
vErrors.push(err388);
}
errors++;
}
}
}
}
var valid68 = _errs433 === errors;
}
else {
var valid68 = true;
}
}
}
}
}
}
}
else {
const err389 = {instancePath:instancePath+"/edges/" + i12+"/to",schemaPath:"#/properties/edges/items/anyOf/0/properties/to/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err389];
}
else {
vErrors.push(err389);
}
errors++;
}
}
var valid66 = _errs424 === errors;
}
else {
var valid66 = true;
}
if(valid66){
if(data122.relation !== undefined){
let data133 = data122.relation;
const _errs435 = errors;
if(typeof data133 !== "string"){
const err390 = {instancePath:instancePath+"/edges/" + i12+"/relation",schemaPath:"#/properties/edges/items/anyOf/0/properties/relation/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err390];
}
else {
vErrors.push(err390);
}
errors++;
}
if(!(((((data133 === "input_to_turn") || (data133 === "turn_to_effect")) || (data133 === "turn_to_output")) || (data133 === "output_to_admission")) || (data133 === "effect_to_observation"))){
const err391 = {instancePath:instancePath+"/edges/" + i12+"/relation",schemaPath:"#/properties/edges/items/anyOf/0/properties/relation/enum",keyword:"enum",params:{allowedValues: schema31.properties.edges.items.anyOf[0].properties.relation.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err391];
}
else {
vErrors.push(err391);
}
errors++;
}
var valid66 = _errs435 === errors;
}
else {
var valid66 = true;
}
if(valid66){
if(data122.from_coverage !== undefined){
let data134 = data122.from_coverage;
const _errs437 = errors;
if(typeof data134 !== "string"){
const err392 = {instancePath:instancePath+"/edges/" + i12+"/from_coverage",schemaPath:"#/properties/edges/items/anyOf/0/properties/from_coverage/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err392];
}
else {
vErrors.push(err392);
}
errors++;
}
if(!(((data134 === "retained") || (data134 === "reclaimed")) || (data134 === "current_state"))){
const err393 = {instancePath:instancePath+"/edges/" + i12+"/from_coverage",schemaPath:"#/properties/edges/items/anyOf/0/properties/from_coverage/enum",keyword:"enum",params:{allowedValues: schema31.properties.edges.items.anyOf[0].properties.from_coverage.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err393];
}
else {
vErrors.push(err393);
}
errors++;
}
var valid66 = _errs437 === errors;
}
else {
var valid66 = true;
}
if(valid66){
if(data122.to_coverage !== undefined){
let data135 = data122.to_coverage;
const _errs439 = errors;
if(typeof data135 !== "string"){
const err394 = {instancePath:instancePath+"/edges/" + i12+"/to_coverage",schemaPath:"#/properties/edges/items/anyOf/0/properties/to_coverage/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err394];
}
else {
vErrors.push(err394);
}
errors++;
}
if(!(((data135 === "retained") || (data135 === "reclaimed")) || (data135 === "current_state"))){
const err395 = {instancePath:instancePath+"/edges/" + i12+"/to_coverage",schemaPath:"#/properties/edges/items/anyOf/0/properties/to_coverage/enum",keyword:"enum",params:{allowedValues: schema31.properties.edges.items.anyOf[0].properties.to_coverage.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err395];
}
else {
vErrors.push(err395);
}
errors++;
}
var valid66 = _errs439 === errors;
}
else {
var valid66 = true;
}
}
}
}
}
}
}
}
else {
const err396 = {instancePath:instancePath+"/edges/" + i12,schemaPath:"#/properties/edges/items/anyOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err396];
}
else {
vErrors.push(err396);
}
errors++;
}
}
var _valid37 = _errs410 === errors;
valid65 = valid65 || _valid37;
const _errs441 = errors;
if(data122 !== null){
const err397 = {instancePath:instancePath+"/edges/" + i12,schemaPath:"#/properties/edges/items/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err397];
}
else {
vErrors.push(err397);
}
errors++;
}
var _valid37 = _errs441 === errors;
valid65 = valid65 || _valid37;
if(!valid65){
const err398 = {instancePath:instancePath+"/edges/" + i12,schemaPath:"#/properties/edges/items/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err398];
}
else {
vErrors.push(err398);
}
errors++;
validate20.errors = vErrors;
return false;
}
else {
errors = _errs409;
if(vErrors !== null){
if(_errs409){
vErrors.length = _errs409;
}
else {
vErrors = null;
}
}
}
var valid64 = _errs408 === errors;
if(!valid64){
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
var valid0 = _errs406 === errors;
}
else {
var valid0 = true;
}
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

export const Capabilities = validate21;
const schema32 = {"type":"object","additionalProperties":false,"properties":{"version":{"type":"integer","minimum":0,"maximum":4294967295},"realm":{"type":"integer","minimum":0,"maximum":9007199254740991},"scope_pid":{"anyOf":[{"type":"integer","minimum":0,"maximum":9007199254740991},{"type":"null"}]},"read_only":{"type":"boolean"},"shared_principal":{"type":"boolean"},"page_size":{"type":"integer","minimum":0,"maximum":4294967295},"scan_limit":{"type":"integer","minimum":0,"maximum":4294967295},"max_edges":{"type":"integer","minimum":0,"maximum":4294967295},"min_refresh_ms":{"type":"integer","minimum":0,"maximum":4294967295},"max_request_bytes":{"type":"integer","minimum":0,"maximum":4294967295},"session_seconds":{"type":"integer","minimum":0,"maximum":4294967295},"station":{"type":"boolean"},"http_connector":{"type":"boolean"},"push":{"type":"boolean"}},"required":["version","realm","scope_pid","read_only","shared_principal","page_size","scan_limit","max_edges","min_refresh_ms","max_request_bytes","session_seconds","station","http_connector","push"]};

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
if(((((((((((((((data.version === undefined) && (missing0 = "version")) || ((data.realm === undefined) && (missing0 = "realm"))) || ((data.scope_pid === undefined) && (missing0 = "scope_pid"))) || ((data.read_only === undefined) && (missing0 = "read_only"))) || ((data.shared_principal === undefined) && (missing0 = "shared_principal"))) || ((data.page_size === undefined) && (missing0 = "page_size"))) || ((data.scan_limit === undefined) && (missing0 = "scan_limit"))) || ((data.max_edges === undefined) && (missing0 = "max_edges"))) || ((data.min_refresh_ms === undefined) && (missing0 = "min_refresh_ms"))) || ((data.max_request_bytes === undefined) && (missing0 = "max_request_bytes"))) || ((data.session_seconds === undefined) && (missing0 = "session_seconds"))) || ((data.station === undefined) && (missing0 = "station"))) || ((data.http_connector === undefined) && (missing0 = "http_connector"))) || ((data.push === undefined) && (missing0 = "push"))){
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
let data0 = data.version;
const _errs2 = errors;
if(!(((typeof data0 == "number") && (!(data0 % 1) && !isNaN(data0))) && (isFinite(data0)))){
validate21.errors = [{instancePath:instancePath+"/version",schemaPath:"#/properties/version/type",keyword:"type",params:{type: "integer"},message:"must be integer"}];
return false;
}
if(errors === _errs2){
if((typeof data0 == "number") && (isFinite(data0))){
if(data0 > 4294967295 || isNaN(data0)){
validate21.errors = [{instancePath:instancePath+"/version",schemaPath:"#/properties/version/maximum",keyword:"maximum",params:{comparison: "<=", limit: 4294967295},message:"must be <= 4294967295"}];
return false;
}
else {
if(data0 < 0 || isNaN(data0)){
validate21.errors = [{instancePath:instancePath+"/version",schemaPath:"#/properties/version/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"}];
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
validate21.errors = [{instancePath:instancePath+"/realm",schemaPath:"#/properties/realm/type",keyword:"type",params:{type: "integer"},message:"must be integer"}];
return false;
}
if(errors === _errs4){
if((typeof data1 == "number") && (isFinite(data1))){
if(data1 > 9007199254740991 || isNaN(data1)){
validate21.errors = [{instancePath:instancePath+"/realm",schemaPath:"#/properties/realm/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"}];
return false;
}
else {
if(data1 < 0 || isNaN(data1)){
validate21.errors = [{instancePath:instancePath+"/realm",schemaPath:"#/properties/realm/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"}];
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
validate21.errors = vErrors;
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
validate21.errors = [{instancePath:instancePath+"/read_only",schemaPath:"#/properties/read_only/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"}];
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
validate21.errors = [{instancePath:instancePath+"/shared_principal",schemaPath:"#/properties/shared_principal/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"}];
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
validate21.errors = [{instancePath:instancePath+"/page_size",schemaPath:"#/properties/page_size/type",keyword:"type",params:{type: "integer"},message:"must be integer"}];
return false;
}
if(errors === _errs16){
if((typeof data5 == "number") && (isFinite(data5))){
if(data5 > 4294967295 || isNaN(data5)){
validate21.errors = [{instancePath:instancePath+"/page_size",schemaPath:"#/properties/page_size/maximum",keyword:"maximum",params:{comparison: "<=", limit: 4294967295},message:"must be <= 4294967295"}];
return false;
}
else {
if(data5 < 0 || isNaN(data5)){
validate21.errors = [{instancePath:instancePath+"/page_size",schemaPath:"#/properties/page_size/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"}];
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
validate21.errors = [{instancePath:instancePath+"/scan_limit",schemaPath:"#/properties/scan_limit/type",keyword:"type",params:{type: "integer"},message:"must be integer"}];
return false;
}
if(errors === _errs18){
if((typeof data6 == "number") && (isFinite(data6))){
if(data6 > 4294967295 || isNaN(data6)){
validate21.errors = [{instancePath:instancePath+"/scan_limit",schemaPath:"#/properties/scan_limit/maximum",keyword:"maximum",params:{comparison: "<=", limit: 4294967295},message:"must be <= 4294967295"}];
return false;
}
else {
if(data6 < 0 || isNaN(data6)){
validate21.errors = [{instancePath:instancePath+"/scan_limit",schemaPath:"#/properties/scan_limit/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"}];
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
validate21.errors = [{instancePath:instancePath+"/max_edges",schemaPath:"#/properties/max_edges/type",keyword:"type",params:{type: "integer"},message:"must be integer"}];
return false;
}
if(errors === _errs20){
if((typeof data7 == "number") && (isFinite(data7))){
if(data7 > 4294967295 || isNaN(data7)){
validate21.errors = [{instancePath:instancePath+"/max_edges",schemaPath:"#/properties/max_edges/maximum",keyword:"maximum",params:{comparison: "<=", limit: 4294967295},message:"must be <= 4294967295"}];
return false;
}
else {
if(data7 < 0 || isNaN(data7)){
validate21.errors = [{instancePath:instancePath+"/max_edges",schemaPath:"#/properties/max_edges/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"}];
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
validate21.errors = [{instancePath:instancePath+"/min_refresh_ms",schemaPath:"#/properties/min_refresh_ms/type",keyword:"type",params:{type: "integer"},message:"must be integer"}];
return false;
}
if(errors === _errs22){
if((typeof data8 == "number") && (isFinite(data8))){
if(data8 > 4294967295 || isNaN(data8)){
validate21.errors = [{instancePath:instancePath+"/min_refresh_ms",schemaPath:"#/properties/min_refresh_ms/maximum",keyword:"maximum",params:{comparison: "<=", limit: 4294967295},message:"must be <= 4294967295"}];
return false;
}
else {
if(data8 < 0 || isNaN(data8)){
validate21.errors = [{instancePath:instancePath+"/min_refresh_ms",schemaPath:"#/properties/min_refresh_ms/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"}];
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
validate21.errors = [{instancePath:instancePath+"/max_request_bytes",schemaPath:"#/properties/max_request_bytes/type",keyword:"type",params:{type: "integer"},message:"must be integer"}];
return false;
}
if(errors === _errs24){
if((typeof data9 == "number") && (isFinite(data9))){
if(data9 > 4294967295 || isNaN(data9)){
validate21.errors = [{instancePath:instancePath+"/max_request_bytes",schemaPath:"#/properties/max_request_bytes/maximum",keyword:"maximum",params:{comparison: "<=", limit: 4294967295},message:"must be <= 4294967295"}];
return false;
}
else {
if(data9 < 0 || isNaN(data9)){
validate21.errors = [{instancePath:instancePath+"/max_request_bytes",schemaPath:"#/properties/max_request_bytes/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"}];
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
if(data.session_seconds !== undefined){
let data10 = data.session_seconds;
const _errs26 = errors;
if(!(((typeof data10 == "number") && (!(data10 % 1) && !isNaN(data10))) && (isFinite(data10)))){
validate21.errors = [{instancePath:instancePath+"/session_seconds",schemaPath:"#/properties/session_seconds/type",keyword:"type",params:{type: "integer"},message:"must be integer"}];
return false;
}
if(errors === _errs26){
if((typeof data10 == "number") && (isFinite(data10))){
if(data10 > 4294967295 || isNaN(data10)){
validate21.errors = [{instancePath:instancePath+"/session_seconds",schemaPath:"#/properties/session_seconds/maximum",keyword:"maximum",params:{comparison: "<=", limit: 4294967295},message:"must be <= 4294967295"}];
return false;
}
else {
if(data10 < 0 || isNaN(data10)){
validate21.errors = [{instancePath:instancePath+"/session_seconds",schemaPath:"#/properties/session_seconds/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"}];
return false;
}
}
}
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
validate21.errors = [{instancePath:instancePath+"/station",schemaPath:"#/properties/station/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"}];
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
validate21.errors = [{instancePath:instancePath+"/http_connector",schemaPath:"#/properties/http_connector/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"}];
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
validate21.errors = [{instancePath:instancePath+"/push",schemaPath:"#/properties/push/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"}];
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
validate21.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate21.errors = vErrors;
return errors === 0;
}
validate21.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

export const Error = validate22;
const schema33 = {"type":"object","additionalProperties":false,"properties":{"err":{"type":"string","enum":["Unauthorized","Forbidden","NotFound","InvalidQuery","QueryExpired","HistoryReclaimed","Unavailable","RateLimited","InvalidOrigin","UnsafePrincipal"]}},"required":["err"]};

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
if((data.err === undefined) && (missing0 = "err")){
validate22.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(key0 === "err")){
validate22.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.err !== undefined){
let data0 = data.err;
if(typeof data0 !== "string"){
validate22.errors = [{instancePath:instancePath+"/err",schemaPath:"#/properties/err/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
if(!((((((((((data0 === "Unauthorized") || (data0 === "Forbidden")) || (data0 === "NotFound")) || (data0 === "InvalidQuery")) || (data0 === "QueryExpired")) || (data0 === "HistoryReclaimed")) || (data0 === "Unavailable")) || (data0 === "RateLimited")) || (data0 === "InvalidOrigin")) || (data0 === "UnsafePrincipal"))){
validate22.errors = [{instancePath:instancePath+"/err",schemaPath:"#/properties/err/enum",keyword:"enum",params:{allowedValues: schema33.properties.err.enum},message:"must be equal to one of the allowed values"}];
return false;
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

export const Session = validate23;
const schema34 = {"type":"object","additionalProperties":false,"properties":{"expires_in":{"type":"integer","minimum":0,"maximum":4294967295}},"required":["expires_in"]};

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
if((data.expires_in === undefined) && (missing0 = "expires_in")){
validate23.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(key0 === "expires_in")){
validate23.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.expires_in !== undefined){
let data0 = data.expires_in;
const _errs2 = errors;
if(!(((typeof data0 == "number") && (!(data0 % 1) && !isNaN(data0))) && (isFinite(data0)))){
validate23.errors = [{instancePath:instancePath+"/expires_in",schemaPath:"#/properties/expires_in/type",keyword:"type",params:{type: "integer"},message:"must be integer"}];
return false;
}
if(errors === _errs2){
if((typeof data0 == "number") && (isFinite(data0))){
if(data0 > 4294967295 || isNaN(data0)){
validate23.errors = [{instancePath:instancePath+"/expires_in",schemaPath:"#/properties/expires_in/maximum",keyword:"maximum",params:{comparison: "<=", limit: 4294967295},message:"must be <= 4294967295"}];
return false;
}
else {
if(data0 < 0 || isNaN(data0)){
validate23.errors = [{instancePath:instancePath+"/expires_in",schemaPath:"#/properties/expires_in/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"}];
return false;
}
}
}
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
