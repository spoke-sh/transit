// Generated; no runtime code generation or eval.
import lengthModule from "ajv/dist/runtime/ucs2length.js";
const ucs2length = lengthModule.default ?? lengthModule;
"use strict";
export const RelationalRequest = validate1442;
const schema376 = {"oneOf":[{"type":"object","additionalProperties":false,"required":["describe"],"properties":{"describe":{"$ref":"#/$defs/RelationalRequest/$defs/T1"}}},{"type":"object","additionalProperties":false,"required":["storage"],"properties":{"storage":{"$ref":"#/$defs/RelationalRequest/$defs/T2"}}},{"type":"object","additionalProperties":false,"required":["query"],"properties":{"query":{"$ref":"#/$defs/RelationalRequest/$defs/T16"}}},{"type":"object","additionalProperties":false,"required":["recover"],"properties":{"recover":{"$ref":"#/$defs/RelationalRequest/$defs/T38"}}}]};
const schema377 = {"type":"object","maxProperties":0};

function validate1443(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1443.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
if(Object.keys(data).length > 0){
validate1443.errors = [{instancePath,schemaPath:"#/maxProperties",keyword:"maxProperties",params:{limit: 0}}];
return false;
}
}
else {
validate1443.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
return false;
}
}
validate1443.errors = vErrors;
return errors === 0;
}
validate1443.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema378 = {"type":"object","additionalProperties":false,"properties":{"route":{"$ref":"#/$defs/RelationalRequest/$defs/T3"},"binding":{"$ref":"#/$defs/RelationalRequest/$defs/T4"}},"required":["route","binding"]};
const schema26 = {"type":"integer","minimum":0,"maximum":65535};

function validate1446(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1446.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(!(((typeof data == "number") && (!(data % 1) && !isNaN(data))) && (isFinite(data)))){
validate1446.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "integer"}}];
return false;
}
if(errors === 0){
if((typeof data == "number") && (isFinite(data))){
if(data > 65535 || isNaN(data)){
validate1446.errors = [{instancePath,schemaPath:"#/maximum",keyword:"maximum",params:{comparison: "<=", limit: 65535}}];
return false;
}
else {
if(data < 0 || isNaN(data)){
validate1446.errors = [{instancePath,schemaPath:"#/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0}}];
return false;
}
}
}
}
validate1446.errors = vErrors;
return errors === 0;
}
validate1446.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema380 = {"type":"object","additionalProperties":false,"properties":{"definition":{"$ref":"#/$defs/RelationalRequest/$defs/T5"},"connection":{"$ref":"#/$defs/RelationalRequest/$defs/T6"},"namespace":{"$ref":"#/$defs/RelationalRequest/$defs/T8"},"name":{"$ref":"#/$defs/RelationalRequest/$defs/T9"},"interpretation":{"$ref":"#/$defs/RelationalRequest/$defs/T11"}},"required":["definition","connection","namespace","name","interpretation"]};
const schema55 = {"type":"string","enum":["fe0da791b6421a288d3f53bedbfd1804cf5583c2c08e1d121c8120125daeb9f6"]};

function validate1449(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1449.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate1449.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"}}];
return false;
}
if(!(data === "fe0da791b6421a288d3f53bedbfd1804cf5583c2c08e1d121c8120125daeb9f6")){
validate1449.errors = [{instancePath,schemaPath:"#/enum",keyword:"enum",params:{allowedValues: schema55.enum}}];
return false;
}
validate1449.errors = vErrors;
return errors === 0;
}
validate1449.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema382 = {"type":"object","additionalProperties":false,"properties":{"scope":{"$ref":"#/$defs/RelationalRequest/$defs/T7"},"branch":{"$ref":"#/$defs/RelationalRequest/$defs/T9"},"audience":{"$ref":"#/$defs/RelationalRequest/$defs/T8"},"principal":{"$ref":"#/$defs/RelationalRequest/$defs/T8"},"role":{"$ref":"#/$defs/RelationalRequest/$defs/T10"}},"required":["scope","branch","audience","principal","role"]};
const schema383 = {"type":"object","additionalProperties":false,"properties":{"realm":{"$ref":"#/$defs/RelationalRequest/$defs/T8"},"resource":{"$ref":"#/$defs/RelationalRequest/$defs/T8"},"catalog":{"$ref":"#/$defs/RelationalRequest/$defs/T9"}},"required":["realm","resource","catalog"]};
const schema22 = {"type":"integer","minimum":0,"maximum":9007199254740991};

function validate1453(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1453.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(!(((typeof data == "number") && (!(data % 1) && !isNaN(data))) && (isFinite(data)))){
validate1453.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "integer"}}];
return false;
}
if(errors === 0){
if((typeof data == "number") && (isFinite(data))){
if(data > 9007199254740991 || isNaN(data)){
validate1453.errors = [{instancePath,schemaPath:"#/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991}}];
return false;
}
else {
if(data < 0 || isNaN(data)){
validate1453.errors = [{instancePath,schemaPath:"#/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0}}];
return false;
}
}
}
}
validate1453.errors = vErrors;
return errors === 0;
}
validate1453.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema385 = {"type":"string","maxLength":4096};
const func4 = ucs2length;

function validate1456(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1456.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(typeof data === "string"){
if(func4(data) > 4096){
validate1456.errors = [{instancePath,schemaPath:"#/maxLength",keyword:"maxLength",params:{limit: 4096}}];
return false;
}
}
else {
validate1456.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"}}];
return false;
}
}
validate1456.errors = vErrors;
return errors === 0;
}
validate1456.evaluated = {"dynamicProps":false,"dynamicItems":false};


function validate1452(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1452.evaluated;
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
validate1452.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "realm") || (key0 === "resource")) || (key0 === "catalog"))){
validate1452.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.realm !== undefined){
const _errs2 = errors;
if(!(validate1453(data.realm, {instancePath:instancePath+"/realm",parentData:data,parentDataProperty:"realm",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1453.errors : vErrors.concat(validate1453.errors);
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
if(!(validate1453(data.resource, {instancePath:instancePath+"/resource",parentData:data,parentDataProperty:"resource",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1453.errors : vErrors.concat(validate1453.errors);
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
if(!(validate1456(data.catalog, {instancePath:instancePath+"/catalog",parentData:data,parentDataProperty:"catalog",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1456.errors : vErrors.concat(validate1456.errors);
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
validate1452.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
return false;
}
}
validate1452.errors = vErrors;
return errors === 0;
}
validate1452.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema386 = {"anyOf":[{"$ref":"#/$defs/RelationalRequest/$defs/T8"},{"type":"null"}]};

function validate1462(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1462.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate1453(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1453.errors : vErrors.concat(validate1453.errors);
errors = vErrors.length;
}
var _valid0 = _errs1 === errors;
valid0 = valid0 || _valid0;
const _errs2 = errors;
if(data !== null){
const err0 = {instancePath,schemaPath:"#/anyOf/1/type",keyword:"type",params:{type: "null"}};
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
const err1 = {instancePath,schemaPath:"#/anyOf",keyword:"anyOf",params:{}};
if(vErrors === null){
vErrors = [err1];
}
else {
vErrors.push(err1);
}
errors++;
validate1462.errors = vErrors;
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
validate1462.errors = vErrors;
return errors === 0;
}
validate1462.evaluated = {"dynamicProps":false,"dynamicItems":false};


function validate1451(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1451.evaluated;
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
validate1451.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((((key0 === "scope") || (key0 === "branch")) || (key0 === "audience")) || (key0 === "principal")) || (key0 === "role"))){
validate1451.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.scope !== undefined){
const _errs2 = errors;
if(!(validate1452(data.scope, {instancePath:instancePath+"/scope",parentData:data,parentDataProperty:"scope",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1452.errors : vErrors.concat(validate1452.errors);
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
if(!(validate1456(data.branch, {instancePath:instancePath+"/branch",parentData:data,parentDataProperty:"branch",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1456.errors : vErrors.concat(validate1456.errors);
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
if(!(validate1453(data.audience, {instancePath:instancePath+"/audience",parentData:data,parentDataProperty:"audience",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1453.errors : vErrors.concat(validate1453.errors);
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
if(!(validate1453(data.principal, {instancePath:instancePath+"/principal",parentData:data,parentDataProperty:"principal",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1453.errors : vErrors.concat(validate1453.errors);
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
if(!(validate1462(data.role, {instancePath:instancePath+"/role",parentData:data,parentDataProperty:"role",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1462.errors : vErrors.concat(validate1462.errors);
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
validate1451.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
return false;
}
}
validate1451.errors = vErrors;
return errors === 0;
}
validate1451.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema387 = {"type":"object","additionalProperties":false,"properties":{"interpretation":{"$ref":"#/$defs/RelationalRequest/$defs/T12"},"content":{"$ref":"#/$defs/RelationalRequest/$defs/T14"},"schema_fingerprint":{"$ref":"#/$defs/RelationalRequest/$defs/T9"},"retired":{"$ref":"#/$defs/RelationalRequest/$defs/T15"}},"required":["interpretation","content","schema_fingerprint","retired"]};
const schema388 = {"type":"object","additionalProperties":false,"properties":{"object":{"$ref":"#/$defs/RelationalRequest/$defs/T13"},"revision":{"$ref":"#/$defs/RelationalRequest/$defs/T9"},"digest":{"$ref":"#/$defs/RelationalRequest/$defs/T9"}},"required":["object","revision","digest"]};
const schema389 = {"type":"object","additionalProperties":false,"properties":{"scope":{"$ref":"#/$defs/RelationalRequest/$defs/T7"},"branch":{"$ref":"#/$defs/RelationalRequest/$defs/T9"},"object":{"$ref":"#/$defs/RelationalRequest/$defs/T9"}},"required":["scope","branch","object"]};

function validate1470(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1470.evaluated;
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
validate1470.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "scope") || (key0 === "branch")) || (key0 === "object"))){
validate1470.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.scope !== undefined){
const _errs2 = errors;
if(!(validate1452(data.scope, {instancePath:instancePath+"/scope",parentData:data,parentDataProperty:"scope",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1452.errors : vErrors.concat(validate1452.errors);
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
if(!(validate1456(data.branch, {instancePath:instancePath+"/branch",parentData:data,parentDataProperty:"branch",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1456.errors : vErrors.concat(validate1456.errors);
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
if(!(validate1456(data.object, {instancePath:instancePath+"/object",parentData:data,parentDataProperty:"object",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1456.errors : vErrors.concat(validate1456.errors);
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
validate1470.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
return false;
}
}
validate1470.errors = vErrors;
return errors === 0;
}
validate1470.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate1469(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1469.evaluated;
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
validate1469.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "object") || (key0 === "revision")) || (key0 === "digest"))){
validate1469.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.object !== undefined){
const _errs2 = errors;
if(!(validate1470(data.object, {instancePath:instancePath+"/object",parentData:data,parentDataProperty:"object",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1470.errors : vErrors.concat(validate1470.errors);
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
if(!(validate1456(data.revision, {instancePath:instancePath+"/revision",parentData:data,parentDataProperty:"revision",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1456.errors : vErrors.concat(validate1456.errors);
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
if(!(validate1456(data.digest, {instancePath:instancePath+"/digest",parentData:data,parentDataProperty:"digest",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1456.errors : vErrors.concat(validate1456.errors);
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
validate1469.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
return false;
}
}
validate1469.errors = vErrors;
return errors === 0;
}
validate1469.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema390 = {"type":"object","additionalProperties":false,"properties":{"bytes":{"$ref":"#/$defs/RelationalRequest/$defs/T9"},"sha256":{"$ref":"#/$defs/RelationalRequest/$defs/T9"}},"required":["bytes","sha256"]};

function validate1478(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1478.evaluated;
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
validate1478.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "bytes") || (key0 === "sha256"))){
validate1478.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.bytes !== undefined){
const _errs2 = errors;
if(!(validate1456(data.bytes, {instancePath:instancePath+"/bytes",parentData:data,parentDataProperty:"bytes",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1456.errors : vErrors.concat(validate1456.errors);
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
if(!(validate1456(data.sha256, {instancePath:instancePath+"/sha256",parentData:data,parentDataProperty:"sha256",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1456.errors : vErrors.concat(validate1456.errors);
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
validate1478.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
return false;
}
}
validate1478.errors = vErrors;
return errors === 0;
}
validate1478.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema391 = {"type":"boolean"};

function validate1483(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1483.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "boolean"){
validate1483.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "boolean"}}];
return false;
}
validate1483.errors = vErrors;
return errors === 0;
}
validate1483.evaluated = {"dynamicProps":false,"dynamicItems":false};


function validate1468(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1468.evaluated;
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
validate1468.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((((key0 === "interpretation") || (key0 === "content")) || (key0 === "schema_fingerprint")) || (key0 === "retired"))){
validate1468.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.interpretation !== undefined){
const _errs2 = errors;
if(!(validate1469(data.interpretation, {instancePath:instancePath+"/interpretation",parentData:data,parentDataProperty:"interpretation",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1469.errors : vErrors.concat(validate1469.errors);
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
if(!(validate1478(data.content, {instancePath:instancePath+"/content",parentData:data,parentDataProperty:"content",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1478.errors : vErrors.concat(validate1478.errors);
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
if(!(validate1456(data.schema_fingerprint, {instancePath:instancePath+"/schema_fingerprint",parentData:data,parentDataProperty:"schema_fingerprint",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1456.errors : vErrors.concat(validate1456.errors);
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
if(!(validate1483(data.retired, {instancePath:instancePath+"/retired",parentData:data,parentDataProperty:"retired",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1483.errors : vErrors.concat(validate1483.errors);
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
validate1468.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
return false;
}
}
validate1468.errors = vErrors;
return errors === 0;
}
validate1468.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate1448(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1448.evaluated;
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
validate1448.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((((key0 === "definition") || (key0 === "connection")) || (key0 === "namespace")) || (key0 === "name")) || (key0 === "interpretation"))){
validate1448.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.definition !== undefined){
const _errs2 = errors;
if(!(validate1449(data.definition, {instancePath:instancePath+"/definition",parentData:data,parentDataProperty:"definition",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1449.errors : vErrors.concat(validate1449.errors);
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
if(!(validate1451(data.connection, {instancePath:instancePath+"/connection",parentData:data,parentDataProperty:"connection",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1451.errors : vErrors.concat(validate1451.errors);
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
if(!(validate1453(data.namespace, {instancePath:instancePath+"/namespace",parentData:data,parentDataProperty:"namespace",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1453.errors : vErrors.concat(validate1453.errors);
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
if(!(validate1456(data.name, {instancePath:instancePath+"/name",parentData:data,parentDataProperty:"name",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1456.errors : vErrors.concat(validate1456.errors);
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
if(!(validate1468(data.interpretation, {instancePath:instancePath+"/interpretation",parentData:data,parentDataProperty:"interpretation",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1468.errors : vErrors.concat(validate1468.errors);
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
validate1448.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
return false;
}
}
validate1448.errors = vErrors;
return errors === 0;
}
validate1448.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate1445(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1445.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if(((data.route === undefined) && (missing0 = "route")) || ((data.binding === undefined) && (missing0 = "binding"))){
validate1445.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "route") || (key0 === "binding"))){
validate1445.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.route !== undefined){
const _errs2 = errors;
if(!(validate1446(data.route, {instancePath:instancePath+"/route",parentData:data,parentDataProperty:"route",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1446.errors : vErrors.concat(validate1446.errors);
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
if(!(validate1448(data.binding, {instancePath:instancePath+"/binding",parentData:data,parentDataProperty:"binding",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1448.errors : vErrors.concat(validate1448.errors);
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
validate1445.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
return false;
}
}
validate1445.errors = vErrors;
return errors === 0;
}
validate1445.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema392 = {"oneOf":[{"type":"object","additionalProperties":false,"required":["capabilities"],"properties":{"capabilities":{"$ref":"#/$defs/RelationalRequest/$defs/T1"}}},{"type":"object","additionalProperties":false,"required":["explain"],"properties":{"explain":{"$ref":"#/$defs/RelationalRequest/$defs/T17"}}},{"type":"object","additionalProperties":false,"required":["open"],"properties":{"open":{"$ref":"#/$defs/RelationalRequest/$defs/T20"}}},{"type":"object","additionalProperties":false,"required":["page"],"properties":{"page":{"$ref":"#/$defs/RelationalRequest/$defs/T36"}}},{"type":"object","additionalProperties":false,"required":["close"],"properties":{"close":{"$ref":"#/$defs/RelationalRequest/$defs/T37"}}}]};
const schema393 = {"type":"object","additionalProperties":false,"properties":{"namespace":{"$ref":"#/$defs/RelationalRequest/$defs/T8"},"sql":{"$ref":"#/$defs/RelationalRequest/$defs/T9"},"routes":{"$ref":"#/$defs/RelationalRequest/$defs/T18"}},"required":["sql","routes"]};
const schema394 = {"type":"array","maxItems":2,"items":{"$ref":"#/$defs/RelationalRequest/$defs/T19"}};

function validate1494(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1494.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(!(((typeof data == "number") && (!(data % 1) && !isNaN(data))) && (isFinite(data)))){
validate1494.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "integer"}}];
return false;
}
if(errors === 0){
if((typeof data == "number") && (isFinite(data))){
if(data > 65535 || isNaN(data)){
validate1494.errors = [{instancePath,schemaPath:"#/maximum",keyword:"maximum",params:{comparison: "<=", limit: 65535}}];
return false;
}
else {
if(data < 0 || isNaN(data)){
validate1494.errors = [{instancePath,schemaPath:"#/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0}}];
return false;
}
}
}
}
validate1494.errors = vErrors;
return errors === 0;
}
validate1494.evaluated = {"dynamicProps":false,"dynamicItems":false};


function validate1493(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1493.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(Array.isArray(data)){
if(data.length > 2){
validate1493.errors = [{instancePath,schemaPath:"#/maxItems",keyword:"maxItems",params:{limit: 2}}];
return false;
}
else {
var valid0 = true;
const len0 = data.length;
for(let i0=0; i0<len0; i0++){
const _errs1 = errors;
if(!(validate1494(data[i0], {instancePath:instancePath+"/" + i0,parentData:data,parentDataProperty:i0,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1494.errors : vErrors.concat(validate1494.errors);
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
validate1493.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "array"}}];
return false;
}
}
validate1493.errors = vErrors;
return errors === 0;
}
validate1493.evaluated = {"items":true,"dynamicProps":false,"dynamicItems":false};


function validate1490(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1490.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if(((data.sql === undefined) && (missing0 = "sql")) || ((data.routes === undefined) && (missing0 = "routes"))){
validate1490.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "namespace") || (key0 === "sql")) || (key0 === "routes"))){
validate1490.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.namespace !== undefined){
const _errs2 = errors;
if(!(validate1453(data.namespace, {instancePath:instancePath+"/namespace",parentData:data,parentDataProperty:"namespace",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1453.errors : vErrors.concat(validate1453.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.sql !== undefined){
const _errs3 = errors;
if(!(validate1456(data.sql, {instancePath:instancePath+"/sql",parentData:data,parentDataProperty:"sql",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1456.errors : vErrors.concat(validate1456.errors);
errors = vErrors.length;
}
var valid0 = _errs3 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.routes !== undefined){
const _errs4 = errors;
if(!(validate1493(data.routes, {instancePath:instancePath+"/routes",parentData:data,parentDataProperty:"routes",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1493.errors : vErrors.concat(validate1493.errors);
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
validate1490.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
return false;
}
}
validate1490.errors = vErrors;
return errors === 0;
}
validate1490.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema396 = {"type":"object","additionalProperties":false,"properties":{"id":{"$ref":"#/$defs/RelationalRequest/$defs/T9"},"statement":{"$ref":"#/$defs/RelationalRequest/$defs/T17"},"sources":{"$ref":"#/$defs/RelationalRequest/$defs/T21"}},"required":["id","statement","sources"]};
const schema397 = {"type":"array","maxItems":2,"items":{"$ref":"#/$defs/RelationalRequest/$defs/T22"}};
const schema398 = {"type":"object","additionalProperties":false,"properties":{"alias":{"$ref":"#/$defs/RelationalRequest/$defs/T23"},"binding":{"$ref":"#/$defs/RelationalRequest/$defs/T24"},"position":{"$ref":"#/$defs/RelationalRequest/$defs/T35"}},"required":["alias","binding","position"]};
const schema399 = {"type":"string","maxLength":4096};

function validate1503(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1503.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(typeof data === "string"){
if(func4(data) > 4096){
validate1503.errors = [{instancePath,schemaPath:"#/maxLength",keyword:"maxLength",params:{limit: 4096}}];
return false;
}
}
else {
validate1503.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"}}];
return false;
}
}
validate1503.errors = vErrors;
return errors === 0;
}
validate1503.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema400 = {"type":"object","additionalProperties":false,"properties":{"definition":{"$ref":"#/$defs/RelationalRequest/$defs/T25"},"connection":{"$ref":"#/$defs/RelationalRequest/$defs/T26"},"namespace":{"$ref":"#/$defs/RelationalRequest/$defs/T28"},"name":{"$ref":"#/$defs/RelationalRequest/$defs/T23"},"interpretation":{"$ref":"#/$defs/RelationalRequest/$defs/T30"}},"required":["definition","connection","namespace","name","interpretation"]};

function validate1506(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1506.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate1506.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"}}];
return false;
}
if(!(data === "fe0da791b6421a288d3f53bedbfd1804cf5583c2c08e1d121c8120125daeb9f6")){
validate1506.errors = [{instancePath,schemaPath:"#/enum",keyword:"enum",params:{allowedValues: schema55.enum}}];
return false;
}
validate1506.errors = vErrors;
return errors === 0;
}
validate1506.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema402 = {"type":"object","additionalProperties":false,"properties":{"scope":{"$ref":"#/$defs/RelationalRequest/$defs/T27"},"branch":{"$ref":"#/$defs/RelationalRequest/$defs/T23"},"audience":{"$ref":"#/$defs/RelationalRequest/$defs/T28"},"principal":{"$ref":"#/$defs/RelationalRequest/$defs/T28"},"role":{"$ref":"#/$defs/RelationalRequest/$defs/T29"}},"required":["scope","branch","audience","principal","role"]};
const schema403 = {"type":"object","additionalProperties":false,"properties":{"realm":{"$ref":"#/$defs/RelationalRequest/$defs/T28"},"resource":{"$ref":"#/$defs/RelationalRequest/$defs/T28"},"catalog":{"$ref":"#/$defs/RelationalRequest/$defs/T23"}},"required":["realm","resource","catalog"]};

function validate1510(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1510.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(!(((typeof data == "number") && (!(data % 1) && !isNaN(data))) && (isFinite(data)))){
validate1510.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "integer"}}];
return false;
}
if(errors === 0){
if((typeof data == "number") && (isFinite(data))){
if(data > 9007199254740991 || isNaN(data)){
validate1510.errors = [{instancePath,schemaPath:"#/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991}}];
return false;
}
else {
if(data < 0 || isNaN(data)){
validate1510.errors = [{instancePath,schemaPath:"#/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0}}];
return false;
}
}
}
}
validate1510.errors = vErrors;
return errors === 0;
}
validate1510.evaluated = {"dynamicProps":false,"dynamicItems":false};


function validate1509(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1509.evaluated;
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
validate1509.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "realm") || (key0 === "resource")) || (key0 === "catalog"))){
validate1509.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.realm !== undefined){
const _errs2 = errors;
if(!(validate1510(data.realm, {instancePath:instancePath+"/realm",parentData:data,parentDataProperty:"realm",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1510.errors : vErrors.concat(validate1510.errors);
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
if(!(validate1510(data.resource, {instancePath:instancePath+"/resource",parentData:data,parentDataProperty:"resource",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1510.errors : vErrors.concat(validate1510.errors);
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
if(!(validate1503(data.catalog, {instancePath:instancePath+"/catalog",parentData:data,parentDataProperty:"catalog",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1503.errors : vErrors.concat(validate1503.errors);
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
validate1509.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
return false;
}
}
validate1509.errors = vErrors;
return errors === 0;
}
validate1509.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema405 = {"anyOf":[{"$ref":"#/$defs/RelationalRequest/$defs/T28"},{"type":"null"}]};

function validate1518(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1518.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate1510(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1510.errors : vErrors.concat(validate1510.errors);
errors = vErrors.length;
}
var _valid0 = _errs1 === errors;
valid0 = valid0 || _valid0;
const _errs2 = errors;
if(data !== null){
const err0 = {instancePath,schemaPath:"#/anyOf/1/type",keyword:"type",params:{type: "null"}};
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
const err1 = {instancePath,schemaPath:"#/anyOf",keyword:"anyOf",params:{}};
if(vErrors === null){
vErrors = [err1];
}
else {
vErrors.push(err1);
}
errors++;
validate1518.errors = vErrors;
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
validate1518.errors = vErrors;
return errors === 0;
}
validate1518.evaluated = {"dynamicProps":false,"dynamicItems":false};


function validate1508(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1508.evaluated;
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
validate1508.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((((key0 === "scope") || (key0 === "branch")) || (key0 === "audience")) || (key0 === "principal")) || (key0 === "role"))){
validate1508.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.scope !== undefined){
const _errs2 = errors;
if(!(validate1509(data.scope, {instancePath:instancePath+"/scope",parentData:data,parentDataProperty:"scope",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1509.errors : vErrors.concat(validate1509.errors);
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
if(!(validate1503(data.branch, {instancePath:instancePath+"/branch",parentData:data,parentDataProperty:"branch",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1503.errors : vErrors.concat(validate1503.errors);
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
if(!(validate1510(data.audience, {instancePath:instancePath+"/audience",parentData:data,parentDataProperty:"audience",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1510.errors : vErrors.concat(validate1510.errors);
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
if(!(validate1510(data.principal, {instancePath:instancePath+"/principal",parentData:data,parentDataProperty:"principal",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1510.errors : vErrors.concat(validate1510.errors);
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
if(!(validate1518(data.role, {instancePath:instancePath+"/role",parentData:data,parentDataProperty:"role",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1518.errors : vErrors.concat(validate1518.errors);
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
validate1508.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
return false;
}
}
validate1508.errors = vErrors;
return errors === 0;
}
validate1508.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema406 = {"type":"object","additionalProperties":false,"properties":{"interpretation":{"$ref":"#/$defs/RelationalRequest/$defs/T31"},"content":{"$ref":"#/$defs/RelationalRequest/$defs/T33"},"schema_fingerprint":{"$ref":"#/$defs/RelationalRequest/$defs/T23"},"retired":{"$ref":"#/$defs/RelationalRequest/$defs/T34"}},"required":["interpretation","content","schema_fingerprint","retired"]};
const schema407 = {"type":"object","additionalProperties":false,"properties":{"object":{"$ref":"#/$defs/RelationalRequest/$defs/T32"},"revision":{"$ref":"#/$defs/RelationalRequest/$defs/T23"},"digest":{"$ref":"#/$defs/RelationalRequest/$defs/T23"}},"required":["object","revision","digest"]};
const schema408 = {"type":"object","additionalProperties":false,"properties":{"scope":{"$ref":"#/$defs/RelationalRequest/$defs/T27"},"branch":{"$ref":"#/$defs/RelationalRequest/$defs/T23"},"object":{"$ref":"#/$defs/RelationalRequest/$defs/T23"}},"required":["scope","branch","object"]};

function validate1526(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1526.evaluated;
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
validate1526.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "scope") || (key0 === "branch")) || (key0 === "object"))){
validate1526.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.scope !== undefined){
const _errs2 = errors;
if(!(validate1509(data.scope, {instancePath:instancePath+"/scope",parentData:data,parentDataProperty:"scope",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1509.errors : vErrors.concat(validate1509.errors);
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
if(!(validate1503(data.branch, {instancePath:instancePath+"/branch",parentData:data,parentDataProperty:"branch",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1503.errors : vErrors.concat(validate1503.errors);
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
if(!(validate1503(data.object, {instancePath:instancePath+"/object",parentData:data,parentDataProperty:"object",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1503.errors : vErrors.concat(validate1503.errors);
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
validate1526.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
return false;
}
}
validate1526.errors = vErrors;
return errors === 0;
}
validate1526.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate1525(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1525.evaluated;
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
validate1525.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "object") || (key0 === "revision")) || (key0 === "digest"))){
validate1525.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.object !== undefined){
const _errs2 = errors;
if(!(validate1526(data.object, {instancePath:instancePath+"/object",parentData:data,parentDataProperty:"object",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1526.errors : vErrors.concat(validate1526.errors);
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
if(!(validate1503(data.revision, {instancePath:instancePath+"/revision",parentData:data,parentDataProperty:"revision",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1503.errors : vErrors.concat(validate1503.errors);
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
if(!(validate1503(data.digest, {instancePath:instancePath+"/digest",parentData:data,parentDataProperty:"digest",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1503.errors : vErrors.concat(validate1503.errors);
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
validate1525.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
return false;
}
}
validate1525.errors = vErrors;
return errors === 0;
}
validate1525.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema409 = {"type":"object","additionalProperties":false,"properties":{"bytes":{"$ref":"#/$defs/RelationalRequest/$defs/T23"},"sha256":{"$ref":"#/$defs/RelationalRequest/$defs/T23"}},"required":["bytes","sha256"]};

function validate1534(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1534.evaluated;
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
validate1534.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "bytes") || (key0 === "sha256"))){
validate1534.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.bytes !== undefined){
const _errs2 = errors;
if(!(validate1503(data.bytes, {instancePath:instancePath+"/bytes",parentData:data,parentDataProperty:"bytes",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1503.errors : vErrors.concat(validate1503.errors);
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
if(!(validate1503(data.sha256, {instancePath:instancePath+"/sha256",parentData:data,parentDataProperty:"sha256",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1503.errors : vErrors.concat(validate1503.errors);
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
validate1534.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
return false;
}
}
validate1534.errors = vErrors;
return errors === 0;
}
validate1534.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema410 = {"type":"boolean"};

function validate1539(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1539.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "boolean"){
validate1539.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "boolean"}}];
return false;
}
validate1539.errors = vErrors;
return errors === 0;
}
validate1539.evaluated = {"dynamicProps":false,"dynamicItems":false};


function validate1524(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1524.evaluated;
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
validate1524.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((((key0 === "interpretation") || (key0 === "content")) || (key0 === "schema_fingerprint")) || (key0 === "retired"))){
validate1524.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.interpretation !== undefined){
const _errs2 = errors;
if(!(validate1525(data.interpretation, {instancePath:instancePath+"/interpretation",parentData:data,parentDataProperty:"interpretation",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1525.errors : vErrors.concat(validate1525.errors);
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
if(!(validate1534(data.content, {instancePath:instancePath+"/content",parentData:data,parentDataProperty:"content",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1534.errors : vErrors.concat(validate1534.errors);
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
if(!(validate1503(data.schema_fingerprint, {instancePath:instancePath+"/schema_fingerprint",parentData:data,parentDataProperty:"schema_fingerprint",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1503.errors : vErrors.concat(validate1503.errors);
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
if(!(validate1539(data.retired, {instancePath:instancePath+"/retired",parentData:data,parentDataProperty:"retired",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1539.errors : vErrors.concat(validate1539.errors);
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
validate1524.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
return false;
}
}
validate1524.errors = vErrors;
return errors === 0;
}
validate1524.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate1505(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1505.evaluated;
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
validate1505.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((((key0 === "definition") || (key0 === "connection")) || (key0 === "namespace")) || (key0 === "name")) || (key0 === "interpretation"))){
validate1505.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.definition !== undefined){
const _errs2 = errors;
if(!(validate1506(data.definition, {instancePath:instancePath+"/definition",parentData:data,parentDataProperty:"definition",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1506.errors : vErrors.concat(validate1506.errors);
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
if(!(validate1508(data.connection, {instancePath:instancePath+"/connection",parentData:data,parentDataProperty:"connection",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1508.errors : vErrors.concat(validate1508.errors);
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
if(!(validate1510(data.namespace, {instancePath:instancePath+"/namespace",parentData:data,parentDataProperty:"namespace",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1510.errors : vErrors.concat(validate1510.errors);
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
if(!(validate1503(data.name, {instancePath:instancePath+"/name",parentData:data,parentDataProperty:"name",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1503.errors : vErrors.concat(validate1503.errors);
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
if(!(validate1524(data.interpretation, {instancePath:instancePath+"/interpretation",parentData:data,parentDataProperty:"interpretation",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1524.errors : vErrors.concat(validate1524.errors);
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
validate1505.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
return false;
}
}
validate1505.errors = vErrors;
return errors === 0;
}
validate1505.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema411 = {"type":"object","additionalProperties":false,"properties":{"partition":{"$ref":"#/$defs/RelationalRequest/$defs/T23"},"next_lsn":{"$ref":"#/$defs/RelationalRequest/$defs/T23"}},"required":["partition","next_lsn"]};

function validate1543(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1543.evaluated;
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
validate1543.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "partition") || (key0 === "next_lsn"))){
validate1543.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.partition !== undefined){
const _errs2 = errors;
if(!(validate1503(data.partition, {instancePath:instancePath+"/partition",parentData:data,parentDataProperty:"partition",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1503.errors : vErrors.concat(validate1503.errors);
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
if(!(validate1503(data.next_lsn, {instancePath:instancePath+"/next_lsn",parentData:data,parentDataProperty:"next_lsn",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1503.errors : vErrors.concat(validate1503.errors);
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
validate1543.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
return false;
}
}
validate1543.errors = vErrors;
return errors === 0;
}
validate1543.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate1502(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1502.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((((data.alias === undefined) && (missing0 = "alias")) || ((data.binding === undefined) && (missing0 = "binding"))) || ((data.position === undefined) && (missing0 = "position"))){
validate1502.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "alias") || (key0 === "binding")) || (key0 === "position"))){
validate1502.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.alias !== undefined){
const _errs2 = errors;
if(!(validate1503(data.alias, {instancePath:instancePath+"/alias",parentData:data,parentDataProperty:"alias",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1503.errors : vErrors.concat(validate1503.errors);
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
if(!(validate1505(data.binding, {instancePath:instancePath+"/binding",parentData:data,parentDataProperty:"binding",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1505.errors : vErrors.concat(validate1505.errors);
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
if(!(validate1543(data.position, {instancePath:instancePath+"/position",parentData:data,parentDataProperty:"position",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1543.errors : vErrors.concat(validate1543.errors);
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
validate1502.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
return false;
}
}
validate1502.errors = vErrors;
return errors === 0;
}
validate1502.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate1501(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1501.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(Array.isArray(data)){
if(data.length > 2){
validate1501.errors = [{instancePath,schemaPath:"#/maxItems",keyword:"maxItems",params:{limit: 2}}];
return false;
}
else {
var valid0 = true;
const len0 = data.length;
for(let i0=0; i0<len0; i0++){
const _errs1 = errors;
if(!(validate1502(data[i0], {instancePath:instancePath+"/" + i0,parentData:data,parentDataProperty:i0,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1502.errors : vErrors.concat(validate1502.errors);
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
validate1501.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "array"}}];
return false;
}
}
validate1501.errors = vErrors;
return errors === 0;
}
validate1501.evaluated = {"items":true,"dynamicProps":false,"dynamicItems":false};


function validate1498(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1498.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((((data.id === undefined) && (missing0 = "id")) || ((data.statement === undefined) && (missing0 = "statement"))) || ((data.sources === undefined) && (missing0 = "sources"))){
validate1498.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "id") || (key0 === "statement")) || (key0 === "sources"))){
validate1498.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.id !== undefined){
const _errs2 = errors;
if(!(validate1456(data.id, {instancePath:instancePath+"/id",parentData:data,parentDataProperty:"id",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1456.errors : vErrors.concat(validate1456.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.statement !== undefined){
const _errs3 = errors;
if(!(validate1490(data.statement, {instancePath:instancePath+"/statement",parentData:data,parentDataProperty:"statement",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1490.errors : vErrors.concat(validate1490.errors);
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
if(!(validate1501(data.sources, {instancePath:instancePath+"/sources",parentData:data,parentDataProperty:"sources",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1501.errors : vErrors.concat(validate1501.errors);
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
validate1498.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
return false;
}
}
validate1498.errors = vErrors;
return errors === 0;
}
validate1498.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema412 = {"type":"object","additionalProperties":false,"properties":{"reference":{"$ref":"#/$defs/RelationalRequest/$defs/T37"},"ordinal":{"$ref":"#/$defs/RelationalRequest/$defs/T9"}},"required":["reference","ordinal"]};
const schema413 = {"type":"object","additionalProperties":false,"properties":{"definition":{"$ref":"#/$defs/RelationalRequest/$defs/T5"},"id":{"$ref":"#/$defs/RelationalRequest/$defs/T9"},"plan":{"$ref":"#/$defs/RelationalRequest/$defs/T9"},"basis":{"$ref":"#/$defs/RelationalRequest/$defs/T9"}},"required":["definition","id","plan","basis"]};

function validate1551(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1551.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if(((((data.definition === undefined) && (missing0 = "definition")) || ((data.id === undefined) && (missing0 = "id"))) || ((data.plan === undefined) && (missing0 = "plan"))) || ((data.basis === undefined) && (missing0 = "basis"))){
validate1551.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((((key0 === "definition") || (key0 === "id")) || (key0 === "plan")) || (key0 === "basis"))){
validate1551.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.definition !== undefined){
const _errs2 = errors;
if(!(validate1449(data.definition, {instancePath:instancePath+"/definition",parentData:data,parentDataProperty:"definition",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1449.errors : vErrors.concat(validate1449.errors);
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
if(!(validate1456(data.id, {instancePath:instancePath+"/id",parentData:data,parentDataProperty:"id",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1456.errors : vErrors.concat(validate1456.errors);
errors = vErrors.length;
}
var valid0 = _errs3 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.plan !== undefined){
const _errs4 = errors;
if(!(validate1456(data.plan, {instancePath:instancePath+"/plan",parentData:data,parentDataProperty:"plan",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1456.errors : vErrors.concat(validate1456.errors);
errors = vErrors.length;
}
var valid0 = _errs4 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.basis !== undefined){
const _errs5 = errors;
if(!(validate1456(data.basis, {instancePath:instancePath+"/basis",parentData:data,parentDataProperty:"basis",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1456.errors : vErrors.concat(validate1456.errors);
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
validate1551.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
return false;
}
}
validate1551.errors = vErrors;
return errors === 0;
}
validate1551.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate1550(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1550.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if(((data.reference === undefined) && (missing0 = "reference")) || ((data.ordinal === undefined) && (missing0 = "ordinal"))){
validate1550.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "reference") || (key0 === "ordinal"))){
validate1550.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.reference !== undefined){
const _errs2 = errors;
if(!(validate1551(data.reference, {instancePath:instancePath+"/reference",parentData:data,parentDataProperty:"reference",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1551.errors : vErrors.concat(validate1551.errors);
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
if(!(validate1456(data.ordinal, {instancePath:instancePath+"/ordinal",parentData:data,parentDataProperty:"ordinal",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1456.errors : vErrors.concat(validate1456.errors);
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
validate1550.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
return false;
}
}
validate1550.errors = vErrors;
return errors === 0;
}
validate1550.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate1488(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1488.evaluated;
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
const err0 = {instancePath,schemaPath:"#/oneOf/0/required",keyword:"required",params:{missingProperty: missing0}};
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
const err1 = {instancePath,schemaPath:"#/oneOf/0/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}};
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
if(!(validate1443(data.capabilities, {instancePath:instancePath+"/capabilities",parentData:data,parentDataProperty:"capabilities",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1443.errors : vErrors.concat(validate1443.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err2 = {instancePath,schemaPath:"#/oneOf/0/type",keyword:"type",params:{type: "object"}};
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
if((data.explain === undefined) && (missing1 = "explain")){
const err3 = {instancePath,schemaPath:"#/oneOf/1/required",keyword:"required",params:{missingProperty: missing1}};
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
if(!(key1 === "explain")){
const err4 = {instancePath,schemaPath:"#/oneOf/1/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key1}};
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
if(data.explain !== undefined){
if(!(validate1490(data.explain, {instancePath:instancePath+"/explain",parentData:data,parentDataProperty:"explain",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1490.errors : vErrors.concat(validate1490.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err5 = {instancePath,schemaPath:"#/oneOf/1/type",keyword:"type",params:{type: "object"}};
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
if((data.open === undefined) && (missing2 = "open")){
const err6 = {instancePath,schemaPath:"#/oneOf/2/required",keyword:"required",params:{missingProperty: missing2}};
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
if(!(key2 === "open")){
const err7 = {instancePath,schemaPath:"#/oneOf/2/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key2}};
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
if(data.open !== undefined){
if(!(validate1498(data.open, {instancePath:instancePath+"/open",parentData:data,parentDataProperty:"open",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1498.errors : vErrors.concat(validate1498.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err8 = {instancePath,schemaPath:"#/oneOf/2/type",keyword:"type",params:{type: "object"}};
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
if((data.page === undefined) && (missing3 = "page")){
const err9 = {instancePath,schemaPath:"#/oneOf/3/required",keyword:"required",params:{missingProperty: missing3}};
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
if(!(key3 === "page")){
const err10 = {instancePath,schemaPath:"#/oneOf/3/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key3}};
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
if(data.page !== undefined){
if(!(validate1550(data.page, {instancePath:instancePath+"/page",parentData:data,parentDataProperty:"page",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1550.errors : vErrors.concat(validate1550.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err11 = {instancePath,schemaPath:"#/oneOf/3/type",keyword:"type",params:{type: "object"}};
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
if((data.close === undefined) && (missing4 = "close")){
const err12 = {instancePath,schemaPath:"#/oneOf/4/required",keyword:"required",params:{missingProperty: missing4}};
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
if(!(key4 === "close")){
const err13 = {instancePath,schemaPath:"#/oneOf/4/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key4}};
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
if(data.close !== undefined){
if(!(validate1551(data.close, {instancePath:instancePath+"/close",parentData:data,parentDataProperty:"close",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1551.errors : vErrors.concat(validate1551.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err14 = {instancePath,schemaPath:"#/oneOf/4/type",keyword:"type",params:{type: "object"}};
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
const err15 = {instancePath,schemaPath:"#/oneOf",keyword:"oneOf",params:{passingSchemas: passing0}};
if(vErrors === null){
vErrors = [err15];
}
else {
vErrors.push(err15);
}
errors++;
validate1488.errors = vErrors;
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
validate1488.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate1488.evaluated = {"dynamicProps":true,"dynamicItems":false};

const schema414 = {"type":"object","additionalProperties":false,"properties":{"id":{"$ref":"#/$defs/RelationalRequest/$defs/T9"}},"required":["id"]};

function validate1561(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1561.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((data.id === undefined) && (missing0 = "id")){
validate1561.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(key0 === "id")){
validate1561.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.id !== undefined){
if(!(validate1456(data.id, {instancePath:instancePath+"/id",parentData:data,parentDataProperty:"id",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1456.errors : vErrors.concat(validate1456.errors);
errors = vErrors.length;
}
}
}
}
}
else {
validate1561.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
return false;
}
}
validate1561.errors = vErrors;
return errors === 0;
}
validate1561.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate1442(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1442.evaluated;
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
const err0 = {instancePath,schemaPath:"#/oneOf/0/required",keyword:"required",params:{missingProperty: missing0}};
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
const err1 = {instancePath,schemaPath:"#/oneOf/0/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}};
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
if(!(validate1443(data.describe, {instancePath:instancePath+"/describe",parentData:data,parentDataProperty:"describe",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1443.errors : vErrors.concat(validate1443.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err2 = {instancePath,schemaPath:"#/oneOf/0/type",keyword:"type",params:{type: "object"}};
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
if((data.storage === undefined) && (missing1 = "storage")){
const err3 = {instancePath,schemaPath:"#/oneOf/1/required",keyword:"required",params:{missingProperty: missing1}};
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
if(!(key1 === "storage")){
const err4 = {instancePath,schemaPath:"#/oneOf/1/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key1}};
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
if(data.storage !== undefined){
if(!(validate1445(data.storage, {instancePath:instancePath+"/storage",parentData:data,parentDataProperty:"storage",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1445.errors : vErrors.concat(validate1445.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err5 = {instancePath,schemaPath:"#/oneOf/1/type",keyword:"type",params:{type: "object"}};
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
if((data.query === undefined) && (missing2 = "query")){
const err6 = {instancePath,schemaPath:"#/oneOf/2/required",keyword:"required",params:{missingProperty: missing2}};
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
if(!(key2 === "query")){
const err7 = {instancePath,schemaPath:"#/oneOf/2/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key2}};
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
if(data.query !== undefined){
if(!(validate1488(data.query, {instancePath:instancePath+"/query",parentData:data,parentDataProperty:"query",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1488.errors : vErrors.concat(validate1488.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err8 = {instancePath,schemaPath:"#/oneOf/2/type",keyword:"type",params:{type: "object"}};
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
if((data.recover === undefined) && (missing3 = "recover")){
const err9 = {instancePath,schemaPath:"#/oneOf/3/required",keyword:"required",params:{missingProperty: missing3}};
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
if(!(key3 === "recover")){
const err10 = {instancePath,schemaPath:"#/oneOf/3/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key3}};
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
if(data.recover !== undefined){
if(!(validate1561(data.recover, {instancePath:instancePath+"/recover",parentData:data,parentDataProperty:"recover",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1561.errors : vErrors.concat(validate1561.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err11 = {instancePath,schemaPath:"#/oneOf/3/type",keyword:"type",params:{type: "object"}};
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
const err12 = {instancePath,schemaPath:"#/oneOf",keyword:"oneOf",params:{passingSchemas: passing0}};
if(vErrors === null){
vErrors = [err12];
}
else {
vErrors.push(err12);
}
errors++;
validate1442.errors = vErrors;
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
validate1442.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate1442.evaluated = {"dynamicProps":true,"dynamicItems":false};

export const RelationalResponse = validate1564;
const schema415 = {"oneOf":[{"type":"object","additionalProperties":false,"required":["description"],"properties":{"description":{"$ref":"#/$defs/RelationalResponse/$defs/T1"}}},{"type":"object","additionalProperties":false,"required":["storage"],"properties":{"storage":{"$ref":"#/$defs/RelationalResponse/$defs/T68"}}},{"type":"object","additionalProperties":false,"required":["query"],"properties":{"query":{"$ref":"#/$defs/RelationalResponse/$defs/T81"}}},{"type":"object","additionalProperties":false,"required":["recovered"],"properties":{"recovered":{"$ref":"#/$defs/RelationalResponse/$defs/T39"}}}]};
const schema416 = {"type":"object","additionalProperties":false,"properties":{"capabilities":{"$ref":"#/$defs/RelationalResponse/$defs/T2"},"routes":{"$ref":"#/$defs/RelationalResponse/$defs/T7"},"active":{"$ref":"#/$defs/RelationalResponse/$defs/T20"},"recovery":{"$ref":"#/$defs/RelationalResponse/$defs/T65"}},"required":["capabilities","routes","active","recovery"]};
const schema417 = {"type":"object","additionalProperties":false,"properties":{"definition":{"$ref":"#/$defs/RelationalResponse/$defs/T3"},"sources":{"$ref":"#/$defs/RelationalResponse/$defs/T4"},"active_queries":{"$ref":"#/$defs/RelationalResponse/$defs/T4"},"page_rows":{"$ref":"#/$defs/RelationalResponse/$defs/T4"},"interactive":{"$ref":"#/$defs/RelationalResponse/$defs/T5"},"captured":{"$ref":"#/$defs/RelationalResponse/$defs/T5"},"maintained":{"$ref":"#/$defs/RelationalResponse/$defs/T5"},"consistency":{"$ref":"#/$defs/RelationalResponse/$defs/T6"}},"required":["definition","sources","active_queries","page_rows","interactive","captured","maintained","consistency"]};

function validate1567(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1567.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate1567.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"}}];
return false;
}
if(!(data === "fe0da791b6421a288d3f53bedbfd1804cf5583c2c08e1d121c8120125daeb9f6")){
validate1567.errors = [{instancePath,schemaPath:"#/enum",keyword:"enum",params:{allowedValues: schema55.enum}}];
return false;
}
validate1567.errors = vErrors;
return errors === 0;
}
validate1567.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema36 = {"type":"integer","minimum":0,"maximum":255};

function validate1569(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1569.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(!(((typeof data == "number") && (!(data % 1) && !isNaN(data))) && (isFinite(data)))){
validate1569.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "integer"}}];
return false;
}
if(errors === 0){
if((typeof data == "number") && (isFinite(data))){
if(data > 255 || isNaN(data)){
validate1569.errors = [{instancePath,schemaPath:"#/maximum",keyword:"maximum",params:{comparison: "<=", limit: 255}}];
return false;
}
else {
if(data < 0 || isNaN(data)){
validate1569.errors = [{instancePath,schemaPath:"#/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0}}];
return false;
}
}
}
}
validate1569.errors = vErrors;
return errors === 0;
}
validate1569.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema420 = {"type":"boolean"};

function validate1573(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1573.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "boolean"){
validate1573.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "boolean"}}];
return false;
}
validate1573.errors = vErrors;
return errors === 0;
}
validate1573.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema421 = {"type":"string","enum":["per_resource_snapshot_vector","independent_table_snapshots","atomic"]};

function validate1577(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1577.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate1577.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"}}];
return false;
}
if(!(((data === "per_resource_snapshot_vector") || (data === "independent_table_snapshots")) || (data === "atomic"))){
validate1577.errors = [{instancePath,schemaPath:"#/enum",keyword:"enum",params:{allowedValues: schema421.enum}}];
return false;
}
validate1577.errors = vErrors;
return errors === 0;
}
validate1577.evaluated = {"dynamicProps":false,"dynamicItems":false};


function validate1566(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1566.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if(((((((((data.definition === undefined) && (missing0 = "definition")) || ((data.sources === undefined) && (missing0 = "sources"))) || ((data.active_queries === undefined) && (missing0 = "active_queries"))) || ((data.page_rows === undefined) && (missing0 = "page_rows"))) || ((data.interactive === undefined) && (missing0 = "interactive"))) || ((data.captured === undefined) && (missing0 = "captured"))) || ((data.maintained === undefined) && (missing0 = "maintained"))) || ((data.consistency === undefined) && (missing0 = "consistency"))){
validate1566.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((((((((key0 === "definition") || (key0 === "sources")) || (key0 === "active_queries")) || (key0 === "page_rows")) || (key0 === "interactive")) || (key0 === "captured")) || (key0 === "maintained")) || (key0 === "consistency"))){
validate1566.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.definition !== undefined){
const _errs2 = errors;
if(!(validate1567(data.definition, {instancePath:instancePath+"/definition",parentData:data,parentDataProperty:"definition",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1567.errors : vErrors.concat(validate1567.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.sources !== undefined){
const _errs3 = errors;
if(!(validate1569(data.sources, {instancePath:instancePath+"/sources",parentData:data,parentDataProperty:"sources",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1569.errors : vErrors.concat(validate1569.errors);
errors = vErrors.length;
}
var valid0 = _errs3 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.active_queries !== undefined){
const _errs4 = errors;
if(!(validate1569(data.active_queries, {instancePath:instancePath+"/active_queries",parentData:data,parentDataProperty:"active_queries",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1569.errors : vErrors.concat(validate1569.errors);
errors = vErrors.length;
}
var valid0 = _errs4 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.page_rows !== undefined){
const _errs5 = errors;
if(!(validate1569(data.page_rows, {instancePath:instancePath+"/page_rows",parentData:data,parentDataProperty:"page_rows",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1569.errors : vErrors.concat(validate1569.errors);
errors = vErrors.length;
}
var valid0 = _errs5 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.interactive !== undefined){
const _errs6 = errors;
if(!(validate1573(data.interactive, {instancePath:instancePath+"/interactive",parentData:data,parentDataProperty:"interactive",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1573.errors : vErrors.concat(validate1573.errors);
errors = vErrors.length;
}
var valid0 = _errs6 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.captured !== undefined){
const _errs7 = errors;
if(!(validate1573(data.captured, {instancePath:instancePath+"/captured",parentData:data,parentDataProperty:"captured",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1573.errors : vErrors.concat(validate1573.errors);
errors = vErrors.length;
}
var valid0 = _errs7 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.maintained !== undefined){
const _errs8 = errors;
if(!(validate1573(data.maintained, {instancePath:instancePath+"/maintained",parentData:data,parentDataProperty:"maintained",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1573.errors : vErrors.concat(validate1573.errors);
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
if(!(validate1577(data.consistency, {instancePath:instancePath+"/consistency",parentData:data,parentDataProperty:"consistency",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1577.errors : vErrors.concat(validate1577.errors);
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
validate1566.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
return false;
}
}
validate1566.errors = vErrors;
return errors === 0;
}
validate1566.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema422 = {"type":"array","maxItems":2,"items":{"$ref":"#/$defs/RelationalResponse/$defs/T8"}};
const schema423 = {"type":"object","additionalProperties":false,"properties":{"connection":{"$ref":"#/$defs/RelationalResponse/$defs/T9"},"description":{"$ref":"#/$defs/RelationalResponse/$defs/T14"}},"required":["connection","description"]};
const schema424 = {"type":"object","additionalProperties":false,"properties":{"scope":{"$ref":"#/$defs/RelationalResponse/$defs/T10"},"branch":{"$ref":"#/$defs/RelationalResponse/$defs/T12"},"audience":{"$ref":"#/$defs/RelationalResponse/$defs/T11"},"principal":{"$ref":"#/$defs/RelationalResponse/$defs/T11"},"role":{"$ref":"#/$defs/RelationalResponse/$defs/T13"}},"required":["scope","branch","audience","principal","role"]};
const schema425 = {"type":"object","additionalProperties":false,"properties":{"realm":{"$ref":"#/$defs/RelationalResponse/$defs/T11"},"resource":{"$ref":"#/$defs/RelationalResponse/$defs/T11"},"catalog":{"$ref":"#/$defs/RelationalResponse/$defs/T12"}},"required":["realm","resource","catalog"]};

function validate1584(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1584.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(!(((typeof data == "number") && (!(data % 1) && !isNaN(data))) && (isFinite(data)))){
validate1584.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "integer"}}];
return false;
}
if(errors === 0){
if((typeof data == "number") && (isFinite(data))){
if(data > 9007199254740991 || isNaN(data)){
validate1584.errors = [{instancePath,schemaPath:"#/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991}}];
return false;
}
else {
if(data < 0 || isNaN(data)){
validate1584.errors = [{instancePath,schemaPath:"#/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0}}];
return false;
}
}
}
}
validate1584.errors = vErrors;
return errors === 0;
}
validate1584.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema427 = {"type":"string","maxLength":4096};

function validate1587(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1587.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(typeof data === "string"){
if(func4(data) > 4096){
validate1587.errors = [{instancePath,schemaPath:"#/maxLength",keyword:"maxLength",params:{limit: 4096}}];
return false;
}
}
else {
validate1587.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"}}];
return false;
}
}
validate1587.errors = vErrors;
return errors === 0;
}
validate1587.evaluated = {"dynamicProps":false,"dynamicItems":false};


function validate1583(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1583.evaluated;
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
validate1583.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "realm") || (key0 === "resource")) || (key0 === "catalog"))){
validate1583.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.realm !== undefined){
const _errs2 = errors;
if(!(validate1584(data.realm, {instancePath:instancePath+"/realm",parentData:data,parentDataProperty:"realm",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1584.errors : vErrors.concat(validate1584.errors);
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
if(!(validate1584(data.resource, {instancePath:instancePath+"/resource",parentData:data,parentDataProperty:"resource",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1584.errors : vErrors.concat(validate1584.errors);
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
if(!(validate1587(data.catalog, {instancePath:instancePath+"/catalog",parentData:data,parentDataProperty:"catalog",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1587.errors : vErrors.concat(validate1587.errors);
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
validate1583.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
return false;
}
}
validate1583.errors = vErrors;
return errors === 0;
}
validate1583.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema428 = {"anyOf":[{"$ref":"#/$defs/RelationalResponse/$defs/T11"},{"type":"null"}]};

function validate1593(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1593.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate1584(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1584.errors : vErrors.concat(validate1584.errors);
errors = vErrors.length;
}
var _valid0 = _errs1 === errors;
valid0 = valid0 || _valid0;
const _errs2 = errors;
if(data !== null){
const err0 = {instancePath,schemaPath:"#/anyOf/1/type",keyword:"type",params:{type: "null"}};
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
const err1 = {instancePath,schemaPath:"#/anyOf",keyword:"anyOf",params:{}};
if(vErrors === null){
vErrors = [err1];
}
else {
vErrors.push(err1);
}
errors++;
validate1593.errors = vErrors;
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
validate1593.errors = vErrors;
return errors === 0;
}
validate1593.evaluated = {"dynamicProps":false,"dynamicItems":false};


function validate1582(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1582.evaluated;
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
validate1582.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((((key0 === "scope") || (key0 === "branch")) || (key0 === "audience")) || (key0 === "principal")) || (key0 === "role"))){
validate1582.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.scope !== undefined){
const _errs2 = errors;
if(!(validate1583(data.scope, {instancePath:instancePath+"/scope",parentData:data,parentDataProperty:"scope",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1583.errors : vErrors.concat(validate1583.errors);
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
if(!(validate1587(data.branch, {instancePath:instancePath+"/branch",parentData:data,parentDataProperty:"branch",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1587.errors : vErrors.concat(validate1587.errors);
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
if(!(validate1584(data.audience, {instancePath:instancePath+"/audience",parentData:data,parentDataProperty:"audience",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1584.errors : vErrors.concat(validate1584.errors);
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
if(!(validate1584(data.principal, {instancePath:instancePath+"/principal",parentData:data,parentDataProperty:"principal",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1584.errors : vErrors.concat(validate1584.errors);
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
if(!(validate1593(data.role, {instancePath:instancePath+"/role",parentData:data,parentDataProperty:"role",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1593.errors : vErrors.concat(validate1593.errors);
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
validate1582.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
return false;
}
}
validate1582.errors = vErrors;
return errors === 0;
}
validate1582.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema429 = {"type":"object","additionalProperties":false,"properties":{"configuration":{"$ref":"#/$defs/RelationalResponse/$defs/T15"},"subject":{"$ref":"#/$defs/RelationalResponse/$defs/T17"},"policy_revision":{"$ref":"#/$defs/RelationalResponse/$defs/T11"}},"required":["configuration","subject","policy_revision"]};
const schema430 = {"type":"object","additionalProperties":false,"properties":{"scope":{"$ref":"#/$defs/RelationalResponse/$defs/T10"},"branch":{"$ref":"#/$defs/RelationalResponse/$defs/T12"},"partition":{"$ref":"#/$defs/RelationalResponse/$defs/T12"},"audience":{"$ref":"#/$defs/RelationalResponse/$defs/T11"},"authority":{"$ref":"#/$defs/RelationalResponse/$defs/T16"},"database_name":{"$ref":"#/$defs/RelationalResponse/$defs/T12"},"initial_schema_name":{"$ref":"#/$defs/RelationalResponse/$defs/T12"}},"required":["scope","branch","partition","audience","authority","database_name","initial_schema_name"]};
const schema431 = {"type":"object","additionalProperties":false,"properties":{"database_domain":{"$ref":"#/$defs/RelationalResponse/$defs/T11"},"schema_domain":{"$ref":"#/$defs/RelationalResponse/$defs/T11"},"table_domain":{"$ref":"#/$defs/RelationalResponse/$defs/T11"},"database":{"$ref":"#/$defs/RelationalResponse/$defs/T11"},"initial_schema":{"$ref":"#/$defs/RelationalResponse/$defs/T11"},"initial_schema_authority":{"$ref":"#/$defs/RelationalResponse/$defs/T11"}},"required":["database_domain","schema_domain","table_domain","database","initial_schema","initial_schema_authority"]};

function validate1603(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1603.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if(((((((data.database_domain === undefined) && (missing0 = "database_domain")) || ((data.schema_domain === undefined) && (missing0 = "schema_domain"))) || ((data.table_domain === undefined) && (missing0 = "table_domain"))) || ((data.database === undefined) && (missing0 = "database"))) || ((data.initial_schema === undefined) && (missing0 = "initial_schema"))) || ((data.initial_schema_authority === undefined) && (missing0 = "initial_schema_authority"))){
validate1603.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((((((key0 === "database_domain") || (key0 === "schema_domain")) || (key0 === "table_domain")) || (key0 === "database")) || (key0 === "initial_schema")) || (key0 === "initial_schema_authority"))){
validate1603.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.database_domain !== undefined){
const _errs2 = errors;
if(!(validate1584(data.database_domain, {instancePath:instancePath+"/database_domain",parentData:data,parentDataProperty:"database_domain",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1584.errors : vErrors.concat(validate1584.errors);
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
if(!(validate1584(data.schema_domain, {instancePath:instancePath+"/schema_domain",parentData:data,parentDataProperty:"schema_domain",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1584.errors : vErrors.concat(validate1584.errors);
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
if(!(validate1584(data.table_domain, {instancePath:instancePath+"/table_domain",parentData:data,parentDataProperty:"table_domain",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1584.errors : vErrors.concat(validate1584.errors);
errors = vErrors.length;
}
var valid0 = _errs4 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.database !== undefined){
const _errs5 = errors;
if(!(validate1584(data.database, {instancePath:instancePath+"/database",parentData:data,parentDataProperty:"database",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1584.errors : vErrors.concat(validate1584.errors);
errors = vErrors.length;
}
var valid0 = _errs5 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.initial_schema !== undefined){
const _errs6 = errors;
if(!(validate1584(data.initial_schema, {instancePath:instancePath+"/initial_schema",parentData:data,parentDataProperty:"initial_schema",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1584.errors : vErrors.concat(validate1584.errors);
errors = vErrors.length;
}
var valid0 = _errs6 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.initial_schema_authority !== undefined){
const _errs7 = errors;
if(!(validate1584(data.initial_schema_authority, {instancePath:instancePath+"/initial_schema_authority",parentData:data,parentDataProperty:"initial_schema_authority",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1584.errors : vErrors.concat(validate1584.errors);
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
validate1603.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
return false;
}
}
validate1603.errors = vErrors;
return errors === 0;
}
validate1603.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate1598(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1598.evaluated;
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
validate1598.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((((((key0 === "scope") || (key0 === "branch")) || (key0 === "partition")) || (key0 === "audience")) || (key0 === "authority")) || (key0 === "database_name")) || (key0 === "initial_schema_name"))){
validate1598.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.scope !== undefined){
const _errs2 = errors;
if(!(validate1583(data.scope, {instancePath:instancePath+"/scope",parentData:data,parentDataProperty:"scope",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1583.errors : vErrors.concat(validate1583.errors);
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
if(!(validate1587(data.branch, {instancePath:instancePath+"/branch",parentData:data,parentDataProperty:"branch",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1587.errors : vErrors.concat(validate1587.errors);
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
if(!(validate1587(data.partition, {instancePath:instancePath+"/partition",parentData:data,parentDataProperty:"partition",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1587.errors : vErrors.concat(validate1587.errors);
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
if(!(validate1584(data.audience, {instancePath:instancePath+"/audience",parentData:data,parentDataProperty:"audience",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1584.errors : vErrors.concat(validate1584.errors);
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
if(!(validate1603(data.authority, {instancePath:instancePath+"/authority",parentData:data,parentDataProperty:"authority",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1603.errors : vErrors.concat(validate1603.errors);
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
if(!(validate1587(data.database_name, {instancePath:instancePath+"/database_name",parentData:data,parentDataProperty:"database_name",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1587.errors : vErrors.concat(validate1587.errors);
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
if(!(validate1587(data.initial_schema_name, {instancePath:instancePath+"/initial_schema_name",parentData:data,parentDataProperty:"initial_schema_name",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1587.errors : vErrors.concat(validate1587.errors);
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
validate1598.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
return false;
}
}
validate1598.errors = vErrors;
return errors === 0;
}
validate1598.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema432 = {"type":"object","additionalProperties":false,"properties":{"principal":{"$ref":"#/$defs/RelationalResponse/$defs/T11"},"login_role":{"$ref":"#/$defs/RelationalResponse/$defs/T11"},"role":{"$ref":"#/$defs/RelationalResponse/$defs/T11"},"credential_epoch":{"$ref":"#/$defs/RelationalResponse/$defs/T11"},"audience":{"$ref":"#/$defs/RelationalResponse/$defs/T11"},"context":{"$ref":"#/$defs/RelationalResponse/$defs/T18"}},"required":["principal","login_role","role","credential_epoch","audience","context"]};
const schema433 = {"type":"array","minItems":32,"maxItems":32,"items":{"$ref":"#/$defs/RelationalResponse/$defs/T19"}};

function validate1621(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1621.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(!(((typeof data == "number") && (!(data % 1) && !isNaN(data))) && (isFinite(data)))){
validate1621.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "integer"}}];
return false;
}
if(errors === 0){
if((typeof data == "number") && (isFinite(data))){
if(data > 255 || isNaN(data)){
validate1621.errors = [{instancePath,schemaPath:"#/maximum",keyword:"maximum",params:{comparison: "<=", limit: 255}}];
return false;
}
else {
if(data < 0 || isNaN(data)){
validate1621.errors = [{instancePath,schemaPath:"#/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0}}];
return false;
}
}
}
}
validate1621.errors = vErrors;
return errors === 0;
}
validate1621.evaluated = {"dynamicProps":false,"dynamicItems":false};


function validate1620(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1620.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(Array.isArray(data)){
if(data.length > 32){
validate1620.errors = [{instancePath,schemaPath:"#/maxItems",keyword:"maxItems",params:{limit: 32}}];
return false;
}
else {
if(data.length < 32){
validate1620.errors = [{instancePath,schemaPath:"#/minItems",keyword:"minItems",params:{limit: 32}}];
return false;
}
else {
var valid0 = true;
const len0 = data.length;
for(let i0=0; i0<len0; i0++){
const _errs1 = errors;
if(!(validate1621(data[i0], {instancePath:instancePath+"/" + i0,parentData:data,parentDataProperty:i0,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1621.errors : vErrors.concat(validate1621.errors);
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
validate1620.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "array"}}];
return false;
}
}
validate1620.errors = vErrors;
return errors === 0;
}
validate1620.evaluated = {"items":true,"dynamicProps":false,"dynamicItems":false};


function validate1614(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1614.evaluated;
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
validate1614.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((((((key0 === "principal") || (key0 === "login_role")) || (key0 === "role")) || (key0 === "credential_epoch")) || (key0 === "audience")) || (key0 === "context"))){
validate1614.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.principal !== undefined){
const _errs2 = errors;
if(!(validate1584(data.principal, {instancePath:instancePath+"/principal",parentData:data,parentDataProperty:"principal",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1584.errors : vErrors.concat(validate1584.errors);
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
if(!(validate1584(data.login_role, {instancePath:instancePath+"/login_role",parentData:data,parentDataProperty:"login_role",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1584.errors : vErrors.concat(validate1584.errors);
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
if(!(validate1584(data.role, {instancePath:instancePath+"/role",parentData:data,parentDataProperty:"role",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1584.errors : vErrors.concat(validate1584.errors);
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
if(!(validate1584(data.credential_epoch, {instancePath:instancePath+"/credential_epoch",parentData:data,parentDataProperty:"credential_epoch",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1584.errors : vErrors.concat(validate1584.errors);
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
if(!(validate1584(data.audience, {instancePath:instancePath+"/audience",parentData:data,parentDataProperty:"audience",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1584.errors : vErrors.concat(validate1584.errors);
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
if(!(validate1620(data.context, {instancePath:instancePath+"/context",parentData:data,parentDataProperty:"context",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1620.errors : vErrors.concat(validate1620.errors);
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
validate1614.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
return false;
}
}
validate1614.errors = vErrors;
return errors === 0;
}
validate1614.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate1597(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1597.evaluated;
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
validate1597.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "configuration") || (key0 === "subject")) || (key0 === "policy_revision"))){
validate1597.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.configuration !== undefined){
const _errs2 = errors;
if(!(validate1598(data.configuration, {instancePath:instancePath+"/configuration",parentData:data,parentDataProperty:"configuration",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1598.errors : vErrors.concat(validate1598.errors);
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
if(!(validate1614(data.subject, {instancePath:instancePath+"/subject",parentData:data,parentDataProperty:"subject",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1614.errors : vErrors.concat(validate1614.errors);
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
if(!(validate1584(data.policy_revision, {instancePath:instancePath+"/policy_revision",parentData:data,parentDataProperty:"policy_revision",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1584.errors : vErrors.concat(validate1584.errors);
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
validate1597.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
return false;
}
}
validate1597.errors = vErrors;
return errors === 0;
}
validate1597.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate1581(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1581.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if(((data.connection === undefined) && (missing0 = "connection")) || ((data.description === undefined) && (missing0 = "description"))){
validate1581.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "connection") || (key0 === "description"))){
validate1581.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.connection !== undefined){
const _errs2 = errors;
if(!(validate1582(data.connection, {instancePath:instancePath+"/connection",parentData:data,parentDataProperty:"connection",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1582.errors : vErrors.concat(validate1582.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.description !== undefined){
const _errs3 = errors;
if(!(validate1597(data.description, {instancePath:instancePath+"/description",parentData:data,parentDataProperty:"description",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1597.errors : vErrors.concat(validate1597.errors);
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
validate1581.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
return false;
}
}
validate1581.errors = vErrors;
return errors === 0;
}
validate1581.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate1580(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1580.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(Array.isArray(data)){
if(data.length > 2){
validate1580.errors = [{instancePath,schemaPath:"#/maxItems",keyword:"maxItems",params:{limit: 2}}];
return false;
}
else {
var valid0 = true;
const len0 = data.length;
for(let i0=0; i0<len0; i0++){
const _errs1 = errors;
if(!(validate1581(data[i0], {instancePath:instancePath+"/" + i0,parentData:data,parentDataProperty:i0,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1581.errors : vErrors.concat(validate1581.errors);
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
validate1580.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "array"}}];
return false;
}
}
validate1580.errors = vErrors;
return errors === 0;
}
validate1580.evaluated = {"items":true,"dynamicProps":false,"dynamicItems":false};

const schema435 = {"anyOf":[{"$ref":"#/$defs/RelationalResponse/$defs/T21"},{"type":"null"}]};
const schema436 = {"type":"object","additionalProperties":false,"properties":{"opened":{"$ref":"#/$defs/RelationalResponse/$defs/T22"},"ordinal":{"$ref":"#/$defs/RelationalResponse/$defs/T24"},"read":{"$ref":"#/$defs/RelationalResponse/$defs/T5"}},"required":["opened","ordinal","read"]};
const schema437 = {"type":"object","additionalProperties":false,"properties":{"reference":{"$ref":"#/$defs/RelationalResponse/$defs/T23"},"description":{"$ref":"#/$defs/RelationalResponse/$defs/T25"},"cuts":{"$ref":"#/$defs/RelationalResponse/$defs/T63"},"complete_coverage":{"$ref":"#/$defs/RelationalResponse/$defs/T5"}},"required":["reference","description","cuts","complete_coverage"]};
const schema438 = {"type":"object","additionalProperties":false,"properties":{"definition":{"$ref":"#/$defs/RelationalResponse/$defs/T3"},"id":{"$ref":"#/$defs/RelationalResponse/$defs/T24"},"plan":{"$ref":"#/$defs/RelationalResponse/$defs/T24"},"basis":{"$ref":"#/$defs/RelationalResponse/$defs/T24"}},"required":["definition","id","plan","basis"]};
const schema439 = {"type":"string","maxLength":4096};

function validate1634(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1634.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(typeof data === "string"){
if(func4(data) > 4096){
validate1634.errors = [{instancePath,schemaPath:"#/maxLength",keyword:"maxLength",params:{limit: 4096}}];
return false;
}
}
else {
validate1634.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"}}];
return false;
}
}
validate1634.errors = vErrors;
return errors === 0;
}
validate1634.evaluated = {"dynamicProps":false,"dynamicItems":false};


function validate1632(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1632.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if(((((data.definition === undefined) && (missing0 = "definition")) || ((data.id === undefined) && (missing0 = "id"))) || ((data.plan === undefined) && (missing0 = "plan"))) || ((data.basis === undefined) && (missing0 = "basis"))){
validate1632.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((((key0 === "definition") || (key0 === "id")) || (key0 === "plan")) || (key0 === "basis"))){
validate1632.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.definition !== undefined){
const _errs2 = errors;
if(!(validate1567(data.definition, {instancePath:instancePath+"/definition",parentData:data,parentDataProperty:"definition",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1567.errors : vErrors.concat(validate1567.errors);
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
if(!(validate1634(data.id, {instancePath:instancePath+"/id",parentData:data,parentDataProperty:"id",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1634.errors : vErrors.concat(validate1634.errors);
errors = vErrors.length;
}
var valid0 = _errs3 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.plan !== undefined){
const _errs4 = errors;
if(!(validate1634(data.plan, {instancePath:instancePath+"/plan",parentData:data,parentDataProperty:"plan",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1634.errors : vErrors.concat(validate1634.errors);
errors = vErrors.length;
}
var valid0 = _errs4 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.basis !== undefined){
const _errs5 = errors;
if(!(validate1634(data.basis, {instancePath:instancePath+"/basis",parentData:data,parentDataProperty:"basis",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1634.errors : vErrors.concat(validate1634.errors);
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
validate1632.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
return false;
}
}
validate1632.errors = vErrors;
return errors === 0;
}
validate1632.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema440 = {"type":"object","additionalProperties":false,"properties":{"definition":{"$ref":"#/$defs/RelationalResponse/$defs/T3"},"plan":{"$ref":"#/$defs/RelationalResponse/$defs/T24"},"sources":{"$ref":"#/$defs/RelationalResponse/$defs/T26"},"columns":{"$ref":"#/$defs/RelationalResponse/$defs/T36"},"join":{"$ref":"#/$defs/RelationalResponse/$defs/T61"},"grouped":{"$ref":"#/$defs/RelationalResponse/$defs/T5"},"executed":{"$ref":"#/$defs/RelationalResponse/$defs/T5"}},"required":["definition","plan","sources","columns","join","grouped","executed"]};
const schema441 = {"type":"array","maxItems":2,"items":{"$ref":"#/$defs/RelationalResponse/$defs/T27"}};
const schema442 = {"type":"object","additionalProperties":false,"properties":{"alias":{"$ref":"#/$defs/RelationalResponse/$defs/T12"},"binding":{"$ref":"#/$defs/RelationalResponse/$defs/T28"},"position":{"$ref":"#/$defs/RelationalResponse/$defs/T35"}},"required":["alias","binding","position"]};
const schema443 = {"type":"object","additionalProperties":false,"properties":{"definition":{"$ref":"#/$defs/RelationalResponse/$defs/T29"},"connection":{"$ref":"#/$defs/RelationalResponse/$defs/T9"},"namespace":{"$ref":"#/$defs/RelationalResponse/$defs/T11"},"name":{"$ref":"#/$defs/RelationalResponse/$defs/T12"},"interpretation":{"$ref":"#/$defs/RelationalResponse/$defs/T30"}},"required":["definition","connection","namespace","name","interpretation"]};

function validate1646(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1646.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate1646.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"}}];
return false;
}
if(!(data === "fe0da791b6421a288d3f53bedbfd1804cf5583c2c08e1d121c8120125daeb9f6")){
validate1646.errors = [{instancePath,schemaPath:"#/enum",keyword:"enum",params:{allowedValues: schema55.enum}}];
return false;
}
validate1646.errors = vErrors;
return errors === 0;
}
validate1646.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema445 = {"type":"object","additionalProperties":false,"properties":{"interpretation":{"$ref":"#/$defs/RelationalResponse/$defs/T31"},"content":{"$ref":"#/$defs/RelationalResponse/$defs/T33"},"schema_fingerprint":{"$ref":"#/$defs/RelationalResponse/$defs/T12"},"retired":{"$ref":"#/$defs/RelationalResponse/$defs/T34"}},"required":["interpretation","content","schema_fingerprint","retired"]};
const schema446 = {"type":"object","additionalProperties":false,"properties":{"object":{"$ref":"#/$defs/RelationalResponse/$defs/T32"},"revision":{"$ref":"#/$defs/RelationalResponse/$defs/T12"},"digest":{"$ref":"#/$defs/RelationalResponse/$defs/T12"}},"required":["object","revision","digest"]};
const schema447 = {"type":"object","additionalProperties":false,"properties":{"scope":{"$ref":"#/$defs/RelationalResponse/$defs/T10"},"branch":{"$ref":"#/$defs/RelationalResponse/$defs/T12"},"object":{"$ref":"#/$defs/RelationalResponse/$defs/T12"}},"required":["scope","branch","object"]};

function validate1653(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1653.evaluated;
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
validate1653.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "scope") || (key0 === "branch")) || (key0 === "object"))){
validate1653.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.scope !== undefined){
const _errs2 = errors;
if(!(validate1583(data.scope, {instancePath:instancePath+"/scope",parentData:data,parentDataProperty:"scope",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1583.errors : vErrors.concat(validate1583.errors);
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
if(!(validate1587(data.branch, {instancePath:instancePath+"/branch",parentData:data,parentDataProperty:"branch",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1587.errors : vErrors.concat(validate1587.errors);
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
if(!(validate1587(data.object, {instancePath:instancePath+"/object",parentData:data,parentDataProperty:"object",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1587.errors : vErrors.concat(validate1587.errors);
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
validate1653.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
return false;
}
}
validate1653.errors = vErrors;
return errors === 0;
}
validate1653.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate1652(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1652.evaluated;
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
validate1652.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "object") || (key0 === "revision")) || (key0 === "digest"))){
validate1652.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.object !== undefined){
const _errs2 = errors;
if(!(validate1653(data.object, {instancePath:instancePath+"/object",parentData:data,parentDataProperty:"object",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1653.errors : vErrors.concat(validate1653.errors);
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
if(!(validate1587(data.revision, {instancePath:instancePath+"/revision",parentData:data,parentDataProperty:"revision",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1587.errors : vErrors.concat(validate1587.errors);
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
if(!(validate1587(data.digest, {instancePath:instancePath+"/digest",parentData:data,parentDataProperty:"digest",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1587.errors : vErrors.concat(validate1587.errors);
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
validate1652.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
return false;
}
}
validate1652.errors = vErrors;
return errors === 0;
}
validate1652.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema448 = {"type":"object","additionalProperties":false,"properties":{"bytes":{"$ref":"#/$defs/RelationalResponse/$defs/T12"},"sha256":{"$ref":"#/$defs/RelationalResponse/$defs/T12"}},"required":["bytes","sha256"]};

function validate1661(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1661.evaluated;
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
validate1661.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "bytes") || (key0 === "sha256"))){
validate1661.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.bytes !== undefined){
const _errs2 = errors;
if(!(validate1587(data.bytes, {instancePath:instancePath+"/bytes",parentData:data,parentDataProperty:"bytes",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1587.errors : vErrors.concat(validate1587.errors);
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
if(!(validate1587(data.sha256, {instancePath:instancePath+"/sha256",parentData:data,parentDataProperty:"sha256",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1587.errors : vErrors.concat(validate1587.errors);
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
validate1661.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
return false;
}
}
validate1661.errors = vErrors;
return errors === 0;
}
validate1661.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema449 = {"type":"boolean"};

function validate1666(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1666.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "boolean"){
validate1666.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "boolean"}}];
return false;
}
validate1666.errors = vErrors;
return errors === 0;
}
validate1666.evaluated = {"dynamicProps":false,"dynamicItems":false};


function validate1651(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1651.evaluated;
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
validate1651.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((((key0 === "interpretation") || (key0 === "content")) || (key0 === "schema_fingerprint")) || (key0 === "retired"))){
validate1651.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.interpretation !== undefined){
const _errs2 = errors;
if(!(validate1652(data.interpretation, {instancePath:instancePath+"/interpretation",parentData:data,parentDataProperty:"interpretation",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1652.errors : vErrors.concat(validate1652.errors);
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
if(!(validate1661(data.content, {instancePath:instancePath+"/content",parentData:data,parentDataProperty:"content",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1661.errors : vErrors.concat(validate1661.errors);
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
if(!(validate1587(data.schema_fingerprint, {instancePath:instancePath+"/schema_fingerprint",parentData:data,parentDataProperty:"schema_fingerprint",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1587.errors : vErrors.concat(validate1587.errors);
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
if(!(validate1666(data.retired, {instancePath:instancePath+"/retired",parentData:data,parentDataProperty:"retired",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1666.errors : vErrors.concat(validate1666.errors);
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
validate1651.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
return false;
}
}
validate1651.errors = vErrors;
return errors === 0;
}
validate1651.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate1645(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1645.evaluated;
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
validate1645.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((((key0 === "definition") || (key0 === "connection")) || (key0 === "namespace")) || (key0 === "name")) || (key0 === "interpretation"))){
validate1645.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.definition !== undefined){
const _errs2 = errors;
if(!(validate1646(data.definition, {instancePath:instancePath+"/definition",parentData:data,parentDataProperty:"definition",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1646.errors : vErrors.concat(validate1646.errors);
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
if(!(validate1582(data.connection, {instancePath:instancePath+"/connection",parentData:data,parentDataProperty:"connection",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1582.errors : vErrors.concat(validate1582.errors);
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
if(!(validate1584(data.namespace, {instancePath:instancePath+"/namespace",parentData:data,parentDataProperty:"namespace",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1584.errors : vErrors.concat(validate1584.errors);
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
if(!(validate1587(data.name, {instancePath:instancePath+"/name",parentData:data,parentDataProperty:"name",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1587.errors : vErrors.concat(validate1587.errors);
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
if(!(validate1651(data.interpretation, {instancePath:instancePath+"/interpretation",parentData:data,parentDataProperty:"interpretation",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1651.errors : vErrors.concat(validate1651.errors);
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
validate1645.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
return false;
}
}
validate1645.errors = vErrors;
return errors === 0;
}
validate1645.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema450 = {"type":"object","additionalProperties":false,"properties":{"partition":{"$ref":"#/$defs/RelationalResponse/$defs/T12"},"next_lsn":{"$ref":"#/$defs/RelationalResponse/$defs/T12"}},"required":["partition","next_lsn"]};

function validate1670(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1670.evaluated;
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
validate1670.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "partition") || (key0 === "next_lsn"))){
validate1670.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.partition !== undefined){
const _errs2 = errors;
if(!(validate1587(data.partition, {instancePath:instancePath+"/partition",parentData:data,parentDataProperty:"partition",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1587.errors : vErrors.concat(validate1587.errors);
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
if(!(validate1587(data.next_lsn, {instancePath:instancePath+"/next_lsn",parentData:data,parentDataProperty:"next_lsn",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1587.errors : vErrors.concat(validate1587.errors);
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
validate1670.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
return false;
}
}
validate1670.errors = vErrors;
return errors === 0;
}
validate1670.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate1643(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1643.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((((data.alias === undefined) && (missing0 = "alias")) || ((data.binding === undefined) && (missing0 = "binding"))) || ((data.position === undefined) && (missing0 = "position"))){
validate1643.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "alias") || (key0 === "binding")) || (key0 === "position"))){
validate1643.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.alias !== undefined){
const _errs2 = errors;
if(!(validate1587(data.alias, {instancePath:instancePath+"/alias",parentData:data,parentDataProperty:"alias",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1587.errors : vErrors.concat(validate1587.errors);
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
if(!(validate1645(data.binding, {instancePath:instancePath+"/binding",parentData:data,parentDataProperty:"binding",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1645.errors : vErrors.concat(validate1645.errors);
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
if(!(validate1670(data.position, {instancePath:instancePath+"/position",parentData:data,parentDataProperty:"position",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1670.errors : vErrors.concat(validate1670.errors);
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
validate1643.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
return false;
}
}
validate1643.errors = vErrors;
return errors === 0;
}
validate1643.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate1642(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1642.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(Array.isArray(data)){
if(data.length > 2){
validate1642.errors = [{instancePath,schemaPath:"#/maxItems",keyword:"maxItems",params:{limit: 2}}];
return false;
}
else {
var valid0 = true;
const len0 = data.length;
for(let i0=0; i0<len0; i0++){
const _errs1 = errors;
if(!(validate1643(data[i0], {instancePath:instancePath+"/" + i0,parentData:data,parentDataProperty:i0,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1643.errors : vErrors.concat(validate1643.errors);
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
validate1642.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "array"}}];
return false;
}
}
validate1642.errors = vErrors;
return errors === 0;
}
validate1642.evaluated = {"items":true,"dynamicProps":false,"dynamicItems":false};

const schema451 = {"type":"array","maxItems":128,"items":{"$ref":"#/$defs/RelationalResponse/$defs/T37"}};
const schema452 = {"type":"object","additionalProperties":false,"properties":{"name":{"$ref":"#/$defs/RelationalResponse/$defs/T24"},"type":{"$ref":"#/$defs/RelationalResponse/$defs/T38"},"nullable":{"$ref":"#/$defs/RelationalResponse/$defs/T5"},"optional":{"$ref":"#/$defs/RelationalResponse/$defs/T5"}},"required":["name","type","nullable","optional"]};
const schema453 = {"oneOf":[{"type":"object","additionalProperties":false,"required":["int64"],"properties":{"int64":{"$ref":"#/$defs/RelationalResponse/$defs/T39"}}},{"type":"object","additionalProperties":false,"required":["uint64"],"properties":{"uint64":{"$ref":"#/$defs/RelationalResponse/$defs/T39"}}},{"type":"object","additionalProperties":false,"required":["float64"],"properties":{"float64":{"$ref":"#/$defs/RelationalResponse/$defs/T39"}}},{"type":"object","additionalProperties":false,"required":["boolean"],"properties":{"boolean":{"$ref":"#/$defs/RelationalResponse/$defs/T39"}}},{"type":"object","additionalProperties":false,"required":["utf8"],"properties":{"utf8":{"$ref":"#/$defs/RelationalResponse/$defs/T39"}}},{"type":"object","additionalProperties":false,"required":["binary"],"properties":{"binary":{"$ref":"#/$defs/RelationalResponse/$defs/T39"}}},{"type":"object","additionalProperties":false,"required":["int8"],"properties":{"int8":{"$ref":"#/$defs/RelationalResponse/$defs/T39"}}},{"type":"object","additionalProperties":false,"required":["int16"],"properties":{"int16":{"$ref":"#/$defs/RelationalResponse/$defs/T39"}}},{"type":"object","additionalProperties":false,"required":["int32"],"properties":{"int32":{"$ref":"#/$defs/RelationalResponse/$defs/T39"}}},{"type":"object","additionalProperties":false,"required":["int128"],"properties":{"int128":{"$ref":"#/$defs/RelationalResponse/$defs/T39"}}},{"type":"object","additionalProperties":false,"required":["uint8"],"properties":{"uint8":{"$ref":"#/$defs/RelationalResponse/$defs/T39"}}},{"type":"object","additionalProperties":false,"required":["uint16"],"properties":{"uint16":{"$ref":"#/$defs/RelationalResponse/$defs/T39"}}},{"type":"object","additionalProperties":false,"required":["uint32"],"properties":{"uint32":{"$ref":"#/$defs/RelationalResponse/$defs/T39"}}},{"type":"object","additionalProperties":false,"required":["uint128"],"properties":{"uint128":{"$ref":"#/$defs/RelationalResponse/$defs/T39"}}},{"type":"object","additionalProperties":false,"required":["float32"],"properties":{"float32":{"$ref":"#/$defs/RelationalResponse/$defs/T39"}}},{"type":"object","additionalProperties":false,"required":["decimal"],"properties":{"decimal":{"$ref":"#/$defs/RelationalResponse/$defs/T40"}}},{"type":"object","additionalProperties":false,"required":["date"],"properties":{"date":{"$ref":"#/$defs/RelationalResponse/$defs/T39"}}},{"type":"object","additionalProperties":false,"required":["time"],"properties":{"time":{"$ref":"#/$defs/RelationalResponse/$defs/T39"}}},{"type":"object","additionalProperties":false,"required":["timestamp"],"properties":{"timestamp":{"$ref":"#/$defs/RelationalResponse/$defs/T41"}}},{"type":"object","additionalProperties":false,"required":["interval"],"properties":{"interval":{"$ref":"#/$defs/RelationalResponse/$defs/T39"}}},{"type":"object","additionalProperties":false,"required":["uuid"],"properties":{"uuid":{"$ref":"#/$defs/RelationalResponse/$defs/T39"}}},{"type":"object","additionalProperties":false,"required":["structure"],"properties":{"structure":{"$ref":"#/$defs/RelationalResponse/$defs/T42"}}},{"type":"object","additionalProperties":false,"required":["list"],"properties":{"list":{"$ref":"#/$defs/RelationalResponse/$defs/T56"}}},{"type":"object","additionalProperties":false,"required":["array"],"properties":{"array":{"$ref":"#/$defs/RelationalResponse/$defs/T58"}}},{"type":"object","additionalProperties":false,"required":["map"],"properties":{"map":{"$ref":"#/$defs/RelationalResponse/$defs/T60"}}},{"type":"object","additionalProperties":false,"required":["tagged_union"],"properties":{"tagged_union":{"$ref":"#/$defs/RelationalResponse/$defs/T42"}}},{"type":"object","additionalProperties":false,"required":["json"],"properties":{"json":{"$ref":"#/$defs/RelationalResponse/$defs/T39"}}}]};
const schema454 = {"type":"object","maxProperties":0};

function validate1680(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1680.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
if(Object.keys(data).length > 0){
validate1680.errors = [{instancePath,schemaPath:"#/maxProperties",keyword:"maxProperties",params:{limit: 0}}];
return false;
}
}
else {
validate1680.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
return false;
}
}
validate1680.errors = vErrors;
return errors === 0;
}
validate1680.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema455 = {"type":"object","additionalProperties":false,"properties":{"precision":{"$ref":"#/$defs/RelationalResponse/$defs/T4"},"scale":{"$ref":"#/$defs/RelationalResponse/$defs/T4"}},"required":["precision","scale"]};

function validate1696(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1696.evaluated;
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
validate1696.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "precision") || (key0 === "scale"))){
validate1696.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.precision !== undefined){
const _errs2 = errors;
if(!(validate1569(data.precision, {instancePath:instancePath+"/precision",parentData:data,parentDataProperty:"precision",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1569.errors : vErrors.concat(validate1569.errors);
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
if(!(validate1569(data.scale, {instancePath:instancePath+"/scale",parentData:data,parentDataProperty:"scale",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1569.errors : vErrors.concat(validate1569.errors);
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
validate1696.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
return false;
}
}
validate1696.errors = vErrors;
return errors === 0;
}
validate1696.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema177 = {"type":"string","enum":["civil","utc"]};

function validate1702(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1702.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate1702.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"}}];
return false;
}
if(!((data === "civil") || (data === "utc"))){
validate1702.errors = [{instancePath,schemaPath:"#/enum",keyword:"enum",params:{allowedValues: schema177.enum}}];
return false;
}
validate1702.errors = vErrors;
return errors === 0;
}
validate1702.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema457 = {"type":"array","maxItems":256,"items":{"$ref":"#/$defs/RelationalResponse/$defs/T43"}};
const schema458 = {"type":"object","additionalProperties":false,"properties":{"name":{"$ref":"#/$defs/RelationalResponse/$defs/T44"},"type":{"$ref":"#/$defs/RelationalResponse/$defs/T45"},"nullable":{"$ref":"#/$defs/RelationalResponse/$defs/T52"},"optional":{"$ref":"#/$defs/RelationalResponse/$defs/T52"}},"required":["name","type","nullable","optional"]};
const schema459 = {"type":"string","maxLength":4096};

function validate1708(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1708.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(typeof data === "string"){
if(func4(data) > 4096){
validate1708.errors = [{instancePath,schemaPath:"#/maxLength",keyword:"maxLength",params:{limit: 4096}}];
return false;
}
}
else {
validate1708.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"}}];
return false;
}
}
validate1708.errors = vErrors;
return errors === 0;
}
validate1708.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema460 = {"oneOf":[{"type":"object","additionalProperties":false,"required":["int64"],"properties":{"int64":{"$ref":"#/$defs/RelationalResponse/$defs/T46"}}},{"type":"object","additionalProperties":false,"required":["uint64"],"properties":{"uint64":{"$ref":"#/$defs/RelationalResponse/$defs/T46"}}},{"type":"object","additionalProperties":false,"required":["float64"],"properties":{"float64":{"$ref":"#/$defs/RelationalResponse/$defs/T46"}}},{"type":"object","additionalProperties":false,"required":["boolean"],"properties":{"boolean":{"$ref":"#/$defs/RelationalResponse/$defs/T46"}}},{"type":"object","additionalProperties":false,"required":["utf8"],"properties":{"utf8":{"$ref":"#/$defs/RelationalResponse/$defs/T46"}}},{"type":"object","additionalProperties":false,"required":["binary"],"properties":{"binary":{"$ref":"#/$defs/RelationalResponse/$defs/T46"}}},{"type":"object","additionalProperties":false,"required":["int8"],"properties":{"int8":{"$ref":"#/$defs/RelationalResponse/$defs/T46"}}},{"type":"object","additionalProperties":false,"required":["int16"],"properties":{"int16":{"$ref":"#/$defs/RelationalResponse/$defs/T46"}}},{"type":"object","additionalProperties":false,"required":["int32"],"properties":{"int32":{"$ref":"#/$defs/RelationalResponse/$defs/T46"}}},{"type":"object","additionalProperties":false,"required":["int128"],"properties":{"int128":{"$ref":"#/$defs/RelationalResponse/$defs/T46"}}},{"type":"object","additionalProperties":false,"required":["uint8"],"properties":{"uint8":{"$ref":"#/$defs/RelationalResponse/$defs/T46"}}},{"type":"object","additionalProperties":false,"required":["uint16"],"properties":{"uint16":{"$ref":"#/$defs/RelationalResponse/$defs/T46"}}},{"type":"object","additionalProperties":false,"required":["uint32"],"properties":{"uint32":{"$ref":"#/$defs/RelationalResponse/$defs/T46"}}},{"type":"object","additionalProperties":false,"required":["uint128"],"properties":{"uint128":{"$ref":"#/$defs/RelationalResponse/$defs/T46"}}},{"type":"object","additionalProperties":false,"required":["float32"],"properties":{"float32":{"$ref":"#/$defs/RelationalResponse/$defs/T46"}}},{"type":"object","additionalProperties":false,"required":["decimal"],"properties":{"decimal":{"$ref":"#/$defs/RelationalResponse/$defs/T47"}}},{"type":"object","additionalProperties":false,"required":["date"],"properties":{"date":{"$ref":"#/$defs/RelationalResponse/$defs/T46"}}},{"type":"object","additionalProperties":false,"required":["time"],"properties":{"time":{"$ref":"#/$defs/RelationalResponse/$defs/T46"}}},{"type":"object","additionalProperties":false,"required":["timestamp"],"properties":{"timestamp":{"$ref":"#/$defs/RelationalResponse/$defs/T49"}}},{"type":"object","additionalProperties":false,"required":["interval"],"properties":{"interval":{"$ref":"#/$defs/RelationalResponse/$defs/T46"}}},{"type":"object","additionalProperties":false,"required":["uuid"],"properties":{"uuid":{"$ref":"#/$defs/RelationalResponse/$defs/T46"}}},{"type":"object","additionalProperties":false,"required":["structure"],"properties":{"structure":{"$ref":"#/$defs/RelationalResponse/$defs/T42"}}},{"type":"object","additionalProperties":false,"required":["list"],"properties":{"list":{"$ref":"#/$defs/RelationalResponse/$defs/T50"}}},{"type":"object","additionalProperties":false,"required":["array"],"properties":{"array":{"$ref":"#/$defs/RelationalResponse/$defs/T53"}}},{"type":"object","additionalProperties":false,"required":["map"],"properties":{"map":{"$ref":"#/$defs/RelationalResponse/$defs/T55"}}},{"type":"object","additionalProperties":false,"required":["tagged_union"],"properties":{"tagged_union":{"$ref":"#/$defs/RelationalResponse/$defs/T42"}}},{"type":"object","additionalProperties":false,"required":["json"],"properties":{"json":{"$ref":"#/$defs/RelationalResponse/$defs/T46"}}}]};
const schema461 = {"type":"object","maxProperties":0};

function validate1711(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1711.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
if(Object.keys(data).length > 0){
validate1711.errors = [{instancePath,schemaPath:"#/maxProperties",keyword:"maxProperties",params:{limit: 0}}];
return false;
}
}
else {
validate1711.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
return false;
}
}
validate1711.errors = vErrors;
return errors === 0;
}
validate1711.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema462 = {"type":"object","additionalProperties":false,"properties":{"precision":{"$ref":"#/$defs/RelationalResponse/$defs/T48"},"scale":{"$ref":"#/$defs/RelationalResponse/$defs/T48"}},"required":["precision","scale"]};

function validate1728(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1728.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(!(((typeof data == "number") && (!(data % 1) && !isNaN(data))) && (isFinite(data)))){
validate1728.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "integer"}}];
return false;
}
if(errors === 0){
if((typeof data == "number") && (isFinite(data))){
if(data > 255 || isNaN(data)){
validate1728.errors = [{instancePath,schemaPath:"#/maximum",keyword:"maximum",params:{comparison: "<=", limit: 255}}];
return false;
}
else {
if(data < 0 || isNaN(data)){
validate1728.errors = [{instancePath,schemaPath:"#/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0}}];
return false;
}
}
}
}
validate1728.errors = vErrors;
return errors === 0;
}
validate1728.evaluated = {"dynamicProps":false,"dynamicItems":false};


function validate1727(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1727.evaluated;
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
validate1727.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "precision") || (key0 === "scale"))){
validate1727.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.precision !== undefined){
const _errs2 = errors;
if(!(validate1728(data.precision, {instancePath:instancePath+"/precision",parentData:data,parentDataProperty:"precision",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1728.errors : vErrors.concat(validate1728.errors);
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
if(!(validate1728(data.scale, {instancePath:instancePath+"/scale",parentData:data,parentDataProperty:"scale",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1728.errors : vErrors.concat(validate1728.errors);
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
validate1727.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
return false;
}
}
validate1727.errors = vErrors;
return errors === 0;
}
validate1727.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate1734(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1734.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate1734.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"}}];
return false;
}
if(!((data === "civil") || (data === "utc"))){
validate1734.errors = [{instancePath,schemaPath:"#/enum",keyword:"enum",params:{allowedValues: schema177.enum}}];
return false;
}
validate1734.errors = vErrors;
return errors === 0;
}
validate1734.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema465 = {"type":"object","additionalProperties":false,"properties":{"type":{"$ref":"#/$defs/RelationalResponse/$defs/T51"},"nullable":{"$ref":"#/$defs/RelationalResponse/$defs/T52"}},"required":["type","nullable"]};
const wrapper15 = {validate: validate1710};
const schema466 = {"type":"boolean"};

function validate1739(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1739.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "boolean"){
validate1739.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "boolean"}}];
return false;
}
validate1739.errors = vErrors;
return errors === 0;
}
validate1739.evaluated = {"dynamicProps":false,"dynamicItems":false};


function validate1738(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1738.evaluated;
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
validate1738.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "type") || (key0 === "nullable"))){
validate1738.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.type !== undefined){
const _errs2 = errors;
if(!(wrapper15.validate(data.type, {instancePath:instancePath+"/type",parentData:data,parentDataProperty:"type",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? wrapper15.validate.errors : vErrors.concat(wrapper15.validate.errors);
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
if(!(validate1739(data.nullable, {instancePath:instancePath+"/nullable",parentData:data,parentDataProperty:"nullable",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1739.errors : vErrors.concat(validate1739.errors);
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
validate1738.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
return false;
}
}
validate1738.errors = vErrors;
return errors === 0;
}
validate1738.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema467 = {"type":"object","additionalProperties":false,"properties":{"element":{"$ref":"#/$defs/RelationalResponse/$defs/T50"},"length":{"$ref":"#/$defs/RelationalResponse/$defs/T54"}},"required":["element","length"]};
const schema21 = {"type":"integer","minimum":0,"maximum":4294967295};

function validate1744(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1744.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(!(((typeof data == "number") && (!(data % 1) && !isNaN(data))) && (isFinite(data)))){
validate1744.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "integer"}}];
return false;
}
if(errors === 0){
if((typeof data == "number") && (isFinite(data))){
if(data > 4294967295 || isNaN(data)){
validate1744.errors = [{instancePath,schemaPath:"#/maximum",keyword:"maximum",params:{comparison: "<=", limit: 4294967295}}];
return false;
}
else {
if(data < 0 || isNaN(data)){
validate1744.errors = [{instancePath,schemaPath:"#/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0}}];
return false;
}
}
}
}
validate1744.errors = vErrors;
return errors === 0;
}
validate1744.evaluated = {"dynamicProps":false,"dynamicItems":false};


function validate1742(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1742.evaluated;
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
validate1742.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "element") || (key0 === "length"))){
validate1742.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.element !== undefined){
const _errs2 = errors;
if(!(validate1738(data.element, {instancePath:instancePath+"/element",parentData:data,parentDataProperty:"element",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1738.errors : vErrors.concat(validate1738.errors);
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
if(!(validate1744(data.length, {instancePath:instancePath+"/length",parentData:data,parentDataProperty:"length",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1744.errors : vErrors.concat(validate1744.errors);
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
validate1742.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
return false;
}
}
validate1742.errors = vErrors;
return errors === 0;
}
validate1742.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema469 = {"type":"object","additionalProperties":false,"properties":{"key":{"$ref":"#/$defs/RelationalResponse/$defs/T51"},"value":{"$ref":"#/$defs/RelationalResponse/$defs/T50"}},"required":["key","value"]};

function validate1747(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1747.evaluated;
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
validate1747.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "key") || (key0 === "value"))){
validate1747.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.key !== undefined){
const _errs2 = errors;
if(!(wrapper15.validate(data.key, {instancePath:instancePath+"/key",parentData:data,parentDataProperty:"key",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? wrapper15.validate.errors : vErrors.concat(wrapper15.validate.errors);
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
if(!(validate1738(data.value, {instancePath:instancePath+"/value",parentData:data,parentDataProperty:"value",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1738.errors : vErrors.concat(validate1738.errors);
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
validate1747.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
return false;
}
}
validate1747.errors = vErrors;
return errors === 0;
}
validate1747.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const wrapper14 = {validate: validate1706};

function validate1710(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1710.evaluated;
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
const err0 = {instancePath,schemaPath:"#/oneOf/0/required",keyword:"required",params:{missingProperty: missing0}};
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
const err1 = {instancePath,schemaPath:"#/oneOf/0/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}};
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
if(!(validate1711(data.int64, {instancePath:instancePath+"/int64",parentData:data,parentDataProperty:"int64",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1711.errors : vErrors.concat(validate1711.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err2 = {instancePath,schemaPath:"#/oneOf/0/type",keyword:"type",params:{type: "object"}};
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
const err3 = {instancePath,schemaPath:"#/oneOf/1/required",keyword:"required",params:{missingProperty: missing1}};
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
const err4 = {instancePath,schemaPath:"#/oneOf/1/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key1}};
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
if(!(validate1711(data.uint64, {instancePath:instancePath+"/uint64",parentData:data,parentDataProperty:"uint64",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1711.errors : vErrors.concat(validate1711.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err5 = {instancePath,schemaPath:"#/oneOf/1/type",keyword:"type",params:{type: "object"}};
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
const err6 = {instancePath,schemaPath:"#/oneOf/2/required",keyword:"required",params:{missingProperty: missing2}};
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
const err7 = {instancePath,schemaPath:"#/oneOf/2/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key2}};
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
if(!(validate1711(data.float64, {instancePath:instancePath+"/float64",parentData:data,parentDataProperty:"float64",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1711.errors : vErrors.concat(validate1711.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err8 = {instancePath,schemaPath:"#/oneOf/2/type",keyword:"type",params:{type: "object"}};
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
const err9 = {instancePath,schemaPath:"#/oneOf/3/required",keyword:"required",params:{missingProperty: missing3}};
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
const err10 = {instancePath,schemaPath:"#/oneOf/3/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key3}};
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
if(!(validate1711(data.boolean, {instancePath:instancePath+"/boolean",parentData:data,parentDataProperty:"boolean",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1711.errors : vErrors.concat(validate1711.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err11 = {instancePath,schemaPath:"#/oneOf/3/type",keyword:"type",params:{type: "object"}};
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
const err12 = {instancePath,schemaPath:"#/oneOf/4/required",keyword:"required",params:{missingProperty: missing4}};
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
const err13 = {instancePath,schemaPath:"#/oneOf/4/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key4}};
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
if(!(validate1711(data.utf8, {instancePath:instancePath+"/utf8",parentData:data,parentDataProperty:"utf8",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1711.errors : vErrors.concat(validate1711.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err14 = {instancePath,schemaPath:"#/oneOf/4/type",keyword:"type",params:{type: "object"}};
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
const err15 = {instancePath,schemaPath:"#/oneOf/5/required",keyword:"required",params:{missingProperty: missing5}};
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
const err16 = {instancePath,schemaPath:"#/oneOf/5/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key5}};
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
if(!(validate1711(data.binary, {instancePath:instancePath+"/binary",parentData:data,parentDataProperty:"binary",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1711.errors : vErrors.concat(validate1711.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err17 = {instancePath,schemaPath:"#/oneOf/5/type",keyword:"type",params:{type: "object"}};
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
const err18 = {instancePath,schemaPath:"#/oneOf/6/required",keyword:"required",params:{missingProperty: missing6}};
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
const err19 = {instancePath,schemaPath:"#/oneOf/6/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key6}};
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
if(!(validate1711(data.int8, {instancePath:instancePath+"/int8",parentData:data,parentDataProperty:"int8",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1711.errors : vErrors.concat(validate1711.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err20 = {instancePath,schemaPath:"#/oneOf/6/type",keyword:"type",params:{type: "object"}};
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
const err21 = {instancePath,schemaPath:"#/oneOf/7/required",keyword:"required",params:{missingProperty: missing7}};
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
const err22 = {instancePath,schemaPath:"#/oneOf/7/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key7}};
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
if(!(validate1711(data.int16, {instancePath:instancePath+"/int16",parentData:data,parentDataProperty:"int16",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1711.errors : vErrors.concat(validate1711.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err23 = {instancePath,schemaPath:"#/oneOf/7/type",keyword:"type",params:{type: "object"}};
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
const err24 = {instancePath,schemaPath:"#/oneOf/8/required",keyword:"required",params:{missingProperty: missing8}};
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
const err25 = {instancePath,schemaPath:"#/oneOf/8/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key8}};
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
if(!(validate1711(data.int32, {instancePath:instancePath+"/int32",parentData:data,parentDataProperty:"int32",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1711.errors : vErrors.concat(validate1711.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err26 = {instancePath,schemaPath:"#/oneOf/8/type",keyword:"type",params:{type: "object"}};
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
const err27 = {instancePath,schemaPath:"#/oneOf/9/required",keyword:"required",params:{missingProperty: missing9}};
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
const err28 = {instancePath,schemaPath:"#/oneOf/9/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key9}};
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
if(!(validate1711(data.int128, {instancePath:instancePath+"/int128",parentData:data,parentDataProperty:"int128",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1711.errors : vErrors.concat(validate1711.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err29 = {instancePath,schemaPath:"#/oneOf/9/type",keyword:"type",params:{type: "object"}};
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
const err30 = {instancePath,schemaPath:"#/oneOf/10/required",keyword:"required",params:{missingProperty: missing10}};
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
const err31 = {instancePath,schemaPath:"#/oneOf/10/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key10}};
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
if(!(validate1711(data.uint8, {instancePath:instancePath+"/uint8",parentData:data,parentDataProperty:"uint8",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1711.errors : vErrors.concat(validate1711.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err32 = {instancePath,schemaPath:"#/oneOf/10/type",keyword:"type",params:{type: "object"}};
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
const err33 = {instancePath,schemaPath:"#/oneOf/11/required",keyword:"required",params:{missingProperty: missing11}};
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
const err34 = {instancePath,schemaPath:"#/oneOf/11/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key11}};
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
if(!(validate1711(data.uint16, {instancePath:instancePath+"/uint16",parentData:data,parentDataProperty:"uint16",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1711.errors : vErrors.concat(validate1711.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err35 = {instancePath,schemaPath:"#/oneOf/11/type",keyword:"type",params:{type: "object"}};
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
const err36 = {instancePath,schemaPath:"#/oneOf/12/required",keyword:"required",params:{missingProperty: missing12}};
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
const err37 = {instancePath,schemaPath:"#/oneOf/12/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key12}};
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
if(!(validate1711(data.uint32, {instancePath:instancePath+"/uint32",parentData:data,parentDataProperty:"uint32",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1711.errors : vErrors.concat(validate1711.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err38 = {instancePath,schemaPath:"#/oneOf/12/type",keyword:"type",params:{type: "object"}};
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
const err39 = {instancePath,schemaPath:"#/oneOf/13/required",keyword:"required",params:{missingProperty: missing13}};
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
const err40 = {instancePath,schemaPath:"#/oneOf/13/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key13}};
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
if(!(validate1711(data.uint128, {instancePath:instancePath+"/uint128",parentData:data,parentDataProperty:"uint128",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1711.errors : vErrors.concat(validate1711.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err41 = {instancePath,schemaPath:"#/oneOf/13/type",keyword:"type",params:{type: "object"}};
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
const err42 = {instancePath,schemaPath:"#/oneOf/14/required",keyword:"required",params:{missingProperty: missing14}};
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
const err43 = {instancePath,schemaPath:"#/oneOf/14/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key14}};
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
if(!(validate1711(data.float32, {instancePath:instancePath+"/float32",parentData:data,parentDataProperty:"float32",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1711.errors : vErrors.concat(validate1711.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err44 = {instancePath,schemaPath:"#/oneOf/14/type",keyword:"type",params:{type: "object"}};
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
const err45 = {instancePath,schemaPath:"#/oneOf/15/required",keyword:"required",params:{missingProperty: missing15}};
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
const err46 = {instancePath,schemaPath:"#/oneOf/15/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key15}};
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
if(!(validate1727(data.decimal, {instancePath:instancePath+"/decimal",parentData:data,parentDataProperty:"decimal",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1727.errors : vErrors.concat(validate1727.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err47 = {instancePath,schemaPath:"#/oneOf/15/type",keyword:"type",params:{type: "object"}};
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
const err48 = {instancePath,schemaPath:"#/oneOf/16/required",keyword:"required",params:{missingProperty: missing16}};
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
const err49 = {instancePath,schemaPath:"#/oneOf/16/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key16}};
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
if(!(validate1711(data.date, {instancePath:instancePath+"/date",parentData:data,parentDataProperty:"date",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1711.errors : vErrors.concat(validate1711.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err50 = {instancePath,schemaPath:"#/oneOf/16/type",keyword:"type",params:{type: "object"}};
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
const err51 = {instancePath,schemaPath:"#/oneOf/17/required",keyword:"required",params:{missingProperty: missing17}};
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
const err52 = {instancePath,schemaPath:"#/oneOf/17/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key17}};
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
if(!(validate1711(data.time, {instancePath:instancePath+"/time",parentData:data,parentDataProperty:"time",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1711.errors : vErrors.concat(validate1711.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err53 = {instancePath,schemaPath:"#/oneOf/17/type",keyword:"type",params:{type: "object"}};
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
const err54 = {instancePath,schemaPath:"#/oneOf/18/required",keyword:"required",params:{missingProperty: missing18}};
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
const err55 = {instancePath,schemaPath:"#/oneOf/18/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key18}};
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
if(!(validate1734(data.timestamp, {instancePath:instancePath+"/timestamp",parentData:data,parentDataProperty:"timestamp",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1734.errors : vErrors.concat(validate1734.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err56 = {instancePath,schemaPath:"#/oneOf/18/type",keyword:"type",params:{type: "object"}};
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
const err57 = {instancePath,schemaPath:"#/oneOf/19/required",keyword:"required",params:{missingProperty: missing19}};
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
const err58 = {instancePath,schemaPath:"#/oneOf/19/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key19}};
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
if(!(validate1711(data.interval, {instancePath:instancePath+"/interval",parentData:data,parentDataProperty:"interval",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1711.errors : vErrors.concat(validate1711.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err59 = {instancePath,schemaPath:"#/oneOf/19/type",keyword:"type",params:{type: "object"}};
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
const err60 = {instancePath,schemaPath:"#/oneOf/20/required",keyword:"required",params:{missingProperty: missing20}};
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
const err61 = {instancePath,schemaPath:"#/oneOf/20/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key20}};
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
if(!(validate1711(data.uuid, {instancePath:instancePath+"/uuid",parentData:data,parentDataProperty:"uuid",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1711.errors : vErrors.concat(validate1711.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err62 = {instancePath,schemaPath:"#/oneOf/20/type",keyword:"type",params:{type: "object"}};
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
const err63 = {instancePath,schemaPath:"#/oneOf/21/required",keyword:"required",params:{missingProperty: missing21}};
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
const err64 = {instancePath,schemaPath:"#/oneOf/21/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key21}};
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
if(!(wrapper14.validate(data.structure, {instancePath:instancePath+"/structure",parentData:data,parentDataProperty:"structure",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? wrapper14.validate.errors : vErrors.concat(wrapper14.validate.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err65 = {instancePath,schemaPath:"#/oneOf/21/type",keyword:"type",params:{type: "object"}};
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
const err66 = {instancePath,schemaPath:"#/oneOf/22/required",keyword:"required",params:{missingProperty: missing22}};
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
const err67 = {instancePath,schemaPath:"#/oneOf/22/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key22}};
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
if(!(validate1738(data.list, {instancePath:instancePath+"/list",parentData:data,parentDataProperty:"list",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1738.errors : vErrors.concat(validate1738.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err68 = {instancePath,schemaPath:"#/oneOf/22/type",keyword:"type",params:{type: "object"}};
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
const err69 = {instancePath,schemaPath:"#/oneOf/23/required",keyword:"required",params:{missingProperty: missing23}};
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
const err70 = {instancePath,schemaPath:"#/oneOf/23/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key23}};
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
if(!(validate1742(data.array, {instancePath:instancePath+"/array",parentData:data,parentDataProperty:"array",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1742.errors : vErrors.concat(validate1742.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err71 = {instancePath,schemaPath:"#/oneOf/23/type",keyword:"type",params:{type: "object"}};
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
const err72 = {instancePath,schemaPath:"#/oneOf/24/required",keyword:"required",params:{missingProperty: missing24}};
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
const err73 = {instancePath,schemaPath:"#/oneOf/24/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key24}};
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
if(!(validate1747(data.map, {instancePath:instancePath+"/map",parentData:data,parentDataProperty:"map",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1747.errors : vErrors.concat(validate1747.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err74 = {instancePath,schemaPath:"#/oneOf/24/type",keyword:"type",params:{type: "object"}};
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
const err75 = {instancePath,schemaPath:"#/oneOf/25/required",keyword:"required",params:{missingProperty: missing25}};
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
const err76 = {instancePath,schemaPath:"#/oneOf/25/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key25}};
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
if(!(wrapper14.validate(data.tagged_union, {instancePath:instancePath+"/tagged_union",parentData:data,parentDataProperty:"tagged_union",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? wrapper14.validate.errors : vErrors.concat(wrapper14.validate.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err77 = {instancePath,schemaPath:"#/oneOf/25/type",keyword:"type",params:{type: "object"}};
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
const err78 = {instancePath,schemaPath:"#/oneOf/26/required",keyword:"required",params:{missingProperty: missing26}};
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
const err79 = {instancePath,schemaPath:"#/oneOf/26/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key26}};
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
if(!(validate1711(data.json, {instancePath:instancePath+"/json",parentData:data,parentDataProperty:"json",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1711.errors : vErrors.concat(validate1711.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err80 = {instancePath,schemaPath:"#/oneOf/26/type",keyword:"type",params:{type: "object"}};
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
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
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
const err81 = {instancePath,schemaPath:"#/oneOf",keyword:"oneOf",params:{passingSchemas: passing0}};
if(vErrors === null){
vErrors = [err81];
}
else {
vErrors.push(err81);
}
errors++;
validate1710.errors = vErrors;
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
validate1710.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate1710.evaluated = {"dynamicProps":true,"dynamicItems":false};


function validate1707(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1707.evaluated;
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
validate1707.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((((key0 === "name") || (key0 === "type")) || (key0 === "nullable")) || (key0 === "optional"))){
validate1707.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.name !== undefined){
const _errs2 = errors;
if(!(validate1708(data.name, {instancePath:instancePath+"/name",parentData:data,parentDataProperty:"name",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1708.errors : vErrors.concat(validate1708.errors);
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
if(!(validate1710(data.type, {instancePath:instancePath+"/type",parentData:data,parentDataProperty:"type",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1710.errors : vErrors.concat(validate1710.errors);
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
if(!(validate1739(data.nullable, {instancePath:instancePath+"/nullable",parentData:data,parentDataProperty:"nullable",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1739.errors : vErrors.concat(validate1739.errors);
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
if(!(validate1739(data.optional, {instancePath:instancePath+"/optional",parentData:data,parentDataProperty:"optional",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1739.errors : vErrors.concat(validate1739.errors);
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
validate1707.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
return false;
}
}
validate1707.errors = vErrors;
return errors === 0;
}
validate1707.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate1706(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1706.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(Array.isArray(data)){
if(data.length > 256){
validate1706.errors = [{instancePath,schemaPath:"#/maxItems",keyword:"maxItems",params:{limit: 256}}];
return false;
}
else {
var valid0 = true;
const len0 = data.length;
for(let i0=0; i0<len0; i0++){
const _errs1 = errors;
if(!(validate1707(data[i0], {instancePath:instancePath+"/" + i0,parentData:data,parentDataProperty:i0,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1707.errors : vErrors.concat(validate1707.errors);
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
validate1706.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "array"}}];
return false;
}
}
validate1706.errors = vErrors;
return errors === 0;
}
validate1706.evaluated = {"items":true,"dynamicProps":false,"dynamicItems":false};

const schema470 = {"type":"object","additionalProperties":false,"properties":{"type":{"$ref":"#/$defs/RelationalResponse/$defs/T57"},"nullable":{"$ref":"#/$defs/RelationalResponse/$defs/T5"}},"required":["type","nullable"]};
const wrapper18 = {validate: validate1679};

function validate1756(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1756.evaluated;
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
validate1756.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "type") || (key0 === "nullable"))){
validate1756.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.type !== undefined){
const _errs2 = errors;
if(!(wrapper18.validate(data.type, {instancePath:instancePath+"/type",parentData:data,parentDataProperty:"type",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? wrapper18.validate.errors : vErrors.concat(wrapper18.validate.errors);
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
if(!(validate1573(data.nullable, {instancePath:instancePath+"/nullable",parentData:data,parentDataProperty:"nullable",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1573.errors : vErrors.concat(validate1573.errors);
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
validate1756.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
return false;
}
}
validate1756.errors = vErrors;
return errors === 0;
}
validate1756.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema471 = {"type":"object","additionalProperties":false,"properties":{"element":{"$ref":"#/$defs/RelationalResponse/$defs/T56"},"length":{"$ref":"#/$defs/RelationalResponse/$defs/T59"}},"required":["element","length"]};

function validate1761(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1761.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(!(((typeof data == "number") && (!(data % 1) && !isNaN(data))) && (isFinite(data)))){
validate1761.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "integer"}}];
return false;
}
if(errors === 0){
if((typeof data == "number") && (isFinite(data))){
if(data > 4294967295 || isNaN(data)){
validate1761.errors = [{instancePath,schemaPath:"#/maximum",keyword:"maximum",params:{comparison: "<=", limit: 4294967295}}];
return false;
}
else {
if(data < 0 || isNaN(data)){
validate1761.errors = [{instancePath,schemaPath:"#/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0}}];
return false;
}
}
}
}
validate1761.errors = vErrors;
return errors === 0;
}
validate1761.evaluated = {"dynamicProps":false,"dynamicItems":false};


function validate1759(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1759.evaluated;
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
validate1759.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "element") || (key0 === "length"))){
validate1759.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.element !== undefined){
const _errs2 = errors;
if(!(validate1756(data.element, {instancePath:instancePath+"/element",parentData:data,parentDataProperty:"element",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1756.errors : vErrors.concat(validate1756.errors);
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
if(!(validate1761(data.length, {instancePath:instancePath+"/length",parentData:data,parentDataProperty:"length",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1761.errors : vErrors.concat(validate1761.errors);
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
validate1759.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
return false;
}
}
validate1759.errors = vErrors;
return errors === 0;
}
validate1759.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema473 = {"type":"object","additionalProperties":false,"properties":{"key":{"$ref":"#/$defs/RelationalResponse/$defs/T57"},"value":{"$ref":"#/$defs/RelationalResponse/$defs/T56"}},"required":["key","value"]};

function validate1764(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1764.evaluated;
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
validate1764.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "key") || (key0 === "value"))){
validate1764.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.key !== undefined){
const _errs2 = errors;
if(!(wrapper18.validate(data.key, {instancePath:instancePath+"/key",parentData:data,parentDataProperty:"key",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? wrapper18.validate.errors : vErrors.concat(wrapper18.validate.errors);
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
if(!(validate1756(data.value, {instancePath:instancePath+"/value",parentData:data,parentDataProperty:"value",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1756.errors : vErrors.concat(validate1756.errors);
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
validate1764.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
return false;
}
}
validate1764.errors = vErrors;
return errors === 0;
}
validate1764.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate1679(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1679.evaluated;
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
const err0 = {instancePath,schemaPath:"#/oneOf/0/required",keyword:"required",params:{missingProperty: missing0}};
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
const err1 = {instancePath,schemaPath:"#/oneOf/0/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}};
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
if(!(validate1680(data.int64, {instancePath:instancePath+"/int64",parentData:data,parentDataProperty:"int64",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1680.errors : vErrors.concat(validate1680.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err2 = {instancePath,schemaPath:"#/oneOf/0/type",keyword:"type",params:{type: "object"}};
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
const err3 = {instancePath,schemaPath:"#/oneOf/1/required",keyword:"required",params:{missingProperty: missing1}};
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
const err4 = {instancePath,schemaPath:"#/oneOf/1/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key1}};
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
if(!(validate1680(data.uint64, {instancePath:instancePath+"/uint64",parentData:data,parentDataProperty:"uint64",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1680.errors : vErrors.concat(validate1680.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err5 = {instancePath,schemaPath:"#/oneOf/1/type",keyword:"type",params:{type: "object"}};
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
const err6 = {instancePath,schemaPath:"#/oneOf/2/required",keyword:"required",params:{missingProperty: missing2}};
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
const err7 = {instancePath,schemaPath:"#/oneOf/2/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key2}};
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
if(!(validate1680(data.float64, {instancePath:instancePath+"/float64",parentData:data,parentDataProperty:"float64",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1680.errors : vErrors.concat(validate1680.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err8 = {instancePath,schemaPath:"#/oneOf/2/type",keyword:"type",params:{type: "object"}};
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
const err9 = {instancePath,schemaPath:"#/oneOf/3/required",keyword:"required",params:{missingProperty: missing3}};
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
const err10 = {instancePath,schemaPath:"#/oneOf/3/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key3}};
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
if(!(validate1680(data.boolean, {instancePath:instancePath+"/boolean",parentData:data,parentDataProperty:"boolean",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1680.errors : vErrors.concat(validate1680.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err11 = {instancePath,schemaPath:"#/oneOf/3/type",keyword:"type",params:{type: "object"}};
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
const err12 = {instancePath,schemaPath:"#/oneOf/4/required",keyword:"required",params:{missingProperty: missing4}};
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
const err13 = {instancePath,schemaPath:"#/oneOf/4/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key4}};
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
if(!(validate1680(data.utf8, {instancePath:instancePath+"/utf8",parentData:data,parentDataProperty:"utf8",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1680.errors : vErrors.concat(validate1680.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err14 = {instancePath,schemaPath:"#/oneOf/4/type",keyword:"type",params:{type: "object"}};
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
const err15 = {instancePath,schemaPath:"#/oneOf/5/required",keyword:"required",params:{missingProperty: missing5}};
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
const err16 = {instancePath,schemaPath:"#/oneOf/5/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key5}};
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
if(!(validate1680(data.binary, {instancePath:instancePath+"/binary",parentData:data,parentDataProperty:"binary",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1680.errors : vErrors.concat(validate1680.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err17 = {instancePath,schemaPath:"#/oneOf/5/type",keyword:"type",params:{type: "object"}};
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
const err18 = {instancePath,schemaPath:"#/oneOf/6/required",keyword:"required",params:{missingProperty: missing6}};
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
const err19 = {instancePath,schemaPath:"#/oneOf/6/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key6}};
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
if(!(validate1680(data.int8, {instancePath:instancePath+"/int8",parentData:data,parentDataProperty:"int8",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1680.errors : vErrors.concat(validate1680.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err20 = {instancePath,schemaPath:"#/oneOf/6/type",keyword:"type",params:{type: "object"}};
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
const err21 = {instancePath,schemaPath:"#/oneOf/7/required",keyword:"required",params:{missingProperty: missing7}};
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
const err22 = {instancePath,schemaPath:"#/oneOf/7/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key7}};
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
if(!(validate1680(data.int16, {instancePath:instancePath+"/int16",parentData:data,parentDataProperty:"int16",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1680.errors : vErrors.concat(validate1680.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err23 = {instancePath,schemaPath:"#/oneOf/7/type",keyword:"type",params:{type: "object"}};
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
const err24 = {instancePath,schemaPath:"#/oneOf/8/required",keyword:"required",params:{missingProperty: missing8}};
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
const err25 = {instancePath,schemaPath:"#/oneOf/8/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key8}};
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
if(!(validate1680(data.int32, {instancePath:instancePath+"/int32",parentData:data,parentDataProperty:"int32",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1680.errors : vErrors.concat(validate1680.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err26 = {instancePath,schemaPath:"#/oneOf/8/type",keyword:"type",params:{type: "object"}};
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
const err27 = {instancePath,schemaPath:"#/oneOf/9/required",keyword:"required",params:{missingProperty: missing9}};
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
const err28 = {instancePath,schemaPath:"#/oneOf/9/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key9}};
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
if(!(validate1680(data.int128, {instancePath:instancePath+"/int128",parentData:data,parentDataProperty:"int128",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1680.errors : vErrors.concat(validate1680.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err29 = {instancePath,schemaPath:"#/oneOf/9/type",keyword:"type",params:{type: "object"}};
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
const err30 = {instancePath,schemaPath:"#/oneOf/10/required",keyword:"required",params:{missingProperty: missing10}};
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
const err31 = {instancePath,schemaPath:"#/oneOf/10/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key10}};
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
if(!(validate1680(data.uint8, {instancePath:instancePath+"/uint8",parentData:data,parentDataProperty:"uint8",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1680.errors : vErrors.concat(validate1680.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err32 = {instancePath,schemaPath:"#/oneOf/10/type",keyword:"type",params:{type: "object"}};
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
const err33 = {instancePath,schemaPath:"#/oneOf/11/required",keyword:"required",params:{missingProperty: missing11}};
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
const err34 = {instancePath,schemaPath:"#/oneOf/11/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key11}};
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
if(!(validate1680(data.uint16, {instancePath:instancePath+"/uint16",parentData:data,parentDataProperty:"uint16",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1680.errors : vErrors.concat(validate1680.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err35 = {instancePath,schemaPath:"#/oneOf/11/type",keyword:"type",params:{type: "object"}};
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
const err36 = {instancePath,schemaPath:"#/oneOf/12/required",keyword:"required",params:{missingProperty: missing12}};
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
const err37 = {instancePath,schemaPath:"#/oneOf/12/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key12}};
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
if(!(validate1680(data.uint32, {instancePath:instancePath+"/uint32",parentData:data,parentDataProperty:"uint32",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1680.errors : vErrors.concat(validate1680.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err38 = {instancePath,schemaPath:"#/oneOf/12/type",keyword:"type",params:{type: "object"}};
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
const err39 = {instancePath,schemaPath:"#/oneOf/13/required",keyword:"required",params:{missingProperty: missing13}};
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
const err40 = {instancePath,schemaPath:"#/oneOf/13/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key13}};
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
if(!(validate1680(data.uint128, {instancePath:instancePath+"/uint128",parentData:data,parentDataProperty:"uint128",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1680.errors : vErrors.concat(validate1680.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err41 = {instancePath,schemaPath:"#/oneOf/13/type",keyword:"type",params:{type: "object"}};
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
const err42 = {instancePath,schemaPath:"#/oneOf/14/required",keyword:"required",params:{missingProperty: missing14}};
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
const err43 = {instancePath,schemaPath:"#/oneOf/14/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key14}};
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
if(!(validate1680(data.float32, {instancePath:instancePath+"/float32",parentData:data,parentDataProperty:"float32",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1680.errors : vErrors.concat(validate1680.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err44 = {instancePath,schemaPath:"#/oneOf/14/type",keyword:"type",params:{type: "object"}};
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
const err45 = {instancePath,schemaPath:"#/oneOf/15/required",keyword:"required",params:{missingProperty: missing15}};
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
const err46 = {instancePath,schemaPath:"#/oneOf/15/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key15}};
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
if(!(validate1696(data.decimal, {instancePath:instancePath+"/decimal",parentData:data,parentDataProperty:"decimal",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1696.errors : vErrors.concat(validate1696.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err47 = {instancePath,schemaPath:"#/oneOf/15/type",keyword:"type",params:{type: "object"}};
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
const err48 = {instancePath,schemaPath:"#/oneOf/16/required",keyword:"required",params:{missingProperty: missing16}};
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
const err49 = {instancePath,schemaPath:"#/oneOf/16/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key16}};
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
if(!(validate1680(data.date, {instancePath:instancePath+"/date",parentData:data,parentDataProperty:"date",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1680.errors : vErrors.concat(validate1680.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err50 = {instancePath,schemaPath:"#/oneOf/16/type",keyword:"type",params:{type: "object"}};
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
const err51 = {instancePath,schemaPath:"#/oneOf/17/required",keyword:"required",params:{missingProperty: missing17}};
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
const err52 = {instancePath,schemaPath:"#/oneOf/17/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key17}};
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
if(!(validate1680(data.time, {instancePath:instancePath+"/time",parentData:data,parentDataProperty:"time",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1680.errors : vErrors.concat(validate1680.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err53 = {instancePath,schemaPath:"#/oneOf/17/type",keyword:"type",params:{type: "object"}};
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
const err54 = {instancePath,schemaPath:"#/oneOf/18/required",keyword:"required",params:{missingProperty: missing18}};
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
const err55 = {instancePath,schemaPath:"#/oneOf/18/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key18}};
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
if(!(validate1702(data.timestamp, {instancePath:instancePath+"/timestamp",parentData:data,parentDataProperty:"timestamp",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1702.errors : vErrors.concat(validate1702.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err56 = {instancePath,schemaPath:"#/oneOf/18/type",keyword:"type",params:{type: "object"}};
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
const err57 = {instancePath,schemaPath:"#/oneOf/19/required",keyword:"required",params:{missingProperty: missing19}};
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
const err58 = {instancePath,schemaPath:"#/oneOf/19/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key19}};
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
if(!(validate1680(data.interval, {instancePath:instancePath+"/interval",parentData:data,parentDataProperty:"interval",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1680.errors : vErrors.concat(validate1680.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err59 = {instancePath,schemaPath:"#/oneOf/19/type",keyword:"type",params:{type: "object"}};
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
const err60 = {instancePath,schemaPath:"#/oneOf/20/required",keyword:"required",params:{missingProperty: missing20}};
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
const err61 = {instancePath,schemaPath:"#/oneOf/20/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key20}};
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
if(!(validate1680(data.uuid, {instancePath:instancePath+"/uuid",parentData:data,parentDataProperty:"uuid",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1680.errors : vErrors.concat(validate1680.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err62 = {instancePath,schemaPath:"#/oneOf/20/type",keyword:"type",params:{type: "object"}};
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
const err63 = {instancePath,schemaPath:"#/oneOf/21/required",keyword:"required",params:{missingProperty: missing21}};
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
const err64 = {instancePath,schemaPath:"#/oneOf/21/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key21}};
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
if(!(validate1706(data.structure, {instancePath:instancePath+"/structure",parentData:data,parentDataProperty:"structure",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1706.errors : vErrors.concat(validate1706.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err65 = {instancePath,schemaPath:"#/oneOf/21/type",keyword:"type",params:{type: "object"}};
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
const err66 = {instancePath,schemaPath:"#/oneOf/22/required",keyword:"required",params:{missingProperty: missing22}};
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
const err67 = {instancePath,schemaPath:"#/oneOf/22/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key22}};
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
if(!(validate1756(data.list, {instancePath:instancePath+"/list",parentData:data,parentDataProperty:"list",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1756.errors : vErrors.concat(validate1756.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err68 = {instancePath,schemaPath:"#/oneOf/22/type",keyword:"type",params:{type: "object"}};
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
const err69 = {instancePath,schemaPath:"#/oneOf/23/required",keyword:"required",params:{missingProperty: missing23}};
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
const err70 = {instancePath,schemaPath:"#/oneOf/23/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key23}};
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
if(!(validate1759(data.array, {instancePath:instancePath+"/array",parentData:data,parentDataProperty:"array",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1759.errors : vErrors.concat(validate1759.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err71 = {instancePath,schemaPath:"#/oneOf/23/type",keyword:"type",params:{type: "object"}};
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
const err72 = {instancePath,schemaPath:"#/oneOf/24/required",keyword:"required",params:{missingProperty: missing24}};
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
const err73 = {instancePath,schemaPath:"#/oneOf/24/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key24}};
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
if(!(validate1764(data.map, {instancePath:instancePath+"/map",parentData:data,parentDataProperty:"map",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1764.errors : vErrors.concat(validate1764.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err74 = {instancePath,schemaPath:"#/oneOf/24/type",keyword:"type",params:{type: "object"}};
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
const err75 = {instancePath,schemaPath:"#/oneOf/25/required",keyword:"required",params:{missingProperty: missing25}};
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
const err76 = {instancePath,schemaPath:"#/oneOf/25/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key25}};
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
if(!(validate1706(data.tagged_union, {instancePath:instancePath+"/tagged_union",parentData:data,parentDataProperty:"tagged_union",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1706.errors : vErrors.concat(validate1706.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err77 = {instancePath,schemaPath:"#/oneOf/25/type",keyword:"type",params:{type: "object"}};
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
const err78 = {instancePath,schemaPath:"#/oneOf/26/required",keyword:"required",params:{missingProperty: missing26}};
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
const err79 = {instancePath,schemaPath:"#/oneOf/26/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key26}};
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
if(!(validate1680(data.json, {instancePath:instancePath+"/json",parentData:data,parentDataProperty:"json",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1680.errors : vErrors.concat(validate1680.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err80 = {instancePath,schemaPath:"#/oneOf/26/type",keyword:"type",params:{type: "object"}};
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
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
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
const err81 = {instancePath,schemaPath:"#/oneOf",keyword:"oneOf",params:{passingSchemas: passing0}};
if(vErrors === null){
vErrors = [err81];
}
else {
vErrors.push(err81);
}
errors++;
validate1679.errors = vErrors;
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
validate1679.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate1679.evaluated = {"dynamicProps":true,"dynamicItems":false};


function validate1677(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1677.evaluated;
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
validate1677.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((((key0 === "name") || (key0 === "type")) || (key0 === "nullable")) || (key0 === "optional"))){
validate1677.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.name !== undefined){
const _errs2 = errors;
if(!(validate1634(data.name, {instancePath:instancePath+"/name",parentData:data,parentDataProperty:"name",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1634.errors : vErrors.concat(validate1634.errors);
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
if(!(validate1679(data.type, {instancePath:instancePath+"/type",parentData:data,parentDataProperty:"type",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1679.errors : vErrors.concat(validate1679.errors);
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
if(!(validate1573(data.nullable, {instancePath:instancePath+"/nullable",parentData:data,parentDataProperty:"nullable",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1573.errors : vErrors.concat(validate1573.errors);
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
if(!(validate1573(data.optional, {instancePath:instancePath+"/optional",parentData:data,parentDataProperty:"optional",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1573.errors : vErrors.concat(validate1573.errors);
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
validate1677.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
return false;
}
}
validate1677.errors = vErrors;
return errors === 0;
}
validate1677.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate1676(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1676.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(Array.isArray(data)){
if(data.length > 128){
validate1676.errors = [{instancePath,schemaPath:"#/maxItems",keyword:"maxItems",params:{limit: 128}}];
return false;
}
else {
var valid0 = true;
const len0 = data.length;
for(let i0=0; i0<len0; i0++){
const _errs1 = errors;
if(!(validate1677(data[i0], {instancePath:instancePath+"/" + i0,parentData:data,parentDataProperty:i0,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1677.errors : vErrors.concat(validate1677.errors);
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
validate1676.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "array"}}];
return false;
}
}
validate1676.errors = vErrors;
return errors === 0;
}
validate1676.evaluated = {"items":true,"dynamicProps":false,"dynamicItems":false};

const schema474 = {"anyOf":[{"$ref":"#/$defs/RelationalResponse/$defs/T62"},{"type":"null"}]};
const schema475 = {"type":"string","enum":["inner","left"]};

function validate1775(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1775.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate1775.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"}}];
return false;
}
if(!((data === "inner") || (data === "left"))){
validate1775.errors = [{instancePath,schemaPath:"#/enum",keyword:"enum",params:{allowedValues: schema475.enum}}];
return false;
}
validate1775.errors = vErrors;
return errors === 0;
}
validate1775.evaluated = {"dynamicProps":false,"dynamicItems":false};


function validate1774(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1774.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate1775(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1775.errors : vErrors.concat(validate1775.errors);
errors = vErrors.length;
}
var _valid0 = _errs1 === errors;
valid0 = valid0 || _valid0;
const _errs2 = errors;
if(data !== null){
const err0 = {instancePath,schemaPath:"#/anyOf/1/type",keyword:"type",params:{type: "null"}};
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
const err1 = {instancePath,schemaPath:"#/anyOf",keyword:"anyOf",params:{}};
if(vErrors === null){
vErrors = [err1];
}
else {
vErrors.push(err1);
}
errors++;
validate1774.errors = vErrors;
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
validate1774.errors = vErrors;
return errors === 0;
}
validate1774.evaluated = {"dynamicProps":false,"dynamicItems":false};


function validate1639(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1639.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((((((((data.definition === undefined) && (missing0 = "definition")) || ((data.plan === undefined) && (missing0 = "plan"))) || ((data.sources === undefined) && (missing0 = "sources"))) || ((data.columns === undefined) && (missing0 = "columns"))) || ((data.join === undefined) && (missing0 = "join"))) || ((data.grouped === undefined) && (missing0 = "grouped"))) || ((data.executed === undefined) && (missing0 = "executed"))){
validate1639.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((((((key0 === "definition") || (key0 === "plan")) || (key0 === "sources")) || (key0 === "columns")) || (key0 === "join")) || (key0 === "grouped")) || (key0 === "executed"))){
validate1639.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.definition !== undefined){
const _errs2 = errors;
if(!(validate1567(data.definition, {instancePath:instancePath+"/definition",parentData:data,parentDataProperty:"definition",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1567.errors : vErrors.concat(validate1567.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.plan !== undefined){
const _errs3 = errors;
if(!(validate1634(data.plan, {instancePath:instancePath+"/plan",parentData:data,parentDataProperty:"plan",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1634.errors : vErrors.concat(validate1634.errors);
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
if(!(validate1642(data.sources, {instancePath:instancePath+"/sources",parentData:data,parentDataProperty:"sources",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1642.errors : vErrors.concat(validate1642.errors);
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
if(!(validate1676(data.columns, {instancePath:instancePath+"/columns",parentData:data,parentDataProperty:"columns",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1676.errors : vErrors.concat(validate1676.errors);
errors = vErrors.length;
}
var valid0 = _errs5 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.join !== undefined){
const _errs6 = errors;
if(!(validate1774(data.join, {instancePath:instancePath+"/join",parentData:data,parentDataProperty:"join",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1774.errors : vErrors.concat(validate1774.errors);
errors = vErrors.length;
}
var valid0 = _errs6 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.grouped !== undefined){
const _errs7 = errors;
if(!(validate1573(data.grouped, {instancePath:instancePath+"/grouped",parentData:data,parentDataProperty:"grouped",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1573.errors : vErrors.concat(validate1573.errors);
errors = vErrors.length;
}
var valid0 = _errs7 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.executed !== undefined){
const _errs8 = errors;
if(!(validate1573(data.executed, {instancePath:instancePath+"/executed",parentData:data,parentDataProperty:"executed",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1573.errors : vErrors.concat(validate1573.errors);
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
validate1639.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
return false;
}
}
validate1639.errors = vErrors;
return errors === 0;
}
validate1639.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema476 = {"type":"array","maxItems":2,"items":{"$ref":"#/$defs/RelationalResponse/$defs/T64"}};
const schema477 = {"type":"object","additionalProperties":false,"properties":{"object":{"$ref":"#/$defs/RelationalResponse/$defs/T32"},"position":{"$ref":"#/$defs/RelationalResponse/$defs/T35"},"commitment":{"$ref":"#/$defs/RelationalResponse/$defs/T12"},"schema":{"$ref":"#/$defs/RelationalResponse/$defs/T12"}},"required":["object","position","commitment","schema"]};

function validate1782(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1782.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if(((((data.object === undefined) && (missing0 = "object")) || ((data.position === undefined) && (missing0 = "position"))) || ((data.commitment === undefined) && (missing0 = "commitment"))) || ((data.schema === undefined) && (missing0 = "schema"))){
validate1782.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((((key0 === "object") || (key0 === "position")) || (key0 === "commitment")) || (key0 === "schema"))){
validate1782.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.object !== undefined){
const _errs2 = errors;
if(!(validate1653(data.object, {instancePath:instancePath+"/object",parentData:data,parentDataProperty:"object",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1653.errors : vErrors.concat(validate1653.errors);
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
if(!(validate1670(data.position, {instancePath:instancePath+"/position",parentData:data,parentDataProperty:"position",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1670.errors : vErrors.concat(validate1670.errors);
errors = vErrors.length;
}
var valid0 = _errs3 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.commitment !== undefined){
const _errs4 = errors;
if(!(validate1587(data.commitment, {instancePath:instancePath+"/commitment",parentData:data,parentDataProperty:"commitment",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1587.errors : vErrors.concat(validate1587.errors);
errors = vErrors.length;
}
var valid0 = _errs4 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.schema !== undefined){
const _errs5 = errors;
if(!(validate1587(data.schema, {instancePath:instancePath+"/schema",parentData:data,parentDataProperty:"schema",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1587.errors : vErrors.concat(validate1587.errors);
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
validate1782.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
return false;
}
}
validate1782.errors = vErrors;
return errors === 0;
}
validate1782.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate1781(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1781.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(Array.isArray(data)){
if(data.length > 2){
validate1781.errors = [{instancePath,schemaPath:"#/maxItems",keyword:"maxItems",params:{limit: 2}}];
return false;
}
else {
var valid0 = true;
const len0 = data.length;
for(let i0=0; i0<len0; i0++){
const _errs1 = errors;
if(!(validate1782(data[i0], {instancePath:instancePath+"/" + i0,parentData:data,parentDataProperty:i0,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1782.errors : vErrors.concat(validate1782.errors);
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
validate1781.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "array"}}];
return false;
}
}
validate1781.errors = vErrors;
return errors === 0;
}
validate1781.evaluated = {"items":true,"dynamicProps":false,"dynamicItems":false};


function validate1631(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1631.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if(((((data.reference === undefined) && (missing0 = "reference")) || ((data.description === undefined) && (missing0 = "description"))) || ((data.cuts === undefined) && (missing0 = "cuts"))) || ((data.complete_coverage === undefined) && (missing0 = "complete_coverage"))){
validate1631.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((((key0 === "reference") || (key0 === "description")) || (key0 === "cuts")) || (key0 === "complete_coverage"))){
validate1631.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.reference !== undefined){
const _errs2 = errors;
if(!(validate1632(data.reference, {instancePath:instancePath+"/reference",parentData:data,parentDataProperty:"reference",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1632.errors : vErrors.concat(validate1632.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.description !== undefined){
const _errs3 = errors;
if(!(validate1639(data.description, {instancePath:instancePath+"/description",parentData:data,parentDataProperty:"description",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1639.errors : vErrors.concat(validate1639.errors);
errors = vErrors.length;
}
var valid0 = _errs3 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.cuts !== undefined){
const _errs4 = errors;
if(!(validate1781(data.cuts, {instancePath:instancePath+"/cuts",parentData:data,parentDataProperty:"cuts",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1781.errors : vErrors.concat(validate1781.errors);
errors = vErrors.length;
}
var valid0 = _errs4 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.complete_coverage !== undefined){
const _errs5 = errors;
if(!(validate1573(data.complete_coverage, {instancePath:instancePath+"/complete_coverage",parentData:data,parentDataProperty:"complete_coverage",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1573.errors : vErrors.concat(validate1573.errors);
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
validate1631.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
return false;
}
}
validate1631.errors = vErrors;
return errors === 0;
}
validate1631.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate1630(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1630.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((((data.opened === undefined) && (missing0 = "opened")) || ((data.ordinal === undefined) && (missing0 = "ordinal"))) || ((data.read === undefined) && (missing0 = "read"))){
validate1630.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "opened") || (key0 === "ordinal")) || (key0 === "read"))){
validate1630.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.opened !== undefined){
const _errs2 = errors;
if(!(validate1631(data.opened, {instancePath:instancePath+"/opened",parentData:data,parentDataProperty:"opened",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1631.errors : vErrors.concat(validate1631.errors);
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
if(!(validate1634(data.ordinal, {instancePath:instancePath+"/ordinal",parentData:data,parentDataProperty:"ordinal",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1634.errors : vErrors.concat(validate1634.errors);
errors = vErrors.length;
}
var valid0 = _errs3 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.read !== undefined){
const _errs4 = errors;
if(!(validate1573(data.read, {instancePath:instancePath+"/read",parentData:data,parentDataProperty:"read",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1573.errors : vErrors.concat(validate1573.errors);
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
validate1630.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
return false;
}
}
validate1630.errors = vErrors;
return errors === 0;
}
validate1630.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate1629(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1629.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate1630(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1630.errors : vErrors.concat(validate1630.errors);
errors = vErrors.length;
}
var _valid0 = _errs1 === errors;
valid0 = valid0 || _valid0;
if(_valid0){
var props0 = true;
}
const _errs2 = errors;
if(data !== null){
const err0 = {instancePath,schemaPath:"#/anyOf/1/type",keyword:"type",params:{type: "null"}};
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
const err1 = {instancePath,schemaPath:"#/anyOf",keyword:"anyOf",params:{}};
if(vErrors === null){
vErrors = [err1];
}
else {
vErrors.push(err1);
}
errors++;
validate1629.errors = vErrors;
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
validate1629.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate1629.evaluated = {"dynamicProps":true,"dynamicItems":false};

const schema478 = {"anyOf":[{"$ref":"#/$defs/RelationalResponse/$defs/T66"},{"type":"null"}]};
const schema479 = {"type":"object","additionalProperties":false,"properties":{"id":{"$ref":"#/$defs/RelationalResponse/$defs/T24"},"state":{"$ref":"#/$defs/RelationalResponse/$defs/T67"},"remaining_pins":{"$ref":"#/$defs/RelationalResponse/$defs/T4"}},"required":["id","state","remaining_pins"]};
const schema480 = {"type":"string","enum":["acquiring","active","closing"]};

function validate1798(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1798.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate1798.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"}}];
return false;
}
if(!(((data === "acquiring") || (data === "active")) || (data === "closing"))){
validate1798.errors = [{instancePath,schemaPath:"#/enum",keyword:"enum",params:{allowedValues: schema480.enum}}];
return false;
}
validate1798.errors = vErrors;
return errors === 0;
}
validate1798.evaluated = {"dynamicProps":false,"dynamicItems":false};


function validate1796(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1796.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((((data.id === undefined) && (missing0 = "id")) || ((data.state === undefined) && (missing0 = "state"))) || ((data.remaining_pins === undefined) && (missing0 = "remaining_pins"))){
validate1796.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "id") || (key0 === "state")) || (key0 === "remaining_pins"))){
validate1796.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.id !== undefined){
const _errs2 = errors;
if(!(validate1634(data.id, {instancePath:instancePath+"/id",parentData:data,parentDataProperty:"id",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1634.errors : vErrors.concat(validate1634.errors);
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
if(!(validate1798(data.state, {instancePath:instancePath+"/state",parentData:data,parentDataProperty:"state",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1798.errors : vErrors.concat(validate1798.errors);
errors = vErrors.length;
}
var valid0 = _errs3 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.remaining_pins !== undefined){
const _errs4 = errors;
if(!(validate1569(data.remaining_pins, {instancePath:instancePath+"/remaining_pins",parentData:data,parentDataProperty:"remaining_pins",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1569.errors : vErrors.concat(validate1569.errors);
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
validate1796.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
return false;
}
}
validate1796.errors = vErrors;
return errors === 0;
}
validate1796.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate1795(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1795.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate1796(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1796.errors : vErrors.concat(validate1796.errors);
errors = vErrors.length;
}
var _valid0 = _errs1 === errors;
valid0 = valid0 || _valid0;
if(_valid0){
var props0 = true;
}
const _errs2 = errors;
if(data !== null){
const err0 = {instancePath,schemaPath:"#/anyOf/1/type",keyword:"type",params:{type: "null"}};
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
const err1 = {instancePath,schemaPath:"#/anyOf",keyword:"anyOf",params:{}};
if(vErrors === null){
vErrors = [err1];
}
else {
vErrors.push(err1);
}
errors++;
validate1795.errors = vErrors;
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
validate1795.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate1795.evaluated = {"dynamicProps":true,"dynamicItems":false};


function validate1565(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1565.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if(((((data.capabilities === undefined) && (missing0 = "capabilities")) || ((data.routes === undefined) && (missing0 = "routes"))) || ((data.active === undefined) && (missing0 = "active"))) || ((data.recovery === undefined) && (missing0 = "recovery"))){
validate1565.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((((key0 === "capabilities") || (key0 === "routes")) || (key0 === "active")) || (key0 === "recovery"))){
validate1565.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.capabilities !== undefined){
const _errs2 = errors;
if(!(validate1566(data.capabilities, {instancePath:instancePath+"/capabilities",parentData:data,parentDataProperty:"capabilities",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1566.errors : vErrors.concat(validate1566.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.routes !== undefined){
const _errs3 = errors;
if(!(validate1580(data.routes, {instancePath:instancePath+"/routes",parentData:data,parentDataProperty:"routes",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1580.errors : vErrors.concat(validate1580.errors);
errors = vErrors.length;
}
var valid0 = _errs3 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.active !== undefined){
const _errs4 = errors;
if(!(validate1629(data.active, {instancePath:instancePath+"/active",parentData:data,parentDataProperty:"active",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1629.errors : vErrors.concat(validate1629.errors);
errors = vErrors.length;
}
var valid0 = _errs4 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.recovery !== undefined){
const _errs5 = errors;
if(!(validate1795(data.recovery, {instancePath:instancePath+"/recovery",parentData:data,parentDataProperty:"recovery",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1795.errors : vErrors.concat(validate1795.errors);
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
validate1565.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
return false;
}
}
validate1565.errors = vErrors;
return errors === 0;
}
validate1565.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema481 = {"type":"object","additionalProperties":false,"properties":{"binding":{"$ref":"#/$defs/RelationalResponse/$defs/T69"},"observed":{"$ref":"#/$defs/RelationalResponse/$defs/T78"}},"required":["binding","observed"]};
const schema482 = {"type":"object","additionalProperties":false,"properties":{"definition":{"$ref":"#/$defs/RelationalResponse/$defs/T3"},"connection":{"$ref":"#/$defs/RelationalResponse/$defs/T70"},"namespace":{"$ref":"#/$defs/RelationalResponse/$defs/T72"},"name":{"$ref":"#/$defs/RelationalResponse/$defs/T24"},"interpretation":{"$ref":"#/$defs/RelationalResponse/$defs/T74"}},"required":["definition","connection","namespace","name","interpretation"]};
const schema483 = {"type":"object","additionalProperties":false,"properties":{"scope":{"$ref":"#/$defs/RelationalResponse/$defs/T71"},"branch":{"$ref":"#/$defs/RelationalResponse/$defs/T24"},"audience":{"$ref":"#/$defs/RelationalResponse/$defs/T72"},"principal":{"$ref":"#/$defs/RelationalResponse/$defs/T72"},"role":{"$ref":"#/$defs/RelationalResponse/$defs/T73"}},"required":["scope","branch","audience","principal","role"]};
const schema484 = {"type":"object","additionalProperties":false,"properties":{"realm":{"$ref":"#/$defs/RelationalResponse/$defs/T72"},"resource":{"$ref":"#/$defs/RelationalResponse/$defs/T72"},"catalog":{"$ref":"#/$defs/RelationalResponse/$defs/T24"}},"required":["realm","resource","catalog"]};

function validate1809(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1809.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(!(((typeof data == "number") && (!(data % 1) && !isNaN(data))) && (isFinite(data)))){
validate1809.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "integer"}}];
return false;
}
if(errors === 0){
if((typeof data == "number") && (isFinite(data))){
if(data > 9007199254740991 || isNaN(data)){
validate1809.errors = [{instancePath,schemaPath:"#/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991}}];
return false;
}
else {
if(data < 0 || isNaN(data)){
validate1809.errors = [{instancePath,schemaPath:"#/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0}}];
return false;
}
}
}
}
validate1809.errors = vErrors;
return errors === 0;
}
validate1809.evaluated = {"dynamicProps":false,"dynamicItems":false};


function validate1808(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1808.evaluated;
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
validate1808.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "realm") || (key0 === "resource")) || (key0 === "catalog"))){
validate1808.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.realm !== undefined){
const _errs2 = errors;
if(!(validate1809(data.realm, {instancePath:instancePath+"/realm",parentData:data,parentDataProperty:"realm",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1809.errors : vErrors.concat(validate1809.errors);
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
if(!(validate1809(data.resource, {instancePath:instancePath+"/resource",parentData:data,parentDataProperty:"resource",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1809.errors : vErrors.concat(validate1809.errors);
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
if(!(validate1634(data.catalog, {instancePath:instancePath+"/catalog",parentData:data,parentDataProperty:"catalog",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1634.errors : vErrors.concat(validate1634.errors);
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
validate1808.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
return false;
}
}
validate1808.errors = vErrors;
return errors === 0;
}
validate1808.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema486 = {"anyOf":[{"$ref":"#/$defs/RelationalResponse/$defs/T72"},{"type":"null"}]};

function validate1817(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1817.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate1809(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1809.errors : vErrors.concat(validate1809.errors);
errors = vErrors.length;
}
var _valid0 = _errs1 === errors;
valid0 = valid0 || _valid0;
const _errs2 = errors;
if(data !== null){
const err0 = {instancePath,schemaPath:"#/anyOf/1/type",keyword:"type",params:{type: "null"}};
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
const err1 = {instancePath,schemaPath:"#/anyOf",keyword:"anyOf",params:{}};
if(vErrors === null){
vErrors = [err1];
}
else {
vErrors.push(err1);
}
errors++;
validate1817.errors = vErrors;
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
validate1817.errors = vErrors;
return errors === 0;
}
validate1817.evaluated = {"dynamicProps":false,"dynamicItems":false};


function validate1807(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1807.evaluated;
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
validate1807.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((((key0 === "scope") || (key0 === "branch")) || (key0 === "audience")) || (key0 === "principal")) || (key0 === "role"))){
validate1807.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.scope !== undefined){
const _errs2 = errors;
if(!(validate1808(data.scope, {instancePath:instancePath+"/scope",parentData:data,parentDataProperty:"scope",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1808.errors : vErrors.concat(validate1808.errors);
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
if(!(validate1634(data.branch, {instancePath:instancePath+"/branch",parentData:data,parentDataProperty:"branch",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1634.errors : vErrors.concat(validate1634.errors);
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
if(!(validate1809(data.audience, {instancePath:instancePath+"/audience",parentData:data,parentDataProperty:"audience",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1809.errors : vErrors.concat(validate1809.errors);
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
if(!(validate1809(data.principal, {instancePath:instancePath+"/principal",parentData:data,parentDataProperty:"principal",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1809.errors : vErrors.concat(validate1809.errors);
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
if(!(validate1817(data.role, {instancePath:instancePath+"/role",parentData:data,parentDataProperty:"role",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1817.errors : vErrors.concat(validate1817.errors);
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
validate1807.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
return false;
}
}
validate1807.errors = vErrors;
return errors === 0;
}
validate1807.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema487 = {"type":"object","additionalProperties":false,"properties":{"interpretation":{"$ref":"#/$defs/RelationalResponse/$defs/T75"},"content":{"$ref":"#/$defs/RelationalResponse/$defs/T77"},"schema_fingerprint":{"$ref":"#/$defs/RelationalResponse/$defs/T24"},"retired":{"$ref":"#/$defs/RelationalResponse/$defs/T5"}},"required":["interpretation","content","schema_fingerprint","retired"]};
const schema488 = {"type":"object","additionalProperties":false,"properties":{"object":{"$ref":"#/$defs/RelationalResponse/$defs/T76"},"revision":{"$ref":"#/$defs/RelationalResponse/$defs/T24"},"digest":{"$ref":"#/$defs/RelationalResponse/$defs/T24"}},"required":["object","revision","digest"]};
const schema489 = {"type":"object","additionalProperties":false,"properties":{"scope":{"$ref":"#/$defs/RelationalResponse/$defs/T71"},"branch":{"$ref":"#/$defs/RelationalResponse/$defs/T24"},"object":{"$ref":"#/$defs/RelationalResponse/$defs/T24"}},"required":["scope","branch","object"]};

function validate1825(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1825.evaluated;
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
validate1825.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "scope") || (key0 === "branch")) || (key0 === "object"))){
validate1825.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.scope !== undefined){
const _errs2 = errors;
if(!(validate1808(data.scope, {instancePath:instancePath+"/scope",parentData:data,parentDataProperty:"scope",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1808.errors : vErrors.concat(validate1808.errors);
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
if(!(validate1634(data.branch, {instancePath:instancePath+"/branch",parentData:data,parentDataProperty:"branch",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1634.errors : vErrors.concat(validate1634.errors);
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
if(!(validate1634(data.object, {instancePath:instancePath+"/object",parentData:data,parentDataProperty:"object",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1634.errors : vErrors.concat(validate1634.errors);
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
validate1825.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
return false;
}
}
validate1825.errors = vErrors;
return errors === 0;
}
validate1825.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate1824(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1824.evaluated;
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
validate1824.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "object") || (key0 === "revision")) || (key0 === "digest"))){
validate1824.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.object !== undefined){
const _errs2 = errors;
if(!(validate1825(data.object, {instancePath:instancePath+"/object",parentData:data,parentDataProperty:"object",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1825.errors : vErrors.concat(validate1825.errors);
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
if(!(validate1634(data.revision, {instancePath:instancePath+"/revision",parentData:data,parentDataProperty:"revision",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1634.errors : vErrors.concat(validate1634.errors);
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
if(!(validate1634(data.digest, {instancePath:instancePath+"/digest",parentData:data,parentDataProperty:"digest",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1634.errors : vErrors.concat(validate1634.errors);
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
validate1824.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
return false;
}
}
validate1824.errors = vErrors;
return errors === 0;
}
validate1824.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema490 = {"type":"object","additionalProperties":false,"properties":{"bytes":{"$ref":"#/$defs/RelationalResponse/$defs/T24"},"sha256":{"$ref":"#/$defs/RelationalResponse/$defs/T24"}},"required":["bytes","sha256"]};

function validate1833(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1833.evaluated;
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
validate1833.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "bytes") || (key0 === "sha256"))){
validate1833.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.bytes !== undefined){
const _errs2 = errors;
if(!(validate1634(data.bytes, {instancePath:instancePath+"/bytes",parentData:data,parentDataProperty:"bytes",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1634.errors : vErrors.concat(validate1634.errors);
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
if(!(validate1634(data.sha256, {instancePath:instancePath+"/sha256",parentData:data,parentDataProperty:"sha256",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1634.errors : vErrors.concat(validate1634.errors);
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
validate1833.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
return false;
}
}
validate1833.errors = vErrors;
return errors === 0;
}
validate1833.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate1823(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1823.evaluated;
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
validate1823.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((((key0 === "interpretation") || (key0 === "content")) || (key0 === "schema_fingerprint")) || (key0 === "retired"))){
validate1823.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.interpretation !== undefined){
const _errs2 = errors;
if(!(validate1824(data.interpretation, {instancePath:instancePath+"/interpretation",parentData:data,parentDataProperty:"interpretation",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1824.errors : vErrors.concat(validate1824.errors);
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
if(!(validate1833(data.content, {instancePath:instancePath+"/content",parentData:data,parentDataProperty:"content",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1833.errors : vErrors.concat(validate1833.errors);
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
if(!(validate1634(data.schema_fingerprint, {instancePath:instancePath+"/schema_fingerprint",parentData:data,parentDataProperty:"schema_fingerprint",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1634.errors : vErrors.concat(validate1634.errors);
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
if(!(validate1573(data.retired, {instancePath:instancePath+"/retired",parentData:data,parentDataProperty:"retired",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1573.errors : vErrors.concat(validate1573.errors);
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
validate1823.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
return false;
}
}
validate1823.errors = vErrors;
return errors === 0;
}
validate1823.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate1805(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1805.evaluated;
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
validate1805.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((((key0 === "definition") || (key0 === "connection")) || (key0 === "namespace")) || (key0 === "name")) || (key0 === "interpretation"))){
validate1805.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.definition !== undefined){
const _errs2 = errors;
if(!(validate1567(data.definition, {instancePath:instancePath+"/definition",parentData:data,parentDataProperty:"definition",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1567.errors : vErrors.concat(validate1567.errors);
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
if(!(validate1807(data.connection, {instancePath:instancePath+"/connection",parentData:data,parentDataProperty:"connection",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1807.errors : vErrors.concat(validate1807.errors);
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
if(!(validate1809(data.namespace, {instancePath:instancePath+"/namespace",parentData:data,parentDataProperty:"namespace",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1809.errors : vErrors.concat(validate1809.errors);
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
if(!(validate1634(data.name, {instancePath:instancePath+"/name",parentData:data,parentDataProperty:"name",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1634.errors : vErrors.concat(validate1634.errors);
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
if(!(validate1823(data.interpretation, {instancePath:instancePath+"/interpretation",parentData:data,parentDataProperty:"interpretation",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1823.errors : vErrors.concat(validate1823.errors);
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
validate1805.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
return false;
}
}
validate1805.errors = vErrors;
return errors === 0;
}
validate1805.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema491 = {"type":"object","additionalProperties":false,"properties":{"position":{"$ref":"#/$defs/RelationalResponse/$defs/T79"},"changed_lsn":{"$ref":"#/$defs/RelationalResponse/$defs/T24"},"live_rows":{"$ref":"#/$defs/RelationalResponse/$defs/T24"},"pending_rows":{"$ref":"#/$defs/RelationalResponse/$defs/T24"},"pending_bytes":{"$ref":"#/$defs/RelationalResponse/$defs/T24"},"pending_complete":{"$ref":"#/$defs/RelationalResponse/$defs/T5"},"oldest_pending_lsn":{"$ref":"#/$defs/RelationalResponse/$defs/T80"},"archive_through":{"$ref":"#/$defs/RelationalResponse/$defs/T24"},"recovery_through":{"$ref":"#/$defs/RelationalResponse/$defs/T80"},"history_floor":{"$ref":"#/$defs/RelationalResponse/$defs/T24"},"next_segment":{"$ref":"#/$defs/RelationalResponse/$defs/T24"},"archive_source_lsn":{"$ref":"#/$defs/RelationalResponse/$defs/T24"},"archived_source_lsn":{"$ref":"#/$defs/RelationalResponse/$defs/T24"},"archive_target_source_lsn":{"$ref":"#/$defs/RelationalResponse/$defs/T80"},"archive_target_through_lsn":{"$ref":"#/$defs/RelationalResponse/$defs/T80"},"compaction_source_lsn":{"$ref":"#/$defs/RelationalResponse/$defs/T24"},"compacted_source_lsn":{"$ref":"#/$defs/RelationalResponse/$defs/T24"},"compaction_target_source_lsn":{"$ref":"#/$defs/RelationalResponse/$defs/T80"},"compaction_target_before_segment":{"$ref":"#/$defs/RelationalResponse/$defs/T80"},"compaction_target_after_segment":{"$ref":"#/$defs/RelationalResponse/$defs/T80"}},"required":["position","changed_lsn","live_rows","pending_rows","pending_bytes","pending_complete","oldest_pending_lsn","archive_through","recovery_through","history_floor","next_segment","archive_source_lsn","archived_source_lsn","archive_target_source_lsn","archive_target_through_lsn","compaction_source_lsn","compacted_source_lsn","compaction_target_source_lsn","compaction_target_before_segment","compaction_target_after_segment"]};
const func1 = Object.prototype.hasOwnProperty;
const schema492 = {"type":"object","additionalProperties":false,"properties":{"partition":{"$ref":"#/$defs/RelationalResponse/$defs/T24"},"next_lsn":{"$ref":"#/$defs/RelationalResponse/$defs/T24"}},"required":["partition","next_lsn"]};

function validate1842(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1842.evaluated;
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
validate1842.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "partition") || (key0 === "next_lsn"))){
validate1842.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.partition !== undefined){
const _errs2 = errors;
if(!(validate1634(data.partition, {instancePath:instancePath+"/partition",parentData:data,parentDataProperty:"partition",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1634.errors : vErrors.concat(validate1634.errors);
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
if(!(validate1634(data.next_lsn, {instancePath:instancePath+"/next_lsn",parentData:data,parentDataProperty:"next_lsn",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1634.errors : vErrors.concat(validate1634.errors);
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
validate1842.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
return false;
}
}
validate1842.errors = vErrors;
return errors === 0;
}
validate1842.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema493 = {"anyOf":[{"$ref":"#/$defs/RelationalResponse/$defs/T24"},{"type":"null"}]};

function validate1851(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1851.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate1634(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1634.errors : vErrors.concat(validate1634.errors);
errors = vErrors.length;
}
var _valid0 = _errs1 === errors;
valid0 = valid0 || _valid0;
const _errs2 = errors;
if(data !== null){
const err0 = {instancePath,schemaPath:"#/anyOf/1/type",keyword:"type",params:{type: "null"}};
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
const err1 = {instancePath,schemaPath:"#/anyOf",keyword:"anyOf",params:{}};
if(vErrors === null){
vErrors = [err1];
}
else {
vErrors.push(err1);
}
errors++;
validate1851.errors = vErrors;
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
validate1851.errors = vErrors;
return errors === 0;
}
validate1851.evaluated = {"dynamicProps":false,"dynamicItems":false};


function validate1841(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1841.evaluated;
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
validate1841.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(func1.call(schema491.properties, key0))){
validate1841.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.position !== undefined){
const _errs2 = errors;
if(!(validate1842(data.position, {instancePath:instancePath+"/position",parentData:data,parentDataProperty:"position",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1842.errors : vErrors.concat(validate1842.errors);
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
if(!(validate1634(data.changed_lsn, {instancePath:instancePath+"/changed_lsn",parentData:data,parentDataProperty:"changed_lsn",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1634.errors : vErrors.concat(validate1634.errors);
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
if(!(validate1634(data.live_rows, {instancePath:instancePath+"/live_rows",parentData:data,parentDataProperty:"live_rows",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1634.errors : vErrors.concat(validate1634.errors);
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
if(!(validate1634(data.pending_rows, {instancePath:instancePath+"/pending_rows",parentData:data,parentDataProperty:"pending_rows",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1634.errors : vErrors.concat(validate1634.errors);
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
if(!(validate1634(data.pending_bytes, {instancePath:instancePath+"/pending_bytes",parentData:data,parentDataProperty:"pending_bytes",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1634.errors : vErrors.concat(validate1634.errors);
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
if(!(validate1573(data.pending_complete, {instancePath:instancePath+"/pending_complete",parentData:data,parentDataProperty:"pending_complete",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1573.errors : vErrors.concat(validate1573.errors);
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
if(!(validate1851(data.oldest_pending_lsn, {instancePath:instancePath+"/oldest_pending_lsn",parentData:data,parentDataProperty:"oldest_pending_lsn",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1851.errors : vErrors.concat(validate1851.errors);
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
if(!(validate1634(data.archive_through, {instancePath:instancePath+"/archive_through",parentData:data,parentDataProperty:"archive_through",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1634.errors : vErrors.concat(validate1634.errors);
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
if(!(validate1851(data.recovery_through, {instancePath:instancePath+"/recovery_through",parentData:data,parentDataProperty:"recovery_through",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1851.errors : vErrors.concat(validate1851.errors);
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
if(!(validate1634(data.history_floor, {instancePath:instancePath+"/history_floor",parentData:data,parentDataProperty:"history_floor",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1634.errors : vErrors.concat(validate1634.errors);
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
if(!(validate1634(data.next_segment, {instancePath:instancePath+"/next_segment",parentData:data,parentDataProperty:"next_segment",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1634.errors : vErrors.concat(validate1634.errors);
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
if(!(validate1634(data.archive_source_lsn, {instancePath:instancePath+"/archive_source_lsn",parentData:data,parentDataProperty:"archive_source_lsn",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1634.errors : vErrors.concat(validate1634.errors);
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
if(!(validate1634(data.archived_source_lsn, {instancePath:instancePath+"/archived_source_lsn",parentData:data,parentDataProperty:"archived_source_lsn",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1634.errors : vErrors.concat(validate1634.errors);
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
if(!(validate1851(data.archive_target_source_lsn, {instancePath:instancePath+"/archive_target_source_lsn",parentData:data,parentDataProperty:"archive_target_source_lsn",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1851.errors : vErrors.concat(validate1851.errors);
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
if(!(validate1851(data.archive_target_through_lsn, {instancePath:instancePath+"/archive_target_through_lsn",parentData:data,parentDataProperty:"archive_target_through_lsn",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1851.errors : vErrors.concat(validate1851.errors);
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
if(!(validate1634(data.compaction_source_lsn, {instancePath:instancePath+"/compaction_source_lsn",parentData:data,parentDataProperty:"compaction_source_lsn",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1634.errors : vErrors.concat(validate1634.errors);
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
if(!(validate1634(data.compacted_source_lsn, {instancePath:instancePath+"/compacted_source_lsn",parentData:data,parentDataProperty:"compacted_source_lsn",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1634.errors : vErrors.concat(validate1634.errors);
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
if(!(validate1851(data.compaction_target_source_lsn, {instancePath:instancePath+"/compaction_target_source_lsn",parentData:data,parentDataProperty:"compaction_target_source_lsn",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1851.errors : vErrors.concat(validate1851.errors);
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
if(!(validate1851(data.compaction_target_before_segment, {instancePath:instancePath+"/compaction_target_before_segment",parentData:data,parentDataProperty:"compaction_target_before_segment",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1851.errors : vErrors.concat(validate1851.errors);
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
if(!(validate1851(data.compaction_target_after_segment, {instancePath:instancePath+"/compaction_target_after_segment",parentData:data,parentDataProperty:"compaction_target_after_segment",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1851.errors : vErrors.concat(validate1851.errors);
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
validate1841.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
return false;
}
}
validate1841.errors = vErrors;
return errors === 0;
}
validate1841.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate1804(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1804.evaluated;
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
validate1804.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "binding") || (key0 === "observed"))){
validate1804.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.binding !== undefined){
const _errs2 = errors;
if(!(validate1805(data.binding, {instancePath:instancePath+"/binding",parentData:data,parentDataProperty:"binding",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1805.errors : vErrors.concat(validate1805.errors);
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
if(!(validate1841(data.observed, {instancePath:instancePath+"/observed",parentData:data,parentDataProperty:"observed",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1841.errors : vErrors.concat(validate1841.errors);
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
validate1804.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
return false;
}
}
validate1804.errors = vErrors;
return errors === 0;
}
validate1804.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema494 = {"oneOf":[{"type":"object","additionalProperties":false,"required":["capabilities"],"properties":{"capabilities":{"$ref":"#/$defs/RelationalResponse/$defs/T2"}}},{"type":"object","additionalProperties":false,"required":["explained"],"properties":{"explained":{"$ref":"#/$defs/RelationalResponse/$defs/T25"}}},{"type":"object","additionalProperties":false,"required":["opened"],"properties":{"opened":{"$ref":"#/$defs/RelationalResponse/$defs/T22"}}},{"type":"object","additionalProperties":false,"required":["page"],"properties":{"page":{"$ref":"#/$defs/RelationalResponse/$defs/T82"}}},{"type":"object","additionalProperties":false,"required":["closed"],"properties":{"closed":{"$ref":"#/$defs/RelationalResponse/$defs/T39"}}}]};
const schema495 = {"type":"object","additionalProperties":false,"properties":{"reference":{"$ref":"#/$defs/RelationalResponse/$defs/T23"},"ordinal":{"$ref":"#/$defs/RelationalResponse/$defs/T24"},"row":{"$ref":"#/$defs/RelationalResponse/$defs/T83"},"complete_coverage":{"$ref":"#/$defs/RelationalResponse/$defs/T5"}},"required":["reference","ordinal","row","complete_coverage"]};
const schema496 = {"anyOf":[{"$ref":"#/$defs/RelationalResponse/$defs/T84"},{"type":"null"}]};
const schema497 = {"type":"object","additionalProperties":false,"properties":{"identity":{"$ref":"#/$defs/RelationalResponse/$defs/T85"},"cells":{"$ref":"#/$defs/RelationalResponse/$defs/T90"}},"required":["identity","cells"]};
const schema498 = {"oneOf":[{"type":"object","additionalProperties":false,"required":["pair"],"properties":{"pair":{"$ref":"#/$defs/RelationalResponse/$defs/T86"}}},{"type":"object","additionalProperties":false,"required":["group"],"properties":{"group":{"$ref":"#/$defs/RelationalResponse/$defs/T87"}}}]};
const schema499 = {"type":"object","additionalProperties":false,"properties":{"left":{"$ref":"#/$defs/RelationalResponse/$defs/T24"},"right":{"$ref":"#/$defs/RelationalResponse/$defs/T80"}},"required":["left","right"]};

function validate1879(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1879.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if(((data.left === undefined) && (missing0 = "left")) || ((data.right === undefined) && (missing0 = "right"))){
validate1879.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "left") || (key0 === "right"))){
validate1879.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.left !== undefined){
const _errs2 = errors;
if(!(validate1634(data.left, {instancePath:instancePath+"/left",parentData:data,parentDataProperty:"left",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1634.errors : vErrors.concat(validate1634.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.right !== undefined){
const _errs3 = errors;
if(!(validate1851(data.right, {instancePath:instancePath+"/right",parentData:data,parentDataProperty:"right",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1851.errors : vErrors.concat(validate1851.errors);
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
validate1879.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
return false;
}
}
validate1879.errors = vErrors;
return errors === 0;
}
validate1879.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema500 = {"type":"array","maxItems":128,"items":{"$ref":"#/$defs/RelationalResponse/$defs/T88"}};
const schema501 = {"anyOf":[{"$ref":"#/$defs/RelationalResponse/$defs/T89"},{"type":"null"}]};
const schema502 = {"oneOf":[{"type":"object","additionalProperties":false,"required":["signed"],"properties":{"signed":{"$ref":"#/$defs/RelationalResponse/$defs/T24"}}},{"type":"object","additionalProperties":false,"required":["utf8"],"properties":{"utf8":{"$ref":"#/$defs/RelationalResponse/$defs/T24"}}}]};

function validate1885(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1885.evaluated;
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
const err0 = {instancePath,schemaPath:"#/oneOf/0/required",keyword:"required",params:{missingProperty: missing0}};
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
const err1 = {instancePath,schemaPath:"#/oneOf/0/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}};
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
if(!(validate1634(data.signed, {instancePath:instancePath+"/signed",parentData:data,parentDataProperty:"signed",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1634.errors : vErrors.concat(validate1634.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err2 = {instancePath,schemaPath:"#/oneOf/0/type",keyword:"type",params:{type: "object"}};
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
if((data.utf8 === undefined) && (missing1 = "utf8")){
const err3 = {instancePath,schemaPath:"#/oneOf/1/required",keyword:"required",params:{missingProperty: missing1}};
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
if(!(key1 === "utf8")){
const err4 = {instancePath,schemaPath:"#/oneOf/1/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key1}};
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
if(data.utf8 !== undefined){
if(!(validate1634(data.utf8, {instancePath:instancePath+"/utf8",parentData:data,parentDataProperty:"utf8",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1634.errors : vErrors.concat(validate1634.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err5 = {instancePath,schemaPath:"#/oneOf/1/type",keyword:"type",params:{type: "object"}};
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
const err6 = {instancePath,schemaPath:"#/oneOf",keyword:"oneOf",params:{passingSchemas: passing0}};
if(vErrors === null){
vErrors = [err6];
}
else {
vErrors.push(err6);
}
errors++;
validate1885.errors = vErrors;
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
validate1885.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate1885.evaluated = {"dynamicProps":true,"dynamicItems":false};


function validate1884(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1884.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate1885(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1885.errors : vErrors.concat(validate1885.errors);
errors = vErrors.length;
}
else {
var props0 = validate1885.evaluated.props;
}
var _valid0 = _errs1 === errors;
valid0 = valid0 || _valid0;
const _errs2 = errors;
if(data !== null){
const err0 = {instancePath,schemaPath:"#/anyOf/1/type",keyword:"type",params:{type: "null"}};
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
const err1 = {instancePath,schemaPath:"#/anyOf",keyword:"anyOf",params:{}};
if(vErrors === null){
vErrors = [err1];
}
else {
vErrors.push(err1);
}
errors++;
validate1884.errors = vErrors;
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
validate1884.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate1884.evaluated = {"dynamicProps":true,"dynamicItems":false};


function validate1883(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1883.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(Array.isArray(data)){
if(data.length > 128){
validate1883.errors = [{instancePath,schemaPath:"#/maxItems",keyword:"maxItems",params:{limit: 128}}];
return false;
}
else {
var valid0 = true;
const len0 = data.length;
for(let i0=0; i0<len0; i0++){
const _errs1 = errors;
if(!(validate1884(data[i0], {instancePath:instancePath+"/" + i0,parentData:data,parentDataProperty:i0,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1884.errors : vErrors.concat(validate1884.errors);
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
validate1883.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "array"}}];
return false;
}
}
validate1883.errors = vErrors;
return errors === 0;
}
validate1883.evaluated = {"items":true,"dynamicProps":false,"dynamicItems":false};


function validate1878(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1878.evaluated;
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
if((data.pair === undefined) && (missing0 = "pair")){
const err0 = {instancePath,schemaPath:"#/oneOf/0/required",keyword:"required",params:{missingProperty: missing0}};
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
if(!(key0 === "pair")){
const err1 = {instancePath,schemaPath:"#/oneOf/0/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}};
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
if(data.pair !== undefined){
if(!(validate1879(data.pair, {instancePath:instancePath+"/pair",parentData:data,parentDataProperty:"pair",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1879.errors : vErrors.concat(validate1879.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err2 = {instancePath,schemaPath:"#/oneOf/0/type",keyword:"type",params:{type: "object"}};
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
if((data.group === undefined) && (missing1 = "group")){
const err3 = {instancePath,schemaPath:"#/oneOf/1/required",keyword:"required",params:{missingProperty: missing1}};
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
if(!(key1 === "group")){
const err4 = {instancePath,schemaPath:"#/oneOf/1/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key1}};
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
if(data.group !== undefined){
if(!(validate1883(data.group, {instancePath:instancePath+"/group",parentData:data,parentDataProperty:"group",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1883.errors : vErrors.concat(validate1883.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err5 = {instancePath,schemaPath:"#/oneOf/1/type",keyword:"type",params:{type: "object"}};
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
const err6 = {instancePath,schemaPath:"#/oneOf",keyword:"oneOf",params:{passingSchemas: passing0}};
if(vErrors === null){
vErrors = [err6];
}
else {
vErrors.push(err6);
}
errors++;
validate1878.errors = vErrors;
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
validate1878.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate1878.evaluated = {"dynamicProps":true,"dynamicItems":false};

const schema503 = {"type":"array","maxItems":128,"items":{"$ref":"#/$defs/RelationalResponse/$defs/T91"}};
const schema504 = {"oneOf":[{"type":"object","additionalProperties":false,"required":["missing"],"properties":{"missing":{"$ref":"#/$defs/RelationalResponse/$defs/T39"}}},{"type":"object","additionalProperties":false,"required":["null"],"properties":{"null":{"$ref":"#/$defs/RelationalResponse/$defs/T39"}}},{"type":"object","additionalProperties":false,"required":["type_error"],"properties":{"type_error":{"$ref":"#/$defs/RelationalResponse/$defs/T92"}}},{"type":"object","additionalProperties":false,"required":["value"],"properties":{"value":{"$ref":"#/$defs/RelationalResponse/$defs/T93"}}},{"type":"object","additionalProperties":false,"required":["conflict"],"properties":{"conflict":{"$ref":"#/$defs/RelationalResponse/$defs/T110"}}}]};
const schema350 = {"type":"string","enum":["unknown","int64","uint64","float64","boolean","utf8","binary","int8","int16","int32","int128","uint8","uint16","uint32","uint128","float32","decimal","date","time","timestamp","interval","uuid","structure","list","array","map","tagged_union","json","null_value","text","character"]};

function validate1896(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1896.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate1896.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"}}];
return false;
}
if(!(((((((((((((((((((((((((((((((data === "unknown") || (data === "int64")) || (data === "uint64")) || (data === "float64")) || (data === "boolean")) || (data === "utf8")) || (data === "binary")) || (data === "int8")) || (data === "int16")) || (data === "int32")) || (data === "int128")) || (data === "uint8")) || (data === "uint16")) || (data === "uint32")) || (data === "uint128")) || (data === "float32")) || (data === "decimal")) || (data === "date")) || (data === "time")) || (data === "timestamp")) || (data === "interval")) || (data === "uuid")) || (data === "structure")) || (data === "list")) || (data === "array")) || (data === "map")) || (data === "tagged_union")) || (data === "json")) || (data === "null_value")) || (data === "text")) || (data === "character"))){
validate1896.errors = [{instancePath,schemaPath:"#/enum",keyword:"enum",params:{allowedValues: schema350.enum}}];
return false;
}
validate1896.errors = vErrors;
return errors === 0;
}
validate1896.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema506 = {"oneOf":[{"type":"object","additionalProperties":false,"required":["atom"],"properties":{"atom":{"$ref":"#/$defs/RelationalResponse/$defs/T94"}}},{"type":"object","additionalProperties":false,"required":["structure"],"properties":{"structure":{"$ref":"#/$defs/RelationalResponse/$defs/T96"}}},{"type":"object","additionalProperties":false,"required":["list"],"properties":{"list":{"$ref":"#/$defs/RelationalResponse/$defs/T96"}}},{"type":"object","additionalProperties":false,"required":["array"],"properties":{"array":{"$ref":"#/$defs/RelationalResponse/$defs/T96"}}},{"type":"object","additionalProperties":false,"required":["map"],"properties":{"map":{"$ref":"#/$defs/RelationalResponse/$defs/T105"}}},{"type":"object","additionalProperties":false,"required":["tagged_union"],"properties":{"tagged_union":{"$ref":"#/$defs/RelationalResponse/$defs/T113"}}},{"type":"object","additionalProperties":false,"required":["json"],"properties":{"json":{"$ref":"#/$defs/RelationalResponse/$defs/T24"}}}]};
const schema507 = {"oneOf":[{"type":"object","additionalProperties":false,"required":["signed"],"properties":{"signed":{"$ref":"#/$defs/RelationalResponse/$defs/T24"}}},{"type":"object","additionalProperties":false,"required":["unsigned"],"properties":{"unsigned":{"$ref":"#/$defs/RelationalResponse/$defs/T24"}}},{"type":"object","additionalProperties":false,"required":["decimal"],"properties":{"decimal":{"$ref":"#/$defs/RelationalResponse/$defs/T24"}}},{"type":"object","additionalProperties":false,"required":["float_bits"],"properties":{"float_bits":{"$ref":"#/$defs/RelationalResponse/$defs/T24"}}},{"type":"object","additionalProperties":false,"required":["boolean"],"properties":{"boolean":{"$ref":"#/$defs/RelationalResponse/$defs/T5"}}},{"type":"object","additionalProperties":false,"required":["utf8"],"properties":{"utf8":{"$ref":"#/$defs/RelationalResponse/$defs/T24"}}},{"type":"object","additionalProperties":false,"required":["binary"],"properties":{"binary":{"$ref":"#/$defs/RelationalResponse/$defs/T24"}}},{"type":"object","additionalProperties":false,"required":["date_days"],"properties":{"date_days":{"$ref":"#/$defs/RelationalResponse/$defs/T24"}}},{"type":"object","additionalProperties":false,"required":["time_nanos"],"properties":{"time_nanos":{"$ref":"#/$defs/RelationalResponse/$defs/T24"}}},{"type":"object","additionalProperties":false,"required":["timestamp_micros"],"properties":{"timestamp_micros":{"$ref":"#/$defs/RelationalResponse/$defs/T24"}}},{"type":"object","additionalProperties":false,"required":["interval"],"properties":{"interval":{"$ref":"#/$defs/RelationalResponse/$defs/T95"}}},{"type":"object","additionalProperties":false,"required":["uuid"],"properties":{"uuid":{"$ref":"#/$defs/RelationalResponse/$defs/T24"}}}]};
const schema508 = {"type":"object","additionalProperties":false,"properties":{"months":{"$ref":"#/$defs/RelationalResponse/$defs/T24"},"days":{"$ref":"#/$defs/RelationalResponse/$defs/T24"},"nanos":{"$ref":"#/$defs/RelationalResponse/$defs/T24"}},"required":["months","days","nanos"]};

function validate1910(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1910.evaluated;
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
validate1910.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "months") || (key0 === "days")) || (key0 === "nanos"))){
validate1910.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.months !== undefined){
const _errs2 = errors;
if(!(validate1634(data.months, {instancePath:instancePath+"/months",parentData:data,parentDataProperty:"months",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1634.errors : vErrors.concat(validate1634.errors);
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
if(!(validate1634(data.days, {instancePath:instancePath+"/days",parentData:data,parentDataProperty:"days",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1634.errors : vErrors.concat(validate1634.errors);
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
if(!(validate1634(data.nanos, {instancePath:instancePath+"/nanos",parentData:data,parentDataProperty:"nanos",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1634.errors : vErrors.concat(validate1634.errors);
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
validate1910.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
return false;
}
}
validate1910.errors = vErrors;
return errors === 0;
}
validate1910.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate1899(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1899.evaluated;
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
const err0 = {instancePath,schemaPath:"#/oneOf/0/required",keyword:"required",params:{missingProperty: missing0}};
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
const err1 = {instancePath,schemaPath:"#/oneOf/0/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}};
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
if(!(validate1634(data.signed, {instancePath:instancePath+"/signed",parentData:data,parentDataProperty:"signed",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1634.errors : vErrors.concat(validate1634.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err2 = {instancePath,schemaPath:"#/oneOf/0/type",keyword:"type",params:{type: "object"}};
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
const err3 = {instancePath,schemaPath:"#/oneOf/1/required",keyword:"required",params:{missingProperty: missing1}};
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
const err4 = {instancePath,schemaPath:"#/oneOf/1/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key1}};
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
if(!(validate1634(data.unsigned, {instancePath:instancePath+"/unsigned",parentData:data,parentDataProperty:"unsigned",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1634.errors : vErrors.concat(validate1634.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err5 = {instancePath,schemaPath:"#/oneOf/1/type",keyword:"type",params:{type: "object"}};
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
const err6 = {instancePath,schemaPath:"#/oneOf/2/required",keyword:"required",params:{missingProperty: missing2}};
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
const err7 = {instancePath,schemaPath:"#/oneOf/2/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key2}};
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
if(!(validate1634(data.decimal, {instancePath:instancePath+"/decimal",parentData:data,parentDataProperty:"decimal",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1634.errors : vErrors.concat(validate1634.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err8 = {instancePath,schemaPath:"#/oneOf/2/type",keyword:"type",params:{type: "object"}};
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
const err9 = {instancePath,schemaPath:"#/oneOf/3/required",keyword:"required",params:{missingProperty: missing3}};
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
const err10 = {instancePath,schemaPath:"#/oneOf/3/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key3}};
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
if(!(validate1634(data.float_bits, {instancePath:instancePath+"/float_bits",parentData:data,parentDataProperty:"float_bits",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1634.errors : vErrors.concat(validate1634.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err11 = {instancePath,schemaPath:"#/oneOf/3/type",keyword:"type",params:{type: "object"}};
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
const err12 = {instancePath,schemaPath:"#/oneOf/4/required",keyword:"required",params:{missingProperty: missing4}};
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
const err13 = {instancePath,schemaPath:"#/oneOf/4/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key4}};
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
if(!(validate1573(data.boolean, {instancePath:instancePath+"/boolean",parentData:data,parentDataProperty:"boolean",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1573.errors : vErrors.concat(validate1573.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err14 = {instancePath,schemaPath:"#/oneOf/4/type",keyword:"type",params:{type: "object"}};
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
const err15 = {instancePath,schemaPath:"#/oneOf/5/required",keyword:"required",params:{missingProperty: missing5}};
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
const err16 = {instancePath,schemaPath:"#/oneOf/5/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key5}};
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
if(!(validate1634(data.utf8, {instancePath:instancePath+"/utf8",parentData:data,parentDataProperty:"utf8",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1634.errors : vErrors.concat(validate1634.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err17 = {instancePath,schemaPath:"#/oneOf/5/type",keyword:"type",params:{type: "object"}};
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
const err18 = {instancePath,schemaPath:"#/oneOf/6/required",keyword:"required",params:{missingProperty: missing6}};
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
const err19 = {instancePath,schemaPath:"#/oneOf/6/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key6}};
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
if(!(validate1634(data.binary, {instancePath:instancePath+"/binary",parentData:data,parentDataProperty:"binary",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1634.errors : vErrors.concat(validate1634.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err20 = {instancePath,schemaPath:"#/oneOf/6/type",keyword:"type",params:{type: "object"}};
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
const err21 = {instancePath,schemaPath:"#/oneOf/7/required",keyword:"required",params:{missingProperty: missing7}};
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
const err22 = {instancePath,schemaPath:"#/oneOf/7/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key7}};
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
if(!(validate1634(data.date_days, {instancePath:instancePath+"/date_days",parentData:data,parentDataProperty:"date_days",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1634.errors : vErrors.concat(validate1634.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err23 = {instancePath,schemaPath:"#/oneOf/7/type",keyword:"type",params:{type: "object"}};
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
const err24 = {instancePath,schemaPath:"#/oneOf/8/required",keyword:"required",params:{missingProperty: missing8}};
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
const err25 = {instancePath,schemaPath:"#/oneOf/8/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key8}};
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
if(!(validate1634(data.time_nanos, {instancePath:instancePath+"/time_nanos",parentData:data,parentDataProperty:"time_nanos",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1634.errors : vErrors.concat(validate1634.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err26 = {instancePath,schemaPath:"#/oneOf/8/type",keyword:"type",params:{type: "object"}};
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
const err27 = {instancePath,schemaPath:"#/oneOf/9/required",keyword:"required",params:{missingProperty: missing9}};
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
const err28 = {instancePath,schemaPath:"#/oneOf/9/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key9}};
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
if(!(validate1634(data.timestamp_micros, {instancePath:instancePath+"/timestamp_micros",parentData:data,parentDataProperty:"timestamp_micros",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1634.errors : vErrors.concat(validate1634.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err29 = {instancePath,schemaPath:"#/oneOf/9/type",keyword:"type",params:{type: "object"}};
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
const err30 = {instancePath,schemaPath:"#/oneOf/10/required",keyword:"required",params:{missingProperty: missing10}};
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
const err31 = {instancePath,schemaPath:"#/oneOf/10/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key10}};
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
if(!(validate1910(data.interval, {instancePath:instancePath+"/interval",parentData:data,parentDataProperty:"interval",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1910.errors : vErrors.concat(validate1910.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err32 = {instancePath,schemaPath:"#/oneOf/10/type",keyword:"type",params:{type: "object"}};
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
const err33 = {instancePath,schemaPath:"#/oneOf/11/required",keyword:"required",params:{missingProperty: missing11}};
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
const err34 = {instancePath,schemaPath:"#/oneOf/11/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key11}};
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
if(!(validate1634(data.uuid, {instancePath:instancePath+"/uuid",parentData:data,parentDataProperty:"uuid",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1634.errors : vErrors.concat(validate1634.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err35 = {instancePath,schemaPath:"#/oneOf/11/type",keyword:"type",params:{type: "object"}};
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
const err36 = {instancePath,schemaPath:"#/oneOf",keyword:"oneOf",params:{passingSchemas: passing0}};
if(vErrors === null){
vErrors = [err36];
}
else {
vErrors.push(err36);
}
errors++;
validate1899.errors = vErrors;
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
validate1899.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate1899.evaluated = {"dynamicProps":true,"dynamicItems":false};

const schema509 = {"type":"array","maxItems":65536,"items":{"$ref":"#/$defs/RelationalResponse/$defs/T97"}};
const schema510 = {"oneOf":[{"type":"object","additionalProperties":false,"required":["missing"],"properties":{"missing":{"$ref":"#/$defs/RelationalResponse/$defs/T98"}}},{"type":"object","additionalProperties":false,"required":["null"],"properties":{"null":{"$ref":"#/$defs/RelationalResponse/$defs/T98"}}},{"type":"object","additionalProperties":false,"required":["type_error"],"properties":{"type_error":{"$ref":"#/$defs/RelationalResponse/$defs/T99"}}},{"type":"object","additionalProperties":false,"required":["value"],"properties":{"value":{"$ref":"#/$defs/RelationalResponse/$defs/T100"}}},{"type":"object","additionalProperties":false,"required":["conflict"],"properties":{"conflict":{"$ref":"#/$defs/RelationalResponse/$defs/T110"}}}]};
const schema511 = {"type":"object","maxProperties":0};

function validate1919(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1919.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
if(Object.keys(data).length > 0){
validate1919.errors = [{instancePath,schemaPath:"#/maxProperties",keyword:"maxProperties",params:{limit: 0}}];
return false;
}
}
else {
validate1919.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
return false;
}
}
validate1919.errors = vErrors;
return errors === 0;
}
validate1919.evaluated = {"dynamicProps":false,"dynamicItems":false};


function validate1922(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1922.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate1922.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"}}];
return false;
}
if(!(((((((((((((((((((((((((((((((data === "unknown") || (data === "int64")) || (data === "uint64")) || (data === "float64")) || (data === "boolean")) || (data === "utf8")) || (data === "binary")) || (data === "int8")) || (data === "int16")) || (data === "int32")) || (data === "int128")) || (data === "uint8")) || (data === "uint16")) || (data === "uint32")) || (data === "uint128")) || (data === "float32")) || (data === "decimal")) || (data === "date")) || (data === "time")) || (data === "timestamp")) || (data === "interval")) || (data === "uuid")) || (data === "structure")) || (data === "list")) || (data === "array")) || (data === "map")) || (data === "tagged_union")) || (data === "json")) || (data === "null_value")) || (data === "text")) || (data === "character"))){
validate1922.errors = [{instancePath,schemaPath:"#/enum",keyword:"enum",params:{allowedValues: schema350.enum}}];
return false;
}
validate1922.errors = vErrors;
return errors === 0;
}
validate1922.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema513 = {"oneOf":[{"type":"object","additionalProperties":false,"required":["atom"],"properties":{"atom":{"$ref":"#/$defs/RelationalResponse/$defs/T101"}}},{"type":"object","additionalProperties":false,"required":["structure"],"properties":{"structure":{"$ref":"#/$defs/RelationalResponse/$defs/T96"}}},{"type":"object","additionalProperties":false,"required":["list"],"properties":{"list":{"$ref":"#/$defs/RelationalResponse/$defs/T96"}}},{"type":"object","additionalProperties":false,"required":["array"],"properties":{"array":{"$ref":"#/$defs/RelationalResponse/$defs/T96"}}},{"type":"object","additionalProperties":false,"required":["map"],"properties":{"map":{"$ref":"#/$defs/RelationalResponse/$defs/T105"}}},{"type":"object","additionalProperties":false,"required":["tagged_union"],"properties":{"tagged_union":{"$ref":"#/$defs/RelationalResponse/$defs/T107"}}},{"type":"object","additionalProperties":false,"required":["json"],"properties":{"json":{"$ref":"#/$defs/RelationalResponse/$defs/T102"}}}]};
const schema514 = {"oneOf":[{"type":"object","additionalProperties":false,"required":["signed"],"properties":{"signed":{"$ref":"#/$defs/RelationalResponse/$defs/T102"}}},{"type":"object","additionalProperties":false,"required":["unsigned"],"properties":{"unsigned":{"$ref":"#/$defs/RelationalResponse/$defs/T102"}}},{"type":"object","additionalProperties":false,"required":["decimal"],"properties":{"decimal":{"$ref":"#/$defs/RelationalResponse/$defs/T102"}}},{"type":"object","additionalProperties":false,"required":["float_bits"],"properties":{"float_bits":{"$ref":"#/$defs/RelationalResponse/$defs/T102"}}},{"type":"object","additionalProperties":false,"required":["boolean"],"properties":{"boolean":{"$ref":"#/$defs/RelationalResponse/$defs/T103"}}},{"type":"object","additionalProperties":false,"required":["utf8"],"properties":{"utf8":{"$ref":"#/$defs/RelationalResponse/$defs/T102"}}},{"type":"object","additionalProperties":false,"required":["binary"],"properties":{"binary":{"$ref":"#/$defs/RelationalResponse/$defs/T102"}}},{"type":"object","additionalProperties":false,"required":["date_days"],"properties":{"date_days":{"$ref":"#/$defs/RelationalResponse/$defs/T102"}}},{"type":"object","additionalProperties":false,"required":["time_nanos"],"properties":{"time_nanos":{"$ref":"#/$defs/RelationalResponse/$defs/T102"}}},{"type":"object","additionalProperties":false,"required":["timestamp_micros"],"properties":{"timestamp_micros":{"$ref":"#/$defs/RelationalResponse/$defs/T102"}}},{"type":"object","additionalProperties":false,"required":["interval"],"properties":{"interval":{"$ref":"#/$defs/RelationalResponse/$defs/T104"}}},{"type":"object","additionalProperties":false,"required":["uuid"],"properties":{"uuid":{"$ref":"#/$defs/RelationalResponse/$defs/T102"}}}]};
const schema515 = {"type":"string","maxLength":4096};

function validate1926(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1926.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(typeof data === "string"){
if(func4(data) > 4096){
validate1926.errors = [{instancePath,schemaPath:"#/maxLength",keyword:"maxLength",params:{limit: 4096}}];
return false;
}
}
else {
validate1926.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"}}];
return false;
}
}
validate1926.errors = vErrors;
return errors === 0;
}
validate1926.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema516 = {"type":"boolean"};

function validate1931(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1931.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "boolean"){
validate1931.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "boolean"}}];
return false;
}
validate1931.errors = vErrors;
return errors === 0;
}
validate1931.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema517 = {"type":"object","additionalProperties":false,"properties":{"months":{"$ref":"#/$defs/RelationalResponse/$defs/T102"},"days":{"$ref":"#/$defs/RelationalResponse/$defs/T102"},"nanos":{"$ref":"#/$defs/RelationalResponse/$defs/T102"}},"required":["months","days","nanos"]};

function validate1938(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1938.evaluated;
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
validate1938.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "months") || (key0 === "days")) || (key0 === "nanos"))){
validate1938.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.months !== undefined){
const _errs2 = errors;
if(!(validate1926(data.months, {instancePath:instancePath+"/months",parentData:data,parentDataProperty:"months",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1926.errors : vErrors.concat(validate1926.errors);
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
if(!(validate1926(data.days, {instancePath:instancePath+"/days",parentData:data,parentDataProperty:"days",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1926.errors : vErrors.concat(validate1926.errors);
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
if(!(validate1926(data.nanos, {instancePath:instancePath+"/nanos",parentData:data,parentDataProperty:"nanos",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1926.errors : vErrors.concat(validate1926.errors);
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
validate1938.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
return false;
}
}
validate1938.errors = vErrors;
return errors === 0;
}
validate1938.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate1925(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1925.evaluated;
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
const err0 = {instancePath,schemaPath:"#/oneOf/0/required",keyword:"required",params:{missingProperty: missing0}};
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
const err1 = {instancePath,schemaPath:"#/oneOf/0/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}};
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
if(!(validate1926(data.signed, {instancePath:instancePath+"/signed",parentData:data,parentDataProperty:"signed",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1926.errors : vErrors.concat(validate1926.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err2 = {instancePath,schemaPath:"#/oneOf/0/type",keyword:"type",params:{type: "object"}};
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
const err3 = {instancePath,schemaPath:"#/oneOf/1/required",keyword:"required",params:{missingProperty: missing1}};
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
const err4 = {instancePath,schemaPath:"#/oneOf/1/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key1}};
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
if(!(validate1926(data.unsigned, {instancePath:instancePath+"/unsigned",parentData:data,parentDataProperty:"unsigned",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1926.errors : vErrors.concat(validate1926.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err5 = {instancePath,schemaPath:"#/oneOf/1/type",keyword:"type",params:{type: "object"}};
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
const err6 = {instancePath,schemaPath:"#/oneOf/2/required",keyword:"required",params:{missingProperty: missing2}};
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
const err7 = {instancePath,schemaPath:"#/oneOf/2/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key2}};
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
if(!(validate1926(data.decimal, {instancePath:instancePath+"/decimal",parentData:data,parentDataProperty:"decimal",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1926.errors : vErrors.concat(validate1926.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err8 = {instancePath,schemaPath:"#/oneOf/2/type",keyword:"type",params:{type: "object"}};
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
const err9 = {instancePath,schemaPath:"#/oneOf/3/required",keyword:"required",params:{missingProperty: missing3}};
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
const err10 = {instancePath,schemaPath:"#/oneOf/3/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key3}};
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
if(!(validate1926(data.float_bits, {instancePath:instancePath+"/float_bits",parentData:data,parentDataProperty:"float_bits",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1926.errors : vErrors.concat(validate1926.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err11 = {instancePath,schemaPath:"#/oneOf/3/type",keyword:"type",params:{type: "object"}};
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
const err12 = {instancePath,schemaPath:"#/oneOf/4/required",keyword:"required",params:{missingProperty: missing4}};
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
const err13 = {instancePath,schemaPath:"#/oneOf/4/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key4}};
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
if(!(validate1931(data.boolean, {instancePath:instancePath+"/boolean",parentData:data,parentDataProperty:"boolean",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1931.errors : vErrors.concat(validate1931.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err14 = {instancePath,schemaPath:"#/oneOf/4/type",keyword:"type",params:{type: "object"}};
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
const err15 = {instancePath,schemaPath:"#/oneOf/5/required",keyword:"required",params:{missingProperty: missing5}};
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
const err16 = {instancePath,schemaPath:"#/oneOf/5/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key5}};
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
if(!(validate1926(data.utf8, {instancePath:instancePath+"/utf8",parentData:data,parentDataProperty:"utf8",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1926.errors : vErrors.concat(validate1926.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err17 = {instancePath,schemaPath:"#/oneOf/5/type",keyword:"type",params:{type: "object"}};
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
const err18 = {instancePath,schemaPath:"#/oneOf/6/required",keyword:"required",params:{missingProperty: missing6}};
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
const err19 = {instancePath,schemaPath:"#/oneOf/6/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key6}};
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
if(!(validate1926(data.binary, {instancePath:instancePath+"/binary",parentData:data,parentDataProperty:"binary",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1926.errors : vErrors.concat(validate1926.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err20 = {instancePath,schemaPath:"#/oneOf/6/type",keyword:"type",params:{type: "object"}};
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
const err21 = {instancePath,schemaPath:"#/oneOf/7/required",keyword:"required",params:{missingProperty: missing7}};
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
const err22 = {instancePath,schemaPath:"#/oneOf/7/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key7}};
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
if(!(validate1926(data.date_days, {instancePath:instancePath+"/date_days",parentData:data,parentDataProperty:"date_days",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1926.errors : vErrors.concat(validate1926.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err23 = {instancePath,schemaPath:"#/oneOf/7/type",keyword:"type",params:{type: "object"}};
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
const err24 = {instancePath,schemaPath:"#/oneOf/8/required",keyword:"required",params:{missingProperty: missing8}};
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
const err25 = {instancePath,schemaPath:"#/oneOf/8/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key8}};
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
if(!(validate1926(data.time_nanos, {instancePath:instancePath+"/time_nanos",parentData:data,parentDataProperty:"time_nanos",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1926.errors : vErrors.concat(validate1926.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err26 = {instancePath,schemaPath:"#/oneOf/8/type",keyword:"type",params:{type: "object"}};
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
const err27 = {instancePath,schemaPath:"#/oneOf/9/required",keyword:"required",params:{missingProperty: missing9}};
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
const err28 = {instancePath,schemaPath:"#/oneOf/9/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key9}};
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
if(!(validate1926(data.timestamp_micros, {instancePath:instancePath+"/timestamp_micros",parentData:data,parentDataProperty:"timestamp_micros",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1926.errors : vErrors.concat(validate1926.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err29 = {instancePath,schemaPath:"#/oneOf/9/type",keyword:"type",params:{type: "object"}};
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
const err30 = {instancePath,schemaPath:"#/oneOf/10/required",keyword:"required",params:{missingProperty: missing10}};
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
const err31 = {instancePath,schemaPath:"#/oneOf/10/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key10}};
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
if(!(validate1938(data.interval, {instancePath:instancePath+"/interval",parentData:data,parentDataProperty:"interval",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1938.errors : vErrors.concat(validate1938.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err32 = {instancePath,schemaPath:"#/oneOf/10/type",keyword:"type",params:{type: "object"}};
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
const err33 = {instancePath,schemaPath:"#/oneOf/11/required",keyword:"required",params:{missingProperty: missing11}};
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
const err34 = {instancePath,schemaPath:"#/oneOf/11/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key11}};
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
if(!(validate1926(data.uuid, {instancePath:instancePath+"/uuid",parentData:data,parentDataProperty:"uuid",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1926.errors : vErrors.concat(validate1926.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err35 = {instancePath,schemaPath:"#/oneOf/11/type",keyword:"type",params:{type: "object"}};
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
const err36 = {instancePath,schemaPath:"#/oneOf",keyword:"oneOf",params:{passingSchemas: passing0}};
if(vErrors === null){
vErrors = [err36];
}
else {
vErrors.push(err36);
}
errors++;
validate1925.errors = vErrors;
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
validate1925.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate1925.evaluated = {"dynamicProps":true,"dynamicItems":false};

const schema518 = {"type":"array","maxItems":65536,"items":{"$ref":"#/$defs/RelationalResponse/$defs/T106"}};
const schema519 = {"type":"object","additionalProperties":false,"properties":{"key":{"$ref":"#/$defs/RelationalResponse/$defs/T101"},"value":{"$ref":"#/$defs/RelationalResponse/$defs/T97"}},"required":["key","value"]};
const wrapper23 = {validate: validate1918};

function validate1946(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1946.evaluated;
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
validate1946.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "key") || (key0 === "value"))){
validate1946.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.key !== undefined){
const _errs2 = errors;
if(!(validate1925(data.key, {instancePath:instancePath+"/key",parentData:data,parentDataProperty:"key",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1925.errors : vErrors.concat(validate1925.errors);
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
if(!(wrapper23.validate(data.value, {instancePath:instancePath+"/value",parentData:data,parentDataProperty:"value",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? wrapper23.validate.errors : vErrors.concat(wrapper23.validate.errors);
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
validate1946.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
return false;
}
}
validate1946.errors = vErrors;
return errors === 0;
}
validate1946.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate1945(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1945.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(Array.isArray(data)){
if(data.length > 65536){
validate1945.errors = [{instancePath,schemaPath:"#/maxItems",keyword:"maxItems",params:{limit: 65536}}];
return false;
}
else {
var valid0 = true;
const len0 = data.length;
for(let i0=0; i0<len0; i0++){
const _errs1 = errors;
if(!(validate1946(data[i0], {instancePath:instancePath+"/" + i0,parentData:data,parentDataProperty:i0,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1946.errors : vErrors.concat(validate1946.errors);
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
validate1945.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "array"}}];
return false;
}
}
validate1945.errors = vErrors;
return errors === 0;
}
validate1945.evaluated = {"items":true,"dynamicProps":false,"dynamicItems":false};

const schema520 = {"type":"object","additionalProperties":false,"properties":{"index":{"$ref":"#/$defs/RelationalResponse/$defs/T108"},"value":{"$ref":"#/$defs/RelationalResponse/$defs/T109"}},"required":["index","value"]};

function validate1951(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1951.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(!(((typeof data == "number") && (!(data % 1) && !isNaN(data))) && (isFinite(data)))){
validate1951.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "integer"}}];
return false;
}
if(errors === 0){
if((typeof data == "number") && (isFinite(data))){
if(data > 255 || isNaN(data)){
validate1951.errors = [{instancePath,schemaPath:"#/maximum",keyword:"maximum",params:{comparison: "<=", limit: 255}}];
return false;
}
else {
if(data < 0 || isNaN(data)){
validate1951.errors = [{instancePath,schemaPath:"#/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0}}];
return false;
}
}
}
}
validate1951.errors = vErrors;
return errors === 0;
}
validate1951.evaluated = {"dynamicProps":false,"dynamicItems":false};


function validate1950(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1950.evaluated;
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
validate1950.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "index") || (key0 === "value"))){
validate1950.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.index !== undefined){
const _errs2 = errors;
if(!(validate1951(data.index, {instancePath:instancePath+"/index",parentData:data,parentDataProperty:"index",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1951.errors : vErrors.concat(validate1951.errors);
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
if(!(wrapper23.validate(data.value, {instancePath:instancePath+"/value",parentData:data,parentDataProperty:"value",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? wrapper23.validate.errors : vErrors.concat(wrapper23.validate.errors);
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
validate1950.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
return false;
}
}
validate1950.errors = vErrors;
return errors === 0;
}
validate1950.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const wrapper20 = {validate: validate1917};

function validate1924(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1924.evaluated;
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
const err0 = {instancePath,schemaPath:"#/oneOf/0/required",keyword:"required",params:{missingProperty: missing0}};
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
const err1 = {instancePath,schemaPath:"#/oneOf/0/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}};
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
if(!(validate1925(data.atom, {instancePath:instancePath+"/atom",parentData:data,parentDataProperty:"atom",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1925.errors : vErrors.concat(validate1925.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err2 = {instancePath,schemaPath:"#/oneOf/0/type",keyword:"type",params:{type: "object"}};
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
const err3 = {instancePath,schemaPath:"#/oneOf/1/required",keyword:"required",params:{missingProperty: missing1}};
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
const err4 = {instancePath,schemaPath:"#/oneOf/1/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key1}};
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
if(!(wrapper20.validate(data.structure, {instancePath:instancePath+"/structure",parentData:data,parentDataProperty:"structure",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? wrapper20.validate.errors : vErrors.concat(wrapper20.validate.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err5 = {instancePath,schemaPath:"#/oneOf/1/type",keyword:"type",params:{type: "object"}};
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
const err6 = {instancePath,schemaPath:"#/oneOf/2/required",keyword:"required",params:{missingProperty: missing2}};
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
const err7 = {instancePath,schemaPath:"#/oneOf/2/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key2}};
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
if(!(wrapper20.validate(data.list, {instancePath:instancePath+"/list",parentData:data,parentDataProperty:"list",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? wrapper20.validate.errors : vErrors.concat(wrapper20.validate.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err8 = {instancePath,schemaPath:"#/oneOf/2/type",keyword:"type",params:{type: "object"}};
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
const err9 = {instancePath,schemaPath:"#/oneOf/3/required",keyword:"required",params:{missingProperty: missing3}};
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
const err10 = {instancePath,schemaPath:"#/oneOf/3/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key3}};
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
if(!(wrapper20.validate(data.array, {instancePath:instancePath+"/array",parentData:data,parentDataProperty:"array",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? wrapper20.validate.errors : vErrors.concat(wrapper20.validate.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err11 = {instancePath,schemaPath:"#/oneOf/3/type",keyword:"type",params:{type: "object"}};
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
const err12 = {instancePath,schemaPath:"#/oneOf/4/required",keyword:"required",params:{missingProperty: missing4}};
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
const err13 = {instancePath,schemaPath:"#/oneOf/4/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key4}};
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
if(!(validate1945(data.map, {instancePath:instancePath+"/map",parentData:data,parentDataProperty:"map",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1945.errors : vErrors.concat(validate1945.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err14 = {instancePath,schemaPath:"#/oneOf/4/type",keyword:"type",params:{type: "object"}};
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
const err15 = {instancePath,schemaPath:"#/oneOf/5/required",keyword:"required",params:{missingProperty: missing5}};
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
const err16 = {instancePath,schemaPath:"#/oneOf/5/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key5}};
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
if(!(validate1950(data.tagged_union, {instancePath:instancePath+"/tagged_union",parentData:data,parentDataProperty:"tagged_union",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1950.errors : vErrors.concat(validate1950.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err17 = {instancePath,schemaPath:"#/oneOf/5/type",keyword:"type",params:{type: "object"}};
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
const err18 = {instancePath,schemaPath:"#/oneOf/6/required",keyword:"required",params:{missingProperty: missing6}};
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
const err19 = {instancePath,schemaPath:"#/oneOf/6/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key6}};
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
if(!(validate1926(data.json, {instancePath:instancePath+"/json",parentData:data,parentDataProperty:"json",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1926.errors : vErrors.concat(validate1926.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err20 = {instancePath,schemaPath:"#/oneOf/6/type",keyword:"type",params:{type: "object"}};
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
const err21 = {instancePath,schemaPath:"#/oneOf",keyword:"oneOf",params:{passingSchemas: passing0}};
if(vErrors === null){
vErrors = [err21];
}
else {
vErrors.push(err21);
}
errors++;
validate1924.errors = vErrors;
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
validate1924.errors = vErrors;
evaluated0.props = props1;
return errors === 0;
}
validate1924.evaluated = {"dynamicProps":true,"dynamicItems":false};

const schema522 = {"type":"array","maxItems":65536,"items":{"$ref":"#/$defs/RelationalResponse/$defs/T111"}};
const schema523 = {"type":"object","additionalProperties":false,"properties":{"counter":{"$ref":"#/$defs/RelationalResponse/$defs/T102"},"replica":{"$ref":"#/$defs/RelationalResponse/$defs/T102"},"value":{"$ref":"#/$defs/RelationalResponse/$defs/T112"}},"required":["counter","replica","value"]};
const schema524 = {"oneOf":[{"type":"object","additionalProperties":false,"required":["null"],"properties":{"null":{"$ref":"#/$defs/RelationalResponse/$defs/T98"}}},{"type":"object","additionalProperties":false,"required":["type_error"],"properties":{"type_error":{"$ref":"#/$defs/RelationalResponse/$defs/T99"}}},{"type":"object","additionalProperties":false,"required":["value"],"properties":{"value":{"$ref":"#/$defs/RelationalResponse/$defs/T100"}}}]};

function validate1960(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1960.evaluated;
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
const err0 = {instancePath,schemaPath:"#/oneOf/0/required",keyword:"required",params:{missingProperty: missing0}};
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
const err1 = {instancePath,schemaPath:"#/oneOf/0/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}};
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
if(!(validate1919(data.null, {instancePath:instancePath+"/null",parentData:data,parentDataProperty:"null",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1919.errors : vErrors.concat(validate1919.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err2 = {instancePath,schemaPath:"#/oneOf/0/type",keyword:"type",params:{type: "object"}};
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
const err3 = {instancePath,schemaPath:"#/oneOf/1/required",keyword:"required",params:{missingProperty: missing1}};
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
const err4 = {instancePath,schemaPath:"#/oneOf/1/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key1}};
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
if(!(validate1922(data.type_error, {instancePath:instancePath+"/type_error",parentData:data,parentDataProperty:"type_error",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1922.errors : vErrors.concat(validate1922.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err5 = {instancePath,schemaPath:"#/oneOf/1/type",keyword:"type",params:{type: "object"}};
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
const err6 = {instancePath,schemaPath:"#/oneOf/2/required",keyword:"required",params:{missingProperty: missing2}};
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
const err7 = {instancePath,schemaPath:"#/oneOf/2/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key2}};
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
if(!(validate1924(data.value, {instancePath:instancePath+"/value",parentData:data,parentDataProperty:"value",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1924.errors : vErrors.concat(validate1924.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err8 = {instancePath,schemaPath:"#/oneOf/2/type",keyword:"type",params:{type: "object"}};
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
const err9 = {instancePath,schemaPath:"#/oneOf",keyword:"oneOf",params:{passingSchemas: passing0}};
if(vErrors === null){
vErrors = [err9];
}
else {
vErrors.push(err9);
}
errors++;
validate1960.errors = vErrors;
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
validate1960.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate1960.evaluated = {"dynamicProps":true,"dynamicItems":false};


function validate1957(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1957.evaluated;
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
validate1957.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "counter") || (key0 === "replica")) || (key0 === "value"))){
validate1957.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.counter !== undefined){
const _errs2 = errors;
if(!(validate1926(data.counter, {instancePath:instancePath+"/counter",parentData:data,parentDataProperty:"counter",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1926.errors : vErrors.concat(validate1926.errors);
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
if(!(validate1926(data.replica, {instancePath:instancePath+"/replica",parentData:data,parentDataProperty:"replica",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1926.errors : vErrors.concat(validate1926.errors);
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
if(!(validate1960(data.value, {instancePath:instancePath+"/value",parentData:data,parentDataProperty:"value",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1960.errors : vErrors.concat(validate1960.errors);
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
validate1957.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
return false;
}
}
validate1957.errors = vErrors;
return errors === 0;
}
validate1957.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate1956(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1956.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(Array.isArray(data)){
if(data.length > 65536){
validate1956.errors = [{instancePath,schemaPath:"#/maxItems",keyword:"maxItems",params:{limit: 65536}}];
return false;
}
else {
var valid0 = true;
const len0 = data.length;
for(let i0=0; i0<len0; i0++){
const _errs1 = errors;
if(!(validate1957(data[i0], {instancePath:instancePath+"/" + i0,parentData:data,parentDataProperty:i0,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1957.errors : vErrors.concat(validate1957.errors);
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
validate1956.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "array"}}];
return false;
}
}
validate1956.errors = vErrors;
return errors === 0;
}
validate1956.evaluated = {"items":true,"dynamicProps":false,"dynamicItems":false};


function validate1918(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1918.evaluated;
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
const err0 = {instancePath,schemaPath:"#/oneOf/0/required",keyword:"required",params:{missingProperty: missing0}};
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
const err1 = {instancePath,schemaPath:"#/oneOf/0/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}};
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
if(!(validate1919(data.missing, {instancePath:instancePath+"/missing",parentData:data,parentDataProperty:"missing",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1919.errors : vErrors.concat(validate1919.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err2 = {instancePath,schemaPath:"#/oneOf/0/type",keyword:"type",params:{type: "object"}};
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
const err3 = {instancePath,schemaPath:"#/oneOf/1/required",keyword:"required",params:{missingProperty: missing1}};
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
const err4 = {instancePath,schemaPath:"#/oneOf/1/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key1}};
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
if(!(validate1919(data.null, {instancePath:instancePath+"/null",parentData:data,parentDataProperty:"null",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1919.errors : vErrors.concat(validate1919.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err5 = {instancePath,schemaPath:"#/oneOf/1/type",keyword:"type",params:{type: "object"}};
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
const err6 = {instancePath,schemaPath:"#/oneOf/2/required",keyword:"required",params:{missingProperty: missing2}};
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
const err7 = {instancePath,schemaPath:"#/oneOf/2/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key2}};
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
if(!(validate1922(data.type_error, {instancePath:instancePath+"/type_error",parentData:data,parentDataProperty:"type_error",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1922.errors : vErrors.concat(validate1922.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err8 = {instancePath,schemaPath:"#/oneOf/2/type",keyword:"type",params:{type: "object"}};
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
const err9 = {instancePath,schemaPath:"#/oneOf/3/required",keyword:"required",params:{missingProperty: missing3}};
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
const err10 = {instancePath,schemaPath:"#/oneOf/3/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key3}};
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
if(!(validate1924(data.value, {instancePath:instancePath+"/value",parentData:data,parentDataProperty:"value",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1924.errors : vErrors.concat(validate1924.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err11 = {instancePath,schemaPath:"#/oneOf/3/type",keyword:"type",params:{type: "object"}};
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
const err12 = {instancePath,schemaPath:"#/oneOf/4/required",keyword:"required",params:{missingProperty: missing4}};
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
const err13 = {instancePath,schemaPath:"#/oneOf/4/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key4}};
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
if(!(validate1956(data.conflict, {instancePath:instancePath+"/conflict",parentData:data,parentDataProperty:"conflict",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1956.errors : vErrors.concat(validate1956.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err14 = {instancePath,schemaPath:"#/oneOf/4/type",keyword:"type",params:{type: "object"}};
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
const err15 = {instancePath,schemaPath:"#/oneOf",keyword:"oneOf",params:{passingSchemas: passing0}};
if(vErrors === null){
vErrors = [err15];
}
else {
vErrors.push(err15);
}
errors++;
validate1918.errors = vErrors;
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
validate1918.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate1918.evaluated = {"dynamicProps":true,"dynamicItems":false};


function validate1917(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1917.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(Array.isArray(data)){
if(data.length > 65536){
validate1917.errors = [{instancePath,schemaPath:"#/maxItems",keyword:"maxItems",params:{limit: 65536}}];
return false;
}
else {
var valid0 = true;
const len0 = data.length;
for(let i0=0; i0<len0; i0++){
const _errs1 = errors;
if(!(validate1918(data[i0], {instancePath:instancePath+"/" + i0,parentData:data,parentDataProperty:i0,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1918.errors : vErrors.concat(validate1918.errors);
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
validate1917.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "array"}}];
return false;
}
}
validate1917.errors = vErrors;
return errors === 0;
}
validate1917.evaluated = {"items":true,"dynamicProps":false,"dynamicItems":false};

const schema525 = {"type":"object","additionalProperties":false,"properties":{"index":{"$ref":"#/$defs/RelationalResponse/$defs/T4"},"value":{"$ref":"#/$defs/RelationalResponse/$defs/T114"}},"required":["index","value"]};
const wrapper25 = {validate: validate1893};

function validate1972(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1972.evaluated;
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
validate1972.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "index") || (key0 === "value"))){
validate1972.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.index !== undefined){
const _errs2 = errors;
if(!(validate1569(data.index, {instancePath:instancePath+"/index",parentData:data,parentDataProperty:"index",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1569.errors : vErrors.concat(validate1569.errors);
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
if(!(wrapper25.validate(data.value, {instancePath:instancePath+"/value",parentData:data,parentDataProperty:"value",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? wrapper25.validate.errors : vErrors.concat(wrapper25.validate.errors);
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
validate1972.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
return false;
}
}
validate1972.errors = vErrors;
return errors === 0;
}
validate1972.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate1898(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1898.evaluated;
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
const err0 = {instancePath,schemaPath:"#/oneOf/0/required",keyword:"required",params:{missingProperty: missing0}};
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
const err1 = {instancePath,schemaPath:"#/oneOf/0/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}};
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
if(!(validate1899(data.atom, {instancePath:instancePath+"/atom",parentData:data,parentDataProperty:"atom",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1899.errors : vErrors.concat(validate1899.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err2 = {instancePath,schemaPath:"#/oneOf/0/type",keyword:"type",params:{type: "object"}};
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
const err3 = {instancePath,schemaPath:"#/oneOf/1/required",keyword:"required",params:{missingProperty: missing1}};
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
const err4 = {instancePath,schemaPath:"#/oneOf/1/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key1}};
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
if(!(validate1917(data.structure, {instancePath:instancePath+"/structure",parentData:data,parentDataProperty:"structure",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1917.errors : vErrors.concat(validate1917.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err5 = {instancePath,schemaPath:"#/oneOf/1/type",keyword:"type",params:{type: "object"}};
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
const err6 = {instancePath,schemaPath:"#/oneOf/2/required",keyword:"required",params:{missingProperty: missing2}};
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
const err7 = {instancePath,schemaPath:"#/oneOf/2/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key2}};
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
if(!(validate1917(data.list, {instancePath:instancePath+"/list",parentData:data,parentDataProperty:"list",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1917.errors : vErrors.concat(validate1917.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err8 = {instancePath,schemaPath:"#/oneOf/2/type",keyword:"type",params:{type: "object"}};
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
const err9 = {instancePath,schemaPath:"#/oneOf/3/required",keyword:"required",params:{missingProperty: missing3}};
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
const err10 = {instancePath,schemaPath:"#/oneOf/3/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key3}};
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
if(!(validate1917(data.array, {instancePath:instancePath+"/array",parentData:data,parentDataProperty:"array",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1917.errors : vErrors.concat(validate1917.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err11 = {instancePath,schemaPath:"#/oneOf/3/type",keyword:"type",params:{type: "object"}};
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
const err12 = {instancePath,schemaPath:"#/oneOf/4/required",keyword:"required",params:{missingProperty: missing4}};
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
const err13 = {instancePath,schemaPath:"#/oneOf/4/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key4}};
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
if(!(validate1945(data.map, {instancePath:instancePath+"/map",parentData:data,parentDataProperty:"map",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1945.errors : vErrors.concat(validate1945.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err14 = {instancePath,schemaPath:"#/oneOf/4/type",keyword:"type",params:{type: "object"}};
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
const err15 = {instancePath,schemaPath:"#/oneOf/5/required",keyword:"required",params:{missingProperty: missing5}};
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
const err16 = {instancePath,schemaPath:"#/oneOf/5/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key5}};
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
if(!(validate1972(data.tagged_union, {instancePath:instancePath+"/tagged_union",parentData:data,parentDataProperty:"tagged_union",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1972.errors : vErrors.concat(validate1972.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err17 = {instancePath,schemaPath:"#/oneOf/5/type",keyword:"type",params:{type: "object"}};
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
const err18 = {instancePath,schemaPath:"#/oneOf/6/required",keyword:"required",params:{missingProperty: missing6}};
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
const err19 = {instancePath,schemaPath:"#/oneOf/6/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key6}};
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
if(!(validate1634(data.json, {instancePath:instancePath+"/json",parentData:data,parentDataProperty:"json",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1634.errors : vErrors.concat(validate1634.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err20 = {instancePath,schemaPath:"#/oneOf/6/type",keyword:"type",params:{type: "object"}};
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
const err21 = {instancePath,schemaPath:"#/oneOf",keyword:"oneOf",params:{passingSchemas: passing0}};
if(vErrors === null){
vErrors = [err21];
}
else {
vErrors.push(err21);
}
errors++;
validate1898.errors = vErrors;
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
validate1898.errors = vErrors;
evaluated0.props = props1;
return errors === 0;
}
validate1898.evaluated = {"dynamicProps":true,"dynamicItems":false};


function validate1893(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1893.evaluated;
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
const err0 = {instancePath,schemaPath:"#/oneOf/0/required",keyword:"required",params:{missingProperty: missing0}};
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
const err1 = {instancePath,schemaPath:"#/oneOf/0/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}};
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
if(!(validate1680(data.missing, {instancePath:instancePath+"/missing",parentData:data,parentDataProperty:"missing",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1680.errors : vErrors.concat(validate1680.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err2 = {instancePath,schemaPath:"#/oneOf/0/type",keyword:"type",params:{type: "object"}};
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
const err3 = {instancePath,schemaPath:"#/oneOf/1/required",keyword:"required",params:{missingProperty: missing1}};
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
const err4 = {instancePath,schemaPath:"#/oneOf/1/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key1}};
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
if(!(validate1680(data.null, {instancePath:instancePath+"/null",parentData:data,parentDataProperty:"null",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1680.errors : vErrors.concat(validate1680.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err5 = {instancePath,schemaPath:"#/oneOf/1/type",keyword:"type",params:{type: "object"}};
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
const err6 = {instancePath,schemaPath:"#/oneOf/2/required",keyword:"required",params:{missingProperty: missing2}};
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
const err7 = {instancePath,schemaPath:"#/oneOf/2/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key2}};
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
if(!(validate1896(data.type_error, {instancePath:instancePath+"/type_error",parentData:data,parentDataProperty:"type_error",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1896.errors : vErrors.concat(validate1896.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err8 = {instancePath,schemaPath:"#/oneOf/2/type",keyword:"type",params:{type: "object"}};
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
const err9 = {instancePath,schemaPath:"#/oneOf/3/required",keyword:"required",params:{missingProperty: missing3}};
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
const err10 = {instancePath,schemaPath:"#/oneOf/3/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key3}};
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
if(!(validate1898(data.value, {instancePath:instancePath+"/value",parentData:data,parentDataProperty:"value",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1898.errors : vErrors.concat(validate1898.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err11 = {instancePath,schemaPath:"#/oneOf/3/type",keyword:"type",params:{type: "object"}};
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
const err12 = {instancePath,schemaPath:"#/oneOf/4/required",keyword:"required",params:{missingProperty: missing4}};
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
const err13 = {instancePath,schemaPath:"#/oneOf/4/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key4}};
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
if(!(validate1956(data.conflict, {instancePath:instancePath+"/conflict",parentData:data,parentDataProperty:"conflict",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1956.errors : vErrors.concat(validate1956.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err14 = {instancePath,schemaPath:"#/oneOf/4/type",keyword:"type",params:{type: "object"}};
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
const err15 = {instancePath,schemaPath:"#/oneOf",keyword:"oneOf",params:{passingSchemas: passing0}};
if(vErrors === null){
vErrors = [err15];
}
else {
vErrors.push(err15);
}
errors++;
validate1893.errors = vErrors;
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
validate1893.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate1893.evaluated = {"dynamicProps":true,"dynamicItems":false};


function validate1892(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1892.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(Array.isArray(data)){
if(data.length > 128){
validate1892.errors = [{instancePath,schemaPath:"#/maxItems",keyword:"maxItems",params:{limit: 128}}];
return false;
}
else {
var valid0 = true;
const len0 = data.length;
for(let i0=0; i0<len0; i0++){
const _errs1 = errors;
if(!(validate1893(data[i0], {instancePath:instancePath+"/" + i0,parentData:data,parentDataProperty:i0,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1893.errors : vErrors.concat(validate1893.errors);
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
validate1892.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "array"}}];
return false;
}
}
validate1892.errors = vErrors;
return errors === 0;
}
validate1892.evaluated = {"items":true,"dynamicProps":false,"dynamicItems":false};


function validate1877(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1877.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if(((data.identity === undefined) && (missing0 = "identity")) || ((data.cells === undefined) && (missing0 = "cells"))){
validate1877.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "identity") || (key0 === "cells"))){
validate1877.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.identity !== undefined){
const _errs2 = errors;
if(!(validate1878(data.identity, {instancePath:instancePath+"/identity",parentData:data,parentDataProperty:"identity",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1878.errors : vErrors.concat(validate1878.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.cells !== undefined){
const _errs3 = errors;
if(!(validate1892(data.cells, {instancePath:instancePath+"/cells",parentData:data,parentDataProperty:"cells",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1892.errors : vErrors.concat(validate1892.errors);
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
validate1877.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
return false;
}
}
validate1877.errors = vErrors;
return errors === 0;
}
validate1877.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate1876(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1876.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate1877(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1877.errors : vErrors.concat(validate1877.errors);
errors = vErrors.length;
}
var _valid0 = _errs1 === errors;
valid0 = valid0 || _valid0;
if(_valid0){
var props0 = true;
}
const _errs2 = errors;
if(data !== null){
const err0 = {instancePath,schemaPath:"#/anyOf/1/type",keyword:"type",params:{type: "null"}};
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
const err1 = {instancePath,schemaPath:"#/anyOf",keyword:"anyOf",params:{}};
if(vErrors === null){
vErrors = [err1];
}
else {
vErrors.push(err1);
}
errors++;
validate1876.errors = vErrors;
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
validate1876.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate1876.evaluated = {"dynamicProps":true,"dynamicItems":false};


function validate1873(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1873.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if(((((data.reference === undefined) && (missing0 = "reference")) || ((data.ordinal === undefined) && (missing0 = "ordinal"))) || ((data.row === undefined) && (missing0 = "row"))) || ((data.complete_coverage === undefined) && (missing0 = "complete_coverage"))){
validate1873.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((((key0 === "reference") || (key0 === "ordinal")) || (key0 === "row")) || (key0 === "complete_coverage"))){
validate1873.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.reference !== undefined){
const _errs2 = errors;
if(!(validate1632(data.reference, {instancePath:instancePath+"/reference",parentData:data,parentDataProperty:"reference",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1632.errors : vErrors.concat(validate1632.errors);
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
if(!(validate1634(data.ordinal, {instancePath:instancePath+"/ordinal",parentData:data,parentDataProperty:"ordinal",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1634.errors : vErrors.concat(validate1634.errors);
errors = vErrors.length;
}
var valid0 = _errs3 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.row !== undefined){
const _errs4 = errors;
if(!(validate1876(data.row, {instancePath:instancePath+"/row",parentData:data,parentDataProperty:"row",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1876.errors : vErrors.concat(validate1876.errors);
errors = vErrors.length;
}
var valid0 = _errs4 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.complete_coverage !== undefined){
const _errs5 = errors;
if(!(validate1573(data.complete_coverage, {instancePath:instancePath+"/complete_coverage",parentData:data,parentDataProperty:"complete_coverage",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1573.errors : vErrors.concat(validate1573.errors);
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
validate1873.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
return false;
}
}
validate1873.errors = vErrors;
return errors === 0;
}
validate1873.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate1869(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1869.evaluated;
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
const err0 = {instancePath,schemaPath:"#/oneOf/0/required",keyword:"required",params:{missingProperty: missing0}};
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
const err1 = {instancePath,schemaPath:"#/oneOf/0/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}};
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
if(!(validate1566(data.capabilities, {instancePath:instancePath+"/capabilities",parentData:data,parentDataProperty:"capabilities",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1566.errors : vErrors.concat(validate1566.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err2 = {instancePath,schemaPath:"#/oneOf/0/type",keyword:"type",params:{type: "object"}};
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
if((data.explained === undefined) && (missing1 = "explained")){
const err3 = {instancePath,schemaPath:"#/oneOf/1/required",keyword:"required",params:{missingProperty: missing1}};
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
if(!(key1 === "explained")){
const err4 = {instancePath,schemaPath:"#/oneOf/1/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key1}};
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
if(data.explained !== undefined){
if(!(validate1639(data.explained, {instancePath:instancePath+"/explained",parentData:data,parentDataProperty:"explained",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1639.errors : vErrors.concat(validate1639.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err5 = {instancePath,schemaPath:"#/oneOf/1/type",keyword:"type",params:{type: "object"}};
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
if((data.opened === undefined) && (missing2 = "opened")){
const err6 = {instancePath,schemaPath:"#/oneOf/2/required",keyword:"required",params:{missingProperty: missing2}};
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
if(!(key2 === "opened")){
const err7 = {instancePath,schemaPath:"#/oneOf/2/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key2}};
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
if(data.opened !== undefined){
if(!(validate1631(data.opened, {instancePath:instancePath+"/opened",parentData:data,parentDataProperty:"opened",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1631.errors : vErrors.concat(validate1631.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err8 = {instancePath,schemaPath:"#/oneOf/2/type",keyword:"type",params:{type: "object"}};
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
if((data.page === undefined) && (missing3 = "page")){
const err9 = {instancePath,schemaPath:"#/oneOf/3/required",keyword:"required",params:{missingProperty: missing3}};
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
if(!(key3 === "page")){
const err10 = {instancePath,schemaPath:"#/oneOf/3/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key3}};
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
if(data.page !== undefined){
if(!(validate1873(data.page, {instancePath:instancePath+"/page",parentData:data,parentDataProperty:"page",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1873.errors : vErrors.concat(validate1873.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err11 = {instancePath,schemaPath:"#/oneOf/3/type",keyword:"type",params:{type: "object"}};
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
if((data.closed === undefined) && (missing4 = "closed")){
const err12 = {instancePath,schemaPath:"#/oneOf/4/required",keyword:"required",params:{missingProperty: missing4}};
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
if(!(key4 === "closed")){
const err13 = {instancePath,schemaPath:"#/oneOf/4/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key4}};
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
if(data.closed !== undefined){
if(!(validate1680(data.closed, {instancePath:instancePath+"/closed",parentData:data,parentDataProperty:"closed",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1680.errors : vErrors.concat(validate1680.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err14 = {instancePath,schemaPath:"#/oneOf/4/type",keyword:"type",params:{type: "object"}};
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
const err15 = {instancePath,schemaPath:"#/oneOf",keyword:"oneOf",params:{passingSchemas: passing0}};
if(vErrors === null){
vErrors = [err15];
}
else {
vErrors.push(err15);
}
errors++;
validate1869.errors = vErrors;
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
validate1869.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate1869.evaluated = {"dynamicProps":true,"dynamicItems":false};


function validate1564(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1564.evaluated;
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
const err0 = {instancePath,schemaPath:"#/oneOf/0/required",keyword:"required",params:{missingProperty: missing0}};
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
const err1 = {instancePath,schemaPath:"#/oneOf/0/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}};
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
if(!(validate1565(data.description, {instancePath:instancePath+"/description",parentData:data,parentDataProperty:"description",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1565.errors : vErrors.concat(validate1565.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err2 = {instancePath,schemaPath:"#/oneOf/0/type",keyword:"type",params:{type: "object"}};
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
if((data.storage === undefined) && (missing1 = "storage")){
const err3 = {instancePath,schemaPath:"#/oneOf/1/required",keyword:"required",params:{missingProperty: missing1}};
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
if(!(key1 === "storage")){
const err4 = {instancePath,schemaPath:"#/oneOf/1/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key1}};
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
if(data.storage !== undefined){
if(!(validate1804(data.storage, {instancePath:instancePath+"/storage",parentData:data,parentDataProperty:"storage",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1804.errors : vErrors.concat(validate1804.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err5 = {instancePath,schemaPath:"#/oneOf/1/type",keyword:"type",params:{type: "object"}};
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
if((data.query === undefined) && (missing2 = "query")){
const err6 = {instancePath,schemaPath:"#/oneOf/2/required",keyword:"required",params:{missingProperty: missing2}};
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
if(!(key2 === "query")){
const err7 = {instancePath,schemaPath:"#/oneOf/2/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key2}};
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
if(data.query !== undefined){
if(!(validate1869(data.query, {instancePath:instancePath+"/query",parentData:data,parentDataProperty:"query",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1869.errors : vErrors.concat(validate1869.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err8 = {instancePath,schemaPath:"#/oneOf/2/type",keyword:"type",params:{type: "object"}};
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
if((data.recovered === undefined) && (missing3 = "recovered")){
const err9 = {instancePath,schemaPath:"#/oneOf/3/required",keyword:"required",params:{missingProperty: missing3}};
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
if(!(key3 === "recovered")){
const err10 = {instancePath,schemaPath:"#/oneOf/3/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key3}};
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
if(data.recovered !== undefined){
if(!(validate1680(data.recovered, {instancePath:instancePath+"/recovered",parentData:data,parentDataProperty:"recovered",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1680.errors : vErrors.concat(validate1680.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err11 = {instancePath,schemaPath:"#/oneOf/3/type",keyword:"type",params:{type: "object"}};
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
const err12 = {instancePath,schemaPath:"#/oneOf",keyword:"oneOf",params:{passingSchemas: passing0}};
if(vErrors === null){
vErrors = [err12];
}
else {
vErrors.push(err12);
}
errors++;
validate1564.errors = vErrors;
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
validate1564.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate1564.evaluated = {"dynamicProps":true,"dynamicItems":false};
