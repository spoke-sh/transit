// Generated; no runtime code generation or eval.
import lengthModule from "ajv/dist/runtime/ucs2length.js";
const ucs2length = lengthModule.default ?? lengthModule;
"use strict";
export const RelationalRequest = validate1531;
const schema413 = {"oneOf":[{"type":"object","additionalProperties":false,"required":["describe"],"properties":{"describe":{"$ref":"#/$defs/RelationalRequest/$defs/T1"}}},{"type":"object","additionalProperties":false,"required":["storage"],"properties":{"storage":{"$ref":"#/$defs/RelationalRequest/$defs/T2"}}},{"type":"object","additionalProperties":false,"required":["query"],"properties":{"query":{"$ref":"#/$defs/RelationalRequest/$defs/T16"}}},{"type":"object","additionalProperties":false,"required":["recover"],"properties":{"recover":{"$ref":"#/$defs/RelationalRequest/$defs/T38"}}}]};
const schema414 = {"type":"object","maxProperties":0};

function validate1532(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1532.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
if(Object.keys(data).length > 0){
validate1532.errors = [{instancePath,schemaPath:"#/maxProperties",keyword:"maxProperties",params:{limit: 0}}];
return false;
}
}
else {
validate1532.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
return false;
}
}
validate1532.errors = vErrors;
return errors === 0;
}
validate1532.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema415 = {"type":"object","additionalProperties":false,"properties":{"route":{"$ref":"#/$defs/RelationalRequest/$defs/T3"},"binding":{"$ref":"#/$defs/RelationalRequest/$defs/T4"}},"required":["route","binding"]};
const schema26 = {"type":"integer","minimum":0,"maximum":65535};

function validate1535(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1535.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(!(((typeof data == "number") && (!(data % 1) && !isNaN(data))) && (isFinite(data)))){
validate1535.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "integer"}}];
return false;
}
if(errors === 0){
if((typeof data == "number") && (isFinite(data))){
if(data > 65535 || isNaN(data)){
validate1535.errors = [{instancePath,schemaPath:"#/maximum",keyword:"maximum",params:{comparison: "<=", limit: 65535}}];
return false;
}
else {
if(data < 0 || isNaN(data)){
validate1535.errors = [{instancePath,schemaPath:"#/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0}}];
return false;
}
}
}
}
validate1535.errors = vErrors;
return errors === 0;
}
validate1535.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema417 = {"type":"object","additionalProperties":false,"properties":{"definition":{"$ref":"#/$defs/RelationalRequest/$defs/T5"},"connection":{"$ref":"#/$defs/RelationalRequest/$defs/T6"},"namespace":{"$ref":"#/$defs/RelationalRequest/$defs/T8"},"name":{"$ref":"#/$defs/RelationalRequest/$defs/T9"},"interpretation":{"$ref":"#/$defs/RelationalRequest/$defs/T11"}},"required":["definition","connection","namespace","name","interpretation"]};
const schema55 = {"type":"string","enum":["9ccbb15686fea6ace7f101548f0957d9847446c09353f098543b2c20361b2fef"]};

function validate1538(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1538.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate1538.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"}}];
return false;
}
if(!(data === "9ccbb15686fea6ace7f101548f0957d9847446c09353f098543b2c20361b2fef")){
validate1538.errors = [{instancePath,schemaPath:"#/enum",keyword:"enum",params:{allowedValues: schema55.enum}}];
return false;
}
validate1538.errors = vErrors;
return errors === 0;
}
validate1538.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema419 = {"type":"object","additionalProperties":false,"properties":{"scope":{"$ref":"#/$defs/RelationalRequest/$defs/T7"},"branch":{"$ref":"#/$defs/RelationalRequest/$defs/T9"},"audience":{"$ref":"#/$defs/RelationalRequest/$defs/T8"},"principal":{"$ref":"#/$defs/RelationalRequest/$defs/T8"},"role":{"$ref":"#/$defs/RelationalRequest/$defs/T10"}},"required":["scope","branch","audience","principal","role"]};
const schema420 = {"type":"object","additionalProperties":false,"properties":{"realm":{"$ref":"#/$defs/RelationalRequest/$defs/T8"},"resource":{"$ref":"#/$defs/RelationalRequest/$defs/T8"},"catalog":{"$ref":"#/$defs/RelationalRequest/$defs/T9"}},"required":["realm","resource","catalog"]};
const schema22 = {"type":"integer","minimum":0,"maximum":9007199254740991};

function validate1542(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1542.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(!(((typeof data == "number") && (!(data % 1) && !isNaN(data))) && (isFinite(data)))){
validate1542.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "integer"}}];
return false;
}
if(errors === 0){
if((typeof data == "number") && (isFinite(data))){
if(data > 9007199254740991 || isNaN(data)){
validate1542.errors = [{instancePath,schemaPath:"#/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991}}];
return false;
}
else {
if(data < 0 || isNaN(data)){
validate1542.errors = [{instancePath,schemaPath:"#/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0}}];
return false;
}
}
}
}
validate1542.errors = vErrors;
return errors === 0;
}
validate1542.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema422 = {"type":"string","maxLength":4096};
const func4 = ucs2length;

function validate1545(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1545.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(typeof data === "string"){
if(func4(data) > 4096){
validate1545.errors = [{instancePath,schemaPath:"#/maxLength",keyword:"maxLength",params:{limit: 4096}}];
return false;
}
}
else {
validate1545.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"}}];
return false;
}
}
validate1545.errors = vErrors;
return errors === 0;
}
validate1545.evaluated = {"dynamicProps":false,"dynamicItems":false};


function validate1541(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1541.evaluated;
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
validate1541.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "realm") || (key0 === "resource")) || (key0 === "catalog"))){
validate1541.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.realm !== undefined){
const _errs2 = errors;
if(!(validate1542(data.realm, {instancePath:instancePath+"/realm",parentData:data,parentDataProperty:"realm",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1542.errors : vErrors.concat(validate1542.errors);
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
if(!(validate1542(data.resource, {instancePath:instancePath+"/resource",parentData:data,parentDataProperty:"resource",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1542.errors : vErrors.concat(validate1542.errors);
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
if(!(validate1545(data.catalog, {instancePath:instancePath+"/catalog",parentData:data,parentDataProperty:"catalog",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1545.errors : vErrors.concat(validate1545.errors);
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
validate1541.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
return false;
}
}
validate1541.errors = vErrors;
return errors === 0;
}
validate1541.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema423 = {"anyOf":[{"$ref":"#/$defs/RelationalRequest/$defs/T8"},{"type":"null"}]};

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
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate1542(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1542.errors : vErrors.concat(validate1542.errors);
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
validate1551.errors = vErrors;
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
validate1551.errors = vErrors;
return errors === 0;
}
validate1551.evaluated = {"dynamicProps":false,"dynamicItems":false};


function validate1540(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1540.evaluated;
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
validate1540.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((((key0 === "scope") || (key0 === "branch")) || (key0 === "audience")) || (key0 === "principal")) || (key0 === "role"))){
validate1540.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.scope !== undefined){
const _errs2 = errors;
if(!(validate1541(data.scope, {instancePath:instancePath+"/scope",parentData:data,parentDataProperty:"scope",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1541.errors : vErrors.concat(validate1541.errors);
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
if(!(validate1545(data.branch, {instancePath:instancePath+"/branch",parentData:data,parentDataProperty:"branch",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1545.errors : vErrors.concat(validate1545.errors);
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
if(!(validate1542(data.audience, {instancePath:instancePath+"/audience",parentData:data,parentDataProperty:"audience",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1542.errors : vErrors.concat(validate1542.errors);
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
if(!(validate1542(data.principal, {instancePath:instancePath+"/principal",parentData:data,parentDataProperty:"principal",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1542.errors : vErrors.concat(validate1542.errors);
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
if(!(validate1551(data.role, {instancePath:instancePath+"/role",parentData:data,parentDataProperty:"role",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1551.errors : vErrors.concat(validate1551.errors);
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
validate1540.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
return false;
}
}
validate1540.errors = vErrors;
return errors === 0;
}
validate1540.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema424 = {"type":"object","additionalProperties":false,"properties":{"interpretation":{"$ref":"#/$defs/RelationalRequest/$defs/T12"},"content":{"$ref":"#/$defs/RelationalRequest/$defs/T14"},"schema_fingerprint":{"$ref":"#/$defs/RelationalRequest/$defs/T9"},"retired":{"$ref":"#/$defs/RelationalRequest/$defs/T15"}},"required":["interpretation","content","schema_fingerprint","retired"]};
const schema425 = {"type":"object","additionalProperties":false,"properties":{"object":{"$ref":"#/$defs/RelationalRequest/$defs/T13"},"revision":{"$ref":"#/$defs/RelationalRequest/$defs/T9"},"digest":{"$ref":"#/$defs/RelationalRequest/$defs/T9"}},"required":["object","revision","digest"]};
const schema426 = {"type":"object","additionalProperties":false,"properties":{"scope":{"$ref":"#/$defs/RelationalRequest/$defs/T7"},"branch":{"$ref":"#/$defs/RelationalRequest/$defs/T9"},"object":{"$ref":"#/$defs/RelationalRequest/$defs/T9"}},"required":["scope","branch","object"]};

function validate1559(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1559.evaluated;
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
validate1559.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "scope") || (key0 === "branch")) || (key0 === "object"))){
validate1559.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.scope !== undefined){
const _errs2 = errors;
if(!(validate1541(data.scope, {instancePath:instancePath+"/scope",parentData:data,parentDataProperty:"scope",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1541.errors : vErrors.concat(validate1541.errors);
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
if(!(validate1545(data.branch, {instancePath:instancePath+"/branch",parentData:data,parentDataProperty:"branch",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1545.errors : vErrors.concat(validate1545.errors);
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
if(!(validate1545(data.object, {instancePath:instancePath+"/object",parentData:data,parentDataProperty:"object",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1545.errors : vErrors.concat(validate1545.errors);
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
validate1559.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
return false;
}
}
validate1559.errors = vErrors;
return errors === 0;
}
validate1559.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate1558(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1558.evaluated;
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
validate1558.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "object") || (key0 === "revision")) || (key0 === "digest"))){
validate1558.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.object !== undefined){
const _errs2 = errors;
if(!(validate1559(data.object, {instancePath:instancePath+"/object",parentData:data,parentDataProperty:"object",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1559.errors : vErrors.concat(validate1559.errors);
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
if(!(validate1545(data.revision, {instancePath:instancePath+"/revision",parentData:data,parentDataProperty:"revision",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1545.errors : vErrors.concat(validate1545.errors);
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
if(!(validate1545(data.digest, {instancePath:instancePath+"/digest",parentData:data,parentDataProperty:"digest",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1545.errors : vErrors.concat(validate1545.errors);
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
validate1558.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
return false;
}
}
validate1558.errors = vErrors;
return errors === 0;
}
validate1558.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema427 = {"type":"object","additionalProperties":false,"properties":{"bytes":{"$ref":"#/$defs/RelationalRequest/$defs/T9"},"sha256":{"$ref":"#/$defs/RelationalRequest/$defs/T9"}},"required":["bytes","sha256"]};

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
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if(((data.bytes === undefined) && (missing0 = "bytes")) || ((data.sha256 === undefined) && (missing0 = "sha256"))){
validate1567.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "bytes") || (key0 === "sha256"))){
validate1567.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.bytes !== undefined){
const _errs2 = errors;
if(!(validate1545(data.bytes, {instancePath:instancePath+"/bytes",parentData:data,parentDataProperty:"bytes",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1545.errors : vErrors.concat(validate1545.errors);
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
if(!(validate1545(data.sha256, {instancePath:instancePath+"/sha256",parentData:data,parentDataProperty:"sha256",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1545.errors : vErrors.concat(validate1545.errors);
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
validate1567.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
return false;
}
}
validate1567.errors = vErrors;
return errors === 0;
}
validate1567.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema428 = {"type":"boolean"};

function validate1572(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1572.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "boolean"){
validate1572.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "boolean"}}];
return false;
}
validate1572.errors = vErrors;
return errors === 0;
}
validate1572.evaluated = {"dynamicProps":false,"dynamicItems":false};


function validate1557(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1557.evaluated;
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
validate1557.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((((key0 === "interpretation") || (key0 === "content")) || (key0 === "schema_fingerprint")) || (key0 === "retired"))){
validate1557.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.interpretation !== undefined){
const _errs2 = errors;
if(!(validate1558(data.interpretation, {instancePath:instancePath+"/interpretation",parentData:data,parentDataProperty:"interpretation",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1558.errors : vErrors.concat(validate1558.errors);
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
if(!(validate1567(data.content, {instancePath:instancePath+"/content",parentData:data,parentDataProperty:"content",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1567.errors : vErrors.concat(validate1567.errors);
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
if(!(validate1545(data.schema_fingerprint, {instancePath:instancePath+"/schema_fingerprint",parentData:data,parentDataProperty:"schema_fingerprint",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1545.errors : vErrors.concat(validate1545.errors);
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
if(!(validate1572(data.retired, {instancePath:instancePath+"/retired",parentData:data,parentDataProperty:"retired",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1572.errors : vErrors.concat(validate1572.errors);
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
validate1557.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
return false;
}
}
validate1557.errors = vErrors;
return errors === 0;
}
validate1557.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate1537(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1537.evaluated;
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
validate1537.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((((key0 === "definition") || (key0 === "connection")) || (key0 === "namespace")) || (key0 === "name")) || (key0 === "interpretation"))){
validate1537.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.definition !== undefined){
const _errs2 = errors;
if(!(validate1538(data.definition, {instancePath:instancePath+"/definition",parentData:data,parentDataProperty:"definition",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1538.errors : vErrors.concat(validate1538.errors);
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
if(!(validate1540(data.connection, {instancePath:instancePath+"/connection",parentData:data,parentDataProperty:"connection",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1540.errors : vErrors.concat(validate1540.errors);
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
if(!(validate1542(data.namespace, {instancePath:instancePath+"/namespace",parentData:data,parentDataProperty:"namespace",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1542.errors : vErrors.concat(validate1542.errors);
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
if(!(validate1545(data.name, {instancePath:instancePath+"/name",parentData:data,parentDataProperty:"name",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1545.errors : vErrors.concat(validate1545.errors);
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
if(!(validate1557(data.interpretation, {instancePath:instancePath+"/interpretation",parentData:data,parentDataProperty:"interpretation",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1557.errors : vErrors.concat(validate1557.errors);
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
validate1537.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
return false;
}
}
validate1537.errors = vErrors;
return errors === 0;
}
validate1537.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


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
if(((data.route === undefined) && (missing0 = "route")) || ((data.binding === undefined) && (missing0 = "binding"))){
validate1534.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "route") || (key0 === "binding"))){
validate1534.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.route !== undefined){
const _errs2 = errors;
if(!(validate1535(data.route, {instancePath:instancePath+"/route",parentData:data,parentDataProperty:"route",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1535.errors : vErrors.concat(validate1535.errors);
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
if(!(validate1537(data.binding, {instancePath:instancePath+"/binding",parentData:data,parentDataProperty:"binding",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1537.errors : vErrors.concat(validate1537.errors);
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

const schema429 = {"oneOf":[{"type":"object","additionalProperties":false,"required":["capabilities"],"properties":{"capabilities":{"$ref":"#/$defs/RelationalRequest/$defs/T1"}}},{"type":"object","additionalProperties":false,"required":["explain"],"properties":{"explain":{"$ref":"#/$defs/RelationalRequest/$defs/T17"}}},{"type":"object","additionalProperties":false,"required":["open"],"properties":{"open":{"$ref":"#/$defs/RelationalRequest/$defs/T20"}}},{"type":"object","additionalProperties":false,"required":["page"],"properties":{"page":{"$ref":"#/$defs/RelationalRequest/$defs/T36"}}},{"type":"object","additionalProperties":false,"required":["close"],"properties":{"close":{"$ref":"#/$defs/RelationalRequest/$defs/T37"}}}]};
const schema430 = {"type":"object","additionalProperties":false,"properties":{"namespace":{"$ref":"#/$defs/RelationalRequest/$defs/T8"},"sql":{"$ref":"#/$defs/RelationalRequest/$defs/T9"},"routes":{"$ref":"#/$defs/RelationalRequest/$defs/T18"}},"required":["sql","routes"]};
const schema431 = {"type":"array","maxItems":2,"items":{"$ref":"#/$defs/RelationalRequest/$defs/T19"}};

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
if(!(((typeof data == "number") && (!(data % 1) && !isNaN(data))) && (isFinite(data)))){
validate1583.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "integer"}}];
return false;
}
if(errors === 0){
if((typeof data == "number") && (isFinite(data))){
if(data > 65535 || isNaN(data)){
validate1583.errors = [{instancePath,schemaPath:"#/maximum",keyword:"maximum",params:{comparison: "<=", limit: 65535}}];
return false;
}
else {
if(data < 0 || isNaN(data)){
validate1583.errors = [{instancePath,schemaPath:"#/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0}}];
return false;
}
}
}
}
validate1583.errors = vErrors;
return errors === 0;
}
validate1583.evaluated = {"dynamicProps":false,"dynamicItems":false};


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
if(Array.isArray(data)){
if(data.length > 2){
validate1582.errors = [{instancePath,schemaPath:"#/maxItems",keyword:"maxItems",params:{limit: 2}}];
return false;
}
else {
var valid0 = true;
const len0 = data.length;
for(let i0=0; i0<len0; i0++){
const _errs1 = errors;
if(!(validate1583(data[i0], {instancePath:instancePath+"/" + i0,parentData:data,parentDataProperty:i0,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1583.errors : vErrors.concat(validate1583.errors);
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
validate1582.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "array"}}];
return false;
}
}
validate1582.errors = vErrors;
return errors === 0;
}
validate1582.evaluated = {"items":true,"dynamicProps":false,"dynamicItems":false};


function validate1579(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1579.evaluated;
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
validate1579.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "namespace") || (key0 === "sql")) || (key0 === "routes"))){
validate1579.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.namespace !== undefined){
const _errs2 = errors;
if(!(validate1542(data.namespace, {instancePath:instancePath+"/namespace",parentData:data,parentDataProperty:"namespace",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1542.errors : vErrors.concat(validate1542.errors);
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
if(!(validate1545(data.sql, {instancePath:instancePath+"/sql",parentData:data,parentDataProperty:"sql",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1545.errors : vErrors.concat(validate1545.errors);
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
if(!(validate1582(data.routes, {instancePath:instancePath+"/routes",parentData:data,parentDataProperty:"routes",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1582.errors : vErrors.concat(validate1582.errors);
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
validate1579.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
return false;
}
}
validate1579.errors = vErrors;
return errors === 0;
}
validate1579.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema433 = {"type":"object","additionalProperties":false,"properties":{"id":{"$ref":"#/$defs/RelationalRequest/$defs/T9"},"statement":{"$ref":"#/$defs/RelationalRequest/$defs/T17"},"sources":{"$ref":"#/$defs/RelationalRequest/$defs/T21"}},"required":["id","statement","sources"]};
const schema434 = {"type":"array","maxItems":2,"items":{"$ref":"#/$defs/RelationalRequest/$defs/T22"}};
const schema435 = {"type":"object","additionalProperties":false,"properties":{"alias":{"$ref":"#/$defs/RelationalRequest/$defs/T23"},"binding":{"$ref":"#/$defs/RelationalRequest/$defs/T24"},"position":{"$ref":"#/$defs/RelationalRequest/$defs/T35"}},"required":["alias","binding","position"]};
const schema436 = {"type":"string","maxLength":4096};

function validate1592(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1592.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(typeof data === "string"){
if(func4(data) > 4096){
validate1592.errors = [{instancePath,schemaPath:"#/maxLength",keyword:"maxLength",params:{limit: 4096}}];
return false;
}
}
else {
validate1592.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"}}];
return false;
}
}
validate1592.errors = vErrors;
return errors === 0;
}
validate1592.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema437 = {"type":"object","additionalProperties":false,"properties":{"definition":{"$ref":"#/$defs/RelationalRequest/$defs/T25"},"connection":{"$ref":"#/$defs/RelationalRequest/$defs/T26"},"namespace":{"$ref":"#/$defs/RelationalRequest/$defs/T28"},"name":{"$ref":"#/$defs/RelationalRequest/$defs/T23"},"interpretation":{"$ref":"#/$defs/RelationalRequest/$defs/T30"}},"required":["definition","connection","namespace","name","interpretation"]};

function validate1595(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1595.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate1595.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"}}];
return false;
}
if(!(data === "9ccbb15686fea6ace7f101548f0957d9847446c09353f098543b2c20361b2fef")){
validate1595.errors = [{instancePath,schemaPath:"#/enum",keyword:"enum",params:{allowedValues: schema55.enum}}];
return false;
}
validate1595.errors = vErrors;
return errors === 0;
}
validate1595.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema439 = {"type":"object","additionalProperties":false,"properties":{"scope":{"$ref":"#/$defs/RelationalRequest/$defs/T27"},"branch":{"$ref":"#/$defs/RelationalRequest/$defs/T23"},"audience":{"$ref":"#/$defs/RelationalRequest/$defs/T28"},"principal":{"$ref":"#/$defs/RelationalRequest/$defs/T28"},"role":{"$ref":"#/$defs/RelationalRequest/$defs/T29"}},"required":["scope","branch","audience","principal","role"]};
const schema440 = {"type":"object","additionalProperties":false,"properties":{"realm":{"$ref":"#/$defs/RelationalRequest/$defs/T28"},"resource":{"$ref":"#/$defs/RelationalRequest/$defs/T28"},"catalog":{"$ref":"#/$defs/RelationalRequest/$defs/T23"}},"required":["realm","resource","catalog"]};

function validate1599(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1599.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(!(((typeof data == "number") && (!(data % 1) && !isNaN(data))) && (isFinite(data)))){
validate1599.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "integer"}}];
return false;
}
if(errors === 0){
if((typeof data == "number") && (isFinite(data))){
if(data > 9007199254740991 || isNaN(data)){
validate1599.errors = [{instancePath,schemaPath:"#/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991}}];
return false;
}
else {
if(data < 0 || isNaN(data)){
validate1599.errors = [{instancePath,schemaPath:"#/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0}}];
return false;
}
}
}
}
validate1599.errors = vErrors;
return errors === 0;
}
validate1599.evaluated = {"dynamicProps":false,"dynamicItems":false};


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
if((((data.realm === undefined) && (missing0 = "realm")) || ((data.resource === undefined) && (missing0 = "resource"))) || ((data.catalog === undefined) && (missing0 = "catalog"))){
validate1598.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "realm") || (key0 === "resource")) || (key0 === "catalog"))){
validate1598.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.realm !== undefined){
const _errs2 = errors;
if(!(validate1599(data.realm, {instancePath:instancePath+"/realm",parentData:data,parentDataProperty:"realm",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1599.errors : vErrors.concat(validate1599.errors);
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
if(!(validate1599(data.resource, {instancePath:instancePath+"/resource",parentData:data,parentDataProperty:"resource",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1599.errors : vErrors.concat(validate1599.errors);
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
if(!(validate1592(data.catalog, {instancePath:instancePath+"/catalog",parentData:data,parentDataProperty:"catalog",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1592.errors : vErrors.concat(validate1592.errors);
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
validate1598.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
return false;
}
}
validate1598.errors = vErrors;
return errors === 0;
}
validate1598.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema442 = {"anyOf":[{"$ref":"#/$defs/RelationalRequest/$defs/T28"},{"type":"null"}]};

function validate1607(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1607.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate1599(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1599.errors : vErrors.concat(validate1599.errors);
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
validate1607.errors = vErrors;
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
validate1607.errors = vErrors;
return errors === 0;
}
validate1607.evaluated = {"dynamicProps":false,"dynamicItems":false};


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
if((((((data.scope === undefined) && (missing0 = "scope")) || ((data.branch === undefined) && (missing0 = "branch"))) || ((data.audience === undefined) && (missing0 = "audience"))) || ((data.principal === undefined) && (missing0 = "principal"))) || ((data.role === undefined) && (missing0 = "role"))){
validate1597.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((((key0 === "scope") || (key0 === "branch")) || (key0 === "audience")) || (key0 === "principal")) || (key0 === "role"))){
validate1597.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.scope !== undefined){
const _errs2 = errors;
if(!(validate1598(data.scope, {instancePath:instancePath+"/scope",parentData:data,parentDataProperty:"scope",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1598.errors : vErrors.concat(validate1598.errors);
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
if(!(validate1592(data.branch, {instancePath:instancePath+"/branch",parentData:data,parentDataProperty:"branch",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1592.errors : vErrors.concat(validate1592.errors);
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
if(!(validate1599(data.audience, {instancePath:instancePath+"/audience",parentData:data,parentDataProperty:"audience",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1599.errors : vErrors.concat(validate1599.errors);
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
if(!(validate1599(data.principal, {instancePath:instancePath+"/principal",parentData:data,parentDataProperty:"principal",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1599.errors : vErrors.concat(validate1599.errors);
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
if(!(validate1607(data.role, {instancePath:instancePath+"/role",parentData:data,parentDataProperty:"role",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1607.errors : vErrors.concat(validate1607.errors);
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
validate1597.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
return false;
}
}
validate1597.errors = vErrors;
return errors === 0;
}
validate1597.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema443 = {"type":"object","additionalProperties":false,"properties":{"interpretation":{"$ref":"#/$defs/RelationalRequest/$defs/T31"},"content":{"$ref":"#/$defs/RelationalRequest/$defs/T33"},"schema_fingerprint":{"$ref":"#/$defs/RelationalRequest/$defs/T23"},"retired":{"$ref":"#/$defs/RelationalRequest/$defs/T34"}},"required":["interpretation","content","schema_fingerprint","retired"]};
const schema444 = {"type":"object","additionalProperties":false,"properties":{"object":{"$ref":"#/$defs/RelationalRequest/$defs/T32"},"revision":{"$ref":"#/$defs/RelationalRequest/$defs/T23"},"digest":{"$ref":"#/$defs/RelationalRequest/$defs/T23"}},"required":["object","revision","digest"]};
const schema445 = {"type":"object","additionalProperties":false,"properties":{"scope":{"$ref":"#/$defs/RelationalRequest/$defs/T27"},"branch":{"$ref":"#/$defs/RelationalRequest/$defs/T23"},"object":{"$ref":"#/$defs/RelationalRequest/$defs/T23"}},"required":["scope","branch","object"]};

function validate1615(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1615.evaluated;
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
validate1615.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "scope") || (key0 === "branch")) || (key0 === "object"))){
validate1615.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.scope !== undefined){
const _errs2 = errors;
if(!(validate1598(data.scope, {instancePath:instancePath+"/scope",parentData:data,parentDataProperty:"scope",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1598.errors : vErrors.concat(validate1598.errors);
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
if(!(validate1592(data.branch, {instancePath:instancePath+"/branch",parentData:data,parentDataProperty:"branch",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1592.errors : vErrors.concat(validate1592.errors);
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
if(!(validate1592(data.object, {instancePath:instancePath+"/object",parentData:data,parentDataProperty:"object",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1592.errors : vErrors.concat(validate1592.errors);
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
validate1615.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
return false;
}
}
validate1615.errors = vErrors;
return errors === 0;
}
validate1615.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


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
if((((data.object === undefined) && (missing0 = "object")) || ((data.revision === undefined) && (missing0 = "revision"))) || ((data.digest === undefined) && (missing0 = "digest"))){
validate1614.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "object") || (key0 === "revision")) || (key0 === "digest"))){
validate1614.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.object !== undefined){
const _errs2 = errors;
if(!(validate1615(data.object, {instancePath:instancePath+"/object",parentData:data,parentDataProperty:"object",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1615.errors : vErrors.concat(validate1615.errors);
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
if(!(validate1592(data.revision, {instancePath:instancePath+"/revision",parentData:data,parentDataProperty:"revision",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1592.errors : vErrors.concat(validate1592.errors);
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
if(!(validate1592(data.digest, {instancePath:instancePath+"/digest",parentData:data,parentDataProperty:"digest",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1592.errors : vErrors.concat(validate1592.errors);
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
validate1614.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
return false;
}
}
validate1614.errors = vErrors;
return errors === 0;
}
validate1614.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema446 = {"type":"object","additionalProperties":false,"properties":{"bytes":{"$ref":"#/$defs/RelationalRequest/$defs/T23"},"sha256":{"$ref":"#/$defs/RelationalRequest/$defs/T23"}},"required":["bytes","sha256"]};

function validate1623(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1623.evaluated;
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
validate1623.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "bytes") || (key0 === "sha256"))){
validate1623.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.bytes !== undefined){
const _errs2 = errors;
if(!(validate1592(data.bytes, {instancePath:instancePath+"/bytes",parentData:data,parentDataProperty:"bytes",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1592.errors : vErrors.concat(validate1592.errors);
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
if(!(validate1592(data.sha256, {instancePath:instancePath+"/sha256",parentData:data,parentDataProperty:"sha256",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1592.errors : vErrors.concat(validate1592.errors);
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
validate1623.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
return false;
}
}
validate1623.errors = vErrors;
return errors === 0;
}
validate1623.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema447 = {"type":"boolean"};

function validate1628(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1628.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "boolean"){
validate1628.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "boolean"}}];
return false;
}
validate1628.errors = vErrors;
return errors === 0;
}
validate1628.evaluated = {"dynamicProps":false,"dynamicItems":false};


function validate1613(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1613.evaluated;
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
validate1613.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((((key0 === "interpretation") || (key0 === "content")) || (key0 === "schema_fingerprint")) || (key0 === "retired"))){
validate1613.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.interpretation !== undefined){
const _errs2 = errors;
if(!(validate1614(data.interpretation, {instancePath:instancePath+"/interpretation",parentData:data,parentDataProperty:"interpretation",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1614.errors : vErrors.concat(validate1614.errors);
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
if(!(validate1623(data.content, {instancePath:instancePath+"/content",parentData:data,parentDataProperty:"content",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1623.errors : vErrors.concat(validate1623.errors);
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
if(!(validate1592(data.schema_fingerprint, {instancePath:instancePath+"/schema_fingerprint",parentData:data,parentDataProperty:"schema_fingerprint",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1592.errors : vErrors.concat(validate1592.errors);
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
if(!(validate1628(data.retired, {instancePath:instancePath+"/retired",parentData:data,parentDataProperty:"retired",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1628.errors : vErrors.concat(validate1628.errors);
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
validate1613.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
return false;
}
}
validate1613.errors = vErrors;
return errors === 0;
}
validate1613.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate1594(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1594.evaluated;
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
validate1594.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((((key0 === "definition") || (key0 === "connection")) || (key0 === "namespace")) || (key0 === "name")) || (key0 === "interpretation"))){
validate1594.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.definition !== undefined){
const _errs2 = errors;
if(!(validate1595(data.definition, {instancePath:instancePath+"/definition",parentData:data,parentDataProperty:"definition",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1595.errors : vErrors.concat(validate1595.errors);
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
if(!(validate1597(data.connection, {instancePath:instancePath+"/connection",parentData:data,parentDataProperty:"connection",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1597.errors : vErrors.concat(validate1597.errors);
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
if(!(validate1599(data.namespace, {instancePath:instancePath+"/namespace",parentData:data,parentDataProperty:"namespace",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1599.errors : vErrors.concat(validate1599.errors);
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
if(!(validate1592(data.name, {instancePath:instancePath+"/name",parentData:data,parentDataProperty:"name",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1592.errors : vErrors.concat(validate1592.errors);
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
if(!(validate1613(data.interpretation, {instancePath:instancePath+"/interpretation",parentData:data,parentDataProperty:"interpretation",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1613.errors : vErrors.concat(validate1613.errors);
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
validate1594.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
return false;
}
}
validate1594.errors = vErrors;
return errors === 0;
}
validate1594.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema448 = {"type":"object","additionalProperties":false,"properties":{"partition":{"$ref":"#/$defs/RelationalRequest/$defs/T23"},"next_lsn":{"$ref":"#/$defs/RelationalRequest/$defs/T23"}},"required":["partition","next_lsn"]};

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
if(((data.partition === undefined) && (missing0 = "partition")) || ((data.next_lsn === undefined) && (missing0 = "next_lsn"))){
validate1632.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "partition") || (key0 === "next_lsn"))){
validate1632.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.partition !== undefined){
const _errs2 = errors;
if(!(validate1592(data.partition, {instancePath:instancePath+"/partition",parentData:data,parentDataProperty:"partition",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1592.errors : vErrors.concat(validate1592.errors);
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
if(!(validate1592(data.next_lsn, {instancePath:instancePath+"/next_lsn",parentData:data,parentDataProperty:"next_lsn",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1592.errors : vErrors.concat(validate1592.errors);
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
validate1632.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
return false;
}
}
validate1632.errors = vErrors;
return errors === 0;
}
validate1632.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate1591(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1591.evaluated;
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
validate1591.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "alias") || (key0 === "binding")) || (key0 === "position"))){
validate1591.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.alias !== undefined){
const _errs2 = errors;
if(!(validate1592(data.alias, {instancePath:instancePath+"/alias",parentData:data,parentDataProperty:"alias",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1592.errors : vErrors.concat(validate1592.errors);
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
if(!(validate1594(data.binding, {instancePath:instancePath+"/binding",parentData:data,parentDataProperty:"binding",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1594.errors : vErrors.concat(validate1594.errors);
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
if(!(validate1632(data.position, {instancePath:instancePath+"/position",parentData:data,parentDataProperty:"position",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1632.errors : vErrors.concat(validate1632.errors);
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
validate1591.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
return false;
}
}
validate1591.errors = vErrors;
return errors === 0;
}
validate1591.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate1590(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1590.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(Array.isArray(data)){
if(data.length > 2){
validate1590.errors = [{instancePath,schemaPath:"#/maxItems",keyword:"maxItems",params:{limit: 2}}];
return false;
}
else {
var valid0 = true;
const len0 = data.length;
for(let i0=0; i0<len0; i0++){
const _errs1 = errors;
if(!(validate1591(data[i0], {instancePath:instancePath+"/" + i0,parentData:data,parentDataProperty:i0,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1591.errors : vErrors.concat(validate1591.errors);
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
validate1590.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "array"}}];
return false;
}
}
validate1590.errors = vErrors;
return errors === 0;
}
validate1590.evaluated = {"items":true,"dynamicProps":false,"dynamicItems":false};


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
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((((data.id === undefined) && (missing0 = "id")) || ((data.statement === undefined) && (missing0 = "statement"))) || ((data.sources === undefined) && (missing0 = "sources"))){
validate1587.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "id") || (key0 === "statement")) || (key0 === "sources"))){
validate1587.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.id !== undefined){
const _errs2 = errors;
if(!(validate1545(data.id, {instancePath:instancePath+"/id",parentData:data,parentDataProperty:"id",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1545.errors : vErrors.concat(validate1545.errors);
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
if(!(validate1579(data.statement, {instancePath:instancePath+"/statement",parentData:data,parentDataProperty:"statement",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1579.errors : vErrors.concat(validate1579.errors);
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
if(!(validate1590(data.sources, {instancePath:instancePath+"/sources",parentData:data,parentDataProperty:"sources",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1590.errors : vErrors.concat(validate1590.errors);
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
validate1587.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
return false;
}
}
validate1587.errors = vErrors;
return errors === 0;
}
validate1587.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema449 = {"type":"object","additionalProperties":false,"properties":{"reference":{"$ref":"#/$defs/RelationalRequest/$defs/T37"},"ordinal":{"$ref":"#/$defs/RelationalRequest/$defs/T9"}},"required":["reference","ordinal"]};
const schema450 = {"type":"object","additionalProperties":false,"properties":{"definition":{"$ref":"#/$defs/RelationalRequest/$defs/T5"},"id":{"$ref":"#/$defs/RelationalRequest/$defs/T9"},"plan":{"$ref":"#/$defs/RelationalRequest/$defs/T9"},"basis":{"$ref":"#/$defs/RelationalRequest/$defs/T9"}},"required":["definition","id","plan","basis"]};

function validate1640(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1640.evaluated;
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
validate1640.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((((key0 === "definition") || (key0 === "id")) || (key0 === "plan")) || (key0 === "basis"))){
validate1640.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.definition !== undefined){
const _errs2 = errors;
if(!(validate1538(data.definition, {instancePath:instancePath+"/definition",parentData:data,parentDataProperty:"definition",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1538.errors : vErrors.concat(validate1538.errors);
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
if(!(validate1545(data.id, {instancePath:instancePath+"/id",parentData:data,parentDataProperty:"id",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1545.errors : vErrors.concat(validate1545.errors);
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
if(!(validate1545(data.plan, {instancePath:instancePath+"/plan",parentData:data,parentDataProperty:"plan",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1545.errors : vErrors.concat(validate1545.errors);
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
if(!(validate1545(data.basis, {instancePath:instancePath+"/basis",parentData:data,parentDataProperty:"basis",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1545.errors : vErrors.concat(validate1545.errors);
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
validate1640.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
return false;
}
}
validate1640.errors = vErrors;
return errors === 0;
}
validate1640.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


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
if(((data.reference === undefined) && (missing0 = "reference")) || ((data.ordinal === undefined) && (missing0 = "ordinal"))){
validate1639.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "reference") || (key0 === "ordinal"))){
validate1639.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.reference !== undefined){
const _errs2 = errors;
if(!(validate1640(data.reference, {instancePath:instancePath+"/reference",parentData:data,parentDataProperty:"reference",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1640.errors : vErrors.concat(validate1640.errors);
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
if(!(validate1545(data.ordinal, {instancePath:instancePath+"/ordinal",parentData:data,parentDataProperty:"ordinal",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1545.errors : vErrors.concat(validate1545.errors);
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
validate1639.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
return false;
}
}
validate1639.errors = vErrors;
return errors === 0;
}
validate1639.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


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
if(!(validate1532(data.capabilities, {instancePath:instancePath+"/capabilities",parentData:data,parentDataProperty:"capabilities",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1532.errors : vErrors.concat(validate1532.errors);
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
if(!(validate1579(data.explain, {instancePath:instancePath+"/explain",parentData:data,parentDataProperty:"explain",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1579.errors : vErrors.concat(validate1579.errors);
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
if(!(validate1587(data.open, {instancePath:instancePath+"/open",parentData:data,parentDataProperty:"open",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1587.errors : vErrors.concat(validate1587.errors);
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
if(!(validate1639(data.page, {instancePath:instancePath+"/page",parentData:data,parentDataProperty:"page",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1639.errors : vErrors.concat(validate1639.errors);
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
if(!(validate1640(data.close, {instancePath:instancePath+"/close",parentData:data,parentDataProperty:"close",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1640.errors : vErrors.concat(validate1640.errors);
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
validate1577.errors = vErrors;
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
validate1577.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate1577.evaluated = {"dynamicProps":true,"dynamicItems":false};

const schema451 = {"type":"object","additionalProperties":false,"properties":{"id":{"$ref":"#/$defs/RelationalRequest/$defs/T9"}},"required":["id"]};

function validate1650(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1650.evaluated;
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
validate1650.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(key0 === "id")){
validate1650.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.id !== undefined){
if(!(validate1545(data.id, {instancePath:instancePath+"/id",parentData:data,parentDataProperty:"id",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1545.errors : vErrors.concat(validate1545.errors);
errors = vErrors.length;
}
}
}
}
}
else {
validate1650.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
return false;
}
}
validate1650.errors = vErrors;
return errors === 0;
}
validate1650.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate1531(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1531.evaluated;
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
if(!(validate1532(data.describe, {instancePath:instancePath+"/describe",parentData:data,parentDataProperty:"describe",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1532.errors : vErrors.concat(validate1532.errors);
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
if(!(validate1534(data.storage, {instancePath:instancePath+"/storage",parentData:data,parentDataProperty:"storage",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1534.errors : vErrors.concat(validate1534.errors);
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
if(!(validate1577(data.query, {instancePath:instancePath+"/query",parentData:data,parentDataProperty:"query",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1577.errors : vErrors.concat(validate1577.errors);
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
if(!(validate1650(data.recover, {instancePath:instancePath+"/recover",parentData:data,parentDataProperty:"recover",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1650.errors : vErrors.concat(validate1650.errors);
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
validate1531.errors = vErrors;
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
validate1531.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate1531.evaluated = {"dynamicProps":true,"dynamicItems":false};

export const RelationalResponse = validate1653;
const schema452 = {"oneOf":[{"type":"object","additionalProperties":false,"required":["description"],"properties":{"description":{"$ref":"#/$defs/RelationalResponse/$defs/T1"}}},{"type":"object","additionalProperties":false,"required":["storage"],"properties":{"storage":{"$ref":"#/$defs/RelationalResponse/$defs/T72"}}},{"type":"object","additionalProperties":false,"required":["query"],"properties":{"query":{"$ref":"#/$defs/RelationalResponse/$defs/T85"}}},{"type":"object","additionalProperties":false,"required":["recovered"],"properties":{"recovered":{"$ref":"#/$defs/RelationalResponse/$defs/T39"}}}]};
const schema453 = {"type":"object","additionalProperties":false,"properties":{"capabilities":{"$ref":"#/$defs/RelationalResponse/$defs/T2"},"routes":{"$ref":"#/$defs/RelationalResponse/$defs/T7"},"active":{"$ref":"#/$defs/RelationalResponse/$defs/T20"},"recovery":{"$ref":"#/$defs/RelationalResponse/$defs/T69"}},"required":["capabilities","routes","active","recovery"]};
const schema454 = {"type":"object","additionalProperties":false,"properties":{"definition":{"$ref":"#/$defs/RelationalResponse/$defs/T3"},"sources":{"$ref":"#/$defs/RelationalResponse/$defs/T4"},"active_queries":{"$ref":"#/$defs/RelationalResponse/$defs/T4"},"page_rows":{"$ref":"#/$defs/RelationalResponse/$defs/T4"},"interactive":{"$ref":"#/$defs/RelationalResponse/$defs/T5"},"captured":{"$ref":"#/$defs/RelationalResponse/$defs/T5"},"maintained":{"$ref":"#/$defs/RelationalResponse/$defs/T5"},"consistency":{"$ref":"#/$defs/RelationalResponse/$defs/T6"}},"required":["definition","sources","active_queries","page_rows","interactive","captured","maintained","consistency"]};

function validate1656(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1656.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate1656.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"}}];
return false;
}
if(!(data === "9ccbb15686fea6ace7f101548f0957d9847446c09353f098543b2c20361b2fef")){
validate1656.errors = [{instancePath,schemaPath:"#/enum",keyword:"enum",params:{allowedValues: schema55.enum}}];
return false;
}
validate1656.errors = vErrors;
return errors === 0;
}
validate1656.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema36 = {"type":"integer","minimum":0,"maximum":255};

function validate1658(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1658.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(!(((typeof data == "number") && (!(data % 1) && !isNaN(data))) && (isFinite(data)))){
validate1658.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "integer"}}];
return false;
}
if(errors === 0){
if((typeof data == "number") && (isFinite(data))){
if(data > 255 || isNaN(data)){
validate1658.errors = [{instancePath,schemaPath:"#/maximum",keyword:"maximum",params:{comparison: "<=", limit: 255}}];
return false;
}
else {
if(data < 0 || isNaN(data)){
validate1658.errors = [{instancePath,schemaPath:"#/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0}}];
return false;
}
}
}
}
validate1658.errors = vErrors;
return errors === 0;
}
validate1658.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema457 = {"type":"boolean"};

function validate1662(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1662.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "boolean"){
validate1662.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "boolean"}}];
return false;
}
validate1662.errors = vErrors;
return errors === 0;
}
validate1662.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema458 = {"type":"string","enum":["per_resource_snapshot_vector","independent_table_snapshots","transaction","atomic"]};

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
if(typeof data !== "string"){
validate1666.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"}}];
return false;
}
if(!((((data === "per_resource_snapshot_vector") || (data === "independent_table_snapshots")) || (data === "transaction")) || (data === "atomic"))){
validate1666.errors = [{instancePath,schemaPath:"#/enum",keyword:"enum",params:{allowedValues: schema458.enum}}];
return false;
}
validate1666.errors = vErrors;
return errors === 0;
}
validate1666.evaluated = {"dynamicProps":false,"dynamicItems":false};


function validate1655(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1655.evaluated;
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
validate1655.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((((((((key0 === "definition") || (key0 === "sources")) || (key0 === "active_queries")) || (key0 === "page_rows")) || (key0 === "interactive")) || (key0 === "captured")) || (key0 === "maintained")) || (key0 === "consistency"))){
validate1655.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.definition !== undefined){
const _errs2 = errors;
if(!(validate1656(data.definition, {instancePath:instancePath+"/definition",parentData:data,parentDataProperty:"definition",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1656.errors : vErrors.concat(validate1656.errors);
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
if(!(validate1658(data.sources, {instancePath:instancePath+"/sources",parentData:data,parentDataProperty:"sources",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1658.errors : vErrors.concat(validate1658.errors);
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
if(!(validate1658(data.active_queries, {instancePath:instancePath+"/active_queries",parentData:data,parentDataProperty:"active_queries",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1658.errors : vErrors.concat(validate1658.errors);
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
if(!(validate1658(data.page_rows, {instancePath:instancePath+"/page_rows",parentData:data,parentDataProperty:"page_rows",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1658.errors : vErrors.concat(validate1658.errors);
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
if(!(validate1662(data.interactive, {instancePath:instancePath+"/interactive",parentData:data,parentDataProperty:"interactive",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1662.errors : vErrors.concat(validate1662.errors);
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
if(!(validate1662(data.captured, {instancePath:instancePath+"/captured",parentData:data,parentDataProperty:"captured",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1662.errors : vErrors.concat(validate1662.errors);
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
if(!(validate1662(data.maintained, {instancePath:instancePath+"/maintained",parentData:data,parentDataProperty:"maintained",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1662.errors : vErrors.concat(validate1662.errors);
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
if(!(validate1666(data.consistency, {instancePath:instancePath+"/consistency",parentData:data,parentDataProperty:"consistency",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1666.errors : vErrors.concat(validate1666.errors);
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
validate1655.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
return false;
}
}
validate1655.errors = vErrors;
return errors === 0;
}
validate1655.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema459 = {"type":"array","maxItems":2,"items":{"$ref":"#/$defs/RelationalResponse/$defs/T8"}};
const schema460 = {"type":"object","additionalProperties":false,"properties":{"connection":{"$ref":"#/$defs/RelationalResponse/$defs/T9"},"description":{"$ref":"#/$defs/RelationalResponse/$defs/T14"}},"required":["connection","description"]};
const schema461 = {"type":"object","additionalProperties":false,"properties":{"scope":{"$ref":"#/$defs/RelationalResponse/$defs/T10"},"branch":{"$ref":"#/$defs/RelationalResponse/$defs/T12"},"audience":{"$ref":"#/$defs/RelationalResponse/$defs/T11"},"principal":{"$ref":"#/$defs/RelationalResponse/$defs/T11"},"role":{"$ref":"#/$defs/RelationalResponse/$defs/T13"}},"required":["scope","branch","audience","principal","role"]};
const schema462 = {"type":"object","additionalProperties":false,"properties":{"realm":{"$ref":"#/$defs/RelationalResponse/$defs/T11"},"resource":{"$ref":"#/$defs/RelationalResponse/$defs/T11"},"catalog":{"$ref":"#/$defs/RelationalResponse/$defs/T12"}},"required":["realm","resource","catalog"]};

function validate1673(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1673.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(!(((typeof data == "number") && (!(data % 1) && !isNaN(data))) && (isFinite(data)))){
validate1673.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "integer"}}];
return false;
}
if(errors === 0){
if((typeof data == "number") && (isFinite(data))){
if(data > 9007199254740991 || isNaN(data)){
validate1673.errors = [{instancePath,schemaPath:"#/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991}}];
return false;
}
else {
if(data < 0 || isNaN(data)){
validate1673.errors = [{instancePath,schemaPath:"#/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0}}];
return false;
}
}
}
}
validate1673.errors = vErrors;
return errors === 0;
}
validate1673.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema464 = {"type":"string","maxLength":4096};

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
if(typeof data === "string"){
if(func4(data) > 4096){
validate1676.errors = [{instancePath,schemaPath:"#/maxLength",keyword:"maxLength",params:{limit: 4096}}];
return false;
}
}
else {
validate1676.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"}}];
return false;
}
}
validate1676.errors = vErrors;
return errors === 0;
}
validate1676.evaluated = {"dynamicProps":false,"dynamicItems":false};


function validate1672(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1672.evaluated;
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
validate1672.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "realm") || (key0 === "resource")) || (key0 === "catalog"))){
validate1672.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.realm !== undefined){
const _errs2 = errors;
if(!(validate1673(data.realm, {instancePath:instancePath+"/realm",parentData:data,parentDataProperty:"realm",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1673.errors : vErrors.concat(validate1673.errors);
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
if(!(validate1673(data.resource, {instancePath:instancePath+"/resource",parentData:data,parentDataProperty:"resource",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1673.errors : vErrors.concat(validate1673.errors);
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
if(!(validate1676(data.catalog, {instancePath:instancePath+"/catalog",parentData:data,parentDataProperty:"catalog",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1676.errors : vErrors.concat(validate1676.errors);
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
validate1672.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
return false;
}
}
validate1672.errors = vErrors;
return errors === 0;
}
validate1672.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema465 = {"anyOf":[{"$ref":"#/$defs/RelationalResponse/$defs/T11"},{"type":"null"}]};

function validate1682(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1682.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate1673(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1673.errors : vErrors.concat(validate1673.errors);
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
validate1682.errors = vErrors;
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
validate1682.errors = vErrors;
return errors === 0;
}
validate1682.evaluated = {"dynamicProps":false,"dynamicItems":false};


function validate1671(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1671.evaluated;
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
validate1671.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((((key0 === "scope") || (key0 === "branch")) || (key0 === "audience")) || (key0 === "principal")) || (key0 === "role"))){
validate1671.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.scope !== undefined){
const _errs2 = errors;
if(!(validate1672(data.scope, {instancePath:instancePath+"/scope",parentData:data,parentDataProperty:"scope",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1672.errors : vErrors.concat(validate1672.errors);
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
if(!(validate1676(data.branch, {instancePath:instancePath+"/branch",parentData:data,parentDataProperty:"branch",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1676.errors : vErrors.concat(validate1676.errors);
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
if(!(validate1673(data.audience, {instancePath:instancePath+"/audience",parentData:data,parentDataProperty:"audience",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1673.errors : vErrors.concat(validate1673.errors);
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
if(!(validate1673(data.principal, {instancePath:instancePath+"/principal",parentData:data,parentDataProperty:"principal",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1673.errors : vErrors.concat(validate1673.errors);
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
if(!(validate1682(data.role, {instancePath:instancePath+"/role",parentData:data,parentDataProperty:"role",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1682.errors : vErrors.concat(validate1682.errors);
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
validate1671.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
return false;
}
}
validate1671.errors = vErrors;
return errors === 0;
}
validate1671.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema466 = {"type":"object","additionalProperties":false,"properties":{"configuration":{"$ref":"#/$defs/RelationalResponse/$defs/T15"},"subject":{"$ref":"#/$defs/RelationalResponse/$defs/T17"},"policy_revision":{"$ref":"#/$defs/RelationalResponse/$defs/T11"}},"required":["configuration","subject","policy_revision"]};
const schema467 = {"type":"object","additionalProperties":false,"properties":{"scope":{"$ref":"#/$defs/RelationalResponse/$defs/T10"},"branch":{"$ref":"#/$defs/RelationalResponse/$defs/T12"},"partition":{"$ref":"#/$defs/RelationalResponse/$defs/T12"},"audience":{"$ref":"#/$defs/RelationalResponse/$defs/T11"},"authority":{"$ref":"#/$defs/RelationalResponse/$defs/T16"},"database_name":{"$ref":"#/$defs/RelationalResponse/$defs/T12"},"initial_schema_name":{"$ref":"#/$defs/RelationalResponse/$defs/T12"}},"required":["scope","branch","partition","audience","authority","database_name","initial_schema_name"]};
const schema468 = {"type":"object","additionalProperties":false,"properties":{"database_domain":{"$ref":"#/$defs/RelationalResponse/$defs/T11"},"schema_domain":{"$ref":"#/$defs/RelationalResponse/$defs/T11"},"table_domain":{"$ref":"#/$defs/RelationalResponse/$defs/T11"},"stream_domain":{"$ref":"#/$defs/RelationalResponse/$defs/T11"},"queue_domain":{"$ref":"#/$defs/RelationalResponse/$defs/T11"},"kv_domain":{"$ref":"#/$defs/RelationalResponse/$defs/T11"},"database":{"$ref":"#/$defs/RelationalResponse/$defs/T11"},"initial_schema":{"$ref":"#/$defs/RelationalResponse/$defs/T11"},"initial_schema_authority":{"$ref":"#/$defs/RelationalResponse/$defs/T11"}},"required":["database_domain","schema_domain","table_domain","stream_domain","queue_domain","kv_domain","database","initial_schema","initial_schema_authority"]};
const func1 = Object.prototype.hasOwnProperty;

function validate1692(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1692.evaluated;
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
validate1692.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(func1.call(schema468.properties, key0))){
validate1692.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.database_domain !== undefined){
const _errs2 = errors;
if(!(validate1673(data.database_domain, {instancePath:instancePath+"/database_domain",parentData:data,parentDataProperty:"database_domain",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1673.errors : vErrors.concat(validate1673.errors);
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
if(!(validate1673(data.schema_domain, {instancePath:instancePath+"/schema_domain",parentData:data,parentDataProperty:"schema_domain",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1673.errors : vErrors.concat(validate1673.errors);
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
if(!(validate1673(data.table_domain, {instancePath:instancePath+"/table_domain",parentData:data,parentDataProperty:"table_domain",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1673.errors : vErrors.concat(validate1673.errors);
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
if(!(validate1673(data.stream_domain, {instancePath:instancePath+"/stream_domain",parentData:data,parentDataProperty:"stream_domain",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1673.errors : vErrors.concat(validate1673.errors);
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
if(!(validate1673(data.queue_domain, {instancePath:instancePath+"/queue_domain",parentData:data,parentDataProperty:"queue_domain",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1673.errors : vErrors.concat(validate1673.errors);
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
if(!(validate1673(data.kv_domain, {instancePath:instancePath+"/kv_domain",parentData:data,parentDataProperty:"kv_domain",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1673.errors : vErrors.concat(validate1673.errors);
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
if(!(validate1673(data.database, {instancePath:instancePath+"/database",parentData:data,parentDataProperty:"database",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1673.errors : vErrors.concat(validate1673.errors);
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
if(!(validate1673(data.initial_schema, {instancePath:instancePath+"/initial_schema",parentData:data,parentDataProperty:"initial_schema",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1673.errors : vErrors.concat(validate1673.errors);
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
if(!(validate1673(data.initial_schema_authority, {instancePath:instancePath+"/initial_schema_authority",parentData:data,parentDataProperty:"initial_schema_authority",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1673.errors : vErrors.concat(validate1673.errors);
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
validate1692.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
return false;
}
}
validate1692.errors = vErrors;
return errors === 0;
}
validate1692.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate1687(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1687.evaluated;
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
validate1687.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((((((key0 === "scope") || (key0 === "branch")) || (key0 === "partition")) || (key0 === "audience")) || (key0 === "authority")) || (key0 === "database_name")) || (key0 === "initial_schema_name"))){
validate1687.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.scope !== undefined){
const _errs2 = errors;
if(!(validate1672(data.scope, {instancePath:instancePath+"/scope",parentData:data,parentDataProperty:"scope",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1672.errors : vErrors.concat(validate1672.errors);
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
if(!(validate1676(data.branch, {instancePath:instancePath+"/branch",parentData:data,parentDataProperty:"branch",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1676.errors : vErrors.concat(validate1676.errors);
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
if(!(validate1676(data.partition, {instancePath:instancePath+"/partition",parentData:data,parentDataProperty:"partition",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1676.errors : vErrors.concat(validate1676.errors);
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
if(!(validate1673(data.audience, {instancePath:instancePath+"/audience",parentData:data,parentDataProperty:"audience",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1673.errors : vErrors.concat(validate1673.errors);
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
if(!(validate1692(data.authority, {instancePath:instancePath+"/authority",parentData:data,parentDataProperty:"authority",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1692.errors : vErrors.concat(validate1692.errors);
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
if(!(validate1676(data.database_name, {instancePath:instancePath+"/database_name",parentData:data,parentDataProperty:"database_name",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1676.errors : vErrors.concat(validate1676.errors);
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
if(!(validate1676(data.initial_schema_name, {instancePath:instancePath+"/initial_schema_name",parentData:data,parentDataProperty:"initial_schema_name",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1676.errors : vErrors.concat(validate1676.errors);
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
validate1687.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
return false;
}
}
validate1687.errors = vErrors;
return errors === 0;
}
validate1687.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema469 = {"type":"object","additionalProperties":false,"properties":{"principal":{"$ref":"#/$defs/RelationalResponse/$defs/T11"},"login_role":{"$ref":"#/$defs/RelationalResponse/$defs/T11"},"role":{"$ref":"#/$defs/RelationalResponse/$defs/T11"},"credential_epoch":{"$ref":"#/$defs/RelationalResponse/$defs/T11"},"audience":{"$ref":"#/$defs/RelationalResponse/$defs/T11"},"context":{"$ref":"#/$defs/RelationalResponse/$defs/T18"}},"required":["principal","login_role","role","credential_epoch","audience","context"]};
const schema470 = {"type":"array","minItems":32,"maxItems":32,"items":{"$ref":"#/$defs/RelationalResponse/$defs/T19"}};

function validate1713(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1713.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(!(((typeof data == "number") && (!(data % 1) && !isNaN(data))) && (isFinite(data)))){
validate1713.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "integer"}}];
return false;
}
if(errors === 0){
if((typeof data == "number") && (isFinite(data))){
if(data > 255 || isNaN(data)){
validate1713.errors = [{instancePath,schemaPath:"#/maximum",keyword:"maximum",params:{comparison: "<=", limit: 255}}];
return false;
}
else {
if(data < 0 || isNaN(data)){
validate1713.errors = [{instancePath,schemaPath:"#/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0}}];
return false;
}
}
}
}
validate1713.errors = vErrors;
return errors === 0;
}
validate1713.evaluated = {"dynamicProps":false,"dynamicItems":false};


function validate1712(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1712.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(Array.isArray(data)){
if(data.length > 32){
validate1712.errors = [{instancePath,schemaPath:"#/maxItems",keyword:"maxItems",params:{limit: 32}}];
return false;
}
else {
if(data.length < 32){
validate1712.errors = [{instancePath,schemaPath:"#/minItems",keyword:"minItems",params:{limit: 32}}];
return false;
}
else {
var valid0 = true;
const len0 = data.length;
for(let i0=0; i0<len0; i0++){
const _errs1 = errors;
if(!(validate1713(data[i0], {instancePath:instancePath+"/" + i0,parentData:data,parentDataProperty:i0,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1713.errors : vErrors.concat(validate1713.errors);
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
validate1712.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "array"}}];
return false;
}
}
validate1712.errors = vErrors;
return errors === 0;
}
validate1712.evaluated = {"items":true,"dynamicProps":false,"dynamicItems":false};


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
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if(((((((data.principal === undefined) && (missing0 = "principal")) || ((data.login_role === undefined) && (missing0 = "login_role"))) || ((data.role === undefined) && (missing0 = "role"))) || ((data.credential_epoch === undefined) && (missing0 = "credential_epoch"))) || ((data.audience === undefined) && (missing0 = "audience"))) || ((data.context === undefined) && (missing0 = "context"))){
validate1706.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((((((key0 === "principal") || (key0 === "login_role")) || (key0 === "role")) || (key0 === "credential_epoch")) || (key0 === "audience")) || (key0 === "context"))){
validate1706.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.principal !== undefined){
const _errs2 = errors;
if(!(validate1673(data.principal, {instancePath:instancePath+"/principal",parentData:data,parentDataProperty:"principal",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1673.errors : vErrors.concat(validate1673.errors);
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
if(!(validate1673(data.login_role, {instancePath:instancePath+"/login_role",parentData:data,parentDataProperty:"login_role",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1673.errors : vErrors.concat(validate1673.errors);
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
if(!(validate1673(data.role, {instancePath:instancePath+"/role",parentData:data,parentDataProperty:"role",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1673.errors : vErrors.concat(validate1673.errors);
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
if(!(validate1673(data.credential_epoch, {instancePath:instancePath+"/credential_epoch",parentData:data,parentDataProperty:"credential_epoch",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1673.errors : vErrors.concat(validate1673.errors);
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
if(!(validate1673(data.audience, {instancePath:instancePath+"/audience",parentData:data,parentDataProperty:"audience",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1673.errors : vErrors.concat(validate1673.errors);
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
if(!(validate1712(data.context, {instancePath:instancePath+"/context",parentData:data,parentDataProperty:"context",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1712.errors : vErrors.concat(validate1712.errors);
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
validate1706.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
return false;
}
}
validate1706.errors = vErrors;
return errors === 0;
}
validate1706.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate1686(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1686.evaluated;
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
validate1686.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "configuration") || (key0 === "subject")) || (key0 === "policy_revision"))){
validate1686.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.configuration !== undefined){
const _errs2 = errors;
if(!(validate1687(data.configuration, {instancePath:instancePath+"/configuration",parentData:data,parentDataProperty:"configuration",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1687.errors : vErrors.concat(validate1687.errors);
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
if(!(validate1706(data.subject, {instancePath:instancePath+"/subject",parentData:data,parentDataProperty:"subject",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1706.errors : vErrors.concat(validate1706.errors);
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
if(!(validate1673(data.policy_revision, {instancePath:instancePath+"/policy_revision",parentData:data,parentDataProperty:"policy_revision",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1673.errors : vErrors.concat(validate1673.errors);
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
validate1686.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
return false;
}
}
validate1686.errors = vErrors;
return errors === 0;
}
validate1686.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


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
if(((data.connection === undefined) && (missing0 = "connection")) || ((data.description === undefined) && (missing0 = "description"))){
validate1670.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "connection") || (key0 === "description"))){
validate1670.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.connection !== undefined){
const _errs2 = errors;
if(!(validate1671(data.connection, {instancePath:instancePath+"/connection",parentData:data,parentDataProperty:"connection",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1671.errors : vErrors.concat(validate1671.errors);
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
if(!(validate1686(data.description, {instancePath:instancePath+"/description",parentData:data,parentDataProperty:"description",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1686.errors : vErrors.concat(validate1686.errors);
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


function validate1669(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1669.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(Array.isArray(data)){
if(data.length > 2){
validate1669.errors = [{instancePath,schemaPath:"#/maxItems",keyword:"maxItems",params:{limit: 2}}];
return false;
}
else {
var valid0 = true;
const len0 = data.length;
for(let i0=0; i0<len0; i0++){
const _errs1 = errors;
if(!(validate1670(data[i0], {instancePath:instancePath+"/" + i0,parentData:data,parentDataProperty:i0,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1670.errors : vErrors.concat(validate1670.errors);
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
validate1669.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "array"}}];
return false;
}
}
validate1669.errors = vErrors;
return errors === 0;
}
validate1669.evaluated = {"items":true,"dynamicProps":false,"dynamicItems":false};

const schema472 = {"anyOf":[{"$ref":"#/$defs/RelationalResponse/$defs/T21"},{"type":"null"}]};
const schema473 = {"type":"object","additionalProperties":false,"properties":{"opened":{"$ref":"#/$defs/RelationalResponse/$defs/T22"},"ordinal":{"$ref":"#/$defs/RelationalResponse/$defs/T24"},"read":{"$ref":"#/$defs/RelationalResponse/$defs/T5"}},"required":["opened","ordinal","read"]};
const schema474 = {"type":"object","additionalProperties":false,"properties":{"reference":{"$ref":"#/$defs/RelationalResponse/$defs/T23"},"description":{"$ref":"#/$defs/RelationalResponse/$defs/T25"},"cuts":{"$ref":"#/$defs/RelationalResponse/$defs/T67"},"complete_coverage":{"$ref":"#/$defs/RelationalResponse/$defs/T5"}},"required":["reference","description","cuts","complete_coverage"]};
const schema475 = {"type":"object","additionalProperties":false,"properties":{"definition":{"$ref":"#/$defs/RelationalResponse/$defs/T3"},"id":{"$ref":"#/$defs/RelationalResponse/$defs/T24"},"plan":{"$ref":"#/$defs/RelationalResponse/$defs/T24"},"basis":{"$ref":"#/$defs/RelationalResponse/$defs/T24"}},"required":["definition","id","plan","basis"]};
const schema476 = {"type":"string","maxLength":4096};

function validate1726(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1726.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(typeof data === "string"){
if(func4(data) > 4096){
validate1726.errors = [{instancePath,schemaPath:"#/maxLength",keyword:"maxLength",params:{limit: 4096}}];
return false;
}
}
else {
validate1726.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"}}];
return false;
}
}
validate1726.errors = vErrors;
return errors === 0;
}
validate1726.evaluated = {"dynamicProps":false,"dynamicItems":false};


function validate1724(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1724.evaluated;
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
validate1724.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((((key0 === "definition") || (key0 === "id")) || (key0 === "plan")) || (key0 === "basis"))){
validate1724.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.definition !== undefined){
const _errs2 = errors;
if(!(validate1656(data.definition, {instancePath:instancePath+"/definition",parentData:data,parentDataProperty:"definition",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1656.errors : vErrors.concat(validate1656.errors);
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
if(!(validate1726(data.id, {instancePath:instancePath+"/id",parentData:data,parentDataProperty:"id",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1726.errors : vErrors.concat(validate1726.errors);
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
if(!(validate1726(data.plan, {instancePath:instancePath+"/plan",parentData:data,parentDataProperty:"plan",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1726.errors : vErrors.concat(validate1726.errors);
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
if(!(validate1726(data.basis, {instancePath:instancePath+"/basis",parentData:data,parentDataProperty:"basis",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1726.errors : vErrors.concat(validate1726.errors);
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
validate1724.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
return false;
}
}
validate1724.errors = vErrors;
return errors === 0;
}
validate1724.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema477 = {"type":"object","additionalProperties":false,"properties":{"definition":{"$ref":"#/$defs/RelationalResponse/$defs/T3"},"plan":{"$ref":"#/$defs/RelationalResponse/$defs/T24"},"sources":{"$ref":"#/$defs/RelationalResponse/$defs/T26"},"columns":{"$ref":"#/$defs/RelationalResponse/$defs/T36"},"join":{"$ref":"#/$defs/RelationalResponse/$defs/T65"},"grouped":{"$ref":"#/$defs/RelationalResponse/$defs/T5"},"executed":{"$ref":"#/$defs/RelationalResponse/$defs/T5"}},"required":["definition","plan","sources","columns","join","grouped","executed"]};
const schema478 = {"type":"array","maxItems":2,"items":{"$ref":"#/$defs/RelationalResponse/$defs/T27"}};
const schema479 = {"type":"object","additionalProperties":false,"properties":{"alias":{"$ref":"#/$defs/RelationalResponse/$defs/T12"},"binding":{"$ref":"#/$defs/RelationalResponse/$defs/T28"},"position":{"$ref":"#/$defs/RelationalResponse/$defs/T35"}},"required":["alias","binding","position"]};
const schema480 = {"type":"object","additionalProperties":false,"properties":{"definition":{"$ref":"#/$defs/RelationalResponse/$defs/T29"},"connection":{"$ref":"#/$defs/RelationalResponse/$defs/T9"},"namespace":{"$ref":"#/$defs/RelationalResponse/$defs/T11"},"name":{"$ref":"#/$defs/RelationalResponse/$defs/T12"},"interpretation":{"$ref":"#/$defs/RelationalResponse/$defs/T30"}},"required":["definition","connection","namespace","name","interpretation"]};

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
if(typeof data !== "string"){
validate1738.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"}}];
return false;
}
if(!(data === "9ccbb15686fea6ace7f101548f0957d9847446c09353f098543b2c20361b2fef")){
validate1738.errors = [{instancePath,schemaPath:"#/enum",keyword:"enum",params:{allowedValues: schema55.enum}}];
return false;
}
validate1738.errors = vErrors;
return errors === 0;
}
validate1738.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema482 = {"type":"object","additionalProperties":false,"properties":{"interpretation":{"$ref":"#/$defs/RelationalResponse/$defs/T31"},"content":{"$ref":"#/$defs/RelationalResponse/$defs/T33"},"schema_fingerprint":{"$ref":"#/$defs/RelationalResponse/$defs/T12"},"retired":{"$ref":"#/$defs/RelationalResponse/$defs/T34"}},"required":["interpretation","content","schema_fingerprint","retired"]};
const schema483 = {"type":"object","additionalProperties":false,"properties":{"object":{"$ref":"#/$defs/RelationalResponse/$defs/T32"},"revision":{"$ref":"#/$defs/RelationalResponse/$defs/T12"},"digest":{"$ref":"#/$defs/RelationalResponse/$defs/T12"}},"required":["object","revision","digest"]};
const schema484 = {"type":"object","additionalProperties":false,"properties":{"scope":{"$ref":"#/$defs/RelationalResponse/$defs/T10"},"branch":{"$ref":"#/$defs/RelationalResponse/$defs/T12"},"object":{"$ref":"#/$defs/RelationalResponse/$defs/T12"}},"required":["scope","branch","object"]};

function validate1745(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1745.evaluated;
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
validate1745.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "scope") || (key0 === "branch")) || (key0 === "object"))){
validate1745.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.scope !== undefined){
const _errs2 = errors;
if(!(validate1672(data.scope, {instancePath:instancePath+"/scope",parentData:data,parentDataProperty:"scope",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1672.errors : vErrors.concat(validate1672.errors);
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
if(!(validate1676(data.branch, {instancePath:instancePath+"/branch",parentData:data,parentDataProperty:"branch",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1676.errors : vErrors.concat(validate1676.errors);
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
if(!(validate1676(data.object, {instancePath:instancePath+"/object",parentData:data,parentDataProperty:"object",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1676.errors : vErrors.concat(validate1676.errors);
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
validate1745.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
return false;
}
}
validate1745.errors = vErrors;
return errors === 0;
}
validate1745.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


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
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((((data.object === undefined) && (missing0 = "object")) || ((data.revision === undefined) && (missing0 = "revision"))) || ((data.digest === undefined) && (missing0 = "digest"))){
validate1744.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "object") || (key0 === "revision")) || (key0 === "digest"))){
validate1744.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.object !== undefined){
const _errs2 = errors;
if(!(validate1745(data.object, {instancePath:instancePath+"/object",parentData:data,parentDataProperty:"object",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1745.errors : vErrors.concat(validate1745.errors);
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
if(!(validate1676(data.revision, {instancePath:instancePath+"/revision",parentData:data,parentDataProperty:"revision",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1676.errors : vErrors.concat(validate1676.errors);
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
if(!(validate1676(data.digest, {instancePath:instancePath+"/digest",parentData:data,parentDataProperty:"digest",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1676.errors : vErrors.concat(validate1676.errors);
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
validate1744.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
return false;
}
}
validate1744.errors = vErrors;
return errors === 0;
}
validate1744.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema485 = {"type":"object","additionalProperties":false,"properties":{"bytes":{"$ref":"#/$defs/RelationalResponse/$defs/T12"},"sha256":{"$ref":"#/$defs/RelationalResponse/$defs/T12"}},"required":["bytes","sha256"]};

function validate1753(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1753.evaluated;
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
validate1753.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "bytes") || (key0 === "sha256"))){
validate1753.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.bytes !== undefined){
const _errs2 = errors;
if(!(validate1676(data.bytes, {instancePath:instancePath+"/bytes",parentData:data,parentDataProperty:"bytes",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1676.errors : vErrors.concat(validate1676.errors);
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
if(!(validate1676(data.sha256, {instancePath:instancePath+"/sha256",parentData:data,parentDataProperty:"sha256",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1676.errors : vErrors.concat(validate1676.errors);
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
validate1753.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
return false;
}
}
validate1753.errors = vErrors;
return errors === 0;
}
validate1753.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema486 = {"type":"boolean"};

function validate1758(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1758.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "boolean"){
validate1758.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "boolean"}}];
return false;
}
validate1758.errors = vErrors;
return errors === 0;
}
validate1758.evaluated = {"dynamicProps":false,"dynamicItems":false};


function validate1743(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1743.evaluated;
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
validate1743.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((((key0 === "interpretation") || (key0 === "content")) || (key0 === "schema_fingerprint")) || (key0 === "retired"))){
validate1743.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.interpretation !== undefined){
const _errs2 = errors;
if(!(validate1744(data.interpretation, {instancePath:instancePath+"/interpretation",parentData:data,parentDataProperty:"interpretation",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1744.errors : vErrors.concat(validate1744.errors);
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
if(!(validate1753(data.content, {instancePath:instancePath+"/content",parentData:data,parentDataProperty:"content",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1753.errors : vErrors.concat(validate1753.errors);
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
if(!(validate1676(data.schema_fingerprint, {instancePath:instancePath+"/schema_fingerprint",parentData:data,parentDataProperty:"schema_fingerprint",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1676.errors : vErrors.concat(validate1676.errors);
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
if(!(validate1758(data.retired, {instancePath:instancePath+"/retired",parentData:data,parentDataProperty:"retired",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1758.errors : vErrors.concat(validate1758.errors);
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
validate1743.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
return false;
}
}
validate1743.errors = vErrors;
return errors === 0;
}
validate1743.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate1737(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1737.evaluated;
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
validate1737.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((((key0 === "definition") || (key0 === "connection")) || (key0 === "namespace")) || (key0 === "name")) || (key0 === "interpretation"))){
validate1737.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.definition !== undefined){
const _errs2 = errors;
if(!(validate1738(data.definition, {instancePath:instancePath+"/definition",parentData:data,parentDataProperty:"definition",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1738.errors : vErrors.concat(validate1738.errors);
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
if(!(validate1671(data.connection, {instancePath:instancePath+"/connection",parentData:data,parentDataProperty:"connection",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1671.errors : vErrors.concat(validate1671.errors);
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
if(!(validate1673(data.namespace, {instancePath:instancePath+"/namespace",parentData:data,parentDataProperty:"namespace",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1673.errors : vErrors.concat(validate1673.errors);
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
if(!(validate1676(data.name, {instancePath:instancePath+"/name",parentData:data,parentDataProperty:"name",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1676.errors : vErrors.concat(validate1676.errors);
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
if(!(validate1743(data.interpretation, {instancePath:instancePath+"/interpretation",parentData:data,parentDataProperty:"interpretation",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1743.errors : vErrors.concat(validate1743.errors);
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
validate1737.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
return false;
}
}
validate1737.errors = vErrors;
return errors === 0;
}
validate1737.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema487 = {"type":"object","additionalProperties":false,"properties":{"partition":{"$ref":"#/$defs/RelationalResponse/$defs/T12"},"next_lsn":{"$ref":"#/$defs/RelationalResponse/$defs/T12"}},"required":["partition","next_lsn"]};

function validate1762(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1762.evaluated;
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
validate1762.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "partition") || (key0 === "next_lsn"))){
validate1762.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.partition !== undefined){
const _errs2 = errors;
if(!(validate1676(data.partition, {instancePath:instancePath+"/partition",parentData:data,parentDataProperty:"partition",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1676.errors : vErrors.concat(validate1676.errors);
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
if(!(validate1676(data.next_lsn, {instancePath:instancePath+"/next_lsn",parentData:data,parentDataProperty:"next_lsn",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1676.errors : vErrors.concat(validate1676.errors);
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
validate1762.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
return false;
}
}
validate1762.errors = vErrors;
return errors === 0;
}
validate1762.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate1735(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1735.evaluated;
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
validate1735.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "alias") || (key0 === "binding")) || (key0 === "position"))){
validate1735.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.alias !== undefined){
const _errs2 = errors;
if(!(validate1676(data.alias, {instancePath:instancePath+"/alias",parentData:data,parentDataProperty:"alias",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1676.errors : vErrors.concat(validate1676.errors);
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
if(!(validate1737(data.binding, {instancePath:instancePath+"/binding",parentData:data,parentDataProperty:"binding",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1737.errors : vErrors.concat(validate1737.errors);
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
if(!(validate1762(data.position, {instancePath:instancePath+"/position",parentData:data,parentDataProperty:"position",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1762.errors : vErrors.concat(validate1762.errors);
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
validate1735.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
return false;
}
}
validate1735.errors = vErrors;
return errors === 0;
}
validate1735.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


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
if(errors === 0){
if(Array.isArray(data)){
if(data.length > 2){
validate1734.errors = [{instancePath,schemaPath:"#/maxItems",keyword:"maxItems",params:{limit: 2}}];
return false;
}
else {
var valid0 = true;
const len0 = data.length;
for(let i0=0; i0<len0; i0++){
const _errs1 = errors;
if(!(validate1735(data[i0], {instancePath:instancePath+"/" + i0,parentData:data,parentDataProperty:i0,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1735.errors : vErrors.concat(validate1735.errors);
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
validate1734.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "array"}}];
return false;
}
}
validate1734.errors = vErrors;
return errors === 0;
}
validate1734.evaluated = {"items":true,"dynamicProps":false,"dynamicItems":false};

const schema488 = {"type":"array","maxItems":128,"items":{"$ref":"#/$defs/RelationalResponse/$defs/T37"}};
const schema489 = {"type":"object","additionalProperties":false,"properties":{"name":{"$ref":"#/$defs/RelationalResponse/$defs/T24"},"type":{"$ref":"#/$defs/RelationalResponse/$defs/T38"},"nullable":{"$ref":"#/$defs/RelationalResponse/$defs/T5"},"optional":{"$ref":"#/$defs/RelationalResponse/$defs/T5"}},"required":["name","type","nullable","optional"]};
const schema490 = {"oneOf":[{"type":"object","additionalProperties":false,"required":["int64"],"properties":{"int64":{"$ref":"#/$defs/RelationalResponse/$defs/T39"}}},{"type":"object","additionalProperties":false,"required":["uint64"],"properties":{"uint64":{"$ref":"#/$defs/RelationalResponse/$defs/T39"}}},{"type":"object","additionalProperties":false,"required":["float64"],"properties":{"float64":{"$ref":"#/$defs/RelationalResponse/$defs/T39"}}},{"type":"object","additionalProperties":false,"required":["boolean"],"properties":{"boolean":{"$ref":"#/$defs/RelationalResponse/$defs/T39"}}},{"type":"object","additionalProperties":false,"required":["utf8"],"properties":{"utf8":{"$ref":"#/$defs/RelationalResponse/$defs/T39"}}},{"type":"object","additionalProperties":false,"required":["binary"],"properties":{"binary":{"$ref":"#/$defs/RelationalResponse/$defs/T39"}}},{"type":"object","additionalProperties":false,"required":["int8"],"properties":{"int8":{"$ref":"#/$defs/RelationalResponse/$defs/T39"}}},{"type":"object","additionalProperties":false,"required":["int16"],"properties":{"int16":{"$ref":"#/$defs/RelationalResponse/$defs/T39"}}},{"type":"object","additionalProperties":false,"required":["int32"],"properties":{"int32":{"$ref":"#/$defs/RelationalResponse/$defs/T39"}}},{"type":"object","additionalProperties":false,"required":["int128"],"properties":{"int128":{"$ref":"#/$defs/RelationalResponse/$defs/T39"}}},{"type":"object","additionalProperties":false,"required":["uint8"],"properties":{"uint8":{"$ref":"#/$defs/RelationalResponse/$defs/T39"}}},{"type":"object","additionalProperties":false,"required":["uint16"],"properties":{"uint16":{"$ref":"#/$defs/RelationalResponse/$defs/T39"}}},{"type":"object","additionalProperties":false,"required":["uint32"],"properties":{"uint32":{"$ref":"#/$defs/RelationalResponse/$defs/T39"}}},{"type":"object","additionalProperties":false,"required":["uint128"],"properties":{"uint128":{"$ref":"#/$defs/RelationalResponse/$defs/T39"}}},{"type":"object","additionalProperties":false,"required":["float32"],"properties":{"float32":{"$ref":"#/$defs/RelationalResponse/$defs/T39"}}},{"type":"object","additionalProperties":false,"required":["decimal"],"properties":{"decimal":{"$ref":"#/$defs/RelationalResponse/$defs/T40"}}},{"type":"object","additionalProperties":false,"required":["date"],"properties":{"date":{"$ref":"#/$defs/RelationalResponse/$defs/T39"}}},{"type":"object","additionalProperties":false,"required":["time"],"properties":{"time":{"$ref":"#/$defs/RelationalResponse/$defs/T39"}}},{"type":"object","additionalProperties":false,"required":["timestamp"],"properties":{"timestamp":{"$ref":"#/$defs/RelationalResponse/$defs/T41"}}},{"type":"object","additionalProperties":false,"required":["interval"],"properties":{"interval":{"$ref":"#/$defs/RelationalResponse/$defs/T39"}}},{"type":"object","additionalProperties":false,"required":["uuid"],"properties":{"uuid":{"$ref":"#/$defs/RelationalResponse/$defs/T39"}}},{"type":"object","additionalProperties":false,"required":["structure"],"properties":{"structure":{"$ref":"#/$defs/RelationalResponse/$defs/T42"}}},{"type":"object","additionalProperties":false,"required":["list"],"properties":{"list":{"$ref":"#/$defs/RelationalResponse/$defs/T58"}}},{"type":"object","additionalProperties":false,"required":["array"],"properties":{"array":{"$ref":"#/$defs/RelationalResponse/$defs/T60"}}},{"type":"object","additionalProperties":false,"required":["map"],"properties":{"map":{"$ref":"#/$defs/RelationalResponse/$defs/T62"}}},{"type":"object","additionalProperties":false,"required":["tagged_union"],"properties":{"tagged_union":{"$ref":"#/$defs/RelationalResponse/$defs/T42"}}},{"type":"object","additionalProperties":false,"required":["json"],"properties":{"json":{"$ref":"#/$defs/RelationalResponse/$defs/T39"}}},{"type":"object","additionalProperties":false,"required":["range"],"properties":{"range":{"$ref":"#/$defs/RelationalResponse/$defs/T59"}}},{"type":"object","additionalProperties":false,"required":["multirange"],"properties":{"multirange":{"$ref":"#/$defs/RelationalResponse/$defs/T59"}}},{"type":"object","additionalProperties":false,"required":["vector"],"properties":{"vector":{"$ref":"#/$defs/RelationalResponse/$defs/T63"}}}]};
const schema491 = {"type":"object","maxProperties":0};

function validate1772(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1772.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
if(Object.keys(data).length > 0){
validate1772.errors = [{instancePath,schemaPath:"#/maxProperties",keyword:"maxProperties",params:{limit: 0}}];
return false;
}
}
else {
validate1772.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
return false;
}
}
validate1772.errors = vErrors;
return errors === 0;
}
validate1772.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema492 = {"type":"object","additionalProperties":false,"properties":{"precision":{"$ref":"#/$defs/RelationalResponse/$defs/T4"},"scale":{"$ref":"#/$defs/RelationalResponse/$defs/T4"}},"required":["precision","scale"]};

function validate1788(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1788.evaluated;
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
validate1788.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "precision") || (key0 === "scale"))){
validate1788.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.precision !== undefined){
const _errs2 = errors;
if(!(validate1658(data.precision, {instancePath:instancePath+"/precision",parentData:data,parentDataProperty:"precision",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1658.errors : vErrors.concat(validate1658.errors);
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
if(!(validate1658(data.scale, {instancePath:instancePath+"/scale",parentData:data,parentDataProperty:"scale",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1658.errors : vErrors.concat(validate1658.errors);
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
validate1788.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
return false;
}
}
validate1788.errors = vErrors;
return errors === 0;
}
validate1788.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema177 = {"type":"string","enum":["civil","utc"]};

function validate1794(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1794.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate1794.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"}}];
return false;
}
if(!((data === "civil") || (data === "utc"))){
validate1794.errors = [{instancePath,schemaPath:"#/enum",keyword:"enum",params:{allowedValues: schema177.enum}}];
return false;
}
validate1794.errors = vErrors;
return errors === 0;
}
validate1794.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema494 = {"type":"array","maxItems":256,"items":{"$ref":"#/$defs/RelationalResponse/$defs/T43"}};
const schema495 = {"type":"object","additionalProperties":false,"properties":{"name":{"$ref":"#/$defs/RelationalResponse/$defs/T44"},"type":{"$ref":"#/$defs/RelationalResponse/$defs/T45"},"nullable":{"$ref":"#/$defs/RelationalResponse/$defs/T52"},"optional":{"$ref":"#/$defs/RelationalResponse/$defs/T52"}},"required":["name","type","nullable","optional"]};
const schema496 = {"type":"string","maxLength":4096};

function validate1800(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1800.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(typeof data === "string"){
if(func4(data) > 4096){
validate1800.errors = [{instancePath,schemaPath:"#/maxLength",keyword:"maxLength",params:{limit: 4096}}];
return false;
}
}
else {
validate1800.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"}}];
return false;
}
}
validate1800.errors = vErrors;
return errors === 0;
}
validate1800.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema497 = {"oneOf":[{"type":"object","additionalProperties":false,"required":["int64"],"properties":{"int64":{"$ref":"#/$defs/RelationalResponse/$defs/T46"}}},{"type":"object","additionalProperties":false,"required":["uint64"],"properties":{"uint64":{"$ref":"#/$defs/RelationalResponse/$defs/T46"}}},{"type":"object","additionalProperties":false,"required":["float64"],"properties":{"float64":{"$ref":"#/$defs/RelationalResponse/$defs/T46"}}},{"type":"object","additionalProperties":false,"required":["boolean"],"properties":{"boolean":{"$ref":"#/$defs/RelationalResponse/$defs/T46"}}},{"type":"object","additionalProperties":false,"required":["utf8"],"properties":{"utf8":{"$ref":"#/$defs/RelationalResponse/$defs/T46"}}},{"type":"object","additionalProperties":false,"required":["binary"],"properties":{"binary":{"$ref":"#/$defs/RelationalResponse/$defs/T46"}}},{"type":"object","additionalProperties":false,"required":["int8"],"properties":{"int8":{"$ref":"#/$defs/RelationalResponse/$defs/T46"}}},{"type":"object","additionalProperties":false,"required":["int16"],"properties":{"int16":{"$ref":"#/$defs/RelationalResponse/$defs/T46"}}},{"type":"object","additionalProperties":false,"required":["int32"],"properties":{"int32":{"$ref":"#/$defs/RelationalResponse/$defs/T46"}}},{"type":"object","additionalProperties":false,"required":["int128"],"properties":{"int128":{"$ref":"#/$defs/RelationalResponse/$defs/T46"}}},{"type":"object","additionalProperties":false,"required":["uint8"],"properties":{"uint8":{"$ref":"#/$defs/RelationalResponse/$defs/T46"}}},{"type":"object","additionalProperties":false,"required":["uint16"],"properties":{"uint16":{"$ref":"#/$defs/RelationalResponse/$defs/T46"}}},{"type":"object","additionalProperties":false,"required":["uint32"],"properties":{"uint32":{"$ref":"#/$defs/RelationalResponse/$defs/T46"}}},{"type":"object","additionalProperties":false,"required":["uint128"],"properties":{"uint128":{"$ref":"#/$defs/RelationalResponse/$defs/T46"}}},{"type":"object","additionalProperties":false,"required":["float32"],"properties":{"float32":{"$ref":"#/$defs/RelationalResponse/$defs/T46"}}},{"type":"object","additionalProperties":false,"required":["decimal"],"properties":{"decimal":{"$ref":"#/$defs/RelationalResponse/$defs/T47"}}},{"type":"object","additionalProperties":false,"required":["date"],"properties":{"date":{"$ref":"#/$defs/RelationalResponse/$defs/T46"}}},{"type":"object","additionalProperties":false,"required":["time"],"properties":{"time":{"$ref":"#/$defs/RelationalResponse/$defs/T46"}}},{"type":"object","additionalProperties":false,"required":["timestamp"],"properties":{"timestamp":{"$ref":"#/$defs/RelationalResponse/$defs/T49"}}},{"type":"object","additionalProperties":false,"required":["interval"],"properties":{"interval":{"$ref":"#/$defs/RelationalResponse/$defs/T46"}}},{"type":"object","additionalProperties":false,"required":["uuid"],"properties":{"uuid":{"$ref":"#/$defs/RelationalResponse/$defs/T46"}}},{"type":"object","additionalProperties":false,"required":["structure"],"properties":{"structure":{"$ref":"#/$defs/RelationalResponse/$defs/T42"}}},{"type":"object","additionalProperties":false,"required":["list"],"properties":{"list":{"$ref":"#/$defs/RelationalResponse/$defs/T50"}}},{"type":"object","additionalProperties":false,"required":["array"],"properties":{"array":{"$ref":"#/$defs/RelationalResponse/$defs/T53"}}},{"type":"object","additionalProperties":false,"required":["map"],"properties":{"map":{"$ref":"#/$defs/RelationalResponse/$defs/T55"}}},{"type":"object","additionalProperties":false,"required":["tagged_union"],"properties":{"tagged_union":{"$ref":"#/$defs/RelationalResponse/$defs/T42"}}},{"type":"object","additionalProperties":false,"required":["json"],"properties":{"json":{"$ref":"#/$defs/RelationalResponse/$defs/T46"}}},{"type":"object","additionalProperties":false,"required":["range"],"properties":{"range":{"$ref":"#/$defs/RelationalResponse/$defs/T51"}}},{"type":"object","additionalProperties":false,"required":["multirange"],"properties":{"multirange":{"$ref":"#/$defs/RelationalResponse/$defs/T51"}}},{"type":"object","additionalProperties":false,"required":["vector"],"properties":{"vector":{"$ref":"#/$defs/RelationalResponse/$defs/T56"}}}]};
const schema498 = {"type":"object","maxProperties":0};

function validate1803(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1803.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
if(Object.keys(data).length > 0){
validate1803.errors = [{instancePath,schemaPath:"#/maxProperties",keyword:"maxProperties",params:{limit: 0}}];
return false;
}
}
else {
validate1803.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
return false;
}
}
validate1803.errors = vErrors;
return errors === 0;
}
validate1803.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema499 = {"type":"object","additionalProperties":false,"properties":{"precision":{"$ref":"#/$defs/RelationalResponse/$defs/T48"},"scale":{"$ref":"#/$defs/RelationalResponse/$defs/T48"}},"required":["precision","scale"]};

function validate1820(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1820.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(!(((typeof data == "number") && (!(data % 1) && !isNaN(data))) && (isFinite(data)))){
validate1820.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "integer"}}];
return false;
}
if(errors === 0){
if((typeof data == "number") && (isFinite(data))){
if(data > 255 || isNaN(data)){
validate1820.errors = [{instancePath,schemaPath:"#/maximum",keyword:"maximum",params:{comparison: "<=", limit: 255}}];
return false;
}
else {
if(data < 0 || isNaN(data)){
validate1820.errors = [{instancePath,schemaPath:"#/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0}}];
return false;
}
}
}
}
validate1820.errors = vErrors;
return errors === 0;
}
validate1820.evaluated = {"dynamicProps":false,"dynamicItems":false};


function validate1819(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1819.evaluated;
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
validate1819.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "precision") || (key0 === "scale"))){
validate1819.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.precision !== undefined){
const _errs2 = errors;
if(!(validate1820(data.precision, {instancePath:instancePath+"/precision",parentData:data,parentDataProperty:"precision",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1820.errors : vErrors.concat(validate1820.errors);
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
if(!(validate1820(data.scale, {instancePath:instancePath+"/scale",parentData:data,parentDataProperty:"scale",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1820.errors : vErrors.concat(validate1820.errors);
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
validate1819.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
return false;
}
}
validate1819.errors = vErrors;
return errors === 0;
}
validate1819.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate1826(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1826.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate1826.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"}}];
return false;
}
if(!((data === "civil") || (data === "utc"))){
validate1826.errors = [{instancePath,schemaPath:"#/enum",keyword:"enum",params:{allowedValues: schema177.enum}}];
return false;
}
validate1826.errors = vErrors;
return errors === 0;
}
validate1826.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema502 = {"type":"object","additionalProperties":false,"properties":{"type":{"$ref":"#/$defs/RelationalResponse/$defs/T51"},"nullable":{"$ref":"#/$defs/RelationalResponse/$defs/T52"}},"required":["type","nullable"]};
const wrapper21 = {validate: validate1802};
const schema503 = {"type":"boolean"};

function validate1831(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1831.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "boolean"){
validate1831.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "boolean"}}];
return false;
}
validate1831.errors = vErrors;
return errors === 0;
}
validate1831.evaluated = {"dynamicProps":false,"dynamicItems":false};


function validate1830(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1830.evaluated;
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
validate1830.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "type") || (key0 === "nullable"))){
validate1830.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.type !== undefined){
const _errs2 = errors;
if(!(wrapper21.validate(data.type, {instancePath:instancePath+"/type",parentData:data,parentDataProperty:"type",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? wrapper21.validate.errors : vErrors.concat(wrapper21.validate.errors);
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
if(!(validate1831(data.nullable, {instancePath:instancePath+"/nullable",parentData:data,parentDataProperty:"nullable",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1831.errors : vErrors.concat(validate1831.errors);
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
validate1830.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
return false;
}
}
validate1830.errors = vErrors;
return errors === 0;
}
validate1830.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema504 = {"type":"object","additionalProperties":false,"properties":{"element":{"$ref":"#/$defs/RelationalResponse/$defs/T50"},"length":{"$ref":"#/$defs/RelationalResponse/$defs/T54"}},"required":["element","length"]};
const schema21 = {"type":"integer","minimum":0,"maximum":4294967295};

function validate1836(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1836.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(!(((typeof data == "number") && (!(data % 1) && !isNaN(data))) && (isFinite(data)))){
validate1836.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "integer"}}];
return false;
}
if(errors === 0){
if((typeof data == "number") && (isFinite(data))){
if(data > 4294967295 || isNaN(data)){
validate1836.errors = [{instancePath,schemaPath:"#/maximum",keyword:"maximum",params:{comparison: "<=", limit: 4294967295}}];
return false;
}
else {
if(data < 0 || isNaN(data)){
validate1836.errors = [{instancePath,schemaPath:"#/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0}}];
return false;
}
}
}
}
validate1836.errors = vErrors;
return errors === 0;
}
validate1836.evaluated = {"dynamicProps":false,"dynamicItems":false};


function validate1834(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1834.evaluated;
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
validate1834.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "element") || (key0 === "length"))){
validate1834.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.element !== undefined){
const _errs2 = errors;
if(!(validate1830(data.element, {instancePath:instancePath+"/element",parentData:data,parentDataProperty:"element",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1830.errors : vErrors.concat(validate1830.errors);
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
if(!(validate1836(data.length, {instancePath:instancePath+"/length",parentData:data,parentDataProperty:"length",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1836.errors : vErrors.concat(validate1836.errors);
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
validate1834.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
return false;
}
}
validate1834.errors = vErrors;
return errors === 0;
}
validate1834.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema506 = {"type":"object","additionalProperties":false,"properties":{"key":{"$ref":"#/$defs/RelationalResponse/$defs/T51"},"value":{"$ref":"#/$defs/RelationalResponse/$defs/T50"}},"required":["key","value"]};

function validate1839(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1839.evaluated;
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
validate1839.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "key") || (key0 === "value"))){
validate1839.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.key !== undefined){
const _errs2 = errors;
if(!(wrapper21.validate(data.key, {instancePath:instancePath+"/key",parentData:data,parentDataProperty:"key",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? wrapper21.validate.errors : vErrors.concat(wrapper21.validate.errors);
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
if(!(validate1830(data.value, {instancePath:instancePath+"/value",parentData:data,parentDataProperty:"value",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1830.errors : vErrors.concat(validate1830.errors);
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
validate1839.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
return false;
}
}
validate1839.errors = vErrors;
return errors === 0;
}
validate1839.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema507 = {"type":"object","additionalProperties":false,"properties":{"dimensions":{"$ref":"#/$defs/RelationalResponse/$defs/T54"},"element":{"$ref":"#/$defs/RelationalResponse/$defs/T57"}},"required":["dimensions","element"]};
const schema193 = {"type":"string","enum":["float32","float16","bfloat16","int8","binary"]};

function validate1845(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1845.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate1845.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"}}];
return false;
}
if(!(((((data === "float32") || (data === "float16")) || (data === "bfloat16")) || (data === "int8")) || (data === "binary"))){
validate1845.errors = [{instancePath,schemaPath:"#/enum",keyword:"enum",params:{allowedValues: schema193.enum}}];
return false;
}
validate1845.errors = vErrors;
return errors === 0;
}
validate1845.evaluated = {"dynamicProps":false,"dynamicItems":false};


function validate1843(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1843.evaluated;
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
validate1843.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "dimensions") || (key0 === "element"))){
validate1843.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.dimensions !== undefined){
const _errs2 = errors;
if(!(validate1836(data.dimensions, {instancePath:instancePath+"/dimensions",parentData:data,parentDataProperty:"dimensions",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1836.errors : vErrors.concat(validate1836.errors);
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
if(!(validate1845(data.element, {instancePath:instancePath+"/element",parentData:data,parentDataProperty:"element",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1845.errors : vErrors.concat(validate1845.errors);
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
validate1843.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
return false;
}
}
validate1843.errors = vErrors;
return errors === 0;
}
validate1843.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const wrapper20 = {validate: validate1798};

function validate1802(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1802.evaluated;
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
if(!(validate1803(data.int64, {instancePath:instancePath+"/int64",parentData:data,parentDataProperty:"int64",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1803.errors : vErrors.concat(validate1803.errors);
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
if(!(validate1803(data.uint64, {instancePath:instancePath+"/uint64",parentData:data,parentDataProperty:"uint64",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1803.errors : vErrors.concat(validate1803.errors);
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
if(!(validate1803(data.float64, {instancePath:instancePath+"/float64",parentData:data,parentDataProperty:"float64",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1803.errors : vErrors.concat(validate1803.errors);
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
if(!(validate1803(data.boolean, {instancePath:instancePath+"/boolean",parentData:data,parentDataProperty:"boolean",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1803.errors : vErrors.concat(validate1803.errors);
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
if(!(validate1803(data.utf8, {instancePath:instancePath+"/utf8",parentData:data,parentDataProperty:"utf8",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1803.errors : vErrors.concat(validate1803.errors);
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
if(!(validate1803(data.binary, {instancePath:instancePath+"/binary",parentData:data,parentDataProperty:"binary",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1803.errors : vErrors.concat(validate1803.errors);
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
if(!(validate1803(data.int8, {instancePath:instancePath+"/int8",parentData:data,parentDataProperty:"int8",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1803.errors : vErrors.concat(validate1803.errors);
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
if(!(validate1803(data.int16, {instancePath:instancePath+"/int16",parentData:data,parentDataProperty:"int16",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1803.errors : vErrors.concat(validate1803.errors);
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
if(!(validate1803(data.int32, {instancePath:instancePath+"/int32",parentData:data,parentDataProperty:"int32",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1803.errors : vErrors.concat(validate1803.errors);
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
if(!(validate1803(data.int128, {instancePath:instancePath+"/int128",parentData:data,parentDataProperty:"int128",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1803.errors : vErrors.concat(validate1803.errors);
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
if(!(validate1803(data.uint8, {instancePath:instancePath+"/uint8",parentData:data,parentDataProperty:"uint8",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1803.errors : vErrors.concat(validate1803.errors);
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
if(!(validate1803(data.uint16, {instancePath:instancePath+"/uint16",parentData:data,parentDataProperty:"uint16",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1803.errors : vErrors.concat(validate1803.errors);
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
if(!(validate1803(data.uint32, {instancePath:instancePath+"/uint32",parentData:data,parentDataProperty:"uint32",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1803.errors : vErrors.concat(validate1803.errors);
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
if(!(validate1803(data.uint128, {instancePath:instancePath+"/uint128",parentData:data,parentDataProperty:"uint128",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1803.errors : vErrors.concat(validate1803.errors);
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
if(!(validate1803(data.float32, {instancePath:instancePath+"/float32",parentData:data,parentDataProperty:"float32",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1803.errors : vErrors.concat(validate1803.errors);
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
if(!(validate1819(data.decimal, {instancePath:instancePath+"/decimal",parentData:data,parentDataProperty:"decimal",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1819.errors : vErrors.concat(validate1819.errors);
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
if(!(validate1803(data.date, {instancePath:instancePath+"/date",parentData:data,parentDataProperty:"date",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1803.errors : vErrors.concat(validate1803.errors);
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
if(!(validate1803(data.time, {instancePath:instancePath+"/time",parentData:data,parentDataProperty:"time",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1803.errors : vErrors.concat(validate1803.errors);
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
if(!(validate1826(data.timestamp, {instancePath:instancePath+"/timestamp",parentData:data,parentDataProperty:"timestamp",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1826.errors : vErrors.concat(validate1826.errors);
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
if(!(validate1803(data.interval, {instancePath:instancePath+"/interval",parentData:data,parentDataProperty:"interval",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1803.errors : vErrors.concat(validate1803.errors);
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
if(!(validate1803(data.uuid, {instancePath:instancePath+"/uuid",parentData:data,parentDataProperty:"uuid",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1803.errors : vErrors.concat(validate1803.errors);
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
if(!(wrapper20.validate(data.structure, {instancePath:instancePath+"/structure",parentData:data,parentDataProperty:"structure",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? wrapper20.validate.errors : vErrors.concat(wrapper20.validate.errors);
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
if(!(validate1830(data.list, {instancePath:instancePath+"/list",parentData:data,parentDataProperty:"list",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1830.errors : vErrors.concat(validate1830.errors);
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
if(!(validate1834(data.array, {instancePath:instancePath+"/array",parentData:data,parentDataProperty:"array",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1834.errors : vErrors.concat(validate1834.errors);
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
if(!(validate1839(data.map, {instancePath:instancePath+"/map",parentData:data,parentDataProperty:"map",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1839.errors : vErrors.concat(validate1839.errors);
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
if(!(wrapper20.validate(data.tagged_union, {instancePath:instancePath+"/tagged_union",parentData:data,parentDataProperty:"tagged_union",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? wrapper20.validate.errors : vErrors.concat(wrapper20.validate.errors);
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
if(!(validate1803(data.json, {instancePath:instancePath+"/json",parentData:data,parentDataProperty:"json",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1803.errors : vErrors.concat(validate1803.errors);
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
const _errs109 = errors;
if(errors === _errs109){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing27;
if((data.range === undefined) && (missing27 = "range")){
const err81 = {instancePath,schemaPath:"#/oneOf/27/required",keyword:"required",params:{missingProperty: missing27}};
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
const err82 = {instancePath,schemaPath:"#/oneOf/27/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key27}};
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
if(!(wrapper21.validate(data.range, {instancePath:instancePath+"/range",parentData:data,parentDataProperty:"range",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? wrapper21.validate.errors : vErrors.concat(wrapper21.validate.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err83 = {instancePath,schemaPath:"#/oneOf/27/type",keyword:"type",params:{type: "object"}};
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
const err84 = {instancePath,schemaPath:"#/oneOf/28/required",keyword:"required",params:{missingProperty: missing28}};
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
const err85 = {instancePath,schemaPath:"#/oneOf/28/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key28}};
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
if(!(wrapper21.validate(data.multirange, {instancePath:instancePath+"/multirange",parentData:data,parentDataProperty:"multirange",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? wrapper21.validate.errors : vErrors.concat(wrapper21.validate.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err86 = {instancePath,schemaPath:"#/oneOf/28/type",keyword:"type",params:{type: "object"}};
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
const err87 = {instancePath,schemaPath:"#/oneOf/29/required",keyword:"required",params:{missingProperty: missing29}};
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
const err88 = {instancePath,schemaPath:"#/oneOf/29/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key29}};
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
if(!(validate1843(data.vector, {instancePath:instancePath+"/vector",parentData:data,parentDataProperty:"vector",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1843.errors : vErrors.concat(validate1843.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err89 = {instancePath,schemaPath:"#/oneOf/29/type",keyword:"type",params:{type: "object"}};
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
const err90 = {instancePath,schemaPath:"#/oneOf",keyword:"oneOf",params:{passingSchemas: passing0}};
if(vErrors === null){
vErrors = [err90];
}
else {
vErrors.push(err90);
}
errors++;
validate1802.errors = vErrors;
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
validate1802.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate1802.evaluated = {"dynamicProps":true,"dynamicItems":false};


function validate1799(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1799.evaluated;
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
validate1799.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((((key0 === "name") || (key0 === "type")) || (key0 === "nullable")) || (key0 === "optional"))){
validate1799.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.name !== undefined){
const _errs2 = errors;
if(!(validate1800(data.name, {instancePath:instancePath+"/name",parentData:data,parentDataProperty:"name",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1800.errors : vErrors.concat(validate1800.errors);
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
if(!(validate1802(data.type, {instancePath:instancePath+"/type",parentData:data,parentDataProperty:"type",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1802.errors : vErrors.concat(validate1802.errors);
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
if(!(validate1831(data.nullable, {instancePath:instancePath+"/nullable",parentData:data,parentDataProperty:"nullable",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1831.errors : vErrors.concat(validate1831.errors);
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
if(!(validate1831(data.optional, {instancePath:instancePath+"/optional",parentData:data,parentDataProperty:"optional",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1831.errors : vErrors.concat(validate1831.errors);
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
validate1799.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
return false;
}
}
validate1799.errors = vErrors;
return errors === 0;
}
validate1799.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


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
if(errors === 0){
if(Array.isArray(data)){
if(data.length > 256){
validate1798.errors = [{instancePath,schemaPath:"#/maxItems",keyword:"maxItems",params:{limit: 256}}];
return false;
}
else {
var valid0 = true;
const len0 = data.length;
for(let i0=0; i0<len0; i0++){
const _errs1 = errors;
if(!(validate1799(data[i0], {instancePath:instancePath+"/" + i0,parentData:data,parentDataProperty:i0,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1799.errors : vErrors.concat(validate1799.errors);
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
validate1798.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "array"}}];
return false;
}
}
validate1798.errors = vErrors;
return errors === 0;
}
validate1798.evaluated = {"items":true,"dynamicProps":false,"dynamicItems":false};

const schema509 = {"type":"object","additionalProperties":false,"properties":{"type":{"$ref":"#/$defs/RelationalResponse/$defs/T59"},"nullable":{"$ref":"#/$defs/RelationalResponse/$defs/T5"}},"required":["type","nullable"]};
const wrapper26 = {validate: validate1771};

function validate1853(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1853.evaluated;
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
validate1853.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "type") || (key0 === "nullable"))){
validate1853.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.type !== undefined){
const _errs2 = errors;
if(!(wrapper26.validate(data.type, {instancePath:instancePath+"/type",parentData:data,parentDataProperty:"type",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? wrapper26.validate.errors : vErrors.concat(wrapper26.validate.errors);
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
if(!(validate1662(data.nullable, {instancePath:instancePath+"/nullable",parentData:data,parentDataProperty:"nullable",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1662.errors : vErrors.concat(validate1662.errors);
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
validate1853.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
return false;
}
}
validate1853.errors = vErrors;
return errors === 0;
}
validate1853.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema510 = {"type":"object","additionalProperties":false,"properties":{"element":{"$ref":"#/$defs/RelationalResponse/$defs/T58"},"length":{"$ref":"#/$defs/RelationalResponse/$defs/T61"}},"required":["element","length"]};

function validate1858(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1858.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(!(((typeof data == "number") && (!(data % 1) && !isNaN(data))) && (isFinite(data)))){
validate1858.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "integer"}}];
return false;
}
if(errors === 0){
if((typeof data == "number") && (isFinite(data))){
if(data > 4294967295 || isNaN(data)){
validate1858.errors = [{instancePath,schemaPath:"#/maximum",keyword:"maximum",params:{comparison: "<=", limit: 4294967295}}];
return false;
}
else {
if(data < 0 || isNaN(data)){
validate1858.errors = [{instancePath,schemaPath:"#/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0}}];
return false;
}
}
}
}
validate1858.errors = vErrors;
return errors === 0;
}
validate1858.evaluated = {"dynamicProps":false,"dynamicItems":false};


function validate1856(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1856.evaluated;
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
validate1856.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "element") || (key0 === "length"))){
validate1856.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.element !== undefined){
const _errs2 = errors;
if(!(validate1853(data.element, {instancePath:instancePath+"/element",parentData:data,parentDataProperty:"element",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1853.errors : vErrors.concat(validate1853.errors);
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
if(!(validate1858(data.length, {instancePath:instancePath+"/length",parentData:data,parentDataProperty:"length",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1858.errors : vErrors.concat(validate1858.errors);
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
validate1856.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
return false;
}
}
validate1856.errors = vErrors;
return errors === 0;
}
validate1856.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema512 = {"type":"object","additionalProperties":false,"properties":{"key":{"$ref":"#/$defs/RelationalResponse/$defs/T59"},"value":{"$ref":"#/$defs/RelationalResponse/$defs/T58"}},"required":["key","value"]};

function validate1861(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1861.evaluated;
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
validate1861.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "key") || (key0 === "value"))){
validate1861.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.key !== undefined){
const _errs2 = errors;
if(!(wrapper26.validate(data.key, {instancePath:instancePath+"/key",parentData:data,parentDataProperty:"key",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? wrapper26.validate.errors : vErrors.concat(wrapper26.validate.errors);
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
if(!(validate1853(data.value, {instancePath:instancePath+"/value",parentData:data,parentDataProperty:"value",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1853.errors : vErrors.concat(validate1853.errors);
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
validate1861.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
return false;
}
}
validate1861.errors = vErrors;
return errors === 0;
}
validate1861.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema513 = {"type":"object","additionalProperties":false,"properties":{"dimensions":{"$ref":"#/$defs/RelationalResponse/$defs/T61"},"element":{"$ref":"#/$defs/RelationalResponse/$defs/T64"}},"required":["dimensions","element"]};

function validate1868(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1868.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate1868.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"}}];
return false;
}
if(!(((((data === "float32") || (data === "float16")) || (data === "bfloat16")) || (data === "int8")) || (data === "binary"))){
validate1868.errors = [{instancePath,schemaPath:"#/enum",keyword:"enum",params:{allowedValues: schema193.enum}}];
return false;
}
validate1868.errors = vErrors;
return errors === 0;
}
validate1868.evaluated = {"dynamicProps":false,"dynamicItems":false};


function validate1866(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1866.evaluated;
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
validate1866.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "dimensions") || (key0 === "element"))){
validate1866.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.dimensions !== undefined){
const _errs2 = errors;
if(!(validate1858(data.dimensions, {instancePath:instancePath+"/dimensions",parentData:data,parentDataProperty:"dimensions",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1858.errors : vErrors.concat(validate1858.errors);
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
if(!(validate1868(data.element, {instancePath:instancePath+"/element",parentData:data,parentDataProperty:"element",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1868.errors : vErrors.concat(validate1868.errors);
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
validate1866.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
return false;
}
}
validate1866.errors = vErrors;
return errors === 0;
}
validate1866.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate1771(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1771.evaluated;
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
if(!(validate1772(data.int64, {instancePath:instancePath+"/int64",parentData:data,parentDataProperty:"int64",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1772.errors : vErrors.concat(validate1772.errors);
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
if(!(validate1772(data.uint64, {instancePath:instancePath+"/uint64",parentData:data,parentDataProperty:"uint64",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1772.errors : vErrors.concat(validate1772.errors);
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
if(!(validate1772(data.float64, {instancePath:instancePath+"/float64",parentData:data,parentDataProperty:"float64",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1772.errors : vErrors.concat(validate1772.errors);
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
if(!(validate1772(data.boolean, {instancePath:instancePath+"/boolean",parentData:data,parentDataProperty:"boolean",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1772.errors : vErrors.concat(validate1772.errors);
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
if(!(validate1772(data.utf8, {instancePath:instancePath+"/utf8",parentData:data,parentDataProperty:"utf8",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1772.errors : vErrors.concat(validate1772.errors);
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
if(!(validate1772(data.binary, {instancePath:instancePath+"/binary",parentData:data,parentDataProperty:"binary",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1772.errors : vErrors.concat(validate1772.errors);
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
if(!(validate1772(data.int8, {instancePath:instancePath+"/int8",parentData:data,parentDataProperty:"int8",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1772.errors : vErrors.concat(validate1772.errors);
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
if(!(validate1772(data.int16, {instancePath:instancePath+"/int16",parentData:data,parentDataProperty:"int16",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1772.errors : vErrors.concat(validate1772.errors);
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
if(!(validate1772(data.int32, {instancePath:instancePath+"/int32",parentData:data,parentDataProperty:"int32",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1772.errors : vErrors.concat(validate1772.errors);
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
if(!(validate1772(data.int128, {instancePath:instancePath+"/int128",parentData:data,parentDataProperty:"int128",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1772.errors : vErrors.concat(validate1772.errors);
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
if(!(validate1772(data.uint8, {instancePath:instancePath+"/uint8",parentData:data,parentDataProperty:"uint8",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1772.errors : vErrors.concat(validate1772.errors);
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
if(!(validate1772(data.uint16, {instancePath:instancePath+"/uint16",parentData:data,parentDataProperty:"uint16",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1772.errors : vErrors.concat(validate1772.errors);
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
if(!(validate1772(data.uint32, {instancePath:instancePath+"/uint32",parentData:data,parentDataProperty:"uint32",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1772.errors : vErrors.concat(validate1772.errors);
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
if(!(validate1772(data.uint128, {instancePath:instancePath+"/uint128",parentData:data,parentDataProperty:"uint128",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1772.errors : vErrors.concat(validate1772.errors);
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
if(!(validate1772(data.float32, {instancePath:instancePath+"/float32",parentData:data,parentDataProperty:"float32",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1772.errors : vErrors.concat(validate1772.errors);
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
if(!(validate1788(data.decimal, {instancePath:instancePath+"/decimal",parentData:data,parentDataProperty:"decimal",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1788.errors : vErrors.concat(validate1788.errors);
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
if(!(validate1772(data.date, {instancePath:instancePath+"/date",parentData:data,parentDataProperty:"date",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1772.errors : vErrors.concat(validate1772.errors);
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
if(!(validate1772(data.time, {instancePath:instancePath+"/time",parentData:data,parentDataProperty:"time",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1772.errors : vErrors.concat(validate1772.errors);
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
if(!(validate1794(data.timestamp, {instancePath:instancePath+"/timestamp",parentData:data,parentDataProperty:"timestamp",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1794.errors : vErrors.concat(validate1794.errors);
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
if(!(validate1772(data.interval, {instancePath:instancePath+"/interval",parentData:data,parentDataProperty:"interval",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1772.errors : vErrors.concat(validate1772.errors);
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
if(!(validate1772(data.uuid, {instancePath:instancePath+"/uuid",parentData:data,parentDataProperty:"uuid",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1772.errors : vErrors.concat(validate1772.errors);
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
if(!(validate1798(data.structure, {instancePath:instancePath+"/structure",parentData:data,parentDataProperty:"structure",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1798.errors : vErrors.concat(validate1798.errors);
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
if(!(validate1853(data.list, {instancePath:instancePath+"/list",parentData:data,parentDataProperty:"list",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1853.errors : vErrors.concat(validate1853.errors);
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
if(!(validate1856(data.array, {instancePath:instancePath+"/array",parentData:data,parentDataProperty:"array",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1856.errors : vErrors.concat(validate1856.errors);
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
if(!(validate1861(data.map, {instancePath:instancePath+"/map",parentData:data,parentDataProperty:"map",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1861.errors : vErrors.concat(validate1861.errors);
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
if(!(validate1798(data.tagged_union, {instancePath:instancePath+"/tagged_union",parentData:data,parentDataProperty:"tagged_union",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1798.errors : vErrors.concat(validate1798.errors);
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
if(!(validate1772(data.json, {instancePath:instancePath+"/json",parentData:data,parentDataProperty:"json",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1772.errors : vErrors.concat(validate1772.errors);
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
const _errs109 = errors;
if(errors === _errs109){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing27;
if((data.range === undefined) && (missing27 = "range")){
const err81 = {instancePath,schemaPath:"#/oneOf/27/required",keyword:"required",params:{missingProperty: missing27}};
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
const err82 = {instancePath,schemaPath:"#/oneOf/27/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key27}};
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
if(!(wrapper26.validate(data.range, {instancePath:instancePath+"/range",parentData:data,parentDataProperty:"range",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? wrapper26.validate.errors : vErrors.concat(wrapper26.validate.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err83 = {instancePath,schemaPath:"#/oneOf/27/type",keyword:"type",params:{type: "object"}};
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
const err84 = {instancePath,schemaPath:"#/oneOf/28/required",keyword:"required",params:{missingProperty: missing28}};
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
const err85 = {instancePath,schemaPath:"#/oneOf/28/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key28}};
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
if(!(wrapper26.validate(data.multirange, {instancePath:instancePath+"/multirange",parentData:data,parentDataProperty:"multirange",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? wrapper26.validate.errors : vErrors.concat(wrapper26.validate.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err86 = {instancePath,schemaPath:"#/oneOf/28/type",keyword:"type",params:{type: "object"}};
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
const err87 = {instancePath,schemaPath:"#/oneOf/29/required",keyword:"required",params:{missingProperty: missing29}};
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
const err88 = {instancePath,schemaPath:"#/oneOf/29/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key29}};
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
if(!(validate1866(data.vector, {instancePath:instancePath+"/vector",parentData:data,parentDataProperty:"vector",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1866.errors : vErrors.concat(validate1866.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err89 = {instancePath,schemaPath:"#/oneOf/29/type",keyword:"type",params:{type: "object"}};
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
const err90 = {instancePath,schemaPath:"#/oneOf",keyword:"oneOf",params:{passingSchemas: passing0}};
if(vErrors === null){
vErrors = [err90];
}
else {
vErrors.push(err90);
}
errors++;
validate1771.errors = vErrors;
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
validate1771.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate1771.evaluated = {"dynamicProps":true,"dynamicItems":false};


function validate1769(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1769.evaluated;
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
validate1769.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((((key0 === "name") || (key0 === "type")) || (key0 === "nullable")) || (key0 === "optional"))){
validate1769.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.name !== undefined){
const _errs2 = errors;
if(!(validate1726(data.name, {instancePath:instancePath+"/name",parentData:data,parentDataProperty:"name",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1726.errors : vErrors.concat(validate1726.errors);
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
if(!(validate1771(data.type, {instancePath:instancePath+"/type",parentData:data,parentDataProperty:"type",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1771.errors : vErrors.concat(validate1771.errors);
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
if(!(validate1662(data.nullable, {instancePath:instancePath+"/nullable",parentData:data,parentDataProperty:"nullable",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1662.errors : vErrors.concat(validate1662.errors);
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
if(!(validate1662(data.optional, {instancePath:instancePath+"/optional",parentData:data,parentDataProperty:"optional",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1662.errors : vErrors.concat(validate1662.errors);
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
validate1769.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
return false;
}
}
validate1769.errors = vErrors;
return errors === 0;
}
validate1769.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate1768(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1768.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(Array.isArray(data)){
if(data.length > 128){
validate1768.errors = [{instancePath,schemaPath:"#/maxItems",keyword:"maxItems",params:{limit: 128}}];
return false;
}
else {
var valid0 = true;
const len0 = data.length;
for(let i0=0; i0<len0; i0++){
const _errs1 = errors;
if(!(validate1769(data[i0], {instancePath:instancePath+"/" + i0,parentData:data,parentDataProperty:i0,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1769.errors : vErrors.concat(validate1769.errors);
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
validate1768.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "array"}}];
return false;
}
}
validate1768.errors = vErrors;
return errors === 0;
}
validate1768.evaluated = {"items":true,"dynamicProps":false,"dynamicItems":false};

const schema515 = {"anyOf":[{"$ref":"#/$defs/RelationalResponse/$defs/T66"},{"type":"null"}]};
const schema516 = {"type":"string","enum":["inner","left"]};

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
if(typeof data !== "string"){
validate1877.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"}}];
return false;
}
if(!((data === "inner") || (data === "left"))){
validate1877.errors = [{instancePath,schemaPath:"#/enum",keyword:"enum",params:{allowedValues: schema516.enum}}];
return false;
}
validate1877.errors = vErrors;
return errors === 0;
}
validate1877.evaluated = {"dynamicProps":false,"dynamicItems":false};


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
return errors === 0;
}
validate1876.evaluated = {"dynamicProps":false,"dynamicItems":false};


function validate1731(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1731.evaluated;
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
validate1731.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((((((key0 === "definition") || (key0 === "plan")) || (key0 === "sources")) || (key0 === "columns")) || (key0 === "join")) || (key0 === "grouped")) || (key0 === "executed"))){
validate1731.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.definition !== undefined){
const _errs2 = errors;
if(!(validate1656(data.definition, {instancePath:instancePath+"/definition",parentData:data,parentDataProperty:"definition",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1656.errors : vErrors.concat(validate1656.errors);
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
if(!(validate1726(data.plan, {instancePath:instancePath+"/plan",parentData:data,parentDataProperty:"plan",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1726.errors : vErrors.concat(validate1726.errors);
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
if(!(validate1734(data.sources, {instancePath:instancePath+"/sources",parentData:data,parentDataProperty:"sources",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1734.errors : vErrors.concat(validate1734.errors);
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
if(!(validate1768(data.columns, {instancePath:instancePath+"/columns",parentData:data,parentDataProperty:"columns",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1768.errors : vErrors.concat(validate1768.errors);
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
if(!(validate1876(data.join, {instancePath:instancePath+"/join",parentData:data,parentDataProperty:"join",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1876.errors : vErrors.concat(validate1876.errors);
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
if(!(validate1662(data.grouped, {instancePath:instancePath+"/grouped",parentData:data,parentDataProperty:"grouped",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1662.errors : vErrors.concat(validate1662.errors);
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
if(!(validate1662(data.executed, {instancePath:instancePath+"/executed",parentData:data,parentDataProperty:"executed",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1662.errors : vErrors.concat(validate1662.errors);
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
validate1731.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
return false;
}
}
validate1731.errors = vErrors;
return errors === 0;
}
validate1731.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema517 = {"type":"array","maxItems":2,"items":{"$ref":"#/$defs/RelationalResponse/$defs/T68"}};
const schema518 = {"type":"object","additionalProperties":false,"properties":{"object":{"$ref":"#/$defs/RelationalResponse/$defs/T32"},"position":{"$ref":"#/$defs/RelationalResponse/$defs/T35"},"commitment":{"$ref":"#/$defs/RelationalResponse/$defs/T12"},"schema":{"$ref":"#/$defs/RelationalResponse/$defs/T12"}},"required":["object","position","commitment","schema"]};

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
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if(((((data.object === undefined) && (missing0 = "object")) || ((data.position === undefined) && (missing0 = "position"))) || ((data.commitment === undefined) && (missing0 = "commitment"))) || ((data.schema === undefined) && (missing0 = "schema"))){
validate1884.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((((key0 === "object") || (key0 === "position")) || (key0 === "commitment")) || (key0 === "schema"))){
validate1884.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.object !== undefined){
const _errs2 = errors;
if(!(validate1745(data.object, {instancePath:instancePath+"/object",parentData:data,parentDataProperty:"object",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1745.errors : vErrors.concat(validate1745.errors);
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
if(!(validate1762(data.position, {instancePath:instancePath+"/position",parentData:data,parentDataProperty:"position",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1762.errors : vErrors.concat(validate1762.errors);
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
if(!(validate1676(data.commitment, {instancePath:instancePath+"/commitment",parentData:data,parentDataProperty:"commitment",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1676.errors : vErrors.concat(validate1676.errors);
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
if(!(validate1676(data.schema, {instancePath:instancePath+"/schema",parentData:data,parentDataProperty:"schema",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1676.errors : vErrors.concat(validate1676.errors);
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
validate1884.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
return false;
}
}
validate1884.errors = vErrors;
return errors === 0;
}
validate1884.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


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
if(data.length > 2){
validate1883.errors = [{instancePath,schemaPath:"#/maxItems",keyword:"maxItems",params:{limit: 2}}];
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


function validate1723(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1723.evaluated;
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
validate1723.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((((key0 === "reference") || (key0 === "description")) || (key0 === "cuts")) || (key0 === "complete_coverage"))){
validate1723.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.reference !== undefined){
const _errs2 = errors;
if(!(validate1724(data.reference, {instancePath:instancePath+"/reference",parentData:data,parentDataProperty:"reference",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1724.errors : vErrors.concat(validate1724.errors);
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
if(!(validate1731(data.description, {instancePath:instancePath+"/description",parentData:data,parentDataProperty:"description",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1731.errors : vErrors.concat(validate1731.errors);
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
if(!(validate1883(data.cuts, {instancePath:instancePath+"/cuts",parentData:data,parentDataProperty:"cuts",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1883.errors : vErrors.concat(validate1883.errors);
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
if(!(validate1662(data.complete_coverage, {instancePath:instancePath+"/complete_coverage",parentData:data,parentDataProperty:"complete_coverage",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1662.errors : vErrors.concat(validate1662.errors);
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
validate1723.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
return false;
}
}
validate1723.errors = vErrors;
return errors === 0;
}
validate1723.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate1722(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1722.evaluated;
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
validate1722.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "opened") || (key0 === "ordinal")) || (key0 === "read"))){
validate1722.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.opened !== undefined){
const _errs2 = errors;
if(!(validate1723(data.opened, {instancePath:instancePath+"/opened",parentData:data,parentDataProperty:"opened",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1723.errors : vErrors.concat(validate1723.errors);
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
if(!(validate1726(data.ordinal, {instancePath:instancePath+"/ordinal",parentData:data,parentDataProperty:"ordinal",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1726.errors : vErrors.concat(validate1726.errors);
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
if(!(validate1662(data.read, {instancePath:instancePath+"/read",parentData:data,parentDataProperty:"read",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1662.errors : vErrors.concat(validate1662.errors);
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
validate1722.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
return false;
}
}
validate1722.errors = vErrors;
return errors === 0;
}
validate1722.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate1721(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1721.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate1722(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1722.errors : vErrors.concat(validate1722.errors);
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
validate1721.errors = vErrors;
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
validate1721.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate1721.evaluated = {"dynamicProps":true,"dynamicItems":false};

const schema519 = {"anyOf":[{"$ref":"#/$defs/RelationalResponse/$defs/T70"},{"type":"null"}]};
const schema520 = {"type":"object","additionalProperties":false,"properties":{"id":{"$ref":"#/$defs/RelationalResponse/$defs/T24"},"state":{"$ref":"#/$defs/RelationalResponse/$defs/T71"},"remaining_pins":{"$ref":"#/$defs/RelationalResponse/$defs/T4"}},"required":["id","state","remaining_pins"]};
const schema521 = {"type":"string","enum":["acquiring","active","closing"]};

function validate1900(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1900.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate1900.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"}}];
return false;
}
if(!(((data === "acquiring") || (data === "active")) || (data === "closing"))){
validate1900.errors = [{instancePath,schemaPath:"#/enum",keyword:"enum",params:{allowedValues: schema521.enum}}];
return false;
}
validate1900.errors = vErrors;
return errors === 0;
}
validate1900.evaluated = {"dynamicProps":false,"dynamicItems":false};


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
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((((data.id === undefined) && (missing0 = "id")) || ((data.state === undefined) && (missing0 = "state"))) || ((data.remaining_pins === undefined) && (missing0 = "remaining_pins"))){
validate1898.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "id") || (key0 === "state")) || (key0 === "remaining_pins"))){
validate1898.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.id !== undefined){
const _errs2 = errors;
if(!(validate1726(data.id, {instancePath:instancePath+"/id",parentData:data,parentDataProperty:"id",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1726.errors : vErrors.concat(validate1726.errors);
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
if(!(validate1900(data.state, {instancePath:instancePath+"/state",parentData:data,parentDataProperty:"state",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1900.errors : vErrors.concat(validate1900.errors);
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
if(!(validate1658(data.remaining_pins, {instancePath:instancePath+"/remaining_pins",parentData:data,parentDataProperty:"remaining_pins",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1658.errors : vErrors.concat(validate1658.errors);
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
validate1898.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
return false;
}
}
validate1898.errors = vErrors;
return errors === 0;
}
validate1898.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate1897(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1897.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate1898(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1898.errors : vErrors.concat(validate1898.errors);
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
validate1897.errors = vErrors;
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
validate1897.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate1897.evaluated = {"dynamicProps":true,"dynamicItems":false};


function validate1654(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1654.evaluated;
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
validate1654.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((((key0 === "capabilities") || (key0 === "routes")) || (key0 === "active")) || (key0 === "recovery"))){
validate1654.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.capabilities !== undefined){
const _errs2 = errors;
if(!(validate1655(data.capabilities, {instancePath:instancePath+"/capabilities",parentData:data,parentDataProperty:"capabilities",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1655.errors : vErrors.concat(validate1655.errors);
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
if(!(validate1669(data.routes, {instancePath:instancePath+"/routes",parentData:data,parentDataProperty:"routes",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1669.errors : vErrors.concat(validate1669.errors);
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
if(!(validate1721(data.active, {instancePath:instancePath+"/active",parentData:data,parentDataProperty:"active",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1721.errors : vErrors.concat(validate1721.errors);
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
if(!(validate1897(data.recovery, {instancePath:instancePath+"/recovery",parentData:data,parentDataProperty:"recovery",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1897.errors : vErrors.concat(validate1897.errors);
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
validate1654.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
return false;
}
}
validate1654.errors = vErrors;
return errors === 0;
}
validate1654.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema522 = {"type":"object","additionalProperties":false,"properties":{"binding":{"$ref":"#/$defs/RelationalResponse/$defs/T73"},"observed":{"$ref":"#/$defs/RelationalResponse/$defs/T82"}},"required":["binding","observed"]};
const schema523 = {"type":"object","additionalProperties":false,"properties":{"definition":{"$ref":"#/$defs/RelationalResponse/$defs/T3"},"connection":{"$ref":"#/$defs/RelationalResponse/$defs/T74"},"namespace":{"$ref":"#/$defs/RelationalResponse/$defs/T76"},"name":{"$ref":"#/$defs/RelationalResponse/$defs/T24"},"interpretation":{"$ref":"#/$defs/RelationalResponse/$defs/T78"}},"required":["definition","connection","namespace","name","interpretation"]};
const schema524 = {"type":"object","additionalProperties":false,"properties":{"scope":{"$ref":"#/$defs/RelationalResponse/$defs/T75"},"branch":{"$ref":"#/$defs/RelationalResponse/$defs/T24"},"audience":{"$ref":"#/$defs/RelationalResponse/$defs/T76"},"principal":{"$ref":"#/$defs/RelationalResponse/$defs/T76"},"role":{"$ref":"#/$defs/RelationalResponse/$defs/T77"}},"required":["scope","branch","audience","principal","role"]};
const schema525 = {"type":"object","additionalProperties":false,"properties":{"realm":{"$ref":"#/$defs/RelationalResponse/$defs/T76"},"resource":{"$ref":"#/$defs/RelationalResponse/$defs/T76"},"catalog":{"$ref":"#/$defs/RelationalResponse/$defs/T24"}},"required":["realm","resource","catalog"]};

function validate1911(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1911.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(!(((typeof data == "number") && (!(data % 1) && !isNaN(data))) && (isFinite(data)))){
validate1911.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "integer"}}];
return false;
}
if(errors === 0){
if((typeof data == "number") && (isFinite(data))){
if(data > 9007199254740991 || isNaN(data)){
validate1911.errors = [{instancePath,schemaPath:"#/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991}}];
return false;
}
else {
if(data < 0 || isNaN(data)){
validate1911.errors = [{instancePath,schemaPath:"#/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0}}];
return false;
}
}
}
}
validate1911.errors = vErrors;
return errors === 0;
}
validate1911.evaluated = {"dynamicProps":false,"dynamicItems":false};


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
if((((data.realm === undefined) && (missing0 = "realm")) || ((data.resource === undefined) && (missing0 = "resource"))) || ((data.catalog === undefined) && (missing0 = "catalog"))){
validate1910.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "realm") || (key0 === "resource")) || (key0 === "catalog"))){
validate1910.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.realm !== undefined){
const _errs2 = errors;
if(!(validate1911(data.realm, {instancePath:instancePath+"/realm",parentData:data,parentDataProperty:"realm",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1911.errors : vErrors.concat(validate1911.errors);
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
if(!(validate1911(data.resource, {instancePath:instancePath+"/resource",parentData:data,parentDataProperty:"resource",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1911.errors : vErrors.concat(validate1911.errors);
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
if(!(validate1726(data.catalog, {instancePath:instancePath+"/catalog",parentData:data,parentDataProperty:"catalog",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1726.errors : vErrors.concat(validate1726.errors);
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

const schema527 = {"anyOf":[{"$ref":"#/$defs/RelationalResponse/$defs/T76"},{"type":"null"}]};

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
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate1911(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1911.errors : vErrors.concat(validate1911.errors);
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
validate1919.errors = vErrors;
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
validate1919.errors = vErrors;
return errors === 0;
}
validate1919.evaluated = {"dynamicProps":false,"dynamicItems":false};


function validate1909(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1909.evaluated;
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
validate1909.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((((key0 === "scope") || (key0 === "branch")) || (key0 === "audience")) || (key0 === "principal")) || (key0 === "role"))){
validate1909.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.scope !== undefined){
const _errs2 = errors;
if(!(validate1910(data.scope, {instancePath:instancePath+"/scope",parentData:data,parentDataProperty:"scope",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1910.errors : vErrors.concat(validate1910.errors);
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
if(!(validate1726(data.branch, {instancePath:instancePath+"/branch",parentData:data,parentDataProperty:"branch",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1726.errors : vErrors.concat(validate1726.errors);
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
if(!(validate1911(data.audience, {instancePath:instancePath+"/audience",parentData:data,parentDataProperty:"audience",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1911.errors : vErrors.concat(validate1911.errors);
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
if(!(validate1911(data.principal, {instancePath:instancePath+"/principal",parentData:data,parentDataProperty:"principal",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1911.errors : vErrors.concat(validate1911.errors);
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
if(!(validate1919(data.role, {instancePath:instancePath+"/role",parentData:data,parentDataProperty:"role",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1919.errors : vErrors.concat(validate1919.errors);
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
validate1909.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
return false;
}
}
validate1909.errors = vErrors;
return errors === 0;
}
validate1909.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema528 = {"type":"object","additionalProperties":false,"properties":{"interpretation":{"$ref":"#/$defs/RelationalResponse/$defs/T79"},"content":{"$ref":"#/$defs/RelationalResponse/$defs/T81"},"schema_fingerprint":{"$ref":"#/$defs/RelationalResponse/$defs/T24"},"retired":{"$ref":"#/$defs/RelationalResponse/$defs/T5"}},"required":["interpretation","content","schema_fingerprint","retired"]};
const schema529 = {"type":"object","additionalProperties":false,"properties":{"object":{"$ref":"#/$defs/RelationalResponse/$defs/T80"},"revision":{"$ref":"#/$defs/RelationalResponse/$defs/T24"},"digest":{"$ref":"#/$defs/RelationalResponse/$defs/T24"}},"required":["object","revision","digest"]};
const schema530 = {"type":"object","additionalProperties":false,"properties":{"scope":{"$ref":"#/$defs/RelationalResponse/$defs/T75"},"branch":{"$ref":"#/$defs/RelationalResponse/$defs/T24"},"object":{"$ref":"#/$defs/RelationalResponse/$defs/T24"}},"required":["scope","branch","object"]};

function validate1927(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1927.evaluated;
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
validate1927.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "scope") || (key0 === "branch")) || (key0 === "object"))){
validate1927.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.scope !== undefined){
const _errs2 = errors;
if(!(validate1910(data.scope, {instancePath:instancePath+"/scope",parentData:data,parentDataProperty:"scope",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1910.errors : vErrors.concat(validate1910.errors);
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
if(!(validate1726(data.branch, {instancePath:instancePath+"/branch",parentData:data,parentDataProperty:"branch",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1726.errors : vErrors.concat(validate1726.errors);
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
if(!(validate1726(data.object, {instancePath:instancePath+"/object",parentData:data,parentDataProperty:"object",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1726.errors : vErrors.concat(validate1726.errors);
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
validate1927.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
return false;
}
}
validate1927.errors = vErrors;
return errors === 0;
}
validate1927.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


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
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((((data.object === undefined) && (missing0 = "object")) || ((data.revision === undefined) && (missing0 = "revision"))) || ((data.digest === undefined) && (missing0 = "digest"))){
validate1926.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "object") || (key0 === "revision")) || (key0 === "digest"))){
validate1926.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.object !== undefined){
const _errs2 = errors;
if(!(validate1927(data.object, {instancePath:instancePath+"/object",parentData:data,parentDataProperty:"object",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1927.errors : vErrors.concat(validate1927.errors);
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
if(!(validate1726(data.revision, {instancePath:instancePath+"/revision",parentData:data,parentDataProperty:"revision",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1726.errors : vErrors.concat(validate1726.errors);
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
if(!(validate1726(data.digest, {instancePath:instancePath+"/digest",parentData:data,parentDataProperty:"digest",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1726.errors : vErrors.concat(validate1726.errors);
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
validate1926.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
return false;
}
}
validate1926.errors = vErrors;
return errors === 0;
}
validate1926.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema531 = {"type":"object","additionalProperties":false,"properties":{"bytes":{"$ref":"#/$defs/RelationalResponse/$defs/T24"},"sha256":{"$ref":"#/$defs/RelationalResponse/$defs/T24"}},"required":["bytes","sha256"]};

function validate1935(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1935.evaluated;
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
validate1935.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "bytes") || (key0 === "sha256"))){
validate1935.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.bytes !== undefined){
const _errs2 = errors;
if(!(validate1726(data.bytes, {instancePath:instancePath+"/bytes",parentData:data,parentDataProperty:"bytes",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1726.errors : vErrors.concat(validate1726.errors);
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
if(!(validate1726(data.sha256, {instancePath:instancePath+"/sha256",parentData:data,parentDataProperty:"sha256",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1726.errors : vErrors.concat(validate1726.errors);
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
validate1935.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
return false;
}
}
validate1935.errors = vErrors;
return errors === 0;
}
validate1935.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


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
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if(((((data.interpretation === undefined) && (missing0 = "interpretation")) || ((data.content === undefined) && (missing0 = "content"))) || ((data.schema_fingerprint === undefined) && (missing0 = "schema_fingerprint"))) || ((data.retired === undefined) && (missing0 = "retired"))){
validate1925.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((((key0 === "interpretation") || (key0 === "content")) || (key0 === "schema_fingerprint")) || (key0 === "retired"))){
validate1925.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.interpretation !== undefined){
const _errs2 = errors;
if(!(validate1926(data.interpretation, {instancePath:instancePath+"/interpretation",parentData:data,parentDataProperty:"interpretation",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1926.errors : vErrors.concat(validate1926.errors);
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
if(!(validate1935(data.content, {instancePath:instancePath+"/content",parentData:data,parentDataProperty:"content",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1935.errors : vErrors.concat(validate1935.errors);
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
if(!(validate1726(data.schema_fingerprint, {instancePath:instancePath+"/schema_fingerprint",parentData:data,parentDataProperty:"schema_fingerprint",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1726.errors : vErrors.concat(validate1726.errors);
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
if(!(validate1662(data.retired, {instancePath:instancePath+"/retired",parentData:data,parentDataProperty:"retired",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1662.errors : vErrors.concat(validate1662.errors);
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
validate1925.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
return false;
}
}
validate1925.errors = vErrors;
return errors === 0;
}
validate1925.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate1907(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1907.evaluated;
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
validate1907.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((((key0 === "definition") || (key0 === "connection")) || (key0 === "namespace")) || (key0 === "name")) || (key0 === "interpretation"))){
validate1907.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.definition !== undefined){
const _errs2 = errors;
if(!(validate1656(data.definition, {instancePath:instancePath+"/definition",parentData:data,parentDataProperty:"definition",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1656.errors : vErrors.concat(validate1656.errors);
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
if(!(validate1909(data.connection, {instancePath:instancePath+"/connection",parentData:data,parentDataProperty:"connection",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1909.errors : vErrors.concat(validate1909.errors);
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
if(!(validate1911(data.namespace, {instancePath:instancePath+"/namespace",parentData:data,parentDataProperty:"namespace",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1911.errors : vErrors.concat(validate1911.errors);
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
if(!(validate1726(data.name, {instancePath:instancePath+"/name",parentData:data,parentDataProperty:"name",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1726.errors : vErrors.concat(validate1726.errors);
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
if(!(validate1925(data.interpretation, {instancePath:instancePath+"/interpretation",parentData:data,parentDataProperty:"interpretation",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1925.errors : vErrors.concat(validate1925.errors);
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
validate1907.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
return false;
}
}
validate1907.errors = vErrors;
return errors === 0;
}
validate1907.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema532 = {"type":"object","additionalProperties":false,"properties":{"position":{"$ref":"#/$defs/RelationalResponse/$defs/T83"},"changed_lsn":{"$ref":"#/$defs/RelationalResponse/$defs/T24"},"live_rows":{"$ref":"#/$defs/RelationalResponse/$defs/T24"},"pending_rows":{"$ref":"#/$defs/RelationalResponse/$defs/T24"},"pending_bytes":{"$ref":"#/$defs/RelationalResponse/$defs/T24"},"pending_complete":{"$ref":"#/$defs/RelationalResponse/$defs/T5"},"oldest_pending_lsn":{"$ref":"#/$defs/RelationalResponse/$defs/T84"},"archive_through":{"$ref":"#/$defs/RelationalResponse/$defs/T24"},"recovery_through":{"$ref":"#/$defs/RelationalResponse/$defs/T84"},"history_floor":{"$ref":"#/$defs/RelationalResponse/$defs/T24"},"next_segment":{"$ref":"#/$defs/RelationalResponse/$defs/T24"},"archive_source_lsn":{"$ref":"#/$defs/RelationalResponse/$defs/T24"},"archived_source_lsn":{"$ref":"#/$defs/RelationalResponse/$defs/T24"},"archive_target_source_lsn":{"$ref":"#/$defs/RelationalResponse/$defs/T84"},"archive_target_through_lsn":{"$ref":"#/$defs/RelationalResponse/$defs/T84"},"compaction_source_lsn":{"$ref":"#/$defs/RelationalResponse/$defs/T24"},"compacted_source_lsn":{"$ref":"#/$defs/RelationalResponse/$defs/T24"},"compaction_target_source_lsn":{"$ref":"#/$defs/RelationalResponse/$defs/T84"},"compaction_target_before_segment":{"$ref":"#/$defs/RelationalResponse/$defs/T84"},"compaction_target_after_segment":{"$ref":"#/$defs/RelationalResponse/$defs/T84"}},"required":["position","changed_lsn","live_rows","pending_rows","pending_bytes","pending_complete","oldest_pending_lsn","archive_through","recovery_through","history_floor","next_segment","archive_source_lsn","archived_source_lsn","archive_target_source_lsn","archive_target_through_lsn","compaction_source_lsn","compacted_source_lsn","compaction_target_source_lsn","compaction_target_before_segment","compaction_target_after_segment"]};
const schema533 = {"type":"object","additionalProperties":false,"properties":{"partition":{"$ref":"#/$defs/RelationalResponse/$defs/T24"},"next_lsn":{"$ref":"#/$defs/RelationalResponse/$defs/T24"}},"required":["partition","next_lsn"]};

function validate1944(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1944.evaluated;
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
validate1944.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "partition") || (key0 === "next_lsn"))){
validate1944.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.partition !== undefined){
const _errs2 = errors;
if(!(validate1726(data.partition, {instancePath:instancePath+"/partition",parentData:data,parentDataProperty:"partition",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1726.errors : vErrors.concat(validate1726.errors);
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
if(!(validate1726(data.next_lsn, {instancePath:instancePath+"/next_lsn",parentData:data,parentDataProperty:"next_lsn",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1726.errors : vErrors.concat(validate1726.errors);
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
validate1944.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
return false;
}
}
validate1944.errors = vErrors;
return errors === 0;
}
validate1944.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema534 = {"anyOf":[{"$ref":"#/$defs/RelationalResponse/$defs/T24"},{"type":"null"}]};

function validate1953(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1953.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate1726(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1726.errors : vErrors.concat(validate1726.errors);
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
validate1953.errors = vErrors;
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
validate1953.errors = vErrors;
return errors === 0;
}
validate1953.evaluated = {"dynamicProps":false,"dynamicItems":false};


function validate1943(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1943.evaluated;
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
validate1943.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(func1.call(schema532.properties, key0))){
validate1943.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.position !== undefined){
const _errs2 = errors;
if(!(validate1944(data.position, {instancePath:instancePath+"/position",parentData:data,parentDataProperty:"position",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1944.errors : vErrors.concat(validate1944.errors);
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
if(!(validate1726(data.changed_lsn, {instancePath:instancePath+"/changed_lsn",parentData:data,parentDataProperty:"changed_lsn",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1726.errors : vErrors.concat(validate1726.errors);
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
if(!(validate1726(data.live_rows, {instancePath:instancePath+"/live_rows",parentData:data,parentDataProperty:"live_rows",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1726.errors : vErrors.concat(validate1726.errors);
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
if(!(validate1726(data.pending_rows, {instancePath:instancePath+"/pending_rows",parentData:data,parentDataProperty:"pending_rows",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1726.errors : vErrors.concat(validate1726.errors);
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
if(!(validate1726(data.pending_bytes, {instancePath:instancePath+"/pending_bytes",parentData:data,parentDataProperty:"pending_bytes",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1726.errors : vErrors.concat(validate1726.errors);
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
if(!(validate1662(data.pending_complete, {instancePath:instancePath+"/pending_complete",parentData:data,parentDataProperty:"pending_complete",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1662.errors : vErrors.concat(validate1662.errors);
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
if(!(validate1953(data.oldest_pending_lsn, {instancePath:instancePath+"/oldest_pending_lsn",parentData:data,parentDataProperty:"oldest_pending_lsn",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1953.errors : vErrors.concat(validate1953.errors);
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
if(!(validate1726(data.archive_through, {instancePath:instancePath+"/archive_through",parentData:data,parentDataProperty:"archive_through",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1726.errors : vErrors.concat(validate1726.errors);
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
if(!(validate1953(data.recovery_through, {instancePath:instancePath+"/recovery_through",parentData:data,parentDataProperty:"recovery_through",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1953.errors : vErrors.concat(validate1953.errors);
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
if(!(validate1726(data.history_floor, {instancePath:instancePath+"/history_floor",parentData:data,parentDataProperty:"history_floor",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1726.errors : vErrors.concat(validate1726.errors);
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
if(!(validate1726(data.next_segment, {instancePath:instancePath+"/next_segment",parentData:data,parentDataProperty:"next_segment",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1726.errors : vErrors.concat(validate1726.errors);
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
if(!(validate1726(data.archive_source_lsn, {instancePath:instancePath+"/archive_source_lsn",parentData:data,parentDataProperty:"archive_source_lsn",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1726.errors : vErrors.concat(validate1726.errors);
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
if(!(validate1726(data.archived_source_lsn, {instancePath:instancePath+"/archived_source_lsn",parentData:data,parentDataProperty:"archived_source_lsn",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1726.errors : vErrors.concat(validate1726.errors);
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
if(!(validate1953(data.archive_target_source_lsn, {instancePath:instancePath+"/archive_target_source_lsn",parentData:data,parentDataProperty:"archive_target_source_lsn",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1953.errors : vErrors.concat(validate1953.errors);
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
if(!(validate1953(data.archive_target_through_lsn, {instancePath:instancePath+"/archive_target_through_lsn",parentData:data,parentDataProperty:"archive_target_through_lsn",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1953.errors : vErrors.concat(validate1953.errors);
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
if(!(validate1726(data.compaction_source_lsn, {instancePath:instancePath+"/compaction_source_lsn",parentData:data,parentDataProperty:"compaction_source_lsn",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1726.errors : vErrors.concat(validate1726.errors);
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
if(!(validate1726(data.compacted_source_lsn, {instancePath:instancePath+"/compacted_source_lsn",parentData:data,parentDataProperty:"compacted_source_lsn",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1726.errors : vErrors.concat(validate1726.errors);
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
if(!(validate1953(data.compaction_target_source_lsn, {instancePath:instancePath+"/compaction_target_source_lsn",parentData:data,parentDataProperty:"compaction_target_source_lsn",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1953.errors : vErrors.concat(validate1953.errors);
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
if(!(validate1953(data.compaction_target_before_segment, {instancePath:instancePath+"/compaction_target_before_segment",parentData:data,parentDataProperty:"compaction_target_before_segment",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1953.errors : vErrors.concat(validate1953.errors);
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
if(!(validate1953(data.compaction_target_after_segment, {instancePath:instancePath+"/compaction_target_after_segment",parentData:data,parentDataProperty:"compaction_target_after_segment",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1953.errors : vErrors.concat(validate1953.errors);
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
validate1943.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
return false;
}
}
validate1943.errors = vErrors;
return errors === 0;
}
validate1943.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate1906(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1906.evaluated;
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
validate1906.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "binding") || (key0 === "observed"))){
validate1906.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.binding !== undefined){
const _errs2 = errors;
if(!(validate1907(data.binding, {instancePath:instancePath+"/binding",parentData:data,parentDataProperty:"binding",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1907.errors : vErrors.concat(validate1907.errors);
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
if(!(validate1943(data.observed, {instancePath:instancePath+"/observed",parentData:data,parentDataProperty:"observed",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1943.errors : vErrors.concat(validate1943.errors);
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
validate1906.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
return false;
}
}
validate1906.errors = vErrors;
return errors === 0;
}
validate1906.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema535 = {"oneOf":[{"type":"object","additionalProperties":false,"required":["capabilities"],"properties":{"capabilities":{"$ref":"#/$defs/RelationalResponse/$defs/T2"}}},{"type":"object","additionalProperties":false,"required":["explained"],"properties":{"explained":{"$ref":"#/$defs/RelationalResponse/$defs/T25"}}},{"type":"object","additionalProperties":false,"required":["opened"],"properties":{"opened":{"$ref":"#/$defs/RelationalResponse/$defs/T22"}}},{"type":"object","additionalProperties":false,"required":["page"],"properties":{"page":{"$ref":"#/$defs/RelationalResponse/$defs/T86"}}},{"type":"object","additionalProperties":false,"required":["closed"],"properties":{"closed":{"$ref":"#/$defs/RelationalResponse/$defs/T39"}}}]};
const schema536 = {"type":"object","additionalProperties":false,"properties":{"reference":{"$ref":"#/$defs/RelationalResponse/$defs/T23"},"ordinal":{"$ref":"#/$defs/RelationalResponse/$defs/T24"},"row":{"$ref":"#/$defs/RelationalResponse/$defs/T87"},"complete_coverage":{"$ref":"#/$defs/RelationalResponse/$defs/T5"}},"required":["reference","ordinal","row","complete_coverage"]};
const schema537 = {"anyOf":[{"$ref":"#/$defs/RelationalResponse/$defs/T88"},{"type":"null"}]};
const schema538 = {"type":"object","additionalProperties":false,"properties":{"identity":{"$ref":"#/$defs/RelationalResponse/$defs/T89"},"cells":{"$ref":"#/$defs/RelationalResponse/$defs/T94"}},"required":["identity","cells"]};
const schema539 = {"oneOf":[{"type":"object","additionalProperties":false,"required":["pair"],"properties":{"pair":{"$ref":"#/$defs/RelationalResponse/$defs/T90"}}},{"type":"object","additionalProperties":false,"required":["group"],"properties":{"group":{"$ref":"#/$defs/RelationalResponse/$defs/T91"}}}]};
const schema540 = {"type":"object","additionalProperties":false,"properties":{"left":{"$ref":"#/$defs/RelationalResponse/$defs/T24"},"right":{"$ref":"#/$defs/RelationalResponse/$defs/T84"}},"required":["left","right"]};

function validate1981(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1981.evaluated;
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
validate1981.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "left") || (key0 === "right"))){
validate1981.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.left !== undefined){
const _errs2 = errors;
if(!(validate1726(data.left, {instancePath:instancePath+"/left",parentData:data,parentDataProperty:"left",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1726.errors : vErrors.concat(validate1726.errors);
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
if(!(validate1953(data.right, {instancePath:instancePath+"/right",parentData:data,parentDataProperty:"right",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1953.errors : vErrors.concat(validate1953.errors);
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
validate1981.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
return false;
}
}
validate1981.errors = vErrors;
return errors === 0;
}
validate1981.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema541 = {"type":"array","maxItems":128,"items":{"$ref":"#/$defs/RelationalResponse/$defs/T92"}};
const schema542 = {"anyOf":[{"$ref":"#/$defs/RelationalResponse/$defs/T93"},{"type":"null"}]};
const schema543 = {"oneOf":[{"type":"object","additionalProperties":false,"required":["signed"],"properties":{"signed":{"$ref":"#/$defs/RelationalResponse/$defs/T24"}}},{"type":"object","additionalProperties":false,"required":["utf8"],"properties":{"utf8":{"$ref":"#/$defs/RelationalResponse/$defs/T24"}}}]};

function validate1987(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1987.evaluated;
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
if(!(validate1726(data.signed, {instancePath:instancePath+"/signed",parentData:data,parentDataProperty:"signed",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1726.errors : vErrors.concat(validate1726.errors);
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
if(!(validate1726(data.utf8, {instancePath:instancePath+"/utf8",parentData:data,parentDataProperty:"utf8",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1726.errors : vErrors.concat(validate1726.errors);
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
validate1987.errors = vErrors;
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
validate1987.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate1987.evaluated = {"dynamicProps":true,"dynamicItems":false};


function validate1986(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1986.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate1987(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1987.errors : vErrors.concat(validate1987.errors);
errors = vErrors.length;
}
else {
var props0 = validate1987.evaluated.props;
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
validate1986.errors = vErrors;
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
validate1986.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate1986.evaluated = {"dynamicProps":true,"dynamicItems":false};


function validate1985(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1985.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(Array.isArray(data)){
if(data.length > 128){
validate1985.errors = [{instancePath,schemaPath:"#/maxItems",keyword:"maxItems",params:{limit: 128}}];
return false;
}
else {
var valid0 = true;
const len0 = data.length;
for(let i0=0; i0<len0; i0++){
const _errs1 = errors;
if(!(validate1986(data[i0], {instancePath:instancePath+"/" + i0,parentData:data,parentDataProperty:i0,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1986.errors : vErrors.concat(validate1986.errors);
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
validate1985.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "array"}}];
return false;
}
}
validate1985.errors = vErrors;
return errors === 0;
}
validate1985.evaluated = {"items":true,"dynamicProps":false,"dynamicItems":false};


function validate1980(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1980.evaluated;
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
if(!(validate1981(data.pair, {instancePath:instancePath+"/pair",parentData:data,parentDataProperty:"pair",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1981.errors : vErrors.concat(validate1981.errors);
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
if(!(validate1985(data.group, {instancePath:instancePath+"/group",parentData:data,parentDataProperty:"group",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1985.errors : vErrors.concat(validate1985.errors);
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
validate1980.errors = vErrors;
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
validate1980.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate1980.evaluated = {"dynamicProps":true,"dynamicItems":false};

const schema544 = {"type":"array","maxItems":128,"items":{"$ref":"#/$defs/RelationalResponse/$defs/T95"}};
const schema545 = {"oneOf":[{"type":"object","additionalProperties":false,"required":["missing"],"properties":{"missing":{"$ref":"#/$defs/RelationalResponse/$defs/T39"}}},{"type":"object","additionalProperties":false,"required":["null"],"properties":{"null":{"$ref":"#/$defs/RelationalResponse/$defs/T39"}}},{"type":"object","additionalProperties":false,"required":["type_error"],"properties":{"type_error":{"$ref":"#/$defs/RelationalResponse/$defs/T96"}}},{"type":"object","additionalProperties":false,"required":["value"],"properties":{"value":{"$ref":"#/$defs/RelationalResponse/$defs/T97"}}},{"type":"object","additionalProperties":false,"required":["conflict"],"properties":{"conflict":{"$ref":"#/$defs/RelationalResponse/$defs/T118"}}}]};
const schema380 = {"type":"string","enum":["unknown","int64","uint64","float64","boolean","utf8","binary","int8","int16","int32","int128","uint8","uint16","uint32","uint128","float32","decimal","date","time","timestamp","interval","uuid","structure","list","array","map","tagged_union","json","range","multirange","vector","null_value","text","character"]};

function validate1998(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1998.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate1998.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"}}];
return false;
}
if(!((((((((((((((((((((((((((((((((((data === "unknown") || (data === "int64")) || (data === "uint64")) || (data === "float64")) || (data === "boolean")) || (data === "utf8")) || (data === "binary")) || (data === "int8")) || (data === "int16")) || (data === "int32")) || (data === "int128")) || (data === "uint8")) || (data === "uint16")) || (data === "uint32")) || (data === "uint128")) || (data === "float32")) || (data === "decimal")) || (data === "date")) || (data === "time")) || (data === "timestamp")) || (data === "interval")) || (data === "uuid")) || (data === "structure")) || (data === "list")) || (data === "array")) || (data === "map")) || (data === "tagged_union")) || (data === "json")) || (data === "range")) || (data === "multirange")) || (data === "vector")) || (data === "null_value")) || (data === "text")) || (data === "character"))){
validate1998.errors = [{instancePath,schemaPath:"#/enum",keyword:"enum",params:{allowedValues: schema380.enum}}];
return false;
}
validate1998.errors = vErrors;
return errors === 0;
}
validate1998.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema547 = {"oneOf":[{"type":"object","additionalProperties":false,"required":["atom"],"properties":{"atom":{"$ref":"#/$defs/RelationalResponse/$defs/T98"}}},{"type":"object","additionalProperties":false,"required":["structure"],"properties":{"structure":{"$ref":"#/$defs/RelationalResponse/$defs/T100"}}},{"type":"object","additionalProperties":false,"required":["list"],"properties":{"list":{"$ref":"#/$defs/RelationalResponse/$defs/T100"}}},{"type":"object","additionalProperties":false,"required":["array"],"properties":{"array":{"$ref":"#/$defs/RelationalResponse/$defs/T100"}}},{"type":"object","additionalProperties":false,"required":["map"],"properties":{"map":{"$ref":"#/$defs/RelationalResponse/$defs/T109"}}},{"type":"object","additionalProperties":false,"required":["tagged_union"],"properties":{"tagged_union":{"$ref":"#/$defs/RelationalResponse/$defs/T121"}}},{"type":"object","additionalProperties":false,"required":["json"],"properties":{"json":{"$ref":"#/$defs/RelationalResponse/$defs/T24"}}},{"type":"object","additionalProperties":false,"required":["range"],"properties":{"range":{"$ref":"#/$defs/RelationalResponse/$defs/T123"}}},{"type":"object","additionalProperties":false,"required":["multirange"],"properties":{"multirange":{"$ref":"#/$defs/RelationalResponse/$defs/T117"}}},{"type":"object","additionalProperties":false,"required":["vector"],"properties":{"vector":{"$ref":"#/$defs/RelationalResponse/$defs/T24"}}}]};
const schema548 = {"oneOf":[{"type":"object","additionalProperties":false,"required":["signed"],"properties":{"signed":{"$ref":"#/$defs/RelationalResponse/$defs/T24"}}},{"type":"object","additionalProperties":false,"required":["unsigned"],"properties":{"unsigned":{"$ref":"#/$defs/RelationalResponse/$defs/T24"}}},{"type":"object","additionalProperties":false,"required":["decimal"],"properties":{"decimal":{"$ref":"#/$defs/RelationalResponse/$defs/T24"}}},{"type":"object","additionalProperties":false,"required":["float_bits"],"properties":{"float_bits":{"$ref":"#/$defs/RelationalResponse/$defs/T24"}}},{"type":"object","additionalProperties":false,"required":["boolean"],"properties":{"boolean":{"$ref":"#/$defs/RelationalResponse/$defs/T5"}}},{"type":"object","additionalProperties":false,"required":["utf8"],"properties":{"utf8":{"$ref":"#/$defs/RelationalResponse/$defs/T24"}}},{"type":"object","additionalProperties":false,"required":["binary"],"properties":{"binary":{"$ref":"#/$defs/RelationalResponse/$defs/T24"}}},{"type":"object","additionalProperties":false,"required":["date_days"],"properties":{"date_days":{"$ref":"#/$defs/RelationalResponse/$defs/T24"}}},{"type":"object","additionalProperties":false,"required":["time_nanos"],"properties":{"time_nanos":{"$ref":"#/$defs/RelationalResponse/$defs/T24"}}},{"type":"object","additionalProperties":false,"required":["timestamp_micros"],"properties":{"timestamp_micros":{"$ref":"#/$defs/RelationalResponse/$defs/T24"}}},{"type":"object","additionalProperties":false,"required":["interval"],"properties":{"interval":{"$ref":"#/$defs/RelationalResponse/$defs/T99"}}},{"type":"object","additionalProperties":false,"required":["uuid"],"properties":{"uuid":{"$ref":"#/$defs/RelationalResponse/$defs/T24"}}}]};
const schema549 = {"type":"object","additionalProperties":false,"properties":{"months":{"$ref":"#/$defs/RelationalResponse/$defs/T24"},"days":{"$ref":"#/$defs/RelationalResponse/$defs/T24"},"nanos":{"$ref":"#/$defs/RelationalResponse/$defs/T24"}},"required":["months","days","nanos"]};

function validate2012(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2012.evaluated;
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
validate2012.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "months") || (key0 === "days")) || (key0 === "nanos"))){
validate2012.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.months !== undefined){
const _errs2 = errors;
if(!(validate1726(data.months, {instancePath:instancePath+"/months",parentData:data,parentDataProperty:"months",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1726.errors : vErrors.concat(validate1726.errors);
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
if(!(validate1726(data.days, {instancePath:instancePath+"/days",parentData:data,parentDataProperty:"days",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1726.errors : vErrors.concat(validate1726.errors);
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
if(!(validate1726(data.nanos, {instancePath:instancePath+"/nanos",parentData:data,parentDataProperty:"nanos",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1726.errors : vErrors.concat(validate1726.errors);
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
validate2012.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
return false;
}
}
validate2012.errors = vErrors;
return errors === 0;
}
validate2012.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate2001(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2001.evaluated;
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
if(!(validate1726(data.signed, {instancePath:instancePath+"/signed",parentData:data,parentDataProperty:"signed",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1726.errors : vErrors.concat(validate1726.errors);
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
if(!(validate1726(data.unsigned, {instancePath:instancePath+"/unsigned",parentData:data,parentDataProperty:"unsigned",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1726.errors : vErrors.concat(validate1726.errors);
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
if(!(validate1726(data.decimal, {instancePath:instancePath+"/decimal",parentData:data,parentDataProperty:"decimal",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1726.errors : vErrors.concat(validate1726.errors);
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
if(!(validate1726(data.float_bits, {instancePath:instancePath+"/float_bits",parentData:data,parentDataProperty:"float_bits",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1726.errors : vErrors.concat(validate1726.errors);
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
if(!(validate1662(data.boolean, {instancePath:instancePath+"/boolean",parentData:data,parentDataProperty:"boolean",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1662.errors : vErrors.concat(validate1662.errors);
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
if(!(validate1726(data.utf8, {instancePath:instancePath+"/utf8",parentData:data,parentDataProperty:"utf8",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1726.errors : vErrors.concat(validate1726.errors);
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
if(!(validate1726(data.binary, {instancePath:instancePath+"/binary",parentData:data,parentDataProperty:"binary",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1726.errors : vErrors.concat(validate1726.errors);
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
if(!(validate1726(data.date_days, {instancePath:instancePath+"/date_days",parentData:data,parentDataProperty:"date_days",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1726.errors : vErrors.concat(validate1726.errors);
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
if(!(validate1726(data.time_nanos, {instancePath:instancePath+"/time_nanos",parentData:data,parentDataProperty:"time_nanos",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1726.errors : vErrors.concat(validate1726.errors);
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
if(!(validate1726(data.timestamp_micros, {instancePath:instancePath+"/timestamp_micros",parentData:data,parentDataProperty:"timestamp_micros",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1726.errors : vErrors.concat(validate1726.errors);
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
if(!(validate2012(data.interval, {instancePath:instancePath+"/interval",parentData:data,parentDataProperty:"interval",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2012.errors : vErrors.concat(validate2012.errors);
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
if(!(validate1726(data.uuid, {instancePath:instancePath+"/uuid",parentData:data,parentDataProperty:"uuid",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1726.errors : vErrors.concat(validate1726.errors);
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
validate2001.errors = vErrors;
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
validate2001.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate2001.evaluated = {"dynamicProps":true,"dynamicItems":false};

const schema550 = {"type":"array","maxItems":65536,"items":{"$ref":"#/$defs/RelationalResponse/$defs/T101"}};
const schema551 = {"oneOf":[{"type":"object","additionalProperties":false,"required":["missing"],"properties":{"missing":{"$ref":"#/$defs/RelationalResponse/$defs/T102"}}},{"type":"object","additionalProperties":false,"required":["null"],"properties":{"null":{"$ref":"#/$defs/RelationalResponse/$defs/T102"}}},{"type":"object","additionalProperties":false,"required":["type_error"],"properties":{"type_error":{"$ref":"#/$defs/RelationalResponse/$defs/T103"}}},{"type":"object","additionalProperties":false,"required":["value"],"properties":{"value":{"$ref":"#/$defs/RelationalResponse/$defs/T104"}}},{"type":"object","additionalProperties":false,"required":["conflict"],"properties":{"conflict":{"$ref":"#/$defs/RelationalResponse/$defs/T118"}}}]};
const schema552 = {"type":"object","maxProperties":0};

function validate2021(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2021.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
if(Object.keys(data).length > 0){
validate2021.errors = [{instancePath,schemaPath:"#/maxProperties",keyword:"maxProperties",params:{limit: 0}}];
return false;
}
}
else {
validate2021.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
return false;
}
}
validate2021.errors = vErrors;
return errors === 0;
}
validate2021.evaluated = {"dynamicProps":false,"dynamicItems":false};


function validate2024(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2024.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate2024.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"}}];
return false;
}
if(!((((((((((((((((((((((((((((((((((data === "unknown") || (data === "int64")) || (data === "uint64")) || (data === "float64")) || (data === "boolean")) || (data === "utf8")) || (data === "binary")) || (data === "int8")) || (data === "int16")) || (data === "int32")) || (data === "int128")) || (data === "uint8")) || (data === "uint16")) || (data === "uint32")) || (data === "uint128")) || (data === "float32")) || (data === "decimal")) || (data === "date")) || (data === "time")) || (data === "timestamp")) || (data === "interval")) || (data === "uuid")) || (data === "structure")) || (data === "list")) || (data === "array")) || (data === "map")) || (data === "tagged_union")) || (data === "json")) || (data === "range")) || (data === "multirange")) || (data === "vector")) || (data === "null_value")) || (data === "text")) || (data === "character"))){
validate2024.errors = [{instancePath,schemaPath:"#/enum",keyword:"enum",params:{allowedValues: schema380.enum}}];
return false;
}
validate2024.errors = vErrors;
return errors === 0;
}
validate2024.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema554 = {"oneOf":[{"type":"object","additionalProperties":false,"required":["atom"],"properties":{"atom":{"$ref":"#/$defs/RelationalResponse/$defs/T105"}}},{"type":"object","additionalProperties":false,"required":["structure"],"properties":{"structure":{"$ref":"#/$defs/RelationalResponse/$defs/T100"}}},{"type":"object","additionalProperties":false,"required":["list"],"properties":{"list":{"$ref":"#/$defs/RelationalResponse/$defs/T100"}}},{"type":"object","additionalProperties":false,"required":["array"],"properties":{"array":{"$ref":"#/$defs/RelationalResponse/$defs/T100"}}},{"type":"object","additionalProperties":false,"required":["map"],"properties":{"map":{"$ref":"#/$defs/RelationalResponse/$defs/T109"}}},{"type":"object","additionalProperties":false,"required":["tagged_union"],"properties":{"tagged_union":{"$ref":"#/$defs/RelationalResponse/$defs/T111"}}},{"type":"object","additionalProperties":false,"required":["json"],"properties":{"json":{"$ref":"#/$defs/RelationalResponse/$defs/T106"}}},{"type":"object","additionalProperties":false,"required":["range"],"properties":{"range":{"$ref":"#/$defs/RelationalResponse/$defs/T114"}}},{"type":"object","additionalProperties":false,"required":["multirange"],"properties":{"multirange":{"$ref":"#/$defs/RelationalResponse/$defs/T117"}}},{"type":"object","additionalProperties":false,"required":["vector"],"properties":{"vector":{"$ref":"#/$defs/RelationalResponse/$defs/T106"}}}]};
const schema555 = {"oneOf":[{"type":"object","additionalProperties":false,"required":["signed"],"properties":{"signed":{"$ref":"#/$defs/RelationalResponse/$defs/T106"}}},{"type":"object","additionalProperties":false,"required":["unsigned"],"properties":{"unsigned":{"$ref":"#/$defs/RelationalResponse/$defs/T106"}}},{"type":"object","additionalProperties":false,"required":["decimal"],"properties":{"decimal":{"$ref":"#/$defs/RelationalResponse/$defs/T106"}}},{"type":"object","additionalProperties":false,"required":["float_bits"],"properties":{"float_bits":{"$ref":"#/$defs/RelationalResponse/$defs/T106"}}},{"type":"object","additionalProperties":false,"required":["boolean"],"properties":{"boolean":{"$ref":"#/$defs/RelationalResponse/$defs/T107"}}},{"type":"object","additionalProperties":false,"required":["utf8"],"properties":{"utf8":{"$ref":"#/$defs/RelationalResponse/$defs/T106"}}},{"type":"object","additionalProperties":false,"required":["binary"],"properties":{"binary":{"$ref":"#/$defs/RelationalResponse/$defs/T106"}}},{"type":"object","additionalProperties":false,"required":["date_days"],"properties":{"date_days":{"$ref":"#/$defs/RelationalResponse/$defs/T106"}}},{"type":"object","additionalProperties":false,"required":["time_nanos"],"properties":{"time_nanos":{"$ref":"#/$defs/RelationalResponse/$defs/T106"}}},{"type":"object","additionalProperties":false,"required":["timestamp_micros"],"properties":{"timestamp_micros":{"$ref":"#/$defs/RelationalResponse/$defs/T106"}}},{"type":"object","additionalProperties":false,"required":["interval"],"properties":{"interval":{"$ref":"#/$defs/RelationalResponse/$defs/T108"}}},{"type":"object","additionalProperties":false,"required":["uuid"],"properties":{"uuid":{"$ref":"#/$defs/RelationalResponse/$defs/T106"}}}]};
const schema556 = {"type":"string","maxLength":4096};

function validate2028(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2028.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(typeof data === "string"){
if(func4(data) > 4096){
validate2028.errors = [{instancePath,schemaPath:"#/maxLength",keyword:"maxLength",params:{limit: 4096}}];
return false;
}
}
else {
validate2028.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"}}];
return false;
}
}
validate2028.errors = vErrors;
return errors === 0;
}
validate2028.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema557 = {"type":"boolean"};

function validate2033(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2033.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "boolean"){
validate2033.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "boolean"}}];
return false;
}
validate2033.errors = vErrors;
return errors === 0;
}
validate2033.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema558 = {"type":"object","additionalProperties":false,"properties":{"months":{"$ref":"#/$defs/RelationalResponse/$defs/T106"},"days":{"$ref":"#/$defs/RelationalResponse/$defs/T106"},"nanos":{"$ref":"#/$defs/RelationalResponse/$defs/T106"}},"required":["months","days","nanos"]};

function validate2040(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2040.evaluated;
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
validate2040.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "months") || (key0 === "days")) || (key0 === "nanos"))){
validate2040.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.months !== undefined){
const _errs2 = errors;
if(!(validate2028(data.months, {instancePath:instancePath+"/months",parentData:data,parentDataProperty:"months",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2028.errors : vErrors.concat(validate2028.errors);
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
if(!(validate2028(data.days, {instancePath:instancePath+"/days",parentData:data,parentDataProperty:"days",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2028.errors : vErrors.concat(validate2028.errors);
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
if(!(validate2028(data.nanos, {instancePath:instancePath+"/nanos",parentData:data,parentDataProperty:"nanos",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2028.errors : vErrors.concat(validate2028.errors);
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
validate2040.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
return false;
}
}
validate2040.errors = vErrors;
return errors === 0;
}
validate2040.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate2027(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2027.evaluated;
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
if(!(validate2028(data.signed, {instancePath:instancePath+"/signed",parentData:data,parentDataProperty:"signed",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2028.errors : vErrors.concat(validate2028.errors);
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
if(!(validate2028(data.unsigned, {instancePath:instancePath+"/unsigned",parentData:data,parentDataProperty:"unsigned",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2028.errors : vErrors.concat(validate2028.errors);
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
if(!(validate2028(data.decimal, {instancePath:instancePath+"/decimal",parentData:data,parentDataProperty:"decimal",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2028.errors : vErrors.concat(validate2028.errors);
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
if(!(validate2028(data.float_bits, {instancePath:instancePath+"/float_bits",parentData:data,parentDataProperty:"float_bits",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2028.errors : vErrors.concat(validate2028.errors);
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
if(!(validate2033(data.boolean, {instancePath:instancePath+"/boolean",parentData:data,parentDataProperty:"boolean",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2033.errors : vErrors.concat(validate2033.errors);
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
if(!(validate2028(data.utf8, {instancePath:instancePath+"/utf8",parentData:data,parentDataProperty:"utf8",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2028.errors : vErrors.concat(validate2028.errors);
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
if(!(validate2028(data.binary, {instancePath:instancePath+"/binary",parentData:data,parentDataProperty:"binary",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2028.errors : vErrors.concat(validate2028.errors);
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
if(!(validate2028(data.date_days, {instancePath:instancePath+"/date_days",parentData:data,parentDataProperty:"date_days",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2028.errors : vErrors.concat(validate2028.errors);
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
if(!(validate2028(data.time_nanos, {instancePath:instancePath+"/time_nanos",parentData:data,parentDataProperty:"time_nanos",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2028.errors : vErrors.concat(validate2028.errors);
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
if(!(validate2028(data.timestamp_micros, {instancePath:instancePath+"/timestamp_micros",parentData:data,parentDataProperty:"timestamp_micros",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2028.errors : vErrors.concat(validate2028.errors);
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
if(!(validate2040(data.interval, {instancePath:instancePath+"/interval",parentData:data,parentDataProperty:"interval",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2040.errors : vErrors.concat(validate2040.errors);
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
if(!(validate2028(data.uuid, {instancePath:instancePath+"/uuid",parentData:data,parentDataProperty:"uuid",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2028.errors : vErrors.concat(validate2028.errors);
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
validate2027.errors = vErrors;
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
validate2027.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate2027.evaluated = {"dynamicProps":true,"dynamicItems":false};

const schema559 = {"type":"array","maxItems":65536,"items":{"$ref":"#/$defs/RelationalResponse/$defs/T110"}};
const schema560 = {"type":"object","additionalProperties":false,"properties":{"key":{"$ref":"#/$defs/RelationalResponse/$defs/T105"},"value":{"$ref":"#/$defs/RelationalResponse/$defs/T101"}},"required":["key","value"]};
const wrapper33 = {validate: validate2020};

function validate2048(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2048.evaluated;
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
validate2048.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "key") || (key0 === "value"))){
validate2048.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.key !== undefined){
const _errs2 = errors;
if(!(validate2027(data.key, {instancePath:instancePath+"/key",parentData:data,parentDataProperty:"key",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2027.errors : vErrors.concat(validate2027.errors);
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
if(!(wrapper33.validate(data.value, {instancePath:instancePath+"/value",parentData:data,parentDataProperty:"value",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? wrapper33.validate.errors : vErrors.concat(wrapper33.validate.errors);
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
validate2048.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
return false;
}
}
validate2048.errors = vErrors;
return errors === 0;
}
validate2048.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate2047(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2047.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(Array.isArray(data)){
if(data.length > 65536){
validate2047.errors = [{instancePath,schemaPath:"#/maxItems",keyword:"maxItems",params:{limit: 65536}}];
return false;
}
else {
var valid0 = true;
const len0 = data.length;
for(let i0=0; i0<len0; i0++){
const _errs1 = errors;
if(!(validate2048(data[i0], {instancePath:instancePath+"/" + i0,parentData:data,parentDataProperty:i0,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2048.errors : vErrors.concat(validate2048.errors);
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
validate2047.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "array"}}];
return false;
}
}
validate2047.errors = vErrors;
return errors === 0;
}
validate2047.evaluated = {"items":true,"dynamicProps":false,"dynamicItems":false};

const schema561 = {"type":"object","additionalProperties":false,"properties":{"index":{"$ref":"#/$defs/RelationalResponse/$defs/T112"},"value":{"$ref":"#/$defs/RelationalResponse/$defs/T113"}},"required":["index","value"]};

function validate2053(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2053.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(!(((typeof data == "number") && (!(data % 1) && !isNaN(data))) && (isFinite(data)))){
validate2053.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "integer"}}];
return false;
}
if(errors === 0){
if((typeof data == "number") && (isFinite(data))){
if(data > 255 || isNaN(data)){
validate2053.errors = [{instancePath,schemaPath:"#/maximum",keyword:"maximum",params:{comparison: "<=", limit: 255}}];
return false;
}
else {
if(data < 0 || isNaN(data)){
validate2053.errors = [{instancePath,schemaPath:"#/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0}}];
return false;
}
}
}
}
validate2053.errors = vErrors;
return errors === 0;
}
validate2053.evaluated = {"dynamicProps":false,"dynamicItems":false};


function validate2052(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2052.evaluated;
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
validate2052.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "index") || (key0 === "value"))){
validate2052.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.index !== undefined){
const _errs2 = errors;
if(!(validate2053(data.index, {instancePath:instancePath+"/index",parentData:data,parentDataProperty:"index",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2053.errors : vErrors.concat(validate2053.errors);
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
if(!(wrapper33.validate(data.value, {instancePath:instancePath+"/value",parentData:data,parentDataProperty:"value",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? wrapper33.validate.errors : vErrors.concat(wrapper33.validate.errors);
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
validate2052.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
return false;
}
}
validate2052.errors = vErrors;
return errors === 0;
}
validate2052.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema563 = {"type":"object","additionalProperties":false,"properties":{"is_empty":{"$ref":"#/$defs/RelationalResponse/$defs/T107"},"lower":{"$ref":"#/$defs/RelationalResponse/$defs/T115"},"upper":{"$ref":"#/$defs/RelationalResponse/$defs/T115"}},"required":["is_empty","lower","upper"]};
const schema564 = {"anyOf":[{"$ref":"#/$defs/RelationalResponse/$defs/T116"},{"type":"null"}]};
const schema565 = {"type":"object","additionalProperties":false,"properties":{"value":{"$ref":"#/$defs/RelationalResponse/$defs/T105"},"inclusive":{"$ref":"#/$defs/RelationalResponse/$defs/T107"}},"required":["value","inclusive"]};

function validate2060(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2060.evaluated;
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
validate2060.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "value") || (key0 === "inclusive"))){
validate2060.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.value !== undefined){
const _errs2 = errors;
if(!(validate2027(data.value, {instancePath:instancePath+"/value",parentData:data,parentDataProperty:"value",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2027.errors : vErrors.concat(validate2027.errors);
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
if(!(validate2033(data.inclusive, {instancePath:instancePath+"/inclusive",parentData:data,parentDataProperty:"inclusive",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2033.errors : vErrors.concat(validate2033.errors);
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
validate2060.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
return false;
}
}
validate2060.errors = vErrors;
return errors === 0;
}
validate2060.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate2059(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2059.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate2060(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2060.errors : vErrors.concat(validate2060.errors);
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
validate2059.errors = vErrors;
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
validate2059.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate2059.evaluated = {"dynamicProps":true,"dynamicItems":false};


function validate2057(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2057.evaluated;
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
validate2057.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "is_empty") || (key0 === "lower")) || (key0 === "upper"))){
validate2057.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.is_empty !== undefined){
const _errs2 = errors;
if(!(validate2033(data.is_empty, {instancePath:instancePath+"/is_empty",parentData:data,parentDataProperty:"is_empty",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2033.errors : vErrors.concat(validate2033.errors);
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
if(!(validate2059(data.lower, {instancePath:instancePath+"/lower",parentData:data,parentDataProperty:"lower",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2059.errors : vErrors.concat(validate2059.errors);
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
if(!(validate2059(data.upper, {instancePath:instancePath+"/upper",parentData:data,parentDataProperty:"upper",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2059.errors : vErrors.concat(validate2059.errors);
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
validate2057.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
return false;
}
}
validate2057.errors = vErrors;
return errors === 0;
}
validate2057.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema566 = {"type":"array","maxItems":65536,"items":{"$ref":"#/$defs/RelationalResponse/$defs/T114"}};

function validate2067(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2067.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(Array.isArray(data)){
if(data.length > 65536){
validate2067.errors = [{instancePath,schemaPath:"#/maxItems",keyword:"maxItems",params:{limit: 65536}}];
return false;
}
else {
var valid0 = true;
const len0 = data.length;
for(let i0=0; i0<len0; i0++){
const _errs1 = errors;
if(!(validate2057(data[i0], {instancePath:instancePath+"/" + i0,parentData:data,parentDataProperty:i0,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2057.errors : vErrors.concat(validate2057.errors);
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
validate2067.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "array"}}];
return false;
}
}
validate2067.errors = vErrors;
return errors === 0;
}
validate2067.evaluated = {"items":true,"dynamicProps":false,"dynamicItems":false};

const wrapper30 = {validate: validate2019};

function validate2026(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2026.evaluated;
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
if(!(validate2027(data.atom, {instancePath:instancePath+"/atom",parentData:data,parentDataProperty:"atom",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2027.errors : vErrors.concat(validate2027.errors);
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
if(!(wrapper30.validate(data.structure, {instancePath:instancePath+"/structure",parentData:data,parentDataProperty:"structure",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? wrapper30.validate.errors : vErrors.concat(wrapper30.validate.errors);
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
if(!(wrapper30.validate(data.list, {instancePath:instancePath+"/list",parentData:data,parentDataProperty:"list",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? wrapper30.validate.errors : vErrors.concat(wrapper30.validate.errors);
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
if(!(wrapper30.validate(data.array, {instancePath:instancePath+"/array",parentData:data,parentDataProperty:"array",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? wrapper30.validate.errors : vErrors.concat(wrapper30.validate.errors);
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
if(!(validate2047(data.map, {instancePath:instancePath+"/map",parentData:data,parentDataProperty:"map",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2047.errors : vErrors.concat(validate2047.errors);
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
if(!(validate2052(data.tagged_union, {instancePath:instancePath+"/tagged_union",parentData:data,parentDataProperty:"tagged_union",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2052.errors : vErrors.concat(validate2052.errors);
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
if(!(validate2028(data.json, {instancePath:instancePath+"/json",parentData:data,parentDataProperty:"json",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2028.errors : vErrors.concat(validate2028.errors);
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
const _errs29 = errors;
if(errors === _errs29){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing7;
if((data.range === undefined) && (missing7 = "range")){
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
if(!(key7 === "range")){
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
if(data.range !== undefined){
if(!(validate2057(data.range, {instancePath:instancePath+"/range",parentData:data,parentDataProperty:"range",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2057.errors : vErrors.concat(validate2057.errors);
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
if(props1 !== true){
props1 = true;
}
}
const _errs33 = errors;
if(errors === _errs33){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing8;
if((data.multirange === undefined) && (missing8 = "multirange")){
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
if(!(key8 === "multirange")){
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
if(data.multirange !== undefined){
if(!(validate2067(data.multirange, {instancePath:instancePath+"/multirange",parentData:data,parentDataProperty:"multirange",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2067.errors : vErrors.concat(validate2067.errors);
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
if(props1 !== true){
props1 = true;
}
}
const _errs37 = errors;
if(errors === _errs37){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing9;
if((data.vector === undefined) && (missing9 = "vector")){
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
if(!(key9 === "vector")){
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
if(data.vector !== undefined){
if(!(validate2028(data.vector, {instancePath:instancePath+"/vector",parentData:data,parentDataProperty:"vector",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2028.errors : vErrors.concat(validate2028.errors);
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
const err30 = {instancePath,schemaPath:"#/oneOf",keyword:"oneOf",params:{passingSchemas: passing0}};
if(vErrors === null){
vErrors = [err30];
}
else {
vErrors.push(err30);
}
errors++;
validate2026.errors = vErrors;
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
validate2026.errors = vErrors;
evaluated0.props = props1;
return errors === 0;
}
validate2026.evaluated = {"dynamicProps":true,"dynamicItems":false};

const schema567 = {"type":"array","maxItems":65536,"items":{"$ref":"#/$defs/RelationalResponse/$defs/T119"}};
const schema568 = {"type":"object","additionalProperties":false,"properties":{"counter":{"$ref":"#/$defs/RelationalResponse/$defs/T106"},"replica":{"$ref":"#/$defs/RelationalResponse/$defs/T106"},"value":{"$ref":"#/$defs/RelationalResponse/$defs/T120"}},"required":["counter","replica","value"]};
const schema569 = {"oneOf":[{"type":"object","additionalProperties":false,"required":["null"],"properties":{"null":{"$ref":"#/$defs/RelationalResponse/$defs/T102"}}},{"type":"object","additionalProperties":false,"required":["type_error"],"properties":{"type_error":{"$ref":"#/$defs/RelationalResponse/$defs/T103"}}},{"type":"object","additionalProperties":false,"required":["value"],"properties":{"value":{"$ref":"#/$defs/RelationalResponse/$defs/T104"}}}]};

function validate2076(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2076.evaluated;
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
if(!(validate2021(data.null, {instancePath:instancePath+"/null",parentData:data,parentDataProperty:"null",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2021.errors : vErrors.concat(validate2021.errors);
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
if(!(validate2024(data.type_error, {instancePath:instancePath+"/type_error",parentData:data,parentDataProperty:"type_error",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2024.errors : vErrors.concat(validate2024.errors);
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
if(!(validate2026(data.value, {instancePath:instancePath+"/value",parentData:data,parentDataProperty:"value",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2026.errors : vErrors.concat(validate2026.errors);
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
validate2076.errors = vErrors;
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
validate2076.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate2076.evaluated = {"dynamicProps":true,"dynamicItems":false};


function validate2073(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2073.evaluated;
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
validate2073.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "counter") || (key0 === "replica")) || (key0 === "value"))){
validate2073.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.counter !== undefined){
const _errs2 = errors;
if(!(validate2028(data.counter, {instancePath:instancePath+"/counter",parentData:data,parentDataProperty:"counter",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2028.errors : vErrors.concat(validate2028.errors);
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
if(!(validate2028(data.replica, {instancePath:instancePath+"/replica",parentData:data,parentDataProperty:"replica",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2028.errors : vErrors.concat(validate2028.errors);
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
if(!(validate2076(data.value, {instancePath:instancePath+"/value",parentData:data,parentDataProperty:"value",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2076.errors : vErrors.concat(validate2076.errors);
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
validate2073.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
return false;
}
}
validate2073.errors = vErrors;
return errors === 0;
}
validate2073.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate2072(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2072.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(Array.isArray(data)){
if(data.length > 65536){
validate2072.errors = [{instancePath,schemaPath:"#/maxItems",keyword:"maxItems",params:{limit: 65536}}];
return false;
}
else {
var valid0 = true;
const len0 = data.length;
for(let i0=0; i0<len0; i0++){
const _errs1 = errors;
if(!(validate2073(data[i0], {instancePath:instancePath+"/" + i0,parentData:data,parentDataProperty:i0,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2073.errors : vErrors.concat(validate2073.errors);
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
validate2072.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "array"}}];
return false;
}
}
validate2072.errors = vErrors;
return errors === 0;
}
validate2072.evaluated = {"items":true,"dynamicProps":false,"dynamicItems":false};


function validate2020(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2020.evaluated;
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
if(!(validate2021(data.missing, {instancePath:instancePath+"/missing",parentData:data,parentDataProperty:"missing",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2021.errors : vErrors.concat(validate2021.errors);
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
if(!(validate2021(data.null, {instancePath:instancePath+"/null",parentData:data,parentDataProperty:"null",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2021.errors : vErrors.concat(validate2021.errors);
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
if(!(validate2024(data.type_error, {instancePath:instancePath+"/type_error",parentData:data,parentDataProperty:"type_error",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2024.errors : vErrors.concat(validate2024.errors);
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
if(!(validate2026(data.value, {instancePath:instancePath+"/value",parentData:data,parentDataProperty:"value",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2026.errors : vErrors.concat(validate2026.errors);
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
if(!(validate2072(data.conflict, {instancePath:instancePath+"/conflict",parentData:data,parentDataProperty:"conflict",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2072.errors : vErrors.concat(validate2072.errors);
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
validate2020.errors = vErrors;
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
validate2020.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate2020.evaluated = {"dynamicProps":true,"dynamicItems":false};


function validate2019(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2019.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(Array.isArray(data)){
if(data.length > 65536){
validate2019.errors = [{instancePath,schemaPath:"#/maxItems",keyword:"maxItems",params:{limit: 65536}}];
return false;
}
else {
var valid0 = true;
const len0 = data.length;
for(let i0=0; i0<len0; i0++){
const _errs1 = errors;
if(!(validate2020(data[i0], {instancePath:instancePath+"/" + i0,parentData:data,parentDataProperty:i0,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2020.errors : vErrors.concat(validate2020.errors);
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
validate2019.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "array"}}];
return false;
}
}
validate2019.errors = vErrors;
return errors === 0;
}
validate2019.evaluated = {"items":true,"dynamicProps":false,"dynamicItems":false};

const schema570 = {"type":"object","additionalProperties":false,"properties":{"index":{"$ref":"#/$defs/RelationalResponse/$defs/T4"},"value":{"$ref":"#/$defs/RelationalResponse/$defs/T122"}},"required":["index","value"]};
const wrapper35 = {validate: validate1995};

function validate2088(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2088.evaluated;
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
validate2088.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "index") || (key0 === "value"))){
validate2088.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.index !== undefined){
const _errs2 = errors;
if(!(validate1658(data.index, {instancePath:instancePath+"/index",parentData:data,parentDataProperty:"index",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1658.errors : vErrors.concat(validate1658.errors);
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
if(!(wrapper35.validate(data.value, {instancePath:instancePath+"/value",parentData:data,parentDataProperty:"value",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? wrapper35.validate.errors : vErrors.concat(wrapper35.validate.errors);
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
validate2088.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
return false;
}
}
validate2088.errors = vErrors;
return errors === 0;
}
validate2088.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema571 = {"type":"object","additionalProperties":false,"properties":{"is_empty":{"$ref":"#/$defs/RelationalResponse/$defs/T5"},"lower":{"$ref":"#/$defs/RelationalResponse/$defs/T124"},"upper":{"$ref":"#/$defs/RelationalResponse/$defs/T124"}},"required":["is_empty","lower","upper"]};
const schema572 = {"anyOf":[{"$ref":"#/$defs/RelationalResponse/$defs/T125"},{"type":"null"}]};
const schema573 = {"type":"object","additionalProperties":false,"properties":{"value":{"$ref":"#/$defs/RelationalResponse/$defs/T98"},"inclusive":{"$ref":"#/$defs/RelationalResponse/$defs/T5"}},"required":["value","inclusive"]};

function validate2095(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2095.evaluated;
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
validate2095.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "value") || (key0 === "inclusive"))){
validate2095.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.value !== undefined){
const _errs2 = errors;
if(!(validate2001(data.value, {instancePath:instancePath+"/value",parentData:data,parentDataProperty:"value",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2001.errors : vErrors.concat(validate2001.errors);
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
if(!(validate1662(data.inclusive, {instancePath:instancePath+"/inclusive",parentData:data,parentDataProperty:"inclusive",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1662.errors : vErrors.concat(validate1662.errors);
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
validate2095.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
return false;
}
}
validate2095.errors = vErrors;
return errors === 0;
}
validate2095.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate2094(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2094.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate2095(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2095.errors : vErrors.concat(validate2095.errors);
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
validate2094.errors = vErrors;
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
validate2094.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate2094.evaluated = {"dynamicProps":true,"dynamicItems":false};


function validate2092(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2092.evaluated;
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
validate2092.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "is_empty") || (key0 === "lower")) || (key0 === "upper"))){
validate2092.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.is_empty !== undefined){
const _errs2 = errors;
if(!(validate1662(data.is_empty, {instancePath:instancePath+"/is_empty",parentData:data,parentDataProperty:"is_empty",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1662.errors : vErrors.concat(validate1662.errors);
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
if(!(validate2094(data.lower, {instancePath:instancePath+"/lower",parentData:data,parentDataProperty:"lower",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2094.errors : vErrors.concat(validate2094.errors);
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
if(!(validate2094(data.upper, {instancePath:instancePath+"/upper",parentData:data,parentDataProperty:"upper",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2094.errors : vErrors.concat(validate2094.errors);
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
validate2092.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
return false;
}
}
validate2092.errors = vErrors;
return errors === 0;
}
validate2092.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate2000(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate2000.evaluated;
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
if(!(validate2001(data.atom, {instancePath:instancePath+"/atom",parentData:data,parentDataProperty:"atom",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2001.errors : vErrors.concat(validate2001.errors);
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
if(!(validate2019(data.structure, {instancePath:instancePath+"/structure",parentData:data,parentDataProperty:"structure",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2019.errors : vErrors.concat(validate2019.errors);
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
if(!(validate2019(data.list, {instancePath:instancePath+"/list",parentData:data,parentDataProperty:"list",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2019.errors : vErrors.concat(validate2019.errors);
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
if(!(validate2019(data.array, {instancePath:instancePath+"/array",parentData:data,parentDataProperty:"array",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2019.errors : vErrors.concat(validate2019.errors);
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
if(!(validate2047(data.map, {instancePath:instancePath+"/map",parentData:data,parentDataProperty:"map",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2047.errors : vErrors.concat(validate2047.errors);
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
if(!(validate2088(data.tagged_union, {instancePath:instancePath+"/tagged_union",parentData:data,parentDataProperty:"tagged_union",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2088.errors : vErrors.concat(validate2088.errors);
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
if(!(validate1726(data.json, {instancePath:instancePath+"/json",parentData:data,parentDataProperty:"json",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1726.errors : vErrors.concat(validate1726.errors);
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
const _errs29 = errors;
if(errors === _errs29){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing7;
if((data.range === undefined) && (missing7 = "range")){
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
if(!(key7 === "range")){
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
if(data.range !== undefined){
if(!(validate2092(data.range, {instancePath:instancePath+"/range",parentData:data,parentDataProperty:"range",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2092.errors : vErrors.concat(validate2092.errors);
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
if(props1 !== true){
props1 = true;
}
}
const _errs33 = errors;
if(errors === _errs33){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing8;
if((data.multirange === undefined) && (missing8 = "multirange")){
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
if(!(key8 === "multirange")){
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
if(data.multirange !== undefined){
if(!(validate2067(data.multirange, {instancePath:instancePath+"/multirange",parentData:data,parentDataProperty:"multirange",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2067.errors : vErrors.concat(validate2067.errors);
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
if(props1 !== true){
props1 = true;
}
}
const _errs37 = errors;
if(errors === _errs37){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing9;
if((data.vector === undefined) && (missing9 = "vector")){
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
if(!(key9 === "vector")){
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
if(data.vector !== undefined){
if(!(validate1726(data.vector, {instancePath:instancePath+"/vector",parentData:data,parentDataProperty:"vector",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1726.errors : vErrors.concat(validate1726.errors);
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
const err30 = {instancePath,schemaPath:"#/oneOf",keyword:"oneOf",params:{passingSchemas: passing0}};
if(vErrors === null){
vErrors = [err30];
}
else {
vErrors.push(err30);
}
errors++;
validate2000.errors = vErrors;
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
validate2000.errors = vErrors;
evaluated0.props = props1;
return errors === 0;
}
validate2000.evaluated = {"dynamicProps":true,"dynamicItems":false};


function validate1995(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1995.evaluated;
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
if(!(validate1772(data.missing, {instancePath:instancePath+"/missing",parentData:data,parentDataProperty:"missing",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1772.errors : vErrors.concat(validate1772.errors);
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
if(!(validate1772(data.null, {instancePath:instancePath+"/null",parentData:data,parentDataProperty:"null",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1772.errors : vErrors.concat(validate1772.errors);
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
if(!(validate1998(data.type_error, {instancePath:instancePath+"/type_error",parentData:data,parentDataProperty:"type_error",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1998.errors : vErrors.concat(validate1998.errors);
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
if(!(validate2000(data.value, {instancePath:instancePath+"/value",parentData:data,parentDataProperty:"value",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2000.errors : vErrors.concat(validate2000.errors);
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
if(!(validate2072(data.conflict, {instancePath:instancePath+"/conflict",parentData:data,parentDataProperty:"conflict",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate2072.errors : vErrors.concat(validate2072.errors);
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
validate1995.errors = vErrors;
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
validate1995.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate1995.evaluated = {"dynamicProps":true,"dynamicItems":false};


function validate1994(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1994.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(Array.isArray(data)){
if(data.length > 128){
validate1994.errors = [{instancePath,schemaPath:"#/maxItems",keyword:"maxItems",params:{limit: 128}}];
return false;
}
else {
var valid0 = true;
const len0 = data.length;
for(let i0=0; i0<len0; i0++){
const _errs1 = errors;
if(!(validate1995(data[i0], {instancePath:instancePath+"/" + i0,parentData:data,parentDataProperty:i0,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1995.errors : vErrors.concat(validate1995.errors);
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
validate1994.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "array"}}];
return false;
}
}
validate1994.errors = vErrors;
return errors === 0;
}
validate1994.evaluated = {"items":true,"dynamicProps":false,"dynamicItems":false};


function validate1979(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1979.evaluated;
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
validate1979.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "identity") || (key0 === "cells"))){
validate1979.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.identity !== undefined){
const _errs2 = errors;
if(!(validate1980(data.identity, {instancePath:instancePath+"/identity",parentData:data,parentDataProperty:"identity",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1980.errors : vErrors.concat(validate1980.errors);
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
if(!(validate1994(data.cells, {instancePath:instancePath+"/cells",parentData:data,parentDataProperty:"cells",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1994.errors : vErrors.concat(validate1994.errors);
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
validate1979.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
return false;
}
}
validate1979.errors = vErrors;
return errors === 0;
}
validate1979.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate1978(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1978.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate1979(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1979.errors : vErrors.concat(validate1979.errors);
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
validate1978.errors = vErrors;
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
validate1978.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate1978.evaluated = {"dynamicProps":true,"dynamicItems":false};


function validate1975(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1975.evaluated;
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
validate1975.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0}}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((((key0 === "reference") || (key0 === "ordinal")) || (key0 === "row")) || (key0 === "complete_coverage"))){
validate1975.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0}}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.reference !== undefined){
const _errs2 = errors;
if(!(validate1724(data.reference, {instancePath:instancePath+"/reference",parentData:data,parentDataProperty:"reference",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1724.errors : vErrors.concat(validate1724.errors);
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
if(!(validate1726(data.ordinal, {instancePath:instancePath+"/ordinal",parentData:data,parentDataProperty:"ordinal",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1726.errors : vErrors.concat(validate1726.errors);
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
if(!(validate1978(data.row, {instancePath:instancePath+"/row",parentData:data,parentDataProperty:"row",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1978.errors : vErrors.concat(validate1978.errors);
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
if(!(validate1662(data.complete_coverage, {instancePath:instancePath+"/complete_coverage",parentData:data,parentDataProperty:"complete_coverage",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1662.errors : vErrors.concat(validate1662.errors);
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
validate1975.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"}}];
return false;
}
}
validate1975.errors = vErrors;
return errors === 0;
}
validate1975.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate1971(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1971.evaluated;
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
if(!(validate1655(data.capabilities, {instancePath:instancePath+"/capabilities",parentData:data,parentDataProperty:"capabilities",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1655.errors : vErrors.concat(validate1655.errors);
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
if(!(validate1731(data.explained, {instancePath:instancePath+"/explained",parentData:data,parentDataProperty:"explained",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1731.errors : vErrors.concat(validate1731.errors);
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
if(!(validate1723(data.opened, {instancePath:instancePath+"/opened",parentData:data,parentDataProperty:"opened",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1723.errors : vErrors.concat(validate1723.errors);
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
if(!(validate1975(data.page, {instancePath:instancePath+"/page",parentData:data,parentDataProperty:"page",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1975.errors : vErrors.concat(validate1975.errors);
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
if(!(validate1772(data.closed, {instancePath:instancePath+"/closed",parentData:data,parentDataProperty:"closed",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1772.errors : vErrors.concat(validate1772.errors);
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
validate1971.errors = vErrors;
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
validate1971.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate1971.evaluated = {"dynamicProps":true,"dynamicItems":false};


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
if(!(validate1654(data.description, {instancePath:instancePath+"/description",parentData:data,parentDataProperty:"description",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1654.errors : vErrors.concat(validate1654.errors);
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
if(!(validate1906(data.storage, {instancePath:instancePath+"/storage",parentData:data,parentDataProperty:"storage",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1906.errors : vErrors.concat(validate1906.errors);
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
if(!(validate1971(data.query, {instancePath:instancePath+"/query",parentData:data,parentDataProperty:"query",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1971.errors : vErrors.concat(validate1971.errors);
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
if(!(validate1772(data.recovered, {instancePath:instancePath+"/recovered",parentData:data,parentDataProperty:"recovered",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1772.errors : vErrors.concat(validate1772.errors);
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
validate1653.errors = vErrors;
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
validate1653.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate1653.evaluated = {"dynamicProps":true,"dynamicItems":false};
