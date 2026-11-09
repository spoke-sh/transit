// Generated; no runtime code generation or eval.
import lengthModule from "ajv/dist/runtime/ucs2length.js";
const ucs2length = lengthModule.default ?? lengthModule;
"use strict";
export const AtlasResponse = validate399;
const schema102 = {"type":"object","additionalProperties":false,"properties":{"version":{"$ref":"https://transit.invalid/generated-validator/9"},"realm":{"$ref":"https://transit.invalid/generated-validator/1"},"position":{"$ref":"https://transit.invalid/generated-validator/1"},"identity":{"$ref":"https://transit.invalid/generated-validator/5"},"processes":{"type":"object","additionalProperties":false,"properties":{"entries":{"$ref":"https://transit.invalid/generated-validator/28"},"next":{"$ref":"https://transit.invalid/generated-validator/2"}},"required":["entries","next"]},"resources":{"type":"object","additionalProperties":false,"properties":{"entries":{"$ref":"https://transit.invalid/generated-validator/71"},"next":{"$ref":"https://transit.invalid/generated-validator/2"}},"required":["entries","next"]},"query_resource":{"$ref":"https://transit.invalid/generated-validator/2"},"query_version":{"anyOf":[{"$ref":"https://transit.invalid/generated-validator/9"},{"type":"null"}]}},"required":["version","realm","position","identity","processes","resources","query_resource","query_version"]};
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


function validate399(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate399.evaluated;
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
validate399.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((((((((key0 === "version") || (key0 === "realm")) || (key0 === "position")) || (key0 === "identity")) || (key0 === "processes")) || (key0 === "resources")) || (key0 === "query_resource")) || (key0 === "query_version"))){
validate399.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.version !== undefined){
const _errs2 = errors;
if(!(validate134(data.version, {instancePath:instancePath+"/version",parentData:data,parentDataProperty:"version",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate134.errors : vErrors.concat(validate134.errors);
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
if(!(validate56(data.realm, {instancePath:instancePath+"/realm",parentData:data,parentDataProperty:"realm",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
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
if(!(validate56(data.position, {instancePath:instancePath+"/position",parentData:data,parentDataProperty:"position",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
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
if(!(validate166(data.identity, {instancePath:instancePath+"/identity",parentData:data,parentDataProperty:"identity",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate166.errors : vErrors.concat(validate166.errors);
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
validate399.errors = [{}];
return false;
}
else {
const _errs8 = errors;
for(const key1 in data4){
if(!((key1 === "entries") || (key1 === "next"))){
validate399.errors = [{}];
return false;
break;
}
}
if(_errs8 === errors){
if(data4.entries !== undefined){
const _errs9 = errors;
if(!(validate176(data4.entries, {instancePath:instancePath+"/processes/entries",parentData:data4,parentDataProperty:"entries",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate176.errors : vErrors.concat(validate176.errors);
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
if(!(validate62(data4.next, {instancePath:instancePath+"/processes/next",parentData:data4,parentDataProperty:"next",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate62.errors : vErrors.concat(validate62.errors);
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
validate399.errors = [{}];
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
validate399.errors = [{}];
return false;
}
else {
const _errs13 = errors;
for(const key2 in data7){
if(!((key2 === "entries") || (key2 === "next"))){
validate399.errors = [{}];
return false;
break;
}
}
if(_errs13 === errors){
if(data7.entries !== undefined){
const _errs14 = errors;
if(!(validate304(data7.entries, {instancePath:instancePath+"/resources/entries",parentData:data7,parentDataProperty:"entries",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate304.errors : vErrors.concat(validate304.errors);
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
if(!(validate62(data7.next, {instancePath:instancePath+"/resources/next",parentData:data7,parentDataProperty:"next",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate62.errors : vErrors.concat(validate62.errors);
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
validate399.errors = [{}];
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
if(!(validate62(data.query_resource, {instancePath:instancePath+"/query_resource",parentData:data,parentDataProperty:"query_resource",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate62.errors : vErrors.concat(validate62.errors);
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
if(!(validate134(data11, {instancePath:instancePath+"/query_version",parentData:data,parentDataProperty:"query_version",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate134.errors : vErrors.concat(validate134.errors);
errors = vErrors.length;
}
var _valid0 = _errs19 === errors;
valid3 = valid3 || _valid0;
const _errs20 = errors;
if(data11 !== null){
const err0 = {};
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
const err1 = {};
if(vErrors === null){
vErrors = [err1];
}
else {
vErrors.push(err1);
}
errors++;
validate399.errors = vErrors;
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
validate399.errors = [{}];
return false;
}
}
validate399.errors = vErrors;
return errors === 0;
}
validate399.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

export const ParticipationResponse = validate410;
const schema103 = {"type":"object","additionalProperties":false,"properties":{"version":{"$ref":"https://transit.invalid/generated-validator/9"},"realm":{"$ref":"https://transit.invalid/generated-validator/1"},"resource":{"$ref":"https://transit.invalid/generated-validator/69"},"resource_position":{"$ref":"https://transit.invalid/generated-validator/1"},"process_position":{"$ref":"https://transit.invalid/generated-validator/2"},"policy_revision":{"$ref":"https://transit.invalid/generated-validator/1"},"members":{"type":"array","minItems":8,"maxItems":8,"items":{"anyOf":[{"type":"object","additionalProperties":false,"properties":{"pid":{"$ref":"https://transit.invalid/generated-validator/1"},"association_position":{"$ref":"https://transit.invalid/generated-validator/1"},"matches":{"$ref":"https://transit.invalid/generated-validator/9"},"next":{"$ref":"https://transit.invalid/generated-validator/2"}},"required":["pid","association_position","matches","next"]},{"type":"null"}]}},"next":{"$ref":"https://transit.invalid/generated-validator/2"}},"required":["version","realm","resource","resource_position","process_position","policy_revision","members","next"]};

function validate410(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate410.evaluated;
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
validate410.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((((((((key0 === "version") || (key0 === "realm")) || (key0 === "resource")) || (key0 === "resource_position")) || (key0 === "process_position")) || (key0 === "policy_revision")) || (key0 === "members")) || (key0 === "next"))){
validate410.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.version !== undefined){
const _errs2 = errors;
if(!(validate134(data.version, {instancePath:instancePath+"/version",parentData:data,parentDataProperty:"version",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate134.errors : vErrors.concat(validate134.errors);
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
if(!(validate56(data.realm, {instancePath:instancePath+"/realm",parentData:data,parentDataProperty:"realm",rootData,dynamicAnchors}))){
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
if(!(validate306(data.resource, {instancePath:instancePath+"/resource",parentData:data,parentDataProperty:"resource",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate306.errors : vErrors.concat(validate306.errors);
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
if(!(validate56(data.resource_position, {instancePath:instancePath+"/resource_position",parentData:data,parentDataProperty:"resource_position",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
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
if(!(validate62(data.process_position, {instancePath:instancePath+"/process_position",parentData:data,parentDataProperty:"process_position",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate62.errors : vErrors.concat(validate62.errors);
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
if(!(validate56(data.policy_revision, {instancePath:instancePath+"/policy_revision",parentData:data,parentDataProperty:"policy_revision",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
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
validate410.errors = [{}];
return false;
}
else {
if(data6.length < 8){
validate410.errors = [{}];
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
const _errs14 = errors;
for(const key1 in data7){
if(!((((key1 === "pid") || (key1 === "association_position")) || (key1 === "matches")) || (key1 === "next"))){
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
if(_errs14 === errors){
if(data7.pid !== undefined){
const _errs15 = errors;
if(!(validate56(data7.pid, {instancePath:instancePath+"/members/" + i0+"/pid",parentData:data7,parentDataProperty:"pid",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
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
if(!(validate56(data7.association_position, {instancePath:instancePath+"/members/" + i0+"/association_position",parentData:data7,parentDataProperty:"association_position",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
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
if(!(validate134(data7.matches, {instancePath:instancePath+"/members/" + i0+"/matches",parentData:data7,parentDataProperty:"matches",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate134.errors : vErrors.concat(validate134.errors);
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
if(!(validate62(data7.next, {instancePath:instancePath+"/members/" + i0+"/next",parentData:data7,parentDataProperty:"next",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate62.errors : vErrors.concat(validate62.errors);
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
const err2 = {};
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
const err3 = {};
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
const err4 = {};
if(vErrors === null){
vErrors = [err4];
}
else {
vErrors.push(err4);
}
errors++;
validate410.errors = vErrors;
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
validate410.errors = [{}];
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
if(!(validate62(data.next, {instancePath:instancePath+"/next",parentData:data,parentDataProperty:"next",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate62.errors : vErrors.concat(validate62.errors);
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
validate410.errors = [{}];
return false;
}
}
validate410.errors = vErrors;
return errors === 0;
}
validate410.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

export const RecordsResponse = validate422;
const schema104 = {"type":"object","additionalProperties":false,"properties":{"version":{"$ref":"https://transit.invalid/generated-validator/9"},"realm":{"$ref":"https://transit.invalid/generated-validator/1"},"position":{"$ref":"https://transit.invalid/generated-validator/1"},"resource":{"$ref":"https://transit.invalid/generated-validator/69"},"page":{"type":"object","additionalProperties":false,"properties":{"entries":{"type":"array","minItems":8,"maxItems":8,"items":{"anyOf":[{"type":"object","additionalProperties":false,"properties":{"key":{"$ref":"https://transit.invalid/generated-validator/21"},"revision":{"$ref":"https://transit.invalid/generated-validator/1"}},"required":["key","revision"]},{"type":"null"}]}},"next":{"$ref":"https://transit.invalid/generated-validator/22"}},"required":["entries","next"]},"exchanges":{"type":"array","minItems":8,"maxItems":8,"items":{"anyOf":[{"type":"object","additionalProperties":false,"properties":{"version":{"$ref":"https://transit.invalid/generated-validator/9"},"source":{"$ref":"https://transit.invalid/generated-validator/72"},"declaration":{"oneOf":[{"type":"object","additionalProperties":false,"required":["failure"],"properties":{"failure":{"$ref":"https://transit.invalid/generated-validator/77"}}},{"type":"object","additionalProperties":false,"required":["capture"],"properties":{"capture":{"type":"object","additionalProperties":false,"properties":{"exchange":{"type":"string","maxLength":256},"protocol":{"$ref":"https://transit.invalid/generated-validator/0"},"phase":{"$ref":"https://transit.invalid/generated-validator/76"},"caller":{"$ref":"https://transit.invalid/generated-validator/1"},"input":{"$ref":"https://transit.invalid/generated-validator/1"},"owner":{"$ref":"https://transit.invalid/generated-validator/1"},"parent":{"type":"string","maxLength":256},"effect":{"$ref":"https://transit.invalid/generated-validator/1"},"attempt":{"$ref":"https://transit.invalid/generated-validator/1"},"executor":{"$ref":"https://transit.invalid/generated-validator/1"},"reconcile_before_ms":{"$ref":"https://transit.invalid/generated-validator/1"},"segments":{"$ref":"https://transit.invalid/generated-validator/0"},"max_segments":{"$ref":"https://transit.invalid/generated-validator/0"},"bytes":{"type":"string","maxLength":256},"capture_bytes":{"type":"string","maxLength":256},"segment_bytes":{"$ref":"https://transit.invalid/generated-validator/0"},"pending_kind":{"$ref":"https://transit.invalid/generated-validator/0"},"terminal_code":{"$ref":"https://transit.invalid/generated-validator/0"},"collected":{"$ref":"https://transit.invalid/generated-validator/0"},"coverage":{"$ref":"https://transit.invalid/generated-validator/11"}},"required":["exchange","protocol","phase","caller","input","owner","parent","effect","attempt","executor","reconcile_before_ms","segments","max_segments","bytes","capture_bytes","segment_bytes","pending_kind","terminal_code","collected","coverage"]}}},{"type":"object","additionalProperties":false,"required":["obligations"],"properties":{"obligations":{"type":"object","additionalProperties":false,"properties":{"exchange":{"type":"string","maxLength":256},"dependents":{"type":"string","maxLength":256},"disposition":{"type":"string","enum":["no_intent","pending","observed","cancelled","closed_unknown"]},"caller":{"type":"string","enum":["none","held","released"]},"effect":{"$ref":"https://transit.invalid/generated-validator/1"}},"required":["exchange","dependents","disposition","caller","effect"]}}},{"type":"object","additionalProperties":false,"required":["lineage"],"properties":{"lineage":{"type":"object","additionalProperties":false,"properties":{"exchange":{"type":"string","maxLength":256},"root":{"type":"string","maxLength":256},"parent":{"type":"string","maxLength":256},"ordinal":{"$ref":"https://transit.invalid/generated-validator/0"},"reason":{"type":"string","enum":["retry","redirect","reconcile","cancel"]},"policy":{"type":"string","maxLength":256},"policy_revision":{"type":"string","maxLength":256}},"required":["exchange","root","parent","ordinal","reason","policy","policy_revision"]}}},{"type":"object","additionalProperties":false,"required":["attempts"],"properties":{"attempts":{"type":"object","additionalProperties":false,"properties":{"exchange":{"type":"string","maxLength":256},"limit":{"$ref":"https://transit.invalid/generated-validator/0"},"used":{"$ref":"https://transit.invalid/generated-validator/0"},"unsettled":{"$ref":"https://transit.invalid/generated-validator/0"}},"required":["exchange","limit","used","unsettled"]}}}]}},"required":["version","source","declaration"]},{"type":"null"}]}},"documents":{"type":"array","minItems":8,"maxItems":8,"items":{"anyOf":[{"type":"object","additionalProperties":false,"properties":{"version":{"$ref":"https://transit.invalid/generated-validator/9"},"source":{"$ref":"https://transit.invalid/generated-validator/72"},"declaration":{"$ref":"https://transit.invalid/generated-validator/78"}},"required":["version","source","declaration"]},{"type":"null"}]}},"queries":{"type":"array","minItems":8,"maxItems":8,"items":{"anyOf":[{"type":"object","additionalProperties":false,"properties":{"version":{"$ref":"https://transit.invalid/generated-validator/9"},"source":{"$ref":"https://transit.invalid/generated-validator/72"},"declaration":{"oneOf":[{"type":"object","additionalProperties":false,"required":["execution"],"properties":{"execution":{"type":"object","additionalProperties":false,"properties":{"result":{"$ref":"https://transit.invalid/generated-validator/1"},"destination":{"$ref":"https://transit.invalid/generated-validator/1"},"correlation":{"$ref":"https://transit.invalid/generated-validator/1"},"source":{"oneOf":[{"type":"object","additionalProperties":false,"required":["native"],"properties":{"native":{"type":"object","additionalProperties":false,"properties":{"pid":{"$ref":"https://transit.invalid/generated-validator/1"},"input":{"$ref":"https://transit.invalid/generated-validator/1"},"index":{"$ref":"https://transit.invalid/generated-validator/9"}},"required":["pid","input","index"]}}},{"type":"object","additionalProperties":false,"required":["table"],"properties":{"table":{"type":"object","additionalProperties":false,"properties":{"worker":{"$ref":"https://transit.invalid/generated-validator/1"}},"required":["worker"]}}}]},"request_resource":{"$ref":"https://transit.invalid/generated-validator/1"},"request_namespace":{"type":"string","maxLength":256},"phase":{"type":"string","enum":["capturing","captured","complete","cancelled","denied","failed","retired","admitted","acquiring"]},"failure":{"$ref":"https://transit.invalid/generated-validator/83"},"policy_revision":{"$ref":"https://transit.invalid/generated-validator/1"}},"required":["result","destination","correlation","source","request_resource","request_namespace","phase","failure","policy_revision"]}}},{"type":"object","additionalProperties":false,"required":["request"],"properties":{"request":{"type":"object","additionalProperties":false,"properties":{"namespace":{"type":"string","maxLength":256},"correlation":{"$ref":"https://transit.invalid/generated-validator/1"},"phase":{"$ref":"https://transit.invalid/generated-validator/84"},"failure":{"$ref":"https://transit.invalid/generated-validator/83"},"collected":{"type":"boolean"},"result_resource":{"$ref":"https://transit.invalid/generated-validator/2"},"result_namespace":{"$ref":"https://transit.invalid/generated-validator/75"},"result_digest":{"$ref":"https://transit.invalid/generated-validator/15"}},"required":["namespace","correlation","phase","failure","collected","result_resource","result_namespace","result_digest"]}}}]}},"required":["version","source","declaration"]},{"type":"null"}]}}},"required":["version","realm","position","resource","page","exchanges","documents","queries"]};
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

const schema105 = {"type":"object","additionalProperties":false,"properties":{"exchange":{"type":"string","maxLength":256},"resource":{"$ref":"https://transit.invalid/generated-validator/1"},"owner":{"$ref":"https://transit.invalid/generated-validator/1"},"principal":{"$ref":"https://transit.invalid/generated-validator/1"},"input":{"$ref":"https://transit.invalid/generated-validator/1"},"reason":{"$ref":"https://transit.invalid/generated-validator/73"},"operation":{"$ref":"https://transit.invalid/generated-validator/74"},"origin_input":{"$ref":"https://transit.invalid/generated-validator/1"},"kind":{"$ref":"https://transit.invalid/generated-validator/0"},"member":{"$ref":"https://transit.invalid/generated-validator/0"},"chunk":{"$ref":"https://transit.invalid/generated-validator/0"},"requested_bytes":{"$ref":"https://transit.invalid/generated-validator/0"},"cause":{"$ref":"https://transit.invalid/generated-validator/75"},"cause_truncated":{"type":"boolean"},"phase":{"$ref":"https://transit.invalid/generated-validator/76"},"effect":{"$ref":"https://transit.invalid/generated-validator/1"},"attempt":{"$ref":"https://transit.invalid/generated-validator/1"},"segments":{"$ref":"https://transit.invalid/generated-validator/0"},"bytes":{"type":"string","maxLength":256}},"required":["exchange","resource","owner","principal","input","reason","operation","origin_input","kind","member","chunk","requested_bytes","cause","cause_truncated","phase","effect","attempt","segments","bytes"]};
const schema106 = {"type":"string","enum":["caller_closed","controller_release","recovered_incomplete","transport_failure","capture_failure","preparation_failure"]};

function validate437(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate437.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate437.errors = [{}];
return false;
}
if(!((((((data === "caller_closed") || (data === "controller_release")) || (data === "recovered_incomplete")) || (data === "transport_failure")) || (data === "capture_failure")) || (data === "preparation_failure"))){
validate437.errors = [{}];
return false;
}
validate437.errors = vErrors;
return errors === 0;
}
validate437.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema107 = {"type":"string","enum":["none","callback","begin","append","seal"]};

function validate439(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate439.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate439.errors = [{}];
return false;
}
if(!(((((data === "none") || (data === "callback")) || (data === "begin")) || (data === "append")) || (data === "seal"))){
validate439.errors = [{}];
return false;
}
validate439.errors = vErrors;
return errors === 0;
}
validate439.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema108 = {"anyOf":[{"type":"string","maxLength":256},{"type":"null"}]};

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
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(errors === _errs1){
if(typeof data === "string"){
if(func3(data) > 256){
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
validate446.errors = vErrors;
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
validate446.errors = vErrors;
return errors === 0;
}
validate446.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema109 = {"type":"string","enum":["preparing","capturing","complete","unknown","retired","ready"]};

function validate448(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate448.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate448.errors = [{}];
return false;
}
if(!((((((data === "preparing") || (data === "capturing")) || (data === "complete")) || (data === "unknown")) || (data === "retired")) || (data === "ready"))){
validate448.errors = [{}];
return false;
}
validate448.errors = vErrors;
return errors === 0;
}
validate448.evaluated = {"dynamicProps":false,"dynamicItems":false};


function validate432(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate432.evaluated;
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
validate432.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(func1.call(schema105.properties, key0))){
validate432.errors = [{}];
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
if(func3(data0) > 256){
validate432.errors = [{}];
return false;
}
}
else {
validate432.errors = [{}];
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
if(data.owner !== undefined){
const _errs5 = errors;
if(!(validate56(data.owner, {instancePath:instancePath+"/owner",parentData:data,parentDataProperty:"owner",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
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
if(!(validate56(data.principal, {instancePath:instancePath+"/principal",parentData:data,parentDataProperty:"principal",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
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
if(!(validate56(data.input, {instancePath:instancePath+"/input",parentData:data,parentDataProperty:"input",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
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
if(!(validate437(data.reason, {instancePath:instancePath+"/reason",parentData:data,parentDataProperty:"reason",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate437.errors : vErrors.concat(validate437.errors);
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
if(!(validate439(data.operation, {instancePath:instancePath+"/operation",parentData:data,parentDataProperty:"operation",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate439.errors : vErrors.concat(validate439.errors);
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
if(!(validate56(data.origin_input, {instancePath:instancePath+"/origin_input",parentData:data,parentDataProperty:"origin_input",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
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
if(!(validate59(data.kind, {instancePath:instancePath+"/kind",parentData:data,parentDataProperty:"kind",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate59.errors : vErrors.concat(validate59.errors);
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
if(!(validate59(data.member, {instancePath:instancePath+"/member",parentData:data,parentDataProperty:"member",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate59.errors : vErrors.concat(validate59.errors);
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
if(!(validate59(data.chunk, {instancePath:instancePath+"/chunk",parentData:data,parentDataProperty:"chunk",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate59.errors : vErrors.concat(validate59.errors);
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
if(!(validate59(data.requested_bytes, {instancePath:instancePath+"/requested_bytes",parentData:data,parentDataProperty:"requested_bytes",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate59.errors : vErrors.concat(validate59.errors);
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
if(!(validate446(data.cause, {instancePath:instancePath+"/cause",parentData:data,parentDataProperty:"cause",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate446.errors : vErrors.concat(validate446.errors);
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
validate432.errors = [{}];
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
if(!(validate448(data.phase, {instancePath:instancePath+"/phase",parentData:data,parentDataProperty:"phase",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate448.errors : vErrors.concat(validate448.errors);
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
if(!(validate56(data.effect, {instancePath:instancePath+"/effect",parentData:data,parentDataProperty:"effect",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
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
if(!(validate56(data.attempt, {instancePath:instancePath+"/attempt",parentData:data,parentDataProperty:"attempt",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
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
if(!(validate59(data.segments, {instancePath:instancePath+"/segments",parentData:data,parentDataProperty:"segments",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate59.errors : vErrors.concat(validate59.errors);
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
if(func3(data18) > 256){
validate432.errors = [{}];
return false;
}
}
else {
validate432.errors = [{}];
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
validate432.errors = [{}];
return false;
}
}
validate432.errors = vErrors;
return errors === 0;
}
validate432.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema110 = {"type":"object","additionalProperties":false,"properties":{"document":{"type":"string","maxLength":256},"epoch":{"type":"string","maxLength":256},"type_revision":{"$ref":"https://transit.invalid/generated-validator/0"},"change_format":{"$ref":"https://transit.invalid/generated-validator/0"},"revision":{"type":"string","maxLength":256},"floor":{"type":"string","maxLength":256},"merge_window":{"type":"string","maxLength":256},"active_job":{"type":"string","maxLength":256},"retired":{"type":"boolean"}},"required":["document","epoch","type_revision","change_format","revision","floor","merge_window","active_job","retired"]};

function validate477(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate477.evaluated;
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
validate477.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(func1.call(schema110.properties, key0))){
validate477.errors = [{}];
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
if(func3(data0) > 256){
validate477.errors = [{}];
return false;
}
}
else {
validate477.errors = [{}];
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
if(func3(data1) > 256){
validate477.errors = [{}];
return false;
}
}
else {
validate477.errors = [{}];
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
if(!(validate59(data.type_revision, {instancePath:instancePath+"/type_revision",parentData:data,parentDataProperty:"type_revision",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate59.errors : vErrors.concat(validate59.errors);
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
if(!(validate59(data.change_format, {instancePath:instancePath+"/change_format",parentData:data,parentDataProperty:"change_format",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate59.errors : vErrors.concat(validate59.errors);
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
if(func3(data4) > 256){
validate477.errors = [{}];
return false;
}
}
else {
validate477.errors = [{}];
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
if(func3(data5) > 256){
validate477.errors = [{}];
return false;
}
}
else {
validate477.errors = [{}];
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
if(func3(data6) > 256){
validate477.errors = [{}];
return false;
}
}
else {
validate477.errors = [{}];
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
if(func3(data7) > 256){
validate477.errors = [{}];
return false;
}
}
else {
validate477.errors = [{}];
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
validate477.errors = [{}];
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
validate477.errors = [{}];
return false;
}
}
validate477.errors = vErrors;
return errors === 0;
}
validate477.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema111 = {"anyOf":[{"$ref":"https://transit.invalid/generated-validator/82"},{"type":"null"}]};
const schema112 = {"type":"object","additionalProperties":false,"properties":{"code":{"$ref":"https://transit.invalid/generated-validator/79"},"stage":{"$ref":"https://transit.invalid/generated-validator/80"},"dimension":{"$ref":"https://transit.invalid/generated-validator/81"},"limit":{"type":"string","maxLength":256},"observed":{"type":"string","maxLength":256}},"required":["code","stage","dimension","limit","observed"]};
const schema113 = {"type":"string","enum":["policy_denied","access_denied","resource_unavailable","request_unpublished","publisher_mismatch","document_history_gap","document_retired","document_resync_required","budget_exceeded","projection_budget","expansion_missing","expansion_null","expansion_conflict","expansion_type_error","cell_type_error","cell_conflict","arithmetic_overflow","segment_byte_limit","type_mismatch","unsupported_aggregate","unknown_column","invalid_projection","duplicate_projection","invalid_bundle","invalid_source","invalid_prefix","invalid_path","invalid_projection_budget","invalid_text_projection","invalid_element_projection","unsupported_source","unsupported_decoder","unsupported_document_source","invalid_source_encoding","invalid_plan_encoding","plan_definition_mismatch","invalid_output_names","unsupported_plan","plan_too_large","bundle_too_large","truncated_input","source_changed","table_schema_changed","invalid_budget","namespace_in_use","query_after_mutation","nonfinite_value","invalid_utf8","cell_too_large","invalid_column_name","invalid_column_count","duplicate_column","unsupported_schema","peer_mismatch","invalid_request_reference","writer_not_ready","request_resource_expired","request_resource_missing","catalog_read_denied","catalog_owner_changed","catalog_configuration_changed","catalog_uninitialized","table_absent","table_retired","table_definition_changed","definition_mismatch","value_budget","unsupported_comparison","source_definition_too_large","catalog_scope_changed","adapter_memory_budget","arrow_workspace_budget","missing_column_semantics","scalar_program_budget","invalid_scalar_reference","invalid_scalar_encoding","decimal_overflow","division_by_zero","inexact_decimal_rounding","timestamp_overflow","zero_magnitude_cosine_vector","invalid_time_bucket","nonexistent_local_time","ambiguous_local_time","timezone_coverage_unavailable","invalid_column_semantics"]};

function validate493(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate493.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate493.errors = [{}];
return false;
}
if(!((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((data === "policy_denied") || (data === "access_denied")) || (data === "resource_unavailable")) || (data === "request_unpublished")) || (data === "publisher_mismatch")) || (data === "document_history_gap")) || (data === "document_retired")) || (data === "document_resync_required")) || (data === "budget_exceeded")) || (data === "projection_budget")) || (data === "expansion_missing")) || (data === "expansion_null")) || (data === "expansion_conflict")) || (data === "expansion_type_error")) || (data === "cell_type_error")) || (data === "cell_conflict")) || (data === "arithmetic_overflow")) || (data === "segment_byte_limit")) || (data === "type_mismatch")) || (data === "unsupported_aggregate")) || (data === "unknown_column")) || (data === "invalid_projection")) || (data === "duplicate_projection")) || (data === "invalid_bundle")) || (data === "invalid_source")) || (data === "invalid_prefix")) || (data === "invalid_path")) || (data === "invalid_projection_budget")) || (data === "invalid_text_projection")) || (data === "invalid_element_projection")) || (data === "unsupported_source")) || (data === "unsupported_decoder")) || (data === "unsupported_document_source")) || (data === "invalid_source_encoding")) || (data === "invalid_plan_encoding")) || (data === "plan_definition_mismatch")) || (data === "invalid_output_names")) || (data === "unsupported_plan")) || (data === "plan_too_large")) || (data === "bundle_too_large")) || (data === "truncated_input")) || (data === "source_changed")) || (data === "table_schema_changed")) || (data === "invalid_budget")) || (data === "namespace_in_use")) || (data === "query_after_mutation")) || (data === "nonfinite_value")) || (data === "invalid_utf8")) || (data === "cell_too_large")) || (data === "invalid_column_name")) || (data === "invalid_column_count")) || (data === "duplicate_column")) || (data === "unsupported_schema")) || (data === "peer_mismatch")) || (data === "invalid_request_reference")) || (data === "writer_not_ready")) || (data === "request_resource_expired")) || (data === "request_resource_missing")) || (data === "catalog_read_denied")) || (data === "catalog_owner_changed")) || (data === "catalog_configuration_changed")) || (data === "catalog_uninitialized")) || (data === "table_absent")) || (data === "table_retired")) || (data === "table_definition_changed")) || (data === "definition_mismatch")) || (data === "value_budget")) || (data === "unsupported_comparison")) || (data === "source_definition_too_large")) || (data === "catalog_scope_changed")) || (data === "adapter_memory_budget")) || (data === "arrow_workspace_budget")) || (data === "missing_column_semantics")) || (data === "scalar_program_budget")) || (data === "invalid_scalar_reference")) || (data === "invalid_scalar_encoding")) || (data === "decimal_overflow")) || (data === "division_by_zero")) || (data === "inexact_decimal_rounding")) || (data === "timestamp_overflow")) || (data === "zero_magnitude_cosine_vector")) || (data === "invalid_time_bucket")) || (data === "nonexistent_local_time")) || (data === "ambiguous_local_time")) || (data === "timezone_coverage_unavailable")) || (data === "invalid_column_semantics"))){
validate493.errors = [{}];
return false;
}
validate493.errors = vErrors;
return errors === 0;
}
validate493.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema114 = {"type":"string","enum":["admission","execution"]};

function validate495(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate495.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate495.errors = [{}];
return false;
}
if(!((data === "admission") || (data === "execution"))){
validate495.errors = [{}];
return false;
}
validate495.errors = vErrors;
return errors === 0;
}
validate495.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema115 = {"type":"string","enum":["none","pages","segments","result_bytes"]};

function validate497(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate497.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate497.errors = [{}];
return false;
}
if(!((((data === "none") || (data === "pages")) || (data === "segments")) || (data === "result_bytes"))){
validate497.errors = [{}];
return false;
}
validate497.errors = vErrors;
return errors === 0;
}
validate497.evaluated = {"dynamicProps":false,"dynamicItems":false};


function validate492(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate492.evaluated;
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
validate492.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((((key0 === "code") || (key0 === "stage")) || (key0 === "dimension")) || (key0 === "limit")) || (key0 === "observed"))){
validate492.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.code !== undefined){
const _errs2 = errors;
if(!(validate493(data.code, {instancePath:instancePath+"/code",parentData:data,parentDataProperty:"code",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate493.errors : vErrors.concat(validate493.errors);
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
if(!(validate495(data.stage, {instancePath:instancePath+"/stage",parentData:data,parentDataProperty:"stage",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate495.errors : vErrors.concat(validate495.errors);
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
if(!(validate497(data.dimension, {instancePath:instancePath+"/dimension",parentData:data,parentDataProperty:"dimension",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate497.errors : vErrors.concat(validate497.errors);
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
if(func3(data3) > 256){
validate492.errors = [{}];
return false;
}
}
else {
validate492.errors = [{}];
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
if(func3(data4) > 256){
validate492.errors = [{}];
return false;
}
}
else {
validate492.errors = [{}];
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
validate492.errors = [{}];
return false;
}
}
validate492.errors = vErrors;
return errors === 0;
}
validate492.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate491(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate491.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate492(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate492.errors : vErrors.concat(validate492.errors);
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
validate491.errors = vErrors;
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
validate491.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate491.evaluated = {"dynamicProps":true,"dynamicItems":false};

const schema116 = {"type":"string","enum":["uploading","sealed","admitted","complete","cancelled","denied","rejected","retired","prepared"]};

function validate503(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate503.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate503.errors = [{}];
return false;
}
if(!(((((((((data === "uploading") || (data === "sealed")) || (data === "admitted")) || (data === "complete")) || (data === "cancelled")) || (data === "denied")) || (data === "rejected")) || (data === "retired")) || (data === "prepared"))){
validate503.errors = [{}];
return false;
}
validate503.errors = vErrors;
return errors === 0;
}
validate503.evaluated = {"dynamicProps":false,"dynamicItems":false};


function validate422(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate422.evaluated;
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
validate422.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((((((((key0 === "version") || (key0 === "realm")) || (key0 === "position")) || (key0 === "resource")) || (key0 === "page")) || (key0 === "exchanges")) || (key0 === "documents")) || (key0 === "queries"))){
validate422.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.version !== undefined){
const _errs2 = errors;
if(!(validate134(data.version, {instancePath:instancePath+"/version",parentData:data,parentDataProperty:"version",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate134.errors : vErrors.concat(validate134.errors);
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
if(!(validate56(data.realm, {instancePath:instancePath+"/realm",parentData:data,parentDataProperty:"realm",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
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
if(!(validate56(data.position, {instancePath:instancePath+"/position",parentData:data,parentDataProperty:"position",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
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
if(!(validate306(data.resource, {instancePath:instancePath+"/resource",parentData:data,parentDataProperty:"resource",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate306.errors : vErrors.concat(validate306.errors);
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
validate422.errors = [{}];
return false;
}
else {
const _errs8 = errors;
for(const key1 in data4){
if(!((key1 === "entries") || (key1 === "next"))){
validate422.errors = [{}];
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
validate422.errors = [{}];
return false;
}
else {
if(data5.length < 8){
validate422.errors = [{}];
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
const _errs15 = errors;
for(const key2 in data6){
if(!((key2 === "key") || (key2 === "revision"))){
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
if(_errs15 === errors){
if(data6.key !== undefined){
const _errs16 = errors;
if(!(validate232(data6.key, {instancePath:instancePath+"/page/entries/" + i0+"/key",parentData:data6,parentDataProperty:"key",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate232.errors : vErrors.concat(validate232.errors);
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
if(!(validate56(data6.revision, {instancePath:instancePath+"/page/entries/" + i0+"/revision",parentData:data6,parentDataProperty:"revision",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
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
const err2 = {};
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
const err3 = {};
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
const err4 = {};
if(vErrors === null){
vErrors = [err4];
}
else {
vErrors.push(err4);
}
errors++;
validate422.errors = vErrors;
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
validate422.errors = [{}];
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
if(!(validate231(data4.next, {instancePath:instancePath+"/page/next",parentData:data4,parentDataProperty:"next",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate231.errors : vErrors.concat(validate231.errors);
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
validate422.errors = [{}];
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
validate422.errors = [{}];
return false;
}
else {
if(data10.length < 8){
validate422.errors = [{}];
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
const err5 = {};
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
const err6 = {};
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
if(!(validate134(data11.version, {instancePath:instancePath+"/exchanges/" + i1+"/version",parentData:data11,parentDataProperty:"version",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate134.errors : vErrors.concat(validate134.errors);
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
if(!(validate331(data11.source, {instancePath:instancePath+"/exchanges/" + i1+"/source",parentData:data11,parentDataProperty:"source",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate331.errors : vErrors.concat(validate331.errors);
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
const err7 = {};
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
const err8 = {};
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
if(!(validate432(data14.failure, {instancePath:instancePath+"/exchanges/" + i1+"/declaration/failure",parentData:data14,parentDataProperty:"failure",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate432.errors : vErrors.concat(validate432.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err9 = {};
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
for(const key5 in data14){
if(!(key5 === "capture")){
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
if(data14.capture !== undefined){
let data16 = data14.capture;
const _errs39 = errors;
if(errors === _errs39){
if(data16 && typeof data16 == "object" && !Array.isArray(data16)){
let missing6;
if(((((((((((((((((((((data16.exchange === undefined) && (missing6 = "exchange")) || ((data16.protocol === undefined) && (missing6 = "protocol"))) || ((data16.phase === undefined) && (missing6 = "phase"))) || ((data16.caller === undefined) && (missing6 = "caller"))) || ((data16.input === undefined) && (missing6 = "input"))) || ((data16.owner === undefined) && (missing6 = "owner"))) || ((data16.parent === undefined) && (missing6 = "parent"))) || ((data16.effect === undefined) && (missing6 = "effect"))) || ((data16.attempt === undefined) && (missing6 = "attempt"))) || ((data16.executor === undefined) && (missing6 = "executor"))) || ((data16.reconcile_before_ms === undefined) && (missing6 = "reconcile_before_ms"))) || ((data16.segments === undefined) && (missing6 = "segments"))) || ((data16.max_segments === undefined) && (missing6 = "max_segments"))) || ((data16.bytes === undefined) && (missing6 = "bytes"))) || ((data16.capture_bytes === undefined) && (missing6 = "capture_bytes"))) || ((data16.segment_bytes === undefined) && (missing6 = "segment_bytes"))) || ((data16.pending_kind === undefined) && (missing6 = "pending_kind"))) || ((data16.terminal_code === undefined) && (missing6 = "terminal_code"))) || ((data16.collected === undefined) && (missing6 = "collected"))) || ((data16.coverage === undefined) && (missing6 = "coverage"))){
const err12 = {};
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
if(!(func1.call(schema104.properties.exchanges.items.anyOf[0].properties.declaration.oneOf[1].properties.capture.properties, key6))){
const err13 = {};
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
if(func3(data17) > 256){
const err14 = {};
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
const err15 = {};
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
if(!(validate59(data16.protocol, {instancePath:instancePath+"/exchanges/" + i1+"/declaration/capture/protocol",parentData:data16,parentDataProperty:"protocol",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate59.errors : vErrors.concat(validate59.errors);
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
if(!(validate448(data16.phase, {instancePath:instancePath+"/exchanges/" + i1+"/declaration/capture/phase",parentData:data16,parentDataProperty:"phase",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate448.errors : vErrors.concat(validate448.errors);
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
if(!(validate56(data16.caller, {instancePath:instancePath+"/exchanges/" + i1+"/declaration/capture/caller",parentData:data16,parentDataProperty:"caller",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
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
if(!(validate56(data16.input, {instancePath:instancePath+"/exchanges/" + i1+"/declaration/capture/input",parentData:data16,parentDataProperty:"input",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
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
if(!(validate56(data16.owner, {instancePath:instancePath+"/exchanges/" + i1+"/declaration/capture/owner",parentData:data16,parentDataProperty:"owner",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
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
if(func3(data23) > 256){
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
var valid11 = _errs49 === errors;
}
else {
var valid11 = true;
}
if(valid11){
if(data16.effect !== undefined){
const _errs51 = errors;
if(!(validate56(data16.effect, {instancePath:instancePath+"/exchanges/" + i1+"/declaration/capture/effect",parentData:data16,parentDataProperty:"effect",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
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
if(!(validate56(data16.attempt, {instancePath:instancePath+"/exchanges/" + i1+"/declaration/capture/attempt",parentData:data16,parentDataProperty:"attempt",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
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
if(!(validate56(data16.executor, {instancePath:instancePath+"/exchanges/" + i1+"/declaration/capture/executor",parentData:data16,parentDataProperty:"executor",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
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
if(!(validate56(data16.reconcile_before_ms, {instancePath:instancePath+"/exchanges/" + i1+"/declaration/capture/reconcile_before_ms",parentData:data16,parentDataProperty:"reconcile_before_ms",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
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
if(!(validate59(data16.segments, {instancePath:instancePath+"/exchanges/" + i1+"/declaration/capture/segments",parentData:data16,parentDataProperty:"segments",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate59.errors : vErrors.concat(validate59.errors);
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
if(!(validate59(data16.max_segments, {instancePath:instancePath+"/exchanges/" + i1+"/declaration/capture/max_segments",parentData:data16,parentDataProperty:"max_segments",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate59.errors : vErrors.concat(validate59.errors);
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
if(func3(data30) > 256){
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
if(func3(data31) > 256){
const err20 = {};
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
const err21 = {};
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
if(!(validate59(data16.segment_bytes, {instancePath:instancePath+"/exchanges/" + i1+"/declaration/capture/segment_bytes",parentData:data16,parentDataProperty:"segment_bytes",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate59.errors : vErrors.concat(validate59.errors);
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
if(!(validate59(data16.pending_kind, {instancePath:instancePath+"/exchanges/" + i1+"/declaration/capture/pending_kind",parentData:data16,parentDataProperty:"pending_kind",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate59.errors : vErrors.concat(validate59.errors);
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
if(!(validate59(data16.terminal_code, {instancePath:instancePath+"/exchanges/" + i1+"/declaration/capture/terminal_code",parentData:data16,parentDataProperty:"terminal_code",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate59.errors : vErrors.concat(validate59.errors);
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
if(!(validate59(data16.collected, {instancePath:instancePath+"/exchanges/" + i1+"/declaration/capture/collected",parentData:data16,parentDataProperty:"collected",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate59.errors : vErrors.concat(validate59.errors);
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
if(!(validate133(data16.coverage, {instancePath:instancePath+"/exchanges/" + i1+"/declaration/capture/coverage",parentData:data16,parentDataProperty:"coverage",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate133.errors : vErrors.concat(validate133.errors);
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
const err22 = {};
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
const err23 = {};
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
const _errs68 = errors;
for(const key7 in data14){
if(!(key7 === "obligations")){
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
if(_errs68 === errors){
if(data14.obligations !== undefined){
let data37 = data14.obligations;
const _errs69 = errors;
if(errors === _errs69){
if(data37 && typeof data37 == "object" && !Array.isArray(data37)){
let missing8;
if((((((data37.exchange === undefined) && (missing8 = "exchange")) || ((data37.dependents === undefined) && (missing8 = "dependents"))) || ((data37.disposition === undefined) && (missing8 = "disposition"))) || ((data37.caller === undefined) && (missing8 = "caller"))) || ((data37.effect === undefined) && (missing8 = "effect"))){
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
const _errs71 = errors;
for(const key8 in data37){
if(!(((((key8 === "exchange") || (key8 === "dependents")) || (key8 === "disposition")) || (key8 === "caller")) || (key8 === "effect"))){
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
if(_errs71 === errors){
if(data37.exchange !== undefined){
let data38 = data37.exchange;
const _errs72 = errors;
if(errors === _errs72){
if(typeof data38 === "string"){
if(func3(data38) > 256){
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
else {
const err29 = {};
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
if(func3(data39) > 256){
const err30 = {};
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
const err32 = {};
if(vErrors === null){
vErrors = [err32];
}
else {
vErrors.push(err32);
}
errors++;
}
if(!(((((data40 === "no_intent") || (data40 === "pending")) || (data40 === "observed")) || (data40 === "cancelled")) || (data40 === "closed_unknown"))){
const err33 = {};
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
const err34 = {};
if(vErrors === null){
vErrors = [err34];
}
else {
vErrors.push(err34);
}
errors++;
}
if(!(((data41 === "none") || (data41 === "held")) || (data41 === "released"))){
const err35 = {};
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
if(!(validate56(data37.effect, {instancePath:instancePath+"/exchanges/" + i1+"/declaration/obligations/effect",parentData:data37,parentDataProperty:"effect",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
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
const err36 = {};
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
const err37 = {};
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
const err38 = {};
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
const err39 = {};
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
const _errs86 = errors;
for(const key10 in data43){
if(!(((((((key10 === "exchange") || (key10 === "root")) || (key10 === "parent")) || (key10 === "ordinal")) || (key10 === "reason")) || (key10 === "policy")) || (key10 === "policy_revision"))){
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
if(_errs86 === errors){
if(data43.exchange !== undefined){
let data44 = data43.exchange;
const _errs87 = errors;
if(errors === _errs87){
if(typeof data44 === "string"){
if(func3(data44) > 256){
const err42 = {};
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
const err43 = {};
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
if(func3(data45) > 256){
const err44 = {};
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
const err45 = {};
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
if(func3(data46) > 256){
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
var valid15 = _errs91 === errors;
}
else {
var valid15 = true;
}
if(valid15){
if(data43.ordinal !== undefined){
const _errs93 = errors;
if(!(validate59(data43.ordinal, {instancePath:instancePath+"/exchanges/" + i1+"/declaration/lineage/ordinal",parentData:data43,parentDataProperty:"ordinal",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate59.errors : vErrors.concat(validate59.errors);
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
const err48 = {};
if(vErrors === null){
vErrors = [err48];
}
else {
vErrors.push(err48);
}
errors++;
}
if(!((((data48 === "retry") || (data48 === "redirect")) || (data48 === "reconcile")) || (data48 === "cancel"))){
const err49 = {};
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
if(func3(data49) > 256){
const err50 = {};
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
const err51 = {};
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
if(func3(data50) > 256){
const err52 = {};
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
const _errs102 = errors;
for(const key11 in data14){
if(!(key11 === "attempts")){
const err57 = {};
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
const err58 = {};
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
const err59 = {};
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
if(func3(data52) > 256){
const err60 = {};
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
const err61 = {};
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
if(!(validate59(data51.limit, {instancePath:instancePath+"/exchanges/" + i1+"/declaration/attempts/limit",parentData:data51,parentDataProperty:"limit",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate59.errors : vErrors.concat(validate59.errors);
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
if(!(validate59(data51.used, {instancePath:instancePath+"/exchanges/" + i1+"/declaration/attempts/used",parentData:data51,parentDataProperty:"used",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate59.errors : vErrors.concat(validate59.errors);
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
if(!(validate59(data51.unsettled, {instancePath:instancePath+"/exchanges/" + i1+"/declaration/attempts/unsettled",parentData:data51,parentDataProperty:"unsettled",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate59.errors : vErrors.concat(validate59.errors);
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
const err62 = {};
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
const err63 = {};
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
const err64 = {};
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
const err65 = {};
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
const err66 = {};
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
const err67 = {};
if(vErrors === null){
vErrors = [err67];
}
else {
vErrors.push(err67);
}
errors++;
validate422.errors = vErrors;
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
validate422.errors = [{}];
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
validate422.errors = [{}];
return false;
}
else {
if(data56.length < 8){
validate422.errors = [{}];
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
const err68 = {};
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
const err69 = {};
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
if(!(validate134(data57.version, {instancePath:instancePath+"/documents/" + i2+"/version",parentData:data57,parentDataProperty:"version",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate134.errors : vErrors.concat(validate134.errors);
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
if(!(validate331(data57.source, {instancePath:instancePath+"/documents/" + i2+"/source",parentData:data57,parentDataProperty:"source",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate331.errors : vErrors.concat(validate331.errors);
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
if(!(validate477(data57.declaration, {instancePath:instancePath+"/documents/" + i2+"/declaration",parentData:data57,parentDataProperty:"declaration",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate477.errors : vErrors.concat(validate477.errors);
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
const err70 = {};
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
const err71 = {};
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
const err72 = {};
if(vErrors === null){
vErrors = [err72];
}
else {
vErrors.push(err72);
}
errors++;
validate422.errors = vErrors;
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
validate422.errors = [{}];
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
validate422.errors = [{}];
return false;
}
else {
if(data61.length < 8){
validate422.errors = [{}];
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
const err73 = {};
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
const err74 = {};
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
if(!(validate134(data62.version, {instancePath:instancePath+"/queries/" + i3+"/version",parentData:data62,parentDataProperty:"version",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate134.errors : vErrors.concat(validate134.errors);
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
if(!(validate331(data62.source, {instancePath:instancePath+"/queries/" + i3+"/source",parentData:data62,parentDataProperty:"source",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate331.errors : vErrors.concat(validate331.errors);
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
const err75 = {};
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
const err76 = {};
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
const err77 = {};
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
if(!(func1.call(schema104.properties.queries.items.anyOf[0].properties.declaration.oneOf[0].properties.execution.properties, key16))){
const err78 = {};
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
if(!(validate56(data66.result, {instancePath:instancePath+"/queries/" + i3+"/declaration/execution/result",parentData:data66,parentDataProperty:"result",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
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
if(!(validate56(data66.destination, {instancePath:instancePath+"/queries/" + i3+"/declaration/execution/destination",parentData:data66,parentDataProperty:"destination",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
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
if(!(validate56(data66.correlation, {instancePath:instancePath+"/queries/" + i3+"/declaration/execution/correlation",parentData:data66,parentDataProperty:"correlation",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid26 = _errs144 === errors;
}
else {
var valid26 = true;
}
if(valid26){
if(data66.source !== undefined){
let data70 = data66.source;
const _errs145 = errors;
const _errs146 = errors;
let valid27 = false;
let passing2 = null;
const _errs147 = errors;
if(errors === _errs147){
if(data70 && typeof data70 == "object" && !Array.isArray(data70)){
let missing17;
if((data70.native === undefined) && (missing17 = "native")){
const err79 = {};
if(vErrors === null){
vErrors = [err79];
}
else {
vErrors.push(err79);
}
errors++;
}
else {
const _errs149 = errors;
for(const key17 in data70){
if(!(key17 === "native")){
const err80 = {};
if(vErrors === null){
vErrors = [err80];
}
else {
vErrors.push(err80);
}
errors++;
break;
}
}
if(_errs149 === errors){
if(data70.native !== undefined){
let data71 = data70.native;
const _errs150 = errors;
if(errors === _errs150){
if(data71 && typeof data71 == "object" && !Array.isArray(data71)){
let missing18;
if((((data71.pid === undefined) && (missing18 = "pid")) || ((data71.input === undefined) && (missing18 = "input"))) || ((data71.index === undefined) && (missing18 = "index"))){
const err81 = {};
if(vErrors === null){
vErrors = [err81];
}
else {
vErrors.push(err81);
}
errors++;
}
else {
const _errs152 = errors;
for(const key18 in data71){
if(!(((key18 === "pid") || (key18 === "input")) || (key18 === "index"))){
const err82 = {};
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
if(_errs152 === errors){
if(data71.pid !== undefined){
const _errs153 = errors;
if(!(validate56(data71.pid, {instancePath:instancePath+"/queries/" + i3+"/declaration/execution/source/native/pid",parentData:data71,parentDataProperty:"pid",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid29 = _errs153 === errors;
}
else {
var valid29 = true;
}
if(valid29){
if(data71.input !== undefined){
const _errs154 = errors;
if(!(validate56(data71.input, {instancePath:instancePath+"/queries/" + i3+"/declaration/execution/source/native/input",parentData:data71,parentDataProperty:"input",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid29 = _errs154 === errors;
}
else {
var valid29 = true;
}
if(valid29){
if(data71.index !== undefined){
const _errs155 = errors;
if(!(validate134(data71.index, {instancePath:instancePath+"/queries/" + i3+"/declaration/execution/source/native/index",parentData:data71,parentDataProperty:"index",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate134.errors : vErrors.concat(validate134.errors);
errors = vErrors.length;
}
var valid29 = _errs155 === errors;
}
else {
var valid29 = true;
}
}
}
}
}
}
else {
const err83 = {};
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
const err84 = {};
if(vErrors === null){
vErrors = [err84];
}
else {
vErrors.push(err84);
}
errors++;
}
}
var _valid6 = _errs147 === errors;
if(_valid6){
valid27 = true;
passing2 = 0;
var props4 = true;
}
const _errs156 = errors;
if(errors === _errs156){
if(data70 && typeof data70 == "object" && !Array.isArray(data70)){
let missing19;
if((data70.table === undefined) && (missing19 = "table")){
const err85 = {};
if(vErrors === null){
vErrors = [err85];
}
else {
vErrors.push(err85);
}
errors++;
}
else {
const _errs158 = errors;
for(const key19 in data70){
if(!(key19 === "table")){
const err86 = {};
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
if(_errs158 === errors){
if(data70.table !== undefined){
let data75 = data70.table;
const _errs159 = errors;
if(errors === _errs159){
if(data75 && typeof data75 == "object" && !Array.isArray(data75)){
let missing20;
if((data75.worker === undefined) && (missing20 = "worker")){
const err87 = {};
if(vErrors === null){
vErrors = [err87];
}
else {
vErrors.push(err87);
}
errors++;
}
else {
const _errs161 = errors;
for(const key20 in data75){
if(!(key20 === "worker")){
const err88 = {};
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
if(_errs161 === errors){
if(data75.worker !== undefined){
if(!(validate56(data75.worker, {instancePath:instancePath+"/queries/" + i3+"/declaration/execution/source/table/worker",parentData:data75,parentDataProperty:"worker",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err89 = {};
if(vErrors === null){
vErrors = [err89];
}
else {
vErrors.push(err89);
}
errors++;
}
}
}
}
}
}
else {
const err90 = {};
if(vErrors === null){
vErrors = [err90];
}
else {
vErrors.push(err90);
}
errors++;
}
}
var _valid6 = _errs156 === errors;
if(_valid6 && valid27){
valid27 = false;
passing2 = [passing2, 1];
}
else {
if(_valid6){
valid27 = true;
passing2 = 1;
if(props4 !== true){
props4 = true;
}
}
}
if(!valid27){
const err91 = {};
if(vErrors === null){
vErrors = [err91];
}
else {
vErrors.push(err91);
}
errors++;
}
else {
errors = _errs146;
if(vErrors !== null){
if(_errs146){
vErrors.length = _errs146;
}
else {
vErrors = null;
}
}
}
var valid26 = _errs145 === errors;
}
else {
var valid26 = true;
}
if(valid26){
if(data66.request_resource !== undefined){
const _errs163 = errors;
if(!(validate56(data66.request_resource, {instancePath:instancePath+"/queries/" + i3+"/declaration/execution/request_resource",parentData:data66,parentDataProperty:"request_resource",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid26 = _errs163 === errors;
}
else {
var valid26 = true;
}
if(valid26){
if(data66.request_namespace !== undefined){
let data78 = data66.request_namespace;
const _errs164 = errors;
if(errors === _errs164){
if(typeof data78 === "string"){
if(func3(data78) > 256){
const err92 = {};
if(vErrors === null){
vErrors = [err92];
}
else {
vErrors.push(err92);
}
errors++;
}
}
else {
const err93 = {};
if(vErrors === null){
vErrors = [err93];
}
else {
vErrors.push(err93);
}
errors++;
}
}
var valid26 = _errs164 === errors;
}
else {
var valid26 = true;
}
if(valid26){
if(data66.phase !== undefined){
let data79 = data66.phase;
const _errs166 = errors;
if(typeof data79 !== "string"){
const err94 = {};
if(vErrors === null){
vErrors = [err94];
}
else {
vErrors.push(err94);
}
errors++;
}
if(!(((((((((data79 === "capturing") || (data79 === "captured")) || (data79 === "complete")) || (data79 === "cancelled")) || (data79 === "denied")) || (data79 === "failed")) || (data79 === "retired")) || (data79 === "admitted")) || (data79 === "acquiring"))){
const err95 = {};
if(vErrors === null){
vErrors = [err95];
}
else {
vErrors.push(err95);
}
errors++;
}
var valid26 = _errs166 === errors;
}
else {
var valid26 = true;
}
if(valid26){
if(data66.failure !== undefined){
const _errs168 = errors;
if(!(validate491(data66.failure, {instancePath:instancePath+"/queries/" + i3+"/declaration/execution/failure",parentData:data66,parentDataProperty:"failure",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate491.errors : vErrors.concat(validate491.errors);
errors = vErrors.length;
}
var valid26 = _errs168 === errors;
}
else {
var valid26 = true;
}
if(valid26){
if(data66.policy_revision !== undefined){
const _errs169 = errors;
if(!(validate56(data66.policy_revision, {instancePath:instancePath+"/queries/" + i3+"/declaration/execution/policy_revision",parentData:data66,parentDataProperty:"policy_revision",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid26 = _errs169 === errors;
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
const err96 = {};
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
}
}
else {
const err97 = {};
if(vErrors === null){
vErrors = [err97];
}
else {
vErrors.push(err97);
}
errors++;
}
}
var _valid5 = _errs136 === errors;
if(_valid5){
valid24 = true;
passing1 = 0;
var props6 = true;
}
const _errs170 = errors;
if(errors === _errs170){
if(data65 && typeof data65 == "object" && !Array.isArray(data65)){
let missing21;
if((data65.request === undefined) && (missing21 = "request")){
const err98 = {};
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
for(const key21 in data65){
if(!(key21 === "request")){
const err99 = {};
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
if(data65.request !== undefined){
let data82 = data65.request;
const _errs173 = errors;
if(errors === _errs173){
if(data82 && typeof data82 == "object" && !Array.isArray(data82)){
let missing22;
if(((((((((data82.namespace === undefined) && (missing22 = "namespace")) || ((data82.correlation === undefined) && (missing22 = "correlation"))) || ((data82.phase === undefined) && (missing22 = "phase"))) || ((data82.failure === undefined) && (missing22 = "failure"))) || ((data82.collected === undefined) && (missing22 = "collected"))) || ((data82.result_resource === undefined) && (missing22 = "result_resource"))) || ((data82.result_namespace === undefined) && (missing22 = "result_namespace"))) || ((data82.result_digest === undefined) && (missing22 = "result_digest"))){
const err100 = {};
if(vErrors === null){
vErrors = [err100];
}
else {
vErrors.push(err100);
}
errors++;
}
else {
const _errs175 = errors;
for(const key22 in data82){
if(!((((((((key22 === "namespace") || (key22 === "correlation")) || (key22 === "phase")) || (key22 === "failure")) || (key22 === "collected")) || (key22 === "result_resource")) || (key22 === "result_namespace")) || (key22 === "result_digest"))){
const err101 = {};
if(vErrors === null){
vErrors = [err101];
}
else {
vErrors.push(err101);
}
errors++;
break;
}
}
if(_errs175 === errors){
if(data82.namespace !== undefined){
let data83 = data82.namespace;
const _errs176 = errors;
if(errors === _errs176){
if(typeof data83 === "string"){
if(func3(data83) > 256){
const err102 = {};
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
const err103 = {};
if(vErrors === null){
vErrors = [err103];
}
else {
vErrors.push(err103);
}
errors++;
}
}
var valid33 = _errs176 === errors;
}
else {
var valid33 = true;
}
if(valid33){
if(data82.correlation !== undefined){
const _errs178 = errors;
if(!(validate56(data82.correlation, {instancePath:instancePath+"/queries/" + i3+"/declaration/request/correlation",parentData:data82,parentDataProperty:"correlation",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
errors = vErrors.length;
}
var valid33 = _errs178 === errors;
}
else {
var valid33 = true;
}
if(valid33){
if(data82.phase !== undefined){
const _errs179 = errors;
if(!(validate503(data82.phase, {instancePath:instancePath+"/queries/" + i3+"/declaration/request/phase",parentData:data82,parentDataProperty:"phase",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate503.errors : vErrors.concat(validate503.errors);
errors = vErrors.length;
}
var valid33 = _errs179 === errors;
}
else {
var valid33 = true;
}
if(valid33){
if(data82.failure !== undefined){
const _errs180 = errors;
if(!(validate491(data82.failure, {instancePath:instancePath+"/queries/" + i3+"/declaration/request/failure",parentData:data82,parentDataProperty:"failure",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate491.errors : vErrors.concat(validate491.errors);
errors = vErrors.length;
}
var valid33 = _errs180 === errors;
}
else {
var valid33 = true;
}
if(valid33){
if(data82.collected !== undefined){
const _errs181 = errors;
if(typeof data82.collected !== "boolean"){
const err104 = {};
if(vErrors === null){
vErrors = [err104];
}
else {
vErrors.push(err104);
}
errors++;
}
var valid33 = _errs181 === errors;
}
else {
var valid33 = true;
}
if(valid33){
if(data82.result_resource !== undefined){
const _errs183 = errors;
if(!(validate62(data82.result_resource, {instancePath:instancePath+"/queries/" + i3+"/declaration/request/result_resource",parentData:data82,parentDataProperty:"result_resource",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate62.errors : vErrors.concat(validate62.errors);
errors = vErrors.length;
}
var valid33 = _errs183 === errors;
}
else {
var valid33 = true;
}
if(valid33){
if(data82.result_namespace !== undefined){
const _errs184 = errors;
if(!(validate446(data82.result_namespace, {instancePath:instancePath+"/queries/" + i3+"/declaration/request/result_namespace",parentData:data82,parentDataProperty:"result_namespace",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate446.errors : vErrors.concat(validate446.errors);
errors = vErrors.length;
}
var valid33 = _errs184 === errors;
}
else {
var valid33 = true;
}
if(valid33){
if(data82.result_digest !== undefined){
const _errs185 = errors;
if(!(validate214(data82.result_digest, {instancePath:instancePath+"/queries/" + i3+"/declaration/request/result_digest",parentData:data82,parentDataProperty:"result_digest",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate214.errors : vErrors.concat(validate214.errors);
errors = vErrors.length;
}
var valid33 = _errs185 === errors;
}
else {
var valid33 = true;
}
}
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
const err105 = {};
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
}
}
else {
const err106 = {};
if(vErrors === null){
vErrors = [err106];
}
else {
vErrors.push(err106);
}
errors++;
}
}
var _valid5 = _errs170 === errors;
if(_valid5 && valid24){
valid24 = false;
passing1 = [passing1, 1];
}
else {
if(_valid5){
valid24 = true;
passing1 = 1;
if(props6 !== true){
props6 = true;
}
}
}
if(!valid24){
const err107 = {};
if(vErrors === null){
vErrors = [err107];
}
else {
vErrors.push(err107);
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
const err108 = {};
if(vErrors === null){
vErrors = [err108];
}
else {
vErrors.push(err108);
}
errors++;
}
}
var _valid4 = _errs129 === errors;
valid22 = valid22 || _valid4;
const _errs186 = errors;
if(data62 !== null){
const err109 = {};
if(vErrors === null){
vErrors = [err109];
}
else {
vErrors.push(err109);
}
errors++;
}
var _valid4 = _errs186 === errors;
valid22 = valid22 || _valid4;
if(!valid22){
const err110 = {};
if(vErrors === null){
vErrors = [err110];
}
else {
vErrors.push(err110);
}
errors++;
validate422.errors = vErrors;
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
validate422.errors = [{}];
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
validate422.errors = [{}];
return false;
}
}
validate422.errors = vErrors;
return errors === 0;
}
validate422.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

export const HttpResponse = validate509;
const schema117 = {"type":"object","additionalProperties":false,"properties":{"version":{"$ref":"https://transit.invalid/generated-validator/9"},"source":{"$ref":"https://transit.invalid/generated-validator/72"},"exchange":{"type":"string","maxLength":256},"phase":{"$ref":"https://transit.invalid/generated-validator/76"},"coverage":{"$ref":"https://transit.invalid/generated-validator/11"},"failure":{"$ref":"https://transit.invalid/generated-validator/85"},"policy":{"anyOf":[{"type":"object","additionalProperties":false,"properties":{"member":{"$ref":"https://transit.invalid/generated-validator/87"},"endpoint_revision":{"type":"string","maxLength":256},"tls":{"type":"boolean"},"trust_digest":{"$ref":"https://transit.invalid/generated-validator/15"},"timeout_ms":{"$ref":"https://transit.invalid/generated-validator/0"},"request_bytes":{"type":"string","maxLength":256},"response_bytes":{"type":"string","maxLength":256},"method":{"type":"string","enum":["GET","HEAD","POST","PUT","DELETE","CONNECT","OPTIONS","TRACE","PATCH","QUERY"]},"retry":{"$ref":"https://transit.invalid/generated-validator/89"},"redirect":{"$ref":"https://transit.invalid/generated-validator/89"},"reconcile":{"$ref":"https://transit.invalid/generated-validator/89"},"cancel":{"$ref":"https://transit.invalid/generated-validator/89"}},"required":["member","endpoint_revision","tls","trust_digest","timeout_ms","request_bytes","response_bytes","method","retry","redirect","reconcile","cancel"]},{"type":"null"}]},"terminal":{"anyOf":[{"type":"object","additionalProperties":false,"properties":{"timing":{"type":"object","additionalProperties":false,"properties":{"member":{"$ref":"https://transit.invalid/generated-validator/87"},"started_ms":{"type":"string","maxLength":256},"elapsed_ns":{"type":"string","maxLength":256}},"required":["member","started_ms","elapsed_ns"]},"omission":{"type":"object","additionalProperties":false,"properties":{"member":{"$ref":"https://transit.invalid/generated-validator/87"},"response_headers":{"$ref":"https://transit.invalid/generated-validator/0"},"request_secrets":{"$ref":"https://transit.invalid/generated-validator/0"}},"required":["member","response_headers","request_secrets"]},"completion":{"type":"object","additionalProperties":false,"properties":{"member":{"$ref":"https://transit.invalid/generated-validator/87"},"status":{"$ref":"https://transit.invalid/generated-validator/4"},"request_bytes":{"type":"string","maxLength":256},"response_bytes":{"type":"string","maxLength":256},"heads":{"$ref":"https://transit.invalid/generated-validator/9"},"framing":{"type":"string","enum":["none","length","chunked","close"]}},"required":["member","status","request_bytes","response_bytes","heads","framing"]}},"required":["timing","omission","completion"]},{"type":"null"}]}},"required":["version","source","exchange","phase","coverage","failure","policy","terminal"]};
const schema118 = {"anyOf":[{"$ref":"https://transit.invalid/generated-validator/77"},{"type":"null"}]};

function validate514(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate514.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate432(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate432.errors : vErrors.concat(validate432.errors);
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
validate514.errors = vErrors;
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
validate514.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate514.evaluated = {"dynamicProps":true,"dynamicItems":false};

const schema119 = {"type":"object","additionalProperties":false,"properties":{"key":{"$ref":"https://transit.invalid/generated-validator/21"},"ordinal":{"$ref":"https://transit.invalid/generated-validator/0"},"kind":{"$ref":"https://transit.invalid/generated-validator/86"},"bytes":{"$ref":"https://transit.invalid/generated-validator/0"},"digest":{"$ref":"https://transit.invalid/generated-validator/11"},"chain":{"$ref":"https://transit.invalid/generated-validator/11"}},"required":["key","ordinal","kind","bytes","digest","chain"]};
const schema120 = {"type":"string","enum":["request_template","request_head","request_body","response_head","response_body","response_trailers","timing","omission","completion"]};

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
if(typeof data !== "string"){
validate520.errors = [{}];
return false;
}
if(!(((((((((data === "request_template") || (data === "request_head")) || (data === "request_body")) || (data === "response_head")) || (data === "response_body")) || (data === "response_trailers")) || (data === "timing")) || (data === "omission")) || (data === "completion"))){
validate520.errors = [{}];
return false;
}
validate520.errors = vErrors;
return errors === 0;
}
validate520.evaluated = {"dynamicProps":false,"dynamicItems":false};


function validate517(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate517.evaluated;
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
validate517.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((((((key0 === "key") || (key0 === "ordinal")) || (key0 === "kind")) || (key0 === "bytes")) || (key0 === "digest")) || (key0 === "chain"))){
validate517.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.key !== undefined){
const _errs2 = errors;
if(!(validate232(data.key, {instancePath:instancePath+"/key",parentData:data,parentDataProperty:"key",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate232.errors : vErrors.concat(validate232.errors);
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
if(!(validate59(data.ordinal, {instancePath:instancePath+"/ordinal",parentData:data,parentDataProperty:"ordinal",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate59.errors : vErrors.concat(validate59.errors);
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
if(!(validate520(data.kind, {instancePath:instancePath+"/kind",parentData:data,parentDataProperty:"kind",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate520.errors : vErrors.concat(validate520.errors);
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
if(!(validate59(data.bytes, {instancePath:instancePath+"/bytes",parentData:data,parentDataProperty:"bytes",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate59.errors : vErrors.concat(validate59.errors);
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
if(!(validate133(data.digest, {instancePath:instancePath+"/digest",parentData:data,parentDataProperty:"digest",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate133.errors : vErrors.concat(validate133.errors);
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
if(!(validate133(data.chain, {instancePath:instancePath+"/chain",parentData:data,parentDataProperty:"chain",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate133.errors : vErrors.concat(validate133.errors);
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
validate517.errors = [{}];
return false;
}
}
validate517.errors = vErrors;
return errors === 0;
}
validate517.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema121 = {"anyOf":[{"$ref":"https://transit.invalid/generated-validator/88"},{"type":"null"}]};
const schema122 = {"type":"object","additionalProperties":false,"properties":{"id":{"type":"string","maxLength":256},"revision":{"type":"string","maxLength":256}},"required":["id","revision"]};

function validate529(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate529.evaluated;
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
validate529.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "id") || (key0 === "revision"))){
validate529.errors = [{}];
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
if(func3(data0) > 256){
validate529.errors = [{}];
return false;
}
}
else {
validate529.errors = [{}];
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
if(func3(data1) > 256){
validate529.errors = [{}];
return false;
}
}
else {
validate529.errors = [{}];
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
validate529.errors = [{}];
return false;
}
}
validate529.errors = vErrors;
return errors === 0;
}
validate529.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate528(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate528.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate529(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate529.errors : vErrors.concat(validate529.errors);
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
validate528.errors = vErrors;
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
validate528.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate528.evaluated = {"dynamicProps":true,"dynamicItems":false};


function validate509(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate509.evaluated;
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
validate509.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((((((((key0 === "version") || (key0 === "source")) || (key0 === "exchange")) || (key0 === "phase")) || (key0 === "coverage")) || (key0 === "failure")) || (key0 === "policy")) || (key0 === "terminal"))){
validate509.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.version !== undefined){
const _errs2 = errors;
if(!(validate134(data.version, {instancePath:instancePath+"/version",parentData:data,parentDataProperty:"version",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate134.errors : vErrors.concat(validate134.errors);
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
if(!(validate331(data.source, {instancePath:instancePath+"/source",parentData:data,parentDataProperty:"source",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate331.errors : vErrors.concat(validate331.errors);
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
if(func3(data2) > 256){
validate509.errors = [{}];
return false;
}
}
else {
validate509.errors = [{}];
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
if(!(validate448(data.phase, {instancePath:instancePath+"/phase",parentData:data,parentDataProperty:"phase",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate448.errors : vErrors.concat(validate448.errors);
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
if(!(validate133(data.coverage, {instancePath:instancePath+"/coverage",parentData:data,parentDataProperty:"coverage",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate133.errors : vErrors.concat(validate133.errors);
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
if(!(validate514(data.failure, {instancePath:instancePath+"/failure",parentData:data,parentDataProperty:"failure",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate514.errors : vErrors.concat(validate514.errors);
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
const _errs13 = errors;
for(const key1 in data6){
if(!(func1.call(schema117.properties.policy.anyOf[0].properties, key1))){
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
if(_errs13 === errors){
if(data6.member !== undefined){
const _errs14 = errors;
if(!(validate517(data6.member, {instancePath:instancePath+"/policy/member",parentData:data6,parentDataProperty:"member",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate517.errors : vErrors.concat(validate517.errors);
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
if(func3(data8) > 256){
const err2 = {};
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
var valid2 = _errs15 === errors;
}
else {
var valid2 = true;
}
if(valid2){
if(data6.tls !== undefined){
const _errs17 = errors;
if(typeof data6.tls !== "boolean"){
const err4 = {};
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
if(!(validate214(data6.trust_digest, {instancePath:instancePath+"/policy/trust_digest",parentData:data6,parentDataProperty:"trust_digest",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate214.errors : vErrors.concat(validate214.errors);
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
if(!(validate59(data6.timeout_ms, {instancePath:instancePath+"/policy/timeout_ms",parentData:data6,parentDataProperty:"timeout_ms",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate59.errors : vErrors.concat(validate59.errors);
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
if(func3(data12) > 256){
const err5 = {};
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
if(func3(data13) > 256){
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
const err9 = {};
if(vErrors === null){
vErrors = [err9];
}
else {
vErrors.push(err9);
}
errors++;
}
if(!((((((((((data14 === "GET") || (data14 === "HEAD")) || (data14 === "POST")) || (data14 === "PUT")) || (data14 === "DELETE")) || (data14 === "CONNECT")) || (data14 === "OPTIONS")) || (data14 === "TRACE")) || (data14 === "PATCH")) || (data14 === "QUERY"))){
const err10 = {};
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
if(!(validate528(data6.retry, {instancePath:instancePath+"/policy/retry",parentData:data6,parentDataProperty:"retry",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate528.errors : vErrors.concat(validate528.errors);
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
if(!(validate528(data6.redirect, {instancePath:instancePath+"/policy/redirect",parentData:data6,parentDataProperty:"redirect",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate528.errors : vErrors.concat(validate528.errors);
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
if(!(validate528(data6.reconcile, {instancePath:instancePath+"/policy/reconcile",parentData:data6,parentDataProperty:"reconcile",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate528.errors : vErrors.concat(validate528.errors);
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
if(!(validate528(data6.cancel, {instancePath:instancePath+"/policy/cancel",parentData:data6,parentDataProperty:"cancel",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate528.errors : vErrors.concat(validate528.errors);
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
const err11 = {};
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
const err12 = {};
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
const err13 = {};
if(vErrors === null){
vErrors = [err13];
}
else {
vErrors.push(err13);
}
errors++;
validate509.errors = vErrors;
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
const err14 = {};
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
const err15 = {};
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
const err16 = {};
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
const err17 = {};
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
if(!(validate517(data20.member, {instancePath:instancePath+"/terminal/timing/member",parentData:data20,parentDataProperty:"member",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate517.errors : vErrors.concat(validate517.errors);
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
if(func3(data22) > 256){
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
if(func3(data23) > 256){
const err20 = {};
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
const err21 = {};
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
const err22 = {};
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
const _errs48 = errors;
for(const key4 in data24){
if(!(((key4 === "member") || (key4 === "response_headers")) || (key4 === "request_secrets"))){
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
if(_errs48 === errors){
if(data24.member !== undefined){
const _errs49 = errors;
if(!(validate517(data24.member, {instancePath:instancePath+"/terminal/omission/member",parentData:data24,parentDataProperty:"member",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate517.errors : vErrors.concat(validate517.errors);
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
if(!(validate59(data24.response_headers, {instancePath:instancePath+"/terminal/omission/response_headers",parentData:data24,parentDataProperty:"response_headers",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate59.errors : vErrors.concat(validate59.errors);
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
if(!(validate59(data24.request_secrets, {instancePath:instancePath+"/terminal/omission/request_secrets",parentData:data24,parentDataProperty:"request_secrets",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate59.errors : vErrors.concat(validate59.errors);
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
const _errs54 = errors;
for(const key5 in data28){
if(!((((((key5 === "member") || (key5 === "status")) || (key5 === "request_bytes")) || (key5 === "response_bytes")) || (key5 === "heads")) || (key5 === "framing"))){
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
if(_errs54 === errors){
if(data28.member !== undefined){
const _errs55 = errors;
if(!(validate517(data28.member, {instancePath:instancePath+"/terminal/completion/member",parentData:data28,parentDataProperty:"member",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate517.errors : vErrors.concat(validate517.errors);
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
if(!(validate168(data28.status, {instancePath:instancePath+"/terminal/completion/status",parentData:data28,parentDataProperty:"status",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate168.errors : vErrors.concat(validate168.errors);
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
if(func3(data31) > 256){
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
else {
const err29 = {};
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
if(func3(data32) > 256){
const err30 = {};
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
var valid7 = _errs59 === errors;
}
else {
var valid7 = true;
}
if(valid7){
if(data28.heads !== undefined){
const _errs61 = errors;
if(!(validate134(data28.heads, {instancePath:instancePath+"/terminal/completion/heads",parentData:data28,parentDataProperty:"heads",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate134.errors : vErrors.concat(validate134.errors);
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
const err32 = {};
if(vErrors === null){
vErrors = [err32];
}
else {
vErrors.push(err32);
}
errors++;
}
if(!((((data34 === "none") || (data34 === "length")) || (data34 === "chunked")) || (data34 === "close"))){
const err33 = {};
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
var _valid1 = _errs35 === errors;
valid3 = valid3 || _valid1;
const _errs64 = errors;
if(data19 !== null){
const err36 = {};
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
const err37 = {};
if(vErrors === null){
vErrors = [err37];
}
else {
vErrors.push(err37);
}
errors++;
validate509.errors = vErrors;
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
validate509.errors = [{}];
return false;
}
}
validate509.errors = vErrors;
return errors === 0;
}
validate509.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

export const GrpcResponse = validate542;
const schema123 = {"type":"object","additionalProperties":false,"properties":{"version":{"$ref":"https://transit.invalid/generated-validator/9"},"source":{"$ref":"https://transit.invalid/generated-validator/72"},"exchange":{"type":"string","maxLength":256},"phase":{"$ref":"https://transit.invalid/generated-validator/76"},"coverage":{"$ref":"https://transit.invalid/generated-validator/11"},"failure":{"$ref":"https://transit.invalid/generated-validator/85"},"policy":{"anyOf":[{"type":"object","additionalProperties":false,"properties":{"member":{"$ref":"https://transit.invalid/generated-validator/91"},"endpoint_revision":{"type":"string","maxLength":256},"tls":{"type":"boolean"},"trust_digest":{"$ref":"https://transit.invalid/generated-validator/15"},"timeout_ms":{"$ref":"https://transit.invalid/generated-validator/0"},"limits":{"type":"object","additionalProperties":false,"properties":{"message_bytes":{"$ref":"https://transit.invalid/generated-validator/0"},"request_bytes":{"$ref":"https://transit.invalid/generated-validator/0"},"response_bytes":{"$ref":"https://transit.invalid/generated-validator/0"},"request_messages":{"$ref":"https://transit.invalid/generated-validator/0"},"response_messages":{"$ref":"https://transit.invalid/generated-validator/0"},"metadata_bytes":{"$ref":"https://transit.invalid/generated-validator/0"}},"required":["message_bytes","request_bytes","response_bytes","request_messages","response_messages","metadata_bytes"]},"shape":{"type":"string","enum":["unary","server_streaming","client_streaming","bidi"]},"descriptor_digest":{"$ref":"https://transit.invalid/generated-validator/11"},"retry":{"$ref":"https://transit.invalid/generated-validator/89"}},"required":["member","endpoint_revision","tls","trust_digest","timeout_ms","limits","shape","descriptor_digest","retry"]},{"type":"null"}]},"half_close":{"anyOf":[{"type":"object","additionalProperties":false,"properties":{"member":{"$ref":"https://transit.invalid/generated-validator/91"},"messages":{"$ref":"https://transit.invalid/generated-validator/0"},"wire_bytes":{"$ref":"https://transit.invalid/generated-validator/0"}},"required":["member","messages","wire_bytes"]},{"type":"null"}]},"response_message_records":{"$ref":"https://transit.invalid/generated-validator/0"},"response_body_bytes":{"type":"string","maxLength":256},"terminal":{"anyOf":[{"type":"object","additionalProperties":false,"properties":{"timing":{"type":"object","additionalProperties":false,"properties":{"member":{"$ref":"https://transit.invalid/generated-validator/91"},"started_ms":{"type":"string","maxLength":256},"elapsed_ns":{"type":"string","maxLength":256}},"required":["member","started_ms","elapsed_ns"]},"omission":{"type":"object","additionalProperties":false,"properties":{"member":{"$ref":"https://transit.invalid/generated-validator/91"},"response_fields":{"$ref":"https://transit.invalid/generated-validator/0"},"request_secrets":{"$ref":"https://transit.invalid/generated-validator/0"}},"required":["member","response_fields","request_secrets"]},"completion":{"type":"object","additionalProperties":false,"properties":{"member":{"$ref":"https://transit.invalid/generated-validator/91"},"status":{"$ref":"https://transit.invalid/generated-validator/0"},"sent_messages":{"$ref":"https://transit.invalid/generated-validator/0"},"received_messages":{"$ref":"https://transit.invalid/generated-validator/0"},"sent_bytes":{"$ref":"https://transit.invalid/generated-validator/0"},"received_bytes":{"$ref":"https://transit.invalid/generated-validator/0"},"half_closed":{"type":"boolean"}},"required":["member","status","sent_messages","received_messages","sent_bytes","received_bytes","half_closed"]}},"required":["timing","omission","completion"]},{"type":"null"}]}},"required":["version","source","exchange","phase","coverage","failure","policy","half_close","response_message_records","response_body_bytes","terminal"]};
const schema124 = {"type":"object","additionalProperties":false,"properties":{"key":{"$ref":"https://transit.invalid/generated-validator/21"},"ordinal":{"$ref":"https://transit.invalid/generated-validator/0"},"kind":{"$ref":"https://transit.invalid/generated-validator/90"},"bytes":{"$ref":"https://transit.invalid/generated-validator/0"},"digest":{"$ref":"https://transit.invalid/generated-validator/11"},"chain":{"$ref":"https://transit.invalid/generated-validator/11"}},"required":["key","ordinal","kind","bytes","digest","chain"]};
const schema125 = {"type":"string","enum":["request_metadata","request_batch","endpoint_policy","initial_metadata","response_message","response_body","half_close","trailers","timing","omission","completion"]};

function validate551(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate551.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate551.errors = [{}];
return false;
}
if(!(((((((((((data === "request_metadata") || (data === "request_batch")) || (data === "endpoint_policy")) || (data === "initial_metadata")) || (data === "response_message")) || (data === "response_body")) || (data === "half_close")) || (data === "trailers")) || (data === "timing")) || (data === "omission")) || (data === "completion"))){
validate551.errors = [{}];
return false;
}
validate551.errors = vErrors;
return errors === 0;
}
validate551.evaluated = {"dynamicProps":false,"dynamicItems":false};


function validate548(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate548.evaluated;
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
validate548.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((((((key0 === "key") || (key0 === "ordinal")) || (key0 === "kind")) || (key0 === "bytes")) || (key0 === "digest")) || (key0 === "chain"))){
validate548.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.key !== undefined){
const _errs2 = errors;
if(!(validate232(data.key, {instancePath:instancePath+"/key",parentData:data,parentDataProperty:"key",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate232.errors : vErrors.concat(validate232.errors);
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
if(!(validate59(data.ordinal, {instancePath:instancePath+"/ordinal",parentData:data,parentDataProperty:"ordinal",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate59.errors : vErrors.concat(validate59.errors);
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
if(!(validate551(data.kind, {instancePath:instancePath+"/kind",parentData:data,parentDataProperty:"kind",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate551.errors : vErrors.concat(validate551.errors);
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
if(!(validate59(data.bytes, {instancePath:instancePath+"/bytes",parentData:data,parentDataProperty:"bytes",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate59.errors : vErrors.concat(validate59.errors);
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
if(!(validate133(data.digest, {instancePath:instancePath+"/digest",parentData:data,parentDataProperty:"digest",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate133.errors : vErrors.concat(validate133.errors);
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
if(!(validate133(data.chain, {instancePath:instancePath+"/chain",parentData:data,parentDataProperty:"chain",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate133.errors : vErrors.concat(validate133.errors);
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
validate548.errors = [{}];
return false;
}
}
validate548.errors = vErrors;
return errors === 0;
}
validate548.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


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
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((((((((((((data.version === undefined) && (missing0 = "version")) || ((data.source === undefined) && (missing0 = "source"))) || ((data.exchange === undefined) && (missing0 = "exchange"))) || ((data.phase === undefined) && (missing0 = "phase"))) || ((data.coverage === undefined) && (missing0 = "coverage"))) || ((data.failure === undefined) && (missing0 = "failure"))) || ((data.policy === undefined) && (missing0 = "policy"))) || ((data.half_close === undefined) && (missing0 = "half_close"))) || ((data.response_message_records === undefined) && (missing0 = "response_message_records"))) || ((data.response_body_bytes === undefined) && (missing0 = "response_body_bytes"))) || ((data.terminal === undefined) && (missing0 = "terminal"))){
validate542.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(func1.call(schema123.properties, key0))){
validate542.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.version !== undefined){
const _errs2 = errors;
if(!(validate134(data.version, {instancePath:instancePath+"/version",parentData:data,parentDataProperty:"version",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate134.errors : vErrors.concat(validate134.errors);
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
if(!(validate331(data.source, {instancePath:instancePath+"/source",parentData:data,parentDataProperty:"source",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate331.errors : vErrors.concat(validate331.errors);
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
if(func3(data2) > 256){
validate542.errors = [{}];
return false;
}
}
else {
validate542.errors = [{}];
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
if(!(validate448(data.phase, {instancePath:instancePath+"/phase",parentData:data,parentDataProperty:"phase",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate448.errors : vErrors.concat(validate448.errors);
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
if(!(validate133(data.coverage, {instancePath:instancePath+"/coverage",parentData:data,parentDataProperty:"coverage",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate133.errors : vErrors.concat(validate133.errors);
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
if(!(validate514(data.failure, {instancePath:instancePath+"/failure",parentData:data,parentDataProperty:"failure",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate514.errors : vErrors.concat(validate514.errors);
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
const _errs13 = errors;
for(const key1 in data6){
if(!(func1.call(schema123.properties.policy.anyOf[0].properties, key1))){
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
if(_errs13 === errors){
if(data6.member !== undefined){
const _errs14 = errors;
if(!(validate548(data6.member, {instancePath:instancePath+"/policy/member",parentData:data6,parentDataProperty:"member",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate548.errors : vErrors.concat(validate548.errors);
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
if(func3(data8) > 256){
const err2 = {};
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
var valid2 = _errs15 === errors;
}
else {
var valid2 = true;
}
if(valid2){
if(data6.tls !== undefined){
const _errs17 = errors;
if(typeof data6.tls !== "boolean"){
const err4 = {};
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
if(!(validate214(data6.trust_digest, {instancePath:instancePath+"/policy/trust_digest",parentData:data6,parentDataProperty:"trust_digest",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate214.errors : vErrors.concat(validate214.errors);
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
if(!(validate59(data6.timeout_ms, {instancePath:instancePath+"/policy/timeout_ms",parentData:data6,parentDataProperty:"timeout_ms",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate59.errors : vErrors.concat(validate59.errors);
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
const err5 = {};
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
const err6 = {};
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
if(!(validate59(data12.message_bytes, {instancePath:instancePath+"/policy/limits/message_bytes",parentData:data12,parentDataProperty:"message_bytes",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate59.errors : vErrors.concat(validate59.errors);
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
if(!(validate59(data12.request_bytes, {instancePath:instancePath+"/policy/limits/request_bytes",parentData:data12,parentDataProperty:"request_bytes",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate59.errors : vErrors.concat(validate59.errors);
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
if(!(validate59(data12.response_bytes, {instancePath:instancePath+"/policy/limits/response_bytes",parentData:data12,parentDataProperty:"response_bytes",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate59.errors : vErrors.concat(validate59.errors);
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
if(!(validate59(data12.request_messages, {instancePath:instancePath+"/policy/limits/request_messages",parentData:data12,parentDataProperty:"request_messages",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate59.errors : vErrors.concat(validate59.errors);
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
if(!(validate59(data12.response_messages, {instancePath:instancePath+"/policy/limits/response_messages",parentData:data12,parentDataProperty:"response_messages",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate59.errors : vErrors.concat(validate59.errors);
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
if(!(validate59(data12.metadata_bytes, {instancePath:instancePath+"/policy/limits/metadata_bytes",parentData:data12,parentDataProperty:"metadata_bytes",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate59.errors : vErrors.concat(validate59.errors);
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
const err8 = {};
if(vErrors === null){
vErrors = [err8];
}
else {
vErrors.push(err8);
}
errors++;
}
if(!((((data19 === "unary") || (data19 === "server_streaming")) || (data19 === "client_streaming")) || (data19 === "bidi"))){
const err9 = {};
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
if(!(validate133(data6.descriptor_digest, {instancePath:instancePath+"/policy/descriptor_digest",parentData:data6,parentDataProperty:"descriptor_digest",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate133.errors : vErrors.concat(validate133.errors);
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
if(!(validate528(data6.retry, {instancePath:instancePath+"/policy/retry",parentData:data6,parentDataProperty:"retry",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate528.errors : vErrors.concat(validate528.errors);
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
const err10 = {};
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
const err11 = {};
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
const err12 = {};
if(vErrors === null){
vErrors = [err12];
}
else {
vErrors.push(err12);
}
errors++;
validate542.errors = vErrors;
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
const _errs40 = errors;
for(const key3 in data22){
if(!(((key3 === "member") || (key3 === "messages")) || (key3 === "wire_bytes"))){
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
if(_errs40 === errors){
if(data22.member !== undefined){
const _errs41 = errors;
if(!(validate548(data22.member, {instancePath:instancePath+"/half_close/member",parentData:data22,parentDataProperty:"member",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate548.errors : vErrors.concat(validate548.errors);
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
if(!(validate59(data22.messages, {instancePath:instancePath+"/half_close/messages",parentData:data22,parentDataProperty:"messages",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate59.errors : vErrors.concat(validate59.errors);
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
if(!(validate59(data22.wire_bytes, {instancePath:instancePath+"/half_close/wire_bytes",parentData:data22,parentDataProperty:"wire_bytes",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate59.errors : vErrors.concat(validate59.errors);
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
const err15 = {};
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
const err16 = {};
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
const err17 = {};
if(vErrors === null){
vErrors = [err17];
}
else {
vErrors.push(err17);
}
errors++;
validate542.errors = vErrors;
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
if(!(validate59(data.response_message_records, {instancePath:instancePath+"/response_message_records",parentData:data,parentDataProperty:"response_message_records",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate59.errors : vErrors.concat(validate59.errors);
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
if(func3(data27) > 256){
validate542.errors = [{}];
return false;
}
}
else {
validate542.errors = [{}];
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
const _errs53 = errors;
for(const key4 in data28){
if(!(((key4 === "timing") || (key4 === "omission")) || (key4 === "completion"))){
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
if(_errs53 === errors){
if(data28.timing !== undefined){
let data29 = data28.timing;
const _errs54 = errors;
if(errors === _errs54){
if(data29 && typeof data29 == "object" && !Array.isArray(data29)){
let missing5;
if((((data29.member === undefined) && (missing5 = "member")) || ((data29.started_ms === undefined) && (missing5 = "started_ms"))) || ((data29.elapsed_ns === undefined) && (missing5 = "elapsed_ns"))){
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
const _errs56 = errors;
for(const key5 in data29){
if(!(((key5 === "member") || (key5 === "started_ms")) || (key5 === "elapsed_ns"))){
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
if(_errs56 === errors){
if(data29.member !== undefined){
const _errs57 = errors;
if(!(validate548(data29.member, {instancePath:instancePath+"/terminal/timing/member",parentData:data29,parentDataProperty:"member",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate548.errors : vErrors.concat(validate548.errors);
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
if(func3(data31) > 256){
const err22 = {};
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
const err23 = {};
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
if(func3(data32) > 256){
const err24 = {};
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
const err27 = {};
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
const err28 = {};
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
if(!(validate548(data33.member, {instancePath:instancePath+"/terminal/omission/member",parentData:data33,parentDataProperty:"member",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate548.errors : vErrors.concat(validate548.errors);
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
if(!(validate59(data33.response_fields, {instancePath:instancePath+"/terminal/omission/response_fields",parentData:data33,parentDataProperty:"response_fields",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate59.errors : vErrors.concat(validate59.errors);
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
if(!(validate59(data33.request_secrets, {instancePath:instancePath+"/terminal/omission/request_secrets",parentData:data33,parentDataProperty:"request_secrets",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate59.errors : vErrors.concat(validate59.errors);
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
const err29 = {};
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
const _errs70 = errors;
for(const key7 in data37){
if(!(((((((key7 === "member") || (key7 === "status")) || (key7 === "sent_messages")) || (key7 === "received_messages")) || (key7 === "sent_bytes")) || (key7 === "received_bytes")) || (key7 === "half_closed"))){
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
if(_errs70 === errors){
if(data37.member !== undefined){
const _errs71 = errors;
if(!(validate548(data37.member, {instancePath:instancePath+"/terminal/completion/member",parentData:data37,parentDataProperty:"member",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate548.errors : vErrors.concat(validate548.errors);
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
if(!(validate59(data37.status, {instancePath:instancePath+"/terminal/completion/status",parentData:data37,parentDataProperty:"status",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate59.errors : vErrors.concat(validate59.errors);
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
if(!(validate59(data37.sent_messages, {instancePath:instancePath+"/terminal/completion/sent_messages",parentData:data37,parentDataProperty:"sent_messages",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate59.errors : vErrors.concat(validate59.errors);
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
if(!(validate59(data37.received_messages, {instancePath:instancePath+"/terminal/completion/received_messages",parentData:data37,parentDataProperty:"received_messages",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate59.errors : vErrors.concat(validate59.errors);
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
if(!(validate59(data37.sent_bytes, {instancePath:instancePath+"/terminal/completion/sent_bytes",parentData:data37,parentDataProperty:"sent_bytes",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate59.errors : vErrors.concat(validate59.errors);
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
if(!(validate59(data37.received_bytes, {instancePath:instancePath+"/terminal/completion/received_bytes",parentData:data37,parentDataProperty:"received_bytes",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate59.errors : vErrors.concat(validate59.errors);
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
const err32 = {};
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
var _valid2 = _errs51 === errors;
valid6 = valid6 || _valid2;
const _errs79 = errors;
if(data28 !== null){
const err35 = {};
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
const err36 = {};
if(vErrors === null){
vErrors = [err36];
}
else {
vErrors.push(err36);
}
errors++;
validate542.errors = vErrors;
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
validate542.errors = [{}];
return false;
}
}
validate542.errors = vErrors;
return errors === 0;
}
validate542.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

export const DocumentResponse = validate581;
const schema126 = {"type":"object","additionalProperties":false,"properties":{"version":{"$ref":"https://transit.invalid/generated-validator/9"},"source":{"$ref":"https://transit.invalid/generated-validator/72"},"declaration":{"$ref":"https://transit.invalid/generated-validator/78"},"registers":{"anyOf":[{"type":"object","additionalProperties":false,"properties":{"count":{"$ref":"https://transit.invalid/generated-validator/9"},"conflicts":{"$ref":"https://transit.invalid/generated-validator/9"},"assignments":{"$ref":"https://transit.invalid/generated-validator/9"},"next":{"$ref":"https://transit.invalid/generated-validator/75"}},"required":["count","conflicts","assignments","next"]},{"type":"null"}]}},"required":["version","source","declaration","registers"]};

function validate581(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate581.evaluated;
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
validate581.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((((key0 === "version") || (key0 === "source")) || (key0 === "declaration")) || (key0 === "registers"))){
validate581.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.version !== undefined){
const _errs2 = errors;
if(!(validate134(data.version, {instancePath:instancePath+"/version",parentData:data,parentDataProperty:"version",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate134.errors : vErrors.concat(validate134.errors);
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
if(!(validate331(data.source, {instancePath:instancePath+"/source",parentData:data,parentDataProperty:"source",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate331.errors : vErrors.concat(validate331.errors);
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
if(!(validate477(data.declaration, {instancePath:instancePath+"/declaration",parentData:data,parentDataProperty:"declaration",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate477.errors : vErrors.concat(validate477.errors);
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
const _errs9 = errors;
for(const key1 in data3){
if(!((((key1 === "count") || (key1 === "conflicts")) || (key1 === "assignments")) || (key1 === "next"))){
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
if(_errs9 === errors){
if(data3.count !== undefined){
const _errs10 = errors;
if(!(validate134(data3.count, {instancePath:instancePath+"/registers/count",parentData:data3,parentDataProperty:"count",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate134.errors : vErrors.concat(validate134.errors);
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
if(!(validate134(data3.conflicts, {instancePath:instancePath+"/registers/conflicts",parentData:data3,parentDataProperty:"conflicts",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate134.errors : vErrors.concat(validate134.errors);
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
if(!(validate134(data3.assignments, {instancePath:instancePath+"/registers/assignments",parentData:data3,parentDataProperty:"assignments",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate134.errors : vErrors.concat(validate134.errors);
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
if(!(validate446(data3.next, {instancePath:instancePath+"/registers/next",parentData:data3,parentDataProperty:"next",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate446.errors : vErrors.concat(validate446.errors);
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
const err2 = {};
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
const err3 = {};
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
const err4 = {};
if(vErrors === null){
vErrors = [err4];
}
else {
vErrors.push(err4);
}
errors++;
validate581.errors = vErrors;
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
validate581.errors = [{}];
return false;
}
}
validate581.errors = vErrors;
return errors === 0;
}
validate581.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};
