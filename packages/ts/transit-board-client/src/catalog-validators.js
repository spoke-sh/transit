// Generated; no runtime code generation or eval.
import lengthModule from "ajv/dist/runtime/ucs2length.js";
const ucs2length = lengthModule.default ?? lengthModule;
"use strict";
export const CatalogRequest = validate2177;
const schema590 = {"type":"object","additionalProperties":false,"properties":{"definition":{"$ref":"#/$defs/CatalogRequest/$defs/T1"},"action":{"$ref":"#/$defs/CatalogRequest/$defs/T2"}},"required":["definition","action"]};
const schema21 = {"type":"string","enum":["6da8e815dec26c458515e34fb6553654d57c77536f652b9258897bf1a513842e"]};

function validate2178(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2178.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate2178.errors = [{}];
return false;
}
if(!(data === "6da8e815dec26c458515e34fb6553654d57c77536f652b9258897bf1a513842e")){
validate2178.errors = [{}];
return false;
}
validate2178.errors = vErrors;
return errors === 0;
}
validate2178.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema592 = {"oneOf":[{"type":"object","additionalProperties":false,"required":["describe"],"properties":{"describe":{"$ref":"#/$defs/CatalogRequest/$defs/T3"}}},{"type":"object","additionalProperties":false,"required":["history"],"properties":{"history":{"$ref":"#/$defs/CatalogRequest/$defs/T4"}}},{"type":"object","additionalProperties":false,"required":["definitions"],"properties":{"definitions":{"$ref":"#/$defs/CatalogRequest/$defs/T19"}}},{"type":"object","additionalProperties":false,"required":["namespaces"],"properties":{"namespaces":{"$ref":"#/$defs/CatalogRequest/$defs/T31"}}},{"type":"object","additionalProperties":false,"required":["tables"],"properties":{"tables":{"$ref":"#/$defs/CatalogRequest/$defs/T35"}}},{"type":"object","additionalProperties":false,"required":["resources"],"properties":{"resources":{"$ref":"#/$defs/CatalogRequest/$defs/T36"}}},{"type":"object","additionalProperties":false,"required":["table"],"properties":{"table":{"$ref":"#/$defs/CatalogRequest/$defs/T37"}}},{"type":"object","additionalProperties":false,"required":["storage"],"properties":{"storage":{"$ref":"#/$defs/CatalogRequest/$defs/T38"}}},{"type":"object","additionalProperties":false,"required":["dependencies"],"properties":{"dependencies":{"$ref":"#/$defs/CatalogRequest/$defs/T41"}}}]};
const schema593 = {"type":"object","maxProperties":0};

function validate2181(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2181.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
if(Object.keys(data).length > 0){
validate2181.errors = [{}];
return false;
}
}
else {
validate2181.errors = [{}];
return false;
}
}
validate2181.errors = vErrors;
return errors === 0;
}
validate2181.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema594 = {"oneOf":[{"type":"object","additionalProperties":false,"required":["lookup"],"properties":{"lookup":{"$ref":"#/$defs/CatalogRequest/$defs/T5"}}},{"type":"object","additionalProperties":false,"required":["namespace"],"properties":{"namespace":{"$ref":"#/$defs/CatalogRequest/$defs/T8"}}},{"type":"object","additionalProperties":false,"required":["list"],"properties":{"list":{"$ref":"#/$defs/CatalogRequest/$defs/T9"}}},{"type":"object","additionalProperties":false,"required":["source"],"properties":{"source":{"$ref":"#/$defs/CatalogRequest/$defs/T14"}}},{"type":"object","additionalProperties":false,"required":["definitions"],"properties":{"definitions":{"$ref":"#/$defs/CatalogRequest/$defs/T15"}}},{"type":"object","additionalProperties":false,"required":["locations"],"properties":{"locations":{"$ref":"#/$defs/CatalogRequest/$defs/T15"}}}]};
const schema595 = {"type":"object","additionalProperties":false,"properties":{"selector":{"$ref":"#/$defs/CatalogRequest/$defs/T6"},"namespace":{"$ref":"#/$defs/CatalogRequest/$defs/T7"},"name":{"$ref":"#/$defs/CatalogRequest/$defs/T6"}},"required":["selector","namespace","name"]};
const schema596 = {"type":"string","maxLength":262144};
const func3 = ucs2length;

function validate2185(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2185.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(typeof data === "string"){
if(func3(data) > 262144){
validate2185.errors = [{}];
return false;
}
}
else {
validate2185.errors = [{}];
return false;
}
}
validate2185.errors = vErrors;
return errors === 0;
}
validate2185.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema22 = {"type":"integer","minimum":0,"maximum":9007199254740991};

function validate2187(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2187.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(!(((typeof data == "number") && (!(data % 1) && !isNaN(data))) && (isFinite(data)))){
validate2187.errors = [{}];
return false;
}
if(errors === 0){
if((typeof data == "number") && (isFinite(data))){
if(data > 9007199254740991 || isNaN(data)){
validate2187.errors = [{}];
return false;
}
else {
if(data < 0 || isNaN(data)){
validate2187.errors = [{}];
return false;
}
}
}
}
validate2187.errors = vErrors;
return errors === 0;
}
validate2187.evaluated = {"dynamicProps":false,"dynamicItems":false};


function validate2184(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2184.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((((data.selector === undefined) && (missing0 = "selector")) || ((data.namespace === undefined) && (missing0 = "namespace"))) || ((data.name === undefined) && (missing0 = "name"))){
validate2184.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "selector") || (key0 === "namespace")) || (key0 === "name"))){
validate2184.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.selector !== undefined){
const _errs2 = errors;
if(!(validate2185(data.selector, {instancePath:instancePath+"/selector",parentData:data,parentDataProperty:"selector",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2185.errors : vErrors.concat(validate2185.errors);
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
if(!(validate2187(data.namespace, {instancePath:instancePath+"/namespace",parentData:data,parentDataProperty:"namespace",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2187.errors : vErrors.concat(validate2187.errors);
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
if(!(validate2185(data.name, {instancePath:instancePath+"/name",parentData:data,parentDataProperty:"name",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2185.errors : vErrors.concat(validate2185.errors);
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
validate2184.errors = [{}];
return false;
}
}
validate2184.errors = vErrors;
return errors === 0;
}
validate2184.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema598 = {"type":"object","additionalProperties":false,"properties":{"selector":{"$ref":"#/$defs/CatalogRequest/$defs/T6"},"name":{"$ref":"#/$defs/CatalogRequest/$defs/T6"}},"required":["selector","name"]};

function validate2191(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2191.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if(((data.selector === undefined) && (missing0 = "selector")) || ((data.name === undefined) && (missing0 = "name"))){
validate2191.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "selector") || (key0 === "name"))){
validate2191.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.selector !== undefined){
const _errs2 = errors;
if(!(validate2185(data.selector, {instancePath:instancePath+"/selector",parentData:data,parentDataProperty:"selector",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2185.errors : vErrors.concat(validate2185.errors);
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
if(!(validate2185(data.name, {instancePath:instancePath+"/name",parentData:data,parentDataProperty:"name",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2185.errors : vErrors.concat(validate2185.errors);
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
validate2191.errors = [{}];
return false;
}
}
validate2191.errors = vErrors;
return errors === 0;
}
validate2191.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema599 = {"type":"object","additionalProperties":false,"properties":{"selector":{"$ref":"#/$defs/CatalogRequest/$defs/T6"},"namespace":{"$ref":"#/$defs/CatalogRequest/$defs/T7"},"after":{"$ref":"#/$defs/CatalogRequest/$defs/T10"}},"required":["selector","namespace","after"]};
const schema600 = {"anyOf":[{"$ref":"#/$defs/CatalogRequest/$defs/T11"},{"type":"null"}]};
const schema601 = {"type":"object","additionalProperties":false,"properties":{"selector":{"$ref":"#/$defs/CatalogRequest/$defs/T6"},"namespace":{"$ref":"#/$defs/CatalogRequest/$defs/T7"},"directory":{"$ref":"#/$defs/CatalogRequest/$defs/T12"},"after":{"$ref":"#/$defs/CatalogRequest/$defs/T6"}},"required":["selector","namespace","directory","after"]};
const schema602 = {"type":"object","additionalProperties":false,"properties":{"content":{"$ref":"#/$defs/CatalogRequest/$defs/T13"},"count":{"$ref":"#/$defs/CatalogRequest/$defs/T6"},"descriptors":{"$ref":"#/$defs/CatalogRequest/$defs/T6"}},"required":["content","count","descriptors"]};
const schema603 = {"type":"object","additionalProperties":false,"properties":{"bytes":{"$ref":"#/$defs/CatalogRequest/$defs/T6"},"sha256":{"$ref":"#/$defs/CatalogRequest/$defs/T6"}},"required":["bytes","sha256"]};

function validate2203(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2203.evaluated;
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
validate2203.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "bytes") || (key0 === "sha256"))){
validate2203.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.bytes !== undefined){
const _errs2 = errors;
if(!(validate2185(data.bytes, {instancePath:instancePath+"/bytes",parentData:data,parentDataProperty:"bytes",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2185.errors : vErrors.concat(validate2185.errors);
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
if(!(validate2185(data.sha256, {instancePath:instancePath+"/sha256",parentData:data,parentDataProperty:"sha256",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2185.errors : vErrors.concat(validate2185.errors);
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
validate2203.errors = [{}];
return false;
}
}
validate2203.errors = vErrors;
return errors === 0;
}
validate2203.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate2202(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2202.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((((data.content === undefined) && (missing0 = "content")) || ((data.count === undefined) && (missing0 = "count"))) || ((data.descriptors === undefined) && (missing0 = "descriptors"))){
validate2202.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "content") || (key0 === "count")) || (key0 === "descriptors"))){
validate2202.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.content !== undefined){
const _errs2 = errors;
if(!(validate2203(data.content, {instancePath:instancePath+"/content",parentData:data,parentDataProperty:"content",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2203.errors : vErrors.concat(validate2203.errors);
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
if(!(validate2185(data.count, {instancePath:instancePath+"/count",parentData:data,parentDataProperty:"count",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2185.errors : vErrors.concat(validate2185.errors);
errors = vErrors.length;
}
var valid0 = _errs3 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.descriptors !== undefined){
const _errs4 = errors;
if(!(validate2185(data.descriptors, {instancePath:instancePath+"/descriptors",parentData:data,parentDataProperty:"descriptors",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2185.errors : vErrors.concat(validate2185.errors);
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
validate2202.errors = [{}];
return false;
}
}
validate2202.errors = vErrors;
return errors === 0;
}
validate2202.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate2199(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2199.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if(((((data.selector === undefined) && (missing0 = "selector")) || ((data.namespace === undefined) && (missing0 = "namespace"))) || ((data.directory === undefined) && (missing0 = "directory"))) || ((data.after === undefined) && (missing0 = "after"))){
validate2199.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((((key0 === "selector") || (key0 === "namespace")) || (key0 === "directory")) || (key0 === "after"))){
validate2199.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.selector !== undefined){
const _errs2 = errors;
if(!(validate2185(data.selector, {instancePath:instancePath+"/selector",parentData:data,parentDataProperty:"selector",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2185.errors : vErrors.concat(validate2185.errors);
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
if(!(validate2187(data.namespace, {instancePath:instancePath+"/namespace",parentData:data,parentDataProperty:"namespace",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2187.errors : vErrors.concat(validate2187.errors);
errors = vErrors.length;
}
var valid0 = _errs3 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.directory !== undefined){
const _errs4 = errors;
if(!(validate2202(data.directory, {instancePath:instancePath+"/directory",parentData:data,parentDataProperty:"directory",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2202.errors : vErrors.concat(validate2202.errors);
errors = vErrors.length;
}
var valid0 = _errs4 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.after !== undefined){
const _errs5 = errors;
if(!(validate2185(data.after, {instancePath:instancePath+"/after",parentData:data,parentDataProperty:"after",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2185.errors : vErrors.concat(validate2185.errors);
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
validate2199.errors = [{}];
return false;
}
}
validate2199.errors = vErrors;
return errors === 0;
}
validate2199.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate2198(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2198.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate2199(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2199.errors : vErrors.concat(validate2199.errors);
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
validate2198.errors = vErrors;
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
validate2198.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate2198.evaluated = {"dynamicProps":true,"dynamicItems":false};


function validate2195(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2195.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((((data.selector === undefined) && (missing0 = "selector")) || ((data.namespace === undefined) && (missing0 = "namespace"))) || ((data.after === undefined) && (missing0 = "after"))){
validate2195.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "selector") || (key0 === "namespace")) || (key0 === "after"))){
validate2195.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.selector !== undefined){
const _errs2 = errors;
if(!(validate2185(data.selector, {instancePath:instancePath+"/selector",parentData:data,parentDataProperty:"selector",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2185.errors : vErrors.concat(validate2185.errors);
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
if(!(validate2187(data.namespace, {instancePath:instancePath+"/namespace",parentData:data,parentDataProperty:"namespace",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2187.errors : vErrors.concat(validate2187.errors);
errors = vErrors.length;
}
var valid0 = _errs3 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.after !== undefined){
const _errs4 = errors;
if(!(validate2198(data.after, {instancePath:instancePath+"/after",parentData:data,parentDataProperty:"after",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2198.errors : vErrors.concat(validate2198.errors);
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
validate2195.errors = [{}];
return false;
}
}
validate2195.errors = vErrors;
return errors === 0;
}
validate2195.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema604 = {"type":"object","additionalProperties":false,"properties":{"selector":{"$ref":"#/$defs/CatalogRequest/$defs/T6"},"object":{"$ref":"#/$defs/CatalogRequest/$defs/T6"}},"required":["selector","object"]};

function validate2214(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2214.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if(((data.selector === undefined) && (missing0 = "selector")) || ((data.object === undefined) && (missing0 = "object"))){
validate2214.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "selector") || (key0 === "object"))){
validate2214.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.selector !== undefined){
const _errs2 = errors;
if(!(validate2185(data.selector, {instancePath:instancePath+"/selector",parentData:data,parentDataProperty:"selector",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2185.errors : vErrors.concat(validate2185.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.object !== undefined){
const _errs3 = errors;
if(!(validate2185(data.object, {instancePath:instancePath+"/object",parentData:data,parentDataProperty:"object",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2185.errors : vErrors.concat(validate2185.errors);
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
validate2214.errors = [{}];
return false;
}
}
validate2214.errors = vErrors;
return errors === 0;
}
validate2214.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema605 = {"type":"object","additionalProperties":false,"properties":{"selector":{"$ref":"#/$defs/CatalogRequest/$defs/T6"},"object":{"$ref":"#/$defs/CatalogRequest/$defs/T6"},"after":{"$ref":"#/$defs/CatalogRequest/$defs/T16"}},"required":["selector","object","after"]};
const schema606 = {"anyOf":[{"$ref":"#/$defs/CatalogRequest/$defs/T17"},{"type":"null"}]};
const schema607 = {"type":"object","additionalProperties":false,"properties":{"selector":{"$ref":"#/$defs/CatalogRequest/$defs/T6"},"object":{"$ref":"#/$defs/CatalogRequest/$defs/T6"},"kind":{"$ref":"#/$defs/CatalogRequest/$defs/T18"},"source":{"$ref":"#/$defs/CatalogRequest/$defs/T13"},"after":{"$ref":"#/$defs/CatalogRequest/$defs/T6"}},"required":["selector","object","kind","source","after"]};
const schema608 = {"type":"string","enum":["definitions","locations"]};

function validate2226(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2226.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate2226.errors = [{}];
return false;
}
if(!((data === "definitions") || (data === "locations"))){
validate2226.errors = [{}];
return false;
}
validate2226.errors = vErrors;
return errors === 0;
}
validate2226.evaluated = {"dynamicProps":false,"dynamicItems":false};


function validate2222(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2222.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((((((data.selector === undefined) && (missing0 = "selector")) || ((data.object === undefined) && (missing0 = "object"))) || ((data.kind === undefined) && (missing0 = "kind"))) || ((data.source === undefined) && (missing0 = "source"))) || ((data.after === undefined) && (missing0 = "after"))){
validate2222.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((((key0 === "selector") || (key0 === "object")) || (key0 === "kind")) || (key0 === "source")) || (key0 === "after"))){
validate2222.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.selector !== undefined){
const _errs2 = errors;
if(!(validate2185(data.selector, {instancePath:instancePath+"/selector",parentData:data,parentDataProperty:"selector",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2185.errors : vErrors.concat(validate2185.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.object !== undefined){
const _errs3 = errors;
if(!(validate2185(data.object, {instancePath:instancePath+"/object",parentData:data,parentDataProperty:"object",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2185.errors : vErrors.concat(validate2185.errors);
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
if(!(validate2226(data.kind, {instancePath:instancePath+"/kind",parentData:data,parentDataProperty:"kind",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2226.errors : vErrors.concat(validate2226.errors);
errors = vErrors.length;
}
var valid0 = _errs4 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.source !== undefined){
const _errs5 = errors;
if(!(validate2203(data.source, {instancePath:instancePath+"/source",parentData:data,parentDataProperty:"source",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2203.errors : vErrors.concat(validate2203.errors);
errors = vErrors.length;
}
var valid0 = _errs5 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.after !== undefined){
const _errs6 = errors;
if(!(validate2185(data.after, {instancePath:instancePath+"/after",parentData:data,parentDataProperty:"after",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2185.errors : vErrors.concat(validate2185.errors);
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
validate2222.errors = [{}];
return false;
}
}
validate2222.errors = vErrors;
return errors === 0;
}
validate2222.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate2221(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2221.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate2222(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2222.errors : vErrors.concat(validate2222.errors);
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
validate2221.errors = vErrors;
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
validate2221.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate2221.evaluated = {"dynamicProps":true,"dynamicItems":false};


function validate2218(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2218.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((((data.selector === undefined) && (missing0 = "selector")) || ((data.object === undefined) && (missing0 = "object"))) || ((data.after === undefined) && (missing0 = "after"))){
validate2218.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "selector") || (key0 === "object")) || (key0 === "after"))){
validate2218.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.selector !== undefined){
const _errs2 = errors;
if(!(validate2185(data.selector, {instancePath:instancePath+"/selector",parentData:data,parentDataProperty:"selector",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2185.errors : vErrors.concat(validate2185.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.object !== undefined){
const _errs3 = errors;
if(!(validate2185(data.object, {instancePath:instancePath+"/object",parentData:data,parentDataProperty:"object",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2185.errors : vErrors.concat(validate2185.errors);
errors = vErrors.length;
}
var valid0 = _errs3 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.after !== undefined){
const _errs4 = errors;
if(!(validate2221(data.after, {instancePath:instancePath+"/after",parentData:data,parentDataProperty:"after",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2221.errors : vErrors.concat(validate2221.errors);
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
validate2218.errors = [{}];
return false;
}
}
validate2218.errors = vErrors;
return errors === 0;
}
validate2218.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate2183(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2183.evaluated;
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
if((data.lookup === undefined) && (missing0 = "lookup")){
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
const _errs3 = errors;
for(const key0 in data){
if(!(key0 === "lookup")){
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
if(_errs3 === errors){
if(data.lookup !== undefined){
if(!(validate2184(data.lookup, {instancePath:instancePath+"/lookup",parentData:data,parentDataProperty:"lookup",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2184.errors : vErrors.concat(validate2184.errors);
errors = vErrors.length;
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
var _valid0 = _errs1 === errors;
if(_valid0){
valid0 = true;
passing0 = 0;
var props0 = true;
}
const _errs5 = errors;
if(errors === _errs5){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing1;
if((data.namespace === undefined) && (missing1 = "namespace")){
const err3 = {};
if(vErrors === null){
vErrors = [err3];
}
else {
vErrors.push(err3);
}
errors++;
}
else {
const _errs7 = errors;
for(const key1 in data){
if(!(key1 === "namespace")){
const err4 = {};
if(vErrors === null){
vErrors = [err4];
}
else {
vErrors.push(err4);
}
errors++;
break;
}
}
if(_errs7 === errors){
if(data.namespace !== undefined){
if(!(validate2191(data.namespace, {instancePath:instancePath+"/namespace",parentData:data,parentDataProperty:"namespace",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2191.errors : vErrors.concat(validate2191.errors);
errors = vErrors.length;
}
}
}
}
}
else {
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
var _valid0 = _errs5 === errors;
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
const _errs9 = errors;
if(errors === _errs9){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing2;
if((data.list === undefined) && (missing2 = "list")){
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
const _errs11 = errors;
for(const key2 in data){
if(!(key2 === "list")){
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
if(_errs11 === errors){
if(data.list !== undefined){
if(!(validate2195(data.list, {instancePath:instancePath+"/list",parentData:data,parentDataProperty:"list",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2195.errors : vErrors.concat(validate2195.errors);
errors = vErrors.length;
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
var _valid0 = _errs9 === errors;
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
const _errs13 = errors;
if(errors === _errs13){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing3;
if((data.source === undefined) && (missing3 = "source")){
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
const _errs15 = errors;
for(const key3 in data){
if(!(key3 === "source")){
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
if(_errs15 === errors){
if(data.source !== undefined){
if(!(validate2214(data.source, {instancePath:instancePath+"/source",parentData:data,parentDataProperty:"source",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2214.errors : vErrors.concat(validate2214.errors);
errors = vErrors.length;
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
var _valid0 = _errs13 === errors;
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
const _errs17 = errors;
if(errors === _errs17){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing4;
if((data.definitions === undefined) && (missing4 = "definitions")){
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
const _errs19 = errors;
for(const key4 in data){
if(!(key4 === "definitions")){
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
if(_errs19 === errors){
if(data.definitions !== undefined){
if(!(validate2218(data.definitions, {instancePath:instancePath+"/definitions",parentData:data,parentDataProperty:"definitions",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2218.errors : vErrors.concat(validate2218.errors);
errors = vErrors.length;
}
}
}
}
}
else {
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
var _valid0 = _errs17 === errors;
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
const _errs21 = errors;
if(errors === _errs21){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing5;
if((data.locations === undefined) && (missing5 = "locations")){
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
const _errs23 = errors;
for(const key5 in data){
if(!(key5 === "locations")){
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
if(_errs23 === errors){
if(data.locations !== undefined){
if(!(validate2218(data.locations, {instancePath:instancePath+"/locations",parentData:data,parentDataProperty:"locations",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2218.errors : vErrors.concat(validate2218.errors);
errors = vErrors.length;
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
var _valid0 = _errs21 === errors;
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
const err18 = {};
if(vErrors === null){
vErrors = [err18];
}
else {
vErrors.push(err18);
}
errors++;
validate2183.errors = vErrors;
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
validate2183.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate2183.evaluated = {"dynamicProps":true,"dynamicItems":false};

const schema610 = {"oneOf":[{"type":"object","additionalProperties":false,"required":["lookup"],"properties":{"lookup":{"$ref":"#/$defs/CatalogRequest/$defs/T20"}}},{"type":"object","additionalProperties":false,"required":["inspect"],"properties":{"inspect":{"$ref":"#/$defs/CatalogRequest/$defs/T21"}}},{"type":"object","additionalProperties":false,"required":["historical"],"properties":{"historical":{"$ref":"#/$defs/CatalogRequest/$defs/T24"}}},{"type":"object","additionalProperties":false,"required":["list"],"properties":{"list":{"$ref":"#/$defs/CatalogRequest/$defs/T25"}}}]};
const schema611 = {"type":"object","additionalProperties":false,"properties":{"namespace":{"$ref":"#/$defs/CatalogRequest/$defs/T7"},"name":{"$ref":"#/$defs/CatalogRequest/$defs/T6"}},"required":["namespace","name"]};

function validate2236(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2236.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if(((data.namespace === undefined) && (missing0 = "namespace")) || ((data.name === undefined) && (missing0 = "name"))){
validate2236.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "namespace") || (key0 === "name"))){
validate2236.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.namespace !== undefined){
const _errs2 = errors;
if(!(validate2187(data.namespace, {instancePath:instancePath+"/namespace",parentData:data,parentDataProperty:"namespace",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2187.errors : vErrors.concat(validate2187.errors);
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
if(!(validate2185(data.name, {instancePath:instancePath+"/name",parentData:data,parentDataProperty:"name",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2185.errors : vErrors.concat(validate2185.errors);
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
validate2236.errors = [{}];
return false;
}
}
validate2236.errors = vErrors;
return errors === 0;
}
validate2236.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema612 = {"type":"object","additionalProperties":false,"properties":{"object":{"$ref":"#/$defs/CatalogRequest/$defs/T22"},"revision":{"$ref":"#/$defs/CatalogRequest/$defs/T6"},"digest":{"$ref":"#/$defs/CatalogRequest/$defs/T6"}},"required":["object","revision","digest"]};
const schema613 = {"type":"object","additionalProperties":false,"properties":{"scope":{"$ref":"#/$defs/CatalogRequest/$defs/T23"},"branch":{"$ref":"#/$defs/CatalogRequest/$defs/T6"},"object":{"$ref":"#/$defs/CatalogRequest/$defs/T6"}},"required":["scope","branch","object"]};
const schema614 = {"type":"object","additionalProperties":false,"properties":{"realm":{"$ref":"#/$defs/CatalogRequest/$defs/T7"},"resource":{"$ref":"#/$defs/CatalogRequest/$defs/T7"},"catalog":{"$ref":"#/$defs/CatalogRequest/$defs/T6"}},"required":["realm","resource","catalog"]};

function validate2242(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2242.evaluated;
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
validate2242.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "realm") || (key0 === "resource")) || (key0 === "catalog"))){
validate2242.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.realm !== undefined){
const _errs2 = errors;
if(!(validate2187(data.realm, {instancePath:instancePath+"/realm",parentData:data,parentDataProperty:"realm",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2187.errors : vErrors.concat(validate2187.errors);
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
if(!(validate2187(data.resource, {instancePath:instancePath+"/resource",parentData:data,parentDataProperty:"resource",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2187.errors : vErrors.concat(validate2187.errors);
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
if(!(validate2185(data.catalog, {instancePath:instancePath+"/catalog",parentData:data,parentDataProperty:"catalog",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2185.errors : vErrors.concat(validate2185.errors);
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
validate2242.errors = [{}];
return false;
}
}
validate2242.errors = vErrors;
return errors === 0;
}
validate2242.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate2241(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2241.evaluated;
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
validate2241.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "scope") || (key0 === "branch")) || (key0 === "object"))){
validate2241.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.scope !== undefined){
const _errs2 = errors;
if(!(validate2242(data.scope, {instancePath:instancePath+"/scope",parentData:data,parentDataProperty:"scope",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2242.errors : vErrors.concat(validate2242.errors);
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
if(!(validate2185(data.branch, {instancePath:instancePath+"/branch",parentData:data,parentDataProperty:"branch",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2185.errors : vErrors.concat(validate2185.errors);
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
if(!(validate2185(data.object, {instancePath:instancePath+"/object",parentData:data,parentDataProperty:"object",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2185.errors : vErrors.concat(validate2185.errors);
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
validate2241.errors = [{}];
return false;
}
}
validate2241.errors = vErrors;
return errors === 0;
}
validate2241.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate2240(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2240.evaluated;
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
validate2240.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "object") || (key0 === "revision")) || (key0 === "digest"))){
validate2240.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.object !== undefined){
const _errs2 = errors;
if(!(validate2241(data.object, {instancePath:instancePath+"/object",parentData:data,parentDataProperty:"object",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2241.errors : vErrors.concat(validate2241.errors);
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
if(!(validate2185(data.revision, {instancePath:instancePath+"/revision",parentData:data,parentDataProperty:"revision",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2185.errors : vErrors.concat(validate2185.errors);
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
if(!(validate2185(data.digest, {instancePath:instancePath+"/digest",parentData:data,parentDataProperty:"digest",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2185.errors : vErrors.concat(validate2185.errors);
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
validate2240.errors = [{}];
return false;
}
}
validate2240.errors = vErrors;
return errors === 0;
}
validate2240.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema615 = {"type":"object","additionalProperties":false,"properties":{"selector":{"$ref":"#/$defs/CatalogRequest/$defs/T6"},"namespace":{"$ref":"#/$defs/CatalogRequest/$defs/T7"},"name":{"$ref":"#/$defs/CatalogRequest/$defs/T6"}},"required":["selector","namespace","name"]};

function validate2253(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2253.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((((data.selector === undefined) && (missing0 = "selector")) || ((data.namespace === undefined) && (missing0 = "namespace"))) || ((data.name === undefined) && (missing0 = "name"))){
validate2253.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "selector") || (key0 === "namespace")) || (key0 === "name"))){
validate2253.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.selector !== undefined){
const _errs2 = errors;
if(!(validate2185(data.selector, {instancePath:instancePath+"/selector",parentData:data,parentDataProperty:"selector",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2185.errors : vErrors.concat(validate2185.errors);
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
if(!(validate2187(data.namespace, {instancePath:instancePath+"/namespace",parentData:data,parentDataProperty:"namespace",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2187.errors : vErrors.concat(validate2187.errors);
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
if(!(validate2185(data.name, {instancePath:instancePath+"/name",parentData:data,parentDataProperty:"name",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2185.errors : vErrors.concat(validate2185.errors);
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
validate2253.errors = [{}];
return false;
}
}
validate2253.errors = vErrors;
return errors === 0;
}
validate2253.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema616 = {"type":"object","additionalProperties":false,"properties":{"namespace":{"$ref":"#/$defs/CatalogRequest/$defs/T7"},"selector":{"$ref":"#/$defs/CatalogRequest/$defs/T26"},"cursor":{"$ref":"#/$defs/CatalogRequest/$defs/T27"}},"required":["namespace","selector","cursor"]};
const schema617 = {"anyOf":[{"$ref":"#/$defs/CatalogRequest/$defs/T6"},{"type":"null"}]};

function validate2260(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2260.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate2185(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2185.errors : vErrors.concat(validate2185.errors);
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
validate2260.errors = vErrors;
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
validate2260.errors = vErrors;
return errors === 0;
}
validate2260.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema618 = {"anyOf":[{"$ref":"#/$defs/CatalogRequest/$defs/T28"},{"type":"null"}]};
const schema619 = {"type":"object","additionalProperties":false,"properties":{"definition":{"$ref":"#/$defs/CatalogRequest/$defs/T1"},"connection":{"$ref":"#/$defs/CatalogRequest/$defs/T29"},"namespace":{"$ref":"#/$defs/CatalogRequest/$defs/T7"},"selector":{"$ref":"#/$defs/CatalogRequest/$defs/T26"},"after":{"$ref":"#/$defs/CatalogRequest/$defs/T6"}},"required":["definition","connection","namespace","selector","after"]};
const schema620 = {"type":"object","additionalProperties":false,"properties":{"scope":{"$ref":"#/$defs/CatalogRequest/$defs/T23"},"branch":{"$ref":"#/$defs/CatalogRequest/$defs/T6"},"audience":{"$ref":"#/$defs/CatalogRequest/$defs/T7"},"principal":{"$ref":"#/$defs/CatalogRequest/$defs/T7"},"role":{"$ref":"#/$defs/CatalogRequest/$defs/T30"}},"required":["scope","branch","audience","principal","role"]};
const schema621 = {"anyOf":[{"$ref":"#/$defs/CatalogRequest/$defs/T7"},{"type":"null"}]};

function validate2271(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2271.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate2187(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2187.errors : vErrors.concat(validate2187.errors);
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
validate2271.errors = vErrors;
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
validate2271.errors = vErrors;
return errors === 0;
}
validate2271.evaluated = {"dynamicProps":false,"dynamicItems":false};


function validate2266(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2266.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((((((data.scope === undefined) && (missing0 = "scope")) || ((data.branch === undefined) && (missing0 = "branch"))) || ((data.audience === undefined) && (missing0 = "audience"))) || ((data.principal === undefined) && (missing0 = "principal"))) || ((data.role === undefined) && (missing0 = "role"))){
validate2266.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((((key0 === "scope") || (key0 === "branch")) || (key0 === "audience")) || (key0 === "principal")) || (key0 === "role"))){
validate2266.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.scope !== undefined){
const _errs2 = errors;
if(!(validate2242(data.scope, {instancePath:instancePath+"/scope",parentData:data,parentDataProperty:"scope",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2242.errors : vErrors.concat(validate2242.errors);
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
if(!(validate2185(data.branch, {instancePath:instancePath+"/branch",parentData:data,parentDataProperty:"branch",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2185.errors : vErrors.concat(validate2185.errors);
errors = vErrors.length;
}
var valid0 = _errs3 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.audience !== undefined){
const _errs4 = errors;
if(!(validate2187(data.audience, {instancePath:instancePath+"/audience",parentData:data,parentDataProperty:"audience",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2187.errors : vErrors.concat(validate2187.errors);
errors = vErrors.length;
}
var valid0 = _errs4 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.principal !== undefined){
const _errs5 = errors;
if(!(validate2187(data.principal, {instancePath:instancePath+"/principal",parentData:data,parentDataProperty:"principal",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2187.errors : vErrors.concat(validate2187.errors);
errors = vErrors.length;
}
var valid0 = _errs5 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.role !== undefined){
const _errs6 = errors;
if(!(validate2271(data.role, {instancePath:instancePath+"/role",parentData:data,parentDataProperty:"role",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2271.errors : vErrors.concat(validate2271.errors);
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
validate2266.errors = [{}];
return false;
}
}
validate2266.errors = vErrors;
return errors === 0;
}
validate2266.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate2264(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2264.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((((((data.definition === undefined) && (missing0 = "definition")) || ((data.connection === undefined) && (missing0 = "connection"))) || ((data.namespace === undefined) && (missing0 = "namespace"))) || ((data.selector === undefined) && (missing0 = "selector"))) || ((data.after === undefined) && (missing0 = "after"))){
validate2264.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((((key0 === "definition") || (key0 === "connection")) || (key0 === "namespace")) || (key0 === "selector")) || (key0 === "after"))){
validate2264.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.definition !== undefined){
const _errs2 = errors;
if(!(validate2178(data.definition, {instancePath:instancePath+"/definition",parentData:data,parentDataProperty:"definition",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2178.errors : vErrors.concat(validate2178.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.connection !== undefined){
const _errs3 = errors;
if(!(validate2266(data.connection, {instancePath:instancePath+"/connection",parentData:data,parentDataProperty:"connection",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2266.errors : vErrors.concat(validate2266.errors);
errors = vErrors.length;
}
var valid0 = _errs3 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.namespace !== undefined){
const _errs4 = errors;
if(!(validate2187(data.namespace, {instancePath:instancePath+"/namespace",parentData:data,parentDataProperty:"namespace",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2187.errors : vErrors.concat(validate2187.errors);
errors = vErrors.length;
}
var valid0 = _errs4 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.selector !== undefined){
const _errs5 = errors;
if(!(validate2260(data.selector, {instancePath:instancePath+"/selector",parentData:data,parentDataProperty:"selector",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2260.errors : vErrors.concat(validate2260.errors);
errors = vErrors.length;
}
var valid0 = _errs5 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.after !== undefined){
const _errs6 = errors;
if(!(validate2185(data.after, {instancePath:instancePath+"/after",parentData:data,parentDataProperty:"after",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2185.errors : vErrors.concat(validate2185.errors);
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
validate2264.errors = [{}];
return false;
}
}
validate2264.errors = vErrors;
return errors === 0;
}
validate2264.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate2263(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2263.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate2264(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2264.errors : vErrors.concat(validate2264.errors);
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
validate2263.errors = vErrors;
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
validate2263.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate2263.evaluated = {"dynamicProps":true,"dynamicItems":false};


function validate2258(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2258.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((((data.namespace === undefined) && (missing0 = "namespace")) || ((data.selector === undefined) && (missing0 = "selector"))) || ((data.cursor === undefined) && (missing0 = "cursor"))){
validate2258.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "namespace") || (key0 === "selector")) || (key0 === "cursor"))){
validate2258.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.namespace !== undefined){
const _errs2 = errors;
if(!(validate2187(data.namespace, {instancePath:instancePath+"/namespace",parentData:data,parentDataProperty:"namespace",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2187.errors : vErrors.concat(validate2187.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.selector !== undefined){
const _errs3 = errors;
if(!(validate2260(data.selector, {instancePath:instancePath+"/selector",parentData:data,parentDataProperty:"selector",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2260.errors : vErrors.concat(validate2260.errors);
errors = vErrors.length;
}
var valid0 = _errs3 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.cursor !== undefined){
const _errs4 = errors;
if(!(validate2263(data.cursor, {instancePath:instancePath+"/cursor",parentData:data,parentDataProperty:"cursor",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2263.errors : vErrors.concat(validate2263.errors);
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
validate2258.errors = [{}];
return false;
}
}
validate2258.errors = vErrors;
return errors === 0;
}
validate2258.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate2235(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2235.evaluated;
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
if((data.lookup === undefined) && (missing0 = "lookup")){
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
const _errs3 = errors;
for(const key0 in data){
if(!(key0 === "lookup")){
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
if(_errs3 === errors){
if(data.lookup !== undefined){
if(!(validate2236(data.lookup, {instancePath:instancePath+"/lookup",parentData:data,parentDataProperty:"lookup",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2236.errors : vErrors.concat(validate2236.errors);
errors = vErrors.length;
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
var _valid0 = _errs1 === errors;
if(_valid0){
valid0 = true;
passing0 = 0;
var props0 = true;
}
const _errs5 = errors;
if(errors === _errs5){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing1;
if((data.inspect === undefined) && (missing1 = "inspect")){
const err3 = {};
if(vErrors === null){
vErrors = [err3];
}
else {
vErrors.push(err3);
}
errors++;
}
else {
const _errs7 = errors;
for(const key1 in data){
if(!(key1 === "inspect")){
const err4 = {};
if(vErrors === null){
vErrors = [err4];
}
else {
vErrors.push(err4);
}
errors++;
break;
}
}
if(_errs7 === errors){
if(data.inspect !== undefined){
if(!(validate2240(data.inspect, {instancePath:instancePath+"/inspect",parentData:data,parentDataProperty:"inspect",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2240.errors : vErrors.concat(validate2240.errors);
errors = vErrors.length;
}
}
}
}
}
else {
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
var _valid0 = _errs5 === errors;
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
const _errs9 = errors;
if(errors === _errs9){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing2;
if((data.historical === undefined) && (missing2 = "historical")){
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
const _errs11 = errors;
for(const key2 in data){
if(!(key2 === "historical")){
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
if(_errs11 === errors){
if(data.historical !== undefined){
if(!(validate2253(data.historical, {instancePath:instancePath+"/historical",parentData:data,parentDataProperty:"historical",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2253.errors : vErrors.concat(validate2253.errors);
errors = vErrors.length;
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
var _valid0 = _errs9 === errors;
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
const _errs13 = errors;
if(errors === _errs13){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing3;
if((data.list === undefined) && (missing3 = "list")){
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
const _errs15 = errors;
for(const key3 in data){
if(!(key3 === "list")){
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
if(_errs15 === errors){
if(data.list !== undefined){
if(!(validate2258(data.list, {instancePath:instancePath+"/list",parentData:data,parentDataProperty:"list",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2258.errors : vErrors.concat(validate2258.errors);
errors = vErrors.length;
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
var _valid0 = _errs13 === errors;
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
}
}
}
if(!valid0){
const err12 = {};
if(vErrors === null){
vErrors = [err12];
}
else {
vErrors.push(err12);
}
errors++;
validate2235.errors = vErrors;
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
validate2235.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate2235.evaluated = {"dynamicProps":true,"dynamicItems":false};

const schema622 = {"anyOf":[{"$ref":"#/$defs/CatalogRequest/$defs/T32"},{"type":"null"}]};
const schema623 = {"type":"object","additionalProperties":false,"properties":{"definition":{"$ref":"#/$defs/CatalogRequest/$defs/T1"},"connection":{"$ref":"#/$defs/CatalogRequest/$defs/T29"},"selection":{"$ref":"#/$defs/CatalogRequest/$defs/T33"},"position":{"$ref":"#/$defs/CatalogRequest/$defs/T34"},"after":{"$ref":"#/$defs/CatalogRequest/$defs/T6"}},"required":["definition","connection","selection","position","after"]};
const schema624 = {"oneOf":[{"type":"object","additionalProperties":false,"required":["namespaces"],"properties":{"namespaces":{"$ref":"#/$defs/CatalogRequest/$defs/T3"}}},{"type":"object","additionalProperties":false,"required":["tables"],"properties":{"tables":{"$ref":"#/$defs/CatalogRequest/$defs/T7"}}},{"type":"object","additionalProperties":false,"required":["resources"],"properties":{"resources":{"$ref":"#/$defs/CatalogRequest/$defs/T7"}}}]};

function validate2286(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2286.evaluated;
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
if((data.namespaces === undefined) && (missing0 = "namespaces")){
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
const _errs3 = errors;
for(const key0 in data){
if(!(key0 === "namespaces")){
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
if(_errs3 === errors){
if(data.namespaces !== undefined){
if(!(validate2181(data.namespaces, {instancePath:instancePath+"/namespaces",parentData:data,parentDataProperty:"namespaces",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2181.errors : vErrors.concat(validate2181.errors);
errors = vErrors.length;
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
var _valid0 = _errs1 === errors;
if(_valid0){
valid0 = true;
passing0 = 0;
var props0 = true;
}
const _errs5 = errors;
if(errors === _errs5){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing1;
if((data.tables === undefined) && (missing1 = "tables")){
const err3 = {};
if(vErrors === null){
vErrors = [err3];
}
else {
vErrors.push(err3);
}
errors++;
}
else {
const _errs7 = errors;
for(const key1 in data){
if(!(key1 === "tables")){
const err4 = {};
if(vErrors === null){
vErrors = [err4];
}
else {
vErrors.push(err4);
}
errors++;
break;
}
}
if(_errs7 === errors){
if(data.tables !== undefined){
if(!(validate2187(data.tables, {instancePath:instancePath+"/tables",parentData:data,parentDataProperty:"tables",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2187.errors : vErrors.concat(validate2187.errors);
errors = vErrors.length;
}
}
}
}
}
else {
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
var _valid0 = _errs5 === errors;
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
const _errs9 = errors;
if(errors === _errs9){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing2;
if((data.resources === undefined) && (missing2 = "resources")){
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
const _errs11 = errors;
for(const key2 in data){
if(!(key2 === "resources")){
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
if(_errs11 === errors){
if(data.resources !== undefined){
if(!(validate2187(data.resources, {instancePath:instancePath+"/resources",parentData:data,parentDataProperty:"resources",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2187.errors : vErrors.concat(validate2187.errors);
errors = vErrors.length;
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
var _valid0 = _errs9 === errors;
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
const err9 = {};
if(vErrors === null){
vErrors = [err9];
}
else {
vErrors.push(err9);
}
errors++;
validate2286.errors = vErrors;
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
validate2286.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate2286.evaluated = {"dynamicProps":true,"dynamicItems":false};

const schema625 = {"type":"object","additionalProperties":false,"properties":{"partition":{"$ref":"#/$defs/CatalogRequest/$defs/T6"},"next_lsn":{"$ref":"#/$defs/CatalogRequest/$defs/T6"}},"required":["partition","next_lsn"]};

function validate2291(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2291.evaluated;
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
validate2291.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "partition") || (key0 === "next_lsn"))){
validate2291.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.partition !== undefined){
const _errs2 = errors;
if(!(validate2185(data.partition, {instancePath:instancePath+"/partition",parentData:data,parentDataProperty:"partition",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2185.errors : vErrors.concat(validate2185.errors);
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
if(!(validate2185(data.next_lsn, {instancePath:instancePath+"/next_lsn",parentData:data,parentDataProperty:"next_lsn",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2185.errors : vErrors.concat(validate2185.errors);
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
validate2291.errors = [{}];
return false;
}
}
validate2291.errors = vErrors;
return errors === 0;
}
validate2291.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate2283(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2283.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((((((data.definition === undefined) && (missing0 = "definition")) || ((data.connection === undefined) && (missing0 = "connection"))) || ((data.selection === undefined) && (missing0 = "selection"))) || ((data.position === undefined) && (missing0 = "position"))) || ((data.after === undefined) && (missing0 = "after"))){
validate2283.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((((key0 === "definition") || (key0 === "connection")) || (key0 === "selection")) || (key0 === "position")) || (key0 === "after"))){
validate2283.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.definition !== undefined){
const _errs2 = errors;
if(!(validate2178(data.definition, {instancePath:instancePath+"/definition",parentData:data,parentDataProperty:"definition",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2178.errors : vErrors.concat(validate2178.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.connection !== undefined){
const _errs3 = errors;
if(!(validate2266(data.connection, {instancePath:instancePath+"/connection",parentData:data,parentDataProperty:"connection",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2266.errors : vErrors.concat(validate2266.errors);
errors = vErrors.length;
}
var valid0 = _errs3 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.selection !== undefined){
const _errs4 = errors;
if(!(validate2286(data.selection, {instancePath:instancePath+"/selection",parentData:data,parentDataProperty:"selection",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2286.errors : vErrors.concat(validate2286.errors);
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
if(!(validate2291(data.position, {instancePath:instancePath+"/position",parentData:data,parentDataProperty:"position",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2291.errors : vErrors.concat(validate2291.errors);
errors = vErrors.length;
}
var valid0 = _errs5 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.after !== undefined){
const _errs6 = errors;
if(!(validate2185(data.after, {instancePath:instancePath+"/after",parentData:data,parentDataProperty:"after",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2185.errors : vErrors.concat(validate2185.errors);
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
validate2283.errors = [{}];
return false;
}
}
validate2283.errors = vErrors;
return errors === 0;
}
validate2283.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate2282(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2282.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate2283(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2283.errors : vErrors.concat(validate2283.errors);
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
validate2282.errors = vErrors;
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
validate2282.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate2282.evaluated = {"dynamicProps":true,"dynamicItems":false};

const schema626 = {"type":"object","additionalProperties":false,"properties":{"namespace":{"$ref":"#/$defs/CatalogRequest/$defs/T7"},"cursor":{"$ref":"#/$defs/CatalogRequest/$defs/T31"}},"required":["namespace","cursor"]};

function validate2298(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2298.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if(((data.namespace === undefined) && (missing0 = "namespace")) || ((data.cursor === undefined) && (missing0 = "cursor"))){
validate2298.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "namespace") || (key0 === "cursor"))){
validate2298.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.namespace !== undefined){
const _errs2 = errors;
if(!(validate2187(data.namespace, {instancePath:instancePath+"/namespace",parentData:data,parentDataProperty:"namespace",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2187.errors : vErrors.concat(validate2187.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.cursor !== undefined){
const _errs3 = errors;
if(!(validate2282(data.cursor, {instancePath:instancePath+"/cursor",parentData:data,parentDataProperty:"cursor",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2282.errors : vErrors.concat(validate2282.errors);
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
validate2298.errors = [{}];
return false;
}
}
validate2298.errors = vErrors;
return errors === 0;
}
validate2298.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema627 = {"type":"object","additionalProperties":false,"properties":{"namespace":{"$ref":"#/$defs/CatalogRequest/$defs/T7"},"cursor":{"$ref":"#/$defs/CatalogRequest/$defs/T31"}},"required":["namespace","cursor"]};

function validate2302(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2302.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if(((data.namespace === undefined) && (missing0 = "namespace")) || ((data.cursor === undefined) && (missing0 = "cursor"))){
validate2302.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "namespace") || (key0 === "cursor"))){
validate2302.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.namespace !== undefined){
const _errs2 = errors;
if(!(validate2187(data.namespace, {instancePath:instancePath+"/namespace",parentData:data,parentDataProperty:"namespace",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2187.errors : vErrors.concat(validate2187.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.cursor !== undefined){
const _errs3 = errors;
if(!(validate2282(data.cursor, {instancePath:instancePath+"/cursor",parentData:data,parentDataProperty:"cursor",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2282.errors : vErrors.concat(validate2282.errors);
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
validate2302.errors = [{}];
return false;
}
}
validate2302.errors = vErrors;
return errors === 0;
}
validate2302.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema628 = {"type":"object","additionalProperties":false,"properties":{"namespace":{"$ref":"#/$defs/CatalogRequest/$defs/T7"},"name":{"$ref":"#/$defs/CatalogRequest/$defs/T6"},"expected":{"$ref":"#/$defs/CatalogRequest/$defs/T21"}},"required":["namespace","name","expected"]};

function validate2306(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2306.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((((data.namespace === undefined) && (missing0 = "namespace")) || ((data.name === undefined) && (missing0 = "name"))) || ((data.expected === undefined) && (missing0 = "expected"))){
validate2306.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "namespace") || (key0 === "name")) || (key0 === "expected"))){
validate2306.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.namespace !== undefined){
const _errs2 = errors;
if(!(validate2187(data.namespace, {instancePath:instancePath+"/namespace",parentData:data,parentDataProperty:"namespace",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2187.errors : vErrors.concat(validate2187.errors);
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
if(!(validate2185(data.name, {instancePath:instancePath+"/name",parentData:data,parentDataProperty:"name",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2185.errors : vErrors.concat(validate2185.errors);
errors = vErrors.length;
}
var valid0 = _errs3 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.expected !== undefined){
const _errs4 = errors;
if(!(validate2240(data.expected, {instancePath:instancePath+"/expected",parentData:data,parentDataProperty:"expected",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2240.errors : vErrors.concat(validate2240.errors);
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
validate2306.errors = [{}];
return false;
}
}
validate2306.errors = vErrors;
return errors === 0;
}
validate2306.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema629 = {"type":"object","additionalProperties":false,"properties":{"definition":{"$ref":"#/$defs/CatalogRequest/$defs/T1"},"connection":{"$ref":"#/$defs/CatalogRequest/$defs/T29"},"namespace":{"$ref":"#/$defs/CatalogRequest/$defs/T7"},"name":{"$ref":"#/$defs/CatalogRequest/$defs/T6"},"interpretation":{"$ref":"#/$defs/CatalogRequest/$defs/T39"}},"required":["definition","connection","namespace","name","interpretation"]};
const schema630 = {"type":"object","additionalProperties":false,"properties":{"interpretation":{"$ref":"#/$defs/CatalogRequest/$defs/T21"},"content":{"$ref":"#/$defs/CatalogRequest/$defs/T13"},"schema_fingerprint":{"$ref":"#/$defs/CatalogRequest/$defs/T6"},"retired":{"$ref":"#/$defs/CatalogRequest/$defs/T40"}},"required":["interpretation","content","schema_fingerprint","retired"]};
const schema631 = {"type":"boolean"};

function validate2320(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2320.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "boolean"){
validate2320.errors = [{}];
return false;
}
validate2320.errors = vErrors;
return errors === 0;
}
validate2320.evaluated = {"dynamicProps":false,"dynamicItems":false};


function validate2316(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2316.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if(((((data.interpretation === undefined) && (missing0 = "interpretation")) || ((data.content === undefined) && (missing0 = "content"))) || ((data.schema_fingerprint === undefined) && (missing0 = "schema_fingerprint"))) || ((data.retired === undefined) && (missing0 = "retired"))){
validate2316.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((((key0 === "interpretation") || (key0 === "content")) || (key0 === "schema_fingerprint")) || (key0 === "retired"))){
validate2316.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.interpretation !== undefined){
const _errs2 = errors;
if(!(validate2240(data.interpretation, {instancePath:instancePath+"/interpretation",parentData:data,parentDataProperty:"interpretation",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2240.errors : vErrors.concat(validate2240.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.content !== undefined){
const _errs3 = errors;
if(!(validate2203(data.content, {instancePath:instancePath+"/content",parentData:data,parentDataProperty:"content",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2203.errors : vErrors.concat(validate2203.errors);
errors = vErrors.length;
}
var valid0 = _errs3 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.schema_fingerprint !== undefined){
const _errs4 = errors;
if(!(validate2185(data.schema_fingerprint, {instancePath:instancePath+"/schema_fingerprint",parentData:data,parentDataProperty:"schema_fingerprint",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2185.errors : vErrors.concat(validate2185.errors);
errors = vErrors.length;
}
var valid0 = _errs4 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.retired !== undefined){
const _errs5 = errors;
if(!(validate2320(data.retired, {instancePath:instancePath+"/retired",parentData:data,parentDataProperty:"retired",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2320.errors : vErrors.concat(validate2320.errors);
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
validate2316.errors = [{}];
return false;
}
}
validate2316.errors = vErrors;
return errors === 0;
}
validate2316.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate2311(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2311.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((((((data.definition === undefined) && (missing0 = "definition")) || ((data.connection === undefined) && (missing0 = "connection"))) || ((data.namespace === undefined) && (missing0 = "namespace"))) || ((data.name === undefined) && (missing0 = "name"))) || ((data.interpretation === undefined) && (missing0 = "interpretation"))){
validate2311.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((((key0 === "definition") || (key0 === "connection")) || (key0 === "namespace")) || (key0 === "name")) || (key0 === "interpretation"))){
validate2311.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.definition !== undefined){
const _errs2 = errors;
if(!(validate2178(data.definition, {instancePath:instancePath+"/definition",parentData:data,parentDataProperty:"definition",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2178.errors : vErrors.concat(validate2178.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.connection !== undefined){
const _errs3 = errors;
if(!(validate2266(data.connection, {instancePath:instancePath+"/connection",parentData:data,parentDataProperty:"connection",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2266.errors : vErrors.concat(validate2266.errors);
errors = vErrors.length;
}
var valid0 = _errs3 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.namespace !== undefined){
const _errs4 = errors;
if(!(validate2187(data.namespace, {instancePath:instancePath+"/namespace",parentData:data,parentDataProperty:"namespace",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2187.errors : vErrors.concat(validate2187.errors);
errors = vErrors.length;
}
var valid0 = _errs4 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.name !== undefined){
const _errs5 = errors;
if(!(validate2185(data.name, {instancePath:instancePath+"/name",parentData:data,parentDataProperty:"name",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2185.errors : vErrors.concat(validate2185.errors);
errors = vErrors.length;
}
var valid0 = _errs5 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.interpretation !== undefined){
const _errs6 = errors;
if(!(validate2316(data.interpretation, {instancePath:instancePath+"/interpretation",parentData:data,parentDataProperty:"interpretation",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2316.errors : vErrors.concat(validate2316.errors);
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
validate2311.errors = [{}];
return false;
}
}
validate2311.errors = vErrors;
return errors === 0;
}
validate2311.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema632 = {"type":"object","additionalProperties":false,"properties":{"selection":{"$ref":"#/$defs/CatalogRequest/$defs/T42"},"authority":{"$ref":"#/$defs/CatalogRequest/$defs/T43"},"cursor":{"$ref":"#/$defs/CatalogRequest/$defs/T44"}},"required":["selection","authority","cursor"]};
const schema633 = {"oneOf":[{"type":"object","additionalProperties":false,"required":["dependents"],"properties":{"dependents":{"$ref":"#/$defs/CatalogRequest/$defs/T22"}}},{"type":"object","additionalProperties":false,"required":["dependencies"],"properties":{"dependencies":{"$ref":"#/$defs/CatalogRequest/$defs/T22"}}}]};

function validate2325(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2325.evaluated;
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
if((data.dependents === undefined) && (missing0 = "dependents")){
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
const _errs3 = errors;
for(const key0 in data){
if(!(key0 === "dependents")){
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
if(_errs3 === errors){
if(data.dependents !== undefined){
if(!(validate2241(data.dependents, {instancePath:instancePath+"/dependents",parentData:data,parentDataProperty:"dependents",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2241.errors : vErrors.concat(validate2241.errors);
errors = vErrors.length;
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
var _valid0 = _errs1 === errors;
if(_valid0){
valid0 = true;
passing0 = 0;
var props0 = true;
}
const _errs5 = errors;
if(errors === _errs5){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing1;
if((data.dependencies === undefined) && (missing1 = "dependencies")){
const err3 = {};
if(vErrors === null){
vErrors = [err3];
}
else {
vErrors.push(err3);
}
errors++;
}
else {
const _errs7 = errors;
for(const key1 in data){
if(!(key1 === "dependencies")){
const err4 = {};
if(vErrors === null){
vErrors = [err4];
}
else {
vErrors.push(err4);
}
errors++;
break;
}
}
if(_errs7 === errors){
if(data.dependencies !== undefined){
if(!(validate2241(data.dependencies, {instancePath:instancePath+"/dependencies",parentData:data,parentDataProperty:"dependencies",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2241.errors : vErrors.concat(validate2241.errors);
errors = vErrors.length;
}
}
}
}
}
else {
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
var _valid0 = _errs5 === errors;
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
}
if(!valid0){
const err6 = {};
if(vErrors === null){
vErrors = [err6];
}
else {
vErrors.push(err6);
}
errors++;
validate2325.errors = vErrors;
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
validate2325.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate2325.evaluated = {"dynamicProps":true,"dynamicItems":false};

const schema634 = {"type":"string","enum":["dependent","catalog_administrator"]};

function validate2330(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2330.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate2330.errors = [{}];
return false;
}
if(!((data === "dependent") || (data === "catalog_administrator"))){
validate2330.errors = [{}];
return false;
}
validate2330.errors = vErrors;
return errors === 0;
}
validate2330.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema636 = {"anyOf":[{"$ref":"#/$defs/CatalogRequest/$defs/T45"},{"type":"null"}]};
const schema637 = {"type":"object","additionalProperties":false,"properties":{"definition":{"$ref":"#/$defs/CatalogRequest/$defs/T1"},"connection":{"$ref":"#/$defs/CatalogRequest/$defs/T29"},"selection":{"$ref":"#/$defs/CatalogRequest/$defs/T42"},"authority":{"$ref":"#/$defs/CatalogRequest/$defs/T43"},"position":{"$ref":"#/$defs/CatalogRequest/$defs/T34"},"after":{"$ref":"#/$defs/CatalogRequest/$defs/T6"}},"required":["definition","connection","selection","authority","position","after"]};

function validate2333(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2333.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if(((((((data.definition === undefined) && (missing0 = "definition")) || ((data.connection === undefined) && (missing0 = "connection"))) || ((data.selection === undefined) && (missing0 = "selection"))) || ((data.authority === undefined) && (missing0 = "authority"))) || ((data.position === undefined) && (missing0 = "position"))) || ((data.after === undefined) && (missing0 = "after"))){
validate2333.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((((((key0 === "definition") || (key0 === "connection")) || (key0 === "selection")) || (key0 === "authority")) || (key0 === "position")) || (key0 === "after"))){
validate2333.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.definition !== undefined){
const _errs2 = errors;
if(!(validate2178(data.definition, {instancePath:instancePath+"/definition",parentData:data,parentDataProperty:"definition",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2178.errors : vErrors.concat(validate2178.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.connection !== undefined){
const _errs3 = errors;
if(!(validate2266(data.connection, {instancePath:instancePath+"/connection",parentData:data,parentDataProperty:"connection",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2266.errors : vErrors.concat(validate2266.errors);
errors = vErrors.length;
}
var valid0 = _errs3 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.selection !== undefined){
const _errs4 = errors;
if(!(validate2325(data.selection, {instancePath:instancePath+"/selection",parentData:data,parentDataProperty:"selection",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2325.errors : vErrors.concat(validate2325.errors);
errors = vErrors.length;
}
var valid0 = _errs4 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.authority !== undefined){
const _errs5 = errors;
if(!(validate2330(data.authority, {instancePath:instancePath+"/authority",parentData:data,parentDataProperty:"authority",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2330.errors : vErrors.concat(validate2330.errors);
errors = vErrors.length;
}
var valid0 = _errs5 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.position !== undefined){
const _errs6 = errors;
if(!(validate2291(data.position, {instancePath:instancePath+"/position",parentData:data,parentDataProperty:"position",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2291.errors : vErrors.concat(validate2291.errors);
errors = vErrors.length;
}
var valid0 = _errs6 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.after !== undefined){
const _errs7 = errors;
if(!(validate2185(data.after, {instancePath:instancePath+"/after",parentData:data,parentDataProperty:"after",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2185.errors : vErrors.concat(validate2185.errors);
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
validate2333.errors = [{}];
return false;
}
}
validate2333.errors = vErrors;
return errors === 0;
}
validate2333.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate2332(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2332.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate2333(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2333.errors : vErrors.concat(validate2333.errors);
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
validate2332.errors = vErrors;
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
validate2332.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate2332.evaluated = {"dynamicProps":true,"dynamicItems":false};


function validate2324(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2324.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((((data.selection === undefined) && (missing0 = "selection")) || ((data.authority === undefined) && (missing0 = "authority"))) || ((data.cursor === undefined) && (missing0 = "cursor"))){
validate2324.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "selection") || (key0 === "authority")) || (key0 === "cursor"))){
validate2324.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.selection !== undefined){
const _errs2 = errors;
if(!(validate2325(data.selection, {instancePath:instancePath+"/selection",parentData:data,parentDataProperty:"selection",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2325.errors : vErrors.concat(validate2325.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.authority !== undefined){
const _errs3 = errors;
if(!(validate2330(data.authority, {instancePath:instancePath+"/authority",parentData:data,parentDataProperty:"authority",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2330.errors : vErrors.concat(validate2330.errors);
errors = vErrors.length;
}
var valid0 = _errs3 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.cursor !== undefined){
const _errs4 = errors;
if(!(validate2332(data.cursor, {instancePath:instancePath+"/cursor",parentData:data,parentDataProperty:"cursor",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2332.errors : vErrors.concat(validate2332.errors);
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
validate2324.errors = [{}];
return false;
}
}
validate2324.errors = vErrors;
return errors === 0;
}
validate2324.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate2180(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2180.evaluated;
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
const _errs3 = errors;
for(const key0 in data){
if(!(key0 === "describe")){
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
if(_errs3 === errors){
if(data.describe !== undefined){
if(!(validate2181(data.describe, {instancePath:instancePath+"/describe",parentData:data,parentDataProperty:"describe",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2181.errors : vErrors.concat(validate2181.errors);
errors = vErrors.length;
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
var _valid0 = _errs1 === errors;
if(_valid0){
valid0 = true;
passing0 = 0;
var props0 = true;
}
const _errs5 = errors;
if(errors === _errs5){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing1;
if((data.history === undefined) && (missing1 = "history")){
const err3 = {};
if(vErrors === null){
vErrors = [err3];
}
else {
vErrors.push(err3);
}
errors++;
}
else {
const _errs7 = errors;
for(const key1 in data){
if(!(key1 === "history")){
const err4 = {};
if(vErrors === null){
vErrors = [err4];
}
else {
vErrors.push(err4);
}
errors++;
break;
}
}
if(_errs7 === errors){
if(data.history !== undefined){
if(!(validate2183(data.history, {instancePath:instancePath+"/history",parentData:data,parentDataProperty:"history",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2183.errors : vErrors.concat(validate2183.errors);
errors = vErrors.length;
}
}
}
}
}
else {
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
var _valid0 = _errs5 === errors;
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
const _errs9 = errors;
if(errors === _errs9){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing2;
if((data.definitions === undefined) && (missing2 = "definitions")){
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
const _errs11 = errors;
for(const key2 in data){
if(!(key2 === "definitions")){
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
if(_errs11 === errors){
if(data.definitions !== undefined){
if(!(validate2235(data.definitions, {instancePath:instancePath+"/definitions",parentData:data,parentDataProperty:"definitions",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2235.errors : vErrors.concat(validate2235.errors);
errors = vErrors.length;
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
var _valid0 = _errs9 === errors;
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
const _errs13 = errors;
if(errors === _errs13){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing3;
if((data.namespaces === undefined) && (missing3 = "namespaces")){
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
const _errs15 = errors;
for(const key3 in data){
if(!(key3 === "namespaces")){
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
if(_errs15 === errors){
if(data.namespaces !== undefined){
if(!(validate2282(data.namespaces, {instancePath:instancePath+"/namespaces",parentData:data,parentDataProperty:"namespaces",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2282.errors : vErrors.concat(validate2282.errors);
errors = vErrors.length;
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
var _valid0 = _errs13 === errors;
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
const _errs17 = errors;
if(errors === _errs17){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing4;
if((data.tables === undefined) && (missing4 = "tables")){
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
const _errs19 = errors;
for(const key4 in data){
if(!(key4 === "tables")){
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
if(_errs19 === errors){
if(data.tables !== undefined){
if(!(validate2298(data.tables, {instancePath:instancePath+"/tables",parentData:data,parentDataProperty:"tables",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2298.errors : vErrors.concat(validate2298.errors);
errors = vErrors.length;
}
}
}
}
}
else {
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
var _valid0 = _errs17 === errors;
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
const _errs21 = errors;
if(errors === _errs21){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing5;
if((data.resources === undefined) && (missing5 = "resources")){
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
const _errs23 = errors;
for(const key5 in data){
if(!(key5 === "resources")){
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
if(_errs23 === errors){
if(data.resources !== undefined){
if(!(validate2302(data.resources, {instancePath:instancePath+"/resources",parentData:data,parentDataProperty:"resources",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2302.errors : vErrors.concat(validate2302.errors);
errors = vErrors.length;
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
var _valid0 = _errs21 === errors;
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
const _errs25 = errors;
if(errors === _errs25){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing6;
if((data.table === undefined) && (missing6 = "table")){
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
const _errs27 = errors;
for(const key6 in data){
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
if(_errs27 === errors){
if(data.table !== undefined){
if(!(validate2306(data.table, {instancePath:instancePath+"/table",parentData:data,parentDataProperty:"table",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2306.errors : vErrors.concat(validate2306.errors);
errors = vErrors.length;
}
}
}
}
}
else {
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
var _valid0 = _errs25 === errors;
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
const _errs29 = errors;
if(errors === _errs29){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing7;
if((data.storage === undefined) && (missing7 = "storage")){
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
const _errs31 = errors;
for(const key7 in data){
if(!(key7 === "storage")){
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
if(_errs31 === errors){
if(data.storage !== undefined){
if(!(validate2311(data.storage, {instancePath:instancePath+"/storage",parentData:data,parentDataProperty:"storage",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2311.errors : vErrors.concat(validate2311.errors);
errors = vErrors.length;
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
var _valid0 = _errs29 === errors;
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
const _errs33 = errors;
if(errors === _errs33){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing8;
if((data.dependencies === undefined) && (missing8 = "dependencies")){
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
const _errs35 = errors;
for(const key8 in data){
if(!(key8 === "dependencies")){
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
if(_errs35 === errors){
if(data.dependencies !== undefined){
if(!(validate2324(data.dependencies, {instancePath:instancePath+"/dependencies",parentData:data,parentDataProperty:"dependencies",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2324.errors : vErrors.concat(validate2324.errors);
errors = vErrors.length;
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
var _valid0 = _errs33 === errors;
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
}
}
}
}
}
}
}
}
if(!valid0){
const err27 = {};
if(vErrors === null){
vErrors = [err27];
}
else {
vErrors.push(err27);
}
errors++;
validate2180.errors = vErrors;
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
validate2180.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate2180.evaluated = {"dynamicProps":true,"dynamicItems":false};


function validate2177(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2177.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if(((data.definition === undefined) && (missing0 = "definition")) || ((data.action === undefined) && (missing0 = "action"))){
validate2177.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "definition") || (key0 === "action"))){
validate2177.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.definition !== undefined){
const _errs2 = errors;
if(!(validate2178(data.definition, {instancePath:instancePath+"/definition",parentData:data,parentDataProperty:"definition",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2178.errors : vErrors.concat(validate2178.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.action !== undefined){
const _errs3 = errors;
if(!(validate2180(data.action, {instancePath:instancePath+"/action",parentData:data,parentDataProperty:"action",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2180.errors : vErrors.concat(validate2180.errors);
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
validate2177.errors = [{}];
return false;
}
}
validate2177.errors = vErrors;
return errors === 0;
}
validate2177.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

export const CatalogResponse = validate2344;
const schema638 = {"oneOf":[{"type":"object","additionalProperties":false,"required":["catalog"],"properties":{"catalog":{"$ref":"#/$defs/CatalogResponse/$defs/T1"}}},{"type":"object","additionalProperties":false,"required":["history"],"properties":{"history":{"$ref":"#/$defs/CatalogResponse/$defs/T34"}}},{"type":"object","additionalProperties":false,"required":["definitions"],"properties":{"definitions":{"$ref":"#/$defs/CatalogResponse/$defs/T198"}}},{"type":"object","additionalProperties":false,"required":["resources"],"properties":{"resources":{"$ref":"#/$defs/CatalogResponse/$defs/T248"}}},{"type":"object","additionalProperties":false,"required":["table"],"properties":{"table":{"$ref":"#/$defs/CatalogResponse/$defs/T258"}}},{"type":"object","additionalProperties":false,"required":["storage"],"properties":{"storage":{"$ref":"#/$defs/CatalogResponse/$defs/T261"}}},{"type":"object","additionalProperties":false,"required":["dependencies"],"properties":{"dependencies":{"$ref":"#/$defs/CatalogResponse/$defs/T263"}}}]};
const schema639 = {"oneOf":[{"type":"object","additionalProperties":false,"required":["capabilities"],"properties":{"capabilities":{"$ref":"#/$defs/CatalogResponse/$defs/T2"}}},{"type":"object","additionalProperties":false,"required":["description"],"properties":{"description":{"$ref":"#/$defs/CatalogResponse/$defs/T7"}}},{"type":"object","additionalProperties":false,"required":["namespace"],"properties":{"namespace":{"$ref":"#/$defs/CatalogResponse/$defs/T15"}}},{"type":"object","additionalProperties":false,"required":["namespaces"],"properties":{"namespaces":{"$ref":"#/$defs/CatalogResponse/$defs/T18"}}},{"type":"object","additionalProperties":false,"required":["tables"],"properties":{"tables":{"$ref":"#/$defs/CatalogResponse/$defs/T27"}}}]};
const schema640 = {"type":"object","additionalProperties":false,"properties":{"version":{"$ref":"#/$defs/CatalogResponse/$defs/T3"},"definition":{"$ref":"#/$defs/CatalogResponse/$defs/T4"},"max_columns":{"$ref":"#/$defs/CatalogResponse/$defs/T5"},"max_rows":{"$ref":"#/$defs/CatalogResponse/$defs/T5"},"max_sql_bytes":{"$ref":"#/$defs/CatalogResponse/$defs/T5"},"max_intent_bytes":{"$ref":"#/$defs/CatalogResponse/$defs/T6"},"max_action_bytes":{"$ref":"#/$defs/CatalogResponse/$defs/T6"},"metadata_page_entries":{"$ref":"#/$defs/CatalogResponse/$defs/T3"},"resident_intents":{"$ref":"#/$defs/CatalogResponse/$defs/T3"}},"required":["version","definition","max_columns","max_rows","max_sql_bytes","max_intent_bytes","max_action_bytes","metadata_page_entries","resident_intents"]};
const func1 = Object.prototype.hasOwnProperty;
const schema58 = {"type":"integer","minimum":0,"maximum":255};

function validate2347(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2347.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(!(((typeof data == "number") && (!(data % 1) && !isNaN(data))) && (isFinite(data)))){
validate2347.errors = [{}];
return false;
}
if(errors === 0){
if((typeof data == "number") && (isFinite(data))){
if(data > 255 || isNaN(data)){
validate2347.errors = [{}];
return false;
}
else {
if(data < 0 || isNaN(data)){
validate2347.errors = [{}];
return false;
}
}
}
}
validate2347.errors = vErrors;
return errors === 0;
}
validate2347.evaluated = {"dynamicProps":false,"dynamicItems":false};


function validate2349(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2349.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate2349.errors = [{}];
return false;
}
if(!(data === "6da8e815dec26c458515e34fb6553654d57c77536f652b9258897bf1a513842e")){
validate2349.errors = [{}];
return false;
}
validate2349.errors = vErrors;
return errors === 0;
}
validate2349.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema67 = {"type":"integer","minimum":0,"maximum":65535};

function validate2351(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2351.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(!(((typeof data == "number") && (!(data % 1) && !isNaN(data))) && (isFinite(data)))){
validate2351.errors = [{}];
return false;
}
if(errors === 0){
if((typeof data == "number") && (isFinite(data))){
if(data > 65535 || isNaN(data)){
validate2351.errors = [{}];
return false;
}
else {
if(data < 0 || isNaN(data)){
validate2351.errors = [{}];
return false;
}
}
}
}
validate2351.errors = vErrors;
return errors === 0;
}
validate2351.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema24 = {"type":"integer","minimum":0,"maximum":4294967295};

function validate2355(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2355.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(!(((typeof data == "number") && (!(data % 1) && !isNaN(data))) && (isFinite(data)))){
validate2355.errors = [{}];
return false;
}
if(errors === 0){
if((typeof data == "number") && (isFinite(data))){
if(data > 4294967295 || isNaN(data)){
validate2355.errors = [{}];
return false;
}
else {
if(data < 0 || isNaN(data)){
validate2355.errors = [{}];
return false;
}
}
}
}
validate2355.errors = vErrors;
return errors === 0;
}
validate2355.evaluated = {"dynamicProps":false,"dynamicItems":false};


function validate2346(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2346.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((((((((((data.version === undefined) && (missing0 = "version")) || ((data.definition === undefined) && (missing0 = "definition"))) || ((data.max_columns === undefined) && (missing0 = "max_columns"))) || ((data.max_rows === undefined) && (missing0 = "max_rows"))) || ((data.max_sql_bytes === undefined) && (missing0 = "max_sql_bytes"))) || ((data.max_intent_bytes === undefined) && (missing0 = "max_intent_bytes"))) || ((data.max_action_bytes === undefined) && (missing0 = "max_action_bytes"))) || ((data.metadata_page_entries === undefined) && (missing0 = "metadata_page_entries"))) || ((data.resident_intents === undefined) && (missing0 = "resident_intents"))){
validate2346.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(func1.call(schema640.properties, key0))){
validate2346.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.version !== undefined){
const _errs2 = errors;
if(!(validate2347(data.version, {instancePath:instancePath+"/version",parentData:data,parentDataProperty:"version",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2347.errors : vErrors.concat(validate2347.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.definition !== undefined){
const _errs3 = errors;
if(!(validate2349(data.definition, {instancePath:instancePath+"/definition",parentData:data,parentDataProperty:"definition",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2349.errors : vErrors.concat(validate2349.errors);
errors = vErrors.length;
}
var valid0 = _errs3 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.max_columns !== undefined){
const _errs4 = errors;
if(!(validate2351(data.max_columns, {instancePath:instancePath+"/max_columns",parentData:data,parentDataProperty:"max_columns",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2351.errors : vErrors.concat(validate2351.errors);
errors = vErrors.length;
}
var valid0 = _errs4 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.max_rows !== undefined){
const _errs5 = errors;
if(!(validate2351(data.max_rows, {instancePath:instancePath+"/max_rows",parentData:data,parentDataProperty:"max_rows",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2351.errors : vErrors.concat(validate2351.errors);
errors = vErrors.length;
}
var valid0 = _errs5 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.max_sql_bytes !== undefined){
const _errs6 = errors;
if(!(validate2351(data.max_sql_bytes, {instancePath:instancePath+"/max_sql_bytes",parentData:data,parentDataProperty:"max_sql_bytes",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2351.errors : vErrors.concat(validate2351.errors);
errors = vErrors.length;
}
var valid0 = _errs6 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.max_intent_bytes !== undefined){
const _errs7 = errors;
if(!(validate2355(data.max_intent_bytes, {instancePath:instancePath+"/max_intent_bytes",parentData:data,parentDataProperty:"max_intent_bytes",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2355.errors : vErrors.concat(validate2355.errors);
errors = vErrors.length;
}
var valid0 = _errs7 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.max_action_bytes !== undefined){
const _errs8 = errors;
if(!(validate2355(data.max_action_bytes, {instancePath:instancePath+"/max_action_bytes",parentData:data,parentDataProperty:"max_action_bytes",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2355.errors : vErrors.concat(validate2355.errors);
errors = vErrors.length;
}
var valid0 = _errs8 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.metadata_page_entries !== undefined){
const _errs9 = errors;
if(!(validate2347(data.metadata_page_entries, {instancePath:instancePath+"/metadata_page_entries",parentData:data,parentDataProperty:"metadata_page_entries",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2347.errors : vErrors.concat(validate2347.errors);
errors = vErrors.length;
}
var valid0 = _errs9 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.resident_intents !== undefined){
const _errs10 = errors;
if(!(validate2347(data.resident_intents, {instancePath:instancePath+"/resident_intents",parentData:data,parentDataProperty:"resident_intents",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2347.errors : vErrors.concat(validate2347.errors);
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
validate2346.errors = [{}];
return false;
}
}
validate2346.errors = vErrors;
return errors === 0;
}
validate2346.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema645 = {"type":"object","additionalProperties":false,"properties":{"configuration":{"$ref":"#/$defs/CatalogResponse/$defs/T8"},"subject":{"$ref":"#/$defs/CatalogResponse/$defs/T13"},"policy_revision":{"$ref":"#/$defs/CatalogResponse/$defs/T10"}},"required":["configuration","subject","policy_revision"]};
const schema646 = {"type":"object","additionalProperties":false,"properties":{"scope":{"$ref":"#/$defs/CatalogResponse/$defs/T9"},"branch":{"$ref":"#/$defs/CatalogResponse/$defs/T11"},"partition":{"$ref":"#/$defs/CatalogResponse/$defs/T11"},"audience":{"$ref":"#/$defs/CatalogResponse/$defs/T10"},"authority":{"$ref":"#/$defs/CatalogResponse/$defs/T12"},"database_name":{"$ref":"#/$defs/CatalogResponse/$defs/T11"},"initial_schema_name":{"$ref":"#/$defs/CatalogResponse/$defs/T11"}},"required":["scope","branch","partition","audience","authority","database_name","initial_schema_name"]};
const schema647 = {"type":"object","additionalProperties":false,"properties":{"realm":{"$ref":"#/$defs/CatalogResponse/$defs/T10"},"resource":{"$ref":"#/$defs/CatalogResponse/$defs/T10"},"catalog":{"$ref":"#/$defs/CatalogResponse/$defs/T11"}},"required":["realm","resource","catalog"]};

function validate2364(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2364.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(!(((typeof data == "number") && (!(data % 1) && !isNaN(data))) && (isFinite(data)))){
validate2364.errors = [{}];
return false;
}
if(errors === 0){
if((typeof data == "number") && (isFinite(data))){
if(data > 9007199254740991 || isNaN(data)){
validate2364.errors = [{}];
return false;
}
else {
if(data < 0 || isNaN(data)){
validate2364.errors = [{}];
return false;
}
}
}
}
validate2364.errors = vErrors;
return errors === 0;
}
validate2364.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema649 = {"type":"string","maxLength":262144};

function validate2367(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2367.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(typeof data === "string"){
if(func3(data) > 262144){
validate2367.errors = [{}];
return false;
}
}
else {
validate2367.errors = [{}];
return false;
}
}
validate2367.errors = vErrors;
return errors === 0;
}
validate2367.evaluated = {"dynamicProps":false,"dynamicItems":false};


function validate2363(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2363.evaluated;
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
validate2363.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "realm") || (key0 === "resource")) || (key0 === "catalog"))){
validate2363.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.realm !== undefined){
const _errs2 = errors;
if(!(validate2364(data.realm, {instancePath:instancePath+"/realm",parentData:data,parentDataProperty:"realm",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2364.errors : vErrors.concat(validate2364.errors);
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
if(!(validate2364(data.resource, {instancePath:instancePath+"/resource",parentData:data,parentDataProperty:"resource",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2364.errors : vErrors.concat(validate2364.errors);
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
if(!(validate2367(data.catalog, {instancePath:instancePath+"/catalog",parentData:data,parentDataProperty:"catalog",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2367.errors : vErrors.concat(validate2367.errors);
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
validate2363.errors = [{}];
return false;
}
}
validate2363.errors = vErrors;
return errors === 0;
}
validate2363.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema650 = {"type":"object","additionalProperties":false,"properties":{"database_domain":{"$ref":"#/$defs/CatalogResponse/$defs/T10"},"schema_domain":{"$ref":"#/$defs/CatalogResponse/$defs/T10"},"table_domain":{"$ref":"#/$defs/CatalogResponse/$defs/T10"},"stream_domain":{"$ref":"#/$defs/CatalogResponse/$defs/T10"},"queue_domain":{"$ref":"#/$defs/CatalogResponse/$defs/T10"},"kv_domain":{"$ref":"#/$defs/CatalogResponse/$defs/T10"},"connection_domain":{"$ref":"#/$defs/CatalogResponse/$defs/T10"},"source_domain":{"$ref":"#/$defs/CatalogResponse/$defs/T10"},"sink_domain":{"$ref":"#/$defs/CatalogResponse/$defs/T10"},"database":{"$ref":"#/$defs/CatalogResponse/$defs/T10"},"initial_schema":{"$ref":"#/$defs/CatalogResponse/$defs/T10"},"initial_schema_authority":{"$ref":"#/$defs/CatalogResponse/$defs/T10"}},"required":["database_domain","schema_domain","table_domain","stream_domain","queue_domain","kv_domain","connection_domain","source_domain","sink_domain","database","initial_schema","initial_schema_authority"]};

function validate2373(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2373.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if(((((((((((((data.database_domain === undefined) && (missing0 = "database_domain")) || ((data.schema_domain === undefined) && (missing0 = "schema_domain"))) || ((data.table_domain === undefined) && (missing0 = "table_domain"))) || ((data.stream_domain === undefined) && (missing0 = "stream_domain"))) || ((data.queue_domain === undefined) && (missing0 = "queue_domain"))) || ((data.kv_domain === undefined) && (missing0 = "kv_domain"))) || ((data.connection_domain === undefined) && (missing0 = "connection_domain"))) || ((data.source_domain === undefined) && (missing0 = "source_domain"))) || ((data.sink_domain === undefined) && (missing0 = "sink_domain"))) || ((data.database === undefined) && (missing0 = "database"))) || ((data.initial_schema === undefined) && (missing0 = "initial_schema"))) || ((data.initial_schema_authority === undefined) && (missing0 = "initial_schema_authority"))){
validate2373.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(func1.call(schema650.properties, key0))){
validate2373.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.database_domain !== undefined){
const _errs2 = errors;
if(!(validate2364(data.database_domain, {instancePath:instancePath+"/database_domain",parentData:data,parentDataProperty:"database_domain",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2364.errors : vErrors.concat(validate2364.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.schema_domain !== undefined){
const _errs3 = errors;
if(!(validate2364(data.schema_domain, {instancePath:instancePath+"/schema_domain",parentData:data,parentDataProperty:"schema_domain",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2364.errors : vErrors.concat(validate2364.errors);
errors = vErrors.length;
}
var valid0 = _errs3 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.table_domain !== undefined){
const _errs4 = errors;
if(!(validate2364(data.table_domain, {instancePath:instancePath+"/table_domain",parentData:data,parentDataProperty:"table_domain",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2364.errors : vErrors.concat(validate2364.errors);
errors = vErrors.length;
}
var valid0 = _errs4 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.stream_domain !== undefined){
const _errs5 = errors;
if(!(validate2364(data.stream_domain, {instancePath:instancePath+"/stream_domain",parentData:data,parentDataProperty:"stream_domain",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2364.errors : vErrors.concat(validate2364.errors);
errors = vErrors.length;
}
var valid0 = _errs5 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.queue_domain !== undefined){
const _errs6 = errors;
if(!(validate2364(data.queue_domain, {instancePath:instancePath+"/queue_domain",parentData:data,parentDataProperty:"queue_domain",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2364.errors : vErrors.concat(validate2364.errors);
errors = vErrors.length;
}
var valid0 = _errs6 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.kv_domain !== undefined){
const _errs7 = errors;
if(!(validate2364(data.kv_domain, {instancePath:instancePath+"/kv_domain",parentData:data,parentDataProperty:"kv_domain",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2364.errors : vErrors.concat(validate2364.errors);
errors = vErrors.length;
}
var valid0 = _errs7 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.connection_domain !== undefined){
const _errs8 = errors;
if(!(validate2364(data.connection_domain, {instancePath:instancePath+"/connection_domain",parentData:data,parentDataProperty:"connection_domain",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2364.errors : vErrors.concat(validate2364.errors);
errors = vErrors.length;
}
var valid0 = _errs8 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.source_domain !== undefined){
const _errs9 = errors;
if(!(validate2364(data.source_domain, {instancePath:instancePath+"/source_domain",parentData:data,parentDataProperty:"source_domain",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2364.errors : vErrors.concat(validate2364.errors);
errors = vErrors.length;
}
var valid0 = _errs9 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.sink_domain !== undefined){
const _errs10 = errors;
if(!(validate2364(data.sink_domain, {instancePath:instancePath+"/sink_domain",parentData:data,parentDataProperty:"sink_domain",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2364.errors : vErrors.concat(validate2364.errors);
errors = vErrors.length;
}
var valid0 = _errs10 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.database !== undefined){
const _errs11 = errors;
if(!(validate2364(data.database, {instancePath:instancePath+"/database",parentData:data,parentDataProperty:"database",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2364.errors : vErrors.concat(validate2364.errors);
errors = vErrors.length;
}
var valid0 = _errs11 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.initial_schema !== undefined){
const _errs12 = errors;
if(!(validate2364(data.initial_schema, {instancePath:instancePath+"/initial_schema",parentData:data,parentDataProperty:"initial_schema",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2364.errors : vErrors.concat(validate2364.errors);
errors = vErrors.length;
}
var valid0 = _errs12 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.initial_schema_authority !== undefined){
const _errs13 = errors;
if(!(validate2364(data.initial_schema_authority, {instancePath:instancePath+"/initial_schema_authority",parentData:data,parentDataProperty:"initial_schema_authority",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2364.errors : vErrors.concat(validate2364.errors);
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
validate2373.errors = [{}];
return false;
}
}
validate2373.errors = vErrors;
return errors === 0;
}
validate2373.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate2362(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2362.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((((((((data.scope === undefined) && (missing0 = "scope")) || ((data.branch === undefined) && (missing0 = "branch"))) || ((data.partition === undefined) && (missing0 = "partition"))) || ((data.audience === undefined) && (missing0 = "audience"))) || ((data.authority === undefined) && (missing0 = "authority"))) || ((data.database_name === undefined) && (missing0 = "database_name"))) || ((data.initial_schema_name === undefined) && (missing0 = "initial_schema_name"))){
validate2362.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((((((key0 === "scope") || (key0 === "branch")) || (key0 === "partition")) || (key0 === "audience")) || (key0 === "authority")) || (key0 === "database_name")) || (key0 === "initial_schema_name"))){
validate2362.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.scope !== undefined){
const _errs2 = errors;
if(!(validate2363(data.scope, {instancePath:instancePath+"/scope",parentData:data,parentDataProperty:"scope",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2363.errors : vErrors.concat(validate2363.errors);
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
if(!(validate2367(data.branch, {instancePath:instancePath+"/branch",parentData:data,parentDataProperty:"branch",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2367.errors : vErrors.concat(validate2367.errors);
errors = vErrors.length;
}
var valid0 = _errs3 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.partition !== undefined){
const _errs4 = errors;
if(!(validate2367(data.partition, {instancePath:instancePath+"/partition",parentData:data,parentDataProperty:"partition",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2367.errors : vErrors.concat(validate2367.errors);
errors = vErrors.length;
}
var valid0 = _errs4 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.audience !== undefined){
const _errs5 = errors;
if(!(validate2364(data.audience, {instancePath:instancePath+"/audience",parentData:data,parentDataProperty:"audience",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2364.errors : vErrors.concat(validate2364.errors);
errors = vErrors.length;
}
var valid0 = _errs5 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.authority !== undefined){
const _errs6 = errors;
if(!(validate2373(data.authority, {instancePath:instancePath+"/authority",parentData:data,parentDataProperty:"authority",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2373.errors : vErrors.concat(validate2373.errors);
errors = vErrors.length;
}
var valid0 = _errs6 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.database_name !== undefined){
const _errs7 = errors;
if(!(validate2367(data.database_name, {instancePath:instancePath+"/database_name",parentData:data,parentDataProperty:"database_name",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2367.errors : vErrors.concat(validate2367.errors);
errors = vErrors.length;
}
var valid0 = _errs7 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.initial_schema_name !== undefined){
const _errs8 = errors;
if(!(validate2367(data.initial_schema_name, {instancePath:instancePath+"/initial_schema_name",parentData:data,parentDataProperty:"initial_schema_name",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2367.errors : vErrors.concat(validate2367.errors);
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
validate2362.errors = [{}];
return false;
}
}
validate2362.errors = vErrors;
return errors === 0;
}
validate2362.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema651 = {"type":"object","additionalProperties":false,"properties":{"principal":{"$ref":"#/$defs/CatalogResponse/$defs/T10"},"login_role":{"$ref":"#/$defs/CatalogResponse/$defs/T10"},"role":{"$ref":"#/$defs/CatalogResponse/$defs/T10"},"credential_epoch":{"$ref":"#/$defs/CatalogResponse/$defs/T10"},"audience":{"$ref":"#/$defs/CatalogResponse/$defs/T10"},"context":{"$ref":"#/$defs/CatalogResponse/$defs/T14"}},"required":["principal","login_role","role","credential_epoch","audience","context"]};
const schema652 = {"type":"array","minItems":32,"maxItems":32,"items":{"$ref":"#/$defs/CatalogResponse/$defs/T3"}};

function validate2396(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2396.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(Array.isArray(data)){
if(data.length > 32){
validate2396.errors = [{}];
return false;
}
else {
if(data.length < 32){
validate2396.errors = [{}];
return false;
}
else {
var valid0 = true;
const len0 = data.length;
for(let i0=0; i0<len0; i0++){
const _errs1 = errors;
if(!(validate2347(data[i0], {instancePath:instancePath+"/" + i0,parentData:data,parentDataProperty:i0,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2347.errors : vErrors.concat(validate2347.errors);
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
validate2396.errors = [{}];
return false;
}
}
validate2396.errors = vErrors;
return errors === 0;
}
validate2396.evaluated = {"items":true,"dynamicProps":false,"dynamicItems":false};


function validate2390(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2390.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if(((((((data.principal === undefined) && (missing0 = "principal")) || ((data.login_role === undefined) && (missing0 = "login_role"))) || ((data.role === undefined) && (missing0 = "role"))) || ((data.credential_epoch === undefined) && (missing0 = "credential_epoch"))) || ((data.audience === undefined) && (missing0 = "audience"))) || ((data.context === undefined) && (missing0 = "context"))){
validate2390.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((((((key0 === "principal") || (key0 === "login_role")) || (key0 === "role")) || (key0 === "credential_epoch")) || (key0 === "audience")) || (key0 === "context"))){
validate2390.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.principal !== undefined){
const _errs2 = errors;
if(!(validate2364(data.principal, {instancePath:instancePath+"/principal",parentData:data,parentDataProperty:"principal",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2364.errors : vErrors.concat(validate2364.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.login_role !== undefined){
const _errs3 = errors;
if(!(validate2364(data.login_role, {instancePath:instancePath+"/login_role",parentData:data,parentDataProperty:"login_role",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2364.errors : vErrors.concat(validate2364.errors);
errors = vErrors.length;
}
var valid0 = _errs3 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.role !== undefined){
const _errs4 = errors;
if(!(validate2364(data.role, {instancePath:instancePath+"/role",parentData:data,parentDataProperty:"role",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2364.errors : vErrors.concat(validate2364.errors);
errors = vErrors.length;
}
var valid0 = _errs4 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.credential_epoch !== undefined){
const _errs5 = errors;
if(!(validate2364(data.credential_epoch, {instancePath:instancePath+"/credential_epoch",parentData:data,parentDataProperty:"credential_epoch",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2364.errors : vErrors.concat(validate2364.errors);
errors = vErrors.length;
}
var valid0 = _errs5 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.audience !== undefined){
const _errs6 = errors;
if(!(validate2364(data.audience, {instancePath:instancePath+"/audience",parentData:data,parentDataProperty:"audience",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2364.errors : vErrors.concat(validate2364.errors);
errors = vErrors.length;
}
var valid0 = _errs6 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.context !== undefined){
const _errs7 = errors;
if(!(validate2396(data.context, {instancePath:instancePath+"/context",parentData:data,parentDataProperty:"context",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2396.errors : vErrors.concat(validate2396.errors);
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
validate2390.errors = [{}];
return false;
}
}
validate2390.errors = vErrors;
return errors === 0;
}
validate2390.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate2361(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2361.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((((data.configuration === undefined) && (missing0 = "configuration")) || ((data.subject === undefined) && (missing0 = "subject"))) || ((data.policy_revision === undefined) && (missing0 = "policy_revision"))){
validate2361.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "configuration") || (key0 === "subject")) || (key0 === "policy_revision"))){
validate2361.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.configuration !== undefined){
const _errs2 = errors;
if(!(validate2362(data.configuration, {instancePath:instancePath+"/configuration",parentData:data,parentDataProperty:"configuration",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2362.errors : vErrors.concat(validate2362.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.subject !== undefined){
const _errs3 = errors;
if(!(validate2390(data.subject, {instancePath:instancePath+"/subject",parentData:data,parentDataProperty:"subject",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2390.errors : vErrors.concat(validate2390.errors);
errors = vErrors.length;
}
var valid0 = _errs3 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.policy_revision !== undefined){
const _errs4 = errors;
if(!(validate2364(data.policy_revision, {instancePath:instancePath+"/policy_revision",parentData:data,parentDataProperty:"policy_revision",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2364.errors : vErrors.concat(validate2364.errors);
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
validate2361.errors = [{}];
return false;
}
}
validate2361.errors = vErrors;
return errors === 0;
}
validate2361.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema653 = {"anyOf":[{"$ref":"#/$defs/CatalogResponse/$defs/T16"},{"type":"null"}]};
const schema654 = {"type":"object","additionalProperties":false,"properties":{"scope":{"$ref":"#/$defs/CatalogResponse/$defs/T9"},"id":{"$ref":"#/$defs/CatalogResponse/$defs/T10"},"authorization":{"$ref":"#/$defs/CatalogResponse/$defs/T10"},"name":{"$ref":"#/$defs/CatalogResponse/$defs/T11"},"revision":{"$ref":"#/$defs/CatalogResponse/$defs/T10"},"retired":{"$ref":"#/$defs/CatalogResponse/$defs/T17"}},"required":["scope","id","authorization","name","revision","retired"]};
const schema655 = {"type":"boolean"};

function validate2409(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2409.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "boolean"){
validate2409.errors = [{}];
return false;
}
validate2409.errors = vErrors;
return errors === 0;
}
validate2409.evaluated = {"dynamicProps":false,"dynamicItems":false};


function validate2403(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2403.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if(((((((data.scope === undefined) && (missing0 = "scope")) || ((data.id === undefined) && (missing0 = "id"))) || ((data.authorization === undefined) && (missing0 = "authorization"))) || ((data.name === undefined) && (missing0 = "name"))) || ((data.revision === undefined) && (missing0 = "revision"))) || ((data.retired === undefined) && (missing0 = "retired"))){
validate2403.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((((((key0 === "scope") || (key0 === "id")) || (key0 === "authorization")) || (key0 === "name")) || (key0 === "revision")) || (key0 === "retired"))){
validate2403.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.scope !== undefined){
const _errs2 = errors;
if(!(validate2363(data.scope, {instancePath:instancePath+"/scope",parentData:data,parentDataProperty:"scope",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2363.errors : vErrors.concat(validate2363.errors);
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
if(!(validate2364(data.id, {instancePath:instancePath+"/id",parentData:data,parentDataProperty:"id",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2364.errors : vErrors.concat(validate2364.errors);
errors = vErrors.length;
}
var valid0 = _errs3 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.authorization !== undefined){
const _errs4 = errors;
if(!(validate2364(data.authorization, {instancePath:instancePath+"/authorization",parentData:data,parentDataProperty:"authorization",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2364.errors : vErrors.concat(validate2364.errors);
errors = vErrors.length;
}
var valid0 = _errs4 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.name !== undefined){
const _errs5 = errors;
if(!(validate2367(data.name, {instancePath:instancePath+"/name",parentData:data,parentDataProperty:"name",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2367.errors : vErrors.concat(validate2367.errors);
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
if(!(validate2364(data.revision, {instancePath:instancePath+"/revision",parentData:data,parentDataProperty:"revision",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2364.errors : vErrors.concat(validate2364.errors);
errors = vErrors.length;
}
var valid0 = _errs6 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.retired !== undefined){
const _errs7 = errors;
if(!(validate2409(data.retired, {instancePath:instancePath+"/retired",parentData:data,parentDataProperty:"retired",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2409.errors : vErrors.concat(validate2409.errors);
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
validate2403.errors = [{}];
return false;
}
}
validate2403.errors = vErrors;
return errors === 0;
}
validate2403.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate2402(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2402.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate2403(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2403.errors : vErrors.concat(validate2403.errors);
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
validate2402.errors = vErrors;
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
validate2402.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate2402.evaluated = {"dynamicProps":true,"dynamicItems":false};

const schema656 = {"type":"object","additionalProperties":false,"properties":{"entries":{"$ref":"#/$defs/CatalogResponse/$defs/T19"},"next":{"$ref":"#/$defs/CatalogResponse/$defs/T20"},"position":{"$ref":"#/$defs/CatalogResponse/$defs/T26"}},"required":["entries","next","position"]};
const schema657 = {"type":"array","minItems":8,"maxItems":8,"items":{"$ref":"#/$defs/CatalogResponse/$defs/T15"}};

function validate2414(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2414.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(Array.isArray(data)){
if(data.length > 8){
validate2414.errors = [{}];
return false;
}
else {
if(data.length < 8){
validate2414.errors = [{}];
return false;
}
else {
var valid0 = true;
const len0 = data.length;
for(let i0=0; i0<len0; i0++){
const _errs1 = errors;
if(!(validate2402(data[i0], {instancePath:instancePath+"/" + i0,parentData:data,parentDataProperty:i0,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2402.errors : vErrors.concat(validate2402.errors);
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
validate2414.errors = [{}];
return false;
}
}
validate2414.errors = vErrors;
return errors === 0;
}
validate2414.evaluated = {"items":true,"dynamicProps":false,"dynamicItems":false};

const schema658 = {"anyOf":[{"$ref":"#/$defs/CatalogResponse/$defs/T21"},{"type":"null"}]};
const schema659 = {"type":"object","additionalProperties":false,"properties":{"definition":{"$ref":"#/$defs/CatalogResponse/$defs/T4"},"connection":{"$ref":"#/$defs/CatalogResponse/$defs/T22"},"selection":{"$ref":"#/$defs/CatalogResponse/$defs/T24"},"position":{"$ref":"#/$defs/CatalogResponse/$defs/T26"},"after":{"$ref":"#/$defs/CatalogResponse/$defs/T11"}},"required":["definition","connection","selection","position","after"]};
const schema660 = {"type":"object","additionalProperties":false,"properties":{"scope":{"$ref":"#/$defs/CatalogResponse/$defs/T9"},"branch":{"$ref":"#/$defs/CatalogResponse/$defs/T11"},"audience":{"$ref":"#/$defs/CatalogResponse/$defs/T10"},"principal":{"$ref":"#/$defs/CatalogResponse/$defs/T10"},"role":{"$ref":"#/$defs/CatalogResponse/$defs/T23"}},"required":["scope","branch","audience","principal","role"]};
const schema661 = {"anyOf":[{"$ref":"#/$defs/CatalogResponse/$defs/T10"},{"type":"null"}]};

function validate2425(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2425.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate2364(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2364.errors : vErrors.concat(validate2364.errors);
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
validate2425.errors = vErrors;
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
validate2425.errors = vErrors;
return errors === 0;
}
validate2425.evaluated = {"dynamicProps":false,"dynamicItems":false};


function validate2420(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2420.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((((((data.scope === undefined) && (missing0 = "scope")) || ((data.branch === undefined) && (missing0 = "branch"))) || ((data.audience === undefined) && (missing0 = "audience"))) || ((data.principal === undefined) && (missing0 = "principal"))) || ((data.role === undefined) && (missing0 = "role"))){
validate2420.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((((key0 === "scope") || (key0 === "branch")) || (key0 === "audience")) || (key0 === "principal")) || (key0 === "role"))){
validate2420.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.scope !== undefined){
const _errs2 = errors;
if(!(validate2363(data.scope, {instancePath:instancePath+"/scope",parentData:data,parentDataProperty:"scope",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2363.errors : vErrors.concat(validate2363.errors);
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
if(!(validate2367(data.branch, {instancePath:instancePath+"/branch",parentData:data,parentDataProperty:"branch",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2367.errors : vErrors.concat(validate2367.errors);
errors = vErrors.length;
}
var valid0 = _errs3 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.audience !== undefined){
const _errs4 = errors;
if(!(validate2364(data.audience, {instancePath:instancePath+"/audience",parentData:data,parentDataProperty:"audience",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2364.errors : vErrors.concat(validate2364.errors);
errors = vErrors.length;
}
var valid0 = _errs4 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.principal !== undefined){
const _errs5 = errors;
if(!(validate2364(data.principal, {instancePath:instancePath+"/principal",parentData:data,parentDataProperty:"principal",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2364.errors : vErrors.concat(validate2364.errors);
errors = vErrors.length;
}
var valid0 = _errs5 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.role !== undefined){
const _errs6 = errors;
if(!(validate2425(data.role, {instancePath:instancePath+"/role",parentData:data,parentDataProperty:"role",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2425.errors : vErrors.concat(validate2425.errors);
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
validate2420.errors = [{}];
return false;
}
}
validate2420.errors = vErrors;
return errors === 0;
}
validate2420.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema662 = {"oneOf":[{"type":"object","additionalProperties":false,"required":["namespaces"],"properties":{"namespaces":{"$ref":"#/$defs/CatalogResponse/$defs/T25"}}},{"type":"object","additionalProperties":false,"required":["tables"],"properties":{"tables":{"$ref":"#/$defs/CatalogResponse/$defs/T10"}}},{"type":"object","additionalProperties":false,"required":["resources"],"properties":{"resources":{"$ref":"#/$defs/CatalogResponse/$defs/T10"}}}]};
const schema663 = {"type":"object","maxProperties":0};

function validate2430(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2430.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
if(Object.keys(data).length > 0){
validate2430.errors = [{}];
return false;
}
}
else {
validate2430.errors = [{}];
return false;
}
}
validate2430.errors = vErrors;
return errors === 0;
}
validate2430.evaluated = {"dynamicProps":false,"dynamicItems":false};


function validate2429(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2429.evaluated;
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
if((data.namespaces === undefined) && (missing0 = "namespaces")){
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
const _errs3 = errors;
for(const key0 in data){
if(!(key0 === "namespaces")){
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
if(_errs3 === errors){
if(data.namespaces !== undefined){
if(!(validate2430(data.namespaces, {instancePath:instancePath+"/namespaces",parentData:data,parentDataProperty:"namespaces",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2430.errors : vErrors.concat(validate2430.errors);
errors = vErrors.length;
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
var _valid0 = _errs1 === errors;
if(_valid0){
valid0 = true;
passing0 = 0;
var props0 = true;
}
const _errs5 = errors;
if(errors === _errs5){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing1;
if((data.tables === undefined) && (missing1 = "tables")){
const err3 = {};
if(vErrors === null){
vErrors = [err3];
}
else {
vErrors.push(err3);
}
errors++;
}
else {
const _errs7 = errors;
for(const key1 in data){
if(!(key1 === "tables")){
const err4 = {};
if(vErrors === null){
vErrors = [err4];
}
else {
vErrors.push(err4);
}
errors++;
break;
}
}
if(_errs7 === errors){
if(data.tables !== undefined){
if(!(validate2364(data.tables, {instancePath:instancePath+"/tables",parentData:data,parentDataProperty:"tables",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2364.errors : vErrors.concat(validate2364.errors);
errors = vErrors.length;
}
}
}
}
}
else {
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
var _valid0 = _errs5 === errors;
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
const _errs9 = errors;
if(errors === _errs9){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing2;
if((data.resources === undefined) && (missing2 = "resources")){
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
const _errs11 = errors;
for(const key2 in data){
if(!(key2 === "resources")){
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
if(_errs11 === errors){
if(data.resources !== undefined){
if(!(validate2364(data.resources, {instancePath:instancePath+"/resources",parentData:data,parentDataProperty:"resources",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2364.errors : vErrors.concat(validate2364.errors);
errors = vErrors.length;
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
var _valid0 = _errs9 === errors;
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
const err9 = {};
if(vErrors === null){
vErrors = [err9];
}
else {
vErrors.push(err9);
}
errors++;
validate2429.errors = vErrors;
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
validate2429.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate2429.evaluated = {"dynamicProps":true,"dynamicItems":false};

const schema664 = {"type":"object","additionalProperties":false,"properties":{"partition":{"$ref":"#/$defs/CatalogResponse/$defs/T11"},"next_lsn":{"$ref":"#/$defs/CatalogResponse/$defs/T11"}},"required":["partition","next_lsn"]};

function validate2435(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2435.evaluated;
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
validate2435.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "partition") || (key0 === "next_lsn"))){
validate2435.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.partition !== undefined){
const _errs2 = errors;
if(!(validate2367(data.partition, {instancePath:instancePath+"/partition",parentData:data,parentDataProperty:"partition",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2367.errors : vErrors.concat(validate2367.errors);
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
if(!(validate2367(data.next_lsn, {instancePath:instancePath+"/next_lsn",parentData:data,parentDataProperty:"next_lsn",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2367.errors : vErrors.concat(validate2367.errors);
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
validate2435.errors = [{}];
return false;
}
}
validate2435.errors = vErrors;
return errors === 0;
}
validate2435.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate2418(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2418.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((((((data.definition === undefined) && (missing0 = "definition")) || ((data.connection === undefined) && (missing0 = "connection"))) || ((data.selection === undefined) && (missing0 = "selection"))) || ((data.position === undefined) && (missing0 = "position"))) || ((data.after === undefined) && (missing0 = "after"))){
validate2418.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((((key0 === "definition") || (key0 === "connection")) || (key0 === "selection")) || (key0 === "position")) || (key0 === "after"))){
validate2418.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.definition !== undefined){
const _errs2 = errors;
if(!(validate2349(data.definition, {instancePath:instancePath+"/definition",parentData:data,parentDataProperty:"definition",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2349.errors : vErrors.concat(validate2349.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.connection !== undefined){
const _errs3 = errors;
if(!(validate2420(data.connection, {instancePath:instancePath+"/connection",parentData:data,parentDataProperty:"connection",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2420.errors : vErrors.concat(validate2420.errors);
errors = vErrors.length;
}
var valid0 = _errs3 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.selection !== undefined){
const _errs4 = errors;
if(!(validate2429(data.selection, {instancePath:instancePath+"/selection",parentData:data,parentDataProperty:"selection",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2429.errors : vErrors.concat(validate2429.errors);
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
if(!(validate2435(data.position, {instancePath:instancePath+"/position",parentData:data,parentDataProperty:"position",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2435.errors : vErrors.concat(validate2435.errors);
errors = vErrors.length;
}
var valid0 = _errs5 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.after !== undefined){
const _errs6 = errors;
if(!(validate2367(data.after, {instancePath:instancePath+"/after",parentData:data,parentDataProperty:"after",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2367.errors : vErrors.concat(validate2367.errors);
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
validate2418.errors = [{}];
return false;
}
}
validate2418.errors = vErrors;
return errors === 0;
}
validate2418.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate2417(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2417.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate2418(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2418.errors : vErrors.concat(validate2418.errors);
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
validate2417.errors = vErrors;
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
validate2417.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate2417.evaluated = {"dynamicProps":true,"dynamicItems":false};


function validate2413(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2413.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((((data.entries === undefined) && (missing0 = "entries")) || ((data.next === undefined) && (missing0 = "next"))) || ((data.position === undefined) && (missing0 = "position"))){
validate2413.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "entries") || (key0 === "next")) || (key0 === "position"))){
validate2413.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.entries !== undefined){
const _errs2 = errors;
if(!(validate2414(data.entries, {instancePath:instancePath+"/entries",parentData:data,parentDataProperty:"entries",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2414.errors : vErrors.concat(validate2414.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.next !== undefined){
const _errs3 = errors;
if(!(validate2417(data.next, {instancePath:instancePath+"/next",parentData:data,parentDataProperty:"next",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2417.errors : vErrors.concat(validate2417.errors);
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
if(!(validate2435(data.position, {instancePath:instancePath+"/position",parentData:data,parentDataProperty:"position",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2435.errors : vErrors.concat(validate2435.errors);
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
validate2413.errors = [{}];
return false;
}
}
validate2413.errors = vErrors;
return errors === 0;
}
validate2413.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema665 = {"type":"object","additionalProperties":false,"properties":{"entries":{"$ref":"#/$defs/CatalogResponse/$defs/T28"},"next":{"$ref":"#/$defs/CatalogResponse/$defs/T20"},"position":{"$ref":"#/$defs/CatalogResponse/$defs/T26"},"consistency":{"$ref":"#/$defs/CatalogResponse/$defs/T33"}},"required":["entries","next","position","consistency"]};
const schema666 = {"type":"array","minItems":8,"maxItems":8,"items":{"$ref":"#/$defs/CatalogResponse/$defs/T29"}};
const schema667 = {"anyOf":[{"$ref":"#/$defs/CatalogResponse/$defs/T30"},{"type":"null"}]};
const schema668 = {"type":"object","additionalProperties":false,"properties":{"interpretation":{"$ref":"#/$defs/CatalogResponse/$defs/T31"},"namespace":{"$ref":"#/$defs/CatalogResponse/$defs/T10"},"name":{"$ref":"#/$defs/CatalogResponse/$defs/T11"},"position":{"$ref":"#/$defs/CatalogResponse/$defs/T26"},"changed_lsn":{"$ref":"#/$defs/CatalogResponse/$defs/T11"}},"required":["interpretation","namespace","name","position","changed_lsn"]};
const schema669 = {"type":"object","additionalProperties":false,"properties":{"object":{"$ref":"#/$defs/CatalogResponse/$defs/T32"},"revision":{"$ref":"#/$defs/CatalogResponse/$defs/T11"},"digest":{"$ref":"#/$defs/CatalogResponse/$defs/T11"}},"required":["object","revision","digest"]};
const schema670 = {"type":"object","additionalProperties":false,"properties":{"scope":{"$ref":"#/$defs/CatalogResponse/$defs/T9"},"branch":{"$ref":"#/$defs/CatalogResponse/$defs/T11"},"object":{"$ref":"#/$defs/CatalogResponse/$defs/T11"}},"required":["scope","branch","object"]};

function validate2449(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2449.evaluated;
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
validate2449.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "scope") || (key0 === "branch")) || (key0 === "object"))){
validate2449.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.scope !== undefined){
const _errs2 = errors;
if(!(validate2363(data.scope, {instancePath:instancePath+"/scope",parentData:data,parentDataProperty:"scope",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2363.errors : vErrors.concat(validate2363.errors);
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
if(!(validate2367(data.branch, {instancePath:instancePath+"/branch",parentData:data,parentDataProperty:"branch",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2367.errors : vErrors.concat(validate2367.errors);
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
if(!(validate2367(data.object, {instancePath:instancePath+"/object",parentData:data,parentDataProperty:"object",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2367.errors : vErrors.concat(validate2367.errors);
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
validate2449.errors = [{}];
return false;
}
}
validate2449.errors = vErrors;
return errors === 0;
}
validate2449.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate2448(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2448.evaluated;
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
validate2448.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "object") || (key0 === "revision")) || (key0 === "digest"))){
validate2448.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.object !== undefined){
const _errs2 = errors;
if(!(validate2449(data.object, {instancePath:instancePath+"/object",parentData:data,parentDataProperty:"object",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2449.errors : vErrors.concat(validate2449.errors);
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
if(!(validate2367(data.revision, {instancePath:instancePath+"/revision",parentData:data,parentDataProperty:"revision",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2367.errors : vErrors.concat(validate2367.errors);
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
if(!(validate2367(data.digest, {instancePath:instancePath+"/digest",parentData:data,parentDataProperty:"digest",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2367.errors : vErrors.concat(validate2367.errors);
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
validate2448.errors = [{}];
return false;
}
}
validate2448.errors = vErrors;
return errors === 0;
}
validate2448.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate2447(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2447.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((((((data.interpretation === undefined) && (missing0 = "interpretation")) || ((data.namespace === undefined) && (missing0 = "namespace"))) || ((data.name === undefined) && (missing0 = "name"))) || ((data.position === undefined) && (missing0 = "position"))) || ((data.changed_lsn === undefined) && (missing0 = "changed_lsn"))){
validate2447.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((((key0 === "interpretation") || (key0 === "namespace")) || (key0 === "name")) || (key0 === "position")) || (key0 === "changed_lsn"))){
validate2447.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.interpretation !== undefined){
const _errs2 = errors;
if(!(validate2448(data.interpretation, {instancePath:instancePath+"/interpretation",parentData:data,parentDataProperty:"interpretation",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2448.errors : vErrors.concat(validate2448.errors);
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
if(!(validate2364(data.namespace, {instancePath:instancePath+"/namespace",parentData:data,parentDataProperty:"namespace",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2364.errors : vErrors.concat(validate2364.errors);
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
if(!(validate2367(data.name, {instancePath:instancePath+"/name",parentData:data,parentDataProperty:"name",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2367.errors : vErrors.concat(validate2367.errors);
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
if(!(validate2435(data.position, {instancePath:instancePath+"/position",parentData:data,parentDataProperty:"position",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2435.errors : vErrors.concat(validate2435.errors);
errors = vErrors.length;
}
var valid0 = _errs5 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.changed_lsn !== undefined){
const _errs6 = errors;
if(!(validate2367(data.changed_lsn, {instancePath:instancePath+"/changed_lsn",parentData:data,parentDataProperty:"changed_lsn",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2367.errors : vErrors.concat(validate2367.errors);
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
validate2447.errors = [{}];
return false;
}
}
validate2447.errors = vErrors;
return errors === 0;
}
validate2447.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate2446(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2446.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate2447(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2447.errors : vErrors.concat(validate2447.errors);
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
validate2446.errors = vErrors;
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
validate2446.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate2446.evaluated = {"dynamicProps":true,"dynamicItems":false};


function validate2445(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2445.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(Array.isArray(data)){
if(data.length > 8){
validate2445.errors = [{}];
return false;
}
else {
if(data.length < 8){
validate2445.errors = [{}];
return false;
}
else {
var valid0 = true;
const len0 = data.length;
for(let i0=0; i0<len0; i0++){
const _errs1 = errors;
if(!(validate2446(data[i0], {instancePath:instancePath+"/" + i0,parentData:data,parentDataProperty:i0,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2446.errors : vErrors.concat(validate2446.errors);
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
validate2445.errors = [{}];
return false;
}
}
validate2445.errors = vErrors;
return errors === 0;
}
validate2445.evaluated = {"items":true,"dynamicProps":false,"dynamicItems":false};

const schema671 = {"type":"string","enum":["independent"]};

function validate2466(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2466.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate2466.errors = [{}];
return false;
}
if(!(data === "independent")){
validate2466.errors = [{}];
return false;
}
validate2466.errors = vErrors;
return errors === 0;
}
validate2466.evaluated = {"dynamicProps":false,"dynamicItems":false};


function validate2444(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2444.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if(((((data.entries === undefined) && (missing0 = "entries")) || ((data.next === undefined) && (missing0 = "next"))) || ((data.position === undefined) && (missing0 = "position"))) || ((data.consistency === undefined) && (missing0 = "consistency"))){
validate2444.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((((key0 === "entries") || (key0 === "next")) || (key0 === "position")) || (key0 === "consistency"))){
validate2444.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.entries !== undefined){
const _errs2 = errors;
if(!(validate2445(data.entries, {instancePath:instancePath+"/entries",parentData:data,parentDataProperty:"entries",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2445.errors : vErrors.concat(validate2445.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.next !== undefined){
const _errs3 = errors;
if(!(validate2417(data.next, {instancePath:instancePath+"/next",parentData:data,parentDataProperty:"next",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2417.errors : vErrors.concat(validate2417.errors);
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
if(!(validate2435(data.position, {instancePath:instancePath+"/position",parentData:data,parentDataProperty:"position",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2435.errors : vErrors.concat(validate2435.errors);
errors = vErrors.length;
}
var valid0 = _errs4 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.consistency !== undefined){
const _errs5 = errors;
if(!(validate2466(data.consistency, {instancePath:instancePath+"/consistency",parentData:data,parentDataProperty:"consistency",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2466.errors : vErrors.concat(validate2466.errors);
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
validate2444.errors = [{}];
return false;
}
}
validate2444.errors = vErrors;
return errors === 0;
}
validate2444.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate2345(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2345.evaluated;
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
if((data.capabilities === undefined) && (missing0 = "capabilities")){
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
const _errs3 = errors;
for(const key0 in data){
if(!(key0 === "capabilities")){
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
if(_errs3 === errors){
if(data.capabilities !== undefined){
if(!(validate2346(data.capabilities, {instancePath:instancePath+"/capabilities",parentData:data,parentDataProperty:"capabilities",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2346.errors : vErrors.concat(validate2346.errors);
errors = vErrors.length;
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
var _valid0 = _errs1 === errors;
if(_valid0){
valid0 = true;
passing0 = 0;
var props0 = true;
}
const _errs5 = errors;
if(errors === _errs5){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing1;
if((data.description === undefined) && (missing1 = "description")){
const err3 = {};
if(vErrors === null){
vErrors = [err3];
}
else {
vErrors.push(err3);
}
errors++;
}
else {
const _errs7 = errors;
for(const key1 in data){
if(!(key1 === "description")){
const err4 = {};
if(vErrors === null){
vErrors = [err4];
}
else {
vErrors.push(err4);
}
errors++;
break;
}
}
if(_errs7 === errors){
if(data.description !== undefined){
if(!(validate2361(data.description, {instancePath:instancePath+"/description",parentData:data,parentDataProperty:"description",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2361.errors : vErrors.concat(validate2361.errors);
errors = vErrors.length;
}
}
}
}
}
else {
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
var _valid0 = _errs5 === errors;
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
const _errs9 = errors;
if(errors === _errs9){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing2;
if((data.namespace === undefined) && (missing2 = "namespace")){
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
const _errs11 = errors;
for(const key2 in data){
if(!(key2 === "namespace")){
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
if(_errs11 === errors){
if(data.namespace !== undefined){
if(!(validate2402(data.namespace, {instancePath:instancePath+"/namespace",parentData:data,parentDataProperty:"namespace",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2402.errors : vErrors.concat(validate2402.errors);
errors = vErrors.length;
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
var _valid0 = _errs9 === errors;
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
const _errs13 = errors;
if(errors === _errs13){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing3;
if((data.namespaces === undefined) && (missing3 = "namespaces")){
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
const _errs15 = errors;
for(const key3 in data){
if(!(key3 === "namespaces")){
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
if(_errs15 === errors){
if(data.namespaces !== undefined){
if(!(validate2413(data.namespaces, {instancePath:instancePath+"/namespaces",parentData:data,parentDataProperty:"namespaces",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2413.errors : vErrors.concat(validate2413.errors);
errors = vErrors.length;
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
var _valid0 = _errs13 === errors;
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
const _errs17 = errors;
if(errors === _errs17){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing4;
if((data.tables === undefined) && (missing4 = "tables")){
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
const _errs19 = errors;
for(const key4 in data){
if(!(key4 === "tables")){
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
if(_errs19 === errors){
if(data.tables !== undefined){
if(!(validate2444(data.tables, {instancePath:instancePath+"/tables",parentData:data,parentDataProperty:"tables",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2444.errors : vErrors.concat(validate2444.errors);
errors = vErrors.length;
}
}
}
}
}
else {
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
var _valid0 = _errs17 === errors;
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
}
}
}
}
if(!valid0){
const err15 = {};
if(vErrors === null){
vErrors = [err15];
}
else {
vErrors.push(err15);
}
errors++;
validate2345.errors = vErrors;
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
validate2345.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate2345.evaluated = {"dynamicProps":true,"dynamicItems":false};

const schema672 = {"oneOf":[{"type":"object","additionalProperties":false,"required":["coverage"],"properties":{"coverage":{"$ref":"#/$defs/CatalogResponse/$defs/T35"}}},{"type":"object","additionalProperties":false,"required":["object"],"properties":{"object":{"$ref":"#/$defs/CatalogResponse/$defs/T72"}}},{"type":"object","additionalProperties":false,"required":["namespace"],"properties":{"namespace":{"$ref":"#/$defs/CatalogResponse/$defs/T73"}}},{"type":"object","additionalProperties":false,"required":["listing"],"properties":{"listing":{"$ref":"#/$defs/CatalogResponse/$defs/T75"}}},{"type":"object","additionalProperties":false,"required":["source"],"properties":{"source":{"$ref":"#/$defs/CatalogResponse/$defs/T83"}}}]};
const schema673 = {"type":"object","additionalProperties":false,"properties":{"snapshot":{"$ref":"#/$defs/CatalogResponse/$defs/T36"},"logical":{"$ref":"#/$defs/CatalogResponse/$defs/T41"},"accepted":{"$ref":"#/$defs/CatalogResponse/$defs/T26"},"total_rows":{"$ref":"#/$defs/CatalogResponse/$defs/T11"},"definitions":{"$ref":"#/$defs/CatalogResponse/$defs/T42"},"locations":{"$ref":"#/$defs/CatalogResponse/$defs/T54"},"next":{"$ref":"#/$defs/CatalogResponse/$defs/T69"}},"required":["snapshot","logical","accepted","total_rows","definitions","locations","next"]};
const schema674 = {"type":"object","additionalProperties":false,"properties":{"selector":{"$ref":"#/$defs/CatalogResponse/$defs/T11"},"definition":{"$ref":"#/$defs/CatalogResponse/$defs/T4"},"owner":{"$ref":"#/$defs/CatalogResponse/$defs/T37"},"branch":{"$ref":"#/$defs/CatalogResponse/$defs/T11"},"catalog_root":{"$ref":"#/$defs/CatalogResponse/$defs/T38"},"sources_root":{"$ref":"#/$defs/CatalogResponse/$defs/T38"},"source_count":{"$ref":"#/$defs/CatalogResponse/$defs/T11"},"consistency":{"$ref":"#/$defs/CatalogResponse/$defs/T39"}},"required":["selector","definition","owner","branch","catalog_root","sources_root","source_count","consistency"]};
const schema675 = {"type":"object","additionalProperties":false,"properties":{"scope":{"$ref":"#/$defs/CatalogResponse/$defs/T9"},"principal":{"$ref":"#/$defs/CatalogResponse/$defs/T10"},"operation":{"$ref":"#/$defs/CatalogResponse/$defs/T11"}},"required":["scope","principal","operation"]};

function validate2475(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2475.evaluated;
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
validate2475.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "scope") || (key0 === "principal")) || (key0 === "operation"))){
validate2475.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.scope !== undefined){
const _errs2 = errors;
if(!(validate2363(data.scope, {instancePath:instancePath+"/scope",parentData:data,parentDataProperty:"scope",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2363.errors : vErrors.concat(validate2363.errors);
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
if(!(validate2364(data.principal, {instancePath:instancePath+"/principal",parentData:data,parentDataProperty:"principal",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2364.errors : vErrors.concat(validate2364.errors);
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
if(!(validate2367(data.operation, {instancePath:instancePath+"/operation",parentData:data,parentDataProperty:"operation",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2367.errors : vErrors.concat(validate2367.errors);
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
validate2475.errors = [{}];
return false;
}
}
validate2475.errors = vErrors;
return errors === 0;
}
validate2475.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema676 = {"type":"object","additionalProperties":false,"properties":{"bytes":{"$ref":"#/$defs/CatalogResponse/$defs/T11"},"sha256":{"$ref":"#/$defs/CatalogResponse/$defs/T11"}},"required":["bytes","sha256"]};

function validate2481(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2481.evaluated;
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
validate2481.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "bytes") || (key0 === "sha256"))){
validate2481.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.bytes !== undefined){
const _errs2 = errors;
if(!(validate2367(data.bytes, {instancePath:instancePath+"/bytes",parentData:data,parentDataProperty:"bytes",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2367.errors : vErrors.concat(validate2367.errors);
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
if(!(validate2367(data.sha256, {instancePath:instancePath+"/sha256",parentData:data,parentDataProperty:"sha256",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2367.errors : vErrors.concat(validate2367.errors);
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
validate2481.errors = [{}];
return false;
}
}
validate2481.errors = vErrors;
return errors === 0;
}
validate2481.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema677 = {"oneOf":[{"type":"object","additionalProperties":false,"required":["single_partition"],"properties":{"single_partition":{"$ref":"#/$defs/CatalogResponse/$defs/T26"}}},{"type":"object","additionalProperties":false,"required":["independent"],"properties":{"independent":{"$ref":"#/$defs/CatalogResponse/$defs/T25"}}},{"type":"object","additionalProperties":false,"required":["common_transaction"],"properties":{"common_transaction":{"$ref":"#/$defs/CatalogResponse/$defs/T40"}}}]};
const schema678 = {"type":"object","additionalProperties":false,"properties":{"transaction":{"$ref":"#/$defs/CatalogResponse/$defs/T37"},"acquired":{"$ref":"#/$defs/CatalogResponse/$defs/T26"},"sources":{"$ref":"#/$defs/CatalogResponse/$defs/T38"},"source_count":{"$ref":"#/$defs/CatalogResponse/$defs/T11"}},"required":["transaction","acquired","sources","source_count"]};

function validate2490(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2490.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if(((((data.transaction === undefined) && (missing0 = "transaction")) || ((data.acquired === undefined) && (missing0 = "acquired"))) || ((data.sources === undefined) && (missing0 = "sources"))) || ((data.source_count === undefined) && (missing0 = "source_count"))){
validate2490.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((((key0 === "transaction") || (key0 === "acquired")) || (key0 === "sources")) || (key0 === "source_count"))){
validate2490.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.transaction !== undefined){
const _errs2 = errors;
if(!(validate2475(data.transaction, {instancePath:instancePath+"/transaction",parentData:data,parentDataProperty:"transaction",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2475.errors : vErrors.concat(validate2475.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.acquired !== undefined){
const _errs3 = errors;
if(!(validate2435(data.acquired, {instancePath:instancePath+"/acquired",parentData:data,parentDataProperty:"acquired",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2435.errors : vErrors.concat(validate2435.errors);
errors = vErrors.length;
}
var valid0 = _errs3 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.sources !== undefined){
const _errs4 = errors;
if(!(validate2481(data.sources, {instancePath:instancePath+"/sources",parentData:data,parentDataProperty:"sources",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2481.errors : vErrors.concat(validate2481.errors);
errors = vErrors.length;
}
var valid0 = _errs4 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.source_count !== undefined){
const _errs5 = errors;
if(!(validate2367(data.source_count, {instancePath:instancePath+"/source_count",parentData:data,parentDataProperty:"source_count",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2367.errors : vErrors.concat(validate2367.errors);
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
validate2490.errors = [{}];
return false;
}
}
validate2490.errors = vErrors;
return errors === 0;
}
validate2490.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate2487(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2487.evaluated;
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
if((data.single_partition === undefined) && (missing0 = "single_partition")){
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
const _errs3 = errors;
for(const key0 in data){
if(!(key0 === "single_partition")){
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
if(_errs3 === errors){
if(data.single_partition !== undefined){
if(!(validate2435(data.single_partition, {instancePath:instancePath+"/single_partition",parentData:data,parentDataProperty:"single_partition",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2435.errors : vErrors.concat(validate2435.errors);
errors = vErrors.length;
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
var _valid0 = _errs1 === errors;
if(_valid0){
valid0 = true;
passing0 = 0;
var props0 = true;
}
const _errs5 = errors;
if(errors === _errs5){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing1;
if((data.independent === undefined) && (missing1 = "independent")){
const err3 = {};
if(vErrors === null){
vErrors = [err3];
}
else {
vErrors.push(err3);
}
errors++;
}
else {
const _errs7 = errors;
for(const key1 in data){
if(!(key1 === "independent")){
const err4 = {};
if(vErrors === null){
vErrors = [err4];
}
else {
vErrors.push(err4);
}
errors++;
break;
}
}
if(_errs7 === errors){
if(data.independent !== undefined){
if(!(validate2430(data.independent, {instancePath:instancePath+"/independent",parentData:data,parentDataProperty:"independent",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2430.errors : vErrors.concat(validate2430.errors);
errors = vErrors.length;
}
}
}
}
}
else {
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
var _valid0 = _errs5 === errors;
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
const _errs9 = errors;
if(errors === _errs9){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing2;
if((data.common_transaction === undefined) && (missing2 = "common_transaction")){
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
const _errs11 = errors;
for(const key2 in data){
if(!(key2 === "common_transaction")){
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
if(_errs11 === errors){
if(data.common_transaction !== undefined){
if(!(validate2490(data.common_transaction, {instancePath:instancePath+"/common_transaction",parentData:data,parentDataProperty:"common_transaction",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2490.errors : vErrors.concat(validate2490.errors);
errors = vErrors.length;
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
var _valid0 = _errs9 === errors;
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
const err9 = {};
if(vErrors === null){
vErrors = [err9];
}
else {
vErrors.push(err9);
}
errors++;
validate2487.errors = vErrors;
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
validate2487.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate2487.evaluated = {"dynamicProps":true,"dynamicItems":false};


function validate2472(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2472.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if(((((((((data.selector === undefined) && (missing0 = "selector")) || ((data.definition === undefined) && (missing0 = "definition"))) || ((data.owner === undefined) && (missing0 = "owner"))) || ((data.branch === undefined) && (missing0 = "branch"))) || ((data.catalog_root === undefined) && (missing0 = "catalog_root"))) || ((data.sources_root === undefined) && (missing0 = "sources_root"))) || ((data.source_count === undefined) && (missing0 = "source_count"))) || ((data.consistency === undefined) && (missing0 = "consistency"))){
validate2472.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((((((((key0 === "selector") || (key0 === "definition")) || (key0 === "owner")) || (key0 === "branch")) || (key0 === "catalog_root")) || (key0 === "sources_root")) || (key0 === "source_count")) || (key0 === "consistency"))){
validate2472.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.selector !== undefined){
const _errs2 = errors;
if(!(validate2367(data.selector, {instancePath:instancePath+"/selector",parentData:data,parentDataProperty:"selector",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2367.errors : vErrors.concat(validate2367.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.definition !== undefined){
const _errs3 = errors;
if(!(validate2349(data.definition, {instancePath:instancePath+"/definition",parentData:data,parentDataProperty:"definition",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2349.errors : vErrors.concat(validate2349.errors);
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
if(!(validate2475(data.owner, {instancePath:instancePath+"/owner",parentData:data,parentDataProperty:"owner",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2475.errors : vErrors.concat(validate2475.errors);
errors = vErrors.length;
}
var valid0 = _errs4 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.branch !== undefined){
const _errs5 = errors;
if(!(validate2367(data.branch, {instancePath:instancePath+"/branch",parentData:data,parentDataProperty:"branch",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2367.errors : vErrors.concat(validate2367.errors);
errors = vErrors.length;
}
var valid0 = _errs5 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.catalog_root !== undefined){
const _errs6 = errors;
if(!(validate2481(data.catalog_root, {instancePath:instancePath+"/catalog_root",parentData:data,parentDataProperty:"catalog_root",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2481.errors : vErrors.concat(validate2481.errors);
errors = vErrors.length;
}
var valid0 = _errs6 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.sources_root !== undefined){
const _errs7 = errors;
if(!(validate2481(data.sources_root, {instancePath:instancePath+"/sources_root",parentData:data,parentDataProperty:"sources_root",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2481.errors : vErrors.concat(validate2481.errors);
errors = vErrors.length;
}
var valid0 = _errs7 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.source_count !== undefined){
const _errs8 = errors;
if(!(validate2367(data.source_count, {instancePath:instancePath+"/source_count",parentData:data,parentDataProperty:"source_count",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2367.errors : vErrors.concat(validate2367.errors);
errors = vErrors.length;
}
var valid0 = _errs8 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.consistency !== undefined){
const _errs9 = errors;
if(!(validate2487(data.consistency, {instancePath:instancePath+"/consistency",parentData:data,parentDataProperty:"consistency",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2487.errors : vErrors.concat(validate2487.errors);
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
validate2472.errors = [{}];
return false;
}
}
validate2472.errors = vErrors;
return errors === 0;
}
validate2472.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema679 = {"type":"object","additionalProperties":false,"properties":{"interpretation":{"$ref":"#/$defs/CatalogResponse/$defs/T31"},"content":{"$ref":"#/$defs/CatalogResponse/$defs/T38"},"schema_fingerprint":{"$ref":"#/$defs/CatalogResponse/$defs/T11"},"retired":{"$ref":"#/$defs/CatalogResponse/$defs/T17"}},"required":["interpretation","content","schema_fingerprint","retired"]};

function validate2498(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2498.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if(((((data.interpretation === undefined) && (missing0 = "interpretation")) || ((data.content === undefined) && (missing0 = "content"))) || ((data.schema_fingerprint === undefined) && (missing0 = "schema_fingerprint"))) || ((data.retired === undefined) && (missing0 = "retired"))){
validate2498.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((((key0 === "interpretation") || (key0 === "content")) || (key0 === "schema_fingerprint")) || (key0 === "retired"))){
validate2498.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.interpretation !== undefined){
const _errs2 = errors;
if(!(validate2448(data.interpretation, {instancePath:instancePath+"/interpretation",parentData:data,parentDataProperty:"interpretation",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2448.errors : vErrors.concat(validate2448.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.content !== undefined){
const _errs3 = errors;
if(!(validate2481(data.content, {instancePath:instancePath+"/content",parentData:data,parentDataProperty:"content",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2481.errors : vErrors.concat(validate2481.errors);
errors = vErrors.length;
}
var valid0 = _errs3 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.schema_fingerprint !== undefined){
const _errs4 = errors;
if(!(validate2367(data.schema_fingerprint, {instancePath:instancePath+"/schema_fingerprint",parentData:data,parentDataProperty:"schema_fingerprint",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2367.errors : vErrors.concat(validate2367.errors);
errors = vErrors.length;
}
var valid0 = _errs4 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.retired !== undefined){
const _errs5 = errors;
if(!(validate2409(data.retired, {instancePath:instancePath+"/retired",parentData:data,parentDataProperty:"retired",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2409.errors : vErrors.concat(validate2409.errors);
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
validate2498.errors = [{}];
return false;
}
}
validate2498.errors = vErrors;
return errors === 0;
}
validate2498.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema680 = {"anyOf":[{"$ref":"#/$defs/CatalogResponse/$defs/T43"},{"type":"null"}]};
const schema681 = {"type":"object","additionalProperties":false,"properties":{"physical":{"$ref":"#/$defs/CatalogResponse/$defs/T41"},"schema_revision":{"$ref":"#/$defs/CatalogResponse/$defs/T11"},"rows":{"$ref":"#/$defs/CatalogResponse/$defs/T11"},"columns":{"$ref":"#/$defs/CatalogResponse/$defs/T44"}},"required":["physical","schema_revision","rows","columns"]};
const schema682 = {"type":"array","maxItems":128,"items":{"$ref":"#/$defs/CatalogResponse/$defs/T45"}};
const schema683 = {"type":"object","additionalProperties":false,"properties":{"column":{"$ref":"#/$defs/CatalogResponse/$defs/T46"},"source":{"$ref":"#/$defs/CatalogResponse/$defs/T47"}},"required":["column","source"]};
const schema684 = {"type":"string","maxLength":262144};

function validate2513(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2513.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(typeof data === "string"){
if(func3(data) > 262144){
validate2513.errors = [{}];
return false;
}
}
else {
validate2513.errors = [{}];
return false;
}
}
validate2513.errors = vErrors;
return errors === 0;
}
validate2513.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema685 = {"oneOf":[{"type":"object","additionalProperties":false,"required":["physical"],"properties":{"physical":{"$ref":"#/$defs/CatalogResponse/$defs/T46"}}},{"type":"object","additionalProperties":false,"required":["initial"],"properties":{"initial":{"$ref":"#/$defs/CatalogResponse/$defs/T48"}}}]};
const schema686 = {"type":"object","additionalProperties":false,"properties":{"definition":{"$ref":"#/$defs/CatalogResponse/$defs/T49"},"state":{"$ref":"#/$defs/CatalogResponse/$defs/T53"}},"required":["definition","state"]};
const schema687 = {"type":"object","additionalProperties":false,"properties":{"object":{"$ref":"#/$defs/CatalogResponse/$defs/T50"},"revision":{"$ref":"#/$defs/CatalogResponse/$defs/T46"},"digest":{"$ref":"#/$defs/CatalogResponse/$defs/T46"}},"required":["object","revision","digest"]};
const schema688 = {"type":"object","additionalProperties":false,"properties":{"scope":{"$ref":"#/$defs/CatalogResponse/$defs/T51"},"branch":{"$ref":"#/$defs/CatalogResponse/$defs/T46"},"object":{"$ref":"#/$defs/CatalogResponse/$defs/T46"}},"required":["scope","branch","object"]};
const schema689 = {"type":"object","additionalProperties":false,"properties":{"realm":{"$ref":"#/$defs/CatalogResponse/$defs/T52"},"resource":{"$ref":"#/$defs/CatalogResponse/$defs/T52"},"catalog":{"$ref":"#/$defs/CatalogResponse/$defs/T46"}},"required":["realm","resource","catalog"]};

function validate2521(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2521.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(!(((typeof data == "number") && (!(data % 1) && !isNaN(data))) && (isFinite(data)))){
validate2521.errors = [{}];
return false;
}
if(errors === 0){
if((typeof data == "number") && (isFinite(data))){
if(data > 9007199254740991 || isNaN(data)){
validate2521.errors = [{}];
return false;
}
else {
if(data < 0 || isNaN(data)){
validate2521.errors = [{}];
return false;
}
}
}
}
validate2521.errors = vErrors;
return errors === 0;
}
validate2521.evaluated = {"dynamicProps":false,"dynamicItems":false};


function validate2520(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2520.evaluated;
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
validate2520.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "realm") || (key0 === "resource")) || (key0 === "catalog"))){
validate2520.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.realm !== undefined){
const _errs2 = errors;
if(!(validate2521(data.realm, {instancePath:instancePath+"/realm",parentData:data,parentDataProperty:"realm",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2521.errors : vErrors.concat(validate2521.errors);
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
if(!(validate2521(data.resource, {instancePath:instancePath+"/resource",parentData:data,parentDataProperty:"resource",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2521.errors : vErrors.concat(validate2521.errors);
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
if(!(validate2513(data.catalog, {instancePath:instancePath+"/catalog",parentData:data,parentDataProperty:"catalog",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2513.errors : vErrors.concat(validate2513.errors);
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
validate2520.errors = [{}];
return false;
}
}
validate2520.errors = vErrors;
return errors === 0;
}
validate2520.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate2519(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2519.evaluated;
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
validate2519.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "scope") || (key0 === "branch")) || (key0 === "object"))){
validate2519.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.scope !== undefined){
const _errs2 = errors;
if(!(validate2520(data.scope, {instancePath:instancePath+"/scope",parentData:data,parentDataProperty:"scope",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2520.errors : vErrors.concat(validate2520.errors);
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
if(!(validate2513(data.branch, {instancePath:instancePath+"/branch",parentData:data,parentDataProperty:"branch",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2513.errors : vErrors.concat(validate2513.errors);
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
if(!(validate2513(data.object, {instancePath:instancePath+"/object",parentData:data,parentDataProperty:"object",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2513.errors : vErrors.concat(validate2513.errors);
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
validate2519.errors = [{}];
return false;
}
}
validate2519.errors = vErrors;
return errors === 0;
}
validate2519.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate2518(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2518.evaluated;
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
validate2518.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "object") || (key0 === "revision")) || (key0 === "digest"))){
validate2518.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.object !== undefined){
const _errs2 = errors;
if(!(validate2519(data.object, {instancePath:instancePath+"/object",parentData:data,parentDataProperty:"object",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2519.errors : vErrors.concat(validate2519.errors);
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
if(!(validate2513(data.revision, {instancePath:instancePath+"/revision",parentData:data,parentDataProperty:"revision",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2513.errors : vErrors.concat(validate2513.errors);
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
if(!(validate2513(data.digest, {instancePath:instancePath+"/digest",parentData:data,parentDataProperty:"digest",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2513.errors : vErrors.concat(validate2513.errors);
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
validate2518.errors = [{}];
return false;
}
}
validate2518.errors = vErrors;
return errors === 0;
}
validate2518.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema283 = {"type":"string","enum":["missing","null","type_error","value","conflict"]};

function validate2532(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2532.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate2532.errors = [{}];
return false;
}
if(!(((((data === "missing") || (data === "null")) || (data === "type_error")) || (data === "value")) || (data === "conflict"))){
validate2532.errors = [{}];
return false;
}
validate2532.errors = vErrors;
return errors === 0;
}
validate2532.evaluated = {"dynamicProps":false,"dynamicItems":false};


function validate2517(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2517.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if(((data.definition === undefined) && (missing0 = "definition")) || ((data.state === undefined) && (missing0 = "state"))){
validate2517.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "definition") || (key0 === "state"))){
validate2517.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.definition !== undefined){
const _errs2 = errors;
if(!(validate2518(data.definition, {instancePath:instancePath+"/definition",parentData:data,parentDataProperty:"definition",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2518.errors : vErrors.concat(validate2518.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.state !== undefined){
const _errs3 = errors;
if(!(validate2532(data.state, {instancePath:instancePath+"/state",parentData:data,parentDataProperty:"state",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2532.errors : vErrors.concat(validate2532.errors);
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
validate2517.errors = [{}];
return false;
}
}
validate2517.errors = vErrors;
return errors === 0;
}
validate2517.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate2515(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2515.evaluated;
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
if((data.physical === undefined) && (missing0 = "physical")){
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
const _errs3 = errors;
for(const key0 in data){
if(!(key0 === "physical")){
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
if(_errs3 === errors){
if(data.physical !== undefined){
if(!(validate2513(data.physical, {instancePath:instancePath+"/physical",parentData:data,parentDataProperty:"physical",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2513.errors : vErrors.concat(validate2513.errors);
errors = vErrors.length;
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
var _valid0 = _errs1 === errors;
if(_valid0){
valid0 = true;
passing0 = 0;
var props0 = true;
}
const _errs5 = errors;
if(errors === _errs5){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing1;
if((data.initial === undefined) && (missing1 = "initial")){
const err3 = {};
if(vErrors === null){
vErrors = [err3];
}
else {
vErrors.push(err3);
}
errors++;
}
else {
const _errs7 = errors;
for(const key1 in data){
if(!(key1 === "initial")){
const err4 = {};
if(vErrors === null){
vErrors = [err4];
}
else {
vErrors.push(err4);
}
errors++;
break;
}
}
if(_errs7 === errors){
if(data.initial !== undefined){
if(!(validate2517(data.initial, {instancePath:instancePath+"/initial",parentData:data,parentDataProperty:"initial",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2517.errors : vErrors.concat(validate2517.errors);
errors = vErrors.length;
}
}
}
}
}
else {
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
var _valid0 = _errs5 === errors;
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
}
if(!valid0){
const err6 = {};
if(vErrors === null){
vErrors = [err6];
}
else {
vErrors.push(err6);
}
errors++;
validate2515.errors = vErrors;
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
validate2515.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate2515.evaluated = {"dynamicProps":true,"dynamicItems":false};


function validate2512(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2512.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if(((data.column === undefined) && (missing0 = "column")) || ((data.source === undefined) && (missing0 = "source"))){
validate2512.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "column") || (key0 === "source"))){
validate2512.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.column !== undefined){
const _errs2 = errors;
if(!(validate2513(data.column, {instancePath:instancePath+"/column",parentData:data,parentDataProperty:"column",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2513.errors : vErrors.concat(validate2513.errors);
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
if(!(validate2515(data.source, {instancePath:instancePath+"/source",parentData:data,parentDataProperty:"source",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2515.errors : vErrors.concat(validate2515.errors);
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
validate2512.errors = [{}];
return false;
}
}
validate2512.errors = vErrors;
return errors === 0;
}
validate2512.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate2511(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2511.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(Array.isArray(data)){
if(data.length > 128){
validate2511.errors = [{}];
return false;
}
else {
var valid0 = true;
const len0 = data.length;
for(let i0=0; i0<len0; i0++){
const _errs1 = errors;
if(!(validate2512(data[i0], {instancePath:instancePath+"/" + i0,parentData:data,parentDataProperty:i0,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2512.errors : vErrors.concat(validate2512.errors);
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
validate2511.errors = [{}];
return false;
}
}
validate2511.errors = vErrors;
return errors === 0;
}
validate2511.evaluated = {"items":true,"dynamicProps":false,"dynamicItems":false};


function validate2507(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2507.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if(((((data.physical === undefined) && (missing0 = "physical")) || ((data.schema_revision === undefined) && (missing0 = "schema_revision"))) || ((data.rows === undefined) && (missing0 = "rows"))) || ((data.columns === undefined) && (missing0 = "columns"))){
validate2507.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((((key0 === "physical") || (key0 === "schema_revision")) || (key0 === "rows")) || (key0 === "columns"))){
validate2507.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.physical !== undefined){
const _errs2 = errors;
if(!(validate2498(data.physical, {instancePath:instancePath+"/physical",parentData:data,parentDataProperty:"physical",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2498.errors : vErrors.concat(validate2498.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.schema_revision !== undefined){
const _errs3 = errors;
if(!(validate2367(data.schema_revision, {instancePath:instancePath+"/schema_revision",parentData:data,parentDataProperty:"schema_revision",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2367.errors : vErrors.concat(validate2367.errors);
errors = vErrors.length;
}
var valid0 = _errs3 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.rows !== undefined){
const _errs4 = errors;
if(!(validate2367(data.rows, {instancePath:instancePath+"/rows",parentData:data,parentDataProperty:"rows",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2367.errors : vErrors.concat(validate2367.errors);
errors = vErrors.length;
}
var valid0 = _errs4 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.columns !== undefined){
const _errs5 = errors;
if(!(validate2511(data.columns, {instancePath:instancePath+"/columns",parentData:data,parentDataProperty:"columns",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2511.errors : vErrors.concat(validate2511.errors);
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
validate2507.errors = [{}];
return false;
}
}
validate2507.errors = vErrors;
return errors === 0;
}
validate2507.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate2506(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2506.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate2507(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2507.errors : vErrors.concat(validate2507.errors);
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
validate2506.errors = vErrors;
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
validate2506.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate2506.evaluated = {"dynamicProps":true,"dynamicItems":false};

const schema692 = {"type":"array","maxItems":8,"items":{"$ref":"#/$defs/CatalogResponse/$defs/T55"}};
const schema693 = {"type":"object","additionalProperties":false,"properties":{"identity":{"$ref":"#/$defs/CatalogResponse/$defs/T56"},"physical":{"$ref":"#/$defs/CatalogResponse/$defs/T59"},"schema_revision":{"$ref":"#/$defs/CatalogResponse/$defs/T57"},"location":{"$ref":"#/$defs/CatalogResponse/$defs/T66"}},"required":["identity","physical","schema_revision","location"]};
const schema694 = {"type":"object","additionalProperties":false,"properties":{"origin":{"$ref":"#/$defs/CatalogResponse/$defs/T57"},"operation":{"$ref":"#/$defs/CatalogResponse/$defs/T57"},"ordinal":{"$ref":"#/$defs/CatalogResponse/$defs/T58"}},"required":["origin","operation","ordinal"]};
const schema695 = {"type":"string","maxLength":262144};

function validate2543(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2543.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(typeof data === "string"){
if(func3(data) > 262144){
validate2543.errors = [{}];
return false;
}
}
else {
validate2543.errors = [{}];
return false;
}
}
validate2543.errors = vErrors;
return errors === 0;
}
validate2543.evaluated = {"dynamicProps":false,"dynamicItems":false};


function validate2546(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2546.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(!(((typeof data == "number") && (!(data % 1) && !isNaN(data))) && (isFinite(data)))){
validate2546.errors = [{}];
return false;
}
if(errors === 0){
if((typeof data == "number") && (isFinite(data))){
if(data > 4294967295 || isNaN(data)){
validate2546.errors = [{}];
return false;
}
else {
if(data < 0 || isNaN(data)){
validate2546.errors = [{}];
return false;
}
}
}
}
validate2546.errors = vErrors;
return errors === 0;
}
validate2546.evaluated = {"dynamicProps":false,"dynamicItems":false};


function validate2542(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2542.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((((data.origin === undefined) && (missing0 = "origin")) || ((data.operation === undefined) && (missing0 = "operation"))) || ((data.ordinal === undefined) && (missing0 = "ordinal"))){
validate2542.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "origin") || (key0 === "operation")) || (key0 === "ordinal"))){
validate2542.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.origin !== undefined){
const _errs2 = errors;
if(!(validate2543(data.origin, {instancePath:instancePath+"/origin",parentData:data,parentDataProperty:"origin",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2543.errors : vErrors.concat(validate2543.errors);
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
if(!(validate2543(data.operation, {instancePath:instancePath+"/operation",parentData:data,parentDataProperty:"operation",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2543.errors : vErrors.concat(validate2543.errors);
errors = vErrors.length;
}
var valid0 = _errs3 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.ordinal !== undefined){
const _errs4 = errors;
if(!(validate2546(data.ordinal, {instancePath:instancePath+"/ordinal",parentData:data,parentDataProperty:"ordinal",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2546.errors : vErrors.concat(validate2546.errors);
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
validate2542.errors = [{}];
return false;
}
}
validate2542.errors = vErrors;
return errors === 0;
}
validate2542.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema697 = {"type":"object","additionalProperties":false,"properties":{"interpretation":{"$ref":"#/$defs/CatalogResponse/$defs/T60"},"content":{"$ref":"#/$defs/CatalogResponse/$defs/T64"},"schema_fingerprint":{"$ref":"#/$defs/CatalogResponse/$defs/T57"},"retired":{"$ref":"#/$defs/CatalogResponse/$defs/T65"}},"required":["interpretation","content","schema_fingerprint","retired"]};
const schema698 = {"type":"object","additionalProperties":false,"properties":{"object":{"$ref":"#/$defs/CatalogResponse/$defs/T61"},"revision":{"$ref":"#/$defs/CatalogResponse/$defs/T57"},"digest":{"$ref":"#/$defs/CatalogResponse/$defs/T57"}},"required":["object","revision","digest"]};
const schema699 = {"type":"object","additionalProperties":false,"properties":{"scope":{"$ref":"#/$defs/CatalogResponse/$defs/T62"},"branch":{"$ref":"#/$defs/CatalogResponse/$defs/T57"},"object":{"$ref":"#/$defs/CatalogResponse/$defs/T57"}},"required":["scope","branch","object"]};
const schema700 = {"type":"object","additionalProperties":false,"properties":{"realm":{"$ref":"#/$defs/CatalogResponse/$defs/T63"},"resource":{"$ref":"#/$defs/CatalogResponse/$defs/T63"},"catalog":{"$ref":"#/$defs/CatalogResponse/$defs/T57"}},"required":["realm","resource","catalog"]};

function validate2553(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2553.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(!(((typeof data == "number") && (!(data % 1) && !isNaN(data))) && (isFinite(data)))){
validate2553.errors = [{}];
return false;
}
if(errors === 0){
if((typeof data == "number") && (isFinite(data))){
if(data > 9007199254740991 || isNaN(data)){
validate2553.errors = [{}];
return false;
}
else {
if(data < 0 || isNaN(data)){
validate2553.errors = [{}];
return false;
}
}
}
}
validate2553.errors = vErrors;
return errors === 0;
}
validate2553.evaluated = {"dynamicProps":false,"dynamicItems":false};


function validate2552(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2552.evaluated;
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
validate2552.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "realm") || (key0 === "resource")) || (key0 === "catalog"))){
validate2552.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.realm !== undefined){
const _errs2 = errors;
if(!(validate2553(data.realm, {instancePath:instancePath+"/realm",parentData:data,parentDataProperty:"realm",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2553.errors : vErrors.concat(validate2553.errors);
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
if(!(validate2553(data.resource, {instancePath:instancePath+"/resource",parentData:data,parentDataProperty:"resource",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2553.errors : vErrors.concat(validate2553.errors);
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
if(!(validate2543(data.catalog, {instancePath:instancePath+"/catalog",parentData:data,parentDataProperty:"catalog",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2543.errors : vErrors.concat(validate2543.errors);
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
validate2552.errors = [{}];
return false;
}
}
validate2552.errors = vErrors;
return errors === 0;
}
validate2552.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate2551(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2551.evaluated;
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
validate2551.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "scope") || (key0 === "branch")) || (key0 === "object"))){
validate2551.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.scope !== undefined){
const _errs2 = errors;
if(!(validate2552(data.scope, {instancePath:instancePath+"/scope",parentData:data,parentDataProperty:"scope",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2552.errors : vErrors.concat(validate2552.errors);
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
if(!(validate2543(data.branch, {instancePath:instancePath+"/branch",parentData:data,parentDataProperty:"branch",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2543.errors : vErrors.concat(validate2543.errors);
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
if(!(validate2543(data.object, {instancePath:instancePath+"/object",parentData:data,parentDataProperty:"object",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2543.errors : vErrors.concat(validate2543.errors);
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
validate2551.errors = [{}];
return false;
}
}
validate2551.errors = vErrors;
return errors === 0;
}
validate2551.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate2550(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2550.evaluated;
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
validate2550.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "object") || (key0 === "revision")) || (key0 === "digest"))){
validate2550.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.object !== undefined){
const _errs2 = errors;
if(!(validate2551(data.object, {instancePath:instancePath+"/object",parentData:data,parentDataProperty:"object",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2551.errors : vErrors.concat(validate2551.errors);
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
if(!(validate2543(data.revision, {instancePath:instancePath+"/revision",parentData:data,parentDataProperty:"revision",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2543.errors : vErrors.concat(validate2543.errors);
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
if(!(validate2543(data.digest, {instancePath:instancePath+"/digest",parentData:data,parentDataProperty:"digest",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2543.errors : vErrors.concat(validate2543.errors);
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
validate2550.errors = [{}];
return false;
}
}
validate2550.errors = vErrors;
return errors === 0;
}
validate2550.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema702 = {"type":"object","additionalProperties":false,"properties":{"bytes":{"$ref":"#/$defs/CatalogResponse/$defs/T57"},"sha256":{"$ref":"#/$defs/CatalogResponse/$defs/T57"}},"required":["bytes","sha256"]};

function validate2564(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2564.evaluated;
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
validate2564.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "bytes") || (key0 === "sha256"))){
validate2564.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.bytes !== undefined){
const _errs2 = errors;
if(!(validate2543(data.bytes, {instancePath:instancePath+"/bytes",parentData:data,parentDataProperty:"bytes",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2543.errors : vErrors.concat(validate2543.errors);
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
if(!(validate2543(data.sha256, {instancePath:instancePath+"/sha256",parentData:data,parentDataProperty:"sha256",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2543.errors : vErrors.concat(validate2543.errors);
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
validate2564.errors = [{}];
return false;
}
}
validate2564.errors = vErrors;
return errors === 0;
}
validate2564.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema703 = {"type":"boolean"};

function validate2569(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2569.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "boolean"){
validate2569.errors = [{}];
return false;
}
validate2569.errors = vErrors;
return errors === 0;
}
validate2569.evaluated = {"dynamicProps":false,"dynamicItems":false};


function validate2549(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2549.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if(((((data.interpretation === undefined) && (missing0 = "interpretation")) || ((data.content === undefined) && (missing0 = "content"))) || ((data.schema_fingerprint === undefined) && (missing0 = "schema_fingerprint"))) || ((data.retired === undefined) && (missing0 = "retired"))){
validate2549.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((((key0 === "interpretation") || (key0 === "content")) || (key0 === "schema_fingerprint")) || (key0 === "retired"))){
validate2549.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.interpretation !== undefined){
const _errs2 = errors;
if(!(validate2550(data.interpretation, {instancePath:instancePath+"/interpretation",parentData:data,parentDataProperty:"interpretation",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2550.errors : vErrors.concat(validate2550.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.content !== undefined){
const _errs3 = errors;
if(!(validate2564(data.content, {instancePath:instancePath+"/content",parentData:data,parentDataProperty:"content",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2564.errors : vErrors.concat(validate2564.errors);
errors = vErrors.length;
}
var valid0 = _errs3 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.schema_fingerprint !== undefined){
const _errs4 = errors;
if(!(validate2543(data.schema_fingerprint, {instancePath:instancePath+"/schema_fingerprint",parentData:data,parentDataProperty:"schema_fingerprint",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2543.errors : vErrors.concat(validate2543.errors);
errors = vErrors.length;
}
var valid0 = _errs4 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.retired !== undefined){
const _errs5 = errors;
if(!(validate2569(data.retired, {instancePath:instancePath+"/retired",parentData:data,parentDataProperty:"retired",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2569.errors : vErrors.concat(validate2569.errors);
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
validate2549.errors = [{}];
return false;
}
}
validate2549.errors = vErrors;
return errors === 0;
}
validate2549.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema704 = {"oneOf":[{"type":"object","additionalProperties":false,"required":["wal"],"properties":{"wal":{"$ref":"#/$defs/CatalogResponse/$defs/T67"}}},{"type":"object","additionalProperties":false,"required":["segment"],"properties":{"segment":{"$ref":"#/$defs/CatalogResponse/$defs/T68"}}}]};
const schema705 = {"type":"object","additionalProperties":false,"properties":{"lsn":{"$ref":"#/$defs/CatalogResponse/$defs/T57"},"offset":{"$ref":"#/$defs/CatalogResponse/$defs/T58"},"bytes":{"$ref":"#/$defs/CatalogResponse/$defs/T58"},"row_digest":{"$ref":"#/$defs/CatalogResponse/$defs/T57"}},"required":["lsn","offset","bytes","row_digest"]};

function validate2574(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2574.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if(((((data.lsn === undefined) && (missing0 = "lsn")) || ((data.offset === undefined) && (missing0 = "offset"))) || ((data.bytes === undefined) && (missing0 = "bytes"))) || ((data.row_digest === undefined) && (missing0 = "row_digest"))){
validate2574.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((((key0 === "lsn") || (key0 === "offset")) || (key0 === "bytes")) || (key0 === "row_digest"))){
validate2574.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.lsn !== undefined){
const _errs2 = errors;
if(!(validate2543(data.lsn, {instancePath:instancePath+"/lsn",parentData:data,parentDataProperty:"lsn",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2543.errors : vErrors.concat(validate2543.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.offset !== undefined){
const _errs3 = errors;
if(!(validate2546(data.offset, {instancePath:instancePath+"/offset",parentData:data,parentDataProperty:"offset",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2546.errors : vErrors.concat(validate2546.errors);
errors = vErrors.length;
}
var valid0 = _errs3 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.bytes !== undefined){
const _errs4 = errors;
if(!(validate2546(data.bytes, {instancePath:instancePath+"/bytes",parentData:data,parentDataProperty:"bytes",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2546.errors : vErrors.concat(validate2546.errors);
errors = vErrors.length;
}
var valid0 = _errs4 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.row_digest !== undefined){
const _errs5 = errors;
if(!(validate2543(data.row_digest, {instancePath:instancePath+"/row_digest",parentData:data,parentDataProperty:"row_digest",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2543.errors : vErrors.concat(validate2543.errors);
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
validate2574.errors = [{}];
return false;
}
}
validate2574.errors = vErrors;
return errors === 0;
}
validate2574.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema706 = {"type":"object","additionalProperties":false,"properties":{"id":{"$ref":"#/$defs/CatalogResponse/$defs/T57"},"row":{"$ref":"#/$defs/CatalogResponse/$defs/T58"},"content":{"$ref":"#/$defs/CatalogResponse/$defs/T64"}},"required":["id","row","content"]};

function validate2580(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2580.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((((data.id === undefined) && (missing0 = "id")) || ((data.row === undefined) && (missing0 = "row"))) || ((data.content === undefined) && (missing0 = "content"))){
validate2580.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "id") || (key0 === "row")) || (key0 === "content"))){
validate2580.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.id !== undefined){
const _errs2 = errors;
if(!(validate2543(data.id, {instancePath:instancePath+"/id",parentData:data,parentDataProperty:"id",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2543.errors : vErrors.concat(validate2543.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.row !== undefined){
const _errs3 = errors;
if(!(validate2546(data.row, {instancePath:instancePath+"/row",parentData:data,parentDataProperty:"row",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2546.errors : vErrors.concat(validate2546.errors);
errors = vErrors.length;
}
var valid0 = _errs3 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.content !== undefined){
const _errs4 = errors;
if(!(validate2564(data.content, {instancePath:instancePath+"/content",parentData:data,parentDataProperty:"content",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2564.errors : vErrors.concat(validate2564.errors);
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
validate2580.errors = [{}];
return false;
}
}
validate2580.errors = vErrors;
return errors === 0;
}
validate2580.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate2573(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2573.evaluated;
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
if((data.wal === undefined) && (missing0 = "wal")){
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
const _errs3 = errors;
for(const key0 in data){
if(!(key0 === "wal")){
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
if(_errs3 === errors){
if(data.wal !== undefined){
if(!(validate2574(data.wal, {instancePath:instancePath+"/wal",parentData:data,parentDataProperty:"wal",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2574.errors : vErrors.concat(validate2574.errors);
errors = vErrors.length;
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
var _valid0 = _errs1 === errors;
if(_valid0){
valid0 = true;
passing0 = 0;
var props0 = true;
}
const _errs5 = errors;
if(errors === _errs5){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing1;
if((data.segment === undefined) && (missing1 = "segment")){
const err3 = {};
if(vErrors === null){
vErrors = [err3];
}
else {
vErrors.push(err3);
}
errors++;
}
else {
const _errs7 = errors;
for(const key1 in data){
if(!(key1 === "segment")){
const err4 = {};
if(vErrors === null){
vErrors = [err4];
}
else {
vErrors.push(err4);
}
errors++;
break;
}
}
if(_errs7 === errors){
if(data.segment !== undefined){
if(!(validate2580(data.segment, {instancePath:instancePath+"/segment",parentData:data,parentDataProperty:"segment",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2580.errors : vErrors.concat(validate2580.errors);
errors = vErrors.length;
}
}
}
}
}
else {
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
var _valid0 = _errs5 === errors;
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
}
if(!valid0){
const err6 = {};
if(vErrors === null){
vErrors = [err6];
}
else {
vErrors.push(err6);
}
errors++;
validate2573.errors = vErrors;
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
validate2573.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate2573.evaluated = {"dynamicProps":true,"dynamicItems":false};


function validate2541(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2541.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if(((((data.identity === undefined) && (missing0 = "identity")) || ((data.physical === undefined) && (missing0 = "physical"))) || ((data.schema_revision === undefined) && (missing0 = "schema_revision"))) || ((data.location === undefined) && (missing0 = "location"))){
validate2541.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((((key0 === "identity") || (key0 === "physical")) || (key0 === "schema_revision")) || (key0 === "location"))){
validate2541.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.identity !== undefined){
const _errs2 = errors;
if(!(validate2542(data.identity, {instancePath:instancePath+"/identity",parentData:data,parentDataProperty:"identity",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2542.errors : vErrors.concat(validate2542.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.physical !== undefined){
const _errs3 = errors;
if(!(validate2549(data.physical, {instancePath:instancePath+"/physical",parentData:data,parentDataProperty:"physical",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2549.errors : vErrors.concat(validate2549.errors);
errors = vErrors.length;
}
var valid0 = _errs3 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.schema_revision !== undefined){
const _errs4 = errors;
if(!(validate2543(data.schema_revision, {instancePath:instancePath+"/schema_revision",parentData:data,parentDataProperty:"schema_revision",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2543.errors : vErrors.concat(validate2543.errors);
errors = vErrors.length;
}
var valid0 = _errs4 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.location !== undefined){
const _errs5 = errors;
if(!(validate2573(data.location, {instancePath:instancePath+"/location",parentData:data,parentDataProperty:"location",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2573.errors : vErrors.concat(validate2573.errors);
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
validate2541.errors = [{}];
return false;
}
}
validate2541.errors = vErrors;
return errors === 0;
}
validate2541.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate2540(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2540.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(Array.isArray(data)){
if(data.length > 8){
validate2540.errors = [{}];
return false;
}
else {
var valid0 = true;
const len0 = data.length;
for(let i0=0; i0<len0; i0++){
const _errs1 = errors;
if(!(validate2541(data[i0], {instancePath:instancePath+"/" + i0,parentData:data,parentDataProperty:i0,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2541.errors : vErrors.concat(validate2541.errors);
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
validate2540.errors = [{}];
return false;
}
}
validate2540.errors = vErrors;
return errors === 0;
}
validate2540.evaluated = {"items":true,"dynamicProps":false,"dynamicItems":false};

const schema707 = {"anyOf":[{"$ref":"#/$defs/CatalogResponse/$defs/T70"},{"type":"null"}]};
const schema708 = {"type":"object","additionalProperties":false,"properties":{"selector":{"$ref":"#/$defs/CatalogResponse/$defs/T11"},"object":{"$ref":"#/$defs/CatalogResponse/$defs/T11"},"kind":{"$ref":"#/$defs/CatalogResponse/$defs/T71"},"source":{"$ref":"#/$defs/CatalogResponse/$defs/T38"},"after":{"$ref":"#/$defs/CatalogResponse/$defs/T11"}},"required":["selector","object","kind","source","after"]};

function validate2592(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2592.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate2592.errors = [{}];
return false;
}
if(!((data === "definitions") || (data === "locations"))){
validate2592.errors = [{}];
return false;
}
validate2592.errors = vErrors;
return errors === 0;
}
validate2592.evaluated = {"dynamicProps":false,"dynamicItems":false};


function validate2589(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2589.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((((((data.selector === undefined) && (missing0 = "selector")) || ((data.object === undefined) && (missing0 = "object"))) || ((data.kind === undefined) && (missing0 = "kind"))) || ((data.source === undefined) && (missing0 = "source"))) || ((data.after === undefined) && (missing0 = "after"))){
validate2589.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((((key0 === "selector") || (key0 === "object")) || (key0 === "kind")) || (key0 === "source")) || (key0 === "after"))){
validate2589.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.selector !== undefined){
const _errs2 = errors;
if(!(validate2367(data.selector, {instancePath:instancePath+"/selector",parentData:data,parentDataProperty:"selector",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2367.errors : vErrors.concat(validate2367.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.object !== undefined){
const _errs3 = errors;
if(!(validate2367(data.object, {instancePath:instancePath+"/object",parentData:data,parentDataProperty:"object",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2367.errors : vErrors.concat(validate2367.errors);
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
if(!(validate2592(data.kind, {instancePath:instancePath+"/kind",parentData:data,parentDataProperty:"kind",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2592.errors : vErrors.concat(validate2592.errors);
errors = vErrors.length;
}
var valid0 = _errs4 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.source !== undefined){
const _errs5 = errors;
if(!(validate2481(data.source, {instancePath:instancePath+"/source",parentData:data,parentDataProperty:"source",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2481.errors : vErrors.concat(validate2481.errors);
errors = vErrors.length;
}
var valid0 = _errs5 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.after !== undefined){
const _errs6 = errors;
if(!(validate2367(data.after, {instancePath:instancePath+"/after",parentData:data,parentDataProperty:"after",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2367.errors : vErrors.concat(validate2367.errors);
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
validate2589.errors = [{}];
return false;
}
}
validate2589.errors = vErrors;
return errors === 0;
}
validate2589.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate2588(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2588.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate2589(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2589.errors : vErrors.concat(validate2589.errors);
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
validate2588.errors = vErrors;
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
validate2588.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate2588.evaluated = {"dynamicProps":true,"dynamicItems":false};


function validate2471(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2471.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((((((((data.snapshot === undefined) && (missing0 = "snapshot")) || ((data.logical === undefined) && (missing0 = "logical"))) || ((data.accepted === undefined) && (missing0 = "accepted"))) || ((data.total_rows === undefined) && (missing0 = "total_rows"))) || ((data.definitions === undefined) && (missing0 = "definitions"))) || ((data.locations === undefined) && (missing0 = "locations"))) || ((data.next === undefined) && (missing0 = "next"))){
validate2471.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((((((key0 === "snapshot") || (key0 === "logical")) || (key0 === "accepted")) || (key0 === "total_rows")) || (key0 === "definitions")) || (key0 === "locations")) || (key0 === "next"))){
validate2471.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.snapshot !== undefined){
const _errs2 = errors;
if(!(validate2472(data.snapshot, {instancePath:instancePath+"/snapshot",parentData:data,parentDataProperty:"snapshot",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2472.errors : vErrors.concat(validate2472.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.logical !== undefined){
const _errs3 = errors;
if(!(validate2498(data.logical, {instancePath:instancePath+"/logical",parentData:data,parentDataProperty:"logical",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2498.errors : vErrors.concat(validate2498.errors);
errors = vErrors.length;
}
var valid0 = _errs3 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.accepted !== undefined){
const _errs4 = errors;
if(!(validate2435(data.accepted, {instancePath:instancePath+"/accepted",parentData:data,parentDataProperty:"accepted",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2435.errors : vErrors.concat(validate2435.errors);
errors = vErrors.length;
}
var valid0 = _errs4 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.total_rows !== undefined){
const _errs5 = errors;
if(!(validate2367(data.total_rows, {instancePath:instancePath+"/total_rows",parentData:data,parentDataProperty:"total_rows",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2367.errors : vErrors.concat(validate2367.errors);
errors = vErrors.length;
}
var valid0 = _errs5 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.definitions !== undefined){
const _errs6 = errors;
if(!(validate2506(data.definitions, {instancePath:instancePath+"/definitions",parentData:data,parentDataProperty:"definitions",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2506.errors : vErrors.concat(validate2506.errors);
errors = vErrors.length;
}
var valid0 = _errs6 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.locations !== undefined){
const _errs7 = errors;
if(!(validate2540(data.locations, {instancePath:instancePath+"/locations",parentData:data,parentDataProperty:"locations",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2540.errors : vErrors.concat(validate2540.errors);
errors = vErrors.length;
}
var valid0 = _errs7 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.next !== undefined){
const _errs8 = errors;
if(!(validate2588(data.next, {instancePath:instancePath+"/next",parentData:data,parentDataProperty:"next",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2588.errors : vErrors.concat(validate2588.errors);
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
validate2471.errors = [{}];
return false;
}
}
validate2471.errors = vErrors;
return errors === 0;
}
validate2471.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema710 = {"anyOf":[{"$ref":"#/$defs/CatalogResponse/$defs/T11"},{"type":"null"}]};

function validate2599(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2599.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate2367(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2367.errors : vErrors.concat(validate2367.errors);
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
validate2599.errors = vErrors;
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
validate2599.errors = vErrors;
return errors === 0;
}
validate2599.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema711 = {"anyOf":[{"$ref":"#/$defs/CatalogResponse/$defs/T74"},{"type":"null"}]};
const schema712 = {"type":"object","additionalProperties":false,"properties":{"scope":{"$ref":"#/$defs/CatalogResponse/$defs/T9"},"id":{"$ref":"#/$defs/CatalogResponse/$defs/T10"},"authorization":{"$ref":"#/$defs/CatalogResponse/$defs/T10"},"name":{"$ref":"#/$defs/CatalogResponse/$defs/T11"},"revision":{"$ref":"#/$defs/CatalogResponse/$defs/T11"}},"required":["scope","id","authorization","name","revision"]};

function validate2603(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2603.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((((((data.scope === undefined) && (missing0 = "scope")) || ((data.id === undefined) && (missing0 = "id"))) || ((data.authorization === undefined) && (missing0 = "authorization"))) || ((data.name === undefined) && (missing0 = "name"))) || ((data.revision === undefined) && (missing0 = "revision"))){
validate2603.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((((key0 === "scope") || (key0 === "id")) || (key0 === "authorization")) || (key0 === "name")) || (key0 === "revision"))){
validate2603.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.scope !== undefined){
const _errs2 = errors;
if(!(validate2363(data.scope, {instancePath:instancePath+"/scope",parentData:data,parentDataProperty:"scope",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2363.errors : vErrors.concat(validate2363.errors);
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
if(!(validate2364(data.id, {instancePath:instancePath+"/id",parentData:data,parentDataProperty:"id",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2364.errors : vErrors.concat(validate2364.errors);
errors = vErrors.length;
}
var valid0 = _errs3 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.authorization !== undefined){
const _errs4 = errors;
if(!(validate2364(data.authorization, {instancePath:instancePath+"/authorization",parentData:data,parentDataProperty:"authorization",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2364.errors : vErrors.concat(validate2364.errors);
errors = vErrors.length;
}
var valid0 = _errs4 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.name !== undefined){
const _errs5 = errors;
if(!(validate2367(data.name, {instancePath:instancePath+"/name",parentData:data,parentDataProperty:"name",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2367.errors : vErrors.concat(validate2367.errors);
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
if(!(validate2367(data.revision, {instancePath:instancePath+"/revision",parentData:data,parentDataProperty:"revision",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2367.errors : vErrors.concat(validate2367.errors);
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
validate2603.errors = [{}];
return false;
}
}
validate2603.errors = vErrors;
return errors === 0;
}
validate2603.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate2602(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2602.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate2603(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2603.errors : vErrors.concat(validate2603.errors);
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
validate2602.errors = vErrors;
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
validate2602.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate2602.evaluated = {"dynamicProps":true,"dynamicItems":false};

const schema713 = {"type":"object","additionalProperties":false,"properties":{"snapshot":{"$ref":"#/$defs/CatalogResponse/$defs/T36"},"namespace":{"$ref":"#/$defs/CatalogResponse/$defs/T10"},"entries":{"$ref":"#/$defs/CatalogResponse/$defs/T76"},"next":{"$ref":"#/$defs/CatalogResponse/$defs/T80"}},"required":["snapshot","namespace","entries","next"]};
const schema714 = {"type":"array","maxItems":8,"items":{"$ref":"#/$defs/CatalogResponse/$defs/T77"}};
const schema715 = {"type":"object","additionalProperties":false,"properties":{"namespace":{"$ref":"#/$defs/CatalogResponse/$defs/T78"},"name":{"$ref":"#/$defs/CatalogResponse/$defs/T57"},"declaration":{"$ref":"#/$defs/CatalogResponse/$defs/T59"},"accepted":{"$ref":"#/$defs/CatalogResponse/$defs/T79"},"catalog":{"$ref":"#/$defs/CatalogResponse/$defs/T79"}},"required":["namespace","name","declaration","accepted","catalog"]};
const schema716 = {"type":"object","additionalProperties":false,"properties":{"scope":{"$ref":"#/$defs/CatalogResponse/$defs/T62"},"id":{"$ref":"#/$defs/CatalogResponse/$defs/T63"},"authorization":{"$ref":"#/$defs/CatalogResponse/$defs/T63"},"name":{"$ref":"#/$defs/CatalogResponse/$defs/T57"},"revision":{"$ref":"#/$defs/CatalogResponse/$defs/T57"}},"required":["scope","id","authorization","name","revision"]};

function validate2616(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2616.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((((((data.scope === undefined) && (missing0 = "scope")) || ((data.id === undefined) && (missing0 = "id"))) || ((data.authorization === undefined) && (missing0 = "authorization"))) || ((data.name === undefined) && (missing0 = "name"))) || ((data.revision === undefined) && (missing0 = "revision"))){
validate2616.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((((key0 === "scope") || (key0 === "id")) || (key0 === "authorization")) || (key0 === "name")) || (key0 === "revision"))){
validate2616.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.scope !== undefined){
const _errs2 = errors;
if(!(validate2552(data.scope, {instancePath:instancePath+"/scope",parentData:data,parentDataProperty:"scope",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2552.errors : vErrors.concat(validate2552.errors);
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
if(!(validate2553(data.id, {instancePath:instancePath+"/id",parentData:data,parentDataProperty:"id",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2553.errors : vErrors.concat(validate2553.errors);
errors = vErrors.length;
}
var valid0 = _errs3 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.authorization !== undefined){
const _errs4 = errors;
if(!(validate2553(data.authorization, {instancePath:instancePath+"/authorization",parentData:data,parentDataProperty:"authorization",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2553.errors : vErrors.concat(validate2553.errors);
errors = vErrors.length;
}
var valid0 = _errs4 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.name !== undefined){
const _errs5 = errors;
if(!(validate2543(data.name, {instancePath:instancePath+"/name",parentData:data,parentDataProperty:"name",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2543.errors : vErrors.concat(validate2543.errors);
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
if(!(validate2543(data.revision, {instancePath:instancePath+"/revision",parentData:data,parentDataProperty:"revision",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2543.errors : vErrors.concat(validate2543.errors);
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
validate2616.errors = [{}];
return false;
}
}
validate2616.errors = vErrors;
return errors === 0;
}
validate2616.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema717 = {"type":"object","additionalProperties":false,"properties":{"partition":{"$ref":"#/$defs/CatalogResponse/$defs/T57"},"next_lsn":{"$ref":"#/$defs/CatalogResponse/$defs/T57"}},"required":["partition","next_lsn"]};

function validate2625(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2625.evaluated;
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
validate2625.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "partition") || (key0 === "next_lsn"))){
validate2625.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.partition !== undefined){
const _errs2 = errors;
if(!(validate2543(data.partition, {instancePath:instancePath+"/partition",parentData:data,parentDataProperty:"partition",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2543.errors : vErrors.concat(validate2543.errors);
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
if(!(validate2543(data.next_lsn, {instancePath:instancePath+"/next_lsn",parentData:data,parentDataProperty:"next_lsn",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2543.errors : vErrors.concat(validate2543.errors);
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
validate2625.errors = [{}];
return false;
}
}
validate2625.errors = vErrors;
return errors === 0;
}
validate2625.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate2615(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2615.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((((((data.namespace === undefined) && (missing0 = "namespace")) || ((data.name === undefined) && (missing0 = "name"))) || ((data.declaration === undefined) && (missing0 = "declaration"))) || ((data.accepted === undefined) && (missing0 = "accepted"))) || ((data.catalog === undefined) && (missing0 = "catalog"))){
validate2615.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((((key0 === "namespace") || (key0 === "name")) || (key0 === "declaration")) || (key0 === "accepted")) || (key0 === "catalog"))){
validate2615.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.namespace !== undefined){
const _errs2 = errors;
if(!(validate2616(data.namespace, {instancePath:instancePath+"/namespace",parentData:data,parentDataProperty:"namespace",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2616.errors : vErrors.concat(validate2616.errors);
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
if(!(validate2543(data.name, {instancePath:instancePath+"/name",parentData:data,parentDataProperty:"name",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2543.errors : vErrors.concat(validate2543.errors);
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
if(!(validate2549(data.declaration, {instancePath:instancePath+"/declaration",parentData:data,parentDataProperty:"declaration",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2549.errors : vErrors.concat(validate2549.errors);
errors = vErrors.length;
}
var valid0 = _errs4 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.accepted !== undefined){
const _errs5 = errors;
if(!(validate2625(data.accepted, {instancePath:instancePath+"/accepted",parentData:data,parentDataProperty:"accepted",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2625.errors : vErrors.concat(validate2625.errors);
errors = vErrors.length;
}
var valid0 = _errs5 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.catalog !== undefined){
const _errs6 = errors;
if(!(validate2625(data.catalog, {instancePath:instancePath+"/catalog",parentData:data,parentDataProperty:"catalog",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2625.errors : vErrors.concat(validate2625.errors);
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
validate2615.errors = [{}];
return false;
}
}
validate2615.errors = vErrors;
return errors === 0;
}
validate2615.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate2614(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2614.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(Array.isArray(data)){
if(data.length > 8){
validate2614.errors = [{}];
return false;
}
else {
var valid0 = true;
const len0 = data.length;
for(let i0=0; i0<len0; i0++){
const _errs1 = errors;
if(!(validate2615(data[i0], {instancePath:instancePath+"/" + i0,parentData:data,parentDataProperty:i0,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2615.errors : vErrors.concat(validate2615.errors);
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
validate2614.errors = [{}];
return false;
}
}
validate2614.errors = vErrors;
return errors === 0;
}
validate2614.evaluated = {"items":true,"dynamicProps":false,"dynamicItems":false};

const schema718 = {"anyOf":[{"$ref":"#/$defs/CatalogResponse/$defs/T81"},{"type":"null"}]};
const schema719 = {"type":"object","additionalProperties":false,"properties":{"selector":{"$ref":"#/$defs/CatalogResponse/$defs/T11"},"namespace":{"$ref":"#/$defs/CatalogResponse/$defs/T10"},"directory":{"$ref":"#/$defs/CatalogResponse/$defs/T82"},"after":{"$ref":"#/$defs/CatalogResponse/$defs/T11"}},"required":["selector","namespace","directory","after"]};
const schema720 = {"type":"object","additionalProperties":false,"properties":{"content":{"$ref":"#/$defs/CatalogResponse/$defs/T38"},"count":{"$ref":"#/$defs/CatalogResponse/$defs/T11"},"descriptors":{"$ref":"#/$defs/CatalogResponse/$defs/T11"}},"required":["content","count","descriptors"]};

function validate2636(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2636.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((((data.content === undefined) && (missing0 = "content")) || ((data.count === undefined) && (missing0 = "count"))) || ((data.descriptors === undefined) && (missing0 = "descriptors"))){
validate2636.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "content") || (key0 === "count")) || (key0 === "descriptors"))){
validate2636.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.content !== undefined){
const _errs2 = errors;
if(!(validate2481(data.content, {instancePath:instancePath+"/content",parentData:data,parentDataProperty:"content",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2481.errors : vErrors.concat(validate2481.errors);
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
if(!(validate2367(data.count, {instancePath:instancePath+"/count",parentData:data,parentDataProperty:"count",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2367.errors : vErrors.concat(validate2367.errors);
errors = vErrors.length;
}
var valid0 = _errs3 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.descriptors !== undefined){
const _errs4 = errors;
if(!(validate2367(data.descriptors, {instancePath:instancePath+"/descriptors",parentData:data,parentDataProperty:"descriptors",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2367.errors : vErrors.concat(validate2367.errors);
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
validate2636.errors = [{}];
return false;
}
}
validate2636.errors = vErrors;
return errors === 0;
}
validate2636.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate2633(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2633.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if(((((data.selector === undefined) && (missing0 = "selector")) || ((data.namespace === undefined) && (missing0 = "namespace"))) || ((data.directory === undefined) && (missing0 = "directory"))) || ((data.after === undefined) && (missing0 = "after"))){
validate2633.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((((key0 === "selector") || (key0 === "namespace")) || (key0 === "directory")) || (key0 === "after"))){
validate2633.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.selector !== undefined){
const _errs2 = errors;
if(!(validate2367(data.selector, {instancePath:instancePath+"/selector",parentData:data,parentDataProperty:"selector",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2367.errors : vErrors.concat(validate2367.errors);
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
if(!(validate2364(data.namespace, {instancePath:instancePath+"/namespace",parentData:data,parentDataProperty:"namespace",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2364.errors : vErrors.concat(validate2364.errors);
errors = vErrors.length;
}
var valid0 = _errs3 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.directory !== undefined){
const _errs4 = errors;
if(!(validate2636(data.directory, {instancePath:instancePath+"/directory",parentData:data,parentDataProperty:"directory",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2636.errors : vErrors.concat(validate2636.errors);
errors = vErrors.length;
}
var valid0 = _errs4 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.after !== undefined){
const _errs5 = errors;
if(!(validate2367(data.after, {instancePath:instancePath+"/after",parentData:data,parentDataProperty:"after",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2367.errors : vErrors.concat(validate2367.errors);
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
validate2633.errors = [{}];
return false;
}
}
validate2633.errors = vErrors;
return errors === 0;
}
validate2633.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate2632(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2632.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate2633(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2633.errors : vErrors.concat(validate2633.errors);
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
validate2632.errors = vErrors;
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
validate2632.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate2632.evaluated = {"dynamicProps":true,"dynamicItems":false};


function validate2611(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2611.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if(((((data.snapshot === undefined) && (missing0 = "snapshot")) || ((data.namespace === undefined) && (missing0 = "namespace"))) || ((data.entries === undefined) && (missing0 = "entries"))) || ((data.next === undefined) && (missing0 = "next"))){
validate2611.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((((key0 === "snapshot") || (key0 === "namespace")) || (key0 === "entries")) || (key0 === "next"))){
validate2611.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.snapshot !== undefined){
const _errs2 = errors;
if(!(validate2472(data.snapshot, {instancePath:instancePath+"/snapshot",parentData:data,parentDataProperty:"snapshot",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2472.errors : vErrors.concat(validate2472.errors);
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
if(!(validate2364(data.namespace, {instancePath:instancePath+"/namespace",parentData:data,parentDataProperty:"namespace",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2364.errors : vErrors.concat(validate2364.errors);
errors = vErrors.length;
}
var valid0 = _errs3 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.entries !== undefined){
const _errs4 = errors;
if(!(validate2614(data.entries, {instancePath:instancePath+"/entries",parentData:data,parentDataProperty:"entries",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2614.errors : vErrors.concat(validate2614.errors);
errors = vErrors.length;
}
var valid0 = _errs4 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.next !== undefined){
const _errs5 = errors;
if(!(validate2632(data.next, {instancePath:instancePath+"/next",parentData:data,parentDataProperty:"next",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2632.errors : vErrors.concat(validate2632.errors);
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
validate2611.errors = [{}];
return false;
}
}
validate2611.errors = vErrors;
return errors === 0;
}
validate2611.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema721 = {"type":"object","additionalProperties":false,"properties":{"snapshot":{"$ref":"#/$defs/CatalogResponse/$defs/T36"},"binding":{"$ref":"#/$defs/CatalogResponse/$defs/T84"},"schema":{"$ref":"#/$defs/CatalogResponse/$defs/T85"},"rows":{"$ref":"#/$defs/CatalogResponse/$defs/T11"},"changed_lsn":{"$ref":"#/$defs/CatalogResponse/$defs/T11"},"authority":{"$ref":"#/$defs/CatalogResponse/$defs/T197"}},"required":["snapshot","binding","schema","rows","changed_lsn","authority"]};
const schema722 = {"type":"object","additionalProperties":false,"properties":{"namespace":{"$ref":"#/$defs/CatalogResponse/$defs/T74"},"name":{"$ref":"#/$defs/CatalogResponse/$defs/T11"},"declaration":{"$ref":"#/$defs/CatalogResponse/$defs/T41"},"accepted":{"$ref":"#/$defs/CatalogResponse/$defs/T26"},"catalog":{"$ref":"#/$defs/CatalogResponse/$defs/T26"}},"required":["namespace","name","declaration","accepted","catalog"]};

function validate2647(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2647.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((((((data.namespace === undefined) && (missing0 = "namespace")) || ((data.name === undefined) && (missing0 = "name"))) || ((data.declaration === undefined) && (missing0 = "declaration"))) || ((data.accepted === undefined) && (missing0 = "accepted"))) || ((data.catalog === undefined) && (missing0 = "catalog"))){
validate2647.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((((key0 === "namespace") || (key0 === "name")) || (key0 === "declaration")) || (key0 === "accepted")) || (key0 === "catalog"))){
validate2647.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.namespace !== undefined){
const _errs2 = errors;
if(!(validate2603(data.namespace, {instancePath:instancePath+"/namespace",parentData:data,parentDataProperty:"namespace",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2603.errors : vErrors.concat(validate2603.errors);
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
if(!(validate2367(data.name, {instancePath:instancePath+"/name",parentData:data,parentDataProperty:"name",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2367.errors : vErrors.concat(validate2367.errors);
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
if(!(validate2498(data.declaration, {instancePath:instancePath+"/declaration",parentData:data,parentDataProperty:"declaration",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2498.errors : vErrors.concat(validate2498.errors);
errors = vErrors.length;
}
var valid0 = _errs4 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.accepted !== undefined){
const _errs5 = errors;
if(!(validate2435(data.accepted, {instancePath:instancePath+"/accepted",parentData:data,parentDataProperty:"accepted",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2435.errors : vErrors.concat(validate2435.errors);
errors = vErrors.length;
}
var valid0 = _errs5 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.catalog !== undefined){
const _errs6 = errors;
if(!(validate2435(data.catalog, {instancePath:instancePath+"/catalog",parentData:data,parentDataProperty:"catalog",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2435.errors : vErrors.concat(validate2435.errors);
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
validate2647.errors = [{}];
return false;
}
}
validate2647.errors = vErrors;
return errors === 0;
}
validate2647.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema723 = {"type":"object","additionalProperties":false,"properties":{"definition":{"$ref":"#/$defs/CatalogResponse/$defs/T4"},"object":{"$ref":"#/$defs/CatalogResponse/$defs/T11"},"revision":{"$ref":"#/$defs/CatalogResponse/$defs/T11"},"next_column":{"$ref":"#/$defs/CatalogResponse/$defs/T11"},"columns":{"$ref":"#/$defs/CatalogResponse/$defs/T86"},"primary_key":{"$ref":"#/$defs/CatalogResponse/$defs/T166"},"integrity":{"$ref":"#/$defs/CatalogResponse/$defs/T167"}},"required":["definition","object","revision","next_column","columns","primary_key","integrity"]};
const schema724 = {"type":"array","maxItems":128,"items":{"$ref":"#/$defs/CatalogResponse/$defs/T87"}};
const schema725 = {"type":"object","additionalProperties":false,"properties":{"id":{"$ref":"#/$defs/CatalogResponse/$defs/T46"},"name":{"$ref":"#/$defs/CatalogResponse/$defs/T46"},"type":{"$ref":"#/$defs/CatalogResponse/$defs/T88"},"nullable":{"$ref":"#/$defs/CatalogResponse/$defs/T107"},"default":{"$ref":"#/$defs/CatalogResponse/$defs/T113"},"max_characters":{"$ref":"#/$defs/CatalogResponse/$defs/T145"},"encoding":{"$ref":"#/$defs/CatalogResponse/$defs/T146"},"collation":{"$ref":"#/$defs/CatalogResponse/$defs/T147"},"semantics":{"$ref":"#/$defs/CatalogResponse/$defs/T148"}},"required":["id","name","type","nullable","default","max_characters","encoding","collation","semantics"]};
const schema726 = {"oneOf":[{"type":"object","additionalProperties":false,"required":["int64"],"properties":{"int64":{"$ref":"#/$defs/CatalogResponse/$defs/T89"}}},{"type":"object","additionalProperties":false,"required":["uint64"],"properties":{"uint64":{"$ref":"#/$defs/CatalogResponse/$defs/T89"}}},{"type":"object","additionalProperties":false,"required":["float64"],"properties":{"float64":{"$ref":"#/$defs/CatalogResponse/$defs/T89"}}},{"type":"object","additionalProperties":false,"required":["boolean"],"properties":{"boolean":{"$ref":"#/$defs/CatalogResponse/$defs/T89"}}},{"type":"object","additionalProperties":false,"required":["utf8"],"properties":{"utf8":{"$ref":"#/$defs/CatalogResponse/$defs/T89"}}},{"type":"object","additionalProperties":false,"required":["binary"],"properties":{"binary":{"$ref":"#/$defs/CatalogResponse/$defs/T89"}}},{"type":"object","additionalProperties":false,"required":["int8"],"properties":{"int8":{"$ref":"#/$defs/CatalogResponse/$defs/T89"}}},{"type":"object","additionalProperties":false,"required":["int16"],"properties":{"int16":{"$ref":"#/$defs/CatalogResponse/$defs/T89"}}},{"type":"object","additionalProperties":false,"required":["int32"],"properties":{"int32":{"$ref":"#/$defs/CatalogResponse/$defs/T89"}}},{"type":"object","additionalProperties":false,"required":["int128"],"properties":{"int128":{"$ref":"#/$defs/CatalogResponse/$defs/T89"}}},{"type":"object","additionalProperties":false,"required":["uint8"],"properties":{"uint8":{"$ref":"#/$defs/CatalogResponse/$defs/T89"}}},{"type":"object","additionalProperties":false,"required":["uint16"],"properties":{"uint16":{"$ref":"#/$defs/CatalogResponse/$defs/T89"}}},{"type":"object","additionalProperties":false,"required":["uint32"],"properties":{"uint32":{"$ref":"#/$defs/CatalogResponse/$defs/T89"}}},{"type":"object","additionalProperties":false,"required":["uint128"],"properties":{"uint128":{"$ref":"#/$defs/CatalogResponse/$defs/T89"}}},{"type":"object","additionalProperties":false,"required":["float32"],"properties":{"float32":{"$ref":"#/$defs/CatalogResponse/$defs/T89"}}},{"type":"object","additionalProperties":false,"required":["decimal"],"properties":{"decimal":{"$ref":"#/$defs/CatalogResponse/$defs/T90"}}},{"type":"object","additionalProperties":false,"required":["date"],"properties":{"date":{"$ref":"#/$defs/CatalogResponse/$defs/T89"}}},{"type":"object","additionalProperties":false,"required":["time"],"properties":{"time":{"$ref":"#/$defs/CatalogResponse/$defs/T89"}}},{"type":"object","additionalProperties":false,"required":["timestamp"],"properties":{"timestamp":{"$ref":"#/$defs/CatalogResponse/$defs/T92"}}},{"type":"object","additionalProperties":false,"required":["interval"],"properties":{"interval":{"$ref":"#/$defs/CatalogResponse/$defs/T89"}}},{"type":"object","additionalProperties":false,"required":["uuid"],"properties":{"uuid":{"$ref":"#/$defs/CatalogResponse/$defs/T89"}}},{"type":"object","additionalProperties":false,"required":["structure"],"properties":{"structure":{"$ref":"#/$defs/CatalogResponse/$defs/T93"}}},{"type":"object","additionalProperties":false,"required":["list"],"properties":{"list":{"$ref":"#/$defs/CatalogResponse/$defs/T105"}}},{"type":"object","additionalProperties":false,"required":["array"],"properties":{"array":{"$ref":"#/$defs/CatalogResponse/$defs/T108"}}},{"type":"object","additionalProperties":false,"required":["map"],"properties":{"map":{"$ref":"#/$defs/CatalogResponse/$defs/T110"}}},{"type":"object","additionalProperties":false,"required":["tagged_union"],"properties":{"tagged_union":{"$ref":"#/$defs/CatalogResponse/$defs/T93"}}},{"type":"object","additionalProperties":false,"required":["json"],"properties":{"json":{"$ref":"#/$defs/CatalogResponse/$defs/T89"}}},{"type":"object","additionalProperties":false,"required":["range"],"properties":{"range":{"$ref":"#/$defs/CatalogResponse/$defs/T106"}}},{"type":"object","additionalProperties":false,"required":["multirange"],"properties":{"multirange":{"$ref":"#/$defs/CatalogResponse/$defs/T106"}}},{"type":"object","additionalProperties":false,"required":["vector"],"properties":{"vector":{"$ref":"#/$defs/CatalogResponse/$defs/T111"}}},{"type":"object","additionalProperties":false,"required":["capability"],"properties":{"capability":{"$ref":"#/$defs/CatalogResponse/$defs/T89"}}}]};
const schema727 = {"type":"object","maxProperties":0};

function validate2664(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2664.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
if(Object.keys(data).length > 0){
validate2664.errors = [{}];
return false;
}
}
else {
validate2664.errors = [{}];
return false;
}
}
validate2664.errors = vErrors;
return errors === 0;
}
validate2664.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema728 = {"type":"object","additionalProperties":false,"properties":{"precision":{"$ref":"#/$defs/CatalogResponse/$defs/T91"},"scale":{"$ref":"#/$defs/CatalogResponse/$defs/T91"}},"required":["precision","scale"]};

function validate2681(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2681.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(!(((typeof data == "number") && (!(data % 1) && !isNaN(data))) && (isFinite(data)))){
validate2681.errors = [{}];
return false;
}
if(errors === 0){
if((typeof data == "number") && (isFinite(data))){
if(data > 255 || isNaN(data)){
validate2681.errors = [{}];
return false;
}
else {
if(data < 0 || isNaN(data)){
validate2681.errors = [{}];
return false;
}
}
}
}
validate2681.errors = vErrors;
return errors === 0;
}
validate2681.evaluated = {"dynamicProps":false,"dynamicItems":false};


function validate2680(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2680.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if(((data.precision === undefined) && (missing0 = "precision")) || ((data.scale === undefined) && (missing0 = "scale"))){
validate2680.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "precision") || (key0 === "scale"))){
validate2680.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.precision !== undefined){
const _errs2 = errors;
if(!(validate2681(data.precision, {instancePath:instancePath+"/precision",parentData:data,parentDataProperty:"precision",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2681.errors : vErrors.concat(validate2681.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.scale !== undefined){
const _errs3 = errors;
if(!(validate2681(data.scale, {instancePath:instancePath+"/scale",parentData:data,parentDataProperty:"scale",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2681.errors : vErrors.concat(validate2681.errors);
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
validate2680.errors = [{}];
return false;
}
}
validate2680.errors = vErrors;
return errors === 0;
}
validate2680.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema181 = {"type":"string","enum":["civil","utc"]};

function validate2687(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2687.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate2687.errors = [{}];
return false;
}
if(!((data === "civil") || (data === "utc"))){
validate2687.errors = [{}];
return false;
}
validate2687.errors = vErrors;
return errors === 0;
}
validate2687.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema731 = {"type":"array","maxItems":256,"items":{"$ref":"#/$defs/CatalogResponse/$defs/T94"}};
const schema732 = {"type":"object","additionalProperties":false,"properties":{"name":{"$ref":"#/$defs/CatalogResponse/$defs/T11"},"type":{"$ref":"#/$defs/CatalogResponse/$defs/T95"},"nullable":{"$ref":"#/$defs/CatalogResponse/$defs/T17"},"optional":{"$ref":"#/$defs/CatalogResponse/$defs/T17"},"max_characters":{"$ref":"#/$defs/CatalogResponse/$defs/T104"}},"required":["name","type","nullable","optional","max_characters"]};
const schema733 = {"oneOf":[{"type":"object","additionalProperties":false,"required":["int64"],"properties":{"int64":{"$ref":"#/$defs/CatalogResponse/$defs/T25"}}},{"type":"object","additionalProperties":false,"required":["uint64"],"properties":{"uint64":{"$ref":"#/$defs/CatalogResponse/$defs/T25"}}},{"type":"object","additionalProperties":false,"required":["float64"],"properties":{"float64":{"$ref":"#/$defs/CatalogResponse/$defs/T25"}}},{"type":"object","additionalProperties":false,"required":["boolean"],"properties":{"boolean":{"$ref":"#/$defs/CatalogResponse/$defs/T25"}}},{"type":"object","additionalProperties":false,"required":["utf8"],"properties":{"utf8":{"$ref":"#/$defs/CatalogResponse/$defs/T25"}}},{"type":"object","additionalProperties":false,"required":["binary"],"properties":{"binary":{"$ref":"#/$defs/CatalogResponse/$defs/T25"}}},{"type":"object","additionalProperties":false,"required":["int8"],"properties":{"int8":{"$ref":"#/$defs/CatalogResponse/$defs/T25"}}},{"type":"object","additionalProperties":false,"required":["int16"],"properties":{"int16":{"$ref":"#/$defs/CatalogResponse/$defs/T25"}}},{"type":"object","additionalProperties":false,"required":["int32"],"properties":{"int32":{"$ref":"#/$defs/CatalogResponse/$defs/T25"}}},{"type":"object","additionalProperties":false,"required":["int128"],"properties":{"int128":{"$ref":"#/$defs/CatalogResponse/$defs/T25"}}},{"type":"object","additionalProperties":false,"required":["uint8"],"properties":{"uint8":{"$ref":"#/$defs/CatalogResponse/$defs/T25"}}},{"type":"object","additionalProperties":false,"required":["uint16"],"properties":{"uint16":{"$ref":"#/$defs/CatalogResponse/$defs/T25"}}},{"type":"object","additionalProperties":false,"required":["uint32"],"properties":{"uint32":{"$ref":"#/$defs/CatalogResponse/$defs/T25"}}},{"type":"object","additionalProperties":false,"required":["uint128"],"properties":{"uint128":{"$ref":"#/$defs/CatalogResponse/$defs/T25"}}},{"type":"object","additionalProperties":false,"required":["float32"],"properties":{"float32":{"$ref":"#/$defs/CatalogResponse/$defs/T25"}}},{"type":"object","additionalProperties":false,"required":["decimal"],"properties":{"decimal":{"$ref":"#/$defs/CatalogResponse/$defs/T96"}}},{"type":"object","additionalProperties":false,"required":["date"],"properties":{"date":{"$ref":"#/$defs/CatalogResponse/$defs/T25"}}},{"type":"object","additionalProperties":false,"required":["time"],"properties":{"time":{"$ref":"#/$defs/CatalogResponse/$defs/T25"}}},{"type":"object","additionalProperties":false,"required":["timestamp"],"properties":{"timestamp":{"$ref":"#/$defs/CatalogResponse/$defs/T97"}}},{"type":"object","additionalProperties":false,"required":["interval"],"properties":{"interval":{"$ref":"#/$defs/CatalogResponse/$defs/T25"}}},{"type":"object","additionalProperties":false,"required":["uuid"],"properties":{"uuid":{"$ref":"#/$defs/CatalogResponse/$defs/T25"}}},{"type":"object","additionalProperties":false,"required":["structure"],"properties":{"structure":{"$ref":"#/$defs/CatalogResponse/$defs/T93"}}},{"type":"object","additionalProperties":false,"required":["list"],"properties":{"list":{"$ref":"#/$defs/CatalogResponse/$defs/T98"}}},{"type":"object","additionalProperties":false,"required":["array"],"properties":{"array":{"$ref":"#/$defs/CatalogResponse/$defs/T100"}}},{"type":"object","additionalProperties":false,"required":["map"],"properties":{"map":{"$ref":"#/$defs/CatalogResponse/$defs/T101"}}},{"type":"object","additionalProperties":false,"required":["tagged_union"],"properties":{"tagged_union":{"$ref":"#/$defs/CatalogResponse/$defs/T93"}}},{"type":"object","additionalProperties":false,"required":["json"],"properties":{"json":{"$ref":"#/$defs/CatalogResponse/$defs/T25"}}},{"type":"object","additionalProperties":false,"required":["range"],"properties":{"range":{"$ref":"#/$defs/CatalogResponse/$defs/T99"}}},{"type":"object","additionalProperties":false,"required":["multirange"],"properties":{"multirange":{"$ref":"#/$defs/CatalogResponse/$defs/T99"}}},{"type":"object","additionalProperties":false,"required":["vector"],"properties":{"vector":{"$ref":"#/$defs/CatalogResponse/$defs/T102"}}},{"type":"object","additionalProperties":false,"required":["capability"],"properties":{"capability":{"$ref":"#/$defs/CatalogResponse/$defs/T25"}}}]};
const schema734 = {"type":"object","additionalProperties":false,"properties":{"precision":{"$ref":"#/$defs/CatalogResponse/$defs/T3"},"scale":{"$ref":"#/$defs/CatalogResponse/$defs/T3"}},"required":["precision","scale"]};

function validate2710(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2710.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if(((data.precision === undefined) && (missing0 = "precision")) || ((data.scale === undefined) && (missing0 = "scale"))){
validate2710.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "precision") || (key0 === "scale"))){
validate2710.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.precision !== undefined){
const _errs2 = errors;
if(!(validate2347(data.precision, {instancePath:instancePath+"/precision",parentData:data,parentDataProperty:"precision",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2347.errors : vErrors.concat(validate2347.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.scale !== undefined){
const _errs3 = errors;
if(!(validate2347(data.scale, {instancePath:instancePath+"/scale",parentData:data,parentDataProperty:"scale",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2347.errors : vErrors.concat(validate2347.errors);
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
validate2710.errors = [{}];
return false;
}
}
validate2710.errors = vErrors;
return errors === 0;
}
validate2710.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate2716(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2716.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate2716.errors = [{}];
return false;
}
if(!((data === "civil") || (data === "utc"))){
validate2716.errors = [{}];
return false;
}
validate2716.errors = vErrors;
return errors === 0;
}
validate2716.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema736 = {"type":"object","additionalProperties":false,"properties":{"type":{"$ref":"#/$defs/CatalogResponse/$defs/T99"},"nullable":{"$ref":"#/$defs/CatalogResponse/$defs/T17"}},"required":["type","nullable"]};
const wrapper37 = {validate: validate2694};

function validate2720(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2720.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if(((data.type === undefined) && (missing0 = "type")) || ((data.nullable === undefined) && (missing0 = "nullable"))){
validate2720.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "type") || (key0 === "nullable"))){
validate2720.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.type !== undefined){
const _errs2 = errors;
if(!(wrapper37.validate(data.type, {instancePath:instancePath+"/type",parentData:data,parentDataProperty:"type",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? wrapper37.validate.errors : vErrors.concat(wrapper37.validate.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.nullable !== undefined){
const _errs3 = errors;
if(!(validate2409(data.nullable, {instancePath:instancePath+"/nullable",parentData:data,parentDataProperty:"nullable",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2409.errors : vErrors.concat(validate2409.errors);
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
validate2720.errors = [{}];
return false;
}
}
validate2720.errors = vErrors;
return errors === 0;
}
validate2720.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema737 = {"type":"object","additionalProperties":false,"properties":{"element":{"$ref":"#/$defs/CatalogResponse/$defs/T98"},"length":{"$ref":"#/$defs/CatalogResponse/$defs/T6"}},"required":["element","length"]};

function validate2723(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2723.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if(((data.element === undefined) && (missing0 = "element")) || ((data.length === undefined) && (missing0 = "length"))){
validate2723.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "element") || (key0 === "length"))){
validate2723.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.element !== undefined){
const _errs2 = errors;
if(!(validate2720(data.element, {instancePath:instancePath+"/element",parentData:data,parentDataProperty:"element",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2720.errors : vErrors.concat(validate2720.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.length !== undefined){
const _errs3 = errors;
if(!(validate2355(data.length, {instancePath:instancePath+"/length",parentData:data,parentDataProperty:"length",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2355.errors : vErrors.concat(validate2355.errors);
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
validate2723.errors = [{}];
return false;
}
}
validate2723.errors = vErrors;
return errors === 0;
}
validate2723.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema738 = {"type":"object","additionalProperties":false,"properties":{"key":{"$ref":"#/$defs/CatalogResponse/$defs/T99"},"value":{"$ref":"#/$defs/CatalogResponse/$defs/T98"}},"required":["key","value"]};

function validate2727(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2727.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if(((data.key === undefined) && (missing0 = "key")) || ((data.value === undefined) && (missing0 = "value"))){
validate2727.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "key") || (key0 === "value"))){
validate2727.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.key !== undefined){
const _errs2 = errors;
if(!(wrapper37.validate(data.key, {instancePath:instancePath+"/key",parentData:data,parentDataProperty:"key",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? wrapper37.validate.errors : vErrors.concat(wrapper37.validate.errors);
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
if(!(validate2720(data.value, {instancePath:instancePath+"/value",parentData:data,parentDataProperty:"value",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2720.errors : vErrors.concat(validate2720.errors);
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
validate2727.errors = [{}];
return false;
}
}
validate2727.errors = vErrors;
return errors === 0;
}
validate2727.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema739 = {"type":"object","additionalProperties":false,"properties":{"dimensions":{"$ref":"#/$defs/CatalogResponse/$defs/T6"},"element":{"$ref":"#/$defs/CatalogResponse/$defs/T103"}},"required":["dimensions","element"]};
const schema197 = {"type":"string","enum":["float32","float16","bfloat16","int8","binary"]};

function validate2733(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2733.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate2733.errors = [{}];
return false;
}
if(!(((((data === "float32") || (data === "float16")) || (data === "bfloat16")) || (data === "int8")) || (data === "binary"))){
validate2733.errors = [{}];
return false;
}
validate2733.errors = vErrors;
return errors === 0;
}
validate2733.evaluated = {"dynamicProps":false,"dynamicItems":false};


function validate2731(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2731.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if(((data.dimensions === undefined) && (missing0 = "dimensions")) || ((data.element === undefined) && (missing0 = "element"))){
validate2731.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "dimensions") || (key0 === "element"))){
validate2731.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.dimensions !== undefined){
const _errs2 = errors;
if(!(validate2355(data.dimensions, {instancePath:instancePath+"/dimensions",parentData:data,parentDataProperty:"dimensions",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2355.errors : vErrors.concat(validate2355.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.element !== undefined){
const _errs3 = errors;
if(!(validate2733(data.element, {instancePath:instancePath+"/element",parentData:data,parentDataProperty:"element",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2733.errors : vErrors.concat(validate2733.errors);
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
validate2731.errors = [{}];
return false;
}
}
validate2731.errors = vErrors;
return errors === 0;
}
validate2731.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const wrapper36 = {validate: validate2691};

function validate2694(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2694.evaluated;
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
if((data.int64 === undefined) && (missing0 = "int64")){
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
const _errs3 = errors;
for(const key0 in data){
if(!(key0 === "int64")){
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
if(_errs3 === errors){
if(data.int64 !== undefined){
if(!(validate2430(data.int64, {instancePath:instancePath+"/int64",parentData:data,parentDataProperty:"int64",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2430.errors : vErrors.concat(validate2430.errors);
errors = vErrors.length;
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
var _valid0 = _errs1 === errors;
if(_valid0){
valid0 = true;
passing0 = 0;
var props0 = true;
}
const _errs5 = errors;
if(errors === _errs5){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing1;
if((data.uint64 === undefined) && (missing1 = "uint64")){
const err3 = {};
if(vErrors === null){
vErrors = [err3];
}
else {
vErrors.push(err3);
}
errors++;
}
else {
const _errs7 = errors;
for(const key1 in data){
if(!(key1 === "uint64")){
const err4 = {};
if(vErrors === null){
vErrors = [err4];
}
else {
vErrors.push(err4);
}
errors++;
break;
}
}
if(_errs7 === errors){
if(data.uint64 !== undefined){
if(!(validate2430(data.uint64, {instancePath:instancePath+"/uint64",parentData:data,parentDataProperty:"uint64",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2430.errors : vErrors.concat(validate2430.errors);
errors = vErrors.length;
}
}
}
}
}
else {
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
var _valid0 = _errs5 === errors;
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
const _errs9 = errors;
if(errors === _errs9){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing2;
if((data.float64 === undefined) && (missing2 = "float64")){
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
const _errs11 = errors;
for(const key2 in data){
if(!(key2 === "float64")){
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
if(_errs11 === errors){
if(data.float64 !== undefined){
if(!(validate2430(data.float64, {instancePath:instancePath+"/float64",parentData:data,parentDataProperty:"float64",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2430.errors : vErrors.concat(validate2430.errors);
errors = vErrors.length;
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
var _valid0 = _errs9 === errors;
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
const _errs13 = errors;
if(errors === _errs13){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing3;
if((data.boolean === undefined) && (missing3 = "boolean")){
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
const _errs15 = errors;
for(const key3 in data){
if(!(key3 === "boolean")){
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
if(_errs15 === errors){
if(data.boolean !== undefined){
if(!(validate2430(data.boolean, {instancePath:instancePath+"/boolean",parentData:data,parentDataProperty:"boolean",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2430.errors : vErrors.concat(validate2430.errors);
errors = vErrors.length;
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
var _valid0 = _errs13 === errors;
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
const _errs17 = errors;
if(errors === _errs17){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing4;
if((data.utf8 === undefined) && (missing4 = "utf8")){
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
const _errs19 = errors;
for(const key4 in data){
if(!(key4 === "utf8")){
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
if(_errs19 === errors){
if(data.utf8 !== undefined){
if(!(validate2430(data.utf8, {instancePath:instancePath+"/utf8",parentData:data,parentDataProperty:"utf8",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2430.errors : vErrors.concat(validate2430.errors);
errors = vErrors.length;
}
}
}
}
}
else {
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
var _valid0 = _errs17 === errors;
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
const _errs21 = errors;
if(errors === _errs21){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing5;
if((data.binary === undefined) && (missing5 = "binary")){
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
const _errs23 = errors;
for(const key5 in data){
if(!(key5 === "binary")){
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
if(_errs23 === errors){
if(data.binary !== undefined){
if(!(validate2430(data.binary, {instancePath:instancePath+"/binary",parentData:data,parentDataProperty:"binary",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2430.errors : vErrors.concat(validate2430.errors);
errors = vErrors.length;
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
var _valid0 = _errs21 === errors;
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
const _errs25 = errors;
if(errors === _errs25){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing6;
if((data.int8 === undefined) && (missing6 = "int8")){
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
const _errs27 = errors;
for(const key6 in data){
if(!(key6 === "int8")){
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
if(_errs27 === errors){
if(data.int8 !== undefined){
if(!(validate2430(data.int8, {instancePath:instancePath+"/int8",parentData:data,parentDataProperty:"int8",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2430.errors : vErrors.concat(validate2430.errors);
errors = vErrors.length;
}
}
}
}
}
else {
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
var _valid0 = _errs25 === errors;
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
const _errs29 = errors;
if(errors === _errs29){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing7;
if((data.int16 === undefined) && (missing7 = "int16")){
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
const _errs31 = errors;
for(const key7 in data){
if(!(key7 === "int16")){
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
if(_errs31 === errors){
if(data.int16 !== undefined){
if(!(validate2430(data.int16, {instancePath:instancePath+"/int16",parentData:data,parentDataProperty:"int16",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2430.errors : vErrors.concat(validate2430.errors);
errors = vErrors.length;
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
var _valid0 = _errs29 === errors;
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
const _errs33 = errors;
if(errors === _errs33){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing8;
if((data.int32 === undefined) && (missing8 = "int32")){
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
const _errs35 = errors;
for(const key8 in data){
if(!(key8 === "int32")){
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
if(_errs35 === errors){
if(data.int32 !== undefined){
if(!(validate2430(data.int32, {instancePath:instancePath+"/int32",parentData:data,parentDataProperty:"int32",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2430.errors : vErrors.concat(validate2430.errors);
errors = vErrors.length;
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
var _valid0 = _errs33 === errors;
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
const _errs37 = errors;
if(errors === _errs37){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing9;
if((data.int128 === undefined) && (missing9 = "int128")){
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
const _errs39 = errors;
for(const key9 in data){
if(!(key9 === "int128")){
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
if(_errs39 === errors){
if(data.int128 !== undefined){
if(!(validate2430(data.int128, {instancePath:instancePath+"/int128",parentData:data,parentDataProperty:"int128",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2430.errors : vErrors.concat(validate2430.errors);
errors = vErrors.length;
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
var _valid0 = _errs37 === errors;
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
const _errs41 = errors;
if(errors === _errs41){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing10;
if((data.uint8 === undefined) && (missing10 = "uint8")){
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
const _errs43 = errors;
for(const key10 in data){
if(!(key10 === "uint8")){
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
if(_errs43 === errors){
if(data.uint8 !== undefined){
if(!(validate2430(data.uint8, {instancePath:instancePath+"/uint8",parentData:data,parentDataProperty:"uint8",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2430.errors : vErrors.concat(validate2430.errors);
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
var _valid0 = _errs41 === errors;
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
const _errs45 = errors;
if(errors === _errs45){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing11;
if((data.uint16 === undefined) && (missing11 = "uint16")){
const err33 = {};
if(vErrors === null){
vErrors = [err33];
}
else {
vErrors.push(err33);
}
errors++;
}
else {
const _errs47 = errors;
for(const key11 in data){
if(!(key11 === "uint16")){
const err34 = {};
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
if(_errs47 === errors){
if(data.uint16 !== undefined){
if(!(validate2430(data.uint16, {instancePath:instancePath+"/uint16",parentData:data,parentDataProperty:"uint16",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2430.errors : vErrors.concat(validate2430.errors);
errors = vErrors.length;
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
var _valid0 = _errs45 === errors;
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
const _errs49 = errors;
if(errors === _errs49){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing12;
if((data.uint32 === undefined) && (missing12 = "uint32")){
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
const _errs51 = errors;
for(const key12 in data){
if(!(key12 === "uint32")){
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
if(_errs51 === errors){
if(data.uint32 !== undefined){
if(!(validate2430(data.uint32, {instancePath:instancePath+"/uint32",parentData:data,parentDataProperty:"uint32",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2430.errors : vErrors.concat(validate2430.errors);
errors = vErrors.length;
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
var _valid0 = _errs49 === errors;
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
const _errs53 = errors;
if(errors === _errs53){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing13;
if((data.uint128 === undefined) && (missing13 = "uint128")){
const err39 = {};
if(vErrors === null){
vErrors = [err39];
}
else {
vErrors.push(err39);
}
errors++;
}
else {
const _errs55 = errors;
for(const key13 in data){
if(!(key13 === "uint128")){
const err40 = {};
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
if(_errs55 === errors){
if(data.uint128 !== undefined){
if(!(validate2430(data.uint128, {instancePath:instancePath+"/uint128",parentData:data,parentDataProperty:"uint128",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2430.errors : vErrors.concat(validate2430.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err41 = {};
if(vErrors === null){
vErrors = [err41];
}
else {
vErrors.push(err41);
}
errors++;
}
}
var _valid0 = _errs53 === errors;
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
const _errs57 = errors;
if(errors === _errs57){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing14;
if((data.float32 === undefined) && (missing14 = "float32")){
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
const _errs59 = errors;
for(const key14 in data){
if(!(key14 === "float32")){
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
if(_errs59 === errors){
if(data.float32 !== undefined){
if(!(validate2430(data.float32, {instancePath:instancePath+"/float32",parentData:data,parentDataProperty:"float32",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2430.errors : vErrors.concat(validate2430.errors);
errors = vErrors.length;
}
}
}
}
}
else {
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
var _valid0 = _errs57 === errors;
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
const _errs61 = errors;
if(errors === _errs61){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing15;
if((data.decimal === undefined) && (missing15 = "decimal")){
const err45 = {};
if(vErrors === null){
vErrors = [err45];
}
else {
vErrors.push(err45);
}
errors++;
}
else {
const _errs63 = errors;
for(const key15 in data){
if(!(key15 === "decimal")){
const err46 = {};
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
if(_errs63 === errors){
if(data.decimal !== undefined){
if(!(validate2710(data.decimal, {instancePath:instancePath+"/decimal",parentData:data,parentDataProperty:"decimal",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2710.errors : vErrors.concat(validate2710.errors);
errors = vErrors.length;
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
var _valid0 = _errs61 === errors;
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
const _errs65 = errors;
if(errors === _errs65){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing16;
if((data.date === undefined) && (missing16 = "date")){
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
const _errs67 = errors;
for(const key16 in data){
if(!(key16 === "date")){
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
if(_errs67 === errors){
if(data.date !== undefined){
if(!(validate2430(data.date, {instancePath:instancePath+"/date",parentData:data,parentDataProperty:"date",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2430.errors : vErrors.concat(validate2430.errors);
errors = vErrors.length;
}
}
}
}
}
else {
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
var _valid0 = _errs65 === errors;
if(_valid0 && valid0){
valid0 = false;
passing0 = [passing0, 16];
}
else {
if(_valid0){
valid0 = true;
passing0 = 16;
if(props0 !== true){
props0 = true;
}
}
const _errs69 = errors;
if(errors === _errs69){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing17;
if((data.time === undefined) && (missing17 = "time")){
const err51 = {};
if(vErrors === null){
vErrors = [err51];
}
else {
vErrors.push(err51);
}
errors++;
}
else {
const _errs71 = errors;
for(const key17 in data){
if(!(key17 === "time")){
const err52 = {};
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
if(_errs71 === errors){
if(data.time !== undefined){
if(!(validate2430(data.time, {instancePath:instancePath+"/time",parentData:data,parentDataProperty:"time",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2430.errors : vErrors.concat(validate2430.errors);
errors = vErrors.length;
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
var _valid0 = _errs69 === errors;
if(_valid0 && valid0){
valid0 = false;
passing0 = [passing0, 17];
}
else {
if(_valid0){
valid0 = true;
passing0 = 17;
if(props0 !== true){
props0 = true;
}
}
const _errs73 = errors;
if(errors === _errs73){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing18;
if((data.timestamp === undefined) && (missing18 = "timestamp")){
const err54 = {};
if(vErrors === null){
vErrors = [err54];
}
else {
vErrors.push(err54);
}
errors++;
}
else {
const _errs75 = errors;
for(const key18 in data){
if(!(key18 === "timestamp")){
const err55 = {};
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
if(_errs75 === errors){
if(data.timestamp !== undefined){
if(!(validate2716(data.timestamp, {instancePath:instancePath+"/timestamp",parentData:data,parentDataProperty:"timestamp",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2716.errors : vErrors.concat(validate2716.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err56 = {};
if(vErrors === null){
vErrors = [err56];
}
else {
vErrors.push(err56);
}
errors++;
}
}
var _valid0 = _errs73 === errors;
if(_valid0 && valid0){
valid0 = false;
passing0 = [passing0, 18];
}
else {
if(_valid0){
valid0 = true;
passing0 = 18;
if(props0 !== true){
props0 = true;
}
}
const _errs77 = errors;
if(errors === _errs77){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing19;
if((data.interval === undefined) && (missing19 = "interval")){
const err57 = {};
if(vErrors === null){
vErrors = [err57];
}
else {
vErrors.push(err57);
}
errors++;
}
else {
const _errs79 = errors;
for(const key19 in data){
if(!(key19 === "interval")){
const err58 = {};
if(vErrors === null){
vErrors = [err58];
}
else {
vErrors.push(err58);
}
errors++;
break;
}
}
if(_errs79 === errors){
if(data.interval !== undefined){
if(!(validate2430(data.interval, {instancePath:instancePath+"/interval",parentData:data,parentDataProperty:"interval",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2430.errors : vErrors.concat(validate2430.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err59 = {};
if(vErrors === null){
vErrors = [err59];
}
else {
vErrors.push(err59);
}
errors++;
}
}
var _valid0 = _errs77 === errors;
if(_valid0 && valid0){
valid0 = false;
passing0 = [passing0, 19];
}
else {
if(_valid0){
valid0 = true;
passing0 = 19;
if(props0 !== true){
props0 = true;
}
}
const _errs81 = errors;
if(errors === _errs81){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing20;
if((data.uuid === undefined) && (missing20 = "uuid")){
const err60 = {};
if(vErrors === null){
vErrors = [err60];
}
else {
vErrors.push(err60);
}
errors++;
}
else {
const _errs83 = errors;
for(const key20 in data){
if(!(key20 === "uuid")){
const err61 = {};
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
if(_errs83 === errors){
if(data.uuid !== undefined){
if(!(validate2430(data.uuid, {instancePath:instancePath+"/uuid",parentData:data,parentDataProperty:"uuid",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2430.errors : vErrors.concat(validate2430.errors);
errors = vErrors.length;
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
var _valid0 = _errs81 === errors;
if(_valid0 && valid0){
valid0 = false;
passing0 = [passing0, 20];
}
else {
if(_valid0){
valid0 = true;
passing0 = 20;
if(props0 !== true){
props0 = true;
}
}
const _errs85 = errors;
if(errors === _errs85){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing21;
if((data.structure === undefined) && (missing21 = "structure")){
const err63 = {};
if(vErrors === null){
vErrors = [err63];
}
else {
vErrors.push(err63);
}
errors++;
}
else {
const _errs87 = errors;
for(const key21 in data){
if(!(key21 === "structure")){
const err64 = {};
if(vErrors === null){
vErrors = [err64];
}
else {
vErrors.push(err64);
}
errors++;
break;
}
}
if(_errs87 === errors){
if(data.structure !== undefined){
if(!(wrapper36.validate(data.structure, {instancePath:instancePath+"/structure",parentData:data,parentDataProperty:"structure",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? wrapper36.validate.errors : vErrors.concat(wrapper36.validate.errors);
errors = vErrors.length;
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
var _valid0 = _errs85 === errors;
if(_valid0 && valid0){
valid0 = false;
passing0 = [passing0, 21];
}
else {
if(_valid0){
valid0 = true;
passing0 = 21;
if(props0 !== true){
props0 = true;
}
}
const _errs89 = errors;
if(errors === _errs89){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing22;
if((data.list === undefined) && (missing22 = "list")){
const err66 = {};
if(vErrors === null){
vErrors = [err66];
}
else {
vErrors.push(err66);
}
errors++;
}
else {
const _errs91 = errors;
for(const key22 in data){
if(!(key22 === "list")){
const err67 = {};
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
if(_errs91 === errors){
if(data.list !== undefined){
if(!(validate2720(data.list, {instancePath:instancePath+"/list",parentData:data,parentDataProperty:"list",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2720.errors : vErrors.concat(validate2720.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err68 = {};
if(vErrors === null){
vErrors = [err68];
}
else {
vErrors.push(err68);
}
errors++;
}
}
var _valid0 = _errs89 === errors;
if(_valid0 && valid0){
valid0 = false;
passing0 = [passing0, 22];
}
else {
if(_valid0){
valid0 = true;
passing0 = 22;
if(props0 !== true){
props0 = true;
}
}
const _errs93 = errors;
if(errors === _errs93){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing23;
if((data.array === undefined) && (missing23 = "array")){
const err69 = {};
if(vErrors === null){
vErrors = [err69];
}
else {
vErrors.push(err69);
}
errors++;
}
else {
const _errs95 = errors;
for(const key23 in data){
if(!(key23 === "array")){
const err70 = {};
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
if(_errs95 === errors){
if(data.array !== undefined){
if(!(validate2723(data.array, {instancePath:instancePath+"/array",parentData:data,parentDataProperty:"array",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2723.errors : vErrors.concat(validate2723.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err71 = {};
if(vErrors === null){
vErrors = [err71];
}
else {
vErrors.push(err71);
}
errors++;
}
}
var _valid0 = _errs93 === errors;
if(_valid0 && valid0){
valid0 = false;
passing0 = [passing0, 23];
}
else {
if(_valid0){
valid0 = true;
passing0 = 23;
if(props0 !== true){
props0 = true;
}
}
const _errs97 = errors;
if(errors === _errs97){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing24;
if((data.map === undefined) && (missing24 = "map")){
const err72 = {};
if(vErrors === null){
vErrors = [err72];
}
else {
vErrors.push(err72);
}
errors++;
}
else {
const _errs99 = errors;
for(const key24 in data){
if(!(key24 === "map")){
const err73 = {};
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
if(_errs99 === errors){
if(data.map !== undefined){
if(!(validate2727(data.map, {instancePath:instancePath+"/map",parentData:data,parentDataProperty:"map",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2727.errors : vErrors.concat(validate2727.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err74 = {};
if(vErrors === null){
vErrors = [err74];
}
else {
vErrors.push(err74);
}
errors++;
}
}
var _valid0 = _errs97 === errors;
if(_valid0 && valid0){
valid0 = false;
passing0 = [passing0, 24];
}
else {
if(_valid0){
valid0 = true;
passing0 = 24;
if(props0 !== true){
props0 = true;
}
}
const _errs101 = errors;
if(errors === _errs101){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing25;
if((data.tagged_union === undefined) && (missing25 = "tagged_union")){
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
const _errs103 = errors;
for(const key25 in data){
if(!(key25 === "tagged_union")){
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
if(_errs103 === errors){
if(data.tagged_union !== undefined){
if(!(wrapper36.validate(data.tagged_union, {instancePath:instancePath+"/tagged_union",parentData:data,parentDataProperty:"tagged_union",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? wrapper36.validate.errors : vErrors.concat(wrapper36.validate.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err77 = {};
if(vErrors === null){
vErrors = [err77];
}
else {
vErrors.push(err77);
}
errors++;
}
}
var _valid0 = _errs101 === errors;
if(_valid0 && valid0){
valid0 = false;
passing0 = [passing0, 25];
}
else {
if(_valid0){
valid0 = true;
passing0 = 25;
if(props0 !== true){
props0 = true;
}
}
const _errs105 = errors;
if(errors === _errs105){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing26;
if((data.json === undefined) && (missing26 = "json")){
const err78 = {};
if(vErrors === null){
vErrors = [err78];
}
else {
vErrors.push(err78);
}
errors++;
}
else {
const _errs107 = errors;
for(const key26 in data){
if(!(key26 === "json")){
const err79 = {};
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
if(_errs107 === errors){
if(data.json !== undefined){
if(!(validate2430(data.json, {instancePath:instancePath+"/json",parentData:data,parentDataProperty:"json",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2430.errors : vErrors.concat(validate2430.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err80 = {};
if(vErrors === null){
vErrors = [err80];
}
else {
vErrors.push(err80);
}
errors++;
}
}
var _valid0 = _errs105 === errors;
if(_valid0 && valid0){
valid0 = false;
passing0 = [passing0, 26];
}
else {
if(_valid0){
valid0 = true;
passing0 = 26;
if(props0 !== true){
props0 = true;
}
}
const _errs109 = errors;
if(errors === _errs109){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing27;
if((data.range === undefined) && (missing27 = "range")){
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
const _errs111 = errors;
for(const key27 in data){
if(!(key27 === "range")){
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
if(_errs111 === errors){
if(data.range !== undefined){
if(!(wrapper37.validate(data.range, {instancePath:instancePath+"/range",parentData:data,parentDataProperty:"range",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? wrapper37.validate.errors : vErrors.concat(wrapper37.validate.errors);
errors = vErrors.length;
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
var _valid0 = _errs109 === errors;
if(_valid0 && valid0){
valid0 = false;
passing0 = [passing0, 27];
}
else {
if(_valid0){
valid0 = true;
passing0 = 27;
if(props0 !== true){
props0 = true;
}
}
const _errs113 = errors;
if(errors === _errs113){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing28;
if((data.multirange === undefined) && (missing28 = "multirange")){
const err84 = {};
if(vErrors === null){
vErrors = [err84];
}
else {
vErrors.push(err84);
}
errors++;
}
else {
const _errs115 = errors;
for(const key28 in data){
if(!(key28 === "multirange")){
const err85 = {};
if(vErrors === null){
vErrors = [err85];
}
else {
vErrors.push(err85);
}
errors++;
break;
}
}
if(_errs115 === errors){
if(data.multirange !== undefined){
if(!(wrapper37.validate(data.multirange, {instancePath:instancePath+"/multirange",parentData:data,parentDataProperty:"multirange",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? wrapper37.validate.errors : vErrors.concat(wrapper37.validate.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err86 = {};
if(vErrors === null){
vErrors = [err86];
}
else {
vErrors.push(err86);
}
errors++;
}
}
var _valid0 = _errs113 === errors;
if(_valid0 && valid0){
valid0 = false;
passing0 = [passing0, 28];
}
else {
if(_valid0){
valid0 = true;
passing0 = 28;
if(props0 !== true){
props0 = true;
}
}
const _errs117 = errors;
if(errors === _errs117){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing29;
if((data.vector === undefined) && (missing29 = "vector")){
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
const _errs119 = errors;
for(const key29 in data){
if(!(key29 === "vector")){
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
if(_errs119 === errors){
if(data.vector !== undefined){
if(!(validate2731(data.vector, {instancePath:instancePath+"/vector",parentData:data,parentDataProperty:"vector",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2731.errors : vErrors.concat(validate2731.errors);
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
var _valid0 = _errs117 === errors;
if(_valid0 && valid0){
valid0 = false;
passing0 = [passing0, 29];
}
else {
if(_valid0){
valid0 = true;
passing0 = 29;
if(props0 !== true){
props0 = true;
}
}
const _errs121 = errors;
if(errors === _errs121){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing30;
if((data.capability === undefined) && (missing30 = "capability")){
const err90 = {};
if(vErrors === null){
vErrors = [err90];
}
else {
vErrors.push(err90);
}
errors++;
}
else {
const _errs123 = errors;
for(const key30 in data){
if(!(key30 === "capability")){
const err91 = {};
if(vErrors === null){
vErrors = [err91];
}
else {
vErrors.push(err91);
}
errors++;
break;
}
}
if(_errs123 === errors){
if(data.capability !== undefined){
if(!(validate2430(data.capability, {instancePath:instancePath+"/capability",parentData:data,parentDataProperty:"capability",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2430.errors : vErrors.concat(validate2430.errors);
errors = vErrors.length;
}
}
}
}
}
else {
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
var _valid0 = _errs121 === errors;
if(_valid0 && valid0){
valid0 = false;
passing0 = [passing0, 30];
}
else {
if(_valid0){
valid0 = true;
passing0 = 30;
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
}
}
}
}
}
}
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
const err93 = {};
if(vErrors === null){
vErrors = [err93];
}
else {
vErrors.push(err93);
}
errors++;
validate2694.errors = vErrors;
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
validate2694.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate2694.evaluated = {"dynamicProps":true,"dynamicItems":false};

const schema741 = {"anyOf":[{"$ref":"#/$defs/CatalogResponse/$defs/T6"},{"type":"null"}]};

function validate2740(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2740.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate2355(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2355.errors : vErrors.concat(validate2355.errors);
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
validate2740.errors = vErrors;
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
validate2740.errors = vErrors;
return errors === 0;
}
validate2740.evaluated = {"dynamicProps":false,"dynamicItems":false};


function validate2692(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2692.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((((((data.name === undefined) && (missing0 = "name")) || ((data.type === undefined) && (missing0 = "type"))) || ((data.nullable === undefined) && (missing0 = "nullable"))) || ((data.optional === undefined) && (missing0 = "optional"))) || ((data.max_characters === undefined) && (missing0 = "max_characters"))){
validate2692.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((((key0 === "name") || (key0 === "type")) || (key0 === "nullable")) || (key0 === "optional")) || (key0 === "max_characters"))){
validate2692.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.name !== undefined){
const _errs2 = errors;
if(!(validate2367(data.name, {instancePath:instancePath+"/name",parentData:data,parentDataProperty:"name",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2367.errors : vErrors.concat(validate2367.errors);
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
if(!(validate2694(data.type, {instancePath:instancePath+"/type",parentData:data,parentDataProperty:"type",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2694.errors : vErrors.concat(validate2694.errors);
errors = vErrors.length;
}
var valid0 = _errs3 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.nullable !== undefined){
const _errs4 = errors;
if(!(validate2409(data.nullable, {instancePath:instancePath+"/nullable",parentData:data,parentDataProperty:"nullable",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2409.errors : vErrors.concat(validate2409.errors);
errors = vErrors.length;
}
var valid0 = _errs4 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.optional !== undefined){
const _errs5 = errors;
if(!(validate2409(data.optional, {instancePath:instancePath+"/optional",parentData:data,parentDataProperty:"optional",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2409.errors : vErrors.concat(validate2409.errors);
errors = vErrors.length;
}
var valid0 = _errs5 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.max_characters !== undefined){
const _errs6 = errors;
if(!(validate2740(data.max_characters, {instancePath:instancePath+"/max_characters",parentData:data,parentDataProperty:"max_characters",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2740.errors : vErrors.concat(validate2740.errors);
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
validate2692.errors = [{}];
return false;
}
}
validate2692.errors = vErrors;
return errors === 0;
}
validate2692.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate2691(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2691.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(Array.isArray(data)){
if(data.length > 256){
validate2691.errors = [{}];
return false;
}
else {
var valid0 = true;
const len0 = data.length;
for(let i0=0; i0<len0; i0++){
const _errs1 = errors;
if(!(validate2692(data[i0], {instancePath:instancePath+"/" + i0,parentData:data,parentDataProperty:i0,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2692.errors : vErrors.concat(validate2692.errors);
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
validate2691.errors = [{}];
return false;
}
}
validate2691.errors = vErrors;
return errors === 0;
}
validate2691.evaluated = {"items":true,"dynamicProps":false,"dynamicItems":false};

const schema742 = {"type":"object","additionalProperties":false,"properties":{"type":{"$ref":"#/$defs/CatalogResponse/$defs/T106"},"nullable":{"$ref":"#/$defs/CatalogResponse/$defs/T107"}},"required":["type","nullable"]};
const wrapper42 = {validate: validate2663};
const schema743 = {"type":"boolean"};

function validate2746(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2746.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "boolean"){
validate2746.errors = [{}];
return false;
}
validate2746.errors = vErrors;
return errors === 0;
}
validate2746.evaluated = {"dynamicProps":false,"dynamicItems":false};


function validate2745(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2745.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if(((data.type === undefined) && (missing0 = "type")) || ((data.nullable === undefined) && (missing0 = "nullable"))){
validate2745.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "type") || (key0 === "nullable"))){
validate2745.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.type !== undefined){
const _errs2 = errors;
if(!(wrapper42.validate(data.type, {instancePath:instancePath+"/type",parentData:data,parentDataProperty:"type",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? wrapper42.validate.errors : vErrors.concat(wrapper42.validate.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.nullable !== undefined){
const _errs3 = errors;
if(!(validate2746(data.nullable, {instancePath:instancePath+"/nullable",parentData:data,parentDataProperty:"nullable",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2746.errors : vErrors.concat(validate2746.errors);
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
validate2745.errors = [{}];
return false;
}
}
validate2745.errors = vErrors;
return errors === 0;
}
validate2745.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema744 = {"type":"object","additionalProperties":false,"properties":{"element":{"$ref":"#/$defs/CatalogResponse/$defs/T105"},"length":{"$ref":"#/$defs/CatalogResponse/$defs/T109"}},"required":["element","length"]};

function validate2751(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2751.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(!(((typeof data == "number") && (!(data % 1) && !isNaN(data))) && (isFinite(data)))){
validate2751.errors = [{}];
return false;
}
if(errors === 0){
if((typeof data == "number") && (isFinite(data))){
if(data > 4294967295 || isNaN(data)){
validate2751.errors = [{}];
return false;
}
else {
if(data < 0 || isNaN(data)){
validate2751.errors = [{}];
return false;
}
}
}
}
validate2751.errors = vErrors;
return errors === 0;
}
validate2751.evaluated = {"dynamicProps":false,"dynamicItems":false};


function validate2749(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2749.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if(((data.element === undefined) && (missing0 = "element")) || ((data.length === undefined) && (missing0 = "length"))){
validate2749.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "element") || (key0 === "length"))){
validate2749.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.element !== undefined){
const _errs2 = errors;
if(!(validate2745(data.element, {instancePath:instancePath+"/element",parentData:data,parentDataProperty:"element",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2745.errors : vErrors.concat(validate2745.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.length !== undefined){
const _errs3 = errors;
if(!(validate2751(data.length, {instancePath:instancePath+"/length",parentData:data,parentDataProperty:"length",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2751.errors : vErrors.concat(validate2751.errors);
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
validate2749.errors = [{}];
return false;
}
}
validate2749.errors = vErrors;
return errors === 0;
}
validate2749.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema746 = {"type":"object","additionalProperties":false,"properties":{"key":{"$ref":"#/$defs/CatalogResponse/$defs/T106"},"value":{"$ref":"#/$defs/CatalogResponse/$defs/T105"}},"required":["key","value"]};

function validate2754(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2754.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if(((data.key === undefined) && (missing0 = "key")) || ((data.value === undefined) && (missing0 = "value"))){
validate2754.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "key") || (key0 === "value"))){
validate2754.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.key !== undefined){
const _errs2 = errors;
if(!(wrapper42.validate(data.key, {instancePath:instancePath+"/key",parentData:data,parentDataProperty:"key",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? wrapper42.validate.errors : vErrors.concat(wrapper42.validate.errors);
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
if(!(validate2745(data.value, {instancePath:instancePath+"/value",parentData:data,parentDataProperty:"value",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2745.errors : vErrors.concat(validate2745.errors);
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
validate2754.errors = [{}];
return false;
}
}
validate2754.errors = vErrors;
return errors === 0;
}
validate2754.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema747 = {"type":"object","additionalProperties":false,"properties":{"dimensions":{"$ref":"#/$defs/CatalogResponse/$defs/T109"},"element":{"$ref":"#/$defs/CatalogResponse/$defs/T112"}},"required":["dimensions","element"]};

function validate2761(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2761.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate2761.errors = [{}];
return false;
}
if(!(((((data === "float32") || (data === "float16")) || (data === "bfloat16")) || (data === "int8")) || (data === "binary"))){
validate2761.errors = [{}];
return false;
}
validate2761.errors = vErrors;
return errors === 0;
}
validate2761.evaluated = {"dynamicProps":false,"dynamicItems":false};


function validate2759(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2759.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if(((data.dimensions === undefined) && (missing0 = "dimensions")) || ((data.element === undefined) && (missing0 = "element"))){
validate2759.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "dimensions") || (key0 === "element"))){
validate2759.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.dimensions !== undefined){
const _errs2 = errors;
if(!(validate2751(data.dimensions, {instancePath:instancePath+"/dimensions",parentData:data,parentDataProperty:"dimensions",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2751.errors : vErrors.concat(validate2751.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.element !== undefined){
const _errs3 = errors;
if(!(validate2761(data.element, {instancePath:instancePath+"/element",parentData:data,parentDataProperty:"element",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2761.errors : vErrors.concat(validate2761.errors);
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
validate2759.errors = [{}];
return false;
}
}
validate2759.errors = vErrors;
return errors === 0;
}
validate2759.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate2663(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2663.evaluated;
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
if((data.int64 === undefined) && (missing0 = "int64")){
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
const _errs3 = errors;
for(const key0 in data){
if(!(key0 === "int64")){
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
if(_errs3 === errors){
if(data.int64 !== undefined){
if(!(validate2664(data.int64, {instancePath:instancePath+"/int64",parentData:data,parentDataProperty:"int64",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2664.errors : vErrors.concat(validate2664.errors);
errors = vErrors.length;
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
var _valid0 = _errs1 === errors;
if(_valid0){
valid0 = true;
passing0 = 0;
var props0 = true;
}
const _errs5 = errors;
if(errors === _errs5){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing1;
if((data.uint64 === undefined) && (missing1 = "uint64")){
const err3 = {};
if(vErrors === null){
vErrors = [err3];
}
else {
vErrors.push(err3);
}
errors++;
}
else {
const _errs7 = errors;
for(const key1 in data){
if(!(key1 === "uint64")){
const err4 = {};
if(vErrors === null){
vErrors = [err4];
}
else {
vErrors.push(err4);
}
errors++;
break;
}
}
if(_errs7 === errors){
if(data.uint64 !== undefined){
if(!(validate2664(data.uint64, {instancePath:instancePath+"/uint64",parentData:data,parentDataProperty:"uint64",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2664.errors : vErrors.concat(validate2664.errors);
errors = vErrors.length;
}
}
}
}
}
else {
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
var _valid0 = _errs5 === errors;
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
const _errs9 = errors;
if(errors === _errs9){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing2;
if((data.float64 === undefined) && (missing2 = "float64")){
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
const _errs11 = errors;
for(const key2 in data){
if(!(key2 === "float64")){
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
if(_errs11 === errors){
if(data.float64 !== undefined){
if(!(validate2664(data.float64, {instancePath:instancePath+"/float64",parentData:data,parentDataProperty:"float64",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2664.errors : vErrors.concat(validate2664.errors);
errors = vErrors.length;
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
var _valid0 = _errs9 === errors;
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
const _errs13 = errors;
if(errors === _errs13){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing3;
if((data.boolean === undefined) && (missing3 = "boolean")){
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
const _errs15 = errors;
for(const key3 in data){
if(!(key3 === "boolean")){
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
if(_errs15 === errors){
if(data.boolean !== undefined){
if(!(validate2664(data.boolean, {instancePath:instancePath+"/boolean",parentData:data,parentDataProperty:"boolean",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2664.errors : vErrors.concat(validate2664.errors);
errors = vErrors.length;
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
var _valid0 = _errs13 === errors;
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
const _errs17 = errors;
if(errors === _errs17){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing4;
if((data.utf8 === undefined) && (missing4 = "utf8")){
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
const _errs19 = errors;
for(const key4 in data){
if(!(key4 === "utf8")){
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
if(_errs19 === errors){
if(data.utf8 !== undefined){
if(!(validate2664(data.utf8, {instancePath:instancePath+"/utf8",parentData:data,parentDataProperty:"utf8",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2664.errors : vErrors.concat(validate2664.errors);
errors = vErrors.length;
}
}
}
}
}
else {
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
var _valid0 = _errs17 === errors;
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
const _errs21 = errors;
if(errors === _errs21){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing5;
if((data.binary === undefined) && (missing5 = "binary")){
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
const _errs23 = errors;
for(const key5 in data){
if(!(key5 === "binary")){
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
if(_errs23 === errors){
if(data.binary !== undefined){
if(!(validate2664(data.binary, {instancePath:instancePath+"/binary",parentData:data,parentDataProperty:"binary",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2664.errors : vErrors.concat(validate2664.errors);
errors = vErrors.length;
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
var _valid0 = _errs21 === errors;
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
const _errs25 = errors;
if(errors === _errs25){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing6;
if((data.int8 === undefined) && (missing6 = "int8")){
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
const _errs27 = errors;
for(const key6 in data){
if(!(key6 === "int8")){
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
if(_errs27 === errors){
if(data.int8 !== undefined){
if(!(validate2664(data.int8, {instancePath:instancePath+"/int8",parentData:data,parentDataProperty:"int8",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2664.errors : vErrors.concat(validate2664.errors);
errors = vErrors.length;
}
}
}
}
}
else {
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
var _valid0 = _errs25 === errors;
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
const _errs29 = errors;
if(errors === _errs29){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing7;
if((data.int16 === undefined) && (missing7 = "int16")){
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
const _errs31 = errors;
for(const key7 in data){
if(!(key7 === "int16")){
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
if(_errs31 === errors){
if(data.int16 !== undefined){
if(!(validate2664(data.int16, {instancePath:instancePath+"/int16",parentData:data,parentDataProperty:"int16",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2664.errors : vErrors.concat(validate2664.errors);
errors = vErrors.length;
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
var _valid0 = _errs29 === errors;
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
const _errs33 = errors;
if(errors === _errs33){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing8;
if((data.int32 === undefined) && (missing8 = "int32")){
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
const _errs35 = errors;
for(const key8 in data){
if(!(key8 === "int32")){
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
if(_errs35 === errors){
if(data.int32 !== undefined){
if(!(validate2664(data.int32, {instancePath:instancePath+"/int32",parentData:data,parentDataProperty:"int32",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2664.errors : vErrors.concat(validate2664.errors);
errors = vErrors.length;
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
var _valid0 = _errs33 === errors;
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
const _errs37 = errors;
if(errors === _errs37){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing9;
if((data.int128 === undefined) && (missing9 = "int128")){
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
const _errs39 = errors;
for(const key9 in data){
if(!(key9 === "int128")){
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
if(_errs39 === errors){
if(data.int128 !== undefined){
if(!(validate2664(data.int128, {instancePath:instancePath+"/int128",parentData:data,parentDataProperty:"int128",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2664.errors : vErrors.concat(validate2664.errors);
errors = vErrors.length;
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
var _valid0 = _errs37 === errors;
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
const _errs41 = errors;
if(errors === _errs41){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing10;
if((data.uint8 === undefined) && (missing10 = "uint8")){
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
const _errs43 = errors;
for(const key10 in data){
if(!(key10 === "uint8")){
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
if(_errs43 === errors){
if(data.uint8 !== undefined){
if(!(validate2664(data.uint8, {instancePath:instancePath+"/uint8",parentData:data,parentDataProperty:"uint8",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2664.errors : vErrors.concat(validate2664.errors);
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
var _valid0 = _errs41 === errors;
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
const _errs45 = errors;
if(errors === _errs45){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing11;
if((data.uint16 === undefined) && (missing11 = "uint16")){
const err33 = {};
if(vErrors === null){
vErrors = [err33];
}
else {
vErrors.push(err33);
}
errors++;
}
else {
const _errs47 = errors;
for(const key11 in data){
if(!(key11 === "uint16")){
const err34 = {};
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
if(_errs47 === errors){
if(data.uint16 !== undefined){
if(!(validate2664(data.uint16, {instancePath:instancePath+"/uint16",parentData:data,parentDataProperty:"uint16",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2664.errors : vErrors.concat(validate2664.errors);
errors = vErrors.length;
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
var _valid0 = _errs45 === errors;
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
const _errs49 = errors;
if(errors === _errs49){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing12;
if((data.uint32 === undefined) && (missing12 = "uint32")){
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
const _errs51 = errors;
for(const key12 in data){
if(!(key12 === "uint32")){
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
if(_errs51 === errors){
if(data.uint32 !== undefined){
if(!(validate2664(data.uint32, {instancePath:instancePath+"/uint32",parentData:data,parentDataProperty:"uint32",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2664.errors : vErrors.concat(validate2664.errors);
errors = vErrors.length;
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
var _valid0 = _errs49 === errors;
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
const _errs53 = errors;
if(errors === _errs53){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing13;
if((data.uint128 === undefined) && (missing13 = "uint128")){
const err39 = {};
if(vErrors === null){
vErrors = [err39];
}
else {
vErrors.push(err39);
}
errors++;
}
else {
const _errs55 = errors;
for(const key13 in data){
if(!(key13 === "uint128")){
const err40 = {};
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
if(_errs55 === errors){
if(data.uint128 !== undefined){
if(!(validate2664(data.uint128, {instancePath:instancePath+"/uint128",parentData:data,parentDataProperty:"uint128",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2664.errors : vErrors.concat(validate2664.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err41 = {};
if(vErrors === null){
vErrors = [err41];
}
else {
vErrors.push(err41);
}
errors++;
}
}
var _valid0 = _errs53 === errors;
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
const _errs57 = errors;
if(errors === _errs57){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing14;
if((data.float32 === undefined) && (missing14 = "float32")){
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
const _errs59 = errors;
for(const key14 in data){
if(!(key14 === "float32")){
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
if(_errs59 === errors){
if(data.float32 !== undefined){
if(!(validate2664(data.float32, {instancePath:instancePath+"/float32",parentData:data,parentDataProperty:"float32",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2664.errors : vErrors.concat(validate2664.errors);
errors = vErrors.length;
}
}
}
}
}
else {
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
var _valid0 = _errs57 === errors;
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
const _errs61 = errors;
if(errors === _errs61){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing15;
if((data.decimal === undefined) && (missing15 = "decimal")){
const err45 = {};
if(vErrors === null){
vErrors = [err45];
}
else {
vErrors.push(err45);
}
errors++;
}
else {
const _errs63 = errors;
for(const key15 in data){
if(!(key15 === "decimal")){
const err46 = {};
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
if(_errs63 === errors){
if(data.decimal !== undefined){
if(!(validate2680(data.decimal, {instancePath:instancePath+"/decimal",parentData:data,parentDataProperty:"decimal",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2680.errors : vErrors.concat(validate2680.errors);
errors = vErrors.length;
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
var _valid0 = _errs61 === errors;
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
const _errs65 = errors;
if(errors === _errs65){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing16;
if((data.date === undefined) && (missing16 = "date")){
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
const _errs67 = errors;
for(const key16 in data){
if(!(key16 === "date")){
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
if(_errs67 === errors){
if(data.date !== undefined){
if(!(validate2664(data.date, {instancePath:instancePath+"/date",parentData:data,parentDataProperty:"date",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2664.errors : vErrors.concat(validate2664.errors);
errors = vErrors.length;
}
}
}
}
}
else {
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
var _valid0 = _errs65 === errors;
if(_valid0 && valid0){
valid0 = false;
passing0 = [passing0, 16];
}
else {
if(_valid0){
valid0 = true;
passing0 = 16;
if(props0 !== true){
props0 = true;
}
}
const _errs69 = errors;
if(errors === _errs69){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing17;
if((data.time === undefined) && (missing17 = "time")){
const err51 = {};
if(vErrors === null){
vErrors = [err51];
}
else {
vErrors.push(err51);
}
errors++;
}
else {
const _errs71 = errors;
for(const key17 in data){
if(!(key17 === "time")){
const err52 = {};
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
if(_errs71 === errors){
if(data.time !== undefined){
if(!(validate2664(data.time, {instancePath:instancePath+"/time",parentData:data,parentDataProperty:"time",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2664.errors : vErrors.concat(validate2664.errors);
errors = vErrors.length;
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
var _valid0 = _errs69 === errors;
if(_valid0 && valid0){
valid0 = false;
passing0 = [passing0, 17];
}
else {
if(_valid0){
valid0 = true;
passing0 = 17;
if(props0 !== true){
props0 = true;
}
}
const _errs73 = errors;
if(errors === _errs73){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing18;
if((data.timestamp === undefined) && (missing18 = "timestamp")){
const err54 = {};
if(vErrors === null){
vErrors = [err54];
}
else {
vErrors.push(err54);
}
errors++;
}
else {
const _errs75 = errors;
for(const key18 in data){
if(!(key18 === "timestamp")){
const err55 = {};
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
if(_errs75 === errors){
if(data.timestamp !== undefined){
if(!(validate2687(data.timestamp, {instancePath:instancePath+"/timestamp",parentData:data,parentDataProperty:"timestamp",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2687.errors : vErrors.concat(validate2687.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err56 = {};
if(vErrors === null){
vErrors = [err56];
}
else {
vErrors.push(err56);
}
errors++;
}
}
var _valid0 = _errs73 === errors;
if(_valid0 && valid0){
valid0 = false;
passing0 = [passing0, 18];
}
else {
if(_valid0){
valid0 = true;
passing0 = 18;
if(props0 !== true){
props0 = true;
}
}
const _errs77 = errors;
if(errors === _errs77){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing19;
if((data.interval === undefined) && (missing19 = "interval")){
const err57 = {};
if(vErrors === null){
vErrors = [err57];
}
else {
vErrors.push(err57);
}
errors++;
}
else {
const _errs79 = errors;
for(const key19 in data){
if(!(key19 === "interval")){
const err58 = {};
if(vErrors === null){
vErrors = [err58];
}
else {
vErrors.push(err58);
}
errors++;
break;
}
}
if(_errs79 === errors){
if(data.interval !== undefined){
if(!(validate2664(data.interval, {instancePath:instancePath+"/interval",parentData:data,parentDataProperty:"interval",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2664.errors : vErrors.concat(validate2664.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err59 = {};
if(vErrors === null){
vErrors = [err59];
}
else {
vErrors.push(err59);
}
errors++;
}
}
var _valid0 = _errs77 === errors;
if(_valid0 && valid0){
valid0 = false;
passing0 = [passing0, 19];
}
else {
if(_valid0){
valid0 = true;
passing0 = 19;
if(props0 !== true){
props0 = true;
}
}
const _errs81 = errors;
if(errors === _errs81){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing20;
if((data.uuid === undefined) && (missing20 = "uuid")){
const err60 = {};
if(vErrors === null){
vErrors = [err60];
}
else {
vErrors.push(err60);
}
errors++;
}
else {
const _errs83 = errors;
for(const key20 in data){
if(!(key20 === "uuid")){
const err61 = {};
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
if(_errs83 === errors){
if(data.uuid !== undefined){
if(!(validate2664(data.uuid, {instancePath:instancePath+"/uuid",parentData:data,parentDataProperty:"uuid",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2664.errors : vErrors.concat(validate2664.errors);
errors = vErrors.length;
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
var _valid0 = _errs81 === errors;
if(_valid0 && valid0){
valid0 = false;
passing0 = [passing0, 20];
}
else {
if(_valid0){
valid0 = true;
passing0 = 20;
if(props0 !== true){
props0 = true;
}
}
const _errs85 = errors;
if(errors === _errs85){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing21;
if((data.structure === undefined) && (missing21 = "structure")){
const err63 = {};
if(vErrors === null){
vErrors = [err63];
}
else {
vErrors.push(err63);
}
errors++;
}
else {
const _errs87 = errors;
for(const key21 in data){
if(!(key21 === "structure")){
const err64 = {};
if(vErrors === null){
vErrors = [err64];
}
else {
vErrors.push(err64);
}
errors++;
break;
}
}
if(_errs87 === errors){
if(data.structure !== undefined){
if(!(validate2691(data.structure, {instancePath:instancePath+"/structure",parentData:data,parentDataProperty:"structure",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2691.errors : vErrors.concat(validate2691.errors);
errors = vErrors.length;
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
var _valid0 = _errs85 === errors;
if(_valid0 && valid0){
valid0 = false;
passing0 = [passing0, 21];
}
else {
if(_valid0){
valid0 = true;
passing0 = 21;
if(props0 !== true){
props0 = true;
}
}
const _errs89 = errors;
if(errors === _errs89){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing22;
if((data.list === undefined) && (missing22 = "list")){
const err66 = {};
if(vErrors === null){
vErrors = [err66];
}
else {
vErrors.push(err66);
}
errors++;
}
else {
const _errs91 = errors;
for(const key22 in data){
if(!(key22 === "list")){
const err67 = {};
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
if(_errs91 === errors){
if(data.list !== undefined){
if(!(validate2745(data.list, {instancePath:instancePath+"/list",parentData:data,parentDataProperty:"list",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2745.errors : vErrors.concat(validate2745.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err68 = {};
if(vErrors === null){
vErrors = [err68];
}
else {
vErrors.push(err68);
}
errors++;
}
}
var _valid0 = _errs89 === errors;
if(_valid0 && valid0){
valid0 = false;
passing0 = [passing0, 22];
}
else {
if(_valid0){
valid0 = true;
passing0 = 22;
if(props0 !== true){
props0 = true;
}
}
const _errs93 = errors;
if(errors === _errs93){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing23;
if((data.array === undefined) && (missing23 = "array")){
const err69 = {};
if(vErrors === null){
vErrors = [err69];
}
else {
vErrors.push(err69);
}
errors++;
}
else {
const _errs95 = errors;
for(const key23 in data){
if(!(key23 === "array")){
const err70 = {};
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
if(_errs95 === errors){
if(data.array !== undefined){
if(!(validate2749(data.array, {instancePath:instancePath+"/array",parentData:data,parentDataProperty:"array",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2749.errors : vErrors.concat(validate2749.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err71 = {};
if(vErrors === null){
vErrors = [err71];
}
else {
vErrors.push(err71);
}
errors++;
}
}
var _valid0 = _errs93 === errors;
if(_valid0 && valid0){
valid0 = false;
passing0 = [passing0, 23];
}
else {
if(_valid0){
valid0 = true;
passing0 = 23;
if(props0 !== true){
props0 = true;
}
}
const _errs97 = errors;
if(errors === _errs97){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing24;
if((data.map === undefined) && (missing24 = "map")){
const err72 = {};
if(vErrors === null){
vErrors = [err72];
}
else {
vErrors.push(err72);
}
errors++;
}
else {
const _errs99 = errors;
for(const key24 in data){
if(!(key24 === "map")){
const err73 = {};
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
if(_errs99 === errors){
if(data.map !== undefined){
if(!(validate2754(data.map, {instancePath:instancePath+"/map",parentData:data,parentDataProperty:"map",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2754.errors : vErrors.concat(validate2754.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err74 = {};
if(vErrors === null){
vErrors = [err74];
}
else {
vErrors.push(err74);
}
errors++;
}
}
var _valid0 = _errs97 === errors;
if(_valid0 && valid0){
valid0 = false;
passing0 = [passing0, 24];
}
else {
if(_valid0){
valid0 = true;
passing0 = 24;
if(props0 !== true){
props0 = true;
}
}
const _errs101 = errors;
if(errors === _errs101){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing25;
if((data.tagged_union === undefined) && (missing25 = "tagged_union")){
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
const _errs103 = errors;
for(const key25 in data){
if(!(key25 === "tagged_union")){
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
if(_errs103 === errors){
if(data.tagged_union !== undefined){
if(!(validate2691(data.tagged_union, {instancePath:instancePath+"/tagged_union",parentData:data,parentDataProperty:"tagged_union",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2691.errors : vErrors.concat(validate2691.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err77 = {};
if(vErrors === null){
vErrors = [err77];
}
else {
vErrors.push(err77);
}
errors++;
}
}
var _valid0 = _errs101 === errors;
if(_valid0 && valid0){
valid0 = false;
passing0 = [passing0, 25];
}
else {
if(_valid0){
valid0 = true;
passing0 = 25;
if(props0 !== true){
props0 = true;
}
}
const _errs105 = errors;
if(errors === _errs105){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing26;
if((data.json === undefined) && (missing26 = "json")){
const err78 = {};
if(vErrors === null){
vErrors = [err78];
}
else {
vErrors.push(err78);
}
errors++;
}
else {
const _errs107 = errors;
for(const key26 in data){
if(!(key26 === "json")){
const err79 = {};
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
if(_errs107 === errors){
if(data.json !== undefined){
if(!(validate2664(data.json, {instancePath:instancePath+"/json",parentData:data,parentDataProperty:"json",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2664.errors : vErrors.concat(validate2664.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err80 = {};
if(vErrors === null){
vErrors = [err80];
}
else {
vErrors.push(err80);
}
errors++;
}
}
var _valid0 = _errs105 === errors;
if(_valid0 && valid0){
valid0 = false;
passing0 = [passing0, 26];
}
else {
if(_valid0){
valid0 = true;
passing0 = 26;
if(props0 !== true){
props0 = true;
}
}
const _errs109 = errors;
if(errors === _errs109){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing27;
if((data.range === undefined) && (missing27 = "range")){
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
const _errs111 = errors;
for(const key27 in data){
if(!(key27 === "range")){
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
if(_errs111 === errors){
if(data.range !== undefined){
if(!(wrapper42.validate(data.range, {instancePath:instancePath+"/range",parentData:data,parentDataProperty:"range",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? wrapper42.validate.errors : vErrors.concat(wrapper42.validate.errors);
errors = vErrors.length;
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
var _valid0 = _errs109 === errors;
if(_valid0 && valid0){
valid0 = false;
passing0 = [passing0, 27];
}
else {
if(_valid0){
valid0 = true;
passing0 = 27;
if(props0 !== true){
props0 = true;
}
}
const _errs113 = errors;
if(errors === _errs113){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing28;
if((data.multirange === undefined) && (missing28 = "multirange")){
const err84 = {};
if(vErrors === null){
vErrors = [err84];
}
else {
vErrors.push(err84);
}
errors++;
}
else {
const _errs115 = errors;
for(const key28 in data){
if(!(key28 === "multirange")){
const err85 = {};
if(vErrors === null){
vErrors = [err85];
}
else {
vErrors.push(err85);
}
errors++;
break;
}
}
if(_errs115 === errors){
if(data.multirange !== undefined){
if(!(wrapper42.validate(data.multirange, {instancePath:instancePath+"/multirange",parentData:data,parentDataProperty:"multirange",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? wrapper42.validate.errors : vErrors.concat(wrapper42.validate.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err86 = {};
if(vErrors === null){
vErrors = [err86];
}
else {
vErrors.push(err86);
}
errors++;
}
}
var _valid0 = _errs113 === errors;
if(_valid0 && valid0){
valid0 = false;
passing0 = [passing0, 28];
}
else {
if(_valid0){
valid0 = true;
passing0 = 28;
if(props0 !== true){
props0 = true;
}
}
const _errs117 = errors;
if(errors === _errs117){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing29;
if((data.vector === undefined) && (missing29 = "vector")){
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
const _errs119 = errors;
for(const key29 in data){
if(!(key29 === "vector")){
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
if(_errs119 === errors){
if(data.vector !== undefined){
if(!(validate2759(data.vector, {instancePath:instancePath+"/vector",parentData:data,parentDataProperty:"vector",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2759.errors : vErrors.concat(validate2759.errors);
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
var _valid0 = _errs117 === errors;
if(_valid0 && valid0){
valid0 = false;
passing0 = [passing0, 29];
}
else {
if(_valid0){
valid0 = true;
passing0 = 29;
if(props0 !== true){
props0 = true;
}
}
const _errs121 = errors;
if(errors === _errs121){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing30;
if((data.capability === undefined) && (missing30 = "capability")){
const err90 = {};
if(vErrors === null){
vErrors = [err90];
}
else {
vErrors.push(err90);
}
errors++;
}
else {
const _errs123 = errors;
for(const key30 in data){
if(!(key30 === "capability")){
const err91 = {};
if(vErrors === null){
vErrors = [err91];
}
else {
vErrors.push(err91);
}
errors++;
break;
}
}
if(_errs123 === errors){
if(data.capability !== undefined){
if(!(validate2664(data.capability, {instancePath:instancePath+"/capability",parentData:data,parentDataProperty:"capability",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2664.errors : vErrors.concat(validate2664.errors);
errors = vErrors.length;
}
}
}
}
}
else {
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
var _valid0 = _errs121 === errors;
if(_valid0 && valid0){
valid0 = false;
passing0 = [passing0, 30];
}
else {
if(_valid0){
valid0 = true;
passing0 = 30;
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
}
}
}
}
}
}
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
const err93 = {};
if(vErrors === null){
vErrors = [err93];
}
else {
vErrors.push(err93);
}
errors++;
validate2663.errors = vErrors;
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
validate2663.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate2663.evaluated = {"dynamicProps":true,"dynamicItems":false};

const schema749 = {"anyOf":[{"$ref":"#/$defs/CatalogResponse/$defs/T114"},{"type":"null"}]};
const schema750 = {"oneOf":[{"type":"object","additionalProperties":false,"required":["missing"],"properties":{"missing":{"$ref":"#/$defs/CatalogResponse/$defs/T89"}}},{"type":"object","additionalProperties":false,"required":["null"],"properties":{"null":{"$ref":"#/$defs/CatalogResponse/$defs/T89"}}},{"type":"object","additionalProperties":false,"required":["type_error"],"properties":{"type_error":{"$ref":"#/$defs/CatalogResponse/$defs/T115"}}},{"type":"object","additionalProperties":false,"required":["value"],"properties":{"value":{"$ref":"#/$defs/CatalogResponse/$defs/T116"}}},{"type":"object","additionalProperties":false,"required":["conflict"],"properties":{"conflict":{"$ref":"#/$defs/CatalogResponse/$defs/T137"}}}]};
const schema398 = {"type":"string","enum":["unknown","int64","uint64","float64","boolean","utf8","binary","int8","int16","int32","int128","uint8","uint16","uint32","uint128","float32","decimal","date","time","timestamp","interval","uuid","structure","list","array","map","tagged_union","json","range","multirange","vector","capability","null_value","text","character"]};

function validate2771(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2771.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate2771.errors = [{}];
return false;
}
if(!(((((((((((((((((((((((((((((((((((data === "unknown") || (data === "int64")) || (data === "uint64")) || (data === "float64")) || (data === "boolean")) || (data === "utf8")) || (data === "binary")) || (data === "int8")) || (data === "int16")) || (data === "int32")) || (data === "int128")) || (data === "uint8")) || (data === "uint16")) || (data === "uint32")) || (data === "uint128")) || (data === "float32")) || (data === "decimal")) || (data === "date")) || (data === "time")) || (data === "timestamp")) || (data === "interval")) || (data === "uuid")) || (data === "structure")) || (data === "list")) || (data === "array")) || (data === "map")) || (data === "tagged_union")) || (data === "json")) || (data === "range")) || (data === "multirange")) || (data === "vector")) || (data === "capability")) || (data === "null_value")) || (data === "text")) || (data === "character"))){
validate2771.errors = [{}];
return false;
}
validate2771.errors = vErrors;
return errors === 0;
}
validate2771.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema752 = {"oneOf":[{"type":"object","additionalProperties":false,"required":["atom"],"properties":{"atom":{"$ref":"#/$defs/CatalogResponse/$defs/T117"}}},{"type":"object","additionalProperties":false,"required":["structure"],"properties":{"structure":{"$ref":"#/$defs/CatalogResponse/$defs/T119"}}},{"type":"object","additionalProperties":false,"required":["list"],"properties":{"list":{"$ref":"#/$defs/CatalogResponse/$defs/T119"}}},{"type":"object","additionalProperties":false,"required":["array"],"properties":{"array":{"$ref":"#/$defs/CatalogResponse/$defs/T119"}}},{"type":"object","additionalProperties":false,"required":["map"],"properties":{"map":{"$ref":"#/$defs/CatalogResponse/$defs/T128"}}},{"type":"object","additionalProperties":false,"required":["tagged_union"],"properties":{"tagged_union":{"$ref":"#/$defs/CatalogResponse/$defs/T140"}}},{"type":"object","additionalProperties":false,"required":["json"],"properties":{"json":{"$ref":"#/$defs/CatalogResponse/$defs/T46"}}},{"type":"object","additionalProperties":false,"required":["range"],"properties":{"range":{"$ref":"#/$defs/CatalogResponse/$defs/T142"}}},{"type":"object","additionalProperties":false,"required":["multirange"],"properties":{"multirange":{"$ref":"#/$defs/CatalogResponse/$defs/T136"}}},{"type":"object","additionalProperties":false,"required":["vector"],"properties":{"vector":{"$ref":"#/$defs/CatalogResponse/$defs/T46"}}}]};
const schema753 = {"oneOf":[{"type":"object","additionalProperties":false,"required":["signed"],"properties":{"signed":{"$ref":"#/$defs/CatalogResponse/$defs/T46"}}},{"type":"object","additionalProperties":false,"required":["unsigned"],"properties":{"unsigned":{"$ref":"#/$defs/CatalogResponse/$defs/T46"}}},{"type":"object","additionalProperties":false,"required":["decimal"],"properties":{"decimal":{"$ref":"#/$defs/CatalogResponse/$defs/T46"}}},{"type":"object","additionalProperties":false,"required":["float_bits"],"properties":{"float_bits":{"$ref":"#/$defs/CatalogResponse/$defs/T46"}}},{"type":"object","additionalProperties":false,"required":["boolean"],"properties":{"boolean":{"$ref":"#/$defs/CatalogResponse/$defs/T107"}}},{"type":"object","additionalProperties":false,"required":["utf8"],"properties":{"utf8":{"$ref":"#/$defs/CatalogResponse/$defs/T46"}}},{"type":"object","additionalProperties":false,"required":["binary"],"properties":{"binary":{"$ref":"#/$defs/CatalogResponse/$defs/T46"}}},{"type":"object","additionalProperties":false,"required":["date_days"],"properties":{"date_days":{"$ref":"#/$defs/CatalogResponse/$defs/T46"}}},{"type":"object","additionalProperties":false,"required":["time_nanos"],"properties":{"time_nanos":{"$ref":"#/$defs/CatalogResponse/$defs/T46"}}},{"type":"object","additionalProperties":false,"required":["timestamp_micros"],"properties":{"timestamp_micros":{"$ref":"#/$defs/CatalogResponse/$defs/T46"}}},{"type":"object","additionalProperties":false,"required":["interval"],"properties":{"interval":{"$ref":"#/$defs/CatalogResponse/$defs/T118"}}},{"type":"object","additionalProperties":false,"required":["uuid"],"properties":{"uuid":{"$ref":"#/$defs/CatalogResponse/$defs/T46"}}}]};
const schema754 = {"type":"object","additionalProperties":false,"properties":{"months":{"$ref":"#/$defs/CatalogResponse/$defs/T46"},"days":{"$ref":"#/$defs/CatalogResponse/$defs/T46"},"nanos":{"$ref":"#/$defs/CatalogResponse/$defs/T46"}},"required":["months","days","nanos"]};

function validate2785(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2785.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((((data.months === undefined) && (missing0 = "months")) || ((data.days === undefined) && (missing0 = "days"))) || ((data.nanos === undefined) && (missing0 = "nanos"))){
validate2785.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "months") || (key0 === "days")) || (key0 === "nanos"))){
validate2785.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.months !== undefined){
const _errs2 = errors;
if(!(validate2513(data.months, {instancePath:instancePath+"/months",parentData:data,parentDataProperty:"months",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2513.errors : vErrors.concat(validate2513.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.days !== undefined){
const _errs3 = errors;
if(!(validate2513(data.days, {instancePath:instancePath+"/days",parentData:data,parentDataProperty:"days",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2513.errors : vErrors.concat(validate2513.errors);
errors = vErrors.length;
}
var valid0 = _errs3 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.nanos !== undefined){
const _errs4 = errors;
if(!(validate2513(data.nanos, {instancePath:instancePath+"/nanos",parentData:data,parentDataProperty:"nanos",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2513.errors : vErrors.concat(validate2513.errors);
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
validate2785.errors = [{}];
return false;
}
}
validate2785.errors = vErrors;
return errors === 0;
}
validate2785.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate2774(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2774.evaluated;
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
if((data.signed === undefined) && (missing0 = "signed")){
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
const _errs3 = errors;
for(const key0 in data){
if(!(key0 === "signed")){
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
if(_errs3 === errors){
if(data.signed !== undefined){
if(!(validate2513(data.signed, {instancePath:instancePath+"/signed",parentData:data,parentDataProperty:"signed",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2513.errors : vErrors.concat(validate2513.errors);
errors = vErrors.length;
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
var _valid0 = _errs1 === errors;
if(_valid0){
valid0 = true;
passing0 = 0;
var props0 = true;
}
const _errs5 = errors;
if(errors === _errs5){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing1;
if((data.unsigned === undefined) && (missing1 = "unsigned")){
const err3 = {};
if(vErrors === null){
vErrors = [err3];
}
else {
vErrors.push(err3);
}
errors++;
}
else {
const _errs7 = errors;
for(const key1 in data){
if(!(key1 === "unsigned")){
const err4 = {};
if(vErrors === null){
vErrors = [err4];
}
else {
vErrors.push(err4);
}
errors++;
break;
}
}
if(_errs7 === errors){
if(data.unsigned !== undefined){
if(!(validate2513(data.unsigned, {instancePath:instancePath+"/unsigned",parentData:data,parentDataProperty:"unsigned",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2513.errors : vErrors.concat(validate2513.errors);
errors = vErrors.length;
}
}
}
}
}
else {
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
var _valid0 = _errs5 === errors;
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
const _errs9 = errors;
if(errors === _errs9){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing2;
if((data.decimal === undefined) && (missing2 = "decimal")){
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
const _errs11 = errors;
for(const key2 in data){
if(!(key2 === "decimal")){
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
if(_errs11 === errors){
if(data.decimal !== undefined){
if(!(validate2513(data.decimal, {instancePath:instancePath+"/decimal",parentData:data,parentDataProperty:"decimal",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2513.errors : vErrors.concat(validate2513.errors);
errors = vErrors.length;
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
var _valid0 = _errs9 === errors;
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
const _errs13 = errors;
if(errors === _errs13){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing3;
if((data.float_bits === undefined) && (missing3 = "float_bits")){
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
const _errs15 = errors;
for(const key3 in data){
if(!(key3 === "float_bits")){
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
if(_errs15 === errors){
if(data.float_bits !== undefined){
if(!(validate2513(data.float_bits, {instancePath:instancePath+"/float_bits",parentData:data,parentDataProperty:"float_bits",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2513.errors : vErrors.concat(validate2513.errors);
errors = vErrors.length;
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
var _valid0 = _errs13 === errors;
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
const _errs17 = errors;
if(errors === _errs17){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing4;
if((data.boolean === undefined) && (missing4 = "boolean")){
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
const _errs19 = errors;
for(const key4 in data){
if(!(key4 === "boolean")){
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
if(_errs19 === errors){
if(data.boolean !== undefined){
if(!(validate2746(data.boolean, {instancePath:instancePath+"/boolean",parentData:data,parentDataProperty:"boolean",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2746.errors : vErrors.concat(validate2746.errors);
errors = vErrors.length;
}
}
}
}
}
else {
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
var _valid0 = _errs17 === errors;
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
const _errs21 = errors;
if(errors === _errs21){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing5;
if((data.utf8 === undefined) && (missing5 = "utf8")){
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
const _errs23 = errors;
for(const key5 in data){
if(!(key5 === "utf8")){
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
if(_errs23 === errors){
if(data.utf8 !== undefined){
if(!(validate2513(data.utf8, {instancePath:instancePath+"/utf8",parentData:data,parentDataProperty:"utf8",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2513.errors : vErrors.concat(validate2513.errors);
errors = vErrors.length;
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
var _valid0 = _errs21 === errors;
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
const _errs25 = errors;
if(errors === _errs25){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing6;
if((data.binary === undefined) && (missing6 = "binary")){
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
const _errs27 = errors;
for(const key6 in data){
if(!(key6 === "binary")){
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
if(_errs27 === errors){
if(data.binary !== undefined){
if(!(validate2513(data.binary, {instancePath:instancePath+"/binary",parentData:data,parentDataProperty:"binary",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2513.errors : vErrors.concat(validate2513.errors);
errors = vErrors.length;
}
}
}
}
}
else {
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
var _valid0 = _errs25 === errors;
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
const _errs29 = errors;
if(errors === _errs29){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing7;
if((data.date_days === undefined) && (missing7 = "date_days")){
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
const _errs31 = errors;
for(const key7 in data){
if(!(key7 === "date_days")){
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
if(_errs31 === errors){
if(data.date_days !== undefined){
if(!(validate2513(data.date_days, {instancePath:instancePath+"/date_days",parentData:data,parentDataProperty:"date_days",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2513.errors : vErrors.concat(validate2513.errors);
errors = vErrors.length;
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
var _valid0 = _errs29 === errors;
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
const _errs33 = errors;
if(errors === _errs33){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing8;
if((data.time_nanos === undefined) && (missing8 = "time_nanos")){
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
const _errs35 = errors;
for(const key8 in data){
if(!(key8 === "time_nanos")){
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
if(_errs35 === errors){
if(data.time_nanos !== undefined){
if(!(validate2513(data.time_nanos, {instancePath:instancePath+"/time_nanos",parentData:data,parentDataProperty:"time_nanos",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2513.errors : vErrors.concat(validate2513.errors);
errors = vErrors.length;
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
var _valid0 = _errs33 === errors;
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
const _errs37 = errors;
if(errors === _errs37){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing9;
if((data.timestamp_micros === undefined) && (missing9 = "timestamp_micros")){
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
const _errs39 = errors;
for(const key9 in data){
if(!(key9 === "timestamp_micros")){
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
if(_errs39 === errors){
if(data.timestamp_micros !== undefined){
if(!(validate2513(data.timestamp_micros, {instancePath:instancePath+"/timestamp_micros",parentData:data,parentDataProperty:"timestamp_micros",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2513.errors : vErrors.concat(validate2513.errors);
errors = vErrors.length;
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
var _valid0 = _errs37 === errors;
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
const _errs41 = errors;
if(errors === _errs41){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing10;
if((data.interval === undefined) && (missing10 = "interval")){
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
const _errs43 = errors;
for(const key10 in data){
if(!(key10 === "interval")){
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
if(_errs43 === errors){
if(data.interval !== undefined){
if(!(validate2785(data.interval, {instancePath:instancePath+"/interval",parentData:data,parentDataProperty:"interval",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2785.errors : vErrors.concat(validate2785.errors);
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
var _valid0 = _errs41 === errors;
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
const _errs45 = errors;
if(errors === _errs45){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing11;
if((data.uuid === undefined) && (missing11 = "uuid")){
const err33 = {};
if(vErrors === null){
vErrors = [err33];
}
else {
vErrors.push(err33);
}
errors++;
}
else {
const _errs47 = errors;
for(const key11 in data){
if(!(key11 === "uuid")){
const err34 = {};
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
if(_errs47 === errors){
if(data.uuid !== undefined){
if(!(validate2513(data.uuid, {instancePath:instancePath+"/uuid",parentData:data,parentDataProperty:"uuid",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2513.errors : vErrors.concat(validate2513.errors);
errors = vErrors.length;
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
var _valid0 = _errs45 === errors;
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
const err36 = {};
if(vErrors === null){
vErrors = [err36];
}
else {
vErrors.push(err36);
}
errors++;
validate2774.errors = vErrors;
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
validate2774.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate2774.evaluated = {"dynamicProps":true,"dynamicItems":false};

const schema755 = {"type":"array","maxItems":65536,"items":{"$ref":"#/$defs/CatalogResponse/$defs/T120"}};
const schema756 = {"oneOf":[{"type":"object","additionalProperties":false,"required":["missing"],"properties":{"missing":{"$ref":"#/$defs/CatalogResponse/$defs/T121"}}},{"type":"object","additionalProperties":false,"required":["null"],"properties":{"null":{"$ref":"#/$defs/CatalogResponse/$defs/T121"}}},{"type":"object","additionalProperties":false,"required":["type_error"],"properties":{"type_error":{"$ref":"#/$defs/CatalogResponse/$defs/T122"}}},{"type":"object","additionalProperties":false,"required":["value"],"properties":{"value":{"$ref":"#/$defs/CatalogResponse/$defs/T123"}}},{"type":"object","additionalProperties":false,"required":["conflict"],"properties":{"conflict":{"$ref":"#/$defs/CatalogResponse/$defs/T137"}}}]};
const schema757 = {"type":"object","maxProperties":0};

function validate2794(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2794.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
if(Object.keys(data).length > 0){
validate2794.errors = [{}];
return false;
}
}
else {
validate2794.errors = [{}];
return false;
}
}
validate2794.errors = vErrors;
return errors === 0;
}
validate2794.evaluated = {"dynamicProps":false,"dynamicItems":false};


function validate2797(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2797.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate2797.errors = [{}];
return false;
}
if(!(((((((((((((((((((((((((((((((((((data === "unknown") || (data === "int64")) || (data === "uint64")) || (data === "float64")) || (data === "boolean")) || (data === "utf8")) || (data === "binary")) || (data === "int8")) || (data === "int16")) || (data === "int32")) || (data === "int128")) || (data === "uint8")) || (data === "uint16")) || (data === "uint32")) || (data === "uint128")) || (data === "float32")) || (data === "decimal")) || (data === "date")) || (data === "time")) || (data === "timestamp")) || (data === "interval")) || (data === "uuid")) || (data === "structure")) || (data === "list")) || (data === "array")) || (data === "map")) || (data === "tagged_union")) || (data === "json")) || (data === "range")) || (data === "multirange")) || (data === "vector")) || (data === "capability")) || (data === "null_value")) || (data === "text")) || (data === "character"))){
validate2797.errors = [{}];
return false;
}
validate2797.errors = vErrors;
return errors === 0;
}
validate2797.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema759 = {"oneOf":[{"type":"object","additionalProperties":false,"required":["atom"],"properties":{"atom":{"$ref":"#/$defs/CatalogResponse/$defs/T124"}}},{"type":"object","additionalProperties":false,"required":["structure"],"properties":{"structure":{"$ref":"#/$defs/CatalogResponse/$defs/T119"}}},{"type":"object","additionalProperties":false,"required":["list"],"properties":{"list":{"$ref":"#/$defs/CatalogResponse/$defs/T119"}}},{"type":"object","additionalProperties":false,"required":["array"],"properties":{"array":{"$ref":"#/$defs/CatalogResponse/$defs/T119"}}},{"type":"object","additionalProperties":false,"required":["map"],"properties":{"map":{"$ref":"#/$defs/CatalogResponse/$defs/T128"}}},{"type":"object","additionalProperties":false,"required":["tagged_union"],"properties":{"tagged_union":{"$ref":"#/$defs/CatalogResponse/$defs/T130"}}},{"type":"object","additionalProperties":false,"required":["json"],"properties":{"json":{"$ref":"#/$defs/CatalogResponse/$defs/T125"}}},{"type":"object","additionalProperties":false,"required":["range"],"properties":{"range":{"$ref":"#/$defs/CatalogResponse/$defs/T133"}}},{"type":"object","additionalProperties":false,"required":["multirange"],"properties":{"multirange":{"$ref":"#/$defs/CatalogResponse/$defs/T136"}}},{"type":"object","additionalProperties":false,"required":["vector"],"properties":{"vector":{"$ref":"#/$defs/CatalogResponse/$defs/T125"}}}]};
const schema760 = {"oneOf":[{"type":"object","additionalProperties":false,"required":["signed"],"properties":{"signed":{"$ref":"#/$defs/CatalogResponse/$defs/T125"}}},{"type":"object","additionalProperties":false,"required":["unsigned"],"properties":{"unsigned":{"$ref":"#/$defs/CatalogResponse/$defs/T125"}}},{"type":"object","additionalProperties":false,"required":["decimal"],"properties":{"decimal":{"$ref":"#/$defs/CatalogResponse/$defs/T125"}}},{"type":"object","additionalProperties":false,"required":["float_bits"],"properties":{"float_bits":{"$ref":"#/$defs/CatalogResponse/$defs/T125"}}},{"type":"object","additionalProperties":false,"required":["boolean"],"properties":{"boolean":{"$ref":"#/$defs/CatalogResponse/$defs/T126"}}},{"type":"object","additionalProperties":false,"required":["utf8"],"properties":{"utf8":{"$ref":"#/$defs/CatalogResponse/$defs/T125"}}},{"type":"object","additionalProperties":false,"required":["binary"],"properties":{"binary":{"$ref":"#/$defs/CatalogResponse/$defs/T125"}}},{"type":"object","additionalProperties":false,"required":["date_days"],"properties":{"date_days":{"$ref":"#/$defs/CatalogResponse/$defs/T125"}}},{"type":"object","additionalProperties":false,"required":["time_nanos"],"properties":{"time_nanos":{"$ref":"#/$defs/CatalogResponse/$defs/T125"}}},{"type":"object","additionalProperties":false,"required":["timestamp_micros"],"properties":{"timestamp_micros":{"$ref":"#/$defs/CatalogResponse/$defs/T125"}}},{"type":"object","additionalProperties":false,"required":["interval"],"properties":{"interval":{"$ref":"#/$defs/CatalogResponse/$defs/T127"}}},{"type":"object","additionalProperties":false,"required":["uuid"],"properties":{"uuid":{"$ref":"#/$defs/CatalogResponse/$defs/T125"}}}]};
const schema761 = {"type":"string","maxLength":262144};

function validate2801(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2801.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(typeof data === "string"){
if(func3(data) > 262144){
validate2801.errors = [{}];
return false;
}
}
else {
validate2801.errors = [{}];
return false;
}
}
validate2801.errors = vErrors;
return errors === 0;
}
validate2801.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema762 = {"type":"boolean"};

function validate2806(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2806.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "boolean"){
validate2806.errors = [{}];
return false;
}
validate2806.errors = vErrors;
return errors === 0;
}
validate2806.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema763 = {"type":"object","additionalProperties":false,"properties":{"months":{"$ref":"#/$defs/CatalogResponse/$defs/T125"},"days":{"$ref":"#/$defs/CatalogResponse/$defs/T125"},"nanos":{"$ref":"#/$defs/CatalogResponse/$defs/T125"}},"required":["months","days","nanos"]};

function validate2813(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2813.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((((data.months === undefined) && (missing0 = "months")) || ((data.days === undefined) && (missing0 = "days"))) || ((data.nanos === undefined) && (missing0 = "nanos"))){
validate2813.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "months") || (key0 === "days")) || (key0 === "nanos"))){
validate2813.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.months !== undefined){
const _errs2 = errors;
if(!(validate2801(data.months, {instancePath:instancePath+"/months",parentData:data,parentDataProperty:"months",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2801.errors : vErrors.concat(validate2801.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.days !== undefined){
const _errs3 = errors;
if(!(validate2801(data.days, {instancePath:instancePath+"/days",parentData:data,parentDataProperty:"days",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2801.errors : vErrors.concat(validate2801.errors);
errors = vErrors.length;
}
var valid0 = _errs3 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.nanos !== undefined){
const _errs4 = errors;
if(!(validate2801(data.nanos, {instancePath:instancePath+"/nanos",parentData:data,parentDataProperty:"nanos",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2801.errors : vErrors.concat(validate2801.errors);
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
validate2813.errors = [{}];
return false;
}
}
validate2813.errors = vErrors;
return errors === 0;
}
validate2813.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate2800(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2800.evaluated;
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
if((data.signed === undefined) && (missing0 = "signed")){
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
const _errs3 = errors;
for(const key0 in data){
if(!(key0 === "signed")){
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
if(_errs3 === errors){
if(data.signed !== undefined){
if(!(validate2801(data.signed, {instancePath:instancePath+"/signed",parentData:data,parentDataProperty:"signed",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2801.errors : vErrors.concat(validate2801.errors);
errors = vErrors.length;
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
var _valid0 = _errs1 === errors;
if(_valid0){
valid0 = true;
passing0 = 0;
var props0 = true;
}
const _errs5 = errors;
if(errors === _errs5){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing1;
if((data.unsigned === undefined) && (missing1 = "unsigned")){
const err3 = {};
if(vErrors === null){
vErrors = [err3];
}
else {
vErrors.push(err3);
}
errors++;
}
else {
const _errs7 = errors;
for(const key1 in data){
if(!(key1 === "unsigned")){
const err4 = {};
if(vErrors === null){
vErrors = [err4];
}
else {
vErrors.push(err4);
}
errors++;
break;
}
}
if(_errs7 === errors){
if(data.unsigned !== undefined){
if(!(validate2801(data.unsigned, {instancePath:instancePath+"/unsigned",parentData:data,parentDataProperty:"unsigned",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2801.errors : vErrors.concat(validate2801.errors);
errors = vErrors.length;
}
}
}
}
}
else {
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
var _valid0 = _errs5 === errors;
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
const _errs9 = errors;
if(errors === _errs9){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing2;
if((data.decimal === undefined) && (missing2 = "decimal")){
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
const _errs11 = errors;
for(const key2 in data){
if(!(key2 === "decimal")){
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
if(_errs11 === errors){
if(data.decimal !== undefined){
if(!(validate2801(data.decimal, {instancePath:instancePath+"/decimal",parentData:data,parentDataProperty:"decimal",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2801.errors : vErrors.concat(validate2801.errors);
errors = vErrors.length;
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
var _valid0 = _errs9 === errors;
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
const _errs13 = errors;
if(errors === _errs13){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing3;
if((data.float_bits === undefined) && (missing3 = "float_bits")){
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
const _errs15 = errors;
for(const key3 in data){
if(!(key3 === "float_bits")){
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
if(_errs15 === errors){
if(data.float_bits !== undefined){
if(!(validate2801(data.float_bits, {instancePath:instancePath+"/float_bits",parentData:data,parentDataProperty:"float_bits",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2801.errors : vErrors.concat(validate2801.errors);
errors = vErrors.length;
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
var _valid0 = _errs13 === errors;
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
const _errs17 = errors;
if(errors === _errs17){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing4;
if((data.boolean === undefined) && (missing4 = "boolean")){
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
const _errs19 = errors;
for(const key4 in data){
if(!(key4 === "boolean")){
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
if(_errs19 === errors){
if(data.boolean !== undefined){
if(!(validate2806(data.boolean, {instancePath:instancePath+"/boolean",parentData:data,parentDataProperty:"boolean",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2806.errors : vErrors.concat(validate2806.errors);
errors = vErrors.length;
}
}
}
}
}
else {
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
var _valid0 = _errs17 === errors;
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
const _errs21 = errors;
if(errors === _errs21){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing5;
if((data.utf8 === undefined) && (missing5 = "utf8")){
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
const _errs23 = errors;
for(const key5 in data){
if(!(key5 === "utf8")){
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
if(_errs23 === errors){
if(data.utf8 !== undefined){
if(!(validate2801(data.utf8, {instancePath:instancePath+"/utf8",parentData:data,parentDataProperty:"utf8",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2801.errors : vErrors.concat(validate2801.errors);
errors = vErrors.length;
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
var _valid0 = _errs21 === errors;
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
const _errs25 = errors;
if(errors === _errs25){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing6;
if((data.binary === undefined) && (missing6 = "binary")){
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
const _errs27 = errors;
for(const key6 in data){
if(!(key6 === "binary")){
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
if(_errs27 === errors){
if(data.binary !== undefined){
if(!(validate2801(data.binary, {instancePath:instancePath+"/binary",parentData:data,parentDataProperty:"binary",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2801.errors : vErrors.concat(validate2801.errors);
errors = vErrors.length;
}
}
}
}
}
else {
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
var _valid0 = _errs25 === errors;
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
const _errs29 = errors;
if(errors === _errs29){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing7;
if((data.date_days === undefined) && (missing7 = "date_days")){
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
const _errs31 = errors;
for(const key7 in data){
if(!(key7 === "date_days")){
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
if(_errs31 === errors){
if(data.date_days !== undefined){
if(!(validate2801(data.date_days, {instancePath:instancePath+"/date_days",parentData:data,parentDataProperty:"date_days",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2801.errors : vErrors.concat(validate2801.errors);
errors = vErrors.length;
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
var _valid0 = _errs29 === errors;
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
const _errs33 = errors;
if(errors === _errs33){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing8;
if((data.time_nanos === undefined) && (missing8 = "time_nanos")){
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
const _errs35 = errors;
for(const key8 in data){
if(!(key8 === "time_nanos")){
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
if(_errs35 === errors){
if(data.time_nanos !== undefined){
if(!(validate2801(data.time_nanos, {instancePath:instancePath+"/time_nanos",parentData:data,parentDataProperty:"time_nanos",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2801.errors : vErrors.concat(validate2801.errors);
errors = vErrors.length;
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
var _valid0 = _errs33 === errors;
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
const _errs37 = errors;
if(errors === _errs37){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing9;
if((data.timestamp_micros === undefined) && (missing9 = "timestamp_micros")){
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
const _errs39 = errors;
for(const key9 in data){
if(!(key9 === "timestamp_micros")){
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
if(_errs39 === errors){
if(data.timestamp_micros !== undefined){
if(!(validate2801(data.timestamp_micros, {instancePath:instancePath+"/timestamp_micros",parentData:data,parentDataProperty:"timestamp_micros",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2801.errors : vErrors.concat(validate2801.errors);
errors = vErrors.length;
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
var _valid0 = _errs37 === errors;
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
const _errs41 = errors;
if(errors === _errs41){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing10;
if((data.interval === undefined) && (missing10 = "interval")){
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
const _errs43 = errors;
for(const key10 in data){
if(!(key10 === "interval")){
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
if(_errs43 === errors){
if(data.interval !== undefined){
if(!(validate2813(data.interval, {instancePath:instancePath+"/interval",parentData:data,parentDataProperty:"interval",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2813.errors : vErrors.concat(validate2813.errors);
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
var _valid0 = _errs41 === errors;
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
const _errs45 = errors;
if(errors === _errs45){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing11;
if((data.uuid === undefined) && (missing11 = "uuid")){
const err33 = {};
if(vErrors === null){
vErrors = [err33];
}
else {
vErrors.push(err33);
}
errors++;
}
else {
const _errs47 = errors;
for(const key11 in data){
if(!(key11 === "uuid")){
const err34 = {};
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
if(_errs47 === errors){
if(data.uuid !== undefined){
if(!(validate2801(data.uuid, {instancePath:instancePath+"/uuid",parentData:data,parentDataProperty:"uuid",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2801.errors : vErrors.concat(validate2801.errors);
errors = vErrors.length;
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
var _valid0 = _errs45 === errors;
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
const err36 = {};
if(vErrors === null){
vErrors = [err36];
}
else {
vErrors.push(err36);
}
errors++;
validate2800.errors = vErrors;
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
validate2800.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate2800.evaluated = {"dynamicProps":true,"dynamicItems":false};

const schema764 = {"type":"array","maxItems":65536,"items":{"$ref":"#/$defs/CatalogResponse/$defs/T129"}};
const schema765 = {"type":"object","additionalProperties":false,"properties":{"key":{"$ref":"#/$defs/CatalogResponse/$defs/T124"},"value":{"$ref":"#/$defs/CatalogResponse/$defs/T120"}},"required":["key","value"]};
const wrapper49 = {validate: validate2793};

function validate2821(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2821.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if(((data.key === undefined) && (missing0 = "key")) || ((data.value === undefined) && (missing0 = "value"))){
validate2821.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "key") || (key0 === "value"))){
validate2821.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.key !== undefined){
const _errs2 = errors;
if(!(validate2800(data.key, {instancePath:instancePath+"/key",parentData:data,parentDataProperty:"key",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2800.errors : vErrors.concat(validate2800.errors);
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
if(!(wrapper49.validate(data.value, {instancePath:instancePath+"/value",parentData:data,parentDataProperty:"value",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? wrapper49.validate.errors : vErrors.concat(wrapper49.validate.errors);
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
validate2821.errors = [{}];
return false;
}
}
validate2821.errors = vErrors;
return errors === 0;
}
validate2821.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate2820(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2820.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(Array.isArray(data)){
if(data.length > 65536){
validate2820.errors = [{}];
return false;
}
else {
var valid0 = true;
const len0 = data.length;
for(let i0=0; i0<len0; i0++){
const _errs1 = errors;
if(!(validate2821(data[i0], {instancePath:instancePath+"/" + i0,parentData:data,parentDataProperty:i0,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2821.errors : vErrors.concat(validate2821.errors);
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
validate2820.errors = [{}];
return false;
}
}
validate2820.errors = vErrors;
return errors === 0;
}
validate2820.evaluated = {"items":true,"dynamicProps":false,"dynamicItems":false};

const schema766 = {"type":"object","additionalProperties":false,"properties":{"index":{"$ref":"#/$defs/CatalogResponse/$defs/T131"},"value":{"$ref":"#/$defs/CatalogResponse/$defs/T132"}},"required":["index","value"]};

function validate2826(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2826.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(!(((typeof data == "number") && (!(data % 1) && !isNaN(data))) && (isFinite(data)))){
validate2826.errors = [{}];
return false;
}
if(errors === 0){
if((typeof data == "number") && (isFinite(data))){
if(data > 255 || isNaN(data)){
validate2826.errors = [{}];
return false;
}
else {
if(data < 0 || isNaN(data)){
validate2826.errors = [{}];
return false;
}
}
}
}
validate2826.errors = vErrors;
return errors === 0;
}
validate2826.evaluated = {"dynamicProps":false,"dynamicItems":false};


function validate2825(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2825.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if(((data.index === undefined) && (missing0 = "index")) || ((data.value === undefined) && (missing0 = "value"))){
validate2825.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "index") || (key0 === "value"))){
validate2825.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.index !== undefined){
const _errs2 = errors;
if(!(validate2826(data.index, {instancePath:instancePath+"/index",parentData:data,parentDataProperty:"index",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2826.errors : vErrors.concat(validate2826.errors);
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
if(!(wrapper49.validate(data.value, {instancePath:instancePath+"/value",parentData:data,parentDataProperty:"value",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? wrapper49.validate.errors : vErrors.concat(wrapper49.validate.errors);
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
validate2825.errors = [{}];
return false;
}
}
validate2825.errors = vErrors;
return errors === 0;
}
validate2825.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema768 = {"type":"object","additionalProperties":false,"properties":{"is_empty":{"$ref":"#/$defs/CatalogResponse/$defs/T126"},"lower":{"$ref":"#/$defs/CatalogResponse/$defs/T134"},"upper":{"$ref":"#/$defs/CatalogResponse/$defs/T134"}},"required":["is_empty","lower","upper"]};
const schema769 = {"anyOf":[{"$ref":"#/$defs/CatalogResponse/$defs/T135"},{"type":"null"}]};
const schema770 = {"type":"object","additionalProperties":false,"properties":{"value":{"$ref":"#/$defs/CatalogResponse/$defs/T124"},"inclusive":{"$ref":"#/$defs/CatalogResponse/$defs/T126"}},"required":["value","inclusive"]};

function validate2833(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2833.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if(((data.value === undefined) && (missing0 = "value")) || ((data.inclusive === undefined) && (missing0 = "inclusive"))){
validate2833.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "value") || (key0 === "inclusive"))){
validate2833.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.value !== undefined){
const _errs2 = errors;
if(!(validate2800(data.value, {instancePath:instancePath+"/value",parentData:data,parentDataProperty:"value",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2800.errors : vErrors.concat(validate2800.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.inclusive !== undefined){
const _errs3 = errors;
if(!(validate2806(data.inclusive, {instancePath:instancePath+"/inclusive",parentData:data,parentDataProperty:"inclusive",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2806.errors : vErrors.concat(validate2806.errors);
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
validate2833.errors = [{}];
return false;
}
}
validate2833.errors = vErrors;
return errors === 0;
}
validate2833.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate2832(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2832.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate2833(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2833.errors : vErrors.concat(validate2833.errors);
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
validate2832.errors = vErrors;
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
validate2832.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate2832.evaluated = {"dynamicProps":true,"dynamicItems":false};


function validate2830(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2830.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((((data.is_empty === undefined) && (missing0 = "is_empty")) || ((data.lower === undefined) && (missing0 = "lower"))) || ((data.upper === undefined) && (missing0 = "upper"))){
validate2830.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "is_empty") || (key0 === "lower")) || (key0 === "upper"))){
validate2830.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.is_empty !== undefined){
const _errs2 = errors;
if(!(validate2806(data.is_empty, {instancePath:instancePath+"/is_empty",parentData:data,parentDataProperty:"is_empty",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2806.errors : vErrors.concat(validate2806.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.lower !== undefined){
const _errs3 = errors;
if(!(validate2832(data.lower, {instancePath:instancePath+"/lower",parentData:data,parentDataProperty:"lower",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2832.errors : vErrors.concat(validate2832.errors);
errors = vErrors.length;
}
var valid0 = _errs3 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.upper !== undefined){
const _errs4 = errors;
if(!(validate2832(data.upper, {instancePath:instancePath+"/upper",parentData:data,parentDataProperty:"upper",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2832.errors : vErrors.concat(validate2832.errors);
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
validate2830.errors = [{}];
return false;
}
}
validate2830.errors = vErrors;
return errors === 0;
}
validate2830.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema771 = {"type":"array","maxItems":65536,"items":{"$ref":"#/$defs/CatalogResponse/$defs/T133"}};

function validate2840(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2840.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(Array.isArray(data)){
if(data.length > 65536){
validate2840.errors = [{}];
return false;
}
else {
var valid0 = true;
const len0 = data.length;
for(let i0=0; i0<len0; i0++){
const _errs1 = errors;
if(!(validate2830(data[i0], {instancePath:instancePath+"/" + i0,parentData:data,parentDataProperty:i0,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2830.errors : vErrors.concat(validate2830.errors);
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
validate2840.errors = [{}];
return false;
}
}
validate2840.errors = vErrors;
return errors === 0;
}
validate2840.evaluated = {"items":true,"dynamicProps":false,"dynamicItems":false};

const wrapper46 = {validate: validate2792};

function validate2799(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2799.evaluated;
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
if((data.atom === undefined) && (missing0 = "atom")){
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
const _errs3 = errors;
for(const key0 in data){
if(!(key0 === "atom")){
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
if(_errs3 === errors){
if(data.atom !== undefined){
if(!(validate2800(data.atom, {instancePath:instancePath+"/atom",parentData:data,parentDataProperty:"atom",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2800.errors : vErrors.concat(validate2800.errors);
errors = vErrors.length;
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
var _valid0 = _errs1 === errors;
if(_valid0){
valid0 = true;
passing0 = 0;
var props1 = true;
}
const _errs5 = errors;
if(errors === _errs5){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing1;
if((data.structure === undefined) && (missing1 = "structure")){
const err3 = {};
if(vErrors === null){
vErrors = [err3];
}
else {
vErrors.push(err3);
}
errors++;
}
else {
const _errs7 = errors;
for(const key1 in data){
if(!(key1 === "structure")){
const err4 = {};
if(vErrors === null){
vErrors = [err4];
}
else {
vErrors.push(err4);
}
errors++;
break;
}
}
if(_errs7 === errors){
if(data.structure !== undefined){
if(!(wrapper46.validate(data.structure, {instancePath:instancePath+"/structure",parentData:data,parentDataProperty:"structure",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? wrapper46.validate.errors : vErrors.concat(wrapper46.validate.errors);
errors = vErrors.length;
}
}
}
}
}
else {
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
var _valid0 = _errs5 === errors;
if(_valid0 && valid0){
valid0 = false;
passing0 = [passing0, 1];
}
else {
if(_valid0){
valid0 = true;
passing0 = 1;
if(props1 !== true){
props1 = true;
}
}
const _errs9 = errors;
if(errors === _errs9){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing2;
if((data.list === undefined) && (missing2 = "list")){
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
const _errs11 = errors;
for(const key2 in data){
if(!(key2 === "list")){
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
if(_errs11 === errors){
if(data.list !== undefined){
if(!(wrapper46.validate(data.list, {instancePath:instancePath+"/list",parentData:data,parentDataProperty:"list",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? wrapper46.validate.errors : vErrors.concat(wrapper46.validate.errors);
errors = vErrors.length;
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
var _valid0 = _errs9 === errors;
if(_valid0 && valid0){
valid0 = false;
passing0 = [passing0, 2];
}
else {
if(_valid0){
valid0 = true;
passing0 = 2;
if(props1 !== true){
props1 = true;
}
}
const _errs13 = errors;
if(errors === _errs13){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing3;
if((data.array === undefined) && (missing3 = "array")){
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
const _errs15 = errors;
for(const key3 in data){
if(!(key3 === "array")){
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
if(_errs15 === errors){
if(data.array !== undefined){
if(!(wrapper46.validate(data.array, {instancePath:instancePath+"/array",parentData:data,parentDataProperty:"array",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? wrapper46.validate.errors : vErrors.concat(wrapper46.validate.errors);
errors = vErrors.length;
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
var _valid0 = _errs13 === errors;
if(_valid0 && valid0){
valid0 = false;
passing0 = [passing0, 3];
}
else {
if(_valid0){
valid0 = true;
passing0 = 3;
if(props1 !== true){
props1 = true;
}
}
const _errs17 = errors;
if(errors === _errs17){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing4;
if((data.map === undefined) && (missing4 = "map")){
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
const _errs19 = errors;
for(const key4 in data){
if(!(key4 === "map")){
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
if(_errs19 === errors){
if(data.map !== undefined){
if(!(validate2820(data.map, {instancePath:instancePath+"/map",parentData:data,parentDataProperty:"map",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2820.errors : vErrors.concat(validate2820.errors);
errors = vErrors.length;
}
}
}
}
}
else {
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
var _valid0 = _errs17 === errors;
if(_valid0 && valid0){
valid0 = false;
passing0 = [passing0, 4];
}
else {
if(_valid0){
valid0 = true;
passing0 = 4;
if(props1 !== true){
props1 = true;
}
}
const _errs21 = errors;
if(errors === _errs21){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing5;
if((data.tagged_union === undefined) && (missing5 = "tagged_union")){
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
const _errs23 = errors;
for(const key5 in data){
if(!(key5 === "tagged_union")){
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
if(_errs23 === errors){
if(data.tagged_union !== undefined){
if(!(validate2825(data.tagged_union, {instancePath:instancePath+"/tagged_union",parentData:data,parentDataProperty:"tagged_union",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2825.errors : vErrors.concat(validate2825.errors);
errors = vErrors.length;
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
var _valid0 = _errs21 === errors;
if(_valid0 && valid0){
valid0 = false;
passing0 = [passing0, 5];
}
else {
if(_valid0){
valid0 = true;
passing0 = 5;
if(props1 !== true){
props1 = true;
}
}
const _errs25 = errors;
if(errors === _errs25){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing6;
if((data.json === undefined) && (missing6 = "json")){
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
const _errs27 = errors;
for(const key6 in data){
if(!(key6 === "json")){
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
if(_errs27 === errors){
if(data.json !== undefined){
if(!(validate2801(data.json, {instancePath:instancePath+"/json",parentData:data,parentDataProperty:"json",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2801.errors : vErrors.concat(validate2801.errors);
errors = vErrors.length;
}
}
}
}
}
else {
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
var _valid0 = _errs25 === errors;
if(_valid0 && valid0){
valid0 = false;
passing0 = [passing0, 6];
}
else {
if(_valid0){
valid0 = true;
passing0 = 6;
if(props1 !== true){
props1 = true;
}
}
const _errs29 = errors;
if(errors === _errs29){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing7;
if((data.range === undefined) && (missing7 = "range")){
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
const _errs31 = errors;
for(const key7 in data){
if(!(key7 === "range")){
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
if(_errs31 === errors){
if(data.range !== undefined){
if(!(validate2830(data.range, {instancePath:instancePath+"/range",parentData:data,parentDataProperty:"range",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2830.errors : vErrors.concat(validate2830.errors);
errors = vErrors.length;
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
var _valid0 = _errs29 === errors;
if(_valid0 && valid0){
valid0 = false;
passing0 = [passing0, 7];
}
else {
if(_valid0){
valid0 = true;
passing0 = 7;
if(props1 !== true){
props1 = true;
}
}
const _errs33 = errors;
if(errors === _errs33){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing8;
if((data.multirange === undefined) && (missing8 = "multirange")){
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
const _errs35 = errors;
for(const key8 in data){
if(!(key8 === "multirange")){
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
if(_errs35 === errors){
if(data.multirange !== undefined){
if(!(validate2840(data.multirange, {instancePath:instancePath+"/multirange",parentData:data,parentDataProperty:"multirange",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2840.errors : vErrors.concat(validate2840.errors);
errors = vErrors.length;
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
var _valid0 = _errs33 === errors;
if(_valid0 && valid0){
valid0 = false;
passing0 = [passing0, 8];
}
else {
if(_valid0){
valid0 = true;
passing0 = 8;
if(props1 !== true){
props1 = true;
}
}
const _errs37 = errors;
if(errors === _errs37){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing9;
if((data.vector === undefined) && (missing9 = "vector")){
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
const _errs39 = errors;
for(const key9 in data){
if(!(key9 === "vector")){
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
if(_errs39 === errors){
if(data.vector !== undefined){
if(!(validate2801(data.vector, {instancePath:instancePath+"/vector",parentData:data,parentDataProperty:"vector",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2801.errors : vErrors.concat(validate2801.errors);
errors = vErrors.length;
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
var _valid0 = _errs37 === errors;
if(_valid0 && valid0){
valid0 = false;
passing0 = [passing0, 9];
}
else {
if(_valid0){
valid0 = true;
passing0 = 9;
if(props1 !== true){
props1 = true;
}
}
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
const err30 = {};
if(vErrors === null){
vErrors = [err30];
}
else {
vErrors.push(err30);
}
errors++;
validate2799.errors = vErrors;
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
validate2799.errors = vErrors;
evaluated0.props = props1;
return errors === 0;
}
validate2799.evaluated = {"dynamicProps":true,"dynamicItems":false};

const schema772 = {"type":"array","maxItems":65536,"items":{"$ref":"#/$defs/CatalogResponse/$defs/T138"}};
const schema773 = {"type":"object","additionalProperties":false,"properties":{"counter":{"$ref":"#/$defs/CatalogResponse/$defs/T125"},"replica":{"$ref":"#/$defs/CatalogResponse/$defs/T125"},"value":{"$ref":"#/$defs/CatalogResponse/$defs/T139"}},"required":["counter","replica","value"]};
const schema774 = {"oneOf":[{"type":"object","additionalProperties":false,"required":["null"],"properties":{"null":{"$ref":"#/$defs/CatalogResponse/$defs/T121"}}},{"type":"object","additionalProperties":false,"required":["type_error"],"properties":{"type_error":{"$ref":"#/$defs/CatalogResponse/$defs/T122"}}},{"type":"object","additionalProperties":false,"required":["value"],"properties":{"value":{"$ref":"#/$defs/CatalogResponse/$defs/T123"}}}]};

function validate2849(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2849.evaluated;
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
if((data.null === undefined) && (missing0 = "null")){
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
const _errs3 = errors;
for(const key0 in data){
if(!(key0 === "null")){
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
if(_errs3 === errors){
if(data.null !== undefined){
if(!(validate2794(data.null, {instancePath:instancePath+"/null",parentData:data,parentDataProperty:"null",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2794.errors : vErrors.concat(validate2794.errors);
errors = vErrors.length;
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
var _valid0 = _errs1 === errors;
if(_valid0){
valid0 = true;
passing0 = 0;
var props0 = true;
}
const _errs5 = errors;
if(errors === _errs5){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing1;
if((data.type_error === undefined) && (missing1 = "type_error")){
const err3 = {};
if(vErrors === null){
vErrors = [err3];
}
else {
vErrors.push(err3);
}
errors++;
}
else {
const _errs7 = errors;
for(const key1 in data){
if(!(key1 === "type_error")){
const err4 = {};
if(vErrors === null){
vErrors = [err4];
}
else {
vErrors.push(err4);
}
errors++;
break;
}
}
if(_errs7 === errors){
if(data.type_error !== undefined){
if(!(validate2797(data.type_error, {instancePath:instancePath+"/type_error",parentData:data,parentDataProperty:"type_error",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2797.errors : vErrors.concat(validate2797.errors);
errors = vErrors.length;
}
}
}
}
}
else {
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
var _valid0 = _errs5 === errors;
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
const _errs9 = errors;
if(errors === _errs9){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing2;
if((data.value === undefined) && (missing2 = "value")){
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
const _errs11 = errors;
for(const key2 in data){
if(!(key2 === "value")){
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
if(_errs11 === errors){
if(data.value !== undefined){
if(!(validate2799(data.value, {instancePath:instancePath+"/value",parentData:data,parentDataProperty:"value",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2799.errors : vErrors.concat(validate2799.errors);
errors = vErrors.length;
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
var _valid0 = _errs9 === errors;
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
const err9 = {};
if(vErrors === null){
vErrors = [err9];
}
else {
vErrors.push(err9);
}
errors++;
validate2849.errors = vErrors;
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
validate2849.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate2849.evaluated = {"dynamicProps":true,"dynamicItems":false};


function validate2846(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2846.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((((data.counter === undefined) && (missing0 = "counter")) || ((data.replica === undefined) && (missing0 = "replica"))) || ((data.value === undefined) && (missing0 = "value"))){
validate2846.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "counter") || (key0 === "replica")) || (key0 === "value"))){
validate2846.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.counter !== undefined){
const _errs2 = errors;
if(!(validate2801(data.counter, {instancePath:instancePath+"/counter",parentData:data,parentDataProperty:"counter",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2801.errors : vErrors.concat(validate2801.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.replica !== undefined){
const _errs3 = errors;
if(!(validate2801(data.replica, {instancePath:instancePath+"/replica",parentData:data,parentDataProperty:"replica",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2801.errors : vErrors.concat(validate2801.errors);
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
if(!(validate2849(data.value, {instancePath:instancePath+"/value",parentData:data,parentDataProperty:"value",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2849.errors : vErrors.concat(validate2849.errors);
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
validate2846.errors = [{}];
return false;
}
}
validate2846.errors = vErrors;
return errors === 0;
}
validate2846.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate2845(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2845.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(Array.isArray(data)){
if(data.length > 65536){
validate2845.errors = [{}];
return false;
}
else {
var valid0 = true;
const len0 = data.length;
for(let i0=0; i0<len0; i0++){
const _errs1 = errors;
if(!(validate2846(data[i0], {instancePath:instancePath+"/" + i0,parentData:data,parentDataProperty:i0,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2846.errors : vErrors.concat(validate2846.errors);
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
validate2845.errors = [{}];
return false;
}
}
validate2845.errors = vErrors;
return errors === 0;
}
validate2845.evaluated = {"items":true,"dynamicProps":false,"dynamicItems":false};


function validate2793(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2793.evaluated;
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
if((data.missing === undefined) && (missing0 = "missing")){
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
const _errs3 = errors;
for(const key0 in data){
if(!(key0 === "missing")){
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
if(_errs3 === errors){
if(data.missing !== undefined){
if(!(validate2794(data.missing, {instancePath:instancePath+"/missing",parentData:data,parentDataProperty:"missing",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2794.errors : vErrors.concat(validate2794.errors);
errors = vErrors.length;
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
var _valid0 = _errs1 === errors;
if(_valid0){
valid0 = true;
passing0 = 0;
var props0 = true;
}
const _errs5 = errors;
if(errors === _errs5){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing1;
if((data.null === undefined) && (missing1 = "null")){
const err3 = {};
if(vErrors === null){
vErrors = [err3];
}
else {
vErrors.push(err3);
}
errors++;
}
else {
const _errs7 = errors;
for(const key1 in data){
if(!(key1 === "null")){
const err4 = {};
if(vErrors === null){
vErrors = [err4];
}
else {
vErrors.push(err4);
}
errors++;
break;
}
}
if(_errs7 === errors){
if(data.null !== undefined){
if(!(validate2794(data.null, {instancePath:instancePath+"/null",parentData:data,parentDataProperty:"null",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2794.errors : vErrors.concat(validate2794.errors);
errors = vErrors.length;
}
}
}
}
}
else {
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
var _valid0 = _errs5 === errors;
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
const _errs9 = errors;
if(errors === _errs9){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing2;
if((data.type_error === undefined) && (missing2 = "type_error")){
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
const _errs11 = errors;
for(const key2 in data){
if(!(key2 === "type_error")){
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
if(_errs11 === errors){
if(data.type_error !== undefined){
if(!(validate2797(data.type_error, {instancePath:instancePath+"/type_error",parentData:data,parentDataProperty:"type_error",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2797.errors : vErrors.concat(validate2797.errors);
errors = vErrors.length;
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
var _valid0 = _errs9 === errors;
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
const _errs13 = errors;
if(errors === _errs13){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing3;
if((data.value === undefined) && (missing3 = "value")){
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
const _errs15 = errors;
for(const key3 in data){
if(!(key3 === "value")){
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
if(_errs15 === errors){
if(data.value !== undefined){
if(!(validate2799(data.value, {instancePath:instancePath+"/value",parentData:data,parentDataProperty:"value",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2799.errors : vErrors.concat(validate2799.errors);
errors = vErrors.length;
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
var _valid0 = _errs13 === errors;
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
const _errs17 = errors;
if(errors === _errs17){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing4;
if((data.conflict === undefined) && (missing4 = "conflict")){
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
const _errs19 = errors;
for(const key4 in data){
if(!(key4 === "conflict")){
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
if(_errs19 === errors){
if(data.conflict !== undefined){
if(!(validate2845(data.conflict, {instancePath:instancePath+"/conflict",parentData:data,parentDataProperty:"conflict",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2845.errors : vErrors.concat(validate2845.errors);
errors = vErrors.length;
}
}
}
}
}
else {
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
var _valid0 = _errs17 === errors;
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
}
}
}
}
if(!valid0){
const err15 = {};
if(vErrors === null){
vErrors = [err15];
}
else {
vErrors.push(err15);
}
errors++;
validate2793.errors = vErrors;
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
validate2793.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate2793.evaluated = {"dynamicProps":true,"dynamicItems":false};


function validate2792(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2792.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(Array.isArray(data)){
if(data.length > 65536){
validate2792.errors = [{}];
return false;
}
else {
var valid0 = true;
const len0 = data.length;
for(let i0=0; i0<len0; i0++){
const _errs1 = errors;
if(!(validate2793(data[i0], {instancePath:instancePath+"/" + i0,parentData:data,parentDataProperty:i0,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2793.errors : vErrors.concat(validate2793.errors);
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
validate2792.errors = [{}];
return false;
}
}
validate2792.errors = vErrors;
return errors === 0;
}
validate2792.evaluated = {"items":true,"dynamicProps":false,"dynamicItems":false};

const schema775 = {"type":"object","additionalProperties":false,"properties":{"index":{"$ref":"#/$defs/CatalogResponse/$defs/T91"},"value":{"$ref":"#/$defs/CatalogResponse/$defs/T141"}},"required":["index","value"]};
const wrapper51 = {validate: validate2768};

function validate2861(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2861.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if(((data.index === undefined) && (missing0 = "index")) || ((data.value === undefined) && (missing0 = "value"))){
validate2861.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "index") || (key0 === "value"))){
validate2861.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.index !== undefined){
const _errs2 = errors;
if(!(validate2681(data.index, {instancePath:instancePath+"/index",parentData:data,parentDataProperty:"index",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2681.errors : vErrors.concat(validate2681.errors);
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
if(!(wrapper51.validate(data.value, {instancePath:instancePath+"/value",parentData:data,parentDataProperty:"value",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? wrapper51.validate.errors : vErrors.concat(wrapper51.validate.errors);
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
validate2861.errors = [{}];
return false;
}
}
validate2861.errors = vErrors;
return errors === 0;
}
validate2861.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema776 = {"type":"object","additionalProperties":false,"properties":{"is_empty":{"$ref":"#/$defs/CatalogResponse/$defs/T107"},"lower":{"$ref":"#/$defs/CatalogResponse/$defs/T143"},"upper":{"$ref":"#/$defs/CatalogResponse/$defs/T143"}},"required":["is_empty","lower","upper"]};
const schema777 = {"anyOf":[{"$ref":"#/$defs/CatalogResponse/$defs/T144"},{"type":"null"}]};
const schema778 = {"type":"object","additionalProperties":false,"properties":{"value":{"$ref":"#/$defs/CatalogResponse/$defs/T117"},"inclusive":{"$ref":"#/$defs/CatalogResponse/$defs/T107"}},"required":["value","inclusive"]};

function validate2868(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2868.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if(((data.value === undefined) && (missing0 = "value")) || ((data.inclusive === undefined) && (missing0 = "inclusive"))){
validate2868.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "value") || (key0 === "inclusive"))){
validate2868.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.value !== undefined){
const _errs2 = errors;
if(!(validate2774(data.value, {instancePath:instancePath+"/value",parentData:data,parentDataProperty:"value",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2774.errors : vErrors.concat(validate2774.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.inclusive !== undefined){
const _errs3 = errors;
if(!(validate2746(data.inclusive, {instancePath:instancePath+"/inclusive",parentData:data,parentDataProperty:"inclusive",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2746.errors : vErrors.concat(validate2746.errors);
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
validate2868.errors = [{}];
return false;
}
}
validate2868.errors = vErrors;
return errors === 0;
}
validate2868.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate2867(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2867.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate2868(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2868.errors : vErrors.concat(validate2868.errors);
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
validate2867.errors = vErrors;
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
validate2867.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate2867.evaluated = {"dynamicProps":true,"dynamicItems":false};


function validate2865(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2865.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((((data.is_empty === undefined) && (missing0 = "is_empty")) || ((data.lower === undefined) && (missing0 = "lower"))) || ((data.upper === undefined) && (missing0 = "upper"))){
validate2865.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "is_empty") || (key0 === "lower")) || (key0 === "upper"))){
validate2865.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.is_empty !== undefined){
const _errs2 = errors;
if(!(validate2746(data.is_empty, {instancePath:instancePath+"/is_empty",parentData:data,parentDataProperty:"is_empty",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2746.errors : vErrors.concat(validate2746.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.lower !== undefined){
const _errs3 = errors;
if(!(validate2867(data.lower, {instancePath:instancePath+"/lower",parentData:data,parentDataProperty:"lower",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2867.errors : vErrors.concat(validate2867.errors);
errors = vErrors.length;
}
var valid0 = _errs3 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.upper !== undefined){
const _errs4 = errors;
if(!(validate2867(data.upper, {instancePath:instancePath+"/upper",parentData:data,parentDataProperty:"upper",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2867.errors : vErrors.concat(validate2867.errors);
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
validate2865.errors = [{}];
return false;
}
}
validate2865.errors = vErrors;
return errors === 0;
}
validate2865.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate2773(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2773.evaluated;
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
if((data.atom === undefined) && (missing0 = "atom")){
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
const _errs3 = errors;
for(const key0 in data){
if(!(key0 === "atom")){
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
if(_errs3 === errors){
if(data.atom !== undefined){
if(!(validate2774(data.atom, {instancePath:instancePath+"/atom",parentData:data,parentDataProperty:"atom",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2774.errors : vErrors.concat(validate2774.errors);
errors = vErrors.length;
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
var _valid0 = _errs1 === errors;
if(_valid0){
valid0 = true;
passing0 = 0;
var props1 = true;
}
const _errs5 = errors;
if(errors === _errs5){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing1;
if((data.structure === undefined) && (missing1 = "structure")){
const err3 = {};
if(vErrors === null){
vErrors = [err3];
}
else {
vErrors.push(err3);
}
errors++;
}
else {
const _errs7 = errors;
for(const key1 in data){
if(!(key1 === "structure")){
const err4 = {};
if(vErrors === null){
vErrors = [err4];
}
else {
vErrors.push(err4);
}
errors++;
break;
}
}
if(_errs7 === errors){
if(data.structure !== undefined){
if(!(validate2792(data.structure, {instancePath:instancePath+"/structure",parentData:data,parentDataProperty:"structure",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2792.errors : vErrors.concat(validate2792.errors);
errors = vErrors.length;
}
}
}
}
}
else {
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
var _valid0 = _errs5 === errors;
if(_valid0 && valid0){
valid0 = false;
passing0 = [passing0, 1];
}
else {
if(_valid0){
valid0 = true;
passing0 = 1;
if(props1 !== true){
props1 = true;
}
}
const _errs9 = errors;
if(errors === _errs9){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing2;
if((data.list === undefined) && (missing2 = "list")){
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
const _errs11 = errors;
for(const key2 in data){
if(!(key2 === "list")){
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
if(_errs11 === errors){
if(data.list !== undefined){
if(!(validate2792(data.list, {instancePath:instancePath+"/list",parentData:data,parentDataProperty:"list",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2792.errors : vErrors.concat(validate2792.errors);
errors = vErrors.length;
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
var _valid0 = _errs9 === errors;
if(_valid0 && valid0){
valid0 = false;
passing0 = [passing0, 2];
}
else {
if(_valid0){
valid0 = true;
passing0 = 2;
if(props1 !== true){
props1 = true;
}
}
const _errs13 = errors;
if(errors === _errs13){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing3;
if((data.array === undefined) && (missing3 = "array")){
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
const _errs15 = errors;
for(const key3 in data){
if(!(key3 === "array")){
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
if(_errs15 === errors){
if(data.array !== undefined){
if(!(validate2792(data.array, {instancePath:instancePath+"/array",parentData:data,parentDataProperty:"array",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2792.errors : vErrors.concat(validate2792.errors);
errors = vErrors.length;
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
var _valid0 = _errs13 === errors;
if(_valid0 && valid0){
valid0 = false;
passing0 = [passing0, 3];
}
else {
if(_valid0){
valid0 = true;
passing0 = 3;
if(props1 !== true){
props1 = true;
}
}
const _errs17 = errors;
if(errors === _errs17){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing4;
if((data.map === undefined) && (missing4 = "map")){
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
const _errs19 = errors;
for(const key4 in data){
if(!(key4 === "map")){
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
if(_errs19 === errors){
if(data.map !== undefined){
if(!(validate2820(data.map, {instancePath:instancePath+"/map",parentData:data,parentDataProperty:"map",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2820.errors : vErrors.concat(validate2820.errors);
errors = vErrors.length;
}
}
}
}
}
else {
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
var _valid0 = _errs17 === errors;
if(_valid0 && valid0){
valid0 = false;
passing0 = [passing0, 4];
}
else {
if(_valid0){
valid0 = true;
passing0 = 4;
if(props1 !== true){
props1 = true;
}
}
const _errs21 = errors;
if(errors === _errs21){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing5;
if((data.tagged_union === undefined) && (missing5 = "tagged_union")){
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
const _errs23 = errors;
for(const key5 in data){
if(!(key5 === "tagged_union")){
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
if(_errs23 === errors){
if(data.tagged_union !== undefined){
if(!(validate2861(data.tagged_union, {instancePath:instancePath+"/tagged_union",parentData:data,parentDataProperty:"tagged_union",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2861.errors : vErrors.concat(validate2861.errors);
errors = vErrors.length;
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
var _valid0 = _errs21 === errors;
if(_valid0 && valid0){
valid0 = false;
passing0 = [passing0, 5];
}
else {
if(_valid0){
valid0 = true;
passing0 = 5;
if(props1 !== true){
props1 = true;
}
}
const _errs25 = errors;
if(errors === _errs25){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing6;
if((data.json === undefined) && (missing6 = "json")){
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
const _errs27 = errors;
for(const key6 in data){
if(!(key6 === "json")){
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
if(_errs27 === errors){
if(data.json !== undefined){
if(!(validate2513(data.json, {instancePath:instancePath+"/json",parentData:data,parentDataProperty:"json",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2513.errors : vErrors.concat(validate2513.errors);
errors = vErrors.length;
}
}
}
}
}
else {
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
var _valid0 = _errs25 === errors;
if(_valid0 && valid0){
valid0 = false;
passing0 = [passing0, 6];
}
else {
if(_valid0){
valid0 = true;
passing0 = 6;
if(props1 !== true){
props1 = true;
}
}
const _errs29 = errors;
if(errors === _errs29){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing7;
if((data.range === undefined) && (missing7 = "range")){
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
const _errs31 = errors;
for(const key7 in data){
if(!(key7 === "range")){
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
if(_errs31 === errors){
if(data.range !== undefined){
if(!(validate2865(data.range, {instancePath:instancePath+"/range",parentData:data,parentDataProperty:"range",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2865.errors : vErrors.concat(validate2865.errors);
errors = vErrors.length;
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
var _valid0 = _errs29 === errors;
if(_valid0 && valid0){
valid0 = false;
passing0 = [passing0, 7];
}
else {
if(_valid0){
valid0 = true;
passing0 = 7;
if(props1 !== true){
props1 = true;
}
}
const _errs33 = errors;
if(errors === _errs33){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing8;
if((data.multirange === undefined) && (missing8 = "multirange")){
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
const _errs35 = errors;
for(const key8 in data){
if(!(key8 === "multirange")){
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
if(_errs35 === errors){
if(data.multirange !== undefined){
if(!(validate2840(data.multirange, {instancePath:instancePath+"/multirange",parentData:data,parentDataProperty:"multirange",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2840.errors : vErrors.concat(validate2840.errors);
errors = vErrors.length;
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
var _valid0 = _errs33 === errors;
if(_valid0 && valid0){
valid0 = false;
passing0 = [passing0, 8];
}
else {
if(_valid0){
valid0 = true;
passing0 = 8;
if(props1 !== true){
props1 = true;
}
}
const _errs37 = errors;
if(errors === _errs37){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing9;
if((data.vector === undefined) && (missing9 = "vector")){
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
const _errs39 = errors;
for(const key9 in data){
if(!(key9 === "vector")){
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
if(_errs39 === errors){
if(data.vector !== undefined){
if(!(validate2513(data.vector, {instancePath:instancePath+"/vector",parentData:data,parentDataProperty:"vector",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2513.errors : vErrors.concat(validate2513.errors);
errors = vErrors.length;
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
var _valid0 = _errs37 === errors;
if(_valid0 && valid0){
valid0 = false;
passing0 = [passing0, 9];
}
else {
if(_valid0){
valid0 = true;
passing0 = 9;
if(props1 !== true){
props1 = true;
}
}
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
const err30 = {};
if(vErrors === null){
vErrors = [err30];
}
else {
vErrors.push(err30);
}
errors++;
validate2773.errors = vErrors;
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
validate2773.errors = vErrors;
evaluated0.props = props1;
return errors === 0;
}
validate2773.evaluated = {"dynamicProps":true,"dynamicItems":false};


function validate2768(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2768.evaluated;
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
if((data.missing === undefined) && (missing0 = "missing")){
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
const _errs3 = errors;
for(const key0 in data){
if(!(key0 === "missing")){
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
if(_errs3 === errors){
if(data.missing !== undefined){
if(!(validate2664(data.missing, {instancePath:instancePath+"/missing",parentData:data,parentDataProperty:"missing",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2664.errors : vErrors.concat(validate2664.errors);
errors = vErrors.length;
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
var _valid0 = _errs1 === errors;
if(_valid0){
valid0 = true;
passing0 = 0;
var props0 = true;
}
const _errs5 = errors;
if(errors === _errs5){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing1;
if((data.null === undefined) && (missing1 = "null")){
const err3 = {};
if(vErrors === null){
vErrors = [err3];
}
else {
vErrors.push(err3);
}
errors++;
}
else {
const _errs7 = errors;
for(const key1 in data){
if(!(key1 === "null")){
const err4 = {};
if(vErrors === null){
vErrors = [err4];
}
else {
vErrors.push(err4);
}
errors++;
break;
}
}
if(_errs7 === errors){
if(data.null !== undefined){
if(!(validate2664(data.null, {instancePath:instancePath+"/null",parentData:data,parentDataProperty:"null",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2664.errors : vErrors.concat(validate2664.errors);
errors = vErrors.length;
}
}
}
}
}
else {
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
var _valid0 = _errs5 === errors;
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
const _errs9 = errors;
if(errors === _errs9){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing2;
if((data.type_error === undefined) && (missing2 = "type_error")){
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
const _errs11 = errors;
for(const key2 in data){
if(!(key2 === "type_error")){
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
if(_errs11 === errors){
if(data.type_error !== undefined){
if(!(validate2771(data.type_error, {instancePath:instancePath+"/type_error",parentData:data,parentDataProperty:"type_error",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2771.errors : vErrors.concat(validate2771.errors);
errors = vErrors.length;
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
var _valid0 = _errs9 === errors;
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
const _errs13 = errors;
if(errors === _errs13){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing3;
if((data.value === undefined) && (missing3 = "value")){
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
const _errs15 = errors;
for(const key3 in data){
if(!(key3 === "value")){
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
if(_errs15 === errors){
if(data.value !== undefined){
if(!(validate2773(data.value, {instancePath:instancePath+"/value",parentData:data,parentDataProperty:"value",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2773.errors : vErrors.concat(validate2773.errors);
errors = vErrors.length;
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
var _valid0 = _errs13 === errors;
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
const _errs17 = errors;
if(errors === _errs17){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing4;
if((data.conflict === undefined) && (missing4 = "conflict")){
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
const _errs19 = errors;
for(const key4 in data){
if(!(key4 === "conflict")){
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
if(_errs19 === errors){
if(data.conflict !== undefined){
if(!(validate2845(data.conflict, {instancePath:instancePath+"/conflict",parentData:data,parentDataProperty:"conflict",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2845.errors : vErrors.concat(validate2845.errors);
errors = vErrors.length;
}
}
}
}
}
else {
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
var _valid0 = _errs17 === errors;
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
}
}
}
}
if(!valid0){
const err15 = {};
if(vErrors === null){
vErrors = [err15];
}
else {
vErrors.push(err15);
}
errors++;
validate2768.errors = vErrors;
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
validate2768.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate2768.evaluated = {"dynamicProps":true,"dynamicItems":false};


function validate2767(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2767.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate2768(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2768.errors : vErrors.concat(validate2768.errors);
errors = vErrors.length;
}
else {
var props0 = validate2768.evaluated.props;
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
validate2767.errors = vErrors;
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
validate2767.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate2767.evaluated = {"dynamicProps":true,"dynamicItems":false};

const schema779 = {"anyOf":[{"$ref":"#/$defs/CatalogResponse/$defs/T109"},{"type":"null"}]};

function validate2881(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2881.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate2751(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2751.errors : vErrors.concat(validate2751.errors);
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
validate2881.errors = vErrors;
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
validate2881.errors = vErrors;
return errors === 0;
}
validate2881.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema780 = {"type":"string","enum":["plain","bitpacked","rle","dictionary","fsst","comp","comp_3","zoned","ibm_hfp","ebcdic"]};

function validate2884(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2884.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate2884.errors = [{}];
return false;
}
if(!((((((((((data === "plain") || (data === "bitpacked")) || (data === "rle")) || (data === "dictionary")) || (data === "fsst")) || (data === "comp")) || (data === "comp_3")) || (data === "zoned")) || (data === "ibm_hfp")) || (data === "ebcdic"))){
validate2884.errors = [{}];
return false;
}
validate2884.errors = vErrors;
return errors === 0;
}
validate2884.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema206 = {"type":"string","enum":["none","utf8_binary","ascii_ci","ebcdic_cp037","icu_root","ebcdic_037_pad","ebcdic_1047_nopad"]};

function validate2886(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2886.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate2886.errors = [{}];
return false;
}
if(!(((((((data === "none") || (data === "utf8_binary")) || (data === "ascii_ci")) || (data === "ebcdic_cp037")) || (data === "icu_root")) || (data === "ebcdic_037_pad")) || (data === "ebcdic_1047_nopad"))){
validate2886.errors = [{}];
return false;
}
validate2886.errors = vErrors;
return errors === 0;
}
validate2886.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema782 = {"type":"object","additionalProperties":false,"properties":{"rounding":{"$ref":"#/$defs/CatalogResponse/$defs/T149"},"metric":{"$ref":"#/$defs/CatalogResponse/$defs/T151"},"timezone":{"$ref":"#/$defs/CatalogResponse/$defs/T153"},"spatial":{"$ref":"#/$defs/CatalogResponse/$defs/T157"}},"required":["rounding","metric","timezone","spatial"]};
const schema783 = {"anyOf":[{"$ref":"#/$defs/CatalogResponse/$defs/T150"},{"type":"null"}]};
const schema211 = {"type":"string","enum":["reject","half_even","toward_zero"]};

function validate2890(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2890.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate2890.errors = [{}];
return false;
}
if(!(((data === "reject") || (data === "half_even")) || (data === "toward_zero"))){
validate2890.errors = [{}];
return false;
}
validate2890.errors = vErrors;
return errors === 0;
}
validate2890.evaluated = {"dynamicProps":false,"dynamicItems":false};


function validate2889(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2889.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate2890(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2890.errors : vErrors.concat(validate2890.errors);
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
validate2889.errors = vErrors;
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
validate2889.errors = vErrors;
return errors === 0;
}
validate2889.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema785 = {"anyOf":[{"$ref":"#/$defs/CatalogResponse/$defs/T152"},{"type":"null"}]};
const schema214 = {"type":"string","enum":["l2_squared","cosine","dot_product","hamming"]};

function validate2894(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2894.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate2894.errors = [{}];
return false;
}
if(!((((data === "l2_squared") || (data === "cosine")) || (data === "dot_product")) || (data === "hamming"))){
validate2894.errors = [{}];
return false;
}
validate2894.errors = vErrors;
return errors === 0;
}
validate2894.evaluated = {"dynamicProps":false,"dynamicItems":false};


function validate2893(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2893.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate2894(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2894.errors : vErrors.concat(validate2894.errors);
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
validate2893.errors = vErrors;
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
validate2893.errors = vErrors;
return errors === 0;
}
validate2893.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema787 = {"anyOf":[{"$ref":"#/$defs/CatalogResponse/$defs/T154"},{"type":"null"}]};
const schema788 = {"type":"object","additionalProperties":false,"properties":{"version":{"$ref":"#/$defs/CatalogResponse/$defs/T155"},"zone":{"$ref":"#/$defs/CatalogResponse/$defs/T46"},"tzif_hex":{"$ref":"#/$defs/CatalogResponse/$defs/T46"}},"required":["version","zone","tzif_hex"]};
const schema789 = {"type":"object","additionalProperties":false,"properties":{"version_id":{"$ref":"#/$defs/CatalogResponse/$defs/T46"},"digest":{"$ref":"#/$defs/CatalogResponse/$defs/T156"}},"required":["version_id","digest"]};
const schema790 = {"type":"array","minItems":32,"maxItems":32,"items":{"$ref":"#/$defs/CatalogResponse/$defs/T91"}};

function validate2901(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2901.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(Array.isArray(data)){
if(data.length > 32){
validate2901.errors = [{}];
return false;
}
else {
if(data.length < 32){
validate2901.errors = [{}];
return false;
}
else {
var valid0 = true;
const len0 = data.length;
for(let i0=0; i0<len0; i0++){
const _errs1 = errors;
if(!(validate2681(data[i0], {instancePath:instancePath+"/" + i0,parentData:data,parentDataProperty:i0,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2681.errors : vErrors.concat(validate2681.errors);
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
validate2901.errors = [{}];
return false;
}
}
validate2901.errors = vErrors;
return errors === 0;
}
validate2901.evaluated = {"items":true,"dynamicProps":false,"dynamicItems":false};


function validate2899(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2899.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if(((data.version_id === undefined) && (missing0 = "version_id")) || ((data.digest === undefined) && (missing0 = "digest"))){
validate2899.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "version_id") || (key0 === "digest"))){
validate2899.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.version_id !== undefined){
const _errs2 = errors;
if(!(validate2513(data.version_id, {instancePath:instancePath+"/version_id",parentData:data,parentDataProperty:"version_id",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2513.errors : vErrors.concat(validate2513.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.digest !== undefined){
const _errs3 = errors;
if(!(validate2901(data.digest, {instancePath:instancePath+"/digest",parentData:data,parentDataProperty:"digest",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2901.errors : vErrors.concat(validate2901.errors);
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
validate2899.errors = [{}];
return false;
}
}
validate2899.errors = vErrors;
return errors === 0;
}
validate2899.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate2898(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2898.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((((data.version === undefined) && (missing0 = "version")) || ((data.zone === undefined) && (missing0 = "zone"))) || ((data.tzif_hex === undefined) && (missing0 = "tzif_hex"))){
validate2898.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "version") || (key0 === "zone")) || (key0 === "tzif_hex"))){
validate2898.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.version !== undefined){
const _errs2 = errors;
if(!(validate2899(data.version, {instancePath:instancePath+"/version",parentData:data,parentDataProperty:"version",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2899.errors : vErrors.concat(validate2899.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.zone !== undefined){
const _errs3 = errors;
if(!(validate2513(data.zone, {instancePath:instancePath+"/zone",parentData:data,parentDataProperty:"zone",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2513.errors : vErrors.concat(validate2513.errors);
errors = vErrors.length;
}
var valid0 = _errs3 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.tzif_hex !== undefined){
const _errs4 = errors;
if(!(validate2513(data.tzif_hex, {instancePath:instancePath+"/tzif_hex",parentData:data,parentDataProperty:"tzif_hex",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2513.errors : vErrors.concat(validate2513.errors);
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
validate2898.errors = [{}];
return false;
}
}
validate2898.errors = vErrors;
return errors === 0;
}
validate2898.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate2897(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2897.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate2898(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2898.errors : vErrors.concat(validate2898.errors);
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
validate2897.errors = vErrors;
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
validate2897.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate2897.evaluated = {"dynamicProps":true,"dynamicItems":false};

const schema791 = {"anyOf":[{"$ref":"#/$defs/CatalogResponse/$defs/T158"},{"type":"null"}]};
const schema792 = {"type":"object","additionalProperties":false,"properties":{"definition":{"$ref":"#/$defs/CatalogResponse/$defs/T159"},"srid":{"$ref":"#/$defs/CatalogResponse/$defs/T109"},"local_frame":{"$ref":"#/$defs/CatalogResponse/$defs/T160"},"axes":{"$ref":"#/$defs/CatalogResponse/$defs/T161"},"manifold":{"$ref":"#/$defs/CatalogResponse/$defs/T162"},"linear_unit_nm":{"$ref":"#/$defs/CatalogResponse/$defs/T46"},"vertical_datum":{"$ref":"#/$defs/CatalogResponse/$defs/T163"},"precision":{"$ref":"#/$defs/CatalogResponse/$defs/T164"}},"required":["definition","srid","local_frame","axes","manifold","linear_unit_nm","vertical_datum","precision"]};

function validate2911(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2911.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate2911.errors = [{}];
return false;
}
if(!(data === "6da8e815dec26c458515e34fb6553654d57c77536f652b9258897bf1a513842e")){
validate2911.errors = [{}];
return false;
}
validate2911.errors = vErrors;
return errors === 0;
}
validate2911.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema794 = {"type":"array","minItems":16,"maxItems":16,"items":{"$ref":"#/$defs/CatalogResponse/$defs/T91"}};

function validate2914(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2914.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(Array.isArray(data)){
if(data.length > 16){
validate2914.errors = [{}];
return false;
}
else {
if(data.length < 16){
validate2914.errors = [{}];
return false;
}
else {
var valid0 = true;
const len0 = data.length;
for(let i0=0; i0<len0; i0++){
const _errs1 = errors;
if(!(validate2681(data[i0], {instancePath:instancePath+"/" + i0,parentData:data,parentDataProperty:i0,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2681.errors : vErrors.concat(validate2681.errors);
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
validate2914.errors = [{}];
return false;
}
}
validate2914.errors = vErrors;
return errors === 0;
}
validate2914.evaluated = {"items":true,"dynamicProps":false,"dynamicItems":false};

const schema223 = {"type":"string","enum":["xy","xyz","longitude_latitude","longitude_latitude_height"]};

function validate2917(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2917.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate2917.errors = [{}];
return false;
}
if(!((((data === "xy") || (data === "xyz")) || (data === "longitude_latitude")) || (data === "longitude_latitude_height"))){
validate2917.errors = [{}];
return false;
}
validate2917.errors = vErrors;
return errors === 0;
}
validate2917.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema225 = {"type":"string","enum":["planar","wgs84_ellipsoid"]};

function validate2919(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2919.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate2919.errors = [{}];
return false;
}
if(!((data === "planar") || (data === "wgs84_ellipsoid"))){
validate2919.errors = [{}];
return false;
}
validate2919.errors = vErrors;
return errors === 0;
}
validate2919.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema227 = {"type":"string","enum":["none","local","wgs84_ellipsoid"]};

function validate2922(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2922.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate2922.errors = [{}];
return false;
}
if(!(((data === "none") || (data === "local")) || (data === "wgs84_ellipsoid"))){
validate2922.errors = [{}];
return false;
}
validate2922.errors = vErrors;
return errors === 0;
}
validate2922.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema798 = {"oneOf":[{"type":"object","additionalProperties":false,"required":["exact"],"properties":{"exact":{"$ref":"#/$defs/CatalogResponse/$defs/T89"}}},{"type":"object","additionalProperties":false,"required":["binary_grid"],"properties":{"binary_grid":{"$ref":"#/$defs/CatalogResponse/$defs/T165"}}}]};
const schema230 = {"type":"integer","minimum":-32768,"maximum":32767};

function validate2926(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2926.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(!(((typeof data == "number") && (!(data % 1) && !isNaN(data))) && (isFinite(data)))){
validate2926.errors = [{}];
return false;
}
if(errors === 0){
if((typeof data == "number") && (isFinite(data))){
if(data > 32767 || isNaN(data)){
validate2926.errors = [{}];
return false;
}
else {
if(data < -32768 || isNaN(data)){
validate2926.errors = [{}];
return false;
}
}
}
}
validate2926.errors = vErrors;
return errors === 0;
}
validate2926.evaluated = {"dynamicProps":false,"dynamicItems":false};


function validate2924(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2924.evaluated;
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
if((data.exact === undefined) && (missing0 = "exact")){
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
const _errs3 = errors;
for(const key0 in data){
if(!(key0 === "exact")){
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
if(_errs3 === errors){
if(data.exact !== undefined){
if(!(validate2664(data.exact, {instancePath:instancePath+"/exact",parentData:data,parentDataProperty:"exact",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2664.errors : vErrors.concat(validate2664.errors);
errors = vErrors.length;
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
var _valid0 = _errs1 === errors;
if(_valid0){
valid0 = true;
passing0 = 0;
var props0 = true;
}
const _errs5 = errors;
if(errors === _errs5){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing1;
if((data.binary_grid === undefined) && (missing1 = "binary_grid")){
const err3 = {};
if(vErrors === null){
vErrors = [err3];
}
else {
vErrors.push(err3);
}
errors++;
}
else {
const _errs7 = errors;
for(const key1 in data){
if(!(key1 === "binary_grid")){
const err4 = {};
if(vErrors === null){
vErrors = [err4];
}
else {
vErrors.push(err4);
}
errors++;
break;
}
}
if(_errs7 === errors){
if(data.binary_grid !== undefined){
if(!(validate2926(data.binary_grid, {instancePath:instancePath+"/binary_grid",parentData:data,parentDataProperty:"binary_grid",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2926.errors : vErrors.concat(validate2926.errors);
errors = vErrors.length;
}
}
}
}
}
else {
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
var _valid0 = _errs5 === errors;
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
}
if(!valid0){
const err6 = {};
if(vErrors === null){
vErrors = [err6];
}
else {
vErrors.push(err6);
}
errors++;
validate2924.errors = vErrors;
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
validate2924.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate2924.evaluated = {"dynamicProps":true,"dynamicItems":false};


function validate2910(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2910.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if(((((((((data.definition === undefined) && (missing0 = "definition")) || ((data.srid === undefined) && (missing0 = "srid"))) || ((data.local_frame === undefined) && (missing0 = "local_frame"))) || ((data.axes === undefined) && (missing0 = "axes"))) || ((data.manifold === undefined) && (missing0 = "manifold"))) || ((data.linear_unit_nm === undefined) && (missing0 = "linear_unit_nm"))) || ((data.vertical_datum === undefined) && (missing0 = "vertical_datum"))) || ((data.precision === undefined) && (missing0 = "precision"))){
validate2910.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((((((((key0 === "definition") || (key0 === "srid")) || (key0 === "local_frame")) || (key0 === "axes")) || (key0 === "manifold")) || (key0 === "linear_unit_nm")) || (key0 === "vertical_datum")) || (key0 === "precision"))){
validate2910.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.definition !== undefined){
const _errs2 = errors;
if(!(validate2911(data.definition, {instancePath:instancePath+"/definition",parentData:data,parentDataProperty:"definition",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2911.errors : vErrors.concat(validate2911.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.srid !== undefined){
const _errs3 = errors;
if(!(validate2751(data.srid, {instancePath:instancePath+"/srid",parentData:data,parentDataProperty:"srid",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2751.errors : vErrors.concat(validate2751.errors);
errors = vErrors.length;
}
var valid0 = _errs3 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.local_frame !== undefined){
const _errs4 = errors;
if(!(validate2914(data.local_frame, {instancePath:instancePath+"/local_frame",parentData:data,parentDataProperty:"local_frame",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2914.errors : vErrors.concat(validate2914.errors);
errors = vErrors.length;
}
var valid0 = _errs4 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.axes !== undefined){
const _errs5 = errors;
if(!(validate2917(data.axes, {instancePath:instancePath+"/axes",parentData:data,parentDataProperty:"axes",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2917.errors : vErrors.concat(validate2917.errors);
errors = vErrors.length;
}
var valid0 = _errs5 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.manifold !== undefined){
const _errs6 = errors;
if(!(validate2919(data.manifold, {instancePath:instancePath+"/manifold",parentData:data,parentDataProperty:"manifold",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2919.errors : vErrors.concat(validate2919.errors);
errors = vErrors.length;
}
var valid0 = _errs6 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.linear_unit_nm !== undefined){
const _errs7 = errors;
if(!(validate2513(data.linear_unit_nm, {instancePath:instancePath+"/linear_unit_nm",parentData:data,parentDataProperty:"linear_unit_nm",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2513.errors : vErrors.concat(validate2513.errors);
errors = vErrors.length;
}
var valid0 = _errs7 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.vertical_datum !== undefined){
const _errs8 = errors;
if(!(validate2922(data.vertical_datum, {instancePath:instancePath+"/vertical_datum",parentData:data,parentDataProperty:"vertical_datum",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2922.errors : vErrors.concat(validate2922.errors);
errors = vErrors.length;
}
var valid0 = _errs8 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.precision !== undefined){
const _errs9 = errors;
if(!(validate2924(data.precision, {instancePath:instancePath+"/precision",parentData:data,parentDataProperty:"precision",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2924.errors : vErrors.concat(validate2924.errors);
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
validate2910.errors = [{}];
return false;
}
}
validate2910.errors = vErrors;
return errors === 0;
}
validate2910.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate2909(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2909.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate2910(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2910.errors : vErrors.concat(validate2910.errors);
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
validate2909.errors = vErrors;
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
validate2909.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate2909.evaluated = {"dynamicProps":true,"dynamicItems":false};


function validate2888(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2888.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if(((((data.rounding === undefined) && (missing0 = "rounding")) || ((data.metric === undefined) && (missing0 = "metric"))) || ((data.timezone === undefined) && (missing0 = "timezone"))) || ((data.spatial === undefined) && (missing0 = "spatial"))){
validate2888.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((((key0 === "rounding") || (key0 === "metric")) || (key0 === "timezone")) || (key0 === "spatial"))){
validate2888.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.rounding !== undefined){
const _errs2 = errors;
if(!(validate2889(data.rounding, {instancePath:instancePath+"/rounding",parentData:data,parentDataProperty:"rounding",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2889.errors : vErrors.concat(validate2889.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.metric !== undefined){
const _errs3 = errors;
if(!(validate2893(data.metric, {instancePath:instancePath+"/metric",parentData:data,parentDataProperty:"metric",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2893.errors : vErrors.concat(validate2893.errors);
errors = vErrors.length;
}
var valid0 = _errs3 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.timezone !== undefined){
const _errs4 = errors;
if(!(validate2897(data.timezone, {instancePath:instancePath+"/timezone",parentData:data,parentDataProperty:"timezone",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2897.errors : vErrors.concat(validate2897.errors);
errors = vErrors.length;
}
var valid0 = _errs4 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.spatial !== undefined){
const _errs5 = errors;
if(!(validate2909(data.spatial, {instancePath:instancePath+"/spatial",parentData:data,parentDataProperty:"spatial",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2909.errors : vErrors.concat(validate2909.errors);
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
validate2888.errors = [{}];
return false;
}
}
validate2888.errors = vErrors;
return errors === 0;
}
validate2888.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate2660(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2660.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((((((((((data.id === undefined) && (missing0 = "id")) || ((data.name === undefined) && (missing0 = "name"))) || ((data.type === undefined) && (missing0 = "type"))) || ((data.nullable === undefined) && (missing0 = "nullable"))) || ((data.default === undefined) && (missing0 = "default"))) || ((data.max_characters === undefined) && (missing0 = "max_characters"))) || ((data.encoding === undefined) && (missing0 = "encoding"))) || ((data.collation === undefined) && (missing0 = "collation"))) || ((data.semantics === undefined) && (missing0 = "semantics"))){
validate2660.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(func1.call(schema725.properties, key0))){
validate2660.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.id !== undefined){
const _errs2 = errors;
if(!(validate2513(data.id, {instancePath:instancePath+"/id",parentData:data,parentDataProperty:"id",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2513.errors : vErrors.concat(validate2513.errors);
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
if(!(validate2513(data.name, {instancePath:instancePath+"/name",parentData:data,parentDataProperty:"name",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2513.errors : vErrors.concat(validate2513.errors);
errors = vErrors.length;
}
var valid0 = _errs3 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.type !== undefined){
const _errs4 = errors;
if(!(validate2663(data.type, {instancePath:instancePath+"/type",parentData:data,parentDataProperty:"type",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2663.errors : vErrors.concat(validate2663.errors);
errors = vErrors.length;
}
var valid0 = _errs4 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.nullable !== undefined){
const _errs5 = errors;
if(!(validate2746(data.nullable, {instancePath:instancePath+"/nullable",parentData:data,parentDataProperty:"nullable",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2746.errors : vErrors.concat(validate2746.errors);
errors = vErrors.length;
}
var valid0 = _errs5 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.default !== undefined){
const _errs6 = errors;
if(!(validate2767(data.default, {instancePath:instancePath+"/default",parentData:data,parentDataProperty:"default",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2767.errors : vErrors.concat(validate2767.errors);
errors = vErrors.length;
}
var valid0 = _errs6 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.max_characters !== undefined){
const _errs7 = errors;
if(!(validate2881(data.max_characters, {instancePath:instancePath+"/max_characters",parentData:data,parentDataProperty:"max_characters",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2881.errors : vErrors.concat(validate2881.errors);
errors = vErrors.length;
}
var valid0 = _errs7 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.encoding !== undefined){
const _errs8 = errors;
if(!(validate2884(data.encoding, {instancePath:instancePath+"/encoding",parentData:data,parentDataProperty:"encoding",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2884.errors : vErrors.concat(validate2884.errors);
errors = vErrors.length;
}
var valid0 = _errs8 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.collation !== undefined){
const _errs9 = errors;
if(!(validate2886(data.collation, {instancePath:instancePath+"/collation",parentData:data,parentDataProperty:"collation",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2886.errors : vErrors.concat(validate2886.errors);
errors = vErrors.length;
}
var valid0 = _errs9 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.semantics !== undefined){
const _errs10 = errors;
if(!(validate2888(data.semantics, {instancePath:instancePath+"/semantics",parentData:data,parentDataProperty:"semantics",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2888.errors : vErrors.concat(validate2888.errors);
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
validate2660.errors = [{}];
return false;
}
}
validate2660.errors = vErrors;
return errors === 0;
}
validate2660.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate2659(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2659.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(Array.isArray(data)){
if(data.length > 128){
validate2659.errors = [{}];
return false;
}
else {
var valid0 = true;
const len0 = data.length;
for(let i0=0; i0<len0; i0++){
const _errs1 = errors;
if(!(validate2660(data[i0], {instancePath:instancePath+"/" + i0,parentData:data,parentDataProperty:i0,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2660.errors : vErrors.concat(validate2660.errors);
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
validate2659.errors = [{}];
return false;
}
}
validate2659.errors = vErrors;
return errors === 0;
}
validate2659.evaluated = {"items":true,"dynamicProps":false,"dynamicItems":false};

const schema800 = {"type":"array","maxItems":128,"items":{"$ref":"#/$defs/CatalogResponse/$defs/T46"}};

function validate2934(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2934.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(Array.isArray(data)){
if(data.length > 128){
validate2934.errors = [{}];
return false;
}
else {
var valid0 = true;
const len0 = data.length;
for(let i0=0; i0<len0; i0++){
const _errs1 = errors;
if(!(validate2513(data[i0], {instancePath:instancePath+"/" + i0,parentData:data,parentDataProperty:i0,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2513.errors : vErrors.concat(validate2513.errors);
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
validate2934.errors = [{}];
return false;
}
}
validate2934.errors = vErrors;
return errors === 0;
}
validate2934.evaluated = {"items":true,"dynamicProps":false,"dynamicItems":false};

const schema801 = {"type":"object","additionalProperties":false,"properties":{"next_id":{"$ref":"#/$defs/CatalogResponse/$defs/T6"},"checks":{"$ref":"#/$defs/CatalogResponse/$defs/T168"},"foreign_keys":{"$ref":"#/$defs/CatalogResponse/$defs/T192"}},"required":["next_id","checks","foreign_keys"]};
const schema802 = {"type":"array","maxItems":64,"items":{"$ref":"#/$defs/CatalogResponse/$defs/T169"}};
const schema803 = {"type":"object","additionalProperties":false,"properties":{"id":{"$ref":"#/$defs/CatalogResponse/$defs/T170"},"name":{"$ref":"#/$defs/CatalogResponse/$defs/T171"},"atoms":{"$ref":"#/$defs/CatalogResponse/$defs/T172"},"validated":{"$ref":"#/$defs/CatalogResponse/$defs/T191"}},"required":["id","name","atoms","validated"]};

function validate2941(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2941.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(!(((typeof data == "number") && (!(data % 1) && !isNaN(data))) && (isFinite(data)))){
validate2941.errors = [{}];
return false;
}
if(errors === 0){
if((typeof data == "number") && (isFinite(data))){
if(data > 4294967295 || isNaN(data)){
validate2941.errors = [{}];
return false;
}
else {
if(data < 0 || isNaN(data)){
validate2941.errors = [{}];
return false;
}
}
}
}
validate2941.errors = vErrors;
return errors === 0;
}
validate2941.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema805 = {"type":"string","maxLength":262144};

function validate2943(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2943.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(typeof data === "string"){
if(func3(data) > 262144){
validate2943.errors = [{}];
return false;
}
}
else {
validate2943.errors = [{}];
return false;
}
}
validate2943.errors = vErrors;
return errors === 0;
}
validate2943.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema806 = {"type":"array","maxItems":32,"items":{"$ref":"#/$defs/CatalogResponse/$defs/T173"}};
const schema807 = {"oneOf":[{"type":"object","additionalProperties":false,"required":["compare_literal"],"properties":{"compare_literal":{"$ref":"#/$defs/CatalogResponse/$defs/T174"}}},{"type":"object","additionalProperties":false,"required":["compare_columns"],"properties":{"compare_columns":{"$ref":"#/$defs/CatalogResponse/$defs/T190"}}},{"type":"object","additionalProperties":false,"required":["is_not_null"],"properties":{"is_not_null":{"$ref":"#/$defs/CatalogResponse/$defs/T175"}}},{"type":"object","additionalProperties":false,"required":["is_null"],"properties":{"is_null":{"$ref":"#/$defs/CatalogResponse/$defs/T175"}}}]};
const schema808 = {"type":"object","additionalProperties":false,"properties":{"column":{"$ref":"#/$defs/CatalogResponse/$defs/T175"},"op":{"$ref":"#/$defs/CatalogResponse/$defs/T176"},"literal":{"$ref":"#/$defs/CatalogResponse/$defs/T177"}},"required":["column","op","literal"]};
const schema809 = {"type":"string","maxLength":262144};

function validate2948(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2948.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(typeof data === "string"){
if(func3(data) > 262144){
validate2948.errors = [{}];
return false;
}
}
else {
validate2948.errors = [{}];
return false;
}
}
validate2948.errors = vErrors;
return errors === 0;
}
validate2948.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema810 = {"type":"string","enum":["lt","lte","eq","gte","gt","neq"]};

function validate2950(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2950.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate2950.errors = [{}];
return false;
}
if(!((((((data === "lt") || (data === "lte")) || (data === "eq")) || (data === "gte")) || (data === "gt")) || (data === "neq"))){
validate2950.errors = [{}];
return false;
}
validate2950.errors = vErrors;
return errors === 0;
}
validate2950.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema811 = {"oneOf":[{"type":"object","additionalProperties":false,"required":["missing"],"properties":{"missing":{"$ref":"#/$defs/CatalogResponse/$defs/T178"}}},{"type":"object","additionalProperties":false,"required":["null"],"properties":{"null":{"$ref":"#/$defs/CatalogResponse/$defs/T178"}}},{"type":"object","additionalProperties":false,"required":["type_error"],"properties":{"type_error":{"$ref":"#/$defs/CatalogResponse/$defs/T179"}}},{"type":"object","additionalProperties":false,"required":["value"],"properties":{"value":{"$ref":"#/$defs/CatalogResponse/$defs/T180"}}},{"type":"object","additionalProperties":false,"required":["conflict"],"properties":{"conflict":{"$ref":"#/$defs/CatalogResponse/$defs/T137"}}}]};
const schema812 = {"type":"object","maxProperties":0};

function validate2953(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2953.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
if(Object.keys(data).length > 0){
validate2953.errors = [{}];
return false;
}
}
else {
validate2953.errors = [{}];
return false;
}
}
validate2953.errors = vErrors;
return errors === 0;
}
validate2953.evaluated = {"dynamicProps":false,"dynamicItems":false};


function validate2956(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2956.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate2956.errors = [{}];
return false;
}
if(!(((((((((((((((((((((((((((((((((((data === "unknown") || (data === "int64")) || (data === "uint64")) || (data === "float64")) || (data === "boolean")) || (data === "utf8")) || (data === "binary")) || (data === "int8")) || (data === "int16")) || (data === "int32")) || (data === "int128")) || (data === "uint8")) || (data === "uint16")) || (data === "uint32")) || (data === "uint128")) || (data === "float32")) || (data === "decimal")) || (data === "date")) || (data === "time")) || (data === "timestamp")) || (data === "interval")) || (data === "uuid")) || (data === "structure")) || (data === "list")) || (data === "array")) || (data === "map")) || (data === "tagged_union")) || (data === "json")) || (data === "range")) || (data === "multirange")) || (data === "vector")) || (data === "capability")) || (data === "null_value")) || (data === "text")) || (data === "character"))){
validate2956.errors = [{}];
return false;
}
validate2956.errors = vErrors;
return errors === 0;
}
validate2956.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema814 = {"oneOf":[{"type":"object","additionalProperties":false,"required":["atom"],"properties":{"atom":{"$ref":"#/$defs/CatalogResponse/$defs/T181"}}},{"type":"object","additionalProperties":false,"required":["structure"],"properties":{"structure":{"$ref":"#/$defs/CatalogResponse/$defs/T119"}}},{"type":"object","additionalProperties":false,"required":["list"],"properties":{"list":{"$ref":"#/$defs/CatalogResponse/$defs/T119"}}},{"type":"object","additionalProperties":false,"required":["array"],"properties":{"array":{"$ref":"#/$defs/CatalogResponse/$defs/T119"}}},{"type":"object","additionalProperties":false,"required":["map"],"properties":{"map":{"$ref":"#/$defs/CatalogResponse/$defs/T128"}}},{"type":"object","additionalProperties":false,"required":["tagged_union"],"properties":{"tagged_union":{"$ref":"#/$defs/CatalogResponse/$defs/T184"}}},{"type":"object","additionalProperties":false,"required":["json"],"properties":{"json":{"$ref":"#/$defs/CatalogResponse/$defs/T175"}}},{"type":"object","additionalProperties":false,"required":["range"],"properties":{"range":{"$ref":"#/$defs/CatalogResponse/$defs/T187"}}},{"type":"object","additionalProperties":false,"required":["multirange"],"properties":{"multirange":{"$ref":"#/$defs/CatalogResponse/$defs/T136"}}},{"type":"object","additionalProperties":false,"required":["vector"],"properties":{"vector":{"$ref":"#/$defs/CatalogResponse/$defs/T175"}}}]};
const schema815 = {"oneOf":[{"type":"object","additionalProperties":false,"required":["signed"],"properties":{"signed":{"$ref":"#/$defs/CatalogResponse/$defs/T175"}}},{"type":"object","additionalProperties":false,"required":["unsigned"],"properties":{"unsigned":{"$ref":"#/$defs/CatalogResponse/$defs/T175"}}},{"type":"object","additionalProperties":false,"required":["decimal"],"properties":{"decimal":{"$ref":"#/$defs/CatalogResponse/$defs/T175"}}},{"type":"object","additionalProperties":false,"required":["float_bits"],"properties":{"float_bits":{"$ref":"#/$defs/CatalogResponse/$defs/T175"}}},{"type":"object","additionalProperties":false,"required":["boolean"],"properties":{"boolean":{"$ref":"#/$defs/CatalogResponse/$defs/T182"}}},{"type":"object","additionalProperties":false,"required":["utf8"],"properties":{"utf8":{"$ref":"#/$defs/CatalogResponse/$defs/T175"}}},{"type":"object","additionalProperties":false,"required":["binary"],"properties":{"binary":{"$ref":"#/$defs/CatalogResponse/$defs/T175"}}},{"type":"object","additionalProperties":false,"required":["date_days"],"properties":{"date_days":{"$ref":"#/$defs/CatalogResponse/$defs/T175"}}},{"type":"object","additionalProperties":false,"required":["time_nanos"],"properties":{"time_nanos":{"$ref":"#/$defs/CatalogResponse/$defs/T175"}}},{"type":"object","additionalProperties":false,"required":["timestamp_micros"],"properties":{"timestamp_micros":{"$ref":"#/$defs/CatalogResponse/$defs/T175"}}},{"type":"object","additionalProperties":false,"required":["interval"],"properties":{"interval":{"$ref":"#/$defs/CatalogResponse/$defs/T183"}}},{"type":"object","additionalProperties":false,"required":["uuid"],"properties":{"uuid":{"$ref":"#/$defs/CatalogResponse/$defs/T175"}}}]};
const schema816 = {"type":"boolean"};

function validate2964(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2964.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "boolean"){
validate2964.errors = [{}];
return false;
}
validate2964.errors = vErrors;
return errors === 0;
}
validate2964.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema817 = {"type":"object","additionalProperties":false,"properties":{"months":{"$ref":"#/$defs/CatalogResponse/$defs/T175"},"days":{"$ref":"#/$defs/CatalogResponse/$defs/T175"},"nanos":{"$ref":"#/$defs/CatalogResponse/$defs/T175"}},"required":["months","days","nanos"]};

function validate2971(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2971.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((((data.months === undefined) && (missing0 = "months")) || ((data.days === undefined) && (missing0 = "days"))) || ((data.nanos === undefined) && (missing0 = "nanos"))){
validate2971.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "months") || (key0 === "days")) || (key0 === "nanos"))){
validate2971.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.months !== undefined){
const _errs2 = errors;
if(!(validate2948(data.months, {instancePath:instancePath+"/months",parentData:data,parentDataProperty:"months",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2948.errors : vErrors.concat(validate2948.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.days !== undefined){
const _errs3 = errors;
if(!(validate2948(data.days, {instancePath:instancePath+"/days",parentData:data,parentDataProperty:"days",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2948.errors : vErrors.concat(validate2948.errors);
errors = vErrors.length;
}
var valid0 = _errs3 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.nanos !== undefined){
const _errs4 = errors;
if(!(validate2948(data.nanos, {instancePath:instancePath+"/nanos",parentData:data,parentDataProperty:"nanos",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2948.errors : vErrors.concat(validate2948.errors);
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
validate2971.errors = [{}];
return false;
}
}
validate2971.errors = vErrors;
return errors === 0;
}
validate2971.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate2959(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2959.evaluated;
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
if((data.signed === undefined) && (missing0 = "signed")){
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
const _errs3 = errors;
for(const key0 in data){
if(!(key0 === "signed")){
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
if(_errs3 === errors){
if(data.signed !== undefined){
if(!(validate2948(data.signed, {instancePath:instancePath+"/signed",parentData:data,parentDataProperty:"signed",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2948.errors : vErrors.concat(validate2948.errors);
errors = vErrors.length;
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
var _valid0 = _errs1 === errors;
if(_valid0){
valid0 = true;
passing0 = 0;
var props0 = true;
}
const _errs5 = errors;
if(errors === _errs5){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing1;
if((data.unsigned === undefined) && (missing1 = "unsigned")){
const err3 = {};
if(vErrors === null){
vErrors = [err3];
}
else {
vErrors.push(err3);
}
errors++;
}
else {
const _errs7 = errors;
for(const key1 in data){
if(!(key1 === "unsigned")){
const err4 = {};
if(vErrors === null){
vErrors = [err4];
}
else {
vErrors.push(err4);
}
errors++;
break;
}
}
if(_errs7 === errors){
if(data.unsigned !== undefined){
if(!(validate2948(data.unsigned, {instancePath:instancePath+"/unsigned",parentData:data,parentDataProperty:"unsigned",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2948.errors : vErrors.concat(validate2948.errors);
errors = vErrors.length;
}
}
}
}
}
else {
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
var _valid0 = _errs5 === errors;
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
const _errs9 = errors;
if(errors === _errs9){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing2;
if((data.decimal === undefined) && (missing2 = "decimal")){
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
const _errs11 = errors;
for(const key2 in data){
if(!(key2 === "decimal")){
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
if(_errs11 === errors){
if(data.decimal !== undefined){
if(!(validate2948(data.decimal, {instancePath:instancePath+"/decimal",parentData:data,parentDataProperty:"decimal",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2948.errors : vErrors.concat(validate2948.errors);
errors = vErrors.length;
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
var _valid0 = _errs9 === errors;
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
const _errs13 = errors;
if(errors === _errs13){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing3;
if((data.float_bits === undefined) && (missing3 = "float_bits")){
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
const _errs15 = errors;
for(const key3 in data){
if(!(key3 === "float_bits")){
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
if(_errs15 === errors){
if(data.float_bits !== undefined){
if(!(validate2948(data.float_bits, {instancePath:instancePath+"/float_bits",parentData:data,parentDataProperty:"float_bits",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2948.errors : vErrors.concat(validate2948.errors);
errors = vErrors.length;
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
var _valid0 = _errs13 === errors;
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
const _errs17 = errors;
if(errors === _errs17){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing4;
if((data.boolean === undefined) && (missing4 = "boolean")){
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
const _errs19 = errors;
for(const key4 in data){
if(!(key4 === "boolean")){
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
if(_errs19 === errors){
if(data.boolean !== undefined){
if(!(validate2964(data.boolean, {instancePath:instancePath+"/boolean",parentData:data,parentDataProperty:"boolean",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2964.errors : vErrors.concat(validate2964.errors);
errors = vErrors.length;
}
}
}
}
}
else {
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
var _valid0 = _errs17 === errors;
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
const _errs21 = errors;
if(errors === _errs21){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing5;
if((data.utf8 === undefined) && (missing5 = "utf8")){
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
const _errs23 = errors;
for(const key5 in data){
if(!(key5 === "utf8")){
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
if(_errs23 === errors){
if(data.utf8 !== undefined){
if(!(validate2948(data.utf8, {instancePath:instancePath+"/utf8",parentData:data,parentDataProperty:"utf8",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2948.errors : vErrors.concat(validate2948.errors);
errors = vErrors.length;
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
var _valid0 = _errs21 === errors;
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
const _errs25 = errors;
if(errors === _errs25){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing6;
if((data.binary === undefined) && (missing6 = "binary")){
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
const _errs27 = errors;
for(const key6 in data){
if(!(key6 === "binary")){
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
if(_errs27 === errors){
if(data.binary !== undefined){
if(!(validate2948(data.binary, {instancePath:instancePath+"/binary",parentData:data,parentDataProperty:"binary",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2948.errors : vErrors.concat(validate2948.errors);
errors = vErrors.length;
}
}
}
}
}
else {
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
var _valid0 = _errs25 === errors;
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
const _errs29 = errors;
if(errors === _errs29){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing7;
if((data.date_days === undefined) && (missing7 = "date_days")){
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
const _errs31 = errors;
for(const key7 in data){
if(!(key7 === "date_days")){
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
if(_errs31 === errors){
if(data.date_days !== undefined){
if(!(validate2948(data.date_days, {instancePath:instancePath+"/date_days",parentData:data,parentDataProperty:"date_days",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2948.errors : vErrors.concat(validate2948.errors);
errors = vErrors.length;
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
var _valid0 = _errs29 === errors;
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
const _errs33 = errors;
if(errors === _errs33){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing8;
if((data.time_nanos === undefined) && (missing8 = "time_nanos")){
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
const _errs35 = errors;
for(const key8 in data){
if(!(key8 === "time_nanos")){
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
if(_errs35 === errors){
if(data.time_nanos !== undefined){
if(!(validate2948(data.time_nanos, {instancePath:instancePath+"/time_nanos",parentData:data,parentDataProperty:"time_nanos",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2948.errors : vErrors.concat(validate2948.errors);
errors = vErrors.length;
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
var _valid0 = _errs33 === errors;
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
const _errs37 = errors;
if(errors === _errs37){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing9;
if((data.timestamp_micros === undefined) && (missing9 = "timestamp_micros")){
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
const _errs39 = errors;
for(const key9 in data){
if(!(key9 === "timestamp_micros")){
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
if(_errs39 === errors){
if(data.timestamp_micros !== undefined){
if(!(validate2948(data.timestamp_micros, {instancePath:instancePath+"/timestamp_micros",parentData:data,parentDataProperty:"timestamp_micros",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2948.errors : vErrors.concat(validate2948.errors);
errors = vErrors.length;
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
var _valid0 = _errs37 === errors;
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
const _errs41 = errors;
if(errors === _errs41){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing10;
if((data.interval === undefined) && (missing10 = "interval")){
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
const _errs43 = errors;
for(const key10 in data){
if(!(key10 === "interval")){
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
if(_errs43 === errors){
if(data.interval !== undefined){
if(!(validate2971(data.interval, {instancePath:instancePath+"/interval",parentData:data,parentDataProperty:"interval",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2971.errors : vErrors.concat(validate2971.errors);
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
var _valid0 = _errs41 === errors;
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
const _errs45 = errors;
if(errors === _errs45){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing11;
if((data.uuid === undefined) && (missing11 = "uuid")){
const err33 = {};
if(vErrors === null){
vErrors = [err33];
}
else {
vErrors.push(err33);
}
errors++;
}
else {
const _errs47 = errors;
for(const key11 in data){
if(!(key11 === "uuid")){
const err34 = {};
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
if(_errs47 === errors){
if(data.uuid !== undefined){
if(!(validate2948(data.uuid, {instancePath:instancePath+"/uuid",parentData:data,parentDataProperty:"uuid",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2948.errors : vErrors.concat(validate2948.errors);
errors = vErrors.length;
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
var _valid0 = _errs45 === errors;
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
const err36 = {};
if(vErrors === null){
vErrors = [err36];
}
else {
vErrors.push(err36);
}
errors++;
validate2959.errors = vErrors;
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
validate2959.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate2959.evaluated = {"dynamicProps":true,"dynamicItems":false};

const schema818 = {"type":"object","additionalProperties":false,"properties":{"index":{"$ref":"#/$defs/CatalogResponse/$defs/T185"},"value":{"$ref":"#/$defs/CatalogResponse/$defs/T186"}},"required":["index","value"]};

function validate2983(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2983.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(!(((typeof data == "number") && (!(data % 1) && !isNaN(data))) && (isFinite(data)))){
validate2983.errors = [{}];
return false;
}
if(errors === 0){
if((typeof data == "number") && (isFinite(data))){
if(data > 255 || isNaN(data)){
validate2983.errors = [{}];
return false;
}
else {
if(data < 0 || isNaN(data)){
validate2983.errors = [{}];
return false;
}
}
}
}
validate2983.errors = vErrors;
return errors === 0;
}
validate2983.evaluated = {"dynamicProps":false,"dynamicItems":false};

const wrapper52 = {validate: validate2952};

function validate2982(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2982.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if(((data.index === undefined) && (missing0 = "index")) || ((data.value === undefined) && (missing0 = "value"))){
validate2982.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "index") || (key0 === "value"))){
validate2982.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.index !== undefined){
const _errs2 = errors;
if(!(validate2983(data.index, {instancePath:instancePath+"/index",parentData:data,parentDataProperty:"index",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2983.errors : vErrors.concat(validate2983.errors);
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
if(!(wrapper52.validate(data.value, {instancePath:instancePath+"/value",parentData:data,parentDataProperty:"value",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? wrapper52.validate.errors : vErrors.concat(wrapper52.validate.errors);
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
validate2982.errors = [{}];
return false;
}
}
validate2982.errors = vErrors;
return errors === 0;
}
validate2982.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema820 = {"type":"object","additionalProperties":false,"properties":{"is_empty":{"$ref":"#/$defs/CatalogResponse/$defs/T182"},"lower":{"$ref":"#/$defs/CatalogResponse/$defs/T188"},"upper":{"$ref":"#/$defs/CatalogResponse/$defs/T188"}},"required":["is_empty","lower","upper"]};
const schema821 = {"anyOf":[{"$ref":"#/$defs/CatalogResponse/$defs/T189"},{"type":"null"}]};
const schema822 = {"type":"object","additionalProperties":false,"properties":{"value":{"$ref":"#/$defs/CatalogResponse/$defs/T181"},"inclusive":{"$ref":"#/$defs/CatalogResponse/$defs/T182"}},"required":["value","inclusive"]};

function validate2990(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2990.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if(((data.value === undefined) && (missing0 = "value")) || ((data.inclusive === undefined) && (missing0 = "inclusive"))){
validate2990.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "value") || (key0 === "inclusive"))){
validate2990.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.value !== undefined){
const _errs2 = errors;
if(!(validate2959(data.value, {instancePath:instancePath+"/value",parentData:data,parentDataProperty:"value",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2959.errors : vErrors.concat(validate2959.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.inclusive !== undefined){
const _errs3 = errors;
if(!(validate2964(data.inclusive, {instancePath:instancePath+"/inclusive",parentData:data,parentDataProperty:"inclusive",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2964.errors : vErrors.concat(validate2964.errors);
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
validate2990.errors = [{}];
return false;
}
}
validate2990.errors = vErrors;
return errors === 0;
}
validate2990.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate2989(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2989.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate2990(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2990.errors : vErrors.concat(validate2990.errors);
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
validate2989.errors = vErrors;
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
validate2989.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate2989.evaluated = {"dynamicProps":true,"dynamicItems":false};


function validate2987(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2987.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((((data.is_empty === undefined) && (missing0 = "is_empty")) || ((data.lower === undefined) && (missing0 = "lower"))) || ((data.upper === undefined) && (missing0 = "upper"))){
validate2987.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "is_empty") || (key0 === "lower")) || (key0 === "upper"))){
validate2987.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.is_empty !== undefined){
const _errs2 = errors;
if(!(validate2964(data.is_empty, {instancePath:instancePath+"/is_empty",parentData:data,parentDataProperty:"is_empty",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2964.errors : vErrors.concat(validate2964.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.lower !== undefined){
const _errs3 = errors;
if(!(validate2989(data.lower, {instancePath:instancePath+"/lower",parentData:data,parentDataProperty:"lower",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2989.errors : vErrors.concat(validate2989.errors);
errors = vErrors.length;
}
var valid0 = _errs3 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.upper !== undefined){
const _errs4 = errors;
if(!(validate2989(data.upper, {instancePath:instancePath+"/upper",parentData:data,parentDataProperty:"upper",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2989.errors : vErrors.concat(validate2989.errors);
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
validate2987.errors = [{}];
return false;
}
}
validate2987.errors = vErrors;
return errors === 0;
}
validate2987.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate2958(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2958.evaluated;
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
if((data.atom === undefined) && (missing0 = "atom")){
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
const _errs3 = errors;
for(const key0 in data){
if(!(key0 === "atom")){
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
if(_errs3 === errors){
if(data.atom !== undefined){
if(!(validate2959(data.atom, {instancePath:instancePath+"/atom",parentData:data,parentDataProperty:"atom",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2959.errors : vErrors.concat(validate2959.errors);
errors = vErrors.length;
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
var _valid0 = _errs1 === errors;
if(_valid0){
valid0 = true;
passing0 = 0;
var props1 = true;
}
const _errs5 = errors;
if(errors === _errs5){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing1;
if((data.structure === undefined) && (missing1 = "structure")){
const err3 = {};
if(vErrors === null){
vErrors = [err3];
}
else {
vErrors.push(err3);
}
errors++;
}
else {
const _errs7 = errors;
for(const key1 in data){
if(!(key1 === "structure")){
const err4 = {};
if(vErrors === null){
vErrors = [err4];
}
else {
vErrors.push(err4);
}
errors++;
break;
}
}
if(_errs7 === errors){
if(data.structure !== undefined){
if(!(validate2792(data.structure, {instancePath:instancePath+"/structure",parentData:data,parentDataProperty:"structure",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2792.errors : vErrors.concat(validate2792.errors);
errors = vErrors.length;
}
}
}
}
}
else {
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
var _valid0 = _errs5 === errors;
if(_valid0 && valid0){
valid0 = false;
passing0 = [passing0, 1];
}
else {
if(_valid0){
valid0 = true;
passing0 = 1;
if(props1 !== true){
props1 = true;
}
}
const _errs9 = errors;
if(errors === _errs9){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing2;
if((data.list === undefined) && (missing2 = "list")){
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
const _errs11 = errors;
for(const key2 in data){
if(!(key2 === "list")){
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
if(_errs11 === errors){
if(data.list !== undefined){
if(!(validate2792(data.list, {instancePath:instancePath+"/list",parentData:data,parentDataProperty:"list",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2792.errors : vErrors.concat(validate2792.errors);
errors = vErrors.length;
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
var _valid0 = _errs9 === errors;
if(_valid0 && valid0){
valid0 = false;
passing0 = [passing0, 2];
}
else {
if(_valid0){
valid0 = true;
passing0 = 2;
if(props1 !== true){
props1 = true;
}
}
const _errs13 = errors;
if(errors === _errs13){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing3;
if((data.array === undefined) && (missing3 = "array")){
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
const _errs15 = errors;
for(const key3 in data){
if(!(key3 === "array")){
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
if(_errs15 === errors){
if(data.array !== undefined){
if(!(validate2792(data.array, {instancePath:instancePath+"/array",parentData:data,parentDataProperty:"array",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2792.errors : vErrors.concat(validate2792.errors);
errors = vErrors.length;
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
var _valid0 = _errs13 === errors;
if(_valid0 && valid0){
valid0 = false;
passing0 = [passing0, 3];
}
else {
if(_valid0){
valid0 = true;
passing0 = 3;
if(props1 !== true){
props1 = true;
}
}
const _errs17 = errors;
if(errors === _errs17){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing4;
if((data.map === undefined) && (missing4 = "map")){
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
const _errs19 = errors;
for(const key4 in data){
if(!(key4 === "map")){
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
if(_errs19 === errors){
if(data.map !== undefined){
if(!(validate2820(data.map, {instancePath:instancePath+"/map",parentData:data,parentDataProperty:"map",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2820.errors : vErrors.concat(validate2820.errors);
errors = vErrors.length;
}
}
}
}
}
else {
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
var _valid0 = _errs17 === errors;
if(_valid0 && valid0){
valid0 = false;
passing0 = [passing0, 4];
}
else {
if(_valid0){
valid0 = true;
passing0 = 4;
if(props1 !== true){
props1 = true;
}
}
const _errs21 = errors;
if(errors === _errs21){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing5;
if((data.tagged_union === undefined) && (missing5 = "tagged_union")){
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
const _errs23 = errors;
for(const key5 in data){
if(!(key5 === "tagged_union")){
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
if(_errs23 === errors){
if(data.tagged_union !== undefined){
if(!(validate2982(data.tagged_union, {instancePath:instancePath+"/tagged_union",parentData:data,parentDataProperty:"tagged_union",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2982.errors : vErrors.concat(validate2982.errors);
errors = vErrors.length;
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
var _valid0 = _errs21 === errors;
if(_valid0 && valid0){
valid0 = false;
passing0 = [passing0, 5];
}
else {
if(_valid0){
valid0 = true;
passing0 = 5;
if(props1 !== true){
props1 = true;
}
}
const _errs25 = errors;
if(errors === _errs25){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing6;
if((data.json === undefined) && (missing6 = "json")){
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
const _errs27 = errors;
for(const key6 in data){
if(!(key6 === "json")){
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
if(_errs27 === errors){
if(data.json !== undefined){
if(!(validate2948(data.json, {instancePath:instancePath+"/json",parentData:data,parentDataProperty:"json",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2948.errors : vErrors.concat(validate2948.errors);
errors = vErrors.length;
}
}
}
}
}
else {
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
var _valid0 = _errs25 === errors;
if(_valid0 && valid0){
valid0 = false;
passing0 = [passing0, 6];
}
else {
if(_valid0){
valid0 = true;
passing0 = 6;
if(props1 !== true){
props1 = true;
}
}
const _errs29 = errors;
if(errors === _errs29){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing7;
if((data.range === undefined) && (missing7 = "range")){
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
const _errs31 = errors;
for(const key7 in data){
if(!(key7 === "range")){
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
if(_errs31 === errors){
if(data.range !== undefined){
if(!(validate2987(data.range, {instancePath:instancePath+"/range",parentData:data,parentDataProperty:"range",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2987.errors : vErrors.concat(validate2987.errors);
errors = vErrors.length;
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
var _valid0 = _errs29 === errors;
if(_valid0 && valid0){
valid0 = false;
passing0 = [passing0, 7];
}
else {
if(_valid0){
valid0 = true;
passing0 = 7;
if(props1 !== true){
props1 = true;
}
}
const _errs33 = errors;
if(errors === _errs33){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing8;
if((data.multirange === undefined) && (missing8 = "multirange")){
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
const _errs35 = errors;
for(const key8 in data){
if(!(key8 === "multirange")){
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
if(_errs35 === errors){
if(data.multirange !== undefined){
if(!(validate2840(data.multirange, {instancePath:instancePath+"/multirange",parentData:data,parentDataProperty:"multirange",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2840.errors : vErrors.concat(validate2840.errors);
errors = vErrors.length;
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
var _valid0 = _errs33 === errors;
if(_valid0 && valid0){
valid0 = false;
passing0 = [passing0, 8];
}
else {
if(_valid0){
valid0 = true;
passing0 = 8;
if(props1 !== true){
props1 = true;
}
}
const _errs37 = errors;
if(errors === _errs37){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing9;
if((data.vector === undefined) && (missing9 = "vector")){
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
const _errs39 = errors;
for(const key9 in data){
if(!(key9 === "vector")){
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
if(_errs39 === errors){
if(data.vector !== undefined){
if(!(validate2948(data.vector, {instancePath:instancePath+"/vector",parentData:data,parentDataProperty:"vector",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2948.errors : vErrors.concat(validate2948.errors);
errors = vErrors.length;
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
var _valid0 = _errs37 === errors;
if(_valid0 && valid0){
valid0 = false;
passing0 = [passing0, 9];
}
else {
if(_valid0){
valid0 = true;
passing0 = 9;
if(props1 !== true){
props1 = true;
}
}
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
const err30 = {};
if(vErrors === null){
vErrors = [err30];
}
else {
vErrors.push(err30);
}
errors++;
validate2958.errors = vErrors;
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
validate2958.errors = vErrors;
evaluated0.props = props1;
return errors === 0;
}
validate2958.evaluated = {"dynamicProps":true,"dynamicItems":false};


function validate2952(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2952.evaluated;
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
if((data.missing === undefined) && (missing0 = "missing")){
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
const _errs3 = errors;
for(const key0 in data){
if(!(key0 === "missing")){
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
if(_errs3 === errors){
if(data.missing !== undefined){
if(!(validate2953(data.missing, {instancePath:instancePath+"/missing",parentData:data,parentDataProperty:"missing",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2953.errors : vErrors.concat(validate2953.errors);
errors = vErrors.length;
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
var _valid0 = _errs1 === errors;
if(_valid0){
valid0 = true;
passing0 = 0;
var props0 = true;
}
const _errs5 = errors;
if(errors === _errs5){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing1;
if((data.null === undefined) && (missing1 = "null")){
const err3 = {};
if(vErrors === null){
vErrors = [err3];
}
else {
vErrors.push(err3);
}
errors++;
}
else {
const _errs7 = errors;
for(const key1 in data){
if(!(key1 === "null")){
const err4 = {};
if(vErrors === null){
vErrors = [err4];
}
else {
vErrors.push(err4);
}
errors++;
break;
}
}
if(_errs7 === errors){
if(data.null !== undefined){
if(!(validate2953(data.null, {instancePath:instancePath+"/null",parentData:data,parentDataProperty:"null",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2953.errors : vErrors.concat(validate2953.errors);
errors = vErrors.length;
}
}
}
}
}
else {
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
var _valid0 = _errs5 === errors;
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
const _errs9 = errors;
if(errors === _errs9){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing2;
if((data.type_error === undefined) && (missing2 = "type_error")){
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
const _errs11 = errors;
for(const key2 in data){
if(!(key2 === "type_error")){
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
if(_errs11 === errors){
if(data.type_error !== undefined){
if(!(validate2956(data.type_error, {instancePath:instancePath+"/type_error",parentData:data,parentDataProperty:"type_error",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2956.errors : vErrors.concat(validate2956.errors);
errors = vErrors.length;
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
var _valid0 = _errs9 === errors;
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
const _errs13 = errors;
if(errors === _errs13){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing3;
if((data.value === undefined) && (missing3 = "value")){
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
const _errs15 = errors;
for(const key3 in data){
if(!(key3 === "value")){
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
if(_errs15 === errors){
if(data.value !== undefined){
if(!(validate2958(data.value, {instancePath:instancePath+"/value",parentData:data,parentDataProperty:"value",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2958.errors : vErrors.concat(validate2958.errors);
errors = vErrors.length;
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
var _valid0 = _errs13 === errors;
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
const _errs17 = errors;
if(errors === _errs17){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing4;
if((data.conflict === undefined) && (missing4 = "conflict")){
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
const _errs19 = errors;
for(const key4 in data){
if(!(key4 === "conflict")){
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
if(_errs19 === errors){
if(data.conflict !== undefined){
if(!(validate2845(data.conflict, {instancePath:instancePath+"/conflict",parentData:data,parentDataProperty:"conflict",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2845.errors : vErrors.concat(validate2845.errors);
errors = vErrors.length;
}
}
}
}
}
else {
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
var _valid0 = _errs17 === errors;
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
}
}
}
}
if(!valid0){
const err15 = {};
if(vErrors === null){
vErrors = [err15];
}
else {
vErrors.push(err15);
}
errors++;
validate2952.errors = vErrors;
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
validate2952.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate2952.evaluated = {"dynamicProps":true,"dynamicItems":false};


function validate2947(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2947.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((((data.column === undefined) && (missing0 = "column")) || ((data.op === undefined) && (missing0 = "op"))) || ((data.literal === undefined) && (missing0 = "literal"))){
validate2947.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "column") || (key0 === "op")) || (key0 === "literal"))){
validate2947.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.column !== undefined){
const _errs2 = errors;
if(!(validate2948(data.column, {instancePath:instancePath+"/column",parentData:data,parentDataProperty:"column",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2948.errors : vErrors.concat(validate2948.errors);
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
if(!(validate2950(data.op, {instancePath:instancePath+"/op",parentData:data,parentDataProperty:"op",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2950.errors : vErrors.concat(validate2950.errors);
errors = vErrors.length;
}
var valid0 = _errs3 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.literal !== undefined){
const _errs4 = errors;
if(!(validate2952(data.literal, {instancePath:instancePath+"/literal",parentData:data,parentDataProperty:"literal",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2952.errors : vErrors.concat(validate2952.errors);
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
validate2947.errors = [{}];
return false;
}
}
validate2947.errors = vErrors;
return errors === 0;
}
validate2947.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema823 = {"type":"object","additionalProperties":false,"properties":{"left_column":{"$ref":"#/$defs/CatalogResponse/$defs/T175"},"op":{"$ref":"#/$defs/CatalogResponse/$defs/T176"},"right_column":{"$ref":"#/$defs/CatalogResponse/$defs/T175"}},"required":["left_column","op","right_column"]};

function validate3003(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3003.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((((data.left_column === undefined) && (missing0 = "left_column")) || ((data.op === undefined) && (missing0 = "op"))) || ((data.right_column === undefined) && (missing0 = "right_column"))){
validate3003.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "left_column") || (key0 === "op")) || (key0 === "right_column"))){
validate3003.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.left_column !== undefined){
const _errs2 = errors;
if(!(validate2948(data.left_column, {instancePath:instancePath+"/left_column",parentData:data,parentDataProperty:"left_column",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2948.errors : vErrors.concat(validate2948.errors);
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
if(!(validate2950(data.op, {instancePath:instancePath+"/op",parentData:data,parentDataProperty:"op",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2950.errors : vErrors.concat(validate2950.errors);
errors = vErrors.length;
}
var valid0 = _errs3 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.right_column !== undefined){
const _errs4 = errors;
if(!(validate2948(data.right_column, {instancePath:instancePath+"/right_column",parentData:data,parentDataProperty:"right_column",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2948.errors : vErrors.concat(validate2948.errors);
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
validate3003.errors = [{}];
return false;
}
}
validate3003.errors = vErrors;
return errors === 0;
}
validate3003.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate2946(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2946.evaluated;
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
if((data.compare_literal === undefined) && (missing0 = "compare_literal")){
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
const _errs3 = errors;
for(const key0 in data){
if(!(key0 === "compare_literal")){
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
if(_errs3 === errors){
if(data.compare_literal !== undefined){
if(!(validate2947(data.compare_literal, {instancePath:instancePath+"/compare_literal",parentData:data,parentDataProperty:"compare_literal",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2947.errors : vErrors.concat(validate2947.errors);
errors = vErrors.length;
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
var _valid0 = _errs1 === errors;
if(_valid0){
valid0 = true;
passing0 = 0;
var props0 = true;
}
const _errs5 = errors;
if(errors === _errs5){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing1;
if((data.compare_columns === undefined) && (missing1 = "compare_columns")){
const err3 = {};
if(vErrors === null){
vErrors = [err3];
}
else {
vErrors.push(err3);
}
errors++;
}
else {
const _errs7 = errors;
for(const key1 in data){
if(!(key1 === "compare_columns")){
const err4 = {};
if(vErrors === null){
vErrors = [err4];
}
else {
vErrors.push(err4);
}
errors++;
break;
}
}
if(_errs7 === errors){
if(data.compare_columns !== undefined){
if(!(validate3003(data.compare_columns, {instancePath:instancePath+"/compare_columns",parentData:data,parentDataProperty:"compare_columns",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3003.errors : vErrors.concat(validate3003.errors);
errors = vErrors.length;
}
}
}
}
}
else {
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
var _valid0 = _errs5 === errors;
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
const _errs9 = errors;
if(errors === _errs9){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing2;
if((data.is_not_null === undefined) && (missing2 = "is_not_null")){
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
const _errs11 = errors;
for(const key2 in data){
if(!(key2 === "is_not_null")){
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
if(_errs11 === errors){
if(data.is_not_null !== undefined){
if(!(validate2948(data.is_not_null, {instancePath:instancePath+"/is_not_null",parentData:data,parentDataProperty:"is_not_null",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2948.errors : vErrors.concat(validate2948.errors);
errors = vErrors.length;
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
var _valid0 = _errs9 === errors;
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
const _errs13 = errors;
if(errors === _errs13){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing3;
if((data.is_null === undefined) && (missing3 = "is_null")){
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
const _errs15 = errors;
for(const key3 in data){
if(!(key3 === "is_null")){
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
if(_errs15 === errors){
if(data.is_null !== undefined){
if(!(validate2948(data.is_null, {instancePath:instancePath+"/is_null",parentData:data,parentDataProperty:"is_null",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2948.errors : vErrors.concat(validate2948.errors);
errors = vErrors.length;
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
var _valid0 = _errs13 === errors;
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
}
}
}
if(!valid0){
const err12 = {};
if(vErrors === null){
vErrors = [err12];
}
else {
vErrors.push(err12);
}
errors++;
validate2946.errors = vErrors;
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
validate2946.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate2946.evaluated = {"dynamicProps":true,"dynamicItems":false};


function validate2945(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2945.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(Array.isArray(data)){
if(data.length > 32){
validate2945.errors = [{}];
return false;
}
else {
var valid0 = true;
const len0 = data.length;
for(let i0=0; i0<len0; i0++){
const _errs1 = errors;
if(!(validate2946(data[i0], {instancePath:instancePath+"/" + i0,parentData:data,parentDataProperty:i0,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2946.errors : vErrors.concat(validate2946.errors);
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
validate2945.errors = [{}];
return false;
}
}
validate2945.errors = vErrors;
return errors === 0;
}
validate2945.evaluated = {"items":true,"dynamicProps":false,"dynamicItems":false};

const schema824 = {"type":"boolean"};

function validate3012(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3012.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "boolean"){
validate3012.errors = [{}];
return false;
}
validate3012.errors = vErrors;
return errors === 0;
}
validate3012.evaluated = {"dynamicProps":false,"dynamicItems":false};


function validate2940(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2940.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if(((((data.id === undefined) && (missing0 = "id")) || ((data.name === undefined) && (missing0 = "name"))) || ((data.atoms === undefined) && (missing0 = "atoms"))) || ((data.validated === undefined) && (missing0 = "validated"))){
validate2940.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((((key0 === "id") || (key0 === "name")) || (key0 === "atoms")) || (key0 === "validated"))){
validate2940.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.id !== undefined){
const _errs2 = errors;
if(!(validate2941(data.id, {instancePath:instancePath+"/id",parentData:data,parentDataProperty:"id",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2941.errors : vErrors.concat(validate2941.errors);
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
if(!(validate2943(data.name, {instancePath:instancePath+"/name",parentData:data,parentDataProperty:"name",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2943.errors : vErrors.concat(validate2943.errors);
errors = vErrors.length;
}
var valid0 = _errs3 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.atoms !== undefined){
const _errs4 = errors;
if(!(validate2945(data.atoms, {instancePath:instancePath+"/atoms",parentData:data,parentDataProperty:"atoms",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2945.errors : vErrors.concat(validate2945.errors);
errors = vErrors.length;
}
var valid0 = _errs4 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.validated !== undefined){
const _errs5 = errors;
if(!(validate3012(data.validated, {instancePath:instancePath+"/validated",parentData:data,parentDataProperty:"validated",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3012.errors : vErrors.concat(validate3012.errors);
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
validate2940.errors = [{}];
return false;
}
}
validate2940.errors = vErrors;
return errors === 0;
}
validate2940.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate2939(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2939.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(Array.isArray(data)){
if(data.length > 64){
validate2939.errors = [{}];
return false;
}
else {
var valid0 = true;
const len0 = data.length;
for(let i0=0; i0<len0; i0++){
const _errs1 = errors;
if(!(validate2940(data[i0], {instancePath:instancePath+"/" + i0,parentData:data,parentDataProperty:i0,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2940.errors : vErrors.concat(validate2940.errors);
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
validate2939.errors = [{}];
return false;
}
}
validate2939.errors = vErrors;
return errors === 0;
}
validate2939.evaluated = {"items":true,"dynamicProps":false,"dynamicItems":false};

const schema825 = {"type":"array","maxItems":64,"items":{"$ref":"#/$defs/CatalogResponse/$defs/T193"}};
const schema826 = {"type":"object","additionalProperties":false,"properties":{"id":{"$ref":"#/$defs/CatalogResponse/$defs/T170"},"name":{"$ref":"#/$defs/CatalogResponse/$defs/T171"},"local_columns":{"$ref":"#/$defs/CatalogResponse/$defs/T166"},"target_object":{"$ref":"#/$defs/CatalogResponse/$defs/T171"},"target_revision":{"$ref":"#/$defs/CatalogResponse/$defs/T171"},"target_definition":{"$ref":"#/$defs/CatalogResponse/$defs/T194"},"target_columns":{"$ref":"#/$defs/CatalogResponse/$defs/T166"},"on_delete":{"$ref":"#/$defs/CatalogResponse/$defs/T195"},"on_update":{"$ref":"#/$defs/CatalogResponse/$defs/T195"},"enforcement":{"$ref":"#/$defs/CatalogResponse/$defs/T196"}},"required":["id","name","local_columns","target_object","target_revision","target_definition","target_columns","on_delete","on_update","enforcement"]};
const schema827 = {"type":"object","additionalProperties":false,"properties":{"realm":{"$ref":"#/$defs/CatalogResponse/$defs/T171"},"resource":{"$ref":"#/$defs/CatalogResponse/$defs/T171"},"catalog":{"$ref":"#/$defs/CatalogResponse/$defs/T171"},"branch":{"$ref":"#/$defs/CatalogResponse/$defs/T171"},"object":{"$ref":"#/$defs/CatalogResponse/$defs/T171"},"revision":{"$ref":"#/$defs/CatalogResponse/$defs/T171"},"digest":{"$ref":"#/$defs/CatalogResponse/$defs/T171"}},"required":["realm","resource","catalog","branch","object","revision","digest"]};

function validate3023(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3023.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((((((((data.realm === undefined) && (missing0 = "realm")) || ((data.resource === undefined) && (missing0 = "resource"))) || ((data.catalog === undefined) && (missing0 = "catalog"))) || ((data.branch === undefined) && (missing0 = "branch"))) || ((data.object === undefined) && (missing0 = "object"))) || ((data.revision === undefined) && (missing0 = "revision"))) || ((data.digest === undefined) && (missing0 = "digest"))){
validate3023.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((((((key0 === "realm") || (key0 === "resource")) || (key0 === "catalog")) || (key0 === "branch")) || (key0 === "object")) || (key0 === "revision")) || (key0 === "digest"))){
validate3023.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.realm !== undefined){
const _errs2 = errors;
if(!(validate2943(data.realm, {instancePath:instancePath+"/realm",parentData:data,parentDataProperty:"realm",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2943.errors : vErrors.concat(validate2943.errors);
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
if(!(validate2943(data.resource, {instancePath:instancePath+"/resource",parentData:data,parentDataProperty:"resource",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2943.errors : vErrors.concat(validate2943.errors);
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
if(!(validate2943(data.catalog, {instancePath:instancePath+"/catalog",parentData:data,parentDataProperty:"catalog",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2943.errors : vErrors.concat(validate2943.errors);
errors = vErrors.length;
}
var valid0 = _errs4 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.branch !== undefined){
const _errs5 = errors;
if(!(validate2943(data.branch, {instancePath:instancePath+"/branch",parentData:data,parentDataProperty:"branch",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2943.errors : vErrors.concat(validate2943.errors);
errors = vErrors.length;
}
var valid0 = _errs5 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.object !== undefined){
const _errs6 = errors;
if(!(validate2943(data.object, {instancePath:instancePath+"/object",parentData:data,parentDataProperty:"object",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2943.errors : vErrors.concat(validate2943.errors);
errors = vErrors.length;
}
var valid0 = _errs6 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.revision !== undefined){
const _errs7 = errors;
if(!(validate2943(data.revision, {instancePath:instancePath+"/revision",parentData:data,parentDataProperty:"revision",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2943.errors : vErrors.concat(validate2943.errors);
errors = vErrors.length;
}
var valid0 = _errs7 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.digest !== undefined){
const _errs8 = errors;
if(!(validate2943(data.digest, {instancePath:instancePath+"/digest",parentData:data,parentDataProperty:"digest",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2943.errors : vErrors.concat(validate2943.errors);
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
validate3023.errors = [{}];
return false;
}
}
validate3023.errors = vErrors;
return errors === 0;
}
validate3023.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema828 = {"type":"string","enum":["restrict","no_action","cascade","set_null"]};

function validate3033(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3033.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate3033.errors = [{}];
return false;
}
if(!((((data === "restrict") || (data === "no_action")) || (data === "cascade")) || (data === "set_null"))){
validate3033.errors = [{}];
return false;
}
validate3033.errors = vErrors;
return errors === 0;
}
validate3033.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema829 = {"type":"string","enum":["staged_awaiting_index","enforced"]};

function validate3036(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3036.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate3036.errors = [{}];
return false;
}
if(!((data === "staged_awaiting_index") || (data === "enforced"))){
validate3036.errors = [{}];
return false;
}
validate3036.errors = vErrors;
return errors === 0;
}
validate3036.evaluated = {"dynamicProps":false,"dynamicItems":false};


function validate3017(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3017.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if(((((((((((data.id === undefined) && (missing0 = "id")) || ((data.name === undefined) && (missing0 = "name"))) || ((data.local_columns === undefined) && (missing0 = "local_columns"))) || ((data.target_object === undefined) && (missing0 = "target_object"))) || ((data.target_revision === undefined) && (missing0 = "target_revision"))) || ((data.target_definition === undefined) && (missing0 = "target_definition"))) || ((data.target_columns === undefined) && (missing0 = "target_columns"))) || ((data.on_delete === undefined) && (missing0 = "on_delete"))) || ((data.on_update === undefined) && (missing0 = "on_update"))) || ((data.enforcement === undefined) && (missing0 = "enforcement"))){
validate3017.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(func1.call(schema826.properties, key0))){
validate3017.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.id !== undefined){
const _errs2 = errors;
if(!(validate2941(data.id, {instancePath:instancePath+"/id",parentData:data,parentDataProperty:"id",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2941.errors : vErrors.concat(validate2941.errors);
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
if(!(validate2943(data.name, {instancePath:instancePath+"/name",parentData:data,parentDataProperty:"name",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2943.errors : vErrors.concat(validate2943.errors);
errors = vErrors.length;
}
var valid0 = _errs3 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.local_columns !== undefined){
const _errs4 = errors;
if(!(validate2934(data.local_columns, {instancePath:instancePath+"/local_columns",parentData:data,parentDataProperty:"local_columns",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2934.errors : vErrors.concat(validate2934.errors);
errors = vErrors.length;
}
var valid0 = _errs4 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.target_object !== undefined){
const _errs5 = errors;
if(!(validate2943(data.target_object, {instancePath:instancePath+"/target_object",parentData:data,parentDataProperty:"target_object",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2943.errors : vErrors.concat(validate2943.errors);
errors = vErrors.length;
}
var valid0 = _errs5 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.target_revision !== undefined){
const _errs6 = errors;
if(!(validate2943(data.target_revision, {instancePath:instancePath+"/target_revision",parentData:data,parentDataProperty:"target_revision",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2943.errors : vErrors.concat(validate2943.errors);
errors = vErrors.length;
}
var valid0 = _errs6 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.target_definition !== undefined){
const _errs7 = errors;
if(!(validate3023(data.target_definition, {instancePath:instancePath+"/target_definition",parentData:data,parentDataProperty:"target_definition",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3023.errors : vErrors.concat(validate3023.errors);
errors = vErrors.length;
}
var valid0 = _errs7 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.target_columns !== undefined){
const _errs8 = errors;
if(!(validate2934(data.target_columns, {instancePath:instancePath+"/target_columns",parentData:data,parentDataProperty:"target_columns",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2934.errors : vErrors.concat(validate2934.errors);
errors = vErrors.length;
}
var valid0 = _errs8 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.on_delete !== undefined){
const _errs9 = errors;
if(!(validate3033(data.on_delete, {instancePath:instancePath+"/on_delete",parentData:data,parentDataProperty:"on_delete",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3033.errors : vErrors.concat(validate3033.errors);
errors = vErrors.length;
}
var valid0 = _errs9 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.on_update !== undefined){
const _errs10 = errors;
if(!(validate3033(data.on_update, {instancePath:instancePath+"/on_update",parentData:data,parentDataProperty:"on_update",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3033.errors : vErrors.concat(validate3033.errors);
errors = vErrors.length;
}
var valid0 = _errs10 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.enforcement !== undefined){
const _errs11 = errors;
if(!(validate3036(data.enforcement, {instancePath:instancePath+"/enforcement",parentData:data,parentDataProperty:"enforcement",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3036.errors : vErrors.concat(validate3036.errors);
errors = vErrors.length;
}
var valid0 = _errs11 === errors;
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
else {
validate3017.errors = [{}];
return false;
}
}
validate3017.errors = vErrors;
return errors === 0;
}
validate3017.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate3016(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3016.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(Array.isArray(data)){
if(data.length > 64){
validate3016.errors = [{}];
return false;
}
else {
var valid0 = true;
const len0 = data.length;
for(let i0=0; i0<len0; i0++){
const _errs1 = errors;
if(!(validate3017(data[i0], {instancePath:instancePath+"/" + i0,parentData:data,parentDataProperty:i0,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3017.errors : vErrors.concat(validate3017.errors);
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
validate3016.errors = [{}];
return false;
}
}
validate3016.errors = vErrors;
return errors === 0;
}
validate3016.evaluated = {"items":true,"dynamicProps":false,"dynamicItems":false};


function validate2937(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2937.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((((data.next_id === undefined) && (missing0 = "next_id")) || ((data.checks === undefined) && (missing0 = "checks"))) || ((data.foreign_keys === undefined) && (missing0 = "foreign_keys"))){
validate2937.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "next_id") || (key0 === "checks")) || (key0 === "foreign_keys"))){
validate2937.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.next_id !== undefined){
const _errs2 = errors;
if(!(validate2355(data.next_id, {instancePath:instancePath+"/next_id",parentData:data,parentDataProperty:"next_id",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2355.errors : vErrors.concat(validate2355.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.checks !== undefined){
const _errs3 = errors;
if(!(validate2939(data.checks, {instancePath:instancePath+"/checks",parentData:data,parentDataProperty:"checks",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2939.errors : vErrors.concat(validate2939.errors);
errors = vErrors.length;
}
var valid0 = _errs3 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.foreign_keys !== undefined){
const _errs4 = errors;
if(!(validate3016(data.foreign_keys, {instancePath:instancePath+"/foreign_keys",parentData:data,parentDataProperty:"foreign_keys",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3016.errors : vErrors.concat(validate3016.errors);
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
validate2937.errors = [{}];
return false;
}
}
validate2937.errors = vErrors;
return errors === 0;
}
validate2937.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate2654(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2654.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((((((((data.definition === undefined) && (missing0 = "definition")) || ((data.object === undefined) && (missing0 = "object"))) || ((data.revision === undefined) && (missing0 = "revision"))) || ((data.next_column === undefined) && (missing0 = "next_column"))) || ((data.columns === undefined) && (missing0 = "columns"))) || ((data.primary_key === undefined) && (missing0 = "primary_key"))) || ((data.integrity === undefined) && (missing0 = "integrity"))){
validate2654.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((((((key0 === "definition") || (key0 === "object")) || (key0 === "revision")) || (key0 === "next_column")) || (key0 === "columns")) || (key0 === "primary_key")) || (key0 === "integrity"))){
validate2654.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.definition !== undefined){
const _errs2 = errors;
if(!(validate2349(data.definition, {instancePath:instancePath+"/definition",parentData:data,parentDataProperty:"definition",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2349.errors : vErrors.concat(validate2349.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.object !== undefined){
const _errs3 = errors;
if(!(validate2367(data.object, {instancePath:instancePath+"/object",parentData:data,parentDataProperty:"object",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2367.errors : vErrors.concat(validate2367.errors);
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
if(!(validate2367(data.revision, {instancePath:instancePath+"/revision",parentData:data,parentDataProperty:"revision",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2367.errors : vErrors.concat(validate2367.errors);
errors = vErrors.length;
}
var valid0 = _errs4 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.next_column !== undefined){
const _errs5 = errors;
if(!(validate2367(data.next_column, {instancePath:instancePath+"/next_column",parentData:data,parentDataProperty:"next_column",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2367.errors : vErrors.concat(validate2367.errors);
errors = vErrors.length;
}
var valid0 = _errs5 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.columns !== undefined){
const _errs6 = errors;
if(!(validate2659(data.columns, {instancePath:instancePath+"/columns",parentData:data,parentDataProperty:"columns",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2659.errors : vErrors.concat(validate2659.errors);
errors = vErrors.length;
}
var valid0 = _errs6 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.primary_key !== undefined){
const _errs7 = errors;
if(!(validate2934(data.primary_key, {instancePath:instancePath+"/primary_key",parentData:data,parentDataProperty:"primary_key",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2934.errors : vErrors.concat(validate2934.errors);
errors = vErrors.length;
}
var valid0 = _errs7 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.integrity !== undefined){
const _errs8 = errors;
if(!(validate2937(data.integrity, {instancePath:instancePath+"/integrity",parentData:data,parentDataProperty:"integrity",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2937.errors : vErrors.concat(validate2937.errors);
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
validate2654.errors = [{}];
return false;
}
}
validate2654.errors = vErrors;
return errors === 0;
}
validate2654.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema830 = {"type":"object","additionalProperties":false,"properties":{"database":{"$ref":"#/$defs/CatalogResponse/$defs/T10"},"schema":{"$ref":"#/$defs/CatalogResponse/$defs/T10"},"table":{"$ref":"#/$defs/CatalogResponse/$defs/T10"}},"required":["database","schema","table"]};

function validate3044(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3044.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((((data.database === undefined) && (missing0 = "database")) || ((data.schema === undefined) && (missing0 = "schema"))) || ((data.table === undefined) && (missing0 = "table"))){
validate3044.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "database") || (key0 === "schema")) || (key0 === "table"))){
validate3044.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.database !== undefined){
const _errs2 = errors;
if(!(validate2364(data.database, {instancePath:instancePath+"/database",parentData:data,parentDataProperty:"database",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2364.errors : vErrors.concat(validate2364.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.schema !== undefined){
const _errs3 = errors;
if(!(validate2364(data.schema, {instancePath:instancePath+"/schema",parentData:data,parentDataProperty:"schema",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2364.errors : vErrors.concat(validate2364.errors);
errors = vErrors.length;
}
var valid0 = _errs3 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.table !== undefined){
const _errs4 = errors;
if(!(validate2364(data.table, {instancePath:instancePath+"/table",parentData:data,parentDataProperty:"table",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2364.errors : vErrors.concat(validate2364.errors);
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
validate3044.errors = [{}];
return false;
}
}
validate3044.errors = vErrors;
return errors === 0;
}
validate3044.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate2645(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2645.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if(((((((data.snapshot === undefined) && (missing0 = "snapshot")) || ((data.binding === undefined) && (missing0 = "binding"))) || ((data.schema === undefined) && (missing0 = "schema"))) || ((data.rows === undefined) && (missing0 = "rows"))) || ((data.changed_lsn === undefined) && (missing0 = "changed_lsn"))) || ((data.authority === undefined) && (missing0 = "authority"))){
validate2645.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((((((key0 === "snapshot") || (key0 === "binding")) || (key0 === "schema")) || (key0 === "rows")) || (key0 === "changed_lsn")) || (key0 === "authority"))){
validate2645.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.snapshot !== undefined){
const _errs2 = errors;
if(!(validate2472(data.snapshot, {instancePath:instancePath+"/snapshot",parentData:data,parentDataProperty:"snapshot",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2472.errors : vErrors.concat(validate2472.errors);
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
if(!(validate2647(data.binding, {instancePath:instancePath+"/binding",parentData:data,parentDataProperty:"binding",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2647.errors : vErrors.concat(validate2647.errors);
errors = vErrors.length;
}
var valid0 = _errs3 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.schema !== undefined){
const _errs4 = errors;
if(!(validate2654(data.schema, {instancePath:instancePath+"/schema",parentData:data,parentDataProperty:"schema",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2654.errors : vErrors.concat(validate2654.errors);
errors = vErrors.length;
}
var valid0 = _errs4 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.rows !== undefined){
const _errs5 = errors;
if(!(validate2367(data.rows, {instancePath:instancePath+"/rows",parentData:data,parentDataProperty:"rows",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2367.errors : vErrors.concat(validate2367.errors);
errors = vErrors.length;
}
var valid0 = _errs5 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.changed_lsn !== undefined){
const _errs6 = errors;
if(!(validate2367(data.changed_lsn, {instancePath:instancePath+"/changed_lsn",parentData:data,parentDataProperty:"changed_lsn",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2367.errors : vErrors.concat(validate2367.errors);
errors = vErrors.length;
}
var valid0 = _errs6 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.authority !== undefined){
const _errs7 = errors;
if(!(validate3044(data.authority, {instancePath:instancePath+"/authority",parentData:data,parentDataProperty:"authority",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3044.errors : vErrors.concat(validate3044.errors);
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
validate2645.errors = [{}];
return false;
}
}
validate2645.errors = vErrors;
return errors === 0;
}
validate2645.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate2470(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2470.evaluated;
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
if((data.coverage === undefined) && (missing0 = "coverage")){
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
const _errs3 = errors;
for(const key0 in data){
if(!(key0 === "coverage")){
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
if(_errs3 === errors){
if(data.coverage !== undefined){
if(!(validate2471(data.coverage, {instancePath:instancePath+"/coverage",parentData:data,parentDataProperty:"coverage",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2471.errors : vErrors.concat(validate2471.errors);
errors = vErrors.length;
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
var _valid0 = _errs1 === errors;
if(_valid0){
valid0 = true;
passing0 = 0;
var props0 = true;
}
const _errs5 = errors;
if(errors === _errs5){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing1;
if((data.object === undefined) && (missing1 = "object")){
const err3 = {};
if(vErrors === null){
vErrors = [err3];
}
else {
vErrors.push(err3);
}
errors++;
}
else {
const _errs7 = errors;
for(const key1 in data){
if(!(key1 === "object")){
const err4 = {};
if(vErrors === null){
vErrors = [err4];
}
else {
vErrors.push(err4);
}
errors++;
break;
}
}
if(_errs7 === errors){
if(data.object !== undefined){
if(!(validate2599(data.object, {instancePath:instancePath+"/object",parentData:data,parentDataProperty:"object",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2599.errors : vErrors.concat(validate2599.errors);
errors = vErrors.length;
}
}
}
}
}
else {
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
var _valid0 = _errs5 === errors;
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
const _errs9 = errors;
if(errors === _errs9){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing2;
if((data.namespace === undefined) && (missing2 = "namespace")){
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
const _errs11 = errors;
for(const key2 in data){
if(!(key2 === "namespace")){
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
if(_errs11 === errors){
if(data.namespace !== undefined){
if(!(validate2602(data.namespace, {instancePath:instancePath+"/namespace",parentData:data,parentDataProperty:"namespace",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2602.errors : vErrors.concat(validate2602.errors);
errors = vErrors.length;
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
var _valid0 = _errs9 === errors;
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
const _errs13 = errors;
if(errors === _errs13){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing3;
if((data.listing === undefined) && (missing3 = "listing")){
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
const _errs15 = errors;
for(const key3 in data){
if(!(key3 === "listing")){
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
if(_errs15 === errors){
if(data.listing !== undefined){
if(!(validate2611(data.listing, {instancePath:instancePath+"/listing",parentData:data,parentDataProperty:"listing",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2611.errors : vErrors.concat(validate2611.errors);
errors = vErrors.length;
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
var _valid0 = _errs13 === errors;
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
const _errs17 = errors;
if(errors === _errs17){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing4;
if((data.source === undefined) && (missing4 = "source")){
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
const _errs19 = errors;
for(const key4 in data){
if(!(key4 === "source")){
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
if(_errs19 === errors){
if(data.source !== undefined){
if(!(validate2645(data.source, {instancePath:instancePath+"/source",parentData:data,parentDataProperty:"source",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2645.errors : vErrors.concat(validate2645.errors);
errors = vErrors.length;
}
}
}
}
}
else {
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
var _valid0 = _errs17 === errors;
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
}
}
}
}
if(!valid0){
const err15 = {};
if(vErrors === null){
vErrors = [err15];
}
else {
vErrors.push(err15);
}
errors++;
validate2470.errors = vErrors;
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
validate2470.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate2470.evaluated = {"dynamicProps":true,"dynamicItems":false};

const schema831 = {"oneOf":[{"type":"object","additionalProperties":false,"required":["definition"],"properties":{"definition":{"$ref":"#/$defs/CatalogResponse/$defs/T199"}}},{"type":"object","additionalProperties":false,"required":["historical"],"properties":{"historical":{"$ref":"#/$defs/CatalogResponse/$defs/T240"}}},{"type":"object","additionalProperties":false,"required":["page"],"properties":{"page":{"$ref":"#/$defs/CatalogResponse/$defs/T242"}}}]};
const schema832 = {"anyOf":[{"$ref":"#/$defs/CatalogResponse/$defs/T200"},{"type":"null"}]};
const schema833 = {"type":"object","additionalProperties":false,"properties":{"stored":{"$ref":"#/$defs/CatalogResponse/$defs/T201"},"schema":{"$ref":"#/$defs/CatalogResponse/$defs/T85"},"sources":{"$ref":"#/$defs/CatalogResponse/$defs/T204"},"body":{"$ref":"#/$defs/CatalogResponse/$defs/T219"}},"required":["stored","schema","sources","body"]};
const schema834 = {"type":"object","additionalProperties":false,"properties":{"kind":{"$ref":"#/$defs/CatalogResponse/$defs/T202"},"interpretation":{"$ref":"#/$defs/CatalogResponse/$defs/T31"},"content":{"$ref":"#/$defs/CatalogResponse/$defs/T38"},"properties":{"$ref":"#/$defs/CatalogResponse/$defs/T203"},"schema_fingerprint":{"$ref":"#/$defs/CatalogResponse/$defs/T11"},"next_column":{"$ref":"#/$defs/CatalogResponse/$defs/T11"},"retired":{"$ref":"#/$defs/CatalogResponse/$defs/T17"}},"required":["kind","interpretation","content","properties","schema_fingerprint","next_column","retired"]};
const schema835 = {"type":"string","enum":["view","property_graph","foreign"]};

function validate3055(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3055.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate3055.errors = [{}];
return false;
}
if(!(((data === "view") || (data === "property_graph")) || (data === "foreign"))){
validate3055.errors = [{}];
return false;
}
validate3055.errors = vErrors;
return errors === 0;
}
validate3055.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema836 = {"type":"object","additionalProperties":false,"properties":{"namespace":{"$ref":"#/$defs/CatalogResponse/$defs/T10"},"authorization":{"$ref":"#/$defs/CatalogResponse/$defs/T10"},"name":{"$ref":"#/$defs/CatalogResponse/$defs/T11"}},"required":["namespace","authorization","name"]};

function validate3059(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3059.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((((data.namespace === undefined) && (missing0 = "namespace")) || ((data.authorization === undefined) && (missing0 = "authorization"))) || ((data.name === undefined) && (missing0 = "name"))){
validate3059.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "namespace") || (key0 === "authorization")) || (key0 === "name"))){
validate3059.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.namespace !== undefined){
const _errs2 = errors;
if(!(validate2364(data.namespace, {instancePath:instancePath+"/namespace",parentData:data,parentDataProperty:"namespace",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2364.errors : vErrors.concat(validate2364.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.authorization !== undefined){
const _errs3 = errors;
if(!(validate2364(data.authorization, {instancePath:instancePath+"/authorization",parentData:data,parentDataProperty:"authorization",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2364.errors : vErrors.concat(validate2364.errors);
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
if(!(validate2367(data.name, {instancePath:instancePath+"/name",parentData:data,parentDataProperty:"name",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2367.errors : vErrors.concat(validate2367.errors);
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
validate3059.errors = [{}];
return false;
}
}
validate3059.errors = vErrors;
return errors === 0;
}
validate3059.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate3054(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3054.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((((((((data.kind === undefined) && (missing0 = "kind")) || ((data.interpretation === undefined) && (missing0 = "interpretation"))) || ((data.content === undefined) && (missing0 = "content"))) || ((data.properties === undefined) && (missing0 = "properties"))) || ((data.schema_fingerprint === undefined) && (missing0 = "schema_fingerprint"))) || ((data.next_column === undefined) && (missing0 = "next_column"))) || ((data.retired === undefined) && (missing0 = "retired"))){
validate3054.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((((((key0 === "kind") || (key0 === "interpretation")) || (key0 === "content")) || (key0 === "properties")) || (key0 === "schema_fingerprint")) || (key0 === "next_column")) || (key0 === "retired"))){
validate3054.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.kind !== undefined){
const _errs2 = errors;
if(!(validate3055(data.kind, {instancePath:instancePath+"/kind",parentData:data,parentDataProperty:"kind",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3055.errors : vErrors.concat(validate3055.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.interpretation !== undefined){
const _errs3 = errors;
if(!(validate2448(data.interpretation, {instancePath:instancePath+"/interpretation",parentData:data,parentDataProperty:"interpretation",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2448.errors : vErrors.concat(validate2448.errors);
errors = vErrors.length;
}
var valid0 = _errs3 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.content !== undefined){
const _errs4 = errors;
if(!(validate2481(data.content, {instancePath:instancePath+"/content",parentData:data,parentDataProperty:"content",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2481.errors : vErrors.concat(validate2481.errors);
errors = vErrors.length;
}
var valid0 = _errs4 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.properties !== undefined){
const _errs5 = errors;
if(!(validate3059(data.properties, {instancePath:instancePath+"/properties",parentData:data,parentDataProperty:"properties",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3059.errors : vErrors.concat(validate3059.errors);
errors = vErrors.length;
}
var valid0 = _errs5 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.schema_fingerprint !== undefined){
const _errs6 = errors;
if(!(validate2367(data.schema_fingerprint, {instancePath:instancePath+"/schema_fingerprint",parentData:data,parentDataProperty:"schema_fingerprint",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2367.errors : vErrors.concat(validate2367.errors);
errors = vErrors.length;
}
var valid0 = _errs6 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.next_column !== undefined){
const _errs7 = errors;
if(!(validate2367(data.next_column, {instancePath:instancePath+"/next_column",parentData:data,parentDataProperty:"next_column",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2367.errors : vErrors.concat(validate2367.errors);
errors = vErrors.length;
}
var valid0 = _errs7 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.retired !== undefined){
const _errs8 = errors;
if(!(validate2409(data.retired, {instancePath:instancePath+"/retired",parentData:data,parentDataProperty:"retired",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2409.errors : vErrors.concat(validate2409.errors);
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
validate3054.errors = [{}];
return false;
}
}
validate3054.errors = vErrors;
return errors === 0;
}
validate3054.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema837 = {"type":"array","maxItems":4,"items":{"$ref":"#/$defs/CatalogResponse/$defs/T205"}};
const schema838 = {"type":"object","additionalProperties":false,"properties":{"declaration":{"$ref":"#/$defs/CatalogResponse/$defs/T206"},"properties":{"$ref":"#/$defs/CatalogResponse/$defs/T214"},"schema":{"$ref":"#/$defs/CatalogResponse/$defs/T215"}},"required":["declaration","properties","schema"]};
const schema839 = {"type":"object","additionalProperties":false,"properties":{"interpretation":{"$ref":"#/$defs/CatalogResponse/$defs/T207"},"content":{"$ref":"#/$defs/CatalogResponse/$defs/T212"},"schema_fingerprint":{"$ref":"#/$defs/CatalogResponse/$defs/T211"},"retired":{"$ref":"#/$defs/CatalogResponse/$defs/T213"}},"required":["interpretation","content","schema_fingerprint","retired"]};
const schema840 = {"type":"object","additionalProperties":false,"properties":{"object":{"$ref":"#/$defs/CatalogResponse/$defs/T208"},"revision":{"$ref":"#/$defs/CatalogResponse/$defs/T211"},"digest":{"$ref":"#/$defs/CatalogResponse/$defs/T211"}},"required":["object","revision","digest"]};
const schema841 = {"type":"object","additionalProperties":false,"properties":{"scope":{"$ref":"#/$defs/CatalogResponse/$defs/T209"},"branch":{"$ref":"#/$defs/CatalogResponse/$defs/T211"},"object":{"$ref":"#/$defs/CatalogResponse/$defs/T211"}},"required":["scope","branch","object"]};
const schema842 = {"type":"object","additionalProperties":false,"properties":{"realm":{"$ref":"#/$defs/CatalogResponse/$defs/T210"},"resource":{"$ref":"#/$defs/CatalogResponse/$defs/T210"},"catalog":{"$ref":"#/$defs/CatalogResponse/$defs/T211"}},"required":["realm","resource","catalog"]};

function validate3075(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3075.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(!(((typeof data == "number") && (!(data % 1) && !isNaN(data))) && (isFinite(data)))){
validate3075.errors = [{}];
return false;
}
if(errors === 0){
if((typeof data == "number") && (isFinite(data))){
if(data > 9007199254740991 || isNaN(data)){
validate3075.errors = [{}];
return false;
}
else {
if(data < 0 || isNaN(data)){
validate3075.errors = [{}];
return false;
}
}
}
}
validate3075.errors = vErrors;
return errors === 0;
}
validate3075.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema844 = {"type":"string","maxLength":262144};

function validate3078(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3078.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(typeof data === "string"){
if(func3(data) > 262144){
validate3078.errors = [{}];
return false;
}
}
else {
validate3078.errors = [{}];
return false;
}
}
validate3078.errors = vErrors;
return errors === 0;
}
validate3078.evaluated = {"dynamicProps":false,"dynamicItems":false};


function validate3074(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3074.evaluated;
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
validate3074.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "realm") || (key0 === "resource")) || (key0 === "catalog"))){
validate3074.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.realm !== undefined){
const _errs2 = errors;
if(!(validate3075(data.realm, {instancePath:instancePath+"/realm",parentData:data,parentDataProperty:"realm",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3075.errors : vErrors.concat(validate3075.errors);
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
if(!(validate3075(data.resource, {instancePath:instancePath+"/resource",parentData:data,parentDataProperty:"resource",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3075.errors : vErrors.concat(validate3075.errors);
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
if(!(validate3078(data.catalog, {instancePath:instancePath+"/catalog",parentData:data,parentDataProperty:"catalog",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3078.errors : vErrors.concat(validate3078.errors);
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
validate3074.errors = [{}];
return false;
}
}
validate3074.errors = vErrors;
return errors === 0;
}
validate3074.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate3073(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3073.evaluated;
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
validate3073.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "scope") || (key0 === "branch")) || (key0 === "object"))){
validate3073.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.scope !== undefined){
const _errs2 = errors;
if(!(validate3074(data.scope, {instancePath:instancePath+"/scope",parentData:data,parentDataProperty:"scope",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3074.errors : vErrors.concat(validate3074.errors);
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
if(!(validate3078(data.branch, {instancePath:instancePath+"/branch",parentData:data,parentDataProperty:"branch",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3078.errors : vErrors.concat(validate3078.errors);
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
if(!(validate3078(data.object, {instancePath:instancePath+"/object",parentData:data,parentDataProperty:"object",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3078.errors : vErrors.concat(validate3078.errors);
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
validate3073.errors = [{}];
return false;
}
}
validate3073.errors = vErrors;
return errors === 0;
}
validate3073.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate3072(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3072.evaluated;
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
validate3072.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "object") || (key0 === "revision")) || (key0 === "digest"))){
validate3072.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.object !== undefined){
const _errs2 = errors;
if(!(validate3073(data.object, {instancePath:instancePath+"/object",parentData:data,parentDataProperty:"object",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3073.errors : vErrors.concat(validate3073.errors);
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
if(!(validate3078(data.revision, {instancePath:instancePath+"/revision",parentData:data,parentDataProperty:"revision",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3078.errors : vErrors.concat(validate3078.errors);
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
if(!(validate3078(data.digest, {instancePath:instancePath+"/digest",parentData:data,parentDataProperty:"digest",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3078.errors : vErrors.concat(validate3078.errors);
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
validate3072.errors = [{}];
return false;
}
}
validate3072.errors = vErrors;
return errors === 0;
}
validate3072.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema845 = {"type":"object","additionalProperties":false,"properties":{"bytes":{"$ref":"#/$defs/CatalogResponse/$defs/T211"},"sha256":{"$ref":"#/$defs/CatalogResponse/$defs/T211"}},"required":["bytes","sha256"]};

function validate3087(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3087.evaluated;
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
validate3087.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "bytes") || (key0 === "sha256"))){
validate3087.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.bytes !== undefined){
const _errs2 = errors;
if(!(validate3078(data.bytes, {instancePath:instancePath+"/bytes",parentData:data,parentDataProperty:"bytes",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3078.errors : vErrors.concat(validate3078.errors);
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
if(!(validate3078(data.sha256, {instancePath:instancePath+"/sha256",parentData:data,parentDataProperty:"sha256",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3078.errors : vErrors.concat(validate3078.errors);
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
validate3087.errors = [{}];
return false;
}
}
validate3087.errors = vErrors;
return errors === 0;
}
validate3087.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema846 = {"type":"boolean"};

function validate3092(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3092.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "boolean"){
validate3092.errors = [{}];
return false;
}
validate3092.errors = vErrors;
return errors === 0;
}
validate3092.evaluated = {"dynamicProps":false,"dynamicItems":false};


function validate3071(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3071.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if(((((data.interpretation === undefined) && (missing0 = "interpretation")) || ((data.content === undefined) && (missing0 = "content"))) || ((data.schema_fingerprint === undefined) && (missing0 = "schema_fingerprint"))) || ((data.retired === undefined) && (missing0 = "retired"))){
validate3071.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((((key0 === "interpretation") || (key0 === "content")) || (key0 === "schema_fingerprint")) || (key0 === "retired"))){
validate3071.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.interpretation !== undefined){
const _errs2 = errors;
if(!(validate3072(data.interpretation, {instancePath:instancePath+"/interpretation",parentData:data,parentDataProperty:"interpretation",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3072.errors : vErrors.concat(validate3072.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.content !== undefined){
const _errs3 = errors;
if(!(validate3087(data.content, {instancePath:instancePath+"/content",parentData:data,parentDataProperty:"content",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3087.errors : vErrors.concat(validate3087.errors);
errors = vErrors.length;
}
var valid0 = _errs3 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.schema_fingerprint !== undefined){
const _errs4 = errors;
if(!(validate3078(data.schema_fingerprint, {instancePath:instancePath+"/schema_fingerprint",parentData:data,parentDataProperty:"schema_fingerprint",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3078.errors : vErrors.concat(validate3078.errors);
errors = vErrors.length;
}
var valid0 = _errs4 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.retired !== undefined){
const _errs5 = errors;
if(!(validate3092(data.retired, {instancePath:instancePath+"/retired",parentData:data,parentDataProperty:"retired",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3092.errors : vErrors.concat(validate3092.errors);
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
validate3071.errors = [{}];
return false;
}
}
validate3071.errors = vErrors;
return errors === 0;
}
validate3071.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema847 = {"type":"object","additionalProperties":false,"properties":{"namespace":{"$ref":"#/$defs/CatalogResponse/$defs/T210"},"authorization":{"$ref":"#/$defs/CatalogResponse/$defs/T210"},"name":{"$ref":"#/$defs/CatalogResponse/$defs/T211"}},"required":["namespace","authorization","name"]};

function validate3095(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3095.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((((data.namespace === undefined) && (missing0 = "namespace")) || ((data.authorization === undefined) && (missing0 = "authorization"))) || ((data.name === undefined) && (missing0 = "name"))){
validate3095.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "namespace") || (key0 === "authorization")) || (key0 === "name"))){
validate3095.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.namespace !== undefined){
const _errs2 = errors;
if(!(validate3075(data.namespace, {instancePath:instancePath+"/namespace",parentData:data,parentDataProperty:"namespace",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3075.errors : vErrors.concat(validate3075.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.authorization !== undefined){
const _errs3 = errors;
if(!(validate3075(data.authorization, {instancePath:instancePath+"/authorization",parentData:data,parentDataProperty:"authorization",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3075.errors : vErrors.concat(validate3075.errors);
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
if(!(validate3078(data.name, {instancePath:instancePath+"/name",parentData:data,parentDataProperty:"name",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3078.errors : vErrors.concat(validate3078.errors);
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
validate3095.errors = [{}];
return false;
}
}
validate3095.errors = vErrors;
return errors === 0;
}
validate3095.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema848 = {"type":"object","additionalProperties":false,"properties":{"definition":{"$ref":"#/$defs/CatalogResponse/$defs/T216"},"object":{"$ref":"#/$defs/CatalogResponse/$defs/T211"},"revision":{"$ref":"#/$defs/CatalogResponse/$defs/T211"},"next_column":{"$ref":"#/$defs/CatalogResponse/$defs/T211"},"columns":{"$ref":"#/$defs/CatalogResponse/$defs/T86"},"primary_key":{"$ref":"#/$defs/CatalogResponse/$defs/T166"},"integrity":{"$ref":"#/$defs/CatalogResponse/$defs/T217"}},"required":["definition","object","revision","next_column","columns","primary_key","integrity"]};

function validate3101(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3101.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate3101.errors = [{}];
return false;
}
if(!(data === "6da8e815dec26c458515e34fb6553654d57c77536f652b9258897bf1a513842e")){
validate3101.errors = [{}];
return false;
}
validate3101.errors = vErrors;
return errors === 0;
}
validate3101.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema850 = {"type":"object","additionalProperties":false,"properties":{"next_id":{"$ref":"#/$defs/CatalogResponse/$defs/T218"},"checks":{"$ref":"#/$defs/CatalogResponse/$defs/T168"},"foreign_keys":{"$ref":"#/$defs/CatalogResponse/$defs/T192"}},"required":["next_id","checks","foreign_keys"]};

function validate3109(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3109.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(!(((typeof data == "number") && (!(data % 1) && !isNaN(data))) && (isFinite(data)))){
validate3109.errors = [{}];
return false;
}
if(errors === 0){
if((typeof data == "number") && (isFinite(data))){
if(data > 4294967295 || isNaN(data)){
validate3109.errors = [{}];
return false;
}
else {
if(data < 0 || isNaN(data)){
validate3109.errors = [{}];
return false;
}
}
}
}
validate3109.errors = vErrors;
return errors === 0;
}
validate3109.evaluated = {"dynamicProps":false,"dynamicItems":false};


function validate3108(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3108.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((((data.next_id === undefined) && (missing0 = "next_id")) || ((data.checks === undefined) && (missing0 = "checks"))) || ((data.foreign_keys === undefined) && (missing0 = "foreign_keys"))){
validate3108.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "next_id") || (key0 === "checks")) || (key0 === "foreign_keys"))){
validate3108.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.next_id !== undefined){
const _errs2 = errors;
if(!(validate3109(data.next_id, {instancePath:instancePath+"/next_id",parentData:data,parentDataProperty:"next_id",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3109.errors : vErrors.concat(validate3109.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.checks !== undefined){
const _errs3 = errors;
if(!(validate2939(data.checks, {instancePath:instancePath+"/checks",parentData:data,parentDataProperty:"checks",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2939.errors : vErrors.concat(validate2939.errors);
errors = vErrors.length;
}
var valid0 = _errs3 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.foreign_keys !== undefined){
const _errs4 = errors;
if(!(validate3016(data.foreign_keys, {instancePath:instancePath+"/foreign_keys",parentData:data,parentDataProperty:"foreign_keys",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3016.errors : vErrors.concat(validate3016.errors);
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
validate3108.errors = [{}];
return false;
}
}
validate3108.errors = vErrors;
return errors === 0;
}
validate3108.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate3100(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3100.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((((((((data.definition === undefined) && (missing0 = "definition")) || ((data.object === undefined) && (missing0 = "object"))) || ((data.revision === undefined) && (missing0 = "revision"))) || ((data.next_column === undefined) && (missing0 = "next_column"))) || ((data.columns === undefined) && (missing0 = "columns"))) || ((data.primary_key === undefined) && (missing0 = "primary_key"))) || ((data.integrity === undefined) && (missing0 = "integrity"))){
validate3100.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((((((key0 === "definition") || (key0 === "object")) || (key0 === "revision")) || (key0 === "next_column")) || (key0 === "columns")) || (key0 === "primary_key")) || (key0 === "integrity"))){
validate3100.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.definition !== undefined){
const _errs2 = errors;
if(!(validate3101(data.definition, {instancePath:instancePath+"/definition",parentData:data,parentDataProperty:"definition",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3101.errors : vErrors.concat(validate3101.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.object !== undefined){
const _errs3 = errors;
if(!(validate3078(data.object, {instancePath:instancePath+"/object",parentData:data,parentDataProperty:"object",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3078.errors : vErrors.concat(validate3078.errors);
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
if(!(validate3078(data.revision, {instancePath:instancePath+"/revision",parentData:data,parentDataProperty:"revision",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3078.errors : vErrors.concat(validate3078.errors);
errors = vErrors.length;
}
var valid0 = _errs4 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.next_column !== undefined){
const _errs5 = errors;
if(!(validate3078(data.next_column, {instancePath:instancePath+"/next_column",parentData:data,parentDataProperty:"next_column",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3078.errors : vErrors.concat(validate3078.errors);
errors = vErrors.length;
}
var valid0 = _errs5 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.columns !== undefined){
const _errs6 = errors;
if(!(validate2659(data.columns, {instancePath:instancePath+"/columns",parentData:data,parentDataProperty:"columns",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2659.errors : vErrors.concat(validate2659.errors);
errors = vErrors.length;
}
var valid0 = _errs6 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.primary_key !== undefined){
const _errs7 = errors;
if(!(validate2934(data.primary_key, {instancePath:instancePath+"/primary_key",parentData:data,parentDataProperty:"primary_key",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2934.errors : vErrors.concat(validate2934.errors);
errors = vErrors.length;
}
var valid0 = _errs7 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.integrity !== undefined){
const _errs8 = errors;
if(!(validate3108(data.integrity, {instancePath:instancePath+"/integrity",parentData:data,parentDataProperty:"integrity",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3108.errors : vErrors.concat(validate3108.errors);
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
validate3100.errors = [{}];
return false;
}
}
validate3100.errors = vErrors;
return errors === 0;
}
validate3100.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate3070(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3070.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((((data.declaration === undefined) && (missing0 = "declaration")) || ((data.properties === undefined) && (missing0 = "properties"))) || ((data.schema === undefined) && (missing0 = "schema"))){
validate3070.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "declaration") || (key0 === "properties")) || (key0 === "schema"))){
validate3070.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.declaration !== undefined){
const _errs2 = errors;
if(!(validate3071(data.declaration, {instancePath:instancePath+"/declaration",parentData:data,parentDataProperty:"declaration",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3071.errors : vErrors.concat(validate3071.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.properties !== undefined){
const _errs3 = errors;
if(!(validate3095(data.properties, {instancePath:instancePath+"/properties",parentData:data,parentDataProperty:"properties",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3095.errors : vErrors.concat(validate3095.errors);
errors = vErrors.length;
}
var valid0 = _errs3 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.schema !== undefined){
const _errs4 = errors;
if(!(validate3100(data.schema, {instancePath:instancePath+"/schema",parentData:data,parentDataProperty:"schema",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3100.errors : vErrors.concat(validate3100.errors);
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
validate3070.errors = [{}];
return false;
}
}
validate3070.errors = vErrors;
return errors === 0;
}
validate3070.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate3069(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3069.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(Array.isArray(data)){
if(data.length > 4){
validate3069.errors = [{}];
return false;
}
else {
var valid0 = true;
const len0 = data.length;
for(let i0=0; i0<len0; i0++){
const _errs1 = errors;
if(!(validate3070(data[i0], {instancePath:instancePath+"/" + i0,parentData:data,parentDataProperty:i0,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3070.errors : vErrors.concat(validate3070.errors);
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
validate3069.errors = [{}];
return false;
}
}
validate3069.errors = vErrors;
return errors === 0;
}
validate3069.evaluated = {"items":true,"dynamicProps":false,"dynamicItems":false};

const schema852 = {"oneOf":[{"type":"object","additionalProperties":false,"required":["view"],"properties":{"view":{"$ref":"#/$defs/CatalogResponse/$defs/T220"}}},{"type":"object","additionalProperties":false,"required":["property_graph"],"properties":{"property_graph":{"$ref":"#/$defs/CatalogResponse/$defs/T223"}}},{"type":"object","additionalProperties":false,"required":["foreign"],"properties":{"foreign":{"$ref":"#/$defs/CatalogResponse/$defs/T234"}}}]};
const schema853 = {"type":"object","additionalProperties":false,"properties":{"plan":{"$ref":"#/$defs/CatalogResponse/$defs/T221"},"source_text":{"$ref":"#/$defs/CatalogResponse/$defs/T11"}},"required":["plan","source_text"]};
const schema854 = {"type":"object","additionalProperties":false,"properties":{"base64":{"$ref":"#/$defs/CatalogResponse/$defs/T222"}},"required":["base64"]};
const schema855 = {"type":"string","maxLength":5592408};

function validate3120(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3120.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(typeof data === "string"){
if(func3(data) > 5592408){
validate3120.errors = [{}];
return false;
}
}
else {
validate3120.errors = [{}];
return false;
}
}
validate3120.errors = vErrors;
return errors === 0;
}
validate3120.evaluated = {"dynamicProps":false,"dynamicItems":false};


function validate3119(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3119.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((data.base64 === undefined) && (missing0 = "base64")){
validate3119.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(key0 === "base64")){
validate3119.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.base64 !== undefined){
if(!(validate3120(data.base64, {instancePath:instancePath+"/base64",parentData:data,parentDataProperty:"base64",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3120.errors : vErrors.concat(validate3120.errors);
errors = vErrors.length;
}
}
}
}
}
else {
validate3119.errors = [{}];
return false;
}
}
validate3119.errors = vErrors;
return errors === 0;
}
validate3119.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate3118(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3118.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if(((data.plan === undefined) && (missing0 = "plan")) || ((data.source_text === undefined) && (missing0 = "source_text"))){
validate3118.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "plan") || (key0 === "source_text"))){
validate3118.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.plan !== undefined){
const _errs2 = errors;
if(!(validate3119(data.plan, {instancePath:instancePath+"/plan",parentData:data,parentDataProperty:"plan",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3119.errors : vErrors.concat(validate3119.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.source_text !== undefined){
const _errs3 = errors;
if(!(validate2367(data.source_text, {instancePath:instancePath+"/source_text",parentData:data,parentDataProperty:"source_text",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2367.errors : vErrors.concat(validate2367.errors);
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
validate3118.errors = [{}];
return false;
}
}
validate3118.errors = vErrors;
return errors === 0;
}
validate3118.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema856 = {"type":"object","additionalProperties":false,"properties":{"next_mapping":{"$ref":"#/$defs/CatalogResponse/$defs/T11"},"vertices":{"$ref":"#/$defs/CatalogResponse/$defs/T224"},"edges":{"$ref":"#/$defs/CatalogResponse/$defs/T232"}},"required":["next_mapping","vertices","edges"]};
const schema857 = {"type":"array","maxItems":16,"items":{"$ref":"#/$defs/CatalogResponse/$defs/T225"}};
const schema858 = {"type":"object","additionalProperties":false,"properties":{"id":{"$ref":"#/$defs/CatalogResponse/$defs/T226"},"label":{"$ref":"#/$defs/CatalogResponse/$defs/T226"},"key":{"$ref":"#/$defs/CatalogResponse/$defs/T227"},"properties":{"$ref":"#/$defs/CatalogResponse/$defs/T229"}},"required":["id","label","key","properties"]};
const schema859 = {"type":"string","maxLength":262144};

function validate3129(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3129.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(typeof data === "string"){
if(func3(data) > 262144){
validate3129.errors = [{}];
return false;
}
}
else {
validate3129.errors = [{}];
return false;
}
}
validate3129.errors = vErrors;
return errors === 0;
}
validate3129.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema860 = {"type":"object","additionalProperties":false,"properties":{"source":{"$ref":"#/$defs/CatalogResponse/$defs/T228"},"column":{"$ref":"#/$defs/CatalogResponse/$defs/T226"}},"required":["source","column"]};

function validate3133(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3133.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(!(((typeof data == "number") && (!(data % 1) && !isNaN(data))) && (isFinite(data)))){
validate3133.errors = [{}];
return false;
}
if(errors === 0){
if((typeof data == "number") && (isFinite(data))){
if(data > 255 || isNaN(data)){
validate3133.errors = [{}];
return false;
}
else {
if(data < 0 || isNaN(data)){
validate3133.errors = [{}];
return false;
}
}
}
}
validate3133.errors = vErrors;
return errors === 0;
}
validate3133.evaluated = {"dynamicProps":false,"dynamicItems":false};


function validate3132(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3132.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if(((data.source === undefined) && (missing0 = "source")) || ((data.column === undefined) && (missing0 = "column"))){
validate3132.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "source") || (key0 === "column"))){
validate3132.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.source !== undefined){
const _errs2 = errors;
if(!(validate3133(data.source, {instancePath:instancePath+"/source",parentData:data,parentDataProperty:"source",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3133.errors : vErrors.concat(validate3133.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.column !== undefined){
const _errs3 = errors;
if(!(validate3129(data.column, {instancePath:instancePath+"/column",parentData:data,parentDataProperty:"column",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3129.errors : vErrors.concat(validate3129.errors);
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
validate3132.errors = [{}];
return false;
}
}
validate3132.errors = vErrors;
return errors === 0;
}
validate3132.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema862 = {"type":"array","maxItems":128,"items":{"$ref":"#/$defs/CatalogResponse/$defs/T230"}};
const schema863 = {"type":"object","additionalProperties":false,"properties":{"id":{"$ref":"#/$defs/CatalogResponse/$defs/T46"},"name":{"$ref":"#/$defs/CatalogResponse/$defs/T46"},"value":{"$ref":"#/$defs/CatalogResponse/$defs/T231"}},"required":["id","name","value"]};
const schema864 = {"type":"object","additionalProperties":false,"properties":{"source":{"$ref":"#/$defs/CatalogResponse/$defs/T91"},"column":{"$ref":"#/$defs/CatalogResponse/$defs/T46"}},"required":["source","column"]};

function validate3141(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3141.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if(((data.source === undefined) && (missing0 = "source")) || ((data.column === undefined) && (missing0 = "column"))){
validate3141.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "source") || (key0 === "column"))){
validate3141.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.source !== undefined){
const _errs2 = errors;
if(!(validate2681(data.source, {instancePath:instancePath+"/source",parentData:data,parentDataProperty:"source",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2681.errors : vErrors.concat(validate2681.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.column !== undefined){
const _errs3 = errors;
if(!(validate2513(data.column, {instancePath:instancePath+"/column",parentData:data,parentDataProperty:"column",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2513.errors : vErrors.concat(validate2513.errors);
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
validate3141.errors = [{}];
return false;
}
}
validate3141.errors = vErrors;
return errors === 0;
}
validate3141.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate3138(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3138.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((((data.id === undefined) && (missing0 = "id")) || ((data.name === undefined) && (missing0 = "name"))) || ((data.value === undefined) && (missing0 = "value"))){
validate3138.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "id") || (key0 === "name")) || (key0 === "value"))){
validate3138.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.id !== undefined){
const _errs2 = errors;
if(!(validate2513(data.id, {instancePath:instancePath+"/id",parentData:data,parentDataProperty:"id",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2513.errors : vErrors.concat(validate2513.errors);
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
if(!(validate2513(data.name, {instancePath:instancePath+"/name",parentData:data,parentDataProperty:"name",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2513.errors : vErrors.concat(validate2513.errors);
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
if(!(validate3141(data.value, {instancePath:instancePath+"/value",parentData:data,parentDataProperty:"value",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3141.errors : vErrors.concat(validate3141.errors);
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
validate3138.errors = [{}];
return false;
}
}
validate3138.errors = vErrors;
return errors === 0;
}
validate3138.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate3137(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3137.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(Array.isArray(data)){
if(data.length > 128){
validate3137.errors = [{}];
return false;
}
else {
var valid0 = true;
const len0 = data.length;
for(let i0=0; i0<len0; i0++){
const _errs1 = errors;
if(!(validate3138(data[i0], {instancePath:instancePath+"/" + i0,parentData:data,parentDataProperty:i0,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3138.errors : vErrors.concat(validate3138.errors);
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
validate3137.errors = [{}];
return false;
}
}
validate3137.errors = vErrors;
return errors === 0;
}
validate3137.evaluated = {"items":true,"dynamicProps":false,"dynamicItems":false};


function validate3128(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3128.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if(((((data.id === undefined) && (missing0 = "id")) || ((data.label === undefined) && (missing0 = "label"))) || ((data.key === undefined) && (missing0 = "key"))) || ((data.properties === undefined) && (missing0 = "properties"))){
validate3128.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((((key0 === "id") || (key0 === "label")) || (key0 === "key")) || (key0 === "properties"))){
validate3128.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.id !== undefined){
const _errs2 = errors;
if(!(validate3129(data.id, {instancePath:instancePath+"/id",parentData:data,parentDataProperty:"id",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3129.errors : vErrors.concat(validate3129.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.label !== undefined){
const _errs3 = errors;
if(!(validate3129(data.label, {instancePath:instancePath+"/label",parentData:data,parentDataProperty:"label",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3129.errors : vErrors.concat(validate3129.errors);
errors = vErrors.length;
}
var valid0 = _errs3 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.key !== undefined){
const _errs4 = errors;
if(!(validate3132(data.key, {instancePath:instancePath+"/key",parentData:data,parentDataProperty:"key",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3132.errors : vErrors.concat(validate3132.errors);
errors = vErrors.length;
}
var valid0 = _errs4 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.properties !== undefined){
const _errs5 = errors;
if(!(validate3137(data.properties, {instancePath:instancePath+"/properties",parentData:data,parentDataProperty:"properties",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3137.errors : vErrors.concat(validate3137.errors);
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
validate3128.errors = [{}];
return false;
}
}
validate3128.errors = vErrors;
return errors === 0;
}
validate3128.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate3127(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3127.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(Array.isArray(data)){
if(data.length > 16){
validate3127.errors = [{}];
return false;
}
else {
var valid0 = true;
const len0 = data.length;
for(let i0=0; i0<len0; i0++){
const _errs1 = errors;
if(!(validate3128(data[i0], {instancePath:instancePath+"/" + i0,parentData:data,parentDataProperty:i0,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3128.errors : vErrors.concat(validate3128.errors);
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
validate3127.errors = [{}];
return false;
}
}
validate3127.errors = vErrors;
return errors === 0;
}
validate3127.evaluated = {"items":true,"dynamicProps":false,"dynamicItems":false};

const schema865 = {"type":"array","maxItems":16,"items":{"$ref":"#/$defs/CatalogResponse/$defs/T233"}};
const schema866 = {"type":"object","additionalProperties":false,"properties":{"id":{"$ref":"#/$defs/CatalogResponse/$defs/T226"},"label":{"$ref":"#/$defs/CatalogResponse/$defs/T226"},"key":{"$ref":"#/$defs/CatalogResponse/$defs/T227"},"source_vertex":{"$ref":"#/$defs/CatalogResponse/$defs/T226"},"source_key":{"$ref":"#/$defs/CatalogResponse/$defs/T227"},"target_vertex":{"$ref":"#/$defs/CatalogResponse/$defs/T226"},"target_key":{"$ref":"#/$defs/CatalogResponse/$defs/T227"},"properties":{"$ref":"#/$defs/CatalogResponse/$defs/T229"}},"required":["id","label","key","source_vertex","source_key","target_vertex","target_key","properties"]};

function validate3150(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3150.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if(((((((((data.id === undefined) && (missing0 = "id")) || ((data.label === undefined) && (missing0 = "label"))) || ((data.key === undefined) && (missing0 = "key"))) || ((data.source_vertex === undefined) && (missing0 = "source_vertex"))) || ((data.source_key === undefined) && (missing0 = "source_key"))) || ((data.target_vertex === undefined) && (missing0 = "target_vertex"))) || ((data.target_key === undefined) && (missing0 = "target_key"))) || ((data.properties === undefined) && (missing0 = "properties"))){
validate3150.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((((((((key0 === "id") || (key0 === "label")) || (key0 === "key")) || (key0 === "source_vertex")) || (key0 === "source_key")) || (key0 === "target_vertex")) || (key0 === "target_key")) || (key0 === "properties"))){
validate3150.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.id !== undefined){
const _errs2 = errors;
if(!(validate3129(data.id, {instancePath:instancePath+"/id",parentData:data,parentDataProperty:"id",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3129.errors : vErrors.concat(validate3129.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.label !== undefined){
const _errs3 = errors;
if(!(validate3129(data.label, {instancePath:instancePath+"/label",parentData:data,parentDataProperty:"label",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3129.errors : vErrors.concat(validate3129.errors);
errors = vErrors.length;
}
var valid0 = _errs3 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.key !== undefined){
const _errs4 = errors;
if(!(validate3132(data.key, {instancePath:instancePath+"/key",parentData:data,parentDataProperty:"key",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3132.errors : vErrors.concat(validate3132.errors);
errors = vErrors.length;
}
var valid0 = _errs4 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.source_vertex !== undefined){
const _errs5 = errors;
if(!(validate3129(data.source_vertex, {instancePath:instancePath+"/source_vertex",parentData:data,parentDataProperty:"source_vertex",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3129.errors : vErrors.concat(validate3129.errors);
errors = vErrors.length;
}
var valid0 = _errs5 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.source_key !== undefined){
const _errs6 = errors;
if(!(validate3132(data.source_key, {instancePath:instancePath+"/source_key",parentData:data,parentDataProperty:"source_key",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3132.errors : vErrors.concat(validate3132.errors);
errors = vErrors.length;
}
var valid0 = _errs6 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.target_vertex !== undefined){
const _errs7 = errors;
if(!(validate3129(data.target_vertex, {instancePath:instancePath+"/target_vertex",parentData:data,parentDataProperty:"target_vertex",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3129.errors : vErrors.concat(validate3129.errors);
errors = vErrors.length;
}
var valid0 = _errs7 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.target_key !== undefined){
const _errs8 = errors;
if(!(validate3132(data.target_key, {instancePath:instancePath+"/target_key",parentData:data,parentDataProperty:"target_key",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3132.errors : vErrors.concat(validate3132.errors);
errors = vErrors.length;
}
var valid0 = _errs8 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.properties !== undefined){
const _errs9 = errors;
if(!(validate3137(data.properties, {instancePath:instancePath+"/properties",parentData:data,parentDataProperty:"properties",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3137.errors : vErrors.concat(validate3137.errors);
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
validate3150.errors = [{}];
return false;
}
}
validate3150.errors = vErrors;
return errors === 0;
}
validate3150.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate3149(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3149.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(Array.isArray(data)){
if(data.length > 16){
validate3149.errors = [{}];
return false;
}
else {
var valid0 = true;
const len0 = data.length;
for(let i0=0; i0<len0; i0++){
const _errs1 = errors;
if(!(validate3150(data[i0], {instancePath:instancePath+"/" + i0,parentData:data,parentDataProperty:i0,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3150.errors : vErrors.concat(validate3150.errors);
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
validate3149.errors = [{}];
return false;
}
}
validate3149.errors = vErrors;
return errors === 0;
}
validate3149.evaluated = {"items":true,"dynamicProps":false,"dynamicItems":false};


function validate3125(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3125.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((((data.next_mapping === undefined) && (missing0 = "next_mapping")) || ((data.vertices === undefined) && (missing0 = "vertices"))) || ((data.edges === undefined) && (missing0 = "edges"))){
validate3125.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "next_mapping") || (key0 === "vertices")) || (key0 === "edges"))){
validate3125.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.next_mapping !== undefined){
const _errs2 = errors;
if(!(validate2367(data.next_mapping, {instancePath:instancePath+"/next_mapping",parentData:data,parentDataProperty:"next_mapping",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2367.errors : vErrors.concat(validate2367.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.vertices !== undefined){
const _errs3 = errors;
if(!(validate3127(data.vertices, {instancePath:instancePath+"/vertices",parentData:data,parentDataProperty:"vertices",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3127.errors : vErrors.concat(validate3127.errors);
errors = vErrors.length;
}
var valid0 = _errs3 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.edges !== undefined){
const _errs4 = errors;
if(!(validate3149(data.edges, {instancePath:instancePath+"/edges",parentData:data,parentDataProperty:"edges",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3149.errors : vErrors.concat(validate3149.errors);
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
validate3125.errors = [{}];
return false;
}
}
validate3125.errors = vErrors;
return errors === 0;
}
validate3125.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema867 = {"type":"object","additionalProperties":false,"properties":{"record_bytes":{"$ref":"#/$defs/CatalogResponse/$defs/T6"},"fields":{"$ref":"#/$defs/CatalogResponse/$defs/T235"},"malformed":{"$ref":"#/$defs/CatalogResponse/$defs/T237"},"input":{"$ref":"#/$defs/CatalogResponse/$defs/T238"}},"required":["record_bytes","fields","malformed","input"]};
const schema868 = {"type":"array","maxItems":128,"items":{"$ref":"#/$defs/CatalogResponse/$defs/T236"}};
const schema869 = {"type":"object","additionalProperties":false,"properties":{"column":{"$ref":"#/$defs/CatalogResponse/$defs/T46"},"offset":{"$ref":"#/$defs/CatalogResponse/$defs/T109"},"bytes":{"$ref":"#/$defs/CatalogResponse/$defs/T109"},"encoding":{"$ref":"#/$defs/CatalogResponse/$defs/T146"}},"required":["column","offset","bytes","encoding"]};

function validate3165(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3165.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if(((((data.column === undefined) && (missing0 = "column")) || ((data.offset === undefined) && (missing0 = "offset"))) || ((data.bytes === undefined) && (missing0 = "bytes"))) || ((data.encoding === undefined) && (missing0 = "encoding"))){
validate3165.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((((key0 === "column") || (key0 === "offset")) || (key0 === "bytes")) || (key0 === "encoding"))){
validate3165.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.column !== undefined){
const _errs2 = errors;
if(!(validate2513(data.column, {instancePath:instancePath+"/column",parentData:data,parentDataProperty:"column",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2513.errors : vErrors.concat(validate2513.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.offset !== undefined){
const _errs3 = errors;
if(!(validate2751(data.offset, {instancePath:instancePath+"/offset",parentData:data,parentDataProperty:"offset",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2751.errors : vErrors.concat(validate2751.errors);
errors = vErrors.length;
}
var valid0 = _errs3 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.bytes !== undefined){
const _errs4 = errors;
if(!(validate2751(data.bytes, {instancePath:instancePath+"/bytes",parentData:data,parentDataProperty:"bytes",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2751.errors : vErrors.concat(validate2751.errors);
errors = vErrors.length;
}
var valid0 = _errs4 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.encoding !== undefined){
const _errs5 = errors;
if(!(validate2884(data.encoding, {instancePath:instancePath+"/encoding",parentData:data,parentDataProperty:"encoding",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2884.errors : vErrors.concat(validate2884.errors);
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
validate3165.errors = [{}];
return false;
}
}
validate3165.errors = vErrors;
return errors === 0;
}
validate3165.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate3164(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3164.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(Array.isArray(data)){
if(data.length > 128){
validate3164.errors = [{}];
return false;
}
else {
var valid0 = true;
const len0 = data.length;
for(let i0=0; i0<len0; i0++){
const _errs1 = errors;
if(!(validate3165(data[i0], {instancePath:instancePath+"/" + i0,parentData:data,parentDataProperty:i0,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3165.errors : vErrors.concat(validate3165.errors);
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
validate3164.errors = [{}];
return false;
}
}
validate3164.errors = vErrors;
return errors === 0;
}
validate3164.evaluated = {"items":true,"dynamicProps":false,"dynamicItems":false};

const schema870 = {"type":"string","enum":["reject","type_error"]};

function validate3172(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3172.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate3172.errors = [{}];
return false;
}
if(!((data === "reject") || (data === "type_error"))){
validate3172.errors = [{}];
return false;
}
validate3172.errors = vErrors;
return errors === 0;
}
validate3172.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema871 = {"type":"object","additionalProperties":false,"properties":{"content":{"$ref":"#/$defs/CatalogResponse/$defs/T38"},"availability":{"$ref":"#/$defs/CatalogResponse/$defs/T239"},"provenance":{"$ref":"#/$defs/CatalogResponse/$defs/T11"}},"required":["content","availability","provenance"]};
const schema872 = {"type":"string","enum":["retained","unavailable"]};

function validate3176(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3176.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate3176.errors = [{}];
return false;
}
if(!((data === "retained") || (data === "unavailable"))){
validate3176.errors = [{}];
return false;
}
validate3176.errors = vErrors;
return errors === 0;
}
validate3176.evaluated = {"dynamicProps":false,"dynamicItems":false};


function validate3174(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3174.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((((data.content === undefined) && (missing0 = "content")) || ((data.availability === undefined) && (missing0 = "availability"))) || ((data.provenance === undefined) && (missing0 = "provenance"))){
validate3174.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "content") || (key0 === "availability")) || (key0 === "provenance"))){
validate3174.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.content !== undefined){
const _errs2 = errors;
if(!(validate2481(data.content, {instancePath:instancePath+"/content",parentData:data,parentDataProperty:"content",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2481.errors : vErrors.concat(validate2481.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.availability !== undefined){
const _errs3 = errors;
if(!(validate3176(data.availability, {instancePath:instancePath+"/availability",parentData:data,parentDataProperty:"availability",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3176.errors : vErrors.concat(validate3176.errors);
errors = vErrors.length;
}
var valid0 = _errs3 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.provenance !== undefined){
const _errs4 = errors;
if(!(validate2367(data.provenance, {instancePath:instancePath+"/provenance",parentData:data,parentDataProperty:"provenance",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2367.errors : vErrors.concat(validate2367.errors);
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
validate3174.errors = [{}];
return false;
}
}
validate3174.errors = vErrors;
return errors === 0;
}
validate3174.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate3162(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3162.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if(((((data.record_bytes === undefined) && (missing0 = "record_bytes")) || ((data.fields === undefined) && (missing0 = "fields"))) || ((data.malformed === undefined) && (missing0 = "malformed"))) || ((data.input === undefined) && (missing0 = "input"))){
validate3162.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((((key0 === "record_bytes") || (key0 === "fields")) || (key0 === "malformed")) || (key0 === "input"))){
validate3162.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.record_bytes !== undefined){
const _errs2 = errors;
if(!(validate2355(data.record_bytes, {instancePath:instancePath+"/record_bytes",parentData:data,parentDataProperty:"record_bytes",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2355.errors : vErrors.concat(validate2355.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.fields !== undefined){
const _errs3 = errors;
if(!(validate3164(data.fields, {instancePath:instancePath+"/fields",parentData:data,parentDataProperty:"fields",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3164.errors : vErrors.concat(validate3164.errors);
errors = vErrors.length;
}
var valid0 = _errs3 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.malformed !== undefined){
const _errs4 = errors;
if(!(validate3172(data.malformed, {instancePath:instancePath+"/malformed",parentData:data,parentDataProperty:"malformed",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3172.errors : vErrors.concat(validate3172.errors);
errors = vErrors.length;
}
var valid0 = _errs4 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.input !== undefined){
const _errs5 = errors;
if(!(validate3174(data.input, {instancePath:instancePath+"/input",parentData:data,parentDataProperty:"input",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3174.errors : vErrors.concat(validate3174.errors);
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
validate3162.errors = [{}];
return false;
}
}
validate3162.errors = vErrors;
return errors === 0;
}
validate3162.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate3117(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3117.evaluated;
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
if((data.view === undefined) && (missing0 = "view")){
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
const _errs3 = errors;
for(const key0 in data){
if(!(key0 === "view")){
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
if(_errs3 === errors){
if(data.view !== undefined){
if(!(validate3118(data.view, {instancePath:instancePath+"/view",parentData:data,parentDataProperty:"view",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3118.errors : vErrors.concat(validate3118.errors);
errors = vErrors.length;
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
var _valid0 = _errs1 === errors;
if(_valid0){
valid0 = true;
passing0 = 0;
var props0 = true;
}
const _errs5 = errors;
if(errors === _errs5){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing1;
if((data.property_graph === undefined) && (missing1 = "property_graph")){
const err3 = {};
if(vErrors === null){
vErrors = [err3];
}
else {
vErrors.push(err3);
}
errors++;
}
else {
const _errs7 = errors;
for(const key1 in data){
if(!(key1 === "property_graph")){
const err4 = {};
if(vErrors === null){
vErrors = [err4];
}
else {
vErrors.push(err4);
}
errors++;
break;
}
}
if(_errs7 === errors){
if(data.property_graph !== undefined){
if(!(validate3125(data.property_graph, {instancePath:instancePath+"/property_graph",parentData:data,parentDataProperty:"property_graph",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3125.errors : vErrors.concat(validate3125.errors);
errors = vErrors.length;
}
}
}
}
}
else {
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
var _valid0 = _errs5 === errors;
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
const _errs9 = errors;
if(errors === _errs9){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing2;
if((data.foreign === undefined) && (missing2 = "foreign")){
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
const _errs11 = errors;
for(const key2 in data){
if(!(key2 === "foreign")){
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
if(_errs11 === errors){
if(data.foreign !== undefined){
if(!(validate3162(data.foreign, {instancePath:instancePath+"/foreign",parentData:data,parentDataProperty:"foreign",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3162.errors : vErrors.concat(validate3162.errors);
errors = vErrors.length;
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
var _valid0 = _errs9 === errors;
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
const err9 = {};
if(vErrors === null){
vErrors = [err9];
}
else {
vErrors.push(err9);
}
errors++;
validate3117.errors = vErrors;
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
validate3117.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate3117.evaluated = {"dynamicProps":true,"dynamicItems":false};


function validate3053(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3053.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if(((((data.stored === undefined) && (missing0 = "stored")) || ((data.schema === undefined) && (missing0 = "schema"))) || ((data.sources === undefined) && (missing0 = "sources"))) || ((data.body === undefined) && (missing0 = "body"))){
validate3053.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((((key0 === "stored") || (key0 === "schema")) || (key0 === "sources")) || (key0 === "body"))){
validate3053.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.stored !== undefined){
const _errs2 = errors;
if(!(validate3054(data.stored, {instancePath:instancePath+"/stored",parentData:data,parentDataProperty:"stored",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3054.errors : vErrors.concat(validate3054.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.schema !== undefined){
const _errs3 = errors;
if(!(validate2654(data.schema, {instancePath:instancePath+"/schema",parentData:data,parentDataProperty:"schema",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2654.errors : vErrors.concat(validate2654.errors);
errors = vErrors.length;
}
var valid0 = _errs3 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.sources !== undefined){
const _errs4 = errors;
if(!(validate3069(data.sources, {instancePath:instancePath+"/sources",parentData:data,parentDataProperty:"sources",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3069.errors : vErrors.concat(validate3069.errors);
errors = vErrors.length;
}
var valid0 = _errs4 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.body !== undefined){
const _errs5 = errors;
if(!(validate3117(data.body, {instancePath:instancePath+"/body",parentData:data,parentDataProperty:"body",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3117.errors : vErrors.concat(validate3117.errors);
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
validate3053.errors = [{}];
return false;
}
}
validate3053.errors = vErrors;
return errors === 0;
}
validate3053.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate3052(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3052.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate3053(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3053.errors : vErrors.concat(validate3053.errors);
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
validate3052.errors = vErrors;
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
validate3052.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate3052.evaluated = {"dynamicProps":true,"dynamicItems":false};

const schema873 = {"type":"object","additionalProperties":false,"properties":{"snapshot":{"$ref":"#/$defs/CatalogResponse/$defs/T36"},"catalog":{"$ref":"#/$defs/CatalogResponse/$defs/T241"},"definition":{"$ref":"#/$defs/CatalogResponse/$defs/T199"}},"required":["snapshot","catalog","definition"]};
const schema874 = {"anyOf":[{"$ref":"#/$defs/CatalogResponse/$defs/T26"},{"type":"null"}]};

function validate3186(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3186.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate2435(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2435.errors : vErrors.concat(validate2435.errors);
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
validate3186.errors = vErrors;
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
validate3186.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate3186.evaluated = {"dynamicProps":true,"dynamicItems":false};


function validate3184(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3184.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((((data.snapshot === undefined) && (missing0 = "snapshot")) || ((data.catalog === undefined) && (missing0 = "catalog"))) || ((data.definition === undefined) && (missing0 = "definition"))){
validate3184.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "snapshot") || (key0 === "catalog")) || (key0 === "definition"))){
validate3184.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.snapshot !== undefined){
const _errs2 = errors;
if(!(validate2472(data.snapshot, {instancePath:instancePath+"/snapshot",parentData:data,parentDataProperty:"snapshot",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2472.errors : vErrors.concat(validate2472.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.catalog !== undefined){
const _errs3 = errors;
if(!(validate3186(data.catalog, {instancePath:instancePath+"/catalog",parentData:data,parentDataProperty:"catalog",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3186.errors : vErrors.concat(validate3186.errors);
errors = vErrors.length;
}
var valid0 = _errs3 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.definition !== undefined){
const _errs4 = errors;
if(!(validate3052(data.definition, {instancePath:instancePath+"/definition",parentData:data,parentDataProperty:"definition",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3052.errors : vErrors.concat(validate3052.errors);
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
validate3184.errors = [{}];
return false;
}
}
validate3184.errors = vErrors;
return errors === 0;
}
validate3184.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema875 = {"type":"object","additionalProperties":false,"properties":{"entries":{"$ref":"#/$defs/CatalogResponse/$defs/T243"},"next":{"$ref":"#/$defs/CatalogResponse/$defs/T245"},"snapshot":{"$ref":"#/$defs/CatalogResponse/$defs/T247"},"position":{"$ref":"#/$defs/CatalogResponse/$defs/T241"}},"required":["entries","next","snapshot","position"]};
const schema876 = {"type":"array","minItems":4,"maxItems":4,"items":{"$ref":"#/$defs/CatalogResponse/$defs/T244"}};
const schema877 = {"anyOf":[{"$ref":"#/$defs/CatalogResponse/$defs/T201"},{"type":"null"}]};

function validate3193(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3193.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate3054(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3054.errors : vErrors.concat(validate3054.errors);
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
validate3193.errors = vErrors;
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
validate3193.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate3193.evaluated = {"dynamicProps":true,"dynamicItems":false};


function validate3192(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3192.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(Array.isArray(data)){
if(data.length > 4){
validate3192.errors = [{}];
return false;
}
else {
if(data.length < 4){
validate3192.errors = [{}];
return false;
}
else {
var valid0 = true;
const len0 = data.length;
for(let i0=0; i0<len0; i0++){
const _errs1 = errors;
if(!(validate3193(data[i0], {instancePath:instancePath+"/" + i0,parentData:data,parentDataProperty:i0,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3193.errors : vErrors.concat(validate3193.errors);
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
validate3192.errors = [{}];
return false;
}
}
validate3192.errors = vErrors;
return errors === 0;
}
validate3192.evaluated = {"items":true,"dynamicProps":false,"dynamicItems":false};

const schema878 = {"anyOf":[{"$ref":"#/$defs/CatalogResponse/$defs/T246"},{"type":"null"}]};
const schema879 = {"type":"object","additionalProperties":false,"properties":{"definition":{"$ref":"#/$defs/CatalogResponse/$defs/T4"},"connection":{"$ref":"#/$defs/CatalogResponse/$defs/T22"},"namespace":{"$ref":"#/$defs/CatalogResponse/$defs/T10"},"selector":{"$ref":"#/$defs/CatalogResponse/$defs/T72"},"after":{"$ref":"#/$defs/CatalogResponse/$defs/T11"}},"required":["definition","connection","namespace","selector","after"]};

function validate3198(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3198.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((((((data.definition === undefined) && (missing0 = "definition")) || ((data.connection === undefined) && (missing0 = "connection"))) || ((data.namespace === undefined) && (missing0 = "namespace"))) || ((data.selector === undefined) && (missing0 = "selector"))) || ((data.after === undefined) && (missing0 = "after"))){
validate3198.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((((key0 === "definition") || (key0 === "connection")) || (key0 === "namespace")) || (key0 === "selector")) || (key0 === "after"))){
validate3198.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.definition !== undefined){
const _errs2 = errors;
if(!(validate2349(data.definition, {instancePath:instancePath+"/definition",parentData:data,parentDataProperty:"definition",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2349.errors : vErrors.concat(validate2349.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.connection !== undefined){
const _errs3 = errors;
if(!(validate2420(data.connection, {instancePath:instancePath+"/connection",parentData:data,parentDataProperty:"connection",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2420.errors : vErrors.concat(validate2420.errors);
errors = vErrors.length;
}
var valid0 = _errs3 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.namespace !== undefined){
const _errs4 = errors;
if(!(validate2364(data.namespace, {instancePath:instancePath+"/namespace",parentData:data,parentDataProperty:"namespace",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2364.errors : vErrors.concat(validate2364.errors);
errors = vErrors.length;
}
var valid0 = _errs4 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.selector !== undefined){
const _errs5 = errors;
if(!(validate2599(data.selector, {instancePath:instancePath+"/selector",parentData:data,parentDataProperty:"selector",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2599.errors : vErrors.concat(validate2599.errors);
errors = vErrors.length;
}
var valid0 = _errs5 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.after !== undefined){
const _errs6 = errors;
if(!(validate2367(data.after, {instancePath:instancePath+"/after",parentData:data,parentDataProperty:"after",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2367.errors : vErrors.concat(validate2367.errors);
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
validate3198.errors = [{}];
return false;
}
}
validate3198.errors = vErrors;
return errors === 0;
}
validate3198.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate3197(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3197.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate3198(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3198.errors : vErrors.concat(validate3198.errors);
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
validate3197.errors = vErrors;
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
validate3197.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate3197.evaluated = {"dynamicProps":true,"dynamicItems":false};

const schema880 = {"anyOf":[{"$ref":"#/$defs/CatalogResponse/$defs/T36"},{"type":"null"}]};

function validate3206(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3206.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate2472(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2472.errors : vErrors.concat(validate2472.errors);
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
validate3206.errors = vErrors;
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
validate3206.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate3206.evaluated = {"dynamicProps":true,"dynamicItems":false};


function validate3191(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3191.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if(((((data.entries === undefined) && (missing0 = "entries")) || ((data.next === undefined) && (missing0 = "next"))) || ((data.snapshot === undefined) && (missing0 = "snapshot"))) || ((data.position === undefined) && (missing0 = "position"))){
validate3191.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((((key0 === "entries") || (key0 === "next")) || (key0 === "snapshot")) || (key0 === "position"))){
validate3191.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.entries !== undefined){
const _errs2 = errors;
if(!(validate3192(data.entries, {instancePath:instancePath+"/entries",parentData:data,parentDataProperty:"entries",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3192.errors : vErrors.concat(validate3192.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.next !== undefined){
const _errs3 = errors;
if(!(validate3197(data.next, {instancePath:instancePath+"/next",parentData:data,parentDataProperty:"next",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3197.errors : vErrors.concat(validate3197.errors);
errors = vErrors.length;
}
var valid0 = _errs3 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.snapshot !== undefined){
const _errs4 = errors;
if(!(validate3206(data.snapshot, {instancePath:instancePath+"/snapshot",parentData:data,parentDataProperty:"snapshot",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3206.errors : vErrors.concat(validate3206.errors);
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
if(!(validate3186(data.position, {instancePath:instancePath+"/position",parentData:data,parentDataProperty:"position",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3186.errors : vErrors.concat(validate3186.errors);
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
validate3191.errors = [{}];
return false;
}
}
validate3191.errors = vErrors;
return errors === 0;
}
validate3191.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate3051(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3051.evaluated;
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
if((data.definition === undefined) && (missing0 = "definition")){
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
const _errs3 = errors;
for(const key0 in data){
if(!(key0 === "definition")){
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
if(_errs3 === errors){
if(data.definition !== undefined){
if(!(validate3052(data.definition, {instancePath:instancePath+"/definition",parentData:data,parentDataProperty:"definition",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3052.errors : vErrors.concat(validate3052.errors);
errors = vErrors.length;
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
var _valid0 = _errs1 === errors;
if(_valid0){
valid0 = true;
passing0 = 0;
var props1 = true;
}
const _errs5 = errors;
if(errors === _errs5){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing1;
if((data.historical === undefined) && (missing1 = "historical")){
const err3 = {};
if(vErrors === null){
vErrors = [err3];
}
else {
vErrors.push(err3);
}
errors++;
}
else {
const _errs7 = errors;
for(const key1 in data){
if(!(key1 === "historical")){
const err4 = {};
if(vErrors === null){
vErrors = [err4];
}
else {
vErrors.push(err4);
}
errors++;
break;
}
}
if(_errs7 === errors){
if(data.historical !== undefined){
if(!(validate3184(data.historical, {instancePath:instancePath+"/historical",parentData:data,parentDataProperty:"historical",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3184.errors : vErrors.concat(validate3184.errors);
errors = vErrors.length;
}
}
}
}
}
else {
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
var _valid0 = _errs5 === errors;
if(_valid0 && valid0){
valid0 = false;
passing0 = [passing0, 1];
}
else {
if(_valid0){
valid0 = true;
passing0 = 1;
if(props1 !== true){
props1 = true;
}
}
const _errs9 = errors;
if(errors === _errs9){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing2;
if((data.page === undefined) && (missing2 = "page")){
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
const _errs11 = errors;
for(const key2 in data){
if(!(key2 === "page")){
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
if(_errs11 === errors){
if(data.page !== undefined){
if(!(validate3191(data.page, {instancePath:instancePath+"/page",parentData:data,parentDataProperty:"page",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3191.errors : vErrors.concat(validate3191.errors);
errors = vErrors.length;
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
var _valid0 = _errs9 === errors;
if(_valid0 && valid0){
valid0 = false;
passing0 = [passing0, 2];
}
else {
if(_valid0){
valid0 = true;
passing0 = 2;
if(props1 !== true){
props1 = true;
}
}
}
}
if(!valid0){
const err9 = {};
if(vErrors === null){
vErrors = [err9];
}
else {
vErrors.push(err9);
}
errors++;
validate3051.errors = vErrors;
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
validate3051.errors = vErrors;
evaluated0.props = props1;
return errors === 0;
}
validate3051.evaluated = {"dynamicProps":true,"dynamicItems":false};

const schema881 = {"type":"object","additionalProperties":false,"properties":{"entries":{"$ref":"#/$defs/CatalogResponse/$defs/T249"},"next":{"$ref":"#/$defs/CatalogResponse/$defs/T20"},"position":{"$ref":"#/$defs/CatalogResponse/$defs/T26"}},"required":["entries","next","position"]};
const schema882 = {"type":"array","minItems":8,"maxItems":8,"items":{"$ref":"#/$defs/CatalogResponse/$defs/T250"}};
const schema883 = {"anyOf":[{"$ref":"#/$defs/CatalogResponse/$defs/T251"},{"type":"null"}]};
const schema884 = {"type":"object","additionalProperties":false,"properties":{"definition":{"$ref":"#/$defs/CatalogResponse/$defs/T252"},"interpretation":{"$ref":"#/$defs/CatalogResponse/$defs/T31"},"position":{"$ref":"#/$defs/CatalogResponse/$defs/T26"}},"required":["definition","interpretation","position"]};
const schema885 = {"type":"object","additionalProperties":false,"properties":{"object":{"$ref":"#/$defs/CatalogResponse/$defs/T32"},"revision":{"$ref":"#/$defs/CatalogResponse/$defs/T11"},"namespace":{"$ref":"#/$defs/CatalogResponse/$defs/T10"},"name":{"$ref":"#/$defs/CatalogResponse/$defs/T11"},"authorization":{"$ref":"#/$defs/CatalogResponse/$defs/T10"},"resource":{"$ref":"#/$defs/CatalogResponse/$defs/T10"},"allocating_principal":{"$ref":"#/$defs/CatalogResponse/$defs/T10"},"allocation":{"$ref":"#/$defs/CatalogResponse/$defs/T253"},"creation":{"$ref":"#/$defs/CatalogResponse/$defs/T254"}},"required":["object","revision","namespace","name","authorization","resource","allocating_principal","allocation","creation"]};
const schema886 = {"type":"object","additionalProperties":false,"properties":{"sequence":{"$ref":"#/$defs/CatalogResponse/$defs/T10"}},"required":["sequence"]};

function validate3224(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3224.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((data.sequence === undefined) && (missing0 = "sequence")){
validate3224.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(key0 === "sequence")){
validate3224.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.sequence !== undefined){
if(!(validate2364(data.sequence, {instancePath:instancePath+"/sequence",parentData:data,parentDataProperty:"sequence",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2364.errors : vErrors.concat(validate2364.errors);
errors = vErrors.length;
}
}
}
}
}
else {
validate3224.errors = [{}];
return false;
}
}
validate3224.errors = vErrors;
return errors === 0;
}
validate3224.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema887 = {"type":"object","additionalProperties":false,"properties":{"namespace":{"$ref":"#/$defs/CatalogResponse/$defs/T10"},"name":{"$ref":"#/$defs/CatalogResponse/$defs/T11"},"owner":{"$ref":"#/$defs/CatalogResponse/$defs/T10"},"writer":{"$ref":"#/$defs/CatalogResponse/$defs/T10"},"owned":{"$ref":"#/$defs/CatalogResponse/$defs/T17"},"deadline_ms":{"$ref":"#/$defs/CatalogResponse/$defs/T23"},"history_ms":{"$ref":"#/$defs/CatalogResponse/$defs/T23"},"spec":{"$ref":"#/$defs/CatalogResponse/$defs/T255"}},"required":["namespace","name","owner","writer","owned","deadline_ms","history_ms","spec"]};
const schema888 = {"oneOf":[{"type":"object","additionalProperties":false,"required":["document"],"properties":{"document":{"$ref":"#/$defs/CatalogResponse/$defs/T256"}}}]};
const schema889 = {"type":"object","additionalProperties":false,"properties":{"document":{"$ref":"#/$defs/CatalogResponse/$defs/T11"},"type_revision":{"$ref":"#/$defs/CatalogResponse/$defs/T6"},"limits":{"$ref":"#/$defs/CatalogResponse/$defs/T257"}},"required":["document","type_revision","limits"]};
const schema890 = {"type":"object","additionalProperties":false,"properties":{"record_bytes":{"$ref":"#/$defs/CatalogResponse/$defs/T6"},"staging_bytes":{"$ref":"#/$defs/CatalogResponse/$defs/T11"},"staging_records":{"$ref":"#/$defs/CatalogResponse/$defs/T6"}},"required":["record_bytes","staging_bytes","staging_records"]};

function validate3239(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3239.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((((data.record_bytes === undefined) && (missing0 = "record_bytes")) || ((data.staging_bytes === undefined) && (missing0 = "staging_bytes"))) || ((data.staging_records === undefined) && (missing0 = "staging_records"))){
validate3239.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "record_bytes") || (key0 === "staging_bytes")) || (key0 === "staging_records"))){
validate3239.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.record_bytes !== undefined){
const _errs2 = errors;
if(!(validate2355(data.record_bytes, {instancePath:instancePath+"/record_bytes",parentData:data,parentDataProperty:"record_bytes",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2355.errors : vErrors.concat(validate2355.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.staging_bytes !== undefined){
const _errs3 = errors;
if(!(validate2367(data.staging_bytes, {instancePath:instancePath+"/staging_bytes",parentData:data,parentDataProperty:"staging_bytes",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2367.errors : vErrors.concat(validate2367.errors);
errors = vErrors.length;
}
var valid0 = _errs3 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.staging_records !== undefined){
const _errs4 = errors;
if(!(validate2355(data.staging_records, {instancePath:instancePath+"/staging_records",parentData:data,parentDataProperty:"staging_records",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2355.errors : vErrors.concat(validate2355.errors);
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
validate3239.errors = [{}];
return false;
}
}
validate3239.errors = vErrors;
return errors === 0;
}
validate3239.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate3236(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3236.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((((data.document === undefined) && (missing0 = "document")) || ((data.type_revision === undefined) && (missing0 = "type_revision"))) || ((data.limits === undefined) && (missing0 = "limits"))){
validate3236.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "document") || (key0 === "type_revision")) || (key0 === "limits"))){
validate3236.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.document !== undefined){
const _errs2 = errors;
if(!(validate2367(data.document, {instancePath:instancePath+"/document",parentData:data,parentDataProperty:"document",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2367.errors : vErrors.concat(validate2367.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.type_revision !== undefined){
const _errs3 = errors;
if(!(validate2355(data.type_revision, {instancePath:instancePath+"/type_revision",parentData:data,parentDataProperty:"type_revision",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2355.errors : vErrors.concat(validate2355.errors);
errors = vErrors.length;
}
var valid0 = _errs3 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.limits !== undefined){
const _errs4 = errors;
if(!(validate3239(data.limits, {instancePath:instancePath+"/limits",parentData:data,parentDataProperty:"limits",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3239.errors : vErrors.concat(validate3239.errors);
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
validate3236.errors = [{}];
return false;
}
}
validate3236.errors = vErrors;
return errors === 0;
}
validate3236.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate3235(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3235.evaluated;
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
if((data.document === undefined) && (missing0 = "document")){
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
const _errs3 = errors;
for(const key0 in data){
if(!(key0 === "document")){
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
if(_errs3 === errors){
if(data.document !== undefined){
if(!(validate3236(data.document, {instancePath:instancePath+"/document",parentData:data,parentDataProperty:"document",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3236.errors : vErrors.concat(validate3236.errors);
errors = vErrors.length;
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
var _valid0 = _errs1 === errors;
if(_valid0){
valid0 = true;
passing0 = 0;
var props0 = true;
}
if(!valid0){
const err3 = {};
if(vErrors === null){
vErrors = [err3];
}
else {
vErrors.push(err3);
}
errors++;
validate3235.errors = vErrors;
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
validate3235.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate3235.evaluated = {"dynamicProps":true,"dynamicItems":false};


function validate3227(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3227.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if(((((((((data.namespace === undefined) && (missing0 = "namespace")) || ((data.name === undefined) && (missing0 = "name"))) || ((data.owner === undefined) && (missing0 = "owner"))) || ((data.writer === undefined) && (missing0 = "writer"))) || ((data.owned === undefined) && (missing0 = "owned"))) || ((data.deadline_ms === undefined) && (missing0 = "deadline_ms"))) || ((data.history_ms === undefined) && (missing0 = "history_ms"))) || ((data.spec === undefined) && (missing0 = "spec"))){
validate3227.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((((((((key0 === "namespace") || (key0 === "name")) || (key0 === "owner")) || (key0 === "writer")) || (key0 === "owned")) || (key0 === "deadline_ms")) || (key0 === "history_ms")) || (key0 === "spec"))){
validate3227.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.namespace !== undefined){
const _errs2 = errors;
if(!(validate2364(data.namespace, {instancePath:instancePath+"/namespace",parentData:data,parentDataProperty:"namespace",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2364.errors : vErrors.concat(validate2364.errors);
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
if(!(validate2367(data.name, {instancePath:instancePath+"/name",parentData:data,parentDataProperty:"name",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2367.errors : vErrors.concat(validate2367.errors);
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
if(!(validate2364(data.owner, {instancePath:instancePath+"/owner",parentData:data,parentDataProperty:"owner",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2364.errors : vErrors.concat(validate2364.errors);
errors = vErrors.length;
}
var valid0 = _errs4 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.writer !== undefined){
const _errs5 = errors;
if(!(validate2364(data.writer, {instancePath:instancePath+"/writer",parentData:data,parentDataProperty:"writer",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2364.errors : vErrors.concat(validate2364.errors);
errors = vErrors.length;
}
var valid0 = _errs5 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.owned !== undefined){
const _errs6 = errors;
if(!(validate2409(data.owned, {instancePath:instancePath+"/owned",parentData:data,parentDataProperty:"owned",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2409.errors : vErrors.concat(validate2409.errors);
errors = vErrors.length;
}
var valid0 = _errs6 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.deadline_ms !== undefined){
const _errs7 = errors;
if(!(validate2425(data.deadline_ms, {instancePath:instancePath+"/deadline_ms",parentData:data,parentDataProperty:"deadline_ms",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2425.errors : vErrors.concat(validate2425.errors);
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
if(!(validate2425(data.history_ms, {instancePath:instancePath+"/history_ms",parentData:data,parentDataProperty:"history_ms",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2425.errors : vErrors.concat(validate2425.errors);
errors = vErrors.length;
}
var valid0 = _errs8 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.spec !== undefined){
const _errs9 = errors;
if(!(validate3235(data.spec, {instancePath:instancePath+"/spec",parentData:data,parentDataProperty:"spec",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3235.errors : vErrors.concat(validate3235.errors);
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
validate3227.errors = [{}];
return false;
}
}
validate3227.errors = vErrors;
return errors === 0;
}
validate3227.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate3216(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3216.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((((((((((data.object === undefined) && (missing0 = "object")) || ((data.revision === undefined) && (missing0 = "revision"))) || ((data.namespace === undefined) && (missing0 = "namespace"))) || ((data.name === undefined) && (missing0 = "name"))) || ((data.authorization === undefined) && (missing0 = "authorization"))) || ((data.resource === undefined) && (missing0 = "resource"))) || ((data.allocating_principal === undefined) && (missing0 = "allocating_principal"))) || ((data.allocation === undefined) && (missing0 = "allocation"))) || ((data.creation === undefined) && (missing0 = "creation"))){
validate3216.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(func1.call(schema885.properties, key0))){
validate3216.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.object !== undefined){
const _errs2 = errors;
if(!(validate2449(data.object, {instancePath:instancePath+"/object",parentData:data,parentDataProperty:"object",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2449.errors : vErrors.concat(validate2449.errors);
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
if(!(validate2367(data.revision, {instancePath:instancePath+"/revision",parentData:data,parentDataProperty:"revision",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2367.errors : vErrors.concat(validate2367.errors);
errors = vErrors.length;
}
var valid0 = _errs3 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.namespace !== undefined){
const _errs4 = errors;
if(!(validate2364(data.namespace, {instancePath:instancePath+"/namespace",parentData:data,parentDataProperty:"namespace",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2364.errors : vErrors.concat(validate2364.errors);
errors = vErrors.length;
}
var valid0 = _errs4 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.name !== undefined){
const _errs5 = errors;
if(!(validate2367(data.name, {instancePath:instancePath+"/name",parentData:data,parentDataProperty:"name",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2367.errors : vErrors.concat(validate2367.errors);
errors = vErrors.length;
}
var valid0 = _errs5 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.authorization !== undefined){
const _errs6 = errors;
if(!(validate2364(data.authorization, {instancePath:instancePath+"/authorization",parentData:data,parentDataProperty:"authorization",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2364.errors : vErrors.concat(validate2364.errors);
errors = vErrors.length;
}
var valid0 = _errs6 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.resource !== undefined){
const _errs7 = errors;
if(!(validate2364(data.resource, {instancePath:instancePath+"/resource",parentData:data,parentDataProperty:"resource",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2364.errors : vErrors.concat(validate2364.errors);
errors = vErrors.length;
}
var valid0 = _errs7 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.allocating_principal !== undefined){
const _errs8 = errors;
if(!(validate2364(data.allocating_principal, {instancePath:instancePath+"/allocating_principal",parentData:data,parentDataProperty:"allocating_principal",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2364.errors : vErrors.concat(validate2364.errors);
errors = vErrors.length;
}
var valid0 = _errs8 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.allocation !== undefined){
const _errs9 = errors;
if(!(validate3224(data.allocation, {instancePath:instancePath+"/allocation",parentData:data,parentDataProperty:"allocation",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3224.errors : vErrors.concat(validate3224.errors);
errors = vErrors.length;
}
var valid0 = _errs9 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.creation !== undefined){
const _errs10 = errors;
if(!(validate3227(data.creation, {instancePath:instancePath+"/creation",parentData:data,parentDataProperty:"creation",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3227.errors : vErrors.concat(validate3227.errors);
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
validate3216.errors = [{}];
return false;
}
}
validate3216.errors = vErrors;
return errors === 0;
}
validate3216.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate3215(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3215.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((((data.definition === undefined) && (missing0 = "definition")) || ((data.interpretation === undefined) && (missing0 = "interpretation"))) || ((data.position === undefined) && (missing0 = "position"))){
validate3215.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "definition") || (key0 === "interpretation")) || (key0 === "position"))){
validate3215.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.definition !== undefined){
const _errs2 = errors;
if(!(validate3216(data.definition, {instancePath:instancePath+"/definition",parentData:data,parentDataProperty:"definition",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3216.errors : vErrors.concat(validate3216.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.interpretation !== undefined){
const _errs3 = errors;
if(!(validate2448(data.interpretation, {instancePath:instancePath+"/interpretation",parentData:data,parentDataProperty:"interpretation",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2448.errors : vErrors.concat(validate2448.errors);
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
if(!(validate2435(data.position, {instancePath:instancePath+"/position",parentData:data,parentDataProperty:"position",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2435.errors : vErrors.concat(validate2435.errors);
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
validate3215.errors = [{}];
return false;
}
}
validate3215.errors = vErrors;
return errors === 0;
}
validate3215.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate3214(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3214.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate3215(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3215.errors : vErrors.concat(validate3215.errors);
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
validate3214.errors = vErrors;
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
validate3214.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate3214.evaluated = {"dynamicProps":true,"dynamicItems":false};


function validate3213(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3213.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(Array.isArray(data)){
if(data.length > 8){
validate3213.errors = [{}];
return false;
}
else {
if(data.length < 8){
validate3213.errors = [{}];
return false;
}
else {
var valid0 = true;
const len0 = data.length;
for(let i0=0; i0<len0; i0++){
const _errs1 = errors;
if(!(validate3214(data[i0], {instancePath:instancePath+"/" + i0,parentData:data,parentDataProperty:i0,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3214.errors : vErrors.concat(validate3214.errors);
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
validate3213.errors = [{}];
return false;
}
}
validate3213.errors = vErrors;
return errors === 0;
}
validate3213.evaluated = {"items":true,"dynamicProps":false,"dynamicItems":false};


function validate3212(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3212.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((((data.entries === undefined) && (missing0 = "entries")) || ((data.next === undefined) && (missing0 = "next"))) || ((data.position === undefined) && (missing0 = "position"))){
validate3212.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "entries") || (key0 === "next")) || (key0 === "position"))){
validate3212.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.entries !== undefined){
const _errs2 = errors;
if(!(validate3213(data.entries, {instancePath:instancePath+"/entries",parentData:data,parentDataProperty:"entries",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3213.errors : vErrors.concat(validate3213.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.next !== undefined){
const _errs3 = errors;
if(!(validate2417(data.next, {instancePath:instancePath+"/next",parentData:data,parentDataProperty:"next",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2417.errors : vErrors.concat(validate2417.errors);
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
if(!(validate2435(data.position, {instancePath:instancePath+"/position",parentData:data,parentDataProperty:"position",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2435.errors : vErrors.concat(validate2435.errors);
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
validate3212.errors = [{}];
return false;
}
}
validate3212.errors = vErrors;
return errors === 0;
}
validate3212.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema891 = {"type":"object","additionalProperties":false,"properties":{"metadata":{"$ref":"#/$defs/CatalogResponse/$defs/T259"},"preview_sql":{"$ref":"#/$defs/CatalogResponse/$defs/T11"},"expected_definition":{"$ref":"#/$defs/CatalogResponse/$defs/T11"}},"required":["metadata","preview_sql","expected_definition"]};
const schema892 = {"type":"object","additionalProperties":false,"properties":{"binding":{"$ref":"#/$defs/CatalogResponse/$defs/T260"},"authorization":{"$ref":"#/$defs/CatalogResponse/$defs/T10"},"position":{"$ref":"#/$defs/CatalogResponse/$defs/T26"},"changed_lsn":{"$ref":"#/$defs/CatalogResponse/$defs/T11"},"row_count":{"$ref":"#/$defs/CatalogResponse/$defs/T11"},"schema":{"$ref":"#/$defs/CatalogResponse/$defs/T85"}},"required":["binding","authorization","position","changed_lsn","row_count","schema"]};
const schema893 = {"type":"object","additionalProperties":false,"properties":{"definition":{"$ref":"#/$defs/CatalogResponse/$defs/T4"},"connection":{"$ref":"#/$defs/CatalogResponse/$defs/T22"},"namespace":{"$ref":"#/$defs/CatalogResponse/$defs/T10"},"name":{"$ref":"#/$defs/CatalogResponse/$defs/T11"},"interpretation":{"$ref":"#/$defs/CatalogResponse/$defs/T41"}},"required":["definition","connection","namespace","name","interpretation"]};

function validate3258(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3258.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((((((data.definition === undefined) && (missing0 = "definition")) || ((data.connection === undefined) && (missing0 = "connection"))) || ((data.namespace === undefined) && (missing0 = "namespace"))) || ((data.name === undefined) && (missing0 = "name"))) || ((data.interpretation === undefined) && (missing0 = "interpretation"))){
validate3258.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((((key0 === "definition") || (key0 === "connection")) || (key0 === "namespace")) || (key0 === "name")) || (key0 === "interpretation"))){
validate3258.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.definition !== undefined){
const _errs2 = errors;
if(!(validate2349(data.definition, {instancePath:instancePath+"/definition",parentData:data,parentDataProperty:"definition",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2349.errors : vErrors.concat(validate2349.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.connection !== undefined){
const _errs3 = errors;
if(!(validate2420(data.connection, {instancePath:instancePath+"/connection",parentData:data,parentDataProperty:"connection",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2420.errors : vErrors.concat(validate2420.errors);
errors = vErrors.length;
}
var valid0 = _errs3 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.namespace !== undefined){
const _errs4 = errors;
if(!(validate2364(data.namespace, {instancePath:instancePath+"/namespace",parentData:data,parentDataProperty:"namespace",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2364.errors : vErrors.concat(validate2364.errors);
errors = vErrors.length;
}
var valid0 = _errs4 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.name !== undefined){
const _errs5 = errors;
if(!(validate2367(data.name, {instancePath:instancePath+"/name",parentData:data,parentDataProperty:"name",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2367.errors : vErrors.concat(validate2367.errors);
errors = vErrors.length;
}
var valid0 = _errs5 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.interpretation !== undefined){
const _errs6 = errors;
if(!(validate2498(data.interpretation, {instancePath:instancePath+"/interpretation",parentData:data,parentDataProperty:"interpretation",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2498.errors : vErrors.concat(validate2498.errors);
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
validate3258.errors = [{}];
return false;
}
}
validate3258.errors = vErrors;
return errors === 0;
}
validate3258.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate3257(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3257.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if(((((((data.binding === undefined) && (missing0 = "binding")) || ((data.authorization === undefined) && (missing0 = "authorization"))) || ((data.position === undefined) && (missing0 = "position"))) || ((data.changed_lsn === undefined) && (missing0 = "changed_lsn"))) || ((data.row_count === undefined) && (missing0 = "row_count"))) || ((data.schema === undefined) && (missing0 = "schema"))){
validate3257.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((((((key0 === "binding") || (key0 === "authorization")) || (key0 === "position")) || (key0 === "changed_lsn")) || (key0 === "row_count")) || (key0 === "schema"))){
validate3257.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.binding !== undefined){
const _errs2 = errors;
if(!(validate3258(data.binding, {instancePath:instancePath+"/binding",parentData:data,parentDataProperty:"binding",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3258.errors : vErrors.concat(validate3258.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.authorization !== undefined){
const _errs3 = errors;
if(!(validate2364(data.authorization, {instancePath:instancePath+"/authorization",parentData:data,parentDataProperty:"authorization",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2364.errors : vErrors.concat(validate2364.errors);
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
if(!(validate2435(data.position, {instancePath:instancePath+"/position",parentData:data,parentDataProperty:"position",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2435.errors : vErrors.concat(validate2435.errors);
errors = vErrors.length;
}
var valid0 = _errs4 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.changed_lsn !== undefined){
const _errs5 = errors;
if(!(validate2367(data.changed_lsn, {instancePath:instancePath+"/changed_lsn",parentData:data,parentDataProperty:"changed_lsn",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2367.errors : vErrors.concat(validate2367.errors);
errors = vErrors.length;
}
var valid0 = _errs5 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.row_count !== undefined){
const _errs6 = errors;
if(!(validate2367(data.row_count, {instancePath:instancePath+"/row_count",parentData:data,parentDataProperty:"row_count",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2367.errors : vErrors.concat(validate2367.errors);
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
if(!(validate2654(data.schema, {instancePath:instancePath+"/schema",parentData:data,parentDataProperty:"schema",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2654.errors : vErrors.concat(validate2654.errors);
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
validate3257.errors = [{}];
return false;
}
}
validate3257.errors = vErrors;
return errors === 0;
}
validate3257.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate3256(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3256.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((((data.metadata === undefined) && (missing0 = "metadata")) || ((data.preview_sql === undefined) && (missing0 = "preview_sql"))) || ((data.expected_definition === undefined) && (missing0 = "expected_definition"))){
validate3256.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "metadata") || (key0 === "preview_sql")) || (key0 === "expected_definition"))){
validate3256.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.metadata !== undefined){
const _errs2 = errors;
if(!(validate3257(data.metadata, {instancePath:instancePath+"/metadata",parentData:data,parentDataProperty:"metadata",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3257.errors : vErrors.concat(validate3257.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.preview_sql !== undefined){
const _errs3 = errors;
if(!(validate2367(data.preview_sql, {instancePath:instancePath+"/preview_sql",parentData:data,parentDataProperty:"preview_sql",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2367.errors : vErrors.concat(validate2367.errors);
errors = vErrors.length;
}
var valid0 = _errs3 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.expected_definition !== undefined){
const _errs4 = errors;
if(!(validate2367(data.expected_definition, {instancePath:instancePath+"/expected_definition",parentData:data,parentDataProperty:"expected_definition",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2367.errors : vErrors.concat(validate2367.errors);
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
validate3256.errors = [{}];
return false;
}
}
validate3256.errors = vErrors;
return errors === 0;
}
validate3256.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema894 = {"type":"object","additionalProperties":false,"properties":{"binding":{"$ref":"#/$defs/CatalogResponse/$defs/T260"},"observed":{"$ref":"#/$defs/CatalogResponse/$defs/T262"}},"required":["binding","observed"]};
const schema895 = {"type":"object","additionalProperties":false,"properties":{"position":{"$ref":"#/$defs/CatalogResponse/$defs/T26"},"changed_lsn":{"$ref":"#/$defs/CatalogResponse/$defs/T11"},"live_rows":{"$ref":"#/$defs/CatalogResponse/$defs/T11"},"pending_rows":{"$ref":"#/$defs/CatalogResponse/$defs/T11"},"pending_bytes":{"$ref":"#/$defs/CatalogResponse/$defs/T11"},"pending_complete":{"$ref":"#/$defs/CatalogResponse/$defs/T17"},"oldest_pending_lsn":{"$ref":"#/$defs/CatalogResponse/$defs/T72"},"archive_through":{"$ref":"#/$defs/CatalogResponse/$defs/T11"},"recovery_through":{"$ref":"#/$defs/CatalogResponse/$defs/T72"},"history_floor":{"$ref":"#/$defs/CatalogResponse/$defs/T11"},"next_segment":{"$ref":"#/$defs/CatalogResponse/$defs/T11"},"archive_source_lsn":{"$ref":"#/$defs/CatalogResponse/$defs/T11"},"archived_source_lsn":{"$ref":"#/$defs/CatalogResponse/$defs/T11"},"archive_target_source_lsn":{"$ref":"#/$defs/CatalogResponse/$defs/T72"},"archive_target_through_lsn":{"$ref":"#/$defs/CatalogResponse/$defs/T72"},"compaction_source_lsn":{"$ref":"#/$defs/CatalogResponse/$defs/T11"},"compacted_source_lsn":{"$ref":"#/$defs/CatalogResponse/$defs/T11"},"compaction_target_source_lsn":{"$ref":"#/$defs/CatalogResponse/$defs/T72"},"compaction_target_before_segment":{"$ref":"#/$defs/CatalogResponse/$defs/T72"},"compaction_target_after_segment":{"$ref":"#/$defs/CatalogResponse/$defs/T72"}},"required":["position","changed_lsn","live_rows","pending_rows","pending_bytes","pending_complete","oldest_pending_lsn","archive_through","recovery_through","history_floor","next_segment","archive_source_lsn","archived_source_lsn","archive_target_source_lsn","archive_target_through_lsn","compaction_source_lsn","compacted_source_lsn","compaction_target_source_lsn","compaction_target_before_segment","compaction_target_after_segment"]};

function validate3276(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3276.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if(((((((((((((((((((((data.position === undefined) && (missing0 = "position")) || ((data.changed_lsn === undefined) && (missing0 = "changed_lsn"))) || ((data.live_rows === undefined) && (missing0 = "live_rows"))) || ((data.pending_rows === undefined) && (missing0 = "pending_rows"))) || ((data.pending_bytes === undefined) && (missing0 = "pending_bytes"))) || ((data.pending_complete === undefined) && (missing0 = "pending_complete"))) || ((data.oldest_pending_lsn === undefined) && (missing0 = "oldest_pending_lsn"))) || ((data.archive_through === undefined) && (missing0 = "archive_through"))) || ((data.recovery_through === undefined) && (missing0 = "recovery_through"))) || ((data.history_floor === undefined) && (missing0 = "history_floor"))) || ((data.next_segment === undefined) && (missing0 = "next_segment"))) || ((data.archive_source_lsn === undefined) && (missing0 = "archive_source_lsn"))) || ((data.archived_source_lsn === undefined) && (missing0 = "archived_source_lsn"))) || ((data.archive_target_source_lsn === undefined) && (missing0 = "archive_target_source_lsn"))) || ((data.archive_target_through_lsn === undefined) && (missing0 = "archive_target_through_lsn"))) || ((data.compaction_source_lsn === undefined) && (missing0 = "compaction_source_lsn"))) || ((data.compacted_source_lsn === undefined) && (missing0 = "compacted_source_lsn"))) || ((data.compaction_target_source_lsn === undefined) && (missing0 = "compaction_target_source_lsn"))) || ((data.compaction_target_before_segment === undefined) && (missing0 = "compaction_target_before_segment"))) || ((data.compaction_target_after_segment === undefined) && (missing0 = "compaction_target_after_segment"))){
validate3276.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(func1.call(schema895.properties, key0))){
validate3276.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.position !== undefined){
const _errs2 = errors;
if(!(validate2435(data.position, {instancePath:instancePath+"/position",parentData:data,parentDataProperty:"position",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2435.errors : vErrors.concat(validate2435.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.changed_lsn !== undefined){
const _errs3 = errors;
if(!(validate2367(data.changed_lsn, {instancePath:instancePath+"/changed_lsn",parentData:data,parentDataProperty:"changed_lsn",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2367.errors : vErrors.concat(validate2367.errors);
errors = vErrors.length;
}
var valid0 = _errs3 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.live_rows !== undefined){
const _errs4 = errors;
if(!(validate2367(data.live_rows, {instancePath:instancePath+"/live_rows",parentData:data,parentDataProperty:"live_rows",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2367.errors : vErrors.concat(validate2367.errors);
errors = vErrors.length;
}
var valid0 = _errs4 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.pending_rows !== undefined){
const _errs5 = errors;
if(!(validate2367(data.pending_rows, {instancePath:instancePath+"/pending_rows",parentData:data,parentDataProperty:"pending_rows",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2367.errors : vErrors.concat(validate2367.errors);
errors = vErrors.length;
}
var valid0 = _errs5 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.pending_bytes !== undefined){
const _errs6 = errors;
if(!(validate2367(data.pending_bytes, {instancePath:instancePath+"/pending_bytes",parentData:data,parentDataProperty:"pending_bytes",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2367.errors : vErrors.concat(validate2367.errors);
errors = vErrors.length;
}
var valid0 = _errs6 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.pending_complete !== undefined){
const _errs7 = errors;
if(!(validate2409(data.pending_complete, {instancePath:instancePath+"/pending_complete",parentData:data,parentDataProperty:"pending_complete",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2409.errors : vErrors.concat(validate2409.errors);
errors = vErrors.length;
}
var valid0 = _errs7 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.oldest_pending_lsn !== undefined){
const _errs8 = errors;
if(!(validate2599(data.oldest_pending_lsn, {instancePath:instancePath+"/oldest_pending_lsn",parentData:data,parentDataProperty:"oldest_pending_lsn",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2599.errors : vErrors.concat(validate2599.errors);
errors = vErrors.length;
}
var valid0 = _errs8 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.archive_through !== undefined){
const _errs9 = errors;
if(!(validate2367(data.archive_through, {instancePath:instancePath+"/archive_through",parentData:data,parentDataProperty:"archive_through",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2367.errors : vErrors.concat(validate2367.errors);
errors = vErrors.length;
}
var valid0 = _errs9 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.recovery_through !== undefined){
const _errs10 = errors;
if(!(validate2599(data.recovery_through, {instancePath:instancePath+"/recovery_through",parentData:data,parentDataProperty:"recovery_through",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2599.errors : vErrors.concat(validate2599.errors);
errors = vErrors.length;
}
var valid0 = _errs10 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.history_floor !== undefined){
const _errs11 = errors;
if(!(validate2367(data.history_floor, {instancePath:instancePath+"/history_floor",parentData:data,parentDataProperty:"history_floor",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2367.errors : vErrors.concat(validate2367.errors);
errors = vErrors.length;
}
var valid0 = _errs11 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.next_segment !== undefined){
const _errs12 = errors;
if(!(validate2367(data.next_segment, {instancePath:instancePath+"/next_segment",parentData:data,parentDataProperty:"next_segment",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2367.errors : vErrors.concat(validate2367.errors);
errors = vErrors.length;
}
var valid0 = _errs12 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.archive_source_lsn !== undefined){
const _errs13 = errors;
if(!(validate2367(data.archive_source_lsn, {instancePath:instancePath+"/archive_source_lsn",parentData:data,parentDataProperty:"archive_source_lsn",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2367.errors : vErrors.concat(validate2367.errors);
errors = vErrors.length;
}
var valid0 = _errs13 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.archived_source_lsn !== undefined){
const _errs14 = errors;
if(!(validate2367(data.archived_source_lsn, {instancePath:instancePath+"/archived_source_lsn",parentData:data,parentDataProperty:"archived_source_lsn",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2367.errors : vErrors.concat(validate2367.errors);
errors = vErrors.length;
}
var valid0 = _errs14 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.archive_target_source_lsn !== undefined){
const _errs15 = errors;
if(!(validate2599(data.archive_target_source_lsn, {instancePath:instancePath+"/archive_target_source_lsn",parentData:data,parentDataProperty:"archive_target_source_lsn",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2599.errors : vErrors.concat(validate2599.errors);
errors = vErrors.length;
}
var valid0 = _errs15 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.archive_target_through_lsn !== undefined){
const _errs16 = errors;
if(!(validate2599(data.archive_target_through_lsn, {instancePath:instancePath+"/archive_target_through_lsn",parentData:data,parentDataProperty:"archive_target_through_lsn",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2599.errors : vErrors.concat(validate2599.errors);
errors = vErrors.length;
}
var valid0 = _errs16 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.compaction_source_lsn !== undefined){
const _errs17 = errors;
if(!(validate2367(data.compaction_source_lsn, {instancePath:instancePath+"/compaction_source_lsn",parentData:data,parentDataProperty:"compaction_source_lsn",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2367.errors : vErrors.concat(validate2367.errors);
errors = vErrors.length;
}
var valid0 = _errs17 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.compacted_source_lsn !== undefined){
const _errs18 = errors;
if(!(validate2367(data.compacted_source_lsn, {instancePath:instancePath+"/compacted_source_lsn",parentData:data,parentDataProperty:"compacted_source_lsn",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2367.errors : vErrors.concat(validate2367.errors);
errors = vErrors.length;
}
var valid0 = _errs18 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.compaction_target_source_lsn !== undefined){
const _errs19 = errors;
if(!(validate2599(data.compaction_target_source_lsn, {instancePath:instancePath+"/compaction_target_source_lsn",parentData:data,parentDataProperty:"compaction_target_source_lsn",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2599.errors : vErrors.concat(validate2599.errors);
errors = vErrors.length;
}
var valid0 = _errs19 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.compaction_target_before_segment !== undefined){
const _errs20 = errors;
if(!(validate2599(data.compaction_target_before_segment, {instancePath:instancePath+"/compaction_target_before_segment",parentData:data,parentDataProperty:"compaction_target_before_segment",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2599.errors : vErrors.concat(validate2599.errors);
errors = vErrors.length;
}
var valid0 = _errs20 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.compaction_target_after_segment !== undefined){
const _errs21 = errors;
if(!(validate2599(data.compaction_target_after_segment, {instancePath:instancePath+"/compaction_target_after_segment",parentData:data,parentDataProperty:"compaction_target_after_segment",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2599.errors : vErrors.concat(validate2599.errors);
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
}
}
}
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
validate3276.errors = [{}];
return false;
}
}
validate3276.errors = vErrors;
return errors === 0;
}
validate3276.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate3274(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3274.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if(((data.binding === undefined) && (missing0 = "binding")) || ((data.observed === undefined) && (missing0 = "observed"))){
validate3274.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "binding") || (key0 === "observed"))){
validate3274.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.binding !== undefined){
const _errs2 = errors;
if(!(validate3258(data.binding, {instancePath:instancePath+"/binding",parentData:data,parentDataProperty:"binding",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3258.errors : vErrors.concat(validate3258.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.observed !== undefined){
const _errs3 = errors;
if(!(validate3276(data.observed, {instancePath:instancePath+"/observed",parentData:data,parentDataProperty:"observed",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3276.errors : vErrors.concat(validate3276.errors);
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
validate3274.errors = [{}];
return false;
}
}
validate3274.errors = vErrors;
return errors === 0;
}
validate3274.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema896 = {"type":"object","additionalProperties":false,"properties":{"entries":{"$ref":"#/$defs/CatalogResponse/$defs/T264"},"next":{"$ref":"#/$defs/CatalogResponse/$defs/T271"},"position":{"$ref":"#/$defs/CatalogResponse/$defs/T26"}},"required":["entries","next","position"]};
const schema897 = {"type":"array","minItems":4,"maxItems":4,"items":{"$ref":"#/$defs/CatalogResponse/$defs/T265"}};
const schema898 = {"anyOf":[{"$ref":"#/$defs/CatalogResponse/$defs/T266"},{"type":"null"}]};
const schema899 = {"type":"object","additionalProperties":false,"properties":{"source":{"$ref":"#/$defs/CatalogResponse/$defs/T31"},"dependent":{"$ref":"#/$defs/CatalogResponse/$defs/T267"},"privileges":{"$ref":"#/$defs/CatalogResponse/$defs/T10"},"foreign_key":{"$ref":"#/$defs/CatalogResponse/$defs/T269"}},"required":["source","dependent","privileges","foreign_key"]};
const schema900 = {"type":"object","additionalProperties":false,"properties":{"kind":{"$ref":"#/$defs/CatalogResponse/$defs/T268"},"interpretation":{"$ref":"#/$defs/CatalogResponse/$defs/T31"}},"required":["kind","interpretation"]};
const schema901 = {"type":"string","enum":["kv","document","captured","maintained","stream","queue","table","view","property_graph","foreign","managed","source","application","sink"]};

function validate3305(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3305.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate3305.errors = [{}];
return false;
}
if(!((((((((((((((data === "kv") || (data === "document")) || (data === "captured")) || (data === "maintained")) || (data === "stream")) || (data === "queue")) || (data === "table")) || (data === "view")) || (data === "property_graph")) || (data === "foreign")) || (data === "managed")) || (data === "source")) || (data === "application")) || (data === "sink"))){
validate3305.errors = [{}];
return false;
}
validate3305.errors = vErrors;
return errors === 0;
}
validate3305.evaluated = {"dynamicProps":false,"dynamicItems":false};


function validate3304(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3304.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if(((data.kind === undefined) && (missing0 = "kind")) || ((data.interpretation === undefined) && (missing0 = "interpretation"))){
validate3304.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "kind") || (key0 === "interpretation"))){
validate3304.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.kind !== undefined){
const _errs2 = errors;
if(!(validate3305(data.kind, {instancePath:instancePath+"/kind",parentData:data,parentDataProperty:"kind",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3305.errors : vErrors.concat(validate3305.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.interpretation !== undefined){
const _errs3 = errors;
if(!(validate2448(data.interpretation, {instancePath:instancePath+"/interpretation",parentData:data,parentDataProperty:"interpretation",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2448.errors : vErrors.concat(validate2448.errors);
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
validate3304.errors = [{}];
return false;
}
}
validate3304.errors = vErrors;
return errors === 0;
}
validate3304.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema902 = {"anyOf":[{"$ref":"#/$defs/CatalogResponse/$defs/T270"},{"type":"null"}]};
const schema903 = {"type":"object","additionalProperties":false,"properties":{"constraint":{"$ref":"#/$defs/CatalogResponse/$defs/T6"},"column":{"$ref":"#/$defs/CatalogResponse/$defs/T11"}},"required":["constraint","column"]};

function validate3311(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3311.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if(((data.constraint === undefined) && (missing0 = "constraint")) || ((data.column === undefined) && (missing0 = "column"))){
validate3311.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "constraint") || (key0 === "column"))){
validate3311.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.constraint !== undefined){
const _errs2 = errors;
if(!(validate2355(data.constraint, {instancePath:instancePath+"/constraint",parentData:data,parentDataProperty:"constraint",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2355.errors : vErrors.concat(validate2355.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.column !== undefined){
const _errs3 = errors;
if(!(validate2367(data.column, {instancePath:instancePath+"/column",parentData:data,parentDataProperty:"column",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2367.errors : vErrors.concat(validate2367.errors);
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
validate3311.errors = [{}];
return false;
}
}
validate3311.errors = vErrors;
return errors === 0;
}
validate3311.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate3310(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3310.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate3311(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3311.errors : vErrors.concat(validate3311.errors);
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
validate3310.errors = vErrors;
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
validate3310.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate3310.evaluated = {"dynamicProps":true,"dynamicItems":false};


function validate3302(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3302.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if(((((data.source === undefined) && (missing0 = "source")) || ((data.dependent === undefined) && (missing0 = "dependent"))) || ((data.privileges === undefined) && (missing0 = "privileges"))) || ((data.foreign_key === undefined) && (missing0 = "foreign_key"))){
validate3302.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((((key0 === "source") || (key0 === "dependent")) || (key0 === "privileges")) || (key0 === "foreign_key"))){
validate3302.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.source !== undefined){
const _errs2 = errors;
if(!(validate2448(data.source, {instancePath:instancePath+"/source",parentData:data,parentDataProperty:"source",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2448.errors : vErrors.concat(validate2448.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.dependent !== undefined){
const _errs3 = errors;
if(!(validate3304(data.dependent, {instancePath:instancePath+"/dependent",parentData:data,parentDataProperty:"dependent",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3304.errors : vErrors.concat(validate3304.errors);
errors = vErrors.length;
}
var valid0 = _errs3 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.privileges !== undefined){
const _errs4 = errors;
if(!(validate2364(data.privileges, {instancePath:instancePath+"/privileges",parentData:data,parentDataProperty:"privileges",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2364.errors : vErrors.concat(validate2364.errors);
errors = vErrors.length;
}
var valid0 = _errs4 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.foreign_key !== undefined){
const _errs5 = errors;
if(!(validate3310(data.foreign_key, {instancePath:instancePath+"/foreign_key",parentData:data,parentDataProperty:"foreign_key",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3310.errors : vErrors.concat(validate3310.errors);
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
validate3302.errors = [{}];
return false;
}
}
validate3302.errors = vErrors;
return errors === 0;
}
validate3302.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate3301(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3301.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate3302(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3302.errors : vErrors.concat(validate3302.errors);
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
validate3301.errors = vErrors;
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
validate3301.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate3301.evaluated = {"dynamicProps":true,"dynamicItems":false};


function validate3300(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3300.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(Array.isArray(data)){
if(data.length > 4){
validate3300.errors = [{}];
return false;
}
else {
if(data.length < 4){
validate3300.errors = [{}];
return false;
}
else {
var valid0 = true;
const len0 = data.length;
for(let i0=0; i0<len0; i0++){
const _errs1 = errors;
if(!(validate3301(data[i0], {instancePath:instancePath+"/" + i0,parentData:data,parentDataProperty:i0,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3301.errors : vErrors.concat(validate3301.errors);
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
validate3300.errors = [{}];
return false;
}
}
validate3300.errors = vErrors;
return errors === 0;
}
validate3300.evaluated = {"items":true,"dynamicProps":false,"dynamicItems":false};

const schema904 = {"anyOf":[{"$ref":"#/$defs/CatalogResponse/$defs/T272"},{"type":"null"}]};
const schema905 = {"type":"object","additionalProperties":false,"properties":{"definition":{"$ref":"#/$defs/CatalogResponse/$defs/T4"},"connection":{"$ref":"#/$defs/CatalogResponse/$defs/T22"},"selection":{"$ref":"#/$defs/CatalogResponse/$defs/T273"},"authority":{"$ref":"#/$defs/CatalogResponse/$defs/T274"},"position":{"$ref":"#/$defs/CatalogResponse/$defs/T26"},"after":{"$ref":"#/$defs/CatalogResponse/$defs/T11"}},"required":["definition","connection","selection","authority","position","after"]};
const schema906 = {"oneOf":[{"type":"object","additionalProperties":false,"required":["dependents"],"properties":{"dependents":{"$ref":"#/$defs/CatalogResponse/$defs/T32"}}},{"type":"object","additionalProperties":false,"required":["dependencies"],"properties":{"dependencies":{"$ref":"#/$defs/CatalogResponse/$defs/T32"}}}]};

function validate3323(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3323.evaluated;
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
if((data.dependents === undefined) && (missing0 = "dependents")){
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
const _errs3 = errors;
for(const key0 in data){
if(!(key0 === "dependents")){
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
if(_errs3 === errors){
if(data.dependents !== undefined){
if(!(validate2449(data.dependents, {instancePath:instancePath+"/dependents",parentData:data,parentDataProperty:"dependents",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2449.errors : vErrors.concat(validate2449.errors);
errors = vErrors.length;
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
var _valid0 = _errs1 === errors;
if(_valid0){
valid0 = true;
passing0 = 0;
var props0 = true;
}
const _errs5 = errors;
if(errors === _errs5){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing1;
if((data.dependencies === undefined) && (missing1 = "dependencies")){
const err3 = {};
if(vErrors === null){
vErrors = [err3];
}
else {
vErrors.push(err3);
}
errors++;
}
else {
const _errs7 = errors;
for(const key1 in data){
if(!(key1 === "dependencies")){
const err4 = {};
if(vErrors === null){
vErrors = [err4];
}
else {
vErrors.push(err4);
}
errors++;
break;
}
}
if(_errs7 === errors){
if(data.dependencies !== undefined){
if(!(validate2449(data.dependencies, {instancePath:instancePath+"/dependencies",parentData:data,parentDataProperty:"dependencies",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2449.errors : vErrors.concat(validate2449.errors);
errors = vErrors.length;
}
}
}
}
}
else {
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
var _valid0 = _errs5 === errors;
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
}
if(!valid0){
const err6 = {};
if(vErrors === null){
vErrors = [err6];
}
else {
vErrors.push(err6);
}
errors++;
validate3323.errors = vErrors;
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
validate3323.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate3323.evaluated = {"dynamicProps":true,"dynamicItems":false};


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
if(!((data === "dependent") || (data === "catalog_administrator"))){
validate3327.errors = [{}];
return false;
}
validate3327.errors = vErrors;
return errors === 0;
}
validate3327.evaluated = {"dynamicProps":false,"dynamicItems":false};


function validate3320(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3320.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if(((((((data.definition === undefined) && (missing0 = "definition")) || ((data.connection === undefined) && (missing0 = "connection"))) || ((data.selection === undefined) && (missing0 = "selection"))) || ((data.authority === undefined) && (missing0 = "authority"))) || ((data.position === undefined) && (missing0 = "position"))) || ((data.after === undefined) && (missing0 = "after"))){
validate3320.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((((((key0 === "definition") || (key0 === "connection")) || (key0 === "selection")) || (key0 === "authority")) || (key0 === "position")) || (key0 === "after"))){
validate3320.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.definition !== undefined){
const _errs2 = errors;
if(!(validate2349(data.definition, {instancePath:instancePath+"/definition",parentData:data,parentDataProperty:"definition",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2349.errors : vErrors.concat(validate2349.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.connection !== undefined){
const _errs3 = errors;
if(!(validate2420(data.connection, {instancePath:instancePath+"/connection",parentData:data,parentDataProperty:"connection",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2420.errors : vErrors.concat(validate2420.errors);
errors = vErrors.length;
}
var valid0 = _errs3 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.selection !== undefined){
const _errs4 = errors;
if(!(validate3323(data.selection, {instancePath:instancePath+"/selection",parentData:data,parentDataProperty:"selection",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3323.errors : vErrors.concat(validate3323.errors);
errors = vErrors.length;
}
var valid0 = _errs4 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.authority !== undefined){
const _errs5 = errors;
if(!(validate3327(data.authority, {instancePath:instancePath+"/authority",parentData:data,parentDataProperty:"authority",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3327.errors : vErrors.concat(validate3327.errors);
errors = vErrors.length;
}
var valid0 = _errs5 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.position !== undefined){
const _errs6 = errors;
if(!(validate2435(data.position, {instancePath:instancePath+"/position",parentData:data,parentDataProperty:"position",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2435.errors : vErrors.concat(validate2435.errors);
errors = vErrors.length;
}
var valid0 = _errs6 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.after !== undefined){
const _errs7 = errors;
if(!(validate2367(data.after, {instancePath:instancePath+"/after",parentData:data,parentDataProperty:"after",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2367.errors : vErrors.concat(validate2367.errors);
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
validate3320.errors = [{}];
return false;
}
}
validate3320.errors = vErrors;
return errors === 0;
}
validate3320.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate3319(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3319.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate3320(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3320.errors : vErrors.concat(validate3320.errors);
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
validate3319.errors = vErrors;
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
validate3319.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate3319.evaluated = {"dynamicProps":true,"dynamicItems":false};


function validate3299(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3299.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((((data.entries === undefined) && (missing0 = "entries")) || ((data.next === undefined) && (missing0 = "next"))) || ((data.position === undefined) && (missing0 = "position"))){
validate3299.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "entries") || (key0 === "next")) || (key0 === "position"))){
validate3299.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.entries !== undefined){
const _errs2 = errors;
if(!(validate3300(data.entries, {instancePath:instancePath+"/entries",parentData:data,parentDataProperty:"entries",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3300.errors : vErrors.concat(validate3300.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.next !== undefined){
const _errs3 = errors;
if(!(validate3319(data.next, {instancePath:instancePath+"/next",parentData:data,parentDataProperty:"next",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3319.errors : vErrors.concat(validate3319.errors);
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
if(!(validate2435(data.position, {instancePath:instancePath+"/position",parentData:data,parentDataProperty:"position",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2435.errors : vErrors.concat(validate2435.errors);
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
validate3299.errors = [{}];
return false;
}
}
validate3299.errors = vErrors;
return errors === 0;
}
validate3299.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate2344(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2344.evaluated;
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
if((data.catalog === undefined) && (missing0 = "catalog")){
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
const _errs3 = errors;
for(const key0 in data){
if(!(key0 === "catalog")){
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
if(_errs3 === errors){
if(data.catalog !== undefined){
if(!(validate2345(data.catalog, {instancePath:instancePath+"/catalog",parentData:data,parentDataProperty:"catalog",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2345.errors : vErrors.concat(validate2345.errors);
errors = vErrors.length;
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
var _valid0 = _errs1 === errors;
if(_valid0){
valid0 = true;
passing0 = 0;
var props1 = true;
}
const _errs5 = errors;
if(errors === _errs5){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing1;
if((data.history === undefined) && (missing1 = "history")){
const err3 = {};
if(vErrors === null){
vErrors = [err3];
}
else {
vErrors.push(err3);
}
errors++;
}
else {
const _errs7 = errors;
for(const key1 in data){
if(!(key1 === "history")){
const err4 = {};
if(vErrors === null){
vErrors = [err4];
}
else {
vErrors.push(err4);
}
errors++;
break;
}
}
if(_errs7 === errors){
if(data.history !== undefined){
if(!(validate2470(data.history, {instancePath:instancePath+"/history",parentData:data,parentDataProperty:"history",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2470.errors : vErrors.concat(validate2470.errors);
errors = vErrors.length;
}
}
}
}
}
else {
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
var _valid0 = _errs5 === errors;
if(_valid0 && valid0){
valid0 = false;
passing0 = [passing0, 1];
}
else {
if(_valid0){
valid0 = true;
passing0 = 1;
if(props1 !== true){
props1 = true;
}
}
const _errs9 = errors;
if(errors === _errs9){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing2;
if((data.definitions === undefined) && (missing2 = "definitions")){
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
const _errs11 = errors;
for(const key2 in data){
if(!(key2 === "definitions")){
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
if(_errs11 === errors){
if(data.definitions !== undefined){
if(!(validate3051(data.definitions, {instancePath:instancePath+"/definitions",parentData:data,parentDataProperty:"definitions",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3051.errors : vErrors.concat(validate3051.errors);
errors = vErrors.length;
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
var _valid0 = _errs9 === errors;
if(_valid0 && valid0){
valid0 = false;
passing0 = [passing0, 2];
}
else {
if(_valid0){
valid0 = true;
passing0 = 2;
if(props1 !== true){
props1 = true;
}
}
const _errs13 = errors;
if(errors === _errs13){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing3;
if((data.resources === undefined) && (missing3 = "resources")){
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
const _errs15 = errors;
for(const key3 in data){
if(!(key3 === "resources")){
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
if(_errs15 === errors){
if(data.resources !== undefined){
if(!(validate3212(data.resources, {instancePath:instancePath+"/resources",parentData:data,parentDataProperty:"resources",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3212.errors : vErrors.concat(validate3212.errors);
errors = vErrors.length;
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
var _valid0 = _errs13 === errors;
if(_valid0 && valid0){
valid0 = false;
passing0 = [passing0, 3];
}
else {
if(_valid0){
valid0 = true;
passing0 = 3;
if(props1 !== true){
props1 = true;
}
}
const _errs17 = errors;
if(errors === _errs17){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing4;
if((data.table === undefined) && (missing4 = "table")){
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
const _errs19 = errors;
for(const key4 in data){
if(!(key4 === "table")){
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
if(_errs19 === errors){
if(data.table !== undefined){
if(!(validate3256(data.table, {instancePath:instancePath+"/table",parentData:data,parentDataProperty:"table",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3256.errors : vErrors.concat(validate3256.errors);
errors = vErrors.length;
}
}
}
}
}
else {
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
var _valid0 = _errs17 === errors;
if(_valid0 && valid0){
valid0 = false;
passing0 = [passing0, 4];
}
else {
if(_valid0){
valid0 = true;
passing0 = 4;
if(props1 !== true){
props1 = true;
}
}
const _errs21 = errors;
if(errors === _errs21){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing5;
if((data.storage === undefined) && (missing5 = "storage")){
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
const _errs23 = errors;
for(const key5 in data){
if(!(key5 === "storage")){
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
if(_errs23 === errors){
if(data.storage !== undefined){
if(!(validate3274(data.storage, {instancePath:instancePath+"/storage",parentData:data,parentDataProperty:"storage",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3274.errors : vErrors.concat(validate3274.errors);
errors = vErrors.length;
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
var _valid0 = _errs21 === errors;
if(_valid0 && valid0){
valid0 = false;
passing0 = [passing0, 5];
}
else {
if(_valid0){
valid0 = true;
passing0 = 5;
if(props1 !== true){
props1 = true;
}
}
const _errs25 = errors;
if(errors === _errs25){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing6;
if((data.dependencies === undefined) && (missing6 = "dependencies")){
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
const _errs27 = errors;
for(const key6 in data){
if(!(key6 === "dependencies")){
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
if(_errs27 === errors){
if(data.dependencies !== undefined){
if(!(validate3299(data.dependencies, {instancePath:instancePath+"/dependencies",parentData:data,parentDataProperty:"dependencies",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3299.errors : vErrors.concat(validate3299.errors);
errors = vErrors.length;
}
}
}
}
}
else {
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
var _valid0 = _errs25 === errors;
if(_valid0 && valid0){
valid0 = false;
passing0 = [passing0, 6];
}
else {
if(_valid0){
valid0 = true;
passing0 = 6;
if(props1 !== true){
props1 = true;
}
}
}
}
}
}
}
}
if(!valid0){
const err21 = {};
if(vErrors === null){
vErrors = [err21];
}
else {
vErrors.push(err21);
}
errors++;
validate2344.errors = vErrors;
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
validate2344.errors = vErrors;
evaluated0.props = props1;
return errors === 0;
}
validate2344.evaluated = {"dynamicProps":true,"dynamicItems":false};
