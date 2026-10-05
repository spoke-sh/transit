// Generated; no runtime code generation or eval.
import lengthModule from "ajv/dist/runtime/ucs2length.js";
const ucs2length = lengthModule.default ?? lengthModule;
"use strict";
export const Request = validate53;
const schema20 = {"oneOf":[{"type":"object","additionalProperties":false,"required":["describe"],"properties":{"describe":{"type":"object","maxProperties":0}}},{"type":"object","additionalProperties":false,"required":["sql_capabilities"],"properties":{"sql_capabilities":{"type":"object","maxProperties":0}}},{"type":"object","additionalProperties":false,"required":["suggest"],"properties":{"suggest":{"type":"object","additionalProperties":false,"properties":{"search":{"type":"string","maxLength":131072}},"required":["search"]}}},{"type":"object","additionalProperties":false,"required":["assist"],"properties":{"assist":{"type":"object","additionalProperties":false,"properties":{"sql":{"type":"string","maxLength":131072},"cursor":{"$ref":"https://transit.invalid/generated-validator/0"},"generation":{"$ref":"https://transit.invalid/generated-validator/1"},"mode":{"type":"string","enum":["sql","console"]}},"required":["sql","cursor","generation"]}}},{"type":"object","additionalProperties":false,"required":["compile"],"properties":{"compile":{"type":"object","additionalProperties":false,"properties":{"sql":{"type":"string","maxLength":131072},"parameters":{"anyOf":[{"type":"array","maxItems":8,"items":{"$ref":"https://transit.invalid/generated-validator/8"}},{"type":"null"}]}},"required":["sql"]}}},{"type":"object","additionalProperties":false,"required":["inspect"],"properties":{"inspect":{"type":"object","additionalProperties":false,"properties":{"sql":{"type":"string","maxLength":131072}},"required":["sql"]}}},{"type":"object","additionalProperties":false,"required":["next"],"properties":{"next":{"type":"object","additionalProperties":false,"properties":{"namespace":{"type":"string","maxLength":131072},"bundle":{"type":"string","maxLength":131072}},"required":["namespace","bundle"]}}},{"type":"object","additionalProperties":false,"required":["next_draft"],"properties":{"next_draft":{"type":"object","additionalProperties":false,"properties":{"namespace":{"type":"string","maxLength":131072},"bundle":{"type":"string","maxLength":131072},"generation":{"type":"string","maxLength":131072}},"required":["namespace","bundle","generation"]}}},{"type":"object","additionalProperties":false,"required":["draft_open"],"properties":{"draft_open":{"type":"object","additionalProperties":false,"properties":{"expected":{"type":"string","maxLength":131072},"limit":{"$ref":"https://transit.invalid/generated-validator/9"}},"required":["expected","limit"]}}},{"type":"object","additionalProperties":false,"required":["draft_close"],"properties":{"draft_close":{"type":"string","maxLength":131072}}},{"type":"object","additionalProperties":false,"required":["draft_status"],"properties":{"draft_status":{"$ref":"https://transit.invalid/generated-validator/10"}}},{"type":"object","additionalProperties":false,"required":["submit"],"properties":{"submit":{"$ref":"https://transit.invalid/generated-validator/11"}}},{"type":"object","additionalProperties":false,"required":["observe"],"properties":{"observe":{"$ref":"https://transit.invalid/generated-validator/12"}}},{"type":"object","additionalProperties":false,"required":["status"],"properties":{"status":{"type":"string","maxLength":131072}}},{"type":"object","additionalProperties":false,"required":["page"],"properties":{"page":{"type":"object","additionalProperties":false,"properties":{"namespace":{"type":"string","maxLength":131072},"cursor":{"$ref":"https://transit.invalid/generated-validator/10"}},"required":["namespace"]}}},{"type":"object","additionalProperties":false,"required":["prepare_control"],"properties":{"prepare_control":{"type":"object","additionalProperties":false,"properties":{"namespace":{"type":"string","maxLength":131072},"operation":{"type":"string","enum":["cancel","collect","retire"]}},"required":["namespace","operation"]}}}]};
const func1 = ucs2length;
const schema21 = {"type":"integer","minimum":0,"maximum":65535};

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
if(!(((typeof data == "number") && (!(data % 1) && !isNaN(data))) && (isFinite(data)))){
validate54.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "integer"},message:"must be integer"}];
return false;
}
if(errors === 0){
if((typeof data == "number") && (isFinite(data))){
if(data > 65535 || isNaN(data)){
validate54.errors = [{instancePath,schemaPath:"#/maximum",keyword:"maximum",params:{comparison: "<=", limit: 65535},message:"must be <= 65535"}];
return false;
}
else {
if(data < 0 || isNaN(data)){
validate54.errors = [{instancePath,schemaPath:"#/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"}];
return false;
}
}
}
}
validate54.errors = vErrors;
return errors === 0;
}
validate54.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema22 = {"type":"integer","minimum":0,"maximum":4294967295};

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
validate56.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "integer"},message:"must be integer"}];
return false;
}
if(errors === 0){
if((typeof data == "number") && (isFinite(data))){
if(data > 4294967295 || isNaN(data)){
validate56.errors = [{instancePath,schemaPath:"#/maximum",keyword:"maximum",params:{comparison: "<=", limit: 4294967295},message:"must be <= 4294967295"}];
return false;
}
else {
if(data < 0 || isNaN(data)){
validate56.errors = [{instancePath,schemaPath:"#/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"}];
return false;
}
}
}
}
validate56.errors = vErrors;
return errors === 0;
}
validate56.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema23 = {"oneOf":[{"$ref":"https://transit.invalid/generated-validator/2"},{"$ref":"https://transit.invalid/generated-validator/3"},{"$ref":"https://transit.invalid/generated-validator/4"},{"$ref":"https://transit.invalid/generated-validator/5"},{"$ref":"https://transit.invalid/generated-validator/6"},{"$ref":"https://transit.invalid/generated-validator/7"}]};
const schema24 = {"type":"object","additionalProperties":false,"required":["int64"],"properties":{"int64":{"type":"string","maxLength":131072}}};

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
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((data.int64 === undefined) && (missing0 = "int64")){
validate59.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(key0 === "int64")){
validate59.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
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
if(func1(data0) > 131072){
validate59.errors = [{instancePath:instancePath+"/int64",schemaPath:"#/properties/int64/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"}];
return false;
}
}
else {
validate59.errors = [{instancePath:instancePath+"/int64",schemaPath:"#/properties/int64/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
}
}
}
}
}
else {
validate59.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate59.errors = vErrors;
return errors === 0;
}
validate59.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema25 = {"type":"object","additionalProperties":false,"required":["uint64"],"properties":{"uint64":{"type":"string","maxLength":131072}}};

function validate61(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate61.evaluated;
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
validate61.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(key0 === "uint64")){
validate61.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
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
if(func1(data0) > 131072){
validate61.errors = [{instancePath:instancePath+"/uint64",schemaPath:"#/properties/uint64/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"}];
return false;
}
}
else {
validate61.errors = [{instancePath:instancePath+"/uint64",schemaPath:"#/properties/uint64/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
}
}
}
}
}
else {
validate61.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate61.errors = vErrors;
return errors === 0;
}
validate61.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema26 = {"type":"object","additionalProperties":false,"required":["float_bits"],"properties":{"float_bits":{"type":"string","maxLength":131072}}};

function validate63(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate63.evaluated;
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
validate63.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(key0 === "float_bits")){
validate63.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
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
if(func1(data0) > 131072){
validate63.errors = [{instancePath:instancePath+"/float_bits",schemaPath:"#/properties/float_bits/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"}];
return false;
}
}
else {
validate63.errors = [{instancePath:instancePath+"/float_bits",schemaPath:"#/properties/float_bits/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
}
}
}
}
}
else {
validate63.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate63.errors = vErrors;
return errors === 0;
}
validate63.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema27 = {"type":"object","additionalProperties":false,"required":["boolean"],"properties":{"boolean":{"type":"boolean"}}};

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
if((data.boolean === undefined) && (missing0 = "boolean")){
validate65.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(key0 === "boolean")){
validate65.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.boolean !== undefined){
if(typeof data.boolean !== "boolean"){
validate65.errors = [{instancePath:instancePath+"/boolean",schemaPath:"#/properties/boolean/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"}];
return false;
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

const schema28 = {"type":"object","additionalProperties":false,"required":["utf8"],"properties":{"utf8":{"type":"string","maxLength":131072}}};

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
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((data.utf8 === undefined) && (missing0 = "utf8")){
validate67.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(key0 === "utf8")){
validate67.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
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
if(func1(data0) > 131072){
validate67.errors = [{instancePath:instancePath+"/utf8",schemaPath:"#/properties/utf8/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"}];
return false;
}
}
else {
validate67.errors = [{instancePath:instancePath+"/utf8",schemaPath:"#/properties/utf8/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
}
}
}
}
}
else {
validate67.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate67.errors = vErrors;
return errors === 0;
}
validate67.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema29 = {"type":"object","additionalProperties":false,"required":["binary"],"properties":{"binary":{"type":"string","maxLength":131072}}};

function validate69(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate69.evaluated;
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
validate69.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(key0 === "binary")){
validate69.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
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
if(func1(data0) > 131072){
validate69.errors = [{instancePath:instancePath+"/binary",schemaPath:"#/properties/binary/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"}];
return false;
}
}
else {
validate69.errors = [{instancePath:instancePath+"/binary",schemaPath:"#/properties/binary/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
}
}
}
}
}
else {
validate69.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate69.errors = vErrors;
return errors === 0;
}
validate69.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate58(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate58.evaluated;
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
if(!(validate59(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate59.errors : vErrors.concat(validate59.errors);
errors = vErrors.length;
}
var _valid0 = _errs1 === errors;
if(_valid0){
valid0 = true;
passing0 = 0;
var props0 = true;
}
const _errs2 = errors;
if(!(validate61(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate61.errors : vErrors.concat(validate61.errors);
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
if(!(validate63(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate63.errors : vErrors.concat(validate63.errors);
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
if(!(validate65(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate65.errors : vErrors.concat(validate65.errors);
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
if(!(validate67(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate67.errors : vErrors.concat(validate67.errors);
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
if(!(validate69(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate69.errors : vErrors.concat(validate69.errors);
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
validate58.errors = vErrors;
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
validate58.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate58.evaluated = {"dynamicProps":true,"dynamicItems":false};

const schema30 = {"type":"integer","minimum":0,"maximum":255};

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
if(!(((typeof data == "number") && (!(data % 1) && !isNaN(data))) && (isFinite(data)))){
validate72.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "integer"},message:"must be integer"}];
return false;
}
if(errors === 0){
if((typeof data == "number") && (isFinite(data))){
if(data > 255 || isNaN(data)){
validate72.errors = [{instancePath,schemaPath:"#/maximum",keyword:"maximum",params:{comparison: "<=", limit: 255},message:"must be <= 255"}];
return false;
}
else {
if(data < 0 || isNaN(data)){
validate72.errors = [{instancePath,schemaPath:"#/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"}];
return false;
}
}
}
}
validate72.errors = vErrors;
return errors === 0;
}
validate72.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema31 = {"anyOf":[{"type":"string","maxLength":131072},{"type":"null"}]};

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
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(errors === _errs1){
if(typeof data === "string"){
if(func1(data) > 131072){
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
validate74.errors = vErrors;
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
validate74.errors = vErrors;
return errors === 0;
}
validate74.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema32 = {"type":"object","additionalProperties":false,"properties":{"token":{"type":"string","maxLength":131072}},"required":["token"]};

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
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((data.token === undefined) && (missing0 = "token")){
validate76.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(key0 === "token")){
validate76.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
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
if(func1(data0) > 131072){
validate76.errors = [{instancePath:instancePath+"/token",schemaPath:"#/properties/token/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"}];
return false;
}
}
else {
validate76.errors = [{instancePath:instancePath+"/token",schemaPath:"#/properties/token/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
}
}
}
}
}
else {
validate76.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate76.errors = vErrors;
return errors === 0;
}
validate76.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema33 = {"type":"integer","minimum":0,"maximum":9007199254740991};

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
if(!(((typeof data == "number") && (!(data % 1) && !isNaN(data))) && (isFinite(data)))){
validate78.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "integer"},message:"must be integer"}];
return false;
}
if(errors === 0){
if((typeof data == "number") && (isFinite(data))){
if(data > 9007199254740991 || isNaN(data)){
validate78.errors = [{instancePath,schemaPath:"#/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"}];
return false;
}
else {
if(data < 0 || isNaN(data)){
validate78.errors = [{instancePath,schemaPath:"#/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"}];
return false;
}
}
}
}
validate78.errors = vErrors;
return errors === 0;
}
validate78.evaluated = {"dynamicProps":false,"dynamicItems":false};


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
if(func1(data3) > 131072){
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
if(func1(data5) > 131072){
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
if(!(validate54(data4.cursor, {instancePath:instancePath+"/assist/cursor",parentData:data4,parentDataProperty:"cursor",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate54.errors : vErrors.concat(validate54.errors);
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
if(!(validate56(data4.generation, {instancePath:instancePath+"/assist/generation",parentData:data4,parentDataProperty:"generation",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
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
const err25 = {instancePath:instancePath+"/assist/mode",schemaPath:"#/oneOf/3/properties/assist/properties/mode/enum",keyword:"enum",params:{allowedValues: schema20.oneOf[3].properties.assist.properties.mode.enum},message:"must be equal to one of the allowed values"};
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
if(func1(data10) > 131072){
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
if(!(validate58(data11[i0], {instancePath:instancePath+"/compile/parameters/" + i0,parentData:data11,parentDataProperty:i0,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate58.errors : vErrors.concat(validate58.errors);
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
if(func1(data14) > 131072){
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
if(func1(data16) > 131072){
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
if(func1(data17) > 131072){
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
if(func1(data19) > 131072){
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
if(func1(data20) > 131072){
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
if(func1(data21) > 131072){
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
if(func1(data23) > 131072){
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
if(!(validate72(data22.limit, {instancePath:instancePath+"/draft_open/limit",parentData:data22,parentDataProperty:"limit",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate72.errors : vErrors.concat(validate72.errors);
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
if(func1(data25) > 131072){
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
if(!(validate74(data.draft_status, {instancePath:instancePath+"/draft_status",parentData:data,parentDataProperty:"draft_status",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate74.errors : vErrors.concat(validate74.errors);
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
if(!(validate76(data.submit, {instancePath:instancePath+"/submit",parentData:data,parentDataProperty:"submit",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate76.errors : vErrors.concat(validate76.errors);
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
if(!(validate78(data.observe, {instancePath:instancePath+"/observe",parentData:data,parentDataProperty:"observe",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate78.errors : vErrors.concat(validate78.errors);
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
if(func1(data29) > 131072){
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
if(func1(data31) > 131072){
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
if(!(validate74(data30.cursor, {instancePath:instancePath+"/page/cursor",parentData:data30,parentDataProperty:"cursor",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate74.errors : vErrors.concat(validate74.errors);
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
if(func1(data34) > 131072){
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
const err112 = {instancePath:instancePath+"/prepare_control/operation",schemaPath:"#/oneOf/15/properties/prepare_control/properties/operation/enum",keyword:"enum",params:{allowedValues: schema20.oneOf[15].properties.prepare_control.properties.operation.enum},message:"must be equal to one of the allowed values"};
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
validate53.errors = vErrors;
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
validate53.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate53.evaluated = {"dynamicProps":true,"dynamicItems":false};

export const Response = validate81;
const schema34 = {"oneOf":[{"type":"object","additionalProperties":false,"required":["description"],"properties":{"description":{"type":"object","additionalProperties":false,"properties":{"connection":{"type":"object","additionalProperties":false,"properties":{"realm":{"$ref":"https://transit.invalid/generated-validator/12"},"principal":{"$ref":"https://transit.invalid/generated-validator/12"},"source":{"$ref":"https://transit.invalid/generated-validator/12"},"resource":{"$ref":"https://transit.invalid/generated-validator/12"},"requester":{"$ref":"https://transit.invalid/generated-validator/12"},"requests":{"$ref":"https://transit.invalid/generated-validator/12"}},"required":["realm","principal","source","resource","requester","requests"]},"name":{"type":"string","maxLength":131072},"source":{"type":"object","additionalProperties":false,"properties":{"capabilities":{"type":"object","additionalProperties":false,"properties":{"version":{"$ref":"https://transit.invalid/generated-validator/9"},"source":{"$ref":"https://transit.invalid/generated-validator/9"},"plan":{"$ref":"https://transit.invalid/generated-validator/9"},"result":{"$ref":"https://transit.invalid/generated-validator/9"},"bundle_bytes":{"$ref":"https://transit.invalid/generated-validator/1"},"part_bytes":{"$ref":"https://transit.invalid/generated-validator/0"},"segment_bytes":{"$ref":"https://transit.invalid/generated-validator/1"},"batch_rows":{"$ref":"https://transit.invalid/generated-validator/9"},"columns":{"$ref":"https://transit.invalid/generated-validator/9"},"kv":{"type":"boolean"},"table":{"type":"boolean"},"document":{"type":"boolean"}},"required":["version","source","plan","result","bundle_bytes","part_bytes","segment_bytes","batch_rows","columns","kv","table","document"]},"source":{"$ref":"https://transit.invalid/generated-validator/31"},"resource_revision":{"$ref":"https://transit.invalid/generated-validator/12"},"policy_revision":{"type":"string","maxLength":131072},"limits":{"$ref":"https://transit.invalid/generated-validator/32"},"active":{"$ref":"https://transit.invalid/generated-validator/10"}},"required":["capabilities","source","resource_revision","policy_revision","limits","active"]},"sql":{"type":"object","additionalProperties":false,"properties":{"version":{"$ref":"https://transit.invalid/generated-validator/9"},"statement_bytes":{"$ref":"https://transit.invalid/generated-validator/1"},"named_columns":{"$ref":"https://transit.invalid/generated-validator/9"},"star_columns":{"$ref":"https://transit.invalid/generated-validator/9"},"uint64_limits":{"type":"boolean"},"uint64_literals":{"type":"boolean"},"float64_literals":{"type":"boolean"},"null_comparison":{"type":"boolean"},"explicit_null_test":{"type":"boolean"},"writes":{"type":"boolean"},"continuous":{"type":"boolean"}},"required":["version","statement_bytes","named_columns","star_columns","uint64_limits","uint64_literals","float64_literals","null_comparison","explicit_null_test","writes","continuous"]},"budgets":{"$ref":"https://transit.invalid/generated-validator/32"},"columns":{"$ref":"https://transit.invalid/generated-validator/33"}},"required":["connection","name","source","sql","budgets","columns"]}}},{"type":"object","additionalProperties":false,"required":["sql_capabilities"],"properties":{"sql_capabilities":{"type":"object","additionalProperties":false,"properties":{"version":{"$ref":"https://transit.invalid/generated-validator/9"},"parameters":{"type":"boolean"},"max_parameters":{"$ref":"https://transit.invalid/generated-validator/9"},"statement_bytes":{"$ref":"https://transit.invalid/generated-validator/1"}},"required":["version","parameters","max_parameters","statement_bytes"]}}},{"type":"object","additionalProperties":false,"required":["suggestions"],"properties":{"suggestions":{"type":"object","additionalProperties":false,"properties":{"resource":{"$ref":"https://transit.invalid/generated-validator/12"},"contract":{"$ref":"https://transit.invalid/generated-validator/34"},"items":{"type":"array","maxItems":8,"items":{"type":"object","additionalProperties":false,"properties":{"label":{"type":"string","maxLength":131072},"sql":{"type":"string","maxLength":131072}},"required":["label","sql"]}}},"required":["resource","contract","items"]}}},{"type":"object","additionalProperties":false,"required":["assistance"],"properties":{"assistance":{"type":"object","additionalProperties":false,"properties":{"version":{"$ref":"https://transit.invalid/generated-validator/9"},"generation":{"$ref":"https://transit.invalid/generated-validator/1"},"profile":{"type":"string","enum":["unified_v1"]},"resource":{"$ref":"https://transit.invalid/generated-validator/12"},"contract":{"$ref":"https://transit.invalid/generated-validator/34"},"resource_revision":{"$ref":"https://transit.invalid/generated-validator/12"},"policy_revision":{"type":"string","maxLength":131072},"range":{"anyOf":[{"type":"object","additionalProperties":false,"properties":{"start":{"$ref":"https://transit.invalid/generated-validator/0"},"end":{"$ref":"https://transit.invalid/generated-validator/0"},"quoted":{"type":"boolean"}},"required":["start","end","quoted"]},{"type":"null"}]},"items":{"type":"array","maxItems":8,"items":{"type":"object","additionalProperties":false,"properties":{"text":{"type":"string","maxLength":131072},"kind":{"type":"string","enum":["keyword","source","column","symbol","literal","meta"]},"detail":{"type":"string","maxLength":131072}},"required":["text","kind","detail"]}}},"required":["version","generation","profile","resource","contract","resource_revision","policy_revision","range","items"]}}},{"type":"object","additionalProperties":false,"required":["compiled"],"properties":{"compiled":{"type":"object","additionalProperties":false,"properties":{"bundle":{"type":"string","maxLength":131072},"source":{"$ref":"https://transit.invalid/generated-validator/31"},"plan":{"type":"object","additionalProperties":false,"properties":{"version":{"$ref":"https://transit.invalid/generated-validator/9"},"projection":{"type":"array","maxItems":8,"items":{"$ref":"https://transit.invalid/generated-validator/1"}},"output_names":{"anyOf":[{"type":"array","maxItems":8,"items":{"$ref":"https://transit.invalid/generated-validator/10"}},{"type":"null"}]},"limit":{"$ref":"https://transit.invalid/generated-validator/10"},"aggregate":{"$ref":"https://transit.invalid/generated-validator/35"},"predicate":{"oneOf":[{"$ref":"https://transit.invalid/generated-validator/36"},{"$ref":"https://transit.invalid/generated-validator/39"},{"$ref":"https://transit.invalid/generated-validator/42"},{"type":"object","additionalProperties":false,"required":["program"],"properties":{"program":{"type":"array","maxItems":64,"items":{"oneOf":[{"type":"object","additionalProperties":false,"required":["atom"],"properties":{"atom":{"oneOf":[{"$ref":"https://transit.invalid/generated-validator/36"},{"$ref":"https://transit.invalid/generated-validator/39"},{"$ref":"https://transit.invalid/generated-validator/42"}]}}},{"$ref":"https://transit.invalid/generated-validator/43"},{"$ref":"https://transit.invalid/generated-validator/44"},{"$ref":"https://transit.invalid/generated-validator/45"}]}}}}]}},"required":["version","projection","output_names","limit","aggregate","predicate"]},"limits":{"$ref":"https://transit.invalid/generated-validator/32"},"contract":{"$ref":"https://transit.invalid/generated-validator/34"},"schema":{"$ref":"https://transit.invalid/generated-validator/34"}},"required":["bundle","source","plan","limits","contract","schema"]}}},{"type":"object","additionalProperties":false,"required":["inspection"],"properties":{"inspection":{"type":"object","additionalProperties":false,"properties":{"version":{"$ref":"https://transit.invalid/generated-validator/9"},"scope":{"type":"string","enum":["configured_source"]},"name":{"type":"string","maxLength":131072},"resource":{"$ref":"https://transit.invalid/generated-validator/12"},"source_kind":{"$ref":"https://transit.invalid/generated-validator/46"},"contract":{"$ref":"https://transit.invalid/generated-validator/34"},"schema":{"$ref":"https://transit.invalid/generated-validator/34"},"resource_revision":{"$ref":"https://transit.invalid/generated-validator/12"},"policy_revision":{"type":"string","maxLength":131072},"details":{"oneOf":[{"type":"object","additionalProperties":false,"required":["description"],"properties":{"description":{"type":"object","additionalProperties":false,"properties":{"columns":{"$ref":"https://transit.invalid/generated-validator/33"}},"required":["columns"]}}},{"type":"object","additionalProperties":false,"required":["tables"],"properties":{"tables":{"$ref":"https://transit.invalid/generated-validator/22"}}},{"type":"object","additionalProperties":false,"required":["explanation"],"properties":{"explanation":{"type":"object","additionalProperties":false,"properties":{"operators":{"type":"array","maxItems":8,"items":{"type":"string","enum":["scan","filter","limit","project","count","sum","count_values"]}},"predicate":{"oneOf":[{"$ref":"https://transit.invalid/generated-validator/36"},{"$ref":"https://transit.invalid/generated-validator/48"},{"$ref":"https://transit.invalid/generated-validator/50"},{"type":"object","additionalProperties":false,"required":["program"],"properties":{"program":{"type":"array","maxItems":64,"items":{"oneOf":[{"type":"object","additionalProperties":false,"required":["atom"],"properties":{"atom":{"oneOf":[{"$ref":"https://transit.invalid/generated-validator/36"},{"$ref":"https://transit.invalid/generated-validator/48"},{"$ref":"https://transit.invalid/generated-validator/50"}]}}},{"$ref":"https://transit.invalid/generated-validator/43"},{"$ref":"https://transit.invalid/generated-validator/44"},{"$ref":"https://transit.invalid/generated-validator/45"}]}}}}]},"projection":{"$ref":"https://transit.invalid/generated-validator/22"},"limit":{"$ref":"https://transit.invalid/generated-validator/10"},"aggregate":{"$ref":"https://transit.invalid/generated-validator/35"},"columns":{"$ref":"https://transit.invalid/generated-validator/33"},"budgets":{"$ref":"https://transit.invalid/generated-validator/32"}},"required":["operators","predicate","projection","limit","aggregate","columns","budgets"]}}}]}},"required":["version","scope","name","resource","source_kind","contract","schema","resource_revision","policy_revision","details"]}}},{"type":"object","additionalProperties":false,"required":["prepared"],"properties":{"prepared":{"anyOf":[{"$ref":"https://transit.invalid/generated-validator/11"},{"type":"null"}]}}},{"type":"object","additionalProperties":false,"required":["receipt"],"properties":{"receipt":{"type":"object","additionalProperties":false,"properties":{"position":{"$ref":"https://transit.invalid/generated-validator/12"}},"required":["position"]}}},{"type":"object","additionalProperties":false,"required":["observation"],"properties":{"observation":{"oneOf":[{"type":"object","additionalProperties":false,"required":["pending"],"properties":{"pending":{"type":"object","maxProperties":0}}},{"type":"object","additionalProperties":false,"required":["committed"],"properties":{"committed":{"type":"object","maxProperties":0}}},{"type":"object","additionalProperties":false,"required":["rejected"],"properties":{"rejected":{"$ref":"https://transit.invalid/generated-validator/51"}}}]}}},{"type":"object","additionalProperties":false,"required":["status"],"properties":{"status":{"anyOf":[{"type":"object","additionalProperties":false,"properties":{"reference":{"$ref":"https://transit.invalid/generated-validator/51"},"phase":{"type":"string","enum":["uploading","sealed","admitted","complete","cancelled","denied","rejected","retired"]},"correlation":{"type":"string","maxLength":131072},"manifest":{"anyOf":[{"$ref":"https://transit.invalid/generated-validator/51"},{"type":"null"}]},"collected":{"type":"boolean"},"failure":{"anyOf":[{"type":"object","additionalProperties":false,"properties":{"code":{"type":"string","enum":["policy_denied","access_denied","resource_unavailable","request_unpublished","publisher_mismatch","document_history_gap","document_retired","document_resync_required","budget_exceeded","projection_budget","expansion_missing","expansion_null","expansion_conflict","expansion_type_error","cell_type_error","cell_conflict","arithmetic_overflow","segment_byte_limit","type_mismatch","unsupported_aggregate","unknown_column","invalid_projection","duplicate_projection","invalid_bundle","invalid_source","invalid_prefix","invalid_path","invalid_projection_budget","invalid_text_projection","invalid_element_projection","unsupported_source","unsupported_decoder","unsupported_document_source","invalid_source_encoding","invalid_plan_encoding","plan_definition_mismatch","invalid_output_names","unsupported_plan","plan_too_large","bundle_too_large","truncated_input","source_changed","table_schema_changed","invalid_budget","namespace_in_use","query_after_mutation","nonfinite_value","invalid_utf8","cell_too_large","invalid_column_name","invalid_column_count","duplicate_column","unsupported_schema","peer_mismatch","invalid_request_reference","writer_not_ready","request_resource_expired","request_resource_missing"]},"stage":{"type":"string","enum":["admission","execution"]},"dimension":{"type":"string","enum":["none","pages","segments","result_bytes"]},"limit":{"type":"string","maxLength":131072},"observed":{"type":"string","maxLength":131072}},"required":["code","stage","dimension","limit","observed"]},{"type":"null"}]},"diagnostic":{"anyOf":[{"$ref":"https://transit.invalid/generated-validator/85"},{"type":"null"}]}},"required":["reference","phase","correlation","manifest","collected","failure","diagnostic"]},{"type":"null"}]}}},{"type":"object","additionalProperties":false,"required":["page"],"properties":{"page":{"type":"object","additionalProperties":false,"properties":{"evidence":{"type":"object","additionalProperties":false,"properties":{"manifest":{"type":"object","additionalProperties":false,"properties":{"job":{"$ref":"https://transit.invalid/generated-validator/12"},"source":{"type":"object","additionalProperties":false,"properties":{"pid":{"$ref":"https://transit.invalid/generated-validator/12"},"input":{"$ref":"https://transit.invalid/generated-validator/12"},"index":{"$ref":"https://transit.invalid/generated-validator/9"}},"required":["pid","input","index"]},"requester":{"$ref":"https://transit.invalid/generated-validator/12"},"correlation":{"type":"string","maxLength":131072},"policy_revision":{"type":"string","maxLength":131072},"request":{"$ref":"https://transit.invalid/generated-validator/51"},"basis":{"type":"object","additionalProperties":false,"properties":{"kind":{"$ref":"https://transit.invalid/generated-validator/46"},"resource":{"$ref":"https://transit.invalid/generated-validator/12"},"revision":{"$ref":"https://transit.invalid/generated-validator/12"},"contract":{"$ref":"https://transit.invalid/generated-validator/34"},"schema":{"$ref":"https://transit.invalid/generated-validator/34"}},"required":["kind","resource","revision","contract","schema"]},"plan":{"$ref":"https://transit.invalid/generated-validator/34"},"pages":{"type":"string","maxLength":131072},"scanned":{"type":"string","maxLength":131072},"selected":{"type":"string","maxLength":131072},"value_count":{"type":"string","maxLength":131072},"segments":{"type":"string","maxLength":131072},"rows":{"type":"string","maxLength":131072},"bytes":{"type":"string","maxLength":131072},"sum":{"$ref":"https://transit.invalid/generated-validator/10"},"finished":{"anyOf":[{"type":"string","enum":["source_end","limit"]},{"type":"null"}]},"chain":{"$ref":"https://transit.invalid/generated-validator/34"}},"required":["job","source","requester","correlation","policy_revision","request","basis","plan","pages","scanned","selected","value_count","segments","rows","bytes","sum","finished","chain"]},"columns":{"$ref":"https://transit.invalid/generated-validator/33"},"ordinal":{"type":"string","maxLength":131072},"rows":{"$ref":"https://transit.invalid/generated-validator/9"},"ipc":{"type":"string","maxLength":131072},"next":{"$ref":"https://transit.invalid/generated-validator/10"}},"required":["manifest","columns","ordinal","rows","ipc","next"]},"cells":{"type":"array","maxItems":8,"items":{"type":"array","maxItems":8,"items":{"oneOf":[{"type":"object","additionalProperties":false,"required":["missing"],"properties":{"missing":{"type":"object","maxProperties":0}}},{"$ref":"https://transit.invalid/generated-validator/86"},{"$ref":"https://transit.invalid/generated-validator/88"},{"$ref":"https://transit.invalid/generated-validator/89"},{"type":"object","additionalProperties":false,"required":["conflict"],"properties":{"conflict":{"type":"array","maxItems":8,"items":{"type":"object","additionalProperties":false,"properties":{"counter":{"type":"string","maxLength":131072},"replica":{"type":"string","maxLength":131072},"value":{"oneOf":[{"$ref":"https://transit.invalid/generated-validator/86"},{"$ref":"https://transit.invalid/generated-validator/88"},{"$ref":"https://transit.invalid/generated-validator/89"}]}},"required":["counter","replica","value"]}}}}]}}}},"required":["evidence","cells"]}}},{"type":"object","additionalProperties":false,"required":["draft"],"properties":{"draft":{"anyOf":[{"$ref":"https://transit.invalid/generated-validator/91"},{"type":"null"}]}}}]};
const schema35 = {"type":"object","additionalProperties":false,"properties":{"version":{"$ref":"https://transit.invalid/generated-validator/9"},"resource":{"$ref":"https://transit.invalid/generated-validator/12"},"source":{"$ref":"https://transit.invalid/generated-validator/30"}},"required":["version","resource","source"]};
const schema36 = {"oneOf":[{"$ref":"https://transit.invalid/generated-validator/16"},{"$ref":"https://transit.invalid/generated-validator/20"},{"$ref":"https://transit.invalid/generated-validator/29"}]};
const schema37 = {"type":"object","additionalProperties":false,"required":["kv"],"properties":{"kv":{"$ref":"https://transit.invalid/generated-validator/15"}}};
const schema38 = {"type":"object","additionalProperties":false,"properties":{"prefix":{"type":"string","maxLength":131072},"key":{"$ref":"https://transit.invalid/generated-validator/14"},"value":{"$ref":"https://transit.invalid/generated-validator/14"}},"required":["prefix","key","value"]};
const schema39 = {"type":"object","additionalProperties":false,"properties":{"version":{"$ref":"https://transit.invalid/generated-validator/9"},"type":{"$ref":"https://transit.invalid/generated-validator/13"}},"required":["version","type"]};
const schema40 = {"type":"string","enum":["int64","uint64","float64","boolean","utf8","binary"]};

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
if(typeof data !== "string"){
validate105.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
if(!((((((data === "int64") || (data === "uint64")) || (data === "float64")) || (data === "boolean")) || (data === "utf8")) || (data === "binary"))){
validate105.errors = [{instancePath,schemaPath:"#/enum",keyword:"enum",params:{allowedValues: schema40.enum},message:"must be equal to one of the allowed values"}];
return false;
}
validate105.errors = vErrors;
return errors === 0;
}
validate105.evaluated = {"dynamicProps":false,"dynamicItems":false};


function validate103(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate103.evaluated;
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
validate103.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "version") || (key0 === "type"))){
validate103.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.version !== undefined){
const _errs2 = errors;
if(!(validate72(data.version, {instancePath:instancePath+"/version",parentData:data,parentDataProperty:"version",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate72.errors : vErrors.concat(validate72.errors);
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
if(!(validate105(data.type, {instancePath:instancePath+"/type",parentData:data,parentDataProperty:"type",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate105.errors : vErrors.concat(validate105.errors);
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
validate103.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate103.errors = vErrors;
return errors === 0;
}
validate103.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


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
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((((data.prefix === undefined) && (missing0 = "prefix")) || ((data.key === undefined) && (missing0 = "key"))) || ((data.value === undefined) && (missing0 = "value"))){
validate102.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "prefix") || (key0 === "key")) || (key0 === "value"))){
validate102.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
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
if(func1(data0) > 131072){
validate102.errors = [{instancePath:instancePath+"/prefix",schemaPath:"#/properties/prefix/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"}];
return false;
}
}
else {
validate102.errors = [{instancePath:instancePath+"/prefix",schemaPath:"#/properties/prefix/type",keyword:"type",params:{type: "string"},message:"must be string"}];
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
if(!(validate103(data.key, {instancePath:instancePath+"/key",parentData:data,parentDataProperty:"key",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate103.errors : vErrors.concat(validate103.errors);
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
if(!(validate103(data.value, {instancePath:instancePath+"/value",parentData:data,parentDataProperty:"value",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate103.errors : vErrors.concat(validate103.errors);
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
validate102.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate102.errors = vErrors;
return errors === 0;
}
validate102.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


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
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((data.kv === undefined) && (missing0 = "kv")){
validate101.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(key0 === "kv")){
validate101.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.kv !== undefined){
if(!(validate102(data.kv, {instancePath:instancePath+"/kv",parentData:data,parentDataProperty:"kv",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate102.errors : vErrors.concat(validate102.errors);
errors = vErrors.length;
}
}
}
}
}
else {
validate101.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate101.errors = vErrors;
return errors === 0;
}
validate101.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema41 = {"type":"object","additionalProperties":false,"required":["table"],"properties":{"table":{"$ref":"https://transit.invalid/generated-validator/19"}}};
const schema42 = {"type":"object","additionalProperties":false,"properties":{"id":{"$ref":"https://transit.invalid/generated-validator/1"},"names":{"$ref":"https://transit.invalid/generated-validator/17"},"value_type":{"$ref":"https://transit.invalid/generated-validator/18"}},"required":["id","names","value_type"]};
const schema43 = {"type":"array","minItems":2,"maxItems":2,"items":{"type":"string","maxLength":131072}};

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
if(errors === 0){
if(Array.isArray(data)){
if(data.length > 2){
validate114.errors = [{instancePath,schemaPath:"#/maxItems",keyword:"maxItems",params:{limit: 2},message:"must NOT have more than 2 items"}];
return false;
}
else {
if(data.length < 2){
validate114.errors = [{instancePath,schemaPath:"#/minItems",keyword:"minItems",params:{limit: 2},message:"must NOT have fewer than 2 items"}];
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
if(func1(data0) > 131072){
validate114.errors = [{instancePath:instancePath+"/" + i0,schemaPath:"#/items/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"}];
return false;
}
}
else {
validate114.errors = [{instancePath:instancePath+"/" + i0,schemaPath:"#/items/type",keyword:"type",params:{type: "string"},message:"must be string"}];
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
validate114.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "array"},message:"must be array"}];
return false;
}
}
validate114.errors = vErrors;
return errors === 0;
}
validate114.evaluated = {"items":true,"dynamicProps":false,"dynamicItems":false};

const schema44 = {"type":"string","enum":["int64","boolean","utf8","binary"]};

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
if(typeof data !== "string"){
validate116.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
if(!((((data === "int64") || (data === "boolean")) || (data === "utf8")) || (data === "binary"))){
validate116.errors = [{instancePath,schemaPath:"#/enum",keyword:"enum",params:{allowedValues: schema44.enum},message:"must be equal to one of the allowed values"}];
return false;
}
validate116.errors = vErrors;
return errors === 0;
}
validate116.evaluated = {"dynamicProps":false,"dynamicItems":false};


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
if((((data.id === undefined) && (missing0 = "id")) || ((data.names === undefined) && (missing0 = "names"))) || ((data.value_type === undefined) && (missing0 = "value_type"))){
validate112.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "id") || (key0 === "names")) || (key0 === "value_type"))){
validate112.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
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
if(data.names !== undefined){
const _errs3 = errors;
if(!(validate114(data.names, {instancePath:instancePath+"/names",parentData:data,parentDataProperty:"names",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate114.errors : vErrors.concat(validate114.errors);
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
if(!(validate116(data.value_type, {instancePath:instancePath+"/value_type",parentData:data,parentDataProperty:"value_type",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate116.errors : vErrors.concat(validate116.errors);
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
validate112.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
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
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((data.table === undefined) && (missing0 = "table")){
validate111.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(key0 === "table")){
validate111.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.table !== undefined){
if(!(validate112(data.table, {instancePath:instancePath+"/table",parentData:data,parentDataProperty:"table",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate112.errors : vErrors.concat(validate112.errors);
errors = vErrors.length;
}
}
}
}
}
else {
validate111.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate111.errors = vErrors;
return errors === 0;
}
validate111.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema45 = {"type":"object","additionalProperties":false,"required":["document"],"properties":{"document":{"$ref":"https://transit.invalid/generated-validator/28"}}};
const schema46 = {"type":"object","additionalProperties":false,"properties":{"reference":{"$ref":"https://transit.invalid/generated-validator/21"},"change_format":{"$ref":"https://transit.invalid/generated-validator/1"},"expand":{"$ref":"https://transit.invalid/generated-validator/23"},"projections":{"$ref":"https://transit.invalid/generated-validator/27"}},"required":["reference","change_format","expand","projections"]};
const schema47 = {"type":"object","additionalProperties":false,"properties":{"resource":{"$ref":"https://transit.invalid/generated-validator/12"},"document":{"type":"string","maxLength":131072},"epoch":{"type":"string","maxLength":131072},"type_revision":{"$ref":"https://transit.invalid/generated-validator/1"},"revision":{"type":"string","maxLength":131072}},"required":["resource","document","epoch","type_revision","revision"]};

function validate122(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate122.evaluated;
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
validate122.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((((key0 === "resource") || (key0 === "document")) || (key0 === "epoch")) || (key0 === "type_revision")) || (key0 === "revision"))){
validate122.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.resource !== undefined){
const _errs2 = errors;
if(!(validate78(data.resource, {instancePath:instancePath+"/resource",parentData:data,parentDataProperty:"resource",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate78.errors : vErrors.concat(validate78.errors);
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
if(func1(data1) > 131072){
validate122.errors = [{instancePath:instancePath+"/document",schemaPath:"#/properties/document/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"}];
return false;
}
}
else {
validate122.errors = [{instancePath:instancePath+"/document",schemaPath:"#/properties/document/type",keyword:"type",params:{type: "string"},message:"must be string"}];
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
if(func1(data2) > 131072){
validate122.errors = [{instancePath:instancePath+"/epoch",schemaPath:"#/properties/epoch/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"}];
return false;
}
}
else {
validate122.errors = [{instancePath:instancePath+"/epoch",schemaPath:"#/properties/epoch/type",keyword:"type",params:{type: "string"},message:"must be string"}];
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
if(!(validate56(data.type_revision, {instancePath:instancePath+"/type_revision",parentData:data,parentDataProperty:"type_revision",rootData,dynamicAnchors}))){
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
let data4 = data.revision;
const _errs8 = errors;
if(errors === _errs8){
if(typeof data4 === "string"){
if(func1(data4) > 131072){
validate122.errors = [{instancePath:instancePath+"/revision",schemaPath:"#/properties/revision/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"}];
return false;
}
}
else {
validate122.errors = [{instancePath:instancePath+"/revision",schemaPath:"#/properties/revision/type",keyword:"type",params:{type: "string"},message:"must be string"}];
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
validate122.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate122.errors = vErrors;
return errors === 0;
}
validate122.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema48 = {"anyOf":[{"$ref":"https://transit.invalid/generated-validator/22"},{"type":"null"}]};
const schema49 = {"type":"array","maxItems":8,"items":{"type":"string","maxLength":131072}};

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
if(errors === 0){
if(Array.isArray(data)){
if(data.length > 8){
validate128.errors = [{instancePath,schemaPath:"#/maxItems",keyword:"maxItems",params:{limit: 8},message:"must NOT have more than 8 items"}];
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
if(func1(data0) > 131072){
validate128.errors = [{instancePath:instancePath+"/" + i0,schemaPath:"#/items/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"}];
return false;
}
}
else {
validate128.errors = [{instancePath:instancePath+"/" + i0,schemaPath:"#/items/type",keyword:"type",params:{type: "string"},message:"must be string"}];
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
validate128.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "array"},message:"must be array"}];
return false;
}
}
validate128.errors = vErrors;
return errors === 0;
}
validate128.evaluated = {"items":true,"dynamicProps":false,"dynamicItems":false};


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
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate128(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate128.errors : vErrors.concat(validate128.errors);
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
validate127.errors = vErrors;
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
validate127.errors = vErrors;
evaluated0.items = items0;
return errors === 0;
}
validate127.evaluated = {"dynamicProps":false,"dynamicItems":true};

const schema50 = {"type":"array","maxItems":8,"items":{"$ref":"https://transit.invalid/generated-validator/26"}};
const schema51 = {"type":"object","additionalProperties":false,"properties":{"column":{"$ref":"https://transit.invalid/generated-validator/24"},"path":{"$ref":"https://transit.invalid/generated-validator/22"},"relative":{"type":"boolean"},"mode":{"$ref":"https://transit.invalid/generated-validator/25"},"text_bytes":{"$ref":"https://transit.invalid/generated-validator/0"},"text_steps":{"$ref":"https://transit.invalid/generated-validator/0"}},"required":["column","path","relative","mode","text_bytes","text_steps"]};
const schema52 = {"type":"object","additionalProperties":false,"properties":{"name":{"type":"string","maxLength":131072},"type":{"$ref":"https://transit.invalid/generated-validator/13"}},"required":["name","type"]};

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
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if(((data.name === undefined) && (missing0 = "name")) || ((data.type === undefined) && (missing0 = "type"))){
validate133.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "name") || (key0 === "type"))){
validate133.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
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
if(func1(data0) > 131072){
validate133.errors = [{instancePath:instancePath+"/name",schemaPath:"#/properties/name/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"}];
return false;
}
}
else {
validate133.errors = [{instancePath:instancePath+"/name",schemaPath:"#/properties/name/type",keyword:"type",params:{type: "string"},message:"must be string"}];
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
if(!(validate105(data.type, {instancePath:instancePath+"/type",parentData:data,parentDataProperty:"type",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate105.errors : vErrors.concat(validate105.errors);
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
validate133.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate133.errors = vErrors;
return errors === 0;
}
validate133.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema53 = {"type":"string","enum":["scalar","text","element_counter","element_replica"]};

function validate137(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate137.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate137.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
if(!((((data === "scalar") || (data === "text")) || (data === "element_counter")) || (data === "element_replica"))){
validate137.errors = [{instancePath,schemaPath:"#/enum",keyword:"enum",params:{allowedValues: schema53.enum},message:"must be equal to one of the allowed values"}];
return false;
}
validate137.errors = vErrors;
return errors === 0;
}
validate137.evaluated = {"dynamicProps":false,"dynamicItems":false};


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
if(((((((data.column === undefined) && (missing0 = "column")) || ((data.path === undefined) && (missing0 = "path"))) || ((data.relative === undefined) && (missing0 = "relative"))) || ((data.mode === undefined) && (missing0 = "mode"))) || ((data.text_bytes === undefined) && (missing0 = "text_bytes"))) || ((data.text_steps === undefined) && (missing0 = "text_steps"))){
validate132.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((((((key0 === "column") || (key0 === "path")) || (key0 === "relative")) || (key0 === "mode")) || (key0 === "text_bytes")) || (key0 === "text_steps"))){
validate132.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.column !== undefined){
const _errs2 = errors;
if(!(validate133(data.column, {instancePath:instancePath+"/column",parentData:data,parentDataProperty:"column",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate133.errors : vErrors.concat(validate133.errors);
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
if(!(validate128(data.path, {instancePath:instancePath+"/path",parentData:data,parentDataProperty:"path",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate128.errors : vErrors.concat(validate128.errors);
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
validate132.errors = [{instancePath:instancePath+"/relative",schemaPath:"#/properties/relative/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"}];
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
if(!(validate137(data.mode, {instancePath:instancePath+"/mode",parentData:data,parentDataProperty:"mode",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate137.errors : vErrors.concat(validate137.errors);
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
if(!(validate54(data.text_bytes, {instancePath:instancePath+"/text_bytes",parentData:data,parentDataProperty:"text_bytes",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate54.errors : vErrors.concat(validate54.errors);
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
if(!(validate54(data.text_steps, {instancePath:instancePath+"/text_steps",parentData:data,parentDataProperty:"text_steps",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate54.errors : vErrors.concat(validate54.errors);
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
validate132.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate132.errors = vErrors;
return errors === 0;
}
validate132.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate131(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate131.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(Array.isArray(data)){
if(data.length > 8){
validate131.errors = [{instancePath,schemaPath:"#/maxItems",keyword:"maxItems",params:{limit: 8},message:"must NOT have more than 8 items"}];
return false;
}
else {
var valid0 = true;
const len0 = data.length;
for(let i0=0; i0<len0; i0++){
const _errs1 = errors;
if(!(validate132(data[i0], {instancePath:instancePath+"/" + i0,parentData:data,parentDataProperty:i0,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate132.errors : vErrors.concat(validate132.errors);
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
validate131.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "array"},message:"must be array"}];
return false;
}
}
validate131.errors = vErrors;
return errors === 0;
}
validate131.evaluated = {"items":true,"dynamicProps":false,"dynamicItems":false};


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
if(((((data.reference === undefined) && (missing0 = "reference")) || ((data.change_format === undefined) && (missing0 = "change_format"))) || ((data.expand === undefined) && (missing0 = "expand"))) || ((data.projections === undefined) && (missing0 = "projections"))){
validate121.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((((key0 === "reference") || (key0 === "change_format")) || (key0 === "expand")) || (key0 === "projections"))){
validate121.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.reference !== undefined){
const _errs2 = errors;
if(!(validate122(data.reference, {instancePath:instancePath+"/reference",parentData:data,parentDataProperty:"reference",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate122.errors : vErrors.concat(validate122.errors);
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
if(!(validate56(data.change_format, {instancePath:instancePath+"/change_format",parentData:data,parentDataProperty:"change_format",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
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
if(!(validate127(data.expand, {instancePath:instancePath+"/expand",parentData:data,parentDataProperty:"expand",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate127.errors : vErrors.concat(validate127.errors);
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
if(!(validate131(data.projections, {instancePath:instancePath+"/projections",parentData:data,parentDataProperty:"projections",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate131.errors : vErrors.concat(validate131.errors);
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
validate121.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate121.errors = vErrors;
return errors === 0;
}
validate121.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


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
if((data.document === undefined) && (missing0 = "document")){
validate120.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(key0 === "document")){
validate120.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.document !== undefined){
if(!(validate121(data.document, {instancePath:instancePath+"/document",parentData:data,parentDataProperty:"document",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate121.errors : vErrors.concat(validate121.errors);
errors = vErrors.length;
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


function validate100(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate100.evaluated;
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
if(!(validate101(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate101.errors : vErrors.concat(validate101.errors);
errors = vErrors.length;
}
var _valid0 = _errs1 === errors;
if(_valid0){
valid0 = true;
passing0 = 0;
var props0 = true;
}
const _errs2 = errors;
if(!(validate111(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate111.errors : vErrors.concat(validate111.errors);
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
if(!(validate120(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate120.errors : vErrors.concat(validate120.errors);
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
validate100.errors = vErrors;
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
validate100.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate100.evaluated = {"dynamicProps":true,"dynamicItems":false};


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
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((((data.version === undefined) && (missing0 = "version")) || ((data.resource === undefined) && (missing0 = "resource"))) || ((data.source === undefined) && (missing0 = "source"))){
validate97.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "version") || (key0 === "resource")) || (key0 === "source"))){
validate97.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.version !== undefined){
const _errs2 = errors;
if(!(validate72(data.version, {instancePath:instancePath+"/version",parentData:data,parentDataProperty:"version",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate72.errors : vErrors.concat(validate72.errors);
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
if(!(validate78(data.resource, {instancePath:instancePath+"/resource",parentData:data,parentDataProperty:"resource",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate78.errors : vErrors.concat(validate78.errors);
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
if(!(validate100(data.source, {instancePath:instancePath+"/source",parentData:data,parentDataProperty:"source",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate100.errors : vErrors.concat(validate100.errors);
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
validate97.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate97.errors = vErrors;
return errors === 0;
}
validate97.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema54 = {"type":"object","additionalProperties":false,"properties":{"pages":{"type":"string","maxLength":131072},"segments":{"type":"string","maxLength":131072},"result_bytes":{"type":"string","maxLength":131072}},"required":["pages","segments","result_bytes"]};

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
if((((data.pages === undefined) && (missing0 = "pages")) || ((data.segments === undefined) && (missing0 = "segments"))) || ((data.result_bytes === undefined) && (missing0 = "result_bytes"))){
validate148.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "pages") || (key0 === "segments")) || (key0 === "result_bytes"))){
validate148.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
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
if(func1(data0) > 131072){
validate148.errors = [{instancePath:instancePath+"/pages",schemaPath:"#/properties/pages/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"}];
return false;
}
}
else {
validate148.errors = [{instancePath:instancePath+"/pages",schemaPath:"#/properties/pages/type",keyword:"type",params:{type: "string"},message:"must be string"}];
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
if(func1(data1) > 131072){
validate148.errors = [{instancePath:instancePath+"/segments",schemaPath:"#/properties/segments/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"}];
return false;
}
}
else {
validate148.errors = [{instancePath:instancePath+"/segments",schemaPath:"#/properties/segments/type",keyword:"type",params:{type: "string"},message:"must be string"}];
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
if(func1(data2) > 131072){
validate148.errors = [{instancePath:instancePath+"/result_bytes",schemaPath:"#/properties/result_bytes/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"}];
return false;
}
}
else {
validate148.errors = [{instancePath:instancePath+"/result_bytes",schemaPath:"#/properties/result_bytes/type",keyword:"type",params:{type: "string"},message:"must be string"}];
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
validate148.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate148.errors = vErrors;
return errors === 0;
}
validate148.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema55 = {"type":"array","maxItems":8,"items":{"$ref":"https://transit.invalid/generated-validator/24"}};

function validate156(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate156.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(Array.isArray(data)){
if(data.length > 8){
validate156.errors = [{instancePath,schemaPath:"#/maxItems",keyword:"maxItems",params:{limit: 8},message:"must NOT have more than 8 items"}];
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
else {
validate156.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "array"},message:"must be array"}];
return false;
}
}
validate156.errors = vErrors;
return errors === 0;
}
validate156.evaluated = {"items":true,"dynamicProps":false,"dynamicItems":false};

const schema56 = {"type":"array","minItems":32,"maxItems":32,"items":{"$ref":"https://transit.invalid/generated-validator/9"}};

function validate163(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate163.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(Array.isArray(data)){
if(data.length > 32){
validate163.errors = [{instancePath,schemaPath:"#/maxItems",keyword:"maxItems",params:{limit: 32},message:"must NOT have more than 32 items"}];
return false;
}
else {
if(data.length < 32){
validate163.errors = [{instancePath,schemaPath:"#/minItems",keyword:"minItems",params:{limit: 32},message:"must NOT have fewer than 32 items"}];
return false;
}
else {
var valid0 = true;
const len0 = data.length;
for(let i0=0; i0<len0; i0++){
const _errs1 = errors;
if(!(validate72(data[i0], {instancePath:instancePath+"/" + i0,parentData:data,parentDataProperty:i0,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate72.errors : vErrors.concat(validate72.errors);
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
validate163.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "array"},message:"must be array"}];
return false;
}
}
validate163.errors = vErrors;
return errors === 0;
}
validate163.evaluated = {"items":true,"dynamicProps":false,"dynamicItems":false};

const schema57 = {"type":"string","enum":["rows","count","sum","count_values"]};

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
if(typeof data !== "string"){
validate178.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
if(!((((data === "rows") || (data === "count")) || (data === "sum")) || (data === "count_values"))){
validate178.errors = [{instancePath,schemaPath:"#/enum",keyword:"enum",params:{allowedValues: schema57.enum},message:"must be equal to one of the allowed values"}];
return false;
}
validate178.errors = vErrors;
return errors === 0;
}
validate178.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema58 = {"type":"object","additionalProperties":false,"required":["all"],"properties":{"all":{"type":"object","maxProperties":0}}};

function validate180(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate180.evaluated;
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
validate180.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(key0 === "all")){
validate180.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
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
validate180.errors = [{instancePath:instancePath+"/all",schemaPath:"#/properties/all/maxProperties",keyword:"maxProperties",params:{limit: 0},message:"must NOT have more than 0 properties"}];
return false;
}
}
else {
validate180.errors = [{instancePath:instancePath+"/all",schemaPath:"#/properties/all/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
}
}
}
}
else {
validate180.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate180.errors = vErrors;
return errors === 0;
}
validate180.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema59 = {"type":"object","additionalProperties":false,"required":["state"],"properties":{"state":{"$ref":"https://transit.invalid/generated-validator/38"}}};
const schema60 = {"type":"object","additionalProperties":false,"properties":{"column":{"$ref":"https://transit.invalid/generated-validator/9"},"value":{"$ref":"https://transit.invalid/generated-validator/37"}},"required":["column","value"]};
const schema61 = {"type":"string","enum":["missing","null","type_error","value","conflict"]};

function validate185(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate185.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate185.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
if(!(((((data === "missing") || (data === "null")) || (data === "type_error")) || (data === "value")) || (data === "conflict"))){
validate185.errors = [{instancePath,schemaPath:"#/enum",keyword:"enum",params:{allowedValues: schema61.enum},message:"must be equal to one of the allowed values"}];
return false;
}
validate185.errors = vErrors;
return errors === 0;
}
validate185.evaluated = {"dynamicProps":false,"dynamicItems":false};


function validate183(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate183.evaluated;
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
validate183.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "column") || (key0 === "value"))){
validate183.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.column !== undefined){
const _errs2 = errors;
if(!(validate72(data.column, {instancePath:instancePath+"/column",parentData:data,parentDataProperty:"column",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate72.errors : vErrors.concat(validate72.errors);
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
if(!(validate185(data.value, {instancePath:instancePath+"/value",parentData:data,parentDataProperty:"value",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate185.errors : vErrors.concat(validate185.errors);
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
validate183.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate183.errors = vErrors;
return errors === 0;
}
validate183.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate182(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate182.evaluated;
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
validate182.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(key0 === "state")){
validate182.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.state !== undefined){
if(!(validate183(data.state, {instancePath:instancePath+"/state",parentData:data,parentDataProperty:"state",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate183.errors : vErrors.concat(validate183.errors);
errors = vErrors.length;
}
}
}
}
}
else {
validate182.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate182.errors = vErrors;
return errors === 0;
}
validate182.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema62 = {"type":"object","additionalProperties":false,"required":["compare"],"properties":{"compare":{"$ref":"https://transit.invalid/generated-validator/41"}}};
const schema63 = {"type":"object","additionalProperties":false,"properties":{"column":{"$ref":"https://transit.invalid/generated-validator/9"},"op":{"$ref":"https://transit.invalid/generated-validator/40"},"value":{"$ref":"https://transit.invalid/generated-validator/8"}},"required":["column","op","value"]};
const schema64 = {"type":"string","enum":["eq","ne","lt","le","gt","ge"]};

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
if(typeof data !== "string"){
validate192.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
if(!((((((data === "eq") || (data === "ne")) || (data === "lt")) || (data === "le")) || (data === "gt")) || (data === "ge"))){
validate192.errors = [{instancePath,schemaPath:"#/enum",keyword:"enum",params:{allowedValues: schema64.enum},message:"must be equal to one of the allowed values"}];
return false;
}
validate192.errors = vErrors;
return errors === 0;
}
validate192.evaluated = {"dynamicProps":false,"dynamicItems":false};


function validate190(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate190.evaluated;
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
validate190.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "column") || (key0 === "op")) || (key0 === "value"))){
validate190.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.column !== undefined){
const _errs2 = errors;
if(!(validate72(data.column, {instancePath:instancePath+"/column",parentData:data,parentDataProperty:"column",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate72.errors : vErrors.concat(validate72.errors);
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
if(!(validate192(data.op, {instancePath:instancePath+"/op",parentData:data,parentDataProperty:"op",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate192.errors : vErrors.concat(validate192.errors);
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
if(!(validate58(data.value, {instancePath:instancePath+"/value",parentData:data,parentDataProperty:"value",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate58.errors : vErrors.concat(validate58.errors);
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
validate190.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate190.errors = vErrors;
return errors === 0;
}
validate190.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


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
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((data.compare === undefined) && (missing0 = "compare")){
validate189.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(key0 === "compare")){
validate189.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.compare !== undefined){
if(!(validate190(data.compare, {instancePath:instancePath+"/compare",parentData:data,parentDataProperty:"compare",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate190.errors : vErrors.concat(validate190.errors);
errors = vErrors.length;
}
}
}
}
}
else {
validate189.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate189.errors = vErrors;
return errors === 0;
}
validate189.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema65 = {"type":"object","additionalProperties":false,"required":["negate"],"properties":{"negate":{"type":"object","maxProperties":0}}};

function validate200(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate200.evaluated;
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
validate200.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(key0 === "negate")){
validate200.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
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
validate200.errors = [{instancePath:instancePath+"/negate",schemaPath:"#/properties/negate/maxProperties",keyword:"maxProperties",params:{limit: 0},message:"must NOT have more than 0 properties"}];
return false;
}
}
else {
validate200.errors = [{instancePath:instancePath+"/negate",schemaPath:"#/properties/negate/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
}
}
}
}
else {
validate200.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate200.errors = vErrors;
return errors === 0;
}
validate200.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema66 = {"type":"object","additionalProperties":false,"required":["conjunction"],"properties":{"conjunction":{"type":"object","maxProperties":0}}};

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
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((data.conjunction === undefined) && (missing0 = "conjunction")){
validate202.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(key0 === "conjunction")){
validate202.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
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
validate202.errors = [{instancePath:instancePath+"/conjunction",schemaPath:"#/properties/conjunction/maxProperties",keyword:"maxProperties",params:{limit: 0},message:"must NOT have more than 0 properties"}];
return false;
}
}
else {
validate202.errors = [{instancePath:instancePath+"/conjunction",schemaPath:"#/properties/conjunction/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
}
}
}
}
else {
validate202.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate202.errors = vErrors;
return errors === 0;
}
validate202.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema67 = {"type":"object","additionalProperties":false,"required":["disjunction"],"properties":{"disjunction":{"type":"object","maxProperties":0}}};

function validate204(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate204.evaluated;
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
validate204.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(key0 === "disjunction")){
validate204.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
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
validate204.errors = [{instancePath:instancePath+"/disjunction",schemaPath:"#/properties/disjunction/maxProperties",keyword:"maxProperties",params:{limit: 0},message:"must NOT have more than 0 properties"}];
return false;
}
}
else {
validate204.errors = [{instancePath:instancePath+"/disjunction",schemaPath:"#/properties/disjunction/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
}
}
}
}
else {
validate204.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate204.errors = vErrors;
return errors === 0;
}
validate204.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema68 = {"type":"string","enum":["kv","table","document"]};

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
if(typeof data !== "string"){
validate211.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
if(!(((data === "kv") || (data === "table")) || (data === "document"))){
validate211.errors = [{instancePath,schemaPath:"#/enum",keyword:"enum",params:{allowedValues: schema68.enum},message:"must be equal to one of the allowed values"}];
return false;
}
validate211.errors = vErrors;
return errors === 0;
}
validate211.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema69 = {"type":"object","additionalProperties":false,"required":["state"],"properties":{"state":{"$ref":"https://transit.invalid/generated-validator/47"}}};
const schema70 = {"type":"object","additionalProperties":false,"properties":{"column":{"type":"string","maxLength":131072},"value":{"$ref":"https://transit.invalid/generated-validator/37"}},"required":["column","value"]};

function validate220(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate220.evaluated;
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
validate220.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "column") || (key0 === "value"))){
validate220.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
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
if(func1(data0) > 131072){
validate220.errors = [{instancePath:instancePath+"/column",schemaPath:"#/properties/column/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"}];
return false;
}
}
else {
validate220.errors = [{instancePath:instancePath+"/column",schemaPath:"#/properties/column/type",keyword:"type",params:{type: "string"},message:"must be string"}];
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
if(!(validate185(data.value, {instancePath:instancePath+"/value",parentData:data,parentDataProperty:"value",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate185.errors : vErrors.concat(validate185.errors);
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
validate220.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate220.errors = vErrors;
return errors === 0;
}
validate220.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate219(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate219.evaluated;
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
validate219.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(key0 === "state")){
validate219.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.state !== undefined){
if(!(validate220(data.state, {instancePath:instancePath+"/state",parentData:data,parentDataProperty:"state",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate220.errors : vErrors.concat(validate220.errors);
errors = vErrors.length;
}
}
}
}
}
else {
validate219.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate219.errors = vErrors;
return errors === 0;
}
validate219.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema71 = {"type":"object","additionalProperties":false,"required":["compare"],"properties":{"compare":{"$ref":"https://transit.invalid/generated-validator/49"}}};
const schema72 = {"type":"object","additionalProperties":false,"properties":{"column":{"type":"string","maxLength":131072},"op":{"$ref":"https://transit.invalid/generated-validator/40"},"type":{"$ref":"https://transit.invalid/generated-validator/13"}},"required":["column","op","type"]};

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
if((((data.column === undefined) && (missing0 = "column")) || ((data.op === undefined) && (missing0 = "op"))) || ((data.type === undefined) && (missing0 = "type"))){
validate225.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "column") || (key0 === "op")) || (key0 === "type"))){
validate225.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
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
if(func1(data0) > 131072){
validate225.errors = [{instancePath:instancePath+"/column",schemaPath:"#/properties/column/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"}];
return false;
}
}
else {
validate225.errors = [{instancePath:instancePath+"/column",schemaPath:"#/properties/column/type",keyword:"type",params:{type: "string"},message:"must be string"}];
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
if(!(validate192(data.op, {instancePath:instancePath+"/op",parentData:data,parentDataProperty:"op",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate192.errors : vErrors.concat(validate192.errors);
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
if(!(validate105(data.type, {instancePath:instancePath+"/type",parentData:data,parentDataProperty:"type",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate105.errors : vErrors.concat(validate105.errors);
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
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((data.compare === undefined) && (missing0 = "compare")){
validate224.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(key0 === "compare")){
validate224.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.compare !== undefined){
if(!(validate225(data.compare, {instancePath:instancePath+"/compare",parentData:data,parentDataProperty:"compare",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate225.errors : vErrors.concat(validate225.errors);
errors = vErrors.length;
}
}
}
}
}
else {
validate224.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate224.errors = vErrors;
return errors === 0;
}
validate224.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema73 = {"type":"string","pattern":"^(?:[0-9a-f]{2})*$","maxLength":512};
const pattern3 = new RegExp("^(?:[0-9a-f]{2})*$", "u");

function validate243(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate243.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(typeof data === "string"){
if(func1(data) > 512){
validate243.errors = [{instancePath,schemaPath:"#/maxLength",keyword:"maxLength",params:{limit: 512},message:"must NOT have more than 512 characters"}];
return false;
}
else {
if(!pattern3.test(data)){
validate243.errors = [{instancePath,schemaPath:"#/pattern",keyword:"pattern",params:{pattern: "^(?:[0-9a-f]{2})*$"},message:"must match pattern \""+"^(?:[0-9a-f]{2})*$"+"\""}];
return false;
}
}
}
else {
validate243.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
}
validate243.errors = vErrors;
return errors === 0;
}
validate243.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema74 = {"type":"object","additionalProperties":false,"properties":{"version":{"const":1},"definition":{"$ref":"https://transit.invalid/generated-validator/52"},"code":{"type":"string","maxLength":96},"category":{"$ref":"https://transit.invalid/generated-validator/53"},"stage":{"$ref":"https://transit.invalid/generated-validator/54"},"outcome":{"$ref":"https://transit.invalid/generated-validator/55"},"evidence":{"$ref":"https://transit.invalid/generated-validator/56"},"message":{"type":"string","maxLength":384},"cause":{"$ref":"https://transit.invalid/generated-validator/57"},"identity":{"$ref":"https://transit.invalid/generated-validator/62"},"location":{"$ref":"https://transit.invalid/generated-validator/66"},"facts":{"$ref":"https://transit.invalid/generated-validator/80"},"actions":{"$ref":"https://transit.invalid/generated-validator/84"}},"required":["version","definition","code","category","stage","outcome","evidence","message","cause","identity","location","facts","actions"]};
const func23 = Object.prototype.hasOwnProperty;
const schema75 = {"type":"string","enum":["57343ef043d4dc7f9612a7ca3309e9218dd527c0f3826a519ff0d29b761b4a82"]};

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
if(typeof data !== "string"){
validate248.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
if(!(data === "57343ef043d4dc7f9612a7ca3309e9218dd527c0f3826a519ff0d29b761b4a82")){
validate248.errors = [{instancePath,schemaPath:"#/enum",keyword:"enum",params:{allowedValues: schema75.enum},message:"must be equal to one of the allowed values"}];
return false;
}
validate248.errors = vErrors;
return errors === 0;
}
validate248.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema76 = {"type":"string","enum":["syntax","binding","unsupported","constraint","access","conflict","limit","lifecycle","integrity","unavailable","internal"]};

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
if(typeof data !== "string"){
validate250.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
if(!(((((((((((data === "syntax") || (data === "binding")) || (data === "unsupported")) || (data === "constraint")) || (data === "access")) || (data === "conflict")) || (data === "limit")) || (data === "lifecycle")) || (data === "integrity")) || (data === "unavailable")) || (data === "internal"))){
validate250.errors = [{instancePath,schemaPath:"#/enum",keyword:"enum",params:{allowedValues: schema76.enum},message:"must be equal to one of the allowed values"}];
return false;
}
validate250.errors = vErrors;
return errors === 0;
}
validate250.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema77 = {"type":"string","enum":["input","parse","compile","bind","prepare","submit","admission","execute","read","decode","output","reconcile","cleanup","control"]};

function validate252(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate252.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate252.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
if(!((((((((((((((data === "input") || (data === "parse")) || (data === "compile")) || (data === "bind")) || (data === "prepare")) || (data === "submit")) || (data === "admission")) || (data === "execute")) || (data === "read")) || (data === "decode")) || (data === "output")) || (data === "reconcile")) || (data === "cleanup")) || (data === "control"))){
validate252.errors = [{instancePath,schemaPath:"#/enum",keyword:"enum",params:{allowedValues: schema77.enum},message:"must be equal to one of the allowed values"}];
return false;
}
validate252.errors = vErrors;
return errors === 0;
}
validate252.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema78 = {"type":"string","enum":["not_applicable","not_submitted","not_dispatched","prepared","unknown","pending","input_rejected","rejected","applied","completed","failed","cancelled","retired","closed_unknown"]};

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
if(typeof data !== "string"){
validate254.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
if(!((((((((((((((data === "not_applicable") || (data === "not_submitted")) || (data === "not_dispatched")) || (data === "prepared")) || (data === "unknown")) || (data === "pending")) || (data === "input_rejected")) || (data === "rejected")) || (data === "applied")) || (data === "completed")) || (data === "failed")) || (data === "cancelled")) || (data === "retired")) || (data === "closed_unknown"))){
validate254.errors = [{instancePath,schemaPath:"#/enum",keyword:"enum",params:{allowedValues: schema78.enum},message:"must be equal to one of the allowed values"}];
return false;
}
validate254.errors = vErrors;
return errors === 0;
}
validate254.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema79 = {"type":"string","enum":["none","local_before_dispatch","saved_intent","native_receipt","domain_status"]};

function validate256(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate256.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate256.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
if(!(((((data === "none") || (data === "local_before_dispatch")) || (data === "saved_intent")) || (data === "native_receipt")) || (data === "domain_status"))){
validate256.errors = [{instancePath,schemaPath:"#/enum",keyword:"enum",params:{allowedValues: schema79.enum},message:"must be equal to one of the allowed values"}];
return false;
}
validate256.errors = vErrors;
return errors === 0;
}
validate256.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema80 = {"anyOf":[{"type":"string","maxLength":96},{"type":"null"}]};

function validate258(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate258.evaluated;
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
if(func1(data) > 96){
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
validate258.errors = vErrors;
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
validate258.errors = vErrors;
return errors === 0;
}
validate258.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema81 = {"anyOf":[{"$ref":"https://transit.invalid/generated-validator/61"},{"type":"null"}]};
const schema82 = {"type":"object","additionalProperties":false,"properties":{"domain":{"$ref":"https://transit.invalid/generated-validator/58"},"id":{"$ref":"https://transit.invalid/generated-validator/59"},"realm":{"$ref":"https://transit.invalid/generated-validator/60"},"resource":{"$ref":"https://transit.invalid/generated-validator/60"},"sequence":{"$ref":"https://transit.invalid/generated-validator/60"}},"required":["domain","id","realm","resource","sequence"]};
const schema83 = {"type":"string","enum":["sql","query","mutation","catalog","application","publication","migration","reactive","serving","effect","exchange","transport","internal"]};

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
if(typeof data !== "string"){
validate262.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
if(!(((((((((((((data === "sql") || (data === "query")) || (data === "mutation")) || (data === "catalog")) || (data === "application")) || (data === "publication")) || (data === "migration")) || (data === "reactive")) || (data === "serving")) || (data === "effect")) || (data === "exchange")) || (data === "transport")) || (data === "internal"))){
validate262.errors = [{instancePath,schemaPath:"#/enum",keyword:"enum",params:{allowedValues: schema83.enum},message:"must be equal to one of the allowed values"}];
return false;
}
validate262.errors = vErrors;
return errors === 0;
}
validate262.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema84 = {"type":"string","maxLength":20,"pattern":"^(0|[1-9][0-9]*)$"};
const pattern4 = new RegExp("^(0|[1-9][0-9]*)$", "u");

function validate264(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate264.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(typeof data === "string"){
if(func1(data) > 20){
validate264.errors = [{instancePath,schemaPath:"#/maxLength",keyword:"maxLength",params:{limit: 20},message:"must NOT have more than 20 characters"}];
return false;
}
else {
if(!pattern4.test(data)){
validate264.errors = [{instancePath,schemaPath:"#/pattern",keyword:"pattern",params:{pattern: "^(0|[1-9][0-9]*)$"},message:"must match pattern \""+"^(0|[1-9][0-9]*)$"+"\""}];
return false;
}
}
}
else {
validate264.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
}
validate264.errors = vErrors;
return errors === 0;
}
validate264.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema85 = {"anyOf":[{"$ref":"https://transit.invalid/generated-validator/59"},{"type":"null"}]};

function validate266(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate266.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate264(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate264.errors : vErrors.concat(validate264.errors);
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
validate266.errors = vErrors;
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
validate266.errors = vErrors;
return errors === 0;
}
validate266.evaluated = {"dynamicProps":false,"dynamicItems":false};


function validate261(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate261.evaluated;
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
validate261.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((((key0 === "domain") || (key0 === "id")) || (key0 === "realm")) || (key0 === "resource")) || (key0 === "sequence"))){
validate261.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.domain !== undefined){
const _errs2 = errors;
if(!(validate262(data.domain, {instancePath:instancePath+"/domain",parentData:data,parentDataProperty:"domain",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate262.errors : vErrors.concat(validate262.errors);
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
if(!(validate264(data.id, {instancePath:instancePath+"/id",parentData:data,parentDataProperty:"id",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate264.errors : vErrors.concat(validate264.errors);
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
if(!(validate266(data.realm, {instancePath:instancePath+"/realm",parentData:data,parentDataProperty:"realm",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate266.errors : vErrors.concat(validate266.errors);
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
if(!(validate266(data.resource, {instancePath:instancePath+"/resource",parentData:data,parentDataProperty:"resource",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate266.errors : vErrors.concat(validate266.errors);
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
if(!(validate266(data.sequence, {instancePath:instancePath+"/sequence",parentData:data,parentDataProperty:"sequence",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate266.errors : vErrors.concat(validate266.errors);
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
validate261.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate261.errors = vErrors;
return errors === 0;
}
validate261.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate260(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate260.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate261(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate261.errors : vErrors.concat(validate261.errors);
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
validate260.errors = vErrors;
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
validate260.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate260.evaluated = {"dynamicProps":true,"dynamicItems":false};

const schema86 = {"anyOf":[{"$ref":"https://transit.invalid/generated-validator/65"},{"type":"null"}]};
const schema87 = {"type":"object","additionalProperties":false,"properties":{"source":{"$ref":"https://transit.invalid/generated-validator/63"},"source_encoding":{"$ref":"https://transit.invalid/generated-validator/64"},"source_truncated":{"type":"boolean"},"statement":{"$ref":"https://transit.invalid/generated-validator/60"},"offset":{"$ref":"https://transit.invalid/generated-validator/59"},"length":{"$ref":"https://transit.invalid/generated-validator/59"},"line":{"$ref":"https://transit.invalid/generated-validator/59"},"byte_column":{"$ref":"https://transit.invalid/generated-validator/59"}},"required":["source","source_encoding","source_truncated","statement","offset","length","line","byte_column"]};
const schema88 = {"anyOf":[{"type":"string","maxLength":512},{"type":"null"}]};

function validate275(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate275.evaluated;
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
if(func1(data) > 512){
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
validate275.errors = vErrors;
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
validate275.errors = vErrors;
return errors === 0;
}
validate275.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema89 = {"type":"string","enum":["utf8","escaped_bytes"]};

function validate277(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate277.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate277.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
if(!((data === "utf8") || (data === "escaped_bytes"))){
validate277.errors = [{instancePath,schemaPath:"#/enum",keyword:"enum",params:{allowedValues: schema89.enum},message:"must be equal to one of the allowed values"}];
return false;
}
validate277.errors = vErrors;
return errors === 0;
}
validate277.evaluated = {"dynamicProps":false,"dynamicItems":false};


function validate274(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate274.evaluated;
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
validate274.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((((((((key0 === "source") || (key0 === "source_encoding")) || (key0 === "source_truncated")) || (key0 === "statement")) || (key0 === "offset")) || (key0 === "length")) || (key0 === "line")) || (key0 === "byte_column"))){
validate274.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.source !== undefined){
const _errs2 = errors;
if(!(validate275(data.source, {instancePath:instancePath+"/source",parentData:data,parentDataProperty:"source",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate275.errors : vErrors.concat(validate275.errors);
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
if(!(validate277(data.source_encoding, {instancePath:instancePath+"/source_encoding",parentData:data,parentDataProperty:"source_encoding",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate277.errors : vErrors.concat(validate277.errors);
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
validate274.errors = [{instancePath:instancePath+"/source_truncated",schemaPath:"#/properties/source_truncated/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"}];
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
if(!(validate266(data.statement, {instancePath:instancePath+"/statement",parentData:data,parentDataProperty:"statement",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate266.errors : vErrors.concat(validate266.errors);
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
if(!(validate264(data.offset, {instancePath:instancePath+"/offset",parentData:data,parentDataProperty:"offset",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate264.errors : vErrors.concat(validate264.errors);
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
if(!(validate264(data.length, {instancePath:instancePath+"/length",parentData:data,parentDataProperty:"length",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate264.errors : vErrors.concat(validate264.errors);
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
if(!(validate264(data.line, {instancePath:instancePath+"/line",parentData:data,parentDataProperty:"line",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate264.errors : vErrors.concat(validate264.errors);
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
if(!(validate264(data.byte_column, {instancePath:instancePath+"/byte_column",parentData:data,parentDataProperty:"byte_column",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate264.errors : vErrors.concat(validate264.errors);
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
validate274.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate274.errors = vErrors;
return errors === 0;
}
validate274.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


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
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate274(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate274.errors : vErrors.concat(validate274.errors);
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
validate273.errors = vErrors;
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
validate273.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate273.evaluated = {"dynamicProps":true,"dynamicItems":false};

const schema90 = {"type":"array","minItems":16,"maxItems":16,"items":{"$ref":"https://transit.invalid/generated-validator/79"}};
const schema91 = {"anyOf":[{"$ref":"https://transit.invalid/generated-validator/78"},{"type":"null"}]};
const schema92 = {"type":"object","additionalProperties":false,"properties":{"field":{"$ref":"https://transit.invalid/generated-validator/67"},"origin":{"$ref":"https://transit.invalid/generated-validator/68"},"availability":{"$ref":"https://transit.invalid/generated-validator/69"},"value":{"$ref":"https://transit.invalid/generated-validator/77"}},"required":["field","origin","availability","value"]};
const schema93 = {"type":"string","enum":["object","name","table","native_input","affected_rows","argument","option","permissions","scope","column","qualifier","constraint","key","input_row","first_occurrence","parameter","parameter_use","expected_count","actual_count","expected_type","actual_type","supplied_value","expected_value","expression","source_kind","source_basis","source_key","source_row","field_path","byte_offset","expected_resource","actual_resource","expected_source","actual_source","expected_revision","actual_revision","expected_schema","actual_schema","expected_policy","actual_policy","budget","limit","required","unit","completed_statements","emitted_rows","emitted_segments","completion","proposal","step","generation","attachment","lease","schema_origin","sampling_records","operation","native_cause","expected_bytes","presence","published","subscription","expected_codec","actual_codec","observed_clock","expected_namespace","actual_namespace","attempt","executor","resolution_reason","principal","deadline","authorization_policy","resolution_policy","protocol_status","native_effect"]};

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
if(typeof data !== "string"){
validate289.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
if(!(((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((data === "object") || (data === "name")) || (data === "table")) || (data === "native_input")) || (data === "affected_rows")) || (data === "argument")) || (data === "option")) || (data === "permissions")) || (data === "scope")) || (data === "column")) || (data === "qualifier")) || (data === "constraint")) || (data === "key")) || (data === "input_row")) || (data === "first_occurrence")) || (data === "parameter")) || (data === "parameter_use")) || (data === "expected_count")) || (data === "actual_count")) || (data === "expected_type")) || (data === "actual_type")) || (data === "supplied_value")) || (data === "expected_value")) || (data === "expression")) || (data === "source_kind")) || (data === "source_basis")) || (data === "source_key")) || (data === "source_row")) || (data === "field_path")) || (data === "byte_offset")) || (data === "expected_resource")) || (data === "actual_resource")) || (data === "expected_source")) || (data === "actual_source")) || (data === "expected_revision")) || (data === "actual_revision")) || (data === "expected_schema")) || (data === "actual_schema")) || (data === "expected_policy")) || (data === "actual_policy")) || (data === "budget")) || (data === "limit")) || (data === "required")) || (data === "unit")) || (data === "completed_statements")) || (data === "emitted_rows")) || (data === "emitted_segments")) || (data === "completion")) || (data === "proposal")) || (data === "step")) || (data === "generation")) || (data === "attachment")) || (data === "lease")) || (data === "schema_origin")) || (data === "sampling_records")) || (data === "operation")) || (data === "native_cause")) || (data === "expected_bytes")) || (data === "presence")) || (data === "published")) || (data === "subscription")) || (data === "expected_codec")) || (data === "actual_codec")) || (data === "observed_clock")) || (data === "expected_namespace")) || (data === "actual_namespace")) || (data === "attempt")) || (data === "executor")) || (data === "resolution_reason")) || (data === "principal")) || (data === "deadline")) || (data === "authorization_policy")) || (data === "resolution_policy")) || (data === "protocol_status")) || (data === "native_effect"))){
validate289.errors = [{instancePath,schemaPath:"#/enum",keyword:"enum",params:{allowedValues: schema93.enum},message:"must be equal to one of the allowed values"}];
return false;
}
validate289.errors = vErrors;
return errors === 0;
}
validate289.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema94 = {"type":"string","enum":["caller","execution","schema","authority","owner"]};

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
if(typeof data !== "string"){
validate291.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
if(!(((((data === "caller") || (data === "execution")) || (data === "schema")) || (data === "authority")) || (data === "owner"))){
validate291.errors = [{instancePath,schemaPath:"#/enum",keyword:"enum",params:{allowedValues: schema94.enum},message:"must be equal to one of the allowed values"}];
return false;
}
validate291.errors = vErrors;
return errors === 0;
}
validate291.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema95 = {"type":"string","enum":["provided","truncated","unrecorded","unavailable","withheld","inapplicable"]};

function validate293(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate293.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate293.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
if(!((((((data === "provided") || (data === "truncated")) || (data === "unrecorded")) || (data === "unavailable")) || (data === "withheld")) || (data === "inapplicable"))){
validate293.errors = [{instancePath,schemaPath:"#/enum",keyword:"enum",params:{allowedValues: schema95.enum},message:"must be equal to one of the allowed values"}];
return false;
}
validate293.errors = vErrors;
return errors === 0;
}
validate293.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema96 = {"anyOf":[{"$ref":"https://transit.invalid/generated-validator/76"},{"type":"null"}]};
const schema97 = {"oneOf":[{"$ref":"https://transit.invalid/generated-validator/70"},{"$ref":"https://transit.invalid/generated-validator/72"},{"$ref":"https://transit.invalid/generated-validator/73"},{"$ref":"https://transit.invalid/generated-validator/5"},{"$ref":"https://transit.invalid/generated-validator/74"},{"$ref":"https://transit.invalid/generated-validator/75"}]};
const schema98 = {"type":"object","additionalProperties":false,"required":["text"],"properties":{"text":{"type":"string","maxLength":256}}};

function validate297(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate297.evaluated;
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
validate297.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(key0 === "text")){
validate297.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
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
if(func1(data0) > 256){
validate297.errors = [{instancePath:instancePath+"/text",schemaPath:"#/properties/text/maxLength",keyword:"maxLength",params:{limit: 256},message:"must NOT have more than 256 characters"}];
return false;
}
}
else {
validate297.errors = [{instancePath:instancePath+"/text",schemaPath:"#/properties/text/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
}
}
}
}
}
else {
validate297.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate297.errors = vErrors;
return errors === 0;
}
validate297.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema99 = {"type":"object","additionalProperties":false,"required":["signed"],"properties":{"signed":{"$ref":"https://transit.invalid/generated-validator/71"}}};
const schema100 = {"type":"string","maxLength":20,"pattern":"^(0|-?[1-9][0-9]*)$"};
const pattern5 = new RegExp("^(0|-?[1-9][0-9]*)$", "u");

function validate300(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate300.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(typeof data === "string"){
if(func1(data) > 20){
validate300.errors = [{instancePath,schemaPath:"#/maxLength",keyword:"maxLength",params:{limit: 20},message:"must NOT have more than 20 characters"}];
return false;
}
else {
if(!pattern5.test(data)){
validate300.errors = [{instancePath,schemaPath:"#/pattern",keyword:"pattern",params:{pattern: "^(0|-?[1-9][0-9]*)$"},message:"must match pattern \""+"^(0|-?[1-9][0-9]*)$"+"\""}];
return false;
}
}
}
else {
validate300.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
}
validate300.errors = vErrors;
return errors === 0;
}
validate300.evaluated = {"dynamicProps":false,"dynamicItems":false};


function validate299(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate299.evaluated;
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
validate299.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(key0 === "signed")){
validate299.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.signed !== undefined){
if(!(validate300(data.signed, {instancePath:instancePath+"/signed",parentData:data,parentDataProperty:"signed",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate300.errors : vErrors.concat(validate300.errors);
errors = vErrors.length;
}
}
}
}
}
else {
validate299.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate299.errors = vErrors;
return errors === 0;
}
validate299.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema101 = {"type":"object","additionalProperties":false,"required":["unsigned"],"properties":{"unsigned":{"$ref":"https://transit.invalid/generated-validator/59"}}};

function validate303(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate303.evaluated;
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
validate303.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(key0 === "unsigned")){
validate303.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.unsigned !== undefined){
if(!(validate264(data.unsigned, {instancePath:instancePath+"/unsigned",parentData:data,parentDataProperty:"unsigned",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate264.errors : vErrors.concat(validate264.errors);
errors = vErrors.length;
}
}
}
}
}
else {
validate303.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate303.errors = vErrors;
return errors === 0;
}
validate303.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema102 = {"type":"object","additionalProperties":false,"required":["digest"],"properties":{"digest":{"$ref":"https://transit.invalid/generated-validator/34"}}};

function validate307(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate307.evaluated;
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
validate307.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(key0 === "digest")){
validate307.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.digest !== undefined){
if(!(validate163(data.digest, {instancePath:instancePath+"/digest",parentData:data,parentDataProperty:"digest",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate163.errors : vErrors.concat(validate163.errors);
errors = vErrors.length;
}
}
}
}
}
else {
validate307.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate307.errors = vErrors;
return errors === 0;
}
validate307.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema103 = {"type":"object","additionalProperties":false,"required":["location"],"properties":{"location":{"$ref":"https://transit.invalid/generated-validator/65"}}};

function validate310(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate310.evaluated;
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
validate310.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(key0 === "location")){
validate310.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.location !== undefined){
if(!(validate274(data.location, {instancePath:instancePath+"/location",parentData:data,parentDataProperty:"location",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate274.errors : vErrors.concat(validate274.errors);
errors = vErrors.length;
}
}
}
}
}
else {
validate310.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate310.errors = vErrors;
return errors === 0;
}
validate310.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


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
const _errs0 = errors;
let valid0 = false;
let passing0 = null;
const _errs1 = errors;
if(!(validate297(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate297.errors : vErrors.concat(validate297.errors);
errors = vErrors.length;
}
var _valid0 = _errs1 === errors;
if(_valid0){
valid0 = true;
passing0 = 0;
var props0 = true;
}
const _errs2 = errors;
if(!(validate299(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate299.errors : vErrors.concat(validate299.errors);
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
if(!(validate303(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate303.errors : vErrors.concat(validate303.errors);
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
if(!(validate65(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate65.errors : vErrors.concat(validate65.errors);
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
if(!(validate307(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate307.errors : vErrors.concat(validate307.errors);
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
if(!(validate310(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate310.errors : vErrors.concat(validate310.errors);
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
validate296.errors = vErrors;
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
validate296.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate296.evaluated = {"dynamicProps":true,"dynamicItems":false};


function validate295(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate295.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate296(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate296.errors : vErrors.concat(validate296.errors);
errors = vErrors.length;
}
else {
var props0 = validate296.evaluated.props;
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
validate295.errors = vErrors;
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
validate295.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate295.evaluated = {"dynamicProps":true,"dynamicItems":false};


function validate288(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate288.evaluated;
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
validate288.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((((key0 === "field") || (key0 === "origin")) || (key0 === "availability")) || (key0 === "value"))){
validate288.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.field !== undefined){
const _errs2 = errors;
if(!(validate289(data.field, {instancePath:instancePath+"/field",parentData:data,parentDataProperty:"field",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate289.errors : vErrors.concat(validate289.errors);
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
if(!(validate291(data.origin, {instancePath:instancePath+"/origin",parentData:data,parentDataProperty:"origin",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate291.errors : vErrors.concat(validate291.errors);
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
if(!(validate293(data.availability, {instancePath:instancePath+"/availability",parentData:data,parentDataProperty:"availability",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate293.errors : vErrors.concat(validate293.errors);
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
if(!(validate295(data.value, {instancePath:instancePath+"/value",parentData:data,parentDataProperty:"value",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate295.errors : vErrors.concat(validate295.errors);
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
validate288.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate288.errors = vErrors;
return errors === 0;
}
validate288.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


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
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate288(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate288.errors : vErrors.concat(validate288.errors);
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
validate287.errors = vErrors;
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
validate287.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate287.evaluated = {"dynamicProps":true,"dynamicItems":false};


function validate286(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate286.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(Array.isArray(data)){
if(data.length > 16){
validate286.errors = [{instancePath,schemaPath:"#/maxItems",keyword:"maxItems",params:{limit: 16},message:"must NOT have more than 16 items"}];
return false;
}
else {
if(data.length < 16){
validate286.errors = [{instancePath,schemaPath:"#/minItems",keyword:"minItems",params:{limit: 16},message:"must NOT have fewer than 16 items"}];
return false;
}
else {
var valid0 = true;
const len0 = data.length;
for(let i0=0; i0<len0; i0++){
const _errs1 = errors;
if(!(validate287(data[i0], {instancePath:instancePath+"/" + i0,parentData:data,parentDataProperty:i0,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate287.errors : vErrors.concat(validate287.errors);
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
validate286.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "array"},message:"must be array"}];
return false;
}
}
validate286.errors = vErrors;
return errors === 0;
}
validate286.evaluated = {"items":true,"dynamicProps":false,"dynamicItems":false};

const schema104 = {"type":"array","minItems":4,"maxItems":4,"items":{"$ref":"https://transit.invalid/generated-validator/83"}};
const schema105 = {"anyOf":[{"$ref":"https://transit.invalid/generated-validator/82"},{"type":"null"}]};
const schema106 = {"type":"object","additionalProperties":false,"properties":{"kind":{"$ref":"https://transit.invalid/generated-validator/81"},"target":{"$ref":"https://transit.invalid/generated-validator/62"}},"required":["kind","target"]};
const schema107 = {"type":"string","enum":["correct_input","inspect_status","resume_exact","cancel_wait","cancel_mutation","refresh","recompile","retry_read","inspect_scope","reconcile_effect","contact_operator"]};

function validate321(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate321.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate321.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
if(!(((((((((((data === "correct_input") || (data === "inspect_status")) || (data === "resume_exact")) || (data === "cancel_wait")) || (data === "cancel_mutation")) || (data === "refresh")) || (data === "recompile")) || (data === "retry_read")) || (data === "inspect_scope")) || (data === "reconcile_effect")) || (data === "contact_operator"))){
validate321.errors = [{instancePath,schemaPath:"#/enum",keyword:"enum",params:{allowedValues: schema107.enum},message:"must be equal to one of the allowed values"}];
return false;
}
validate321.errors = vErrors;
return errors === 0;
}
validate321.evaluated = {"dynamicProps":false,"dynamicItems":false};


function validate320(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate320.evaluated;
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
validate320.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "kind") || (key0 === "target"))){
validate320.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.kind !== undefined){
const _errs2 = errors;
if(!(validate321(data.kind, {instancePath:instancePath+"/kind",parentData:data,parentDataProperty:"kind",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate321.errors : vErrors.concat(validate321.errors);
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
if(!(validate260(data.target, {instancePath:instancePath+"/target",parentData:data,parentDataProperty:"target",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate260.errors : vErrors.concat(validate260.errors);
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
validate320.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate320.errors = vErrors;
return errors === 0;
}
validate320.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate319(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate319.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate320(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate320.errors : vErrors.concat(validate320.errors);
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
validate319.errors = vErrors;
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
validate319.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate319.evaluated = {"dynamicProps":true,"dynamicItems":false};


function validate318(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate318.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(Array.isArray(data)){
if(data.length > 4){
validate318.errors = [{instancePath,schemaPath:"#/maxItems",keyword:"maxItems",params:{limit: 4},message:"must NOT have more than 4 items"}];
return false;
}
else {
if(data.length < 4){
validate318.errors = [{instancePath,schemaPath:"#/minItems",keyword:"minItems",params:{limit: 4},message:"must NOT have fewer than 4 items"}];
return false;
}
else {
var valid0 = true;
const len0 = data.length;
for(let i0=0; i0<len0; i0++){
const _errs1 = errors;
if(!(validate319(data[i0], {instancePath:instancePath+"/" + i0,parentData:data,parentDataProperty:i0,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate319.errors : vErrors.concat(validate319.errors);
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
validate318.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "array"},message:"must be array"}];
return false;
}
}
validate318.errors = vErrors;
return errors === 0;
}
validate318.evaluated = {"items":true,"dynamicProps":false,"dynamicItems":false};


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
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((((((((((((((data.version === undefined) && (missing0 = "version")) || ((data.definition === undefined) && (missing0 = "definition"))) || ((data.code === undefined) && (missing0 = "code"))) || ((data.category === undefined) && (missing0 = "category"))) || ((data.stage === undefined) && (missing0 = "stage"))) || ((data.outcome === undefined) && (missing0 = "outcome"))) || ((data.evidence === undefined) && (missing0 = "evidence"))) || ((data.message === undefined) && (missing0 = "message"))) || ((data.cause === undefined) && (missing0 = "cause"))) || ((data.identity === undefined) && (missing0 = "identity"))) || ((data.location === undefined) && (missing0 = "location"))) || ((data.facts === undefined) && (missing0 = "facts"))) || ((data.actions === undefined) && (missing0 = "actions"))){
validate247.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(func23.call(schema74.properties, key0))){
validate247.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.version !== undefined){
const _errs2 = errors;
if(1 !== data.version){
validate247.errors = [{instancePath:instancePath+"/version",schemaPath:"#/properties/version/const",keyword:"const",params:{allowedValue: 1},message:"must be equal to constant"}];
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
if(!(validate248(data.definition, {instancePath:instancePath+"/definition",parentData:data,parentDataProperty:"definition",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate248.errors : vErrors.concat(validate248.errors);
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
if(func1(data2) > 96){
validate247.errors = [{instancePath:instancePath+"/code",schemaPath:"#/properties/code/maxLength",keyword:"maxLength",params:{limit: 96},message:"must NOT have more than 96 characters"}];
return false;
}
}
else {
validate247.errors = [{instancePath:instancePath+"/code",schemaPath:"#/properties/code/type",keyword:"type",params:{type: "string"},message:"must be string"}];
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
if(!(validate250(data.category, {instancePath:instancePath+"/category",parentData:data,parentDataProperty:"category",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate250.errors : vErrors.concat(validate250.errors);
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
if(!(validate252(data.stage, {instancePath:instancePath+"/stage",parentData:data,parentDataProperty:"stage",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate252.errors : vErrors.concat(validate252.errors);
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
if(!(validate254(data.outcome, {instancePath:instancePath+"/outcome",parentData:data,parentDataProperty:"outcome",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate254.errors : vErrors.concat(validate254.errors);
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
if(!(validate256(data.evidence, {instancePath:instancePath+"/evidence",parentData:data,parentDataProperty:"evidence",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate256.errors : vErrors.concat(validate256.errors);
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
if(func1(data7) > 384){
validate247.errors = [{instancePath:instancePath+"/message",schemaPath:"#/properties/message/maxLength",keyword:"maxLength",params:{limit: 384},message:"must NOT have more than 384 characters"}];
return false;
}
}
else {
validate247.errors = [{instancePath:instancePath+"/message",schemaPath:"#/properties/message/type",keyword:"type",params:{type: "string"},message:"must be string"}];
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
if(!(validate258(data.cause, {instancePath:instancePath+"/cause",parentData:data,parentDataProperty:"cause",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate258.errors : vErrors.concat(validate258.errors);
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
if(!(validate260(data.identity, {instancePath:instancePath+"/identity",parentData:data,parentDataProperty:"identity",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate260.errors : vErrors.concat(validate260.errors);
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
if(!(validate273(data.location, {instancePath:instancePath+"/location",parentData:data,parentDataProperty:"location",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate273.errors : vErrors.concat(validate273.errors);
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
if(!(validate286(data.facts, {instancePath:instancePath+"/facts",parentData:data,parentDataProperty:"facts",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate286.errors : vErrors.concat(validate286.errors);
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
if(!(validate318(data.actions, {instancePath:instancePath+"/actions",parentData:data,parentDataProperty:"actions",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate318.errors : vErrors.concat(validate318.errors);
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
validate247.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate247.errors = vErrors;
return errors === 0;
}
validate247.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema108 = {"type":"object","additionalProperties":false,"required":["null"],"properties":{"null":{"type":"object","maxProperties":0}}};

function validate345(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate345.evaluated;
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
validate345.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(key0 === "null")){
validate345.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
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
validate345.errors = [{instancePath:instancePath+"/null",schemaPath:"#/properties/null/maxProperties",keyword:"maxProperties",params:{limit: 0},message:"must NOT have more than 0 properties"}];
return false;
}
}
else {
validate345.errors = [{instancePath:instancePath+"/null",schemaPath:"#/properties/null/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
}
}
}
}
else {
validate345.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate345.errors = vErrors;
return errors === 0;
}
validate345.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema109 = {"type":"object","additionalProperties":false,"required":["type_error"],"properties":{"type_error":{"$ref":"https://transit.invalid/generated-validator/87"}}};
const schema110 = {"type":"string","enum":["unknown","int64","uint64","float64","boolean","utf8","binary","null_value","map","list","text","character"]};

function validate348(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate348.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate348.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
if(!((((((((((((data === "unknown") || (data === "int64")) || (data === "uint64")) || (data === "float64")) || (data === "boolean")) || (data === "utf8")) || (data === "binary")) || (data === "null_value")) || (data === "map")) || (data === "list")) || (data === "text")) || (data === "character"))){
validate348.errors = [{instancePath,schemaPath:"#/enum",keyword:"enum",params:{allowedValues: schema110.enum},message:"must be equal to one of the allowed values"}];
return false;
}
validate348.errors = vErrors;
return errors === 0;
}
validate348.evaluated = {"dynamicProps":false,"dynamicItems":false};


function validate347(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate347.evaluated;
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
validate347.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(key0 === "type_error")){
validate347.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.type_error !== undefined){
if(!(validate348(data.type_error, {instancePath:instancePath+"/type_error",parentData:data,parentDataProperty:"type_error",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate348.errors : vErrors.concat(validate348.errors);
errors = vErrors.length;
}
}
}
}
}
else {
validate347.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate347.errors = vErrors;
return errors === 0;
}
validate347.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema111 = {"type":"object","additionalProperties":false,"required":["value"],"properties":{"value":{"$ref":"https://transit.invalid/generated-validator/8"}}};

function validate351(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate351.evaluated;
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
validate351.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(key0 === "value")){
validate351.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.value !== undefined){
if(!(validate58(data.value, {instancePath:instancePath+"/value",parentData:data,parentDataProperty:"value",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate58.errors : vErrors.concat(validate58.errors);
errors = vErrors.length;
}
}
}
}
}
else {
validate351.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate351.errors = vErrors;
return errors === 0;
}
validate351.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema112 = {"type":"object","additionalProperties":false,"properties":{"generation":{"type":"string","maxLength":131072},"limit":{"$ref":"https://transit.invalid/generated-validator/9"},"starts":{"$ref":"https://transit.invalid/generated-validator/9"},"enabled":{"type":"boolean"},"contract":{"$ref":"https://transit.invalid/generated-validator/34"},"budgets":{"$ref":"https://transit.invalid/generated-validator/32"},"namespaces":{"$ref":"https://transit.invalid/generated-validator/90"}},"required":["generation","limit","starts","enabled","contract","budgets","namespaces"]};
const schema113 = {"type":"array","minItems":8,"maxItems":8,"items":{"type":"string","maxLength":131072}};

function validate362(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate362.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(Array.isArray(data)){
if(data.length > 8){
validate362.errors = [{instancePath,schemaPath:"#/maxItems",keyword:"maxItems",params:{limit: 8},message:"must NOT have more than 8 items"}];
return false;
}
else {
if(data.length < 8){
validate362.errors = [{instancePath,schemaPath:"#/minItems",keyword:"minItems",params:{limit: 8},message:"must NOT have fewer than 8 items"}];
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
if(func1(data0) > 131072){
validate362.errors = [{instancePath:instancePath+"/" + i0,schemaPath:"#/items/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"}];
return false;
}
}
else {
validate362.errors = [{instancePath:instancePath+"/" + i0,schemaPath:"#/items/type",keyword:"type",params:{type: "string"},message:"must be string"}];
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
validate362.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "array"},message:"must be array"}];
return false;
}
}
validate362.errors = vErrors;
return errors === 0;
}
validate362.evaluated = {"items":true,"dynamicProps":false,"dynamicItems":false};


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
if((((((((data.generation === undefined) && (missing0 = "generation")) || ((data.limit === undefined) && (missing0 = "limit"))) || ((data.starts === undefined) && (missing0 = "starts"))) || ((data.enabled === undefined) && (missing0 = "enabled"))) || ((data.contract === undefined) && (missing0 = "contract"))) || ((data.budgets === undefined) && (missing0 = "budgets"))) || ((data.namespaces === undefined) && (missing0 = "namespaces"))){
validate357.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((((((key0 === "generation") || (key0 === "limit")) || (key0 === "starts")) || (key0 === "enabled")) || (key0 === "contract")) || (key0 === "budgets")) || (key0 === "namespaces"))){
validate357.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.generation !== undefined){
let data0 = data.generation;
const _errs2 = errors;
if(errors === _errs2){
if(typeof data0 === "string"){
if(func1(data0) > 131072){
validate357.errors = [{instancePath:instancePath+"/generation",schemaPath:"#/properties/generation/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"}];
return false;
}
}
else {
validate357.errors = [{instancePath:instancePath+"/generation",schemaPath:"#/properties/generation/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.limit !== undefined){
const _errs4 = errors;
if(!(validate72(data.limit, {instancePath:instancePath+"/limit",parentData:data,parentDataProperty:"limit",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate72.errors : vErrors.concat(validate72.errors);
errors = vErrors.length;
}
var valid0 = _errs4 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.starts !== undefined){
const _errs5 = errors;
if(!(validate72(data.starts, {instancePath:instancePath+"/starts",parentData:data,parentDataProperty:"starts",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate72.errors : vErrors.concat(validate72.errors);
errors = vErrors.length;
}
var valid0 = _errs5 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.enabled !== undefined){
const _errs6 = errors;
if(typeof data.enabled !== "boolean"){
validate357.errors = [{instancePath:instancePath+"/enabled",schemaPath:"#/properties/enabled/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"}];
return false;
}
var valid0 = _errs6 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.contract !== undefined){
const _errs8 = errors;
if(!(validate163(data.contract, {instancePath:instancePath+"/contract",parentData:data,parentDataProperty:"contract",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate163.errors : vErrors.concat(validate163.errors);
errors = vErrors.length;
}
var valid0 = _errs8 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.budgets !== undefined){
const _errs9 = errors;
if(!(validate148(data.budgets, {instancePath:instancePath+"/budgets",parentData:data,parentDataProperty:"budgets",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate148.errors : vErrors.concat(validate148.errors);
errors = vErrors.length;
}
var valid0 = _errs9 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.namespaces !== undefined){
const _errs10 = errors;
if(!(validate362(data.namespaces, {instancePath:instancePath+"/namespaces",parentData:data,parentDataProperty:"namespaces",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate362.errors : vErrors.concat(validate362.errors);
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
else {
validate357.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate357.errors = vErrors;
return errors === 0;
}
validate357.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate81(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate81.evaluated;
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
if(!(validate78(data1.realm, {instancePath:instancePath+"/description/connection/realm",parentData:data1,parentDataProperty:"realm",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate78.errors : vErrors.concat(validate78.errors);
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
if(!(validate78(data1.principal, {instancePath:instancePath+"/description/connection/principal",parentData:data1,parentDataProperty:"principal",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate78.errors : vErrors.concat(validate78.errors);
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
if(!(validate78(data1.source, {instancePath:instancePath+"/description/connection/source",parentData:data1,parentDataProperty:"source",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate78.errors : vErrors.concat(validate78.errors);
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
if(!(validate78(data1.resource, {instancePath:instancePath+"/description/connection/resource",parentData:data1,parentDataProperty:"resource",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate78.errors : vErrors.concat(validate78.errors);
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
if(!(validate78(data1.requester, {instancePath:instancePath+"/description/connection/requester",parentData:data1,parentDataProperty:"requester",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate78.errors : vErrors.concat(validate78.errors);
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
if(!(validate78(data1.requests, {instancePath:instancePath+"/description/connection/requests",parentData:data1,parentDataProperty:"requests",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate78.errors : vErrors.concat(validate78.errors);
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
if(func1(data8) > 131072){
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
if(!(func23.call(schema34.oneOf[0].properties.description.properties.source.properties.capabilities.properties, key4))){
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
if(!(validate72(data10.version, {instancePath:instancePath+"/description/source/capabilities/version",parentData:data10,parentDataProperty:"version",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate72.errors : vErrors.concat(validate72.errors);
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
if(!(validate72(data10.source, {instancePath:instancePath+"/description/source/capabilities/source",parentData:data10,parentDataProperty:"source",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate72.errors : vErrors.concat(validate72.errors);
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
if(!(validate72(data10.plan, {instancePath:instancePath+"/description/source/capabilities/plan",parentData:data10,parentDataProperty:"plan",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate72.errors : vErrors.concat(validate72.errors);
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
if(!(validate72(data10.result, {instancePath:instancePath+"/description/source/capabilities/result",parentData:data10,parentDataProperty:"result",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate72.errors : vErrors.concat(validate72.errors);
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
if(!(validate56(data10.bundle_bytes, {instancePath:instancePath+"/description/source/capabilities/bundle_bytes",parentData:data10,parentDataProperty:"bundle_bytes",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
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
if(!(validate54(data10.part_bytes, {instancePath:instancePath+"/description/source/capabilities/part_bytes",parentData:data10,parentDataProperty:"part_bytes",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate54.errors : vErrors.concat(validate54.errors);
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
if(!(validate56(data10.segment_bytes, {instancePath:instancePath+"/description/source/capabilities/segment_bytes",parentData:data10,parentDataProperty:"segment_bytes",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
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
if(!(validate72(data10.batch_rows, {instancePath:instancePath+"/description/source/capabilities/batch_rows",parentData:data10,parentDataProperty:"batch_rows",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate72.errors : vErrors.concat(validate72.errors);
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
if(!(validate72(data10.columns, {instancePath:instancePath+"/description/source/capabilities/columns",parentData:data10,parentDataProperty:"columns",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate72.errors : vErrors.concat(validate72.errors);
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
if(!(validate97(data9.source, {instancePath:instancePath+"/description/source/source",parentData:data9,parentDataProperty:"source",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate97.errors : vErrors.concat(validate97.errors);
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
if(!(validate78(data9.resource_revision, {instancePath:instancePath+"/description/source/resource_revision",parentData:data9,parentDataProperty:"resource_revision",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate78.errors : vErrors.concat(validate78.errors);
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
if(func1(data25) > 131072){
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
if(!(validate148(data9.limits, {instancePath:instancePath+"/description/source/limits",parentData:data9,parentDataProperty:"limits",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate148.errors : vErrors.concat(validate148.errors);
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
if(!(validate74(data9.active, {instancePath:instancePath+"/description/source/active",parentData:data9,parentDataProperty:"active",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate74.errors : vErrors.concat(validate74.errors);
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
if(!(func23.call(schema34.oneOf[0].properties.description.properties.sql.properties, key5))){
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
if(!(validate72(data28.version, {instancePath:instancePath+"/description/sql/version",parentData:data28,parentDataProperty:"version",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate72.errors : vErrors.concat(validate72.errors);
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
if(!(validate56(data28.statement_bytes, {instancePath:instancePath+"/description/sql/statement_bytes",parentData:data28,parentDataProperty:"statement_bytes",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
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
if(!(validate72(data28.named_columns, {instancePath:instancePath+"/description/sql/named_columns",parentData:data28,parentDataProperty:"named_columns",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate72.errors : vErrors.concat(validate72.errors);
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
if(!(validate72(data28.star_columns, {instancePath:instancePath+"/description/sql/star_columns",parentData:data28,parentDataProperty:"star_columns",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate72.errors : vErrors.concat(validate72.errors);
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
if(!(validate148(data0.budgets, {instancePath:instancePath+"/description/budgets",parentData:data0,parentDataProperty:"budgets",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate148.errors : vErrors.concat(validate148.errors);
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
if(!(validate156(data0.columns, {instancePath:instancePath+"/description/columns",parentData:data0,parentDataProperty:"columns",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate156.errors : vErrors.concat(validate156.errors);
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
if(!(validate72(data42.version, {instancePath:instancePath+"/sql_capabilities/version",parentData:data42,parentDataProperty:"version",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate72.errors : vErrors.concat(validate72.errors);
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
if(!(validate72(data42.max_parameters, {instancePath:instancePath+"/sql_capabilities/max_parameters",parentData:data42,parentDataProperty:"max_parameters",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate72.errors : vErrors.concat(validate72.errors);
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
if(!(validate56(data42.statement_bytes, {instancePath:instancePath+"/sql_capabilities/statement_bytes",parentData:data42,parentDataProperty:"statement_bytes",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
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
if(!(validate78(data47.resource, {instancePath:instancePath+"/suggestions/resource",parentData:data47,parentDataProperty:"resource",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate78.errors : vErrors.concat(validate78.errors);
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
if(!(validate163(data47.contract, {instancePath:instancePath+"/suggestions/contract",parentData:data47,parentDataProperty:"contract",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate163.errors : vErrors.concat(validate163.errors);
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
if(func1(data52) > 131072){
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
if(func1(data53) > 131072){
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
if(!(func23.call(schema34.oneOf[3].properties.assistance.properties, key12))){
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
if(!(validate72(data54.version, {instancePath:instancePath+"/assistance/version",parentData:data54,parentDataProperty:"version",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate72.errors : vErrors.concat(validate72.errors);
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
if(!(validate56(data54.generation, {instancePath:instancePath+"/assistance/generation",parentData:data54,parentDataProperty:"generation",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
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
if(!(data57 === "unified_v1")){
const err59 = {instancePath:instancePath+"/assistance/profile",schemaPath:"#/oneOf/3/properties/assistance/properties/profile/enum",keyword:"enum",params:{allowedValues: schema34.oneOf[3].properties.assistance.properties.profile.enum},message:"must be equal to one of the allowed values"};
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
if(!(validate78(data54.resource, {instancePath:instancePath+"/assistance/resource",parentData:data54,parentDataProperty:"resource",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate78.errors : vErrors.concat(validate78.errors);
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
if(!(validate163(data54.contract, {instancePath:instancePath+"/assistance/contract",parentData:data54,parentDataProperty:"contract",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate163.errors : vErrors.concat(validate163.errors);
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
if(!(validate78(data54.resource_revision, {instancePath:instancePath+"/assistance/resource_revision",parentData:data54,parentDataProperty:"resource_revision",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate78.errors : vErrors.concat(validate78.errors);
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
if(func1(data61) > 131072){
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
if(!(validate54(data62.start, {instancePath:instancePath+"/assistance/range/start",parentData:data62,parentDataProperty:"start",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate54.errors : vErrors.concat(validate54.errors);
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
if(!(validate54(data62.end, {instancePath:instancePath+"/assistance/range/end",parentData:data62,parentDataProperty:"end",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate54.errors : vErrors.concat(validate54.errors);
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
if(func1(data68) > 131072){
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
const err74 = {instancePath:instancePath+"/assistance/items/" + i1+"/kind",schemaPath:"#/oneOf/3/properties/assistance/properties/items/items/properties/kind/enum",keyword:"enum",params:{allowedValues: schema34.oneOf[3].properties.assistance.properties.items.items.properties.kind.enum},message:"must be equal to one of the allowed values"};
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
if(func1(data70) > 131072){
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
if(func1(data72) > 131072){
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
if(!(validate97(data71.source, {instancePath:instancePath+"/compiled/source",parentData:data71,parentDataProperty:"source",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate97.errors : vErrors.concat(validate97.errors);
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
if(!(validate72(data74.version, {instancePath:instancePath+"/compiled/plan/version",parentData:data74,parentDataProperty:"version",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate72.errors : vErrors.concat(validate72.errors);
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
if(!(validate56(data76[i2], {instancePath:instancePath+"/compiled/plan/projection/" + i2,parentData:data76,parentDataProperty:i2,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate56.errors : vErrors.concat(validate56.errors);
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
if(!(validate74(data78[i3], {instancePath:instancePath+"/compiled/plan/output_names/" + i3,parentData:data78,parentDataProperty:i3,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate74.errors : vErrors.concat(validate74.errors);
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
if(!(validate74(data74.limit, {instancePath:instancePath+"/compiled/plan/limit",parentData:data74,parentDataProperty:"limit",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate74.errors : vErrors.concat(validate74.errors);
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
if(!(validate178(data74.aggregate, {instancePath:instancePath+"/compiled/plan/aggregate",parentData:data74,parentDataProperty:"aggregate",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate178.errors : vErrors.concat(validate178.errors);
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
if(!(validate180(data82, {instancePath:instancePath+"/compiled/plan/predicate",parentData:data74,parentDataProperty:"predicate",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate180.errors : vErrors.concat(validate180.errors);
errors = vErrors.length;
}
var _valid3 = _errs160 === errors;
if(_valid3){
valid25 = true;
passing1 = 0;
var props2 = true;
}
const _errs161 = errors;
if(!(validate182(data82, {instancePath:instancePath+"/compiled/plan/predicate",parentData:data74,parentDataProperty:"predicate",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate182.errors : vErrors.concat(validate182.errors);
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
if(!(validate189(data82, {instancePath:instancePath+"/compiled/plan/predicate",parentData:data74,parentDataProperty:"predicate",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate189.errors : vErrors.concat(validate189.errors);
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
if(!(validate180(data85, {instancePath:instancePath+"/compiled/plan/predicate/program/" + i4+"/atom",parentData:data84,parentDataProperty:"atom",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate180.errors : vErrors.concat(validate180.errors);
errors = vErrors.length;
}
var _valid5 = _errs175 === errors;
if(_valid5){
valid30 = true;
passing3 = 0;
var props3 = true;
}
const _errs176 = errors;
if(!(validate182(data85, {instancePath:instancePath+"/compiled/plan/predicate/program/" + i4+"/atom",parentData:data84,parentDataProperty:"atom",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate182.errors : vErrors.concat(validate182.errors);
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
if(!(validate189(data85, {instancePath:instancePath+"/compiled/plan/predicate/program/" + i4+"/atom",parentData:data84,parentDataProperty:"atom",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate189.errors : vErrors.concat(validate189.errors);
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
if(!(validate200(data84, {instancePath:instancePath+"/compiled/plan/predicate/program/" + i4,parentData:data83,parentDataProperty:i4,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate200.errors : vErrors.concat(validate200.errors);
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
if(!(validate202(data84, {instancePath:instancePath+"/compiled/plan/predicate/program/" + i4,parentData:data83,parentDataProperty:i4,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate202.errors : vErrors.concat(validate202.errors);
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
if(!(validate204(data84, {instancePath:instancePath+"/compiled/plan/predicate/program/" + i4,parentData:data83,parentDataProperty:i4,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate204.errors : vErrors.concat(validate204.errors);
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
if(!(validate148(data71.limits, {instancePath:instancePath+"/compiled/limits",parentData:data71,parentDataProperty:"limits",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate148.errors : vErrors.concat(validate148.errors);
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
if(!(validate163(data71.contract, {instancePath:instancePath+"/compiled/contract",parentData:data71,parentDataProperty:"contract",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate163.errors : vErrors.concat(validate163.errors);
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
if(!(validate163(data71.schema, {instancePath:instancePath+"/compiled/schema",parentData:data71,parentDataProperty:"schema",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate163.errors : vErrors.concat(validate163.errors);
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
if(!(func23.call(schema34.oneOf[5].properties.inspection.properties, key21))){
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
if(!(validate72(data89.version, {instancePath:instancePath+"/inspection/version",parentData:data89,parentDataProperty:"version",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate72.errors : vErrors.concat(validate72.errors);
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
const err114 = {instancePath:instancePath+"/inspection/scope",schemaPath:"#/oneOf/5/properties/inspection/properties/scope/enum",keyword:"enum",params:{allowedValues: schema34.oneOf[5].properties.inspection.properties.scope.enum},message:"must be equal to one of the allowed values"};
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
if(func1(data92) > 131072){
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
if(!(validate78(data89.resource, {instancePath:instancePath+"/inspection/resource",parentData:data89,parentDataProperty:"resource",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate78.errors : vErrors.concat(validate78.errors);
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
if(!(validate211(data89.source_kind, {instancePath:instancePath+"/inspection/source_kind",parentData:data89,parentDataProperty:"source_kind",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate211.errors : vErrors.concat(validate211.errors);
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
if(!(validate163(data89.contract, {instancePath:instancePath+"/inspection/contract",parentData:data89,parentDataProperty:"contract",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate163.errors : vErrors.concat(validate163.errors);
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
if(!(validate163(data89.schema, {instancePath:instancePath+"/inspection/schema",parentData:data89,parentDataProperty:"schema",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate163.errors : vErrors.concat(validate163.errors);
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
if(!(validate78(data89.resource_revision, {instancePath:instancePath+"/inspection/resource_revision",parentData:data89,parentDataProperty:"resource_revision",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate78.errors : vErrors.concat(validate78.errors);
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
if(func1(data98) > 131072){
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
if(!(validate156(data100.columns, {instancePath:instancePath+"/inspection/details/description/columns",parentData:data100,parentDataProperty:"columns",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate156.errors : vErrors.concat(validate156.errors);
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
if(!(validate128(data99.tables, {instancePath:instancePath+"/inspection/details/tables",parentData:data99,parentDataProperty:"tables",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate128.errors : vErrors.concat(validate128.errors);
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
const err134 = {instancePath:instancePath+"/inspection/details/explanation/operators/" + i5,schemaPath:"#/oneOf/5/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/operators/items/enum",keyword:"enum",params:{allowedValues: schema34.oneOf[5].properties.inspection.properties.details.oneOf[2].properties.explanation.properties.operators.items.enum},message:"must be equal to one of the allowed values"};
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
if(!(validate180(data106, {instancePath:instancePath+"/inspection/details/explanation/predicate",parentData:data103,parentDataProperty:"predicate",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate180.errors : vErrors.concat(validate180.errors);
errors = vErrors.length;
}
var _valid7 = _errs227 === errors;
if(_valid7){
valid40 = true;
passing5 = 0;
var props6 = true;
}
const _errs228 = errors;
if(!(validate219(data106, {instancePath:instancePath+"/inspection/details/explanation/predicate",parentData:data103,parentDataProperty:"predicate",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate219.errors : vErrors.concat(validate219.errors);
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
if(!(validate224(data106, {instancePath:instancePath+"/inspection/details/explanation/predicate",parentData:data103,parentDataProperty:"predicate",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate224.errors : vErrors.concat(validate224.errors);
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
if(!(validate180(data109, {instancePath:instancePath+"/inspection/details/explanation/predicate/program/" + i6+"/atom",parentData:data108,parentDataProperty:"atom",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate180.errors : vErrors.concat(validate180.errors);
errors = vErrors.length;
}
var _valid9 = _errs242 === errors;
if(_valid9){
valid45 = true;
passing7 = 0;
var props7 = true;
}
const _errs243 = errors;
if(!(validate219(data109, {instancePath:instancePath+"/inspection/details/explanation/predicate/program/" + i6+"/atom",parentData:data108,parentDataProperty:"atom",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate219.errors : vErrors.concat(validate219.errors);
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
if(!(validate224(data109, {instancePath:instancePath+"/inspection/details/explanation/predicate/program/" + i6+"/atom",parentData:data108,parentDataProperty:"atom",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate224.errors : vErrors.concat(validate224.errors);
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
if(!(validate200(data108, {instancePath:instancePath+"/inspection/details/explanation/predicate/program/" + i6,parentData:data107,parentDataProperty:i6,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate200.errors : vErrors.concat(validate200.errors);
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
if(!(validate202(data108, {instancePath:instancePath+"/inspection/details/explanation/predicate/program/" + i6,parentData:data107,parentDataProperty:i6,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate202.errors : vErrors.concat(validate202.errors);
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
if(!(validate204(data108, {instancePath:instancePath+"/inspection/details/explanation/predicate/program/" + i6,parentData:data107,parentDataProperty:i6,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate204.errors : vErrors.concat(validate204.errors);
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
if(!(validate128(data103.projection, {instancePath:instancePath+"/inspection/details/explanation/projection",parentData:data103,parentDataProperty:"projection",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate128.errors : vErrors.concat(validate128.errors);
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
if(!(validate74(data103.limit, {instancePath:instancePath+"/inspection/details/explanation/limit",parentData:data103,parentDataProperty:"limit",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate74.errors : vErrors.concat(validate74.errors);
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
if(!(validate178(data103.aggregate, {instancePath:instancePath+"/inspection/details/explanation/aggregate",parentData:data103,parentDataProperty:"aggregate",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate178.errors : vErrors.concat(validate178.errors);
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
if(!(validate156(data103.columns, {instancePath:instancePath+"/inspection/details/explanation/columns",parentData:data103,parentDataProperty:"columns",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate156.errors : vErrors.concat(validate156.errors);
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
if(!(validate148(data103.budgets, {instancePath:instancePath+"/inspection/details/explanation/budgets",parentData:data103,parentDataProperty:"budgets",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate148.errors : vErrors.concat(validate148.errors);
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
if(!(validate76(data115, {instancePath:instancePath+"/prepared",parentData:data,parentDataProperty:"prepared",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate76.errors : vErrors.concat(validate76.errors);
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
if(!(validate78(data116.position, {instancePath:instancePath+"/receipt/position",parentData:data116,parentDataProperty:"position",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate78.errors : vErrors.concat(validate78.errors);
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
if(!(validate243(data118.rejected, {instancePath:instancePath+"/observation/rejected",parentData:data118,parentDataProperty:"rejected",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate243.errors : vErrors.concat(validate243.errors);
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
if(!(validate243(data122.reference, {instancePath:instancePath+"/status/reference",parentData:data122,parentDataProperty:"reference",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate243.errors : vErrors.concat(validate243.errors);
errors = vErrors.length;
}
var valid57 = _errs295 === errors;
}
else {
var valid57 = true;
}
if(valid57){
if(data122.phase !== undefined){
let data124 = data122.phase;
const _errs296 = errors;
if(typeof data124 !== "string"){
const err184 = {instancePath:instancePath+"/status/phase",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/phase/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err184];
}
else {
vErrors.push(err184);
}
errors++;
}
if(!((((((((data124 === "uploading") || (data124 === "sealed")) || (data124 === "admitted")) || (data124 === "complete")) || (data124 === "cancelled")) || (data124 === "denied")) || (data124 === "rejected")) || (data124 === "retired"))){
const err185 = {instancePath:instancePath+"/status/phase",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/phase/enum",keyword:"enum",params:{allowedValues: schema34.oneOf[9].properties.status.anyOf[0].properties.phase.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err185];
}
else {
vErrors.push(err185);
}
errors++;
}
var valid57 = _errs296 === errors;
}
else {
var valid57 = true;
}
if(valid57){
if(data122.correlation !== undefined){
let data125 = data122.correlation;
const _errs298 = errors;
if(errors === _errs298){
if(typeof data125 === "string"){
if(func1(data125) > 131072){
const err186 = {instancePath:instancePath+"/status/correlation",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/correlation/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err186];
}
else {
vErrors.push(err186);
}
errors++;
}
}
else {
const err187 = {instancePath:instancePath+"/status/correlation",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/correlation/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err187];
}
else {
vErrors.push(err187);
}
errors++;
}
}
var valid57 = _errs298 === errors;
}
else {
var valid57 = true;
}
if(valid57){
if(data122.manifest !== undefined){
let data126 = data122.manifest;
const _errs300 = errors;
const _errs301 = errors;
let valid58 = false;
const _errs302 = errors;
if(!(validate243(data126, {instancePath:instancePath+"/status/manifest",parentData:data122,parentDataProperty:"manifest",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate243.errors : vErrors.concat(validate243.errors);
errors = vErrors.length;
}
var _valid13 = _errs302 === errors;
valid58 = valid58 || _valid13;
const _errs303 = errors;
if(data126 !== null){
const err188 = {instancePath:instancePath+"/status/manifest",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/manifest/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err188];
}
else {
vErrors.push(err188);
}
errors++;
}
var _valid13 = _errs303 === errors;
valid58 = valid58 || _valid13;
if(!valid58){
const err189 = {instancePath:instancePath+"/status/manifest",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/manifest/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err189];
}
else {
vErrors.push(err189);
}
errors++;
}
else {
errors = _errs301;
if(vErrors !== null){
if(_errs301){
vErrors.length = _errs301;
}
else {
vErrors = null;
}
}
}
var valid57 = _errs300 === errors;
}
else {
var valid57 = true;
}
if(valid57){
if(data122.collected !== undefined){
const _errs305 = errors;
if(typeof data122.collected !== "boolean"){
const err190 = {instancePath:instancePath+"/status/collected",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/collected/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"};
if(vErrors === null){
vErrors = [err190];
}
else {
vErrors.push(err190);
}
errors++;
}
var valid57 = _errs305 === errors;
}
else {
var valid57 = true;
}
if(valid57){
if(data122.failure !== undefined){
let data128 = data122.failure;
const _errs307 = errors;
const _errs308 = errors;
let valid59 = false;
const _errs309 = errors;
if(errors === _errs309){
if(data128 && typeof data128 == "object" && !Array.isArray(data128)){
let missing38;
if((((((data128.code === undefined) && (missing38 = "code")) || ((data128.stage === undefined) && (missing38 = "stage"))) || ((data128.dimension === undefined) && (missing38 = "dimension"))) || ((data128.limit === undefined) && (missing38 = "limit"))) || ((data128.observed === undefined) && (missing38 = "observed"))){
const err191 = {instancePath:instancePath+"/status/failure",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/failure/anyOf/0/required",keyword:"required",params:{missingProperty: missing38},message:"must have required property '"+missing38+"'"};
if(vErrors === null){
vErrors = [err191];
}
else {
vErrors.push(err191);
}
errors++;
}
else {
const _errs311 = errors;
for(const key38 in data128){
if(!(((((key38 === "code") || (key38 === "stage")) || (key38 === "dimension")) || (key38 === "limit")) || (key38 === "observed"))){
const err192 = {instancePath:instancePath+"/status/failure",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/failure/anyOf/0/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key38},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err192];
}
else {
vErrors.push(err192);
}
errors++;
break;
}
}
if(_errs311 === errors){
if(data128.code !== undefined){
let data129 = data128.code;
const _errs312 = errors;
if(typeof data129 !== "string"){
const err193 = {instancePath:instancePath+"/status/failure/code",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/failure/anyOf/0/properties/code/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err193];
}
else {
vErrors.push(err193);
}
errors++;
}
if(!((((((((((((((((((((((((((((((((((((((((((((((((((((((((((data129 === "policy_denied") || (data129 === "access_denied")) || (data129 === "resource_unavailable")) || (data129 === "request_unpublished")) || (data129 === "publisher_mismatch")) || (data129 === "document_history_gap")) || (data129 === "document_retired")) || (data129 === "document_resync_required")) || (data129 === "budget_exceeded")) || (data129 === "projection_budget")) || (data129 === "expansion_missing")) || (data129 === "expansion_null")) || (data129 === "expansion_conflict")) || (data129 === "expansion_type_error")) || (data129 === "cell_type_error")) || (data129 === "cell_conflict")) || (data129 === "arithmetic_overflow")) || (data129 === "segment_byte_limit")) || (data129 === "type_mismatch")) || (data129 === "unsupported_aggregate")) || (data129 === "unknown_column")) || (data129 === "invalid_projection")) || (data129 === "duplicate_projection")) || (data129 === "invalid_bundle")) || (data129 === "invalid_source")) || (data129 === "invalid_prefix")) || (data129 === "invalid_path")) || (data129 === "invalid_projection_budget")) || (data129 === "invalid_text_projection")) || (data129 === "invalid_element_projection")) || (data129 === "unsupported_source")) || (data129 === "unsupported_decoder")) || (data129 === "unsupported_document_source")) || (data129 === "invalid_source_encoding")) || (data129 === "invalid_plan_encoding")) || (data129 === "plan_definition_mismatch")) || (data129 === "invalid_output_names")) || (data129 === "unsupported_plan")) || (data129 === "plan_too_large")) || (data129 === "bundle_too_large")) || (data129 === "truncated_input")) || (data129 === "source_changed")) || (data129 === "table_schema_changed")) || (data129 === "invalid_budget")) || (data129 === "namespace_in_use")) || (data129 === "query_after_mutation")) || (data129 === "nonfinite_value")) || (data129 === "invalid_utf8")) || (data129 === "cell_too_large")) || (data129 === "invalid_column_name")) || (data129 === "invalid_column_count")) || (data129 === "duplicate_column")) || (data129 === "unsupported_schema")) || (data129 === "peer_mismatch")) || (data129 === "invalid_request_reference")) || (data129 === "writer_not_ready")) || (data129 === "request_resource_expired")) || (data129 === "request_resource_missing"))){
const err194 = {instancePath:instancePath+"/status/failure/code",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/failure/anyOf/0/properties/code/enum",keyword:"enum",params:{allowedValues: schema34.oneOf[9].properties.status.anyOf[0].properties.failure.anyOf[0].properties.code.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err194];
}
else {
vErrors.push(err194);
}
errors++;
}
var valid60 = _errs312 === errors;
}
else {
var valid60 = true;
}
if(valid60){
if(data128.stage !== undefined){
let data130 = data128.stage;
const _errs314 = errors;
if(typeof data130 !== "string"){
const err195 = {instancePath:instancePath+"/status/failure/stage",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/failure/anyOf/0/properties/stage/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err195];
}
else {
vErrors.push(err195);
}
errors++;
}
if(!((data130 === "admission") || (data130 === "execution"))){
const err196 = {instancePath:instancePath+"/status/failure/stage",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/failure/anyOf/0/properties/stage/enum",keyword:"enum",params:{allowedValues: schema34.oneOf[9].properties.status.anyOf[0].properties.failure.anyOf[0].properties.stage.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err196];
}
else {
vErrors.push(err196);
}
errors++;
}
var valid60 = _errs314 === errors;
}
else {
var valid60 = true;
}
if(valid60){
if(data128.dimension !== undefined){
let data131 = data128.dimension;
const _errs316 = errors;
if(typeof data131 !== "string"){
const err197 = {instancePath:instancePath+"/status/failure/dimension",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/failure/anyOf/0/properties/dimension/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err197];
}
else {
vErrors.push(err197);
}
errors++;
}
if(!((((data131 === "none") || (data131 === "pages")) || (data131 === "segments")) || (data131 === "result_bytes"))){
const err198 = {instancePath:instancePath+"/status/failure/dimension",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/failure/anyOf/0/properties/dimension/enum",keyword:"enum",params:{allowedValues: schema34.oneOf[9].properties.status.anyOf[0].properties.failure.anyOf[0].properties.dimension.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err198];
}
else {
vErrors.push(err198);
}
errors++;
}
var valid60 = _errs316 === errors;
}
else {
var valid60 = true;
}
if(valid60){
if(data128.limit !== undefined){
let data132 = data128.limit;
const _errs318 = errors;
if(errors === _errs318){
if(typeof data132 === "string"){
if(func1(data132) > 131072){
const err199 = {instancePath:instancePath+"/status/failure/limit",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/failure/anyOf/0/properties/limit/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err199];
}
else {
vErrors.push(err199);
}
errors++;
}
}
else {
const err200 = {instancePath:instancePath+"/status/failure/limit",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/failure/anyOf/0/properties/limit/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err200];
}
else {
vErrors.push(err200);
}
errors++;
}
}
var valid60 = _errs318 === errors;
}
else {
var valid60 = true;
}
if(valid60){
if(data128.observed !== undefined){
let data133 = data128.observed;
const _errs320 = errors;
if(errors === _errs320){
if(typeof data133 === "string"){
if(func1(data133) > 131072){
const err201 = {instancePath:instancePath+"/status/failure/observed",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/failure/anyOf/0/properties/observed/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err201];
}
else {
vErrors.push(err201);
}
errors++;
}
}
else {
const err202 = {instancePath:instancePath+"/status/failure/observed",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/failure/anyOf/0/properties/observed/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err202];
}
else {
vErrors.push(err202);
}
errors++;
}
}
var valid60 = _errs320 === errors;
}
else {
var valid60 = true;
}
}
}
}
}
}
}
}
else {
const err203 = {instancePath:instancePath+"/status/failure",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/failure/anyOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err203];
}
else {
vErrors.push(err203);
}
errors++;
}
}
var _valid14 = _errs309 === errors;
valid59 = valid59 || _valid14;
const _errs322 = errors;
if(data128 !== null){
const err204 = {instancePath:instancePath+"/status/failure",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/failure/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err204];
}
else {
vErrors.push(err204);
}
errors++;
}
var _valid14 = _errs322 === errors;
valid59 = valid59 || _valid14;
if(!valid59){
const err205 = {instancePath:instancePath+"/status/failure",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/failure/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err205];
}
else {
vErrors.push(err205);
}
errors++;
}
else {
errors = _errs308;
if(vErrors !== null){
if(_errs308){
vErrors.length = _errs308;
}
else {
vErrors = null;
}
}
}
var valid57 = _errs307 === errors;
}
else {
var valid57 = true;
}
if(valid57){
if(data122.diagnostic !== undefined){
let data134 = data122.diagnostic;
const _errs324 = errors;
const _errs325 = errors;
let valid61 = false;
const _errs326 = errors;
if(!(validate247(data134, {instancePath:instancePath+"/status/diagnostic",parentData:data122,parentDataProperty:"diagnostic",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate247.errors : vErrors.concat(validate247.errors);
errors = vErrors.length;
}
var _valid15 = _errs326 === errors;
valid61 = valid61 || _valid15;
const _errs327 = errors;
if(data134 !== null){
const err206 = {instancePath:instancePath+"/status/diagnostic",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/diagnostic/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err206];
}
else {
vErrors.push(err206);
}
errors++;
}
var _valid15 = _errs327 === errors;
valid61 = valid61 || _valid15;
if(!valid61){
const err207 = {instancePath:instancePath+"/status/diagnostic",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/diagnostic/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err207];
}
else {
vErrors.push(err207);
}
errors++;
}
else {
errors = _errs325;
if(vErrors !== null){
if(_errs325){
vErrors.length = _errs325;
}
else {
vErrors = null;
}
}
}
var valid57 = _errs324 === errors;
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
const err208 = {instancePath:instancePath+"/status",schemaPath:"#/oneOf/9/properties/status/anyOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err208];
}
else {
vErrors.push(err208);
}
errors++;
}
}
var _valid12 = _errs292 === errors;
valid56 = valid56 || _valid12;
const _errs329 = errors;
if(data122 !== null){
const err209 = {instancePath:instancePath+"/status",schemaPath:"#/oneOf/9/properties/status/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err209];
}
else {
vErrors.push(err209);
}
errors++;
}
var _valid12 = _errs329 === errors;
valid56 = valid56 || _valid12;
if(!valid56){
const err210 = {instancePath:instancePath+"/status",schemaPath:"#/oneOf/9/properties/status/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err210];
}
else {
vErrors.push(err210);
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
const err211 = {instancePath,schemaPath:"#/oneOf/9/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err211];
}
else {
vErrors.push(err211);
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
const _errs331 = errors;
if(errors === _errs331){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing39;
if((data.page === undefined) && (missing39 = "page")){
const err212 = {instancePath,schemaPath:"#/oneOf/10/required",keyword:"required",params:{missingProperty: missing39},message:"must have required property '"+missing39+"'"};
if(vErrors === null){
vErrors = [err212];
}
else {
vErrors.push(err212);
}
errors++;
}
else {
const _errs333 = errors;
for(const key39 in data){
if(!(key39 === "page")){
const err213 = {instancePath,schemaPath:"#/oneOf/10/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key39},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err213];
}
else {
vErrors.push(err213);
}
errors++;
break;
}
}
if(_errs333 === errors){
if(data.page !== undefined){
let data135 = data.page;
const _errs334 = errors;
if(errors === _errs334){
if(data135 && typeof data135 == "object" && !Array.isArray(data135)){
let missing40;
if(((data135.evidence === undefined) && (missing40 = "evidence")) || ((data135.cells === undefined) && (missing40 = "cells"))){
const err214 = {instancePath:instancePath+"/page",schemaPath:"#/oneOf/10/properties/page/required",keyword:"required",params:{missingProperty: missing40},message:"must have required property '"+missing40+"'"};
if(vErrors === null){
vErrors = [err214];
}
else {
vErrors.push(err214);
}
errors++;
}
else {
const _errs336 = errors;
for(const key40 in data135){
if(!((key40 === "evidence") || (key40 === "cells"))){
const err215 = {instancePath:instancePath+"/page",schemaPath:"#/oneOf/10/properties/page/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key40},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err215];
}
else {
vErrors.push(err215);
}
errors++;
break;
}
}
if(_errs336 === errors){
if(data135.evidence !== undefined){
let data136 = data135.evidence;
const _errs337 = errors;
if(errors === _errs337){
if(data136 && typeof data136 == "object" && !Array.isArray(data136)){
let missing41;
if(((((((data136.manifest === undefined) && (missing41 = "manifest")) || ((data136.columns === undefined) && (missing41 = "columns"))) || ((data136.ordinal === undefined) && (missing41 = "ordinal"))) || ((data136.rows === undefined) && (missing41 = "rows"))) || ((data136.ipc === undefined) && (missing41 = "ipc"))) || ((data136.next === undefined) && (missing41 = "next"))){
const err216 = {instancePath:instancePath+"/page/evidence",schemaPath:"#/oneOf/10/properties/page/properties/evidence/required",keyword:"required",params:{missingProperty: missing41},message:"must have required property '"+missing41+"'"};
if(vErrors === null){
vErrors = [err216];
}
else {
vErrors.push(err216);
}
errors++;
}
else {
const _errs339 = errors;
for(const key41 in data136){
if(!((((((key41 === "manifest") || (key41 === "columns")) || (key41 === "ordinal")) || (key41 === "rows")) || (key41 === "ipc")) || (key41 === "next"))){
const err217 = {instancePath:instancePath+"/page/evidence",schemaPath:"#/oneOf/10/properties/page/properties/evidence/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key41},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err217];
}
else {
vErrors.push(err217);
}
errors++;
break;
}
}
if(_errs339 === errors){
if(data136.manifest !== undefined){
let data137 = data136.manifest;
const _errs340 = errors;
if(errors === _errs340){
if(data137 && typeof data137 == "object" && !Array.isArray(data137)){
let missing42;
if(((((((((((((((((((data137.job === undefined) && (missing42 = "job")) || ((data137.source === undefined) && (missing42 = "source"))) || ((data137.requester === undefined) && (missing42 = "requester"))) || ((data137.correlation === undefined) && (missing42 = "correlation"))) || ((data137.policy_revision === undefined) && (missing42 = "policy_revision"))) || ((data137.request === undefined) && (missing42 = "request"))) || ((data137.basis === undefined) && (missing42 = "basis"))) || ((data137.plan === undefined) && (missing42 = "plan"))) || ((data137.pages === undefined) && (missing42 = "pages"))) || ((data137.scanned === undefined) && (missing42 = "scanned"))) || ((data137.selected === undefined) && (missing42 = "selected"))) || ((data137.value_count === undefined) && (missing42 = "value_count"))) || ((data137.segments === undefined) && (missing42 = "segments"))) || ((data137.rows === undefined) && (missing42 = "rows"))) || ((data137.bytes === undefined) && (missing42 = "bytes"))) || ((data137.sum === undefined) && (missing42 = "sum"))) || ((data137.finished === undefined) && (missing42 = "finished"))) || ((data137.chain === undefined) && (missing42 = "chain"))){
const err218 = {instancePath:instancePath+"/page/evidence/manifest",schemaPath:"#/oneOf/10/properties/page/properties/evidence/properties/manifest/required",keyword:"required",params:{missingProperty: missing42},message:"must have required property '"+missing42+"'"};
if(vErrors === null){
vErrors = [err218];
}
else {
vErrors.push(err218);
}
errors++;
}
else {
const _errs342 = errors;
for(const key42 in data137){
if(!(func23.call(schema34.oneOf[10].properties.page.properties.evidence.properties.manifest.properties, key42))){
const err219 = {instancePath:instancePath+"/page/evidence/manifest",schemaPath:"#/oneOf/10/properties/page/properties/evidence/properties/manifest/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key42},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err219];
}
else {
vErrors.push(err219);
}
errors++;
break;
}
}
if(_errs342 === errors){
if(data137.job !== undefined){
const _errs343 = errors;
if(!(validate78(data137.job, {instancePath:instancePath+"/page/evidence/manifest/job",parentData:data137,parentDataProperty:"job",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate78.errors : vErrors.concat(validate78.errors);
errors = vErrors.length;
}
var valid65 = _errs343 === errors;
}
else {
var valid65 = true;
}
if(valid65){
if(data137.source !== undefined){
let data139 = data137.source;
const _errs344 = errors;
if(errors === _errs344){
if(data139 && typeof data139 == "object" && !Array.isArray(data139)){
let missing43;
if((((data139.pid === undefined) && (missing43 = "pid")) || ((data139.input === undefined) && (missing43 = "input"))) || ((data139.index === undefined) && (missing43 = "index"))){
const err220 = {instancePath:instancePath+"/page/evidence/manifest/source",schemaPath:"#/oneOf/10/properties/page/properties/evidence/properties/manifest/properties/source/required",keyword:"required",params:{missingProperty: missing43},message:"must have required property '"+missing43+"'"};
if(vErrors === null){
vErrors = [err220];
}
else {
vErrors.push(err220);
}
errors++;
}
else {
const _errs346 = errors;
for(const key43 in data139){
if(!(((key43 === "pid") || (key43 === "input")) || (key43 === "index"))){
const err221 = {instancePath:instancePath+"/page/evidence/manifest/source",schemaPath:"#/oneOf/10/properties/page/properties/evidence/properties/manifest/properties/source/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key43},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err221];
}
else {
vErrors.push(err221);
}
errors++;
break;
}
}
if(_errs346 === errors){
if(data139.pid !== undefined){
const _errs347 = errors;
if(!(validate78(data139.pid, {instancePath:instancePath+"/page/evidence/manifest/source/pid",parentData:data139,parentDataProperty:"pid",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate78.errors : vErrors.concat(validate78.errors);
errors = vErrors.length;
}
var valid66 = _errs347 === errors;
}
else {
var valid66 = true;
}
if(valid66){
if(data139.input !== undefined){
const _errs348 = errors;
if(!(validate78(data139.input, {instancePath:instancePath+"/page/evidence/manifest/source/input",parentData:data139,parentDataProperty:"input",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate78.errors : vErrors.concat(validate78.errors);
errors = vErrors.length;
}
var valid66 = _errs348 === errors;
}
else {
var valid66 = true;
}
if(valid66){
if(data139.index !== undefined){
const _errs349 = errors;
if(!(validate72(data139.index, {instancePath:instancePath+"/page/evidence/manifest/source/index",parentData:data139,parentDataProperty:"index",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate72.errors : vErrors.concat(validate72.errors);
errors = vErrors.length;
}
var valid66 = _errs349 === errors;
}
else {
var valid66 = true;
}
}
}
}
}
}
else {
const err222 = {instancePath:instancePath+"/page/evidence/manifest/source",schemaPath:"#/oneOf/10/properties/page/properties/evidence/properties/manifest/properties/source/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err222];
}
else {
vErrors.push(err222);
}
errors++;
}
}
var valid65 = _errs344 === errors;
}
else {
var valid65 = true;
}
if(valid65){
if(data137.requester !== undefined){
const _errs350 = errors;
if(!(validate78(data137.requester, {instancePath:instancePath+"/page/evidence/manifest/requester",parentData:data137,parentDataProperty:"requester",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate78.errors : vErrors.concat(validate78.errors);
errors = vErrors.length;
}
var valid65 = _errs350 === errors;
}
else {
var valid65 = true;
}
if(valid65){
if(data137.correlation !== undefined){
let data144 = data137.correlation;
const _errs351 = errors;
if(errors === _errs351){
if(typeof data144 === "string"){
if(func1(data144) > 131072){
const err223 = {instancePath:instancePath+"/page/evidence/manifest/correlation",schemaPath:"#/oneOf/10/properties/page/properties/evidence/properties/manifest/properties/correlation/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err223];
}
else {
vErrors.push(err223);
}
errors++;
}
}
else {
const err224 = {instancePath:instancePath+"/page/evidence/manifest/correlation",schemaPath:"#/oneOf/10/properties/page/properties/evidence/properties/manifest/properties/correlation/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err224];
}
else {
vErrors.push(err224);
}
errors++;
}
}
var valid65 = _errs351 === errors;
}
else {
var valid65 = true;
}
if(valid65){
if(data137.policy_revision !== undefined){
let data145 = data137.policy_revision;
const _errs353 = errors;
if(errors === _errs353){
if(typeof data145 === "string"){
if(func1(data145) > 131072){
const err225 = {instancePath:instancePath+"/page/evidence/manifest/policy_revision",schemaPath:"#/oneOf/10/properties/page/properties/evidence/properties/manifest/properties/policy_revision/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err225];
}
else {
vErrors.push(err225);
}
errors++;
}
}
else {
const err226 = {instancePath:instancePath+"/page/evidence/manifest/policy_revision",schemaPath:"#/oneOf/10/properties/page/properties/evidence/properties/manifest/properties/policy_revision/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err226];
}
else {
vErrors.push(err226);
}
errors++;
}
}
var valid65 = _errs353 === errors;
}
else {
var valid65 = true;
}
if(valid65){
if(data137.request !== undefined){
const _errs355 = errors;
if(!(validate243(data137.request, {instancePath:instancePath+"/page/evidence/manifest/request",parentData:data137,parentDataProperty:"request",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate243.errors : vErrors.concat(validate243.errors);
errors = vErrors.length;
}
var valid65 = _errs355 === errors;
}
else {
var valid65 = true;
}
if(valid65){
if(data137.basis !== undefined){
let data147 = data137.basis;
const _errs356 = errors;
if(errors === _errs356){
if(data147 && typeof data147 == "object" && !Array.isArray(data147)){
let missing44;
if((((((data147.kind === undefined) && (missing44 = "kind")) || ((data147.resource === undefined) && (missing44 = "resource"))) || ((data147.revision === undefined) && (missing44 = "revision"))) || ((data147.contract === undefined) && (missing44 = "contract"))) || ((data147.schema === undefined) && (missing44 = "schema"))){
const err227 = {instancePath:instancePath+"/page/evidence/manifest/basis",schemaPath:"#/oneOf/10/properties/page/properties/evidence/properties/manifest/properties/basis/required",keyword:"required",params:{missingProperty: missing44},message:"must have required property '"+missing44+"'"};
if(vErrors === null){
vErrors = [err227];
}
else {
vErrors.push(err227);
}
errors++;
}
else {
const _errs358 = errors;
for(const key44 in data147){
if(!(((((key44 === "kind") || (key44 === "resource")) || (key44 === "revision")) || (key44 === "contract")) || (key44 === "schema"))){
const err228 = {instancePath:instancePath+"/page/evidence/manifest/basis",schemaPath:"#/oneOf/10/properties/page/properties/evidence/properties/manifest/properties/basis/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key44},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err228];
}
else {
vErrors.push(err228);
}
errors++;
break;
}
}
if(_errs358 === errors){
if(data147.kind !== undefined){
const _errs359 = errors;
if(!(validate211(data147.kind, {instancePath:instancePath+"/page/evidence/manifest/basis/kind",parentData:data147,parentDataProperty:"kind",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate211.errors : vErrors.concat(validate211.errors);
errors = vErrors.length;
}
var valid67 = _errs359 === errors;
}
else {
var valid67 = true;
}
if(valid67){
if(data147.resource !== undefined){
const _errs360 = errors;
if(!(validate78(data147.resource, {instancePath:instancePath+"/page/evidence/manifest/basis/resource",parentData:data147,parentDataProperty:"resource",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate78.errors : vErrors.concat(validate78.errors);
errors = vErrors.length;
}
var valid67 = _errs360 === errors;
}
else {
var valid67 = true;
}
if(valid67){
if(data147.revision !== undefined){
const _errs361 = errors;
if(!(validate78(data147.revision, {instancePath:instancePath+"/page/evidence/manifest/basis/revision",parentData:data147,parentDataProperty:"revision",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate78.errors : vErrors.concat(validate78.errors);
errors = vErrors.length;
}
var valid67 = _errs361 === errors;
}
else {
var valid67 = true;
}
if(valid67){
if(data147.contract !== undefined){
const _errs362 = errors;
if(!(validate163(data147.contract, {instancePath:instancePath+"/page/evidence/manifest/basis/contract",parentData:data147,parentDataProperty:"contract",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate163.errors : vErrors.concat(validate163.errors);
errors = vErrors.length;
}
var valid67 = _errs362 === errors;
}
else {
var valid67 = true;
}
if(valid67){
if(data147.schema !== undefined){
const _errs363 = errors;
if(!(validate163(data147.schema, {instancePath:instancePath+"/page/evidence/manifest/basis/schema",parentData:data147,parentDataProperty:"schema",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate163.errors : vErrors.concat(validate163.errors);
errors = vErrors.length;
}
var valid67 = _errs363 === errors;
}
else {
var valid67 = true;
}
}
}
}
}
}
}
}
else {
const err229 = {instancePath:instancePath+"/page/evidence/manifest/basis",schemaPath:"#/oneOf/10/properties/page/properties/evidence/properties/manifest/properties/basis/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err229];
}
else {
vErrors.push(err229);
}
errors++;
}
}
var valid65 = _errs356 === errors;
}
else {
var valid65 = true;
}
if(valid65){
if(data137.plan !== undefined){
const _errs364 = errors;
if(!(validate163(data137.plan, {instancePath:instancePath+"/page/evidence/manifest/plan",parentData:data137,parentDataProperty:"plan",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate163.errors : vErrors.concat(validate163.errors);
errors = vErrors.length;
}
var valid65 = _errs364 === errors;
}
else {
var valid65 = true;
}
if(valid65){
if(data137.pages !== undefined){
let data154 = data137.pages;
const _errs365 = errors;
if(errors === _errs365){
if(typeof data154 === "string"){
if(func1(data154) > 131072){
const err230 = {instancePath:instancePath+"/page/evidence/manifest/pages",schemaPath:"#/oneOf/10/properties/page/properties/evidence/properties/manifest/properties/pages/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err230];
}
else {
vErrors.push(err230);
}
errors++;
}
}
else {
const err231 = {instancePath:instancePath+"/page/evidence/manifest/pages",schemaPath:"#/oneOf/10/properties/page/properties/evidence/properties/manifest/properties/pages/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err231];
}
else {
vErrors.push(err231);
}
errors++;
}
}
var valid65 = _errs365 === errors;
}
else {
var valid65 = true;
}
if(valid65){
if(data137.scanned !== undefined){
let data155 = data137.scanned;
const _errs367 = errors;
if(errors === _errs367){
if(typeof data155 === "string"){
if(func1(data155) > 131072){
const err232 = {instancePath:instancePath+"/page/evidence/manifest/scanned",schemaPath:"#/oneOf/10/properties/page/properties/evidence/properties/manifest/properties/scanned/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err232];
}
else {
vErrors.push(err232);
}
errors++;
}
}
else {
const err233 = {instancePath:instancePath+"/page/evidence/manifest/scanned",schemaPath:"#/oneOf/10/properties/page/properties/evidence/properties/manifest/properties/scanned/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err233];
}
else {
vErrors.push(err233);
}
errors++;
}
}
var valid65 = _errs367 === errors;
}
else {
var valid65 = true;
}
if(valid65){
if(data137.selected !== undefined){
let data156 = data137.selected;
const _errs369 = errors;
if(errors === _errs369){
if(typeof data156 === "string"){
if(func1(data156) > 131072){
const err234 = {instancePath:instancePath+"/page/evidence/manifest/selected",schemaPath:"#/oneOf/10/properties/page/properties/evidence/properties/manifest/properties/selected/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err234];
}
else {
vErrors.push(err234);
}
errors++;
}
}
else {
const err235 = {instancePath:instancePath+"/page/evidence/manifest/selected",schemaPath:"#/oneOf/10/properties/page/properties/evidence/properties/manifest/properties/selected/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err235];
}
else {
vErrors.push(err235);
}
errors++;
}
}
var valid65 = _errs369 === errors;
}
else {
var valid65 = true;
}
if(valid65){
if(data137.value_count !== undefined){
let data157 = data137.value_count;
const _errs371 = errors;
if(errors === _errs371){
if(typeof data157 === "string"){
if(func1(data157) > 131072){
const err236 = {instancePath:instancePath+"/page/evidence/manifest/value_count",schemaPath:"#/oneOf/10/properties/page/properties/evidence/properties/manifest/properties/value_count/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err236];
}
else {
vErrors.push(err236);
}
errors++;
}
}
else {
const err237 = {instancePath:instancePath+"/page/evidence/manifest/value_count",schemaPath:"#/oneOf/10/properties/page/properties/evidence/properties/manifest/properties/value_count/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err237];
}
else {
vErrors.push(err237);
}
errors++;
}
}
var valid65 = _errs371 === errors;
}
else {
var valid65 = true;
}
if(valid65){
if(data137.segments !== undefined){
let data158 = data137.segments;
const _errs373 = errors;
if(errors === _errs373){
if(typeof data158 === "string"){
if(func1(data158) > 131072){
const err238 = {instancePath:instancePath+"/page/evidence/manifest/segments",schemaPath:"#/oneOf/10/properties/page/properties/evidence/properties/manifest/properties/segments/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err238];
}
else {
vErrors.push(err238);
}
errors++;
}
}
else {
const err239 = {instancePath:instancePath+"/page/evidence/manifest/segments",schemaPath:"#/oneOf/10/properties/page/properties/evidence/properties/manifest/properties/segments/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err239];
}
else {
vErrors.push(err239);
}
errors++;
}
}
var valid65 = _errs373 === errors;
}
else {
var valid65 = true;
}
if(valid65){
if(data137.rows !== undefined){
let data159 = data137.rows;
const _errs375 = errors;
if(errors === _errs375){
if(typeof data159 === "string"){
if(func1(data159) > 131072){
const err240 = {instancePath:instancePath+"/page/evidence/manifest/rows",schemaPath:"#/oneOf/10/properties/page/properties/evidence/properties/manifest/properties/rows/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
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
const err241 = {instancePath:instancePath+"/page/evidence/manifest/rows",schemaPath:"#/oneOf/10/properties/page/properties/evidence/properties/manifest/properties/rows/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err241];
}
else {
vErrors.push(err241);
}
errors++;
}
}
var valid65 = _errs375 === errors;
}
else {
var valid65 = true;
}
if(valid65){
if(data137.bytes !== undefined){
let data160 = data137.bytes;
const _errs377 = errors;
if(errors === _errs377){
if(typeof data160 === "string"){
if(func1(data160) > 131072){
const err242 = {instancePath:instancePath+"/page/evidence/manifest/bytes",schemaPath:"#/oneOf/10/properties/page/properties/evidence/properties/manifest/properties/bytes/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err242];
}
else {
vErrors.push(err242);
}
errors++;
}
}
else {
const err243 = {instancePath:instancePath+"/page/evidence/manifest/bytes",schemaPath:"#/oneOf/10/properties/page/properties/evidence/properties/manifest/properties/bytes/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err243];
}
else {
vErrors.push(err243);
}
errors++;
}
}
var valid65 = _errs377 === errors;
}
else {
var valid65 = true;
}
if(valid65){
if(data137.sum !== undefined){
const _errs379 = errors;
if(!(validate74(data137.sum, {instancePath:instancePath+"/page/evidence/manifest/sum",parentData:data137,parentDataProperty:"sum",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate74.errors : vErrors.concat(validate74.errors);
errors = vErrors.length;
}
var valid65 = _errs379 === errors;
}
else {
var valid65 = true;
}
if(valid65){
if(data137.finished !== undefined){
let data162 = data137.finished;
const _errs380 = errors;
const _errs381 = errors;
let valid68 = false;
const _errs382 = errors;
if(typeof data162 !== "string"){
const err244 = {instancePath:instancePath+"/page/evidence/manifest/finished",schemaPath:"#/oneOf/10/properties/page/properties/evidence/properties/manifest/properties/finished/anyOf/0/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err244];
}
else {
vErrors.push(err244);
}
errors++;
}
if(!((data162 === "source_end") || (data162 === "limit"))){
const err245 = {instancePath:instancePath+"/page/evidence/manifest/finished",schemaPath:"#/oneOf/10/properties/page/properties/evidence/properties/manifest/properties/finished/anyOf/0/enum",keyword:"enum",params:{allowedValues: schema34.oneOf[10].properties.page.properties.evidence.properties.manifest.properties.finished.anyOf[0].enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err245];
}
else {
vErrors.push(err245);
}
errors++;
}
var _valid16 = _errs382 === errors;
valid68 = valid68 || _valid16;
const _errs384 = errors;
if(data162 !== null){
const err246 = {instancePath:instancePath+"/page/evidence/manifest/finished",schemaPath:"#/oneOf/10/properties/page/properties/evidence/properties/manifest/properties/finished/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err246];
}
else {
vErrors.push(err246);
}
errors++;
}
var _valid16 = _errs384 === errors;
valid68 = valid68 || _valid16;
if(!valid68){
const err247 = {instancePath:instancePath+"/page/evidence/manifest/finished",schemaPath:"#/oneOf/10/properties/page/properties/evidence/properties/manifest/properties/finished/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err247];
}
else {
vErrors.push(err247);
}
errors++;
}
else {
errors = _errs381;
if(vErrors !== null){
if(_errs381){
vErrors.length = _errs381;
}
else {
vErrors = null;
}
}
}
var valid65 = _errs380 === errors;
}
else {
var valid65 = true;
}
if(valid65){
if(data137.chain !== undefined){
const _errs386 = errors;
if(!(validate163(data137.chain, {instancePath:instancePath+"/page/evidence/manifest/chain",parentData:data137,parentDataProperty:"chain",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate163.errors : vErrors.concat(validate163.errors);
errors = vErrors.length;
}
var valid65 = _errs386 === errors;
}
else {
var valid65 = true;
}
}
}
}
}
}
}
}
}
}
}
}
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
const err248 = {instancePath:instancePath+"/page/evidence/manifest",schemaPath:"#/oneOf/10/properties/page/properties/evidence/properties/manifest/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err248];
}
else {
vErrors.push(err248);
}
errors++;
}
}
var valid64 = _errs340 === errors;
}
else {
var valid64 = true;
}
if(valid64){
if(data136.columns !== undefined){
const _errs387 = errors;
if(!(validate156(data136.columns, {instancePath:instancePath+"/page/evidence/columns",parentData:data136,parentDataProperty:"columns",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate156.errors : vErrors.concat(validate156.errors);
errors = vErrors.length;
}
var valid64 = _errs387 === errors;
}
else {
var valid64 = true;
}
if(valid64){
if(data136.ordinal !== undefined){
let data165 = data136.ordinal;
const _errs388 = errors;
if(errors === _errs388){
if(typeof data165 === "string"){
if(func1(data165) > 131072){
const err249 = {instancePath:instancePath+"/page/evidence/ordinal",schemaPath:"#/oneOf/10/properties/page/properties/evidence/properties/ordinal/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err249];
}
else {
vErrors.push(err249);
}
errors++;
}
}
else {
const err250 = {instancePath:instancePath+"/page/evidence/ordinal",schemaPath:"#/oneOf/10/properties/page/properties/evidence/properties/ordinal/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err250];
}
else {
vErrors.push(err250);
}
errors++;
}
}
var valid64 = _errs388 === errors;
}
else {
var valid64 = true;
}
if(valid64){
if(data136.rows !== undefined){
const _errs390 = errors;
if(!(validate72(data136.rows, {instancePath:instancePath+"/page/evidence/rows",parentData:data136,parentDataProperty:"rows",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate72.errors : vErrors.concat(validate72.errors);
errors = vErrors.length;
}
var valid64 = _errs390 === errors;
}
else {
var valid64 = true;
}
if(valid64){
if(data136.ipc !== undefined){
let data167 = data136.ipc;
const _errs391 = errors;
if(errors === _errs391){
if(typeof data167 === "string"){
if(func1(data167) > 131072){
const err251 = {instancePath:instancePath+"/page/evidence/ipc",schemaPath:"#/oneOf/10/properties/page/properties/evidence/properties/ipc/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err251];
}
else {
vErrors.push(err251);
}
errors++;
}
}
else {
const err252 = {instancePath:instancePath+"/page/evidence/ipc",schemaPath:"#/oneOf/10/properties/page/properties/evidence/properties/ipc/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err252];
}
else {
vErrors.push(err252);
}
errors++;
}
}
var valid64 = _errs391 === errors;
}
else {
var valid64 = true;
}
if(valid64){
if(data136.next !== undefined){
const _errs393 = errors;
if(!(validate74(data136.next, {instancePath:instancePath+"/page/evidence/next",parentData:data136,parentDataProperty:"next",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate74.errors : vErrors.concat(validate74.errors);
errors = vErrors.length;
}
var valid64 = _errs393 === errors;
}
else {
var valid64 = true;
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
const err253 = {instancePath:instancePath+"/page/evidence",schemaPath:"#/oneOf/10/properties/page/properties/evidence/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err253];
}
else {
vErrors.push(err253);
}
errors++;
}
}
var valid63 = _errs337 === errors;
}
else {
var valid63 = true;
}
if(valid63){
if(data135.cells !== undefined){
let data169 = data135.cells;
const _errs394 = errors;
if(errors === _errs394){
if(Array.isArray(data169)){
if(data169.length > 8){
const err254 = {instancePath:instancePath+"/page/cells",schemaPath:"#/oneOf/10/properties/page/properties/cells/maxItems",keyword:"maxItems",params:{limit: 8},message:"must NOT have more than 8 items"};
if(vErrors === null){
vErrors = [err254];
}
else {
vErrors.push(err254);
}
errors++;
}
else {
var valid69 = true;
const len7 = data169.length;
for(let i7=0; i7<len7; i7++){
let data170 = data169[i7];
const _errs396 = errors;
if(errors === _errs396){
if(Array.isArray(data170)){
if(data170.length > 8){
const err255 = {instancePath:instancePath+"/page/cells/" + i7,schemaPath:"#/oneOf/10/properties/page/properties/cells/items/maxItems",keyword:"maxItems",params:{limit: 8},message:"must NOT have more than 8 items"};
if(vErrors === null){
vErrors = [err255];
}
else {
vErrors.push(err255);
}
errors++;
}
else {
var valid70 = true;
const len8 = data170.length;
for(let i8=0; i8<len8; i8++){
let data171 = data170[i8];
const _errs398 = errors;
const _errs399 = errors;
let valid71 = false;
let passing9 = null;
const _errs400 = errors;
if(errors === _errs400){
if(data171 && typeof data171 == "object" && !Array.isArray(data171)){
let missing45;
if((data171.missing === undefined) && (missing45 = "missing")){
const err256 = {instancePath:instancePath+"/page/cells/" + i7+"/" + i8,schemaPath:"#/oneOf/10/properties/page/properties/cells/items/items/oneOf/0/required",keyword:"required",params:{missingProperty: missing45},message:"must have required property '"+missing45+"'"};
if(vErrors === null){
vErrors = [err256];
}
else {
vErrors.push(err256);
}
errors++;
}
else {
const _errs402 = errors;
for(const key45 in data171){
if(!(key45 === "missing")){
const err257 = {instancePath:instancePath+"/page/cells/" + i7+"/" + i8,schemaPath:"#/oneOf/10/properties/page/properties/cells/items/items/oneOf/0/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key45},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err257];
}
else {
vErrors.push(err257);
}
errors++;
break;
}
}
if(_errs402 === errors){
if(data171.missing !== undefined){
let data172 = data171.missing;
const _errs403 = errors;
if(errors === _errs403){
if(data172 && typeof data172 == "object" && !Array.isArray(data172)){
if(Object.keys(data172).length > 0){
const err258 = {instancePath:instancePath+"/page/cells/" + i7+"/" + i8+"/missing",schemaPath:"#/oneOf/10/properties/page/properties/cells/items/items/oneOf/0/properties/missing/maxProperties",keyword:"maxProperties",params:{limit: 0},message:"must NOT have more than 0 properties"};
if(vErrors === null){
vErrors = [err258];
}
else {
vErrors.push(err258);
}
errors++;
}
}
else {
const err259 = {instancePath:instancePath+"/page/cells/" + i7+"/" + i8+"/missing",schemaPath:"#/oneOf/10/properties/page/properties/cells/items/items/oneOf/0/properties/missing/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err260 = {instancePath:instancePath+"/page/cells/" + i7+"/" + i8,schemaPath:"#/oneOf/10/properties/page/properties/cells/items/items/oneOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err260];
}
else {
vErrors.push(err260);
}
errors++;
}
}
var _valid17 = _errs400 === errors;
if(_valid17){
valid71 = true;
passing9 = 0;
var props14 = true;
}
const _errs405 = errors;
if(!(validate345(data171, {instancePath:instancePath+"/page/cells/" + i7+"/" + i8,parentData:data170,parentDataProperty:i8,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate345.errors : vErrors.concat(validate345.errors);
errors = vErrors.length;
}
var _valid17 = _errs405 === errors;
if(_valid17 && valid71){
valid71 = false;
passing9 = [passing9, 1];
}
else {
if(_valid17){
valid71 = true;
passing9 = 1;
if(props14 !== true){
props14 = true;
}
}
const _errs406 = errors;
if(!(validate347(data171, {instancePath:instancePath+"/page/cells/" + i7+"/" + i8,parentData:data170,parentDataProperty:i8,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate347.errors : vErrors.concat(validate347.errors);
errors = vErrors.length;
}
var _valid17 = _errs406 === errors;
if(_valid17 && valid71){
valid71 = false;
passing9 = [passing9, 2];
}
else {
if(_valid17){
valid71 = true;
passing9 = 2;
if(props14 !== true){
props14 = true;
}
}
const _errs407 = errors;
if(!(validate351(data171, {instancePath:instancePath+"/page/cells/" + i7+"/" + i8,parentData:data170,parentDataProperty:i8,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate351.errors : vErrors.concat(validate351.errors);
errors = vErrors.length;
}
var _valid17 = _errs407 === errors;
if(_valid17 && valid71){
valid71 = false;
passing9 = [passing9, 3];
}
else {
if(_valid17){
valid71 = true;
passing9 = 3;
if(props14 !== true){
props14 = true;
}
}
const _errs408 = errors;
if(errors === _errs408){
if(data171 && typeof data171 == "object" && !Array.isArray(data171)){
let missing46;
if((data171.conflict === undefined) && (missing46 = "conflict")){
const err261 = {instancePath:instancePath+"/page/cells/" + i7+"/" + i8,schemaPath:"#/oneOf/10/properties/page/properties/cells/items/items/oneOf/4/required",keyword:"required",params:{missingProperty: missing46},message:"must have required property '"+missing46+"'"};
if(vErrors === null){
vErrors = [err261];
}
else {
vErrors.push(err261);
}
errors++;
}
else {
const _errs410 = errors;
for(const key46 in data171){
if(!(key46 === "conflict")){
const err262 = {instancePath:instancePath+"/page/cells/" + i7+"/" + i8,schemaPath:"#/oneOf/10/properties/page/properties/cells/items/items/oneOf/4/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key46},message:"must NOT have additional properties"};
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
if(_errs410 === errors){
if(data171.conflict !== undefined){
let data173 = data171.conflict;
const _errs411 = errors;
if(errors === _errs411){
if(Array.isArray(data173)){
if(data173.length > 8){
const err263 = {instancePath:instancePath+"/page/cells/" + i7+"/" + i8+"/conflict",schemaPath:"#/oneOf/10/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/maxItems",keyword:"maxItems",params:{limit: 8},message:"must NOT have more than 8 items"};
if(vErrors === null){
vErrors = [err263];
}
else {
vErrors.push(err263);
}
errors++;
}
else {
var valid74 = true;
const len9 = data173.length;
for(let i9=0; i9<len9; i9++){
let data174 = data173[i9];
const _errs413 = errors;
if(errors === _errs413){
if(data174 && typeof data174 == "object" && !Array.isArray(data174)){
let missing47;
if((((data174.counter === undefined) && (missing47 = "counter")) || ((data174.replica === undefined) && (missing47 = "replica"))) || ((data174.value === undefined) && (missing47 = "value"))){
const err264 = {instancePath:instancePath+"/page/cells/" + i7+"/" + i8+"/conflict/" + i9,schemaPath:"#/oneOf/10/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/required",keyword:"required",params:{missingProperty: missing47},message:"must have required property '"+missing47+"'"};
if(vErrors === null){
vErrors = [err264];
}
else {
vErrors.push(err264);
}
errors++;
}
else {
const _errs415 = errors;
for(const key47 in data174){
if(!(((key47 === "counter") || (key47 === "replica")) || (key47 === "value"))){
const err265 = {instancePath:instancePath+"/page/cells/" + i7+"/" + i8+"/conflict/" + i9,schemaPath:"#/oneOf/10/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key47},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err265];
}
else {
vErrors.push(err265);
}
errors++;
break;
}
}
if(_errs415 === errors){
if(data174.counter !== undefined){
let data175 = data174.counter;
const _errs416 = errors;
if(errors === _errs416){
if(typeof data175 === "string"){
if(func1(data175) > 131072){
const err266 = {instancePath:instancePath+"/page/cells/" + i7+"/" + i8+"/conflict/" + i9+"/counter",schemaPath:"#/oneOf/10/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/properties/counter/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err266];
}
else {
vErrors.push(err266);
}
errors++;
}
}
else {
const err267 = {instancePath:instancePath+"/page/cells/" + i7+"/" + i8+"/conflict/" + i9+"/counter",schemaPath:"#/oneOf/10/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/properties/counter/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err267];
}
else {
vErrors.push(err267);
}
errors++;
}
}
var valid75 = _errs416 === errors;
}
else {
var valid75 = true;
}
if(valid75){
if(data174.replica !== undefined){
let data176 = data174.replica;
const _errs418 = errors;
if(errors === _errs418){
if(typeof data176 === "string"){
if(func1(data176) > 131072){
const err268 = {instancePath:instancePath+"/page/cells/" + i7+"/" + i8+"/conflict/" + i9+"/replica",schemaPath:"#/oneOf/10/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/properties/replica/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err268];
}
else {
vErrors.push(err268);
}
errors++;
}
}
else {
const err269 = {instancePath:instancePath+"/page/cells/" + i7+"/" + i8+"/conflict/" + i9+"/replica",schemaPath:"#/oneOf/10/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/properties/replica/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err269];
}
else {
vErrors.push(err269);
}
errors++;
}
}
var valid75 = _errs418 === errors;
}
else {
var valid75 = true;
}
if(valid75){
if(data174.value !== undefined){
let data177 = data174.value;
const _errs420 = errors;
const _errs421 = errors;
let valid76 = false;
let passing10 = null;
const _errs422 = errors;
if(!(validate345(data177, {instancePath:instancePath+"/page/cells/" + i7+"/" + i8+"/conflict/" + i9+"/value",parentData:data174,parentDataProperty:"value",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate345.errors : vErrors.concat(validate345.errors);
errors = vErrors.length;
}
var _valid18 = _errs422 === errors;
if(_valid18){
valid76 = true;
passing10 = 0;
var props15 = true;
}
const _errs423 = errors;
if(!(validate347(data177, {instancePath:instancePath+"/page/cells/" + i7+"/" + i8+"/conflict/" + i9+"/value",parentData:data174,parentDataProperty:"value",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate347.errors : vErrors.concat(validate347.errors);
errors = vErrors.length;
}
var _valid18 = _errs423 === errors;
if(_valid18 && valid76){
valid76 = false;
passing10 = [passing10, 1];
}
else {
if(_valid18){
valid76 = true;
passing10 = 1;
if(props15 !== true){
props15 = true;
}
}
const _errs424 = errors;
if(!(validate351(data177, {instancePath:instancePath+"/page/cells/" + i7+"/" + i8+"/conflict/" + i9+"/value",parentData:data174,parentDataProperty:"value",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate351.errors : vErrors.concat(validate351.errors);
errors = vErrors.length;
}
var _valid18 = _errs424 === errors;
if(_valid18 && valid76){
valid76 = false;
passing10 = [passing10, 2];
}
else {
if(_valid18){
valid76 = true;
passing10 = 2;
if(props15 !== true){
props15 = true;
}
}
}
}
if(!valid76){
const err270 = {instancePath:instancePath+"/page/cells/" + i7+"/" + i8+"/conflict/" + i9+"/value",schemaPath:"#/oneOf/10/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/properties/value/oneOf",keyword:"oneOf",params:{passingSchemas: passing10},message:"must match exactly one schema in oneOf"};
if(vErrors === null){
vErrors = [err270];
}
else {
vErrors.push(err270);
}
errors++;
}
else {
errors = _errs421;
if(vErrors !== null){
if(_errs421){
vErrors.length = _errs421;
}
else {
vErrors = null;
}
}
}
var valid75 = _errs420 === errors;
}
else {
var valid75 = true;
}
}
}
}
}
}
else {
const err271 = {instancePath:instancePath+"/page/cells/" + i7+"/" + i8+"/conflict/" + i9,schemaPath:"#/oneOf/10/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err271];
}
else {
vErrors.push(err271);
}
errors++;
}
}
var valid74 = _errs413 === errors;
if(!valid74){
break;
}
}
}
}
else {
const err272 = {instancePath:instancePath+"/page/cells/" + i7+"/" + i8+"/conflict",schemaPath:"#/oneOf/10/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/type",keyword:"type",params:{type: "array"},message:"must be array"};
if(vErrors === null){
vErrors = [err272];
}
else {
vErrors.push(err272);
}
errors++;
}
}
}
}
}
}
else {
const err273 = {instancePath:instancePath+"/page/cells/" + i7+"/" + i8,schemaPath:"#/oneOf/10/properties/page/properties/cells/items/items/oneOf/4/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err273];
}
else {
vErrors.push(err273);
}
errors++;
}
}
var _valid17 = _errs408 === errors;
if(_valid17 && valid71){
valid71 = false;
passing9 = [passing9, 4];
}
else {
if(_valid17){
valid71 = true;
passing9 = 4;
if(props14 !== true){
props14 = true;
}
}
}
}
}
}
if(!valid71){
const err274 = {instancePath:instancePath+"/page/cells/" + i7+"/" + i8,schemaPath:"#/oneOf/10/properties/page/properties/cells/items/items/oneOf",keyword:"oneOf",params:{passingSchemas: passing9},message:"must match exactly one schema in oneOf"};
if(vErrors === null){
vErrors = [err274];
}
else {
vErrors.push(err274);
}
errors++;
}
else {
errors = _errs399;
if(vErrors !== null){
if(_errs399){
vErrors.length = _errs399;
}
else {
vErrors = null;
}
}
}
var valid70 = _errs398 === errors;
if(!valid70){
break;
}
}
}
}
else {
const err275 = {instancePath:instancePath+"/page/cells/" + i7,schemaPath:"#/oneOf/10/properties/page/properties/cells/items/type",keyword:"type",params:{type: "array"},message:"must be array"};
if(vErrors === null){
vErrors = [err275];
}
else {
vErrors.push(err275);
}
errors++;
}
}
var valid69 = _errs396 === errors;
if(!valid69){
break;
}
}
}
}
else {
const err276 = {instancePath:instancePath+"/page/cells",schemaPath:"#/oneOf/10/properties/page/properties/cells/type",keyword:"type",params:{type: "array"},message:"must be array"};
if(vErrors === null){
vErrors = [err276];
}
else {
vErrors.push(err276);
}
errors++;
}
}
var valid63 = _errs394 === errors;
}
else {
var valid63 = true;
}
}
}
}
}
else {
const err277 = {instancePath:instancePath+"/page",schemaPath:"#/oneOf/10/properties/page/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err277];
}
else {
vErrors.push(err277);
}
errors++;
}
}
}
}
}
}
else {
const err278 = {instancePath,schemaPath:"#/oneOf/10/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err278];
}
else {
vErrors.push(err278);
}
errors++;
}
}
var _valid0 = _errs331 === errors;
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
const _errs425 = errors;
if(errors === _errs425){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing48;
if((data.draft === undefined) && (missing48 = "draft")){
const err279 = {instancePath,schemaPath:"#/oneOf/11/required",keyword:"required",params:{missingProperty: missing48},message:"must have required property '"+missing48+"'"};
if(vErrors === null){
vErrors = [err279];
}
else {
vErrors.push(err279);
}
errors++;
}
else {
const _errs427 = errors;
for(const key48 in data){
if(!(key48 === "draft")){
const err280 = {instancePath,schemaPath:"#/oneOf/11/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key48},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err280];
}
else {
vErrors.push(err280);
}
errors++;
break;
}
}
if(_errs427 === errors){
if(data.draft !== undefined){
let data178 = data.draft;
const _errs429 = errors;
let valid78 = false;
const _errs430 = errors;
if(!(validate357(data178, {instancePath:instancePath+"/draft",parentData:data,parentDataProperty:"draft",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate357.errors : vErrors.concat(validate357.errors);
errors = vErrors.length;
}
var _valid19 = _errs430 === errors;
valid78 = valid78 || _valid19;
const _errs431 = errors;
if(data178 !== null){
const err281 = {instancePath:instancePath+"/draft",schemaPath:"#/oneOf/11/properties/draft/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err281];
}
else {
vErrors.push(err281);
}
errors++;
}
var _valid19 = _errs431 === errors;
valid78 = valid78 || _valid19;
if(!valid78){
const err282 = {instancePath:instancePath+"/draft",schemaPath:"#/oneOf/11/properties/draft/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err282];
}
else {
vErrors.push(err282);
}
errors++;
}
else {
errors = _errs429;
if(vErrors !== null){
if(_errs429){
vErrors.length = _errs429;
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
const err283 = {instancePath,schemaPath:"#/oneOf/11/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err283];
}
else {
vErrors.push(err283);
}
errors++;
}
}
var _valid0 = _errs425 === errors;
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
const err284 = {instancePath,schemaPath:"#/oneOf",keyword:"oneOf",params:{passingSchemas: passing0},message:"must match exactly one schema in oneOf"};
if(vErrors === null){
vErrors = [err284];
}
else {
vErrors.push(err284);
}
errors++;
validate81.errors = vErrors;
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
validate81.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate81.evaluated = {"dynamicProps":true,"dynamicItems":false};

export const Draft = validate365;

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
if((((((((data.generation === undefined) && (missing0 = "generation")) || ((data.limit === undefined) && (missing0 = "limit"))) || ((data.starts === undefined) && (missing0 = "starts"))) || ((data.enabled === undefined) && (missing0 = "enabled"))) || ((data.contract === undefined) && (missing0 = "contract"))) || ((data.budgets === undefined) && (missing0 = "budgets"))) || ((data.namespaces === undefined) && (missing0 = "namespaces"))){
validate365.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((((((key0 === "generation") || (key0 === "limit")) || (key0 === "starts")) || (key0 === "enabled")) || (key0 === "contract")) || (key0 === "budgets")) || (key0 === "namespaces"))){
validate365.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.generation !== undefined){
let data0 = data.generation;
const _errs2 = errors;
if(errors === _errs2){
if(typeof data0 === "string"){
if(func1(data0) > 131072){
validate365.errors = [{instancePath:instancePath+"/generation",schemaPath:"#/properties/generation/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"}];
return false;
}
}
else {
validate365.errors = [{instancePath:instancePath+"/generation",schemaPath:"#/properties/generation/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.limit !== undefined){
const _errs4 = errors;
if(!(validate72(data.limit, {instancePath:instancePath+"/limit",parentData:data,parentDataProperty:"limit",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate72.errors : vErrors.concat(validate72.errors);
errors = vErrors.length;
}
var valid0 = _errs4 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.starts !== undefined){
const _errs5 = errors;
if(!(validate72(data.starts, {instancePath:instancePath+"/starts",parentData:data,parentDataProperty:"starts",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate72.errors : vErrors.concat(validate72.errors);
errors = vErrors.length;
}
var valid0 = _errs5 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.enabled !== undefined){
const _errs6 = errors;
if(typeof data.enabled !== "boolean"){
validate365.errors = [{instancePath:instancePath+"/enabled",schemaPath:"#/properties/enabled/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"}];
return false;
}
var valid0 = _errs6 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.contract !== undefined){
const _errs8 = errors;
if(!(validate163(data.contract, {instancePath:instancePath+"/contract",parentData:data,parentDataProperty:"contract",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate163.errors : vErrors.concat(validate163.errors);
errors = vErrors.length;
}
var valid0 = _errs8 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.budgets !== undefined){
const _errs9 = errors;
if(!(validate148(data.budgets, {instancePath:instancePath+"/budgets",parentData:data,parentDataProperty:"budgets",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate148.errors : vErrors.concat(validate148.errors);
errors = vErrors.length;
}
var valid0 = _errs9 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.namespaces !== undefined){
const _errs10 = errors;
if(!(validate362(data.namespaces, {instancePath:instancePath+"/namespaces",parentData:data,parentDataProperty:"namespaces",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate362.errors : vErrors.concat(validate362.errors);
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
else {
validate365.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate365.errors = vErrors;
return errors === 0;
}
validate365.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

export const Diagnostic = validate371;

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
if((((((((((((((data.version === undefined) && (missing0 = "version")) || ((data.definition === undefined) && (missing0 = "definition"))) || ((data.code === undefined) && (missing0 = "code"))) || ((data.category === undefined) && (missing0 = "category"))) || ((data.stage === undefined) && (missing0 = "stage"))) || ((data.outcome === undefined) && (missing0 = "outcome"))) || ((data.evidence === undefined) && (missing0 = "evidence"))) || ((data.message === undefined) && (missing0 = "message"))) || ((data.cause === undefined) && (missing0 = "cause"))) || ((data.identity === undefined) && (missing0 = "identity"))) || ((data.location === undefined) && (missing0 = "location"))) || ((data.facts === undefined) && (missing0 = "facts"))) || ((data.actions === undefined) && (missing0 = "actions"))){
validate371.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(func23.call(schema74.properties, key0))){
validate371.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.version !== undefined){
const _errs2 = errors;
if(1 !== data.version){
validate371.errors = [{instancePath:instancePath+"/version",schemaPath:"#/properties/version/const",keyword:"const",params:{allowedValue: 1},message:"must be equal to constant"}];
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
if(!(validate248(data.definition, {instancePath:instancePath+"/definition",parentData:data,parentDataProperty:"definition",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate248.errors : vErrors.concat(validate248.errors);
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
if(func1(data2) > 96){
validate371.errors = [{instancePath:instancePath+"/code",schemaPath:"#/properties/code/maxLength",keyword:"maxLength",params:{limit: 96},message:"must NOT have more than 96 characters"}];
return false;
}
}
else {
validate371.errors = [{instancePath:instancePath+"/code",schemaPath:"#/properties/code/type",keyword:"type",params:{type: "string"},message:"must be string"}];
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
if(!(validate250(data.category, {instancePath:instancePath+"/category",parentData:data,parentDataProperty:"category",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate250.errors : vErrors.concat(validate250.errors);
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
if(!(validate252(data.stage, {instancePath:instancePath+"/stage",parentData:data,parentDataProperty:"stage",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate252.errors : vErrors.concat(validate252.errors);
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
if(!(validate254(data.outcome, {instancePath:instancePath+"/outcome",parentData:data,parentDataProperty:"outcome",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate254.errors : vErrors.concat(validate254.errors);
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
if(!(validate256(data.evidence, {instancePath:instancePath+"/evidence",parentData:data,parentDataProperty:"evidence",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate256.errors : vErrors.concat(validate256.errors);
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
if(func1(data7) > 384){
validate371.errors = [{instancePath:instancePath+"/message",schemaPath:"#/properties/message/maxLength",keyword:"maxLength",params:{limit: 384},message:"must NOT have more than 384 characters"}];
return false;
}
}
else {
validate371.errors = [{instancePath:instancePath+"/message",schemaPath:"#/properties/message/type",keyword:"type",params:{type: "string"},message:"must be string"}];
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
if(!(validate258(data.cause, {instancePath:instancePath+"/cause",parentData:data,parentDataProperty:"cause",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate258.errors : vErrors.concat(validate258.errors);
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
if(!(validate260(data.identity, {instancePath:instancePath+"/identity",parentData:data,parentDataProperty:"identity",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate260.errors : vErrors.concat(validate260.errors);
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
if(!(validate273(data.location, {instancePath:instancePath+"/location",parentData:data,parentDataProperty:"location",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate273.errors : vErrors.concat(validate273.errors);
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
if(!(validate286(data.facts, {instancePath:instancePath+"/facts",parentData:data,parentDataProperty:"facts",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate286.errors : vErrors.concat(validate286.errors);
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
if(!(validate318(data.actions, {instancePath:instancePath+"/actions",parentData:data,parentDataProperty:"actions",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate318.errors : vErrors.concat(validate318.errors);
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
validate371.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate371.errors = vErrors;
return errors === 0;
}
validate371.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};
