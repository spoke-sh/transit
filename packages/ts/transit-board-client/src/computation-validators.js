// Generated; no runtime code generation or eval.
import lengthModule from "ajv/dist/runtime/ucs2length.js";
const ucs2length = lengthModule.default ?? lengthModule;
"use strict";
export const ComputationRequest = validate3326;
const schema908 = {"type":"object","additionalProperties":false,"properties":{"definition":{"$ref":"#/$defs/ComputationRequest/$defs/T1"},"namespace":{"$ref":"#/$defs/ComputationRequest/$defs/T2"},"name":{"$ref":"#/$defs/ComputationRequest/$defs/T3"},"expected":{"$ref":"#/$defs/ComputationRequest/$defs/T4"},"revision":{"$ref":"#/$defs/ComputationRequest/$defs/T8"}},"required":["definition","namespace","name","expected","revision"]};
const schema21 = {"type":"string","enum":["6da8e815dec26c458515e34fb6553654d57c77536f652b9258897bf1a513842e"]};

function validate3327(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3327.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate3327.errors = [{}];
return false;
}
if(!(data === "6da8e815dec26c458515e34fb6553654d57c77536f652b9258897bf1a513842e")){
validate3327.errors = [{}];
return false;
}
validate3327.errors = vErrors;
return errors === 0;
}
validate3327.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema22 = {"type":"integer","minimum":0,"maximum":9007199254740991};

function validate3329(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3329.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(!(((typeof data == "number") && (!(data % 1) && !isNaN(data))) && (isFinite(data)))){
validate3329.errors = [{}];
return false;
}
if(errors === 0){
if((typeof data == "number") && (isFinite(data))){
if(data > 9007199254740991 || isNaN(data)){
validate3329.errors = [{}];
return false;
}
else {
if(data < 0 || isNaN(data)){
validate3329.errors = [{}];
return false;
}
}
}
}
validate3329.errors = vErrors;
return errors === 0;
}
validate3329.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema911 = {"type":"string","maxLength":262144};
const func3 = ucs2length;

function validate3331(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3331.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(typeof data === "string"){
if(func3(data) > 262144){
validate3331.errors = [{}];
return false;
}
}
else {
validate3331.errors = [{}];
return false;
}
}
validate3331.errors = vErrors;
return errors === 0;
}
validate3331.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema912 = {"anyOf":[{"$ref":"#/$defs/ComputationRequest/$defs/T5"},{"type":"null"}]};
const schema913 = {"type":"object","additionalProperties":false,"properties":{"object":{"$ref":"#/$defs/ComputationRequest/$defs/T6"},"revision":{"$ref":"#/$defs/ComputationRequest/$defs/T3"},"digest":{"$ref":"#/$defs/ComputationRequest/$defs/T3"}},"required":["object","revision","digest"]};
const schema914 = {"type":"object","additionalProperties":false,"properties":{"scope":{"$ref":"#/$defs/ComputationRequest/$defs/T7"},"branch":{"$ref":"#/$defs/ComputationRequest/$defs/T3"},"object":{"$ref":"#/$defs/ComputationRequest/$defs/T3"}},"required":["scope","branch","object"]};
const schema915 = {"type":"object","additionalProperties":false,"properties":{"realm":{"$ref":"#/$defs/ComputationRequest/$defs/T2"},"resource":{"$ref":"#/$defs/ComputationRequest/$defs/T2"},"catalog":{"$ref":"#/$defs/ComputationRequest/$defs/T3"}},"required":["realm","resource","catalog"]};

function validate3336(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3336.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((((data.realm === undefined) && (missing0 = "realm")) || ((data.resource === undefined) && (missing0 = "resource"))) || ((data.catalog === undefined) && (missing0 = "catalog"))){
validate3336.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "realm") || (key0 === "resource")) || (key0 === "catalog"))){
validate3336.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.realm !== undefined){
const _errs2 = errors;
if(!(validate3329(data.realm, {instancePath:instancePath+"/realm",parentData:data,parentDataProperty:"realm",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3329.errors : vErrors.concat(validate3329.errors);
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
if(!(validate3329(data.resource, {instancePath:instancePath+"/resource",parentData:data,parentDataProperty:"resource",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3329.errors : vErrors.concat(validate3329.errors);
errors = vErrors.length;
}
var valid0 = _errs3 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.catalog !== undefined){
const _errs4 = errors;
if(!(validate3331(data.catalog, {instancePath:instancePath+"/catalog",parentData:data,parentDataProperty:"catalog",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3331.errors : vErrors.concat(validate3331.errors);
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
validate3336.errors = [{}];
return false;
}
}
validate3336.errors = vErrors;
return errors === 0;
}
validate3336.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate3335(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3335.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((((data.scope === undefined) && (missing0 = "scope")) || ((data.branch === undefined) && (missing0 = "branch"))) || ((data.object === undefined) && (missing0 = "object"))){
validate3335.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "scope") || (key0 === "branch")) || (key0 === "object"))){
validate3335.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.scope !== undefined){
const _errs2 = errors;
if(!(validate3336(data.scope, {instancePath:instancePath+"/scope",parentData:data,parentDataProperty:"scope",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3336.errors : vErrors.concat(validate3336.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.branch !== undefined){
const _errs3 = errors;
if(!(validate3331(data.branch, {instancePath:instancePath+"/branch",parentData:data,parentDataProperty:"branch",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3331.errors : vErrors.concat(validate3331.errors);
errors = vErrors.length;
}
var valid0 = _errs3 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.object !== undefined){
const _errs4 = errors;
if(!(validate3331(data.object, {instancePath:instancePath+"/object",parentData:data,parentDataProperty:"object",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3331.errors : vErrors.concat(validate3331.errors);
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
validate3335.errors = [{}];
return false;
}
}
validate3335.errors = vErrors;
return errors === 0;
}
validate3335.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate3334(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3334.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((((data.object === undefined) && (missing0 = "object")) || ((data.revision === undefined) && (missing0 = "revision"))) || ((data.digest === undefined) && (missing0 = "digest"))){
validate3334.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "object") || (key0 === "revision")) || (key0 === "digest"))){
validate3334.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.object !== undefined){
const _errs2 = errors;
if(!(validate3335(data.object, {instancePath:instancePath+"/object",parentData:data,parentDataProperty:"object",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3335.errors : vErrors.concat(validate3335.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.revision !== undefined){
const _errs3 = errors;
if(!(validate3331(data.revision, {instancePath:instancePath+"/revision",parentData:data,parentDataProperty:"revision",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3331.errors : vErrors.concat(validate3331.errors);
errors = vErrors.length;
}
var valid0 = _errs3 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.digest !== undefined){
const _errs4 = errors;
if(!(validate3331(data.digest, {instancePath:instancePath+"/digest",parentData:data,parentDataProperty:"digest",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3331.errors : vErrors.concat(validate3331.errors);
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
validate3334.errors = [{}];
return false;
}
}
validate3334.errors = vErrors;
return errors === 0;
}
validate3334.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate3333(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3333.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate3334(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3334.errors : vErrors.concat(validate3334.errors);
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
validate3333.errors = vErrors;
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
validate3333.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate3333.evaluated = {"dynamicProps":true,"dynamicItems":false};

const schema916 = {"anyOf":[{"$ref":"#/$defs/ComputationRequest/$defs/T3"},{"type":"null"}]};

function validate3348(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3348.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate3331(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3331.errors : vErrors.concat(validate3331.errors);
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
validate3348.errors = vErrors;
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
validate3348.errors = vErrors;
return errors === 0;
}
validate3348.evaluated = {"dynamicProps":false,"dynamicItems":false};


function validate3326(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3326.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((((((data.definition === undefined) && (missing0 = "definition")) || ((data.namespace === undefined) && (missing0 = "namespace"))) || ((data.name === undefined) && (missing0 = "name"))) || ((data.expected === undefined) && (missing0 = "expected"))) || ((data.revision === undefined) && (missing0 = "revision"))){
validate3326.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((((key0 === "definition") || (key0 === "namespace")) || (key0 === "name")) || (key0 === "expected")) || (key0 === "revision"))){
validate3326.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.definition !== undefined){
const _errs2 = errors;
if(!(validate3327(data.definition, {instancePath:instancePath+"/definition",parentData:data,parentDataProperty:"definition",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3327.errors : vErrors.concat(validate3327.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.namespace !== undefined){
const _errs3 = errors;
if(!(validate3329(data.namespace, {instancePath:instancePath+"/namespace",parentData:data,parentDataProperty:"namespace",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3329.errors : vErrors.concat(validate3329.errors);
errors = vErrors.length;
}
var valid0 = _errs3 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.name !== undefined){
const _errs4 = errors;
if(!(validate3331(data.name, {instancePath:instancePath+"/name",parentData:data,parentDataProperty:"name",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3331.errors : vErrors.concat(validate3331.errors);
errors = vErrors.length;
}
var valid0 = _errs4 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.expected !== undefined){
const _errs5 = errors;
if(!(validate3333(data.expected, {instancePath:instancePath+"/expected",parentData:data,parentDataProperty:"expected",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3333.errors : vErrors.concat(validate3333.errors);
errors = vErrors.length;
}
var valid0 = _errs5 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.revision !== undefined){
const _errs6 = errors;
if(!(validate3348(data.revision, {instancePath:instancePath+"/revision",parentData:data,parentDataProperty:"revision",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3348.errors : vErrors.concat(validate3348.errors);
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
validate3326.errors = [{}];
return false;
}
}
validate3326.errors = vErrors;
return errors === 0;
}
validate3326.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

export const ComputationResponse = validate3351;
const schema917 = {"type":"object","additionalProperties":false,"properties":{"definition":{"$ref":"#/$defs/ComputationResponse/$defs/T1"},"binding":{"$ref":"#/$defs/ComputationResponse/$defs/T2"},"source":{"$ref":"#/$defs/ComputationResponse/$defs/T2"},"output":{"$ref":"#/$defs/ComputationResponse/$defs/T2"},"sql":{"$ref":"#/$defs/ComputationResponse/$defs/T4"},"current":{"$ref":"#/$defs/ComputationResponse/$defs/T8"},"completed":{"$ref":"#/$defs/ComputationResponse/$defs/T16"}},"required":["definition","binding","source","output","sql","current","completed"]};

function validate3352(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3352.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate3352.errors = [{}];
return false;
}
if(!(data === "6da8e815dec26c458515e34fb6553654d57c77536f652b9258897bf1a513842e")){
validate3352.errors = [{}];
return false;
}
validate3352.errors = vErrors;
return errors === 0;
}
validate3352.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema919 = {"type":"object","additionalProperties":false,"properties":{"namespace":{"$ref":"#/$defs/ComputationResponse/$defs/T3"},"name":{"$ref":"#/$defs/ComputationResponse/$defs/T4"},"interpretation":{"$ref":"#/$defs/ComputationResponse/$defs/T5"}},"required":["namespace","name","interpretation"]};

function validate3355(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3355.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(!(((typeof data == "number") && (!(data % 1) && !isNaN(data))) && (isFinite(data)))){
validate3355.errors = [{}];
return false;
}
if(errors === 0){
if((typeof data == "number") && (isFinite(data))){
if(data > 9007199254740991 || isNaN(data)){
validate3355.errors = [{}];
return false;
}
else {
if(data < 0 || isNaN(data)){
validate3355.errors = [{}];
return false;
}
}
}
}
validate3355.errors = vErrors;
return errors === 0;
}
validate3355.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema921 = {"type":"string","maxLength":262144};

function validate3357(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3357.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(typeof data === "string"){
if(func3(data) > 262144){
validate3357.errors = [{}];
return false;
}
}
else {
validate3357.errors = [{}];
return false;
}
}
validate3357.errors = vErrors;
return errors === 0;
}
validate3357.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema922 = {"type":"object","additionalProperties":false,"properties":{"object":{"$ref":"#/$defs/ComputationResponse/$defs/T6"},"revision":{"$ref":"#/$defs/ComputationResponse/$defs/T4"},"digest":{"$ref":"#/$defs/ComputationResponse/$defs/T4"}},"required":["object","revision","digest"]};
const schema923 = {"type":"object","additionalProperties":false,"properties":{"scope":{"$ref":"#/$defs/ComputationResponse/$defs/T7"},"branch":{"$ref":"#/$defs/ComputationResponse/$defs/T4"},"object":{"$ref":"#/$defs/ComputationResponse/$defs/T4"}},"required":["scope","branch","object"]};
const schema924 = {"type":"object","additionalProperties":false,"properties":{"realm":{"$ref":"#/$defs/ComputationResponse/$defs/T3"},"resource":{"$ref":"#/$defs/ComputationResponse/$defs/T3"},"catalog":{"$ref":"#/$defs/ComputationResponse/$defs/T4"}},"required":["realm","resource","catalog"]};

function validate3361(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3361.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((((data.realm === undefined) && (missing0 = "realm")) || ((data.resource === undefined) && (missing0 = "resource"))) || ((data.catalog === undefined) && (missing0 = "catalog"))){
validate3361.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "realm") || (key0 === "resource")) || (key0 === "catalog"))){
validate3361.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.realm !== undefined){
const _errs2 = errors;
if(!(validate3355(data.realm, {instancePath:instancePath+"/realm",parentData:data,parentDataProperty:"realm",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3355.errors : vErrors.concat(validate3355.errors);
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
if(!(validate3355(data.resource, {instancePath:instancePath+"/resource",parentData:data,parentDataProperty:"resource",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3355.errors : vErrors.concat(validate3355.errors);
errors = vErrors.length;
}
var valid0 = _errs3 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.catalog !== undefined){
const _errs4 = errors;
if(!(validate3357(data.catalog, {instancePath:instancePath+"/catalog",parentData:data,parentDataProperty:"catalog",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3357.errors : vErrors.concat(validate3357.errors);
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
validate3361.errors = [{}];
return false;
}
}
validate3361.errors = vErrors;
return errors === 0;
}
validate3361.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate3360(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3360.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((((data.scope === undefined) && (missing0 = "scope")) || ((data.branch === undefined) && (missing0 = "branch"))) || ((data.object === undefined) && (missing0 = "object"))){
validate3360.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "scope") || (key0 === "branch")) || (key0 === "object"))){
validate3360.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.scope !== undefined){
const _errs2 = errors;
if(!(validate3361(data.scope, {instancePath:instancePath+"/scope",parentData:data,parentDataProperty:"scope",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3361.errors : vErrors.concat(validate3361.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.branch !== undefined){
const _errs3 = errors;
if(!(validate3357(data.branch, {instancePath:instancePath+"/branch",parentData:data,parentDataProperty:"branch",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3357.errors : vErrors.concat(validate3357.errors);
errors = vErrors.length;
}
var valid0 = _errs3 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.object !== undefined){
const _errs4 = errors;
if(!(validate3357(data.object, {instancePath:instancePath+"/object",parentData:data,parentDataProperty:"object",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3357.errors : vErrors.concat(validate3357.errors);
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
validate3360.errors = [{}];
return false;
}
}
validate3360.errors = vErrors;
return errors === 0;
}
validate3360.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate3359(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3359.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((((data.object === undefined) && (missing0 = "object")) || ((data.revision === undefined) && (missing0 = "revision"))) || ((data.digest === undefined) && (missing0 = "digest"))){
validate3359.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "object") || (key0 === "revision")) || (key0 === "digest"))){
validate3359.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.object !== undefined){
const _errs2 = errors;
if(!(validate3360(data.object, {instancePath:instancePath+"/object",parentData:data,parentDataProperty:"object",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3360.errors : vErrors.concat(validate3360.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.revision !== undefined){
const _errs3 = errors;
if(!(validate3357(data.revision, {instancePath:instancePath+"/revision",parentData:data,parentDataProperty:"revision",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3357.errors : vErrors.concat(validate3357.errors);
errors = vErrors.length;
}
var valid0 = _errs3 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.digest !== undefined){
const _errs4 = errors;
if(!(validate3357(data.digest, {instancePath:instancePath+"/digest",parentData:data,parentDataProperty:"digest",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3357.errors : vErrors.concat(validate3357.errors);
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
validate3359.errors = [{}];
return false;
}
}
validate3359.errors = vErrors;
return errors === 0;
}
validate3359.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate3354(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3354.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((((data.namespace === undefined) && (missing0 = "namespace")) || ((data.name === undefined) && (missing0 = "name"))) || ((data.interpretation === undefined) && (missing0 = "interpretation"))){
validate3354.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "namespace") || (key0 === "name")) || (key0 === "interpretation"))){
validate3354.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.namespace !== undefined){
const _errs2 = errors;
if(!(validate3355(data.namespace, {instancePath:instancePath+"/namespace",parentData:data,parentDataProperty:"namespace",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3355.errors : vErrors.concat(validate3355.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.name !== undefined){
const _errs3 = errors;
if(!(validate3357(data.name, {instancePath:instancePath+"/name",parentData:data,parentDataProperty:"name",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3357.errors : vErrors.concat(validate3357.errors);
errors = vErrors.length;
}
var valid0 = _errs3 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.interpretation !== undefined){
const _errs4 = errors;
if(!(validate3359(data.interpretation, {instancePath:instancePath+"/interpretation",parentData:data,parentDataProperty:"interpretation",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3359.errors : vErrors.concat(validate3359.errors);
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
validate3354.errors = [{}];
return false;
}
}
validate3354.errors = vErrors;
return errors === 0;
}
validate3354.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema925 = {"anyOf":[{"$ref":"#/$defs/ComputationResponse/$defs/T9"},{"type":"null"}]};
const schema926 = {"type":"object","additionalProperties":false,"properties":{"state":{"$ref":"#/$defs/ComputationResponse/$defs/T10"},"epoch":{"$ref":"#/$defs/ComputationResponse/$defs/T4"},"refresh":{"$ref":"#/$defs/ComputationResponse/$defs/T4"},"attempt":{"$ref":"#/$defs/ComputationResponse/$defs/T4"},"pending":{"$ref":"#/$defs/ComputationResponse/$defs/T11"},"blocked":{"$ref":"#/$defs/ComputationResponse/$defs/T13"},"retirement_complete":{"$ref":"#/$defs/ComputationResponse/$defs/T14"},"storage":{"$ref":"#/$defs/ComputationResponse/$defs/T5"},"position":{"$ref":"#/$defs/ComputationResponse/$defs/T15"}},"required":["state","epoch","refresh","attempt","pending","blocked","retirement_complete","storage","position"]};
const func1 = Object.prototype.hasOwnProperty;
const schema927 = {"type":"string","enum":["published","authorized","active","suspended","retired"]};

function validate3378(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3378.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate3378.errors = [{}];
return false;
}
if(!(((((data === "published") || (data === "authorized")) || (data === "active")) || (data === "suspended")) || (data === "retired"))){
validate3378.errors = [{}];
return false;
}
validate3378.errors = vErrors;
return errors === 0;
}
validate3378.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema928 = {"anyOf":[{"$ref":"#/$defs/ComputationResponse/$defs/T12"},{"type":"null"}]};
const schema929 = {"type":"object","additionalProperties":false,"properties":{"account":{"$ref":"#/$defs/ComputationResponse/$defs/T4"},"token":{"$ref":"#/$defs/ComputationResponse/$defs/T4"}},"required":["account","token"]};

function validate3384(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3384.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if(((data.account === undefined) && (missing0 = "account")) || ((data.token === undefined) && (missing0 = "token"))){
validate3384.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "account") || (key0 === "token"))){
validate3384.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.account !== undefined){
const _errs2 = errors;
if(!(validate3357(data.account, {instancePath:instancePath+"/account",parentData:data,parentDataProperty:"account",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3357.errors : vErrors.concat(validate3357.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.token !== undefined){
const _errs3 = errors;
if(!(validate3357(data.token, {instancePath:instancePath+"/token",parentData:data,parentDataProperty:"token",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3357.errors : vErrors.concat(validate3357.errors);
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
validate3384.errors = [{}];
return false;
}
}
validate3384.errors = vErrors;
return errors === 0;
}
validate3384.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate3383(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3383.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate3384(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3384.errors : vErrors.concat(validate3384.errors);
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
validate3383.errors = vErrors;
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
validate3383.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate3383.evaluated = {"dynamicProps":true,"dynamicItems":false};

const schema930 = {"type":"string","enum":["none","authorization","source_changed","history_expired","storage_unavailable","budget","execution_failed","lease_fenced","unresolved_transaction"]};

function validate3389(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3389.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate3389.errors = [{}];
return false;
}
if(!(((((((((data === "none") || (data === "authorization")) || (data === "source_changed")) || (data === "history_expired")) || (data === "storage_unavailable")) || (data === "budget")) || (data === "execution_failed")) || (data === "lease_fenced")) || (data === "unresolved_transaction"))){
validate3389.errors = [{}];
return false;
}
validate3389.errors = vErrors;
return errors === 0;
}
validate3389.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema931 = {"type":"boolean"};

function validate3391(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3391.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "boolean"){
validate3391.errors = [{}];
return false;
}
validate3391.errors = vErrors;
return errors === 0;
}
validate3391.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema932 = {"type":"object","additionalProperties":false,"properties":{"partition":{"$ref":"#/$defs/ComputationResponse/$defs/T4"},"next_lsn":{"$ref":"#/$defs/ComputationResponse/$defs/T4"}},"required":["partition","next_lsn"]};

function validate3394(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3394.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if(((data.partition === undefined) && (missing0 = "partition")) || ((data.next_lsn === undefined) && (missing0 = "next_lsn"))){
validate3394.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "partition") || (key0 === "next_lsn"))){
validate3394.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.partition !== undefined){
const _errs2 = errors;
if(!(validate3357(data.partition, {instancePath:instancePath+"/partition",parentData:data,parentDataProperty:"partition",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3357.errors : vErrors.concat(validate3357.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.next_lsn !== undefined){
const _errs3 = errors;
if(!(validate3357(data.next_lsn, {instancePath:instancePath+"/next_lsn",parentData:data,parentDataProperty:"next_lsn",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3357.errors : vErrors.concat(validate3357.errors);
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
validate3394.errors = [{}];
return false;
}
}
validate3394.errors = vErrors;
return errors === 0;
}
validate3394.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate3377(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3377.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((((((((((data.state === undefined) && (missing0 = "state")) || ((data.epoch === undefined) && (missing0 = "epoch"))) || ((data.refresh === undefined) && (missing0 = "refresh"))) || ((data.attempt === undefined) && (missing0 = "attempt"))) || ((data.pending === undefined) && (missing0 = "pending"))) || ((data.blocked === undefined) && (missing0 = "blocked"))) || ((data.retirement_complete === undefined) && (missing0 = "retirement_complete"))) || ((data.storage === undefined) && (missing0 = "storage"))) || ((data.position === undefined) && (missing0 = "position"))){
validate3377.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(func1.call(schema926.properties, key0))){
validate3377.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.state !== undefined){
const _errs2 = errors;
if(!(validate3378(data.state, {instancePath:instancePath+"/state",parentData:data,parentDataProperty:"state",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3378.errors : vErrors.concat(validate3378.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.epoch !== undefined){
const _errs3 = errors;
if(!(validate3357(data.epoch, {instancePath:instancePath+"/epoch",parentData:data,parentDataProperty:"epoch",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3357.errors : vErrors.concat(validate3357.errors);
errors = vErrors.length;
}
var valid0 = _errs3 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.refresh !== undefined){
const _errs4 = errors;
if(!(validate3357(data.refresh, {instancePath:instancePath+"/refresh",parentData:data,parentDataProperty:"refresh",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3357.errors : vErrors.concat(validate3357.errors);
errors = vErrors.length;
}
var valid0 = _errs4 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.attempt !== undefined){
const _errs5 = errors;
if(!(validate3357(data.attempt, {instancePath:instancePath+"/attempt",parentData:data,parentDataProperty:"attempt",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3357.errors : vErrors.concat(validate3357.errors);
errors = vErrors.length;
}
var valid0 = _errs5 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.pending !== undefined){
const _errs6 = errors;
if(!(validate3383(data.pending, {instancePath:instancePath+"/pending",parentData:data,parentDataProperty:"pending",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3383.errors : vErrors.concat(validate3383.errors);
errors = vErrors.length;
}
var valid0 = _errs6 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.blocked !== undefined){
const _errs7 = errors;
if(!(validate3389(data.blocked, {instancePath:instancePath+"/blocked",parentData:data,parentDataProperty:"blocked",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3389.errors : vErrors.concat(validate3389.errors);
errors = vErrors.length;
}
var valid0 = _errs7 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.retirement_complete !== undefined){
const _errs8 = errors;
if(!(validate3391(data.retirement_complete, {instancePath:instancePath+"/retirement_complete",parentData:data,parentDataProperty:"retirement_complete",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3391.errors : vErrors.concat(validate3391.errors);
errors = vErrors.length;
}
var valid0 = _errs8 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.storage !== undefined){
const _errs9 = errors;
if(!(validate3359(data.storage, {instancePath:instancePath+"/storage",parentData:data,parentDataProperty:"storage",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3359.errors : vErrors.concat(validate3359.errors);
errors = vErrors.length;
}
var valid0 = _errs9 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.position !== undefined){
const _errs10 = errors;
if(!(validate3394(data.position, {instancePath:instancePath+"/position",parentData:data,parentDataProperty:"position",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3394.errors : vErrors.concat(validate3394.errors);
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
}
else {
validate3377.errors = [{}];
return false;
}
}
validate3377.errors = vErrors;
return errors === 0;
}
validate3377.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate3376(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3376.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate3377(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3377.errors : vErrors.concat(validate3377.errors);
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
validate3376.errors = vErrors;
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
validate3376.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate3376.evaluated = {"dynamicProps":true,"dynamicItems":false};

const schema933 = {"anyOf":[{"$ref":"#/$defs/ComputationResponse/$defs/T17"},{"type":"null"}]};
const schema934 = {"type":"object","additionalProperties":false,"properties":{"revision":{"$ref":"#/$defs/ComputationResponse/$defs/T4"},"rows":{"$ref":"#/$defs/ComputationResponse/$defs/T4"},"source":{"$ref":"#/$defs/ComputationResponse/$defs/T5"},"output":{"$ref":"#/$defs/ComputationResponse/$defs/T5"},"source_position":{"$ref":"#/$defs/ComputationResponse/$defs/T15"},"schema":{"$ref":"#/$defs/ComputationResponse/$defs/T18"},"manifest":{"$ref":"#/$defs/ComputationResponse/$defs/T18"},"decision":{"$ref":"#/$defs/ComputationResponse/$defs/T19"}},"required":["revision","rows","source","output","source_position","schema","manifest","decision"]};
const schema935 = {"type":"object","additionalProperties":false,"properties":{"bytes":{"$ref":"#/$defs/ComputationResponse/$defs/T4"},"sha256":{"$ref":"#/$defs/ComputationResponse/$defs/T4"}},"required":["bytes","sha256"]};

function validate3407(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3407.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if(((data.bytes === undefined) && (missing0 = "bytes")) || ((data.sha256 === undefined) && (missing0 = "sha256"))){
validate3407.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "bytes") || (key0 === "sha256"))){
validate3407.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.bytes !== undefined){
const _errs2 = errors;
if(!(validate3357(data.bytes, {instancePath:instancePath+"/bytes",parentData:data,parentDataProperty:"bytes",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3357.errors : vErrors.concat(validate3357.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.sha256 !== undefined){
const _errs3 = errors;
if(!(validate3357(data.sha256, {instancePath:instancePath+"/sha256",parentData:data,parentDataProperty:"sha256",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3357.errors : vErrors.concat(validate3357.errors);
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
validate3407.errors = [{}];
return false;
}
}
validate3407.errors = vErrors;
return errors === 0;
}
validate3407.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema936 = {"type":"object","additionalProperties":false,"properties":{"attempt":{"$ref":"#/$defs/ComputationResponse/$defs/T20"},"outcome":{"$ref":"#/$defs/ComputationResponse/$defs/T24"},"prepared":{"$ref":"#/$defs/ComputationResponse/$defs/T23"},"position":{"$ref":"#/$defs/ComputationResponse/$defs/T15"},"coordinator_epoch":{"$ref":"#/$defs/ComputationResponse/$defs/T4"},"policy_epoch":{"$ref":"#/$defs/ComputationResponse/$defs/T4"}},"required":["attempt","outcome","prepared","position","coordinator_epoch","policy_epoch"]};
const schema937 = {"type":"object","additionalProperties":false,"properties":{"definition":{"$ref":"#/$defs/ComputationResponse/$defs/T1"},"transaction":{"$ref":"#/$defs/ComputationResponse/$defs/T21"},"operation":{"$ref":"#/$defs/ComputationResponse/$defs/T22"},"cut":{"$ref":"#/$defs/ComputationResponse/$defs/T18"},"workspace":{"$ref":"#/$defs/ComputationResponse/$defs/T18"},"participants":{"$ref":"#/$defs/ComputationResponse/$defs/T23"},"writes":{"$ref":"#/$defs/ComputationResponse/$defs/T4"},"last_statement":{"$ref":"#/$defs/ComputationResponse/$defs/T4"}},"required":["definition","transaction","operation","cut","workspace","participants","writes","last_statement"]};
const schema938 = {"type":"object","additionalProperties":false,"properties":{"begin":{"$ref":"#/$defs/ComputationResponse/$defs/T22"},"branch":{"$ref":"#/$defs/ComputationResponse/$defs/T4"}},"required":["begin","branch"]};
const schema939 = {"type":"object","additionalProperties":false,"properties":{"scope":{"$ref":"#/$defs/ComputationResponse/$defs/T7"},"principal":{"$ref":"#/$defs/ComputationResponse/$defs/T3"},"operation":{"$ref":"#/$defs/ComputationResponse/$defs/T4"}},"required":["scope","principal","operation"]};

function validate3416(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3416.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((((data.scope === undefined) && (missing0 = "scope")) || ((data.principal === undefined) && (missing0 = "principal"))) || ((data.operation === undefined) && (missing0 = "operation"))){
validate3416.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "scope") || (key0 === "principal")) || (key0 === "operation"))){
validate3416.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.scope !== undefined){
const _errs2 = errors;
if(!(validate3361(data.scope, {instancePath:instancePath+"/scope",parentData:data,parentDataProperty:"scope",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3361.errors : vErrors.concat(validate3361.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.principal !== undefined){
const _errs3 = errors;
if(!(validate3355(data.principal, {instancePath:instancePath+"/principal",parentData:data,parentDataProperty:"principal",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3355.errors : vErrors.concat(validate3355.errors);
errors = vErrors.length;
}
var valid0 = _errs3 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.operation !== undefined){
const _errs4 = errors;
if(!(validate3357(data.operation, {instancePath:instancePath+"/operation",parentData:data,parentDataProperty:"operation",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3357.errors : vErrors.concat(validate3357.errors);
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
validate3416.errors = [{}];
return false;
}
}
validate3416.errors = vErrors;
return errors === 0;
}
validate3416.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate3415(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3415.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if(((data.begin === undefined) && (missing0 = "begin")) || ((data.branch === undefined) && (missing0 = "branch"))){
validate3415.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "begin") || (key0 === "branch"))){
validate3415.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.begin !== undefined){
const _errs2 = errors;
if(!(validate3416(data.begin, {instancePath:instancePath+"/begin",parentData:data,parentDataProperty:"begin",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3416.errors : vErrors.concat(validate3416.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.branch !== undefined){
const _errs3 = errors;
if(!(validate3357(data.branch, {instancePath:instancePath+"/branch",parentData:data,parentDataProperty:"branch",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3357.errors : vErrors.concat(validate3357.errors);
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
validate3415.errors = [{}];
return false;
}
}
validate3415.errors = vErrors;
return errors === 0;
}
validate3415.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema940 = {"type":"object","additionalProperties":false,"properties":{"content":{"$ref":"#/$defs/ComputationResponse/$defs/T18"},"count":{"$ref":"#/$defs/ComputationResponse/$defs/T4"}},"required":["content","count"]};

function validate3426(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3426.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if(((data.content === undefined) && (missing0 = "content")) || ((data.count === undefined) && (missing0 = "count"))){
validate3426.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "content") || (key0 === "count"))){
validate3426.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.content !== undefined){
const _errs2 = errors;
if(!(validate3407(data.content, {instancePath:instancePath+"/content",parentData:data,parentDataProperty:"content",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3407.errors : vErrors.concat(validate3407.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.count !== undefined){
const _errs3 = errors;
if(!(validate3357(data.count, {instancePath:instancePath+"/count",parentData:data,parentDataProperty:"count",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3357.errors : vErrors.concat(validate3357.errors);
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
validate3426.errors = [{}];
return false;
}
}
validate3426.errors = vErrors;
return errors === 0;
}
validate3426.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate3413(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3413.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if(((((((((data.definition === undefined) && (missing0 = "definition")) || ((data.transaction === undefined) && (missing0 = "transaction"))) || ((data.operation === undefined) && (missing0 = "operation"))) || ((data.cut === undefined) && (missing0 = "cut"))) || ((data.workspace === undefined) && (missing0 = "workspace"))) || ((data.participants === undefined) && (missing0 = "participants"))) || ((data.writes === undefined) && (missing0 = "writes"))) || ((data.last_statement === undefined) && (missing0 = "last_statement"))){
validate3413.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((((((((key0 === "definition") || (key0 === "transaction")) || (key0 === "operation")) || (key0 === "cut")) || (key0 === "workspace")) || (key0 === "participants")) || (key0 === "writes")) || (key0 === "last_statement"))){
validate3413.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.definition !== undefined){
const _errs2 = errors;
if(!(validate3352(data.definition, {instancePath:instancePath+"/definition",parentData:data,parentDataProperty:"definition",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3352.errors : vErrors.concat(validate3352.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.transaction !== undefined){
const _errs3 = errors;
if(!(validate3415(data.transaction, {instancePath:instancePath+"/transaction",parentData:data,parentDataProperty:"transaction",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3415.errors : vErrors.concat(validate3415.errors);
errors = vErrors.length;
}
var valid0 = _errs3 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.operation !== undefined){
const _errs4 = errors;
if(!(validate3416(data.operation, {instancePath:instancePath+"/operation",parentData:data,parentDataProperty:"operation",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3416.errors : vErrors.concat(validate3416.errors);
errors = vErrors.length;
}
var valid0 = _errs4 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.cut !== undefined){
const _errs5 = errors;
if(!(validate3407(data.cut, {instancePath:instancePath+"/cut",parentData:data,parentDataProperty:"cut",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3407.errors : vErrors.concat(validate3407.errors);
errors = vErrors.length;
}
var valid0 = _errs5 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.workspace !== undefined){
const _errs6 = errors;
if(!(validate3407(data.workspace, {instancePath:instancePath+"/workspace",parentData:data,parentDataProperty:"workspace",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3407.errors : vErrors.concat(validate3407.errors);
errors = vErrors.length;
}
var valid0 = _errs6 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.participants !== undefined){
const _errs7 = errors;
if(!(validate3426(data.participants, {instancePath:instancePath+"/participants",parentData:data,parentDataProperty:"participants",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3426.errors : vErrors.concat(validate3426.errors);
errors = vErrors.length;
}
var valid0 = _errs7 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.writes !== undefined){
const _errs8 = errors;
if(!(validate3357(data.writes, {instancePath:instancePath+"/writes",parentData:data,parentDataProperty:"writes",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3357.errors : vErrors.concat(validate3357.errors);
errors = vErrors.length;
}
var valid0 = _errs8 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.last_statement !== undefined){
const _errs9 = errors;
if(!(validate3357(data.last_statement, {instancePath:instancePath+"/last_statement",parentData:data,parentDataProperty:"last_statement",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3357.errors : vErrors.concat(validate3357.errors);
errors = vErrors.length;
}
var valid0 = _errs9 === errors;
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
validate3413.errors = [{}];
return false;
}
}
validate3413.errors = vErrors;
return errors === 0;
}
validate3413.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema941 = {"type":"string","enum":["committed","aborted"]};

function validate3433(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3433.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate3433.errors = [{}];
return false;
}
if(!((data === "committed") || (data === "aborted"))){
validate3433.errors = [{}];
return false;
}
validate3433.errors = vErrors;
return errors === 0;
}
validate3433.evaluated = {"dynamicProps":false,"dynamicItems":false};


function validate3412(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3412.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if(((((((data.attempt === undefined) && (missing0 = "attempt")) || ((data.outcome === undefined) && (missing0 = "outcome"))) || ((data.prepared === undefined) && (missing0 = "prepared"))) || ((data.position === undefined) && (missing0 = "position"))) || ((data.coordinator_epoch === undefined) && (missing0 = "coordinator_epoch"))) || ((data.policy_epoch === undefined) && (missing0 = "policy_epoch"))){
validate3412.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((((((key0 === "attempt") || (key0 === "outcome")) || (key0 === "prepared")) || (key0 === "position")) || (key0 === "coordinator_epoch")) || (key0 === "policy_epoch"))){
validate3412.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.attempt !== undefined){
const _errs2 = errors;
if(!(validate3413(data.attempt, {instancePath:instancePath+"/attempt",parentData:data,parentDataProperty:"attempt",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3413.errors : vErrors.concat(validate3413.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.outcome !== undefined){
const _errs3 = errors;
if(!(validate3433(data.outcome, {instancePath:instancePath+"/outcome",parentData:data,parentDataProperty:"outcome",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3433.errors : vErrors.concat(validate3433.errors);
errors = vErrors.length;
}
var valid0 = _errs3 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.prepared !== undefined){
const _errs4 = errors;
if(!(validate3426(data.prepared, {instancePath:instancePath+"/prepared",parentData:data,parentDataProperty:"prepared",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3426.errors : vErrors.concat(validate3426.errors);
errors = vErrors.length;
}
var valid0 = _errs4 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.position !== undefined){
const _errs5 = errors;
if(!(validate3394(data.position, {instancePath:instancePath+"/position",parentData:data,parentDataProperty:"position",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3394.errors : vErrors.concat(validate3394.errors);
errors = vErrors.length;
}
var valid0 = _errs5 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.coordinator_epoch !== undefined){
const _errs6 = errors;
if(!(validate3357(data.coordinator_epoch, {instancePath:instancePath+"/coordinator_epoch",parentData:data,parentDataProperty:"coordinator_epoch",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3357.errors : vErrors.concat(validate3357.errors);
errors = vErrors.length;
}
var valid0 = _errs6 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.policy_epoch !== undefined){
const _errs7 = errors;
if(!(validate3357(data.policy_epoch, {instancePath:instancePath+"/policy_epoch",parentData:data,parentDataProperty:"policy_epoch",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3357.errors : vErrors.concat(validate3357.errors);
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
validate3412.errors = [{}];
return false;
}
}
validate3412.errors = vErrors;
return errors === 0;
}
validate3412.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate3401(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3401.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if(((((((((data.revision === undefined) && (missing0 = "revision")) || ((data.rows === undefined) && (missing0 = "rows"))) || ((data.source === undefined) && (missing0 = "source"))) || ((data.output === undefined) && (missing0 = "output"))) || ((data.source_position === undefined) && (missing0 = "source_position"))) || ((data.schema === undefined) && (missing0 = "schema"))) || ((data.manifest === undefined) && (missing0 = "manifest"))) || ((data.decision === undefined) && (missing0 = "decision"))){
validate3401.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((((((((key0 === "revision") || (key0 === "rows")) || (key0 === "source")) || (key0 === "output")) || (key0 === "source_position")) || (key0 === "schema")) || (key0 === "manifest")) || (key0 === "decision"))){
validate3401.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.revision !== undefined){
const _errs2 = errors;
if(!(validate3357(data.revision, {instancePath:instancePath+"/revision",parentData:data,parentDataProperty:"revision",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3357.errors : vErrors.concat(validate3357.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.rows !== undefined){
const _errs3 = errors;
if(!(validate3357(data.rows, {instancePath:instancePath+"/rows",parentData:data,parentDataProperty:"rows",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3357.errors : vErrors.concat(validate3357.errors);
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
if(!(validate3359(data.source, {instancePath:instancePath+"/source",parentData:data,parentDataProperty:"source",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3359.errors : vErrors.concat(validate3359.errors);
errors = vErrors.length;
}
var valid0 = _errs4 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.output !== undefined){
const _errs5 = errors;
if(!(validate3359(data.output, {instancePath:instancePath+"/output",parentData:data,parentDataProperty:"output",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3359.errors : vErrors.concat(validate3359.errors);
errors = vErrors.length;
}
var valid0 = _errs5 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.source_position !== undefined){
const _errs6 = errors;
if(!(validate3394(data.source_position, {instancePath:instancePath+"/source_position",parentData:data,parentDataProperty:"source_position",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3394.errors : vErrors.concat(validate3394.errors);
errors = vErrors.length;
}
var valid0 = _errs6 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.schema !== undefined){
const _errs7 = errors;
if(!(validate3407(data.schema, {instancePath:instancePath+"/schema",parentData:data,parentDataProperty:"schema",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3407.errors : vErrors.concat(validate3407.errors);
errors = vErrors.length;
}
var valid0 = _errs7 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.manifest !== undefined){
const _errs8 = errors;
if(!(validate3407(data.manifest, {instancePath:instancePath+"/manifest",parentData:data,parentDataProperty:"manifest",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3407.errors : vErrors.concat(validate3407.errors);
errors = vErrors.length;
}
var valid0 = _errs8 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.decision !== undefined){
const _errs9 = errors;
if(!(validate3412(data.decision, {instancePath:instancePath+"/decision",parentData:data,parentDataProperty:"decision",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3412.errors : vErrors.concat(validate3412.errors);
errors = vErrors.length;
}
var valid0 = _errs9 === errors;
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
validate3401.errors = [{}];
return false;
}
}
validate3401.errors = vErrors;
return errors === 0;
}
validate3401.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate3400(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3400.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate3401(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3401.errors : vErrors.concat(validate3401.errors);
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
validate3400.errors = vErrors;
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
validate3400.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate3400.evaluated = {"dynamicProps":true,"dynamicItems":false};


function validate3351(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3351.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((((((((data.definition === undefined) && (missing0 = "definition")) || ((data.binding === undefined) && (missing0 = "binding"))) || ((data.source === undefined) && (missing0 = "source"))) || ((data.output === undefined) && (missing0 = "output"))) || ((data.sql === undefined) && (missing0 = "sql"))) || ((data.current === undefined) && (missing0 = "current"))) || ((data.completed === undefined) && (missing0 = "completed"))){
validate3351.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((((((key0 === "definition") || (key0 === "binding")) || (key0 === "source")) || (key0 === "output")) || (key0 === "sql")) || (key0 === "current")) || (key0 === "completed"))){
validate3351.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.definition !== undefined){
const _errs2 = errors;
if(!(validate3352(data.definition, {instancePath:instancePath+"/definition",parentData:data,parentDataProperty:"definition",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3352.errors : vErrors.concat(validate3352.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.binding !== undefined){
const _errs3 = errors;
if(!(validate3354(data.binding, {instancePath:instancePath+"/binding",parentData:data,parentDataProperty:"binding",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3354.errors : vErrors.concat(validate3354.errors);
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
if(!(validate3354(data.source, {instancePath:instancePath+"/source",parentData:data,parentDataProperty:"source",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3354.errors : vErrors.concat(validate3354.errors);
errors = vErrors.length;
}
var valid0 = _errs4 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.output !== undefined){
const _errs5 = errors;
if(!(validate3354(data.output, {instancePath:instancePath+"/output",parentData:data,parentDataProperty:"output",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3354.errors : vErrors.concat(validate3354.errors);
errors = vErrors.length;
}
var valid0 = _errs5 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.sql !== undefined){
const _errs6 = errors;
if(!(validate3357(data.sql, {instancePath:instancePath+"/sql",parentData:data,parentDataProperty:"sql",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3357.errors : vErrors.concat(validate3357.errors);
errors = vErrors.length;
}
var valid0 = _errs6 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.current !== undefined){
const _errs7 = errors;
if(!(validate3376(data.current, {instancePath:instancePath+"/current",parentData:data,parentDataProperty:"current",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3376.errors : vErrors.concat(validate3376.errors);
errors = vErrors.length;
}
var valid0 = _errs7 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.completed !== undefined){
const _errs8 = errors;
if(!(validate3400(data.completed, {instancePath:instancePath+"/completed",parentData:data,parentDataProperty:"completed",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3400.errors : vErrors.concat(validate3400.errors);
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
validate3351.errors = [{}];
return false;
}
}
validate3351.errors = vErrors;
return errors === 0;
}
validate3351.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};
