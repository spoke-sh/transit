// Generated; no runtime code generation or eval.
import lengthModule from "ajv/dist/runtime/ucs2length.js";
const ucs2length = lengthModule.default ?? lengthModule;
"use strict";
export const Response = validate157;
const schema64 = {"type":"object","additionalProperties":false,"properties":{"observation":{"type":"object","additionalProperties":false,"properties":{"version":{"$ref":"https://transit.invalid/generated-validator/0"},"realm":{"$ref":"https://transit.invalid/generated-validator/1"},"resource":{"type":"string","enum":["processes","process","mailbox","outbox","effects","payloads","history"]},"pid":{"$ref":"https://transit.invalid/generated-validator/2"},"cut":{"$ref":"https://transit.invalid/generated-validator/3"},"reader":{"$ref":"https://transit.invalid/generated-validator/5"},"next":{"$ref":"https://transit.invalid/generated-validator/2"},"complete":{"type":"boolean"},"history":{"type":"string","enum":["retained","prefix_reclaimed"]},"last_collection":{"$ref":"https://transit.invalid/generated-validator/2"},"scanned":{"$ref":"https://transit.invalid/generated-validator/4"},"processes":{"$ref":"https://transit.invalid/generated-validator/28"},"events":{"type":"array","minItems":8,"maxItems":8,"items":{"anyOf":[{"type":"object","additionalProperties":false,"properties":{"position":{"$ref":"https://transit.invalid/generated-validator/1"},"pid":{"$ref":"https://transit.invalid/generated-validator/1"},"kind":{"type":"string","enum":["authorization","grant","revoke","spawn","own","retry","send","begin_turn","turn","terminate","expire","create_resource","grant_resource","associate","open_view","close_view","retire_resource","expire_resource","reclaim_resource","deliver","dispatch","observe","close_effect","cancel_effect","checkpoint","storage_fence","storage_compact","turn_with_versions","rotate_worker","create_principal","runtime_intent","runtime_observe","runtime_upgrade","activate","create","initialize","suspend","resume","expire_suspension","declare_payload","payload_ready","retire_payload","payload_deleted","collect"]},"policy_revision":{"$ref":"https://transit.invalid/generated-validator/1"},"input":{"$ref":"https://transit.invalid/generated-validator/2"},"effect":{"$ref":"https://transit.invalid/generated-validator/2"},"output":{"$ref":"https://transit.invalid/generated-validator/2"},"value":{"$ref":"https://transit.invalid/generated-validator/22"},"failed":{"type":"boolean"},"generation":{"$ref":"https://transit.invalid/generated-validator/2"},"mailbox_status":{"anyOf":[{"type":"string","enum":["pending","consumed","cancelled"]},{"type":"null"}]},"admitted":{"type":"boolean"},"unix_ms":{"$ref":"https://transit.invalid/generated-validator/2"},"clock_error_ms":{"anyOf":[{"$ref":"https://transit.invalid/generated-validator/0"},{"type":"null"}]}},"required":["position","pid","kind","policy_revision","input","effect","output","value","failed","generation","mailbox_status","admitted","unix_ms","clock_error_ms"]},{"type":"null"}]}},"outbox":{"type":"array","minItems":8,"maxItems":8,"items":{"anyOf":[{"type":"object","additionalProperties":false,"properties":{"id":{"$ref":"https://transit.invalid/generated-validator/1"},"source":{"$ref":"https://transit.invalid/generated-validator/1"},"turn":{"$ref":"https://transit.invalid/generated-validator/1"},"index":{"$ref":"https://transit.invalid/generated-validator/9"},"destination":{"$ref":"https://transit.invalid/generated-validator/1"},"value":{"$ref":"https://transit.invalid/generated-validator/21"},"phase":{"type":"string","enum":["pending","delivered","denied","expired","retired","cancelled"]},"resolved_at":{"$ref":"https://transit.invalid/generated-validator/2"},"courier":{"$ref":"https://transit.invalid/generated-validator/2"},"policy_revision":{"$ref":"https://transit.invalid/generated-validator/2"}},"required":["id","source","turn","index","destination","value","phase","resolved_at","courier","policy_revision"]},{"type":"null"}]}},"effects":{"type":"array","minItems":8,"maxItems":8,"items":{"anyOf":[{"type":"object","additionalProperties":false,"properties":{"id":{"$ref":"https://transit.invalid/generated-validator/1"},"pid":{"$ref":"https://transit.invalid/generated-validator/1"},"payload":{"$ref":"https://transit.invalid/generated-validator/21"},"phase":{"type":"string","enum":["pending","authorized","unknown","observed","cancelled","closed_unknown"]},"attempt":{"$ref":"https://transit.invalid/generated-validator/2"},"executor":{"$ref":"https://transit.invalid/generated-validator/2"},"authorization_policy":{"$ref":"https://transit.invalid/generated-validator/2"},"last_observation":{"anyOf":[{"type":"object","additionalProperties":false,"properties":{"input":{"$ref":"https://transit.invalid/generated-validator/1"},"policy_revision":{"$ref":"https://transit.invalid/generated-validator/1"}},"required":["input","policy_revision"]},{"type":"null"}]},"closure":{"anyOf":[{"type":"object","additionalProperties":false,"properties":{"reason":{"type":"string","enum":["observed","observation_budget","abandoned","deadline","unattempted_cancel"]},"principal":{"$ref":"https://transit.invalid/generated-validator/1"},"policy_revision":{"$ref":"https://transit.invalid/generated-validator/1"},"clock_lower_ms":{"$ref":"https://transit.invalid/generated-validator/2"}},"required":["reason","principal","policy_revision","clock_lower_ms"]},{"type":"null"}]},"result":{"$ref":"https://transit.invalid/generated-validator/22"},"closed_at":{"$ref":"https://transit.invalid/generated-validator/2"},"reconcile_before_ms":{"$ref":"https://transit.invalid/generated-validator/2"},"max_observations":{"$ref":"https://transit.invalid/generated-validator/4"},"observations":{"$ref":"https://transit.invalid/generated-validator/4"}},"required":["id","pid","payload","phase","attempt","executor","authorization_policy","last_observation","closure","result","closed_at","reconcile_before_ms","max_observations","observations"]},{"type":"null"}]}},"payloads":{"type":"array","minItems":8,"maxItems":8,"items":{"anyOf":[{"type":"object","additionalProperties":false,"properties":{"id":{"$ref":"https://transit.invalid/generated-validator/1"},"pid":{"$ref":"https://transit.invalid/generated-validator/1"},"publisher":{"$ref":"https://transit.invalid/generated-validator/1"},"sha256":{"$ref":"https://transit.invalid/generated-validator/11"},"bytes":{"$ref":"https://transit.invalid/generated-validator/0"},"allow_delete":{"type":"boolean"},"phase":{"type":"string","enum":["creating","ready","retiring","deleted"]},"retired_at":{"$ref":"https://transit.invalid/generated-validator/2"},"deleted_at":{"$ref":"https://transit.invalid/generated-validator/2"}},"required":["id","pid","publisher","sha256","bytes","allow_delete","phase","retired_at","deleted_at"]},{"type":"null"}]}}},"required":["version","realm","resource","pid","cut","reader","next","complete","history","last_collection","scanned","processes","events","outbox","effects","payloads"]},"edges":{"type":"array","minItems":16,"maxItems":16,"items":{"anyOf":[{"type":"object","additionalProperties":false,"properties":{"from":{"$ref":"https://transit.invalid/generated-validator/30"},"to":{"$ref":"https://transit.invalid/generated-validator/30"},"relation":{"type":"string","enum":["input_to_turn","turn_to_effect","turn_to_output","output_to_admission","effect_to_observation"]},"from_coverage":{"$ref":"https://transit.invalid/generated-validator/31"},"to_coverage":{"$ref":"https://transit.invalid/generated-validator/31"}},"required":["from","to","relation","from_coverage","to_coverage"]},{"type":"null"}]}},"effect_diagnostics":{"type":"array","minItems":8,"maxItems":8,"items":{"$ref":"https://transit.invalid/generated-validator/67"}}},"required":["observation","edges","effect_diagnostics"]};
const func1 = Object.prototype.hasOwnProperty;
const schema24 = {"type":"integer","minimum":0,"maximum":4294967295};

function validate59(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate59.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(!(((typeof data == "number") && (!(data % 1) && !isNaN(data))) && (isFinite(data)))){
validate59.errors = [{}];
return false;
}
if(errors === 0){
if((typeof data == "number") && (isFinite(data))){
if(data > 4294967295 || isNaN(data)){
validate59.errors = [{}];
return false;
}
else {
if(data < 0 || isNaN(data)){
validate59.errors = [{}];
return false;
}
}
}
}
validate59.errors = vErrors;
return errors === 0;
}
validate59.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema22 = {"type":"integer","minimum":0,"maximum":9007199254740991};

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
if(!(((typeof data == "number") && (!(data % 1) && !isNaN(data))) && (isFinite(data)))){
validate56.errors = [{}];
return false;
}
if(errors === 0){
if((typeof data == "number") && (isFinite(data))){
if(data > 9007199254740991 || isNaN(data)){
validate56.errors = [{}];
return false;
}
else {
if(data < 0 || isNaN(data)){
validate56.errors = [{}];
return false;
}
}
}
}
validate56.errors = vErrors;
return errors === 0;
}
validate56.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema25 = {"anyOf":[{"$ref":"https://transit.invalid/generated-validator/1"},{"type":"null"}]};

function validate62(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate62.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate56(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var _valid0 = _errs1 === errors;
valid0 = valid0 || _valid0;
const _errs2 = errors;
if(data !== null){
const err0 = {};
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
const err1 = {};
if(vErrors === null){
vErrors = [err1];
}
else {
vErrors.push(err1);
}
errors++;
validate62.errors = vErrors;
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
validate62.errors = vErrors;
return errors === 0;
}
validate62.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema65 = {"type":"object","additionalProperties":false,"properties":{"position":{"$ref":"https://transit.invalid/generated-validator/1"},"policy_revision":{"$ref":"https://transit.invalid/generated-validator/1"},"retained_from":{"$ref":"https://transit.invalid/generated-validator/1"}},"required":["position","policy_revision","retained_from"]};

function validate161(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate161.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((((data.position === undefined) && (missing0 = "position")) || ((data.policy_revision === undefined) && (missing0 = "policy_revision"))) || ((data.retained_from === undefined) && (missing0 = "retained_from"))){
validate161.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "position") || (key0 === "policy_revision")) || (key0 === "retained_from"))){
validate161.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.position !== undefined){
const _errs2 = errors;
if(!(validate56(data.position, {instancePath:instancePath+"/position",parentData:data,parentDataProperty:"position",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.policy_revision !== undefined){
const _errs3 = errors;
if(!(validate56(data.policy_revision, {instancePath:instancePath+"/policy_revision",parentData:data,parentDataProperty:"policy_revision",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid0 = _errs3 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.retained_from !== undefined){
const _errs4 = errors;
if(!(validate56(data.retained_from, {instancePath:instancePath+"/retained_from",parentData:data,parentDataProperty:"retained_from",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid0 = _errs4 === errors;
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
validate161.errors = [{}];
return false;
}
}
validate161.errors = vErrors;
return errors === 0;
}
validate161.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema66 = {"type":"object","additionalProperties":false,"properties":{"principal":{"$ref":"https://transit.invalid/generated-validator/1"},"permissions":{"$ref":"https://transit.invalid/generated-validator/4"},"pid":{"$ref":"https://transit.invalid/generated-validator/2"},"policy_revision":{"$ref":"https://transit.invalid/generated-validator/1"}},"required":["principal","permissions","pid","policy_revision"]};
const schema67 = {"type":"integer","minimum":0,"maximum":65535};

function validate168(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate168.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(!(((typeof data == "number") && (!(data % 1) && !isNaN(data))) && (isFinite(data)))){
validate168.errors = [{}];
return false;
}
if(errors === 0){
if((typeof data == "number") && (isFinite(data))){
if(data > 65535 || isNaN(data)){
validate168.errors = [{}];
return false;
}
else {
if(data < 0 || isNaN(data)){
validate168.errors = [{}];
return false;
}
}
}
}
validate168.errors = vErrors;
return errors === 0;
}
validate168.evaluated = {"dynamicProps":false,"dynamicItems":false};


function validate166(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate166.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if(((((data.principal === undefined) && (missing0 = "principal")) || ((data.permissions === undefined) && (missing0 = "permissions"))) || ((data.pid === undefined) && (missing0 = "pid"))) || ((data.policy_revision === undefined) && (missing0 = "policy_revision"))){
validate166.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((((key0 === "principal") || (key0 === "permissions")) || (key0 === "pid")) || (key0 === "policy_revision"))){
validate166.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.principal !== undefined){
const _errs2 = errors;
if(!(validate56(data.principal, {instancePath:instancePath+"/principal",parentData:data,parentDataProperty:"principal",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.permissions !== undefined){
const _errs3 = errors;
if(!(validate168(data.permissions, {instancePath:instancePath+"/permissions",parentData:data,parentDataProperty:"permissions",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate168.errors : vErrors.concat(validate168.errors);
errors = vErrors.length;
}
var valid0 = _errs3 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.pid !== undefined){
const _errs4 = errors;
if(!(validate62(data.pid, {instancePath:instancePath+"/pid",parentData:data,parentDataProperty:"pid",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate62.errors : vErrors.concat(validate62.errors);
errors = vErrors.length;
}
var valid0 = _errs4 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.policy_revision !== undefined){
const _errs5 = errors;
if(!(validate56(data.policy_revision, {instancePath:instancePath+"/policy_revision",parentData:data,parentDataProperty:"policy_revision",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid0 = _errs5 === errors;
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
else {
validate166.errors = [{}];
return false;
}
}
validate166.errors = vErrors;
return errors === 0;
}
validate166.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema68 = {"type":"array","minItems":8,"maxItems":8,"items":{"$ref":"https://transit.invalid/generated-validator/27"}};
const schema69 = {"anyOf":[{"$ref":"https://transit.invalid/generated-validator/26"},{"type":"null"}]};
const schema70 = {"type":"object","additionalProperties":false,"properties":{"allow_collection":{"type":"boolean"},"pid":{"$ref":"https://transit.invalid/generated-validator/1"},"code":{"$ref":"https://transit.invalid/generated-validator/0"},"owner":{"$ref":"https://transit.invalid/generated-validator/2"},"generation":{"$ref":"https://transit.invalid/generated-validator/1"},"revision":{"$ref":"https://transit.invalid/generated-validator/1"},"lifecycle":{"$ref":"https://transit.invalid/generated-validator/6"},"failure":{"$ref":"https://transit.invalid/generated-validator/2"},"admitted":{"$ref":"https://transit.invalid/generated-validator/1"},"consumed":{"$ref":"https://transit.invalid/generated-validator/1"},"cancelled":{"$ref":"https://transit.invalid/generated-validator/1"},"work_before_ms":{"$ref":"https://transit.invalid/generated-validator/2"},"settle_before_ms":{"$ref":"https://transit.invalid/generated-validator/2"},"turn_permit":{"$ref":"https://transit.invalid/generated-validator/8"},"binding":{"$ref":"https://transit.invalid/generated-validator/19"},"control":{"$ref":"https://transit.invalid/generated-validator/25"}},"required":["allow_collection","pid","code","owner","generation","revision","lifecycle","failure","admitted","consumed","cancelled","work_before_ms","settle_before_ms","turn_permit","binding","control"]};
const schema71 = {"type":"string","enum":["running","terminated","expired"]};

function validate184(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate184.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate184.errors = [{}];
return false;
}
if(!(((data === "running") || (data === "terminated")) || (data === "expired"))){
validate184.errors = [{}];
return false;
}
validate184.errors = vErrors;
return errors === 0;
}
validate184.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema72 = {"anyOf":[{"$ref":"https://transit.invalid/generated-validator/7"},{"type":"null"}]};
const schema73 = {"type":"object","additionalProperties":false,"properties":{"id":{"$ref":"https://transit.invalid/generated-validator/1"},"input":{"$ref":"https://transit.invalid/generated-validator/1"}},"required":["id","input"]};

function validate193(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate193.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if(((data.id === undefined) && (missing0 = "id")) || ((data.input === undefined) && (missing0 = "input"))){
validate193.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "id") || (key0 === "input"))){
validate193.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.id !== undefined){
const _errs2 = errors;
if(!(validate56(data.id, {instancePath:instancePath+"/id",parentData:data,parentDataProperty:"id",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.input !== undefined){
const _errs3 = errors;
if(!(validate56(data.input, {instancePath:instancePath+"/input",parentData:data,parentDataProperty:"input",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid0 = _errs3 === errors;
}
else {
var valid0 = true;
}
}
}
}
}
else {
validate193.errors = [{}];
return false;
}
}
validate193.errors = vErrors;
return errors === 0;
}
validate193.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate192(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate192.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate193(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate193.errors : vErrors.concat(validate193.errors);
errors = vErrors.length;
}
var _valid0 = _errs1 === errors;
valid0 = valid0 || _valid0;
if(_valid0){
var props0 = true;
}
const _errs2 = errors;
if(data !== null){
const err0 = {};
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
const err1 = {};
if(vErrors === null){
vErrors = [err1];
}
else {
vErrors.push(err1);
}
errors++;
validate192.errors = vErrors;
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
validate192.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate192.evaluated = {"dynamicProps":true,"dynamicItems":false};

const schema74 = {"anyOf":[{"$ref":"https://transit.invalid/generated-validator/18"},{"type":"null"}]};
const schema75 = {"type":"object","additionalProperties":false,"properties":{"revision":{"$ref":"https://transit.invalid/generated-validator/1"},"operation":{"$ref":"https://transit.invalid/generated-validator/1"},"instance":{"$ref":"https://transit.invalid/generated-validator/10"},"resource":{"$ref":"https://transit.invalid/generated-validator/11"},"workload":{"$ref":"https://transit.invalid/generated-validator/11"},"incarnation":{"$ref":"https://transit.invalid/generated-validator/12"},"desired":{"$ref":"https://transit.invalid/generated-validator/13"},"phase":{"$ref":"https://transit.invalid/generated-validator/14"},"upgrade_from":{"$ref":"https://transit.invalid/generated-validator/15"},"activation":{"$ref":"https://transit.invalid/generated-validator/17"},"last_worker_incarnation":{"$ref":"https://transit.invalid/generated-validator/12"}},"required":["revision","operation","instance","resource","workload","incarnation","desired","phase","activation","last_worker_incarnation"]};
const schema76 = {"type":"array","minItems":16,"maxItems":16,"items":{"$ref":"https://transit.invalid/generated-validator/9"}};
const schema58 = {"type":"integer","minimum":0,"maximum":255};

function validate134(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate134.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(!(((typeof data == "number") && (!(data % 1) && !isNaN(data))) && (isFinite(data)))){
validate134.errors = [{}];
return false;
}
if(errors === 0){
if((typeof data == "number") && (isFinite(data))){
if(data > 255 || isNaN(data)){
validate134.errors = [{}];
return false;
}
else {
if(data < 0 || isNaN(data)){
validate134.errors = [{}];
return false;
}
}
}
}
validate134.errors = vErrors;
return errors === 0;
}
validate134.evaluated = {"dynamicProps":false,"dynamicItems":false};


function validate202(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate202.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(Array.isArray(data)){
if(data.length > 16){
validate202.errors = [{}];
return false;
}
else {
if(data.length < 16){
validate202.errors = [{}];
return false;
}
else {
var valid0 = true;
const len0 = data.length;
for(let i0=0; i0<len0; i0++){
const _errs1 = errors;
if(!(validate134(data[i0], {instancePath:instancePath+"/" + i0,parentData:data,parentDataProperty:i0,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate134.errors : vErrors.concat(validate134.errors);
errors = vErrors.length;
}
var valid0 = _errs1 === errors;
if(!valid0){
break;
}
}
}
}
}
else {
validate202.errors = [{}];
return false;
}
}
validate202.errors = vErrors;
return errors === 0;
}
validate202.evaluated = {"items":true,"dynamicProps":false,"dynamicItems":false};

const schema57 = {"type":"array","minItems":32,"maxItems":32,"items":{"$ref":"https://transit.invalid/generated-validator/9"}};

function validate133(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate133.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(Array.isArray(data)){
if(data.length > 32){
validate133.errors = [{}];
return false;
}
else {
if(data.length < 32){
validate133.errors = [{}];
return false;
}
else {
var valid0 = true;
const len0 = data.length;
for(let i0=0; i0<len0; i0++){
const _errs1 = errors;
if(!(validate134(data[i0], {instancePath:instancePath+"/" + i0,parentData:data,parentDataProperty:i0,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate134.errors : vErrors.concat(validate134.errors);
errors = vErrors.length;
}
var valid0 = _errs1 === errors;
if(!valid0){
break;
}
}
}
}
}
else {
validate133.errors = [{}];
return false;
}
}
validate133.errors = vErrors;
return errors === 0;
}
validate133.evaluated = {"items":true,"dynamicProps":false,"dynamicItems":false};

const schema77 = {"anyOf":[{"$ref":"https://transit.invalid/generated-validator/10"},{"type":"null"}]};

function validate207(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate207.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate202(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate202.errors : vErrors.concat(validate202.errors);
errors = vErrors.length;
}
var _valid0 = _errs1 === errors;
valid0 = valid0 || _valid0;
if(_valid0){
var items0 = true;
}
const _errs2 = errors;
if(data !== null){
const err0 = {};
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
const err1 = {};
if(vErrors === null){
vErrors = [err1];
}
else {
vErrors.push(err1);
}
errors++;
validate207.errors = vErrors;
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
validate207.errors = vErrors;
evaluated0.items = items0;
return errors === 0;
}
validate207.evaluated = {"dynamicProps":false,"dynamicItems":true};

const schema78 = {"type":"string","enum":["running","stopped"]};

function validate210(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate210.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate210.errors = [{}];
return false;
}
if(!((data === "running") || (data === "stopped"))){
validate210.errors = [{}];
return false;
}
validate210.errors = vErrors;
return errors === 0;
}
validate210.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema79 = {"type":"string","enum":["pending","unknown","ready","stopped"]};

function validate212(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate212.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate212.errors = [{}];
return false;
}
if(!((((data === "pending") || (data === "unknown")) || (data === "ready")) || (data === "stopped"))){
validate212.errors = [{}];
return false;
}
validate212.errors = vErrors;
return errors === 0;
}
validate212.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema80 = {"anyOf":[{"$ref":"https://transit.invalid/generated-validator/11"},{"type":"null"}]};

function validate214(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate214.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate133(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate133.errors : vErrors.concat(validate133.errors);
errors = vErrors.length;
}
var _valid0 = _errs1 === errors;
valid0 = valid0 || _valid0;
if(_valid0){
var items0 = true;
}
const _errs2 = errors;
if(data !== null){
const err0 = {};
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
const err1 = {};
if(vErrors === null){
vErrors = [err1];
}
else {
vErrors.push(err1);
}
errors++;
validate214.errors = vErrors;
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
validate214.errors = vErrors;
evaluated0.items = items0;
return errors === 0;
}
validate214.evaluated = {"dynamicProps":false,"dynamicItems":true};

const schema81 = {"anyOf":[{"$ref":"https://transit.invalid/generated-validator/16"},{"type":"null"}]};
const schema82 = {"type":"object","additionalProperties":false,"properties":{"worker_incarnation":{"$ref":"https://transit.invalid/generated-validator/10"},"generation":{"$ref":"https://transit.invalid/generated-validator/1"}},"required":["worker_incarnation","generation"]};

function validate218(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate218.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if(((data.worker_incarnation === undefined) && (missing0 = "worker_incarnation")) || ((data.generation === undefined) && (missing0 = "generation"))){
validate218.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "worker_incarnation") || (key0 === "generation"))){
validate218.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.worker_incarnation !== undefined){
const _errs2 = errors;
if(!(validate202(data.worker_incarnation, {instancePath:instancePath+"/worker_incarnation",parentData:data,parentDataProperty:"worker_incarnation",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate202.errors : vErrors.concat(validate202.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.generation !== undefined){
const _errs3 = errors;
if(!(validate56(data.generation, {instancePath:instancePath+"/generation",parentData:data,parentDataProperty:"generation",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid0 = _errs3 === errors;
}
else {
var valid0 = true;
}
}
}
}
}
else {
validate218.errors = [{}];
return false;
}
}
validate218.errors = vErrors;
return errors === 0;
}
validate218.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate217(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate217.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate218(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate218.errors : vErrors.concat(validate218.errors);
errors = vErrors.length;
}
var _valid0 = _errs1 === errors;
valid0 = valid0 || _valid0;
if(_valid0){
var props0 = true;
}
const _errs2 = errors;
if(data !== null){
const err0 = {};
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
const err1 = {};
if(vErrors === null){
vErrors = [err1];
}
else {
vErrors.push(err1);
}
errors++;
validate217.errors = vErrors;
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
validate217.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate217.evaluated = {"dynamicProps":true,"dynamicItems":false};


function validate199(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate199.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if(((((((((((data.revision === undefined) && (missing0 = "revision")) || ((data.operation === undefined) && (missing0 = "operation"))) || ((data.instance === undefined) && (missing0 = "instance"))) || ((data.resource === undefined) && (missing0 = "resource"))) || ((data.workload === undefined) && (missing0 = "workload"))) || ((data.incarnation === undefined) && (missing0 = "incarnation"))) || ((data.desired === undefined) && (missing0 = "desired"))) || ((data.phase === undefined) && (missing0 = "phase"))) || ((data.activation === undefined) && (missing0 = "activation"))) || ((data.last_worker_incarnation === undefined) && (missing0 = "last_worker_incarnation"))){
validate199.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(func1.call(schema75.properties, key0))){
validate199.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.revision !== undefined){
const _errs2 = errors;
if(!(validate56(data.revision, {instancePath:instancePath+"/revision",parentData:data,parentDataProperty:"revision",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.operation !== undefined){
const _errs3 = errors;
if(!(validate56(data.operation, {instancePath:instancePath+"/operation",parentData:data,parentDataProperty:"operation",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid0 = _errs3 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.instance !== undefined){
const _errs4 = errors;
if(!(validate202(data.instance, {instancePath:instancePath+"/instance",parentData:data,parentDataProperty:"instance",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate202.errors : vErrors.concat(validate202.errors);
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
if(!(validate133(data.resource, {instancePath:instancePath+"/resource",parentData:data,parentDataProperty:"resource",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate133.errors : vErrors.concat(validate133.errors);
errors = vErrors.length;
}
var valid0 = _errs5 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.workload !== undefined){
const _errs6 = errors;
if(!(validate133(data.workload, {instancePath:instancePath+"/workload",parentData:data,parentDataProperty:"workload",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate133.errors : vErrors.concat(validate133.errors);
errors = vErrors.length;
}
var valid0 = _errs6 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.incarnation !== undefined){
const _errs7 = errors;
if(!(validate207(data.incarnation, {instancePath:instancePath+"/incarnation",parentData:data,parentDataProperty:"incarnation",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate207.errors : vErrors.concat(validate207.errors);
errors = vErrors.length;
}
var valid0 = _errs7 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.desired !== undefined){
const _errs8 = errors;
if(!(validate210(data.desired, {instancePath:instancePath+"/desired",parentData:data,parentDataProperty:"desired",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate210.errors : vErrors.concat(validate210.errors);
errors = vErrors.length;
}
var valid0 = _errs8 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.phase !== undefined){
const _errs9 = errors;
if(!(validate212(data.phase, {instancePath:instancePath+"/phase",parentData:data,parentDataProperty:"phase",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate212.errors : vErrors.concat(validate212.errors);
errors = vErrors.length;
}
var valid0 = _errs9 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.upgrade_from !== undefined){
const _errs10 = errors;
if(!(validate214(data.upgrade_from, {instancePath:instancePath+"/upgrade_from",parentData:data,parentDataProperty:"upgrade_from",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate214.errors : vErrors.concat(validate214.errors);
errors = vErrors.length;
}
var valid0 = _errs10 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.activation !== undefined){
const _errs11 = errors;
if(!(validate217(data.activation, {instancePath:instancePath+"/activation",parentData:data,parentDataProperty:"activation",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate217.errors : vErrors.concat(validate217.errors);
errors = vErrors.length;
}
var valid0 = _errs11 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.last_worker_incarnation !== undefined){
const _errs12 = errors;
if(!(validate207(data.last_worker_incarnation, {instancePath:instancePath+"/last_worker_incarnation",parentData:data,parentDataProperty:"last_worker_incarnation",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate207.errors : vErrors.concat(validate207.errors);
errors = vErrors.length;
}
var valid0 = _errs12 === errors;
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
else {
validate199.errors = [{}];
return false;
}
}
validate199.errors = vErrors;
return errors === 0;
}
validate199.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate198(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate198.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate199(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate199.errors : vErrors.concat(validate199.errors);
errors = vErrors.length;
}
var _valid0 = _errs1 === errors;
valid0 = valid0 || _valid0;
if(_valid0){
var props0 = true;
}
const _errs2 = errors;
if(data !== null){
const err0 = {};
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
const err1 = {};
if(vErrors === null){
vErrors = [err1];
}
else {
vErrors.push(err1);
}
errors++;
validate198.errors = vErrors;
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
validate198.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate198.evaluated = {"dynamicProps":true,"dynamicItems":false};

const schema83 = {"anyOf":[{"$ref":"https://transit.invalid/generated-validator/24"},{"type":"null"}]};
const schema84 = {"type":"object","additionalProperties":false,"properties":{"phase":{"$ref":"https://transit.invalid/generated-validator/20"},"required":{"$ref":"https://transit.invalid/generated-validator/23"},"resume_before_ms":{"$ref":"https://transit.invalid/generated-validator/2"}},"required":["phase","required","resume_before_ms"]};
const schema85 = {"type":"string","enum":["initializing","ready","suspended"]};

function validate228(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate228.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate228.errors = [{}];
return false;
}
if(!(((data === "initializing") || (data === "ready")) || (data === "suspended"))){
validate228.errors = [{}];
return false;
}
validate228.errors = vErrors;
return errors === 0;
}
validate228.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema86 = {"type":"array","minItems":4,"maxItems":4,"items":{"$ref":"https://transit.invalid/generated-validator/22"}};
const schema87 = {"anyOf":[{"$ref":"https://transit.invalid/generated-validator/21"},{"type":"null"}]};
const schema88 = {"type":"string","pattern":"^(?:[0-9a-f]{2})*$","maxLength":512};
const func3 = ucs2length;
const pattern5 = new RegExp("^(?:[0-9a-f]{2})*$", "u");

function validate232(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate232.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(typeof data === "string"){
if(func3(data) > 512){
validate232.errors = [{}];
return false;
}
else {
if(!pattern5.test(data)){
validate232.errors = [{}];
return false;
}
}
}
else {
validate232.errors = [{}];
return false;
}
}
validate232.errors = vErrors;
return errors === 0;
}
validate232.evaluated = {"dynamicProps":false,"dynamicItems":false};


function validate231(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate231.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate232(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate232.errors : vErrors.concat(validate232.errors);
errors = vErrors.length;
}
var _valid0 = _errs1 === errors;
valid0 = valid0 || _valid0;
const _errs2 = errors;
if(data !== null){
const err0 = {};
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
const err1 = {};
if(vErrors === null){
vErrors = [err1];
}
else {
vErrors.push(err1);
}
errors++;
validate231.errors = vErrors;
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
validate231.errors = vErrors;
return errors === 0;
}
validate231.evaluated = {"dynamicProps":false,"dynamicItems":false};


function validate230(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate230.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(Array.isArray(data)){
if(data.length > 4){
validate230.errors = [{}];
return false;
}
else {
if(data.length < 4){
validate230.errors = [{}];
return false;
}
else {
var valid0 = true;
const len0 = data.length;
for(let i0=0; i0<len0; i0++){
const _errs1 = errors;
if(!(validate231(data[i0], {instancePath:instancePath+"/" + i0,parentData:data,parentDataProperty:i0,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate231.errors : vErrors.concat(validate231.errors);
errors = vErrors.length;
}
var valid0 = _errs1 === errors;
if(!valid0){
break;
}
}
}
}
}
else {
validate230.errors = [{}];
return false;
}
}
validate230.errors = vErrors;
return errors === 0;
}
validate230.evaluated = {"items":true,"dynamicProps":false,"dynamicItems":false};


function validate227(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate227.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((((data.phase === undefined) && (missing0 = "phase")) || ((data.required === undefined) && (missing0 = "required"))) || ((data.resume_before_ms === undefined) && (missing0 = "resume_before_ms"))){
validate227.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "phase") || (key0 === "required")) || (key0 === "resume_before_ms"))){
validate227.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.phase !== undefined){
const _errs2 = errors;
if(!(validate228(data.phase, {instancePath:instancePath+"/phase",parentData:data,parentDataProperty:"phase",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate228.errors : vErrors.concat(validate228.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.required !== undefined){
const _errs3 = errors;
if(!(validate230(data.required, {instancePath:instancePath+"/required",parentData:data,parentDataProperty:"required",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate230.errors : vErrors.concat(validate230.errors);
errors = vErrors.length;
}
var valid0 = _errs3 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.resume_before_ms !== undefined){
const _errs4 = errors;
if(!(validate62(data.resume_before_ms, {instancePath:instancePath+"/resume_before_ms",parentData:data,parentDataProperty:"resume_before_ms",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate62.errors : vErrors.concat(validate62.errors);
errors = vErrors.length;
}
var valid0 = _errs4 === errors;
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
validate227.errors = [{}];
return false;
}
}
validate227.errors = vErrors;
return errors === 0;
}
validate227.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate226(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate226.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate227(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate227.errors : vErrors.concat(validate227.errors);
errors = vErrors.length;
}
var _valid0 = _errs1 === errors;
valid0 = valid0 || _valid0;
if(_valid0){
var props0 = true;
}
const _errs2 = errors;
if(data !== null){
const err0 = {};
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
const err1 = {};
if(vErrors === null){
vErrors = [err1];
}
else {
vErrors.push(err1);
}
errors++;
validate226.errors = vErrors;
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
validate226.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate226.evaluated = {"dynamicProps":true,"dynamicItems":false};


function validate178(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate178.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if(((((((((((((((((data.allow_collection === undefined) && (missing0 = "allow_collection")) || ((data.pid === undefined) && (missing0 = "pid"))) || ((data.code === undefined) && (missing0 = "code"))) || ((data.owner === undefined) && (missing0 = "owner"))) || ((data.generation === undefined) && (missing0 = "generation"))) || ((data.revision === undefined) && (missing0 = "revision"))) || ((data.lifecycle === undefined) && (missing0 = "lifecycle"))) || ((data.failure === undefined) && (missing0 = "failure"))) || ((data.admitted === undefined) && (missing0 = "admitted"))) || ((data.consumed === undefined) && (missing0 = "consumed"))) || ((data.cancelled === undefined) && (missing0 = "cancelled"))) || ((data.work_before_ms === undefined) && (missing0 = "work_before_ms"))) || ((data.settle_before_ms === undefined) && (missing0 = "settle_before_ms"))) || ((data.turn_permit === undefined) && (missing0 = "turn_permit"))) || ((data.binding === undefined) && (missing0 = "binding"))) || ((data.control === undefined) && (missing0 = "control"))){
validate178.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(func1.call(schema70.properties, key0))){
validate178.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.allow_collection !== undefined){
const _errs2 = errors;
if(typeof data.allow_collection !== "boolean"){
validate178.errors = [{}];
return false;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.pid !== undefined){
const _errs4 = errors;
if(!(validate56(data.pid, {instancePath:instancePath+"/pid",parentData:data,parentDataProperty:"pid",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid0 = _errs4 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.code !== undefined){
const _errs5 = errors;
if(!(validate59(data.code, {instancePath:instancePath+"/code",parentData:data,parentDataProperty:"code",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate59.errors : vErrors.concat(validate59.errors);
errors = vErrors.length;
}
var valid0 = _errs5 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.owner !== undefined){
const _errs6 = errors;
if(!(validate62(data.owner, {instancePath:instancePath+"/owner",parentData:data,parentDataProperty:"owner",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate62.errors : vErrors.concat(validate62.errors);
errors = vErrors.length;
}
var valid0 = _errs6 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.generation !== undefined){
const _errs7 = errors;
if(!(validate56(data.generation, {instancePath:instancePath+"/generation",parentData:data,parentDataProperty:"generation",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid0 = _errs7 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.revision !== undefined){
const _errs8 = errors;
if(!(validate56(data.revision, {instancePath:instancePath+"/revision",parentData:data,parentDataProperty:"revision",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid0 = _errs8 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.lifecycle !== undefined){
const _errs9 = errors;
if(!(validate184(data.lifecycle, {instancePath:instancePath+"/lifecycle",parentData:data,parentDataProperty:"lifecycle",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate184.errors : vErrors.concat(validate184.errors);
errors = vErrors.length;
}
var valid0 = _errs9 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.failure !== undefined){
const _errs10 = errors;
if(!(validate62(data.failure, {instancePath:instancePath+"/failure",parentData:data,parentDataProperty:"failure",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate62.errors : vErrors.concat(validate62.errors);
errors = vErrors.length;
}
var valid0 = _errs10 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.admitted !== undefined){
const _errs11 = errors;
if(!(validate56(data.admitted, {instancePath:instancePath+"/admitted",parentData:data,parentDataProperty:"admitted",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid0 = _errs11 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.consumed !== undefined){
const _errs12 = errors;
if(!(validate56(data.consumed, {instancePath:instancePath+"/consumed",parentData:data,parentDataProperty:"consumed",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid0 = _errs12 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.cancelled !== undefined){
const _errs13 = errors;
if(!(validate56(data.cancelled, {instancePath:instancePath+"/cancelled",parentData:data,parentDataProperty:"cancelled",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid0 = _errs13 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.work_before_ms !== undefined){
const _errs14 = errors;
if(!(validate62(data.work_before_ms, {instancePath:instancePath+"/work_before_ms",parentData:data,parentDataProperty:"work_before_ms",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate62.errors : vErrors.concat(validate62.errors);
errors = vErrors.length;
}
var valid0 = _errs14 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.settle_before_ms !== undefined){
const _errs15 = errors;
if(!(validate62(data.settle_before_ms, {instancePath:instancePath+"/settle_before_ms",parentData:data,parentDataProperty:"settle_before_ms",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate62.errors : vErrors.concat(validate62.errors);
errors = vErrors.length;
}
var valid0 = _errs15 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.turn_permit !== undefined){
const _errs16 = errors;
if(!(validate192(data.turn_permit, {instancePath:instancePath+"/turn_permit",parentData:data,parentDataProperty:"turn_permit",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate192.errors : vErrors.concat(validate192.errors);
errors = vErrors.length;
}
var valid0 = _errs16 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.binding !== undefined){
const _errs17 = errors;
if(!(validate198(data.binding, {instancePath:instancePath+"/binding",parentData:data,parentDataProperty:"binding",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate198.errors : vErrors.concat(validate198.errors);
errors = vErrors.length;
}
var valid0 = _errs17 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.control !== undefined){
const _errs18 = errors;
if(!(validate226(data.control, {instancePath:instancePath+"/control",parentData:data,parentDataProperty:"control",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate226.errors : vErrors.concat(validate226.errors);
errors = vErrors.length;
}
var valid0 = _errs18 === errors;
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
}
}
else {
validate178.errors = [{}];
return false;
}
}
validate178.errors = vErrors;
return errors === 0;
}
validate178.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate177(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate177.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate178(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate178.errors : vErrors.concat(validate178.errors);
errors = vErrors.length;
}
var _valid0 = _errs1 === errors;
valid0 = valid0 || _valid0;
if(_valid0){
var props0 = true;
}
const _errs2 = errors;
if(data !== null){
const err0 = {};
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
const err1 = {};
if(vErrors === null){
vErrors = [err1];
}
else {
vErrors.push(err1);
}
errors++;
validate177.errors = vErrors;
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
validate177.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate177.evaluated = {"dynamicProps":true,"dynamicItems":false};


function validate176(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate176.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(Array.isArray(data)){
if(data.length > 8){
validate176.errors = [{}];
return false;
}
else {
if(data.length < 8){
validate176.errors = [{}];
return false;
}
else {
var valid0 = true;
const len0 = data.length;
for(let i0=0; i0<len0; i0++){
const _errs1 = errors;
if(!(validate177(data[i0], {instancePath:instancePath+"/" + i0,parentData:data,parentDataProperty:i0,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate177.errors : vErrors.concat(validate177.errors);
errors = vErrors.length;
}
var valid0 = _errs1 === errors;
if(!valid0){
break;
}
}
}
}
}
else {
validate176.errors = [{}];
return false;
}
}
validate176.errors = vErrors;
return errors === 0;
}
validate176.evaluated = {"items":true,"dynamicProps":false,"dynamicItems":false};

const schema89 = {"type":"object","additionalProperties":false,"properties":{"realm":{"$ref":"https://transit.invalid/generated-validator/1"},"pid":{"$ref":"https://transit.invalid/generated-validator/1"},"kind":{"$ref":"https://transit.invalid/generated-validator/29"},"id":{"$ref":"https://transit.invalid/generated-validator/1"}},"required":["realm","pid","kind","id"]};
const schema90 = {"type":"string","enum":["input","turn","output","effect","event","state"]};

function validate287(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate287.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate287.errors = [{}];
return false;
}
if(!((((((data === "input") || (data === "turn")) || (data === "output")) || (data === "effect")) || (data === "event")) || (data === "state"))){
validate287.errors = [{}];
return false;
}
validate287.errors = vErrors;
return errors === 0;
}
validate287.evaluated = {"dynamicProps":false,"dynamicItems":false};


function validate284(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate284.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if(((((data.realm === undefined) && (missing0 = "realm")) || ((data.pid === undefined) && (missing0 = "pid"))) || ((data.kind === undefined) && (missing0 = "kind"))) || ((data.id === undefined) && (missing0 = "id"))){
validate284.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((((key0 === "realm") || (key0 === "pid")) || (key0 === "kind")) || (key0 === "id"))){
validate284.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.realm !== undefined){
const _errs2 = errors;
if(!(validate56(data.realm, {instancePath:instancePath+"/realm",parentData:data,parentDataProperty:"realm",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.pid !== undefined){
const _errs3 = errors;
if(!(validate56(data.pid, {instancePath:instancePath+"/pid",parentData:data,parentDataProperty:"pid",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid0 = _errs3 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.kind !== undefined){
const _errs4 = errors;
if(!(validate287(data.kind, {instancePath:instancePath+"/kind",parentData:data,parentDataProperty:"kind",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate287.errors : vErrors.concat(validate287.errors);
errors = vErrors.length;
}
var valid0 = _errs4 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.id !== undefined){
const _errs5 = errors;
if(!(validate56(data.id, {instancePath:instancePath+"/id",parentData:data,parentDataProperty:"id",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid0 = _errs5 === errors;
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
else {
validate284.errors = [{}];
return false;
}
}
validate284.errors = vErrors;
return errors === 0;
}
validate284.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema91 = {"type":"string","enum":["retained","reclaimed","current_state"]};

function validate292(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate292.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate292.errors = [{}];
return false;
}
if(!(((data === "retained") || (data === "reclaimed")) || (data === "current_state"))){
validate292.errors = [{}];
return false;
}
validate292.errors = vErrors;
return errors === 0;
}
validate292.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema27 = {"anyOf":[{"$ref":"https://transit.invalid/generated-validator/66"},{"type":"null"}]};
const schema28 = {"type":"object","additionalProperties":false,"properties":{"version":{"const":1},"definition":{"$ref":"https://transit.invalid/generated-validator/32"},"code":{"type":"string","maxLength":96},"category":{"$ref":"https://transit.invalid/generated-validator/33"},"stage":{"$ref":"https://transit.invalid/generated-validator/34"},"outcome":{"$ref":"https://transit.invalid/generated-validator/35"},"evidence":{"$ref":"https://transit.invalid/generated-validator/36"},"message":{"type":"string","maxLength":384},"cause":{"$ref":"https://transit.invalid/generated-validator/37"},"identity":{"$ref":"https://transit.invalid/generated-validator/42"},"location":{"$ref":"https://transit.invalid/generated-validator/46"},"facts":{"$ref":"https://transit.invalid/generated-validator/61"},"actions":{"$ref":"https://transit.invalid/generated-validator/65"}},"required":["version","definition","code","category","stage","outcome","evidence","message","cause","identity","location","facts","actions"]};
const schema21 = {"type":"string","enum":["65287f89db5a4ee587cb90ddcec6d819f1974613e89ee14c410ebff01c342ab4"]};

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
if(typeof data !== "string"){
validate54.errors = [{}];
return false;
}
if(!(data === "65287f89db5a4ee587cb90ddcec6d819f1974613e89ee14c410ebff01c342ab4")){
validate54.errors = [{}];
return false;
}
validate54.errors = vErrors;
return errors === 0;
}
validate54.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema29 = {"type":"string","enum":["syntax","binding","unsupported","constraint","access","conflict","limit","lifecycle","integrity","unavailable","internal"]};

function validate74(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate74.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate74.errors = [{}];
return false;
}
if(!(((((((((((data === "syntax") || (data === "binding")) || (data === "unsupported")) || (data === "constraint")) || (data === "access")) || (data === "conflict")) || (data === "limit")) || (data === "lifecycle")) || (data === "integrity")) || (data === "unavailable")) || (data === "internal"))){
validate74.errors = [{}];
return false;
}
validate74.errors = vErrors;
return errors === 0;
}
validate74.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema30 = {"type":"string","enum":["input","parse","compile","bind","prepare","submit","admission","execute","read","decode","output","reconcile","cleanup","control"]};

function validate76(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate76.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate76.errors = [{}];
return false;
}
if(!((((((((((((((data === "input") || (data === "parse")) || (data === "compile")) || (data === "bind")) || (data === "prepare")) || (data === "submit")) || (data === "admission")) || (data === "execute")) || (data === "read")) || (data === "decode")) || (data === "output")) || (data === "reconcile")) || (data === "cleanup")) || (data === "control"))){
validate76.errors = [{}];
return false;
}
validate76.errors = vErrors;
return errors === 0;
}
validate76.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema31 = {"type":"string","enum":["not_applicable","not_submitted","not_dispatched","prepared","unknown","pending","input_rejected","rejected","applied","completed","failed","cancelled","retired","closed_unknown"]};

function validate78(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate78.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate78.errors = [{}];
return false;
}
if(!((((((((((((((data === "not_applicable") || (data === "not_submitted")) || (data === "not_dispatched")) || (data === "prepared")) || (data === "unknown")) || (data === "pending")) || (data === "input_rejected")) || (data === "rejected")) || (data === "applied")) || (data === "completed")) || (data === "failed")) || (data === "cancelled")) || (data === "retired")) || (data === "closed_unknown"))){
validate78.errors = [{}];
return false;
}
validate78.errors = vErrors;
return errors === 0;
}
validate78.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema32 = {"type":"string","enum":["none","local_before_dispatch","saved_intent","native_receipt","domain_status"]};

function validate80(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate80.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate80.errors = [{}];
return false;
}
if(!(((((data === "none") || (data === "local_before_dispatch")) || (data === "saved_intent")) || (data === "native_receipt")) || (data === "domain_status"))){
validate80.errors = [{}];
return false;
}
validate80.errors = vErrors;
return errors === 0;
}
validate80.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema33 = {"anyOf":[{"type":"string","maxLength":96},{"type":"null"}]};

function validate82(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate82.evaluated;
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
if(func3(data) > 96){
const err0 = {};
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
const err1 = {};
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
const err2 = {};
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
const err3 = {};
if(vErrors === null){
vErrors = [err3];
}
else {
vErrors.push(err3);
}
errors++;
validate82.errors = vErrors;
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
validate82.errors = vErrors;
return errors === 0;
}
validate82.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema34 = {"anyOf":[{"$ref":"https://transit.invalid/generated-validator/41"},{"type":"null"}]};
const schema35 = {"type":"object","additionalProperties":false,"properties":{"domain":{"$ref":"https://transit.invalid/generated-validator/38"},"id":{"$ref":"https://transit.invalid/generated-validator/39"},"realm":{"$ref":"https://transit.invalid/generated-validator/40"},"resource":{"$ref":"https://transit.invalid/generated-validator/40"},"sequence":{"$ref":"https://transit.invalid/generated-validator/40"}},"required":["domain","id","realm","resource","sequence"]};
const schema36 = {"type":"string","enum":["sql","query","mutation","catalog","application","publication","migration","reactive","serving","effect","exchange","transport","internal"]};

function validate86(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate86.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate86.errors = [{}];
return false;
}
if(!(((((((((((((data === "sql") || (data === "query")) || (data === "mutation")) || (data === "catalog")) || (data === "application")) || (data === "publication")) || (data === "migration")) || (data === "reactive")) || (data === "serving")) || (data === "effect")) || (data === "exchange")) || (data === "transport")) || (data === "internal"))){
validate86.errors = [{}];
return false;
}
validate86.errors = vErrors;
return errors === 0;
}
validate86.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema37 = {"type":"string","maxLength":20,"pattern":"^(0|[1-9][0-9]*)$"};
const pattern3 = new RegExp("^(0|[1-9][0-9]*)$", "u");

function validate88(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate88.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(typeof data === "string"){
if(func3(data) > 20){
validate88.errors = [{}];
return false;
}
else {
if(!pattern3.test(data)){
validate88.errors = [{}];
return false;
}
}
}
else {
validate88.errors = [{}];
return false;
}
}
validate88.errors = vErrors;
return errors === 0;
}
validate88.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema38 = {"anyOf":[{"$ref":"https://transit.invalid/generated-validator/39"},{"type":"null"}]};

function validate90(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate90.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate88(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate88.errors : vErrors.concat(validate88.errors);
errors = vErrors.length;
}
var _valid0 = _errs1 === errors;
valid0 = valid0 || _valid0;
const _errs2 = errors;
if(data !== null){
const err0 = {};
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
const err1 = {};
if(vErrors === null){
vErrors = [err1];
}
else {
vErrors.push(err1);
}
errors++;
validate90.errors = vErrors;
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
validate90.errors = vErrors;
return errors === 0;
}
validate90.evaluated = {"dynamicProps":false,"dynamicItems":false};


function validate85(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate85.evaluated;
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
validate85.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((((key0 === "domain") || (key0 === "id")) || (key0 === "realm")) || (key0 === "resource")) || (key0 === "sequence"))){
validate85.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.domain !== undefined){
const _errs2 = errors;
if(!(validate86(data.domain, {instancePath:instancePath+"/domain",parentData:data,parentDataProperty:"domain",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate86.errors : vErrors.concat(validate86.errors);
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
if(!(validate88(data.id, {instancePath:instancePath+"/id",parentData:data,parentDataProperty:"id",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate88.errors : vErrors.concat(validate88.errors);
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
if(!(validate90(data.realm, {instancePath:instancePath+"/realm",parentData:data,parentDataProperty:"realm",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate90.errors : vErrors.concat(validate90.errors);
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
if(!(validate90(data.resource, {instancePath:instancePath+"/resource",parentData:data,parentDataProperty:"resource",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate90.errors : vErrors.concat(validate90.errors);
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
if(!(validate90(data.sequence, {instancePath:instancePath+"/sequence",parentData:data,parentDataProperty:"sequence",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate90.errors : vErrors.concat(validate90.errors);
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
validate85.errors = [{}];
return false;
}
}
validate85.errors = vErrors;
return errors === 0;
}
validate85.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate84(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate84.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate85(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate85.errors : vErrors.concat(validate85.errors);
errors = vErrors.length;
}
var _valid0 = _errs1 === errors;
valid0 = valid0 || _valid0;
if(_valid0){
var props0 = true;
}
const _errs2 = errors;
if(data !== null){
const err0 = {};
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
const err1 = {};
if(vErrors === null){
vErrors = [err1];
}
else {
vErrors.push(err1);
}
errors++;
validate84.errors = vErrors;
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
validate84.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate84.evaluated = {"dynamicProps":true,"dynamicItems":false};

const schema39 = {"anyOf":[{"$ref":"https://transit.invalid/generated-validator/45"},{"type":"null"}]};
const schema40 = {"type":"object","additionalProperties":false,"properties":{"source":{"$ref":"https://transit.invalid/generated-validator/43"},"source_encoding":{"$ref":"https://transit.invalid/generated-validator/44"},"source_truncated":{"type":"boolean"},"statement":{"$ref":"https://transit.invalid/generated-validator/40"},"offset":{"$ref":"https://transit.invalid/generated-validator/39"},"length":{"$ref":"https://transit.invalid/generated-validator/39"},"line":{"$ref":"https://transit.invalid/generated-validator/39"},"byte_column":{"$ref":"https://transit.invalid/generated-validator/39"}},"required":["source","source_encoding","source_truncated","statement","offset","length","line","byte_column"]};
const schema41 = {"anyOf":[{"type":"string","maxLength":512},{"type":"null"}]};

function validate99(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate99.evaluated;
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
if(func3(data) > 512){
const err0 = {};
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
const err1 = {};
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
const err2 = {};
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
const err3 = {};
if(vErrors === null){
vErrors = [err3];
}
else {
vErrors.push(err3);
}
errors++;
validate99.errors = vErrors;
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
validate99.errors = vErrors;
return errors === 0;
}
validate99.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema42 = {"type":"string","enum":["utf8","escaped_bytes"]};

function validate101(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate101.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate101.errors = [{}];
return false;
}
if(!((data === "utf8") || (data === "escaped_bytes"))){
validate101.errors = [{}];
return false;
}
validate101.errors = vErrors;
return errors === 0;
}
validate101.evaluated = {"dynamicProps":false,"dynamicItems":false};


function validate98(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate98.evaluated;
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
validate98.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((((((((key0 === "source") || (key0 === "source_encoding")) || (key0 === "source_truncated")) || (key0 === "statement")) || (key0 === "offset")) || (key0 === "length")) || (key0 === "line")) || (key0 === "byte_column"))){
validate98.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.source !== undefined){
const _errs2 = errors;
if(!(validate99(data.source, {instancePath:instancePath+"/source",parentData:data,parentDataProperty:"source",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate99.errors : vErrors.concat(validate99.errors);
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
if(!(validate101(data.source_encoding, {instancePath:instancePath+"/source_encoding",parentData:data,parentDataProperty:"source_encoding",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate101.errors : vErrors.concat(validate101.errors);
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
validate98.errors = [{}];
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
if(!(validate90(data.statement, {instancePath:instancePath+"/statement",parentData:data,parentDataProperty:"statement",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate90.errors : vErrors.concat(validate90.errors);
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
if(!(validate88(data.offset, {instancePath:instancePath+"/offset",parentData:data,parentDataProperty:"offset",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate88.errors : vErrors.concat(validate88.errors);
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
if(!(validate88(data.length, {instancePath:instancePath+"/length",parentData:data,parentDataProperty:"length",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate88.errors : vErrors.concat(validate88.errors);
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
if(!(validate88(data.line, {instancePath:instancePath+"/line",parentData:data,parentDataProperty:"line",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate88.errors : vErrors.concat(validate88.errors);
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
if(!(validate88(data.byte_column, {instancePath:instancePath+"/byte_column",parentData:data,parentDataProperty:"byte_column",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate88.errors : vErrors.concat(validate88.errors);
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
validate98.errors = [{}];
return false;
}
}
validate98.errors = vErrors;
return errors === 0;
}
validate98.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate97(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate97.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate98(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate98.errors : vErrors.concat(validate98.errors);
errors = vErrors.length;
}
var _valid0 = _errs1 === errors;
valid0 = valid0 || _valid0;
if(_valid0){
var props0 = true;
}
const _errs2 = errors;
if(data !== null){
const err0 = {};
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
const err1 = {};
if(vErrors === null){
vErrors = [err1];
}
else {
vErrors.push(err1);
}
errors++;
validate97.errors = vErrors;
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
validate97.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate97.evaluated = {"dynamicProps":true,"dynamicItems":false};

const schema43 = {"type":"array","minItems":16,"maxItems":16,"items":{"$ref":"https://transit.invalid/generated-validator/60"}};
const schema44 = {"anyOf":[{"$ref":"https://transit.invalid/generated-validator/59"},{"type":"null"}]};
const schema45 = {"type":"object","additionalProperties":false,"properties":{"field":{"$ref":"https://transit.invalid/generated-validator/47"},"origin":{"$ref":"https://transit.invalid/generated-validator/48"},"availability":{"$ref":"https://transit.invalid/generated-validator/49"},"value":{"$ref":"https://transit.invalid/generated-validator/58"}},"required":["field","origin","availability","value"]};
const schema46 = {"type":"string","enum":["object","name","table","native_input","affected_rows","argument","option","permissions","scope","column","qualifier","constraint","key","input_row","first_occurrence","parameter","parameter_use","expected_count","actual_count","expected_type","actual_type","supplied_value","expected_value","expression","source_kind","source_basis","source_key","source_row","field_path","byte_offset","expected_resource","actual_resource","expected_source","actual_source","expected_revision","actual_revision","expected_schema","actual_schema","expected_policy","actual_policy","budget","limit","required","unit","completed_statements","emitted_rows","emitted_segments","completion","proposal","step","generation","attachment","lease","schema_origin","sampling_records","operation","native_cause","expected_bytes","presence","published","subscription","expected_codec","actual_codec","observed_clock","expected_namespace","actual_namespace","attempt","executor","resolution_reason","principal","deadline","authorization_policy","resolution_policy","protocol_status","native_effect","dependency","dependency_kind","dependency_owner"]};

function validate113(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate113.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate113.errors = [{}];
return false;
}
if(!((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((data === "object") || (data === "name")) || (data === "table")) || (data === "native_input")) || (data === "affected_rows")) || (data === "argument")) || (data === "option")) || (data === "permissions")) || (data === "scope")) || (data === "column")) || (data === "qualifier")) || (data === "constraint")) || (data === "key")) || (data === "input_row")) || (data === "first_occurrence")) || (data === "parameter")) || (data === "parameter_use")) || (data === "expected_count")) || (data === "actual_count")) || (data === "expected_type")) || (data === "actual_type")) || (data === "supplied_value")) || (data === "expected_value")) || (data === "expression")) || (data === "source_kind")) || (data === "source_basis")) || (data === "source_key")) || (data === "source_row")) || (data === "field_path")) || (data === "byte_offset")) || (data === "expected_resource")) || (data === "actual_resource")) || (data === "expected_source")) || (data === "actual_source")) || (data === "expected_revision")) || (data === "actual_revision")) || (data === "expected_schema")) || (data === "actual_schema")) || (data === "expected_policy")) || (data === "actual_policy")) || (data === "budget")) || (data === "limit")) || (data === "required")) || (data === "unit")) || (data === "completed_statements")) || (data === "emitted_rows")) || (data === "emitted_segments")) || (data === "completion")) || (data === "proposal")) || (data === "step")) || (data === "generation")) || (data === "attachment")) || (data === "lease")) || (data === "schema_origin")) || (data === "sampling_records")) || (data === "operation")) || (data === "native_cause")) || (data === "expected_bytes")) || (data === "presence")) || (data === "published")) || (data === "subscription")) || (data === "expected_codec")) || (data === "actual_codec")) || (data === "observed_clock")) || (data === "expected_namespace")) || (data === "actual_namespace")) || (data === "attempt")) || (data === "executor")) || (data === "resolution_reason")) || (data === "principal")) || (data === "deadline")) || (data === "authorization_policy")) || (data === "resolution_policy")) || (data === "protocol_status")) || (data === "native_effect")) || (data === "dependency")) || (data === "dependency_kind")) || (data === "dependency_owner"))){
validate113.errors = [{}];
return false;
}
validate113.errors = vErrors;
return errors === 0;
}
validate113.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema47 = {"type":"string","enum":["caller","execution","schema","authority","owner"]};

function validate115(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate115.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate115.errors = [{}];
return false;
}
if(!(((((data === "caller") || (data === "execution")) || (data === "schema")) || (data === "authority")) || (data === "owner"))){
validate115.errors = [{}];
return false;
}
validate115.errors = vErrors;
return errors === 0;
}
validate115.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema48 = {"type":"string","enum":["provided","truncated","unrecorded","unavailable","withheld","inapplicable"]};

function validate117(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate117.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate117.errors = [{}];
return false;
}
if(!((((((data === "provided") || (data === "truncated")) || (data === "unrecorded")) || (data === "unavailable")) || (data === "withheld")) || (data === "inapplicable"))){
validate117.errors = [{}];
return false;
}
validate117.errors = vErrors;
return errors === 0;
}
validate117.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema49 = {"anyOf":[{"$ref":"https://transit.invalid/generated-validator/57"},{"type":"null"}]};
const schema50 = {"oneOf":[{"$ref":"https://transit.invalid/generated-validator/50"},{"$ref":"https://transit.invalid/generated-validator/52"},{"$ref":"https://transit.invalid/generated-validator/53"},{"$ref":"https://transit.invalid/generated-validator/54"},{"$ref":"https://transit.invalid/generated-validator/55"},{"$ref":"https://transit.invalid/generated-validator/56"}]};
const schema51 = {"type":"object","additionalProperties":false,"required":["text"],"properties":{"text":{"type":"string","maxLength":256}}};

function validate121(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate121.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((data.text === undefined) && (missing0 = "text")){
validate121.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(key0 === "text")){
validate121.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.text !== undefined){
let data0 = data.text;
const _errs2 = errors;
if(errors === _errs2){
if(typeof data0 === "string"){
if(func3(data0) > 256){
validate121.errors = [{}];
return false;
}
}
else {
validate121.errors = [{}];
return false;
}
}
}
}
}
}
else {
validate121.errors = [{}];
return false;
}
}
validate121.errors = vErrors;
return errors === 0;
}
validate121.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema52 = {"type":"object","additionalProperties":false,"required":["signed"],"properties":{"signed":{"$ref":"https://transit.invalid/generated-validator/51"}}};
const schema53 = {"type":"string","maxLength":20,"pattern":"^(0|-?[1-9][0-9]*)$"};
const pattern4 = new RegExp("^(0|-?[1-9][0-9]*)$", "u");

function validate124(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate124.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(typeof data === "string"){
if(func3(data) > 20){
validate124.errors = [{}];
return false;
}
else {
if(!pattern4.test(data)){
validate124.errors = [{}];
return false;
}
}
}
else {
validate124.errors = [{}];
return false;
}
}
validate124.errors = vErrors;
return errors === 0;
}
validate124.evaluated = {"dynamicProps":false,"dynamicItems":false};


function validate123(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate123.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((data.signed === undefined) && (missing0 = "signed")){
validate123.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(key0 === "signed")){
validate123.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.signed !== undefined){
if(!(validate124(data.signed, {instancePath:instancePath+"/signed",parentData:data,parentDataProperty:"signed",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate124.errors : vErrors.concat(validate124.errors);
errors = vErrors.length;
}
}
}
}
}
else {
validate123.errors = [{}];
return false;
}
}
validate123.errors = vErrors;
return errors === 0;
}
validate123.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema54 = {"type":"object","additionalProperties":false,"required":["unsigned"],"properties":{"unsigned":{"$ref":"https://transit.invalid/generated-validator/39"}}};

function validate127(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate127.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((data.unsigned === undefined) && (missing0 = "unsigned")){
validate127.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(key0 === "unsigned")){
validate127.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.unsigned !== undefined){
if(!(validate88(data.unsigned, {instancePath:instancePath+"/unsigned",parentData:data,parentDataProperty:"unsigned",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate88.errors : vErrors.concat(validate88.errors);
errors = vErrors.length;
}
}
}
}
}
else {
validate127.errors = [{}];
return false;
}
}
validate127.errors = vErrors;
return errors === 0;
}
validate127.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema55 = {"type":"object","additionalProperties":false,"required":["boolean"],"properties":{"boolean":{"type":"boolean"}}};

function validate130(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate130.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((data.boolean === undefined) && (missing0 = "boolean")){
validate130.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(key0 === "boolean")){
validate130.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.boolean !== undefined){
if(typeof data.boolean !== "boolean"){
validate130.errors = [{}];
return false;
}
}
}
}
}
else {
validate130.errors = [{}];
return false;
}
}
validate130.errors = vErrors;
return errors === 0;
}
validate130.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema56 = {"type":"object","additionalProperties":false,"required":["digest"],"properties":{"digest":{"$ref":"https://transit.invalid/generated-validator/11"}}};

function validate132(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate132.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((data.digest === undefined) && (missing0 = "digest")){
validate132.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(key0 === "digest")){
validate132.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.digest !== undefined){
if(!(validate133(data.digest, {instancePath:instancePath+"/digest",parentData:data,parentDataProperty:"digest",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate133.errors : vErrors.concat(validate133.errors);
errors = vErrors.length;
}
}
}
}
}
else {
validate132.errors = [{}];
return false;
}
}
validate132.errors = vErrors;
return errors === 0;
}
validate132.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema59 = {"type":"object","additionalProperties":false,"required":["location"],"properties":{"location":{"$ref":"https://transit.invalid/generated-validator/45"}}};

function validate138(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate138.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((data.location === undefined) && (missing0 = "location")){
validate138.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(key0 === "location")){
validate138.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.location !== undefined){
if(!(validate98(data.location, {instancePath:instancePath+"/location",parentData:data,parentDataProperty:"location",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate98.errors : vErrors.concat(validate98.errors);
errors = vErrors.length;
}
}
}
}
}
else {
validate138.errors = [{}];
return false;
}
}
validate138.errors = vErrors;
return errors === 0;
}
validate138.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate120(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate120.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
const _errs0 = errors;
let valid0 = false;
let passing0 = null;
const _errs1 = errors;
if(!(validate121(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate121.errors : vErrors.concat(validate121.errors);
errors = vErrors.length;
}
var _valid0 = _errs1 === errors;
if(_valid0){
valid0 = true;
passing0 = 0;
var props0 = true;
}
const _errs2 = errors;
if(!(validate123(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate123.errors : vErrors.concat(validate123.errors);
errors = vErrors.length;
}
var _valid0 = _errs2 === errors;
if(_valid0 && valid0){
valid0 = false;
passing0 = [passing0, 1];
}
else {
if(_valid0){
valid0 = true;
passing0 = 1;
if(props0 !== true){
props0 = true;
}
}
const _errs3 = errors;
if(!(validate127(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate127.errors : vErrors.concat(validate127.errors);
errors = vErrors.length;
}
var _valid0 = _errs3 === errors;
if(_valid0 && valid0){
valid0 = false;
passing0 = [passing0, 2];
}
else {
if(_valid0){
valid0 = true;
passing0 = 2;
if(props0 !== true){
props0 = true;
}
}
const _errs4 = errors;
if(!(validate130(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate130.errors : vErrors.concat(validate130.errors);
errors = vErrors.length;
}
var _valid0 = _errs4 === errors;
if(_valid0 && valid0){
valid0 = false;
passing0 = [passing0, 3];
}
else {
if(_valid0){
valid0 = true;
passing0 = 3;
if(props0 !== true){
props0 = true;
}
}
const _errs5 = errors;
if(!(validate132(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate132.errors : vErrors.concat(validate132.errors);
errors = vErrors.length;
}
var _valid0 = _errs5 === errors;
if(_valid0 && valid0){
valid0 = false;
passing0 = [passing0, 4];
}
else {
if(_valid0){
valid0 = true;
passing0 = 4;
if(props0 !== true){
props0 = true;
}
}
const _errs6 = errors;
if(!(validate138(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate138.errors : vErrors.concat(validate138.errors);
errors = vErrors.length;
}
var _valid0 = _errs6 === errors;
if(_valid0 && valid0){
valid0 = false;
passing0 = [passing0, 5];
}
else {
if(_valid0){
valid0 = true;
passing0 = 5;
if(props0 !== true){
props0 = true;
}
}
}
}
}
}
}
if(!valid0){
const err0 = {};
if(vErrors === null){
vErrors = [err0];
}
else {
vErrors.push(err0);
}
errors++;
validate120.errors = vErrors;
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
validate120.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate120.evaluated = {"dynamicProps":true,"dynamicItems":false};


function validate119(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate119.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate120(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate120.errors : vErrors.concat(validate120.errors);
errors = vErrors.length;
}
else {
var props0 = validate120.evaluated.props;
}
var _valid0 = _errs1 === errors;
valid0 = valid0 || _valid0;
const _errs2 = errors;
if(data !== null){
const err0 = {};
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
const err1 = {};
if(vErrors === null){
vErrors = [err1];
}
else {
vErrors.push(err1);
}
errors++;
validate119.errors = vErrors;
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
validate119.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate119.evaluated = {"dynamicProps":true,"dynamicItems":false};


function validate112(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate112.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if(((((data.field === undefined) && (missing0 = "field")) || ((data.origin === undefined) && (missing0 = "origin"))) || ((data.availability === undefined) && (missing0 = "availability"))) || ((data.value === undefined) && (missing0 = "value"))){
validate112.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((((key0 === "field") || (key0 === "origin")) || (key0 === "availability")) || (key0 === "value"))){
validate112.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.field !== undefined){
const _errs2 = errors;
if(!(validate113(data.field, {instancePath:instancePath+"/field",parentData:data,parentDataProperty:"field",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate113.errors : vErrors.concat(validate113.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.origin !== undefined){
const _errs3 = errors;
if(!(validate115(data.origin, {instancePath:instancePath+"/origin",parentData:data,parentDataProperty:"origin",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate115.errors : vErrors.concat(validate115.errors);
errors = vErrors.length;
}
var valid0 = _errs3 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.availability !== undefined){
const _errs4 = errors;
if(!(validate117(data.availability, {instancePath:instancePath+"/availability",parentData:data,parentDataProperty:"availability",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate117.errors : vErrors.concat(validate117.errors);
errors = vErrors.length;
}
var valid0 = _errs4 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.value !== undefined){
const _errs5 = errors;
if(!(validate119(data.value, {instancePath:instancePath+"/value",parentData:data,parentDataProperty:"value",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate119.errors : vErrors.concat(validate119.errors);
errors = vErrors.length;
}
var valid0 = _errs5 === errors;
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
else {
validate112.errors = [{}];
return false;
}
}
validate112.errors = vErrors;
return errors === 0;
}
validate112.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate111(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate111.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate112(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate112.errors : vErrors.concat(validate112.errors);
errors = vErrors.length;
}
var _valid0 = _errs1 === errors;
valid0 = valid0 || _valid0;
if(_valid0){
var props0 = true;
}
const _errs2 = errors;
if(data !== null){
const err0 = {};
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
const err1 = {};
if(vErrors === null){
vErrors = [err1];
}
else {
vErrors.push(err1);
}
errors++;
validate111.errors = vErrors;
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
validate111.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate111.evaluated = {"dynamicProps":true,"dynamicItems":false};


function validate110(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate110.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(Array.isArray(data)){
if(data.length > 16){
validate110.errors = [{}];
return false;
}
else {
if(data.length < 16){
validate110.errors = [{}];
return false;
}
else {
var valid0 = true;
const len0 = data.length;
for(let i0=0; i0<len0; i0++){
const _errs1 = errors;
if(!(validate111(data[i0], {instancePath:instancePath+"/" + i0,parentData:data,parentDataProperty:i0,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate111.errors : vErrors.concat(validate111.errors);
errors = vErrors.length;
}
var valid0 = _errs1 === errors;
if(!valid0){
break;
}
}
}
}
}
else {
validate110.errors = [{}];
return false;
}
}
validate110.errors = vErrors;
return errors === 0;
}
validate110.evaluated = {"items":true,"dynamicProps":false,"dynamicItems":false};

const schema60 = {"type":"array","minItems":4,"maxItems":4,"items":{"$ref":"https://transit.invalid/generated-validator/64"}};
const schema61 = {"anyOf":[{"$ref":"https://transit.invalid/generated-validator/63"},{"type":"null"}]};
const schema62 = {"type":"object","additionalProperties":false,"properties":{"kind":{"$ref":"https://transit.invalid/generated-validator/62"},"target":{"$ref":"https://transit.invalid/generated-validator/42"}},"required":["kind","target"]};
const schema63 = {"type":"string","enum":["correct_input","inspect_status","resume_exact","cancel_wait","cancel_mutation","refresh","recompile","retry_read","inspect_scope","reconcile_effect","contact_operator"]};

function validate149(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate149.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate149.errors = [{}];
return false;
}
if(!(((((((((((data === "correct_input") || (data === "inspect_status")) || (data === "resume_exact")) || (data === "cancel_wait")) || (data === "cancel_mutation")) || (data === "refresh")) || (data === "recompile")) || (data === "retry_read")) || (data === "inspect_scope")) || (data === "reconcile_effect")) || (data === "contact_operator"))){
validate149.errors = [{}];
return false;
}
validate149.errors = vErrors;
return errors === 0;
}
validate149.evaluated = {"dynamicProps":false,"dynamicItems":false};


function validate148(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate148.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if(((data.kind === undefined) && (missing0 = "kind")) || ((data.target === undefined) && (missing0 = "target"))){
validate148.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "kind") || (key0 === "target"))){
validate148.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.kind !== undefined){
const _errs2 = errors;
if(!(validate149(data.kind, {instancePath:instancePath+"/kind",parentData:data,parentDataProperty:"kind",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate149.errors : vErrors.concat(validate149.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.target !== undefined){
const _errs3 = errors;
if(!(validate84(data.target, {instancePath:instancePath+"/target",parentData:data,parentDataProperty:"target",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate84.errors : vErrors.concat(validate84.errors);
errors = vErrors.length;
}
var valid0 = _errs3 === errors;
}
else {
var valid0 = true;
}
}
}
}
}
else {
validate148.errors = [{}];
return false;
}
}
validate148.errors = vErrors;
return errors === 0;
}
validate148.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate147(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate147.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate148(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate148.errors : vErrors.concat(validate148.errors);
errors = vErrors.length;
}
var _valid0 = _errs1 === errors;
valid0 = valid0 || _valid0;
if(_valid0){
var props0 = true;
}
const _errs2 = errors;
if(data !== null){
const err0 = {};
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
const err1 = {};
if(vErrors === null){
vErrors = [err1];
}
else {
vErrors.push(err1);
}
errors++;
validate147.errors = vErrors;
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
validate147.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate147.evaluated = {"dynamicProps":true,"dynamicItems":false};


function validate146(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate146.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(Array.isArray(data)){
if(data.length > 4){
validate146.errors = [{}];
return false;
}
else {
if(data.length < 4){
validate146.errors = [{}];
return false;
}
else {
var valid0 = true;
const len0 = data.length;
for(let i0=0; i0<len0; i0++){
const _errs1 = errors;
if(!(validate147(data[i0], {instancePath:instancePath+"/" + i0,parentData:data,parentDataProperty:i0,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate147.errors : vErrors.concat(validate147.errors);
errors = vErrors.length;
}
var valid0 = _errs1 === errors;
if(!valid0){
break;
}
}
}
}
}
else {
validate146.errors = [{}];
return false;
}
}
validate146.errors = vErrors;
return errors === 0;
}
validate146.evaluated = {"items":true,"dynamicProps":false,"dynamicItems":false};


function validate72(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate72.evaluated;
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
validate72.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(func1.call(schema28.properties, key0))){
validate72.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.version !== undefined){
const _errs2 = errors;
if(1 !== data.version){
validate72.errors = [{}];
return false;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.definition !== undefined){
const _errs3 = errors;
if(!(validate54(data.definition, {instancePath:instancePath+"/definition",parentData:data,parentDataProperty:"definition",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate54.errors : vErrors.concat(validate54.errors);
errors = vErrors.length;
}
var valid0 = _errs3 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.code !== undefined){
let data2 = data.code;
const _errs4 = errors;
if(errors === _errs4){
if(typeof data2 === "string"){
if(func3(data2) > 96){
validate72.errors = [{}];
return false;
}
}
else {
validate72.errors = [{}];
return false;
}
}
var valid0 = _errs4 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.category !== undefined){
const _errs6 = errors;
if(!(validate74(data.category, {instancePath:instancePath+"/category",parentData:data,parentDataProperty:"category",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate74.errors : vErrors.concat(validate74.errors);
errors = vErrors.length;
}
var valid0 = _errs6 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.stage !== undefined){
const _errs7 = errors;
if(!(validate76(data.stage, {instancePath:instancePath+"/stage",parentData:data,parentDataProperty:"stage",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate76.errors : vErrors.concat(validate76.errors);
errors = vErrors.length;
}
var valid0 = _errs7 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.outcome !== undefined){
const _errs8 = errors;
if(!(validate78(data.outcome, {instancePath:instancePath+"/outcome",parentData:data,parentDataProperty:"outcome",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate78.errors : vErrors.concat(validate78.errors);
errors = vErrors.length;
}
var valid0 = _errs8 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.evidence !== undefined){
const _errs9 = errors;
if(!(validate80(data.evidence, {instancePath:instancePath+"/evidence",parentData:data,parentDataProperty:"evidence",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate80.errors : vErrors.concat(validate80.errors);
errors = vErrors.length;
}
var valid0 = _errs9 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.message !== undefined){
let data7 = data.message;
const _errs10 = errors;
if(errors === _errs10){
if(typeof data7 === "string"){
if(func3(data7) > 384){
validate72.errors = [{}];
return false;
}
}
else {
validate72.errors = [{}];
return false;
}
}
var valid0 = _errs10 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.cause !== undefined){
const _errs12 = errors;
if(!(validate82(data.cause, {instancePath:instancePath+"/cause",parentData:data,parentDataProperty:"cause",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate82.errors : vErrors.concat(validate82.errors);
errors = vErrors.length;
}
var valid0 = _errs12 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.identity !== undefined){
const _errs13 = errors;
if(!(validate84(data.identity, {instancePath:instancePath+"/identity",parentData:data,parentDataProperty:"identity",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate84.errors : vErrors.concat(validate84.errors);
errors = vErrors.length;
}
var valid0 = _errs13 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.location !== undefined){
const _errs14 = errors;
if(!(validate97(data.location, {instancePath:instancePath+"/location",parentData:data,parentDataProperty:"location",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate97.errors : vErrors.concat(validate97.errors);
errors = vErrors.length;
}
var valid0 = _errs14 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.facts !== undefined){
const _errs15 = errors;
if(!(validate110(data.facts, {instancePath:instancePath+"/facts",parentData:data,parentDataProperty:"facts",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate110.errors : vErrors.concat(validate110.errors);
errors = vErrors.length;
}
var valid0 = _errs15 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.actions !== undefined){
const _errs16 = errors;
if(!(validate146(data.actions, {instancePath:instancePath+"/actions",parentData:data,parentDataProperty:"actions",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate146.errors : vErrors.concat(validate146.errors);
errors = vErrors.length;
}
var valid0 = _errs16 === errors;
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
validate72.errors = [{}];
return false;
}
}
validate72.errors = vErrors;
return errors === 0;
}
validate72.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate71(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate71.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate72(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate72.errors : vErrors.concat(validate72.errors);
errors = vErrors.length;
}
var _valid0 = _errs1 === errors;
valid0 = valid0 || _valid0;
if(_valid0){
var props0 = true;
}
const _errs2 = errors;
if(data !== null){
const err0 = {};
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
const err1 = {};
if(vErrors === null){
vErrors = [err1];
}
else {
vErrors.push(err1);
}
errors++;
validate71.errors = vErrors;
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
validate71.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate71.evaluated = {"dynamicProps":true,"dynamicItems":false};


function validate157(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate157.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((((data.observation === undefined) && (missing0 = "observation")) || ((data.edges === undefined) && (missing0 = "edges"))) || ((data.effect_diagnostics === undefined) && (missing0 = "effect_diagnostics"))){
validate157.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "observation") || (key0 === "edges")) || (key0 === "effect_diagnostics"))){
validate157.errors = [{}];
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
if(((((((((((((((((data0.version === undefined) && (missing1 = "version")) || ((data0.realm === undefined) && (missing1 = "realm"))) || ((data0.resource === undefined) && (missing1 = "resource"))) || ((data0.pid === undefined) && (missing1 = "pid"))) || ((data0.cut === undefined) && (missing1 = "cut"))) || ((data0.reader === undefined) && (missing1 = "reader"))) || ((data0.next === undefined) && (missing1 = "next"))) || ((data0.complete === undefined) && (missing1 = "complete"))) || ((data0.history === undefined) && (missing1 = "history"))) || ((data0.last_collection === undefined) && (missing1 = "last_collection"))) || ((data0.scanned === undefined) && (missing1 = "scanned"))) || ((data0.processes === undefined) && (missing1 = "processes"))) || ((data0.events === undefined) && (missing1 = "events"))) || ((data0.outbox === undefined) && (missing1 = "outbox"))) || ((data0.effects === undefined) && (missing1 = "effects"))) || ((data0.payloads === undefined) && (missing1 = "payloads"))){
validate157.errors = [{}];
return false;
}
else {
const _errs4 = errors;
for(const key1 in data0){
if(!(func1.call(schema64.properties.observation.properties, key1))){
validate157.errors = [{}];
return false;
break;
}
}
if(_errs4 === errors){
if(data0.version !== undefined){
const _errs5 = errors;
if(!(validate59(data0.version, {instancePath:instancePath+"/observation/version",parentData:data0,parentDataProperty:"version",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate59.errors : vErrors.concat(validate59.errors);
errors = vErrors.length;
}
var valid1 = _errs5 === errors;
}
else {
var valid1 = true;
}
if(valid1){
if(data0.realm !== undefined){
const _errs6 = errors;
if(!(validate56(data0.realm, {instancePath:instancePath+"/observation/realm",parentData:data0,parentDataProperty:"realm",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid1 = _errs6 === errors;
}
else {
var valid1 = true;
}
if(valid1){
if(data0.resource !== undefined){
let data3 = data0.resource;
const _errs7 = errors;
if(typeof data3 !== "string"){
validate157.errors = [{}];
return false;
}
if(!(((((((data3 === "processes") || (data3 === "process")) || (data3 === "mailbox")) || (data3 === "outbox")) || (data3 === "effects")) || (data3 === "payloads")) || (data3 === "history"))){
validate157.errors = [{}];
return false;
}
var valid1 = _errs7 === errors;
}
else {
var valid1 = true;
}
if(valid1){
if(data0.pid !== undefined){
const _errs9 = errors;
if(!(validate62(data0.pid, {instancePath:instancePath+"/observation/pid",parentData:data0,parentDataProperty:"pid",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate62.errors : vErrors.concat(validate62.errors);
errors = vErrors.length;
}
var valid1 = _errs9 === errors;
}
else {
var valid1 = true;
}
if(valid1){
if(data0.cut !== undefined){
const _errs10 = errors;
if(!(validate161(data0.cut, {instancePath:instancePath+"/observation/cut",parentData:data0,parentDataProperty:"cut",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate161.errors : vErrors.concat(validate161.errors);
errors = vErrors.length;
}
var valid1 = _errs10 === errors;
}
else {
var valid1 = true;
}
if(valid1){
if(data0.reader !== undefined){
const _errs11 = errors;
if(!(validate166(data0.reader, {instancePath:instancePath+"/observation/reader",parentData:data0,parentDataProperty:"reader",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate166.errors : vErrors.concat(validate166.errors);
errors = vErrors.length;
}
var valid1 = _errs11 === errors;
}
else {
var valid1 = true;
}
if(valid1){
if(data0.next !== undefined){
const _errs12 = errors;
if(!(validate62(data0.next, {instancePath:instancePath+"/observation/next",parentData:data0,parentDataProperty:"next",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate62.errors : vErrors.concat(validate62.errors);
errors = vErrors.length;
}
var valid1 = _errs12 === errors;
}
else {
var valid1 = true;
}
if(valid1){
if(data0.complete !== undefined){
const _errs13 = errors;
if(typeof data0.complete !== "boolean"){
validate157.errors = [{}];
return false;
}
var valid1 = _errs13 === errors;
}
else {
var valid1 = true;
}
if(valid1){
if(data0.history !== undefined){
let data9 = data0.history;
const _errs15 = errors;
if(typeof data9 !== "string"){
validate157.errors = [{}];
return false;
}
if(!((data9 === "retained") || (data9 === "prefix_reclaimed"))){
validate157.errors = [{}];
return false;
}
var valid1 = _errs15 === errors;
}
else {
var valid1 = true;
}
if(valid1){
if(data0.last_collection !== undefined){
const _errs17 = errors;
if(!(validate62(data0.last_collection, {instancePath:instancePath+"/observation/last_collection",parentData:data0,parentDataProperty:"last_collection",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate62.errors : vErrors.concat(validate62.errors);
errors = vErrors.length;
}
var valid1 = _errs17 === errors;
}
else {
var valid1 = true;
}
if(valid1){
if(data0.scanned !== undefined){
const _errs18 = errors;
if(!(validate168(data0.scanned, {instancePath:instancePath+"/observation/scanned",parentData:data0,parentDataProperty:"scanned",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate168.errors : vErrors.concat(validate168.errors);
errors = vErrors.length;
}
var valid1 = _errs18 === errors;
}
else {
var valid1 = true;
}
if(valid1){
if(data0.processes !== undefined){
const _errs19 = errors;
if(!(validate176(data0.processes, {instancePath:instancePath+"/observation/processes",parentData:data0,parentDataProperty:"processes",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate176.errors : vErrors.concat(validate176.errors);
errors = vErrors.length;
}
var valid1 = _errs19 === errors;
}
else {
var valid1 = true;
}
if(valid1){
if(data0.events !== undefined){
let data13 = data0.events;
const _errs20 = errors;
if(errors === _errs20){
if(Array.isArray(data13)){
if(data13.length > 8){
validate157.errors = [{}];
return false;
}
else {
if(data13.length < 8){
validate157.errors = [{}];
return false;
}
else {
var valid2 = true;
const len0 = data13.length;
for(let i0=0; i0<len0; i0++){
let data14 = data13[i0];
const _errs22 = errors;
const _errs23 = errors;
let valid3 = false;
const _errs24 = errors;
if(errors === _errs24){
if(data14 && typeof data14 == "object" && !Array.isArray(data14)){
let missing2;
if(((((((((((((((data14.position === undefined) && (missing2 = "position")) || ((data14.pid === undefined) && (missing2 = "pid"))) || ((data14.kind === undefined) && (missing2 = "kind"))) || ((data14.policy_revision === undefined) && (missing2 = "policy_revision"))) || ((data14.input === undefined) && (missing2 = "input"))) || ((data14.effect === undefined) && (missing2 = "effect"))) || ((data14.output === undefined) && (missing2 = "output"))) || ((data14.value === undefined) && (missing2 = "value"))) || ((data14.failed === undefined) && (missing2 = "failed"))) || ((data14.generation === undefined) && (missing2 = "generation"))) || ((data14.mailbox_status === undefined) && (missing2 = "mailbox_status"))) || ((data14.admitted === undefined) && (missing2 = "admitted"))) || ((data14.unix_ms === undefined) && (missing2 = "unix_ms"))) || ((data14.clock_error_ms === undefined) && (missing2 = "clock_error_ms"))){
const err0 = {};
if(vErrors === null){
vErrors = [err0];
}
else {
vErrors.push(err0);
}
errors++;
}
else {
const _errs26 = errors;
for(const key2 in data14){
if(!(func1.call(schema64.properties.observation.properties.events.items.anyOf[0].properties, key2))){
const err1 = {};
if(vErrors === null){
vErrors = [err1];
}
else {
vErrors.push(err1);
}
errors++;
break;
}
}
if(_errs26 === errors){
if(data14.position !== undefined){
const _errs27 = errors;
if(!(validate56(data14.position, {instancePath:instancePath+"/observation/events/" + i0+"/position",parentData:data14,parentDataProperty:"position",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid4 = _errs27 === errors;
}
else {
var valid4 = true;
}
if(valid4){
if(data14.pid !== undefined){
const _errs28 = errors;
if(!(validate56(data14.pid, {instancePath:instancePath+"/observation/events/" + i0+"/pid",parentData:data14,parentDataProperty:"pid",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid4 = _errs28 === errors;
}
else {
var valid4 = true;
}
if(valid4){
if(data14.kind !== undefined){
let data17 = data14.kind;
const _errs29 = errors;
if(typeof data17 !== "string"){
const err2 = {};
if(vErrors === null){
vErrors = [err2];
}
else {
vErrors.push(err2);
}
errors++;
}
if(!((((((((((((((((((((((((((((((((((((((((((((data17 === "authorization") || (data17 === "grant")) || (data17 === "revoke")) || (data17 === "spawn")) || (data17 === "own")) || (data17 === "retry")) || (data17 === "send")) || (data17 === "begin_turn")) || (data17 === "turn")) || (data17 === "terminate")) || (data17 === "expire")) || (data17 === "create_resource")) || (data17 === "grant_resource")) || (data17 === "associate")) || (data17 === "open_view")) || (data17 === "close_view")) || (data17 === "retire_resource")) || (data17 === "expire_resource")) || (data17 === "reclaim_resource")) || (data17 === "deliver")) || (data17 === "dispatch")) || (data17 === "observe")) || (data17 === "close_effect")) || (data17 === "cancel_effect")) || (data17 === "checkpoint")) || (data17 === "storage_fence")) || (data17 === "storage_compact")) || (data17 === "turn_with_versions")) || (data17 === "rotate_worker")) || (data17 === "create_principal")) || (data17 === "runtime_intent")) || (data17 === "runtime_observe")) || (data17 === "runtime_upgrade")) || (data17 === "activate")) || (data17 === "create")) || (data17 === "initialize")) || (data17 === "suspend")) || (data17 === "resume")) || (data17 === "expire_suspension")) || (data17 === "declare_payload")) || (data17 === "payload_ready")) || (data17 === "retire_payload")) || (data17 === "payload_deleted")) || (data17 === "collect"))){
const err3 = {};
if(vErrors === null){
vErrors = [err3];
}
else {
vErrors.push(err3);
}
errors++;
}
var valid4 = _errs29 === errors;
}
else {
var valid4 = true;
}
if(valid4){
if(data14.policy_revision !== undefined){
const _errs31 = errors;
if(!(validate56(data14.policy_revision, {instancePath:instancePath+"/observation/events/" + i0+"/policy_revision",parentData:data14,parentDataProperty:"policy_revision",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid4 = _errs31 === errors;
}
else {
var valid4 = true;
}
if(valid4){
if(data14.input !== undefined){
const _errs32 = errors;
if(!(validate62(data14.input, {instancePath:instancePath+"/observation/events/" + i0+"/input",parentData:data14,parentDataProperty:"input",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate62.errors : vErrors.concat(validate62.errors);
errors = vErrors.length;
}
var valid4 = _errs32 === errors;
}
else {
var valid4 = true;
}
if(valid4){
if(data14.effect !== undefined){
const _errs33 = errors;
if(!(validate62(data14.effect, {instancePath:instancePath+"/observation/events/" + i0+"/effect",parentData:data14,parentDataProperty:"effect",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate62.errors : vErrors.concat(validate62.errors);
errors = vErrors.length;
}
var valid4 = _errs33 === errors;
}
else {
var valid4 = true;
}
if(valid4){
if(data14.output !== undefined){
const _errs34 = errors;
if(!(validate62(data14.output, {instancePath:instancePath+"/observation/events/" + i0+"/output",parentData:data14,parentDataProperty:"output",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate62.errors : vErrors.concat(validate62.errors);
errors = vErrors.length;
}
var valid4 = _errs34 === errors;
}
else {
var valid4 = true;
}
if(valid4){
if(data14.value !== undefined){
const _errs35 = errors;
if(!(validate231(data14.value, {instancePath:instancePath+"/observation/events/" + i0+"/value",parentData:data14,parentDataProperty:"value",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate231.errors : vErrors.concat(validate231.errors);
errors = vErrors.length;
}
var valid4 = _errs35 === errors;
}
else {
var valid4 = true;
}
if(valid4){
if(data14.failed !== undefined){
const _errs36 = errors;
if(typeof data14.failed !== "boolean"){
const err4 = {};
if(vErrors === null){
vErrors = [err4];
}
else {
vErrors.push(err4);
}
errors++;
}
var valid4 = _errs36 === errors;
}
else {
var valid4 = true;
}
if(valid4){
if(data14.generation !== undefined){
const _errs38 = errors;
if(!(validate62(data14.generation, {instancePath:instancePath+"/observation/events/" + i0+"/generation",parentData:data14,parentDataProperty:"generation",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate62.errors : vErrors.concat(validate62.errors);
errors = vErrors.length;
}
var valid4 = _errs38 === errors;
}
else {
var valid4 = true;
}
if(valid4){
if(data14.mailbox_status !== undefined){
let data25 = data14.mailbox_status;
const _errs39 = errors;
const _errs40 = errors;
let valid5 = false;
const _errs41 = errors;
if(typeof data25 !== "string"){
const err5 = {};
if(vErrors === null){
vErrors = [err5];
}
else {
vErrors.push(err5);
}
errors++;
}
if(!(((data25 === "pending") || (data25 === "consumed")) || (data25 === "cancelled"))){
const err6 = {};
if(vErrors === null){
vErrors = [err6];
}
else {
vErrors.push(err6);
}
errors++;
}
var _valid1 = _errs41 === errors;
valid5 = valid5 || _valid1;
const _errs43 = errors;
if(data25 !== null){
const err7 = {};
if(vErrors === null){
vErrors = [err7];
}
else {
vErrors.push(err7);
}
errors++;
}
var _valid1 = _errs43 === errors;
valid5 = valid5 || _valid1;
if(!valid5){
const err8 = {};
if(vErrors === null){
vErrors = [err8];
}
else {
vErrors.push(err8);
}
errors++;
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
var valid4 = _errs39 === errors;
}
else {
var valid4 = true;
}
if(valid4){
if(data14.admitted !== undefined){
const _errs45 = errors;
if(typeof data14.admitted !== "boolean"){
const err9 = {};
if(vErrors === null){
vErrors = [err9];
}
else {
vErrors.push(err9);
}
errors++;
}
var valid4 = _errs45 === errors;
}
else {
var valid4 = true;
}
if(valid4){
if(data14.unix_ms !== undefined){
const _errs47 = errors;
if(!(validate62(data14.unix_ms, {instancePath:instancePath+"/observation/events/" + i0+"/unix_ms",parentData:data14,parentDataProperty:"unix_ms",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate62.errors : vErrors.concat(validate62.errors);
errors = vErrors.length;
}
var valid4 = _errs47 === errors;
}
else {
var valid4 = true;
}
if(valid4){
if(data14.clock_error_ms !== undefined){
let data28 = data14.clock_error_ms;
const _errs48 = errors;
const _errs49 = errors;
let valid6 = false;
const _errs50 = errors;
if(!(validate59(data28, {instancePath:instancePath+"/observation/events/" + i0+"/clock_error_ms",parentData:data14,parentDataProperty:"clock_error_ms",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate59.errors : vErrors.concat(validate59.errors);
errors = vErrors.length;
}
var _valid2 = _errs50 === errors;
valid6 = valid6 || _valid2;
const _errs51 = errors;
if(data28 !== null){
const err10 = {};
if(vErrors === null){
vErrors = [err10];
}
else {
vErrors.push(err10);
}
errors++;
}
var _valid2 = _errs51 === errors;
valid6 = valid6 || _valid2;
if(!valid6){
const err11 = {};
if(vErrors === null){
vErrors = [err11];
}
else {
vErrors.push(err11);
}
errors++;
}
else {
errors = _errs49;
if(vErrors !== null){
if(_errs49){
vErrors.length = _errs49;
}
else {
vErrors = null;
}
}
}
var valid4 = _errs48 === errors;
}
else {
var valid4 = true;
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
const err12 = {};
if(vErrors === null){
vErrors = [err12];
}
else {
vErrors.push(err12);
}
errors++;
}
}
var _valid0 = _errs24 === errors;
valid3 = valid3 || _valid0;
const _errs53 = errors;
if(data14 !== null){
const err13 = {};
if(vErrors === null){
vErrors = [err13];
}
else {
vErrors.push(err13);
}
errors++;
}
var _valid0 = _errs53 === errors;
valid3 = valid3 || _valid0;
if(!valid3){
const err14 = {};
if(vErrors === null){
vErrors = [err14];
}
else {
vErrors.push(err14);
}
errors++;
validate157.errors = vErrors;
return false;
}
else {
errors = _errs23;
if(vErrors !== null){
if(_errs23){
vErrors.length = _errs23;
}
else {
vErrors = null;
}
}
}
var valid2 = _errs22 === errors;
if(!valid2){
break;
}
}
}
}
}
else {
validate157.errors = [{}];
return false;
}
}
var valid1 = _errs20 === errors;
}
else {
var valid1 = true;
}
if(valid1){
if(data0.outbox !== undefined){
let data29 = data0.outbox;
const _errs55 = errors;
if(errors === _errs55){
if(Array.isArray(data29)){
if(data29.length > 8){
validate157.errors = [{}];
return false;
}
else {
if(data29.length < 8){
validate157.errors = [{}];
return false;
}
else {
var valid7 = true;
const len1 = data29.length;
for(let i1=0; i1<len1; i1++){
let data30 = data29[i1];
const _errs57 = errors;
const _errs58 = errors;
let valid8 = false;
const _errs59 = errors;
if(errors === _errs59){
if(data30 && typeof data30 == "object" && !Array.isArray(data30)){
let missing3;
if(((((((((((data30.id === undefined) && (missing3 = "id")) || ((data30.source === undefined) && (missing3 = "source"))) || ((data30.turn === undefined) && (missing3 = "turn"))) || ((data30.index === undefined) && (missing3 = "index"))) || ((data30.destination === undefined) && (missing3 = "destination"))) || ((data30.value === undefined) && (missing3 = "value"))) || ((data30.phase === undefined) && (missing3 = "phase"))) || ((data30.resolved_at === undefined) && (missing3 = "resolved_at"))) || ((data30.courier === undefined) && (missing3 = "courier"))) || ((data30.policy_revision === undefined) && (missing3 = "policy_revision"))){
const err15 = {};
if(vErrors === null){
vErrors = [err15];
}
else {
vErrors.push(err15);
}
errors++;
}
else {
const _errs61 = errors;
for(const key3 in data30){
if(!(func1.call(schema64.properties.observation.properties.outbox.items.anyOf[0].properties, key3))){
const err16 = {};
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
if(_errs61 === errors){
if(data30.id !== undefined){
const _errs62 = errors;
if(!(validate56(data30.id, {instancePath:instancePath+"/observation/outbox/" + i1+"/id",parentData:data30,parentDataProperty:"id",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid9 = _errs62 === errors;
}
else {
var valid9 = true;
}
if(valid9){
if(data30.source !== undefined){
const _errs63 = errors;
if(!(validate56(data30.source, {instancePath:instancePath+"/observation/outbox/" + i1+"/source",parentData:data30,parentDataProperty:"source",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid9 = _errs63 === errors;
}
else {
var valid9 = true;
}
if(valid9){
if(data30.turn !== undefined){
const _errs64 = errors;
if(!(validate56(data30.turn, {instancePath:instancePath+"/observation/outbox/" + i1+"/turn",parentData:data30,parentDataProperty:"turn",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid9 = _errs64 === errors;
}
else {
var valid9 = true;
}
if(valid9){
if(data30.index !== undefined){
const _errs65 = errors;
if(!(validate134(data30.index, {instancePath:instancePath+"/observation/outbox/" + i1+"/index",parentData:data30,parentDataProperty:"index",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate134.errors : vErrors.concat(validate134.errors);
errors = vErrors.length;
}
var valid9 = _errs65 === errors;
}
else {
var valid9 = true;
}
if(valid9){
if(data30.destination !== undefined){
const _errs66 = errors;
if(!(validate56(data30.destination, {instancePath:instancePath+"/observation/outbox/" + i1+"/destination",parentData:data30,parentDataProperty:"destination",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid9 = _errs66 === errors;
}
else {
var valid9 = true;
}
if(valid9){
if(data30.value !== undefined){
const _errs67 = errors;
if(!(validate232(data30.value, {instancePath:instancePath+"/observation/outbox/" + i1+"/value",parentData:data30,parentDataProperty:"value",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate232.errors : vErrors.concat(validate232.errors);
errors = vErrors.length;
}
var valid9 = _errs67 === errors;
}
else {
var valid9 = true;
}
if(valid9){
if(data30.phase !== undefined){
let data37 = data30.phase;
const _errs68 = errors;
if(typeof data37 !== "string"){
const err17 = {};
if(vErrors === null){
vErrors = [err17];
}
else {
vErrors.push(err17);
}
errors++;
}
if(!((((((data37 === "pending") || (data37 === "delivered")) || (data37 === "denied")) || (data37 === "expired")) || (data37 === "retired")) || (data37 === "cancelled"))){
const err18 = {};
if(vErrors === null){
vErrors = [err18];
}
else {
vErrors.push(err18);
}
errors++;
}
var valid9 = _errs68 === errors;
}
else {
var valid9 = true;
}
if(valid9){
if(data30.resolved_at !== undefined){
const _errs70 = errors;
if(!(validate62(data30.resolved_at, {instancePath:instancePath+"/observation/outbox/" + i1+"/resolved_at",parentData:data30,parentDataProperty:"resolved_at",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate62.errors : vErrors.concat(validate62.errors);
errors = vErrors.length;
}
var valid9 = _errs70 === errors;
}
else {
var valid9 = true;
}
if(valid9){
if(data30.courier !== undefined){
const _errs71 = errors;
if(!(validate62(data30.courier, {instancePath:instancePath+"/observation/outbox/" + i1+"/courier",parentData:data30,parentDataProperty:"courier",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate62.errors : vErrors.concat(validate62.errors);
errors = vErrors.length;
}
var valid9 = _errs71 === errors;
}
else {
var valid9 = true;
}
if(valid9){
if(data30.policy_revision !== undefined){
const _errs72 = errors;
if(!(validate62(data30.policy_revision, {instancePath:instancePath+"/observation/outbox/" + i1+"/policy_revision",parentData:data30,parentDataProperty:"policy_revision",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate62.errors : vErrors.concat(validate62.errors);
errors = vErrors.length;
}
var valid9 = _errs72 === errors;
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
else {
const err19 = {};
if(vErrors === null){
vErrors = [err19];
}
else {
vErrors.push(err19);
}
errors++;
}
}
var _valid3 = _errs59 === errors;
valid8 = valid8 || _valid3;
const _errs73 = errors;
if(data30 !== null){
const err20 = {};
if(vErrors === null){
vErrors = [err20];
}
else {
vErrors.push(err20);
}
errors++;
}
var _valid3 = _errs73 === errors;
valid8 = valid8 || _valid3;
if(!valid8){
const err21 = {};
if(vErrors === null){
vErrors = [err21];
}
else {
vErrors.push(err21);
}
errors++;
validate157.errors = vErrors;
return false;
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
var valid7 = _errs57 === errors;
if(!valid7){
break;
}
}
}
}
}
else {
validate157.errors = [{}];
return false;
}
}
var valid1 = _errs55 === errors;
}
else {
var valid1 = true;
}
if(valid1){
if(data0.effects !== undefined){
let data41 = data0.effects;
const _errs75 = errors;
if(errors === _errs75){
if(Array.isArray(data41)){
if(data41.length > 8){
validate157.errors = [{}];
return false;
}
else {
if(data41.length < 8){
validate157.errors = [{}];
return false;
}
else {
var valid10 = true;
const len2 = data41.length;
for(let i2=0; i2<len2; i2++){
let data42 = data41[i2];
const _errs77 = errors;
const _errs78 = errors;
let valid11 = false;
const _errs79 = errors;
if(errors === _errs79){
if(data42 && typeof data42 == "object" && !Array.isArray(data42)){
let missing4;
if(((((((((((((((data42.id === undefined) && (missing4 = "id")) || ((data42.pid === undefined) && (missing4 = "pid"))) || ((data42.payload === undefined) && (missing4 = "payload"))) || ((data42.phase === undefined) && (missing4 = "phase"))) || ((data42.attempt === undefined) && (missing4 = "attempt"))) || ((data42.executor === undefined) && (missing4 = "executor"))) || ((data42.authorization_policy === undefined) && (missing4 = "authorization_policy"))) || ((data42.last_observation === undefined) && (missing4 = "last_observation"))) || ((data42.closure === undefined) && (missing4 = "closure"))) || ((data42.result === undefined) && (missing4 = "result"))) || ((data42.closed_at === undefined) && (missing4 = "closed_at"))) || ((data42.reconcile_before_ms === undefined) && (missing4 = "reconcile_before_ms"))) || ((data42.max_observations === undefined) && (missing4 = "max_observations"))) || ((data42.observations === undefined) && (missing4 = "observations"))){
const err22 = {};
if(vErrors === null){
vErrors = [err22];
}
else {
vErrors.push(err22);
}
errors++;
}
else {
const _errs81 = errors;
for(const key4 in data42){
if(!(func1.call(schema64.properties.observation.properties.effects.items.anyOf[0].properties, key4))){
const err23 = {};
if(vErrors === null){
vErrors = [err23];
}
else {
vErrors.push(err23);
}
errors++;
break;
}
}
if(_errs81 === errors){
if(data42.id !== undefined){
const _errs82 = errors;
if(!(validate56(data42.id, {instancePath:instancePath+"/observation/effects/" + i2+"/id",parentData:data42,parentDataProperty:"id",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid12 = _errs82 === errors;
}
else {
var valid12 = true;
}
if(valid12){
if(data42.pid !== undefined){
const _errs83 = errors;
if(!(validate56(data42.pid, {instancePath:instancePath+"/observation/effects/" + i2+"/pid",parentData:data42,parentDataProperty:"pid",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid12 = _errs83 === errors;
}
else {
var valid12 = true;
}
if(valid12){
if(data42.payload !== undefined){
const _errs84 = errors;
if(!(validate232(data42.payload, {instancePath:instancePath+"/observation/effects/" + i2+"/payload",parentData:data42,parentDataProperty:"payload",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate232.errors : vErrors.concat(validate232.errors);
errors = vErrors.length;
}
var valid12 = _errs84 === errors;
}
else {
var valid12 = true;
}
if(valid12){
if(data42.phase !== undefined){
let data46 = data42.phase;
const _errs85 = errors;
if(typeof data46 !== "string"){
const err24 = {};
if(vErrors === null){
vErrors = [err24];
}
else {
vErrors.push(err24);
}
errors++;
}
if(!((((((data46 === "pending") || (data46 === "authorized")) || (data46 === "unknown")) || (data46 === "observed")) || (data46 === "cancelled")) || (data46 === "closed_unknown"))){
const err25 = {};
if(vErrors === null){
vErrors = [err25];
}
else {
vErrors.push(err25);
}
errors++;
}
var valid12 = _errs85 === errors;
}
else {
var valid12 = true;
}
if(valid12){
if(data42.attempt !== undefined){
const _errs87 = errors;
if(!(validate62(data42.attempt, {instancePath:instancePath+"/observation/effects/" + i2+"/attempt",parentData:data42,parentDataProperty:"attempt",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate62.errors : vErrors.concat(validate62.errors);
errors = vErrors.length;
}
var valid12 = _errs87 === errors;
}
else {
var valid12 = true;
}
if(valid12){
if(data42.executor !== undefined){
const _errs88 = errors;
if(!(validate62(data42.executor, {instancePath:instancePath+"/observation/effects/" + i2+"/executor",parentData:data42,parentDataProperty:"executor",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate62.errors : vErrors.concat(validate62.errors);
errors = vErrors.length;
}
var valid12 = _errs88 === errors;
}
else {
var valid12 = true;
}
if(valid12){
if(data42.authorization_policy !== undefined){
const _errs89 = errors;
if(!(validate62(data42.authorization_policy, {instancePath:instancePath+"/observation/effects/" + i2+"/authorization_policy",parentData:data42,parentDataProperty:"authorization_policy",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate62.errors : vErrors.concat(validate62.errors);
errors = vErrors.length;
}
var valid12 = _errs89 === errors;
}
else {
var valid12 = true;
}
if(valid12){
if(data42.last_observation !== undefined){
let data50 = data42.last_observation;
const _errs90 = errors;
const _errs91 = errors;
let valid13 = false;
const _errs92 = errors;
if(errors === _errs92){
if(data50 && typeof data50 == "object" && !Array.isArray(data50)){
let missing5;
if(((data50.input === undefined) && (missing5 = "input")) || ((data50.policy_revision === undefined) && (missing5 = "policy_revision"))){
const err26 = {};
if(vErrors === null){
vErrors = [err26];
}
else {
vErrors.push(err26);
}
errors++;
}
else {
const _errs94 = errors;
for(const key5 in data50){
if(!((key5 === "input") || (key5 === "policy_revision"))){
const err27 = {};
if(vErrors === null){
vErrors = [err27];
}
else {
vErrors.push(err27);
}
errors++;
break;
}
}
if(_errs94 === errors){
if(data50.input !== undefined){
const _errs95 = errors;
if(!(validate56(data50.input, {instancePath:instancePath+"/observation/effects/" + i2+"/last_observation/input",parentData:data50,parentDataProperty:"input",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid14 = _errs95 === errors;
}
else {
var valid14 = true;
}
if(valid14){
if(data50.policy_revision !== undefined){
const _errs96 = errors;
if(!(validate56(data50.policy_revision, {instancePath:instancePath+"/observation/effects/" + i2+"/last_observation/policy_revision",parentData:data50,parentDataProperty:"policy_revision",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid14 = _errs96 === errors;
}
else {
var valid14 = true;
}
}
}
}
}
else {
const err28 = {};
if(vErrors === null){
vErrors = [err28];
}
else {
vErrors.push(err28);
}
errors++;
}
}
var _valid5 = _errs92 === errors;
valid13 = valid13 || _valid5;
const _errs97 = errors;
if(data50 !== null){
const err29 = {};
if(vErrors === null){
vErrors = [err29];
}
else {
vErrors.push(err29);
}
errors++;
}
var _valid5 = _errs97 === errors;
valid13 = valid13 || _valid5;
if(!valid13){
const err30 = {};
if(vErrors === null){
vErrors = [err30];
}
else {
vErrors.push(err30);
}
errors++;
}
else {
errors = _errs91;
if(vErrors !== null){
if(_errs91){
vErrors.length = _errs91;
}
else {
vErrors = null;
}
}
}
var valid12 = _errs90 === errors;
}
else {
var valid12 = true;
}
if(valid12){
if(data42.closure !== undefined){
let data53 = data42.closure;
const _errs99 = errors;
const _errs100 = errors;
let valid15 = false;
const _errs101 = errors;
if(errors === _errs101){
if(data53 && typeof data53 == "object" && !Array.isArray(data53)){
let missing6;
if(((((data53.reason === undefined) && (missing6 = "reason")) || ((data53.principal === undefined) && (missing6 = "principal"))) || ((data53.policy_revision === undefined) && (missing6 = "policy_revision"))) || ((data53.clock_lower_ms === undefined) && (missing6 = "clock_lower_ms"))){
const err31 = {};
if(vErrors === null){
vErrors = [err31];
}
else {
vErrors.push(err31);
}
errors++;
}
else {
const _errs103 = errors;
for(const key6 in data53){
if(!((((key6 === "reason") || (key6 === "principal")) || (key6 === "policy_revision")) || (key6 === "clock_lower_ms"))){
const err32 = {};
if(vErrors === null){
vErrors = [err32];
}
else {
vErrors.push(err32);
}
errors++;
break;
}
}
if(_errs103 === errors){
if(data53.reason !== undefined){
let data54 = data53.reason;
const _errs104 = errors;
if(typeof data54 !== "string"){
const err33 = {};
if(vErrors === null){
vErrors = [err33];
}
else {
vErrors.push(err33);
}
errors++;
}
if(!(((((data54 === "observed") || (data54 === "observation_budget")) || (data54 === "abandoned")) || (data54 === "deadline")) || (data54 === "unattempted_cancel"))){
const err34 = {};
if(vErrors === null){
vErrors = [err34];
}
else {
vErrors.push(err34);
}
errors++;
}
var valid16 = _errs104 === errors;
}
else {
var valid16 = true;
}
if(valid16){
if(data53.principal !== undefined){
const _errs106 = errors;
if(!(validate56(data53.principal, {instancePath:instancePath+"/observation/effects/" + i2+"/closure/principal",parentData:data53,parentDataProperty:"principal",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid16 = _errs106 === errors;
}
else {
var valid16 = true;
}
if(valid16){
if(data53.policy_revision !== undefined){
const _errs107 = errors;
if(!(validate56(data53.policy_revision, {instancePath:instancePath+"/observation/effects/" + i2+"/closure/policy_revision",parentData:data53,parentDataProperty:"policy_revision",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid16 = _errs107 === errors;
}
else {
var valid16 = true;
}
if(valid16){
if(data53.clock_lower_ms !== undefined){
const _errs108 = errors;
if(!(validate62(data53.clock_lower_ms, {instancePath:instancePath+"/observation/effects/" + i2+"/closure/clock_lower_ms",parentData:data53,parentDataProperty:"clock_lower_ms",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate62.errors : vErrors.concat(validate62.errors);
errors = vErrors.length;
}
var valid16 = _errs108 === errors;
}
else {
var valid16 = true;
}
}
}
}
}
}
}
else {
const err35 = {};
if(vErrors === null){
vErrors = [err35];
}
else {
vErrors.push(err35);
}
errors++;
}
}
var _valid6 = _errs101 === errors;
valid15 = valid15 || _valid6;
const _errs109 = errors;
if(data53 !== null){
const err36 = {};
if(vErrors === null){
vErrors = [err36];
}
else {
vErrors.push(err36);
}
errors++;
}
var _valid6 = _errs109 === errors;
valid15 = valid15 || _valid6;
if(!valid15){
const err37 = {};
if(vErrors === null){
vErrors = [err37];
}
else {
vErrors.push(err37);
}
errors++;
}
else {
errors = _errs100;
if(vErrors !== null){
if(_errs100){
vErrors.length = _errs100;
}
else {
vErrors = null;
}
}
}
var valid12 = _errs99 === errors;
}
else {
var valid12 = true;
}
if(valid12){
if(data42.result !== undefined){
const _errs111 = errors;
if(!(validate231(data42.result, {instancePath:instancePath+"/observation/effects/" + i2+"/result",parentData:data42,parentDataProperty:"result",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate231.errors : vErrors.concat(validate231.errors);
errors = vErrors.length;
}
var valid12 = _errs111 === errors;
}
else {
var valid12 = true;
}
if(valid12){
if(data42.closed_at !== undefined){
const _errs112 = errors;
if(!(validate62(data42.closed_at, {instancePath:instancePath+"/observation/effects/" + i2+"/closed_at",parentData:data42,parentDataProperty:"closed_at",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate62.errors : vErrors.concat(validate62.errors);
errors = vErrors.length;
}
var valid12 = _errs112 === errors;
}
else {
var valid12 = true;
}
if(valid12){
if(data42.reconcile_before_ms !== undefined){
const _errs113 = errors;
if(!(validate62(data42.reconcile_before_ms, {instancePath:instancePath+"/observation/effects/" + i2+"/reconcile_before_ms",parentData:data42,parentDataProperty:"reconcile_before_ms",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate62.errors : vErrors.concat(validate62.errors);
errors = vErrors.length;
}
var valid12 = _errs113 === errors;
}
else {
var valid12 = true;
}
if(valid12){
if(data42.max_observations !== undefined){
const _errs114 = errors;
if(!(validate168(data42.max_observations, {instancePath:instancePath+"/observation/effects/" + i2+"/max_observations",parentData:data42,parentDataProperty:"max_observations",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate168.errors : vErrors.concat(validate168.errors);
errors = vErrors.length;
}
var valid12 = _errs114 === errors;
}
else {
var valid12 = true;
}
if(valid12){
if(data42.observations !== undefined){
const _errs115 = errors;
if(!(validate168(data42.observations, {instancePath:instancePath+"/observation/effects/" + i2+"/observations",parentData:data42,parentDataProperty:"observations",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate168.errors : vErrors.concat(validate168.errors);
errors = vErrors.length;
}
var valid12 = _errs115 === errors;
}
else {
var valid12 = true;
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
const err38 = {};
if(vErrors === null){
vErrors = [err38];
}
else {
vErrors.push(err38);
}
errors++;
}
}
var _valid4 = _errs79 === errors;
valid11 = valid11 || _valid4;
const _errs116 = errors;
if(data42 !== null){
const err39 = {};
if(vErrors === null){
vErrors = [err39];
}
else {
vErrors.push(err39);
}
errors++;
}
var _valid4 = _errs116 === errors;
valid11 = valid11 || _valid4;
if(!valid11){
const err40 = {};
if(vErrors === null){
vErrors = [err40];
}
else {
vErrors.push(err40);
}
errors++;
validate157.errors = vErrors;
return false;
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
if(!valid10){
break;
}
}
}
}
}
else {
validate157.errors = [{}];
return false;
}
}
var valid1 = _errs75 === errors;
}
else {
var valid1 = true;
}
if(valid1){
if(data0.payloads !== undefined){
let data63 = data0.payloads;
const _errs118 = errors;
if(errors === _errs118){
if(Array.isArray(data63)){
if(data63.length > 8){
validate157.errors = [{}];
return false;
}
else {
if(data63.length < 8){
validate157.errors = [{}];
return false;
}
else {
var valid17 = true;
const len3 = data63.length;
for(let i3=0; i3<len3; i3++){
let data64 = data63[i3];
const _errs120 = errors;
const _errs121 = errors;
let valid18 = false;
const _errs122 = errors;
if(errors === _errs122){
if(data64 && typeof data64 == "object" && !Array.isArray(data64)){
let missing7;
if((((((((((data64.id === undefined) && (missing7 = "id")) || ((data64.pid === undefined) && (missing7 = "pid"))) || ((data64.publisher === undefined) && (missing7 = "publisher"))) || ((data64.sha256 === undefined) && (missing7 = "sha256"))) || ((data64.bytes === undefined) && (missing7 = "bytes"))) || ((data64.allow_delete === undefined) && (missing7 = "allow_delete"))) || ((data64.phase === undefined) && (missing7 = "phase"))) || ((data64.retired_at === undefined) && (missing7 = "retired_at"))) || ((data64.deleted_at === undefined) && (missing7 = "deleted_at"))){
const err41 = {};
if(vErrors === null){
vErrors = [err41];
}
else {
vErrors.push(err41);
}
errors++;
}
else {
const _errs124 = errors;
for(const key7 in data64){
if(!(func1.call(schema64.properties.observation.properties.payloads.items.anyOf[0].properties, key7))){
const err42 = {};
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
if(_errs124 === errors){
if(data64.id !== undefined){
const _errs125 = errors;
if(!(validate56(data64.id, {instancePath:instancePath+"/observation/payloads/" + i3+"/id",parentData:data64,parentDataProperty:"id",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid19 = _errs125 === errors;
}
else {
var valid19 = true;
}
if(valid19){
if(data64.pid !== undefined){
const _errs126 = errors;
if(!(validate56(data64.pid, {instancePath:instancePath+"/observation/payloads/" + i3+"/pid",parentData:data64,parentDataProperty:"pid",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid19 = _errs126 === errors;
}
else {
var valid19 = true;
}
if(valid19){
if(data64.publisher !== undefined){
const _errs127 = errors;
if(!(validate56(data64.publisher, {instancePath:instancePath+"/observation/payloads/" + i3+"/publisher",parentData:data64,parentDataProperty:"publisher",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid19 = _errs127 === errors;
}
else {
var valid19 = true;
}
if(valid19){
if(data64.sha256 !== undefined){
const _errs128 = errors;
if(!(validate133(data64.sha256, {instancePath:instancePath+"/observation/payloads/" + i3+"/sha256",parentData:data64,parentDataProperty:"sha256",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate133.errors : vErrors.concat(validate133.errors);
errors = vErrors.length;
}
var valid19 = _errs128 === errors;
}
else {
var valid19 = true;
}
if(valid19){
if(data64.bytes !== undefined){
const _errs129 = errors;
if(!(validate59(data64.bytes, {instancePath:instancePath+"/observation/payloads/" + i3+"/bytes",parentData:data64,parentDataProperty:"bytes",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate59.errors : vErrors.concat(validate59.errors);
errors = vErrors.length;
}
var valid19 = _errs129 === errors;
}
else {
var valid19 = true;
}
if(valid19){
if(data64.allow_delete !== undefined){
const _errs130 = errors;
if(typeof data64.allow_delete !== "boolean"){
const err43 = {};
if(vErrors === null){
vErrors = [err43];
}
else {
vErrors.push(err43);
}
errors++;
}
var valid19 = _errs130 === errors;
}
else {
var valid19 = true;
}
if(valid19){
if(data64.phase !== undefined){
let data71 = data64.phase;
const _errs132 = errors;
if(typeof data71 !== "string"){
const err44 = {};
if(vErrors === null){
vErrors = [err44];
}
else {
vErrors.push(err44);
}
errors++;
}
if(!((((data71 === "creating") || (data71 === "ready")) || (data71 === "retiring")) || (data71 === "deleted"))){
const err45 = {};
if(vErrors === null){
vErrors = [err45];
}
else {
vErrors.push(err45);
}
errors++;
}
var valid19 = _errs132 === errors;
}
else {
var valid19 = true;
}
if(valid19){
if(data64.retired_at !== undefined){
const _errs134 = errors;
if(!(validate62(data64.retired_at, {instancePath:instancePath+"/observation/payloads/" + i3+"/retired_at",parentData:data64,parentDataProperty:"retired_at",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate62.errors : vErrors.concat(validate62.errors);
errors = vErrors.length;
}
var valid19 = _errs134 === errors;
}
else {
var valid19 = true;
}
if(valid19){
if(data64.deleted_at !== undefined){
const _errs135 = errors;
if(!(validate62(data64.deleted_at, {instancePath:instancePath+"/observation/payloads/" + i3+"/deleted_at",parentData:data64,parentDataProperty:"deleted_at",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate62.errors : vErrors.concat(validate62.errors);
errors = vErrors.length;
}
var valid19 = _errs135 === errors;
}
else {
var valid19 = true;
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
const err46 = {};
if(vErrors === null){
vErrors = [err46];
}
else {
vErrors.push(err46);
}
errors++;
}
}
var _valid7 = _errs122 === errors;
valid18 = valid18 || _valid7;
const _errs136 = errors;
if(data64 !== null){
const err47 = {};
if(vErrors === null){
vErrors = [err47];
}
else {
vErrors.push(err47);
}
errors++;
}
var _valid7 = _errs136 === errors;
valid18 = valid18 || _valid7;
if(!valid18){
const err48 = {};
if(vErrors === null){
vErrors = [err48];
}
else {
vErrors.push(err48);
}
errors++;
validate157.errors = vErrors;
return false;
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
var valid17 = _errs120 === errors;
if(!valid17){
break;
}
}
}
}
}
else {
validate157.errors = [{}];
return false;
}
}
var valid1 = _errs118 === errors;
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
}
else {
validate157.errors = [{}];
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
let data74 = data.edges;
const _errs138 = errors;
if(errors === _errs138){
if(Array.isArray(data74)){
if(data74.length > 16){
validate157.errors = [{}];
return false;
}
else {
if(data74.length < 16){
validate157.errors = [{}];
return false;
}
else {
var valid20 = true;
const len4 = data74.length;
for(let i4=0; i4<len4; i4++){
let data75 = data74[i4];
const _errs140 = errors;
const _errs141 = errors;
let valid21 = false;
const _errs142 = errors;
if(errors === _errs142){
if(data75 && typeof data75 == "object" && !Array.isArray(data75)){
let missing8;
if((((((data75.from === undefined) && (missing8 = "from")) || ((data75.to === undefined) && (missing8 = "to"))) || ((data75.relation === undefined) && (missing8 = "relation"))) || ((data75.from_coverage === undefined) && (missing8 = "from_coverage"))) || ((data75.to_coverage === undefined) && (missing8 = "to_coverage"))){
const err49 = {};
if(vErrors === null){
vErrors = [err49];
}
else {
vErrors.push(err49);
}
errors++;
}
else {
const _errs144 = errors;
for(const key8 in data75){
if(!(((((key8 === "from") || (key8 === "to")) || (key8 === "relation")) || (key8 === "from_coverage")) || (key8 === "to_coverage"))){
const err50 = {};
if(vErrors === null){
vErrors = [err50];
}
else {
vErrors.push(err50);
}
errors++;
break;
}
}
if(_errs144 === errors){
if(data75.from !== undefined){
const _errs145 = errors;
if(!(validate284(data75.from, {instancePath:instancePath+"/edges/" + i4+"/from",parentData:data75,parentDataProperty:"from",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate284.errors : vErrors.concat(validate284.errors);
errors = vErrors.length;
}
var valid22 = _errs145 === errors;
}
else {
var valid22 = true;
}
if(valid22){
if(data75.to !== undefined){
const _errs146 = errors;
if(!(validate284(data75.to, {instancePath:instancePath+"/edges/" + i4+"/to",parentData:data75,parentDataProperty:"to",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate284.errors : vErrors.concat(validate284.errors);
errors = vErrors.length;
}
var valid22 = _errs146 === errors;
}
else {
var valid22 = true;
}
if(valid22){
if(data75.relation !== undefined){
let data78 = data75.relation;
const _errs147 = errors;
if(typeof data78 !== "string"){
const err51 = {};
if(vErrors === null){
vErrors = [err51];
}
else {
vErrors.push(err51);
}
errors++;
}
if(!(((((data78 === "input_to_turn") || (data78 === "turn_to_effect")) || (data78 === "turn_to_output")) || (data78 === "output_to_admission")) || (data78 === "effect_to_observation"))){
const err52 = {};
if(vErrors === null){
vErrors = [err52];
}
else {
vErrors.push(err52);
}
errors++;
}
var valid22 = _errs147 === errors;
}
else {
var valid22 = true;
}
if(valid22){
if(data75.from_coverage !== undefined){
const _errs149 = errors;
if(!(validate292(data75.from_coverage, {instancePath:instancePath+"/edges/" + i4+"/from_coverage",parentData:data75,parentDataProperty:"from_coverage",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate292.errors : vErrors.concat(validate292.errors);
errors = vErrors.length;
}
var valid22 = _errs149 === errors;
}
else {
var valid22 = true;
}
if(valid22){
if(data75.to_coverage !== undefined){
const _errs150 = errors;
if(!(validate292(data75.to_coverage, {instancePath:instancePath+"/edges/" + i4+"/to_coverage",parentData:data75,parentDataProperty:"to_coverage",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate292.errors : vErrors.concat(validate292.errors);
errors = vErrors.length;
}
var valid22 = _errs150 === errors;
}
else {
var valid22 = true;
}
}
}
}
}
}
}
}
else {
const err53 = {};
if(vErrors === null){
vErrors = [err53];
}
else {
vErrors.push(err53);
}
errors++;
}
}
var _valid8 = _errs142 === errors;
valid21 = valid21 || _valid8;
const _errs151 = errors;
if(data75 !== null){
const err54 = {};
if(vErrors === null){
vErrors = [err54];
}
else {
vErrors.push(err54);
}
errors++;
}
var _valid8 = _errs151 === errors;
valid21 = valid21 || _valid8;
if(!valid21){
const err55 = {};
if(vErrors === null){
vErrors = [err55];
}
else {
vErrors.push(err55);
}
errors++;
validate157.errors = vErrors;
return false;
}
else {
errors = _errs141;
if(vErrors !== null){
if(_errs141){
vErrors.length = _errs141;
}
else {
vErrors = null;
}
}
}
var valid20 = _errs140 === errors;
if(!valid20){
break;
}
}
}
}
}
else {
validate157.errors = [{}];
return false;
}
}
var valid0 = _errs138 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.effect_diagnostics !== undefined){
let data81 = data.effect_diagnostics;
const _errs153 = errors;
if(errors === _errs153){
if(Array.isArray(data81)){
if(data81.length > 8){
validate157.errors = [{}];
return false;
}
else {
if(data81.length < 8){
validate157.errors = [{}];
return false;
}
else {
var valid23 = true;
const len5 = data81.length;
for(let i5=0; i5<len5; i5++){
const _errs155 = errors;
if(!(validate71(data81[i5], {instancePath:instancePath+"/effect_diagnostics/" + i5,parentData:data81,parentDataProperty:i5,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate71.errors : vErrors.concat(validate71.errors);
errors = vErrors.length;
}
var valid23 = _errs155 === errors;
if(!valid23){
break;
}
}
}
}
}
else {
validate157.errors = [{}];
return false;
}
}
var valid0 = _errs153 === errors;
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
validate157.errors = [{}];
return false;
}
}
validate157.errors = vErrors;
return errors === 0;
}
validate157.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

export const StateResponse = validate296;
const schema92 = {"type":"object","additionalProperties":false,"properties":{"observation":{"type":"object","additionalProperties":false,"properties":{"version":{"$ref":"https://transit.invalid/generated-validator/0"},"realm":{"$ref":"https://transit.invalid/generated-validator/1"},"principal_sequence":{"$ref":"https://transit.invalid/generated-validator/1"},"reader":{"$ref":"https://transit.invalid/generated-validator/5"},"kind":{"type":"string","enum":["resources","associations","entries"]},"cut":{"$ref":"https://transit.invalid/generated-validator/3"},"next":{"$ref":"https://transit.invalid/generated-validator/2"},"next_key":{"$ref":"https://transit.invalid/generated-validator/22"},"resources":{"$ref":"https://transit.invalid/generated-validator/71"},"associations":{"type":"array","minItems":8,"maxItems":8,"items":{"anyOf":[{"type":"object","additionalProperties":false,"properties":{"pid":{"$ref":"https://transit.invalid/generated-validator/1"},"name":{"$ref":"https://transit.invalid/generated-validator/21"},"resource":{"$ref":"https://transit.invalid/generated-validator/1"},"revision":{"$ref":"https://transit.invalid/generated-validator/1"},"required":{"type":"boolean"}},"required":["pid","name","resource","revision","required"]},{"type":"null"}]}},"entries":{"type":"array","minItems":8,"maxItems":8,"items":{"anyOf":[{"type":"object","additionalProperties":false,"properties":{"key":{"$ref":"https://transit.invalid/generated-validator/21"},"value":{"$ref":"https://transit.invalid/generated-validator/21"},"revision":{"$ref":"https://transit.invalid/generated-validator/1"}},"required":["key","value","revision"]},{"type":"null"}]}}},"required":["version","realm","principal_sequence","reader","kind","cut","next","next_key","resources","associations","entries"]},"framework":{"type":"array","minItems":8,"maxItems":8,"items":{"anyOf":[{"type":"object","additionalProperties":false,"properties":{"version":{"$ref":"https://transit.invalid/generated-validator/9"},"source":{"$ref":"https://transit.invalid/generated-validator/72"},"declaration":{"oneOf":[{"type":"object","additionalProperties":false,"required":["behavior"],"properties":{"behavior":{"type":"string","enum":["genserver"]}}},{"type":"object","additionalProperties":false,"required":["table"],"properties":{"table":{"type":"object","additionalProperties":false,"properties":{"object":{"$ref":"https://transit.invalid/generated-validator/21"},"revision":{"$ref":"https://transit.invalid/generated-validator/21"},"rows":{"$ref":"https://transit.invalid/generated-validator/21"},"retired":{"type":"boolean"},"pending":{"$ref":"https://transit.invalid/generated-validator/22"},"schema":{"type":"object","additionalProperties":false,"properties":{"record":{"$ref":"https://transit.invalid/generated-validator/21"},"bytes":{"$ref":"https://transit.invalid/generated-validator/0"},"digest":{"$ref":"https://transit.invalid/generated-validator/11"}},"required":["record","bytes","digest"]}},"required":["object","revision","rows","retired","pending","schema"]}}},{"type":"object","additionalProperties":false,"required":["registry_scope"],"properties":{"registry_scope":{"type":"object","additionalProperties":false,"properties":{"id":{"$ref":"https://transit.invalid/generated-validator/0"}},"required":["id"]}}},{"type":"object","additionalProperties":false,"required":["registry_binding"],"properties":{"registry_binding":{"type":"object","additionalProperties":false,"properties":{"scope":{"$ref":"https://transit.invalid/generated-validator/0"},"name":{"$ref":"https://transit.invalid/generated-validator/21"},"revision":{"$ref":"https://transit.invalid/generated-validator/1"},"destination":{"$ref":"https://transit.invalid/generated-validator/2"}},"required":["scope","name","revision","destination"]}}},{"type":"object","additionalProperties":false,"required":["child"],"properties":{"child":{"type":"object","additionalProperties":false,"properties":{"pid":{"$ref":"https://transit.invalid/generated-validator/1"},"generation":{"$ref":"https://transit.invalid/generated-validator/1"},"phase":{"type":"string","enum":["watching","retry_wait","retry_requested","exhausted","retired","suspended","placement_unavailable","initializing"]},"attempts":{"$ref":"https://transit.invalid/generated-validator/9"},"limit":{"$ref":"https://transit.invalid/generated-validator/9"},"retry_at_ms":{"$ref":"https://transit.invalid/generated-validator/1"},"successor":{"$ref":"https://transit.invalid/generated-validator/2"}},"required":["pid","generation","phase","attempts","limit","retry_at_ms","successor"]}}},{"type":"object","additionalProperties":false,"required":["wait"],"properties":{"wait":{"type":"object","additionalProperties":false,"properties":{"correlation":{"$ref":"https://transit.invalid/generated-validator/21"},"target":{"$ref":"https://transit.invalid/generated-validator/1"},"phase":{"type":"string","enum":["waiting","replied","timed_out","cancelled"]},"deadline_ms":{"$ref":"https://transit.invalid/generated-validator/2"},"observer":{"$ref":"https://transit.invalid/generated-validator/2"},"resolution_input":{"$ref":"https://transit.invalid/generated-validator/1"}},"required":["correlation","target","phase","deadline_ms","observer","resolution_input"]}}}]}},"required":["version","source","declaration"]},{"type":"null"}]}}},"required":["observation","framework"]};
const schema93 = {"type":"array","minItems":8,"maxItems":8,"items":{"$ref":"https://transit.invalid/generated-validator/70"}};
const schema94 = {"anyOf":[{"$ref":"https://transit.invalid/generated-validator/69"},{"type":"null"}]};
const schema95 = {"type":"object","additionalProperties":false,"properties":{"id":{"$ref":"https://transit.invalid/generated-validator/1"},"writer":{"$ref":"https://transit.invalid/generated-validator/1"},"owner":{"$ref":"https://transit.invalid/generated-validator/2"},"revision":{"$ref":"https://transit.invalid/generated-validator/1"},"entries":{"$ref":"https://transit.invalid/generated-validator/1"},"block_entries":{"$ref":"https://transit.invalid/generated-validator/1"},"history_ms":{"$ref":"https://transit.invalid/generated-validator/2"},"changed_ms":{"$ref":"https://transit.invalid/generated-validator/1"},"last_turn":{"$ref":"https://transit.invalid/generated-validator/2"},"deadline_ms":{"$ref":"https://transit.invalid/generated-validator/2"},"phase":{"$ref":"https://transit.invalid/generated-validator/68"},"retired_at":{"$ref":"https://transit.invalid/generated-validator/2"}},"required":["id","writer","owner","revision","entries","block_entries","history_ms","changed_ms","last_turn","deadline_ms","phase","retired_at"]};
const schema96 = {"type":"string","enum":["active","retired","reclaimed"]};

function validate317(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate317.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate317.errors = [{}];
return false;
}
if(!(((data === "active") || (data === "retired")) || (data === "reclaimed"))){
validate317.errors = [{}];
return false;
}
validate317.errors = vErrors;
return errors === 0;
}
validate317.evaluated = {"dynamicProps":false,"dynamicItems":false};


function validate306(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate306.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if(((((((((((((data.id === undefined) && (missing0 = "id")) || ((data.writer === undefined) && (missing0 = "writer"))) || ((data.owner === undefined) && (missing0 = "owner"))) || ((data.revision === undefined) && (missing0 = "revision"))) || ((data.entries === undefined) && (missing0 = "entries"))) || ((data.block_entries === undefined) && (missing0 = "block_entries"))) || ((data.history_ms === undefined) && (missing0 = "history_ms"))) || ((data.changed_ms === undefined) && (missing0 = "changed_ms"))) || ((data.last_turn === undefined) && (missing0 = "last_turn"))) || ((data.deadline_ms === undefined) && (missing0 = "deadline_ms"))) || ((data.phase === undefined) && (missing0 = "phase"))) || ((data.retired_at === undefined) && (missing0 = "retired_at"))){
validate306.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(func1.call(schema95.properties, key0))){
validate306.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.id !== undefined){
const _errs2 = errors;
if(!(validate56(data.id, {instancePath:instancePath+"/id",parentData:data,parentDataProperty:"id",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.writer !== undefined){
const _errs3 = errors;
if(!(validate56(data.writer, {instancePath:instancePath+"/writer",parentData:data,parentDataProperty:"writer",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid0 = _errs3 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.owner !== undefined){
const _errs4 = errors;
if(!(validate62(data.owner, {instancePath:instancePath+"/owner",parentData:data,parentDataProperty:"owner",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate62.errors : vErrors.concat(validate62.errors);
errors = vErrors.length;
}
var valid0 = _errs4 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.revision !== undefined){
const _errs5 = errors;
if(!(validate56(data.revision, {instancePath:instancePath+"/revision",parentData:data,parentDataProperty:"revision",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid0 = _errs5 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.entries !== undefined){
const _errs6 = errors;
if(!(validate56(data.entries, {instancePath:instancePath+"/entries",parentData:data,parentDataProperty:"entries",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid0 = _errs6 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.block_entries !== undefined){
const _errs7 = errors;
if(!(validate56(data.block_entries, {instancePath:instancePath+"/block_entries",parentData:data,parentDataProperty:"block_entries",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid0 = _errs7 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.history_ms !== undefined){
const _errs8 = errors;
if(!(validate62(data.history_ms, {instancePath:instancePath+"/history_ms",parentData:data,parentDataProperty:"history_ms",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate62.errors : vErrors.concat(validate62.errors);
errors = vErrors.length;
}
var valid0 = _errs8 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.changed_ms !== undefined){
const _errs9 = errors;
if(!(validate56(data.changed_ms, {instancePath:instancePath+"/changed_ms",parentData:data,parentDataProperty:"changed_ms",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid0 = _errs9 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.last_turn !== undefined){
const _errs10 = errors;
if(!(validate62(data.last_turn, {instancePath:instancePath+"/last_turn",parentData:data,parentDataProperty:"last_turn",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate62.errors : vErrors.concat(validate62.errors);
errors = vErrors.length;
}
var valid0 = _errs10 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.deadline_ms !== undefined){
const _errs11 = errors;
if(!(validate62(data.deadline_ms, {instancePath:instancePath+"/deadline_ms",parentData:data,parentDataProperty:"deadline_ms",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate62.errors : vErrors.concat(validate62.errors);
errors = vErrors.length;
}
var valid0 = _errs11 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.phase !== undefined){
const _errs12 = errors;
if(!(validate317(data.phase, {instancePath:instancePath+"/phase",parentData:data,parentDataProperty:"phase",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate317.errors : vErrors.concat(validate317.errors);
errors = vErrors.length;
}
var valid0 = _errs12 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.retired_at !== undefined){
const _errs13 = errors;
if(!(validate62(data.retired_at, {instancePath:instancePath+"/retired_at",parentData:data,parentDataProperty:"retired_at",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate62.errors : vErrors.concat(validate62.errors);
errors = vErrors.length;
}
var valid0 = _errs13 === errors;
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
else {
validate306.errors = [{}];
return false;
}
}
validate306.errors = vErrors;
return errors === 0;
}
validate306.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate305(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate305.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate306(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate306.errors : vErrors.concat(validate306.errors);
errors = vErrors.length;
}
var _valid0 = _errs1 === errors;
valid0 = valid0 || _valid0;
if(_valid0){
var props0 = true;
}
const _errs2 = errors;
if(data !== null){
const err0 = {};
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
const err1 = {};
if(vErrors === null){
vErrors = [err1];
}
else {
vErrors.push(err1);
}
errors++;
validate305.errors = vErrors;
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
validate305.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate305.evaluated = {"dynamicProps":true,"dynamicItems":false};


function validate304(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate304.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(Array.isArray(data)){
if(data.length > 8){
validate304.errors = [{}];
return false;
}
else {
if(data.length < 8){
validate304.errors = [{}];
return false;
}
else {
var valid0 = true;
const len0 = data.length;
for(let i0=0; i0<len0; i0++){
const _errs1 = errors;
if(!(validate305(data[i0], {instancePath:instancePath+"/" + i0,parentData:data,parentDataProperty:i0,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate305.errors : vErrors.concat(validate305.errors);
errors = vErrors.length;
}
var valid0 = _errs1 === errors;
if(!valid0){
break;
}
}
}
}
}
else {
validate304.errors = [{}];
return false;
}
}
validate304.errors = vErrors;
return errors === 0;
}
validate304.evaluated = {"items":true,"dynamicProps":false,"dynamicItems":false};

const schema97 = {"type":"object","additionalProperties":false,"properties":{"realm":{"$ref":"https://transit.invalid/generated-validator/1"},"pid":{"$ref":"https://transit.invalid/generated-validator/1"},"resource":{"$ref":"https://transit.invalid/generated-validator/1"},"key":{"$ref":"https://transit.invalid/generated-validator/21"},"entry_revision":{"$ref":"https://transit.invalid/generated-validator/1"},"resource_revision":{"$ref":"https://transit.invalid/generated-validator/1"},"position":{"$ref":"https://transit.invalid/generated-validator/1"}},"required":["realm","pid","resource","key","entry_revision","resource_revision","position"]};

function validate331(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate331.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((((((((data.realm === undefined) && (missing0 = "realm")) || ((data.pid === undefined) && (missing0 = "pid"))) || ((data.resource === undefined) && (missing0 = "resource"))) || ((data.key === undefined) && (missing0 = "key"))) || ((data.entry_revision === undefined) && (missing0 = "entry_revision"))) || ((data.resource_revision === undefined) && (missing0 = "resource_revision"))) || ((data.position === undefined) && (missing0 = "position"))){
validate331.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((((((key0 === "realm") || (key0 === "pid")) || (key0 === "resource")) || (key0 === "key")) || (key0 === "entry_revision")) || (key0 === "resource_revision")) || (key0 === "position"))){
validate331.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.realm !== undefined){
const _errs2 = errors;
if(!(validate56(data.realm, {instancePath:instancePath+"/realm",parentData:data,parentDataProperty:"realm",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.pid !== undefined){
const _errs3 = errors;
if(!(validate56(data.pid, {instancePath:instancePath+"/pid",parentData:data,parentDataProperty:"pid",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid0 = _errs3 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.resource !== undefined){
const _errs4 = errors;
if(!(validate56(data.resource, {instancePath:instancePath+"/resource",parentData:data,parentDataProperty:"resource",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid0 = _errs4 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.key !== undefined){
const _errs5 = errors;
if(!(validate232(data.key, {instancePath:instancePath+"/key",parentData:data,parentDataProperty:"key",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate232.errors : vErrors.concat(validate232.errors);
errors = vErrors.length;
}
var valid0 = _errs5 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.entry_revision !== undefined){
const _errs6 = errors;
if(!(validate56(data.entry_revision, {instancePath:instancePath+"/entry_revision",parentData:data,parentDataProperty:"entry_revision",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid0 = _errs6 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.resource_revision !== undefined){
const _errs7 = errors;
if(!(validate56(data.resource_revision, {instancePath:instancePath+"/resource_revision",parentData:data,parentDataProperty:"resource_revision",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid0 = _errs7 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.position !== undefined){
const _errs8 = errors;
if(!(validate56(data.position, {instancePath:instancePath+"/position",parentData:data,parentDataProperty:"position",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid0 = _errs8 === errors;
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
else {
validate331.errors = [{}];
return false;
}
}
validate331.errors = vErrors;
return errors === 0;
}
validate331.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate296(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate296.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if(((data.observation === undefined) && (missing0 = "observation")) || ((data.framework === undefined) && (missing0 = "framework"))){
validate296.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "observation") || (key0 === "framework"))){
validate296.errors = [{}];
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
if((((((((((((data0.version === undefined) && (missing1 = "version")) || ((data0.realm === undefined) && (missing1 = "realm"))) || ((data0.principal_sequence === undefined) && (missing1 = "principal_sequence"))) || ((data0.reader === undefined) && (missing1 = "reader"))) || ((data0.kind === undefined) && (missing1 = "kind"))) || ((data0.cut === undefined) && (missing1 = "cut"))) || ((data0.next === undefined) && (missing1 = "next"))) || ((data0.next_key === undefined) && (missing1 = "next_key"))) || ((data0.resources === undefined) && (missing1 = "resources"))) || ((data0.associations === undefined) && (missing1 = "associations"))) || ((data0.entries === undefined) && (missing1 = "entries"))){
validate296.errors = [{}];
return false;
}
else {
const _errs4 = errors;
for(const key1 in data0){
if(!(func1.call(schema92.properties.observation.properties, key1))){
validate296.errors = [{}];
return false;
break;
}
}
if(_errs4 === errors){
if(data0.version !== undefined){
const _errs5 = errors;
if(!(validate59(data0.version, {instancePath:instancePath+"/observation/version",parentData:data0,parentDataProperty:"version",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate59.errors : vErrors.concat(validate59.errors);
errors = vErrors.length;
}
var valid1 = _errs5 === errors;
}
else {
var valid1 = true;
}
if(valid1){
if(data0.realm !== undefined){
const _errs6 = errors;
if(!(validate56(data0.realm, {instancePath:instancePath+"/observation/realm",parentData:data0,parentDataProperty:"realm",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid1 = _errs6 === errors;
}
else {
var valid1 = true;
}
if(valid1){
if(data0.principal_sequence !== undefined){
const _errs7 = errors;
if(!(validate56(data0.principal_sequence, {instancePath:instancePath+"/observation/principal_sequence",parentData:data0,parentDataProperty:"principal_sequence",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid1 = _errs7 === errors;
}
else {
var valid1 = true;
}
if(valid1){
if(data0.reader !== undefined){
const _errs8 = errors;
if(!(validate166(data0.reader, {instancePath:instancePath+"/observation/reader",parentData:data0,parentDataProperty:"reader",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate166.errors : vErrors.concat(validate166.errors);
errors = vErrors.length;
}
var valid1 = _errs8 === errors;
}
else {
var valid1 = true;
}
if(valid1){
if(data0.kind !== undefined){
let data5 = data0.kind;
const _errs9 = errors;
if(typeof data5 !== "string"){
validate296.errors = [{}];
return false;
}
if(!(((data5 === "resources") || (data5 === "associations")) || (data5 === "entries"))){
validate296.errors = [{}];
return false;
}
var valid1 = _errs9 === errors;
}
else {
var valid1 = true;
}
if(valid1){
if(data0.cut !== undefined){
const _errs11 = errors;
if(!(validate161(data0.cut, {instancePath:instancePath+"/observation/cut",parentData:data0,parentDataProperty:"cut",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate161.errors : vErrors.concat(validate161.errors);
errors = vErrors.length;
}
var valid1 = _errs11 === errors;
}
else {
var valid1 = true;
}
if(valid1){
if(data0.next !== undefined){
const _errs12 = errors;
if(!(validate62(data0.next, {instancePath:instancePath+"/observation/next",parentData:data0,parentDataProperty:"next",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate62.errors : vErrors.concat(validate62.errors);
errors = vErrors.length;
}
var valid1 = _errs12 === errors;
}
else {
var valid1 = true;
}
if(valid1){
if(data0.next_key !== undefined){
const _errs13 = errors;
if(!(validate231(data0.next_key, {instancePath:instancePath+"/observation/next_key",parentData:data0,parentDataProperty:"next_key",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate231.errors : vErrors.concat(validate231.errors);
errors = vErrors.length;
}
var valid1 = _errs13 === errors;
}
else {
var valid1 = true;
}
if(valid1){
if(data0.resources !== undefined){
const _errs14 = errors;
if(!(validate304(data0.resources, {instancePath:instancePath+"/observation/resources",parentData:data0,parentDataProperty:"resources",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate304.errors : vErrors.concat(validate304.errors);
errors = vErrors.length;
}
var valid1 = _errs14 === errors;
}
else {
var valid1 = true;
}
if(valid1){
if(data0.associations !== undefined){
let data10 = data0.associations;
const _errs15 = errors;
if(errors === _errs15){
if(Array.isArray(data10)){
if(data10.length > 8){
validate296.errors = [{}];
return false;
}
else {
if(data10.length < 8){
validate296.errors = [{}];
return false;
}
else {
var valid2 = true;
const len0 = data10.length;
for(let i0=0; i0<len0; i0++){
let data11 = data10[i0];
const _errs17 = errors;
const _errs18 = errors;
let valid3 = false;
const _errs19 = errors;
if(errors === _errs19){
if(data11 && typeof data11 == "object" && !Array.isArray(data11)){
let missing2;
if((((((data11.pid === undefined) && (missing2 = "pid")) || ((data11.name === undefined) && (missing2 = "name"))) || ((data11.resource === undefined) && (missing2 = "resource"))) || ((data11.revision === undefined) && (missing2 = "revision"))) || ((data11.required === undefined) && (missing2 = "required"))){
const err0 = {};
if(vErrors === null){
vErrors = [err0];
}
else {
vErrors.push(err0);
}
errors++;
}
else {
const _errs21 = errors;
for(const key2 in data11){
if(!(((((key2 === "pid") || (key2 === "name")) || (key2 === "resource")) || (key2 === "revision")) || (key2 === "required"))){
const err1 = {};
if(vErrors === null){
vErrors = [err1];
}
else {
vErrors.push(err1);
}
errors++;
break;
}
}
if(_errs21 === errors){
if(data11.pid !== undefined){
const _errs22 = errors;
if(!(validate56(data11.pid, {instancePath:instancePath+"/observation/associations/" + i0+"/pid",parentData:data11,parentDataProperty:"pid",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid4 = _errs22 === errors;
}
else {
var valid4 = true;
}
if(valid4){
if(data11.name !== undefined){
const _errs23 = errors;
if(!(validate232(data11.name, {instancePath:instancePath+"/observation/associations/" + i0+"/name",parentData:data11,parentDataProperty:"name",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate232.errors : vErrors.concat(validate232.errors);
errors = vErrors.length;
}
var valid4 = _errs23 === errors;
}
else {
var valid4 = true;
}
if(valid4){
if(data11.resource !== undefined){
const _errs24 = errors;
if(!(validate56(data11.resource, {instancePath:instancePath+"/observation/associations/" + i0+"/resource",parentData:data11,parentDataProperty:"resource",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid4 = _errs24 === errors;
}
else {
var valid4 = true;
}
if(valid4){
if(data11.revision !== undefined){
const _errs25 = errors;
if(!(validate56(data11.revision, {instancePath:instancePath+"/observation/associations/" + i0+"/revision",parentData:data11,parentDataProperty:"revision",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid4 = _errs25 === errors;
}
else {
var valid4 = true;
}
if(valid4){
if(data11.required !== undefined){
const _errs26 = errors;
if(typeof data11.required !== "boolean"){
const err2 = {};
if(vErrors === null){
vErrors = [err2];
}
else {
vErrors.push(err2);
}
errors++;
}
var valid4 = _errs26 === errors;
}
else {
var valid4 = true;
}
}
}
}
}
}
}
}
else {
const err3 = {};
if(vErrors === null){
vErrors = [err3];
}
else {
vErrors.push(err3);
}
errors++;
}
}
var _valid0 = _errs19 === errors;
valid3 = valid3 || _valid0;
const _errs28 = errors;
if(data11 !== null){
const err4 = {};
if(vErrors === null){
vErrors = [err4];
}
else {
vErrors.push(err4);
}
errors++;
}
var _valid0 = _errs28 === errors;
valid3 = valid3 || _valid0;
if(!valid3){
const err5 = {};
if(vErrors === null){
vErrors = [err5];
}
else {
vErrors.push(err5);
}
errors++;
validate296.errors = vErrors;
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
var valid2 = _errs17 === errors;
if(!valid2){
break;
}
}
}
}
}
else {
validate296.errors = [{}];
return false;
}
}
var valid1 = _errs15 === errors;
}
else {
var valid1 = true;
}
if(valid1){
if(data0.entries !== undefined){
let data17 = data0.entries;
const _errs30 = errors;
if(errors === _errs30){
if(Array.isArray(data17)){
if(data17.length > 8){
validate296.errors = [{}];
return false;
}
else {
if(data17.length < 8){
validate296.errors = [{}];
return false;
}
else {
var valid5 = true;
const len1 = data17.length;
for(let i1=0; i1<len1; i1++){
let data18 = data17[i1];
const _errs32 = errors;
const _errs33 = errors;
let valid6 = false;
const _errs34 = errors;
if(errors === _errs34){
if(data18 && typeof data18 == "object" && !Array.isArray(data18)){
let missing3;
if((((data18.key === undefined) && (missing3 = "key")) || ((data18.value === undefined) && (missing3 = "value"))) || ((data18.revision === undefined) && (missing3 = "revision"))){
const err6 = {};
if(vErrors === null){
vErrors = [err6];
}
else {
vErrors.push(err6);
}
errors++;
}
else {
const _errs36 = errors;
for(const key3 in data18){
if(!(((key3 === "key") || (key3 === "value")) || (key3 === "revision"))){
const err7 = {};
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
if(_errs36 === errors){
if(data18.key !== undefined){
const _errs37 = errors;
if(!(validate232(data18.key, {instancePath:instancePath+"/observation/entries/" + i1+"/key",parentData:data18,parentDataProperty:"key",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate232.errors : vErrors.concat(validate232.errors);
errors = vErrors.length;
}
var valid7 = _errs37 === errors;
}
else {
var valid7 = true;
}
if(valid7){
if(data18.value !== undefined){
const _errs38 = errors;
if(!(validate232(data18.value, {instancePath:instancePath+"/observation/entries/" + i1+"/value",parentData:data18,parentDataProperty:"value",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate232.errors : vErrors.concat(validate232.errors);
errors = vErrors.length;
}
var valid7 = _errs38 === errors;
}
else {
var valid7 = true;
}
if(valid7){
if(data18.revision !== undefined){
const _errs39 = errors;
if(!(validate56(data18.revision, {instancePath:instancePath+"/observation/entries/" + i1+"/revision",parentData:data18,parentDataProperty:"revision",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid7 = _errs39 === errors;
}
else {
var valid7 = true;
}
}
}
}
}
}
else {
const err8 = {};
if(vErrors === null){
vErrors = [err8];
}
else {
vErrors.push(err8);
}
errors++;
}
}
var _valid1 = _errs34 === errors;
valid6 = valid6 || _valid1;
const _errs40 = errors;
if(data18 !== null){
const err9 = {};
if(vErrors === null){
vErrors = [err9];
}
else {
vErrors.push(err9);
}
errors++;
}
var _valid1 = _errs40 === errors;
valid6 = valid6 || _valid1;
if(!valid6){
const err10 = {};
if(vErrors === null){
vErrors = [err10];
}
else {
vErrors.push(err10);
}
errors++;
validate296.errors = vErrors;
return false;
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
var valid5 = _errs32 === errors;
if(!valid5){
break;
}
}
}
}
}
else {
validate296.errors = [{}];
return false;
}
}
var valid1 = _errs30 === errors;
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
else {
validate296.errors = [{}];
return false;
}
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.framework !== undefined){
let data22 = data.framework;
const _errs42 = errors;
if(errors === _errs42){
if(Array.isArray(data22)){
if(data22.length > 8){
validate296.errors = [{}];
return false;
}
else {
if(data22.length < 8){
validate296.errors = [{}];
return false;
}
else {
var valid8 = true;
const len2 = data22.length;
for(let i2=0; i2<len2; i2++){
let data23 = data22[i2];
const _errs44 = errors;
const _errs45 = errors;
let valid9 = false;
const _errs46 = errors;
if(errors === _errs46){
if(data23 && typeof data23 == "object" && !Array.isArray(data23)){
let missing4;
if((((data23.version === undefined) && (missing4 = "version")) || ((data23.source === undefined) && (missing4 = "source"))) || ((data23.declaration === undefined) && (missing4 = "declaration"))){
const err11 = {};
if(vErrors === null){
vErrors = [err11];
}
else {
vErrors.push(err11);
}
errors++;
}
else {
const _errs48 = errors;
for(const key4 in data23){
if(!(((key4 === "version") || (key4 === "source")) || (key4 === "declaration"))){
const err12 = {};
if(vErrors === null){
vErrors = [err12];
}
else {
vErrors.push(err12);
}
errors++;
break;
}
}
if(_errs48 === errors){
if(data23.version !== undefined){
const _errs49 = errors;
if(!(validate134(data23.version, {instancePath:instancePath+"/framework/" + i2+"/version",parentData:data23,parentDataProperty:"version",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate134.errors : vErrors.concat(validate134.errors);
errors = vErrors.length;
}
var valid10 = _errs49 === errors;
}
else {
var valid10 = true;
}
if(valid10){
if(data23.source !== undefined){
const _errs50 = errors;
if(!(validate331(data23.source, {instancePath:instancePath+"/framework/" + i2+"/source",parentData:data23,parentDataProperty:"source",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate331.errors : vErrors.concat(validate331.errors);
errors = vErrors.length;
}
var valid10 = _errs50 === errors;
}
else {
var valid10 = true;
}
if(valid10){
if(data23.declaration !== undefined){
let data26 = data23.declaration;
const _errs51 = errors;
const _errs52 = errors;
let valid11 = false;
let passing0 = null;
const _errs53 = errors;
if(errors === _errs53){
if(data26 && typeof data26 == "object" && !Array.isArray(data26)){
let missing5;
if((data26.behavior === undefined) && (missing5 = "behavior")){
const err13 = {};
if(vErrors === null){
vErrors = [err13];
}
else {
vErrors.push(err13);
}
errors++;
}
else {
const _errs55 = errors;
for(const key5 in data26){
if(!(key5 === "behavior")){
const err14 = {};
if(vErrors === null){
vErrors = [err14];
}
else {
vErrors.push(err14);
}
errors++;
break;
}
}
if(_errs55 === errors){
if(data26.behavior !== undefined){
let data27 = data26.behavior;
if(typeof data27 !== "string"){
const err15 = {};
if(vErrors === null){
vErrors = [err15];
}
else {
vErrors.push(err15);
}
errors++;
}
if(!(data27 === "genserver")){
const err16 = {};
if(vErrors === null){
vErrors = [err16];
}
else {
vErrors.push(err16);
}
errors++;
}
}
}
}
}
else {
const err17 = {};
if(vErrors === null){
vErrors = [err17];
}
else {
vErrors.push(err17);
}
errors++;
}
}
var _valid3 = _errs53 === errors;
if(_valid3){
valid11 = true;
passing0 = 0;
var props2 = true;
}
const _errs58 = errors;
if(errors === _errs58){
if(data26 && typeof data26 == "object" && !Array.isArray(data26)){
let missing6;
if((data26.table === undefined) && (missing6 = "table")){
const err18 = {};
if(vErrors === null){
vErrors = [err18];
}
else {
vErrors.push(err18);
}
errors++;
}
else {
const _errs60 = errors;
for(const key6 in data26){
if(!(key6 === "table")){
const err19 = {};
if(vErrors === null){
vErrors = [err19];
}
else {
vErrors.push(err19);
}
errors++;
break;
}
}
if(_errs60 === errors){
if(data26.table !== undefined){
let data28 = data26.table;
const _errs61 = errors;
if(errors === _errs61){
if(data28 && typeof data28 == "object" && !Array.isArray(data28)){
let missing7;
if(((((((data28.object === undefined) && (missing7 = "object")) || ((data28.revision === undefined) && (missing7 = "revision"))) || ((data28.rows === undefined) && (missing7 = "rows"))) || ((data28.retired === undefined) && (missing7 = "retired"))) || ((data28.pending === undefined) && (missing7 = "pending"))) || ((data28.schema === undefined) && (missing7 = "schema"))){
const err20 = {};
if(vErrors === null){
vErrors = [err20];
}
else {
vErrors.push(err20);
}
errors++;
}
else {
const _errs63 = errors;
for(const key7 in data28){
if(!((((((key7 === "object") || (key7 === "revision")) || (key7 === "rows")) || (key7 === "retired")) || (key7 === "pending")) || (key7 === "schema"))){
const err21 = {};
if(vErrors === null){
vErrors = [err21];
}
else {
vErrors.push(err21);
}
errors++;
break;
}
}
if(_errs63 === errors){
if(data28.object !== undefined){
const _errs64 = errors;
if(!(validate232(data28.object, {instancePath:instancePath+"/framework/" + i2+"/declaration/table/object",parentData:data28,parentDataProperty:"object",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate232.errors : vErrors.concat(validate232.errors);
errors = vErrors.length;
}
var valid14 = _errs64 === errors;
}
else {
var valid14 = true;
}
if(valid14){
if(data28.revision !== undefined){
const _errs65 = errors;
if(!(validate232(data28.revision, {instancePath:instancePath+"/framework/" + i2+"/declaration/table/revision",parentData:data28,parentDataProperty:"revision",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate232.errors : vErrors.concat(validate232.errors);
errors = vErrors.length;
}
var valid14 = _errs65 === errors;
}
else {
var valid14 = true;
}
if(valid14){
if(data28.rows !== undefined){
const _errs66 = errors;
if(!(validate232(data28.rows, {instancePath:instancePath+"/framework/" + i2+"/declaration/table/rows",parentData:data28,parentDataProperty:"rows",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate232.errors : vErrors.concat(validate232.errors);
errors = vErrors.length;
}
var valid14 = _errs66 === errors;
}
else {
var valid14 = true;
}
if(valid14){
if(data28.retired !== undefined){
const _errs67 = errors;
if(typeof data28.retired !== "boolean"){
const err22 = {};
if(vErrors === null){
vErrors = [err22];
}
else {
vErrors.push(err22);
}
errors++;
}
var valid14 = _errs67 === errors;
}
else {
var valid14 = true;
}
if(valid14){
if(data28.pending !== undefined){
const _errs69 = errors;
if(!(validate231(data28.pending, {instancePath:instancePath+"/framework/" + i2+"/declaration/table/pending",parentData:data28,parentDataProperty:"pending",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate231.errors : vErrors.concat(validate231.errors);
errors = vErrors.length;
}
var valid14 = _errs69 === errors;
}
else {
var valid14 = true;
}
if(valid14){
if(data28.schema !== undefined){
let data34 = data28.schema;
const _errs70 = errors;
if(errors === _errs70){
if(data34 && typeof data34 == "object" && !Array.isArray(data34)){
let missing8;
if((((data34.record === undefined) && (missing8 = "record")) || ((data34.bytes === undefined) && (missing8 = "bytes"))) || ((data34.digest === undefined) && (missing8 = "digest"))){
const err23 = {};
if(vErrors === null){
vErrors = [err23];
}
else {
vErrors.push(err23);
}
errors++;
}
else {
const _errs72 = errors;
for(const key8 in data34){
if(!(((key8 === "record") || (key8 === "bytes")) || (key8 === "digest"))){
const err24 = {};
if(vErrors === null){
vErrors = [err24];
}
else {
vErrors.push(err24);
}
errors++;
break;
}
}
if(_errs72 === errors){
if(data34.record !== undefined){
const _errs73 = errors;
if(!(validate232(data34.record, {instancePath:instancePath+"/framework/" + i2+"/declaration/table/schema/record",parentData:data34,parentDataProperty:"record",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate232.errors : vErrors.concat(validate232.errors);
errors = vErrors.length;
}
var valid15 = _errs73 === errors;
}
else {
var valid15 = true;
}
if(valid15){
if(data34.bytes !== undefined){
const _errs74 = errors;
if(!(validate59(data34.bytes, {instancePath:instancePath+"/framework/" + i2+"/declaration/table/schema/bytes",parentData:data34,parentDataProperty:"bytes",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate59.errors : vErrors.concat(validate59.errors);
errors = vErrors.length;
}
var valid15 = _errs74 === errors;
}
else {
var valid15 = true;
}
if(valid15){
if(data34.digest !== undefined){
const _errs75 = errors;
if(!(validate133(data34.digest, {instancePath:instancePath+"/framework/" + i2+"/declaration/table/schema/digest",parentData:data34,parentDataProperty:"digest",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate133.errors : vErrors.concat(validate133.errors);
errors = vErrors.length;
}
var valid15 = _errs75 === errors;
}
else {
var valid15 = true;
}
}
}
}
}
}
else {
const err25 = {};
if(vErrors === null){
vErrors = [err25];
}
else {
vErrors.push(err25);
}
errors++;
}
}
var valid14 = _errs70 === errors;
}
else {
var valid14 = true;
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
const err26 = {};
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
}
}
else {
const err27 = {};
if(vErrors === null){
vErrors = [err27];
}
else {
vErrors.push(err27);
}
errors++;
}
}
var _valid3 = _errs58 === errors;
if(_valid3 && valid11){
valid11 = false;
passing0 = [passing0, 1];
}
else {
if(_valid3){
valid11 = true;
passing0 = 1;
if(props2 !== true){
props2 = true;
}
}
const _errs76 = errors;
if(errors === _errs76){
if(data26 && typeof data26 == "object" && !Array.isArray(data26)){
let missing9;
if((data26.registry_scope === undefined) && (missing9 = "registry_scope")){
const err28 = {};
if(vErrors === null){
vErrors = [err28];
}
else {
vErrors.push(err28);
}
errors++;
}
else {
const _errs78 = errors;
for(const key9 in data26){
if(!(key9 === "registry_scope")){
const err29 = {};
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
if(_errs78 === errors){
if(data26.registry_scope !== undefined){
let data38 = data26.registry_scope;
const _errs79 = errors;
if(errors === _errs79){
if(data38 && typeof data38 == "object" && !Array.isArray(data38)){
let missing10;
if((data38.id === undefined) && (missing10 = "id")){
const err30 = {};
if(vErrors === null){
vErrors = [err30];
}
else {
vErrors.push(err30);
}
errors++;
}
else {
const _errs81 = errors;
for(const key10 in data38){
if(!(key10 === "id")){
const err31 = {};
if(vErrors === null){
vErrors = [err31];
}
else {
vErrors.push(err31);
}
errors++;
break;
}
}
if(_errs81 === errors){
if(data38.id !== undefined){
if(!(validate59(data38.id, {instancePath:instancePath+"/framework/" + i2+"/declaration/registry_scope/id",parentData:data38,parentDataProperty:"id",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate59.errors : vErrors.concat(validate59.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err32 = {};
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
}
}
}
else {
const err33 = {};
if(vErrors === null){
vErrors = [err33];
}
else {
vErrors.push(err33);
}
errors++;
}
}
var _valid3 = _errs76 === errors;
if(_valid3 && valid11){
valid11 = false;
passing0 = [passing0, 2];
}
else {
if(_valid3){
valid11 = true;
passing0 = 2;
if(props2 !== true){
props2 = true;
}
}
const _errs83 = errors;
if(errors === _errs83){
if(data26 && typeof data26 == "object" && !Array.isArray(data26)){
let missing11;
if((data26.registry_binding === undefined) && (missing11 = "registry_binding")){
const err34 = {};
if(vErrors === null){
vErrors = [err34];
}
else {
vErrors.push(err34);
}
errors++;
}
else {
const _errs85 = errors;
for(const key11 in data26){
if(!(key11 === "registry_binding")){
const err35 = {};
if(vErrors === null){
vErrors = [err35];
}
else {
vErrors.push(err35);
}
errors++;
break;
}
}
if(_errs85 === errors){
if(data26.registry_binding !== undefined){
let data40 = data26.registry_binding;
const _errs86 = errors;
if(errors === _errs86){
if(data40 && typeof data40 == "object" && !Array.isArray(data40)){
let missing12;
if(((((data40.scope === undefined) && (missing12 = "scope")) || ((data40.name === undefined) && (missing12 = "name"))) || ((data40.revision === undefined) && (missing12 = "revision"))) || ((data40.destination === undefined) && (missing12 = "destination"))){
const err36 = {};
if(vErrors === null){
vErrors = [err36];
}
else {
vErrors.push(err36);
}
errors++;
}
else {
const _errs88 = errors;
for(const key12 in data40){
if(!((((key12 === "scope") || (key12 === "name")) || (key12 === "revision")) || (key12 === "destination"))){
const err37 = {};
if(vErrors === null){
vErrors = [err37];
}
else {
vErrors.push(err37);
}
errors++;
break;
}
}
if(_errs88 === errors){
if(data40.scope !== undefined){
const _errs89 = errors;
if(!(validate59(data40.scope, {instancePath:instancePath+"/framework/" + i2+"/declaration/registry_binding/scope",parentData:data40,parentDataProperty:"scope",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate59.errors : vErrors.concat(validate59.errors);
errors = vErrors.length;
}
var valid19 = _errs89 === errors;
}
else {
var valid19 = true;
}
if(valid19){
if(data40.name !== undefined){
const _errs90 = errors;
if(!(validate232(data40.name, {instancePath:instancePath+"/framework/" + i2+"/declaration/registry_binding/name",parentData:data40,parentDataProperty:"name",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate232.errors : vErrors.concat(validate232.errors);
errors = vErrors.length;
}
var valid19 = _errs90 === errors;
}
else {
var valid19 = true;
}
if(valid19){
if(data40.revision !== undefined){
const _errs91 = errors;
if(!(validate56(data40.revision, {instancePath:instancePath+"/framework/" + i2+"/declaration/registry_binding/revision",parentData:data40,parentDataProperty:"revision",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid19 = _errs91 === errors;
}
else {
var valid19 = true;
}
if(valid19){
if(data40.destination !== undefined){
const _errs92 = errors;
if(!(validate62(data40.destination, {instancePath:instancePath+"/framework/" + i2+"/declaration/registry_binding/destination",parentData:data40,parentDataProperty:"destination",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate62.errors : vErrors.concat(validate62.errors);
errors = vErrors.length;
}
var valid19 = _errs92 === errors;
}
else {
var valid19 = true;
}
}
}
}
}
}
}
else {
const err38 = {};
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
}
}
else {
const err39 = {};
if(vErrors === null){
vErrors = [err39];
}
else {
vErrors.push(err39);
}
errors++;
}
}
var _valid3 = _errs83 === errors;
if(_valid3 && valid11){
valid11 = false;
passing0 = [passing0, 3];
}
else {
if(_valid3){
valid11 = true;
passing0 = 3;
if(props2 !== true){
props2 = true;
}
}
const _errs93 = errors;
if(errors === _errs93){
if(data26 && typeof data26 == "object" && !Array.isArray(data26)){
let missing13;
if((data26.child === undefined) && (missing13 = "child")){
const err40 = {};
if(vErrors === null){
vErrors = [err40];
}
else {
vErrors.push(err40);
}
errors++;
}
else {
const _errs95 = errors;
for(const key13 in data26){
if(!(key13 === "child")){
const err41 = {};
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
if(_errs95 === errors){
if(data26.child !== undefined){
let data45 = data26.child;
const _errs96 = errors;
if(errors === _errs96){
if(data45 && typeof data45 == "object" && !Array.isArray(data45)){
let missing14;
if((((((((data45.pid === undefined) && (missing14 = "pid")) || ((data45.generation === undefined) && (missing14 = "generation"))) || ((data45.phase === undefined) && (missing14 = "phase"))) || ((data45.attempts === undefined) && (missing14 = "attempts"))) || ((data45.limit === undefined) && (missing14 = "limit"))) || ((data45.retry_at_ms === undefined) && (missing14 = "retry_at_ms"))) || ((data45.successor === undefined) && (missing14 = "successor"))){
const err42 = {};
if(vErrors === null){
vErrors = [err42];
}
else {
vErrors.push(err42);
}
errors++;
}
else {
const _errs98 = errors;
for(const key14 in data45){
if(!(((((((key14 === "pid") || (key14 === "generation")) || (key14 === "phase")) || (key14 === "attempts")) || (key14 === "limit")) || (key14 === "retry_at_ms")) || (key14 === "successor"))){
const err43 = {};
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
if(_errs98 === errors){
if(data45.pid !== undefined){
const _errs99 = errors;
if(!(validate56(data45.pid, {instancePath:instancePath+"/framework/" + i2+"/declaration/child/pid",parentData:data45,parentDataProperty:"pid",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid21 = _errs99 === errors;
}
else {
var valid21 = true;
}
if(valid21){
if(data45.generation !== undefined){
const _errs100 = errors;
if(!(validate56(data45.generation, {instancePath:instancePath+"/framework/" + i2+"/declaration/child/generation",parentData:data45,parentDataProperty:"generation",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid21 = _errs100 === errors;
}
else {
var valid21 = true;
}
if(valid21){
if(data45.phase !== undefined){
let data48 = data45.phase;
const _errs101 = errors;
if(typeof data48 !== "string"){
const err44 = {};
if(vErrors === null){
vErrors = [err44];
}
else {
vErrors.push(err44);
}
errors++;
}
if(!((((((((data48 === "watching") || (data48 === "retry_wait")) || (data48 === "retry_requested")) || (data48 === "exhausted")) || (data48 === "retired")) || (data48 === "suspended")) || (data48 === "placement_unavailable")) || (data48 === "initializing"))){
const err45 = {};
if(vErrors === null){
vErrors = [err45];
}
else {
vErrors.push(err45);
}
errors++;
}
var valid21 = _errs101 === errors;
}
else {
var valid21 = true;
}
if(valid21){
if(data45.attempts !== undefined){
const _errs103 = errors;
if(!(validate134(data45.attempts, {instancePath:instancePath+"/framework/" + i2+"/declaration/child/attempts",parentData:data45,parentDataProperty:"attempts",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate134.errors : vErrors.concat(validate134.errors);
errors = vErrors.length;
}
var valid21 = _errs103 === errors;
}
else {
var valid21 = true;
}
if(valid21){
if(data45.limit !== undefined){
const _errs104 = errors;
if(!(validate134(data45.limit, {instancePath:instancePath+"/framework/" + i2+"/declaration/child/limit",parentData:data45,parentDataProperty:"limit",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate134.errors : vErrors.concat(validate134.errors);
errors = vErrors.length;
}
var valid21 = _errs104 === errors;
}
else {
var valid21 = true;
}
if(valid21){
if(data45.retry_at_ms !== undefined){
const _errs105 = errors;
if(!(validate56(data45.retry_at_ms, {instancePath:instancePath+"/framework/" + i2+"/declaration/child/retry_at_ms",parentData:data45,parentDataProperty:"retry_at_ms",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid21 = _errs105 === errors;
}
else {
var valid21 = true;
}
if(valid21){
if(data45.successor !== undefined){
const _errs106 = errors;
if(!(validate62(data45.successor, {instancePath:instancePath+"/framework/" + i2+"/declaration/child/successor",parentData:data45,parentDataProperty:"successor",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate62.errors : vErrors.concat(validate62.errors);
errors = vErrors.length;
}
var valid21 = _errs106 === errors;
}
else {
var valid21 = true;
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
const err46 = {};
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
}
}
else {
const err47 = {};
if(vErrors === null){
vErrors = [err47];
}
else {
vErrors.push(err47);
}
errors++;
}
}
var _valid3 = _errs93 === errors;
if(_valid3 && valid11){
valid11 = false;
passing0 = [passing0, 4];
}
else {
if(_valid3){
valid11 = true;
passing0 = 4;
if(props2 !== true){
props2 = true;
}
}
const _errs107 = errors;
if(errors === _errs107){
if(data26 && typeof data26 == "object" && !Array.isArray(data26)){
let missing15;
if((data26.wait === undefined) && (missing15 = "wait")){
const err48 = {};
if(vErrors === null){
vErrors = [err48];
}
else {
vErrors.push(err48);
}
errors++;
}
else {
const _errs109 = errors;
for(const key15 in data26){
if(!(key15 === "wait")){
const err49 = {};
if(vErrors === null){
vErrors = [err49];
}
else {
vErrors.push(err49);
}
errors++;
break;
}
}
if(_errs109 === errors){
if(data26.wait !== undefined){
let data53 = data26.wait;
const _errs110 = errors;
if(errors === _errs110){
if(data53 && typeof data53 == "object" && !Array.isArray(data53)){
let missing16;
if(((((((data53.correlation === undefined) && (missing16 = "correlation")) || ((data53.target === undefined) && (missing16 = "target"))) || ((data53.phase === undefined) && (missing16 = "phase"))) || ((data53.deadline_ms === undefined) && (missing16 = "deadline_ms"))) || ((data53.observer === undefined) && (missing16 = "observer"))) || ((data53.resolution_input === undefined) && (missing16 = "resolution_input"))){
const err50 = {};
if(vErrors === null){
vErrors = [err50];
}
else {
vErrors.push(err50);
}
errors++;
}
else {
const _errs112 = errors;
for(const key16 in data53){
if(!((((((key16 === "correlation") || (key16 === "target")) || (key16 === "phase")) || (key16 === "deadline_ms")) || (key16 === "observer")) || (key16 === "resolution_input"))){
const err51 = {};
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
if(_errs112 === errors){
if(data53.correlation !== undefined){
const _errs113 = errors;
if(!(validate232(data53.correlation, {instancePath:instancePath+"/framework/" + i2+"/declaration/wait/correlation",parentData:data53,parentDataProperty:"correlation",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate232.errors : vErrors.concat(validate232.errors);
errors = vErrors.length;
}
var valid23 = _errs113 === errors;
}
else {
var valid23 = true;
}
if(valid23){
if(data53.target !== undefined){
const _errs114 = errors;
if(!(validate56(data53.target, {instancePath:instancePath+"/framework/" + i2+"/declaration/wait/target",parentData:data53,parentDataProperty:"target",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid23 = _errs114 === errors;
}
else {
var valid23 = true;
}
if(valid23){
if(data53.phase !== undefined){
let data56 = data53.phase;
const _errs115 = errors;
if(typeof data56 !== "string"){
const err52 = {};
if(vErrors === null){
vErrors = [err52];
}
else {
vErrors.push(err52);
}
errors++;
}
if(!((((data56 === "waiting") || (data56 === "replied")) || (data56 === "timed_out")) || (data56 === "cancelled"))){
const err53 = {};
if(vErrors === null){
vErrors = [err53];
}
else {
vErrors.push(err53);
}
errors++;
}
var valid23 = _errs115 === errors;
}
else {
var valid23 = true;
}
if(valid23){
if(data53.deadline_ms !== undefined){
const _errs117 = errors;
if(!(validate62(data53.deadline_ms, {instancePath:instancePath+"/framework/" + i2+"/declaration/wait/deadline_ms",parentData:data53,parentDataProperty:"deadline_ms",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate62.errors : vErrors.concat(validate62.errors);
errors = vErrors.length;
}
var valid23 = _errs117 === errors;
}
else {
var valid23 = true;
}
if(valid23){
if(data53.observer !== undefined){
const _errs118 = errors;
if(!(validate62(data53.observer, {instancePath:instancePath+"/framework/" + i2+"/declaration/wait/observer",parentData:data53,parentDataProperty:"observer",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate62.errors : vErrors.concat(validate62.errors);
errors = vErrors.length;
}
var valid23 = _errs118 === errors;
}
else {
var valid23 = true;
}
if(valid23){
if(data53.resolution_input !== undefined){
const _errs119 = errors;
if(!(validate56(data53.resolution_input, {instancePath:instancePath+"/framework/" + i2+"/declaration/wait/resolution_input",parentData:data53,parentDataProperty:"resolution_input",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid23 = _errs119 === errors;
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
else {
const err54 = {};
if(vErrors === null){
vErrors = [err54];
}
else {
vErrors.push(err54);
}
errors++;
}
}
}
}
}
}
else {
const err55 = {};
if(vErrors === null){
vErrors = [err55];
}
else {
vErrors.push(err55);
}
errors++;
}
}
var _valid3 = _errs107 === errors;
if(_valid3 && valid11){
valid11 = false;
passing0 = [passing0, 5];
}
else {
if(_valid3){
valid11 = true;
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
if(!valid11){
const err56 = {};
if(vErrors === null){
vErrors = [err56];
}
else {
vErrors.push(err56);
}
errors++;
}
else {
errors = _errs52;
if(vErrors !== null){
if(_errs52){
vErrors.length = _errs52;
}
else {
vErrors = null;
}
}
}
var valid10 = _errs51 === errors;
}
else {
var valid10 = true;
}
}
}
}
}
}
else {
const err57 = {};
if(vErrors === null){
vErrors = [err57];
}
else {
vErrors.push(err57);
}
errors++;
}
}
var _valid2 = _errs46 === errors;
valid9 = valid9 || _valid2;
const _errs120 = errors;
if(data23 !== null){
const err58 = {};
if(vErrors === null){
vErrors = [err58];
}
else {
vErrors.push(err58);
}
errors++;
}
var _valid2 = _errs120 === errors;
valid9 = valid9 || _valid2;
if(!valid9){
const err59 = {};
if(vErrors === null){
vErrors = [err59];
}
else {
vErrors.push(err59);
}
errors++;
validate296.errors = vErrors;
return false;
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
var valid8 = _errs44 === errors;
if(!valid8){
break;
}
}
}
}
}
else {
validate296.errors = [{}];
return false;
}
}
var valid0 = _errs42 === errors;
}
else {
var valid0 = true;
}
}
}
}
}
else {
validate296.errors = [{}];
return false;
}
}
validate296.errors = vErrors;
return errors === 0;
}
validate296.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};
