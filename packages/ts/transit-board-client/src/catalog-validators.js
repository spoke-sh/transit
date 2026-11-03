// Generated; no runtime code generation or eval.
import lengthModule from "ajv/dist/runtime/ucs2length.js";
const ucs2length = lengthModule.default ?? lengthModule;
"use strict";
export const CatalogRequest = validate2160;
const schema587 = {"type":"object","additionalProperties":false,"properties":{"definition":{"$ref":"#/$defs/CatalogRequest/$defs/T1"},"action":{"$ref":"#/$defs/CatalogRequest/$defs/T2"}},"required":["definition","action"]};
const schema21 = {"type":"string","enum":["28dd54cfe806369cb6a6d8ed5bb87fed380afb08c79af9812b5bebe2f123b573"]};

function validate2161(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2161.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate2161.errors = [{}];
return false;
}
if(!(data === "28dd54cfe806369cb6a6d8ed5bb87fed380afb08c79af9812b5bebe2f123b573")){
validate2161.errors = [{}];
return false;
}
validate2161.errors = vErrors;
return errors === 0;
}
validate2161.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema589 = {"oneOf":[{"type":"object","additionalProperties":false,"required":["describe"],"properties":{"describe":{"$ref":"#/$defs/CatalogRequest/$defs/T3"}}},{"type":"object","additionalProperties":false,"required":["history"],"properties":{"history":{"$ref":"#/$defs/CatalogRequest/$defs/T4"}}},{"type":"object","additionalProperties":false,"required":["definitions"],"properties":{"definitions":{"$ref":"#/$defs/CatalogRequest/$defs/T19"}}},{"type":"object","additionalProperties":false,"required":["namespaces"],"properties":{"namespaces":{"$ref":"#/$defs/CatalogRequest/$defs/T31"}}},{"type":"object","additionalProperties":false,"required":["tables"],"properties":{"tables":{"$ref":"#/$defs/CatalogRequest/$defs/T35"}}},{"type":"object","additionalProperties":false,"required":["resources"],"properties":{"resources":{"$ref":"#/$defs/CatalogRequest/$defs/T36"}}},{"type":"object","additionalProperties":false,"required":["table"],"properties":{"table":{"$ref":"#/$defs/CatalogRequest/$defs/T37"}}},{"type":"object","additionalProperties":false,"required":["storage"],"properties":{"storage":{"$ref":"#/$defs/CatalogRequest/$defs/T38"}}},{"type":"object","additionalProperties":false,"required":["dependencies"],"properties":{"dependencies":{"$ref":"#/$defs/CatalogRequest/$defs/T41"}}}]};
const schema590 = {"type":"object","maxProperties":0};

function validate2164(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2164.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
if(Object.keys(data).length > 0){
validate2164.errors = [{}];
return false;
}
}
else {
validate2164.errors = [{}];
return false;
}
}
validate2164.errors = vErrors;
return errors === 0;
}
validate2164.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema591 = {"oneOf":[{"type":"object","additionalProperties":false,"required":["lookup"],"properties":{"lookup":{"$ref":"#/$defs/CatalogRequest/$defs/T5"}}},{"type":"object","additionalProperties":false,"required":["namespace"],"properties":{"namespace":{"$ref":"#/$defs/CatalogRequest/$defs/T8"}}},{"type":"object","additionalProperties":false,"required":["list"],"properties":{"list":{"$ref":"#/$defs/CatalogRequest/$defs/T9"}}},{"type":"object","additionalProperties":false,"required":["source"],"properties":{"source":{"$ref":"#/$defs/CatalogRequest/$defs/T14"}}},{"type":"object","additionalProperties":false,"required":["definitions"],"properties":{"definitions":{"$ref":"#/$defs/CatalogRequest/$defs/T15"}}},{"type":"object","additionalProperties":false,"required":["locations"],"properties":{"locations":{"$ref":"#/$defs/CatalogRequest/$defs/T15"}}}]};
const schema592 = {"type":"object","additionalProperties":false,"properties":{"selector":{"$ref":"#/$defs/CatalogRequest/$defs/T6"},"namespace":{"$ref":"#/$defs/CatalogRequest/$defs/T7"},"name":{"$ref":"#/$defs/CatalogRequest/$defs/T6"}},"required":["selector","namespace","name"]};
const schema593 = {"type":"string","maxLength":262144};
const func3 = ucs2length;

function validate2168(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2168.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(typeof data === "string"){
if(func3(data) > 262144){
validate2168.errors = [{}];
return false;
}
}
else {
validate2168.errors = [{}];
return false;
}
}
validate2168.errors = vErrors;
return errors === 0;
}
validate2168.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema22 = {"type":"integer","minimum":0,"maximum":9007199254740991};

function validate2170(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2170.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(!(((typeof data == "number") && (!(data % 1) && !isNaN(data))) && (isFinite(data)))){
validate2170.errors = [{}];
return false;
}
if(errors === 0){
if((typeof data == "number") && (isFinite(data))){
if(data > 9007199254740991 || isNaN(data)){
validate2170.errors = [{}];
return false;
}
else {
if(data < 0 || isNaN(data)){
validate2170.errors = [{}];
return false;
}
}
}
}
validate2170.errors = vErrors;
return errors === 0;
}
validate2170.evaluated = {"dynamicProps":false,"dynamicItems":false};


function validate2167(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2167.evaluated;
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
validate2167.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "selector") || (key0 === "namespace")) || (key0 === "name"))){
validate2167.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.selector !== undefined){
const _errs2 = errors;
if(!(validate2168(data.selector, {instancePath:instancePath+"/selector",parentData:data,parentDataProperty:"selector",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2168.errors : vErrors.concat(validate2168.errors);
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
if(!(validate2170(data.namespace, {instancePath:instancePath+"/namespace",parentData:data,parentDataProperty:"namespace",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2170.errors : vErrors.concat(validate2170.errors);
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
if(!(validate2168(data.name, {instancePath:instancePath+"/name",parentData:data,parentDataProperty:"name",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2168.errors : vErrors.concat(validate2168.errors);
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
validate2167.errors = [{}];
return false;
}
}
validate2167.errors = vErrors;
return errors === 0;
}
validate2167.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema595 = {"type":"object","additionalProperties":false,"properties":{"selector":{"$ref":"#/$defs/CatalogRequest/$defs/T6"},"name":{"$ref":"#/$defs/CatalogRequest/$defs/T6"}},"required":["selector","name"]};

function validate2174(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2174.evaluated;
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
validate2174.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "selector") || (key0 === "name"))){
validate2174.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.selector !== undefined){
const _errs2 = errors;
if(!(validate2168(data.selector, {instancePath:instancePath+"/selector",parentData:data,parentDataProperty:"selector",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2168.errors : vErrors.concat(validate2168.errors);
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
if(!(validate2168(data.name, {instancePath:instancePath+"/name",parentData:data,parentDataProperty:"name",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2168.errors : vErrors.concat(validate2168.errors);
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
validate2174.errors = [{}];
return false;
}
}
validate2174.errors = vErrors;
return errors === 0;
}
validate2174.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema596 = {"type":"object","additionalProperties":false,"properties":{"selector":{"$ref":"#/$defs/CatalogRequest/$defs/T6"},"namespace":{"$ref":"#/$defs/CatalogRequest/$defs/T7"},"after":{"$ref":"#/$defs/CatalogRequest/$defs/T10"}},"required":["selector","namespace","after"]};
const schema597 = {"anyOf":[{"$ref":"#/$defs/CatalogRequest/$defs/T11"},{"type":"null"}]};
const schema598 = {"type":"object","additionalProperties":false,"properties":{"selector":{"$ref":"#/$defs/CatalogRequest/$defs/T6"},"namespace":{"$ref":"#/$defs/CatalogRequest/$defs/T7"},"directory":{"$ref":"#/$defs/CatalogRequest/$defs/T12"},"after":{"$ref":"#/$defs/CatalogRequest/$defs/T6"}},"required":["selector","namespace","directory","after"]};
const schema599 = {"type":"object","additionalProperties":false,"properties":{"content":{"$ref":"#/$defs/CatalogRequest/$defs/T13"},"count":{"$ref":"#/$defs/CatalogRequest/$defs/T6"},"descriptors":{"$ref":"#/$defs/CatalogRequest/$defs/T6"}},"required":["content","count","descriptors"]};
const schema600 = {"type":"object","additionalProperties":false,"properties":{"bytes":{"$ref":"#/$defs/CatalogRequest/$defs/T6"},"sha256":{"$ref":"#/$defs/CatalogRequest/$defs/T6"}},"required":["bytes","sha256"]};

function validate2186(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2186.evaluated;
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
validate2186.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "bytes") || (key0 === "sha256"))){
validate2186.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.bytes !== undefined){
const _errs2 = errors;
if(!(validate2168(data.bytes, {instancePath:instancePath+"/bytes",parentData:data,parentDataProperty:"bytes",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2168.errors : vErrors.concat(validate2168.errors);
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
if(!(validate2168(data.sha256, {instancePath:instancePath+"/sha256",parentData:data,parentDataProperty:"sha256",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2168.errors : vErrors.concat(validate2168.errors);
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
validate2186.errors = [{}];
return false;
}
}
validate2186.errors = vErrors;
return errors === 0;
}
validate2186.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


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
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((((data.content === undefined) && (missing0 = "content")) || ((data.count === undefined) && (missing0 = "count"))) || ((data.descriptors === undefined) && (missing0 = "descriptors"))){
validate2185.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "content") || (key0 === "count")) || (key0 === "descriptors"))){
validate2185.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.content !== undefined){
const _errs2 = errors;
if(!(validate2186(data.content, {instancePath:instancePath+"/content",parentData:data,parentDataProperty:"content",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2186.errors : vErrors.concat(validate2186.errors);
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
if(!(validate2168(data.count, {instancePath:instancePath+"/count",parentData:data,parentDataProperty:"count",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2168.errors : vErrors.concat(validate2168.errors);
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
if(!(validate2168(data.descriptors, {instancePath:instancePath+"/descriptors",parentData:data,parentDataProperty:"descriptors",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2168.errors : vErrors.concat(validate2168.errors);
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
validate2185.errors = [{}];
return false;
}
}
validate2185.errors = vErrors;
return errors === 0;
}
validate2185.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate2182(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2182.evaluated;
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
validate2182.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((((key0 === "selector") || (key0 === "namespace")) || (key0 === "directory")) || (key0 === "after"))){
validate2182.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.selector !== undefined){
const _errs2 = errors;
if(!(validate2168(data.selector, {instancePath:instancePath+"/selector",parentData:data,parentDataProperty:"selector",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2168.errors : vErrors.concat(validate2168.errors);
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
if(!(validate2170(data.namespace, {instancePath:instancePath+"/namespace",parentData:data,parentDataProperty:"namespace",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2170.errors : vErrors.concat(validate2170.errors);
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
if(!(validate2185(data.directory, {instancePath:instancePath+"/directory",parentData:data,parentDataProperty:"directory",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2185.errors : vErrors.concat(validate2185.errors);
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
if(!(validate2168(data.after, {instancePath:instancePath+"/after",parentData:data,parentDataProperty:"after",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2168.errors : vErrors.concat(validate2168.errors);
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
validate2182.errors = [{}];
return false;
}
}
validate2182.errors = vErrors;
return errors === 0;
}
validate2182.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


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
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate2182(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2182.errors : vErrors.concat(validate2182.errors);
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
validate2181.errors = vErrors;
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
validate2181.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate2181.evaluated = {"dynamicProps":true,"dynamicItems":false};


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
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((((data.selector === undefined) && (missing0 = "selector")) || ((data.namespace === undefined) && (missing0 = "namespace"))) || ((data.after === undefined) && (missing0 = "after"))){
validate2178.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "selector") || (key0 === "namespace")) || (key0 === "after"))){
validate2178.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.selector !== undefined){
const _errs2 = errors;
if(!(validate2168(data.selector, {instancePath:instancePath+"/selector",parentData:data,parentDataProperty:"selector",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2168.errors : vErrors.concat(validate2168.errors);
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
if(!(validate2170(data.namespace, {instancePath:instancePath+"/namespace",parentData:data,parentDataProperty:"namespace",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2170.errors : vErrors.concat(validate2170.errors);
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
if(!(validate2181(data.after, {instancePath:instancePath+"/after",parentData:data,parentDataProperty:"after",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2181.errors : vErrors.concat(validate2181.errors);
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
validate2178.errors = [{}];
return false;
}
}
validate2178.errors = vErrors;
return errors === 0;
}
validate2178.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema601 = {"type":"object","additionalProperties":false,"properties":{"selector":{"$ref":"#/$defs/CatalogRequest/$defs/T6"},"object":{"$ref":"#/$defs/CatalogRequest/$defs/T6"}},"required":["selector","object"]};

function validate2197(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2197.evaluated;
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
validate2197.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "selector") || (key0 === "object"))){
validate2197.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.selector !== undefined){
const _errs2 = errors;
if(!(validate2168(data.selector, {instancePath:instancePath+"/selector",parentData:data,parentDataProperty:"selector",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2168.errors : vErrors.concat(validate2168.errors);
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
if(!(validate2168(data.object, {instancePath:instancePath+"/object",parentData:data,parentDataProperty:"object",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2168.errors : vErrors.concat(validate2168.errors);
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
validate2197.errors = [{}];
return false;
}
}
validate2197.errors = vErrors;
return errors === 0;
}
validate2197.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema602 = {"type":"object","additionalProperties":false,"properties":{"selector":{"$ref":"#/$defs/CatalogRequest/$defs/T6"},"object":{"$ref":"#/$defs/CatalogRequest/$defs/T6"},"after":{"$ref":"#/$defs/CatalogRequest/$defs/T16"}},"required":["selector","object","after"]};
const schema603 = {"anyOf":[{"$ref":"#/$defs/CatalogRequest/$defs/T17"},{"type":"null"}]};
const schema604 = {"type":"object","additionalProperties":false,"properties":{"selector":{"$ref":"#/$defs/CatalogRequest/$defs/T6"},"object":{"$ref":"#/$defs/CatalogRequest/$defs/T6"},"kind":{"$ref":"#/$defs/CatalogRequest/$defs/T18"},"source":{"$ref":"#/$defs/CatalogRequest/$defs/T13"},"after":{"$ref":"#/$defs/CatalogRequest/$defs/T6"}},"required":["selector","object","kind","source","after"]};
const schema605 = {"type":"string","enum":["definitions","locations"]};

function validate2209(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2209.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate2209.errors = [{}];
return false;
}
if(!((data === "definitions") || (data === "locations"))){
validate2209.errors = [{}];
return false;
}
validate2209.errors = vErrors;
return errors === 0;
}
validate2209.evaluated = {"dynamicProps":false,"dynamicItems":false};


function validate2205(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2205.evaluated;
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
validate2205.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((((key0 === "selector") || (key0 === "object")) || (key0 === "kind")) || (key0 === "source")) || (key0 === "after"))){
validate2205.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.selector !== undefined){
const _errs2 = errors;
if(!(validate2168(data.selector, {instancePath:instancePath+"/selector",parentData:data,parentDataProperty:"selector",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2168.errors : vErrors.concat(validate2168.errors);
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
if(!(validate2168(data.object, {instancePath:instancePath+"/object",parentData:data,parentDataProperty:"object",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2168.errors : vErrors.concat(validate2168.errors);
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
if(!(validate2209(data.kind, {instancePath:instancePath+"/kind",parentData:data,parentDataProperty:"kind",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2209.errors : vErrors.concat(validate2209.errors);
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
if(!(validate2186(data.source, {instancePath:instancePath+"/source",parentData:data,parentDataProperty:"source",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2186.errors : vErrors.concat(validate2186.errors);
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
if(!(validate2168(data.after, {instancePath:instancePath+"/after",parentData:data,parentDataProperty:"after",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2168.errors : vErrors.concat(validate2168.errors);
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
validate2205.errors = [{}];
return false;
}
}
validate2205.errors = vErrors;
return errors === 0;
}
validate2205.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate2204(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2204.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate2205(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2205.errors : vErrors.concat(validate2205.errors);
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
validate2204.errors = vErrors;
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
validate2204.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate2204.evaluated = {"dynamicProps":true,"dynamicItems":false};


function validate2201(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2201.evaluated;
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
validate2201.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "selector") || (key0 === "object")) || (key0 === "after"))){
validate2201.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.selector !== undefined){
const _errs2 = errors;
if(!(validate2168(data.selector, {instancePath:instancePath+"/selector",parentData:data,parentDataProperty:"selector",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2168.errors : vErrors.concat(validate2168.errors);
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
if(!(validate2168(data.object, {instancePath:instancePath+"/object",parentData:data,parentDataProperty:"object",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2168.errors : vErrors.concat(validate2168.errors);
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
if(!(validate2204(data.after, {instancePath:instancePath+"/after",parentData:data,parentDataProperty:"after",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2204.errors : vErrors.concat(validate2204.errors);
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
validate2201.errors = [{}];
return false;
}
}
validate2201.errors = vErrors;
return errors === 0;
}
validate2201.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate2166(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2166.evaluated;
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
if(!(validate2167(data.lookup, {instancePath:instancePath+"/lookup",parentData:data,parentDataProperty:"lookup",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2167.errors : vErrors.concat(validate2167.errors);
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
if(!(validate2174(data.namespace, {instancePath:instancePath+"/namespace",parentData:data,parentDataProperty:"namespace",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2174.errors : vErrors.concat(validate2174.errors);
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
if(!(validate2178(data.list, {instancePath:instancePath+"/list",parentData:data,parentDataProperty:"list",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2178.errors : vErrors.concat(validate2178.errors);
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
if(!(validate2197(data.source, {instancePath:instancePath+"/source",parentData:data,parentDataProperty:"source",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2197.errors : vErrors.concat(validate2197.errors);
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
if(!(validate2201(data.definitions, {instancePath:instancePath+"/definitions",parentData:data,parentDataProperty:"definitions",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2201.errors : vErrors.concat(validate2201.errors);
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
if(!(validate2201(data.locations, {instancePath:instancePath+"/locations",parentData:data,parentDataProperty:"locations",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2201.errors : vErrors.concat(validate2201.errors);
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
validate2166.errors = vErrors;
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
validate2166.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate2166.evaluated = {"dynamicProps":true,"dynamicItems":false};

const schema607 = {"oneOf":[{"type":"object","additionalProperties":false,"required":["lookup"],"properties":{"lookup":{"$ref":"#/$defs/CatalogRequest/$defs/T20"}}},{"type":"object","additionalProperties":false,"required":["inspect"],"properties":{"inspect":{"$ref":"#/$defs/CatalogRequest/$defs/T21"}}},{"type":"object","additionalProperties":false,"required":["historical"],"properties":{"historical":{"$ref":"#/$defs/CatalogRequest/$defs/T24"}}},{"type":"object","additionalProperties":false,"required":["list"],"properties":{"list":{"$ref":"#/$defs/CatalogRequest/$defs/T25"}}}]};
const schema608 = {"type":"object","additionalProperties":false,"properties":{"namespace":{"$ref":"#/$defs/CatalogRequest/$defs/T7"},"name":{"$ref":"#/$defs/CatalogRequest/$defs/T6"}},"required":["namespace","name"]};

function validate2219(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2219.evaluated;
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
validate2219.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "namespace") || (key0 === "name"))){
validate2219.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.namespace !== undefined){
const _errs2 = errors;
if(!(validate2170(data.namespace, {instancePath:instancePath+"/namespace",parentData:data,parentDataProperty:"namespace",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2170.errors : vErrors.concat(validate2170.errors);
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
if(!(validate2168(data.name, {instancePath:instancePath+"/name",parentData:data,parentDataProperty:"name",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2168.errors : vErrors.concat(validate2168.errors);
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
validate2219.errors = [{}];
return false;
}
}
validate2219.errors = vErrors;
return errors === 0;
}
validate2219.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema609 = {"type":"object","additionalProperties":false,"properties":{"object":{"$ref":"#/$defs/CatalogRequest/$defs/T22"},"revision":{"$ref":"#/$defs/CatalogRequest/$defs/T6"},"digest":{"$ref":"#/$defs/CatalogRequest/$defs/T6"}},"required":["object","revision","digest"]};
const schema610 = {"type":"object","additionalProperties":false,"properties":{"scope":{"$ref":"#/$defs/CatalogRequest/$defs/T23"},"branch":{"$ref":"#/$defs/CatalogRequest/$defs/T6"},"object":{"$ref":"#/$defs/CatalogRequest/$defs/T6"}},"required":["scope","branch","object"]};
const schema611 = {"type":"object","additionalProperties":false,"properties":{"realm":{"$ref":"#/$defs/CatalogRequest/$defs/T7"},"resource":{"$ref":"#/$defs/CatalogRequest/$defs/T7"},"catalog":{"$ref":"#/$defs/CatalogRequest/$defs/T6"}},"required":["realm","resource","catalog"]};

function validate2225(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2225.evaluated;
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
validate2225.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "realm") || (key0 === "resource")) || (key0 === "catalog"))){
validate2225.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.realm !== undefined){
const _errs2 = errors;
if(!(validate2170(data.realm, {instancePath:instancePath+"/realm",parentData:data,parentDataProperty:"realm",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2170.errors : vErrors.concat(validate2170.errors);
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
if(!(validate2170(data.resource, {instancePath:instancePath+"/resource",parentData:data,parentDataProperty:"resource",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2170.errors : vErrors.concat(validate2170.errors);
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
if(!(validate2168(data.catalog, {instancePath:instancePath+"/catalog",parentData:data,parentDataProperty:"catalog",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2168.errors : vErrors.concat(validate2168.errors);
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
validate2225.errors = [{}];
return false;
}
}
validate2225.errors = vErrors;
return errors === 0;
}
validate2225.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate2224(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2224.evaluated;
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
validate2224.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "scope") || (key0 === "branch")) || (key0 === "object"))){
validate2224.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.scope !== undefined){
const _errs2 = errors;
if(!(validate2225(data.scope, {instancePath:instancePath+"/scope",parentData:data,parentDataProperty:"scope",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2225.errors : vErrors.concat(validate2225.errors);
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
if(!(validate2168(data.branch, {instancePath:instancePath+"/branch",parentData:data,parentDataProperty:"branch",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2168.errors : vErrors.concat(validate2168.errors);
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
if(!(validate2168(data.object, {instancePath:instancePath+"/object",parentData:data,parentDataProperty:"object",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2168.errors : vErrors.concat(validate2168.errors);
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
validate2224.errors = [{}];
return false;
}
}
validate2224.errors = vErrors;
return errors === 0;
}
validate2224.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate2223(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2223.evaluated;
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
validate2223.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "object") || (key0 === "revision")) || (key0 === "digest"))){
validate2223.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.object !== undefined){
const _errs2 = errors;
if(!(validate2224(data.object, {instancePath:instancePath+"/object",parentData:data,parentDataProperty:"object",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2224.errors : vErrors.concat(validate2224.errors);
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
if(!(validate2168(data.revision, {instancePath:instancePath+"/revision",parentData:data,parentDataProperty:"revision",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2168.errors : vErrors.concat(validate2168.errors);
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
if(!(validate2168(data.digest, {instancePath:instancePath+"/digest",parentData:data,parentDataProperty:"digest",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2168.errors : vErrors.concat(validate2168.errors);
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
validate2223.errors = [{}];
return false;
}
}
validate2223.errors = vErrors;
return errors === 0;
}
validate2223.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema612 = {"type":"object","additionalProperties":false,"properties":{"selector":{"$ref":"#/$defs/CatalogRequest/$defs/T6"},"namespace":{"$ref":"#/$defs/CatalogRequest/$defs/T7"},"name":{"$ref":"#/$defs/CatalogRequest/$defs/T6"}},"required":["selector","namespace","name"]};

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
if((((data.selector === undefined) && (missing0 = "selector")) || ((data.namespace === undefined) && (missing0 = "namespace"))) || ((data.name === undefined) && (missing0 = "name"))){
validate2236.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "selector") || (key0 === "namespace")) || (key0 === "name"))){
validate2236.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.selector !== undefined){
const _errs2 = errors;
if(!(validate2168(data.selector, {instancePath:instancePath+"/selector",parentData:data,parentDataProperty:"selector",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2168.errors : vErrors.concat(validate2168.errors);
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
if(!(validate2170(data.namespace, {instancePath:instancePath+"/namespace",parentData:data,parentDataProperty:"namespace",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2170.errors : vErrors.concat(validate2170.errors);
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
if(!(validate2168(data.name, {instancePath:instancePath+"/name",parentData:data,parentDataProperty:"name",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2168.errors : vErrors.concat(validate2168.errors);
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
validate2236.errors = [{}];
return false;
}
}
validate2236.errors = vErrors;
return errors === 0;
}
validate2236.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema613 = {"type":"object","additionalProperties":false,"properties":{"namespace":{"$ref":"#/$defs/CatalogRequest/$defs/T7"},"selector":{"$ref":"#/$defs/CatalogRequest/$defs/T26"},"cursor":{"$ref":"#/$defs/CatalogRequest/$defs/T27"}},"required":["namespace","selector","cursor"]};
const schema614 = {"anyOf":[{"$ref":"#/$defs/CatalogRequest/$defs/T6"},{"type":"null"}]};

function validate2243(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2243.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate2168(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2168.errors : vErrors.concat(validate2168.errors);
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
validate2243.errors = vErrors;
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
validate2243.errors = vErrors;
return errors === 0;
}
validate2243.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema615 = {"anyOf":[{"$ref":"#/$defs/CatalogRequest/$defs/T28"},{"type":"null"}]};
const schema616 = {"type":"object","additionalProperties":false,"properties":{"definition":{"$ref":"#/$defs/CatalogRequest/$defs/T1"},"connection":{"$ref":"#/$defs/CatalogRequest/$defs/T29"},"namespace":{"$ref":"#/$defs/CatalogRequest/$defs/T7"},"selector":{"$ref":"#/$defs/CatalogRequest/$defs/T26"},"after":{"$ref":"#/$defs/CatalogRequest/$defs/T6"}},"required":["definition","connection","namespace","selector","after"]};
const schema617 = {"type":"object","additionalProperties":false,"properties":{"scope":{"$ref":"#/$defs/CatalogRequest/$defs/T23"},"branch":{"$ref":"#/$defs/CatalogRequest/$defs/T6"},"audience":{"$ref":"#/$defs/CatalogRequest/$defs/T7"},"principal":{"$ref":"#/$defs/CatalogRequest/$defs/T7"},"role":{"$ref":"#/$defs/CatalogRequest/$defs/T30"}},"required":["scope","branch","audience","principal","role"]};
const schema618 = {"anyOf":[{"$ref":"#/$defs/CatalogRequest/$defs/T7"},{"type":"null"}]};

function validate2254(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2254.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate2170(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2170.errors : vErrors.concat(validate2170.errors);
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
validate2254.errors = vErrors;
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
validate2254.errors = vErrors;
return errors === 0;
}
validate2254.evaluated = {"dynamicProps":false,"dynamicItems":false};


function validate2249(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2249.evaluated;
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
validate2249.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((((key0 === "scope") || (key0 === "branch")) || (key0 === "audience")) || (key0 === "principal")) || (key0 === "role"))){
validate2249.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.scope !== undefined){
const _errs2 = errors;
if(!(validate2225(data.scope, {instancePath:instancePath+"/scope",parentData:data,parentDataProperty:"scope",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2225.errors : vErrors.concat(validate2225.errors);
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
if(!(validate2168(data.branch, {instancePath:instancePath+"/branch",parentData:data,parentDataProperty:"branch",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2168.errors : vErrors.concat(validate2168.errors);
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
if(!(validate2170(data.audience, {instancePath:instancePath+"/audience",parentData:data,parentDataProperty:"audience",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2170.errors : vErrors.concat(validate2170.errors);
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
if(!(validate2170(data.principal, {instancePath:instancePath+"/principal",parentData:data,parentDataProperty:"principal",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2170.errors : vErrors.concat(validate2170.errors);
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
if(!(validate2254(data.role, {instancePath:instancePath+"/role",parentData:data,parentDataProperty:"role",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2254.errors : vErrors.concat(validate2254.errors);
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
validate2249.errors = [{}];
return false;
}
}
validate2249.errors = vErrors;
return errors === 0;
}
validate2249.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate2247(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2247.evaluated;
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
validate2247.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((((key0 === "definition") || (key0 === "connection")) || (key0 === "namespace")) || (key0 === "selector")) || (key0 === "after"))){
validate2247.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.definition !== undefined){
const _errs2 = errors;
if(!(validate2161(data.definition, {instancePath:instancePath+"/definition",parentData:data,parentDataProperty:"definition",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2161.errors : vErrors.concat(validate2161.errors);
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
if(!(validate2249(data.connection, {instancePath:instancePath+"/connection",parentData:data,parentDataProperty:"connection",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2249.errors : vErrors.concat(validate2249.errors);
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
if(!(validate2170(data.namespace, {instancePath:instancePath+"/namespace",parentData:data,parentDataProperty:"namespace",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2170.errors : vErrors.concat(validate2170.errors);
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
if(!(validate2243(data.selector, {instancePath:instancePath+"/selector",parentData:data,parentDataProperty:"selector",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2243.errors : vErrors.concat(validate2243.errors);
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
if(!(validate2168(data.after, {instancePath:instancePath+"/after",parentData:data,parentDataProperty:"after",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2168.errors : vErrors.concat(validate2168.errors);
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
validate2247.errors = [{}];
return false;
}
}
validate2247.errors = vErrors;
return errors === 0;
}
validate2247.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate2246(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2246.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate2247(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2247.errors : vErrors.concat(validate2247.errors);
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
validate2246.errors = vErrors;
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
validate2246.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate2246.evaluated = {"dynamicProps":true,"dynamicItems":false};


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
if((((data.namespace === undefined) && (missing0 = "namespace")) || ((data.selector === undefined) && (missing0 = "selector"))) || ((data.cursor === undefined) && (missing0 = "cursor"))){
validate2241.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "namespace") || (key0 === "selector")) || (key0 === "cursor"))){
validate2241.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.namespace !== undefined){
const _errs2 = errors;
if(!(validate2170(data.namespace, {instancePath:instancePath+"/namespace",parentData:data,parentDataProperty:"namespace",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2170.errors : vErrors.concat(validate2170.errors);
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
if(!(validate2243(data.selector, {instancePath:instancePath+"/selector",parentData:data,parentDataProperty:"selector",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2243.errors : vErrors.concat(validate2243.errors);
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
if(!(validate2246(data.cursor, {instancePath:instancePath+"/cursor",parentData:data,parentDataProperty:"cursor",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2246.errors : vErrors.concat(validate2246.errors);
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
if(!(validate2219(data.lookup, {instancePath:instancePath+"/lookup",parentData:data,parentDataProperty:"lookup",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2219.errors : vErrors.concat(validate2219.errors);
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
if(!(validate2223(data.inspect, {instancePath:instancePath+"/inspect",parentData:data,parentDataProperty:"inspect",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2223.errors : vErrors.concat(validate2223.errors);
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
if(!(validate2236(data.historical, {instancePath:instancePath+"/historical",parentData:data,parentDataProperty:"historical",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2236.errors : vErrors.concat(validate2236.errors);
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
if(!(validate2241(data.list, {instancePath:instancePath+"/list",parentData:data,parentDataProperty:"list",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2241.errors : vErrors.concat(validate2241.errors);
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
validate2218.errors = vErrors;
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
validate2218.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate2218.evaluated = {"dynamicProps":true,"dynamicItems":false};

const schema619 = {"anyOf":[{"$ref":"#/$defs/CatalogRequest/$defs/T32"},{"type":"null"}]};
const schema620 = {"type":"object","additionalProperties":false,"properties":{"definition":{"$ref":"#/$defs/CatalogRequest/$defs/T1"},"connection":{"$ref":"#/$defs/CatalogRequest/$defs/T29"},"selection":{"$ref":"#/$defs/CatalogRequest/$defs/T33"},"position":{"$ref":"#/$defs/CatalogRequest/$defs/T34"},"after":{"$ref":"#/$defs/CatalogRequest/$defs/T6"}},"required":["definition","connection","selection","position","after"]};
const schema621 = {"oneOf":[{"type":"object","additionalProperties":false,"required":["namespaces"],"properties":{"namespaces":{"$ref":"#/$defs/CatalogRequest/$defs/T3"}}},{"type":"object","additionalProperties":false,"required":["tables"],"properties":{"tables":{"$ref":"#/$defs/CatalogRequest/$defs/T7"}}},{"type":"object","additionalProperties":false,"required":["resources"],"properties":{"resources":{"$ref":"#/$defs/CatalogRequest/$defs/T7"}}}]};

function validate2269(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2269.evaluated;
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
if(!(validate2164(data.namespaces, {instancePath:instancePath+"/namespaces",parentData:data,parentDataProperty:"namespaces",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2164.errors : vErrors.concat(validate2164.errors);
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
if(!(validate2170(data.tables, {instancePath:instancePath+"/tables",parentData:data,parentDataProperty:"tables",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2170.errors : vErrors.concat(validate2170.errors);
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
if(!(validate2170(data.resources, {instancePath:instancePath+"/resources",parentData:data,parentDataProperty:"resources",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2170.errors : vErrors.concat(validate2170.errors);
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
validate2269.errors = vErrors;
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
validate2269.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate2269.evaluated = {"dynamicProps":true,"dynamicItems":false};

const schema622 = {"type":"object","additionalProperties":false,"properties":{"partition":{"$ref":"#/$defs/CatalogRequest/$defs/T6"},"next_lsn":{"$ref":"#/$defs/CatalogRequest/$defs/T6"}},"required":["partition","next_lsn"]};

function validate2274(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2274.evaluated;
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
validate2274.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "partition") || (key0 === "next_lsn"))){
validate2274.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.partition !== undefined){
const _errs2 = errors;
if(!(validate2168(data.partition, {instancePath:instancePath+"/partition",parentData:data,parentDataProperty:"partition",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2168.errors : vErrors.concat(validate2168.errors);
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
if(!(validate2168(data.next_lsn, {instancePath:instancePath+"/next_lsn",parentData:data,parentDataProperty:"next_lsn",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2168.errors : vErrors.concat(validate2168.errors);
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
validate2274.errors = [{}];
return false;
}
}
validate2274.errors = vErrors;
return errors === 0;
}
validate2274.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


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
if((((((data.definition === undefined) && (missing0 = "definition")) || ((data.connection === undefined) && (missing0 = "connection"))) || ((data.selection === undefined) && (missing0 = "selection"))) || ((data.position === undefined) && (missing0 = "position"))) || ((data.after === undefined) && (missing0 = "after"))){
validate2266.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((((key0 === "definition") || (key0 === "connection")) || (key0 === "selection")) || (key0 === "position")) || (key0 === "after"))){
validate2266.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.definition !== undefined){
const _errs2 = errors;
if(!(validate2161(data.definition, {instancePath:instancePath+"/definition",parentData:data,parentDataProperty:"definition",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2161.errors : vErrors.concat(validate2161.errors);
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
if(!(validate2249(data.connection, {instancePath:instancePath+"/connection",parentData:data,parentDataProperty:"connection",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2249.errors : vErrors.concat(validate2249.errors);
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
if(!(validate2269(data.selection, {instancePath:instancePath+"/selection",parentData:data,parentDataProperty:"selection",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2269.errors : vErrors.concat(validate2269.errors);
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
if(!(validate2274(data.position, {instancePath:instancePath+"/position",parentData:data,parentDataProperty:"position",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2274.errors : vErrors.concat(validate2274.errors);
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
if(!(validate2168(data.after, {instancePath:instancePath+"/after",parentData:data,parentDataProperty:"after",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2168.errors : vErrors.concat(validate2168.errors);
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


function validate2265(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2265.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate2266(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2266.errors : vErrors.concat(validate2266.errors);
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
validate2265.errors = vErrors;
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
validate2265.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate2265.evaluated = {"dynamicProps":true,"dynamicItems":false};

const schema623 = {"type":"object","additionalProperties":false,"properties":{"namespace":{"$ref":"#/$defs/CatalogRequest/$defs/T7"},"cursor":{"$ref":"#/$defs/CatalogRequest/$defs/T31"}},"required":["namespace","cursor"]};

function validate2281(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2281.evaluated;
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
validate2281.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "namespace") || (key0 === "cursor"))){
validate2281.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.namespace !== undefined){
const _errs2 = errors;
if(!(validate2170(data.namespace, {instancePath:instancePath+"/namespace",parentData:data,parentDataProperty:"namespace",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2170.errors : vErrors.concat(validate2170.errors);
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
if(!(validate2265(data.cursor, {instancePath:instancePath+"/cursor",parentData:data,parentDataProperty:"cursor",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2265.errors : vErrors.concat(validate2265.errors);
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
validate2281.errors = [{}];
return false;
}
}
validate2281.errors = vErrors;
return errors === 0;
}
validate2281.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema624 = {"type":"object","additionalProperties":false,"properties":{"namespace":{"$ref":"#/$defs/CatalogRequest/$defs/T7"},"cursor":{"$ref":"#/$defs/CatalogRequest/$defs/T31"}},"required":["namespace","cursor"]};

function validate2285(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2285.evaluated;
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
validate2285.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "namespace") || (key0 === "cursor"))){
validate2285.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.namespace !== undefined){
const _errs2 = errors;
if(!(validate2170(data.namespace, {instancePath:instancePath+"/namespace",parentData:data,parentDataProperty:"namespace",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2170.errors : vErrors.concat(validate2170.errors);
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
if(!(validate2265(data.cursor, {instancePath:instancePath+"/cursor",parentData:data,parentDataProperty:"cursor",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2265.errors : vErrors.concat(validate2265.errors);
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
validate2285.errors = [{}];
return false;
}
}
validate2285.errors = vErrors;
return errors === 0;
}
validate2285.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema625 = {"type":"object","additionalProperties":false,"properties":{"namespace":{"$ref":"#/$defs/CatalogRequest/$defs/T7"},"name":{"$ref":"#/$defs/CatalogRequest/$defs/T6"},"expected":{"$ref":"#/$defs/CatalogRequest/$defs/T21"}},"required":["namespace","name","expected"]};

function validate2289(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2289.evaluated;
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
validate2289.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "namespace") || (key0 === "name")) || (key0 === "expected"))){
validate2289.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.namespace !== undefined){
const _errs2 = errors;
if(!(validate2170(data.namespace, {instancePath:instancePath+"/namespace",parentData:data,parentDataProperty:"namespace",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2170.errors : vErrors.concat(validate2170.errors);
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
if(!(validate2168(data.name, {instancePath:instancePath+"/name",parentData:data,parentDataProperty:"name",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2168.errors : vErrors.concat(validate2168.errors);
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
if(!(validate2223(data.expected, {instancePath:instancePath+"/expected",parentData:data,parentDataProperty:"expected",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2223.errors : vErrors.concat(validate2223.errors);
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
validate2289.errors = [{}];
return false;
}
}
validate2289.errors = vErrors;
return errors === 0;
}
validate2289.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema626 = {"type":"object","additionalProperties":false,"properties":{"definition":{"$ref":"#/$defs/CatalogRequest/$defs/T1"},"connection":{"$ref":"#/$defs/CatalogRequest/$defs/T29"},"namespace":{"$ref":"#/$defs/CatalogRequest/$defs/T7"},"name":{"$ref":"#/$defs/CatalogRequest/$defs/T6"},"interpretation":{"$ref":"#/$defs/CatalogRequest/$defs/T39"}},"required":["definition","connection","namespace","name","interpretation"]};
const schema627 = {"type":"object","additionalProperties":false,"properties":{"interpretation":{"$ref":"#/$defs/CatalogRequest/$defs/T21"},"content":{"$ref":"#/$defs/CatalogRequest/$defs/T13"},"schema_fingerprint":{"$ref":"#/$defs/CatalogRequest/$defs/T6"},"retired":{"$ref":"#/$defs/CatalogRequest/$defs/T40"}},"required":["interpretation","content","schema_fingerprint","retired"]};
const schema628 = {"type":"boolean"};

function validate2303(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2303.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "boolean"){
validate2303.errors = [{}];
return false;
}
validate2303.errors = vErrors;
return errors === 0;
}
validate2303.evaluated = {"dynamicProps":false,"dynamicItems":false};


function validate2299(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2299.evaluated;
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
validate2299.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((((key0 === "interpretation") || (key0 === "content")) || (key0 === "schema_fingerprint")) || (key0 === "retired"))){
validate2299.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.interpretation !== undefined){
const _errs2 = errors;
if(!(validate2223(data.interpretation, {instancePath:instancePath+"/interpretation",parentData:data,parentDataProperty:"interpretation",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2223.errors : vErrors.concat(validate2223.errors);
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
if(!(validate2186(data.content, {instancePath:instancePath+"/content",parentData:data,parentDataProperty:"content",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2186.errors : vErrors.concat(validate2186.errors);
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
if(!(validate2168(data.schema_fingerprint, {instancePath:instancePath+"/schema_fingerprint",parentData:data,parentDataProperty:"schema_fingerprint",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2168.errors : vErrors.concat(validate2168.errors);
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
if(!(validate2303(data.retired, {instancePath:instancePath+"/retired",parentData:data,parentDataProperty:"retired",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2303.errors : vErrors.concat(validate2303.errors);
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
validate2299.errors = [{}];
return false;
}
}
validate2299.errors = vErrors;
return errors === 0;
}
validate2299.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate2294(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2294.evaluated;
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
validate2294.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((((key0 === "definition") || (key0 === "connection")) || (key0 === "namespace")) || (key0 === "name")) || (key0 === "interpretation"))){
validate2294.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.definition !== undefined){
const _errs2 = errors;
if(!(validate2161(data.definition, {instancePath:instancePath+"/definition",parentData:data,parentDataProperty:"definition",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2161.errors : vErrors.concat(validate2161.errors);
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
if(!(validate2249(data.connection, {instancePath:instancePath+"/connection",parentData:data,parentDataProperty:"connection",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2249.errors : vErrors.concat(validate2249.errors);
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
if(!(validate2170(data.namespace, {instancePath:instancePath+"/namespace",parentData:data,parentDataProperty:"namespace",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2170.errors : vErrors.concat(validate2170.errors);
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
if(!(validate2168(data.name, {instancePath:instancePath+"/name",parentData:data,parentDataProperty:"name",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2168.errors : vErrors.concat(validate2168.errors);
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
if(!(validate2299(data.interpretation, {instancePath:instancePath+"/interpretation",parentData:data,parentDataProperty:"interpretation",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2299.errors : vErrors.concat(validate2299.errors);
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
validate2294.errors = [{}];
return false;
}
}
validate2294.errors = vErrors;
return errors === 0;
}
validate2294.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema629 = {"type":"object","additionalProperties":false,"properties":{"selection":{"$ref":"#/$defs/CatalogRequest/$defs/T42"},"authority":{"$ref":"#/$defs/CatalogRequest/$defs/T43"},"cursor":{"$ref":"#/$defs/CatalogRequest/$defs/T44"}},"required":["selection","authority","cursor"]};
const schema630 = {"oneOf":[{"type":"object","additionalProperties":false,"required":["dependents"],"properties":{"dependents":{"$ref":"#/$defs/CatalogRequest/$defs/T22"}}},{"type":"object","additionalProperties":false,"required":["dependencies"],"properties":{"dependencies":{"$ref":"#/$defs/CatalogRequest/$defs/T22"}}}]};

function validate2308(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2308.evaluated;
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
if(!(validate2224(data.dependents, {instancePath:instancePath+"/dependents",parentData:data,parentDataProperty:"dependents",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2224.errors : vErrors.concat(validate2224.errors);
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
if(!(validate2224(data.dependencies, {instancePath:instancePath+"/dependencies",parentData:data,parentDataProperty:"dependencies",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2224.errors : vErrors.concat(validate2224.errors);
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
validate2308.errors = vErrors;
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
validate2308.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate2308.evaluated = {"dynamicProps":true,"dynamicItems":false};

const schema631 = {"type":"string","enum":["dependent","catalog_administrator"]};

function validate2313(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2313.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate2313.errors = [{}];
return false;
}
if(!((data === "dependent") || (data === "catalog_administrator"))){
validate2313.errors = [{}];
return false;
}
validate2313.errors = vErrors;
return errors === 0;
}
validate2313.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema633 = {"anyOf":[{"$ref":"#/$defs/CatalogRequest/$defs/T45"},{"type":"null"}]};
const schema634 = {"type":"object","additionalProperties":false,"properties":{"definition":{"$ref":"#/$defs/CatalogRequest/$defs/T1"},"connection":{"$ref":"#/$defs/CatalogRequest/$defs/T29"},"selection":{"$ref":"#/$defs/CatalogRequest/$defs/T42"},"authority":{"$ref":"#/$defs/CatalogRequest/$defs/T43"},"position":{"$ref":"#/$defs/CatalogRequest/$defs/T34"},"after":{"$ref":"#/$defs/CatalogRequest/$defs/T6"}},"required":["definition","connection","selection","authority","position","after"]};

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
if(((((((data.definition === undefined) && (missing0 = "definition")) || ((data.connection === undefined) && (missing0 = "connection"))) || ((data.selection === undefined) && (missing0 = "selection"))) || ((data.authority === undefined) && (missing0 = "authority"))) || ((data.position === undefined) && (missing0 = "position"))) || ((data.after === undefined) && (missing0 = "after"))){
validate2316.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((((((key0 === "definition") || (key0 === "connection")) || (key0 === "selection")) || (key0 === "authority")) || (key0 === "position")) || (key0 === "after"))){
validate2316.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.definition !== undefined){
const _errs2 = errors;
if(!(validate2161(data.definition, {instancePath:instancePath+"/definition",parentData:data,parentDataProperty:"definition",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2161.errors : vErrors.concat(validate2161.errors);
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
if(!(validate2249(data.connection, {instancePath:instancePath+"/connection",parentData:data,parentDataProperty:"connection",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2249.errors : vErrors.concat(validate2249.errors);
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
if(!(validate2308(data.selection, {instancePath:instancePath+"/selection",parentData:data,parentDataProperty:"selection",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2308.errors : vErrors.concat(validate2308.errors);
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
if(!(validate2313(data.authority, {instancePath:instancePath+"/authority",parentData:data,parentDataProperty:"authority",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2313.errors : vErrors.concat(validate2313.errors);
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
if(!(validate2274(data.position, {instancePath:instancePath+"/position",parentData:data,parentDataProperty:"position",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2274.errors : vErrors.concat(validate2274.errors);
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
if(!(validate2168(data.after, {instancePath:instancePath+"/after",parentData:data,parentDataProperty:"after",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2168.errors : vErrors.concat(validate2168.errors);
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
validate2316.errors = [{}];
return false;
}
}
validate2316.errors = vErrors;
return errors === 0;
}
validate2316.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate2315(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2315.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate2316(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2316.errors : vErrors.concat(validate2316.errors);
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
validate2315.errors = vErrors;
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
validate2315.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate2315.evaluated = {"dynamicProps":true,"dynamicItems":false};


function validate2307(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2307.evaluated;
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
validate2307.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "selection") || (key0 === "authority")) || (key0 === "cursor"))){
validate2307.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.selection !== undefined){
const _errs2 = errors;
if(!(validate2308(data.selection, {instancePath:instancePath+"/selection",parentData:data,parentDataProperty:"selection",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2308.errors : vErrors.concat(validate2308.errors);
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
if(!(validate2313(data.authority, {instancePath:instancePath+"/authority",parentData:data,parentDataProperty:"authority",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2313.errors : vErrors.concat(validate2313.errors);
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
if(!(validate2315(data.cursor, {instancePath:instancePath+"/cursor",parentData:data,parentDataProperty:"cursor",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2315.errors : vErrors.concat(validate2315.errors);
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
validate2307.errors = [{}];
return false;
}
}
validate2307.errors = vErrors;
return errors === 0;
}
validate2307.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate2163(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2163.evaluated;
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
if(!(validate2164(data.describe, {instancePath:instancePath+"/describe",parentData:data,parentDataProperty:"describe",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2164.errors : vErrors.concat(validate2164.errors);
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
if(!(validate2166(data.history, {instancePath:instancePath+"/history",parentData:data,parentDataProperty:"history",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2166.errors : vErrors.concat(validate2166.errors);
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
if(!(validate2218(data.definitions, {instancePath:instancePath+"/definitions",parentData:data,parentDataProperty:"definitions",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2218.errors : vErrors.concat(validate2218.errors);
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
if(!(validate2265(data.namespaces, {instancePath:instancePath+"/namespaces",parentData:data,parentDataProperty:"namespaces",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2265.errors : vErrors.concat(validate2265.errors);
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
if(!(validate2281(data.tables, {instancePath:instancePath+"/tables",parentData:data,parentDataProperty:"tables",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2281.errors : vErrors.concat(validate2281.errors);
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
if(!(validate2285(data.resources, {instancePath:instancePath+"/resources",parentData:data,parentDataProperty:"resources",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2285.errors : vErrors.concat(validate2285.errors);
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
if(!(validate2289(data.table, {instancePath:instancePath+"/table",parentData:data,parentDataProperty:"table",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2289.errors : vErrors.concat(validate2289.errors);
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
if(!(validate2294(data.storage, {instancePath:instancePath+"/storage",parentData:data,parentDataProperty:"storage",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2294.errors : vErrors.concat(validate2294.errors);
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
if(!(validate2307(data.dependencies, {instancePath:instancePath+"/dependencies",parentData:data,parentDataProperty:"dependencies",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2307.errors : vErrors.concat(validate2307.errors);
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
validate2163.errors = vErrors;
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
validate2163.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate2163.evaluated = {"dynamicProps":true,"dynamicItems":false};


function validate2160(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2160.evaluated;
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
validate2160.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "definition") || (key0 === "action"))){
validate2160.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.definition !== undefined){
const _errs2 = errors;
if(!(validate2161(data.definition, {instancePath:instancePath+"/definition",parentData:data,parentDataProperty:"definition",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2161.errors : vErrors.concat(validate2161.errors);
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
if(!(validate2163(data.action, {instancePath:instancePath+"/action",parentData:data,parentDataProperty:"action",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2163.errors : vErrors.concat(validate2163.errors);
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
validate2160.errors = [{}];
return false;
}
}
validate2160.errors = vErrors;
return errors === 0;
}
validate2160.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

export const CatalogResponse = validate2327;
const schema635 = {"oneOf":[{"type":"object","additionalProperties":false,"required":["catalog"],"properties":{"catalog":{"$ref":"#/$defs/CatalogResponse/$defs/T1"}}},{"type":"object","additionalProperties":false,"required":["history"],"properties":{"history":{"$ref":"#/$defs/CatalogResponse/$defs/T34"}}},{"type":"object","additionalProperties":false,"required":["definitions"],"properties":{"definitions":{"$ref":"#/$defs/CatalogResponse/$defs/T197"}}},{"type":"object","additionalProperties":false,"required":["resources"],"properties":{"resources":{"$ref":"#/$defs/CatalogResponse/$defs/T247"}}},{"type":"object","additionalProperties":false,"required":["table"],"properties":{"table":{"$ref":"#/$defs/CatalogResponse/$defs/T257"}}},{"type":"object","additionalProperties":false,"required":["storage"],"properties":{"storage":{"$ref":"#/$defs/CatalogResponse/$defs/T260"}}},{"type":"object","additionalProperties":false,"required":["dependencies"],"properties":{"dependencies":{"$ref":"#/$defs/CatalogResponse/$defs/T262"}}}]};
const schema636 = {"oneOf":[{"type":"object","additionalProperties":false,"required":["capabilities"],"properties":{"capabilities":{"$ref":"#/$defs/CatalogResponse/$defs/T2"}}},{"type":"object","additionalProperties":false,"required":["description"],"properties":{"description":{"$ref":"#/$defs/CatalogResponse/$defs/T7"}}},{"type":"object","additionalProperties":false,"required":["namespace"],"properties":{"namespace":{"$ref":"#/$defs/CatalogResponse/$defs/T15"}}},{"type":"object","additionalProperties":false,"required":["namespaces"],"properties":{"namespaces":{"$ref":"#/$defs/CatalogResponse/$defs/T18"}}},{"type":"object","additionalProperties":false,"required":["tables"],"properties":{"tables":{"$ref":"#/$defs/CatalogResponse/$defs/T27"}}}]};
const schema637 = {"type":"object","additionalProperties":false,"properties":{"version":{"$ref":"#/$defs/CatalogResponse/$defs/T3"},"definition":{"$ref":"#/$defs/CatalogResponse/$defs/T4"},"max_columns":{"$ref":"#/$defs/CatalogResponse/$defs/T5"},"max_rows":{"$ref":"#/$defs/CatalogResponse/$defs/T5"},"max_sql_bytes":{"$ref":"#/$defs/CatalogResponse/$defs/T5"},"max_intent_bytes":{"$ref":"#/$defs/CatalogResponse/$defs/T6"},"max_action_bytes":{"$ref":"#/$defs/CatalogResponse/$defs/T6"},"metadata_page_entries":{"$ref":"#/$defs/CatalogResponse/$defs/T3"},"resident_intents":{"$ref":"#/$defs/CatalogResponse/$defs/T3"}},"required":["version","definition","max_columns","max_rows","max_sql_bytes","max_intent_bytes","max_action_bytes","metadata_page_entries","resident_intents"]};
const func1 = Object.prototype.hasOwnProperty;
const schema58 = {"type":"integer","minimum":0,"maximum":255};

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
if(!(((typeof data == "number") && (!(data % 1) && !isNaN(data))) && (isFinite(data)))){
validate2330.errors = [{}];
return false;
}
if(errors === 0){
if((typeof data == "number") && (isFinite(data))){
if(data > 255 || isNaN(data)){
validate2330.errors = [{}];
return false;
}
else {
if(data < 0 || isNaN(data)){
validate2330.errors = [{}];
return false;
}
}
}
}
validate2330.errors = vErrors;
return errors === 0;
}
validate2330.evaluated = {"dynamicProps":false,"dynamicItems":false};


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
if(typeof data !== "string"){
validate2332.errors = [{}];
return false;
}
if(!(data === "28dd54cfe806369cb6a6d8ed5bb87fed380afb08c79af9812b5bebe2f123b573")){
validate2332.errors = [{}];
return false;
}
validate2332.errors = vErrors;
return errors === 0;
}
validate2332.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema67 = {"type":"integer","minimum":0,"maximum":65535};

function validate2334(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2334.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(!(((typeof data == "number") && (!(data % 1) && !isNaN(data))) && (isFinite(data)))){
validate2334.errors = [{}];
return false;
}
if(errors === 0){
if((typeof data == "number") && (isFinite(data))){
if(data > 65535 || isNaN(data)){
validate2334.errors = [{}];
return false;
}
else {
if(data < 0 || isNaN(data)){
validate2334.errors = [{}];
return false;
}
}
}
}
validate2334.errors = vErrors;
return errors === 0;
}
validate2334.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema24 = {"type":"integer","minimum":0,"maximum":4294967295};

function validate2338(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2338.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(!(((typeof data == "number") && (!(data % 1) && !isNaN(data))) && (isFinite(data)))){
validate2338.errors = [{}];
return false;
}
if(errors === 0){
if((typeof data == "number") && (isFinite(data))){
if(data > 4294967295 || isNaN(data)){
validate2338.errors = [{}];
return false;
}
else {
if(data < 0 || isNaN(data)){
validate2338.errors = [{}];
return false;
}
}
}
}
validate2338.errors = vErrors;
return errors === 0;
}
validate2338.evaluated = {"dynamicProps":false,"dynamicItems":false};


function validate2329(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2329.evaluated;
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
validate2329.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(func1.call(schema637.properties, key0))){
validate2329.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.version !== undefined){
const _errs2 = errors;
if(!(validate2330(data.version, {instancePath:instancePath+"/version",parentData:data,parentDataProperty:"version",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2330.errors : vErrors.concat(validate2330.errors);
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
if(!(validate2332(data.definition, {instancePath:instancePath+"/definition",parentData:data,parentDataProperty:"definition",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2332.errors : vErrors.concat(validate2332.errors);
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
if(!(validate2334(data.max_columns, {instancePath:instancePath+"/max_columns",parentData:data,parentDataProperty:"max_columns",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2334.errors : vErrors.concat(validate2334.errors);
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
if(!(validate2334(data.max_rows, {instancePath:instancePath+"/max_rows",parentData:data,parentDataProperty:"max_rows",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2334.errors : vErrors.concat(validate2334.errors);
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
if(!(validate2334(data.max_sql_bytes, {instancePath:instancePath+"/max_sql_bytes",parentData:data,parentDataProperty:"max_sql_bytes",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2334.errors : vErrors.concat(validate2334.errors);
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
if(!(validate2338(data.max_intent_bytes, {instancePath:instancePath+"/max_intent_bytes",parentData:data,parentDataProperty:"max_intent_bytes",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2338.errors : vErrors.concat(validate2338.errors);
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
if(!(validate2338(data.max_action_bytes, {instancePath:instancePath+"/max_action_bytes",parentData:data,parentDataProperty:"max_action_bytes",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2338.errors : vErrors.concat(validate2338.errors);
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
if(!(validate2330(data.metadata_page_entries, {instancePath:instancePath+"/metadata_page_entries",parentData:data,parentDataProperty:"metadata_page_entries",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2330.errors : vErrors.concat(validate2330.errors);
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
if(!(validate2330(data.resident_intents, {instancePath:instancePath+"/resident_intents",parentData:data,parentDataProperty:"resident_intents",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2330.errors : vErrors.concat(validate2330.errors);
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
validate2329.errors = [{}];
return false;
}
}
validate2329.errors = vErrors;
return errors === 0;
}
validate2329.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema642 = {"type":"object","additionalProperties":false,"properties":{"configuration":{"$ref":"#/$defs/CatalogResponse/$defs/T8"},"subject":{"$ref":"#/$defs/CatalogResponse/$defs/T13"},"policy_revision":{"$ref":"#/$defs/CatalogResponse/$defs/T10"}},"required":["configuration","subject","policy_revision"]};
const schema643 = {"type":"object","additionalProperties":false,"properties":{"scope":{"$ref":"#/$defs/CatalogResponse/$defs/T9"},"branch":{"$ref":"#/$defs/CatalogResponse/$defs/T11"},"partition":{"$ref":"#/$defs/CatalogResponse/$defs/T11"},"audience":{"$ref":"#/$defs/CatalogResponse/$defs/T10"},"authority":{"$ref":"#/$defs/CatalogResponse/$defs/T12"},"database_name":{"$ref":"#/$defs/CatalogResponse/$defs/T11"},"initial_schema_name":{"$ref":"#/$defs/CatalogResponse/$defs/T11"}},"required":["scope","branch","partition","audience","authority","database_name","initial_schema_name"]};
const schema644 = {"type":"object","additionalProperties":false,"properties":{"realm":{"$ref":"#/$defs/CatalogResponse/$defs/T10"},"resource":{"$ref":"#/$defs/CatalogResponse/$defs/T10"},"catalog":{"$ref":"#/$defs/CatalogResponse/$defs/T11"}},"required":["realm","resource","catalog"]};

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
if(data > 9007199254740991 || isNaN(data)){
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

const schema646 = {"type":"string","maxLength":262144};

function validate2350(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2350.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(typeof data === "string"){
if(func3(data) > 262144){
validate2350.errors = [{}];
return false;
}
}
else {
validate2350.errors = [{}];
return false;
}
}
validate2350.errors = vErrors;
return errors === 0;
}
validate2350.evaluated = {"dynamicProps":false,"dynamicItems":false};


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
if((((data.realm === undefined) && (missing0 = "realm")) || ((data.resource === undefined) && (missing0 = "resource"))) || ((data.catalog === undefined) && (missing0 = "catalog"))){
validate2346.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "realm") || (key0 === "resource")) || (key0 === "catalog"))){
validate2346.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.realm !== undefined){
const _errs2 = errors;
if(!(validate2347(data.realm, {instancePath:instancePath+"/realm",parentData:data,parentDataProperty:"realm",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2347.errors : vErrors.concat(validate2347.errors);
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
if(!(validate2347(data.resource, {instancePath:instancePath+"/resource",parentData:data,parentDataProperty:"resource",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2347.errors : vErrors.concat(validate2347.errors);
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
if(!(validate2350(data.catalog, {instancePath:instancePath+"/catalog",parentData:data,parentDataProperty:"catalog",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2350.errors : vErrors.concat(validate2350.errors);
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
validate2346.errors = [{}];
return false;
}
}
validate2346.errors = vErrors;
return errors === 0;
}
validate2346.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema647 = {"type":"object","additionalProperties":false,"properties":{"database_domain":{"$ref":"#/$defs/CatalogResponse/$defs/T10"},"schema_domain":{"$ref":"#/$defs/CatalogResponse/$defs/T10"},"table_domain":{"$ref":"#/$defs/CatalogResponse/$defs/T10"},"stream_domain":{"$ref":"#/$defs/CatalogResponse/$defs/T10"},"queue_domain":{"$ref":"#/$defs/CatalogResponse/$defs/T10"},"kv_domain":{"$ref":"#/$defs/CatalogResponse/$defs/T10"},"database":{"$ref":"#/$defs/CatalogResponse/$defs/T10"},"initial_schema":{"$ref":"#/$defs/CatalogResponse/$defs/T10"},"initial_schema_authority":{"$ref":"#/$defs/CatalogResponse/$defs/T10"}},"required":["database_domain","schema_domain","table_domain","stream_domain","queue_domain","kv_domain","database","initial_schema","initial_schema_authority"]};

function validate2356(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2356.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((((((((((data.database_domain === undefined) && (missing0 = "database_domain")) || ((data.schema_domain === undefined) && (missing0 = "schema_domain"))) || ((data.table_domain === undefined) && (missing0 = "table_domain"))) || ((data.stream_domain === undefined) && (missing0 = "stream_domain"))) || ((data.queue_domain === undefined) && (missing0 = "queue_domain"))) || ((data.kv_domain === undefined) && (missing0 = "kv_domain"))) || ((data.database === undefined) && (missing0 = "database"))) || ((data.initial_schema === undefined) && (missing0 = "initial_schema"))) || ((data.initial_schema_authority === undefined) && (missing0 = "initial_schema_authority"))){
validate2356.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(func1.call(schema647.properties, key0))){
validate2356.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.database_domain !== undefined){
const _errs2 = errors;
if(!(validate2347(data.database_domain, {instancePath:instancePath+"/database_domain",parentData:data,parentDataProperty:"database_domain",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2347.errors : vErrors.concat(validate2347.errors);
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
if(!(validate2347(data.schema_domain, {instancePath:instancePath+"/schema_domain",parentData:data,parentDataProperty:"schema_domain",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2347.errors : vErrors.concat(validate2347.errors);
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
if(!(validate2347(data.table_domain, {instancePath:instancePath+"/table_domain",parentData:data,parentDataProperty:"table_domain",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2347.errors : vErrors.concat(validate2347.errors);
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
if(!(validate2347(data.stream_domain, {instancePath:instancePath+"/stream_domain",parentData:data,parentDataProperty:"stream_domain",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2347.errors : vErrors.concat(validate2347.errors);
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
if(!(validate2347(data.queue_domain, {instancePath:instancePath+"/queue_domain",parentData:data,parentDataProperty:"queue_domain",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2347.errors : vErrors.concat(validate2347.errors);
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
if(!(validate2347(data.kv_domain, {instancePath:instancePath+"/kv_domain",parentData:data,parentDataProperty:"kv_domain",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2347.errors : vErrors.concat(validate2347.errors);
errors = vErrors.length;
}
var valid0 = _errs7 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.database !== undefined){
const _errs8 = errors;
if(!(validate2347(data.database, {instancePath:instancePath+"/database",parentData:data,parentDataProperty:"database",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2347.errors : vErrors.concat(validate2347.errors);
errors = vErrors.length;
}
var valid0 = _errs8 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.initial_schema !== undefined){
const _errs9 = errors;
if(!(validate2347(data.initial_schema, {instancePath:instancePath+"/initial_schema",parentData:data,parentDataProperty:"initial_schema",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2347.errors : vErrors.concat(validate2347.errors);
errors = vErrors.length;
}
var valid0 = _errs9 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.initial_schema_authority !== undefined){
const _errs10 = errors;
if(!(validate2347(data.initial_schema_authority, {instancePath:instancePath+"/initial_schema_authority",parentData:data,parentDataProperty:"initial_schema_authority",rootData,dynamicAnchors}))){
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
validate2356.errors = [{}];
return false;
}
}
validate2356.errors = vErrors;
return errors === 0;
}
validate2356.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


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
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((((((((data.scope === undefined) && (missing0 = "scope")) || ((data.branch === undefined) && (missing0 = "branch"))) || ((data.partition === undefined) && (missing0 = "partition"))) || ((data.audience === undefined) && (missing0 = "audience"))) || ((data.authority === undefined) && (missing0 = "authority"))) || ((data.database_name === undefined) && (missing0 = "database_name"))) || ((data.initial_schema_name === undefined) && (missing0 = "initial_schema_name"))){
validate2345.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((((((key0 === "scope") || (key0 === "branch")) || (key0 === "partition")) || (key0 === "audience")) || (key0 === "authority")) || (key0 === "database_name")) || (key0 === "initial_schema_name"))){
validate2345.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.scope !== undefined){
const _errs2 = errors;
if(!(validate2346(data.scope, {instancePath:instancePath+"/scope",parentData:data,parentDataProperty:"scope",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2346.errors : vErrors.concat(validate2346.errors);
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
if(!(validate2350(data.branch, {instancePath:instancePath+"/branch",parentData:data,parentDataProperty:"branch",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2350.errors : vErrors.concat(validate2350.errors);
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
if(!(validate2350(data.partition, {instancePath:instancePath+"/partition",parentData:data,parentDataProperty:"partition",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2350.errors : vErrors.concat(validate2350.errors);
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
if(!(validate2347(data.audience, {instancePath:instancePath+"/audience",parentData:data,parentDataProperty:"audience",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2347.errors : vErrors.concat(validate2347.errors);
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
if(!(validate2356(data.authority, {instancePath:instancePath+"/authority",parentData:data,parentDataProperty:"authority",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2356.errors : vErrors.concat(validate2356.errors);
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
if(!(validate2350(data.database_name, {instancePath:instancePath+"/database_name",parentData:data,parentDataProperty:"database_name",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2350.errors : vErrors.concat(validate2350.errors);
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
if(!(validate2350(data.initial_schema_name, {instancePath:instancePath+"/initial_schema_name",parentData:data,parentDataProperty:"initial_schema_name",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2350.errors : vErrors.concat(validate2350.errors);
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
validate2345.errors = [{}];
return false;
}
}
validate2345.errors = vErrors;
return errors === 0;
}
validate2345.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema648 = {"type":"object","additionalProperties":false,"properties":{"principal":{"$ref":"#/$defs/CatalogResponse/$defs/T10"},"login_role":{"$ref":"#/$defs/CatalogResponse/$defs/T10"},"role":{"$ref":"#/$defs/CatalogResponse/$defs/T10"},"credential_epoch":{"$ref":"#/$defs/CatalogResponse/$defs/T10"},"audience":{"$ref":"#/$defs/CatalogResponse/$defs/T10"},"context":{"$ref":"#/$defs/CatalogResponse/$defs/T14"}},"required":["principal","login_role","role","credential_epoch","audience","context"]};
const schema649 = {"type":"array","minItems":32,"maxItems":32,"items":{"$ref":"#/$defs/CatalogResponse/$defs/T3"}};

function validate2376(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2376.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(Array.isArray(data)){
if(data.length > 32){
validate2376.errors = [{}];
return false;
}
else {
if(data.length < 32){
validate2376.errors = [{}];
return false;
}
else {
var valid0 = true;
const len0 = data.length;
for(let i0=0; i0<len0; i0++){
const _errs1 = errors;
if(!(validate2330(data[i0], {instancePath:instancePath+"/" + i0,parentData:data,parentDataProperty:i0,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2330.errors : vErrors.concat(validate2330.errors);
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
validate2376.errors = [{}];
return false;
}
}
validate2376.errors = vErrors;
return errors === 0;
}
validate2376.evaluated = {"items":true,"dynamicProps":false,"dynamicItems":false};


function validate2370(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2370.evaluated;
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
validate2370.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((((((key0 === "principal") || (key0 === "login_role")) || (key0 === "role")) || (key0 === "credential_epoch")) || (key0 === "audience")) || (key0 === "context"))){
validate2370.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.principal !== undefined){
const _errs2 = errors;
if(!(validate2347(data.principal, {instancePath:instancePath+"/principal",parentData:data,parentDataProperty:"principal",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2347.errors : vErrors.concat(validate2347.errors);
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
if(!(validate2347(data.login_role, {instancePath:instancePath+"/login_role",parentData:data,parentDataProperty:"login_role",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2347.errors : vErrors.concat(validate2347.errors);
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
if(!(validate2347(data.role, {instancePath:instancePath+"/role",parentData:data,parentDataProperty:"role",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2347.errors : vErrors.concat(validate2347.errors);
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
if(!(validate2347(data.credential_epoch, {instancePath:instancePath+"/credential_epoch",parentData:data,parentDataProperty:"credential_epoch",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2347.errors : vErrors.concat(validate2347.errors);
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
if(!(validate2347(data.audience, {instancePath:instancePath+"/audience",parentData:data,parentDataProperty:"audience",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2347.errors : vErrors.concat(validate2347.errors);
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
if(!(validate2376(data.context, {instancePath:instancePath+"/context",parentData:data,parentDataProperty:"context",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2376.errors : vErrors.concat(validate2376.errors);
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
validate2370.errors = [{}];
return false;
}
}
validate2370.errors = vErrors;
return errors === 0;
}
validate2370.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


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
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((((data.configuration === undefined) && (missing0 = "configuration")) || ((data.subject === undefined) && (missing0 = "subject"))) || ((data.policy_revision === undefined) && (missing0 = "policy_revision"))){
validate2344.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "configuration") || (key0 === "subject")) || (key0 === "policy_revision"))){
validate2344.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.configuration !== undefined){
const _errs2 = errors;
if(!(validate2345(data.configuration, {instancePath:instancePath+"/configuration",parentData:data,parentDataProperty:"configuration",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2345.errors : vErrors.concat(validate2345.errors);
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
if(!(validate2370(data.subject, {instancePath:instancePath+"/subject",parentData:data,parentDataProperty:"subject",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2370.errors : vErrors.concat(validate2370.errors);
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
if(!(validate2347(data.policy_revision, {instancePath:instancePath+"/policy_revision",parentData:data,parentDataProperty:"policy_revision",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2347.errors : vErrors.concat(validate2347.errors);
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
validate2344.errors = [{}];
return false;
}
}
validate2344.errors = vErrors;
return errors === 0;
}
validate2344.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema650 = {"anyOf":[{"$ref":"#/$defs/CatalogResponse/$defs/T16"},{"type":"null"}]};
const schema651 = {"type":"object","additionalProperties":false,"properties":{"scope":{"$ref":"#/$defs/CatalogResponse/$defs/T9"},"id":{"$ref":"#/$defs/CatalogResponse/$defs/T10"},"authorization":{"$ref":"#/$defs/CatalogResponse/$defs/T10"},"name":{"$ref":"#/$defs/CatalogResponse/$defs/T11"},"revision":{"$ref":"#/$defs/CatalogResponse/$defs/T10"},"retired":{"$ref":"#/$defs/CatalogResponse/$defs/T17"}},"required":["scope","id","authorization","name","revision","retired"]};
const schema652 = {"type":"boolean"};

function validate2389(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2389.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "boolean"){
validate2389.errors = [{}];
return false;
}
validate2389.errors = vErrors;
return errors === 0;
}
validate2389.evaluated = {"dynamicProps":false,"dynamicItems":false};


function validate2383(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2383.evaluated;
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
validate2383.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((((((key0 === "scope") || (key0 === "id")) || (key0 === "authorization")) || (key0 === "name")) || (key0 === "revision")) || (key0 === "retired"))){
validate2383.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.scope !== undefined){
const _errs2 = errors;
if(!(validate2346(data.scope, {instancePath:instancePath+"/scope",parentData:data,parentDataProperty:"scope",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2346.errors : vErrors.concat(validate2346.errors);
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
if(!(validate2347(data.id, {instancePath:instancePath+"/id",parentData:data,parentDataProperty:"id",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2347.errors : vErrors.concat(validate2347.errors);
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
if(!(validate2347(data.authorization, {instancePath:instancePath+"/authorization",parentData:data,parentDataProperty:"authorization",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2347.errors : vErrors.concat(validate2347.errors);
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
if(!(validate2350(data.name, {instancePath:instancePath+"/name",parentData:data,parentDataProperty:"name",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2350.errors : vErrors.concat(validate2350.errors);
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
if(!(validate2347(data.revision, {instancePath:instancePath+"/revision",parentData:data,parentDataProperty:"revision",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2347.errors : vErrors.concat(validate2347.errors);
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
if(!(validate2389(data.retired, {instancePath:instancePath+"/retired",parentData:data,parentDataProperty:"retired",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2389.errors : vErrors.concat(validate2389.errors);
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
validate2383.errors = [{}];
return false;
}
}
validate2383.errors = vErrors;
return errors === 0;
}
validate2383.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate2382(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2382.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate2383(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2383.errors : vErrors.concat(validate2383.errors);
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
validate2382.errors = vErrors;
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
validate2382.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate2382.evaluated = {"dynamicProps":true,"dynamicItems":false};

const schema653 = {"type":"object","additionalProperties":false,"properties":{"entries":{"$ref":"#/$defs/CatalogResponse/$defs/T19"},"next":{"$ref":"#/$defs/CatalogResponse/$defs/T20"},"position":{"$ref":"#/$defs/CatalogResponse/$defs/T26"}},"required":["entries","next","position"]};
const schema654 = {"type":"array","minItems":8,"maxItems":8,"items":{"$ref":"#/$defs/CatalogResponse/$defs/T15"}};

function validate2394(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2394.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(Array.isArray(data)){
if(data.length > 8){
validate2394.errors = [{}];
return false;
}
else {
if(data.length < 8){
validate2394.errors = [{}];
return false;
}
else {
var valid0 = true;
const len0 = data.length;
for(let i0=0; i0<len0; i0++){
const _errs1 = errors;
if(!(validate2382(data[i0], {instancePath:instancePath+"/" + i0,parentData:data,parentDataProperty:i0,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2382.errors : vErrors.concat(validate2382.errors);
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
validate2394.errors = [{}];
return false;
}
}
validate2394.errors = vErrors;
return errors === 0;
}
validate2394.evaluated = {"items":true,"dynamicProps":false,"dynamicItems":false};

const schema655 = {"anyOf":[{"$ref":"#/$defs/CatalogResponse/$defs/T21"},{"type":"null"}]};
const schema656 = {"type":"object","additionalProperties":false,"properties":{"definition":{"$ref":"#/$defs/CatalogResponse/$defs/T4"},"connection":{"$ref":"#/$defs/CatalogResponse/$defs/T22"},"selection":{"$ref":"#/$defs/CatalogResponse/$defs/T24"},"position":{"$ref":"#/$defs/CatalogResponse/$defs/T26"},"after":{"$ref":"#/$defs/CatalogResponse/$defs/T11"}},"required":["definition","connection","selection","position","after"]};
const schema657 = {"type":"object","additionalProperties":false,"properties":{"scope":{"$ref":"#/$defs/CatalogResponse/$defs/T9"},"branch":{"$ref":"#/$defs/CatalogResponse/$defs/T11"},"audience":{"$ref":"#/$defs/CatalogResponse/$defs/T10"},"principal":{"$ref":"#/$defs/CatalogResponse/$defs/T10"},"role":{"$ref":"#/$defs/CatalogResponse/$defs/T23"}},"required":["scope","branch","audience","principal","role"]};
const schema658 = {"anyOf":[{"$ref":"#/$defs/CatalogResponse/$defs/T10"},{"type":"null"}]};

function validate2405(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2405.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate2347(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2347.errors : vErrors.concat(validate2347.errors);
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
validate2405.errors = vErrors;
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
validate2405.errors = vErrors;
return errors === 0;
}
validate2405.evaluated = {"dynamicProps":false,"dynamicItems":false};


function validate2400(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2400.evaluated;
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
validate2400.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((((key0 === "scope") || (key0 === "branch")) || (key0 === "audience")) || (key0 === "principal")) || (key0 === "role"))){
validate2400.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.scope !== undefined){
const _errs2 = errors;
if(!(validate2346(data.scope, {instancePath:instancePath+"/scope",parentData:data,parentDataProperty:"scope",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2346.errors : vErrors.concat(validate2346.errors);
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
if(!(validate2350(data.branch, {instancePath:instancePath+"/branch",parentData:data,parentDataProperty:"branch",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2350.errors : vErrors.concat(validate2350.errors);
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
if(!(validate2347(data.audience, {instancePath:instancePath+"/audience",parentData:data,parentDataProperty:"audience",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2347.errors : vErrors.concat(validate2347.errors);
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
if(!(validate2347(data.principal, {instancePath:instancePath+"/principal",parentData:data,parentDataProperty:"principal",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2347.errors : vErrors.concat(validate2347.errors);
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
if(!(validate2405(data.role, {instancePath:instancePath+"/role",parentData:data,parentDataProperty:"role",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2405.errors : vErrors.concat(validate2405.errors);
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
validate2400.errors = [{}];
return false;
}
}
validate2400.errors = vErrors;
return errors === 0;
}
validate2400.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema659 = {"oneOf":[{"type":"object","additionalProperties":false,"required":["namespaces"],"properties":{"namespaces":{"$ref":"#/$defs/CatalogResponse/$defs/T25"}}},{"type":"object","additionalProperties":false,"required":["tables"],"properties":{"tables":{"$ref":"#/$defs/CatalogResponse/$defs/T10"}}},{"type":"object","additionalProperties":false,"required":["resources"],"properties":{"resources":{"$ref":"#/$defs/CatalogResponse/$defs/T10"}}}]};
const schema660 = {"type":"object","maxProperties":0};

function validate2410(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2410.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
if(Object.keys(data).length > 0){
validate2410.errors = [{}];
return false;
}
}
else {
validate2410.errors = [{}];
return false;
}
}
validate2410.errors = vErrors;
return errors === 0;
}
validate2410.evaluated = {"dynamicProps":false,"dynamicItems":false};


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
if(!(validate2410(data.namespaces, {instancePath:instancePath+"/namespaces",parentData:data,parentDataProperty:"namespaces",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2410.errors : vErrors.concat(validate2410.errors);
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
if(!(validate2347(data.tables, {instancePath:instancePath+"/tables",parentData:data,parentDataProperty:"tables",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2347.errors : vErrors.concat(validate2347.errors);
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
if(!(validate2347(data.resources, {instancePath:instancePath+"/resources",parentData:data,parentDataProperty:"resources",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2347.errors : vErrors.concat(validate2347.errors);
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
validate2409.errors = vErrors;
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
validate2409.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate2409.evaluated = {"dynamicProps":true,"dynamicItems":false};

const schema661 = {"type":"object","additionalProperties":false,"properties":{"partition":{"$ref":"#/$defs/CatalogResponse/$defs/T11"},"next_lsn":{"$ref":"#/$defs/CatalogResponse/$defs/T11"}},"required":["partition","next_lsn"]};

function validate2415(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2415.evaluated;
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
validate2415.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "partition") || (key0 === "next_lsn"))){
validate2415.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.partition !== undefined){
const _errs2 = errors;
if(!(validate2350(data.partition, {instancePath:instancePath+"/partition",parentData:data,parentDataProperty:"partition",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2350.errors : vErrors.concat(validate2350.errors);
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
if(!(validate2350(data.next_lsn, {instancePath:instancePath+"/next_lsn",parentData:data,parentDataProperty:"next_lsn",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2350.errors : vErrors.concat(validate2350.errors);
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
validate2415.errors = [{}];
return false;
}
}
validate2415.errors = vErrors;
return errors === 0;
}
validate2415.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate2398(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2398.evaluated;
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
validate2398.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((((key0 === "definition") || (key0 === "connection")) || (key0 === "selection")) || (key0 === "position")) || (key0 === "after"))){
validate2398.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.definition !== undefined){
const _errs2 = errors;
if(!(validate2332(data.definition, {instancePath:instancePath+"/definition",parentData:data,parentDataProperty:"definition",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2332.errors : vErrors.concat(validate2332.errors);
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
if(!(validate2400(data.connection, {instancePath:instancePath+"/connection",parentData:data,parentDataProperty:"connection",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2400.errors : vErrors.concat(validate2400.errors);
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
if(!(validate2409(data.selection, {instancePath:instancePath+"/selection",parentData:data,parentDataProperty:"selection",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2409.errors : vErrors.concat(validate2409.errors);
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
if(!(validate2415(data.position, {instancePath:instancePath+"/position",parentData:data,parentDataProperty:"position",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2415.errors : vErrors.concat(validate2415.errors);
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
if(!(validate2350(data.after, {instancePath:instancePath+"/after",parentData:data,parentDataProperty:"after",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2350.errors : vErrors.concat(validate2350.errors);
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
validate2398.errors = [{}];
return false;
}
}
validate2398.errors = vErrors;
return errors === 0;
}
validate2398.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate2397(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2397.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate2398(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2398.errors : vErrors.concat(validate2398.errors);
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
validate2397.errors = vErrors;
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
validate2397.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate2397.evaluated = {"dynamicProps":true,"dynamicItems":false};


function validate2393(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2393.evaluated;
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
validate2393.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "entries") || (key0 === "next")) || (key0 === "position"))){
validate2393.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.entries !== undefined){
const _errs2 = errors;
if(!(validate2394(data.entries, {instancePath:instancePath+"/entries",parentData:data,parentDataProperty:"entries",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2394.errors : vErrors.concat(validate2394.errors);
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
if(!(validate2397(data.next, {instancePath:instancePath+"/next",parentData:data,parentDataProperty:"next",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2397.errors : vErrors.concat(validate2397.errors);
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
if(!(validate2415(data.position, {instancePath:instancePath+"/position",parentData:data,parentDataProperty:"position",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2415.errors : vErrors.concat(validate2415.errors);
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
validate2393.errors = [{}];
return false;
}
}
validate2393.errors = vErrors;
return errors === 0;
}
validate2393.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema662 = {"type":"object","additionalProperties":false,"properties":{"entries":{"$ref":"#/$defs/CatalogResponse/$defs/T28"},"next":{"$ref":"#/$defs/CatalogResponse/$defs/T20"},"position":{"$ref":"#/$defs/CatalogResponse/$defs/T26"},"consistency":{"$ref":"#/$defs/CatalogResponse/$defs/T33"}},"required":["entries","next","position","consistency"]};
const schema663 = {"type":"array","minItems":8,"maxItems":8,"items":{"$ref":"#/$defs/CatalogResponse/$defs/T29"}};
const schema664 = {"anyOf":[{"$ref":"#/$defs/CatalogResponse/$defs/T30"},{"type":"null"}]};
const schema665 = {"type":"object","additionalProperties":false,"properties":{"interpretation":{"$ref":"#/$defs/CatalogResponse/$defs/T31"},"namespace":{"$ref":"#/$defs/CatalogResponse/$defs/T10"},"name":{"$ref":"#/$defs/CatalogResponse/$defs/T11"},"position":{"$ref":"#/$defs/CatalogResponse/$defs/T26"},"changed_lsn":{"$ref":"#/$defs/CatalogResponse/$defs/T11"}},"required":["interpretation","namespace","name","position","changed_lsn"]};
const schema666 = {"type":"object","additionalProperties":false,"properties":{"object":{"$ref":"#/$defs/CatalogResponse/$defs/T32"},"revision":{"$ref":"#/$defs/CatalogResponse/$defs/T11"},"digest":{"$ref":"#/$defs/CatalogResponse/$defs/T11"}},"required":["object","revision","digest"]};
const schema667 = {"type":"object","additionalProperties":false,"properties":{"scope":{"$ref":"#/$defs/CatalogResponse/$defs/T9"},"branch":{"$ref":"#/$defs/CatalogResponse/$defs/T11"},"object":{"$ref":"#/$defs/CatalogResponse/$defs/T11"}},"required":["scope","branch","object"]};

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
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((((data.scope === undefined) && (missing0 = "scope")) || ((data.branch === undefined) && (missing0 = "branch"))) || ((data.object === undefined) && (missing0 = "object"))){
validate2429.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "scope") || (key0 === "branch")) || (key0 === "object"))){
validate2429.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.scope !== undefined){
const _errs2 = errors;
if(!(validate2346(data.scope, {instancePath:instancePath+"/scope",parentData:data,parentDataProperty:"scope",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2346.errors : vErrors.concat(validate2346.errors);
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
if(!(validate2350(data.branch, {instancePath:instancePath+"/branch",parentData:data,parentDataProperty:"branch",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2350.errors : vErrors.concat(validate2350.errors);
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
if(!(validate2350(data.object, {instancePath:instancePath+"/object",parentData:data,parentDataProperty:"object",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2350.errors : vErrors.concat(validate2350.errors);
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
validate2429.errors = [{}];
return false;
}
}
validate2429.errors = vErrors;
return errors === 0;
}
validate2429.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate2428(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2428.evaluated;
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
validate2428.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "object") || (key0 === "revision")) || (key0 === "digest"))){
validate2428.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.object !== undefined){
const _errs2 = errors;
if(!(validate2429(data.object, {instancePath:instancePath+"/object",parentData:data,parentDataProperty:"object",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2429.errors : vErrors.concat(validate2429.errors);
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
if(!(validate2350(data.revision, {instancePath:instancePath+"/revision",parentData:data,parentDataProperty:"revision",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2350.errors : vErrors.concat(validate2350.errors);
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
if(!(validate2350(data.digest, {instancePath:instancePath+"/digest",parentData:data,parentDataProperty:"digest",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2350.errors : vErrors.concat(validate2350.errors);
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
validate2428.errors = [{}];
return false;
}
}
validate2428.errors = vErrors;
return errors === 0;
}
validate2428.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate2427(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2427.evaluated;
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
validate2427.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((((key0 === "interpretation") || (key0 === "namespace")) || (key0 === "name")) || (key0 === "position")) || (key0 === "changed_lsn"))){
validate2427.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.interpretation !== undefined){
const _errs2 = errors;
if(!(validate2428(data.interpretation, {instancePath:instancePath+"/interpretation",parentData:data,parentDataProperty:"interpretation",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2428.errors : vErrors.concat(validate2428.errors);
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
if(!(validate2347(data.namespace, {instancePath:instancePath+"/namespace",parentData:data,parentDataProperty:"namespace",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2347.errors : vErrors.concat(validate2347.errors);
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
if(!(validate2350(data.name, {instancePath:instancePath+"/name",parentData:data,parentDataProperty:"name",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2350.errors : vErrors.concat(validate2350.errors);
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
if(!(validate2415(data.position, {instancePath:instancePath+"/position",parentData:data,parentDataProperty:"position",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2415.errors : vErrors.concat(validate2415.errors);
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
if(!(validate2350(data.changed_lsn, {instancePath:instancePath+"/changed_lsn",parentData:data,parentDataProperty:"changed_lsn",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2350.errors : vErrors.concat(validate2350.errors);
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
validate2427.errors = [{}];
return false;
}
}
validate2427.errors = vErrors;
return errors === 0;
}
validate2427.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate2426(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2426.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate2427(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2427.errors : vErrors.concat(validate2427.errors);
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
validate2426.errors = vErrors;
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
validate2426.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate2426.evaluated = {"dynamicProps":true,"dynamicItems":false};


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
if(errors === 0){
if(Array.isArray(data)){
if(data.length > 8){
validate2425.errors = [{}];
return false;
}
else {
if(data.length < 8){
validate2425.errors = [{}];
return false;
}
else {
var valid0 = true;
const len0 = data.length;
for(let i0=0; i0<len0; i0++){
const _errs1 = errors;
if(!(validate2426(data[i0], {instancePath:instancePath+"/" + i0,parentData:data,parentDataProperty:i0,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2426.errors : vErrors.concat(validate2426.errors);
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
validate2425.errors = [{}];
return false;
}
}
validate2425.errors = vErrors;
return errors === 0;
}
validate2425.evaluated = {"items":true,"dynamicProps":false,"dynamicItems":false};

const schema668 = {"type":"string","enum":["independent"]};

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
if(typeof data !== "string"){
validate2446.errors = [{}];
return false;
}
if(!(data === "independent")){
validate2446.errors = [{}];
return false;
}
validate2446.errors = vErrors;
return errors === 0;
}
validate2446.evaluated = {"dynamicProps":false,"dynamicItems":false};


function validate2424(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2424.evaluated;
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
validate2424.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((((key0 === "entries") || (key0 === "next")) || (key0 === "position")) || (key0 === "consistency"))){
validate2424.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.entries !== undefined){
const _errs2 = errors;
if(!(validate2425(data.entries, {instancePath:instancePath+"/entries",parentData:data,parentDataProperty:"entries",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2425.errors : vErrors.concat(validate2425.errors);
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
if(!(validate2397(data.next, {instancePath:instancePath+"/next",parentData:data,parentDataProperty:"next",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2397.errors : vErrors.concat(validate2397.errors);
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
if(!(validate2415(data.position, {instancePath:instancePath+"/position",parentData:data,parentDataProperty:"position",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2415.errors : vErrors.concat(validate2415.errors);
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
if(!(validate2446(data.consistency, {instancePath:instancePath+"/consistency",parentData:data,parentDataProperty:"consistency",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2446.errors : vErrors.concat(validate2446.errors);
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
validate2424.errors = [{}];
return false;
}
}
validate2424.errors = vErrors;
return errors === 0;
}
validate2424.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate2328(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2328.evaluated;
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
if(!(validate2329(data.capabilities, {instancePath:instancePath+"/capabilities",parentData:data,parentDataProperty:"capabilities",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2329.errors : vErrors.concat(validate2329.errors);
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
if(!(validate2344(data.description, {instancePath:instancePath+"/description",parentData:data,parentDataProperty:"description",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2344.errors : vErrors.concat(validate2344.errors);
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
if(!(validate2382(data.namespace, {instancePath:instancePath+"/namespace",parentData:data,parentDataProperty:"namespace",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2382.errors : vErrors.concat(validate2382.errors);
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
if(!(validate2393(data.namespaces, {instancePath:instancePath+"/namespaces",parentData:data,parentDataProperty:"namespaces",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2393.errors : vErrors.concat(validate2393.errors);
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
if(!(validate2424(data.tables, {instancePath:instancePath+"/tables",parentData:data,parentDataProperty:"tables",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2424.errors : vErrors.concat(validate2424.errors);
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
validate2328.errors = vErrors;
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
validate2328.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate2328.evaluated = {"dynamicProps":true,"dynamicItems":false};

const schema669 = {"oneOf":[{"type":"object","additionalProperties":false,"required":["coverage"],"properties":{"coverage":{"$ref":"#/$defs/CatalogResponse/$defs/T35"}}},{"type":"object","additionalProperties":false,"required":["object"],"properties":{"object":{"$ref":"#/$defs/CatalogResponse/$defs/T72"}}},{"type":"object","additionalProperties":false,"required":["namespace"],"properties":{"namespace":{"$ref":"#/$defs/CatalogResponse/$defs/T73"}}},{"type":"object","additionalProperties":false,"required":["listing"],"properties":{"listing":{"$ref":"#/$defs/CatalogResponse/$defs/T75"}}},{"type":"object","additionalProperties":false,"required":["source"],"properties":{"source":{"$ref":"#/$defs/CatalogResponse/$defs/T83"}}}]};
const schema670 = {"type":"object","additionalProperties":false,"properties":{"snapshot":{"$ref":"#/$defs/CatalogResponse/$defs/T36"},"logical":{"$ref":"#/$defs/CatalogResponse/$defs/T41"},"accepted":{"$ref":"#/$defs/CatalogResponse/$defs/T26"},"total_rows":{"$ref":"#/$defs/CatalogResponse/$defs/T11"},"definitions":{"$ref":"#/$defs/CatalogResponse/$defs/T42"},"locations":{"$ref":"#/$defs/CatalogResponse/$defs/T54"},"next":{"$ref":"#/$defs/CatalogResponse/$defs/T69"}},"required":["snapshot","logical","accepted","total_rows","definitions","locations","next"]};
const schema671 = {"type":"object","additionalProperties":false,"properties":{"selector":{"$ref":"#/$defs/CatalogResponse/$defs/T11"},"definition":{"$ref":"#/$defs/CatalogResponse/$defs/T4"},"owner":{"$ref":"#/$defs/CatalogResponse/$defs/T37"},"branch":{"$ref":"#/$defs/CatalogResponse/$defs/T11"},"catalog_root":{"$ref":"#/$defs/CatalogResponse/$defs/T38"},"sources_root":{"$ref":"#/$defs/CatalogResponse/$defs/T38"},"source_count":{"$ref":"#/$defs/CatalogResponse/$defs/T11"},"consistency":{"$ref":"#/$defs/CatalogResponse/$defs/T39"}},"required":["selector","definition","owner","branch","catalog_root","sources_root","source_count","consistency"]};
const schema672 = {"type":"object","additionalProperties":false,"properties":{"scope":{"$ref":"#/$defs/CatalogResponse/$defs/T9"},"principal":{"$ref":"#/$defs/CatalogResponse/$defs/T10"},"operation":{"$ref":"#/$defs/CatalogResponse/$defs/T11"}},"required":["scope","principal","operation"]};

function validate2455(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2455.evaluated;
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
validate2455.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "scope") || (key0 === "principal")) || (key0 === "operation"))){
validate2455.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.scope !== undefined){
const _errs2 = errors;
if(!(validate2346(data.scope, {instancePath:instancePath+"/scope",parentData:data,parentDataProperty:"scope",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2346.errors : vErrors.concat(validate2346.errors);
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
if(!(validate2347(data.principal, {instancePath:instancePath+"/principal",parentData:data,parentDataProperty:"principal",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2347.errors : vErrors.concat(validate2347.errors);
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
if(!(validate2350(data.operation, {instancePath:instancePath+"/operation",parentData:data,parentDataProperty:"operation",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2350.errors : vErrors.concat(validate2350.errors);
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
validate2455.errors = [{}];
return false;
}
}
validate2455.errors = vErrors;
return errors === 0;
}
validate2455.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema673 = {"type":"object","additionalProperties":false,"properties":{"bytes":{"$ref":"#/$defs/CatalogResponse/$defs/T11"},"sha256":{"$ref":"#/$defs/CatalogResponse/$defs/T11"}},"required":["bytes","sha256"]};

function validate2461(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2461.evaluated;
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
validate2461.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "bytes") || (key0 === "sha256"))){
validate2461.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.bytes !== undefined){
const _errs2 = errors;
if(!(validate2350(data.bytes, {instancePath:instancePath+"/bytes",parentData:data,parentDataProperty:"bytes",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2350.errors : vErrors.concat(validate2350.errors);
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
if(!(validate2350(data.sha256, {instancePath:instancePath+"/sha256",parentData:data,parentDataProperty:"sha256",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2350.errors : vErrors.concat(validate2350.errors);
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
validate2461.errors = [{}];
return false;
}
}
validate2461.errors = vErrors;
return errors === 0;
}
validate2461.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema674 = {"oneOf":[{"type":"object","additionalProperties":false,"required":["single_partition"],"properties":{"single_partition":{"$ref":"#/$defs/CatalogResponse/$defs/T26"}}},{"type":"object","additionalProperties":false,"required":["independent"],"properties":{"independent":{"$ref":"#/$defs/CatalogResponse/$defs/T25"}}},{"type":"object","additionalProperties":false,"required":["common_transaction"],"properties":{"common_transaction":{"$ref":"#/$defs/CatalogResponse/$defs/T40"}}}]};
const schema675 = {"type":"object","additionalProperties":false,"properties":{"transaction":{"$ref":"#/$defs/CatalogResponse/$defs/T37"},"acquired":{"$ref":"#/$defs/CatalogResponse/$defs/T26"},"sources":{"$ref":"#/$defs/CatalogResponse/$defs/T38"},"source_count":{"$ref":"#/$defs/CatalogResponse/$defs/T11"}},"required":["transaction","acquired","sources","source_count"]};

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
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if(((((data.transaction === undefined) && (missing0 = "transaction")) || ((data.acquired === undefined) && (missing0 = "acquired"))) || ((data.sources === undefined) && (missing0 = "sources"))) || ((data.source_count === undefined) && (missing0 = "source_count"))){
validate2470.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((((key0 === "transaction") || (key0 === "acquired")) || (key0 === "sources")) || (key0 === "source_count"))){
validate2470.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.transaction !== undefined){
const _errs2 = errors;
if(!(validate2455(data.transaction, {instancePath:instancePath+"/transaction",parentData:data,parentDataProperty:"transaction",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2455.errors : vErrors.concat(validate2455.errors);
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
if(!(validate2415(data.acquired, {instancePath:instancePath+"/acquired",parentData:data,parentDataProperty:"acquired",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2415.errors : vErrors.concat(validate2415.errors);
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
if(!(validate2461(data.sources, {instancePath:instancePath+"/sources",parentData:data,parentDataProperty:"sources",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2461.errors : vErrors.concat(validate2461.errors);
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
if(!(validate2350(data.source_count, {instancePath:instancePath+"/source_count",parentData:data,parentDataProperty:"source_count",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2350.errors : vErrors.concat(validate2350.errors);
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
validate2470.errors = [{}];
return false;
}
}
validate2470.errors = vErrors;
return errors === 0;
}
validate2470.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate2467(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2467.evaluated;
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
if(!(validate2415(data.single_partition, {instancePath:instancePath+"/single_partition",parentData:data,parentDataProperty:"single_partition",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2415.errors : vErrors.concat(validate2415.errors);
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
if(!(validate2410(data.independent, {instancePath:instancePath+"/independent",parentData:data,parentDataProperty:"independent",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2410.errors : vErrors.concat(validate2410.errors);
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
if(!(validate2470(data.common_transaction, {instancePath:instancePath+"/common_transaction",parentData:data,parentDataProperty:"common_transaction",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2470.errors : vErrors.concat(validate2470.errors);
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
validate2467.errors = vErrors;
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
validate2467.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate2467.evaluated = {"dynamicProps":true,"dynamicItems":false};


function validate2452(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2452.evaluated;
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
validate2452.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((((((((key0 === "selector") || (key0 === "definition")) || (key0 === "owner")) || (key0 === "branch")) || (key0 === "catalog_root")) || (key0 === "sources_root")) || (key0 === "source_count")) || (key0 === "consistency"))){
validate2452.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.selector !== undefined){
const _errs2 = errors;
if(!(validate2350(data.selector, {instancePath:instancePath+"/selector",parentData:data,parentDataProperty:"selector",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2350.errors : vErrors.concat(validate2350.errors);
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
if(!(validate2332(data.definition, {instancePath:instancePath+"/definition",parentData:data,parentDataProperty:"definition",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2332.errors : vErrors.concat(validate2332.errors);
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
if(!(validate2455(data.owner, {instancePath:instancePath+"/owner",parentData:data,parentDataProperty:"owner",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2455.errors : vErrors.concat(validate2455.errors);
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
if(!(validate2350(data.branch, {instancePath:instancePath+"/branch",parentData:data,parentDataProperty:"branch",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2350.errors : vErrors.concat(validate2350.errors);
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
if(!(validate2461(data.catalog_root, {instancePath:instancePath+"/catalog_root",parentData:data,parentDataProperty:"catalog_root",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2461.errors : vErrors.concat(validate2461.errors);
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
if(!(validate2461(data.sources_root, {instancePath:instancePath+"/sources_root",parentData:data,parentDataProperty:"sources_root",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2461.errors : vErrors.concat(validate2461.errors);
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
if(!(validate2350(data.source_count, {instancePath:instancePath+"/source_count",parentData:data,parentDataProperty:"source_count",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2350.errors : vErrors.concat(validate2350.errors);
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
if(!(validate2467(data.consistency, {instancePath:instancePath+"/consistency",parentData:data,parentDataProperty:"consistency",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2467.errors : vErrors.concat(validate2467.errors);
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
validate2452.errors = [{}];
return false;
}
}
validate2452.errors = vErrors;
return errors === 0;
}
validate2452.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema676 = {"type":"object","additionalProperties":false,"properties":{"interpretation":{"$ref":"#/$defs/CatalogResponse/$defs/T31"},"content":{"$ref":"#/$defs/CatalogResponse/$defs/T38"},"schema_fingerprint":{"$ref":"#/$defs/CatalogResponse/$defs/T11"},"retired":{"$ref":"#/$defs/CatalogResponse/$defs/T17"}},"required":["interpretation","content","schema_fingerprint","retired"]};

function validate2478(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2478.evaluated;
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
validate2478.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((((key0 === "interpretation") || (key0 === "content")) || (key0 === "schema_fingerprint")) || (key0 === "retired"))){
validate2478.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.interpretation !== undefined){
const _errs2 = errors;
if(!(validate2428(data.interpretation, {instancePath:instancePath+"/interpretation",parentData:data,parentDataProperty:"interpretation",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2428.errors : vErrors.concat(validate2428.errors);
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
if(!(validate2461(data.content, {instancePath:instancePath+"/content",parentData:data,parentDataProperty:"content",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2461.errors : vErrors.concat(validate2461.errors);
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
if(!(validate2350(data.schema_fingerprint, {instancePath:instancePath+"/schema_fingerprint",parentData:data,parentDataProperty:"schema_fingerprint",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2350.errors : vErrors.concat(validate2350.errors);
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
if(!(validate2389(data.retired, {instancePath:instancePath+"/retired",parentData:data,parentDataProperty:"retired",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2389.errors : vErrors.concat(validate2389.errors);
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
validate2478.errors = [{}];
return false;
}
}
validate2478.errors = vErrors;
return errors === 0;
}
validate2478.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema677 = {"anyOf":[{"$ref":"#/$defs/CatalogResponse/$defs/T43"},{"type":"null"}]};
const schema678 = {"type":"object","additionalProperties":false,"properties":{"physical":{"$ref":"#/$defs/CatalogResponse/$defs/T41"},"schema_revision":{"$ref":"#/$defs/CatalogResponse/$defs/T11"},"rows":{"$ref":"#/$defs/CatalogResponse/$defs/T11"},"columns":{"$ref":"#/$defs/CatalogResponse/$defs/T44"}},"required":["physical","schema_revision","rows","columns"]};
const schema679 = {"type":"array","maxItems":128,"items":{"$ref":"#/$defs/CatalogResponse/$defs/T45"}};
const schema680 = {"type":"object","additionalProperties":false,"properties":{"column":{"$ref":"#/$defs/CatalogResponse/$defs/T46"},"source":{"$ref":"#/$defs/CatalogResponse/$defs/T47"}},"required":["column","source"]};
const schema681 = {"type":"string","maxLength":262144};

function validate2493(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2493.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(typeof data === "string"){
if(func3(data) > 262144){
validate2493.errors = [{}];
return false;
}
}
else {
validate2493.errors = [{}];
return false;
}
}
validate2493.errors = vErrors;
return errors === 0;
}
validate2493.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema682 = {"oneOf":[{"type":"object","additionalProperties":false,"required":["physical"],"properties":{"physical":{"$ref":"#/$defs/CatalogResponse/$defs/T46"}}},{"type":"object","additionalProperties":false,"required":["initial"],"properties":{"initial":{"$ref":"#/$defs/CatalogResponse/$defs/T48"}}}]};
const schema683 = {"type":"object","additionalProperties":false,"properties":{"definition":{"$ref":"#/$defs/CatalogResponse/$defs/T49"},"state":{"$ref":"#/$defs/CatalogResponse/$defs/T53"}},"required":["definition","state"]};
const schema684 = {"type":"object","additionalProperties":false,"properties":{"object":{"$ref":"#/$defs/CatalogResponse/$defs/T50"},"revision":{"$ref":"#/$defs/CatalogResponse/$defs/T46"},"digest":{"$ref":"#/$defs/CatalogResponse/$defs/T46"}},"required":["object","revision","digest"]};
const schema685 = {"type":"object","additionalProperties":false,"properties":{"scope":{"$ref":"#/$defs/CatalogResponse/$defs/T51"},"branch":{"$ref":"#/$defs/CatalogResponse/$defs/T46"},"object":{"$ref":"#/$defs/CatalogResponse/$defs/T46"}},"required":["scope","branch","object"]};
const schema686 = {"type":"object","additionalProperties":false,"properties":{"realm":{"$ref":"#/$defs/CatalogResponse/$defs/T52"},"resource":{"$ref":"#/$defs/CatalogResponse/$defs/T52"},"catalog":{"$ref":"#/$defs/CatalogResponse/$defs/T46"}},"required":["realm","resource","catalog"]};

function validate2501(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2501.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(!(((typeof data == "number") && (!(data % 1) && !isNaN(data))) && (isFinite(data)))){
validate2501.errors = [{}];
return false;
}
if(errors === 0){
if((typeof data == "number") && (isFinite(data))){
if(data > 9007199254740991 || isNaN(data)){
validate2501.errors = [{}];
return false;
}
else {
if(data < 0 || isNaN(data)){
validate2501.errors = [{}];
return false;
}
}
}
}
validate2501.errors = vErrors;
return errors === 0;
}
validate2501.evaluated = {"dynamicProps":false,"dynamicItems":false};


function validate2500(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2500.evaluated;
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
validate2500.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "realm") || (key0 === "resource")) || (key0 === "catalog"))){
validate2500.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.realm !== undefined){
const _errs2 = errors;
if(!(validate2501(data.realm, {instancePath:instancePath+"/realm",parentData:data,parentDataProperty:"realm",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2501.errors : vErrors.concat(validate2501.errors);
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
if(!(validate2501(data.resource, {instancePath:instancePath+"/resource",parentData:data,parentDataProperty:"resource",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2501.errors : vErrors.concat(validate2501.errors);
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
if(!(validate2493(data.catalog, {instancePath:instancePath+"/catalog",parentData:data,parentDataProperty:"catalog",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2493.errors : vErrors.concat(validate2493.errors);
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
validate2500.errors = [{}];
return false;
}
}
validate2500.errors = vErrors;
return errors === 0;
}
validate2500.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate2499(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2499.evaluated;
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
validate2499.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "scope") || (key0 === "branch")) || (key0 === "object"))){
validate2499.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.scope !== undefined){
const _errs2 = errors;
if(!(validate2500(data.scope, {instancePath:instancePath+"/scope",parentData:data,parentDataProperty:"scope",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2500.errors : vErrors.concat(validate2500.errors);
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
if(!(validate2493(data.branch, {instancePath:instancePath+"/branch",parentData:data,parentDataProperty:"branch",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2493.errors : vErrors.concat(validate2493.errors);
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
if(!(validate2493(data.object, {instancePath:instancePath+"/object",parentData:data,parentDataProperty:"object",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2493.errors : vErrors.concat(validate2493.errors);
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
validate2499.errors = [{}];
return false;
}
}
validate2499.errors = vErrors;
return errors === 0;
}
validate2499.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


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
if((((data.object === undefined) && (missing0 = "object")) || ((data.revision === undefined) && (missing0 = "revision"))) || ((data.digest === undefined) && (missing0 = "digest"))){
validate2498.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "object") || (key0 === "revision")) || (key0 === "digest"))){
validate2498.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.object !== undefined){
const _errs2 = errors;
if(!(validate2499(data.object, {instancePath:instancePath+"/object",parentData:data,parentDataProperty:"object",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2499.errors : vErrors.concat(validate2499.errors);
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
if(!(validate2493(data.revision, {instancePath:instancePath+"/revision",parentData:data,parentDataProperty:"revision",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2493.errors : vErrors.concat(validate2493.errors);
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
if(!(validate2493(data.digest, {instancePath:instancePath+"/digest",parentData:data,parentDataProperty:"digest",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2493.errors : vErrors.concat(validate2493.errors);
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
validate2498.errors = [{}];
return false;
}
}
validate2498.errors = vErrors;
return errors === 0;
}
validate2498.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema281 = {"type":"string","enum":["missing","null","type_error","value","conflict"]};

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
if(typeof data !== "string"){
validate2512.errors = [{}];
return false;
}
if(!(((((data === "missing") || (data === "null")) || (data === "type_error")) || (data === "value")) || (data === "conflict"))){
validate2512.errors = [{}];
return false;
}
validate2512.errors = vErrors;
return errors === 0;
}
validate2512.evaluated = {"dynamicProps":false,"dynamicItems":false};


function validate2497(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2497.evaluated;
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
validate2497.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "definition") || (key0 === "state"))){
validate2497.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.definition !== undefined){
const _errs2 = errors;
if(!(validate2498(data.definition, {instancePath:instancePath+"/definition",parentData:data,parentDataProperty:"definition",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2498.errors : vErrors.concat(validate2498.errors);
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
if(!(validate2512(data.state, {instancePath:instancePath+"/state",parentData:data,parentDataProperty:"state",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2512.errors : vErrors.concat(validate2512.errors);
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
validate2497.errors = [{}];
return false;
}
}
validate2497.errors = vErrors;
return errors === 0;
}
validate2497.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate2495(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2495.evaluated;
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
if(!(validate2493(data.physical, {instancePath:instancePath+"/physical",parentData:data,parentDataProperty:"physical",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2493.errors : vErrors.concat(validate2493.errors);
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
if(!(validate2497(data.initial, {instancePath:instancePath+"/initial",parentData:data,parentDataProperty:"initial",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2497.errors : vErrors.concat(validate2497.errors);
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
validate2495.errors = vErrors;
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
validate2495.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate2495.evaluated = {"dynamicProps":true,"dynamicItems":false};


function validate2492(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2492.evaluated;
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
validate2492.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "column") || (key0 === "source"))){
validate2492.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.column !== undefined){
const _errs2 = errors;
if(!(validate2493(data.column, {instancePath:instancePath+"/column",parentData:data,parentDataProperty:"column",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2493.errors : vErrors.concat(validate2493.errors);
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
if(!(validate2495(data.source, {instancePath:instancePath+"/source",parentData:data,parentDataProperty:"source",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2495.errors : vErrors.concat(validate2495.errors);
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
validate2492.errors = [{}];
return false;
}
}
validate2492.errors = vErrors;
return errors === 0;
}
validate2492.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate2491(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2491.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(Array.isArray(data)){
if(data.length > 128){
validate2491.errors = [{}];
return false;
}
else {
var valid0 = true;
const len0 = data.length;
for(let i0=0; i0<len0; i0++){
const _errs1 = errors;
if(!(validate2492(data[i0], {instancePath:instancePath+"/" + i0,parentData:data,parentDataProperty:i0,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2492.errors : vErrors.concat(validate2492.errors);
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
validate2491.errors = [{}];
return false;
}
}
validate2491.errors = vErrors;
return errors === 0;
}
validate2491.evaluated = {"items":true,"dynamicProps":false,"dynamicItems":false};


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
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if(((((data.physical === undefined) && (missing0 = "physical")) || ((data.schema_revision === undefined) && (missing0 = "schema_revision"))) || ((data.rows === undefined) && (missing0 = "rows"))) || ((data.columns === undefined) && (missing0 = "columns"))){
validate2487.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((((key0 === "physical") || (key0 === "schema_revision")) || (key0 === "rows")) || (key0 === "columns"))){
validate2487.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.physical !== undefined){
const _errs2 = errors;
if(!(validate2478(data.physical, {instancePath:instancePath+"/physical",parentData:data,parentDataProperty:"physical",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2478.errors : vErrors.concat(validate2478.errors);
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
if(!(validate2350(data.schema_revision, {instancePath:instancePath+"/schema_revision",parentData:data,parentDataProperty:"schema_revision",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2350.errors : vErrors.concat(validate2350.errors);
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
if(!(validate2350(data.rows, {instancePath:instancePath+"/rows",parentData:data,parentDataProperty:"rows",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2350.errors : vErrors.concat(validate2350.errors);
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
if(!(validate2491(data.columns, {instancePath:instancePath+"/columns",parentData:data,parentDataProperty:"columns",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2491.errors : vErrors.concat(validate2491.errors);
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
validate2487.errors = [{}];
return false;
}
}
validate2487.errors = vErrors;
return errors === 0;
}
validate2487.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate2486(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2486.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate2487(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2487.errors : vErrors.concat(validate2487.errors);
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
validate2486.errors = vErrors;
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
validate2486.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate2486.evaluated = {"dynamicProps":true,"dynamicItems":false};

const schema689 = {"type":"array","maxItems":8,"items":{"$ref":"#/$defs/CatalogResponse/$defs/T55"}};
const schema690 = {"type":"object","additionalProperties":false,"properties":{"identity":{"$ref":"#/$defs/CatalogResponse/$defs/T56"},"physical":{"$ref":"#/$defs/CatalogResponse/$defs/T59"},"schema_revision":{"$ref":"#/$defs/CatalogResponse/$defs/T57"},"location":{"$ref":"#/$defs/CatalogResponse/$defs/T66"}},"required":["identity","physical","schema_revision","location"]};
const schema691 = {"type":"object","additionalProperties":false,"properties":{"origin":{"$ref":"#/$defs/CatalogResponse/$defs/T57"},"operation":{"$ref":"#/$defs/CatalogResponse/$defs/T57"},"ordinal":{"$ref":"#/$defs/CatalogResponse/$defs/T58"}},"required":["origin","operation","ordinal"]};
const schema692 = {"type":"string","maxLength":262144};

function validate2523(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2523.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(typeof data === "string"){
if(func3(data) > 262144){
validate2523.errors = [{}];
return false;
}
}
else {
validate2523.errors = [{}];
return false;
}
}
validate2523.errors = vErrors;
return errors === 0;
}
validate2523.evaluated = {"dynamicProps":false,"dynamicItems":false};


function validate2526(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2526.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(!(((typeof data == "number") && (!(data % 1) && !isNaN(data))) && (isFinite(data)))){
validate2526.errors = [{}];
return false;
}
if(errors === 0){
if((typeof data == "number") && (isFinite(data))){
if(data > 4294967295 || isNaN(data)){
validate2526.errors = [{}];
return false;
}
else {
if(data < 0 || isNaN(data)){
validate2526.errors = [{}];
return false;
}
}
}
}
validate2526.errors = vErrors;
return errors === 0;
}
validate2526.evaluated = {"dynamicProps":false,"dynamicItems":false};


function validate2522(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2522.evaluated;
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
validate2522.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "origin") || (key0 === "operation")) || (key0 === "ordinal"))){
validate2522.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.origin !== undefined){
const _errs2 = errors;
if(!(validate2523(data.origin, {instancePath:instancePath+"/origin",parentData:data,parentDataProperty:"origin",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2523.errors : vErrors.concat(validate2523.errors);
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
if(!(validate2523(data.operation, {instancePath:instancePath+"/operation",parentData:data,parentDataProperty:"operation",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2523.errors : vErrors.concat(validate2523.errors);
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
if(!(validate2526(data.ordinal, {instancePath:instancePath+"/ordinal",parentData:data,parentDataProperty:"ordinal",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2526.errors : vErrors.concat(validate2526.errors);
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
validate2522.errors = [{}];
return false;
}
}
validate2522.errors = vErrors;
return errors === 0;
}
validate2522.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema694 = {"type":"object","additionalProperties":false,"properties":{"interpretation":{"$ref":"#/$defs/CatalogResponse/$defs/T60"},"content":{"$ref":"#/$defs/CatalogResponse/$defs/T64"},"schema_fingerprint":{"$ref":"#/$defs/CatalogResponse/$defs/T57"},"retired":{"$ref":"#/$defs/CatalogResponse/$defs/T65"}},"required":["interpretation","content","schema_fingerprint","retired"]};
const schema695 = {"type":"object","additionalProperties":false,"properties":{"object":{"$ref":"#/$defs/CatalogResponse/$defs/T61"},"revision":{"$ref":"#/$defs/CatalogResponse/$defs/T57"},"digest":{"$ref":"#/$defs/CatalogResponse/$defs/T57"}},"required":["object","revision","digest"]};
const schema696 = {"type":"object","additionalProperties":false,"properties":{"scope":{"$ref":"#/$defs/CatalogResponse/$defs/T62"},"branch":{"$ref":"#/$defs/CatalogResponse/$defs/T57"},"object":{"$ref":"#/$defs/CatalogResponse/$defs/T57"}},"required":["scope","branch","object"]};
const schema697 = {"type":"object","additionalProperties":false,"properties":{"realm":{"$ref":"#/$defs/CatalogResponse/$defs/T63"},"resource":{"$ref":"#/$defs/CatalogResponse/$defs/T63"},"catalog":{"$ref":"#/$defs/CatalogResponse/$defs/T57"}},"required":["realm","resource","catalog"]};

function validate2533(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2533.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(!(((typeof data == "number") && (!(data % 1) && !isNaN(data))) && (isFinite(data)))){
validate2533.errors = [{}];
return false;
}
if(errors === 0){
if((typeof data == "number") && (isFinite(data))){
if(data > 9007199254740991 || isNaN(data)){
validate2533.errors = [{}];
return false;
}
else {
if(data < 0 || isNaN(data)){
validate2533.errors = [{}];
return false;
}
}
}
}
validate2533.errors = vErrors;
return errors === 0;
}
validate2533.evaluated = {"dynamicProps":false,"dynamicItems":false};


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
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((((data.realm === undefined) && (missing0 = "realm")) || ((data.resource === undefined) && (missing0 = "resource"))) || ((data.catalog === undefined) && (missing0 = "catalog"))){
validate2532.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "realm") || (key0 === "resource")) || (key0 === "catalog"))){
validate2532.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.realm !== undefined){
const _errs2 = errors;
if(!(validate2533(data.realm, {instancePath:instancePath+"/realm",parentData:data,parentDataProperty:"realm",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2533.errors : vErrors.concat(validate2533.errors);
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
if(!(validate2533(data.resource, {instancePath:instancePath+"/resource",parentData:data,parentDataProperty:"resource",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2533.errors : vErrors.concat(validate2533.errors);
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
if(!(validate2523(data.catalog, {instancePath:instancePath+"/catalog",parentData:data,parentDataProperty:"catalog",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2523.errors : vErrors.concat(validate2523.errors);
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
validate2532.errors = [{}];
return false;
}
}
validate2532.errors = vErrors;
return errors === 0;
}
validate2532.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate2531(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2531.evaluated;
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
validate2531.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "scope") || (key0 === "branch")) || (key0 === "object"))){
validate2531.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.scope !== undefined){
const _errs2 = errors;
if(!(validate2532(data.scope, {instancePath:instancePath+"/scope",parentData:data,parentDataProperty:"scope",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2532.errors : vErrors.concat(validate2532.errors);
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
if(!(validate2523(data.branch, {instancePath:instancePath+"/branch",parentData:data,parentDataProperty:"branch",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2523.errors : vErrors.concat(validate2523.errors);
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
if(!(validate2523(data.object, {instancePath:instancePath+"/object",parentData:data,parentDataProperty:"object",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2523.errors : vErrors.concat(validate2523.errors);
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
validate2531.errors = [{}];
return false;
}
}
validate2531.errors = vErrors;
return errors === 0;
}
validate2531.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate2530(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2530.evaluated;
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
validate2530.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "object") || (key0 === "revision")) || (key0 === "digest"))){
validate2530.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.object !== undefined){
const _errs2 = errors;
if(!(validate2531(data.object, {instancePath:instancePath+"/object",parentData:data,parentDataProperty:"object",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2531.errors : vErrors.concat(validate2531.errors);
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
if(!(validate2523(data.revision, {instancePath:instancePath+"/revision",parentData:data,parentDataProperty:"revision",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2523.errors : vErrors.concat(validate2523.errors);
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
if(!(validate2523(data.digest, {instancePath:instancePath+"/digest",parentData:data,parentDataProperty:"digest",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2523.errors : vErrors.concat(validate2523.errors);
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
validate2530.errors = [{}];
return false;
}
}
validate2530.errors = vErrors;
return errors === 0;
}
validate2530.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema699 = {"type":"object","additionalProperties":false,"properties":{"bytes":{"$ref":"#/$defs/CatalogResponse/$defs/T57"},"sha256":{"$ref":"#/$defs/CatalogResponse/$defs/T57"}},"required":["bytes","sha256"]};

function validate2544(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2544.evaluated;
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
validate2544.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "bytes") || (key0 === "sha256"))){
validate2544.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.bytes !== undefined){
const _errs2 = errors;
if(!(validate2523(data.bytes, {instancePath:instancePath+"/bytes",parentData:data,parentDataProperty:"bytes",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2523.errors : vErrors.concat(validate2523.errors);
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
if(!(validate2523(data.sha256, {instancePath:instancePath+"/sha256",parentData:data,parentDataProperty:"sha256",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2523.errors : vErrors.concat(validate2523.errors);
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
validate2544.errors = [{}];
return false;
}
}
validate2544.errors = vErrors;
return errors === 0;
}
validate2544.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema700 = {"type":"boolean"};

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
if(typeof data !== "boolean"){
validate2549.errors = [{}];
return false;
}
validate2549.errors = vErrors;
return errors === 0;
}
validate2549.evaluated = {"dynamicProps":false,"dynamicItems":false};


function validate2529(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2529.evaluated;
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
validate2529.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((((key0 === "interpretation") || (key0 === "content")) || (key0 === "schema_fingerprint")) || (key0 === "retired"))){
validate2529.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.interpretation !== undefined){
const _errs2 = errors;
if(!(validate2530(data.interpretation, {instancePath:instancePath+"/interpretation",parentData:data,parentDataProperty:"interpretation",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2530.errors : vErrors.concat(validate2530.errors);
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
if(!(validate2544(data.content, {instancePath:instancePath+"/content",parentData:data,parentDataProperty:"content",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2544.errors : vErrors.concat(validate2544.errors);
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
if(!(validate2523(data.schema_fingerprint, {instancePath:instancePath+"/schema_fingerprint",parentData:data,parentDataProperty:"schema_fingerprint",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2523.errors : vErrors.concat(validate2523.errors);
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
if(!(validate2549(data.retired, {instancePath:instancePath+"/retired",parentData:data,parentDataProperty:"retired",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2549.errors : vErrors.concat(validate2549.errors);
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
validate2529.errors = [{}];
return false;
}
}
validate2529.errors = vErrors;
return errors === 0;
}
validate2529.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema701 = {"oneOf":[{"type":"object","additionalProperties":false,"required":["wal"],"properties":{"wal":{"$ref":"#/$defs/CatalogResponse/$defs/T67"}}},{"type":"object","additionalProperties":false,"required":["segment"],"properties":{"segment":{"$ref":"#/$defs/CatalogResponse/$defs/T68"}}}]};
const schema702 = {"type":"object","additionalProperties":false,"properties":{"lsn":{"$ref":"#/$defs/CatalogResponse/$defs/T57"},"offset":{"$ref":"#/$defs/CatalogResponse/$defs/T58"},"bytes":{"$ref":"#/$defs/CatalogResponse/$defs/T58"},"row_digest":{"$ref":"#/$defs/CatalogResponse/$defs/T57"}},"required":["lsn","offset","bytes","row_digest"]};

function validate2554(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2554.evaluated;
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
validate2554.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((((key0 === "lsn") || (key0 === "offset")) || (key0 === "bytes")) || (key0 === "row_digest"))){
validate2554.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.lsn !== undefined){
const _errs2 = errors;
if(!(validate2523(data.lsn, {instancePath:instancePath+"/lsn",parentData:data,parentDataProperty:"lsn",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2523.errors : vErrors.concat(validate2523.errors);
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
if(!(validate2526(data.offset, {instancePath:instancePath+"/offset",parentData:data,parentDataProperty:"offset",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2526.errors : vErrors.concat(validate2526.errors);
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
if(!(validate2526(data.bytes, {instancePath:instancePath+"/bytes",parentData:data,parentDataProperty:"bytes",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2526.errors : vErrors.concat(validate2526.errors);
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
if(!(validate2523(data.row_digest, {instancePath:instancePath+"/row_digest",parentData:data,parentDataProperty:"row_digest",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2523.errors : vErrors.concat(validate2523.errors);
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
validate2554.errors = [{}];
return false;
}
}
validate2554.errors = vErrors;
return errors === 0;
}
validate2554.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema703 = {"type":"object","additionalProperties":false,"properties":{"id":{"$ref":"#/$defs/CatalogResponse/$defs/T57"},"row":{"$ref":"#/$defs/CatalogResponse/$defs/T58"},"content":{"$ref":"#/$defs/CatalogResponse/$defs/T64"}},"required":["id","row","content"]};

function validate2560(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2560.evaluated;
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
validate2560.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "id") || (key0 === "row")) || (key0 === "content"))){
validate2560.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.id !== undefined){
const _errs2 = errors;
if(!(validate2523(data.id, {instancePath:instancePath+"/id",parentData:data,parentDataProperty:"id",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2523.errors : vErrors.concat(validate2523.errors);
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
if(!(validate2526(data.row, {instancePath:instancePath+"/row",parentData:data,parentDataProperty:"row",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2526.errors : vErrors.concat(validate2526.errors);
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
if(!(validate2544(data.content, {instancePath:instancePath+"/content",parentData:data,parentDataProperty:"content",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2544.errors : vErrors.concat(validate2544.errors);
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
validate2560.errors = [{}];
return false;
}
}
validate2560.errors = vErrors;
return errors === 0;
}
validate2560.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


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
if(!(validate2554(data.wal, {instancePath:instancePath+"/wal",parentData:data,parentDataProperty:"wal",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2554.errors : vErrors.concat(validate2554.errors);
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
if(!(validate2560(data.segment, {instancePath:instancePath+"/segment",parentData:data,parentDataProperty:"segment",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2560.errors : vErrors.concat(validate2560.errors);
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
validate2553.errors = vErrors;
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
validate2553.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate2553.evaluated = {"dynamicProps":true,"dynamicItems":false};


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
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if(((((data.identity === undefined) && (missing0 = "identity")) || ((data.physical === undefined) && (missing0 = "physical"))) || ((data.schema_revision === undefined) && (missing0 = "schema_revision"))) || ((data.location === undefined) && (missing0 = "location"))){
validate2521.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((((key0 === "identity") || (key0 === "physical")) || (key0 === "schema_revision")) || (key0 === "location"))){
validate2521.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.identity !== undefined){
const _errs2 = errors;
if(!(validate2522(data.identity, {instancePath:instancePath+"/identity",parentData:data,parentDataProperty:"identity",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2522.errors : vErrors.concat(validate2522.errors);
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
if(!(validate2529(data.physical, {instancePath:instancePath+"/physical",parentData:data,parentDataProperty:"physical",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2529.errors : vErrors.concat(validate2529.errors);
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
if(!(validate2523(data.schema_revision, {instancePath:instancePath+"/schema_revision",parentData:data,parentDataProperty:"schema_revision",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2523.errors : vErrors.concat(validate2523.errors);
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
if(!(validate2553(data.location, {instancePath:instancePath+"/location",parentData:data,parentDataProperty:"location",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2553.errors : vErrors.concat(validate2553.errors);
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
validate2521.errors = [{}];
return false;
}
}
validate2521.errors = vErrors;
return errors === 0;
}
validate2521.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


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
if(Array.isArray(data)){
if(data.length > 8){
validate2520.errors = [{}];
return false;
}
else {
var valid0 = true;
const len0 = data.length;
for(let i0=0; i0<len0; i0++){
const _errs1 = errors;
if(!(validate2521(data[i0], {instancePath:instancePath+"/" + i0,parentData:data,parentDataProperty:i0,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2521.errors : vErrors.concat(validate2521.errors);
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
validate2520.errors = [{}];
return false;
}
}
validate2520.errors = vErrors;
return errors === 0;
}
validate2520.evaluated = {"items":true,"dynamicProps":false,"dynamicItems":false};

const schema704 = {"anyOf":[{"$ref":"#/$defs/CatalogResponse/$defs/T70"},{"type":"null"}]};
const schema705 = {"type":"object","additionalProperties":false,"properties":{"selector":{"$ref":"#/$defs/CatalogResponse/$defs/T11"},"object":{"$ref":"#/$defs/CatalogResponse/$defs/T11"},"kind":{"$ref":"#/$defs/CatalogResponse/$defs/T71"},"source":{"$ref":"#/$defs/CatalogResponse/$defs/T38"},"after":{"$ref":"#/$defs/CatalogResponse/$defs/T11"}},"required":["selector","object","kind","source","after"]};

function validate2572(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2572.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate2572.errors = [{}];
return false;
}
if(!((data === "definitions") || (data === "locations"))){
validate2572.errors = [{}];
return false;
}
validate2572.errors = vErrors;
return errors === 0;
}
validate2572.evaluated = {"dynamicProps":false,"dynamicItems":false};


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
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((((((data.selector === undefined) && (missing0 = "selector")) || ((data.object === undefined) && (missing0 = "object"))) || ((data.kind === undefined) && (missing0 = "kind"))) || ((data.source === undefined) && (missing0 = "source"))) || ((data.after === undefined) && (missing0 = "after"))){
validate2569.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((((key0 === "selector") || (key0 === "object")) || (key0 === "kind")) || (key0 === "source")) || (key0 === "after"))){
validate2569.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.selector !== undefined){
const _errs2 = errors;
if(!(validate2350(data.selector, {instancePath:instancePath+"/selector",parentData:data,parentDataProperty:"selector",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2350.errors : vErrors.concat(validate2350.errors);
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
if(!(validate2350(data.object, {instancePath:instancePath+"/object",parentData:data,parentDataProperty:"object",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2350.errors : vErrors.concat(validate2350.errors);
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
if(!(validate2572(data.kind, {instancePath:instancePath+"/kind",parentData:data,parentDataProperty:"kind",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2572.errors : vErrors.concat(validate2572.errors);
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
if(!(validate2461(data.source, {instancePath:instancePath+"/source",parentData:data,parentDataProperty:"source",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2461.errors : vErrors.concat(validate2461.errors);
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
if(!(validate2350(data.after, {instancePath:instancePath+"/after",parentData:data,parentDataProperty:"after",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2350.errors : vErrors.concat(validate2350.errors);
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
validate2569.errors = [{}];
return false;
}
}
validate2569.errors = vErrors;
return errors === 0;
}
validate2569.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate2568(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2568.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate2569(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2569.errors : vErrors.concat(validate2569.errors);
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
validate2568.errors = vErrors;
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
validate2568.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate2568.evaluated = {"dynamicProps":true,"dynamicItems":false};


function validate2451(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2451.evaluated;
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
validate2451.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((((((key0 === "snapshot") || (key0 === "logical")) || (key0 === "accepted")) || (key0 === "total_rows")) || (key0 === "definitions")) || (key0 === "locations")) || (key0 === "next"))){
validate2451.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.snapshot !== undefined){
const _errs2 = errors;
if(!(validate2452(data.snapshot, {instancePath:instancePath+"/snapshot",parentData:data,parentDataProperty:"snapshot",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2452.errors : vErrors.concat(validate2452.errors);
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
if(!(validate2478(data.logical, {instancePath:instancePath+"/logical",parentData:data,parentDataProperty:"logical",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2478.errors : vErrors.concat(validate2478.errors);
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
if(!(validate2415(data.accepted, {instancePath:instancePath+"/accepted",parentData:data,parentDataProperty:"accepted",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2415.errors : vErrors.concat(validate2415.errors);
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
if(!(validate2350(data.total_rows, {instancePath:instancePath+"/total_rows",parentData:data,parentDataProperty:"total_rows",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2350.errors : vErrors.concat(validate2350.errors);
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
if(!(validate2486(data.definitions, {instancePath:instancePath+"/definitions",parentData:data,parentDataProperty:"definitions",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2486.errors : vErrors.concat(validate2486.errors);
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
if(!(validate2520(data.locations, {instancePath:instancePath+"/locations",parentData:data,parentDataProperty:"locations",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2520.errors : vErrors.concat(validate2520.errors);
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
if(!(validate2568(data.next, {instancePath:instancePath+"/next",parentData:data,parentDataProperty:"next",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2568.errors : vErrors.concat(validate2568.errors);
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
validate2451.errors = [{}];
return false;
}
}
validate2451.errors = vErrors;
return errors === 0;
}
validate2451.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema707 = {"anyOf":[{"$ref":"#/$defs/CatalogResponse/$defs/T11"},{"type":"null"}]};

function validate2579(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2579.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate2350(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2350.errors : vErrors.concat(validate2350.errors);
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
validate2579.errors = vErrors;
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
validate2579.errors = vErrors;
return errors === 0;
}
validate2579.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema708 = {"anyOf":[{"$ref":"#/$defs/CatalogResponse/$defs/T74"},{"type":"null"}]};
const schema709 = {"type":"object","additionalProperties":false,"properties":{"scope":{"$ref":"#/$defs/CatalogResponse/$defs/T9"},"id":{"$ref":"#/$defs/CatalogResponse/$defs/T10"},"authorization":{"$ref":"#/$defs/CatalogResponse/$defs/T10"},"name":{"$ref":"#/$defs/CatalogResponse/$defs/T11"},"revision":{"$ref":"#/$defs/CatalogResponse/$defs/T11"}},"required":["scope","id","authorization","name","revision"]};

function validate2583(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2583.evaluated;
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
validate2583.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((((key0 === "scope") || (key0 === "id")) || (key0 === "authorization")) || (key0 === "name")) || (key0 === "revision"))){
validate2583.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.scope !== undefined){
const _errs2 = errors;
if(!(validate2346(data.scope, {instancePath:instancePath+"/scope",parentData:data,parentDataProperty:"scope",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2346.errors : vErrors.concat(validate2346.errors);
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
if(!(validate2347(data.id, {instancePath:instancePath+"/id",parentData:data,parentDataProperty:"id",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2347.errors : vErrors.concat(validate2347.errors);
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
if(!(validate2347(data.authorization, {instancePath:instancePath+"/authorization",parentData:data,parentDataProperty:"authorization",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2347.errors : vErrors.concat(validate2347.errors);
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
if(!(validate2350(data.name, {instancePath:instancePath+"/name",parentData:data,parentDataProperty:"name",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2350.errors : vErrors.concat(validate2350.errors);
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
if(!(validate2350(data.revision, {instancePath:instancePath+"/revision",parentData:data,parentDataProperty:"revision",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2350.errors : vErrors.concat(validate2350.errors);
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
validate2583.errors = [{}];
return false;
}
}
validate2583.errors = vErrors;
return errors === 0;
}
validate2583.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate2582(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2582.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate2583(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2583.errors : vErrors.concat(validate2583.errors);
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
validate2582.errors = vErrors;
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
validate2582.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate2582.evaluated = {"dynamicProps":true,"dynamicItems":false};

const schema710 = {"type":"object","additionalProperties":false,"properties":{"snapshot":{"$ref":"#/$defs/CatalogResponse/$defs/T36"},"namespace":{"$ref":"#/$defs/CatalogResponse/$defs/T10"},"entries":{"$ref":"#/$defs/CatalogResponse/$defs/T76"},"next":{"$ref":"#/$defs/CatalogResponse/$defs/T80"}},"required":["snapshot","namespace","entries","next"]};
const schema711 = {"type":"array","maxItems":8,"items":{"$ref":"#/$defs/CatalogResponse/$defs/T77"}};
const schema712 = {"type":"object","additionalProperties":false,"properties":{"namespace":{"$ref":"#/$defs/CatalogResponse/$defs/T78"},"name":{"$ref":"#/$defs/CatalogResponse/$defs/T57"},"declaration":{"$ref":"#/$defs/CatalogResponse/$defs/T59"},"accepted":{"$ref":"#/$defs/CatalogResponse/$defs/T79"},"catalog":{"$ref":"#/$defs/CatalogResponse/$defs/T79"}},"required":["namespace","name","declaration","accepted","catalog"]};
const schema713 = {"type":"object","additionalProperties":false,"properties":{"scope":{"$ref":"#/$defs/CatalogResponse/$defs/T62"},"id":{"$ref":"#/$defs/CatalogResponse/$defs/T63"},"authorization":{"$ref":"#/$defs/CatalogResponse/$defs/T63"},"name":{"$ref":"#/$defs/CatalogResponse/$defs/T57"},"revision":{"$ref":"#/$defs/CatalogResponse/$defs/T57"}},"required":["scope","id","authorization","name","revision"]};

function validate2596(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2596.evaluated;
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
validate2596.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((((key0 === "scope") || (key0 === "id")) || (key0 === "authorization")) || (key0 === "name")) || (key0 === "revision"))){
validate2596.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.scope !== undefined){
const _errs2 = errors;
if(!(validate2532(data.scope, {instancePath:instancePath+"/scope",parentData:data,parentDataProperty:"scope",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2532.errors : vErrors.concat(validate2532.errors);
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
if(!(validate2533(data.id, {instancePath:instancePath+"/id",parentData:data,parentDataProperty:"id",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2533.errors : vErrors.concat(validate2533.errors);
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
if(!(validate2533(data.authorization, {instancePath:instancePath+"/authorization",parentData:data,parentDataProperty:"authorization",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2533.errors : vErrors.concat(validate2533.errors);
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
if(!(validate2523(data.name, {instancePath:instancePath+"/name",parentData:data,parentDataProperty:"name",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2523.errors : vErrors.concat(validate2523.errors);
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
if(!(validate2523(data.revision, {instancePath:instancePath+"/revision",parentData:data,parentDataProperty:"revision",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2523.errors : vErrors.concat(validate2523.errors);
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
validate2596.errors = [{}];
return false;
}
}
validate2596.errors = vErrors;
return errors === 0;
}
validate2596.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema714 = {"type":"object","additionalProperties":false,"properties":{"partition":{"$ref":"#/$defs/CatalogResponse/$defs/T57"},"next_lsn":{"$ref":"#/$defs/CatalogResponse/$defs/T57"}},"required":["partition","next_lsn"]};

function validate2605(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2605.evaluated;
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
validate2605.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "partition") || (key0 === "next_lsn"))){
validate2605.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.partition !== undefined){
const _errs2 = errors;
if(!(validate2523(data.partition, {instancePath:instancePath+"/partition",parentData:data,parentDataProperty:"partition",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2523.errors : vErrors.concat(validate2523.errors);
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
if(!(validate2523(data.next_lsn, {instancePath:instancePath+"/next_lsn",parentData:data,parentDataProperty:"next_lsn",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2523.errors : vErrors.concat(validate2523.errors);
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
validate2605.errors = [{}];
return false;
}
}
validate2605.errors = vErrors;
return errors === 0;
}
validate2605.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate2595(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2595.evaluated;
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
validate2595.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((((key0 === "namespace") || (key0 === "name")) || (key0 === "declaration")) || (key0 === "accepted")) || (key0 === "catalog"))){
validate2595.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.namespace !== undefined){
const _errs2 = errors;
if(!(validate2596(data.namespace, {instancePath:instancePath+"/namespace",parentData:data,parentDataProperty:"namespace",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2596.errors : vErrors.concat(validate2596.errors);
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
if(!(validate2523(data.name, {instancePath:instancePath+"/name",parentData:data,parentDataProperty:"name",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2523.errors : vErrors.concat(validate2523.errors);
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
if(!(validate2529(data.declaration, {instancePath:instancePath+"/declaration",parentData:data,parentDataProperty:"declaration",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2529.errors : vErrors.concat(validate2529.errors);
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
if(!(validate2605(data.accepted, {instancePath:instancePath+"/accepted",parentData:data,parentDataProperty:"accepted",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2605.errors : vErrors.concat(validate2605.errors);
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
if(!(validate2605(data.catalog, {instancePath:instancePath+"/catalog",parentData:data,parentDataProperty:"catalog",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2605.errors : vErrors.concat(validate2605.errors);
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
validate2595.errors = [{}];
return false;
}
}
validate2595.errors = vErrors;
return errors === 0;
}
validate2595.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate2594(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2594.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(Array.isArray(data)){
if(data.length > 8){
validate2594.errors = [{}];
return false;
}
else {
var valid0 = true;
const len0 = data.length;
for(let i0=0; i0<len0; i0++){
const _errs1 = errors;
if(!(validate2595(data[i0], {instancePath:instancePath+"/" + i0,parentData:data,parentDataProperty:i0,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2595.errors : vErrors.concat(validate2595.errors);
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
validate2594.errors = [{}];
return false;
}
}
validate2594.errors = vErrors;
return errors === 0;
}
validate2594.evaluated = {"items":true,"dynamicProps":false,"dynamicItems":false};

const schema715 = {"anyOf":[{"$ref":"#/$defs/CatalogResponse/$defs/T81"},{"type":"null"}]};
const schema716 = {"type":"object","additionalProperties":false,"properties":{"selector":{"$ref":"#/$defs/CatalogResponse/$defs/T11"},"namespace":{"$ref":"#/$defs/CatalogResponse/$defs/T10"},"directory":{"$ref":"#/$defs/CatalogResponse/$defs/T82"},"after":{"$ref":"#/$defs/CatalogResponse/$defs/T11"}},"required":["selector","namespace","directory","after"]};
const schema717 = {"type":"object","additionalProperties":false,"properties":{"content":{"$ref":"#/$defs/CatalogResponse/$defs/T38"},"count":{"$ref":"#/$defs/CatalogResponse/$defs/T11"},"descriptors":{"$ref":"#/$defs/CatalogResponse/$defs/T11"}},"required":["content","count","descriptors"]};

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
if((((data.content === undefined) && (missing0 = "content")) || ((data.count === undefined) && (missing0 = "count"))) || ((data.descriptors === undefined) && (missing0 = "descriptors"))){
validate2616.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "content") || (key0 === "count")) || (key0 === "descriptors"))){
validate2616.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.content !== undefined){
const _errs2 = errors;
if(!(validate2461(data.content, {instancePath:instancePath+"/content",parentData:data,parentDataProperty:"content",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2461.errors : vErrors.concat(validate2461.errors);
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
if(!(validate2350(data.count, {instancePath:instancePath+"/count",parentData:data,parentDataProperty:"count",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2350.errors : vErrors.concat(validate2350.errors);
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
if(!(validate2350(data.descriptors, {instancePath:instancePath+"/descriptors",parentData:data,parentDataProperty:"descriptors",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2350.errors : vErrors.concat(validate2350.errors);
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
validate2616.errors = [{}];
return false;
}
}
validate2616.errors = vErrors;
return errors === 0;
}
validate2616.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate2613(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2613.evaluated;
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
validate2613.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((((key0 === "selector") || (key0 === "namespace")) || (key0 === "directory")) || (key0 === "after"))){
validate2613.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.selector !== undefined){
const _errs2 = errors;
if(!(validate2350(data.selector, {instancePath:instancePath+"/selector",parentData:data,parentDataProperty:"selector",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2350.errors : vErrors.concat(validate2350.errors);
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
if(!(validate2347(data.namespace, {instancePath:instancePath+"/namespace",parentData:data,parentDataProperty:"namespace",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2347.errors : vErrors.concat(validate2347.errors);
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
if(!(validate2616(data.directory, {instancePath:instancePath+"/directory",parentData:data,parentDataProperty:"directory",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2616.errors : vErrors.concat(validate2616.errors);
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
if(!(validate2350(data.after, {instancePath:instancePath+"/after",parentData:data,parentDataProperty:"after",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2350.errors : vErrors.concat(validate2350.errors);
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
validate2613.errors = [{}];
return false;
}
}
validate2613.errors = vErrors;
return errors === 0;
}
validate2613.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate2612(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2612.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate2613(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2613.errors : vErrors.concat(validate2613.errors);
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
validate2612.errors = vErrors;
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
validate2612.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate2612.evaluated = {"dynamicProps":true,"dynamicItems":false};


function validate2591(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2591.evaluated;
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
validate2591.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((((key0 === "snapshot") || (key0 === "namespace")) || (key0 === "entries")) || (key0 === "next"))){
validate2591.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.snapshot !== undefined){
const _errs2 = errors;
if(!(validate2452(data.snapshot, {instancePath:instancePath+"/snapshot",parentData:data,parentDataProperty:"snapshot",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2452.errors : vErrors.concat(validate2452.errors);
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
if(!(validate2347(data.namespace, {instancePath:instancePath+"/namespace",parentData:data,parentDataProperty:"namespace",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2347.errors : vErrors.concat(validate2347.errors);
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
if(!(validate2594(data.entries, {instancePath:instancePath+"/entries",parentData:data,parentDataProperty:"entries",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2594.errors : vErrors.concat(validate2594.errors);
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
if(!(validate2612(data.next, {instancePath:instancePath+"/next",parentData:data,parentDataProperty:"next",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2612.errors : vErrors.concat(validate2612.errors);
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
validate2591.errors = [{}];
return false;
}
}
validate2591.errors = vErrors;
return errors === 0;
}
validate2591.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema718 = {"type":"object","additionalProperties":false,"properties":{"snapshot":{"$ref":"#/$defs/CatalogResponse/$defs/T36"},"binding":{"$ref":"#/$defs/CatalogResponse/$defs/T84"},"schema":{"$ref":"#/$defs/CatalogResponse/$defs/T85"},"rows":{"$ref":"#/$defs/CatalogResponse/$defs/T11"},"changed_lsn":{"$ref":"#/$defs/CatalogResponse/$defs/T11"},"authority":{"$ref":"#/$defs/CatalogResponse/$defs/T196"}},"required":["snapshot","binding","schema","rows","changed_lsn","authority"]};
const schema719 = {"type":"object","additionalProperties":false,"properties":{"namespace":{"$ref":"#/$defs/CatalogResponse/$defs/T74"},"name":{"$ref":"#/$defs/CatalogResponse/$defs/T11"},"declaration":{"$ref":"#/$defs/CatalogResponse/$defs/T41"},"accepted":{"$ref":"#/$defs/CatalogResponse/$defs/T26"},"catalog":{"$ref":"#/$defs/CatalogResponse/$defs/T26"}},"required":["namespace","name","declaration","accepted","catalog"]};

function validate2627(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2627.evaluated;
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
validate2627.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((((key0 === "namespace") || (key0 === "name")) || (key0 === "declaration")) || (key0 === "accepted")) || (key0 === "catalog"))){
validate2627.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.namespace !== undefined){
const _errs2 = errors;
if(!(validate2583(data.namespace, {instancePath:instancePath+"/namespace",parentData:data,parentDataProperty:"namespace",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2583.errors : vErrors.concat(validate2583.errors);
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
if(!(validate2350(data.name, {instancePath:instancePath+"/name",parentData:data,parentDataProperty:"name",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2350.errors : vErrors.concat(validate2350.errors);
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
if(!(validate2478(data.declaration, {instancePath:instancePath+"/declaration",parentData:data,parentDataProperty:"declaration",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2478.errors : vErrors.concat(validate2478.errors);
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
if(!(validate2415(data.accepted, {instancePath:instancePath+"/accepted",parentData:data,parentDataProperty:"accepted",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2415.errors : vErrors.concat(validate2415.errors);
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
if(!(validate2415(data.catalog, {instancePath:instancePath+"/catalog",parentData:data,parentDataProperty:"catalog",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2415.errors : vErrors.concat(validate2415.errors);
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
validate2627.errors = [{}];
return false;
}
}
validate2627.errors = vErrors;
return errors === 0;
}
validate2627.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema720 = {"type":"object","additionalProperties":false,"properties":{"definition":{"$ref":"#/$defs/CatalogResponse/$defs/T4"},"object":{"$ref":"#/$defs/CatalogResponse/$defs/T11"},"revision":{"$ref":"#/$defs/CatalogResponse/$defs/T11"},"next_column":{"$ref":"#/$defs/CatalogResponse/$defs/T11"},"columns":{"$ref":"#/$defs/CatalogResponse/$defs/T86"},"primary_key":{"$ref":"#/$defs/CatalogResponse/$defs/T165"},"integrity":{"$ref":"#/$defs/CatalogResponse/$defs/T166"}},"required":["definition","object","revision","next_column","columns","primary_key","integrity"]};
const schema721 = {"type":"array","maxItems":128,"items":{"$ref":"#/$defs/CatalogResponse/$defs/T87"}};
const schema722 = {"type":"object","additionalProperties":false,"properties":{"id":{"$ref":"#/$defs/CatalogResponse/$defs/T46"},"name":{"$ref":"#/$defs/CatalogResponse/$defs/T46"},"type":{"$ref":"#/$defs/CatalogResponse/$defs/T88"},"nullable":{"$ref":"#/$defs/CatalogResponse/$defs/T106"},"default":{"$ref":"#/$defs/CatalogResponse/$defs/T112"},"max_characters":{"$ref":"#/$defs/CatalogResponse/$defs/T144"},"encoding":{"$ref":"#/$defs/CatalogResponse/$defs/T145"},"collation":{"$ref":"#/$defs/CatalogResponse/$defs/T146"},"semantics":{"$ref":"#/$defs/CatalogResponse/$defs/T147"}},"required":["id","name","type","nullable","default","max_characters","encoding","collation","semantics"]};
const schema723 = {"oneOf":[{"type":"object","additionalProperties":false,"required":["int64"],"properties":{"int64":{"$ref":"#/$defs/CatalogResponse/$defs/T89"}}},{"type":"object","additionalProperties":false,"required":["uint64"],"properties":{"uint64":{"$ref":"#/$defs/CatalogResponse/$defs/T89"}}},{"type":"object","additionalProperties":false,"required":["float64"],"properties":{"float64":{"$ref":"#/$defs/CatalogResponse/$defs/T89"}}},{"type":"object","additionalProperties":false,"required":["boolean"],"properties":{"boolean":{"$ref":"#/$defs/CatalogResponse/$defs/T89"}}},{"type":"object","additionalProperties":false,"required":["utf8"],"properties":{"utf8":{"$ref":"#/$defs/CatalogResponse/$defs/T89"}}},{"type":"object","additionalProperties":false,"required":["binary"],"properties":{"binary":{"$ref":"#/$defs/CatalogResponse/$defs/T89"}}},{"type":"object","additionalProperties":false,"required":["int8"],"properties":{"int8":{"$ref":"#/$defs/CatalogResponse/$defs/T89"}}},{"type":"object","additionalProperties":false,"required":["int16"],"properties":{"int16":{"$ref":"#/$defs/CatalogResponse/$defs/T89"}}},{"type":"object","additionalProperties":false,"required":["int32"],"properties":{"int32":{"$ref":"#/$defs/CatalogResponse/$defs/T89"}}},{"type":"object","additionalProperties":false,"required":["int128"],"properties":{"int128":{"$ref":"#/$defs/CatalogResponse/$defs/T89"}}},{"type":"object","additionalProperties":false,"required":["uint8"],"properties":{"uint8":{"$ref":"#/$defs/CatalogResponse/$defs/T89"}}},{"type":"object","additionalProperties":false,"required":["uint16"],"properties":{"uint16":{"$ref":"#/$defs/CatalogResponse/$defs/T89"}}},{"type":"object","additionalProperties":false,"required":["uint32"],"properties":{"uint32":{"$ref":"#/$defs/CatalogResponse/$defs/T89"}}},{"type":"object","additionalProperties":false,"required":["uint128"],"properties":{"uint128":{"$ref":"#/$defs/CatalogResponse/$defs/T89"}}},{"type":"object","additionalProperties":false,"required":["float32"],"properties":{"float32":{"$ref":"#/$defs/CatalogResponse/$defs/T89"}}},{"type":"object","additionalProperties":false,"required":["decimal"],"properties":{"decimal":{"$ref":"#/$defs/CatalogResponse/$defs/T90"}}},{"type":"object","additionalProperties":false,"required":["date"],"properties":{"date":{"$ref":"#/$defs/CatalogResponse/$defs/T89"}}},{"type":"object","additionalProperties":false,"required":["time"],"properties":{"time":{"$ref":"#/$defs/CatalogResponse/$defs/T89"}}},{"type":"object","additionalProperties":false,"required":["timestamp"],"properties":{"timestamp":{"$ref":"#/$defs/CatalogResponse/$defs/T92"}}},{"type":"object","additionalProperties":false,"required":["interval"],"properties":{"interval":{"$ref":"#/$defs/CatalogResponse/$defs/T89"}}},{"type":"object","additionalProperties":false,"required":["uuid"],"properties":{"uuid":{"$ref":"#/$defs/CatalogResponse/$defs/T89"}}},{"type":"object","additionalProperties":false,"required":["structure"],"properties":{"structure":{"$ref":"#/$defs/CatalogResponse/$defs/T93"}}},{"type":"object","additionalProperties":false,"required":["list"],"properties":{"list":{"$ref":"#/$defs/CatalogResponse/$defs/T104"}}},{"type":"object","additionalProperties":false,"required":["array"],"properties":{"array":{"$ref":"#/$defs/CatalogResponse/$defs/T107"}}},{"type":"object","additionalProperties":false,"required":["map"],"properties":{"map":{"$ref":"#/$defs/CatalogResponse/$defs/T109"}}},{"type":"object","additionalProperties":false,"required":["tagged_union"],"properties":{"tagged_union":{"$ref":"#/$defs/CatalogResponse/$defs/T93"}}},{"type":"object","additionalProperties":false,"required":["json"],"properties":{"json":{"$ref":"#/$defs/CatalogResponse/$defs/T89"}}},{"type":"object","additionalProperties":false,"required":["range"],"properties":{"range":{"$ref":"#/$defs/CatalogResponse/$defs/T105"}}},{"type":"object","additionalProperties":false,"required":["multirange"],"properties":{"multirange":{"$ref":"#/$defs/CatalogResponse/$defs/T105"}}},{"type":"object","additionalProperties":false,"required":["vector"],"properties":{"vector":{"$ref":"#/$defs/CatalogResponse/$defs/T110"}}}]};
const schema724 = {"type":"object","maxProperties":0};

function validate2644(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2644.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
if(Object.keys(data).length > 0){
validate2644.errors = [{}];
return false;
}
}
else {
validate2644.errors = [{}];
return false;
}
}
validate2644.errors = vErrors;
return errors === 0;
}
validate2644.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema725 = {"type":"object","additionalProperties":false,"properties":{"precision":{"$ref":"#/$defs/CatalogResponse/$defs/T91"},"scale":{"$ref":"#/$defs/CatalogResponse/$defs/T91"}},"required":["precision","scale"]};

function validate2661(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2661.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(!(((typeof data == "number") && (!(data % 1) && !isNaN(data))) && (isFinite(data)))){
validate2661.errors = [{}];
return false;
}
if(errors === 0){
if((typeof data == "number") && (isFinite(data))){
if(data > 255 || isNaN(data)){
validate2661.errors = [{}];
return false;
}
else {
if(data < 0 || isNaN(data)){
validate2661.errors = [{}];
return false;
}
}
}
}
validate2661.errors = vErrors;
return errors === 0;
}
validate2661.evaluated = {"dynamicProps":false,"dynamicItems":false};


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
if(((data.precision === undefined) && (missing0 = "precision")) || ((data.scale === undefined) && (missing0 = "scale"))){
validate2660.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "precision") || (key0 === "scale"))){
validate2660.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.precision !== undefined){
const _errs2 = errors;
if(!(validate2661(data.precision, {instancePath:instancePath+"/precision",parentData:data,parentDataProperty:"precision",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2661.errors : vErrors.concat(validate2661.errors);
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
if(!(validate2661(data.scale, {instancePath:instancePath+"/scale",parentData:data,parentDataProperty:"scale",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2661.errors : vErrors.concat(validate2661.errors);
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
validate2660.errors = [{}];
return false;
}
}
validate2660.errors = vErrors;
return errors === 0;
}
validate2660.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema181 = {"type":"string","enum":["civil","utc"]};

function validate2667(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2667.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate2667.errors = [{}];
return false;
}
if(!((data === "civil") || (data === "utc"))){
validate2667.errors = [{}];
return false;
}
validate2667.errors = vErrors;
return errors === 0;
}
validate2667.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema728 = {"type":"array","maxItems":256,"items":{"$ref":"#/$defs/CatalogResponse/$defs/T94"}};
const schema729 = {"type":"object","additionalProperties":false,"properties":{"name":{"$ref":"#/$defs/CatalogResponse/$defs/T11"},"type":{"$ref":"#/$defs/CatalogResponse/$defs/T95"},"nullable":{"$ref":"#/$defs/CatalogResponse/$defs/T17"},"optional":{"$ref":"#/$defs/CatalogResponse/$defs/T17"}},"required":["name","type","nullable","optional"]};
const schema730 = {"oneOf":[{"type":"object","additionalProperties":false,"required":["int64"],"properties":{"int64":{"$ref":"#/$defs/CatalogResponse/$defs/T25"}}},{"type":"object","additionalProperties":false,"required":["uint64"],"properties":{"uint64":{"$ref":"#/$defs/CatalogResponse/$defs/T25"}}},{"type":"object","additionalProperties":false,"required":["float64"],"properties":{"float64":{"$ref":"#/$defs/CatalogResponse/$defs/T25"}}},{"type":"object","additionalProperties":false,"required":["boolean"],"properties":{"boolean":{"$ref":"#/$defs/CatalogResponse/$defs/T25"}}},{"type":"object","additionalProperties":false,"required":["utf8"],"properties":{"utf8":{"$ref":"#/$defs/CatalogResponse/$defs/T25"}}},{"type":"object","additionalProperties":false,"required":["binary"],"properties":{"binary":{"$ref":"#/$defs/CatalogResponse/$defs/T25"}}},{"type":"object","additionalProperties":false,"required":["int8"],"properties":{"int8":{"$ref":"#/$defs/CatalogResponse/$defs/T25"}}},{"type":"object","additionalProperties":false,"required":["int16"],"properties":{"int16":{"$ref":"#/$defs/CatalogResponse/$defs/T25"}}},{"type":"object","additionalProperties":false,"required":["int32"],"properties":{"int32":{"$ref":"#/$defs/CatalogResponse/$defs/T25"}}},{"type":"object","additionalProperties":false,"required":["int128"],"properties":{"int128":{"$ref":"#/$defs/CatalogResponse/$defs/T25"}}},{"type":"object","additionalProperties":false,"required":["uint8"],"properties":{"uint8":{"$ref":"#/$defs/CatalogResponse/$defs/T25"}}},{"type":"object","additionalProperties":false,"required":["uint16"],"properties":{"uint16":{"$ref":"#/$defs/CatalogResponse/$defs/T25"}}},{"type":"object","additionalProperties":false,"required":["uint32"],"properties":{"uint32":{"$ref":"#/$defs/CatalogResponse/$defs/T25"}}},{"type":"object","additionalProperties":false,"required":["uint128"],"properties":{"uint128":{"$ref":"#/$defs/CatalogResponse/$defs/T25"}}},{"type":"object","additionalProperties":false,"required":["float32"],"properties":{"float32":{"$ref":"#/$defs/CatalogResponse/$defs/T25"}}},{"type":"object","additionalProperties":false,"required":["decimal"],"properties":{"decimal":{"$ref":"#/$defs/CatalogResponse/$defs/T96"}}},{"type":"object","additionalProperties":false,"required":["date"],"properties":{"date":{"$ref":"#/$defs/CatalogResponse/$defs/T25"}}},{"type":"object","additionalProperties":false,"required":["time"],"properties":{"time":{"$ref":"#/$defs/CatalogResponse/$defs/T25"}}},{"type":"object","additionalProperties":false,"required":["timestamp"],"properties":{"timestamp":{"$ref":"#/$defs/CatalogResponse/$defs/T97"}}},{"type":"object","additionalProperties":false,"required":["interval"],"properties":{"interval":{"$ref":"#/$defs/CatalogResponse/$defs/T25"}}},{"type":"object","additionalProperties":false,"required":["uuid"],"properties":{"uuid":{"$ref":"#/$defs/CatalogResponse/$defs/T25"}}},{"type":"object","additionalProperties":false,"required":["structure"],"properties":{"structure":{"$ref":"#/$defs/CatalogResponse/$defs/T93"}}},{"type":"object","additionalProperties":false,"required":["list"],"properties":{"list":{"$ref":"#/$defs/CatalogResponse/$defs/T98"}}},{"type":"object","additionalProperties":false,"required":["array"],"properties":{"array":{"$ref":"#/$defs/CatalogResponse/$defs/T100"}}},{"type":"object","additionalProperties":false,"required":["map"],"properties":{"map":{"$ref":"#/$defs/CatalogResponse/$defs/T101"}}},{"type":"object","additionalProperties":false,"required":["tagged_union"],"properties":{"tagged_union":{"$ref":"#/$defs/CatalogResponse/$defs/T93"}}},{"type":"object","additionalProperties":false,"required":["json"],"properties":{"json":{"$ref":"#/$defs/CatalogResponse/$defs/T25"}}},{"type":"object","additionalProperties":false,"required":["range"],"properties":{"range":{"$ref":"#/$defs/CatalogResponse/$defs/T99"}}},{"type":"object","additionalProperties":false,"required":["multirange"],"properties":{"multirange":{"$ref":"#/$defs/CatalogResponse/$defs/T99"}}},{"type":"object","additionalProperties":false,"required":["vector"],"properties":{"vector":{"$ref":"#/$defs/CatalogResponse/$defs/T102"}}}]};
const schema731 = {"type":"object","additionalProperties":false,"properties":{"precision":{"$ref":"#/$defs/CatalogResponse/$defs/T3"},"scale":{"$ref":"#/$defs/CatalogResponse/$defs/T3"}},"required":["precision","scale"]};

function validate2690(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2690.evaluated;
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
validate2690.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "precision") || (key0 === "scale"))){
validate2690.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.precision !== undefined){
const _errs2 = errors;
if(!(validate2330(data.precision, {instancePath:instancePath+"/precision",parentData:data,parentDataProperty:"precision",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2330.errors : vErrors.concat(validate2330.errors);
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
if(!(validate2330(data.scale, {instancePath:instancePath+"/scale",parentData:data,parentDataProperty:"scale",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2330.errors : vErrors.concat(validate2330.errors);
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
validate2690.errors = [{}];
return false;
}
}
validate2690.errors = vErrors;
return errors === 0;
}
validate2690.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate2696(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2696.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate2696.errors = [{}];
return false;
}
if(!((data === "civil") || (data === "utc"))){
validate2696.errors = [{}];
return false;
}
validate2696.errors = vErrors;
return errors === 0;
}
validate2696.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema733 = {"type":"object","additionalProperties":false,"properties":{"type":{"$ref":"#/$defs/CatalogResponse/$defs/T99"},"nullable":{"$ref":"#/$defs/CatalogResponse/$defs/T17"}},"required":["type","nullable"]};
const wrapper37 = {validate: validate2674};

function validate2700(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2700.evaluated;
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
validate2700.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "type") || (key0 === "nullable"))){
validate2700.errors = [{}];
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
if(!(validate2389(data.nullable, {instancePath:instancePath+"/nullable",parentData:data,parentDataProperty:"nullable",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2389.errors : vErrors.concat(validate2389.errors);
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
validate2700.errors = [{}];
return false;
}
}
validate2700.errors = vErrors;
return errors === 0;
}
validate2700.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema734 = {"type":"object","additionalProperties":false,"properties":{"element":{"$ref":"#/$defs/CatalogResponse/$defs/T98"},"length":{"$ref":"#/$defs/CatalogResponse/$defs/T6"}},"required":["element","length"]};

function validate2703(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2703.evaluated;
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
validate2703.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "element") || (key0 === "length"))){
validate2703.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.element !== undefined){
const _errs2 = errors;
if(!(validate2700(data.element, {instancePath:instancePath+"/element",parentData:data,parentDataProperty:"element",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2700.errors : vErrors.concat(validate2700.errors);
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
if(!(validate2338(data.length, {instancePath:instancePath+"/length",parentData:data,parentDataProperty:"length",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2338.errors : vErrors.concat(validate2338.errors);
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
validate2703.errors = [{}];
return false;
}
}
validate2703.errors = vErrors;
return errors === 0;
}
validate2703.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema735 = {"type":"object","additionalProperties":false,"properties":{"key":{"$ref":"#/$defs/CatalogResponse/$defs/T99"},"value":{"$ref":"#/$defs/CatalogResponse/$defs/T98"}},"required":["key","value"]};

function validate2707(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2707.evaluated;
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
validate2707.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "key") || (key0 === "value"))){
validate2707.errors = [{}];
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
if(!(validate2700(data.value, {instancePath:instancePath+"/value",parentData:data,parentDataProperty:"value",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2700.errors : vErrors.concat(validate2700.errors);
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
validate2707.errors = [{}];
return false;
}
}
validate2707.errors = vErrors;
return errors === 0;
}
validate2707.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema736 = {"type":"object","additionalProperties":false,"properties":{"dimensions":{"$ref":"#/$defs/CatalogResponse/$defs/T6"},"element":{"$ref":"#/$defs/CatalogResponse/$defs/T103"}},"required":["dimensions","element"]};
const schema197 = {"type":"string","enum":["float32","float16","bfloat16","int8","binary"]};

function validate2713(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2713.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate2713.errors = [{}];
return false;
}
if(!(((((data === "float32") || (data === "float16")) || (data === "bfloat16")) || (data === "int8")) || (data === "binary"))){
validate2713.errors = [{}];
return false;
}
validate2713.errors = vErrors;
return errors === 0;
}
validate2713.evaluated = {"dynamicProps":false,"dynamicItems":false};


function validate2711(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2711.evaluated;
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
validate2711.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "dimensions") || (key0 === "element"))){
validate2711.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.dimensions !== undefined){
const _errs2 = errors;
if(!(validate2338(data.dimensions, {instancePath:instancePath+"/dimensions",parentData:data,parentDataProperty:"dimensions",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2338.errors : vErrors.concat(validate2338.errors);
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
if(!(validate2713(data.element, {instancePath:instancePath+"/element",parentData:data,parentDataProperty:"element",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2713.errors : vErrors.concat(validate2713.errors);
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
validate2711.errors = [{}];
return false;
}
}
validate2711.errors = vErrors;
return errors === 0;
}
validate2711.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const wrapper36 = {validate: validate2671};

function validate2674(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2674.evaluated;
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
if(!(validate2410(data.int64, {instancePath:instancePath+"/int64",parentData:data,parentDataProperty:"int64",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2410.errors : vErrors.concat(validate2410.errors);
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
if(!(validate2410(data.uint64, {instancePath:instancePath+"/uint64",parentData:data,parentDataProperty:"uint64",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2410.errors : vErrors.concat(validate2410.errors);
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
if(!(validate2410(data.float64, {instancePath:instancePath+"/float64",parentData:data,parentDataProperty:"float64",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2410.errors : vErrors.concat(validate2410.errors);
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
if(!(validate2410(data.boolean, {instancePath:instancePath+"/boolean",parentData:data,parentDataProperty:"boolean",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2410.errors : vErrors.concat(validate2410.errors);
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
if(!(validate2410(data.utf8, {instancePath:instancePath+"/utf8",parentData:data,parentDataProperty:"utf8",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2410.errors : vErrors.concat(validate2410.errors);
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
if(!(validate2410(data.binary, {instancePath:instancePath+"/binary",parentData:data,parentDataProperty:"binary",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2410.errors : vErrors.concat(validate2410.errors);
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
if(!(validate2410(data.int8, {instancePath:instancePath+"/int8",parentData:data,parentDataProperty:"int8",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2410.errors : vErrors.concat(validate2410.errors);
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
if(!(validate2410(data.int16, {instancePath:instancePath+"/int16",parentData:data,parentDataProperty:"int16",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2410.errors : vErrors.concat(validate2410.errors);
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
if(!(validate2410(data.int32, {instancePath:instancePath+"/int32",parentData:data,parentDataProperty:"int32",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2410.errors : vErrors.concat(validate2410.errors);
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
if(!(validate2410(data.int128, {instancePath:instancePath+"/int128",parentData:data,parentDataProperty:"int128",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2410.errors : vErrors.concat(validate2410.errors);
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
if(!(validate2410(data.uint8, {instancePath:instancePath+"/uint8",parentData:data,parentDataProperty:"uint8",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2410.errors : vErrors.concat(validate2410.errors);
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
if(!(validate2410(data.uint16, {instancePath:instancePath+"/uint16",parentData:data,parentDataProperty:"uint16",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2410.errors : vErrors.concat(validate2410.errors);
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
if(!(validate2410(data.uint32, {instancePath:instancePath+"/uint32",parentData:data,parentDataProperty:"uint32",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2410.errors : vErrors.concat(validate2410.errors);
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
if(!(validate2410(data.uint128, {instancePath:instancePath+"/uint128",parentData:data,parentDataProperty:"uint128",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2410.errors : vErrors.concat(validate2410.errors);
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
if(!(validate2410(data.float32, {instancePath:instancePath+"/float32",parentData:data,parentDataProperty:"float32",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2410.errors : vErrors.concat(validate2410.errors);
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
if(!(validate2690(data.decimal, {instancePath:instancePath+"/decimal",parentData:data,parentDataProperty:"decimal",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2690.errors : vErrors.concat(validate2690.errors);
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
if(!(validate2410(data.date, {instancePath:instancePath+"/date",parentData:data,parentDataProperty:"date",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2410.errors : vErrors.concat(validate2410.errors);
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
if(!(validate2410(data.time, {instancePath:instancePath+"/time",parentData:data,parentDataProperty:"time",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2410.errors : vErrors.concat(validate2410.errors);
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
if(!(validate2696(data.timestamp, {instancePath:instancePath+"/timestamp",parentData:data,parentDataProperty:"timestamp",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2696.errors : vErrors.concat(validate2696.errors);
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
if(!(validate2410(data.interval, {instancePath:instancePath+"/interval",parentData:data,parentDataProperty:"interval",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2410.errors : vErrors.concat(validate2410.errors);
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
if(!(validate2410(data.uuid, {instancePath:instancePath+"/uuid",parentData:data,parentDataProperty:"uuid",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2410.errors : vErrors.concat(validate2410.errors);
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
if(!(validate2700(data.list, {instancePath:instancePath+"/list",parentData:data,parentDataProperty:"list",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2700.errors : vErrors.concat(validate2700.errors);
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
if(!(validate2703(data.array, {instancePath:instancePath+"/array",parentData:data,parentDataProperty:"array",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2703.errors : vErrors.concat(validate2703.errors);
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
if(!(validate2707(data.map, {instancePath:instancePath+"/map",parentData:data,parentDataProperty:"map",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2707.errors : vErrors.concat(validate2707.errors);
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
if(!(validate2410(data.json, {instancePath:instancePath+"/json",parentData:data,parentDataProperty:"json",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2410.errors : vErrors.concat(validate2410.errors);
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
if(!(validate2711(data.vector, {instancePath:instancePath+"/vector",parentData:data,parentDataProperty:"vector",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2711.errors : vErrors.concat(validate2711.errors);
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
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
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
const err90 = {};
if(vErrors === null){
vErrors = [err90];
}
else {
vErrors.push(err90);
}
errors++;
validate2674.errors = vErrors;
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
validate2674.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate2674.evaluated = {"dynamicProps":true,"dynamicItems":false};


function validate2672(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2672.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if(((((data.name === undefined) && (missing0 = "name")) || ((data.type === undefined) && (missing0 = "type"))) || ((data.nullable === undefined) && (missing0 = "nullable"))) || ((data.optional === undefined) && (missing0 = "optional"))){
validate2672.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((((key0 === "name") || (key0 === "type")) || (key0 === "nullable")) || (key0 === "optional"))){
validate2672.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.name !== undefined){
const _errs2 = errors;
if(!(validate2350(data.name, {instancePath:instancePath+"/name",parentData:data,parentDataProperty:"name",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2350.errors : vErrors.concat(validate2350.errors);
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
if(!(validate2674(data.type, {instancePath:instancePath+"/type",parentData:data,parentDataProperty:"type",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2674.errors : vErrors.concat(validate2674.errors);
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
if(!(validate2389(data.nullable, {instancePath:instancePath+"/nullable",parentData:data,parentDataProperty:"nullable",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2389.errors : vErrors.concat(validate2389.errors);
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
if(!(validate2389(data.optional, {instancePath:instancePath+"/optional",parentData:data,parentDataProperty:"optional",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2389.errors : vErrors.concat(validate2389.errors);
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
validate2672.errors = [{}];
return false;
}
}
validate2672.errors = vErrors;
return errors === 0;
}
validate2672.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate2671(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2671.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(Array.isArray(data)){
if(data.length > 256){
validate2671.errors = [{}];
return false;
}
else {
var valid0 = true;
const len0 = data.length;
for(let i0=0; i0<len0; i0++){
const _errs1 = errors;
if(!(validate2672(data[i0], {instancePath:instancePath+"/" + i0,parentData:data,parentDataProperty:i0,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2672.errors : vErrors.concat(validate2672.errors);
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
validate2671.errors = [{}];
return false;
}
}
validate2671.errors = vErrors;
return errors === 0;
}
validate2671.evaluated = {"items":true,"dynamicProps":false,"dynamicItems":false};

const schema738 = {"type":"object","additionalProperties":false,"properties":{"type":{"$ref":"#/$defs/CatalogResponse/$defs/T105"},"nullable":{"$ref":"#/$defs/CatalogResponse/$defs/T106"}},"required":["type","nullable"]};
const wrapper42 = {validate: validate2643};
const schema739 = {"type":"boolean"};

function validate2722(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2722.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "boolean"){
validate2722.errors = [{}];
return false;
}
validate2722.errors = vErrors;
return errors === 0;
}
validate2722.evaluated = {"dynamicProps":false,"dynamicItems":false};


function validate2721(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2721.evaluated;
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
validate2721.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "type") || (key0 === "nullable"))){
validate2721.errors = [{}];
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
if(!(validate2722(data.nullable, {instancePath:instancePath+"/nullable",parentData:data,parentDataProperty:"nullable",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2722.errors : vErrors.concat(validate2722.errors);
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
validate2721.errors = [{}];
return false;
}
}
validate2721.errors = vErrors;
return errors === 0;
}
validate2721.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema740 = {"type":"object","additionalProperties":false,"properties":{"element":{"$ref":"#/$defs/CatalogResponse/$defs/T104"},"length":{"$ref":"#/$defs/CatalogResponse/$defs/T108"}},"required":["element","length"]};

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
if(!(((typeof data == "number") && (!(data % 1) && !isNaN(data))) && (isFinite(data)))){
validate2727.errors = [{}];
return false;
}
if(errors === 0){
if((typeof data == "number") && (isFinite(data))){
if(data > 4294967295 || isNaN(data)){
validate2727.errors = [{}];
return false;
}
else {
if(data < 0 || isNaN(data)){
validate2727.errors = [{}];
return false;
}
}
}
}
validate2727.errors = vErrors;
return errors === 0;
}
validate2727.evaluated = {"dynamicProps":false,"dynamicItems":false};


function validate2725(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2725.evaluated;
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
validate2725.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "element") || (key0 === "length"))){
validate2725.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.element !== undefined){
const _errs2 = errors;
if(!(validate2721(data.element, {instancePath:instancePath+"/element",parentData:data,parentDataProperty:"element",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2721.errors : vErrors.concat(validate2721.errors);
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
if(!(validate2727(data.length, {instancePath:instancePath+"/length",parentData:data,parentDataProperty:"length",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2727.errors : vErrors.concat(validate2727.errors);
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
validate2725.errors = [{}];
return false;
}
}
validate2725.errors = vErrors;
return errors === 0;
}
validate2725.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema742 = {"type":"object","additionalProperties":false,"properties":{"key":{"$ref":"#/$defs/CatalogResponse/$defs/T105"},"value":{"$ref":"#/$defs/CatalogResponse/$defs/T104"}},"required":["key","value"]};

function validate2730(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2730.evaluated;
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
validate2730.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "key") || (key0 === "value"))){
validate2730.errors = [{}];
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
if(!(validate2721(data.value, {instancePath:instancePath+"/value",parentData:data,parentDataProperty:"value",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2721.errors : vErrors.concat(validate2721.errors);
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
validate2730.errors = [{}];
return false;
}
}
validate2730.errors = vErrors;
return errors === 0;
}
validate2730.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema743 = {"type":"object","additionalProperties":false,"properties":{"dimensions":{"$ref":"#/$defs/CatalogResponse/$defs/T108"},"element":{"$ref":"#/$defs/CatalogResponse/$defs/T111"}},"required":["dimensions","element"]};

function validate2737(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2737.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate2737.errors = [{}];
return false;
}
if(!(((((data === "float32") || (data === "float16")) || (data === "bfloat16")) || (data === "int8")) || (data === "binary"))){
validate2737.errors = [{}];
return false;
}
validate2737.errors = vErrors;
return errors === 0;
}
validate2737.evaluated = {"dynamicProps":false,"dynamicItems":false};


function validate2735(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2735.evaluated;
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
validate2735.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "dimensions") || (key0 === "element"))){
validate2735.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.dimensions !== undefined){
const _errs2 = errors;
if(!(validate2727(data.dimensions, {instancePath:instancePath+"/dimensions",parentData:data,parentDataProperty:"dimensions",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2727.errors : vErrors.concat(validate2727.errors);
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
if(!(validate2737(data.element, {instancePath:instancePath+"/element",parentData:data,parentDataProperty:"element",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2737.errors : vErrors.concat(validate2737.errors);
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
validate2735.errors = [{}];
return false;
}
}
validate2735.errors = vErrors;
return errors === 0;
}
validate2735.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate2643(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2643.evaluated;
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
if(!(validate2644(data.int64, {instancePath:instancePath+"/int64",parentData:data,parentDataProperty:"int64",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2644.errors : vErrors.concat(validate2644.errors);
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
if(!(validate2644(data.uint64, {instancePath:instancePath+"/uint64",parentData:data,parentDataProperty:"uint64",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2644.errors : vErrors.concat(validate2644.errors);
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
if(!(validate2644(data.float64, {instancePath:instancePath+"/float64",parentData:data,parentDataProperty:"float64",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2644.errors : vErrors.concat(validate2644.errors);
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
if(!(validate2644(data.boolean, {instancePath:instancePath+"/boolean",parentData:data,parentDataProperty:"boolean",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2644.errors : vErrors.concat(validate2644.errors);
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
if(!(validate2644(data.utf8, {instancePath:instancePath+"/utf8",parentData:data,parentDataProperty:"utf8",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2644.errors : vErrors.concat(validate2644.errors);
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
if(!(validate2644(data.binary, {instancePath:instancePath+"/binary",parentData:data,parentDataProperty:"binary",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2644.errors : vErrors.concat(validate2644.errors);
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
if(!(validate2644(data.int8, {instancePath:instancePath+"/int8",parentData:data,parentDataProperty:"int8",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2644.errors : vErrors.concat(validate2644.errors);
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
if(!(validate2644(data.int16, {instancePath:instancePath+"/int16",parentData:data,parentDataProperty:"int16",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2644.errors : vErrors.concat(validate2644.errors);
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
if(!(validate2644(data.int32, {instancePath:instancePath+"/int32",parentData:data,parentDataProperty:"int32",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2644.errors : vErrors.concat(validate2644.errors);
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
if(!(validate2644(data.int128, {instancePath:instancePath+"/int128",parentData:data,parentDataProperty:"int128",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2644.errors : vErrors.concat(validate2644.errors);
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
if(!(validate2644(data.uint8, {instancePath:instancePath+"/uint8",parentData:data,parentDataProperty:"uint8",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2644.errors : vErrors.concat(validate2644.errors);
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
if(!(validate2644(data.uint16, {instancePath:instancePath+"/uint16",parentData:data,parentDataProperty:"uint16",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2644.errors : vErrors.concat(validate2644.errors);
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
if(!(validate2644(data.uint32, {instancePath:instancePath+"/uint32",parentData:data,parentDataProperty:"uint32",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2644.errors : vErrors.concat(validate2644.errors);
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
if(!(validate2644(data.uint128, {instancePath:instancePath+"/uint128",parentData:data,parentDataProperty:"uint128",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2644.errors : vErrors.concat(validate2644.errors);
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
if(!(validate2644(data.float32, {instancePath:instancePath+"/float32",parentData:data,parentDataProperty:"float32",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2644.errors : vErrors.concat(validate2644.errors);
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
if(!(validate2660(data.decimal, {instancePath:instancePath+"/decimal",parentData:data,parentDataProperty:"decimal",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2660.errors : vErrors.concat(validate2660.errors);
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
if(!(validate2644(data.date, {instancePath:instancePath+"/date",parentData:data,parentDataProperty:"date",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2644.errors : vErrors.concat(validate2644.errors);
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
if(!(validate2644(data.time, {instancePath:instancePath+"/time",parentData:data,parentDataProperty:"time",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2644.errors : vErrors.concat(validate2644.errors);
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
if(!(validate2667(data.timestamp, {instancePath:instancePath+"/timestamp",parentData:data,parentDataProperty:"timestamp",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2667.errors : vErrors.concat(validate2667.errors);
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
if(!(validate2644(data.interval, {instancePath:instancePath+"/interval",parentData:data,parentDataProperty:"interval",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2644.errors : vErrors.concat(validate2644.errors);
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
if(!(validate2644(data.uuid, {instancePath:instancePath+"/uuid",parentData:data,parentDataProperty:"uuid",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2644.errors : vErrors.concat(validate2644.errors);
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
if(!(validate2671(data.structure, {instancePath:instancePath+"/structure",parentData:data,parentDataProperty:"structure",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2671.errors : vErrors.concat(validate2671.errors);
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
if(!(validate2721(data.list, {instancePath:instancePath+"/list",parentData:data,parentDataProperty:"list",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2721.errors : vErrors.concat(validate2721.errors);
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
if(!(validate2725(data.array, {instancePath:instancePath+"/array",parentData:data,parentDataProperty:"array",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2725.errors : vErrors.concat(validate2725.errors);
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
if(!(validate2730(data.map, {instancePath:instancePath+"/map",parentData:data,parentDataProperty:"map",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2730.errors : vErrors.concat(validate2730.errors);
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
if(!(validate2671(data.tagged_union, {instancePath:instancePath+"/tagged_union",parentData:data,parentDataProperty:"tagged_union",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2671.errors : vErrors.concat(validate2671.errors);
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
if(!(validate2644(data.json, {instancePath:instancePath+"/json",parentData:data,parentDataProperty:"json",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2644.errors : vErrors.concat(validate2644.errors);
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
if(!(validate2735(data.vector, {instancePath:instancePath+"/vector",parentData:data,parentDataProperty:"vector",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2735.errors : vErrors.concat(validate2735.errors);
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
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
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
const err90 = {};
if(vErrors === null){
vErrors = [err90];
}
else {
vErrors.push(err90);
}
errors++;
validate2643.errors = vErrors;
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
validate2643.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate2643.evaluated = {"dynamicProps":true,"dynamicItems":false};

const schema745 = {"anyOf":[{"$ref":"#/$defs/CatalogResponse/$defs/T113"},{"type":"null"}]};
const schema746 = {"oneOf":[{"type":"object","additionalProperties":false,"required":["missing"],"properties":{"missing":{"$ref":"#/$defs/CatalogResponse/$defs/T89"}}},{"type":"object","additionalProperties":false,"required":["null"],"properties":{"null":{"$ref":"#/$defs/CatalogResponse/$defs/T89"}}},{"type":"object","additionalProperties":false,"required":["type_error"],"properties":{"type_error":{"$ref":"#/$defs/CatalogResponse/$defs/T114"}}},{"type":"object","additionalProperties":false,"required":["value"],"properties":{"value":{"$ref":"#/$defs/CatalogResponse/$defs/T115"}}},{"type":"object","additionalProperties":false,"required":["conflict"],"properties":{"conflict":{"$ref":"#/$defs/CatalogResponse/$defs/T136"}}}]};
const schema396 = {"type":"string","enum":["unknown","int64","uint64","float64","boolean","utf8","binary","int8","int16","int32","int128","uint8","uint16","uint32","uint128","float32","decimal","date","time","timestamp","interval","uuid","structure","list","array","map","tagged_union","json","range","multirange","vector","null_value","text","character"]};

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
if(typeof data !== "string"){
validate2746.errors = [{}];
return false;
}
if(!((((((((((((((((((((((((((((((((((data === "unknown") || (data === "int64")) || (data === "uint64")) || (data === "float64")) || (data === "boolean")) || (data === "utf8")) || (data === "binary")) || (data === "int8")) || (data === "int16")) || (data === "int32")) || (data === "int128")) || (data === "uint8")) || (data === "uint16")) || (data === "uint32")) || (data === "uint128")) || (data === "float32")) || (data === "decimal")) || (data === "date")) || (data === "time")) || (data === "timestamp")) || (data === "interval")) || (data === "uuid")) || (data === "structure")) || (data === "list")) || (data === "array")) || (data === "map")) || (data === "tagged_union")) || (data === "json")) || (data === "range")) || (data === "multirange")) || (data === "vector")) || (data === "null_value")) || (data === "text")) || (data === "character"))){
validate2746.errors = [{}];
return false;
}
validate2746.errors = vErrors;
return errors === 0;
}
validate2746.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema748 = {"oneOf":[{"type":"object","additionalProperties":false,"required":["atom"],"properties":{"atom":{"$ref":"#/$defs/CatalogResponse/$defs/T116"}}},{"type":"object","additionalProperties":false,"required":["structure"],"properties":{"structure":{"$ref":"#/$defs/CatalogResponse/$defs/T118"}}},{"type":"object","additionalProperties":false,"required":["list"],"properties":{"list":{"$ref":"#/$defs/CatalogResponse/$defs/T118"}}},{"type":"object","additionalProperties":false,"required":["array"],"properties":{"array":{"$ref":"#/$defs/CatalogResponse/$defs/T118"}}},{"type":"object","additionalProperties":false,"required":["map"],"properties":{"map":{"$ref":"#/$defs/CatalogResponse/$defs/T127"}}},{"type":"object","additionalProperties":false,"required":["tagged_union"],"properties":{"tagged_union":{"$ref":"#/$defs/CatalogResponse/$defs/T139"}}},{"type":"object","additionalProperties":false,"required":["json"],"properties":{"json":{"$ref":"#/$defs/CatalogResponse/$defs/T46"}}},{"type":"object","additionalProperties":false,"required":["range"],"properties":{"range":{"$ref":"#/$defs/CatalogResponse/$defs/T141"}}},{"type":"object","additionalProperties":false,"required":["multirange"],"properties":{"multirange":{"$ref":"#/$defs/CatalogResponse/$defs/T135"}}},{"type":"object","additionalProperties":false,"required":["vector"],"properties":{"vector":{"$ref":"#/$defs/CatalogResponse/$defs/T46"}}}]};
const schema749 = {"oneOf":[{"type":"object","additionalProperties":false,"required":["signed"],"properties":{"signed":{"$ref":"#/$defs/CatalogResponse/$defs/T46"}}},{"type":"object","additionalProperties":false,"required":["unsigned"],"properties":{"unsigned":{"$ref":"#/$defs/CatalogResponse/$defs/T46"}}},{"type":"object","additionalProperties":false,"required":["decimal"],"properties":{"decimal":{"$ref":"#/$defs/CatalogResponse/$defs/T46"}}},{"type":"object","additionalProperties":false,"required":["float_bits"],"properties":{"float_bits":{"$ref":"#/$defs/CatalogResponse/$defs/T46"}}},{"type":"object","additionalProperties":false,"required":["boolean"],"properties":{"boolean":{"$ref":"#/$defs/CatalogResponse/$defs/T106"}}},{"type":"object","additionalProperties":false,"required":["utf8"],"properties":{"utf8":{"$ref":"#/$defs/CatalogResponse/$defs/T46"}}},{"type":"object","additionalProperties":false,"required":["binary"],"properties":{"binary":{"$ref":"#/$defs/CatalogResponse/$defs/T46"}}},{"type":"object","additionalProperties":false,"required":["date_days"],"properties":{"date_days":{"$ref":"#/$defs/CatalogResponse/$defs/T46"}}},{"type":"object","additionalProperties":false,"required":["time_nanos"],"properties":{"time_nanos":{"$ref":"#/$defs/CatalogResponse/$defs/T46"}}},{"type":"object","additionalProperties":false,"required":["timestamp_micros"],"properties":{"timestamp_micros":{"$ref":"#/$defs/CatalogResponse/$defs/T46"}}},{"type":"object","additionalProperties":false,"required":["interval"],"properties":{"interval":{"$ref":"#/$defs/CatalogResponse/$defs/T117"}}},{"type":"object","additionalProperties":false,"required":["uuid"],"properties":{"uuid":{"$ref":"#/$defs/CatalogResponse/$defs/T46"}}}]};
const schema750 = {"type":"object","additionalProperties":false,"properties":{"months":{"$ref":"#/$defs/CatalogResponse/$defs/T46"},"days":{"$ref":"#/$defs/CatalogResponse/$defs/T46"},"nanos":{"$ref":"#/$defs/CatalogResponse/$defs/T46"}},"required":["months","days","nanos"]};

function validate2760(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2760.evaluated;
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
validate2760.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "months") || (key0 === "days")) || (key0 === "nanos"))){
validate2760.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.months !== undefined){
const _errs2 = errors;
if(!(validate2493(data.months, {instancePath:instancePath+"/months",parentData:data,parentDataProperty:"months",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2493.errors : vErrors.concat(validate2493.errors);
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
if(!(validate2493(data.days, {instancePath:instancePath+"/days",parentData:data,parentDataProperty:"days",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2493.errors : vErrors.concat(validate2493.errors);
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
if(!(validate2493(data.nanos, {instancePath:instancePath+"/nanos",parentData:data,parentDataProperty:"nanos",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2493.errors : vErrors.concat(validate2493.errors);
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
validate2760.errors = [{}];
return false;
}
}
validate2760.errors = vErrors;
return errors === 0;
}
validate2760.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


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
if(!(validate2493(data.signed, {instancePath:instancePath+"/signed",parentData:data,parentDataProperty:"signed",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2493.errors : vErrors.concat(validate2493.errors);
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
if(!(validate2493(data.unsigned, {instancePath:instancePath+"/unsigned",parentData:data,parentDataProperty:"unsigned",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2493.errors : vErrors.concat(validate2493.errors);
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
if(!(validate2493(data.decimal, {instancePath:instancePath+"/decimal",parentData:data,parentDataProperty:"decimal",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2493.errors : vErrors.concat(validate2493.errors);
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
if(!(validate2493(data.float_bits, {instancePath:instancePath+"/float_bits",parentData:data,parentDataProperty:"float_bits",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2493.errors : vErrors.concat(validate2493.errors);
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
if(!(validate2722(data.boolean, {instancePath:instancePath+"/boolean",parentData:data,parentDataProperty:"boolean",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2722.errors : vErrors.concat(validate2722.errors);
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
if(!(validate2493(data.utf8, {instancePath:instancePath+"/utf8",parentData:data,parentDataProperty:"utf8",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2493.errors : vErrors.concat(validate2493.errors);
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
if(!(validate2493(data.binary, {instancePath:instancePath+"/binary",parentData:data,parentDataProperty:"binary",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2493.errors : vErrors.concat(validate2493.errors);
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
if(!(validate2493(data.date_days, {instancePath:instancePath+"/date_days",parentData:data,parentDataProperty:"date_days",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2493.errors : vErrors.concat(validate2493.errors);
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
if(!(validate2493(data.time_nanos, {instancePath:instancePath+"/time_nanos",parentData:data,parentDataProperty:"time_nanos",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2493.errors : vErrors.concat(validate2493.errors);
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
if(!(validate2493(data.timestamp_micros, {instancePath:instancePath+"/timestamp_micros",parentData:data,parentDataProperty:"timestamp_micros",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2493.errors : vErrors.concat(validate2493.errors);
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
if(!(validate2760(data.interval, {instancePath:instancePath+"/interval",parentData:data,parentDataProperty:"interval",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2760.errors : vErrors.concat(validate2760.errors);
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
if(!(validate2493(data.uuid, {instancePath:instancePath+"/uuid",parentData:data,parentDataProperty:"uuid",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2493.errors : vErrors.concat(validate2493.errors);
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
validate2749.errors = vErrors;
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
validate2749.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate2749.evaluated = {"dynamicProps":true,"dynamicItems":false};

const schema751 = {"type":"array","maxItems":65536,"items":{"$ref":"#/$defs/CatalogResponse/$defs/T119"}};
const schema752 = {"oneOf":[{"type":"object","additionalProperties":false,"required":["missing"],"properties":{"missing":{"$ref":"#/$defs/CatalogResponse/$defs/T120"}}},{"type":"object","additionalProperties":false,"required":["null"],"properties":{"null":{"$ref":"#/$defs/CatalogResponse/$defs/T120"}}},{"type":"object","additionalProperties":false,"required":["type_error"],"properties":{"type_error":{"$ref":"#/$defs/CatalogResponse/$defs/T121"}}},{"type":"object","additionalProperties":false,"required":["value"],"properties":{"value":{"$ref":"#/$defs/CatalogResponse/$defs/T122"}}},{"type":"object","additionalProperties":false,"required":["conflict"],"properties":{"conflict":{"$ref":"#/$defs/CatalogResponse/$defs/T136"}}}]};
const schema753 = {"type":"object","maxProperties":0};

function validate2769(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2769.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
if(Object.keys(data).length > 0){
validate2769.errors = [{}];
return false;
}
}
else {
validate2769.errors = [{}];
return false;
}
}
validate2769.errors = vErrors;
return errors === 0;
}
validate2769.evaluated = {"dynamicProps":false,"dynamicItems":false};


function validate2772(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2772.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate2772.errors = [{}];
return false;
}
if(!((((((((((((((((((((((((((((((((((data === "unknown") || (data === "int64")) || (data === "uint64")) || (data === "float64")) || (data === "boolean")) || (data === "utf8")) || (data === "binary")) || (data === "int8")) || (data === "int16")) || (data === "int32")) || (data === "int128")) || (data === "uint8")) || (data === "uint16")) || (data === "uint32")) || (data === "uint128")) || (data === "float32")) || (data === "decimal")) || (data === "date")) || (data === "time")) || (data === "timestamp")) || (data === "interval")) || (data === "uuid")) || (data === "structure")) || (data === "list")) || (data === "array")) || (data === "map")) || (data === "tagged_union")) || (data === "json")) || (data === "range")) || (data === "multirange")) || (data === "vector")) || (data === "null_value")) || (data === "text")) || (data === "character"))){
validate2772.errors = [{}];
return false;
}
validate2772.errors = vErrors;
return errors === 0;
}
validate2772.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema755 = {"oneOf":[{"type":"object","additionalProperties":false,"required":["atom"],"properties":{"atom":{"$ref":"#/$defs/CatalogResponse/$defs/T123"}}},{"type":"object","additionalProperties":false,"required":["structure"],"properties":{"structure":{"$ref":"#/$defs/CatalogResponse/$defs/T118"}}},{"type":"object","additionalProperties":false,"required":["list"],"properties":{"list":{"$ref":"#/$defs/CatalogResponse/$defs/T118"}}},{"type":"object","additionalProperties":false,"required":["array"],"properties":{"array":{"$ref":"#/$defs/CatalogResponse/$defs/T118"}}},{"type":"object","additionalProperties":false,"required":["map"],"properties":{"map":{"$ref":"#/$defs/CatalogResponse/$defs/T127"}}},{"type":"object","additionalProperties":false,"required":["tagged_union"],"properties":{"tagged_union":{"$ref":"#/$defs/CatalogResponse/$defs/T129"}}},{"type":"object","additionalProperties":false,"required":["json"],"properties":{"json":{"$ref":"#/$defs/CatalogResponse/$defs/T124"}}},{"type":"object","additionalProperties":false,"required":["range"],"properties":{"range":{"$ref":"#/$defs/CatalogResponse/$defs/T132"}}},{"type":"object","additionalProperties":false,"required":["multirange"],"properties":{"multirange":{"$ref":"#/$defs/CatalogResponse/$defs/T135"}}},{"type":"object","additionalProperties":false,"required":["vector"],"properties":{"vector":{"$ref":"#/$defs/CatalogResponse/$defs/T124"}}}]};
const schema756 = {"oneOf":[{"type":"object","additionalProperties":false,"required":["signed"],"properties":{"signed":{"$ref":"#/$defs/CatalogResponse/$defs/T124"}}},{"type":"object","additionalProperties":false,"required":["unsigned"],"properties":{"unsigned":{"$ref":"#/$defs/CatalogResponse/$defs/T124"}}},{"type":"object","additionalProperties":false,"required":["decimal"],"properties":{"decimal":{"$ref":"#/$defs/CatalogResponse/$defs/T124"}}},{"type":"object","additionalProperties":false,"required":["float_bits"],"properties":{"float_bits":{"$ref":"#/$defs/CatalogResponse/$defs/T124"}}},{"type":"object","additionalProperties":false,"required":["boolean"],"properties":{"boolean":{"$ref":"#/$defs/CatalogResponse/$defs/T125"}}},{"type":"object","additionalProperties":false,"required":["utf8"],"properties":{"utf8":{"$ref":"#/$defs/CatalogResponse/$defs/T124"}}},{"type":"object","additionalProperties":false,"required":["binary"],"properties":{"binary":{"$ref":"#/$defs/CatalogResponse/$defs/T124"}}},{"type":"object","additionalProperties":false,"required":["date_days"],"properties":{"date_days":{"$ref":"#/$defs/CatalogResponse/$defs/T124"}}},{"type":"object","additionalProperties":false,"required":["time_nanos"],"properties":{"time_nanos":{"$ref":"#/$defs/CatalogResponse/$defs/T124"}}},{"type":"object","additionalProperties":false,"required":["timestamp_micros"],"properties":{"timestamp_micros":{"$ref":"#/$defs/CatalogResponse/$defs/T124"}}},{"type":"object","additionalProperties":false,"required":["interval"],"properties":{"interval":{"$ref":"#/$defs/CatalogResponse/$defs/T126"}}},{"type":"object","additionalProperties":false,"required":["uuid"],"properties":{"uuid":{"$ref":"#/$defs/CatalogResponse/$defs/T124"}}}]};
const schema757 = {"type":"string","maxLength":262144};

function validate2776(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2776.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(typeof data === "string"){
if(func3(data) > 262144){
validate2776.errors = [{}];
return false;
}
}
else {
validate2776.errors = [{}];
return false;
}
}
validate2776.errors = vErrors;
return errors === 0;
}
validate2776.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema758 = {"type":"boolean"};

function validate2781(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2781.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "boolean"){
validate2781.errors = [{}];
return false;
}
validate2781.errors = vErrors;
return errors === 0;
}
validate2781.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema759 = {"type":"object","additionalProperties":false,"properties":{"months":{"$ref":"#/$defs/CatalogResponse/$defs/T124"},"days":{"$ref":"#/$defs/CatalogResponse/$defs/T124"},"nanos":{"$ref":"#/$defs/CatalogResponse/$defs/T124"}},"required":["months","days","nanos"]};

function validate2788(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2788.evaluated;
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
validate2788.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "months") || (key0 === "days")) || (key0 === "nanos"))){
validate2788.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.months !== undefined){
const _errs2 = errors;
if(!(validate2776(data.months, {instancePath:instancePath+"/months",parentData:data,parentDataProperty:"months",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2776.errors : vErrors.concat(validate2776.errors);
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
if(!(validate2776(data.days, {instancePath:instancePath+"/days",parentData:data,parentDataProperty:"days",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2776.errors : vErrors.concat(validate2776.errors);
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
if(!(validate2776(data.nanos, {instancePath:instancePath+"/nanos",parentData:data,parentDataProperty:"nanos",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2776.errors : vErrors.concat(validate2776.errors);
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
validate2788.errors = [{}];
return false;
}
}
validate2788.errors = vErrors;
return errors === 0;
}
validate2788.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate2775(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2775.evaluated;
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
if(!(validate2776(data.signed, {instancePath:instancePath+"/signed",parentData:data,parentDataProperty:"signed",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2776.errors : vErrors.concat(validate2776.errors);
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
if(!(validate2776(data.unsigned, {instancePath:instancePath+"/unsigned",parentData:data,parentDataProperty:"unsigned",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2776.errors : vErrors.concat(validate2776.errors);
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
if(!(validate2776(data.decimal, {instancePath:instancePath+"/decimal",parentData:data,parentDataProperty:"decimal",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2776.errors : vErrors.concat(validate2776.errors);
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
if(!(validate2776(data.float_bits, {instancePath:instancePath+"/float_bits",parentData:data,parentDataProperty:"float_bits",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2776.errors : vErrors.concat(validate2776.errors);
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
if(!(validate2781(data.boolean, {instancePath:instancePath+"/boolean",parentData:data,parentDataProperty:"boolean",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2781.errors : vErrors.concat(validate2781.errors);
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
if(!(validate2776(data.utf8, {instancePath:instancePath+"/utf8",parentData:data,parentDataProperty:"utf8",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2776.errors : vErrors.concat(validate2776.errors);
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
if(!(validate2776(data.binary, {instancePath:instancePath+"/binary",parentData:data,parentDataProperty:"binary",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2776.errors : vErrors.concat(validate2776.errors);
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
if(!(validate2776(data.date_days, {instancePath:instancePath+"/date_days",parentData:data,parentDataProperty:"date_days",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2776.errors : vErrors.concat(validate2776.errors);
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
if(!(validate2776(data.time_nanos, {instancePath:instancePath+"/time_nanos",parentData:data,parentDataProperty:"time_nanos",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2776.errors : vErrors.concat(validate2776.errors);
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
if(!(validate2776(data.timestamp_micros, {instancePath:instancePath+"/timestamp_micros",parentData:data,parentDataProperty:"timestamp_micros",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2776.errors : vErrors.concat(validate2776.errors);
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
if(!(validate2788(data.interval, {instancePath:instancePath+"/interval",parentData:data,parentDataProperty:"interval",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2788.errors : vErrors.concat(validate2788.errors);
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
if(!(validate2776(data.uuid, {instancePath:instancePath+"/uuid",parentData:data,parentDataProperty:"uuid",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2776.errors : vErrors.concat(validate2776.errors);
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
validate2775.errors = vErrors;
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
validate2775.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate2775.evaluated = {"dynamicProps":true,"dynamicItems":false};

const schema760 = {"type":"array","maxItems":65536,"items":{"$ref":"#/$defs/CatalogResponse/$defs/T128"}};
const schema761 = {"type":"object","additionalProperties":false,"properties":{"key":{"$ref":"#/$defs/CatalogResponse/$defs/T123"},"value":{"$ref":"#/$defs/CatalogResponse/$defs/T119"}},"required":["key","value"]};
const wrapper49 = {validate: validate2768};

function validate2796(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2796.evaluated;
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
validate2796.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "key") || (key0 === "value"))){
validate2796.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.key !== undefined){
const _errs2 = errors;
if(!(validate2775(data.key, {instancePath:instancePath+"/key",parentData:data,parentDataProperty:"key",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2775.errors : vErrors.concat(validate2775.errors);
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
validate2796.errors = [{}];
return false;
}
}
validate2796.errors = vErrors;
return errors === 0;
}
validate2796.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate2795(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2795.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(Array.isArray(data)){
if(data.length > 65536){
validate2795.errors = [{}];
return false;
}
else {
var valid0 = true;
const len0 = data.length;
for(let i0=0; i0<len0; i0++){
const _errs1 = errors;
if(!(validate2796(data[i0], {instancePath:instancePath+"/" + i0,parentData:data,parentDataProperty:i0,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2796.errors : vErrors.concat(validate2796.errors);
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
validate2795.errors = [{}];
return false;
}
}
validate2795.errors = vErrors;
return errors === 0;
}
validate2795.evaluated = {"items":true,"dynamicProps":false,"dynamicItems":false};

const schema762 = {"type":"object","additionalProperties":false,"properties":{"index":{"$ref":"#/$defs/CatalogResponse/$defs/T130"},"value":{"$ref":"#/$defs/CatalogResponse/$defs/T131"}},"required":["index","value"]};

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
if(!(((typeof data == "number") && (!(data % 1) && !isNaN(data))) && (isFinite(data)))){
validate2801.errors = [{}];
return false;
}
if(errors === 0){
if((typeof data == "number") && (isFinite(data))){
if(data > 255 || isNaN(data)){
validate2801.errors = [{}];
return false;
}
else {
if(data < 0 || isNaN(data)){
validate2801.errors = [{}];
return false;
}
}
}
}
validate2801.errors = vErrors;
return errors === 0;
}
validate2801.evaluated = {"dynamicProps":false,"dynamicItems":false};


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
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if(((data.index === undefined) && (missing0 = "index")) || ((data.value === undefined) && (missing0 = "value"))){
validate2800.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "index") || (key0 === "value"))){
validate2800.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.index !== undefined){
const _errs2 = errors;
if(!(validate2801(data.index, {instancePath:instancePath+"/index",parentData:data,parentDataProperty:"index",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2801.errors : vErrors.concat(validate2801.errors);
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
validate2800.errors = [{}];
return false;
}
}
validate2800.errors = vErrors;
return errors === 0;
}
validate2800.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema764 = {"type":"object","additionalProperties":false,"properties":{"is_empty":{"$ref":"#/$defs/CatalogResponse/$defs/T125"},"lower":{"$ref":"#/$defs/CatalogResponse/$defs/T133"},"upper":{"$ref":"#/$defs/CatalogResponse/$defs/T133"}},"required":["is_empty","lower","upper"]};
const schema765 = {"anyOf":[{"$ref":"#/$defs/CatalogResponse/$defs/T134"},{"type":"null"}]};
const schema766 = {"type":"object","additionalProperties":false,"properties":{"value":{"$ref":"#/$defs/CatalogResponse/$defs/T123"},"inclusive":{"$ref":"#/$defs/CatalogResponse/$defs/T125"}},"required":["value","inclusive"]};

function validate2808(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2808.evaluated;
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
validate2808.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "value") || (key0 === "inclusive"))){
validate2808.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.value !== undefined){
const _errs2 = errors;
if(!(validate2775(data.value, {instancePath:instancePath+"/value",parentData:data,parentDataProperty:"value",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2775.errors : vErrors.concat(validate2775.errors);
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
if(!(validate2781(data.inclusive, {instancePath:instancePath+"/inclusive",parentData:data,parentDataProperty:"inclusive",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2781.errors : vErrors.concat(validate2781.errors);
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
validate2808.errors = [{}];
return false;
}
}
validate2808.errors = vErrors;
return errors === 0;
}
validate2808.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate2807(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2807.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate2808(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2808.errors : vErrors.concat(validate2808.errors);
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
validate2807.errors = vErrors;
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
validate2807.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate2807.evaluated = {"dynamicProps":true,"dynamicItems":false};


function validate2805(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2805.evaluated;
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
validate2805.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "is_empty") || (key0 === "lower")) || (key0 === "upper"))){
validate2805.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.is_empty !== undefined){
const _errs2 = errors;
if(!(validate2781(data.is_empty, {instancePath:instancePath+"/is_empty",parentData:data,parentDataProperty:"is_empty",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2781.errors : vErrors.concat(validate2781.errors);
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
if(!(validate2807(data.lower, {instancePath:instancePath+"/lower",parentData:data,parentDataProperty:"lower",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2807.errors : vErrors.concat(validate2807.errors);
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
if(!(validate2807(data.upper, {instancePath:instancePath+"/upper",parentData:data,parentDataProperty:"upper",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2807.errors : vErrors.concat(validate2807.errors);
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
validate2805.errors = [{}];
return false;
}
}
validate2805.errors = vErrors;
return errors === 0;
}
validate2805.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema767 = {"type":"array","maxItems":65536,"items":{"$ref":"#/$defs/CatalogResponse/$defs/T132"}};

function validate2815(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2815.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(Array.isArray(data)){
if(data.length > 65536){
validate2815.errors = [{}];
return false;
}
else {
var valid0 = true;
const len0 = data.length;
for(let i0=0; i0<len0; i0++){
const _errs1 = errors;
if(!(validate2805(data[i0], {instancePath:instancePath+"/" + i0,parentData:data,parentDataProperty:i0,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2805.errors : vErrors.concat(validate2805.errors);
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
validate2815.errors = [{}];
return false;
}
}
validate2815.errors = vErrors;
return errors === 0;
}
validate2815.evaluated = {"items":true,"dynamicProps":false,"dynamicItems":false};

const wrapper46 = {validate: validate2767};

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
if(!(validate2775(data.atom, {instancePath:instancePath+"/atom",parentData:data,parentDataProperty:"atom",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2775.errors : vErrors.concat(validate2775.errors);
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
if(!(validate2795(data.map, {instancePath:instancePath+"/map",parentData:data,parentDataProperty:"map",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2795.errors : vErrors.concat(validate2795.errors);
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
if(!(validate2800(data.tagged_union, {instancePath:instancePath+"/tagged_union",parentData:data,parentDataProperty:"tagged_union",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2800.errors : vErrors.concat(validate2800.errors);
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
if(!(validate2776(data.json, {instancePath:instancePath+"/json",parentData:data,parentDataProperty:"json",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2776.errors : vErrors.concat(validate2776.errors);
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
if(!(validate2805(data.range, {instancePath:instancePath+"/range",parentData:data,parentDataProperty:"range",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2805.errors : vErrors.concat(validate2805.errors);
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
if(!(validate2815(data.multirange, {instancePath:instancePath+"/multirange",parentData:data,parentDataProperty:"multirange",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2815.errors : vErrors.concat(validate2815.errors);
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
if(!(validate2776(data.vector, {instancePath:instancePath+"/vector",parentData:data,parentDataProperty:"vector",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2776.errors : vErrors.concat(validate2776.errors);
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
evaluated0.props = props1;
return errors === 0;
}
validate2774.evaluated = {"dynamicProps":true,"dynamicItems":false};

const schema768 = {"type":"array","maxItems":65536,"items":{"$ref":"#/$defs/CatalogResponse/$defs/T137"}};
const schema769 = {"type":"object","additionalProperties":false,"properties":{"counter":{"$ref":"#/$defs/CatalogResponse/$defs/T124"},"replica":{"$ref":"#/$defs/CatalogResponse/$defs/T124"},"value":{"$ref":"#/$defs/CatalogResponse/$defs/T138"}},"required":["counter","replica","value"]};
const schema770 = {"oneOf":[{"type":"object","additionalProperties":false,"required":["null"],"properties":{"null":{"$ref":"#/$defs/CatalogResponse/$defs/T120"}}},{"type":"object","additionalProperties":false,"required":["type_error"],"properties":{"type_error":{"$ref":"#/$defs/CatalogResponse/$defs/T121"}}},{"type":"object","additionalProperties":false,"required":["value"],"properties":{"value":{"$ref":"#/$defs/CatalogResponse/$defs/T122"}}}]};

function validate2824(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2824.evaluated;
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
if(!(validate2769(data.null, {instancePath:instancePath+"/null",parentData:data,parentDataProperty:"null",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2769.errors : vErrors.concat(validate2769.errors);
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
if(!(validate2772(data.type_error, {instancePath:instancePath+"/type_error",parentData:data,parentDataProperty:"type_error",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2772.errors : vErrors.concat(validate2772.errors);
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
if(!(validate2774(data.value, {instancePath:instancePath+"/value",parentData:data,parentDataProperty:"value",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2774.errors : vErrors.concat(validate2774.errors);
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
validate2824.errors = vErrors;
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
validate2824.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate2824.evaluated = {"dynamicProps":true,"dynamicItems":false};


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
if((((data.counter === undefined) && (missing0 = "counter")) || ((data.replica === undefined) && (missing0 = "replica"))) || ((data.value === undefined) && (missing0 = "value"))){
validate2821.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "counter") || (key0 === "replica")) || (key0 === "value"))){
validate2821.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.counter !== undefined){
const _errs2 = errors;
if(!(validate2776(data.counter, {instancePath:instancePath+"/counter",parentData:data,parentDataProperty:"counter",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2776.errors : vErrors.concat(validate2776.errors);
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
if(!(validate2776(data.replica, {instancePath:instancePath+"/replica",parentData:data,parentDataProperty:"replica",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2776.errors : vErrors.concat(validate2776.errors);
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
if(!(validate2824(data.value, {instancePath:instancePath+"/value",parentData:data,parentDataProperty:"value",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2824.errors : vErrors.concat(validate2824.errors);
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
if(!(validate2769(data.missing, {instancePath:instancePath+"/missing",parentData:data,parentDataProperty:"missing",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2769.errors : vErrors.concat(validate2769.errors);
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
if(!(validate2769(data.null, {instancePath:instancePath+"/null",parentData:data,parentDataProperty:"null",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2769.errors : vErrors.concat(validate2769.errors);
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
if(!(validate2772(data.type_error, {instancePath:instancePath+"/type_error",parentData:data,parentDataProperty:"type_error",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2772.errors : vErrors.concat(validate2772.errors);
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
if(!(validate2774(data.value, {instancePath:instancePath+"/value",parentData:data,parentDataProperty:"value",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2774.errors : vErrors.concat(validate2774.errors);
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
if(!(validate2820(data.conflict, {instancePath:instancePath+"/conflict",parentData:data,parentDataProperty:"conflict",rootData,dynamicAnchors}))){
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
if(errors === 0){
if(Array.isArray(data)){
if(data.length > 65536){
validate2767.errors = [{}];
return false;
}
else {
var valid0 = true;
const len0 = data.length;
for(let i0=0; i0<len0; i0++){
const _errs1 = errors;
if(!(validate2768(data[i0], {instancePath:instancePath+"/" + i0,parentData:data,parentDataProperty:i0,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2768.errors : vErrors.concat(validate2768.errors);
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
validate2767.errors = [{}];
return false;
}
}
validate2767.errors = vErrors;
return errors === 0;
}
validate2767.evaluated = {"items":true,"dynamicProps":false,"dynamicItems":false};

const schema771 = {"type":"object","additionalProperties":false,"properties":{"index":{"$ref":"#/$defs/CatalogResponse/$defs/T91"},"value":{"$ref":"#/$defs/CatalogResponse/$defs/T140"}},"required":["index","value"]};
const wrapper51 = {validate: validate2743};

function validate2836(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2836.evaluated;
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
validate2836.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "index") || (key0 === "value"))){
validate2836.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.index !== undefined){
const _errs2 = errors;
if(!(validate2661(data.index, {instancePath:instancePath+"/index",parentData:data,parentDataProperty:"index",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2661.errors : vErrors.concat(validate2661.errors);
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
validate2836.errors = [{}];
return false;
}
}
validate2836.errors = vErrors;
return errors === 0;
}
validate2836.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema772 = {"type":"object","additionalProperties":false,"properties":{"is_empty":{"$ref":"#/$defs/CatalogResponse/$defs/T106"},"lower":{"$ref":"#/$defs/CatalogResponse/$defs/T142"},"upper":{"$ref":"#/$defs/CatalogResponse/$defs/T142"}},"required":["is_empty","lower","upper"]};
const schema773 = {"anyOf":[{"$ref":"#/$defs/CatalogResponse/$defs/T143"},{"type":"null"}]};
const schema774 = {"type":"object","additionalProperties":false,"properties":{"value":{"$ref":"#/$defs/CatalogResponse/$defs/T116"},"inclusive":{"$ref":"#/$defs/CatalogResponse/$defs/T106"}},"required":["value","inclusive"]};

function validate2843(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2843.evaluated;
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
validate2843.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "value") || (key0 === "inclusive"))){
validate2843.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.value !== undefined){
const _errs2 = errors;
if(!(validate2749(data.value, {instancePath:instancePath+"/value",parentData:data,parentDataProperty:"value",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2749.errors : vErrors.concat(validate2749.errors);
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
if(!(validate2722(data.inclusive, {instancePath:instancePath+"/inclusive",parentData:data,parentDataProperty:"inclusive",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2722.errors : vErrors.concat(validate2722.errors);
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
validate2843.errors = [{}];
return false;
}
}
validate2843.errors = vErrors;
return errors === 0;
}
validate2843.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate2842(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2842.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate2843(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2843.errors : vErrors.concat(validate2843.errors);
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
validate2842.errors = vErrors;
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
validate2842.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate2842.evaluated = {"dynamicProps":true,"dynamicItems":false};


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
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((((data.is_empty === undefined) && (missing0 = "is_empty")) || ((data.lower === undefined) && (missing0 = "lower"))) || ((data.upper === undefined) && (missing0 = "upper"))){
validate2840.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "is_empty") || (key0 === "lower")) || (key0 === "upper"))){
validate2840.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.is_empty !== undefined){
const _errs2 = errors;
if(!(validate2722(data.is_empty, {instancePath:instancePath+"/is_empty",parentData:data,parentDataProperty:"is_empty",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2722.errors : vErrors.concat(validate2722.errors);
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
if(!(validate2842(data.lower, {instancePath:instancePath+"/lower",parentData:data,parentDataProperty:"lower",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2842.errors : vErrors.concat(validate2842.errors);
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
if(!(validate2842(data.upper, {instancePath:instancePath+"/upper",parentData:data,parentDataProperty:"upper",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2842.errors : vErrors.concat(validate2842.errors);
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
validate2840.errors = [{}];
return false;
}
}
validate2840.errors = vErrors;
return errors === 0;
}
validate2840.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate2748(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2748.evaluated;
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
if(!(validate2749(data.atom, {instancePath:instancePath+"/atom",parentData:data,parentDataProperty:"atom",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2749.errors : vErrors.concat(validate2749.errors);
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
if(!(validate2767(data.structure, {instancePath:instancePath+"/structure",parentData:data,parentDataProperty:"structure",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2767.errors : vErrors.concat(validate2767.errors);
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
if(!(validate2767(data.list, {instancePath:instancePath+"/list",parentData:data,parentDataProperty:"list",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2767.errors : vErrors.concat(validate2767.errors);
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
if(!(validate2767(data.array, {instancePath:instancePath+"/array",parentData:data,parentDataProperty:"array",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2767.errors : vErrors.concat(validate2767.errors);
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
if(!(validate2795(data.map, {instancePath:instancePath+"/map",parentData:data,parentDataProperty:"map",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2795.errors : vErrors.concat(validate2795.errors);
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
if(!(validate2836(data.tagged_union, {instancePath:instancePath+"/tagged_union",parentData:data,parentDataProperty:"tagged_union",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2836.errors : vErrors.concat(validate2836.errors);
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
if(!(validate2493(data.json, {instancePath:instancePath+"/json",parentData:data,parentDataProperty:"json",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2493.errors : vErrors.concat(validate2493.errors);
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
if(!(validate2840(data.range, {instancePath:instancePath+"/range",parentData:data,parentDataProperty:"range",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2840.errors : vErrors.concat(validate2840.errors);
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
if(!(validate2815(data.multirange, {instancePath:instancePath+"/multirange",parentData:data,parentDataProperty:"multirange",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2815.errors : vErrors.concat(validate2815.errors);
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
if(!(validate2493(data.vector, {instancePath:instancePath+"/vector",parentData:data,parentDataProperty:"vector",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2493.errors : vErrors.concat(validate2493.errors);
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
validate2748.errors = vErrors;
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
validate2748.errors = vErrors;
evaluated0.props = props1;
return errors === 0;
}
validate2748.evaluated = {"dynamicProps":true,"dynamicItems":false};


function validate2743(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2743.evaluated;
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
if(!(validate2644(data.missing, {instancePath:instancePath+"/missing",parentData:data,parentDataProperty:"missing",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2644.errors : vErrors.concat(validate2644.errors);
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
if(!(validate2644(data.null, {instancePath:instancePath+"/null",parentData:data,parentDataProperty:"null",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2644.errors : vErrors.concat(validate2644.errors);
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
if(!(validate2746(data.type_error, {instancePath:instancePath+"/type_error",parentData:data,parentDataProperty:"type_error",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2746.errors : vErrors.concat(validate2746.errors);
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
if(!(validate2748(data.value, {instancePath:instancePath+"/value",parentData:data,parentDataProperty:"value",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2748.errors : vErrors.concat(validate2748.errors);
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
if(!(validate2820(data.conflict, {instancePath:instancePath+"/conflict",parentData:data,parentDataProperty:"conflict",rootData,dynamicAnchors}))){
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
validate2743.errors = vErrors;
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
validate2743.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate2743.evaluated = {"dynamicProps":true,"dynamicItems":false};


function validate2742(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2742.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate2743(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2743.errors : vErrors.concat(validate2743.errors);
errors = vErrors.length;
}
else {
var props0 = validate2743.evaluated.props;
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
validate2742.errors = vErrors;
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
validate2742.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate2742.evaluated = {"dynamicProps":true,"dynamicItems":false};

const schema775 = {"anyOf":[{"$ref":"#/$defs/CatalogResponse/$defs/T108"},{"type":"null"}]};

function validate2856(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2856.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate2727(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2727.errors : vErrors.concat(validate2727.errors);
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
validate2856.errors = vErrors;
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
validate2856.errors = vErrors;
return errors === 0;
}
validate2856.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema776 = {"type":"string","enum":["plain","bitpacked","rle","dictionary","fsst","comp","comp_3","zoned","ibm_hfp","ebcdic"]};

function validate2859(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2859.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate2859.errors = [{}];
return false;
}
if(!((((((((((data === "plain") || (data === "bitpacked")) || (data === "rle")) || (data === "dictionary")) || (data === "fsst")) || (data === "comp")) || (data === "comp_3")) || (data === "zoned")) || (data === "ibm_hfp")) || (data === "ebcdic"))){
validate2859.errors = [{}];
return false;
}
validate2859.errors = vErrors;
return errors === 0;
}
validate2859.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema205 = {"type":"string","enum":["none","utf8_binary","ascii_ci","ebcdic_cp037","icu_root","ebcdic_037_pad","ebcdic_1047_nopad"]};

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
if(typeof data !== "string"){
validate2861.errors = [{}];
return false;
}
if(!(((((((data === "none") || (data === "utf8_binary")) || (data === "ascii_ci")) || (data === "ebcdic_cp037")) || (data === "icu_root")) || (data === "ebcdic_037_pad")) || (data === "ebcdic_1047_nopad"))){
validate2861.errors = [{}];
return false;
}
validate2861.errors = vErrors;
return errors === 0;
}
validate2861.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema778 = {"type":"object","additionalProperties":false,"properties":{"rounding":{"$ref":"#/$defs/CatalogResponse/$defs/T148"},"metric":{"$ref":"#/$defs/CatalogResponse/$defs/T150"},"timezone":{"$ref":"#/$defs/CatalogResponse/$defs/T152"},"spatial":{"$ref":"#/$defs/CatalogResponse/$defs/T156"}},"required":["rounding","metric","timezone","spatial"]};
const schema779 = {"anyOf":[{"$ref":"#/$defs/CatalogResponse/$defs/T149"},{"type":"null"}]};
const schema210 = {"type":"string","enum":["reject","half_even","toward_zero"]};

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
if(typeof data !== "string"){
validate2865.errors = [{}];
return false;
}
if(!(((data === "reject") || (data === "half_even")) || (data === "toward_zero"))){
validate2865.errors = [{}];
return false;
}
validate2865.errors = vErrors;
return errors === 0;
}
validate2865.evaluated = {"dynamicProps":false,"dynamicItems":false};


function validate2864(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2864.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate2865(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2865.errors : vErrors.concat(validate2865.errors);
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
validate2864.errors = vErrors;
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
validate2864.errors = vErrors;
return errors === 0;
}
validate2864.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema781 = {"anyOf":[{"$ref":"#/$defs/CatalogResponse/$defs/T151"},{"type":"null"}]};
const schema213 = {"type":"string","enum":["l2_squared","cosine","dot_product","hamming"]};

function validate2869(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2869.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate2869.errors = [{}];
return false;
}
if(!((((data === "l2_squared") || (data === "cosine")) || (data === "dot_product")) || (data === "hamming"))){
validate2869.errors = [{}];
return false;
}
validate2869.errors = vErrors;
return errors === 0;
}
validate2869.evaluated = {"dynamicProps":false,"dynamicItems":false};


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
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate2869(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2869.errors : vErrors.concat(validate2869.errors);
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
validate2868.errors = vErrors;
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
validate2868.errors = vErrors;
return errors === 0;
}
validate2868.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema783 = {"anyOf":[{"$ref":"#/$defs/CatalogResponse/$defs/T153"},{"type":"null"}]};
const schema784 = {"type":"object","additionalProperties":false,"properties":{"version":{"$ref":"#/$defs/CatalogResponse/$defs/T154"},"zone":{"$ref":"#/$defs/CatalogResponse/$defs/T46"},"tzif_hex":{"$ref":"#/$defs/CatalogResponse/$defs/T46"}},"required":["version","zone","tzif_hex"]};
const schema785 = {"type":"object","additionalProperties":false,"properties":{"version_id":{"$ref":"#/$defs/CatalogResponse/$defs/T46"},"digest":{"$ref":"#/$defs/CatalogResponse/$defs/T155"}},"required":["version_id","digest"]};
const schema786 = {"type":"array","minItems":32,"maxItems":32,"items":{"$ref":"#/$defs/CatalogResponse/$defs/T91"}};

function validate2876(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2876.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(Array.isArray(data)){
if(data.length > 32){
validate2876.errors = [{}];
return false;
}
else {
if(data.length < 32){
validate2876.errors = [{}];
return false;
}
else {
var valid0 = true;
const len0 = data.length;
for(let i0=0; i0<len0; i0++){
const _errs1 = errors;
if(!(validate2661(data[i0], {instancePath:instancePath+"/" + i0,parentData:data,parentDataProperty:i0,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2661.errors : vErrors.concat(validate2661.errors);
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
validate2876.errors = [{}];
return false;
}
}
validate2876.errors = vErrors;
return errors === 0;
}
validate2876.evaluated = {"items":true,"dynamicProps":false,"dynamicItems":false};


function validate2874(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2874.evaluated;
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
validate2874.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "version_id") || (key0 === "digest"))){
validate2874.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.version_id !== undefined){
const _errs2 = errors;
if(!(validate2493(data.version_id, {instancePath:instancePath+"/version_id",parentData:data,parentDataProperty:"version_id",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2493.errors : vErrors.concat(validate2493.errors);
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
if(!(validate2876(data.digest, {instancePath:instancePath+"/digest",parentData:data,parentDataProperty:"digest",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2876.errors : vErrors.concat(validate2876.errors);
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
validate2874.errors = [{}];
return false;
}
}
validate2874.errors = vErrors;
return errors === 0;
}
validate2874.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate2873(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2873.evaluated;
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
validate2873.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "version") || (key0 === "zone")) || (key0 === "tzif_hex"))){
validate2873.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.version !== undefined){
const _errs2 = errors;
if(!(validate2874(data.version, {instancePath:instancePath+"/version",parentData:data,parentDataProperty:"version",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2874.errors : vErrors.concat(validate2874.errors);
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
if(!(validate2493(data.zone, {instancePath:instancePath+"/zone",parentData:data,parentDataProperty:"zone",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2493.errors : vErrors.concat(validate2493.errors);
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
if(!(validate2493(data.tzif_hex, {instancePath:instancePath+"/tzif_hex",parentData:data,parentDataProperty:"tzif_hex",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2493.errors : vErrors.concat(validate2493.errors);
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
validate2873.errors = [{}];
return false;
}
}
validate2873.errors = vErrors;
return errors === 0;
}
validate2873.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate2872(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2872.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate2873(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2873.errors : vErrors.concat(validate2873.errors);
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
validate2872.errors = vErrors;
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
validate2872.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate2872.evaluated = {"dynamicProps":true,"dynamicItems":false};

const schema787 = {"anyOf":[{"$ref":"#/$defs/CatalogResponse/$defs/T157"},{"type":"null"}]};
const schema788 = {"type":"object","additionalProperties":false,"properties":{"definition":{"$ref":"#/$defs/CatalogResponse/$defs/T158"},"srid":{"$ref":"#/$defs/CatalogResponse/$defs/T108"},"local_frame":{"$ref":"#/$defs/CatalogResponse/$defs/T159"},"axes":{"$ref":"#/$defs/CatalogResponse/$defs/T160"},"manifold":{"$ref":"#/$defs/CatalogResponse/$defs/T161"},"linear_unit_nm":{"$ref":"#/$defs/CatalogResponse/$defs/T46"},"vertical_datum":{"$ref":"#/$defs/CatalogResponse/$defs/T162"},"precision":{"$ref":"#/$defs/CatalogResponse/$defs/T163"}},"required":["definition","srid","local_frame","axes","manifold","linear_unit_nm","vertical_datum","precision"]};

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
if(!(data === "28dd54cfe806369cb6a6d8ed5bb87fed380afb08c79af9812b5bebe2f123b573")){
validate2886.errors = [{}];
return false;
}
validate2886.errors = vErrors;
return errors === 0;
}
validate2886.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema790 = {"type":"array","minItems":16,"maxItems":16,"items":{"$ref":"#/$defs/CatalogResponse/$defs/T91"}};

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
if(errors === 0){
if(Array.isArray(data)){
if(data.length > 16){
validate2889.errors = [{}];
return false;
}
else {
if(data.length < 16){
validate2889.errors = [{}];
return false;
}
else {
var valid0 = true;
const len0 = data.length;
for(let i0=0; i0<len0; i0++){
const _errs1 = errors;
if(!(validate2661(data[i0], {instancePath:instancePath+"/" + i0,parentData:data,parentDataProperty:i0,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2661.errors : vErrors.concat(validate2661.errors);
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
validate2889.errors = [{}];
return false;
}
}
validate2889.errors = vErrors;
return errors === 0;
}
validate2889.evaluated = {"items":true,"dynamicProps":false,"dynamicItems":false};

const schema222 = {"type":"string","enum":["xy","xyz","longitude_latitude","longitude_latitude_height"]};

function validate2892(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2892.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate2892.errors = [{}];
return false;
}
if(!((((data === "xy") || (data === "xyz")) || (data === "longitude_latitude")) || (data === "longitude_latitude_height"))){
validate2892.errors = [{}];
return false;
}
validate2892.errors = vErrors;
return errors === 0;
}
validate2892.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema224 = {"type":"string","enum":["planar","wgs84_ellipsoid"]};

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
if(!((data === "planar") || (data === "wgs84_ellipsoid"))){
validate2894.errors = [{}];
return false;
}
validate2894.errors = vErrors;
return errors === 0;
}
validate2894.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema226 = {"type":"string","enum":["none","local","wgs84_ellipsoid"]};

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
if(typeof data !== "string"){
validate2897.errors = [{}];
return false;
}
if(!(((data === "none") || (data === "local")) || (data === "wgs84_ellipsoid"))){
validate2897.errors = [{}];
return false;
}
validate2897.errors = vErrors;
return errors === 0;
}
validate2897.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema794 = {"oneOf":[{"type":"object","additionalProperties":false,"required":["exact"],"properties":{"exact":{"$ref":"#/$defs/CatalogResponse/$defs/T89"}}},{"type":"object","additionalProperties":false,"required":["binary_grid"],"properties":{"binary_grid":{"$ref":"#/$defs/CatalogResponse/$defs/T164"}}}]};
const schema229 = {"type":"integer","minimum":-32768,"maximum":32767};

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
if(!(((typeof data == "number") && (!(data % 1) && !isNaN(data))) && (isFinite(data)))){
validate2901.errors = [{}];
return false;
}
if(errors === 0){
if((typeof data == "number") && (isFinite(data))){
if(data > 32767 || isNaN(data)){
validate2901.errors = [{}];
return false;
}
else {
if(data < -32768 || isNaN(data)){
validate2901.errors = [{}];
return false;
}
}
}
}
validate2901.errors = vErrors;
return errors === 0;
}
validate2901.evaluated = {"dynamicProps":false,"dynamicItems":false};


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
if(!(validate2644(data.exact, {instancePath:instancePath+"/exact",parentData:data,parentDataProperty:"exact",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2644.errors : vErrors.concat(validate2644.errors);
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
if(!(validate2901(data.binary_grid, {instancePath:instancePath+"/binary_grid",parentData:data,parentDataProperty:"binary_grid",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2901.errors : vErrors.concat(validate2901.errors);
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
validate2899.errors = vErrors;
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
validate2899.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate2899.evaluated = {"dynamicProps":true,"dynamicItems":false};


function validate2885(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2885.evaluated;
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
validate2885.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((((((((key0 === "definition") || (key0 === "srid")) || (key0 === "local_frame")) || (key0 === "axes")) || (key0 === "manifold")) || (key0 === "linear_unit_nm")) || (key0 === "vertical_datum")) || (key0 === "precision"))){
validate2885.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.definition !== undefined){
const _errs2 = errors;
if(!(validate2886(data.definition, {instancePath:instancePath+"/definition",parentData:data,parentDataProperty:"definition",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2886.errors : vErrors.concat(validate2886.errors);
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
if(!(validate2727(data.srid, {instancePath:instancePath+"/srid",parentData:data,parentDataProperty:"srid",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2727.errors : vErrors.concat(validate2727.errors);
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
if(!(validate2889(data.local_frame, {instancePath:instancePath+"/local_frame",parentData:data,parentDataProperty:"local_frame",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2889.errors : vErrors.concat(validate2889.errors);
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
if(!(validate2892(data.axes, {instancePath:instancePath+"/axes",parentData:data,parentDataProperty:"axes",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2892.errors : vErrors.concat(validate2892.errors);
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
if(!(validate2894(data.manifold, {instancePath:instancePath+"/manifold",parentData:data,parentDataProperty:"manifold",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2894.errors : vErrors.concat(validate2894.errors);
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
if(!(validate2493(data.linear_unit_nm, {instancePath:instancePath+"/linear_unit_nm",parentData:data,parentDataProperty:"linear_unit_nm",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2493.errors : vErrors.concat(validate2493.errors);
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
if(!(validate2897(data.vertical_datum, {instancePath:instancePath+"/vertical_datum",parentData:data,parentDataProperty:"vertical_datum",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2897.errors : vErrors.concat(validate2897.errors);
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
if(!(validate2899(data.precision, {instancePath:instancePath+"/precision",parentData:data,parentDataProperty:"precision",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2899.errors : vErrors.concat(validate2899.errors);
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
validate2885.errors = [{}];
return false;
}
}
validate2885.errors = vErrors;
return errors === 0;
}
validate2885.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


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
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate2885(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2885.errors : vErrors.concat(validate2885.errors);
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
validate2884.errors = vErrors;
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
validate2884.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate2884.evaluated = {"dynamicProps":true,"dynamicItems":false};


function validate2863(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2863.evaluated;
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
validate2863.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((((key0 === "rounding") || (key0 === "metric")) || (key0 === "timezone")) || (key0 === "spatial"))){
validate2863.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.rounding !== undefined){
const _errs2 = errors;
if(!(validate2864(data.rounding, {instancePath:instancePath+"/rounding",parentData:data,parentDataProperty:"rounding",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2864.errors : vErrors.concat(validate2864.errors);
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
if(!(validate2868(data.metric, {instancePath:instancePath+"/metric",parentData:data,parentDataProperty:"metric",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2868.errors : vErrors.concat(validate2868.errors);
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
if(!(validate2872(data.timezone, {instancePath:instancePath+"/timezone",parentData:data,parentDataProperty:"timezone",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2872.errors : vErrors.concat(validate2872.errors);
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
if(!(validate2884(data.spatial, {instancePath:instancePath+"/spatial",parentData:data,parentDataProperty:"spatial",rootData,dynamicAnchors}))){
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
validate2863.errors = [{}];
return false;
}
}
validate2863.errors = vErrors;
return errors === 0;
}
validate2863.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate2640(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2640.evaluated;
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
validate2640.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(func1.call(schema722.properties, key0))){
validate2640.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.id !== undefined){
const _errs2 = errors;
if(!(validate2493(data.id, {instancePath:instancePath+"/id",parentData:data,parentDataProperty:"id",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2493.errors : vErrors.concat(validate2493.errors);
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
if(!(validate2493(data.name, {instancePath:instancePath+"/name",parentData:data,parentDataProperty:"name",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2493.errors : vErrors.concat(validate2493.errors);
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
if(!(validate2643(data.type, {instancePath:instancePath+"/type",parentData:data,parentDataProperty:"type",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2643.errors : vErrors.concat(validate2643.errors);
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
if(!(validate2722(data.nullable, {instancePath:instancePath+"/nullable",parentData:data,parentDataProperty:"nullable",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2722.errors : vErrors.concat(validate2722.errors);
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
if(!(validate2742(data.default, {instancePath:instancePath+"/default",parentData:data,parentDataProperty:"default",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2742.errors : vErrors.concat(validate2742.errors);
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
if(!(validate2856(data.max_characters, {instancePath:instancePath+"/max_characters",parentData:data,parentDataProperty:"max_characters",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2856.errors : vErrors.concat(validate2856.errors);
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
if(!(validate2859(data.encoding, {instancePath:instancePath+"/encoding",parentData:data,parentDataProperty:"encoding",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2859.errors : vErrors.concat(validate2859.errors);
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
if(!(validate2861(data.collation, {instancePath:instancePath+"/collation",parentData:data,parentDataProperty:"collation",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2861.errors : vErrors.concat(validate2861.errors);
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
if(!(validate2863(data.semantics, {instancePath:instancePath+"/semantics",parentData:data,parentDataProperty:"semantics",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2863.errors : vErrors.concat(validate2863.errors);
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
validate2640.errors = [{}];
return false;
}
}
validate2640.errors = vErrors;
return errors === 0;
}
validate2640.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate2639(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2639.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(Array.isArray(data)){
if(data.length > 128){
validate2639.errors = [{}];
return false;
}
else {
var valid0 = true;
const len0 = data.length;
for(let i0=0; i0<len0; i0++){
const _errs1 = errors;
if(!(validate2640(data[i0], {instancePath:instancePath+"/" + i0,parentData:data,parentDataProperty:i0,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2640.errors : vErrors.concat(validate2640.errors);
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
validate2639.errors = [{}];
return false;
}
}
validate2639.errors = vErrors;
return errors === 0;
}
validate2639.evaluated = {"items":true,"dynamicProps":false,"dynamicItems":false};

const schema796 = {"type":"array","maxItems":128,"items":{"$ref":"#/$defs/CatalogResponse/$defs/T46"}};

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
if(errors === 0){
if(Array.isArray(data)){
if(data.length > 128){
validate2909.errors = [{}];
return false;
}
else {
var valid0 = true;
const len0 = data.length;
for(let i0=0; i0<len0; i0++){
const _errs1 = errors;
if(!(validate2493(data[i0], {instancePath:instancePath+"/" + i0,parentData:data,parentDataProperty:i0,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2493.errors : vErrors.concat(validate2493.errors);
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
validate2909.errors = [{}];
return false;
}
}
validate2909.errors = vErrors;
return errors === 0;
}
validate2909.evaluated = {"items":true,"dynamicProps":false,"dynamicItems":false};

const schema797 = {"type":"object","additionalProperties":false,"properties":{"next_id":{"$ref":"#/$defs/CatalogResponse/$defs/T6"},"checks":{"$ref":"#/$defs/CatalogResponse/$defs/T167"},"foreign_keys":{"$ref":"#/$defs/CatalogResponse/$defs/T191"}},"required":["next_id","checks","foreign_keys"]};
const schema798 = {"type":"array","maxItems":64,"items":{"$ref":"#/$defs/CatalogResponse/$defs/T168"}};
const schema799 = {"type":"object","additionalProperties":false,"properties":{"id":{"$ref":"#/$defs/CatalogResponse/$defs/T169"},"name":{"$ref":"#/$defs/CatalogResponse/$defs/T170"},"atoms":{"$ref":"#/$defs/CatalogResponse/$defs/T171"},"validated":{"$ref":"#/$defs/CatalogResponse/$defs/T190"}},"required":["id","name","atoms","validated"]};

function validate2916(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2916.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(!(((typeof data == "number") && (!(data % 1) && !isNaN(data))) && (isFinite(data)))){
validate2916.errors = [{}];
return false;
}
if(errors === 0){
if((typeof data == "number") && (isFinite(data))){
if(data > 4294967295 || isNaN(data)){
validate2916.errors = [{}];
return false;
}
else {
if(data < 0 || isNaN(data)){
validate2916.errors = [{}];
return false;
}
}
}
}
validate2916.errors = vErrors;
return errors === 0;
}
validate2916.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema801 = {"type":"string","maxLength":262144};

function validate2918(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2918.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(typeof data === "string"){
if(func3(data) > 262144){
validate2918.errors = [{}];
return false;
}
}
else {
validate2918.errors = [{}];
return false;
}
}
validate2918.errors = vErrors;
return errors === 0;
}
validate2918.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema802 = {"type":"array","maxItems":32,"items":{"$ref":"#/$defs/CatalogResponse/$defs/T172"}};
const schema803 = {"oneOf":[{"type":"object","additionalProperties":false,"required":["compare_literal"],"properties":{"compare_literal":{"$ref":"#/$defs/CatalogResponse/$defs/T173"}}},{"type":"object","additionalProperties":false,"required":["compare_columns"],"properties":{"compare_columns":{"$ref":"#/$defs/CatalogResponse/$defs/T189"}}},{"type":"object","additionalProperties":false,"required":["is_not_null"],"properties":{"is_not_null":{"$ref":"#/$defs/CatalogResponse/$defs/T174"}}},{"type":"object","additionalProperties":false,"required":["is_null"],"properties":{"is_null":{"$ref":"#/$defs/CatalogResponse/$defs/T174"}}}]};
const schema804 = {"type":"object","additionalProperties":false,"properties":{"column":{"$ref":"#/$defs/CatalogResponse/$defs/T174"},"op":{"$ref":"#/$defs/CatalogResponse/$defs/T175"},"literal":{"$ref":"#/$defs/CatalogResponse/$defs/T176"}},"required":["column","op","literal"]};
const schema805 = {"type":"string","maxLength":262144};

function validate2923(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2923.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(typeof data === "string"){
if(func3(data) > 262144){
validate2923.errors = [{}];
return false;
}
}
else {
validate2923.errors = [{}];
return false;
}
}
validate2923.errors = vErrors;
return errors === 0;
}
validate2923.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema806 = {"type":"string","enum":["lt","lte","eq","gte","gt","neq"]};

function validate2925(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2925.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate2925.errors = [{}];
return false;
}
if(!((((((data === "lt") || (data === "lte")) || (data === "eq")) || (data === "gte")) || (data === "gt")) || (data === "neq"))){
validate2925.errors = [{}];
return false;
}
validate2925.errors = vErrors;
return errors === 0;
}
validate2925.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema807 = {"oneOf":[{"type":"object","additionalProperties":false,"required":["missing"],"properties":{"missing":{"$ref":"#/$defs/CatalogResponse/$defs/T177"}}},{"type":"object","additionalProperties":false,"required":["null"],"properties":{"null":{"$ref":"#/$defs/CatalogResponse/$defs/T177"}}},{"type":"object","additionalProperties":false,"required":["type_error"],"properties":{"type_error":{"$ref":"#/$defs/CatalogResponse/$defs/T178"}}},{"type":"object","additionalProperties":false,"required":["value"],"properties":{"value":{"$ref":"#/$defs/CatalogResponse/$defs/T179"}}},{"type":"object","additionalProperties":false,"required":["conflict"],"properties":{"conflict":{"$ref":"#/$defs/CatalogResponse/$defs/T136"}}}]};
const schema808 = {"type":"object","maxProperties":0};

function validate2928(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2928.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
if(Object.keys(data).length > 0){
validate2928.errors = [{}];
return false;
}
}
else {
validate2928.errors = [{}];
return false;
}
}
validate2928.errors = vErrors;
return errors === 0;
}
validate2928.evaluated = {"dynamicProps":false,"dynamicItems":false};


function validate2931(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2931.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate2931.errors = [{}];
return false;
}
if(!((((((((((((((((((((((((((((((((((data === "unknown") || (data === "int64")) || (data === "uint64")) || (data === "float64")) || (data === "boolean")) || (data === "utf8")) || (data === "binary")) || (data === "int8")) || (data === "int16")) || (data === "int32")) || (data === "int128")) || (data === "uint8")) || (data === "uint16")) || (data === "uint32")) || (data === "uint128")) || (data === "float32")) || (data === "decimal")) || (data === "date")) || (data === "time")) || (data === "timestamp")) || (data === "interval")) || (data === "uuid")) || (data === "structure")) || (data === "list")) || (data === "array")) || (data === "map")) || (data === "tagged_union")) || (data === "json")) || (data === "range")) || (data === "multirange")) || (data === "vector")) || (data === "null_value")) || (data === "text")) || (data === "character"))){
validate2931.errors = [{}];
return false;
}
validate2931.errors = vErrors;
return errors === 0;
}
validate2931.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema810 = {"oneOf":[{"type":"object","additionalProperties":false,"required":["atom"],"properties":{"atom":{"$ref":"#/$defs/CatalogResponse/$defs/T180"}}},{"type":"object","additionalProperties":false,"required":["structure"],"properties":{"structure":{"$ref":"#/$defs/CatalogResponse/$defs/T118"}}},{"type":"object","additionalProperties":false,"required":["list"],"properties":{"list":{"$ref":"#/$defs/CatalogResponse/$defs/T118"}}},{"type":"object","additionalProperties":false,"required":["array"],"properties":{"array":{"$ref":"#/$defs/CatalogResponse/$defs/T118"}}},{"type":"object","additionalProperties":false,"required":["map"],"properties":{"map":{"$ref":"#/$defs/CatalogResponse/$defs/T127"}}},{"type":"object","additionalProperties":false,"required":["tagged_union"],"properties":{"tagged_union":{"$ref":"#/$defs/CatalogResponse/$defs/T183"}}},{"type":"object","additionalProperties":false,"required":["json"],"properties":{"json":{"$ref":"#/$defs/CatalogResponse/$defs/T174"}}},{"type":"object","additionalProperties":false,"required":["range"],"properties":{"range":{"$ref":"#/$defs/CatalogResponse/$defs/T186"}}},{"type":"object","additionalProperties":false,"required":["multirange"],"properties":{"multirange":{"$ref":"#/$defs/CatalogResponse/$defs/T135"}}},{"type":"object","additionalProperties":false,"required":["vector"],"properties":{"vector":{"$ref":"#/$defs/CatalogResponse/$defs/T174"}}}]};
const schema811 = {"oneOf":[{"type":"object","additionalProperties":false,"required":["signed"],"properties":{"signed":{"$ref":"#/$defs/CatalogResponse/$defs/T174"}}},{"type":"object","additionalProperties":false,"required":["unsigned"],"properties":{"unsigned":{"$ref":"#/$defs/CatalogResponse/$defs/T174"}}},{"type":"object","additionalProperties":false,"required":["decimal"],"properties":{"decimal":{"$ref":"#/$defs/CatalogResponse/$defs/T174"}}},{"type":"object","additionalProperties":false,"required":["float_bits"],"properties":{"float_bits":{"$ref":"#/$defs/CatalogResponse/$defs/T174"}}},{"type":"object","additionalProperties":false,"required":["boolean"],"properties":{"boolean":{"$ref":"#/$defs/CatalogResponse/$defs/T181"}}},{"type":"object","additionalProperties":false,"required":["utf8"],"properties":{"utf8":{"$ref":"#/$defs/CatalogResponse/$defs/T174"}}},{"type":"object","additionalProperties":false,"required":["binary"],"properties":{"binary":{"$ref":"#/$defs/CatalogResponse/$defs/T174"}}},{"type":"object","additionalProperties":false,"required":["date_days"],"properties":{"date_days":{"$ref":"#/$defs/CatalogResponse/$defs/T174"}}},{"type":"object","additionalProperties":false,"required":["time_nanos"],"properties":{"time_nanos":{"$ref":"#/$defs/CatalogResponse/$defs/T174"}}},{"type":"object","additionalProperties":false,"required":["timestamp_micros"],"properties":{"timestamp_micros":{"$ref":"#/$defs/CatalogResponse/$defs/T174"}}},{"type":"object","additionalProperties":false,"required":["interval"],"properties":{"interval":{"$ref":"#/$defs/CatalogResponse/$defs/T182"}}},{"type":"object","additionalProperties":false,"required":["uuid"],"properties":{"uuid":{"$ref":"#/$defs/CatalogResponse/$defs/T174"}}}]};
const schema812 = {"type":"boolean"};

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
if(typeof data !== "boolean"){
validate2939.errors = [{}];
return false;
}
validate2939.errors = vErrors;
return errors === 0;
}
validate2939.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema813 = {"type":"object","additionalProperties":false,"properties":{"months":{"$ref":"#/$defs/CatalogResponse/$defs/T174"},"days":{"$ref":"#/$defs/CatalogResponse/$defs/T174"},"nanos":{"$ref":"#/$defs/CatalogResponse/$defs/T174"}},"required":["months","days","nanos"]};

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
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((((data.months === undefined) && (missing0 = "months")) || ((data.days === undefined) && (missing0 = "days"))) || ((data.nanos === undefined) && (missing0 = "nanos"))){
validate2946.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "months") || (key0 === "days")) || (key0 === "nanos"))){
validate2946.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.months !== undefined){
const _errs2 = errors;
if(!(validate2923(data.months, {instancePath:instancePath+"/months",parentData:data,parentDataProperty:"months",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2923.errors : vErrors.concat(validate2923.errors);
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
if(!(validate2923(data.days, {instancePath:instancePath+"/days",parentData:data,parentDataProperty:"days",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2923.errors : vErrors.concat(validate2923.errors);
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
if(!(validate2923(data.nanos, {instancePath:instancePath+"/nanos",parentData:data,parentDataProperty:"nanos",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2923.errors : vErrors.concat(validate2923.errors);
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
validate2946.errors = [{}];
return false;
}
}
validate2946.errors = vErrors;
return errors === 0;
}
validate2946.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


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
if(!(validate2923(data.signed, {instancePath:instancePath+"/signed",parentData:data,parentDataProperty:"signed",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2923.errors : vErrors.concat(validate2923.errors);
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
if(!(validate2923(data.unsigned, {instancePath:instancePath+"/unsigned",parentData:data,parentDataProperty:"unsigned",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2923.errors : vErrors.concat(validate2923.errors);
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
if(!(validate2923(data.decimal, {instancePath:instancePath+"/decimal",parentData:data,parentDataProperty:"decimal",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2923.errors : vErrors.concat(validate2923.errors);
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
if(!(validate2923(data.float_bits, {instancePath:instancePath+"/float_bits",parentData:data,parentDataProperty:"float_bits",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2923.errors : vErrors.concat(validate2923.errors);
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
if(!(validate2939(data.boolean, {instancePath:instancePath+"/boolean",parentData:data,parentDataProperty:"boolean",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2939.errors : vErrors.concat(validate2939.errors);
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
if(!(validate2923(data.utf8, {instancePath:instancePath+"/utf8",parentData:data,parentDataProperty:"utf8",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2923.errors : vErrors.concat(validate2923.errors);
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
if(!(validate2923(data.binary, {instancePath:instancePath+"/binary",parentData:data,parentDataProperty:"binary",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2923.errors : vErrors.concat(validate2923.errors);
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
if(!(validate2923(data.date_days, {instancePath:instancePath+"/date_days",parentData:data,parentDataProperty:"date_days",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2923.errors : vErrors.concat(validate2923.errors);
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
if(!(validate2923(data.time_nanos, {instancePath:instancePath+"/time_nanos",parentData:data,parentDataProperty:"time_nanos",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2923.errors : vErrors.concat(validate2923.errors);
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
if(!(validate2923(data.timestamp_micros, {instancePath:instancePath+"/timestamp_micros",parentData:data,parentDataProperty:"timestamp_micros",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2923.errors : vErrors.concat(validate2923.errors);
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
if(!(validate2946(data.interval, {instancePath:instancePath+"/interval",parentData:data,parentDataProperty:"interval",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2946.errors : vErrors.concat(validate2946.errors);
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
if(!(validate2923(data.uuid, {instancePath:instancePath+"/uuid",parentData:data,parentDataProperty:"uuid",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2923.errors : vErrors.concat(validate2923.errors);
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
validate2934.errors = vErrors;
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
validate2934.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate2934.evaluated = {"dynamicProps":true,"dynamicItems":false};

const schema814 = {"type":"object","additionalProperties":false,"properties":{"index":{"$ref":"#/$defs/CatalogResponse/$defs/T184"},"value":{"$ref":"#/$defs/CatalogResponse/$defs/T185"}},"required":["index","value"]};

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
if(!(((typeof data == "number") && (!(data % 1) && !isNaN(data))) && (isFinite(data)))){
validate2958.errors = [{}];
return false;
}
if(errors === 0){
if((typeof data == "number") && (isFinite(data))){
if(data > 255 || isNaN(data)){
validate2958.errors = [{}];
return false;
}
else {
if(data < 0 || isNaN(data)){
validate2958.errors = [{}];
return false;
}
}
}
}
validate2958.errors = vErrors;
return errors === 0;
}
validate2958.evaluated = {"dynamicProps":false,"dynamicItems":false};

const wrapper52 = {validate: validate2927};

function validate2957(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2957.evaluated;
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
validate2957.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "index") || (key0 === "value"))){
validate2957.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.index !== undefined){
const _errs2 = errors;
if(!(validate2958(data.index, {instancePath:instancePath+"/index",parentData:data,parentDataProperty:"index",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2958.errors : vErrors.concat(validate2958.errors);
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
validate2957.errors = [{}];
return false;
}
}
validate2957.errors = vErrors;
return errors === 0;
}
validate2957.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema816 = {"type":"object","additionalProperties":false,"properties":{"is_empty":{"$ref":"#/$defs/CatalogResponse/$defs/T181"},"lower":{"$ref":"#/$defs/CatalogResponse/$defs/T187"},"upper":{"$ref":"#/$defs/CatalogResponse/$defs/T187"}},"required":["is_empty","lower","upper"]};
const schema817 = {"anyOf":[{"$ref":"#/$defs/CatalogResponse/$defs/T188"},{"type":"null"}]};
const schema818 = {"type":"object","additionalProperties":false,"properties":{"value":{"$ref":"#/$defs/CatalogResponse/$defs/T180"},"inclusive":{"$ref":"#/$defs/CatalogResponse/$defs/T181"}},"required":["value","inclusive"]};

function validate2965(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2965.evaluated;
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
validate2965.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "value") || (key0 === "inclusive"))){
validate2965.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.value !== undefined){
const _errs2 = errors;
if(!(validate2934(data.value, {instancePath:instancePath+"/value",parentData:data,parentDataProperty:"value",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2934.errors : vErrors.concat(validate2934.errors);
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
if(!(validate2939(data.inclusive, {instancePath:instancePath+"/inclusive",parentData:data,parentDataProperty:"inclusive",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2939.errors : vErrors.concat(validate2939.errors);
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
validate2965.errors = [{}];
return false;
}
}
validate2965.errors = vErrors;
return errors === 0;
}
validate2965.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


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
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate2965(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2965.errors : vErrors.concat(validate2965.errors);
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
validate2964.errors = vErrors;
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
validate2964.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate2964.evaluated = {"dynamicProps":true,"dynamicItems":false};


function validate2962(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2962.evaluated;
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
validate2962.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "is_empty") || (key0 === "lower")) || (key0 === "upper"))){
validate2962.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.is_empty !== undefined){
const _errs2 = errors;
if(!(validate2939(data.is_empty, {instancePath:instancePath+"/is_empty",parentData:data,parentDataProperty:"is_empty",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2939.errors : vErrors.concat(validate2939.errors);
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
if(!(validate2964(data.lower, {instancePath:instancePath+"/lower",parentData:data,parentDataProperty:"lower",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2964.errors : vErrors.concat(validate2964.errors);
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
if(!(validate2964(data.upper, {instancePath:instancePath+"/upper",parentData:data,parentDataProperty:"upper",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2964.errors : vErrors.concat(validate2964.errors);
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
validate2962.errors = [{}];
return false;
}
}
validate2962.errors = vErrors;
return errors === 0;
}
validate2962.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate2933(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2933.evaluated;
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
if(!(validate2934(data.atom, {instancePath:instancePath+"/atom",parentData:data,parentDataProperty:"atom",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2934.errors : vErrors.concat(validate2934.errors);
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
if(!(validate2767(data.structure, {instancePath:instancePath+"/structure",parentData:data,parentDataProperty:"structure",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2767.errors : vErrors.concat(validate2767.errors);
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
if(!(validate2767(data.list, {instancePath:instancePath+"/list",parentData:data,parentDataProperty:"list",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2767.errors : vErrors.concat(validate2767.errors);
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
if(!(validate2767(data.array, {instancePath:instancePath+"/array",parentData:data,parentDataProperty:"array",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2767.errors : vErrors.concat(validate2767.errors);
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
if(!(validate2795(data.map, {instancePath:instancePath+"/map",parentData:data,parentDataProperty:"map",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2795.errors : vErrors.concat(validate2795.errors);
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
if(!(validate2957(data.tagged_union, {instancePath:instancePath+"/tagged_union",parentData:data,parentDataProperty:"tagged_union",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2957.errors : vErrors.concat(validate2957.errors);
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
if(!(validate2923(data.json, {instancePath:instancePath+"/json",parentData:data,parentDataProperty:"json",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2923.errors : vErrors.concat(validate2923.errors);
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
if(!(validate2962(data.range, {instancePath:instancePath+"/range",parentData:data,parentDataProperty:"range",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2962.errors : vErrors.concat(validate2962.errors);
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
if(!(validate2815(data.multirange, {instancePath:instancePath+"/multirange",parentData:data,parentDataProperty:"multirange",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2815.errors : vErrors.concat(validate2815.errors);
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
if(!(validate2923(data.vector, {instancePath:instancePath+"/vector",parentData:data,parentDataProperty:"vector",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2923.errors : vErrors.concat(validate2923.errors);
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
validate2933.errors = vErrors;
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
validate2933.errors = vErrors;
evaluated0.props = props1;
return errors === 0;
}
validate2933.evaluated = {"dynamicProps":true,"dynamicItems":false};


function validate2927(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2927.evaluated;
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
if(!(validate2928(data.missing, {instancePath:instancePath+"/missing",parentData:data,parentDataProperty:"missing",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2928.errors : vErrors.concat(validate2928.errors);
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
if(!(validate2928(data.null, {instancePath:instancePath+"/null",parentData:data,parentDataProperty:"null",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2928.errors : vErrors.concat(validate2928.errors);
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
if(!(validate2931(data.type_error, {instancePath:instancePath+"/type_error",parentData:data,parentDataProperty:"type_error",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2931.errors : vErrors.concat(validate2931.errors);
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
if(!(validate2933(data.value, {instancePath:instancePath+"/value",parentData:data,parentDataProperty:"value",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2933.errors : vErrors.concat(validate2933.errors);
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
if(!(validate2820(data.conflict, {instancePath:instancePath+"/conflict",parentData:data,parentDataProperty:"conflict",rootData,dynamicAnchors}))){
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
validate2927.errors = vErrors;
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
validate2927.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate2927.evaluated = {"dynamicProps":true,"dynamicItems":false};


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
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((((data.column === undefined) && (missing0 = "column")) || ((data.op === undefined) && (missing0 = "op"))) || ((data.literal === undefined) && (missing0 = "literal"))){
validate2922.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "column") || (key0 === "op")) || (key0 === "literal"))){
validate2922.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.column !== undefined){
const _errs2 = errors;
if(!(validate2923(data.column, {instancePath:instancePath+"/column",parentData:data,parentDataProperty:"column",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2923.errors : vErrors.concat(validate2923.errors);
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
if(!(validate2925(data.op, {instancePath:instancePath+"/op",parentData:data,parentDataProperty:"op",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2925.errors : vErrors.concat(validate2925.errors);
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
if(!(validate2927(data.literal, {instancePath:instancePath+"/literal",parentData:data,parentDataProperty:"literal",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2927.errors : vErrors.concat(validate2927.errors);
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
validate2922.errors = [{}];
return false;
}
}
validate2922.errors = vErrors;
return errors === 0;
}
validate2922.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema819 = {"type":"object","additionalProperties":false,"properties":{"left_column":{"$ref":"#/$defs/CatalogResponse/$defs/T174"},"op":{"$ref":"#/$defs/CatalogResponse/$defs/T175"},"right_column":{"$ref":"#/$defs/CatalogResponse/$defs/T174"}},"required":["left_column","op","right_column"]};

function validate2978(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2978.evaluated;
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
validate2978.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "left_column") || (key0 === "op")) || (key0 === "right_column"))){
validate2978.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.left_column !== undefined){
const _errs2 = errors;
if(!(validate2923(data.left_column, {instancePath:instancePath+"/left_column",parentData:data,parentDataProperty:"left_column",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2923.errors : vErrors.concat(validate2923.errors);
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
if(!(validate2925(data.op, {instancePath:instancePath+"/op",parentData:data,parentDataProperty:"op",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2925.errors : vErrors.concat(validate2925.errors);
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
if(!(validate2923(data.right_column, {instancePath:instancePath+"/right_column",parentData:data,parentDataProperty:"right_column",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2923.errors : vErrors.concat(validate2923.errors);
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
validate2978.errors = [{}];
return false;
}
}
validate2978.errors = vErrors;
return errors === 0;
}
validate2978.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate2921(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2921.evaluated;
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
if(!(validate2922(data.compare_literal, {instancePath:instancePath+"/compare_literal",parentData:data,parentDataProperty:"compare_literal",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2922.errors : vErrors.concat(validate2922.errors);
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
if(!(validate2978(data.compare_columns, {instancePath:instancePath+"/compare_columns",parentData:data,parentDataProperty:"compare_columns",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2978.errors : vErrors.concat(validate2978.errors);
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
if(!(validate2923(data.is_not_null, {instancePath:instancePath+"/is_not_null",parentData:data,parentDataProperty:"is_not_null",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2923.errors : vErrors.concat(validate2923.errors);
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
if(!(validate2923(data.is_null, {instancePath:instancePath+"/is_null",parentData:data,parentDataProperty:"is_null",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2923.errors : vErrors.concat(validate2923.errors);
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
validate2921.errors = vErrors;
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
validate2921.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate2921.evaluated = {"dynamicProps":true,"dynamicItems":false};


function validate2920(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2920.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(Array.isArray(data)){
if(data.length > 32){
validate2920.errors = [{}];
return false;
}
else {
var valid0 = true;
const len0 = data.length;
for(let i0=0; i0<len0; i0++){
const _errs1 = errors;
if(!(validate2921(data[i0], {instancePath:instancePath+"/" + i0,parentData:data,parentDataProperty:i0,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2921.errors : vErrors.concat(validate2921.errors);
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
validate2920.errors = [{}];
return false;
}
}
validate2920.errors = vErrors;
return errors === 0;
}
validate2920.evaluated = {"items":true,"dynamicProps":false,"dynamicItems":false};

const schema820 = {"type":"boolean"};

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
if(typeof data !== "boolean"){
validate2987.errors = [{}];
return false;
}
validate2987.errors = vErrors;
return errors === 0;
}
validate2987.evaluated = {"dynamicProps":false,"dynamicItems":false};


function validate2915(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2915.evaluated;
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
validate2915.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((((key0 === "id") || (key0 === "name")) || (key0 === "atoms")) || (key0 === "validated"))){
validate2915.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.id !== undefined){
const _errs2 = errors;
if(!(validate2916(data.id, {instancePath:instancePath+"/id",parentData:data,parentDataProperty:"id",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2916.errors : vErrors.concat(validate2916.errors);
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
if(!(validate2918(data.name, {instancePath:instancePath+"/name",parentData:data,parentDataProperty:"name",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2918.errors : vErrors.concat(validate2918.errors);
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
if(!(validate2920(data.atoms, {instancePath:instancePath+"/atoms",parentData:data,parentDataProperty:"atoms",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2920.errors : vErrors.concat(validate2920.errors);
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
if(!(validate2987(data.validated, {instancePath:instancePath+"/validated",parentData:data,parentDataProperty:"validated",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2987.errors : vErrors.concat(validate2987.errors);
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
validate2915.errors = [{}];
return false;
}
}
validate2915.errors = vErrors;
return errors === 0;
}
validate2915.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


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
if(data.length > 64){
validate2914.errors = [{}];
return false;
}
else {
var valid0 = true;
const len0 = data.length;
for(let i0=0; i0<len0; i0++){
const _errs1 = errors;
if(!(validate2915(data[i0], {instancePath:instancePath+"/" + i0,parentData:data,parentDataProperty:i0,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2915.errors : vErrors.concat(validate2915.errors);
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
validate2914.errors = [{}];
return false;
}
}
validate2914.errors = vErrors;
return errors === 0;
}
validate2914.evaluated = {"items":true,"dynamicProps":false,"dynamicItems":false};

const schema821 = {"type":"array","maxItems":64,"items":{"$ref":"#/$defs/CatalogResponse/$defs/T192"}};
const schema822 = {"type":"object","additionalProperties":false,"properties":{"id":{"$ref":"#/$defs/CatalogResponse/$defs/T169"},"name":{"$ref":"#/$defs/CatalogResponse/$defs/T170"},"local_columns":{"$ref":"#/$defs/CatalogResponse/$defs/T165"},"target_object":{"$ref":"#/$defs/CatalogResponse/$defs/T170"},"target_revision":{"$ref":"#/$defs/CatalogResponse/$defs/T170"},"target_definition":{"$ref":"#/$defs/CatalogResponse/$defs/T193"},"target_columns":{"$ref":"#/$defs/CatalogResponse/$defs/T165"},"on_delete":{"$ref":"#/$defs/CatalogResponse/$defs/T194"},"on_update":{"$ref":"#/$defs/CatalogResponse/$defs/T194"},"enforcement":{"$ref":"#/$defs/CatalogResponse/$defs/T195"}},"required":["id","name","local_columns","target_object","target_revision","target_definition","target_columns","on_delete","on_update","enforcement"]};
const schema823 = {"type":"object","additionalProperties":false,"properties":{"realm":{"$ref":"#/$defs/CatalogResponse/$defs/T170"},"resource":{"$ref":"#/$defs/CatalogResponse/$defs/T170"},"catalog":{"$ref":"#/$defs/CatalogResponse/$defs/T170"},"branch":{"$ref":"#/$defs/CatalogResponse/$defs/T170"},"object":{"$ref":"#/$defs/CatalogResponse/$defs/T170"},"revision":{"$ref":"#/$defs/CatalogResponse/$defs/T170"},"digest":{"$ref":"#/$defs/CatalogResponse/$defs/T170"}},"required":["realm","resource","catalog","branch","object","revision","digest"]};

function validate2998(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2998.evaluated;
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
validate2998.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((((((key0 === "realm") || (key0 === "resource")) || (key0 === "catalog")) || (key0 === "branch")) || (key0 === "object")) || (key0 === "revision")) || (key0 === "digest"))){
validate2998.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.realm !== undefined){
const _errs2 = errors;
if(!(validate2918(data.realm, {instancePath:instancePath+"/realm",parentData:data,parentDataProperty:"realm",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2918.errors : vErrors.concat(validate2918.errors);
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
if(!(validate2918(data.resource, {instancePath:instancePath+"/resource",parentData:data,parentDataProperty:"resource",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2918.errors : vErrors.concat(validate2918.errors);
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
if(!(validate2918(data.catalog, {instancePath:instancePath+"/catalog",parentData:data,parentDataProperty:"catalog",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2918.errors : vErrors.concat(validate2918.errors);
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
if(!(validate2918(data.branch, {instancePath:instancePath+"/branch",parentData:data,parentDataProperty:"branch",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2918.errors : vErrors.concat(validate2918.errors);
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
if(!(validate2918(data.object, {instancePath:instancePath+"/object",parentData:data,parentDataProperty:"object",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2918.errors : vErrors.concat(validate2918.errors);
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
if(!(validate2918(data.revision, {instancePath:instancePath+"/revision",parentData:data,parentDataProperty:"revision",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2918.errors : vErrors.concat(validate2918.errors);
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
if(!(validate2918(data.digest, {instancePath:instancePath+"/digest",parentData:data,parentDataProperty:"digest",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2918.errors : vErrors.concat(validate2918.errors);
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
validate2998.errors = [{}];
return false;
}
}
validate2998.errors = vErrors;
return errors === 0;
}
validate2998.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema824 = {"type":"string","enum":["restrict","no_action","cascade","set_null"]};

function validate3008(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3008.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate3008.errors = [{}];
return false;
}
if(!((((data === "restrict") || (data === "no_action")) || (data === "cascade")) || (data === "set_null"))){
validate3008.errors = [{}];
return false;
}
validate3008.errors = vErrors;
return errors === 0;
}
validate3008.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema825 = {"type":"string","enum":["staged_awaiting_index","enforced"]};

function validate3011(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3011.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate3011.errors = [{}];
return false;
}
if(!((data === "staged_awaiting_index") || (data === "enforced"))){
validate3011.errors = [{}];
return false;
}
validate3011.errors = vErrors;
return errors === 0;
}
validate3011.evaluated = {"dynamicProps":false,"dynamicItems":false};


function validate2992(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2992.evaluated;
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
validate2992.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(func1.call(schema822.properties, key0))){
validate2992.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.id !== undefined){
const _errs2 = errors;
if(!(validate2916(data.id, {instancePath:instancePath+"/id",parentData:data,parentDataProperty:"id",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2916.errors : vErrors.concat(validate2916.errors);
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
if(!(validate2918(data.name, {instancePath:instancePath+"/name",parentData:data,parentDataProperty:"name",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2918.errors : vErrors.concat(validate2918.errors);
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
if(!(validate2909(data.local_columns, {instancePath:instancePath+"/local_columns",parentData:data,parentDataProperty:"local_columns",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2909.errors : vErrors.concat(validate2909.errors);
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
if(!(validate2918(data.target_object, {instancePath:instancePath+"/target_object",parentData:data,parentDataProperty:"target_object",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2918.errors : vErrors.concat(validate2918.errors);
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
if(!(validate2918(data.target_revision, {instancePath:instancePath+"/target_revision",parentData:data,parentDataProperty:"target_revision",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2918.errors : vErrors.concat(validate2918.errors);
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
if(!(validate2998(data.target_definition, {instancePath:instancePath+"/target_definition",parentData:data,parentDataProperty:"target_definition",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2998.errors : vErrors.concat(validate2998.errors);
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
if(!(validate2909(data.target_columns, {instancePath:instancePath+"/target_columns",parentData:data,parentDataProperty:"target_columns",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2909.errors : vErrors.concat(validate2909.errors);
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
if(!(validate3008(data.on_delete, {instancePath:instancePath+"/on_delete",parentData:data,parentDataProperty:"on_delete",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3008.errors : vErrors.concat(validate3008.errors);
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
if(!(validate3008(data.on_update, {instancePath:instancePath+"/on_update",parentData:data,parentDataProperty:"on_update",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3008.errors : vErrors.concat(validate3008.errors);
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
if(!(validate3011(data.enforcement, {instancePath:instancePath+"/enforcement",parentData:data,parentDataProperty:"enforcement",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3011.errors : vErrors.concat(validate3011.errors);
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
validate2992.errors = [{}];
return false;
}
}
validate2992.errors = vErrors;
return errors === 0;
}
validate2992.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate2991(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2991.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(Array.isArray(data)){
if(data.length > 64){
validate2991.errors = [{}];
return false;
}
else {
var valid0 = true;
const len0 = data.length;
for(let i0=0; i0<len0; i0++){
const _errs1 = errors;
if(!(validate2992(data[i0], {instancePath:instancePath+"/" + i0,parentData:data,parentDataProperty:i0,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2992.errors : vErrors.concat(validate2992.errors);
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
validate2991.errors = [{}];
return false;
}
}
validate2991.errors = vErrors;
return errors === 0;
}
validate2991.evaluated = {"items":true,"dynamicProps":false,"dynamicItems":false};


function validate2912(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2912.evaluated;
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
validate2912.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "next_id") || (key0 === "checks")) || (key0 === "foreign_keys"))){
validate2912.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.next_id !== undefined){
const _errs2 = errors;
if(!(validate2338(data.next_id, {instancePath:instancePath+"/next_id",parentData:data,parentDataProperty:"next_id",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2338.errors : vErrors.concat(validate2338.errors);
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
if(!(validate2914(data.checks, {instancePath:instancePath+"/checks",parentData:data,parentDataProperty:"checks",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2914.errors : vErrors.concat(validate2914.errors);
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
if(!(validate2991(data.foreign_keys, {instancePath:instancePath+"/foreign_keys",parentData:data,parentDataProperty:"foreign_keys",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2991.errors : vErrors.concat(validate2991.errors);
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
validate2912.errors = [{}];
return false;
}
}
validate2912.errors = vErrors;
return errors === 0;
}
validate2912.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate2634(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2634.evaluated;
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
validate2634.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((((((key0 === "definition") || (key0 === "object")) || (key0 === "revision")) || (key0 === "next_column")) || (key0 === "columns")) || (key0 === "primary_key")) || (key0 === "integrity"))){
validate2634.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.definition !== undefined){
const _errs2 = errors;
if(!(validate2332(data.definition, {instancePath:instancePath+"/definition",parentData:data,parentDataProperty:"definition",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2332.errors : vErrors.concat(validate2332.errors);
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
if(!(validate2350(data.object, {instancePath:instancePath+"/object",parentData:data,parentDataProperty:"object",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2350.errors : vErrors.concat(validate2350.errors);
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
if(!(validate2350(data.revision, {instancePath:instancePath+"/revision",parentData:data,parentDataProperty:"revision",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2350.errors : vErrors.concat(validate2350.errors);
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
if(!(validate2350(data.next_column, {instancePath:instancePath+"/next_column",parentData:data,parentDataProperty:"next_column",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2350.errors : vErrors.concat(validate2350.errors);
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
if(!(validate2639(data.columns, {instancePath:instancePath+"/columns",parentData:data,parentDataProperty:"columns",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2639.errors : vErrors.concat(validate2639.errors);
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
if(!(validate2909(data.primary_key, {instancePath:instancePath+"/primary_key",parentData:data,parentDataProperty:"primary_key",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2909.errors : vErrors.concat(validate2909.errors);
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
if(!(validate2912(data.integrity, {instancePath:instancePath+"/integrity",parentData:data,parentDataProperty:"integrity",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2912.errors : vErrors.concat(validate2912.errors);
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
validate2634.errors = [{}];
return false;
}
}
validate2634.errors = vErrors;
return errors === 0;
}
validate2634.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema826 = {"type":"object","additionalProperties":false,"properties":{"database":{"$ref":"#/$defs/CatalogResponse/$defs/T10"},"schema":{"$ref":"#/$defs/CatalogResponse/$defs/T10"},"table":{"$ref":"#/$defs/CatalogResponse/$defs/T10"}},"required":["database","schema","table"]};

function validate3019(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3019.evaluated;
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
validate3019.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "database") || (key0 === "schema")) || (key0 === "table"))){
validate3019.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.database !== undefined){
const _errs2 = errors;
if(!(validate2347(data.database, {instancePath:instancePath+"/database",parentData:data,parentDataProperty:"database",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2347.errors : vErrors.concat(validate2347.errors);
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
if(!(validate2347(data.schema, {instancePath:instancePath+"/schema",parentData:data,parentDataProperty:"schema",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2347.errors : vErrors.concat(validate2347.errors);
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
if(!(validate2347(data.table, {instancePath:instancePath+"/table",parentData:data,parentDataProperty:"table",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2347.errors : vErrors.concat(validate2347.errors);
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
validate3019.errors = [{}];
return false;
}
}
validate3019.errors = vErrors;
return errors === 0;
}
validate3019.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


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
if(((((((data.snapshot === undefined) && (missing0 = "snapshot")) || ((data.binding === undefined) && (missing0 = "binding"))) || ((data.schema === undefined) && (missing0 = "schema"))) || ((data.rows === undefined) && (missing0 = "rows"))) || ((data.changed_lsn === undefined) && (missing0 = "changed_lsn"))) || ((data.authority === undefined) && (missing0 = "authority"))){
validate2625.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((((((key0 === "snapshot") || (key0 === "binding")) || (key0 === "schema")) || (key0 === "rows")) || (key0 === "changed_lsn")) || (key0 === "authority"))){
validate2625.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.snapshot !== undefined){
const _errs2 = errors;
if(!(validate2452(data.snapshot, {instancePath:instancePath+"/snapshot",parentData:data,parentDataProperty:"snapshot",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2452.errors : vErrors.concat(validate2452.errors);
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
if(!(validate2627(data.binding, {instancePath:instancePath+"/binding",parentData:data,parentDataProperty:"binding",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2627.errors : vErrors.concat(validate2627.errors);
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
if(!(validate2634(data.schema, {instancePath:instancePath+"/schema",parentData:data,parentDataProperty:"schema",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2634.errors : vErrors.concat(validate2634.errors);
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
if(!(validate2350(data.rows, {instancePath:instancePath+"/rows",parentData:data,parentDataProperty:"rows",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2350.errors : vErrors.concat(validate2350.errors);
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
if(!(validate2350(data.changed_lsn, {instancePath:instancePath+"/changed_lsn",parentData:data,parentDataProperty:"changed_lsn",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2350.errors : vErrors.concat(validate2350.errors);
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
if(!(validate3019(data.authority, {instancePath:instancePath+"/authority",parentData:data,parentDataProperty:"authority",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3019.errors : vErrors.concat(validate3019.errors);
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
validate2625.errors = [{}];
return false;
}
}
validate2625.errors = vErrors;
return errors === 0;
}
validate2625.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate2450(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2450.evaluated;
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
if(!(validate2451(data.coverage, {instancePath:instancePath+"/coverage",parentData:data,parentDataProperty:"coverage",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2451.errors : vErrors.concat(validate2451.errors);
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
if(!(validate2579(data.object, {instancePath:instancePath+"/object",parentData:data,parentDataProperty:"object",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2579.errors : vErrors.concat(validate2579.errors);
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
if(!(validate2582(data.namespace, {instancePath:instancePath+"/namespace",parentData:data,parentDataProperty:"namespace",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2582.errors : vErrors.concat(validate2582.errors);
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
if(!(validate2591(data.listing, {instancePath:instancePath+"/listing",parentData:data,parentDataProperty:"listing",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2591.errors : vErrors.concat(validate2591.errors);
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
if(!(validate2625(data.source, {instancePath:instancePath+"/source",parentData:data,parentDataProperty:"source",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2625.errors : vErrors.concat(validate2625.errors);
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
validate2450.errors = vErrors;
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
validate2450.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate2450.evaluated = {"dynamicProps":true,"dynamicItems":false};

const schema827 = {"oneOf":[{"type":"object","additionalProperties":false,"required":["definition"],"properties":{"definition":{"$ref":"#/$defs/CatalogResponse/$defs/T198"}}},{"type":"object","additionalProperties":false,"required":["historical"],"properties":{"historical":{"$ref":"#/$defs/CatalogResponse/$defs/T239"}}},{"type":"object","additionalProperties":false,"required":["page"],"properties":{"page":{"$ref":"#/$defs/CatalogResponse/$defs/T241"}}}]};
const schema828 = {"anyOf":[{"$ref":"#/$defs/CatalogResponse/$defs/T199"},{"type":"null"}]};
const schema829 = {"type":"object","additionalProperties":false,"properties":{"stored":{"$ref":"#/$defs/CatalogResponse/$defs/T200"},"schema":{"$ref":"#/$defs/CatalogResponse/$defs/T85"},"sources":{"$ref":"#/$defs/CatalogResponse/$defs/T203"},"body":{"$ref":"#/$defs/CatalogResponse/$defs/T218"}},"required":["stored","schema","sources","body"]};
const schema830 = {"type":"object","additionalProperties":false,"properties":{"kind":{"$ref":"#/$defs/CatalogResponse/$defs/T201"},"interpretation":{"$ref":"#/$defs/CatalogResponse/$defs/T31"},"content":{"$ref":"#/$defs/CatalogResponse/$defs/T38"},"properties":{"$ref":"#/$defs/CatalogResponse/$defs/T202"},"schema_fingerprint":{"$ref":"#/$defs/CatalogResponse/$defs/T11"},"next_column":{"$ref":"#/$defs/CatalogResponse/$defs/T11"},"retired":{"$ref":"#/$defs/CatalogResponse/$defs/T17"}},"required":["kind","interpretation","content","properties","schema_fingerprint","next_column","retired"]};
const schema831 = {"type":"string","enum":["view","property_graph","foreign"]};

function validate3030(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3030.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate3030.errors = [{}];
return false;
}
if(!(((data === "view") || (data === "property_graph")) || (data === "foreign"))){
validate3030.errors = [{}];
return false;
}
validate3030.errors = vErrors;
return errors === 0;
}
validate3030.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema832 = {"type":"object","additionalProperties":false,"properties":{"namespace":{"$ref":"#/$defs/CatalogResponse/$defs/T10"},"authorization":{"$ref":"#/$defs/CatalogResponse/$defs/T10"},"name":{"$ref":"#/$defs/CatalogResponse/$defs/T11"}},"required":["namespace","authorization","name"]};

function validate3034(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3034.evaluated;
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
validate3034.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "namespace") || (key0 === "authorization")) || (key0 === "name"))){
validate3034.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.namespace !== undefined){
const _errs2 = errors;
if(!(validate2347(data.namespace, {instancePath:instancePath+"/namespace",parentData:data,parentDataProperty:"namespace",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2347.errors : vErrors.concat(validate2347.errors);
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
if(!(validate2347(data.authorization, {instancePath:instancePath+"/authorization",parentData:data,parentDataProperty:"authorization",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2347.errors : vErrors.concat(validate2347.errors);
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
if(!(validate2350(data.name, {instancePath:instancePath+"/name",parentData:data,parentDataProperty:"name",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2350.errors : vErrors.concat(validate2350.errors);
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
validate3034.errors = [{}];
return false;
}
}
validate3034.errors = vErrors;
return errors === 0;
}
validate3034.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate3029(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3029.evaluated;
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
validate3029.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((((((key0 === "kind") || (key0 === "interpretation")) || (key0 === "content")) || (key0 === "properties")) || (key0 === "schema_fingerprint")) || (key0 === "next_column")) || (key0 === "retired"))){
validate3029.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.kind !== undefined){
const _errs2 = errors;
if(!(validate3030(data.kind, {instancePath:instancePath+"/kind",parentData:data,parentDataProperty:"kind",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3030.errors : vErrors.concat(validate3030.errors);
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
if(!(validate2428(data.interpretation, {instancePath:instancePath+"/interpretation",parentData:data,parentDataProperty:"interpretation",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2428.errors : vErrors.concat(validate2428.errors);
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
if(!(validate2461(data.content, {instancePath:instancePath+"/content",parentData:data,parentDataProperty:"content",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2461.errors : vErrors.concat(validate2461.errors);
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
if(!(validate3034(data.properties, {instancePath:instancePath+"/properties",parentData:data,parentDataProperty:"properties",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3034.errors : vErrors.concat(validate3034.errors);
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
if(!(validate2350(data.schema_fingerprint, {instancePath:instancePath+"/schema_fingerprint",parentData:data,parentDataProperty:"schema_fingerprint",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2350.errors : vErrors.concat(validate2350.errors);
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
if(!(validate2350(data.next_column, {instancePath:instancePath+"/next_column",parentData:data,parentDataProperty:"next_column",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2350.errors : vErrors.concat(validate2350.errors);
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
if(!(validate2389(data.retired, {instancePath:instancePath+"/retired",parentData:data,parentDataProperty:"retired",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2389.errors : vErrors.concat(validate2389.errors);
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
validate3029.errors = [{}];
return false;
}
}
validate3029.errors = vErrors;
return errors === 0;
}
validate3029.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema833 = {"type":"array","maxItems":4,"items":{"$ref":"#/$defs/CatalogResponse/$defs/T204"}};
const schema834 = {"type":"object","additionalProperties":false,"properties":{"declaration":{"$ref":"#/$defs/CatalogResponse/$defs/T205"},"properties":{"$ref":"#/$defs/CatalogResponse/$defs/T213"},"schema":{"$ref":"#/$defs/CatalogResponse/$defs/T214"}},"required":["declaration","properties","schema"]};
const schema835 = {"type":"object","additionalProperties":false,"properties":{"interpretation":{"$ref":"#/$defs/CatalogResponse/$defs/T206"},"content":{"$ref":"#/$defs/CatalogResponse/$defs/T211"},"schema_fingerprint":{"$ref":"#/$defs/CatalogResponse/$defs/T210"},"retired":{"$ref":"#/$defs/CatalogResponse/$defs/T212"}},"required":["interpretation","content","schema_fingerprint","retired"]};
const schema836 = {"type":"object","additionalProperties":false,"properties":{"object":{"$ref":"#/$defs/CatalogResponse/$defs/T207"},"revision":{"$ref":"#/$defs/CatalogResponse/$defs/T210"},"digest":{"$ref":"#/$defs/CatalogResponse/$defs/T210"}},"required":["object","revision","digest"]};
const schema837 = {"type":"object","additionalProperties":false,"properties":{"scope":{"$ref":"#/$defs/CatalogResponse/$defs/T208"},"branch":{"$ref":"#/$defs/CatalogResponse/$defs/T210"},"object":{"$ref":"#/$defs/CatalogResponse/$defs/T210"}},"required":["scope","branch","object"]};
const schema838 = {"type":"object","additionalProperties":false,"properties":{"realm":{"$ref":"#/$defs/CatalogResponse/$defs/T209"},"resource":{"$ref":"#/$defs/CatalogResponse/$defs/T209"},"catalog":{"$ref":"#/$defs/CatalogResponse/$defs/T210"}},"required":["realm","resource","catalog"]};

function validate3050(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3050.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(!(((typeof data == "number") && (!(data % 1) && !isNaN(data))) && (isFinite(data)))){
validate3050.errors = [{}];
return false;
}
if(errors === 0){
if((typeof data == "number") && (isFinite(data))){
if(data > 9007199254740991 || isNaN(data)){
validate3050.errors = [{}];
return false;
}
else {
if(data < 0 || isNaN(data)){
validate3050.errors = [{}];
return false;
}
}
}
}
validate3050.errors = vErrors;
return errors === 0;
}
validate3050.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema840 = {"type":"string","maxLength":262144};

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
if(typeof data === "string"){
if(func3(data) > 262144){
validate3053.errors = [{}];
return false;
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
validate3053.evaluated = {"dynamicProps":false,"dynamicItems":false};


function validate3049(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3049.evaluated;
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
validate3049.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "realm") || (key0 === "resource")) || (key0 === "catalog"))){
validate3049.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.realm !== undefined){
const _errs2 = errors;
if(!(validate3050(data.realm, {instancePath:instancePath+"/realm",parentData:data,parentDataProperty:"realm",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3050.errors : vErrors.concat(validate3050.errors);
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
if(!(validate3050(data.resource, {instancePath:instancePath+"/resource",parentData:data,parentDataProperty:"resource",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3050.errors : vErrors.concat(validate3050.errors);
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
if(!(validate3053(data.catalog, {instancePath:instancePath+"/catalog",parentData:data,parentDataProperty:"catalog",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3053.errors : vErrors.concat(validate3053.errors);
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
validate3049.errors = [{}];
return false;
}
}
validate3049.errors = vErrors;
return errors === 0;
}
validate3049.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate3048(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3048.evaluated;
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
validate3048.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "scope") || (key0 === "branch")) || (key0 === "object"))){
validate3048.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.scope !== undefined){
const _errs2 = errors;
if(!(validate3049(data.scope, {instancePath:instancePath+"/scope",parentData:data,parentDataProperty:"scope",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3049.errors : vErrors.concat(validate3049.errors);
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
if(!(validate3053(data.branch, {instancePath:instancePath+"/branch",parentData:data,parentDataProperty:"branch",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3053.errors : vErrors.concat(validate3053.errors);
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
if(!(validate3053(data.object, {instancePath:instancePath+"/object",parentData:data,parentDataProperty:"object",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3053.errors : vErrors.concat(validate3053.errors);
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
validate3048.errors = [{}];
return false;
}
}
validate3048.errors = vErrors;
return errors === 0;
}
validate3048.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate3047(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3047.evaluated;
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
validate3047.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "object") || (key0 === "revision")) || (key0 === "digest"))){
validate3047.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.object !== undefined){
const _errs2 = errors;
if(!(validate3048(data.object, {instancePath:instancePath+"/object",parentData:data,parentDataProperty:"object",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3048.errors : vErrors.concat(validate3048.errors);
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
if(!(validate3053(data.revision, {instancePath:instancePath+"/revision",parentData:data,parentDataProperty:"revision",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3053.errors : vErrors.concat(validate3053.errors);
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
if(!(validate3053(data.digest, {instancePath:instancePath+"/digest",parentData:data,parentDataProperty:"digest",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3053.errors : vErrors.concat(validate3053.errors);
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
validate3047.errors = [{}];
return false;
}
}
validate3047.errors = vErrors;
return errors === 0;
}
validate3047.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema841 = {"type":"object","additionalProperties":false,"properties":{"bytes":{"$ref":"#/$defs/CatalogResponse/$defs/T210"},"sha256":{"$ref":"#/$defs/CatalogResponse/$defs/T210"}},"required":["bytes","sha256"]};

function validate3062(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3062.evaluated;
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
validate3062.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "bytes") || (key0 === "sha256"))){
validate3062.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.bytes !== undefined){
const _errs2 = errors;
if(!(validate3053(data.bytes, {instancePath:instancePath+"/bytes",parentData:data,parentDataProperty:"bytes",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3053.errors : vErrors.concat(validate3053.errors);
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
if(!(validate3053(data.sha256, {instancePath:instancePath+"/sha256",parentData:data,parentDataProperty:"sha256",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3053.errors : vErrors.concat(validate3053.errors);
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
validate3062.errors = [{}];
return false;
}
}
validate3062.errors = vErrors;
return errors === 0;
}
validate3062.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema842 = {"type":"boolean"};

function validate3067(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3067.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "boolean"){
validate3067.errors = [{}];
return false;
}
validate3067.errors = vErrors;
return errors === 0;
}
validate3067.evaluated = {"dynamicProps":false,"dynamicItems":false};


function validate3046(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3046.evaluated;
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
validate3046.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((((key0 === "interpretation") || (key0 === "content")) || (key0 === "schema_fingerprint")) || (key0 === "retired"))){
validate3046.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.interpretation !== undefined){
const _errs2 = errors;
if(!(validate3047(data.interpretation, {instancePath:instancePath+"/interpretation",parentData:data,parentDataProperty:"interpretation",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3047.errors : vErrors.concat(validate3047.errors);
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
if(!(validate3062(data.content, {instancePath:instancePath+"/content",parentData:data,parentDataProperty:"content",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3062.errors : vErrors.concat(validate3062.errors);
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
if(!(validate3053(data.schema_fingerprint, {instancePath:instancePath+"/schema_fingerprint",parentData:data,parentDataProperty:"schema_fingerprint",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3053.errors : vErrors.concat(validate3053.errors);
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
if(!(validate3067(data.retired, {instancePath:instancePath+"/retired",parentData:data,parentDataProperty:"retired",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3067.errors : vErrors.concat(validate3067.errors);
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
validate3046.errors = [{}];
return false;
}
}
validate3046.errors = vErrors;
return errors === 0;
}
validate3046.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema843 = {"type":"object","additionalProperties":false,"properties":{"namespace":{"$ref":"#/$defs/CatalogResponse/$defs/T209"},"authorization":{"$ref":"#/$defs/CatalogResponse/$defs/T209"},"name":{"$ref":"#/$defs/CatalogResponse/$defs/T210"}},"required":["namespace","authorization","name"]};

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
if((((data.namespace === undefined) && (missing0 = "namespace")) || ((data.authorization === undefined) && (missing0 = "authorization"))) || ((data.name === undefined) && (missing0 = "name"))){
validate3070.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "namespace") || (key0 === "authorization")) || (key0 === "name"))){
validate3070.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.namespace !== undefined){
const _errs2 = errors;
if(!(validate3050(data.namespace, {instancePath:instancePath+"/namespace",parentData:data,parentDataProperty:"namespace",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3050.errors : vErrors.concat(validate3050.errors);
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
if(!(validate3050(data.authorization, {instancePath:instancePath+"/authorization",parentData:data,parentDataProperty:"authorization",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3050.errors : vErrors.concat(validate3050.errors);
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
if(!(validate3053(data.name, {instancePath:instancePath+"/name",parentData:data,parentDataProperty:"name",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3053.errors : vErrors.concat(validate3053.errors);
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

const schema844 = {"type":"object","additionalProperties":false,"properties":{"definition":{"$ref":"#/$defs/CatalogResponse/$defs/T215"},"object":{"$ref":"#/$defs/CatalogResponse/$defs/T210"},"revision":{"$ref":"#/$defs/CatalogResponse/$defs/T210"},"next_column":{"$ref":"#/$defs/CatalogResponse/$defs/T210"},"columns":{"$ref":"#/$defs/CatalogResponse/$defs/T86"},"primary_key":{"$ref":"#/$defs/CatalogResponse/$defs/T165"},"integrity":{"$ref":"#/$defs/CatalogResponse/$defs/T216"}},"required":["definition","object","revision","next_column","columns","primary_key","integrity"]};

function validate3076(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3076.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate3076.errors = [{}];
return false;
}
if(!(data === "28dd54cfe806369cb6a6d8ed5bb87fed380afb08c79af9812b5bebe2f123b573")){
validate3076.errors = [{}];
return false;
}
validate3076.errors = vErrors;
return errors === 0;
}
validate3076.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema846 = {"type":"object","additionalProperties":false,"properties":{"next_id":{"$ref":"#/$defs/CatalogResponse/$defs/T217"},"checks":{"$ref":"#/$defs/CatalogResponse/$defs/T167"},"foreign_keys":{"$ref":"#/$defs/CatalogResponse/$defs/T191"}},"required":["next_id","checks","foreign_keys"]};

function validate3084(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3084.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(!(((typeof data == "number") && (!(data % 1) && !isNaN(data))) && (isFinite(data)))){
validate3084.errors = [{}];
return false;
}
if(errors === 0){
if((typeof data == "number") && (isFinite(data))){
if(data > 4294967295 || isNaN(data)){
validate3084.errors = [{}];
return false;
}
else {
if(data < 0 || isNaN(data)){
validate3084.errors = [{}];
return false;
}
}
}
}
validate3084.errors = vErrors;
return errors === 0;
}
validate3084.evaluated = {"dynamicProps":false,"dynamicItems":false};


function validate3083(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3083.evaluated;
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
validate3083.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "next_id") || (key0 === "checks")) || (key0 === "foreign_keys"))){
validate3083.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.next_id !== undefined){
const _errs2 = errors;
if(!(validate3084(data.next_id, {instancePath:instancePath+"/next_id",parentData:data,parentDataProperty:"next_id",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3084.errors : vErrors.concat(validate3084.errors);
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
if(!(validate2914(data.checks, {instancePath:instancePath+"/checks",parentData:data,parentDataProperty:"checks",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2914.errors : vErrors.concat(validate2914.errors);
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
if(!(validate2991(data.foreign_keys, {instancePath:instancePath+"/foreign_keys",parentData:data,parentDataProperty:"foreign_keys",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2991.errors : vErrors.concat(validate2991.errors);
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
validate3083.errors = [{}];
return false;
}
}
validate3083.errors = vErrors;
return errors === 0;
}
validate3083.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


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
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((((((((data.definition === undefined) && (missing0 = "definition")) || ((data.object === undefined) && (missing0 = "object"))) || ((data.revision === undefined) && (missing0 = "revision"))) || ((data.next_column === undefined) && (missing0 = "next_column"))) || ((data.columns === undefined) && (missing0 = "columns"))) || ((data.primary_key === undefined) && (missing0 = "primary_key"))) || ((data.integrity === undefined) && (missing0 = "integrity"))){
validate3075.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((((((key0 === "definition") || (key0 === "object")) || (key0 === "revision")) || (key0 === "next_column")) || (key0 === "columns")) || (key0 === "primary_key")) || (key0 === "integrity"))){
validate3075.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.definition !== undefined){
const _errs2 = errors;
if(!(validate3076(data.definition, {instancePath:instancePath+"/definition",parentData:data,parentDataProperty:"definition",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3076.errors : vErrors.concat(validate3076.errors);
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
if(!(validate3053(data.object, {instancePath:instancePath+"/object",parentData:data,parentDataProperty:"object",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3053.errors : vErrors.concat(validate3053.errors);
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
if(!(validate3053(data.revision, {instancePath:instancePath+"/revision",parentData:data,parentDataProperty:"revision",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3053.errors : vErrors.concat(validate3053.errors);
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
if(!(validate3053(data.next_column, {instancePath:instancePath+"/next_column",parentData:data,parentDataProperty:"next_column",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3053.errors : vErrors.concat(validate3053.errors);
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
if(!(validate2639(data.columns, {instancePath:instancePath+"/columns",parentData:data,parentDataProperty:"columns",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2639.errors : vErrors.concat(validate2639.errors);
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
if(!(validate2909(data.primary_key, {instancePath:instancePath+"/primary_key",parentData:data,parentDataProperty:"primary_key",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2909.errors : vErrors.concat(validate2909.errors);
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
if(!(validate3083(data.integrity, {instancePath:instancePath+"/integrity",parentData:data,parentDataProperty:"integrity",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3083.errors : vErrors.concat(validate3083.errors);
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
validate3075.errors = [{}];
return false;
}
}
validate3075.errors = vErrors;
return errors === 0;
}
validate3075.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate3045(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3045.evaluated;
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
validate3045.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "declaration") || (key0 === "properties")) || (key0 === "schema"))){
validate3045.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.declaration !== undefined){
const _errs2 = errors;
if(!(validate3046(data.declaration, {instancePath:instancePath+"/declaration",parentData:data,parentDataProperty:"declaration",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3046.errors : vErrors.concat(validate3046.errors);
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
if(!(validate3070(data.properties, {instancePath:instancePath+"/properties",parentData:data,parentDataProperty:"properties",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3070.errors : vErrors.concat(validate3070.errors);
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
if(!(validate3075(data.schema, {instancePath:instancePath+"/schema",parentData:data,parentDataProperty:"schema",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3075.errors : vErrors.concat(validate3075.errors);
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
validate3045.errors = [{}];
return false;
}
}
validate3045.errors = vErrors;
return errors === 0;
}
validate3045.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


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
if(Array.isArray(data)){
if(data.length > 4){
validate3044.errors = [{}];
return false;
}
else {
var valid0 = true;
const len0 = data.length;
for(let i0=0; i0<len0; i0++){
const _errs1 = errors;
if(!(validate3045(data[i0], {instancePath:instancePath+"/" + i0,parentData:data,parentDataProperty:i0,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3045.errors : vErrors.concat(validate3045.errors);
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
validate3044.errors = [{}];
return false;
}
}
validate3044.errors = vErrors;
return errors === 0;
}
validate3044.evaluated = {"items":true,"dynamicProps":false,"dynamicItems":false};

const schema848 = {"oneOf":[{"type":"object","additionalProperties":false,"required":["view"],"properties":{"view":{"$ref":"#/$defs/CatalogResponse/$defs/T219"}}},{"type":"object","additionalProperties":false,"required":["property_graph"],"properties":{"property_graph":{"$ref":"#/$defs/CatalogResponse/$defs/T222"}}},{"type":"object","additionalProperties":false,"required":["foreign"],"properties":{"foreign":{"$ref":"#/$defs/CatalogResponse/$defs/T233"}}}]};
const schema849 = {"type":"object","additionalProperties":false,"properties":{"plan":{"$ref":"#/$defs/CatalogResponse/$defs/T220"},"source_text":{"$ref":"#/$defs/CatalogResponse/$defs/T11"}},"required":["plan","source_text"]};
const schema850 = {"type":"object","additionalProperties":false,"properties":{"base64":{"$ref":"#/$defs/CatalogResponse/$defs/T221"}},"required":["base64"]};
const schema851 = {"type":"string","maxLength":5592408};

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
if(typeof data === "string"){
if(func3(data) > 5592408){
validate3095.errors = [{}];
return false;
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
validate3095.evaluated = {"dynamicProps":false,"dynamicItems":false};


function validate3094(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3094.evaluated;
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
validate3094.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(key0 === "base64")){
validate3094.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.base64 !== undefined){
if(!(validate3095(data.base64, {instancePath:instancePath+"/base64",parentData:data,parentDataProperty:"base64",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3095.errors : vErrors.concat(validate3095.errors);
errors = vErrors.length;
}
}
}
}
}
else {
validate3094.errors = [{}];
return false;
}
}
validate3094.errors = vErrors;
return errors === 0;
}
validate3094.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate3093(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3093.evaluated;
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
validate3093.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "plan") || (key0 === "source_text"))){
validate3093.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.plan !== undefined){
const _errs2 = errors;
if(!(validate3094(data.plan, {instancePath:instancePath+"/plan",parentData:data,parentDataProperty:"plan",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3094.errors : vErrors.concat(validate3094.errors);
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
if(!(validate2350(data.source_text, {instancePath:instancePath+"/source_text",parentData:data,parentDataProperty:"source_text",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2350.errors : vErrors.concat(validate2350.errors);
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
validate3093.errors = [{}];
return false;
}
}
validate3093.errors = vErrors;
return errors === 0;
}
validate3093.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema852 = {"type":"object","additionalProperties":false,"properties":{"next_mapping":{"$ref":"#/$defs/CatalogResponse/$defs/T11"},"vertices":{"$ref":"#/$defs/CatalogResponse/$defs/T223"},"edges":{"$ref":"#/$defs/CatalogResponse/$defs/T231"}},"required":["next_mapping","vertices","edges"]};
const schema853 = {"type":"array","maxItems":16,"items":{"$ref":"#/$defs/CatalogResponse/$defs/T224"}};
const schema854 = {"type":"object","additionalProperties":false,"properties":{"id":{"$ref":"#/$defs/CatalogResponse/$defs/T225"},"label":{"$ref":"#/$defs/CatalogResponse/$defs/T225"},"key":{"$ref":"#/$defs/CatalogResponse/$defs/T226"},"properties":{"$ref":"#/$defs/CatalogResponse/$defs/T228"}},"required":["id","label","key","properties"]};
const schema855 = {"type":"string","maxLength":262144};

function validate3104(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3104.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(typeof data === "string"){
if(func3(data) > 262144){
validate3104.errors = [{}];
return false;
}
}
else {
validate3104.errors = [{}];
return false;
}
}
validate3104.errors = vErrors;
return errors === 0;
}
validate3104.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema856 = {"type":"object","additionalProperties":false,"properties":{"source":{"$ref":"#/$defs/CatalogResponse/$defs/T227"},"column":{"$ref":"#/$defs/CatalogResponse/$defs/T225"}},"required":["source","column"]};

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
if(!(((typeof data == "number") && (!(data % 1) && !isNaN(data))) && (isFinite(data)))){
validate3108.errors = [{}];
return false;
}
if(errors === 0){
if((typeof data == "number") && (isFinite(data))){
if(data > 255 || isNaN(data)){
validate3108.errors = [{}];
return false;
}
else {
if(data < 0 || isNaN(data)){
validate3108.errors = [{}];
return false;
}
}
}
}
validate3108.errors = vErrors;
return errors === 0;
}
validate3108.evaluated = {"dynamicProps":false,"dynamicItems":false};


function validate3107(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3107.evaluated;
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
validate3107.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "source") || (key0 === "column"))){
validate3107.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.source !== undefined){
const _errs2 = errors;
if(!(validate3108(data.source, {instancePath:instancePath+"/source",parentData:data,parentDataProperty:"source",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3108.errors : vErrors.concat(validate3108.errors);
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
if(!(validate3104(data.column, {instancePath:instancePath+"/column",parentData:data,parentDataProperty:"column",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3104.errors : vErrors.concat(validate3104.errors);
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
validate3107.errors = [{}];
return false;
}
}
validate3107.errors = vErrors;
return errors === 0;
}
validate3107.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema858 = {"type":"array","maxItems":128,"items":{"$ref":"#/$defs/CatalogResponse/$defs/T229"}};
const schema859 = {"type":"object","additionalProperties":false,"properties":{"id":{"$ref":"#/$defs/CatalogResponse/$defs/T46"},"name":{"$ref":"#/$defs/CatalogResponse/$defs/T46"},"value":{"$ref":"#/$defs/CatalogResponse/$defs/T230"}},"required":["id","name","value"]};
const schema860 = {"type":"object","additionalProperties":false,"properties":{"source":{"$ref":"#/$defs/CatalogResponse/$defs/T91"},"column":{"$ref":"#/$defs/CatalogResponse/$defs/T46"}},"required":["source","column"]};

function validate3116(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3116.evaluated;
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
validate3116.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "source") || (key0 === "column"))){
validate3116.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.source !== undefined){
const _errs2 = errors;
if(!(validate2661(data.source, {instancePath:instancePath+"/source",parentData:data,parentDataProperty:"source",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2661.errors : vErrors.concat(validate2661.errors);
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
if(!(validate2493(data.column, {instancePath:instancePath+"/column",parentData:data,parentDataProperty:"column",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2493.errors : vErrors.concat(validate2493.errors);
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
validate3116.errors = [{}];
return false;
}
}
validate3116.errors = vErrors;
return errors === 0;
}
validate3116.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate3113(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3113.evaluated;
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
validate3113.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "id") || (key0 === "name")) || (key0 === "value"))){
validate3113.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.id !== undefined){
const _errs2 = errors;
if(!(validate2493(data.id, {instancePath:instancePath+"/id",parentData:data,parentDataProperty:"id",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2493.errors : vErrors.concat(validate2493.errors);
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
if(!(validate2493(data.name, {instancePath:instancePath+"/name",parentData:data,parentDataProperty:"name",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2493.errors : vErrors.concat(validate2493.errors);
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
if(!(validate3116(data.value, {instancePath:instancePath+"/value",parentData:data,parentDataProperty:"value",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3116.errors : vErrors.concat(validate3116.errors);
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
validate3113.errors = [{}];
return false;
}
}
validate3113.errors = vErrors;
return errors === 0;
}
validate3113.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate3112(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3112.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(Array.isArray(data)){
if(data.length > 128){
validate3112.errors = [{}];
return false;
}
else {
var valid0 = true;
const len0 = data.length;
for(let i0=0; i0<len0; i0++){
const _errs1 = errors;
if(!(validate3113(data[i0], {instancePath:instancePath+"/" + i0,parentData:data,parentDataProperty:i0,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3113.errors : vErrors.concat(validate3113.errors);
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
validate3112.errors = [{}];
return false;
}
}
validate3112.errors = vErrors;
return errors === 0;
}
validate3112.evaluated = {"items":true,"dynamicProps":false,"dynamicItems":false};


function validate3103(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3103.evaluated;
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
validate3103.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((((key0 === "id") || (key0 === "label")) || (key0 === "key")) || (key0 === "properties"))){
validate3103.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.id !== undefined){
const _errs2 = errors;
if(!(validate3104(data.id, {instancePath:instancePath+"/id",parentData:data,parentDataProperty:"id",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3104.errors : vErrors.concat(validate3104.errors);
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
if(!(validate3104(data.label, {instancePath:instancePath+"/label",parentData:data,parentDataProperty:"label",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3104.errors : vErrors.concat(validate3104.errors);
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
if(!(validate3107(data.key, {instancePath:instancePath+"/key",parentData:data,parentDataProperty:"key",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3107.errors : vErrors.concat(validate3107.errors);
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
if(!(validate3112(data.properties, {instancePath:instancePath+"/properties",parentData:data,parentDataProperty:"properties",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3112.errors : vErrors.concat(validate3112.errors);
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
validate3103.errors = [{}];
return false;
}
}
validate3103.errors = vErrors;
return errors === 0;
}
validate3103.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate3102(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3102.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(Array.isArray(data)){
if(data.length > 16){
validate3102.errors = [{}];
return false;
}
else {
var valid0 = true;
const len0 = data.length;
for(let i0=0; i0<len0; i0++){
const _errs1 = errors;
if(!(validate3103(data[i0], {instancePath:instancePath+"/" + i0,parentData:data,parentDataProperty:i0,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3103.errors : vErrors.concat(validate3103.errors);
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
validate3102.errors = [{}];
return false;
}
}
validate3102.errors = vErrors;
return errors === 0;
}
validate3102.evaluated = {"items":true,"dynamicProps":false,"dynamicItems":false};

const schema861 = {"type":"array","maxItems":16,"items":{"$ref":"#/$defs/CatalogResponse/$defs/T232"}};
const schema862 = {"type":"object","additionalProperties":false,"properties":{"id":{"$ref":"#/$defs/CatalogResponse/$defs/T225"},"label":{"$ref":"#/$defs/CatalogResponse/$defs/T225"},"key":{"$ref":"#/$defs/CatalogResponse/$defs/T226"},"source_vertex":{"$ref":"#/$defs/CatalogResponse/$defs/T225"},"source_key":{"$ref":"#/$defs/CatalogResponse/$defs/T226"},"target_vertex":{"$ref":"#/$defs/CatalogResponse/$defs/T225"},"target_key":{"$ref":"#/$defs/CatalogResponse/$defs/T226"},"properties":{"$ref":"#/$defs/CatalogResponse/$defs/T228"}},"required":["id","label","key","source_vertex","source_key","target_vertex","target_key","properties"]};

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
if(((((((((data.id === undefined) && (missing0 = "id")) || ((data.label === undefined) && (missing0 = "label"))) || ((data.key === undefined) && (missing0 = "key"))) || ((data.source_vertex === undefined) && (missing0 = "source_vertex"))) || ((data.source_key === undefined) && (missing0 = "source_key"))) || ((data.target_vertex === undefined) && (missing0 = "target_vertex"))) || ((data.target_key === undefined) && (missing0 = "target_key"))) || ((data.properties === undefined) && (missing0 = "properties"))){
validate3125.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((((((((key0 === "id") || (key0 === "label")) || (key0 === "key")) || (key0 === "source_vertex")) || (key0 === "source_key")) || (key0 === "target_vertex")) || (key0 === "target_key")) || (key0 === "properties"))){
validate3125.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.id !== undefined){
const _errs2 = errors;
if(!(validate3104(data.id, {instancePath:instancePath+"/id",parentData:data,parentDataProperty:"id",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3104.errors : vErrors.concat(validate3104.errors);
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
if(!(validate3104(data.label, {instancePath:instancePath+"/label",parentData:data,parentDataProperty:"label",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3104.errors : vErrors.concat(validate3104.errors);
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
if(!(validate3107(data.key, {instancePath:instancePath+"/key",parentData:data,parentDataProperty:"key",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3107.errors : vErrors.concat(validate3107.errors);
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
if(!(validate3104(data.source_vertex, {instancePath:instancePath+"/source_vertex",parentData:data,parentDataProperty:"source_vertex",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3104.errors : vErrors.concat(validate3104.errors);
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
if(!(validate3107(data.source_key, {instancePath:instancePath+"/source_key",parentData:data,parentDataProperty:"source_key",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3107.errors : vErrors.concat(validate3107.errors);
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
if(!(validate3104(data.target_vertex, {instancePath:instancePath+"/target_vertex",parentData:data,parentDataProperty:"target_vertex",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3104.errors : vErrors.concat(validate3104.errors);
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
if(!(validate3107(data.target_key, {instancePath:instancePath+"/target_key",parentData:data,parentDataProperty:"target_key",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3107.errors : vErrors.concat(validate3107.errors);
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
if(!(validate3112(data.properties, {instancePath:instancePath+"/properties",parentData:data,parentDataProperty:"properties",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3112.errors : vErrors.concat(validate3112.errors);
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
validate3125.errors = [{}];
return false;
}
}
validate3125.errors = vErrors;
return errors === 0;
}
validate3125.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate3124(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3124.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(Array.isArray(data)){
if(data.length > 16){
validate3124.errors = [{}];
return false;
}
else {
var valid0 = true;
const len0 = data.length;
for(let i0=0; i0<len0; i0++){
const _errs1 = errors;
if(!(validate3125(data[i0], {instancePath:instancePath+"/" + i0,parentData:data,parentDataProperty:i0,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3125.errors : vErrors.concat(validate3125.errors);
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
validate3124.errors = [{}];
return false;
}
}
validate3124.errors = vErrors;
return errors === 0;
}
validate3124.evaluated = {"items":true,"dynamicProps":false,"dynamicItems":false};


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
if((((data.next_mapping === undefined) && (missing0 = "next_mapping")) || ((data.vertices === undefined) && (missing0 = "vertices"))) || ((data.edges === undefined) && (missing0 = "edges"))){
validate3100.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "next_mapping") || (key0 === "vertices")) || (key0 === "edges"))){
validate3100.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.next_mapping !== undefined){
const _errs2 = errors;
if(!(validate2350(data.next_mapping, {instancePath:instancePath+"/next_mapping",parentData:data,parentDataProperty:"next_mapping",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2350.errors : vErrors.concat(validate2350.errors);
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
if(!(validate3102(data.vertices, {instancePath:instancePath+"/vertices",parentData:data,parentDataProperty:"vertices",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3102.errors : vErrors.concat(validate3102.errors);
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
if(!(validate3124(data.edges, {instancePath:instancePath+"/edges",parentData:data,parentDataProperty:"edges",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3124.errors : vErrors.concat(validate3124.errors);
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
validate3100.errors = [{}];
return false;
}
}
validate3100.errors = vErrors;
return errors === 0;
}
validate3100.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema863 = {"type":"object","additionalProperties":false,"properties":{"record_bytes":{"$ref":"#/$defs/CatalogResponse/$defs/T6"},"fields":{"$ref":"#/$defs/CatalogResponse/$defs/T234"},"malformed":{"$ref":"#/$defs/CatalogResponse/$defs/T236"},"input":{"$ref":"#/$defs/CatalogResponse/$defs/T237"}},"required":["record_bytes","fields","malformed","input"]};
const schema864 = {"type":"array","maxItems":128,"items":{"$ref":"#/$defs/CatalogResponse/$defs/T235"}};
const schema865 = {"type":"object","additionalProperties":false,"properties":{"column":{"$ref":"#/$defs/CatalogResponse/$defs/T46"},"offset":{"$ref":"#/$defs/CatalogResponse/$defs/T108"},"bytes":{"$ref":"#/$defs/CatalogResponse/$defs/T108"},"encoding":{"$ref":"#/$defs/CatalogResponse/$defs/T145"}},"required":["column","offset","bytes","encoding"]};

function validate3140(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3140.evaluated;
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
validate3140.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((((key0 === "column") || (key0 === "offset")) || (key0 === "bytes")) || (key0 === "encoding"))){
validate3140.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.column !== undefined){
const _errs2 = errors;
if(!(validate2493(data.column, {instancePath:instancePath+"/column",parentData:data,parentDataProperty:"column",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2493.errors : vErrors.concat(validate2493.errors);
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
if(!(validate2727(data.offset, {instancePath:instancePath+"/offset",parentData:data,parentDataProperty:"offset",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2727.errors : vErrors.concat(validate2727.errors);
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
if(!(validate2727(data.bytes, {instancePath:instancePath+"/bytes",parentData:data,parentDataProperty:"bytes",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2727.errors : vErrors.concat(validate2727.errors);
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
if(!(validate2859(data.encoding, {instancePath:instancePath+"/encoding",parentData:data,parentDataProperty:"encoding",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2859.errors : vErrors.concat(validate2859.errors);
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
validate3140.errors = [{}];
return false;
}
}
validate3140.errors = vErrors;
return errors === 0;
}
validate3140.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate3139(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3139.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(Array.isArray(data)){
if(data.length > 128){
validate3139.errors = [{}];
return false;
}
else {
var valid0 = true;
const len0 = data.length;
for(let i0=0; i0<len0; i0++){
const _errs1 = errors;
if(!(validate3140(data[i0], {instancePath:instancePath+"/" + i0,parentData:data,parentDataProperty:i0,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3140.errors : vErrors.concat(validate3140.errors);
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
validate3139.errors = [{}];
return false;
}
}
validate3139.errors = vErrors;
return errors === 0;
}
validate3139.evaluated = {"items":true,"dynamicProps":false,"dynamicItems":false};

const schema866 = {"type":"string","enum":["reject","type_error"]};

function validate3147(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3147.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate3147.errors = [{}];
return false;
}
if(!((data === "reject") || (data === "type_error"))){
validate3147.errors = [{}];
return false;
}
validate3147.errors = vErrors;
return errors === 0;
}
validate3147.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema867 = {"type":"object","additionalProperties":false,"properties":{"content":{"$ref":"#/$defs/CatalogResponse/$defs/T38"},"availability":{"$ref":"#/$defs/CatalogResponse/$defs/T238"},"provenance":{"$ref":"#/$defs/CatalogResponse/$defs/T11"}},"required":["content","availability","provenance"]};
const schema868 = {"type":"string","enum":["retained","unavailable"]};

function validate3151(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3151.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate3151.errors = [{}];
return false;
}
if(!((data === "retained") || (data === "unavailable"))){
validate3151.errors = [{}];
return false;
}
validate3151.errors = vErrors;
return errors === 0;
}
validate3151.evaluated = {"dynamicProps":false,"dynamicItems":false};


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
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((((data.content === undefined) && (missing0 = "content")) || ((data.availability === undefined) && (missing0 = "availability"))) || ((data.provenance === undefined) && (missing0 = "provenance"))){
validate3149.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "content") || (key0 === "availability")) || (key0 === "provenance"))){
validate3149.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.content !== undefined){
const _errs2 = errors;
if(!(validate2461(data.content, {instancePath:instancePath+"/content",parentData:data,parentDataProperty:"content",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2461.errors : vErrors.concat(validate2461.errors);
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
if(!(validate3151(data.availability, {instancePath:instancePath+"/availability",parentData:data,parentDataProperty:"availability",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3151.errors : vErrors.concat(validate3151.errors);
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
if(!(validate2350(data.provenance, {instancePath:instancePath+"/provenance",parentData:data,parentDataProperty:"provenance",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2350.errors : vErrors.concat(validate2350.errors);
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
validate3149.errors = [{}];
return false;
}
}
validate3149.errors = vErrors;
return errors === 0;
}
validate3149.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


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
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if(((((data.record_bytes === undefined) && (missing0 = "record_bytes")) || ((data.fields === undefined) && (missing0 = "fields"))) || ((data.malformed === undefined) && (missing0 = "malformed"))) || ((data.input === undefined) && (missing0 = "input"))){
validate3137.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((((key0 === "record_bytes") || (key0 === "fields")) || (key0 === "malformed")) || (key0 === "input"))){
validate3137.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.record_bytes !== undefined){
const _errs2 = errors;
if(!(validate2338(data.record_bytes, {instancePath:instancePath+"/record_bytes",parentData:data,parentDataProperty:"record_bytes",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2338.errors : vErrors.concat(validate2338.errors);
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
if(!(validate3139(data.fields, {instancePath:instancePath+"/fields",parentData:data,parentDataProperty:"fields",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3139.errors : vErrors.concat(validate3139.errors);
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
if(!(validate3147(data.malformed, {instancePath:instancePath+"/malformed",parentData:data,parentDataProperty:"malformed",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3147.errors : vErrors.concat(validate3147.errors);
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
if(!(validate3149(data.input, {instancePath:instancePath+"/input",parentData:data,parentDataProperty:"input",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3149.errors : vErrors.concat(validate3149.errors);
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
validate3137.errors = [{}];
return false;
}
}
validate3137.errors = vErrors;
return errors === 0;
}
validate3137.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


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
if(!(validate3093(data.view, {instancePath:instancePath+"/view",parentData:data,parentDataProperty:"view",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3093.errors : vErrors.concat(validate3093.errors);
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
if(!(validate3100(data.property_graph, {instancePath:instancePath+"/property_graph",parentData:data,parentDataProperty:"property_graph",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3100.errors : vErrors.concat(validate3100.errors);
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
if(!(validate3137(data.foreign, {instancePath:instancePath+"/foreign",parentData:data,parentDataProperty:"foreign",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3137.errors : vErrors.concat(validate3137.errors);
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
validate3092.errors = vErrors;
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
validate3092.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate3092.evaluated = {"dynamicProps":true,"dynamicItems":false};


function validate3028(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3028.evaluated;
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
validate3028.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((((key0 === "stored") || (key0 === "schema")) || (key0 === "sources")) || (key0 === "body"))){
validate3028.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.stored !== undefined){
const _errs2 = errors;
if(!(validate3029(data.stored, {instancePath:instancePath+"/stored",parentData:data,parentDataProperty:"stored",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3029.errors : vErrors.concat(validate3029.errors);
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
if(!(validate2634(data.schema, {instancePath:instancePath+"/schema",parentData:data,parentDataProperty:"schema",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2634.errors : vErrors.concat(validate2634.errors);
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
if(!(validate3044(data.sources, {instancePath:instancePath+"/sources",parentData:data,parentDataProperty:"sources",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3044.errors : vErrors.concat(validate3044.errors);
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
if(!(validate3092(data.body, {instancePath:instancePath+"/body",parentData:data,parentDataProperty:"body",rootData,dynamicAnchors}))){
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
validate3028.errors = [{}];
return false;
}
}
validate3028.errors = vErrors;
return errors === 0;
}
validate3028.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate3027(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3027.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate3028(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3028.errors : vErrors.concat(validate3028.errors);
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
validate3027.errors = vErrors;
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
validate3027.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate3027.evaluated = {"dynamicProps":true,"dynamicItems":false};

const schema869 = {"type":"object","additionalProperties":false,"properties":{"snapshot":{"$ref":"#/$defs/CatalogResponse/$defs/T36"},"catalog":{"$ref":"#/$defs/CatalogResponse/$defs/T240"},"definition":{"$ref":"#/$defs/CatalogResponse/$defs/T198"}},"required":["snapshot","catalog","definition"]};
const schema870 = {"anyOf":[{"$ref":"#/$defs/CatalogResponse/$defs/T26"},{"type":"null"}]};

function validate3161(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3161.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate2415(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2415.errors : vErrors.concat(validate2415.errors);
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
validate3161.errors = vErrors;
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
validate3161.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate3161.evaluated = {"dynamicProps":true,"dynamicItems":false};


function validate3159(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3159.evaluated;
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
validate3159.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "snapshot") || (key0 === "catalog")) || (key0 === "definition"))){
validate3159.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.snapshot !== undefined){
const _errs2 = errors;
if(!(validate2452(data.snapshot, {instancePath:instancePath+"/snapshot",parentData:data,parentDataProperty:"snapshot",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2452.errors : vErrors.concat(validate2452.errors);
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
if(!(validate3161(data.catalog, {instancePath:instancePath+"/catalog",parentData:data,parentDataProperty:"catalog",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3161.errors : vErrors.concat(validate3161.errors);
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
if(!(validate3027(data.definition, {instancePath:instancePath+"/definition",parentData:data,parentDataProperty:"definition",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3027.errors : vErrors.concat(validate3027.errors);
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
validate3159.errors = [{}];
return false;
}
}
validate3159.errors = vErrors;
return errors === 0;
}
validate3159.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema871 = {"type":"object","additionalProperties":false,"properties":{"entries":{"$ref":"#/$defs/CatalogResponse/$defs/T242"},"next":{"$ref":"#/$defs/CatalogResponse/$defs/T244"},"snapshot":{"$ref":"#/$defs/CatalogResponse/$defs/T246"},"position":{"$ref":"#/$defs/CatalogResponse/$defs/T240"}},"required":["entries","next","snapshot","position"]};
const schema872 = {"type":"array","minItems":4,"maxItems":4,"items":{"$ref":"#/$defs/CatalogResponse/$defs/T243"}};
const schema873 = {"anyOf":[{"$ref":"#/$defs/CatalogResponse/$defs/T200"},{"type":"null"}]};

function validate3168(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3168.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate3029(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3029.errors : vErrors.concat(validate3029.errors);
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
validate3168.errors = vErrors;
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
validate3168.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate3168.evaluated = {"dynamicProps":true,"dynamicItems":false};


function validate3167(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3167.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(Array.isArray(data)){
if(data.length > 4){
validate3167.errors = [{}];
return false;
}
else {
if(data.length < 4){
validate3167.errors = [{}];
return false;
}
else {
var valid0 = true;
const len0 = data.length;
for(let i0=0; i0<len0; i0++){
const _errs1 = errors;
if(!(validate3168(data[i0], {instancePath:instancePath+"/" + i0,parentData:data,parentDataProperty:i0,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3168.errors : vErrors.concat(validate3168.errors);
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
validate3167.errors = [{}];
return false;
}
}
validate3167.errors = vErrors;
return errors === 0;
}
validate3167.evaluated = {"items":true,"dynamicProps":false,"dynamicItems":false};

const schema874 = {"anyOf":[{"$ref":"#/$defs/CatalogResponse/$defs/T245"},{"type":"null"}]};
const schema875 = {"type":"object","additionalProperties":false,"properties":{"definition":{"$ref":"#/$defs/CatalogResponse/$defs/T4"},"connection":{"$ref":"#/$defs/CatalogResponse/$defs/T22"},"namespace":{"$ref":"#/$defs/CatalogResponse/$defs/T10"},"selector":{"$ref":"#/$defs/CatalogResponse/$defs/T72"},"after":{"$ref":"#/$defs/CatalogResponse/$defs/T11"}},"required":["definition","connection","namespace","selector","after"]};

function validate3173(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3173.evaluated;
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
validate3173.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((((key0 === "definition") || (key0 === "connection")) || (key0 === "namespace")) || (key0 === "selector")) || (key0 === "after"))){
validate3173.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.definition !== undefined){
const _errs2 = errors;
if(!(validate2332(data.definition, {instancePath:instancePath+"/definition",parentData:data,parentDataProperty:"definition",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2332.errors : vErrors.concat(validate2332.errors);
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
if(!(validate2400(data.connection, {instancePath:instancePath+"/connection",parentData:data,parentDataProperty:"connection",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2400.errors : vErrors.concat(validate2400.errors);
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
if(!(validate2347(data.namespace, {instancePath:instancePath+"/namespace",parentData:data,parentDataProperty:"namespace",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2347.errors : vErrors.concat(validate2347.errors);
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
if(!(validate2579(data.selector, {instancePath:instancePath+"/selector",parentData:data,parentDataProperty:"selector",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2579.errors : vErrors.concat(validate2579.errors);
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
if(!(validate2350(data.after, {instancePath:instancePath+"/after",parentData:data,parentDataProperty:"after",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2350.errors : vErrors.concat(validate2350.errors);
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
validate3173.errors = [{}];
return false;
}
}
validate3173.errors = vErrors;
return errors === 0;
}
validate3173.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


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
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate3173(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3173.errors : vErrors.concat(validate3173.errors);
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
validate3172.errors = vErrors;
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
validate3172.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate3172.evaluated = {"dynamicProps":true,"dynamicItems":false};

const schema876 = {"anyOf":[{"$ref":"#/$defs/CatalogResponse/$defs/T36"},{"type":"null"}]};

function validate3181(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3181.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate2452(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2452.errors : vErrors.concat(validate2452.errors);
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
validate3181.errors = vErrors;
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
validate3181.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate3181.evaluated = {"dynamicProps":true,"dynamicItems":false};


function validate3166(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3166.evaluated;
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
validate3166.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((((key0 === "entries") || (key0 === "next")) || (key0 === "snapshot")) || (key0 === "position"))){
validate3166.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.entries !== undefined){
const _errs2 = errors;
if(!(validate3167(data.entries, {instancePath:instancePath+"/entries",parentData:data,parentDataProperty:"entries",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3167.errors : vErrors.concat(validate3167.errors);
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
if(!(validate3172(data.next, {instancePath:instancePath+"/next",parentData:data,parentDataProperty:"next",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3172.errors : vErrors.concat(validate3172.errors);
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
if(!(validate3181(data.snapshot, {instancePath:instancePath+"/snapshot",parentData:data,parentDataProperty:"snapshot",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3181.errors : vErrors.concat(validate3181.errors);
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
if(!(validate3161(data.position, {instancePath:instancePath+"/position",parentData:data,parentDataProperty:"position",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3161.errors : vErrors.concat(validate3161.errors);
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
validate3166.errors = [{}];
return false;
}
}
validate3166.errors = vErrors;
return errors === 0;
}
validate3166.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate3026(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3026.evaluated;
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
if(!(validate3027(data.definition, {instancePath:instancePath+"/definition",parentData:data,parentDataProperty:"definition",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3027.errors : vErrors.concat(validate3027.errors);
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
if(!(validate3159(data.historical, {instancePath:instancePath+"/historical",parentData:data,parentDataProperty:"historical",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3159.errors : vErrors.concat(validate3159.errors);
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
if(!(validate3166(data.page, {instancePath:instancePath+"/page",parentData:data,parentDataProperty:"page",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3166.errors : vErrors.concat(validate3166.errors);
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
validate3026.errors = vErrors;
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
validate3026.errors = vErrors;
evaluated0.props = props1;
return errors === 0;
}
validate3026.evaluated = {"dynamicProps":true,"dynamicItems":false};

const schema877 = {"type":"object","additionalProperties":false,"properties":{"entries":{"$ref":"#/$defs/CatalogResponse/$defs/T248"},"next":{"$ref":"#/$defs/CatalogResponse/$defs/T20"},"position":{"$ref":"#/$defs/CatalogResponse/$defs/T26"}},"required":["entries","next","position"]};
const schema878 = {"type":"array","minItems":8,"maxItems":8,"items":{"$ref":"#/$defs/CatalogResponse/$defs/T249"}};
const schema879 = {"anyOf":[{"$ref":"#/$defs/CatalogResponse/$defs/T250"},{"type":"null"}]};
const schema880 = {"type":"object","additionalProperties":false,"properties":{"definition":{"$ref":"#/$defs/CatalogResponse/$defs/T251"},"interpretation":{"$ref":"#/$defs/CatalogResponse/$defs/T31"},"position":{"$ref":"#/$defs/CatalogResponse/$defs/T26"}},"required":["definition","interpretation","position"]};
const schema881 = {"type":"object","additionalProperties":false,"properties":{"object":{"$ref":"#/$defs/CatalogResponse/$defs/T32"},"revision":{"$ref":"#/$defs/CatalogResponse/$defs/T11"},"namespace":{"$ref":"#/$defs/CatalogResponse/$defs/T10"},"name":{"$ref":"#/$defs/CatalogResponse/$defs/T11"},"authorization":{"$ref":"#/$defs/CatalogResponse/$defs/T10"},"resource":{"$ref":"#/$defs/CatalogResponse/$defs/T10"},"allocating_principal":{"$ref":"#/$defs/CatalogResponse/$defs/T10"},"allocation":{"$ref":"#/$defs/CatalogResponse/$defs/T252"},"creation":{"$ref":"#/$defs/CatalogResponse/$defs/T253"}},"required":["object","revision","namespace","name","authorization","resource","allocating_principal","allocation","creation"]};
const schema882 = {"type":"object","additionalProperties":false,"properties":{"sequence":{"$ref":"#/$defs/CatalogResponse/$defs/T10"}},"required":["sequence"]};

function validate3199(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3199.evaluated;
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
validate3199.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(key0 === "sequence")){
validate3199.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.sequence !== undefined){
if(!(validate2347(data.sequence, {instancePath:instancePath+"/sequence",parentData:data,parentDataProperty:"sequence",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2347.errors : vErrors.concat(validate2347.errors);
errors = vErrors.length;
}
}
}
}
}
else {
validate3199.errors = [{}];
return false;
}
}
validate3199.errors = vErrors;
return errors === 0;
}
validate3199.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema883 = {"type":"object","additionalProperties":false,"properties":{"namespace":{"$ref":"#/$defs/CatalogResponse/$defs/T10"},"name":{"$ref":"#/$defs/CatalogResponse/$defs/T11"},"owner":{"$ref":"#/$defs/CatalogResponse/$defs/T10"},"writer":{"$ref":"#/$defs/CatalogResponse/$defs/T10"},"owned":{"$ref":"#/$defs/CatalogResponse/$defs/T17"},"deadline_ms":{"$ref":"#/$defs/CatalogResponse/$defs/T23"},"history_ms":{"$ref":"#/$defs/CatalogResponse/$defs/T23"},"spec":{"$ref":"#/$defs/CatalogResponse/$defs/T254"}},"required":["namespace","name","owner","writer","owned","deadline_ms","history_ms","spec"]};
const schema884 = {"oneOf":[{"type":"object","additionalProperties":false,"required":["document"],"properties":{"document":{"$ref":"#/$defs/CatalogResponse/$defs/T255"}}}]};
const schema885 = {"type":"object","additionalProperties":false,"properties":{"document":{"$ref":"#/$defs/CatalogResponse/$defs/T11"},"type_revision":{"$ref":"#/$defs/CatalogResponse/$defs/T6"},"limits":{"$ref":"#/$defs/CatalogResponse/$defs/T256"}},"required":["document","type_revision","limits"]};
const schema886 = {"type":"object","additionalProperties":false,"properties":{"record_bytes":{"$ref":"#/$defs/CatalogResponse/$defs/T6"},"staging_bytes":{"$ref":"#/$defs/CatalogResponse/$defs/T11"},"staging_records":{"$ref":"#/$defs/CatalogResponse/$defs/T6"}},"required":["record_bytes","staging_bytes","staging_records"]};

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
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((((data.record_bytes === undefined) && (missing0 = "record_bytes")) || ((data.staging_bytes === undefined) && (missing0 = "staging_bytes"))) || ((data.staging_records === undefined) && (missing0 = "staging_records"))){
validate3214.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "record_bytes") || (key0 === "staging_bytes")) || (key0 === "staging_records"))){
validate3214.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.record_bytes !== undefined){
const _errs2 = errors;
if(!(validate2338(data.record_bytes, {instancePath:instancePath+"/record_bytes",parentData:data,parentDataProperty:"record_bytes",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2338.errors : vErrors.concat(validate2338.errors);
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
if(!(validate2350(data.staging_bytes, {instancePath:instancePath+"/staging_bytes",parentData:data,parentDataProperty:"staging_bytes",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2350.errors : vErrors.concat(validate2350.errors);
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
if(!(validate2338(data.staging_records, {instancePath:instancePath+"/staging_records",parentData:data,parentDataProperty:"staging_records",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2338.errors : vErrors.concat(validate2338.errors);
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
validate3214.errors = [{}];
return false;
}
}
validate3214.errors = vErrors;
return errors === 0;
}
validate3214.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate3211(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3211.evaluated;
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
validate3211.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "document") || (key0 === "type_revision")) || (key0 === "limits"))){
validate3211.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.document !== undefined){
const _errs2 = errors;
if(!(validate2350(data.document, {instancePath:instancePath+"/document",parentData:data,parentDataProperty:"document",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2350.errors : vErrors.concat(validate2350.errors);
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
if(!(validate2338(data.type_revision, {instancePath:instancePath+"/type_revision",parentData:data,parentDataProperty:"type_revision",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2338.errors : vErrors.concat(validate2338.errors);
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
if(!(validate3214(data.limits, {instancePath:instancePath+"/limits",parentData:data,parentDataProperty:"limits",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3214.errors : vErrors.concat(validate3214.errors);
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
validate3211.errors = [{}];
return false;
}
}
validate3211.errors = vErrors;
return errors === 0;
}
validate3211.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate3210(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3210.evaluated;
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
if(!(validate3211(data.document, {instancePath:instancePath+"/document",parentData:data,parentDataProperty:"document",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3211.errors : vErrors.concat(validate3211.errors);
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
validate3210.errors = vErrors;
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
validate3210.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate3210.evaluated = {"dynamicProps":true,"dynamicItems":false};


function validate3202(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3202.evaluated;
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
validate3202.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((((((((key0 === "namespace") || (key0 === "name")) || (key0 === "owner")) || (key0 === "writer")) || (key0 === "owned")) || (key0 === "deadline_ms")) || (key0 === "history_ms")) || (key0 === "spec"))){
validate3202.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.namespace !== undefined){
const _errs2 = errors;
if(!(validate2347(data.namespace, {instancePath:instancePath+"/namespace",parentData:data,parentDataProperty:"namespace",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2347.errors : vErrors.concat(validate2347.errors);
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
if(!(validate2350(data.name, {instancePath:instancePath+"/name",parentData:data,parentDataProperty:"name",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2350.errors : vErrors.concat(validate2350.errors);
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
if(!(validate2347(data.owner, {instancePath:instancePath+"/owner",parentData:data,parentDataProperty:"owner",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2347.errors : vErrors.concat(validate2347.errors);
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
if(!(validate2347(data.writer, {instancePath:instancePath+"/writer",parentData:data,parentDataProperty:"writer",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2347.errors : vErrors.concat(validate2347.errors);
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
if(!(validate2389(data.owned, {instancePath:instancePath+"/owned",parentData:data,parentDataProperty:"owned",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2389.errors : vErrors.concat(validate2389.errors);
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
if(!(validate2405(data.deadline_ms, {instancePath:instancePath+"/deadline_ms",parentData:data,parentDataProperty:"deadline_ms",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2405.errors : vErrors.concat(validate2405.errors);
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
if(!(validate2405(data.history_ms, {instancePath:instancePath+"/history_ms",parentData:data,parentDataProperty:"history_ms",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2405.errors : vErrors.concat(validate2405.errors);
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
if(!(validate3210(data.spec, {instancePath:instancePath+"/spec",parentData:data,parentDataProperty:"spec",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3210.errors : vErrors.concat(validate3210.errors);
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
validate3202.errors = [{}];
return false;
}
}
validate3202.errors = vErrors;
return errors === 0;
}
validate3202.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


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
if((((((((((data.object === undefined) && (missing0 = "object")) || ((data.revision === undefined) && (missing0 = "revision"))) || ((data.namespace === undefined) && (missing0 = "namespace"))) || ((data.name === undefined) && (missing0 = "name"))) || ((data.authorization === undefined) && (missing0 = "authorization"))) || ((data.resource === undefined) && (missing0 = "resource"))) || ((data.allocating_principal === undefined) && (missing0 = "allocating_principal"))) || ((data.allocation === undefined) && (missing0 = "allocation"))) || ((data.creation === undefined) && (missing0 = "creation"))){
validate3191.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(func1.call(schema881.properties, key0))){
validate3191.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.object !== undefined){
const _errs2 = errors;
if(!(validate2429(data.object, {instancePath:instancePath+"/object",parentData:data,parentDataProperty:"object",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2429.errors : vErrors.concat(validate2429.errors);
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
if(!(validate2350(data.revision, {instancePath:instancePath+"/revision",parentData:data,parentDataProperty:"revision",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2350.errors : vErrors.concat(validate2350.errors);
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
if(!(validate2347(data.namespace, {instancePath:instancePath+"/namespace",parentData:data,parentDataProperty:"namespace",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2347.errors : vErrors.concat(validate2347.errors);
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
if(!(validate2350(data.name, {instancePath:instancePath+"/name",parentData:data,parentDataProperty:"name",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2350.errors : vErrors.concat(validate2350.errors);
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
if(!(validate2347(data.authorization, {instancePath:instancePath+"/authorization",parentData:data,parentDataProperty:"authorization",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2347.errors : vErrors.concat(validate2347.errors);
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
if(!(validate2347(data.resource, {instancePath:instancePath+"/resource",parentData:data,parentDataProperty:"resource",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2347.errors : vErrors.concat(validate2347.errors);
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
if(!(validate2347(data.allocating_principal, {instancePath:instancePath+"/allocating_principal",parentData:data,parentDataProperty:"allocating_principal",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2347.errors : vErrors.concat(validate2347.errors);
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
if(!(validate3199(data.allocation, {instancePath:instancePath+"/allocation",parentData:data,parentDataProperty:"allocation",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3199.errors : vErrors.concat(validate3199.errors);
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
if(!(validate3202(data.creation, {instancePath:instancePath+"/creation",parentData:data,parentDataProperty:"creation",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3202.errors : vErrors.concat(validate3202.errors);
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
validate3191.errors = [{}];
return false;
}
}
validate3191.errors = vErrors;
return errors === 0;
}
validate3191.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate3190(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3190.evaluated;
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
validate3190.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "definition") || (key0 === "interpretation")) || (key0 === "position"))){
validate3190.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.definition !== undefined){
const _errs2 = errors;
if(!(validate3191(data.definition, {instancePath:instancePath+"/definition",parentData:data,parentDataProperty:"definition",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3191.errors : vErrors.concat(validate3191.errors);
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
if(!(validate2428(data.interpretation, {instancePath:instancePath+"/interpretation",parentData:data,parentDataProperty:"interpretation",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2428.errors : vErrors.concat(validate2428.errors);
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
if(!(validate2415(data.position, {instancePath:instancePath+"/position",parentData:data,parentDataProperty:"position",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2415.errors : vErrors.concat(validate2415.errors);
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
validate3190.errors = [{}];
return false;
}
}
validate3190.errors = vErrors;
return errors === 0;
}
validate3190.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate3189(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3189.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate3190(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3190.errors : vErrors.concat(validate3190.errors);
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
validate3189.errors = vErrors;
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
validate3189.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate3189.evaluated = {"dynamicProps":true,"dynamicItems":false};


function validate3188(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3188.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(Array.isArray(data)){
if(data.length > 8){
validate3188.errors = [{}];
return false;
}
else {
if(data.length < 8){
validate3188.errors = [{}];
return false;
}
else {
var valid0 = true;
const len0 = data.length;
for(let i0=0; i0<len0; i0++){
const _errs1 = errors;
if(!(validate3189(data[i0], {instancePath:instancePath+"/" + i0,parentData:data,parentDataProperty:i0,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3189.errors : vErrors.concat(validate3189.errors);
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
validate3188.errors = [{}];
return false;
}
}
validate3188.errors = vErrors;
return errors === 0;
}
validate3188.evaluated = {"items":true,"dynamicProps":false,"dynamicItems":false};


function validate3187(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3187.evaluated;
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
validate3187.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "entries") || (key0 === "next")) || (key0 === "position"))){
validate3187.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.entries !== undefined){
const _errs2 = errors;
if(!(validate3188(data.entries, {instancePath:instancePath+"/entries",parentData:data,parentDataProperty:"entries",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3188.errors : vErrors.concat(validate3188.errors);
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
if(!(validate2397(data.next, {instancePath:instancePath+"/next",parentData:data,parentDataProperty:"next",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2397.errors : vErrors.concat(validate2397.errors);
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
if(!(validate2415(data.position, {instancePath:instancePath+"/position",parentData:data,parentDataProperty:"position",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2415.errors : vErrors.concat(validate2415.errors);
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
validate3187.errors = [{}];
return false;
}
}
validate3187.errors = vErrors;
return errors === 0;
}
validate3187.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema887 = {"type":"object","additionalProperties":false,"properties":{"metadata":{"$ref":"#/$defs/CatalogResponse/$defs/T258"},"preview_sql":{"$ref":"#/$defs/CatalogResponse/$defs/T11"},"expected_definition":{"$ref":"#/$defs/CatalogResponse/$defs/T11"}},"required":["metadata","preview_sql","expected_definition"]};
const schema888 = {"type":"object","additionalProperties":false,"properties":{"binding":{"$ref":"#/$defs/CatalogResponse/$defs/T259"},"authorization":{"$ref":"#/$defs/CatalogResponse/$defs/T10"},"position":{"$ref":"#/$defs/CatalogResponse/$defs/T26"},"changed_lsn":{"$ref":"#/$defs/CatalogResponse/$defs/T11"},"row_count":{"$ref":"#/$defs/CatalogResponse/$defs/T11"},"schema":{"$ref":"#/$defs/CatalogResponse/$defs/T85"}},"required":["binding","authorization","position","changed_lsn","row_count","schema"]};
const schema889 = {"type":"object","additionalProperties":false,"properties":{"definition":{"$ref":"#/$defs/CatalogResponse/$defs/T4"},"connection":{"$ref":"#/$defs/CatalogResponse/$defs/T22"},"namespace":{"$ref":"#/$defs/CatalogResponse/$defs/T10"},"name":{"$ref":"#/$defs/CatalogResponse/$defs/T11"},"interpretation":{"$ref":"#/$defs/CatalogResponse/$defs/T41"}},"required":["definition","connection","namespace","name","interpretation"]};

function validate3233(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3233.evaluated;
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
validate3233.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((((key0 === "definition") || (key0 === "connection")) || (key0 === "namespace")) || (key0 === "name")) || (key0 === "interpretation"))){
validate3233.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.definition !== undefined){
const _errs2 = errors;
if(!(validate2332(data.definition, {instancePath:instancePath+"/definition",parentData:data,parentDataProperty:"definition",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2332.errors : vErrors.concat(validate2332.errors);
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
if(!(validate2400(data.connection, {instancePath:instancePath+"/connection",parentData:data,parentDataProperty:"connection",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2400.errors : vErrors.concat(validate2400.errors);
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
if(!(validate2347(data.namespace, {instancePath:instancePath+"/namespace",parentData:data,parentDataProperty:"namespace",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2347.errors : vErrors.concat(validate2347.errors);
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
if(!(validate2350(data.name, {instancePath:instancePath+"/name",parentData:data,parentDataProperty:"name",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2350.errors : vErrors.concat(validate2350.errors);
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
if(!(validate2478(data.interpretation, {instancePath:instancePath+"/interpretation",parentData:data,parentDataProperty:"interpretation",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2478.errors : vErrors.concat(validate2478.errors);
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
validate3233.errors = [{}];
return false;
}
}
validate3233.errors = vErrors;
return errors === 0;
}
validate3233.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate3232(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3232.evaluated;
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
validate3232.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((((((key0 === "binding") || (key0 === "authorization")) || (key0 === "position")) || (key0 === "changed_lsn")) || (key0 === "row_count")) || (key0 === "schema"))){
validate3232.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.binding !== undefined){
const _errs2 = errors;
if(!(validate3233(data.binding, {instancePath:instancePath+"/binding",parentData:data,parentDataProperty:"binding",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3233.errors : vErrors.concat(validate3233.errors);
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
if(!(validate2347(data.authorization, {instancePath:instancePath+"/authorization",parentData:data,parentDataProperty:"authorization",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2347.errors : vErrors.concat(validate2347.errors);
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
if(!(validate2415(data.position, {instancePath:instancePath+"/position",parentData:data,parentDataProperty:"position",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2415.errors : vErrors.concat(validate2415.errors);
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
if(!(validate2350(data.changed_lsn, {instancePath:instancePath+"/changed_lsn",parentData:data,parentDataProperty:"changed_lsn",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2350.errors : vErrors.concat(validate2350.errors);
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
if(!(validate2350(data.row_count, {instancePath:instancePath+"/row_count",parentData:data,parentDataProperty:"row_count",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2350.errors : vErrors.concat(validate2350.errors);
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
if(!(validate2634(data.schema, {instancePath:instancePath+"/schema",parentData:data,parentDataProperty:"schema",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2634.errors : vErrors.concat(validate2634.errors);
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
validate3232.errors = [{}];
return false;
}
}
validate3232.errors = vErrors;
return errors === 0;
}
validate3232.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate3231(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3231.evaluated;
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
validate3231.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "metadata") || (key0 === "preview_sql")) || (key0 === "expected_definition"))){
validate3231.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.metadata !== undefined){
const _errs2 = errors;
if(!(validate3232(data.metadata, {instancePath:instancePath+"/metadata",parentData:data,parentDataProperty:"metadata",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3232.errors : vErrors.concat(validate3232.errors);
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
if(!(validate2350(data.preview_sql, {instancePath:instancePath+"/preview_sql",parentData:data,parentDataProperty:"preview_sql",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2350.errors : vErrors.concat(validate2350.errors);
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
if(!(validate2350(data.expected_definition, {instancePath:instancePath+"/expected_definition",parentData:data,parentDataProperty:"expected_definition",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2350.errors : vErrors.concat(validate2350.errors);
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
validate3231.errors = [{}];
return false;
}
}
validate3231.errors = vErrors;
return errors === 0;
}
validate3231.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema890 = {"type":"object","additionalProperties":false,"properties":{"binding":{"$ref":"#/$defs/CatalogResponse/$defs/T259"},"observed":{"$ref":"#/$defs/CatalogResponse/$defs/T261"}},"required":["binding","observed"]};
const schema891 = {"type":"object","additionalProperties":false,"properties":{"position":{"$ref":"#/$defs/CatalogResponse/$defs/T26"},"changed_lsn":{"$ref":"#/$defs/CatalogResponse/$defs/T11"},"live_rows":{"$ref":"#/$defs/CatalogResponse/$defs/T11"},"pending_rows":{"$ref":"#/$defs/CatalogResponse/$defs/T11"},"pending_bytes":{"$ref":"#/$defs/CatalogResponse/$defs/T11"},"pending_complete":{"$ref":"#/$defs/CatalogResponse/$defs/T17"},"oldest_pending_lsn":{"$ref":"#/$defs/CatalogResponse/$defs/T72"},"archive_through":{"$ref":"#/$defs/CatalogResponse/$defs/T11"},"recovery_through":{"$ref":"#/$defs/CatalogResponse/$defs/T72"},"history_floor":{"$ref":"#/$defs/CatalogResponse/$defs/T11"},"next_segment":{"$ref":"#/$defs/CatalogResponse/$defs/T11"},"archive_source_lsn":{"$ref":"#/$defs/CatalogResponse/$defs/T11"},"archived_source_lsn":{"$ref":"#/$defs/CatalogResponse/$defs/T11"},"archive_target_source_lsn":{"$ref":"#/$defs/CatalogResponse/$defs/T72"},"archive_target_through_lsn":{"$ref":"#/$defs/CatalogResponse/$defs/T72"},"compaction_source_lsn":{"$ref":"#/$defs/CatalogResponse/$defs/T11"},"compacted_source_lsn":{"$ref":"#/$defs/CatalogResponse/$defs/T11"},"compaction_target_source_lsn":{"$ref":"#/$defs/CatalogResponse/$defs/T72"},"compaction_target_before_segment":{"$ref":"#/$defs/CatalogResponse/$defs/T72"},"compaction_target_after_segment":{"$ref":"#/$defs/CatalogResponse/$defs/T72"}},"required":["position","changed_lsn","live_rows","pending_rows","pending_bytes","pending_complete","oldest_pending_lsn","archive_through","recovery_through","history_floor","next_segment","archive_source_lsn","archived_source_lsn","archive_target_source_lsn","archive_target_through_lsn","compaction_source_lsn","compacted_source_lsn","compaction_target_source_lsn","compaction_target_before_segment","compaction_target_after_segment"]};

function validate3251(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3251.evaluated;
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
validate3251.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(func1.call(schema891.properties, key0))){
validate3251.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.position !== undefined){
const _errs2 = errors;
if(!(validate2415(data.position, {instancePath:instancePath+"/position",parentData:data,parentDataProperty:"position",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2415.errors : vErrors.concat(validate2415.errors);
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
if(!(validate2350(data.changed_lsn, {instancePath:instancePath+"/changed_lsn",parentData:data,parentDataProperty:"changed_lsn",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2350.errors : vErrors.concat(validate2350.errors);
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
if(!(validate2350(data.live_rows, {instancePath:instancePath+"/live_rows",parentData:data,parentDataProperty:"live_rows",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2350.errors : vErrors.concat(validate2350.errors);
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
if(!(validate2350(data.pending_rows, {instancePath:instancePath+"/pending_rows",parentData:data,parentDataProperty:"pending_rows",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2350.errors : vErrors.concat(validate2350.errors);
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
if(!(validate2350(data.pending_bytes, {instancePath:instancePath+"/pending_bytes",parentData:data,parentDataProperty:"pending_bytes",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2350.errors : vErrors.concat(validate2350.errors);
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
if(!(validate2389(data.pending_complete, {instancePath:instancePath+"/pending_complete",parentData:data,parentDataProperty:"pending_complete",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2389.errors : vErrors.concat(validate2389.errors);
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
if(!(validate2579(data.oldest_pending_lsn, {instancePath:instancePath+"/oldest_pending_lsn",parentData:data,parentDataProperty:"oldest_pending_lsn",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2579.errors : vErrors.concat(validate2579.errors);
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
if(!(validate2350(data.archive_through, {instancePath:instancePath+"/archive_through",parentData:data,parentDataProperty:"archive_through",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2350.errors : vErrors.concat(validate2350.errors);
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
if(!(validate2579(data.recovery_through, {instancePath:instancePath+"/recovery_through",parentData:data,parentDataProperty:"recovery_through",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2579.errors : vErrors.concat(validate2579.errors);
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
if(!(validate2350(data.history_floor, {instancePath:instancePath+"/history_floor",parentData:data,parentDataProperty:"history_floor",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2350.errors : vErrors.concat(validate2350.errors);
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
if(!(validate2350(data.next_segment, {instancePath:instancePath+"/next_segment",parentData:data,parentDataProperty:"next_segment",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2350.errors : vErrors.concat(validate2350.errors);
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
if(!(validate2350(data.archive_source_lsn, {instancePath:instancePath+"/archive_source_lsn",parentData:data,parentDataProperty:"archive_source_lsn",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2350.errors : vErrors.concat(validate2350.errors);
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
if(!(validate2350(data.archived_source_lsn, {instancePath:instancePath+"/archived_source_lsn",parentData:data,parentDataProperty:"archived_source_lsn",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2350.errors : vErrors.concat(validate2350.errors);
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
if(!(validate2579(data.archive_target_source_lsn, {instancePath:instancePath+"/archive_target_source_lsn",parentData:data,parentDataProperty:"archive_target_source_lsn",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2579.errors : vErrors.concat(validate2579.errors);
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
if(!(validate2579(data.archive_target_through_lsn, {instancePath:instancePath+"/archive_target_through_lsn",parentData:data,parentDataProperty:"archive_target_through_lsn",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2579.errors : vErrors.concat(validate2579.errors);
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
if(!(validate2350(data.compaction_source_lsn, {instancePath:instancePath+"/compaction_source_lsn",parentData:data,parentDataProperty:"compaction_source_lsn",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2350.errors : vErrors.concat(validate2350.errors);
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
if(!(validate2350(data.compacted_source_lsn, {instancePath:instancePath+"/compacted_source_lsn",parentData:data,parentDataProperty:"compacted_source_lsn",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2350.errors : vErrors.concat(validate2350.errors);
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
if(!(validate2579(data.compaction_target_source_lsn, {instancePath:instancePath+"/compaction_target_source_lsn",parentData:data,parentDataProperty:"compaction_target_source_lsn",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2579.errors : vErrors.concat(validate2579.errors);
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
if(!(validate2579(data.compaction_target_before_segment, {instancePath:instancePath+"/compaction_target_before_segment",parentData:data,parentDataProperty:"compaction_target_before_segment",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2579.errors : vErrors.concat(validate2579.errors);
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
if(!(validate2579(data.compaction_target_after_segment, {instancePath:instancePath+"/compaction_target_after_segment",parentData:data,parentDataProperty:"compaction_target_after_segment",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2579.errors : vErrors.concat(validate2579.errors);
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
validate3251.errors = [{}];
return false;
}
}
validate3251.errors = vErrors;
return errors === 0;
}
validate3251.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate3249(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3249.evaluated;
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
validate3249.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "binding") || (key0 === "observed"))){
validate3249.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.binding !== undefined){
const _errs2 = errors;
if(!(validate3233(data.binding, {instancePath:instancePath+"/binding",parentData:data,parentDataProperty:"binding",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3233.errors : vErrors.concat(validate3233.errors);
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
if(!(validate3251(data.observed, {instancePath:instancePath+"/observed",parentData:data,parentDataProperty:"observed",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3251.errors : vErrors.concat(validate3251.errors);
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
validate3249.errors = [{}];
return false;
}
}
validate3249.errors = vErrors;
return errors === 0;
}
validate3249.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema892 = {"type":"object","additionalProperties":false,"properties":{"entries":{"$ref":"#/$defs/CatalogResponse/$defs/T263"},"next":{"$ref":"#/$defs/CatalogResponse/$defs/T270"},"position":{"$ref":"#/$defs/CatalogResponse/$defs/T26"}},"required":["entries","next","position"]};
const schema893 = {"type":"array","minItems":4,"maxItems":4,"items":{"$ref":"#/$defs/CatalogResponse/$defs/T264"}};
const schema894 = {"anyOf":[{"$ref":"#/$defs/CatalogResponse/$defs/T265"},{"type":"null"}]};
const schema895 = {"type":"object","additionalProperties":false,"properties":{"source":{"$ref":"#/$defs/CatalogResponse/$defs/T31"},"dependent":{"$ref":"#/$defs/CatalogResponse/$defs/T266"},"privileges":{"$ref":"#/$defs/CatalogResponse/$defs/T10"},"foreign_key":{"$ref":"#/$defs/CatalogResponse/$defs/T268"}},"required":["source","dependent","privileges","foreign_key"]};
const schema896 = {"type":"object","additionalProperties":false,"properties":{"kind":{"$ref":"#/$defs/CatalogResponse/$defs/T267"},"interpretation":{"$ref":"#/$defs/CatalogResponse/$defs/T31"}},"required":["kind","interpretation"]};
const schema897 = {"type":"string","enum":["kv","document","captured","maintained","stream","queue","table","view","property_graph","foreign","managed"]};

function validate3280(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3280.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate3280.errors = [{}];
return false;
}
if(!(((((((((((data === "kv") || (data === "document")) || (data === "captured")) || (data === "maintained")) || (data === "stream")) || (data === "queue")) || (data === "table")) || (data === "view")) || (data === "property_graph")) || (data === "foreign")) || (data === "managed"))){
validate3280.errors = [{}];
return false;
}
validate3280.errors = vErrors;
return errors === 0;
}
validate3280.evaluated = {"dynamicProps":false,"dynamicItems":false};


function validate3279(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3279.evaluated;
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
validate3279.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "kind") || (key0 === "interpretation"))){
validate3279.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.kind !== undefined){
const _errs2 = errors;
if(!(validate3280(data.kind, {instancePath:instancePath+"/kind",parentData:data,parentDataProperty:"kind",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3280.errors : vErrors.concat(validate3280.errors);
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
if(!(validate2428(data.interpretation, {instancePath:instancePath+"/interpretation",parentData:data,parentDataProperty:"interpretation",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2428.errors : vErrors.concat(validate2428.errors);
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
validate3279.errors = [{}];
return false;
}
}
validate3279.errors = vErrors;
return errors === 0;
}
validate3279.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema898 = {"anyOf":[{"$ref":"#/$defs/CatalogResponse/$defs/T269"},{"type":"null"}]};
const schema899 = {"type":"object","additionalProperties":false,"properties":{"constraint":{"$ref":"#/$defs/CatalogResponse/$defs/T6"},"column":{"$ref":"#/$defs/CatalogResponse/$defs/T11"}},"required":["constraint","column"]};

function validate3286(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3286.evaluated;
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
validate3286.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "constraint") || (key0 === "column"))){
validate3286.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.constraint !== undefined){
const _errs2 = errors;
if(!(validate2338(data.constraint, {instancePath:instancePath+"/constraint",parentData:data,parentDataProperty:"constraint",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2338.errors : vErrors.concat(validate2338.errors);
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
if(!(validate2350(data.column, {instancePath:instancePath+"/column",parentData:data,parentDataProperty:"column",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2350.errors : vErrors.concat(validate2350.errors);
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
validate3286.errors = [{}];
return false;
}
}
validate3286.errors = vErrors;
return errors === 0;
}
validate3286.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate3285(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3285.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate3286(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3286.errors : vErrors.concat(validate3286.errors);
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
validate3285.errors = vErrors;
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
validate3285.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate3285.evaluated = {"dynamicProps":true,"dynamicItems":false};


function validate3277(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3277.evaluated;
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
validate3277.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((((key0 === "source") || (key0 === "dependent")) || (key0 === "privileges")) || (key0 === "foreign_key"))){
validate3277.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.source !== undefined){
const _errs2 = errors;
if(!(validate2428(data.source, {instancePath:instancePath+"/source",parentData:data,parentDataProperty:"source",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2428.errors : vErrors.concat(validate2428.errors);
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
if(!(validate3279(data.dependent, {instancePath:instancePath+"/dependent",parentData:data,parentDataProperty:"dependent",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3279.errors : vErrors.concat(validate3279.errors);
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
if(!(validate2347(data.privileges, {instancePath:instancePath+"/privileges",parentData:data,parentDataProperty:"privileges",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2347.errors : vErrors.concat(validate2347.errors);
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
if(!(validate3285(data.foreign_key, {instancePath:instancePath+"/foreign_key",parentData:data,parentDataProperty:"foreign_key",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3285.errors : vErrors.concat(validate3285.errors);
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
validate3277.errors = [{}];
return false;
}
}
validate3277.errors = vErrors;
return errors === 0;
}
validate3277.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


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
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate3277(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3277.errors : vErrors.concat(validate3277.errors);
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
validate3276.errors = vErrors;
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
validate3276.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate3276.evaluated = {"dynamicProps":true,"dynamicItems":false};


function validate3275(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3275.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(Array.isArray(data)){
if(data.length > 4){
validate3275.errors = [{}];
return false;
}
else {
if(data.length < 4){
validate3275.errors = [{}];
return false;
}
else {
var valid0 = true;
const len0 = data.length;
for(let i0=0; i0<len0; i0++){
const _errs1 = errors;
if(!(validate3276(data[i0], {instancePath:instancePath+"/" + i0,parentData:data,parentDataProperty:i0,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3276.errors : vErrors.concat(validate3276.errors);
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
validate3275.errors = [{}];
return false;
}
}
validate3275.errors = vErrors;
return errors === 0;
}
validate3275.evaluated = {"items":true,"dynamicProps":false,"dynamicItems":false};

const schema900 = {"anyOf":[{"$ref":"#/$defs/CatalogResponse/$defs/T271"},{"type":"null"}]};
const schema901 = {"type":"object","additionalProperties":false,"properties":{"definition":{"$ref":"#/$defs/CatalogResponse/$defs/T4"},"connection":{"$ref":"#/$defs/CatalogResponse/$defs/T22"},"selection":{"$ref":"#/$defs/CatalogResponse/$defs/T272"},"authority":{"$ref":"#/$defs/CatalogResponse/$defs/T273"},"position":{"$ref":"#/$defs/CatalogResponse/$defs/T26"},"after":{"$ref":"#/$defs/CatalogResponse/$defs/T11"}},"required":["definition","connection","selection","authority","position","after"]};
const schema902 = {"oneOf":[{"type":"object","additionalProperties":false,"required":["dependents"],"properties":{"dependents":{"$ref":"#/$defs/CatalogResponse/$defs/T32"}}},{"type":"object","additionalProperties":false,"required":["dependencies"],"properties":{"dependencies":{"$ref":"#/$defs/CatalogResponse/$defs/T32"}}}]};

function validate3298(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3298.evaluated;
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
if(!(validate2429(data.dependents, {instancePath:instancePath+"/dependents",parentData:data,parentDataProperty:"dependents",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2429.errors : vErrors.concat(validate2429.errors);
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
if(!(validate2429(data.dependencies, {instancePath:instancePath+"/dependencies",parentData:data,parentDataProperty:"dependencies",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2429.errors : vErrors.concat(validate2429.errors);
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
validate3298.errors = vErrors;
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
validate3298.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate3298.evaluated = {"dynamicProps":true,"dynamicItems":false};


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
if(typeof data !== "string"){
validate3302.errors = [{}];
return false;
}
if(!((data === "dependent") || (data === "catalog_administrator"))){
validate3302.errors = [{}];
return false;
}
validate3302.errors = vErrors;
return errors === 0;
}
validate3302.evaluated = {"dynamicProps":false,"dynamicItems":false};


function validate3295(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3295.evaluated;
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
validate3295.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((((((key0 === "definition") || (key0 === "connection")) || (key0 === "selection")) || (key0 === "authority")) || (key0 === "position")) || (key0 === "after"))){
validate3295.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.definition !== undefined){
const _errs2 = errors;
if(!(validate2332(data.definition, {instancePath:instancePath+"/definition",parentData:data,parentDataProperty:"definition",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2332.errors : vErrors.concat(validate2332.errors);
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
if(!(validate2400(data.connection, {instancePath:instancePath+"/connection",parentData:data,parentDataProperty:"connection",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2400.errors : vErrors.concat(validate2400.errors);
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
if(!(validate3298(data.selection, {instancePath:instancePath+"/selection",parentData:data,parentDataProperty:"selection",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3298.errors : vErrors.concat(validate3298.errors);
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
if(!(validate3302(data.authority, {instancePath:instancePath+"/authority",parentData:data,parentDataProperty:"authority",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3302.errors : vErrors.concat(validate3302.errors);
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
if(!(validate2415(data.position, {instancePath:instancePath+"/position",parentData:data,parentDataProperty:"position",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2415.errors : vErrors.concat(validate2415.errors);
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
if(!(validate2350(data.after, {instancePath:instancePath+"/after",parentData:data,parentDataProperty:"after",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2350.errors : vErrors.concat(validate2350.errors);
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
validate3295.errors = [{}];
return false;
}
}
validate3295.errors = vErrors;
return errors === 0;
}
validate3295.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate3294(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate3294.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate3295(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3295.errors : vErrors.concat(validate3295.errors);
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
validate3294.errors = vErrors;
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
validate3294.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate3294.evaluated = {"dynamicProps":true,"dynamicItems":false};


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
if((((data.entries === undefined) && (missing0 = "entries")) || ((data.next === undefined) && (missing0 = "next"))) || ((data.position === undefined) && (missing0 = "position"))){
validate3274.errors = [{}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "entries") || (key0 === "next")) || (key0 === "position"))){
validate3274.errors = [{}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.entries !== undefined){
const _errs2 = errors;
if(!(validate3275(data.entries, {instancePath:instancePath+"/entries",parentData:data,parentDataProperty:"entries",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3275.errors : vErrors.concat(validate3275.errors);
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
if(!(validate3294(data.next, {instancePath:instancePath+"/next",parentData:data,parentDataProperty:"next",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3294.errors : vErrors.concat(validate3294.errors);
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
if(!(validate2415(data.position, {instancePath:instancePath+"/position",parentData:data,parentDataProperty:"position",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2415.errors : vErrors.concat(validate2415.errors);
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
validate3274.errors = [{}];
return false;
}
}
validate3274.errors = vErrors;
return errors === 0;
}
validate3274.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate2327(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2327.evaluated;
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
if(!(validate2328(data.catalog, {instancePath:instancePath+"/catalog",parentData:data,parentDataProperty:"catalog",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2328.errors : vErrors.concat(validate2328.errors);
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
if(!(validate2450(data.history, {instancePath:instancePath+"/history",parentData:data,parentDataProperty:"history",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2450.errors : vErrors.concat(validate2450.errors);
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
if(!(validate3026(data.definitions, {instancePath:instancePath+"/definitions",parentData:data,parentDataProperty:"definitions",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3026.errors : vErrors.concat(validate3026.errors);
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
if(!(validate3187(data.resources, {instancePath:instancePath+"/resources",parentData:data,parentDataProperty:"resources",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3187.errors : vErrors.concat(validate3187.errors);
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
if(!(validate3231(data.table, {instancePath:instancePath+"/table",parentData:data,parentDataProperty:"table",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3231.errors : vErrors.concat(validate3231.errors);
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
if(!(validate3249(data.storage, {instancePath:instancePath+"/storage",parentData:data,parentDataProperty:"storage",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3249.errors : vErrors.concat(validate3249.errors);
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
if(!(validate3274(data.dependencies, {instancePath:instancePath+"/dependencies",parentData:data,parentDataProperty:"dependencies",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate3274.errors : vErrors.concat(validate3274.errors);
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
validate2327.errors = vErrors;
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
validate2327.errors = vErrors;
evaluated0.props = props1;
return errors === 0;
}
validate2327.evaluated = {"dynamicProps":true,"dynamicItems":false};
