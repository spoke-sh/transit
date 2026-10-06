// Generated; no runtime code generation or eval.
import lengthModule from "ajv/dist/runtime/ucs2length.js";
const ucs2length = lengthModule.default ?? lengthModule;
"use strict";
export const Response = validate52;
const schema19 = {"type":"object","additionalProperties":false,"properties":{"observation":{"type":"object","additionalProperties":false,"properties":{"version":{"$ref":"https://transit.invalid/generated-validator/0"},"realm":{"$ref":"https://transit.invalid/generated-validator/1"},"resource":{"type":"string","enum":["processes","process","mailbox","outbox","effects","payloads","history"]},"pid":{"$ref":"https://transit.invalid/generated-validator/2"},"cut":{"$ref":"https://transit.invalid/generated-validator/3"},"reader":{"$ref":"https://transit.invalid/generated-validator/5"},"next":{"$ref":"https://transit.invalid/generated-validator/2"},"complete":{"type":"boolean"},"history":{"type":"string","enum":["retained","prefix_reclaimed"]},"last_collection":{"$ref":"https://transit.invalid/generated-validator/2"},"scanned":{"$ref":"https://transit.invalid/generated-validator/4"},"processes":{"$ref":"https://transit.invalid/generated-validator/28"},"events":{"type":"array","minItems":8,"maxItems":8,"items":{"anyOf":[{"type":"object","additionalProperties":false,"properties":{"position":{"$ref":"https://transit.invalid/generated-validator/1"},"pid":{"$ref":"https://transit.invalid/generated-validator/1"},"kind":{"type":"string","enum":["grant","revoke","spawn","own","retry","send","begin_turn","turn","terminate","expire","create_resource","grant_resource","associate","open_view","close_view","retire_resource","expire_resource","reclaim_resource","deliver","dispatch","observe","close_effect","cancel_effect","checkpoint","turn_with_versions","rotate_worker","create_principal","runtime_intent","runtime_observe","runtime_upgrade","activate","create","initialize","suspend","resume","expire_suspension","declare_payload","payload_ready","retire_payload","payload_deleted","collect"]},"policy_revision":{"$ref":"https://transit.invalid/generated-validator/1"},"input":{"$ref":"https://transit.invalid/generated-validator/2"},"effect":{"$ref":"https://transit.invalid/generated-validator/2"},"output":{"$ref":"https://transit.invalid/generated-validator/2"},"value":{"$ref":"https://transit.invalid/generated-validator/22"},"failed":{"type":"boolean"},"generation":{"$ref":"https://transit.invalid/generated-validator/2"},"mailbox_status":{"anyOf":[{"type":"string","enum":["pending","consumed","cancelled"]},{"type":"null"}]},"admitted":{"type":"boolean"},"unix_ms":{"$ref":"https://transit.invalid/generated-validator/2"},"clock_error_ms":{"anyOf":[{"$ref":"https://transit.invalid/generated-validator/0"},{"type":"null"}]}},"required":["position","pid","kind","policy_revision","input","effect","output","value","failed","generation","mailbox_status","admitted","unix_ms","clock_error_ms"]},{"type":"null"}]}},"outbox":{"type":"array","minItems":8,"maxItems":8,"items":{"anyOf":[{"type":"object","additionalProperties":false,"properties":{"id":{"$ref":"https://transit.invalid/generated-validator/1"},"source":{"$ref":"https://transit.invalid/generated-validator/1"},"turn":{"$ref":"https://transit.invalid/generated-validator/1"},"index":{"$ref":"https://transit.invalid/generated-validator/9"},"destination":{"$ref":"https://transit.invalid/generated-validator/1"},"value":{"$ref":"https://transit.invalid/generated-validator/21"},"phase":{"type":"string","enum":["pending","delivered","denied","expired","retired","cancelled"]},"resolved_at":{"$ref":"https://transit.invalid/generated-validator/2"},"courier":{"$ref":"https://transit.invalid/generated-validator/2"},"policy_revision":{"$ref":"https://transit.invalid/generated-validator/2"}},"required":["id","source","turn","index","destination","value","phase","resolved_at","courier","policy_revision"]},{"type":"null"}]}},"effects":{"type":"array","minItems":8,"maxItems":8,"items":{"anyOf":[{"type":"object","additionalProperties":false,"properties":{"id":{"$ref":"https://transit.invalid/generated-validator/1"},"pid":{"$ref":"https://transit.invalid/generated-validator/1"},"payload":{"$ref":"https://transit.invalid/generated-validator/21"},"phase":{"type":"string","enum":["pending","authorized","unknown","observed","cancelled","closed_unknown"]},"attempt":{"$ref":"https://transit.invalid/generated-validator/2"},"executor":{"$ref":"https://transit.invalid/generated-validator/2"},"authorization_policy":{"$ref":"https://transit.invalid/generated-validator/2"},"last_observation":{"anyOf":[{"type":"object","additionalProperties":false,"properties":{"input":{"$ref":"https://transit.invalid/generated-validator/1"},"policy_revision":{"$ref":"https://transit.invalid/generated-validator/1"}},"required":["input","policy_revision"]},{"type":"null"}]},"closure":{"anyOf":[{"type":"object","additionalProperties":false,"properties":{"reason":{"type":"string","enum":["observed","observation_budget","abandoned","deadline","unattempted_cancel"]},"principal":{"$ref":"https://transit.invalid/generated-validator/1"},"policy_revision":{"$ref":"https://transit.invalid/generated-validator/1"},"clock_lower_ms":{"$ref":"https://transit.invalid/generated-validator/2"}},"required":["reason","principal","policy_revision","clock_lower_ms"]},{"type":"null"}]},"result":{"$ref":"https://transit.invalid/generated-validator/22"},"closed_at":{"$ref":"https://transit.invalid/generated-validator/2"},"reconcile_before_ms":{"$ref":"https://transit.invalid/generated-validator/2"},"max_observations":{"$ref":"https://transit.invalid/generated-validator/4"},"observations":{"$ref":"https://transit.invalid/generated-validator/4"}},"required":["id","pid","payload","phase","attempt","executor","authorization_policy","last_observation","closure","result","closed_at","reconcile_before_ms","max_observations","observations"]},{"type":"null"}]}},"payloads":{"type":"array","minItems":8,"maxItems":8,"items":{"anyOf":[{"type":"object","additionalProperties":false,"properties":{"id":{"$ref":"https://transit.invalid/generated-validator/1"},"pid":{"$ref":"https://transit.invalid/generated-validator/1"},"publisher":{"$ref":"https://transit.invalid/generated-validator/1"},"sha256":{"$ref":"https://transit.invalid/generated-validator/11"},"bytes":{"$ref":"https://transit.invalid/generated-validator/0"},"allow_delete":{"type":"boolean"},"phase":{"type":"string","enum":["creating","ready","retiring","deleted"]},"retired_at":{"$ref":"https://transit.invalid/generated-validator/2"},"deleted_at":{"$ref":"https://transit.invalid/generated-validator/2"}},"required":["id","pid","publisher","sha256","bytes","allow_delete","phase","retired_at","deleted_at"]},{"type":"null"}]}}},"required":["version","realm","resource","pid","cut","reader","next","complete","history","last_collection","scanned","processes","events","outbox","effects","payloads"]},"edges":{"type":"array","minItems":16,"maxItems":16,"items":{"anyOf":[{"type":"object","additionalProperties":false,"properties":{"from":{"$ref":"https://transit.invalid/generated-validator/30"},"to":{"$ref":"https://transit.invalid/generated-validator/30"},"relation":{"type":"string","enum":["input_to_turn","turn_to_effect","turn_to_output","output_to_admission","effect_to_observation"]},"from_coverage":{"$ref":"https://transit.invalid/generated-validator/31"},"to_coverage":{"$ref":"https://transit.invalid/generated-validator/31"}},"required":["from","to","relation","from_coverage","to_coverage"]},{"type":"null"}]}},"effect_diagnostics":{"type":"array","minItems":8,"maxItems":8,"items":{"$ref":"https://transit.invalid/generated-validator/67"}}},"required":["observation","edges","effect_diagnostics"]};
const func1 = Object.prototype.hasOwnProperty;
const schema20 = {"type":"integer","minimum":0,"maximum":4294967295};

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
if(!(((typeof data == "number") && (!(data % 1) && !isNaN(data))) && (isFinite(data)))){
validate53.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "integer"},message:"must be integer"}];
return false;
}
if(errors === 0){
if((typeof data == "number") && (isFinite(data))){
if(data > 4294967295 || isNaN(data)){
validate53.errors = [{instancePath,schemaPath:"#/maximum",keyword:"maximum",params:{comparison: "<=", limit: 4294967295},message:"must be <= 4294967295"}];
return false;
}
else {
if(data < 0 || isNaN(data)){
validate53.errors = [{instancePath,schemaPath:"#/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"}];
return false;
}
}
}
}
validate53.errors = vErrors;
return errors === 0;
}
validate53.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema21 = {"type":"integer","minimum":0,"maximum":9007199254740991};

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
if(!(((typeof data == "number") && (!(data % 1) && !isNaN(data))) && (isFinite(data)))){
validate55.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "integer"},message:"must be integer"}];
return false;
}
if(errors === 0){
if((typeof data == "number") && (isFinite(data))){
if(data > 9007199254740991 || isNaN(data)){
validate55.errors = [{instancePath,schemaPath:"#/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"}];
return false;
}
else {
if(data < 0 || isNaN(data)){
validate55.errors = [{instancePath,schemaPath:"#/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"}];
return false;
}
}
}
}
validate55.errors = vErrors;
return errors === 0;
}
validate55.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema22 = {"anyOf":[{"$ref":"https://transit.invalid/generated-validator/1"},{"type":"null"}]};

function validate57(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate57.evaluated;
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
validate57.errors = vErrors;
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
validate57.errors = vErrors;
return errors === 0;
}
validate57.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema23 = {"type":"object","additionalProperties":false,"properties":{"position":{"$ref":"https://transit.invalid/generated-validator/1"},"policy_revision":{"$ref":"https://transit.invalid/generated-validator/1"},"retained_from":{"$ref":"https://transit.invalid/generated-validator/1"}},"required":["position","policy_revision","retained_from"]};

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
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((((data.position === undefined) && (missing0 = "position")) || ((data.policy_revision === undefined) && (missing0 = "policy_revision"))) || ((data.retained_from === undefined) && (missing0 = "retained_from"))){
validate60.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "position") || (key0 === "policy_revision")) || (key0 === "retained_from"))){
validate60.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.position !== undefined){
const _errs2 = errors;
if(!(validate55(data.position, {instancePath:instancePath+"/position",parentData:data,parentDataProperty:"position",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate55.errors : vErrors.concat(validate55.errors);
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
if(!(validate55(data.policy_revision, {instancePath:instancePath+"/policy_revision",parentData:data,parentDataProperty:"policy_revision",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate55.errors : vErrors.concat(validate55.errors);
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
if(!(validate55(data.retained_from, {instancePath:instancePath+"/retained_from",parentData:data,parentDataProperty:"retained_from",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate55.errors : vErrors.concat(validate55.errors);
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
validate60.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate60.errors = vErrors;
return errors === 0;
}
validate60.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema24 = {"type":"object","additionalProperties":false,"properties":{"principal":{"$ref":"https://transit.invalid/generated-validator/1"},"permissions":{"$ref":"https://transit.invalid/generated-validator/4"},"pid":{"$ref":"https://transit.invalid/generated-validator/2"},"policy_revision":{"$ref":"https://transit.invalid/generated-validator/1"}},"required":["principal","permissions","pid","policy_revision"]};
const schema25 = {"type":"integer","minimum":0,"maximum":65535};

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
if(!(((typeof data == "number") && (!(data % 1) && !isNaN(data))) && (isFinite(data)))){
validate67.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "integer"},message:"must be integer"}];
return false;
}
if(errors === 0){
if((typeof data == "number") && (isFinite(data))){
if(data > 65535 || isNaN(data)){
validate67.errors = [{instancePath,schemaPath:"#/maximum",keyword:"maximum",params:{comparison: "<=", limit: 65535},message:"must be <= 65535"}];
return false;
}
else {
if(data < 0 || isNaN(data)){
validate67.errors = [{instancePath,schemaPath:"#/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"}];
return false;
}
}
}
}
validate67.errors = vErrors;
return errors === 0;
}
validate67.evaluated = {"dynamicProps":false,"dynamicItems":false};


function validate65(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate65.evaluated;
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
validate65.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((((key0 === "principal") || (key0 === "permissions")) || (key0 === "pid")) || (key0 === "policy_revision"))){
validate65.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.principal !== undefined){
const _errs2 = errors;
if(!(validate55(data.principal, {instancePath:instancePath+"/principal",parentData:data,parentDataProperty:"principal",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate55.errors : vErrors.concat(validate55.errors);
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
if(!(validate67(data.permissions, {instancePath:instancePath+"/permissions",parentData:data,parentDataProperty:"permissions",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate67.errors : vErrors.concat(validate67.errors);
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
if(!(validate57(data.pid, {instancePath:instancePath+"/pid",parentData:data,parentDataProperty:"pid",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate57.errors : vErrors.concat(validate57.errors);
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
if(!(validate55(data.policy_revision, {instancePath:instancePath+"/policy_revision",parentData:data,parentDataProperty:"policy_revision",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate55.errors : vErrors.concat(validate55.errors);
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
validate65.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate65.errors = vErrors;
return errors === 0;
}
validate65.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema26 = {"type":"array","minItems":8,"maxItems":8,"items":{"$ref":"https://transit.invalid/generated-validator/27"}};
const schema27 = {"anyOf":[{"$ref":"https://transit.invalid/generated-validator/26"},{"type":"null"}]};
const schema28 = {"type":"object","additionalProperties":false,"properties":{"allow_collection":{"type":"boolean"},"pid":{"$ref":"https://transit.invalid/generated-validator/1"},"code":{"$ref":"https://transit.invalid/generated-validator/0"},"owner":{"$ref":"https://transit.invalid/generated-validator/2"},"generation":{"$ref":"https://transit.invalid/generated-validator/1"},"revision":{"$ref":"https://transit.invalid/generated-validator/1"},"lifecycle":{"$ref":"https://transit.invalid/generated-validator/6"},"failure":{"$ref":"https://transit.invalid/generated-validator/2"},"admitted":{"$ref":"https://transit.invalid/generated-validator/1"},"consumed":{"$ref":"https://transit.invalid/generated-validator/1"},"cancelled":{"$ref":"https://transit.invalid/generated-validator/1"},"work_before_ms":{"$ref":"https://transit.invalid/generated-validator/2"},"settle_before_ms":{"$ref":"https://transit.invalid/generated-validator/2"},"turn_permit":{"$ref":"https://transit.invalid/generated-validator/8"},"binding":{"$ref":"https://transit.invalid/generated-validator/19"},"control":{"$ref":"https://transit.invalid/generated-validator/25"}},"required":["allow_collection","pid","code","owner","generation","revision","lifecycle","failure","admitted","consumed","cancelled","work_before_ms","settle_before_ms","turn_permit","binding","control"]};
const schema29 = {"type":"string","enum":["running","terminated","expired"]};

function validate83(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate83.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate83.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
if(!(((data === "running") || (data === "terminated")) || (data === "expired"))){
validate83.errors = [{instancePath,schemaPath:"#/enum",keyword:"enum",params:{allowedValues: schema29.enum},message:"must be equal to one of the allowed values"}];
return false;
}
validate83.errors = vErrors;
return errors === 0;
}
validate83.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema30 = {"anyOf":[{"$ref":"https://transit.invalid/generated-validator/7"},{"type":"null"}]};
const schema31 = {"type":"object","additionalProperties":false,"properties":{"id":{"$ref":"https://transit.invalid/generated-validator/1"},"input":{"$ref":"https://transit.invalid/generated-validator/1"}},"required":["id","input"]};

function validate92(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate92.evaluated;
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
validate92.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "id") || (key0 === "input"))){
validate92.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.id !== undefined){
const _errs2 = errors;
if(!(validate55(data.id, {instancePath:instancePath+"/id",parentData:data,parentDataProperty:"id",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate55.errors : vErrors.concat(validate55.errors);
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
if(!(validate55(data.input, {instancePath:instancePath+"/input",parentData:data,parentDataProperty:"input",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate55.errors : vErrors.concat(validate55.errors);
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
validate92.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate92.errors = vErrors;
return errors === 0;
}
validate92.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate91(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate91.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate92(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate92.errors : vErrors.concat(validate92.errors);
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
validate91.errors = vErrors;
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
validate91.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate91.evaluated = {"dynamicProps":true,"dynamicItems":false};

const schema32 = {"anyOf":[{"$ref":"https://transit.invalid/generated-validator/18"},{"type":"null"}]};
const schema33 = {"type":"object","additionalProperties":false,"properties":{"revision":{"$ref":"https://transit.invalid/generated-validator/1"},"operation":{"$ref":"https://transit.invalid/generated-validator/1"},"instance":{"$ref":"https://transit.invalid/generated-validator/10"},"resource":{"$ref":"https://transit.invalid/generated-validator/11"},"workload":{"$ref":"https://transit.invalid/generated-validator/11"},"incarnation":{"$ref":"https://transit.invalid/generated-validator/12"},"desired":{"$ref":"https://transit.invalid/generated-validator/13"},"phase":{"$ref":"https://transit.invalid/generated-validator/14"},"upgrade_from":{"$ref":"https://transit.invalid/generated-validator/15"},"activation":{"$ref":"https://transit.invalid/generated-validator/17"},"last_worker_incarnation":{"$ref":"https://transit.invalid/generated-validator/12"}},"required":["revision","operation","instance","resource","workload","incarnation","desired","phase","activation","last_worker_incarnation"]};
const schema34 = {"type":"array","minItems":16,"maxItems":16,"items":{"$ref":"https://transit.invalid/generated-validator/9"}};
const schema35 = {"type":"integer","minimum":0,"maximum":255};

function validate102(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate102.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(!(((typeof data == "number") && (!(data % 1) && !isNaN(data))) && (isFinite(data)))){
validate102.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "integer"},message:"must be integer"}];
return false;
}
if(errors === 0){
if((typeof data == "number") && (isFinite(data))){
if(data > 255 || isNaN(data)){
validate102.errors = [{instancePath,schemaPath:"#/maximum",keyword:"maximum",params:{comparison: "<=", limit: 255},message:"must be <= 255"}];
return false;
}
else {
if(data < 0 || isNaN(data)){
validate102.errors = [{instancePath,schemaPath:"#/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"}];
return false;
}
}
}
}
validate102.errors = vErrors;
return errors === 0;
}
validate102.evaluated = {"dynamicProps":false,"dynamicItems":false};


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
if(errors === 0){
if(Array.isArray(data)){
if(data.length > 16){
validate101.errors = [{instancePath,schemaPath:"#/maxItems",keyword:"maxItems",params:{limit: 16},message:"must NOT have more than 16 items"}];
return false;
}
else {
if(data.length < 16){
validate101.errors = [{instancePath,schemaPath:"#/minItems",keyword:"minItems",params:{limit: 16},message:"must NOT have fewer than 16 items"}];
return false;
}
else {
var valid0 = true;
const len0 = data.length;
for(let i0=0; i0<len0; i0++){
const _errs1 = errors;
if(!(validate102(data[i0], {instancePath:instancePath+"/" + i0,parentData:data,parentDataProperty:i0,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate102.errors : vErrors.concat(validate102.errors);
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
validate101.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "array"},message:"must be array"}];
return false;
}
}
validate101.errors = vErrors;
return errors === 0;
}
validate101.evaluated = {"items":true,"dynamicProps":false,"dynamicItems":false};

const schema36 = {"type":"array","minItems":32,"maxItems":32,"items":{"$ref":"https://transit.invalid/generated-validator/9"}};

function validate105(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate105.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(Array.isArray(data)){
if(data.length > 32){
validate105.errors = [{instancePath,schemaPath:"#/maxItems",keyword:"maxItems",params:{limit: 32},message:"must NOT have more than 32 items"}];
return false;
}
else {
if(data.length < 32){
validate105.errors = [{instancePath,schemaPath:"#/minItems",keyword:"minItems",params:{limit: 32},message:"must NOT have fewer than 32 items"}];
return false;
}
else {
var valid0 = true;
const len0 = data.length;
for(let i0=0; i0<len0; i0++){
const _errs1 = errors;
if(!(validate102(data[i0], {instancePath:instancePath+"/" + i0,parentData:data,parentDataProperty:i0,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate102.errors : vErrors.concat(validate102.errors);
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
validate105.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "array"},message:"must be array"}];
return false;
}
}
validate105.errors = vErrors;
return errors === 0;
}
validate105.evaluated = {"items":true,"dynamicProps":false,"dynamicItems":false};

const schema37 = {"anyOf":[{"$ref":"https://transit.invalid/generated-validator/10"},{"type":"null"}]};

function validate109(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate109.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate101(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate101.errors : vErrors.concat(validate101.errors);
errors = vErrors.length;
}
var _valid0 = _errs1 === errors;
valid0 = valid0 || _valid0;
if(_valid0){
var items0 = true;
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
validate109.errors = vErrors;
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
validate109.errors = vErrors;
evaluated0.items = items0;
return errors === 0;
}
validate109.evaluated = {"dynamicProps":false,"dynamicItems":true};

const schema38 = {"type":"string","enum":["running","stopped"]};

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
if(typeof data !== "string"){
validate112.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
if(!((data === "running") || (data === "stopped"))){
validate112.errors = [{instancePath,schemaPath:"#/enum",keyword:"enum",params:{allowedValues: schema38.enum},message:"must be equal to one of the allowed values"}];
return false;
}
validate112.errors = vErrors;
return errors === 0;
}
validate112.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema39 = {"type":"string","enum":["pending","unknown","ready","stopped"]};

function validate114(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate114.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate114.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
if(!((((data === "pending") || (data === "unknown")) || (data === "ready")) || (data === "stopped"))){
validate114.errors = [{instancePath,schemaPath:"#/enum",keyword:"enum",params:{allowedValues: schema39.enum},message:"must be equal to one of the allowed values"}];
return false;
}
validate114.errors = vErrors;
return errors === 0;
}
validate114.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema40 = {"anyOf":[{"$ref":"https://transit.invalid/generated-validator/11"},{"type":"null"}]};

function validate116(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate116.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate105(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate105.errors : vErrors.concat(validate105.errors);
errors = vErrors.length;
}
var _valid0 = _errs1 === errors;
valid0 = valid0 || _valid0;
if(_valid0){
var items0 = true;
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
validate116.errors = vErrors;
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
validate116.errors = vErrors;
evaluated0.items = items0;
return errors === 0;
}
validate116.evaluated = {"dynamicProps":false,"dynamicItems":true};

const schema41 = {"anyOf":[{"$ref":"https://transit.invalid/generated-validator/16"},{"type":"null"}]};
const schema42 = {"type":"object","additionalProperties":false,"properties":{"worker_incarnation":{"$ref":"https://transit.invalid/generated-validator/10"},"generation":{"$ref":"https://transit.invalid/generated-validator/1"}},"required":["worker_incarnation","generation"]};

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
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if(((data.worker_incarnation === undefined) && (missing0 = "worker_incarnation")) || ((data.generation === undefined) && (missing0 = "generation"))){
validate120.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "worker_incarnation") || (key0 === "generation"))){
validate120.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.worker_incarnation !== undefined){
const _errs2 = errors;
if(!(validate101(data.worker_incarnation, {instancePath:instancePath+"/worker_incarnation",parentData:data,parentDataProperty:"worker_incarnation",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate101.errors : vErrors.concat(validate101.errors);
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
if(!(validate55(data.generation, {instancePath:instancePath+"/generation",parentData:data,parentDataProperty:"generation",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate55.errors : vErrors.concat(validate55.errors);
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
validate120.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate120.errors = vErrors;
return errors === 0;
}
validate120.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


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
if(((((((((((data.revision === undefined) && (missing0 = "revision")) || ((data.operation === undefined) && (missing0 = "operation"))) || ((data.instance === undefined) && (missing0 = "instance"))) || ((data.resource === undefined) && (missing0 = "resource"))) || ((data.workload === undefined) && (missing0 = "workload"))) || ((data.incarnation === undefined) && (missing0 = "incarnation"))) || ((data.desired === undefined) && (missing0 = "desired"))) || ((data.phase === undefined) && (missing0 = "phase"))) || ((data.activation === undefined) && (missing0 = "activation"))) || ((data.last_worker_incarnation === undefined) && (missing0 = "last_worker_incarnation"))){
validate98.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(func1.call(schema33.properties, key0))){
validate98.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.revision !== undefined){
const _errs2 = errors;
if(!(validate55(data.revision, {instancePath:instancePath+"/revision",parentData:data,parentDataProperty:"revision",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate55.errors : vErrors.concat(validate55.errors);
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
if(!(validate55(data.operation, {instancePath:instancePath+"/operation",parentData:data,parentDataProperty:"operation",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate55.errors : vErrors.concat(validate55.errors);
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
if(!(validate101(data.instance, {instancePath:instancePath+"/instance",parentData:data,parentDataProperty:"instance",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate101.errors : vErrors.concat(validate101.errors);
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
if(!(validate105(data.resource, {instancePath:instancePath+"/resource",parentData:data,parentDataProperty:"resource",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate105.errors : vErrors.concat(validate105.errors);
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
if(!(validate105(data.workload, {instancePath:instancePath+"/workload",parentData:data,parentDataProperty:"workload",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate105.errors : vErrors.concat(validate105.errors);
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
if(!(validate109(data.incarnation, {instancePath:instancePath+"/incarnation",parentData:data,parentDataProperty:"incarnation",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate109.errors : vErrors.concat(validate109.errors);
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
if(!(validate112(data.desired, {instancePath:instancePath+"/desired",parentData:data,parentDataProperty:"desired",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate112.errors : vErrors.concat(validate112.errors);
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
if(!(validate114(data.phase, {instancePath:instancePath+"/phase",parentData:data,parentDataProperty:"phase",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate114.errors : vErrors.concat(validate114.errors);
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
if(!(validate116(data.upgrade_from, {instancePath:instancePath+"/upgrade_from",parentData:data,parentDataProperty:"upgrade_from",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate116.errors : vErrors.concat(validate116.errors);
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
if(!(validate119(data.activation, {instancePath:instancePath+"/activation",parentData:data,parentDataProperty:"activation",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate119.errors : vErrors.concat(validate119.errors);
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
if(!(validate109(data.last_worker_incarnation, {instancePath:instancePath+"/last_worker_incarnation",parentData:data,parentDataProperty:"last_worker_incarnation",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate109.errors : vErrors.concat(validate109.errors);
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
validate98.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
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

const schema43 = {"anyOf":[{"$ref":"https://transit.invalid/generated-validator/24"},{"type":"null"}]};
const schema44 = {"type":"object","additionalProperties":false,"properties":{"phase":{"$ref":"https://transit.invalid/generated-validator/20"},"required":{"$ref":"https://transit.invalid/generated-validator/23"},"resume_before_ms":{"$ref":"https://transit.invalid/generated-validator/2"}},"required":["phase","required","resume_before_ms"]};
const schema45 = {"type":"string","enum":["initializing","ready","suspended"]};

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
if(typeof data !== "string"){
validate130.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
if(!(((data === "initializing") || (data === "ready")) || (data === "suspended"))){
validate130.errors = [{instancePath,schemaPath:"#/enum",keyword:"enum",params:{allowedValues: schema45.enum},message:"must be equal to one of the allowed values"}];
return false;
}
validate130.errors = vErrors;
return errors === 0;
}
validate130.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema46 = {"type":"array","minItems":4,"maxItems":4,"items":{"$ref":"https://transit.invalid/generated-validator/22"}};
const schema47 = {"anyOf":[{"$ref":"https://transit.invalid/generated-validator/21"},{"type":"null"}]};
const schema48 = {"type":"string","pattern":"^(?:[0-9a-f]{2})*$","maxLength":512};
const func4 = ucs2length;
const pattern3 = new RegExp("^(?:[0-9a-f]{2})*$", "u");

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
if(errors === 0){
if(typeof data === "string"){
if(func4(data) > 512){
validate134.errors = [{instancePath,schemaPath:"#/maxLength",keyword:"maxLength",params:{limit: 512},message:"must NOT have more than 512 characters"}];
return false;
}
else {
if(!pattern3.test(data)){
validate134.errors = [{instancePath,schemaPath:"#/pattern",keyword:"pattern",params:{pattern: "^(?:[0-9a-f]{2})*$"},message:"must match pattern \""+"^(?:[0-9a-f]{2})*$"+"\""}];
return false;
}
}
}
else {
validate134.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
}
validate134.errors = vErrors;
return errors === 0;
}
validate134.evaluated = {"dynamicProps":false,"dynamicItems":false};


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
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate134(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate134.errors : vErrors.concat(validate134.errors);
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
validate133.errors = vErrors;
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
validate133.errors = vErrors;
return errors === 0;
}
validate133.evaluated = {"dynamicProps":false,"dynamicItems":false};


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
if(Array.isArray(data)){
if(data.length > 4){
validate132.errors = [{instancePath,schemaPath:"#/maxItems",keyword:"maxItems",params:{limit: 4},message:"must NOT have more than 4 items"}];
return false;
}
else {
if(data.length < 4){
validate132.errors = [{instancePath,schemaPath:"#/minItems",keyword:"minItems",params:{limit: 4},message:"must NOT have fewer than 4 items"}];
return false;
}
else {
var valid0 = true;
const len0 = data.length;
for(let i0=0; i0<len0; i0++){
const _errs1 = errors;
if(!(validate133(data[i0], {instancePath:instancePath+"/" + i0,parentData:data,parentDataProperty:i0,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate133.errors : vErrors.concat(validate133.errors);
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
validate132.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "array"},message:"must be array"}];
return false;
}
}
validate132.errors = vErrors;
return errors === 0;
}
validate132.evaluated = {"items":true,"dynamicProps":false,"dynamicItems":false};


function validate129(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate129.evaluated;
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
validate129.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "phase") || (key0 === "required")) || (key0 === "resume_before_ms"))){
validate129.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.phase !== undefined){
const _errs2 = errors;
if(!(validate130(data.phase, {instancePath:instancePath+"/phase",parentData:data,parentDataProperty:"phase",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate130.errors : vErrors.concat(validate130.errors);
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
if(!(validate132(data.required, {instancePath:instancePath+"/required",parentData:data,parentDataProperty:"required",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate132.errors : vErrors.concat(validate132.errors);
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
if(!(validate57(data.resume_before_ms, {instancePath:instancePath+"/resume_before_ms",parentData:data,parentDataProperty:"resume_before_ms",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate57.errors : vErrors.concat(validate57.errors);
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
validate129.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate129.errors = vErrors;
return errors === 0;
}
validate129.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate128(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate128.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate129(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate129.errors : vErrors.concat(validate129.errors);
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
validate128.errors = vErrors;
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
validate128.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate128.evaluated = {"dynamicProps":true,"dynamicItems":false};


function validate77(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate77.evaluated;
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
validate77.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(func1.call(schema28.properties, key0))){
validate77.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.allow_collection !== undefined){
const _errs2 = errors;
if(typeof data.allow_collection !== "boolean"){
validate77.errors = [{instancePath:instancePath+"/allow_collection",schemaPath:"#/properties/allow_collection/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"}];
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
if(!(validate55(data.pid, {instancePath:instancePath+"/pid",parentData:data,parentDataProperty:"pid",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate55.errors : vErrors.concat(validate55.errors);
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
if(!(validate53(data.code, {instancePath:instancePath+"/code",parentData:data,parentDataProperty:"code",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate53.errors : vErrors.concat(validate53.errors);
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
if(!(validate57(data.owner, {instancePath:instancePath+"/owner",parentData:data,parentDataProperty:"owner",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate57.errors : vErrors.concat(validate57.errors);
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
if(!(validate55(data.generation, {instancePath:instancePath+"/generation",parentData:data,parentDataProperty:"generation",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate55.errors : vErrors.concat(validate55.errors);
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
if(!(validate55(data.revision, {instancePath:instancePath+"/revision",parentData:data,parentDataProperty:"revision",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate55.errors : vErrors.concat(validate55.errors);
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
if(!(validate83(data.lifecycle, {instancePath:instancePath+"/lifecycle",parentData:data,parentDataProperty:"lifecycle",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate83.errors : vErrors.concat(validate83.errors);
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
if(!(validate57(data.failure, {instancePath:instancePath+"/failure",parentData:data,parentDataProperty:"failure",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate57.errors : vErrors.concat(validate57.errors);
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
if(!(validate55(data.admitted, {instancePath:instancePath+"/admitted",parentData:data,parentDataProperty:"admitted",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate55.errors : vErrors.concat(validate55.errors);
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
if(!(validate55(data.consumed, {instancePath:instancePath+"/consumed",parentData:data,parentDataProperty:"consumed",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate55.errors : vErrors.concat(validate55.errors);
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
if(!(validate55(data.cancelled, {instancePath:instancePath+"/cancelled",parentData:data,parentDataProperty:"cancelled",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate55.errors : vErrors.concat(validate55.errors);
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
if(!(validate57(data.work_before_ms, {instancePath:instancePath+"/work_before_ms",parentData:data,parentDataProperty:"work_before_ms",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate57.errors : vErrors.concat(validate57.errors);
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
if(!(validate57(data.settle_before_ms, {instancePath:instancePath+"/settle_before_ms",parentData:data,parentDataProperty:"settle_before_ms",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate57.errors : vErrors.concat(validate57.errors);
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
if(!(validate91(data.turn_permit, {instancePath:instancePath+"/turn_permit",parentData:data,parentDataProperty:"turn_permit",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate91.errors : vErrors.concat(validate91.errors);
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
if(!(validate97(data.binding, {instancePath:instancePath+"/binding",parentData:data,parentDataProperty:"binding",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate97.errors : vErrors.concat(validate97.errors);
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
if(!(validate128(data.control, {instancePath:instancePath+"/control",parentData:data,parentDataProperty:"control",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate128.errors : vErrors.concat(validate128.errors);
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
validate77.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate77.errors = vErrors;
return errors === 0;
}
validate77.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


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
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate77(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate77.errors : vErrors.concat(validate77.errors);
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
validate76.errors = vErrors;
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
validate76.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate76.evaluated = {"dynamicProps":true,"dynamicItems":false};


function validate75(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate75.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(Array.isArray(data)){
if(data.length > 8){
validate75.errors = [{instancePath,schemaPath:"#/maxItems",keyword:"maxItems",params:{limit: 8},message:"must NOT have more than 8 items"}];
return false;
}
else {
if(data.length < 8){
validate75.errors = [{instancePath,schemaPath:"#/minItems",keyword:"minItems",params:{limit: 8},message:"must NOT have fewer than 8 items"}];
return false;
}
else {
var valid0 = true;
const len0 = data.length;
for(let i0=0; i0<len0; i0++){
const _errs1 = errors;
if(!(validate76(data[i0], {instancePath:instancePath+"/" + i0,parentData:data,parentDataProperty:i0,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate76.errors : vErrors.concat(validate76.errors);
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
validate75.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "array"},message:"must be array"}];
return false;
}
}
validate75.errors = vErrors;
return errors === 0;
}
validate75.evaluated = {"items":true,"dynamicProps":false,"dynamicItems":false};

const schema49 = {"type":"object","additionalProperties":false,"properties":{"realm":{"$ref":"https://transit.invalid/generated-validator/1"},"pid":{"$ref":"https://transit.invalid/generated-validator/1"},"kind":{"$ref":"https://transit.invalid/generated-validator/29"},"id":{"$ref":"https://transit.invalid/generated-validator/1"}},"required":["realm","pid","kind","id"]};
const schema50 = {"type":"string","enum":["input","turn","output","effect","event","state"]};

function validate189(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate189.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate189.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
if(!((((((data === "input") || (data === "turn")) || (data === "output")) || (data === "effect")) || (data === "event")) || (data === "state"))){
validate189.errors = [{instancePath,schemaPath:"#/enum",keyword:"enum",params:{allowedValues: schema50.enum},message:"must be equal to one of the allowed values"}];
return false;
}
validate189.errors = vErrors;
return errors === 0;
}
validate189.evaluated = {"dynamicProps":false,"dynamicItems":false};


function validate186(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate186.evaluated;
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
validate186.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((((key0 === "realm") || (key0 === "pid")) || (key0 === "kind")) || (key0 === "id"))){
validate186.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.realm !== undefined){
const _errs2 = errors;
if(!(validate55(data.realm, {instancePath:instancePath+"/realm",parentData:data,parentDataProperty:"realm",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate55.errors : vErrors.concat(validate55.errors);
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
if(!(validate55(data.pid, {instancePath:instancePath+"/pid",parentData:data,parentDataProperty:"pid",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate55.errors : vErrors.concat(validate55.errors);
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
if(!(validate189(data.kind, {instancePath:instancePath+"/kind",parentData:data,parentDataProperty:"kind",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate189.errors : vErrors.concat(validate189.errors);
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
if(!(validate55(data.id, {instancePath:instancePath+"/id",parentData:data,parentDataProperty:"id",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate55.errors : vErrors.concat(validate55.errors);
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
validate186.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate186.errors = vErrors;
return errors === 0;
}
validate186.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema51 = {"type":"string","enum":["retained","reclaimed","current_state"]};

function validate194(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate194.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate194.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
if(!(((data === "retained") || (data === "reclaimed")) || (data === "current_state"))){
validate194.errors = [{instancePath,schemaPath:"#/enum",keyword:"enum",params:{allowedValues: schema51.enum},message:"must be equal to one of the allowed values"}];
return false;
}
validate194.errors = vErrors;
return errors === 0;
}
validate194.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema52 = {"anyOf":[{"$ref":"https://transit.invalid/generated-validator/66"},{"type":"null"}]};
const schema53 = {"type":"object","additionalProperties":false,"properties":{"version":{"const":1},"definition":{"$ref":"https://transit.invalid/generated-validator/32"},"code":{"type":"string","maxLength":96},"category":{"$ref":"https://transit.invalid/generated-validator/33"},"stage":{"$ref":"https://transit.invalid/generated-validator/34"},"outcome":{"$ref":"https://transit.invalid/generated-validator/35"},"evidence":{"$ref":"https://transit.invalid/generated-validator/36"},"message":{"type":"string","maxLength":384},"cause":{"$ref":"https://transit.invalid/generated-validator/37"},"identity":{"$ref":"https://transit.invalid/generated-validator/42"},"location":{"$ref":"https://transit.invalid/generated-validator/46"},"facts":{"$ref":"https://transit.invalid/generated-validator/61"},"actions":{"$ref":"https://transit.invalid/generated-validator/65"}},"required":["version","definition","code","category","stage","outcome","evidence","message","cause","identity","location","facts","actions"]};
const schema54 = {"type":"string","enum":["57343ef043d4dc7f9612a7ca3309e9218dd527c0f3826a519ff0d29b761b4a82"]};

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
if(typeof data !== "string"){
validate199.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
if(!(data === "57343ef043d4dc7f9612a7ca3309e9218dd527c0f3826a519ff0d29b761b4a82")){
validate199.errors = [{instancePath,schemaPath:"#/enum",keyword:"enum",params:{allowedValues: schema54.enum},message:"must be equal to one of the allowed values"}];
return false;
}
validate199.errors = vErrors;
return errors === 0;
}
validate199.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema55 = {"type":"string","enum":["syntax","binding","unsupported","constraint","access","conflict","limit","lifecycle","integrity","unavailable","internal"]};

function validate201(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate201.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate201.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
if(!(((((((((((data === "syntax") || (data === "binding")) || (data === "unsupported")) || (data === "constraint")) || (data === "access")) || (data === "conflict")) || (data === "limit")) || (data === "lifecycle")) || (data === "integrity")) || (data === "unavailable")) || (data === "internal"))){
validate201.errors = [{instancePath,schemaPath:"#/enum",keyword:"enum",params:{allowedValues: schema55.enum},message:"must be equal to one of the allowed values"}];
return false;
}
validate201.errors = vErrors;
return errors === 0;
}
validate201.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema56 = {"type":"string","enum":["input","parse","compile","bind","prepare","submit","admission","execute","read","decode","output","reconcile","cleanup","control"]};

function validate203(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate203.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate203.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
if(!((((((((((((((data === "input") || (data === "parse")) || (data === "compile")) || (data === "bind")) || (data === "prepare")) || (data === "submit")) || (data === "admission")) || (data === "execute")) || (data === "read")) || (data === "decode")) || (data === "output")) || (data === "reconcile")) || (data === "cleanup")) || (data === "control"))){
validate203.errors = [{instancePath,schemaPath:"#/enum",keyword:"enum",params:{allowedValues: schema56.enum},message:"must be equal to one of the allowed values"}];
return false;
}
validate203.errors = vErrors;
return errors === 0;
}
validate203.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema57 = {"type":"string","enum":["not_applicable","not_submitted","not_dispatched","prepared","unknown","pending","input_rejected","rejected","applied","completed","failed","cancelled","retired","closed_unknown"]};

function validate205(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate205.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate205.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
if(!((((((((((((((data === "not_applicable") || (data === "not_submitted")) || (data === "not_dispatched")) || (data === "prepared")) || (data === "unknown")) || (data === "pending")) || (data === "input_rejected")) || (data === "rejected")) || (data === "applied")) || (data === "completed")) || (data === "failed")) || (data === "cancelled")) || (data === "retired")) || (data === "closed_unknown"))){
validate205.errors = [{instancePath,schemaPath:"#/enum",keyword:"enum",params:{allowedValues: schema57.enum},message:"must be equal to one of the allowed values"}];
return false;
}
validate205.errors = vErrors;
return errors === 0;
}
validate205.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema58 = {"type":"string","enum":["none","local_before_dispatch","saved_intent","native_receipt","domain_status"]};

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
if(typeof data !== "string"){
validate207.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
if(!(((((data === "none") || (data === "local_before_dispatch")) || (data === "saved_intent")) || (data === "native_receipt")) || (data === "domain_status"))){
validate207.errors = [{instancePath,schemaPath:"#/enum",keyword:"enum",params:{allowedValues: schema58.enum},message:"must be equal to one of the allowed values"}];
return false;
}
validate207.errors = vErrors;
return errors === 0;
}
validate207.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema59 = {"anyOf":[{"type":"string","maxLength":96},{"type":"null"}]};

function validate209(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate209.evaluated;
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
if(func4(data) > 96){
const err0 = {instancePath,schemaPath:"#/anyOf/0/maxLength",keyword:"maxLength",params:{limit: 96},message:"must NOT have more than 96 characters"};
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
validate209.errors = vErrors;
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
validate209.errors = vErrors;
return errors === 0;
}
validate209.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema60 = {"anyOf":[{"$ref":"https://transit.invalid/generated-validator/41"},{"type":"null"}]};
const schema61 = {"type":"object","additionalProperties":false,"properties":{"domain":{"$ref":"https://transit.invalid/generated-validator/38"},"id":{"$ref":"https://transit.invalid/generated-validator/39"},"realm":{"$ref":"https://transit.invalid/generated-validator/40"},"resource":{"$ref":"https://transit.invalid/generated-validator/40"},"sequence":{"$ref":"https://transit.invalid/generated-validator/40"}},"required":["domain","id","realm","resource","sequence"]};
const schema62 = {"type":"string","enum":["sql","query","mutation","catalog","application","publication","migration","reactive","serving","effect","exchange","transport","internal"]};

function validate213(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate213.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate213.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
if(!(((((((((((((data === "sql") || (data === "query")) || (data === "mutation")) || (data === "catalog")) || (data === "application")) || (data === "publication")) || (data === "migration")) || (data === "reactive")) || (data === "serving")) || (data === "effect")) || (data === "exchange")) || (data === "transport")) || (data === "internal"))){
validate213.errors = [{instancePath,schemaPath:"#/enum",keyword:"enum",params:{allowedValues: schema62.enum},message:"must be equal to one of the allowed values"}];
return false;
}
validate213.errors = vErrors;
return errors === 0;
}
validate213.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema63 = {"type":"string","maxLength":20,"pattern":"^(0|[1-9][0-9]*)$"};
const pattern4 = new RegExp("^(0|[1-9][0-9]*)$", "u");

function validate215(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate215.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(typeof data === "string"){
if(func4(data) > 20){
validate215.errors = [{instancePath,schemaPath:"#/maxLength",keyword:"maxLength",params:{limit: 20},message:"must NOT have more than 20 characters"}];
return false;
}
else {
if(!pattern4.test(data)){
validate215.errors = [{instancePath,schemaPath:"#/pattern",keyword:"pattern",params:{pattern: "^(0|[1-9][0-9]*)$"},message:"must match pattern \""+"^(0|[1-9][0-9]*)$"+"\""}];
return false;
}
}
}
else {
validate215.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
}
validate215.errors = vErrors;
return errors === 0;
}
validate215.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema64 = {"anyOf":[{"$ref":"https://transit.invalid/generated-validator/39"},{"type":"null"}]};

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
if(!(validate215(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate215.errors : vErrors.concat(validate215.errors);
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
return errors === 0;
}
validate217.evaluated = {"dynamicProps":false,"dynamicItems":false};


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
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((((((data.domain === undefined) && (missing0 = "domain")) || ((data.id === undefined) && (missing0 = "id"))) || ((data.realm === undefined) && (missing0 = "realm"))) || ((data.resource === undefined) && (missing0 = "resource"))) || ((data.sequence === undefined) && (missing0 = "sequence"))){
validate212.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((((key0 === "domain") || (key0 === "id")) || (key0 === "realm")) || (key0 === "resource")) || (key0 === "sequence"))){
validate212.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.domain !== undefined){
const _errs2 = errors;
if(!(validate213(data.domain, {instancePath:instancePath+"/domain",parentData:data,parentDataProperty:"domain",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate213.errors : vErrors.concat(validate213.errors);
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
if(!(validate215(data.id, {instancePath:instancePath+"/id",parentData:data,parentDataProperty:"id",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate215.errors : vErrors.concat(validate215.errors);
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
if(!(validate217(data.realm, {instancePath:instancePath+"/realm",parentData:data,parentDataProperty:"realm",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate217.errors : vErrors.concat(validate217.errors);
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
if(!(validate217(data.resource, {instancePath:instancePath+"/resource",parentData:data,parentDataProperty:"resource",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate217.errors : vErrors.concat(validate217.errors);
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
if(!(validate217(data.sequence, {instancePath:instancePath+"/sequence",parentData:data,parentDataProperty:"sequence",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate217.errors : vErrors.concat(validate217.errors);
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
validate212.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate212.errors = vErrors;
return errors === 0;
}
validate212.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate211(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate211.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate212(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate212.errors : vErrors.concat(validate212.errors);
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
validate211.errors = vErrors;
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
validate211.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate211.evaluated = {"dynamicProps":true,"dynamicItems":false};

const schema65 = {"anyOf":[{"$ref":"https://transit.invalid/generated-validator/45"},{"type":"null"}]};
const schema66 = {"type":"object","additionalProperties":false,"properties":{"source":{"$ref":"https://transit.invalid/generated-validator/43"},"source_encoding":{"$ref":"https://transit.invalid/generated-validator/44"},"source_truncated":{"type":"boolean"},"statement":{"$ref":"https://transit.invalid/generated-validator/40"},"offset":{"$ref":"https://transit.invalid/generated-validator/39"},"length":{"$ref":"https://transit.invalid/generated-validator/39"},"line":{"$ref":"https://transit.invalid/generated-validator/39"},"byte_column":{"$ref":"https://transit.invalid/generated-validator/39"}},"required":["source","source_encoding","source_truncated","statement","offset","length","line","byte_column"]};
const schema67 = {"anyOf":[{"type":"string","maxLength":512},{"type":"null"}]};

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
if(errors === _errs1){
if(typeof data === "string"){
if(func4(data) > 512){
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
return errors === 0;
}
validate226.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema68 = {"type":"string","enum":["utf8","escaped_bytes"]};

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
validate228.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
if(!((data === "utf8") || (data === "escaped_bytes"))){
validate228.errors = [{instancePath,schemaPath:"#/enum",keyword:"enum",params:{allowedValues: schema68.enum},message:"must be equal to one of the allowed values"}];
return false;
}
validate228.errors = vErrors;
return errors === 0;
}
validate228.evaluated = {"dynamicProps":false,"dynamicItems":false};


function validate225(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate225.evaluated;
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
validate225.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((((((((key0 === "source") || (key0 === "source_encoding")) || (key0 === "source_truncated")) || (key0 === "statement")) || (key0 === "offset")) || (key0 === "length")) || (key0 === "line")) || (key0 === "byte_column"))){
validate225.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.source !== undefined){
const _errs2 = errors;
if(!(validate226(data.source, {instancePath:instancePath+"/source",parentData:data,parentDataProperty:"source",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate226.errors : vErrors.concat(validate226.errors);
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
if(!(validate228(data.source_encoding, {instancePath:instancePath+"/source_encoding",parentData:data,parentDataProperty:"source_encoding",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate228.errors : vErrors.concat(validate228.errors);
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
validate225.errors = [{instancePath:instancePath+"/source_truncated",schemaPath:"#/properties/source_truncated/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"}];
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
if(!(validate217(data.statement, {instancePath:instancePath+"/statement",parentData:data,parentDataProperty:"statement",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate217.errors : vErrors.concat(validate217.errors);
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
if(!(validate215(data.offset, {instancePath:instancePath+"/offset",parentData:data,parentDataProperty:"offset",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate215.errors : vErrors.concat(validate215.errors);
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
if(!(validate215(data.length, {instancePath:instancePath+"/length",parentData:data,parentDataProperty:"length",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate215.errors : vErrors.concat(validate215.errors);
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
if(!(validate215(data.line, {instancePath:instancePath+"/line",parentData:data,parentDataProperty:"line",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate215.errors : vErrors.concat(validate215.errors);
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
if(!(validate215(data.byte_column, {instancePath:instancePath+"/byte_column",parentData:data,parentDataProperty:"byte_column",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate215.errors : vErrors.concat(validate215.errors);
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
validate225.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate225.errors = vErrors;
return errors === 0;
}
validate225.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate224(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate224.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate225(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate225.errors : vErrors.concat(validate225.errors);
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
validate224.errors = vErrors;
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
validate224.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate224.evaluated = {"dynamicProps":true,"dynamicItems":false};

const schema69 = {"type":"array","minItems":16,"maxItems":16,"items":{"$ref":"https://transit.invalid/generated-validator/60"}};
const schema70 = {"anyOf":[{"$ref":"https://transit.invalid/generated-validator/59"},{"type":"null"}]};
const schema71 = {"type":"object","additionalProperties":false,"properties":{"field":{"$ref":"https://transit.invalid/generated-validator/47"},"origin":{"$ref":"https://transit.invalid/generated-validator/48"},"availability":{"$ref":"https://transit.invalid/generated-validator/49"},"value":{"$ref":"https://transit.invalid/generated-validator/58"}},"required":["field","origin","availability","value"]};
const schema72 = {"type":"string","enum":["object","name","table","native_input","affected_rows","argument","option","permissions","scope","column","qualifier","constraint","key","input_row","first_occurrence","parameter","parameter_use","expected_count","actual_count","expected_type","actual_type","supplied_value","expected_value","expression","source_kind","source_basis","source_key","source_row","field_path","byte_offset","expected_resource","actual_resource","expected_source","actual_source","expected_revision","actual_revision","expected_schema","actual_schema","expected_policy","actual_policy","budget","limit","required","unit","completed_statements","emitted_rows","emitted_segments","completion","proposal","step","generation","attachment","lease","schema_origin","sampling_records","operation","native_cause","expected_bytes","presence","published","subscription","expected_codec","actual_codec","observed_clock","expected_namespace","actual_namespace","attempt","executor","resolution_reason","principal","deadline","authorization_policy","resolution_policy","protocol_status","native_effect","dependency","dependency_kind","dependency_owner"]};

function validate240(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate240.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate240.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
if(!((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((data === "object") || (data === "name")) || (data === "table")) || (data === "native_input")) || (data === "affected_rows")) || (data === "argument")) || (data === "option")) || (data === "permissions")) || (data === "scope")) || (data === "column")) || (data === "qualifier")) || (data === "constraint")) || (data === "key")) || (data === "input_row")) || (data === "first_occurrence")) || (data === "parameter")) || (data === "parameter_use")) || (data === "expected_count")) || (data === "actual_count")) || (data === "expected_type")) || (data === "actual_type")) || (data === "supplied_value")) || (data === "expected_value")) || (data === "expression")) || (data === "source_kind")) || (data === "source_basis")) || (data === "source_key")) || (data === "source_row")) || (data === "field_path")) || (data === "byte_offset")) || (data === "expected_resource")) || (data === "actual_resource")) || (data === "expected_source")) || (data === "actual_source")) || (data === "expected_revision")) || (data === "actual_revision")) || (data === "expected_schema")) || (data === "actual_schema")) || (data === "expected_policy")) || (data === "actual_policy")) || (data === "budget")) || (data === "limit")) || (data === "required")) || (data === "unit")) || (data === "completed_statements")) || (data === "emitted_rows")) || (data === "emitted_segments")) || (data === "completion")) || (data === "proposal")) || (data === "step")) || (data === "generation")) || (data === "attachment")) || (data === "lease")) || (data === "schema_origin")) || (data === "sampling_records")) || (data === "operation")) || (data === "native_cause")) || (data === "expected_bytes")) || (data === "presence")) || (data === "published")) || (data === "subscription")) || (data === "expected_codec")) || (data === "actual_codec")) || (data === "observed_clock")) || (data === "expected_namespace")) || (data === "actual_namespace")) || (data === "attempt")) || (data === "executor")) || (data === "resolution_reason")) || (data === "principal")) || (data === "deadline")) || (data === "authorization_policy")) || (data === "resolution_policy")) || (data === "protocol_status")) || (data === "native_effect")) || (data === "dependency")) || (data === "dependency_kind")) || (data === "dependency_owner"))){
validate240.errors = [{instancePath,schemaPath:"#/enum",keyword:"enum",params:{allowedValues: schema72.enum},message:"must be equal to one of the allowed values"}];
return false;
}
validate240.errors = vErrors;
return errors === 0;
}
validate240.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema73 = {"type":"string","enum":["caller","execution","schema","authority","owner"]};

function validate242(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate242.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate242.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
if(!(((((data === "caller") || (data === "execution")) || (data === "schema")) || (data === "authority")) || (data === "owner"))){
validate242.errors = [{instancePath,schemaPath:"#/enum",keyword:"enum",params:{allowedValues: schema73.enum},message:"must be equal to one of the allowed values"}];
return false;
}
validate242.errors = vErrors;
return errors === 0;
}
validate242.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema74 = {"type":"string","enum":["provided","truncated","unrecorded","unavailable","withheld","inapplicable"]};

function validate244(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate244.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate244.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
if(!((((((data === "provided") || (data === "truncated")) || (data === "unrecorded")) || (data === "unavailable")) || (data === "withheld")) || (data === "inapplicable"))){
validate244.errors = [{instancePath,schemaPath:"#/enum",keyword:"enum",params:{allowedValues: schema74.enum},message:"must be equal to one of the allowed values"}];
return false;
}
validate244.errors = vErrors;
return errors === 0;
}
validate244.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema75 = {"anyOf":[{"$ref":"https://transit.invalid/generated-validator/57"},{"type":"null"}]};
const schema76 = {"oneOf":[{"$ref":"https://transit.invalid/generated-validator/50"},{"$ref":"https://transit.invalid/generated-validator/52"},{"$ref":"https://transit.invalid/generated-validator/53"},{"$ref":"https://transit.invalid/generated-validator/54"},{"$ref":"https://transit.invalid/generated-validator/55"},{"$ref":"https://transit.invalid/generated-validator/56"}]};
const schema77 = {"type":"object","additionalProperties":false,"required":["text"],"properties":{"text":{"type":"string","maxLength":256}}};

function validate248(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate248.evaluated;
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
validate248.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(key0 === "text")){
validate248.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
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
if(func4(data0) > 256){
validate248.errors = [{instancePath:instancePath+"/text",schemaPath:"#/properties/text/maxLength",keyword:"maxLength",params:{limit: 256},message:"must NOT have more than 256 characters"}];
return false;
}
}
else {
validate248.errors = [{instancePath:instancePath+"/text",schemaPath:"#/properties/text/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
}
}
}
}
}
else {
validate248.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate248.errors = vErrors;
return errors === 0;
}
validate248.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema78 = {"type":"object","additionalProperties":false,"required":["signed"],"properties":{"signed":{"$ref":"https://transit.invalid/generated-validator/51"}}};
const schema79 = {"type":"string","maxLength":20,"pattern":"^(0|-?[1-9][0-9]*)$"};
const pattern5 = new RegExp("^(0|-?[1-9][0-9]*)$", "u");

function validate251(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate251.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(typeof data === "string"){
if(func4(data) > 20){
validate251.errors = [{instancePath,schemaPath:"#/maxLength",keyword:"maxLength",params:{limit: 20},message:"must NOT have more than 20 characters"}];
return false;
}
else {
if(!pattern5.test(data)){
validate251.errors = [{instancePath,schemaPath:"#/pattern",keyword:"pattern",params:{pattern: "^(0|-?[1-9][0-9]*)$"},message:"must match pattern \""+"^(0|-?[1-9][0-9]*)$"+"\""}];
return false;
}
}
}
else {
validate251.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
}
validate251.errors = vErrors;
return errors === 0;
}
validate251.evaluated = {"dynamicProps":false,"dynamicItems":false};


function validate250(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate250.evaluated;
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
validate250.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(key0 === "signed")){
validate250.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.signed !== undefined){
if(!(validate251(data.signed, {instancePath:instancePath+"/signed",parentData:data,parentDataProperty:"signed",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate251.errors : vErrors.concat(validate251.errors);
errors = vErrors.length;
}
}
}
}
}
else {
validate250.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate250.errors = vErrors;
return errors === 0;
}
validate250.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema80 = {"type":"object","additionalProperties":false,"required":["unsigned"],"properties":{"unsigned":{"$ref":"https://transit.invalid/generated-validator/39"}}};

function validate254(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate254.evaluated;
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
validate254.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(key0 === "unsigned")){
validate254.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.unsigned !== undefined){
if(!(validate215(data.unsigned, {instancePath:instancePath+"/unsigned",parentData:data,parentDataProperty:"unsigned",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate215.errors : vErrors.concat(validate215.errors);
errors = vErrors.length;
}
}
}
}
}
else {
validate254.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate254.errors = vErrors;
return errors === 0;
}
validate254.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema81 = {"type":"object","additionalProperties":false,"required":["boolean"],"properties":{"boolean":{"type":"boolean"}}};

function validate257(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate257.evaluated;
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
validate257.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(key0 === "boolean")){
validate257.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.boolean !== undefined){
if(typeof data.boolean !== "boolean"){
validate257.errors = [{instancePath:instancePath+"/boolean",schemaPath:"#/properties/boolean/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"}];
return false;
}
}
}
}
}
else {
validate257.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate257.errors = vErrors;
return errors === 0;
}
validate257.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema82 = {"type":"object","additionalProperties":false,"required":["digest"],"properties":{"digest":{"$ref":"https://transit.invalid/generated-validator/11"}}};

function validate259(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate259.evaluated;
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
validate259.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(key0 === "digest")){
validate259.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.digest !== undefined){
if(!(validate105(data.digest, {instancePath:instancePath+"/digest",parentData:data,parentDataProperty:"digest",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate105.errors : vErrors.concat(validate105.errors);
errors = vErrors.length;
}
}
}
}
}
else {
validate259.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate259.errors = vErrors;
return errors === 0;
}
validate259.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema83 = {"type":"object","additionalProperties":false,"required":["location"],"properties":{"location":{"$ref":"https://transit.invalid/generated-validator/45"}}};

function validate262(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate262.evaluated;
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
validate262.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(key0 === "location")){
validate262.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.location !== undefined){
if(!(validate225(data.location, {instancePath:instancePath+"/location",parentData:data,parentDataProperty:"location",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate225.errors : vErrors.concat(validate225.errors);
errors = vErrors.length;
}
}
}
}
}
else {
validate262.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate262.errors = vErrors;
return errors === 0;
}
validate262.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate247(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate247.evaluated;
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
if(!(validate248(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate248.errors : vErrors.concat(validate248.errors);
errors = vErrors.length;
}
var _valid0 = _errs1 === errors;
if(_valid0){
valid0 = true;
passing0 = 0;
var props0 = true;
}
const _errs2 = errors;
if(!(validate250(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate250.errors : vErrors.concat(validate250.errors);
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
if(!(validate254(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate254.errors : vErrors.concat(validate254.errors);
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
if(!(validate257(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate257.errors : vErrors.concat(validate257.errors);
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
if(!(validate259(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate259.errors : vErrors.concat(validate259.errors);
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
if(!(validate262(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate262.errors : vErrors.concat(validate262.errors);
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
const err0 = {instancePath,schemaPath:"#/oneOf",keyword:"oneOf",params:{passingSchemas: passing0},message:"must match exactly one schema in oneOf"};
if(vErrors === null){
vErrors = [err0];
}
else {
vErrors.push(err0);
}
errors++;
validate247.errors = vErrors;
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
validate247.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate247.evaluated = {"dynamicProps":true,"dynamicItems":false};


function validate246(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate246.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate247(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate247.errors : vErrors.concat(validate247.errors);
errors = vErrors.length;
}
else {
var props0 = validate247.evaluated.props;
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
validate246.errors = vErrors;
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
validate246.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate246.evaluated = {"dynamicProps":true,"dynamicItems":false};


function validate239(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate239.evaluated;
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
validate239.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((((key0 === "field") || (key0 === "origin")) || (key0 === "availability")) || (key0 === "value"))){
validate239.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.field !== undefined){
const _errs2 = errors;
if(!(validate240(data.field, {instancePath:instancePath+"/field",parentData:data,parentDataProperty:"field",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate240.errors : vErrors.concat(validate240.errors);
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
if(!(validate242(data.origin, {instancePath:instancePath+"/origin",parentData:data,parentDataProperty:"origin",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate242.errors : vErrors.concat(validate242.errors);
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
if(!(validate244(data.availability, {instancePath:instancePath+"/availability",parentData:data,parentDataProperty:"availability",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate244.errors : vErrors.concat(validate244.errors);
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
if(!(validate246(data.value, {instancePath:instancePath+"/value",parentData:data,parentDataProperty:"value",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate246.errors : vErrors.concat(validate246.errors);
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
validate239.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate239.errors = vErrors;
return errors === 0;
}
validate239.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate238(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate238.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate239(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate239.errors : vErrors.concat(validate239.errors);
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
validate238.errors = vErrors;
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
validate238.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate238.evaluated = {"dynamicProps":true,"dynamicItems":false};


function validate237(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate237.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(Array.isArray(data)){
if(data.length > 16){
validate237.errors = [{instancePath,schemaPath:"#/maxItems",keyword:"maxItems",params:{limit: 16},message:"must NOT have more than 16 items"}];
return false;
}
else {
if(data.length < 16){
validate237.errors = [{instancePath,schemaPath:"#/minItems",keyword:"minItems",params:{limit: 16},message:"must NOT have fewer than 16 items"}];
return false;
}
else {
var valid0 = true;
const len0 = data.length;
for(let i0=0; i0<len0; i0++){
const _errs1 = errors;
if(!(validate238(data[i0], {instancePath:instancePath+"/" + i0,parentData:data,parentDataProperty:i0,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate238.errors : vErrors.concat(validate238.errors);
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
validate237.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "array"},message:"must be array"}];
return false;
}
}
validate237.errors = vErrors;
return errors === 0;
}
validate237.evaluated = {"items":true,"dynamicProps":false,"dynamicItems":false};

const schema84 = {"type":"array","minItems":4,"maxItems":4,"items":{"$ref":"https://transit.invalid/generated-validator/64"}};
const schema85 = {"anyOf":[{"$ref":"https://transit.invalid/generated-validator/63"},{"type":"null"}]};
const schema86 = {"type":"object","additionalProperties":false,"properties":{"kind":{"$ref":"https://transit.invalid/generated-validator/62"},"target":{"$ref":"https://transit.invalid/generated-validator/42"}},"required":["kind","target"]};
const schema87 = {"type":"string","enum":["correct_input","inspect_status","resume_exact","cancel_wait","cancel_mutation","refresh","recompile","retry_read","inspect_scope","reconcile_effect","contact_operator"]};

function validate273(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate273.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate273.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
if(!(((((((((((data === "correct_input") || (data === "inspect_status")) || (data === "resume_exact")) || (data === "cancel_wait")) || (data === "cancel_mutation")) || (data === "refresh")) || (data === "recompile")) || (data === "retry_read")) || (data === "inspect_scope")) || (data === "reconcile_effect")) || (data === "contact_operator"))){
validate273.errors = [{instancePath,schemaPath:"#/enum",keyword:"enum",params:{allowedValues: schema87.enum},message:"must be equal to one of the allowed values"}];
return false;
}
validate273.errors = vErrors;
return errors === 0;
}
validate273.evaluated = {"dynamicProps":false,"dynamicItems":false};


function validate272(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate272.evaluated;
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
validate272.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "kind") || (key0 === "target"))){
validate272.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.kind !== undefined){
const _errs2 = errors;
if(!(validate273(data.kind, {instancePath:instancePath+"/kind",parentData:data,parentDataProperty:"kind",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate273.errors : vErrors.concat(validate273.errors);
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
if(!(validate211(data.target, {instancePath:instancePath+"/target",parentData:data,parentDataProperty:"target",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate211.errors : vErrors.concat(validate211.errors);
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
validate272.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate272.errors = vErrors;
return errors === 0;
}
validate272.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate271(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate271.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate272(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate272.errors : vErrors.concat(validate272.errors);
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
validate271.errors = vErrors;
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
validate271.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate271.evaluated = {"dynamicProps":true,"dynamicItems":false};


function validate270(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate270.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(Array.isArray(data)){
if(data.length > 4){
validate270.errors = [{instancePath,schemaPath:"#/maxItems",keyword:"maxItems",params:{limit: 4},message:"must NOT have more than 4 items"}];
return false;
}
else {
if(data.length < 4){
validate270.errors = [{instancePath,schemaPath:"#/minItems",keyword:"minItems",params:{limit: 4},message:"must NOT have fewer than 4 items"}];
return false;
}
else {
var valid0 = true;
const len0 = data.length;
for(let i0=0; i0<len0; i0++){
const _errs1 = errors;
if(!(validate271(data[i0], {instancePath:instancePath+"/" + i0,parentData:data,parentDataProperty:i0,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate271.errors : vErrors.concat(validate271.errors);
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
validate270.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "array"},message:"must be array"}];
return false;
}
}
validate270.errors = vErrors;
return errors === 0;
}
validate270.evaluated = {"items":true,"dynamicProps":false,"dynamicItems":false};


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
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((((((((((((((data.version === undefined) && (missing0 = "version")) || ((data.definition === undefined) && (missing0 = "definition"))) || ((data.code === undefined) && (missing0 = "code"))) || ((data.category === undefined) && (missing0 = "category"))) || ((data.stage === undefined) && (missing0 = "stage"))) || ((data.outcome === undefined) && (missing0 = "outcome"))) || ((data.evidence === undefined) && (missing0 = "evidence"))) || ((data.message === undefined) && (missing0 = "message"))) || ((data.cause === undefined) && (missing0 = "cause"))) || ((data.identity === undefined) && (missing0 = "identity"))) || ((data.location === undefined) && (missing0 = "location"))) || ((data.facts === undefined) && (missing0 = "facts"))) || ((data.actions === undefined) && (missing0 = "actions"))){
validate198.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(func1.call(schema53.properties, key0))){
validate198.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.version !== undefined){
const _errs2 = errors;
if(1 !== data.version){
validate198.errors = [{instancePath:instancePath+"/version",schemaPath:"#/properties/version/const",keyword:"const",params:{allowedValue: 1},message:"must be equal to constant"}];
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
if(!(validate199(data.definition, {instancePath:instancePath+"/definition",parentData:data,parentDataProperty:"definition",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate199.errors : vErrors.concat(validate199.errors);
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
if(func4(data2) > 96){
validate198.errors = [{instancePath:instancePath+"/code",schemaPath:"#/properties/code/maxLength",keyword:"maxLength",params:{limit: 96},message:"must NOT have more than 96 characters"}];
return false;
}
}
else {
validate198.errors = [{instancePath:instancePath+"/code",schemaPath:"#/properties/code/type",keyword:"type",params:{type: "string"},message:"must be string"}];
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
if(!(validate201(data.category, {instancePath:instancePath+"/category",parentData:data,parentDataProperty:"category",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate201.errors : vErrors.concat(validate201.errors);
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
if(!(validate203(data.stage, {instancePath:instancePath+"/stage",parentData:data,parentDataProperty:"stage",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate203.errors : vErrors.concat(validate203.errors);
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
if(!(validate205(data.outcome, {instancePath:instancePath+"/outcome",parentData:data,parentDataProperty:"outcome",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate205.errors : vErrors.concat(validate205.errors);
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
if(!(validate207(data.evidence, {instancePath:instancePath+"/evidence",parentData:data,parentDataProperty:"evidence",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate207.errors : vErrors.concat(validate207.errors);
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
if(func4(data7) > 384){
validate198.errors = [{instancePath:instancePath+"/message",schemaPath:"#/properties/message/maxLength",keyword:"maxLength",params:{limit: 384},message:"must NOT have more than 384 characters"}];
return false;
}
}
else {
validate198.errors = [{instancePath:instancePath+"/message",schemaPath:"#/properties/message/type",keyword:"type",params:{type: "string"},message:"must be string"}];
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
if(!(validate209(data.cause, {instancePath:instancePath+"/cause",parentData:data,parentDataProperty:"cause",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate209.errors : vErrors.concat(validate209.errors);
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
if(!(validate211(data.identity, {instancePath:instancePath+"/identity",parentData:data,parentDataProperty:"identity",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate211.errors : vErrors.concat(validate211.errors);
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
if(!(validate224(data.location, {instancePath:instancePath+"/location",parentData:data,parentDataProperty:"location",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate224.errors : vErrors.concat(validate224.errors);
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
if(!(validate237(data.facts, {instancePath:instancePath+"/facts",parentData:data,parentDataProperty:"facts",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate237.errors : vErrors.concat(validate237.errors);
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
if(!(validate270(data.actions, {instancePath:instancePath+"/actions",parentData:data,parentDataProperty:"actions",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate270.errors : vErrors.concat(validate270.errors);
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
validate198.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate198.errors = vErrors;
return errors === 0;
}
validate198.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate197(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate197.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate198(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate198.errors : vErrors.concat(validate198.errors);
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
validate197.errors = vErrors;
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
validate197.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate197.evaluated = {"dynamicProps":true,"dynamicItems":false};


function validate52(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate52.evaluated;
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
validate52.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "observation") || (key0 === "edges")) || (key0 === "effect_diagnostics"))){
validate52.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
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
validate52.errors = [{instancePath:instancePath+"/observation",schemaPath:"#/properties/observation/required",keyword:"required",params:{missingProperty: missing1},message:"must have required property '"+missing1+"'"}];
return false;
}
else {
const _errs4 = errors;
for(const key1 in data0){
if(!(func1.call(schema19.properties.observation.properties, key1))){
validate52.errors = [{instancePath:instancePath+"/observation",schemaPath:"#/properties/observation/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key1},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs4 === errors){
if(data0.version !== undefined){
const _errs5 = errors;
if(!(validate53(data0.version, {instancePath:instancePath+"/observation/version",parentData:data0,parentDataProperty:"version",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate53.errors : vErrors.concat(validate53.errors);
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
if(!(validate55(data0.realm, {instancePath:instancePath+"/observation/realm",parentData:data0,parentDataProperty:"realm",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate55.errors : vErrors.concat(validate55.errors);
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
validate52.errors = [{instancePath:instancePath+"/observation/resource",schemaPath:"#/properties/observation/properties/resource/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
if(!(((((((data3 === "processes") || (data3 === "process")) || (data3 === "mailbox")) || (data3 === "outbox")) || (data3 === "effects")) || (data3 === "payloads")) || (data3 === "history"))){
validate52.errors = [{instancePath:instancePath+"/observation/resource",schemaPath:"#/properties/observation/properties/resource/enum",keyword:"enum",params:{allowedValues: schema19.properties.observation.properties.resource.enum},message:"must be equal to one of the allowed values"}];
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
if(!(validate57(data0.pid, {instancePath:instancePath+"/observation/pid",parentData:data0,parentDataProperty:"pid",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate57.errors : vErrors.concat(validate57.errors);
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
if(!(validate60(data0.cut, {instancePath:instancePath+"/observation/cut",parentData:data0,parentDataProperty:"cut",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate60.errors : vErrors.concat(validate60.errors);
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
if(!(validate65(data0.reader, {instancePath:instancePath+"/observation/reader",parentData:data0,parentDataProperty:"reader",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate65.errors : vErrors.concat(validate65.errors);
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
if(!(validate57(data0.next, {instancePath:instancePath+"/observation/next",parentData:data0,parentDataProperty:"next",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate57.errors : vErrors.concat(validate57.errors);
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
validate52.errors = [{instancePath:instancePath+"/observation/complete",schemaPath:"#/properties/observation/properties/complete/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"}];
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
validate52.errors = [{instancePath:instancePath+"/observation/history",schemaPath:"#/properties/observation/properties/history/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
if(!((data9 === "retained") || (data9 === "prefix_reclaimed"))){
validate52.errors = [{instancePath:instancePath+"/observation/history",schemaPath:"#/properties/observation/properties/history/enum",keyword:"enum",params:{allowedValues: schema19.properties.observation.properties.history.enum},message:"must be equal to one of the allowed values"}];
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
if(!(validate57(data0.last_collection, {instancePath:instancePath+"/observation/last_collection",parentData:data0,parentDataProperty:"last_collection",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate57.errors : vErrors.concat(validate57.errors);
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
if(!(validate67(data0.scanned, {instancePath:instancePath+"/observation/scanned",parentData:data0,parentDataProperty:"scanned",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate67.errors : vErrors.concat(validate67.errors);
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
if(!(validate75(data0.processes, {instancePath:instancePath+"/observation/processes",parentData:data0,parentDataProperty:"processes",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate75.errors : vErrors.concat(validate75.errors);
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
validate52.errors = [{instancePath:instancePath+"/observation/events",schemaPath:"#/properties/observation/properties/events/maxItems",keyword:"maxItems",params:{limit: 8},message:"must NOT have more than 8 items"}];
return false;
}
else {
if(data13.length < 8){
validate52.errors = [{instancePath:instancePath+"/observation/events",schemaPath:"#/properties/observation/properties/events/minItems",keyword:"minItems",params:{limit: 8},message:"must NOT have fewer than 8 items"}];
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
const err0 = {instancePath:instancePath+"/observation/events/" + i0,schemaPath:"#/properties/observation/properties/events/items/anyOf/0/required",keyword:"required",params:{missingProperty: missing2},message:"must have required property '"+missing2+"'"};
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
if(!(func1.call(schema19.properties.observation.properties.events.items.anyOf[0].properties, key2))){
const err1 = {instancePath:instancePath+"/observation/events/" + i0,schemaPath:"#/properties/observation/properties/events/items/anyOf/0/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key2},message:"must NOT have additional properties"};
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
if(!(validate55(data14.position, {instancePath:instancePath+"/observation/events/" + i0+"/position",parentData:data14,parentDataProperty:"position",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate55.errors : vErrors.concat(validate55.errors);
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
if(!(validate55(data14.pid, {instancePath:instancePath+"/observation/events/" + i0+"/pid",parentData:data14,parentDataProperty:"pid",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate55.errors : vErrors.concat(validate55.errors);
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
const err2 = {instancePath:instancePath+"/observation/events/" + i0+"/kind",schemaPath:"#/properties/observation/properties/events/items/anyOf/0/properties/kind/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err2];
}
else {
vErrors.push(err2);
}
errors++;
}
if(!(((((((((((((((((((((((((((((((((((((((((data17 === "grant") || (data17 === "revoke")) || (data17 === "spawn")) || (data17 === "own")) || (data17 === "retry")) || (data17 === "send")) || (data17 === "begin_turn")) || (data17 === "turn")) || (data17 === "terminate")) || (data17 === "expire")) || (data17 === "create_resource")) || (data17 === "grant_resource")) || (data17 === "associate")) || (data17 === "open_view")) || (data17 === "close_view")) || (data17 === "retire_resource")) || (data17 === "expire_resource")) || (data17 === "reclaim_resource")) || (data17 === "deliver")) || (data17 === "dispatch")) || (data17 === "observe")) || (data17 === "close_effect")) || (data17 === "cancel_effect")) || (data17 === "checkpoint")) || (data17 === "turn_with_versions")) || (data17 === "rotate_worker")) || (data17 === "create_principal")) || (data17 === "runtime_intent")) || (data17 === "runtime_observe")) || (data17 === "runtime_upgrade")) || (data17 === "activate")) || (data17 === "create")) || (data17 === "initialize")) || (data17 === "suspend")) || (data17 === "resume")) || (data17 === "expire_suspension")) || (data17 === "declare_payload")) || (data17 === "payload_ready")) || (data17 === "retire_payload")) || (data17 === "payload_deleted")) || (data17 === "collect"))){
const err3 = {instancePath:instancePath+"/observation/events/" + i0+"/kind",schemaPath:"#/properties/observation/properties/events/items/anyOf/0/properties/kind/enum",keyword:"enum",params:{allowedValues: schema19.properties.observation.properties.events.items.anyOf[0].properties.kind.enum},message:"must be equal to one of the allowed values"};
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
if(!(validate55(data14.policy_revision, {instancePath:instancePath+"/observation/events/" + i0+"/policy_revision",parentData:data14,parentDataProperty:"policy_revision",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate55.errors : vErrors.concat(validate55.errors);
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
if(!(validate57(data14.input, {instancePath:instancePath+"/observation/events/" + i0+"/input",parentData:data14,parentDataProperty:"input",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate57.errors : vErrors.concat(validate57.errors);
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
if(!(validate57(data14.effect, {instancePath:instancePath+"/observation/events/" + i0+"/effect",parentData:data14,parentDataProperty:"effect",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate57.errors : vErrors.concat(validate57.errors);
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
if(!(validate57(data14.output, {instancePath:instancePath+"/observation/events/" + i0+"/output",parentData:data14,parentDataProperty:"output",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate57.errors : vErrors.concat(validate57.errors);
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
if(!(validate133(data14.value, {instancePath:instancePath+"/observation/events/" + i0+"/value",parentData:data14,parentDataProperty:"value",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate133.errors : vErrors.concat(validate133.errors);
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
const err4 = {instancePath:instancePath+"/observation/events/" + i0+"/failed",schemaPath:"#/properties/observation/properties/events/items/anyOf/0/properties/failed/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"};
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
if(!(validate57(data14.generation, {instancePath:instancePath+"/observation/events/" + i0+"/generation",parentData:data14,parentDataProperty:"generation",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate57.errors : vErrors.concat(validate57.errors);
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
const err5 = {instancePath:instancePath+"/observation/events/" + i0+"/mailbox_status",schemaPath:"#/properties/observation/properties/events/items/anyOf/0/properties/mailbox_status/anyOf/0/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err5];
}
else {
vErrors.push(err5);
}
errors++;
}
if(!(((data25 === "pending") || (data25 === "consumed")) || (data25 === "cancelled"))){
const err6 = {instancePath:instancePath+"/observation/events/" + i0+"/mailbox_status",schemaPath:"#/properties/observation/properties/events/items/anyOf/0/properties/mailbox_status/anyOf/0/enum",keyword:"enum",params:{allowedValues: schema19.properties.observation.properties.events.items.anyOf[0].properties.mailbox_status.anyOf[0].enum},message:"must be equal to one of the allowed values"};
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
const err7 = {instancePath:instancePath+"/observation/events/" + i0+"/mailbox_status",schemaPath:"#/properties/observation/properties/events/items/anyOf/0/properties/mailbox_status/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
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
const err8 = {instancePath:instancePath+"/observation/events/" + i0+"/mailbox_status",schemaPath:"#/properties/observation/properties/events/items/anyOf/0/properties/mailbox_status/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
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
const err9 = {instancePath:instancePath+"/observation/events/" + i0+"/admitted",schemaPath:"#/properties/observation/properties/events/items/anyOf/0/properties/admitted/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"};
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
if(!(validate57(data14.unix_ms, {instancePath:instancePath+"/observation/events/" + i0+"/unix_ms",parentData:data14,parentDataProperty:"unix_ms",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate57.errors : vErrors.concat(validate57.errors);
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
if(!(validate53(data28, {instancePath:instancePath+"/observation/events/" + i0+"/clock_error_ms",parentData:data14,parentDataProperty:"clock_error_ms",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate53.errors : vErrors.concat(validate53.errors);
errors = vErrors.length;
}
var _valid2 = _errs50 === errors;
valid6 = valid6 || _valid2;
const _errs51 = errors;
if(data28 !== null){
const err10 = {instancePath:instancePath+"/observation/events/" + i0+"/clock_error_ms",schemaPath:"#/properties/observation/properties/events/items/anyOf/0/properties/clock_error_ms/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
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
const err11 = {instancePath:instancePath+"/observation/events/" + i0+"/clock_error_ms",schemaPath:"#/properties/observation/properties/events/items/anyOf/0/properties/clock_error_ms/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
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
const err12 = {instancePath:instancePath+"/observation/events/" + i0,schemaPath:"#/properties/observation/properties/events/items/anyOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err13 = {instancePath:instancePath+"/observation/events/" + i0,schemaPath:"#/properties/observation/properties/events/items/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
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
const err14 = {instancePath:instancePath+"/observation/events/" + i0,schemaPath:"#/properties/observation/properties/events/items/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err14];
}
else {
vErrors.push(err14);
}
errors++;
validate52.errors = vErrors;
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
validate52.errors = [{instancePath:instancePath+"/observation/events",schemaPath:"#/properties/observation/properties/events/type",keyword:"type",params:{type: "array"},message:"must be array"}];
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
validate52.errors = [{instancePath:instancePath+"/observation/outbox",schemaPath:"#/properties/observation/properties/outbox/maxItems",keyword:"maxItems",params:{limit: 8},message:"must NOT have more than 8 items"}];
return false;
}
else {
if(data29.length < 8){
validate52.errors = [{instancePath:instancePath+"/observation/outbox",schemaPath:"#/properties/observation/properties/outbox/minItems",keyword:"minItems",params:{limit: 8},message:"must NOT have fewer than 8 items"}];
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
const err15 = {instancePath:instancePath+"/observation/outbox/" + i1,schemaPath:"#/properties/observation/properties/outbox/items/anyOf/0/required",keyword:"required",params:{missingProperty: missing3},message:"must have required property '"+missing3+"'"};
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
if(!(func1.call(schema19.properties.observation.properties.outbox.items.anyOf[0].properties, key3))){
const err16 = {instancePath:instancePath+"/observation/outbox/" + i1,schemaPath:"#/properties/observation/properties/outbox/items/anyOf/0/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key3},message:"must NOT have additional properties"};
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
if(!(validate55(data30.id, {instancePath:instancePath+"/observation/outbox/" + i1+"/id",parentData:data30,parentDataProperty:"id",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate55.errors : vErrors.concat(validate55.errors);
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
if(!(validate55(data30.source, {instancePath:instancePath+"/observation/outbox/" + i1+"/source",parentData:data30,parentDataProperty:"source",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate55.errors : vErrors.concat(validate55.errors);
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
if(!(validate55(data30.turn, {instancePath:instancePath+"/observation/outbox/" + i1+"/turn",parentData:data30,parentDataProperty:"turn",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate55.errors : vErrors.concat(validate55.errors);
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
if(!(validate102(data30.index, {instancePath:instancePath+"/observation/outbox/" + i1+"/index",parentData:data30,parentDataProperty:"index",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate102.errors : vErrors.concat(validate102.errors);
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
if(!(validate55(data30.destination, {instancePath:instancePath+"/observation/outbox/" + i1+"/destination",parentData:data30,parentDataProperty:"destination",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate55.errors : vErrors.concat(validate55.errors);
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
if(!(validate134(data30.value, {instancePath:instancePath+"/observation/outbox/" + i1+"/value",parentData:data30,parentDataProperty:"value",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate134.errors : vErrors.concat(validate134.errors);
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
const err17 = {instancePath:instancePath+"/observation/outbox/" + i1+"/phase",schemaPath:"#/properties/observation/properties/outbox/items/anyOf/0/properties/phase/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err17];
}
else {
vErrors.push(err17);
}
errors++;
}
if(!((((((data37 === "pending") || (data37 === "delivered")) || (data37 === "denied")) || (data37 === "expired")) || (data37 === "retired")) || (data37 === "cancelled"))){
const err18 = {instancePath:instancePath+"/observation/outbox/" + i1+"/phase",schemaPath:"#/properties/observation/properties/outbox/items/anyOf/0/properties/phase/enum",keyword:"enum",params:{allowedValues: schema19.properties.observation.properties.outbox.items.anyOf[0].properties.phase.enum},message:"must be equal to one of the allowed values"};
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
if(!(validate57(data30.resolved_at, {instancePath:instancePath+"/observation/outbox/" + i1+"/resolved_at",parentData:data30,parentDataProperty:"resolved_at",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate57.errors : vErrors.concat(validate57.errors);
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
if(!(validate57(data30.courier, {instancePath:instancePath+"/observation/outbox/" + i1+"/courier",parentData:data30,parentDataProperty:"courier",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate57.errors : vErrors.concat(validate57.errors);
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
if(!(validate57(data30.policy_revision, {instancePath:instancePath+"/observation/outbox/" + i1+"/policy_revision",parentData:data30,parentDataProperty:"policy_revision",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate57.errors : vErrors.concat(validate57.errors);
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
const err19 = {instancePath:instancePath+"/observation/outbox/" + i1,schemaPath:"#/properties/observation/properties/outbox/items/anyOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err20 = {instancePath:instancePath+"/observation/outbox/" + i1,schemaPath:"#/properties/observation/properties/outbox/items/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
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
const err21 = {instancePath:instancePath+"/observation/outbox/" + i1,schemaPath:"#/properties/observation/properties/outbox/items/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err21];
}
else {
vErrors.push(err21);
}
errors++;
validate52.errors = vErrors;
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
validate52.errors = [{instancePath:instancePath+"/observation/outbox",schemaPath:"#/properties/observation/properties/outbox/type",keyword:"type",params:{type: "array"},message:"must be array"}];
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
validate52.errors = [{instancePath:instancePath+"/observation/effects",schemaPath:"#/properties/observation/properties/effects/maxItems",keyword:"maxItems",params:{limit: 8},message:"must NOT have more than 8 items"}];
return false;
}
else {
if(data41.length < 8){
validate52.errors = [{instancePath:instancePath+"/observation/effects",schemaPath:"#/properties/observation/properties/effects/minItems",keyword:"minItems",params:{limit: 8},message:"must NOT have fewer than 8 items"}];
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
const err22 = {instancePath:instancePath+"/observation/effects/" + i2,schemaPath:"#/properties/observation/properties/effects/items/anyOf/0/required",keyword:"required",params:{missingProperty: missing4},message:"must have required property '"+missing4+"'"};
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
if(!(func1.call(schema19.properties.observation.properties.effects.items.anyOf[0].properties, key4))){
const err23 = {instancePath:instancePath+"/observation/effects/" + i2,schemaPath:"#/properties/observation/properties/effects/items/anyOf/0/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key4},message:"must NOT have additional properties"};
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
if(!(validate55(data42.id, {instancePath:instancePath+"/observation/effects/" + i2+"/id",parentData:data42,parentDataProperty:"id",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate55.errors : vErrors.concat(validate55.errors);
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
if(!(validate55(data42.pid, {instancePath:instancePath+"/observation/effects/" + i2+"/pid",parentData:data42,parentDataProperty:"pid",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate55.errors : vErrors.concat(validate55.errors);
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
if(!(validate134(data42.payload, {instancePath:instancePath+"/observation/effects/" + i2+"/payload",parentData:data42,parentDataProperty:"payload",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate134.errors : vErrors.concat(validate134.errors);
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
const err24 = {instancePath:instancePath+"/observation/effects/" + i2+"/phase",schemaPath:"#/properties/observation/properties/effects/items/anyOf/0/properties/phase/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err24];
}
else {
vErrors.push(err24);
}
errors++;
}
if(!((((((data46 === "pending") || (data46 === "authorized")) || (data46 === "unknown")) || (data46 === "observed")) || (data46 === "cancelled")) || (data46 === "closed_unknown"))){
const err25 = {instancePath:instancePath+"/observation/effects/" + i2+"/phase",schemaPath:"#/properties/observation/properties/effects/items/anyOf/0/properties/phase/enum",keyword:"enum",params:{allowedValues: schema19.properties.observation.properties.effects.items.anyOf[0].properties.phase.enum},message:"must be equal to one of the allowed values"};
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
if(!(validate57(data42.attempt, {instancePath:instancePath+"/observation/effects/" + i2+"/attempt",parentData:data42,parentDataProperty:"attempt",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate57.errors : vErrors.concat(validate57.errors);
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
if(!(validate57(data42.executor, {instancePath:instancePath+"/observation/effects/" + i2+"/executor",parentData:data42,parentDataProperty:"executor",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate57.errors : vErrors.concat(validate57.errors);
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
if(!(validate57(data42.authorization_policy, {instancePath:instancePath+"/observation/effects/" + i2+"/authorization_policy",parentData:data42,parentDataProperty:"authorization_policy",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate57.errors : vErrors.concat(validate57.errors);
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
const err26 = {instancePath:instancePath+"/observation/effects/" + i2+"/last_observation",schemaPath:"#/properties/observation/properties/effects/items/anyOf/0/properties/last_observation/anyOf/0/required",keyword:"required",params:{missingProperty: missing5},message:"must have required property '"+missing5+"'"};
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
const err27 = {instancePath:instancePath+"/observation/effects/" + i2+"/last_observation",schemaPath:"#/properties/observation/properties/effects/items/anyOf/0/properties/last_observation/anyOf/0/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key5},message:"must NOT have additional properties"};
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
if(!(validate55(data50.input, {instancePath:instancePath+"/observation/effects/" + i2+"/last_observation/input",parentData:data50,parentDataProperty:"input",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate55.errors : vErrors.concat(validate55.errors);
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
if(!(validate55(data50.policy_revision, {instancePath:instancePath+"/observation/effects/" + i2+"/last_observation/policy_revision",parentData:data50,parentDataProperty:"policy_revision",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate55.errors : vErrors.concat(validate55.errors);
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
const err28 = {instancePath:instancePath+"/observation/effects/" + i2+"/last_observation",schemaPath:"#/properties/observation/properties/effects/items/anyOf/0/properties/last_observation/anyOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err29 = {instancePath:instancePath+"/observation/effects/" + i2+"/last_observation",schemaPath:"#/properties/observation/properties/effects/items/anyOf/0/properties/last_observation/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
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
const err30 = {instancePath:instancePath+"/observation/effects/" + i2+"/last_observation",schemaPath:"#/properties/observation/properties/effects/items/anyOf/0/properties/last_observation/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
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
const err31 = {instancePath:instancePath+"/observation/effects/" + i2+"/closure",schemaPath:"#/properties/observation/properties/effects/items/anyOf/0/properties/closure/anyOf/0/required",keyword:"required",params:{missingProperty: missing6},message:"must have required property '"+missing6+"'"};
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
const err32 = {instancePath:instancePath+"/observation/effects/" + i2+"/closure",schemaPath:"#/properties/observation/properties/effects/items/anyOf/0/properties/closure/anyOf/0/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key6},message:"must NOT have additional properties"};
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
const err33 = {instancePath:instancePath+"/observation/effects/" + i2+"/closure/reason",schemaPath:"#/properties/observation/properties/effects/items/anyOf/0/properties/closure/anyOf/0/properties/reason/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err33];
}
else {
vErrors.push(err33);
}
errors++;
}
if(!(((((data54 === "observed") || (data54 === "observation_budget")) || (data54 === "abandoned")) || (data54 === "deadline")) || (data54 === "unattempted_cancel"))){
const err34 = {instancePath:instancePath+"/observation/effects/" + i2+"/closure/reason",schemaPath:"#/properties/observation/properties/effects/items/anyOf/0/properties/closure/anyOf/0/properties/reason/enum",keyword:"enum",params:{allowedValues: schema19.properties.observation.properties.effects.items.anyOf[0].properties.closure.anyOf[0].properties.reason.enum},message:"must be equal to one of the allowed values"};
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
if(!(validate55(data53.principal, {instancePath:instancePath+"/observation/effects/" + i2+"/closure/principal",parentData:data53,parentDataProperty:"principal",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate55.errors : vErrors.concat(validate55.errors);
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
if(!(validate55(data53.policy_revision, {instancePath:instancePath+"/observation/effects/" + i2+"/closure/policy_revision",parentData:data53,parentDataProperty:"policy_revision",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate55.errors : vErrors.concat(validate55.errors);
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
if(!(validate57(data53.clock_lower_ms, {instancePath:instancePath+"/observation/effects/" + i2+"/closure/clock_lower_ms",parentData:data53,parentDataProperty:"clock_lower_ms",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate57.errors : vErrors.concat(validate57.errors);
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
const err35 = {instancePath:instancePath+"/observation/effects/" + i2+"/closure",schemaPath:"#/properties/observation/properties/effects/items/anyOf/0/properties/closure/anyOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err36 = {instancePath:instancePath+"/observation/effects/" + i2+"/closure",schemaPath:"#/properties/observation/properties/effects/items/anyOf/0/properties/closure/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
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
const err37 = {instancePath:instancePath+"/observation/effects/" + i2+"/closure",schemaPath:"#/properties/observation/properties/effects/items/anyOf/0/properties/closure/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
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
if(!(validate133(data42.result, {instancePath:instancePath+"/observation/effects/" + i2+"/result",parentData:data42,parentDataProperty:"result",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate133.errors : vErrors.concat(validate133.errors);
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
if(!(validate57(data42.closed_at, {instancePath:instancePath+"/observation/effects/" + i2+"/closed_at",parentData:data42,parentDataProperty:"closed_at",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate57.errors : vErrors.concat(validate57.errors);
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
if(!(validate57(data42.reconcile_before_ms, {instancePath:instancePath+"/observation/effects/" + i2+"/reconcile_before_ms",parentData:data42,parentDataProperty:"reconcile_before_ms",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate57.errors : vErrors.concat(validate57.errors);
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
if(!(validate67(data42.max_observations, {instancePath:instancePath+"/observation/effects/" + i2+"/max_observations",parentData:data42,parentDataProperty:"max_observations",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate67.errors : vErrors.concat(validate67.errors);
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
if(!(validate67(data42.observations, {instancePath:instancePath+"/observation/effects/" + i2+"/observations",parentData:data42,parentDataProperty:"observations",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate67.errors : vErrors.concat(validate67.errors);
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
const err38 = {instancePath:instancePath+"/observation/effects/" + i2,schemaPath:"#/properties/observation/properties/effects/items/anyOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err39 = {instancePath:instancePath+"/observation/effects/" + i2,schemaPath:"#/properties/observation/properties/effects/items/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
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
const err40 = {instancePath:instancePath+"/observation/effects/" + i2,schemaPath:"#/properties/observation/properties/effects/items/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err40];
}
else {
vErrors.push(err40);
}
errors++;
validate52.errors = vErrors;
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
validate52.errors = [{instancePath:instancePath+"/observation/effects",schemaPath:"#/properties/observation/properties/effects/type",keyword:"type",params:{type: "array"},message:"must be array"}];
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
validate52.errors = [{instancePath:instancePath+"/observation/payloads",schemaPath:"#/properties/observation/properties/payloads/maxItems",keyword:"maxItems",params:{limit: 8},message:"must NOT have more than 8 items"}];
return false;
}
else {
if(data63.length < 8){
validate52.errors = [{instancePath:instancePath+"/observation/payloads",schemaPath:"#/properties/observation/properties/payloads/minItems",keyword:"minItems",params:{limit: 8},message:"must NOT have fewer than 8 items"}];
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
const err41 = {instancePath:instancePath+"/observation/payloads/" + i3,schemaPath:"#/properties/observation/properties/payloads/items/anyOf/0/required",keyword:"required",params:{missingProperty: missing7},message:"must have required property '"+missing7+"'"};
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
if(!(func1.call(schema19.properties.observation.properties.payloads.items.anyOf[0].properties, key7))){
const err42 = {instancePath:instancePath+"/observation/payloads/" + i3,schemaPath:"#/properties/observation/properties/payloads/items/anyOf/0/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key7},message:"must NOT have additional properties"};
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
if(!(validate55(data64.id, {instancePath:instancePath+"/observation/payloads/" + i3+"/id",parentData:data64,parentDataProperty:"id",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate55.errors : vErrors.concat(validate55.errors);
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
if(!(validate55(data64.pid, {instancePath:instancePath+"/observation/payloads/" + i3+"/pid",parentData:data64,parentDataProperty:"pid",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate55.errors : vErrors.concat(validate55.errors);
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
if(!(validate55(data64.publisher, {instancePath:instancePath+"/observation/payloads/" + i3+"/publisher",parentData:data64,parentDataProperty:"publisher",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate55.errors : vErrors.concat(validate55.errors);
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
if(!(validate105(data64.sha256, {instancePath:instancePath+"/observation/payloads/" + i3+"/sha256",parentData:data64,parentDataProperty:"sha256",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate105.errors : vErrors.concat(validate105.errors);
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
if(!(validate53(data64.bytes, {instancePath:instancePath+"/observation/payloads/" + i3+"/bytes",parentData:data64,parentDataProperty:"bytes",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate53.errors : vErrors.concat(validate53.errors);
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
const err43 = {instancePath:instancePath+"/observation/payloads/" + i3+"/allow_delete",schemaPath:"#/properties/observation/properties/payloads/items/anyOf/0/properties/allow_delete/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"};
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
const err44 = {instancePath:instancePath+"/observation/payloads/" + i3+"/phase",schemaPath:"#/properties/observation/properties/payloads/items/anyOf/0/properties/phase/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err44];
}
else {
vErrors.push(err44);
}
errors++;
}
if(!((((data71 === "creating") || (data71 === "ready")) || (data71 === "retiring")) || (data71 === "deleted"))){
const err45 = {instancePath:instancePath+"/observation/payloads/" + i3+"/phase",schemaPath:"#/properties/observation/properties/payloads/items/anyOf/0/properties/phase/enum",keyword:"enum",params:{allowedValues: schema19.properties.observation.properties.payloads.items.anyOf[0].properties.phase.enum},message:"must be equal to one of the allowed values"};
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
if(!(validate57(data64.retired_at, {instancePath:instancePath+"/observation/payloads/" + i3+"/retired_at",parentData:data64,parentDataProperty:"retired_at",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate57.errors : vErrors.concat(validate57.errors);
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
if(!(validate57(data64.deleted_at, {instancePath:instancePath+"/observation/payloads/" + i3+"/deleted_at",parentData:data64,parentDataProperty:"deleted_at",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate57.errors : vErrors.concat(validate57.errors);
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
const err46 = {instancePath:instancePath+"/observation/payloads/" + i3,schemaPath:"#/properties/observation/properties/payloads/items/anyOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err47 = {instancePath:instancePath+"/observation/payloads/" + i3,schemaPath:"#/properties/observation/properties/payloads/items/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
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
const err48 = {instancePath:instancePath+"/observation/payloads/" + i3,schemaPath:"#/properties/observation/properties/payloads/items/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err48];
}
else {
vErrors.push(err48);
}
errors++;
validate52.errors = vErrors;
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
validate52.errors = [{instancePath:instancePath+"/observation/payloads",schemaPath:"#/properties/observation/properties/payloads/type",keyword:"type",params:{type: "array"},message:"must be array"}];
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
validate52.errors = [{instancePath:instancePath+"/observation",schemaPath:"#/properties/observation/type",keyword:"type",params:{type: "object"},message:"must be object"}];
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
validate52.errors = [{instancePath:instancePath+"/edges",schemaPath:"#/properties/edges/maxItems",keyword:"maxItems",params:{limit: 16},message:"must NOT have more than 16 items"}];
return false;
}
else {
if(data74.length < 16){
validate52.errors = [{instancePath:instancePath+"/edges",schemaPath:"#/properties/edges/minItems",keyword:"minItems",params:{limit: 16},message:"must NOT have fewer than 16 items"}];
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
const err49 = {instancePath:instancePath+"/edges/" + i4,schemaPath:"#/properties/edges/items/anyOf/0/required",keyword:"required",params:{missingProperty: missing8},message:"must have required property '"+missing8+"'"};
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
const err50 = {instancePath:instancePath+"/edges/" + i4,schemaPath:"#/properties/edges/items/anyOf/0/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key8},message:"must NOT have additional properties"};
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
if(!(validate186(data75.from, {instancePath:instancePath+"/edges/" + i4+"/from",parentData:data75,parentDataProperty:"from",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate186.errors : vErrors.concat(validate186.errors);
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
if(!(validate186(data75.to, {instancePath:instancePath+"/edges/" + i4+"/to",parentData:data75,parentDataProperty:"to",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate186.errors : vErrors.concat(validate186.errors);
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
const err51 = {instancePath:instancePath+"/edges/" + i4+"/relation",schemaPath:"#/properties/edges/items/anyOf/0/properties/relation/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err51];
}
else {
vErrors.push(err51);
}
errors++;
}
if(!(((((data78 === "input_to_turn") || (data78 === "turn_to_effect")) || (data78 === "turn_to_output")) || (data78 === "output_to_admission")) || (data78 === "effect_to_observation"))){
const err52 = {instancePath:instancePath+"/edges/" + i4+"/relation",schemaPath:"#/properties/edges/items/anyOf/0/properties/relation/enum",keyword:"enum",params:{allowedValues: schema19.properties.edges.items.anyOf[0].properties.relation.enum},message:"must be equal to one of the allowed values"};
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
if(!(validate194(data75.from_coverage, {instancePath:instancePath+"/edges/" + i4+"/from_coverage",parentData:data75,parentDataProperty:"from_coverage",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate194.errors : vErrors.concat(validate194.errors);
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
if(!(validate194(data75.to_coverage, {instancePath:instancePath+"/edges/" + i4+"/to_coverage",parentData:data75,parentDataProperty:"to_coverage",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate194.errors : vErrors.concat(validate194.errors);
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
const err53 = {instancePath:instancePath+"/edges/" + i4,schemaPath:"#/properties/edges/items/anyOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err54 = {instancePath:instancePath+"/edges/" + i4,schemaPath:"#/properties/edges/items/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
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
const err55 = {instancePath:instancePath+"/edges/" + i4,schemaPath:"#/properties/edges/items/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err55];
}
else {
vErrors.push(err55);
}
errors++;
validate52.errors = vErrors;
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
validate52.errors = [{instancePath:instancePath+"/edges",schemaPath:"#/properties/edges/type",keyword:"type",params:{type: "array"},message:"must be array"}];
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
validate52.errors = [{instancePath:instancePath+"/effect_diagnostics",schemaPath:"#/properties/effect_diagnostics/maxItems",keyword:"maxItems",params:{limit: 8},message:"must NOT have more than 8 items"}];
return false;
}
else {
if(data81.length < 8){
validate52.errors = [{instancePath:instancePath+"/effect_diagnostics",schemaPath:"#/properties/effect_diagnostics/minItems",keyword:"minItems",params:{limit: 8},message:"must NOT have fewer than 8 items"}];
return false;
}
else {
var valid23 = true;
const len5 = data81.length;
for(let i5=0; i5<len5; i5++){
const _errs155 = errors;
if(!(validate197(data81[i5], {instancePath:instancePath+"/effect_diagnostics/" + i5,parentData:data81,parentDataProperty:i5,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate197.errors : vErrors.concat(validate197.errors);
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
validate52.errors = [{instancePath:instancePath+"/effect_diagnostics",schemaPath:"#/properties/effect_diagnostics/type",keyword:"type",params:{type: "array"},message:"must be array"}];
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
validate52.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate52.errors = vErrors;
return errors === 0;
}
validate52.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

export const StateResponse = validate281;
const schema88 = {"type":"object","additionalProperties":false,"properties":{"observation":{"type":"object","additionalProperties":false,"properties":{"version":{"$ref":"https://transit.invalid/generated-validator/0"},"realm":{"$ref":"https://transit.invalid/generated-validator/1"},"principal_sequence":{"$ref":"https://transit.invalid/generated-validator/1"},"reader":{"$ref":"https://transit.invalid/generated-validator/5"},"kind":{"type":"string","enum":["resources","associations","entries"]},"cut":{"$ref":"https://transit.invalid/generated-validator/3"},"next":{"$ref":"https://transit.invalid/generated-validator/2"},"next_key":{"$ref":"https://transit.invalid/generated-validator/22"},"resources":{"$ref":"https://transit.invalid/generated-validator/71"},"associations":{"type":"array","minItems":8,"maxItems":8,"items":{"anyOf":[{"type":"object","additionalProperties":false,"properties":{"pid":{"$ref":"https://transit.invalid/generated-validator/1"},"name":{"$ref":"https://transit.invalid/generated-validator/21"},"resource":{"$ref":"https://transit.invalid/generated-validator/1"},"revision":{"$ref":"https://transit.invalid/generated-validator/1"},"required":{"type":"boolean"}},"required":["pid","name","resource","revision","required"]},{"type":"null"}]}},"entries":{"type":"array","minItems":8,"maxItems":8,"items":{"anyOf":[{"type":"object","additionalProperties":false,"properties":{"key":{"$ref":"https://transit.invalid/generated-validator/21"},"value":{"$ref":"https://transit.invalid/generated-validator/21"},"revision":{"$ref":"https://transit.invalid/generated-validator/1"}},"required":["key","value","revision"]},{"type":"null"}]}}},"required":["version","realm","principal_sequence","reader","kind","cut","next","next_key","resources","associations","entries"]},"framework":{"type":"array","minItems":8,"maxItems":8,"items":{"anyOf":[{"type":"object","additionalProperties":false,"properties":{"version":{"$ref":"https://transit.invalid/generated-validator/9"},"source":{"$ref":"https://transit.invalid/generated-validator/72"},"declaration":{"oneOf":[{"type":"object","additionalProperties":false,"required":["behavior"],"properties":{"behavior":{"type":"string","enum":["genserver"]}}},{"type":"object","additionalProperties":false,"required":["table"],"properties":{"table":{"type":"object","additionalProperties":false,"properties":{"id":{"$ref":"https://transit.invalid/generated-validator/0"},"schema_version":{"$ref":"https://transit.invalid/generated-validator/9"},"columns":{"type":"array","minItems":2,"maxItems":2,"items":{"type":"object","additionalProperties":false,"properties":{"name":{"$ref":"https://transit.invalid/generated-validator/21"},"data_type":{"$ref":"https://transit.invalid/generated-validator/73"},"nullable":{"type":"boolean"}},"required":["name","data_type","nullable"]}},"fingerprint":{"$ref":"https://transit.invalid/generated-validator/11"}},"required":["id","schema_version","columns","fingerprint"]}}},{"type":"object","additionalProperties":false,"required":["registry_scope"],"properties":{"registry_scope":{"type":"object","additionalProperties":false,"properties":{"id":{"$ref":"https://transit.invalid/generated-validator/0"}},"required":["id"]}}},{"type":"object","additionalProperties":false,"required":["registry_binding"],"properties":{"registry_binding":{"type":"object","additionalProperties":false,"properties":{"scope":{"$ref":"https://transit.invalid/generated-validator/0"},"name":{"$ref":"https://transit.invalid/generated-validator/21"},"revision":{"$ref":"https://transit.invalid/generated-validator/1"},"destination":{"$ref":"https://transit.invalid/generated-validator/2"}},"required":["scope","name","revision","destination"]}}},{"type":"object","additionalProperties":false,"required":["child"],"properties":{"child":{"type":"object","additionalProperties":false,"properties":{"pid":{"$ref":"https://transit.invalid/generated-validator/1"},"generation":{"$ref":"https://transit.invalid/generated-validator/1"},"phase":{"type":"string","enum":["watching","retry_wait","retry_requested","exhausted","retired","suspended","placement_unavailable","initializing"]},"attempts":{"$ref":"https://transit.invalid/generated-validator/9"},"limit":{"$ref":"https://transit.invalid/generated-validator/9"},"retry_at_ms":{"$ref":"https://transit.invalid/generated-validator/1"},"successor":{"$ref":"https://transit.invalid/generated-validator/2"}},"required":["pid","generation","phase","attempts","limit","retry_at_ms","successor"]}}},{"type":"object","additionalProperties":false,"required":["query"],"properties":{"query":{"type":"object","additionalProperties":false,"properties":{"id":{"$ref":"https://transit.invalid/generated-validator/1"},"correlation":{"$ref":"https://transit.invalid/generated-validator/21"},"destination":{"$ref":"https://transit.invalid/generated-validator/1"},"table":{"$ref":"https://transit.invalid/generated-validator/0"},"source_resource":{"$ref":"https://transit.invalid/generated-validator/1"},"source_revision":{"$ref":"https://transit.invalid/generated-validator/1"},"schema":{"$ref":"https://transit.invalid/generated-validator/11"},"bytes":{"$ref":"https://transit.invalid/generated-validator/1"},"rows":{"$ref":"https://transit.invalid/generated-validator/1"},"phase":{"$ref":"https://transit.invalid/generated-validator/74"},"direction":{"type":"string","enum":["outgoing","incoming"]}},"required":["id","correlation","destination","table","source_resource","source_revision","schema","bytes","rows","phase","direction"]}}},{"type":"object","additionalProperties":false,"required":["wait"],"properties":{"wait":{"type":"object","additionalProperties":false,"properties":{"correlation":{"$ref":"https://transit.invalid/generated-validator/21"},"target":{"$ref":"https://transit.invalid/generated-validator/1"},"phase":{"type":"string","enum":["waiting","replied","timed_out","cancelled"]},"deadline_ms":{"$ref":"https://transit.invalid/generated-validator/2"},"observer":{"$ref":"https://transit.invalid/generated-validator/2"},"resolution_input":{"$ref":"https://transit.invalid/generated-validator/1"}},"required":["correlation","target","phase","deadline_ms","observer","resolution_input"]}}}]}},"required":["version","source","declaration"]},{"type":"null"}]}}},"required":["observation","framework"]};
const schema89 = {"type":"array","minItems":8,"maxItems":8,"items":{"$ref":"https://transit.invalid/generated-validator/70"}};
const schema90 = {"anyOf":[{"$ref":"https://transit.invalid/generated-validator/69"},{"type":"null"}]};
const schema91 = {"type":"object","additionalProperties":false,"properties":{"id":{"$ref":"https://transit.invalid/generated-validator/1"},"writer":{"$ref":"https://transit.invalid/generated-validator/1"},"owner":{"$ref":"https://transit.invalid/generated-validator/2"},"revision":{"$ref":"https://transit.invalid/generated-validator/1"},"entries":{"$ref":"https://transit.invalid/generated-validator/1"},"history_ms":{"$ref":"https://transit.invalid/generated-validator/2"},"changed_ms":{"$ref":"https://transit.invalid/generated-validator/1"},"last_turn":{"$ref":"https://transit.invalid/generated-validator/2"},"deadline_ms":{"$ref":"https://transit.invalid/generated-validator/2"},"phase":{"$ref":"https://transit.invalid/generated-validator/68"},"retired_at":{"$ref":"https://transit.invalid/generated-validator/2"}},"required":["id","writer","owner","revision","entries","history_ms","changed_ms","last_turn","deadline_ms","phase","retired_at"]};
const schema92 = {"type":"string","enum":["active","retired","reclaimed"]};

function validate301(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate301.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate301.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
if(!(((data === "active") || (data === "retired")) || (data === "reclaimed"))){
validate301.errors = [{instancePath,schemaPath:"#/enum",keyword:"enum",params:{allowedValues: schema92.enum},message:"must be equal to one of the allowed values"}];
return false;
}
validate301.errors = vErrors;
return errors === 0;
}
validate301.evaluated = {"dynamicProps":false,"dynamicItems":false};


function validate291(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate291.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((((((((((((data.id === undefined) && (missing0 = "id")) || ((data.writer === undefined) && (missing0 = "writer"))) || ((data.owner === undefined) && (missing0 = "owner"))) || ((data.revision === undefined) && (missing0 = "revision"))) || ((data.entries === undefined) && (missing0 = "entries"))) || ((data.history_ms === undefined) && (missing0 = "history_ms"))) || ((data.changed_ms === undefined) && (missing0 = "changed_ms"))) || ((data.last_turn === undefined) && (missing0 = "last_turn"))) || ((data.deadline_ms === undefined) && (missing0 = "deadline_ms"))) || ((data.phase === undefined) && (missing0 = "phase"))) || ((data.retired_at === undefined) && (missing0 = "retired_at"))){
validate291.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(func1.call(schema91.properties, key0))){
validate291.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.id !== undefined){
const _errs2 = errors;
if(!(validate55(data.id, {instancePath:instancePath+"/id",parentData:data,parentDataProperty:"id",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate55.errors : vErrors.concat(validate55.errors);
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
if(!(validate55(data.writer, {instancePath:instancePath+"/writer",parentData:data,parentDataProperty:"writer",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate55.errors : vErrors.concat(validate55.errors);
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
if(!(validate57(data.owner, {instancePath:instancePath+"/owner",parentData:data,parentDataProperty:"owner",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate57.errors : vErrors.concat(validate57.errors);
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
if(!(validate55(data.revision, {instancePath:instancePath+"/revision",parentData:data,parentDataProperty:"revision",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate55.errors : vErrors.concat(validate55.errors);
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
if(!(validate55(data.entries, {instancePath:instancePath+"/entries",parentData:data,parentDataProperty:"entries",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate55.errors : vErrors.concat(validate55.errors);
errors = vErrors.length;
}
var valid0 = _errs6 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.history_ms !== undefined){
const _errs7 = errors;
if(!(validate57(data.history_ms, {instancePath:instancePath+"/history_ms",parentData:data,parentDataProperty:"history_ms",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate57.errors : vErrors.concat(validate57.errors);
errors = vErrors.length;
}
var valid0 = _errs7 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.changed_ms !== undefined){
const _errs8 = errors;
if(!(validate55(data.changed_ms, {instancePath:instancePath+"/changed_ms",parentData:data,parentDataProperty:"changed_ms",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate55.errors : vErrors.concat(validate55.errors);
errors = vErrors.length;
}
var valid0 = _errs8 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.last_turn !== undefined){
const _errs9 = errors;
if(!(validate57(data.last_turn, {instancePath:instancePath+"/last_turn",parentData:data,parentDataProperty:"last_turn",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate57.errors : vErrors.concat(validate57.errors);
errors = vErrors.length;
}
var valid0 = _errs9 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.deadline_ms !== undefined){
const _errs10 = errors;
if(!(validate57(data.deadline_ms, {instancePath:instancePath+"/deadline_ms",parentData:data,parentDataProperty:"deadline_ms",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate57.errors : vErrors.concat(validate57.errors);
errors = vErrors.length;
}
var valid0 = _errs10 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.phase !== undefined){
const _errs11 = errors;
if(!(validate301(data.phase, {instancePath:instancePath+"/phase",parentData:data,parentDataProperty:"phase",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate301.errors : vErrors.concat(validate301.errors);
errors = vErrors.length;
}
var valid0 = _errs11 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.retired_at !== undefined){
const _errs12 = errors;
if(!(validate57(data.retired_at, {instancePath:instancePath+"/retired_at",parentData:data,parentDataProperty:"retired_at",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate57.errors : vErrors.concat(validate57.errors);
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
validate291.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate291.errors = vErrors;
return errors === 0;
}
validate291.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate290(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate290.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate291(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate291.errors : vErrors.concat(validate291.errors);
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
validate290.errors = vErrors;
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
validate290.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate290.evaluated = {"dynamicProps":true,"dynamicItems":false};


function validate289(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate289.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(Array.isArray(data)){
if(data.length > 8){
validate289.errors = [{instancePath,schemaPath:"#/maxItems",keyword:"maxItems",params:{limit: 8},message:"must NOT have more than 8 items"}];
return false;
}
else {
if(data.length < 8){
validate289.errors = [{instancePath,schemaPath:"#/minItems",keyword:"minItems",params:{limit: 8},message:"must NOT have fewer than 8 items"}];
return false;
}
else {
var valid0 = true;
const len0 = data.length;
for(let i0=0; i0<len0; i0++){
const _errs1 = errors;
if(!(validate290(data[i0], {instancePath:instancePath+"/" + i0,parentData:data,parentDataProperty:i0,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate290.errors : vErrors.concat(validate290.errors);
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
validate289.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "array"},message:"must be array"}];
return false;
}
}
validate289.errors = vErrors;
return errors === 0;
}
validate289.evaluated = {"items":true,"dynamicProps":false,"dynamicItems":false};

const schema93 = {"type":"object","additionalProperties":false,"properties":{"realm":{"$ref":"https://transit.invalid/generated-validator/1"},"pid":{"$ref":"https://transit.invalid/generated-validator/1"},"resource":{"$ref":"https://transit.invalid/generated-validator/1"},"key":{"$ref":"https://transit.invalid/generated-validator/21"},"entry_revision":{"$ref":"https://transit.invalid/generated-validator/1"},"resource_revision":{"$ref":"https://transit.invalid/generated-validator/1"},"position":{"$ref":"https://transit.invalid/generated-validator/1"}},"required":["realm","pid","resource","key","entry_revision","resource_revision","position"]};

function validate315(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate315.evaluated;
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
validate315.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((((((key0 === "realm") || (key0 === "pid")) || (key0 === "resource")) || (key0 === "key")) || (key0 === "entry_revision")) || (key0 === "resource_revision")) || (key0 === "position"))){
validate315.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.realm !== undefined){
const _errs2 = errors;
if(!(validate55(data.realm, {instancePath:instancePath+"/realm",parentData:data,parentDataProperty:"realm",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate55.errors : vErrors.concat(validate55.errors);
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
if(!(validate55(data.pid, {instancePath:instancePath+"/pid",parentData:data,parentDataProperty:"pid",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate55.errors : vErrors.concat(validate55.errors);
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
if(!(validate55(data.resource, {instancePath:instancePath+"/resource",parentData:data,parentDataProperty:"resource",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate55.errors : vErrors.concat(validate55.errors);
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
if(!(validate134(data.key, {instancePath:instancePath+"/key",parentData:data,parentDataProperty:"key",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate134.errors : vErrors.concat(validate134.errors);
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
if(!(validate55(data.entry_revision, {instancePath:instancePath+"/entry_revision",parentData:data,parentDataProperty:"entry_revision",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate55.errors : vErrors.concat(validate55.errors);
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
if(!(validate55(data.resource_revision, {instancePath:instancePath+"/resource_revision",parentData:data,parentDataProperty:"resource_revision",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate55.errors : vErrors.concat(validate55.errors);
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
if(!(validate55(data.position, {instancePath:instancePath+"/position",parentData:data,parentDataProperty:"position",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate55.errors : vErrors.concat(validate55.errors);
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
validate315.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate315.errors = vErrors;
return errors === 0;
}
validate315.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema94 = {"type":"string","enum":["int64","boolean","utf8","binary"]};

function validate327(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate327.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate327.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
if(!((((data === "int64") || (data === "boolean")) || (data === "utf8")) || (data === "binary"))){
validate327.errors = [{instancePath,schemaPath:"#/enum",keyword:"enum",params:{allowedValues: schema94.enum},message:"must be equal to one of the allowed values"}];
return false;
}
validate327.errors = vErrors;
return errors === 0;
}
validate327.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema95 = {"type":"string","enum":["capturing","captured","published","acknowledged","cancelled","denied"]};

function validate350(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate350.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate350.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
if(!((((((data === "capturing") || (data === "captured")) || (data === "published")) || (data === "acknowledged")) || (data === "cancelled")) || (data === "denied"))){
validate350.errors = [{instancePath,schemaPath:"#/enum",keyword:"enum",params:{allowedValues: schema95.enum},message:"must be equal to one of the allowed values"}];
return false;
}
validate350.errors = vErrors;
return errors === 0;
}
validate350.evaluated = {"dynamicProps":false,"dynamicItems":false};


function validate281(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate281.evaluated;
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
validate281.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "observation") || (key0 === "framework"))){
validate281.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
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
validate281.errors = [{instancePath:instancePath+"/observation",schemaPath:"#/properties/observation/required",keyword:"required",params:{missingProperty: missing1},message:"must have required property '"+missing1+"'"}];
return false;
}
else {
const _errs4 = errors;
for(const key1 in data0){
if(!(func1.call(schema88.properties.observation.properties, key1))){
validate281.errors = [{instancePath:instancePath+"/observation",schemaPath:"#/properties/observation/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key1},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs4 === errors){
if(data0.version !== undefined){
const _errs5 = errors;
if(!(validate53(data0.version, {instancePath:instancePath+"/observation/version",parentData:data0,parentDataProperty:"version",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate53.errors : vErrors.concat(validate53.errors);
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
if(!(validate55(data0.realm, {instancePath:instancePath+"/observation/realm",parentData:data0,parentDataProperty:"realm",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate55.errors : vErrors.concat(validate55.errors);
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
if(!(validate55(data0.principal_sequence, {instancePath:instancePath+"/observation/principal_sequence",parentData:data0,parentDataProperty:"principal_sequence",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate55.errors : vErrors.concat(validate55.errors);
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
if(!(validate65(data0.reader, {instancePath:instancePath+"/observation/reader",parentData:data0,parentDataProperty:"reader",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate65.errors : vErrors.concat(validate65.errors);
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
validate281.errors = [{instancePath:instancePath+"/observation/kind",schemaPath:"#/properties/observation/properties/kind/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
if(!(((data5 === "resources") || (data5 === "associations")) || (data5 === "entries"))){
validate281.errors = [{instancePath:instancePath+"/observation/kind",schemaPath:"#/properties/observation/properties/kind/enum",keyword:"enum",params:{allowedValues: schema88.properties.observation.properties.kind.enum},message:"must be equal to one of the allowed values"}];
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
if(!(validate60(data0.cut, {instancePath:instancePath+"/observation/cut",parentData:data0,parentDataProperty:"cut",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate60.errors : vErrors.concat(validate60.errors);
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
if(!(validate57(data0.next, {instancePath:instancePath+"/observation/next",parentData:data0,parentDataProperty:"next",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate57.errors : vErrors.concat(validate57.errors);
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
if(!(validate133(data0.next_key, {instancePath:instancePath+"/observation/next_key",parentData:data0,parentDataProperty:"next_key",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate133.errors : vErrors.concat(validate133.errors);
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
if(!(validate289(data0.resources, {instancePath:instancePath+"/observation/resources",parentData:data0,parentDataProperty:"resources",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate289.errors : vErrors.concat(validate289.errors);
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
validate281.errors = [{instancePath:instancePath+"/observation/associations",schemaPath:"#/properties/observation/properties/associations/maxItems",keyword:"maxItems",params:{limit: 8},message:"must NOT have more than 8 items"}];
return false;
}
else {
if(data10.length < 8){
validate281.errors = [{instancePath:instancePath+"/observation/associations",schemaPath:"#/properties/observation/properties/associations/minItems",keyword:"minItems",params:{limit: 8},message:"must NOT have fewer than 8 items"}];
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
const err0 = {instancePath:instancePath+"/observation/associations/" + i0,schemaPath:"#/properties/observation/properties/associations/items/anyOf/0/required",keyword:"required",params:{missingProperty: missing2},message:"must have required property '"+missing2+"'"};
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
const err1 = {instancePath:instancePath+"/observation/associations/" + i0,schemaPath:"#/properties/observation/properties/associations/items/anyOf/0/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key2},message:"must NOT have additional properties"};
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
if(!(validate55(data11.pid, {instancePath:instancePath+"/observation/associations/" + i0+"/pid",parentData:data11,parentDataProperty:"pid",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate55.errors : vErrors.concat(validate55.errors);
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
if(!(validate134(data11.name, {instancePath:instancePath+"/observation/associations/" + i0+"/name",parentData:data11,parentDataProperty:"name",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate134.errors : vErrors.concat(validate134.errors);
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
if(!(validate55(data11.resource, {instancePath:instancePath+"/observation/associations/" + i0+"/resource",parentData:data11,parentDataProperty:"resource",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate55.errors : vErrors.concat(validate55.errors);
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
if(!(validate55(data11.revision, {instancePath:instancePath+"/observation/associations/" + i0+"/revision",parentData:data11,parentDataProperty:"revision",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate55.errors : vErrors.concat(validate55.errors);
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
const err2 = {instancePath:instancePath+"/observation/associations/" + i0+"/required",schemaPath:"#/properties/observation/properties/associations/items/anyOf/0/properties/required/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"};
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
const err3 = {instancePath:instancePath+"/observation/associations/" + i0,schemaPath:"#/properties/observation/properties/associations/items/anyOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err4 = {instancePath:instancePath+"/observation/associations/" + i0,schemaPath:"#/properties/observation/properties/associations/items/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
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
const err5 = {instancePath:instancePath+"/observation/associations/" + i0,schemaPath:"#/properties/observation/properties/associations/items/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err5];
}
else {
vErrors.push(err5);
}
errors++;
validate281.errors = vErrors;
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
validate281.errors = [{instancePath:instancePath+"/observation/associations",schemaPath:"#/properties/observation/properties/associations/type",keyword:"type",params:{type: "array"},message:"must be array"}];
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
validate281.errors = [{instancePath:instancePath+"/observation/entries",schemaPath:"#/properties/observation/properties/entries/maxItems",keyword:"maxItems",params:{limit: 8},message:"must NOT have more than 8 items"}];
return false;
}
else {
if(data17.length < 8){
validate281.errors = [{instancePath:instancePath+"/observation/entries",schemaPath:"#/properties/observation/properties/entries/minItems",keyword:"minItems",params:{limit: 8},message:"must NOT have fewer than 8 items"}];
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
const err6 = {instancePath:instancePath+"/observation/entries/" + i1,schemaPath:"#/properties/observation/properties/entries/items/anyOf/0/required",keyword:"required",params:{missingProperty: missing3},message:"must have required property '"+missing3+"'"};
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
const err7 = {instancePath:instancePath+"/observation/entries/" + i1,schemaPath:"#/properties/observation/properties/entries/items/anyOf/0/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key3},message:"must NOT have additional properties"};
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
if(!(validate134(data18.key, {instancePath:instancePath+"/observation/entries/" + i1+"/key",parentData:data18,parentDataProperty:"key",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate134.errors : vErrors.concat(validate134.errors);
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
if(!(validate134(data18.value, {instancePath:instancePath+"/observation/entries/" + i1+"/value",parentData:data18,parentDataProperty:"value",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate134.errors : vErrors.concat(validate134.errors);
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
if(!(validate55(data18.revision, {instancePath:instancePath+"/observation/entries/" + i1+"/revision",parentData:data18,parentDataProperty:"revision",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate55.errors : vErrors.concat(validate55.errors);
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
const err8 = {instancePath:instancePath+"/observation/entries/" + i1,schemaPath:"#/properties/observation/properties/entries/items/anyOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err9 = {instancePath:instancePath+"/observation/entries/" + i1,schemaPath:"#/properties/observation/properties/entries/items/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
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
const err10 = {instancePath:instancePath+"/observation/entries/" + i1,schemaPath:"#/properties/observation/properties/entries/items/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err10];
}
else {
vErrors.push(err10);
}
errors++;
validate281.errors = vErrors;
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
validate281.errors = [{instancePath:instancePath+"/observation/entries",schemaPath:"#/properties/observation/properties/entries/type",keyword:"type",params:{type: "array"},message:"must be array"}];
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
validate281.errors = [{instancePath:instancePath+"/observation",schemaPath:"#/properties/observation/type",keyword:"type",params:{type: "object"},message:"must be object"}];
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
validate281.errors = [{instancePath:instancePath+"/framework",schemaPath:"#/properties/framework/maxItems",keyword:"maxItems",params:{limit: 8},message:"must NOT have more than 8 items"}];
return false;
}
else {
if(data22.length < 8){
validate281.errors = [{instancePath:instancePath+"/framework",schemaPath:"#/properties/framework/minItems",keyword:"minItems",params:{limit: 8},message:"must NOT have fewer than 8 items"}];
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
const err11 = {instancePath:instancePath+"/framework/" + i2,schemaPath:"#/properties/framework/items/anyOf/0/required",keyword:"required",params:{missingProperty: missing4},message:"must have required property '"+missing4+"'"};
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
const err12 = {instancePath:instancePath+"/framework/" + i2,schemaPath:"#/properties/framework/items/anyOf/0/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key4},message:"must NOT have additional properties"};
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
if(!(validate102(data23.version, {instancePath:instancePath+"/framework/" + i2+"/version",parentData:data23,parentDataProperty:"version",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate102.errors : vErrors.concat(validate102.errors);
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
if(!(validate315(data23.source, {instancePath:instancePath+"/framework/" + i2+"/source",parentData:data23,parentDataProperty:"source",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate315.errors : vErrors.concat(validate315.errors);
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
const err13 = {instancePath:instancePath+"/framework/" + i2+"/declaration",schemaPath:"#/properties/framework/items/anyOf/0/properties/declaration/oneOf/0/required",keyword:"required",params:{missingProperty: missing5},message:"must have required property '"+missing5+"'"};
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
const err14 = {instancePath:instancePath+"/framework/" + i2+"/declaration",schemaPath:"#/properties/framework/items/anyOf/0/properties/declaration/oneOf/0/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key5},message:"must NOT have additional properties"};
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
const err15 = {instancePath:instancePath+"/framework/" + i2+"/declaration/behavior",schemaPath:"#/properties/framework/items/anyOf/0/properties/declaration/oneOf/0/properties/behavior/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err15];
}
else {
vErrors.push(err15);
}
errors++;
}
if(!(data27 === "genserver")){
const err16 = {instancePath:instancePath+"/framework/" + i2+"/declaration/behavior",schemaPath:"#/properties/framework/items/anyOf/0/properties/declaration/oneOf/0/properties/behavior/enum",keyword:"enum",params:{allowedValues: schema88.properties.framework.items.anyOf[0].properties.declaration.oneOf[0].properties.behavior.enum},message:"must be equal to one of the allowed values"};
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
const err17 = {instancePath:instancePath+"/framework/" + i2+"/declaration",schemaPath:"#/properties/framework/items/anyOf/0/properties/declaration/oneOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err18 = {instancePath:instancePath+"/framework/" + i2+"/declaration",schemaPath:"#/properties/framework/items/anyOf/0/properties/declaration/oneOf/1/required",keyword:"required",params:{missingProperty: missing6},message:"must have required property '"+missing6+"'"};
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
const err19 = {instancePath:instancePath+"/framework/" + i2+"/declaration",schemaPath:"#/properties/framework/items/anyOf/0/properties/declaration/oneOf/1/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key6},message:"must NOT have additional properties"};
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
if(((((data28.id === undefined) && (missing7 = "id")) || ((data28.schema_version === undefined) && (missing7 = "schema_version"))) || ((data28.columns === undefined) && (missing7 = "columns"))) || ((data28.fingerprint === undefined) && (missing7 = "fingerprint"))){
const err20 = {instancePath:instancePath+"/framework/" + i2+"/declaration/table",schemaPath:"#/properties/framework/items/anyOf/0/properties/declaration/oneOf/1/properties/table/required",keyword:"required",params:{missingProperty: missing7},message:"must have required property '"+missing7+"'"};
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
if(!((((key7 === "id") || (key7 === "schema_version")) || (key7 === "columns")) || (key7 === "fingerprint"))){
const err21 = {instancePath:instancePath+"/framework/" + i2+"/declaration/table",schemaPath:"#/properties/framework/items/anyOf/0/properties/declaration/oneOf/1/properties/table/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key7},message:"must NOT have additional properties"};
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
if(data28.id !== undefined){
const _errs64 = errors;
if(!(validate53(data28.id, {instancePath:instancePath+"/framework/" + i2+"/declaration/table/id",parentData:data28,parentDataProperty:"id",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate53.errors : vErrors.concat(validate53.errors);
errors = vErrors.length;
}
var valid14 = _errs64 === errors;
}
else {
var valid14 = true;
}
if(valid14){
if(data28.schema_version !== undefined){
const _errs65 = errors;
if(!(validate102(data28.schema_version, {instancePath:instancePath+"/framework/" + i2+"/declaration/table/schema_version",parentData:data28,parentDataProperty:"schema_version",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate102.errors : vErrors.concat(validate102.errors);
errors = vErrors.length;
}
var valid14 = _errs65 === errors;
}
else {
var valid14 = true;
}
if(valid14){
if(data28.columns !== undefined){
let data31 = data28.columns;
const _errs66 = errors;
if(errors === _errs66){
if(Array.isArray(data31)){
if(data31.length > 2){
const err22 = {instancePath:instancePath+"/framework/" + i2+"/declaration/table/columns",schemaPath:"#/properties/framework/items/anyOf/0/properties/declaration/oneOf/1/properties/table/properties/columns/maxItems",keyword:"maxItems",params:{limit: 2},message:"must NOT have more than 2 items"};
if(vErrors === null){
vErrors = [err22];
}
else {
vErrors.push(err22);
}
errors++;
}
else {
if(data31.length < 2){
const err23 = {instancePath:instancePath+"/framework/" + i2+"/declaration/table/columns",schemaPath:"#/properties/framework/items/anyOf/0/properties/declaration/oneOf/1/properties/table/properties/columns/minItems",keyword:"minItems",params:{limit: 2},message:"must NOT have fewer than 2 items"};
if(vErrors === null){
vErrors = [err23];
}
else {
vErrors.push(err23);
}
errors++;
}
else {
var valid15 = true;
const len3 = data31.length;
for(let i3=0; i3<len3; i3++){
let data32 = data31[i3];
const _errs68 = errors;
if(errors === _errs68){
if(data32 && typeof data32 == "object" && !Array.isArray(data32)){
let missing8;
if((((data32.name === undefined) && (missing8 = "name")) || ((data32.data_type === undefined) && (missing8 = "data_type"))) || ((data32.nullable === undefined) && (missing8 = "nullable"))){
const err24 = {instancePath:instancePath+"/framework/" + i2+"/declaration/table/columns/" + i3,schemaPath:"#/properties/framework/items/anyOf/0/properties/declaration/oneOf/1/properties/table/properties/columns/items/required",keyword:"required",params:{missingProperty: missing8},message:"must have required property '"+missing8+"'"};
if(vErrors === null){
vErrors = [err24];
}
else {
vErrors.push(err24);
}
errors++;
}
else {
const _errs70 = errors;
for(const key8 in data32){
if(!(((key8 === "name") || (key8 === "data_type")) || (key8 === "nullable"))){
const err25 = {instancePath:instancePath+"/framework/" + i2+"/declaration/table/columns/" + i3,schemaPath:"#/properties/framework/items/anyOf/0/properties/declaration/oneOf/1/properties/table/properties/columns/items/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key8},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err25];
}
else {
vErrors.push(err25);
}
errors++;
break;
}
}
if(_errs70 === errors){
if(data32.name !== undefined){
const _errs71 = errors;
if(!(validate134(data32.name, {instancePath:instancePath+"/framework/" + i2+"/declaration/table/columns/" + i3+"/name",parentData:data32,parentDataProperty:"name",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate134.errors : vErrors.concat(validate134.errors);
errors = vErrors.length;
}
var valid16 = _errs71 === errors;
}
else {
var valid16 = true;
}
if(valid16){
if(data32.data_type !== undefined){
const _errs72 = errors;
if(!(validate327(data32.data_type, {instancePath:instancePath+"/framework/" + i2+"/declaration/table/columns/" + i3+"/data_type",parentData:data32,parentDataProperty:"data_type",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate327.errors : vErrors.concat(validate327.errors);
errors = vErrors.length;
}
var valid16 = _errs72 === errors;
}
else {
var valid16 = true;
}
if(valid16){
if(data32.nullable !== undefined){
const _errs73 = errors;
if(typeof data32.nullable !== "boolean"){
const err26 = {instancePath:instancePath+"/framework/" + i2+"/declaration/table/columns/" + i3+"/nullable",schemaPath:"#/properties/framework/items/anyOf/0/properties/declaration/oneOf/1/properties/table/properties/columns/items/properties/nullable/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"};
if(vErrors === null){
vErrors = [err26];
}
else {
vErrors.push(err26);
}
errors++;
}
var valid16 = _errs73 === errors;
}
else {
var valid16 = true;
}
}
}
}
}
}
else {
const err27 = {instancePath:instancePath+"/framework/" + i2+"/declaration/table/columns/" + i3,schemaPath:"#/properties/framework/items/anyOf/0/properties/declaration/oneOf/1/properties/table/properties/columns/items/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err27];
}
else {
vErrors.push(err27);
}
errors++;
}
}
var valid15 = _errs68 === errors;
if(!valid15){
break;
}
}
}
}
}
else {
const err28 = {instancePath:instancePath+"/framework/" + i2+"/declaration/table/columns",schemaPath:"#/properties/framework/items/anyOf/0/properties/declaration/oneOf/1/properties/table/properties/columns/type",keyword:"type",params:{type: "array"},message:"must be array"};
if(vErrors === null){
vErrors = [err28];
}
else {
vErrors.push(err28);
}
errors++;
}
}
var valid14 = _errs66 === errors;
}
else {
var valid14 = true;
}
if(valid14){
if(data28.fingerprint !== undefined){
const _errs75 = errors;
if(!(validate105(data28.fingerprint, {instancePath:instancePath+"/framework/" + i2+"/declaration/table/fingerprint",parentData:data28,parentDataProperty:"fingerprint",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate105.errors : vErrors.concat(validate105.errors);
errors = vErrors.length;
}
var valid14 = _errs75 === errors;
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
else {
const err29 = {instancePath:instancePath+"/framework/" + i2+"/declaration/table",schemaPath:"#/properties/framework/items/anyOf/0/properties/declaration/oneOf/1/properties/table/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err29];
}
else {
vErrors.push(err29);
}
errors++;
}
}
}
}
}
}
else {
const err30 = {instancePath:instancePath+"/framework/" + i2+"/declaration",schemaPath:"#/properties/framework/items/anyOf/0/properties/declaration/oneOf/1/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err30];
}
else {
vErrors.push(err30);
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
const err31 = {instancePath:instancePath+"/framework/" + i2+"/declaration",schemaPath:"#/properties/framework/items/anyOf/0/properties/declaration/oneOf/2/required",keyword:"required",params:{missingProperty: missing9},message:"must have required property '"+missing9+"'"};
if(vErrors === null){
vErrors = [err31];
}
else {
vErrors.push(err31);
}
errors++;
}
else {
const _errs78 = errors;
for(const key9 in data26){
if(!(key9 === "registry_scope")){
const err32 = {instancePath:instancePath+"/framework/" + i2+"/declaration",schemaPath:"#/properties/framework/items/anyOf/0/properties/declaration/oneOf/2/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key9},message:"must NOT have additional properties"};
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
if(_errs78 === errors){
if(data26.registry_scope !== undefined){
let data37 = data26.registry_scope;
const _errs79 = errors;
if(errors === _errs79){
if(data37 && typeof data37 == "object" && !Array.isArray(data37)){
let missing10;
if((data37.id === undefined) && (missing10 = "id")){
const err33 = {instancePath:instancePath+"/framework/" + i2+"/declaration/registry_scope",schemaPath:"#/properties/framework/items/anyOf/0/properties/declaration/oneOf/2/properties/registry_scope/required",keyword:"required",params:{missingProperty: missing10},message:"must have required property '"+missing10+"'"};
if(vErrors === null){
vErrors = [err33];
}
else {
vErrors.push(err33);
}
errors++;
}
else {
const _errs81 = errors;
for(const key10 in data37){
if(!(key10 === "id")){
const err34 = {instancePath:instancePath+"/framework/" + i2+"/declaration/registry_scope",schemaPath:"#/properties/framework/items/anyOf/0/properties/declaration/oneOf/2/properties/registry_scope/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key10},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err34];
}
else {
vErrors.push(err34);
}
errors++;
break;
}
}
if(_errs81 === errors){
if(data37.id !== undefined){
if(!(validate53(data37.id, {instancePath:instancePath+"/framework/" + i2+"/declaration/registry_scope/id",parentData:data37,parentDataProperty:"id",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate53.errors : vErrors.concat(validate53.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err35 = {instancePath:instancePath+"/framework/" + i2+"/declaration/registry_scope",schemaPath:"#/properties/framework/items/anyOf/0/properties/declaration/oneOf/2/properties/registry_scope/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
}
}
}
else {
const err36 = {instancePath:instancePath+"/framework/" + i2+"/declaration",schemaPath:"#/properties/framework/items/anyOf/0/properties/declaration/oneOf/2/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err36];
}
else {
vErrors.push(err36);
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
const err37 = {instancePath:instancePath+"/framework/" + i2+"/declaration",schemaPath:"#/properties/framework/items/anyOf/0/properties/declaration/oneOf/3/required",keyword:"required",params:{missingProperty: missing11},message:"must have required property '"+missing11+"'"};
if(vErrors === null){
vErrors = [err37];
}
else {
vErrors.push(err37);
}
errors++;
}
else {
const _errs85 = errors;
for(const key11 in data26){
if(!(key11 === "registry_binding")){
const err38 = {instancePath:instancePath+"/framework/" + i2+"/declaration",schemaPath:"#/properties/framework/items/anyOf/0/properties/declaration/oneOf/3/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key11},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err38];
}
else {
vErrors.push(err38);
}
errors++;
break;
}
}
if(_errs85 === errors){
if(data26.registry_binding !== undefined){
let data39 = data26.registry_binding;
const _errs86 = errors;
if(errors === _errs86){
if(data39 && typeof data39 == "object" && !Array.isArray(data39)){
let missing12;
if(((((data39.scope === undefined) && (missing12 = "scope")) || ((data39.name === undefined) && (missing12 = "name"))) || ((data39.revision === undefined) && (missing12 = "revision"))) || ((data39.destination === undefined) && (missing12 = "destination"))){
const err39 = {instancePath:instancePath+"/framework/" + i2+"/declaration/registry_binding",schemaPath:"#/properties/framework/items/anyOf/0/properties/declaration/oneOf/3/properties/registry_binding/required",keyword:"required",params:{missingProperty: missing12},message:"must have required property '"+missing12+"'"};
if(vErrors === null){
vErrors = [err39];
}
else {
vErrors.push(err39);
}
errors++;
}
else {
const _errs88 = errors;
for(const key12 in data39){
if(!((((key12 === "scope") || (key12 === "name")) || (key12 === "revision")) || (key12 === "destination"))){
const err40 = {instancePath:instancePath+"/framework/" + i2+"/declaration/registry_binding",schemaPath:"#/properties/framework/items/anyOf/0/properties/declaration/oneOf/3/properties/registry_binding/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key12},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err40];
}
else {
vErrors.push(err40);
}
errors++;
break;
}
}
if(_errs88 === errors){
if(data39.scope !== undefined){
const _errs89 = errors;
if(!(validate53(data39.scope, {instancePath:instancePath+"/framework/" + i2+"/declaration/registry_binding/scope",parentData:data39,parentDataProperty:"scope",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate53.errors : vErrors.concat(validate53.errors);
errors = vErrors.length;
}
var valid20 = _errs89 === errors;
}
else {
var valid20 = true;
}
if(valid20){
if(data39.name !== undefined){
const _errs90 = errors;
if(!(validate134(data39.name, {instancePath:instancePath+"/framework/" + i2+"/declaration/registry_binding/name",parentData:data39,parentDataProperty:"name",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate134.errors : vErrors.concat(validate134.errors);
errors = vErrors.length;
}
var valid20 = _errs90 === errors;
}
else {
var valid20 = true;
}
if(valid20){
if(data39.revision !== undefined){
const _errs91 = errors;
if(!(validate55(data39.revision, {instancePath:instancePath+"/framework/" + i2+"/declaration/registry_binding/revision",parentData:data39,parentDataProperty:"revision",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate55.errors : vErrors.concat(validate55.errors);
errors = vErrors.length;
}
var valid20 = _errs91 === errors;
}
else {
var valid20 = true;
}
if(valid20){
if(data39.destination !== undefined){
const _errs92 = errors;
if(!(validate57(data39.destination, {instancePath:instancePath+"/framework/" + i2+"/declaration/registry_binding/destination",parentData:data39,parentDataProperty:"destination",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate57.errors : vErrors.concat(validate57.errors);
errors = vErrors.length;
}
var valid20 = _errs92 === errors;
}
else {
var valid20 = true;
}
}
}
}
}
}
}
else {
const err41 = {instancePath:instancePath+"/framework/" + i2+"/declaration/registry_binding",schemaPath:"#/properties/framework/items/anyOf/0/properties/declaration/oneOf/3/properties/registry_binding/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err41];
}
else {
vErrors.push(err41);
}
errors++;
}
}
}
}
}
}
else {
const err42 = {instancePath:instancePath+"/framework/" + i2+"/declaration",schemaPath:"#/properties/framework/items/anyOf/0/properties/declaration/oneOf/3/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err42];
}
else {
vErrors.push(err42);
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
const err43 = {instancePath:instancePath+"/framework/" + i2+"/declaration",schemaPath:"#/properties/framework/items/anyOf/0/properties/declaration/oneOf/4/required",keyword:"required",params:{missingProperty: missing13},message:"must have required property '"+missing13+"'"};
if(vErrors === null){
vErrors = [err43];
}
else {
vErrors.push(err43);
}
errors++;
}
else {
const _errs95 = errors;
for(const key13 in data26){
if(!(key13 === "child")){
const err44 = {instancePath:instancePath+"/framework/" + i2+"/declaration",schemaPath:"#/properties/framework/items/anyOf/0/properties/declaration/oneOf/4/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key13},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err44];
}
else {
vErrors.push(err44);
}
errors++;
break;
}
}
if(_errs95 === errors){
if(data26.child !== undefined){
let data44 = data26.child;
const _errs96 = errors;
if(errors === _errs96){
if(data44 && typeof data44 == "object" && !Array.isArray(data44)){
let missing14;
if((((((((data44.pid === undefined) && (missing14 = "pid")) || ((data44.generation === undefined) && (missing14 = "generation"))) || ((data44.phase === undefined) && (missing14 = "phase"))) || ((data44.attempts === undefined) && (missing14 = "attempts"))) || ((data44.limit === undefined) && (missing14 = "limit"))) || ((data44.retry_at_ms === undefined) && (missing14 = "retry_at_ms"))) || ((data44.successor === undefined) && (missing14 = "successor"))){
const err45 = {instancePath:instancePath+"/framework/" + i2+"/declaration/child",schemaPath:"#/properties/framework/items/anyOf/0/properties/declaration/oneOf/4/properties/child/required",keyword:"required",params:{missingProperty: missing14},message:"must have required property '"+missing14+"'"};
if(vErrors === null){
vErrors = [err45];
}
else {
vErrors.push(err45);
}
errors++;
}
else {
const _errs98 = errors;
for(const key14 in data44){
if(!(((((((key14 === "pid") || (key14 === "generation")) || (key14 === "phase")) || (key14 === "attempts")) || (key14 === "limit")) || (key14 === "retry_at_ms")) || (key14 === "successor"))){
const err46 = {instancePath:instancePath+"/framework/" + i2+"/declaration/child",schemaPath:"#/properties/framework/items/anyOf/0/properties/declaration/oneOf/4/properties/child/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key14},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err46];
}
else {
vErrors.push(err46);
}
errors++;
break;
}
}
if(_errs98 === errors){
if(data44.pid !== undefined){
const _errs99 = errors;
if(!(validate55(data44.pid, {instancePath:instancePath+"/framework/" + i2+"/declaration/child/pid",parentData:data44,parentDataProperty:"pid",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate55.errors : vErrors.concat(validate55.errors);
errors = vErrors.length;
}
var valid22 = _errs99 === errors;
}
else {
var valid22 = true;
}
if(valid22){
if(data44.generation !== undefined){
const _errs100 = errors;
if(!(validate55(data44.generation, {instancePath:instancePath+"/framework/" + i2+"/declaration/child/generation",parentData:data44,parentDataProperty:"generation",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate55.errors : vErrors.concat(validate55.errors);
errors = vErrors.length;
}
var valid22 = _errs100 === errors;
}
else {
var valid22 = true;
}
if(valid22){
if(data44.phase !== undefined){
let data47 = data44.phase;
const _errs101 = errors;
if(typeof data47 !== "string"){
const err47 = {instancePath:instancePath+"/framework/" + i2+"/declaration/child/phase",schemaPath:"#/properties/framework/items/anyOf/0/properties/declaration/oneOf/4/properties/child/properties/phase/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err47];
}
else {
vErrors.push(err47);
}
errors++;
}
if(!((((((((data47 === "watching") || (data47 === "retry_wait")) || (data47 === "retry_requested")) || (data47 === "exhausted")) || (data47 === "retired")) || (data47 === "suspended")) || (data47 === "placement_unavailable")) || (data47 === "initializing"))){
const err48 = {instancePath:instancePath+"/framework/" + i2+"/declaration/child/phase",schemaPath:"#/properties/framework/items/anyOf/0/properties/declaration/oneOf/4/properties/child/properties/phase/enum",keyword:"enum",params:{allowedValues: schema88.properties.framework.items.anyOf[0].properties.declaration.oneOf[4].properties.child.properties.phase.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err48];
}
else {
vErrors.push(err48);
}
errors++;
}
var valid22 = _errs101 === errors;
}
else {
var valid22 = true;
}
if(valid22){
if(data44.attempts !== undefined){
const _errs103 = errors;
if(!(validate102(data44.attempts, {instancePath:instancePath+"/framework/" + i2+"/declaration/child/attempts",parentData:data44,parentDataProperty:"attempts",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate102.errors : vErrors.concat(validate102.errors);
errors = vErrors.length;
}
var valid22 = _errs103 === errors;
}
else {
var valid22 = true;
}
if(valid22){
if(data44.limit !== undefined){
const _errs104 = errors;
if(!(validate102(data44.limit, {instancePath:instancePath+"/framework/" + i2+"/declaration/child/limit",parentData:data44,parentDataProperty:"limit",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate102.errors : vErrors.concat(validate102.errors);
errors = vErrors.length;
}
var valid22 = _errs104 === errors;
}
else {
var valid22 = true;
}
if(valid22){
if(data44.retry_at_ms !== undefined){
const _errs105 = errors;
if(!(validate55(data44.retry_at_ms, {instancePath:instancePath+"/framework/" + i2+"/declaration/child/retry_at_ms",parentData:data44,parentDataProperty:"retry_at_ms",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate55.errors : vErrors.concat(validate55.errors);
errors = vErrors.length;
}
var valid22 = _errs105 === errors;
}
else {
var valid22 = true;
}
if(valid22){
if(data44.successor !== undefined){
const _errs106 = errors;
if(!(validate57(data44.successor, {instancePath:instancePath+"/framework/" + i2+"/declaration/child/successor",parentData:data44,parentDataProperty:"successor",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate57.errors : vErrors.concat(validate57.errors);
errors = vErrors.length;
}
var valid22 = _errs106 === errors;
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
}
}
else {
const err49 = {instancePath:instancePath+"/framework/" + i2+"/declaration/child",schemaPath:"#/properties/framework/items/anyOf/0/properties/declaration/oneOf/4/properties/child/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
}
}
else {
const err50 = {instancePath:instancePath+"/framework/" + i2+"/declaration",schemaPath:"#/properties/framework/items/anyOf/0/properties/declaration/oneOf/4/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err50];
}
else {
vErrors.push(err50);
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
if((data26.query === undefined) && (missing15 = "query")){
const err51 = {instancePath:instancePath+"/framework/" + i2+"/declaration",schemaPath:"#/properties/framework/items/anyOf/0/properties/declaration/oneOf/5/required",keyword:"required",params:{missingProperty: missing15},message:"must have required property '"+missing15+"'"};
if(vErrors === null){
vErrors = [err51];
}
else {
vErrors.push(err51);
}
errors++;
}
else {
const _errs109 = errors;
for(const key15 in data26){
if(!(key15 === "query")){
const err52 = {instancePath:instancePath+"/framework/" + i2+"/declaration",schemaPath:"#/properties/framework/items/anyOf/0/properties/declaration/oneOf/5/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key15},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err52];
}
else {
vErrors.push(err52);
}
errors++;
break;
}
}
if(_errs109 === errors){
if(data26.query !== undefined){
let data52 = data26.query;
const _errs110 = errors;
if(errors === _errs110){
if(data52 && typeof data52 == "object" && !Array.isArray(data52)){
let missing16;
if((((((((((((data52.id === undefined) && (missing16 = "id")) || ((data52.correlation === undefined) && (missing16 = "correlation"))) || ((data52.destination === undefined) && (missing16 = "destination"))) || ((data52.table === undefined) && (missing16 = "table"))) || ((data52.source_resource === undefined) && (missing16 = "source_resource"))) || ((data52.source_revision === undefined) && (missing16 = "source_revision"))) || ((data52.schema === undefined) && (missing16 = "schema"))) || ((data52.bytes === undefined) && (missing16 = "bytes"))) || ((data52.rows === undefined) && (missing16 = "rows"))) || ((data52.phase === undefined) && (missing16 = "phase"))) || ((data52.direction === undefined) && (missing16 = "direction"))){
const err53 = {instancePath:instancePath+"/framework/" + i2+"/declaration/query",schemaPath:"#/properties/framework/items/anyOf/0/properties/declaration/oneOf/5/properties/query/required",keyword:"required",params:{missingProperty: missing16},message:"must have required property '"+missing16+"'"};
if(vErrors === null){
vErrors = [err53];
}
else {
vErrors.push(err53);
}
errors++;
}
else {
const _errs112 = errors;
for(const key16 in data52){
if(!(func1.call(schema88.properties.framework.items.anyOf[0].properties.declaration.oneOf[5].properties.query.properties, key16))){
const err54 = {instancePath:instancePath+"/framework/" + i2+"/declaration/query",schemaPath:"#/properties/framework/items/anyOf/0/properties/declaration/oneOf/5/properties/query/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key16},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err54];
}
else {
vErrors.push(err54);
}
errors++;
break;
}
}
if(_errs112 === errors){
if(data52.id !== undefined){
const _errs113 = errors;
if(!(validate55(data52.id, {instancePath:instancePath+"/framework/" + i2+"/declaration/query/id",parentData:data52,parentDataProperty:"id",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate55.errors : vErrors.concat(validate55.errors);
errors = vErrors.length;
}
var valid24 = _errs113 === errors;
}
else {
var valid24 = true;
}
if(valid24){
if(data52.correlation !== undefined){
const _errs114 = errors;
if(!(validate134(data52.correlation, {instancePath:instancePath+"/framework/" + i2+"/declaration/query/correlation",parentData:data52,parentDataProperty:"correlation",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate134.errors : vErrors.concat(validate134.errors);
errors = vErrors.length;
}
var valid24 = _errs114 === errors;
}
else {
var valid24 = true;
}
if(valid24){
if(data52.destination !== undefined){
const _errs115 = errors;
if(!(validate55(data52.destination, {instancePath:instancePath+"/framework/" + i2+"/declaration/query/destination",parentData:data52,parentDataProperty:"destination",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate55.errors : vErrors.concat(validate55.errors);
errors = vErrors.length;
}
var valid24 = _errs115 === errors;
}
else {
var valid24 = true;
}
if(valid24){
if(data52.table !== undefined){
const _errs116 = errors;
if(!(validate53(data52.table, {instancePath:instancePath+"/framework/" + i2+"/declaration/query/table",parentData:data52,parentDataProperty:"table",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate53.errors : vErrors.concat(validate53.errors);
errors = vErrors.length;
}
var valid24 = _errs116 === errors;
}
else {
var valid24 = true;
}
if(valid24){
if(data52.source_resource !== undefined){
const _errs117 = errors;
if(!(validate55(data52.source_resource, {instancePath:instancePath+"/framework/" + i2+"/declaration/query/source_resource",parentData:data52,parentDataProperty:"source_resource",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate55.errors : vErrors.concat(validate55.errors);
errors = vErrors.length;
}
var valid24 = _errs117 === errors;
}
else {
var valid24 = true;
}
if(valid24){
if(data52.source_revision !== undefined){
const _errs118 = errors;
if(!(validate55(data52.source_revision, {instancePath:instancePath+"/framework/" + i2+"/declaration/query/source_revision",parentData:data52,parentDataProperty:"source_revision",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate55.errors : vErrors.concat(validate55.errors);
errors = vErrors.length;
}
var valid24 = _errs118 === errors;
}
else {
var valid24 = true;
}
if(valid24){
if(data52.schema !== undefined){
const _errs119 = errors;
if(!(validate105(data52.schema, {instancePath:instancePath+"/framework/" + i2+"/declaration/query/schema",parentData:data52,parentDataProperty:"schema",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate105.errors : vErrors.concat(validate105.errors);
errors = vErrors.length;
}
var valid24 = _errs119 === errors;
}
else {
var valid24 = true;
}
if(valid24){
if(data52.bytes !== undefined){
const _errs120 = errors;
if(!(validate55(data52.bytes, {instancePath:instancePath+"/framework/" + i2+"/declaration/query/bytes",parentData:data52,parentDataProperty:"bytes",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate55.errors : vErrors.concat(validate55.errors);
errors = vErrors.length;
}
var valid24 = _errs120 === errors;
}
else {
var valid24 = true;
}
if(valid24){
if(data52.rows !== undefined){
const _errs121 = errors;
if(!(validate55(data52.rows, {instancePath:instancePath+"/framework/" + i2+"/declaration/query/rows",parentData:data52,parentDataProperty:"rows",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate55.errors : vErrors.concat(validate55.errors);
errors = vErrors.length;
}
var valid24 = _errs121 === errors;
}
else {
var valid24 = true;
}
if(valid24){
if(data52.phase !== undefined){
const _errs122 = errors;
if(!(validate350(data52.phase, {instancePath:instancePath+"/framework/" + i2+"/declaration/query/phase",parentData:data52,parentDataProperty:"phase",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate350.errors : vErrors.concat(validate350.errors);
errors = vErrors.length;
}
var valid24 = _errs122 === errors;
}
else {
var valid24 = true;
}
if(valid24){
if(data52.direction !== undefined){
let data63 = data52.direction;
const _errs123 = errors;
if(typeof data63 !== "string"){
const err55 = {instancePath:instancePath+"/framework/" + i2+"/declaration/query/direction",schemaPath:"#/properties/framework/items/anyOf/0/properties/declaration/oneOf/5/properties/query/properties/direction/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err55];
}
else {
vErrors.push(err55);
}
errors++;
}
if(!((data63 === "outgoing") || (data63 === "incoming"))){
const err56 = {instancePath:instancePath+"/framework/" + i2+"/declaration/query/direction",schemaPath:"#/properties/framework/items/anyOf/0/properties/declaration/oneOf/5/properties/query/properties/direction/enum",keyword:"enum",params:{allowedValues: schema88.properties.framework.items.anyOf[0].properties.declaration.oneOf[5].properties.query.properties.direction.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err56];
}
else {
vErrors.push(err56);
}
errors++;
}
var valid24 = _errs123 === errors;
}
else {
var valid24 = true;
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
const err57 = {instancePath:instancePath+"/framework/" + i2+"/declaration/query",schemaPath:"#/properties/framework/items/anyOf/0/properties/declaration/oneOf/5/properties/query/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
}
}
else {
const err58 = {instancePath:instancePath+"/framework/" + i2+"/declaration",schemaPath:"#/properties/framework/items/anyOf/0/properties/declaration/oneOf/5/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err58];
}
else {
vErrors.push(err58);
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
const _errs125 = errors;
if(errors === _errs125){
if(data26 && typeof data26 == "object" && !Array.isArray(data26)){
let missing17;
if((data26.wait === undefined) && (missing17 = "wait")){
const err59 = {instancePath:instancePath+"/framework/" + i2+"/declaration",schemaPath:"#/properties/framework/items/anyOf/0/properties/declaration/oneOf/6/required",keyword:"required",params:{missingProperty: missing17},message:"must have required property '"+missing17+"'"};
if(vErrors === null){
vErrors = [err59];
}
else {
vErrors.push(err59);
}
errors++;
}
else {
const _errs127 = errors;
for(const key17 in data26){
if(!(key17 === "wait")){
const err60 = {instancePath:instancePath+"/framework/" + i2+"/declaration",schemaPath:"#/properties/framework/items/anyOf/0/properties/declaration/oneOf/6/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key17},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err60];
}
else {
vErrors.push(err60);
}
errors++;
break;
}
}
if(_errs127 === errors){
if(data26.wait !== undefined){
let data64 = data26.wait;
const _errs128 = errors;
if(errors === _errs128){
if(data64 && typeof data64 == "object" && !Array.isArray(data64)){
let missing18;
if(((((((data64.correlation === undefined) && (missing18 = "correlation")) || ((data64.target === undefined) && (missing18 = "target"))) || ((data64.phase === undefined) && (missing18 = "phase"))) || ((data64.deadline_ms === undefined) && (missing18 = "deadline_ms"))) || ((data64.observer === undefined) && (missing18 = "observer"))) || ((data64.resolution_input === undefined) && (missing18 = "resolution_input"))){
const err61 = {instancePath:instancePath+"/framework/" + i2+"/declaration/wait",schemaPath:"#/properties/framework/items/anyOf/0/properties/declaration/oneOf/6/properties/wait/required",keyword:"required",params:{missingProperty: missing18},message:"must have required property '"+missing18+"'"};
if(vErrors === null){
vErrors = [err61];
}
else {
vErrors.push(err61);
}
errors++;
}
else {
const _errs130 = errors;
for(const key18 in data64){
if(!((((((key18 === "correlation") || (key18 === "target")) || (key18 === "phase")) || (key18 === "deadline_ms")) || (key18 === "observer")) || (key18 === "resolution_input"))){
const err62 = {instancePath:instancePath+"/framework/" + i2+"/declaration/wait",schemaPath:"#/properties/framework/items/anyOf/0/properties/declaration/oneOf/6/properties/wait/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key18},message:"must NOT have additional properties"};
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
if(_errs130 === errors){
if(data64.correlation !== undefined){
const _errs131 = errors;
if(!(validate134(data64.correlation, {instancePath:instancePath+"/framework/" + i2+"/declaration/wait/correlation",parentData:data64,parentDataProperty:"correlation",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate134.errors : vErrors.concat(validate134.errors);
errors = vErrors.length;
}
var valid26 = _errs131 === errors;
}
else {
var valid26 = true;
}
if(valid26){
if(data64.target !== undefined){
const _errs132 = errors;
if(!(validate55(data64.target, {instancePath:instancePath+"/framework/" + i2+"/declaration/wait/target",parentData:data64,parentDataProperty:"target",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate55.errors : vErrors.concat(validate55.errors);
errors = vErrors.length;
}
var valid26 = _errs132 === errors;
}
else {
var valid26 = true;
}
if(valid26){
if(data64.phase !== undefined){
let data67 = data64.phase;
const _errs133 = errors;
if(typeof data67 !== "string"){
const err63 = {instancePath:instancePath+"/framework/" + i2+"/declaration/wait/phase",schemaPath:"#/properties/framework/items/anyOf/0/properties/declaration/oneOf/6/properties/wait/properties/phase/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err63];
}
else {
vErrors.push(err63);
}
errors++;
}
if(!((((data67 === "waiting") || (data67 === "replied")) || (data67 === "timed_out")) || (data67 === "cancelled"))){
const err64 = {instancePath:instancePath+"/framework/" + i2+"/declaration/wait/phase",schemaPath:"#/properties/framework/items/anyOf/0/properties/declaration/oneOf/6/properties/wait/properties/phase/enum",keyword:"enum",params:{allowedValues: schema88.properties.framework.items.anyOf[0].properties.declaration.oneOf[6].properties.wait.properties.phase.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err64];
}
else {
vErrors.push(err64);
}
errors++;
}
var valid26 = _errs133 === errors;
}
else {
var valid26 = true;
}
if(valid26){
if(data64.deadline_ms !== undefined){
const _errs135 = errors;
if(!(validate57(data64.deadline_ms, {instancePath:instancePath+"/framework/" + i2+"/declaration/wait/deadline_ms",parentData:data64,parentDataProperty:"deadline_ms",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate57.errors : vErrors.concat(validate57.errors);
errors = vErrors.length;
}
var valid26 = _errs135 === errors;
}
else {
var valid26 = true;
}
if(valid26){
if(data64.observer !== undefined){
const _errs136 = errors;
if(!(validate57(data64.observer, {instancePath:instancePath+"/framework/" + i2+"/declaration/wait/observer",parentData:data64,parentDataProperty:"observer",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate57.errors : vErrors.concat(validate57.errors);
errors = vErrors.length;
}
var valid26 = _errs136 === errors;
}
else {
var valid26 = true;
}
if(valid26){
if(data64.resolution_input !== undefined){
const _errs137 = errors;
if(!(validate55(data64.resolution_input, {instancePath:instancePath+"/framework/" + i2+"/declaration/wait/resolution_input",parentData:data64,parentDataProperty:"resolution_input",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate55.errors : vErrors.concat(validate55.errors);
errors = vErrors.length;
}
var valid26 = _errs137 === errors;
}
else {
var valid26 = true;
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
const err65 = {instancePath:instancePath+"/framework/" + i2+"/declaration/wait",schemaPath:"#/properties/framework/items/anyOf/0/properties/declaration/oneOf/6/properties/wait/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
}
}
else {
const err66 = {instancePath:instancePath+"/framework/" + i2+"/declaration",schemaPath:"#/properties/framework/items/anyOf/0/properties/declaration/oneOf/6/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err66];
}
else {
vErrors.push(err66);
}
errors++;
}
}
var _valid3 = _errs125 === errors;
if(_valid3 && valid11){
valid11 = false;
passing0 = [passing0, 6];
}
else {
if(_valid3){
valid11 = true;
passing0 = 6;
if(props2 !== true){
props2 = true;
}
}
}
}
}
}
}
}
if(!valid11){
const err67 = {instancePath:instancePath+"/framework/" + i2+"/declaration",schemaPath:"#/properties/framework/items/anyOf/0/properties/declaration/oneOf",keyword:"oneOf",params:{passingSchemas: passing0},message:"must match exactly one schema in oneOf"};
if(vErrors === null){
vErrors = [err67];
}
else {
vErrors.push(err67);
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
const err68 = {instancePath:instancePath+"/framework/" + i2,schemaPath:"#/properties/framework/items/anyOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err68];
}
else {
vErrors.push(err68);
}
errors++;
}
}
var _valid2 = _errs46 === errors;
valid9 = valid9 || _valid2;
const _errs138 = errors;
if(data23 !== null){
const err69 = {instancePath:instancePath+"/framework/" + i2,schemaPath:"#/properties/framework/items/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err69];
}
else {
vErrors.push(err69);
}
errors++;
}
var _valid2 = _errs138 === errors;
valid9 = valid9 || _valid2;
if(!valid9){
const err70 = {instancePath:instancePath+"/framework/" + i2,schemaPath:"#/properties/framework/items/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err70];
}
else {
vErrors.push(err70);
}
errors++;
validate281.errors = vErrors;
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
validate281.errors = [{instancePath:instancePath+"/framework",schemaPath:"#/properties/framework/type",keyword:"type",params:{type: "array"},message:"must be array"}];
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
validate281.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate281.errors = vErrors;
return errors === 0;
}
validate281.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

export const Capabilities = validate357;
const schema96 = {"type":"object","additionalProperties":false,"properties":{"version":{"$ref":"https://transit.invalid/generated-validator/0"},"profile":{"type":"string","enum":["native_v1"]},"query_enabled":{"type":"boolean"},"realm":{"$ref":"https://transit.invalid/generated-validator/1"},"scope_pid":{"$ref":"https://transit.invalid/generated-validator/2"},"read_only":{"type":"boolean"},"shared_principal":{"type":"boolean"},"page_size":{"$ref":"https://transit.invalid/generated-validator/0"},"scan_limit":{"$ref":"https://transit.invalid/generated-validator/0"},"max_edges":{"$ref":"https://transit.invalid/generated-validator/0"},"min_refresh_ms":{"$ref":"https://transit.invalid/generated-validator/0"},"max_request_bytes":{"$ref":"https://transit.invalid/generated-validator/0"},"state_resources":{"type":"boolean"},"station":{"type":"boolean"},"http_connector":{"type":"boolean"},"grpc_connector":{"type":"boolean"},"documents":{"type":"boolean"},"reactive_table":{"type":"boolean"},"push":{"type":"boolean"}},"required":["version","profile","query_enabled","realm","scope_pid","read_only","shared_principal","page_size","scan_limit","max_edges","min_refresh_ms","max_request_bytes","state_resources","station","http_connector","grpc_connector","documents","reactive_table","push"]};

function validate357(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate357.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((((((((((((((((((((data.version === undefined) && (missing0 = "version")) || ((data.profile === undefined) && (missing0 = "profile"))) || ((data.query_enabled === undefined) && (missing0 = "query_enabled"))) || ((data.realm === undefined) && (missing0 = "realm"))) || ((data.scope_pid === undefined) && (missing0 = "scope_pid"))) || ((data.read_only === undefined) && (missing0 = "read_only"))) || ((data.shared_principal === undefined) && (missing0 = "shared_principal"))) || ((data.page_size === undefined) && (missing0 = "page_size"))) || ((data.scan_limit === undefined) && (missing0 = "scan_limit"))) || ((data.max_edges === undefined) && (missing0 = "max_edges"))) || ((data.min_refresh_ms === undefined) && (missing0 = "min_refresh_ms"))) || ((data.max_request_bytes === undefined) && (missing0 = "max_request_bytes"))) || ((data.state_resources === undefined) && (missing0 = "state_resources"))) || ((data.station === undefined) && (missing0 = "station"))) || ((data.http_connector === undefined) && (missing0 = "http_connector"))) || ((data.grpc_connector === undefined) && (missing0 = "grpc_connector"))) || ((data.documents === undefined) && (missing0 = "documents"))) || ((data.reactive_table === undefined) && (missing0 = "reactive_table"))) || ((data.push === undefined) && (missing0 = "push"))){
validate357.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(func1.call(schema96.properties, key0))){
validate357.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.version !== undefined){
const _errs2 = errors;
if(!(validate53(data.version, {instancePath:instancePath+"/version",parentData:data,parentDataProperty:"version",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate53.errors : vErrors.concat(validate53.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.profile !== undefined){
let data1 = data.profile;
const _errs3 = errors;
if(typeof data1 !== "string"){
validate357.errors = [{instancePath:instancePath+"/profile",schemaPath:"#/properties/profile/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
if(!(data1 === "native_v1")){
validate357.errors = [{instancePath:instancePath+"/profile",schemaPath:"#/properties/profile/enum",keyword:"enum",params:{allowedValues: schema96.properties.profile.enum},message:"must be equal to one of the allowed values"}];
return false;
}
var valid0 = _errs3 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.query_enabled !== undefined){
const _errs5 = errors;
if(typeof data.query_enabled !== "boolean"){
validate357.errors = [{instancePath:instancePath+"/query_enabled",schemaPath:"#/properties/query_enabled/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"}];
return false;
}
var valid0 = _errs5 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.realm !== undefined){
const _errs7 = errors;
if(!(validate55(data.realm, {instancePath:instancePath+"/realm",parentData:data,parentDataProperty:"realm",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate55.errors : vErrors.concat(validate55.errors);
errors = vErrors.length;
}
var valid0 = _errs7 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.scope_pid !== undefined){
const _errs8 = errors;
if(!(validate57(data.scope_pid, {instancePath:instancePath+"/scope_pid",parentData:data,parentDataProperty:"scope_pid",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate57.errors : vErrors.concat(validate57.errors);
errors = vErrors.length;
}
var valid0 = _errs8 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.read_only !== undefined){
const _errs9 = errors;
if(typeof data.read_only !== "boolean"){
validate357.errors = [{instancePath:instancePath+"/read_only",schemaPath:"#/properties/read_only/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"}];
return false;
}
var valid0 = _errs9 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.shared_principal !== undefined){
const _errs11 = errors;
if(typeof data.shared_principal !== "boolean"){
validate357.errors = [{instancePath:instancePath+"/shared_principal",schemaPath:"#/properties/shared_principal/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"}];
return false;
}
var valid0 = _errs11 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.page_size !== undefined){
const _errs13 = errors;
if(!(validate53(data.page_size, {instancePath:instancePath+"/page_size",parentData:data,parentDataProperty:"page_size",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate53.errors : vErrors.concat(validate53.errors);
errors = vErrors.length;
}
var valid0 = _errs13 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.scan_limit !== undefined){
const _errs14 = errors;
if(!(validate53(data.scan_limit, {instancePath:instancePath+"/scan_limit",parentData:data,parentDataProperty:"scan_limit",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate53.errors : vErrors.concat(validate53.errors);
errors = vErrors.length;
}
var valid0 = _errs14 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.max_edges !== undefined){
const _errs15 = errors;
if(!(validate53(data.max_edges, {instancePath:instancePath+"/max_edges",parentData:data,parentDataProperty:"max_edges",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate53.errors : vErrors.concat(validate53.errors);
errors = vErrors.length;
}
var valid0 = _errs15 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.min_refresh_ms !== undefined){
const _errs16 = errors;
if(!(validate53(data.min_refresh_ms, {instancePath:instancePath+"/min_refresh_ms",parentData:data,parentDataProperty:"min_refresh_ms",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate53.errors : vErrors.concat(validate53.errors);
errors = vErrors.length;
}
var valid0 = _errs16 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.max_request_bytes !== undefined){
const _errs17 = errors;
if(!(validate53(data.max_request_bytes, {instancePath:instancePath+"/max_request_bytes",parentData:data,parentDataProperty:"max_request_bytes",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate53.errors : vErrors.concat(validate53.errors);
errors = vErrors.length;
}
var valid0 = _errs17 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.state_resources !== undefined){
const _errs18 = errors;
if(typeof data.state_resources !== "boolean"){
validate357.errors = [{instancePath:instancePath+"/state_resources",schemaPath:"#/properties/state_resources/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"}];
return false;
}
var valid0 = _errs18 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.station !== undefined){
const _errs20 = errors;
if(typeof data.station !== "boolean"){
validate357.errors = [{instancePath:instancePath+"/station",schemaPath:"#/properties/station/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"}];
return false;
}
var valid0 = _errs20 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.http_connector !== undefined){
const _errs22 = errors;
if(typeof data.http_connector !== "boolean"){
validate357.errors = [{instancePath:instancePath+"/http_connector",schemaPath:"#/properties/http_connector/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"}];
return false;
}
var valid0 = _errs22 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.grpc_connector !== undefined){
const _errs24 = errors;
if(typeof data.grpc_connector !== "boolean"){
validate357.errors = [{instancePath:instancePath+"/grpc_connector",schemaPath:"#/properties/grpc_connector/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"}];
return false;
}
var valid0 = _errs24 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.documents !== undefined){
const _errs26 = errors;
if(typeof data.documents !== "boolean"){
validate357.errors = [{instancePath:instancePath+"/documents",schemaPath:"#/properties/documents/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"}];
return false;
}
var valid0 = _errs26 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.reactive_table !== undefined){
const _errs28 = errors;
if(typeof data.reactive_table !== "boolean"){
validate357.errors = [{instancePath:instancePath+"/reactive_table",schemaPath:"#/properties/reactive_table/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"}];
return false;
}
var valid0 = _errs28 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.push !== undefined){
const _errs30 = errors;
if(typeof data.push !== "boolean"){
validate357.errors = [{instancePath:instancePath+"/push",schemaPath:"#/properties/push/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"}];
return false;
}
var valid0 = _errs30 === errors;
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
}
}
}
else {
validate357.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate357.errors = vErrors;
return errors === 0;
}
validate357.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

export const Error = validate366;
const schema97 = {"type":"object","additionalProperties":false,"properties":{"err":{"type":"string","enum":["Forbidden","NotFound","InvalidQuery","QueryExpired","HistoryReclaimed","Unavailable","RateLimited","InvalidOrigin","UnsafePrincipal","StateResourceExpired","QueryDisabled","QueryBusy","UnsupportedQuery","QueryRequestTooLarge","IncompleteResult","InvalidQueryOrdinal","QueryConflict"]},"diagnostic":{"$ref":"https://transit.invalid/generated-validator/67"}},"required":["err","diagnostic"]};

function validate366(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate366.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if(((data.err === undefined) && (missing0 = "err")) || ((data.diagnostic === undefined) && (missing0 = "diagnostic"))){
validate366.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "err") || (key0 === "diagnostic"))){
validate366.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.err !== undefined){
let data0 = data.err;
const _errs2 = errors;
if(typeof data0 !== "string"){
validate366.errors = [{instancePath:instancePath+"/err",schemaPath:"#/properties/err/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
if(!(((((((((((((((((data0 === "Forbidden") || (data0 === "NotFound")) || (data0 === "InvalidQuery")) || (data0 === "QueryExpired")) || (data0 === "HistoryReclaimed")) || (data0 === "Unavailable")) || (data0 === "RateLimited")) || (data0 === "InvalidOrigin")) || (data0 === "UnsafePrincipal")) || (data0 === "StateResourceExpired")) || (data0 === "QueryDisabled")) || (data0 === "QueryBusy")) || (data0 === "UnsupportedQuery")) || (data0 === "QueryRequestTooLarge")) || (data0 === "IncompleteResult")) || (data0 === "InvalidQueryOrdinal")) || (data0 === "QueryConflict"))){
validate366.errors = [{instancePath:instancePath+"/err",schemaPath:"#/properties/err/enum",keyword:"enum",params:{allowedValues: schema97.properties.err.enum},message:"must be equal to one of the allowed values"}];
return false;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.diagnostic !== undefined){
const _errs4 = errors;
if(!(validate197(data.diagnostic, {instancePath:instancePath+"/diagnostic",parentData:data,parentDataProperty:"diagnostic",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate197.errors : vErrors.concat(validate197.errors);
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
else {
validate366.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate366.errors = vErrors;
return errors === 0;
}
validate366.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

export const AtlasResponse = validate368;
const schema98 = {"type":"object","additionalProperties":false,"properties":{"version":{"$ref":"https://transit.invalid/generated-validator/9"},"realm":{"$ref":"https://transit.invalid/generated-validator/1"},"position":{"$ref":"https://transit.invalid/generated-validator/1"},"identity":{"$ref":"https://transit.invalid/generated-validator/5"},"processes":{"type":"object","additionalProperties":false,"properties":{"entries":{"$ref":"https://transit.invalid/generated-validator/28"},"next":{"$ref":"https://transit.invalid/generated-validator/2"}},"required":["entries","next"]},"resources":{"type":"object","additionalProperties":false,"properties":{"entries":{"$ref":"https://transit.invalid/generated-validator/71"},"next":{"$ref":"https://transit.invalid/generated-validator/2"}},"required":["entries","next"]},"query_resource":{"$ref":"https://transit.invalid/generated-validator/2"},"query_version":{"anyOf":[{"$ref":"https://transit.invalid/generated-validator/9"},{"type":"null"}]}},"required":["version","realm","position","identity","processes","resources","query_resource","query_version"]};

function validate368(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate368.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if(((((((((data.version === undefined) && (missing0 = "version")) || ((data.realm === undefined) && (missing0 = "realm"))) || ((data.position === undefined) && (missing0 = "position"))) || ((data.identity === undefined) && (missing0 = "identity"))) || ((data.processes === undefined) && (missing0 = "processes"))) || ((data.resources === undefined) && (missing0 = "resources"))) || ((data.query_resource === undefined) && (missing0 = "query_resource"))) || ((data.query_version === undefined) && (missing0 = "query_version"))){
validate368.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((((((((key0 === "version") || (key0 === "realm")) || (key0 === "position")) || (key0 === "identity")) || (key0 === "processes")) || (key0 === "resources")) || (key0 === "query_resource")) || (key0 === "query_version"))){
validate368.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.version !== undefined){
const _errs2 = errors;
if(!(validate102(data.version, {instancePath:instancePath+"/version",parentData:data,parentDataProperty:"version",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate102.errors : vErrors.concat(validate102.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.realm !== undefined){
const _errs3 = errors;
if(!(validate55(data.realm, {instancePath:instancePath+"/realm",parentData:data,parentDataProperty:"realm",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate55.errors : vErrors.concat(validate55.errors);
errors = vErrors.length;
}
var valid0 = _errs3 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.position !== undefined){
const _errs4 = errors;
if(!(validate55(data.position, {instancePath:instancePath+"/position",parentData:data,parentDataProperty:"position",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate55.errors : vErrors.concat(validate55.errors);
errors = vErrors.length;
}
var valid0 = _errs4 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.identity !== undefined){
const _errs5 = errors;
if(!(validate65(data.identity, {instancePath:instancePath+"/identity",parentData:data,parentDataProperty:"identity",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate65.errors : vErrors.concat(validate65.errors);
errors = vErrors.length;
}
var valid0 = _errs5 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.processes !== undefined){
let data4 = data.processes;
const _errs6 = errors;
if(errors === _errs6){
if(data4 && typeof data4 == "object" && !Array.isArray(data4)){
let missing1;
if(((data4.entries === undefined) && (missing1 = "entries")) || ((data4.next === undefined) && (missing1 = "next"))){
validate368.errors = [{instancePath:instancePath+"/processes",schemaPath:"#/properties/processes/required",keyword:"required",params:{missingProperty: missing1},message:"must have required property '"+missing1+"'"}];
return false;
}
else {
const _errs8 = errors;
for(const key1 in data4){
if(!((key1 === "entries") || (key1 === "next"))){
validate368.errors = [{instancePath:instancePath+"/processes",schemaPath:"#/properties/processes/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key1},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs8 === errors){
if(data4.entries !== undefined){
const _errs9 = errors;
if(!(validate75(data4.entries, {instancePath:instancePath+"/processes/entries",parentData:data4,parentDataProperty:"entries",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate75.errors : vErrors.concat(validate75.errors);
errors = vErrors.length;
}
var valid1 = _errs9 === errors;
}
else {
var valid1 = true;
}
if(valid1){
if(data4.next !== undefined){
const _errs10 = errors;
if(!(validate57(data4.next, {instancePath:instancePath+"/processes/next",parentData:data4,parentDataProperty:"next",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate57.errors : vErrors.concat(validate57.errors);
errors = vErrors.length;
}
var valid1 = _errs10 === errors;
}
else {
var valid1 = true;
}
}
}
}
}
else {
validate368.errors = [{instancePath:instancePath+"/processes",schemaPath:"#/properties/processes/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
var valid0 = _errs6 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.resources !== undefined){
let data7 = data.resources;
const _errs11 = errors;
if(errors === _errs11){
if(data7 && typeof data7 == "object" && !Array.isArray(data7)){
let missing2;
if(((data7.entries === undefined) && (missing2 = "entries")) || ((data7.next === undefined) && (missing2 = "next"))){
validate368.errors = [{instancePath:instancePath+"/resources",schemaPath:"#/properties/resources/required",keyword:"required",params:{missingProperty: missing2},message:"must have required property '"+missing2+"'"}];
return false;
}
else {
const _errs13 = errors;
for(const key2 in data7){
if(!((key2 === "entries") || (key2 === "next"))){
validate368.errors = [{instancePath:instancePath+"/resources",schemaPath:"#/properties/resources/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key2},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs13 === errors){
if(data7.entries !== undefined){
const _errs14 = errors;
if(!(validate289(data7.entries, {instancePath:instancePath+"/resources/entries",parentData:data7,parentDataProperty:"entries",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate289.errors : vErrors.concat(validate289.errors);
errors = vErrors.length;
}
var valid2 = _errs14 === errors;
}
else {
var valid2 = true;
}
if(valid2){
if(data7.next !== undefined){
const _errs15 = errors;
if(!(validate57(data7.next, {instancePath:instancePath+"/resources/next",parentData:data7,parentDataProperty:"next",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate57.errors : vErrors.concat(validate57.errors);
errors = vErrors.length;
}
var valid2 = _errs15 === errors;
}
else {
var valid2 = true;
}
}
}
}
}
else {
validate368.errors = [{instancePath:instancePath+"/resources",schemaPath:"#/properties/resources/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
var valid0 = _errs11 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.query_resource !== undefined){
const _errs16 = errors;
if(!(validate57(data.query_resource, {instancePath:instancePath+"/query_resource",parentData:data,parentDataProperty:"query_resource",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate57.errors : vErrors.concat(validate57.errors);
errors = vErrors.length;
}
var valid0 = _errs16 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.query_version !== undefined){
let data11 = data.query_version;
const _errs17 = errors;
const _errs18 = errors;
let valid3 = false;
const _errs19 = errors;
if(!(validate102(data11, {instancePath:instancePath+"/query_version",parentData:data,parentDataProperty:"query_version",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate102.errors : vErrors.concat(validate102.errors);
errors = vErrors.length;
}
var _valid0 = _errs19 === errors;
valid3 = valid3 || _valid0;
const _errs20 = errors;
if(data11 !== null){
const err0 = {instancePath:instancePath+"/query_version",schemaPath:"#/properties/query_version/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err0];
}
else {
vErrors.push(err0);
}
errors++;
}
var _valid0 = _errs20 === errors;
valid3 = valid3 || _valid0;
if(!valid3){
const err1 = {instancePath:instancePath+"/query_version",schemaPath:"#/properties/query_version/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err1];
}
else {
vErrors.push(err1);
}
errors++;
validate368.errors = vErrors;
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
validate368.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate368.errors = vErrors;
return errors === 0;
}
validate368.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

export const ParticipationResponse = validate379;
const schema99 = {"type":"object","additionalProperties":false,"properties":{"version":{"$ref":"https://transit.invalid/generated-validator/9"},"realm":{"$ref":"https://transit.invalid/generated-validator/1"},"resource":{"$ref":"https://transit.invalid/generated-validator/69"},"resource_position":{"$ref":"https://transit.invalid/generated-validator/1"},"process_position":{"$ref":"https://transit.invalid/generated-validator/2"},"policy_revision":{"$ref":"https://transit.invalid/generated-validator/1"},"members":{"type":"array","minItems":8,"maxItems":8,"items":{"anyOf":[{"type":"object","additionalProperties":false,"properties":{"pid":{"$ref":"https://transit.invalid/generated-validator/1"},"association_position":{"$ref":"https://transit.invalid/generated-validator/1"},"matches":{"$ref":"https://transit.invalid/generated-validator/9"},"next":{"$ref":"https://transit.invalid/generated-validator/2"}},"required":["pid","association_position","matches","next"]},{"type":"null"}]}},"next":{"$ref":"https://transit.invalid/generated-validator/2"}},"required":["version","realm","resource","resource_position","process_position","policy_revision","members","next"]};

function validate379(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate379.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if(((((((((data.version === undefined) && (missing0 = "version")) || ((data.realm === undefined) && (missing0 = "realm"))) || ((data.resource === undefined) && (missing0 = "resource"))) || ((data.resource_position === undefined) && (missing0 = "resource_position"))) || ((data.process_position === undefined) && (missing0 = "process_position"))) || ((data.policy_revision === undefined) && (missing0 = "policy_revision"))) || ((data.members === undefined) && (missing0 = "members"))) || ((data.next === undefined) && (missing0 = "next"))){
validate379.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((((((((key0 === "version") || (key0 === "realm")) || (key0 === "resource")) || (key0 === "resource_position")) || (key0 === "process_position")) || (key0 === "policy_revision")) || (key0 === "members")) || (key0 === "next"))){
validate379.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.version !== undefined){
const _errs2 = errors;
if(!(validate102(data.version, {instancePath:instancePath+"/version",parentData:data,parentDataProperty:"version",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate102.errors : vErrors.concat(validate102.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.realm !== undefined){
const _errs3 = errors;
if(!(validate55(data.realm, {instancePath:instancePath+"/realm",parentData:data,parentDataProperty:"realm",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate55.errors : vErrors.concat(validate55.errors);
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
if(!(validate291(data.resource, {instancePath:instancePath+"/resource",parentData:data,parentDataProperty:"resource",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate291.errors : vErrors.concat(validate291.errors);
errors = vErrors.length;
}
var valid0 = _errs4 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.resource_position !== undefined){
const _errs5 = errors;
if(!(validate55(data.resource_position, {instancePath:instancePath+"/resource_position",parentData:data,parentDataProperty:"resource_position",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate55.errors : vErrors.concat(validate55.errors);
errors = vErrors.length;
}
var valid0 = _errs5 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.process_position !== undefined){
const _errs6 = errors;
if(!(validate57(data.process_position, {instancePath:instancePath+"/process_position",parentData:data,parentDataProperty:"process_position",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate57.errors : vErrors.concat(validate57.errors);
errors = vErrors.length;
}
var valid0 = _errs6 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.policy_revision !== undefined){
const _errs7 = errors;
if(!(validate55(data.policy_revision, {instancePath:instancePath+"/policy_revision",parentData:data,parentDataProperty:"policy_revision",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate55.errors : vErrors.concat(validate55.errors);
errors = vErrors.length;
}
var valid0 = _errs7 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.members !== undefined){
let data6 = data.members;
const _errs8 = errors;
if(errors === _errs8){
if(Array.isArray(data6)){
if(data6.length > 8){
validate379.errors = [{instancePath:instancePath+"/members",schemaPath:"#/properties/members/maxItems",keyword:"maxItems",params:{limit: 8},message:"must NOT have more than 8 items"}];
return false;
}
else {
if(data6.length < 8){
validate379.errors = [{instancePath:instancePath+"/members",schemaPath:"#/properties/members/minItems",keyword:"minItems",params:{limit: 8},message:"must NOT have fewer than 8 items"}];
return false;
}
else {
var valid1 = true;
const len0 = data6.length;
for(let i0=0; i0<len0; i0++){
let data7 = data6[i0];
const _errs10 = errors;
const _errs11 = errors;
let valid2 = false;
const _errs12 = errors;
if(errors === _errs12){
if(data7 && typeof data7 == "object" && !Array.isArray(data7)){
let missing1;
if(((((data7.pid === undefined) && (missing1 = "pid")) || ((data7.association_position === undefined) && (missing1 = "association_position"))) || ((data7.matches === undefined) && (missing1 = "matches"))) || ((data7.next === undefined) && (missing1 = "next"))){
const err0 = {instancePath:instancePath+"/members/" + i0,schemaPath:"#/properties/members/items/anyOf/0/required",keyword:"required",params:{missingProperty: missing1},message:"must have required property '"+missing1+"'"};
if(vErrors === null){
vErrors = [err0];
}
else {
vErrors.push(err0);
}
errors++;
}
else {
const _errs14 = errors;
for(const key1 in data7){
if(!((((key1 === "pid") || (key1 === "association_position")) || (key1 === "matches")) || (key1 === "next"))){
const err1 = {instancePath:instancePath+"/members/" + i0,schemaPath:"#/properties/members/items/anyOf/0/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key1},message:"must NOT have additional properties"};
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
if(_errs14 === errors){
if(data7.pid !== undefined){
const _errs15 = errors;
if(!(validate55(data7.pid, {instancePath:instancePath+"/members/" + i0+"/pid",parentData:data7,parentDataProperty:"pid",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate55.errors : vErrors.concat(validate55.errors);
errors = vErrors.length;
}
var valid3 = _errs15 === errors;
}
else {
var valid3 = true;
}
if(valid3){
if(data7.association_position !== undefined){
const _errs16 = errors;
if(!(validate55(data7.association_position, {instancePath:instancePath+"/members/" + i0+"/association_position",parentData:data7,parentDataProperty:"association_position",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate55.errors : vErrors.concat(validate55.errors);
errors = vErrors.length;
}
var valid3 = _errs16 === errors;
}
else {
var valid3 = true;
}
if(valid3){
if(data7.matches !== undefined){
const _errs17 = errors;
if(!(validate102(data7.matches, {instancePath:instancePath+"/members/" + i0+"/matches",parentData:data7,parentDataProperty:"matches",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate102.errors : vErrors.concat(validate102.errors);
errors = vErrors.length;
}
var valid3 = _errs17 === errors;
}
else {
var valid3 = true;
}
if(valid3){
if(data7.next !== undefined){
const _errs18 = errors;
if(!(validate57(data7.next, {instancePath:instancePath+"/members/" + i0+"/next",parentData:data7,parentDataProperty:"next",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate57.errors : vErrors.concat(validate57.errors);
errors = vErrors.length;
}
var valid3 = _errs18 === errors;
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
else {
const err2 = {instancePath:instancePath+"/members/" + i0,schemaPath:"#/properties/members/items/anyOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err2];
}
else {
vErrors.push(err2);
}
errors++;
}
}
var _valid0 = _errs12 === errors;
valid2 = valid2 || _valid0;
const _errs19 = errors;
if(data7 !== null){
const err3 = {instancePath:instancePath+"/members/" + i0,schemaPath:"#/properties/members/items/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err3];
}
else {
vErrors.push(err3);
}
errors++;
}
var _valid0 = _errs19 === errors;
valid2 = valid2 || _valid0;
if(!valid2){
const err4 = {instancePath:instancePath+"/members/" + i0,schemaPath:"#/properties/members/items/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err4];
}
else {
vErrors.push(err4);
}
errors++;
validate379.errors = vErrors;
return false;
}
else {
errors = _errs11;
if(vErrors !== null){
if(_errs11){
vErrors.length = _errs11;
}
else {
vErrors = null;
}
}
}
var valid1 = _errs10 === errors;
if(!valid1){
break;
}
}
}
}
}
else {
validate379.errors = [{instancePath:instancePath+"/members",schemaPath:"#/properties/members/type",keyword:"type",params:{type: "array"},message:"must be array"}];
return false;
}
}
var valid0 = _errs8 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.next !== undefined){
const _errs21 = errors;
if(!(validate57(data.next, {instancePath:instancePath+"/next",parentData:data,parentDataProperty:"next",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate57.errors : vErrors.concat(validate57.errors);
errors = vErrors.length;
}
var valid0 = _errs21 === errors;
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
validate379.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate379.errors = vErrors;
return errors === 0;
}
validate379.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

export const RecordsResponse = validate391;
const schema100 = {"type":"object","additionalProperties":false,"properties":{"version":{"$ref":"https://transit.invalid/generated-validator/9"},"realm":{"$ref":"https://transit.invalid/generated-validator/1"},"position":{"$ref":"https://transit.invalid/generated-validator/1"},"resource":{"$ref":"https://transit.invalid/generated-validator/69"},"page":{"type":"object","additionalProperties":false,"properties":{"entries":{"type":"array","minItems":8,"maxItems":8,"items":{"anyOf":[{"type":"object","additionalProperties":false,"properties":{"key":{"$ref":"https://transit.invalid/generated-validator/21"},"revision":{"$ref":"https://transit.invalid/generated-validator/1"}},"required":["key","revision"]},{"type":"null"}]}},"next":{"$ref":"https://transit.invalid/generated-validator/22"}},"required":["entries","next"]},"exchanges":{"type":"array","minItems":8,"maxItems":8,"items":{"anyOf":[{"type":"object","additionalProperties":false,"properties":{"version":{"$ref":"https://transit.invalid/generated-validator/9"},"source":{"$ref":"https://transit.invalid/generated-validator/72"},"declaration":{"oneOf":[{"type":"object","additionalProperties":false,"required":["failure"],"properties":{"failure":{"$ref":"https://transit.invalid/generated-validator/79"}}},{"type":"object","additionalProperties":false,"required":["capture"],"properties":{"capture":{"type":"object","additionalProperties":false,"properties":{"exchange":{"type":"string","maxLength":256},"protocol":{"$ref":"https://transit.invalid/generated-validator/0"},"phase":{"$ref":"https://transit.invalid/generated-validator/78"},"caller":{"$ref":"https://transit.invalid/generated-validator/1"},"input":{"$ref":"https://transit.invalid/generated-validator/1"},"owner":{"$ref":"https://transit.invalid/generated-validator/1"},"parent":{"type":"string","maxLength":256},"effect":{"$ref":"https://transit.invalid/generated-validator/1"},"attempt":{"$ref":"https://transit.invalid/generated-validator/1"},"executor":{"$ref":"https://transit.invalid/generated-validator/1"},"reconcile_before_ms":{"$ref":"https://transit.invalid/generated-validator/1"},"segments":{"$ref":"https://transit.invalid/generated-validator/0"},"max_segments":{"$ref":"https://transit.invalid/generated-validator/0"},"bytes":{"type":"string","maxLength":256},"capture_bytes":{"type":"string","maxLength":256},"segment_bytes":{"$ref":"https://transit.invalid/generated-validator/0"},"pending_kind":{"$ref":"https://transit.invalid/generated-validator/0"},"terminal_code":{"$ref":"https://transit.invalid/generated-validator/0"},"collected":{"$ref":"https://transit.invalid/generated-validator/0"},"coverage":{"$ref":"https://transit.invalid/generated-validator/11"}},"required":["exchange","protocol","phase","caller","input","owner","parent","effect","attempt","executor","reconcile_before_ms","segments","max_segments","bytes","capture_bytes","segment_bytes","pending_kind","terminal_code","collected","coverage"]}}},{"type":"object","additionalProperties":false,"required":["obligations"],"properties":{"obligations":{"type":"object","additionalProperties":false,"properties":{"exchange":{"type":"string","maxLength":256},"dependents":{"type":"string","maxLength":256},"disposition":{"type":"string","enum":["no_intent","pending","observed","cancelled","closed_unknown"]},"caller":{"type":"string","enum":["none","held","released"]},"effect":{"$ref":"https://transit.invalid/generated-validator/1"}},"required":["exchange","dependents","disposition","caller","effect"]}}},{"type":"object","additionalProperties":false,"required":["lineage"],"properties":{"lineage":{"type":"object","additionalProperties":false,"properties":{"exchange":{"type":"string","maxLength":256},"root":{"type":"string","maxLength":256},"parent":{"type":"string","maxLength":256},"ordinal":{"$ref":"https://transit.invalid/generated-validator/0"},"reason":{"type":"string","enum":["retry","redirect","reconcile","cancel"]},"policy":{"type":"string","maxLength":256},"policy_revision":{"type":"string","maxLength":256}},"required":["exchange","root","parent","ordinal","reason","policy","policy_revision"]}}},{"type":"object","additionalProperties":false,"required":["attempts"],"properties":{"attempts":{"type":"object","additionalProperties":false,"properties":{"exchange":{"type":"string","maxLength":256},"limit":{"$ref":"https://transit.invalid/generated-validator/0"},"used":{"$ref":"https://transit.invalid/generated-validator/0"},"unsettled":{"$ref":"https://transit.invalid/generated-validator/0"}},"required":["exchange","limit","used","unsettled"]}}}]}},"required":["version","source","declaration"]},{"type":"null"}]}},"documents":{"type":"array","minItems":8,"maxItems":8,"items":{"anyOf":[{"type":"object","additionalProperties":false,"properties":{"version":{"$ref":"https://transit.invalid/generated-validator/9"},"source":{"$ref":"https://transit.invalid/generated-validator/72"},"declaration":{"$ref":"https://transit.invalid/generated-validator/80"}},"required":["version","source","declaration"]},{"type":"null"}]}},"queries":{"type":"array","minItems":8,"maxItems":8,"items":{"anyOf":[{"type":"object","additionalProperties":false,"properties":{"version":{"$ref":"https://transit.invalid/generated-validator/9"},"source":{"$ref":"https://transit.invalid/generated-validator/72"},"declaration":{"oneOf":[{"type":"object","additionalProperties":false,"required":["execution"],"properties":{"execution":{"type":"object","additionalProperties":false,"properties":{"result":{"$ref":"https://transit.invalid/generated-validator/1"},"destination":{"$ref":"https://transit.invalid/generated-validator/1"},"correlation":{"$ref":"https://transit.invalid/generated-validator/1"},"source":{"$ref":"https://transit.invalid/generated-validator/81"},"request_resource":{"$ref":"https://transit.invalid/generated-validator/1"},"request_namespace":{"type":"string","maxLength":256},"phase":{"type":"string","enum":["capturing","captured","complete","cancelled","denied","failed","retired"]},"failure":{"$ref":"https://transit.invalid/generated-validator/86"},"policy_revision":{"$ref":"https://transit.invalid/generated-validator/1"}},"required":["result","destination","correlation","source","request_resource","request_namespace","phase","failure","policy_revision"]}}},{"type":"object","additionalProperties":false,"required":["request"],"properties":{"request":{"type":"object","additionalProperties":false,"properties":{"namespace":{"type":"string","maxLength":256},"correlation":{"$ref":"https://transit.invalid/generated-validator/1"},"phase":{"$ref":"https://transit.invalid/generated-validator/87"},"failure":{"$ref":"https://transit.invalid/generated-validator/86"},"collected":{"type":"boolean"},"result_resource":{"$ref":"https://transit.invalid/generated-validator/2"},"result_namespace":{"$ref":"https://transit.invalid/generated-validator/77"},"result_digest":{"$ref":"https://transit.invalid/generated-validator/15"}},"required":["namespace","correlation","phase","failure","collected","result_resource","result_namespace","result_digest"]}}},{"type":"object","additionalProperties":false,"required":["capture"],"properties":{"capture":{"type":"object","additionalProperties":false,"properties":{"result":{"$ref":"https://transit.invalid/generated-validator/1"},"destination":{"$ref":"https://transit.invalid/generated-validator/1"},"correlation":{"type":"string","maxLength":256},"table":{"$ref":"https://transit.invalid/generated-validator/0"},"source":{"$ref":"https://transit.invalid/generated-validator/81"},"policy_revision":{"type":"string","maxLength":256},"phase":{"$ref":"https://transit.invalid/generated-validator/74"},"bytes":{"type":"string","maxLength":256},"send_segment":{"type":"string","maxLength":256},"send_offset":{"$ref":"https://transit.invalid/generated-validator/4"},"chain":{"$ref":"https://transit.invalid/generated-validator/11"}},"required":["result","destination","correlation","table","source","policy_revision","phase","bytes","send_segment","send_offset","chain"]}}},{"type":"object","additionalProperties":false,"required":["manifest"],"properties":{"manifest":{"type":"object","additionalProperties":false,"properties":{"result":{"$ref":"https://transit.invalid/generated-validator/1"},"destination":{"$ref":"https://transit.invalid/generated-validator/1"},"correlation":{"type":"string","maxLength":256},"table":{"$ref":"https://transit.invalid/generated-validator/0"},"policy_revision":{"type":"string","maxLength":256},"basis":{"$ref":"https://transit.invalid/generated-validator/89"},"plan":{"$ref":"https://transit.invalid/generated-validator/11"},"segments":{"type":"string","maxLength":256},"bytes":{"type":"string","maxLength":256},"rows":{"type":"string","maxLength":256},"chain":{"$ref":"https://transit.invalid/generated-validator/11"},"schema":{"$ref":"https://transit.invalid/generated-validator/11"}},"required":["result","destination","correlation","table","policy_revision","basis","plan","segments","bytes","rows","chain","schema"]}}}]}},"required":["version","source","declaration"]},{"type":"null"}]}}},"required":["version","realm","position","resource","page","exchanges","documents","queries"]};
const schema101 = {"type":"object","additionalProperties":false,"properties":{"exchange":{"type":"string","maxLength":256},"resource":{"$ref":"https://transit.invalid/generated-validator/1"},"owner":{"$ref":"https://transit.invalid/generated-validator/1"},"principal":{"$ref":"https://transit.invalid/generated-validator/1"},"input":{"$ref":"https://transit.invalid/generated-validator/1"},"reason":{"$ref":"https://transit.invalid/generated-validator/75"},"operation":{"$ref":"https://transit.invalid/generated-validator/76"},"origin_input":{"$ref":"https://transit.invalid/generated-validator/1"},"kind":{"$ref":"https://transit.invalid/generated-validator/0"},"member":{"$ref":"https://transit.invalid/generated-validator/0"},"chunk":{"$ref":"https://transit.invalid/generated-validator/0"},"requested_bytes":{"$ref":"https://transit.invalid/generated-validator/0"},"cause":{"$ref":"https://transit.invalid/generated-validator/77"},"cause_truncated":{"type":"boolean"},"phase":{"$ref":"https://transit.invalid/generated-validator/78"},"effect":{"$ref":"https://transit.invalid/generated-validator/1"},"attempt":{"$ref":"https://transit.invalid/generated-validator/1"},"segments":{"$ref":"https://transit.invalid/generated-validator/0"},"bytes":{"type":"string","maxLength":256}},"required":["exchange","resource","owner","principal","input","reason","operation","origin_input","kind","member","chunk","requested_bytes","cause","cause_truncated","phase","effect","attempt","segments","bytes"]};
const schema102 = {"type":"string","enum":["caller_closed","controller_release","recovered_incomplete","transport_failure","capture_failure","preparation_failure"]};

function validate406(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate406.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate406.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
if(!((((((data === "caller_closed") || (data === "controller_release")) || (data === "recovered_incomplete")) || (data === "transport_failure")) || (data === "capture_failure")) || (data === "preparation_failure"))){
validate406.errors = [{instancePath,schemaPath:"#/enum",keyword:"enum",params:{allowedValues: schema102.enum},message:"must be equal to one of the allowed values"}];
return false;
}
validate406.errors = vErrors;
return errors === 0;
}
validate406.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema103 = {"type":"string","enum":["none","callback","begin","append","seal"]};

function validate408(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate408.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate408.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
if(!(((((data === "none") || (data === "callback")) || (data === "begin")) || (data === "append")) || (data === "seal"))){
validate408.errors = [{instancePath,schemaPath:"#/enum",keyword:"enum",params:{allowedValues: schema103.enum},message:"must be equal to one of the allowed values"}];
return false;
}
validate408.errors = vErrors;
return errors === 0;
}
validate408.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema104 = {"anyOf":[{"type":"string","maxLength":256},{"type":"null"}]};

function validate415(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate415.evaluated;
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
if(func4(data) > 256){
const err0 = {instancePath,schemaPath:"#/anyOf/0/maxLength",keyword:"maxLength",params:{limit: 256},message:"must NOT have more than 256 characters"};
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
validate415.errors = vErrors;
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
validate415.errors = vErrors;
return errors === 0;
}
validate415.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema105 = {"type":"string","enum":["preparing","capturing","complete","unknown","retired","ready"]};

function validate417(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate417.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate417.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
if(!((((((data === "preparing") || (data === "capturing")) || (data === "complete")) || (data === "unknown")) || (data === "retired")) || (data === "ready"))){
validate417.errors = [{instancePath,schemaPath:"#/enum",keyword:"enum",params:{allowedValues: schema105.enum},message:"must be equal to one of the allowed values"}];
return false;
}
validate417.errors = vErrors;
return errors === 0;
}
validate417.evaluated = {"dynamicProps":false,"dynamicItems":false};


function validate401(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate401.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((((((((((((((((((((data.exchange === undefined) && (missing0 = "exchange")) || ((data.resource === undefined) && (missing0 = "resource"))) || ((data.owner === undefined) && (missing0 = "owner"))) || ((data.principal === undefined) && (missing0 = "principal"))) || ((data.input === undefined) && (missing0 = "input"))) || ((data.reason === undefined) && (missing0 = "reason"))) || ((data.operation === undefined) && (missing0 = "operation"))) || ((data.origin_input === undefined) && (missing0 = "origin_input"))) || ((data.kind === undefined) && (missing0 = "kind"))) || ((data.member === undefined) && (missing0 = "member"))) || ((data.chunk === undefined) && (missing0 = "chunk"))) || ((data.requested_bytes === undefined) && (missing0 = "requested_bytes"))) || ((data.cause === undefined) && (missing0 = "cause"))) || ((data.cause_truncated === undefined) && (missing0 = "cause_truncated"))) || ((data.phase === undefined) && (missing0 = "phase"))) || ((data.effect === undefined) && (missing0 = "effect"))) || ((data.attempt === undefined) && (missing0 = "attempt"))) || ((data.segments === undefined) && (missing0 = "segments"))) || ((data.bytes === undefined) && (missing0 = "bytes"))){
validate401.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(func1.call(schema101.properties, key0))){
validate401.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.exchange !== undefined){
let data0 = data.exchange;
const _errs2 = errors;
if(errors === _errs2){
if(typeof data0 === "string"){
if(func4(data0) > 256){
validate401.errors = [{instancePath:instancePath+"/exchange",schemaPath:"#/properties/exchange/maxLength",keyword:"maxLength",params:{limit: 256},message:"must NOT have more than 256 characters"}];
return false;
}
}
else {
validate401.errors = [{instancePath:instancePath+"/exchange",schemaPath:"#/properties/exchange/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.resource !== undefined){
const _errs4 = errors;
if(!(validate55(data.resource, {instancePath:instancePath+"/resource",parentData:data,parentDataProperty:"resource",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate55.errors : vErrors.concat(validate55.errors);
errors = vErrors.length;
}
var valid0 = _errs4 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.owner !== undefined){
const _errs5 = errors;
if(!(validate55(data.owner, {instancePath:instancePath+"/owner",parentData:data,parentDataProperty:"owner",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate55.errors : vErrors.concat(validate55.errors);
errors = vErrors.length;
}
var valid0 = _errs5 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.principal !== undefined){
const _errs6 = errors;
if(!(validate55(data.principal, {instancePath:instancePath+"/principal",parentData:data,parentDataProperty:"principal",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate55.errors : vErrors.concat(validate55.errors);
errors = vErrors.length;
}
var valid0 = _errs6 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.input !== undefined){
const _errs7 = errors;
if(!(validate55(data.input, {instancePath:instancePath+"/input",parentData:data,parentDataProperty:"input",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate55.errors : vErrors.concat(validate55.errors);
errors = vErrors.length;
}
var valid0 = _errs7 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.reason !== undefined){
const _errs8 = errors;
if(!(validate406(data.reason, {instancePath:instancePath+"/reason",parentData:data,parentDataProperty:"reason",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate406.errors : vErrors.concat(validate406.errors);
errors = vErrors.length;
}
var valid0 = _errs8 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.operation !== undefined){
const _errs9 = errors;
if(!(validate408(data.operation, {instancePath:instancePath+"/operation",parentData:data,parentDataProperty:"operation",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate408.errors : vErrors.concat(validate408.errors);
errors = vErrors.length;
}
var valid0 = _errs9 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.origin_input !== undefined){
const _errs10 = errors;
if(!(validate55(data.origin_input, {instancePath:instancePath+"/origin_input",parentData:data,parentDataProperty:"origin_input",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate55.errors : vErrors.concat(validate55.errors);
errors = vErrors.length;
}
var valid0 = _errs10 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.kind !== undefined){
const _errs11 = errors;
if(!(validate53(data.kind, {instancePath:instancePath+"/kind",parentData:data,parentDataProperty:"kind",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate53.errors : vErrors.concat(validate53.errors);
errors = vErrors.length;
}
var valid0 = _errs11 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.member !== undefined){
const _errs12 = errors;
if(!(validate53(data.member, {instancePath:instancePath+"/member",parentData:data,parentDataProperty:"member",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate53.errors : vErrors.concat(validate53.errors);
errors = vErrors.length;
}
var valid0 = _errs12 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.chunk !== undefined){
const _errs13 = errors;
if(!(validate53(data.chunk, {instancePath:instancePath+"/chunk",parentData:data,parentDataProperty:"chunk",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate53.errors : vErrors.concat(validate53.errors);
errors = vErrors.length;
}
var valid0 = _errs13 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.requested_bytes !== undefined){
const _errs14 = errors;
if(!(validate53(data.requested_bytes, {instancePath:instancePath+"/requested_bytes",parentData:data,parentDataProperty:"requested_bytes",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate53.errors : vErrors.concat(validate53.errors);
errors = vErrors.length;
}
var valid0 = _errs14 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.cause !== undefined){
const _errs15 = errors;
if(!(validate415(data.cause, {instancePath:instancePath+"/cause",parentData:data,parentDataProperty:"cause",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate415.errors : vErrors.concat(validate415.errors);
errors = vErrors.length;
}
var valid0 = _errs15 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.cause_truncated !== undefined){
const _errs16 = errors;
if(typeof data.cause_truncated !== "boolean"){
validate401.errors = [{instancePath:instancePath+"/cause_truncated",schemaPath:"#/properties/cause_truncated/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"}];
return false;
}
var valid0 = _errs16 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.phase !== undefined){
const _errs18 = errors;
if(!(validate417(data.phase, {instancePath:instancePath+"/phase",parentData:data,parentDataProperty:"phase",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate417.errors : vErrors.concat(validate417.errors);
errors = vErrors.length;
}
var valid0 = _errs18 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.effect !== undefined){
const _errs19 = errors;
if(!(validate55(data.effect, {instancePath:instancePath+"/effect",parentData:data,parentDataProperty:"effect",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate55.errors : vErrors.concat(validate55.errors);
errors = vErrors.length;
}
var valid0 = _errs19 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.attempt !== undefined){
const _errs20 = errors;
if(!(validate55(data.attempt, {instancePath:instancePath+"/attempt",parentData:data,parentDataProperty:"attempt",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate55.errors : vErrors.concat(validate55.errors);
errors = vErrors.length;
}
var valid0 = _errs20 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.segments !== undefined){
const _errs21 = errors;
if(!(validate53(data.segments, {instancePath:instancePath+"/segments",parentData:data,parentDataProperty:"segments",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate53.errors : vErrors.concat(validate53.errors);
errors = vErrors.length;
}
var valid0 = _errs21 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.bytes !== undefined){
let data18 = data.bytes;
const _errs22 = errors;
if(errors === _errs22){
if(typeof data18 === "string"){
if(func4(data18) > 256){
validate401.errors = [{instancePath:instancePath+"/bytes",schemaPath:"#/properties/bytes/maxLength",keyword:"maxLength",params:{limit: 256},message:"must NOT have more than 256 characters"}];
return false;
}
}
else {
validate401.errors = [{instancePath:instancePath+"/bytes",schemaPath:"#/properties/bytes/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
}
var valid0 = _errs22 === errors;
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
}
}
}
else {
validate401.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate401.errors = vErrors;
return errors === 0;
}
validate401.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema106 = {"type":"object","additionalProperties":false,"properties":{"document":{"type":"string","maxLength":256},"epoch":{"type":"string","maxLength":256},"type_revision":{"$ref":"https://transit.invalid/generated-validator/0"},"change_format":{"$ref":"https://transit.invalid/generated-validator/0"},"revision":{"type":"string","maxLength":256},"floor":{"type":"string","maxLength":256},"merge_window":{"type":"string","maxLength":256},"active_job":{"type":"string","maxLength":256},"retired":{"type":"boolean"}},"required":["document","epoch","type_revision","change_format","revision","floor","merge_window","active_job","retired"]};

function validate446(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate446.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((((((((((data.document === undefined) && (missing0 = "document")) || ((data.epoch === undefined) && (missing0 = "epoch"))) || ((data.type_revision === undefined) && (missing0 = "type_revision"))) || ((data.change_format === undefined) && (missing0 = "change_format"))) || ((data.revision === undefined) && (missing0 = "revision"))) || ((data.floor === undefined) && (missing0 = "floor"))) || ((data.merge_window === undefined) && (missing0 = "merge_window"))) || ((data.active_job === undefined) && (missing0 = "active_job"))) || ((data.retired === undefined) && (missing0 = "retired"))){
validate446.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(func1.call(schema106.properties, key0))){
validate446.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.document !== undefined){
let data0 = data.document;
const _errs2 = errors;
if(errors === _errs2){
if(typeof data0 === "string"){
if(func4(data0) > 256){
validate446.errors = [{instancePath:instancePath+"/document",schemaPath:"#/properties/document/maxLength",keyword:"maxLength",params:{limit: 256},message:"must NOT have more than 256 characters"}];
return false;
}
}
else {
validate446.errors = [{instancePath:instancePath+"/document",schemaPath:"#/properties/document/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.epoch !== undefined){
let data1 = data.epoch;
const _errs4 = errors;
if(errors === _errs4){
if(typeof data1 === "string"){
if(func4(data1) > 256){
validate446.errors = [{instancePath:instancePath+"/epoch",schemaPath:"#/properties/epoch/maxLength",keyword:"maxLength",params:{limit: 256},message:"must NOT have more than 256 characters"}];
return false;
}
}
else {
validate446.errors = [{instancePath:instancePath+"/epoch",schemaPath:"#/properties/epoch/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
}
var valid0 = _errs4 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.type_revision !== undefined){
const _errs6 = errors;
if(!(validate53(data.type_revision, {instancePath:instancePath+"/type_revision",parentData:data,parentDataProperty:"type_revision",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate53.errors : vErrors.concat(validate53.errors);
errors = vErrors.length;
}
var valid0 = _errs6 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.change_format !== undefined){
const _errs7 = errors;
if(!(validate53(data.change_format, {instancePath:instancePath+"/change_format",parentData:data,parentDataProperty:"change_format",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate53.errors : vErrors.concat(validate53.errors);
errors = vErrors.length;
}
var valid0 = _errs7 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.revision !== undefined){
let data4 = data.revision;
const _errs8 = errors;
if(errors === _errs8){
if(typeof data4 === "string"){
if(func4(data4) > 256){
validate446.errors = [{instancePath:instancePath+"/revision",schemaPath:"#/properties/revision/maxLength",keyword:"maxLength",params:{limit: 256},message:"must NOT have more than 256 characters"}];
return false;
}
}
else {
validate446.errors = [{instancePath:instancePath+"/revision",schemaPath:"#/properties/revision/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
}
var valid0 = _errs8 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.floor !== undefined){
let data5 = data.floor;
const _errs10 = errors;
if(errors === _errs10){
if(typeof data5 === "string"){
if(func4(data5) > 256){
validate446.errors = [{instancePath:instancePath+"/floor",schemaPath:"#/properties/floor/maxLength",keyword:"maxLength",params:{limit: 256},message:"must NOT have more than 256 characters"}];
return false;
}
}
else {
validate446.errors = [{instancePath:instancePath+"/floor",schemaPath:"#/properties/floor/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
}
var valid0 = _errs10 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.merge_window !== undefined){
let data6 = data.merge_window;
const _errs12 = errors;
if(errors === _errs12){
if(typeof data6 === "string"){
if(func4(data6) > 256){
validate446.errors = [{instancePath:instancePath+"/merge_window",schemaPath:"#/properties/merge_window/maxLength",keyword:"maxLength",params:{limit: 256},message:"must NOT have more than 256 characters"}];
return false;
}
}
else {
validate446.errors = [{instancePath:instancePath+"/merge_window",schemaPath:"#/properties/merge_window/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
}
var valid0 = _errs12 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.active_job !== undefined){
let data7 = data.active_job;
const _errs14 = errors;
if(errors === _errs14){
if(typeof data7 === "string"){
if(func4(data7) > 256){
validate446.errors = [{instancePath:instancePath+"/active_job",schemaPath:"#/properties/active_job/maxLength",keyword:"maxLength",params:{limit: 256},message:"must NOT have more than 256 characters"}];
return false;
}
}
else {
validate446.errors = [{instancePath:instancePath+"/active_job",schemaPath:"#/properties/active_job/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
}
var valid0 = _errs14 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.retired !== undefined){
const _errs16 = errors;
if(typeof data.retired !== "boolean"){
validate446.errors = [{instancePath:instancePath+"/retired",schemaPath:"#/properties/retired/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"}];
return false;
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
else {
validate446.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate446.errors = vErrors;
return errors === 0;
}
validate446.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema107 = {"type":"object","additionalProperties":false,"properties":{"pid":{"$ref":"https://transit.invalid/generated-validator/1"},"input":{"$ref":"https://transit.invalid/generated-validator/1"},"index":{"$ref":"https://transit.invalid/generated-validator/9"}},"required":["pid","input","index"]};

function validate455(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate455.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((((data.pid === undefined) && (missing0 = "pid")) || ((data.input === undefined) && (missing0 = "input"))) || ((data.index === undefined) && (missing0 = "index"))){
validate455.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "pid") || (key0 === "input")) || (key0 === "index"))){
validate455.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.pid !== undefined){
const _errs2 = errors;
if(!(validate55(data.pid, {instancePath:instancePath+"/pid",parentData:data,parentDataProperty:"pid",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate55.errors : vErrors.concat(validate55.errors);
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
if(!(validate55(data.input, {instancePath:instancePath+"/input",parentData:data,parentDataProperty:"input",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate55.errors : vErrors.concat(validate55.errors);
errors = vErrors.length;
}
var valid0 = _errs3 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.index !== undefined){
const _errs4 = errors;
if(!(validate102(data.index, {instancePath:instancePath+"/index",parentData:data,parentDataProperty:"index",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate102.errors : vErrors.concat(validate102.errors);
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
validate455.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate455.errors = vErrors;
return errors === 0;
}
validate455.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema108 = {"anyOf":[{"$ref":"https://transit.invalid/generated-validator/85"},{"type":"null"}]};
const schema109 = {"type":"object","additionalProperties":false,"properties":{"code":{"$ref":"https://transit.invalid/generated-validator/82"},"stage":{"$ref":"https://transit.invalid/generated-validator/83"},"dimension":{"$ref":"https://transit.invalid/generated-validator/84"},"limit":{"type":"string","maxLength":256},"observed":{"type":"string","maxLength":256}},"required":["code","stage","dimension","limit","observed"]};
const schema110 = {"type":"string","enum":["policy_denied","access_denied","resource_unavailable","request_unpublished","publisher_mismatch","document_history_gap","document_retired","document_resync_required","budget_exceeded","projection_budget","expansion_missing","expansion_null","expansion_conflict","expansion_type_error","cell_type_error","cell_conflict","arithmetic_overflow","segment_byte_limit","type_mismatch","unsupported_aggregate","unknown_column","invalid_projection","duplicate_projection","invalid_bundle","invalid_source","invalid_prefix","invalid_path","invalid_projection_budget","invalid_text_projection","invalid_element_projection","unsupported_source","unsupported_decoder","unsupported_document_source","invalid_source_encoding","invalid_plan_encoding","plan_definition_mismatch","invalid_output_names","unsupported_plan","plan_too_large","bundle_too_large","truncated_input","source_changed","table_schema_changed","invalid_budget","namespace_in_use","query_after_mutation","nonfinite_value","invalid_utf8","cell_too_large","invalid_column_name","invalid_column_count","duplicate_column","unsupported_schema","peer_mismatch","invalid_request_reference","writer_not_ready","request_resource_expired","request_resource_missing"]};

function validate463(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate463.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate463.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
if(!((((((((((((((((((((((((((((((((((((((((((((((((((((((((((data === "policy_denied") || (data === "access_denied")) || (data === "resource_unavailable")) || (data === "request_unpublished")) || (data === "publisher_mismatch")) || (data === "document_history_gap")) || (data === "document_retired")) || (data === "document_resync_required")) || (data === "budget_exceeded")) || (data === "projection_budget")) || (data === "expansion_missing")) || (data === "expansion_null")) || (data === "expansion_conflict")) || (data === "expansion_type_error")) || (data === "cell_type_error")) || (data === "cell_conflict")) || (data === "arithmetic_overflow")) || (data === "segment_byte_limit")) || (data === "type_mismatch")) || (data === "unsupported_aggregate")) || (data === "unknown_column")) || (data === "invalid_projection")) || (data === "duplicate_projection")) || (data === "invalid_bundle")) || (data === "invalid_source")) || (data === "invalid_prefix")) || (data === "invalid_path")) || (data === "invalid_projection_budget")) || (data === "invalid_text_projection")) || (data === "invalid_element_projection")) || (data === "unsupported_source")) || (data === "unsupported_decoder")) || (data === "unsupported_document_source")) || (data === "invalid_source_encoding")) || (data === "invalid_plan_encoding")) || (data === "plan_definition_mismatch")) || (data === "invalid_output_names")) || (data === "unsupported_plan")) || (data === "plan_too_large")) || (data === "bundle_too_large")) || (data === "truncated_input")) || (data === "source_changed")) || (data === "table_schema_changed")) || (data === "invalid_budget")) || (data === "namespace_in_use")) || (data === "query_after_mutation")) || (data === "nonfinite_value")) || (data === "invalid_utf8")) || (data === "cell_too_large")) || (data === "invalid_column_name")) || (data === "invalid_column_count")) || (data === "duplicate_column")) || (data === "unsupported_schema")) || (data === "peer_mismatch")) || (data === "invalid_request_reference")) || (data === "writer_not_ready")) || (data === "request_resource_expired")) || (data === "request_resource_missing"))){
validate463.errors = [{instancePath,schemaPath:"#/enum",keyword:"enum",params:{allowedValues: schema110.enum},message:"must be equal to one of the allowed values"}];
return false;
}
validate463.errors = vErrors;
return errors === 0;
}
validate463.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema111 = {"type":"string","enum":["admission","execution"]};

function validate465(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate465.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate465.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
if(!((data === "admission") || (data === "execution"))){
validate465.errors = [{instancePath,schemaPath:"#/enum",keyword:"enum",params:{allowedValues: schema111.enum},message:"must be equal to one of the allowed values"}];
return false;
}
validate465.errors = vErrors;
return errors === 0;
}
validate465.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema112 = {"type":"string","enum":["none","pages","segments","result_bytes"]};

function validate467(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate467.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate467.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
if(!((((data === "none") || (data === "pages")) || (data === "segments")) || (data === "result_bytes"))){
validate467.errors = [{instancePath,schemaPath:"#/enum",keyword:"enum",params:{allowedValues: schema112.enum},message:"must be equal to one of the allowed values"}];
return false;
}
validate467.errors = vErrors;
return errors === 0;
}
validate467.evaluated = {"dynamicProps":false,"dynamicItems":false};


function validate462(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate462.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((((((data.code === undefined) && (missing0 = "code")) || ((data.stage === undefined) && (missing0 = "stage"))) || ((data.dimension === undefined) && (missing0 = "dimension"))) || ((data.limit === undefined) && (missing0 = "limit"))) || ((data.observed === undefined) && (missing0 = "observed"))){
validate462.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((((key0 === "code") || (key0 === "stage")) || (key0 === "dimension")) || (key0 === "limit")) || (key0 === "observed"))){
validate462.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.code !== undefined){
const _errs2 = errors;
if(!(validate463(data.code, {instancePath:instancePath+"/code",parentData:data,parentDataProperty:"code",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate463.errors : vErrors.concat(validate463.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.stage !== undefined){
const _errs3 = errors;
if(!(validate465(data.stage, {instancePath:instancePath+"/stage",parentData:data,parentDataProperty:"stage",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate465.errors : vErrors.concat(validate465.errors);
errors = vErrors.length;
}
var valid0 = _errs3 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.dimension !== undefined){
const _errs4 = errors;
if(!(validate467(data.dimension, {instancePath:instancePath+"/dimension",parentData:data,parentDataProperty:"dimension",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate467.errors : vErrors.concat(validate467.errors);
errors = vErrors.length;
}
var valid0 = _errs4 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.limit !== undefined){
let data3 = data.limit;
const _errs5 = errors;
if(errors === _errs5){
if(typeof data3 === "string"){
if(func4(data3) > 256){
validate462.errors = [{instancePath:instancePath+"/limit",schemaPath:"#/properties/limit/maxLength",keyword:"maxLength",params:{limit: 256},message:"must NOT have more than 256 characters"}];
return false;
}
}
else {
validate462.errors = [{instancePath:instancePath+"/limit",schemaPath:"#/properties/limit/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
}
var valid0 = _errs5 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.observed !== undefined){
let data4 = data.observed;
const _errs7 = errors;
if(errors === _errs7){
if(typeof data4 === "string"){
if(func4(data4) > 256){
validate462.errors = [{instancePath:instancePath+"/observed",schemaPath:"#/properties/observed/maxLength",keyword:"maxLength",params:{limit: 256},message:"must NOT have more than 256 characters"}];
return false;
}
}
else {
validate462.errors = [{instancePath:instancePath+"/observed",schemaPath:"#/properties/observed/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
}
var valid0 = _errs7 === errors;
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
validate462.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate462.errors = vErrors;
return errors === 0;
}
validate462.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate461(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate461.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate462(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate462.errors : vErrors.concat(validate462.errors);
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
validate461.errors = vErrors;
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
validate461.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate461.evaluated = {"dynamicProps":true,"dynamicItems":false};

const schema113 = {"type":"string","enum":["uploading","sealed","admitted","complete","cancelled","denied","rejected","retired"]};

function validate473(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate473.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate473.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
if(!((((((((data === "uploading") || (data === "sealed")) || (data === "admitted")) || (data === "complete")) || (data === "cancelled")) || (data === "denied")) || (data === "rejected")) || (data === "retired"))){
validate473.errors = [{instancePath,schemaPath:"#/enum",keyword:"enum",params:{allowedValues: schema113.enum},message:"must be equal to one of the allowed values"}];
return false;
}
validate473.errors = vErrors;
return errors === 0;
}
validate473.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema114 = {"type":"object","additionalProperties":false,"properties":{"kind":{"$ref":"https://transit.invalid/generated-validator/88"},"resource":{"$ref":"https://transit.invalid/generated-validator/1"},"revision":{"$ref":"https://transit.invalid/generated-validator/1"},"contract":{"$ref":"https://transit.invalid/generated-validator/11"},"schema":{"$ref":"https://transit.invalid/generated-validator/11"}},"required":["kind","resource","revision","contract","schema"]};
const schema115 = {"type":"string","enum":["kv","table","document"]};

function validate490(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate490.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate490.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
if(!(((data === "kv") || (data === "table")) || (data === "document"))){
validate490.errors = [{instancePath,schemaPath:"#/enum",keyword:"enum",params:{allowedValues: schema115.enum},message:"must be equal to one of the allowed values"}];
return false;
}
validate490.errors = vErrors;
return errors === 0;
}
validate490.evaluated = {"dynamicProps":false,"dynamicItems":false};


function validate489(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate489.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((((((data.kind === undefined) && (missing0 = "kind")) || ((data.resource === undefined) && (missing0 = "resource"))) || ((data.revision === undefined) && (missing0 = "revision"))) || ((data.contract === undefined) && (missing0 = "contract"))) || ((data.schema === undefined) && (missing0 = "schema"))){
validate489.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((((key0 === "kind") || (key0 === "resource")) || (key0 === "revision")) || (key0 === "contract")) || (key0 === "schema"))){
validate489.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.kind !== undefined){
const _errs2 = errors;
if(!(validate490(data.kind, {instancePath:instancePath+"/kind",parentData:data,parentDataProperty:"kind",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate490.errors : vErrors.concat(validate490.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.resource !== undefined){
const _errs3 = errors;
if(!(validate55(data.resource, {instancePath:instancePath+"/resource",parentData:data,parentDataProperty:"resource",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate55.errors : vErrors.concat(validate55.errors);
errors = vErrors.length;
}
var valid0 = _errs3 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.revision !== undefined){
const _errs4 = errors;
if(!(validate55(data.revision, {instancePath:instancePath+"/revision",parentData:data,parentDataProperty:"revision",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate55.errors : vErrors.concat(validate55.errors);
errors = vErrors.length;
}
var valid0 = _errs4 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.contract !== undefined){
const _errs5 = errors;
if(!(validate105(data.contract, {instancePath:instancePath+"/contract",parentData:data,parentDataProperty:"contract",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate105.errors : vErrors.concat(validate105.errors);
errors = vErrors.length;
}
var valid0 = _errs5 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.schema !== undefined){
const _errs6 = errors;
if(!(validate105(data.schema, {instancePath:instancePath+"/schema",parentData:data,parentDataProperty:"schema",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate105.errors : vErrors.concat(validate105.errors);
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
validate489.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate489.errors = vErrors;
return errors === 0;
}
validate489.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate391(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate391.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if(((((((((data.version === undefined) && (missing0 = "version")) || ((data.realm === undefined) && (missing0 = "realm"))) || ((data.position === undefined) && (missing0 = "position"))) || ((data.resource === undefined) && (missing0 = "resource"))) || ((data.page === undefined) && (missing0 = "page"))) || ((data.exchanges === undefined) && (missing0 = "exchanges"))) || ((data.documents === undefined) && (missing0 = "documents"))) || ((data.queries === undefined) && (missing0 = "queries"))){
validate391.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((((((((key0 === "version") || (key0 === "realm")) || (key0 === "position")) || (key0 === "resource")) || (key0 === "page")) || (key0 === "exchanges")) || (key0 === "documents")) || (key0 === "queries"))){
validate391.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.version !== undefined){
const _errs2 = errors;
if(!(validate102(data.version, {instancePath:instancePath+"/version",parentData:data,parentDataProperty:"version",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate102.errors : vErrors.concat(validate102.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.realm !== undefined){
const _errs3 = errors;
if(!(validate55(data.realm, {instancePath:instancePath+"/realm",parentData:data,parentDataProperty:"realm",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate55.errors : vErrors.concat(validate55.errors);
errors = vErrors.length;
}
var valid0 = _errs3 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.position !== undefined){
const _errs4 = errors;
if(!(validate55(data.position, {instancePath:instancePath+"/position",parentData:data,parentDataProperty:"position",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate55.errors : vErrors.concat(validate55.errors);
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
if(!(validate291(data.resource, {instancePath:instancePath+"/resource",parentData:data,parentDataProperty:"resource",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate291.errors : vErrors.concat(validate291.errors);
errors = vErrors.length;
}
var valid0 = _errs5 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.page !== undefined){
let data4 = data.page;
const _errs6 = errors;
if(errors === _errs6){
if(data4 && typeof data4 == "object" && !Array.isArray(data4)){
let missing1;
if(((data4.entries === undefined) && (missing1 = "entries")) || ((data4.next === undefined) && (missing1 = "next"))){
validate391.errors = [{instancePath:instancePath+"/page",schemaPath:"#/properties/page/required",keyword:"required",params:{missingProperty: missing1},message:"must have required property '"+missing1+"'"}];
return false;
}
else {
const _errs8 = errors;
for(const key1 in data4){
if(!((key1 === "entries") || (key1 === "next"))){
validate391.errors = [{instancePath:instancePath+"/page",schemaPath:"#/properties/page/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key1},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs8 === errors){
if(data4.entries !== undefined){
let data5 = data4.entries;
const _errs9 = errors;
if(errors === _errs9){
if(Array.isArray(data5)){
if(data5.length > 8){
validate391.errors = [{instancePath:instancePath+"/page/entries",schemaPath:"#/properties/page/properties/entries/maxItems",keyword:"maxItems",params:{limit: 8},message:"must NOT have more than 8 items"}];
return false;
}
else {
if(data5.length < 8){
validate391.errors = [{instancePath:instancePath+"/page/entries",schemaPath:"#/properties/page/properties/entries/minItems",keyword:"minItems",params:{limit: 8},message:"must NOT have fewer than 8 items"}];
return false;
}
else {
var valid2 = true;
const len0 = data5.length;
for(let i0=0; i0<len0; i0++){
let data6 = data5[i0];
const _errs11 = errors;
const _errs12 = errors;
let valid3 = false;
const _errs13 = errors;
if(errors === _errs13){
if(data6 && typeof data6 == "object" && !Array.isArray(data6)){
let missing2;
if(((data6.key === undefined) && (missing2 = "key")) || ((data6.revision === undefined) && (missing2 = "revision"))){
const err0 = {instancePath:instancePath+"/page/entries/" + i0,schemaPath:"#/properties/page/properties/entries/items/anyOf/0/required",keyword:"required",params:{missingProperty: missing2},message:"must have required property '"+missing2+"'"};
if(vErrors === null){
vErrors = [err0];
}
else {
vErrors.push(err0);
}
errors++;
}
else {
const _errs15 = errors;
for(const key2 in data6){
if(!((key2 === "key") || (key2 === "revision"))){
const err1 = {instancePath:instancePath+"/page/entries/" + i0,schemaPath:"#/properties/page/properties/entries/items/anyOf/0/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key2},message:"must NOT have additional properties"};
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
if(_errs15 === errors){
if(data6.key !== undefined){
const _errs16 = errors;
if(!(validate134(data6.key, {instancePath:instancePath+"/page/entries/" + i0+"/key",parentData:data6,parentDataProperty:"key",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate134.errors : vErrors.concat(validate134.errors);
errors = vErrors.length;
}
var valid4 = _errs16 === errors;
}
else {
var valid4 = true;
}
if(valid4){
if(data6.revision !== undefined){
const _errs17 = errors;
if(!(validate55(data6.revision, {instancePath:instancePath+"/page/entries/" + i0+"/revision",parentData:data6,parentDataProperty:"revision",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate55.errors : vErrors.concat(validate55.errors);
errors = vErrors.length;
}
var valid4 = _errs17 === errors;
}
else {
var valid4 = true;
}
}
}
}
}
else {
const err2 = {instancePath:instancePath+"/page/entries/" + i0,schemaPath:"#/properties/page/properties/entries/items/anyOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err2];
}
else {
vErrors.push(err2);
}
errors++;
}
}
var _valid0 = _errs13 === errors;
valid3 = valid3 || _valid0;
const _errs18 = errors;
if(data6 !== null){
const err3 = {instancePath:instancePath+"/page/entries/" + i0,schemaPath:"#/properties/page/properties/entries/items/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err3];
}
else {
vErrors.push(err3);
}
errors++;
}
var _valid0 = _errs18 === errors;
valid3 = valid3 || _valid0;
if(!valid3){
const err4 = {instancePath:instancePath+"/page/entries/" + i0,schemaPath:"#/properties/page/properties/entries/items/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err4];
}
else {
vErrors.push(err4);
}
errors++;
validate391.errors = vErrors;
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
var valid2 = _errs11 === errors;
if(!valid2){
break;
}
}
}
}
}
else {
validate391.errors = [{instancePath:instancePath+"/page/entries",schemaPath:"#/properties/page/properties/entries/type",keyword:"type",params:{type: "array"},message:"must be array"}];
return false;
}
}
var valid1 = _errs9 === errors;
}
else {
var valid1 = true;
}
if(valid1){
if(data4.next !== undefined){
const _errs20 = errors;
if(!(validate133(data4.next, {instancePath:instancePath+"/page/next",parentData:data4,parentDataProperty:"next",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate133.errors : vErrors.concat(validate133.errors);
errors = vErrors.length;
}
var valid1 = _errs20 === errors;
}
else {
var valid1 = true;
}
}
}
}
}
else {
validate391.errors = [{instancePath:instancePath+"/page",schemaPath:"#/properties/page/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
var valid0 = _errs6 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.exchanges !== undefined){
let data10 = data.exchanges;
const _errs21 = errors;
if(errors === _errs21){
if(Array.isArray(data10)){
if(data10.length > 8){
validate391.errors = [{instancePath:instancePath+"/exchanges",schemaPath:"#/properties/exchanges/maxItems",keyword:"maxItems",params:{limit: 8},message:"must NOT have more than 8 items"}];
return false;
}
else {
if(data10.length < 8){
validate391.errors = [{instancePath:instancePath+"/exchanges",schemaPath:"#/properties/exchanges/minItems",keyword:"minItems",params:{limit: 8},message:"must NOT have fewer than 8 items"}];
return false;
}
else {
var valid5 = true;
const len1 = data10.length;
for(let i1=0; i1<len1; i1++){
let data11 = data10[i1];
const _errs23 = errors;
const _errs24 = errors;
let valid6 = false;
const _errs25 = errors;
if(errors === _errs25){
if(data11 && typeof data11 == "object" && !Array.isArray(data11)){
let missing3;
if((((data11.version === undefined) && (missing3 = "version")) || ((data11.source === undefined) && (missing3 = "source"))) || ((data11.declaration === undefined) && (missing3 = "declaration"))){
const err5 = {instancePath:instancePath+"/exchanges/" + i1,schemaPath:"#/properties/exchanges/items/anyOf/0/required",keyword:"required",params:{missingProperty: missing3},message:"must have required property '"+missing3+"'"};
if(vErrors === null){
vErrors = [err5];
}
else {
vErrors.push(err5);
}
errors++;
}
else {
const _errs27 = errors;
for(const key3 in data11){
if(!(((key3 === "version") || (key3 === "source")) || (key3 === "declaration"))){
const err6 = {instancePath:instancePath+"/exchanges/" + i1,schemaPath:"#/properties/exchanges/items/anyOf/0/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key3},message:"must NOT have additional properties"};
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
if(_errs27 === errors){
if(data11.version !== undefined){
const _errs28 = errors;
if(!(validate102(data11.version, {instancePath:instancePath+"/exchanges/" + i1+"/version",parentData:data11,parentDataProperty:"version",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate102.errors : vErrors.concat(validate102.errors);
errors = vErrors.length;
}
var valid7 = _errs28 === errors;
}
else {
var valid7 = true;
}
if(valid7){
if(data11.source !== undefined){
const _errs29 = errors;
if(!(validate315(data11.source, {instancePath:instancePath+"/exchanges/" + i1+"/source",parentData:data11,parentDataProperty:"source",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate315.errors : vErrors.concat(validate315.errors);
errors = vErrors.length;
}
var valid7 = _errs29 === errors;
}
else {
var valid7 = true;
}
if(valid7){
if(data11.declaration !== undefined){
let data14 = data11.declaration;
const _errs30 = errors;
const _errs31 = errors;
let valid8 = false;
let passing0 = null;
const _errs32 = errors;
if(errors === _errs32){
if(data14 && typeof data14 == "object" && !Array.isArray(data14)){
let missing4;
if((data14.failure === undefined) && (missing4 = "failure")){
const err7 = {instancePath:instancePath+"/exchanges/" + i1+"/declaration",schemaPath:"#/properties/exchanges/items/anyOf/0/properties/declaration/oneOf/0/required",keyword:"required",params:{missingProperty: missing4},message:"must have required property '"+missing4+"'"};
if(vErrors === null){
vErrors = [err7];
}
else {
vErrors.push(err7);
}
errors++;
}
else {
const _errs34 = errors;
for(const key4 in data14){
if(!(key4 === "failure")){
const err8 = {instancePath:instancePath+"/exchanges/" + i1+"/declaration",schemaPath:"#/properties/exchanges/items/anyOf/0/properties/declaration/oneOf/0/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key4},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err8];
}
else {
vErrors.push(err8);
}
errors++;
break;
}
}
if(_errs34 === errors){
if(data14.failure !== undefined){
if(!(validate401(data14.failure, {instancePath:instancePath+"/exchanges/" + i1+"/declaration/failure",parentData:data14,parentDataProperty:"failure",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate401.errors : vErrors.concat(validate401.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err9 = {instancePath:instancePath+"/exchanges/" + i1+"/declaration",schemaPath:"#/properties/exchanges/items/anyOf/0/properties/declaration/oneOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err9];
}
else {
vErrors.push(err9);
}
errors++;
}
}
var _valid2 = _errs32 === errors;
if(_valid2){
valid8 = true;
passing0 = 0;
var props1 = true;
}
const _errs36 = errors;
if(errors === _errs36){
if(data14 && typeof data14 == "object" && !Array.isArray(data14)){
let missing5;
if((data14.capture === undefined) && (missing5 = "capture")){
const err10 = {instancePath:instancePath+"/exchanges/" + i1+"/declaration",schemaPath:"#/properties/exchanges/items/anyOf/0/properties/declaration/oneOf/1/required",keyword:"required",params:{missingProperty: missing5},message:"must have required property '"+missing5+"'"};
if(vErrors === null){
vErrors = [err10];
}
else {
vErrors.push(err10);
}
errors++;
}
else {
const _errs38 = errors;
for(const key5 in data14){
if(!(key5 === "capture")){
const err11 = {instancePath:instancePath+"/exchanges/" + i1+"/declaration",schemaPath:"#/properties/exchanges/items/anyOf/0/properties/declaration/oneOf/1/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key5},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err11];
}
else {
vErrors.push(err11);
}
errors++;
break;
}
}
if(_errs38 === errors){
if(data14.capture !== undefined){
let data16 = data14.capture;
const _errs39 = errors;
if(errors === _errs39){
if(data16 && typeof data16 == "object" && !Array.isArray(data16)){
let missing6;
if(((((((((((((((((((((data16.exchange === undefined) && (missing6 = "exchange")) || ((data16.protocol === undefined) && (missing6 = "protocol"))) || ((data16.phase === undefined) && (missing6 = "phase"))) || ((data16.caller === undefined) && (missing6 = "caller"))) || ((data16.input === undefined) && (missing6 = "input"))) || ((data16.owner === undefined) && (missing6 = "owner"))) || ((data16.parent === undefined) && (missing6 = "parent"))) || ((data16.effect === undefined) && (missing6 = "effect"))) || ((data16.attempt === undefined) && (missing6 = "attempt"))) || ((data16.executor === undefined) && (missing6 = "executor"))) || ((data16.reconcile_before_ms === undefined) && (missing6 = "reconcile_before_ms"))) || ((data16.segments === undefined) && (missing6 = "segments"))) || ((data16.max_segments === undefined) && (missing6 = "max_segments"))) || ((data16.bytes === undefined) && (missing6 = "bytes"))) || ((data16.capture_bytes === undefined) && (missing6 = "capture_bytes"))) || ((data16.segment_bytes === undefined) && (missing6 = "segment_bytes"))) || ((data16.pending_kind === undefined) && (missing6 = "pending_kind"))) || ((data16.terminal_code === undefined) && (missing6 = "terminal_code"))) || ((data16.collected === undefined) && (missing6 = "collected"))) || ((data16.coverage === undefined) && (missing6 = "coverage"))){
const err12 = {instancePath:instancePath+"/exchanges/" + i1+"/declaration/capture",schemaPath:"#/properties/exchanges/items/anyOf/0/properties/declaration/oneOf/1/properties/capture/required",keyword:"required",params:{missingProperty: missing6},message:"must have required property '"+missing6+"'"};
if(vErrors === null){
vErrors = [err12];
}
else {
vErrors.push(err12);
}
errors++;
}
else {
const _errs41 = errors;
for(const key6 in data16){
if(!(func1.call(schema100.properties.exchanges.items.anyOf[0].properties.declaration.oneOf[1].properties.capture.properties, key6))){
const err13 = {instancePath:instancePath+"/exchanges/" + i1+"/declaration/capture",schemaPath:"#/properties/exchanges/items/anyOf/0/properties/declaration/oneOf/1/properties/capture/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key6},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err13];
}
else {
vErrors.push(err13);
}
errors++;
break;
}
}
if(_errs41 === errors){
if(data16.exchange !== undefined){
let data17 = data16.exchange;
const _errs42 = errors;
if(errors === _errs42){
if(typeof data17 === "string"){
if(func4(data17) > 256){
const err14 = {instancePath:instancePath+"/exchanges/" + i1+"/declaration/capture/exchange",schemaPath:"#/properties/exchanges/items/anyOf/0/properties/declaration/oneOf/1/properties/capture/properties/exchange/maxLength",keyword:"maxLength",params:{limit: 256},message:"must NOT have more than 256 characters"};
if(vErrors === null){
vErrors = [err14];
}
else {
vErrors.push(err14);
}
errors++;
}
}
else {
const err15 = {instancePath:instancePath+"/exchanges/" + i1+"/declaration/capture/exchange",schemaPath:"#/properties/exchanges/items/anyOf/0/properties/declaration/oneOf/1/properties/capture/properties/exchange/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err15];
}
else {
vErrors.push(err15);
}
errors++;
}
}
var valid11 = _errs42 === errors;
}
else {
var valid11 = true;
}
if(valid11){
if(data16.protocol !== undefined){
const _errs44 = errors;
if(!(validate53(data16.protocol, {instancePath:instancePath+"/exchanges/" + i1+"/declaration/capture/protocol",parentData:data16,parentDataProperty:"protocol",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate53.errors : vErrors.concat(validate53.errors);
errors = vErrors.length;
}
var valid11 = _errs44 === errors;
}
else {
var valid11 = true;
}
if(valid11){
if(data16.phase !== undefined){
const _errs45 = errors;
if(!(validate417(data16.phase, {instancePath:instancePath+"/exchanges/" + i1+"/declaration/capture/phase",parentData:data16,parentDataProperty:"phase",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate417.errors : vErrors.concat(validate417.errors);
errors = vErrors.length;
}
var valid11 = _errs45 === errors;
}
else {
var valid11 = true;
}
if(valid11){
if(data16.caller !== undefined){
const _errs46 = errors;
if(!(validate55(data16.caller, {instancePath:instancePath+"/exchanges/" + i1+"/declaration/capture/caller",parentData:data16,parentDataProperty:"caller",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate55.errors : vErrors.concat(validate55.errors);
errors = vErrors.length;
}
var valid11 = _errs46 === errors;
}
else {
var valid11 = true;
}
if(valid11){
if(data16.input !== undefined){
const _errs47 = errors;
if(!(validate55(data16.input, {instancePath:instancePath+"/exchanges/" + i1+"/declaration/capture/input",parentData:data16,parentDataProperty:"input",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate55.errors : vErrors.concat(validate55.errors);
errors = vErrors.length;
}
var valid11 = _errs47 === errors;
}
else {
var valid11 = true;
}
if(valid11){
if(data16.owner !== undefined){
const _errs48 = errors;
if(!(validate55(data16.owner, {instancePath:instancePath+"/exchanges/" + i1+"/declaration/capture/owner",parentData:data16,parentDataProperty:"owner",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate55.errors : vErrors.concat(validate55.errors);
errors = vErrors.length;
}
var valid11 = _errs48 === errors;
}
else {
var valid11 = true;
}
if(valid11){
if(data16.parent !== undefined){
let data23 = data16.parent;
const _errs49 = errors;
if(errors === _errs49){
if(typeof data23 === "string"){
if(func4(data23) > 256){
const err16 = {instancePath:instancePath+"/exchanges/" + i1+"/declaration/capture/parent",schemaPath:"#/properties/exchanges/items/anyOf/0/properties/declaration/oneOf/1/properties/capture/properties/parent/maxLength",keyword:"maxLength",params:{limit: 256},message:"must NOT have more than 256 characters"};
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
const err17 = {instancePath:instancePath+"/exchanges/" + i1+"/declaration/capture/parent",schemaPath:"#/properties/exchanges/items/anyOf/0/properties/declaration/oneOf/1/properties/capture/properties/parent/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err17];
}
else {
vErrors.push(err17);
}
errors++;
}
}
var valid11 = _errs49 === errors;
}
else {
var valid11 = true;
}
if(valid11){
if(data16.effect !== undefined){
const _errs51 = errors;
if(!(validate55(data16.effect, {instancePath:instancePath+"/exchanges/" + i1+"/declaration/capture/effect",parentData:data16,parentDataProperty:"effect",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate55.errors : vErrors.concat(validate55.errors);
errors = vErrors.length;
}
var valid11 = _errs51 === errors;
}
else {
var valid11 = true;
}
if(valid11){
if(data16.attempt !== undefined){
const _errs52 = errors;
if(!(validate55(data16.attempt, {instancePath:instancePath+"/exchanges/" + i1+"/declaration/capture/attempt",parentData:data16,parentDataProperty:"attempt",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate55.errors : vErrors.concat(validate55.errors);
errors = vErrors.length;
}
var valid11 = _errs52 === errors;
}
else {
var valid11 = true;
}
if(valid11){
if(data16.executor !== undefined){
const _errs53 = errors;
if(!(validate55(data16.executor, {instancePath:instancePath+"/exchanges/" + i1+"/declaration/capture/executor",parentData:data16,parentDataProperty:"executor",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate55.errors : vErrors.concat(validate55.errors);
errors = vErrors.length;
}
var valid11 = _errs53 === errors;
}
else {
var valid11 = true;
}
if(valid11){
if(data16.reconcile_before_ms !== undefined){
const _errs54 = errors;
if(!(validate55(data16.reconcile_before_ms, {instancePath:instancePath+"/exchanges/" + i1+"/declaration/capture/reconcile_before_ms",parentData:data16,parentDataProperty:"reconcile_before_ms",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate55.errors : vErrors.concat(validate55.errors);
errors = vErrors.length;
}
var valid11 = _errs54 === errors;
}
else {
var valid11 = true;
}
if(valid11){
if(data16.segments !== undefined){
const _errs55 = errors;
if(!(validate53(data16.segments, {instancePath:instancePath+"/exchanges/" + i1+"/declaration/capture/segments",parentData:data16,parentDataProperty:"segments",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate53.errors : vErrors.concat(validate53.errors);
errors = vErrors.length;
}
var valid11 = _errs55 === errors;
}
else {
var valid11 = true;
}
if(valid11){
if(data16.max_segments !== undefined){
const _errs56 = errors;
if(!(validate53(data16.max_segments, {instancePath:instancePath+"/exchanges/" + i1+"/declaration/capture/max_segments",parentData:data16,parentDataProperty:"max_segments",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate53.errors : vErrors.concat(validate53.errors);
errors = vErrors.length;
}
var valid11 = _errs56 === errors;
}
else {
var valid11 = true;
}
if(valid11){
if(data16.bytes !== undefined){
let data30 = data16.bytes;
const _errs57 = errors;
if(errors === _errs57){
if(typeof data30 === "string"){
if(func4(data30) > 256){
const err18 = {instancePath:instancePath+"/exchanges/" + i1+"/declaration/capture/bytes",schemaPath:"#/properties/exchanges/items/anyOf/0/properties/declaration/oneOf/1/properties/capture/properties/bytes/maxLength",keyword:"maxLength",params:{limit: 256},message:"must NOT have more than 256 characters"};
if(vErrors === null){
vErrors = [err18];
}
else {
vErrors.push(err18);
}
errors++;
}
}
else {
const err19 = {instancePath:instancePath+"/exchanges/" + i1+"/declaration/capture/bytes",schemaPath:"#/properties/exchanges/items/anyOf/0/properties/declaration/oneOf/1/properties/capture/properties/bytes/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err19];
}
else {
vErrors.push(err19);
}
errors++;
}
}
var valid11 = _errs57 === errors;
}
else {
var valid11 = true;
}
if(valid11){
if(data16.capture_bytes !== undefined){
let data31 = data16.capture_bytes;
const _errs59 = errors;
if(errors === _errs59){
if(typeof data31 === "string"){
if(func4(data31) > 256){
const err20 = {instancePath:instancePath+"/exchanges/" + i1+"/declaration/capture/capture_bytes",schemaPath:"#/properties/exchanges/items/anyOf/0/properties/declaration/oneOf/1/properties/capture/properties/capture_bytes/maxLength",keyword:"maxLength",params:{limit: 256},message:"must NOT have more than 256 characters"};
if(vErrors === null){
vErrors = [err20];
}
else {
vErrors.push(err20);
}
errors++;
}
}
else {
const err21 = {instancePath:instancePath+"/exchanges/" + i1+"/declaration/capture/capture_bytes",schemaPath:"#/properties/exchanges/items/anyOf/0/properties/declaration/oneOf/1/properties/capture/properties/capture_bytes/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err21];
}
else {
vErrors.push(err21);
}
errors++;
}
}
var valid11 = _errs59 === errors;
}
else {
var valid11 = true;
}
if(valid11){
if(data16.segment_bytes !== undefined){
const _errs61 = errors;
if(!(validate53(data16.segment_bytes, {instancePath:instancePath+"/exchanges/" + i1+"/declaration/capture/segment_bytes",parentData:data16,parentDataProperty:"segment_bytes",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate53.errors : vErrors.concat(validate53.errors);
errors = vErrors.length;
}
var valid11 = _errs61 === errors;
}
else {
var valid11 = true;
}
if(valid11){
if(data16.pending_kind !== undefined){
const _errs62 = errors;
if(!(validate53(data16.pending_kind, {instancePath:instancePath+"/exchanges/" + i1+"/declaration/capture/pending_kind",parentData:data16,parentDataProperty:"pending_kind",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate53.errors : vErrors.concat(validate53.errors);
errors = vErrors.length;
}
var valid11 = _errs62 === errors;
}
else {
var valid11 = true;
}
if(valid11){
if(data16.terminal_code !== undefined){
const _errs63 = errors;
if(!(validate53(data16.terminal_code, {instancePath:instancePath+"/exchanges/" + i1+"/declaration/capture/terminal_code",parentData:data16,parentDataProperty:"terminal_code",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate53.errors : vErrors.concat(validate53.errors);
errors = vErrors.length;
}
var valid11 = _errs63 === errors;
}
else {
var valid11 = true;
}
if(valid11){
if(data16.collected !== undefined){
const _errs64 = errors;
if(!(validate53(data16.collected, {instancePath:instancePath+"/exchanges/" + i1+"/declaration/capture/collected",parentData:data16,parentDataProperty:"collected",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate53.errors : vErrors.concat(validate53.errors);
errors = vErrors.length;
}
var valid11 = _errs64 === errors;
}
else {
var valid11 = true;
}
if(valid11){
if(data16.coverage !== undefined){
const _errs65 = errors;
if(!(validate105(data16.coverage, {instancePath:instancePath+"/exchanges/" + i1+"/declaration/capture/coverage",parentData:data16,parentDataProperty:"coverage",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate105.errors : vErrors.concat(validate105.errors);
errors = vErrors.length;
}
var valid11 = _errs65 === errors;
}
else {
var valid11 = true;
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
}
}
else {
const err22 = {instancePath:instancePath+"/exchanges/" + i1+"/declaration/capture",schemaPath:"#/properties/exchanges/items/anyOf/0/properties/declaration/oneOf/1/properties/capture/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
}
}
else {
const err23 = {instancePath:instancePath+"/exchanges/" + i1+"/declaration",schemaPath:"#/properties/exchanges/items/anyOf/0/properties/declaration/oneOf/1/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err23];
}
else {
vErrors.push(err23);
}
errors++;
}
}
var _valid2 = _errs36 === errors;
if(_valid2 && valid8){
valid8 = false;
passing0 = [passing0, 1];
}
else {
if(_valid2){
valid8 = true;
passing0 = 1;
if(props1 !== true){
props1 = true;
}
}
const _errs66 = errors;
if(errors === _errs66){
if(data14 && typeof data14 == "object" && !Array.isArray(data14)){
let missing7;
if((data14.obligations === undefined) && (missing7 = "obligations")){
const err24 = {instancePath:instancePath+"/exchanges/" + i1+"/declaration",schemaPath:"#/properties/exchanges/items/anyOf/0/properties/declaration/oneOf/2/required",keyword:"required",params:{missingProperty: missing7},message:"must have required property '"+missing7+"'"};
if(vErrors === null){
vErrors = [err24];
}
else {
vErrors.push(err24);
}
errors++;
}
else {
const _errs68 = errors;
for(const key7 in data14){
if(!(key7 === "obligations")){
const err25 = {instancePath:instancePath+"/exchanges/" + i1+"/declaration",schemaPath:"#/properties/exchanges/items/anyOf/0/properties/declaration/oneOf/2/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key7},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err25];
}
else {
vErrors.push(err25);
}
errors++;
break;
}
}
if(_errs68 === errors){
if(data14.obligations !== undefined){
let data37 = data14.obligations;
const _errs69 = errors;
if(errors === _errs69){
if(data37 && typeof data37 == "object" && !Array.isArray(data37)){
let missing8;
if((((((data37.exchange === undefined) && (missing8 = "exchange")) || ((data37.dependents === undefined) && (missing8 = "dependents"))) || ((data37.disposition === undefined) && (missing8 = "disposition"))) || ((data37.caller === undefined) && (missing8 = "caller"))) || ((data37.effect === undefined) && (missing8 = "effect"))){
const err26 = {instancePath:instancePath+"/exchanges/" + i1+"/declaration/obligations",schemaPath:"#/properties/exchanges/items/anyOf/0/properties/declaration/oneOf/2/properties/obligations/required",keyword:"required",params:{missingProperty: missing8},message:"must have required property '"+missing8+"'"};
if(vErrors === null){
vErrors = [err26];
}
else {
vErrors.push(err26);
}
errors++;
}
else {
const _errs71 = errors;
for(const key8 in data37){
if(!(((((key8 === "exchange") || (key8 === "dependents")) || (key8 === "disposition")) || (key8 === "caller")) || (key8 === "effect"))){
const err27 = {instancePath:instancePath+"/exchanges/" + i1+"/declaration/obligations",schemaPath:"#/properties/exchanges/items/anyOf/0/properties/declaration/oneOf/2/properties/obligations/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key8},message:"must NOT have additional properties"};
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
if(_errs71 === errors){
if(data37.exchange !== undefined){
let data38 = data37.exchange;
const _errs72 = errors;
if(errors === _errs72){
if(typeof data38 === "string"){
if(func4(data38) > 256){
const err28 = {instancePath:instancePath+"/exchanges/" + i1+"/declaration/obligations/exchange",schemaPath:"#/properties/exchanges/items/anyOf/0/properties/declaration/oneOf/2/properties/obligations/properties/exchange/maxLength",keyword:"maxLength",params:{limit: 256},message:"must NOT have more than 256 characters"};
if(vErrors === null){
vErrors = [err28];
}
else {
vErrors.push(err28);
}
errors++;
}
}
else {
const err29 = {instancePath:instancePath+"/exchanges/" + i1+"/declaration/obligations/exchange",schemaPath:"#/properties/exchanges/items/anyOf/0/properties/declaration/oneOf/2/properties/obligations/properties/exchange/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err29];
}
else {
vErrors.push(err29);
}
errors++;
}
}
var valid13 = _errs72 === errors;
}
else {
var valid13 = true;
}
if(valid13){
if(data37.dependents !== undefined){
let data39 = data37.dependents;
const _errs74 = errors;
if(errors === _errs74){
if(typeof data39 === "string"){
if(func4(data39) > 256){
const err30 = {instancePath:instancePath+"/exchanges/" + i1+"/declaration/obligations/dependents",schemaPath:"#/properties/exchanges/items/anyOf/0/properties/declaration/oneOf/2/properties/obligations/properties/dependents/maxLength",keyword:"maxLength",params:{limit: 256},message:"must NOT have more than 256 characters"};
if(vErrors === null){
vErrors = [err30];
}
else {
vErrors.push(err30);
}
errors++;
}
}
else {
const err31 = {instancePath:instancePath+"/exchanges/" + i1+"/declaration/obligations/dependents",schemaPath:"#/properties/exchanges/items/anyOf/0/properties/declaration/oneOf/2/properties/obligations/properties/dependents/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err31];
}
else {
vErrors.push(err31);
}
errors++;
}
}
var valid13 = _errs74 === errors;
}
else {
var valid13 = true;
}
if(valid13){
if(data37.disposition !== undefined){
let data40 = data37.disposition;
const _errs76 = errors;
if(typeof data40 !== "string"){
const err32 = {instancePath:instancePath+"/exchanges/" + i1+"/declaration/obligations/disposition",schemaPath:"#/properties/exchanges/items/anyOf/0/properties/declaration/oneOf/2/properties/obligations/properties/disposition/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err32];
}
else {
vErrors.push(err32);
}
errors++;
}
if(!(((((data40 === "no_intent") || (data40 === "pending")) || (data40 === "observed")) || (data40 === "cancelled")) || (data40 === "closed_unknown"))){
const err33 = {instancePath:instancePath+"/exchanges/" + i1+"/declaration/obligations/disposition",schemaPath:"#/properties/exchanges/items/anyOf/0/properties/declaration/oneOf/2/properties/obligations/properties/disposition/enum",keyword:"enum",params:{allowedValues: schema100.properties.exchanges.items.anyOf[0].properties.declaration.oneOf[2].properties.obligations.properties.disposition.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err33];
}
else {
vErrors.push(err33);
}
errors++;
}
var valid13 = _errs76 === errors;
}
else {
var valid13 = true;
}
if(valid13){
if(data37.caller !== undefined){
let data41 = data37.caller;
const _errs78 = errors;
if(typeof data41 !== "string"){
const err34 = {instancePath:instancePath+"/exchanges/" + i1+"/declaration/obligations/caller",schemaPath:"#/properties/exchanges/items/anyOf/0/properties/declaration/oneOf/2/properties/obligations/properties/caller/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err34];
}
else {
vErrors.push(err34);
}
errors++;
}
if(!(((data41 === "none") || (data41 === "held")) || (data41 === "released"))){
const err35 = {instancePath:instancePath+"/exchanges/" + i1+"/declaration/obligations/caller",schemaPath:"#/properties/exchanges/items/anyOf/0/properties/declaration/oneOf/2/properties/obligations/properties/caller/enum",keyword:"enum",params:{allowedValues: schema100.properties.exchanges.items.anyOf[0].properties.declaration.oneOf[2].properties.obligations.properties.caller.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err35];
}
else {
vErrors.push(err35);
}
errors++;
}
var valid13 = _errs78 === errors;
}
else {
var valid13 = true;
}
if(valid13){
if(data37.effect !== undefined){
const _errs80 = errors;
if(!(validate55(data37.effect, {instancePath:instancePath+"/exchanges/" + i1+"/declaration/obligations/effect",parentData:data37,parentDataProperty:"effect",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate55.errors : vErrors.concat(validate55.errors);
errors = vErrors.length;
}
var valid13 = _errs80 === errors;
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
}
else {
const err36 = {instancePath:instancePath+"/exchanges/" + i1+"/declaration/obligations",schemaPath:"#/properties/exchanges/items/anyOf/0/properties/declaration/oneOf/2/properties/obligations/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err36];
}
else {
vErrors.push(err36);
}
errors++;
}
}
}
}
}
}
else {
const err37 = {instancePath:instancePath+"/exchanges/" + i1+"/declaration",schemaPath:"#/properties/exchanges/items/anyOf/0/properties/declaration/oneOf/2/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err37];
}
else {
vErrors.push(err37);
}
errors++;
}
}
var _valid2 = _errs66 === errors;
if(_valid2 && valid8){
valid8 = false;
passing0 = [passing0, 2];
}
else {
if(_valid2){
valid8 = true;
passing0 = 2;
if(props1 !== true){
props1 = true;
}
}
const _errs81 = errors;
if(errors === _errs81){
if(data14 && typeof data14 == "object" && !Array.isArray(data14)){
let missing9;
if((data14.lineage === undefined) && (missing9 = "lineage")){
const err38 = {instancePath:instancePath+"/exchanges/" + i1+"/declaration",schemaPath:"#/properties/exchanges/items/anyOf/0/properties/declaration/oneOf/3/required",keyword:"required",params:{missingProperty: missing9},message:"must have required property '"+missing9+"'"};
if(vErrors === null){
vErrors = [err38];
}
else {
vErrors.push(err38);
}
errors++;
}
else {
const _errs83 = errors;
for(const key9 in data14){
if(!(key9 === "lineage")){
const err39 = {instancePath:instancePath+"/exchanges/" + i1+"/declaration",schemaPath:"#/properties/exchanges/items/anyOf/0/properties/declaration/oneOf/3/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key9},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err39];
}
else {
vErrors.push(err39);
}
errors++;
break;
}
}
if(_errs83 === errors){
if(data14.lineage !== undefined){
let data43 = data14.lineage;
const _errs84 = errors;
if(errors === _errs84){
if(data43 && typeof data43 == "object" && !Array.isArray(data43)){
let missing10;
if((((((((data43.exchange === undefined) && (missing10 = "exchange")) || ((data43.root === undefined) && (missing10 = "root"))) || ((data43.parent === undefined) && (missing10 = "parent"))) || ((data43.ordinal === undefined) && (missing10 = "ordinal"))) || ((data43.reason === undefined) && (missing10 = "reason"))) || ((data43.policy === undefined) && (missing10 = "policy"))) || ((data43.policy_revision === undefined) && (missing10 = "policy_revision"))){
const err40 = {instancePath:instancePath+"/exchanges/" + i1+"/declaration/lineage",schemaPath:"#/properties/exchanges/items/anyOf/0/properties/declaration/oneOf/3/properties/lineage/required",keyword:"required",params:{missingProperty: missing10},message:"must have required property '"+missing10+"'"};
if(vErrors === null){
vErrors = [err40];
}
else {
vErrors.push(err40);
}
errors++;
}
else {
const _errs86 = errors;
for(const key10 in data43){
if(!(((((((key10 === "exchange") || (key10 === "root")) || (key10 === "parent")) || (key10 === "ordinal")) || (key10 === "reason")) || (key10 === "policy")) || (key10 === "policy_revision"))){
const err41 = {instancePath:instancePath+"/exchanges/" + i1+"/declaration/lineage",schemaPath:"#/properties/exchanges/items/anyOf/0/properties/declaration/oneOf/3/properties/lineage/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key10},message:"must NOT have additional properties"};
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
if(_errs86 === errors){
if(data43.exchange !== undefined){
let data44 = data43.exchange;
const _errs87 = errors;
if(errors === _errs87){
if(typeof data44 === "string"){
if(func4(data44) > 256){
const err42 = {instancePath:instancePath+"/exchanges/" + i1+"/declaration/lineage/exchange",schemaPath:"#/properties/exchanges/items/anyOf/0/properties/declaration/oneOf/3/properties/lineage/properties/exchange/maxLength",keyword:"maxLength",params:{limit: 256},message:"must NOT have more than 256 characters"};
if(vErrors === null){
vErrors = [err42];
}
else {
vErrors.push(err42);
}
errors++;
}
}
else {
const err43 = {instancePath:instancePath+"/exchanges/" + i1+"/declaration/lineage/exchange",schemaPath:"#/properties/exchanges/items/anyOf/0/properties/declaration/oneOf/3/properties/lineage/properties/exchange/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err43];
}
else {
vErrors.push(err43);
}
errors++;
}
}
var valid15 = _errs87 === errors;
}
else {
var valid15 = true;
}
if(valid15){
if(data43.root !== undefined){
let data45 = data43.root;
const _errs89 = errors;
if(errors === _errs89){
if(typeof data45 === "string"){
if(func4(data45) > 256){
const err44 = {instancePath:instancePath+"/exchanges/" + i1+"/declaration/lineage/root",schemaPath:"#/properties/exchanges/items/anyOf/0/properties/declaration/oneOf/3/properties/lineage/properties/root/maxLength",keyword:"maxLength",params:{limit: 256},message:"must NOT have more than 256 characters"};
if(vErrors === null){
vErrors = [err44];
}
else {
vErrors.push(err44);
}
errors++;
}
}
else {
const err45 = {instancePath:instancePath+"/exchanges/" + i1+"/declaration/lineage/root",schemaPath:"#/properties/exchanges/items/anyOf/0/properties/declaration/oneOf/3/properties/lineage/properties/root/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err45];
}
else {
vErrors.push(err45);
}
errors++;
}
}
var valid15 = _errs89 === errors;
}
else {
var valid15 = true;
}
if(valid15){
if(data43.parent !== undefined){
let data46 = data43.parent;
const _errs91 = errors;
if(errors === _errs91){
if(typeof data46 === "string"){
if(func4(data46) > 256){
const err46 = {instancePath:instancePath+"/exchanges/" + i1+"/declaration/lineage/parent",schemaPath:"#/properties/exchanges/items/anyOf/0/properties/declaration/oneOf/3/properties/lineage/properties/parent/maxLength",keyword:"maxLength",params:{limit: 256},message:"must NOT have more than 256 characters"};
if(vErrors === null){
vErrors = [err46];
}
else {
vErrors.push(err46);
}
errors++;
}
}
else {
const err47 = {instancePath:instancePath+"/exchanges/" + i1+"/declaration/lineage/parent",schemaPath:"#/properties/exchanges/items/anyOf/0/properties/declaration/oneOf/3/properties/lineage/properties/parent/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err47];
}
else {
vErrors.push(err47);
}
errors++;
}
}
var valid15 = _errs91 === errors;
}
else {
var valid15 = true;
}
if(valid15){
if(data43.ordinal !== undefined){
const _errs93 = errors;
if(!(validate53(data43.ordinal, {instancePath:instancePath+"/exchanges/" + i1+"/declaration/lineage/ordinal",parentData:data43,parentDataProperty:"ordinal",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate53.errors : vErrors.concat(validate53.errors);
errors = vErrors.length;
}
var valid15 = _errs93 === errors;
}
else {
var valid15 = true;
}
if(valid15){
if(data43.reason !== undefined){
let data48 = data43.reason;
const _errs94 = errors;
if(typeof data48 !== "string"){
const err48 = {instancePath:instancePath+"/exchanges/" + i1+"/declaration/lineage/reason",schemaPath:"#/properties/exchanges/items/anyOf/0/properties/declaration/oneOf/3/properties/lineage/properties/reason/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err48];
}
else {
vErrors.push(err48);
}
errors++;
}
if(!((((data48 === "retry") || (data48 === "redirect")) || (data48 === "reconcile")) || (data48 === "cancel"))){
const err49 = {instancePath:instancePath+"/exchanges/" + i1+"/declaration/lineage/reason",schemaPath:"#/properties/exchanges/items/anyOf/0/properties/declaration/oneOf/3/properties/lineage/properties/reason/enum",keyword:"enum",params:{allowedValues: schema100.properties.exchanges.items.anyOf[0].properties.declaration.oneOf[3].properties.lineage.properties.reason.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err49];
}
else {
vErrors.push(err49);
}
errors++;
}
var valid15 = _errs94 === errors;
}
else {
var valid15 = true;
}
if(valid15){
if(data43.policy !== undefined){
let data49 = data43.policy;
const _errs96 = errors;
if(errors === _errs96){
if(typeof data49 === "string"){
if(func4(data49) > 256){
const err50 = {instancePath:instancePath+"/exchanges/" + i1+"/declaration/lineage/policy",schemaPath:"#/properties/exchanges/items/anyOf/0/properties/declaration/oneOf/3/properties/lineage/properties/policy/maxLength",keyword:"maxLength",params:{limit: 256},message:"must NOT have more than 256 characters"};
if(vErrors === null){
vErrors = [err50];
}
else {
vErrors.push(err50);
}
errors++;
}
}
else {
const err51 = {instancePath:instancePath+"/exchanges/" + i1+"/declaration/lineage/policy",schemaPath:"#/properties/exchanges/items/anyOf/0/properties/declaration/oneOf/3/properties/lineage/properties/policy/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err51];
}
else {
vErrors.push(err51);
}
errors++;
}
}
var valid15 = _errs96 === errors;
}
else {
var valid15 = true;
}
if(valid15){
if(data43.policy_revision !== undefined){
let data50 = data43.policy_revision;
const _errs98 = errors;
if(errors === _errs98){
if(typeof data50 === "string"){
if(func4(data50) > 256){
const err52 = {instancePath:instancePath+"/exchanges/" + i1+"/declaration/lineage/policy_revision",schemaPath:"#/properties/exchanges/items/anyOf/0/properties/declaration/oneOf/3/properties/lineage/properties/policy_revision/maxLength",keyword:"maxLength",params:{limit: 256},message:"must NOT have more than 256 characters"};
if(vErrors === null){
vErrors = [err52];
}
else {
vErrors.push(err52);
}
errors++;
}
}
else {
const err53 = {instancePath:instancePath+"/exchanges/" + i1+"/declaration/lineage/policy_revision",schemaPath:"#/properties/exchanges/items/anyOf/0/properties/declaration/oneOf/3/properties/lineage/properties/policy_revision/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err53];
}
else {
vErrors.push(err53);
}
errors++;
}
}
var valid15 = _errs98 === errors;
}
else {
var valid15 = true;
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
const err54 = {instancePath:instancePath+"/exchanges/" + i1+"/declaration/lineage",schemaPath:"#/properties/exchanges/items/anyOf/0/properties/declaration/oneOf/3/properties/lineage/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err55 = {instancePath:instancePath+"/exchanges/" + i1+"/declaration",schemaPath:"#/properties/exchanges/items/anyOf/0/properties/declaration/oneOf/3/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err55];
}
else {
vErrors.push(err55);
}
errors++;
}
}
var _valid2 = _errs81 === errors;
if(_valid2 && valid8){
valid8 = false;
passing0 = [passing0, 3];
}
else {
if(_valid2){
valid8 = true;
passing0 = 3;
if(props1 !== true){
props1 = true;
}
}
const _errs100 = errors;
if(errors === _errs100){
if(data14 && typeof data14 == "object" && !Array.isArray(data14)){
let missing11;
if((data14.attempts === undefined) && (missing11 = "attempts")){
const err56 = {instancePath:instancePath+"/exchanges/" + i1+"/declaration",schemaPath:"#/properties/exchanges/items/anyOf/0/properties/declaration/oneOf/4/required",keyword:"required",params:{missingProperty: missing11},message:"must have required property '"+missing11+"'"};
if(vErrors === null){
vErrors = [err56];
}
else {
vErrors.push(err56);
}
errors++;
}
else {
const _errs102 = errors;
for(const key11 in data14){
if(!(key11 === "attempts")){
const err57 = {instancePath:instancePath+"/exchanges/" + i1+"/declaration",schemaPath:"#/properties/exchanges/items/anyOf/0/properties/declaration/oneOf/4/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key11},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err57];
}
else {
vErrors.push(err57);
}
errors++;
break;
}
}
if(_errs102 === errors){
if(data14.attempts !== undefined){
let data51 = data14.attempts;
const _errs103 = errors;
if(errors === _errs103){
if(data51 && typeof data51 == "object" && !Array.isArray(data51)){
let missing12;
if(((((data51.exchange === undefined) && (missing12 = "exchange")) || ((data51.limit === undefined) && (missing12 = "limit"))) || ((data51.used === undefined) && (missing12 = "used"))) || ((data51.unsettled === undefined) && (missing12 = "unsettled"))){
const err58 = {instancePath:instancePath+"/exchanges/" + i1+"/declaration/attempts",schemaPath:"#/properties/exchanges/items/anyOf/0/properties/declaration/oneOf/4/properties/attempts/required",keyword:"required",params:{missingProperty: missing12},message:"must have required property '"+missing12+"'"};
if(vErrors === null){
vErrors = [err58];
}
else {
vErrors.push(err58);
}
errors++;
}
else {
const _errs105 = errors;
for(const key12 in data51){
if(!((((key12 === "exchange") || (key12 === "limit")) || (key12 === "used")) || (key12 === "unsettled"))){
const err59 = {instancePath:instancePath+"/exchanges/" + i1+"/declaration/attempts",schemaPath:"#/properties/exchanges/items/anyOf/0/properties/declaration/oneOf/4/properties/attempts/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key12},message:"must NOT have additional properties"};
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
if(_errs105 === errors){
if(data51.exchange !== undefined){
let data52 = data51.exchange;
const _errs106 = errors;
if(errors === _errs106){
if(typeof data52 === "string"){
if(func4(data52) > 256){
const err60 = {instancePath:instancePath+"/exchanges/" + i1+"/declaration/attempts/exchange",schemaPath:"#/properties/exchanges/items/anyOf/0/properties/declaration/oneOf/4/properties/attempts/properties/exchange/maxLength",keyword:"maxLength",params:{limit: 256},message:"must NOT have more than 256 characters"};
if(vErrors === null){
vErrors = [err60];
}
else {
vErrors.push(err60);
}
errors++;
}
}
else {
const err61 = {instancePath:instancePath+"/exchanges/" + i1+"/declaration/attempts/exchange",schemaPath:"#/properties/exchanges/items/anyOf/0/properties/declaration/oneOf/4/properties/attempts/properties/exchange/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err61];
}
else {
vErrors.push(err61);
}
errors++;
}
}
var valid17 = _errs106 === errors;
}
else {
var valid17 = true;
}
if(valid17){
if(data51.limit !== undefined){
const _errs108 = errors;
if(!(validate53(data51.limit, {instancePath:instancePath+"/exchanges/" + i1+"/declaration/attempts/limit",parentData:data51,parentDataProperty:"limit",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate53.errors : vErrors.concat(validate53.errors);
errors = vErrors.length;
}
var valid17 = _errs108 === errors;
}
else {
var valid17 = true;
}
if(valid17){
if(data51.used !== undefined){
const _errs109 = errors;
if(!(validate53(data51.used, {instancePath:instancePath+"/exchanges/" + i1+"/declaration/attempts/used",parentData:data51,parentDataProperty:"used",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate53.errors : vErrors.concat(validate53.errors);
errors = vErrors.length;
}
var valid17 = _errs109 === errors;
}
else {
var valid17 = true;
}
if(valid17){
if(data51.unsettled !== undefined){
const _errs110 = errors;
if(!(validate53(data51.unsettled, {instancePath:instancePath+"/exchanges/" + i1+"/declaration/attempts/unsettled",parentData:data51,parentDataProperty:"unsettled",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate53.errors : vErrors.concat(validate53.errors);
errors = vErrors.length;
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
}
}
else {
const err62 = {instancePath:instancePath+"/exchanges/" + i1+"/declaration/attempts",schemaPath:"#/properties/exchanges/items/anyOf/0/properties/declaration/oneOf/4/properties/attempts/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
}
}
else {
const err63 = {instancePath:instancePath+"/exchanges/" + i1+"/declaration",schemaPath:"#/properties/exchanges/items/anyOf/0/properties/declaration/oneOf/4/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err63];
}
else {
vErrors.push(err63);
}
errors++;
}
}
var _valid2 = _errs100 === errors;
if(_valid2 && valid8){
valid8 = false;
passing0 = [passing0, 4];
}
else {
if(_valid2){
valid8 = true;
passing0 = 4;
if(props1 !== true){
props1 = true;
}
}
}
}
}
}
if(!valid8){
const err64 = {instancePath:instancePath+"/exchanges/" + i1+"/declaration",schemaPath:"#/properties/exchanges/items/anyOf/0/properties/declaration/oneOf",keyword:"oneOf",params:{passingSchemas: passing0},message:"must match exactly one schema in oneOf"};
if(vErrors === null){
vErrors = [err64];
}
else {
vErrors.push(err64);
}
errors++;
}
else {
errors = _errs31;
if(vErrors !== null){
if(_errs31){
vErrors.length = _errs31;
}
else {
vErrors = null;
}
}
}
var valid7 = _errs30 === errors;
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
const err65 = {instancePath:instancePath+"/exchanges/" + i1,schemaPath:"#/properties/exchanges/items/anyOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err65];
}
else {
vErrors.push(err65);
}
errors++;
}
}
var _valid1 = _errs25 === errors;
valid6 = valid6 || _valid1;
const _errs111 = errors;
if(data11 !== null){
const err66 = {instancePath:instancePath+"/exchanges/" + i1,schemaPath:"#/properties/exchanges/items/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err66];
}
else {
vErrors.push(err66);
}
errors++;
}
var _valid1 = _errs111 === errors;
valid6 = valid6 || _valid1;
if(!valid6){
const err67 = {instancePath:instancePath+"/exchanges/" + i1,schemaPath:"#/properties/exchanges/items/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err67];
}
else {
vErrors.push(err67);
}
errors++;
validate391.errors = vErrors;
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
var valid5 = _errs23 === errors;
if(!valid5){
break;
}
}
}
}
}
else {
validate391.errors = [{instancePath:instancePath+"/exchanges",schemaPath:"#/properties/exchanges/type",keyword:"type",params:{type: "array"},message:"must be array"}];
return false;
}
}
var valid0 = _errs21 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.documents !== undefined){
let data56 = data.documents;
const _errs113 = errors;
if(errors === _errs113){
if(Array.isArray(data56)){
if(data56.length > 8){
validate391.errors = [{instancePath:instancePath+"/documents",schemaPath:"#/properties/documents/maxItems",keyword:"maxItems",params:{limit: 8},message:"must NOT have more than 8 items"}];
return false;
}
else {
if(data56.length < 8){
validate391.errors = [{instancePath:instancePath+"/documents",schemaPath:"#/properties/documents/minItems",keyword:"minItems",params:{limit: 8},message:"must NOT have fewer than 8 items"}];
return false;
}
else {
var valid18 = true;
const len2 = data56.length;
for(let i2=0; i2<len2; i2++){
let data57 = data56[i2];
const _errs115 = errors;
const _errs116 = errors;
let valid19 = false;
const _errs117 = errors;
if(errors === _errs117){
if(data57 && typeof data57 == "object" && !Array.isArray(data57)){
let missing13;
if((((data57.version === undefined) && (missing13 = "version")) || ((data57.source === undefined) && (missing13 = "source"))) || ((data57.declaration === undefined) && (missing13 = "declaration"))){
const err68 = {instancePath:instancePath+"/documents/" + i2,schemaPath:"#/properties/documents/items/anyOf/0/required",keyword:"required",params:{missingProperty: missing13},message:"must have required property '"+missing13+"'"};
if(vErrors === null){
vErrors = [err68];
}
else {
vErrors.push(err68);
}
errors++;
}
else {
const _errs119 = errors;
for(const key13 in data57){
if(!(((key13 === "version") || (key13 === "source")) || (key13 === "declaration"))){
const err69 = {instancePath:instancePath+"/documents/" + i2,schemaPath:"#/properties/documents/items/anyOf/0/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key13},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err69];
}
else {
vErrors.push(err69);
}
errors++;
break;
}
}
if(_errs119 === errors){
if(data57.version !== undefined){
const _errs120 = errors;
if(!(validate102(data57.version, {instancePath:instancePath+"/documents/" + i2+"/version",parentData:data57,parentDataProperty:"version",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate102.errors : vErrors.concat(validate102.errors);
errors = vErrors.length;
}
var valid20 = _errs120 === errors;
}
else {
var valid20 = true;
}
if(valid20){
if(data57.source !== undefined){
const _errs121 = errors;
if(!(validate315(data57.source, {instancePath:instancePath+"/documents/" + i2+"/source",parentData:data57,parentDataProperty:"source",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate315.errors : vErrors.concat(validate315.errors);
errors = vErrors.length;
}
var valid20 = _errs121 === errors;
}
else {
var valid20 = true;
}
if(valid20){
if(data57.declaration !== undefined){
const _errs122 = errors;
if(!(validate446(data57.declaration, {instancePath:instancePath+"/documents/" + i2+"/declaration",parentData:data57,parentDataProperty:"declaration",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate446.errors : vErrors.concat(validate446.errors);
errors = vErrors.length;
}
var valid20 = _errs122 === errors;
}
else {
var valid20 = true;
}
}
}
}
}
}
else {
const err70 = {instancePath:instancePath+"/documents/" + i2,schemaPath:"#/properties/documents/items/anyOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err70];
}
else {
vErrors.push(err70);
}
errors++;
}
}
var _valid3 = _errs117 === errors;
valid19 = valid19 || _valid3;
const _errs123 = errors;
if(data57 !== null){
const err71 = {instancePath:instancePath+"/documents/" + i2,schemaPath:"#/properties/documents/items/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err71];
}
else {
vErrors.push(err71);
}
errors++;
}
var _valid3 = _errs123 === errors;
valid19 = valid19 || _valid3;
if(!valid19){
const err72 = {instancePath:instancePath+"/documents/" + i2,schemaPath:"#/properties/documents/items/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err72];
}
else {
vErrors.push(err72);
}
errors++;
validate391.errors = vErrors;
return false;
}
else {
errors = _errs116;
if(vErrors !== null){
if(_errs116){
vErrors.length = _errs116;
}
else {
vErrors = null;
}
}
}
var valid18 = _errs115 === errors;
if(!valid18){
break;
}
}
}
}
}
else {
validate391.errors = [{instancePath:instancePath+"/documents",schemaPath:"#/properties/documents/type",keyword:"type",params:{type: "array"},message:"must be array"}];
return false;
}
}
var valid0 = _errs113 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.queries !== undefined){
let data61 = data.queries;
const _errs125 = errors;
if(errors === _errs125){
if(Array.isArray(data61)){
if(data61.length > 8){
validate391.errors = [{instancePath:instancePath+"/queries",schemaPath:"#/properties/queries/maxItems",keyword:"maxItems",params:{limit: 8},message:"must NOT have more than 8 items"}];
return false;
}
else {
if(data61.length < 8){
validate391.errors = [{instancePath:instancePath+"/queries",schemaPath:"#/properties/queries/minItems",keyword:"minItems",params:{limit: 8},message:"must NOT have fewer than 8 items"}];
return false;
}
else {
var valid21 = true;
const len3 = data61.length;
for(let i3=0; i3<len3; i3++){
let data62 = data61[i3];
const _errs127 = errors;
const _errs128 = errors;
let valid22 = false;
const _errs129 = errors;
if(errors === _errs129){
if(data62 && typeof data62 == "object" && !Array.isArray(data62)){
let missing14;
if((((data62.version === undefined) && (missing14 = "version")) || ((data62.source === undefined) && (missing14 = "source"))) || ((data62.declaration === undefined) && (missing14 = "declaration"))){
const err73 = {instancePath:instancePath+"/queries/" + i3,schemaPath:"#/properties/queries/items/anyOf/0/required",keyword:"required",params:{missingProperty: missing14},message:"must have required property '"+missing14+"'"};
if(vErrors === null){
vErrors = [err73];
}
else {
vErrors.push(err73);
}
errors++;
}
else {
const _errs131 = errors;
for(const key14 in data62){
if(!(((key14 === "version") || (key14 === "source")) || (key14 === "declaration"))){
const err74 = {instancePath:instancePath+"/queries/" + i3,schemaPath:"#/properties/queries/items/anyOf/0/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key14},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err74];
}
else {
vErrors.push(err74);
}
errors++;
break;
}
}
if(_errs131 === errors){
if(data62.version !== undefined){
const _errs132 = errors;
if(!(validate102(data62.version, {instancePath:instancePath+"/queries/" + i3+"/version",parentData:data62,parentDataProperty:"version",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate102.errors : vErrors.concat(validate102.errors);
errors = vErrors.length;
}
var valid23 = _errs132 === errors;
}
else {
var valid23 = true;
}
if(valid23){
if(data62.source !== undefined){
const _errs133 = errors;
if(!(validate315(data62.source, {instancePath:instancePath+"/queries/" + i3+"/source",parentData:data62,parentDataProperty:"source",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate315.errors : vErrors.concat(validate315.errors);
errors = vErrors.length;
}
var valid23 = _errs133 === errors;
}
else {
var valid23 = true;
}
if(valid23){
if(data62.declaration !== undefined){
let data65 = data62.declaration;
const _errs134 = errors;
const _errs135 = errors;
let valid24 = false;
let passing1 = null;
const _errs136 = errors;
if(errors === _errs136){
if(data65 && typeof data65 == "object" && !Array.isArray(data65)){
let missing15;
if((data65.execution === undefined) && (missing15 = "execution")){
const err75 = {instancePath:instancePath+"/queries/" + i3+"/declaration",schemaPath:"#/properties/queries/items/anyOf/0/properties/declaration/oneOf/0/required",keyword:"required",params:{missingProperty: missing15},message:"must have required property '"+missing15+"'"};
if(vErrors === null){
vErrors = [err75];
}
else {
vErrors.push(err75);
}
errors++;
}
else {
const _errs138 = errors;
for(const key15 in data65){
if(!(key15 === "execution")){
const err76 = {instancePath:instancePath+"/queries/" + i3+"/declaration",schemaPath:"#/properties/queries/items/anyOf/0/properties/declaration/oneOf/0/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key15},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err76];
}
else {
vErrors.push(err76);
}
errors++;
break;
}
}
if(_errs138 === errors){
if(data65.execution !== undefined){
let data66 = data65.execution;
const _errs139 = errors;
if(errors === _errs139){
if(data66 && typeof data66 == "object" && !Array.isArray(data66)){
let missing16;
if((((((((((data66.result === undefined) && (missing16 = "result")) || ((data66.destination === undefined) && (missing16 = "destination"))) || ((data66.correlation === undefined) && (missing16 = "correlation"))) || ((data66.source === undefined) && (missing16 = "source"))) || ((data66.request_resource === undefined) && (missing16 = "request_resource"))) || ((data66.request_namespace === undefined) && (missing16 = "request_namespace"))) || ((data66.phase === undefined) && (missing16 = "phase"))) || ((data66.failure === undefined) && (missing16 = "failure"))) || ((data66.policy_revision === undefined) && (missing16 = "policy_revision"))){
const err77 = {instancePath:instancePath+"/queries/" + i3+"/declaration/execution",schemaPath:"#/properties/queries/items/anyOf/0/properties/declaration/oneOf/0/properties/execution/required",keyword:"required",params:{missingProperty: missing16},message:"must have required property '"+missing16+"'"};
if(vErrors === null){
vErrors = [err77];
}
else {
vErrors.push(err77);
}
errors++;
}
else {
const _errs141 = errors;
for(const key16 in data66){
if(!(func1.call(schema100.properties.queries.items.anyOf[0].properties.declaration.oneOf[0].properties.execution.properties, key16))){
const err78 = {instancePath:instancePath+"/queries/" + i3+"/declaration/execution",schemaPath:"#/properties/queries/items/anyOf/0/properties/declaration/oneOf/0/properties/execution/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key16},message:"must NOT have additional properties"};
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
if(_errs141 === errors){
if(data66.result !== undefined){
const _errs142 = errors;
if(!(validate55(data66.result, {instancePath:instancePath+"/queries/" + i3+"/declaration/execution/result",parentData:data66,parentDataProperty:"result",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate55.errors : vErrors.concat(validate55.errors);
errors = vErrors.length;
}
var valid26 = _errs142 === errors;
}
else {
var valid26 = true;
}
if(valid26){
if(data66.destination !== undefined){
const _errs143 = errors;
if(!(validate55(data66.destination, {instancePath:instancePath+"/queries/" + i3+"/declaration/execution/destination",parentData:data66,parentDataProperty:"destination",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate55.errors : vErrors.concat(validate55.errors);
errors = vErrors.length;
}
var valid26 = _errs143 === errors;
}
else {
var valid26 = true;
}
if(valid26){
if(data66.correlation !== undefined){
const _errs144 = errors;
if(!(validate55(data66.correlation, {instancePath:instancePath+"/queries/" + i3+"/declaration/execution/correlation",parentData:data66,parentDataProperty:"correlation",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate55.errors : vErrors.concat(validate55.errors);
errors = vErrors.length;
}
var valid26 = _errs144 === errors;
}
else {
var valid26 = true;
}
if(valid26){
if(data66.source !== undefined){
const _errs145 = errors;
if(!(validate455(data66.source, {instancePath:instancePath+"/queries/" + i3+"/declaration/execution/source",parentData:data66,parentDataProperty:"source",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate455.errors : vErrors.concat(validate455.errors);
errors = vErrors.length;
}
var valid26 = _errs145 === errors;
}
else {
var valid26 = true;
}
if(valid26){
if(data66.request_resource !== undefined){
const _errs146 = errors;
if(!(validate55(data66.request_resource, {instancePath:instancePath+"/queries/" + i3+"/declaration/execution/request_resource",parentData:data66,parentDataProperty:"request_resource",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate55.errors : vErrors.concat(validate55.errors);
errors = vErrors.length;
}
var valid26 = _errs146 === errors;
}
else {
var valid26 = true;
}
if(valid26){
if(data66.request_namespace !== undefined){
let data72 = data66.request_namespace;
const _errs147 = errors;
if(errors === _errs147){
if(typeof data72 === "string"){
if(func4(data72) > 256){
const err79 = {instancePath:instancePath+"/queries/" + i3+"/declaration/execution/request_namespace",schemaPath:"#/properties/queries/items/anyOf/0/properties/declaration/oneOf/0/properties/execution/properties/request_namespace/maxLength",keyword:"maxLength",params:{limit: 256},message:"must NOT have more than 256 characters"};
if(vErrors === null){
vErrors = [err79];
}
else {
vErrors.push(err79);
}
errors++;
}
}
else {
const err80 = {instancePath:instancePath+"/queries/" + i3+"/declaration/execution/request_namespace",schemaPath:"#/properties/queries/items/anyOf/0/properties/declaration/oneOf/0/properties/execution/properties/request_namespace/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err80];
}
else {
vErrors.push(err80);
}
errors++;
}
}
var valid26 = _errs147 === errors;
}
else {
var valid26 = true;
}
if(valid26){
if(data66.phase !== undefined){
let data73 = data66.phase;
const _errs149 = errors;
if(typeof data73 !== "string"){
const err81 = {instancePath:instancePath+"/queries/" + i3+"/declaration/execution/phase",schemaPath:"#/properties/queries/items/anyOf/0/properties/declaration/oneOf/0/properties/execution/properties/phase/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err81];
}
else {
vErrors.push(err81);
}
errors++;
}
if(!(((((((data73 === "capturing") || (data73 === "captured")) || (data73 === "complete")) || (data73 === "cancelled")) || (data73 === "denied")) || (data73 === "failed")) || (data73 === "retired"))){
const err82 = {instancePath:instancePath+"/queries/" + i3+"/declaration/execution/phase",schemaPath:"#/properties/queries/items/anyOf/0/properties/declaration/oneOf/0/properties/execution/properties/phase/enum",keyword:"enum",params:{allowedValues: schema100.properties.queries.items.anyOf[0].properties.declaration.oneOf[0].properties.execution.properties.phase.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err82];
}
else {
vErrors.push(err82);
}
errors++;
}
var valid26 = _errs149 === errors;
}
else {
var valid26 = true;
}
if(valid26){
if(data66.failure !== undefined){
const _errs151 = errors;
if(!(validate461(data66.failure, {instancePath:instancePath+"/queries/" + i3+"/declaration/execution/failure",parentData:data66,parentDataProperty:"failure",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate461.errors : vErrors.concat(validate461.errors);
errors = vErrors.length;
}
var valid26 = _errs151 === errors;
}
else {
var valid26 = true;
}
if(valid26){
if(data66.policy_revision !== undefined){
const _errs152 = errors;
if(!(validate55(data66.policy_revision, {instancePath:instancePath+"/queries/" + i3+"/declaration/execution/policy_revision",parentData:data66,parentDataProperty:"policy_revision",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate55.errors : vErrors.concat(validate55.errors);
errors = vErrors.length;
}
var valid26 = _errs152 === errors;
}
else {
var valid26 = true;
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
const err83 = {instancePath:instancePath+"/queries/" + i3+"/declaration/execution",schemaPath:"#/properties/queries/items/anyOf/0/properties/declaration/oneOf/0/properties/execution/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
}
}
else {
const err84 = {instancePath:instancePath+"/queries/" + i3+"/declaration",schemaPath:"#/properties/queries/items/anyOf/0/properties/declaration/oneOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err84];
}
else {
vErrors.push(err84);
}
errors++;
}
}
var _valid5 = _errs136 === errors;
if(_valid5){
valid24 = true;
passing1 = 0;
var props5 = true;
}
const _errs153 = errors;
if(errors === _errs153){
if(data65 && typeof data65 == "object" && !Array.isArray(data65)){
let missing17;
if((data65.request === undefined) && (missing17 = "request")){
const err85 = {instancePath:instancePath+"/queries/" + i3+"/declaration",schemaPath:"#/properties/queries/items/anyOf/0/properties/declaration/oneOf/1/required",keyword:"required",params:{missingProperty: missing17},message:"must have required property '"+missing17+"'"};
if(vErrors === null){
vErrors = [err85];
}
else {
vErrors.push(err85);
}
errors++;
}
else {
const _errs155 = errors;
for(const key17 in data65){
if(!(key17 === "request")){
const err86 = {instancePath:instancePath+"/queries/" + i3+"/declaration",schemaPath:"#/properties/queries/items/anyOf/0/properties/declaration/oneOf/1/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key17},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err86];
}
else {
vErrors.push(err86);
}
errors++;
break;
}
}
if(_errs155 === errors){
if(data65.request !== undefined){
let data76 = data65.request;
const _errs156 = errors;
if(errors === _errs156){
if(data76 && typeof data76 == "object" && !Array.isArray(data76)){
let missing18;
if(((((((((data76.namespace === undefined) && (missing18 = "namespace")) || ((data76.correlation === undefined) && (missing18 = "correlation"))) || ((data76.phase === undefined) && (missing18 = "phase"))) || ((data76.failure === undefined) && (missing18 = "failure"))) || ((data76.collected === undefined) && (missing18 = "collected"))) || ((data76.result_resource === undefined) && (missing18 = "result_resource"))) || ((data76.result_namespace === undefined) && (missing18 = "result_namespace"))) || ((data76.result_digest === undefined) && (missing18 = "result_digest"))){
const err87 = {instancePath:instancePath+"/queries/" + i3+"/declaration/request",schemaPath:"#/properties/queries/items/anyOf/0/properties/declaration/oneOf/1/properties/request/required",keyword:"required",params:{missingProperty: missing18},message:"must have required property '"+missing18+"'"};
if(vErrors === null){
vErrors = [err87];
}
else {
vErrors.push(err87);
}
errors++;
}
else {
const _errs158 = errors;
for(const key18 in data76){
if(!((((((((key18 === "namespace") || (key18 === "correlation")) || (key18 === "phase")) || (key18 === "failure")) || (key18 === "collected")) || (key18 === "result_resource")) || (key18 === "result_namespace")) || (key18 === "result_digest"))){
const err88 = {instancePath:instancePath+"/queries/" + i3+"/declaration/request",schemaPath:"#/properties/queries/items/anyOf/0/properties/declaration/oneOf/1/properties/request/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key18},message:"must NOT have additional properties"};
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
if(_errs158 === errors){
if(data76.namespace !== undefined){
let data77 = data76.namespace;
const _errs159 = errors;
if(errors === _errs159){
if(typeof data77 === "string"){
if(func4(data77) > 256){
const err89 = {instancePath:instancePath+"/queries/" + i3+"/declaration/request/namespace",schemaPath:"#/properties/queries/items/anyOf/0/properties/declaration/oneOf/1/properties/request/properties/namespace/maxLength",keyword:"maxLength",params:{limit: 256},message:"must NOT have more than 256 characters"};
if(vErrors === null){
vErrors = [err89];
}
else {
vErrors.push(err89);
}
errors++;
}
}
else {
const err90 = {instancePath:instancePath+"/queries/" + i3+"/declaration/request/namespace",schemaPath:"#/properties/queries/items/anyOf/0/properties/declaration/oneOf/1/properties/request/properties/namespace/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err90];
}
else {
vErrors.push(err90);
}
errors++;
}
}
var valid28 = _errs159 === errors;
}
else {
var valid28 = true;
}
if(valid28){
if(data76.correlation !== undefined){
const _errs161 = errors;
if(!(validate55(data76.correlation, {instancePath:instancePath+"/queries/" + i3+"/declaration/request/correlation",parentData:data76,parentDataProperty:"correlation",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate55.errors : vErrors.concat(validate55.errors);
errors = vErrors.length;
}
var valid28 = _errs161 === errors;
}
else {
var valid28 = true;
}
if(valid28){
if(data76.phase !== undefined){
const _errs162 = errors;
if(!(validate473(data76.phase, {instancePath:instancePath+"/queries/" + i3+"/declaration/request/phase",parentData:data76,parentDataProperty:"phase",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate473.errors : vErrors.concat(validate473.errors);
errors = vErrors.length;
}
var valid28 = _errs162 === errors;
}
else {
var valid28 = true;
}
if(valid28){
if(data76.failure !== undefined){
const _errs163 = errors;
if(!(validate461(data76.failure, {instancePath:instancePath+"/queries/" + i3+"/declaration/request/failure",parentData:data76,parentDataProperty:"failure",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate461.errors : vErrors.concat(validate461.errors);
errors = vErrors.length;
}
var valid28 = _errs163 === errors;
}
else {
var valid28 = true;
}
if(valid28){
if(data76.collected !== undefined){
const _errs164 = errors;
if(typeof data76.collected !== "boolean"){
const err91 = {instancePath:instancePath+"/queries/" + i3+"/declaration/request/collected",schemaPath:"#/properties/queries/items/anyOf/0/properties/declaration/oneOf/1/properties/request/properties/collected/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"};
if(vErrors === null){
vErrors = [err91];
}
else {
vErrors.push(err91);
}
errors++;
}
var valid28 = _errs164 === errors;
}
else {
var valid28 = true;
}
if(valid28){
if(data76.result_resource !== undefined){
const _errs166 = errors;
if(!(validate57(data76.result_resource, {instancePath:instancePath+"/queries/" + i3+"/declaration/request/result_resource",parentData:data76,parentDataProperty:"result_resource",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate57.errors : vErrors.concat(validate57.errors);
errors = vErrors.length;
}
var valid28 = _errs166 === errors;
}
else {
var valid28 = true;
}
if(valid28){
if(data76.result_namespace !== undefined){
const _errs167 = errors;
if(!(validate415(data76.result_namespace, {instancePath:instancePath+"/queries/" + i3+"/declaration/request/result_namespace",parentData:data76,parentDataProperty:"result_namespace",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate415.errors : vErrors.concat(validate415.errors);
errors = vErrors.length;
}
var valid28 = _errs167 === errors;
}
else {
var valid28 = true;
}
if(valid28){
if(data76.result_digest !== undefined){
const _errs168 = errors;
if(!(validate116(data76.result_digest, {instancePath:instancePath+"/queries/" + i3+"/declaration/request/result_digest",parentData:data76,parentDataProperty:"result_digest",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate116.errors : vErrors.concat(validate116.errors);
errors = vErrors.length;
}
var valid28 = _errs168 === errors;
}
else {
var valid28 = true;
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
const err92 = {instancePath:instancePath+"/queries/" + i3+"/declaration/request",schemaPath:"#/properties/queries/items/anyOf/0/properties/declaration/oneOf/1/properties/request/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
}
}
}
else {
const err93 = {instancePath:instancePath+"/queries/" + i3+"/declaration",schemaPath:"#/properties/queries/items/anyOf/0/properties/declaration/oneOf/1/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err93];
}
else {
vErrors.push(err93);
}
errors++;
}
}
var _valid5 = _errs153 === errors;
if(_valid5 && valid24){
valid24 = false;
passing1 = [passing1, 1];
}
else {
if(_valid5){
valid24 = true;
passing1 = 1;
if(props5 !== true){
props5 = true;
}
}
const _errs169 = errors;
if(errors === _errs169){
if(data65 && typeof data65 == "object" && !Array.isArray(data65)){
let missing19;
if((data65.capture === undefined) && (missing19 = "capture")){
const err94 = {instancePath:instancePath+"/queries/" + i3+"/declaration",schemaPath:"#/properties/queries/items/anyOf/0/properties/declaration/oneOf/2/required",keyword:"required",params:{missingProperty: missing19},message:"must have required property '"+missing19+"'"};
if(vErrors === null){
vErrors = [err94];
}
else {
vErrors.push(err94);
}
errors++;
}
else {
const _errs171 = errors;
for(const key19 in data65){
if(!(key19 === "capture")){
const err95 = {instancePath:instancePath+"/queries/" + i3+"/declaration",schemaPath:"#/properties/queries/items/anyOf/0/properties/declaration/oneOf/2/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key19},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err95];
}
else {
vErrors.push(err95);
}
errors++;
break;
}
}
if(_errs171 === errors){
if(data65.capture !== undefined){
let data85 = data65.capture;
const _errs172 = errors;
if(errors === _errs172){
if(data85 && typeof data85 == "object" && !Array.isArray(data85)){
let missing20;
if((((((((((((data85.result === undefined) && (missing20 = "result")) || ((data85.destination === undefined) && (missing20 = "destination"))) || ((data85.correlation === undefined) && (missing20 = "correlation"))) || ((data85.table === undefined) && (missing20 = "table"))) || ((data85.source === undefined) && (missing20 = "source"))) || ((data85.policy_revision === undefined) && (missing20 = "policy_revision"))) || ((data85.phase === undefined) && (missing20 = "phase"))) || ((data85.bytes === undefined) && (missing20 = "bytes"))) || ((data85.send_segment === undefined) && (missing20 = "send_segment"))) || ((data85.send_offset === undefined) && (missing20 = "send_offset"))) || ((data85.chain === undefined) && (missing20 = "chain"))){
const err96 = {instancePath:instancePath+"/queries/" + i3+"/declaration/capture",schemaPath:"#/properties/queries/items/anyOf/0/properties/declaration/oneOf/2/properties/capture/required",keyword:"required",params:{missingProperty: missing20},message:"must have required property '"+missing20+"'"};
if(vErrors === null){
vErrors = [err96];
}
else {
vErrors.push(err96);
}
errors++;
}
else {
const _errs174 = errors;
for(const key20 in data85){
if(!(func1.call(schema100.properties.queries.items.anyOf[0].properties.declaration.oneOf[2].properties.capture.properties, key20))){
const err97 = {instancePath:instancePath+"/queries/" + i3+"/declaration/capture",schemaPath:"#/properties/queries/items/anyOf/0/properties/declaration/oneOf/2/properties/capture/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key20},message:"must NOT have additional properties"};
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
if(_errs174 === errors){
if(data85.result !== undefined){
const _errs175 = errors;
if(!(validate55(data85.result, {instancePath:instancePath+"/queries/" + i3+"/declaration/capture/result",parentData:data85,parentDataProperty:"result",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate55.errors : vErrors.concat(validate55.errors);
errors = vErrors.length;
}
var valid30 = _errs175 === errors;
}
else {
var valid30 = true;
}
if(valid30){
if(data85.destination !== undefined){
const _errs176 = errors;
if(!(validate55(data85.destination, {instancePath:instancePath+"/queries/" + i3+"/declaration/capture/destination",parentData:data85,parentDataProperty:"destination",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate55.errors : vErrors.concat(validate55.errors);
errors = vErrors.length;
}
var valid30 = _errs176 === errors;
}
else {
var valid30 = true;
}
if(valid30){
if(data85.correlation !== undefined){
let data88 = data85.correlation;
const _errs177 = errors;
if(errors === _errs177){
if(typeof data88 === "string"){
if(func4(data88) > 256){
const err98 = {instancePath:instancePath+"/queries/" + i3+"/declaration/capture/correlation",schemaPath:"#/properties/queries/items/anyOf/0/properties/declaration/oneOf/2/properties/capture/properties/correlation/maxLength",keyword:"maxLength",params:{limit: 256},message:"must NOT have more than 256 characters"};
if(vErrors === null){
vErrors = [err98];
}
else {
vErrors.push(err98);
}
errors++;
}
}
else {
const err99 = {instancePath:instancePath+"/queries/" + i3+"/declaration/capture/correlation",schemaPath:"#/properties/queries/items/anyOf/0/properties/declaration/oneOf/2/properties/capture/properties/correlation/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err99];
}
else {
vErrors.push(err99);
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
if(data85.table !== undefined){
const _errs179 = errors;
if(!(validate53(data85.table, {instancePath:instancePath+"/queries/" + i3+"/declaration/capture/table",parentData:data85,parentDataProperty:"table",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate53.errors : vErrors.concat(validate53.errors);
errors = vErrors.length;
}
var valid30 = _errs179 === errors;
}
else {
var valid30 = true;
}
if(valid30){
if(data85.source !== undefined){
const _errs180 = errors;
if(!(validate455(data85.source, {instancePath:instancePath+"/queries/" + i3+"/declaration/capture/source",parentData:data85,parentDataProperty:"source",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate455.errors : vErrors.concat(validate455.errors);
errors = vErrors.length;
}
var valid30 = _errs180 === errors;
}
else {
var valid30 = true;
}
if(valid30){
if(data85.policy_revision !== undefined){
let data91 = data85.policy_revision;
const _errs181 = errors;
if(errors === _errs181){
if(typeof data91 === "string"){
if(func4(data91) > 256){
const err100 = {instancePath:instancePath+"/queries/" + i3+"/declaration/capture/policy_revision",schemaPath:"#/properties/queries/items/anyOf/0/properties/declaration/oneOf/2/properties/capture/properties/policy_revision/maxLength",keyword:"maxLength",params:{limit: 256},message:"must NOT have more than 256 characters"};
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
const err101 = {instancePath:instancePath+"/queries/" + i3+"/declaration/capture/policy_revision",schemaPath:"#/properties/queries/items/anyOf/0/properties/declaration/oneOf/2/properties/capture/properties/policy_revision/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err101];
}
else {
vErrors.push(err101);
}
errors++;
}
}
var valid30 = _errs181 === errors;
}
else {
var valid30 = true;
}
if(valid30){
if(data85.phase !== undefined){
const _errs183 = errors;
if(!(validate350(data85.phase, {instancePath:instancePath+"/queries/" + i3+"/declaration/capture/phase",parentData:data85,parentDataProperty:"phase",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate350.errors : vErrors.concat(validate350.errors);
errors = vErrors.length;
}
var valid30 = _errs183 === errors;
}
else {
var valid30 = true;
}
if(valid30){
if(data85.bytes !== undefined){
let data93 = data85.bytes;
const _errs184 = errors;
if(errors === _errs184){
if(typeof data93 === "string"){
if(func4(data93) > 256){
const err102 = {instancePath:instancePath+"/queries/" + i3+"/declaration/capture/bytes",schemaPath:"#/properties/queries/items/anyOf/0/properties/declaration/oneOf/2/properties/capture/properties/bytes/maxLength",keyword:"maxLength",params:{limit: 256},message:"must NOT have more than 256 characters"};
if(vErrors === null){
vErrors = [err102];
}
else {
vErrors.push(err102);
}
errors++;
}
}
else {
const err103 = {instancePath:instancePath+"/queries/" + i3+"/declaration/capture/bytes",schemaPath:"#/properties/queries/items/anyOf/0/properties/declaration/oneOf/2/properties/capture/properties/bytes/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err103];
}
else {
vErrors.push(err103);
}
errors++;
}
}
var valid30 = _errs184 === errors;
}
else {
var valid30 = true;
}
if(valid30){
if(data85.send_segment !== undefined){
let data94 = data85.send_segment;
const _errs186 = errors;
if(errors === _errs186){
if(typeof data94 === "string"){
if(func4(data94) > 256){
const err104 = {instancePath:instancePath+"/queries/" + i3+"/declaration/capture/send_segment",schemaPath:"#/properties/queries/items/anyOf/0/properties/declaration/oneOf/2/properties/capture/properties/send_segment/maxLength",keyword:"maxLength",params:{limit: 256},message:"must NOT have more than 256 characters"};
if(vErrors === null){
vErrors = [err104];
}
else {
vErrors.push(err104);
}
errors++;
}
}
else {
const err105 = {instancePath:instancePath+"/queries/" + i3+"/declaration/capture/send_segment",schemaPath:"#/properties/queries/items/anyOf/0/properties/declaration/oneOf/2/properties/capture/properties/send_segment/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err105];
}
else {
vErrors.push(err105);
}
errors++;
}
}
var valid30 = _errs186 === errors;
}
else {
var valid30 = true;
}
if(valid30){
if(data85.send_offset !== undefined){
const _errs188 = errors;
if(!(validate67(data85.send_offset, {instancePath:instancePath+"/queries/" + i3+"/declaration/capture/send_offset",parentData:data85,parentDataProperty:"send_offset",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate67.errors : vErrors.concat(validate67.errors);
errors = vErrors.length;
}
var valid30 = _errs188 === errors;
}
else {
var valid30 = true;
}
if(valid30){
if(data85.chain !== undefined){
const _errs189 = errors;
if(!(validate105(data85.chain, {instancePath:instancePath+"/queries/" + i3+"/declaration/capture/chain",parentData:data85,parentDataProperty:"chain",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate105.errors : vErrors.concat(validate105.errors);
errors = vErrors.length;
}
var valid30 = _errs189 === errors;
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
}
}
}
}
}
}
else {
const err106 = {instancePath:instancePath+"/queries/" + i3+"/declaration/capture",schemaPath:"#/properties/queries/items/anyOf/0/properties/declaration/oneOf/2/properties/capture/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
}
}
else {
const err107 = {instancePath:instancePath+"/queries/" + i3+"/declaration",schemaPath:"#/properties/queries/items/anyOf/0/properties/declaration/oneOf/2/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err107];
}
else {
vErrors.push(err107);
}
errors++;
}
}
var _valid5 = _errs169 === errors;
if(_valid5 && valid24){
valid24 = false;
passing1 = [passing1, 2];
}
else {
if(_valid5){
valid24 = true;
passing1 = 2;
if(props5 !== true){
props5 = true;
}
}
const _errs190 = errors;
if(errors === _errs190){
if(data65 && typeof data65 == "object" && !Array.isArray(data65)){
let missing21;
if((data65.manifest === undefined) && (missing21 = "manifest")){
const err108 = {instancePath:instancePath+"/queries/" + i3+"/declaration",schemaPath:"#/properties/queries/items/anyOf/0/properties/declaration/oneOf/3/required",keyword:"required",params:{missingProperty: missing21},message:"must have required property '"+missing21+"'"};
if(vErrors === null){
vErrors = [err108];
}
else {
vErrors.push(err108);
}
errors++;
}
else {
const _errs192 = errors;
for(const key21 in data65){
if(!(key21 === "manifest")){
const err109 = {instancePath:instancePath+"/queries/" + i3+"/declaration",schemaPath:"#/properties/queries/items/anyOf/0/properties/declaration/oneOf/3/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key21},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err109];
}
else {
vErrors.push(err109);
}
errors++;
break;
}
}
if(_errs192 === errors){
if(data65.manifest !== undefined){
let data97 = data65.manifest;
const _errs193 = errors;
if(errors === _errs193){
if(data97 && typeof data97 == "object" && !Array.isArray(data97)){
let missing22;
if(((((((((((((data97.result === undefined) && (missing22 = "result")) || ((data97.destination === undefined) && (missing22 = "destination"))) || ((data97.correlation === undefined) && (missing22 = "correlation"))) || ((data97.table === undefined) && (missing22 = "table"))) || ((data97.policy_revision === undefined) && (missing22 = "policy_revision"))) || ((data97.basis === undefined) && (missing22 = "basis"))) || ((data97.plan === undefined) && (missing22 = "plan"))) || ((data97.segments === undefined) && (missing22 = "segments"))) || ((data97.bytes === undefined) && (missing22 = "bytes"))) || ((data97.rows === undefined) && (missing22 = "rows"))) || ((data97.chain === undefined) && (missing22 = "chain"))) || ((data97.schema === undefined) && (missing22 = "schema"))){
const err110 = {instancePath:instancePath+"/queries/" + i3+"/declaration/manifest",schemaPath:"#/properties/queries/items/anyOf/0/properties/declaration/oneOf/3/properties/manifest/required",keyword:"required",params:{missingProperty: missing22},message:"must have required property '"+missing22+"'"};
if(vErrors === null){
vErrors = [err110];
}
else {
vErrors.push(err110);
}
errors++;
}
else {
const _errs195 = errors;
for(const key22 in data97){
if(!(func1.call(schema100.properties.queries.items.anyOf[0].properties.declaration.oneOf[3].properties.manifest.properties, key22))){
const err111 = {instancePath:instancePath+"/queries/" + i3+"/declaration/manifest",schemaPath:"#/properties/queries/items/anyOf/0/properties/declaration/oneOf/3/properties/manifest/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key22},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err111];
}
else {
vErrors.push(err111);
}
errors++;
break;
}
}
if(_errs195 === errors){
if(data97.result !== undefined){
const _errs196 = errors;
if(!(validate55(data97.result, {instancePath:instancePath+"/queries/" + i3+"/declaration/manifest/result",parentData:data97,parentDataProperty:"result",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate55.errors : vErrors.concat(validate55.errors);
errors = vErrors.length;
}
var valid32 = _errs196 === errors;
}
else {
var valid32 = true;
}
if(valid32){
if(data97.destination !== undefined){
const _errs197 = errors;
if(!(validate55(data97.destination, {instancePath:instancePath+"/queries/" + i3+"/declaration/manifest/destination",parentData:data97,parentDataProperty:"destination",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate55.errors : vErrors.concat(validate55.errors);
errors = vErrors.length;
}
var valid32 = _errs197 === errors;
}
else {
var valid32 = true;
}
if(valid32){
if(data97.correlation !== undefined){
let data100 = data97.correlation;
const _errs198 = errors;
if(errors === _errs198){
if(typeof data100 === "string"){
if(func4(data100) > 256){
const err112 = {instancePath:instancePath+"/queries/" + i3+"/declaration/manifest/correlation",schemaPath:"#/properties/queries/items/anyOf/0/properties/declaration/oneOf/3/properties/manifest/properties/correlation/maxLength",keyword:"maxLength",params:{limit: 256},message:"must NOT have more than 256 characters"};
if(vErrors === null){
vErrors = [err112];
}
else {
vErrors.push(err112);
}
errors++;
}
}
else {
const err113 = {instancePath:instancePath+"/queries/" + i3+"/declaration/manifest/correlation",schemaPath:"#/properties/queries/items/anyOf/0/properties/declaration/oneOf/3/properties/manifest/properties/correlation/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err113];
}
else {
vErrors.push(err113);
}
errors++;
}
}
var valid32 = _errs198 === errors;
}
else {
var valid32 = true;
}
if(valid32){
if(data97.table !== undefined){
const _errs200 = errors;
if(!(validate53(data97.table, {instancePath:instancePath+"/queries/" + i3+"/declaration/manifest/table",parentData:data97,parentDataProperty:"table",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate53.errors : vErrors.concat(validate53.errors);
errors = vErrors.length;
}
var valid32 = _errs200 === errors;
}
else {
var valid32 = true;
}
if(valid32){
if(data97.policy_revision !== undefined){
let data102 = data97.policy_revision;
const _errs201 = errors;
if(errors === _errs201){
if(typeof data102 === "string"){
if(func4(data102) > 256){
const err114 = {instancePath:instancePath+"/queries/" + i3+"/declaration/manifest/policy_revision",schemaPath:"#/properties/queries/items/anyOf/0/properties/declaration/oneOf/3/properties/manifest/properties/policy_revision/maxLength",keyword:"maxLength",params:{limit: 256},message:"must NOT have more than 256 characters"};
if(vErrors === null){
vErrors = [err114];
}
else {
vErrors.push(err114);
}
errors++;
}
}
else {
const err115 = {instancePath:instancePath+"/queries/" + i3+"/declaration/manifest/policy_revision",schemaPath:"#/properties/queries/items/anyOf/0/properties/declaration/oneOf/3/properties/manifest/properties/policy_revision/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err115];
}
else {
vErrors.push(err115);
}
errors++;
}
}
var valid32 = _errs201 === errors;
}
else {
var valid32 = true;
}
if(valid32){
if(data97.basis !== undefined){
const _errs203 = errors;
if(!(validate489(data97.basis, {instancePath:instancePath+"/queries/" + i3+"/declaration/manifest/basis",parentData:data97,parentDataProperty:"basis",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate489.errors : vErrors.concat(validate489.errors);
errors = vErrors.length;
}
var valid32 = _errs203 === errors;
}
else {
var valid32 = true;
}
if(valid32){
if(data97.plan !== undefined){
const _errs204 = errors;
if(!(validate105(data97.plan, {instancePath:instancePath+"/queries/" + i3+"/declaration/manifest/plan",parentData:data97,parentDataProperty:"plan",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate105.errors : vErrors.concat(validate105.errors);
errors = vErrors.length;
}
var valid32 = _errs204 === errors;
}
else {
var valid32 = true;
}
if(valid32){
if(data97.segments !== undefined){
let data105 = data97.segments;
const _errs205 = errors;
if(errors === _errs205){
if(typeof data105 === "string"){
if(func4(data105) > 256){
const err116 = {instancePath:instancePath+"/queries/" + i3+"/declaration/manifest/segments",schemaPath:"#/properties/queries/items/anyOf/0/properties/declaration/oneOf/3/properties/manifest/properties/segments/maxLength",keyword:"maxLength",params:{limit: 256},message:"must NOT have more than 256 characters"};
if(vErrors === null){
vErrors = [err116];
}
else {
vErrors.push(err116);
}
errors++;
}
}
else {
const err117 = {instancePath:instancePath+"/queries/" + i3+"/declaration/manifest/segments",schemaPath:"#/properties/queries/items/anyOf/0/properties/declaration/oneOf/3/properties/manifest/properties/segments/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err117];
}
else {
vErrors.push(err117);
}
errors++;
}
}
var valid32 = _errs205 === errors;
}
else {
var valid32 = true;
}
if(valid32){
if(data97.bytes !== undefined){
let data106 = data97.bytes;
const _errs207 = errors;
if(errors === _errs207){
if(typeof data106 === "string"){
if(func4(data106) > 256){
const err118 = {instancePath:instancePath+"/queries/" + i3+"/declaration/manifest/bytes",schemaPath:"#/properties/queries/items/anyOf/0/properties/declaration/oneOf/3/properties/manifest/properties/bytes/maxLength",keyword:"maxLength",params:{limit: 256},message:"must NOT have more than 256 characters"};
if(vErrors === null){
vErrors = [err118];
}
else {
vErrors.push(err118);
}
errors++;
}
}
else {
const err119 = {instancePath:instancePath+"/queries/" + i3+"/declaration/manifest/bytes",schemaPath:"#/properties/queries/items/anyOf/0/properties/declaration/oneOf/3/properties/manifest/properties/bytes/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err119];
}
else {
vErrors.push(err119);
}
errors++;
}
}
var valid32 = _errs207 === errors;
}
else {
var valid32 = true;
}
if(valid32){
if(data97.rows !== undefined){
let data107 = data97.rows;
const _errs209 = errors;
if(errors === _errs209){
if(typeof data107 === "string"){
if(func4(data107) > 256){
const err120 = {instancePath:instancePath+"/queries/" + i3+"/declaration/manifest/rows",schemaPath:"#/properties/queries/items/anyOf/0/properties/declaration/oneOf/3/properties/manifest/properties/rows/maxLength",keyword:"maxLength",params:{limit: 256},message:"must NOT have more than 256 characters"};
if(vErrors === null){
vErrors = [err120];
}
else {
vErrors.push(err120);
}
errors++;
}
}
else {
const err121 = {instancePath:instancePath+"/queries/" + i3+"/declaration/manifest/rows",schemaPath:"#/properties/queries/items/anyOf/0/properties/declaration/oneOf/3/properties/manifest/properties/rows/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err121];
}
else {
vErrors.push(err121);
}
errors++;
}
}
var valid32 = _errs209 === errors;
}
else {
var valid32 = true;
}
if(valid32){
if(data97.chain !== undefined){
const _errs211 = errors;
if(!(validate105(data97.chain, {instancePath:instancePath+"/queries/" + i3+"/declaration/manifest/chain",parentData:data97,parentDataProperty:"chain",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate105.errors : vErrors.concat(validate105.errors);
errors = vErrors.length;
}
var valid32 = _errs211 === errors;
}
else {
var valid32 = true;
}
if(valid32){
if(data97.schema !== undefined){
const _errs212 = errors;
if(!(validate105(data97.schema, {instancePath:instancePath+"/queries/" + i3+"/declaration/manifest/schema",parentData:data97,parentDataProperty:"schema",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate105.errors : vErrors.concat(validate105.errors);
errors = vErrors.length;
}
var valid32 = _errs212 === errors;
}
else {
var valid32 = true;
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
const err122 = {instancePath:instancePath+"/queries/" + i3+"/declaration/manifest",schemaPath:"#/properties/queries/items/anyOf/0/properties/declaration/oneOf/3/properties/manifest/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
}
}
else {
const err123 = {instancePath:instancePath+"/queries/" + i3+"/declaration",schemaPath:"#/properties/queries/items/anyOf/0/properties/declaration/oneOf/3/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err123];
}
else {
vErrors.push(err123);
}
errors++;
}
}
var _valid5 = _errs190 === errors;
if(_valid5 && valid24){
valid24 = false;
passing1 = [passing1, 3];
}
else {
if(_valid5){
valid24 = true;
passing1 = 3;
if(props5 !== true){
props5 = true;
}
}
}
}
}
if(!valid24){
const err124 = {instancePath:instancePath+"/queries/" + i3+"/declaration",schemaPath:"#/properties/queries/items/anyOf/0/properties/declaration/oneOf",keyword:"oneOf",params:{passingSchemas: passing1},message:"must match exactly one schema in oneOf"};
if(vErrors === null){
vErrors = [err124];
}
else {
vErrors.push(err124);
}
errors++;
}
else {
errors = _errs135;
if(vErrors !== null){
if(_errs135){
vErrors.length = _errs135;
}
else {
vErrors = null;
}
}
}
var valid23 = _errs134 === errors;
}
else {
var valid23 = true;
}
}
}
}
}
}
else {
const err125 = {instancePath:instancePath+"/queries/" + i3,schemaPath:"#/properties/queries/items/anyOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err125];
}
else {
vErrors.push(err125);
}
errors++;
}
}
var _valid4 = _errs129 === errors;
valid22 = valid22 || _valid4;
const _errs213 = errors;
if(data62 !== null){
const err126 = {instancePath:instancePath+"/queries/" + i3,schemaPath:"#/properties/queries/items/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err126];
}
else {
vErrors.push(err126);
}
errors++;
}
var _valid4 = _errs213 === errors;
valid22 = valid22 || _valid4;
if(!valid22){
const err127 = {instancePath:instancePath+"/queries/" + i3,schemaPath:"#/properties/queries/items/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err127];
}
else {
vErrors.push(err127);
}
errors++;
validate391.errors = vErrors;
return false;
}
else {
errors = _errs128;
if(vErrors !== null){
if(_errs128){
vErrors.length = _errs128;
}
else {
vErrors = null;
}
}
}
var valid21 = _errs127 === errors;
if(!valid21){
break;
}
}
}
}
}
else {
validate391.errors = [{instancePath:instancePath+"/queries",schemaPath:"#/properties/queries/type",keyword:"type",params:{type: "array"},message:"must be array"}];
return false;
}
}
var valid0 = _errs125 === errors;
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
validate391.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate391.errors = vErrors;
return errors === 0;
}
validate391.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

export const HttpResponse = validate500;
const schema116 = {"type":"object","additionalProperties":false,"properties":{"version":{"$ref":"https://transit.invalid/generated-validator/9"},"source":{"$ref":"https://transit.invalid/generated-validator/72"},"exchange":{"type":"string","maxLength":256},"phase":{"$ref":"https://transit.invalid/generated-validator/78"},"coverage":{"$ref":"https://transit.invalid/generated-validator/11"},"failure":{"$ref":"https://transit.invalid/generated-validator/90"},"policy":{"anyOf":[{"type":"object","additionalProperties":false,"properties":{"member":{"$ref":"https://transit.invalid/generated-validator/92"},"endpoint_revision":{"type":"string","maxLength":256},"tls":{"type":"boolean"},"trust_digest":{"$ref":"https://transit.invalid/generated-validator/15"},"timeout_ms":{"$ref":"https://transit.invalid/generated-validator/0"},"request_bytes":{"type":"string","maxLength":256},"response_bytes":{"type":"string","maxLength":256},"method":{"type":"string","enum":["GET","HEAD","POST","PUT","DELETE","CONNECT","OPTIONS","TRACE","PATCH","QUERY"]},"retry":{"$ref":"https://transit.invalid/generated-validator/94"},"redirect":{"$ref":"https://transit.invalid/generated-validator/94"},"reconcile":{"$ref":"https://transit.invalid/generated-validator/94"},"cancel":{"$ref":"https://transit.invalid/generated-validator/94"}},"required":["member","endpoint_revision","tls","trust_digest","timeout_ms","request_bytes","response_bytes","method","retry","redirect","reconcile","cancel"]},{"type":"null"}]},"terminal":{"anyOf":[{"type":"object","additionalProperties":false,"properties":{"timing":{"type":"object","additionalProperties":false,"properties":{"member":{"$ref":"https://transit.invalid/generated-validator/92"},"started_ms":{"type":"string","maxLength":256},"elapsed_ns":{"type":"string","maxLength":256}},"required":["member","started_ms","elapsed_ns"]},"omission":{"type":"object","additionalProperties":false,"properties":{"member":{"$ref":"https://transit.invalid/generated-validator/92"},"response_headers":{"$ref":"https://transit.invalid/generated-validator/0"},"request_secrets":{"$ref":"https://transit.invalid/generated-validator/0"}},"required":["member","response_headers","request_secrets"]},"completion":{"type":"object","additionalProperties":false,"properties":{"member":{"$ref":"https://transit.invalid/generated-validator/92"},"status":{"$ref":"https://transit.invalid/generated-validator/4"},"request_bytes":{"type":"string","maxLength":256},"response_bytes":{"type":"string","maxLength":256},"heads":{"$ref":"https://transit.invalid/generated-validator/9"},"framing":{"type":"string","enum":["none","length","chunked","close"]}},"required":["member","status","request_bytes","response_bytes","heads","framing"]}},"required":["timing","omission","completion"]},{"type":"null"}]}},"required":["version","source","exchange","phase","coverage","failure","policy","terminal"]};
const schema117 = {"anyOf":[{"$ref":"https://transit.invalid/generated-validator/79"},{"type":"null"}]};

function validate505(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate505.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate401(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate401.errors : vErrors.concat(validate401.errors);
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
validate505.errors = vErrors;
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
validate505.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate505.evaluated = {"dynamicProps":true,"dynamicItems":false};

const schema118 = {"type":"object","additionalProperties":false,"properties":{"key":{"$ref":"https://transit.invalid/generated-validator/21"},"ordinal":{"$ref":"https://transit.invalid/generated-validator/0"},"kind":{"$ref":"https://transit.invalid/generated-validator/91"},"bytes":{"$ref":"https://transit.invalid/generated-validator/0"},"digest":{"$ref":"https://transit.invalid/generated-validator/11"},"chain":{"$ref":"https://transit.invalid/generated-validator/11"}},"required":["key","ordinal","kind","bytes","digest","chain"]};
const schema119 = {"type":"string","enum":["request_template","request_head","request_body","response_head","response_body","response_trailers","timing","omission","completion"]};

function validate511(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate511.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate511.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
if(!(((((((((data === "request_template") || (data === "request_head")) || (data === "request_body")) || (data === "response_head")) || (data === "response_body")) || (data === "response_trailers")) || (data === "timing")) || (data === "omission")) || (data === "completion"))){
validate511.errors = [{instancePath,schemaPath:"#/enum",keyword:"enum",params:{allowedValues: schema119.enum},message:"must be equal to one of the allowed values"}];
return false;
}
validate511.errors = vErrors;
return errors === 0;
}
validate511.evaluated = {"dynamicProps":false,"dynamicItems":false};


function validate508(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate508.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if(((((((data.key === undefined) && (missing0 = "key")) || ((data.ordinal === undefined) && (missing0 = "ordinal"))) || ((data.kind === undefined) && (missing0 = "kind"))) || ((data.bytes === undefined) && (missing0 = "bytes"))) || ((data.digest === undefined) && (missing0 = "digest"))) || ((data.chain === undefined) && (missing0 = "chain"))){
validate508.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((((((key0 === "key") || (key0 === "ordinal")) || (key0 === "kind")) || (key0 === "bytes")) || (key0 === "digest")) || (key0 === "chain"))){
validate508.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.key !== undefined){
const _errs2 = errors;
if(!(validate134(data.key, {instancePath:instancePath+"/key",parentData:data,parentDataProperty:"key",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate134.errors : vErrors.concat(validate134.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.ordinal !== undefined){
const _errs3 = errors;
if(!(validate53(data.ordinal, {instancePath:instancePath+"/ordinal",parentData:data,parentDataProperty:"ordinal",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate53.errors : vErrors.concat(validate53.errors);
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
if(!(validate511(data.kind, {instancePath:instancePath+"/kind",parentData:data,parentDataProperty:"kind",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate511.errors : vErrors.concat(validate511.errors);
errors = vErrors.length;
}
var valid0 = _errs4 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.bytes !== undefined){
const _errs5 = errors;
if(!(validate53(data.bytes, {instancePath:instancePath+"/bytes",parentData:data,parentDataProperty:"bytes",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate53.errors : vErrors.concat(validate53.errors);
errors = vErrors.length;
}
var valid0 = _errs5 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.digest !== undefined){
const _errs6 = errors;
if(!(validate105(data.digest, {instancePath:instancePath+"/digest",parentData:data,parentDataProperty:"digest",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate105.errors : vErrors.concat(validate105.errors);
errors = vErrors.length;
}
var valid0 = _errs6 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.chain !== undefined){
const _errs7 = errors;
if(!(validate105(data.chain, {instancePath:instancePath+"/chain",parentData:data,parentDataProperty:"chain",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate105.errors : vErrors.concat(validate105.errors);
errors = vErrors.length;
}
var valid0 = _errs7 === errors;
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
else {
validate508.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate508.errors = vErrors;
return errors === 0;
}
validate508.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema120 = {"anyOf":[{"$ref":"https://transit.invalid/generated-validator/93"},{"type":"null"}]};
const schema121 = {"type":"object","additionalProperties":false,"properties":{"id":{"type":"string","maxLength":256},"revision":{"type":"string","maxLength":256}},"required":["id","revision"]};

function validate520(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate520.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if(((data.id === undefined) && (missing0 = "id")) || ((data.revision === undefined) && (missing0 = "revision"))){
validate520.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "id") || (key0 === "revision"))){
validate520.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.id !== undefined){
let data0 = data.id;
const _errs2 = errors;
if(errors === _errs2){
if(typeof data0 === "string"){
if(func4(data0) > 256){
validate520.errors = [{instancePath:instancePath+"/id",schemaPath:"#/properties/id/maxLength",keyword:"maxLength",params:{limit: 256},message:"must NOT have more than 256 characters"}];
return false;
}
}
else {
validate520.errors = [{instancePath:instancePath+"/id",schemaPath:"#/properties/id/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.revision !== undefined){
let data1 = data.revision;
const _errs4 = errors;
if(errors === _errs4){
if(typeof data1 === "string"){
if(func4(data1) > 256){
validate520.errors = [{instancePath:instancePath+"/revision",schemaPath:"#/properties/revision/maxLength",keyword:"maxLength",params:{limit: 256},message:"must NOT have more than 256 characters"}];
return false;
}
}
else {
validate520.errors = [{instancePath:instancePath+"/revision",schemaPath:"#/properties/revision/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
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
else {
validate520.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate520.errors = vErrors;
return errors === 0;
}
validate520.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate519(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate519.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate520(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate520.errors : vErrors.concat(validate520.errors);
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
validate519.errors = vErrors;
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
validate519.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate519.evaluated = {"dynamicProps":true,"dynamicItems":false};


function validate500(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate500.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if(((((((((data.version === undefined) && (missing0 = "version")) || ((data.source === undefined) && (missing0 = "source"))) || ((data.exchange === undefined) && (missing0 = "exchange"))) || ((data.phase === undefined) && (missing0 = "phase"))) || ((data.coverage === undefined) && (missing0 = "coverage"))) || ((data.failure === undefined) && (missing0 = "failure"))) || ((data.policy === undefined) && (missing0 = "policy"))) || ((data.terminal === undefined) && (missing0 = "terminal"))){
validate500.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((((((((key0 === "version") || (key0 === "source")) || (key0 === "exchange")) || (key0 === "phase")) || (key0 === "coverage")) || (key0 === "failure")) || (key0 === "policy")) || (key0 === "terminal"))){
validate500.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.version !== undefined){
const _errs2 = errors;
if(!(validate102(data.version, {instancePath:instancePath+"/version",parentData:data,parentDataProperty:"version",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate102.errors : vErrors.concat(validate102.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.source !== undefined){
const _errs3 = errors;
if(!(validate315(data.source, {instancePath:instancePath+"/source",parentData:data,parentDataProperty:"source",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate315.errors : vErrors.concat(validate315.errors);
errors = vErrors.length;
}
var valid0 = _errs3 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.exchange !== undefined){
let data2 = data.exchange;
const _errs4 = errors;
if(errors === _errs4){
if(typeof data2 === "string"){
if(func4(data2) > 256){
validate500.errors = [{instancePath:instancePath+"/exchange",schemaPath:"#/properties/exchange/maxLength",keyword:"maxLength",params:{limit: 256},message:"must NOT have more than 256 characters"}];
return false;
}
}
else {
validate500.errors = [{instancePath:instancePath+"/exchange",schemaPath:"#/properties/exchange/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
}
var valid0 = _errs4 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.phase !== undefined){
const _errs6 = errors;
if(!(validate417(data.phase, {instancePath:instancePath+"/phase",parentData:data,parentDataProperty:"phase",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate417.errors : vErrors.concat(validate417.errors);
errors = vErrors.length;
}
var valid0 = _errs6 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.coverage !== undefined){
const _errs7 = errors;
if(!(validate105(data.coverage, {instancePath:instancePath+"/coverage",parentData:data,parentDataProperty:"coverage",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate105.errors : vErrors.concat(validate105.errors);
errors = vErrors.length;
}
var valid0 = _errs7 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.failure !== undefined){
const _errs8 = errors;
if(!(validate505(data.failure, {instancePath:instancePath+"/failure",parentData:data,parentDataProperty:"failure",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate505.errors : vErrors.concat(validate505.errors);
errors = vErrors.length;
}
var valid0 = _errs8 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.policy !== undefined){
let data6 = data.policy;
const _errs9 = errors;
const _errs10 = errors;
let valid1 = false;
const _errs11 = errors;
if(errors === _errs11){
if(data6 && typeof data6 == "object" && !Array.isArray(data6)){
let missing1;
if(((((((((((((data6.member === undefined) && (missing1 = "member")) || ((data6.endpoint_revision === undefined) && (missing1 = "endpoint_revision"))) || ((data6.tls === undefined) && (missing1 = "tls"))) || ((data6.trust_digest === undefined) && (missing1 = "trust_digest"))) || ((data6.timeout_ms === undefined) && (missing1 = "timeout_ms"))) || ((data6.request_bytes === undefined) && (missing1 = "request_bytes"))) || ((data6.response_bytes === undefined) && (missing1 = "response_bytes"))) || ((data6.method === undefined) && (missing1 = "method"))) || ((data6.retry === undefined) && (missing1 = "retry"))) || ((data6.redirect === undefined) && (missing1 = "redirect"))) || ((data6.reconcile === undefined) && (missing1 = "reconcile"))) || ((data6.cancel === undefined) && (missing1 = "cancel"))){
const err0 = {instancePath:instancePath+"/policy",schemaPath:"#/properties/policy/anyOf/0/required",keyword:"required",params:{missingProperty: missing1},message:"must have required property '"+missing1+"'"};
if(vErrors === null){
vErrors = [err0];
}
else {
vErrors.push(err0);
}
errors++;
}
else {
const _errs13 = errors;
for(const key1 in data6){
if(!(func1.call(schema116.properties.policy.anyOf[0].properties, key1))){
const err1 = {instancePath:instancePath+"/policy",schemaPath:"#/properties/policy/anyOf/0/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key1},message:"must NOT have additional properties"};
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
if(_errs13 === errors){
if(data6.member !== undefined){
const _errs14 = errors;
if(!(validate508(data6.member, {instancePath:instancePath+"/policy/member",parentData:data6,parentDataProperty:"member",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate508.errors : vErrors.concat(validate508.errors);
errors = vErrors.length;
}
var valid2 = _errs14 === errors;
}
else {
var valid2 = true;
}
if(valid2){
if(data6.endpoint_revision !== undefined){
let data8 = data6.endpoint_revision;
const _errs15 = errors;
if(errors === _errs15){
if(typeof data8 === "string"){
if(func4(data8) > 256){
const err2 = {instancePath:instancePath+"/policy/endpoint_revision",schemaPath:"#/properties/policy/anyOf/0/properties/endpoint_revision/maxLength",keyword:"maxLength",params:{limit: 256},message:"must NOT have more than 256 characters"};
if(vErrors === null){
vErrors = [err2];
}
else {
vErrors.push(err2);
}
errors++;
}
}
else {
const err3 = {instancePath:instancePath+"/policy/endpoint_revision",schemaPath:"#/properties/policy/anyOf/0/properties/endpoint_revision/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err3];
}
else {
vErrors.push(err3);
}
errors++;
}
}
var valid2 = _errs15 === errors;
}
else {
var valid2 = true;
}
if(valid2){
if(data6.tls !== undefined){
const _errs17 = errors;
if(typeof data6.tls !== "boolean"){
const err4 = {instancePath:instancePath+"/policy/tls",schemaPath:"#/properties/policy/anyOf/0/properties/tls/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"};
if(vErrors === null){
vErrors = [err4];
}
else {
vErrors.push(err4);
}
errors++;
}
var valid2 = _errs17 === errors;
}
else {
var valid2 = true;
}
if(valid2){
if(data6.trust_digest !== undefined){
const _errs19 = errors;
if(!(validate116(data6.trust_digest, {instancePath:instancePath+"/policy/trust_digest",parentData:data6,parentDataProperty:"trust_digest",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate116.errors : vErrors.concat(validate116.errors);
errors = vErrors.length;
}
var valid2 = _errs19 === errors;
}
else {
var valid2 = true;
}
if(valid2){
if(data6.timeout_ms !== undefined){
const _errs20 = errors;
if(!(validate53(data6.timeout_ms, {instancePath:instancePath+"/policy/timeout_ms",parentData:data6,parentDataProperty:"timeout_ms",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate53.errors : vErrors.concat(validate53.errors);
errors = vErrors.length;
}
var valid2 = _errs20 === errors;
}
else {
var valid2 = true;
}
if(valid2){
if(data6.request_bytes !== undefined){
let data12 = data6.request_bytes;
const _errs21 = errors;
if(errors === _errs21){
if(typeof data12 === "string"){
if(func4(data12) > 256){
const err5 = {instancePath:instancePath+"/policy/request_bytes",schemaPath:"#/properties/policy/anyOf/0/properties/request_bytes/maxLength",keyword:"maxLength",params:{limit: 256},message:"must NOT have more than 256 characters"};
if(vErrors === null){
vErrors = [err5];
}
else {
vErrors.push(err5);
}
errors++;
}
}
else {
const err6 = {instancePath:instancePath+"/policy/request_bytes",schemaPath:"#/properties/policy/anyOf/0/properties/request_bytes/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err6];
}
else {
vErrors.push(err6);
}
errors++;
}
}
var valid2 = _errs21 === errors;
}
else {
var valid2 = true;
}
if(valid2){
if(data6.response_bytes !== undefined){
let data13 = data6.response_bytes;
const _errs23 = errors;
if(errors === _errs23){
if(typeof data13 === "string"){
if(func4(data13) > 256){
const err7 = {instancePath:instancePath+"/policy/response_bytes",schemaPath:"#/properties/policy/anyOf/0/properties/response_bytes/maxLength",keyword:"maxLength",params:{limit: 256},message:"must NOT have more than 256 characters"};
if(vErrors === null){
vErrors = [err7];
}
else {
vErrors.push(err7);
}
errors++;
}
}
else {
const err8 = {instancePath:instancePath+"/policy/response_bytes",schemaPath:"#/properties/policy/anyOf/0/properties/response_bytes/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err8];
}
else {
vErrors.push(err8);
}
errors++;
}
}
var valid2 = _errs23 === errors;
}
else {
var valid2 = true;
}
if(valid2){
if(data6.method !== undefined){
let data14 = data6.method;
const _errs25 = errors;
if(typeof data14 !== "string"){
const err9 = {instancePath:instancePath+"/policy/method",schemaPath:"#/properties/policy/anyOf/0/properties/method/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err9];
}
else {
vErrors.push(err9);
}
errors++;
}
if(!((((((((((data14 === "GET") || (data14 === "HEAD")) || (data14 === "POST")) || (data14 === "PUT")) || (data14 === "DELETE")) || (data14 === "CONNECT")) || (data14 === "OPTIONS")) || (data14 === "TRACE")) || (data14 === "PATCH")) || (data14 === "QUERY"))){
const err10 = {instancePath:instancePath+"/policy/method",schemaPath:"#/properties/policy/anyOf/0/properties/method/enum",keyword:"enum",params:{allowedValues: schema116.properties.policy.anyOf[0].properties.method.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err10];
}
else {
vErrors.push(err10);
}
errors++;
}
var valid2 = _errs25 === errors;
}
else {
var valid2 = true;
}
if(valid2){
if(data6.retry !== undefined){
const _errs27 = errors;
if(!(validate519(data6.retry, {instancePath:instancePath+"/policy/retry",parentData:data6,parentDataProperty:"retry",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate519.errors : vErrors.concat(validate519.errors);
errors = vErrors.length;
}
var valid2 = _errs27 === errors;
}
else {
var valid2 = true;
}
if(valid2){
if(data6.redirect !== undefined){
const _errs28 = errors;
if(!(validate519(data6.redirect, {instancePath:instancePath+"/policy/redirect",parentData:data6,parentDataProperty:"redirect",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate519.errors : vErrors.concat(validate519.errors);
errors = vErrors.length;
}
var valid2 = _errs28 === errors;
}
else {
var valid2 = true;
}
if(valid2){
if(data6.reconcile !== undefined){
const _errs29 = errors;
if(!(validate519(data6.reconcile, {instancePath:instancePath+"/policy/reconcile",parentData:data6,parentDataProperty:"reconcile",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate519.errors : vErrors.concat(validate519.errors);
errors = vErrors.length;
}
var valid2 = _errs29 === errors;
}
else {
var valid2 = true;
}
if(valid2){
if(data6.cancel !== undefined){
const _errs30 = errors;
if(!(validate519(data6.cancel, {instancePath:instancePath+"/policy/cancel",parentData:data6,parentDataProperty:"cancel",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate519.errors : vErrors.concat(validate519.errors);
errors = vErrors.length;
}
var valid2 = _errs30 === errors;
}
else {
var valid2 = true;
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
const err11 = {instancePath:instancePath+"/policy",schemaPath:"#/properties/policy/anyOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err11];
}
else {
vErrors.push(err11);
}
errors++;
}
}
var _valid0 = _errs11 === errors;
valid1 = valid1 || _valid0;
const _errs31 = errors;
if(data6 !== null){
const err12 = {instancePath:instancePath+"/policy",schemaPath:"#/properties/policy/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err12];
}
else {
vErrors.push(err12);
}
errors++;
}
var _valid0 = _errs31 === errors;
valid1 = valid1 || _valid0;
if(!valid1){
const err13 = {instancePath:instancePath+"/policy",schemaPath:"#/properties/policy/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err13];
}
else {
vErrors.push(err13);
}
errors++;
validate500.errors = vErrors;
return false;
}
else {
errors = _errs10;
if(vErrors !== null){
if(_errs10){
vErrors.length = _errs10;
}
else {
vErrors = null;
}
}
}
var valid0 = _errs9 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.terminal !== undefined){
let data19 = data.terminal;
const _errs33 = errors;
const _errs34 = errors;
let valid3 = false;
const _errs35 = errors;
if(errors === _errs35){
if(data19 && typeof data19 == "object" && !Array.isArray(data19)){
let missing2;
if((((data19.timing === undefined) && (missing2 = "timing")) || ((data19.omission === undefined) && (missing2 = "omission"))) || ((data19.completion === undefined) && (missing2 = "completion"))){
const err14 = {instancePath:instancePath+"/terminal",schemaPath:"#/properties/terminal/anyOf/0/required",keyword:"required",params:{missingProperty: missing2},message:"must have required property '"+missing2+"'"};
if(vErrors === null){
vErrors = [err14];
}
else {
vErrors.push(err14);
}
errors++;
}
else {
const _errs37 = errors;
for(const key2 in data19){
if(!(((key2 === "timing") || (key2 === "omission")) || (key2 === "completion"))){
const err15 = {instancePath:instancePath+"/terminal",schemaPath:"#/properties/terminal/anyOf/0/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key2},message:"must NOT have additional properties"};
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
if(_errs37 === errors){
if(data19.timing !== undefined){
let data20 = data19.timing;
const _errs38 = errors;
if(errors === _errs38){
if(data20 && typeof data20 == "object" && !Array.isArray(data20)){
let missing3;
if((((data20.member === undefined) && (missing3 = "member")) || ((data20.started_ms === undefined) && (missing3 = "started_ms"))) || ((data20.elapsed_ns === undefined) && (missing3 = "elapsed_ns"))){
const err16 = {instancePath:instancePath+"/terminal/timing",schemaPath:"#/properties/terminal/anyOf/0/properties/timing/required",keyword:"required",params:{missingProperty: missing3},message:"must have required property '"+missing3+"'"};
if(vErrors === null){
vErrors = [err16];
}
else {
vErrors.push(err16);
}
errors++;
}
else {
const _errs40 = errors;
for(const key3 in data20){
if(!(((key3 === "member") || (key3 === "started_ms")) || (key3 === "elapsed_ns"))){
const err17 = {instancePath:instancePath+"/terminal/timing",schemaPath:"#/properties/terminal/anyOf/0/properties/timing/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key3},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err17];
}
else {
vErrors.push(err17);
}
errors++;
break;
}
}
if(_errs40 === errors){
if(data20.member !== undefined){
const _errs41 = errors;
if(!(validate508(data20.member, {instancePath:instancePath+"/terminal/timing/member",parentData:data20,parentDataProperty:"member",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate508.errors : vErrors.concat(validate508.errors);
errors = vErrors.length;
}
var valid5 = _errs41 === errors;
}
else {
var valid5 = true;
}
if(valid5){
if(data20.started_ms !== undefined){
let data22 = data20.started_ms;
const _errs42 = errors;
if(errors === _errs42){
if(typeof data22 === "string"){
if(func4(data22) > 256){
const err18 = {instancePath:instancePath+"/terminal/timing/started_ms",schemaPath:"#/properties/terminal/anyOf/0/properties/timing/properties/started_ms/maxLength",keyword:"maxLength",params:{limit: 256},message:"must NOT have more than 256 characters"};
if(vErrors === null){
vErrors = [err18];
}
else {
vErrors.push(err18);
}
errors++;
}
}
else {
const err19 = {instancePath:instancePath+"/terminal/timing/started_ms",schemaPath:"#/properties/terminal/anyOf/0/properties/timing/properties/started_ms/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err19];
}
else {
vErrors.push(err19);
}
errors++;
}
}
var valid5 = _errs42 === errors;
}
else {
var valid5 = true;
}
if(valid5){
if(data20.elapsed_ns !== undefined){
let data23 = data20.elapsed_ns;
const _errs44 = errors;
if(errors === _errs44){
if(typeof data23 === "string"){
if(func4(data23) > 256){
const err20 = {instancePath:instancePath+"/terminal/timing/elapsed_ns",schemaPath:"#/properties/terminal/anyOf/0/properties/timing/properties/elapsed_ns/maxLength",keyword:"maxLength",params:{limit: 256},message:"must NOT have more than 256 characters"};
if(vErrors === null){
vErrors = [err20];
}
else {
vErrors.push(err20);
}
errors++;
}
}
else {
const err21 = {instancePath:instancePath+"/terminal/timing/elapsed_ns",schemaPath:"#/properties/terminal/anyOf/0/properties/timing/properties/elapsed_ns/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err21];
}
else {
vErrors.push(err21);
}
errors++;
}
}
var valid5 = _errs44 === errors;
}
else {
var valid5 = true;
}
}
}
}
}
}
else {
const err22 = {instancePath:instancePath+"/terminal/timing",schemaPath:"#/properties/terminal/anyOf/0/properties/timing/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err22];
}
else {
vErrors.push(err22);
}
errors++;
}
}
var valid4 = _errs38 === errors;
}
else {
var valid4 = true;
}
if(valid4){
if(data19.omission !== undefined){
let data24 = data19.omission;
const _errs46 = errors;
if(errors === _errs46){
if(data24 && typeof data24 == "object" && !Array.isArray(data24)){
let missing4;
if((((data24.member === undefined) && (missing4 = "member")) || ((data24.response_headers === undefined) && (missing4 = "response_headers"))) || ((data24.request_secrets === undefined) && (missing4 = "request_secrets"))){
const err23 = {instancePath:instancePath+"/terminal/omission",schemaPath:"#/properties/terminal/anyOf/0/properties/omission/required",keyword:"required",params:{missingProperty: missing4},message:"must have required property '"+missing4+"'"};
if(vErrors === null){
vErrors = [err23];
}
else {
vErrors.push(err23);
}
errors++;
}
else {
const _errs48 = errors;
for(const key4 in data24){
if(!(((key4 === "member") || (key4 === "response_headers")) || (key4 === "request_secrets"))){
const err24 = {instancePath:instancePath+"/terminal/omission",schemaPath:"#/properties/terminal/anyOf/0/properties/omission/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key4},message:"must NOT have additional properties"};
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
if(_errs48 === errors){
if(data24.member !== undefined){
const _errs49 = errors;
if(!(validate508(data24.member, {instancePath:instancePath+"/terminal/omission/member",parentData:data24,parentDataProperty:"member",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate508.errors : vErrors.concat(validate508.errors);
errors = vErrors.length;
}
var valid6 = _errs49 === errors;
}
else {
var valid6 = true;
}
if(valid6){
if(data24.response_headers !== undefined){
const _errs50 = errors;
if(!(validate53(data24.response_headers, {instancePath:instancePath+"/terminal/omission/response_headers",parentData:data24,parentDataProperty:"response_headers",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate53.errors : vErrors.concat(validate53.errors);
errors = vErrors.length;
}
var valid6 = _errs50 === errors;
}
else {
var valid6 = true;
}
if(valid6){
if(data24.request_secrets !== undefined){
const _errs51 = errors;
if(!(validate53(data24.request_secrets, {instancePath:instancePath+"/terminal/omission/request_secrets",parentData:data24,parentDataProperty:"request_secrets",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate53.errors : vErrors.concat(validate53.errors);
errors = vErrors.length;
}
var valid6 = _errs51 === errors;
}
else {
var valid6 = true;
}
}
}
}
}
}
else {
const err25 = {instancePath:instancePath+"/terminal/omission",schemaPath:"#/properties/terminal/anyOf/0/properties/omission/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err25];
}
else {
vErrors.push(err25);
}
errors++;
}
}
var valid4 = _errs46 === errors;
}
else {
var valid4 = true;
}
if(valid4){
if(data19.completion !== undefined){
let data28 = data19.completion;
const _errs52 = errors;
if(errors === _errs52){
if(data28 && typeof data28 == "object" && !Array.isArray(data28)){
let missing5;
if(((((((data28.member === undefined) && (missing5 = "member")) || ((data28.status === undefined) && (missing5 = "status"))) || ((data28.request_bytes === undefined) && (missing5 = "request_bytes"))) || ((data28.response_bytes === undefined) && (missing5 = "response_bytes"))) || ((data28.heads === undefined) && (missing5 = "heads"))) || ((data28.framing === undefined) && (missing5 = "framing"))){
const err26 = {instancePath:instancePath+"/terminal/completion",schemaPath:"#/properties/terminal/anyOf/0/properties/completion/required",keyword:"required",params:{missingProperty: missing5},message:"must have required property '"+missing5+"'"};
if(vErrors === null){
vErrors = [err26];
}
else {
vErrors.push(err26);
}
errors++;
}
else {
const _errs54 = errors;
for(const key5 in data28){
if(!((((((key5 === "member") || (key5 === "status")) || (key5 === "request_bytes")) || (key5 === "response_bytes")) || (key5 === "heads")) || (key5 === "framing"))){
const err27 = {instancePath:instancePath+"/terminal/completion",schemaPath:"#/properties/terminal/anyOf/0/properties/completion/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key5},message:"must NOT have additional properties"};
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
if(_errs54 === errors){
if(data28.member !== undefined){
const _errs55 = errors;
if(!(validate508(data28.member, {instancePath:instancePath+"/terminal/completion/member",parentData:data28,parentDataProperty:"member",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate508.errors : vErrors.concat(validate508.errors);
errors = vErrors.length;
}
var valid7 = _errs55 === errors;
}
else {
var valid7 = true;
}
if(valid7){
if(data28.status !== undefined){
const _errs56 = errors;
if(!(validate67(data28.status, {instancePath:instancePath+"/terminal/completion/status",parentData:data28,parentDataProperty:"status",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate67.errors : vErrors.concat(validate67.errors);
errors = vErrors.length;
}
var valid7 = _errs56 === errors;
}
else {
var valid7 = true;
}
if(valid7){
if(data28.request_bytes !== undefined){
let data31 = data28.request_bytes;
const _errs57 = errors;
if(errors === _errs57){
if(typeof data31 === "string"){
if(func4(data31) > 256){
const err28 = {instancePath:instancePath+"/terminal/completion/request_bytes",schemaPath:"#/properties/terminal/anyOf/0/properties/completion/properties/request_bytes/maxLength",keyword:"maxLength",params:{limit: 256},message:"must NOT have more than 256 characters"};
if(vErrors === null){
vErrors = [err28];
}
else {
vErrors.push(err28);
}
errors++;
}
}
else {
const err29 = {instancePath:instancePath+"/terminal/completion/request_bytes",schemaPath:"#/properties/terminal/anyOf/0/properties/completion/properties/request_bytes/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err29];
}
else {
vErrors.push(err29);
}
errors++;
}
}
var valid7 = _errs57 === errors;
}
else {
var valid7 = true;
}
if(valid7){
if(data28.response_bytes !== undefined){
let data32 = data28.response_bytes;
const _errs59 = errors;
if(errors === _errs59){
if(typeof data32 === "string"){
if(func4(data32) > 256){
const err30 = {instancePath:instancePath+"/terminal/completion/response_bytes",schemaPath:"#/properties/terminal/anyOf/0/properties/completion/properties/response_bytes/maxLength",keyword:"maxLength",params:{limit: 256},message:"must NOT have more than 256 characters"};
if(vErrors === null){
vErrors = [err30];
}
else {
vErrors.push(err30);
}
errors++;
}
}
else {
const err31 = {instancePath:instancePath+"/terminal/completion/response_bytes",schemaPath:"#/properties/terminal/anyOf/0/properties/completion/properties/response_bytes/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err31];
}
else {
vErrors.push(err31);
}
errors++;
}
}
var valid7 = _errs59 === errors;
}
else {
var valid7 = true;
}
if(valid7){
if(data28.heads !== undefined){
const _errs61 = errors;
if(!(validate102(data28.heads, {instancePath:instancePath+"/terminal/completion/heads",parentData:data28,parentDataProperty:"heads",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate102.errors : vErrors.concat(validate102.errors);
errors = vErrors.length;
}
var valid7 = _errs61 === errors;
}
else {
var valid7 = true;
}
if(valid7){
if(data28.framing !== undefined){
let data34 = data28.framing;
const _errs62 = errors;
if(typeof data34 !== "string"){
const err32 = {instancePath:instancePath+"/terminal/completion/framing",schemaPath:"#/properties/terminal/anyOf/0/properties/completion/properties/framing/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err32];
}
else {
vErrors.push(err32);
}
errors++;
}
if(!((((data34 === "none") || (data34 === "length")) || (data34 === "chunked")) || (data34 === "close"))){
const err33 = {instancePath:instancePath+"/terminal/completion/framing",schemaPath:"#/properties/terminal/anyOf/0/properties/completion/properties/framing/enum",keyword:"enum",params:{allowedValues: schema116.properties.terminal.anyOf[0].properties.completion.properties.framing.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err33];
}
else {
vErrors.push(err33);
}
errors++;
}
var valid7 = _errs62 === errors;
}
else {
var valid7 = true;
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
const err34 = {instancePath:instancePath+"/terminal/completion",schemaPath:"#/properties/terminal/anyOf/0/properties/completion/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err34];
}
else {
vErrors.push(err34);
}
errors++;
}
}
var valid4 = _errs52 === errors;
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
const err35 = {instancePath:instancePath+"/terminal",schemaPath:"#/properties/terminal/anyOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err35];
}
else {
vErrors.push(err35);
}
errors++;
}
}
var _valid1 = _errs35 === errors;
valid3 = valid3 || _valid1;
const _errs64 = errors;
if(data19 !== null){
const err36 = {instancePath:instancePath+"/terminal",schemaPath:"#/properties/terminal/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err36];
}
else {
vErrors.push(err36);
}
errors++;
}
var _valid1 = _errs64 === errors;
valid3 = valid3 || _valid1;
if(!valid3){
const err37 = {instancePath:instancePath+"/terminal",schemaPath:"#/properties/terminal/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err37];
}
else {
vErrors.push(err37);
}
errors++;
validate500.errors = vErrors;
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
var valid0 = _errs33 === errors;
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
validate500.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate500.errors = vErrors;
return errors === 0;
}
validate500.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

export const GrpcResponse = validate533;
const schema122 = {"type":"object","additionalProperties":false,"properties":{"version":{"$ref":"https://transit.invalid/generated-validator/9"},"source":{"$ref":"https://transit.invalid/generated-validator/72"},"exchange":{"type":"string","maxLength":256},"phase":{"$ref":"https://transit.invalid/generated-validator/78"},"coverage":{"$ref":"https://transit.invalid/generated-validator/11"},"failure":{"$ref":"https://transit.invalid/generated-validator/90"},"policy":{"anyOf":[{"type":"object","additionalProperties":false,"properties":{"member":{"$ref":"https://transit.invalid/generated-validator/96"},"endpoint_revision":{"type":"string","maxLength":256},"tls":{"type":"boolean"},"trust_digest":{"$ref":"https://transit.invalid/generated-validator/15"},"timeout_ms":{"$ref":"https://transit.invalid/generated-validator/0"},"limits":{"type":"object","additionalProperties":false,"properties":{"message_bytes":{"$ref":"https://transit.invalid/generated-validator/0"},"request_bytes":{"$ref":"https://transit.invalid/generated-validator/0"},"response_bytes":{"$ref":"https://transit.invalid/generated-validator/0"},"request_messages":{"$ref":"https://transit.invalid/generated-validator/0"},"response_messages":{"$ref":"https://transit.invalid/generated-validator/0"},"metadata_bytes":{"$ref":"https://transit.invalid/generated-validator/0"}},"required":["message_bytes","request_bytes","response_bytes","request_messages","response_messages","metadata_bytes"]},"shape":{"type":"string","enum":["unary","server_streaming","client_streaming","bidi"]},"descriptor_digest":{"$ref":"https://transit.invalid/generated-validator/11"},"retry":{"$ref":"https://transit.invalid/generated-validator/94"}},"required":["member","endpoint_revision","tls","trust_digest","timeout_ms","limits","shape","descriptor_digest","retry"]},{"type":"null"}]},"half_close":{"anyOf":[{"type":"object","additionalProperties":false,"properties":{"member":{"$ref":"https://transit.invalid/generated-validator/96"},"messages":{"$ref":"https://transit.invalid/generated-validator/0"},"wire_bytes":{"$ref":"https://transit.invalid/generated-validator/0"}},"required":["member","messages","wire_bytes"]},{"type":"null"}]},"response_message_records":{"$ref":"https://transit.invalid/generated-validator/0"},"response_body_bytes":{"type":"string","maxLength":256},"terminal":{"anyOf":[{"type":"object","additionalProperties":false,"properties":{"timing":{"type":"object","additionalProperties":false,"properties":{"member":{"$ref":"https://transit.invalid/generated-validator/96"},"started_ms":{"type":"string","maxLength":256},"elapsed_ns":{"type":"string","maxLength":256}},"required":["member","started_ms","elapsed_ns"]},"omission":{"type":"object","additionalProperties":false,"properties":{"member":{"$ref":"https://transit.invalid/generated-validator/96"},"response_fields":{"$ref":"https://transit.invalid/generated-validator/0"},"request_secrets":{"$ref":"https://transit.invalid/generated-validator/0"}},"required":["member","response_fields","request_secrets"]},"completion":{"type":"object","additionalProperties":false,"properties":{"member":{"$ref":"https://transit.invalid/generated-validator/96"},"status":{"$ref":"https://transit.invalid/generated-validator/0"},"sent_messages":{"$ref":"https://transit.invalid/generated-validator/0"},"received_messages":{"$ref":"https://transit.invalid/generated-validator/0"},"sent_bytes":{"$ref":"https://transit.invalid/generated-validator/0"},"received_bytes":{"$ref":"https://transit.invalid/generated-validator/0"},"half_closed":{"type":"boolean"}},"required":["member","status","sent_messages","received_messages","sent_bytes","received_bytes","half_closed"]}},"required":["timing","omission","completion"]},{"type":"null"}]}},"required":["version","source","exchange","phase","coverage","failure","policy","half_close","response_message_records","response_body_bytes","terminal"]};
const schema123 = {"type":"object","additionalProperties":false,"properties":{"key":{"$ref":"https://transit.invalid/generated-validator/21"},"ordinal":{"$ref":"https://transit.invalid/generated-validator/0"},"kind":{"$ref":"https://transit.invalid/generated-validator/95"},"bytes":{"$ref":"https://transit.invalid/generated-validator/0"},"digest":{"$ref":"https://transit.invalid/generated-validator/11"},"chain":{"$ref":"https://transit.invalid/generated-validator/11"}},"required":["key","ordinal","kind","bytes","digest","chain"]};
const schema124 = {"type":"string","enum":["request_metadata","request_batch","endpoint_policy","initial_metadata","response_message","response_body","half_close","trailers","timing","omission","completion"]};

function validate542(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate542.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate542.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
if(!(((((((((((data === "request_metadata") || (data === "request_batch")) || (data === "endpoint_policy")) || (data === "initial_metadata")) || (data === "response_message")) || (data === "response_body")) || (data === "half_close")) || (data === "trailers")) || (data === "timing")) || (data === "omission")) || (data === "completion"))){
validate542.errors = [{instancePath,schemaPath:"#/enum",keyword:"enum",params:{allowedValues: schema124.enum},message:"must be equal to one of the allowed values"}];
return false;
}
validate542.errors = vErrors;
return errors === 0;
}
validate542.evaluated = {"dynamicProps":false,"dynamicItems":false};


function validate539(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate539.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if(((((((data.key === undefined) && (missing0 = "key")) || ((data.ordinal === undefined) && (missing0 = "ordinal"))) || ((data.kind === undefined) && (missing0 = "kind"))) || ((data.bytes === undefined) && (missing0 = "bytes"))) || ((data.digest === undefined) && (missing0 = "digest"))) || ((data.chain === undefined) && (missing0 = "chain"))){
validate539.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((((((key0 === "key") || (key0 === "ordinal")) || (key0 === "kind")) || (key0 === "bytes")) || (key0 === "digest")) || (key0 === "chain"))){
validate539.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.key !== undefined){
const _errs2 = errors;
if(!(validate134(data.key, {instancePath:instancePath+"/key",parentData:data,parentDataProperty:"key",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate134.errors : vErrors.concat(validate134.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.ordinal !== undefined){
const _errs3 = errors;
if(!(validate53(data.ordinal, {instancePath:instancePath+"/ordinal",parentData:data,parentDataProperty:"ordinal",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate53.errors : vErrors.concat(validate53.errors);
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
if(!(validate542(data.kind, {instancePath:instancePath+"/kind",parentData:data,parentDataProperty:"kind",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate542.errors : vErrors.concat(validate542.errors);
errors = vErrors.length;
}
var valid0 = _errs4 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.bytes !== undefined){
const _errs5 = errors;
if(!(validate53(data.bytes, {instancePath:instancePath+"/bytes",parentData:data,parentDataProperty:"bytes",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate53.errors : vErrors.concat(validate53.errors);
errors = vErrors.length;
}
var valid0 = _errs5 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.digest !== undefined){
const _errs6 = errors;
if(!(validate105(data.digest, {instancePath:instancePath+"/digest",parentData:data,parentDataProperty:"digest",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate105.errors : vErrors.concat(validate105.errors);
errors = vErrors.length;
}
var valid0 = _errs6 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.chain !== undefined){
const _errs7 = errors;
if(!(validate105(data.chain, {instancePath:instancePath+"/chain",parentData:data,parentDataProperty:"chain",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate105.errors : vErrors.concat(validate105.errors);
errors = vErrors.length;
}
var valid0 = _errs7 === errors;
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
else {
validate539.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate539.errors = vErrors;
return errors === 0;
}
validate539.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate533(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate533.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((((((((((((data.version === undefined) && (missing0 = "version")) || ((data.source === undefined) && (missing0 = "source"))) || ((data.exchange === undefined) && (missing0 = "exchange"))) || ((data.phase === undefined) && (missing0 = "phase"))) || ((data.coverage === undefined) && (missing0 = "coverage"))) || ((data.failure === undefined) && (missing0 = "failure"))) || ((data.policy === undefined) && (missing0 = "policy"))) || ((data.half_close === undefined) && (missing0 = "half_close"))) || ((data.response_message_records === undefined) && (missing0 = "response_message_records"))) || ((data.response_body_bytes === undefined) && (missing0 = "response_body_bytes"))) || ((data.terminal === undefined) && (missing0 = "terminal"))){
validate533.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(func1.call(schema122.properties, key0))){
validate533.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.version !== undefined){
const _errs2 = errors;
if(!(validate102(data.version, {instancePath:instancePath+"/version",parentData:data,parentDataProperty:"version",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate102.errors : vErrors.concat(validate102.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.source !== undefined){
const _errs3 = errors;
if(!(validate315(data.source, {instancePath:instancePath+"/source",parentData:data,parentDataProperty:"source",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate315.errors : vErrors.concat(validate315.errors);
errors = vErrors.length;
}
var valid0 = _errs3 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.exchange !== undefined){
let data2 = data.exchange;
const _errs4 = errors;
if(errors === _errs4){
if(typeof data2 === "string"){
if(func4(data2) > 256){
validate533.errors = [{instancePath:instancePath+"/exchange",schemaPath:"#/properties/exchange/maxLength",keyword:"maxLength",params:{limit: 256},message:"must NOT have more than 256 characters"}];
return false;
}
}
else {
validate533.errors = [{instancePath:instancePath+"/exchange",schemaPath:"#/properties/exchange/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
}
var valid0 = _errs4 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.phase !== undefined){
const _errs6 = errors;
if(!(validate417(data.phase, {instancePath:instancePath+"/phase",parentData:data,parentDataProperty:"phase",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate417.errors : vErrors.concat(validate417.errors);
errors = vErrors.length;
}
var valid0 = _errs6 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.coverage !== undefined){
const _errs7 = errors;
if(!(validate105(data.coverage, {instancePath:instancePath+"/coverage",parentData:data,parentDataProperty:"coverage",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate105.errors : vErrors.concat(validate105.errors);
errors = vErrors.length;
}
var valid0 = _errs7 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.failure !== undefined){
const _errs8 = errors;
if(!(validate505(data.failure, {instancePath:instancePath+"/failure",parentData:data,parentDataProperty:"failure",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate505.errors : vErrors.concat(validate505.errors);
errors = vErrors.length;
}
var valid0 = _errs8 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.policy !== undefined){
let data6 = data.policy;
const _errs9 = errors;
const _errs10 = errors;
let valid1 = false;
const _errs11 = errors;
if(errors === _errs11){
if(data6 && typeof data6 == "object" && !Array.isArray(data6)){
let missing1;
if((((((((((data6.member === undefined) && (missing1 = "member")) || ((data6.endpoint_revision === undefined) && (missing1 = "endpoint_revision"))) || ((data6.tls === undefined) && (missing1 = "tls"))) || ((data6.trust_digest === undefined) && (missing1 = "trust_digest"))) || ((data6.timeout_ms === undefined) && (missing1 = "timeout_ms"))) || ((data6.limits === undefined) && (missing1 = "limits"))) || ((data6.shape === undefined) && (missing1 = "shape"))) || ((data6.descriptor_digest === undefined) && (missing1 = "descriptor_digest"))) || ((data6.retry === undefined) && (missing1 = "retry"))){
const err0 = {instancePath:instancePath+"/policy",schemaPath:"#/properties/policy/anyOf/0/required",keyword:"required",params:{missingProperty: missing1},message:"must have required property '"+missing1+"'"};
if(vErrors === null){
vErrors = [err0];
}
else {
vErrors.push(err0);
}
errors++;
}
else {
const _errs13 = errors;
for(const key1 in data6){
if(!(func1.call(schema122.properties.policy.anyOf[0].properties, key1))){
const err1 = {instancePath:instancePath+"/policy",schemaPath:"#/properties/policy/anyOf/0/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key1},message:"must NOT have additional properties"};
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
if(_errs13 === errors){
if(data6.member !== undefined){
const _errs14 = errors;
if(!(validate539(data6.member, {instancePath:instancePath+"/policy/member",parentData:data6,parentDataProperty:"member",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate539.errors : vErrors.concat(validate539.errors);
errors = vErrors.length;
}
var valid2 = _errs14 === errors;
}
else {
var valid2 = true;
}
if(valid2){
if(data6.endpoint_revision !== undefined){
let data8 = data6.endpoint_revision;
const _errs15 = errors;
if(errors === _errs15){
if(typeof data8 === "string"){
if(func4(data8) > 256){
const err2 = {instancePath:instancePath+"/policy/endpoint_revision",schemaPath:"#/properties/policy/anyOf/0/properties/endpoint_revision/maxLength",keyword:"maxLength",params:{limit: 256},message:"must NOT have more than 256 characters"};
if(vErrors === null){
vErrors = [err2];
}
else {
vErrors.push(err2);
}
errors++;
}
}
else {
const err3 = {instancePath:instancePath+"/policy/endpoint_revision",schemaPath:"#/properties/policy/anyOf/0/properties/endpoint_revision/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err3];
}
else {
vErrors.push(err3);
}
errors++;
}
}
var valid2 = _errs15 === errors;
}
else {
var valid2 = true;
}
if(valid2){
if(data6.tls !== undefined){
const _errs17 = errors;
if(typeof data6.tls !== "boolean"){
const err4 = {instancePath:instancePath+"/policy/tls",schemaPath:"#/properties/policy/anyOf/0/properties/tls/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"};
if(vErrors === null){
vErrors = [err4];
}
else {
vErrors.push(err4);
}
errors++;
}
var valid2 = _errs17 === errors;
}
else {
var valid2 = true;
}
if(valid2){
if(data6.trust_digest !== undefined){
const _errs19 = errors;
if(!(validate116(data6.trust_digest, {instancePath:instancePath+"/policy/trust_digest",parentData:data6,parentDataProperty:"trust_digest",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate116.errors : vErrors.concat(validate116.errors);
errors = vErrors.length;
}
var valid2 = _errs19 === errors;
}
else {
var valid2 = true;
}
if(valid2){
if(data6.timeout_ms !== undefined){
const _errs20 = errors;
if(!(validate53(data6.timeout_ms, {instancePath:instancePath+"/policy/timeout_ms",parentData:data6,parentDataProperty:"timeout_ms",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate53.errors : vErrors.concat(validate53.errors);
errors = vErrors.length;
}
var valid2 = _errs20 === errors;
}
else {
var valid2 = true;
}
if(valid2){
if(data6.limits !== undefined){
let data12 = data6.limits;
const _errs21 = errors;
if(errors === _errs21){
if(data12 && typeof data12 == "object" && !Array.isArray(data12)){
let missing2;
if(((((((data12.message_bytes === undefined) && (missing2 = "message_bytes")) || ((data12.request_bytes === undefined) && (missing2 = "request_bytes"))) || ((data12.response_bytes === undefined) && (missing2 = "response_bytes"))) || ((data12.request_messages === undefined) && (missing2 = "request_messages"))) || ((data12.response_messages === undefined) && (missing2 = "response_messages"))) || ((data12.metadata_bytes === undefined) && (missing2 = "metadata_bytes"))){
const err5 = {instancePath:instancePath+"/policy/limits",schemaPath:"#/properties/policy/anyOf/0/properties/limits/required",keyword:"required",params:{missingProperty: missing2},message:"must have required property '"+missing2+"'"};
if(vErrors === null){
vErrors = [err5];
}
else {
vErrors.push(err5);
}
errors++;
}
else {
const _errs23 = errors;
for(const key2 in data12){
if(!((((((key2 === "message_bytes") || (key2 === "request_bytes")) || (key2 === "response_bytes")) || (key2 === "request_messages")) || (key2 === "response_messages")) || (key2 === "metadata_bytes"))){
const err6 = {instancePath:instancePath+"/policy/limits",schemaPath:"#/properties/policy/anyOf/0/properties/limits/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key2},message:"must NOT have additional properties"};
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
if(_errs23 === errors){
if(data12.message_bytes !== undefined){
const _errs24 = errors;
if(!(validate53(data12.message_bytes, {instancePath:instancePath+"/policy/limits/message_bytes",parentData:data12,parentDataProperty:"message_bytes",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate53.errors : vErrors.concat(validate53.errors);
errors = vErrors.length;
}
var valid3 = _errs24 === errors;
}
else {
var valid3 = true;
}
if(valid3){
if(data12.request_bytes !== undefined){
const _errs25 = errors;
if(!(validate53(data12.request_bytes, {instancePath:instancePath+"/policy/limits/request_bytes",parentData:data12,parentDataProperty:"request_bytes",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate53.errors : vErrors.concat(validate53.errors);
errors = vErrors.length;
}
var valid3 = _errs25 === errors;
}
else {
var valid3 = true;
}
if(valid3){
if(data12.response_bytes !== undefined){
const _errs26 = errors;
if(!(validate53(data12.response_bytes, {instancePath:instancePath+"/policy/limits/response_bytes",parentData:data12,parentDataProperty:"response_bytes",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate53.errors : vErrors.concat(validate53.errors);
errors = vErrors.length;
}
var valid3 = _errs26 === errors;
}
else {
var valid3 = true;
}
if(valid3){
if(data12.request_messages !== undefined){
const _errs27 = errors;
if(!(validate53(data12.request_messages, {instancePath:instancePath+"/policy/limits/request_messages",parentData:data12,parentDataProperty:"request_messages",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate53.errors : vErrors.concat(validate53.errors);
errors = vErrors.length;
}
var valid3 = _errs27 === errors;
}
else {
var valid3 = true;
}
if(valid3){
if(data12.response_messages !== undefined){
const _errs28 = errors;
if(!(validate53(data12.response_messages, {instancePath:instancePath+"/policy/limits/response_messages",parentData:data12,parentDataProperty:"response_messages",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate53.errors : vErrors.concat(validate53.errors);
errors = vErrors.length;
}
var valid3 = _errs28 === errors;
}
else {
var valid3 = true;
}
if(valid3){
if(data12.metadata_bytes !== undefined){
const _errs29 = errors;
if(!(validate53(data12.metadata_bytes, {instancePath:instancePath+"/policy/limits/metadata_bytes",parentData:data12,parentDataProperty:"metadata_bytes",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate53.errors : vErrors.concat(validate53.errors);
errors = vErrors.length;
}
var valid3 = _errs29 === errors;
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
}
else {
const err7 = {instancePath:instancePath+"/policy/limits",schemaPath:"#/properties/policy/anyOf/0/properties/limits/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err7];
}
else {
vErrors.push(err7);
}
errors++;
}
}
var valid2 = _errs21 === errors;
}
else {
var valid2 = true;
}
if(valid2){
if(data6.shape !== undefined){
let data19 = data6.shape;
const _errs30 = errors;
if(typeof data19 !== "string"){
const err8 = {instancePath:instancePath+"/policy/shape",schemaPath:"#/properties/policy/anyOf/0/properties/shape/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err8];
}
else {
vErrors.push(err8);
}
errors++;
}
if(!((((data19 === "unary") || (data19 === "server_streaming")) || (data19 === "client_streaming")) || (data19 === "bidi"))){
const err9 = {instancePath:instancePath+"/policy/shape",schemaPath:"#/properties/policy/anyOf/0/properties/shape/enum",keyword:"enum",params:{allowedValues: schema122.properties.policy.anyOf[0].properties.shape.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err9];
}
else {
vErrors.push(err9);
}
errors++;
}
var valid2 = _errs30 === errors;
}
else {
var valid2 = true;
}
if(valid2){
if(data6.descriptor_digest !== undefined){
const _errs32 = errors;
if(!(validate105(data6.descriptor_digest, {instancePath:instancePath+"/policy/descriptor_digest",parentData:data6,parentDataProperty:"descriptor_digest",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate105.errors : vErrors.concat(validate105.errors);
errors = vErrors.length;
}
var valid2 = _errs32 === errors;
}
else {
var valid2 = true;
}
if(valid2){
if(data6.retry !== undefined){
const _errs33 = errors;
if(!(validate519(data6.retry, {instancePath:instancePath+"/policy/retry",parentData:data6,parentDataProperty:"retry",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate519.errors : vErrors.concat(validate519.errors);
errors = vErrors.length;
}
var valid2 = _errs33 === errors;
}
else {
var valid2 = true;
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
const err10 = {instancePath:instancePath+"/policy",schemaPath:"#/properties/policy/anyOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err10];
}
else {
vErrors.push(err10);
}
errors++;
}
}
var _valid0 = _errs11 === errors;
valid1 = valid1 || _valid0;
const _errs34 = errors;
if(data6 !== null){
const err11 = {instancePath:instancePath+"/policy",schemaPath:"#/properties/policy/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err11];
}
else {
vErrors.push(err11);
}
errors++;
}
var _valid0 = _errs34 === errors;
valid1 = valid1 || _valid0;
if(!valid1){
const err12 = {instancePath:instancePath+"/policy",schemaPath:"#/properties/policy/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err12];
}
else {
vErrors.push(err12);
}
errors++;
validate533.errors = vErrors;
return false;
}
else {
errors = _errs10;
if(vErrors !== null){
if(_errs10){
vErrors.length = _errs10;
}
else {
vErrors = null;
}
}
}
var valid0 = _errs9 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.half_close !== undefined){
let data22 = data.half_close;
const _errs36 = errors;
const _errs37 = errors;
let valid4 = false;
const _errs38 = errors;
if(errors === _errs38){
if(data22 && typeof data22 == "object" && !Array.isArray(data22)){
let missing3;
if((((data22.member === undefined) && (missing3 = "member")) || ((data22.messages === undefined) && (missing3 = "messages"))) || ((data22.wire_bytes === undefined) && (missing3 = "wire_bytes"))){
const err13 = {instancePath:instancePath+"/half_close",schemaPath:"#/properties/half_close/anyOf/0/required",keyword:"required",params:{missingProperty: missing3},message:"must have required property '"+missing3+"'"};
if(vErrors === null){
vErrors = [err13];
}
else {
vErrors.push(err13);
}
errors++;
}
else {
const _errs40 = errors;
for(const key3 in data22){
if(!(((key3 === "member") || (key3 === "messages")) || (key3 === "wire_bytes"))){
const err14 = {instancePath:instancePath+"/half_close",schemaPath:"#/properties/half_close/anyOf/0/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key3},message:"must NOT have additional properties"};
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
if(_errs40 === errors){
if(data22.member !== undefined){
const _errs41 = errors;
if(!(validate539(data22.member, {instancePath:instancePath+"/half_close/member",parentData:data22,parentDataProperty:"member",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate539.errors : vErrors.concat(validate539.errors);
errors = vErrors.length;
}
var valid5 = _errs41 === errors;
}
else {
var valid5 = true;
}
if(valid5){
if(data22.messages !== undefined){
const _errs42 = errors;
if(!(validate53(data22.messages, {instancePath:instancePath+"/half_close/messages",parentData:data22,parentDataProperty:"messages",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate53.errors : vErrors.concat(validate53.errors);
errors = vErrors.length;
}
var valid5 = _errs42 === errors;
}
else {
var valid5 = true;
}
if(valid5){
if(data22.wire_bytes !== undefined){
const _errs43 = errors;
if(!(validate53(data22.wire_bytes, {instancePath:instancePath+"/half_close/wire_bytes",parentData:data22,parentDataProperty:"wire_bytes",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate53.errors : vErrors.concat(validate53.errors);
errors = vErrors.length;
}
var valid5 = _errs43 === errors;
}
else {
var valid5 = true;
}
}
}
}
}
}
else {
const err15 = {instancePath:instancePath+"/half_close",schemaPath:"#/properties/half_close/anyOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err15];
}
else {
vErrors.push(err15);
}
errors++;
}
}
var _valid1 = _errs38 === errors;
valid4 = valid4 || _valid1;
const _errs44 = errors;
if(data22 !== null){
const err16 = {instancePath:instancePath+"/half_close",schemaPath:"#/properties/half_close/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err16];
}
else {
vErrors.push(err16);
}
errors++;
}
var _valid1 = _errs44 === errors;
valid4 = valid4 || _valid1;
if(!valid4){
const err17 = {instancePath:instancePath+"/half_close",schemaPath:"#/properties/half_close/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err17];
}
else {
vErrors.push(err17);
}
errors++;
validate533.errors = vErrors;
return false;
}
else {
errors = _errs37;
if(vErrors !== null){
if(_errs37){
vErrors.length = _errs37;
}
else {
vErrors = null;
}
}
}
var valid0 = _errs36 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.response_message_records !== undefined){
const _errs46 = errors;
if(!(validate53(data.response_message_records, {instancePath:instancePath+"/response_message_records",parentData:data,parentDataProperty:"response_message_records",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate53.errors : vErrors.concat(validate53.errors);
errors = vErrors.length;
}
var valid0 = _errs46 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.response_body_bytes !== undefined){
let data27 = data.response_body_bytes;
const _errs47 = errors;
if(errors === _errs47){
if(typeof data27 === "string"){
if(func4(data27) > 256){
validate533.errors = [{instancePath:instancePath+"/response_body_bytes",schemaPath:"#/properties/response_body_bytes/maxLength",keyword:"maxLength",params:{limit: 256},message:"must NOT have more than 256 characters"}];
return false;
}
}
else {
validate533.errors = [{instancePath:instancePath+"/response_body_bytes",schemaPath:"#/properties/response_body_bytes/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
}
var valid0 = _errs47 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.terminal !== undefined){
let data28 = data.terminal;
const _errs49 = errors;
const _errs50 = errors;
let valid6 = false;
const _errs51 = errors;
if(errors === _errs51){
if(data28 && typeof data28 == "object" && !Array.isArray(data28)){
let missing4;
if((((data28.timing === undefined) && (missing4 = "timing")) || ((data28.omission === undefined) && (missing4 = "omission"))) || ((data28.completion === undefined) && (missing4 = "completion"))){
const err18 = {instancePath:instancePath+"/terminal",schemaPath:"#/properties/terminal/anyOf/0/required",keyword:"required",params:{missingProperty: missing4},message:"must have required property '"+missing4+"'"};
if(vErrors === null){
vErrors = [err18];
}
else {
vErrors.push(err18);
}
errors++;
}
else {
const _errs53 = errors;
for(const key4 in data28){
if(!(((key4 === "timing") || (key4 === "omission")) || (key4 === "completion"))){
const err19 = {instancePath:instancePath+"/terminal",schemaPath:"#/properties/terminal/anyOf/0/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key4},message:"must NOT have additional properties"};
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
if(_errs53 === errors){
if(data28.timing !== undefined){
let data29 = data28.timing;
const _errs54 = errors;
if(errors === _errs54){
if(data29 && typeof data29 == "object" && !Array.isArray(data29)){
let missing5;
if((((data29.member === undefined) && (missing5 = "member")) || ((data29.started_ms === undefined) && (missing5 = "started_ms"))) || ((data29.elapsed_ns === undefined) && (missing5 = "elapsed_ns"))){
const err20 = {instancePath:instancePath+"/terminal/timing",schemaPath:"#/properties/terminal/anyOf/0/properties/timing/required",keyword:"required",params:{missingProperty: missing5},message:"must have required property '"+missing5+"'"};
if(vErrors === null){
vErrors = [err20];
}
else {
vErrors.push(err20);
}
errors++;
}
else {
const _errs56 = errors;
for(const key5 in data29){
if(!(((key5 === "member") || (key5 === "started_ms")) || (key5 === "elapsed_ns"))){
const err21 = {instancePath:instancePath+"/terminal/timing",schemaPath:"#/properties/terminal/anyOf/0/properties/timing/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key5},message:"must NOT have additional properties"};
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
if(_errs56 === errors){
if(data29.member !== undefined){
const _errs57 = errors;
if(!(validate539(data29.member, {instancePath:instancePath+"/terminal/timing/member",parentData:data29,parentDataProperty:"member",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate539.errors : vErrors.concat(validate539.errors);
errors = vErrors.length;
}
var valid8 = _errs57 === errors;
}
else {
var valid8 = true;
}
if(valid8){
if(data29.started_ms !== undefined){
let data31 = data29.started_ms;
const _errs58 = errors;
if(errors === _errs58){
if(typeof data31 === "string"){
if(func4(data31) > 256){
const err22 = {instancePath:instancePath+"/terminal/timing/started_ms",schemaPath:"#/properties/terminal/anyOf/0/properties/timing/properties/started_ms/maxLength",keyword:"maxLength",params:{limit: 256},message:"must NOT have more than 256 characters"};
if(vErrors === null){
vErrors = [err22];
}
else {
vErrors.push(err22);
}
errors++;
}
}
else {
const err23 = {instancePath:instancePath+"/terminal/timing/started_ms",schemaPath:"#/properties/terminal/anyOf/0/properties/timing/properties/started_ms/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err23];
}
else {
vErrors.push(err23);
}
errors++;
}
}
var valid8 = _errs58 === errors;
}
else {
var valid8 = true;
}
if(valid8){
if(data29.elapsed_ns !== undefined){
let data32 = data29.elapsed_ns;
const _errs60 = errors;
if(errors === _errs60){
if(typeof data32 === "string"){
if(func4(data32) > 256){
const err24 = {instancePath:instancePath+"/terminal/timing/elapsed_ns",schemaPath:"#/properties/terminal/anyOf/0/properties/timing/properties/elapsed_ns/maxLength",keyword:"maxLength",params:{limit: 256},message:"must NOT have more than 256 characters"};
if(vErrors === null){
vErrors = [err24];
}
else {
vErrors.push(err24);
}
errors++;
}
}
else {
const err25 = {instancePath:instancePath+"/terminal/timing/elapsed_ns",schemaPath:"#/properties/terminal/anyOf/0/properties/timing/properties/elapsed_ns/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err25];
}
else {
vErrors.push(err25);
}
errors++;
}
}
var valid8 = _errs60 === errors;
}
else {
var valid8 = true;
}
}
}
}
}
}
else {
const err26 = {instancePath:instancePath+"/terminal/timing",schemaPath:"#/properties/terminal/anyOf/0/properties/timing/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err26];
}
else {
vErrors.push(err26);
}
errors++;
}
}
var valid7 = _errs54 === errors;
}
else {
var valid7 = true;
}
if(valid7){
if(data28.omission !== undefined){
let data33 = data28.omission;
const _errs62 = errors;
if(errors === _errs62){
if(data33 && typeof data33 == "object" && !Array.isArray(data33)){
let missing6;
if((((data33.member === undefined) && (missing6 = "member")) || ((data33.response_fields === undefined) && (missing6 = "response_fields"))) || ((data33.request_secrets === undefined) && (missing6 = "request_secrets"))){
const err27 = {instancePath:instancePath+"/terminal/omission",schemaPath:"#/properties/terminal/anyOf/0/properties/omission/required",keyword:"required",params:{missingProperty: missing6},message:"must have required property '"+missing6+"'"};
if(vErrors === null){
vErrors = [err27];
}
else {
vErrors.push(err27);
}
errors++;
}
else {
const _errs64 = errors;
for(const key6 in data33){
if(!(((key6 === "member") || (key6 === "response_fields")) || (key6 === "request_secrets"))){
const err28 = {instancePath:instancePath+"/terminal/omission",schemaPath:"#/properties/terminal/anyOf/0/properties/omission/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key6},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err28];
}
else {
vErrors.push(err28);
}
errors++;
break;
}
}
if(_errs64 === errors){
if(data33.member !== undefined){
const _errs65 = errors;
if(!(validate539(data33.member, {instancePath:instancePath+"/terminal/omission/member",parentData:data33,parentDataProperty:"member",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate539.errors : vErrors.concat(validate539.errors);
errors = vErrors.length;
}
var valid9 = _errs65 === errors;
}
else {
var valid9 = true;
}
if(valid9){
if(data33.response_fields !== undefined){
const _errs66 = errors;
if(!(validate53(data33.response_fields, {instancePath:instancePath+"/terminal/omission/response_fields",parentData:data33,parentDataProperty:"response_fields",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate53.errors : vErrors.concat(validate53.errors);
errors = vErrors.length;
}
var valid9 = _errs66 === errors;
}
else {
var valid9 = true;
}
if(valid9){
if(data33.request_secrets !== undefined){
const _errs67 = errors;
if(!(validate53(data33.request_secrets, {instancePath:instancePath+"/terminal/omission/request_secrets",parentData:data33,parentDataProperty:"request_secrets",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate53.errors : vErrors.concat(validate53.errors);
errors = vErrors.length;
}
var valid9 = _errs67 === errors;
}
else {
var valid9 = true;
}
}
}
}
}
}
else {
const err29 = {instancePath:instancePath+"/terminal/omission",schemaPath:"#/properties/terminal/anyOf/0/properties/omission/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err29];
}
else {
vErrors.push(err29);
}
errors++;
}
}
var valid7 = _errs62 === errors;
}
else {
var valid7 = true;
}
if(valid7){
if(data28.completion !== undefined){
let data37 = data28.completion;
const _errs68 = errors;
if(errors === _errs68){
if(data37 && typeof data37 == "object" && !Array.isArray(data37)){
let missing7;
if((((((((data37.member === undefined) && (missing7 = "member")) || ((data37.status === undefined) && (missing7 = "status"))) || ((data37.sent_messages === undefined) && (missing7 = "sent_messages"))) || ((data37.received_messages === undefined) && (missing7 = "received_messages"))) || ((data37.sent_bytes === undefined) && (missing7 = "sent_bytes"))) || ((data37.received_bytes === undefined) && (missing7 = "received_bytes"))) || ((data37.half_closed === undefined) && (missing7 = "half_closed"))){
const err30 = {instancePath:instancePath+"/terminal/completion",schemaPath:"#/properties/terminal/anyOf/0/properties/completion/required",keyword:"required",params:{missingProperty: missing7},message:"must have required property '"+missing7+"'"};
if(vErrors === null){
vErrors = [err30];
}
else {
vErrors.push(err30);
}
errors++;
}
else {
const _errs70 = errors;
for(const key7 in data37){
if(!(((((((key7 === "member") || (key7 === "status")) || (key7 === "sent_messages")) || (key7 === "received_messages")) || (key7 === "sent_bytes")) || (key7 === "received_bytes")) || (key7 === "half_closed"))){
const err31 = {instancePath:instancePath+"/terminal/completion",schemaPath:"#/properties/terminal/anyOf/0/properties/completion/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key7},message:"must NOT have additional properties"};
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
if(_errs70 === errors){
if(data37.member !== undefined){
const _errs71 = errors;
if(!(validate539(data37.member, {instancePath:instancePath+"/terminal/completion/member",parentData:data37,parentDataProperty:"member",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate539.errors : vErrors.concat(validate539.errors);
errors = vErrors.length;
}
var valid10 = _errs71 === errors;
}
else {
var valid10 = true;
}
if(valid10){
if(data37.status !== undefined){
const _errs72 = errors;
if(!(validate53(data37.status, {instancePath:instancePath+"/terminal/completion/status",parentData:data37,parentDataProperty:"status",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate53.errors : vErrors.concat(validate53.errors);
errors = vErrors.length;
}
var valid10 = _errs72 === errors;
}
else {
var valid10 = true;
}
if(valid10){
if(data37.sent_messages !== undefined){
const _errs73 = errors;
if(!(validate53(data37.sent_messages, {instancePath:instancePath+"/terminal/completion/sent_messages",parentData:data37,parentDataProperty:"sent_messages",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate53.errors : vErrors.concat(validate53.errors);
errors = vErrors.length;
}
var valid10 = _errs73 === errors;
}
else {
var valid10 = true;
}
if(valid10){
if(data37.received_messages !== undefined){
const _errs74 = errors;
if(!(validate53(data37.received_messages, {instancePath:instancePath+"/terminal/completion/received_messages",parentData:data37,parentDataProperty:"received_messages",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate53.errors : vErrors.concat(validate53.errors);
errors = vErrors.length;
}
var valid10 = _errs74 === errors;
}
else {
var valid10 = true;
}
if(valid10){
if(data37.sent_bytes !== undefined){
const _errs75 = errors;
if(!(validate53(data37.sent_bytes, {instancePath:instancePath+"/terminal/completion/sent_bytes",parentData:data37,parentDataProperty:"sent_bytes",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate53.errors : vErrors.concat(validate53.errors);
errors = vErrors.length;
}
var valid10 = _errs75 === errors;
}
else {
var valid10 = true;
}
if(valid10){
if(data37.received_bytes !== undefined){
const _errs76 = errors;
if(!(validate53(data37.received_bytes, {instancePath:instancePath+"/terminal/completion/received_bytes",parentData:data37,parentDataProperty:"received_bytes",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate53.errors : vErrors.concat(validate53.errors);
errors = vErrors.length;
}
var valid10 = _errs76 === errors;
}
else {
var valid10 = true;
}
if(valid10){
if(data37.half_closed !== undefined){
const _errs77 = errors;
if(typeof data37.half_closed !== "boolean"){
const err32 = {instancePath:instancePath+"/terminal/completion/half_closed",schemaPath:"#/properties/terminal/anyOf/0/properties/completion/properties/half_closed/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"};
if(vErrors === null){
vErrors = [err32];
}
else {
vErrors.push(err32);
}
errors++;
}
var valid10 = _errs77 === errors;
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
else {
const err33 = {instancePath:instancePath+"/terminal/completion",schemaPath:"#/properties/terminal/anyOf/0/properties/completion/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err33];
}
else {
vErrors.push(err33);
}
errors++;
}
}
var valid7 = _errs68 === errors;
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
const err34 = {instancePath:instancePath+"/terminal",schemaPath:"#/properties/terminal/anyOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err34];
}
else {
vErrors.push(err34);
}
errors++;
}
}
var _valid2 = _errs51 === errors;
valid6 = valid6 || _valid2;
const _errs79 = errors;
if(data28 !== null){
const err35 = {instancePath:instancePath+"/terminal",schemaPath:"#/properties/terminal/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err35];
}
else {
vErrors.push(err35);
}
errors++;
}
var _valid2 = _errs79 === errors;
valid6 = valid6 || _valid2;
if(!valid6){
const err36 = {instancePath:instancePath+"/terminal",schemaPath:"#/properties/terminal/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err36];
}
else {
vErrors.push(err36);
}
errors++;
validate533.errors = vErrors;
return false;
}
else {
errors = _errs50;
if(vErrors !== null){
if(_errs50){
vErrors.length = _errs50;
}
else {
vErrors = null;
}
}
}
var valid0 = _errs49 === errors;
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
validate533.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate533.errors = vErrors;
return errors === 0;
}
validate533.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

export const DocumentResponse = validate572;
const schema125 = {"type":"object","additionalProperties":false,"properties":{"version":{"$ref":"https://transit.invalid/generated-validator/9"},"source":{"$ref":"https://transit.invalid/generated-validator/72"},"declaration":{"$ref":"https://transit.invalid/generated-validator/80"},"registers":{"anyOf":[{"type":"object","additionalProperties":false,"properties":{"count":{"$ref":"https://transit.invalid/generated-validator/9"},"conflicts":{"$ref":"https://transit.invalid/generated-validator/9"},"assignments":{"$ref":"https://transit.invalid/generated-validator/9"},"next":{"$ref":"https://transit.invalid/generated-validator/77"}},"required":["count","conflicts","assignments","next"]},{"type":"null"}]}},"required":["version","source","declaration","registers"]};

function validate572(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate572.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if(((((data.version === undefined) && (missing0 = "version")) || ((data.source === undefined) && (missing0 = "source"))) || ((data.declaration === undefined) && (missing0 = "declaration"))) || ((data.registers === undefined) && (missing0 = "registers"))){
validate572.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((((key0 === "version") || (key0 === "source")) || (key0 === "declaration")) || (key0 === "registers"))){
validate572.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.version !== undefined){
const _errs2 = errors;
if(!(validate102(data.version, {instancePath:instancePath+"/version",parentData:data,parentDataProperty:"version",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate102.errors : vErrors.concat(validate102.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.source !== undefined){
const _errs3 = errors;
if(!(validate315(data.source, {instancePath:instancePath+"/source",parentData:data,parentDataProperty:"source",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate315.errors : vErrors.concat(validate315.errors);
errors = vErrors.length;
}
var valid0 = _errs3 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.declaration !== undefined){
const _errs4 = errors;
if(!(validate446(data.declaration, {instancePath:instancePath+"/declaration",parentData:data,parentDataProperty:"declaration",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate446.errors : vErrors.concat(validate446.errors);
errors = vErrors.length;
}
var valid0 = _errs4 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.registers !== undefined){
let data3 = data.registers;
const _errs5 = errors;
const _errs6 = errors;
let valid1 = false;
const _errs7 = errors;
if(errors === _errs7){
if(data3 && typeof data3 == "object" && !Array.isArray(data3)){
let missing1;
if(((((data3.count === undefined) && (missing1 = "count")) || ((data3.conflicts === undefined) && (missing1 = "conflicts"))) || ((data3.assignments === undefined) && (missing1 = "assignments"))) || ((data3.next === undefined) && (missing1 = "next"))){
const err0 = {instancePath:instancePath+"/registers",schemaPath:"#/properties/registers/anyOf/0/required",keyword:"required",params:{missingProperty: missing1},message:"must have required property '"+missing1+"'"};
if(vErrors === null){
vErrors = [err0];
}
else {
vErrors.push(err0);
}
errors++;
}
else {
const _errs9 = errors;
for(const key1 in data3){
if(!((((key1 === "count") || (key1 === "conflicts")) || (key1 === "assignments")) || (key1 === "next"))){
const err1 = {instancePath:instancePath+"/registers",schemaPath:"#/properties/registers/anyOf/0/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key1},message:"must NOT have additional properties"};
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
if(_errs9 === errors){
if(data3.count !== undefined){
const _errs10 = errors;
if(!(validate102(data3.count, {instancePath:instancePath+"/registers/count",parentData:data3,parentDataProperty:"count",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate102.errors : vErrors.concat(validate102.errors);
errors = vErrors.length;
}
var valid2 = _errs10 === errors;
}
else {
var valid2 = true;
}
if(valid2){
if(data3.conflicts !== undefined){
const _errs11 = errors;
if(!(validate102(data3.conflicts, {instancePath:instancePath+"/registers/conflicts",parentData:data3,parentDataProperty:"conflicts",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate102.errors : vErrors.concat(validate102.errors);
errors = vErrors.length;
}
var valid2 = _errs11 === errors;
}
else {
var valid2 = true;
}
if(valid2){
if(data3.assignments !== undefined){
const _errs12 = errors;
if(!(validate102(data3.assignments, {instancePath:instancePath+"/registers/assignments",parentData:data3,parentDataProperty:"assignments",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate102.errors : vErrors.concat(validate102.errors);
errors = vErrors.length;
}
var valid2 = _errs12 === errors;
}
else {
var valid2 = true;
}
if(valid2){
if(data3.next !== undefined){
const _errs13 = errors;
if(!(validate415(data3.next, {instancePath:instancePath+"/registers/next",parentData:data3,parentDataProperty:"next",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate415.errors : vErrors.concat(validate415.errors);
errors = vErrors.length;
}
var valid2 = _errs13 === errors;
}
else {
var valid2 = true;
}
}
}
}
}
}
}
else {
const err2 = {instancePath:instancePath+"/registers",schemaPath:"#/properties/registers/anyOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err2];
}
else {
vErrors.push(err2);
}
errors++;
}
}
var _valid0 = _errs7 === errors;
valid1 = valid1 || _valid0;
const _errs14 = errors;
if(data3 !== null){
const err3 = {instancePath:instancePath+"/registers",schemaPath:"#/properties/registers/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err3];
}
else {
vErrors.push(err3);
}
errors++;
}
var _valid0 = _errs14 === errors;
valid1 = valid1 || _valid0;
if(!valid1){
const err4 = {instancePath:instancePath+"/registers",schemaPath:"#/properties/registers/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err4];
}
else {
vErrors.push(err4);
}
errors++;
validate572.errors = vErrors;
return false;
}
else {
errors = _errs6;
if(vErrors !== null){
if(_errs6){
vErrors.length = _errs6;
}
else {
vErrors = null;
}
}
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
validate572.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate572.errors = vErrors;
return errors === 0;
}
validate572.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

export const UnifiedQueryRequest = validate580;
const schema126 = {"oneOf":[{"type":"object","additionalProperties":false,"required":["describe"],"properties":{"describe":{"type":"object","maxProperties":0}}},{"type":"object","additionalProperties":false,"required":["sql_capabilities"],"properties":{"sql_capabilities":{"type":"object","maxProperties":0}}},{"type":"object","additionalProperties":false,"required":["suggest"],"properties":{"suggest":{"type":"object","additionalProperties":false,"properties":{"search":{"type":"string","maxLength":131072}},"required":["search"]}}},{"type":"object","additionalProperties":false,"required":["assist"],"properties":{"assist":{"type":"object","additionalProperties":false,"properties":{"sql":{"type":"string","maxLength":131072},"cursor":{"$ref":"https://transit.invalid/generated-validator/4"},"generation":{"$ref":"https://transit.invalid/generated-validator/0"},"mode":{"type":"string","enum":["sql","console"]}},"required":["sql","cursor","generation"]}}},{"type":"object","additionalProperties":false,"required":["compile"],"properties":{"compile":{"type":"object","additionalProperties":false,"properties":{"sql":{"type":"string","maxLength":131072},"parameters":{"anyOf":[{"type":"array","maxItems":8,"items":{"$ref":"https://transit.invalid/generated-validator/102"}},{"type":"null"}]}},"required":["sql"]}}},{"type":"object","additionalProperties":false,"required":["inspect"],"properties":{"inspect":{"type":"object","additionalProperties":false,"properties":{"sql":{"type":"string","maxLength":131072}},"required":["sql"]}}},{"type":"object","additionalProperties":false,"required":["next"],"properties":{"next":{"type":"object","additionalProperties":false,"properties":{"namespace":{"type":"string","maxLength":131072},"bundle":{"type":"string","maxLength":131072}},"required":["namespace","bundle"]}}},{"type":"object","additionalProperties":false,"required":["next_draft"],"properties":{"next_draft":{"type":"object","additionalProperties":false,"properties":{"namespace":{"type":"string","maxLength":131072},"bundle":{"type":"string","maxLength":131072},"generation":{"type":"string","maxLength":131072}},"required":["namespace","bundle","generation"]}}},{"type":"object","additionalProperties":false,"required":["draft_open"],"properties":{"draft_open":{"type":"object","additionalProperties":false,"properties":{"expected":{"type":"string","maxLength":131072},"limit":{"$ref":"https://transit.invalid/generated-validator/9"}},"required":["expected","limit"]}}},{"type":"object","additionalProperties":false,"required":["draft_close"],"properties":{"draft_close":{"type":"string","maxLength":131072}}},{"type":"object","additionalProperties":false,"required":["draft_status"],"properties":{"draft_status":{"$ref":"https://transit.invalid/generated-validator/103"}}},{"type":"object","additionalProperties":false,"required":["submit"],"properties":{"submit":{"$ref":"https://transit.invalid/generated-validator/104"}}},{"type":"object","additionalProperties":false,"required":["observe"],"properties":{"observe":{"$ref":"https://transit.invalid/generated-validator/1"}}},{"type":"object","additionalProperties":false,"required":["status"],"properties":{"status":{"type":"string","maxLength":131072}}},{"type":"object","additionalProperties":false,"required":["page"],"properties":{"page":{"type":"object","additionalProperties":false,"properties":{"namespace":{"type":"string","maxLength":131072},"cursor":{"$ref":"https://transit.invalid/generated-validator/103"}},"required":["namespace"]}}},{"type":"object","additionalProperties":false,"required":["prepare_control"],"properties":{"prepare_control":{"type":"object","additionalProperties":false,"properties":{"namespace":{"type":"string","maxLength":131072},"operation":{"type":"string","enum":["cancel","collect","retire"]}},"required":["namespace","operation"]}}}]};
const schema127 = {"oneOf":[{"$ref":"https://transit.invalid/generated-validator/97"},{"$ref":"https://transit.invalid/generated-validator/98"},{"$ref":"https://transit.invalid/generated-validator/99"},{"$ref":"https://transit.invalid/generated-validator/54"},{"$ref":"https://transit.invalid/generated-validator/100"},{"$ref":"https://transit.invalid/generated-validator/101"}]};
const schema128 = {"type":"object","additionalProperties":false,"required":["int64"],"properties":{"int64":{"type":"string","maxLength":131072}}};

function validate584(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate584.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((data.int64 === undefined) && (missing0 = "int64")){
validate584.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(key0 === "int64")){
validate584.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.int64 !== undefined){
let data0 = data.int64;
const _errs2 = errors;
if(errors === _errs2){
if(typeof data0 === "string"){
if(func4(data0) > 131072){
validate584.errors = [{instancePath:instancePath+"/int64",schemaPath:"#/properties/int64/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"}];
return false;
}
}
else {
validate584.errors = [{instancePath:instancePath+"/int64",schemaPath:"#/properties/int64/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
}
}
}
}
}
else {
validate584.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate584.errors = vErrors;
return errors === 0;
}
validate584.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema129 = {"type":"object","additionalProperties":false,"required":["uint64"],"properties":{"uint64":{"type":"string","maxLength":131072}}};

function validate586(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate586.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((data.uint64 === undefined) && (missing0 = "uint64")){
validate586.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(key0 === "uint64")){
validate586.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.uint64 !== undefined){
let data0 = data.uint64;
const _errs2 = errors;
if(errors === _errs2){
if(typeof data0 === "string"){
if(func4(data0) > 131072){
validate586.errors = [{instancePath:instancePath+"/uint64",schemaPath:"#/properties/uint64/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"}];
return false;
}
}
else {
validate586.errors = [{instancePath:instancePath+"/uint64",schemaPath:"#/properties/uint64/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
}
}
}
}
}
else {
validate586.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate586.errors = vErrors;
return errors === 0;
}
validate586.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema130 = {"type":"object","additionalProperties":false,"required":["float_bits"],"properties":{"float_bits":{"type":"string","maxLength":131072}}};

function validate588(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate588.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((data.float_bits === undefined) && (missing0 = "float_bits")){
validate588.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(key0 === "float_bits")){
validate588.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.float_bits !== undefined){
let data0 = data.float_bits;
const _errs2 = errors;
if(errors === _errs2){
if(typeof data0 === "string"){
if(func4(data0) > 131072){
validate588.errors = [{instancePath:instancePath+"/float_bits",schemaPath:"#/properties/float_bits/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"}];
return false;
}
}
else {
validate588.errors = [{instancePath:instancePath+"/float_bits",schemaPath:"#/properties/float_bits/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
}
}
}
}
}
else {
validate588.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate588.errors = vErrors;
return errors === 0;
}
validate588.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema131 = {"type":"object","additionalProperties":false,"required":["utf8"],"properties":{"utf8":{"type":"string","maxLength":131072}}};

function validate591(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate591.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((data.utf8 === undefined) && (missing0 = "utf8")){
validate591.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(key0 === "utf8")){
validate591.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.utf8 !== undefined){
let data0 = data.utf8;
const _errs2 = errors;
if(errors === _errs2){
if(typeof data0 === "string"){
if(func4(data0) > 131072){
validate591.errors = [{instancePath:instancePath+"/utf8",schemaPath:"#/properties/utf8/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"}];
return false;
}
}
else {
validate591.errors = [{instancePath:instancePath+"/utf8",schemaPath:"#/properties/utf8/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
}
}
}
}
}
else {
validate591.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate591.errors = vErrors;
return errors === 0;
}
validate591.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema132 = {"type":"object","additionalProperties":false,"required":["binary"],"properties":{"binary":{"type":"string","maxLength":131072}}};

function validate593(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate593.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((data.binary === undefined) && (missing0 = "binary")){
validate593.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(key0 === "binary")){
validate593.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.binary !== undefined){
let data0 = data.binary;
const _errs2 = errors;
if(errors === _errs2){
if(typeof data0 === "string"){
if(func4(data0) > 131072){
validate593.errors = [{instancePath:instancePath+"/binary",schemaPath:"#/properties/binary/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"}];
return false;
}
}
else {
validate593.errors = [{instancePath:instancePath+"/binary",schemaPath:"#/properties/binary/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
}
}
}
}
}
else {
validate593.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate593.errors = vErrors;
return errors === 0;
}
validate593.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate583(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate583.evaluated;
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
if(!(validate584(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate584.errors : vErrors.concat(validate584.errors);
errors = vErrors.length;
}
var _valid0 = _errs1 === errors;
if(_valid0){
valid0 = true;
passing0 = 0;
var props0 = true;
}
const _errs2 = errors;
if(!(validate586(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate586.errors : vErrors.concat(validate586.errors);
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
if(!(validate588(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate588.errors : vErrors.concat(validate588.errors);
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
if(!(validate257(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate257.errors : vErrors.concat(validate257.errors);
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
if(!(validate591(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate591.errors : vErrors.concat(validate591.errors);
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
if(!(validate593(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate593.errors : vErrors.concat(validate593.errors);
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
const err0 = {instancePath,schemaPath:"#/oneOf",keyword:"oneOf",params:{passingSchemas: passing0},message:"must match exactly one schema in oneOf"};
if(vErrors === null){
vErrors = [err0];
}
else {
vErrors.push(err0);
}
errors++;
validate583.errors = vErrors;
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
validate583.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate583.evaluated = {"dynamicProps":true,"dynamicItems":false};

const schema133 = {"anyOf":[{"type":"string","maxLength":131072},{"type":"null"}]};

function validate597(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate597.evaluated;
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
if(func4(data) > 131072){
const err0 = {instancePath,schemaPath:"#/anyOf/0/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
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
validate597.errors = vErrors;
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
validate597.errors = vErrors;
return errors === 0;
}
validate597.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema134 = {"type":"object","additionalProperties":false,"properties":{"token":{"type":"string","maxLength":131072}},"required":["token"]};

function validate599(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate599.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((data.token === undefined) && (missing0 = "token")){
validate599.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(key0 === "token")){
validate599.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.token !== undefined){
let data0 = data.token;
const _errs2 = errors;
if(errors === _errs2){
if(typeof data0 === "string"){
if(func4(data0) > 131072){
validate599.errors = [{instancePath:instancePath+"/token",schemaPath:"#/properties/token/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"}];
return false;
}
}
else {
validate599.errors = [{instancePath:instancePath+"/token",schemaPath:"#/properties/token/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
}
}
}
}
}
else {
validate599.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate599.errors = vErrors;
return errors === 0;
}
validate599.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate580(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate580.evaluated;
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
if(errors === _errs1){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((data.describe === undefined) && (missing0 = "describe")){
const err0 = {instancePath,schemaPath:"#/oneOf/0/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"};
if(vErrors === null){
vErrors = [err0];
}
else {
vErrors.push(err0);
}
errors++;
}
else {
const _errs3 = errors;
for(const key0 in data){
if(!(key0 === "describe")){
const err1 = {instancePath,schemaPath:"#/oneOf/0/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"};
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
if(_errs3 === errors){
if(data.describe !== undefined){
let data0 = data.describe;
const _errs4 = errors;
if(errors === _errs4){
if(data0 && typeof data0 == "object" && !Array.isArray(data0)){
if(Object.keys(data0).length > 0){
const err2 = {instancePath:instancePath+"/describe",schemaPath:"#/oneOf/0/properties/describe/maxProperties",keyword:"maxProperties",params:{limit: 0},message:"must NOT have more than 0 properties"};
if(vErrors === null){
vErrors = [err2];
}
else {
vErrors.push(err2);
}
errors++;
}
}
else {
const err3 = {instancePath:instancePath+"/describe",schemaPath:"#/oneOf/0/properties/describe/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err3];
}
else {
vErrors.push(err3);
}
errors++;
}
}
}
}
}
}
else {
const err4 = {instancePath,schemaPath:"#/oneOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err4];
}
else {
vErrors.push(err4);
}
errors++;
}
}
var _valid0 = _errs1 === errors;
if(_valid0){
valid0 = true;
passing0 = 0;
var props0 = true;
}
const _errs6 = errors;
if(errors === _errs6){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing1;
if((data.sql_capabilities === undefined) && (missing1 = "sql_capabilities")){
const err5 = {instancePath,schemaPath:"#/oneOf/1/required",keyword:"required",params:{missingProperty: missing1},message:"must have required property '"+missing1+"'"};
if(vErrors === null){
vErrors = [err5];
}
else {
vErrors.push(err5);
}
errors++;
}
else {
const _errs8 = errors;
for(const key1 in data){
if(!(key1 === "sql_capabilities")){
const err6 = {instancePath,schemaPath:"#/oneOf/1/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key1},message:"must NOT have additional properties"};
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
if(_errs8 === errors){
if(data.sql_capabilities !== undefined){
let data1 = data.sql_capabilities;
const _errs9 = errors;
if(errors === _errs9){
if(data1 && typeof data1 == "object" && !Array.isArray(data1)){
if(Object.keys(data1).length > 0){
const err7 = {instancePath:instancePath+"/sql_capabilities",schemaPath:"#/oneOf/1/properties/sql_capabilities/maxProperties",keyword:"maxProperties",params:{limit: 0},message:"must NOT have more than 0 properties"};
if(vErrors === null){
vErrors = [err7];
}
else {
vErrors.push(err7);
}
errors++;
}
}
else {
const err8 = {instancePath:instancePath+"/sql_capabilities",schemaPath:"#/oneOf/1/properties/sql_capabilities/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err8];
}
else {
vErrors.push(err8);
}
errors++;
}
}
}
}
}
}
else {
const err9 = {instancePath,schemaPath:"#/oneOf/1/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err9];
}
else {
vErrors.push(err9);
}
errors++;
}
}
var _valid0 = _errs6 === errors;
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
const _errs11 = errors;
if(errors === _errs11){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing2;
if((data.suggest === undefined) && (missing2 = "suggest")){
const err10 = {instancePath,schemaPath:"#/oneOf/2/required",keyword:"required",params:{missingProperty: missing2},message:"must have required property '"+missing2+"'"};
if(vErrors === null){
vErrors = [err10];
}
else {
vErrors.push(err10);
}
errors++;
}
else {
const _errs13 = errors;
for(const key2 in data){
if(!(key2 === "suggest")){
const err11 = {instancePath,schemaPath:"#/oneOf/2/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key2},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err11];
}
else {
vErrors.push(err11);
}
errors++;
break;
}
}
if(_errs13 === errors){
if(data.suggest !== undefined){
let data2 = data.suggest;
const _errs14 = errors;
if(errors === _errs14){
if(data2 && typeof data2 == "object" && !Array.isArray(data2)){
let missing3;
if((data2.search === undefined) && (missing3 = "search")){
const err12 = {instancePath:instancePath+"/suggest",schemaPath:"#/oneOf/2/properties/suggest/required",keyword:"required",params:{missingProperty: missing3},message:"must have required property '"+missing3+"'"};
if(vErrors === null){
vErrors = [err12];
}
else {
vErrors.push(err12);
}
errors++;
}
else {
const _errs16 = errors;
for(const key3 in data2){
if(!(key3 === "search")){
const err13 = {instancePath:instancePath+"/suggest",schemaPath:"#/oneOf/2/properties/suggest/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key3},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err13];
}
else {
vErrors.push(err13);
}
errors++;
break;
}
}
if(_errs16 === errors){
if(data2.search !== undefined){
let data3 = data2.search;
const _errs17 = errors;
if(errors === _errs17){
if(typeof data3 === "string"){
if(func4(data3) > 131072){
const err14 = {instancePath:instancePath+"/suggest/search",schemaPath:"#/oneOf/2/properties/suggest/properties/search/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err14];
}
else {
vErrors.push(err14);
}
errors++;
}
}
else {
const err15 = {instancePath:instancePath+"/suggest/search",schemaPath:"#/oneOf/2/properties/suggest/properties/search/type",keyword:"type",params:{type: "string"},message:"must be string"};
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
}
}
else {
const err16 = {instancePath:instancePath+"/suggest",schemaPath:"#/oneOf/2/properties/suggest/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
}
else {
const err17 = {instancePath,schemaPath:"#/oneOf/2/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err17];
}
else {
vErrors.push(err17);
}
errors++;
}
}
var _valid0 = _errs11 === errors;
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
const _errs19 = errors;
if(errors === _errs19){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing4;
if((data.assist === undefined) && (missing4 = "assist")){
const err18 = {instancePath,schemaPath:"#/oneOf/3/required",keyword:"required",params:{missingProperty: missing4},message:"must have required property '"+missing4+"'"};
if(vErrors === null){
vErrors = [err18];
}
else {
vErrors.push(err18);
}
errors++;
}
else {
const _errs21 = errors;
for(const key4 in data){
if(!(key4 === "assist")){
const err19 = {instancePath,schemaPath:"#/oneOf/3/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key4},message:"must NOT have additional properties"};
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
if(_errs21 === errors){
if(data.assist !== undefined){
let data4 = data.assist;
const _errs22 = errors;
if(errors === _errs22){
if(data4 && typeof data4 == "object" && !Array.isArray(data4)){
let missing5;
if((((data4.sql === undefined) && (missing5 = "sql")) || ((data4.cursor === undefined) && (missing5 = "cursor"))) || ((data4.generation === undefined) && (missing5 = "generation"))){
const err20 = {instancePath:instancePath+"/assist",schemaPath:"#/oneOf/3/properties/assist/required",keyword:"required",params:{missingProperty: missing5},message:"must have required property '"+missing5+"'"};
if(vErrors === null){
vErrors = [err20];
}
else {
vErrors.push(err20);
}
errors++;
}
else {
const _errs24 = errors;
for(const key5 in data4){
if(!((((key5 === "sql") || (key5 === "cursor")) || (key5 === "generation")) || (key5 === "mode"))){
const err21 = {instancePath:instancePath+"/assist",schemaPath:"#/oneOf/3/properties/assist/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key5},message:"must NOT have additional properties"};
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
if(_errs24 === errors){
if(data4.sql !== undefined){
let data5 = data4.sql;
const _errs25 = errors;
if(errors === _errs25){
if(typeof data5 === "string"){
if(func4(data5) > 131072){
const err22 = {instancePath:instancePath+"/assist/sql",schemaPath:"#/oneOf/3/properties/assist/properties/sql/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err22];
}
else {
vErrors.push(err22);
}
errors++;
}
}
else {
const err23 = {instancePath:instancePath+"/assist/sql",schemaPath:"#/oneOf/3/properties/assist/properties/sql/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err23];
}
else {
vErrors.push(err23);
}
errors++;
}
}
var valid6 = _errs25 === errors;
}
else {
var valid6 = true;
}
if(valid6){
if(data4.cursor !== undefined){
const _errs27 = errors;
if(!(validate67(data4.cursor, {instancePath:instancePath+"/assist/cursor",parentData:data4,parentDataProperty:"cursor",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate67.errors : vErrors.concat(validate67.errors);
errors = vErrors.length;
}
var valid6 = _errs27 === errors;
}
else {
var valid6 = true;
}
if(valid6){
if(data4.generation !== undefined){
const _errs28 = errors;
if(!(validate53(data4.generation, {instancePath:instancePath+"/assist/generation",parentData:data4,parentDataProperty:"generation",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate53.errors : vErrors.concat(validate53.errors);
errors = vErrors.length;
}
var valid6 = _errs28 === errors;
}
else {
var valid6 = true;
}
if(valid6){
if(data4.mode !== undefined){
let data8 = data4.mode;
const _errs29 = errors;
if(typeof data8 !== "string"){
const err24 = {instancePath:instancePath+"/assist/mode",schemaPath:"#/oneOf/3/properties/assist/properties/mode/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err24];
}
else {
vErrors.push(err24);
}
errors++;
}
if(!((data8 === "sql") || (data8 === "console"))){
const err25 = {instancePath:instancePath+"/assist/mode",schemaPath:"#/oneOf/3/properties/assist/properties/mode/enum",keyword:"enum",params:{allowedValues: schema126.oneOf[3].properties.assist.properties.mode.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err25];
}
else {
vErrors.push(err25);
}
errors++;
}
var valid6 = _errs29 === errors;
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
else {
const err26 = {instancePath:instancePath+"/assist",schemaPath:"#/oneOf/3/properties/assist/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err27 = {instancePath,schemaPath:"#/oneOf/3/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err27];
}
else {
vErrors.push(err27);
}
errors++;
}
}
var _valid0 = _errs19 === errors;
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
const _errs31 = errors;
if(errors === _errs31){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing6;
if((data.compile === undefined) && (missing6 = "compile")){
const err28 = {instancePath,schemaPath:"#/oneOf/4/required",keyword:"required",params:{missingProperty: missing6},message:"must have required property '"+missing6+"'"};
if(vErrors === null){
vErrors = [err28];
}
else {
vErrors.push(err28);
}
errors++;
}
else {
const _errs33 = errors;
for(const key6 in data){
if(!(key6 === "compile")){
const err29 = {instancePath,schemaPath:"#/oneOf/4/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key6},message:"must NOT have additional properties"};
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
if(_errs33 === errors){
if(data.compile !== undefined){
let data9 = data.compile;
const _errs34 = errors;
if(errors === _errs34){
if(data9 && typeof data9 == "object" && !Array.isArray(data9)){
let missing7;
if((data9.sql === undefined) && (missing7 = "sql")){
const err30 = {instancePath:instancePath+"/compile",schemaPath:"#/oneOf/4/properties/compile/required",keyword:"required",params:{missingProperty: missing7},message:"must have required property '"+missing7+"'"};
if(vErrors === null){
vErrors = [err30];
}
else {
vErrors.push(err30);
}
errors++;
}
else {
const _errs36 = errors;
for(const key7 in data9){
if(!((key7 === "sql") || (key7 === "parameters"))){
const err31 = {instancePath:instancePath+"/compile",schemaPath:"#/oneOf/4/properties/compile/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key7},message:"must NOT have additional properties"};
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
if(_errs36 === errors){
if(data9.sql !== undefined){
let data10 = data9.sql;
const _errs37 = errors;
if(errors === _errs37){
if(typeof data10 === "string"){
if(func4(data10) > 131072){
const err32 = {instancePath:instancePath+"/compile/sql",schemaPath:"#/oneOf/4/properties/compile/properties/sql/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err32];
}
else {
vErrors.push(err32);
}
errors++;
}
}
else {
const err33 = {instancePath:instancePath+"/compile/sql",schemaPath:"#/oneOf/4/properties/compile/properties/sql/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err33];
}
else {
vErrors.push(err33);
}
errors++;
}
}
var valid8 = _errs37 === errors;
}
else {
var valid8 = true;
}
if(valid8){
if(data9.parameters !== undefined){
let data11 = data9.parameters;
const _errs39 = errors;
const _errs40 = errors;
let valid9 = false;
const _errs41 = errors;
if(errors === _errs41){
if(Array.isArray(data11)){
if(data11.length > 8){
const err34 = {instancePath:instancePath+"/compile/parameters",schemaPath:"#/oneOf/4/properties/compile/properties/parameters/anyOf/0/maxItems",keyword:"maxItems",params:{limit: 8},message:"must NOT have more than 8 items"};
if(vErrors === null){
vErrors = [err34];
}
else {
vErrors.push(err34);
}
errors++;
}
else {
var valid10 = true;
const len0 = data11.length;
for(let i0=0; i0<len0; i0++){
const _errs43 = errors;
if(!(validate583(data11[i0], {instancePath:instancePath+"/compile/parameters/" + i0,parentData:data11,parentDataProperty:i0,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate583.errors : vErrors.concat(validate583.errors);
errors = vErrors.length;
}
var valid10 = _errs43 === errors;
if(!valid10){
break;
}
}
}
}
else {
const err35 = {instancePath:instancePath+"/compile/parameters",schemaPath:"#/oneOf/4/properties/compile/properties/parameters/anyOf/0/type",keyword:"type",params:{type: "array"},message:"must be array"};
if(vErrors === null){
vErrors = [err35];
}
else {
vErrors.push(err35);
}
errors++;
}
}
var _valid1 = _errs41 === errors;
valid9 = valid9 || _valid1;
const _errs44 = errors;
if(data11 !== null){
const err36 = {instancePath:instancePath+"/compile/parameters",schemaPath:"#/oneOf/4/properties/compile/properties/parameters/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err36];
}
else {
vErrors.push(err36);
}
errors++;
}
var _valid1 = _errs44 === errors;
valid9 = valid9 || _valid1;
if(!valid9){
const err37 = {instancePath:instancePath+"/compile/parameters",schemaPath:"#/oneOf/4/properties/compile/properties/parameters/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err37];
}
else {
vErrors.push(err37);
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
var valid8 = _errs39 === errors;
}
else {
var valid8 = true;
}
}
}
}
}
else {
const err38 = {instancePath:instancePath+"/compile",schemaPath:"#/oneOf/4/properties/compile/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err39 = {instancePath,schemaPath:"#/oneOf/4/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err39];
}
else {
vErrors.push(err39);
}
errors++;
}
}
var _valid0 = _errs31 === errors;
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
const _errs46 = errors;
if(errors === _errs46){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing8;
if((data.inspect === undefined) && (missing8 = "inspect")){
const err40 = {instancePath,schemaPath:"#/oneOf/5/required",keyword:"required",params:{missingProperty: missing8},message:"must have required property '"+missing8+"'"};
if(vErrors === null){
vErrors = [err40];
}
else {
vErrors.push(err40);
}
errors++;
}
else {
const _errs48 = errors;
for(const key8 in data){
if(!(key8 === "inspect")){
const err41 = {instancePath,schemaPath:"#/oneOf/5/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key8},message:"must NOT have additional properties"};
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
if(_errs48 === errors){
if(data.inspect !== undefined){
let data13 = data.inspect;
const _errs49 = errors;
if(errors === _errs49){
if(data13 && typeof data13 == "object" && !Array.isArray(data13)){
let missing9;
if((data13.sql === undefined) && (missing9 = "sql")){
const err42 = {instancePath:instancePath+"/inspect",schemaPath:"#/oneOf/5/properties/inspect/required",keyword:"required",params:{missingProperty: missing9},message:"must have required property '"+missing9+"'"};
if(vErrors === null){
vErrors = [err42];
}
else {
vErrors.push(err42);
}
errors++;
}
else {
const _errs51 = errors;
for(const key9 in data13){
if(!(key9 === "sql")){
const err43 = {instancePath:instancePath+"/inspect",schemaPath:"#/oneOf/5/properties/inspect/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key9},message:"must NOT have additional properties"};
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
if(_errs51 === errors){
if(data13.sql !== undefined){
let data14 = data13.sql;
const _errs52 = errors;
if(errors === _errs52){
if(typeof data14 === "string"){
if(func4(data14) > 131072){
const err44 = {instancePath:instancePath+"/inspect/sql",schemaPath:"#/oneOf/5/properties/inspect/properties/sql/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err44];
}
else {
vErrors.push(err44);
}
errors++;
}
}
else {
const err45 = {instancePath:instancePath+"/inspect/sql",schemaPath:"#/oneOf/5/properties/inspect/properties/sql/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err45];
}
else {
vErrors.push(err45);
}
errors++;
}
}
}
}
}
}
else {
const err46 = {instancePath:instancePath+"/inspect",schemaPath:"#/oneOf/5/properties/inspect/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err47 = {instancePath,schemaPath:"#/oneOf/5/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err47];
}
else {
vErrors.push(err47);
}
errors++;
}
}
var _valid0 = _errs46 === errors;
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
const _errs54 = errors;
if(errors === _errs54){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing10;
if((data.next === undefined) && (missing10 = "next")){
const err48 = {instancePath,schemaPath:"#/oneOf/6/required",keyword:"required",params:{missingProperty: missing10},message:"must have required property '"+missing10+"'"};
if(vErrors === null){
vErrors = [err48];
}
else {
vErrors.push(err48);
}
errors++;
}
else {
const _errs56 = errors;
for(const key10 in data){
if(!(key10 === "next")){
const err49 = {instancePath,schemaPath:"#/oneOf/6/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key10},message:"must NOT have additional properties"};
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
if(_errs56 === errors){
if(data.next !== undefined){
let data15 = data.next;
const _errs57 = errors;
if(errors === _errs57){
if(data15 && typeof data15 == "object" && !Array.isArray(data15)){
let missing11;
if(((data15.namespace === undefined) && (missing11 = "namespace")) || ((data15.bundle === undefined) && (missing11 = "bundle"))){
const err50 = {instancePath:instancePath+"/next",schemaPath:"#/oneOf/6/properties/next/required",keyword:"required",params:{missingProperty: missing11},message:"must have required property '"+missing11+"'"};
if(vErrors === null){
vErrors = [err50];
}
else {
vErrors.push(err50);
}
errors++;
}
else {
const _errs59 = errors;
for(const key11 in data15){
if(!((key11 === "namespace") || (key11 === "bundle"))){
const err51 = {instancePath:instancePath+"/next",schemaPath:"#/oneOf/6/properties/next/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key11},message:"must NOT have additional properties"};
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
if(_errs59 === errors){
if(data15.namespace !== undefined){
let data16 = data15.namespace;
const _errs60 = errors;
if(errors === _errs60){
if(typeof data16 === "string"){
if(func4(data16) > 131072){
const err52 = {instancePath:instancePath+"/next/namespace",schemaPath:"#/oneOf/6/properties/next/properties/namespace/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err52];
}
else {
vErrors.push(err52);
}
errors++;
}
}
else {
const err53 = {instancePath:instancePath+"/next/namespace",schemaPath:"#/oneOf/6/properties/next/properties/namespace/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err53];
}
else {
vErrors.push(err53);
}
errors++;
}
}
var valid14 = _errs60 === errors;
}
else {
var valid14 = true;
}
if(valid14){
if(data15.bundle !== undefined){
let data17 = data15.bundle;
const _errs62 = errors;
if(errors === _errs62){
if(typeof data17 === "string"){
if(func4(data17) > 131072){
const err54 = {instancePath:instancePath+"/next/bundle",schemaPath:"#/oneOf/6/properties/next/properties/bundle/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err54];
}
else {
vErrors.push(err54);
}
errors++;
}
}
else {
const err55 = {instancePath:instancePath+"/next/bundle",schemaPath:"#/oneOf/6/properties/next/properties/bundle/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err55];
}
else {
vErrors.push(err55);
}
errors++;
}
}
var valid14 = _errs62 === errors;
}
else {
var valid14 = true;
}
}
}
}
}
else {
const err56 = {instancePath:instancePath+"/next",schemaPath:"#/oneOf/6/properties/next/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
}
}
else {
const err57 = {instancePath,schemaPath:"#/oneOf/6/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err57];
}
else {
vErrors.push(err57);
}
errors++;
}
}
var _valid0 = _errs54 === errors;
if(_valid0 && valid0){
valid0 = false;
passing0 = [passing0, 6];
}
else {
if(_valid0){
valid0 = true;
passing0 = 6;
if(props0 !== true){
props0 = true;
}
}
const _errs64 = errors;
if(errors === _errs64){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing12;
if((data.next_draft === undefined) && (missing12 = "next_draft")){
const err58 = {instancePath,schemaPath:"#/oneOf/7/required",keyword:"required",params:{missingProperty: missing12},message:"must have required property '"+missing12+"'"};
if(vErrors === null){
vErrors = [err58];
}
else {
vErrors.push(err58);
}
errors++;
}
else {
const _errs66 = errors;
for(const key12 in data){
if(!(key12 === "next_draft")){
const err59 = {instancePath,schemaPath:"#/oneOf/7/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key12},message:"must NOT have additional properties"};
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
if(_errs66 === errors){
if(data.next_draft !== undefined){
let data18 = data.next_draft;
const _errs67 = errors;
if(errors === _errs67){
if(data18 && typeof data18 == "object" && !Array.isArray(data18)){
let missing13;
if((((data18.namespace === undefined) && (missing13 = "namespace")) || ((data18.bundle === undefined) && (missing13 = "bundle"))) || ((data18.generation === undefined) && (missing13 = "generation"))){
const err60 = {instancePath:instancePath+"/next_draft",schemaPath:"#/oneOf/7/properties/next_draft/required",keyword:"required",params:{missingProperty: missing13},message:"must have required property '"+missing13+"'"};
if(vErrors === null){
vErrors = [err60];
}
else {
vErrors.push(err60);
}
errors++;
}
else {
const _errs69 = errors;
for(const key13 in data18){
if(!(((key13 === "namespace") || (key13 === "bundle")) || (key13 === "generation"))){
const err61 = {instancePath:instancePath+"/next_draft",schemaPath:"#/oneOf/7/properties/next_draft/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key13},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err61];
}
else {
vErrors.push(err61);
}
errors++;
break;
}
}
if(_errs69 === errors){
if(data18.namespace !== undefined){
let data19 = data18.namespace;
const _errs70 = errors;
if(errors === _errs70){
if(typeof data19 === "string"){
if(func4(data19) > 131072){
const err62 = {instancePath:instancePath+"/next_draft/namespace",schemaPath:"#/oneOf/7/properties/next_draft/properties/namespace/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err62];
}
else {
vErrors.push(err62);
}
errors++;
}
}
else {
const err63 = {instancePath:instancePath+"/next_draft/namespace",schemaPath:"#/oneOf/7/properties/next_draft/properties/namespace/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err63];
}
else {
vErrors.push(err63);
}
errors++;
}
}
var valid16 = _errs70 === errors;
}
else {
var valid16 = true;
}
if(valid16){
if(data18.bundle !== undefined){
let data20 = data18.bundle;
const _errs72 = errors;
if(errors === _errs72){
if(typeof data20 === "string"){
if(func4(data20) > 131072){
const err64 = {instancePath:instancePath+"/next_draft/bundle",schemaPath:"#/oneOf/7/properties/next_draft/properties/bundle/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err64];
}
else {
vErrors.push(err64);
}
errors++;
}
}
else {
const err65 = {instancePath:instancePath+"/next_draft/bundle",schemaPath:"#/oneOf/7/properties/next_draft/properties/bundle/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err65];
}
else {
vErrors.push(err65);
}
errors++;
}
}
var valid16 = _errs72 === errors;
}
else {
var valid16 = true;
}
if(valid16){
if(data18.generation !== undefined){
let data21 = data18.generation;
const _errs74 = errors;
if(errors === _errs74){
if(typeof data21 === "string"){
if(func4(data21) > 131072){
const err66 = {instancePath:instancePath+"/next_draft/generation",schemaPath:"#/oneOf/7/properties/next_draft/properties/generation/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err66];
}
else {
vErrors.push(err66);
}
errors++;
}
}
else {
const err67 = {instancePath:instancePath+"/next_draft/generation",schemaPath:"#/oneOf/7/properties/next_draft/properties/generation/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err67];
}
else {
vErrors.push(err67);
}
errors++;
}
}
var valid16 = _errs74 === errors;
}
else {
var valid16 = true;
}
}
}
}
}
}
else {
const err68 = {instancePath:instancePath+"/next_draft",schemaPath:"#/oneOf/7/properties/next_draft/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
}
}
else {
const err69 = {instancePath,schemaPath:"#/oneOf/7/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err69];
}
else {
vErrors.push(err69);
}
errors++;
}
}
var _valid0 = _errs64 === errors;
if(_valid0 && valid0){
valid0 = false;
passing0 = [passing0, 7];
}
else {
if(_valid0){
valid0 = true;
passing0 = 7;
if(props0 !== true){
props0 = true;
}
}
const _errs76 = errors;
if(errors === _errs76){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing14;
if((data.draft_open === undefined) && (missing14 = "draft_open")){
const err70 = {instancePath,schemaPath:"#/oneOf/8/required",keyword:"required",params:{missingProperty: missing14},message:"must have required property '"+missing14+"'"};
if(vErrors === null){
vErrors = [err70];
}
else {
vErrors.push(err70);
}
errors++;
}
else {
const _errs78 = errors;
for(const key14 in data){
if(!(key14 === "draft_open")){
const err71 = {instancePath,schemaPath:"#/oneOf/8/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key14},message:"must NOT have additional properties"};
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
if(_errs78 === errors){
if(data.draft_open !== undefined){
let data22 = data.draft_open;
const _errs79 = errors;
if(errors === _errs79){
if(data22 && typeof data22 == "object" && !Array.isArray(data22)){
let missing15;
if(((data22.expected === undefined) && (missing15 = "expected")) || ((data22.limit === undefined) && (missing15 = "limit"))){
const err72 = {instancePath:instancePath+"/draft_open",schemaPath:"#/oneOf/8/properties/draft_open/required",keyword:"required",params:{missingProperty: missing15},message:"must have required property '"+missing15+"'"};
if(vErrors === null){
vErrors = [err72];
}
else {
vErrors.push(err72);
}
errors++;
}
else {
const _errs81 = errors;
for(const key15 in data22){
if(!((key15 === "expected") || (key15 === "limit"))){
const err73 = {instancePath:instancePath+"/draft_open",schemaPath:"#/oneOf/8/properties/draft_open/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key15},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err73];
}
else {
vErrors.push(err73);
}
errors++;
break;
}
}
if(_errs81 === errors){
if(data22.expected !== undefined){
let data23 = data22.expected;
const _errs82 = errors;
if(errors === _errs82){
if(typeof data23 === "string"){
if(func4(data23) > 131072){
const err74 = {instancePath:instancePath+"/draft_open/expected",schemaPath:"#/oneOf/8/properties/draft_open/properties/expected/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err74];
}
else {
vErrors.push(err74);
}
errors++;
}
}
else {
const err75 = {instancePath:instancePath+"/draft_open/expected",schemaPath:"#/oneOf/8/properties/draft_open/properties/expected/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err75];
}
else {
vErrors.push(err75);
}
errors++;
}
}
var valid18 = _errs82 === errors;
}
else {
var valid18 = true;
}
if(valid18){
if(data22.limit !== undefined){
const _errs84 = errors;
if(!(validate102(data22.limit, {instancePath:instancePath+"/draft_open/limit",parentData:data22,parentDataProperty:"limit",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate102.errors : vErrors.concat(validate102.errors);
errors = vErrors.length;
}
var valid18 = _errs84 === errors;
}
else {
var valid18 = true;
}
}
}
}
}
else {
const err76 = {instancePath:instancePath+"/draft_open",schemaPath:"#/oneOf/8/properties/draft_open/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err76];
}
else {
vErrors.push(err76);
}
errors++;
}
}
}
}
}
}
else {
const err77 = {instancePath,schemaPath:"#/oneOf/8/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err77];
}
else {
vErrors.push(err77);
}
errors++;
}
}
var _valid0 = _errs76 === errors;
if(_valid0 && valid0){
valid0 = false;
passing0 = [passing0, 8];
}
else {
if(_valid0){
valid0 = true;
passing0 = 8;
if(props0 !== true){
props0 = true;
}
}
const _errs85 = errors;
if(errors === _errs85){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing16;
if((data.draft_close === undefined) && (missing16 = "draft_close")){
const err78 = {instancePath,schemaPath:"#/oneOf/9/required",keyword:"required",params:{missingProperty: missing16},message:"must have required property '"+missing16+"'"};
if(vErrors === null){
vErrors = [err78];
}
else {
vErrors.push(err78);
}
errors++;
}
else {
const _errs87 = errors;
for(const key16 in data){
if(!(key16 === "draft_close")){
const err79 = {instancePath,schemaPath:"#/oneOf/9/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key16},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err79];
}
else {
vErrors.push(err79);
}
errors++;
break;
}
}
if(_errs87 === errors){
if(data.draft_close !== undefined){
let data25 = data.draft_close;
const _errs88 = errors;
if(errors === _errs88){
if(typeof data25 === "string"){
if(func4(data25) > 131072){
const err80 = {instancePath:instancePath+"/draft_close",schemaPath:"#/oneOf/9/properties/draft_close/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err80];
}
else {
vErrors.push(err80);
}
errors++;
}
}
else {
const err81 = {instancePath:instancePath+"/draft_close",schemaPath:"#/oneOf/9/properties/draft_close/type",keyword:"type",params:{type: "string"},message:"must be string"};
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
const err82 = {instancePath,schemaPath:"#/oneOf/9/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err82];
}
else {
vErrors.push(err82);
}
errors++;
}
}
var _valid0 = _errs85 === errors;
if(_valid0 && valid0){
valid0 = false;
passing0 = [passing0, 9];
}
else {
if(_valid0){
valid0 = true;
passing0 = 9;
if(props0 !== true){
props0 = true;
}
}
const _errs90 = errors;
if(errors === _errs90){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing17;
if((data.draft_status === undefined) && (missing17 = "draft_status")){
const err83 = {instancePath,schemaPath:"#/oneOf/10/required",keyword:"required",params:{missingProperty: missing17},message:"must have required property '"+missing17+"'"};
if(vErrors === null){
vErrors = [err83];
}
else {
vErrors.push(err83);
}
errors++;
}
else {
const _errs92 = errors;
for(const key17 in data){
if(!(key17 === "draft_status")){
const err84 = {instancePath,schemaPath:"#/oneOf/10/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key17},message:"must NOT have additional properties"};
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
if(_errs92 === errors){
if(data.draft_status !== undefined){
if(!(validate597(data.draft_status, {instancePath:instancePath+"/draft_status",parentData:data,parentDataProperty:"draft_status",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate597.errors : vErrors.concat(validate597.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err85 = {instancePath,schemaPath:"#/oneOf/10/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err85];
}
else {
vErrors.push(err85);
}
errors++;
}
}
var _valid0 = _errs90 === errors;
if(_valid0 && valid0){
valid0 = false;
passing0 = [passing0, 10];
}
else {
if(_valid0){
valid0 = true;
passing0 = 10;
if(props0 !== true){
props0 = true;
}
}
const _errs94 = errors;
if(errors === _errs94){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing18;
if((data.submit === undefined) && (missing18 = "submit")){
const err86 = {instancePath,schemaPath:"#/oneOf/11/required",keyword:"required",params:{missingProperty: missing18},message:"must have required property '"+missing18+"'"};
if(vErrors === null){
vErrors = [err86];
}
else {
vErrors.push(err86);
}
errors++;
}
else {
const _errs96 = errors;
for(const key18 in data){
if(!(key18 === "submit")){
const err87 = {instancePath,schemaPath:"#/oneOf/11/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key18},message:"must NOT have additional properties"};
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
if(_errs96 === errors){
if(data.submit !== undefined){
if(!(validate599(data.submit, {instancePath:instancePath+"/submit",parentData:data,parentDataProperty:"submit",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate599.errors : vErrors.concat(validate599.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err88 = {instancePath,schemaPath:"#/oneOf/11/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err88];
}
else {
vErrors.push(err88);
}
errors++;
}
}
var _valid0 = _errs94 === errors;
if(_valid0 && valid0){
valid0 = false;
passing0 = [passing0, 11];
}
else {
if(_valid0){
valid0 = true;
passing0 = 11;
if(props0 !== true){
props0 = true;
}
}
const _errs98 = errors;
if(errors === _errs98){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing19;
if((data.observe === undefined) && (missing19 = "observe")){
const err89 = {instancePath,schemaPath:"#/oneOf/12/required",keyword:"required",params:{missingProperty: missing19},message:"must have required property '"+missing19+"'"};
if(vErrors === null){
vErrors = [err89];
}
else {
vErrors.push(err89);
}
errors++;
}
else {
const _errs100 = errors;
for(const key19 in data){
if(!(key19 === "observe")){
const err90 = {instancePath,schemaPath:"#/oneOf/12/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key19},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err90];
}
else {
vErrors.push(err90);
}
errors++;
break;
}
}
if(_errs100 === errors){
if(data.observe !== undefined){
if(!(validate55(data.observe, {instancePath:instancePath+"/observe",parentData:data,parentDataProperty:"observe",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate55.errors : vErrors.concat(validate55.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err91 = {instancePath,schemaPath:"#/oneOf/12/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err91];
}
else {
vErrors.push(err91);
}
errors++;
}
}
var _valid0 = _errs98 === errors;
if(_valid0 && valid0){
valid0 = false;
passing0 = [passing0, 12];
}
else {
if(_valid0){
valid0 = true;
passing0 = 12;
if(props0 !== true){
props0 = true;
}
}
const _errs102 = errors;
if(errors === _errs102){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing20;
if((data.status === undefined) && (missing20 = "status")){
const err92 = {instancePath,schemaPath:"#/oneOf/13/required",keyword:"required",params:{missingProperty: missing20},message:"must have required property '"+missing20+"'"};
if(vErrors === null){
vErrors = [err92];
}
else {
vErrors.push(err92);
}
errors++;
}
else {
const _errs104 = errors;
for(const key20 in data){
if(!(key20 === "status")){
const err93 = {instancePath,schemaPath:"#/oneOf/13/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key20},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err93];
}
else {
vErrors.push(err93);
}
errors++;
break;
}
}
if(_errs104 === errors){
if(data.status !== undefined){
let data29 = data.status;
const _errs105 = errors;
if(errors === _errs105){
if(typeof data29 === "string"){
if(func4(data29) > 131072){
const err94 = {instancePath:instancePath+"/status",schemaPath:"#/oneOf/13/properties/status/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err94];
}
else {
vErrors.push(err94);
}
errors++;
}
}
else {
const err95 = {instancePath:instancePath+"/status",schemaPath:"#/oneOf/13/properties/status/type",keyword:"type",params:{type: "string"},message:"must be string"};
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
}
}
else {
const err96 = {instancePath,schemaPath:"#/oneOf/13/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err96];
}
else {
vErrors.push(err96);
}
errors++;
}
}
var _valid0 = _errs102 === errors;
if(_valid0 && valid0){
valid0 = false;
passing0 = [passing0, 13];
}
else {
if(_valid0){
valid0 = true;
passing0 = 13;
if(props0 !== true){
props0 = true;
}
}
const _errs107 = errors;
if(errors === _errs107){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing21;
if((data.page === undefined) && (missing21 = "page")){
const err97 = {instancePath,schemaPath:"#/oneOf/14/required",keyword:"required",params:{missingProperty: missing21},message:"must have required property '"+missing21+"'"};
if(vErrors === null){
vErrors = [err97];
}
else {
vErrors.push(err97);
}
errors++;
}
else {
const _errs109 = errors;
for(const key21 in data){
if(!(key21 === "page")){
const err98 = {instancePath,schemaPath:"#/oneOf/14/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key21},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err98];
}
else {
vErrors.push(err98);
}
errors++;
break;
}
}
if(_errs109 === errors){
if(data.page !== undefined){
let data30 = data.page;
const _errs110 = errors;
if(errors === _errs110){
if(data30 && typeof data30 == "object" && !Array.isArray(data30)){
let missing22;
if((data30.namespace === undefined) && (missing22 = "namespace")){
const err99 = {instancePath:instancePath+"/page",schemaPath:"#/oneOf/14/properties/page/required",keyword:"required",params:{missingProperty: missing22},message:"must have required property '"+missing22+"'"};
if(vErrors === null){
vErrors = [err99];
}
else {
vErrors.push(err99);
}
errors++;
}
else {
const _errs112 = errors;
for(const key22 in data30){
if(!((key22 === "namespace") || (key22 === "cursor"))){
const err100 = {instancePath:instancePath+"/page",schemaPath:"#/oneOf/14/properties/page/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key22},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err100];
}
else {
vErrors.push(err100);
}
errors++;
break;
}
}
if(_errs112 === errors){
if(data30.namespace !== undefined){
let data31 = data30.namespace;
const _errs113 = errors;
if(errors === _errs113){
if(typeof data31 === "string"){
if(func4(data31) > 131072){
const err101 = {instancePath:instancePath+"/page/namespace",schemaPath:"#/oneOf/14/properties/page/properties/namespace/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err101];
}
else {
vErrors.push(err101);
}
errors++;
}
}
else {
const err102 = {instancePath:instancePath+"/page/namespace",schemaPath:"#/oneOf/14/properties/page/properties/namespace/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err102];
}
else {
vErrors.push(err102);
}
errors++;
}
}
var valid25 = _errs113 === errors;
}
else {
var valid25 = true;
}
if(valid25){
if(data30.cursor !== undefined){
const _errs115 = errors;
if(!(validate597(data30.cursor, {instancePath:instancePath+"/page/cursor",parentData:data30,parentDataProperty:"cursor",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate597.errors : vErrors.concat(validate597.errors);
errors = vErrors.length;
}
var valid25 = _errs115 === errors;
}
else {
var valid25 = true;
}
}
}
}
}
else {
const err103 = {instancePath:instancePath+"/page",schemaPath:"#/oneOf/14/properties/page/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err103];
}
else {
vErrors.push(err103);
}
errors++;
}
}
}
}
}
}
else {
const err104 = {instancePath,schemaPath:"#/oneOf/14/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err104];
}
else {
vErrors.push(err104);
}
errors++;
}
}
var _valid0 = _errs107 === errors;
if(_valid0 && valid0){
valid0 = false;
passing0 = [passing0, 14];
}
else {
if(_valid0){
valid0 = true;
passing0 = 14;
if(props0 !== true){
props0 = true;
}
}
const _errs116 = errors;
if(errors === _errs116){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing23;
if((data.prepare_control === undefined) && (missing23 = "prepare_control")){
const err105 = {instancePath,schemaPath:"#/oneOf/15/required",keyword:"required",params:{missingProperty: missing23},message:"must have required property '"+missing23+"'"};
if(vErrors === null){
vErrors = [err105];
}
else {
vErrors.push(err105);
}
errors++;
}
else {
const _errs118 = errors;
for(const key23 in data){
if(!(key23 === "prepare_control")){
const err106 = {instancePath,schemaPath:"#/oneOf/15/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key23},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err106];
}
else {
vErrors.push(err106);
}
errors++;
break;
}
}
if(_errs118 === errors){
if(data.prepare_control !== undefined){
let data33 = data.prepare_control;
const _errs119 = errors;
if(errors === _errs119){
if(data33 && typeof data33 == "object" && !Array.isArray(data33)){
let missing24;
if(((data33.namespace === undefined) && (missing24 = "namespace")) || ((data33.operation === undefined) && (missing24 = "operation"))){
const err107 = {instancePath:instancePath+"/prepare_control",schemaPath:"#/oneOf/15/properties/prepare_control/required",keyword:"required",params:{missingProperty: missing24},message:"must have required property '"+missing24+"'"};
if(vErrors === null){
vErrors = [err107];
}
else {
vErrors.push(err107);
}
errors++;
}
else {
const _errs121 = errors;
for(const key24 in data33){
if(!((key24 === "namespace") || (key24 === "operation"))){
const err108 = {instancePath:instancePath+"/prepare_control",schemaPath:"#/oneOf/15/properties/prepare_control/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key24},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err108];
}
else {
vErrors.push(err108);
}
errors++;
break;
}
}
if(_errs121 === errors){
if(data33.namespace !== undefined){
let data34 = data33.namespace;
const _errs122 = errors;
if(errors === _errs122){
if(typeof data34 === "string"){
if(func4(data34) > 131072){
const err109 = {instancePath:instancePath+"/prepare_control/namespace",schemaPath:"#/oneOf/15/properties/prepare_control/properties/namespace/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err109];
}
else {
vErrors.push(err109);
}
errors++;
}
}
else {
const err110 = {instancePath:instancePath+"/prepare_control/namespace",schemaPath:"#/oneOf/15/properties/prepare_control/properties/namespace/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err110];
}
else {
vErrors.push(err110);
}
errors++;
}
}
var valid27 = _errs122 === errors;
}
else {
var valid27 = true;
}
if(valid27){
if(data33.operation !== undefined){
let data35 = data33.operation;
const _errs124 = errors;
if(typeof data35 !== "string"){
const err111 = {instancePath:instancePath+"/prepare_control/operation",schemaPath:"#/oneOf/15/properties/prepare_control/properties/operation/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err111];
}
else {
vErrors.push(err111);
}
errors++;
}
if(!(((data35 === "cancel") || (data35 === "collect")) || (data35 === "retire"))){
const err112 = {instancePath:instancePath+"/prepare_control/operation",schemaPath:"#/oneOf/15/properties/prepare_control/properties/operation/enum",keyword:"enum",params:{allowedValues: schema126.oneOf[15].properties.prepare_control.properties.operation.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err112];
}
else {
vErrors.push(err112);
}
errors++;
}
var valid27 = _errs124 === errors;
}
else {
var valid27 = true;
}
}
}
}
}
else {
const err113 = {instancePath:instancePath+"/prepare_control",schemaPath:"#/oneOf/15/properties/prepare_control/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
}
}
}
else {
const err114 = {instancePath,schemaPath:"#/oneOf/15/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err114];
}
else {
vErrors.push(err114);
}
errors++;
}
}
var _valid0 = _errs116 === errors;
if(_valid0 && valid0){
valid0 = false;
passing0 = [passing0, 15];
}
else {
if(_valid0){
valid0 = true;
passing0 = 15;
if(props0 !== true){
props0 = true;
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
if(!valid0){
const err115 = {instancePath,schemaPath:"#/oneOf",keyword:"oneOf",params:{passingSchemas: passing0},message:"must match exactly one schema in oneOf"};
if(vErrors === null){
vErrors = [err115];
}
else {
vErrors.push(err115);
}
errors++;
validate580.errors = vErrors;
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
validate580.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate580.evaluated = {"dynamicProps":true,"dynamicItems":false};

export const UnifiedQueryResponse = validate603;
const schema135 = {"oneOf":[{"type":"object","additionalProperties":false,"required":["description"],"properties":{"description":{"type":"object","additionalProperties":false,"properties":{"connection":{"type":"object","additionalProperties":false,"properties":{"realm":{"$ref":"https://transit.invalid/generated-validator/1"},"principal":{"$ref":"https://transit.invalid/generated-validator/1"},"source":{"$ref":"https://transit.invalid/generated-validator/1"},"resource":{"$ref":"https://transit.invalid/generated-validator/1"},"requester":{"$ref":"https://transit.invalid/generated-validator/1"},"requests":{"$ref":"https://transit.invalid/generated-validator/1"}},"required":["realm","principal","source","resource","requester","requests"]},"name":{"type":"string","maxLength":131072},"source":{"type":"object","additionalProperties":false,"properties":{"capabilities":{"type":"object","additionalProperties":false,"properties":{"version":{"$ref":"https://transit.invalid/generated-validator/9"},"source":{"$ref":"https://transit.invalid/generated-validator/9"},"plan":{"$ref":"https://transit.invalid/generated-validator/9"},"result":{"$ref":"https://transit.invalid/generated-validator/9"},"bundle_bytes":{"$ref":"https://transit.invalid/generated-validator/0"},"part_bytes":{"$ref":"https://transit.invalid/generated-validator/4"},"segment_bytes":{"$ref":"https://transit.invalid/generated-validator/0"},"batch_rows":{"$ref":"https://transit.invalid/generated-validator/9"},"columns":{"$ref":"https://transit.invalid/generated-validator/9"},"kv":{"type":"boolean"},"table":{"type":"boolean"},"document":{"type":"boolean"}},"required":["version","source","plan","result","bundle_bytes","part_bytes","segment_bytes","batch_rows","columns","kv","table","document"]},"source":{"$ref":"https://transit.invalid/generated-validator/122"},"resource_revision":{"$ref":"https://transit.invalid/generated-validator/1"},"policy_revision":{"type":"string","maxLength":131072},"limits":{"$ref":"https://transit.invalid/generated-validator/123"},"active":{"$ref":"https://transit.invalid/generated-validator/103"}},"required":["capabilities","source","resource_revision","policy_revision","limits","active"]},"sql":{"type":"object","additionalProperties":false,"properties":{"version":{"$ref":"https://transit.invalid/generated-validator/9"},"statement_bytes":{"$ref":"https://transit.invalid/generated-validator/0"},"named_columns":{"$ref":"https://transit.invalid/generated-validator/9"},"star_columns":{"$ref":"https://transit.invalid/generated-validator/9"},"uint64_limits":{"type":"boolean"},"uint64_literals":{"type":"boolean"},"float64_literals":{"type":"boolean"},"null_comparison":{"type":"boolean"},"explicit_null_test":{"type":"boolean"},"writes":{"type":"boolean"},"continuous":{"type":"boolean"}},"required":["version","statement_bytes","named_columns","star_columns","uint64_limits","uint64_literals","float64_literals","null_comparison","explicit_null_test","writes","continuous"]},"budgets":{"$ref":"https://transit.invalid/generated-validator/123"},"columns":{"$ref":"https://transit.invalid/generated-validator/124"}},"required":["connection","name","source","sql","budgets","columns"]}}},{"type":"object","additionalProperties":false,"required":["sql_capabilities"],"properties":{"sql_capabilities":{"type":"object","additionalProperties":false,"properties":{"version":{"$ref":"https://transit.invalid/generated-validator/9"},"parameters":{"type":"boolean"},"max_parameters":{"$ref":"https://transit.invalid/generated-validator/9"},"statement_bytes":{"$ref":"https://transit.invalid/generated-validator/0"}},"required":["version","parameters","max_parameters","statement_bytes"]}}},{"type":"object","additionalProperties":false,"required":["suggestions"],"properties":{"suggestions":{"type":"object","additionalProperties":false,"properties":{"resource":{"$ref":"https://transit.invalid/generated-validator/1"},"contract":{"$ref":"https://transit.invalid/generated-validator/11"},"items":{"type":"array","maxItems":8,"items":{"type":"object","additionalProperties":false,"properties":{"label":{"type":"string","maxLength":131072},"sql":{"type":"string","maxLength":131072}},"required":["label","sql"]}}},"required":["resource","contract","items"]}}},{"type":"object","additionalProperties":false,"required":["assistance"],"properties":{"assistance":{"type":"object","additionalProperties":false,"properties":{"version":{"$ref":"https://transit.invalid/generated-validator/9"},"generation":{"$ref":"https://transit.invalid/generated-validator/0"},"profile":{"type":"string","enum":["unified_v1","catalog_v1"]},"resource":{"$ref":"https://transit.invalid/generated-validator/1"},"contract":{"$ref":"https://transit.invalid/generated-validator/11"},"resource_revision":{"$ref":"https://transit.invalid/generated-validator/1"},"policy_revision":{"type":"string","maxLength":131072},"range":{"anyOf":[{"type":"object","additionalProperties":false,"properties":{"start":{"$ref":"https://transit.invalid/generated-validator/4"},"end":{"$ref":"https://transit.invalid/generated-validator/4"},"quoted":{"type":"boolean"}},"required":["start","end","quoted"]},{"type":"null"}]},"items":{"type":"array","maxItems":8,"items":{"type":"object","additionalProperties":false,"properties":{"text":{"type":"string","maxLength":131072},"kind":{"type":"string","enum":["keyword","source","column","symbol","literal","meta"]},"detail":{"type":"string","maxLength":131072}},"required":["text","kind","detail"]}}},"required":["version","generation","profile","resource","contract","resource_revision","policy_revision","range","items"]}}},{"type":"object","additionalProperties":false,"required":["compiled"],"properties":{"compiled":{"type":"object","additionalProperties":false,"properties":{"bundle":{"type":"string","maxLength":131072},"source":{"$ref":"https://transit.invalid/generated-validator/122"},"plan":{"type":"object","additionalProperties":false,"properties":{"version":{"$ref":"https://transit.invalid/generated-validator/9"},"projection":{"type":"array","maxItems":8,"items":{"$ref":"https://transit.invalid/generated-validator/0"}},"output_names":{"anyOf":[{"type":"array","maxItems":8,"items":{"$ref":"https://transit.invalid/generated-validator/103"}},{"type":"null"}]},"limit":{"$ref":"https://transit.invalid/generated-validator/103"},"aggregate":{"$ref":"https://transit.invalid/generated-validator/125"},"predicate":{"oneOf":[{"$ref":"https://transit.invalid/generated-validator/126"},{"$ref":"https://transit.invalid/generated-validator/129"},{"$ref":"https://transit.invalid/generated-validator/132"},{"type":"object","additionalProperties":false,"required":["program"],"properties":{"program":{"type":"array","maxItems":64,"items":{"oneOf":[{"type":"object","additionalProperties":false,"required":["atom"],"properties":{"atom":{"oneOf":[{"$ref":"https://transit.invalid/generated-validator/126"},{"$ref":"https://transit.invalid/generated-validator/129"},{"$ref":"https://transit.invalid/generated-validator/132"}]}}},{"$ref":"https://transit.invalid/generated-validator/133"},{"$ref":"https://transit.invalid/generated-validator/134"},{"$ref":"https://transit.invalid/generated-validator/135"}]}}}}]}},"required":["version","projection","output_names","limit","aggregate","predicate"]},"limits":{"$ref":"https://transit.invalid/generated-validator/123"},"contract":{"$ref":"https://transit.invalid/generated-validator/11"},"schema":{"$ref":"https://transit.invalid/generated-validator/11"}},"required":["bundle","source","plan","limits","contract","schema"]}}},{"type":"object","additionalProperties":false,"required":["inspection"],"properties":{"inspection":{"type":"object","additionalProperties":false,"properties":{"version":{"$ref":"https://transit.invalid/generated-validator/9"},"scope":{"type":"string","enum":["configured_source"]},"name":{"type":"string","maxLength":131072},"resource":{"$ref":"https://transit.invalid/generated-validator/1"},"source_kind":{"$ref":"https://transit.invalid/generated-validator/88"},"contract":{"$ref":"https://transit.invalid/generated-validator/11"},"schema":{"$ref":"https://transit.invalid/generated-validator/11"},"resource_revision":{"$ref":"https://transit.invalid/generated-validator/1"},"policy_revision":{"type":"string","maxLength":131072},"details":{"oneOf":[{"type":"object","additionalProperties":false,"required":["description"],"properties":{"description":{"type":"object","additionalProperties":false,"properties":{"columns":{"$ref":"https://transit.invalid/generated-validator/124"}},"required":["columns"]}}},{"type":"object","additionalProperties":false,"required":["tables"],"properties":{"tables":{"$ref":"https://transit.invalid/generated-validator/113"}}},{"type":"object","additionalProperties":false,"required":["explanation"],"properties":{"explanation":{"type":"object","additionalProperties":false,"properties":{"operators":{"type":"array","maxItems":8,"items":{"type":"string","enum":["scan","filter","limit","project","count","sum","count_values"]}},"predicate":{"oneOf":[{"$ref":"https://transit.invalid/generated-validator/126"},{"$ref":"https://transit.invalid/generated-validator/137"},{"$ref":"https://transit.invalid/generated-validator/139"},{"type":"object","additionalProperties":false,"required":["program"],"properties":{"program":{"type":"array","maxItems":64,"items":{"oneOf":[{"type":"object","additionalProperties":false,"required":["atom"],"properties":{"atom":{"oneOf":[{"$ref":"https://transit.invalid/generated-validator/126"},{"$ref":"https://transit.invalid/generated-validator/137"},{"$ref":"https://transit.invalid/generated-validator/139"}]}}},{"$ref":"https://transit.invalid/generated-validator/133"},{"$ref":"https://transit.invalid/generated-validator/134"},{"$ref":"https://transit.invalid/generated-validator/135"}]}}}}]},"projection":{"$ref":"https://transit.invalid/generated-validator/113"},"limit":{"$ref":"https://transit.invalid/generated-validator/103"},"aggregate":{"$ref":"https://transit.invalid/generated-validator/125"},"columns":{"$ref":"https://transit.invalid/generated-validator/124"},"budgets":{"$ref":"https://transit.invalid/generated-validator/123"}},"required":["operators","predicate","projection","limit","aggregate","columns","budgets"]}}}]}},"required":["version","scope","name","resource","source_kind","contract","schema","resource_revision","policy_revision","details"]}}},{"type":"object","additionalProperties":false,"required":["prepared"],"properties":{"prepared":{"anyOf":[{"$ref":"https://transit.invalid/generated-validator/104"},{"type":"null"}]}}},{"type":"object","additionalProperties":false,"required":["receipt"],"properties":{"receipt":{"type":"object","additionalProperties":false,"properties":{"position":{"$ref":"https://transit.invalid/generated-validator/1"}},"required":["position"]}}},{"type":"object","additionalProperties":false,"required":["observation"],"properties":{"observation":{"oneOf":[{"type":"object","additionalProperties":false,"required":["pending"],"properties":{"pending":{"type":"object","maxProperties":0}}},{"type":"object","additionalProperties":false,"required":["committed"],"properties":{"committed":{"type":"object","maxProperties":0}}},{"type":"object","additionalProperties":false,"required":["rejected"],"properties":{"rejected":{"$ref":"https://transit.invalid/generated-validator/21"}}}]}}},{"type":"object","additionalProperties":false,"required":["status"],"properties":{"status":{"anyOf":[{"type":"object","additionalProperties":false,"properties":{"reference":{"$ref":"https://transit.invalid/generated-validator/21"},"phase":{"$ref":"https://transit.invalid/generated-validator/87"},"correlation":{"type":"string","maxLength":131072},"manifest":{"$ref":"https://transit.invalid/generated-validator/22"},"collected":{"type":"boolean"},"failure":{"anyOf":[{"type":"object","additionalProperties":false,"properties":{"code":{"$ref":"https://transit.invalid/generated-validator/82"},"stage":{"$ref":"https://transit.invalid/generated-validator/83"},"dimension":{"$ref":"https://transit.invalid/generated-validator/84"},"limit":{"type":"string","maxLength":131072},"observed":{"type":"string","maxLength":131072}},"required":["code","stage","dimension","limit","observed"]},{"type":"null"}]},"diagnostic":{"$ref":"https://transit.invalid/generated-validator/67"}},"required":["reference","phase","correlation","manifest","collected","failure","diagnostic"]},{"type":"null"}]}}},{"type":"object","additionalProperties":false,"required":["page"],"properties":{"page":{"type":"object","additionalProperties":false,"properties":{"evidence":{"type":"object","additionalProperties":false,"properties":{"manifest":{"type":"object","additionalProperties":false,"properties":{"job":{"$ref":"https://transit.invalid/generated-validator/1"},"source":{"$ref":"https://transit.invalid/generated-validator/81"},"requester":{"$ref":"https://transit.invalid/generated-validator/1"},"correlation":{"type":"string","maxLength":131072},"policy_revision":{"type":"string","maxLength":131072},"request":{"$ref":"https://transit.invalid/generated-validator/21"},"basis":{"$ref":"https://transit.invalid/generated-validator/89"},"plan":{"$ref":"https://transit.invalid/generated-validator/11"},"pages":{"type":"string","maxLength":131072},"scanned":{"type":"string","maxLength":131072},"selected":{"type":"string","maxLength":131072},"value_count":{"type":"string","maxLength":131072},"segments":{"type":"string","maxLength":131072},"rows":{"type":"string","maxLength":131072},"bytes":{"type":"string","maxLength":131072},"sum":{"$ref":"https://transit.invalid/generated-validator/103"},"finished":{"anyOf":[{"type":"string","enum":["source_end","limit"]},{"type":"null"}]},"chain":{"$ref":"https://transit.invalid/generated-validator/11"}},"required":["job","source","requester","correlation","policy_revision","request","basis","plan","pages","scanned","selected","value_count","segments","rows","bytes","sum","finished","chain"]},"columns":{"$ref":"https://transit.invalid/generated-validator/124"},"ordinal":{"type":"string","maxLength":131072},"rows":{"$ref":"https://transit.invalid/generated-validator/9"},"ipc":{"type":"string","maxLength":131072},"next":{"$ref":"https://transit.invalid/generated-validator/103"}},"required":["manifest","columns","ordinal","rows","ipc","next"]},"cells":{"type":"array","maxItems":8,"items":{"type":"array","maxItems":8,"items":{"oneOf":[{"type":"object","additionalProperties":false,"required":["missing"],"properties":{"missing":{"type":"object","maxProperties":0}}},{"$ref":"https://transit.invalid/generated-validator/140"},{"$ref":"https://transit.invalid/generated-validator/142"},{"$ref":"https://transit.invalid/generated-validator/143"},{"type":"object","additionalProperties":false,"required":["conflict"],"properties":{"conflict":{"type":"array","maxItems":8,"items":{"type":"object","additionalProperties":false,"properties":{"counter":{"type":"string","maxLength":131072},"replica":{"type":"string","maxLength":131072},"value":{"oneOf":[{"$ref":"https://transit.invalid/generated-validator/140"},{"$ref":"https://transit.invalid/generated-validator/142"},{"$ref":"https://transit.invalid/generated-validator/143"}]}},"required":["counter","replica","value"]}}}}]}}}},"required":["evidence","cells"]}}},{"type":"object","additionalProperties":false,"required":["draft"],"properties":{"draft":{"anyOf":[{"type":"object","additionalProperties":false,"properties":{"generation":{"type":"string","maxLength":131072},"limit":{"$ref":"https://transit.invalid/generated-validator/9"},"starts":{"$ref":"https://transit.invalid/generated-validator/9"},"enabled":{"type":"boolean"},"contract":{"$ref":"https://transit.invalid/generated-validator/11"},"budgets":{"$ref":"https://transit.invalid/generated-validator/123"},"namespaces":{"type":"array","minItems":8,"maxItems":8,"items":{"type":"string","maxLength":131072}}},"required":["generation","limit","starts","enabled","contract","budgets","namespaces"]},{"type":"null"}]}}}]};
const schema136 = {"type":"object","additionalProperties":false,"properties":{"version":{"$ref":"https://transit.invalid/generated-validator/9"},"resource":{"$ref":"https://transit.invalid/generated-validator/1"},"source":{"$ref":"https://transit.invalid/generated-validator/121"}},"required":["version","resource","source"]};
const schema137 = {"oneOf":[{"$ref":"https://transit.invalid/generated-validator/108"},{"$ref":"https://transit.invalid/generated-validator/111"},{"$ref":"https://transit.invalid/generated-validator/120"}]};
const schema138 = {"type":"object","additionalProperties":false,"required":["kv"],"properties":{"kv":{"$ref":"https://transit.invalid/generated-validator/107"}}};
const schema139 = {"type":"object","additionalProperties":false,"properties":{"prefix":{"type":"string","maxLength":131072},"key":{"$ref":"https://transit.invalid/generated-validator/106"},"value":{"$ref":"https://transit.invalid/generated-validator/106"}},"required":["prefix","key","value"]};
const schema140 = {"type":"object","additionalProperties":false,"properties":{"version":{"$ref":"https://transit.invalid/generated-validator/9"},"type":{"$ref":"https://transit.invalid/generated-validator/105"}},"required":["version","type"]};
const schema141 = {"type":"string","enum":["int64","uint64","float64","boolean","utf8","binary"]};

function validate627(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate627.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate627.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
if(!((((((data === "int64") || (data === "uint64")) || (data === "float64")) || (data === "boolean")) || (data === "utf8")) || (data === "binary"))){
validate627.errors = [{instancePath,schemaPath:"#/enum",keyword:"enum",params:{allowedValues: schema141.enum},message:"must be equal to one of the allowed values"}];
return false;
}
validate627.errors = vErrors;
return errors === 0;
}
validate627.evaluated = {"dynamicProps":false,"dynamicItems":false};


function validate625(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate625.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if(((data.version === undefined) && (missing0 = "version")) || ((data.type === undefined) && (missing0 = "type"))){
validate625.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "version") || (key0 === "type"))){
validate625.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.version !== undefined){
const _errs2 = errors;
if(!(validate102(data.version, {instancePath:instancePath+"/version",parentData:data,parentDataProperty:"version",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate102.errors : vErrors.concat(validate102.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.type !== undefined){
const _errs3 = errors;
if(!(validate627(data.type, {instancePath:instancePath+"/type",parentData:data,parentDataProperty:"type",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate627.errors : vErrors.concat(validate627.errors);
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
validate625.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate625.errors = vErrors;
return errors === 0;
}
validate625.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate624(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate624.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((((data.prefix === undefined) && (missing0 = "prefix")) || ((data.key === undefined) && (missing0 = "key"))) || ((data.value === undefined) && (missing0 = "value"))){
validate624.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "prefix") || (key0 === "key")) || (key0 === "value"))){
validate624.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.prefix !== undefined){
let data0 = data.prefix;
const _errs2 = errors;
if(errors === _errs2){
if(typeof data0 === "string"){
if(func4(data0) > 131072){
validate624.errors = [{instancePath:instancePath+"/prefix",schemaPath:"#/properties/prefix/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"}];
return false;
}
}
else {
validate624.errors = [{instancePath:instancePath+"/prefix",schemaPath:"#/properties/prefix/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.key !== undefined){
const _errs4 = errors;
if(!(validate625(data.key, {instancePath:instancePath+"/key",parentData:data,parentDataProperty:"key",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate625.errors : vErrors.concat(validate625.errors);
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
if(!(validate625(data.value, {instancePath:instancePath+"/value",parentData:data,parentDataProperty:"value",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate625.errors : vErrors.concat(validate625.errors);
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
else {
validate624.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate624.errors = vErrors;
return errors === 0;
}
validate624.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate623(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate623.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((data.kv === undefined) && (missing0 = "kv")){
validate623.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(key0 === "kv")){
validate623.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.kv !== undefined){
if(!(validate624(data.kv, {instancePath:instancePath+"/kv",parentData:data,parentDataProperty:"kv",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate624.errors : vErrors.concat(validate624.errors);
errors = vErrors.length;
}
}
}
}
}
else {
validate623.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate623.errors = vErrors;
return errors === 0;
}
validate623.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema142 = {"type":"object","additionalProperties":false,"required":["table"],"properties":{"table":{"$ref":"https://transit.invalid/generated-validator/110"}}};
const schema143 = {"type":"object","additionalProperties":false,"properties":{"id":{"$ref":"https://transit.invalid/generated-validator/0"},"names":{"$ref":"https://transit.invalid/generated-validator/109"},"value_type":{"$ref":"https://transit.invalid/generated-validator/73"}},"required":["id","names","value_type"]};
const schema144 = {"type":"array","minItems":2,"maxItems":2,"items":{"type":"string","maxLength":131072}};

function validate636(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate636.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(Array.isArray(data)){
if(data.length > 2){
validate636.errors = [{instancePath,schemaPath:"#/maxItems",keyword:"maxItems",params:{limit: 2},message:"must NOT have more than 2 items"}];
return false;
}
else {
if(data.length < 2){
validate636.errors = [{instancePath,schemaPath:"#/minItems",keyword:"minItems",params:{limit: 2},message:"must NOT have fewer than 2 items"}];
return false;
}
else {
var valid0 = true;
const len0 = data.length;
for(let i0=0; i0<len0; i0++){
let data0 = data[i0];
const _errs1 = errors;
if(errors === _errs1){
if(typeof data0 === "string"){
if(func4(data0) > 131072){
validate636.errors = [{instancePath:instancePath+"/" + i0,schemaPath:"#/items/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"}];
return false;
}
}
else {
validate636.errors = [{instancePath:instancePath+"/" + i0,schemaPath:"#/items/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
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
validate636.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "array"},message:"must be array"}];
return false;
}
}
validate636.errors = vErrors;
return errors === 0;
}
validate636.evaluated = {"items":true,"dynamicProps":false,"dynamicItems":false};


function validate634(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate634.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((((data.id === undefined) && (missing0 = "id")) || ((data.names === undefined) && (missing0 = "names"))) || ((data.value_type === undefined) && (missing0 = "value_type"))){
validate634.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "id") || (key0 === "names")) || (key0 === "value_type"))){
validate634.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.id !== undefined){
const _errs2 = errors;
if(!(validate53(data.id, {instancePath:instancePath+"/id",parentData:data,parentDataProperty:"id",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate53.errors : vErrors.concat(validate53.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.names !== undefined){
const _errs3 = errors;
if(!(validate636(data.names, {instancePath:instancePath+"/names",parentData:data,parentDataProperty:"names",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate636.errors : vErrors.concat(validate636.errors);
errors = vErrors.length;
}
var valid0 = _errs3 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.value_type !== undefined){
const _errs4 = errors;
if(!(validate327(data.value_type, {instancePath:instancePath+"/value_type",parentData:data,parentDataProperty:"value_type",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate327.errors : vErrors.concat(validate327.errors);
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
validate634.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate634.errors = vErrors;
return errors === 0;
}
validate634.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate633(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate633.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((data.table === undefined) && (missing0 = "table")){
validate633.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(key0 === "table")){
validate633.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.table !== undefined){
if(!(validate634(data.table, {instancePath:instancePath+"/table",parentData:data,parentDataProperty:"table",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate634.errors : vErrors.concat(validate634.errors);
errors = vErrors.length;
}
}
}
}
}
else {
validate633.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate633.errors = vErrors;
return errors === 0;
}
validate633.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema145 = {"type":"object","additionalProperties":false,"required":["document"],"properties":{"document":{"$ref":"https://transit.invalid/generated-validator/119"}}};
const schema146 = {"type":"object","additionalProperties":false,"properties":{"reference":{"$ref":"https://transit.invalid/generated-validator/112"},"change_format":{"$ref":"https://transit.invalid/generated-validator/0"},"expand":{"$ref":"https://transit.invalid/generated-validator/114"},"projections":{"$ref":"https://transit.invalid/generated-validator/118"}},"required":["reference","change_format","expand","projections"]};
const schema147 = {"type":"object","additionalProperties":false,"properties":{"resource":{"$ref":"https://transit.invalid/generated-validator/1"},"document":{"type":"string","maxLength":131072},"epoch":{"type":"string","maxLength":131072},"type_revision":{"$ref":"https://transit.invalid/generated-validator/0"},"revision":{"type":"string","maxLength":131072}},"required":["resource","document","epoch","type_revision","revision"]};

function validate643(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate643.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((((((data.resource === undefined) && (missing0 = "resource")) || ((data.document === undefined) && (missing0 = "document"))) || ((data.epoch === undefined) && (missing0 = "epoch"))) || ((data.type_revision === undefined) && (missing0 = "type_revision"))) || ((data.revision === undefined) && (missing0 = "revision"))){
validate643.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((((key0 === "resource") || (key0 === "document")) || (key0 === "epoch")) || (key0 === "type_revision")) || (key0 === "revision"))){
validate643.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.resource !== undefined){
const _errs2 = errors;
if(!(validate55(data.resource, {instancePath:instancePath+"/resource",parentData:data,parentDataProperty:"resource",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate55.errors : vErrors.concat(validate55.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.document !== undefined){
let data1 = data.document;
const _errs3 = errors;
if(errors === _errs3){
if(typeof data1 === "string"){
if(func4(data1) > 131072){
validate643.errors = [{instancePath:instancePath+"/document",schemaPath:"#/properties/document/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"}];
return false;
}
}
else {
validate643.errors = [{instancePath:instancePath+"/document",schemaPath:"#/properties/document/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
}
var valid0 = _errs3 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.epoch !== undefined){
let data2 = data.epoch;
const _errs5 = errors;
if(errors === _errs5){
if(typeof data2 === "string"){
if(func4(data2) > 131072){
validate643.errors = [{instancePath:instancePath+"/epoch",schemaPath:"#/properties/epoch/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"}];
return false;
}
}
else {
validate643.errors = [{instancePath:instancePath+"/epoch",schemaPath:"#/properties/epoch/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
}
var valid0 = _errs5 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.type_revision !== undefined){
const _errs7 = errors;
if(!(validate53(data.type_revision, {instancePath:instancePath+"/type_revision",parentData:data,parentDataProperty:"type_revision",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate53.errors : vErrors.concat(validate53.errors);
errors = vErrors.length;
}
var valid0 = _errs7 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.revision !== undefined){
let data4 = data.revision;
const _errs8 = errors;
if(errors === _errs8){
if(typeof data4 === "string"){
if(func4(data4) > 131072){
validate643.errors = [{instancePath:instancePath+"/revision",schemaPath:"#/properties/revision/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"}];
return false;
}
}
else {
validate643.errors = [{instancePath:instancePath+"/revision",schemaPath:"#/properties/revision/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
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
else {
validate643.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate643.errors = vErrors;
return errors === 0;
}
validate643.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema148 = {"anyOf":[{"$ref":"https://transit.invalid/generated-validator/113"},{"type":"null"}]};
const schema149 = {"type":"array","maxItems":8,"items":{"type":"string","maxLength":131072}};

function validate649(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate649.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(Array.isArray(data)){
if(data.length > 8){
validate649.errors = [{instancePath,schemaPath:"#/maxItems",keyword:"maxItems",params:{limit: 8},message:"must NOT have more than 8 items"}];
return false;
}
else {
var valid0 = true;
const len0 = data.length;
for(let i0=0; i0<len0; i0++){
let data0 = data[i0];
const _errs1 = errors;
if(errors === _errs1){
if(typeof data0 === "string"){
if(func4(data0) > 131072){
validate649.errors = [{instancePath:instancePath+"/" + i0,schemaPath:"#/items/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"}];
return false;
}
}
else {
validate649.errors = [{instancePath:instancePath+"/" + i0,schemaPath:"#/items/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
}
var valid0 = _errs1 === errors;
if(!valid0){
break;
}
}
}
}
else {
validate649.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "array"},message:"must be array"}];
return false;
}
}
validate649.errors = vErrors;
return errors === 0;
}
validate649.evaluated = {"items":true,"dynamicProps":false,"dynamicItems":false};


function validate648(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate648.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate649(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate649.errors : vErrors.concat(validate649.errors);
errors = vErrors.length;
}
var _valid0 = _errs1 === errors;
valid0 = valid0 || _valid0;
if(_valid0){
var items0 = true;
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
validate648.errors = vErrors;
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
validate648.errors = vErrors;
evaluated0.items = items0;
return errors === 0;
}
validate648.evaluated = {"dynamicProps":false,"dynamicItems":true};

const schema150 = {"type":"array","maxItems":8,"items":{"$ref":"https://transit.invalid/generated-validator/117"}};
const schema151 = {"type":"object","additionalProperties":false,"properties":{"column":{"$ref":"https://transit.invalid/generated-validator/115"},"path":{"$ref":"https://transit.invalid/generated-validator/113"},"relative":{"type":"boolean"},"mode":{"$ref":"https://transit.invalid/generated-validator/116"},"text_bytes":{"$ref":"https://transit.invalid/generated-validator/4"},"text_steps":{"$ref":"https://transit.invalid/generated-validator/4"}},"required":["column","path","relative","mode","text_bytes","text_steps"]};
const schema152 = {"type":"object","additionalProperties":false,"properties":{"name":{"type":"string","maxLength":131072},"type":{"$ref":"https://transit.invalid/generated-validator/105"}},"required":["name","type"]};

function validate654(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate654.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if(((data.name === undefined) && (missing0 = "name")) || ((data.type === undefined) && (missing0 = "type"))){
validate654.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "name") || (key0 === "type"))){
validate654.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.name !== undefined){
let data0 = data.name;
const _errs2 = errors;
if(errors === _errs2){
if(typeof data0 === "string"){
if(func4(data0) > 131072){
validate654.errors = [{instancePath:instancePath+"/name",schemaPath:"#/properties/name/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"}];
return false;
}
}
else {
validate654.errors = [{instancePath:instancePath+"/name",schemaPath:"#/properties/name/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.type !== undefined){
const _errs4 = errors;
if(!(validate627(data.type, {instancePath:instancePath+"/type",parentData:data,parentDataProperty:"type",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate627.errors : vErrors.concat(validate627.errors);
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
else {
validate654.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate654.errors = vErrors;
return errors === 0;
}
validate654.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema153 = {"type":"string","enum":["scalar","text","element_counter","element_replica"]};

function validate658(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate658.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate658.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
if(!((((data === "scalar") || (data === "text")) || (data === "element_counter")) || (data === "element_replica"))){
validate658.errors = [{instancePath,schemaPath:"#/enum",keyword:"enum",params:{allowedValues: schema153.enum},message:"must be equal to one of the allowed values"}];
return false;
}
validate658.errors = vErrors;
return errors === 0;
}
validate658.evaluated = {"dynamicProps":false,"dynamicItems":false};


function validate653(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate653.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if(((((((data.column === undefined) && (missing0 = "column")) || ((data.path === undefined) && (missing0 = "path"))) || ((data.relative === undefined) && (missing0 = "relative"))) || ((data.mode === undefined) && (missing0 = "mode"))) || ((data.text_bytes === undefined) && (missing0 = "text_bytes"))) || ((data.text_steps === undefined) && (missing0 = "text_steps"))){
validate653.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((((((key0 === "column") || (key0 === "path")) || (key0 === "relative")) || (key0 === "mode")) || (key0 === "text_bytes")) || (key0 === "text_steps"))){
validate653.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.column !== undefined){
const _errs2 = errors;
if(!(validate654(data.column, {instancePath:instancePath+"/column",parentData:data,parentDataProperty:"column",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate654.errors : vErrors.concat(validate654.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.path !== undefined){
const _errs3 = errors;
if(!(validate649(data.path, {instancePath:instancePath+"/path",parentData:data,parentDataProperty:"path",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate649.errors : vErrors.concat(validate649.errors);
errors = vErrors.length;
}
var valid0 = _errs3 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.relative !== undefined){
const _errs4 = errors;
if(typeof data.relative !== "boolean"){
validate653.errors = [{instancePath:instancePath+"/relative",schemaPath:"#/properties/relative/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"}];
return false;
}
var valid0 = _errs4 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.mode !== undefined){
const _errs6 = errors;
if(!(validate658(data.mode, {instancePath:instancePath+"/mode",parentData:data,parentDataProperty:"mode",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate658.errors : vErrors.concat(validate658.errors);
errors = vErrors.length;
}
var valid0 = _errs6 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.text_bytes !== undefined){
const _errs7 = errors;
if(!(validate67(data.text_bytes, {instancePath:instancePath+"/text_bytes",parentData:data,parentDataProperty:"text_bytes",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate67.errors : vErrors.concat(validate67.errors);
errors = vErrors.length;
}
var valid0 = _errs7 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.text_steps !== undefined){
const _errs8 = errors;
if(!(validate67(data.text_steps, {instancePath:instancePath+"/text_steps",parentData:data,parentDataProperty:"text_steps",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate67.errors : vErrors.concat(validate67.errors);
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
else {
validate653.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate653.errors = vErrors;
return errors === 0;
}
validate653.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate652(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate652.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(Array.isArray(data)){
if(data.length > 8){
validate652.errors = [{instancePath,schemaPath:"#/maxItems",keyword:"maxItems",params:{limit: 8},message:"must NOT have more than 8 items"}];
return false;
}
else {
var valid0 = true;
const len0 = data.length;
for(let i0=0; i0<len0; i0++){
const _errs1 = errors;
if(!(validate653(data[i0], {instancePath:instancePath+"/" + i0,parentData:data,parentDataProperty:i0,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate653.errors : vErrors.concat(validate653.errors);
errors = vErrors.length;
}
var valid0 = _errs1 === errors;
if(!valid0){
break;
}
}
}
}
else {
validate652.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "array"},message:"must be array"}];
return false;
}
}
validate652.errors = vErrors;
return errors === 0;
}
validate652.evaluated = {"items":true,"dynamicProps":false,"dynamicItems":false};


function validate642(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate642.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if(((((data.reference === undefined) && (missing0 = "reference")) || ((data.change_format === undefined) && (missing0 = "change_format"))) || ((data.expand === undefined) && (missing0 = "expand"))) || ((data.projections === undefined) && (missing0 = "projections"))){
validate642.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((((key0 === "reference") || (key0 === "change_format")) || (key0 === "expand")) || (key0 === "projections"))){
validate642.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.reference !== undefined){
const _errs2 = errors;
if(!(validate643(data.reference, {instancePath:instancePath+"/reference",parentData:data,parentDataProperty:"reference",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate643.errors : vErrors.concat(validate643.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.change_format !== undefined){
const _errs3 = errors;
if(!(validate53(data.change_format, {instancePath:instancePath+"/change_format",parentData:data,parentDataProperty:"change_format",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate53.errors : vErrors.concat(validate53.errors);
errors = vErrors.length;
}
var valid0 = _errs3 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.expand !== undefined){
const _errs4 = errors;
if(!(validate648(data.expand, {instancePath:instancePath+"/expand",parentData:data,parentDataProperty:"expand",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate648.errors : vErrors.concat(validate648.errors);
errors = vErrors.length;
}
var valid0 = _errs4 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.projections !== undefined){
const _errs5 = errors;
if(!(validate652(data.projections, {instancePath:instancePath+"/projections",parentData:data,parentDataProperty:"projections",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate652.errors : vErrors.concat(validate652.errors);
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
validate642.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate642.errors = vErrors;
return errors === 0;
}
validate642.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate641(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate641.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((data.document === undefined) && (missing0 = "document")){
validate641.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(key0 === "document")){
validate641.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.document !== undefined){
if(!(validate642(data.document, {instancePath:instancePath+"/document",parentData:data,parentDataProperty:"document",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate642.errors : vErrors.concat(validate642.errors);
errors = vErrors.length;
}
}
}
}
}
else {
validate641.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate641.errors = vErrors;
return errors === 0;
}
validate641.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate622(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate622.evaluated;
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
if(!(validate623(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate623.errors : vErrors.concat(validate623.errors);
errors = vErrors.length;
}
var _valid0 = _errs1 === errors;
if(_valid0){
valid0 = true;
passing0 = 0;
var props0 = true;
}
const _errs2 = errors;
if(!(validate633(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate633.errors : vErrors.concat(validate633.errors);
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
if(!(validate641(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate641.errors : vErrors.concat(validate641.errors);
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
}
}
if(!valid0){
const err0 = {instancePath,schemaPath:"#/oneOf",keyword:"oneOf",params:{passingSchemas: passing0},message:"must match exactly one schema in oneOf"};
if(vErrors === null){
vErrors = [err0];
}
else {
vErrors.push(err0);
}
errors++;
validate622.errors = vErrors;
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
validate622.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate622.evaluated = {"dynamicProps":true,"dynamicItems":false};


function validate619(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate619.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((((data.version === undefined) && (missing0 = "version")) || ((data.resource === undefined) && (missing0 = "resource"))) || ((data.source === undefined) && (missing0 = "source"))){
validate619.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "version") || (key0 === "resource")) || (key0 === "source"))){
validate619.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.version !== undefined){
const _errs2 = errors;
if(!(validate102(data.version, {instancePath:instancePath+"/version",parentData:data,parentDataProperty:"version",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate102.errors : vErrors.concat(validate102.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.resource !== undefined){
const _errs3 = errors;
if(!(validate55(data.resource, {instancePath:instancePath+"/resource",parentData:data,parentDataProperty:"resource",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate55.errors : vErrors.concat(validate55.errors);
errors = vErrors.length;
}
var valid0 = _errs3 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.source !== undefined){
const _errs4 = errors;
if(!(validate622(data.source, {instancePath:instancePath+"/source",parentData:data,parentDataProperty:"source",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate622.errors : vErrors.concat(validate622.errors);
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
validate619.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate619.errors = vErrors;
return errors === 0;
}
validate619.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema154 = {"type":"object","additionalProperties":false,"properties":{"pages":{"type":"string","maxLength":131072},"segments":{"type":"string","maxLength":131072},"result_bytes":{"type":"string","maxLength":131072}},"required":["pages","segments","result_bytes"]};

function validate669(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate669.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((((data.pages === undefined) && (missing0 = "pages")) || ((data.segments === undefined) && (missing0 = "segments"))) || ((data.result_bytes === undefined) && (missing0 = "result_bytes"))){
validate669.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "pages") || (key0 === "segments")) || (key0 === "result_bytes"))){
validate669.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.pages !== undefined){
let data0 = data.pages;
const _errs2 = errors;
if(errors === _errs2){
if(typeof data0 === "string"){
if(func4(data0) > 131072){
validate669.errors = [{instancePath:instancePath+"/pages",schemaPath:"#/properties/pages/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"}];
return false;
}
}
else {
validate669.errors = [{instancePath:instancePath+"/pages",schemaPath:"#/properties/pages/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.segments !== undefined){
let data1 = data.segments;
const _errs4 = errors;
if(errors === _errs4){
if(typeof data1 === "string"){
if(func4(data1) > 131072){
validate669.errors = [{instancePath:instancePath+"/segments",schemaPath:"#/properties/segments/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"}];
return false;
}
}
else {
validate669.errors = [{instancePath:instancePath+"/segments",schemaPath:"#/properties/segments/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
}
var valid0 = _errs4 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.result_bytes !== undefined){
let data2 = data.result_bytes;
const _errs6 = errors;
if(errors === _errs6){
if(typeof data2 === "string"){
if(func4(data2) > 131072){
validate669.errors = [{instancePath:instancePath+"/result_bytes",schemaPath:"#/properties/result_bytes/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"}];
return false;
}
}
else {
validate669.errors = [{instancePath:instancePath+"/result_bytes",schemaPath:"#/properties/result_bytes/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
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
else {
validate669.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate669.errors = vErrors;
return errors === 0;
}
validate669.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema155 = {"type":"array","maxItems":8,"items":{"$ref":"https://transit.invalid/generated-validator/115"}};

function validate677(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate677.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(Array.isArray(data)){
if(data.length > 8){
validate677.errors = [{instancePath,schemaPath:"#/maxItems",keyword:"maxItems",params:{limit: 8},message:"must NOT have more than 8 items"}];
return false;
}
else {
var valid0 = true;
const len0 = data.length;
for(let i0=0; i0<len0; i0++){
const _errs1 = errors;
if(!(validate654(data[i0], {instancePath:instancePath+"/" + i0,parentData:data,parentDataProperty:i0,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate654.errors : vErrors.concat(validate654.errors);
errors = vErrors.length;
}
var valid0 = _errs1 === errors;
if(!valid0){
break;
}
}
}
}
else {
validate677.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "array"},message:"must be array"}];
return false;
}
}
validate677.errors = vErrors;
return errors === 0;
}
validate677.evaluated = {"items":true,"dynamicProps":false,"dynamicItems":false};

const schema156 = {"type":"string","enum":["rows","count","sum","count_values"]};

function validate697(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate697.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate697.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
if(!((((data === "rows") || (data === "count")) || (data === "sum")) || (data === "count_values"))){
validate697.errors = [{instancePath,schemaPath:"#/enum",keyword:"enum",params:{allowedValues: schema156.enum},message:"must be equal to one of the allowed values"}];
return false;
}
validate697.errors = vErrors;
return errors === 0;
}
validate697.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema157 = {"type":"object","additionalProperties":false,"required":["all"],"properties":{"all":{"type":"object","maxProperties":0}}};

function validate699(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate699.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((data.all === undefined) && (missing0 = "all")){
validate699.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(key0 === "all")){
validate699.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.all !== undefined){
let data0 = data.all;
const _errs2 = errors;
if(errors === _errs2){
if(data0 && typeof data0 == "object" && !Array.isArray(data0)){
if(Object.keys(data0).length > 0){
validate699.errors = [{instancePath:instancePath+"/all",schemaPath:"#/properties/all/maxProperties",keyword:"maxProperties",params:{limit: 0},message:"must NOT have more than 0 properties"}];
return false;
}
}
else {
validate699.errors = [{instancePath:instancePath+"/all",schemaPath:"#/properties/all/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
}
}
}
}
else {
validate699.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate699.errors = vErrors;
return errors === 0;
}
validate699.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema158 = {"type":"object","additionalProperties":false,"required":["state"],"properties":{"state":{"$ref":"https://transit.invalid/generated-validator/128"}}};
const schema159 = {"type":"object","additionalProperties":false,"properties":{"column":{"$ref":"https://transit.invalid/generated-validator/9"},"value":{"$ref":"https://transit.invalid/generated-validator/127"}},"required":["column","value"]};
const schema160 = {"type":"string","enum":["missing","null","type_error","value","conflict"]};

function validate704(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate704.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate704.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
if(!(((((data === "missing") || (data === "null")) || (data === "type_error")) || (data === "value")) || (data === "conflict"))){
validate704.errors = [{instancePath,schemaPath:"#/enum",keyword:"enum",params:{allowedValues: schema160.enum},message:"must be equal to one of the allowed values"}];
return false;
}
validate704.errors = vErrors;
return errors === 0;
}
validate704.evaluated = {"dynamicProps":false,"dynamicItems":false};


function validate702(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate702.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if(((data.column === undefined) && (missing0 = "column")) || ((data.value === undefined) && (missing0 = "value"))){
validate702.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "column") || (key0 === "value"))){
validate702.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.column !== undefined){
const _errs2 = errors;
if(!(validate102(data.column, {instancePath:instancePath+"/column",parentData:data,parentDataProperty:"column",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate102.errors : vErrors.concat(validate102.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.value !== undefined){
const _errs3 = errors;
if(!(validate704(data.value, {instancePath:instancePath+"/value",parentData:data,parentDataProperty:"value",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate704.errors : vErrors.concat(validate704.errors);
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
validate702.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate702.errors = vErrors;
return errors === 0;
}
validate702.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate701(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate701.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((data.state === undefined) && (missing0 = "state")){
validate701.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(key0 === "state")){
validate701.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.state !== undefined){
if(!(validate702(data.state, {instancePath:instancePath+"/state",parentData:data,parentDataProperty:"state",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate702.errors : vErrors.concat(validate702.errors);
errors = vErrors.length;
}
}
}
}
}
else {
validate701.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate701.errors = vErrors;
return errors === 0;
}
validate701.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema161 = {"type":"object","additionalProperties":false,"required":["compare"],"properties":{"compare":{"$ref":"https://transit.invalid/generated-validator/131"}}};
const schema162 = {"type":"object","additionalProperties":false,"properties":{"column":{"$ref":"https://transit.invalid/generated-validator/9"},"op":{"$ref":"https://transit.invalid/generated-validator/130"},"value":{"$ref":"https://transit.invalid/generated-validator/102"}},"required":["column","op","value"]};
const schema163 = {"type":"string","enum":["eq","ne","lt","le","gt","ge"]};

function validate711(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate711.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate711.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
if(!((((((data === "eq") || (data === "ne")) || (data === "lt")) || (data === "le")) || (data === "gt")) || (data === "ge"))){
validate711.errors = [{instancePath,schemaPath:"#/enum",keyword:"enum",params:{allowedValues: schema163.enum},message:"must be equal to one of the allowed values"}];
return false;
}
validate711.errors = vErrors;
return errors === 0;
}
validate711.evaluated = {"dynamicProps":false,"dynamicItems":false};


function validate709(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate709.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((((data.column === undefined) && (missing0 = "column")) || ((data.op === undefined) && (missing0 = "op"))) || ((data.value === undefined) && (missing0 = "value"))){
validate709.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "column") || (key0 === "op")) || (key0 === "value"))){
validate709.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.column !== undefined){
const _errs2 = errors;
if(!(validate102(data.column, {instancePath:instancePath+"/column",parentData:data,parentDataProperty:"column",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate102.errors : vErrors.concat(validate102.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.op !== undefined){
const _errs3 = errors;
if(!(validate711(data.op, {instancePath:instancePath+"/op",parentData:data,parentDataProperty:"op",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate711.errors : vErrors.concat(validate711.errors);
errors = vErrors.length;
}
var valid0 = _errs3 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.value !== undefined){
const _errs4 = errors;
if(!(validate583(data.value, {instancePath:instancePath+"/value",parentData:data,parentDataProperty:"value",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate583.errors : vErrors.concat(validate583.errors);
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
validate709.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate709.errors = vErrors;
return errors === 0;
}
validate709.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate708(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate708.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((data.compare === undefined) && (missing0 = "compare")){
validate708.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(key0 === "compare")){
validate708.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.compare !== undefined){
if(!(validate709(data.compare, {instancePath:instancePath+"/compare",parentData:data,parentDataProperty:"compare",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate709.errors : vErrors.concat(validate709.errors);
errors = vErrors.length;
}
}
}
}
}
else {
validate708.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate708.errors = vErrors;
return errors === 0;
}
validate708.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema164 = {"type":"object","additionalProperties":false,"required":["negate"],"properties":{"negate":{"type":"object","maxProperties":0}}};

function validate719(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate719.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((data.negate === undefined) && (missing0 = "negate")){
validate719.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(key0 === "negate")){
validate719.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.negate !== undefined){
let data0 = data.negate;
const _errs2 = errors;
if(errors === _errs2){
if(data0 && typeof data0 == "object" && !Array.isArray(data0)){
if(Object.keys(data0).length > 0){
validate719.errors = [{instancePath:instancePath+"/negate",schemaPath:"#/properties/negate/maxProperties",keyword:"maxProperties",params:{limit: 0},message:"must NOT have more than 0 properties"}];
return false;
}
}
else {
validate719.errors = [{instancePath:instancePath+"/negate",schemaPath:"#/properties/negate/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
}
}
}
}
else {
validate719.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate719.errors = vErrors;
return errors === 0;
}
validate719.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema165 = {"type":"object","additionalProperties":false,"required":["conjunction"],"properties":{"conjunction":{"type":"object","maxProperties":0}}};

function validate721(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate721.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((data.conjunction === undefined) && (missing0 = "conjunction")){
validate721.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(key0 === "conjunction")){
validate721.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.conjunction !== undefined){
let data0 = data.conjunction;
const _errs2 = errors;
if(errors === _errs2){
if(data0 && typeof data0 == "object" && !Array.isArray(data0)){
if(Object.keys(data0).length > 0){
validate721.errors = [{instancePath:instancePath+"/conjunction",schemaPath:"#/properties/conjunction/maxProperties",keyword:"maxProperties",params:{limit: 0},message:"must NOT have more than 0 properties"}];
return false;
}
}
else {
validate721.errors = [{instancePath:instancePath+"/conjunction",schemaPath:"#/properties/conjunction/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
}
}
}
}
else {
validate721.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate721.errors = vErrors;
return errors === 0;
}
validate721.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema166 = {"type":"object","additionalProperties":false,"required":["disjunction"],"properties":{"disjunction":{"type":"object","maxProperties":0}}};

function validate723(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate723.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((data.disjunction === undefined) && (missing0 = "disjunction")){
validate723.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(key0 === "disjunction")){
validate723.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.disjunction !== undefined){
let data0 = data.disjunction;
const _errs2 = errors;
if(errors === _errs2){
if(data0 && typeof data0 == "object" && !Array.isArray(data0)){
if(Object.keys(data0).length > 0){
validate723.errors = [{instancePath:instancePath+"/disjunction",schemaPath:"#/properties/disjunction/maxProperties",keyword:"maxProperties",params:{limit: 0},message:"must NOT have more than 0 properties"}];
return false;
}
}
else {
validate723.errors = [{instancePath:instancePath+"/disjunction",schemaPath:"#/properties/disjunction/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
}
}
}
}
else {
validate723.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate723.errors = vErrors;
return errors === 0;
}
validate723.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema167 = {"type":"object","additionalProperties":false,"required":["state"],"properties":{"state":{"$ref":"https://transit.invalid/generated-validator/136"}}};
const schema168 = {"type":"object","additionalProperties":false,"properties":{"column":{"type":"string","maxLength":131072},"value":{"$ref":"https://transit.invalid/generated-validator/127"}},"required":["column","value"]};

function validate738(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate738.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if(((data.column === undefined) && (missing0 = "column")) || ((data.value === undefined) && (missing0 = "value"))){
validate738.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "column") || (key0 === "value"))){
validate738.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.column !== undefined){
let data0 = data.column;
const _errs2 = errors;
if(errors === _errs2){
if(typeof data0 === "string"){
if(func4(data0) > 131072){
validate738.errors = [{instancePath:instancePath+"/column",schemaPath:"#/properties/column/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"}];
return false;
}
}
else {
validate738.errors = [{instancePath:instancePath+"/column",schemaPath:"#/properties/column/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.value !== undefined){
const _errs4 = errors;
if(!(validate704(data.value, {instancePath:instancePath+"/value",parentData:data,parentDataProperty:"value",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate704.errors : vErrors.concat(validate704.errors);
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
else {
validate738.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate738.errors = vErrors;
return errors === 0;
}
validate738.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate737(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate737.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((data.state === undefined) && (missing0 = "state")){
validate737.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(key0 === "state")){
validate737.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.state !== undefined){
if(!(validate738(data.state, {instancePath:instancePath+"/state",parentData:data,parentDataProperty:"state",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate738.errors : vErrors.concat(validate738.errors);
errors = vErrors.length;
}
}
}
}
}
else {
validate737.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate737.errors = vErrors;
return errors === 0;
}
validate737.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema169 = {"type":"object","additionalProperties":false,"required":["compare"],"properties":{"compare":{"$ref":"https://transit.invalid/generated-validator/138"}}};
const schema170 = {"type":"object","additionalProperties":false,"properties":{"column":{"type":"string","maxLength":131072},"op":{"$ref":"https://transit.invalid/generated-validator/130"},"type":{"$ref":"https://transit.invalid/generated-validator/105"}},"required":["column","op","type"]};

function validate743(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate743.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((((data.column === undefined) && (missing0 = "column")) || ((data.op === undefined) && (missing0 = "op"))) || ((data.type === undefined) && (missing0 = "type"))){
validate743.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "column") || (key0 === "op")) || (key0 === "type"))){
validate743.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.column !== undefined){
let data0 = data.column;
const _errs2 = errors;
if(errors === _errs2){
if(typeof data0 === "string"){
if(func4(data0) > 131072){
validate743.errors = [{instancePath:instancePath+"/column",schemaPath:"#/properties/column/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"}];
return false;
}
}
else {
validate743.errors = [{instancePath:instancePath+"/column",schemaPath:"#/properties/column/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.op !== undefined){
const _errs4 = errors;
if(!(validate711(data.op, {instancePath:instancePath+"/op",parentData:data,parentDataProperty:"op",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate711.errors : vErrors.concat(validate711.errors);
errors = vErrors.length;
}
var valid0 = _errs4 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.type !== undefined){
const _errs5 = errors;
if(!(validate627(data.type, {instancePath:instancePath+"/type",parentData:data,parentDataProperty:"type",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate627.errors : vErrors.concat(validate627.errors);
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
else {
validate743.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate743.errors = vErrors;
return errors === 0;
}
validate743.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate742(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate742.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((data.compare === undefined) && (missing0 = "compare")){
validate742.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(key0 === "compare")){
validate742.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.compare !== undefined){
if(!(validate743(data.compare, {instancePath:instancePath+"/compare",parentData:data,parentDataProperty:"compare",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate743.errors : vErrors.concat(validate743.errors);
errors = vErrors.length;
}
}
}
}
}
else {
validate742.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate742.errors = vErrors;
return errors === 0;
}
validate742.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema171 = {"type":"object","additionalProperties":false,"required":["null"],"properties":{"null":{"type":"object","maxProperties":0}}};

function validate780(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate780.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((data.null === undefined) && (missing0 = "null")){
validate780.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(key0 === "null")){
validate780.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.null !== undefined){
let data0 = data.null;
const _errs2 = errors;
if(errors === _errs2){
if(data0 && typeof data0 == "object" && !Array.isArray(data0)){
if(Object.keys(data0).length > 0){
validate780.errors = [{instancePath:instancePath+"/null",schemaPath:"#/properties/null/maxProperties",keyword:"maxProperties",params:{limit: 0},message:"must NOT have more than 0 properties"}];
return false;
}
}
else {
validate780.errors = [{instancePath:instancePath+"/null",schemaPath:"#/properties/null/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
}
}
}
}
else {
validate780.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate780.errors = vErrors;
return errors === 0;
}
validate780.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema172 = {"type":"object","additionalProperties":false,"required":["type_error"],"properties":{"type_error":{"$ref":"https://transit.invalid/generated-validator/141"}}};
const schema173 = {"type":"string","enum":["unknown","int64","uint64","float64","boolean","utf8","binary","null_value","map","list","text","character"]};

function validate783(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate783.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate783.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
if(!((((((((((((data === "unknown") || (data === "int64")) || (data === "uint64")) || (data === "float64")) || (data === "boolean")) || (data === "utf8")) || (data === "binary")) || (data === "null_value")) || (data === "map")) || (data === "list")) || (data === "text")) || (data === "character"))){
validate783.errors = [{instancePath,schemaPath:"#/enum",keyword:"enum",params:{allowedValues: schema173.enum},message:"must be equal to one of the allowed values"}];
return false;
}
validate783.errors = vErrors;
return errors === 0;
}
validate783.evaluated = {"dynamicProps":false,"dynamicItems":false};


function validate782(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate782.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((data.type_error === undefined) && (missing0 = "type_error")){
validate782.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(key0 === "type_error")){
validate782.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.type_error !== undefined){
if(!(validate783(data.type_error, {instancePath:instancePath+"/type_error",parentData:data,parentDataProperty:"type_error",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate783.errors : vErrors.concat(validate783.errors);
errors = vErrors.length;
}
}
}
}
}
else {
validate782.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate782.errors = vErrors;
return errors === 0;
}
validate782.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema174 = {"type":"object","additionalProperties":false,"required":["value"],"properties":{"value":{"$ref":"https://transit.invalid/generated-validator/102"}}};

function validate786(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate786.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((data.value === undefined) && (missing0 = "value")){
validate786.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(key0 === "value")){
validate786.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.value !== undefined){
if(!(validate583(data.value, {instancePath:instancePath+"/value",parentData:data,parentDataProperty:"value",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate583.errors : vErrors.concat(validate583.errors);
errors = vErrors.length;
}
}
}
}
}
else {
validate786.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate786.errors = vErrors;
return errors === 0;
}
validate786.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate603(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate603.evaluated;
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
if(errors === _errs1){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((data.description === undefined) && (missing0 = "description")){
const err0 = {instancePath,schemaPath:"#/oneOf/0/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"};
if(vErrors === null){
vErrors = [err0];
}
else {
vErrors.push(err0);
}
errors++;
}
else {
const _errs3 = errors;
for(const key0 in data){
if(!(key0 === "description")){
const err1 = {instancePath,schemaPath:"#/oneOf/0/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"};
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
if(_errs3 === errors){
if(data.description !== undefined){
let data0 = data.description;
const _errs4 = errors;
if(errors === _errs4){
if(data0 && typeof data0 == "object" && !Array.isArray(data0)){
let missing1;
if(((((((data0.connection === undefined) && (missing1 = "connection")) || ((data0.name === undefined) && (missing1 = "name"))) || ((data0.source === undefined) && (missing1 = "source"))) || ((data0.sql === undefined) && (missing1 = "sql"))) || ((data0.budgets === undefined) && (missing1 = "budgets"))) || ((data0.columns === undefined) && (missing1 = "columns"))){
const err2 = {instancePath:instancePath+"/description",schemaPath:"#/oneOf/0/properties/description/required",keyword:"required",params:{missingProperty: missing1},message:"must have required property '"+missing1+"'"};
if(vErrors === null){
vErrors = [err2];
}
else {
vErrors.push(err2);
}
errors++;
}
else {
const _errs6 = errors;
for(const key1 in data0){
if(!((((((key1 === "connection") || (key1 === "name")) || (key1 === "source")) || (key1 === "sql")) || (key1 === "budgets")) || (key1 === "columns"))){
const err3 = {instancePath:instancePath+"/description",schemaPath:"#/oneOf/0/properties/description/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key1},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err3];
}
else {
vErrors.push(err3);
}
errors++;
break;
}
}
if(_errs6 === errors){
if(data0.connection !== undefined){
let data1 = data0.connection;
const _errs7 = errors;
if(errors === _errs7){
if(data1 && typeof data1 == "object" && !Array.isArray(data1)){
let missing2;
if(((((((data1.realm === undefined) && (missing2 = "realm")) || ((data1.principal === undefined) && (missing2 = "principal"))) || ((data1.source === undefined) && (missing2 = "source"))) || ((data1.resource === undefined) && (missing2 = "resource"))) || ((data1.requester === undefined) && (missing2 = "requester"))) || ((data1.requests === undefined) && (missing2 = "requests"))){
const err4 = {instancePath:instancePath+"/description/connection",schemaPath:"#/oneOf/0/properties/description/properties/connection/required",keyword:"required",params:{missingProperty: missing2},message:"must have required property '"+missing2+"'"};
if(vErrors === null){
vErrors = [err4];
}
else {
vErrors.push(err4);
}
errors++;
}
else {
const _errs9 = errors;
for(const key2 in data1){
if(!((((((key2 === "realm") || (key2 === "principal")) || (key2 === "source")) || (key2 === "resource")) || (key2 === "requester")) || (key2 === "requests"))){
const err5 = {instancePath:instancePath+"/description/connection",schemaPath:"#/oneOf/0/properties/description/properties/connection/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key2},message:"must NOT have additional properties"};
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
if(_errs9 === errors){
if(data1.realm !== undefined){
const _errs10 = errors;
if(!(validate55(data1.realm, {instancePath:instancePath+"/description/connection/realm",parentData:data1,parentDataProperty:"realm",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate55.errors : vErrors.concat(validate55.errors);
errors = vErrors.length;
}
var valid3 = _errs10 === errors;
}
else {
var valid3 = true;
}
if(valid3){
if(data1.principal !== undefined){
const _errs11 = errors;
if(!(validate55(data1.principal, {instancePath:instancePath+"/description/connection/principal",parentData:data1,parentDataProperty:"principal",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate55.errors : vErrors.concat(validate55.errors);
errors = vErrors.length;
}
var valid3 = _errs11 === errors;
}
else {
var valid3 = true;
}
if(valid3){
if(data1.source !== undefined){
const _errs12 = errors;
if(!(validate55(data1.source, {instancePath:instancePath+"/description/connection/source",parentData:data1,parentDataProperty:"source",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate55.errors : vErrors.concat(validate55.errors);
errors = vErrors.length;
}
var valid3 = _errs12 === errors;
}
else {
var valid3 = true;
}
if(valid3){
if(data1.resource !== undefined){
const _errs13 = errors;
if(!(validate55(data1.resource, {instancePath:instancePath+"/description/connection/resource",parentData:data1,parentDataProperty:"resource",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate55.errors : vErrors.concat(validate55.errors);
errors = vErrors.length;
}
var valid3 = _errs13 === errors;
}
else {
var valid3 = true;
}
if(valid3){
if(data1.requester !== undefined){
const _errs14 = errors;
if(!(validate55(data1.requester, {instancePath:instancePath+"/description/connection/requester",parentData:data1,parentDataProperty:"requester",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate55.errors : vErrors.concat(validate55.errors);
errors = vErrors.length;
}
var valid3 = _errs14 === errors;
}
else {
var valid3 = true;
}
if(valid3){
if(data1.requests !== undefined){
const _errs15 = errors;
if(!(validate55(data1.requests, {instancePath:instancePath+"/description/connection/requests",parentData:data1,parentDataProperty:"requests",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate55.errors : vErrors.concat(validate55.errors);
errors = vErrors.length;
}
var valid3 = _errs15 === errors;
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
}
else {
const err6 = {instancePath:instancePath+"/description/connection",schemaPath:"#/oneOf/0/properties/description/properties/connection/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err6];
}
else {
vErrors.push(err6);
}
errors++;
}
}
var valid2 = _errs7 === errors;
}
else {
var valid2 = true;
}
if(valid2){
if(data0.name !== undefined){
let data8 = data0.name;
const _errs16 = errors;
if(errors === _errs16){
if(typeof data8 === "string"){
if(func4(data8) > 131072){
const err7 = {instancePath:instancePath+"/description/name",schemaPath:"#/oneOf/0/properties/description/properties/name/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err7];
}
else {
vErrors.push(err7);
}
errors++;
}
}
else {
const err8 = {instancePath:instancePath+"/description/name",schemaPath:"#/oneOf/0/properties/description/properties/name/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err8];
}
else {
vErrors.push(err8);
}
errors++;
}
}
var valid2 = _errs16 === errors;
}
else {
var valid2 = true;
}
if(valid2){
if(data0.source !== undefined){
let data9 = data0.source;
const _errs18 = errors;
if(errors === _errs18){
if(data9 && typeof data9 == "object" && !Array.isArray(data9)){
let missing3;
if(((((((data9.capabilities === undefined) && (missing3 = "capabilities")) || ((data9.source === undefined) && (missing3 = "source"))) || ((data9.resource_revision === undefined) && (missing3 = "resource_revision"))) || ((data9.policy_revision === undefined) && (missing3 = "policy_revision"))) || ((data9.limits === undefined) && (missing3 = "limits"))) || ((data9.active === undefined) && (missing3 = "active"))){
const err9 = {instancePath:instancePath+"/description/source",schemaPath:"#/oneOf/0/properties/description/properties/source/required",keyword:"required",params:{missingProperty: missing3},message:"must have required property '"+missing3+"'"};
if(vErrors === null){
vErrors = [err9];
}
else {
vErrors.push(err9);
}
errors++;
}
else {
const _errs20 = errors;
for(const key3 in data9){
if(!((((((key3 === "capabilities") || (key3 === "source")) || (key3 === "resource_revision")) || (key3 === "policy_revision")) || (key3 === "limits")) || (key3 === "active"))){
const err10 = {instancePath:instancePath+"/description/source",schemaPath:"#/oneOf/0/properties/description/properties/source/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key3},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err10];
}
else {
vErrors.push(err10);
}
errors++;
break;
}
}
if(_errs20 === errors){
if(data9.capabilities !== undefined){
let data10 = data9.capabilities;
const _errs21 = errors;
if(errors === _errs21){
if(data10 && typeof data10 == "object" && !Array.isArray(data10)){
let missing4;
if(((((((((((((data10.version === undefined) && (missing4 = "version")) || ((data10.source === undefined) && (missing4 = "source"))) || ((data10.plan === undefined) && (missing4 = "plan"))) || ((data10.result === undefined) && (missing4 = "result"))) || ((data10.bundle_bytes === undefined) && (missing4 = "bundle_bytes"))) || ((data10.part_bytes === undefined) && (missing4 = "part_bytes"))) || ((data10.segment_bytes === undefined) && (missing4 = "segment_bytes"))) || ((data10.batch_rows === undefined) && (missing4 = "batch_rows"))) || ((data10.columns === undefined) && (missing4 = "columns"))) || ((data10.kv === undefined) && (missing4 = "kv"))) || ((data10.table === undefined) && (missing4 = "table"))) || ((data10.document === undefined) && (missing4 = "document"))){
const err11 = {instancePath:instancePath+"/description/source/capabilities",schemaPath:"#/oneOf/0/properties/description/properties/source/properties/capabilities/required",keyword:"required",params:{missingProperty: missing4},message:"must have required property '"+missing4+"'"};
if(vErrors === null){
vErrors = [err11];
}
else {
vErrors.push(err11);
}
errors++;
}
else {
const _errs23 = errors;
for(const key4 in data10){
if(!(func1.call(schema135.oneOf[0].properties.description.properties.source.properties.capabilities.properties, key4))){
const err12 = {instancePath:instancePath+"/description/source/capabilities",schemaPath:"#/oneOf/0/properties/description/properties/source/properties/capabilities/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key4},message:"must NOT have additional properties"};
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
if(_errs23 === errors){
if(data10.version !== undefined){
const _errs24 = errors;
if(!(validate102(data10.version, {instancePath:instancePath+"/description/source/capabilities/version",parentData:data10,parentDataProperty:"version",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate102.errors : vErrors.concat(validate102.errors);
errors = vErrors.length;
}
var valid5 = _errs24 === errors;
}
else {
var valid5 = true;
}
if(valid5){
if(data10.source !== undefined){
const _errs25 = errors;
if(!(validate102(data10.source, {instancePath:instancePath+"/description/source/capabilities/source",parentData:data10,parentDataProperty:"source",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate102.errors : vErrors.concat(validate102.errors);
errors = vErrors.length;
}
var valid5 = _errs25 === errors;
}
else {
var valid5 = true;
}
if(valid5){
if(data10.plan !== undefined){
const _errs26 = errors;
if(!(validate102(data10.plan, {instancePath:instancePath+"/description/source/capabilities/plan",parentData:data10,parentDataProperty:"plan",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate102.errors : vErrors.concat(validate102.errors);
errors = vErrors.length;
}
var valid5 = _errs26 === errors;
}
else {
var valid5 = true;
}
if(valid5){
if(data10.result !== undefined){
const _errs27 = errors;
if(!(validate102(data10.result, {instancePath:instancePath+"/description/source/capabilities/result",parentData:data10,parentDataProperty:"result",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate102.errors : vErrors.concat(validate102.errors);
errors = vErrors.length;
}
var valid5 = _errs27 === errors;
}
else {
var valid5 = true;
}
if(valid5){
if(data10.bundle_bytes !== undefined){
const _errs28 = errors;
if(!(validate53(data10.bundle_bytes, {instancePath:instancePath+"/description/source/capabilities/bundle_bytes",parentData:data10,parentDataProperty:"bundle_bytes",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate53.errors : vErrors.concat(validate53.errors);
errors = vErrors.length;
}
var valid5 = _errs28 === errors;
}
else {
var valid5 = true;
}
if(valid5){
if(data10.part_bytes !== undefined){
const _errs29 = errors;
if(!(validate67(data10.part_bytes, {instancePath:instancePath+"/description/source/capabilities/part_bytes",parentData:data10,parentDataProperty:"part_bytes",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate67.errors : vErrors.concat(validate67.errors);
errors = vErrors.length;
}
var valid5 = _errs29 === errors;
}
else {
var valid5 = true;
}
if(valid5){
if(data10.segment_bytes !== undefined){
const _errs30 = errors;
if(!(validate53(data10.segment_bytes, {instancePath:instancePath+"/description/source/capabilities/segment_bytes",parentData:data10,parentDataProperty:"segment_bytes",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate53.errors : vErrors.concat(validate53.errors);
errors = vErrors.length;
}
var valid5 = _errs30 === errors;
}
else {
var valid5 = true;
}
if(valid5){
if(data10.batch_rows !== undefined){
const _errs31 = errors;
if(!(validate102(data10.batch_rows, {instancePath:instancePath+"/description/source/capabilities/batch_rows",parentData:data10,parentDataProperty:"batch_rows",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate102.errors : vErrors.concat(validate102.errors);
errors = vErrors.length;
}
var valid5 = _errs31 === errors;
}
else {
var valid5 = true;
}
if(valid5){
if(data10.columns !== undefined){
const _errs32 = errors;
if(!(validate102(data10.columns, {instancePath:instancePath+"/description/source/capabilities/columns",parentData:data10,parentDataProperty:"columns",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate102.errors : vErrors.concat(validate102.errors);
errors = vErrors.length;
}
var valid5 = _errs32 === errors;
}
else {
var valid5 = true;
}
if(valid5){
if(data10.kv !== undefined){
const _errs33 = errors;
if(typeof data10.kv !== "boolean"){
const err13 = {instancePath:instancePath+"/description/source/capabilities/kv",schemaPath:"#/oneOf/0/properties/description/properties/source/properties/capabilities/properties/kv/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"};
if(vErrors === null){
vErrors = [err13];
}
else {
vErrors.push(err13);
}
errors++;
}
var valid5 = _errs33 === errors;
}
else {
var valid5 = true;
}
if(valid5){
if(data10.table !== undefined){
const _errs35 = errors;
if(typeof data10.table !== "boolean"){
const err14 = {instancePath:instancePath+"/description/source/capabilities/table",schemaPath:"#/oneOf/0/properties/description/properties/source/properties/capabilities/properties/table/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"};
if(vErrors === null){
vErrors = [err14];
}
else {
vErrors.push(err14);
}
errors++;
}
var valid5 = _errs35 === errors;
}
else {
var valid5 = true;
}
if(valid5){
if(data10.document !== undefined){
const _errs37 = errors;
if(typeof data10.document !== "boolean"){
const err15 = {instancePath:instancePath+"/description/source/capabilities/document",schemaPath:"#/oneOf/0/properties/description/properties/source/properties/capabilities/properties/document/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"};
if(vErrors === null){
vErrors = [err15];
}
else {
vErrors.push(err15);
}
errors++;
}
var valid5 = _errs37 === errors;
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
}
}
}
}
}
}
}
}
else {
const err16 = {instancePath:instancePath+"/description/source/capabilities",schemaPath:"#/oneOf/0/properties/description/properties/source/properties/capabilities/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err16];
}
else {
vErrors.push(err16);
}
errors++;
}
}
var valid4 = _errs21 === errors;
}
else {
var valid4 = true;
}
if(valid4){
if(data9.source !== undefined){
const _errs39 = errors;
if(!(validate619(data9.source, {instancePath:instancePath+"/description/source/source",parentData:data9,parentDataProperty:"source",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate619.errors : vErrors.concat(validate619.errors);
errors = vErrors.length;
}
var valid4 = _errs39 === errors;
}
else {
var valid4 = true;
}
if(valid4){
if(data9.resource_revision !== undefined){
const _errs40 = errors;
if(!(validate55(data9.resource_revision, {instancePath:instancePath+"/description/source/resource_revision",parentData:data9,parentDataProperty:"resource_revision",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate55.errors : vErrors.concat(validate55.errors);
errors = vErrors.length;
}
var valid4 = _errs40 === errors;
}
else {
var valid4 = true;
}
if(valid4){
if(data9.policy_revision !== undefined){
let data25 = data9.policy_revision;
const _errs41 = errors;
if(errors === _errs41){
if(typeof data25 === "string"){
if(func4(data25) > 131072){
const err17 = {instancePath:instancePath+"/description/source/policy_revision",schemaPath:"#/oneOf/0/properties/description/properties/source/properties/policy_revision/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err17];
}
else {
vErrors.push(err17);
}
errors++;
}
}
else {
const err18 = {instancePath:instancePath+"/description/source/policy_revision",schemaPath:"#/oneOf/0/properties/description/properties/source/properties/policy_revision/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err18];
}
else {
vErrors.push(err18);
}
errors++;
}
}
var valid4 = _errs41 === errors;
}
else {
var valid4 = true;
}
if(valid4){
if(data9.limits !== undefined){
const _errs43 = errors;
if(!(validate669(data9.limits, {instancePath:instancePath+"/description/source/limits",parentData:data9,parentDataProperty:"limits",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate669.errors : vErrors.concat(validate669.errors);
errors = vErrors.length;
}
var valid4 = _errs43 === errors;
}
else {
var valid4 = true;
}
if(valid4){
if(data9.active !== undefined){
const _errs44 = errors;
if(!(validate597(data9.active, {instancePath:instancePath+"/description/source/active",parentData:data9,parentDataProperty:"active",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate597.errors : vErrors.concat(validate597.errors);
errors = vErrors.length;
}
var valid4 = _errs44 === errors;
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
else {
const err19 = {instancePath:instancePath+"/description/source",schemaPath:"#/oneOf/0/properties/description/properties/source/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err19];
}
else {
vErrors.push(err19);
}
errors++;
}
}
var valid2 = _errs18 === errors;
}
else {
var valid2 = true;
}
if(valid2){
if(data0.sql !== undefined){
let data28 = data0.sql;
const _errs45 = errors;
if(errors === _errs45){
if(data28 && typeof data28 == "object" && !Array.isArray(data28)){
let missing5;
if((((((((((((data28.version === undefined) && (missing5 = "version")) || ((data28.statement_bytes === undefined) && (missing5 = "statement_bytes"))) || ((data28.named_columns === undefined) && (missing5 = "named_columns"))) || ((data28.star_columns === undefined) && (missing5 = "star_columns"))) || ((data28.uint64_limits === undefined) && (missing5 = "uint64_limits"))) || ((data28.uint64_literals === undefined) && (missing5 = "uint64_literals"))) || ((data28.float64_literals === undefined) && (missing5 = "float64_literals"))) || ((data28.null_comparison === undefined) && (missing5 = "null_comparison"))) || ((data28.explicit_null_test === undefined) && (missing5 = "explicit_null_test"))) || ((data28.writes === undefined) && (missing5 = "writes"))) || ((data28.continuous === undefined) && (missing5 = "continuous"))){
const err20 = {instancePath:instancePath+"/description/sql",schemaPath:"#/oneOf/0/properties/description/properties/sql/required",keyword:"required",params:{missingProperty: missing5},message:"must have required property '"+missing5+"'"};
if(vErrors === null){
vErrors = [err20];
}
else {
vErrors.push(err20);
}
errors++;
}
else {
const _errs47 = errors;
for(const key5 in data28){
if(!(func1.call(schema135.oneOf[0].properties.description.properties.sql.properties, key5))){
const err21 = {instancePath:instancePath+"/description/sql",schemaPath:"#/oneOf/0/properties/description/properties/sql/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key5},message:"must NOT have additional properties"};
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
if(_errs47 === errors){
if(data28.version !== undefined){
const _errs48 = errors;
if(!(validate102(data28.version, {instancePath:instancePath+"/description/sql/version",parentData:data28,parentDataProperty:"version",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate102.errors : vErrors.concat(validate102.errors);
errors = vErrors.length;
}
var valid6 = _errs48 === errors;
}
else {
var valid6 = true;
}
if(valid6){
if(data28.statement_bytes !== undefined){
const _errs49 = errors;
if(!(validate53(data28.statement_bytes, {instancePath:instancePath+"/description/sql/statement_bytes",parentData:data28,parentDataProperty:"statement_bytes",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate53.errors : vErrors.concat(validate53.errors);
errors = vErrors.length;
}
var valid6 = _errs49 === errors;
}
else {
var valid6 = true;
}
if(valid6){
if(data28.named_columns !== undefined){
const _errs50 = errors;
if(!(validate102(data28.named_columns, {instancePath:instancePath+"/description/sql/named_columns",parentData:data28,parentDataProperty:"named_columns",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate102.errors : vErrors.concat(validate102.errors);
errors = vErrors.length;
}
var valid6 = _errs50 === errors;
}
else {
var valid6 = true;
}
if(valid6){
if(data28.star_columns !== undefined){
const _errs51 = errors;
if(!(validate102(data28.star_columns, {instancePath:instancePath+"/description/sql/star_columns",parentData:data28,parentDataProperty:"star_columns",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate102.errors : vErrors.concat(validate102.errors);
errors = vErrors.length;
}
var valid6 = _errs51 === errors;
}
else {
var valid6 = true;
}
if(valid6){
if(data28.uint64_limits !== undefined){
const _errs52 = errors;
if(typeof data28.uint64_limits !== "boolean"){
const err22 = {instancePath:instancePath+"/description/sql/uint64_limits",schemaPath:"#/oneOf/0/properties/description/properties/sql/properties/uint64_limits/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"};
if(vErrors === null){
vErrors = [err22];
}
else {
vErrors.push(err22);
}
errors++;
}
var valid6 = _errs52 === errors;
}
else {
var valid6 = true;
}
if(valid6){
if(data28.uint64_literals !== undefined){
const _errs54 = errors;
if(typeof data28.uint64_literals !== "boolean"){
const err23 = {instancePath:instancePath+"/description/sql/uint64_literals",schemaPath:"#/oneOf/0/properties/description/properties/sql/properties/uint64_literals/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"};
if(vErrors === null){
vErrors = [err23];
}
else {
vErrors.push(err23);
}
errors++;
}
var valid6 = _errs54 === errors;
}
else {
var valid6 = true;
}
if(valid6){
if(data28.float64_literals !== undefined){
const _errs56 = errors;
if(typeof data28.float64_literals !== "boolean"){
const err24 = {instancePath:instancePath+"/description/sql/float64_literals",schemaPath:"#/oneOf/0/properties/description/properties/sql/properties/float64_literals/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"};
if(vErrors === null){
vErrors = [err24];
}
else {
vErrors.push(err24);
}
errors++;
}
var valid6 = _errs56 === errors;
}
else {
var valid6 = true;
}
if(valid6){
if(data28.null_comparison !== undefined){
const _errs58 = errors;
if(typeof data28.null_comparison !== "boolean"){
const err25 = {instancePath:instancePath+"/description/sql/null_comparison",schemaPath:"#/oneOf/0/properties/description/properties/sql/properties/null_comparison/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"};
if(vErrors === null){
vErrors = [err25];
}
else {
vErrors.push(err25);
}
errors++;
}
var valid6 = _errs58 === errors;
}
else {
var valid6 = true;
}
if(valid6){
if(data28.explicit_null_test !== undefined){
const _errs60 = errors;
if(typeof data28.explicit_null_test !== "boolean"){
const err26 = {instancePath:instancePath+"/description/sql/explicit_null_test",schemaPath:"#/oneOf/0/properties/description/properties/sql/properties/explicit_null_test/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"};
if(vErrors === null){
vErrors = [err26];
}
else {
vErrors.push(err26);
}
errors++;
}
var valid6 = _errs60 === errors;
}
else {
var valid6 = true;
}
if(valid6){
if(data28.writes !== undefined){
const _errs62 = errors;
if(typeof data28.writes !== "boolean"){
const err27 = {instancePath:instancePath+"/description/sql/writes",schemaPath:"#/oneOf/0/properties/description/properties/sql/properties/writes/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"};
if(vErrors === null){
vErrors = [err27];
}
else {
vErrors.push(err27);
}
errors++;
}
var valid6 = _errs62 === errors;
}
else {
var valid6 = true;
}
if(valid6){
if(data28.continuous !== undefined){
const _errs64 = errors;
if(typeof data28.continuous !== "boolean"){
const err28 = {instancePath:instancePath+"/description/sql/continuous",schemaPath:"#/oneOf/0/properties/description/properties/sql/properties/continuous/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"};
if(vErrors === null){
vErrors = [err28];
}
else {
vErrors.push(err28);
}
errors++;
}
var valid6 = _errs64 === errors;
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
}
}
else {
const err29 = {instancePath:instancePath+"/description/sql",schemaPath:"#/oneOf/0/properties/description/properties/sql/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err29];
}
else {
vErrors.push(err29);
}
errors++;
}
}
var valid2 = _errs45 === errors;
}
else {
var valid2 = true;
}
if(valid2){
if(data0.budgets !== undefined){
const _errs66 = errors;
if(!(validate669(data0.budgets, {instancePath:instancePath+"/description/budgets",parentData:data0,parentDataProperty:"budgets",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate669.errors : vErrors.concat(validate669.errors);
errors = vErrors.length;
}
var valid2 = _errs66 === errors;
}
else {
var valid2 = true;
}
if(valid2){
if(data0.columns !== undefined){
const _errs67 = errors;
if(!(validate677(data0.columns, {instancePath:instancePath+"/description/columns",parentData:data0,parentDataProperty:"columns",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate677.errors : vErrors.concat(validate677.errors);
errors = vErrors.length;
}
var valid2 = _errs67 === errors;
}
else {
var valid2 = true;
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
const err30 = {instancePath:instancePath+"/description",schemaPath:"#/oneOf/0/properties/description/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
}
else {
const err31 = {instancePath,schemaPath:"#/oneOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err31];
}
else {
vErrors.push(err31);
}
errors++;
}
}
var _valid0 = _errs1 === errors;
if(_valid0){
valid0 = true;
passing0 = 0;
var props0 = true;
}
const _errs68 = errors;
if(errors === _errs68){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing6;
if((data.sql_capabilities === undefined) && (missing6 = "sql_capabilities")){
const err32 = {instancePath,schemaPath:"#/oneOf/1/required",keyword:"required",params:{missingProperty: missing6},message:"must have required property '"+missing6+"'"};
if(vErrors === null){
vErrors = [err32];
}
else {
vErrors.push(err32);
}
errors++;
}
else {
const _errs70 = errors;
for(const key6 in data){
if(!(key6 === "sql_capabilities")){
const err33 = {instancePath,schemaPath:"#/oneOf/1/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key6},message:"must NOT have additional properties"};
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
if(_errs70 === errors){
if(data.sql_capabilities !== undefined){
let data42 = data.sql_capabilities;
const _errs71 = errors;
if(errors === _errs71){
if(data42 && typeof data42 == "object" && !Array.isArray(data42)){
let missing7;
if(((((data42.version === undefined) && (missing7 = "version")) || ((data42.parameters === undefined) && (missing7 = "parameters"))) || ((data42.max_parameters === undefined) && (missing7 = "max_parameters"))) || ((data42.statement_bytes === undefined) && (missing7 = "statement_bytes"))){
const err34 = {instancePath:instancePath+"/sql_capabilities",schemaPath:"#/oneOf/1/properties/sql_capabilities/required",keyword:"required",params:{missingProperty: missing7},message:"must have required property '"+missing7+"'"};
if(vErrors === null){
vErrors = [err34];
}
else {
vErrors.push(err34);
}
errors++;
}
else {
const _errs73 = errors;
for(const key7 in data42){
if(!((((key7 === "version") || (key7 === "parameters")) || (key7 === "max_parameters")) || (key7 === "statement_bytes"))){
const err35 = {instancePath:instancePath+"/sql_capabilities",schemaPath:"#/oneOf/1/properties/sql_capabilities/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key7},message:"must NOT have additional properties"};
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
if(_errs73 === errors){
if(data42.version !== undefined){
const _errs74 = errors;
if(!(validate102(data42.version, {instancePath:instancePath+"/sql_capabilities/version",parentData:data42,parentDataProperty:"version",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate102.errors : vErrors.concat(validate102.errors);
errors = vErrors.length;
}
var valid8 = _errs74 === errors;
}
else {
var valid8 = true;
}
if(valid8){
if(data42.parameters !== undefined){
const _errs75 = errors;
if(typeof data42.parameters !== "boolean"){
const err36 = {instancePath:instancePath+"/sql_capabilities/parameters",schemaPath:"#/oneOf/1/properties/sql_capabilities/properties/parameters/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"};
if(vErrors === null){
vErrors = [err36];
}
else {
vErrors.push(err36);
}
errors++;
}
var valid8 = _errs75 === errors;
}
else {
var valid8 = true;
}
if(valid8){
if(data42.max_parameters !== undefined){
const _errs77 = errors;
if(!(validate102(data42.max_parameters, {instancePath:instancePath+"/sql_capabilities/max_parameters",parentData:data42,parentDataProperty:"max_parameters",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate102.errors : vErrors.concat(validate102.errors);
errors = vErrors.length;
}
var valid8 = _errs77 === errors;
}
else {
var valid8 = true;
}
if(valid8){
if(data42.statement_bytes !== undefined){
const _errs78 = errors;
if(!(validate53(data42.statement_bytes, {instancePath:instancePath+"/sql_capabilities/statement_bytes",parentData:data42,parentDataProperty:"statement_bytes",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate53.errors : vErrors.concat(validate53.errors);
errors = vErrors.length;
}
var valid8 = _errs78 === errors;
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
else {
const err37 = {instancePath:instancePath+"/sql_capabilities",schemaPath:"#/oneOf/1/properties/sql_capabilities/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err37];
}
else {
vErrors.push(err37);
}
errors++;
}
}
}
}
}
}
else {
const err38 = {instancePath,schemaPath:"#/oneOf/1/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err38];
}
else {
vErrors.push(err38);
}
errors++;
}
}
var _valid0 = _errs68 === errors;
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
const _errs79 = errors;
if(errors === _errs79){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing8;
if((data.suggestions === undefined) && (missing8 = "suggestions")){
const err39 = {instancePath,schemaPath:"#/oneOf/2/required",keyword:"required",params:{missingProperty: missing8},message:"must have required property '"+missing8+"'"};
if(vErrors === null){
vErrors = [err39];
}
else {
vErrors.push(err39);
}
errors++;
}
else {
const _errs81 = errors;
for(const key8 in data){
if(!(key8 === "suggestions")){
const err40 = {instancePath,schemaPath:"#/oneOf/2/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key8},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err40];
}
else {
vErrors.push(err40);
}
errors++;
break;
}
}
if(_errs81 === errors){
if(data.suggestions !== undefined){
let data47 = data.suggestions;
const _errs82 = errors;
if(errors === _errs82){
if(data47 && typeof data47 == "object" && !Array.isArray(data47)){
let missing9;
if((((data47.resource === undefined) && (missing9 = "resource")) || ((data47.contract === undefined) && (missing9 = "contract"))) || ((data47.items === undefined) && (missing9 = "items"))){
const err41 = {instancePath:instancePath+"/suggestions",schemaPath:"#/oneOf/2/properties/suggestions/required",keyword:"required",params:{missingProperty: missing9},message:"must have required property '"+missing9+"'"};
if(vErrors === null){
vErrors = [err41];
}
else {
vErrors.push(err41);
}
errors++;
}
else {
const _errs84 = errors;
for(const key9 in data47){
if(!(((key9 === "resource") || (key9 === "contract")) || (key9 === "items"))){
const err42 = {instancePath:instancePath+"/suggestions",schemaPath:"#/oneOf/2/properties/suggestions/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key9},message:"must NOT have additional properties"};
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
if(_errs84 === errors){
if(data47.resource !== undefined){
const _errs85 = errors;
if(!(validate55(data47.resource, {instancePath:instancePath+"/suggestions/resource",parentData:data47,parentDataProperty:"resource",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate55.errors : vErrors.concat(validate55.errors);
errors = vErrors.length;
}
var valid10 = _errs85 === errors;
}
else {
var valid10 = true;
}
if(valid10){
if(data47.contract !== undefined){
const _errs86 = errors;
if(!(validate105(data47.contract, {instancePath:instancePath+"/suggestions/contract",parentData:data47,parentDataProperty:"contract",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate105.errors : vErrors.concat(validate105.errors);
errors = vErrors.length;
}
var valid10 = _errs86 === errors;
}
else {
var valid10 = true;
}
if(valid10){
if(data47.items !== undefined){
let data50 = data47.items;
const _errs87 = errors;
if(errors === _errs87){
if(Array.isArray(data50)){
if(data50.length > 8){
const err43 = {instancePath:instancePath+"/suggestions/items",schemaPath:"#/oneOf/2/properties/suggestions/properties/items/maxItems",keyword:"maxItems",params:{limit: 8},message:"must NOT have more than 8 items"};
if(vErrors === null){
vErrors = [err43];
}
else {
vErrors.push(err43);
}
errors++;
}
else {
var valid11 = true;
const len0 = data50.length;
for(let i0=0; i0<len0; i0++){
let data51 = data50[i0];
const _errs89 = errors;
if(errors === _errs89){
if(data51 && typeof data51 == "object" && !Array.isArray(data51)){
let missing10;
if(((data51.label === undefined) && (missing10 = "label")) || ((data51.sql === undefined) && (missing10 = "sql"))){
const err44 = {instancePath:instancePath+"/suggestions/items/" + i0,schemaPath:"#/oneOf/2/properties/suggestions/properties/items/items/required",keyword:"required",params:{missingProperty: missing10},message:"must have required property '"+missing10+"'"};
if(vErrors === null){
vErrors = [err44];
}
else {
vErrors.push(err44);
}
errors++;
}
else {
const _errs91 = errors;
for(const key10 in data51){
if(!((key10 === "label") || (key10 === "sql"))){
const err45 = {instancePath:instancePath+"/suggestions/items/" + i0,schemaPath:"#/oneOf/2/properties/suggestions/properties/items/items/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key10},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err45];
}
else {
vErrors.push(err45);
}
errors++;
break;
}
}
if(_errs91 === errors){
if(data51.label !== undefined){
let data52 = data51.label;
const _errs92 = errors;
if(errors === _errs92){
if(typeof data52 === "string"){
if(func4(data52) > 131072){
const err46 = {instancePath:instancePath+"/suggestions/items/" + i0+"/label",schemaPath:"#/oneOf/2/properties/suggestions/properties/items/items/properties/label/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err46];
}
else {
vErrors.push(err46);
}
errors++;
}
}
else {
const err47 = {instancePath:instancePath+"/suggestions/items/" + i0+"/label",schemaPath:"#/oneOf/2/properties/suggestions/properties/items/items/properties/label/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err47];
}
else {
vErrors.push(err47);
}
errors++;
}
}
var valid12 = _errs92 === errors;
}
else {
var valid12 = true;
}
if(valid12){
if(data51.sql !== undefined){
let data53 = data51.sql;
const _errs94 = errors;
if(errors === _errs94){
if(typeof data53 === "string"){
if(func4(data53) > 131072){
const err48 = {instancePath:instancePath+"/suggestions/items/" + i0+"/sql",schemaPath:"#/oneOf/2/properties/suggestions/properties/items/items/properties/sql/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err48];
}
else {
vErrors.push(err48);
}
errors++;
}
}
else {
const err49 = {instancePath:instancePath+"/suggestions/items/" + i0+"/sql",schemaPath:"#/oneOf/2/properties/suggestions/properties/items/items/properties/sql/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err49];
}
else {
vErrors.push(err49);
}
errors++;
}
}
var valid12 = _errs94 === errors;
}
else {
var valid12 = true;
}
}
}
}
}
else {
const err50 = {instancePath:instancePath+"/suggestions/items/" + i0,schemaPath:"#/oneOf/2/properties/suggestions/properties/items/items/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err50];
}
else {
vErrors.push(err50);
}
errors++;
}
}
var valid11 = _errs89 === errors;
if(!valid11){
break;
}
}
}
}
else {
const err51 = {instancePath:instancePath+"/suggestions/items",schemaPath:"#/oneOf/2/properties/suggestions/properties/items/type",keyword:"type",params:{type: "array"},message:"must be array"};
if(vErrors === null){
vErrors = [err51];
}
else {
vErrors.push(err51);
}
errors++;
}
}
var valid10 = _errs87 === errors;
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
const err52 = {instancePath:instancePath+"/suggestions",schemaPath:"#/oneOf/2/properties/suggestions/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
}
}
else {
const err53 = {instancePath,schemaPath:"#/oneOf/2/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err53];
}
else {
vErrors.push(err53);
}
errors++;
}
}
var _valid0 = _errs79 === errors;
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
const _errs96 = errors;
if(errors === _errs96){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing11;
if((data.assistance === undefined) && (missing11 = "assistance")){
const err54 = {instancePath,schemaPath:"#/oneOf/3/required",keyword:"required",params:{missingProperty: missing11},message:"must have required property '"+missing11+"'"};
if(vErrors === null){
vErrors = [err54];
}
else {
vErrors.push(err54);
}
errors++;
}
else {
const _errs98 = errors;
for(const key11 in data){
if(!(key11 === "assistance")){
const err55 = {instancePath,schemaPath:"#/oneOf/3/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key11},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err55];
}
else {
vErrors.push(err55);
}
errors++;
break;
}
}
if(_errs98 === errors){
if(data.assistance !== undefined){
let data54 = data.assistance;
const _errs99 = errors;
if(errors === _errs99){
if(data54 && typeof data54 == "object" && !Array.isArray(data54)){
let missing12;
if((((((((((data54.version === undefined) && (missing12 = "version")) || ((data54.generation === undefined) && (missing12 = "generation"))) || ((data54.profile === undefined) && (missing12 = "profile"))) || ((data54.resource === undefined) && (missing12 = "resource"))) || ((data54.contract === undefined) && (missing12 = "contract"))) || ((data54.resource_revision === undefined) && (missing12 = "resource_revision"))) || ((data54.policy_revision === undefined) && (missing12 = "policy_revision"))) || ((data54.range === undefined) && (missing12 = "range"))) || ((data54.items === undefined) && (missing12 = "items"))){
const err56 = {instancePath:instancePath+"/assistance",schemaPath:"#/oneOf/3/properties/assistance/required",keyword:"required",params:{missingProperty: missing12},message:"must have required property '"+missing12+"'"};
if(vErrors === null){
vErrors = [err56];
}
else {
vErrors.push(err56);
}
errors++;
}
else {
const _errs101 = errors;
for(const key12 in data54){
if(!(func1.call(schema135.oneOf[3].properties.assistance.properties, key12))){
const err57 = {instancePath:instancePath+"/assistance",schemaPath:"#/oneOf/3/properties/assistance/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key12},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err57];
}
else {
vErrors.push(err57);
}
errors++;
break;
}
}
if(_errs101 === errors){
if(data54.version !== undefined){
const _errs102 = errors;
if(!(validate102(data54.version, {instancePath:instancePath+"/assistance/version",parentData:data54,parentDataProperty:"version",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate102.errors : vErrors.concat(validate102.errors);
errors = vErrors.length;
}
var valid14 = _errs102 === errors;
}
else {
var valid14 = true;
}
if(valid14){
if(data54.generation !== undefined){
const _errs103 = errors;
if(!(validate53(data54.generation, {instancePath:instancePath+"/assistance/generation",parentData:data54,parentDataProperty:"generation",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate53.errors : vErrors.concat(validate53.errors);
errors = vErrors.length;
}
var valid14 = _errs103 === errors;
}
else {
var valid14 = true;
}
if(valid14){
if(data54.profile !== undefined){
let data57 = data54.profile;
const _errs104 = errors;
if(typeof data57 !== "string"){
const err58 = {instancePath:instancePath+"/assistance/profile",schemaPath:"#/oneOf/3/properties/assistance/properties/profile/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err58];
}
else {
vErrors.push(err58);
}
errors++;
}
if(!((data57 === "unified_v1") || (data57 === "catalog_v1"))){
const err59 = {instancePath:instancePath+"/assistance/profile",schemaPath:"#/oneOf/3/properties/assistance/properties/profile/enum",keyword:"enum",params:{allowedValues: schema135.oneOf[3].properties.assistance.properties.profile.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err59];
}
else {
vErrors.push(err59);
}
errors++;
}
var valid14 = _errs104 === errors;
}
else {
var valid14 = true;
}
if(valid14){
if(data54.resource !== undefined){
const _errs106 = errors;
if(!(validate55(data54.resource, {instancePath:instancePath+"/assistance/resource",parentData:data54,parentDataProperty:"resource",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate55.errors : vErrors.concat(validate55.errors);
errors = vErrors.length;
}
var valid14 = _errs106 === errors;
}
else {
var valid14 = true;
}
if(valid14){
if(data54.contract !== undefined){
const _errs107 = errors;
if(!(validate105(data54.contract, {instancePath:instancePath+"/assistance/contract",parentData:data54,parentDataProperty:"contract",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate105.errors : vErrors.concat(validate105.errors);
errors = vErrors.length;
}
var valid14 = _errs107 === errors;
}
else {
var valid14 = true;
}
if(valid14){
if(data54.resource_revision !== undefined){
const _errs108 = errors;
if(!(validate55(data54.resource_revision, {instancePath:instancePath+"/assistance/resource_revision",parentData:data54,parentDataProperty:"resource_revision",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate55.errors : vErrors.concat(validate55.errors);
errors = vErrors.length;
}
var valid14 = _errs108 === errors;
}
else {
var valid14 = true;
}
if(valid14){
if(data54.policy_revision !== undefined){
let data61 = data54.policy_revision;
const _errs109 = errors;
if(errors === _errs109){
if(typeof data61 === "string"){
if(func4(data61) > 131072){
const err60 = {instancePath:instancePath+"/assistance/policy_revision",schemaPath:"#/oneOf/3/properties/assistance/properties/policy_revision/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err60];
}
else {
vErrors.push(err60);
}
errors++;
}
}
else {
const err61 = {instancePath:instancePath+"/assistance/policy_revision",schemaPath:"#/oneOf/3/properties/assistance/properties/policy_revision/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err61];
}
else {
vErrors.push(err61);
}
errors++;
}
}
var valid14 = _errs109 === errors;
}
else {
var valid14 = true;
}
if(valid14){
if(data54.range !== undefined){
let data62 = data54.range;
const _errs111 = errors;
const _errs112 = errors;
let valid15 = false;
const _errs113 = errors;
if(errors === _errs113){
if(data62 && typeof data62 == "object" && !Array.isArray(data62)){
let missing13;
if((((data62.start === undefined) && (missing13 = "start")) || ((data62.end === undefined) && (missing13 = "end"))) || ((data62.quoted === undefined) && (missing13 = "quoted"))){
const err62 = {instancePath:instancePath+"/assistance/range",schemaPath:"#/oneOf/3/properties/assistance/properties/range/anyOf/0/required",keyword:"required",params:{missingProperty: missing13},message:"must have required property '"+missing13+"'"};
if(vErrors === null){
vErrors = [err62];
}
else {
vErrors.push(err62);
}
errors++;
}
else {
const _errs115 = errors;
for(const key13 in data62){
if(!(((key13 === "start") || (key13 === "end")) || (key13 === "quoted"))){
const err63 = {instancePath:instancePath+"/assistance/range",schemaPath:"#/oneOf/3/properties/assistance/properties/range/anyOf/0/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key13},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err63];
}
else {
vErrors.push(err63);
}
errors++;
break;
}
}
if(_errs115 === errors){
if(data62.start !== undefined){
const _errs116 = errors;
if(!(validate67(data62.start, {instancePath:instancePath+"/assistance/range/start",parentData:data62,parentDataProperty:"start",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate67.errors : vErrors.concat(validate67.errors);
errors = vErrors.length;
}
var valid16 = _errs116 === errors;
}
else {
var valid16 = true;
}
if(valid16){
if(data62.end !== undefined){
const _errs117 = errors;
if(!(validate67(data62.end, {instancePath:instancePath+"/assistance/range/end",parentData:data62,parentDataProperty:"end",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate67.errors : vErrors.concat(validate67.errors);
errors = vErrors.length;
}
var valid16 = _errs117 === errors;
}
else {
var valid16 = true;
}
if(valid16){
if(data62.quoted !== undefined){
const _errs118 = errors;
if(typeof data62.quoted !== "boolean"){
const err64 = {instancePath:instancePath+"/assistance/range/quoted",schemaPath:"#/oneOf/3/properties/assistance/properties/range/anyOf/0/properties/quoted/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"};
if(vErrors === null){
vErrors = [err64];
}
else {
vErrors.push(err64);
}
errors++;
}
var valid16 = _errs118 === errors;
}
else {
var valid16 = true;
}
}
}
}
}
}
else {
const err65 = {instancePath:instancePath+"/assistance/range",schemaPath:"#/oneOf/3/properties/assistance/properties/range/anyOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err65];
}
else {
vErrors.push(err65);
}
errors++;
}
}
var _valid1 = _errs113 === errors;
valid15 = valid15 || _valid1;
const _errs120 = errors;
if(data62 !== null){
const err66 = {instancePath:instancePath+"/assistance/range",schemaPath:"#/oneOf/3/properties/assistance/properties/range/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err66];
}
else {
vErrors.push(err66);
}
errors++;
}
var _valid1 = _errs120 === errors;
valid15 = valid15 || _valid1;
if(!valid15){
const err67 = {instancePath:instancePath+"/assistance/range",schemaPath:"#/oneOf/3/properties/assistance/properties/range/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err67];
}
else {
vErrors.push(err67);
}
errors++;
}
else {
errors = _errs112;
if(vErrors !== null){
if(_errs112){
vErrors.length = _errs112;
}
else {
vErrors = null;
}
}
}
var valid14 = _errs111 === errors;
}
else {
var valid14 = true;
}
if(valid14){
if(data54.items !== undefined){
let data66 = data54.items;
const _errs122 = errors;
if(errors === _errs122){
if(Array.isArray(data66)){
if(data66.length > 8){
const err68 = {instancePath:instancePath+"/assistance/items",schemaPath:"#/oneOf/3/properties/assistance/properties/items/maxItems",keyword:"maxItems",params:{limit: 8},message:"must NOT have more than 8 items"};
if(vErrors === null){
vErrors = [err68];
}
else {
vErrors.push(err68);
}
errors++;
}
else {
var valid17 = true;
const len1 = data66.length;
for(let i1=0; i1<len1; i1++){
let data67 = data66[i1];
const _errs124 = errors;
if(errors === _errs124){
if(data67 && typeof data67 == "object" && !Array.isArray(data67)){
let missing14;
if((((data67.text === undefined) && (missing14 = "text")) || ((data67.kind === undefined) && (missing14 = "kind"))) || ((data67.detail === undefined) && (missing14 = "detail"))){
const err69 = {instancePath:instancePath+"/assistance/items/" + i1,schemaPath:"#/oneOf/3/properties/assistance/properties/items/items/required",keyword:"required",params:{missingProperty: missing14},message:"must have required property '"+missing14+"'"};
if(vErrors === null){
vErrors = [err69];
}
else {
vErrors.push(err69);
}
errors++;
}
else {
const _errs126 = errors;
for(const key14 in data67){
if(!(((key14 === "text") || (key14 === "kind")) || (key14 === "detail"))){
const err70 = {instancePath:instancePath+"/assistance/items/" + i1,schemaPath:"#/oneOf/3/properties/assistance/properties/items/items/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key14},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err70];
}
else {
vErrors.push(err70);
}
errors++;
break;
}
}
if(_errs126 === errors){
if(data67.text !== undefined){
let data68 = data67.text;
const _errs127 = errors;
if(errors === _errs127){
if(typeof data68 === "string"){
if(func4(data68) > 131072){
const err71 = {instancePath:instancePath+"/assistance/items/" + i1+"/text",schemaPath:"#/oneOf/3/properties/assistance/properties/items/items/properties/text/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err71];
}
else {
vErrors.push(err71);
}
errors++;
}
}
else {
const err72 = {instancePath:instancePath+"/assistance/items/" + i1+"/text",schemaPath:"#/oneOf/3/properties/assistance/properties/items/items/properties/text/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err72];
}
else {
vErrors.push(err72);
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
if(data67.kind !== undefined){
let data69 = data67.kind;
const _errs129 = errors;
if(typeof data69 !== "string"){
const err73 = {instancePath:instancePath+"/assistance/items/" + i1+"/kind",schemaPath:"#/oneOf/3/properties/assistance/properties/items/items/properties/kind/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err73];
}
else {
vErrors.push(err73);
}
errors++;
}
if(!((((((data69 === "keyword") || (data69 === "source")) || (data69 === "column")) || (data69 === "symbol")) || (data69 === "literal")) || (data69 === "meta"))){
const err74 = {instancePath:instancePath+"/assistance/items/" + i1+"/kind",schemaPath:"#/oneOf/3/properties/assistance/properties/items/items/properties/kind/enum",keyword:"enum",params:{allowedValues: schema135.oneOf[3].properties.assistance.properties.items.items.properties.kind.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err74];
}
else {
vErrors.push(err74);
}
errors++;
}
var valid18 = _errs129 === errors;
}
else {
var valid18 = true;
}
if(valid18){
if(data67.detail !== undefined){
let data70 = data67.detail;
const _errs131 = errors;
if(errors === _errs131){
if(typeof data70 === "string"){
if(func4(data70) > 131072){
const err75 = {instancePath:instancePath+"/assistance/items/" + i1+"/detail",schemaPath:"#/oneOf/3/properties/assistance/properties/items/items/properties/detail/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err75];
}
else {
vErrors.push(err75);
}
errors++;
}
}
else {
const err76 = {instancePath:instancePath+"/assistance/items/" + i1+"/detail",schemaPath:"#/oneOf/3/properties/assistance/properties/items/items/properties/detail/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err76];
}
else {
vErrors.push(err76);
}
errors++;
}
}
var valid18 = _errs131 === errors;
}
else {
var valid18 = true;
}
}
}
}
}
}
else {
const err77 = {instancePath:instancePath+"/assistance/items/" + i1,schemaPath:"#/oneOf/3/properties/assistance/properties/items/items/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err77];
}
else {
vErrors.push(err77);
}
errors++;
}
}
var valid17 = _errs124 === errors;
if(!valid17){
break;
}
}
}
}
else {
const err78 = {instancePath:instancePath+"/assistance/items",schemaPath:"#/oneOf/3/properties/assistance/properties/items/type",keyword:"type",params:{type: "array"},message:"must be array"};
if(vErrors === null){
vErrors = [err78];
}
else {
vErrors.push(err78);
}
errors++;
}
}
var valid14 = _errs122 === errors;
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
}
}
}
else {
const err79 = {instancePath:instancePath+"/assistance",schemaPath:"#/oneOf/3/properties/assistance/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err79];
}
else {
vErrors.push(err79);
}
errors++;
}
}
}
}
}
}
else {
const err80 = {instancePath,schemaPath:"#/oneOf/3/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err80];
}
else {
vErrors.push(err80);
}
errors++;
}
}
var _valid0 = _errs96 === errors;
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
const _errs133 = errors;
if(errors === _errs133){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing15;
if((data.compiled === undefined) && (missing15 = "compiled")){
const err81 = {instancePath,schemaPath:"#/oneOf/4/required",keyword:"required",params:{missingProperty: missing15},message:"must have required property '"+missing15+"'"};
if(vErrors === null){
vErrors = [err81];
}
else {
vErrors.push(err81);
}
errors++;
}
else {
const _errs135 = errors;
for(const key15 in data){
if(!(key15 === "compiled")){
const err82 = {instancePath,schemaPath:"#/oneOf/4/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key15},message:"must NOT have additional properties"};
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
if(_errs135 === errors){
if(data.compiled !== undefined){
let data71 = data.compiled;
const _errs136 = errors;
if(errors === _errs136){
if(data71 && typeof data71 == "object" && !Array.isArray(data71)){
let missing16;
if(((((((data71.bundle === undefined) && (missing16 = "bundle")) || ((data71.source === undefined) && (missing16 = "source"))) || ((data71.plan === undefined) && (missing16 = "plan"))) || ((data71.limits === undefined) && (missing16 = "limits"))) || ((data71.contract === undefined) && (missing16 = "contract"))) || ((data71.schema === undefined) && (missing16 = "schema"))){
const err83 = {instancePath:instancePath+"/compiled",schemaPath:"#/oneOf/4/properties/compiled/required",keyword:"required",params:{missingProperty: missing16},message:"must have required property '"+missing16+"'"};
if(vErrors === null){
vErrors = [err83];
}
else {
vErrors.push(err83);
}
errors++;
}
else {
const _errs138 = errors;
for(const key16 in data71){
if(!((((((key16 === "bundle") || (key16 === "source")) || (key16 === "plan")) || (key16 === "limits")) || (key16 === "contract")) || (key16 === "schema"))){
const err84 = {instancePath:instancePath+"/compiled",schemaPath:"#/oneOf/4/properties/compiled/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key16},message:"must NOT have additional properties"};
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
if(_errs138 === errors){
if(data71.bundle !== undefined){
let data72 = data71.bundle;
const _errs139 = errors;
if(errors === _errs139){
if(typeof data72 === "string"){
if(func4(data72) > 131072){
const err85 = {instancePath:instancePath+"/compiled/bundle",schemaPath:"#/oneOf/4/properties/compiled/properties/bundle/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err85];
}
else {
vErrors.push(err85);
}
errors++;
}
}
else {
const err86 = {instancePath:instancePath+"/compiled/bundle",schemaPath:"#/oneOf/4/properties/compiled/properties/bundle/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err86];
}
else {
vErrors.push(err86);
}
errors++;
}
}
var valid20 = _errs139 === errors;
}
else {
var valid20 = true;
}
if(valid20){
if(data71.source !== undefined){
const _errs141 = errors;
if(!(validate619(data71.source, {instancePath:instancePath+"/compiled/source",parentData:data71,parentDataProperty:"source",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate619.errors : vErrors.concat(validate619.errors);
errors = vErrors.length;
}
var valid20 = _errs141 === errors;
}
else {
var valid20 = true;
}
if(valid20){
if(data71.plan !== undefined){
let data74 = data71.plan;
const _errs142 = errors;
if(errors === _errs142){
if(data74 && typeof data74 == "object" && !Array.isArray(data74)){
let missing17;
if(((((((data74.version === undefined) && (missing17 = "version")) || ((data74.projection === undefined) && (missing17 = "projection"))) || ((data74.output_names === undefined) && (missing17 = "output_names"))) || ((data74.limit === undefined) && (missing17 = "limit"))) || ((data74.aggregate === undefined) && (missing17 = "aggregate"))) || ((data74.predicate === undefined) && (missing17 = "predicate"))){
const err87 = {instancePath:instancePath+"/compiled/plan",schemaPath:"#/oneOf/4/properties/compiled/properties/plan/required",keyword:"required",params:{missingProperty: missing17},message:"must have required property '"+missing17+"'"};
if(vErrors === null){
vErrors = [err87];
}
else {
vErrors.push(err87);
}
errors++;
}
else {
const _errs144 = errors;
for(const key17 in data74){
if(!((((((key17 === "version") || (key17 === "projection")) || (key17 === "output_names")) || (key17 === "limit")) || (key17 === "aggregate")) || (key17 === "predicate"))){
const err88 = {instancePath:instancePath+"/compiled/plan",schemaPath:"#/oneOf/4/properties/compiled/properties/plan/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key17},message:"must NOT have additional properties"};
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
if(_errs144 === errors){
if(data74.version !== undefined){
const _errs145 = errors;
if(!(validate102(data74.version, {instancePath:instancePath+"/compiled/plan/version",parentData:data74,parentDataProperty:"version",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate102.errors : vErrors.concat(validate102.errors);
errors = vErrors.length;
}
var valid21 = _errs145 === errors;
}
else {
var valid21 = true;
}
if(valid21){
if(data74.projection !== undefined){
let data76 = data74.projection;
const _errs146 = errors;
if(errors === _errs146){
if(Array.isArray(data76)){
if(data76.length > 8){
const err89 = {instancePath:instancePath+"/compiled/plan/projection",schemaPath:"#/oneOf/4/properties/compiled/properties/plan/properties/projection/maxItems",keyword:"maxItems",params:{limit: 8},message:"must NOT have more than 8 items"};
if(vErrors === null){
vErrors = [err89];
}
else {
vErrors.push(err89);
}
errors++;
}
else {
var valid22 = true;
const len2 = data76.length;
for(let i2=0; i2<len2; i2++){
const _errs148 = errors;
if(!(validate53(data76[i2], {instancePath:instancePath+"/compiled/plan/projection/" + i2,parentData:data76,parentDataProperty:i2,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate53.errors : vErrors.concat(validate53.errors);
errors = vErrors.length;
}
var valid22 = _errs148 === errors;
if(!valid22){
break;
}
}
}
}
else {
const err90 = {instancePath:instancePath+"/compiled/plan/projection",schemaPath:"#/oneOf/4/properties/compiled/properties/plan/properties/projection/type",keyword:"type",params:{type: "array"},message:"must be array"};
if(vErrors === null){
vErrors = [err90];
}
else {
vErrors.push(err90);
}
errors++;
}
}
var valid21 = _errs146 === errors;
}
else {
var valid21 = true;
}
if(valid21){
if(data74.output_names !== undefined){
let data78 = data74.output_names;
const _errs149 = errors;
const _errs150 = errors;
let valid23 = false;
const _errs151 = errors;
if(errors === _errs151){
if(Array.isArray(data78)){
if(data78.length > 8){
const err91 = {instancePath:instancePath+"/compiled/plan/output_names",schemaPath:"#/oneOf/4/properties/compiled/properties/plan/properties/output_names/anyOf/0/maxItems",keyword:"maxItems",params:{limit: 8},message:"must NOT have more than 8 items"};
if(vErrors === null){
vErrors = [err91];
}
else {
vErrors.push(err91);
}
errors++;
}
else {
var valid24 = true;
const len3 = data78.length;
for(let i3=0; i3<len3; i3++){
const _errs153 = errors;
if(!(validate597(data78[i3], {instancePath:instancePath+"/compiled/plan/output_names/" + i3,parentData:data78,parentDataProperty:i3,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate597.errors : vErrors.concat(validate597.errors);
errors = vErrors.length;
}
var valid24 = _errs153 === errors;
if(!valid24){
break;
}
}
}
}
else {
const err92 = {instancePath:instancePath+"/compiled/plan/output_names",schemaPath:"#/oneOf/4/properties/compiled/properties/plan/properties/output_names/anyOf/0/type",keyword:"type",params:{type: "array"},message:"must be array"};
if(vErrors === null){
vErrors = [err92];
}
else {
vErrors.push(err92);
}
errors++;
}
}
var _valid2 = _errs151 === errors;
valid23 = valid23 || _valid2;
const _errs154 = errors;
if(data78 !== null){
const err93 = {instancePath:instancePath+"/compiled/plan/output_names",schemaPath:"#/oneOf/4/properties/compiled/properties/plan/properties/output_names/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err93];
}
else {
vErrors.push(err93);
}
errors++;
}
var _valid2 = _errs154 === errors;
valid23 = valid23 || _valid2;
if(!valid23){
const err94 = {instancePath:instancePath+"/compiled/plan/output_names",schemaPath:"#/oneOf/4/properties/compiled/properties/plan/properties/output_names/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err94];
}
else {
vErrors.push(err94);
}
errors++;
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
var valid21 = _errs149 === errors;
}
else {
var valid21 = true;
}
if(valid21){
if(data74.limit !== undefined){
const _errs156 = errors;
if(!(validate597(data74.limit, {instancePath:instancePath+"/compiled/plan/limit",parentData:data74,parentDataProperty:"limit",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate597.errors : vErrors.concat(validate597.errors);
errors = vErrors.length;
}
var valid21 = _errs156 === errors;
}
else {
var valid21 = true;
}
if(valid21){
if(data74.aggregate !== undefined){
const _errs157 = errors;
if(!(validate697(data74.aggregate, {instancePath:instancePath+"/compiled/plan/aggregate",parentData:data74,parentDataProperty:"aggregate",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate697.errors : vErrors.concat(validate697.errors);
errors = vErrors.length;
}
var valid21 = _errs157 === errors;
}
else {
var valid21 = true;
}
if(valid21){
if(data74.predicate !== undefined){
let data82 = data74.predicate;
const _errs158 = errors;
const _errs159 = errors;
let valid25 = false;
let passing1 = null;
const _errs160 = errors;
if(!(validate699(data82, {instancePath:instancePath+"/compiled/plan/predicate",parentData:data74,parentDataProperty:"predicate",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate699.errors : vErrors.concat(validate699.errors);
errors = vErrors.length;
}
var _valid3 = _errs160 === errors;
if(_valid3){
valid25 = true;
passing1 = 0;
var props2 = true;
}
const _errs161 = errors;
if(!(validate701(data82, {instancePath:instancePath+"/compiled/plan/predicate",parentData:data74,parentDataProperty:"predicate",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate701.errors : vErrors.concat(validate701.errors);
errors = vErrors.length;
}
var _valid3 = _errs161 === errors;
if(_valid3 && valid25){
valid25 = false;
passing1 = [passing1, 1];
}
else {
if(_valid3){
valid25 = true;
passing1 = 1;
if(props2 !== true){
props2 = true;
}
}
const _errs162 = errors;
if(!(validate708(data82, {instancePath:instancePath+"/compiled/plan/predicate",parentData:data74,parentDataProperty:"predicate",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate708.errors : vErrors.concat(validate708.errors);
errors = vErrors.length;
}
var _valid3 = _errs162 === errors;
if(_valid3 && valid25){
valid25 = false;
passing1 = [passing1, 2];
}
else {
if(_valid3){
valid25 = true;
passing1 = 2;
if(props2 !== true){
props2 = true;
}
}
const _errs163 = errors;
if(errors === _errs163){
if(data82 && typeof data82 == "object" && !Array.isArray(data82)){
let missing18;
if((data82.program === undefined) && (missing18 = "program")){
const err95 = {instancePath:instancePath+"/compiled/plan/predicate",schemaPath:"#/oneOf/4/properties/compiled/properties/plan/properties/predicate/oneOf/3/required",keyword:"required",params:{missingProperty: missing18},message:"must have required property '"+missing18+"'"};
if(vErrors === null){
vErrors = [err95];
}
else {
vErrors.push(err95);
}
errors++;
}
else {
const _errs165 = errors;
for(const key18 in data82){
if(!(key18 === "program")){
const err96 = {instancePath:instancePath+"/compiled/plan/predicate",schemaPath:"#/oneOf/4/properties/compiled/properties/plan/properties/predicate/oneOf/3/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key18},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err96];
}
else {
vErrors.push(err96);
}
errors++;
break;
}
}
if(_errs165 === errors){
if(data82.program !== undefined){
let data83 = data82.program;
const _errs166 = errors;
if(errors === _errs166){
if(Array.isArray(data83)){
if(data83.length > 64){
const err97 = {instancePath:instancePath+"/compiled/plan/predicate/program",schemaPath:"#/oneOf/4/properties/compiled/properties/plan/properties/predicate/oneOf/3/properties/program/maxItems",keyword:"maxItems",params:{limit: 64},message:"must NOT have more than 64 items"};
if(vErrors === null){
vErrors = [err97];
}
else {
vErrors.push(err97);
}
errors++;
}
else {
var valid27 = true;
const len4 = data83.length;
for(let i4=0; i4<len4; i4++){
let data84 = data83[i4];
const _errs168 = errors;
const _errs169 = errors;
let valid28 = false;
let passing2 = null;
const _errs170 = errors;
if(errors === _errs170){
if(data84 && typeof data84 == "object" && !Array.isArray(data84)){
let missing19;
if((data84.atom === undefined) && (missing19 = "atom")){
const err98 = {instancePath:instancePath+"/compiled/plan/predicate/program/" + i4,schemaPath:"#/oneOf/4/properties/compiled/properties/plan/properties/predicate/oneOf/3/properties/program/items/oneOf/0/required",keyword:"required",params:{missingProperty: missing19},message:"must have required property '"+missing19+"'"};
if(vErrors === null){
vErrors = [err98];
}
else {
vErrors.push(err98);
}
errors++;
}
else {
const _errs172 = errors;
for(const key19 in data84){
if(!(key19 === "atom")){
const err99 = {instancePath:instancePath+"/compiled/plan/predicate/program/" + i4,schemaPath:"#/oneOf/4/properties/compiled/properties/plan/properties/predicate/oneOf/3/properties/program/items/oneOf/0/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key19},message:"must NOT have additional properties"};
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
if(_errs172 === errors){
if(data84.atom !== undefined){
let data85 = data84.atom;
const _errs174 = errors;
let valid30 = false;
let passing3 = null;
const _errs175 = errors;
if(!(validate699(data85, {instancePath:instancePath+"/compiled/plan/predicate/program/" + i4+"/atom",parentData:data84,parentDataProperty:"atom",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate699.errors : vErrors.concat(validate699.errors);
errors = vErrors.length;
}
var _valid5 = _errs175 === errors;
if(_valid5){
valid30 = true;
passing3 = 0;
var props3 = true;
}
const _errs176 = errors;
if(!(validate701(data85, {instancePath:instancePath+"/compiled/plan/predicate/program/" + i4+"/atom",parentData:data84,parentDataProperty:"atom",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate701.errors : vErrors.concat(validate701.errors);
errors = vErrors.length;
}
var _valid5 = _errs176 === errors;
if(_valid5 && valid30){
valid30 = false;
passing3 = [passing3, 1];
}
else {
if(_valid5){
valid30 = true;
passing3 = 1;
if(props3 !== true){
props3 = true;
}
}
const _errs177 = errors;
if(!(validate708(data85, {instancePath:instancePath+"/compiled/plan/predicate/program/" + i4+"/atom",parentData:data84,parentDataProperty:"atom",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate708.errors : vErrors.concat(validate708.errors);
errors = vErrors.length;
}
var _valid5 = _errs177 === errors;
if(_valid5 && valid30){
valid30 = false;
passing3 = [passing3, 2];
}
else {
if(_valid5){
valid30 = true;
passing3 = 2;
if(props3 !== true){
props3 = true;
}
}
}
}
if(!valid30){
const err100 = {instancePath:instancePath+"/compiled/plan/predicate/program/" + i4+"/atom",schemaPath:"#/oneOf/4/properties/compiled/properties/plan/properties/predicate/oneOf/3/properties/program/items/oneOf/0/properties/atom/oneOf",keyword:"oneOf",params:{passingSchemas: passing3},message:"must match exactly one schema in oneOf"};
if(vErrors === null){
vErrors = [err100];
}
else {
vErrors.push(err100);
}
errors++;
}
else {
errors = _errs174;
if(vErrors !== null){
if(_errs174){
vErrors.length = _errs174;
}
else {
vErrors = null;
}
}
}
}
}
}
}
else {
const err101 = {instancePath:instancePath+"/compiled/plan/predicate/program/" + i4,schemaPath:"#/oneOf/4/properties/compiled/properties/plan/properties/predicate/oneOf/3/properties/program/items/oneOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err101];
}
else {
vErrors.push(err101);
}
errors++;
}
}
var _valid4 = _errs170 === errors;
if(_valid4){
valid28 = true;
passing2 = 0;
var props4 = true;
}
const _errs178 = errors;
if(!(validate719(data84, {instancePath:instancePath+"/compiled/plan/predicate/program/" + i4,parentData:data83,parentDataProperty:i4,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate719.errors : vErrors.concat(validate719.errors);
errors = vErrors.length;
}
var _valid4 = _errs178 === errors;
if(_valid4 && valid28){
valid28 = false;
passing2 = [passing2, 1];
}
else {
if(_valid4){
valid28 = true;
passing2 = 1;
if(props4 !== true){
props4 = true;
}
}
const _errs179 = errors;
if(!(validate721(data84, {instancePath:instancePath+"/compiled/plan/predicate/program/" + i4,parentData:data83,parentDataProperty:i4,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate721.errors : vErrors.concat(validate721.errors);
errors = vErrors.length;
}
var _valid4 = _errs179 === errors;
if(_valid4 && valid28){
valid28 = false;
passing2 = [passing2, 2];
}
else {
if(_valid4){
valid28 = true;
passing2 = 2;
if(props4 !== true){
props4 = true;
}
}
const _errs180 = errors;
if(!(validate723(data84, {instancePath:instancePath+"/compiled/plan/predicate/program/" + i4,parentData:data83,parentDataProperty:i4,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate723.errors : vErrors.concat(validate723.errors);
errors = vErrors.length;
}
var _valid4 = _errs180 === errors;
if(_valid4 && valid28){
valid28 = false;
passing2 = [passing2, 3];
}
else {
if(_valid4){
valid28 = true;
passing2 = 3;
if(props4 !== true){
props4 = true;
}
}
}
}
}
if(!valid28){
const err102 = {instancePath:instancePath+"/compiled/plan/predicate/program/" + i4,schemaPath:"#/oneOf/4/properties/compiled/properties/plan/properties/predicate/oneOf/3/properties/program/items/oneOf",keyword:"oneOf",params:{passingSchemas: passing2},message:"must match exactly one schema in oneOf"};
if(vErrors === null){
vErrors = [err102];
}
else {
vErrors.push(err102);
}
errors++;
}
else {
errors = _errs169;
if(vErrors !== null){
if(_errs169){
vErrors.length = _errs169;
}
else {
vErrors = null;
}
}
}
var valid27 = _errs168 === errors;
if(!valid27){
break;
}
}
}
}
else {
const err103 = {instancePath:instancePath+"/compiled/plan/predicate/program",schemaPath:"#/oneOf/4/properties/compiled/properties/plan/properties/predicate/oneOf/3/properties/program/type",keyword:"type",params:{type: "array"},message:"must be array"};
if(vErrors === null){
vErrors = [err103];
}
else {
vErrors.push(err103);
}
errors++;
}
}
}
}
}
}
else {
const err104 = {instancePath:instancePath+"/compiled/plan/predicate",schemaPath:"#/oneOf/4/properties/compiled/properties/plan/properties/predicate/oneOf/3/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err104];
}
else {
vErrors.push(err104);
}
errors++;
}
}
var _valid3 = _errs163 === errors;
if(_valid3 && valid25){
valid25 = false;
passing1 = [passing1, 3];
}
else {
if(_valid3){
valid25 = true;
passing1 = 3;
if(props2 !== true){
props2 = true;
}
}
}
}
}
if(!valid25){
const err105 = {instancePath:instancePath+"/compiled/plan/predicate",schemaPath:"#/oneOf/4/properties/compiled/properties/plan/properties/predicate/oneOf",keyword:"oneOf",params:{passingSchemas: passing1},message:"must match exactly one schema in oneOf"};
if(vErrors === null){
vErrors = [err105];
}
else {
vErrors.push(err105);
}
errors++;
}
else {
errors = _errs159;
if(vErrors !== null){
if(_errs159){
vErrors.length = _errs159;
}
else {
vErrors = null;
}
}
}
var valid21 = _errs158 === errors;
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
else {
const err106 = {instancePath:instancePath+"/compiled/plan",schemaPath:"#/oneOf/4/properties/compiled/properties/plan/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err106];
}
else {
vErrors.push(err106);
}
errors++;
}
}
var valid20 = _errs142 === errors;
}
else {
var valid20 = true;
}
if(valid20){
if(data71.limits !== undefined){
const _errs181 = errors;
if(!(validate669(data71.limits, {instancePath:instancePath+"/compiled/limits",parentData:data71,parentDataProperty:"limits",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate669.errors : vErrors.concat(validate669.errors);
errors = vErrors.length;
}
var valid20 = _errs181 === errors;
}
else {
var valid20 = true;
}
if(valid20){
if(data71.contract !== undefined){
const _errs182 = errors;
if(!(validate105(data71.contract, {instancePath:instancePath+"/compiled/contract",parentData:data71,parentDataProperty:"contract",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate105.errors : vErrors.concat(validate105.errors);
errors = vErrors.length;
}
var valid20 = _errs182 === errors;
}
else {
var valid20 = true;
}
if(valid20){
if(data71.schema !== undefined){
const _errs183 = errors;
if(!(validate105(data71.schema, {instancePath:instancePath+"/compiled/schema",parentData:data71,parentDataProperty:"schema",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate105.errors : vErrors.concat(validate105.errors);
errors = vErrors.length;
}
var valid20 = _errs183 === errors;
}
else {
var valid20 = true;
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
const err107 = {instancePath:instancePath+"/compiled",schemaPath:"#/oneOf/4/properties/compiled/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
}
}
}
else {
const err108 = {instancePath,schemaPath:"#/oneOf/4/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err108];
}
else {
vErrors.push(err108);
}
errors++;
}
}
var _valid0 = _errs133 === errors;
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
const _errs184 = errors;
if(errors === _errs184){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing20;
if((data.inspection === undefined) && (missing20 = "inspection")){
const err109 = {instancePath,schemaPath:"#/oneOf/5/required",keyword:"required",params:{missingProperty: missing20},message:"must have required property '"+missing20+"'"};
if(vErrors === null){
vErrors = [err109];
}
else {
vErrors.push(err109);
}
errors++;
}
else {
const _errs186 = errors;
for(const key20 in data){
if(!(key20 === "inspection")){
const err110 = {instancePath,schemaPath:"#/oneOf/5/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key20},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err110];
}
else {
vErrors.push(err110);
}
errors++;
break;
}
}
if(_errs186 === errors){
if(data.inspection !== undefined){
let data89 = data.inspection;
const _errs187 = errors;
if(errors === _errs187){
if(data89 && typeof data89 == "object" && !Array.isArray(data89)){
let missing21;
if(((((((((((data89.version === undefined) && (missing21 = "version")) || ((data89.scope === undefined) && (missing21 = "scope"))) || ((data89.name === undefined) && (missing21 = "name"))) || ((data89.resource === undefined) && (missing21 = "resource"))) || ((data89.source_kind === undefined) && (missing21 = "source_kind"))) || ((data89.contract === undefined) && (missing21 = "contract"))) || ((data89.schema === undefined) && (missing21 = "schema"))) || ((data89.resource_revision === undefined) && (missing21 = "resource_revision"))) || ((data89.policy_revision === undefined) && (missing21 = "policy_revision"))) || ((data89.details === undefined) && (missing21 = "details"))){
const err111 = {instancePath:instancePath+"/inspection",schemaPath:"#/oneOf/5/properties/inspection/required",keyword:"required",params:{missingProperty: missing21},message:"must have required property '"+missing21+"'"};
if(vErrors === null){
vErrors = [err111];
}
else {
vErrors.push(err111);
}
errors++;
}
else {
const _errs189 = errors;
for(const key21 in data89){
if(!(func1.call(schema135.oneOf[5].properties.inspection.properties, key21))){
const err112 = {instancePath:instancePath+"/inspection",schemaPath:"#/oneOf/5/properties/inspection/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key21},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err112];
}
else {
vErrors.push(err112);
}
errors++;
break;
}
}
if(_errs189 === errors){
if(data89.version !== undefined){
const _errs190 = errors;
if(!(validate102(data89.version, {instancePath:instancePath+"/inspection/version",parentData:data89,parentDataProperty:"version",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate102.errors : vErrors.concat(validate102.errors);
errors = vErrors.length;
}
var valid32 = _errs190 === errors;
}
else {
var valid32 = true;
}
if(valid32){
if(data89.scope !== undefined){
let data91 = data89.scope;
const _errs191 = errors;
if(typeof data91 !== "string"){
const err113 = {instancePath:instancePath+"/inspection/scope",schemaPath:"#/oneOf/5/properties/inspection/properties/scope/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err113];
}
else {
vErrors.push(err113);
}
errors++;
}
if(!(data91 === "configured_source")){
const err114 = {instancePath:instancePath+"/inspection/scope",schemaPath:"#/oneOf/5/properties/inspection/properties/scope/enum",keyword:"enum",params:{allowedValues: schema135.oneOf[5].properties.inspection.properties.scope.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err114];
}
else {
vErrors.push(err114);
}
errors++;
}
var valid32 = _errs191 === errors;
}
else {
var valid32 = true;
}
if(valid32){
if(data89.name !== undefined){
let data92 = data89.name;
const _errs193 = errors;
if(errors === _errs193){
if(typeof data92 === "string"){
if(func4(data92) > 131072){
const err115 = {instancePath:instancePath+"/inspection/name",schemaPath:"#/oneOf/5/properties/inspection/properties/name/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err115];
}
else {
vErrors.push(err115);
}
errors++;
}
}
else {
const err116 = {instancePath:instancePath+"/inspection/name",schemaPath:"#/oneOf/5/properties/inspection/properties/name/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err116];
}
else {
vErrors.push(err116);
}
errors++;
}
}
var valid32 = _errs193 === errors;
}
else {
var valid32 = true;
}
if(valid32){
if(data89.resource !== undefined){
const _errs195 = errors;
if(!(validate55(data89.resource, {instancePath:instancePath+"/inspection/resource",parentData:data89,parentDataProperty:"resource",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate55.errors : vErrors.concat(validate55.errors);
errors = vErrors.length;
}
var valid32 = _errs195 === errors;
}
else {
var valid32 = true;
}
if(valid32){
if(data89.source_kind !== undefined){
const _errs196 = errors;
if(!(validate490(data89.source_kind, {instancePath:instancePath+"/inspection/source_kind",parentData:data89,parentDataProperty:"source_kind",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate490.errors : vErrors.concat(validate490.errors);
errors = vErrors.length;
}
var valid32 = _errs196 === errors;
}
else {
var valid32 = true;
}
if(valid32){
if(data89.contract !== undefined){
const _errs197 = errors;
if(!(validate105(data89.contract, {instancePath:instancePath+"/inspection/contract",parentData:data89,parentDataProperty:"contract",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate105.errors : vErrors.concat(validate105.errors);
errors = vErrors.length;
}
var valid32 = _errs197 === errors;
}
else {
var valid32 = true;
}
if(valid32){
if(data89.schema !== undefined){
const _errs198 = errors;
if(!(validate105(data89.schema, {instancePath:instancePath+"/inspection/schema",parentData:data89,parentDataProperty:"schema",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate105.errors : vErrors.concat(validate105.errors);
errors = vErrors.length;
}
var valid32 = _errs198 === errors;
}
else {
var valid32 = true;
}
if(valid32){
if(data89.resource_revision !== undefined){
const _errs199 = errors;
if(!(validate55(data89.resource_revision, {instancePath:instancePath+"/inspection/resource_revision",parentData:data89,parentDataProperty:"resource_revision",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate55.errors : vErrors.concat(validate55.errors);
errors = vErrors.length;
}
var valid32 = _errs199 === errors;
}
else {
var valid32 = true;
}
if(valid32){
if(data89.policy_revision !== undefined){
let data98 = data89.policy_revision;
const _errs200 = errors;
if(errors === _errs200){
if(typeof data98 === "string"){
if(func4(data98) > 131072){
const err117 = {instancePath:instancePath+"/inspection/policy_revision",schemaPath:"#/oneOf/5/properties/inspection/properties/policy_revision/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err117];
}
else {
vErrors.push(err117);
}
errors++;
}
}
else {
const err118 = {instancePath:instancePath+"/inspection/policy_revision",schemaPath:"#/oneOf/5/properties/inspection/properties/policy_revision/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err118];
}
else {
vErrors.push(err118);
}
errors++;
}
}
var valid32 = _errs200 === errors;
}
else {
var valid32 = true;
}
if(valid32){
if(data89.details !== undefined){
let data99 = data89.details;
const _errs202 = errors;
const _errs203 = errors;
let valid33 = false;
let passing4 = null;
const _errs204 = errors;
if(errors === _errs204){
if(data99 && typeof data99 == "object" && !Array.isArray(data99)){
let missing22;
if((data99.description === undefined) && (missing22 = "description")){
const err119 = {instancePath:instancePath+"/inspection/details",schemaPath:"#/oneOf/5/properties/inspection/properties/details/oneOf/0/required",keyword:"required",params:{missingProperty: missing22},message:"must have required property '"+missing22+"'"};
if(vErrors === null){
vErrors = [err119];
}
else {
vErrors.push(err119);
}
errors++;
}
else {
const _errs206 = errors;
for(const key22 in data99){
if(!(key22 === "description")){
const err120 = {instancePath:instancePath+"/inspection/details",schemaPath:"#/oneOf/5/properties/inspection/properties/details/oneOf/0/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key22},message:"must NOT have additional properties"};
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
if(_errs206 === errors){
if(data99.description !== undefined){
let data100 = data99.description;
const _errs207 = errors;
if(errors === _errs207){
if(data100 && typeof data100 == "object" && !Array.isArray(data100)){
let missing23;
if((data100.columns === undefined) && (missing23 = "columns")){
const err121 = {instancePath:instancePath+"/inspection/details/description",schemaPath:"#/oneOf/5/properties/inspection/properties/details/oneOf/0/properties/description/required",keyword:"required",params:{missingProperty: missing23},message:"must have required property '"+missing23+"'"};
if(vErrors === null){
vErrors = [err121];
}
else {
vErrors.push(err121);
}
errors++;
}
else {
const _errs209 = errors;
for(const key23 in data100){
if(!(key23 === "columns")){
const err122 = {instancePath:instancePath+"/inspection/details/description",schemaPath:"#/oneOf/5/properties/inspection/properties/details/oneOf/0/properties/description/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key23},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err122];
}
else {
vErrors.push(err122);
}
errors++;
break;
}
}
if(_errs209 === errors){
if(data100.columns !== undefined){
if(!(validate677(data100.columns, {instancePath:instancePath+"/inspection/details/description/columns",parentData:data100,parentDataProperty:"columns",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate677.errors : vErrors.concat(validate677.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err123 = {instancePath:instancePath+"/inspection/details/description",schemaPath:"#/oneOf/5/properties/inspection/properties/details/oneOf/0/properties/description/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err123];
}
else {
vErrors.push(err123);
}
errors++;
}
}
}
}
}
}
else {
const err124 = {instancePath:instancePath+"/inspection/details",schemaPath:"#/oneOf/5/properties/inspection/properties/details/oneOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err124];
}
else {
vErrors.push(err124);
}
errors++;
}
}
var _valid6 = _errs204 === errors;
if(_valid6){
valid33 = true;
passing4 = 0;
var props5 = true;
}
const _errs211 = errors;
if(errors === _errs211){
if(data99 && typeof data99 == "object" && !Array.isArray(data99)){
let missing24;
if((data99.tables === undefined) && (missing24 = "tables")){
const err125 = {instancePath:instancePath+"/inspection/details",schemaPath:"#/oneOf/5/properties/inspection/properties/details/oneOf/1/required",keyword:"required",params:{missingProperty: missing24},message:"must have required property '"+missing24+"'"};
if(vErrors === null){
vErrors = [err125];
}
else {
vErrors.push(err125);
}
errors++;
}
else {
const _errs213 = errors;
for(const key24 in data99){
if(!(key24 === "tables")){
const err126 = {instancePath:instancePath+"/inspection/details",schemaPath:"#/oneOf/5/properties/inspection/properties/details/oneOf/1/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key24},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err126];
}
else {
vErrors.push(err126);
}
errors++;
break;
}
}
if(_errs213 === errors){
if(data99.tables !== undefined){
if(!(validate649(data99.tables, {instancePath:instancePath+"/inspection/details/tables",parentData:data99,parentDataProperty:"tables",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate649.errors : vErrors.concat(validate649.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err127 = {instancePath:instancePath+"/inspection/details",schemaPath:"#/oneOf/5/properties/inspection/properties/details/oneOf/1/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err127];
}
else {
vErrors.push(err127);
}
errors++;
}
}
var _valid6 = _errs211 === errors;
if(_valid6 && valid33){
valid33 = false;
passing4 = [passing4, 1];
}
else {
if(_valid6){
valid33 = true;
passing4 = 1;
if(props5 !== true){
props5 = true;
}
}
const _errs215 = errors;
if(errors === _errs215){
if(data99 && typeof data99 == "object" && !Array.isArray(data99)){
let missing25;
if((data99.explanation === undefined) && (missing25 = "explanation")){
const err128 = {instancePath:instancePath+"/inspection/details",schemaPath:"#/oneOf/5/properties/inspection/properties/details/oneOf/2/required",keyword:"required",params:{missingProperty: missing25},message:"must have required property '"+missing25+"'"};
if(vErrors === null){
vErrors = [err128];
}
else {
vErrors.push(err128);
}
errors++;
}
else {
const _errs217 = errors;
for(const key25 in data99){
if(!(key25 === "explanation")){
const err129 = {instancePath:instancePath+"/inspection/details",schemaPath:"#/oneOf/5/properties/inspection/properties/details/oneOf/2/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key25},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err129];
}
else {
vErrors.push(err129);
}
errors++;
break;
}
}
if(_errs217 === errors){
if(data99.explanation !== undefined){
let data103 = data99.explanation;
const _errs218 = errors;
if(errors === _errs218){
if(data103 && typeof data103 == "object" && !Array.isArray(data103)){
let missing26;
if((((((((data103.operators === undefined) && (missing26 = "operators")) || ((data103.predicate === undefined) && (missing26 = "predicate"))) || ((data103.projection === undefined) && (missing26 = "projection"))) || ((data103.limit === undefined) && (missing26 = "limit"))) || ((data103.aggregate === undefined) && (missing26 = "aggregate"))) || ((data103.columns === undefined) && (missing26 = "columns"))) || ((data103.budgets === undefined) && (missing26 = "budgets"))){
const err130 = {instancePath:instancePath+"/inspection/details/explanation",schemaPath:"#/oneOf/5/properties/inspection/properties/details/oneOf/2/properties/explanation/required",keyword:"required",params:{missingProperty: missing26},message:"must have required property '"+missing26+"'"};
if(vErrors === null){
vErrors = [err130];
}
else {
vErrors.push(err130);
}
errors++;
}
else {
const _errs220 = errors;
for(const key26 in data103){
if(!(((((((key26 === "operators") || (key26 === "predicate")) || (key26 === "projection")) || (key26 === "limit")) || (key26 === "aggregate")) || (key26 === "columns")) || (key26 === "budgets"))){
const err131 = {instancePath:instancePath+"/inspection/details/explanation",schemaPath:"#/oneOf/5/properties/inspection/properties/details/oneOf/2/properties/explanation/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key26},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err131];
}
else {
vErrors.push(err131);
}
errors++;
break;
}
}
if(_errs220 === errors){
if(data103.operators !== undefined){
let data104 = data103.operators;
const _errs221 = errors;
if(errors === _errs221){
if(Array.isArray(data104)){
if(data104.length > 8){
const err132 = {instancePath:instancePath+"/inspection/details/explanation/operators",schemaPath:"#/oneOf/5/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/operators/maxItems",keyword:"maxItems",params:{limit: 8},message:"must NOT have more than 8 items"};
if(vErrors === null){
vErrors = [err132];
}
else {
vErrors.push(err132);
}
errors++;
}
else {
var valid39 = true;
const len5 = data104.length;
for(let i5=0; i5<len5; i5++){
let data105 = data104[i5];
const _errs223 = errors;
if(typeof data105 !== "string"){
const err133 = {instancePath:instancePath+"/inspection/details/explanation/operators/" + i5,schemaPath:"#/oneOf/5/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/operators/items/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err133];
}
else {
vErrors.push(err133);
}
errors++;
}
if(!(((((((data105 === "scan") || (data105 === "filter")) || (data105 === "limit")) || (data105 === "project")) || (data105 === "count")) || (data105 === "sum")) || (data105 === "count_values"))){
const err134 = {instancePath:instancePath+"/inspection/details/explanation/operators/" + i5,schemaPath:"#/oneOf/5/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/operators/items/enum",keyword:"enum",params:{allowedValues: schema135.oneOf[5].properties.inspection.properties.details.oneOf[2].properties.explanation.properties.operators.items.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err134];
}
else {
vErrors.push(err134);
}
errors++;
}
var valid39 = _errs223 === errors;
if(!valid39){
break;
}
}
}
}
else {
const err135 = {instancePath:instancePath+"/inspection/details/explanation/operators",schemaPath:"#/oneOf/5/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/operators/type",keyword:"type",params:{type: "array"},message:"must be array"};
if(vErrors === null){
vErrors = [err135];
}
else {
vErrors.push(err135);
}
errors++;
}
}
var valid38 = _errs221 === errors;
}
else {
var valid38 = true;
}
if(valid38){
if(data103.predicate !== undefined){
let data106 = data103.predicate;
const _errs225 = errors;
const _errs226 = errors;
let valid40 = false;
let passing5 = null;
const _errs227 = errors;
if(!(validate699(data106, {instancePath:instancePath+"/inspection/details/explanation/predicate",parentData:data103,parentDataProperty:"predicate",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate699.errors : vErrors.concat(validate699.errors);
errors = vErrors.length;
}
var _valid7 = _errs227 === errors;
if(_valid7){
valid40 = true;
passing5 = 0;
var props6 = true;
}
const _errs228 = errors;
if(!(validate737(data106, {instancePath:instancePath+"/inspection/details/explanation/predicate",parentData:data103,parentDataProperty:"predicate",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate737.errors : vErrors.concat(validate737.errors);
errors = vErrors.length;
}
var _valid7 = _errs228 === errors;
if(_valid7 && valid40){
valid40 = false;
passing5 = [passing5, 1];
}
else {
if(_valid7){
valid40 = true;
passing5 = 1;
if(props6 !== true){
props6 = true;
}
}
const _errs229 = errors;
if(!(validate742(data106, {instancePath:instancePath+"/inspection/details/explanation/predicate",parentData:data103,parentDataProperty:"predicate",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate742.errors : vErrors.concat(validate742.errors);
errors = vErrors.length;
}
var _valid7 = _errs229 === errors;
if(_valid7 && valid40){
valid40 = false;
passing5 = [passing5, 2];
}
else {
if(_valid7){
valid40 = true;
passing5 = 2;
if(props6 !== true){
props6 = true;
}
}
const _errs230 = errors;
if(errors === _errs230){
if(data106 && typeof data106 == "object" && !Array.isArray(data106)){
let missing27;
if((data106.program === undefined) && (missing27 = "program")){
const err136 = {instancePath:instancePath+"/inspection/details/explanation/predicate",schemaPath:"#/oneOf/5/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/predicate/oneOf/3/required",keyword:"required",params:{missingProperty: missing27},message:"must have required property '"+missing27+"'"};
if(vErrors === null){
vErrors = [err136];
}
else {
vErrors.push(err136);
}
errors++;
}
else {
const _errs232 = errors;
for(const key27 in data106){
if(!(key27 === "program")){
const err137 = {instancePath:instancePath+"/inspection/details/explanation/predicate",schemaPath:"#/oneOf/5/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/predicate/oneOf/3/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key27},message:"must NOT have additional properties"};
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
if(_errs232 === errors){
if(data106.program !== undefined){
let data107 = data106.program;
const _errs233 = errors;
if(errors === _errs233){
if(Array.isArray(data107)){
if(data107.length > 64){
const err138 = {instancePath:instancePath+"/inspection/details/explanation/predicate/program",schemaPath:"#/oneOf/5/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/predicate/oneOf/3/properties/program/maxItems",keyword:"maxItems",params:{limit: 64},message:"must NOT have more than 64 items"};
if(vErrors === null){
vErrors = [err138];
}
else {
vErrors.push(err138);
}
errors++;
}
else {
var valid42 = true;
const len6 = data107.length;
for(let i6=0; i6<len6; i6++){
let data108 = data107[i6];
const _errs235 = errors;
const _errs236 = errors;
let valid43 = false;
let passing6 = null;
const _errs237 = errors;
if(errors === _errs237){
if(data108 && typeof data108 == "object" && !Array.isArray(data108)){
let missing28;
if((data108.atom === undefined) && (missing28 = "atom")){
const err139 = {instancePath:instancePath+"/inspection/details/explanation/predicate/program/" + i6,schemaPath:"#/oneOf/5/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/predicate/oneOf/3/properties/program/items/oneOf/0/required",keyword:"required",params:{missingProperty: missing28},message:"must have required property '"+missing28+"'"};
if(vErrors === null){
vErrors = [err139];
}
else {
vErrors.push(err139);
}
errors++;
}
else {
const _errs239 = errors;
for(const key28 in data108){
if(!(key28 === "atom")){
const err140 = {instancePath:instancePath+"/inspection/details/explanation/predicate/program/" + i6,schemaPath:"#/oneOf/5/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/predicate/oneOf/3/properties/program/items/oneOf/0/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key28},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err140];
}
else {
vErrors.push(err140);
}
errors++;
break;
}
}
if(_errs239 === errors){
if(data108.atom !== undefined){
let data109 = data108.atom;
const _errs241 = errors;
let valid45 = false;
let passing7 = null;
const _errs242 = errors;
if(!(validate699(data109, {instancePath:instancePath+"/inspection/details/explanation/predicate/program/" + i6+"/atom",parentData:data108,parentDataProperty:"atom",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate699.errors : vErrors.concat(validate699.errors);
errors = vErrors.length;
}
var _valid9 = _errs242 === errors;
if(_valid9){
valid45 = true;
passing7 = 0;
var props7 = true;
}
const _errs243 = errors;
if(!(validate737(data109, {instancePath:instancePath+"/inspection/details/explanation/predicate/program/" + i6+"/atom",parentData:data108,parentDataProperty:"atom",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate737.errors : vErrors.concat(validate737.errors);
errors = vErrors.length;
}
var _valid9 = _errs243 === errors;
if(_valid9 && valid45){
valid45 = false;
passing7 = [passing7, 1];
}
else {
if(_valid9){
valid45 = true;
passing7 = 1;
if(props7 !== true){
props7 = true;
}
}
const _errs244 = errors;
if(!(validate742(data109, {instancePath:instancePath+"/inspection/details/explanation/predicate/program/" + i6+"/atom",parentData:data108,parentDataProperty:"atom",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate742.errors : vErrors.concat(validate742.errors);
errors = vErrors.length;
}
var _valid9 = _errs244 === errors;
if(_valid9 && valid45){
valid45 = false;
passing7 = [passing7, 2];
}
else {
if(_valid9){
valid45 = true;
passing7 = 2;
if(props7 !== true){
props7 = true;
}
}
}
}
if(!valid45){
const err141 = {instancePath:instancePath+"/inspection/details/explanation/predicate/program/" + i6+"/atom",schemaPath:"#/oneOf/5/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/predicate/oneOf/3/properties/program/items/oneOf/0/properties/atom/oneOf",keyword:"oneOf",params:{passingSchemas: passing7},message:"must match exactly one schema in oneOf"};
if(vErrors === null){
vErrors = [err141];
}
else {
vErrors.push(err141);
}
errors++;
}
else {
errors = _errs241;
if(vErrors !== null){
if(_errs241){
vErrors.length = _errs241;
}
else {
vErrors = null;
}
}
}
}
}
}
}
else {
const err142 = {instancePath:instancePath+"/inspection/details/explanation/predicate/program/" + i6,schemaPath:"#/oneOf/5/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/predicate/oneOf/3/properties/program/items/oneOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err142];
}
else {
vErrors.push(err142);
}
errors++;
}
}
var _valid8 = _errs237 === errors;
if(_valid8){
valid43 = true;
passing6 = 0;
var props8 = true;
}
const _errs245 = errors;
if(!(validate719(data108, {instancePath:instancePath+"/inspection/details/explanation/predicate/program/" + i6,parentData:data107,parentDataProperty:i6,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate719.errors : vErrors.concat(validate719.errors);
errors = vErrors.length;
}
var _valid8 = _errs245 === errors;
if(_valid8 && valid43){
valid43 = false;
passing6 = [passing6, 1];
}
else {
if(_valid8){
valid43 = true;
passing6 = 1;
if(props8 !== true){
props8 = true;
}
}
const _errs246 = errors;
if(!(validate721(data108, {instancePath:instancePath+"/inspection/details/explanation/predicate/program/" + i6,parentData:data107,parentDataProperty:i6,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate721.errors : vErrors.concat(validate721.errors);
errors = vErrors.length;
}
var _valid8 = _errs246 === errors;
if(_valid8 && valid43){
valid43 = false;
passing6 = [passing6, 2];
}
else {
if(_valid8){
valid43 = true;
passing6 = 2;
if(props8 !== true){
props8 = true;
}
}
const _errs247 = errors;
if(!(validate723(data108, {instancePath:instancePath+"/inspection/details/explanation/predicate/program/" + i6,parentData:data107,parentDataProperty:i6,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate723.errors : vErrors.concat(validate723.errors);
errors = vErrors.length;
}
var _valid8 = _errs247 === errors;
if(_valid8 && valid43){
valid43 = false;
passing6 = [passing6, 3];
}
else {
if(_valid8){
valid43 = true;
passing6 = 3;
if(props8 !== true){
props8 = true;
}
}
}
}
}
if(!valid43){
const err143 = {instancePath:instancePath+"/inspection/details/explanation/predicate/program/" + i6,schemaPath:"#/oneOf/5/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/predicate/oneOf/3/properties/program/items/oneOf",keyword:"oneOf",params:{passingSchemas: passing6},message:"must match exactly one schema in oneOf"};
if(vErrors === null){
vErrors = [err143];
}
else {
vErrors.push(err143);
}
errors++;
}
else {
errors = _errs236;
if(vErrors !== null){
if(_errs236){
vErrors.length = _errs236;
}
else {
vErrors = null;
}
}
}
var valid42 = _errs235 === errors;
if(!valid42){
break;
}
}
}
}
else {
const err144 = {instancePath:instancePath+"/inspection/details/explanation/predicate/program",schemaPath:"#/oneOf/5/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/predicate/oneOf/3/properties/program/type",keyword:"type",params:{type: "array"},message:"must be array"};
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
}
}
else {
const err145 = {instancePath:instancePath+"/inspection/details/explanation/predicate",schemaPath:"#/oneOf/5/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/predicate/oneOf/3/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err145];
}
else {
vErrors.push(err145);
}
errors++;
}
}
var _valid7 = _errs230 === errors;
if(_valid7 && valid40){
valid40 = false;
passing5 = [passing5, 3];
}
else {
if(_valid7){
valid40 = true;
passing5 = 3;
if(props6 !== true){
props6 = true;
}
}
}
}
}
if(!valid40){
const err146 = {instancePath:instancePath+"/inspection/details/explanation/predicate",schemaPath:"#/oneOf/5/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/predicate/oneOf",keyword:"oneOf",params:{passingSchemas: passing5},message:"must match exactly one schema in oneOf"};
if(vErrors === null){
vErrors = [err146];
}
else {
vErrors.push(err146);
}
errors++;
}
else {
errors = _errs226;
if(vErrors !== null){
if(_errs226){
vErrors.length = _errs226;
}
else {
vErrors = null;
}
}
}
var valid38 = _errs225 === errors;
}
else {
var valid38 = true;
}
if(valid38){
if(data103.projection !== undefined){
const _errs248 = errors;
if(!(validate649(data103.projection, {instancePath:instancePath+"/inspection/details/explanation/projection",parentData:data103,parentDataProperty:"projection",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate649.errors : vErrors.concat(validate649.errors);
errors = vErrors.length;
}
var valid38 = _errs248 === errors;
}
else {
var valid38 = true;
}
if(valid38){
if(data103.limit !== undefined){
const _errs249 = errors;
if(!(validate597(data103.limit, {instancePath:instancePath+"/inspection/details/explanation/limit",parentData:data103,parentDataProperty:"limit",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate597.errors : vErrors.concat(validate597.errors);
errors = vErrors.length;
}
var valid38 = _errs249 === errors;
}
else {
var valid38 = true;
}
if(valid38){
if(data103.aggregate !== undefined){
const _errs250 = errors;
if(!(validate697(data103.aggregate, {instancePath:instancePath+"/inspection/details/explanation/aggregate",parentData:data103,parentDataProperty:"aggregate",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate697.errors : vErrors.concat(validate697.errors);
errors = vErrors.length;
}
var valid38 = _errs250 === errors;
}
else {
var valid38 = true;
}
if(valid38){
if(data103.columns !== undefined){
const _errs251 = errors;
if(!(validate677(data103.columns, {instancePath:instancePath+"/inspection/details/explanation/columns",parentData:data103,parentDataProperty:"columns",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate677.errors : vErrors.concat(validate677.errors);
errors = vErrors.length;
}
var valid38 = _errs251 === errors;
}
else {
var valid38 = true;
}
if(valid38){
if(data103.budgets !== undefined){
const _errs252 = errors;
if(!(validate669(data103.budgets, {instancePath:instancePath+"/inspection/details/explanation/budgets",parentData:data103,parentDataProperty:"budgets",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate669.errors : vErrors.concat(validate669.errors);
errors = vErrors.length;
}
var valid38 = _errs252 === errors;
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
else {
const err147 = {instancePath:instancePath+"/inspection/details/explanation",schemaPath:"#/oneOf/5/properties/inspection/properties/details/oneOf/2/properties/explanation/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err147];
}
else {
vErrors.push(err147);
}
errors++;
}
}
}
}
}
}
else {
const err148 = {instancePath:instancePath+"/inspection/details",schemaPath:"#/oneOf/5/properties/inspection/properties/details/oneOf/2/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err148];
}
else {
vErrors.push(err148);
}
errors++;
}
}
var _valid6 = _errs215 === errors;
if(_valid6 && valid33){
valid33 = false;
passing4 = [passing4, 2];
}
else {
if(_valid6){
valid33 = true;
passing4 = 2;
if(props5 !== true){
props5 = true;
}
}
}
}
if(!valid33){
const err149 = {instancePath:instancePath+"/inspection/details",schemaPath:"#/oneOf/5/properties/inspection/properties/details/oneOf",keyword:"oneOf",params:{passingSchemas: passing4},message:"must match exactly one schema in oneOf"};
if(vErrors === null){
vErrors = [err149];
}
else {
vErrors.push(err149);
}
errors++;
}
else {
errors = _errs203;
if(vErrors !== null){
if(_errs203){
vErrors.length = _errs203;
}
else {
vErrors = null;
}
}
}
var valid32 = _errs202 === errors;
}
else {
var valid32 = true;
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
const err150 = {instancePath:instancePath+"/inspection",schemaPath:"#/oneOf/5/properties/inspection/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err150];
}
else {
vErrors.push(err150);
}
errors++;
}
}
}
}
}
}
else {
const err151 = {instancePath,schemaPath:"#/oneOf/5/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err151];
}
else {
vErrors.push(err151);
}
errors++;
}
}
var _valid0 = _errs184 === errors;
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
const _errs253 = errors;
if(errors === _errs253){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing29;
if((data.prepared === undefined) && (missing29 = "prepared")){
const err152 = {instancePath,schemaPath:"#/oneOf/6/required",keyword:"required",params:{missingProperty: missing29},message:"must have required property '"+missing29+"'"};
if(vErrors === null){
vErrors = [err152];
}
else {
vErrors.push(err152);
}
errors++;
}
else {
const _errs255 = errors;
for(const key29 in data){
if(!(key29 === "prepared")){
const err153 = {instancePath,schemaPath:"#/oneOf/6/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key29},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err153];
}
else {
vErrors.push(err153);
}
errors++;
break;
}
}
if(_errs255 === errors){
if(data.prepared !== undefined){
let data115 = data.prepared;
const _errs257 = errors;
let valid47 = false;
const _errs258 = errors;
if(!(validate599(data115, {instancePath:instancePath+"/prepared",parentData:data,parentDataProperty:"prepared",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate599.errors : vErrors.concat(validate599.errors);
errors = vErrors.length;
}
var _valid10 = _errs258 === errors;
valid47 = valid47 || _valid10;
const _errs259 = errors;
if(data115 !== null){
const err154 = {instancePath:instancePath+"/prepared",schemaPath:"#/oneOf/6/properties/prepared/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err154];
}
else {
vErrors.push(err154);
}
errors++;
}
var _valid10 = _errs259 === errors;
valid47 = valid47 || _valid10;
if(!valid47){
const err155 = {instancePath:instancePath+"/prepared",schemaPath:"#/oneOf/6/properties/prepared/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err155];
}
else {
vErrors.push(err155);
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
}
}
}
}
else {
const err156 = {instancePath,schemaPath:"#/oneOf/6/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err156];
}
else {
vErrors.push(err156);
}
errors++;
}
}
var _valid0 = _errs253 === errors;
if(_valid0 && valid0){
valid0 = false;
passing0 = [passing0, 6];
}
else {
if(_valid0){
valid0 = true;
passing0 = 6;
if(props0 !== true){
props0 = true;
}
}
const _errs261 = errors;
if(errors === _errs261){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing30;
if((data.receipt === undefined) && (missing30 = "receipt")){
const err157 = {instancePath,schemaPath:"#/oneOf/7/required",keyword:"required",params:{missingProperty: missing30},message:"must have required property '"+missing30+"'"};
if(vErrors === null){
vErrors = [err157];
}
else {
vErrors.push(err157);
}
errors++;
}
else {
const _errs263 = errors;
for(const key30 in data){
if(!(key30 === "receipt")){
const err158 = {instancePath,schemaPath:"#/oneOf/7/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key30},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err158];
}
else {
vErrors.push(err158);
}
errors++;
break;
}
}
if(_errs263 === errors){
if(data.receipt !== undefined){
let data116 = data.receipt;
const _errs264 = errors;
if(errors === _errs264){
if(data116 && typeof data116 == "object" && !Array.isArray(data116)){
let missing31;
if((data116.position === undefined) && (missing31 = "position")){
const err159 = {instancePath:instancePath+"/receipt",schemaPath:"#/oneOf/7/properties/receipt/required",keyword:"required",params:{missingProperty: missing31},message:"must have required property '"+missing31+"'"};
if(vErrors === null){
vErrors = [err159];
}
else {
vErrors.push(err159);
}
errors++;
}
else {
const _errs266 = errors;
for(const key31 in data116){
if(!(key31 === "position")){
const err160 = {instancePath:instancePath+"/receipt",schemaPath:"#/oneOf/7/properties/receipt/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key31},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err160];
}
else {
vErrors.push(err160);
}
errors++;
break;
}
}
if(_errs266 === errors){
if(data116.position !== undefined){
if(!(validate55(data116.position, {instancePath:instancePath+"/receipt/position",parentData:data116,parentDataProperty:"position",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate55.errors : vErrors.concat(validate55.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err161 = {instancePath:instancePath+"/receipt",schemaPath:"#/oneOf/7/properties/receipt/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err161];
}
else {
vErrors.push(err161);
}
errors++;
}
}
}
}
}
}
else {
const err162 = {instancePath,schemaPath:"#/oneOf/7/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err162];
}
else {
vErrors.push(err162);
}
errors++;
}
}
var _valid0 = _errs261 === errors;
if(_valid0 && valid0){
valid0 = false;
passing0 = [passing0, 7];
}
else {
if(_valid0){
valid0 = true;
passing0 = 7;
if(props0 !== true){
props0 = true;
}
}
const _errs268 = errors;
if(errors === _errs268){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing32;
if((data.observation === undefined) && (missing32 = "observation")){
const err163 = {instancePath,schemaPath:"#/oneOf/8/required",keyword:"required",params:{missingProperty: missing32},message:"must have required property '"+missing32+"'"};
if(vErrors === null){
vErrors = [err163];
}
else {
vErrors.push(err163);
}
errors++;
}
else {
const _errs270 = errors;
for(const key32 in data){
if(!(key32 === "observation")){
const err164 = {instancePath,schemaPath:"#/oneOf/8/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key32},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err164];
}
else {
vErrors.push(err164);
}
errors++;
break;
}
}
if(_errs270 === errors){
if(data.observation !== undefined){
let data118 = data.observation;
const _errs272 = errors;
let valid51 = false;
let passing8 = null;
const _errs273 = errors;
if(errors === _errs273){
if(data118 && typeof data118 == "object" && !Array.isArray(data118)){
let missing33;
if((data118.pending === undefined) && (missing33 = "pending")){
const err165 = {instancePath:instancePath+"/observation",schemaPath:"#/oneOf/8/properties/observation/oneOf/0/required",keyword:"required",params:{missingProperty: missing33},message:"must have required property '"+missing33+"'"};
if(vErrors === null){
vErrors = [err165];
}
else {
vErrors.push(err165);
}
errors++;
}
else {
const _errs275 = errors;
for(const key33 in data118){
if(!(key33 === "pending")){
const err166 = {instancePath:instancePath+"/observation",schemaPath:"#/oneOf/8/properties/observation/oneOf/0/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key33},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err166];
}
else {
vErrors.push(err166);
}
errors++;
break;
}
}
if(_errs275 === errors){
if(data118.pending !== undefined){
let data119 = data118.pending;
const _errs276 = errors;
if(errors === _errs276){
if(data119 && typeof data119 == "object" && !Array.isArray(data119)){
if(Object.keys(data119).length > 0){
const err167 = {instancePath:instancePath+"/observation/pending",schemaPath:"#/oneOf/8/properties/observation/oneOf/0/properties/pending/maxProperties",keyword:"maxProperties",params:{limit: 0},message:"must NOT have more than 0 properties"};
if(vErrors === null){
vErrors = [err167];
}
else {
vErrors.push(err167);
}
errors++;
}
}
else {
const err168 = {instancePath:instancePath+"/observation/pending",schemaPath:"#/oneOf/8/properties/observation/oneOf/0/properties/pending/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err168];
}
else {
vErrors.push(err168);
}
errors++;
}
}
}
}
}
}
else {
const err169 = {instancePath:instancePath+"/observation",schemaPath:"#/oneOf/8/properties/observation/oneOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err169];
}
else {
vErrors.push(err169);
}
errors++;
}
}
var _valid11 = _errs273 === errors;
if(_valid11){
valid51 = true;
passing8 = 0;
var props10 = true;
}
const _errs278 = errors;
if(errors === _errs278){
if(data118 && typeof data118 == "object" && !Array.isArray(data118)){
let missing34;
if((data118.committed === undefined) && (missing34 = "committed")){
const err170 = {instancePath:instancePath+"/observation",schemaPath:"#/oneOf/8/properties/observation/oneOf/1/required",keyword:"required",params:{missingProperty: missing34},message:"must have required property '"+missing34+"'"};
if(vErrors === null){
vErrors = [err170];
}
else {
vErrors.push(err170);
}
errors++;
}
else {
const _errs280 = errors;
for(const key34 in data118){
if(!(key34 === "committed")){
const err171 = {instancePath:instancePath+"/observation",schemaPath:"#/oneOf/8/properties/observation/oneOf/1/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key34},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err171];
}
else {
vErrors.push(err171);
}
errors++;
break;
}
}
if(_errs280 === errors){
if(data118.committed !== undefined){
let data120 = data118.committed;
const _errs281 = errors;
if(errors === _errs281){
if(data120 && typeof data120 == "object" && !Array.isArray(data120)){
if(Object.keys(data120).length > 0){
const err172 = {instancePath:instancePath+"/observation/committed",schemaPath:"#/oneOf/8/properties/observation/oneOf/1/properties/committed/maxProperties",keyword:"maxProperties",params:{limit: 0},message:"must NOT have more than 0 properties"};
if(vErrors === null){
vErrors = [err172];
}
else {
vErrors.push(err172);
}
errors++;
}
}
else {
const err173 = {instancePath:instancePath+"/observation/committed",schemaPath:"#/oneOf/8/properties/observation/oneOf/1/properties/committed/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err173];
}
else {
vErrors.push(err173);
}
errors++;
}
}
}
}
}
}
else {
const err174 = {instancePath:instancePath+"/observation",schemaPath:"#/oneOf/8/properties/observation/oneOf/1/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err174];
}
else {
vErrors.push(err174);
}
errors++;
}
}
var _valid11 = _errs278 === errors;
if(_valid11 && valid51){
valid51 = false;
passing8 = [passing8, 1];
}
else {
if(_valid11){
valid51 = true;
passing8 = 1;
if(props10 !== true){
props10 = true;
}
}
const _errs283 = errors;
if(errors === _errs283){
if(data118 && typeof data118 == "object" && !Array.isArray(data118)){
let missing35;
if((data118.rejected === undefined) && (missing35 = "rejected")){
const err175 = {instancePath:instancePath+"/observation",schemaPath:"#/oneOf/8/properties/observation/oneOf/2/required",keyword:"required",params:{missingProperty: missing35},message:"must have required property '"+missing35+"'"};
if(vErrors === null){
vErrors = [err175];
}
else {
vErrors.push(err175);
}
errors++;
}
else {
const _errs285 = errors;
for(const key35 in data118){
if(!(key35 === "rejected")){
const err176 = {instancePath:instancePath+"/observation",schemaPath:"#/oneOf/8/properties/observation/oneOf/2/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key35},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err176];
}
else {
vErrors.push(err176);
}
errors++;
break;
}
}
if(_errs285 === errors){
if(data118.rejected !== undefined){
if(!(validate134(data118.rejected, {instancePath:instancePath+"/observation/rejected",parentData:data118,parentDataProperty:"rejected",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate134.errors : vErrors.concat(validate134.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err177 = {instancePath:instancePath+"/observation",schemaPath:"#/oneOf/8/properties/observation/oneOf/2/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err177];
}
else {
vErrors.push(err177);
}
errors++;
}
}
var _valid11 = _errs283 === errors;
if(_valid11 && valid51){
valid51 = false;
passing8 = [passing8, 2];
}
else {
if(_valid11){
valid51 = true;
passing8 = 2;
if(props10 !== true){
props10 = true;
}
}
}
}
if(!valid51){
const err178 = {instancePath:instancePath+"/observation",schemaPath:"#/oneOf/8/properties/observation/oneOf",keyword:"oneOf",params:{passingSchemas: passing8},message:"must match exactly one schema in oneOf"};
if(vErrors === null){
vErrors = [err178];
}
else {
vErrors.push(err178);
}
errors++;
}
else {
errors = _errs272;
if(vErrors !== null){
if(_errs272){
vErrors.length = _errs272;
}
else {
vErrors = null;
}
}
}
}
}
}
}
else {
const err179 = {instancePath,schemaPath:"#/oneOf/8/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err179];
}
else {
vErrors.push(err179);
}
errors++;
}
}
var _valid0 = _errs268 === errors;
if(_valid0 && valid0){
valid0 = false;
passing0 = [passing0, 8];
}
else {
if(_valid0){
valid0 = true;
passing0 = 8;
if(props0 !== true){
props0 = true;
}
}
const _errs287 = errors;
if(errors === _errs287){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing36;
if((data.status === undefined) && (missing36 = "status")){
const err180 = {instancePath,schemaPath:"#/oneOf/9/required",keyword:"required",params:{missingProperty: missing36},message:"must have required property '"+missing36+"'"};
if(vErrors === null){
vErrors = [err180];
}
else {
vErrors.push(err180);
}
errors++;
}
else {
const _errs289 = errors;
for(const key36 in data){
if(!(key36 === "status")){
const err181 = {instancePath,schemaPath:"#/oneOf/9/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key36},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err181];
}
else {
vErrors.push(err181);
}
errors++;
break;
}
}
if(_errs289 === errors){
if(data.status !== undefined){
let data122 = data.status;
const _errs291 = errors;
let valid56 = false;
const _errs292 = errors;
if(errors === _errs292){
if(data122 && typeof data122 == "object" && !Array.isArray(data122)){
let missing37;
if((((((((data122.reference === undefined) && (missing37 = "reference")) || ((data122.phase === undefined) && (missing37 = "phase"))) || ((data122.correlation === undefined) && (missing37 = "correlation"))) || ((data122.manifest === undefined) && (missing37 = "manifest"))) || ((data122.collected === undefined) && (missing37 = "collected"))) || ((data122.failure === undefined) && (missing37 = "failure"))) || ((data122.diagnostic === undefined) && (missing37 = "diagnostic"))){
const err182 = {instancePath:instancePath+"/status",schemaPath:"#/oneOf/9/properties/status/anyOf/0/required",keyword:"required",params:{missingProperty: missing37},message:"must have required property '"+missing37+"'"};
if(vErrors === null){
vErrors = [err182];
}
else {
vErrors.push(err182);
}
errors++;
}
else {
const _errs294 = errors;
for(const key37 in data122){
if(!(((((((key37 === "reference") || (key37 === "phase")) || (key37 === "correlation")) || (key37 === "manifest")) || (key37 === "collected")) || (key37 === "failure")) || (key37 === "diagnostic"))){
const err183 = {instancePath:instancePath+"/status",schemaPath:"#/oneOf/9/properties/status/anyOf/0/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key37},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err183];
}
else {
vErrors.push(err183);
}
errors++;
break;
}
}
if(_errs294 === errors){
if(data122.reference !== undefined){
const _errs295 = errors;
if(!(validate134(data122.reference, {instancePath:instancePath+"/status/reference",parentData:data122,parentDataProperty:"reference",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate134.errors : vErrors.concat(validate134.errors);
errors = vErrors.length;
}
var valid57 = _errs295 === errors;
}
else {
var valid57 = true;
}
if(valid57){
if(data122.phase !== undefined){
const _errs296 = errors;
if(!(validate473(data122.phase, {instancePath:instancePath+"/status/phase",parentData:data122,parentDataProperty:"phase",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate473.errors : vErrors.concat(validate473.errors);
errors = vErrors.length;
}
var valid57 = _errs296 === errors;
}
else {
var valid57 = true;
}
if(valid57){
if(data122.correlation !== undefined){
let data125 = data122.correlation;
const _errs297 = errors;
if(errors === _errs297){
if(typeof data125 === "string"){
if(func4(data125) > 131072){
const err184 = {instancePath:instancePath+"/status/correlation",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/correlation/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err184];
}
else {
vErrors.push(err184);
}
errors++;
}
}
else {
const err185 = {instancePath:instancePath+"/status/correlation",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/correlation/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err185];
}
else {
vErrors.push(err185);
}
errors++;
}
}
var valid57 = _errs297 === errors;
}
else {
var valid57 = true;
}
if(valid57){
if(data122.manifest !== undefined){
const _errs299 = errors;
if(!(validate133(data122.manifest, {instancePath:instancePath+"/status/manifest",parentData:data122,parentDataProperty:"manifest",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate133.errors : vErrors.concat(validate133.errors);
errors = vErrors.length;
}
var valid57 = _errs299 === errors;
}
else {
var valid57 = true;
}
if(valid57){
if(data122.collected !== undefined){
const _errs300 = errors;
if(typeof data122.collected !== "boolean"){
const err186 = {instancePath:instancePath+"/status/collected",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/collected/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"};
if(vErrors === null){
vErrors = [err186];
}
else {
vErrors.push(err186);
}
errors++;
}
var valid57 = _errs300 === errors;
}
else {
var valid57 = true;
}
if(valid57){
if(data122.failure !== undefined){
let data128 = data122.failure;
const _errs302 = errors;
const _errs303 = errors;
let valid58 = false;
const _errs304 = errors;
if(errors === _errs304){
if(data128 && typeof data128 == "object" && !Array.isArray(data128)){
let missing38;
if((((((data128.code === undefined) && (missing38 = "code")) || ((data128.stage === undefined) && (missing38 = "stage"))) || ((data128.dimension === undefined) && (missing38 = "dimension"))) || ((data128.limit === undefined) && (missing38 = "limit"))) || ((data128.observed === undefined) && (missing38 = "observed"))){
const err187 = {instancePath:instancePath+"/status/failure",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/failure/anyOf/0/required",keyword:"required",params:{missingProperty: missing38},message:"must have required property '"+missing38+"'"};
if(vErrors === null){
vErrors = [err187];
}
else {
vErrors.push(err187);
}
errors++;
}
else {
const _errs306 = errors;
for(const key38 in data128){
if(!(((((key38 === "code") || (key38 === "stage")) || (key38 === "dimension")) || (key38 === "limit")) || (key38 === "observed"))){
const err188 = {instancePath:instancePath+"/status/failure",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/failure/anyOf/0/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key38},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err188];
}
else {
vErrors.push(err188);
}
errors++;
break;
}
}
if(_errs306 === errors){
if(data128.code !== undefined){
const _errs307 = errors;
if(!(validate463(data128.code, {instancePath:instancePath+"/status/failure/code",parentData:data128,parentDataProperty:"code",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate463.errors : vErrors.concat(validate463.errors);
errors = vErrors.length;
}
var valid59 = _errs307 === errors;
}
else {
var valid59 = true;
}
if(valid59){
if(data128.stage !== undefined){
const _errs308 = errors;
if(!(validate465(data128.stage, {instancePath:instancePath+"/status/failure/stage",parentData:data128,parentDataProperty:"stage",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate465.errors : vErrors.concat(validate465.errors);
errors = vErrors.length;
}
var valid59 = _errs308 === errors;
}
else {
var valid59 = true;
}
if(valid59){
if(data128.dimension !== undefined){
const _errs309 = errors;
if(!(validate467(data128.dimension, {instancePath:instancePath+"/status/failure/dimension",parentData:data128,parentDataProperty:"dimension",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate467.errors : vErrors.concat(validate467.errors);
errors = vErrors.length;
}
var valid59 = _errs309 === errors;
}
else {
var valid59 = true;
}
if(valid59){
if(data128.limit !== undefined){
let data132 = data128.limit;
const _errs310 = errors;
if(errors === _errs310){
if(typeof data132 === "string"){
if(func4(data132) > 131072){
const err189 = {instancePath:instancePath+"/status/failure/limit",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/failure/anyOf/0/properties/limit/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err189];
}
else {
vErrors.push(err189);
}
errors++;
}
}
else {
const err190 = {instancePath:instancePath+"/status/failure/limit",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/failure/anyOf/0/properties/limit/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err190];
}
else {
vErrors.push(err190);
}
errors++;
}
}
var valid59 = _errs310 === errors;
}
else {
var valid59 = true;
}
if(valid59){
if(data128.observed !== undefined){
let data133 = data128.observed;
const _errs312 = errors;
if(errors === _errs312){
if(typeof data133 === "string"){
if(func4(data133) > 131072){
const err191 = {instancePath:instancePath+"/status/failure/observed",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/failure/anyOf/0/properties/observed/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err191];
}
else {
vErrors.push(err191);
}
errors++;
}
}
else {
const err192 = {instancePath:instancePath+"/status/failure/observed",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/failure/anyOf/0/properties/observed/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err192];
}
else {
vErrors.push(err192);
}
errors++;
}
}
var valid59 = _errs312 === errors;
}
else {
var valid59 = true;
}
}
}
}
}
}
}
}
else {
const err193 = {instancePath:instancePath+"/status/failure",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/failure/anyOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err193];
}
else {
vErrors.push(err193);
}
errors++;
}
}
var _valid13 = _errs304 === errors;
valid58 = valid58 || _valid13;
const _errs314 = errors;
if(data128 !== null){
const err194 = {instancePath:instancePath+"/status/failure",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/failure/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err194];
}
else {
vErrors.push(err194);
}
errors++;
}
var _valid13 = _errs314 === errors;
valid58 = valid58 || _valid13;
if(!valid58){
const err195 = {instancePath:instancePath+"/status/failure",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/failure/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err195];
}
else {
vErrors.push(err195);
}
errors++;
}
else {
errors = _errs303;
if(vErrors !== null){
if(_errs303){
vErrors.length = _errs303;
}
else {
vErrors = null;
}
}
}
var valid57 = _errs302 === errors;
}
else {
var valid57 = true;
}
if(valid57){
if(data122.diagnostic !== undefined){
const _errs316 = errors;
if(!(validate197(data122.diagnostic, {instancePath:instancePath+"/status/diagnostic",parentData:data122,parentDataProperty:"diagnostic",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate197.errors : vErrors.concat(validate197.errors);
errors = vErrors.length;
}
var valid57 = _errs316 === errors;
}
else {
var valid57 = true;
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
const err196 = {instancePath:instancePath+"/status",schemaPath:"#/oneOf/9/properties/status/anyOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err196];
}
else {
vErrors.push(err196);
}
errors++;
}
}
var _valid12 = _errs292 === errors;
valid56 = valid56 || _valid12;
const _errs317 = errors;
if(data122 !== null){
const err197 = {instancePath:instancePath+"/status",schemaPath:"#/oneOf/9/properties/status/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err197];
}
else {
vErrors.push(err197);
}
errors++;
}
var _valid12 = _errs317 === errors;
valid56 = valid56 || _valid12;
if(!valid56){
const err198 = {instancePath:instancePath+"/status",schemaPath:"#/oneOf/9/properties/status/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err198];
}
else {
vErrors.push(err198);
}
errors++;
}
else {
errors = _errs291;
if(vErrors !== null){
if(_errs291){
vErrors.length = _errs291;
}
else {
vErrors = null;
}
}
}
}
}
}
}
else {
const err199 = {instancePath,schemaPath:"#/oneOf/9/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err199];
}
else {
vErrors.push(err199);
}
errors++;
}
}
var _valid0 = _errs287 === errors;
if(_valid0 && valid0){
valid0 = false;
passing0 = [passing0, 9];
}
else {
if(_valid0){
valid0 = true;
passing0 = 9;
if(props0 !== true){
props0 = true;
}
}
const _errs319 = errors;
if(errors === _errs319){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing39;
if((data.page === undefined) && (missing39 = "page")){
const err200 = {instancePath,schemaPath:"#/oneOf/10/required",keyword:"required",params:{missingProperty: missing39},message:"must have required property '"+missing39+"'"};
if(vErrors === null){
vErrors = [err200];
}
else {
vErrors.push(err200);
}
errors++;
}
else {
const _errs321 = errors;
for(const key39 in data){
if(!(key39 === "page")){
const err201 = {instancePath,schemaPath:"#/oneOf/10/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key39},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err201];
}
else {
vErrors.push(err201);
}
errors++;
break;
}
}
if(_errs321 === errors){
if(data.page !== undefined){
let data135 = data.page;
const _errs322 = errors;
if(errors === _errs322){
if(data135 && typeof data135 == "object" && !Array.isArray(data135)){
let missing40;
if(((data135.evidence === undefined) && (missing40 = "evidence")) || ((data135.cells === undefined) && (missing40 = "cells"))){
const err202 = {instancePath:instancePath+"/page",schemaPath:"#/oneOf/10/properties/page/required",keyword:"required",params:{missingProperty: missing40},message:"must have required property '"+missing40+"'"};
if(vErrors === null){
vErrors = [err202];
}
else {
vErrors.push(err202);
}
errors++;
}
else {
const _errs324 = errors;
for(const key40 in data135){
if(!((key40 === "evidence") || (key40 === "cells"))){
const err203 = {instancePath:instancePath+"/page",schemaPath:"#/oneOf/10/properties/page/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key40},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err203];
}
else {
vErrors.push(err203);
}
errors++;
break;
}
}
if(_errs324 === errors){
if(data135.evidence !== undefined){
let data136 = data135.evidence;
const _errs325 = errors;
if(errors === _errs325){
if(data136 && typeof data136 == "object" && !Array.isArray(data136)){
let missing41;
if(((((((data136.manifest === undefined) && (missing41 = "manifest")) || ((data136.columns === undefined) && (missing41 = "columns"))) || ((data136.ordinal === undefined) && (missing41 = "ordinal"))) || ((data136.rows === undefined) && (missing41 = "rows"))) || ((data136.ipc === undefined) && (missing41 = "ipc"))) || ((data136.next === undefined) && (missing41 = "next"))){
const err204 = {instancePath:instancePath+"/page/evidence",schemaPath:"#/oneOf/10/properties/page/properties/evidence/required",keyword:"required",params:{missingProperty: missing41},message:"must have required property '"+missing41+"'"};
if(vErrors === null){
vErrors = [err204];
}
else {
vErrors.push(err204);
}
errors++;
}
else {
const _errs327 = errors;
for(const key41 in data136){
if(!((((((key41 === "manifest") || (key41 === "columns")) || (key41 === "ordinal")) || (key41 === "rows")) || (key41 === "ipc")) || (key41 === "next"))){
const err205 = {instancePath:instancePath+"/page/evidence",schemaPath:"#/oneOf/10/properties/page/properties/evidence/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key41},message:"must NOT have additional properties"};
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
if(_errs327 === errors){
if(data136.manifest !== undefined){
let data137 = data136.manifest;
const _errs328 = errors;
if(errors === _errs328){
if(data137 && typeof data137 == "object" && !Array.isArray(data137)){
let missing42;
if(((((((((((((((((((data137.job === undefined) && (missing42 = "job")) || ((data137.source === undefined) && (missing42 = "source"))) || ((data137.requester === undefined) && (missing42 = "requester"))) || ((data137.correlation === undefined) && (missing42 = "correlation"))) || ((data137.policy_revision === undefined) && (missing42 = "policy_revision"))) || ((data137.request === undefined) && (missing42 = "request"))) || ((data137.basis === undefined) && (missing42 = "basis"))) || ((data137.plan === undefined) && (missing42 = "plan"))) || ((data137.pages === undefined) && (missing42 = "pages"))) || ((data137.scanned === undefined) && (missing42 = "scanned"))) || ((data137.selected === undefined) && (missing42 = "selected"))) || ((data137.value_count === undefined) && (missing42 = "value_count"))) || ((data137.segments === undefined) && (missing42 = "segments"))) || ((data137.rows === undefined) && (missing42 = "rows"))) || ((data137.bytes === undefined) && (missing42 = "bytes"))) || ((data137.sum === undefined) && (missing42 = "sum"))) || ((data137.finished === undefined) && (missing42 = "finished"))) || ((data137.chain === undefined) && (missing42 = "chain"))){
const err206 = {instancePath:instancePath+"/page/evidence/manifest",schemaPath:"#/oneOf/10/properties/page/properties/evidence/properties/manifest/required",keyword:"required",params:{missingProperty: missing42},message:"must have required property '"+missing42+"'"};
if(vErrors === null){
vErrors = [err206];
}
else {
vErrors.push(err206);
}
errors++;
}
else {
const _errs330 = errors;
for(const key42 in data137){
if(!(func1.call(schema135.oneOf[10].properties.page.properties.evidence.properties.manifest.properties, key42))){
const err207 = {instancePath:instancePath+"/page/evidence/manifest",schemaPath:"#/oneOf/10/properties/page/properties/evidence/properties/manifest/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key42},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err207];
}
else {
vErrors.push(err207);
}
errors++;
break;
}
}
if(_errs330 === errors){
if(data137.job !== undefined){
const _errs331 = errors;
if(!(validate55(data137.job, {instancePath:instancePath+"/page/evidence/manifest/job",parentData:data137,parentDataProperty:"job",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate55.errors : vErrors.concat(validate55.errors);
errors = vErrors.length;
}
var valid63 = _errs331 === errors;
}
else {
var valid63 = true;
}
if(valid63){
if(data137.source !== undefined){
const _errs332 = errors;
if(!(validate455(data137.source, {instancePath:instancePath+"/page/evidence/manifest/source",parentData:data137,parentDataProperty:"source",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate455.errors : vErrors.concat(validate455.errors);
errors = vErrors.length;
}
var valid63 = _errs332 === errors;
}
else {
var valid63 = true;
}
if(valid63){
if(data137.requester !== undefined){
const _errs333 = errors;
if(!(validate55(data137.requester, {instancePath:instancePath+"/page/evidence/manifest/requester",parentData:data137,parentDataProperty:"requester",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate55.errors : vErrors.concat(validate55.errors);
errors = vErrors.length;
}
var valid63 = _errs333 === errors;
}
else {
var valid63 = true;
}
if(valid63){
if(data137.correlation !== undefined){
let data141 = data137.correlation;
const _errs334 = errors;
if(errors === _errs334){
if(typeof data141 === "string"){
if(func4(data141) > 131072){
const err208 = {instancePath:instancePath+"/page/evidence/manifest/correlation",schemaPath:"#/oneOf/10/properties/page/properties/evidence/properties/manifest/properties/correlation/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err208];
}
else {
vErrors.push(err208);
}
errors++;
}
}
else {
const err209 = {instancePath:instancePath+"/page/evidence/manifest/correlation",schemaPath:"#/oneOf/10/properties/page/properties/evidence/properties/manifest/properties/correlation/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err209];
}
else {
vErrors.push(err209);
}
errors++;
}
}
var valid63 = _errs334 === errors;
}
else {
var valid63 = true;
}
if(valid63){
if(data137.policy_revision !== undefined){
let data142 = data137.policy_revision;
const _errs336 = errors;
if(errors === _errs336){
if(typeof data142 === "string"){
if(func4(data142) > 131072){
const err210 = {instancePath:instancePath+"/page/evidence/manifest/policy_revision",schemaPath:"#/oneOf/10/properties/page/properties/evidence/properties/manifest/properties/policy_revision/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err210];
}
else {
vErrors.push(err210);
}
errors++;
}
}
else {
const err211 = {instancePath:instancePath+"/page/evidence/manifest/policy_revision",schemaPath:"#/oneOf/10/properties/page/properties/evidence/properties/manifest/properties/policy_revision/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err211];
}
else {
vErrors.push(err211);
}
errors++;
}
}
var valid63 = _errs336 === errors;
}
else {
var valid63 = true;
}
if(valid63){
if(data137.request !== undefined){
const _errs338 = errors;
if(!(validate134(data137.request, {instancePath:instancePath+"/page/evidence/manifest/request",parentData:data137,parentDataProperty:"request",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate134.errors : vErrors.concat(validate134.errors);
errors = vErrors.length;
}
var valid63 = _errs338 === errors;
}
else {
var valid63 = true;
}
if(valid63){
if(data137.basis !== undefined){
const _errs339 = errors;
if(!(validate489(data137.basis, {instancePath:instancePath+"/page/evidence/manifest/basis",parentData:data137,parentDataProperty:"basis",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate489.errors : vErrors.concat(validate489.errors);
errors = vErrors.length;
}
var valid63 = _errs339 === errors;
}
else {
var valid63 = true;
}
if(valid63){
if(data137.plan !== undefined){
const _errs340 = errors;
if(!(validate105(data137.plan, {instancePath:instancePath+"/page/evidence/manifest/plan",parentData:data137,parentDataProperty:"plan",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate105.errors : vErrors.concat(validate105.errors);
errors = vErrors.length;
}
var valid63 = _errs340 === errors;
}
else {
var valid63 = true;
}
if(valid63){
if(data137.pages !== undefined){
let data146 = data137.pages;
const _errs341 = errors;
if(errors === _errs341){
if(typeof data146 === "string"){
if(func4(data146) > 131072){
const err212 = {instancePath:instancePath+"/page/evidence/manifest/pages",schemaPath:"#/oneOf/10/properties/page/properties/evidence/properties/manifest/properties/pages/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err212];
}
else {
vErrors.push(err212);
}
errors++;
}
}
else {
const err213 = {instancePath:instancePath+"/page/evidence/manifest/pages",schemaPath:"#/oneOf/10/properties/page/properties/evidence/properties/manifest/properties/pages/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err213];
}
else {
vErrors.push(err213);
}
errors++;
}
}
var valid63 = _errs341 === errors;
}
else {
var valid63 = true;
}
if(valid63){
if(data137.scanned !== undefined){
let data147 = data137.scanned;
const _errs343 = errors;
if(errors === _errs343){
if(typeof data147 === "string"){
if(func4(data147) > 131072){
const err214 = {instancePath:instancePath+"/page/evidence/manifest/scanned",schemaPath:"#/oneOf/10/properties/page/properties/evidence/properties/manifest/properties/scanned/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err214];
}
else {
vErrors.push(err214);
}
errors++;
}
}
else {
const err215 = {instancePath:instancePath+"/page/evidence/manifest/scanned",schemaPath:"#/oneOf/10/properties/page/properties/evidence/properties/manifest/properties/scanned/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err215];
}
else {
vErrors.push(err215);
}
errors++;
}
}
var valid63 = _errs343 === errors;
}
else {
var valid63 = true;
}
if(valid63){
if(data137.selected !== undefined){
let data148 = data137.selected;
const _errs345 = errors;
if(errors === _errs345){
if(typeof data148 === "string"){
if(func4(data148) > 131072){
const err216 = {instancePath:instancePath+"/page/evidence/manifest/selected",schemaPath:"#/oneOf/10/properties/page/properties/evidence/properties/manifest/properties/selected/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err216];
}
else {
vErrors.push(err216);
}
errors++;
}
}
else {
const err217 = {instancePath:instancePath+"/page/evidence/manifest/selected",schemaPath:"#/oneOf/10/properties/page/properties/evidence/properties/manifest/properties/selected/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err217];
}
else {
vErrors.push(err217);
}
errors++;
}
}
var valid63 = _errs345 === errors;
}
else {
var valid63 = true;
}
if(valid63){
if(data137.value_count !== undefined){
let data149 = data137.value_count;
const _errs347 = errors;
if(errors === _errs347){
if(typeof data149 === "string"){
if(func4(data149) > 131072){
const err218 = {instancePath:instancePath+"/page/evidence/manifest/value_count",schemaPath:"#/oneOf/10/properties/page/properties/evidence/properties/manifest/properties/value_count/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err218];
}
else {
vErrors.push(err218);
}
errors++;
}
}
else {
const err219 = {instancePath:instancePath+"/page/evidence/manifest/value_count",schemaPath:"#/oneOf/10/properties/page/properties/evidence/properties/manifest/properties/value_count/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err219];
}
else {
vErrors.push(err219);
}
errors++;
}
}
var valid63 = _errs347 === errors;
}
else {
var valid63 = true;
}
if(valid63){
if(data137.segments !== undefined){
let data150 = data137.segments;
const _errs349 = errors;
if(errors === _errs349){
if(typeof data150 === "string"){
if(func4(data150) > 131072){
const err220 = {instancePath:instancePath+"/page/evidence/manifest/segments",schemaPath:"#/oneOf/10/properties/page/properties/evidence/properties/manifest/properties/segments/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err220];
}
else {
vErrors.push(err220);
}
errors++;
}
}
else {
const err221 = {instancePath:instancePath+"/page/evidence/manifest/segments",schemaPath:"#/oneOf/10/properties/page/properties/evidence/properties/manifest/properties/segments/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err221];
}
else {
vErrors.push(err221);
}
errors++;
}
}
var valid63 = _errs349 === errors;
}
else {
var valid63 = true;
}
if(valid63){
if(data137.rows !== undefined){
let data151 = data137.rows;
const _errs351 = errors;
if(errors === _errs351){
if(typeof data151 === "string"){
if(func4(data151) > 131072){
const err222 = {instancePath:instancePath+"/page/evidence/manifest/rows",schemaPath:"#/oneOf/10/properties/page/properties/evidence/properties/manifest/properties/rows/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err222];
}
else {
vErrors.push(err222);
}
errors++;
}
}
else {
const err223 = {instancePath:instancePath+"/page/evidence/manifest/rows",schemaPath:"#/oneOf/10/properties/page/properties/evidence/properties/manifest/properties/rows/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err223];
}
else {
vErrors.push(err223);
}
errors++;
}
}
var valid63 = _errs351 === errors;
}
else {
var valid63 = true;
}
if(valid63){
if(data137.bytes !== undefined){
let data152 = data137.bytes;
const _errs353 = errors;
if(errors === _errs353){
if(typeof data152 === "string"){
if(func4(data152) > 131072){
const err224 = {instancePath:instancePath+"/page/evidence/manifest/bytes",schemaPath:"#/oneOf/10/properties/page/properties/evidence/properties/manifest/properties/bytes/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err224];
}
else {
vErrors.push(err224);
}
errors++;
}
}
else {
const err225 = {instancePath:instancePath+"/page/evidence/manifest/bytes",schemaPath:"#/oneOf/10/properties/page/properties/evidence/properties/manifest/properties/bytes/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err225];
}
else {
vErrors.push(err225);
}
errors++;
}
}
var valid63 = _errs353 === errors;
}
else {
var valid63 = true;
}
if(valid63){
if(data137.sum !== undefined){
const _errs355 = errors;
if(!(validate597(data137.sum, {instancePath:instancePath+"/page/evidence/manifest/sum",parentData:data137,parentDataProperty:"sum",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate597.errors : vErrors.concat(validate597.errors);
errors = vErrors.length;
}
var valid63 = _errs355 === errors;
}
else {
var valid63 = true;
}
if(valid63){
if(data137.finished !== undefined){
let data154 = data137.finished;
const _errs356 = errors;
const _errs357 = errors;
let valid64 = false;
const _errs358 = errors;
if(typeof data154 !== "string"){
const err226 = {instancePath:instancePath+"/page/evidence/manifest/finished",schemaPath:"#/oneOf/10/properties/page/properties/evidence/properties/manifest/properties/finished/anyOf/0/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err226];
}
else {
vErrors.push(err226);
}
errors++;
}
if(!((data154 === "source_end") || (data154 === "limit"))){
const err227 = {instancePath:instancePath+"/page/evidence/manifest/finished",schemaPath:"#/oneOf/10/properties/page/properties/evidence/properties/manifest/properties/finished/anyOf/0/enum",keyword:"enum",params:{allowedValues: schema135.oneOf[10].properties.page.properties.evidence.properties.manifest.properties.finished.anyOf[0].enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err227];
}
else {
vErrors.push(err227);
}
errors++;
}
var _valid14 = _errs358 === errors;
valid64 = valid64 || _valid14;
const _errs360 = errors;
if(data154 !== null){
const err228 = {instancePath:instancePath+"/page/evidence/manifest/finished",schemaPath:"#/oneOf/10/properties/page/properties/evidence/properties/manifest/properties/finished/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err228];
}
else {
vErrors.push(err228);
}
errors++;
}
var _valid14 = _errs360 === errors;
valid64 = valid64 || _valid14;
if(!valid64){
const err229 = {instancePath:instancePath+"/page/evidence/manifest/finished",schemaPath:"#/oneOf/10/properties/page/properties/evidence/properties/manifest/properties/finished/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err229];
}
else {
vErrors.push(err229);
}
errors++;
}
else {
errors = _errs357;
if(vErrors !== null){
if(_errs357){
vErrors.length = _errs357;
}
else {
vErrors = null;
}
}
}
var valid63 = _errs356 === errors;
}
else {
var valid63 = true;
}
if(valid63){
if(data137.chain !== undefined){
const _errs362 = errors;
if(!(validate105(data137.chain, {instancePath:instancePath+"/page/evidence/manifest/chain",parentData:data137,parentDataProperty:"chain",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate105.errors : vErrors.concat(validate105.errors);
errors = vErrors.length;
}
var valid63 = _errs362 === errors;
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
const err230 = {instancePath:instancePath+"/page/evidence/manifest",schemaPath:"#/oneOf/10/properties/page/properties/evidence/properties/manifest/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err230];
}
else {
vErrors.push(err230);
}
errors++;
}
}
var valid62 = _errs328 === errors;
}
else {
var valid62 = true;
}
if(valid62){
if(data136.columns !== undefined){
const _errs363 = errors;
if(!(validate677(data136.columns, {instancePath:instancePath+"/page/evidence/columns",parentData:data136,parentDataProperty:"columns",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate677.errors : vErrors.concat(validate677.errors);
errors = vErrors.length;
}
var valid62 = _errs363 === errors;
}
else {
var valid62 = true;
}
if(valid62){
if(data136.ordinal !== undefined){
let data157 = data136.ordinal;
const _errs364 = errors;
if(errors === _errs364){
if(typeof data157 === "string"){
if(func4(data157) > 131072){
const err231 = {instancePath:instancePath+"/page/evidence/ordinal",schemaPath:"#/oneOf/10/properties/page/properties/evidence/properties/ordinal/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err231];
}
else {
vErrors.push(err231);
}
errors++;
}
}
else {
const err232 = {instancePath:instancePath+"/page/evidence/ordinal",schemaPath:"#/oneOf/10/properties/page/properties/evidence/properties/ordinal/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err232];
}
else {
vErrors.push(err232);
}
errors++;
}
}
var valid62 = _errs364 === errors;
}
else {
var valid62 = true;
}
if(valid62){
if(data136.rows !== undefined){
const _errs366 = errors;
if(!(validate102(data136.rows, {instancePath:instancePath+"/page/evidence/rows",parentData:data136,parentDataProperty:"rows",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate102.errors : vErrors.concat(validate102.errors);
errors = vErrors.length;
}
var valid62 = _errs366 === errors;
}
else {
var valid62 = true;
}
if(valid62){
if(data136.ipc !== undefined){
let data159 = data136.ipc;
const _errs367 = errors;
if(errors === _errs367){
if(typeof data159 === "string"){
if(func4(data159) > 131072){
const err233 = {instancePath:instancePath+"/page/evidence/ipc",schemaPath:"#/oneOf/10/properties/page/properties/evidence/properties/ipc/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err233];
}
else {
vErrors.push(err233);
}
errors++;
}
}
else {
const err234 = {instancePath:instancePath+"/page/evidence/ipc",schemaPath:"#/oneOf/10/properties/page/properties/evidence/properties/ipc/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err234];
}
else {
vErrors.push(err234);
}
errors++;
}
}
var valid62 = _errs367 === errors;
}
else {
var valid62 = true;
}
if(valid62){
if(data136.next !== undefined){
const _errs369 = errors;
if(!(validate597(data136.next, {instancePath:instancePath+"/page/evidence/next",parentData:data136,parentDataProperty:"next",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate597.errors : vErrors.concat(validate597.errors);
errors = vErrors.length;
}
var valid62 = _errs369 === errors;
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
}
}
else {
const err235 = {instancePath:instancePath+"/page/evidence",schemaPath:"#/oneOf/10/properties/page/properties/evidence/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err235];
}
else {
vErrors.push(err235);
}
errors++;
}
}
var valid61 = _errs325 === errors;
}
else {
var valid61 = true;
}
if(valid61){
if(data135.cells !== undefined){
let data161 = data135.cells;
const _errs370 = errors;
if(errors === _errs370){
if(Array.isArray(data161)){
if(data161.length > 8){
const err236 = {instancePath:instancePath+"/page/cells",schemaPath:"#/oneOf/10/properties/page/properties/cells/maxItems",keyword:"maxItems",params:{limit: 8},message:"must NOT have more than 8 items"};
if(vErrors === null){
vErrors = [err236];
}
else {
vErrors.push(err236);
}
errors++;
}
else {
var valid65 = true;
const len7 = data161.length;
for(let i7=0; i7<len7; i7++){
let data162 = data161[i7];
const _errs372 = errors;
if(errors === _errs372){
if(Array.isArray(data162)){
if(data162.length > 8){
const err237 = {instancePath:instancePath+"/page/cells/" + i7,schemaPath:"#/oneOf/10/properties/page/properties/cells/items/maxItems",keyword:"maxItems",params:{limit: 8},message:"must NOT have more than 8 items"};
if(vErrors === null){
vErrors = [err237];
}
else {
vErrors.push(err237);
}
errors++;
}
else {
var valid66 = true;
const len8 = data162.length;
for(let i8=0; i8<len8; i8++){
let data163 = data162[i8];
const _errs374 = errors;
const _errs375 = errors;
let valid67 = false;
let passing9 = null;
const _errs376 = errors;
if(errors === _errs376){
if(data163 && typeof data163 == "object" && !Array.isArray(data163)){
let missing43;
if((data163.missing === undefined) && (missing43 = "missing")){
const err238 = {instancePath:instancePath+"/page/cells/" + i7+"/" + i8,schemaPath:"#/oneOf/10/properties/page/properties/cells/items/items/oneOf/0/required",keyword:"required",params:{missingProperty: missing43},message:"must have required property '"+missing43+"'"};
if(vErrors === null){
vErrors = [err238];
}
else {
vErrors.push(err238);
}
errors++;
}
else {
const _errs378 = errors;
for(const key43 in data163){
if(!(key43 === "missing")){
const err239 = {instancePath:instancePath+"/page/cells/" + i7+"/" + i8,schemaPath:"#/oneOf/10/properties/page/properties/cells/items/items/oneOf/0/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key43},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err239];
}
else {
vErrors.push(err239);
}
errors++;
break;
}
}
if(_errs378 === errors){
if(data163.missing !== undefined){
let data164 = data163.missing;
const _errs379 = errors;
if(errors === _errs379){
if(data164 && typeof data164 == "object" && !Array.isArray(data164)){
if(Object.keys(data164).length > 0){
const err240 = {instancePath:instancePath+"/page/cells/" + i7+"/" + i8+"/missing",schemaPath:"#/oneOf/10/properties/page/properties/cells/items/items/oneOf/0/properties/missing/maxProperties",keyword:"maxProperties",params:{limit: 0},message:"must NOT have more than 0 properties"};
if(vErrors === null){
vErrors = [err240];
}
else {
vErrors.push(err240);
}
errors++;
}
}
else {
const err241 = {instancePath:instancePath+"/page/cells/" + i7+"/" + i8+"/missing",schemaPath:"#/oneOf/10/properties/page/properties/cells/items/items/oneOf/0/properties/missing/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err241];
}
else {
vErrors.push(err241);
}
errors++;
}
}
}
}
}
}
else {
const err242 = {instancePath:instancePath+"/page/cells/" + i7+"/" + i8,schemaPath:"#/oneOf/10/properties/page/properties/cells/items/items/oneOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err242];
}
else {
vErrors.push(err242);
}
errors++;
}
}
var _valid15 = _errs376 === errors;
if(_valid15){
valid67 = true;
passing9 = 0;
var props14 = true;
}
const _errs381 = errors;
if(!(validate780(data163, {instancePath:instancePath+"/page/cells/" + i7+"/" + i8,parentData:data162,parentDataProperty:i8,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate780.errors : vErrors.concat(validate780.errors);
errors = vErrors.length;
}
var _valid15 = _errs381 === errors;
if(_valid15 && valid67){
valid67 = false;
passing9 = [passing9, 1];
}
else {
if(_valid15){
valid67 = true;
passing9 = 1;
if(props14 !== true){
props14 = true;
}
}
const _errs382 = errors;
if(!(validate782(data163, {instancePath:instancePath+"/page/cells/" + i7+"/" + i8,parentData:data162,parentDataProperty:i8,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate782.errors : vErrors.concat(validate782.errors);
errors = vErrors.length;
}
var _valid15 = _errs382 === errors;
if(_valid15 && valid67){
valid67 = false;
passing9 = [passing9, 2];
}
else {
if(_valid15){
valid67 = true;
passing9 = 2;
if(props14 !== true){
props14 = true;
}
}
const _errs383 = errors;
if(!(validate786(data163, {instancePath:instancePath+"/page/cells/" + i7+"/" + i8,parentData:data162,parentDataProperty:i8,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate786.errors : vErrors.concat(validate786.errors);
errors = vErrors.length;
}
var _valid15 = _errs383 === errors;
if(_valid15 && valid67){
valid67 = false;
passing9 = [passing9, 3];
}
else {
if(_valid15){
valid67 = true;
passing9 = 3;
if(props14 !== true){
props14 = true;
}
}
const _errs384 = errors;
if(errors === _errs384){
if(data163 && typeof data163 == "object" && !Array.isArray(data163)){
let missing44;
if((data163.conflict === undefined) && (missing44 = "conflict")){
const err243 = {instancePath:instancePath+"/page/cells/" + i7+"/" + i8,schemaPath:"#/oneOf/10/properties/page/properties/cells/items/items/oneOf/4/required",keyword:"required",params:{missingProperty: missing44},message:"must have required property '"+missing44+"'"};
if(vErrors === null){
vErrors = [err243];
}
else {
vErrors.push(err243);
}
errors++;
}
else {
const _errs386 = errors;
for(const key44 in data163){
if(!(key44 === "conflict")){
const err244 = {instancePath:instancePath+"/page/cells/" + i7+"/" + i8,schemaPath:"#/oneOf/10/properties/page/properties/cells/items/items/oneOf/4/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key44},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err244];
}
else {
vErrors.push(err244);
}
errors++;
break;
}
}
if(_errs386 === errors){
if(data163.conflict !== undefined){
let data165 = data163.conflict;
const _errs387 = errors;
if(errors === _errs387){
if(Array.isArray(data165)){
if(data165.length > 8){
const err245 = {instancePath:instancePath+"/page/cells/" + i7+"/" + i8+"/conflict",schemaPath:"#/oneOf/10/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/maxItems",keyword:"maxItems",params:{limit: 8},message:"must NOT have more than 8 items"};
if(vErrors === null){
vErrors = [err245];
}
else {
vErrors.push(err245);
}
errors++;
}
else {
var valid70 = true;
const len9 = data165.length;
for(let i9=0; i9<len9; i9++){
let data166 = data165[i9];
const _errs389 = errors;
if(errors === _errs389){
if(data166 && typeof data166 == "object" && !Array.isArray(data166)){
let missing45;
if((((data166.counter === undefined) && (missing45 = "counter")) || ((data166.replica === undefined) && (missing45 = "replica"))) || ((data166.value === undefined) && (missing45 = "value"))){
const err246 = {instancePath:instancePath+"/page/cells/" + i7+"/" + i8+"/conflict/" + i9,schemaPath:"#/oneOf/10/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/required",keyword:"required",params:{missingProperty: missing45},message:"must have required property '"+missing45+"'"};
if(vErrors === null){
vErrors = [err246];
}
else {
vErrors.push(err246);
}
errors++;
}
else {
const _errs391 = errors;
for(const key45 in data166){
if(!(((key45 === "counter") || (key45 === "replica")) || (key45 === "value"))){
const err247 = {instancePath:instancePath+"/page/cells/" + i7+"/" + i8+"/conflict/" + i9,schemaPath:"#/oneOf/10/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key45},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err247];
}
else {
vErrors.push(err247);
}
errors++;
break;
}
}
if(_errs391 === errors){
if(data166.counter !== undefined){
let data167 = data166.counter;
const _errs392 = errors;
if(errors === _errs392){
if(typeof data167 === "string"){
if(func4(data167) > 131072){
const err248 = {instancePath:instancePath+"/page/cells/" + i7+"/" + i8+"/conflict/" + i9+"/counter",schemaPath:"#/oneOf/10/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/properties/counter/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err248];
}
else {
vErrors.push(err248);
}
errors++;
}
}
else {
const err249 = {instancePath:instancePath+"/page/cells/" + i7+"/" + i8+"/conflict/" + i9+"/counter",schemaPath:"#/oneOf/10/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/properties/counter/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err249];
}
else {
vErrors.push(err249);
}
errors++;
}
}
var valid71 = _errs392 === errors;
}
else {
var valid71 = true;
}
if(valid71){
if(data166.replica !== undefined){
let data168 = data166.replica;
const _errs394 = errors;
if(errors === _errs394){
if(typeof data168 === "string"){
if(func4(data168) > 131072){
const err250 = {instancePath:instancePath+"/page/cells/" + i7+"/" + i8+"/conflict/" + i9+"/replica",schemaPath:"#/oneOf/10/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/properties/replica/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err250];
}
else {
vErrors.push(err250);
}
errors++;
}
}
else {
const err251 = {instancePath:instancePath+"/page/cells/" + i7+"/" + i8+"/conflict/" + i9+"/replica",schemaPath:"#/oneOf/10/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/properties/replica/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err251];
}
else {
vErrors.push(err251);
}
errors++;
}
}
var valid71 = _errs394 === errors;
}
else {
var valid71 = true;
}
if(valid71){
if(data166.value !== undefined){
let data169 = data166.value;
const _errs396 = errors;
const _errs397 = errors;
let valid72 = false;
let passing10 = null;
const _errs398 = errors;
if(!(validate780(data169, {instancePath:instancePath+"/page/cells/" + i7+"/" + i8+"/conflict/" + i9+"/value",parentData:data166,parentDataProperty:"value",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate780.errors : vErrors.concat(validate780.errors);
errors = vErrors.length;
}
var _valid16 = _errs398 === errors;
if(_valid16){
valid72 = true;
passing10 = 0;
var props15 = true;
}
const _errs399 = errors;
if(!(validate782(data169, {instancePath:instancePath+"/page/cells/" + i7+"/" + i8+"/conflict/" + i9+"/value",parentData:data166,parentDataProperty:"value",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate782.errors : vErrors.concat(validate782.errors);
errors = vErrors.length;
}
var _valid16 = _errs399 === errors;
if(_valid16 && valid72){
valid72 = false;
passing10 = [passing10, 1];
}
else {
if(_valid16){
valid72 = true;
passing10 = 1;
if(props15 !== true){
props15 = true;
}
}
const _errs400 = errors;
if(!(validate786(data169, {instancePath:instancePath+"/page/cells/" + i7+"/" + i8+"/conflict/" + i9+"/value",parentData:data166,parentDataProperty:"value",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate786.errors : vErrors.concat(validate786.errors);
errors = vErrors.length;
}
var _valid16 = _errs400 === errors;
if(_valid16 && valid72){
valid72 = false;
passing10 = [passing10, 2];
}
else {
if(_valid16){
valid72 = true;
passing10 = 2;
if(props15 !== true){
props15 = true;
}
}
}
}
if(!valid72){
const err252 = {instancePath:instancePath+"/page/cells/" + i7+"/" + i8+"/conflict/" + i9+"/value",schemaPath:"#/oneOf/10/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/properties/value/oneOf",keyword:"oneOf",params:{passingSchemas: passing10},message:"must match exactly one schema in oneOf"};
if(vErrors === null){
vErrors = [err252];
}
else {
vErrors.push(err252);
}
errors++;
}
else {
errors = _errs397;
if(vErrors !== null){
if(_errs397){
vErrors.length = _errs397;
}
else {
vErrors = null;
}
}
}
var valid71 = _errs396 === errors;
}
else {
var valid71 = true;
}
}
}
}
}
}
else {
const err253 = {instancePath:instancePath+"/page/cells/" + i7+"/" + i8+"/conflict/" + i9,schemaPath:"#/oneOf/10/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err253];
}
else {
vErrors.push(err253);
}
errors++;
}
}
var valid70 = _errs389 === errors;
if(!valid70){
break;
}
}
}
}
else {
const err254 = {instancePath:instancePath+"/page/cells/" + i7+"/" + i8+"/conflict",schemaPath:"#/oneOf/10/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/type",keyword:"type",params:{type: "array"},message:"must be array"};
if(vErrors === null){
vErrors = [err254];
}
else {
vErrors.push(err254);
}
errors++;
}
}
}
}
}
}
else {
const err255 = {instancePath:instancePath+"/page/cells/" + i7+"/" + i8,schemaPath:"#/oneOf/10/properties/page/properties/cells/items/items/oneOf/4/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err255];
}
else {
vErrors.push(err255);
}
errors++;
}
}
var _valid15 = _errs384 === errors;
if(_valid15 && valid67){
valid67 = false;
passing9 = [passing9, 4];
}
else {
if(_valid15){
valid67 = true;
passing9 = 4;
if(props14 !== true){
props14 = true;
}
}
}
}
}
}
if(!valid67){
const err256 = {instancePath:instancePath+"/page/cells/" + i7+"/" + i8,schemaPath:"#/oneOf/10/properties/page/properties/cells/items/items/oneOf",keyword:"oneOf",params:{passingSchemas: passing9},message:"must match exactly one schema in oneOf"};
if(vErrors === null){
vErrors = [err256];
}
else {
vErrors.push(err256);
}
errors++;
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
var valid66 = _errs374 === errors;
if(!valid66){
break;
}
}
}
}
else {
const err257 = {instancePath:instancePath+"/page/cells/" + i7,schemaPath:"#/oneOf/10/properties/page/properties/cells/items/type",keyword:"type",params:{type: "array"},message:"must be array"};
if(vErrors === null){
vErrors = [err257];
}
else {
vErrors.push(err257);
}
errors++;
}
}
var valid65 = _errs372 === errors;
if(!valid65){
break;
}
}
}
}
else {
const err258 = {instancePath:instancePath+"/page/cells",schemaPath:"#/oneOf/10/properties/page/properties/cells/type",keyword:"type",params:{type: "array"},message:"must be array"};
if(vErrors === null){
vErrors = [err258];
}
else {
vErrors.push(err258);
}
errors++;
}
}
var valid61 = _errs370 === errors;
}
else {
var valid61 = true;
}
}
}
}
}
else {
const err259 = {instancePath:instancePath+"/page",schemaPath:"#/oneOf/10/properties/page/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
}
}
else {
const err260 = {instancePath,schemaPath:"#/oneOf/10/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err260];
}
else {
vErrors.push(err260);
}
errors++;
}
}
var _valid0 = _errs319 === errors;
if(_valid0 && valid0){
valid0 = false;
passing0 = [passing0, 10];
}
else {
if(_valid0){
valid0 = true;
passing0 = 10;
if(props0 !== true){
props0 = true;
}
}
const _errs401 = errors;
if(errors === _errs401){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing46;
if((data.draft === undefined) && (missing46 = "draft")){
const err261 = {instancePath,schemaPath:"#/oneOf/11/required",keyword:"required",params:{missingProperty: missing46},message:"must have required property '"+missing46+"'"};
if(vErrors === null){
vErrors = [err261];
}
else {
vErrors.push(err261);
}
errors++;
}
else {
const _errs403 = errors;
for(const key46 in data){
if(!(key46 === "draft")){
const err262 = {instancePath,schemaPath:"#/oneOf/11/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key46},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err262];
}
else {
vErrors.push(err262);
}
errors++;
break;
}
}
if(_errs403 === errors){
if(data.draft !== undefined){
let data170 = data.draft;
const _errs405 = errors;
let valid74 = false;
const _errs406 = errors;
if(errors === _errs406){
if(data170 && typeof data170 == "object" && !Array.isArray(data170)){
let missing47;
if((((((((data170.generation === undefined) && (missing47 = "generation")) || ((data170.limit === undefined) && (missing47 = "limit"))) || ((data170.starts === undefined) && (missing47 = "starts"))) || ((data170.enabled === undefined) && (missing47 = "enabled"))) || ((data170.contract === undefined) && (missing47 = "contract"))) || ((data170.budgets === undefined) && (missing47 = "budgets"))) || ((data170.namespaces === undefined) && (missing47 = "namespaces"))){
const err263 = {instancePath:instancePath+"/draft",schemaPath:"#/oneOf/11/properties/draft/anyOf/0/required",keyword:"required",params:{missingProperty: missing47},message:"must have required property '"+missing47+"'"};
if(vErrors === null){
vErrors = [err263];
}
else {
vErrors.push(err263);
}
errors++;
}
else {
const _errs408 = errors;
for(const key47 in data170){
if(!(((((((key47 === "generation") || (key47 === "limit")) || (key47 === "starts")) || (key47 === "enabled")) || (key47 === "contract")) || (key47 === "budgets")) || (key47 === "namespaces"))){
const err264 = {instancePath:instancePath+"/draft",schemaPath:"#/oneOf/11/properties/draft/anyOf/0/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key47},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err264];
}
else {
vErrors.push(err264);
}
errors++;
break;
}
}
if(_errs408 === errors){
if(data170.generation !== undefined){
let data171 = data170.generation;
const _errs409 = errors;
if(errors === _errs409){
if(typeof data171 === "string"){
if(func4(data171) > 131072){
const err265 = {instancePath:instancePath+"/draft/generation",schemaPath:"#/oneOf/11/properties/draft/anyOf/0/properties/generation/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err265];
}
else {
vErrors.push(err265);
}
errors++;
}
}
else {
const err266 = {instancePath:instancePath+"/draft/generation",schemaPath:"#/oneOf/11/properties/draft/anyOf/0/properties/generation/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err266];
}
else {
vErrors.push(err266);
}
errors++;
}
}
var valid75 = _errs409 === errors;
}
else {
var valid75 = true;
}
if(valid75){
if(data170.limit !== undefined){
const _errs411 = errors;
if(!(validate102(data170.limit, {instancePath:instancePath+"/draft/limit",parentData:data170,parentDataProperty:"limit",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate102.errors : vErrors.concat(validate102.errors);
errors = vErrors.length;
}
var valid75 = _errs411 === errors;
}
else {
var valid75 = true;
}
if(valid75){
if(data170.starts !== undefined){
const _errs412 = errors;
if(!(validate102(data170.starts, {instancePath:instancePath+"/draft/starts",parentData:data170,parentDataProperty:"starts",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate102.errors : vErrors.concat(validate102.errors);
errors = vErrors.length;
}
var valid75 = _errs412 === errors;
}
else {
var valid75 = true;
}
if(valid75){
if(data170.enabled !== undefined){
const _errs413 = errors;
if(typeof data170.enabled !== "boolean"){
const err267 = {instancePath:instancePath+"/draft/enabled",schemaPath:"#/oneOf/11/properties/draft/anyOf/0/properties/enabled/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"};
if(vErrors === null){
vErrors = [err267];
}
else {
vErrors.push(err267);
}
errors++;
}
var valid75 = _errs413 === errors;
}
else {
var valid75 = true;
}
if(valid75){
if(data170.contract !== undefined){
const _errs415 = errors;
if(!(validate105(data170.contract, {instancePath:instancePath+"/draft/contract",parentData:data170,parentDataProperty:"contract",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate105.errors : vErrors.concat(validate105.errors);
errors = vErrors.length;
}
var valid75 = _errs415 === errors;
}
else {
var valid75 = true;
}
if(valid75){
if(data170.budgets !== undefined){
const _errs416 = errors;
if(!(validate669(data170.budgets, {instancePath:instancePath+"/draft/budgets",parentData:data170,parentDataProperty:"budgets",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate669.errors : vErrors.concat(validate669.errors);
errors = vErrors.length;
}
var valid75 = _errs416 === errors;
}
else {
var valid75 = true;
}
if(valid75){
if(data170.namespaces !== undefined){
let data177 = data170.namespaces;
const _errs417 = errors;
if(errors === _errs417){
if(Array.isArray(data177)){
if(data177.length > 8){
const err268 = {instancePath:instancePath+"/draft/namespaces",schemaPath:"#/oneOf/11/properties/draft/anyOf/0/properties/namespaces/maxItems",keyword:"maxItems",params:{limit: 8},message:"must NOT have more than 8 items"};
if(vErrors === null){
vErrors = [err268];
}
else {
vErrors.push(err268);
}
errors++;
}
else {
if(data177.length < 8){
const err269 = {instancePath:instancePath+"/draft/namespaces",schemaPath:"#/oneOf/11/properties/draft/anyOf/0/properties/namespaces/minItems",keyword:"minItems",params:{limit: 8},message:"must NOT have fewer than 8 items"};
if(vErrors === null){
vErrors = [err269];
}
else {
vErrors.push(err269);
}
errors++;
}
else {
var valid76 = true;
const len10 = data177.length;
for(let i10=0; i10<len10; i10++){
let data178 = data177[i10];
const _errs419 = errors;
if(errors === _errs419){
if(typeof data178 === "string"){
if(func4(data178) > 131072){
const err270 = {instancePath:instancePath+"/draft/namespaces/" + i10,schemaPath:"#/oneOf/11/properties/draft/anyOf/0/properties/namespaces/items/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err270];
}
else {
vErrors.push(err270);
}
errors++;
}
}
else {
const err271 = {instancePath:instancePath+"/draft/namespaces/" + i10,schemaPath:"#/oneOf/11/properties/draft/anyOf/0/properties/namespaces/items/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err271];
}
else {
vErrors.push(err271);
}
errors++;
}
}
var valid76 = _errs419 === errors;
if(!valid76){
break;
}
}
}
}
}
else {
const err272 = {instancePath:instancePath+"/draft/namespaces",schemaPath:"#/oneOf/11/properties/draft/anyOf/0/properties/namespaces/type",keyword:"type",params:{type: "array"},message:"must be array"};
if(vErrors === null){
vErrors = [err272];
}
else {
vErrors.push(err272);
}
errors++;
}
}
var valid75 = _errs417 === errors;
}
else {
var valid75 = true;
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
const err273 = {instancePath:instancePath+"/draft",schemaPath:"#/oneOf/11/properties/draft/anyOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err273];
}
else {
vErrors.push(err273);
}
errors++;
}
}
var _valid17 = _errs406 === errors;
valid74 = valid74 || _valid17;
const _errs421 = errors;
if(data170 !== null){
const err274 = {instancePath:instancePath+"/draft",schemaPath:"#/oneOf/11/properties/draft/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err274];
}
else {
vErrors.push(err274);
}
errors++;
}
var _valid17 = _errs421 === errors;
valid74 = valid74 || _valid17;
if(!valid74){
const err275 = {instancePath:instancePath+"/draft",schemaPath:"#/oneOf/11/properties/draft/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err275];
}
else {
vErrors.push(err275);
}
errors++;
}
else {
errors = _errs405;
if(vErrors !== null){
if(_errs405){
vErrors.length = _errs405;
}
else {
vErrors = null;
}
}
}
}
}
}
}
else {
const err276 = {instancePath,schemaPath:"#/oneOf/11/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err276];
}
else {
vErrors.push(err276);
}
errors++;
}
}
var _valid0 = _errs401 === errors;
if(_valid0 && valid0){
valid0 = false;
passing0 = [passing0, 11];
}
else {
if(_valid0){
valid0 = true;
passing0 = 11;
if(props0 !== true){
props0 = true;
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
if(!valid0){
const err277 = {instancePath,schemaPath:"#/oneOf",keyword:"oneOf",params:{passingSchemas: passing0},message:"must match exactly one schema in oneOf"};
if(vErrors === null){
vErrors = [err277];
}
else {
vErrors.push(err277);
}
errors++;
validate603.errors = vErrors;
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
validate603.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate603.evaluated = {"dynamicProps":true,"dynamicItems":false};
