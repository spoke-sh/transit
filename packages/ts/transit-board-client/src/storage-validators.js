// Generated; no runtime code generation or eval.
import lengthModule from "ajv/dist/runtime/ucs2length.js";
const ucs2length = lengthModule.default ?? lengthModule;
"use strict";
export const StorageResponse = validate365;
const schema98 = {"type":"object","additionalProperties":false,"properties":{"realm":{"$ref":"https://transit.invalid/generated-validator/1"},"position":{"$ref":"https://transit.invalid/generated-validator/1"},"backend":{"type":"string","enum":["unavailable","local"]},"root":{"anyOf":[{"type":"string","maxLength":4096},{"type":"null"}]},"object_tier":{"anyOf":[{"type":"object","additionalProperties":false,"properties":{"pending_upload_bytes":{"$ref":"https://transit.invalid/generated-validator/1"},"pending_objects":{"$ref":"https://transit.invalid/generated-validator/1"},"staging_limit_bytes":{"$ref":"https://transit.invalid/generated-validator/1"},"pending_object_limit":{"$ref":"https://transit.invalid/generated-validator/1"},"cache_limit_bytes":{"$ref":"https://transit.invalid/generated-validator/1"},"cache_used_bytes":{"$ref":"https://transit.invalid/generated-validator/1"},"cache_hits":{"$ref":"https://transit.invalid/generated-validator/1"},"cache_misses":{"$ref":"https://transit.invalid/generated-validator/1"},"uploads_completed":{"$ref":"https://transit.invalid/generated-validator/1"},"deletes_completed":{"$ref":"https://transit.invalid/generated-validator/1"},"failed_steps":{"$ref":"https://transit.invalid/generated-validator/1"},"last_failure":{"$ref":"https://transit.invalid/generated-validator/110"},"recovery_required":{"type":"boolean"}},"required":["pending_upload_bytes","pending_objects","staging_limit_bytes","pending_object_limit","cache_limit_bytes","cache_used_bytes","cache_hits","cache_misses","uploads_completed","deletes_completed","failed_steps","last_failure","recovery_required"]},{"type":"null"}]},"allocated_bytes":{"$ref":"https://transit.invalid/generated-validator/2"},"limits":{"anyOf":[{"type":"object","additionalProperties":false,"properties":{"bytes":{"$ref":"https://transit.invalid/generated-validator/1"},"control_bytes":{"$ref":"https://transit.invalid/generated-validator/1"},"candidate_bytes":{"$ref":"https://transit.invalid/generated-validator/0"}},"required":["bytes","control_bytes","candidate_bytes"]},{"type":"null"}]},"data_requests":{"$ref":"https://transit.invalid/generated-validator/112"},"control_requests":{"$ref":"https://transit.invalid/generated-validator/112"},"request_limit_bytes":{"$ref":"https://transit.invalid/generated-validator/2"},"admission":{"anyOf":[{"type":"object","additionalProperties":false,"properties":{"total":{"$ref":"https://transit.invalid/generated-validator/113"},"data":{"$ref":"https://transit.invalid/generated-validator/113"},"control":{"$ref":"https://transit.invalid/generated-validator/113"},"maintenance":{"$ref":"https://transit.invalid/generated-validator/113"},"collection":{"$ref":"https://transit.invalid/generated-validator/113"}},"required":["total","data","control","maintenance","collection"]},{"type":"null"}]},"maintenance":{"anyOf":[{"type":"object","additionalProperties":false,"properties":{"enabled":{"type":"boolean"},"state":{"type":"string","enum":["disabled","waiting","running","failed"]},"completed_steps":{"$ref":"https://transit.invalid/generated-validator/1"},"failed_steps":{"$ref":"https://transit.invalid/generated-validator/1"},"last_failure":{"$ref":"https://transit.invalid/generated-validator/110"},"interval_ms":{"$ref":"https://transit.invalid/generated-validator/0"},"operation_timeout_ms":{"$ref":"https://transit.invalid/generated-validator/0"}},"required":["enabled","state","completed_steps","failed_steps","last_failure","interval_ms","operation_timeout_ms"]},{"type":"null"}]},"settings":{"anyOf":[{"type":"object","additionalProperties":false,"properties":{"collection_every_records":{"$ref":"https://transit.invalid/generated-validator/1"},"compact":{"type":"boolean"},"compaction_rows":{"$ref":"https://transit.invalid/generated-validator/4"},"resident_bytes":{"$ref":"https://transit.invalid/generated-validator/0"},"archive":{"type":"object","additionalProperties":false,"properties":{"enabled":{"type":"boolean"},"work_frames":{"$ref":"https://transit.invalid/generated-validator/9"}},"required":["enabled","work_frames"]},"flush":{"type":"object","additionalProperties":false,"properties":{"enabled":{"type":"boolean"},"rows":{"$ref":"https://transit.invalid/generated-validator/4"},"work_rows":{"$ref":"https://transit.invalid/generated-validator/4"},"bytes":{"$ref":"https://transit.invalid/generated-validator/1"},"age_ms":{"$ref":"https://transit.invalid/generated-validator/0"}},"required":["enabled","rows","work_rows","bytes","age_ms"]}},"required":["collection_every_records","compact","compaction_rows","resident_bytes","archive","flush"]},{"type":"null"}]}},"required":["realm","position","backend","root","object_tier","allocated_bytes","limits","data_requests","control_requests","request_limit_bytes","admission","maintenance","settings"]};
const func1 = Object.prototype.hasOwnProperty;
const func3 = ucs2length;
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

const schema99 = {"anyOf":[{"$ref":"https://transit.invalid/generated-validator/109"},{"type":"null"}]};
const schema100 = {"type":"string","enum":["capacity","denied","clock","timeout","recovery","storage","other"]};

function validate380(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate380.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate380.errors = [{}];
return false;
}
if(!(((((((data === "capacity") || (data === "denied")) || (data === "clock")) || (data === "timeout")) || (data === "recovery")) || (data === "storage")) || (data === "other"))){
validate380.errors = [{}];
return false;
}
validate380.errors = vErrors;
return errors === 0;
}
validate380.evaluated = {"dynamicProps":false,"dynamicItems":false};


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
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate380(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate380.errors : vErrors.concat(validate380.errors);
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
validate379.errors = vErrors;
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
validate379.errors = vErrors;
return errors === 0;
}
validate379.evaluated = {"dynamicProps":false,"dynamicItems":false};

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

const schema101 = {"anyOf":[{"$ref":"https://transit.invalid/generated-validator/111"},{"type":"null"}]};
const schema102 = {"type":"object","additionalProperties":false,"properties":{"limit":{"$ref":"https://transit.invalid/generated-validator/1"},"used":{"$ref":"https://transit.invalid/generated-validator/1"},"peak":{"$ref":"https://transit.invalid/generated-validator/1"}},"required":["limit","used","peak"]};

function validate388(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate388.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((((data.limit === undefined) && (missing0 = "limit")) || ((data.used === undefined) && (missing0 = "used"))) || ((data.peak === undefined) && (missing0 = "peak"))){
validate388.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "limit") || (key0 === "used")) || (key0 === "peak"))){
validate388.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.limit !== undefined){
const _errs2 = errors;
if(!(validate56(data.limit, {instancePath:instancePath+"/limit",parentData:data,parentDataProperty:"limit",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.used !== undefined){
const _errs3 = errors;
if(!(validate56(data.used, {instancePath:instancePath+"/used",parentData:data,parentDataProperty:"used",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid0 = _errs3 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.peak !== undefined){
const _errs4 = errors;
if(!(validate56(data.peak, {instancePath:instancePath+"/peak",parentData:data,parentDataProperty:"peak",rootData,dynamicAnchors}))){
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
validate388.errors = [{}];
return false;
}
}
validate388.errors = vErrors;
return errors === 0;
}
validate388.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate387(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate387.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate388(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate388.errors : vErrors.concat(validate388.errors);
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
validate387.errors = vErrors;
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
validate387.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate387.evaluated = {"dynamicProps":true,"dynamicItems":false};

const schema103 = {"type":"object","additionalProperties":false,"properties":{"memory":{"$ref":"https://transit.invalid/generated-validator/111"},"refusals":{"$ref":"https://transit.invalid/generated-validator/1"}},"required":["memory","refusals"]};

function validate396(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate396.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if(((data.memory === undefined) && (missing0 = "memory")) || ((data.refusals === undefined) && (missing0 = "refusals"))){
validate396.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "memory") || (key0 === "refusals"))){
validate396.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.memory !== undefined){
const _errs2 = errors;
if(!(validate388(data.memory, {instancePath:instancePath+"/memory",parentData:data,parentDataProperty:"memory",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate388.errors : vErrors.concat(validate388.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.refusals !== undefined){
const _errs3 = errors;
if(!(validate56(data.refusals, {instancePath:instancePath+"/refusals",parentData:data,parentDataProperty:"refusals",rootData,dynamicAnchors}))){
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
validate396.errors = [{}];
return false;
}
}
validate396.errors = vErrors;
return errors === 0;
}
validate396.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

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


function validate365(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate365.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((((((((((((((data.realm === undefined) && (missing0 = "realm")) || ((data.position === undefined) && (missing0 = "position"))) || ((data.backend === undefined) && (missing0 = "backend"))) || ((data.root === undefined) && (missing0 = "root"))) || ((data.object_tier === undefined) && (missing0 = "object_tier"))) || ((data.allocated_bytes === undefined) && (missing0 = "allocated_bytes"))) || ((data.limits === undefined) && (missing0 = "limits"))) || ((data.data_requests === undefined) && (missing0 = "data_requests"))) || ((data.control_requests === undefined) && (missing0 = "control_requests"))) || ((data.request_limit_bytes === undefined) && (missing0 = "request_limit_bytes"))) || ((data.admission === undefined) && (missing0 = "admission"))) || ((data.maintenance === undefined) && (missing0 = "maintenance"))) || ((data.settings === undefined) && (missing0 = "settings"))){
validate365.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(func1.call(schema98.properties, key0))){
validate365.errors = [{}];
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
if(data.position !== undefined){
const _errs3 = errors;
if(!(validate56(data.position, {instancePath:instancePath+"/position",parentData:data,parentDataProperty:"position",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid0 = _errs3 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.backend !== undefined){
let data2 = data.backend;
const _errs4 = errors;
if(typeof data2 !== "string"){
validate365.errors = [{}];
return false;
}
if(!((data2 === "unavailable") || (data2 === "local"))){
validate365.errors = [{}];
return false;
}
var valid0 = _errs4 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.root !== undefined){
let data3 = data.root;
const _errs6 = errors;
const _errs7 = errors;
let valid1 = false;
const _errs8 = errors;
if(errors === _errs8){
if(typeof data3 === "string"){
if(func3(data3) > 4096){
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
var _valid0 = _errs8 === errors;
valid1 = valid1 || _valid0;
const _errs10 = errors;
if(data3 !== null){
const err2 = {};
if(vErrors === null){
vErrors = [err2];
}
else {
vErrors.push(err2);
}
errors++;
}
var _valid0 = _errs10 === errors;
valid1 = valid1 || _valid0;
if(!valid1){
const err3 = {};
if(vErrors === null){
vErrors = [err3];
}
else {
vErrors.push(err3);
}
errors++;
validate365.errors = vErrors;
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
if(data.object_tier !== undefined){
let data4 = data.object_tier;
const _errs12 = errors;
const _errs13 = errors;
let valid2 = false;
const _errs14 = errors;
if(errors === _errs14){
if(data4 && typeof data4 == "object" && !Array.isArray(data4)){
let missing1;
if((((((((((((((data4.pending_upload_bytes === undefined) && (missing1 = "pending_upload_bytes")) || ((data4.pending_objects === undefined) && (missing1 = "pending_objects"))) || ((data4.staging_limit_bytes === undefined) && (missing1 = "staging_limit_bytes"))) || ((data4.pending_object_limit === undefined) && (missing1 = "pending_object_limit"))) || ((data4.cache_limit_bytes === undefined) && (missing1 = "cache_limit_bytes"))) || ((data4.cache_used_bytes === undefined) && (missing1 = "cache_used_bytes"))) || ((data4.cache_hits === undefined) && (missing1 = "cache_hits"))) || ((data4.cache_misses === undefined) && (missing1 = "cache_misses"))) || ((data4.uploads_completed === undefined) && (missing1 = "uploads_completed"))) || ((data4.deletes_completed === undefined) && (missing1 = "deletes_completed"))) || ((data4.failed_steps === undefined) && (missing1 = "failed_steps"))) || ((data4.last_failure === undefined) && (missing1 = "last_failure"))) || ((data4.recovery_required === undefined) && (missing1 = "recovery_required"))){
const err4 = {};
if(vErrors === null){
vErrors = [err4];
}
else {
vErrors.push(err4);
}
errors++;
}
else {
const _errs16 = errors;
for(const key1 in data4){
if(!(func1.call(schema98.properties.object_tier.anyOf[0].properties, key1))){
const err5 = {};
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
if(_errs16 === errors){
if(data4.pending_upload_bytes !== undefined){
const _errs17 = errors;
if(!(validate56(data4.pending_upload_bytes, {instancePath:instancePath+"/object_tier/pending_upload_bytes",parentData:data4,parentDataProperty:"pending_upload_bytes",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid3 = _errs17 === errors;
}
else {
var valid3 = true;
}
if(valid3){
if(data4.pending_objects !== undefined){
const _errs18 = errors;
if(!(validate56(data4.pending_objects, {instancePath:instancePath+"/object_tier/pending_objects",parentData:data4,parentDataProperty:"pending_objects",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid3 = _errs18 === errors;
}
else {
var valid3 = true;
}
if(valid3){
if(data4.staging_limit_bytes !== undefined){
const _errs19 = errors;
if(!(validate56(data4.staging_limit_bytes, {instancePath:instancePath+"/object_tier/staging_limit_bytes",parentData:data4,parentDataProperty:"staging_limit_bytes",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid3 = _errs19 === errors;
}
else {
var valid3 = true;
}
if(valid3){
if(data4.pending_object_limit !== undefined){
const _errs20 = errors;
if(!(validate56(data4.pending_object_limit, {instancePath:instancePath+"/object_tier/pending_object_limit",parentData:data4,parentDataProperty:"pending_object_limit",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid3 = _errs20 === errors;
}
else {
var valid3 = true;
}
if(valid3){
if(data4.cache_limit_bytes !== undefined){
const _errs21 = errors;
if(!(validate56(data4.cache_limit_bytes, {instancePath:instancePath+"/object_tier/cache_limit_bytes",parentData:data4,parentDataProperty:"cache_limit_bytes",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid3 = _errs21 === errors;
}
else {
var valid3 = true;
}
if(valid3){
if(data4.cache_used_bytes !== undefined){
const _errs22 = errors;
if(!(validate56(data4.cache_used_bytes, {instancePath:instancePath+"/object_tier/cache_used_bytes",parentData:data4,parentDataProperty:"cache_used_bytes",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid3 = _errs22 === errors;
}
else {
var valid3 = true;
}
if(valid3){
if(data4.cache_hits !== undefined){
const _errs23 = errors;
if(!(validate56(data4.cache_hits, {instancePath:instancePath+"/object_tier/cache_hits",parentData:data4,parentDataProperty:"cache_hits",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid3 = _errs23 === errors;
}
else {
var valid3 = true;
}
if(valid3){
if(data4.cache_misses !== undefined){
const _errs24 = errors;
if(!(validate56(data4.cache_misses, {instancePath:instancePath+"/object_tier/cache_misses",parentData:data4,parentDataProperty:"cache_misses",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid3 = _errs24 === errors;
}
else {
var valid3 = true;
}
if(valid3){
if(data4.uploads_completed !== undefined){
const _errs25 = errors;
if(!(validate56(data4.uploads_completed, {instancePath:instancePath+"/object_tier/uploads_completed",parentData:data4,parentDataProperty:"uploads_completed",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid3 = _errs25 === errors;
}
else {
var valid3 = true;
}
if(valid3){
if(data4.deletes_completed !== undefined){
const _errs26 = errors;
if(!(validate56(data4.deletes_completed, {instancePath:instancePath+"/object_tier/deletes_completed",parentData:data4,parentDataProperty:"deletes_completed",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid3 = _errs26 === errors;
}
else {
var valid3 = true;
}
if(valid3){
if(data4.failed_steps !== undefined){
const _errs27 = errors;
if(!(validate56(data4.failed_steps, {instancePath:instancePath+"/object_tier/failed_steps",parentData:data4,parentDataProperty:"failed_steps",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid3 = _errs27 === errors;
}
else {
var valid3 = true;
}
if(valid3){
if(data4.last_failure !== undefined){
const _errs28 = errors;
if(!(validate379(data4.last_failure, {instancePath:instancePath+"/object_tier/last_failure",parentData:data4,parentDataProperty:"last_failure",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate379.errors : vErrors.concat(validate379.errors);
errors = vErrors.length;
}
var valid3 = _errs28 === errors;
}
else {
var valid3 = true;
}
if(valid3){
if(data4.recovery_required !== undefined){
const _errs29 = errors;
if(typeof data4.recovery_required !== "boolean"){
const err6 = {};
if(vErrors === null){
vErrors = [err6];
}
else {
vErrors.push(err6);
}
errors++;
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
}
}
}
}
}
}
}
else {
const err7 = {};
if(vErrors === null){
vErrors = [err7];
}
else {
vErrors.push(err7);
}
errors++;
}
}
var _valid1 = _errs14 === errors;
valid2 = valid2 || _valid1;
const _errs31 = errors;
if(data4 !== null){
const err8 = {};
if(vErrors === null){
vErrors = [err8];
}
else {
vErrors.push(err8);
}
errors++;
}
var _valid1 = _errs31 === errors;
valid2 = valid2 || _valid1;
if(!valid2){
const err9 = {};
if(vErrors === null){
vErrors = [err9];
}
else {
vErrors.push(err9);
}
errors++;
validate365.errors = vErrors;
return false;
}
else {
errors = _errs13;
if(vErrors !== null){
if(_errs13){
vErrors.length = _errs13;
}
else {
vErrors = null;
}
}
}
var valid0 = _errs12 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.allocated_bytes !== undefined){
const _errs33 = errors;
if(!(validate62(data.allocated_bytes, {instancePath:instancePath+"/allocated_bytes",parentData:data,parentDataProperty:"allocated_bytes",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate62.errors : vErrors.concat(validate62.errors);
errors = vErrors.length;
}
var valid0 = _errs33 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.limits !== undefined){
let data19 = data.limits;
const _errs34 = errors;
const _errs35 = errors;
let valid4 = false;
const _errs36 = errors;
if(errors === _errs36){
if(data19 && typeof data19 == "object" && !Array.isArray(data19)){
let missing2;
if((((data19.bytes === undefined) && (missing2 = "bytes")) || ((data19.control_bytes === undefined) && (missing2 = "control_bytes"))) || ((data19.candidate_bytes === undefined) && (missing2 = "candidate_bytes"))){
const err10 = {};
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
for(const key2 in data19){
if(!(((key2 === "bytes") || (key2 === "control_bytes")) || (key2 === "candidate_bytes"))){
const err11 = {};
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
if(data19.bytes !== undefined){
const _errs39 = errors;
if(!(validate56(data19.bytes, {instancePath:instancePath+"/limits/bytes",parentData:data19,parentDataProperty:"bytes",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid5 = _errs39 === errors;
}
else {
var valid5 = true;
}
if(valid5){
if(data19.control_bytes !== undefined){
const _errs40 = errors;
if(!(validate56(data19.control_bytes, {instancePath:instancePath+"/limits/control_bytes",parentData:data19,parentDataProperty:"control_bytes",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid5 = _errs40 === errors;
}
else {
var valid5 = true;
}
if(valid5){
if(data19.candidate_bytes !== undefined){
const _errs41 = errors;
if(!(validate59(data19.candidate_bytes, {instancePath:instancePath+"/limits/candidate_bytes",parentData:data19,parentDataProperty:"candidate_bytes",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate59.errors : vErrors.concat(validate59.errors);
errors = vErrors.length;
}
var valid5 = _errs41 === errors;
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
var _valid2 = _errs36 === errors;
valid4 = valid4 || _valid2;
const _errs42 = errors;
if(data19 !== null){
const err13 = {};
if(vErrors === null){
vErrors = [err13];
}
else {
vErrors.push(err13);
}
errors++;
}
var _valid2 = _errs42 === errors;
valid4 = valid4 || _valid2;
if(!valid4){
const err14 = {};
if(vErrors === null){
vErrors = [err14];
}
else {
vErrors.push(err14);
}
errors++;
validate365.errors = vErrors;
return false;
}
else {
errors = _errs35;
if(vErrors !== null){
if(_errs35){
vErrors.length = _errs35;
}
else {
vErrors = null;
}
}
}
var valid0 = _errs34 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.data_requests !== undefined){
const _errs44 = errors;
if(!(validate387(data.data_requests, {instancePath:instancePath+"/data_requests",parentData:data,parentDataProperty:"data_requests",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate387.errors : vErrors.concat(validate387.errors);
errors = vErrors.length;
}
var valid0 = _errs44 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.control_requests !== undefined){
const _errs45 = errors;
if(!(validate387(data.control_requests, {instancePath:instancePath+"/control_requests",parentData:data,parentDataProperty:"control_requests",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate387.errors : vErrors.concat(validate387.errors);
errors = vErrors.length;
}
var valid0 = _errs45 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.request_limit_bytes !== undefined){
const _errs46 = errors;
if(!(validate62(data.request_limit_bytes, {instancePath:instancePath+"/request_limit_bytes",parentData:data,parentDataProperty:"request_limit_bytes",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate62.errors : vErrors.concat(validate62.errors);
errors = vErrors.length;
}
var valid0 = _errs46 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.admission !== undefined){
let data26 = data.admission;
const _errs47 = errors;
const _errs48 = errors;
let valid6 = false;
const _errs49 = errors;
if(errors === _errs49){
if(data26 && typeof data26 == "object" && !Array.isArray(data26)){
let missing3;
if((((((data26.total === undefined) && (missing3 = "total")) || ((data26.data === undefined) && (missing3 = "data"))) || ((data26.control === undefined) && (missing3 = "control"))) || ((data26.maintenance === undefined) && (missing3 = "maintenance"))) || ((data26.collection === undefined) && (missing3 = "collection"))){
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
const _errs51 = errors;
for(const key3 in data26){
if(!(((((key3 === "total") || (key3 === "data")) || (key3 === "control")) || (key3 === "maintenance")) || (key3 === "collection"))){
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
if(_errs51 === errors){
if(data26.total !== undefined){
const _errs52 = errors;
if(!(validate396(data26.total, {instancePath:instancePath+"/admission/total",parentData:data26,parentDataProperty:"total",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate396.errors : vErrors.concat(validate396.errors);
errors = vErrors.length;
}
var valid7 = _errs52 === errors;
}
else {
var valid7 = true;
}
if(valid7){
if(data26.data !== undefined){
const _errs53 = errors;
if(!(validate396(data26.data, {instancePath:instancePath+"/admission/data",parentData:data26,parentDataProperty:"data",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate396.errors : vErrors.concat(validate396.errors);
errors = vErrors.length;
}
var valid7 = _errs53 === errors;
}
else {
var valid7 = true;
}
if(valid7){
if(data26.control !== undefined){
const _errs54 = errors;
if(!(validate396(data26.control, {instancePath:instancePath+"/admission/control",parentData:data26,parentDataProperty:"control",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate396.errors : vErrors.concat(validate396.errors);
errors = vErrors.length;
}
var valid7 = _errs54 === errors;
}
else {
var valid7 = true;
}
if(valid7){
if(data26.maintenance !== undefined){
const _errs55 = errors;
if(!(validate396(data26.maintenance, {instancePath:instancePath+"/admission/maintenance",parentData:data26,parentDataProperty:"maintenance",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate396.errors : vErrors.concat(validate396.errors);
errors = vErrors.length;
}
var valid7 = _errs55 === errors;
}
else {
var valid7 = true;
}
if(valid7){
if(data26.collection !== undefined){
const _errs56 = errors;
if(!(validate396(data26.collection, {instancePath:instancePath+"/admission/collection",parentData:data26,parentDataProperty:"collection",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate396.errors : vErrors.concat(validate396.errors);
errors = vErrors.length;
}
var valid7 = _errs56 === errors;
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
var _valid3 = _errs49 === errors;
valid6 = valid6 || _valid3;
const _errs57 = errors;
if(data26 !== null){
const err18 = {};
if(vErrors === null){
vErrors = [err18];
}
else {
vErrors.push(err18);
}
errors++;
}
var _valid3 = _errs57 === errors;
valid6 = valid6 || _valid3;
if(!valid6){
const err19 = {};
if(vErrors === null){
vErrors = [err19];
}
else {
vErrors.push(err19);
}
errors++;
validate365.errors = vErrors;
return false;
}
else {
errors = _errs48;
if(vErrors !== null){
if(_errs48){
vErrors.length = _errs48;
}
else {
vErrors = null;
}
}
}
var valid0 = _errs47 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.maintenance !== undefined){
let data32 = data.maintenance;
const _errs59 = errors;
const _errs60 = errors;
let valid8 = false;
const _errs61 = errors;
if(errors === _errs61){
if(data32 && typeof data32 == "object" && !Array.isArray(data32)){
let missing4;
if((((((((data32.enabled === undefined) && (missing4 = "enabled")) || ((data32.state === undefined) && (missing4 = "state"))) || ((data32.completed_steps === undefined) && (missing4 = "completed_steps"))) || ((data32.failed_steps === undefined) && (missing4 = "failed_steps"))) || ((data32.last_failure === undefined) && (missing4 = "last_failure"))) || ((data32.interval_ms === undefined) && (missing4 = "interval_ms"))) || ((data32.operation_timeout_ms === undefined) && (missing4 = "operation_timeout_ms"))){
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
for(const key4 in data32){
if(!(((((((key4 === "enabled") || (key4 === "state")) || (key4 === "completed_steps")) || (key4 === "failed_steps")) || (key4 === "last_failure")) || (key4 === "interval_ms")) || (key4 === "operation_timeout_ms"))){
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
if(data32.enabled !== undefined){
const _errs64 = errors;
if(typeof data32.enabled !== "boolean"){
const err22 = {};
if(vErrors === null){
vErrors = [err22];
}
else {
vErrors.push(err22);
}
errors++;
}
var valid9 = _errs64 === errors;
}
else {
var valid9 = true;
}
if(valid9){
if(data32.state !== undefined){
let data34 = data32.state;
const _errs66 = errors;
if(typeof data34 !== "string"){
const err23 = {};
if(vErrors === null){
vErrors = [err23];
}
else {
vErrors.push(err23);
}
errors++;
}
if(!((((data34 === "disabled") || (data34 === "waiting")) || (data34 === "running")) || (data34 === "failed"))){
const err24 = {};
if(vErrors === null){
vErrors = [err24];
}
else {
vErrors.push(err24);
}
errors++;
}
var valid9 = _errs66 === errors;
}
else {
var valid9 = true;
}
if(valid9){
if(data32.completed_steps !== undefined){
const _errs68 = errors;
if(!(validate56(data32.completed_steps, {instancePath:instancePath+"/maintenance/completed_steps",parentData:data32,parentDataProperty:"completed_steps",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid9 = _errs68 === errors;
}
else {
var valid9 = true;
}
if(valid9){
if(data32.failed_steps !== undefined){
const _errs69 = errors;
if(!(validate56(data32.failed_steps, {instancePath:instancePath+"/maintenance/failed_steps",parentData:data32,parentDataProperty:"failed_steps",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid9 = _errs69 === errors;
}
else {
var valid9 = true;
}
if(valid9){
if(data32.last_failure !== undefined){
const _errs70 = errors;
if(!(validate379(data32.last_failure, {instancePath:instancePath+"/maintenance/last_failure",parentData:data32,parentDataProperty:"last_failure",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate379.errors : vErrors.concat(validate379.errors);
errors = vErrors.length;
}
var valid9 = _errs70 === errors;
}
else {
var valid9 = true;
}
if(valid9){
if(data32.interval_ms !== undefined){
const _errs71 = errors;
if(!(validate59(data32.interval_ms, {instancePath:instancePath+"/maintenance/interval_ms",parentData:data32,parentDataProperty:"interval_ms",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate59.errors : vErrors.concat(validate59.errors);
errors = vErrors.length;
}
var valid9 = _errs71 === errors;
}
else {
var valid9 = true;
}
if(valid9){
if(data32.operation_timeout_ms !== undefined){
const _errs72 = errors;
if(!(validate59(data32.operation_timeout_ms, {instancePath:instancePath+"/maintenance/operation_timeout_ms",parentData:data32,parentDataProperty:"operation_timeout_ms",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate59.errors : vErrors.concat(validate59.errors);
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
var _valid4 = _errs61 === errors;
valid8 = valid8 || _valid4;
const _errs73 = errors;
if(data32 !== null){
const err26 = {};
if(vErrors === null){
vErrors = [err26];
}
else {
vErrors.push(err26);
}
errors++;
}
var _valid4 = _errs73 === errors;
valid8 = valid8 || _valid4;
if(!valid8){
const err27 = {};
if(vErrors === null){
vErrors = [err27];
}
else {
vErrors.push(err27);
}
errors++;
validate365.errors = vErrors;
return false;
}
else {
errors = _errs60;
if(vErrors !== null){
if(_errs60){
vErrors.length = _errs60;
}
else {
vErrors = null;
}
}
}
var valid0 = _errs59 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.settings !== undefined){
let data40 = data.settings;
const _errs75 = errors;
const _errs76 = errors;
let valid10 = false;
const _errs77 = errors;
if(errors === _errs77){
if(data40 && typeof data40 == "object" && !Array.isArray(data40)){
let missing5;
if(((((((data40.collection_every_records === undefined) && (missing5 = "collection_every_records")) || ((data40.compact === undefined) && (missing5 = "compact"))) || ((data40.compaction_rows === undefined) && (missing5 = "compaction_rows"))) || ((data40.resident_bytes === undefined) && (missing5 = "resident_bytes"))) || ((data40.archive === undefined) && (missing5 = "archive"))) || ((data40.flush === undefined) && (missing5 = "flush"))){
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
const _errs79 = errors;
for(const key5 in data40){
if(!((((((key5 === "collection_every_records") || (key5 === "compact")) || (key5 === "compaction_rows")) || (key5 === "resident_bytes")) || (key5 === "archive")) || (key5 === "flush"))){
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
if(_errs79 === errors){
if(data40.collection_every_records !== undefined){
const _errs80 = errors;
if(!(validate56(data40.collection_every_records, {instancePath:instancePath+"/settings/collection_every_records",parentData:data40,parentDataProperty:"collection_every_records",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid11 = _errs80 === errors;
}
else {
var valid11 = true;
}
if(valid11){
if(data40.compact !== undefined){
const _errs81 = errors;
if(typeof data40.compact !== "boolean"){
const err30 = {};
if(vErrors === null){
vErrors = [err30];
}
else {
vErrors.push(err30);
}
errors++;
}
var valid11 = _errs81 === errors;
}
else {
var valid11 = true;
}
if(valid11){
if(data40.compaction_rows !== undefined){
const _errs83 = errors;
if(!(validate168(data40.compaction_rows, {instancePath:instancePath+"/settings/compaction_rows",parentData:data40,parentDataProperty:"compaction_rows",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate168.errors : vErrors.concat(validate168.errors);
errors = vErrors.length;
}
var valid11 = _errs83 === errors;
}
else {
var valid11 = true;
}
if(valid11){
if(data40.resident_bytes !== undefined){
const _errs84 = errors;
if(!(validate59(data40.resident_bytes, {instancePath:instancePath+"/settings/resident_bytes",parentData:data40,parentDataProperty:"resident_bytes",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate59.errors : vErrors.concat(validate59.errors);
errors = vErrors.length;
}
var valid11 = _errs84 === errors;
}
else {
var valid11 = true;
}
if(valid11){
if(data40.archive !== undefined){
let data45 = data40.archive;
const _errs85 = errors;
if(errors === _errs85){
if(data45 && typeof data45 == "object" && !Array.isArray(data45)){
let missing6;
if(((data45.enabled === undefined) && (missing6 = "enabled")) || ((data45.work_frames === undefined) && (missing6 = "work_frames"))){
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
const _errs87 = errors;
for(const key6 in data45){
if(!((key6 === "enabled") || (key6 === "work_frames"))){
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
if(_errs87 === errors){
if(data45.enabled !== undefined){
const _errs88 = errors;
if(typeof data45.enabled !== "boolean"){
const err33 = {};
if(vErrors === null){
vErrors = [err33];
}
else {
vErrors.push(err33);
}
errors++;
}
var valid12 = _errs88 === errors;
}
else {
var valid12 = true;
}
if(valid12){
if(data45.work_frames !== undefined){
const _errs90 = errors;
if(!(validate134(data45.work_frames, {instancePath:instancePath+"/settings/archive/work_frames",parentData:data45,parentDataProperty:"work_frames",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate134.errors : vErrors.concat(validate134.errors);
errors = vErrors.length;
}
var valid12 = _errs90 === errors;
}
else {
var valid12 = true;
}
}
}
}
}
else {
const err34 = {};
if(vErrors === null){
vErrors = [err34];
}
else {
vErrors.push(err34);
}
errors++;
}
}
var valid11 = _errs85 === errors;
}
else {
var valid11 = true;
}
if(valid11){
if(data40.flush !== undefined){
let data48 = data40.flush;
const _errs91 = errors;
if(errors === _errs91){
if(data48 && typeof data48 == "object" && !Array.isArray(data48)){
let missing7;
if((((((data48.enabled === undefined) && (missing7 = "enabled")) || ((data48.rows === undefined) && (missing7 = "rows"))) || ((data48.work_rows === undefined) && (missing7 = "work_rows"))) || ((data48.bytes === undefined) && (missing7 = "bytes"))) || ((data48.age_ms === undefined) && (missing7 = "age_ms"))){
const err35 = {};
if(vErrors === null){
vErrors = [err35];
}
else {
vErrors.push(err35);
}
errors++;
}
else {
const _errs93 = errors;
for(const key7 in data48){
if(!(((((key7 === "enabled") || (key7 === "rows")) || (key7 === "work_rows")) || (key7 === "bytes")) || (key7 === "age_ms"))){
const err36 = {};
if(vErrors === null){
vErrors = [err36];
}
else {
vErrors.push(err36);
}
errors++;
break;
}
}
if(_errs93 === errors){
if(data48.enabled !== undefined){
const _errs94 = errors;
if(typeof data48.enabled !== "boolean"){
const err37 = {};
if(vErrors === null){
vErrors = [err37];
}
else {
vErrors.push(err37);
}
errors++;
}
var valid13 = _errs94 === errors;
}
else {
var valid13 = true;
}
if(valid13){
if(data48.rows !== undefined){
const _errs96 = errors;
if(!(validate168(data48.rows, {instancePath:instancePath+"/settings/flush/rows",parentData:data48,parentDataProperty:"rows",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate168.errors : vErrors.concat(validate168.errors);
errors = vErrors.length;
}
var valid13 = _errs96 === errors;
}
else {
var valid13 = true;
}
if(valid13){
if(data48.work_rows !== undefined){
const _errs97 = errors;
if(!(validate168(data48.work_rows, {instancePath:instancePath+"/settings/flush/work_rows",parentData:data48,parentDataProperty:"work_rows",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate168.errors : vErrors.concat(validate168.errors);
errors = vErrors.length;
}
var valid13 = _errs97 === errors;
}
else {
var valid13 = true;
}
if(valid13){
if(data48.bytes !== undefined){
const _errs98 = errors;
if(!(validate56(data48.bytes, {instancePath:instancePath+"/settings/flush/bytes",parentData:data48,parentDataProperty:"bytes",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid13 = _errs98 === errors;
}
else {
var valid13 = true;
}
if(valid13){
if(data48.age_ms !== undefined){
const _errs99 = errors;
if(!(validate59(data48.age_ms, {instancePath:instancePath+"/settings/flush/age_ms",parentData:data48,parentDataProperty:"age_ms",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate59.errors : vErrors.concat(validate59.errors);
errors = vErrors.length;
}
var valid13 = _errs99 === errors;
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
var valid11 = _errs91 === errors;
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
var _valid5 = _errs77 === errors;
valid10 = valid10 || _valid5;
const _errs100 = errors;
if(data40 !== null){
const err40 = {};
if(vErrors === null){
vErrors = [err40];
}
else {
vErrors.push(err40);
}
errors++;
}
var _valid5 = _errs100 === errors;
valid10 = valid10 || _valid5;
if(!valid10){
const err41 = {};
if(vErrors === null){
vErrors = [err41];
}
else {
vErrors.push(err41);
}
errors++;
validate365.errors = vErrors;
return false;
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
var valid0 = _errs75 === errors;
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
validate365.errors = [{}];
return false;
}
}
validate365.errors = vErrors;
return errors === 0;
}
validate365.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};
