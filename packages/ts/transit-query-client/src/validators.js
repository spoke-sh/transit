// Generated; no runtime code generation or eval.
import lengthModule from "ajv/dist/runtime/ucs2length.js";
const ucs2length = lengthModule.default ?? lengthModule;
"use strict";
export const Request = validate53;
const schema20 = {"oneOf":[{"type":"object","additionalProperties":false,"required":["describe"],"properties":{"describe":{"$ref":"#/$defs/Request/$defs/T1"}}},{"type":"object","additionalProperties":false,"required":["sql_capabilities"],"properties":{"sql_capabilities":{"$ref":"#/$defs/Request/$defs/T1"}}},{"type":"object","additionalProperties":false,"required":["suggest"],"properties":{"suggest":{"$ref":"#/$defs/Request/$defs/T2"}}},{"type":"object","additionalProperties":false,"required":["assist"],"properties":{"assist":{"$ref":"#/$defs/Request/$defs/T4"}}},{"type":"object","additionalProperties":false,"required":["compile"],"properties":{"compile":{"$ref":"#/$defs/Request/$defs/T8"}}},{"type":"object","additionalProperties":false,"required":["inspect"],"properties":{"inspect":{"$ref":"#/$defs/Request/$defs/T15"}}},{"type":"object","additionalProperties":false,"required":["next"],"properties":{"next":{"$ref":"#/$defs/Request/$defs/T16"}}},{"type":"object","additionalProperties":false,"required":["refresh"],"properties":{"refresh":{"$ref":"#/$defs/Request/$defs/T18"}}},{"type":"object","additionalProperties":false,"required":["next_draft"],"properties":{"next_draft":{"$ref":"#/$defs/Request/$defs/T19"}}},{"type":"object","additionalProperties":false,"required":["draft_open"],"properties":{"draft_open":{"$ref":"#/$defs/Request/$defs/T20"}}},{"type":"object","additionalProperties":false,"required":["draft_close"],"properties":{"draft_close":{"$ref":"#/$defs/Request/$defs/T3"}}},{"type":"object","additionalProperties":false,"required":["draft_status"],"properties":{"draft_status":{"$ref":"#/$defs/Request/$defs/T22"}}},{"type":"object","additionalProperties":false,"required":["submit"],"properties":{"submit":{"$ref":"#/$defs/Request/$defs/T23"}}},{"type":"object","additionalProperties":false,"required":["observe"],"properties":{"observe":{"$ref":"#/$defs/Request/$defs/T24"}}},{"type":"object","additionalProperties":false,"required":["status"],"properties":{"status":{"$ref":"#/$defs/Request/$defs/T3"}}},{"type":"object","additionalProperties":false,"required":["page"],"properties":{"page":{"$ref":"#/$defs/Request/$defs/T25"}}},{"type":"object","additionalProperties":false,"required":["prepare_control"],"properties":{"prepare_control":{"$ref":"#/$defs/Request/$defs/T26"}}}]};
const schema21 = {"type":"object","maxProperties":0};

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
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
if(Object.keys(data).length > 0){
validate54.errors = [{instancePath,schemaPath:"#/maxProperties",keyword:"maxProperties",params:{limit: 0},message:"must NOT have more than 0 properties"}];
return false;
}
}
else {
validate54.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate54.errors = vErrors;
return errors === 0;
}
validate54.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema22 = {"type":"object","additionalProperties":false,"properties":{"search":{"$ref":"#/$defs/Request/$defs/T3"}},"required":["search"]};
const schema23 = {"type":"string","maxLength":131072};
const func1 = ucs2length;

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
if(errors === 0){
if(typeof data === "string"){
if(func1(data) > 131072){
validate58.errors = [{instancePath,schemaPath:"#/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"}];
return false;
}
}
else {
validate58.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
}
validate58.errors = vErrors;
return errors === 0;
}
validate58.evaluated = {"dynamicProps":false,"dynamicItems":false};


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
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((data.search === undefined) && (missing0 = "search")){
validate57.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(key0 === "search")){
validate57.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.search !== undefined){
if(!(validate58(data.search, {instancePath:instancePath+"/search",parentData:data,parentDataProperty:"search",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate58.errors : vErrors.concat(validate58.errors);
errors = vErrors.length;
}
}
}
}
}
else {
validate57.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate57.errors = vErrors;
return errors === 0;
}
validate57.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema24 = {"type":"object","additionalProperties":false,"properties":{"sql":{"$ref":"#/$defs/Request/$defs/T3"},"cursor":{"$ref":"#/$defs/Request/$defs/T5"},"generation":{"$ref":"#/$defs/Request/$defs/T6"},"mode":{"$ref":"#/$defs/Request/$defs/T7"}},"required":["sql","cursor","generation"]};
const schema25 = {"type":"integer","minimum":0,"maximum":65535};

function validate64(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate64.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(!(((typeof data == "number") && (!(data % 1) && !isNaN(data))) && (isFinite(data)))){
validate64.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "integer"},message:"must be integer"}];
return false;
}
if(errors === 0){
if((typeof data == "number") && (isFinite(data))){
if(data > 65535 || isNaN(data)){
validate64.errors = [{instancePath,schemaPath:"#/maximum",keyword:"maximum",params:{comparison: "<=", limit: 65535},message:"must be <= 65535"}];
return false;
}
else {
if(data < 0 || isNaN(data)){
validate64.errors = [{instancePath,schemaPath:"#/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"}];
return false;
}
}
}
}
validate64.errors = vErrors;
return errors === 0;
}
validate64.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema27 = {"type":"integer","minimum":0,"maximum":4294967295};

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
if(data > 4294967295 || isNaN(data)){
validate67.errors = [{instancePath,schemaPath:"#/maximum",keyword:"maximum",params:{comparison: "<=", limit: 4294967295},message:"must be <= 4294967295"}];
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

const schema29 = {"type":"string","enum":["sql","console"]};

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
if(typeof data !== "string"){
validate69.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
if(!((data === "sql") || (data === "console"))){
validate69.errors = [{instancePath,schemaPath:"#/enum",keyword:"enum",params:{allowedValues: schema29.enum},message:"must be equal to one of the allowed values"}];
return false;
}
validate69.errors = vErrors;
return errors === 0;
}
validate69.evaluated = {"dynamicProps":false,"dynamicItems":false};


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
if((((data.sql === undefined) && (missing0 = "sql")) || ((data.cursor === undefined) && (missing0 = "cursor"))) || ((data.generation === undefined) && (missing0 = "generation"))){
validate61.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((((key0 === "sql") || (key0 === "cursor")) || (key0 === "generation")) || (key0 === "mode"))){
validate61.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.sql !== undefined){
const _errs2 = errors;
if(!(validate58(data.sql, {instancePath:instancePath+"/sql",parentData:data,parentDataProperty:"sql",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate58.errors : vErrors.concat(validate58.errors);
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
if(!(validate64(data.cursor, {instancePath:instancePath+"/cursor",parentData:data,parentDataProperty:"cursor",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate64.errors : vErrors.concat(validate64.errors);
errors = vErrors.length;
}
var valid0 = _errs3 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.generation !== undefined){
const _errs4 = errors;
if(!(validate67(data.generation, {instancePath:instancePath+"/generation",parentData:data,parentDataProperty:"generation",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate67.errors : vErrors.concat(validate67.errors);
errors = vErrors.length;
}
var valid0 = _errs4 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.mode !== undefined){
const _errs5 = errors;
if(!(validate69(data.mode, {instancePath:instancePath+"/mode",parentData:data,parentDataProperty:"mode",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate69.errors : vErrors.concat(validate69.errors);
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
validate61.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate61.errors = vErrors;
return errors === 0;
}
validate61.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema30 = {"type":"object","additionalProperties":false,"properties":{"sql":{"$ref":"#/$defs/Request/$defs/T3"},"parameters":{"$ref":"#/$defs/Request/$defs/T9"}},"required":["sql"]};
const schema31 = {"anyOf":[{"$ref":"#/$defs/Request/$defs/T10"},{"type":"null"}]};
const schema32 = {"type":"array","maxItems":65,"items":{"$ref":"#/$defs/Request/$defs/T11"}};
const schema33 = {"oneOf":[{"type":"object","additionalProperties":false,"required":["signed"],"properties":{"signed":{"$ref":"#/$defs/Request/$defs/T12"}}},{"type":"object","additionalProperties":false,"required":["unsigned"],"properties":{"unsigned":{"$ref":"#/$defs/Request/$defs/T12"}}},{"type":"object","additionalProperties":false,"required":["decimal"],"properties":{"decimal":{"$ref":"#/$defs/Request/$defs/T12"}}},{"type":"object","additionalProperties":false,"required":["float_bits"],"properties":{"float_bits":{"$ref":"#/$defs/Request/$defs/T12"}}},{"type":"object","additionalProperties":false,"required":["boolean"],"properties":{"boolean":{"$ref":"#/$defs/Request/$defs/T13"}}},{"type":"object","additionalProperties":false,"required":["utf8"],"properties":{"utf8":{"$ref":"#/$defs/Request/$defs/T12"}}},{"type":"object","additionalProperties":false,"required":["binary"],"properties":{"binary":{"$ref":"#/$defs/Request/$defs/T12"}}},{"type":"object","additionalProperties":false,"required":["date_days"],"properties":{"date_days":{"$ref":"#/$defs/Request/$defs/T12"}}},{"type":"object","additionalProperties":false,"required":["time_nanos"],"properties":{"time_nanos":{"$ref":"#/$defs/Request/$defs/T12"}}},{"type":"object","additionalProperties":false,"required":["timestamp_micros"],"properties":{"timestamp_micros":{"$ref":"#/$defs/Request/$defs/T12"}}},{"type":"object","additionalProperties":false,"required":["interval"],"properties":{"interval":{"$ref":"#/$defs/Request/$defs/T14"}}},{"type":"object","additionalProperties":false,"required":["uuid"],"properties":{"uuid":{"$ref":"#/$defs/Request/$defs/T12"}}}]};
const schema34 = {"type":"string","maxLength":131072};

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
if(typeof data === "string"){
if(func1(data) > 131072){
validate77.errors = [{instancePath,schemaPath:"#/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"}];
return false;
}
}
else {
validate77.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
}
validate77.errors = vErrors;
return errors === 0;
}
validate77.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema35 = {"type":"boolean"};

function validate82(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate82.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "boolean"){
validate82.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"}];
return false;
}
validate82.errors = vErrors;
return errors === 0;
}
validate82.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema36 = {"type":"object","additionalProperties":false,"properties":{"months":{"$ref":"#/$defs/Request/$defs/T12"},"days":{"$ref":"#/$defs/Request/$defs/T12"},"nanos":{"$ref":"#/$defs/Request/$defs/T12"}},"required":["months","days","nanos"]};

function validate89(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate89.evaluated;
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
validate89.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "months") || (key0 === "days")) || (key0 === "nanos"))){
validate89.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.months !== undefined){
const _errs2 = errors;
if(!(validate77(data.months, {instancePath:instancePath+"/months",parentData:data,parentDataProperty:"months",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate77.errors : vErrors.concat(validate77.errors);
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
if(!(validate77(data.days, {instancePath:instancePath+"/days",parentData:data,parentDataProperty:"days",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate77.errors : vErrors.concat(validate77.errors);
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
if(!(validate77(data.nanos, {instancePath:instancePath+"/nanos",parentData:data,parentDataProperty:"nanos",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate77.errors : vErrors.concat(validate77.errors);
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
validate89.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate89.errors = vErrors;
return errors === 0;
}
validate89.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


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
let passing0 = null;
const _errs1 = errors;
if(errors === _errs1){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((data.signed === undefined) && (missing0 = "signed")){
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
if(!(key0 === "signed")){
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
if(data.signed !== undefined){
if(!(validate77(data.signed, {instancePath:instancePath+"/signed",parentData:data,parentDataProperty:"signed",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate77.errors : vErrors.concat(validate77.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err2 = {instancePath,schemaPath:"#/oneOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err3 = {instancePath,schemaPath:"#/oneOf/1/required",keyword:"required",params:{missingProperty: missing1},message:"must have required property '"+missing1+"'"};
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
const err4 = {instancePath,schemaPath:"#/oneOf/1/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key1},message:"must NOT have additional properties"};
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
if(!(validate77(data.unsigned, {instancePath:instancePath+"/unsigned",parentData:data,parentDataProperty:"unsigned",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate77.errors : vErrors.concat(validate77.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err5 = {instancePath,schemaPath:"#/oneOf/1/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err6 = {instancePath,schemaPath:"#/oneOf/2/required",keyword:"required",params:{missingProperty: missing2},message:"must have required property '"+missing2+"'"};
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
const err7 = {instancePath,schemaPath:"#/oneOf/2/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key2},message:"must NOT have additional properties"};
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
if(!(validate77(data.decimal, {instancePath:instancePath+"/decimal",parentData:data,parentDataProperty:"decimal",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate77.errors : vErrors.concat(validate77.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err8 = {instancePath,schemaPath:"#/oneOf/2/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err9 = {instancePath,schemaPath:"#/oneOf/3/required",keyword:"required",params:{missingProperty: missing3},message:"must have required property '"+missing3+"'"};
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
const err10 = {instancePath,schemaPath:"#/oneOf/3/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key3},message:"must NOT have additional properties"};
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
if(!(validate77(data.float_bits, {instancePath:instancePath+"/float_bits",parentData:data,parentDataProperty:"float_bits",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate77.errors : vErrors.concat(validate77.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err11 = {instancePath,schemaPath:"#/oneOf/3/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err12 = {instancePath,schemaPath:"#/oneOf/4/required",keyword:"required",params:{missingProperty: missing4},message:"must have required property '"+missing4+"'"};
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
const err13 = {instancePath,schemaPath:"#/oneOf/4/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key4},message:"must NOT have additional properties"};
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
if(!(validate82(data.boolean, {instancePath:instancePath+"/boolean",parentData:data,parentDataProperty:"boolean",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate82.errors : vErrors.concat(validate82.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err14 = {instancePath,schemaPath:"#/oneOf/4/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err15 = {instancePath,schemaPath:"#/oneOf/5/required",keyword:"required",params:{missingProperty: missing5},message:"must have required property '"+missing5+"'"};
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
const err16 = {instancePath,schemaPath:"#/oneOf/5/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key5},message:"must NOT have additional properties"};
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
if(!(validate77(data.utf8, {instancePath:instancePath+"/utf8",parentData:data,parentDataProperty:"utf8",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate77.errors : vErrors.concat(validate77.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err17 = {instancePath,schemaPath:"#/oneOf/5/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err18 = {instancePath,schemaPath:"#/oneOf/6/required",keyword:"required",params:{missingProperty: missing6},message:"must have required property '"+missing6+"'"};
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
const err19 = {instancePath,schemaPath:"#/oneOf/6/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key6},message:"must NOT have additional properties"};
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
if(!(validate77(data.binary, {instancePath:instancePath+"/binary",parentData:data,parentDataProperty:"binary",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate77.errors : vErrors.concat(validate77.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err20 = {instancePath,schemaPath:"#/oneOf/6/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err21 = {instancePath,schemaPath:"#/oneOf/7/required",keyword:"required",params:{missingProperty: missing7},message:"must have required property '"+missing7+"'"};
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
const err22 = {instancePath,schemaPath:"#/oneOf/7/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key7},message:"must NOT have additional properties"};
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
if(!(validate77(data.date_days, {instancePath:instancePath+"/date_days",parentData:data,parentDataProperty:"date_days",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate77.errors : vErrors.concat(validate77.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err23 = {instancePath,schemaPath:"#/oneOf/7/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err24 = {instancePath,schemaPath:"#/oneOf/8/required",keyword:"required",params:{missingProperty: missing8},message:"must have required property '"+missing8+"'"};
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
const err25 = {instancePath,schemaPath:"#/oneOf/8/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key8},message:"must NOT have additional properties"};
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
if(!(validate77(data.time_nanos, {instancePath:instancePath+"/time_nanos",parentData:data,parentDataProperty:"time_nanos",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate77.errors : vErrors.concat(validate77.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err26 = {instancePath,schemaPath:"#/oneOf/8/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err27 = {instancePath,schemaPath:"#/oneOf/9/required",keyword:"required",params:{missingProperty: missing9},message:"must have required property '"+missing9+"'"};
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
const err28 = {instancePath,schemaPath:"#/oneOf/9/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key9},message:"must NOT have additional properties"};
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
if(!(validate77(data.timestamp_micros, {instancePath:instancePath+"/timestamp_micros",parentData:data,parentDataProperty:"timestamp_micros",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate77.errors : vErrors.concat(validate77.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err29 = {instancePath,schemaPath:"#/oneOf/9/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err30 = {instancePath,schemaPath:"#/oneOf/10/required",keyword:"required",params:{missingProperty: missing10},message:"must have required property '"+missing10+"'"};
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
const err31 = {instancePath,schemaPath:"#/oneOf/10/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key10},message:"must NOT have additional properties"};
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
if(!(validate89(data.interval, {instancePath:instancePath+"/interval",parentData:data,parentDataProperty:"interval",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate89.errors : vErrors.concat(validate89.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err32 = {instancePath,schemaPath:"#/oneOf/10/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err33 = {instancePath,schemaPath:"#/oneOf/11/required",keyword:"required",params:{missingProperty: missing11},message:"must have required property '"+missing11+"'"};
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
const err34 = {instancePath,schemaPath:"#/oneOf/11/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key11},message:"must NOT have additional properties"};
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
if(!(validate77(data.uuid, {instancePath:instancePath+"/uuid",parentData:data,parentDataProperty:"uuid",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate77.errors : vErrors.concat(validate77.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err35 = {instancePath,schemaPath:"#/oneOf/11/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err36 = {instancePath,schemaPath:"#/oneOf",keyword:"oneOf",params:{passingSchemas: passing0},message:"must match exactly one schema in oneOf"};
if(vErrors === null){
vErrors = [err36];
}
else {
vErrors.push(err36);
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
if(data.length > 65){
validate75.errors = [{instancePath,schemaPath:"#/maxItems",keyword:"maxItems",params:{limit: 65},message:"must NOT have more than 65 items"}];
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
else {
validate75.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "array"},message:"must be array"}];
return false;
}
}
validate75.errors = vErrors;
return errors === 0;
}
validate75.evaluated = {"items":true,"dynamicProps":false,"dynamicItems":false};


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
if(!(validate75(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate75.errors : vErrors.concat(validate75.errors);
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
evaluated0.items = items0;
return errors === 0;
}
validate74.evaluated = {"dynamicProps":false,"dynamicItems":true};


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
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((data.sql === undefined) && (missing0 = "sql")){
validate72.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "sql") || (key0 === "parameters"))){
validate72.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.sql !== undefined){
const _errs2 = errors;
if(!(validate58(data.sql, {instancePath:instancePath+"/sql",parentData:data,parentDataProperty:"sql",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate58.errors : vErrors.concat(validate58.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.parameters !== undefined){
const _errs3 = errors;
if(!(validate74(data.parameters, {instancePath:instancePath+"/parameters",parentData:data,parentDataProperty:"parameters",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate74.errors : vErrors.concat(validate74.errors);
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
validate72.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate72.errors = vErrors;
return errors === 0;
}
validate72.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema37 = {"type":"object","additionalProperties":false,"properties":{"sql":{"$ref":"#/$defs/Request/$defs/T3"}},"required":["sql"]};

function validate99(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate99.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((data.sql === undefined) && (missing0 = "sql")){
validate99.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(key0 === "sql")){
validate99.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.sql !== undefined){
if(!(validate58(data.sql, {instancePath:instancePath+"/sql",parentData:data,parentDataProperty:"sql",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate58.errors : vErrors.concat(validate58.errors);
errors = vErrors.length;
}
}
}
}
}
else {
validate99.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate99.errors = vErrors;
return errors === 0;
}
validate99.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema38 = {"type":"object","additionalProperties":false,"properties":{"namespace":{"$ref":"#/$defs/Request/$defs/T3"},"bundle":{"$ref":"#/$defs/Request/$defs/T3"},"prepare_only":{"$ref":"#/$defs/Request/$defs/T17"}},"required":["namespace","bundle"]};
const schema39 = {"type":"boolean"};

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
if(typeof data !== "boolean"){
validate105.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"}];
return false;
}
validate105.errors = vErrors;
return errors === 0;
}
validate105.evaluated = {"dynamicProps":false,"dynamicItems":false};


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
if(((data.namespace === undefined) && (missing0 = "namespace")) || ((data.bundle === undefined) && (missing0 = "bundle"))){
validate102.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "namespace") || (key0 === "bundle")) || (key0 === "prepare_only"))){
validate102.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.namespace !== undefined){
const _errs2 = errors;
if(!(validate58(data.namespace, {instancePath:instancePath+"/namespace",parentData:data,parentDataProperty:"namespace",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate58.errors : vErrors.concat(validate58.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.bundle !== undefined){
const _errs3 = errors;
if(!(validate58(data.bundle, {instancePath:instancePath+"/bundle",parentData:data,parentDataProperty:"bundle",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate58.errors : vErrors.concat(validate58.errors);
errors = vErrors.length;
}
var valid0 = _errs3 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.prepare_only !== undefined){
const _errs4 = errors;
if(!(validate105(data.prepare_only, {instancePath:instancePath+"/prepare_only",parentData:data,parentDataProperty:"prepare_only",rootData,dynamicAnchors}))){
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

const schema40 = {"type":"object","additionalProperties":false,"properties":{"template":{"$ref":"#/$defs/Request/$defs/T3"},"operation":{"$ref":"#/$defs/Request/$defs/T3"}},"required":["template","operation"]};

function validate108(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate108.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if(((data.template === undefined) && (missing0 = "template")) || ((data.operation === undefined) && (missing0 = "operation"))){
validate108.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "template") || (key0 === "operation"))){
validate108.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.template !== undefined){
const _errs2 = errors;
if(!(validate58(data.template, {instancePath:instancePath+"/template",parentData:data,parentDataProperty:"template",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate58.errors : vErrors.concat(validate58.errors);
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
if(!(validate58(data.operation, {instancePath:instancePath+"/operation",parentData:data,parentDataProperty:"operation",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate58.errors : vErrors.concat(validate58.errors);
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
validate108.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate108.errors = vErrors;
return errors === 0;
}
validate108.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema41 = {"type":"object","additionalProperties":false,"properties":{"namespace":{"$ref":"#/$defs/Request/$defs/T3"},"bundle":{"$ref":"#/$defs/Request/$defs/T3"},"generation":{"$ref":"#/$defs/Request/$defs/T3"}},"required":["namespace","bundle","generation"]};

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
if((((data.namespace === undefined) && (missing0 = "namespace")) || ((data.bundle === undefined) && (missing0 = "bundle"))) || ((data.generation === undefined) && (missing0 = "generation"))){
validate112.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "namespace") || (key0 === "bundle")) || (key0 === "generation"))){
validate112.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.namespace !== undefined){
const _errs2 = errors;
if(!(validate58(data.namespace, {instancePath:instancePath+"/namespace",parentData:data,parentDataProperty:"namespace",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate58.errors : vErrors.concat(validate58.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.bundle !== undefined){
const _errs3 = errors;
if(!(validate58(data.bundle, {instancePath:instancePath+"/bundle",parentData:data,parentDataProperty:"bundle",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate58.errors : vErrors.concat(validate58.errors);
errors = vErrors.length;
}
var valid0 = _errs3 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.generation !== undefined){
const _errs4 = errors;
if(!(validate58(data.generation, {instancePath:instancePath+"/generation",parentData:data,parentDataProperty:"generation",rootData,dynamicAnchors}))){
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
validate112.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate112.errors = vErrors;
return errors === 0;
}
validate112.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema42 = {"type":"object","additionalProperties":false,"properties":{"expected":{"$ref":"#/$defs/Request/$defs/T3"},"limit":{"$ref":"#/$defs/Request/$defs/T21"}},"required":["expected","limit"]};
const schema43 = {"type":"integer","minimum":0,"maximum":255};

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
if(!(((typeof data == "number") && (!(data % 1) && !isNaN(data))) && (isFinite(data)))){
validate120.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "integer"},message:"must be integer"}];
return false;
}
if(errors === 0){
if((typeof data == "number") && (isFinite(data))){
if(data > 255 || isNaN(data)){
validate120.errors = [{instancePath,schemaPath:"#/maximum",keyword:"maximum",params:{comparison: "<=", limit: 255},message:"must be <= 255"}];
return false;
}
else {
if(data < 0 || isNaN(data)){
validate120.errors = [{instancePath,schemaPath:"#/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"}];
return false;
}
}
}
}
validate120.errors = vErrors;
return errors === 0;
}
validate120.evaluated = {"dynamicProps":false,"dynamicItems":false};


function validate117(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate117.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if(((data.expected === undefined) && (missing0 = "expected")) || ((data.limit === undefined) && (missing0 = "limit"))){
validate117.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "expected") || (key0 === "limit"))){
validate117.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.expected !== undefined){
const _errs2 = errors;
if(!(validate58(data.expected, {instancePath:instancePath+"/expected",parentData:data,parentDataProperty:"expected",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate58.errors : vErrors.concat(validate58.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.limit !== undefined){
const _errs3 = errors;
if(!(validate120(data.limit, {instancePath:instancePath+"/limit",parentData:data,parentDataProperty:"limit",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate120.errors : vErrors.concat(validate120.errors);
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
validate117.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate117.errors = vErrors;
return errors === 0;
}
validate117.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema45 = {"anyOf":[{"$ref":"#/$defs/Request/$defs/T3"},{"type":"null"}]};

function validate124(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate124.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate58(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate58.errors : vErrors.concat(validate58.errors);
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
validate124.errors = vErrors;
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
validate124.errors = vErrors;
return errors === 0;
}
validate124.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema46 = {"type":"object","additionalProperties":false,"properties":{"token":{"$ref":"#/$defs/Request/$defs/T3"}},"required":["token"]};

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
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((data.token === undefined) && (missing0 = "token")){
validate127.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(key0 === "token")){
validate127.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.token !== undefined){
if(!(validate58(data.token, {instancePath:instancePath+"/token",parentData:data,parentDataProperty:"token",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate58.errors : vErrors.concat(validate58.errors);
errors = vErrors.length;
}
}
}
}
}
else {
validate127.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate127.errors = vErrors;
return errors === 0;
}
validate127.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema47 = {"type":"integer","minimum":0,"maximum":9007199254740991};

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
if(!(((typeof data == "number") && (!(data % 1) && !isNaN(data))) && (isFinite(data)))){
validate131.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "integer"},message:"must be integer"}];
return false;
}
if(errors === 0){
if((typeof data == "number") && (isFinite(data))){
if(data > 9007199254740991 || isNaN(data)){
validate131.errors = [{instancePath,schemaPath:"#/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"}];
return false;
}
else {
if(data < 0 || isNaN(data)){
validate131.errors = [{instancePath,schemaPath:"#/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"}];
return false;
}
}
}
}
validate131.errors = vErrors;
return errors === 0;
}
validate131.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema49 = {"type":"object","additionalProperties":false,"properties":{"namespace":{"$ref":"#/$defs/Request/$defs/T3"},"cursor":{"$ref":"#/$defs/Request/$defs/T22"}},"required":["namespace"]};

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
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((data.namespace === undefined) && (missing0 = "namespace")){
validate134.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "namespace") || (key0 === "cursor"))){
validate134.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.namespace !== undefined){
const _errs2 = errors;
if(!(validate58(data.namespace, {instancePath:instancePath+"/namespace",parentData:data,parentDataProperty:"namespace",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate58.errors : vErrors.concat(validate58.errors);
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
if(!(validate124(data.cursor, {instancePath:instancePath+"/cursor",parentData:data,parentDataProperty:"cursor",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate124.errors : vErrors.concat(validate124.errors);
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
validate134.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate134.errors = vErrors;
return errors === 0;
}
validate134.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema50 = {"type":"object","additionalProperties":false,"properties":{"namespace":{"$ref":"#/$defs/Request/$defs/T3"},"operation":{"$ref":"#/$defs/Request/$defs/T27"}},"required":["namespace","operation"]};
const schema51 = {"type":"string","enum":["cancel","collect","retire"]};

function validate140(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate140.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate140.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
if(!(((data === "cancel") || (data === "collect")) || (data === "retire"))){
validate140.errors = [{instancePath,schemaPath:"#/enum",keyword:"enum",params:{allowedValues: schema51.enum},message:"must be equal to one of the allowed values"}];
return false;
}
validate140.errors = vErrors;
return errors === 0;
}
validate140.evaluated = {"dynamicProps":false,"dynamicItems":false};


function validate138(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate138.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if(((data.namespace === undefined) && (missing0 = "namespace")) || ((data.operation === undefined) && (missing0 = "operation"))){
validate138.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "namespace") || (key0 === "operation"))){
validate138.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.namespace !== undefined){
const _errs2 = errors;
if(!(validate58(data.namespace, {instancePath:instancePath+"/namespace",parentData:data,parentDataProperty:"namespace",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate58.errors : vErrors.concat(validate58.errors);
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
if(!(validate140(data.operation, {instancePath:instancePath+"/operation",parentData:data,parentDataProperty:"operation",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate140.errors : vErrors.concat(validate140.errors);
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
validate138.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate138.errors = vErrors;
return errors === 0;
}
validate138.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


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
if(!(validate54(data.describe, {instancePath:instancePath+"/describe",parentData:data,parentDataProperty:"describe",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate54.errors : vErrors.concat(validate54.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err2 = {instancePath,schemaPath:"#/oneOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
if((data.sql_capabilities === undefined) && (missing1 = "sql_capabilities")){
const err3 = {instancePath,schemaPath:"#/oneOf/1/required",keyword:"required",params:{missingProperty: missing1},message:"must have required property '"+missing1+"'"};
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
if(!(key1 === "sql_capabilities")){
const err4 = {instancePath,schemaPath:"#/oneOf/1/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key1},message:"must NOT have additional properties"};
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
if(data.sql_capabilities !== undefined){
if(!(validate54(data.sql_capabilities, {instancePath:instancePath+"/sql_capabilities",parentData:data,parentDataProperty:"sql_capabilities",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate54.errors : vErrors.concat(validate54.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err5 = {instancePath,schemaPath:"#/oneOf/1/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
if((data.suggest === undefined) && (missing2 = "suggest")){
const err6 = {instancePath,schemaPath:"#/oneOf/2/required",keyword:"required",params:{missingProperty: missing2},message:"must have required property '"+missing2+"'"};
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
if(!(key2 === "suggest")){
const err7 = {instancePath,schemaPath:"#/oneOf/2/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key2},message:"must NOT have additional properties"};
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
if(data.suggest !== undefined){
if(!(validate57(data.suggest, {instancePath:instancePath+"/suggest",parentData:data,parentDataProperty:"suggest",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate57.errors : vErrors.concat(validate57.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err8 = {instancePath,schemaPath:"#/oneOf/2/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
if((data.assist === undefined) && (missing3 = "assist")){
const err9 = {instancePath,schemaPath:"#/oneOf/3/required",keyword:"required",params:{missingProperty: missing3},message:"must have required property '"+missing3+"'"};
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
if(!(key3 === "assist")){
const err10 = {instancePath,schemaPath:"#/oneOf/3/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key3},message:"must NOT have additional properties"};
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
if(data.assist !== undefined){
if(!(validate61(data.assist, {instancePath:instancePath+"/assist",parentData:data,parentDataProperty:"assist",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate61.errors : vErrors.concat(validate61.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err11 = {instancePath,schemaPath:"#/oneOf/3/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
if((data.compile === undefined) && (missing4 = "compile")){
const err12 = {instancePath,schemaPath:"#/oneOf/4/required",keyword:"required",params:{missingProperty: missing4},message:"must have required property '"+missing4+"'"};
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
if(!(key4 === "compile")){
const err13 = {instancePath,schemaPath:"#/oneOf/4/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key4},message:"must NOT have additional properties"};
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
if(data.compile !== undefined){
if(!(validate72(data.compile, {instancePath:instancePath+"/compile",parentData:data,parentDataProperty:"compile",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate72.errors : vErrors.concat(validate72.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err14 = {instancePath,schemaPath:"#/oneOf/4/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
if((data.inspect === undefined) && (missing5 = "inspect")){
const err15 = {instancePath,schemaPath:"#/oneOf/5/required",keyword:"required",params:{missingProperty: missing5},message:"must have required property '"+missing5+"'"};
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
if(!(key5 === "inspect")){
const err16 = {instancePath,schemaPath:"#/oneOf/5/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key5},message:"must NOT have additional properties"};
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
if(data.inspect !== undefined){
if(!(validate99(data.inspect, {instancePath:instancePath+"/inspect",parentData:data,parentDataProperty:"inspect",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate99.errors : vErrors.concat(validate99.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err17 = {instancePath,schemaPath:"#/oneOf/5/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
if((data.next === undefined) && (missing6 = "next")){
const err18 = {instancePath,schemaPath:"#/oneOf/6/required",keyword:"required",params:{missingProperty: missing6},message:"must have required property '"+missing6+"'"};
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
if(!(key6 === "next")){
const err19 = {instancePath,schemaPath:"#/oneOf/6/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key6},message:"must NOT have additional properties"};
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
if(data.next !== undefined){
if(!(validate102(data.next, {instancePath:instancePath+"/next",parentData:data,parentDataProperty:"next",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate102.errors : vErrors.concat(validate102.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err20 = {instancePath,schemaPath:"#/oneOf/6/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
if((data.refresh === undefined) && (missing7 = "refresh")){
const err21 = {instancePath,schemaPath:"#/oneOf/7/required",keyword:"required",params:{missingProperty: missing7},message:"must have required property '"+missing7+"'"};
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
if(!(key7 === "refresh")){
const err22 = {instancePath,schemaPath:"#/oneOf/7/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key7},message:"must NOT have additional properties"};
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
if(data.refresh !== undefined){
if(!(validate108(data.refresh, {instancePath:instancePath+"/refresh",parentData:data,parentDataProperty:"refresh",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate108.errors : vErrors.concat(validate108.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err23 = {instancePath,schemaPath:"#/oneOf/7/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
if((data.next_draft === undefined) && (missing8 = "next_draft")){
const err24 = {instancePath,schemaPath:"#/oneOf/8/required",keyword:"required",params:{missingProperty: missing8},message:"must have required property '"+missing8+"'"};
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
if(!(key8 === "next_draft")){
const err25 = {instancePath,schemaPath:"#/oneOf/8/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key8},message:"must NOT have additional properties"};
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
if(data.next_draft !== undefined){
if(!(validate112(data.next_draft, {instancePath:instancePath+"/next_draft",parentData:data,parentDataProperty:"next_draft",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate112.errors : vErrors.concat(validate112.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err26 = {instancePath,schemaPath:"#/oneOf/8/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
if((data.draft_open === undefined) && (missing9 = "draft_open")){
const err27 = {instancePath,schemaPath:"#/oneOf/9/required",keyword:"required",params:{missingProperty: missing9},message:"must have required property '"+missing9+"'"};
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
if(!(key9 === "draft_open")){
const err28 = {instancePath,schemaPath:"#/oneOf/9/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key9},message:"must NOT have additional properties"};
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
if(data.draft_open !== undefined){
if(!(validate117(data.draft_open, {instancePath:instancePath+"/draft_open",parentData:data,parentDataProperty:"draft_open",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate117.errors : vErrors.concat(validate117.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err29 = {instancePath,schemaPath:"#/oneOf/9/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
if((data.draft_close === undefined) && (missing10 = "draft_close")){
const err30 = {instancePath,schemaPath:"#/oneOf/10/required",keyword:"required",params:{missingProperty: missing10},message:"must have required property '"+missing10+"'"};
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
if(!(key10 === "draft_close")){
const err31 = {instancePath,schemaPath:"#/oneOf/10/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key10},message:"must NOT have additional properties"};
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
if(data.draft_close !== undefined){
if(!(validate58(data.draft_close, {instancePath:instancePath+"/draft_close",parentData:data,parentDataProperty:"draft_close",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate58.errors : vErrors.concat(validate58.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err32 = {instancePath,schemaPath:"#/oneOf/10/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
if((data.draft_status === undefined) && (missing11 = "draft_status")){
const err33 = {instancePath,schemaPath:"#/oneOf/11/required",keyword:"required",params:{missingProperty: missing11},message:"must have required property '"+missing11+"'"};
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
if(!(key11 === "draft_status")){
const err34 = {instancePath,schemaPath:"#/oneOf/11/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key11},message:"must NOT have additional properties"};
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
if(data.draft_status !== undefined){
if(!(validate124(data.draft_status, {instancePath:instancePath+"/draft_status",parentData:data,parentDataProperty:"draft_status",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate124.errors : vErrors.concat(validate124.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err35 = {instancePath,schemaPath:"#/oneOf/11/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
if((data.submit === undefined) && (missing12 = "submit")){
const err36 = {instancePath,schemaPath:"#/oneOf/12/required",keyword:"required",params:{missingProperty: missing12},message:"must have required property '"+missing12+"'"};
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
if(!(key12 === "submit")){
const err37 = {instancePath,schemaPath:"#/oneOf/12/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key12},message:"must NOT have additional properties"};
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
if(data.submit !== undefined){
if(!(validate127(data.submit, {instancePath:instancePath+"/submit",parentData:data,parentDataProperty:"submit",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate127.errors : vErrors.concat(validate127.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err38 = {instancePath,schemaPath:"#/oneOf/12/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
if((data.observe === undefined) && (missing13 = "observe")){
const err39 = {instancePath,schemaPath:"#/oneOf/13/required",keyword:"required",params:{missingProperty: missing13},message:"must have required property '"+missing13+"'"};
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
if(!(key13 === "observe")){
const err40 = {instancePath,schemaPath:"#/oneOf/13/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key13},message:"must NOT have additional properties"};
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
if(data.observe !== undefined){
if(!(validate131(data.observe, {instancePath:instancePath+"/observe",parentData:data,parentDataProperty:"observe",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate131.errors : vErrors.concat(validate131.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err41 = {instancePath,schemaPath:"#/oneOf/13/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
if((data.status === undefined) && (missing14 = "status")){
const err42 = {instancePath,schemaPath:"#/oneOf/14/required",keyword:"required",params:{missingProperty: missing14},message:"must have required property '"+missing14+"'"};
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
if(!(key14 === "status")){
const err43 = {instancePath,schemaPath:"#/oneOf/14/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key14},message:"must NOT have additional properties"};
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
if(data.status !== undefined){
if(!(validate58(data.status, {instancePath:instancePath+"/status",parentData:data,parentDataProperty:"status",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate58.errors : vErrors.concat(validate58.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err44 = {instancePath,schemaPath:"#/oneOf/14/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
if((data.page === undefined) && (missing15 = "page")){
const err45 = {instancePath,schemaPath:"#/oneOf/15/required",keyword:"required",params:{missingProperty: missing15},message:"must have required property '"+missing15+"'"};
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
if(!(key15 === "page")){
const err46 = {instancePath,schemaPath:"#/oneOf/15/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key15},message:"must NOT have additional properties"};
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
if(data.page !== undefined){
if(!(validate134(data.page, {instancePath:instancePath+"/page",parentData:data,parentDataProperty:"page",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate134.errors : vErrors.concat(validate134.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err47 = {instancePath,schemaPath:"#/oneOf/15/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
if((data.prepare_control === undefined) && (missing16 = "prepare_control")){
const err48 = {instancePath,schemaPath:"#/oneOf/16/required",keyword:"required",params:{missingProperty: missing16},message:"must have required property '"+missing16+"'"};
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
if(!(key16 === "prepare_control")){
const err49 = {instancePath,schemaPath:"#/oneOf/16/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key16},message:"must NOT have additional properties"};
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
if(data.prepare_control !== undefined){
if(!(validate138(data.prepare_control, {instancePath:instancePath+"/prepare_control",parentData:data,parentDataProperty:"prepare_control",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate138.errors : vErrors.concat(validate138.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err50 = {instancePath,schemaPath:"#/oneOf/16/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
}
}
}
}
}
}
}
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
const err51 = {instancePath,schemaPath:"#/oneOf",keyword:"oneOf",params:{passingSchemas: passing0},message:"must match exactly one schema in oneOf"};
if(vErrors === null){
vErrors = [err51];
}
else {
vErrors.push(err51);
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

export const Response = validate143;
const schema52 = {"oneOf":[{"type":"object","additionalProperties":false,"required":["description"],"properties":{"description":{"$ref":"#/$defs/Response/$defs/T1"}}},{"type":"object","additionalProperties":false,"required":["sql_capabilities"],"properties":{"sql_capabilities":{"$ref":"#/$defs/Response/$defs/T60"}}},{"type":"object","additionalProperties":false,"required":["suggestions"],"properties":{"suggestions":{"$ref":"#/$defs/Response/$defs/T61"}}},{"type":"object","additionalProperties":false,"required":["assistance"],"properties":{"assistance":{"$ref":"#/$defs/Response/$defs/T64"}}},{"type":"object","additionalProperties":false,"required":["compiled"],"properties":{"compiled":{"$ref":"#/$defs/Response/$defs/T71"}}},{"type":"object","additionalProperties":false,"required":["inspection"],"properties":{"inspection":{"$ref":"#/$defs/Response/$defs/T99"}}},{"type":"object","additionalProperties":false,"required":["prepared"],"properties":{"prepared":{"$ref":"#/$defs/Response/$defs/T126"}}},{"type":"object","additionalProperties":false,"required":["receipt"],"properties":{"receipt":{"$ref":"#/$defs/Response/$defs/T128"}}},{"type":"object","additionalProperties":false,"required":["observation"],"properties":{"observation":{"$ref":"#/$defs/Response/$defs/T129"}}},{"type":"object","additionalProperties":false,"required":["status"],"properties":{"status":{"$ref":"#/$defs/Response/$defs/T131"}}},{"type":"object","additionalProperties":false,"required":["page"],"properties":{"page":{"$ref":"#/$defs/Response/$defs/T174"}}},{"type":"object","additionalProperties":false,"required":["draft"],"properties":{"draft":{"$ref":"#/$defs/Response/$defs/T212"}}}]};
const schema53 = {"type":"object","additionalProperties":false,"properties":{"connection":{"$ref":"#/$defs/Response/$defs/T2"},"name":{"$ref":"#/$defs/Response/$defs/T5"},"source":{"$ref":"#/$defs/Response/$defs/T6"},"sql":{"$ref":"#/$defs/Response/$defs/T57"},"budgets":{"$ref":"#/$defs/Response/$defs/T55"},"columns":{"$ref":"#/$defs/Response/$defs/T58"}},"required":["connection","name","source","sql","budgets","columns"]};
const schema54 = {"type":"object","additionalProperties":false,"properties":{"realm":{"$ref":"#/$defs/Response/$defs/T3"},"principal":{"$ref":"#/$defs/Response/$defs/T3"},"source":{"$ref":"#/$defs/Response/$defs/T3"},"resource":{"$ref":"#/$defs/Response/$defs/T3"},"requester":{"$ref":"#/$defs/Response/$defs/T3"},"requests":{"$ref":"#/$defs/Response/$defs/T3"},"role":{"$ref":"#/$defs/Response/$defs/T4"}},"required":["realm","principal","source","resource","requester","requests","role"]};

function validate146(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate146.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(!(((typeof data == "number") && (!(data % 1) && !isNaN(data))) && (isFinite(data)))){
validate146.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "integer"},message:"must be integer"}];
return false;
}
if(errors === 0){
if((typeof data == "number") && (isFinite(data))){
if(data > 9007199254740991 || isNaN(data)){
validate146.errors = [{instancePath,schemaPath:"#/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"}];
return false;
}
else {
if(data < 0 || isNaN(data)){
validate146.errors = [{instancePath,schemaPath:"#/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"}];
return false;
}
}
}
}
validate146.errors = vErrors;
return errors === 0;
}
validate146.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema56 = {"anyOf":[{"$ref":"#/$defs/Response/$defs/T3"},{"type":"null"}]};

function validate153(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate153.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate146(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate146.errors : vErrors.concat(validate146.errors);
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
validate153.errors = vErrors;
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
validate153.errors = vErrors;
return errors === 0;
}
validate153.evaluated = {"dynamicProps":false,"dynamicItems":false};


function validate145(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate145.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((((((((data.realm === undefined) && (missing0 = "realm")) || ((data.principal === undefined) && (missing0 = "principal"))) || ((data.source === undefined) && (missing0 = "source"))) || ((data.resource === undefined) && (missing0 = "resource"))) || ((data.requester === undefined) && (missing0 = "requester"))) || ((data.requests === undefined) && (missing0 = "requests"))) || ((data.role === undefined) && (missing0 = "role"))){
validate145.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((((((key0 === "realm") || (key0 === "principal")) || (key0 === "source")) || (key0 === "resource")) || (key0 === "requester")) || (key0 === "requests")) || (key0 === "role"))){
validate145.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.realm !== undefined){
const _errs2 = errors;
if(!(validate146(data.realm, {instancePath:instancePath+"/realm",parentData:data,parentDataProperty:"realm",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate146.errors : vErrors.concat(validate146.errors);
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
if(!(validate146(data.principal, {instancePath:instancePath+"/principal",parentData:data,parentDataProperty:"principal",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate146.errors : vErrors.concat(validate146.errors);
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
if(!(validate146(data.source, {instancePath:instancePath+"/source",parentData:data,parentDataProperty:"source",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate146.errors : vErrors.concat(validate146.errors);
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
if(!(validate146(data.resource, {instancePath:instancePath+"/resource",parentData:data,parentDataProperty:"resource",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate146.errors : vErrors.concat(validate146.errors);
errors = vErrors.length;
}
var valid0 = _errs5 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.requester !== undefined){
const _errs6 = errors;
if(!(validate146(data.requester, {instancePath:instancePath+"/requester",parentData:data,parentDataProperty:"requester",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate146.errors : vErrors.concat(validate146.errors);
errors = vErrors.length;
}
var valid0 = _errs6 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.requests !== undefined){
const _errs7 = errors;
if(!(validate146(data.requests, {instancePath:instancePath+"/requests",parentData:data,parentDataProperty:"requests",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate146.errors : vErrors.concat(validate146.errors);
errors = vErrors.length;
}
var valid0 = _errs7 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.role !== undefined){
const _errs8 = errors;
if(!(validate153(data.role, {instancePath:instancePath+"/role",parentData:data,parentDataProperty:"role",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate153.errors : vErrors.concat(validate153.errors);
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
validate145.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate145.errors = vErrors;
return errors === 0;
}
validate145.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema57 = {"type":"string","maxLength":131072};

function validate157(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate157.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(typeof data === "string"){
if(func1(data) > 131072){
validate157.errors = [{instancePath,schemaPath:"#/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"}];
return false;
}
}
else {
validate157.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
}
validate157.errors = vErrors;
return errors === 0;
}
validate157.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema58 = {"type":"object","additionalProperties":false,"properties":{"capabilities":{"$ref":"#/$defs/Response/$defs/T7"},"source":{"$ref":"#/$defs/Response/$defs/T12"},"resource_revision":{"$ref":"#/$defs/Response/$defs/T3"},"policy_revision":{"$ref":"#/$defs/Response/$defs/T5"},"limits":{"$ref":"#/$defs/Response/$defs/T55"},"active":{"$ref":"#/$defs/Response/$defs/T56"}},"required":["capabilities","source","resource_revision","policy_revision","limits","active"]};
const schema59 = {"type":"object","additionalProperties":false,"properties":{"version":{"$ref":"#/$defs/Response/$defs/T8"},"source":{"$ref":"#/$defs/Response/$defs/T8"},"plan":{"$ref":"#/$defs/Response/$defs/T8"},"result":{"$ref":"#/$defs/Response/$defs/T8"},"bundle_bytes":{"$ref":"#/$defs/Response/$defs/T9"},"part_bytes":{"$ref":"#/$defs/Response/$defs/T10"},"segment_bytes":{"$ref":"#/$defs/Response/$defs/T9"},"batch_rows":{"$ref":"#/$defs/Response/$defs/T8"},"columns":{"$ref":"#/$defs/Response/$defs/T8"},"kv":{"$ref":"#/$defs/Response/$defs/T11"},"table":{"$ref":"#/$defs/Response/$defs/T11"},"document":{"$ref":"#/$defs/Response/$defs/T11"}},"required":["version","source","plan","result","bundle_bytes","part_bytes","segment_bytes","batch_rows","columns","kv","table","document"]};
const func4 = Object.prototype.hasOwnProperty;

function validate161(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate161.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(!(((typeof data == "number") && (!(data % 1) && !isNaN(data))) && (isFinite(data)))){
validate161.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "integer"},message:"must be integer"}];
return false;
}
if(errors === 0){
if((typeof data == "number") && (isFinite(data))){
if(data > 255 || isNaN(data)){
validate161.errors = [{instancePath,schemaPath:"#/maximum",keyword:"maximum",params:{comparison: "<=", limit: 255},message:"must be <= 255"}];
return false;
}
else {
if(data < 0 || isNaN(data)){
validate161.errors = [{instancePath,schemaPath:"#/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"}];
return false;
}
}
}
}
validate161.errors = vErrors;
return errors === 0;
}
validate161.evaluated = {"dynamicProps":false,"dynamicItems":false};


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
if(!(((typeof data == "number") && (!(data % 1) && !isNaN(data))) && (isFinite(data)))){
validate166.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "integer"},message:"must be integer"}];
return false;
}
if(errors === 0){
if((typeof data == "number") && (isFinite(data))){
if(data > 4294967295 || isNaN(data)){
validate166.errors = [{instancePath,schemaPath:"#/maximum",keyword:"maximum",params:{comparison: "<=", limit: 4294967295},message:"must be <= 4294967295"}];
return false;
}
else {
if(data < 0 || isNaN(data)){
validate166.errors = [{instancePath,schemaPath:"#/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"}];
return false;
}
}
}
}
validate166.errors = vErrors;
return errors === 0;
}
validate166.evaluated = {"dynamicProps":false,"dynamicItems":false};


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
validate168.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "integer"},message:"must be integer"}];
return false;
}
if(errors === 0){
if((typeof data == "number") && (isFinite(data))){
if(data > 65535 || isNaN(data)){
validate168.errors = [{instancePath,schemaPath:"#/maximum",keyword:"maximum",params:{comparison: "<=", limit: 65535},message:"must be <= 65535"}];
return false;
}
else {
if(data < 0 || isNaN(data)){
validate168.errors = [{instancePath,schemaPath:"#/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"}];
return false;
}
}
}
}
validate168.errors = vErrors;
return errors === 0;
}
validate168.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema63 = {"type":"boolean"};

function validate173(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate173.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "boolean"){
validate173.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"}];
return false;
}
validate173.errors = vErrors;
return errors === 0;
}
validate173.evaluated = {"dynamicProps":false,"dynamicItems":false};


function validate160(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate160.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if(((((((((((((data.version === undefined) && (missing0 = "version")) || ((data.source === undefined) && (missing0 = "source"))) || ((data.plan === undefined) && (missing0 = "plan"))) || ((data.result === undefined) && (missing0 = "result"))) || ((data.bundle_bytes === undefined) && (missing0 = "bundle_bytes"))) || ((data.part_bytes === undefined) && (missing0 = "part_bytes"))) || ((data.segment_bytes === undefined) && (missing0 = "segment_bytes"))) || ((data.batch_rows === undefined) && (missing0 = "batch_rows"))) || ((data.columns === undefined) && (missing0 = "columns"))) || ((data.kv === undefined) && (missing0 = "kv"))) || ((data.table === undefined) && (missing0 = "table"))) || ((data.document === undefined) && (missing0 = "document"))){
validate160.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(func4.call(schema59.properties, key0))){
validate160.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.version !== undefined){
const _errs2 = errors;
if(!(validate161(data.version, {instancePath:instancePath+"/version",parentData:data,parentDataProperty:"version",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate161.errors : vErrors.concat(validate161.errors);
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
if(!(validate161(data.source, {instancePath:instancePath+"/source",parentData:data,parentDataProperty:"source",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate161.errors : vErrors.concat(validate161.errors);
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
if(!(validate161(data.plan, {instancePath:instancePath+"/plan",parentData:data,parentDataProperty:"plan",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate161.errors : vErrors.concat(validate161.errors);
errors = vErrors.length;
}
var valid0 = _errs4 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.result !== undefined){
const _errs5 = errors;
if(!(validate161(data.result, {instancePath:instancePath+"/result",parentData:data,parentDataProperty:"result",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate161.errors : vErrors.concat(validate161.errors);
errors = vErrors.length;
}
var valid0 = _errs5 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.bundle_bytes !== undefined){
const _errs6 = errors;
if(!(validate166(data.bundle_bytes, {instancePath:instancePath+"/bundle_bytes",parentData:data,parentDataProperty:"bundle_bytes",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate166.errors : vErrors.concat(validate166.errors);
errors = vErrors.length;
}
var valid0 = _errs6 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.part_bytes !== undefined){
const _errs7 = errors;
if(!(validate168(data.part_bytes, {instancePath:instancePath+"/part_bytes",parentData:data,parentDataProperty:"part_bytes",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate168.errors : vErrors.concat(validate168.errors);
errors = vErrors.length;
}
var valid0 = _errs7 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.segment_bytes !== undefined){
const _errs8 = errors;
if(!(validate166(data.segment_bytes, {instancePath:instancePath+"/segment_bytes",parentData:data,parentDataProperty:"segment_bytes",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate166.errors : vErrors.concat(validate166.errors);
errors = vErrors.length;
}
var valid0 = _errs8 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.batch_rows !== undefined){
const _errs9 = errors;
if(!(validate161(data.batch_rows, {instancePath:instancePath+"/batch_rows",parentData:data,parentDataProperty:"batch_rows",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate161.errors : vErrors.concat(validate161.errors);
errors = vErrors.length;
}
var valid0 = _errs9 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.columns !== undefined){
const _errs10 = errors;
if(!(validate161(data.columns, {instancePath:instancePath+"/columns",parentData:data,parentDataProperty:"columns",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate161.errors : vErrors.concat(validate161.errors);
errors = vErrors.length;
}
var valid0 = _errs10 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.kv !== undefined){
const _errs11 = errors;
if(!(validate173(data.kv, {instancePath:instancePath+"/kv",parentData:data,parentDataProperty:"kv",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate173.errors : vErrors.concat(validate173.errors);
errors = vErrors.length;
}
var valid0 = _errs11 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.table !== undefined){
const _errs12 = errors;
if(!(validate173(data.table, {instancePath:instancePath+"/table",parentData:data,parentDataProperty:"table",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate173.errors : vErrors.concat(validate173.errors);
errors = vErrors.length;
}
var valid0 = _errs12 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.document !== undefined){
const _errs13 = errors;
if(!(validate173(data.document, {instancePath:instancePath+"/document",parentData:data,parentDataProperty:"document",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate173.errors : vErrors.concat(validate173.errors);
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
validate160.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate160.errors = vErrors;
return errors === 0;
}
validate160.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema64 = {"type":"object","additionalProperties":false,"properties":{"version":{"$ref":"#/$defs/Response/$defs/T8"},"resource":{"$ref":"#/$defs/Response/$defs/T3"},"source":{"$ref":"#/$defs/Response/$defs/T13"}},"required":["version","resource","source"]};
const schema65 = {"oneOf":[{"type":"object","additionalProperties":false,"required":["kv"],"properties":{"kv":{"$ref":"#/$defs/Response/$defs/T14"}}},{"type":"object","additionalProperties":false,"required":["table"],"properties":{"table":{"$ref":"#/$defs/Response/$defs/T17"}}},{"type":"object","additionalProperties":false,"required":["document"],"properties":{"document":{"$ref":"#/$defs/Response/$defs/T43"}}}]};
const schema66 = {"type":"object","additionalProperties":false,"properties":{"prefix":{"$ref":"#/$defs/Response/$defs/T5"},"key":{"$ref":"#/$defs/Response/$defs/T15"},"value":{"$ref":"#/$defs/Response/$defs/T15"}},"required":["prefix","key","value"]};
const schema67 = {"type":"object","additionalProperties":false,"properties":{"version":{"$ref":"#/$defs/Response/$defs/T8"},"type":{"$ref":"#/$defs/Response/$defs/T16"}},"required":["version","type"]};
const schema68 = {"type":"string","enum":["int64","uint64","float64","boolean","utf8","binary"]};

function validate187(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate187.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate187.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
if(!((((((data === "int64") || (data === "uint64")) || (data === "float64")) || (data === "boolean")) || (data === "utf8")) || (data === "binary"))){
validate187.errors = [{instancePath,schemaPath:"#/enum",keyword:"enum",params:{allowedValues: schema68.enum},message:"must be equal to one of the allowed values"}];
return false;
}
validate187.errors = vErrors;
return errors === 0;
}
validate187.evaluated = {"dynamicProps":false,"dynamicItems":false};


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
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if(((data.version === undefined) && (missing0 = "version")) || ((data.type === undefined) && (missing0 = "type"))){
validate184.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "version") || (key0 === "type"))){
validate184.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.version !== undefined){
const _errs2 = errors;
if(!(validate161(data.version, {instancePath:instancePath+"/version",parentData:data,parentDataProperty:"version",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate161.errors : vErrors.concat(validate161.errors);
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
if(!(validate187(data.type, {instancePath:instancePath+"/type",parentData:data,parentDataProperty:"type",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate187.errors : vErrors.concat(validate187.errors);
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
validate184.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate184.errors = vErrors;
return errors === 0;
}
validate184.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


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
if((((data.prefix === undefined) && (missing0 = "prefix")) || ((data.key === undefined) && (missing0 = "key"))) || ((data.value === undefined) && (missing0 = "value"))){
validate182.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "prefix") || (key0 === "key")) || (key0 === "value"))){
validate182.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.prefix !== undefined){
const _errs2 = errors;
if(!(validate157(data.prefix, {instancePath:instancePath+"/prefix",parentData:data,parentDataProperty:"prefix",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate157.errors : vErrors.concat(validate157.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.key !== undefined){
const _errs3 = errors;
if(!(validate184(data.key, {instancePath:instancePath+"/key",parentData:data,parentDataProperty:"key",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate184.errors : vErrors.concat(validate184.errors);
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
if(!(validate184(data.value, {instancePath:instancePath+"/value",parentData:data,parentDataProperty:"value",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate184.errors : vErrors.concat(validate184.errors);
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
validate182.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate182.errors = vErrors;
return errors === 0;
}
validate182.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema70 = {"type":"object","additionalProperties":false,"properties":{"scope":{"$ref":"#/$defs/Response/$defs/T18"},"owner":{"$ref":"#/$defs/Response/$defs/T3"},"branch":{"$ref":"#/$defs/Response/$defs/T5"},"namespace":{"$ref":"#/$defs/Response/$defs/T3"},"object":{"$ref":"#/$defs/Response/$defs/T5"},"interpretation":{"$ref":"#/$defs/Response/$defs/T19"},"row_type":{"$ref":"#/$defs/Response/$defs/T21"}},"required":["scope","owner","branch","namespace","object","interpretation","row_type"]};
const schema71 = {"type":"object","additionalProperties":false,"properties":{"realm":{"$ref":"#/$defs/Response/$defs/T3"},"resource":{"$ref":"#/$defs/Response/$defs/T3"},"catalog":{"$ref":"#/$defs/Response/$defs/T5"}},"required":["realm","resource","catalog"]};

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
if((((data.realm === undefined) && (missing0 = "realm")) || ((data.resource === undefined) && (missing0 = "resource"))) || ((data.catalog === undefined) && (missing0 = "catalog"))){
validate193.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "realm") || (key0 === "resource")) || (key0 === "catalog"))){
validate193.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.realm !== undefined){
const _errs2 = errors;
if(!(validate146(data.realm, {instancePath:instancePath+"/realm",parentData:data,parentDataProperty:"realm",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate146.errors : vErrors.concat(validate146.errors);
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
if(!(validate146(data.resource, {instancePath:instancePath+"/resource",parentData:data,parentDataProperty:"resource",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate146.errors : vErrors.concat(validate146.errors);
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
if(!(validate157(data.catalog, {instancePath:instancePath+"/catalog",parentData:data,parentDataProperty:"catalog",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate157.errors : vErrors.concat(validate157.errors);
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
validate193.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate193.errors = vErrors;
return errors === 0;
}
validate193.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema72 = {"type":"object","additionalProperties":false,"properties":{"revision":{"$ref":"#/$defs/Response/$defs/T5"},"digest":{"$ref":"#/$defs/Response/$defs/T20"},"bytes":{"$ref":"#/$defs/Response/$defs/T5"},"schema":{"$ref":"#/$defs/Response/$defs/T20"}},"required":["revision","digest","bytes","schema"]};
const schema73 = {"type":"array","minItems":32,"maxItems":32,"items":{"$ref":"#/$defs/Response/$defs/T8"}};

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
if(Array.isArray(data)){
if(data.length > 32){
validate204.errors = [{instancePath,schemaPath:"#/maxItems",keyword:"maxItems",params:{limit: 32},message:"must NOT have more than 32 items"}];
return false;
}
else {
if(data.length < 32){
validate204.errors = [{instancePath,schemaPath:"#/minItems",keyword:"minItems",params:{limit: 32},message:"must NOT have fewer than 32 items"}];
return false;
}
else {
var valid0 = true;
const len0 = data.length;
for(let i0=0; i0<len0; i0++){
const _errs1 = errors;
if(!(validate161(data[i0], {instancePath:instancePath+"/" + i0,parentData:data,parentDataProperty:i0,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate161.errors : vErrors.concat(validate161.errors);
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
validate204.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "array"},message:"must be array"}];
return false;
}
}
validate204.errors = vErrors;
return errors === 0;
}
validate204.evaluated = {"items":true,"dynamicProps":false,"dynamicItems":false};


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
if(((((data.revision === undefined) && (missing0 = "revision")) || ((data.digest === undefined) && (missing0 = "digest"))) || ((data.bytes === undefined) && (missing0 = "bytes"))) || ((data.schema === undefined) && (missing0 = "schema"))){
validate202.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((((key0 === "revision") || (key0 === "digest")) || (key0 === "bytes")) || (key0 === "schema"))){
validate202.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.revision !== undefined){
const _errs2 = errors;
if(!(validate157(data.revision, {instancePath:instancePath+"/revision",parentData:data,parentDataProperty:"revision",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate157.errors : vErrors.concat(validate157.errors);
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
if(!(validate204(data.digest, {instancePath:instancePath+"/digest",parentData:data,parentDataProperty:"digest",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate204.errors : vErrors.concat(validate204.errors);
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
if(!(validate157(data.bytes, {instancePath:instancePath+"/bytes",parentData:data,parentDataProperty:"bytes",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate157.errors : vErrors.concat(validate157.errors);
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
if(!(validate204(data.schema, {instancePath:instancePath+"/schema",parentData:data,parentDataProperty:"schema",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate204.errors : vErrors.concat(validate204.errors);
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
validate202.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate202.errors = vErrors;
return errors === 0;
}
validate202.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema74 = {"oneOf":[{"type":"object","additionalProperties":false,"required":["int64"],"properties":{"int64":{"$ref":"#/$defs/Response/$defs/T22"}}},{"type":"object","additionalProperties":false,"required":["uint64"],"properties":{"uint64":{"$ref":"#/$defs/Response/$defs/T22"}}},{"type":"object","additionalProperties":false,"required":["float64"],"properties":{"float64":{"$ref":"#/$defs/Response/$defs/T22"}}},{"type":"object","additionalProperties":false,"required":["boolean"],"properties":{"boolean":{"$ref":"#/$defs/Response/$defs/T22"}}},{"type":"object","additionalProperties":false,"required":["utf8"],"properties":{"utf8":{"$ref":"#/$defs/Response/$defs/T22"}}},{"type":"object","additionalProperties":false,"required":["binary"],"properties":{"binary":{"$ref":"#/$defs/Response/$defs/T22"}}},{"type":"object","additionalProperties":false,"required":["int8"],"properties":{"int8":{"$ref":"#/$defs/Response/$defs/T22"}}},{"type":"object","additionalProperties":false,"required":["int16"],"properties":{"int16":{"$ref":"#/$defs/Response/$defs/T22"}}},{"type":"object","additionalProperties":false,"required":["int32"],"properties":{"int32":{"$ref":"#/$defs/Response/$defs/T22"}}},{"type":"object","additionalProperties":false,"required":["int128"],"properties":{"int128":{"$ref":"#/$defs/Response/$defs/T22"}}},{"type":"object","additionalProperties":false,"required":["uint8"],"properties":{"uint8":{"$ref":"#/$defs/Response/$defs/T22"}}},{"type":"object","additionalProperties":false,"required":["uint16"],"properties":{"uint16":{"$ref":"#/$defs/Response/$defs/T22"}}},{"type":"object","additionalProperties":false,"required":["uint32"],"properties":{"uint32":{"$ref":"#/$defs/Response/$defs/T22"}}},{"type":"object","additionalProperties":false,"required":["uint128"],"properties":{"uint128":{"$ref":"#/$defs/Response/$defs/T22"}}},{"type":"object","additionalProperties":false,"required":["float32"],"properties":{"float32":{"$ref":"#/$defs/Response/$defs/T22"}}},{"type":"object","additionalProperties":false,"required":["decimal"],"properties":{"decimal":{"$ref":"#/$defs/Response/$defs/T23"}}},{"type":"object","additionalProperties":false,"required":["date"],"properties":{"date":{"$ref":"#/$defs/Response/$defs/T22"}}},{"type":"object","additionalProperties":false,"required":["time"],"properties":{"time":{"$ref":"#/$defs/Response/$defs/T22"}}},{"type":"object","additionalProperties":false,"required":["timestamp"],"properties":{"timestamp":{"$ref":"#/$defs/Response/$defs/T24"}}},{"type":"object","additionalProperties":false,"required":["interval"],"properties":{"interval":{"$ref":"#/$defs/Response/$defs/T22"}}},{"type":"object","additionalProperties":false,"required":["uuid"],"properties":{"uuid":{"$ref":"#/$defs/Response/$defs/T22"}}},{"type":"object","additionalProperties":false,"required":["structure"],"properties":{"structure":{"$ref":"#/$defs/Response/$defs/T25"}}},{"type":"object","additionalProperties":false,"required":["list"],"properties":{"list":{"$ref":"#/$defs/Response/$defs/T39"}}},{"type":"object","additionalProperties":false,"required":["array"],"properties":{"array":{"$ref":"#/$defs/Response/$defs/T41"}}},{"type":"object","additionalProperties":false,"required":["map"],"properties":{"map":{"$ref":"#/$defs/Response/$defs/T42"}}},{"type":"object","additionalProperties":false,"required":["tagged_union"],"properties":{"tagged_union":{"$ref":"#/$defs/Response/$defs/T25"}}},{"type":"object","additionalProperties":false,"required":["json"],"properties":{"json":{"$ref":"#/$defs/Response/$defs/T22"}}}]};
const schema75 = {"type":"object","maxProperties":0};

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
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
if(Object.keys(data).length > 0){
validate211.errors = [{instancePath,schemaPath:"#/maxProperties",keyword:"maxProperties",params:{limit: 0},message:"must NOT have more than 0 properties"}];
return false;
}
}
else {
validate211.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate211.errors = vErrors;
return errors === 0;
}
validate211.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema76 = {"type":"object","additionalProperties":false,"properties":{"precision":{"$ref":"#/$defs/Response/$defs/T8"},"scale":{"$ref":"#/$defs/Response/$defs/T8"}},"required":["precision","scale"]};

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
if(((data.precision === undefined) && (missing0 = "precision")) || ((data.scale === undefined) && (missing0 = "scale"))){
validate227.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "precision") || (key0 === "scale"))){
validate227.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.precision !== undefined){
const _errs2 = errors;
if(!(validate161(data.precision, {instancePath:instancePath+"/precision",parentData:data,parentDataProperty:"precision",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate161.errors : vErrors.concat(validate161.errors);
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
if(!(validate161(data.scale, {instancePath:instancePath+"/scale",parentData:data,parentDataProperty:"scale",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate161.errors : vErrors.concat(validate161.errors);
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
validate227.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate227.errors = vErrors;
return errors === 0;
}
validate227.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema77 = {"type":"string","enum":["civil","utc"]};

function validate234(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate234.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate234.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
if(!((data === "civil") || (data === "utc"))){
validate234.errors = [{instancePath,schemaPath:"#/enum",keyword:"enum",params:{allowedValues: schema77.enum},message:"must be equal to one of the allowed values"}];
return false;
}
validate234.errors = vErrors;
return errors === 0;
}
validate234.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema79 = {"type":"array","maxItems":256,"items":{"$ref":"#/$defs/Response/$defs/T26"}};
const schema80 = {"type":"object","additionalProperties":false,"properties":{"name":{"$ref":"#/$defs/Response/$defs/T27"},"type":{"$ref":"#/$defs/Response/$defs/T28"},"nullable":{"$ref":"#/$defs/Response/$defs/T35"},"optional":{"$ref":"#/$defs/Response/$defs/T35"}},"required":["name","type","nullable","optional"]};
const schema81 = {"type":"string","maxLength":131072};

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
if(errors === 0){
if(typeof data === "string"){
if(func1(data) > 131072){
validate240.errors = [{instancePath,schemaPath:"#/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"}];
return false;
}
}
else {
validate240.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
}
validate240.errors = vErrors;
return errors === 0;
}
validate240.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema82 = {"oneOf":[{"type":"object","additionalProperties":false,"required":["int64"],"properties":{"int64":{"$ref":"#/$defs/Response/$defs/T29"}}},{"type":"object","additionalProperties":false,"required":["uint64"],"properties":{"uint64":{"$ref":"#/$defs/Response/$defs/T29"}}},{"type":"object","additionalProperties":false,"required":["float64"],"properties":{"float64":{"$ref":"#/$defs/Response/$defs/T29"}}},{"type":"object","additionalProperties":false,"required":["boolean"],"properties":{"boolean":{"$ref":"#/$defs/Response/$defs/T29"}}},{"type":"object","additionalProperties":false,"required":["utf8"],"properties":{"utf8":{"$ref":"#/$defs/Response/$defs/T29"}}},{"type":"object","additionalProperties":false,"required":["binary"],"properties":{"binary":{"$ref":"#/$defs/Response/$defs/T29"}}},{"type":"object","additionalProperties":false,"required":["int8"],"properties":{"int8":{"$ref":"#/$defs/Response/$defs/T29"}}},{"type":"object","additionalProperties":false,"required":["int16"],"properties":{"int16":{"$ref":"#/$defs/Response/$defs/T29"}}},{"type":"object","additionalProperties":false,"required":["int32"],"properties":{"int32":{"$ref":"#/$defs/Response/$defs/T29"}}},{"type":"object","additionalProperties":false,"required":["int128"],"properties":{"int128":{"$ref":"#/$defs/Response/$defs/T29"}}},{"type":"object","additionalProperties":false,"required":["uint8"],"properties":{"uint8":{"$ref":"#/$defs/Response/$defs/T29"}}},{"type":"object","additionalProperties":false,"required":["uint16"],"properties":{"uint16":{"$ref":"#/$defs/Response/$defs/T29"}}},{"type":"object","additionalProperties":false,"required":["uint32"],"properties":{"uint32":{"$ref":"#/$defs/Response/$defs/T29"}}},{"type":"object","additionalProperties":false,"required":["uint128"],"properties":{"uint128":{"$ref":"#/$defs/Response/$defs/T29"}}},{"type":"object","additionalProperties":false,"required":["float32"],"properties":{"float32":{"$ref":"#/$defs/Response/$defs/T29"}}},{"type":"object","additionalProperties":false,"required":["decimal"],"properties":{"decimal":{"$ref":"#/$defs/Response/$defs/T30"}}},{"type":"object","additionalProperties":false,"required":["date"],"properties":{"date":{"$ref":"#/$defs/Response/$defs/T29"}}},{"type":"object","additionalProperties":false,"required":["time"],"properties":{"time":{"$ref":"#/$defs/Response/$defs/T29"}}},{"type":"object","additionalProperties":false,"required":["timestamp"],"properties":{"timestamp":{"$ref":"#/$defs/Response/$defs/T32"}}},{"type":"object","additionalProperties":false,"required":["interval"],"properties":{"interval":{"$ref":"#/$defs/Response/$defs/T29"}}},{"type":"object","additionalProperties":false,"required":["uuid"],"properties":{"uuid":{"$ref":"#/$defs/Response/$defs/T29"}}},{"type":"object","additionalProperties":false,"required":["structure"],"properties":{"structure":{"$ref":"#/$defs/Response/$defs/T25"}}},{"type":"object","additionalProperties":false,"required":["list"],"properties":{"list":{"$ref":"#/$defs/Response/$defs/T33"}}},{"type":"object","additionalProperties":false,"required":["array"],"properties":{"array":{"$ref":"#/$defs/Response/$defs/T36"}}},{"type":"object","additionalProperties":false,"required":["map"],"properties":{"map":{"$ref":"#/$defs/Response/$defs/T38"}}},{"type":"object","additionalProperties":false,"required":["tagged_union"],"properties":{"tagged_union":{"$ref":"#/$defs/Response/$defs/T25"}}},{"type":"object","additionalProperties":false,"required":["json"],"properties":{"json":{"$ref":"#/$defs/Response/$defs/T29"}}}]};
const schema83 = {"type":"object","maxProperties":0};

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
if(data && typeof data == "object" && !Array.isArray(data)){
if(Object.keys(data).length > 0){
validate243.errors = [{instancePath,schemaPath:"#/maxProperties",keyword:"maxProperties",params:{limit: 0},message:"must NOT have more than 0 properties"}];
return false;
}
}
else {
validate243.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate243.errors = vErrors;
return errors === 0;
}
validate243.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema84 = {"type":"object","additionalProperties":false,"properties":{"precision":{"$ref":"#/$defs/Response/$defs/T31"},"scale":{"$ref":"#/$defs/Response/$defs/T31"}},"required":["precision","scale"]};

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
if(!(((typeof data == "number") && (!(data % 1) && !isNaN(data))) && (isFinite(data)))){
validate260.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "integer"},message:"must be integer"}];
return false;
}
if(errors === 0){
if((typeof data == "number") && (isFinite(data))){
if(data > 255 || isNaN(data)){
validate260.errors = [{instancePath,schemaPath:"#/maximum",keyword:"maximum",params:{comparison: "<=", limit: 255},message:"must be <= 255"}];
return false;
}
else {
if(data < 0 || isNaN(data)){
validate260.errors = [{instancePath,schemaPath:"#/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"}];
return false;
}
}
}
}
validate260.errors = vErrors;
return errors === 0;
}
validate260.evaluated = {"dynamicProps":false,"dynamicItems":false};


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
if(((data.precision === undefined) && (missing0 = "precision")) || ((data.scale === undefined) && (missing0 = "scale"))){
validate259.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "precision") || (key0 === "scale"))){
validate259.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.precision !== undefined){
const _errs2 = errors;
if(!(validate260(data.precision, {instancePath:instancePath+"/precision",parentData:data,parentDataProperty:"precision",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate260.errors : vErrors.concat(validate260.errors);
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
if(!(validate260(data.scale, {instancePath:instancePath+"/scale",parentData:data,parentDataProperty:"scale",rootData,dynamicAnchors}))){
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
validate259.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate259.errors = vErrors;
return errors === 0;
}
validate259.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


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
if(typeof data !== "string"){
validate266.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
if(!((data === "civil") || (data === "utc"))){
validate266.errors = [{instancePath,schemaPath:"#/enum",keyword:"enum",params:{allowedValues: schema77.enum},message:"must be equal to one of the allowed values"}];
return false;
}
validate266.errors = vErrors;
return errors === 0;
}
validate266.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema87 = {"type":"object","additionalProperties":false,"properties":{"type":{"$ref":"#/$defs/Response/$defs/T34"},"nullable":{"$ref":"#/$defs/Response/$defs/T35"}},"required":["type","nullable"]};
const wrapper1 = {validate: validate242};
const schema88 = {"type":"boolean"};

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
if(typeof data !== "boolean"){
validate271.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"}];
return false;
}
validate271.errors = vErrors;
return errors === 0;
}
validate271.evaluated = {"dynamicProps":false,"dynamicItems":false};


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
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if(((data.type === undefined) && (missing0 = "type")) || ((data.nullable === undefined) && (missing0 = "nullable"))){
validate270.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "type") || (key0 === "nullable"))){
validate270.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.type !== undefined){
const _errs2 = errors;
if(!(wrapper1.validate(data.type, {instancePath:instancePath+"/type",parentData:data,parentDataProperty:"type",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? wrapper1.validate.errors : vErrors.concat(wrapper1.validate.errors);
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
if(!(validate271(data.nullable, {instancePath:instancePath+"/nullable",parentData:data,parentDataProperty:"nullable",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate271.errors : vErrors.concat(validate271.errors);
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
validate270.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate270.errors = vErrors;
return errors === 0;
}
validate270.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema89 = {"type":"object","additionalProperties":false,"properties":{"element":{"$ref":"#/$defs/Response/$defs/T33"},"length":{"$ref":"#/$defs/Response/$defs/T37"}},"required":["element","length"]};

function validate276(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate276.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(!(((typeof data == "number") && (!(data % 1) && !isNaN(data))) && (isFinite(data)))){
validate276.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "integer"},message:"must be integer"}];
return false;
}
if(errors === 0){
if((typeof data == "number") && (isFinite(data))){
if(data > 4294967295 || isNaN(data)){
validate276.errors = [{instancePath,schemaPath:"#/maximum",keyword:"maximum",params:{comparison: "<=", limit: 4294967295},message:"must be <= 4294967295"}];
return false;
}
else {
if(data < 0 || isNaN(data)){
validate276.errors = [{instancePath,schemaPath:"#/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"}];
return false;
}
}
}
}
validate276.errors = vErrors;
return errors === 0;
}
validate276.evaluated = {"dynamicProps":false,"dynamicItems":false};


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
if(((data.element === undefined) && (missing0 = "element")) || ((data.length === undefined) && (missing0 = "length"))){
validate274.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "element") || (key0 === "length"))){
validate274.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.element !== undefined){
const _errs2 = errors;
if(!(validate270(data.element, {instancePath:instancePath+"/element",parentData:data,parentDataProperty:"element",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate270.errors : vErrors.concat(validate270.errors);
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
if(!(validate276(data.length, {instancePath:instancePath+"/length",parentData:data,parentDataProperty:"length",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate276.errors : vErrors.concat(validate276.errors);
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
validate274.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate274.errors = vErrors;
return errors === 0;
}
validate274.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema91 = {"type":"object","additionalProperties":false,"properties":{"key":{"$ref":"#/$defs/Response/$defs/T34"},"value":{"$ref":"#/$defs/Response/$defs/T33"}},"required":["key","value"]};

function validate279(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate279.evaluated;
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
validate279.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "key") || (key0 === "value"))){
validate279.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.key !== undefined){
const _errs2 = errors;
if(!(wrapper1.validate(data.key, {instancePath:instancePath+"/key",parentData:data,parentDataProperty:"key",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? wrapper1.validate.errors : vErrors.concat(wrapper1.validate.errors);
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
if(!(validate270(data.value, {instancePath:instancePath+"/value",parentData:data,parentDataProperty:"value",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate270.errors : vErrors.concat(validate270.errors);
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
validate279.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate279.errors = vErrors;
return errors === 0;
}
validate279.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const wrapper0 = {validate: validate238};

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
const _errs0 = errors;
let valid0 = false;
let passing0 = null;
const _errs1 = errors;
if(errors === _errs1){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((data.int64 === undefined) && (missing0 = "int64")){
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
if(!(key0 === "int64")){
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
if(data.int64 !== undefined){
if(!(validate243(data.int64, {instancePath:instancePath+"/int64",parentData:data,parentDataProperty:"int64",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate243.errors : vErrors.concat(validate243.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err2 = {instancePath,schemaPath:"#/oneOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err3 = {instancePath,schemaPath:"#/oneOf/1/required",keyword:"required",params:{missingProperty: missing1},message:"must have required property '"+missing1+"'"};
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
const err4 = {instancePath,schemaPath:"#/oneOf/1/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key1},message:"must NOT have additional properties"};
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
if(!(validate243(data.uint64, {instancePath:instancePath+"/uint64",parentData:data,parentDataProperty:"uint64",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate243.errors : vErrors.concat(validate243.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err5 = {instancePath,schemaPath:"#/oneOf/1/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err6 = {instancePath,schemaPath:"#/oneOf/2/required",keyword:"required",params:{missingProperty: missing2},message:"must have required property '"+missing2+"'"};
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
const err7 = {instancePath,schemaPath:"#/oneOf/2/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key2},message:"must NOT have additional properties"};
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
if(!(validate243(data.float64, {instancePath:instancePath+"/float64",parentData:data,parentDataProperty:"float64",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate243.errors : vErrors.concat(validate243.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err8 = {instancePath,schemaPath:"#/oneOf/2/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err9 = {instancePath,schemaPath:"#/oneOf/3/required",keyword:"required",params:{missingProperty: missing3},message:"must have required property '"+missing3+"'"};
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
const err10 = {instancePath,schemaPath:"#/oneOf/3/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key3},message:"must NOT have additional properties"};
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
if(!(validate243(data.boolean, {instancePath:instancePath+"/boolean",parentData:data,parentDataProperty:"boolean",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate243.errors : vErrors.concat(validate243.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err11 = {instancePath,schemaPath:"#/oneOf/3/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err12 = {instancePath,schemaPath:"#/oneOf/4/required",keyword:"required",params:{missingProperty: missing4},message:"must have required property '"+missing4+"'"};
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
const err13 = {instancePath,schemaPath:"#/oneOf/4/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key4},message:"must NOT have additional properties"};
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
if(!(validate243(data.utf8, {instancePath:instancePath+"/utf8",parentData:data,parentDataProperty:"utf8",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate243.errors : vErrors.concat(validate243.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err14 = {instancePath,schemaPath:"#/oneOf/4/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err15 = {instancePath,schemaPath:"#/oneOf/5/required",keyword:"required",params:{missingProperty: missing5},message:"must have required property '"+missing5+"'"};
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
const err16 = {instancePath,schemaPath:"#/oneOf/5/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key5},message:"must NOT have additional properties"};
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
if(!(validate243(data.binary, {instancePath:instancePath+"/binary",parentData:data,parentDataProperty:"binary",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate243.errors : vErrors.concat(validate243.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err17 = {instancePath,schemaPath:"#/oneOf/5/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err18 = {instancePath,schemaPath:"#/oneOf/6/required",keyword:"required",params:{missingProperty: missing6},message:"must have required property '"+missing6+"'"};
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
const err19 = {instancePath,schemaPath:"#/oneOf/6/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key6},message:"must NOT have additional properties"};
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
if(!(validate243(data.int8, {instancePath:instancePath+"/int8",parentData:data,parentDataProperty:"int8",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate243.errors : vErrors.concat(validate243.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err20 = {instancePath,schemaPath:"#/oneOf/6/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err21 = {instancePath,schemaPath:"#/oneOf/7/required",keyword:"required",params:{missingProperty: missing7},message:"must have required property '"+missing7+"'"};
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
const err22 = {instancePath,schemaPath:"#/oneOf/7/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key7},message:"must NOT have additional properties"};
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
if(!(validate243(data.int16, {instancePath:instancePath+"/int16",parentData:data,parentDataProperty:"int16",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate243.errors : vErrors.concat(validate243.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err23 = {instancePath,schemaPath:"#/oneOf/7/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err24 = {instancePath,schemaPath:"#/oneOf/8/required",keyword:"required",params:{missingProperty: missing8},message:"must have required property '"+missing8+"'"};
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
const err25 = {instancePath,schemaPath:"#/oneOf/8/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key8},message:"must NOT have additional properties"};
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
if(!(validate243(data.int32, {instancePath:instancePath+"/int32",parentData:data,parentDataProperty:"int32",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate243.errors : vErrors.concat(validate243.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err26 = {instancePath,schemaPath:"#/oneOf/8/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err27 = {instancePath,schemaPath:"#/oneOf/9/required",keyword:"required",params:{missingProperty: missing9},message:"must have required property '"+missing9+"'"};
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
const err28 = {instancePath,schemaPath:"#/oneOf/9/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key9},message:"must NOT have additional properties"};
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
if(!(validate243(data.int128, {instancePath:instancePath+"/int128",parentData:data,parentDataProperty:"int128",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate243.errors : vErrors.concat(validate243.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err29 = {instancePath,schemaPath:"#/oneOf/9/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err30 = {instancePath,schemaPath:"#/oneOf/10/required",keyword:"required",params:{missingProperty: missing10},message:"must have required property '"+missing10+"'"};
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
const err31 = {instancePath,schemaPath:"#/oneOf/10/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key10},message:"must NOT have additional properties"};
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
if(!(validate243(data.uint8, {instancePath:instancePath+"/uint8",parentData:data,parentDataProperty:"uint8",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate243.errors : vErrors.concat(validate243.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err32 = {instancePath,schemaPath:"#/oneOf/10/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err33 = {instancePath,schemaPath:"#/oneOf/11/required",keyword:"required",params:{missingProperty: missing11},message:"must have required property '"+missing11+"'"};
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
const err34 = {instancePath,schemaPath:"#/oneOf/11/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key11},message:"must NOT have additional properties"};
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
if(!(validate243(data.uint16, {instancePath:instancePath+"/uint16",parentData:data,parentDataProperty:"uint16",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate243.errors : vErrors.concat(validate243.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err35 = {instancePath,schemaPath:"#/oneOf/11/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err36 = {instancePath,schemaPath:"#/oneOf/12/required",keyword:"required",params:{missingProperty: missing12},message:"must have required property '"+missing12+"'"};
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
const err37 = {instancePath,schemaPath:"#/oneOf/12/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key12},message:"must NOT have additional properties"};
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
if(!(validate243(data.uint32, {instancePath:instancePath+"/uint32",parentData:data,parentDataProperty:"uint32",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate243.errors : vErrors.concat(validate243.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err38 = {instancePath,schemaPath:"#/oneOf/12/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err39 = {instancePath,schemaPath:"#/oneOf/13/required",keyword:"required",params:{missingProperty: missing13},message:"must have required property '"+missing13+"'"};
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
const err40 = {instancePath,schemaPath:"#/oneOf/13/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key13},message:"must NOT have additional properties"};
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
if(!(validate243(data.uint128, {instancePath:instancePath+"/uint128",parentData:data,parentDataProperty:"uint128",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate243.errors : vErrors.concat(validate243.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err41 = {instancePath,schemaPath:"#/oneOf/13/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err42 = {instancePath,schemaPath:"#/oneOf/14/required",keyword:"required",params:{missingProperty: missing14},message:"must have required property '"+missing14+"'"};
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
const err43 = {instancePath,schemaPath:"#/oneOf/14/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key14},message:"must NOT have additional properties"};
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
if(!(validate243(data.float32, {instancePath:instancePath+"/float32",parentData:data,parentDataProperty:"float32",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate243.errors : vErrors.concat(validate243.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err44 = {instancePath,schemaPath:"#/oneOf/14/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err45 = {instancePath,schemaPath:"#/oneOf/15/required",keyword:"required",params:{missingProperty: missing15},message:"must have required property '"+missing15+"'"};
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
const err46 = {instancePath,schemaPath:"#/oneOf/15/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key15},message:"must NOT have additional properties"};
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
if(!(validate259(data.decimal, {instancePath:instancePath+"/decimal",parentData:data,parentDataProperty:"decimal",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate259.errors : vErrors.concat(validate259.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err47 = {instancePath,schemaPath:"#/oneOf/15/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err48 = {instancePath,schemaPath:"#/oneOf/16/required",keyword:"required",params:{missingProperty: missing16},message:"must have required property '"+missing16+"'"};
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
const err49 = {instancePath,schemaPath:"#/oneOf/16/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key16},message:"must NOT have additional properties"};
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
if(!(validate243(data.date, {instancePath:instancePath+"/date",parentData:data,parentDataProperty:"date",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate243.errors : vErrors.concat(validate243.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err50 = {instancePath,schemaPath:"#/oneOf/16/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err51 = {instancePath,schemaPath:"#/oneOf/17/required",keyword:"required",params:{missingProperty: missing17},message:"must have required property '"+missing17+"'"};
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
const err52 = {instancePath,schemaPath:"#/oneOf/17/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key17},message:"must NOT have additional properties"};
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
if(!(validate243(data.time, {instancePath:instancePath+"/time",parentData:data,parentDataProperty:"time",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate243.errors : vErrors.concat(validate243.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err53 = {instancePath,schemaPath:"#/oneOf/17/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err54 = {instancePath,schemaPath:"#/oneOf/18/required",keyword:"required",params:{missingProperty: missing18},message:"must have required property '"+missing18+"'"};
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
const err55 = {instancePath,schemaPath:"#/oneOf/18/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key18},message:"must NOT have additional properties"};
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
if(!(validate266(data.timestamp, {instancePath:instancePath+"/timestamp",parentData:data,parentDataProperty:"timestamp",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate266.errors : vErrors.concat(validate266.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err56 = {instancePath,schemaPath:"#/oneOf/18/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err57 = {instancePath,schemaPath:"#/oneOf/19/required",keyword:"required",params:{missingProperty: missing19},message:"must have required property '"+missing19+"'"};
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
const err58 = {instancePath,schemaPath:"#/oneOf/19/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key19},message:"must NOT have additional properties"};
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
if(!(validate243(data.interval, {instancePath:instancePath+"/interval",parentData:data,parentDataProperty:"interval",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate243.errors : vErrors.concat(validate243.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err59 = {instancePath,schemaPath:"#/oneOf/19/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err60 = {instancePath,schemaPath:"#/oneOf/20/required",keyword:"required",params:{missingProperty: missing20},message:"must have required property '"+missing20+"'"};
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
const err61 = {instancePath,schemaPath:"#/oneOf/20/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key20},message:"must NOT have additional properties"};
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
if(!(validate243(data.uuid, {instancePath:instancePath+"/uuid",parentData:data,parentDataProperty:"uuid",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate243.errors : vErrors.concat(validate243.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err62 = {instancePath,schemaPath:"#/oneOf/20/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err63 = {instancePath,schemaPath:"#/oneOf/21/required",keyword:"required",params:{missingProperty: missing21},message:"must have required property '"+missing21+"'"};
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
const err64 = {instancePath,schemaPath:"#/oneOf/21/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key21},message:"must NOT have additional properties"};
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
if(!(wrapper0.validate(data.structure, {instancePath:instancePath+"/structure",parentData:data,parentDataProperty:"structure",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? wrapper0.validate.errors : vErrors.concat(wrapper0.validate.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err65 = {instancePath,schemaPath:"#/oneOf/21/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err66 = {instancePath,schemaPath:"#/oneOf/22/required",keyword:"required",params:{missingProperty: missing22},message:"must have required property '"+missing22+"'"};
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
const err67 = {instancePath,schemaPath:"#/oneOf/22/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key22},message:"must NOT have additional properties"};
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
if(!(validate270(data.list, {instancePath:instancePath+"/list",parentData:data,parentDataProperty:"list",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate270.errors : vErrors.concat(validate270.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err68 = {instancePath,schemaPath:"#/oneOf/22/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err69 = {instancePath,schemaPath:"#/oneOf/23/required",keyword:"required",params:{missingProperty: missing23},message:"must have required property '"+missing23+"'"};
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
const err70 = {instancePath,schemaPath:"#/oneOf/23/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key23},message:"must NOT have additional properties"};
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
if(!(validate274(data.array, {instancePath:instancePath+"/array",parentData:data,parentDataProperty:"array",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate274.errors : vErrors.concat(validate274.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err71 = {instancePath,schemaPath:"#/oneOf/23/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err72 = {instancePath,schemaPath:"#/oneOf/24/required",keyword:"required",params:{missingProperty: missing24},message:"must have required property '"+missing24+"'"};
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
const err73 = {instancePath,schemaPath:"#/oneOf/24/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key24},message:"must NOT have additional properties"};
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
if(!(validate279(data.map, {instancePath:instancePath+"/map",parentData:data,parentDataProperty:"map",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate279.errors : vErrors.concat(validate279.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err74 = {instancePath,schemaPath:"#/oneOf/24/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err75 = {instancePath,schemaPath:"#/oneOf/25/required",keyword:"required",params:{missingProperty: missing25},message:"must have required property '"+missing25+"'"};
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
const err76 = {instancePath,schemaPath:"#/oneOf/25/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key25},message:"must NOT have additional properties"};
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
if(!(wrapper0.validate(data.tagged_union, {instancePath:instancePath+"/tagged_union",parentData:data,parentDataProperty:"tagged_union",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? wrapper0.validate.errors : vErrors.concat(wrapper0.validate.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err77 = {instancePath,schemaPath:"#/oneOf/25/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err78 = {instancePath,schemaPath:"#/oneOf/26/required",keyword:"required",params:{missingProperty: missing26},message:"must have required property '"+missing26+"'"};
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
const err79 = {instancePath,schemaPath:"#/oneOf/26/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key26},message:"must NOT have additional properties"};
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
if(!(validate243(data.json, {instancePath:instancePath+"/json",parentData:data,parentDataProperty:"json",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate243.errors : vErrors.concat(validate243.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err80 = {instancePath,schemaPath:"#/oneOf/26/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err81 = {instancePath,schemaPath:"#/oneOf",keyword:"oneOf",params:{passingSchemas: passing0},message:"must match exactly one schema in oneOf"};
if(vErrors === null){
vErrors = [err81];
}
else {
vErrors.push(err81);
}
errors++;
validate242.errors = vErrors;
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
validate242.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate242.evaluated = {"dynamicProps":true,"dynamicItems":false};


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
if(((((data.name === undefined) && (missing0 = "name")) || ((data.type === undefined) && (missing0 = "type"))) || ((data.nullable === undefined) && (missing0 = "nullable"))) || ((data.optional === undefined) && (missing0 = "optional"))){
validate239.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((((key0 === "name") || (key0 === "type")) || (key0 === "nullable")) || (key0 === "optional"))){
validate239.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.name !== undefined){
const _errs2 = errors;
if(!(validate240(data.name, {instancePath:instancePath+"/name",parentData:data,parentDataProperty:"name",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate240.errors : vErrors.concat(validate240.errors);
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
if(!(validate242(data.type, {instancePath:instancePath+"/type",parentData:data,parentDataProperty:"type",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate242.errors : vErrors.concat(validate242.errors);
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
if(!(validate271(data.nullable, {instancePath:instancePath+"/nullable",parentData:data,parentDataProperty:"nullable",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate271.errors : vErrors.concat(validate271.errors);
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
if(!(validate271(data.optional, {instancePath:instancePath+"/optional",parentData:data,parentDataProperty:"optional",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate271.errors : vErrors.concat(validate271.errors);
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
if(errors === 0){
if(Array.isArray(data)){
if(data.length > 256){
validate238.errors = [{instancePath,schemaPath:"#/maxItems",keyword:"maxItems",params:{limit: 256},message:"must NOT have more than 256 items"}];
return false;
}
else {
var valid0 = true;
const len0 = data.length;
for(let i0=0; i0<len0; i0++){
const _errs1 = errors;
if(!(validate239(data[i0], {instancePath:instancePath+"/" + i0,parentData:data,parentDataProperty:i0,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate239.errors : vErrors.concat(validate239.errors);
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
validate238.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "array"},message:"must be array"}];
return false;
}
}
validate238.errors = vErrors;
return errors === 0;
}
validate238.evaluated = {"items":true,"dynamicProps":false,"dynamicItems":false};

const schema92 = {"type":"object","additionalProperties":false,"properties":{"type":{"$ref":"#/$defs/Response/$defs/T40"},"nullable":{"$ref":"#/$defs/Response/$defs/T11"}},"required":["type","nullable"]};
const wrapper4 = {validate: validate210};

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
if(((data.type === undefined) && (missing0 = "type")) || ((data.nullable === undefined) && (missing0 = "nullable"))){
validate288.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "type") || (key0 === "nullable"))){
validate288.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.type !== undefined){
const _errs2 = errors;
if(!(wrapper4.validate(data.type, {instancePath:instancePath+"/type",parentData:data,parentDataProperty:"type",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? wrapper4.validate.errors : vErrors.concat(wrapper4.validate.errors);
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
if(!(validate173(data.nullable, {instancePath:instancePath+"/nullable",parentData:data,parentDataProperty:"nullable",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate173.errors : vErrors.concat(validate173.errors);
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
validate288.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate288.errors = vErrors;
return errors === 0;
}
validate288.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema93 = {"type":"object","additionalProperties":false,"properties":{"element":{"$ref":"#/$defs/Response/$defs/T39"},"length":{"$ref":"#/$defs/Response/$defs/T9"}},"required":["element","length"]};

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
if(((data.element === undefined) && (missing0 = "element")) || ((data.length === undefined) && (missing0 = "length"))){
validate291.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "element") || (key0 === "length"))){
validate291.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.element !== undefined){
const _errs2 = errors;
if(!(validate288(data.element, {instancePath:instancePath+"/element",parentData:data,parentDataProperty:"element",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate288.errors : vErrors.concat(validate288.errors);
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
if(!(validate166(data.length, {instancePath:instancePath+"/length",parentData:data,parentDataProperty:"length",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate166.errors : vErrors.concat(validate166.errors);
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
validate291.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate291.errors = vErrors;
return errors === 0;
}
validate291.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema94 = {"type":"object","additionalProperties":false,"properties":{"key":{"$ref":"#/$defs/Response/$defs/T40"},"value":{"$ref":"#/$defs/Response/$defs/T39"}},"required":["key","value"]};

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
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if(((data.key === undefined) && (missing0 = "key")) || ((data.value === undefined) && (missing0 = "value"))){
validate295.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "key") || (key0 === "value"))){
validate295.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.key !== undefined){
const _errs2 = errors;
if(!(wrapper4.validate(data.key, {instancePath:instancePath+"/key",parentData:data,parentDataProperty:"key",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? wrapper4.validate.errors : vErrors.concat(wrapper4.validate.errors);
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
if(!(validate288(data.value, {instancePath:instancePath+"/value",parentData:data,parentDataProperty:"value",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate288.errors : vErrors.concat(validate288.errors);
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
validate295.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate295.errors = vErrors;
return errors === 0;
}
validate295.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


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
const _errs0 = errors;
let valid0 = false;
let passing0 = null;
const _errs1 = errors;
if(errors === _errs1){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((data.int64 === undefined) && (missing0 = "int64")){
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
if(!(key0 === "int64")){
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
if(data.int64 !== undefined){
if(!(validate211(data.int64, {instancePath:instancePath+"/int64",parentData:data,parentDataProperty:"int64",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate211.errors : vErrors.concat(validate211.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err2 = {instancePath,schemaPath:"#/oneOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err3 = {instancePath,schemaPath:"#/oneOf/1/required",keyword:"required",params:{missingProperty: missing1},message:"must have required property '"+missing1+"'"};
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
const err4 = {instancePath,schemaPath:"#/oneOf/1/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key1},message:"must NOT have additional properties"};
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
if(!(validate211(data.uint64, {instancePath:instancePath+"/uint64",parentData:data,parentDataProperty:"uint64",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate211.errors : vErrors.concat(validate211.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err5 = {instancePath,schemaPath:"#/oneOf/1/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err6 = {instancePath,schemaPath:"#/oneOf/2/required",keyword:"required",params:{missingProperty: missing2},message:"must have required property '"+missing2+"'"};
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
const err7 = {instancePath,schemaPath:"#/oneOf/2/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key2},message:"must NOT have additional properties"};
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
if(!(validate211(data.float64, {instancePath:instancePath+"/float64",parentData:data,parentDataProperty:"float64",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate211.errors : vErrors.concat(validate211.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err8 = {instancePath,schemaPath:"#/oneOf/2/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err9 = {instancePath,schemaPath:"#/oneOf/3/required",keyword:"required",params:{missingProperty: missing3},message:"must have required property '"+missing3+"'"};
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
const err10 = {instancePath,schemaPath:"#/oneOf/3/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key3},message:"must NOT have additional properties"};
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
if(!(validate211(data.boolean, {instancePath:instancePath+"/boolean",parentData:data,parentDataProperty:"boolean",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate211.errors : vErrors.concat(validate211.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err11 = {instancePath,schemaPath:"#/oneOf/3/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err12 = {instancePath,schemaPath:"#/oneOf/4/required",keyword:"required",params:{missingProperty: missing4},message:"must have required property '"+missing4+"'"};
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
const err13 = {instancePath,schemaPath:"#/oneOf/4/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key4},message:"must NOT have additional properties"};
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
if(!(validate211(data.utf8, {instancePath:instancePath+"/utf8",parentData:data,parentDataProperty:"utf8",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate211.errors : vErrors.concat(validate211.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err14 = {instancePath,schemaPath:"#/oneOf/4/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err15 = {instancePath,schemaPath:"#/oneOf/5/required",keyword:"required",params:{missingProperty: missing5},message:"must have required property '"+missing5+"'"};
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
const err16 = {instancePath,schemaPath:"#/oneOf/5/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key5},message:"must NOT have additional properties"};
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
if(!(validate211(data.binary, {instancePath:instancePath+"/binary",parentData:data,parentDataProperty:"binary",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate211.errors : vErrors.concat(validate211.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err17 = {instancePath,schemaPath:"#/oneOf/5/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err18 = {instancePath,schemaPath:"#/oneOf/6/required",keyword:"required",params:{missingProperty: missing6},message:"must have required property '"+missing6+"'"};
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
const err19 = {instancePath,schemaPath:"#/oneOf/6/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key6},message:"must NOT have additional properties"};
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
if(!(validate211(data.int8, {instancePath:instancePath+"/int8",parentData:data,parentDataProperty:"int8",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate211.errors : vErrors.concat(validate211.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err20 = {instancePath,schemaPath:"#/oneOf/6/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err21 = {instancePath,schemaPath:"#/oneOf/7/required",keyword:"required",params:{missingProperty: missing7},message:"must have required property '"+missing7+"'"};
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
const err22 = {instancePath,schemaPath:"#/oneOf/7/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key7},message:"must NOT have additional properties"};
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
if(!(validate211(data.int16, {instancePath:instancePath+"/int16",parentData:data,parentDataProperty:"int16",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate211.errors : vErrors.concat(validate211.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err23 = {instancePath,schemaPath:"#/oneOf/7/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err24 = {instancePath,schemaPath:"#/oneOf/8/required",keyword:"required",params:{missingProperty: missing8},message:"must have required property '"+missing8+"'"};
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
const err25 = {instancePath,schemaPath:"#/oneOf/8/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key8},message:"must NOT have additional properties"};
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
if(!(validate211(data.int32, {instancePath:instancePath+"/int32",parentData:data,parentDataProperty:"int32",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate211.errors : vErrors.concat(validate211.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err26 = {instancePath,schemaPath:"#/oneOf/8/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err27 = {instancePath,schemaPath:"#/oneOf/9/required",keyword:"required",params:{missingProperty: missing9},message:"must have required property '"+missing9+"'"};
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
const err28 = {instancePath,schemaPath:"#/oneOf/9/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key9},message:"must NOT have additional properties"};
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
if(!(validate211(data.int128, {instancePath:instancePath+"/int128",parentData:data,parentDataProperty:"int128",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate211.errors : vErrors.concat(validate211.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err29 = {instancePath,schemaPath:"#/oneOf/9/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err30 = {instancePath,schemaPath:"#/oneOf/10/required",keyword:"required",params:{missingProperty: missing10},message:"must have required property '"+missing10+"'"};
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
const err31 = {instancePath,schemaPath:"#/oneOf/10/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key10},message:"must NOT have additional properties"};
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
if(!(validate211(data.uint8, {instancePath:instancePath+"/uint8",parentData:data,parentDataProperty:"uint8",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate211.errors : vErrors.concat(validate211.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err32 = {instancePath,schemaPath:"#/oneOf/10/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err33 = {instancePath,schemaPath:"#/oneOf/11/required",keyword:"required",params:{missingProperty: missing11},message:"must have required property '"+missing11+"'"};
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
const err34 = {instancePath,schemaPath:"#/oneOf/11/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key11},message:"must NOT have additional properties"};
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
if(!(validate211(data.uint16, {instancePath:instancePath+"/uint16",parentData:data,parentDataProperty:"uint16",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate211.errors : vErrors.concat(validate211.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err35 = {instancePath,schemaPath:"#/oneOf/11/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err36 = {instancePath,schemaPath:"#/oneOf/12/required",keyword:"required",params:{missingProperty: missing12},message:"must have required property '"+missing12+"'"};
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
const err37 = {instancePath,schemaPath:"#/oneOf/12/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key12},message:"must NOT have additional properties"};
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
if(!(validate211(data.uint32, {instancePath:instancePath+"/uint32",parentData:data,parentDataProperty:"uint32",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate211.errors : vErrors.concat(validate211.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err38 = {instancePath,schemaPath:"#/oneOf/12/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err39 = {instancePath,schemaPath:"#/oneOf/13/required",keyword:"required",params:{missingProperty: missing13},message:"must have required property '"+missing13+"'"};
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
const err40 = {instancePath,schemaPath:"#/oneOf/13/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key13},message:"must NOT have additional properties"};
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
if(!(validate211(data.uint128, {instancePath:instancePath+"/uint128",parentData:data,parentDataProperty:"uint128",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate211.errors : vErrors.concat(validate211.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err41 = {instancePath,schemaPath:"#/oneOf/13/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err42 = {instancePath,schemaPath:"#/oneOf/14/required",keyword:"required",params:{missingProperty: missing14},message:"must have required property '"+missing14+"'"};
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
const err43 = {instancePath,schemaPath:"#/oneOf/14/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key14},message:"must NOT have additional properties"};
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
if(!(validate211(data.float32, {instancePath:instancePath+"/float32",parentData:data,parentDataProperty:"float32",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate211.errors : vErrors.concat(validate211.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err44 = {instancePath,schemaPath:"#/oneOf/14/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err45 = {instancePath,schemaPath:"#/oneOf/15/required",keyword:"required",params:{missingProperty: missing15},message:"must have required property '"+missing15+"'"};
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
const err46 = {instancePath,schemaPath:"#/oneOf/15/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key15},message:"must NOT have additional properties"};
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
if(!(validate227(data.decimal, {instancePath:instancePath+"/decimal",parentData:data,parentDataProperty:"decimal",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate227.errors : vErrors.concat(validate227.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err47 = {instancePath,schemaPath:"#/oneOf/15/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err48 = {instancePath,schemaPath:"#/oneOf/16/required",keyword:"required",params:{missingProperty: missing16},message:"must have required property '"+missing16+"'"};
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
const err49 = {instancePath,schemaPath:"#/oneOf/16/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key16},message:"must NOT have additional properties"};
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
if(!(validate211(data.date, {instancePath:instancePath+"/date",parentData:data,parentDataProperty:"date",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate211.errors : vErrors.concat(validate211.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err50 = {instancePath,schemaPath:"#/oneOf/16/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err51 = {instancePath,schemaPath:"#/oneOf/17/required",keyword:"required",params:{missingProperty: missing17},message:"must have required property '"+missing17+"'"};
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
const err52 = {instancePath,schemaPath:"#/oneOf/17/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key17},message:"must NOT have additional properties"};
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
if(!(validate211(data.time, {instancePath:instancePath+"/time",parentData:data,parentDataProperty:"time",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate211.errors : vErrors.concat(validate211.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err53 = {instancePath,schemaPath:"#/oneOf/17/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err54 = {instancePath,schemaPath:"#/oneOf/18/required",keyword:"required",params:{missingProperty: missing18},message:"must have required property '"+missing18+"'"};
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
const err55 = {instancePath,schemaPath:"#/oneOf/18/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key18},message:"must NOT have additional properties"};
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
if(!(validate234(data.timestamp, {instancePath:instancePath+"/timestamp",parentData:data,parentDataProperty:"timestamp",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate234.errors : vErrors.concat(validate234.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err56 = {instancePath,schemaPath:"#/oneOf/18/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err57 = {instancePath,schemaPath:"#/oneOf/19/required",keyword:"required",params:{missingProperty: missing19},message:"must have required property '"+missing19+"'"};
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
const err58 = {instancePath,schemaPath:"#/oneOf/19/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key19},message:"must NOT have additional properties"};
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
if(!(validate211(data.interval, {instancePath:instancePath+"/interval",parentData:data,parentDataProperty:"interval",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate211.errors : vErrors.concat(validate211.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err59 = {instancePath,schemaPath:"#/oneOf/19/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err60 = {instancePath,schemaPath:"#/oneOf/20/required",keyword:"required",params:{missingProperty: missing20},message:"must have required property '"+missing20+"'"};
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
const err61 = {instancePath,schemaPath:"#/oneOf/20/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key20},message:"must NOT have additional properties"};
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
if(!(validate211(data.uuid, {instancePath:instancePath+"/uuid",parentData:data,parentDataProperty:"uuid",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate211.errors : vErrors.concat(validate211.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err62 = {instancePath,schemaPath:"#/oneOf/20/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err63 = {instancePath,schemaPath:"#/oneOf/21/required",keyword:"required",params:{missingProperty: missing21},message:"must have required property '"+missing21+"'"};
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
const err64 = {instancePath,schemaPath:"#/oneOf/21/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key21},message:"must NOT have additional properties"};
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
if(!(validate238(data.structure, {instancePath:instancePath+"/structure",parentData:data,parentDataProperty:"structure",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate238.errors : vErrors.concat(validate238.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err65 = {instancePath,schemaPath:"#/oneOf/21/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err66 = {instancePath,schemaPath:"#/oneOf/22/required",keyword:"required",params:{missingProperty: missing22},message:"must have required property '"+missing22+"'"};
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
const err67 = {instancePath,schemaPath:"#/oneOf/22/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key22},message:"must NOT have additional properties"};
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
if(!(validate288(data.list, {instancePath:instancePath+"/list",parentData:data,parentDataProperty:"list",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate288.errors : vErrors.concat(validate288.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err68 = {instancePath,schemaPath:"#/oneOf/22/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err69 = {instancePath,schemaPath:"#/oneOf/23/required",keyword:"required",params:{missingProperty: missing23},message:"must have required property '"+missing23+"'"};
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
const err70 = {instancePath,schemaPath:"#/oneOf/23/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key23},message:"must NOT have additional properties"};
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
if(!(validate291(data.array, {instancePath:instancePath+"/array",parentData:data,parentDataProperty:"array",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate291.errors : vErrors.concat(validate291.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err71 = {instancePath,schemaPath:"#/oneOf/23/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err72 = {instancePath,schemaPath:"#/oneOf/24/required",keyword:"required",params:{missingProperty: missing24},message:"must have required property '"+missing24+"'"};
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
const err73 = {instancePath,schemaPath:"#/oneOf/24/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key24},message:"must NOT have additional properties"};
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
if(!(validate295(data.map, {instancePath:instancePath+"/map",parentData:data,parentDataProperty:"map",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate295.errors : vErrors.concat(validate295.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err74 = {instancePath,schemaPath:"#/oneOf/24/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err75 = {instancePath,schemaPath:"#/oneOf/25/required",keyword:"required",params:{missingProperty: missing25},message:"must have required property '"+missing25+"'"};
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
const err76 = {instancePath,schemaPath:"#/oneOf/25/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key25},message:"must NOT have additional properties"};
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
if(!(validate238(data.tagged_union, {instancePath:instancePath+"/tagged_union",parentData:data,parentDataProperty:"tagged_union",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate238.errors : vErrors.concat(validate238.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err77 = {instancePath,schemaPath:"#/oneOf/25/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err78 = {instancePath,schemaPath:"#/oneOf/26/required",keyword:"required",params:{missingProperty: missing26},message:"must have required property '"+missing26+"'"};
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
const err79 = {instancePath,schemaPath:"#/oneOf/26/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key26},message:"must NOT have additional properties"};
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
if(!(validate211(data.json, {instancePath:instancePath+"/json",parentData:data,parentDataProperty:"json",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate211.errors : vErrors.concat(validate211.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err80 = {instancePath,schemaPath:"#/oneOf/26/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err81 = {instancePath,schemaPath:"#/oneOf",keyword:"oneOf",params:{passingSchemas: passing0},message:"must match exactly one schema in oneOf"};
if(vErrors === null){
vErrors = [err81];
}
else {
vErrors.push(err81);
}
errors++;
validate210.errors = vErrors;
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
validate210.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate210.evaluated = {"dynamicProps":true,"dynamicItems":false};


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
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((((((((data.scope === undefined) && (missing0 = "scope")) || ((data.owner === undefined) && (missing0 = "owner"))) || ((data.branch === undefined) && (missing0 = "branch"))) || ((data.namespace === undefined) && (missing0 = "namespace"))) || ((data.object === undefined) && (missing0 = "object"))) || ((data.interpretation === undefined) && (missing0 = "interpretation"))) || ((data.row_type === undefined) && (missing0 = "row_type"))){
validate192.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((((((key0 === "scope") || (key0 === "owner")) || (key0 === "branch")) || (key0 === "namespace")) || (key0 === "object")) || (key0 === "interpretation")) || (key0 === "row_type"))){
validate192.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.scope !== undefined){
const _errs2 = errors;
if(!(validate193(data.scope, {instancePath:instancePath+"/scope",parentData:data,parentDataProperty:"scope",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate193.errors : vErrors.concat(validate193.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.owner !== undefined){
const _errs3 = errors;
if(!(validate146(data.owner, {instancePath:instancePath+"/owner",parentData:data,parentDataProperty:"owner",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate146.errors : vErrors.concat(validate146.errors);
errors = vErrors.length;
}
var valid0 = _errs3 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.branch !== undefined){
const _errs4 = errors;
if(!(validate157(data.branch, {instancePath:instancePath+"/branch",parentData:data,parentDataProperty:"branch",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate157.errors : vErrors.concat(validate157.errors);
errors = vErrors.length;
}
var valid0 = _errs4 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.namespace !== undefined){
const _errs5 = errors;
if(!(validate146(data.namespace, {instancePath:instancePath+"/namespace",parentData:data,parentDataProperty:"namespace",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate146.errors : vErrors.concat(validate146.errors);
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
if(!(validate157(data.object, {instancePath:instancePath+"/object",parentData:data,parentDataProperty:"object",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate157.errors : vErrors.concat(validate157.errors);
errors = vErrors.length;
}
var valid0 = _errs6 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.interpretation !== undefined){
const _errs7 = errors;
if(!(validate202(data.interpretation, {instancePath:instancePath+"/interpretation",parentData:data,parentDataProperty:"interpretation",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate202.errors : vErrors.concat(validate202.errors);
errors = vErrors.length;
}
var valid0 = _errs7 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.row_type !== undefined){
const _errs8 = errors;
if(!(validate210(data.row_type, {instancePath:instancePath+"/row_type",parentData:data,parentDataProperty:"row_type",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate210.errors : vErrors.concat(validate210.errors);
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
validate192.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate192.errors = vErrors;
return errors === 0;
}
validate192.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema95 = {"type":"object","additionalProperties":false,"properties":{"reference":{"$ref":"#/$defs/Response/$defs/T44"},"change_format":{"$ref":"#/$defs/Response/$defs/T9"},"expand":{"$ref":"#/$defs/Response/$defs/T45"},"projections":{"$ref":"#/$defs/Response/$defs/T48"}},"required":["reference","change_format","expand","projections"]};
const schema96 = {"type":"object","additionalProperties":false,"properties":{"resource":{"$ref":"#/$defs/Response/$defs/T3"},"document":{"$ref":"#/$defs/Response/$defs/T5"},"epoch":{"$ref":"#/$defs/Response/$defs/T5"},"type_revision":{"$ref":"#/$defs/Response/$defs/T9"},"revision":{"$ref":"#/$defs/Response/$defs/T5"}},"required":["resource","document","epoch","type_revision","revision"]};

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
if((((((data.resource === undefined) && (missing0 = "resource")) || ((data.document === undefined) && (missing0 = "document"))) || ((data.epoch === undefined) && (missing0 = "epoch"))) || ((data.type_revision === undefined) && (missing0 = "type_revision"))) || ((data.revision === undefined) && (missing0 = "revision"))){
validate303.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((((key0 === "resource") || (key0 === "document")) || (key0 === "epoch")) || (key0 === "type_revision")) || (key0 === "revision"))){
validate303.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.resource !== undefined){
const _errs2 = errors;
if(!(validate146(data.resource, {instancePath:instancePath+"/resource",parentData:data,parentDataProperty:"resource",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate146.errors : vErrors.concat(validate146.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.document !== undefined){
const _errs3 = errors;
if(!(validate157(data.document, {instancePath:instancePath+"/document",parentData:data,parentDataProperty:"document",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate157.errors : vErrors.concat(validate157.errors);
errors = vErrors.length;
}
var valid0 = _errs3 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.epoch !== undefined){
const _errs4 = errors;
if(!(validate157(data.epoch, {instancePath:instancePath+"/epoch",parentData:data,parentDataProperty:"epoch",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate157.errors : vErrors.concat(validate157.errors);
errors = vErrors.length;
}
var valid0 = _errs4 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.type_revision !== undefined){
const _errs5 = errors;
if(!(validate166(data.type_revision, {instancePath:instancePath+"/type_revision",parentData:data,parentDataProperty:"type_revision",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate166.errors : vErrors.concat(validate166.errors);
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
if(!(validate157(data.revision, {instancePath:instancePath+"/revision",parentData:data,parentDataProperty:"revision",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate157.errors : vErrors.concat(validate157.errors);
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
validate303.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate303.errors = vErrors;
return errors === 0;
}
validate303.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema97 = {"anyOf":[{"$ref":"#/$defs/Response/$defs/T46"},{"type":"null"}]};
const schema98 = {"type":"array","maxItems":8,"items":{"$ref":"#/$defs/Response/$defs/T47"}};
const schema99 = {"type":"string","maxLength":131072};

function validate313(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate313.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(typeof data === "string"){
if(func1(data) > 131072){
validate313.errors = [{instancePath,schemaPath:"#/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"}];
return false;
}
}
else {
validate313.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
}
validate313.errors = vErrors;
return errors === 0;
}
validate313.evaluated = {"dynamicProps":false,"dynamicItems":false};


function validate312(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate312.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(Array.isArray(data)){
if(data.length > 8){
validate312.errors = [{instancePath,schemaPath:"#/maxItems",keyword:"maxItems",params:{limit: 8},message:"must NOT have more than 8 items"}];
return false;
}
else {
var valid0 = true;
const len0 = data.length;
for(let i0=0; i0<len0; i0++){
const _errs1 = errors;
if(!(validate313(data[i0], {instancePath:instancePath+"/" + i0,parentData:data,parentDataProperty:i0,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate313.errors : vErrors.concat(validate313.errors);
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
validate312.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "array"},message:"must be array"}];
return false;
}
}
validate312.errors = vErrors;
return errors === 0;
}
validate312.evaluated = {"items":true,"dynamicProps":false,"dynamicItems":false};


function validate311(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate311.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate312(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate312.errors : vErrors.concat(validate312.errors);
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
validate311.errors = vErrors;
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
validate311.errors = vErrors;
evaluated0.items = items0;
return errors === 0;
}
validate311.evaluated = {"dynamicProps":false,"dynamicItems":true};

const schema100 = {"type":"array","maxItems":8,"items":{"$ref":"#/$defs/Response/$defs/T49"}};
const schema101 = {"type":"object","additionalProperties":false,"properties":{"column":{"$ref":"#/$defs/Response/$defs/T50"},"path":{"$ref":"#/$defs/Response/$defs/T46"},"relative":{"$ref":"#/$defs/Response/$defs/T52"},"mode":{"$ref":"#/$defs/Response/$defs/T53"},"text_bytes":{"$ref":"#/$defs/Response/$defs/T54"},"text_steps":{"$ref":"#/$defs/Response/$defs/T54"}},"required":["column","path","relative","mode","text_bytes","text_steps"]};
const schema102 = {"type":"object","additionalProperties":false,"properties":{"name":{"$ref":"#/$defs/Response/$defs/T47"},"type":{"$ref":"#/$defs/Response/$defs/T51"}},"required":["name","type"]};

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
if(!((((((data === "int64") || (data === "uint64")) || (data === "float64")) || (data === "boolean")) || (data === "utf8")) || (data === "binary"))){
validate321.errors = [{instancePath,schemaPath:"#/enum",keyword:"enum",params:{allowedValues: schema68.enum},message:"must be equal to one of the allowed values"}];
return false;
}
validate321.errors = vErrors;
return errors === 0;
}
validate321.evaluated = {"dynamicProps":false,"dynamicItems":false};


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
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if(((data.name === undefined) && (missing0 = "name")) || ((data.type === undefined) && (missing0 = "type"))){
validate319.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "name") || (key0 === "type"))){
validate319.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.name !== undefined){
const _errs2 = errors;
if(!(validate313(data.name, {instancePath:instancePath+"/name",parentData:data,parentDataProperty:"name",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate313.errors : vErrors.concat(validate313.errors);
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
if(!(validate321(data.type, {instancePath:instancePath+"/type",parentData:data,parentDataProperty:"type",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate321.errors : vErrors.concat(validate321.errors);
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
validate319.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate319.errors = vErrors;
return errors === 0;
}
validate319.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema104 = {"type":"boolean"};

function validate325(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate325.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "boolean"){
validate325.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"}];
return false;
}
validate325.errors = vErrors;
return errors === 0;
}
validate325.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema105 = {"type":"string","enum":["scalar","text","element_counter","element_replica"]};

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
if(!((((data === "scalar") || (data === "text")) || (data === "element_counter")) || (data === "element_replica"))){
validate327.errors = [{instancePath,schemaPath:"#/enum",keyword:"enum",params:{allowedValues: schema105.enum},message:"must be equal to one of the allowed values"}];
return false;
}
validate327.errors = vErrors;
return errors === 0;
}
validate327.evaluated = {"dynamicProps":false,"dynamicItems":false};


function validate329(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate329.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(!(((typeof data == "number") && (!(data % 1) && !isNaN(data))) && (isFinite(data)))){
validate329.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "integer"},message:"must be integer"}];
return false;
}
if(errors === 0){
if((typeof data == "number") && (isFinite(data))){
if(data > 65535 || isNaN(data)){
validate329.errors = [{instancePath,schemaPath:"#/maximum",keyword:"maximum",params:{comparison: "<=", limit: 65535},message:"must be <= 65535"}];
return false;
}
else {
if(data < 0 || isNaN(data)){
validate329.errors = [{instancePath,schemaPath:"#/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"}];
return false;
}
}
}
}
validate329.errors = vErrors;
return errors === 0;
}
validate329.evaluated = {"dynamicProps":false,"dynamicItems":false};


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
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if(((((((data.column === undefined) && (missing0 = "column")) || ((data.path === undefined) && (missing0 = "path"))) || ((data.relative === undefined) && (missing0 = "relative"))) || ((data.mode === undefined) && (missing0 = "mode"))) || ((data.text_bytes === undefined) && (missing0 = "text_bytes"))) || ((data.text_steps === undefined) && (missing0 = "text_steps"))){
validate318.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((((((key0 === "column") || (key0 === "path")) || (key0 === "relative")) || (key0 === "mode")) || (key0 === "text_bytes")) || (key0 === "text_steps"))){
validate318.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.column !== undefined){
const _errs2 = errors;
if(!(validate319(data.column, {instancePath:instancePath+"/column",parentData:data,parentDataProperty:"column",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate319.errors : vErrors.concat(validate319.errors);
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
if(!(validate312(data.path, {instancePath:instancePath+"/path",parentData:data,parentDataProperty:"path",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate312.errors : vErrors.concat(validate312.errors);
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
if(!(validate325(data.relative, {instancePath:instancePath+"/relative",parentData:data,parentDataProperty:"relative",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate325.errors : vErrors.concat(validate325.errors);
errors = vErrors.length;
}
var valid0 = _errs4 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.mode !== undefined){
const _errs5 = errors;
if(!(validate327(data.mode, {instancePath:instancePath+"/mode",parentData:data,parentDataProperty:"mode",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate327.errors : vErrors.concat(validate327.errors);
errors = vErrors.length;
}
var valid0 = _errs5 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.text_bytes !== undefined){
const _errs6 = errors;
if(!(validate329(data.text_bytes, {instancePath:instancePath+"/text_bytes",parentData:data,parentDataProperty:"text_bytes",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate329.errors : vErrors.concat(validate329.errors);
errors = vErrors.length;
}
var valid0 = _errs6 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.text_steps !== undefined){
const _errs7 = errors;
if(!(validate329(data.text_steps, {instancePath:instancePath+"/text_steps",parentData:data,parentDataProperty:"text_steps",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate329.errors : vErrors.concat(validate329.errors);
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
validate318.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate318.errors = vErrors;
return errors === 0;
}
validate318.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


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
if(errors === 0){
if(Array.isArray(data)){
if(data.length > 8){
validate317.errors = [{instancePath,schemaPath:"#/maxItems",keyword:"maxItems",params:{limit: 8},message:"must NOT have more than 8 items"}];
return false;
}
else {
var valid0 = true;
const len0 = data.length;
for(let i0=0; i0<len0; i0++){
const _errs1 = errors;
if(!(validate318(data[i0], {instancePath:instancePath+"/" + i0,parentData:data,parentDataProperty:i0,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate318.errors : vErrors.concat(validate318.errors);
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
validate317.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "array"},message:"must be array"}];
return false;
}
}
validate317.errors = vErrors;
return errors === 0;
}
validate317.evaluated = {"items":true,"dynamicProps":false,"dynamicItems":false};


function validate302(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate302.evaluated;
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
validate302.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((((key0 === "reference") || (key0 === "change_format")) || (key0 === "expand")) || (key0 === "projections"))){
validate302.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.reference !== undefined){
const _errs2 = errors;
if(!(validate303(data.reference, {instancePath:instancePath+"/reference",parentData:data,parentDataProperty:"reference",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate303.errors : vErrors.concat(validate303.errors);
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
if(!(validate166(data.change_format, {instancePath:instancePath+"/change_format",parentData:data,parentDataProperty:"change_format",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate166.errors : vErrors.concat(validate166.errors);
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
if(!(validate311(data.expand, {instancePath:instancePath+"/expand",parentData:data,parentDataProperty:"expand",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate311.errors : vErrors.concat(validate311.errors);
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
if(!(validate317(data.projections, {instancePath:instancePath+"/projections",parentData:data,parentDataProperty:"projections",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate317.errors : vErrors.concat(validate317.errors);
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
validate302.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate302.errors = vErrors;
return errors === 0;
}
validate302.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate181(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate181.evaluated;
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
if((data.kv === undefined) && (missing0 = "kv")){
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
if(!(key0 === "kv")){
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
if(data.kv !== undefined){
if(!(validate182(data.kv, {instancePath:instancePath+"/kv",parentData:data,parentDataProperty:"kv",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate182.errors : vErrors.concat(validate182.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err2 = {instancePath,schemaPath:"#/oneOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
if((data.table === undefined) && (missing1 = "table")){
const err3 = {instancePath,schemaPath:"#/oneOf/1/required",keyword:"required",params:{missingProperty: missing1},message:"must have required property '"+missing1+"'"};
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
if(!(key1 === "table")){
const err4 = {instancePath,schemaPath:"#/oneOf/1/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key1},message:"must NOT have additional properties"};
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
if(data.table !== undefined){
if(!(validate192(data.table, {instancePath:instancePath+"/table",parentData:data,parentDataProperty:"table",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate192.errors : vErrors.concat(validate192.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err5 = {instancePath,schemaPath:"#/oneOf/1/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
if((data.document === undefined) && (missing2 = "document")){
const err6 = {instancePath,schemaPath:"#/oneOf/2/required",keyword:"required",params:{missingProperty: missing2},message:"must have required property '"+missing2+"'"};
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
if(!(key2 === "document")){
const err7 = {instancePath,schemaPath:"#/oneOf/2/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key2},message:"must NOT have additional properties"};
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
if(data.document !== undefined){
if(!(validate302(data.document, {instancePath:instancePath+"/document",parentData:data,parentDataProperty:"document",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate302.errors : vErrors.concat(validate302.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err8 = {instancePath,schemaPath:"#/oneOf/2/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err9 = {instancePath,schemaPath:"#/oneOf",keyword:"oneOf",params:{passingSchemas: passing0},message:"must match exactly one schema in oneOf"};
if(vErrors === null){
vErrors = [err9];
}
else {
vErrors.push(err9);
}
errors++;
validate181.errors = vErrors;
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
validate181.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate181.evaluated = {"dynamicProps":true,"dynamicItems":false};


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
if((((data.version === undefined) && (missing0 = "version")) || ((data.resource === undefined) && (missing0 = "resource"))) || ((data.source === undefined) && (missing0 = "source"))){
validate178.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "version") || (key0 === "resource")) || (key0 === "source"))){
validate178.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.version !== undefined){
const _errs2 = errors;
if(!(validate161(data.version, {instancePath:instancePath+"/version",parentData:data,parentDataProperty:"version",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate161.errors : vErrors.concat(validate161.errors);
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
if(!(validate146(data.resource, {instancePath:instancePath+"/resource",parentData:data,parentDataProperty:"resource",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate146.errors : vErrors.concat(validate146.errors);
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
if(!(validate181(data.source, {instancePath:instancePath+"/source",parentData:data,parentDataProperty:"source",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate181.errors : vErrors.concat(validate181.errors);
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
validate178.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate178.errors = vErrors;
return errors === 0;
}
validate178.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema107 = {"type":"object","additionalProperties":false,"properties":{"pages":{"$ref":"#/$defs/Response/$defs/T5"},"segments":{"$ref":"#/$defs/Response/$defs/T5"},"result_bytes":{"$ref":"#/$defs/Response/$defs/T5"}},"required":["pages","segments","result_bytes"]};

function validate339(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate339.evaluated;
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
validate339.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "pages") || (key0 === "segments")) || (key0 === "result_bytes"))){
validate339.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.pages !== undefined){
const _errs2 = errors;
if(!(validate157(data.pages, {instancePath:instancePath+"/pages",parentData:data,parentDataProperty:"pages",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate157.errors : vErrors.concat(validate157.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.segments !== undefined){
const _errs3 = errors;
if(!(validate157(data.segments, {instancePath:instancePath+"/segments",parentData:data,parentDataProperty:"segments",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate157.errors : vErrors.concat(validate157.errors);
errors = vErrors.length;
}
var valid0 = _errs3 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.result_bytes !== undefined){
const _errs4 = errors;
if(!(validate157(data.result_bytes, {instancePath:instancePath+"/result_bytes",parentData:data,parentDataProperty:"result_bytes",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate157.errors : vErrors.concat(validate157.errors);
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
validate339.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate339.errors = vErrors;
return errors === 0;
}
validate339.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema108 = {"anyOf":[{"$ref":"#/$defs/Response/$defs/T5"},{"type":"null"}]};

function validate344(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate344.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate157(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate157.errors : vErrors.concat(validate157.errors);
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
validate344.errors = vErrors;
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
validate344.errors = vErrors;
return errors === 0;
}
validate344.evaluated = {"dynamicProps":false,"dynamicItems":false};


function validate159(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate159.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if(((((((data.capabilities === undefined) && (missing0 = "capabilities")) || ((data.source === undefined) && (missing0 = "source"))) || ((data.resource_revision === undefined) && (missing0 = "resource_revision"))) || ((data.policy_revision === undefined) && (missing0 = "policy_revision"))) || ((data.limits === undefined) && (missing0 = "limits"))) || ((data.active === undefined) && (missing0 = "active"))){
validate159.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((((((key0 === "capabilities") || (key0 === "source")) || (key0 === "resource_revision")) || (key0 === "policy_revision")) || (key0 === "limits")) || (key0 === "active"))){
validate159.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.capabilities !== undefined){
const _errs2 = errors;
if(!(validate160(data.capabilities, {instancePath:instancePath+"/capabilities",parentData:data,parentDataProperty:"capabilities",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate160.errors : vErrors.concat(validate160.errors);
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
if(!(validate178(data.source, {instancePath:instancePath+"/source",parentData:data,parentDataProperty:"source",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate178.errors : vErrors.concat(validate178.errors);
errors = vErrors.length;
}
var valid0 = _errs3 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.resource_revision !== undefined){
const _errs4 = errors;
if(!(validate146(data.resource_revision, {instancePath:instancePath+"/resource_revision",parentData:data,parentDataProperty:"resource_revision",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate146.errors : vErrors.concat(validate146.errors);
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
if(!(validate157(data.policy_revision, {instancePath:instancePath+"/policy_revision",parentData:data,parentDataProperty:"policy_revision",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate157.errors : vErrors.concat(validate157.errors);
errors = vErrors.length;
}
var valid0 = _errs5 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.limits !== undefined){
const _errs6 = errors;
if(!(validate339(data.limits, {instancePath:instancePath+"/limits",parentData:data,parentDataProperty:"limits",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate339.errors : vErrors.concat(validate339.errors);
errors = vErrors.length;
}
var valid0 = _errs6 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.active !== undefined){
const _errs7 = errors;
if(!(validate344(data.active, {instancePath:instancePath+"/active",parentData:data,parentDataProperty:"active",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate344.errors : vErrors.concat(validate344.errors);
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
validate159.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate159.errors = vErrors;
return errors === 0;
}
validate159.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema109 = {"type":"object","additionalProperties":false,"properties":{"version":{"$ref":"#/$defs/Response/$defs/T8"},"statement_bytes":{"$ref":"#/$defs/Response/$defs/T9"},"named_columns":{"$ref":"#/$defs/Response/$defs/T8"},"star_columns":{"$ref":"#/$defs/Response/$defs/T8"},"uint64_limits":{"$ref":"#/$defs/Response/$defs/T11"},"uint64_literals":{"$ref":"#/$defs/Response/$defs/T11"},"float64_literals":{"$ref":"#/$defs/Response/$defs/T11"},"null_comparison":{"$ref":"#/$defs/Response/$defs/T11"},"explicit_null_test":{"$ref":"#/$defs/Response/$defs/T11"},"writes":{"$ref":"#/$defs/Response/$defs/T11"},"continuous":{"$ref":"#/$defs/Response/$defs/T11"}},"required":["version","statement_bytes","named_columns","star_columns","uint64_limits","uint64_literals","float64_literals","null_comparison","explicit_null_test","writes","continuous"]};

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
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((((((((((((data.version === undefined) && (missing0 = "version")) || ((data.statement_bytes === undefined) && (missing0 = "statement_bytes"))) || ((data.named_columns === undefined) && (missing0 = "named_columns"))) || ((data.star_columns === undefined) && (missing0 = "star_columns"))) || ((data.uint64_limits === undefined) && (missing0 = "uint64_limits"))) || ((data.uint64_literals === undefined) && (missing0 = "uint64_literals"))) || ((data.float64_literals === undefined) && (missing0 = "float64_literals"))) || ((data.null_comparison === undefined) && (missing0 = "null_comparison"))) || ((data.explicit_null_test === undefined) && (missing0 = "explicit_null_test"))) || ((data.writes === undefined) && (missing0 = "writes"))) || ((data.continuous === undefined) && (missing0 = "continuous"))){
validate348.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(func4.call(schema109.properties, key0))){
validate348.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.version !== undefined){
const _errs2 = errors;
if(!(validate161(data.version, {instancePath:instancePath+"/version",parentData:data,parentDataProperty:"version",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate161.errors : vErrors.concat(validate161.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.statement_bytes !== undefined){
const _errs3 = errors;
if(!(validate166(data.statement_bytes, {instancePath:instancePath+"/statement_bytes",parentData:data,parentDataProperty:"statement_bytes",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate166.errors : vErrors.concat(validate166.errors);
errors = vErrors.length;
}
var valid0 = _errs3 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.named_columns !== undefined){
const _errs4 = errors;
if(!(validate161(data.named_columns, {instancePath:instancePath+"/named_columns",parentData:data,parentDataProperty:"named_columns",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate161.errors : vErrors.concat(validate161.errors);
errors = vErrors.length;
}
var valid0 = _errs4 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.star_columns !== undefined){
const _errs5 = errors;
if(!(validate161(data.star_columns, {instancePath:instancePath+"/star_columns",parentData:data,parentDataProperty:"star_columns",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate161.errors : vErrors.concat(validate161.errors);
errors = vErrors.length;
}
var valid0 = _errs5 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.uint64_limits !== undefined){
const _errs6 = errors;
if(!(validate173(data.uint64_limits, {instancePath:instancePath+"/uint64_limits",parentData:data,parentDataProperty:"uint64_limits",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate173.errors : vErrors.concat(validate173.errors);
errors = vErrors.length;
}
var valid0 = _errs6 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.uint64_literals !== undefined){
const _errs7 = errors;
if(!(validate173(data.uint64_literals, {instancePath:instancePath+"/uint64_literals",parentData:data,parentDataProperty:"uint64_literals",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate173.errors : vErrors.concat(validate173.errors);
errors = vErrors.length;
}
var valid0 = _errs7 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.float64_literals !== undefined){
const _errs8 = errors;
if(!(validate173(data.float64_literals, {instancePath:instancePath+"/float64_literals",parentData:data,parentDataProperty:"float64_literals",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate173.errors : vErrors.concat(validate173.errors);
errors = vErrors.length;
}
var valid0 = _errs8 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.null_comparison !== undefined){
const _errs9 = errors;
if(!(validate173(data.null_comparison, {instancePath:instancePath+"/null_comparison",parentData:data,parentDataProperty:"null_comparison",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate173.errors : vErrors.concat(validate173.errors);
errors = vErrors.length;
}
var valid0 = _errs9 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.explicit_null_test !== undefined){
const _errs10 = errors;
if(!(validate173(data.explicit_null_test, {instancePath:instancePath+"/explicit_null_test",parentData:data,parentDataProperty:"explicit_null_test",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate173.errors : vErrors.concat(validate173.errors);
errors = vErrors.length;
}
var valid0 = _errs10 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.writes !== undefined){
const _errs11 = errors;
if(!(validate173(data.writes, {instancePath:instancePath+"/writes",parentData:data,parentDataProperty:"writes",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate173.errors : vErrors.concat(validate173.errors);
errors = vErrors.length;
}
var valid0 = _errs11 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.continuous !== undefined){
const _errs12 = errors;
if(!(validate173(data.continuous, {instancePath:instancePath+"/continuous",parentData:data,parentDataProperty:"continuous",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate173.errors : vErrors.concat(validate173.errors);
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
validate348.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate348.errors = vErrors;
return errors === 0;
}
validate348.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema110 = {"type":"array","maxItems":128,"items":{"$ref":"#/$defs/Response/$defs/T59"}};
const schema111 = {"type":"object","additionalProperties":false,"properties":{"name":{"$ref":"#/$defs/Response/$defs/T5"},"type":{"$ref":"#/$defs/Response/$defs/T21"},"nullable":{"$ref":"#/$defs/Response/$defs/T11"},"optional":{"$ref":"#/$defs/Response/$defs/T11"}},"required":["name","type","nullable","optional"]};

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
if(((((data.name === undefined) && (missing0 = "name")) || ((data.type === undefined) && (missing0 = "type"))) || ((data.nullable === undefined) && (missing0 = "nullable"))) || ((data.optional === undefined) && (missing0 = "optional"))){
validate363.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((((key0 === "name") || (key0 === "type")) || (key0 === "nullable")) || (key0 === "optional"))){
validate363.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.name !== undefined){
const _errs2 = errors;
if(!(validate157(data.name, {instancePath:instancePath+"/name",parentData:data,parentDataProperty:"name",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate157.errors : vErrors.concat(validate157.errors);
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
if(!(validate210(data.type, {instancePath:instancePath+"/type",parentData:data,parentDataProperty:"type",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate210.errors : vErrors.concat(validate210.errors);
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
if(!(validate173(data.nullable, {instancePath:instancePath+"/nullable",parentData:data,parentDataProperty:"nullable",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate173.errors : vErrors.concat(validate173.errors);
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
if(!(validate173(data.optional, {instancePath:instancePath+"/optional",parentData:data,parentDataProperty:"optional",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate173.errors : vErrors.concat(validate173.errors);
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
validate363.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate363.errors = vErrors;
return errors === 0;
}
validate363.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


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
if(data.length > 128){
validate362.errors = [{instancePath,schemaPath:"#/maxItems",keyword:"maxItems",params:{limit: 128},message:"must NOT have more than 128 items"}];
return false;
}
else {
var valid0 = true;
const len0 = data.length;
for(let i0=0; i0<len0; i0++){
const _errs1 = errors;
if(!(validate363(data[i0], {instancePath:instancePath+"/" + i0,parentData:data,parentDataProperty:i0,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate363.errors : vErrors.concat(validate363.errors);
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
validate362.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "array"},message:"must be array"}];
return false;
}
}
validate362.errors = vErrors;
return errors === 0;
}
validate362.evaluated = {"items":true,"dynamicProps":false,"dynamicItems":false};


function validate144(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate144.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if(((((((data.connection === undefined) && (missing0 = "connection")) || ((data.name === undefined) && (missing0 = "name"))) || ((data.source === undefined) && (missing0 = "source"))) || ((data.sql === undefined) && (missing0 = "sql"))) || ((data.budgets === undefined) && (missing0 = "budgets"))) || ((data.columns === undefined) && (missing0 = "columns"))){
validate144.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((((((key0 === "connection") || (key0 === "name")) || (key0 === "source")) || (key0 === "sql")) || (key0 === "budgets")) || (key0 === "columns"))){
validate144.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.connection !== undefined){
const _errs2 = errors;
if(!(validate145(data.connection, {instancePath:instancePath+"/connection",parentData:data,parentDataProperty:"connection",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate145.errors : vErrors.concat(validate145.errors);
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
if(!(validate157(data.name, {instancePath:instancePath+"/name",parentData:data,parentDataProperty:"name",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate157.errors : vErrors.concat(validate157.errors);
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
if(!(validate159(data.source, {instancePath:instancePath+"/source",parentData:data,parentDataProperty:"source",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate159.errors : vErrors.concat(validate159.errors);
errors = vErrors.length;
}
var valid0 = _errs4 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.sql !== undefined){
const _errs5 = errors;
if(!(validate348(data.sql, {instancePath:instancePath+"/sql",parentData:data,parentDataProperty:"sql",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate348.errors : vErrors.concat(validate348.errors);
errors = vErrors.length;
}
var valid0 = _errs5 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.budgets !== undefined){
const _errs6 = errors;
if(!(validate339(data.budgets, {instancePath:instancePath+"/budgets",parentData:data,parentDataProperty:"budgets",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate339.errors : vErrors.concat(validate339.errors);
errors = vErrors.length;
}
var valid0 = _errs6 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.columns !== undefined){
const _errs7 = errors;
if(!(validate362(data.columns, {instancePath:instancePath+"/columns",parentData:data,parentDataProperty:"columns",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate362.errors : vErrors.concat(validate362.errors);
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
validate144.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate144.errors = vErrors;
return errors === 0;
}
validate144.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema112 = {"type":"object","additionalProperties":false,"properties":{"version":{"$ref":"#/$defs/Response/$defs/T8"},"parameters":{"$ref":"#/$defs/Response/$defs/T11"},"max_parameters":{"$ref":"#/$defs/Response/$defs/T8"},"statement_bytes":{"$ref":"#/$defs/Response/$defs/T9"}},"required":["version","parameters","max_parameters","statement_bytes"]};

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
if(((((data.version === undefined) && (missing0 = "version")) || ((data.parameters === undefined) && (missing0 = "parameters"))) || ((data.max_parameters === undefined) && (missing0 = "max_parameters"))) || ((data.statement_bytes === undefined) && (missing0 = "statement_bytes"))){
validate371.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((((key0 === "version") || (key0 === "parameters")) || (key0 === "max_parameters")) || (key0 === "statement_bytes"))){
validate371.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.version !== undefined){
const _errs2 = errors;
if(!(validate161(data.version, {instancePath:instancePath+"/version",parentData:data,parentDataProperty:"version",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate161.errors : vErrors.concat(validate161.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.parameters !== undefined){
const _errs3 = errors;
if(!(validate173(data.parameters, {instancePath:instancePath+"/parameters",parentData:data,parentDataProperty:"parameters",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate173.errors : vErrors.concat(validate173.errors);
errors = vErrors.length;
}
var valid0 = _errs3 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.max_parameters !== undefined){
const _errs4 = errors;
if(!(validate161(data.max_parameters, {instancePath:instancePath+"/max_parameters",parentData:data,parentDataProperty:"max_parameters",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate161.errors : vErrors.concat(validate161.errors);
errors = vErrors.length;
}
var valid0 = _errs4 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.statement_bytes !== undefined){
const _errs5 = errors;
if(!(validate166(data.statement_bytes, {instancePath:instancePath+"/statement_bytes",parentData:data,parentDataProperty:"statement_bytes",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate166.errors : vErrors.concat(validate166.errors);
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
validate371.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate371.errors = vErrors;
return errors === 0;
}
validate371.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema113 = {"type":"object","additionalProperties":false,"properties":{"resource":{"$ref":"#/$defs/Response/$defs/T3"},"contract":{"$ref":"#/$defs/Response/$defs/T20"},"items":{"$ref":"#/$defs/Response/$defs/T62"}},"required":["resource","contract","items"]};
const schema114 = {"type":"array","maxItems":128,"items":{"$ref":"#/$defs/Response/$defs/T63"}};
const schema115 = {"type":"object","additionalProperties":false,"properties":{"label":{"$ref":"#/$defs/Response/$defs/T5"},"sql":{"$ref":"#/$defs/Response/$defs/T5"}},"required":["label","sql"]};

function validate381(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate381.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if(((data.label === undefined) && (missing0 = "label")) || ((data.sql === undefined) && (missing0 = "sql"))){
validate381.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "label") || (key0 === "sql"))){
validate381.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.label !== undefined){
const _errs2 = errors;
if(!(validate157(data.label, {instancePath:instancePath+"/label",parentData:data,parentDataProperty:"label",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate157.errors : vErrors.concat(validate157.errors);
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
if(!(validate157(data.sql, {instancePath:instancePath+"/sql",parentData:data,parentDataProperty:"sql",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate157.errors : vErrors.concat(validate157.errors);
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
validate381.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate381.errors = vErrors;
return errors === 0;
}
validate381.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


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
if(errors === 0){
if(Array.isArray(data)){
if(data.length > 128){
validate380.errors = [{instancePath,schemaPath:"#/maxItems",keyword:"maxItems",params:{limit: 128},message:"must NOT have more than 128 items"}];
return false;
}
else {
var valid0 = true;
const len0 = data.length;
for(let i0=0; i0<len0; i0++){
const _errs1 = errors;
if(!(validate381(data[i0], {instancePath:instancePath+"/" + i0,parentData:data,parentDataProperty:i0,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate381.errors : vErrors.concat(validate381.errors);
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
validate380.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "array"},message:"must be array"}];
return false;
}
}
validate380.errors = vErrors;
return errors === 0;
}
validate380.evaluated = {"items":true,"dynamicProps":false,"dynamicItems":false};


function validate377(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate377.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((((data.resource === undefined) && (missing0 = "resource")) || ((data.contract === undefined) && (missing0 = "contract"))) || ((data.items === undefined) && (missing0 = "items"))){
validate377.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "resource") || (key0 === "contract")) || (key0 === "items"))){
validate377.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.resource !== undefined){
const _errs2 = errors;
if(!(validate146(data.resource, {instancePath:instancePath+"/resource",parentData:data,parentDataProperty:"resource",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate146.errors : vErrors.concat(validate146.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.contract !== undefined){
const _errs3 = errors;
if(!(validate204(data.contract, {instancePath:instancePath+"/contract",parentData:data,parentDataProperty:"contract",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate204.errors : vErrors.concat(validate204.errors);
errors = vErrors.length;
}
var valid0 = _errs3 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.items !== undefined){
const _errs4 = errors;
if(!(validate380(data.items, {instancePath:instancePath+"/items",parentData:data,parentDataProperty:"items",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate380.errors : vErrors.concat(validate380.errors);
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
validate377.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate377.errors = vErrors;
return errors === 0;
}
validate377.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema116 = {"type":"object","additionalProperties":false,"properties":{"version":{"$ref":"#/$defs/Response/$defs/T8"},"generation":{"$ref":"#/$defs/Response/$defs/T9"},"profile":{"$ref":"#/$defs/Response/$defs/T65"},"resource":{"$ref":"#/$defs/Response/$defs/T3"},"contract":{"$ref":"#/$defs/Response/$defs/T20"},"resource_revision":{"$ref":"#/$defs/Response/$defs/T4"},"policy_revision":{"$ref":"#/$defs/Response/$defs/T5"},"range":{"$ref":"#/$defs/Response/$defs/T66"},"items":{"$ref":"#/$defs/Response/$defs/T68"}},"required":["version","generation","profile","resource","contract","resource_revision","policy_revision","range","items"]};
const schema117 = {"type":"string","enum":["unified_v1","catalog_v1","configuration_v1","direct_table_v1"]};

function validate390(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate390.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate390.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
if(!((((data === "unified_v1") || (data === "catalog_v1")) || (data === "configuration_v1")) || (data === "direct_table_v1"))){
validate390.errors = [{instancePath,schemaPath:"#/enum",keyword:"enum",params:{allowedValues: schema117.enum},message:"must be equal to one of the allowed values"}];
return false;
}
validate390.errors = vErrors;
return errors === 0;
}
validate390.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema118 = {"anyOf":[{"$ref":"#/$defs/Response/$defs/T67"},{"type":"null"}]};
const schema119 = {"type":"object","additionalProperties":false,"properties":{"start":{"$ref":"#/$defs/Response/$defs/T10"},"end":{"$ref":"#/$defs/Response/$defs/T10"},"quoted":{"$ref":"#/$defs/Response/$defs/T11"}},"required":["start","end","quoted"]};

function validate397(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate397.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((((data.start === undefined) && (missing0 = "start")) || ((data.end === undefined) && (missing0 = "end"))) || ((data.quoted === undefined) && (missing0 = "quoted"))){
validate397.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "start") || (key0 === "end")) || (key0 === "quoted"))){
validate397.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.start !== undefined){
const _errs2 = errors;
if(!(validate168(data.start, {instancePath:instancePath+"/start",parentData:data,parentDataProperty:"start",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate168.errors : vErrors.concat(validate168.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.end !== undefined){
const _errs3 = errors;
if(!(validate168(data.end, {instancePath:instancePath+"/end",parentData:data,parentDataProperty:"end",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate168.errors : vErrors.concat(validate168.errors);
errors = vErrors.length;
}
var valid0 = _errs3 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.quoted !== undefined){
const _errs4 = errors;
if(!(validate173(data.quoted, {instancePath:instancePath+"/quoted",parentData:data,parentDataProperty:"quoted",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate173.errors : vErrors.concat(validate173.errors);
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
validate397.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate397.errors = vErrors;
return errors === 0;
}
validate397.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


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
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate397(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate397.errors : vErrors.concat(validate397.errors);
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
validate396.errors = vErrors;
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
validate396.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate396.evaluated = {"dynamicProps":true,"dynamicItems":false};

const schema120 = {"type":"array","maxItems":128,"items":{"$ref":"#/$defs/Response/$defs/T69"}};
const schema121 = {"type":"object","additionalProperties":false,"properties":{"text":{"$ref":"#/$defs/Response/$defs/T5"},"kind":{"$ref":"#/$defs/Response/$defs/T70"},"detail":{"$ref":"#/$defs/Response/$defs/T5"}},"required":["text","kind","detail"]};
const schema122 = {"type":"string","enum":["keyword","source","column","symbol","literal","meta"]};

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
if(!((((((data === "keyword") || (data === "source")) || (data === "column")) || (data === "symbol")) || (data === "literal")) || (data === "meta"))){
validate406.errors = [{instancePath,schemaPath:"#/enum",keyword:"enum",params:{allowedValues: schema122.enum},message:"must be equal to one of the allowed values"}];
return false;
}
validate406.errors = vErrors;
return errors === 0;
}
validate406.evaluated = {"dynamicProps":false,"dynamicItems":false};


function validate404(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate404.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((((data.text === undefined) && (missing0 = "text")) || ((data.kind === undefined) && (missing0 = "kind"))) || ((data.detail === undefined) && (missing0 = "detail"))){
validate404.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "text") || (key0 === "kind")) || (key0 === "detail"))){
validate404.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.text !== undefined){
const _errs2 = errors;
if(!(validate157(data.text, {instancePath:instancePath+"/text",parentData:data,parentDataProperty:"text",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate157.errors : vErrors.concat(validate157.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.kind !== undefined){
const _errs3 = errors;
if(!(validate406(data.kind, {instancePath:instancePath+"/kind",parentData:data,parentDataProperty:"kind",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate406.errors : vErrors.concat(validate406.errors);
errors = vErrors.length;
}
var valid0 = _errs3 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.detail !== undefined){
const _errs4 = errors;
if(!(validate157(data.detail, {instancePath:instancePath+"/detail",parentData:data,parentDataProperty:"detail",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate157.errors : vErrors.concat(validate157.errors);
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
validate404.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate404.errors = vErrors;
return errors === 0;
}
validate404.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate403(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate403.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(Array.isArray(data)){
if(data.length > 128){
validate403.errors = [{instancePath,schemaPath:"#/maxItems",keyword:"maxItems",params:{limit: 128},message:"must NOT have more than 128 items"}];
return false;
}
else {
var valid0 = true;
const len0 = data.length;
for(let i0=0; i0<len0; i0++){
const _errs1 = errors;
if(!(validate404(data[i0], {instancePath:instancePath+"/" + i0,parentData:data,parentDataProperty:i0,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate404.errors : vErrors.concat(validate404.errors);
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
validate403.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "array"},message:"must be array"}];
return false;
}
}
validate403.errors = vErrors;
return errors === 0;
}
validate403.evaluated = {"items":true,"dynamicProps":false,"dynamicItems":false};


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
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((((((((((data.version === undefined) && (missing0 = "version")) || ((data.generation === undefined) && (missing0 = "generation"))) || ((data.profile === undefined) && (missing0 = "profile"))) || ((data.resource === undefined) && (missing0 = "resource"))) || ((data.contract === undefined) && (missing0 = "contract"))) || ((data.resource_revision === undefined) && (missing0 = "resource_revision"))) || ((data.policy_revision === undefined) && (missing0 = "policy_revision"))) || ((data.range === undefined) && (missing0 = "range"))) || ((data.items === undefined) && (missing0 = "items"))){
validate387.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(func4.call(schema116.properties, key0))){
validate387.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.version !== undefined){
const _errs2 = errors;
if(!(validate161(data.version, {instancePath:instancePath+"/version",parentData:data,parentDataProperty:"version",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate161.errors : vErrors.concat(validate161.errors);
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
if(!(validate166(data.generation, {instancePath:instancePath+"/generation",parentData:data,parentDataProperty:"generation",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate166.errors : vErrors.concat(validate166.errors);
errors = vErrors.length;
}
var valid0 = _errs3 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.profile !== undefined){
const _errs4 = errors;
if(!(validate390(data.profile, {instancePath:instancePath+"/profile",parentData:data,parentDataProperty:"profile",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate390.errors : vErrors.concat(validate390.errors);
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
if(!(validate146(data.resource, {instancePath:instancePath+"/resource",parentData:data,parentDataProperty:"resource",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate146.errors : vErrors.concat(validate146.errors);
errors = vErrors.length;
}
var valid0 = _errs5 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.contract !== undefined){
const _errs6 = errors;
if(!(validate204(data.contract, {instancePath:instancePath+"/contract",parentData:data,parentDataProperty:"contract",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate204.errors : vErrors.concat(validate204.errors);
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
if(!(validate153(data.resource_revision, {instancePath:instancePath+"/resource_revision",parentData:data,parentDataProperty:"resource_revision",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate153.errors : vErrors.concat(validate153.errors);
errors = vErrors.length;
}
var valid0 = _errs7 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.policy_revision !== undefined){
const _errs8 = errors;
if(!(validate157(data.policy_revision, {instancePath:instancePath+"/policy_revision",parentData:data,parentDataProperty:"policy_revision",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate157.errors : vErrors.concat(validate157.errors);
errors = vErrors.length;
}
var valid0 = _errs8 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.range !== undefined){
const _errs9 = errors;
if(!(validate396(data.range, {instancePath:instancePath+"/range",parentData:data,parentDataProperty:"range",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate396.errors : vErrors.concat(validate396.errors);
errors = vErrors.length;
}
var valid0 = _errs9 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.items !== undefined){
const _errs10 = errors;
if(!(validate403(data.items, {instancePath:instancePath+"/items",parentData:data,parentDataProperty:"items",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate403.errors : vErrors.concat(validate403.errors);
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
validate387.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate387.errors = vErrors;
return errors === 0;
}
validate387.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema123 = {"type":"object","additionalProperties":false,"properties":{"bundle":{"$ref":"#/$defs/Response/$defs/T5"},"source":{"$ref":"#/$defs/Response/$defs/T12"},"plan":{"$ref":"#/$defs/Response/$defs/T72"},"limits":{"$ref":"#/$defs/Response/$defs/T55"},"contract":{"$ref":"#/$defs/Response/$defs/T20"},"schema":{"$ref":"#/$defs/Response/$defs/T20"}},"required":["bundle","source","plan","limits","contract","schema"]};
const schema124 = {"type":"object","additionalProperties":false,"properties":{"version":{"$ref":"#/$defs/Response/$defs/T8"},"projection":{"$ref":"#/$defs/Response/$defs/T73"},"output_names":{"$ref":"#/$defs/Response/$defs/T74"},"limit":{"$ref":"#/$defs/Response/$defs/T56"},"aggregate":{"$ref":"#/$defs/Response/$defs/T76"},"predicate":{"$ref":"#/$defs/Response/$defs/T77"}},"required":["version","projection","output_names","limit","aggregate","predicate"]};
const schema125 = {"type":"array","maxItems":128,"items":{"$ref":"#/$defs/Response/$defs/T9"}};

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
if(errors === 0){
if(Array.isArray(data)){
if(data.length > 128){
validate417.errors = [{instancePath,schemaPath:"#/maxItems",keyword:"maxItems",params:{limit: 128},message:"must NOT have more than 128 items"}];
return false;
}
else {
var valid0 = true;
const len0 = data.length;
for(let i0=0; i0<len0; i0++){
const _errs1 = errors;
if(!(validate166(data[i0], {instancePath:instancePath+"/" + i0,parentData:data,parentDataProperty:i0,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate166.errors : vErrors.concat(validate166.errors);
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
validate417.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "array"},message:"must be array"}];
return false;
}
}
validate417.errors = vErrors;
return errors === 0;
}
validate417.evaluated = {"items":true,"dynamicProps":false,"dynamicItems":false};

const schema126 = {"anyOf":[{"$ref":"#/$defs/Response/$defs/T75"},{"type":"null"}]};
const schema127 = {"type":"array","maxItems":128,"items":{"$ref":"#/$defs/Response/$defs/T56"}};

function validate421(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate421.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(Array.isArray(data)){
if(data.length > 128){
validate421.errors = [{instancePath,schemaPath:"#/maxItems",keyword:"maxItems",params:{limit: 128},message:"must NOT have more than 128 items"}];
return false;
}
else {
var valid0 = true;
const len0 = data.length;
for(let i0=0; i0<len0; i0++){
const _errs1 = errors;
if(!(validate344(data[i0], {instancePath:instancePath+"/" + i0,parentData:data,parentDataProperty:i0,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate344.errors : vErrors.concat(validate344.errors);
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
validate421.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "array"},message:"must be array"}];
return false;
}
}
validate421.errors = vErrors;
return errors === 0;
}
validate421.evaluated = {"items":true,"dynamicProps":false,"dynamicItems":false};


function validate420(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate420.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate421(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate421.errors : vErrors.concat(validate421.errors);
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
validate420.errors = vErrors;
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
validate420.errors = vErrors;
evaluated0.items = items0;
return errors === 0;
}
validate420.evaluated = {"dynamicProps":false,"dynamicItems":true};

const schema128 = {"type":"string","enum":["rows","count","sum","count_values"]};

function validate426(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate426.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate426.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
if(!((((data === "rows") || (data === "count")) || (data === "sum")) || (data === "count_values"))){
validate426.errors = [{instancePath,schemaPath:"#/enum",keyword:"enum",params:{allowedValues: schema128.enum},message:"must be equal to one of the allowed values"}];
return false;
}
validate426.errors = vErrors;
return errors === 0;
}
validate426.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema129 = {"oneOf":[{"type":"object","additionalProperties":false,"required":["all"],"properties":{"all":{"$ref":"#/$defs/Response/$defs/T22"}}},{"type":"object","additionalProperties":false,"required":["state"],"properties":{"state":{"$ref":"#/$defs/Response/$defs/T78"}}},{"type":"object","additionalProperties":false,"required":["compare"],"properties":{"compare":{"$ref":"#/$defs/Response/$defs/T80"}}},{"type":"object","additionalProperties":false,"required":["null_compare"],"properties":{"null_compare":{"$ref":"#/$defs/Response/$defs/T84"}}},{"type":"object","additionalProperties":false,"required":["program"],"properties":{"program":{"$ref":"#/$defs/Response/$defs/T85"}}}]};
const schema130 = {"type":"object","additionalProperties":false,"properties":{"column":{"$ref":"#/$defs/Response/$defs/T8"},"value":{"$ref":"#/$defs/Response/$defs/T79"}},"required":["column","value"]};
const schema131 = {"type":"string","enum":["missing","null","type_error","value","conflict"]};

function validate433(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate433.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate433.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
if(!(((((data === "missing") || (data === "null")) || (data === "type_error")) || (data === "value")) || (data === "conflict"))){
validate433.errors = [{instancePath,schemaPath:"#/enum",keyword:"enum",params:{allowedValues: schema131.enum},message:"must be equal to one of the allowed values"}];
return false;
}
validate433.errors = vErrors;
return errors === 0;
}
validate433.evaluated = {"dynamicProps":false,"dynamicItems":false};


function validate430(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate430.evaluated;
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
validate430.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "column") || (key0 === "value"))){
validate430.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.column !== undefined){
const _errs2 = errors;
if(!(validate161(data.column, {instancePath:instancePath+"/column",parentData:data,parentDataProperty:"column",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate161.errors : vErrors.concat(validate161.errors);
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
if(!(validate433(data.value, {instancePath:instancePath+"/value",parentData:data,parentDataProperty:"value",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate433.errors : vErrors.concat(validate433.errors);
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
validate430.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate430.errors = vErrors;
return errors === 0;
}
validate430.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema133 = {"type":"object","additionalProperties":false,"properties":{"column":{"$ref":"#/$defs/Response/$defs/T8"},"op":{"$ref":"#/$defs/Response/$defs/T81"},"value":{"$ref":"#/$defs/Response/$defs/T82"}},"required":["column","op","value"]};
const schema134 = {"type":"string","enum":["eq","ne","lt","le","gt","ge"]};

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
validate439.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
if(!((((((data === "eq") || (data === "ne")) || (data === "lt")) || (data === "le")) || (data === "gt")) || (data === "ge"))){
validate439.errors = [{instancePath,schemaPath:"#/enum",keyword:"enum",params:{allowedValues: schema134.enum},message:"must be equal to one of the allowed values"}];
return false;
}
validate439.errors = vErrors;
return errors === 0;
}
validate439.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema136 = {"oneOf":[{"type":"object","additionalProperties":false,"required":["signed"],"properties":{"signed":{"$ref":"#/$defs/Response/$defs/T5"}}},{"type":"object","additionalProperties":false,"required":["unsigned"],"properties":{"unsigned":{"$ref":"#/$defs/Response/$defs/T5"}}},{"type":"object","additionalProperties":false,"required":["decimal"],"properties":{"decimal":{"$ref":"#/$defs/Response/$defs/T5"}}},{"type":"object","additionalProperties":false,"required":["float_bits"],"properties":{"float_bits":{"$ref":"#/$defs/Response/$defs/T5"}}},{"type":"object","additionalProperties":false,"required":["boolean"],"properties":{"boolean":{"$ref":"#/$defs/Response/$defs/T11"}}},{"type":"object","additionalProperties":false,"required":["utf8"],"properties":{"utf8":{"$ref":"#/$defs/Response/$defs/T5"}}},{"type":"object","additionalProperties":false,"required":["binary"],"properties":{"binary":{"$ref":"#/$defs/Response/$defs/T5"}}},{"type":"object","additionalProperties":false,"required":["date_days"],"properties":{"date_days":{"$ref":"#/$defs/Response/$defs/T5"}}},{"type":"object","additionalProperties":false,"required":["time_nanos"],"properties":{"time_nanos":{"$ref":"#/$defs/Response/$defs/T5"}}},{"type":"object","additionalProperties":false,"required":["timestamp_micros"],"properties":{"timestamp_micros":{"$ref":"#/$defs/Response/$defs/T5"}}},{"type":"object","additionalProperties":false,"required":["interval"],"properties":{"interval":{"$ref":"#/$defs/Response/$defs/T83"}}},{"type":"object","additionalProperties":false,"required":["uuid"],"properties":{"uuid":{"$ref":"#/$defs/Response/$defs/T5"}}}]};
const schema137 = {"type":"object","additionalProperties":false,"properties":{"months":{"$ref":"#/$defs/Response/$defs/T5"},"days":{"$ref":"#/$defs/Response/$defs/T5"},"nanos":{"$ref":"#/$defs/Response/$defs/T5"}},"required":["months","days","nanos"]};

function validate452(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate452.evaluated;
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
validate452.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "months") || (key0 === "days")) || (key0 === "nanos"))){
validate452.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.months !== undefined){
const _errs2 = errors;
if(!(validate157(data.months, {instancePath:instancePath+"/months",parentData:data,parentDataProperty:"months",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate157.errors : vErrors.concat(validate157.errors);
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
if(!(validate157(data.days, {instancePath:instancePath+"/days",parentData:data,parentDataProperty:"days",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate157.errors : vErrors.concat(validate157.errors);
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
if(!(validate157(data.nanos, {instancePath:instancePath+"/nanos",parentData:data,parentDataProperty:"nanos",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate157.errors : vErrors.concat(validate157.errors);
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
validate452.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate452.errors = vErrors;
return errors === 0;
}
validate452.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate441(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate441.evaluated;
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
if(!(key0 === "signed")){
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
if(data.signed !== undefined){
if(!(validate157(data.signed, {instancePath:instancePath+"/signed",parentData:data,parentDataProperty:"signed",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate157.errors : vErrors.concat(validate157.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err2 = {instancePath,schemaPath:"#/oneOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err3 = {instancePath,schemaPath:"#/oneOf/1/required",keyword:"required",params:{missingProperty: missing1},message:"must have required property '"+missing1+"'"};
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
const err4 = {instancePath,schemaPath:"#/oneOf/1/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key1},message:"must NOT have additional properties"};
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
if(!(validate157(data.unsigned, {instancePath:instancePath+"/unsigned",parentData:data,parentDataProperty:"unsigned",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate157.errors : vErrors.concat(validate157.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err5 = {instancePath,schemaPath:"#/oneOf/1/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err6 = {instancePath,schemaPath:"#/oneOf/2/required",keyword:"required",params:{missingProperty: missing2},message:"must have required property '"+missing2+"'"};
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
const err7 = {instancePath,schemaPath:"#/oneOf/2/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key2},message:"must NOT have additional properties"};
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
if(!(validate157(data.decimal, {instancePath:instancePath+"/decimal",parentData:data,parentDataProperty:"decimal",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate157.errors : vErrors.concat(validate157.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err8 = {instancePath,schemaPath:"#/oneOf/2/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err9 = {instancePath,schemaPath:"#/oneOf/3/required",keyword:"required",params:{missingProperty: missing3},message:"must have required property '"+missing3+"'"};
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
const err10 = {instancePath,schemaPath:"#/oneOf/3/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key3},message:"must NOT have additional properties"};
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
if(!(validate157(data.float_bits, {instancePath:instancePath+"/float_bits",parentData:data,parentDataProperty:"float_bits",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate157.errors : vErrors.concat(validate157.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err11 = {instancePath,schemaPath:"#/oneOf/3/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err12 = {instancePath,schemaPath:"#/oneOf/4/required",keyword:"required",params:{missingProperty: missing4},message:"must have required property '"+missing4+"'"};
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
const err13 = {instancePath,schemaPath:"#/oneOf/4/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key4},message:"must NOT have additional properties"};
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
if(!(validate173(data.boolean, {instancePath:instancePath+"/boolean",parentData:data,parentDataProperty:"boolean",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate173.errors : vErrors.concat(validate173.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err14 = {instancePath,schemaPath:"#/oneOf/4/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err15 = {instancePath,schemaPath:"#/oneOf/5/required",keyword:"required",params:{missingProperty: missing5},message:"must have required property '"+missing5+"'"};
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
const err16 = {instancePath,schemaPath:"#/oneOf/5/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key5},message:"must NOT have additional properties"};
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
if(!(validate157(data.utf8, {instancePath:instancePath+"/utf8",parentData:data,parentDataProperty:"utf8",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate157.errors : vErrors.concat(validate157.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err17 = {instancePath,schemaPath:"#/oneOf/5/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err18 = {instancePath,schemaPath:"#/oneOf/6/required",keyword:"required",params:{missingProperty: missing6},message:"must have required property '"+missing6+"'"};
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
const err19 = {instancePath,schemaPath:"#/oneOf/6/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key6},message:"must NOT have additional properties"};
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
if(!(validate157(data.binary, {instancePath:instancePath+"/binary",parentData:data,parentDataProperty:"binary",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate157.errors : vErrors.concat(validate157.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err20 = {instancePath,schemaPath:"#/oneOf/6/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err21 = {instancePath,schemaPath:"#/oneOf/7/required",keyword:"required",params:{missingProperty: missing7},message:"must have required property '"+missing7+"'"};
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
const err22 = {instancePath,schemaPath:"#/oneOf/7/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key7},message:"must NOT have additional properties"};
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
if(!(validate157(data.date_days, {instancePath:instancePath+"/date_days",parentData:data,parentDataProperty:"date_days",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate157.errors : vErrors.concat(validate157.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err23 = {instancePath,schemaPath:"#/oneOf/7/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err24 = {instancePath,schemaPath:"#/oneOf/8/required",keyword:"required",params:{missingProperty: missing8},message:"must have required property '"+missing8+"'"};
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
const err25 = {instancePath,schemaPath:"#/oneOf/8/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key8},message:"must NOT have additional properties"};
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
if(!(validate157(data.time_nanos, {instancePath:instancePath+"/time_nanos",parentData:data,parentDataProperty:"time_nanos",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate157.errors : vErrors.concat(validate157.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err26 = {instancePath,schemaPath:"#/oneOf/8/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err27 = {instancePath,schemaPath:"#/oneOf/9/required",keyword:"required",params:{missingProperty: missing9},message:"must have required property '"+missing9+"'"};
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
const err28 = {instancePath,schemaPath:"#/oneOf/9/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key9},message:"must NOT have additional properties"};
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
if(!(validate157(data.timestamp_micros, {instancePath:instancePath+"/timestamp_micros",parentData:data,parentDataProperty:"timestamp_micros",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate157.errors : vErrors.concat(validate157.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err29 = {instancePath,schemaPath:"#/oneOf/9/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err30 = {instancePath,schemaPath:"#/oneOf/10/required",keyword:"required",params:{missingProperty: missing10},message:"must have required property '"+missing10+"'"};
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
const err31 = {instancePath,schemaPath:"#/oneOf/10/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key10},message:"must NOT have additional properties"};
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
if(!(validate452(data.interval, {instancePath:instancePath+"/interval",parentData:data,parentDataProperty:"interval",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate452.errors : vErrors.concat(validate452.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err32 = {instancePath,schemaPath:"#/oneOf/10/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err33 = {instancePath,schemaPath:"#/oneOf/11/required",keyword:"required",params:{missingProperty: missing11},message:"must have required property '"+missing11+"'"};
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
const err34 = {instancePath,schemaPath:"#/oneOf/11/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key11},message:"must NOT have additional properties"};
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
if(!(validate157(data.uuid, {instancePath:instancePath+"/uuid",parentData:data,parentDataProperty:"uuid",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate157.errors : vErrors.concat(validate157.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err35 = {instancePath,schemaPath:"#/oneOf/11/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err36 = {instancePath,schemaPath:"#/oneOf",keyword:"oneOf",params:{passingSchemas: passing0},message:"must match exactly one schema in oneOf"};
if(vErrors === null){
vErrors = [err36];
}
else {
vErrors.push(err36);
}
errors++;
validate441.errors = vErrors;
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
validate441.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate441.evaluated = {"dynamicProps":true,"dynamicItems":false};


function validate436(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate436.evaluated;
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
validate436.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "column") || (key0 === "op")) || (key0 === "value"))){
validate436.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.column !== undefined){
const _errs2 = errors;
if(!(validate161(data.column, {instancePath:instancePath+"/column",parentData:data,parentDataProperty:"column",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate161.errors : vErrors.concat(validate161.errors);
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
if(!(validate439(data.op, {instancePath:instancePath+"/op",parentData:data,parentDataProperty:"op",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate439.errors : vErrors.concat(validate439.errors);
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
if(!(validate441(data.value, {instancePath:instancePath+"/value",parentData:data,parentDataProperty:"value",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate441.errors : vErrors.concat(validate441.errors);
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
validate436.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate436.errors = vErrors;
return errors === 0;
}
validate436.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema138 = {"type":"object","additionalProperties":false,"properties":{"column":{"$ref":"#/$defs/Response/$defs/T8"},"op":{"$ref":"#/$defs/Response/$defs/T81"}},"required":["column","op"]};

function validate460(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate460.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if(((data.column === undefined) && (missing0 = "column")) || ((data.op === undefined) && (missing0 = "op"))){
validate460.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "column") || (key0 === "op"))){
validate460.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.column !== undefined){
const _errs2 = errors;
if(!(validate161(data.column, {instancePath:instancePath+"/column",parentData:data,parentDataProperty:"column",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate161.errors : vErrors.concat(validate161.errors);
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
if(!(validate439(data.op, {instancePath:instancePath+"/op",parentData:data,parentDataProperty:"op",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate439.errors : vErrors.concat(validate439.errors);
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
validate460.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate460.errors = vErrors;
return errors === 0;
}
validate460.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema139 = {"type":"array","maxItems":64,"items":{"$ref":"#/$defs/Response/$defs/T86"}};
const schema140 = {"oneOf":[{"type":"object","additionalProperties":false,"required":["atom"],"properties":{"atom":{"$ref":"#/$defs/Response/$defs/T87"}}},{"type":"object","additionalProperties":false,"required":["negate"],"properties":{"negate":{"$ref":"#/$defs/Response/$defs/T88"}}},{"type":"object","additionalProperties":false,"required":["conjunction"],"properties":{"conjunction":{"$ref":"#/$defs/Response/$defs/T88"}}},{"type":"object","additionalProperties":false,"required":["disjunction"],"properties":{"disjunction":{"$ref":"#/$defs/Response/$defs/T88"}}}]};
const schema141 = {"oneOf":[{"type":"object","additionalProperties":false,"required":["all"],"properties":{"all":{"$ref":"#/$defs/Response/$defs/T88"}}},{"type":"object","additionalProperties":false,"required":["state"],"properties":{"state":{"$ref":"#/$defs/Response/$defs/T89"}}},{"type":"object","additionalProperties":false,"required":["compare"],"properties":{"compare":{"$ref":"#/$defs/Response/$defs/T92"}}},{"type":"object","additionalProperties":false,"required":["null_compare"],"properties":{"null_compare":{"$ref":"#/$defs/Response/$defs/T98"}}}]};
const schema142 = {"type":"object","maxProperties":0};

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
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
if(Object.keys(data).length > 0){
validate467.errors = [{instancePath,schemaPath:"#/maxProperties",keyword:"maxProperties",params:{limit: 0},message:"must NOT have more than 0 properties"}];
return false;
}
}
else {
validate467.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate467.errors = vErrors;
return errors === 0;
}
validate467.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema143 = {"type":"object","additionalProperties":false,"properties":{"column":{"$ref":"#/$defs/Response/$defs/T90"},"value":{"$ref":"#/$defs/Response/$defs/T91"}},"required":["column","value"]};

function validate470(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate470.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(!(((typeof data == "number") && (!(data % 1) && !isNaN(data))) && (isFinite(data)))){
validate470.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "integer"},message:"must be integer"}];
return false;
}
if(errors === 0){
if((typeof data == "number") && (isFinite(data))){
if(data > 255 || isNaN(data)){
validate470.errors = [{instancePath,schemaPath:"#/maximum",keyword:"maximum",params:{comparison: "<=", limit: 255},message:"must be <= 255"}];
return false;
}
else {
if(data < 0 || isNaN(data)){
validate470.errors = [{instancePath,schemaPath:"#/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"}];
return false;
}
}
}
}
validate470.errors = vErrors;
return errors === 0;
}
validate470.evaluated = {"dynamicProps":false,"dynamicItems":false};


function validate472(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate472.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate472.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
if(!(((((data === "missing") || (data === "null")) || (data === "type_error")) || (data === "value")) || (data === "conflict"))){
validate472.errors = [{instancePath,schemaPath:"#/enum",keyword:"enum",params:{allowedValues: schema131.enum},message:"must be equal to one of the allowed values"}];
return false;
}
validate472.errors = vErrors;
return errors === 0;
}
validate472.evaluated = {"dynamicProps":false,"dynamicItems":false};


function validate469(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate469.evaluated;
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
validate469.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "column") || (key0 === "value"))){
validate469.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.column !== undefined){
const _errs2 = errors;
if(!(validate470(data.column, {instancePath:instancePath+"/column",parentData:data,parentDataProperty:"column",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate470.errors : vErrors.concat(validate470.errors);
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
if(!(validate472(data.value, {instancePath:instancePath+"/value",parentData:data,parentDataProperty:"value",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate472.errors : vErrors.concat(validate472.errors);
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
validate469.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate469.errors = vErrors;
return errors === 0;
}
validate469.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema146 = {"type":"object","additionalProperties":false,"properties":{"column":{"$ref":"#/$defs/Response/$defs/T90"},"op":{"$ref":"#/$defs/Response/$defs/T93"},"value":{"$ref":"#/$defs/Response/$defs/T94"}},"required":["column","op","value"]};

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
if(typeof data !== "string"){
validate477.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
if(!((((((data === "eq") || (data === "ne")) || (data === "lt")) || (data === "le")) || (data === "gt")) || (data === "ge"))){
validate477.errors = [{instancePath,schemaPath:"#/enum",keyword:"enum",params:{allowedValues: schema134.enum},message:"must be equal to one of the allowed values"}];
return false;
}
validate477.errors = vErrors;
return errors === 0;
}
validate477.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema148 = {"oneOf":[{"type":"object","additionalProperties":false,"required":["signed"],"properties":{"signed":{"$ref":"#/$defs/Response/$defs/T95"}}},{"type":"object","additionalProperties":false,"required":["unsigned"],"properties":{"unsigned":{"$ref":"#/$defs/Response/$defs/T95"}}},{"type":"object","additionalProperties":false,"required":["decimal"],"properties":{"decimal":{"$ref":"#/$defs/Response/$defs/T95"}}},{"type":"object","additionalProperties":false,"required":["float_bits"],"properties":{"float_bits":{"$ref":"#/$defs/Response/$defs/T95"}}},{"type":"object","additionalProperties":false,"required":["boolean"],"properties":{"boolean":{"$ref":"#/$defs/Response/$defs/T96"}}},{"type":"object","additionalProperties":false,"required":["utf8"],"properties":{"utf8":{"$ref":"#/$defs/Response/$defs/T95"}}},{"type":"object","additionalProperties":false,"required":["binary"],"properties":{"binary":{"$ref":"#/$defs/Response/$defs/T95"}}},{"type":"object","additionalProperties":false,"required":["date_days"],"properties":{"date_days":{"$ref":"#/$defs/Response/$defs/T95"}}},{"type":"object","additionalProperties":false,"required":["time_nanos"],"properties":{"time_nanos":{"$ref":"#/$defs/Response/$defs/T95"}}},{"type":"object","additionalProperties":false,"required":["timestamp_micros"],"properties":{"timestamp_micros":{"$ref":"#/$defs/Response/$defs/T95"}}},{"type":"object","additionalProperties":false,"required":["interval"],"properties":{"interval":{"$ref":"#/$defs/Response/$defs/T97"}}},{"type":"object","additionalProperties":false,"required":["uuid"],"properties":{"uuid":{"$ref":"#/$defs/Response/$defs/T95"}}}]};
const schema149 = {"type":"string","maxLength":131072};

function validate480(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate480.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(typeof data === "string"){
if(func1(data) > 131072){
validate480.errors = [{instancePath,schemaPath:"#/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"}];
return false;
}
}
else {
validate480.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
}
validate480.errors = vErrors;
return errors === 0;
}
validate480.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema150 = {"type":"boolean"};

function validate485(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate485.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "boolean"){
validate485.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"}];
return false;
}
validate485.errors = vErrors;
return errors === 0;
}
validate485.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema151 = {"type":"object","additionalProperties":false,"properties":{"months":{"$ref":"#/$defs/Response/$defs/T95"},"days":{"$ref":"#/$defs/Response/$defs/T95"},"nanos":{"$ref":"#/$defs/Response/$defs/T95"}},"required":["months","days","nanos"]};

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
if((((data.months === undefined) && (missing0 = "months")) || ((data.days === undefined) && (missing0 = "days"))) || ((data.nanos === undefined) && (missing0 = "nanos"))){
validate492.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "months") || (key0 === "days")) || (key0 === "nanos"))){
validate492.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.months !== undefined){
const _errs2 = errors;
if(!(validate480(data.months, {instancePath:instancePath+"/months",parentData:data,parentDataProperty:"months",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate480.errors : vErrors.concat(validate480.errors);
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
if(!(validate480(data.days, {instancePath:instancePath+"/days",parentData:data,parentDataProperty:"days",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate480.errors : vErrors.concat(validate480.errors);
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
if(!(validate480(data.nanos, {instancePath:instancePath+"/nanos",parentData:data,parentDataProperty:"nanos",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate480.errors : vErrors.concat(validate480.errors);
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
validate492.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate492.errors = vErrors;
return errors === 0;
}
validate492.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate479(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate479.evaluated;
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
if(!(key0 === "signed")){
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
if(data.signed !== undefined){
if(!(validate480(data.signed, {instancePath:instancePath+"/signed",parentData:data,parentDataProperty:"signed",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate480.errors : vErrors.concat(validate480.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err2 = {instancePath,schemaPath:"#/oneOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err3 = {instancePath,schemaPath:"#/oneOf/1/required",keyword:"required",params:{missingProperty: missing1},message:"must have required property '"+missing1+"'"};
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
const err4 = {instancePath,schemaPath:"#/oneOf/1/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key1},message:"must NOT have additional properties"};
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
if(!(validate480(data.unsigned, {instancePath:instancePath+"/unsigned",parentData:data,parentDataProperty:"unsigned",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate480.errors : vErrors.concat(validate480.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err5 = {instancePath,schemaPath:"#/oneOf/1/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err6 = {instancePath,schemaPath:"#/oneOf/2/required",keyword:"required",params:{missingProperty: missing2},message:"must have required property '"+missing2+"'"};
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
const err7 = {instancePath,schemaPath:"#/oneOf/2/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key2},message:"must NOT have additional properties"};
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
if(!(validate480(data.decimal, {instancePath:instancePath+"/decimal",parentData:data,parentDataProperty:"decimal",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate480.errors : vErrors.concat(validate480.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err8 = {instancePath,schemaPath:"#/oneOf/2/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err9 = {instancePath,schemaPath:"#/oneOf/3/required",keyword:"required",params:{missingProperty: missing3},message:"must have required property '"+missing3+"'"};
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
const err10 = {instancePath,schemaPath:"#/oneOf/3/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key3},message:"must NOT have additional properties"};
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
if(!(validate480(data.float_bits, {instancePath:instancePath+"/float_bits",parentData:data,parentDataProperty:"float_bits",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate480.errors : vErrors.concat(validate480.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err11 = {instancePath,schemaPath:"#/oneOf/3/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err12 = {instancePath,schemaPath:"#/oneOf/4/required",keyword:"required",params:{missingProperty: missing4},message:"must have required property '"+missing4+"'"};
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
const err13 = {instancePath,schemaPath:"#/oneOf/4/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key4},message:"must NOT have additional properties"};
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
if(!(validate485(data.boolean, {instancePath:instancePath+"/boolean",parentData:data,parentDataProperty:"boolean",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate485.errors : vErrors.concat(validate485.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err14 = {instancePath,schemaPath:"#/oneOf/4/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err15 = {instancePath,schemaPath:"#/oneOf/5/required",keyword:"required",params:{missingProperty: missing5},message:"must have required property '"+missing5+"'"};
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
const err16 = {instancePath,schemaPath:"#/oneOf/5/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key5},message:"must NOT have additional properties"};
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
if(!(validate480(data.utf8, {instancePath:instancePath+"/utf8",parentData:data,parentDataProperty:"utf8",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate480.errors : vErrors.concat(validate480.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err17 = {instancePath,schemaPath:"#/oneOf/5/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err18 = {instancePath,schemaPath:"#/oneOf/6/required",keyword:"required",params:{missingProperty: missing6},message:"must have required property '"+missing6+"'"};
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
const err19 = {instancePath,schemaPath:"#/oneOf/6/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key6},message:"must NOT have additional properties"};
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
if(!(validate480(data.binary, {instancePath:instancePath+"/binary",parentData:data,parentDataProperty:"binary",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate480.errors : vErrors.concat(validate480.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err20 = {instancePath,schemaPath:"#/oneOf/6/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err21 = {instancePath,schemaPath:"#/oneOf/7/required",keyword:"required",params:{missingProperty: missing7},message:"must have required property '"+missing7+"'"};
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
const err22 = {instancePath,schemaPath:"#/oneOf/7/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key7},message:"must NOT have additional properties"};
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
if(!(validate480(data.date_days, {instancePath:instancePath+"/date_days",parentData:data,parentDataProperty:"date_days",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate480.errors : vErrors.concat(validate480.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err23 = {instancePath,schemaPath:"#/oneOf/7/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err24 = {instancePath,schemaPath:"#/oneOf/8/required",keyword:"required",params:{missingProperty: missing8},message:"must have required property '"+missing8+"'"};
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
const err25 = {instancePath,schemaPath:"#/oneOf/8/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key8},message:"must NOT have additional properties"};
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
if(!(validate480(data.time_nanos, {instancePath:instancePath+"/time_nanos",parentData:data,parentDataProperty:"time_nanos",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate480.errors : vErrors.concat(validate480.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err26 = {instancePath,schemaPath:"#/oneOf/8/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err27 = {instancePath,schemaPath:"#/oneOf/9/required",keyword:"required",params:{missingProperty: missing9},message:"must have required property '"+missing9+"'"};
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
const err28 = {instancePath,schemaPath:"#/oneOf/9/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key9},message:"must NOT have additional properties"};
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
if(!(validate480(data.timestamp_micros, {instancePath:instancePath+"/timestamp_micros",parentData:data,parentDataProperty:"timestamp_micros",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate480.errors : vErrors.concat(validate480.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err29 = {instancePath,schemaPath:"#/oneOf/9/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err30 = {instancePath,schemaPath:"#/oneOf/10/required",keyword:"required",params:{missingProperty: missing10},message:"must have required property '"+missing10+"'"};
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
const err31 = {instancePath,schemaPath:"#/oneOf/10/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key10},message:"must NOT have additional properties"};
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
if(!(validate492(data.interval, {instancePath:instancePath+"/interval",parentData:data,parentDataProperty:"interval",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate492.errors : vErrors.concat(validate492.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err32 = {instancePath,schemaPath:"#/oneOf/10/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err33 = {instancePath,schemaPath:"#/oneOf/11/required",keyword:"required",params:{missingProperty: missing11},message:"must have required property '"+missing11+"'"};
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
const err34 = {instancePath,schemaPath:"#/oneOf/11/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key11},message:"must NOT have additional properties"};
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
if(!(validate480(data.uuid, {instancePath:instancePath+"/uuid",parentData:data,parentDataProperty:"uuid",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate480.errors : vErrors.concat(validate480.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err35 = {instancePath,schemaPath:"#/oneOf/11/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err36 = {instancePath,schemaPath:"#/oneOf",keyword:"oneOf",params:{passingSchemas: passing0},message:"must match exactly one schema in oneOf"};
if(vErrors === null){
vErrors = [err36];
}
else {
vErrors.push(err36);
}
errors++;
validate479.errors = vErrors;
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
validate479.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate479.evaluated = {"dynamicProps":true,"dynamicItems":false};


function validate475(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate475.evaluated;
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
validate475.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "column") || (key0 === "op")) || (key0 === "value"))){
validate475.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.column !== undefined){
const _errs2 = errors;
if(!(validate470(data.column, {instancePath:instancePath+"/column",parentData:data,parentDataProperty:"column",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate470.errors : vErrors.concat(validate470.errors);
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
if(!(validate477(data.op, {instancePath:instancePath+"/op",parentData:data,parentDataProperty:"op",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate477.errors : vErrors.concat(validate477.errors);
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
if(!(validate479(data.value, {instancePath:instancePath+"/value",parentData:data,parentDataProperty:"value",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate479.errors : vErrors.concat(validate479.errors);
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
validate475.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate475.errors = vErrors;
return errors === 0;
}
validate475.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema152 = {"type":"object","additionalProperties":false,"properties":{"column":{"$ref":"#/$defs/Response/$defs/T90"},"op":{"$ref":"#/$defs/Response/$defs/T93"}},"required":["column","op"]};

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
if(((data.column === undefined) && (missing0 = "column")) || ((data.op === undefined) && (missing0 = "op"))){
validate500.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "column") || (key0 === "op"))){
validate500.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.column !== undefined){
const _errs2 = errors;
if(!(validate470(data.column, {instancePath:instancePath+"/column",parentData:data,parentDataProperty:"column",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate470.errors : vErrors.concat(validate470.errors);
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
if(!(validate477(data.op, {instancePath:instancePath+"/op",parentData:data,parentDataProperty:"op",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate477.errors : vErrors.concat(validate477.errors);
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
validate500.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate500.errors = vErrors;
return errors === 0;
}
validate500.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate466(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate466.evaluated;
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
if((data.all === undefined) && (missing0 = "all")){
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
if(!(key0 === "all")){
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
if(data.all !== undefined){
if(!(validate467(data.all, {instancePath:instancePath+"/all",parentData:data,parentDataProperty:"all",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate467.errors : vErrors.concat(validate467.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err2 = {instancePath,schemaPath:"#/oneOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
if((data.state === undefined) && (missing1 = "state")){
const err3 = {instancePath,schemaPath:"#/oneOf/1/required",keyword:"required",params:{missingProperty: missing1},message:"must have required property '"+missing1+"'"};
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
if(!(key1 === "state")){
const err4 = {instancePath,schemaPath:"#/oneOf/1/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key1},message:"must NOT have additional properties"};
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
if(data.state !== undefined){
if(!(validate469(data.state, {instancePath:instancePath+"/state",parentData:data,parentDataProperty:"state",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate469.errors : vErrors.concat(validate469.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err5 = {instancePath,schemaPath:"#/oneOf/1/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
if((data.compare === undefined) && (missing2 = "compare")){
const err6 = {instancePath,schemaPath:"#/oneOf/2/required",keyword:"required",params:{missingProperty: missing2},message:"must have required property '"+missing2+"'"};
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
if(!(key2 === "compare")){
const err7 = {instancePath,schemaPath:"#/oneOf/2/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key2},message:"must NOT have additional properties"};
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
if(data.compare !== undefined){
if(!(validate475(data.compare, {instancePath:instancePath+"/compare",parentData:data,parentDataProperty:"compare",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate475.errors : vErrors.concat(validate475.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err8 = {instancePath,schemaPath:"#/oneOf/2/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
if((data.null_compare === undefined) && (missing3 = "null_compare")){
const err9 = {instancePath,schemaPath:"#/oneOf/3/required",keyword:"required",params:{missingProperty: missing3},message:"must have required property '"+missing3+"'"};
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
if(!(key3 === "null_compare")){
const err10 = {instancePath,schemaPath:"#/oneOf/3/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key3},message:"must NOT have additional properties"};
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
if(data.null_compare !== undefined){
if(!(validate500(data.null_compare, {instancePath:instancePath+"/null_compare",parentData:data,parentDataProperty:"null_compare",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate500.errors : vErrors.concat(validate500.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err11 = {instancePath,schemaPath:"#/oneOf/3/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err12 = {instancePath,schemaPath:"#/oneOf",keyword:"oneOf",params:{passingSchemas: passing0},message:"must match exactly one schema in oneOf"};
if(vErrors === null){
vErrors = [err12];
}
else {
vErrors.push(err12);
}
errors++;
validate466.errors = vErrors;
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
validate466.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate466.evaluated = {"dynamicProps":true,"dynamicItems":false};


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
const _errs0 = errors;
let valid0 = false;
let passing0 = null;
const _errs1 = errors;
if(errors === _errs1){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((data.atom === undefined) && (missing0 = "atom")){
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
if(!(key0 === "atom")){
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
if(data.atom !== undefined){
if(!(validate466(data.atom, {instancePath:instancePath+"/atom",parentData:data,parentDataProperty:"atom",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate466.errors : vErrors.concat(validate466.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err2 = {instancePath,schemaPath:"#/oneOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
if((data.negate === undefined) && (missing1 = "negate")){
const err3 = {instancePath,schemaPath:"#/oneOf/1/required",keyword:"required",params:{missingProperty: missing1},message:"must have required property '"+missing1+"'"};
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
if(!(key1 === "negate")){
const err4 = {instancePath,schemaPath:"#/oneOf/1/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key1},message:"must NOT have additional properties"};
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
if(data.negate !== undefined){
if(!(validate467(data.negate, {instancePath:instancePath+"/negate",parentData:data,parentDataProperty:"negate",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate467.errors : vErrors.concat(validate467.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err5 = {instancePath,schemaPath:"#/oneOf/1/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
if((data.conjunction === undefined) && (missing2 = "conjunction")){
const err6 = {instancePath,schemaPath:"#/oneOf/2/required",keyword:"required",params:{missingProperty: missing2},message:"must have required property '"+missing2+"'"};
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
if(!(key2 === "conjunction")){
const err7 = {instancePath,schemaPath:"#/oneOf/2/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key2},message:"must NOT have additional properties"};
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
if(data.conjunction !== undefined){
if(!(validate467(data.conjunction, {instancePath:instancePath+"/conjunction",parentData:data,parentDataProperty:"conjunction",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate467.errors : vErrors.concat(validate467.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err8 = {instancePath,schemaPath:"#/oneOf/2/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
if((data.disjunction === undefined) && (missing3 = "disjunction")){
const err9 = {instancePath,schemaPath:"#/oneOf/3/required",keyword:"required",params:{missingProperty: missing3},message:"must have required property '"+missing3+"'"};
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
if(!(key3 === "disjunction")){
const err10 = {instancePath,schemaPath:"#/oneOf/3/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key3},message:"must NOT have additional properties"};
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
if(data.disjunction !== undefined){
if(!(validate467(data.disjunction, {instancePath:instancePath+"/disjunction",parentData:data,parentDataProperty:"disjunction",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate467.errors : vErrors.concat(validate467.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err11 = {instancePath,schemaPath:"#/oneOf/3/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
}
}
}
if(!valid0){
const err12 = {instancePath,schemaPath:"#/oneOf",keyword:"oneOf",params:{passingSchemas: passing0},message:"must match exactly one schema in oneOf"};
if(vErrors === null){
vErrors = [err12];
}
else {
vErrors.push(err12);
}
errors++;
validate465.errors = vErrors;
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
validate465.errors = vErrors;
evaluated0.props = props1;
return errors === 0;
}
validate465.evaluated = {"dynamicProps":true,"dynamicItems":false};


function validate464(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate464.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(Array.isArray(data)){
if(data.length > 64){
validate464.errors = [{instancePath,schemaPath:"#/maxItems",keyword:"maxItems",params:{limit: 64},message:"must NOT have more than 64 items"}];
return false;
}
else {
var valid0 = true;
const len0 = data.length;
for(let i0=0; i0<len0; i0++){
const _errs1 = errors;
if(!(validate465(data[i0], {instancePath:instancePath+"/" + i0,parentData:data,parentDataProperty:i0,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate465.errors : vErrors.concat(validate465.errors);
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
validate464.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "array"},message:"must be array"}];
return false;
}
}
validate464.errors = vErrors;
return errors === 0;
}
validate464.evaluated = {"items":true,"dynamicProps":false,"dynamicItems":false};


function validate428(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate428.evaluated;
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
if((data.all === undefined) && (missing0 = "all")){
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
if(!(key0 === "all")){
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
if(data.all !== undefined){
if(!(validate211(data.all, {instancePath:instancePath+"/all",parentData:data,parentDataProperty:"all",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate211.errors : vErrors.concat(validate211.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err2 = {instancePath,schemaPath:"#/oneOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
if((data.state === undefined) && (missing1 = "state")){
const err3 = {instancePath,schemaPath:"#/oneOf/1/required",keyword:"required",params:{missingProperty: missing1},message:"must have required property '"+missing1+"'"};
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
if(!(key1 === "state")){
const err4 = {instancePath,schemaPath:"#/oneOf/1/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key1},message:"must NOT have additional properties"};
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
if(data.state !== undefined){
if(!(validate430(data.state, {instancePath:instancePath+"/state",parentData:data,parentDataProperty:"state",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate430.errors : vErrors.concat(validate430.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err5 = {instancePath,schemaPath:"#/oneOf/1/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
if((data.compare === undefined) && (missing2 = "compare")){
const err6 = {instancePath,schemaPath:"#/oneOf/2/required",keyword:"required",params:{missingProperty: missing2},message:"must have required property '"+missing2+"'"};
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
if(!(key2 === "compare")){
const err7 = {instancePath,schemaPath:"#/oneOf/2/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key2},message:"must NOT have additional properties"};
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
if(data.compare !== undefined){
if(!(validate436(data.compare, {instancePath:instancePath+"/compare",parentData:data,parentDataProperty:"compare",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate436.errors : vErrors.concat(validate436.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err8 = {instancePath,schemaPath:"#/oneOf/2/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
if((data.null_compare === undefined) && (missing3 = "null_compare")){
const err9 = {instancePath,schemaPath:"#/oneOf/3/required",keyword:"required",params:{missingProperty: missing3},message:"must have required property '"+missing3+"'"};
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
if(!(key3 === "null_compare")){
const err10 = {instancePath,schemaPath:"#/oneOf/3/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key3},message:"must NOT have additional properties"};
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
if(data.null_compare !== undefined){
if(!(validate460(data.null_compare, {instancePath:instancePath+"/null_compare",parentData:data,parentDataProperty:"null_compare",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate460.errors : vErrors.concat(validate460.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err11 = {instancePath,schemaPath:"#/oneOf/3/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
if((data.program === undefined) && (missing4 = "program")){
const err12 = {instancePath,schemaPath:"#/oneOf/4/required",keyword:"required",params:{missingProperty: missing4},message:"must have required property '"+missing4+"'"};
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
if(!(key4 === "program")){
const err13 = {instancePath,schemaPath:"#/oneOf/4/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key4},message:"must NOT have additional properties"};
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
if(data.program !== undefined){
if(!(validate464(data.program, {instancePath:instancePath+"/program",parentData:data,parentDataProperty:"program",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate464.errors : vErrors.concat(validate464.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err14 = {instancePath,schemaPath:"#/oneOf/4/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err15 = {instancePath,schemaPath:"#/oneOf",keyword:"oneOf",params:{passingSchemas: passing0},message:"must match exactly one schema in oneOf"};
if(vErrors === null){
vErrors = [err15];
}
else {
vErrors.push(err15);
}
errors++;
validate428.errors = vErrors;
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
validate428.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate428.evaluated = {"dynamicProps":true,"dynamicItems":false};


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
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if(((((((data.version === undefined) && (missing0 = "version")) || ((data.projection === undefined) && (missing0 = "projection"))) || ((data.output_names === undefined) && (missing0 = "output_names"))) || ((data.limit === undefined) && (missing0 = "limit"))) || ((data.aggregate === undefined) && (missing0 = "aggregate"))) || ((data.predicate === undefined) && (missing0 = "predicate"))){
validate415.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((((((key0 === "version") || (key0 === "projection")) || (key0 === "output_names")) || (key0 === "limit")) || (key0 === "aggregate")) || (key0 === "predicate"))){
validate415.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.version !== undefined){
const _errs2 = errors;
if(!(validate161(data.version, {instancePath:instancePath+"/version",parentData:data,parentDataProperty:"version",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate161.errors : vErrors.concat(validate161.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.projection !== undefined){
const _errs3 = errors;
if(!(validate417(data.projection, {instancePath:instancePath+"/projection",parentData:data,parentDataProperty:"projection",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate417.errors : vErrors.concat(validate417.errors);
errors = vErrors.length;
}
var valid0 = _errs3 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.output_names !== undefined){
const _errs4 = errors;
if(!(validate420(data.output_names, {instancePath:instancePath+"/output_names",parentData:data,parentDataProperty:"output_names",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate420.errors : vErrors.concat(validate420.errors);
errors = vErrors.length;
}
var valid0 = _errs4 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.limit !== undefined){
const _errs5 = errors;
if(!(validate344(data.limit, {instancePath:instancePath+"/limit",parentData:data,parentDataProperty:"limit",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate344.errors : vErrors.concat(validate344.errors);
errors = vErrors.length;
}
var valid0 = _errs5 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.aggregate !== undefined){
const _errs6 = errors;
if(!(validate426(data.aggregate, {instancePath:instancePath+"/aggregate",parentData:data,parentDataProperty:"aggregate",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate426.errors : vErrors.concat(validate426.errors);
errors = vErrors.length;
}
var valid0 = _errs6 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.predicate !== undefined){
const _errs7 = errors;
if(!(validate428(data.predicate, {instancePath:instancePath+"/predicate",parentData:data,parentDataProperty:"predicate",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate428.errors : vErrors.concat(validate428.errors);
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
validate415.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate415.errors = vErrors;
return errors === 0;
}
validate415.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate412(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate412.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if(((((((data.bundle === undefined) && (missing0 = "bundle")) || ((data.source === undefined) && (missing0 = "source"))) || ((data.plan === undefined) && (missing0 = "plan"))) || ((data.limits === undefined) && (missing0 = "limits"))) || ((data.contract === undefined) && (missing0 = "contract"))) || ((data.schema === undefined) && (missing0 = "schema"))){
validate412.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((((((key0 === "bundle") || (key0 === "source")) || (key0 === "plan")) || (key0 === "limits")) || (key0 === "contract")) || (key0 === "schema"))){
validate412.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.bundle !== undefined){
const _errs2 = errors;
if(!(validate157(data.bundle, {instancePath:instancePath+"/bundle",parentData:data,parentDataProperty:"bundle",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate157.errors : vErrors.concat(validate157.errors);
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
if(!(validate178(data.source, {instancePath:instancePath+"/source",parentData:data,parentDataProperty:"source",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate178.errors : vErrors.concat(validate178.errors);
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
if(!(validate415(data.plan, {instancePath:instancePath+"/plan",parentData:data,parentDataProperty:"plan",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate415.errors : vErrors.concat(validate415.errors);
errors = vErrors.length;
}
var valid0 = _errs4 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.limits !== undefined){
const _errs5 = errors;
if(!(validate339(data.limits, {instancePath:instancePath+"/limits",parentData:data,parentDataProperty:"limits",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate339.errors : vErrors.concat(validate339.errors);
errors = vErrors.length;
}
var valid0 = _errs5 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.contract !== undefined){
const _errs6 = errors;
if(!(validate204(data.contract, {instancePath:instancePath+"/contract",parentData:data,parentDataProperty:"contract",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate204.errors : vErrors.concat(validate204.errors);
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
if(!(validate204(data.schema, {instancePath:instancePath+"/schema",parentData:data,parentDataProperty:"schema",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate204.errors : vErrors.concat(validate204.errors);
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
validate412.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate412.errors = vErrors;
return errors === 0;
}
validate412.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema153 = {"type":"object","additionalProperties":false,"properties":{"version":{"$ref":"#/$defs/Response/$defs/T8"},"scope":{"$ref":"#/$defs/Response/$defs/T100"},"name":{"$ref":"#/$defs/Response/$defs/T5"},"resource":{"$ref":"#/$defs/Response/$defs/T3"},"source_kind":{"$ref":"#/$defs/Response/$defs/T101"},"contract":{"$ref":"#/$defs/Response/$defs/T20"},"schema":{"$ref":"#/$defs/Response/$defs/T20"},"resource_revision":{"$ref":"#/$defs/Response/$defs/T3"},"policy_revision":{"$ref":"#/$defs/Response/$defs/T5"},"details":{"$ref":"#/$defs/Response/$defs/T102"}},"required":["version","scope","name","resource","source_kind","contract","schema","resource_revision","policy_revision","details"]};
const schema154 = {"type":"string","enum":["configured_source"]};

function validate518(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate518.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate518.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
if(!(data === "configured_source")){
validate518.errors = [{instancePath,schemaPath:"#/enum",keyword:"enum",params:{allowedValues: schema154.enum},message:"must be equal to one of the allowed values"}];
return false;
}
validate518.errors = vErrors;
return errors === 0;
}
validate518.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema155 = {"type":"string","enum":["kv","table","document"]};

function validate522(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate522.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate522.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
if(!(((data === "kv") || (data === "table")) || (data === "document"))){
validate522.errors = [{instancePath,schemaPath:"#/enum",keyword:"enum",params:{allowedValues: schema155.enum},message:"must be equal to one of the allowed values"}];
return false;
}
validate522.errors = vErrors;
return errors === 0;
}
validate522.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema156 = {"oneOf":[{"type":"object","additionalProperties":false,"required":["description"],"properties":{"description":{"$ref":"#/$defs/Response/$defs/T103"}}},{"type":"object","additionalProperties":false,"required":["tables"],"properties":{"tables":{"$ref":"#/$defs/Response/$defs/T104"}}},{"type":"object","additionalProperties":false,"required":["explanation"],"properties":{"explanation":{"$ref":"#/$defs/Response/$defs/T105"}}}]};
const schema157 = {"type":"object","additionalProperties":false,"properties":{"columns":{"$ref":"#/$defs/Response/$defs/T58"}},"required":["columns"]};

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
if((data.columns === undefined) && (missing0 = "columns")){
validate529.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(key0 === "columns")){
validate529.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.columns !== undefined){
if(!(validate362(data.columns, {instancePath:instancePath+"/columns",parentData:data,parentDataProperty:"columns",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate362.errors : vErrors.concat(validate362.errors);
errors = vErrors.length;
}
}
}
}
}
else {
validate529.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate529.errors = vErrors;
return errors === 0;
}
validate529.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema158 = {"type":"array","maxItems":128,"items":{"$ref":"#/$defs/Response/$defs/T5"}};

function validate532(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate532.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(Array.isArray(data)){
if(data.length > 128){
validate532.errors = [{instancePath,schemaPath:"#/maxItems",keyword:"maxItems",params:{limit: 128},message:"must NOT have more than 128 items"}];
return false;
}
else {
var valid0 = true;
const len0 = data.length;
for(let i0=0; i0<len0; i0++){
const _errs1 = errors;
if(!(validate157(data[i0], {instancePath:instancePath+"/" + i0,parentData:data,parentDataProperty:i0,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate157.errors : vErrors.concat(validate157.errors);
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
validate532.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "array"},message:"must be array"}];
return false;
}
}
validate532.errors = vErrors;
return errors === 0;
}
validate532.evaluated = {"items":true,"dynamicProps":false,"dynamicItems":false};

const schema159 = {"type":"object","additionalProperties":false,"properties":{"operators":{"$ref":"#/$defs/Response/$defs/T106"},"predicate":{"$ref":"#/$defs/Response/$defs/T108"},"projection":{"$ref":"#/$defs/Response/$defs/T104"},"limit":{"$ref":"#/$defs/Response/$defs/T56"},"aggregate":{"$ref":"#/$defs/Response/$defs/T76"},"columns":{"$ref":"#/$defs/Response/$defs/T58"},"budgets":{"$ref":"#/$defs/Response/$defs/T55"}},"required":["operators","predicate","projection","limit","aggregate","columns","budgets"]};
const schema160 = {"type":"array","maxItems":128,"items":{"$ref":"#/$defs/Response/$defs/T107"}};
const schema161 = {"type":"string","enum":["scan","filter","limit","project","count","sum","count_values"]};

function validate537(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate537.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate537.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
if(!(((((((data === "scan") || (data === "filter")) || (data === "limit")) || (data === "project")) || (data === "count")) || (data === "sum")) || (data === "count_values"))){
validate537.errors = [{instancePath,schemaPath:"#/enum",keyword:"enum",params:{allowedValues: schema161.enum},message:"must be equal to one of the allowed values"}];
return false;
}
validate537.errors = vErrors;
return errors === 0;
}
validate537.evaluated = {"dynamicProps":false,"dynamicItems":false};


function validate536(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate536.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(Array.isArray(data)){
if(data.length > 128){
validate536.errors = [{instancePath,schemaPath:"#/maxItems",keyword:"maxItems",params:{limit: 128},message:"must NOT have more than 128 items"}];
return false;
}
else {
var valid0 = true;
const len0 = data.length;
for(let i0=0; i0<len0; i0++){
const _errs1 = errors;
if(!(validate537(data[i0], {instancePath:instancePath+"/" + i0,parentData:data,parentDataProperty:i0,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate537.errors : vErrors.concat(validate537.errors);
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
validate536.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "array"},message:"must be array"}];
return false;
}
}
validate536.errors = vErrors;
return errors === 0;
}
validate536.evaluated = {"items":true,"dynamicProps":false,"dynamicItems":false};

const schema162 = {"oneOf":[{"type":"object","additionalProperties":false,"required":["all"],"properties":{"all":{"$ref":"#/$defs/Response/$defs/T22"}}},{"type":"object","additionalProperties":false,"required":["state"],"properties":{"state":{"$ref":"#/$defs/Response/$defs/T109"}}},{"type":"object","additionalProperties":false,"required":["compare"],"properties":{"compare":{"$ref":"#/$defs/Response/$defs/T110"}}},{"type":"object","additionalProperties":false,"required":["null_compare"],"properties":{"null_compare":{"$ref":"#/$defs/Response/$defs/T111"}}},{"type":"object","additionalProperties":false,"required":["program"],"properties":{"program":{"$ref":"#/$defs/Response/$defs/T112"}}}]};
const schema163 = {"type":"object","additionalProperties":false,"properties":{"column":{"$ref":"#/$defs/Response/$defs/T5"},"value":{"$ref":"#/$defs/Response/$defs/T79"}},"required":["column","value"]};

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
if(((data.column === undefined) && (missing0 = "column")) || ((data.value === undefined) && (missing0 = "value"))){
validate542.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "column") || (key0 === "value"))){
validate542.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.column !== undefined){
const _errs2 = errors;
if(!(validate157(data.column, {instancePath:instancePath+"/column",parentData:data,parentDataProperty:"column",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate157.errors : vErrors.concat(validate157.errors);
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
if(!(validate433(data.value, {instancePath:instancePath+"/value",parentData:data,parentDataProperty:"value",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate433.errors : vErrors.concat(validate433.errors);
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
validate542.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate542.errors = vErrors;
return errors === 0;
}
validate542.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema164 = {"type":"object","additionalProperties":false,"properties":{"column":{"$ref":"#/$defs/Response/$defs/T5"},"op":{"$ref":"#/$defs/Response/$defs/T81"},"type":{"$ref":"#/$defs/Response/$defs/T21"}},"required":["column","op","type"]};

function validate546(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate546.evaluated;
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
validate546.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "column") || (key0 === "op")) || (key0 === "type"))){
validate546.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.column !== undefined){
const _errs2 = errors;
if(!(validate157(data.column, {instancePath:instancePath+"/column",parentData:data,parentDataProperty:"column",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate157.errors : vErrors.concat(validate157.errors);
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
if(!(validate439(data.op, {instancePath:instancePath+"/op",parentData:data,parentDataProperty:"op",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate439.errors : vErrors.concat(validate439.errors);
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
if(!(validate210(data.type, {instancePath:instancePath+"/type",parentData:data,parentDataProperty:"type",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate210.errors : vErrors.concat(validate210.errors);
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
validate546.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate546.errors = vErrors;
return errors === 0;
}
validate546.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema165 = {"type":"object","additionalProperties":false,"properties":{"column":{"$ref":"#/$defs/Response/$defs/T5"},"op":{"$ref":"#/$defs/Response/$defs/T81"},"type":{"$ref":"#/$defs/Response/$defs/T21"}},"required":["column","op","type"]};

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
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((((data.column === undefined) && (missing0 = "column")) || ((data.op === undefined) && (missing0 = "op"))) || ((data.type === undefined) && (missing0 = "type"))){
validate551.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "column") || (key0 === "op")) || (key0 === "type"))){
validate551.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.column !== undefined){
const _errs2 = errors;
if(!(validate157(data.column, {instancePath:instancePath+"/column",parentData:data,parentDataProperty:"column",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate157.errors : vErrors.concat(validate157.errors);
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
if(!(validate439(data.op, {instancePath:instancePath+"/op",parentData:data,parentDataProperty:"op",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate439.errors : vErrors.concat(validate439.errors);
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
if(!(validate210(data.type, {instancePath:instancePath+"/type",parentData:data,parentDataProperty:"type",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate210.errors : vErrors.concat(validate210.errors);
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
validate551.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate551.errors = vErrors;
return errors === 0;
}
validate551.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema166 = {"type":"array","maxItems":64,"items":{"$ref":"#/$defs/Response/$defs/T113"}};
const schema167 = {"oneOf":[{"type":"object","additionalProperties":false,"required":["atom"],"properties":{"atom":{"$ref":"#/$defs/Response/$defs/T114"}}},{"type":"object","additionalProperties":false,"required":["negate"],"properties":{"negate":{"$ref":"#/$defs/Response/$defs/T88"}}},{"type":"object","additionalProperties":false,"required":["conjunction"],"properties":{"conjunction":{"$ref":"#/$defs/Response/$defs/T88"}}},{"type":"object","additionalProperties":false,"required":["disjunction"],"properties":{"disjunction":{"$ref":"#/$defs/Response/$defs/T88"}}}]};
const schema168 = {"oneOf":[{"type":"object","additionalProperties":false,"required":["all"],"properties":{"all":{"$ref":"#/$defs/Response/$defs/T88"}}},{"type":"object","additionalProperties":false,"required":["state"],"properties":{"state":{"$ref":"#/$defs/Response/$defs/T115"}}},{"type":"object","additionalProperties":false,"required":["compare"],"properties":{"compare":{"$ref":"#/$defs/Response/$defs/T116"}}},{"type":"object","additionalProperties":false,"required":["null_compare"],"properties":{"null_compare":{"$ref":"#/$defs/Response/$defs/T125"}}}]};
const schema169 = {"type":"object","additionalProperties":false,"properties":{"column":{"$ref":"#/$defs/Response/$defs/T95"},"value":{"$ref":"#/$defs/Response/$defs/T91"}},"required":["column","value"]};

function validate560(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate560.evaluated;
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
validate560.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "column") || (key0 === "value"))){
validate560.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.column !== undefined){
const _errs2 = errors;
if(!(validate480(data.column, {instancePath:instancePath+"/column",parentData:data,parentDataProperty:"column",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate480.errors : vErrors.concat(validate480.errors);
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
if(!(validate472(data.value, {instancePath:instancePath+"/value",parentData:data,parentDataProperty:"value",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate472.errors : vErrors.concat(validate472.errors);
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
validate560.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate560.errors = vErrors;
return errors === 0;
}
validate560.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema170 = {"type":"object","additionalProperties":false,"properties":{"column":{"$ref":"#/$defs/Response/$defs/T95"},"op":{"$ref":"#/$defs/Response/$defs/T93"},"type":{"$ref":"#/$defs/Response/$defs/T117"}},"required":["column","op","type"]};
const schema171 = {"oneOf":[{"type":"object","additionalProperties":false,"required":["int64"],"properties":{"int64":{"$ref":"#/$defs/Response/$defs/T88"}}},{"type":"object","additionalProperties":false,"required":["uint64"],"properties":{"uint64":{"$ref":"#/$defs/Response/$defs/T88"}}},{"type":"object","additionalProperties":false,"required":["float64"],"properties":{"float64":{"$ref":"#/$defs/Response/$defs/T88"}}},{"type":"object","additionalProperties":false,"required":["boolean"],"properties":{"boolean":{"$ref":"#/$defs/Response/$defs/T88"}}},{"type":"object","additionalProperties":false,"required":["utf8"],"properties":{"utf8":{"$ref":"#/$defs/Response/$defs/T88"}}},{"type":"object","additionalProperties":false,"required":["binary"],"properties":{"binary":{"$ref":"#/$defs/Response/$defs/T88"}}},{"type":"object","additionalProperties":false,"required":["int8"],"properties":{"int8":{"$ref":"#/$defs/Response/$defs/T88"}}},{"type":"object","additionalProperties":false,"required":["int16"],"properties":{"int16":{"$ref":"#/$defs/Response/$defs/T88"}}},{"type":"object","additionalProperties":false,"required":["int32"],"properties":{"int32":{"$ref":"#/$defs/Response/$defs/T88"}}},{"type":"object","additionalProperties":false,"required":["int128"],"properties":{"int128":{"$ref":"#/$defs/Response/$defs/T88"}}},{"type":"object","additionalProperties":false,"required":["uint8"],"properties":{"uint8":{"$ref":"#/$defs/Response/$defs/T88"}}},{"type":"object","additionalProperties":false,"required":["uint16"],"properties":{"uint16":{"$ref":"#/$defs/Response/$defs/T88"}}},{"type":"object","additionalProperties":false,"required":["uint32"],"properties":{"uint32":{"$ref":"#/$defs/Response/$defs/T88"}}},{"type":"object","additionalProperties":false,"required":["uint128"],"properties":{"uint128":{"$ref":"#/$defs/Response/$defs/T88"}}},{"type":"object","additionalProperties":false,"required":["float32"],"properties":{"float32":{"$ref":"#/$defs/Response/$defs/T88"}}},{"type":"object","additionalProperties":false,"required":["decimal"],"properties":{"decimal":{"$ref":"#/$defs/Response/$defs/T118"}}},{"type":"object","additionalProperties":false,"required":["date"],"properties":{"date":{"$ref":"#/$defs/Response/$defs/T88"}}},{"type":"object","additionalProperties":false,"required":["time"],"properties":{"time":{"$ref":"#/$defs/Response/$defs/T88"}}},{"type":"object","additionalProperties":false,"required":["timestamp"],"properties":{"timestamp":{"$ref":"#/$defs/Response/$defs/T119"}}},{"type":"object","additionalProperties":false,"required":["interval"],"properties":{"interval":{"$ref":"#/$defs/Response/$defs/T88"}}},{"type":"object","additionalProperties":false,"required":["uuid"],"properties":{"uuid":{"$ref":"#/$defs/Response/$defs/T88"}}},{"type":"object","additionalProperties":false,"required":["structure"],"properties":{"structure":{"$ref":"#/$defs/Response/$defs/T25"}}},{"type":"object","additionalProperties":false,"required":["list"],"properties":{"list":{"$ref":"#/$defs/Response/$defs/T120"}}},{"type":"object","additionalProperties":false,"required":["array"],"properties":{"array":{"$ref":"#/$defs/Response/$defs/T122"}}},{"type":"object","additionalProperties":false,"required":["map"],"properties":{"map":{"$ref":"#/$defs/Response/$defs/T124"}}},{"type":"object","additionalProperties":false,"required":["tagged_union"],"properties":{"tagged_union":{"$ref":"#/$defs/Response/$defs/T25"}}},{"type":"object","additionalProperties":false,"required":["json"],"properties":{"json":{"$ref":"#/$defs/Response/$defs/T88"}}}]};
const schema172 = {"type":"object","additionalProperties":false,"properties":{"precision":{"$ref":"#/$defs/Response/$defs/T90"},"scale":{"$ref":"#/$defs/Response/$defs/T90"}},"required":["precision","scale"]};

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
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if(((data.precision === undefined) && (missing0 = "precision")) || ((data.scale === undefined) && (missing0 = "scale"))){
validate583.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "precision") || (key0 === "scale"))){
validate583.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.precision !== undefined){
const _errs2 = errors;
if(!(validate470(data.precision, {instancePath:instancePath+"/precision",parentData:data,parentDataProperty:"precision",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate470.errors : vErrors.concat(validate470.errors);
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
if(!(validate470(data.scale, {instancePath:instancePath+"/scale",parentData:data,parentDataProperty:"scale",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate470.errors : vErrors.concat(validate470.errors);
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
validate583.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate583.errors = vErrors;
return errors === 0;
}
validate583.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate589(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate589.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate589.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
if(!((data === "civil") || (data === "utc"))){
validate589.errors = [{instancePath,schemaPath:"#/enum",keyword:"enum",params:{allowedValues: schema77.enum},message:"must be equal to one of the allowed values"}];
return false;
}
validate589.errors = vErrors;
return errors === 0;
}
validate589.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema174 = {"type":"object","additionalProperties":false,"properties":{"type":{"$ref":"#/$defs/Response/$defs/T121"},"nullable":{"$ref":"#/$defs/Response/$defs/T96"}},"required":["type","nullable"]};
const wrapper6 = {validate: validate567};

function validate594(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate594.evaluated;
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
validate594.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "type") || (key0 === "nullable"))){
validate594.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.type !== undefined){
const _errs2 = errors;
if(!(wrapper6.validate(data.type, {instancePath:instancePath+"/type",parentData:data,parentDataProperty:"type",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? wrapper6.validate.errors : vErrors.concat(wrapper6.validate.errors);
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
if(!(validate485(data.nullable, {instancePath:instancePath+"/nullable",parentData:data,parentDataProperty:"nullable",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate485.errors : vErrors.concat(validate485.errors);
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
validate594.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate594.errors = vErrors;
return errors === 0;
}
validate594.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema175 = {"type":"object","additionalProperties":false,"properties":{"element":{"$ref":"#/$defs/Response/$defs/T120"},"length":{"$ref":"#/$defs/Response/$defs/T123"}},"required":["element","length"]};

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
if(!(((typeof data == "number") && (!(data % 1) && !isNaN(data))) && (isFinite(data)))){
validate599.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "integer"},message:"must be integer"}];
return false;
}
if(errors === 0){
if((typeof data == "number") && (isFinite(data))){
if(data > 4294967295 || isNaN(data)){
validate599.errors = [{instancePath,schemaPath:"#/maximum",keyword:"maximum",params:{comparison: "<=", limit: 4294967295},message:"must be <= 4294967295"}];
return false;
}
else {
if(data < 0 || isNaN(data)){
validate599.errors = [{instancePath,schemaPath:"#/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"}];
return false;
}
}
}
}
validate599.errors = vErrors;
return errors === 0;
}
validate599.evaluated = {"dynamicProps":false,"dynamicItems":false};


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
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if(((data.element === undefined) && (missing0 = "element")) || ((data.length === undefined) && (missing0 = "length"))){
validate597.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "element") || (key0 === "length"))){
validate597.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.element !== undefined){
const _errs2 = errors;
if(!(validate594(data.element, {instancePath:instancePath+"/element",parentData:data,parentDataProperty:"element",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate594.errors : vErrors.concat(validate594.errors);
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
if(!(validate599(data.length, {instancePath:instancePath+"/length",parentData:data,parentDataProperty:"length",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate599.errors : vErrors.concat(validate599.errors);
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
validate597.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate597.errors = vErrors;
return errors === 0;
}
validate597.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema177 = {"type":"object","additionalProperties":false,"properties":{"key":{"$ref":"#/$defs/Response/$defs/T121"},"value":{"$ref":"#/$defs/Response/$defs/T120"}},"required":["key","value"]};

function validate602(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate602.evaluated;
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
validate602.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "key") || (key0 === "value"))){
validate602.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.key !== undefined){
const _errs2 = errors;
if(!(wrapper6.validate(data.key, {instancePath:instancePath+"/key",parentData:data,parentDataProperty:"key",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? wrapper6.validate.errors : vErrors.concat(wrapper6.validate.errors);
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
if(!(validate594(data.value, {instancePath:instancePath+"/value",parentData:data,parentDataProperty:"value",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate594.errors : vErrors.concat(validate594.errors);
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
validate602.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate602.errors = vErrors;
return errors === 0;
}
validate602.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate567(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate567.evaluated;
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
if(!(key0 === "int64")){
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
if(data.int64 !== undefined){
if(!(validate467(data.int64, {instancePath:instancePath+"/int64",parentData:data,parentDataProperty:"int64",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate467.errors : vErrors.concat(validate467.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err2 = {instancePath,schemaPath:"#/oneOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err3 = {instancePath,schemaPath:"#/oneOf/1/required",keyword:"required",params:{missingProperty: missing1},message:"must have required property '"+missing1+"'"};
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
const err4 = {instancePath,schemaPath:"#/oneOf/1/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key1},message:"must NOT have additional properties"};
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
if(!(validate467(data.uint64, {instancePath:instancePath+"/uint64",parentData:data,parentDataProperty:"uint64",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate467.errors : vErrors.concat(validate467.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err5 = {instancePath,schemaPath:"#/oneOf/1/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err6 = {instancePath,schemaPath:"#/oneOf/2/required",keyword:"required",params:{missingProperty: missing2},message:"must have required property '"+missing2+"'"};
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
const err7 = {instancePath,schemaPath:"#/oneOf/2/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key2},message:"must NOT have additional properties"};
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
if(!(validate467(data.float64, {instancePath:instancePath+"/float64",parentData:data,parentDataProperty:"float64",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate467.errors : vErrors.concat(validate467.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err8 = {instancePath,schemaPath:"#/oneOf/2/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err9 = {instancePath,schemaPath:"#/oneOf/3/required",keyword:"required",params:{missingProperty: missing3},message:"must have required property '"+missing3+"'"};
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
const err10 = {instancePath,schemaPath:"#/oneOf/3/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key3},message:"must NOT have additional properties"};
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
if(!(validate467(data.boolean, {instancePath:instancePath+"/boolean",parentData:data,parentDataProperty:"boolean",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate467.errors : vErrors.concat(validate467.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err11 = {instancePath,schemaPath:"#/oneOf/3/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err12 = {instancePath,schemaPath:"#/oneOf/4/required",keyword:"required",params:{missingProperty: missing4},message:"must have required property '"+missing4+"'"};
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
const err13 = {instancePath,schemaPath:"#/oneOf/4/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key4},message:"must NOT have additional properties"};
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
if(!(validate467(data.utf8, {instancePath:instancePath+"/utf8",parentData:data,parentDataProperty:"utf8",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate467.errors : vErrors.concat(validate467.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err14 = {instancePath,schemaPath:"#/oneOf/4/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err15 = {instancePath,schemaPath:"#/oneOf/5/required",keyword:"required",params:{missingProperty: missing5},message:"must have required property '"+missing5+"'"};
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
const err16 = {instancePath,schemaPath:"#/oneOf/5/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key5},message:"must NOT have additional properties"};
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
if(!(validate467(data.binary, {instancePath:instancePath+"/binary",parentData:data,parentDataProperty:"binary",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate467.errors : vErrors.concat(validate467.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err17 = {instancePath,schemaPath:"#/oneOf/5/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err18 = {instancePath,schemaPath:"#/oneOf/6/required",keyword:"required",params:{missingProperty: missing6},message:"must have required property '"+missing6+"'"};
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
const err19 = {instancePath,schemaPath:"#/oneOf/6/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key6},message:"must NOT have additional properties"};
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
if(!(validate467(data.int8, {instancePath:instancePath+"/int8",parentData:data,parentDataProperty:"int8",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate467.errors : vErrors.concat(validate467.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err20 = {instancePath,schemaPath:"#/oneOf/6/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err21 = {instancePath,schemaPath:"#/oneOf/7/required",keyword:"required",params:{missingProperty: missing7},message:"must have required property '"+missing7+"'"};
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
const err22 = {instancePath,schemaPath:"#/oneOf/7/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key7},message:"must NOT have additional properties"};
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
if(!(validate467(data.int16, {instancePath:instancePath+"/int16",parentData:data,parentDataProperty:"int16",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate467.errors : vErrors.concat(validate467.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err23 = {instancePath,schemaPath:"#/oneOf/7/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err24 = {instancePath,schemaPath:"#/oneOf/8/required",keyword:"required",params:{missingProperty: missing8},message:"must have required property '"+missing8+"'"};
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
const err25 = {instancePath,schemaPath:"#/oneOf/8/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key8},message:"must NOT have additional properties"};
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
if(!(validate467(data.int32, {instancePath:instancePath+"/int32",parentData:data,parentDataProperty:"int32",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate467.errors : vErrors.concat(validate467.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err26 = {instancePath,schemaPath:"#/oneOf/8/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err27 = {instancePath,schemaPath:"#/oneOf/9/required",keyword:"required",params:{missingProperty: missing9},message:"must have required property '"+missing9+"'"};
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
const err28 = {instancePath,schemaPath:"#/oneOf/9/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key9},message:"must NOT have additional properties"};
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
if(!(validate467(data.int128, {instancePath:instancePath+"/int128",parentData:data,parentDataProperty:"int128",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate467.errors : vErrors.concat(validate467.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err29 = {instancePath,schemaPath:"#/oneOf/9/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err30 = {instancePath,schemaPath:"#/oneOf/10/required",keyword:"required",params:{missingProperty: missing10},message:"must have required property '"+missing10+"'"};
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
const err31 = {instancePath,schemaPath:"#/oneOf/10/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key10},message:"must NOT have additional properties"};
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
if(!(validate467(data.uint8, {instancePath:instancePath+"/uint8",parentData:data,parentDataProperty:"uint8",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate467.errors : vErrors.concat(validate467.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err32 = {instancePath,schemaPath:"#/oneOf/10/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err33 = {instancePath,schemaPath:"#/oneOf/11/required",keyword:"required",params:{missingProperty: missing11},message:"must have required property '"+missing11+"'"};
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
const err34 = {instancePath,schemaPath:"#/oneOf/11/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key11},message:"must NOT have additional properties"};
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
if(!(validate467(data.uint16, {instancePath:instancePath+"/uint16",parentData:data,parentDataProperty:"uint16",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate467.errors : vErrors.concat(validate467.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err35 = {instancePath,schemaPath:"#/oneOf/11/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err36 = {instancePath,schemaPath:"#/oneOf/12/required",keyword:"required",params:{missingProperty: missing12},message:"must have required property '"+missing12+"'"};
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
const err37 = {instancePath,schemaPath:"#/oneOf/12/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key12},message:"must NOT have additional properties"};
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
if(!(validate467(data.uint32, {instancePath:instancePath+"/uint32",parentData:data,parentDataProperty:"uint32",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate467.errors : vErrors.concat(validate467.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err38 = {instancePath,schemaPath:"#/oneOf/12/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err39 = {instancePath,schemaPath:"#/oneOf/13/required",keyword:"required",params:{missingProperty: missing13},message:"must have required property '"+missing13+"'"};
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
const err40 = {instancePath,schemaPath:"#/oneOf/13/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key13},message:"must NOT have additional properties"};
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
if(!(validate467(data.uint128, {instancePath:instancePath+"/uint128",parentData:data,parentDataProperty:"uint128",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate467.errors : vErrors.concat(validate467.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err41 = {instancePath,schemaPath:"#/oneOf/13/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err42 = {instancePath,schemaPath:"#/oneOf/14/required",keyword:"required",params:{missingProperty: missing14},message:"must have required property '"+missing14+"'"};
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
const err43 = {instancePath,schemaPath:"#/oneOf/14/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key14},message:"must NOT have additional properties"};
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
if(!(validate467(data.float32, {instancePath:instancePath+"/float32",parentData:data,parentDataProperty:"float32",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate467.errors : vErrors.concat(validate467.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err44 = {instancePath,schemaPath:"#/oneOf/14/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err45 = {instancePath,schemaPath:"#/oneOf/15/required",keyword:"required",params:{missingProperty: missing15},message:"must have required property '"+missing15+"'"};
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
const err46 = {instancePath,schemaPath:"#/oneOf/15/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key15},message:"must NOT have additional properties"};
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
if(!(validate583(data.decimal, {instancePath:instancePath+"/decimal",parentData:data,parentDataProperty:"decimal",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate583.errors : vErrors.concat(validate583.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err47 = {instancePath,schemaPath:"#/oneOf/15/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err48 = {instancePath,schemaPath:"#/oneOf/16/required",keyword:"required",params:{missingProperty: missing16},message:"must have required property '"+missing16+"'"};
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
const err49 = {instancePath,schemaPath:"#/oneOf/16/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key16},message:"must NOT have additional properties"};
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
if(!(validate467(data.date, {instancePath:instancePath+"/date",parentData:data,parentDataProperty:"date",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate467.errors : vErrors.concat(validate467.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err50 = {instancePath,schemaPath:"#/oneOf/16/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err51 = {instancePath,schemaPath:"#/oneOf/17/required",keyword:"required",params:{missingProperty: missing17},message:"must have required property '"+missing17+"'"};
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
const err52 = {instancePath,schemaPath:"#/oneOf/17/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key17},message:"must NOT have additional properties"};
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
if(!(validate467(data.time, {instancePath:instancePath+"/time",parentData:data,parentDataProperty:"time",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate467.errors : vErrors.concat(validate467.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err53 = {instancePath,schemaPath:"#/oneOf/17/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err54 = {instancePath,schemaPath:"#/oneOf/18/required",keyword:"required",params:{missingProperty: missing18},message:"must have required property '"+missing18+"'"};
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
const err55 = {instancePath,schemaPath:"#/oneOf/18/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key18},message:"must NOT have additional properties"};
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
if(!(validate589(data.timestamp, {instancePath:instancePath+"/timestamp",parentData:data,parentDataProperty:"timestamp",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate589.errors : vErrors.concat(validate589.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err56 = {instancePath,schemaPath:"#/oneOf/18/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err57 = {instancePath,schemaPath:"#/oneOf/19/required",keyword:"required",params:{missingProperty: missing19},message:"must have required property '"+missing19+"'"};
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
const err58 = {instancePath,schemaPath:"#/oneOf/19/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key19},message:"must NOT have additional properties"};
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
if(!(validate467(data.interval, {instancePath:instancePath+"/interval",parentData:data,parentDataProperty:"interval",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate467.errors : vErrors.concat(validate467.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err59 = {instancePath,schemaPath:"#/oneOf/19/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err60 = {instancePath,schemaPath:"#/oneOf/20/required",keyword:"required",params:{missingProperty: missing20},message:"must have required property '"+missing20+"'"};
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
const err61 = {instancePath,schemaPath:"#/oneOf/20/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key20},message:"must NOT have additional properties"};
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
if(!(validate467(data.uuid, {instancePath:instancePath+"/uuid",parentData:data,parentDataProperty:"uuid",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate467.errors : vErrors.concat(validate467.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err62 = {instancePath,schemaPath:"#/oneOf/20/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err63 = {instancePath,schemaPath:"#/oneOf/21/required",keyword:"required",params:{missingProperty: missing21},message:"must have required property '"+missing21+"'"};
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
const err64 = {instancePath,schemaPath:"#/oneOf/21/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key21},message:"must NOT have additional properties"};
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
if(!(validate238(data.structure, {instancePath:instancePath+"/structure",parentData:data,parentDataProperty:"structure",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate238.errors : vErrors.concat(validate238.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err65 = {instancePath,schemaPath:"#/oneOf/21/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err66 = {instancePath,schemaPath:"#/oneOf/22/required",keyword:"required",params:{missingProperty: missing22},message:"must have required property '"+missing22+"'"};
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
const err67 = {instancePath,schemaPath:"#/oneOf/22/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key22},message:"must NOT have additional properties"};
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
if(!(validate594(data.list, {instancePath:instancePath+"/list",parentData:data,parentDataProperty:"list",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate594.errors : vErrors.concat(validate594.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err68 = {instancePath,schemaPath:"#/oneOf/22/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err69 = {instancePath,schemaPath:"#/oneOf/23/required",keyword:"required",params:{missingProperty: missing23},message:"must have required property '"+missing23+"'"};
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
const err70 = {instancePath,schemaPath:"#/oneOf/23/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key23},message:"must NOT have additional properties"};
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
if(!(validate597(data.array, {instancePath:instancePath+"/array",parentData:data,parentDataProperty:"array",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate597.errors : vErrors.concat(validate597.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err71 = {instancePath,schemaPath:"#/oneOf/23/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err72 = {instancePath,schemaPath:"#/oneOf/24/required",keyword:"required",params:{missingProperty: missing24},message:"must have required property '"+missing24+"'"};
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
const err73 = {instancePath,schemaPath:"#/oneOf/24/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key24},message:"must NOT have additional properties"};
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
if(!(validate602(data.map, {instancePath:instancePath+"/map",parentData:data,parentDataProperty:"map",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate602.errors : vErrors.concat(validate602.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err74 = {instancePath,schemaPath:"#/oneOf/24/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err75 = {instancePath,schemaPath:"#/oneOf/25/required",keyword:"required",params:{missingProperty: missing25},message:"must have required property '"+missing25+"'"};
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
const err76 = {instancePath,schemaPath:"#/oneOf/25/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key25},message:"must NOT have additional properties"};
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
if(!(validate238(data.tagged_union, {instancePath:instancePath+"/tagged_union",parentData:data,parentDataProperty:"tagged_union",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate238.errors : vErrors.concat(validate238.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err77 = {instancePath,schemaPath:"#/oneOf/25/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err78 = {instancePath,schemaPath:"#/oneOf/26/required",keyword:"required",params:{missingProperty: missing26},message:"must have required property '"+missing26+"'"};
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
const err79 = {instancePath,schemaPath:"#/oneOf/26/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key26},message:"must NOT have additional properties"};
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
if(!(validate467(data.json, {instancePath:instancePath+"/json",parentData:data,parentDataProperty:"json",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate467.errors : vErrors.concat(validate467.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err80 = {instancePath,schemaPath:"#/oneOf/26/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err81 = {instancePath,schemaPath:"#/oneOf",keyword:"oneOf",params:{passingSchemas: passing0},message:"must match exactly one schema in oneOf"};
if(vErrors === null){
vErrors = [err81];
}
else {
vErrors.push(err81);
}
errors++;
validate567.errors = vErrors;
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
validate567.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate567.evaluated = {"dynamicProps":true,"dynamicItems":false};


function validate564(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate564.evaluated;
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
validate564.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "column") || (key0 === "op")) || (key0 === "type"))){
validate564.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.column !== undefined){
const _errs2 = errors;
if(!(validate480(data.column, {instancePath:instancePath+"/column",parentData:data,parentDataProperty:"column",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate480.errors : vErrors.concat(validate480.errors);
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
if(!(validate477(data.op, {instancePath:instancePath+"/op",parentData:data,parentDataProperty:"op",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate477.errors : vErrors.concat(validate477.errors);
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
if(!(validate567(data.type, {instancePath:instancePath+"/type",parentData:data,parentDataProperty:"type",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate567.errors : vErrors.concat(validate567.errors);
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
validate564.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate564.errors = vErrors;
return errors === 0;
}
validate564.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema178 = {"type":"object","additionalProperties":false,"properties":{"column":{"$ref":"#/$defs/Response/$defs/T95"},"op":{"$ref":"#/$defs/Response/$defs/T93"},"type":{"$ref":"#/$defs/Response/$defs/T117"}},"required":["column","op","type"]};

function validate609(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate609.evaluated;
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
validate609.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "column") || (key0 === "op")) || (key0 === "type"))){
validate609.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.column !== undefined){
const _errs2 = errors;
if(!(validate480(data.column, {instancePath:instancePath+"/column",parentData:data,parentDataProperty:"column",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate480.errors : vErrors.concat(validate480.errors);
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
if(!(validate477(data.op, {instancePath:instancePath+"/op",parentData:data,parentDataProperty:"op",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate477.errors : vErrors.concat(validate477.errors);
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
if(!(validate567(data.type, {instancePath:instancePath+"/type",parentData:data,parentDataProperty:"type",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate567.errors : vErrors.concat(validate567.errors);
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
validate609.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate609.errors = vErrors;
return errors === 0;
}
validate609.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate558(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate558.evaluated;
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
if((data.all === undefined) && (missing0 = "all")){
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
if(!(key0 === "all")){
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
if(data.all !== undefined){
if(!(validate467(data.all, {instancePath:instancePath+"/all",parentData:data,parentDataProperty:"all",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate467.errors : vErrors.concat(validate467.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err2 = {instancePath,schemaPath:"#/oneOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
if((data.state === undefined) && (missing1 = "state")){
const err3 = {instancePath,schemaPath:"#/oneOf/1/required",keyword:"required",params:{missingProperty: missing1},message:"must have required property '"+missing1+"'"};
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
if(!(key1 === "state")){
const err4 = {instancePath,schemaPath:"#/oneOf/1/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key1},message:"must NOT have additional properties"};
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
if(data.state !== undefined){
if(!(validate560(data.state, {instancePath:instancePath+"/state",parentData:data,parentDataProperty:"state",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate560.errors : vErrors.concat(validate560.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err5 = {instancePath,schemaPath:"#/oneOf/1/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
if((data.compare === undefined) && (missing2 = "compare")){
const err6 = {instancePath,schemaPath:"#/oneOf/2/required",keyword:"required",params:{missingProperty: missing2},message:"must have required property '"+missing2+"'"};
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
if(!(key2 === "compare")){
const err7 = {instancePath,schemaPath:"#/oneOf/2/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key2},message:"must NOT have additional properties"};
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
if(data.compare !== undefined){
if(!(validate564(data.compare, {instancePath:instancePath+"/compare",parentData:data,parentDataProperty:"compare",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate564.errors : vErrors.concat(validate564.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err8 = {instancePath,schemaPath:"#/oneOf/2/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
if((data.null_compare === undefined) && (missing3 = "null_compare")){
const err9 = {instancePath,schemaPath:"#/oneOf/3/required",keyword:"required",params:{missingProperty: missing3},message:"must have required property '"+missing3+"'"};
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
if(!(key3 === "null_compare")){
const err10 = {instancePath,schemaPath:"#/oneOf/3/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key3},message:"must NOT have additional properties"};
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
if(data.null_compare !== undefined){
if(!(validate609(data.null_compare, {instancePath:instancePath+"/null_compare",parentData:data,parentDataProperty:"null_compare",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate609.errors : vErrors.concat(validate609.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err11 = {instancePath,schemaPath:"#/oneOf/3/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err12 = {instancePath,schemaPath:"#/oneOf",keyword:"oneOf",params:{passingSchemas: passing0},message:"must match exactly one schema in oneOf"};
if(vErrors === null){
vErrors = [err12];
}
else {
vErrors.push(err12);
}
errors++;
validate558.errors = vErrors;
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
validate558.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate558.evaluated = {"dynamicProps":true,"dynamicItems":false};


function validate557(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate557.evaluated;
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
if(!(key0 === "atom")){
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
if(data.atom !== undefined){
if(!(validate558(data.atom, {instancePath:instancePath+"/atom",parentData:data,parentDataProperty:"atom",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate558.errors : vErrors.concat(validate558.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err2 = {instancePath,schemaPath:"#/oneOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
if((data.negate === undefined) && (missing1 = "negate")){
const err3 = {instancePath,schemaPath:"#/oneOf/1/required",keyword:"required",params:{missingProperty: missing1},message:"must have required property '"+missing1+"'"};
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
if(!(key1 === "negate")){
const err4 = {instancePath,schemaPath:"#/oneOf/1/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key1},message:"must NOT have additional properties"};
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
if(data.negate !== undefined){
if(!(validate467(data.negate, {instancePath:instancePath+"/negate",parentData:data,parentDataProperty:"negate",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate467.errors : vErrors.concat(validate467.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err5 = {instancePath,schemaPath:"#/oneOf/1/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
if((data.conjunction === undefined) && (missing2 = "conjunction")){
const err6 = {instancePath,schemaPath:"#/oneOf/2/required",keyword:"required",params:{missingProperty: missing2},message:"must have required property '"+missing2+"'"};
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
if(!(key2 === "conjunction")){
const err7 = {instancePath,schemaPath:"#/oneOf/2/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key2},message:"must NOT have additional properties"};
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
if(data.conjunction !== undefined){
if(!(validate467(data.conjunction, {instancePath:instancePath+"/conjunction",parentData:data,parentDataProperty:"conjunction",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate467.errors : vErrors.concat(validate467.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err8 = {instancePath,schemaPath:"#/oneOf/2/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
if((data.disjunction === undefined) && (missing3 = "disjunction")){
const err9 = {instancePath,schemaPath:"#/oneOf/3/required",keyword:"required",params:{missingProperty: missing3},message:"must have required property '"+missing3+"'"};
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
if(!(key3 === "disjunction")){
const err10 = {instancePath,schemaPath:"#/oneOf/3/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key3},message:"must NOT have additional properties"};
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
if(data.disjunction !== undefined){
if(!(validate467(data.disjunction, {instancePath:instancePath+"/disjunction",parentData:data,parentDataProperty:"disjunction",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate467.errors : vErrors.concat(validate467.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err11 = {instancePath,schemaPath:"#/oneOf/3/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
}
}
}
if(!valid0){
const err12 = {instancePath,schemaPath:"#/oneOf",keyword:"oneOf",params:{passingSchemas: passing0},message:"must match exactly one schema in oneOf"};
if(vErrors === null){
vErrors = [err12];
}
else {
vErrors.push(err12);
}
errors++;
validate557.errors = vErrors;
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
validate557.errors = vErrors;
evaluated0.props = props1;
return errors === 0;
}
validate557.evaluated = {"dynamicProps":true,"dynamicItems":false};


function validate556(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate556.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(Array.isArray(data)){
if(data.length > 64){
validate556.errors = [{instancePath,schemaPath:"#/maxItems",keyword:"maxItems",params:{limit: 64},message:"must NOT have more than 64 items"}];
return false;
}
else {
var valid0 = true;
const len0 = data.length;
for(let i0=0; i0<len0; i0++){
const _errs1 = errors;
if(!(validate557(data[i0], {instancePath:instancePath+"/" + i0,parentData:data,parentDataProperty:i0,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate557.errors : vErrors.concat(validate557.errors);
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
validate556.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "array"},message:"must be array"}];
return false;
}
}
validate556.errors = vErrors;
return errors === 0;
}
validate556.evaluated = {"items":true,"dynamicProps":false,"dynamicItems":false};


function validate540(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate540.evaluated;
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
if((data.all === undefined) && (missing0 = "all")){
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
if(!(key0 === "all")){
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
if(data.all !== undefined){
if(!(validate211(data.all, {instancePath:instancePath+"/all",parentData:data,parentDataProperty:"all",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate211.errors : vErrors.concat(validate211.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err2 = {instancePath,schemaPath:"#/oneOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
if((data.state === undefined) && (missing1 = "state")){
const err3 = {instancePath,schemaPath:"#/oneOf/1/required",keyword:"required",params:{missingProperty: missing1},message:"must have required property '"+missing1+"'"};
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
if(!(key1 === "state")){
const err4 = {instancePath,schemaPath:"#/oneOf/1/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key1},message:"must NOT have additional properties"};
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
if(data.state !== undefined){
if(!(validate542(data.state, {instancePath:instancePath+"/state",parentData:data,parentDataProperty:"state",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate542.errors : vErrors.concat(validate542.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err5 = {instancePath,schemaPath:"#/oneOf/1/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
if((data.compare === undefined) && (missing2 = "compare")){
const err6 = {instancePath,schemaPath:"#/oneOf/2/required",keyword:"required",params:{missingProperty: missing2},message:"must have required property '"+missing2+"'"};
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
if(!(key2 === "compare")){
const err7 = {instancePath,schemaPath:"#/oneOf/2/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key2},message:"must NOT have additional properties"};
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
if(data.compare !== undefined){
if(!(validate546(data.compare, {instancePath:instancePath+"/compare",parentData:data,parentDataProperty:"compare",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate546.errors : vErrors.concat(validate546.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err8 = {instancePath,schemaPath:"#/oneOf/2/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
if((data.null_compare === undefined) && (missing3 = "null_compare")){
const err9 = {instancePath,schemaPath:"#/oneOf/3/required",keyword:"required",params:{missingProperty: missing3},message:"must have required property '"+missing3+"'"};
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
if(!(key3 === "null_compare")){
const err10 = {instancePath,schemaPath:"#/oneOf/3/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key3},message:"must NOT have additional properties"};
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
if(data.null_compare !== undefined){
if(!(validate551(data.null_compare, {instancePath:instancePath+"/null_compare",parentData:data,parentDataProperty:"null_compare",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate551.errors : vErrors.concat(validate551.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err11 = {instancePath,schemaPath:"#/oneOf/3/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
if((data.program === undefined) && (missing4 = "program")){
const err12 = {instancePath,schemaPath:"#/oneOf/4/required",keyword:"required",params:{missingProperty: missing4},message:"must have required property '"+missing4+"'"};
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
if(!(key4 === "program")){
const err13 = {instancePath,schemaPath:"#/oneOf/4/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key4},message:"must NOT have additional properties"};
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
if(data.program !== undefined){
if(!(validate556(data.program, {instancePath:instancePath+"/program",parentData:data,parentDataProperty:"program",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate556.errors : vErrors.concat(validate556.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err14 = {instancePath,schemaPath:"#/oneOf/4/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err15 = {instancePath,schemaPath:"#/oneOf",keyword:"oneOf",params:{passingSchemas: passing0},message:"must match exactly one schema in oneOf"};
if(vErrors === null){
vErrors = [err15];
}
else {
vErrors.push(err15);
}
errors++;
validate540.errors = vErrors;
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
validate540.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate540.evaluated = {"dynamicProps":true,"dynamicItems":false};


function validate535(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate535.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((((((((data.operators === undefined) && (missing0 = "operators")) || ((data.predicate === undefined) && (missing0 = "predicate"))) || ((data.projection === undefined) && (missing0 = "projection"))) || ((data.limit === undefined) && (missing0 = "limit"))) || ((data.aggregate === undefined) && (missing0 = "aggregate"))) || ((data.columns === undefined) && (missing0 = "columns"))) || ((data.budgets === undefined) && (missing0 = "budgets"))){
validate535.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((((((key0 === "operators") || (key0 === "predicate")) || (key0 === "projection")) || (key0 === "limit")) || (key0 === "aggregate")) || (key0 === "columns")) || (key0 === "budgets"))){
validate535.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.operators !== undefined){
const _errs2 = errors;
if(!(validate536(data.operators, {instancePath:instancePath+"/operators",parentData:data,parentDataProperty:"operators",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate536.errors : vErrors.concat(validate536.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.predicate !== undefined){
const _errs3 = errors;
if(!(validate540(data.predicate, {instancePath:instancePath+"/predicate",parentData:data,parentDataProperty:"predicate",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate540.errors : vErrors.concat(validate540.errors);
errors = vErrors.length;
}
var valid0 = _errs3 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.projection !== undefined){
const _errs4 = errors;
if(!(validate532(data.projection, {instancePath:instancePath+"/projection",parentData:data,parentDataProperty:"projection",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate532.errors : vErrors.concat(validate532.errors);
errors = vErrors.length;
}
var valid0 = _errs4 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.limit !== undefined){
const _errs5 = errors;
if(!(validate344(data.limit, {instancePath:instancePath+"/limit",parentData:data,parentDataProperty:"limit",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate344.errors : vErrors.concat(validate344.errors);
errors = vErrors.length;
}
var valid0 = _errs5 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.aggregate !== undefined){
const _errs6 = errors;
if(!(validate426(data.aggregate, {instancePath:instancePath+"/aggregate",parentData:data,parentDataProperty:"aggregate",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate426.errors : vErrors.concat(validate426.errors);
errors = vErrors.length;
}
var valid0 = _errs6 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.columns !== undefined){
const _errs7 = errors;
if(!(validate362(data.columns, {instancePath:instancePath+"/columns",parentData:data,parentDataProperty:"columns",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate362.errors : vErrors.concat(validate362.errors);
errors = vErrors.length;
}
var valid0 = _errs7 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.budgets !== undefined){
const _errs8 = errors;
if(!(validate339(data.budgets, {instancePath:instancePath+"/budgets",parentData:data,parentDataProperty:"budgets",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate339.errors : vErrors.concat(validate339.errors);
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
validate535.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate535.errors = vErrors;
return errors === 0;
}
validate535.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


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
if(!(validate529(data.description, {instancePath:instancePath+"/description",parentData:data,parentDataProperty:"description",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate529.errors : vErrors.concat(validate529.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err2 = {instancePath,schemaPath:"#/oneOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err3 = {instancePath,schemaPath:"#/oneOf/1/required",keyword:"required",params:{missingProperty: missing1},message:"must have required property '"+missing1+"'"};
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
const err4 = {instancePath,schemaPath:"#/oneOf/1/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key1},message:"must NOT have additional properties"};
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
if(!(validate532(data.tables, {instancePath:instancePath+"/tables",parentData:data,parentDataProperty:"tables",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate532.errors : vErrors.concat(validate532.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err5 = {instancePath,schemaPath:"#/oneOf/1/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
if((data.explanation === undefined) && (missing2 = "explanation")){
const err6 = {instancePath,schemaPath:"#/oneOf/2/required",keyword:"required",params:{missingProperty: missing2},message:"must have required property '"+missing2+"'"};
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
if(!(key2 === "explanation")){
const err7 = {instancePath,schemaPath:"#/oneOf/2/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key2},message:"must NOT have additional properties"};
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
if(data.explanation !== undefined){
if(!(validate535(data.explanation, {instancePath:instancePath+"/explanation",parentData:data,parentDataProperty:"explanation",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate535.errors : vErrors.concat(validate535.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err8 = {instancePath,schemaPath:"#/oneOf/2/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err9 = {instancePath,schemaPath:"#/oneOf",keyword:"oneOf",params:{passingSchemas: passing0},message:"must match exactly one schema in oneOf"};
if(vErrors === null){
vErrors = [err9];
}
else {
vErrors.push(err9);
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


function validate516(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate516.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if(((((((((((data.version === undefined) && (missing0 = "version")) || ((data.scope === undefined) && (missing0 = "scope"))) || ((data.name === undefined) && (missing0 = "name"))) || ((data.resource === undefined) && (missing0 = "resource"))) || ((data.source_kind === undefined) && (missing0 = "source_kind"))) || ((data.contract === undefined) && (missing0 = "contract"))) || ((data.schema === undefined) && (missing0 = "schema"))) || ((data.resource_revision === undefined) && (missing0 = "resource_revision"))) || ((data.policy_revision === undefined) && (missing0 = "policy_revision"))) || ((data.details === undefined) && (missing0 = "details"))){
validate516.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(func4.call(schema153.properties, key0))){
validate516.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.version !== undefined){
const _errs2 = errors;
if(!(validate161(data.version, {instancePath:instancePath+"/version",parentData:data,parentDataProperty:"version",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate161.errors : vErrors.concat(validate161.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.scope !== undefined){
const _errs3 = errors;
if(!(validate518(data.scope, {instancePath:instancePath+"/scope",parentData:data,parentDataProperty:"scope",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate518.errors : vErrors.concat(validate518.errors);
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
if(!(validate157(data.name, {instancePath:instancePath+"/name",parentData:data,parentDataProperty:"name",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate157.errors : vErrors.concat(validate157.errors);
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
if(!(validate146(data.resource, {instancePath:instancePath+"/resource",parentData:data,parentDataProperty:"resource",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate146.errors : vErrors.concat(validate146.errors);
errors = vErrors.length;
}
var valid0 = _errs5 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.source_kind !== undefined){
const _errs6 = errors;
if(!(validate522(data.source_kind, {instancePath:instancePath+"/source_kind",parentData:data,parentDataProperty:"source_kind",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate522.errors : vErrors.concat(validate522.errors);
errors = vErrors.length;
}
var valid0 = _errs6 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.contract !== undefined){
const _errs7 = errors;
if(!(validate204(data.contract, {instancePath:instancePath+"/contract",parentData:data,parentDataProperty:"contract",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate204.errors : vErrors.concat(validate204.errors);
errors = vErrors.length;
}
var valid0 = _errs7 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.schema !== undefined){
const _errs8 = errors;
if(!(validate204(data.schema, {instancePath:instancePath+"/schema",parentData:data,parentDataProperty:"schema",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate204.errors : vErrors.concat(validate204.errors);
errors = vErrors.length;
}
var valid0 = _errs8 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.resource_revision !== undefined){
const _errs9 = errors;
if(!(validate146(data.resource_revision, {instancePath:instancePath+"/resource_revision",parentData:data,parentDataProperty:"resource_revision",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate146.errors : vErrors.concat(validate146.errors);
errors = vErrors.length;
}
var valid0 = _errs9 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.policy_revision !== undefined){
const _errs10 = errors;
if(!(validate157(data.policy_revision, {instancePath:instancePath+"/policy_revision",parentData:data,parentDataProperty:"policy_revision",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate157.errors : vErrors.concat(validate157.errors);
errors = vErrors.length;
}
var valid0 = _errs10 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.details !== undefined){
const _errs11 = errors;
if(!(validate528(data.details, {instancePath:instancePath+"/details",parentData:data,parentDataProperty:"details",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate528.errors : vErrors.concat(validate528.errors);
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
validate516.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate516.errors = vErrors;
return errors === 0;
}
validate516.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema179 = {"anyOf":[{"$ref":"#/$defs/Response/$defs/T127"},{"type":"null"}]};
const schema180 = {"type":"object","additionalProperties":false,"properties":{"token":{"$ref":"#/$defs/Response/$defs/T5"}},"required":["token"]};

function validate630(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate630.evaluated;
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
validate630.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(key0 === "token")){
validate630.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.token !== undefined){
if(!(validate157(data.token, {instancePath:instancePath+"/token",parentData:data,parentDataProperty:"token",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate157.errors : vErrors.concat(validate157.errors);
errors = vErrors.length;
}
}
}
}
}
else {
validate630.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate630.errors = vErrors;
return errors === 0;
}
validate630.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate629(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate629.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate630(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate630.errors : vErrors.concat(validate630.errors);
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
validate629.errors = vErrors;
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
validate629.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate629.evaluated = {"dynamicProps":true,"dynamicItems":false};

const schema181 = {"type":"object","additionalProperties":false,"properties":{"position":{"$ref":"#/$defs/Response/$defs/T3"}},"required":["position"]};

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
if((data.position === undefined) && (missing0 = "position")){
validate634.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(key0 === "position")){
validate634.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.position !== undefined){
if(!(validate146(data.position, {instancePath:instancePath+"/position",parentData:data,parentDataProperty:"position",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate146.errors : vErrors.concat(validate146.errors);
errors = vErrors.length;
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

const schema182 = {"oneOf":[{"type":"object","additionalProperties":false,"required":["pending"],"properties":{"pending":{"$ref":"#/$defs/Response/$defs/T22"}}},{"type":"object","additionalProperties":false,"required":["committed"],"properties":{"committed":{"$ref":"#/$defs/Response/$defs/T22"}}},{"type":"object","additionalProperties":false,"required":["rejected"],"properties":{"rejected":{"$ref":"#/$defs/Response/$defs/T130"}}}]};
const schema183 = {"type":"string","pattern":"^(?:[0-9a-f]{2})*$","maxLength":512};
const pattern3 = new RegExp("^(?:[0-9a-f]{2})*$", "u");

function validate640(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate640.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(typeof data === "string"){
if(func1(data) > 512){
validate640.errors = [{instancePath,schemaPath:"#/maxLength",keyword:"maxLength",params:{limit: 512},message:"must NOT have more than 512 characters"}];
return false;
}
else {
if(!pattern3.test(data)){
validate640.errors = [{instancePath,schemaPath:"#/pattern",keyword:"pattern",params:{pattern: "^(?:[0-9a-f]{2})*$"},message:"must match pattern \""+"^(?:[0-9a-f]{2})*$"+"\""}];
return false;
}
}
}
else {
validate640.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
}
validate640.errors = vErrors;
return errors === 0;
}
validate640.evaluated = {"dynamicProps":false,"dynamicItems":false};


function validate637(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate637.evaluated;
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
if((data.pending === undefined) && (missing0 = "pending")){
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
if(!(key0 === "pending")){
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
if(data.pending !== undefined){
if(!(validate211(data.pending, {instancePath:instancePath+"/pending",parentData:data,parentDataProperty:"pending",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate211.errors : vErrors.concat(validate211.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err2 = {instancePath,schemaPath:"#/oneOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
if((data.committed === undefined) && (missing1 = "committed")){
const err3 = {instancePath,schemaPath:"#/oneOf/1/required",keyword:"required",params:{missingProperty: missing1},message:"must have required property '"+missing1+"'"};
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
if(!(key1 === "committed")){
const err4 = {instancePath,schemaPath:"#/oneOf/1/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key1},message:"must NOT have additional properties"};
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
if(data.committed !== undefined){
if(!(validate211(data.committed, {instancePath:instancePath+"/committed",parentData:data,parentDataProperty:"committed",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate211.errors : vErrors.concat(validate211.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err5 = {instancePath,schemaPath:"#/oneOf/1/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
if((data.rejected === undefined) && (missing2 = "rejected")){
const err6 = {instancePath,schemaPath:"#/oneOf/2/required",keyword:"required",params:{missingProperty: missing2},message:"must have required property '"+missing2+"'"};
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
if(!(key2 === "rejected")){
const err7 = {instancePath,schemaPath:"#/oneOf/2/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key2},message:"must NOT have additional properties"};
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
if(data.rejected !== undefined){
if(!(validate640(data.rejected, {instancePath:instancePath+"/rejected",parentData:data,parentDataProperty:"rejected",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate640.errors : vErrors.concat(validate640.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err8 = {instancePath,schemaPath:"#/oneOf/2/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err9 = {instancePath,schemaPath:"#/oneOf",keyword:"oneOf",params:{passingSchemas: passing0},message:"must match exactly one schema in oneOf"};
if(vErrors === null){
vErrors = [err9];
}
else {
vErrors.push(err9);
}
errors++;
validate637.errors = vErrors;
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
validate637.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate637.evaluated = {"dynamicProps":true,"dynamicItems":false};

const schema184 = {"anyOf":[{"$ref":"#/$defs/Response/$defs/T132"},{"type":"null"}]};
const schema185 = {"type":"object","additionalProperties":false,"properties":{"reference":{"$ref":"#/$defs/Response/$defs/T130"},"phase":{"$ref":"#/$defs/Response/$defs/T133"},"correlation":{"$ref":"#/$defs/Response/$defs/T5"},"manifest":{"$ref":"#/$defs/Response/$defs/T134"},"collected":{"$ref":"#/$defs/Response/$defs/T11"},"failure":{"$ref":"#/$defs/Response/$defs/T135"},"diagnostic":{"$ref":"#/$defs/Response/$defs/T140"}},"required":["reference","phase","correlation","manifest","collected","failure","diagnostic"]};
const schema186 = {"type":"string","enum":["uploading","sealed","admitted","complete","cancelled","denied","rejected","retired","prepared"]};

function validate646(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate646.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate646.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
if(!(((((((((data === "uploading") || (data === "sealed")) || (data === "admitted")) || (data === "complete")) || (data === "cancelled")) || (data === "denied")) || (data === "rejected")) || (data === "retired")) || (data === "prepared"))){
validate646.errors = [{instancePath,schemaPath:"#/enum",keyword:"enum",params:{allowedValues: schema186.enum},message:"must be equal to one of the allowed values"}];
return false;
}
validate646.errors = vErrors;
return errors === 0;
}
validate646.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema187 = {"anyOf":[{"$ref":"#/$defs/Response/$defs/T130"},{"type":"null"}]};

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
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate640(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate640.errors : vErrors.concat(validate640.errors);
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
validate649.errors = vErrors;
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
validate649.errors = vErrors;
return errors === 0;
}
validate649.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema188 = {"anyOf":[{"$ref":"#/$defs/Response/$defs/T136"},{"type":"null"}]};
const schema189 = {"type":"object","additionalProperties":false,"properties":{"code":{"$ref":"#/$defs/Response/$defs/T137"},"stage":{"$ref":"#/$defs/Response/$defs/T138"},"dimension":{"$ref":"#/$defs/Response/$defs/T139"},"limit":{"$ref":"#/$defs/Response/$defs/T5"},"observed":{"$ref":"#/$defs/Response/$defs/T5"}},"required":["code","stage","dimension","limit","observed"]};
const schema190 = {"type":"string","enum":["policy_denied","access_denied","resource_unavailable","request_unpublished","publisher_mismatch","document_history_gap","document_retired","document_resync_required","budget_exceeded","projection_budget","expansion_missing","expansion_null","expansion_conflict","expansion_type_error","cell_type_error","cell_conflict","arithmetic_overflow","segment_byte_limit","type_mismatch","unsupported_aggregate","unknown_column","invalid_projection","duplicate_projection","invalid_bundle","invalid_source","invalid_prefix","invalid_path","invalid_projection_budget","invalid_text_projection","invalid_element_projection","unsupported_source","unsupported_decoder","unsupported_document_source","invalid_source_encoding","invalid_plan_encoding","plan_definition_mismatch","invalid_output_names","unsupported_plan","plan_too_large","bundle_too_large","truncated_input","source_changed","table_schema_changed","invalid_budget","namespace_in_use","query_after_mutation","nonfinite_value","invalid_utf8","cell_too_large","invalid_column_name","invalid_column_count","duplicate_column","unsupported_schema","peer_mismatch","invalid_request_reference","writer_not_ready","request_resource_expired","request_resource_missing","catalog_read_denied","catalog_owner_changed","catalog_configuration_changed","catalog_uninitialized","table_absent","table_retired","table_definition_changed","definition_mismatch","value_budget","unsupported_comparison","source_definition_too_large","catalog_scope_changed","adapter_memory_budget","arrow_workspace_budget"]};

function validate655(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate655.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate655.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
if(!((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((data === "policy_denied") || (data === "access_denied")) || (data === "resource_unavailable")) || (data === "request_unpublished")) || (data === "publisher_mismatch")) || (data === "document_history_gap")) || (data === "document_retired")) || (data === "document_resync_required")) || (data === "budget_exceeded")) || (data === "projection_budget")) || (data === "expansion_missing")) || (data === "expansion_null")) || (data === "expansion_conflict")) || (data === "expansion_type_error")) || (data === "cell_type_error")) || (data === "cell_conflict")) || (data === "arithmetic_overflow")) || (data === "segment_byte_limit")) || (data === "type_mismatch")) || (data === "unsupported_aggregate")) || (data === "unknown_column")) || (data === "invalid_projection")) || (data === "duplicate_projection")) || (data === "invalid_bundle")) || (data === "invalid_source")) || (data === "invalid_prefix")) || (data === "invalid_path")) || (data === "invalid_projection_budget")) || (data === "invalid_text_projection")) || (data === "invalid_element_projection")) || (data === "unsupported_source")) || (data === "unsupported_decoder")) || (data === "unsupported_document_source")) || (data === "invalid_source_encoding")) || (data === "invalid_plan_encoding")) || (data === "plan_definition_mismatch")) || (data === "invalid_output_names")) || (data === "unsupported_plan")) || (data === "plan_too_large")) || (data === "bundle_too_large")) || (data === "truncated_input")) || (data === "source_changed")) || (data === "table_schema_changed")) || (data === "invalid_budget")) || (data === "namespace_in_use")) || (data === "query_after_mutation")) || (data === "nonfinite_value")) || (data === "invalid_utf8")) || (data === "cell_too_large")) || (data === "invalid_column_name")) || (data === "invalid_column_count")) || (data === "duplicate_column")) || (data === "unsupported_schema")) || (data === "peer_mismatch")) || (data === "invalid_request_reference")) || (data === "writer_not_ready")) || (data === "request_resource_expired")) || (data === "request_resource_missing")) || (data === "catalog_read_denied")) || (data === "catalog_owner_changed")) || (data === "catalog_configuration_changed")) || (data === "catalog_uninitialized")) || (data === "table_absent")) || (data === "table_retired")) || (data === "table_definition_changed")) || (data === "definition_mismatch")) || (data === "value_budget")) || (data === "unsupported_comparison")) || (data === "source_definition_too_large")) || (data === "catalog_scope_changed")) || (data === "adapter_memory_budget")) || (data === "arrow_workspace_budget"))){
validate655.errors = [{instancePath,schemaPath:"#/enum",keyword:"enum",params:{allowedValues: schema190.enum},message:"must be equal to one of the allowed values"}];
return false;
}
validate655.errors = vErrors;
return errors === 0;
}
validate655.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema191 = {"type":"string","enum":["admission","execution"]};

function validate657(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate657.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate657.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
if(!((data === "admission") || (data === "execution"))){
validate657.errors = [{instancePath,schemaPath:"#/enum",keyword:"enum",params:{allowedValues: schema191.enum},message:"must be equal to one of the allowed values"}];
return false;
}
validate657.errors = vErrors;
return errors === 0;
}
validate657.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema192 = {"type":"string","enum":["none","pages","segments","result_bytes"]};

function validate659(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate659.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate659.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
if(!((((data === "none") || (data === "pages")) || (data === "segments")) || (data === "result_bytes"))){
validate659.errors = [{instancePath,schemaPath:"#/enum",keyword:"enum",params:{allowedValues: schema192.enum},message:"must be equal to one of the allowed values"}];
return false;
}
validate659.errors = vErrors;
return errors === 0;
}
validate659.evaluated = {"dynamicProps":false,"dynamicItems":false};


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
if((((((data.code === undefined) && (missing0 = "code")) || ((data.stage === undefined) && (missing0 = "stage"))) || ((data.dimension === undefined) && (missing0 = "dimension"))) || ((data.limit === undefined) && (missing0 = "limit"))) || ((data.observed === undefined) && (missing0 = "observed"))){
validate654.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((((key0 === "code") || (key0 === "stage")) || (key0 === "dimension")) || (key0 === "limit")) || (key0 === "observed"))){
validate654.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.code !== undefined){
const _errs2 = errors;
if(!(validate655(data.code, {instancePath:instancePath+"/code",parentData:data,parentDataProperty:"code",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate655.errors : vErrors.concat(validate655.errors);
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
if(!(validate657(data.stage, {instancePath:instancePath+"/stage",parentData:data,parentDataProperty:"stage",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate657.errors : vErrors.concat(validate657.errors);
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
if(!(validate659(data.dimension, {instancePath:instancePath+"/dimension",parentData:data,parentDataProperty:"dimension",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate659.errors : vErrors.concat(validate659.errors);
errors = vErrors.length;
}
var valid0 = _errs4 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.limit !== undefined){
const _errs5 = errors;
if(!(validate157(data.limit, {instancePath:instancePath+"/limit",parentData:data,parentDataProperty:"limit",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate157.errors : vErrors.concat(validate157.errors);
errors = vErrors.length;
}
var valid0 = _errs5 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.observed !== undefined){
const _errs6 = errors;
if(!(validate157(data.observed, {instancePath:instancePath+"/observed",parentData:data,parentDataProperty:"observed",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate157.errors : vErrors.concat(validate157.errors);
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
validate654.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate654.errors = vErrors;
return errors === 0;
}
validate654.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


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
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate654(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate654.errors : vErrors.concat(validate654.errors);
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
validate653.errors = vErrors;
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
validate653.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate653.evaluated = {"dynamicProps":true,"dynamicItems":false};

const schema193 = {"anyOf":[{"$ref":"#/$defs/Response/$defs/T141"},{"type":"null"}]};
const schema194 = {"type":"object","additionalProperties":false,"properties":{"version":{"const":1},"definition":{"$ref":"#/$defs/Response/$defs/T142"},"code":{"$ref":"#/$defs/Response/$defs/T143"},"category":{"$ref":"#/$defs/Response/$defs/T144"},"stage":{"$ref":"#/$defs/Response/$defs/T145"},"outcome":{"$ref":"#/$defs/Response/$defs/T146"},"evidence":{"$ref":"#/$defs/Response/$defs/T147"},"message":{"$ref":"#/$defs/Response/$defs/T148"},"cause":{"$ref":"#/$defs/Response/$defs/T149"},"identity":{"$ref":"#/$defs/Response/$defs/T150"},"location":{"$ref":"#/$defs/Response/$defs/T155"},"facts":{"$ref":"#/$defs/Response/$defs/T160"},"actions":{"$ref":"#/$defs/Response/$defs/T170"}},"required":["version","definition","code","category","stage","outcome","evidence","message","cause","identity","location","facts","actions"]};
const schema195 = {"type":"string","enum":["02553baa7d791340e9ea3339002537bf15495c26bd2f2bd2e2fde5950589e53f"]};

function validate668(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate668.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate668.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
if(!(data === "02553baa7d791340e9ea3339002537bf15495c26bd2f2bd2e2fde5950589e53f")){
validate668.errors = [{instancePath,schemaPath:"#/enum",keyword:"enum",params:{allowedValues: schema195.enum},message:"must be equal to one of the allowed values"}];
return false;
}
validate668.errors = vErrors;
return errors === 0;
}
validate668.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema197 = {"type":"string","maxLength":96};

function validate670(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate670.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(typeof data === "string"){
if(func1(data) > 96){
validate670.errors = [{instancePath,schemaPath:"#/maxLength",keyword:"maxLength",params:{limit: 96},message:"must NOT have more than 96 characters"}];
return false;
}
}
else {
validate670.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
}
validate670.errors = vErrors;
return errors === 0;
}
validate670.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema198 = {"type":"string","enum":["syntax","binding","unsupported","constraint","access","conflict","limit","lifecycle","integrity","unavailable","internal"]};

function validate673(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate673.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate673.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
if(!(((((((((((data === "syntax") || (data === "binding")) || (data === "unsupported")) || (data === "constraint")) || (data === "access")) || (data === "conflict")) || (data === "limit")) || (data === "lifecycle")) || (data === "integrity")) || (data === "unavailable")) || (data === "internal"))){
validate673.errors = [{instancePath,schemaPath:"#/enum",keyword:"enum",params:{allowedValues: schema198.enum},message:"must be equal to one of the allowed values"}];
return false;
}
validate673.errors = vErrors;
return errors === 0;
}
validate673.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema200 = {"type":"string","enum":["input","parse","compile","bind","prepare","submit","admission","execute","read","decode","output","reconcile","cleanup","control"]};

function validate676(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate676.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate676.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
if(!((((((((((((((data === "input") || (data === "parse")) || (data === "compile")) || (data === "bind")) || (data === "prepare")) || (data === "submit")) || (data === "admission")) || (data === "execute")) || (data === "read")) || (data === "decode")) || (data === "output")) || (data === "reconcile")) || (data === "cleanup")) || (data === "control"))){
validate676.errors = [{instancePath,schemaPath:"#/enum",keyword:"enum",params:{allowedValues: schema200.enum},message:"must be equal to one of the allowed values"}];
return false;
}
validate676.errors = vErrors;
return errors === 0;
}
validate676.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema202 = {"type":"string","enum":["not_applicable","not_submitted","not_dispatched","prepared","unknown","pending","input_rejected","rejected","applied","completed","failed","cancelled","retired","closed_unknown"]};

function validate679(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate679.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate679.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
if(!((((((((((((((data === "not_applicable") || (data === "not_submitted")) || (data === "not_dispatched")) || (data === "prepared")) || (data === "unknown")) || (data === "pending")) || (data === "input_rejected")) || (data === "rejected")) || (data === "applied")) || (data === "completed")) || (data === "failed")) || (data === "cancelled")) || (data === "retired")) || (data === "closed_unknown"))){
validate679.errors = [{instancePath,schemaPath:"#/enum",keyword:"enum",params:{allowedValues: schema202.enum},message:"must be equal to one of the allowed values"}];
return false;
}
validate679.errors = vErrors;
return errors === 0;
}
validate679.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema204 = {"type":"string","enum":["none","local_before_dispatch","saved_intent","native_receipt","domain_status"]};

function validate682(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate682.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate682.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
if(!(((((data === "none") || (data === "local_before_dispatch")) || (data === "saved_intent")) || (data === "native_receipt")) || (data === "domain_status"))){
validate682.errors = [{instancePath,schemaPath:"#/enum",keyword:"enum",params:{allowedValues: schema204.enum},message:"must be equal to one of the allowed values"}];
return false;
}
validate682.errors = vErrors;
return errors === 0;
}
validate682.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema206 = {"type":"string","maxLength":384};

function validate684(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate684.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(typeof data === "string"){
if(func1(data) > 384){
validate684.errors = [{instancePath,schemaPath:"#/maxLength",keyword:"maxLength",params:{limit: 384},message:"must NOT have more than 384 characters"}];
return false;
}
}
else {
validate684.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
}
validate684.errors = vErrors;
return errors === 0;
}
validate684.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema207 = {"anyOf":[{"$ref":"#/$defs/Response/$defs/T143"},{"type":"null"}]};

function validate686(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate686.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate670(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate670.errors : vErrors.concat(validate670.errors);
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
validate686.errors = vErrors;
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
validate686.errors = vErrors;
return errors === 0;
}
validate686.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema208 = {"anyOf":[{"$ref":"#/$defs/Response/$defs/T151"},{"type":"null"}]};
const schema209 = {"type":"object","additionalProperties":false,"properties":{"domain":{"$ref":"#/$defs/Response/$defs/T152"},"id":{"$ref":"#/$defs/Response/$defs/T153"},"realm":{"$ref":"#/$defs/Response/$defs/T154"},"resource":{"$ref":"#/$defs/Response/$defs/T154"},"sequence":{"$ref":"#/$defs/Response/$defs/T154"}},"required":["domain","id","realm","resource","sequence"]};
const schema210 = {"type":"string","enum":["sql","query","mutation","catalog","application","publication","migration","reactive","serving","effect","exchange","transport","internal"]};

function validate692(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate692.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate692.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
if(!(((((((((((((data === "sql") || (data === "query")) || (data === "mutation")) || (data === "catalog")) || (data === "application")) || (data === "publication")) || (data === "migration")) || (data === "reactive")) || (data === "serving")) || (data === "effect")) || (data === "exchange")) || (data === "transport")) || (data === "internal"))){
validate692.errors = [{instancePath,schemaPath:"#/enum",keyword:"enum",params:{allowedValues: schema210.enum},message:"must be equal to one of the allowed values"}];
return false;
}
validate692.errors = vErrors;
return errors === 0;
}
validate692.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema212 = {"type":"string","maxLength":20,"pattern":"^(0|[1-9][0-9]*)$"};
const pattern4 = new RegExp("^(0|[1-9][0-9]*)$", "u");

function validate695(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate695.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(typeof data === "string"){
if(func1(data) > 20){
validate695.errors = [{instancePath,schemaPath:"#/maxLength",keyword:"maxLength",params:{limit: 20},message:"must NOT have more than 20 characters"}];
return false;
}
else {
if(!pattern4.test(data)){
validate695.errors = [{instancePath,schemaPath:"#/pattern",keyword:"pattern",params:{pattern: "^(0|[1-9][0-9]*)$"},message:"must match pattern \""+"^(0|[1-9][0-9]*)$"+"\""}];
return false;
}
}
}
else {
validate695.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
}
validate695.errors = vErrors;
return errors === 0;
}
validate695.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema214 = {"anyOf":[{"$ref":"#/$defs/Response/$defs/T153"},{"type":"null"}]};

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
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate695(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate695.errors : vErrors.concat(validate695.errors);
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
validate697.errors = vErrors;
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
validate697.errors = vErrors;
return errors === 0;
}
validate697.evaluated = {"dynamicProps":false,"dynamicItems":false};


function validate690(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate690.evaluated;
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
validate690.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((((key0 === "domain") || (key0 === "id")) || (key0 === "realm")) || (key0 === "resource")) || (key0 === "sequence"))){
validate690.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.domain !== undefined){
const _errs2 = errors;
if(!(validate692(data.domain, {instancePath:instancePath+"/domain",parentData:data,parentDataProperty:"domain",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate692.errors : vErrors.concat(validate692.errors);
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
if(!(validate695(data.id, {instancePath:instancePath+"/id",parentData:data,parentDataProperty:"id",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate695.errors : vErrors.concat(validate695.errors);
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
if(!(validate697(data.realm, {instancePath:instancePath+"/realm",parentData:data,parentDataProperty:"realm",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate697.errors : vErrors.concat(validate697.errors);
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
if(!(validate697(data.resource, {instancePath:instancePath+"/resource",parentData:data,parentDataProperty:"resource",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate697.errors : vErrors.concat(validate697.errors);
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
if(!(validate697(data.sequence, {instancePath:instancePath+"/sequence",parentData:data,parentDataProperty:"sequence",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate697.errors : vErrors.concat(validate697.errors);
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
validate690.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate690.errors = vErrors;
return errors === 0;
}
validate690.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate689(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate689.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate690(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate690.errors : vErrors.concat(validate690.errors);
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
validate689.errors = vErrors;
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
validate689.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate689.evaluated = {"dynamicProps":true,"dynamicItems":false};

const schema215 = {"anyOf":[{"$ref":"#/$defs/Response/$defs/T156"},{"type":"null"}]};
const schema216 = {"type":"object","additionalProperties":false,"properties":{"source":{"$ref":"#/$defs/Response/$defs/T157"},"source_encoding":{"$ref":"#/$defs/Response/$defs/T159"},"source_truncated":{"$ref":"#/$defs/Response/$defs/T11"},"statement":{"$ref":"#/$defs/Response/$defs/T154"},"offset":{"$ref":"#/$defs/Response/$defs/T153"},"length":{"$ref":"#/$defs/Response/$defs/T153"},"line":{"$ref":"#/$defs/Response/$defs/T153"},"byte_column":{"$ref":"#/$defs/Response/$defs/T153"}},"required":["source","source_encoding","source_truncated","statement","offset","length","line","byte_column"]};
const schema217 = {"anyOf":[{"$ref":"#/$defs/Response/$defs/T158"},{"type":"null"}]};
const schema218 = {"type":"string","maxLength":512};

function validate707(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate707.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(typeof data === "string"){
if(func1(data) > 512){
validate707.errors = [{instancePath,schemaPath:"#/maxLength",keyword:"maxLength",params:{limit: 512},message:"must NOT have more than 512 characters"}];
return false;
}
}
else {
validate707.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
}
validate707.errors = vErrors;
return errors === 0;
}
validate707.evaluated = {"dynamicProps":false,"dynamicItems":false};


function validate706(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate706.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate707(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate707.errors : vErrors.concat(validate707.errors);
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
validate706.errors = vErrors;
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
validate706.errors = vErrors;
return errors === 0;
}
validate706.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema219 = {"type":"string","enum":["utf8","escaped_bytes"]};

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
if(!((data === "utf8") || (data === "escaped_bytes"))){
validate711.errors = [{instancePath,schemaPath:"#/enum",keyword:"enum",params:{allowedValues: schema219.enum},message:"must be equal to one of the allowed values"}];
return false;
}
validate711.errors = vErrors;
return errors === 0;
}
validate711.evaluated = {"dynamicProps":false,"dynamicItems":false};


function validate705(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate705.evaluated;
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
validate705.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((((((((key0 === "source") || (key0 === "source_encoding")) || (key0 === "source_truncated")) || (key0 === "statement")) || (key0 === "offset")) || (key0 === "length")) || (key0 === "line")) || (key0 === "byte_column"))){
validate705.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.source !== undefined){
const _errs2 = errors;
if(!(validate706(data.source, {instancePath:instancePath+"/source",parentData:data,parentDataProperty:"source",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate706.errors : vErrors.concat(validate706.errors);
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
if(!(validate711(data.source_encoding, {instancePath:instancePath+"/source_encoding",parentData:data,parentDataProperty:"source_encoding",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate711.errors : vErrors.concat(validate711.errors);
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
if(!(validate173(data.source_truncated, {instancePath:instancePath+"/source_truncated",parentData:data,parentDataProperty:"source_truncated",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate173.errors : vErrors.concat(validate173.errors);
errors = vErrors.length;
}
var valid0 = _errs4 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.statement !== undefined){
const _errs5 = errors;
if(!(validate697(data.statement, {instancePath:instancePath+"/statement",parentData:data,parentDataProperty:"statement",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate697.errors : vErrors.concat(validate697.errors);
errors = vErrors.length;
}
var valid0 = _errs5 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.offset !== undefined){
const _errs6 = errors;
if(!(validate695(data.offset, {instancePath:instancePath+"/offset",parentData:data,parentDataProperty:"offset",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate695.errors : vErrors.concat(validate695.errors);
errors = vErrors.length;
}
var valid0 = _errs6 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.length !== undefined){
const _errs7 = errors;
if(!(validate695(data.length, {instancePath:instancePath+"/length",parentData:data,parentDataProperty:"length",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate695.errors : vErrors.concat(validate695.errors);
errors = vErrors.length;
}
var valid0 = _errs7 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.line !== undefined){
const _errs8 = errors;
if(!(validate695(data.line, {instancePath:instancePath+"/line",parentData:data,parentDataProperty:"line",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate695.errors : vErrors.concat(validate695.errors);
errors = vErrors.length;
}
var valid0 = _errs8 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.byte_column !== undefined){
const _errs9 = errors;
if(!(validate695(data.byte_column, {instancePath:instancePath+"/byte_column",parentData:data,parentDataProperty:"byte_column",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate695.errors : vErrors.concat(validate695.errors);
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
validate705.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate705.errors = vErrors;
return errors === 0;
}
validate705.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


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
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate705(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate705.errors : vErrors.concat(validate705.errors);
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
validate704.errors = vErrors;
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
validate704.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate704.evaluated = {"dynamicProps":true,"dynamicItems":false};

const schema221 = {"type":"array","minItems":16,"maxItems":16,"items":{"$ref":"#/$defs/Response/$defs/T161"}};
const schema222 = {"anyOf":[{"$ref":"#/$defs/Response/$defs/T162"},{"type":"null"}]};
const schema223 = {"type":"object","additionalProperties":false,"properties":{"field":{"$ref":"#/$defs/Response/$defs/T163"},"origin":{"$ref":"#/$defs/Response/$defs/T164"},"availability":{"$ref":"#/$defs/Response/$defs/T165"},"value":{"$ref":"#/$defs/Response/$defs/T166"}},"required":["field","origin","availability","value"]};
const schema224 = {"type":"string","enum":["object","name","table","native_input","affected_rows","argument","option","permissions","scope","column","qualifier","constraint","key","input_row","first_occurrence","parameter","parameter_use","expected_count","actual_count","expected_type","actual_type","supplied_value","expected_value","expression","source_kind","source_basis","source_key","source_row","field_path","byte_offset","expected_resource","actual_resource","expected_source","actual_source","expected_revision","actual_revision","expected_schema","actual_schema","expected_policy","actual_policy","budget","limit","required","unit","completed_statements","emitted_rows","emitted_segments","completion","proposal","step","generation","attachment","lease","schema_origin","sampling_records","operation","native_cause","expected_bytes","presence","published","subscription","expected_codec","actual_codec","observed_clock","expected_namespace","actual_namespace","attempt","executor","resolution_reason","principal","deadline","authorization_policy","resolution_policy","protocol_status","native_effect","dependency","dependency_kind","dependency_owner"]};

function validate725(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate725.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate725.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
if(!((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((data === "object") || (data === "name")) || (data === "table")) || (data === "native_input")) || (data === "affected_rows")) || (data === "argument")) || (data === "option")) || (data === "permissions")) || (data === "scope")) || (data === "column")) || (data === "qualifier")) || (data === "constraint")) || (data === "key")) || (data === "input_row")) || (data === "first_occurrence")) || (data === "parameter")) || (data === "parameter_use")) || (data === "expected_count")) || (data === "actual_count")) || (data === "expected_type")) || (data === "actual_type")) || (data === "supplied_value")) || (data === "expected_value")) || (data === "expression")) || (data === "source_kind")) || (data === "source_basis")) || (data === "source_key")) || (data === "source_row")) || (data === "field_path")) || (data === "byte_offset")) || (data === "expected_resource")) || (data === "actual_resource")) || (data === "expected_source")) || (data === "actual_source")) || (data === "expected_revision")) || (data === "actual_revision")) || (data === "expected_schema")) || (data === "actual_schema")) || (data === "expected_policy")) || (data === "actual_policy")) || (data === "budget")) || (data === "limit")) || (data === "required")) || (data === "unit")) || (data === "completed_statements")) || (data === "emitted_rows")) || (data === "emitted_segments")) || (data === "completion")) || (data === "proposal")) || (data === "step")) || (data === "generation")) || (data === "attachment")) || (data === "lease")) || (data === "schema_origin")) || (data === "sampling_records")) || (data === "operation")) || (data === "native_cause")) || (data === "expected_bytes")) || (data === "presence")) || (data === "published")) || (data === "subscription")) || (data === "expected_codec")) || (data === "actual_codec")) || (data === "observed_clock")) || (data === "expected_namespace")) || (data === "actual_namespace")) || (data === "attempt")) || (data === "executor")) || (data === "resolution_reason")) || (data === "principal")) || (data === "deadline")) || (data === "authorization_policy")) || (data === "resolution_policy")) || (data === "protocol_status")) || (data === "native_effect")) || (data === "dependency")) || (data === "dependency_kind")) || (data === "dependency_owner"))){
validate725.errors = [{instancePath,schemaPath:"#/enum",keyword:"enum",params:{allowedValues: schema224.enum},message:"must be equal to one of the allowed values"}];
return false;
}
validate725.errors = vErrors;
return errors === 0;
}
validate725.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema226 = {"type":"string","enum":["caller","execution","schema","authority","owner"]};

function validate728(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate728.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate728.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
if(!(((((data === "caller") || (data === "execution")) || (data === "schema")) || (data === "authority")) || (data === "owner"))){
validate728.errors = [{instancePath,schemaPath:"#/enum",keyword:"enum",params:{allowedValues: schema226.enum},message:"must be equal to one of the allowed values"}];
return false;
}
validate728.errors = vErrors;
return errors === 0;
}
validate728.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema228 = {"type":"string","enum":["provided","truncated","unrecorded","unavailable","withheld","inapplicable"]};

function validate731(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate731.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate731.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
if(!((((((data === "provided") || (data === "truncated")) || (data === "unrecorded")) || (data === "unavailable")) || (data === "withheld")) || (data === "inapplicable"))){
validate731.errors = [{instancePath,schemaPath:"#/enum",keyword:"enum",params:{allowedValues: schema228.enum},message:"must be equal to one of the allowed values"}];
return false;
}
validate731.errors = vErrors;
return errors === 0;
}
validate731.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema230 = {"anyOf":[{"$ref":"#/$defs/Response/$defs/T167"},{"type":"null"}]};
const schema231 = {"oneOf":[{"type":"object","additionalProperties":false,"required":["text"],"properties":{"text":{"$ref":"#/$defs/Response/$defs/T168"}}},{"type":"object","additionalProperties":false,"required":["signed"],"properties":{"signed":{"$ref":"#/$defs/Response/$defs/T169"}}},{"type":"object","additionalProperties":false,"required":["unsigned"],"properties":{"unsigned":{"$ref":"#/$defs/Response/$defs/T153"}}},{"type":"object","additionalProperties":false,"required":["boolean"],"properties":{"boolean":{"$ref":"#/$defs/Response/$defs/T11"}}},{"type":"object","additionalProperties":false,"required":["digest"],"properties":{"digest":{"$ref":"#/$defs/Response/$defs/T20"}}},{"type":"object","additionalProperties":false,"required":["location"],"properties":{"location":{"$ref":"#/$defs/Response/$defs/T156"}}}]};
const schema232 = {"type":"string","maxLength":256};

function validate735(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate735.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(typeof data === "string"){
if(func1(data) > 256){
validate735.errors = [{instancePath,schemaPath:"#/maxLength",keyword:"maxLength",params:{limit: 256},message:"must NOT have more than 256 characters"}];
return false;
}
}
else {
validate735.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
}
validate735.errors = vErrors;
return errors === 0;
}
validate735.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema233 = {"type":"string","maxLength":20,"pattern":"^(0|-?[1-9][0-9]*)$"};
const pattern6 = new RegExp("^(0|-?[1-9][0-9]*)$", "u");

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
if(typeof data === "string"){
if(func1(data) > 20){
validate738.errors = [{instancePath,schemaPath:"#/maxLength",keyword:"maxLength",params:{limit: 20},message:"must NOT have more than 20 characters"}];
return false;
}
else {
if(!pattern6.test(data)){
validate738.errors = [{instancePath,schemaPath:"#/pattern",keyword:"pattern",params:{pattern: "^(0|-?[1-9][0-9]*)$"},message:"must match pattern \""+"^(0|-?[1-9][0-9]*)$"+"\""}];
return false;
}
}
}
else {
validate738.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
}
validate738.errors = vErrors;
return errors === 0;
}
validate738.evaluated = {"dynamicProps":false,"dynamicItems":false};


function validate734(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate734.evaluated;
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
if((data.text === undefined) && (missing0 = "text")){
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
if(!(key0 === "text")){
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
if(data.text !== undefined){
if(!(validate735(data.text, {instancePath:instancePath+"/text",parentData:data,parentDataProperty:"text",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate735.errors : vErrors.concat(validate735.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err2 = {instancePath,schemaPath:"#/oneOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
if((data.signed === undefined) && (missing1 = "signed")){
const err3 = {instancePath,schemaPath:"#/oneOf/1/required",keyword:"required",params:{missingProperty: missing1},message:"must have required property '"+missing1+"'"};
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
if(!(key1 === "signed")){
const err4 = {instancePath,schemaPath:"#/oneOf/1/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key1},message:"must NOT have additional properties"};
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
if(data.signed !== undefined){
if(!(validate738(data.signed, {instancePath:instancePath+"/signed",parentData:data,parentDataProperty:"signed",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate738.errors : vErrors.concat(validate738.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err5 = {instancePath,schemaPath:"#/oneOf/1/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
if((data.unsigned === undefined) && (missing2 = "unsigned")){
const err6 = {instancePath,schemaPath:"#/oneOf/2/required",keyword:"required",params:{missingProperty: missing2},message:"must have required property '"+missing2+"'"};
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
if(!(key2 === "unsigned")){
const err7 = {instancePath,schemaPath:"#/oneOf/2/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key2},message:"must NOT have additional properties"};
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
if(data.unsigned !== undefined){
if(!(validate695(data.unsigned, {instancePath:instancePath+"/unsigned",parentData:data,parentDataProperty:"unsigned",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate695.errors : vErrors.concat(validate695.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err8 = {instancePath,schemaPath:"#/oneOf/2/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err9 = {instancePath,schemaPath:"#/oneOf/3/required",keyword:"required",params:{missingProperty: missing3},message:"must have required property '"+missing3+"'"};
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
const err10 = {instancePath,schemaPath:"#/oneOf/3/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key3},message:"must NOT have additional properties"};
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
if(!(validate173(data.boolean, {instancePath:instancePath+"/boolean",parentData:data,parentDataProperty:"boolean",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate173.errors : vErrors.concat(validate173.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err11 = {instancePath,schemaPath:"#/oneOf/3/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
if((data.digest === undefined) && (missing4 = "digest")){
const err12 = {instancePath,schemaPath:"#/oneOf/4/required",keyword:"required",params:{missingProperty: missing4},message:"must have required property '"+missing4+"'"};
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
if(!(key4 === "digest")){
const err13 = {instancePath,schemaPath:"#/oneOf/4/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key4},message:"must NOT have additional properties"};
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
if(data.digest !== undefined){
if(!(validate204(data.digest, {instancePath:instancePath+"/digest",parentData:data,parentDataProperty:"digest",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate204.errors : vErrors.concat(validate204.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err14 = {instancePath,schemaPath:"#/oneOf/4/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
if((data.location === undefined) && (missing5 = "location")){
const err15 = {instancePath,schemaPath:"#/oneOf/5/required",keyword:"required",params:{missingProperty: missing5},message:"must have required property '"+missing5+"'"};
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
if(!(key5 === "location")){
const err16 = {instancePath,schemaPath:"#/oneOf/5/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key5},message:"must NOT have additional properties"};
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
if(data.location !== undefined){
if(!(validate705(data.location, {instancePath:instancePath+"/location",parentData:data,parentDataProperty:"location",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate705.errors : vErrors.concat(validate705.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err17 = {instancePath,schemaPath:"#/oneOf/5/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err18 = {instancePath,schemaPath:"#/oneOf",keyword:"oneOf",params:{passingSchemas: passing0},message:"must match exactly one schema in oneOf"};
if(vErrors === null){
vErrors = [err18];
}
else {
vErrors.push(err18);
}
errors++;
validate734.errors = vErrors;
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
validate734.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate734.evaluated = {"dynamicProps":true,"dynamicItems":false};


function validate733(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate733.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate734(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate734.errors : vErrors.concat(validate734.errors);
errors = vErrors.length;
}
else {
var props0 = validate734.evaluated.props;
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
validate733.errors = vErrors;
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
validate733.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate733.evaluated = {"dynamicProps":true,"dynamicItems":false};


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
if(((((data.field === undefined) && (missing0 = "field")) || ((data.origin === undefined) && (missing0 = "origin"))) || ((data.availability === undefined) && (missing0 = "availability"))) || ((data.value === undefined) && (missing0 = "value"))){
validate723.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((((key0 === "field") || (key0 === "origin")) || (key0 === "availability")) || (key0 === "value"))){
validate723.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.field !== undefined){
const _errs2 = errors;
if(!(validate725(data.field, {instancePath:instancePath+"/field",parentData:data,parentDataProperty:"field",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate725.errors : vErrors.concat(validate725.errors);
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
if(!(validate728(data.origin, {instancePath:instancePath+"/origin",parentData:data,parentDataProperty:"origin",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate728.errors : vErrors.concat(validate728.errors);
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
if(!(validate731(data.availability, {instancePath:instancePath+"/availability",parentData:data,parentDataProperty:"availability",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate731.errors : vErrors.concat(validate731.errors);
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
if(!(validate733(data.value, {instancePath:instancePath+"/value",parentData:data,parentDataProperty:"value",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate733.errors : vErrors.concat(validate733.errors);
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
validate723.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate723.errors = vErrors;
return errors === 0;
}
validate723.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate722(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate722.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate723(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate723.errors : vErrors.concat(validate723.errors);
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
validate722.errors = vErrors;
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
validate722.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate722.evaluated = {"dynamicProps":true,"dynamicItems":false};


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
if(Array.isArray(data)){
if(data.length > 16){
validate721.errors = [{instancePath,schemaPath:"#/maxItems",keyword:"maxItems",params:{limit: 16},message:"must NOT have more than 16 items"}];
return false;
}
else {
if(data.length < 16){
validate721.errors = [{instancePath,schemaPath:"#/minItems",keyword:"minItems",params:{limit: 16},message:"must NOT have fewer than 16 items"}];
return false;
}
else {
var valid0 = true;
const len0 = data.length;
for(let i0=0; i0<len0; i0++){
const _errs1 = errors;
if(!(validate722(data[i0], {instancePath:instancePath+"/" + i0,parentData:data,parentDataProperty:i0,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate722.errors : vErrors.concat(validate722.errors);
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
validate721.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "array"},message:"must be array"}];
return false;
}
}
validate721.errors = vErrors;
return errors === 0;
}
validate721.evaluated = {"items":true,"dynamicProps":false,"dynamicItems":false};

const schema235 = {"type":"array","minItems":4,"maxItems":4,"items":{"$ref":"#/$defs/Response/$defs/T171"}};
const schema236 = {"anyOf":[{"$ref":"#/$defs/Response/$defs/T172"},{"type":"null"}]};
const schema237 = {"type":"object","additionalProperties":false,"properties":{"kind":{"$ref":"#/$defs/Response/$defs/T173"},"target":{"$ref":"#/$defs/Response/$defs/T150"}},"required":["kind","target"]};
const schema238 = {"type":"string","enum":["correct_input","inspect_status","resume_exact","cancel_wait","cancel_mutation","refresh","recompile","retry_read","inspect_scope","reconcile_effect","contact_operator"]};

function validate753(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate753.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate753.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
if(!(((((((((((data === "correct_input") || (data === "inspect_status")) || (data === "resume_exact")) || (data === "cancel_wait")) || (data === "cancel_mutation")) || (data === "refresh")) || (data === "recompile")) || (data === "retry_read")) || (data === "inspect_scope")) || (data === "reconcile_effect")) || (data === "contact_operator"))){
validate753.errors = [{instancePath,schemaPath:"#/enum",keyword:"enum",params:{allowedValues: schema238.enum},message:"must be equal to one of the allowed values"}];
return false;
}
validate753.errors = vErrors;
return errors === 0;
}
validate753.evaluated = {"dynamicProps":false,"dynamicItems":false};


function validate751(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate751.evaluated;
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
validate751.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "kind") || (key0 === "target"))){
validate751.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.kind !== undefined){
const _errs2 = errors;
if(!(validate753(data.kind, {instancePath:instancePath+"/kind",parentData:data,parentDataProperty:"kind",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate753.errors : vErrors.concat(validate753.errors);
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
if(!(validate689(data.target, {instancePath:instancePath+"/target",parentData:data,parentDataProperty:"target",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate689.errors : vErrors.concat(validate689.errors);
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
validate751.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate751.errors = vErrors;
return errors === 0;
}
validate751.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate750(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate750.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate751(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate751.errors : vErrors.concat(validate751.errors);
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
validate750.errors = vErrors;
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
validate750.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate750.evaluated = {"dynamicProps":true,"dynamicItems":false};


function validate749(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate749.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(Array.isArray(data)){
if(data.length > 4){
validate749.errors = [{instancePath,schemaPath:"#/maxItems",keyword:"maxItems",params:{limit: 4},message:"must NOT have more than 4 items"}];
return false;
}
else {
if(data.length < 4){
validate749.errors = [{instancePath,schemaPath:"#/minItems",keyword:"minItems",params:{limit: 4},message:"must NOT have fewer than 4 items"}];
return false;
}
else {
var valid0 = true;
const len0 = data.length;
for(let i0=0; i0<len0; i0++){
const _errs1 = errors;
if(!(validate750(data[i0], {instancePath:instancePath+"/" + i0,parentData:data,parentDataProperty:i0,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate750.errors : vErrors.concat(validate750.errors);
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
validate749.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "array"},message:"must be array"}];
return false;
}
}
validate749.errors = vErrors;
return errors === 0;
}
validate749.evaluated = {"items":true,"dynamicProps":false,"dynamicItems":false};


function validate666(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate666.evaluated;
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
validate666.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(func4.call(schema194.properties, key0))){
validate666.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.version !== undefined){
const _errs2 = errors;
if(1 !== data.version){
validate666.errors = [{instancePath:instancePath+"/version",schemaPath:"#/properties/version/const",keyword:"const",params:{allowedValue: 1},message:"must be equal to constant"}];
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
if(!(validate668(data.definition, {instancePath:instancePath+"/definition",parentData:data,parentDataProperty:"definition",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate668.errors : vErrors.concat(validate668.errors);
errors = vErrors.length;
}
var valid0 = _errs3 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.code !== undefined){
const _errs4 = errors;
if(!(validate670(data.code, {instancePath:instancePath+"/code",parentData:data,parentDataProperty:"code",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate670.errors : vErrors.concat(validate670.errors);
errors = vErrors.length;
}
var valid0 = _errs4 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.category !== undefined){
const _errs5 = errors;
if(!(validate673(data.category, {instancePath:instancePath+"/category",parentData:data,parentDataProperty:"category",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate673.errors : vErrors.concat(validate673.errors);
errors = vErrors.length;
}
var valid0 = _errs5 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.stage !== undefined){
const _errs6 = errors;
if(!(validate676(data.stage, {instancePath:instancePath+"/stage",parentData:data,parentDataProperty:"stage",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate676.errors : vErrors.concat(validate676.errors);
errors = vErrors.length;
}
var valid0 = _errs6 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.outcome !== undefined){
const _errs7 = errors;
if(!(validate679(data.outcome, {instancePath:instancePath+"/outcome",parentData:data,parentDataProperty:"outcome",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate679.errors : vErrors.concat(validate679.errors);
errors = vErrors.length;
}
var valid0 = _errs7 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.evidence !== undefined){
const _errs8 = errors;
if(!(validate682(data.evidence, {instancePath:instancePath+"/evidence",parentData:data,parentDataProperty:"evidence",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate682.errors : vErrors.concat(validate682.errors);
errors = vErrors.length;
}
var valid0 = _errs8 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.message !== undefined){
const _errs9 = errors;
if(!(validate684(data.message, {instancePath:instancePath+"/message",parentData:data,parentDataProperty:"message",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate684.errors : vErrors.concat(validate684.errors);
errors = vErrors.length;
}
var valid0 = _errs9 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.cause !== undefined){
const _errs10 = errors;
if(!(validate686(data.cause, {instancePath:instancePath+"/cause",parentData:data,parentDataProperty:"cause",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate686.errors : vErrors.concat(validate686.errors);
errors = vErrors.length;
}
var valid0 = _errs10 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.identity !== undefined){
const _errs11 = errors;
if(!(validate689(data.identity, {instancePath:instancePath+"/identity",parentData:data,parentDataProperty:"identity",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate689.errors : vErrors.concat(validate689.errors);
errors = vErrors.length;
}
var valid0 = _errs11 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.location !== undefined){
const _errs12 = errors;
if(!(validate704(data.location, {instancePath:instancePath+"/location",parentData:data,parentDataProperty:"location",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate704.errors : vErrors.concat(validate704.errors);
errors = vErrors.length;
}
var valid0 = _errs12 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.facts !== undefined){
const _errs13 = errors;
if(!(validate721(data.facts, {instancePath:instancePath+"/facts",parentData:data,parentDataProperty:"facts",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate721.errors : vErrors.concat(validate721.errors);
errors = vErrors.length;
}
var valid0 = _errs13 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.actions !== undefined){
const _errs14 = errors;
if(!(validate749(data.actions, {instancePath:instancePath+"/actions",parentData:data,parentDataProperty:"actions",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate749.errors : vErrors.concat(validate749.errors);
errors = vErrors.length;
}
var valid0 = _errs14 === errors;
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
validate666.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate666.errors = vErrors;
return errors === 0;
}
validate666.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate665(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate665.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate666(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate666.errors : vErrors.concat(validate666.errors);
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
validate665.errors = vErrors;
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
validate665.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate665.evaluated = {"dynamicProps":true,"dynamicItems":false};


function validate644(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate644.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((((((((data.reference === undefined) && (missing0 = "reference")) || ((data.phase === undefined) && (missing0 = "phase"))) || ((data.correlation === undefined) && (missing0 = "correlation"))) || ((data.manifest === undefined) && (missing0 = "manifest"))) || ((data.collected === undefined) && (missing0 = "collected"))) || ((data.failure === undefined) && (missing0 = "failure"))) || ((data.diagnostic === undefined) && (missing0 = "diagnostic"))){
validate644.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((((((key0 === "reference") || (key0 === "phase")) || (key0 === "correlation")) || (key0 === "manifest")) || (key0 === "collected")) || (key0 === "failure")) || (key0 === "diagnostic"))){
validate644.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.reference !== undefined){
const _errs2 = errors;
if(!(validate640(data.reference, {instancePath:instancePath+"/reference",parentData:data,parentDataProperty:"reference",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate640.errors : vErrors.concat(validate640.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.phase !== undefined){
const _errs3 = errors;
if(!(validate646(data.phase, {instancePath:instancePath+"/phase",parentData:data,parentDataProperty:"phase",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate646.errors : vErrors.concat(validate646.errors);
errors = vErrors.length;
}
var valid0 = _errs3 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.correlation !== undefined){
const _errs4 = errors;
if(!(validate157(data.correlation, {instancePath:instancePath+"/correlation",parentData:data,parentDataProperty:"correlation",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate157.errors : vErrors.concat(validate157.errors);
errors = vErrors.length;
}
var valid0 = _errs4 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.manifest !== undefined){
const _errs5 = errors;
if(!(validate649(data.manifest, {instancePath:instancePath+"/manifest",parentData:data,parentDataProperty:"manifest",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate649.errors : vErrors.concat(validate649.errors);
errors = vErrors.length;
}
var valid0 = _errs5 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.collected !== undefined){
const _errs6 = errors;
if(!(validate173(data.collected, {instancePath:instancePath+"/collected",parentData:data,parentDataProperty:"collected",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate173.errors : vErrors.concat(validate173.errors);
errors = vErrors.length;
}
var valid0 = _errs6 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.failure !== undefined){
const _errs7 = errors;
if(!(validate653(data.failure, {instancePath:instancePath+"/failure",parentData:data,parentDataProperty:"failure",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate653.errors : vErrors.concat(validate653.errors);
errors = vErrors.length;
}
var valid0 = _errs7 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.diagnostic !== undefined){
const _errs8 = errors;
if(!(validate665(data.diagnostic, {instancePath:instancePath+"/diagnostic",parentData:data,parentDataProperty:"diagnostic",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate665.errors : vErrors.concat(validate665.errors);
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
validate644.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate644.errors = vErrors;
return errors === 0;
}
validate644.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


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
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate644(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate644.errors : vErrors.concat(validate644.errors);
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
validate643.errors = vErrors;
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
validate643.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate643.evaluated = {"dynamicProps":true,"dynamicItems":false};

const schema240 = {"type":"object","additionalProperties":false,"properties":{"evidence":{"$ref":"#/$defs/Response/$defs/T175"},"cells":{"$ref":"#/$defs/Response/$defs/T188"}},"required":["evidence","cells"]};
const schema241 = {"type":"object","additionalProperties":false,"properties":{"manifest":{"$ref":"#/$defs/Response/$defs/T176"},"columns":{"$ref":"#/$defs/Response/$defs/T58"},"ordinal":{"$ref":"#/$defs/Response/$defs/T5"},"rows":{"$ref":"#/$defs/Response/$defs/T8"},"ipc":{"$ref":"#/$defs/Response/$defs/T5"},"next":{"$ref":"#/$defs/Response/$defs/T56"}},"required":["manifest","columns","ordinal","rows","ipc","next"]};
const schema242 = {"type":"object","additionalProperties":false,"properties":{"job":{"$ref":"#/$defs/Response/$defs/T3"},"source":{"$ref":"#/$defs/Response/$defs/T177"},"requester":{"$ref":"#/$defs/Response/$defs/T3"},"correlation":{"$ref":"#/$defs/Response/$defs/T5"},"policy_revision":{"$ref":"#/$defs/Response/$defs/T5"},"request":{"$ref":"#/$defs/Response/$defs/T130"},"basis":{"$ref":"#/$defs/Response/$defs/T180"},"table_position":{"$ref":"#/$defs/Response/$defs/T183"},"plan":{"$ref":"#/$defs/Response/$defs/T20"},"pages":{"$ref":"#/$defs/Response/$defs/T5"},"scanned":{"$ref":"#/$defs/Response/$defs/T5"},"selected":{"$ref":"#/$defs/Response/$defs/T5"},"value_count":{"$ref":"#/$defs/Response/$defs/T5"},"segments":{"$ref":"#/$defs/Response/$defs/T5"},"rows":{"$ref":"#/$defs/Response/$defs/T5"},"bytes":{"$ref":"#/$defs/Response/$defs/T5"},"sum":{"$ref":"#/$defs/Response/$defs/T56"},"finished":{"$ref":"#/$defs/Response/$defs/T186"},"chain":{"$ref":"#/$defs/Response/$defs/T20"}},"required":["job","source","requester","correlation","policy_revision","request","basis","table_position","plan","pages","scanned","selected","value_count","segments","rows","bytes","sum","finished","chain"]};
const schema243 = {"oneOf":[{"type":"object","additionalProperties":false,"required":["native"],"properties":{"native":{"$ref":"#/$defs/Response/$defs/T178"}}},{"type":"object","additionalProperties":false,"required":["table"],"properties":{"table":{"$ref":"#/$defs/Response/$defs/T179"}}}]};
const schema244 = {"type":"object","additionalProperties":false,"properties":{"pid":{"$ref":"#/$defs/Response/$defs/T3"},"input":{"$ref":"#/$defs/Response/$defs/T3"},"index":{"$ref":"#/$defs/Response/$defs/T8"}},"required":["pid","input","index"]};

function validate768(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate768.evaluated;
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
validate768.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "pid") || (key0 === "input")) || (key0 === "index"))){
validate768.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.pid !== undefined){
const _errs2 = errors;
if(!(validate146(data.pid, {instancePath:instancePath+"/pid",parentData:data,parentDataProperty:"pid",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate146.errors : vErrors.concat(validate146.errors);
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
if(!(validate146(data.input, {instancePath:instancePath+"/input",parentData:data,parentDataProperty:"input",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate146.errors : vErrors.concat(validate146.errors);
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
if(!(validate161(data.index, {instancePath:instancePath+"/index",parentData:data,parentDataProperty:"index",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate161.errors : vErrors.concat(validate161.errors);
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
validate768.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate768.errors = vErrors;
return errors === 0;
}
validate768.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema245 = {"type":"object","additionalProperties":false,"properties":{"worker":{"$ref":"#/$defs/Response/$defs/T3"}},"required":["worker"]};

function validate773(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate773.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((data.worker === undefined) && (missing0 = "worker")){
validate773.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(key0 === "worker")){
validate773.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.worker !== undefined){
if(!(validate146(data.worker, {instancePath:instancePath+"/worker",parentData:data,parentDataProperty:"worker",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate146.errors : vErrors.concat(validate146.errors);
errors = vErrors.length;
}
}
}
}
}
else {
validate773.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate773.errors = vErrors;
return errors === 0;
}
validate773.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate767(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate767.evaluated;
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
if((data.native === undefined) && (missing0 = "native")){
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
if(!(key0 === "native")){
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
if(data.native !== undefined){
if(!(validate768(data.native, {instancePath:instancePath+"/native",parentData:data,parentDataProperty:"native",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate768.errors : vErrors.concat(validate768.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err2 = {instancePath,schemaPath:"#/oneOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
if((data.table === undefined) && (missing1 = "table")){
const err3 = {instancePath,schemaPath:"#/oneOf/1/required",keyword:"required",params:{missingProperty: missing1},message:"must have required property '"+missing1+"'"};
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
if(!(key1 === "table")){
const err4 = {instancePath,schemaPath:"#/oneOf/1/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key1},message:"must NOT have additional properties"};
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
if(data.table !== undefined){
if(!(validate773(data.table, {instancePath:instancePath+"/table",parentData:data,parentDataProperty:"table",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate773.errors : vErrors.concat(validate773.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err5 = {instancePath,schemaPath:"#/oneOf/1/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err6 = {instancePath,schemaPath:"#/oneOf",keyword:"oneOf",params:{passingSchemas: passing0},message:"must match exactly one schema in oneOf"};
if(vErrors === null){
vErrors = [err6];
}
else {
vErrors.push(err6);
}
errors++;
validate767.errors = vErrors;
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
validate767.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate767.evaluated = {"dynamicProps":true,"dynamicItems":false};

const schema246 = {"type":"object","additionalProperties":false,"properties":{"cut":{"$ref":"#/$defs/Response/$defs/T181"},"contract":{"$ref":"#/$defs/Response/$defs/T20"},"schema":{"$ref":"#/$defs/Response/$defs/T20"}},"required":["cut","contract","schema"]};
const schema247 = {"type":"object","additionalProperties":false,"properties":{"kind":{"$ref":"#/$defs/Response/$defs/T101"},"resource":{"$ref":"#/$defs/Response/$defs/T3"},"position":{"$ref":"#/$defs/Response/$defs/T182"}},"required":["kind","resource","position"]};
const schema248 = {"oneOf":[{"type":"object","additionalProperties":false,"required":["native_revision"],"properties":{"native_revision":{"$ref":"#/$defs/Response/$defs/T3"}}},{"type":"object","additionalProperties":false,"required":["table"],"properties":{"table":{"$ref":"#/$defs/Response/$defs/T20"}}}]};

function validate785(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate785.evaluated;
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
if((data.native_revision === undefined) && (missing0 = "native_revision")){
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
if(!(key0 === "native_revision")){
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
if(data.native_revision !== undefined){
if(!(validate146(data.native_revision, {instancePath:instancePath+"/native_revision",parentData:data,parentDataProperty:"native_revision",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate146.errors : vErrors.concat(validate146.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err2 = {instancePath,schemaPath:"#/oneOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
if((data.table === undefined) && (missing1 = "table")){
const err3 = {instancePath,schemaPath:"#/oneOf/1/required",keyword:"required",params:{missingProperty: missing1},message:"must have required property '"+missing1+"'"};
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
if(!(key1 === "table")){
const err4 = {instancePath,schemaPath:"#/oneOf/1/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key1},message:"must NOT have additional properties"};
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
if(data.table !== undefined){
if(!(validate204(data.table, {instancePath:instancePath+"/table",parentData:data,parentDataProperty:"table",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate204.errors : vErrors.concat(validate204.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err5 = {instancePath,schemaPath:"#/oneOf/1/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err6 = {instancePath,schemaPath:"#/oneOf",keyword:"oneOf",params:{passingSchemas: passing0},message:"must match exactly one schema in oneOf"};
if(vErrors === null){
vErrors = [err6];
}
else {
vErrors.push(err6);
}
errors++;
validate785.errors = vErrors;
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
validate785.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate785.evaluated = {"dynamicProps":true,"dynamicItems":false};


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
if((((data.kind === undefined) && (missing0 = "kind")) || ((data.resource === undefined) && (missing0 = "resource"))) || ((data.position === undefined) && (missing0 = "position"))){
validate782.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "kind") || (key0 === "resource")) || (key0 === "position"))){
validate782.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.kind !== undefined){
const _errs2 = errors;
if(!(validate522(data.kind, {instancePath:instancePath+"/kind",parentData:data,parentDataProperty:"kind",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate522.errors : vErrors.concat(validate522.errors);
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
if(!(validate146(data.resource, {instancePath:instancePath+"/resource",parentData:data,parentDataProperty:"resource",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate146.errors : vErrors.concat(validate146.errors);
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
if(!(validate785(data.position, {instancePath:instancePath+"/position",parentData:data,parentDataProperty:"position",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate785.errors : vErrors.concat(validate785.errors);
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
validate782.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate782.errors = vErrors;
return errors === 0;
}
validate782.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate781(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate781.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((((data.cut === undefined) && (missing0 = "cut")) || ((data.contract === undefined) && (missing0 = "contract"))) || ((data.schema === undefined) && (missing0 = "schema"))){
validate781.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "cut") || (key0 === "contract")) || (key0 === "schema"))){
validate781.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.cut !== undefined){
const _errs2 = errors;
if(!(validate782(data.cut, {instancePath:instancePath+"/cut",parentData:data,parentDataProperty:"cut",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate782.errors : vErrors.concat(validate782.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.contract !== undefined){
const _errs3 = errors;
if(!(validate204(data.contract, {instancePath:instancePath+"/contract",parentData:data,parentDataProperty:"contract",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate204.errors : vErrors.concat(validate204.errors);
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
if(!(validate204(data.schema, {instancePath:instancePath+"/schema",parentData:data,parentDataProperty:"schema",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate204.errors : vErrors.concat(validate204.errors);
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
validate781.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate781.errors = vErrors;
return errors === 0;
}
validate781.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema249 = {"anyOf":[{"$ref":"#/$defs/Response/$defs/T184"},{"type":"null"}]};
const schema250 = {"type":"object","additionalProperties":false,"properties":{"resource":{"$ref":"#/$defs/Response/$defs/T3"},"partition":{"$ref":"#/$defs/Response/$defs/T185"},"accepted":{"$ref":"#/$defs/Response/$defs/T185"},"contract":{"$ref":"#/$defs/Response/$defs/T20"},"schema":{"$ref":"#/$defs/Response/$defs/T20"}},"required":["resource","partition","accepted","contract","schema"]};
const schema251 = {"type":"string","pattern":"^(0|[1-9][0-9]*)$","maxLength":20};

function validate796(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate796.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(typeof data === "string"){
if(func1(data) > 20){
validate796.errors = [{instancePath,schemaPath:"#/maxLength",keyword:"maxLength",params:{limit: 20},message:"must NOT have more than 20 characters"}];
return false;
}
else {
if(!pattern4.test(data)){
validate796.errors = [{instancePath,schemaPath:"#/pattern",keyword:"pattern",params:{pattern: "^(0|[1-9][0-9]*)$"},message:"must match pattern \""+"^(0|[1-9][0-9]*)$"+"\""}];
return false;
}
}
}
else {
validate796.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
}
validate796.errors = vErrors;
return errors === 0;
}
validate796.evaluated = {"dynamicProps":false,"dynamicItems":false};


function validate794(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate794.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((((((data.resource === undefined) && (missing0 = "resource")) || ((data.partition === undefined) && (missing0 = "partition"))) || ((data.accepted === undefined) && (missing0 = "accepted"))) || ((data.contract === undefined) && (missing0 = "contract"))) || ((data.schema === undefined) && (missing0 = "schema"))){
validate794.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((((key0 === "resource") || (key0 === "partition")) || (key0 === "accepted")) || (key0 === "contract")) || (key0 === "schema"))){
validate794.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.resource !== undefined){
const _errs2 = errors;
if(!(validate146(data.resource, {instancePath:instancePath+"/resource",parentData:data,parentDataProperty:"resource",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate146.errors : vErrors.concat(validate146.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.partition !== undefined){
const _errs3 = errors;
if(!(validate796(data.partition, {instancePath:instancePath+"/partition",parentData:data,parentDataProperty:"partition",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate796.errors : vErrors.concat(validate796.errors);
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
if(!(validate796(data.accepted, {instancePath:instancePath+"/accepted",parentData:data,parentDataProperty:"accepted",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate796.errors : vErrors.concat(validate796.errors);
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
if(!(validate204(data.contract, {instancePath:instancePath+"/contract",parentData:data,parentDataProperty:"contract",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate204.errors : vErrors.concat(validate204.errors);
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
if(!(validate204(data.schema, {instancePath:instancePath+"/schema",parentData:data,parentDataProperty:"schema",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate204.errors : vErrors.concat(validate204.errors);
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
validate794.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate794.errors = vErrors;
return errors === 0;
}
validate794.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate793(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate793.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate794(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate794.errors : vErrors.concat(validate794.errors);
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
validate793.errors = vErrors;
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
validate793.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate793.evaluated = {"dynamicProps":true,"dynamicItems":false};

const schema252 = {"anyOf":[{"$ref":"#/$defs/Response/$defs/T187"},{"type":"null"}]};
const schema253 = {"type":"string","enum":["source_end","limit"]};

function validate813(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate813.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate813.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
if(!((data === "source_end") || (data === "limit"))){
validate813.errors = [{instancePath,schemaPath:"#/enum",keyword:"enum",params:{allowedValues: schema253.enum},message:"must be equal to one of the allowed values"}];
return false;
}
validate813.errors = vErrors;
return errors === 0;
}
validate813.evaluated = {"dynamicProps":false,"dynamicItems":false};


function validate812(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate812.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate813(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate813.errors : vErrors.concat(validate813.errors);
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
validate812.errors = vErrors;
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
validate812.errors = vErrors;
return errors === 0;
}
validate812.evaluated = {"dynamicProps":false,"dynamicItems":false};


function validate765(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate765.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if((((((((((((((((((((data.job === undefined) && (missing0 = "job")) || ((data.source === undefined) && (missing0 = "source"))) || ((data.requester === undefined) && (missing0 = "requester"))) || ((data.correlation === undefined) && (missing0 = "correlation"))) || ((data.policy_revision === undefined) && (missing0 = "policy_revision"))) || ((data.request === undefined) && (missing0 = "request"))) || ((data.basis === undefined) && (missing0 = "basis"))) || ((data.table_position === undefined) && (missing0 = "table_position"))) || ((data.plan === undefined) && (missing0 = "plan"))) || ((data.pages === undefined) && (missing0 = "pages"))) || ((data.scanned === undefined) && (missing0 = "scanned"))) || ((data.selected === undefined) && (missing0 = "selected"))) || ((data.value_count === undefined) && (missing0 = "value_count"))) || ((data.segments === undefined) && (missing0 = "segments"))) || ((data.rows === undefined) && (missing0 = "rows"))) || ((data.bytes === undefined) && (missing0 = "bytes"))) || ((data.sum === undefined) && (missing0 = "sum"))) || ((data.finished === undefined) && (missing0 = "finished"))) || ((data.chain === undefined) && (missing0 = "chain"))){
validate765.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(func4.call(schema242.properties, key0))){
validate765.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.job !== undefined){
const _errs2 = errors;
if(!(validate146(data.job, {instancePath:instancePath+"/job",parentData:data,parentDataProperty:"job",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate146.errors : vErrors.concat(validate146.errors);
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
if(!(validate767(data.source, {instancePath:instancePath+"/source",parentData:data,parentDataProperty:"source",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate767.errors : vErrors.concat(validate767.errors);
errors = vErrors.length;
}
var valid0 = _errs3 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.requester !== undefined){
const _errs4 = errors;
if(!(validate146(data.requester, {instancePath:instancePath+"/requester",parentData:data,parentDataProperty:"requester",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate146.errors : vErrors.concat(validate146.errors);
errors = vErrors.length;
}
var valid0 = _errs4 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.correlation !== undefined){
const _errs5 = errors;
if(!(validate157(data.correlation, {instancePath:instancePath+"/correlation",parentData:data,parentDataProperty:"correlation",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate157.errors : vErrors.concat(validate157.errors);
errors = vErrors.length;
}
var valid0 = _errs5 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.policy_revision !== undefined){
const _errs6 = errors;
if(!(validate157(data.policy_revision, {instancePath:instancePath+"/policy_revision",parentData:data,parentDataProperty:"policy_revision",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate157.errors : vErrors.concat(validate157.errors);
errors = vErrors.length;
}
var valid0 = _errs6 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.request !== undefined){
const _errs7 = errors;
if(!(validate640(data.request, {instancePath:instancePath+"/request",parentData:data,parentDataProperty:"request",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate640.errors : vErrors.concat(validate640.errors);
errors = vErrors.length;
}
var valid0 = _errs7 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.basis !== undefined){
const _errs8 = errors;
if(!(validate781(data.basis, {instancePath:instancePath+"/basis",parentData:data,parentDataProperty:"basis",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate781.errors : vErrors.concat(validate781.errors);
errors = vErrors.length;
}
var valid0 = _errs8 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.table_position !== undefined){
const _errs9 = errors;
if(!(validate793(data.table_position, {instancePath:instancePath+"/table_position",parentData:data,parentDataProperty:"table_position",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate793.errors : vErrors.concat(validate793.errors);
errors = vErrors.length;
}
var valid0 = _errs9 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.plan !== undefined){
const _errs10 = errors;
if(!(validate204(data.plan, {instancePath:instancePath+"/plan",parentData:data,parentDataProperty:"plan",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate204.errors : vErrors.concat(validate204.errors);
errors = vErrors.length;
}
var valid0 = _errs10 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.pages !== undefined){
const _errs11 = errors;
if(!(validate157(data.pages, {instancePath:instancePath+"/pages",parentData:data,parentDataProperty:"pages",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate157.errors : vErrors.concat(validate157.errors);
errors = vErrors.length;
}
var valid0 = _errs11 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.scanned !== undefined){
const _errs12 = errors;
if(!(validate157(data.scanned, {instancePath:instancePath+"/scanned",parentData:data,parentDataProperty:"scanned",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate157.errors : vErrors.concat(validate157.errors);
errors = vErrors.length;
}
var valid0 = _errs12 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.selected !== undefined){
const _errs13 = errors;
if(!(validate157(data.selected, {instancePath:instancePath+"/selected",parentData:data,parentDataProperty:"selected",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate157.errors : vErrors.concat(validate157.errors);
errors = vErrors.length;
}
var valid0 = _errs13 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.value_count !== undefined){
const _errs14 = errors;
if(!(validate157(data.value_count, {instancePath:instancePath+"/value_count",parentData:data,parentDataProperty:"value_count",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate157.errors : vErrors.concat(validate157.errors);
errors = vErrors.length;
}
var valid0 = _errs14 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.segments !== undefined){
const _errs15 = errors;
if(!(validate157(data.segments, {instancePath:instancePath+"/segments",parentData:data,parentDataProperty:"segments",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate157.errors : vErrors.concat(validate157.errors);
errors = vErrors.length;
}
var valid0 = _errs15 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.rows !== undefined){
const _errs16 = errors;
if(!(validate157(data.rows, {instancePath:instancePath+"/rows",parentData:data,parentDataProperty:"rows",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate157.errors : vErrors.concat(validate157.errors);
errors = vErrors.length;
}
var valid0 = _errs16 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.bytes !== undefined){
const _errs17 = errors;
if(!(validate157(data.bytes, {instancePath:instancePath+"/bytes",parentData:data,parentDataProperty:"bytes",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate157.errors : vErrors.concat(validate157.errors);
errors = vErrors.length;
}
var valid0 = _errs17 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.sum !== undefined){
const _errs18 = errors;
if(!(validate344(data.sum, {instancePath:instancePath+"/sum",parentData:data,parentDataProperty:"sum",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate344.errors : vErrors.concat(validate344.errors);
errors = vErrors.length;
}
var valid0 = _errs18 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.finished !== undefined){
const _errs19 = errors;
if(!(validate812(data.finished, {instancePath:instancePath+"/finished",parentData:data,parentDataProperty:"finished",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate812.errors : vErrors.concat(validate812.errors);
errors = vErrors.length;
}
var valid0 = _errs19 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.chain !== undefined){
const _errs20 = errors;
if(!(validate204(data.chain, {instancePath:instancePath+"/chain",parentData:data,parentDataProperty:"chain",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate204.errors : vErrors.concat(validate204.errors);
errors = vErrors.length;
}
var valid0 = _errs20 === errors;
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
validate765.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate765.errors = vErrors;
return errors === 0;
}
validate765.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate764(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate764.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if(((((((data.manifest === undefined) && (missing0 = "manifest")) || ((data.columns === undefined) && (missing0 = "columns"))) || ((data.ordinal === undefined) && (missing0 = "ordinal"))) || ((data.rows === undefined) && (missing0 = "rows"))) || ((data.ipc === undefined) && (missing0 = "ipc"))) || ((data.next === undefined) && (missing0 = "next"))){
validate764.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((((((key0 === "manifest") || (key0 === "columns")) || (key0 === "ordinal")) || (key0 === "rows")) || (key0 === "ipc")) || (key0 === "next"))){
validate764.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.manifest !== undefined){
const _errs2 = errors;
if(!(validate765(data.manifest, {instancePath:instancePath+"/manifest",parentData:data,parentDataProperty:"manifest",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate765.errors : vErrors.concat(validate765.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.columns !== undefined){
const _errs3 = errors;
if(!(validate362(data.columns, {instancePath:instancePath+"/columns",parentData:data,parentDataProperty:"columns",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate362.errors : vErrors.concat(validate362.errors);
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
if(!(validate157(data.ordinal, {instancePath:instancePath+"/ordinal",parentData:data,parentDataProperty:"ordinal",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate157.errors : vErrors.concat(validate157.errors);
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
if(!(validate161(data.rows, {instancePath:instancePath+"/rows",parentData:data,parentDataProperty:"rows",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate161.errors : vErrors.concat(validate161.errors);
errors = vErrors.length;
}
var valid0 = _errs5 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.ipc !== undefined){
const _errs6 = errors;
if(!(validate157(data.ipc, {instancePath:instancePath+"/ipc",parentData:data,parentDataProperty:"ipc",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate157.errors : vErrors.concat(validate157.errors);
errors = vErrors.length;
}
var valid0 = _errs6 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.next !== undefined){
const _errs7 = errors;
if(!(validate344(data.next, {instancePath:instancePath+"/next",parentData:data,parentDataProperty:"next",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate344.errors : vErrors.concat(validate344.errors);
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
validate764.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate764.errors = vErrors;
return errors === 0;
}
validate764.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema254 = {"type":"array","maxItems":8,"items":{"$ref":"#/$defs/Response/$defs/T189"}};
const schema255 = {"type":"array","maxItems":128,"items":{"$ref":"#/$defs/Response/$defs/T190"}};
const schema256 = {"oneOf":[{"type":"object","additionalProperties":false,"required":["missing"],"properties":{"missing":{"$ref":"#/$defs/Response/$defs/T22"}}},{"type":"object","additionalProperties":false,"required":["null"],"properties":{"null":{"$ref":"#/$defs/Response/$defs/T22"}}},{"type":"object","additionalProperties":false,"required":["type_error"],"properties":{"type_error":{"$ref":"#/$defs/Response/$defs/T191"}}},{"type":"object","additionalProperties":false,"required":["value"],"properties":{"value":{"$ref":"#/$defs/Response/$defs/T192"}}},{"type":"object","additionalProperties":false,"required":["conflict"],"properties":{"conflict":{"$ref":"#/$defs/Response/$defs/T207"}}}]};
const schema257 = {"type":"string","enum":["unknown","int64","uint64","float64","boolean","utf8","binary","int8","int16","int32","int128","uint8","uint16","uint32","uint128","float32","decimal","date","time","timestamp","interval","uuid","structure","list","array","map","tagged_union","json","null_value","text","character"]};

function validate830(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate830.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate830.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
if(!(((((((((((((((((((((((((((((((data === "unknown") || (data === "int64")) || (data === "uint64")) || (data === "float64")) || (data === "boolean")) || (data === "utf8")) || (data === "binary")) || (data === "int8")) || (data === "int16")) || (data === "int32")) || (data === "int128")) || (data === "uint8")) || (data === "uint16")) || (data === "uint32")) || (data === "uint128")) || (data === "float32")) || (data === "decimal")) || (data === "date")) || (data === "time")) || (data === "timestamp")) || (data === "interval")) || (data === "uuid")) || (data === "structure")) || (data === "list")) || (data === "array")) || (data === "map")) || (data === "tagged_union")) || (data === "json")) || (data === "null_value")) || (data === "text")) || (data === "character"))){
validate830.errors = [{instancePath,schemaPath:"#/enum",keyword:"enum",params:{allowedValues: schema257.enum},message:"must be equal to one of the allowed values"}];
return false;
}
validate830.errors = vErrors;
return errors === 0;
}
validate830.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema259 = {"oneOf":[{"type":"object","additionalProperties":false,"required":["atom"],"properties":{"atom":{"$ref":"#/$defs/Response/$defs/T82"}}},{"type":"object","additionalProperties":false,"required":["structure"],"properties":{"structure":{"$ref":"#/$defs/Response/$defs/T193"}}},{"type":"object","additionalProperties":false,"required":["list"],"properties":{"list":{"$ref":"#/$defs/Response/$defs/T193"}}},{"type":"object","additionalProperties":false,"required":["array"],"properties":{"array":{"$ref":"#/$defs/Response/$defs/T193"}}},{"type":"object","additionalProperties":false,"required":["map"],"properties":{"map":{"$ref":"#/$defs/Response/$defs/T202"}}},{"type":"object","additionalProperties":false,"required":["tagged_union"],"properties":{"tagged_union":{"$ref":"#/$defs/Response/$defs/T210"}}},{"type":"object","additionalProperties":false,"required":["json"],"properties":{"json":{"$ref":"#/$defs/Response/$defs/T5"}}}]};
const schema260 = {"type":"array","maxItems":65536,"items":{"$ref":"#/$defs/Response/$defs/T194"}};
const schema261 = {"oneOf":[{"type":"object","additionalProperties":false,"required":["missing"],"properties":{"missing":{"$ref":"#/$defs/Response/$defs/T195"}}},{"type":"object","additionalProperties":false,"required":["null"],"properties":{"null":{"$ref":"#/$defs/Response/$defs/T195"}}},{"type":"object","additionalProperties":false,"required":["type_error"],"properties":{"type_error":{"$ref":"#/$defs/Response/$defs/T196"}}},{"type":"object","additionalProperties":false,"required":["value"],"properties":{"value":{"$ref":"#/$defs/Response/$defs/T197"}}},{"type":"object","additionalProperties":false,"required":["conflict"],"properties":{"conflict":{"$ref":"#/$defs/Response/$defs/T207"}}}]};
const schema262 = {"type":"object","maxProperties":0};

function validate836(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate836.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
if(Object.keys(data).length > 0){
validate836.errors = [{instancePath,schemaPath:"#/maxProperties",keyword:"maxProperties",params:{limit: 0},message:"must NOT have more than 0 properties"}];
return false;
}
}
else {
validate836.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate836.errors = vErrors;
return errors === 0;
}
validate836.evaluated = {"dynamicProps":false,"dynamicItems":false};


function validate839(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate839.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate839.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
if(!(((((((((((((((((((((((((((((((data === "unknown") || (data === "int64")) || (data === "uint64")) || (data === "float64")) || (data === "boolean")) || (data === "utf8")) || (data === "binary")) || (data === "int8")) || (data === "int16")) || (data === "int32")) || (data === "int128")) || (data === "uint8")) || (data === "uint16")) || (data === "uint32")) || (data === "uint128")) || (data === "float32")) || (data === "decimal")) || (data === "date")) || (data === "time")) || (data === "timestamp")) || (data === "interval")) || (data === "uuid")) || (data === "structure")) || (data === "list")) || (data === "array")) || (data === "map")) || (data === "tagged_union")) || (data === "json")) || (data === "null_value")) || (data === "text")) || (data === "character"))){
validate839.errors = [{instancePath,schemaPath:"#/enum",keyword:"enum",params:{allowedValues: schema257.enum},message:"must be equal to one of the allowed values"}];
return false;
}
validate839.errors = vErrors;
return errors === 0;
}
validate839.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema264 = {"oneOf":[{"type":"object","additionalProperties":false,"required":["atom"],"properties":{"atom":{"$ref":"#/$defs/Response/$defs/T198"}}},{"type":"object","additionalProperties":false,"required":["structure"],"properties":{"structure":{"$ref":"#/$defs/Response/$defs/T193"}}},{"type":"object","additionalProperties":false,"required":["list"],"properties":{"list":{"$ref":"#/$defs/Response/$defs/T193"}}},{"type":"object","additionalProperties":false,"required":["array"],"properties":{"array":{"$ref":"#/$defs/Response/$defs/T193"}}},{"type":"object","additionalProperties":false,"required":["map"],"properties":{"map":{"$ref":"#/$defs/Response/$defs/T202"}}},{"type":"object","additionalProperties":false,"required":["tagged_union"],"properties":{"tagged_union":{"$ref":"#/$defs/Response/$defs/T204"}}},{"type":"object","additionalProperties":false,"required":["json"],"properties":{"json":{"$ref":"#/$defs/Response/$defs/T199"}}}]};
const schema265 = {"oneOf":[{"type":"object","additionalProperties":false,"required":["signed"],"properties":{"signed":{"$ref":"#/$defs/Response/$defs/T199"}}},{"type":"object","additionalProperties":false,"required":["unsigned"],"properties":{"unsigned":{"$ref":"#/$defs/Response/$defs/T199"}}},{"type":"object","additionalProperties":false,"required":["decimal"],"properties":{"decimal":{"$ref":"#/$defs/Response/$defs/T199"}}},{"type":"object","additionalProperties":false,"required":["float_bits"],"properties":{"float_bits":{"$ref":"#/$defs/Response/$defs/T199"}}},{"type":"object","additionalProperties":false,"required":["boolean"],"properties":{"boolean":{"$ref":"#/$defs/Response/$defs/T200"}}},{"type":"object","additionalProperties":false,"required":["utf8"],"properties":{"utf8":{"$ref":"#/$defs/Response/$defs/T199"}}},{"type":"object","additionalProperties":false,"required":["binary"],"properties":{"binary":{"$ref":"#/$defs/Response/$defs/T199"}}},{"type":"object","additionalProperties":false,"required":["date_days"],"properties":{"date_days":{"$ref":"#/$defs/Response/$defs/T199"}}},{"type":"object","additionalProperties":false,"required":["time_nanos"],"properties":{"time_nanos":{"$ref":"#/$defs/Response/$defs/T199"}}},{"type":"object","additionalProperties":false,"required":["timestamp_micros"],"properties":{"timestamp_micros":{"$ref":"#/$defs/Response/$defs/T199"}}},{"type":"object","additionalProperties":false,"required":["interval"],"properties":{"interval":{"$ref":"#/$defs/Response/$defs/T201"}}},{"type":"object","additionalProperties":false,"required":["uuid"],"properties":{"uuid":{"$ref":"#/$defs/Response/$defs/T199"}}}]};
const schema266 = {"type":"string","maxLength":131072};

function validate843(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate843.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(typeof data === "string"){
if(func1(data) > 131072){
validate843.errors = [{instancePath,schemaPath:"#/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"}];
return false;
}
}
else {
validate843.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
}
validate843.errors = vErrors;
return errors === 0;
}
validate843.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema267 = {"type":"boolean"};

function validate848(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate848.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "boolean"){
validate848.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"}];
return false;
}
validate848.errors = vErrors;
return errors === 0;
}
validate848.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema268 = {"type":"object","additionalProperties":false,"properties":{"months":{"$ref":"#/$defs/Response/$defs/T199"},"days":{"$ref":"#/$defs/Response/$defs/T199"},"nanos":{"$ref":"#/$defs/Response/$defs/T199"}},"required":["months","days","nanos"]};

function validate855(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate855.evaluated;
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
validate855.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "months") || (key0 === "days")) || (key0 === "nanos"))){
validate855.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.months !== undefined){
const _errs2 = errors;
if(!(validate843(data.months, {instancePath:instancePath+"/months",parentData:data,parentDataProperty:"months",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate843.errors : vErrors.concat(validate843.errors);
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
if(!(validate843(data.days, {instancePath:instancePath+"/days",parentData:data,parentDataProperty:"days",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate843.errors : vErrors.concat(validate843.errors);
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
if(!(validate843(data.nanos, {instancePath:instancePath+"/nanos",parentData:data,parentDataProperty:"nanos",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate843.errors : vErrors.concat(validate843.errors);
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
validate855.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate855.errors = vErrors;
return errors === 0;
}
validate855.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate842(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate842.evaluated;
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
if(!(key0 === "signed")){
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
if(data.signed !== undefined){
if(!(validate843(data.signed, {instancePath:instancePath+"/signed",parentData:data,parentDataProperty:"signed",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate843.errors : vErrors.concat(validate843.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err2 = {instancePath,schemaPath:"#/oneOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err3 = {instancePath,schemaPath:"#/oneOf/1/required",keyword:"required",params:{missingProperty: missing1},message:"must have required property '"+missing1+"'"};
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
const err4 = {instancePath,schemaPath:"#/oneOf/1/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key1},message:"must NOT have additional properties"};
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
if(!(validate843(data.unsigned, {instancePath:instancePath+"/unsigned",parentData:data,parentDataProperty:"unsigned",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate843.errors : vErrors.concat(validate843.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err5 = {instancePath,schemaPath:"#/oneOf/1/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err6 = {instancePath,schemaPath:"#/oneOf/2/required",keyword:"required",params:{missingProperty: missing2},message:"must have required property '"+missing2+"'"};
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
const err7 = {instancePath,schemaPath:"#/oneOf/2/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key2},message:"must NOT have additional properties"};
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
if(!(validate843(data.decimal, {instancePath:instancePath+"/decimal",parentData:data,parentDataProperty:"decimal",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate843.errors : vErrors.concat(validate843.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err8 = {instancePath,schemaPath:"#/oneOf/2/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err9 = {instancePath,schemaPath:"#/oneOf/3/required",keyword:"required",params:{missingProperty: missing3},message:"must have required property '"+missing3+"'"};
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
const err10 = {instancePath,schemaPath:"#/oneOf/3/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key3},message:"must NOT have additional properties"};
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
if(!(validate843(data.float_bits, {instancePath:instancePath+"/float_bits",parentData:data,parentDataProperty:"float_bits",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate843.errors : vErrors.concat(validate843.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err11 = {instancePath,schemaPath:"#/oneOf/3/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err12 = {instancePath,schemaPath:"#/oneOf/4/required",keyword:"required",params:{missingProperty: missing4},message:"must have required property '"+missing4+"'"};
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
const err13 = {instancePath,schemaPath:"#/oneOf/4/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key4},message:"must NOT have additional properties"};
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
if(!(validate848(data.boolean, {instancePath:instancePath+"/boolean",parentData:data,parentDataProperty:"boolean",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate848.errors : vErrors.concat(validate848.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err14 = {instancePath,schemaPath:"#/oneOf/4/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err15 = {instancePath,schemaPath:"#/oneOf/5/required",keyword:"required",params:{missingProperty: missing5},message:"must have required property '"+missing5+"'"};
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
const err16 = {instancePath,schemaPath:"#/oneOf/5/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key5},message:"must NOT have additional properties"};
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
if(!(validate843(data.utf8, {instancePath:instancePath+"/utf8",parentData:data,parentDataProperty:"utf8",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate843.errors : vErrors.concat(validate843.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err17 = {instancePath,schemaPath:"#/oneOf/5/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err18 = {instancePath,schemaPath:"#/oneOf/6/required",keyword:"required",params:{missingProperty: missing6},message:"must have required property '"+missing6+"'"};
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
const err19 = {instancePath,schemaPath:"#/oneOf/6/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key6},message:"must NOT have additional properties"};
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
if(!(validate843(data.binary, {instancePath:instancePath+"/binary",parentData:data,parentDataProperty:"binary",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate843.errors : vErrors.concat(validate843.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err20 = {instancePath,schemaPath:"#/oneOf/6/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err21 = {instancePath,schemaPath:"#/oneOf/7/required",keyword:"required",params:{missingProperty: missing7},message:"must have required property '"+missing7+"'"};
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
const err22 = {instancePath,schemaPath:"#/oneOf/7/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key7},message:"must NOT have additional properties"};
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
if(!(validate843(data.date_days, {instancePath:instancePath+"/date_days",parentData:data,parentDataProperty:"date_days",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate843.errors : vErrors.concat(validate843.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err23 = {instancePath,schemaPath:"#/oneOf/7/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err24 = {instancePath,schemaPath:"#/oneOf/8/required",keyword:"required",params:{missingProperty: missing8},message:"must have required property '"+missing8+"'"};
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
const err25 = {instancePath,schemaPath:"#/oneOf/8/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key8},message:"must NOT have additional properties"};
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
if(!(validate843(data.time_nanos, {instancePath:instancePath+"/time_nanos",parentData:data,parentDataProperty:"time_nanos",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate843.errors : vErrors.concat(validate843.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err26 = {instancePath,schemaPath:"#/oneOf/8/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err27 = {instancePath,schemaPath:"#/oneOf/9/required",keyword:"required",params:{missingProperty: missing9},message:"must have required property '"+missing9+"'"};
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
const err28 = {instancePath,schemaPath:"#/oneOf/9/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key9},message:"must NOT have additional properties"};
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
if(!(validate843(data.timestamp_micros, {instancePath:instancePath+"/timestamp_micros",parentData:data,parentDataProperty:"timestamp_micros",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate843.errors : vErrors.concat(validate843.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err29 = {instancePath,schemaPath:"#/oneOf/9/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err30 = {instancePath,schemaPath:"#/oneOf/10/required",keyword:"required",params:{missingProperty: missing10},message:"must have required property '"+missing10+"'"};
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
const err31 = {instancePath,schemaPath:"#/oneOf/10/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key10},message:"must NOT have additional properties"};
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
if(!(validate855(data.interval, {instancePath:instancePath+"/interval",parentData:data,parentDataProperty:"interval",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate855.errors : vErrors.concat(validate855.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err32 = {instancePath,schemaPath:"#/oneOf/10/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err33 = {instancePath,schemaPath:"#/oneOf/11/required",keyword:"required",params:{missingProperty: missing11},message:"must have required property '"+missing11+"'"};
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
const err34 = {instancePath,schemaPath:"#/oneOf/11/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key11},message:"must NOT have additional properties"};
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
if(!(validate843(data.uuid, {instancePath:instancePath+"/uuid",parentData:data,parentDataProperty:"uuid",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate843.errors : vErrors.concat(validate843.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err35 = {instancePath,schemaPath:"#/oneOf/11/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err36 = {instancePath,schemaPath:"#/oneOf",keyword:"oneOf",params:{passingSchemas: passing0},message:"must match exactly one schema in oneOf"};
if(vErrors === null){
vErrors = [err36];
}
else {
vErrors.push(err36);
}
errors++;
validate842.errors = vErrors;
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
validate842.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate842.evaluated = {"dynamicProps":true,"dynamicItems":false};

const schema269 = {"type":"array","maxItems":65536,"items":{"$ref":"#/$defs/Response/$defs/T203"}};
const schema270 = {"type":"object","additionalProperties":false,"properties":{"key":{"$ref":"#/$defs/Response/$defs/T198"},"value":{"$ref":"#/$defs/Response/$defs/T194"}},"required":["key","value"]};
const wrapper11 = {validate: validate835};

function validate863(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate863.evaluated;
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
validate863.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "key") || (key0 === "value"))){
validate863.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.key !== undefined){
const _errs2 = errors;
if(!(validate842(data.key, {instancePath:instancePath+"/key",parentData:data,parentDataProperty:"key",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate842.errors : vErrors.concat(validate842.errors);
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
if(!(wrapper11.validate(data.value, {instancePath:instancePath+"/value",parentData:data,parentDataProperty:"value",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? wrapper11.validate.errors : vErrors.concat(wrapper11.validate.errors);
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
validate863.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate863.errors = vErrors;
return errors === 0;
}
validate863.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate862(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate862.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(Array.isArray(data)){
if(data.length > 65536){
validate862.errors = [{instancePath,schemaPath:"#/maxItems",keyword:"maxItems",params:{limit: 65536},message:"must NOT have more than 65536 items"}];
return false;
}
else {
var valid0 = true;
const len0 = data.length;
for(let i0=0; i0<len0; i0++){
const _errs1 = errors;
if(!(validate863(data[i0], {instancePath:instancePath+"/" + i0,parentData:data,parentDataProperty:i0,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate863.errors : vErrors.concat(validate863.errors);
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
validate862.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "array"},message:"must be array"}];
return false;
}
}
validate862.errors = vErrors;
return errors === 0;
}
validate862.evaluated = {"items":true,"dynamicProps":false,"dynamicItems":false};

const schema271 = {"type":"object","additionalProperties":false,"properties":{"index":{"$ref":"#/$defs/Response/$defs/T205"},"value":{"$ref":"#/$defs/Response/$defs/T206"}},"required":["index","value"]};

function validate868(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate868.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(!(((typeof data == "number") && (!(data % 1) && !isNaN(data))) && (isFinite(data)))){
validate868.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "integer"},message:"must be integer"}];
return false;
}
if(errors === 0){
if((typeof data == "number") && (isFinite(data))){
if(data > 255 || isNaN(data)){
validate868.errors = [{instancePath,schemaPath:"#/maximum",keyword:"maximum",params:{comparison: "<=", limit: 255},message:"must be <= 255"}];
return false;
}
else {
if(data < 0 || isNaN(data)){
validate868.errors = [{instancePath,schemaPath:"#/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"}];
return false;
}
}
}
}
validate868.errors = vErrors;
return errors === 0;
}
validate868.evaluated = {"dynamicProps":false,"dynamicItems":false};


function validate867(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate867.evaluated;
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
validate867.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "index") || (key0 === "value"))){
validate867.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.index !== undefined){
const _errs2 = errors;
if(!(validate868(data.index, {instancePath:instancePath+"/index",parentData:data,parentDataProperty:"index",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate868.errors : vErrors.concat(validate868.errors);
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
if(!(wrapper11.validate(data.value, {instancePath:instancePath+"/value",parentData:data,parentDataProperty:"value",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? wrapper11.validate.errors : vErrors.concat(wrapper11.validate.errors);
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
validate867.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate867.errors = vErrors;
return errors === 0;
}
validate867.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const wrapper8 = {validate: validate834};

function validate841(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate841.evaluated;
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
if(!(key0 === "atom")){
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
if(data.atom !== undefined){
if(!(validate842(data.atom, {instancePath:instancePath+"/atom",parentData:data,parentDataProperty:"atom",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate842.errors : vErrors.concat(validate842.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err2 = {instancePath,schemaPath:"#/oneOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err3 = {instancePath,schemaPath:"#/oneOf/1/required",keyword:"required",params:{missingProperty: missing1},message:"must have required property '"+missing1+"'"};
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
const err4 = {instancePath,schemaPath:"#/oneOf/1/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key1},message:"must NOT have additional properties"};
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
if(!(wrapper8.validate(data.structure, {instancePath:instancePath+"/structure",parentData:data,parentDataProperty:"structure",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? wrapper8.validate.errors : vErrors.concat(wrapper8.validate.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err5 = {instancePath,schemaPath:"#/oneOf/1/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err6 = {instancePath,schemaPath:"#/oneOf/2/required",keyword:"required",params:{missingProperty: missing2},message:"must have required property '"+missing2+"'"};
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
const err7 = {instancePath,schemaPath:"#/oneOf/2/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key2},message:"must NOT have additional properties"};
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
if(!(wrapper8.validate(data.list, {instancePath:instancePath+"/list",parentData:data,parentDataProperty:"list",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? wrapper8.validate.errors : vErrors.concat(wrapper8.validate.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err8 = {instancePath,schemaPath:"#/oneOf/2/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err9 = {instancePath,schemaPath:"#/oneOf/3/required",keyword:"required",params:{missingProperty: missing3},message:"must have required property '"+missing3+"'"};
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
const err10 = {instancePath,schemaPath:"#/oneOf/3/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key3},message:"must NOT have additional properties"};
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
if(!(wrapper8.validate(data.array, {instancePath:instancePath+"/array",parentData:data,parentDataProperty:"array",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? wrapper8.validate.errors : vErrors.concat(wrapper8.validate.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err11 = {instancePath,schemaPath:"#/oneOf/3/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err12 = {instancePath,schemaPath:"#/oneOf/4/required",keyword:"required",params:{missingProperty: missing4},message:"must have required property '"+missing4+"'"};
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
const err13 = {instancePath,schemaPath:"#/oneOf/4/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key4},message:"must NOT have additional properties"};
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
if(!(validate862(data.map, {instancePath:instancePath+"/map",parentData:data,parentDataProperty:"map",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate862.errors : vErrors.concat(validate862.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err14 = {instancePath,schemaPath:"#/oneOf/4/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err15 = {instancePath,schemaPath:"#/oneOf/5/required",keyword:"required",params:{missingProperty: missing5},message:"must have required property '"+missing5+"'"};
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
const err16 = {instancePath,schemaPath:"#/oneOf/5/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key5},message:"must NOT have additional properties"};
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
if(!(validate867(data.tagged_union, {instancePath:instancePath+"/tagged_union",parentData:data,parentDataProperty:"tagged_union",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate867.errors : vErrors.concat(validate867.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err17 = {instancePath,schemaPath:"#/oneOf/5/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err18 = {instancePath,schemaPath:"#/oneOf/6/required",keyword:"required",params:{missingProperty: missing6},message:"must have required property '"+missing6+"'"};
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
const err19 = {instancePath,schemaPath:"#/oneOf/6/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key6},message:"must NOT have additional properties"};
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
if(!(validate843(data.json, {instancePath:instancePath+"/json",parentData:data,parentDataProperty:"json",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate843.errors : vErrors.concat(validate843.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err20 = {instancePath,schemaPath:"#/oneOf/6/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err21 = {instancePath,schemaPath:"#/oneOf",keyword:"oneOf",params:{passingSchemas: passing0},message:"must match exactly one schema in oneOf"};
if(vErrors === null){
vErrors = [err21];
}
else {
vErrors.push(err21);
}
errors++;
validate841.errors = vErrors;
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
validate841.errors = vErrors;
evaluated0.props = props1;
return errors === 0;
}
validate841.evaluated = {"dynamicProps":true,"dynamicItems":false};

const schema273 = {"type":"array","maxItems":65536,"items":{"$ref":"#/$defs/Response/$defs/T208"}};
const schema274 = {"type":"object","additionalProperties":false,"properties":{"counter":{"$ref":"#/$defs/Response/$defs/T199"},"replica":{"$ref":"#/$defs/Response/$defs/T199"},"value":{"$ref":"#/$defs/Response/$defs/T209"}},"required":["counter","replica","value"]};
const schema275 = {"oneOf":[{"type":"object","additionalProperties":false,"required":["null"],"properties":{"null":{"$ref":"#/$defs/Response/$defs/T195"}}},{"type":"object","additionalProperties":false,"required":["type_error"],"properties":{"type_error":{"$ref":"#/$defs/Response/$defs/T196"}}},{"type":"object","additionalProperties":false,"required":["value"],"properties":{"value":{"$ref":"#/$defs/Response/$defs/T197"}}}]};

function validate877(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate877.evaluated;
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
if(!(key0 === "null")){
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
if(data.null !== undefined){
if(!(validate836(data.null, {instancePath:instancePath+"/null",parentData:data,parentDataProperty:"null",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate836.errors : vErrors.concat(validate836.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err2 = {instancePath,schemaPath:"#/oneOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err3 = {instancePath,schemaPath:"#/oneOf/1/required",keyword:"required",params:{missingProperty: missing1},message:"must have required property '"+missing1+"'"};
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
const err4 = {instancePath,schemaPath:"#/oneOf/1/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key1},message:"must NOT have additional properties"};
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
if(!(validate839(data.type_error, {instancePath:instancePath+"/type_error",parentData:data,parentDataProperty:"type_error",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate839.errors : vErrors.concat(validate839.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err5 = {instancePath,schemaPath:"#/oneOf/1/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err6 = {instancePath,schemaPath:"#/oneOf/2/required",keyword:"required",params:{missingProperty: missing2},message:"must have required property '"+missing2+"'"};
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
const err7 = {instancePath,schemaPath:"#/oneOf/2/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key2},message:"must NOT have additional properties"};
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
if(!(validate841(data.value, {instancePath:instancePath+"/value",parentData:data,parentDataProperty:"value",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate841.errors : vErrors.concat(validate841.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err8 = {instancePath,schemaPath:"#/oneOf/2/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err9 = {instancePath,schemaPath:"#/oneOf",keyword:"oneOf",params:{passingSchemas: passing0},message:"must match exactly one schema in oneOf"};
if(vErrors === null){
vErrors = [err9];
}
else {
vErrors.push(err9);
}
errors++;
validate877.errors = vErrors;
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
validate877.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate877.evaluated = {"dynamicProps":true,"dynamicItems":false};


function validate874(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate874.evaluated;
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
validate874.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "counter") || (key0 === "replica")) || (key0 === "value"))){
validate874.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.counter !== undefined){
const _errs2 = errors;
if(!(validate843(data.counter, {instancePath:instancePath+"/counter",parentData:data,parentDataProperty:"counter",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate843.errors : vErrors.concat(validate843.errors);
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
if(!(validate843(data.replica, {instancePath:instancePath+"/replica",parentData:data,parentDataProperty:"replica",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate843.errors : vErrors.concat(validate843.errors);
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
if(!(validate877(data.value, {instancePath:instancePath+"/value",parentData:data,parentDataProperty:"value",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate877.errors : vErrors.concat(validate877.errors);
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
validate874.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate874.errors = vErrors;
return errors === 0;
}
validate874.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate873(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate873.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(Array.isArray(data)){
if(data.length > 65536){
validate873.errors = [{instancePath,schemaPath:"#/maxItems",keyword:"maxItems",params:{limit: 65536},message:"must NOT have more than 65536 items"}];
return false;
}
else {
var valid0 = true;
const len0 = data.length;
for(let i0=0; i0<len0; i0++){
const _errs1 = errors;
if(!(validate874(data[i0], {instancePath:instancePath+"/" + i0,parentData:data,parentDataProperty:i0,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate874.errors : vErrors.concat(validate874.errors);
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
validate873.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "array"},message:"must be array"}];
return false;
}
}
validate873.errors = vErrors;
return errors === 0;
}
validate873.evaluated = {"items":true,"dynamicProps":false,"dynamicItems":false};


function validate835(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate835.evaluated;
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
if(!(key0 === "missing")){
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
if(data.missing !== undefined){
if(!(validate836(data.missing, {instancePath:instancePath+"/missing",parentData:data,parentDataProperty:"missing",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate836.errors : vErrors.concat(validate836.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err2 = {instancePath,schemaPath:"#/oneOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err3 = {instancePath,schemaPath:"#/oneOf/1/required",keyword:"required",params:{missingProperty: missing1},message:"must have required property '"+missing1+"'"};
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
const err4 = {instancePath,schemaPath:"#/oneOf/1/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key1},message:"must NOT have additional properties"};
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
if(!(validate836(data.null, {instancePath:instancePath+"/null",parentData:data,parentDataProperty:"null",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate836.errors : vErrors.concat(validate836.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err5 = {instancePath,schemaPath:"#/oneOf/1/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err6 = {instancePath,schemaPath:"#/oneOf/2/required",keyword:"required",params:{missingProperty: missing2},message:"must have required property '"+missing2+"'"};
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
const err7 = {instancePath,schemaPath:"#/oneOf/2/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key2},message:"must NOT have additional properties"};
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
if(!(validate839(data.type_error, {instancePath:instancePath+"/type_error",parentData:data,parentDataProperty:"type_error",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate839.errors : vErrors.concat(validate839.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err8 = {instancePath,schemaPath:"#/oneOf/2/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err9 = {instancePath,schemaPath:"#/oneOf/3/required",keyword:"required",params:{missingProperty: missing3},message:"must have required property '"+missing3+"'"};
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
const err10 = {instancePath,schemaPath:"#/oneOf/3/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key3},message:"must NOT have additional properties"};
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
if(!(validate841(data.value, {instancePath:instancePath+"/value",parentData:data,parentDataProperty:"value",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate841.errors : vErrors.concat(validate841.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err11 = {instancePath,schemaPath:"#/oneOf/3/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err12 = {instancePath,schemaPath:"#/oneOf/4/required",keyword:"required",params:{missingProperty: missing4},message:"must have required property '"+missing4+"'"};
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
const err13 = {instancePath,schemaPath:"#/oneOf/4/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key4},message:"must NOT have additional properties"};
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
if(!(validate873(data.conflict, {instancePath:instancePath+"/conflict",parentData:data,parentDataProperty:"conflict",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate873.errors : vErrors.concat(validate873.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err14 = {instancePath,schemaPath:"#/oneOf/4/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err15 = {instancePath,schemaPath:"#/oneOf",keyword:"oneOf",params:{passingSchemas: passing0},message:"must match exactly one schema in oneOf"};
if(vErrors === null){
vErrors = [err15];
}
else {
vErrors.push(err15);
}
errors++;
validate835.errors = vErrors;
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
validate835.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate835.evaluated = {"dynamicProps":true,"dynamicItems":false};


function validate834(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate834.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(Array.isArray(data)){
if(data.length > 65536){
validate834.errors = [{instancePath,schemaPath:"#/maxItems",keyword:"maxItems",params:{limit: 65536},message:"must NOT have more than 65536 items"}];
return false;
}
else {
var valid0 = true;
const len0 = data.length;
for(let i0=0; i0<len0; i0++){
const _errs1 = errors;
if(!(validate835(data[i0], {instancePath:instancePath+"/" + i0,parentData:data,parentDataProperty:i0,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate835.errors : vErrors.concat(validate835.errors);
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
validate834.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "array"},message:"must be array"}];
return false;
}
}
validate834.errors = vErrors;
return errors === 0;
}
validate834.evaluated = {"items":true,"dynamicProps":false,"dynamicItems":false};

const schema276 = {"type":"object","additionalProperties":false,"properties":{"index":{"$ref":"#/$defs/Response/$defs/T8"},"value":{"$ref":"#/$defs/Response/$defs/T211"}},"required":["index","value"]};
const wrapper13 = {validate: validate826};

function validate889(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate889.evaluated;
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
validate889.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "index") || (key0 === "value"))){
validate889.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.index !== undefined){
const _errs2 = errors;
if(!(validate161(data.index, {instancePath:instancePath+"/index",parentData:data,parentDataProperty:"index",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate161.errors : vErrors.concat(validate161.errors);
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
if(!(wrapper13.validate(data.value, {instancePath:instancePath+"/value",parentData:data,parentDataProperty:"value",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? wrapper13.validate.errors : vErrors.concat(wrapper13.validate.errors);
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
validate889.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate889.errors = vErrors;
return errors === 0;
}
validate889.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate832(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate832.evaluated;
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
if(!(key0 === "atom")){
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
if(data.atom !== undefined){
if(!(validate441(data.atom, {instancePath:instancePath+"/atom",parentData:data,parentDataProperty:"atom",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate441.errors : vErrors.concat(validate441.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err2 = {instancePath,schemaPath:"#/oneOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err3 = {instancePath,schemaPath:"#/oneOf/1/required",keyword:"required",params:{missingProperty: missing1},message:"must have required property '"+missing1+"'"};
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
const err4 = {instancePath,schemaPath:"#/oneOf/1/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key1},message:"must NOT have additional properties"};
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
if(!(validate834(data.structure, {instancePath:instancePath+"/structure",parentData:data,parentDataProperty:"structure",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate834.errors : vErrors.concat(validate834.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err5 = {instancePath,schemaPath:"#/oneOf/1/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err6 = {instancePath,schemaPath:"#/oneOf/2/required",keyword:"required",params:{missingProperty: missing2},message:"must have required property '"+missing2+"'"};
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
const err7 = {instancePath,schemaPath:"#/oneOf/2/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key2},message:"must NOT have additional properties"};
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
if(!(validate834(data.list, {instancePath:instancePath+"/list",parentData:data,parentDataProperty:"list",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate834.errors : vErrors.concat(validate834.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err8 = {instancePath,schemaPath:"#/oneOf/2/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err9 = {instancePath,schemaPath:"#/oneOf/3/required",keyword:"required",params:{missingProperty: missing3},message:"must have required property '"+missing3+"'"};
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
const err10 = {instancePath,schemaPath:"#/oneOf/3/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key3},message:"must NOT have additional properties"};
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
if(!(validate834(data.array, {instancePath:instancePath+"/array",parentData:data,parentDataProperty:"array",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate834.errors : vErrors.concat(validate834.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err11 = {instancePath,schemaPath:"#/oneOf/3/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err12 = {instancePath,schemaPath:"#/oneOf/4/required",keyword:"required",params:{missingProperty: missing4},message:"must have required property '"+missing4+"'"};
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
const err13 = {instancePath,schemaPath:"#/oneOf/4/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key4},message:"must NOT have additional properties"};
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
if(!(validate862(data.map, {instancePath:instancePath+"/map",parentData:data,parentDataProperty:"map",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate862.errors : vErrors.concat(validate862.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err14 = {instancePath,schemaPath:"#/oneOf/4/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err15 = {instancePath,schemaPath:"#/oneOf/5/required",keyword:"required",params:{missingProperty: missing5},message:"must have required property '"+missing5+"'"};
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
const err16 = {instancePath,schemaPath:"#/oneOf/5/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key5},message:"must NOT have additional properties"};
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
if(!(validate889(data.tagged_union, {instancePath:instancePath+"/tagged_union",parentData:data,parentDataProperty:"tagged_union",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate889.errors : vErrors.concat(validate889.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err17 = {instancePath,schemaPath:"#/oneOf/5/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err18 = {instancePath,schemaPath:"#/oneOf/6/required",keyword:"required",params:{missingProperty: missing6},message:"must have required property '"+missing6+"'"};
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
const err19 = {instancePath,schemaPath:"#/oneOf/6/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key6},message:"must NOT have additional properties"};
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
if(!(validate157(data.json, {instancePath:instancePath+"/json",parentData:data,parentDataProperty:"json",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate157.errors : vErrors.concat(validate157.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err20 = {instancePath,schemaPath:"#/oneOf/6/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err21 = {instancePath,schemaPath:"#/oneOf",keyword:"oneOf",params:{passingSchemas: passing0},message:"must match exactly one schema in oneOf"};
if(vErrors === null){
vErrors = [err21];
}
else {
vErrors.push(err21);
}
errors++;
validate832.errors = vErrors;
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
validate832.errors = vErrors;
evaluated0.props = props1;
return errors === 0;
}
validate832.evaluated = {"dynamicProps":true,"dynamicItems":false};


function validate826(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate826.evaluated;
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
if(!(key0 === "missing")){
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
if(data.missing !== undefined){
if(!(validate211(data.missing, {instancePath:instancePath+"/missing",parentData:data,parentDataProperty:"missing",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate211.errors : vErrors.concat(validate211.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err2 = {instancePath,schemaPath:"#/oneOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err3 = {instancePath,schemaPath:"#/oneOf/1/required",keyword:"required",params:{missingProperty: missing1},message:"must have required property '"+missing1+"'"};
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
const err4 = {instancePath,schemaPath:"#/oneOf/1/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key1},message:"must NOT have additional properties"};
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
if(!(validate211(data.null, {instancePath:instancePath+"/null",parentData:data,parentDataProperty:"null",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate211.errors : vErrors.concat(validate211.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err5 = {instancePath,schemaPath:"#/oneOf/1/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err6 = {instancePath,schemaPath:"#/oneOf/2/required",keyword:"required",params:{missingProperty: missing2},message:"must have required property '"+missing2+"'"};
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
const err7 = {instancePath,schemaPath:"#/oneOf/2/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key2},message:"must NOT have additional properties"};
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
if(!(validate830(data.type_error, {instancePath:instancePath+"/type_error",parentData:data,parentDataProperty:"type_error",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate830.errors : vErrors.concat(validate830.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err8 = {instancePath,schemaPath:"#/oneOf/2/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err9 = {instancePath,schemaPath:"#/oneOf/3/required",keyword:"required",params:{missingProperty: missing3},message:"must have required property '"+missing3+"'"};
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
const err10 = {instancePath,schemaPath:"#/oneOf/3/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key3},message:"must NOT have additional properties"};
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
if(!(validate832(data.value, {instancePath:instancePath+"/value",parentData:data,parentDataProperty:"value",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate832.errors : vErrors.concat(validate832.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err11 = {instancePath,schemaPath:"#/oneOf/3/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err12 = {instancePath,schemaPath:"#/oneOf/4/required",keyword:"required",params:{missingProperty: missing4},message:"must have required property '"+missing4+"'"};
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
const err13 = {instancePath,schemaPath:"#/oneOf/4/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key4},message:"must NOT have additional properties"};
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
if(!(validate873(data.conflict, {instancePath:instancePath+"/conflict",parentData:data,parentDataProperty:"conflict",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate873.errors : vErrors.concat(validate873.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err14 = {instancePath,schemaPath:"#/oneOf/4/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err15 = {instancePath,schemaPath:"#/oneOf",keyword:"oneOf",params:{passingSchemas: passing0},message:"must match exactly one schema in oneOf"};
if(vErrors === null){
vErrors = [err15];
}
else {
vErrors.push(err15);
}
errors++;
validate826.errors = vErrors;
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
validate826.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate826.evaluated = {"dynamicProps":true,"dynamicItems":false};


function validate825(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate825.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(Array.isArray(data)){
if(data.length > 128){
validate825.errors = [{instancePath,schemaPath:"#/maxItems",keyword:"maxItems",params:{limit: 128},message:"must NOT have more than 128 items"}];
return false;
}
else {
var valid0 = true;
const len0 = data.length;
for(let i0=0; i0<len0; i0++){
const _errs1 = errors;
if(!(validate826(data[i0], {instancePath:instancePath+"/" + i0,parentData:data,parentDataProperty:i0,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate826.errors : vErrors.concat(validate826.errors);
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
validate825.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "array"},message:"must be array"}];
return false;
}
}
validate825.errors = vErrors;
return errors === 0;
}
validate825.evaluated = {"items":true,"dynamicProps":false,"dynamicItems":false};


function validate824(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate824.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(Array.isArray(data)){
if(data.length > 8){
validate824.errors = [{instancePath,schemaPath:"#/maxItems",keyword:"maxItems",params:{limit: 8},message:"must NOT have more than 8 items"}];
return false;
}
else {
var valid0 = true;
const len0 = data.length;
for(let i0=0; i0<len0; i0++){
const _errs1 = errors;
if(!(validate825(data[i0], {instancePath:instancePath+"/" + i0,parentData:data,parentDataProperty:i0,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate825.errors : vErrors.concat(validate825.errors);
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
validate824.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "array"},message:"must be array"}];
return false;
}
}
validate824.errors = vErrors;
return errors === 0;
}
validate824.evaluated = {"items":true,"dynamicProps":false,"dynamicItems":false};


function validate763(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate763.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing0;
if(((data.evidence === undefined) && (missing0 = "evidence")) || ((data.cells === undefined) && (missing0 = "cells"))){
validate763.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "evidence") || (key0 === "cells"))){
validate763.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.evidence !== undefined){
const _errs2 = errors;
if(!(validate764(data.evidence, {instancePath:instancePath+"/evidence",parentData:data,parentDataProperty:"evidence",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate764.errors : vErrors.concat(validate764.errors);
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
if(!(validate824(data.cells, {instancePath:instancePath+"/cells",parentData:data,parentDataProperty:"cells",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate824.errors : vErrors.concat(validate824.errors);
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
validate763.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate763.errors = vErrors;
return errors === 0;
}
validate763.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema277 = {"anyOf":[{"$ref":"#/$defs/Response/$defs/T213"},{"type":"null"}]};
const schema278 = {"type":"object","additionalProperties":false,"properties":{"generation":{"$ref":"#/$defs/Response/$defs/T5"},"limit":{"$ref":"#/$defs/Response/$defs/T8"},"starts":{"$ref":"#/$defs/Response/$defs/T8"},"enabled":{"$ref":"#/$defs/Response/$defs/T11"},"contract":{"$ref":"#/$defs/Response/$defs/T20"},"budgets":{"$ref":"#/$defs/Response/$defs/T55"},"namespaces":{"$ref":"#/$defs/Response/$defs/T214"}},"required":["generation","limit","starts","enabled","contract","budgets","namespaces"]};
const schema279 = {"type":"array","minItems":8,"maxItems":8,"items":{"$ref":"#/$defs/Response/$defs/T5"}};

function validate907(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate907.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(Array.isArray(data)){
if(data.length > 8){
validate907.errors = [{instancePath,schemaPath:"#/maxItems",keyword:"maxItems",params:{limit: 8},message:"must NOT have more than 8 items"}];
return false;
}
else {
if(data.length < 8){
validate907.errors = [{instancePath,schemaPath:"#/minItems",keyword:"minItems",params:{limit: 8},message:"must NOT have fewer than 8 items"}];
return false;
}
else {
var valid0 = true;
const len0 = data.length;
for(let i0=0; i0<len0; i0++){
const _errs1 = errors;
if(!(validate157(data[i0], {instancePath:instancePath+"/" + i0,parentData:data,parentDataProperty:i0,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate157.errors : vErrors.concat(validate157.errors);
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
validate907.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "array"},message:"must be array"}];
return false;
}
}
validate907.errors = vErrors;
return errors === 0;
}
validate907.evaluated = {"items":true,"dynamicProps":false,"dynamicItems":false};


function validate900(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate900.evaluated;
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
validate900.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((((((key0 === "generation") || (key0 === "limit")) || (key0 === "starts")) || (key0 === "enabled")) || (key0 === "contract")) || (key0 === "budgets")) || (key0 === "namespaces"))){
validate900.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.generation !== undefined){
const _errs2 = errors;
if(!(validate157(data.generation, {instancePath:instancePath+"/generation",parentData:data,parentDataProperty:"generation",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate157.errors : vErrors.concat(validate157.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.limit !== undefined){
const _errs3 = errors;
if(!(validate161(data.limit, {instancePath:instancePath+"/limit",parentData:data,parentDataProperty:"limit",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate161.errors : vErrors.concat(validate161.errors);
errors = vErrors.length;
}
var valid0 = _errs3 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.starts !== undefined){
const _errs4 = errors;
if(!(validate161(data.starts, {instancePath:instancePath+"/starts",parentData:data,parentDataProperty:"starts",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate161.errors : vErrors.concat(validate161.errors);
errors = vErrors.length;
}
var valid0 = _errs4 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.enabled !== undefined){
const _errs5 = errors;
if(!(validate173(data.enabled, {instancePath:instancePath+"/enabled",parentData:data,parentDataProperty:"enabled",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate173.errors : vErrors.concat(validate173.errors);
errors = vErrors.length;
}
var valid0 = _errs5 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.contract !== undefined){
const _errs6 = errors;
if(!(validate204(data.contract, {instancePath:instancePath+"/contract",parentData:data,parentDataProperty:"contract",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate204.errors : vErrors.concat(validate204.errors);
errors = vErrors.length;
}
var valid0 = _errs6 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.budgets !== undefined){
const _errs7 = errors;
if(!(validate339(data.budgets, {instancePath:instancePath+"/budgets",parentData:data,parentDataProperty:"budgets",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate339.errors : vErrors.concat(validate339.errors);
errors = vErrors.length;
}
var valid0 = _errs7 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.namespaces !== undefined){
const _errs8 = errors;
if(!(validate907(data.namespaces, {instancePath:instancePath+"/namespaces",parentData:data,parentDataProperty:"namespaces",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate907.errors : vErrors.concat(validate907.errors);
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
validate900.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate900.errors = vErrors;
return errors === 0;
}
validate900.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate899(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate899.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate900(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate900.errors : vErrors.concat(validate900.errors);
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
validate899.errors = vErrors;
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
validate899.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate899.evaluated = {"dynamicProps":true,"dynamicItems":false};


function validate143(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate143.evaluated;
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
if(!(validate144(data.description, {instancePath:instancePath+"/description",parentData:data,parentDataProperty:"description",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate144.errors : vErrors.concat(validate144.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err2 = {instancePath,schemaPath:"#/oneOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
if((data.sql_capabilities === undefined) && (missing1 = "sql_capabilities")){
const err3 = {instancePath,schemaPath:"#/oneOf/1/required",keyword:"required",params:{missingProperty: missing1},message:"must have required property '"+missing1+"'"};
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
if(!(key1 === "sql_capabilities")){
const err4 = {instancePath,schemaPath:"#/oneOf/1/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key1},message:"must NOT have additional properties"};
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
if(data.sql_capabilities !== undefined){
if(!(validate371(data.sql_capabilities, {instancePath:instancePath+"/sql_capabilities",parentData:data,parentDataProperty:"sql_capabilities",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate371.errors : vErrors.concat(validate371.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err5 = {instancePath,schemaPath:"#/oneOf/1/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
if((data.suggestions === undefined) && (missing2 = "suggestions")){
const err6 = {instancePath,schemaPath:"#/oneOf/2/required",keyword:"required",params:{missingProperty: missing2},message:"must have required property '"+missing2+"'"};
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
if(!(key2 === "suggestions")){
const err7 = {instancePath,schemaPath:"#/oneOf/2/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key2},message:"must NOT have additional properties"};
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
if(data.suggestions !== undefined){
if(!(validate377(data.suggestions, {instancePath:instancePath+"/suggestions",parentData:data,parentDataProperty:"suggestions",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate377.errors : vErrors.concat(validate377.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err8 = {instancePath,schemaPath:"#/oneOf/2/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
if((data.assistance === undefined) && (missing3 = "assistance")){
const err9 = {instancePath,schemaPath:"#/oneOf/3/required",keyword:"required",params:{missingProperty: missing3},message:"must have required property '"+missing3+"'"};
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
if(!(key3 === "assistance")){
const err10 = {instancePath,schemaPath:"#/oneOf/3/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key3},message:"must NOT have additional properties"};
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
if(data.assistance !== undefined){
if(!(validate387(data.assistance, {instancePath:instancePath+"/assistance",parentData:data,parentDataProperty:"assistance",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate387.errors : vErrors.concat(validate387.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err11 = {instancePath,schemaPath:"#/oneOf/3/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
if((data.compiled === undefined) && (missing4 = "compiled")){
const err12 = {instancePath,schemaPath:"#/oneOf/4/required",keyword:"required",params:{missingProperty: missing4},message:"must have required property '"+missing4+"'"};
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
if(!(key4 === "compiled")){
const err13 = {instancePath,schemaPath:"#/oneOf/4/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key4},message:"must NOT have additional properties"};
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
if(data.compiled !== undefined){
if(!(validate412(data.compiled, {instancePath:instancePath+"/compiled",parentData:data,parentDataProperty:"compiled",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate412.errors : vErrors.concat(validate412.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err14 = {instancePath,schemaPath:"#/oneOf/4/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
if((data.inspection === undefined) && (missing5 = "inspection")){
const err15 = {instancePath,schemaPath:"#/oneOf/5/required",keyword:"required",params:{missingProperty: missing5},message:"must have required property '"+missing5+"'"};
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
if(!(key5 === "inspection")){
const err16 = {instancePath,schemaPath:"#/oneOf/5/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key5},message:"must NOT have additional properties"};
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
if(data.inspection !== undefined){
if(!(validate516(data.inspection, {instancePath:instancePath+"/inspection",parentData:data,parentDataProperty:"inspection",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate516.errors : vErrors.concat(validate516.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err17 = {instancePath,schemaPath:"#/oneOf/5/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
if((data.prepared === undefined) && (missing6 = "prepared")){
const err18 = {instancePath,schemaPath:"#/oneOf/6/required",keyword:"required",params:{missingProperty: missing6},message:"must have required property '"+missing6+"'"};
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
if(!(key6 === "prepared")){
const err19 = {instancePath,schemaPath:"#/oneOf/6/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key6},message:"must NOT have additional properties"};
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
if(data.prepared !== undefined){
if(!(validate629(data.prepared, {instancePath:instancePath+"/prepared",parentData:data,parentDataProperty:"prepared",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate629.errors : vErrors.concat(validate629.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err20 = {instancePath,schemaPath:"#/oneOf/6/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
if((data.receipt === undefined) && (missing7 = "receipt")){
const err21 = {instancePath,schemaPath:"#/oneOf/7/required",keyword:"required",params:{missingProperty: missing7},message:"must have required property '"+missing7+"'"};
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
if(!(key7 === "receipt")){
const err22 = {instancePath,schemaPath:"#/oneOf/7/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key7},message:"must NOT have additional properties"};
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
if(data.receipt !== undefined){
if(!(validate634(data.receipt, {instancePath:instancePath+"/receipt",parentData:data,parentDataProperty:"receipt",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate634.errors : vErrors.concat(validate634.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err23 = {instancePath,schemaPath:"#/oneOf/7/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
if((data.observation === undefined) && (missing8 = "observation")){
const err24 = {instancePath,schemaPath:"#/oneOf/8/required",keyword:"required",params:{missingProperty: missing8},message:"must have required property '"+missing8+"'"};
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
if(!(key8 === "observation")){
const err25 = {instancePath,schemaPath:"#/oneOf/8/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key8},message:"must NOT have additional properties"};
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
if(data.observation !== undefined){
if(!(validate637(data.observation, {instancePath:instancePath+"/observation",parentData:data,parentDataProperty:"observation",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate637.errors : vErrors.concat(validate637.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err26 = {instancePath,schemaPath:"#/oneOf/8/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
if((data.status === undefined) && (missing9 = "status")){
const err27 = {instancePath,schemaPath:"#/oneOf/9/required",keyword:"required",params:{missingProperty: missing9},message:"must have required property '"+missing9+"'"};
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
if(!(key9 === "status")){
const err28 = {instancePath,schemaPath:"#/oneOf/9/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key9},message:"must NOT have additional properties"};
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
if(data.status !== undefined){
if(!(validate643(data.status, {instancePath:instancePath+"/status",parentData:data,parentDataProperty:"status",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate643.errors : vErrors.concat(validate643.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err29 = {instancePath,schemaPath:"#/oneOf/9/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
if((data.page === undefined) && (missing10 = "page")){
const err30 = {instancePath,schemaPath:"#/oneOf/10/required",keyword:"required",params:{missingProperty: missing10},message:"must have required property '"+missing10+"'"};
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
if(!(key10 === "page")){
const err31 = {instancePath,schemaPath:"#/oneOf/10/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key10},message:"must NOT have additional properties"};
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
if(data.page !== undefined){
if(!(validate763(data.page, {instancePath:instancePath+"/page",parentData:data,parentDataProperty:"page",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate763.errors : vErrors.concat(validate763.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err32 = {instancePath,schemaPath:"#/oneOf/10/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
if((data.draft === undefined) && (missing11 = "draft")){
const err33 = {instancePath,schemaPath:"#/oneOf/11/required",keyword:"required",params:{missingProperty: missing11},message:"must have required property '"+missing11+"'"};
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
if(!(key11 === "draft")){
const err34 = {instancePath,schemaPath:"#/oneOf/11/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key11},message:"must NOT have additional properties"};
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
if(data.draft !== undefined){
if(!(validate899(data.draft, {instancePath:instancePath+"/draft",parentData:data,parentDataProperty:"draft",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate899.errors : vErrors.concat(validate899.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err35 = {instancePath,schemaPath:"#/oneOf/11/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err36 = {instancePath,schemaPath:"#/oneOf",keyword:"oneOf",params:{passingSchemas: passing0},message:"must match exactly one schema in oneOf"};
if(vErrors === null){
vErrors = [err36];
}
else {
vErrors.push(err36);
}
errors++;
validate143.errors = vErrors;
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
validate143.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate143.evaluated = {"dynamicProps":true,"dynamicItems":false};

export const Draft = validate912;
const schema280 = {"type":"object","additionalProperties":false,"properties":{"generation":{"$ref":"#/$defs/Draft/$defs/T1"},"limit":{"$ref":"#/$defs/Draft/$defs/T2"},"starts":{"$ref":"#/$defs/Draft/$defs/T2"},"enabled":{"$ref":"#/$defs/Draft/$defs/T3"},"contract":{"$ref":"#/$defs/Draft/$defs/T4"},"budgets":{"$ref":"#/$defs/Draft/$defs/T5"},"namespaces":{"$ref":"#/$defs/Draft/$defs/T6"}},"required":["generation","limit","starts","enabled","contract","budgets","namespaces"]};
const schema281 = {"type":"string","maxLength":131072};

function validate913(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate913.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(typeof data === "string"){
if(func1(data) > 131072){
validate913.errors = [{instancePath,schemaPath:"#/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"}];
return false;
}
}
else {
validate913.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
}
validate913.errors = vErrors;
return errors === 0;
}
validate913.evaluated = {"dynamicProps":false,"dynamicItems":false};


function validate915(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate915.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(!(((typeof data == "number") && (!(data % 1) && !isNaN(data))) && (isFinite(data)))){
validate915.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "integer"},message:"must be integer"}];
return false;
}
if(errors === 0){
if((typeof data == "number") && (isFinite(data))){
if(data > 255 || isNaN(data)){
validate915.errors = [{instancePath,schemaPath:"#/maximum",keyword:"maximum",params:{comparison: "<=", limit: 255},message:"must be <= 255"}];
return false;
}
else {
if(data < 0 || isNaN(data)){
validate915.errors = [{instancePath,schemaPath:"#/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"}];
return false;
}
}
}
}
validate915.errors = vErrors;
return errors === 0;
}
validate915.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema283 = {"type":"boolean"};

function validate918(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate918.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "boolean"){
validate918.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"}];
return false;
}
validate918.errors = vErrors;
return errors === 0;
}
validate918.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema284 = {"type":"array","minItems":32,"maxItems":32,"items":{"$ref":"#/$defs/Draft/$defs/T2"}};

function validate920(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate920.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(Array.isArray(data)){
if(data.length > 32){
validate920.errors = [{instancePath,schemaPath:"#/maxItems",keyword:"maxItems",params:{limit: 32},message:"must NOT have more than 32 items"}];
return false;
}
else {
if(data.length < 32){
validate920.errors = [{instancePath,schemaPath:"#/minItems",keyword:"minItems",params:{limit: 32},message:"must NOT have fewer than 32 items"}];
return false;
}
else {
var valid0 = true;
const len0 = data.length;
for(let i0=0; i0<len0; i0++){
const _errs1 = errors;
if(!(validate915(data[i0], {instancePath:instancePath+"/" + i0,parentData:data,parentDataProperty:i0,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate915.errors : vErrors.concat(validate915.errors);
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
validate920.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "array"},message:"must be array"}];
return false;
}
}
validate920.errors = vErrors;
return errors === 0;
}
validate920.evaluated = {"items":true,"dynamicProps":false,"dynamicItems":false};

const schema285 = {"type":"object","additionalProperties":false,"properties":{"pages":{"$ref":"#/$defs/Draft/$defs/T1"},"segments":{"$ref":"#/$defs/Draft/$defs/T1"},"result_bytes":{"$ref":"#/$defs/Draft/$defs/T1"}},"required":["pages","segments","result_bytes"]};

function validate923(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate923.evaluated;
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
validate923.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((key0 === "pages") || (key0 === "segments")) || (key0 === "result_bytes"))){
validate923.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.pages !== undefined){
const _errs2 = errors;
if(!(validate913(data.pages, {instancePath:instancePath+"/pages",parentData:data,parentDataProperty:"pages",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate913.errors : vErrors.concat(validate913.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.segments !== undefined){
const _errs3 = errors;
if(!(validate913(data.segments, {instancePath:instancePath+"/segments",parentData:data,parentDataProperty:"segments",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate913.errors : vErrors.concat(validate913.errors);
errors = vErrors.length;
}
var valid0 = _errs3 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.result_bytes !== undefined){
const _errs4 = errors;
if(!(validate913(data.result_bytes, {instancePath:instancePath+"/result_bytes",parentData:data,parentDataProperty:"result_bytes",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate913.errors : vErrors.concat(validate913.errors);
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
validate923.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate923.errors = vErrors;
return errors === 0;
}
validate923.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

const schema286 = {"type":"array","minItems":8,"maxItems":8,"items":{"$ref":"#/$defs/Draft/$defs/T1"}};

function validate928(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate928.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(Array.isArray(data)){
if(data.length > 8){
validate928.errors = [{instancePath,schemaPath:"#/maxItems",keyword:"maxItems",params:{limit: 8},message:"must NOT have more than 8 items"}];
return false;
}
else {
if(data.length < 8){
validate928.errors = [{instancePath,schemaPath:"#/minItems",keyword:"minItems",params:{limit: 8},message:"must NOT have fewer than 8 items"}];
return false;
}
else {
var valid0 = true;
const len0 = data.length;
for(let i0=0; i0<len0; i0++){
const _errs1 = errors;
if(!(validate913(data[i0], {instancePath:instancePath+"/" + i0,parentData:data,parentDataProperty:i0,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate913.errors : vErrors.concat(validate913.errors);
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
validate928.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "array"},message:"must be array"}];
return false;
}
}
validate928.errors = vErrors;
return errors === 0;
}
validate928.evaluated = {"items":true,"dynamicProps":false,"dynamicItems":false};


function validate912(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate912.evaluated;
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
validate912.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((((((key0 === "generation") || (key0 === "limit")) || (key0 === "starts")) || (key0 === "enabled")) || (key0 === "contract")) || (key0 === "budgets")) || (key0 === "namespaces"))){
validate912.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.generation !== undefined){
const _errs2 = errors;
if(!(validate913(data.generation, {instancePath:instancePath+"/generation",parentData:data,parentDataProperty:"generation",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate913.errors : vErrors.concat(validate913.errors);
errors = vErrors.length;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.limit !== undefined){
const _errs3 = errors;
if(!(validate915(data.limit, {instancePath:instancePath+"/limit",parentData:data,parentDataProperty:"limit",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate915.errors : vErrors.concat(validate915.errors);
errors = vErrors.length;
}
var valid0 = _errs3 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.starts !== undefined){
const _errs4 = errors;
if(!(validate915(data.starts, {instancePath:instancePath+"/starts",parentData:data,parentDataProperty:"starts",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate915.errors : vErrors.concat(validate915.errors);
errors = vErrors.length;
}
var valid0 = _errs4 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.enabled !== undefined){
const _errs5 = errors;
if(!(validate918(data.enabled, {instancePath:instancePath+"/enabled",parentData:data,parentDataProperty:"enabled",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate918.errors : vErrors.concat(validate918.errors);
errors = vErrors.length;
}
var valid0 = _errs5 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.contract !== undefined){
const _errs6 = errors;
if(!(validate920(data.contract, {instancePath:instancePath+"/contract",parentData:data,parentDataProperty:"contract",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate920.errors : vErrors.concat(validate920.errors);
errors = vErrors.length;
}
var valid0 = _errs6 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.budgets !== undefined){
const _errs7 = errors;
if(!(validate923(data.budgets, {instancePath:instancePath+"/budgets",parentData:data,parentDataProperty:"budgets",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate923.errors : vErrors.concat(validate923.errors);
errors = vErrors.length;
}
var valid0 = _errs7 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.namespaces !== undefined){
const _errs8 = errors;
if(!(validate928(data.namespaces, {instancePath:instancePath+"/namespaces",parentData:data,parentDataProperty:"namespaces",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate928.errors : vErrors.concat(validate928.errors);
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
validate912.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate912.errors = vErrors;
return errors === 0;
}
validate912.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

export const Diagnostic = validate931;
const schema287 = {"type":"object","additionalProperties":false,"properties":{"version":{"const":1},"definition":{"$ref":"#/$defs/Diagnostic/$defs/T1"},"code":{"$ref":"#/$defs/Diagnostic/$defs/T2"},"category":{"$ref":"#/$defs/Diagnostic/$defs/T3"},"stage":{"$ref":"#/$defs/Diagnostic/$defs/T4"},"outcome":{"$ref":"#/$defs/Diagnostic/$defs/T5"},"evidence":{"$ref":"#/$defs/Diagnostic/$defs/T6"},"message":{"$ref":"#/$defs/Diagnostic/$defs/T7"},"cause":{"$ref":"#/$defs/Diagnostic/$defs/T8"},"identity":{"$ref":"#/$defs/Diagnostic/$defs/T9"},"location":{"$ref":"#/$defs/Diagnostic/$defs/T14"},"facts":{"$ref":"#/$defs/Diagnostic/$defs/T20"},"actions":{"$ref":"#/$defs/Diagnostic/$defs/T32"}},"required":["version","definition","code","category","stage","outcome","evidence","message","cause","identity","location","facts","actions"]};

function validate932(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate932.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate932.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
if(!(data === "02553baa7d791340e9ea3339002537bf15495c26bd2f2bd2e2fde5950589e53f")){
validate932.errors = [{instancePath,schemaPath:"#/enum",keyword:"enum",params:{allowedValues: schema195.enum},message:"must be equal to one of the allowed values"}];
return false;
}
validate932.errors = vErrors;
return errors === 0;
}
validate932.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema289 = {"type":"string","maxLength":96};

function validate934(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate934.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(typeof data === "string"){
if(func1(data) > 96){
validate934.errors = [{instancePath,schemaPath:"#/maxLength",keyword:"maxLength",params:{limit: 96},message:"must NOT have more than 96 characters"}];
return false;
}
}
else {
validate934.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
}
validate934.errors = vErrors;
return errors === 0;
}
validate934.evaluated = {"dynamicProps":false,"dynamicItems":false};


function validate936(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate936.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate936.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
if(!(((((((((((data === "syntax") || (data === "binding")) || (data === "unsupported")) || (data === "constraint")) || (data === "access")) || (data === "conflict")) || (data === "limit")) || (data === "lifecycle")) || (data === "integrity")) || (data === "unavailable")) || (data === "internal"))){
validate936.errors = [{instancePath,schemaPath:"#/enum",keyword:"enum",params:{allowedValues: schema198.enum},message:"must be equal to one of the allowed values"}];
return false;
}
validate936.errors = vErrors;
return errors === 0;
}
validate936.evaluated = {"dynamicProps":false,"dynamicItems":false};


function validate938(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate938.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate938.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
if(!((((((((((((((data === "input") || (data === "parse")) || (data === "compile")) || (data === "bind")) || (data === "prepare")) || (data === "submit")) || (data === "admission")) || (data === "execute")) || (data === "read")) || (data === "decode")) || (data === "output")) || (data === "reconcile")) || (data === "cleanup")) || (data === "control"))){
validate938.errors = [{instancePath,schemaPath:"#/enum",keyword:"enum",params:{allowedValues: schema200.enum},message:"must be equal to one of the allowed values"}];
return false;
}
validate938.errors = vErrors;
return errors === 0;
}
validate938.evaluated = {"dynamicProps":false,"dynamicItems":false};


function validate940(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate940.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate940.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
if(!((((((((((((((data === "not_applicable") || (data === "not_submitted")) || (data === "not_dispatched")) || (data === "prepared")) || (data === "unknown")) || (data === "pending")) || (data === "input_rejected")) || (data === "rejected")) || (data === "applied")) || (data === "completed")) || (data === "failed")) || (data === "cancelled")) || (data === "retired")) || (data === "closed_unknown"))){
validate940.errors = [{instancePath,schemaPath:"#/enum",keyword:"enum",params:{allowedValues: schema202.enum},message:"must be equal to one of the allowed values"}];
return false;
}
validate940.errors = vErrors;
return errors === 0;
}
validate940.evaluated = {"dynamicProps":false,"dynamicItems":false};


function validate942(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate942.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate942.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
if(!(((((data === "none") || (data === "local_before_dispatch")) || (data === "saved_intent")) || (data === "native_receipt")) || (data === "domain_status"))){
validate942.errors = [{instancePath,schemaPath:"#/enum",keyword:"enum",params:{allowedValues: schema204.enum},message:"must be equal to one of the allowed values"}];
return false;
}
validate942.errors = vErrors;
return errors === 0;
}
validate942.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema294 = {"type":"string","maxLength":384};

function validate944(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate944.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(typeof data === "string"){
if(func1(data) > 384){
validate944.errors = [{instancePath,schemaPath:"#/maxLength",keyword:"maxLength",params:{limit: 384},message:"must NOT have more than 384 characters"}];
return false;
}
}
else {
validate944.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
}
validate944.errors = vErrors;
return errors === 0;
}
validate944.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema295 = {"anyOf":[{"$ref":"#/$defs/Diagnostic/$defs/T2"},{"type":"null"}]};

function validate946(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate946.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate934(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate934.errors : vErrors.concat(validate934.errors);
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
validate946.errors = vErrors;
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
validate946.errors = vErrors;
return errors === 0;
}
validate946.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema296 = {"anyOf":[{"$ref":"#/$defs/Diagnostic/$defs/T10"},{"type":"null"}]};
const schema297 = {"type":"object","additionalProperties":false,"properties":{"domain":{"$ref":"#/$defs/Diagnostic/$defs/T11"},"id":{"$ref":"#/$defs/Diagnostic/$defs/T12"},"realm":{"$ref":"#/$defs/Diagnostic/$defs/T13"},"resource":{"$ref":"#/$defs/Diagnostic/$defs/T13"},"sequence":{"$ref":"#/$defs/Diagnostic/$defs/T13"}},"required":["domain","id","realm","resource","sequence"]};

function validate951(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate951.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate951.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
if(!(((((((((((((data === "sql") || (data === "query")) || (data === "mutation")) || (data === "catalog")) || (data === "application")) || (data === "publication")) || (data === "migration")) || (data === "reactive")) || (data === "serving")) || (data === "effect")) || (data === "exchange")) || (data === "transport")) || (data === "internal"))){
validate951.errors = [{instancePath,schemaPath:"#/enum",keyword:"enum",params:{allowedValues: schema210.enum},message:"must be equal to one of the allowed values"}];
return false;
}
validate951.errors = vErrors;
return errors === 0;
}
validate951.evaluated = {"dynamicProps":false,"dynamicItems":false};


function validate953(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate953.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(typeof data === "string"){
if(func1(data) > 20){
validate953.errors = [{instancePath,schemaPath:"#/maxLength",keyword:"maxLength",params:{limit: 20},message:"must NOT have more than 20 characters"}];
return false;
}
else {
if(!pattern4.test(data)){
validate953.errors = [{instancePath,schemaPath:"#/pattern",keyword:"pattern",params:{pattern: "^(0|[1-9][0-9]*)$"},message:"must match pattern \""+"^(0|[1-9][0-9]*)$"+"\""}];
return false;
}
}
}
else {
validate953.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
}
validate953.errors = vErrors;
return errors === 0;
}
validate953.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema300 = {"anyOf":[{"$ref":"#/$defs/Diagnostic/$defs/T12"},{"type":"null"}]};

function validate955(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate955.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate953(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate953.errors : vErrors.concat(validate953.errors);
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
validate955.errors = vErrors;
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
validate955.errors = vErrors;
return errors === 0;
}
validate955.evaluated = {"dynamicProps":false,"dynamicItems":false};


function validate950(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate950.evaluated;
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
validate950.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((((key0 === "domain") || (key0 === "id")) || (key0 === "realm")) || (key0 === "resource")) || (key0 === "sequence"))){
validate950.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.domain !== undefined){
const _errs2 = errors;
if(!(validate951(data.domain, {instancePath:instancePath+"/domain",parentData:data,parentDataProperty:"domain",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate951.errors : vErrors.concat(validate951.errors);
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
if(!(validate953(data.id, {instancePath:instancePath+"/id",parentData:data,parentDataProperty:"id",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate953.errors : vErrors.concat(validate953.errors);
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
if(!(validate955(data.realm, {instancePath:instancePath+"/realm",parentData:data,parentDataProperty:"realm",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate955.errors : vErrors.concat(validate955.errors);
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
if(!(validate955(data.resource, {instancePath:instancePath+"/resource",parentData:data,parentDataProperty:"resource",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate955.errors : vErrors.concat(validate955.errors);
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
if(!(validate955(data.sequence, {instancePath:instancePath+"/sequence",parentData:data,parentDataProperty:"sequence",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate955.errors : vErrors.concat(validate955.errors);
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
validate950.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate950.errors = vErrors;
return errors === 0;
}
validate950.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate949(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate949.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate950(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate950.errors : vErrors.concat(validate950.errors);
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
validate949.errors = vErrors;
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
validate949.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate949.evaluated = {"dynamicProps":true,"dynamicItems":false};

const schema301 = {"anyOf":[{"$ref":"#/$defs/Diagnostic/$defs/T15"},{"type":"null"}]};
const schema302 = {"type":"object","additionalProperties":false,"properties":{"source":{"$ref":"#/$defs/Diagnostic/$defs/T16"},"source_encoding":{"$ref":"#/$defs/Diagnostic/$defs/T18"},"source_truncated":{"$ref":"#/$defs/Diagnostic/$defs/T19"},"statement":{"$ref":"#/$defs/Diagnostic/$defs/T13"},"offset":{"$ref":"#/$defs/Diagnostic/$defs/T12"},"length":{"$ref":"#/$defs/Diagnostic/$defs/T12"},"line":{"$ref":"#/$defs/Diagnostic/$defs/T12"},"byte_column":{"$ref":"#/$defs/Diagnostic/$defs/T12"}},"required":["source","source_encoding","source_truncated","statement","offset","length","line","byte_column"]};
const schema303 = {"anyOf":[{"$ref":"#/$defs/Diagnostic/$defs/T17"},{"type":"null"}]};
const schema304 = {"type":"string","maxLength":512};

function validate965(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate965.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(typeof data === "string"){
if(func1(data) > 512){
validate965.errors = [{instancePath,schemaPath:"#/maxLength",keyword:"maxLength",params:{limit: 512},message:"must NOT have more than 512 characters"}];
return false;
}
}
else {
validate965.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
}
validate965.errors = vErrors;
return errors === 0;
}
validate965.evaluated = {"dynamicProps":false,"dynamicItems":false};


function validate964(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate964.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate965(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate965.errors : vErrors.concat(validate965.errors);
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
validate964.errors = vErrors;
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
validate964.errors = vErrors;
return errors === 0;
}
validate964.evaluated = {"dynamicProps":false,"dynamicItems":false};


function validate968(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate968.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate968.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
if(!((data === "utf8") || (data === "escaped_bytes"))){
validate968.errors = [{instancePath,schemaPath:"#/enum",keyword:"enum",params:{allowedValues: schema219.enum},message:"must be equal to one of the allowed values"}];
return false;
}
validate968.errors = vErrors;
return errors === 0;
}
validate968.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema306 = {"type":"boolean"};

function validate970(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate970.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "boolean"){
validate970.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"}];
return false;
}
validate970.errors = vErrors;
return errors === 0;
}
validate970.evaluated = {"dynamicProps":false,"dynamicItems":false};


function validate963(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate963.evaluated;
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
validate963.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((((((((key0 === "source") || (key0 === "source_encoding")) || (key0 === "source_truncated")) || (key0 === "statement")) || (key0 === "offset")) || (key0 === "length")) || (key0 === "line")) || (key0 === "byte_column"))){
validate963.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.source !== undefined){
const _errs2 = errors;
if(!(validate964(data.source, {instancePath:instancePath+"/source",parentData:data,parentDataProperty:"source",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate964.errors : vErrors.concat(validate964.errors);
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
if(!(validate968(data.source_encoding, {instancePath:instancePath+"/source_encoding",parentData:data,parentDataProperty:"source_encoding",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate968.errors : vErrors.concat(validate968.errors);
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
if(!(validate970(data.source_truncated, {instancePath:instancePath+"/source_truncated",parentData:data,parentDataProperty:"source_truncated",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate970.errors : vErrors.concat(validate970.errors);
errors = vErrors.length;
}
var valid0 = _errs4 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.statement !== undefined){
const _errs5 = errors;
if(!(validate955(data.statement, {instancePath:instancePath+"/statement",parentData:data,parentDataProperty:"statement",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate955.errors : vErrors.concat(validate955.errors);
errors = vErrors.length;
}
var valid0 = _errs5 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.offset !== undefined){
const _errs6 = errors;
if(!(validate953(data.offset, {instancePath:instancePath+"/offset",parentData:data,parentDataProperty:"offset",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate953.errors : vErrors.concat(validate953.errors);
errors = vErrors.length;
}
var valid0 = _errs6 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.length !== undefined){
const _errs7 = errors;
if(!(validate953(data.length, {instancePath:instancePath+"/length",parentData:data,parentDataProperty:"length",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate953.errors : vErrors.concat(validate953.errors);
errors = vErrors.length;
}
var valid0 = _errs7 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.line !== undefined){
const _errs8 = errors;
if(!(validate953(data.line, {instancePath:instancePath+"/line",parentData:data,parentDataProperty:"line",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate953.errors : vErrors.concat(validate953.errors);
errors = vErrors.length;
}
var valid0 = _errs8 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.byte_column !== undefined){
const _errs9 = errors;
if(!(validate953(data.byte_column, {instancePath:instancePath+"/byte_column",parentData:data,parentDataProperty:"byte_column",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate953.errors : vErrors.concat(validate953.errors);
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
validate963.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate963.errors = vErrors;
return errors === 0;
}
validate963.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate962(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate962.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate963(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate963.errors : vErrors.concat(validate963.errors);
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
validate962.errors = vErrors;
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
validate962.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate962.evaluated = {"dynamicProps":true,"dynamicItems":false};

const schema307 = {"type":"array","minItems":16,"maxItems":16,"items":{"$ref":"#/$defs/Diagnostic/$defs/T21"}};
const schema308 = {"anyOf":[{"$ref":"#/$defs/Diagnostic/$defs/T22"},{"type":"null"}]};
const schema309 = {"type":"object","additionalProperties":false,"properties":{"field":{"$ref":"#/$defs/Diagnostic/$defs/T23"},"origin":{"$ref":"#/$defs/Diagnostic/$defs/T24"},"availability":{"$ref":"#/$defs/Diagnostic/$defs/T25"},"value":{"$ref":"#/$defs/Diagnostic/$defs/T26"}},"required":["field","origin","availability","value"]};

function validate982(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate982.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate982.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
if(!((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((data === "object") || (data === "name")) || (data === "table")) || (data === "native_input")) || (data === "affected_rows")) || (data === "argument")) || (data === "option")) || (data === "permissions")) || (data === "scope")) || (data === "column")) || (data === "qualifier")) || (data === "constraint")) || (data === "key")) || (data === "input_row")) || (data === "first_occurrence")) || (data === "parameter")) || (data === "parameter_use")) || (data === "expected_count")) || (data === "actual_count")) || (data === "expected_type")) || (data === "actual_type")) || (data === "supplied_value")) || (data === "expected_value")) || (data === "expression")) || (data === "source_kind")) || (data === "source_basis")) || (data === "source_key")) || (data === "source_row")) || (data === "field_path")) || (data === "byte_offset")) || (data === "expected_resource")) || (data === "actual_resource")) || (data === "expected_source")) || (data === "actual_source")) || (data === "expected_revision")) || (data === "actual_revision")) || (data === "expected_schema")) || (data === "actual_schema")) || (data === "expected_policy")) || (data === "actual_policy")) || (data === "budget")) || (data === "limit")) || (data === "required")) || (data === "unit")) || (data === "completed_statements")) || (data === "emitted_rows")) || (data === "emitted_segments")) || (data === "completion")) || (data === "proposal")) || (data === "step")) || (data === "generation")) || (data === "attachment")) || (data === "lease")) || (data === "schema_origin")) || (data === "sampling_records")) || (data === "operation")) || (data === "native_cause")) || (data === "expected_bytes")) || (data === "presence")) || (data === "published")) || (data === "subscription")) || (data === "expected_codec")) || (data === "actual_codec")) || (data === "observed_clock")) || (data === "expected_namespace")) || (data === "actual_namespace")) || (data === "attempt")) || (data === "executor")) || (data === "resolution_reason")) || (data === "principal")) || (data === "deadline")) || (data === "authorization_policy")) || (data === "resolution_policy")) || (data === "protocol_status")) || (data === "native_effect")) || (data === "dependency")) || (data === "dependency_kind")) || (data === "dependency_owner"))){
validate982.errors = [{instancePath,schemaPath:"#/enum",keyword:"enum",params:{allowedValues: schema224.enum},message:"must be equal to one of the allowed values"}];
return false;
}
validate982.errors = vErrors;
return errors === 0;
}
validate982.evaluated = {"dynamicProps":false,"dynamicItems":false};


function validate984(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate984.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate984.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
if(!(((((data === "caller") || (data === "execution")) || (data === "schema")) || (data === "authority")) || (data === "owner"))){
validate984.errors = [{instancePath,schemaPath:"#/enum",keyword:"enum",params:{allowedValues: schema226.enum},message:"must be equal to one of the allowed values"}];
return false;
}
validate984.errors = vErrors;
return errors === 0;
}
validate984.evaluated = {"dynamicProps":false,"dynamicItems":false};


function validate986(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate986.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate986.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
if(!((((((data === "provided") || (data === "truncated")) || (data === "unrecorded")) || (data === "unavailable")) || (data === "withheld")) || (data === "inapplicable"))){
validate986.errors = [{instancePath,schemaPath:"#/enum",keyword:"enum",params:{allowedValues: schema228.enum},message:"must be equal to one of the allowed values"}];
return false;
}
validate986.errors = vErrors;
return errors === 0;
}
validate986.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema313 = {"anyOf":[{"$ref":"#/$defs/Diagnostic/$defs/T27"},{"type":"null"}]};
const schema314 = {"oneOf":[{"type":"object","additionalProperties":false,"required":["text"],"properties":{"text":{"$ref":"#/$defs/Diagnostic/$defs/T28"}}},{"type":"object","additionalProperties":false,"required":["signed"],"properties":{"signed":{"$ref":"#/$defs/Diagnostic/$defs/T29"}}},{"type":"object","additionalProperties":false,"required":["unsigned"],"properties":{"unsigned":{"$ref":"#/$defs/Diagnostic/$defs/T12"}}},{"type":"object","additionalProperties":false,"required":["boolean"],"properties":{"boolean":{"$ref":"#/$defs/Diagnostic/$defs/T19"}}},{"type":"object","additionalProperties":false,"required":["digest"],"properties":{"digest":{"$ref":"#/$defs/Diagnostic/$defs/T30"}}},{"type":"object","additionalProperties":false,"required":["location"],"properties":{"location":{"$ref":"#/$defs/Diagnostic/$defs/T15"}}}]};
const schema315 = {"type":"string","maxLength":256};

function validate990(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate990.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(typeof data === "string"){
if(func1(data) > 256){
validate990.errors = [{instancePath,schemaPath:"#/maxLength",keyword:"maxLength",params:{limit: 256},message:"must NOT have more than 256 characters"}];
return false;
}
}
else {
validate990.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
}
validate990.errors = vErrors;
return errors === 0;
}
validate990.evaluated = {"dynamicProps":false,"dynamicItems":false};


function validate992(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate992.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(typeof data === "string"){
if(func1(data) > 20){
validate992.errors = [{instancePath,schemaPath:"#/maxLength",keyword:"maxLength",params:{limit: 20},message:"must NOT have more than 20 characters"}];
return false;
}
else {
if(!pattern6.test(data)){
validate992.errors = [{instancePath,schemaPath:"#/pattern",keyword:"pattern",params:{pattern: "^(0|-?[1-9][0-9]*)$"},message:"must match pattern \""+"^(0|-?[1-9][0-9]*)$"+"\""}];
return false;
}
}
}
else {
validate992.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
}
validate992.errors = vErrors;
return errors === 0;
}
validate992.evaluated = {"dynamicProps":false,"dynamicItems":false};

const schema317 = {"type":"array","minItems":32,"maxItems":32,"items":{"$ref":"#/$defs/Diagnostic/$defs/T31"}};

function validate997(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate997.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(!(((typeof data == "number") && (!(data % 1) && !isNaN(data))) && (isFinite(data)))){
validate997.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "integer"},message:"must be integer"}];
return false;
}
if(errors === 0){
if((typeof data == "number") && (isFinite(data))){
if(data > 255 || isNaN(data)){
validate997.errors = [{instancePath,schemaPath:"#/maximum",keyword:"maximum",params:{comparison: "<=", limit: 255},message:"must be <= 255"}];
return false;
}
else {
if(data < 0 || isNaN(data)){
validate997.errors = [{instancePath,schemaPath:"#/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"}];
return false;
}
}
}
}
validate997.errors = vErrors;
return errors === 0;
}
validate997.evaluated = {"dynamicProps":false,"dynamicItems":false};


function validate996(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate996.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(Array.isArray(data)){
if(data.length > 32){
validate996.errors = [{instancePath,schemaPath:"#/maxItems",keyword:"maxItems",params:{limit: 32},message:"must NOT have more than 32 items"}];
return false;
}
else {
if(data.length < 32){
validate996.errors = [{instancePath,schemaPath:"#/minItems",keyword:"minItems",params:{limit: 32},message:"must NOT have fewer than 32 items"}];
return false;
}
else {
var valid0 = true;
const len0 = data.length;
for(let i0=0; i0<len0; i0++){
const _errs1 = errors;
if(!(validate997(data[i0], {instancePath:instancePath+"/" + i0,parentData:data,parentDataProperty:i0,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate997.errors : vErrors.concat(validate997.errors);
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
validate996.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "array"},message:"must be array"}];
return false;
}
}
validate996.errors = vErrors;
return errors === 0;
}
validate996.evaluated = {"items":true,"dynamicProps":false,"dynamicItems":false};


function validate989(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate989.evaluated;
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
if((data.text === undefined) && (missing0 = "text")){
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
if(!(key0 === "text")){
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
if(data.text !== undefined){
if(!(validate990(data.text, {instancePath:instancePath+"/text",parentData:data,parentDataProperty:"text",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate990.errors : vErrors.concat(validate990.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err2 = {instancePath,schemaPath:"#/oneOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
if((data.signed === undefined) && (missing1 = "signed")){
const err3 = {instancePath,schemaPath:"#/oneOf/1/required",keyword:"required",params:{missingProperty: missing1},message:"must have required property '"+missing1+"'"};
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
if(!(key1 === "signed")){
const err4 = {instancePath,schemaPath:"#/oneOf/1/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key1},message:"must NOT have additional properties"};
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
if(data.signed !== undefined){
if(!(validate992(data.signed, {instancePath:instancePath+"/signed",parentData:data,parentDataProperty:"signed",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate992.errors : vErrors.concat(validate992.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err5 = {instancePath,schemaPath:"#/oneOf/1/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
if((data.unsigned === undefined) && (missing2 = "unsigned")){
const err6 = {instancePath,schemaPath:"#/oneOf/2/required",keyword:"required",params:{missingProperty: missing2},message:"must have required property '"+missing2+"'"};
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
if(!(key2 === "unsigned")){
const err7 = {instancePath,schemaPath:"#/oneOf/2/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key2},message:"must NOT have additional properties"};
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
if(data.unsigned !== undefined){
if(!(validate953(data.unsigned, {instancePath:instancePath+"/unsigned",parentData:data,parentDataProperty:"unsigned",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate953.errors : vErrors.concat(validate953.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err8 = {instancePath,schemaPath:"#/oneOf/2/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err9 = {instancePath,schemaPath:"#/oneOf/3/required",keyword:"required",params:{missingProperty: missing3},message:"must have required property '"+missing3+"'"};
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
const err10 = {instancePath,schemaPath:"#/oneOf/3/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key3},message:"must NOT have additional properties"};
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
if(!(validate970(data.boolean, {instancePath:instancePath+"/boolean",parentData:data,parentDataProperty:"boolean",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate970.errors : vErrors.concat(validate970.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err11 = {instancePath,schemaPath:"#/oneOf/3/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
if((data.digest === undefined) && (missing4 = "digest")){
const err12 = {instancePath,schemaPath:"#/oneOf/4/required",keyword:"required",params:{missingProperty: missing4},message:"must have required property '"+missing4+"'"};
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
if(!(key4 === "digest")){
const err13 = {instancePath,schemaPath:"#/oneOf/4/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key4},message:"must NOT have additional properties"};
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
if(data.digest !== undefined){
if(!(validate996(data.digest, {instancePath:instancePath+"/digest",parentData:data,parentDataProperty:"digest",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate996.errors : vErrors.concat(validate996.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err14 = {instancePath,schemaPath:"#/oneOf/4/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
if((data.location === undefined) && (missing5 = "location")){
const err15 = {instancePath,schemaPath:"#/oneOf/5/required",keyword:"required",params:{missingProperty: missing5},message:"must have required property '"+missing5+"'"};
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
if(!(key5 === "location")){
const err16 = {instancePath,schemaPath:"#/oneOf/5/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key5},message:"must NOT have additional properties"};
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
if(data.location !== undefined){
if(!(validate963(data.location, {instancePath:instancePath+"/location",parentData:data,parentDataProperty:"location",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate963.errors : vErrors.concat(validate963.errors);
errors = vErrors.length;
}
}
}
}
}
else {
const err17 = {instancePath,schemaPath:"#/oneOf/5/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err18 = {instancePath,schemaPath:"#/oneOf",keyword:"oneOf",params:{passingSchemas: passing0},message:"must match exactly one schema in oneOf"};
if(vErrors === null){
vErrors = [err18];
}
else {
vErrors.push(err18);
}
errors++;
validate989.errors = vErrors;
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
validate989.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate989.evaluated = {"dynamicProps":true,"dynamicItems":false};


function validate988(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate988.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate989(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate989.errors : vErrors.concat(validate989.errors);
errors = vErrors.length;
}
else {
var props0 = validate989.evaluated.props;
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
validate988.errors = vErrors;
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
validate988.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate988.evaluated = {"dynamicProps":true,"dynamicItems":false};


function validate981(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate981.evaluated;
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
validate981.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((((key0 === "field") || (key0 === "origin")) || (key0 === "availability")) || (key0 === "value"))){
validate981.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.field !== undefined){
const _errs2 = errors;
if(!(validate982(data.field, {instancePath:instancePath+"/field",parentData:data,parentDataProperty:"field",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate982.errors : vErrors.concat(validate982.errors);
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
if(!(validate984(data.origin, {instancePath:instancePath+"/origin",parentData:data,parentDataProperty:"origin",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate984.errors : vErrors.concat(validate984.errors);
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
if(!(validate986(data.availability, {instancePath:instancePath+"/availability",parentData:data,parentDataProperty:"availability",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate986.errors : vErrors.concat(validate986.errors);
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
if(!(validate988(data.value, {instancePath:instancePath+"/value",parentData:data,parentDataProperty:"value",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate988.errors : vErrors.concat(validate988.errors);
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
validate981.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate981.errors = vErrors;
return errors === 0;
}
validate981.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate980(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate980.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate981(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate981.errors : vErrors.concat(validate981.errors);
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
validate980.errors = vErrors;
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
validate980.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate980.evaluated = {"dynamicProps":true,"dynamicItems":false};


function validate979(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate979.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(Array.isArray(data)){
if(data.length > 16){
validate979.errors = [{instancePath,schemaPath:"#/maxItems",keyword:"maxItems",params:{limit: 16},message:"must NOT have more than 16 items"}];
return false;
}
else {
if(data.length < 16){
validate979.errors = [{instancePath,schemaPath:"#/minItems",keyword:"minItems",params:{limit: 16},message:"must NOT have fewer than 16 items"}];
return false;
}
else {
var valid0 = true;
const len0 = data.length;
for(let i0=0; i0<len0; i0++){
const _errs1 = errors;
if(!(validate980(data[i0], {instancePath:instancePath+"/" + i0,parentData:data,parentDataProperty:i0,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate980.errors : vErrors.concat(validate980.errors);
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
validate979.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "array"},message:"must be array"}];
return false;
}
}
validate979.errors = vErrors;
return errors === 0;
}
validate979.evaluated = {"items":true,"dynamicProps":false,"dynamicItems":false};

const schema319 = {"type":"array","minItems":4,"maxItems":4,"items":{"$ref":"#/$defs/Diagnostic/$defs/T33"}};
const schema320 = {"anyOf":[{"$ref":"#/$defs/Diagnostic/$defs/T34"},{"type":"null"}]};
const schema321 = {"type":"object","additionalProperties":false,"properties":{"kind":{"$ref":"#/$defs/Diagnostic/$defs/T35"},"target":{"$ref":"#/$defs/Diagnostic/$defs/T9"}},"required":["kind","target"]};

function validate1009(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1009.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(typeof data !== "string"){
validate1009.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
if(!(((((((((((data === "correct_input") || (data === "inspect_status")) || (data === "resume_exact")) || (data === "cancel_wait")) || (data === "cancel_mutation")) || (data === "refresh")) || (data === "recompile")) || (data === "retry_read")) || (data === "inspect_scope")) || (data === "reconcile_effect")) || (data === "contact_operator"))){
validate1009.errors = [{instancePath,schemaPath:"#/enum",keyword:"enum",params:{allowedValues: schema238.enum},message:"must be equal to one of the allowed values"}];
return false;
}
validate1009.errors = vErrors;
return errors === 0;
}
validate1009.evaluated = {"dynamicProps":false,"dynamicItems":false};


function validate1008(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1008.evaluated;
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
validate1008.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!((key0 === "kind") || (key0 === "target"))){
validate1008.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.kind !== undefined){
const _errs2 = errors;
if(!(validate1009(data.kind, {instancePath:instancePath+"/kind",parentData:data,parentDataProperty:"kind",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1009.errors : vErrors.concat(validate1009.errors);
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
if(!(validate949(data.target, {instancePath:instancePath+"/target",parentData:data,parentDataProperty:"target",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate949.errors : vErrors.concat(validate949.errors);
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
validate1008.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate1008.errors = vErrors;
return errors === 0;
}
validate1008.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};


function validate1007(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1007.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
const _errs0 = errors;
let valid0 = false;
const _errs1 = errors;
if(!(validate1008(data, {instancePath,parentData,parentDataProperty,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1008.errors : vErrors.concat(validate1008.errors);
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
validate1007.errors = vErrors;
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
validate1007.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate1007.evaluated = {"dynamicProps":true,"dynamicItems":false};


function validate1006(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate1006.evaluated;
if(evaluated0.dynamicProps){
evaluated0.props = undefined;
}
if(evaluated0.dynamicItems){
evaluated0.items = undefined;
}
if(errors === 0){
if(Array.isArray(data)){
if(data.length > 4){
validate1006.errors = [{instancePath,schemaPath:"#/maxItems",keyword:"maxItems",params:{limit: 4},message:"must NOT have more than 4 items"}];
return false;
}
else {
if(data.length < 4){
validate1006.errors = [{instancePath,schemaPath:"#/minItems",keyword:"minItems",params:{limit: 4},message:"must NOT have fewer than 4 items"}];
return false;
}
else {
var valid0 = true;
const len0 = data.length;
for(let i0=0; i0<len0; i0++){
const _errs1 = errors;
if(!(validate1007(data[i0], {instancePath:instancePath+"/" + i0,parentData:data,parentDataProperty:i0,rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1007.errors : vErrors.concat(validate1007.errors);
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
validate1006.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "array"},message:"must be array"}];
return false;
}
}
validate1006.errors = vErrors;
return errors === 0;
}
validate1006.evaluated = {"items":true,"dynamicProps":false,"dynamicItems":false};


function validate931(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate931.evaluated;
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
validate931.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(func4.call(schema287.properties, key0))){
validate931.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.version !== undefined){
const _errs2 = errors;
if(1 !== data.version){
validate931.errors = [{instancePath:instancePath+"/version",schemaPath:"#/properties/version/const",keyword:"const",params:{allowedValue: 1},message:"must be equal to constant"}];
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
if(!(validate932(data.definition, {instancePath:instancePath+"/definition",parentData:data,parentDataProperty:"definition",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate932.errors : vErrors.concat(validate932.errors);
errors = vErrors.length;
}
var valid0 = _errs3 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.code !== undefined){
const _errs4 = errors;
if(!(validate934(data.code, {instancePath:instancePath+"/code",parentData:data,parentDataProperty:"code",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate934.errors : vErrors.concat(validate934.errors);
errors = vErrors.length;
}
var valid0 = _errs4 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.category !== undefined){
const _errs5 = errors;
if(!(validate936(data.category, {instancePath:instancePath+"/category",parentData:data,parentDataProperty:"category",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate936.errors : vErrors.concat(validate936.errors);
errors = vErrors.length;
}
var valid0 = _errs5 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.stage !== undefined){
const _errs6 = errors;
if(!(validate938(data.stage, {instancePath:instancePath+"/stage",parentData:data,parentDataProperty:"stage",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate938.errors : vErrors.concat(validate938.errors);
errors = vErrors.length;
}
var valid0 = _errs6 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.outcome !== undefined){
const _errs7 = errors;
if(!(validate940(data.outcome, {instancePath:instancePath+"/outcome",parentData:data,parentDataProperty:"outcome",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate940.errors : vErrors.concat(validate940.errors);
errors = vErrors.length;
}
var valid0 = _errs7 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.evidence !== undefined){
const _errs8 = errors;
if(!(validate942(data.evidence, {instancePath:instancePath+"/evidence",parentData:data,parentDataProperty:"evidence",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate942.errors : vErrors.concat(validate942.errors);
errors = vErrors.length;
}
var valid0 = _errs8 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.message !== undefined){
const _errs9 = errors;
if(!(validate944(data.message, {instancePath:instancePath+"/message",parentData:data,parentDataProperty:"message",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate944.errors : vErrors.concat(validate944.errors);
errors = vErrors.length;
}
var valid0 = _errs9 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.cause !== undefined){
const _errs10 = errors;
if(!(validate946(data.cause, {instancePath:instancePath+"/cause",parentData:data,parentDataProperty:"cause",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate946.errors : vErrors.concat(validate946.errors);
errors = vErrors.length;
}
var valid0 = _errs10 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.identity !== undefined){
const _errs11 = errors;
if(!(validate949(data.identity, {instancePath:instancePath+"/identity",parentData:data,parentDataProperty:"identity",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate949.errors : vErrors.concat(validate949.errors);
errors = vErrors.length;
}
var valid0 = _errs11 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.location !== undefined){
const _errs12 = errors;
if(!(validate962(data.location, {instancePath:instancePath+"/location",parentData:data,parentDataProperty:"location",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate962.errors : vErrors.concat(validate962.errors);
errors = vErrors.length;
}
var valid0 = _errs12 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.facts !== undefined){
const _errs13 = errors;
if(!(validate979(data.facts, {instancePath:instancePath+"/facts",parentData:data,parentDataProperty:"facts",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate979.errors : vErrors.concat(validate979.errors);
errors = vErrors.length;
}
var valid0 = _errs13 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.actions !== undefined){
const _errs14 = errors;
if(!(validate1006(data.actions, {instancePath:instancePath+"/actions",parentData:data,parentDataProperty:"actions",rootData,dynamicAnchors}))){
vErrors = vErrors === null ? validate1006.errors : vErrors.concat(validate1006.errors);
errors = vErrors.length;
}
var valid0 = _errs14 === errors;
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
validate931.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate931.errors = vErrors;
return errors === 0;
}
validate931.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};
