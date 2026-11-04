// Generated; no runtime code generation or eval.
import lengthModule from "ajv/dist/runtime/ucs2length.js";
const ucs2length = lengthModule.default ?? lengthModule;
"use strict";
export const StorageResponse = validate363;
const schema98 = {"type":"object","additionalProperties":false,"properties":{"realm":{"$ref":"https://transit.invalid/generated-validator/1"},"position":{"$ref":"https://transit.invalid/generated-validator/1"},"backend":{"type":"string","enum":["unavailable","local","ursula"]},"root":{"anyOf":[{"type":"string","maxLength":4096},{"type":"null"}]},"allocated_bytes":{"$ref":"https://transit.invalid/generated-validator/2"},"limits":{"anyOf":[{"type":"object","additionalProperties":false,"properties":{"bytes":{"$ref":"https://transit.invalid/generated-validator/1"},"control_bytes":{"$ref":"https://transit.invalid/generated-validator/1"},"candidate_bytes":{"$ref":"https://transit.invalid/generated-validator/0"}},"required":["bytes","control_bytes","candidate_bytes"]},{"type":"null"}]},"data_requests":{"$ref":"https://transit.invalid/generated-validator/110"},"control_requests":{"$ref":"https://transit.invalid/generated-validator/110"},"request_limit_bytes":{"$ref":"https://transit.invalid/generated-validator/2"},"maintenance":{"anyOf":[{"type":"object","additionalProperties":false,"properties":{"enabled":{"type":"boolean"},"state":{"type":"string","enum":["disabled","waiting","running","failed"]},"completed_steps":{"$ref":"https://transit.invalid/generated-validator/1"},"failed_steps":{"$ref":"https://transit.invalid/generated-validator/1"},"last_failure":{"anyOf":[{"type":"string","enum":["capacity","denied","clock","timeout","recovery","storage","other"]},{"type":"null"}]},"interval_ms":{"$ref":"https://transit.invalid/generated-validator/0"},"operation_timeout_ms":{"$ref":"https://transit.invalid/generated-validator/0"}},"required":["enabled","state","completed_steps","failed_steps","last_failure","interval_ms","operation_timeout_ms"]},{"type":"null"}]},"settings":{"anyOf":[{"type":"object","additionalProperties":false,"properties":{"collection_every_records":{"$ref":"https://transit.invalid/generated-validator/1"},"compact":{"type":"boolean"},"compaction_rows":{"$ref":"https://transit.invalid/generated-validator/4"},"resident_bytes":{"$ref":"https://transit.invalid/generated-validator/0"},"archive":{"type":"object","additionalProperties":false,"properties":{"enabled":{"type":"boolean"},"work_frames":{"$ref":"https://transit.invalid/generated-validator/9"}},"required":["enabled","work_frames"]},"flush":{"type":"object","additionalProperties":false,"properties":{"enabled":{"type":"boolean"},"rows":{"$ref":"https://transit.invalid/generated-validator/4"},"work_rows":{"$ref":"https://transit.invalid/generated-validator/4"},"bytes":{"$ref":"https://transit.invalid/generated-validator/1"},"age_ms":{"$ref":"https://transit.invalid/generated-validator/0"}},"required":["enabled","rows","work_rows","bytes","age_ms"]}},"required":["collection_every_records","compact","compaction_rows","resident_bytes","archive","flush"]},{"type":"null"}]}},"required":["realm","position","backend","root","allocated_bytes","limits","data_requests","control_requests","request_limit_bytes","maintenance","settings"]};
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

const schema99 = {"anyOf":[{"$ref":"https://transit.invalid/generated-validator/109"},{"type":"null"}]};
const schema100 = {"type":"object","additionalProperties":false,"properties":{"limit":{"$ref":"https://transit.invalid/generated-validator/1"},"used":{"$ref":"https://transit.invalid/generated-validator/1"},"peak":{"$ref":"https://transit.invalid/generated-validator/1"}},"required":["limit","used","peak"]};

function validate371(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate371.evaluated;
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
validate371.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "limit") || (key0 === "used")) || (key0 === "peak"))){
validate371.errors = [{}];
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
validate371.errors = [{}];
return false;
}
}
validate371.errors = vErrors;
return errors === 0;
}
validate371.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate370(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate370.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate371(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate371.errors : vErrors.concat(validate371.errors);
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
validate370.errors = vErrors;
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
validate370.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate370.evaluated = {"dynamicProps":true,"dynamicItems":false};

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


function validate363(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate363.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((((((((((((data.realm === undefined) && (missing0 = "realm")) || ((data.position === undefined) && (missing0 = "position"))) || ((data.backend === undefined) && (missing0 = "backend"))) || ((data.root === undefined) && (missing0 = "root"))) || ((data.allocated_bytes === undefined) && (missing0 = "allocated_bytes"))) || ((data.limits === undefined) && (missing0 = "limits"))) || ((data.data_requests === undefined) && (missing0 = "data_requests"))) || ((data.control_requests === undefined) && (missing0 = "control_requests"))) || ((data.request_limit_bytes === undefined) && (missing0 = "request_limit_bytes"))) || ((data.maintenance === undefined) && (missing0 = "maintenance"))) || ((data.settings === undefined) && (missing0 = "settings"))){
validate363.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(func1.call(schema98.properties, key0))){
validate363.errors = [{}];
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
validate363.errors = [{}];
return false;
}
if(!(((data2 === "unavailable") || (data2 === "local")) || (data2 === "ursula"))){
validate363.errors = [{}];
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
validate363.errors = vErrors;
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
if(data.allocated_bytes !== undefined){
const _errs12 = errors;
if(!(validate62(data.allocated_bytes, {instancePath:instancePath+"/allocated_bytes",parentData:data,parentDataProperty:"allocated_bytes",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate62.errors : vErrors.concat(validate62.errors);
errors = vErrors.length;
}
var valid0 = _errs12 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.limits !== undefined){
let data5 = data.limits;
const _errs13 = errors;
const _errs14 = errors;
let valid2 = false;
const _errs15 = errors;
if(errors === _errs15){
if(data5 && typeof data5 == "object" && !Array.isArray(data5)){
let missing1;
if((((data5.bytes === undefined) && (missing1 = "bytes")) || ((data5.control_bytes === undefined) && (missing1 = "control_bytes"))) || ((data5.candidate_bytes === undefined) && (missing1 = "candidate_bytes"))){
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
const _errs17 = errors;
for(const key1 in data5){
if(!(((key1 === "bytes") || (key1 === "control_bytes")) || (key1 === "candidate_bytes"))){
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
if(_errs17 === errors){
if(data5.bytes !== undefined){
const _errs18 = errors;
if(!(validate56(data5.bytes, {instancePath:instancePath+"/limits/bytes",parentData:data5,parentDataProperty:"bytes",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid3 = _errs18 === errors;
}
else {
var valid3 = true;
}
if(valid3){
if(data5.control_bytes !== undefined){
const _errs19 = errors;
if(!(validate56(data5.control_bytes, {instancePath:instancePath+"/limits/control_bytes",parentData:data5,parentDataProperty:"control_bytes",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid3 = _errs19 === errors;
}
else {
var valid3 = true;
}
if(valid3){
if(data5.candidate_bytes !== undefined){
const _errs20 = errors;
if(!(validate59(data5.candidate_bytes, {instancePath:instancePath+"/limits/candidate_bytes",parentData:data5,parentDataProperty:"candidate_bytes",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate59.errors : vErrors.concat(validate59.errors);
errors = vErrors.length;
}
var valid3 = _errs20 === errors;
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
const err6 = {};
if(vErrors === null){
vErrors = [err6];
}
else {
vErrors.push(err6);
}
errors++;
}
}
var _valid1 = _errs15 === errors;
valid2 = valid2 || _valid1;
const _errs21 = errors;
if(data5 !== null){
const err7 = {};
if(vErrors === null){
vErrors = [err7];
}
else {
vErrors.push(err7);
}
errors++;
}
var _valid1 = _errs21 === errors;
valid2 = valid2 || _valid1;
if(!valid2){
const err8 = {};
if(vErrors === null){
vErrors = [err8];
}
else {
vErrors.push(err8);
}
errors++;
validate363.errors = vErrors;
return false;
}
else {
errors = _errs14;
if(vErrors !== null){
if(_errs14){
vErrors.length = _errs14;
}
else {
vErrors = null;
}
}
}
var valid0 = _errs13 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.data_requests !== undefined){
const _errs23 = errors;
if(!(validate370(data.data_requests, {instancePath:instancePath+"/data_requests",parentData:data,parentDataProperty:"data_requests",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate370.errors : vErrors.concat(validate370.errors);
errors = vErrors.length;
}
var valid0 = _errs23 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.control_requests !== undefined){
const _errs24 = errors;
if(!(validate370(data.control_requests, {instancePath:instancePath+"/control_requests",parentData:data,parentDataProperty:"control_requests",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate370.errors : vErrors.concat(validate370.errors);
errors = vErrors.length;
}
var valid0 = _errs24 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.request_limit_bytes !== undefined){
const _errs25 = errors;
if(!(validate62(data.request_limit_bytes, {instancePath:instancePath+"/request_limit_bytes",parentData:data,parentDataProperty:"request_limit_bytes",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate62.errors : vErrors.concat(validate62.errors);
errors = vErrors.length;
}
var valid0 = _errs25 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.maintenance !== undefined){
let data12 = data.maintenance;
const _errs26 = errors;
const _errs27 = errors;
let valid4 = false;
const _errs28 = errors;
if(errors === _errs28){
if(data12 && typeof data12 == "object" && !Array.isArray(data12)){
let missing2;
if((((((((data12.enabled === undefined) && (missing2 = "enabled")) || ((data12.state === undefined) && (missing2 = "state"))) || ((data12.completed_steps === undefined) && (missing2 = "completed_steps"))) || ((data12.failed_steps === undefined) && (missing2 = "failed_steps"))) || ((data12.last_failure === undefined) && (missing2 = "last_failure"))) || ((data12.interval_ms === undefined) && (missing2 = "interval_ms"))) || ((data12.operation_timeout_ms === undefined) && (missing2 = "operation_timeout_ms"))){
const err9 = {};
if(vErrors === null){
vErrors = [err9];
}
else {
vErrors.push(err9);
}
errors++;
}
else {
const _errs30 = errors;
for(const key2 in data12){
if(!(((((((key2 === "enabled") || (key2 === "state")) || (key2 === "completed_steps")) || (key2 === "failed_steps")) || (key2 === "last_failure")) || (key2 === "interval_ms")) || (key2 === "operation_timeout_ms"))){
const err10 = {};
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
if(_errs30 === errors){
if(data12.enabled !== undefined){
const _errs31 = errors;
if(typeof data12.enabled !== "boolean"){
const err11 = {};
if(vErrors === null){
vErrors = [err11];
}
else {
vErrors.push(err11);
}
errors++;
}
var valid5 = _errs31 === errors;
}
else {
var valid5 = true;
}
if(valid5){
if(data12.state !== undefined){
let data14 = data12.state;
const _errs33 = errors;
if(typeof data14 !== "string"){
const err12 = {};
if(vErrors === null){
vErrors = [err12];
}
else {
vErrors.push(err12);
}
errors++;
}
if(!((((data14 === "disabled") || (data14 === "waiting")) || (data14 === "running")) || (data14 === "failed"))){
const err13 = {};
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
if(data12.completed_steps !== undefined){
const _errs35 = errors;
if(!(validate56(data12.completed_steps, {instancePath:instancePath+"/maintenance/completed_steps",parentData:data12,parentDataProperty:"completed_steps",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid5 = _errs35 === errors;
}
else {
var valid5 = true;
}
if(valid5){
if(data12.failed_steps !== undefined){
const _errs36 = errors;
if(!(validate56(data12.failed_steps, {instancePath:instancePath+"/maintenance/failed_steps",parentData:data12,parentDataProperty:"failed_steps",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid5 = _errs36 === errors;
}
else {
var valid5 = true;
}
if(valid5){
if(data12.last_failure !== undefined){
let data17 = data12.last_failure;
const _errs37 = errors;
const _errs38 = errors;
let valid6 = false;
const _errs39 = errors;
if(typeof data17 !== "string"){
const err14 = {};
if(vErrors === null){
vErrors = [err14];
}
else {
vErrors.push(err14);
}
errors++;
}
if(!(((((((data17 === "capacity") || (data17 === "denied")) || (data17 === "clock")) || (data17 === "timeout")) || (data17 === "recovery")) || (data17 === "storage")) || (data17 === "other"))){
const err15 = {};
if(vErrors === null){
vErrors = [err15];
}
else {
vErrors.push(err15);
}
errors++;
}
var _valid3 = _errs39 === errors;
valid6 = valid6 || _valid3;
const _errs41 = errors;
if(data17 !== null){
const err16 = {};
if(vErrors === null){
vErrors = [err16];
}
else {
vErrors.push(err16);
}
errors++;
}
var _valid3 = _errs41 === errors;
valid6 = valid6 || _valid3;
if(!valid6){
const err17 = {};
if(vErrors === null){
vErrors = [err17];
}
else {
vErrors.push(err17);
}
errors++;
}
else {
errors = _errs38;
if(vErrors !== null){
if(_errs38){
vErrors.length = _errs38;
}
else {
vErrors = null;
}
}
}
var valid5 = _errs37 === errors;
}
else {
var valid5 = true;
}
if(valid5){
if(data12.interval_ms !== undefined){
const _errs43 = errors;
if(!(validate59(data12.interval_ms, {instancePath:instancePath+"/maintenance/interval_ms",parentData:data12,parentDataProperty:"interval_ms",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate59.errors : vErrors.concat(validate59.errors);
errors = vErrors.length;
}
var valid5 = _errs43 === errors;
}
else {
var valid5 = true;
}
if(valid5){
if(data12.operation_timeout_ms !== undefined){
const _errs44 = errors;
if(!(validate59(data12.operation_timeout_ms, {instancePath:instancePath+"/maintenance/operation_timeout_ms",parentData:data12,parentDataProperty:"operation_timeout_ms",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate59.errors : vErrors.concat(validate59.errors);
errors = vErrors.length;
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
}
}
}
}
else {
const err18 = {};
if(vErrors === null){
vErrors = [err18];
}
else {
vErrors.push(err18);
}
errors++;
}
}
var _valid2 = _errs28 === errors;
valid4 = valid4 || _valid2;
const _errs45 = errors;
if(data12 !== null){
const err19 = {};
if(vErrors === null){
vErrors = [err19];
}
else {
vErrors.push(err19);
}
errors++;
}
var _valid2 = _errs45 === errors;
valid4 = valid4 || _valid2;
if(!valid4){
const err20 = {};
if(vErrors === null){
vErrors = [err20];
}
else {
vErrors.push(err20);
}
errors++;
validate363.errors = vErrors;
return false;
}
else {
errors = _errs27;
if(vErrors !== null){
if(_errs27){
vErrors.length = _errs27;
}
else {
vErrors = null;
}
}
}
var valid0 = _errs26 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.settings !== undefined){
let data20 = data.settings;
const _errs47 = errors;
const _errs48 = errors;
let valid7 = false;
const _errs49 = errors;
if(errors === _errs49){
if(data20 && typeof data20 == "object" && !Array.isArray(data20)){
let missing3;
if(((((((data20.collection_every_records === undefined) && (missing3 = "collection_every_records")) || ((data20.compact === undefined) && (missing3 = "compact"))) || ((data20.compaction_rows === undefined) && (missing3 = "compaction_rows"))) || ((data20.resident_bytes === undefined) && (missing3 = "resident_bytes"))) || ((data20.archive === undefined) && (missing3 = "archive"))) || ((data20.flush === undefined) && (missing3 = "flush"))){
const err21 = {};
if(vErrors === null){
vErrors = [err21];
}
else {
vErrors.push(err21);
}
errors++;
}
else {
const _errs51 = errors;
for(const key3 in data20){
if(!((((((key3 === "collection_every_records") || (key3 === "compact")) || (key3 === "compaction_rows")) || (key3 === "resident_bytes")) || (key3 === "archive")) || (key3 === "flush"))){
const err22 = {};
if(vErrors === null){
vErrors = [err22];
}
else {
vErrors.push(err22);
}
errors++;
break;
}
}
if(_errs51 === errors){
if(data20.collection_every_records !== undefined){
const _errs52 = errors;
if(!(validate56(data20.collection_every_records, {instancePath:instancePath+"/settings/collection_every_records",parentData:data20,parentDataProperty:"collection_every_records",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid8 = _errs52 === errors;
}
else {
var valid8 = true;
}
if(valid8){
if(data20.compact !== undefined){
const _errs53 = errors;
if(typeof data20.compact !== "boolean"){
const err23 = {};
if(vErrors === null){
vErrors = [err23];
}
else {
vErrors.push(err23);
}
errors++;
}
var valid8 = _errs53 === errors;
}
else {
var valid8 = true;
}
if(valid8){
if(data20.compaction_rows !== undefined){
const _errs55 = errors;
if(!(validate168(data20.compaction_rows, {instancePath:instancePath+"/settings/compaction_rows",parentData:data20,parentDataProperty:"compaction_rows",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate168.errors : vErrors.concat(validate168.errors);
errors = vErrors.length;
}
var valid8 = _errs55 === errors;
}
else {
var valid8 = true;
}
if(valid8){
if(data20.resident_bytes !== undefined){
const _errs56 = errors;
if(!(validate59(data20.resident_bytes, {instancePath:instancePath+"/settings/resident_bytes",parentData:data20,parentDataProperty:"resident_bytes",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate59.errors : vErrors.concat(validate59.errors);
errors = vErrors.length;
}
var valid8 = _errs56 === errors;
}
else {
var valid8 = true;
}
if(valid8){
if(data20.archive !== undefined){
let data25 = data20.archive;
const _errs57 = errors;
if(errors === _errs57){
if(data25 && typeof data25 == "object" && !Array.isArray(data25)){
let missing4;
if(((data25.enabled === undefined) && (missing4 = "enabled")) || ((data25.work_frames === undefined) && (missing4 = "work_frames"))){
const err24 = {};
if(vErrors === null){
vErrors = [err24];
}
else {
vErrors.push(err24);
}
errors++;
}
else {
const _errs59 = errors;
for(const key4 in data25){
if(!((key4 === "enabled") || (key4 === "work_frames"))){
const err25 = {};
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
if(_errs59 === errors){
if(data25.enabled !== undefined){
const _errs60 = errors;
if(typeof data25.enabled !== "boolean"){
const err26 = {};
if(vErrors === null){
vErrors = [err26];
}
else {
vErrors.push(err26);
}
errors++;
}
var valid9 = _errs60 === errors;
}
else {
var valid9 = true;
}
if(valid9){
if(data25.work_frames !== undefined){
const _errs62 = errors;
if(!(validate134(data25.work_frames, {instancePath:instancePath+"/settings/archive/work_frames",parentData:data25,parentDataProperty:"work_frames",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate134.errors : vErrors.concat(validate134.errors);
errors = vErrors.length;
}
var valid9 = _errs62 === errors;
}
else {
var valid9 = true;
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
var valid8 = _errs57 === errors;
}
else {
var valid8 = true;
}
if(valid8){
if(data20.flush !== undefined){
let data28 = data20.flush;
const _errs63 = errors;
if(errors === _errs63){
if(data28 && typeof data28 == "object" && !Array.isArray(data28)){
let missing5;
if((((((data28.enabled === undefined) && (missing5 = "enabled")) || ((data28.rows === undefined) && (missing5 = "rows"))) || ((data28.work_rows === undefined) && (missing5 = "work_rows"))) || ((data28.bytes === undefined) && (missing5 = "bytes"))) || ((data28.age_ms === undefined) && (missing5 = "age_ms"))){
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
const _errs65 = errors;
for(const key5 in data28){
if(!(((((key5 === "enabled") || (key5 === "rows")) || (key5 === "work_rows")) || (key5 === "bytes")) || (key5 === "age_ms"))){
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
if(_errs65 === errors){
if(data28.enabled !== undefined){
const _errs66 = errors;
if(typeof data28.enabled !== "boolean"){
const err30 = {};
if(vErrors === null){
vErrors = [err30];
}
else {
vErrors.push(err30);
}
errors++;
}
var valid10 = _errs66 === errors;
}
else {
var valid10 = true;
}
if(valid10){
if(data28.rows !== undefined){
const _errs68 = errors;
if(!(validate168(data28.rows, {instancePath:instancePath+"/settings/flush/rows",parentData:data28,parentDataProperty:"rows",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate168.errors : vErrors.concat(validate168.errors);
errors = vErrors.length;
}
var valid10 = _errs68 === errors;
}
else {
var valid10 = true;
}
if(valid10){
if(data28.work_rows !== undefined){
const _errs69 = errors;
if(!(validate168(data28.work_rows, {instancePath:instancePath+"/settings/flush/work_rows",parentData:data28,parentDataProperty:"work_rows",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate168.errors : vErrors.concat(validate168.errors);
errors = vErrors.length;
}
var valid10 = _errs69 === errors;
}
else {
var valid10 = true;
}
if(valid10){
if(data28.bytes !== undefined){
const _errs70 = errors;
if(!(validate56(data28.bytes, {instancePath:instancePath+"/settings/flush/bytes",parentData:data28,parentDataProperty:"bytes",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid10 = _errs70 === errors;
}
else {
var valid10 = true;
}
if(valid10){
if(data28.age_ms !== undefined){
const _errs71 = errors;
if(!(validate59(data28.age_ms, {instancePath:instancePath+"/settings/flush/age_ms",parentData:data28,parentDataProperty:"age_ms",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate59.errors : vErrors.concat(validate59.errors);
errors = vErrors.length;
}
var valid10 = _errs71 === errors;
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
else {
const err31 = {};
if(vErrors === null){
vErrors = [err31];
}
else {
vErrors.push(err31);
}
errors++;
}
}
var valid8 = _errs63 === errors;
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
var _valid4 = _errs49 === errors;
valid7 = valid7 || _valid4;
const _errs72 = errors;
if(data20 !== null){
const err33 = {};
if(vErrors === null){
vErrors = [err33];
}
else {
vErrors.push(err33);
}
errors++;
}
var _valid4 = _errs72 === errors;
valid7 = valid7 || _valid4;
if(!valid7){
const err34 = {};
if(vErrors === null){
vErrors = [err34];
}
else {
vErrors.push(err34);
}
errors++;
validate363.errors = vErrors;
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
}
}
}
}
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
validate363.errors = [{}];
return false;
}
}
validate363.errors = vErrors;
return errors === 0;
}
validate363.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};
