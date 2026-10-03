// Generated; no runtime code generation or eval.
import lengthModule from "ajv/dist/runtime/ucs2length.js";
const ucs2length = lengthModule.default ?? lengthModule;
"use strict";
export const Request = validate21;
const schema32 = {"oneOf":[{"type":"object","additionalProperties":false,"required":["describe"],"properties":{"describe":{"type":"object","maxProperties":0}}},{"type":"object","additionalProperties":false,"required":["sql_capabilities"],"properties":{"sql_capabilities":{"type":"object","maxProperties":0}}},{"type":"object","additionalProperties":false,"required":["suggest"],"properties":{"suggest":{"type":"object","additionalProperties":false,"properties":{"search":{"type":"string","maxLength":131072}},"required":["search"]}}},{"type":"object","additionalProperties":false,"required":["assist"],"properties":{"assist":{"type":"object","additionalProperties":false,"properties":{"sql":{"type":"string","maxLength":131072},"cursor":{"type":"integer","minimum":0,"maximum":65535},"generation":{"type":"integer","minimum":0,"maximum":4294967295},"mode":{"type":"string","enum":["sql","console"]}},"required":["sql","cursor","generation"]}}},{"type":"object","additionalProperties":false,"required":["compile"],"properties":{"compile":{"type":"object","additionalProperties":false,"properties":{"sql":{"type":"string","maxLength":131072},"parameters":{"anyOf":[{"type":"array","maxItems":8,"items":{"oneOf":[{"type":"object","additionalProperties":false,"required":["int64"],"properties":{"int64":{"type":"string","maxLength":131072}}},{"type":"object","additionalProperties":false,"required":["uint64"],"properties":{"uint64":{"type":"string","maxLength":131072}}},{"type":"object","additionalProperties":false,"required":["float_bits"],"properties":{"float_bits":{"type":"string","maxLength":131072}}},{"type":"object","additionalProperties":false,"required":["boolean"],"properties":{"boolean":{"type":"boolean"}}},{"type":"object","additionalProperties":false,"required":["utf8"],"properties":{"utf8":{"type":"string","maxLength":131072}}},{"type":"object","additionalProperties":false,"required":["binary"],"properties":{"binary":{"type":"string","maxLength":131072}}}]}},{"type":"null"}]}},"required":["sql"]}}},{"type":"object","additionalProperties":false,"required":["inspect"],"properties":{"inspect":{"type":"object","additionalProperties":false,"properties":{"sql":{"type":"string","maxLength":131072}},"required":["sql"]}}},{"type":"object","additionalProperties":false,"required":["next"],"properties":{"next":{"type":"object","additionalProperties":false,"properties":{"namespace":{"type":"string","maxLength":131072},"bundle":{"type":"string","maxLength":131072}},"required":["namespace","bundle"]}}},{"type":"object","additionalProperties":false,"required":["next_draft"],"properties":{"next_draft":{"type":"object","additionalProperties":false,"properties":{"namespace":{"type":"string","maxLength":131072},"bundle":{"type":"string","maxLength":131072},"generation":{"type":"string","maxLength":131072}},"required":["namespace","bundle","generation"]}}},{"type":"object","additionalProperties":false,"required":["draft_open"],"properties":{"draft_open":{"type":"object","additionalProperties":false,"properties":{"expected":{"type":"string","maxLength":131072},"limit":{"type":"integer","minimum":0,"maximum":255}},"required":["expected","limit"]}}},{"type":"object","additionalProperties":false,"required":["draft_close"],"properties":{"draft_close":{"type":"string","maxLength":131072}}},{"type":"object","additionalProperties":false,"required":["draft_status"],"properties":{"draft_status":{"anyOf":[{"type":"string","maxLength":131072},{"type":"null"}]}}},{"type":"object","additionalProperties":false,"required":["submit"],"properties":{"submit":{"type":"object","additionalProperties":false,"properties":{"token":{"type":"string","maxLength":131072}},"required":["token"]}}},{"type":"object","additionalProperties":false,"required":["observe"],"properties":{"observe":{"type":"integer","minimum":0,"maximum":9007199254740991}}},{"type":"object","additionalProperties":false,"required":["status"],"properties":{"status":{"type":"string","maxLength":131072}}},{"type":"object","additionalProperties":false,"required":["page"],"properties":{"page":{"type":"object","additionalProperties":false,"properties":{"namespace":{"type":"string","maxLength":131072},"cursor":{"anyOf":[{"type":"string","maxLength":131072},{"type":"null"}]}},"required":["namespace"]}}},{"type":"object","additionalProperties":false,"required":["prepare_control"],"properties":{"prepare_control":{"type":"object","additionalProperties":false,"properties":{"namespace":{"type":"string","maxLength":131072},"operation":{"type":"string","enum":["cancel","collect","retire"]}},"required":["namespace","operation"]}}}]};
const func1 = ucs2length;

function validate21(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate21.evaluated;
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
let data6 = data4.cursor;
const _errs27 = errors;
if(!(((typeof data6 == "number") && (!(data6 % 1) && !isNaN(data6))) && (isFinite(data6)))){
const err24 = {instancePath:instancePath+"/assist/cursor",schemaPath:"#/oneOf/3/properties/assist/properties/cursor/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err24];
}
else {
vErrors.push(err24);
}
errors++;
}
if(errors === _errs27){
if((typeof data6 == "number") && (isFinite(data6))){
if(data6 > 65535 || isNaN(data6)){
const err25 = {instancePath:instancePath+"/assist/cursor",schemaPath:"#/oneOf/3/properties/assist/properties/cursor/maximum",keyword:"maximum",params:{comparison: "<=", limit: 65535},message:"must be <= 65535"};
if(vErrors === null){
vErrors = [err25];
}
else {
vErrors.push(err25);
}
errors++;
}
else {
if(data6 < 0 || isNaN(data6)){
const err26 = {instancePath:instancePath+"/assist/cursor",schemaPath:"#/oneOf/3/properties/assist/properties/cursor/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
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
var valid6 = _errs27 === errors;
}
else {
var valid6 = true;
}
if(valid6){
if(data4.generation !== undefined){
let data7 = data4.generation;
const _errs29 = errors;
if(!(((typeof data7 == "number") && (!(data7 % 1) && !isNaN(data7))) && (isFinite(data7)))){
const err27 = {instancePath:instancePath+"/assist/generation",schemaPath:"#/oneOf/3/properties/assist/properties/generation/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err27];
}
else {
vErrors.push(err27);
}
errors++;
}
if(errors === _errs29){
if((typeof data7 == "number") && (isFinite(data7))){
if(data7 > 4294967295 || isNaN(data7)){
const err28 = {instancePath:instancePath+"/assist/generation",schemaPath:"#/oneOf/3/properties/assist/properties/generation/maximum",keyword:"maximum",params:{comparison: "<=", limit: 4294967295},message:"must be <= 4294967295"};
if(vErrors === null){
vErrors = [err28];
}
else {
vErrors.push(err28);
}
errors++;
}
else {
if(data7 < 0 || isNaN(data7)){
const err29 = {instancePath:instancePath+"/assist/generation",schemaPath:"#/oneOf/3/properties/assist/properties/generation/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err29];
}
else {
vErrors.push(err29);
}
errors++;
}
}
}
}
var valid6 = _errs29 === errors;
}
else {
var valid6 = true;
}
if(valid6){
if(data4.mode !== undefined){
let data8 = data4.mode;
const _errs31 = errors;
if(typeof data8 !== "string"){
const err30 = {instancePath:instancePath+"/assist/mode",schemaPath:"#/oneOf/3/properties/assist/properties/mode/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err30];
}
else {
vErrors.push(err30);
}
errors++;
}
if(!((data8 === "sql") || (data8 === "console"))){
const err31 = {instancePath:instancePath+"/assist/mode",schemaPath:"#/oneOf/3/properties/assist/properties/mode/enum",keyword:"enum",params:{allowedValues: schema32.oneOf[3].properties.assist.properties.mode.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err31];
}
else {
vErrors.push(err31);
}
errors++;
}
var valid6 = _errs31 === errors;
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
const err32 = {instancePath:instancePath+"/assist",schemaPath:"#/oneOf/3/properties/assist/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err32];
}
else {
vErrors.push(err32);
}
errors++;
}
}
}
}
}
}
else {
const err33 = {instancePath,schemaPath:"#/oneOf/3/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err33];
}
else {
vErrors.push(err33);
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
const _errs33 = errors;
if(errors === _errs33){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing6;
if((data.compile === undefined) && (missing6 = "compile")){
const err34 = {instancePath,schemaPath:"#/oneOf/4/required",keyword:"required",params:{missingProperty: missing6},message:"must have required property '"+missing6+"'"};
if(vErrors === null){
vErrors = [err34];
}
else {
vErrors.push(err34);
}
errors++;
}
else {
const _errs35 = errors;
for(const key6 in data){
if(!(key6 === "compile")){
const err35 = {instancePath,schemaPath:"#/oneOf/4/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key6},message:"must NOT have additional properties"};
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
if(_errs35 === errors){
if(data.compile !== undefined){
let data9 = data.compile;
const _errs36 = errors;
if(errors === _errs36){
if(data9 && typeof data9 == "object" && !Array.isArray(data9)){
let missing7;
if((data9.sql === undefined) && (missing7 = "sql")){
const err36 = {instancePath:instancePath+"/compile",schemaPath:"#/oneOf/4/properties/compile/required",keyword:"required",params:{missingProperty: missing7},message:"must have required property '"+missing7+"'"};
if(vErrors === null){
vErrors = [err36];
}
else {
vErrors.push(err36);
}
errors++;
}
else {
const _errs38 = errors;
for(const key7 in data9){
if(!((key7 === "sql") || (key7 === "parameters"))){
const err37 = {instancePath:instancePath+"/compile",schemaPath:"#/oneOf/4/properties/compile/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key7},message:"must NOT have additional properties"};
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
if(_errs38 === errors){
if(data9.sql !== undefined){
let data10 = data9.sql;
const _errs39 = errors;
if(errors === _errs39){
if(typeof data10 === "string"){
if(func1(data10) > 131072){
const err38 = {instancePath:instancePath+"/compile/sql",schemaPath:"#/oneOf/4/properties/compile/properties/sql/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err38];
}
else {
vErrors.push(err38);
}
errors++;
}
}
else {
const err39 = {instancePath:instancePath+"/compile/sql",schemaPath:"#/oneOf/4/properties/compile/properties/sql/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err39];
}
else {
vErrors.push(err39);
}
errors++;
}
}
var valid8 = _errs39 === errors;
}
else {
var valid8 = true;
}
if(valid8){
if(data9.parameters !== undefined){
let data11 = data9.parameters;
const _errs41 = errors;
const _errs42 = errors;
let valid9 = false;
const _errs43 = errors;
if(errors === _errs43){
if(Array.isArray(data11)){
if(data11.length > 8){
const err40 = {instancePath:instancePath+"/compile/parameters",schemaPath:"#/oneOf/4/properties/compile/properties/parameters/anyOf/0/maxItems",keyword:"maxItems",params:{limit: 8},message:"must NOT have more than 8 items"};
if(vErrors === null){
vErrors = [err40];
}
else {
vErrors.push(err40);
}
errors++;
}
else {
var valid10 = true;
const len0 = data11.length;
for(let i0=0; i0<len0; i0++){
let data12 = data11[i0];
const _errs45 = errors;
const _errs46 = errors;
let valid11 = false;
let passing1 = null;
const _errs47 = errors;
if(errors === _errs47){
if(data12 && typeof data12 == "object" && !Array.isArray(data12)){
let missing8;
if((data12.int64 === undefined) && (missing8 = "int64")){
const err41 = {instancePath:instancePath+"/compile/parameters/" + i0,schemaPath:"#/oneOf/4/properties/compile/properties/parameters/anyOf/0/items/oneOf/0/required",keyword:"required",params:{missingProperty: missing8},message:"must have required property '"+missing8+"'"};
if(vErrors === null){
vErrors = [err41];
}
else {
vErrors.push(err41);
}
errors++;
}
else {
const _errs49 = errors;
for(const key8 in data12){
if(!(key8 === "int64")){
const err42 = {instancePath:instancePath+"/compile/parameters/" + i0,schemaPath:"#/oneOf/4/properties/compile/properties/parameters/anyOf/0/items/oneOf/0/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key8},message:"must NOT have additional properties"};
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
if(_errs49 === errors){
if(data12.int64 !== undefined){
let data13 = data12.int64;
const _errs50 = errors;
if(errors === _errs50){
if(typeof data13 === "string"){
if(func1(data13) > 131072){
const err43 = {instancePath:instancePath+"/compile/parameters/" + i0+"/int64",schemaPath:"#/oneOf/4/properties/compile/properties/parameters/anyOf/0/items/oneOf/0/properties/int64/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err43];
}
else {
vErrors.push(err43);
}
errors++;
}
}
else {
const err44 = {instancePath:instancePath+"/compile/parameters/" + i0+"/int64",schemaPath:"#/oneOf/4/properties/compile/properties/parameters/anyOf/0/items/oneOf/0/properties/int64/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err44];
}
else {
vErrors.push(err44);
}
errors++;
}
}
}
}
}
}
else {
const err45 = {instancePath:instancePath+"/compile/parameters/" + i0,schemaPath:"#/oneOf/4/properties/compile/properties/parameters/anyOf/0/items/oneOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err45];
}
else {
vErrors.push(err45);
}
errors++;
}
}
var _valid2 = _errs47 === errors;
if(_valid2){
valid11 = true;
passing1 = 0;
var props1 = true;
}
const _errs52 = errors;
if(errors === _errs52){
if(data12 && typeof data12 == "object" && !Array.isArray(data12)){
let missing9;
if((data12.uint64 === undefined) && (missing9 = "uint64")){
const err46 = {instancePath:instancePath+"/compile/parameters/" + i0,schemaPath:"#/oneOf/4/properties/compile/properties/parameters/anyOf/0/items/oneOf/1/required",keyword:"required",params:{missingProperty: missing9},message:"must have required property '"+missing9+"'"};
if(vErrors === null){
vErrors = [err46];
}
else {
vErrors.push(err46);
}
errors++;
}
else {
const _errs54 = errors;
for(const key9 in data12){
if(!(key9 === "uint64")){
const err47 = {instancePath:instancePath+"/compile/parameters/" + i0,schemaPath:"#/oneOf/4/properties/compile/properties/parameters/anyOf/0/items/oneOf/1/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key9},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err47];
}
else {
vErrors.push(err47);
}
errors++;
break;
}
}
if(_errs54 === errors){
if(data12.uint64 !== undefined){
let data14 = data12.uint64;
const _errs55 = errors;
if(errors === _errs55){
if(typeof data14 === "string"){
if(func1(data14) > 131072){
const err48 = {instancePath:instancePath+"/compile/parameters/" + i0+"/uint64",schemaPath:"#/oneOf/4/properties/compile/properties/parameters/anyOf/0/items/oneOf/1/properties/uint64/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
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
const err49 = {instancePath:instancePath+"/compile/parameters/" + i0+"/uint64",schemaPath:"#/oneOf/4/properties/compile/properties/parameters/anyOf/0/items/oneOf/1/properties/uint64/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err49];
}
else {
vErrors.push(err49);
}
errors++;
}
}
}
}
}
}
else {
const err50 = {instancePath:instancePath+"/compile/parameters/" + i0,schemaPath:"#/oneOf/4/properties/compile/properties/parameters/anyOf/0/items/oneOf/1/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err50];
}
else {
vErrors.push(err50);
}
errors++;
}
}
var _valid2 = _errs52 === errors;
if(_valid2 && valid11){
valid11 = false;
passing1 = [passing1, 1];
}
else {
if(_valid2){
valid11 = true;
passing1 = 1;
if(props1 !== true){
props1 = true;
}
}
const _errs57 = errors;
if(errors === _errs57){
if(data12 && typeof data12 == "object" && !Array.isArray(data12)){
let missing10;
if((data12.float_bits === undefined) && (missing10 = "float_bits")){
const err51 = {instancePath:instancePath+"/compile/parameters/" + i0,schemaPath:"#/oneOf/4/properties/compile/properties/parameters/anyOf/0/items/oneOf/2/required",keyword:"required",params:{missingProperty: missing10},message:"must have required property '"+missing10+"'"};
if(vErrors === null){
vErrors = [err51];
}
else {
vErrors.push(err51);
}
errors++;
}
else {
const _errs59 = errors;
for(const key10 in data12){
if(!(key10 === "float_bits")){
const err52 = {instancePath:instancePath+"/compile/parameters/" + i0,schemaPath:"#/oneOf/4/properties/compile/properties/parameters/anyOf/0/items/oneOf/2/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key10},message:"must NOT have additional properties"};
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
if(_errs59 === errors){
if(data12.float_bits !== undefined){
let data15 = data12.float_bits;
const _errs60 = errors;
if(errors === _errs60){
if(typeof data15 === "string"){
if(func1(data15) > 131072){
const err53 = {instancePath:instancePath+"/compile/parameters/" + i0+"/float_bits",schemaPath:"#/oneOf/4/properties/compile/properties/parameters/anyOf/0/items/oneOf/2/properties/float_bits/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err53];
}
else {
vErrors.push(err53);
}
errors++;
}
}
else {
const err54 = {instancePath:instancePath+"/compile/parameters/" + i0+"/float_bits",schemaPath:"#/oneOf/4/properties/compile/properties/parameters/anyOf/0/items/oneOf/2/properties/float_bits/type",keyword:"type",params:{type: "string"},message:"must be string"};
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
const err55 = {instancePath:instancePath+"/compile/parameters/" + i0,schemaPath:"#/oneOf/4/properties/compile/properties/parameters/anyOf/0/items/oneOf/2/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err55];
}
else {
vErrors.push(err55);
}
errors++;
}
}
var _valid2 = _errs57 === errors;
if(_valid2 && valid11){
valid11 = false;
passing1 = [passing1, 2];
}
else {
if(_valid2){
valid11 = true;
passing1 = 2;
if(props1 !== true){
props1 = true;
}
}
const _errs62 = errors;
if(errors === _errs62){
if(data12 && typeof data12 == "object" && !Array.isArray(data12)){
let missing11;
if((data12.boolean === undefined) && (missing11 = "boolean")){
const err56 = {instancePath:instancePath+"/compile/parameters/" + i0,schemaPath:"#/oneOf/4/properties/compile/properties/parameters/anyOf/0/items/oneOf/3/required",keyword:"required",params:{missingProperty: missing11},message:"must have required property '"+missing11+"'"};
if(vErrors === null){
vErrors = [err56];
}
else {
vErrors.push(err56);
}
errors++;
}
else {
const _errs64 = errors;
for(const key11 in data12){
if(!(key11 === "boolean")){
const err57 = {instancePath:instancePath+"/compile/parameters/" + i0,schemaPath:"#/oneOf/4/properties/compile/properties/parameters/anyOf/0/items/oneOf/3/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key11},message:"must NOT have additional properties"};
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
if(_errs64 === errors){
if(data12.boolean !== undefined){
if(typeof data12.boolean !== "boolean"){
const err58 = {instancePath:instancePath+"/compile/parameters/" + i0+"/boolean",schemaPath:"#/oneOf/4/properties/compile/properties/parameters/anyOf/0/items/oneOf/3/properties/boolean/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"};
if(vErrors === null){
vErrors = [err58];
}
else {
vErrors.push(err58);
}
errors++;
}
}
}
}
}
else {
const err59 = {instancePath:instancePath+"/compile/parameters/" + i0,schemaPath:"#/oneOf/4/properties/compile/properties/parameters/anyOf/0/items/oneOf/3/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err59];
}
else {
vErrors.push(err59);
}
errors++;
}
}
var _valid2 = _errs62 === errors;
if(_valid2 && valid11){
valid11 = false;
passing1 = [passing1, 3];
}
else {
if(_valid2){
valid11 = true;
passing1 = 3;
if(props1 !== true){
props1 = true;
}
}
const _errs67 = errors;
if(errors === _errs67){
if(data12 && typeof data12 == "object" && !Array.isArray(data12)){
let missing12;
if((data12.utf8 === undefined) && (missing12 = "utf8")){
const err60 = {instancePath:instancePath+"/compile/parameters/" + i0,schemaPath:"#/oneOf/4/properties/compile/properties/parameters/anyOf/0/items/oneOf/4/required",keyword:"required",params:{missingProperty: missing12},message:"must have required property '"+missing12+"'"};
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
for(const key12 in data12){
if(!(key12 === "utf8")){
const err61 = {instancePath:instancePath+"/compile/parameters/" + i0,schemaPath:"#/oneOf/4/properties/compile/properties/parameters/anyOf/0/items/oneOf/4/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key12},message:"must NOT have additional properties"};
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
if(data12.utf8 !== undefined){
let data17 = data12.utf8;
const _errs70 = errors;
if(errors === _errs70){
if(typeof data17 === "string"){
if(func1(data17) > 131072){
const err62 = {instancePath:instancePath+"/compile/parameters/" + i0+"/utf8",schemaPath:"#/oneOf/4/properties/compile/properties/parameters/anyOf/0/items/oneOf/4/properties/utf8/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
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
const err63 = {instancePath:instancePath+"/compile/parameters/" + i0+"/utf8",schemaPath:"#/oneOf/4/properties/compile/properties/parameters/anyOf/0/items/oneOf/4/properties/utf8/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err63];
}
else {
vErrors.push(err63);
}
errors++;
}
}
}
}
}
}
else {
const err64 = {instancePath:instancePath+"/compile/parameters/" + i0,schemaPath:"#/oneOf/4/properties/compile/properties/parameters/anyOf/0/items/oneOf/4/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err64];
}
else {
vErrors.push(err64);
}
errors++;
}
}
var _valid2 = _errs67 === errors;
if(_valid2 && valid11){
valid11 = false;
passing1 = [passing1, 4];
}
else {
if(_valid2){
valid11 = true;
passing1 = 4;
if(props1 !== true){
props1 = true;
}
}
const _errs72 = errors;
if(errors === _errs72){
if(data12 && typeof data12 == "object" && !Array.isArray(data12)){
let missing13;
if((data12.binary === undefined) && (missing13 = "binary")){
const err65 = {instancePath:instancePath+"/compile/parameters/" + i0,schemaPath:"#/oneOf/4/properties/compile/properties/parameters/anyOf/0/items/oneOf/5/required",keyword:"required",params:{missingProperty: missing13},message:"must have required property '"+missing13+"'"};
if(vErrors === null){
vErrors = [err65];
}
else {
vErrors.push(err65);
}
errors++;
}
else {
const _errs74 = errors;
for(const key13 in data12){
if(!(key13 === "binary")){
const err66 = {instancePath:instancePath+"/compile/parameters/" + i0,schemaPath:"#/oneOf/4/properties/compile/properties/parameters/anyOf/0/items/oneOf/5/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key13},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err66];
}
else {
vErrors.push(err66);
}
errors++;
break;
}
}
if(_errs74 === errors){
if(data12.binary !== undefined){
let data18 = data12.binary;
const _errs75 = errors;
if(errors === _errs75){
if(typeof data18 === "string"){
if(func1(data18) > 131072){
const err67 = {instancePath:instancePath+"/compile/parameters/" + i0+"/binary",schemaPath:"#/oneOf/4/properties/compile/properties/parameters/anyOf/0/items/oneOf/5/properties/binary/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err67];
}
else {
vErrors.push(err67);
}
errors++;
}
}
else {
const err68 = {instancePath:instancePath+"/compile/parameters/" + i0+"/binary",schemaPath:"#/oneOf/4/properties/compile/properties/parameters/anyOf/0/items/oneOf/5/properties/binary/type",keyword:"type",params:{type: "string"},message:"must be string"};
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
const err69 = {instancePath:instancePath+"/compile/parameters/" + i0,schemaPath:"#/oneOf/4/properties/compile/properties/parameters/anyOf/0/items/oneOf/5/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err69];
}
else {
vErrors.push(err69);
}
errors++;
}
}
var _valid2 = _errs72 === errors;
if(_valid2 && valid11){
valid11 = false;
passing1 = [passing1, 5];
}
else {
if(_valid2){
valid11 = true;
passing1 = 5;
if(props1 !== true){
props1 = true;
}
}
}
}
}
}
}
if(!valid11){
const err70 = {instancePath:instancePath+"/compile/parameters/" + i0,schemaPath:"#/oneOf/4/properties/compile/properties/parameters/anyOf/0/items/oneOf",keyword:"oneOf",params:{passingSchemas: passing1},message:"must match exactly one schema in oneOf"};
if(vErrors === null){
vErrors = [err70];
}
else {
vErrors.push(err70);
}
errors++;
}
else {
errors = _errs46;
if(vErrors !== null){
if(_errs46){
vErrors.length = _errs46;
}
else {
vErrors = null;
}
}
}
var valid10 = _errs45 === errors;
if(!valid10){
break;
}
}
}
}
else {
const err71 = {instancePath:instancePath+"/compile/parameters",schemaPath:"#/oneOf/4/properties/compile/properties/parameters/anyOf/0/type",keyword:"type",params:{type: "array"},message:"must be array"};
if(vErrors === null){
vErrors = [err71];
}
else {
vErrors.push(err71);
}
errors++;
}
}
var _valid1 = _errs43 === errors;
valid9 = valid9 || _valid1;
const _errs77 = errors;
if(data11 !== null){
const err72 = {instancePath:instancePath+"/compile/parameters",schemaPath:"#/oneOf/4/properties/compile/properties/parameters/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err72];
}
else {
vErrors.push(err72);
}
errors++;
}
var _valid1 = _errs77 === errors;
valid9 = valid9 || _valid1;
if(!valid9){
const err73 = {instancePath:instancePath+"/compile/parameters",schemaPath:"#/oneOf/4/properties/compile/properties/parameters/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err73];
}
else {
vErrors.push(err73);
}
errors++;
}
else {
errors = _errs42;
if(vErrors !== null){
if(_errs42){
vErrors.length = _errs42;
}
else {
vErrors = null;
}
}
}
var valid8 = _errs41 === errors;
}
else {
var valid8 = true;
}
}
}
}
}
else {
const err74 = {instancePath:instancePath+"/compile",schemaPath:"#/oneOf/4/properties/compile/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err74];
}
else {
vErrors.push(err74);
}
errors++;
}
}
}
}
}
}
else {
const err75 = {instancePath,schemaPath:"#/oneOf/4/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err75];
}
else {
vErrors.push(err75);
}
errors++;
}
}
var _valid0 = _errs33 === errors;
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
const _errs79 = errors;
if(errors === _errs79){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing14;
if((data.inspect === undefined) && (missing14 = "inspect")){
const err76 = {instancePath,schemaPath:"#/oneOf/5/required",keyword:"required",params:{missingProperty: missing14},message:"must have required property '"+missing14+"'"};
if(vErrors === null){
vErrors = [err76];
}
else {
vErrors.push(err76);
}
errors++;
}
else {
const _errs81 = errors;
for(const key14 in data){
if(!(key14 === "inspect")){
const err77 = {instancePath,schemaPath:"#/oneOf/5/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key14},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err77];
}
else {
vErrors.push(err77);
}
errors++;
break;
}
}
if(_errs81 === errors){
if(data.inspect !== undefined){
let data19 = data.inspect;
const _errs82 = errors;
if(errors === _errs82){
if(data19 && typeof data19 == "object" && !Array.isArray(data19)){
let missing15;
if((data19.sql === undefined) && (missing15 = "sql")){
const err78 = {instancePath:instancePath+"/inspect",schemaPath:"#/oneOf/5/properties/inspect/required",keyword:"required",params:{missingProperty: missing15},message:"must have required property '"+missing15+"'"};
if(vErrors === null){
vErrors = [err78];
}
else {
vErrors.push(err78);
}
errors++;
}
else {
const _errs84 = errors;
for(const key15 in data19){
if(!(key15 === "sql")){
const err79 = {instancePath:instancePath+"/inspect",schemaPath:"#/oneOf/5/properties/inspect/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key15},message:"must NOT have additional properties"};
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
if(_errs84 === errors){
if(data19.sql !== undefined){
let data20 = data19.sql;
const _errs85 = errors;
if(errors === _errs85){
if(typeof data20 === "string"){
if(func1(data20) > 131072){
const err80 = {instancePath:instancePath+"/inspect/sql",schemaPath:"#/oneOf/5/properties/inspect/properties/sql/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
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
const err81 = {instancePath:instancePath+"/inspect/sql",schemaPath:"#/oneOf/5/properties/inspect/properties/sql/type",keyword:"type",params:{type: "string"},message:"must be string"};
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
const err82 = {instancePath:instancePath+"/inspect",schemaPath:"#/oneOf/5/properties/inspect/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err82];
}
else {
vErrors.push(err82);
}
errors++;
}
}
}
}
}
}
else {
const err83 = {instancePath,schemaPath:"#/oneOf/5/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err83];
}
else {
vErrors.push(err83);
}
errors++;
}
}
var _valid0 = _errs79 === errors;
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
const _errs87 = errors;
if(errors === _errs87){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing16;
if((data.next === undefined) && (missing16 = "next")){
const err84 = {instancePath,schemaPath:"#/oneOf/6/required",keyword:"required",params:{missingProperty: missing16},message:"must have required property '"+missing16+"'"};
if(vErrors === null){
vErrors = [err84];
}
else {
vErrors.push(err84);
}
errors++;
}
else {
const _errs89 = errors;
for(const key16 in data){
if(!(key16 === "next")){
const err85 = {instancePath,schemaPath:"#/oneOf/6/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key16},message:"must NOT have additional properties"};
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
if(_errs89 === errors){
if(data.next !== undefined){
let data21 = data.next;
const _errs90 = errors;
if(errors === _errs90){
if(data21 && typeof data21 == "object" && !Array.isArray(data21)){
let missing17;
if(((data21.namespace === undefined) && (missing17 = "namespace")) || ((data21.bundle === undefined) && (missing17 = "bundle"))){
const err86 = {instancePath:instancePath+"/next",schemaPath:"#/oneOf/6/properties/next/required",keyword:"required",params:{missingProperty: missing17},message:"must have required property '"+missing17+"'"};
if(vErrors === null){
vErrors = [err86];
}
else {
vErrors.push(err86);
}
errors++;
}
else {
const _errs92 = errors;
for(const key17 in data21){
if(!((key17 === "namespace") || (key17 === "bundle"))){
const err87 = {instancePath:instancePath+"/next",schemaPath:"#/oneOf/6/properties/next/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key17},message:"must NOT have additional properties"};
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
if(_errs92 === errors){
if(data21.namespace !== undefined){
let data22 = data21.namespace;
const _errs93 = errors;
if(errors === _errs93){
if(typeof data22 === "string"){
if(func1(data22) > 131072){
const err88 = {instancePath:instancePath+"/next/namespace",schemaPath:"#/oneOf/6/properties/next/properties/namespace/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err88];
}
else {
vErrors.push(err88);
}
errors++;
}
}
else {
const err89 = {instancePath:instancePath+"/next/namespace",schemaPath:"#/oneOf/6/properties/next/properties/namespace/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err89];
}
else {
vErrors.push(err89);
}
errors++;
}
}
var valid21 = _errs93 === errors;
}
else {
var valid21 = true;
}
if(valid21){
if(data21.bundle !== undefined){
let data23 = data21.bundle;
const _errs95 = errors;
if(errors === _errs95){
if(typeof data23 === "string"){
if(func1(data23) > 131072){
const err90 = {instancePath:instancePath+"/next/bundle",schemaPath:"#/oneOf/6/properties/next/properties/bundle/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err90];
}
else {
vErrors.push(err90);
}
errors++;
}
}
else {
const err91 = {instancePath:instancePath+"/next/bundle",schemaPath:"#/oneOf/6/properties/next/properties/bundle/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err91];
}
else {
vErrors.push(err91);
}
errors++;
}
}
var valid21 = _errs95 === errors;
}
else {
var valid21 = true;
}
}
}
}
}
else {
const err92 = {instancePath:instancePath+"/next",schemaPath:"#/oneOf/6/properties/next/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err92];
}
else {
vErrors.push(err92);
}
errors++;
}
}
}
}
}
}
else {
const err93 = {instancePath,schemaPath:"#/oneOf/6/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err93];
}
else {
vErrors.push(err93);
}
errors++;
}
}
var _valid0 = _errs87 === errors;
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
const _errs97 = errors;
if(errors === _errs97){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing18;
if((data.next_draft === undefined) && (missing18 = "next_draft")){
const err94 = {instancePath,schemaPath:"#/oneOf/7/required",keyword:"required",params:{missingProperty: missing18},message:"must have required property '"+missing18+"'"};
if(vErrors === null){
vErrors = [err94];
}
else {
vErrors.push(err94);
}
errors++;
}
else {
const _errs99 = errors;
for(const key18 in data){
if(!(key18 === "next_draft")){
const err95 = {instancePath,schemaPath:"#/oneOf/7/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key18},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err95];
}
else {
vErrors.push(err95);
}
errors++;
break;
}
}
if(_errs99 === errors){
if(data.next_draft !== undefined){
let data24 = data.next_draft;
const _errs100 = errors;
if(errors === _errs100){
if(data24 && typeof data24 == "object" && !Array.isArray(data24)){
let missing19;
if((((data24.namespace === undefined) && (missing19 = "namespace")) || ((data24.bundle === undefined) && (missing19 = "bundle"))) || ((data24.generation === undefined) && (missing19 = "generation"))){
const err96 = {instancePath:instancePath+"/next_draft",schemaPath:"#/oneOf/7/properties/next_draft/required",keyword:"required",params:{missingProperty: missing19},message:"must have required property '"+missing19+"'"};
if(vErrors === null){
vErrors = [err96];
}
else {
vErrors.push(err96);
}
errors++;
}
else {
const _errs102 = errors;
for(const key19 in data24){
if(!(((key19 === "namespace") || (key19 === "bundle")) || (key19 === "generation"))){
const err97 = {instancePath:instancePath+"/next_draft",schemaPath:"#/oneOf/7/properties/next_draft/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key19},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err97];
}
else {
vErrors.push(err97);
}
errors++;
break;
}
}
if(_errs102 === errors){
if(data24.namespace !== undefined){
let data25 = data24.namespace;
const _errs103 = errors;
if(errors === _errs103){
if(typeof data25 === "string"){
if(func1(data25) > 131072){
const err98 = {instancePath:instancePath+"/next_draft/namespace",schemaPath:"#/oneOf/7/properties/next_draft/properties/namespace/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err98];
}
else {
vErrors.push(err98);
}
errors++;
}
}
else {
const err99 = {instancePath:instancePath+"/next_draft/namespace",schemaPath:"#/oneOf/7/properties/next_draft/properties/namespace/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err99];
}
else {
vErrors.push(err99);
}
errors++;
}
}
var valid23 = _errs103 === errors;
}
else {
var valid23 = true;
}
if(valid23){
if(data24.bundle !== undefined){
let data26 = data24.bundle;
const _errs105 = errors;
if(errors === _errs105){
if(typeof data26 === "string"){
if(func1(data26) > 131072){
const err100 = {instancePath:instancePath+"/next_draft/bundle",schemaPath:"#/oneOf/7/properties/next_draft/properties/bundle/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err100];
}
else {
vErrors.push(err100);
}
errors++;
}
}
else {
const err101 = {instancePath:instancePath+"/next_draft/bundle",schemaPath:"#/oneOf/7/properties/next_draft/properties/bundle/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err101];
}
else {
vErrors.push(err101);
}
errors++;
}
}
var valid23 = _errs105 === errors;
}
else {
var valid23 = true;
}
if(valid23){
if(data24.generation !== undefined){
let data27 = data24.generation;
const _errs107 = errors;
if(errors === _errs107){
if(typeof data27 === "string"){
if(func1(data27) > 131072){
const err102 = {instancePath:instancePath+"/next_draft/generation",schemaPath:"#/oneOf/7/properties/next_draft/properties/generation/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
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
const err103 = {instancePath:instancePath+"/next_draft/generation",schemaPath:"#/oneOf/7/properties/next_draft/properties/generation/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err103];
}
else {
vErrors.push(err103);
}
errors++;
}
}
var valid23 = _errs107 === errors;
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
const err104 = {instancePath:instancePath+"/next_draft",schemaPath:"#/oneOf/7/properties/next_draft/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err104];
}
else {
vErrors.push(err104);
}
errors++;
}
}
}
}
}
}
else {
const err105 = {instancePath,schemaPath:"#/oneOf/7/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err105];
}
else {
vErrors.push(err105);
}
errors++;
}
}
var _valid0 = _errs97 === errors;
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
const _errs109 = errors;
if(errors === _errs109){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing20;
if((data.draft_open === undefined) && (missing20 = "draft_open")){
const err106 = {instancePath,schemaPath:"#/oneOf/8/required",keyword:"required",params:{missingProperty: missing20},message:"must have required property '"+missing20+"'"};
if(vErrors === null){
vErrors = [err106];
}
else {
vErrors.push(err106);
}
errors++;
}
else {
const _errs111 = errors;
for(const key20 in data){
if(!(key20 === "draft_open")){
const err107 = {instancePath,schemaPath:"#/oneOf/8/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key20},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err107];
}
else {
vErrors.push(err107);
}
errors++;
break;
}
}
if(_errs111 === errors){
if(data.draft_open !== undefined){
let data28 = data.draft_open;
const _errs112 = errors;
if(errors === _errs112){
if(data28 && typeof data28 == "object" && !Array.isArray(data28)){
let missing21;
if(((data28.expected === undefined) && (missing21 = "expected")) || ((data28.limit === undefined) && (missing21 = "limit"))){
const err108 = {instancePath:instancePath+"/draft_open",schemaPath:"#/oneOf/8/properties/draft_open/required",keyword:"required",params:{missingProperty: missing21},message:"must have required property '"+missing21+"'"};
if(vErrors === null){
vErrors = [err108];
}
else {
vErrors.push(err108);
}
errors++;
}
else {
const _errs114 = errors;
for(const key21 in data28){
if(!((key21 === "expected") || (key21 === "limit"))){
const err109 = {instancePath:instancePath+"/draft_open",schemaPath:"#/oneOf/8/properties/draft_open/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key21},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err109];
}
else {
vErrors.push(err109);
}
errors++;
break;
}
}
if(_errs114 === errors){
if(data28.expected !== undefined){
let data29 = data28.expected;
const _errs115 = errors;
if(errors === _errs115){
if(typeof data29 === "string"){
if(func1(data29) > 131072){
const err110 = {instancePath:instancePath+"/draft_open/expected",schemaPath:"#/oneOf/8/properties/draft_open/properties/expected/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err110];
}
else {
vErrors.push(err110);
}
errors++;
}
}
else {
const err111 = {instancePath:instancePath+"/draft_open/expected",schemaPath:"#/oneOf/8/properties/draft_open/properties/expected/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err111];
}
else {
vErrors.push(err111);
}
errors++;
}
}
var valid25 = _errs115 === errors;
}
else {
var valid25 = true;
}
if(valid25){
if(data28.limit !== undefined){
let data30 = data28.limit;
const _errs117 = errors;
if(!(((typeof data30 == "number") && (!(data30 % 1) && !isNaN(data30))) && (isFinite(data30)))){
const err112 = {instancePath:instancePath+"/draft_open/limit",schemaPath:"#/oneOf/8/properties/draft_open/properties/limit/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err112];
}
else {
vErrors.push(err112);
}
errors++;
}
if(errors === _errs117){
if((typeof data30 == "number") && (isFinite(data30))){
if(data30 > 255 || isNaN(data30)){
const err113 = {instancePath:instancePath+"/draft_open/limit",schemaPath:"#/oneOf/8/properties/draft_open/properties/limit/maximum",keyword:"maximum",params:{comparison: "<=", limit: 255},message:"must be <= 255"};
if(vErrors === null){
vErrors = [err113];
}
else {
vErrors.push(err113);
}
errors++;
}
else {
if(data30 < 0 || isNaN(data30)){
const err114 = {instancePath:instancePath+"/draft_open/limit",schemaPath:"#/oneOf/8/properties/draft_open/properties/limit/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err114];
}
else {
vErrors.push(err114);
}
errors++;
}
}
}
}
var valid25 = _errs117 === errors;
}
else {
var valid25 = true;
}
}
}
}
}
else {
const err115 = {instancePath:instancePath+"/draft_open",schemaPath:"#/oneOf/8/properties/draft_open/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err115];
}
else {
vErrors.push(err115);
}
errors++;
}
}
}
}
}
}
else {
const err116 = {instancePath,schemaPath:"#/oneOf/8/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err116];
}
else {
vErrors.push(err116);
}
errors++;
}
}
var _valid0 = _errs109 === errors;
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
const _errs119 = errors;
if(errors === _errs119){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing22;
if((data.draft_close === undefined) && (missing22 = "draft_close")){
const err117 = {instancePath,schemaPath:"#/oneOf/9/required",keyword:"required",params:{missingProperty: missing22},message:"must have required property '"+missing22+"'"};
if(vErrors === null){
vErrors = [err117];
}
else {
vErrors.push(err117);
}
errors++;
}
else {
const _errs121 = errors;
for(const key22 in data){
if(!(key22 === "draft_close")){
const err118 = {instancePath,schemaPath:"#/oneOf/9/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key22},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err118];
}
else {
vErrors.push(err118);
}
errors++;
break;
}
}
if(_errs121 === errors){
if(data.draft_close !== undefined){
let data31 = data.draft_close;
const _errs122 = errors;
if(errors === _errs122){
if(typeof data31 === "string"){
if(func1(data31) > 131072){
const err119 = {instancePath:instancePath+"/draft_close",schemaPath:"#/oneOf/9/properties/draft_close/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err119];
}
else {
vErrors.push(err119);
}
errors++;
}
}
else {
const err120 = {instancePath:instancePath+"/draft_close",schemaPath:"#/oneOf/9/properties/draft_close/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err120];
}
else {
vErrors.push(err120);
}
errors++;
}
}
}
}
}
}
else {
const err121 = {instancePath,schemaPath:"#/oneOf/9/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err121];
}
else {
vErrors.push(err121);
}
errors++;
}
}
var _valid0 = _errs119 === errors;
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
const _errs124 = errors;
if(errors === _errs124){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing23;
if((data.draft_status === undefined) && (missing23 = "draft_status")){
const err122 = {instancePath,schemaPath:"#/oneOf/10/required",keyword:"required",params:{missingProperty: missing23},message:"must have required property '"+missing23+"'"};
if(vErrors === null){
vErrors = [err122];
}
else {
vErrors.push(err122);
}
errors++;
}
else {
const _errs126 = errors;
for(const key23 in data){
if(!(key23 === "draft_status")){
const err123 = {instancePath,schemaPath:"#/oneOf/10/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key23},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err123];
}
else {
vErrors.push(err123);
}
errors++;
break;
}
}
if(_errs126 === errors){
if(data.draft_status !== undefined){
let data32 = data.draft_status;
const _errs128 = errors;
let valid28 = false;
const _errs129 = errors;
if(errors === _errs129){
if(typeof data32 === "string"){
if(func1(data32) > 131072){
const err124 = {instancePath:instancePath+"/draft_status",schemaPath:"#/oneOf/10/properties/draft_status/anyOf/0/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err124];
}
else {
vErrors.push(err124);
}
errors++;
}
}
else {
const err125 = {instancePath:instancePath+"/draft_status",schemaPath:"#/oneOf/10/properties/draft_status/anyOf/0/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err125];
}
else {
vErrors.push(err125);
}
errors++;
}
}
var _valid3 = _errs129 === errors;
valid28 = valid28 || _valid3;
const _errs131 = errors;
if(data32 !== null){
const err126 = {instancePath:instancePath+"/draft_status",schemaPath:"#/oneOf/10/properties/draft_status/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err126];
}
else {
vErrors.push(err126);
}
errors++;
}
var _valid3 = _errs131 === errors;
valid28 = valid28 || _valid3;
if(!valid28){
const err127 = {instancePath:instancePath+"/draft_status",schemaPath:"#/oneOf/10/properties/draft_status/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err127];
}
else {
vErrors.push(err127);
}
errors++;
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
}
}
}
}
else {
const err128 = {instancePath,schemaPath:"#/oneOf/10/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err128];
}
else {
vErrors.push(err128);
}
errors++;
}
}
var _valid0 = _errs124 === errors;
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
const _errs133 = errors;
if(errors === _errs133){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing24;
if((data.submit === undefined) && (missing24 = "submit")){
const err129 = {instancePath,schemaPath:"#/oneOf/11/required",keyword:"required",params:{missingProperty: missing24},message:"must have required property '"+missing24+"'"};
if(vErrors === null){
vErrors = [err129];
}
else {
vErrors.push(err129);
}
errors++;
}
else {
const _errs135 = errors;
for(const key24 in data){
if(!(key24 === "submit")){
const err130 = {instancePath,schemaPath:"#/oneOf/11/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key24},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err130];
}
else {
vErrors.push(err130);
}
errors++;
break;
}
}
if(_errs135 === errors){
if(data.submit !== undefined){
let data33 = data.submit;
const _errs136 = errors;
if(errors === _errs136){
if(data33 && typeof data33 == "object" && !Array.isArray(data33)){
let missing25;
if((data33.token === undefined) && (missing25 = "token")){
const err131 = {instancePath:instancePath+"/submit",schemaPath:"#/oneOf/11/properties/submit/required",keyword:"required",params:{missingProperty: missing25},message:"must have required property '"+missing25+"'"};
if(vErrors === null){
vErrors = [err131];
}
else {
vErrors.push(err131);
}
errors++;
}
else {
const _errs138 = errors;
for(const key25 in data33){
if(!(key25 === "token")){
const err132 = {instancePath:instancePath+"/submit",schemaPath:"#/oneOf/11/properties/submit/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key25},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err132];
}
else {
vErrors.push(err132);
}
errors++;
break;
}
}
if(_errs138 === errors){
if(data33.token !== undefined){
let data34 = data33.token;
const _errs139 = errors;
if(errors === _errs139){
if(typeof data34 === "string"){
if(func1(data34) > 131072){
const err133 = {instancePath:instancePath+"/submit/token",schemaPath:"#/oneOf/11/properties/submit/properties/token/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err133];
}
else {
vErrors.push(err133);
}
errors++;
}
}
else {
const err134 = {instancePath:instancePath+"/submit/token",schemaPath:"#/oneOf/11/properties/submit/properties/token/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err134];
}
else {
vErrors.push(err134);
}
errors++;
}
}
}
}
}
}
else {
const err135 = {instancePath:instancePath+"/submit",schemaPath:"#/oneOf/11/properties/submit/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err135];
}
else {
vErrors.push(err135);
}
errors++;
}
}
}
}
}
}
else {
const err136 = {instancePath,schemaPath:"#/oneOf/11/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err136];
}
else {
vErrors.push(err136);
}
errors++;
}
}
var _valid0 = _errs133 === errors;
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
const _errs141 = errors;
if(errors === _errs141){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing26;
if((data.observe === undefined) && (missing26 = "observe")){
const err137 = {instancePath,schemaPath:"#/oneOf/12/required",keyword:"required",params:{missingProperty: missing26},message:"must have required property '"+missing26+"'"};
if(vErrors === null){
vErrors = [err137];
}
else {
vErrors.push(err137);
}
errors++;
}
else {
const _errs143 = errors;
for(const key26 in data){
if(!(key26 === "observe")){
const err138 = {instancePath,schemaPath:"#/oneOf/12/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key26},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err138];
}
else {
vErrors.push(err138);
}
errors++;
break;
}
}
if(_errs143 === errors){
if(data.observe !== undefined){
let data35 = data.observe;
const _errs144 = errors;
if(!(((typeof data35 == "number") && (!(data35 % 1) && !isNaN(data35))) && (isFinite(data35)))){
const err139 = {instancePath:instancePath+"/observe",schemaPath:"#/oneOf/12/properties/observe/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err139];
}
else {
vErrors.push(err139);
}
errors++;
}
if(errors === _errs144){
if((typeof data35 == "number") && (isFinite(data35))){
if(data35 > 9007199254740991 || isNaN(data35)){
const err140 = {instancePath:instancePath+"/observe",schemaPath:"#/oneOf/12/properties/observe/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"};
if(vErrors === null){
vErrors = [err140];
}
else {
vErrors.push(err140);
}
errors++;
}
else {
if(data35 < 0 || isNaN(data35)){
const err141 = {instancePath:instancePath+"/observe",schemaPath:"#/oneOf/12/properties/observe/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err141];
}
else {
vErrors.push(err141);
}
errors++;
}
}
}
}
}
}
}
}
else {
const err142 = {instancePath,schemaPath:"#/oneOf/12/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err142];
}
else {
vErrors.push(err142);
}
errors++;
}
}
var _valid0 = _errs141 === errors;
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
const _errs146 = errors;
if(errors === _errs146){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing27;
if((data.status === undefined) && (missing27 = "status")){
const err143 = {instancePath,schemaPath:"#/oneOf/13/required",keyword:"required",params:{missingProperty: missing27},message:"must have required property '"+missing27+"'"};
if(vErrors === null){
vErrors = [err143];
}
else {
vErrors.push(err143);
}
errors++;
}
else {
const _errs148 = errors;
for(const key27 in data){
if(!(key27 === "status")){
const err144 = {instancePath,schemaPath:"#/oneOf/13/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key27},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err144];
}
else {
vErrors.push(err144);
}
errors++;
break;
}
}
if(_errs148 === errors){
if(data.status !== undefined){
let data36 = data.status;
const _errs149 = errors;
if(errors === _errs149){
if(typeof data36 === "string"){
if(func1(data36) > 131072){
const err145 = {instancePath:instancePath+"/status",schemaPath:"#/oneOf/13/properties/status/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err145];
}
else {
vErrors.push(err145);
}
errors++;
}
}
else {
const err146 = {instancePath:instancePath+"/status",schemaPath:"#/oneOf/13/properties/status/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err146];
}
else {
vErrors.push(err146);
}
errors++;
}
}
}
}
}
}
else {
const err147 = {instancePath,schemaPath:"#/oneOf/13/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err147];
}
else {
vErrors.push(err147);
}
errors++;
}
}
var _valid0 = _errs146 === errors;
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
const _errs151 = errors;
if(errors === _errs151){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing28;
if((data.page === undefined) && (missing28 = "page")){
const err148 = {instancePath,schemaPath:"#/oneOf/14/required",keyword:"required",params:{missingProperty: missing28},message:"must have required property '"+missing28+"'"};
if(vErrors === null){
vErrors = [err148];
}
else {
vErrors.push(err148);
}
errors++;
}
else {
const _errs153 = errors;
for(const key28 in data){
if(!(key28 === "page")){
const err149 = {instancePath,schemaPath:"#/oneOf/14/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key28},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err149];
}
else {
vErrors.push(err149);
}
errors++;
break;
}
}
if(_errs153 === errors){
if(data.page !== undefined){
let data37 = data.page;
const _errs154 = errors;
if(errors === _errs154){
if(data37 && typeof data37 == "object" && !Array.isArray(data37)){
let missing29;
if((data37.namespace === undefined) && (missing29 = "namespace")){
const err150 = {instancePath:instancePath+"/page",schemaPath:"#/oneOf/14/properties/page/required",keyword:"required",params:{missingProperty: missing29},message:"must have required property '"+missing29+"'"};
if(vErrors === null){
vErrors = [err150];
}
else {
vErrors.push(err150);
}
errors++;
}
else {
const _errs156 = errors;
for(const key29 in data37){
if(!((key29 === "namespace") || (key29 === "cursor"))){
const err151 = {instancePath:instancePath+"/page",schemaPath:"#/oneOf/14/properties/page/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key29},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err151];
}
else {
vErrors.push(err151);
}
errors++;
break;
}
}
if(_errs156 === errors){
if(data37.namespace !== undefined){
let data38 = data37.namespace;
const _errs157 = errors;
if(errors === _errs157){
if(typeof data38 === "string"){
if(func1(data38) > 131072){
const err152 = {instancePath:instancePath+"/page/namespace",schemaPath:"#/oneOf/14/properties/page/properties/namespace/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err152];
}
else {
vErrors.push(err152);
}
errors++;
}
}
else {
const err153 = {instancePath:instancePath+"/page/namespace",schemaPath:"#/oneOf/14/properties/page/properties/namespace/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err153];
}
else {
vErrors.push(err153);
}
errors++;
}
}
var valid34 = _errs157 === errors;
}
else {
var valid34 = true;
}
if(valid34){
if(data37.cursor !== undefined){
let data39 = data37.cursor;
const _errs159 = errors;
const _errs160 = errors;
let valid35 = false;
const _errs161 = errors;
if(errors === _errs161){
if(typeof data39 === "string"){
if(func1(data39) > 131072){
const err154 = {instancePath:instancePath+"/page/cursor",schemaPath:"#/oneOf/14/properties/page/properties/cursor/anyOf/0/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err154];
}
else {
vErrors.push(err154);
}
errors++;
}
}
else {
const err155 = {instancePath:instancePath+"/page/cursor",schemaPath:"#/oneOf/14/properties/page/properties/cursor/anyOf/0/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err155];
}
else {
vErrors.push(err155);
}
errors++;
}
}
var _valid4 = _errs161 === errors;
valid35 = valid35 || _valid4;
const _errs163 = errors;
if(data39 !== null){
const err156 = {instancePath:instancePath+"/page/cursor",schemaPath:"#/oneOf/14/properties/page/properties/cursor/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err156];
}
else {
vErrors.push(err156);
}
errors++;
}
var _valid4 = _errs163 === errors;
valid35 = valid35 || _valid4;
if(!valid35){
const err157 = {instancePath:instancePath+"/page/cursor",schemaPath:"#/oneOf/14/properties/page/properties/cursor/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err157];
}
else {
vErrors.push(err157);
}
errors++;
}
else {
errors = _errs160;
if(vErrors !== null){
if(_errs160){
vErrors.length = _errs160;
}
else {
vErrors = null;
}
}
}
var valid34 = _errs159 === errors;
}
else {
var valid34 = true;
}
}
}
}
}
else {
const err158 = {instancePath:instancePath+"/page",schemaPath:"#/oneOf/14/properties/page/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err158];
}
else {
vErrors.push(err158);
}
errors++;
}
}
}
}
}
}
else {
const err159 = {instancePath,schemaPath:"#/oneOf/14/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err159];
}
else {
vErrors.push(err159);
}
errors++;
}
}
var _valid0 = _errs151 === errors;
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
const _errs165 = errors;
if(errors === _errs165){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing30;
if((data.prepare_control === undefined) && (missing30 = "prepare_control")){
const err160 = {instancePath,schemaPath:"#/oneOf/15/required",keyword:"required",params:{missingProperty: missing30},message:"must have required property '"+missing30+"'"};
if(vErrors === null){
vErrors = [err160];
}
else {
vErrors.push(err160);
}
errors++;
}
else {
const _errs167 = errors;
for(const key30 in data){
if(!(key30 === "prepare_control")){
const err161 = {instancePath,schemaPath:"#/oneOf/15/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key30},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err161];
}
else {
vErrors.push(err161);
}
errors++;
break;
}
}
if(_errs167 === errors){
if(data.prepare_control !== undefined){
let data40 = data.prepare_control;
const _errs168 = errors;
if(errors === _errs168){
if(data40 && typeof data40 == "object" && !Array.isArray(data40)){
let missing31;
if(((data40.namespace === undefined) && (missing31 = "namespace")) || ((data40.operation === undefined) && (missing31 = "operation"))){
const err162 = {instancePath:instancePath+"/prepare_control",schemaPath:"#/oneOf/15/properties/prepare_control/required",keyword:"required",params:{missingProperty: missing31},message:"must have required property '"+missing31+"'"};
if(vErrors === null){
vErrors = [err162];
}
else {
vErrors.push(err162);
}
errors++;
}
else {
const _errs170 = errors;
for(const key31 in data40){
if(!((key31 === "namespace") || (key31 === "operation"))){
const err163 = {instancePath:instancePath+"/prepare_control",schemaPath:"#/oneOf/15/properties/prepare_control/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key31},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err163];
}
else {
vErrors.push(err163);
}
errors++;
break;
}
}
if(_errs170 === errors){
if(data40.namespace !== undefined){
let data41 = data40.namespace;
const _errs171 = errors;
if(errors === _errs171){
if(typeof data41 === "string"){
if(func1(data41) > 131072){
const err164 = {instancePath:instancePath+"/prepare_control/namespace",schemaPath:"#/oneOf/15/properties/prepare_control/properties/namespace/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err164];
}
else {
vErrors.push(err164);
}
errors++;
}
}
else {
const err165 = {instancePath:instancePath+"/prepare_control/namespace",schemaPath:"#/oneOf/15/properties/prepare_control/properties/namespace/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err165];
}
else {
vErrors.push(err165);
}
errors++;
}
}
var valid37 = _errs171 === errors;
}
else {
var valid37 = true;
}
if(valid37){
if(data40.operation !== undefined){
let data42 = data40.operation;
const _errs173 = errors;
if(typeof data42 !== "string"){
const err166 = {instancePath:instancePath+"/prepare_control/operation",schemaPath:"#/oneOf/15/properties/prepare_control/properties/operation/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err166];
}
else {
vErrors.push(err166);
}
errors++;
}
if(!(((data42 === "cancel") || (data42 === "collect")) || (data42 === "retire"))){
const err167 = {instancePath:instancePath+"/prepare_control/operation",schemaPath:"#/oneOf/15/properties/prepare_control/properties/operation/enum",keyword:"enum",params:{allowedValues: schema32.oneOf[15].properties.prepare_control.properties.operation.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err167];
}
else {
vErrors.push(err167);
}
errors++;
}
var valid37 = _errs173 === errors;
}
else {
var valid37 = true;
}
}
}
}
}
else {
const err168 = {instancePath:instancePath+"/prepare_control",schemaPath:"#/oneOf/15/properties/prepare_control/type",keyword:"type",params:{type: "object"},message:"must be object"};
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
const err169 = {instancePath,schemaPath:"#/oneOf/15/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err169];
}
else {
vErrors.push(err169);
}
errors++;
}
}
var _valid0 = _errs165 === errors;
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
const err170 = {instancePath,schemaPath:"#/oneOf",keyword:"oneOf",params:{passingSchemas: passing0},message:"must match exactly one schema in oneOf"};
if(vErrors === null){
vErrors = [err170];
}
else {
vErrors.push(err170);
}
errors++;
validate21.errors = vErrors;
return false;
}
else {
errors = _errs0;
if(vErrors !== null){
if(_errs0){
vErrors.length = _errs0;
}
else {
vErrors = null;
}
}
}
validate21.errors = vErrors;
evaluated0.props = props0;
return errors === 0;
}
validate21.evaluated = {"dynamicProps":true,"dynamicItems":false};

export const Response = validate22;
const schema33 = {"oneOf":[{"type":"object","additionalProperties":false,"required":["description"],"properties":{"description":{"type":"object","additionalProperties":false,"properties":{"connection":{"type":"object","additionalProperties":false,"properties":{"realm":{"type":"integer","minimum":0,"maximum":9007199254740991},"principal":{"type":"integer","minimum":0,"maximum":9007199254740991},"source":{"type":"integer","minimum":0,"maximum":9007199254740991},"resource":{"type":"integer","minimum":0,"maximum":9007199254740991},"requester":{"type":"integer","minimum":0,"maximum":9007199254740991},"requests":{"type":"integer","minimum":0,"maximum":9007199254740991}},"required":["realm","principal","source","resource","requester","requests"]},"name":{"type":"string","maxLength":131072},"source":{"type":"object","additionalProperties":false,"properties":{"capabilities":{"type":"object","additionalProperties":false,"properties":{"version":{"type":"integer","minimum":0,"maximum":255},"source":{"type":"integer","minimum":0,"maximum":255},"plan":{"type":"integer","minimum":0,"maximum":255},"result":{"type":"integer","minimum":0,"maximum":255},"bundle_bytes":{"type":"integer","minimum":0,"maximum":4294967295},"part_bytes":{"type":"integer","minimum":0,"maximum":65535},"segment_bytes":{"type":"integer","minimum":0,"maximum":4294967295},"batch_rows":{"type":"integer","minimum":0,"maximum":255},"columns":{"type":"integer","minimum":0,"maximum":255},"kv":{"type":"boolean"},"table":{"type":"boolean"},"document":{"type":"boolean"}},"required":["version","source","plan","result","bundle_bytes","part_bytes","segment_bytes","batch_rows","columns","kv","table","document"]},"source":{"type":"object","additionalProperties":false,"properties":{"version":{"type":"integer","minimum":0,"maximum":255},"resource":{"type":"integer","minimum":0,"maximum":9007199254740991},"source":{"oneOf":[{"type":"object","additionalProperties":false,"required":["kv"],"properties":{"kv":{"type":"object","additionalProperties":false,"properties":{"prefix":{"type":"string","maxLength":131072},"key":{"type":"object","additionalProperties":false,"properties":{"version":{"type":"integer","minimum":0,"maximum":255},"type":{"type":"string","enum":["int64","uint64","float64","boolean","utf8","binary"]}},"required":["version","type"]},"value":{"type":"object","additionalProperties":false,"properties":{"version":{"type":"integer","minimum":0,"maximum":255},"type":{"type":"string","enum":["int64","uint64","float64","boolean","utf8","binary"]}},"required":["version","type"]}},"required":["prefix","key","value"]}}},{"type":"object","additionalProperties":false,"required":["table"],"properties":{"table":{"type":"object","additionalProperties":false,"properties":{"id":{"type":"integer","minimum":0,"maximum":4294967295},"names":{"type":"array","minItems":2,"maxItems":2,"items":{"type":"string","maxLength":131072}},"value_type":{"type":"string","enum":["int64","boolean","utf8","binary"]}},"required":["id","names","value_type"]}}},{"type":"object","additionalProperties":false,"required":["document"],"properties":{"document":{"type":"object","additionalProperties":false,"properties":{"reference":{"type":"object","additionalProperties":false,"properties":{"resource":{"type":"integer","minimum":0,"maximum":9007199254740991},"document":{"type":"string","maxLength":131072},"epoch":{"type":"string","maxLength":131072},"type_revision":{"type":"integer","minimum":0,"maximum":4294967295},"revision":{"type":"string","maxLength":131072}},"required":["resource","document","epoch","type_revision","revision"]},"change_format":{"type":"integer","minimum":0,"maximum":4294967295},"expand":{"anyOf":[{"type":"array","maxItems":8,"items":{"type":"string","maxLength":131072}},{"type":"null"}]},"projections":{"type":"array","maxItems":8,"items":{"type":"object","additionalProperties":false,"properties":{"column":{"type":"object","additionalProperties":false,"properties":{"name":{"type":"string","maxLength":131072},"type":{"type":"string","enum":["int64","uint64","float64","boolean","utf8","binary"]}},"required":["name","type"]},"path":{"type":"array","maxItems":8,"items":{"type":"string","maxLength":131072}},"relative":{"type":"boolean"},"mode":{"type":"string","enum":["scalar","text","element_counter","element_replica"]},"text_bytes":{"type":"integer","minimum":0,"maximum":65535},"text_steps":{"type":"integer","minimum":0,"maximum":65535}},"required":["column","path","relative","mode","text_bytes","text_steps"]}}},"required":["reference","change_format","expand","projections"]}}}]}},"required":["version","resource","source"]},"resource_revision":{"type":"integer","minimum":0,"maximum":9007199254740991},"policy_revision":{"type":"string","maxLength":131072},"limits":{"type":"object","additionalProperties":false,"properties":{"pages":{"type":"string","maxLength":131072},"segments":{"type":"string","maxLength":131072},"result_bytes":{"type":"string","maxLength":131072}},"required":["pages","segments","result_bytes"]},"active":{"anyOf":[{"type":"string","maxLength":131072},{"type":"null"}]}},"required":["capabilities","source","resource_revision","policy_revision","limits","active"]},"sql":{"type":"object","additionalProperties":false,"properties":{"version":{"type":"integer","minimum":0,"maximum":255},"statement_bytes":{"type":"integer","minimum":0,"maximum":4294967295},"named_columns":{"type":"integer","minimum":0,"maximum":255},"star_columns":{"type":"integer","minimum":0,"maximum":255},"uint64_limits":{"type":"boolean"},"uint64_literals":{"type":"boolean"},"float64_literals":{"type":"boolean"},"null_comparison":{"type":"boolean"},"explicit_null_test":{"type":"boolean"},"writes":{"type":"boolean"},"continuous":{"type":"boolean"}},"required":["version","statement_bytes","named_columns","star_columns","uint64_limits","uint64_literals","float64_literals","null_comparison","explicit_null_test","writes","continuous"]},"budgets":{"type":"object","additionalProperties":false,"properties":{"pages":{"type":"string","maxLength":131072},"segments":{"type":"string","maxLength":131072},"result_bytes":{"type":"string","maxLength":131072}},"required":["pages","segments","result_bytes"]},"columns":{"type":"array","maxItems":8,"items":{"type":"object","additionalProperties":false,"properties":{"name":{"type":"string","maxLength":131072},"type":{"type":"string","enum":["int64","uint64","float64","boolean","utf8","binary"]}},"required":["name","type"]}}},"required":["connection","name","source","sql","budgets","columns"]}}},{"type":"object","additionalProperties":false,"required":["sql_capabilities"],"properties":{"sql_capabilities":{"type":"object","additionalProperties":false,"properties":{"version":{"type":"integer","minimum":0,"maximum":255},"parameters":{"type":"boolean"},"max_parameters":{"type":"integer","minimum":0,"maximum":255},"statement_bytes":{"type":"integer","minimum":0,"maximum":4294967295}},"required":["version","parameters","max_parameters","statement_bytes"]}}},{"type":"object","additionalProperties":false,"required":["suggestions"],"properties":{"suggestions":{"type":"object","additionalProperties":false,"properties":{"resource":{"type":"integer","minimum":0,"maximum":9007199254740991},"contract":{"type":"array","minItems":32,"maxItems":32,"items":{"type":"integer","minimum":0,"maximum":255}},"items":{"type":"array","maxItems":8,"items":{"type":"object","additionalProperties":false,"properties":{"label":{"type":"string","maxLength":131072},"sql":{"type":"string","maxLength":131072}},"required":["label","sql"]}}},"required":["resource","contract","items"]}}},{"type":"object","additionalProperties":false,"required":["assistance"],"properties":{"assistance":{"type":"object","additionalProperties":false,"properties":{"version":{"type":"integer","minimum":0,"maximum":255},"generation":{"type":"integer","minimum":0,"maximum":4294967295},"profile":{"type":"string","enum":["unified_v1"]},"resource":{"type":"integer","minimum":0,"maximum":9007199254740991},"contract":{"type":"array","minItems":32,"maxItems":32,"items":{"type":"integer","minimum":0,"maximum":255}},"resource_revision":{"type":"integer","minimum":0,"maximum":9007199254740991},"policy_revision":{"type":"string","maxLength":131072},"range":{"anyOf":[{"type":"object","additionalProperties":false,"properties":{"start":{"type":"integer","minimum":0,"maximum":65535},"end":{"type":"integer","minimum":0,"maximum":65535},"quoted":{"type":"boolean"}},"required":["start","end","quoted"]},{"type":"null"}]},"items":{"type":"array","maxItems":8,"items":{"type":"object","additionalProperties":false,"properties":{"text":{"type":"string","maxLength":131072},"kind":{"type":"string","enum":["keyword","source","column","symbol","literal","meta"]},"detail":{"type":"string","maxLength":131072}},"required":["text","kind","detail"]}}},"required":["version","generation","profile","resource","contract","resource_revision","policy_revision","range","items"]}}},{"type":"object","additionalProperties":false,"required":["compiled"],"properties":{"compiled":{"type":"object","additionalProperties":false,"properties":{"bundle":{"type":"string","maxLength":131072},"source":{"type":"object","additionalProperties":false,"properties":{"version":{"type":"integer","minimum":0,"maximum":255},"resource":{"type":"integer","minimum":0,"maximum":9007199254740991},"source":{"oneOf":[{"type":"object","additionalProperties":false,"required":["kv"],"properties":{"kv":{"type":"object","additionalProperties":false,"properties":{"prefix":{"type":"string","maxLength":131072},"key":{"type":"object","additionalProperties":false,"properties":{"version":{"type":"integer","minimum":0,"maximum":255},"type":{"type":"string","enum":["int64","uint64","float64","boolean","utf8","binary"]}},"required":["version","type"]},"value":{"type":"object","additionalProperties":false,"properties":{"version":{"type":"integer","minimum":0,"maximum":255},"type":{"type":"string","enum":["int64","uint64","float64","boolean","utf8","binary"]}},"required":["version","type"]}},"required":["prefix","key","value"]}}},{"type":"object","additionalProperties":false,"required":["table"],"properties":{"table":{"type":"object","additionalProperties":false,"properties":{"id":{"type":"integer","minimum":0,"maximum":4294967295},"names":{"type":"array","minItems":2,"maxItems":2,"items":{"type":"string","maxLength":131072}},"value_type":{"type":"string","enum":["int64","boolean","utf8","binary"]}},"required":["id","names","value_type"]}}},{"type":"object","additionalProperties":false,"required":["document"],"properties":{"document":{"type":"object","additionalProperties":false,"properties":{"reference":{"type":"object","additionalProperties":false,"properties":{"resource":{"type":"integer","minimum":0,"maximum":9007199254740991},"document":{"type":"string","maxLength":131072},"epoch":{"type":"string","maxLength":131072},"type_revision":{"type":"integer","minimum":0,"maximum":4294967295},"revision":{"type":"string","maxLength":131072}},"required":["resource","document","epoch","type_revision","revision"]},"change_format":{"type":"integer","minimum":0,"maximum":4294967295},"expand":{"anyOf":[{"type":"array","maxItems":8,"items":{"type":"string","maxLength":131072}},{"type":"null"}]},"projections":{"type":"array","maxItems":8,"items":{"type":"object","additionalProperties":false,"properties":{"column":{"type":"object","additionalProperties":false,"properties":{"name":{"type":"string","maxLength":131072},"type":{"type":"string","enum":["int64","uint64","float64","boolean","utf8","binary"]}},"required":["name","type"]},"path":{"type":"array","maxItems":8,"items":{"type":"string","maxLength":131072}},"relative":{"type":"boolean"},"mode":{"type":"string","enum":["scalar","text","element_counter","element_replica"]},"text_bytes":{"type":"integer","minimum":0,"maximum":65535},"text_steps":{"type":"integer","minimum":0,"maximum":65535}},"required":["column","path","relative","mode","text_bytes","text_steps"]}}},"required":["reference","change_format","expand","projections"]}}}]}},"required":["version","resource","source"]},"plan":{"type":"object","additionalProperties":false,"properties":{"version":{"type":"integer","minimum":0,"maximum":255},"projection":{"type":"array","maxItems":8,"items":{"type":"integer","minimum":0,"maximum":4294967295}},"output_names":{"anyOf":[{"type":"array","maxItems":8,"items":{"anyOf":[{"type":"string","maxLength":131072},{"type":"null"}]}},{"type":"null"}]},"limit":{"anyOf":[{"type":"string","maxLength":131072},{"type":"null"}]},"aggregate":{"type":"string","enum":["rows","count","sum","count_values"]},"predicate":{"oneOf":[{"type":"object","additionalProperties":false,"required":["all"],"properties":{"all":{"type":"object","maxProperties":0}}},{"type":"object","additionalProperties":false,"required":["state"],"properties":{"state":{"type":"object","additionalProperties":false,"properties":{"column":{"type":"integer","minimum":0,"maximum":255},"value":{"type":"string","enum":["missing","null","type_error","value","conflict"]}},"required":["column","value"]}}},{"type":"object","additionalProperties":false,"required":["compare"],"properties":{"compare":{"type":"object","additionalProperties":false,"properties":{"column":{"type":"integer","minimum":0,"maximum":255},"op":{"type":"string","enum":["eq","ne","lt","le","gt","ge"]},"value":{"oneOf":[{"type":"object","additionalProperties":false,"required":["int64"],"properties":{"int64":{"type":"string","maxLength":131072}}},{"type":"object","additionalProperties":false,"required":["uint64"],"properties":{"uint64":{"type":"string","maxLength":131072}}},{"type":"object","additionalProperties":false,"required":["float_bits"],"properties":{"float_bits":{"type":"string","maxLength":131072}}},{"type":"object","additionalProperties":false,"required":["boolean"],"properties":{"boolean":{"type":"boolean"}}},{"type":"object","additionalProperties":false,"required":["utf8"],"properties":{"utf8":{"type":"string","maxLength":131072}}},{"type":"object","additionalProperties":false,"required":["binary"],"properties":{"binary":{"type":"string","maxLength":131072}}}]}},"required":["column","op","value"]}}},{"type":"object","additionalProperties":false,"required":["program"],"properties":{"program":{"type":"array","maxItems":64,"items":{"oneOf":[{"type":"object","additionalProperties":false,"required":["atom"],"properties":{"atom":{"oneOf":[{"type":"object","additionalProperties":false,"required":["all"],"properties":{"all":{"type":"object","maxProperties":0}}},{"type":"object","additionalProperties":false,"required":["state"],"properties":{"state":{"type":"object","additionalProperties":false,"properties":{"column":{"type":"integer","minimum":0,"maximum":255},"value":{"type":"string","enum":["missing","null","type_error","value","conflict"]}},"required":["column","value"]}}},{"type":"object","additionalProperties":false,"required":["compare"],"properties":{"compare":{"type":"object","additionalProperties":false,"properties":{"column":{"type":"integer","minimum":0,"maximum":255},"op":{"type":"string","enum":["eq","ne","lt","le","gt","ge"]},"value":{"oneOf":[{"type":"object","additionalProperties":false,"required":["int64"],"properties":{"int64":{"type":"string","maxLength":131072}}},{"type":"object","additionalProperties":false,"required":["uint64"],"properties":{"uint64":{"type":"string","maxLength":131072}}},{"type":"object","additionalProperties":false,"required":["float_bits"],"properties":{"float_bits":{"type":"string","maxLength":131072}}},{"type":"object","additionalProperties":false,"required":["boolean"],"properties":{"boolean":{"type":"boolean"}}},{"type":"object","additionalProperties":false,"required":["utf8"],"properties":{"utf8":{"type":"string","maxLength":131072}}},{"type":"object","additionalProperties":false,"required":["binary"],"properties":{"binary":{"type":"string","maxLength":131072}}}]}},"required":["column","op","value"]}}}]}}},{"type":"object","additionalProperties":false,"required":["negate"],"properties":{"negate":{"type":"object","maxProperties":0}}},{"type":"object","additionalProperties":false,"required":["conjunction"],"properties":{"conjunction":{"type":"object","maxProperties":0}}},{"type":"object","additionalProperties":false,"required":["disjunction"],"properties":{"disjunction":{"type":"object","maxProperties":0}}}]}}}}]}},"required":["version","projection","output_names","limit","aggregate","predicate"]},"limits":{"type":"object","additionalProperties":false,"properties":{"pages":{"type":"string","maxLength":131072},"segments":{"type":"string","maxLength":131072},"result_bytes":{"type":"string","maxLength":131072}},"required":["pages","segments","result_bytes"]},"contract":{"type":"array","minItems":32,"maxItems":32,"items":{"type":"integer","minimum":0,"maximum":255}},"schema":{"type":"array","minItems":32,"maxItems":32,"items":{"type":"integer","minimum":0,"maximum":255}}},"required":["bundle","source","plan","limits","contract","schema"]}}},{"type":"object","additionalProperties":false,"required":["inspection"],"properties":{"inspection":{"type":"object","additionalProperties":false,"properties":{"version":{"type":"integer","minimum":0,"maximum":255},"scope":{"type":"string","enum":["configured_source"]},"name":{"type":"string","maxLength":131072},"resource":{"type":"integer","minimum":0,"maximum":9007199254740991},"source_kind":{"type":"string","enum":["kv","table","document"]},"contract":{"type":"array","minItems":32,"maxItems":32,"items":{"type":"integer","minimum":0,"maximum":255}},"schema":{"type":"array","minItems":32,"maxItems":32,"items":{"type":"integer","minimum":0,"maximum":255}},"resource_revision":{"type":"integer","minimum":0,"maximum":9007199254740991},"policy_revision":{"type":"string","maxLength":131072},"details":{"oneOf":[{"type":"object","additionalProperties":false,"required":["description"],"properties":{"description":{"type":"object","additionalProperties":false,"properties":{"columns":{"type":"array","maxItems":8,"items":{"type":"object","additionalProperties":false,"properties":{"name":{"type":"string","maxLength":131072},"type":{"type":"string","enum":["int64","uint64","float64","boolean","utf8","binary"]}},"required":["name","type"]}}},"required":["columns"]}}},{"type":"object","additionalProperties":false,"required":["tables"],"properties":{"tables":{"type":"array","maxItems":8,"items":{"type":"string","maxLength":131072}}}},{"type":"object","additionalProperties":false,"required":["explanation"],"properties":{"explanation":{"type":"object","additionalProperties":false,"properties":{"operators":{"type":"array","maxItems":8,"items":{"type":"string","enum":["scan","filter","limit","project","count","sum","count_values"]}},"predicate":{"oneOf":[{"type":"object","additionalProperties":false,"required":["all"],"properties":{"all":{"type":"object","maxProperties":0}}},{"type":"object","additionalProperties":false,"required":["state"],"properties":{"state":{"type":"object","additionalProperties":false,"properties":{"column":{"type":"string","maxLength":131072},"value":{"type":"string","enum":["missing","null","type_error","value","conflict"]}},"required":["column","value"]}}},{"type":"object","additionalProperties":false,"required":["compare"],"properties":{"compare":{"type":"object","additionalProperties":false,"properties":{"column":{"type":"string","maxLength":131072},"op":{"type":"string","enum":["eq","ne","lt","le","gt","ge"]},"type":{"type":"string","enum":["int64","uint64","float64","boolean","utf8","binary"]}},"required":["column","op","type"]}}},{"type":"object","additionalProperties":false,"required":["program"],"properties":{"program":{"type":"array","maxItems":64,"items":{"oneOf":[{"type":"object","additionalProperties":false,"required":["atom"],"properties":{"atom":{"oneOf":[{"type":"object","additionalProperties":false,"required":["all"],"properties":{"all":{"type":"object","maxProperties":0}}},{"type":"object","additionalProperties":false,"required":["state"],"properties":{"state":{"type":"object","additionalProperties":false,"properties":{"column":{"type":"string","maxLength":131072},"value":{"type":"string","enum":["missing","null","type_error","value","conflict"]}},"required":["column","value"]}}},{"type":"object","additionalProperties":false,"required":["compare"],"properties":{"compare":{"type":"object","additionalProperties":false,"properties":{"column":{"type":"string","maxLength":131072},"op":{"type":"string","enum":["eq","ne","lt","le","gt","ge"]},"type":{"type":"string","enum":["int64","uint64","float64","boolean","utf8","binary"]}},"required":["column","op","type"]}}}]}}},{"type":"object","additionalProperties":false,"required":["negate"],"properties":{"negate":{"type":"object","maxProperties":0}}},{"type":"object","additionalProperties":false,"required":["conjunction"],"properties":{"conjunction":{"type":"object","maxProperties":0}}},{"type":"object","additionalProperties":false,"required":["disjunction"],"properties":{"disjunction":{"type":"object","maxProperties":0}}}]}}}}]},"projection":{"type":"array","maxItems":8,"items":{"type":"string","maxLength":131072}},"limit":{"anyOf":[{"type":"string","maxLength":131072},{"type":"null"}]},"aggregate":{"type":"string","enum":["rows","count","sum","count_values"]},"columns":{"type":"array","maxItems":8,"items":{"type":"object","additionalProperties":false,"properties":{"name":{"type":"string","maxLength":131072},"type":{"type":"string","enum":["int64","uint64","float64","boolean","utf8","binary"]}},"required":["name","type"]}},"budgets":{"type":"object","additionalProperties":false,"properties":{"pages":{"type":"string","maxLength":131072},"segments":{"type":"string","maxLength":131072},"result_bytes":{"type":"string","maxLength":131072}},"required":["pages","segments","result_bytes"]}},"required":["operators","predicate","projection","limit","aggregate","columns","budgets"]}}}]}},"required":["version","scope","name","resource","source_kind","contract","schema","resource_revision","policy_revision","details"]}}},{"type":"object","additionalProperties":false,"required":["prepared"],"properties":{"prepared":{"anyOf":[{"type":"object","additionalProperties":false,"properties":{"token":{"type":"string","maxLength":131072}},"required":["token"]},{"type":"null"}]}}},{"type":"object","additionalProperties":false,"required":["receipt"],"properties":{"receipt":{"type":"object","additionalProperties":false,"properties":{"position":{"type":"integer","minimum":0,"maximum":9007199254740991}},"required":["position"]}}},{"type":"object","additionalProperties":false,"required":["observation"],"properties":{"observation":{"oneOf":[{"type":"object","additionalProperties":false,"required":["pending"],"properties":{"pending":{"type":"object","maxProperties":0}}},{"type":"object","additionalProperties":false,"required":["committed"],"properties":{"committed":{"type":"object","maxProperties":0}}},{"type":"object","additionalProperties":false,"required":["rejected"],"properties":{"rejected":{"type":"string","pattern":"^(?:[0-9a-f]{2})*$","maxLength":512}}}]}}},{"type":"object","additionalProperties":false,"required":["status"],"properties":{"status":{"anyOf":[{"type":"object","additionalProperties":false,"properties":{"reference":{"type":"string","pattern":"^(?:[0-9a-f]{2})*$","maxLength":512},"phase":{"type":"string","enum":["uploading","sealed","admitted","complete","cancelled","denied","rejected","retired"]},"correlation":{"type":"string","maxLength":131072},"manifest":{"anyOf":[{"type":"string","pattern":"^(?:[0-9a-f]{2})*$","maxLength":512},{"type":"null"}]},"collected":{"type":"boolean"},"failure":{"anyOf":[{"type":"object","additionalProperties":false,"properties":{"code":{"type":"string","enum":["policy_denied","access_denied","resource_unavailable","request_unpublished","publisher_mismatch","document_history_gap","document_retired","document_resync_required","budget_exceeded","projection_budget","expansion_missing","expansion_null","expansion_conflict","expansion_type_error","cell_type_error","cell_conflict","arithmetic_overflow","segment_byte_limit","type_mismatch","unsupported_aggregate","unknown_column","invalid_projection","duplicate_projection","invalid_bundle","invalid_source","invalid_prefix","invalid_path","invalid_projection_budget","invalid_text_projection","invalid_element_projection","unsupported_source","unsupported_decoder","unsupported_document_source","invalid_source_encoding","invalid_plan_encoding","plan_definition_mismatch","invalid_output_names","unsupported_plan","plan_too_large","bundle_too_large","truncated_input","source_changed","table_schema_changed","invalid_budget","namespace_in_use","query_after_mutation","nonfinite_value","invalid_utf8","cell_too_large","invalid_column_name","invalid_column_count","duplicate_column","unsupported_schema","peer_mismatch","invalid_request_reference","writer_not_ready","request_resource_expired","request_resource_missing"]},"stage":{"type":"string","enum":["admission","execution"]},"dimension":{"type":"string","enum":["none","pages","segments","result_bytes"]},"limit":{"type":"string","maxLength":131072},"observed":{"type":"string","maxLength":131072}},"required":["code","stage","dimension","limit","observed"]},{"type":"null"}]},"diagnostic":{"anyOf":[{"type":"object","additionalProperties":false,"properties":{"version":{"const":1},"definition":{"type":"string","enum":["c750e7034f20d2446bfe44c7ad19a3ca45b415a0a02754523dc280cf74e20d15"]},"code":{"type":"string","maxLength":96},"category":{"type":"string","enum":["syntax","binding","unsupported","constraint","access","conflict","limit","lifecycle","integrity","unavailable","internal"]},"stage":{"type":"string","enum":["input","parse","compile","bind","prepare","submit","admission","execute","read","decode","output","reconcile","cleanup","control"]},"outcome":{"type":"string","enum":["not_applicable","not_submitted","prepared","unknown","pending","input_rejected","rejected","applied","cancelled","retired","closed_unknown"]},"evidence":{"type":"string","enum":["none","local_before_dispatch","saved_intent","native_receipt","domain_status"]},"message":{"type":"string","maxLength":384},"cause":{"anyOf":[{"type":"string","maxLength":96},{"type":"null"}]},"identity":{"anyOf":[{"type":"object","additionalProperties":false,"properties":{"domain":{"type":"string","enum":["sql","query","mutation","catalog","application","publication","migration","reactive","effect","transport","internal"]},"id":{"type":"string","maxLength":20,"pattern":"^(0|[1-9][0-9]*)$"},"realm":{"anyOf":[{"type":"string","maxLength":20,"pattern":"^(0|[1-9][0-9]*)$"},{"type":"null"}]},"resource":{"anyOf":[{"type":"string","maxLength":20,"pattern":"^(0|[1-9][0-9]*)$"},{"type":"null"}]},"sequence":{"anyOf":[{"type":"string","maxLength":20,"pattern":"^(0|[1-9][0-9]*)$"},{"type":"null"}]}},"required":["domain","id","realm","resource","sequence"]},{"type":"null"}]},"location":{"anyOf":[{"type":"object","additionalProperties":false,"properties":{"source":{"anyOf":[{"type":"string","maxLength":512},{"type":"null"}]},"source_encoding":{"type":"string","enum":["utf8","escaped_bytes"]},"source_truncated":{"type":"boolean"},"statement":{"anyOf":[{"type":"string","maxLength":20,"pattern":"^(0|[1-9][0-9]*)$"},{"type":"null"}]},"offset":{"type":"string","maxLength":20,"pattern":"^(0|[1-9][0-9]*)$"},"length":{"type":"string","maxLength":20,"pattern":"^(0|[1-9][0-9]*)$"},"line":{"type":"string","maxLength":20,"pattern":"^(0|[1-9][0-9]*)$"},"byte_column":{"type":"string","maxLength":20,"pattern":"^(0|[1-9][0-9]*)$"}},"required":["source","source_encoding","source_truncated","statement","offset","length","line","byte_column"]},{"type":"null"}]},"facts":{"type":"array","minItems":16,"maxItems":16,"items":{"anyOf":[{"type":"object","additionalProperties":false,"properties":{"field":{"type":"string","enum":["object","name","table","native_input","affected_rows","argument","option","permissions","scope","column","qualifier","constraint","key","input_row","first_occurrence","parameter","parameter_use","expected_count","actual_count","expected_type","actual_type","supplied_value","expression","source_kind","source_basis","source_key","source_row","field_path","byte_offset","expected_resource","actual_resource","expected_source","actual_source","expected_revision","actual_revision","expected_schema","actual_schema","expected_policy","actual_policy","budget","limit","required","unit","completed_statements","emitted_rows","emitted_segments","completion","proposal","step","generation","attachment","lease","schema_origin","sampling_records","operation","native_cause","expected_bytes"]},"origin":{"type":"string","enum":["caller","execution","schema","authority","owner"]},"availability":{"type":"string","enum":["provided","truncated","unrecorded","unavailable","withheld","inapplicable"]},"value":{"anyOf":[{"oneOf":[{"type":"object","additionalProperties":false,"required":["text"],"properties":{"text":{"type":"string","maxLength":256}}},{"type":"object","additionalProperties":false,"required":["signed"],"properties":{"signed":{"type":"string","maxLength":20,"pattern":"^(0|-?[1-9][0-9]*)$"}}},{"type":"object","additionalProperties":false,"required":["unsigned"],"properties":{"unsigned":{"type":"string","maxLength":20,"pattern":"^(0|[1-9][0-9]*)$"}}},{"type":"object","additionalProperties":false,"required":["boolean"],"properties":{"boolean":{"type":"boolean"}}},{"type":"object","additionalProperties":false,"required":["digest"],"properties":{"digest":{"type":"array","minItems":32,"maxItems":32,"items":{"type":"integer","minimum":0,"maximum":255}}}},{"type":"object","additionalProperties":false,"required":["location"],"properties":{"location":{"type":"object","additionalProperties":false,"properties":{"source":{"anyOf":[{"type":"string","maxLength":512},{"type":"null"}]},"source_encoding":{"type":"string","enum":["utf8","escaped_bytes"]},"source_truncated":{"type":"boolean"},"statement":{"anyOf":[{"type":"string","maxLength":20,"pattern":"^(0|[1-9][0-9]*)$"},{"type":"null"}]},"offset":{"type":"string","maxLength":20,"pattern":"^(0|[1-9][0-9]*)$"},"length":{"type":"string","maxLength":20,"pattern":"^(0|[1-9][0-9]*)$"},"line":{"type":"string","maxLength":20,"pattern":"^(0|[1-9][0-9]*)$"},"byte_column":{"type":"string","maxLength":20,"pattern":"^(0|[1-9][0-9]*)$"}},"required":["source","source_encoding","source_truncated","statement","offset","length","line","byte_column"]}}}]},{"type":"null"}]}},"required":["field","origin","availability","value"]},{"type":"null"}]}},"actions":{"type":"array","minItems":4,"maxItems":4,"items":{"anyOf":[{"type":"object","additionalProperties":false,"properties":{"kind":{"type":"string","enum":["correct_input","inspect_status","resume_exact","cancel_wait","cancel_mutation","refresh","recompile","retry_read","inspect_scope","reconcile_effect","contact_operator"]},"target":{"anyOf":[{"type":"object","additionalProperties":false,"properties":{"domain":{"type":"string","enum":["sql","query","mutation","catalog","application","publication","migration","reactive","effect","transport","internal"]},"id":{"type":"string","maxLength":20,"pattern":"^(0|[1-9][0-9]*)$"},"realm":{"anyOf":[{"type":"string","maxLength":20,"pattern":"^(0|[1-9][0-9]*)$"},{"type":"null"}]},"resource":{"anyOf":[{"type":"string","maxLength":20,"pattern":"^(0|[1-9][0-9]*)$"},{"type":"null"}]},"sequence":{"anyOf":[{"type":"string","maxLength":20,"pattern":"^(0|[1-9][0-9]*)$"},{"type":"null"}]}},"required":["domain","id","realm","resource","sequence"]},{"type":"null"}]}},"required":["kind","target"]},{"type":"null"}]}}},"required":["version","definition","code","category","stage","outcome","evidence","message","cause","identity","location","facts","actions"]},{"type":"null"}]}},"required":["reference","phase","correlation","manifest","collected","failure","diagnostic"]},{"type":"null"}]}}},{"type":"object","additionalProperties":false,"required":["page"],"properties":{"page":{"type":"object","additionalProperties":false,"properties":{"evidence":{"type":"object","additionalProperties":false,"properties":{"manifest":{"type":"object","additionalProperties":false,"properties":{"job":{"type":"integer","minimum":0,"maximum":9007199254740991},"source":{"type":"object","additionalProperties":false,"properties":{"pid":{"type":"integer","minimum":0,"maximum":9007199254740991},"input":{"type":"integer","minimum":0,"maximum":9007199254740991},"index":{"type":"integer","minimum":0,"maximum":255}},"required":["pid","input","index"]},"requester":{"type":"integer","minimum":0,"maximum":9007199254740991},"correlation":{"type":"string","maxLength":131072},"policy_revision":{"type":"string","maxLength":131072},"request":{"type":"string","pattern":"^(?:[0-9a-f]{2})*$","maxLength":512},"basis":{"type":"object","additionalProperties":false,"properties":{"kind":{"type":"string","enum":["kv","table","document"]},"resource":{"type":"integer","minimum":0,"maximum":9007199254740991},"revision":{"type":"integer","minimum":0,"maximum":9007199254740991},"contract":{"type":"array","minItems":32,"maxItems":32,"items":{"type":"integer","minimum":0,"maximum":255}},"schema":{"type":"array","minItems":32,"maxItems":32,"items":{"type":"integer","minimum":0,"maximum":255}}},"required":["kind","resource","revision","contract","schema"]},"plan":{"type":"array","minItems":32,"maxItems":32,"items":{"type":"integer","minimum":0,"maximum":255}},"pages":{"type":"string","maxLength":131072},"scanned":{"type":"string","maxLength":131072},"selected":{"type":"string","maxLength":131072},"value_count":{"type":"string","maxLength":131072},"segments":{"type":"string","maxLength":131072},"rows":{"type":"string","maxLength":131072},"bytes":{"type":"string","maxLength":131072},"sum":{"anyOf":[{"type":"string","maxLength":131072},{"type":"null"}]},"finished":{"anyOf":[{"type":"string","enum":["source_end","limit"]},{"type":"null"}]},"chain":{"type":"array","minItems":32,"maxItems":32,"items":{"type":"integer","minimum":0,"maximum":255}}},"required":["job","source","requester","correlation","policy_revision","request","basis","plan","pages","scanned","selected","value_count","segments","rows","bytes","sum","finished","chain"]},"columns":{"type":"array","maxItems":8,"items":{"type":"object","additionalProperties":false,"properties":{"name":{"type":"string","maxLength":131072},"type":{"type":"string","enum":["int64","uint64","float64","boolean","utf8","binary"]}},"required":["name","type"]}},"ordinal":{"type":"string","maxLength":131072},"rows":{"type":"integer","minimum":0,"maximum":255},"ipc":{"type":"string","maxLength":131072},"next":{"anyOf":[{"type":"string","maxLength":131072},{"type":"null"}]}},"required":["manifest","columns","ordinal","rows","ipc","next"]},"cells":{"type":"array","maxItems":8,"items":{"type":"array","maxItems":8,"items":{"oneOf":[{"type":"object","additionalProperties":false,"required":["missing"],"properties":{"missing":{"type":"object","maxProperties":0}}},{"type":"object","additionalProperties":false,"required":["null"],"properties":{"null":{"type":"object","maxProperties":0}}},{"type":"object","additionalProperties":false,"required":["type_error"],"properties":{"type_error":{"type":"string","enum":["unknown","int64","uint64","float64","boolean","utf8","binary","null_value","map","list","text","character"]}}},{"type":"object","additionalProperties":false,"required":["value"],"properties":{"value":{"oneOf":[{"type":"object","additionalProperties":false,"required":["int64"],"properties":{"int64":{"type":"string","maxLength":131072}}},{"type":"object","additionalProperties":false,"required":["uint64"],"properties":{"uint64":{"type":"string","maxLength":131072}}},{"type":"object","additionalProperties":false,"required":["float_bits"],"properties":{"float_bits":{"type":"string","maxLength":131072}}},{"type":"object","additionalProperties":false,"required":["boolean"],"properties":{"boolean":{"type":"boolean"}}},{"type":"object","additionalProperties":false,"required":["utf8"],"properties":{"utf8":{"type":"string","maxLength":131072}}},{"type":"object","additionalProperties":false,"required":["binary"],"properties":{"binary":{"type":"string","maxLength":131072}}}]}}},{"type":"object","additionalProperties":false,"required":["conflict"],"properties":{"conflict":{"type":"array","maxItems":8,"items":{"type":"object","additionalProperties":false,"properties":{"counter":{"type":"string","maxLength":131072},"replica":{"type":"string","maxLength":131072},"value":{"oneOf":[{"type":"object","additionalProperties":false,"required":["null"],"properties":{"null":{"type":"object","maxProperties":0}}},{"type":"object","additionalProperties":false,"required":["type_error"],"properties":{"type_error":{"type":"string","enum":["unknown","int64","uint64","float64","boolean","utf8","binary","null_value","map","list","text","character"]}}},{"type":"object","additionalProperties":false,"required":["value"],"properties":{"value":{"oneOf":[{"type":"object","additionalProperties":false,"required":["int64"],"properties":{"int64":{"type":"string","maxLength":131072}}},{"type":"object","additionalProperties":false,"required":["uint64"],"properties":{"uint64":{"type":"string","maxLength":131072}}},{"type":"object","additionalProperties":false,"required":["float_bits"],"properties":{"float_bits":{"type":"string","maxLength":131072}}},{"type":"object","additionalProperties":false,"required":["boolean"],"properties":{"boolean":{"type":"boolean"}}},{"type":"object","additionalProperties":false,"required":["utf8"],"properties":{"utf8":{"type":"string","maxLength":131072}}},{"type":"object","additionalProperties":false,"required":["binary"],"properties":{"binary":{"type":"string","maxLength":131072}}}]}}}]}},"required":["counter","replica","value"]}}}}]}}}},"required":["evidence","cells"]}}},{"type":"object","additionalProperties":false,"required":["draft"],"properties":{"draft":{"anyOf":[{"type":"object","additionalProperties":false,"properties":{"generation":{"type":"string","maxLength":131072},"limit":{"type":"integer","minimum":0,"maximum":255},"starts":{"type":"integer","minimum":0,"maximum":255},"enabled":{"type":"boolean"},"contract":{"type":"array","minItems":32,"maxItems":32,"items":{"type":"integer","minimum":0,"maximum":255}},"budgets":{"type":"object","additionalProperties":false,"properties":{"pages":{"type":"string","maxLength":131072},"segments":{"type":"string","maxLength":131072},"result_bytes":{"type":"string","maxLength":131072}},"required":["pages","segments","result_bytes"]},"namespaces":{"type":"array","minItems":8,"maxItems":8,"items":{"type":"string","maxLength":131072}}},"required":["generation","limit","starts","enabled","contract","budgets","namespaces"]},{"type":"null"}]}}}]};
const func24 = Object.prototype.hasOwnProperty;
const pattern4 = new RegExp("^(?:[0-9a-f]{2})*$", "u");
const pattern7 = new RegExp("^(0|[1-9][0-9]*)$", "u");
const pattern16 = new RegExp("^(0|-?[1-9][0-9]*)$", "u");

function validate22(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate22.evaluated;
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
let data2 = data1.realm;
const _errs10 = errors;
if(!(((typeof data2 == "number") && (!(data2 % 1) && !isNaN(data2))) && (isFinite(data2)))){
const err6 = {instancePath:instancePath+"/description/connection/realm",schemaPath:"#/oneOf/0/properties/description/properties/connection/properties/realm/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err6];
}
else {
vErrors.push(err6);
}
errors++;
}
if(errors === _errs10){
if((typeof data2 == "number") && (isFinite(data2))){
if(data2 > 9007199254740991 || isNaN(data2)){
const err7 = {instancePath:instancePath+"/description/connection/realm",schemaPath:"#/oneOf/0/properties/description/properties/connection/properties/realm/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"};
if(vErrors === null){
vErrors = [err7];
}
else {
vErrors.push(err7);
}
errors++;
}
else {
if(data2 < 0 || isNaN(data2)){
const err8 = {instancePath:instancePath+"/description/connection/realm",schemaPath:"#/oneOf/0/properties/description/properties/connection/properties/realm/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
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
var valid3 = _errs10 === errors;
}
else {
var valid3 = true;
}
if(valid3){
if(data1.principal !== undefined){
let data3 = data1.principal;
const _errs12 = errors;
if(!(((typeof data3 == "number") && (!(data3 % 1) && !isNaN(data3))) && (isFinite(data3)))){
const err9 = {instancePath:instancePath+"/description/connection/principal",schemaPath:"#/oneOf/0/properties/description/properties/connection/properties/principal/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err9];
}
else {
vErrors.push(err9);
}
errors++;
}
if(errors === _errs12){
if((typeof data3 == "number") && (isFinite(data3))){
if(data3 > 9007199254740991 || isNaN(data3)){
const err10 = {instancePath:instancePath+"/description/connection/principal",schemaPath:"#/oneOf/0/properties/description/properties/connection/properties/principal/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"};
if(vErrors === null){
vErrors = [err10];
}
else {
vErrors.push(err10);
}
errors++;
}
else {
if(data3 < 0 || isNaN(data3)){
const err11 = {instancePath:instancePath+"/description/connection/principal",schemaPath:"#/oneOf/0/properties/description/properties/connection/properties/principal/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err11];
}
else {
vErrors.push(err11);
}
errors++;
}
}
}
}
var valid3 = _errs12 === errors;
}
else {
var valid3 = true;
}
if(valid3){
if(data1.source !== undefined){
let data4 = data1.source;
const _errs14 = errors;
if(!(((typeof data4 == "number") && (!(data4 % 1) && !isNaN(data4))) && (isFinite(data4)))){
const err12 = {instancePath:instancePath+"/description/connection/source",schemaPath:"#/oneOf/0/properties/description/properties/connection/properties/source/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err12];
}
else {
vErrors.push(err12);
}
errors++;
}
if(errors === _errs14){
if((typeof data4 == "number") && (isFinite(data4))){
if(data4 > 9007199254740991 || isNaN(data4)){
const err13 = {instancePath:instancePath+"/description/connection/source",schemaPath:"#/oneOf/0/properties/description/properties/connection/properties/source/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"};
if(vErrors === null){
vErrors = [err13];
}
else {
vErrors.push(err13);
}
errors++;
}
else {
if(data4 < 0 || isNaN(data4)){
const err14 = {instancePath:instancePath+"/description/connection/source",schemaPath:"#/oneOf/0/properties/description/properties/connection/properties/source/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err14];
}
else {
vErrors.push(err14);
}
errors++;
}
}
}
}
var valid3 = _errs14 === errors;
}
else {
var valid3 = true;
}
if(valid3){
if(data1.resource !== undefined){
let data5 = data1.resource;
const _errs16 = errors;
if(!(((typeof data5 == "number") && (!(data5 % 1) && !isNaN(data5))) && (isFinite(data5)))){
const err15 = {instancePath:instancePath+"/description/connection/resource",schemaPath:"#/oneOf/0/properties/description/properties/connection/properties/resource/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err15];
}
else {
vErrors.push(err15);
}
errors++;
}
if(errors === _errs16){
if((typeof data5 == "number") && (isFinite(data5))){
if(data5 > 9007199254740991 || isNaN(data5)){
const err16 = {instancePath:instancePath+"/description/connection/resource",schemaPath:"#/oneOf/0/properties/description/properties/connection/properties/resource/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"};
if(vErrors === null){
vErrors = [err16];
}
else {
vErrors.push(err16);
}
errors++;
}
else {
if(data5 < 0 || isNaN(data5)){
const err17 = {instancePath:instancePath+"/description/connection/resource",schemaPath:"#/oneOf/0/properties/description/properties/connection/properties/resource/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err17];
}
else {
vErrors.push(err17);
}
errors++;
}
}
}
}
var valid3 = _errs16 === errors;
}
else {
var valid3 = true;
}
if(valid3){
if(data1.requester !== undefined){
let data6 = data1.requester;
const _errs18 = errors;
if(!(((typeof data6 == "number") && (!(data6 % 1) && !isNaN(data6))) && (isFinite(data6)))){
const err18 = {instancePath:instancePath+"/description/connection/requester",schemaPath:"#/oneOf/0/properties/description/properties/connection/properties/requester/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err18];
}
else {
vErrors.push(err18);
}
errors++;
}
if(errors === _errs18){
if((typeof data6 == "number") && (isFinite(data6))){
if(data6 > 9007199254740991 || isNaN(data6)){
const err19 = {instancePath:instancePath+"/description/connection/requester",schemaPath:"#/oneOf/0/properties/description/properties/connection/properties/requester/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"};
if(vErrors === null){
vErrors = [err19];
}
else {
vErrors.push(err19);
}
errors++;
}
else {
if(data6 < 0 || isNaN(data6)){
const err20 = {instancePath:instancePath+"/description/connection/requester",schemaPath:"#/oneOf/0/properties/description/properties/connection/properties/requester/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err20];
}
else {
vErrors.push(err20);
}
errors++;
}
}
}
}
var valid3 = _errs18 === errors;
}
else {
var valid3 = true;
}
if(valid3){
if(data1.requests !== undefined){
let data7 = data1.requests;
const _errs20 = errors;
if(!(((typeof data7 == "number") && (!(data7 % 1) && !isNaN(data7))) && (isFinite(data7)))){
const err21 = {instancePath:instancePath+"/description/connection/requests",schemaPath:"#/oneOf/0/properties/description/properties/connection/properties/requests/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err21];
}
else {
vErrors.push(err21);
}
errors++;
}
if(errors === _errs20){
if((typeof data7 == "number") && (isFinite(data7))){
if(data7 > 9007199254740991 || isNaN(data7)){
const err22 = {instancePath:instancePath+"/description/connection/requests",schemaPath:"#/oneOf/0/properties/description/properties/connection/properties/requests/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"};
if(vErrors === null){
vErrors = [err22];
}
else {
vErrors.push(err22);
}
errors++;
}
else {
if(data7 < 0 || isNaN(data7)){
const err23 = {instancePath:instancePath+"/description/connection/requests",schemaPath:"#/oneOf/0/properties/description/properties/connection/properties/requests/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err23];
}
else {
vErrors.push(err23);
}
errors++;
}
}
}
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
}
}
}
else {
const err24 = {instancePath:instancePath+"/description/connection",schemaPath:"#/oneOf/0/properties/description/properties/connection/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err24];
}
else {
vErrors.push(err24);
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
const _errs22 = errors;
if(errors === _errs22){
if(typeof data8 === "string"){
if(func1(data8) > 131072){
const err25 = {instancePath:instancePath+"/description/name",schemaPath:"#/oneOf/0/properties/description/properties/name/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err25];
}
else {
vErrors.push(err25);
}
errors++;
}
}
else {
const err26 = {instancePath:instancePath+"/description/name",schemaPath:"#/oneOf/0/properties/description/properties/name/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err26];
}
else {
vErrors.push(err26);
}
errors++;
}
}
var valid2 = _errs22 === errors;
}
else {
var valid2 = true;
}
if(valid2){
if(data0.source !== undefined){
let data9 = data0.source;
const _errs24 = errors;
if(errors === _errs24){
if(data9 && typeof data9 == "object" && !Array.isArray(data9)){
let missing3;
if(((((((data9.capabilities === undefined) && (missing3 = "capabilities")) || ((data9.source === undefined) && (missing3 = "source"))) || ((data9.resource_revision === undefined) && (missing3 = "resource_revision"))) || ((data9.policy_revision === undefined) && (missing3 = "policy_revision"))) || ((data9.limits === undefined) && (missing3 = "limits"))) || ((data9.active === undefined) && (missing3 = "active"))){
const err27 = {instancePath:instancePath+"/description/source",schemaPath:"#/oneOf/0/properties/description/properties/source/required",keyword:"required",params:{missingProperty: missing3},message:"must have required property '"+missing3+"'"};
if(vErrors === null){
vErrors = [err27];
}
else {
vErrors.push(err27);
}
errors++;
}
else {
const _errs26 = errors;
for(const key3 in data9){
if(!((((((key3 === "capabilities") || (key3 === "source")) || (key3 === "resource_revision")) || (key3 === "policy_revision")) || (key3 === "limits")) || (key3 === "active"))){
const err28 = {instancePath:instancePath+"/description/source",schemaPath:"#/oneOf/0/properties/description/properties/source/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key3},message:"must NOT have additional properties"};
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
if(_errs26 === errors){
if(data9.capabilities !== undefined){
let data10 = data9.capabilities;
const _errs27 = errors;
if(errors === _errs27){
if(data10 && typeof data10 == "object" && !Array.isArray(data10)){
let missing4;
if(((((((((((((data10.version === undefined) && (missing4 = "version")) || ((data10.source === undefined) && (missing4 = "source"))) || ((data10.plan === undefined) && (missing4 = "plan"))) || ((data10.result === undefined) && (missing4 = "result"))) || ((data10.bundle_bytes === undefined) && (missing4 = "bundle_bytes"))) || ((data10.part_bytes === undefined) && (missing4 = "part_bytes"))) || ((data10.segment_bytes === undefined) && (missing4 = "segment_bytes"))) || ((data10.batch_rows === undefined) && (missing4 = "batch_rows"))) || ((data10.columns === undefined) && (missing4 = "columns"))) || ((data10.kv === undefined) && (missing4 = "kv"))) || ((data10.table === undefined) && (missing4 = "table"))) || ((data10.document === undefined) && (missing4 = "document"))){
const err29 = {instancePath:instancePath+"/description/source/capabilities",schemaPath:"#/oneOf/0/properties/description/properties/source/properties/capabilities/required",keyword:"required",params:{missingProperty: missing4},message:"must have required property '"+missing4+"'"};
if(vErrors === null){
vErrors = [err29];
}
else {
vErrors.push(err29);
}
errors++;
}
else {
const _errs29 = errors;
for(const key4 in data10){
if(!(func24.call(schema33.oneOf[0].properties.description.properties.source.properties.capabilities.properties, key4))){
const err30 = {instancePath:instancePath+"/description/source/capabilities",schemaPath:"#/oneOf/0/properties/description/properties/source/properties/capabilities/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key4},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err30];
}
else {
vErrors.push(err30);
}
errors++;
break;
}
}
if(_errs29 === errors){
if(data10.version !== undefined){
let data11 = data10.version;
const _errs30 = errors;
if(!(((typeof data11 == "number") && (!(data11 % 1) && !isNaN(data11))) && (isFinite(data11)))){
const err31 = {instancePath:instancePath+"/description/source/capabilities/version",schemaPath:"#/oneOf/0/properties/description/properties/source/properties/capabilities/properties/version/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err31];
}
else {
vErrors.push(err31);
}
errors++;
}
if(errors === _errs30){
if((typeof data11 == "number") && (isFinite(data11))){
if(data11 > 255 || isNaN(data11)){
const err32 = {instancePath:instancePath+"/description/source/capabilities/version",schemaPath:"#/oneOf/0/properties/description/properties/source/properties/capabilities/properties/version/maximum",keyword:"maximum",params:{comparison: "<=", limit: 255},message:"must be <= 255"};
if(vErrors === null){
vErrors = [err32];
}
else {
vErrors.push(err32);
}
errors++;
}
else {
if(data11 < 0 || isNaN(data11)){
const err33 = {instancePath:instancePath+"/description/source/capabilities/version",schemaPath:"#/oneOf/0/properties/description/properties/source/properties/capabilities/properties/version/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err33];
}
else {
vErrors.push(err33);
}
errors++;
}
}
}
}
var valid5 = _errs30 === errors;
}
else {
var valid5 = true;
}
if(valid5){
if(data10.source !== undefined){
let data12 = data10.source;
const _errs32 = errors;
if(!(((typeof data12 == "number") && (!(data12 % 1) && !isNaN(data12))) && (isFinite(data12)))){
const err34 = {instancePath:instancePath+"/description/source/capabilities/source",schemaPath:"#/oneOf/0/properties/description/properties/source/properties/capabilities/properties/source/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err34];
}
else {
vErrors.push(err34);
}
errors++;
}
if(errors === _errs32){
if((typeof data12 == "number") && (isFinite(data12))){
if(data12 > 255 || isNaN(data12)){
const err35 = {instancePath:instancePath+"/description/source/capabilities/source",schemaPath:"#/oneOf/0/properties/description/properties/source/properties/capabilities/properties/source/maximum",keyword:"maximum",params:{comparison: "<=", limit: 255},message:"must be <= 255"};
if(vErrors === null){
vErrors = [err35];
}
else {
vErrors.push(err35);
}
errors++;
}
else {
if(data12 < 0 || isNaN(data12)){
const err36 = {instancePath:instancePath+"/description/source/capabilities/source",schemaPath:"#/oneOf/0/properties/description/properties/source/properties/capabilities/properties/source/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
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
var valid5 = _errs32 === errors;
}
else {
var valid5 = true;
}
if(valid5){
if(data10.plan !== undefined){
let data13 = data10.plan;
const _errs34 = errors;
if(!(((typeof data13 == "number") && (!(data13 % 1) && !isNaN(data13))) && (isFinite(data13)))){
const err37 = {instancePath:instancePath+"/description/source/capabilities/plan",schemaPath:"#/oneOf/0/properties/description/properties/source/properties/capabilities/properties/plan/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err37];
}
else {
vErrors.push(err37);
}
errors++;
}
if(errors === _errs34){
if((typeof data13 == "number") && (isFinite(data13))){
if(data13 > 255 || isNaN(data13)){
const err38 = {instancePath:instancePath+"/description/source/capabilities/plan",schemaPath:"#/oneOf/0/properties/description/properties/source/properties/capabilities/properties/plan/maximum",keyword:"maximum",params:{comparison: "<=", limit: 255},message:"must be <= 255"};
if(vErrors === null){
vErrors = [err38];
}
else {
vErrors.push(err38);
}
errors++;
}
else {
if(data13 < 0 || isNaN(data13)){
const err39 = {instancePath:instancePath+"/description/source/capabilities/plan",schemaPath:"#/oneOf/0/properties/description/properties/source/properties/capabilities/properties/plan/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err39];
}
else {
vErrors.push(err39);
}
errors++;
}
}
}
}
var valid5 = _errs34 === errors;
}
else {
var valid5 = true;
}
if(valid5){
if(data10.result !== undefined){
let data14 = data10.result;
const _errs36 = errors;
if(!(((typeof data14 == "number") && (!(data14 % 1) && !isNaN(data14))) && (isFinite(data14)))){
const err40 = {instancePath:instancePath+"/description/source/capabilities/result",schemaPath:"#/oneOf/0/properties/description/properties/source/properties/capabilities/properties/result/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err40];
}
else {
vErrors.push(err40);
}
errors++;
}
if(errors === _errs36){
if((typeof data14 == "number") && (isFinite(data14))){
if(data14 > 255 || isNaN(data14)){
const err41 = {instancePath:instancePath+"/description/source/capabilities/result",schemaPath:"#/oneOf/0/properties/description/properties/source/properties/capabilities/properties/result/maximum",keyword:"maximum",params:{comparison: "<=", limit: 255},message:"must be <= 255"};
if(vErrors === null){
vErrors = [err41];
}
else {
vErrors.push(err41);
}
errors++;
}
else {
if(data14 < 0 || isNaN(data14)){
const err42 = {instancePath:instancePath+"/description/source/capabilities/result",schemaPath:"#/oneOf/0/properties/description/properties/source/properties/capabilities/properties/result/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err42];
}
else {
vErrors.push(err42);
}
errors++;
}
}
}
}
var valid5 = _errs36 === errors;
}
else {
var valid5 = true;
}
if(valid5){
if(data10.bundle_bytes !== undefined){
let data15 = data10.bundle_bytes;
const _errs38 = errors;
if(!(((typeof data15 == "number") && (!(data15 % 1) && !isNaN(data15))) && (isFinite(data15)))){
const err43 = {instancePath:instancePath+"/description/source/capabilities/bundle_bytes",schemaPath:"#/oneOf/0/properties/description/properties/source/properties/capabilities/properties/bundle_bytes/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err43];
}
else {
vErrors.push(err43);
}
errors++;
}
if(errors === _errs38){
if((typeof data15 == "number") && (isFinite(data15))){
if(data15 > 4294967295 || isNaN(data15)){
const err44 = {instancePath:instancePath+"/description/source/capabilities/bundle_bytes",schemaPath:"#/oneOf/0/properties/description/properties/source/properties/capabilities/properties/bundle_bytes/maximum",keyword:"maximum",params:{comparison: "<=", limit: 4294967295},message:"must be <= 4294967295"};
if(vErrors === null){
vErrors = [err44];
}
else {
vErrors.push(err44);
}
errors++;
}
else {
if(data15 < 0 || isNaN(data15)){
const err45 = {instancePath:instancePath+"/description/source/capabilities/bundle_bytes",schemaPath:"#/oneOf/0/properties/description/properties/source/properties/capabilities/properties/bundle_bytes/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
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
var valid5 = _errs38 === errors;
}
else {
var valid5 = true;
}
if(valid5){
if(data10.part_bytes !== undefined){
let data16 = data10.part_bytes;
const _errs40 = errors;
if(!(((typeof data16 == "number") && (!(data16 % 1) && !isNaN(data16))) && (isFinite(data16)))){
const err46 = {instancePath:instancePath+"/description/source/capabilities/part_bytes",schemaPath:"#/oneOf/0/properties/description/properties/source/properties/capabilities/properties/part_bytes/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err46];
}
else {
vErrors.push(err46);
}
errors++;
}
if(errors === _errs40){
if((typeof data16 == "number") && (isFinite(data16))){
if(data16 > 65535 || isNaN(data16)){
const err47 = {instancePath:instancePath+"/description/source/capabilities/part_bytes",schemaPath:"#/oneOf/0/properties/description/properties/source/properties/capabilities/properties/part_bytes/maximum",keyword:"maximum",params:{comparison: "<=", limit: 65535},message:"must be <= 65535"};
if(vErrors === null){
vErrors = [err47];
}
else {
vErrors.push(err47);
}
errors++;
}
else {
if(data16 < 0 || isNaN(data16)){
const err48 = {instancePath:instancePath+"/description/source/capabilities/part_bytes",schemaPath:"#/oneOf/0/properties/description/properties/source/properties/capabilities/properties/part_bytes/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err48];
}
else {
vErrors.push(err48);
}
errors++;
}
}
}
}
var valid5 = _errs40 === errors;
}
else {
var valid5 = true;
}
if(valid5){
if(data10.segment_bytes !== undefined){
let data17 = data10.segment_bytes;
const _errs42 = errors;
if(!(((typeof data17 == "number") && (!(data17 % 1) && !isNaN(data17))) && (isFinite(data17)))){
const err49 = {instancePath:instancePath+"/description/source/capabilities/segment_bytes",schemaPath:"#/oneOf/0/properties/description/properties/source/properties/capabilities/properties/segment_bytes/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err49];
}
else {
vErrors.push(err49);
}
errors++;
}
if(errors === _errs42){
if((typeof data17 == "number") && (isFinite(data17))){
if(data17 > 4294967295 || isNaN(data17)){
const err50 = {instancePath:instancePath+"/description/source/capabilities/segment_bytes",schemaPath:"#/oneOf/0/properties/description/properties/source/properties/capabilities/properties/segment_bytes/maximum",keyword:"maximum",params:{comparison: "<=", limit: 4294967295},message:"must be <= 4294967295"};
if(vErrors === null){
vErrors = [err50];
}
else {
vErrors.push(err50);
}
errors++;
}
else {
if(data17 < 0 || isNaN(data17)){
const err51 = {instancePath:instancePath+"/description/source/capabilities/segment_bytes",schemaPath:"#/oneOf/0/properties/description/properties/source/properties/capabilities/properties/segment_bytes/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err51];
}
else {
vErrors.push(err51);
}
errors++;
}
}
}
}
var valid5 = _errs42 === errors;
}
else {
var valid5 = true;
}
if(valid5){
if(data10.batch_rows !== undefined){
let data18 = data10.batch_rows;
const _errs44 = errors;
if(!(((typeof data18 == "number") && (!(data18 % 1) && !isNaN(data18))) && (isFinite(data18)))){
const err52 = {instancePath:instancePath+"/description/source/capabilities/batch_rows",schemaPath:"#/oneOf/0/properties/description/properties/source/properties/capabilities/properties/batch_rows/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err52];
}
else {
vErrors.push(err52);
}
errors++;
}
if(errors === _errs44){
if((typeof data18 == "number") && (isFinite(data18))){
if(data18 > 255 || isNaN(data18)){
const err53 = {instancePath:instancePath+"/description/source/capabilities/batch_rows",schemaPath:"#/oneOf/0/properties/description/properties/source/properties/capabilities/properties/batch_rows/maximum",keyword:"maximum",params:{comparison: "<=", limit: 255},message:"must be <= 255"};
if(vErrors === null){
vErrors = [err53];
}
else {
vErrors.push(err53);
}
errors++;
}
else {
if(data18 < 0 || isNaN(data18)){
const err54 = {instancePath:instancePath+"/description/source/capabilities/batch_rows",schemaPath:"#/oneOf/0/properties/description/properties/source/properties/capabilities/properties/batch_rows/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
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
var valid5 = _errs44 === errors;
}
else {
var valid5 = true;
}
if(valid5){
if(data10.columns !== undefined){
let data19 = data10.columns;
const _errs46 = errors;
if(!(((typeof data19 == "number") && (!(data19 % 1) && !isNaN(data19))) && (isFinite(data19)))){
const err55 = {instancePath:instancePath+"/description/source/capabilities/columns",schemaPath:"#/oneOf/0/properties/description/properties/source/properties/capabilities/properties/columns/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err55];
}
else {
vErrors.push(err55);
}
errors++;
}
if(errors === _errs46){
if((typeof data19 == "number") && (isFinite(data19))){
if(data19 > 255 || isNaN(data19)){
const err56 = {instancePath:instancePath+"/description/source/capabilities/columns",schemaPath:"#/oneOf/0/properties/description/properties/source/properties/capabilities/properties/columns/maximum",keyword:"maximum",params:{comparison: "<=", limit: 255},message:"must be <= 255"};
if(vErrors === null){
vErrors = [err56];
}
else {
vErrors.push(err56);
}
errors++;
}
else {
if(data19 < 0 || isNaN(data19)){
const err57 = {instancePath:instancePath+"/description/source/capabilities/columns",schemaPath:"#/oneOf/0/properties/description/properties/source/properties/capabilities/properties/columns/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err57];
}
else {
vErrors.push(err57);
}
errors++;
}
}
}
}
var valid5 = _errs46 === errors;
}
else {
var valid5 = true;
}
if(valid5){
if(data10.kv !== undefined){
const _errs48 = errors;
if(typeof data10.kv !== "boolean"){
const err58 = {instancePath:instancePath+"/description/source/capabilities/kv",schemaPath:"#/oneOf/0/properties/description/properties/source/properties/capabilities/properties/kv/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"};
if(vErrors === null){
vErrors = [err58];
}
else {
vErrors.push(err58);
}
errors++;
}
var valid5 = _errs48 === errors;
}
else {
var valid5 = true;
}
if(valid5){
if(data10.table !== undefined){
const _errs50 = errors;
if(typeof data10.table !== "boolean"){
const err59 = {instancePath:instancePath+"/description/source/capabilities/table",schemaPath:"#/oneOf/0/properties/description/properties/source/properties/capabilities/properties/table/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"};
if(vErrors === null){
vErrors = [err59];
}
else {
vErrors.push(err59);
}
errors++;
}
var valid5 = _errs50 === errors;
}
else {
var valid5 = true;
}
if(valid5){
if(data10.document !== undefined){
const _errs52 = errors;
if(typeof data10.document !== "boolean"){
const err60 = {instancePath:instancePath+"/description/source/capabilities/document",schemaPath:"#/oneOf/0/properties/description/properties/source/properties/capabilities/properties/document/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"};
if(vErrors === null){
vErrors = [err60];
}
else {
vErrors.push(err60);
}
errors++;
}
var valid5 = _errs52 === errors;
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
const err61 = {instancePath:instancePath+"/description/source/capabilities",schemaPath:"#/oneOf/0/properties/description/properties/source/properties/capabilities/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err61];
}
else {
vErrors.push(err61);
}
errors++;
}
}
var valid4 = _errs27 === errors;
}
else {
var valid4 = true;
}
if(valid4){
if(data9.source !== undefined){
let data23 = data9.source;
const _errs54 = errors;
if(errors === _errs54){
if(data23 && typeof data23 == "object" && !Array.isArray(data23)){
let missing5;
if((((data23.version === undefined) && (missing5 = "version")) || ((data23.resource === undefined) && (missing5 = "resource"))) || ((data23.source === undefined) && (missing5 = "source"))){
const err62 = {instancePath:instancePath+"/description/source/source",schemaPath:"#/oneOf/0/properties/description/properties/source/properties/source/required",keyword:"required",params:{missingProperty: missing5},message:"must have required property '"+missing5+"'"};
if(vErrors === null){
vErrors = [err62];
}
else {
vErrors.push(err62);
}
errors++;
}
else {
const _errs56 = errors;
for(const key5 in data23){
if(!(((key5 === "version") || (key5 === "resource")) || (key5 === "source"))){
const err63 = {instancePath:instancePath+"/description/source/source",schemaPath:"#/oneOf/0/properties/description/properties/source/properties/source/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key5},message:"must NOT have additional properties"};
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
if(_errs56 === errors){
if(data23.version !== undefined){
let data24 = data23.version;
const _errs57 = errors;
if(!(((typeof data24 == "number") && (!(data24 % 1) && !isNaN(data24))) && (isFinite(data24)))){
const err64 = {instancePath:instancePath+"/description/source/source/version",schemaPath:"#/oneOf/0/properties/description/properties/source/properties/source/properties/version/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err64];
}
else {
vErrors.push(err64);
}
errors++;
}
if(errors === _errs57){
if((typeof data24 == "number") && (isFinite(data24))){
if(data24 > 255 || isNaN(data24)){
const err65 = {instancePath:instancePath+"/description/source/source/version",schemaPath:"#/oneOf/0/properties/description/properties/source/properties/source/properties/version/maximum",keyword:"maximum",params:{comparison: "<=", limit: 255},message:"must be <= 255"};
if(vErrors === null){
vErrors = [err65];
}
else {
vErrors.push(err65);
}
errors++;
}
else {
if(data24 < 0 || isNaN(data24)){
const err66 = {instancePath:instancePath+"/description/source/source/version",schemaPath:"#/oneOf/0/properties/description/properties/source/properties/source/properties/version/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err66];
}
else {
vErrors.push(err66);
}
errors++;
}
}
}
}
var valid6 = _errs57 === errors;
}
else {
var valid6 = true;
}
if(valid6){
if(data23.resource !== undefined){
let data25 = data23.resource;
const _errs59 = errors;
if(!(((typeof data25 == "number") && (!(data25 % 1) && !isNaN(data25))) && (isFinite(data25)))){
const err67 = {instancePath:instancePath+"/description/source/source/resource",schemaPath:"#/oneOf/0/properties/description/properties/source/properties/source/properties/resource/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err67];
}
else {
vErrors.push(err67);
}
errors++;
}
if(errors === _errs59){
if((typeof data25 == "number") && (isFinite(data25))){
if(data25 > 9007199254740991 || isNaN(data25)){
const err68 = {instancePath:instancePath+"/description/source/source/resource",schemaPath:"#/oneOf/0/properties/description/properties/source/properties/source/properties/resource/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"};
if(vErrors === null){
vErrors = [err68];
}
else {
vErrors.push(err68);
}
errors++;
}
else {
if(data25 < 0 || isNaN(data25)){
const err69 = {instancePath:instancePath+"/description/source/source/resource",schemaPath:"#/oneOf/0/properties/description/properties/source/properties/source/properties/resource/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err69];
}
else {
vErrors.push(err69);
}
errors++;
}
}
}
}
var valid6 = _errs59 === errors;
}
else {
var valid6 = true;
}
if(valid6){
if(data23.source !== undefined){
let data26 = data23.source;
const _errs61 = errors;
const _errs62 = errors;
let valid7 = false;
let passing1 = null;
const _errs63 = errors;
if(errors === _errs63){
if(data26 && typeof data26 == "object" && !Array.isArray(data26)){
let missing6;
if((data26.kv === undefined) && (missing6 = "kv")){
const err70 = {instancePath:instancePath+"/description/source/source/source",schemaPath:"#/oneOf/0/properties/description/properties/source/properties/source/properties/source/oneOf/0/required",keyword:"required",params:{missingProperty: missing6},message:"must have required property '"+missing6+"'"};
if(vErrors === null){
vErrors = [err70];
}
else {
vErrors.push(err70);
}
errors++;
}
else {
const _errs65 = errors;
for(const key6 in data26){
if(!(key6 === "kv")){
const err71 = {instancePath:instancePath+"/description/source/source/source",schemaPath:"#/oneOf/0/properties/description/properties/source/properties/source/properties/source/oneOf/0/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key6},message:"must NOT have additional properties"};
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
if(_errs65 === errors){
if(data26.kv !== undefined){
let data27 = data26.kv;
const _errs66 = errors;
if(errors === _errs66){
if(data27 && typeof data27 == "object" && !Array.isArray(data27)){
let missing7;
if((((data27.prefix === undefined) && (missing7 = "prefix")) || ((data27.key === undefined) && (missing7 = "key"))) || ((data27.value === undefined) && (missing7 = "value"))){
const err72 = {instancePath:instancePath+"/description/source/source/source/kv",schemaPath:"#/oneOf/0/properties/description/properties/source/properties/source/properties/source/oneOf/0/properties/kv/required",keyword:"required",params:{missingProperty: missing7},message:"must have required property '"+missing7+"'"};
if(vErrors === null){
vErrors = [err72];
}
else {
vErrors.push(err72);
}
errors++;
}
else {
const _errs68 = errors;
for(const key7 in data27){
if(!(((key7 === "prefix") || (key7 === "key")) || (key7 === "value"))){
const err73 = {instancePath:instancePath+"/description/source/source/source/kv",schemaPath:"#/oneOf/0/properties/description/properties/source/properties/source/properties/source/oneOf/0/properties/kv/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key7},message:"must NOT have additional properties"};
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
if(_errs68 === errors){
if(data27.prefix !== undefined){
let data28 = data27.prefix;
const _errs69 = errors;
if(errors === _errs69){
if(typeof data28 === "string"){
if(func1(data28) > 131072){
const err74 = {instancePath:instancePath+"/description/source/source/source/kv/prefix",schemaPath:"#/oneOf/0/properties/description/properties/source/properties/source/properties/source/oneOf/0/properties/kv/properties/prefix/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
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
const err75 = {instancePath:instancePath+"/description/source/source/source/kv/prefix",schemaPath:"#/oneOf/0/properties/description/properties/source/properties/source/properties/source/oneOf/0/properties/kv/properties/prefix/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err75];
}
else {
vErrors.push(err75);
}
errors++;
}
}
var valid9 = _errs69 === errors;
}
else {
var valid9 = true;
}
if(valid9){
if(data27.key !== undefined){
let data29 = data27.key;
const _errs71 = errors;
if(errors === _errs71){
if(data29 && typeof data29 == "object" && !Array.isArray(data29)){
let missing8;
if(((data29.version === undefined) && (missing8 = "version")) || ((data29.type === undefined) && (missing8 = "type"))){
const err76 = {instancePath:instancePath+"/description/source/source/source/kv/key",schemaPath:"#/oneOf/0/properties/description/properties/source/properties/source/properties/source/oneOf/0/properties/kv/properties/key/required",keyword:"required",params:{missingProperty: missing8},message:"must have required property '"+missing8+"'"};
if(vErrors === null){
vErrors = [err76];
}
else {
vErrors.push(err76);
}
errors++;
}
else {
const _errs73 = errors;
for(const key8 in data29){
if(!((key8 === "version") || (key8 === "type"))){
const err77 = {instancePath:instancePath+"/description/source/source/source/kv/key",schemaPath:"#/oneOf/0/properties/description/properties/source/properties/source/properties/source/oneOf/0/properties/kv/properties/key/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key8},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err77];
}
else {
vErrors.push(err77);
}
errors++;
break;
}
}
if(_errs73 === errors){
if(data29.version !== undefined){
let data30 = data29.version;
const _errs74 = errors;
if(!(((typeof data30 == "number") && (!(data30 % 1) && !isNaN(data30))) && (isFinite(data30)))){
const err78 = {instancePath:instancePath+"/description/source/source/source/kv/key/version",schemaPath:"#/oneOf/0/properties/description/properties/source/properties/source/properties/source/oneOf/0/properties/kv/properties/key/properties/version/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err78];
}
else {
vErrors.push(err78);
}
errors++;
}
if(errors === _errs74){
if((typeof data30 == "number") && (isFinite(data30))){
if(data30 > 255 || isNaN(data30)){
const err79 = {instancePath:instancePath+"/description/source/source/source/kv/key/version",schemaPath:"#/oneOf/0/properties/description/properties/source/properties/source/properties/source/oneOf/0/properties/kv/properties/key/properties/version/maximum",keyword:"maximum",params:{comparison: "<=", limit: 255},message:"must be <= 255"};
if(vErrors === null){
vErrors = [err79];
}
else {
vErrors.push(err79);
}
errors++;
}
else {
if(data30 < 0 || isNaN(data30)){
const err80 = {instancePath:instancePath+"/description/source/source/source/kv/key/version",schemaPath:"#/oneOf/0/properties/description/properties/source/properties/source/properties/source/oneOf/0/properties/kv/properties/key/properties/version/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err80];
}
else {
vErrors.push(err80);
}
errors++;
}
}
}
}
var valid10 = _errs74 === errors;
}
else {
var valid10 = true;
}
if(valid10){
if(data29.type !== undefined){
let data31 = data29.type;
const _errs76 = errors;
if(typeof data31 !== "string"){
const err81 = {instancePath:instancePath+"/description/source/source/source/kv/key/type",schemaPath:"#/oneOf/0/properties/description/properties/source/properties/source/properties/source/oneOf/0/properties/kv/properties/key/properties/type/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err81];
}
else {
vErrors.push(err81);
}
errors++;
}
if(!((((((data31 === "int64") || (data31 === "uint64")) || (data31 === "float64")) || (data31 === "boolean")) || (data31 === "utf8")) || (data31 === "binary"))){
const err82 = {instancePath:instancePath+"/description/source/source/source/kv/key/type",schemaPath:"#/oneOf/0/properties/description/properties/source/properties/source/properties/source/oneOf/0/properties/kv/properties/key/properties/type/enum",keyword:"enum",params:{allowedValues: schema33.oneOf[0].properties.description.properties.source.properties.source.properties.source.oneOf[0].properties.kv.properties.key.properties.type.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err82];
}
else {
vErrors.push(err82);
}
errors++;
}
var valid10 = _errs76 === errors;
}
else {
var valid10 = true;
}
}
}
}
}
else {
const err83 = {instancePath:instancePath+"/description/source/source/source/kv/key",schemaPath:"#/oneOf/0/properties/description/properties/source/properties/source/properties/source/oneOf/0/properties/kv/properties/key/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err83];
}
else {
vErrors.push(err83);
}
errors++;
}
}
var valid9 = _errs71 === errors;
}
else {
var valid9 = true;
}
if(valid9){
if(data27.value !== undefined){
let data32 = data27.value;
const _errs78 = errors;
if(errors === _errs78){
if(data32 && typeof data32 == "object" && !Array.isArray(data32)){
let missing9;
if(((data32.version === undefined) && (missing9 = "version")) || ((data32.type === undefined) && (missing9 = "type"))){
const err84 = {instancePath:instancePath+"/description/source/source/source/kv/value",schemaPath:"#/oneOf/0/properties/description/properties/source/properties/source/properties/source/oneOf/0/properties/kv/properties/value/required",keyword:"required",params:{missingProperty: missing9},message:"must have required property '"+missing9+"'"};
if(vErrors === null){
vErrors = [err84];
}
else {
vErrors.push(err84);
}
errors++;
}
else {
const _errs80 = errors;
for(const key9 in data32){
if(!((key9 === "version") || (key9 === "type"))){
const err85 = {instancePath:instancePath+"/description/source/source/source/kv/value",schemaPath:"#/oneOf/0/properties/description/properties/source/properties/source/properties/source/oneOf/0/properties/kv/properties/value/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key9},message:"must NOT have additional properties"};
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
if(_errs80 === errors){
if(data32.version !== undefined){
let data33 = data32.version;
const _errs81 = errors;
if(!(((typeof data33 == "number") && (!(data33 % 1) && !isNaN(data33))) && (isFinite(data33)))){
const err86 = {instancePath:instancePath+"/description/source/source/source/kv/value/version",schemaPath:"#/oneOf/0/properties/description/properties/source/properties/source/properties/source/oneOf/0/properties/kv/properties/value/properties/version/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err86];
}
else {
vErrors.push(err86);
}
errors++;
}
if(errors === _errs81){
if((typeof data33 == "number") && (isFinite(data33))){
if(data33 > 255 || isNaN(data33)){
const err87 = {instancePath:instancePath+"/description/source/source/source/kv/value/version",schemaPath:"#/oneOf/0/properties/description/properties/source/properties/source/properties/source/oneOf/0/properties/kv/properties/value/properties/version/maximum",keyword:"maximum",params:{comparison: "<=", limit: 255},message:"must be <= 255"};
if(vErrors === null){
vErrors = [err87];
}
else {
vErrors.push(err87);
}
errors++;
}
else {
if(data33 < 0 || isNaN(data33)){
const err88 = {instancePath:instancePath+"/description/source/source/source/kv/value/version",schemaPath:"#/oneOf/0/properties/description/properties/source/properties/source/properties/source/oneOf/0/properties/kv/properties/value/properties/version/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err88];
}
else {
vErrors.push(err88);
}
errors++;
}
}
}
}
var valid11 = _errs81 === errors;
}
else {
var valid11 = true;
}
if(valid11){
if(data32.type !== undefined){
let data34 = data32.type;
const _errs83 = errors;
if(typeof data34 !== "string"){
const err89 = {instancePath:instancePath+"/description/source/source/source/kv/value/type",schemaPath:"#/oneOf/0/properties/description/properties/source/properties/source/properties/source/oneOf/0/properties/kv/properties/value/properties/type/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err89];
}
else {
vErrors.push(err89);
}
errors++;
}
if(!((((((data34 === "int64") || (data34 === "uint64")) || (data34 === "float64")) || (data34 === "boolean")) || (data34 === "utf8")) || (data34 === "binary"))){
const err90 = {instancePath:instancePath+"/description/source/source/source/kv/value/type",schemaPath:"#/oneOf/0/properties/description/properties/source/properties/source/properties/source/oneOf/0/properties/kv/properties/value/properties/type/enum",keyword:"enum",params:{allowedValues: schema33.oneOf[0].properties.description.properties.source.properties.source.properties.source.oneOf[0].properties.kv.properties.value.properties.type.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err90];
}
else {
vErrors.push(err90);
}
errors++;
}
var valid11 = _errs83 === errors;
}
else {
var valid11 = true;
}
}
}
}
}
else {
const err91 = {instancePath:instancePath+"/description/source/source/source/kv/value",schemaPath:"#/oneOf/0/properties/description/properties/source/properties/source/properties/source/oneOf/0/properties/kv/properties/value/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err91];
}
else {
vErrors.push(err91);
}
errors++;
}
}
var valid9 = _errs78 === errors;
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
const err92 = {instancePath:instancePath+"/description/source/source/source/kv",schemaPath:"#/oneOf/0/properties/description/properties/source/properties/source/properties/source/oneOf/0/properties/kv/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err92];
}
else {
vErrors.push(err92);
}
errors++;
}
}
}
}
}
}
else {
const err93 = {instancePath:instancePath+"/description/source/source/source",schemaPath:"#/oneOf/0/properties/description/properties/source/properties/source/properties/source/oneOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err93];
}
else {
vErrors.push(err93);
}
errors++;
}
}
var _valid1 = _errs63 === errors;
if(_valid1){
valid7 = true;
passing1 = 0;
var props0 = true;
}
const _errs85 = errors;
if(errors === _errs85){
if(data26 && typeof data26 == "object" && !Array.isArray(data26)){
let missing10;
if((data26.table === undefined) && (missing10 = "table")){
const err94 = {instancePath:instancePath+"/description/source/source/source",schemaPath:"#/oneOf/0/properties/description/properties/source/properties/source/properties/source/oneOf/1/required",keyword:"required",params:{missingProperty: missing10},message:"must have required property '"+missing10+"'"};
if(vErrors === null){
vErrors = [err94];
}
else {
vErrors.push(err94);
}
errors++;
}
else {
const _errs87 = errors;
for(const key10 in data26){
if(!(key10 === "table")){
const err95 = {instancePath:instancePath+"/description/source/source/source",schemaPath:"#/oneOf/0/properties/description/properties/source/properties/source/properties/source/oneOf/1/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key10},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err95];
}
else {
vErrors.push(err95);
}
errors++;
break;
}
}
if(_errs87 === errors){
if(data26.table !== undefined){
let data35 = data26.table;
const _errs88 = errors;
if(errors === _errs88){
if(data35 && typeof data35 == "object" && !Array.isArray(data35)){
let missing11;
if((((data35.id === undefined) && (missing11 = "id")) || ((data35.names === undefined) && (missing11 = "names"))) || ((data35.value_type === undefined) && (missing11 = "value_type"))){
const err96 = {instancePath:instancePath+"/description/source/source/source/table",schemaPath:"#/oneOf/0/properties/description/properties/source/properties/source/properties/source/oneOf/1/properties/table/required",keyword:"required",params:{missingProperty: missing11},message:"must have required property '"+missing11+"'"};
if(vErrors === null){
vErrors = [err96];
}
else {
vErrors.push(err96);
}
errors++;
}
else {
const _errs90 = errors;
for(const key11 in data35){
if(!(((key11 === "id") || (key11 === "names")) || (key11 === "value_type"))){
const err97 = {instancePath:instancePath+"/description/source/source/source/table",schemaPath:"#/oneOf/0/properties/description/properties/source/properties/source/properties/source/oneOf/1/properties/table/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key11},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err97];
}
else {
vErrors.push(err97);
}
errors++;
break;
}
}
if(_errs90 === errors){
if(data35.id !== undefined){
let data36 = data35.id;
const _errs91 = errors;
if(!(((typeof data36 == "number") && (!(data36 % 1) && !isNaN(data36))) && (isFinite(data36)))){
const err98 = {instancePath:instancePath+"/description/source/source/source/table/id",schemaPath:"#/oneOf/0/properties/description/properties/source/properties/source/properties/source/oneOf/1/properties/table/properties/id/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err98];
}
else {
vErrors.push(err98);
}
errors++;
}
if(errors === _errs91){
if((typeof data36 == "number") && (isFinite(data36))){
if(data36 > 4294967295 || isNaN(data36)){
const err99 = {instancePath:instancePath+"/description/source/source/source/table/id",schemaPath:"#/oneOf/0/properties/description/properties/source/properties/source/properties/source/oneOf/1/properties/table/properties/id/maximum",keyword:"maximum",params:{comparison: "<=", limit: 4294967295},message:"must be <= 4294967295"};
if(vErrors === null){
vErrors = [err99];
}
else {
vErrors.push(err99);
}
errors++;
}
else {
if(data36 < 0 || isNaN(data36)){
const err100 = {instancePath:instancePath+"/description/source/source/source/table/id",schemaPath:"#/oneOf/0/properties/description/properties/source/properties/source/properties/source/oneOf/1/properties/table/properties/id/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err100];
}
else {
vErrors.push(err100);
}
errors++;
}
}
}
}
var valid13 = _errs91 === errors;
}
else {
var valid13 = true;
}
if(valid13){
if(data35.names !== undefined){
let data37 = data35.names;
const _errs93 = errors;
if(errors === _errs93){
if(Array.isArray(data37)){
if(data37.length > 2){
const err101 = {instancePath:instancePath+"/description/source/source/source/table/names",schemaPath:"#/oneOf/0/properties/description/properties/source/properties/source/properties/source/oneOf/1/properties/table/properties/names/maxItems",keyword:"maxItems",params:{limit: 2},message:"must NOT have more than 2 items"};
if(vErrors === null){
vErrors = [err101];
}
else {
vErrors.push(err101);
}
errors++;
}
else {
if(data37.length < 2){
const err102 = {instancePath:instancePath+"/description/source/source/source/table/names",schemaPath:"#/oneOf/0/properties/description/properties/source/properties/source/properties/source/oneOf/1/properties/table/properties/names/minItems",keyword:"minItems",params:{limit: 2},message:"must NOT have fewer than 2 items"};
if(vErrors === null){
vErrors = [err102];
}
else {
vErrors.push(err102);
}
errors++;
}
else {
var valid14 = true;
const len0 = data37.length;
for(let i0=0; i0<len0; i0++){
let data38 = data37[i0];
const _errs95 = errors;
if(errors === _errs95){
if(typeof data38 === "string"){
if(func1(data38) > 131072){
const err103 = {instancePath:instancePath+"/description/source/source/source/table/names/" + i0,schemaPath:"#/oneOf/0/properties/description/properties/source/properties/source/properties/source/oneOf/1/properties/table/properties/names/items/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err103];
}
else {
vErrors.push(err103);
}
errors++;
}
}
else {
const err104 = {instancePath:instancePath+"/description/source/source/source/table/names/" + i0,schemaPath:"#/oneOf/0/properties/description/properties/source/properties/source/properties/source/oneOf/1/properties/table/properties/names/items/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err104];
}
else {
vErrors.push(err104);
}
errors++;
}
}
var valid14 = _errs95 === errors;
if(!valid14){
break;
}
}
}
}
}
else {
const err105 = {instancePath:instancePath+"/description/source/source/source/table/names",schemaPath:"#/oneOf/0/properties/description/properties/source/properties/source/properties/source/oneOf/1/properties/table/properties/names/type",keyword:"type",params:{type: "array"},message:"must be array"};
if(vErrors === null){
vErrors = [err105];
}
else {
vErrors.push(err105);
}
errors++;
}
}
var valid13 = _errs93 === errors;
}
else {
var valid13 = true;
}
if(valid13){
if(data35.value_type !== undefined){
let data39 = data35.value_type;
const _errs97 = errors;
if(typeof data39 !== "string"){
const err106 = {instancePath:instancePath+"/description/source/source/source/table/value_type",schemaPath:"#/oneOf/0/properties/description/properties/source/properties/source/properties/source/oneOf/1/properties/table/properties/value_type/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err106];
}
else {
vErrors.push(err106);
}
errors++;
}
if(!((((data39 === "int64") || (data39 === "boolean")) || (data39 === "utf8")) || (data39 === "binary"))){
const err107 = {instancePath:instancePath+"/description/source/source/source/table/value_type",schemaPath:"#/oneOf/0/properties/description/properties/source/properties/source/properties/source/oneOf/1/properties/table/properties/value_type/enum",keyword:"enum",params:{allowedValues: schema33.oneOf[0].properties.description.properties.source.properties.source.properties.source.oneOf[1].properties.table.properties.value_type.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err107];
}
else {
vErrors.push(err107);
}
errors++;
}
var valid13 = _errs97 === errors;
}
else {
var valid13 = true;
}
}
}
}
}
}
else {
const err108 = {instancePath:instancePath+"/description/source/source/source/table",schemaPath:"#/oneOf/0/properties/description/properties/source/properties/source/properties/source/oneOf/1/properties/table/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err108];
}
else {
vErrors.push(err108);
}
errors++;
}
}
}
}
}
}
else {
const err109 = {instancePath:instancePath+"/description/source/source/source",schemaPath:"#/oneOf/0/properties/description/properties/source/properties/source/properties/source/oneOf/1/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err109];
}
else {
vErrors.push(err109);
}
errors++;
}
}
var _valid1 = _errs85 === errors;
if(_valid1 && valid7){
valid7 = false;
passing1 = [passing1, 1];
}
else {
if(_valid1){
valid7 = true;
passing1 = 1;
if(props0 !== true){
props0 = true;
}
}
const _errs99 = errors;
if(errors === _errs99){
if(data26 && typeof data26 == "object" && !Array.isArray(data26)){
let missing12;
if((data26.document === undefined) && (missing12 = "document")){
const err110 = {instancePath:instancePath+"/description/source/source/source",schemaPath:"#/oneOf/0/properties/description/properties/source/properties/source/properties/source/oneOf/2/required",keyword:"required",params:{missingProperty: missing12},message:"must have required property '"+missing12+"'"};
if(vErrors === null){
vErrors = [err110];
}
else {
vErrors.push(err110);
}
errors++;
}
else {
const _errs101 = errors;
for(const key12 in data26){
if(!(key12 === "document")){
const err111 = {instancePath:instancePath+"/description/source/source/source",schemaPath:"#/oneOf/0/properties/description/properties/source/properties/source/properties/source/oneOf/2/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key12},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err111];
}
else {
vErrors.push(err111);
}
errors++;
break;
}
}
if(_errs101 === errors){
if(data26.document !== undefined){
let data40 = data26.document;
const _errs102 = errors;
if(errors === _errs102){
if(data40 && typeof data40 == "object" && !Array.isArray(data40)){
let missing13;
if(((((data40.reference === undefined) && (missing13 = "reference")) || ((data40.change_format === undefined) && (missing13 = "change_format"))) || ((data40.expand === undefined) && (missing13 = "expand"))) || ((data40.projections === undefined) && (missing13 = "projections"))){
const err112 = {instancePath:instancePath+"/description/source/source/source/document",schemaPath:"#/oneOf/0/properties/description/properties/source/properties/source/properties/source/oneOf/2/properties/document/required",keyword:"required",params:{missingProperty: missing13},message:"must have required property '"+missing13+"'"};
if(vErrors === null){
vErrors = [err112];
}
else {
vErrors.push(err112);
}
errors++;
}
else {
const _errs104 = errors;
for(const key13 in data40){
if(!((((key13 === "reference") || (key13 === "change_format")) || (key13 === "expand")) || (key13 === "projections"))){
const err113 = {instancePath:instancePath+"/description/source/source/source/document",schemaPath:"#/oneOf/0/properties/description/properties/source/properties/source/properties/source/oneOf/2/properties/document/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key13},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err113];
}
else {
vErrors.push(err113);
}
errors++;
break;
}
}
if(_errs104 === errors){
if(data40.reference !== undefined){
let data41 = data40.reference;
const _errs105 = errors;
if(errors === _errs105){
if(data41 && typeof data41 == "object" && !Array.isArray(data41)){
let missing14;
if((((((data41.resource === undefined) && (missing14 = "resource")) || ((data41.document === undefined) && (missing14 = "document"))) || ((data41.epoch === undefined) && (missing14 = "epoch"))) || ((data41.type_revision === undefined) && (missing14 = "type_revision"))) || ((data41.revision === undefined) && (missing14 = "revision"))){
const err114 = {instancePath:instancePath+"/description/source/source/source/document/reference",schemaPath:"#/oneOf/0/properties/description/properties/source/properties/source/properties/source/oneOf/2/properties/document/properties/reference/required",keyword:"required",params:{missingProperty: missing14},message:"must have required property '"+missing14+"'"};
if(vErrors === null){
vErrors = [err114];
}
else {
vErrors.push(err114);
}
errors++;
}
else {
const _errs107 = errors;
for(const key14 in data41){
if(!(((((key14 === "resource") || (key14 === "document")) || (key14 === "epoch")) || (key14 === "type_revision")) || (key14 === "revision"))){
const err115 = {instancePath:instancePath+"/description/source/source/source/document/reference",schemaPath:"#/oneOf/0/properties/description/properties/source/properties/source/properties/source/oneOf/2/properties/document/properties/reference/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key14},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err115];
}
else {
vErrors.push(err115);
}
errors++;
break;
}
}
if(_errs107 === errors){
if(data41.resource !== undefined){
let data42 = data41.resource;
const _errs108 = errors;
if(!(((typeof data42 == "number") && (!(data42 % 1) && !isNaN(data42))) && (isFinite(data42)))){
const err116 = {instancePath:instancePath+"/description/source/source/source/document/reference/resource",schemaPath:"#/oneOf/0/properties/description/properties/source/properties/source/properties/source/oneOf/2/properties/document/properties/reference/properties/resource/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err116];
}
else {
vErrors.push(err116);
}
errors++;
}
if(errors === _errs108){
if((typeof data42 == "number") && (isFinite(data42))){
if(data42 > 9007199254740991 || isNaN(data42)){
const err117 = {instancePath:instancePath+"/description/source/source/source/document/reference/resource",schemaPath:"#/oneOf/0/properties/description/properties/source/properties/source/properties/source/oneOf/2/properties/document/properties/reference/properties/resource/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"};
if(vErrors === null){
vErrors = [err117];
}
else {
vErrors.push(err117);
}
errors++;
}
else {
if(data42 < 0 || isNaN(data42)){
const err118 = {instancePath:instancePath+"/description/source/source/source/document/reference/resource",schemaPath:"#/oneOf/0/properties/description/properties/source/properties/source/properties/source/oneOf/2/properties/document/properties/reference/properties/resource/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err118];
}
else {
vErrors.push(err118);
}
errors++;
}
}
}
}
var valid17 = _errs108 === errors;
}
else {
var valid17 = true;
}
if(valid17){
if(data41.document !== undefined){
let data43 = data41.document;
const _errs110 = errors;
if(errors === _errs110){
if(typeof data43 === "string"){
if(func1(data43) > 131072){
const err119 = {instancePath:instancePath+"/description/source/source/source/document/reference/document",schemaPath:"#/oneOf/0/properties/description/properties/source/properties/source/properties/source/oneOf/2/properties/document/properties/reference/properties/document/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err119];
}
else {
vErrors.push(err119);
}
errors++;
}
}
else {
const err120 = {instancePath:instancePath+"/description/source/source/source/document/reference/document",schemaPath:"#/oneOf/0/properties/description/properties/source/properties/source/properties/source/oneOf/2/properties/document/properties/reference/properties/document/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err120];
}
else {
vErrors.push(err120);
}
errors++;
}
}
var valid17 = _errs110 === errors;
}
else {
var valid17 = true;
}
if(valid17){
if(data41.epoch !== undefined){
let data44 = data41.epoch;
const _errs112 = errors;
if(errors === _errs112){
if(typeof data44 === "string"){
if(func1(data44) > 131072){
const err121 = {instancePath:instancePath+"/description/source/source/source/document/reference/epoch",schemaPath:"#/oneOf/0/properties/description/properties/source/properties/source/properties/source/oneOf/2/properties/document/properties/reference/properties/epoch/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err121];
}
else {
vErrors.push(err121);
}
errors++;
}
}
else {
const err122 = {instancePath:instancePath+"/description/source/source/source/document/reference/epoch",schemaPath:"#/oneOf/0/properties/description/properties/source/properties/source/properties/source/oneOf/2/properties/document/properties/reference/properties/epoch/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err122];
}
else {
vErrors.push(err122);
}
errors++;
}
}
var valid17 = _errs112 === errors;
}
else {
var valid17 = true;
}
if(valid17){
if(data41.type_revision !== undefined){
let data45 = data41.type_revision;
const _errs114 = errors;
if(!(((typeof data45 == "number") && (!(data45 % 1) && !isNaN(data45))) && (isFinite(data45)))){
const err123 = {instancePath:instancePath+"/description/source/source/source/document/reference/type_revision",schemaPath:"#/oneOf/0/properties/description/properties/source/properties/source/properties/source/oneOf/2/properties/document/properties/reference/properties/type_revision/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err123];
}
else {
vErrors.push(err123);
}
errors++;
}
if(errors === _errs114){
if((typeof data45 == "number") && (isFinite(data45))){
if(data45 > 4294967295 || isNaN(data45)){
const err124 = {instancePath:instancePath+"/description/source/source/source/document/reference/type_revision",schemaPath:"#/oneOf/0/properties/description/properties/source/properties/source/properties/source/oneOf/2/properties/document/properties/reference/properties/type_revision/maximum",keyword:"maximum",params:{comparison: "<=", limit: 4294967295},message:"must be <= 4294967295"};
if(vErrors === null){
vErrors = [err124];
}
else {
vErrors.push(err124);
}
errors++;
}
else {
if(data45 < 0 || isNaN(data45)){
const err125 = {instancePath:instancePath+"/description/source/source/source/document/reference/type_revision",schemaPath:"#/oneOf/0/properties/description/properties/source/properties/source/properties/source/oneOf/2/properties/document/properties/reference/properties/type_revision/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err125];
}
else {
vErrors.push(err125);
}
errors++;
}
}
}
}
var valid17 = _errs114 === errors;
}
else {
var valid17 = true;
}
if(valid17){
if(data41.revision !== undefined){
let data46 = data41.revision;
const _errs116 = errors;
if(errors === _errs116){
if(typeof data46 === "string"){
if(func1(data46) > 131072){
const err126 = {instancePath:instancePath+"/description/source/source/source/document/reference/revision",schemaPath:"#/oneOf/0/properties/description/properties/source/properties/source/properties/source/oneOf/2/properties/document/properties/reference/properties/revision/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err126];
}
else {
vErrors.push(err126);
}
errors++;
}
}
else {
const err127 = {instancePath:instancePath+"/description/source/source/source/document/reference/revision",schemaPath:"#/oneOf/0/properties/description/properties/source/properties/source/properties/source/oneOf/2/properties/document/properties/reference/properties/revision/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err127];
}
else {
vErrors.push(err127);
}
errors++;
}
}
var valid17 = _errs116 === errors;
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
}
else {
const err128 = {instancePath:instancePath+"/description/source/source/source/document/reference",schemaPath:"#/oneOf/0/properties/description/properties/source/properties/source/properties/source/oneOf/2/properties/document/properties/reference/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err128];
}
else {
vErrors.push(err128);
}
errors++;
}
}
var valid16 = _errs105 === errors;
}
else {
var valid16 = true;
}
if(valid16){
if(data40.change_format !== undefined){
let data47 = data40.change_format;
const _errs118 = errors;
if(!(((typeof data47 == "number") && (!(data47 % 1) && !isNaN(data47))) && (isFinite(data47)))){
const err129 = {instancePath:instancePath+"/description/source/source/source/document/change_format",schemaPath:"#/oneOf/0/properties/description/properties/source/properties/source/properties/source/oneOf/2/properties/document/properties/change_format/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err129];
}
else {
vErrors.push(err129);
}
errors++;
}
if(errors === _errs118){
if((typeof data47 == "number") && (isFinite(data47))){
if(data47 > 4294967295 || isNaN(data47)){
const err130 = {instancePath:instancePath+"/description/source/source/source/document/change_format",schemaPath:"#/oneOf/0/properties/description/properties/source/properties/source/properties/source/oneOf/2/properties/document/properties/change_format/maximum",keyword:"maximum",params:{comparison: "<=", limit: 4294967295},message:"must be <= 4294967295"};
if(vErrors === null){
vErrors = [err130];
}
else {
vErrors.push(err130);
}
errors++;
}
else {
if(data47 < 0 || isNaN(data47)){
const err131 = {instancePath:instancePath+"/description/source/source/source/document/change_format",schemaPath:"#/oneOf/0/properties/description/properties/source/properties/source/properties/source/oneOf/2/properties/document/properties/change_format/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err131];
}
else {
vErrors.push(err131);
}
errors++;
}
}
}
}
var valid16 = _errs118 === errors;
}
else {
var valid16 = true;
}
if(valid16){
if(data40.expand !== undefined){
let data48 = data40.expand;
const _errs120 = errors;
const _errs121 = errors;
let valid18 = false;
const _errs122 = errors;
if(errors === _errs122){
if(Array.isArray(data48)){
if(data48.length > 8){
const err132 = {instancePath:instancePath+"/description/source/source/source/document/expand",schemaPath:"#/oneOf/0/properties/description/properties/source/properties/source/properties/source/oneOf/2/properties/document/properties/expand/anyOf/0/maxItems",keyword:"maxItems",params:{limit: 8},message:"must NOT have more than 8 items"};
if(vErrors === null){
vErrors = [err132];
}
else {
vErrors.push(err132);
}
errors++;
}
else {
var valid19 = true;
const len1 = data48.length;
for(let i1=0; i1<len1; i1++){
let data49 = data48[i1];
const _errs124 = errors;
if(errors === _errs124){
if(typeof data49 === "string"){
if(func1(data49) > 131072){
const err133 = {instancePath:instancePath+"/description/source/source/source/document/expand/" + i1,schemaPath:"#/oneOf/0/properties/description/properties/source/properties/source/properties/source/oneOf/2/properties/document/properties/expand/anyOf/0/items/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err133];
}
else {
vErrors.push(err133);
}
errors++;
}
}
else {
const err134 = {instancePath:instancePath+"/description/source/source/source/document/expand/" + i1,schemaPath:"#/oneOf/0/properties/description/properties/source/properties/source/properties/source/oneOf/2/properties/document/properties/expand/anyOf/0/items/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err134];
}
else {
vErrors.push(err134);
}
errors++;
}
}
var valid19 = _errs124 === errors;
if(!valid19){
break;
}
}
}
}
else {
const err135 = {instancePath:instancePath+"/description/source/source/source/document/expand",schemaPath:"#/oneOf/0/properties/description/properties/source/properties/source/properties/source/oneOf/2/properties/document/properties/expand/anyOf/0/type",keyword:"type",params:{type: "array"},message:"must be array"};
if(vErrors === null){
vErrors = [err135];
}
else {
vErrors.push(err135);
}
errors++;
}
}
var _valid2 = _errs122 === errors;
valid18 = valid18 || _valid2;
const _errs126 = errors;
if(data48 !== null){
const err136 = {instancePath:instancePath+"/description/source/source/source/document/expand",schemaPath:"#/oneOf/0/properties/description/properties/source/properties/source/properties/source/oneOf/2/properties/document/properties/expand/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err136];
}
else {
vErrors.push(err136);
}
errors++;
}
var _valid2 = _errs126 === errors;
valid18 = valid18 || _valid2;
if(!valid18){
const err137 = {instancePath:instancePath+"/description/source/source/source/document/expand",schemaPath:"#/oneOf/0/properties/description/properties/source/properties/source/properties/source/oneOf/2/properties/document/properties/expand/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err137];
}
else {
vErrors.push(err137);
}
errors++;
}
else {
errors = _errs121;
if(vErrors !== null){
if(_errs121){
vErrors.length = _errs121;
}
else {
vErrors = null;
}
}
}
var valid16 = _errs120 === errors;
}
else {
var valid16 = true;
}
if(valid16){
if(data40.projections !== undefined){
let data50 = data40.projections;
const _errs128 = errors;
if(errors === _errs128){
if(Array.isArray(data50)){
if(data50.length > 8){
const err138 = {instancePath:instancePath+"/description/source/source/source/document/projections",schemaPath:"#/oneOf/0/properties/description/properties/source/properties/source/properties/source/oneOf/2/properties/document/properties/projections/maxItems",keyword:"maxItems",params:{limit: 8},message:"must NOT have more than 8 items"};
if(vErrors === null){
vErrors = [err138];
}
else {
vErrors.push(err138);
}
errors++;
}
else {
var valid20 = true;
const len2 = data50.length;
for(let i2=0; i2<len2; i2++){
let data51 = data50[i2];
const _errs130 = errors;
if(errors === _errs130){
if(data51 && typeof data51 == "object" && !Array.isArray(data51)){
let missing15;
if(((((((data51.column === undefined) && (missing15 = "column")) || ((data51.path === undefined) && (missing15 = "path"))) || ((data51.relative === undefined) && (missing15 = "relative"))) || ((data51.mode === undefined) && (missing15 = "mode"))) || ((data51.text_bytes === undefined) && (missing15 = "text_bytes"))) || ((data51.text_steps === undefined) && (missing15 = "text_steps"))){
const err139 = {instancePath:instancePath+"/description/source/source/source/document/projections/" + i2,schemaPath:"#/oneOf/0/properties/description/properties/source/properties/source/properties/source/oneOf/2/properties/document/properties/projections/items/required",keyword:"required",params:{missingProperty: missing15},message:"must have required property '"+missing15+"'"};
if(vErrors === null){
vErrors = [err139];
}
else {
vErrors.push(err139);
}
errors++;
}
else {
const _errs132 = errors;
for(const key15 in data51){
if(!((((((key15 === "column") || (key15 === "path")) || (key15 === "relative")) || (key15 === "mode")) || (key15 === "text_bytes")) || (key15 === "text_steps"))){
const err140 = {instancePath:instancePath+"/description/source/source/source/document/projections/" + i2,schemaPath:"#/oneOf/0/properties/description/properties/source/properties/source/properties/source/oneOf/2/properties/document/properties/projections/items/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key15},message:"must NOT have additional properties"};
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
if(_errs132 === errors){
if(data51.column !== undefined){
let data52 = data51.column;
const _errs133 = errors;
if(errors === _errs133){
if(data52 && typeof data52 == "object" && !Array.isArray(data52)){
let missing16;
if(((data52.name === undefined) && (missing16 = "name")) || ((data52.type === undefined) && (missing16 = "type"))){
const err141 = {instancePath:instancePath+"/description/source/source/source/document/projections/" + i2+"/column",schemaPath:"#/oneOf/0/properties/description/properties/source/properties/source/properties/source/oneOf/2/properties/document/properties/projections/items/properties/column/required",keyword:"required",params:{missingProperty: missing16},message:"must have required property '"+missing16+"'"};
if(vErrors === null){
vErrors = [err141];
}
else {
vErrors.push(err141);
}
errors++;
}
else {
const _errs135 = errors;
for(const key16 in data52){
if(!((key16 === "name") || (key16 === "type"))){
const err142 = {instancePath:instancePath+"/description/source/source/source/document/projections/" + i2+"/column",schemaPath:"#/oneOf/0/properties/description/properties/source/properties/source/properties/source/oneOf/2/properties/document/properties/projections/items/properties/column/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key16},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err142];
}
else {
vErrors.push(err142);
}
errors++;
break;
}
}
if(_errs135 === errors){
if(data52.name !== undefined){
let data53 = data52.name;
const _errs136 = errors;
if(errors === _errs136){
if(typeof data53 === "string"){
if(func1(data53) > 131072){
const err143 = {instancePath:instancePath+"/description/source/source/source/document/projections/" + i2+"/column/name",schemaPath:"#/oneOf/0/properties/description/properties/source/properties/source/properties/source/oneOf/2/properties/document/properties/projections/items/properties/column/properties/name/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err143];
}
else {
vErrors.push(err143);
}
errors++;
}
}
else {
const err144 = {instancePath:instancePath+"/description/source/source/source/document/projections/" + i2+"/column/name",schemaPath:"#/oneOf/0/properties/description/properties/source/properties/source/properties/source/oneOf/2/properties/document/properties/projections/items/properties/column/properties/name/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err144];
}
else {
vErrors.push(err144);
}
errors++;
}
}
var valid22 = _errs136 === errors;
}
else {
var valid22 = true;
}
if(valid22){
if(data52.type !== undefined){
let data54 = data52.type;
const _errs138 = errors;
if(typeof data54 !== "string"){
const err145 = {instancePath:instancePath+"/description/source/source/source/document/projections/" + i2+"/column/type",schemaPath:"#/oneOf/0/properties/description/properties/source/properties/source/properties/source/oneOf/2/properties/document/properties/projections/items/properties/column/properties/type/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err145];
}
else {
vErrors.push(err145);
}
errors++;
}
if(!((((((data54 === "int64") || (data54 === "uint64")) || (data54 === "float64")) || (data54 === "boolean")) || (data54 === "utf8")) || (data54 === "binary"))){
const err146 = {instancePath:instancePath+"/description/source/source/source/document/projections/" + i2+"/column/type",schemaPath:"#/oneOf/0/properties/description/properties/source/properties/source/properties/source/oneOf/2/properties/document/properties/projections/items/properties/column/properties/type/enum",keyword:"enum",params:{allowedValues: schema33.oneOf[0].properties.description.properties.source.properties.source.properties.source.oneOf[2].properties.document.properties.projections.items.properties.column.properties.type.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err146];
}
else {
vErrors.push(err146);
}
errors++;
}
var valid22 = _errs138 === errors;
}
else {
var valid22 = true;
}
}
}
}
}
else {
const err147 = {instancePath:instancePath+"/description/source/source/source/document/projections/" + i2+"/column",schemaPath:"#/oneOf/0/properties/description/properties/source/properties/source/properties/source/oneOf/2/properties/document/properties/projections/items/properties/column/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err147];
}
else {
vErrors.push(err147);
}
errors++;
}
}
var valid21 = _errs133 === errors;
}
else {
var valid21 = true;
}
if(valid21){
if(data51.path !== undefined){
let data55 = data51.path;
const _errs140 = errors;
if(errors === _errs140){
if(Array.isArray(data55)){
if(data55.length > 8){
const err148 = {instancePath:instancePath+"/description/source/source/source/document/projections/" + i2+"/path",schemaPath:"#/oneOf/0/properties/description/properties/source/properties/source/properties/source/oneOf/2/properties/document/properties/projections/items/properties/path/maxItems",keyword:"maxItems",params:{limit: 8},message:"must NOT have more than 8 items"};
if(vErrors === null){
vErrors = [err148];
}
else {
vErrors.push(err148);
}
errors++;
}
else {
var valid23 = true;
const len3 = data55.length;
for(let i3=0; i3<len3; i3++){
let data56 = data55[i3];
const _errs142 = errors;
if(errors === _errs142){
if(typeof data56 === "string"){
if(func1(data56) > 131072){
const err149 = {instancePath:instancePath+"/description/source/source/source/document/projections/" + i2+"/path/" + i3,schemaPath:"#/oneOf/0/properties/description/properties/source/properties/source/properties/source/oneOf/2/properties/document/properties/projections/items/properties/path/items/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err149];
}
else {
vErrors.push(err149);
}
errors++;
}
}
else {
const err150 = {instancePath:instancePath+"/description/source/source/source/document/projections/" + i2+"/path/" + i3,schemaPath:"#/oneOf/0/properties/description/properties/source/properties/source/properties/source/oneOf/2/properties/document/properties/projections/items/properties/path/items/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err150];
}
else {
vErrors.push(err150);
}
errors++;
}
}
var valid23 = _errs142 === errors;
if(!valid23){
break;
}
}
}
}
else {
const err151 = {instancePath:instancePath+"/description/source/source/source/document/projections/" + i2+"/path",schemaPath:"#/oneOf/0/properties/description/properties/source/properties/source/properties/source/oneOf/2/properties/document/properties/projections/items/properties/path/type",keyword:"type",params:{type: "array"},message:"must be array"};
if(vErrors === null){
vErrors = [err151];
}
else {
vErrors.push(err151);
}
errors++;
}
}
var valid21 = _errs140 === errors;
}
else {
var valid21 = true;
}
if(valid21){
if(data51.relative !== undefined){
const _errs144 = errors;
if(typeof data51.relative !== "boolean"){
const err152 = {instancePath:instancePath+"/description/source/source/source/document/projections/" + i2+"/relative",schemaPath:"#/oneOf/0/properties/description/properties/source/properties/source/properties/source/oneOf/2/properties/document/properties/projections/items/properties/relative/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"};
if(vErrors === null){
vErrors = [err152];
}
else {
vErrors.push(err152);
}
errors++;
}
var valid21 = _errs144 === errors;
}
else {
var valid21 = true;
}
if(valid21){
if(data51.mode !== undefined){
let data58 = data51.mode;
const _errs146 = errors;
if(typeof data58 !== "string"){
const err153 = {instancePath:instancePath+"/description/source/source/source/document/projections/" + i2+"/mode",schemaPath:"#/oneOf/0/properties/description/properties/source/properties/source/properties/source/oneOf/2/properties/document/properties/projections/items/properties/mode/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err153];
}
else {
vErrors.push(err153);
}
errors++;
}
if(!((((data58 === "scalar") || (data58 === "text")) || (data58 === "element_counter")) || (data58 === "element_replica"))){
const err154 = {instancePath:instancePath+"/description/source/source/source/document/projections/" + i2+"/mode",schemaPath:"#/oneOf/0/properties/description/properties/source/properties/source/properties/source/oneOf/2/properties/document/properties/projections/items/properties/mode/enum",keyword:"enum",params:{allowedValues: schema33.oneOf[0].properties.description.properties.source.properties.source.properties.source.oneOf[2].properties.document.properties.projections.items.properties.mode.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err154];
}
else {
vErrors.push(err154);
}
errors++;
}
var valid21 = _errs146 === errors;
}
else {
var valid21 = true;
}
if(valid21){
if(data51.text_bytes !== undefined){
let data59 = data51.text_bytes;
const _errs148 = errors;
if(!(((typeof data59 == "number") && (!(data59 % 1) && !isNaN(data59))) && (isFinite(data59)))){
const err155 = {instancePath:instancePath+"/description/source/source/source/document/projections/" + i2+"/text_bytes",schemaPath:"#/oneOf/0/properties/description/properties/source/properties/source/properties/source/oneOf/2/properties/document/properties/projections/items/properties/text_bytes/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err155];
}
else {
vErrors.push(err155);
}
errors++;
}
if(errors === _errs148){
if((typeof data59 == "number") && (isFinite(data59))){
if(data59 > 65535 || isNaN(data59)){
const err156 = {instancePath:instancePath+"/description/source/source/source/document/projections/" + i2+"/text_bytes",schemaPath:"#/oneOf/0/properties/description/properties/source/properties/source/properties/source/oneOf/2/properties/document/properties/projections/items/properties/text_bytes/maximum",keyword:"maximum",params:{comparison: "<=", limit: 65535},message:"must be <= 65535"};
if(vErrors === null){
vErrors = [err156];
}
else {
vErrors.push(err156);
}
errors++;
}
else {
if(data59 < 0 || isNaN(data59)){
const err157 = {instancePath:instancePath+"/description/source/source/source/document/projections/" + i2+"/text_bytes",schemaPath:"#/oneOf/0/properties/description/properties/source/properties/source/properties/source/oneOf/2/properties/document/properties/projections/items/properties/text_bytes/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err157];
}
else {
vErrors.push(err157);
}
errors++;
}
}
}
}
var valid21 = _errs148 === errors;
}
else {
var valid21 = true;
}
if(valid21){
if(data51.text_steps !== undefined){
let data60 = data51.text_steps;
const _errs150 = errors;
if(!(((typeof data60 == "number") && (!(data60 % 1) && !isNaN(data60))) && (isFinite(data60)))){
const err158 = {instancePath:instancePath+"/description/source/source/source/document/projections/" + i2+"/text_steps",schemaPath:"#/oneOf/0/properties/description/properties/source/properties/source/properties/source/oneOf/2/properties/document/properties/projections/items/properties/text_steps/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err158];
}
else {
vErrors.push(err158);
}
errors++;
}
if(errors === _errs150){
if((typeof data60 == "number") && (isFinite(data60))){
if(data60 > 65535 || isNaN(data60)){
const err159 = {instancePath:instancePath+"/description/source/source/source/document/projections/" + i2+"/text_steps",schemaPath:"#/oneOf/0/properties/description/properties/source/properties/source/properties/source/oneOf/2/properties/document/properties/projections/items/properties/text_steps/maximum",keyword:"maximum",params:{comparison: "<=", limit: 65535},message:"must be <= 65535"};
if(vErrors === null){
vErrors = [err159];
}
else {
vErrors.push(err159);
}
errors++;
}
else {
if(data60 < 0 || isNaN(data60)){
const err160 = {instancePath:instancePath+"/description/source/source/source/document/projections/" + i2+"/text_steps",schemaPath:"#/oneOf/0/properties/description/properties/source/properties/source/properties/source/oneOf/2/properties/document/properties/projections/items/properties/text_steps/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err160];
}
else {
vErrors.push(err160);
}
errors++;
}
}
}
}
var valid21 = _errs150 === errors;
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
const err161 = {instancePath:instancePath+"/description/source/source/source/document/projections/" + i2,schemaPath:"#/oneOf/0/properties/description/properties/source/properties/source/properties/source/oneOf/2/properties/document/properties/projections/items/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err161];
}
else {
vErrors.push(err161);
}
errors++;
}
}
var valid20 = _errs130 === errors;
if(!valid20){
break;
}
}
}
}
else {
const err162 = {instancePath:instancePath+"/description/source/source/source/document/projections",schemaPath:"#/oneOf/0/properties/description/properties/source/properties/source/properties/source/oneOf/2/properties/document/properties/projections/type",keyword:"type",params:{type: "array"},message:"must be array"};
if(vErrors === null){
vErrors = [err162];
}
else {
vErrors.push(err162);
}
errors++;
}
}
var valid16 = _errs128 === errors;
}
else {
var valid16 = true;
}
}
}
}
}
}
}
else {
const err163 = {instancePath:instancePath+"/description/source/source/source/document",schemaPath:"#/oneOf/0/properties/description/properties/source/properties/source/properties/source/oneOf/2/properties/document/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err163];
}
else {
vErrors.push(err163);
}
errors++;
}
}
}
}
}
}
else {
const err164 = {instancePath:instancePath+"/description/source/source/source",schemaPath:"#/oneOf/0/properties/description/properties/source/properties/source/properties/source/oneOf/2/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err164];
}
else {
vErrors.push(err164);
}
errors++;
}
}
var _valid1 = _errs99 === errors;
if(_valid1 && valid7){
valid7 = false;
passing1 = [passing1, 2];
}
else {
if(_valid1){
valid7 = true;
passing1 = 2;
if(props0 !== true){
props0 = true;
}
}
}
}
if(!valid7){
const err165 = {instancePath:instancePath+"/description/source/source/source",schemaPath:"#/oneOf/0/properties/description/properties/source/properties/source/properties/source/oneOf",keyword:"oneOf",params:{passingSchemas: passing1},message:"must match exactly one schema in oneOf"};
if(vErrors === null){
vErrors = [err165];
}
else {
vErrors.push(err165);
}
errors++;
}
else {
errors = _errs62;
if(vErrors !== null){
if(_errs62){
vErrors.length = _errs62;
}
else {
vErrors = null;
}
}
}
var valid6 = _errs61 === errors;
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
const err166 = {instancePath:instancePath+"/description/source/source",schemaPath:"#/oneOf/0/properties/description/properties/source/properties/source/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err166];
}
else {
vErrors.push(err166);
}
errors++;
}
}
var valid4 = _errs54 === errors;
}
else {
var valid4 = true;
}
if(valid4){
if(data9.resource_revision !== undefined){
let data61 = data9.resource_revision;
const _errs152 = errors;
if(!(((typeof data61 == "number") && (!(data61 % 1) && !isNaN(data61))) && (isFinite(data61)))){
const err167 = {instancePath:instancePath+"/description/source/resource_revision",schemaPath:"#/oneOf/0/properties/description/properties/source/properties/resource_revision/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err167];
}
else {
vErrors.push(err167);
}
errors++;
}
if(errors === _errs152){
if((typeof data61 == "number") && (isFinite(data61))){
if(data61 > 9007199254740991 || isNaN(data61)){
const err168 = {instancePath:instancePath+"/description/source/resource_revision",schemaPath:"#/oneOf/0/properties/description/properties/source/properties/resource_revision/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"};
if(vErrors === null){
vErrors = [err168];
}
else {
vErrors.push(err168);
}
errors++;
}
else {
if(data61 < 0 || isNaN(data61)){
const err169 = {instancePath:instancePath+"/description/source/resource_revision",schemaPath:"#/oneOf/0/properties/description/properties/source/properties/resource_revision/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err169];
}
else {
vErrors.push(err169);
}
errors++;
}
}
}
}
var valid4 = _errs152 === errors;
}
else {
var valid4 = true;
}
if(valid4){
if(data9.policy_revision !== undefined){
let data62 = data9.policy_revision;
const _errs154 = errors;
if(errors === _errs154){
if(typeof data62 === "string"){
if(func1(data62) > 131072){
const err170 = {instancePath:instancePath+"/description/source/policy_revision",schemaPath:"#/oneOf/0/properties/description/properties/source/properties/policy_revision/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err170];
}
else {
vErrors.push(err170);
}
errors++;
}
}
else {
const err171 = {instancePath:instancePath+"/description/source/policy_revision",schemaPath:"#/oneOf/0/properties/description/properties/source/properties/policy_revision/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err171];
}
else {
vErrors.push(err171);
}
errors++;
}
}
var valid4 = _errs154 === errors;
}
else {
var valid4 = true;
}
if(valid4){
if(data9.limits !== undefined){
let data63 = data9.limits;
const _errs156 = errors;
if(errors === _errs156){
if(data63 && typeof data63 == "object" && !Array.isArray(data63)){
let missing17;
if((((data63.pages === undefined) && (missing17 = "pages")) || ((data63.segments === undefined) && (missing17 = "segments"))) || ((data63.result_bytes === undefined) && (missing17 = "result_bytes"))){
const err172 = {instancePath:instancePath+"/description/source/limits",schemaPath:"#/oneOf/0/properties/description/properties/source/properties/limits/required",keyword:"required",params:{missingProperty: missing17},message:"must have required property '"+missing17+"'"};
if(vErrors === null){
vErrors = [err172];
}
else {
vErrors.push(err172);
}
errors++;
}
else {
const _errs158 = errors;
for(const key17 in data63){
if(!(((key17 === "pages") || (key17 === "segments")) || (key17 === "result_bytes"))){
const err173 = {instancePath:instancePath+"/description/source/limits",schemaPath:"#/oneOf/0/properties/description/properties/source/properties/limits/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key17},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err173];
}
else {
vErrors.push(err173);
}
errors++;
break;
}
}
if(_errs158 === errors){
if(data63.pages !== undefined){
let data64 = data63.pages;
const _errs159 = errors;
if(errors === _errs159){
if(typeof data64 === "string"){
if(func1(data64) > 131072){
const err174 = {instancePath:instancePath+"/description/source/limits/pages",schemaPath:"#/oneOf/0/properties/description/properties/source/properties/limits/properties/pages/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err174];
}
else {
vErrors.push(err174);
}
errors++;
}
}
else {
const err175 = {instancePath:instancePath+"/description/source/limits/pages",schemaPath:"#/oneOf/0/properties/description/properties/source/properties/limits/properties/pages/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err175];
}
else {
vErrors.push(err175);
}
errors++;
}
}
var valid24 = _errs159 === errors;
}
else {
var valid24 = true;
}
if(valid24){
if(data63.segments !== undefined){
let data65 = data63.segments;
const _errs161 = errors;
if(errors === _errs161){
if(typeof data65 === "string"){
if(func1(data65) > 131072){
const err176 = {instancePath:instancePath+"/description/source/limits/segments",schemaPath:"#/oneOf/0/properties/description/properties/source/properties/limits/properties/segments/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err176];
}
else {
vErrors.push(err176);
}
errors++;
}
}
else {
const err177 = {instancePath:instancePath+"/description/source/limits/segments",schemaPath:"#/oneOf/0/properties/description/properties/source/properties/limits/properties/segments/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err177];
}
else {
vErrors.push(err177);
}
errors++;
}
}
var valid24 = _errs161 === errors;
}
else {
var valid24 = true;
}
if(valid24){
if(data63.result_bytes !== undefined){
let data66 = data63.result_bytes;
const _errs163 = errors;
if(errors === _errs163){
if(typeof data66 === "string"){
if(func1(data66) > 131072){
const err178 = {instancePath:instancePath+"/description/source/limits/result_bytes",schemaPath:"#/oneOf/0/properties/description/properties/source/properties/limits/properties/result_bytes/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err178];
}
else {
vErrors.push(err178);
}
errors++;
}
}
else {
const err179 = {instancePath:instancePath+"/description/source/limits/result_bytes",schemaPath:"#/oneOf/0/properties/description/properties/source/properties/limits/properties/result_bytes/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err179];
}
else {
vErrors.push(err179);
}
errors++;
}
}
var valid24 = _errs163 === errors;
}
else {
var valid24 = true;
}
}
}
}
}
}
else {
const err180 = {instancePath:instancePath+"/description/source/limits",schemaPath:"#/oneOf/0/properties/description/properties/source/properties/limits/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err180];
}
else {
vErrors.push(err180);
}
errors++;
}
}
var valid4 = _errs156 === errors;
}
else {
var valid4 = true;
}
if(valid4){
if(data9.active !== undefined){
let data67 = data9.active;
const _errs165 = errors;
const _errs166 = errors;
let valid25 = false;
const _errs167 = errors;
if(errors === _errs167){
if(typeof data67 === "string"){
if(func1(data67) > 131072){
const err181 = {instancePath:instancePath+"/description/source/active",schemaPath:"#/oneOf/0/properties/description/properties/source/properties/active/anyOf/0/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err181];
}
else {
vErrors.push(err181);
}
errors++;
}
}
else {
const err182 = {instancePath:instancePath+"/description/source/active",schemaPath:"#/oneOf/0/properties/description/properties/source/properties/active/anyOf/0/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err182];
}
else {
vErrors.push(err182);
}
errors++;
}
}
var _valid3 = _errs167 === errors;
valid25 = valid25 || _valid3;
const _errs169 = errors;
if(data67 !== null){
const err183 = {instancePath:instancePath+"/description/source/active",schemaPath:"#/oneOf/0/properties/description/properties/source/properties/active/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err183];
}
else {
vErrors.push(err183);
}
errors++;
}
var _valid3 = _errs169 === errors;
valid25 = valid25 || _valid3;
if(!valid25){
const err184 = {instancePath:instancePath+"/description/source/active",schemaPath:"#/oneOf/0/properties/description/properties/source/properties/active/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err184];
}
else {
vErrors.push(err184);
}
errors++;
}
else {
errors = _errs166;
if(vErrors !== null){
if(_errs166){
vErrors.length = _errs166;
}
else {
vErrors = null;
}
}
}
var valid4 = _errs165 === errors;
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
const err185 = {instancePath:instancePath+"/description/source",schemaPath:"#/oneOf/0/properties/description/properties/source/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err185];
}
else {
vErrors.push(err185);
}
errors++;
}
}
var valid2 = _errs24 === errors;
}
else {
var valid2 = true;
}
if(valid2){
if(data0.sql !== undefined){
let data68 = data0.sql;
const _errs171 = errors;
if(errors === _errs171){
if(data68 && typeof data68 == "object" && !Array.isArray(data68)){
let missing18;
if((((((((((((data68.version === undefined) && (missing18 = "version")) || ((data68.statement_bytes === undefined) && (missing18 = "statement_bytes"))) || ((data68.named_columns === undefined) && (missing18 = "named_columns"))) || ((data68.star_columns === undefined) && (missing18 = "star_columns"))) || ((data68.uint64_limits === undefined) && (missing18 = "uint64_limits"))) || ((data68.uint64_literals === undefined) && (missing18 = "uint64_literals"))) || ((data68.float64_literals === undefined) && (missing18 = "float64_literals"))) || ((data68.null_comparison === undefined) && (missing18 = "null_comparison"))) || ((data68.explicit_null_test === undefined) && (missing18 = "explicit_null_test"))) || ((data68.writes === undefined) && (missing18 = "writes"))) || ((data68.continuous === undefined) && (missing18 = "continuous"))){
const err186 = {instancePath:instancePath+"/description/sql",schemaPath:"#/oneOf/0/properties/description/properties/sql/required",keyword:"required",params:{missingProperty: missing18},message:"must have required property '"+missing18+"'"};
if(vErrors === null){
vErrors = [err186];
}
else {
vErrors.push(err186);
}
errors++;
}
else {
const _errs173 = errors;
for(const key18 in data68){
if(!(func24.call(schema33.oneOf[0].properties.description.properties.sql.properties, key18))){
const err187 = {instancePath:instancePath+"/description/sql",schemaPath:"#/oneOf/0/properties/description/properties/sql/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key18},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err187];
}
else {
vErrors.push(err187);
}
errors++;
break;
}
}
if(_errs173 === errors){
if(data68.version !== undefined){
let data69 = data68.version;
const _errs174 = errors;
if(!(((typeof data69 == "number") && (!(data69 % 1) && !isNaN(data69))) && (isFinite(data69)))){
const err188 = {instancePath:instancePath+"/description/sql/version",schemaPath:"#/oneOf/0/properties/description/properties/sql/properties/version/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err188];
}
else {
vErrors.push(err188);
}
errors++;
}
if(errors === _errs174){
if((typeof data69 == "number") && (isFinite(data69))){
if(data69 > 255 || isNaN(data69)){
const err189 = {instancePath:instancePath+"/description/sql/version",schemaPath:"#/oneOf/0/properties/description/properties/sql/properties/version/maximum",keyword:"maximum",params:{comparison: "<=", limit: 255},message:"must be <= 255"};
if(vErrors === null){
vErrors = [err189];
}
else {
vErrors.push(err189);
}
errors++;
}
else {
if(data69 < 0 || isNaN(data69)){
const err190 = {instancePath:instancePath+"/description/sql/version",schemaPath:"#/oneOf/0/properties/description/properties/sql/properties/version/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err190];
}
else {
vErrors.push(err190);
}
errors++;
}
}
}
}
var valid26 = _errs174 === errors;
}
else {
var valid26 = true;
}
if(valid26){
if(data68.statement_bytes !== undefined){
let data70 = data68.statement_bytes;
const _errs176 = errors;
if(!(((typeof data70 == "number") && (!(data70 % 1) && !isNaN(data70))) && (isFinite(data70)))){
const err191 = {instancePath:instancePath+"/description/sql/statement_bytes",schemaPath:"#/oneOf/0/properties/description/properties/sql/properties/statement_bytes/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err191];
}
else {
vErrors.push(err191);
}
errors++;
}
if(errors === _errs176){
if((typeof data70 == "number") && (isFinite(data70))){
if(data70 > 4294967295 || isNaN(data70)){
const err192 = {instancePath:instancePath+"/description/sql/statement_bytes",schemaPath:"#/oneOf/0/properties/description/properties/sql/properties/statement_bytes/maximum",keyword:"maximum",params:{comparison: "<=", limit: 4294967295},message:"must be <= 4294967295"};
if(vErrors === null){
vErrors = [err192];
}
else {
vErrors.push(err192);
}
errors++;
}
else {
if(data70 < 0 || isNaN(data70)){
const err193 = {instancePath:instancePath+"/description/sql/statement_bytes",schemaPath:"#/oneOf/0/properties/description/properties/sql/properties/statement_bytes/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err193];
}
else {
vErrors.push(err193);
}
errors++;
}
}
}
}
var valid26 = _errs176 === errors;
}
else {
var valid26 = true;
}
if(valid26){
if(data68.named_columns !== undefined){
let data71 = data68.named_columns;
const _errs178 = errors;
if(!(((typeof data71 == "number") && (!(data71 % 1) && !isNaN(data71))) && (isFinite(data71)))){
const err194 = {instancePath:instancePath+"/description/sql/named_columns",schemaPath:"#/oneOf/0/properties/description/properties/sql/properties/named_columns/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err194];
}
else {
vErrors.push(err194);
}
errors++;
}
if(errors === _errs178){
if((typeof data71 == "number") && (isFinite(data71))){
if(data71 > 255 || isNaN(data71)){
const err195 = {instancePath:instancePath+"/description/sql/named_columns",schemaPath:"#/oneOf/0/properties/description/properties/sql/properties/named_columns/maximum",keyword:"maximum",params:{comparison: "<=", limit: 255},message:"must be <= 255"};
if(vErrors === null){
vErrors = [err195];
}
else {
vErrors.push(err195);
}
errors++;
}
else {
if(data71 < 0 || isNaN(data71)){
const err196 = {instancePath:instancePath+"/description/sql/named_columns",schemaPath:"#/oneOf/0/properties/description/properties/sql/properties/named_columns/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err196];
}
else {
vErrors.push(err196);
}
errors++;
}
}
}
}
var valid26 = _errs178 === errors;
}
else {
var valid26 = true;
}
if(valid26){
if(data68.star_columns !== undefined){
let data72 = data68.star_columns;
const _errs180 = errors;
if(!(((typeof data72 == "number") && (!(data72 % 1) && !isNaN(data72))) && (isFinite(data72)))){
const err197 = {instancePath:instancePath+"/description/sql/star_columns",schemaPath:"#/oneOf/0/properties/description/properties/sql/properties/star_columns/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err197];
}
else {
vErrors.push(err197);
}
errors++;
}
if(errors === _errs180){
if((typeof data72 == "number") && (isFinite(data72))){
if(data72 > 255 || isNaN(data72)){
const err198 = {instancePath:instancePath+"/description/sql/star_columns",schemaPath:"#/oneOf/0/properties/description/properties/sql/properties/star_columns/maximum",keyword:"maximum",params:{comparison: "<=", limit: 255},message:"must be <= 255"};
if(vErrors === null){
vErrors = [err198];
}
else {
vErrors.push(err198);
}
errors++;
}
else {
if(data72 < 0 || isNaN(data72)){
const err199 = {instancePath:instancePath+"/description/sql/star_columns",schemaPath:"#/oneOf/0/properties/description/properties/sql/properties/star_columns/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err199];
}
else {
vErrors.push(err199);
}
errors++;
}
}
}
}
var valid26 = _errs180 === errors;
}
else {
var valid26 = true;
}
if(valid26){
if(data68.uint64_limits !== undefined){
const _errs182 = errors;
if(typeof data68.uint64_limits !== "boolean"){
const err200 = {instancePath:instancePath+"/description/sql/uint64_limits",schemaPath:"#/oneOf/0/properties/description/properties/sql/properties/uint64_limits/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"};
if(vErrors === null){
vErrors = [err200];
}
else {
vErrors.push(err200);
}
errors++;
}
var valid26 = _errs182 === errors;
}
else {
var valid26 = true;
}
if(valid26){
if(data68.uint64_literals !== undefined){
const _errs184 = errors;
if(typeof data68.uint64_literals !== "boolean"){
const err201 = {instancePath:instancePath+"/description/sql/uint64_literals",schemaPath:"#/oneOf/0/properties/description/properties/sql/properties/uint64_literals/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"};
if(vErrors === null){
vErrors = [err201];
}
else {
vErrors.push(err201);
}
errors++;
}
var valid26 = _errs184 === errors;
}
else {
var valid26 = true;
}
if(valid26){
if(data68.float64_literals !== undefined){
const _errs186 = errors;
if(typeof data68.float64_literals !== "boolean"){
const err202 = {instancePath:instancePath+"/description/sql/float64_literals",schemaPath:"#/oneOf/0/properties/description/properties/sql/properties/float64_literals/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"};
if(vErrors === null){
vErrors = [err202];
}
else {
vErrors.push(err202);
}
errors++;
}
var valid26 = _errs186 === errors;
}
else {
var valid26 = true;
}
if(valid26){
if(data68.null_comparison !== undefined){
const _errs188 = errors;
if(typeof data68.null_comparison !== "boolean"){
const err203 = {instancePath:instancePath+"/description/sql/null_comparison",schemaPath:"#/oneOf/0/properties/description/properties/sql/properties/null_comparison/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"};
if(vErrors === null){
vErrors = [err203];
}
else {
vErrors.push(err203);
}
errors++;
}
var valid26 = _errs188 === errors;
}
else {
var valid26 = true;
}
if(valid26){
if(data68.explicit_null_test !== undefined){
const _errs190 = errors;
if(typeof data68.explicit_null_test !== "boolean"){
const err204 = {instancePath:instancePath+"/description/sql/explicit_null_test",schemaPath:"#/oneOf/0/properties/description/properties/sql/properties/explicit_null_test/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"};
if(vErrors === null){
vErrors = [err204];
}
else {
vErrors.push(err204);
}
errors++;
}
var valid26 = _errs190 === errors;
}
else {
var valid26 = true;
}
if(valid26){
if(data68.writes !== undefined){
const _errs192 = errors;
if(typeof data68.writes !== "boolean"){
const err205 = {instancePath:instancePath+"/description/sql/writes",schemaPath:"#/oneOf/0/properties/description/properties/sql/properties/writes/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"};
if(vErrors === null){
vErrors = [err205];
}
else {
vErrors.push(err205);
}
errors++;
}
var valid26 = _errs192 === errors;
}
else {
var valid26 = true;
}
if(valid26){
if(data68.continuous !== undefined){
const _errs194 = errors;
if(typeof data68.continuous !== "boolean"){
const err206 = {instancePath:instancePath+"/description/sql/continuous",schemaPath:"#/oneOf/0/properties/description/properties/sql/properties/continuous/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"};
if(vErrors === null){
vErrors = [err206];
}
else {
vErrors.push(err206);
}
errors++;
}
var valid26 = _errs194 === errors;
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
}
}
else {
const err207 = {instancePath:instancePath+"/description/sql",schemaPath:"#/oneOf/0/properties/description/properties/sql/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err207];
}
else {
vErrors.push(err207);
}
errors++;
}
}
var valid2 = _errs171 === errors;
}
else {
var valid2 = true;
}
if(valid2){
if(data0.budgets !== undefined){
let data80 = data0.budgets;
const _errs196 = errors;
if(errors === _errs196){
if(data80 && typeof data80 == "object" && !Array.isArray(data80)){
let missing19;
if((((data80.pages === undefined) && (missing19 = "pages")) || ((data80.segments === undefined) && (missing19 = "segments"))) || ((data80.result_bytes === undefined) && (missing19 = "result_bytes"))){
const err208 = {instancePath:instancePath+"/description/budgets",schemaPath:"#/oneOf/0/properties/description/properties/budgets/required",keyword:"required",params:{missingProperty: missing19},message:"must have required property '"+missing19+"'"};
if(vErrors === null){
vErrors = [err208];
}
else {
vErrors.push(err208);
}
errors++;
}
else {
const _errs198 = errors;
for(const key19 in data80){
if(!(((key19 === "pages") || (key19 === "segments")) || (key19 === "result_bytes"))){
const err209 = {instancePath:instancePath+"/description/budgets",schemaPath:"#/oneOf/0/properties/description/properties/budgets/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key19},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err209];
}
else {
vErrors.push(err209);
}
errors++;
break;
}
}
if(_errs198 === errors){
if(data80.pages !== undefined){
let data81 = data80.pages;
const _errs199 = errors;
if(errors === _errs199){
if(typeof data81 === "string"){
if(func1(data81) > 131072){
const err210 = {instancePath:instancePath+"/description/budgets/pages",schemaPath:"#/oneOf/0/properties/description/properties/budgets/properties/pages/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err210];
}
else {
vErrors.push(err210);
}
errors++;
}
}
else {
const err211 = {instancePath:instancePath+"/description/budgets/pages",schemaPath:"#/oneOf/0/properties/description/properties/budgets/properties/pages/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err211];
}
else {
vErrors.push(err211);
}
errors++;
}
}
var valid27 = _errs199 === errors;
}
else {
var valid27 = true;
}
if(valid27){
if(data80.segments !== undefined){
let data82 = data80.segments;
const _errs201 = errors;
if(errors === _errs201){
if(typeof data82 === "string"){
if(func1(data82) > 131072){
const err212 = {instancePath:instancePath+"/description/budgets/segments",schemaPath:"#/oneOf/0/properties/description/properties/budgets/properties/segments/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err212];
}
else {
vErrors.push(err212);
}
errors++;
}
}
else {
const err213 = {instancePath:instancePath+"/description/budgets/segments",schemaPath:"#/oneOf/0/properties/description/properties/budgets/properties/segments/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err213];
}
else {
vErrors.push(err213);
}
errors++;
}
}
var valid27 = _errs201 === errors;
}
else {
var valid27 = true;
}
if(valid27){
if(data80.result_bytes !== undefined){
let data83 = data80.result_bytes;
const _errs203 = errors;
if(errors === _errs203){
if(typeof data83 === "string"){
if(func1(data83) > 131072){
const err214 = {instancePath:instancePath+"/description/budgets/result_bytes",schemaPath:"#/oneOf/0/properties/description/properties/budgets/properties/result_bytes/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err214];
}
else {
vErrors.push(err214);
}
errors++;
}
}
else {
const err215 = {instancePath:instancePath+"/description/budgets/result_bytes",schemaPath:"#/oneOf/0/properties/description/properties/budgets/properties/result_bytes/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err215];
}
else {
vErrors.push(err215);
}
errors++;
}
}
var valid27 = _errs203 === errors;
}
else {
var valid27 = true;
}
}
}
}
}
}
else {
const err216 = {instancePath:instancePath+"/description/budgets",schemaPath:"#/oneOf/0/properties/description/properties/budgets/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err216];
}
else {
vErrors.push(err216);
}
errors++;
}
}
var valid2 = _errs196 === errors;
}
else {
var valid2 = true;
}
if(valid2){
if(data0.columns !== undefined){
let data84 = data0.columns;
const _errs205 = errors;
if(errors === _errs205){
if(Array.isArray(data84)){
if(data84.length > 8){
const err217 = {instancePath:instancePath+"/description/columns",schemaPath:"#/oneOf/0/properties/description/properties/columns/maxItems",keyword:"maxItems",params:{limit: 8},message:"must NOT have more than 8 items"};
if(vErrors === null){
vErrors = [err217];
}
else {
vErrors.push(err217);
}
errors++;
}
else {
var valid28 = true;
const len4 = data84.length;
for(let i4=0; i4<len4; i4++){
let data85 = data84[i4];
const _errs207 = errors;
if(errors === _errs207){
if(data85 && typeof data85 == "object" && !Array.isArray(data85)){
let missing20;
if(((data85.name === undefined) && (missing20 = "name")) || ((data85.type === undefined) && (missing20 = "type"))){
const err218 = {instancePath:instancePath+"/description/columns/" + i4,schemaPath:"#/oneOf/0/properties/description/properties/columns/items/required",keyword:"required",params:{missingProperty: missing20},message:"must have required property '"+missing20+"'"};
if(vErrors === null){
vErrors = [err218];
}
else {
vErrors.push(err218);
}
errors++;
}
else {
const _errs209 = errors;
for(const key20 in data85){
if(!((key20 === "name") || (key20 === "type"))){
const err219 = {instancePath:instancePath+"/description/columns/" + i4,schemaPath:"#/oneOf/0/properties/description/properties/columns/items/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key20},message:"must NOT have additional properties"};
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
if(_errs209 === errors){
if(data85.name !== undefined){
let data86 = data85.name;
const _errs210 = errors;
if(errors === _errs210){
if(typeof data86 === "string"){
if(func1(data86) > 131072){
const err220 = {instancePath:instancePath+"/description/columns/" + i4+"/name",schemaPath:"#/oneOf/0/properties/description/properties/columns/items/properties/name/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err220];
}
else {
vErrors.push(err220);
}
errors++;
}
}
else {
const err221 = {instancePath:instancePath+"/description/columns/" + i4+"/name",schemaPath:"#/oneOf/0/properties/description/properties/columns/items/properties/name/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err221];
}
else {
vErrors.push(err221);
}
errors++;
}
}
var valid29 = _errs210 === errors;
}
else {
var valid29 = true;
}
if(valid29){
if(data85.type !== undefined){
let data87 = data85.type;
const _errs212 = errors;
if(typeof data87 !== "string"){
const err222 = {instancePath:instancePath+"/description/columns/" + i4+"/type",schemaPath:"#/oneOf/0/properties/description/properties/columns/items/properties/type/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err222];
}
else {
vErrors.push(err222);
}
errors++;
}
if(!((((((data87 === "int64") || (data87 === "uint64")) || (data87 === "float64")) || (data87 === "boolean")) || (data87 === "utf8")) || (data87 === "binary"))){
const err223 = {instancePath:instancePath+"/description/columns/" + i4+"/type",schemaPath:"#/oneOf/0/properties/description/properties/columns/items/properties/type/enum",keyword:"enum",params:{allowedValues: schema33.oneOf[0].properties.description.properties.columns.items.properties.type.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err223];
}
else {
vErrors.push(err223);
}
errors++;
}
var valid29 = _errs212 === errors;
}
else {
var valid29 = true;
}
}
}
}
}
else {
const err224 = {instancePath:instancePath+"/description/columns/" + i4,schemaPath:"#/oneOf/0/properties/description/properties/columns/items/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err224];
}
else {
vErrors.push(err224);
}
errors++;
}
}
var valid28 = _errs207 === errors;
if(!valid28){
break;
}
}
}
}
else {
const err225 = {instancePath:instancePath+"/description/columns",schemaPath:"#/oneOf/0/properties/description/properties/columns/type",keyword:"type",params:{type: "array"},message:"must be array"};
if(vErrors === null){
vErrors = [err225];
}
else {
vErrors.push(err225);
}
errors++;
}
}
var valid2 = _errs205 === errors;
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
const err226 = {instancePath:instancePath+"/description",schemaPath:"#/oneOf/0/properties/description/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err226];
}
else {
vErrors.push(err226);
}
errors++;
}
}
}
}
}
}
else {
const err227 = {instancePath,schemaPath:"#/oneOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err227];
}
else {
vErrors.push(err227);
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
const _errs214 = errors;
if(errors === _errs214){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing21;
if((data.sql_capabilities === undefined) && (missing21 = "sql_capabilities")){
const err228 = {instancePath,schemaPath:"#/oneOf/1/required",keyword:"required",params:{missingProperty: missing21},message:"must have required property '"+missing21+"'"};
if(vErrors === null){
vErrors = [err228];
}
else {
vErrors.push(err228);
}
errors++;
}
else {
const _errs216 = errors;
for(const key21 in data){
if(!(key21 === "sql_capabilities")){
const err229 = {instancePath,schemaPath:"#/oneOf/1/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key21},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err229];
}
else {
vErrors.push(err229);
}
errors++;
break;
}
}
if(_errs216 === errors){
if(data.sql_capabilities !== undefined){
let data88 = data.sql_capabilities;
const _errs217 = errors;
if(errors === _errs217){
if(data88 && typeof data88 == "object" && !Array.isArray(data88)){
let missing22;
if(((((data88.version === undefined) && (missing22 = "version")) || ((data88.parameters === undefined) && (missing22 = "parameters"))) || ((data88.max_parameters === undefined) && (missing22 = "max_parameters"))) || ((data88.statement_bytes === undefined) && (missing22 = "statement_bytes"))){
const err230 = {instancePath:instancePath+"/sql_capabilities",schemaPath:"#/oneOf/1/properties/sql_capabilities/required",keyword:"required",params:{missingProperty: missing22},message:"must have required property '"+missing22+"'"};
if(vErrors === null){
vErrors = [err230];
}
else {
vErrors.push(err230);
}
errors++;
}
else {
const _errs219 = errors;
for(const key22 in data88){
if(!((((key22 === "version") || (key22 === "parameters")) || (key22 === "max_parameters")) || (key22 === "statement_bytes"))){
const err231 = {instancePath:instancePath+"/sql_capabilities",schemaPath:"#/oneOf/1/properties/sql_capabilities/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key22},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err231];
}
else {
vErrors.push(err231);
}
errors++;
break;
}
}
if(_errs219 === errors){
if(data88.version !== undefined){
let data89 = data88.version;
const _errs220 = errors;
if(!(((typeof data89 == "number") && (!(data89 % 1) && !isNaN(data89))) && (isFinite(data89)))){
const err232 = {instancePath:instancePath+"/sql_capabilities/version",schemaPath:"#/oneOf/1/properties/sql_capabilities/properties/version/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err232];
}
else {
vErrors.push(err232);
}
errors++;
}
if(errors === _errs220){
if((typeof data89 == "number") && (isFinite(data89))){
if(data89 > 255 || isNaN(data89)){
const err233 = {instancePath:instancePath+"/sql_capabilities/version",schemaPath:"#/oneOf/1/properties/sql_capabilities/properties/version/maximum",keyword:"maximum",params:{comparison: "<=", limit: 255},message:"must be <= 255"};
if(vErrors === null){
vErrors = [err233];
}
else {
vErrors.push(err233);
}
errors++;
}
else {
if(data89 < 0 || isNaN(data89)){
const err234 = {instancePath:instancePath+"/sql_capabilities/version",schemaPath:"#/oneOf/1/properties/sql_capabilities/properties/version/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err234];
}
else {
vErrors.push(err234);
}
errors++;
}
}
}
}
var valid31 = _errs220 === errors;
}
else {
var valid31 = true;
}
if(valid31){
if(data88.parameters !== undefined){
const _errs222 = errors;
if(typeof data88.parameters !== "boolean"){
const err235 = {instancePath:instancePath+"/sql_capabilities/parameters",schemaPath:"#/oneOf/1/properties/sql_capabilities/properties/parameters/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"};
if(vErrors === null){
vErrors = [err235];
}
else {
vErrors.push(err235);
}
errors++;
}
var valid31 = _errs222 === errors;
}
else {
var valid31 = true;
}
if(valid31){
if(data88.max_parameters !== undefined){
let data91 = data88.max_parameters;
const _errs224 = errors;
if(!(((typeof data91 == "number") && (!(data91 % 1) && !isNaN(data91))) && (isFinite(data91)))){
const err236 = {instancePath:instancePath+"/sql_capabilities/max_parameters",schemaPath:"#/oneOf/1/properties/sql_capabilities/properties/max_parameters/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err236];
}
else {
vErrors.push(err236);
}
errors++;
}
if(errors === _errs224){
if((typeof data91 == "number") && (isFinite(data91))){
if(data91 > 255 || isNaN(data91)){
const err237 = {instancePath:instancePath+"/sql_capabilities/max_parameters",schemaPath:"#/oneOf/1/properties/sql_capabilities/properties/max_parameters/maximum",keyword:"maximum",params:{comparison: "<=", limit: 255},message:"must be <= 255"};
if(vErrors === null){
vErrors = [err237];
}
else {
vErrors.push(err237);
}
errors++;
}
else {
if(data91 < 0 || isNaN(data91)){
const err238 = {instancePath:instancePath+"/sql_capabilities/max_parameters",schemaPath:"#/oneOf/1/properties/sql_capabilities/properties/max_parameters/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err238];
}
else {
vErrors.push(err238);
}
errors++;
}
}
}
}
var valid31 = _errs224 === errors;
}
else {
var valid31 = true;
}
if(valid31){
if(data88.statement_bytes !== undefined){
let data92 = data88.statement_bytes;
const _errs226 = errors;
if(!(((typeof data92 == "number") && (!(data92 % 1) && !isNaN(data92))) && (isFinite(data92)))){
const err239 = {instancePath:instancePath+"/sql_capabilities/statement_bytes",schemaPath:"#/oneOf/1/properties/sql_capabilities/properties/statement_bytes/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err239];
}
else {
vErrors.push(err239);
}
errors++;
}
if(errors === _errs226){
if((typeof data92 == "number") && (isFinite(data92))){
if(data92 > 4294967295 || isNaN(data92)){
const err240 = {instancePath:instancePath+"/sql_capabilities/statement_bytes",schemaPath:"#/oneOf/1/properties/sql_capabilities/properties/statement_bytes/maximum",keyword:"maximum",params:{comparison: "<=", limit: 4294967295},message:"must be <= 4294967295"};
if(vErrors === null){
vErrors = [err240];
}
else {
vErrors.push(err240);
}
errors++;
}
else {
if(data92 < 0 || isNaN(data92)){
const err241 = {instancePath:instancePath+"/sql_capabilities/statement_bytes",schemaPath:"#/oneOf/1/properties/sql_capabilities/properties/statement_bytes/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err241];
}
else {
vErrors.push(err241);
}
errors++;
}
}
}
}
var valid31 = _errs226 === errors;
}
else {
var valid31 = true;
}
}
}
}
}
}
}
else {
const err242 = {instancePath:instancePath+"/sql_capabilities",schemaPath:"#/oneOf/1/properties/sql_capabilities/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err242];
}
else {
vErrors.push(err242);
}
errors++;
}
}
}
}
}
}
else {
const err243 = {instancePath,schemaPath:"#/oneOf/1/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err243];
}
else {
vErrors.push(err243);
}
errors++;
}
}
var _valid0 = _errs214 === errors;
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
const _errs228 = errors;
if(errors === _errs228){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing23;
if((data.suggestions === undefined) && (missing23 = "suggestions")){
const err244 = {instancePath,schemaPath:"#/oneOf/2/required",keyword:"required",params:{missingProperty: missing23},message:"must have required property '"+missing23+"'"};
if(vErrors === null){
vErrors = [err244];
}
else {
vErrors.push(err244);
}
errors++;
}
else {
const _errs230 = errors;
for(const key23 in data){
if(!(key23 === "suggestions")){
const err245 = {instancePath,schemaPath:"#/oneOf/2/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key23},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err245];
}
else {
vErrors.push(err245);
}
errors++;
break;
}
}
if(_errs230 === errors){
if(data.suggestions !== undefined){
let data93 = data.suggestions;
const _errs231 = errors;
if(errors === _errs231){
if(data93 && typeof data93 == "object" && !Array.isArray(data93)){
let missing24;
if((((data93.resource === undefined) && (missing24 = "resource")) || ((data93.contract === undefined) && (missing24 = "contract"))) || ((data93.items === undefined) && (missing24 = "items"))){
const err246 = {instancePath:instancePath+"/suggestions",schemaPath:"#/oneOf/2/properties/suggestions/required",keyword:"required",params:{missingProperty: missing24},message:"must have required property '"+missing24+"'"};
if(vErrors === null){
vErrors = [err246];
}
else {
vErrors.push(err246);
}
errors++;
}
else {
const _errs233 = errors;
for(const key24 in data93){
if(!(((key24 === "resource") || (key24 === "contract")) || (key24 === "items"))){
const err247 = {instancePath:instancePath+"/suggestions",schemaPath:"#/oneOf/2/properties/suggestions/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key24},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err247];
}
else {
vErrors.push(err247);
}
errors++;
break;
}
}
if(_errs233 === errors){
if(data93.resource !== undefined){
let data94 = data93.resource;
const _errs234 = errors;
if(!(((typeof data94 == "number") && (!(data94 % 1) && !isNaN(data94))) && (isFinite(data94)))){
const err248 = {instancePath:instancePath+"/suggestions/resource",schemaPath:"#/oneOf/2/properties/suggestions/properties/resource/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err248];
}
else {
vErrors.push(err248);
}
errors++;
}
if(errors === _errs234){
if((typeof data94 == "number") && (isFinite(data94))){
if(data94 > 9007199254740991 || isNaN(data94)){
const err249 = {instancePath:instancePath+"/suggestions/resource",schemaPath:"#/oneOf/2/properties/suggestions/properties/resource/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"};
if(vErrors === null){
vErrors = [err249];
}
else {
vErrors.push(err249);
}
errors++;
}
else {
if(data94 < 0 || isNaN(data94)){
const err250 = {instancePath:instancePath+"/suggestions/resource",schemaPath:"#/oneOf/2/properties/suggestions/properties/resource/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err250];
}
else {
vErrors.push(err250);
}
errors++;
}
}
}
}
var valid33 = _errs234 === errors;
}
else {
var valid33 = true;
}
if(valid33){
if(data93.contract !== undefined){
let data95 = data93.contract;
const _errs236 = errors;
if(errors === _errs236){
if(Array.isArray(data95)){
if(data95.length > 32){
const err251 = {instancePath:instancePath+"/suggestions/contract",schemaPath:"#/oneOf/2/properties/suggestions/properties/contract/maxItems",keyword:"maxItems",params:{limit: 32},message:"must NOT have more than 32 items"};
if(vErrors === null){
vErrors = [err251];
}
else {
vErrors.push(err251);
}
errors++;
}
else {
if(data95.length < 32){
const err252 = {instancePath:instancePath+"/suggestions/contract",schemaPath:"#/oneOf/2/properties/suggestions/properties/contract/minItems",keyword:"minItems",params:{limit: 32},message:"must NOT have fewer than 32 items"};
if(vErrors === null){
vErrors = [err252];
}
else {
vErrors.push(err252);
}
errors++;
}
else {
var valid34 = true;
const len5 = data95.length;
for(let i5=0; i5<len5; i5++){
let data96 = data95[i5];
const _errs238 = errors;
if(!(((typeof data96 == "number") && (!(data96 % 1) && !isNaN(data96))) && (isFinite(data96)))){
const err253 = {instancePath:instancePath+"/suggestions/contract/" + i5,schemaPath:"#/oneOf/2/properties/suggestions/properties/contract/items/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err253];
}
else {
vErrors.push(err253);
}
errors++;
}
if(errors === _errs238){
if((typeof data96 == "number") && (isFinite(data96))){
if(data96 > 255 || isNaN(data96)){
const err254 = {instancePath:instancePath+"/suggestions/contract/" + i5,schemaPath:"#/oneOf/2/properties/suggestions/properties/contract/items/maximum",keyword:"maximum",params:{comparison: "<=", limit: 255},message:"must be <= 255"};
if(vErrors === null){
vErrors = [err254];
}
else {
vErrors.push(err254);
}
errors++;
}
else {
if(data96 < 0 || isNaN(data96)){
const err255 = {instancePath:instancePath+"/suggestions/contract/" + i5,schemaPath:"#/oneOf/2/properties/suggestions/properties/contract/items/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err255];
}
else {
vErrors.push(err255);
}
errors++;
}
}
}
}
var valid34 = _errs238 === errors;
if(!valid34){
break;
}
}
}
}
}
else {
const err256 = {instancePath:instancePath+"/suggestions/contract",schemaPath:"#/oneOf/2/properties/suggestions/properties/contract/type",keyword:"type",params:{type: "array"},message:"must be array"};
if(vErrors === null){
vErrors = [err256];
}
else {
vErrors.push(err256);
}
errors++;
}
}
var valid33 = _errs236 === errors;
}
else {
var valid33 = true;
}
if(valid33){
if(data93.items !== undefined){
let data97 = data93.items;
const _errs240 = errors;
if(errors === _errs240){
if(Array.isArray(data97)){
if(data97.length > 8){
const err257 = {instancePath:instancePath+"/suggestions/items",schemaPath:"#/oneOf/2/properties/suggestions/properties/items/maxItems",keyword:"maxItems",params:{limit: 8},message:"must NOT have more than 8 items"};
if(vErrors === null){
vErrors = [err257];
}
else {
vErrors.push(err257);
}
errors++;
}
else {
var valid35 = true;
const len6 = data97.length;
for(let i6=0; i6<len6; i6++){
let data98 = data97[i6];
const _errs242 = errors;
if(errors === _errs242){
if(data98 && typeof data98 == "object" && !Array.isArray(data98)){
let missing25;
if(((data98.label === undefined) && (missing25 = "label")) || ((data98.sql === undefined) && (missing25 = "sql"))){
const err258 = {instancePath:instancePath+"/suggestions/items/" + i6,schemaPath:"#/oneOf/2/properties/suggestions/properties/items/items/required",keyword:"required",params:{missingProperty: missing25},message:"must have required property '"+missing25+"'"};
if(vErrors === null){
vErrors = [err258];
}
else {
vErrors.push(err258);
}
errors++;
}
else {
const _errs244 = errors;
for(const key25 in data98){
if(!((key25 === "label") || (key25 === "sql"))){
const err259 = {instancePath:instancePath+"/suggestions/items/" + i6,schemaPath:"#/oneOf/2/properties/suggestions/properties/items/items/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key25},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err259];
}
else {
vErrors.push(err259);
}
errors++;
break;
}
}
if(_errs244 === errors){
if(data98.label !== undefined){
let data99 = data98.label;
const _errs245 = errors;
if(errors === _errs245){
if(typeof data99 === "string"){
if(func1(data99) > 131072){
const err260 = {instancePath:instancePath+"/suggestions/items/" + i6+"/label",schemaPath:"#/oneOf/2/properties/suggestions/properties/items/items/properties/label/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err260];
}
else {
vErrors.push(err260);
}
errors++;
}
}
else {
const err261 = {instancePath:instancePath+"/suggestions/items/" + i6+"/label",schemaPath:"#/oneOf/2/properties/suggestions/properties/items/items/properties/label/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err261];
}
else {
vErrors.push(err261);
}
errors++;
}
}
var valid36 = _errs245 === errors;
}
else {
var valid36 = true;
}
if(valid36){
if(data98.sql !== undefined){
let data100 = data98.sql;
const _errs247 = errors;
if(errors === _errs247){
if(typeof data100 === "string"){
if(func1(data100) > 131072){
const err262 = {instancePath:instancePath+"/suggestions/items/" + i6+"/sql",schemaPath:"#/oneOf/2/properties/suggestions/properties/items/items/properties/sql/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err262];
}
else {
vErrors.push(err262);
}
errors++;
}
}
else {
const err263 = {instancePath:instancePath+"/suggestions/items/" + i6+"/sql",schemaPath:"#/oneOf/2/properties/suggestions/properties/items/items/properties/sql/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err263];
}
else {
vErrors.push(err263);
}
errors++;
}
}
var valid36 = _errs247 === errors;
}
else {
var valid36 = true;
}
}
}
}
}
else {
const err264 = {instancePath:instancePath+"/suggestions/items/" + i6,schemaPath:"#/oneOf/2/properties/suggestions/properties/items/items/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err264];
}
else {
vErrors.push(err264);
}
errors++;
}
}
var valid35 = _errs242 === errors;
if(!valid35){
break;
}
}
}
}
else {
const err265 = {instancePath:instancePath+"/suggestions/items",schemaPath:"#/oneOf/2/properties/suggestions/properties/items/type",keyword:"type",params:{type: "array"},message:"must be array"};
if(vErrors === null){
vErrors = [err265];
}
else {
vErrors.push(err265);
}
errors++;
}
}
var valid33 = _errs240 === errors;
}
else {
var valid33 = true;
}
}
}
}
}
}
else {
const err266 = {instancePath:instancePath+"/suggestions",schemaPath:"#/oneOf/2/properties/suggestions/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err266];
}
else {
vErrors.push(err266);
}
errors++;
}
}
}
}
}
}
else {
const err267 = {instancePath,schemaPath:"#/oneOf/2/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err267];
}
else {
vErrors.push(err267);
}
errors++;
}
}
var _valid0 = _errs228 === errors;
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
const _errs249 = errors;
if(errors === _errs249){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing26;
if((data.assistance === undefined) && (missing26 = "assistance")){
const err268 = {instancePath,schemaPath:"#/oneOf/3/required",keyword:"required",params:{missingProperty: missing26},message:"must have required property '"+missing26+"'"};
if(vErrors === null){
vErrors = [err268];
}
else {
vErrors.push(err268);
}
errors++;
}
else {
const _errs251 = errors;
for(const key26 in data){
if(!(key26 === "assistance")){
const err269 = {instancePath,schemaPath:"#/oneOf/3/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key26},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err269];
}
else {
vErrors.push(err269);
}
errors++;
break;
}
}
if(_errs251 === errors){
if(data.assistance !== undefined){
let data101 = data.assistance;
const _errs252 = errors;
if(errors === _errs252){
if(data101 && typeof data101 == "object" && !Array.isArray(data101)){
let missing27;
if((((((((((data101.version === undefined) && (missing27 = "version")) || ((data101.generation === undefined) && (missing27 = "generation"))) || ((data101.profile === undefined) && (missing27 = "profile"))) || ((data101.resource === undefined) && (missing27 = "resource"))) || ((data101.contract === undefined) && (missing27 = "contract"))) || ((data101.resource_revision === undefined) && (missing27 = "resource_revision"))) || ((data101.policy_revision === undefined) && (missing27 = "policy_revision"))) || ((data101.range === undefined) && (missing27 = "range"))) || ((data101.items === undefined) && (missing27 = "items"))){
const err270 = {instancePath:instancePath+"/assistance",schemaPath:"#/oneOf/3/properties/assistance/required",keyword:"required",params:{missingProperty: missing27},message:"must have required property '"+missing27+"'"};
if(vErrors === null){
vErrors = [err270];
}
else {
vErrors.push(err270);
}
errors++;
}
else {
const _errs254 = errors;
for(const key27 in data101){
if(!(func24.call(schema33.oneOf[3].properties.assistance.properties, key27))){
const err271 = {instancePath:instancePath+"/assistance",schemaPath:"#/oneOf/3/properties/assistance/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key27},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err271];
}
else {
vErrors.push(err271);
}
errors++;
break;
}
}
if(_errs254 === errors){
if(data101.version !== undefined){
let data102 = data101.version;
const _errs255 = errors;
if(!(((typeof data102 == "number") && (!(data102 % 1) && !isNaN(data102))) && (isFinite(data102)))){
const err272 = {instancePath:instancePath+"/assistance/version",schemaPath:"#/oneOf/3/properties/assistance/properties/version/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err272];
}
else {
vErrors.push(err272);
}
errors++;
}
if(errors === _errs255){
if((typeof data102 == "number") && (isFinite(data102))){
if(data102 > 255 || isNaN(data102)){
const err273 = {instancePath:instancePath+"/assistance/version",schemaPath:"#/oneOf/3/properties/assistance/properties/version/maximum",keyword:"maximum",params:{comparison: "<=", limit: 255},message:"must be <= 255"};
if(vErrors === null){
vErrors = [err273];
}
else {
vErrors.push(err273);
}
errors++;
}
else {
if(data102 < 0 || isNaN(data102)){
const err274 = {instancePath:instancePath+"/assistance/version",schemaPath:"#/oneOf/3/properties/assistance/properties/version/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err274];
}
else {
vErrors.push(err274);
}
errors++;
}
}
}
}
var valid38 = _errs255 === errors;
}
else {
var valid38 = true;
}
if(valid38){
if(data101.generation !== undefined){
let data103 = data101.generation;
const _errs257 = errors;
if(!(((typeof data103 == "number") && (!(data103 % 1) && !isNaN(data103))) && (isFinite(data103)))){
const err275 = {instancePath:instancePath+"/assistance/generation",schemaPath:"#/oneOf/3/properties/assistance/properties/generation/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err275];
}
else {
vErrors.push(err275);
}
errors++;
}
if(errors === _errs257){
if((typeof data103 == "number") && (isFinite(data103))){
if(data103 > 4294967295 || isNaN(data103)){
const err276 = {instancePath:instancePath+"/assistance/generation",schemaPath:"#/oneOf/3/properties/assistance/properties/generation/maximum",keyword:"maximum",params:{comparison: "<=", limit: 4294967295},message:"must be <= 4294967295"};
if(vErrors === null){
vErrors = [err276];
}
else {
vErrors.push(err276);
}
errors++;
}
else {
if(data103 < 0 || isNaN(data103)){
const err277 = {instancePath:instancePath+"/assistance/generation",schemaPath:"#/oneOf/3/properties/assistance/properties/generation/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
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
var valid38 = _errs257 === errors;
}
else {
var valid38 = true;
}
if(valid38){
if(data101.profile !== undefined){
let data104 = data101.profile;
const _errs259 = errors;
if(typeof data104 !== "string"){
const err278 = {instancePath:instancePath+"/assistance/profile",schemaPath:"#/oneOf/3/properties/assistance/properties/profile/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err278];
}
else {
vErrors.push(err278);
}
errors++;
}
if(!(data104 === "unified_v1")){
const err279 = {instancePath:instancePath+"/assistance/profile",schemaPath:"#/oneOf/3/properties/assistance/properties/profile/enum",keyword:"enum",params:{allowedValues: schema33.oneOf[3].properties.assistance.properties.profile.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err279];
}
else {
vErrors.push(err279);
}
errors++;
}
var valid38 = _errs259 === errors;
}
else {
var valid38 = true;
}
if(valid38){
if(data101.resource !== undefined){
let data105 = data101.resource;
const _errs261 = errors;
if(!(((typeof data105 == "number") && (!(data105 % 1) && !isNaN(data105))) && (isFinite(data105)))){
const err280 = {instancePath:instancePath+"/assistance/resource",schemaPath:"#/oneOf/3/properties/assistance/properties/resource/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err280];
}
else {
vErrors.push(err280);
}
errors++;
}
if(errors === _errs261){
if((typeof data105 == "number") && (isFinite(data105))){
if(data105 > 9007199254740991 || isNaN(data105)){
const err281 = {instancePath:instancePath+"/assistance/resource",schemaPath:"#/oneOf/3/properties/assistance/properties/resource/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"};
if(vErrors === null){
vErrors = [err281];
}
else {
vErrors.push(err281);
}
errors++;
}
else {
if(data105 < 0 || isNaN(data105)){
const err282 = {instancePath:instancePath+"/assistance/resource",schemaPath:"#/oneOf/3/properties/assistance/properties/resource/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err282];
}
else {
vErrors.push(err282);
}
errors++;
}
}
}
}
var valid38 = _errs261 === errors;
}
else {
var valid38 = true;
}
if(valid38){
if(data101.contract !== undefined){
let data106 = data101.contract;
const _errs263 = errors;
if(errors === _errs263){
if(Array.isArray(data106)){
if(data106.length > 32){
const err283 = {instancePath:instancePath+"/assistance/contract",schemaPath:"#/oneOf/3/properties/assistance/properties/contract/maxItems",keyword:"maxItems",params:{limit: 32},message:"must NOT have more than 32 items"};
if(vErrors === null){
vErrors = [err283];
}
else {
vErrors.push(err283);
}
errors++;
}
else {
if(data106.length < 32){
const err284 = {instancePath:instancePath+"/assistance/contract",schemaPath:"#/oneOf/3/properties/assistance/properties/contract/minItems",keyword:"minItems",params:{limit: 32},message:"must NOT have fewer than 32 items"};
if(vErrors === null){
vErrors = [err284];
}
else {
vErrors.push(err284);
}
errors++;
}
else {
var valid39 = true;
const len7 = data106.length;
for(let i7=0; i7<len7; i7++){
let data107 = data106[i7];
const _errs265 = errors;
if(!(((typeof data107 == "number") && (!(data107 % 1) && !isNaN(data107))) && (isFinite(data107)))){
const err285 = {instancePath:instancePath+"/assistance/contract/" + i7,schemaPath:"#/oneOf/3/properties/assistance/properties/contract/items/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err285];
}
else {
vErrors.push(err285);
}
errors++;
}
if(errors === _errs265){
if((typeof data107 == "number") && (isFinite(data107))){
if(data107 > 255 || isNaN(data107)){
const err286 = {instancePath:instancePath+"/assistance/contract/" + i7,schemaPath:"#/oneOf/3/properties/assistance/properties/contract/items/maximum",keyword:"maximum",params:{comparison: "<=", limit: 255},message:"must be <= 255"};
if(vErrors === null){
vErrors = [err286];
}
else {
vErrors.push(err286);
}
errors++;
}
else {
if(data107 < 0 || isNaN(data107)){
const err287 = {instancePath:instancePath+"/assistance/contract/" + i7,schemaPath:"#/oneOf/3/properties/assistance/properties/contract/items/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err287];
}
else {
vErrors.push(err287);
}
errors++;
}
}
}
}
var valid39 = _errs265 === errors;
if(!valid39){
break;
}
}
}
}
}
else {
const err288 = {instancePath:instancePath+"/assistance/contract",schemaPath:"#/oneOf/3/properties/assistance/properties/contract/type",keyword:"type",params:{type: "array"},message:"must be array"};
if(vErrors === null){
vErrors = [err288];
}
else {
vErrors.push(err288);
}
errors++;
}
}
var valid38 = _errs263 === errors;
}
else {
var valid38 = true;
}
if(valid38){
if(data101.resource_revision !== undefined){
let data108 = data101.resource_revision;
const _errs267 = errors;
if(!(((typeof data108 == "number") && (!(data108 % 1) && !isNaN(data108))) && (isFinite(data108)))){
const err289 = {instancePath:instancePath+"/assistance/resource_revision",schemaPath:"#/oneOf/3/properties/assistance/properties/resource_revision/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err289];
}
else {
vErrors.push(err289);
}
errors++;
}
if(errors === _errs267){
if((typeof data108 == "number") && (isFinite(data108))){
if(data108 > 9007199254740991 || isNaN(data108)){
const err290 = {instancePath:instancePath+"/assistance/resource_revision",schemaPath:"#/oneOf/3/properties/assistance/properties/resource_revision/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"};
if(vErrors === null){
vErrors = [err290];
}
else {
vErrors.push(err290);
}
errors++;
}
else {
if(data108 < 0 || isNaN(data108)){
const err291 = {instancePath:instancePath+"/assistance/resource_revision",schemaPath:"#/oneOf/3/properties/assistance/properties/resource_revision/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err291];
}
else {
vErrors.push(err291);
}
errors++;
}
}
}
}
var valid38 = _errs267 === errors;
}
else {
var valid38 = true;
}
if(valid38){
if(data101.policy_revision !== undefined){
let data109 = data101.policy_revision;
const _errs269 = errors;
if(errors === _errs269){
if(typeof data109 === "string"){
if(func1(data109) > 131072){
const err292 = {instancePath:instancePath+"/assistance/policy_revision",schemaPath:"#/oneOf/3/properties/assistance/properties/policy_revision/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err292];
}
else {
vErrors.push(err292);
}
errors++;
}
}
else {
const err293 = {instancePath:instancePath+"/assistance/policy_revision",schemaPath:"#/oneOf/3/properties/assistance/properties/policy_revision/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err293];
}
else {
vErrors.push(err293);
}
errors++;
}
}
var valid38 = _errs269 === errors;
}
else {
var valid38 = true;
}
if(valid38){
if(data101.range !== undefined){
let data110 = data101.range;
const _errs271 = errors;
const _errs272 = errors;
let valid40 = false;
const _errs273 = errors;
if(errors === _errs273){
if(data110 && typeof data110 == "object" && !Array.isArray(data110)){
let missing28;
if((((data110.start === undefined) && (missing28 = "start")) || ((data110.end === undefined) && (missing28 = "end"))) || ((data110.quoted === undefined) && (missing28 = "quoted"))){
const err294 = {instancePath:instancePath+"/assistance/range",schemaPath:"#/oneOf/3/properties/assistance/properties/range/anyOf/0/required",keyword:"required",params:{missingProperty: missing28},message:"must have required property '"+missing28+"'"};
if(vErrors === null){
vErrors = [err294];
}
else {
vErrors.push(err294);
}
errors++;
}
else {
const _errs275 = errors;
for(const key28 in data110){
if(!(((key28 === "start") || (key28 === "end")) || (key28 === "quoted"))){
const err295 = {instancePath:instancePath+"/assistance/range",schemaPath:"#/oneOf/3/properties/assistance/properties/range/anyOf/0/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key28},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err295];
}
else {
vErrors.push(err295);
}
errors++;
break;
}
}
if(_errs275 === errors){
if(data110.start !== undefined){
let data111 = data110.start;
const _errs276 = errors;
if(!(((typeof data111 == "number") && (!(data111 % 1) && !isNaN(data111))) && (isFinite(data111)))){
const err296 = {instancePath:instancePath+"/assistance/range/start",schemaPath:"#/oneOf/3/properties/assistance/properties/range/anyOf/0/properties/start/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err296];
}
else {
vErrors.push(err296);
}
errors++;
}
if(errors === _errs276){
if((typeof data111 == "number") && (isFinite(data111))){
if(data111 > 65535 || isNaN(data111)){
const err297 = {instancePath:instancePath+"/assistance/range/start",schemaPath:"#/oneOf/3/properties/assistance/properties/range/anyOf/0/properties/start/maximum",keyword:"maximum",params:{comparison: "<=", limit: 65535},message:"must be <= 65535"};
if(vErrors === null){
vErrors = [err297];
}
else {
vErrors.push(err297);
}
errors++;
}
else {
if(data111 < 0 || isNaN(data111)){
const err298 = {instancePath:instancePath+"/assistance/range/start",schemaPath:"#/oneOf/3/properties/assistance/properties/range/anyOf/0/properties/start/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err298];
}
else {
vErrors.push(err298);
}
errors++;
}
}
}
}
var valid41 = _errs276 === errors;
}
else {
var valid41 = true;
}
if(valid41){
if(data110.end !== undefined){
let data112 = data110.end;
const _errs278 = errors;
if(!(((typeof data112 == "number") && (!(data112 % 1) && !isNaN(data112))) && (isFinite(data112)))){
const err299 = {instancePath:instancePath+"/assistance/range/end",schemaPath:"#/oneOf/3/properties/assistance/properties/range/anyOf/0/properties/end/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err299];
}
else {
vErrors.push(err299);
}
errors++;
}
if(errors === _errs278){
if((typeof data112 == "number") && (isFinite(data112))){
if(data112 > 65535 || isNaN(data112)){
const err300 = {instancePath:instancePath+"/assistance/range/end",schemaPath:"#/oneOf/3/properties/assistance/properties/range/anyOf/0/properties/end/maximum",keyword:"maximum",params:{comparison: "<=", limit: 65535},message:"must be <= 65535"};
if(vErrors === null){
vErrors = [err300];
}
else {
vErrors.push(err300);
}
errors++;
}
else {
if(data112 < 0 || isNaN(data112)){
const err301 = {instancePath:instancePath+"/assistance/range/end",schemaPath:"#/oneOf/3/properties/assistance/properties/range/anyOf/0/properties/end/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err301];
}
else {
vErrors.push(err301);
}
errors++;
}
}
}
}
var valid41 = _errs278 === errors;
}
else {
var valid41 = true;
}
if(valid41){
if(data110.quoted !== undefined){
const _errs280 = errors;
if(typeof data110.quoted !== "boolean"){
const err302 = {instancePath:instancePath+"/assistance/range/quoted",schemaPath:"#/oneOf/3/properties/assistance/properties/range/anyOf/0/properties/quoted/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"};
if(vErrors === null){
vErrors = [err302];
}
else {
vErrors.push(err302);
}
errors++;
}
var valid41 = _errs280 === errors;
}
else {
var valid41 = true;
}
}
}
}
}
}
else {
const err303 = {instancePath:instancePath+"/assistance/range",schemaPath:"#/oneOf/3/properties/assistance/properties/range/anyOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err303];
}
else {
vErrors.push(err303);
}
errors++;
}
}
var _valid4 = _errs273 === errors;
valid40 = valid40 || _valid4;
const _errs282 = errors;
if(data110 !== null){
const err304 = {instancePath:instancePath+"/assistance/range",schemaPath:"#/oneOf/3/properties/assistance/properties/range/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err304];
}
else {
vErrors.push(err304);
}
errors++;
}
var _valid4 = _errs282 === errors;
valid40 = valid40 || _valid4;
if(!valid40){
const err305 = {instancePath:instancePath+"/assistance/range",schemaPath:"#/oneOf/3/properties/assistance/properties/range/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err305];
}
else {
vErrors.push(err305);
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
var valid38 = _errs271 === errors;
}
else {
var valid38 = true;
}
if(valid38){
if(data101.items !== undefined){
let data114 = data101.items;
const _errs284 = errors;
if(errors === _errs284){
if(Array.isArray(data114)){
if(data114.length > 8){
const err306 = {instancePath:instancePath+"/assistance/items",schemaPath:"#/oneOf/3/properties/assistance/properties/items/maxItems",keyword:"maxItems",params:{limit: 8},message:"must NOT have more than 8 items"};
if(vErrors === null){
vErrors = [err306];
}
else {
vErrors.push(err306);
}
errors++;
}
else {
var valid42 = true;
const len8 = data114.length;
for(let i8=0; i8<len8; i8++){
let data115 = data114[i8];
const _errs286 = errors;
if(errors === _errs286){
if(data115 && typeof data115 == "object" && !Array.isArray(data115)){
let missing29;
if((((data115.text === undefined) && (missing29 = "text")) || ((data115.kind === undefined) && (missing29 = "kind"))) || ((data115.detail === undefined) && (missing29 = "detail"))){
const err307 = {instancePath:instancePath+"/assistance/items/" + i8,schemaPath:"#/oneOf/3/properties/assistance/properties/items/items/required",keyword:"required",params:{missingProperty: missing29},message:"must have required property '"+missing29+"'"};
if(vErrors === null){
vErrors = [err307];
}
else {
vErrors.push(err307);
}
errors++;
}
else {
const _errs288 = errors;
for(const key29 in data115){
if(!(((key29 === "text") || (key29 === "kind")) || (key29 === "detail"))){
const err308 = {instancePath:instancePath+"/assistance/items/" + i8,schemaPath:"#/oneOf/3/properties/assistance/properties/items/items/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key29},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err308];
}
else {
vErrors.push(err308);
}
errors++;
break;
}
}
if(_errs288 === errors){
if(data115.text !== undefined){
let data116 = data115.text;
const _errs289 = errors;
if(errors === _errs289){
if(typeof data116 === "string"){
if(func1(data116) > 131072){
const err309 = {instancePath:instancePath+"/assistance/items/" + i8+"/text",schemaPath:"#/oneOf/3/properties/assistance/properties/items/items/properties/text/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err309];
}
else {
vErrors.push(err309);
}
errors++;
}
}
else {
const err310 = {instancePath:instancePath+"/assistance/items/" + i8+"/text",schemaPath:"#/oneOf/3/properties/assistance/properties/items/items/properties/text/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err310];
}
else {
vErrors.push(err310);
}
errors++;
}
}
var valid43 = _errs289 === errors;
}
else {
var valid43 = true;
}
if(valid43){
if(data115.kind !== undefined){
let data117 = data115.kind;
const _errs291 = errors;
if(typeof data117 !== "string"){
const err311 = {instancePath:instancePath+"/assistance/items/" + i8+"/kind",schemaPath:"#/oneOf/3/properties/assistance/properties/items/items/properties/kind/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err311];
}
else {
vErrors.push(err311);
}
errors++;
}
if(!((((((data117 === "keyword") || (data117 === "source")) || (data117 === "column")) || (data117 === "symbol")) || (data117 === "literal")) || (data117 === "meta"))){
const err312 = {instancePath:instancePath+"/assistance/items/" + i8+"/kind",schemaPath:"#/oneOf/3/properties/assistance/properties/items/items/properties/kind/enum",keyword:"enum",params:{allowedValues: schema33.oneOf[3].properties.assistance.properties.items.items.properties.kind.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err312];
}
else {
vErrors.push(err312);
}
errors++;
}
var valid43 = _errs291 === errors;
}
else {
var valid43 = true;
}
if(valid43){
if(data115.detail !== undefined){
let data118 = data115.detail;
const _errs293 = errors;
if(errors === _errs293){
if(typeof data118 === "string"){
if(func1(data118) > 131072){
const err313 = {instancePath:instancePath+"/assistance/items/" + i8+"/detail",schemaPath:"#/oneOf/3/properties/assistance/properties/items/items/properties/detail/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err313];
}
else {
vErrors.push(err313);
}
errors++;
}
}
else {
const err314 = {instancePath:instancePath+"/assistance/items/" + i8+"/detail",schemaPath:"#/oneOf/3/properties/assistance/properties/items/items/properties/detail/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err314];
}
else {
vErrors.push(err314);
}
errors++;
}
}
var valid43 = _errs293 === errors;
}
else {
var valid43 = true;
}
}
}
}
}
}
else {
const err315 = {instancePath:instancePath+"/assistance/items/" + i8,schemaPath:"#/oneOf/3/properties/assistance/properties/items/items/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err315];
}
else {
vErrors.push(err315);
}
errors++;
}
}
var valid42 = _errs286 === errors;
if(!valid42){
break;
}
}
}
}
else {
const err316 = {instancePath:instancePath+"/assistance/items",schemaPath:"#/oneOf/3/properties/assistance/properties/items/type",keyword:"type",params:{type: "array"},message:"must be array"};
if(vErrors === null){
vErrors = [err316];
}
else {
vErrors.push(err316);
}
errors++;
}
}
var valid38 = _errs284 === errors;
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
}
}
else {
const err317 = {instancePath:instancePath+"/assistance",schemaPath:"#/oneOf/3/properties/assistance/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err317];
}
else {
vErrors.push(err317);
}
errors++;
}
}
}
}
}
}
else {
const err318 = {instancePath,schemaPath:"#/oneOf/3/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err318];
}
else {
vErrors.push(err318);
}
errors++;
}
}
var _valid0 = _errs249 === errors;
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
const _errs295 = errors;
if(errors === _errs295){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing30;
if((data.compiled === undefined) && (missing30 = "compiled")){
const err319 = {instancePath,schemaPath:"#/oneOf/4/required",keyword:"required",params:{missingProperty: missing30},message:"must have required property '"+missing30+"'"};
if(vErrors === null){
vErrors = [err319];
}
else {
vErrors.push(err319);
}
errors++;
}
else {
const _errs297 = errors;
for(const key30 in data){
if(!(key30 === "compiled")){
const err320 = {instancePath,schemaPath:"#/oneOf/4/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key30},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err320];
}
else {
vErrors.push(err320);
}
errors++;
break;
}
}
if(_errs297 === errors){
if(data.compiled !== undefined){
let data119 = data.compiled;
const _errs298 = errors;
if(errors === _errs298){
if(data119 && typeof data119 == "object" && !Array.isArray(data119)){
let missing31;
if(((((((data119.bundle === undefined) && (missing31 = "bundle")) || ((data119.source === undefined) && (missing31 = "source"))) || ((data119.plan === undefined) && (missing31 = "plan"))) || ((data119.limits === undefined) && (missing31 = "limits"))) || ((data119.contract === undefined) && (missing31 = "contract"))) || ((data119.schema === undefined) && (missing31 = "schema"))){
const err321 = {instancePath:instancePath+"/compiled",schemaPath:"#/oneOf/4/properties/compiled/required",keyword:"required",params:{missingProperty: missing31},message:"must have required property '"+missing31+"'"};
if(vErrors === null){
vErrors = [err321];
}
else {
vErrors.push(err321);
}
errors++;
}
else {
const _errs300 = errors;
for(const key31 in data119){
if(!((((((key31 === "bundle") || (key31 === "source")) || (key31 === "plan")) || (key31 === "limits")) || (key31 === "contract")) || (key31 === "schema"))){
const err322 = {instancePath:instancePath+"/compiled",schemaPath:"#/oneOf/4/properties/compiled/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key31},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err322];
}
else {
vErrors.push(err322);
}
errors++;
break;
}
}
if(_errs300 === errors){
if(data119.bundle !== undefined){
let data120 = data119.bundle;
const _errs301 = errors;
if(errors === _errs301){
if(typeof data120 === "string"){
if(func1(data120) > 131072){
const err323 = {instancePath:instancePath+"/compiled/bundle",schemaPath:"#/oneOf/4/properties/compiled/properties/bundle/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err323];
}
else {
vErrors.push(err323);
}
errors++;
}
}
else {
const err324 = {instancePath:instancePath+"/compiled/bundle",schemaPath:"#/oneOf/4/properties/compiled/properties/bundle/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err324];
}
else {
vErrors.push(err324);
}
errors++;
}
}
var valid45 = _errs301 === errors;
}
else {
var valid45 = true;
}
if(valid45){
if(data119.source !== undefined){
let data121 = data119.source;
const _errs303 = errors;
if(errors === _errs303){
if(data121 && typeof data121 == "object" && !Array.isArray(data121)){
let missing32;
if((((data121.version === undefined) && (missing32 = "version")) || ((data121.resource === undefined) && (missing32 = "resource"))) || ((data121.source === undefined) && (missing32 = "source"))){
const err325 = {instancePath:instancePath+"/compiled/source",schemaPath:"#/oneOf/4/properties/compiled/properties/source/required",keyword:"required",params:{missingProperty: missing32},message:"must have required property '"+missing32+"'"};
if(vErrors === null){
vErrors = [err325];
}
else {
vErrors.push(err325);
}
errors++;
}
else {
const _errs305 = errors;
for(const key32 in data121){
if(!(((key32 === "version") || (key32 === "resource")) || (key32 === "source"))){
const err326 = {instancePath:instancePath+"/compiled/source",schemaPath:"#/oneOf/4/properties/compiled/properties/source/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key32},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err326];
}
else {
vErrors.push(err326);
}
errors++;
break;
}
}
if(_errs305 === errors){
if(data121.version !== undefined){
let data122 = data121.version;
const _errs306 = errors;
if(!(((typeof data122 == "number") && (!(data122 % 1) && !isNaN(data122))) && (isFinite(data122)))){
const err327 = {instancePath:instancePath+"/compiled/source/version",schemaPath:"#/oneOf/4/properties/compiled/properties/source/properties/version/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err327];
}
else {
vErrors.push(err327);
}
errors++;
}
if(errors === _errs306){
if((typeof data122 == "number") && (isFinite(data122))){
if(data122 > 255 || isNaN(data122)){
const err328 = {instancePath:instancePath+"/compiled/source/version",schemaPath:"#/oneOf/4/properties/compiled/properties/source/properties/version/maximum",keyword:"maximum",params:{comparison: "<=", limit: 255},message:"must be <= 255"};
if(vErrors === null){
vErrors = [err328];
}
else {
vErrors.push(err328);
}
errors++;
}
else {
if(data122 < 0 || isNaN(data122)){
const err329 = {instancePath:instancePath+"/compiled/source/version",schemaPath:"#/oneOf/4/properties/compiled/properties/source/properties/version/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err329];
}
else {
vErrors.push(err329);
}
errors++;
}
}
}
}
var valid46 = _errs306 === errors;
}
else {
var valid46 = true;
}
if(valid46){
if(data121.resource !== undefined){
let data123 = data121.resource;
const _errs308 = errors;
if(!(((typeof data123 == "number") && (!(data123 % 1) && !isNaN(data123))) && (isFinite(data123)))){
const err330 = {instancePath:instancePath+"/compiled/source/resource",schemaPath:"#/oneOf/4/properties/compiled/properties/source/properties/resource/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err330];
}
else {
vErrors.push(err330);
}
errors++;
}
if(errors === _errs308){
if((typeof data123 == "number") && (isFinite(data123))){
if(data123 > 9007199254740991 || isNaN(data123)){
const err331 = {instancePath:instancePath+"/compiled/source/resource",schemaPath:"#/oneOf/4/properties/compiled/properties/source/properties/resource/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"};
if(vErrors === null){
vErrors = [err331];
}
else {
vErrors.push(err331);
}
errors++;
}
else {
if(data123 < 0 || isNaN(data123)){
const err332 = {instancePath:instancePath+"/compiled/source/resource",schemaPath:"#/oneOf/4/properties/compiled/properties/source/properties/resource/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err332];
}
else {
vErrors.push(err332);
}
errors++;
}
}
}
}
var valid46 = _errs308 === errors;
}
else {
var valid46 = true;
}
if(valid46){
if(data121.source !== undefined){
let data124 = data121.source;
const _errs310 = errors;
const _errs311 = errors;
let valid47 = false;
let passing2 = null;
const _errs312 = errors;
if(errors === _errs312){
if(data124 && typeof data124 == "object" && !Array.isArray(data124)){
let missing33;
if((data124.kv === undefined) && (missing33 = "kv")){
const err333 = {instancePath:instancePath+"/compiled/source/source",schemaPath:"#/oneOf/4/properties/compiled/properties/source/properties/source/oneOf/0/required",keyword:"required",params:{missingProperty: missing33},message:"must have required property '"+missing33+"'"};
if(vErrors === null){
vErrors = [err333];
}
else {
vErrors.push(err333);
}
errors++;
}
else {
const _errs314 = errors;
for(const key33 in data124){
if(!(key33 === "kv")){
const err334 = {instancePath:instancePath+"/compiled/source/source",schemaPath:"#/oneOf/4/properties/compiled/properties/source/properties/source/oneOf/0/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key33},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err334];
}
else {
vErrors.push(err334);
}
errors++;
break;
}
}
if(_errs314 === errors){
if(data124.kv !== undefined){
let data125 = data124.kv;
const _errs315 = errors;
if(errors === _errs315){
if(data125 && typeof data125 == "object" && !Array.isArray(data125)){
let missing34;
if((((data125.prefix === undefined) && (missing34 = "prefix")) || ((data125.key === undefined) && (missing34 = "key"))) || ((data125.value === undefined) && (missing34 = "value"))){
const err335 = {instancePath:instancePath+"/compiled/source/source/kv",schemaPath:"#/oneOf/4/properties/compiled/properties/source/properties/source/oneOf/0/properties/kv/required",keyword:"required",params:{missingProperty: missing34},message:"must have required property '"+missing34+"'"};
if(vErrors === null){
vErrors = [err335];
}
else {
vErrors.push(err335);
}
errors++;
}
else {
const _errs317 = errors;
for(const key34 in data125){
if(!(((key34 === "prefix") || (key34 === "key")) || (key34 === "value"))){
const err336 = {instancePath:instancePath+"/compiled/source/source/kv",schemaPath:"#/oneOf/4/properties/compiled/properties/source/properties/source/oneOf/0/properties/kv/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key34},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err336];
}
else {
vErrors.push(err336);
}
errors++;
break;
}
}
if(_errs317 === errors){
if(data125.prefix !== undefined){
let data126 = data125.prefix;
const _errs318 = errors;
if(errors === _errs318){
if(typeof data126 === "string"){
if(func1(data126) > 131072){
const err337 = {instancePath:instancePath+"/compiled/source/source/kv/prefix",schemaPath:"#/oneOf/4/properties/compiled/properties/source/properties/source/oneOf/0/properties/kv/properties/prefix/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err337];
}
else {
vErrors.push(err337);
}
errors++;
}
}
else {
const err338 = {instancePath:instancePath+"/compiled/source/source/kv/prefix",schemaPath:"#/oneOf/4/properties/compiled/properties/source/properties/source/oneOf/0/properties/kv/properties/prefix/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err338];
}
else {
vErrors.push(err338);
}
errors++;
}
}
var valid49 = _errs318 === errors;
}
else {
var valid49 = true;
}
if(valid49){
if(data125.key !== undefined){
let data127 = data125.key;
const _errs320 = errors;
if(errors === _errs320){
if(data127 && typeof data127 == "object" && !Array.isArray(data127)){
let missing35;
if(((data127.version === undefined) && (missing35 = "version")) || ((data127.type === undefined) && (missing35 = "type"))){
const err339 = {instancePath:instancePath+"/compiled/source/source/kv/key",schemaPath:"#/oneOf/4/properties/compiled/properties/source/properties/source/oneOf/0/properties/kv/properties/key/required",keyword:"required",params:{missingProperty: missing35},message:"must have required property '"+missing35+"'"};
if(vErrors === null){
vErrors = [err339];
}
else {
vErrors.push(err339);
}
errors++;
}
else {
const _errs322 = errors;
for(const key35 in data127){
if(!((key35 === "version") || (key35 === "type"))){
const err340 = {instancePath:instancePath+"/compiled/source/source/kv/key",schemaPath:"#/oneOf/4/properties/compiled/properties/source/properties/source/oneOf/0/properties/kv/properties/key/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key35},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err340];
}
else {
vErrors.push(err340);
}
errors++;
break;
}
}
if(_errs322 === errors){
if(data127.version !== undefined){
let data128 = data127.version;
const _errs323 = errors;
if(!(((typeof data128 == "number") && (!(data128 % 1) && !isNaN(data128))) && (isFinite(data128)))){
const err341 = {instancePath:instancePath+"/compiled/source/source/kv/key/version",schemaPath:"#/oneOf/4/properties/compiled/properties/source/properties/source/oneOf/0/properties/kv/properties/key/properties/version/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err341];
}
else {
vErrors.push(err341);
}
errors++;
}
if(errors === _errs323){
if((typeof data128 == "number") && (isFinite(data128))){
if(data128 > 255 || isNaN(data128)){
const err342 = {instancePath:instancePath+"/compiled/source/source/kv/key/version",schemaPath:"#/oneOf/4/properties/compiled/properties/source/properties/source/oneOf/0/properties/kv/properties/key/properties/version/maximum",keyword:"maximum",params:{comparison: "<=", limit: 255},message:"must be <= 255"};
if(vErrors === null){
vErrors = [err342];
}
else {
vErrors.push(err342);
}
errors++;
}
else {
if(data128 < 0 || isNaN(data128)){
const err343 = {instancePath:instancePath+"/compiled/source/source/kv/key/version",schemaPath:"#/oneOf/4/properties/compiled/properties/source/properties/source/oneOf/0/properties/kv/properties/key/properties/version/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err343];
}
else {
vErrors.push(err343);
}
errors++;
}
}
}
}
var valid50 = _errs323 === errors;
}
else {
var valid50 = true;
}
if(valid50){
if(data127.type !== undefined){
let data129 = data127.type;
const _errs325 = errors;
if(typeof data129 !== "string"){
const err344 = {instancePath:instancePath+"/compiled/source/source/kv/key/type",schemaPath:"#/oneOf/4/properties/compiled/properties/source/properties/source/oneOf/0/properties/kv/properties/key/properties/type/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err344];
}
else {
vErrors.push(err344);
}
errors++;
}
if(!((((((data129 === "int64") || (data129 === "uint64")) || (data129 === "float64")) || (data129 === "boolean")) || (data129 === "utf8")) || (data129 === "binary"))){
const err345 = {instancePath:instancePath+"/compiled/source/source/kv/key/type",schemaPath:"#/oneOf/4/properties/compiled/properties/source/properties/source/oneOf/0/properties/kv/properties/key/properties/type/enum",keyword:"enum",params:{allowedValues: schema33.oneOf[4].properties.compiled.properties.source.properties.source.oneOf[0].properties.kv.properties.key.properties.type.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err345];
}
else {
vErrors.push(err345);
}
errors++;
}
var valid50 = _errs325 === errors;
}
else {
var valid50 = true;
}
}
}
}
}
else {
const err346 = {instancePath:instancePath+"/compiled/source/source/kv/key",schemaPath:"#/oneOf/4/properties/compiled/properties/source/properties/source/oneOf/0/properties/kv/properties/key/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err346];
}
else {
vErrors.push(err346);
}
errors++;
}
}
var valid49 = _errs320 === errors;
}
else {
var valid49 = true;
}
if(valid49){
if(data125.value !== undefined){
let data130 = data125.value;
const _errs327 = errors;
if(errors === _errs327){
if(data130 && typeof data130 == "object" && !Array.isArray(data130)){
let missing36;
if(((data130.version === undefined) && (missing36 = "version")) || ((data130.type === undefined) && (missing36 = "type"))){
const err347 = {instancePath:instancePath+"/compiled/source/source/kv/value",schemaPath:"#/oneOf/4/properties/compiled/properties/source/properties/source/oneOf/0/properties/kv/properties/value/required",keyword:"required",params:{missingProperty: missing36},message:"must have required property '"+missing36+"'"};
if(vErrors === null){
vErrors = [err347];
}
else {
vErrors.push(err347);
}
errors++;
}
else {
const _errs329 = errors;
for(const key36 in data130){
if(!((key36 === "version") || (key36 === "type"))){
const err348 = {instancePath:instancePath+"/compiled/source/source/kv/value",schemaPath:"#/oneOf/4/properties/compiled/properties/source/properties/source/oneOf/0/properties/kv/properties/value/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key36},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err348];
}
else {
vErrors.push(err348);
}
errors++;
break;
}
}
if(_errs329 === errors){
if(data130.version !== undefined){
let data131 = data130.version;
const _errs330 = errors;
if(!(((typeof data131 == "number") && (!(data131 % 1) && !isNaN(data131))) && (isFinite(data131)))){
const err349 = {instancePath:instancePath+"/compiled/source/source/kv/value/version",schemaPath:"#/oneOf/4/properties/compiled/properties/source/properties/source/oneOf/0/properties/kv/properties/value/properties/version/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err349];
}
else {
vErrors.push(err349);
}
errors++;
}
if(errors === _errs330){
if((typeof data131 == "number") && (isFinite(data131))){
if(data131 > 255 || isNaN(data131)){
const err350 = {instancePath:instancePath+"/compiled/source/source/kv/value/version",schemaPath:"#/oneOf/4/properties/compiled/properties/source/properties/source/oneOf/0/properties/kv/properties/value/properties/version/maximum",keyword:"maximum",params:{comparison: "<=", limit: 255},message:"must be <= 255"};
if(vErrors === null){
vErrors = [err350];
}
else {
vErrors.push(err350);
}
errors++;
}
else {
if(data131 < 0 || isNaN(data131)){
const err351 = {instancePath:instancePath+"/compiled/source/source/kv/value/version",schemaPath:"#/oneOf/4/properties/compiled/properties/source/properties/source/oneOf/0/properties/kv/properties/value/properties/version/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err351];
}
else {
vErrors.push(err351);
}
errors++;
}
}
}
}
var valid51 = _errs330 === errors;
}
else {
var valid51 = true;
}
if(valid51){
if(data130.type !== undefined){
let data132 = data130.type;
const _errs332 = errors;
if(typeof data132 !== "string"){
const err352 = {instancePath:instancePath+"/compiled/source/source/kv/value/type",schemaPath:"#/oneOf/4/properties/compiled/properties/source/properties/source/oneOf/0/properties/kv/properties/value/properties/type/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err352];
}
else {
vErrors.push(err352);
}
errors++;
}
if(!((((((data132 === "int64") || (data132 === "uint64")) || (data132 === "float64")) || (data132 === "boolean")) || (data132 === "utf8")) || (data132 === "binary"))){
const err353 = {instancePath:instancePath+"/compiled/source/source/kv/value/type",schemaPath:"#/oneOf/4/properties/compiled/properties/source/properties/source/oneOf/0/properties/kv/properties/value/properties/type/enum",keyword:"enum",params:{allowedValues: schema33.oneOf[4].properties.compiled.properties.source.properties.source.oneOf[0].properties.kv.properties.value.properties.type.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err353];
}
else {
vErrors.push(err353);
}
errors++;
}
var valid51 = _errs332 === errors;
}
else {
var valid51 = true;
}
}
}
}
}
else {
const err354 = {instancePath:instancePath+"/compiled/source/source/kv/value",schemaPath:"#/oneOf/4/properties/compiled/properties/source/properties/source/oneOf/0/properties/kv/properties/value/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err354];
}
else {
vErrors.push(err354);
}
errors++;
}
}
var valid49 = _errs327 === errors;
}
else {
var valid49 = true;
}
}
}
}
}
}
else {
const err355 = {instancePath:instancePath+"/compiled/source/source/kv",schemaPath:"#/oneOf/4/properties/compiled/properties/source/properties/source/oneOf/0/properties/kv/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err355];
}
else {
vErrors.push(err355);
}
errors++;
}
}
}
}
}
}
else {
const err356 = {instancePath:instancePath+"/compiled/source/source",schemaPath:"#/oneOf/4/properties/compiled/properties/source/properties/source/oneOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err356];
}
else {
vErrors.push(err356);
}
errors++;
}
}
var _valid5 = _errs312 === errors;
if(_valid5){
valid47 = true;
passing2 = 0;
var props3 = true;
}
const _errs334 = errors;
if(errors === _errs334){
if(data124 && typeof data124 == "object" && !Array.isArray(data124)){
let missing37;
if((data124.table === undefined) && (missing37 = "table")){
const err357 = {instancePath:instancePath+"/compiled/source/source",schemaPath:"#/oneOf/4/properties/compiled/properties/source/properties/source/oneOf/1/required",keyword:"required",params:{missingProperty: missing37},message:"must have required property '"+missing37+"'"};
if(vErrors === null){
vErrors = [err357];
}
else {
vErrors.push(err357);
}
errors++;
}
else {
const _errs336 = errors;
for(const key37 in data124){
if(!(key37 === "table")){
const err358 = {instancePath:instancePath+"/compiled/source/source",schemaPath:"#/oneOf/4/properties/compiled/properties/source/properties/source/oneOf/1/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key37},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err358];
}
else {
vErrors.push(err358);
}
errors++;
break;
}
}
if(_errs336 === errors){
if(data124.table !== undefined){
let data133 = data124.table;
const _errs337 = errors;
if(errors === _errs337){
if(data133 && typeof data133 == "object" && !Array.isArray(data133)){
let missing38;
if((((data133.id === undefined) && (missing38 = "id")) || ((data133.names === undefined) && (missing38 = "names"))) || ((data133.value_type === undefined) && (missing38 = "value_type"))){
const err359 = {instancePath:instancePath+"/compiled/source/source/table",schemaPath:"#/oneOf/4/properties/compiled/properties/source/properties/source/oneOf/1/properties/table/required",keyword:"required",params:{missingProperty: missing38},message:"must have required property '"+missing38+"'"};
if(vErrors === null){
vErrors = [err359];
}
else {
vErrors.push(err359);
}
errors++;
}
else {
const _errs339 = errors;
for(const key38 in data133){
if(!(((key38 === "id") || (key38 === "names")) || (key38 === "value_type"))){
const err360 = {instancePath:instancePath+"/compiled/source/source/table",schemaPath:"#/oneOf/4/properties/compiled/properties/source/properties/source/oneOf/1/properties/table/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key38},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err360];
}
else {
vErrors.push(err360);
}
errors++;
break;
}
}
if(_errs339 === errors){
if(data133.id !== undefined){
let data134 = data133.id;
const _errs340 = errors;
if(!(((typeof data134 == "number") && (!(data134 % 1) && !isNaN(data134))) && (isFinite(data134)))){
const err361 = {instancePath:instancePath+"/compiled/source/source/table/id",schemaPath:"#/oneOf/4/properties/compiled/properties/source/properties/source/oneOf/1/properties/table/properties/id/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err361];
}
else {
vErrors.push(err361);
}
errors++;
}
if(errors === _errs340){
if((typeof data134 == "number") && (isFinite(data134))){
if(data134 > 4294967295 || isNaN(data134)){
const err362 = {instancePath:instancePath+"/compiled/source/source/table/id",schemaPath:"#/oneOf/4/properties/compiled/properties/source/properties/source/oneOf/1/properties/table/properties/id/maximum",keyword:"maximum",params:{comparison: "<=", limit: 4294967295},message:"must be <= 4294967295"};
if(vErrors === null){
vErrors = [err362];
}
else {
vErrors.push(err362);
}
errors++;
}
else {
if(data134 < 0 || isNaN(data134)){
const err363 = {instancePath:instancePath+"/compiled/source/source/table/id",schemaPath:"#/oneOf/4/properties/compiled/properties/source/properties/source/oneOf/1/properties/table/properties/id/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err363];
}
else {
vErrors.push(err363);
}
errors++;
}
}
}
}
var valid53 = _errs340 === errors;
}
else {
var valid53 = true;
}
if(valid53){
if(data133.names !== undefined){
let data135 = data133.names;
const _errs342 = errors;
if(errors === _errs342){
if(Array.isArray(data135)){
if(data135.length > 2){
const err364 = {instancePath:instancePath+"/compiled/source/source/table/names",schemaPath:"#/oneOf/4/properties/compiled/properties/source/properties/source/oneOf/1/properties/table/properties/names/maxItems",keyword:"maxItems",params:{limit: 2},message:"must NOT have more than 2 items"};
if(vErrors === null){
vErrors = [err364];
}
else {
vErrors.push(err364);
}
errors++;
}
else {
if(data135.length < 2){
const err365 = {instancePath:instancePath+"/compiled/source/source/table/names",schemaPath:"#/oneOf/4/properties/compiled/properties/source/properties/source/oneOf/1/properties/table/properties/names/minItems",keyword:"minItems",params:{limit: 2},message:"must NOT have fewer than 2 items"};
if(vErrors === null){
vErrors = [err365];
}
else {
vErrors.push(err365);
}
errors++;
}
else {
var valid54 = true;
const len9 = data135.length;
for(let i9=0; i9<len9; i9++){
let data136 = data135[i9];
const _errs344 = errors;
if(errors === _errs344){
if(typeof data136 === "string"){
if(func1(data136) > 131072){
const err366 = {instancePath:instancePath+"/compiled/source/source/table/names/" + i9,schemaPath:"#/oneOf/4/properties/compiled/properties/source/properties/source/oneOf/1/properties/table/properties/names/items/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err366];
}
else {
vErrors.push(err366);
}
errors++;
}
}
else {
const err367 = {instancePath:instancePath+"/compiled/source/source/table/names/" + i9,schemaPath:"#/oneOf/4/properties/compiled/properties/source/properties/source/oneOf/1/properties/table/properties/names/items/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err367];
}
else {
vErrors.push(err367);
}
errors++;
}
}
var valid54 = _errs344 === errors;
if(!valid54){
break;
}
}
}
}
}
else {
const err368 = {instancePath:instancePath+"/compiled/source/source/table/names",schemaPath:"#/oneOf/4/properties/compiled/properties/source/properties/source/oneOf/1/properties/table/properties/names/type",keyword:"type",params:{type: "array"},message:"must be array"};
if(vErrors === null){
vErrors = [err368];
}
else {
vErrors.push(err368);
}
errors++;
}
}
var valid53 = _errs342 === errors;
}
else {
var valid53 = true;
}
if(valid53){
if(data133.value_type !== undefined){
let data137 = data133.value_type;
const _errs346 = errors;
if(typeof data137 !== "string"){
const err369 = {instancePath:instancePath+"/compiled/source/source/table/value_type",schemaPath:"#/oneOf/4/properties/compiled/properties/source/properties/source/oneOf/1/properties/table/properties/value_type/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err369];
}
else {
vErrors.push(err369);
}
errors++;
}
if(!((((data137 === "int64") || (data137 === "boolean")) || (data137 === "utf8")) || (data137 === "binary"))){
const err370 = {instancePath:instancePath+"/compiled/source/source/table/value_type",schemaPath:"#/oneOf/4/properties/compiled/properties/source/properties/source/oneOf/1/properties/table/properties/value_type/enum",keyword:"enum",params:{allowedValues: schema33.oneOf[4].properties.compiled.properties.source.properties.source.oneOf[1].properties.table.properties.value_type.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err370];
}
else {
vErrors.push(err370);
}
errors++;
}
var valid53 = _errs346 === errors;
}
else {
var valid53 = true;
}
}
}
}
}
}
else {
const err371 = {instancePath:instancePath+"/compiled/source/source/table",schemaPath:"#/oneOf/4/properties/compiled/properties/source/properties/source/oneOf/1/properties/table/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err371];
}
else {
vErrors.push(err371);
}
errors++;
}
}
}
}
}
}
else {
const err372 = {instancePath:instancePath+"/compiled/source/source",schemaPath:"#/oneOf/4/properties/compiled/properties/source/properties/source/oneOf/1/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err372];
}
else {
vErrors.push(err372);
}
errors++;
}
}
var _valid5 = _errs334 === errors;
if(_valid5 && valid47){
valid47 = false;
passing2 = [passing2, 1];
}
else {
if(_valid5){
valid47 = true;
passing2 = 1;
if(props3 !== true){
props3 = true;
}
}
const _errs348 = errors;
if(errors === _errs348){
if(data124 && typeof data124 == "object" && !Array.isArray(data124)){
let missing39;
if((data124.document === undefined) && (missing39 = "document")){
const err373 = {instancePath:instancePath+"/compiled/source/source",schemaPath:"#/oneOf/4/properties/compiled/properties/source/properties/source/oneOf/2/required",keyword:"required",params:{missingProperty: missing39},message:"must have required property '"+missing39+"'"};
if(vErrors === null){
vErrors = [err373];
}
else {
vErrors.push(err373);
}
errors++;
}
else {
const _errs350 = errors;
for(const key39 in data124){
if(!(key39 === "document")){
const err374 = {instancePath:instancePath+"/compiled/source/source",schemaPath:"#/oneOf/4/properties/compiled/properties/source/properties/source/oneOf/2/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key39},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err374];
}
else {
vErrors.push(err374);
}
errors++;
break;
}
}
if(_errs350 === errors){
if(data124.document !== undefined){
let data138 = data124.document;
const _errs351 = errors;
if(errors === _errs351){
if(data138 && typeof data138 == "object" && !Array.isArray(data138)){
let missing40;
if(((((data138.reference === undefined) && (missing40 = "reference")) || ((data138.change_format === undefined) && (missing40 = "change_format"))) || ((data138.expand === undefined) && (missing40 = "expand"))) || ((data138.projections === undefined) && (missing40 = "projections"))){
const err375 = {instancePath:instancePath+"/compiled/source/source/document",schemaPath:"#/oneOf/4/properties/compiled/properties/source/properties/source/oneOf/2/properties/document/required",keyword:"required",params:{missingProperty: missing40},message:"must have required property '"+missing40+"'"};
if(vErrors === null){
vErrors = [err375];
}
else {
vErrors.push(err375);
}
errors++;
}
else {
const _errs353 = errors;
for(const key40 in data138){
if(!((((key40 === "reference") || (key40 === "change_format")) || (key40 === "expand")) || (key40 === "projections"))){
const err376 = {instancePath:instancePath+"/compiled/source/source/document",schemaPath:"#/oneOf/4/properties/compiled/properties/source/properties/source/oneOf/2/properties/document/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key40},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err376];
}
else {
vErrors.push(err376);
}
errors++;
break;
}
}
if(_errs353 === errors){
if(data138.reference !== undefined){
let data139 = data138.reference;
const _errs354 = errors;
if(errors === _errs354){
if(data139 && typeof data139 == "object" && !Array.isArray(data139)){
let missing41;
if((((((data139.resource === undefined) && (missing41 = "resource")) || ((data139.document === undefined) && (missing41 = "document"))) || ((data139.epoch === undefined) && (missing41 = "epoch"))) || ((data139.type_revision === undefined) && (missing41 = "type_revision"))) || ((data139.revision === undefined) && (missing41 = "revision"))){
const err377 = {instancePath:instancePath+"/compiled/source/source/document/reference",schemaPath:"#/oneOf/4/properties/compiled/properties/source/properties/source/oneOf/2/properties/document/properties/reference/required",keyword:"required",params:{missingProperty: missing41},message:"must have required property '"+missing41+"'"};
if(vErrors === null){
vErrors = [err377];
}
else {
vErrors.push(err377);
}
errors++;
}
else {
const _errs356 = errors;
for(const key41 in data139){
if(!(((((key41 === "resource") || (key41 === "document")) || (key41 === "epoch")) || (key41 === "type_revision")) || (key41 === "revision"))){
const err378 = {instancePath:instancePath+"/compiled/source/source/document/reference",schemaPath:"#/oneOf/4/properties/compiled/properties/source/properties/source/oneOf/2/properties/document/properties/reference/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key41},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err378];
}
else {
vErrors.push(err378);
}
errors++;
break;
}
}
if(_errs356 === errors){
if(data139.resource !== undefined){
let data140 = data139.resource;
const _errs357 = errors;
if(!(((typeof data140 == "number") && (!(data140 % 1) && !isNaN(data140))) && (isFinite(data140)))){
const err379 = {instancePath:instancePath+"/compiled/source/source/document/reference/resource",schemaPath:"#/oneOf/4/properties/compiled/properties/source/properties/source/oneOf/2/properties/document/properties/reference/properties/resource/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err379];
}
else {
vErrors.push(err379);
}
errors++;
}
if(errors === _errs357){
if((typeof data140 == "number") && (isFinite(data140))){
if(data140 > 9007199254740991 || isNaN(data140)){
const err380 = {instancePath:instancePath+"/compiled/source/source/document/reference/resource",schemaPath:"#/oneOf/4/properties/compiled/properties/source/properties/source/oneOf/2/properties/document/properties/reference/properties/resource/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"};
if(vErrors === null){
vErrors = [err380];
}
else {
vErrors.push(err380);
}
errors++;
}
else {
if(data140 < 0 || isNaN(data140)){
const err381 = {instancePath:instancePath+"/compiled/source/source/document/reference/resource",schemaPath:"#/oneOf/4/properties/compiled/properties/source/properties/source/oneOf/2/properties/document/properties/reference/properties/resource/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err381];
}
else {
vErrors.push(err381);
}
errors++;
}
}
}
}
var valid57 = _errs357 === errors;
}
else {
var valid57 = true;
}
if(valid57){
if(data139.document !== undefined){
let data141 = data139.document;
const _errs359 = errors;
if(errors === _errs359){
if(typeof data141 === "string"){
if(func1(data141) > 131072){
const err382 = {instancePath:instancePath+"/compiled/source/source/document/reference/document",schemaPath:"#/oneOf/4/properties/compiled/properties/source/properties/source/oneOf/2/properties/document/properties/reference/properties/document/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err382];
}
else {
vErrors.push(err382);
}
errors++;
}
}
else {
const err383 = {instancePath:instancePath+"/compiled/source/source/document/reference/document",schemaPath:"#/oneOf/4/properties/compiled/properties/source/properties/source/oneOf/2/properties/document/properties/reference/properties/document/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err383];
}
else {
vErrors.push(err383);
}
errors++;
}
}
var valid57 = _errs359 === errors;
}
else {
var valid57 = true;
}
if(valid57){
if(data139.epoch !== undefined){
let data142 = data139.epoch;
const _errs361 = errors;
if(errors === _errs361){
if(typeof data142 === "string"){
if(func1(data142) > 131072){
const err384 = {instancePath:instancePath+"/compiled/source/source/document/reference/epoch",schemaPath:"#/oneOf/4/properties/compiled/properties/source/properties/source/oneOf/2/properties/document/properties/reference/properties/epoch/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err384];
}
else {
vErrors.push(err384);
}
errors++;
}
}
else {
const err385 = {instancePath:instancePath+"/compiled/source/source/document/reference/epoch",schemaPath:"#/oneOf/4/properties/compiled/properties/source/properties/source/oneOf/2/properties/document/properties/reference/properties/epoch/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err385];
}
else {
vErrors.push(err385);
}
errors++;
}
}
var valid57 = _errs361 === errors;
}
else {
var valid57 = true;
}
if(valid57){
if(data139.type_revision !== undefined){
let data143 = data139.type_revision;
const _errs363 = errors;
if(!(((typeof data143 == "number") && (!(data143 % 1) && !isNaN(data143))) && (isFinite(data143)))){
const err386 = {instancePath:instancePath+"/compiled/source/source/document/reference/type_revision",schemaPath:"#/oneOf/4/properties/compiled/properties/source/properties/source/oneOf/2/properties/document/properties/reference/properties/type_revision/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err386];
}
else {
vErrors.push(err386);
}
errors++;
}
if(errors === _errs363){
if((typeof data143 == "number") && (isFinite(data143))){
if(data143 > 4294967295 || isNaN(data143)){
const err387 = {instancePath:instancePath+"/compiled/source/source/document/reference/type_revision",schemaPath:"#/oneOf/4/properties/compiled/properties/source/properties/source/oneOf/2/properties/document/properties/reference/properties/type_revision/maximum",keyword:"maximum",params:{comparison: "<=", limit: 4294967295},message:"must be <= 4294967295"};
if(vErrors === null){
vErrors = [err387];
}
else {
vErrors.push(err387);
}
errors++;
}
else {
if(data143 < 0 || isNaN(data143)){
const err388 = {instancePath:instancePath+"/compiled/source/source/document/reference/type_revision",schemaPath:"#/oneOf/4/properties/compiled/properties/source/properties/source/oneOf/2/properties/document/properties/reference/properties/type_revision/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err388];
}
else {
vErrors.push(err388);
}
errors++;
}
}
}
}
var valid57 = _errs363 === errors;
}
else {
var valid57 = true;
}
if(valid57){
if(data139.revision !== undefined){
let data144 = data139.revision;
const _errs365 = errors;
if(errors === _errs365){
if(typeof data144 === "string"){
if(func1(data144) > 131072){
const err389 = {instancePath:instancePath+"/compiled/source/source/document/reference/revision",schemaPath:"#/oneOf/4/properties/compiled/properties/source/properties/source/oneOf/2/properties/document/properties/reference/properties/revision/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err389];
}
else {
vErrors.push(err389);
}
errors++;
}
}
else {
const err390 = {instancePath:instancePath+"/compiled/source/source/document/reference/revision",schemaPath:"#/oneOf/4/properties/compiled/properties/source/properties/source/oneOf/2/properties/document/properties/reference/properties/revision/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err390];
}
else {
vErrors.push(err390);
}
errors++;
}
}
var valid57 = _errs365 === errors;
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
else {
const err391 = {instancePath:instancePath+"/compiled/source/source/document/reference",schemaPath:"#/oneOf/4/properties/compiled/properties/source/properties/source/oneOf/2/properties/document/properties/reference/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err391];
}
else {
vErrors.push(err391);
}
errors++;
}
}
var valid56 = _errs354 === errors;
}
else {
var valid56 = true;
}
if(valid56){
if(data138.change_format !== undefined){
let data145 = data138.change_format;
const _errs367 = errors;
if(!(((typeof data145 == "number") && (!(data145 % 1) && !isNaN(data145))) && (isFinite(data145)))){
const err392 = {instancePath:instancePath+"/compiled/source/source/document/change_format",schemaPath:"#/oneOf/4/properties/compiled/properties/source/properties/source/oneOf/2/properties/document/properties/change_format/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err392];
}
else {
vErrors.push(err392);
}
errors++;
}
if(errors === _errs367){
if((typeof data145 == "number") && (isFinite(data145))){
if(data145 > 4294967295 || isNaN(data145)){
const err393 = {instancePath:instancePath+"/compiled/source/source/document/change_format",schemaPath:"#/oneOf/4/properties/compiled/properties/source/properties/source/oneOf/2/properties/document/properties/change_format/maximum",keyword:"maximum",params:{comparison: "<=", limit: 4294967295},message:"must be <= 4294967295"};
if(vErrors === null){
vErrors = [err393];
}
else {
vErrors.push(err393);
}
errors++;
}
else {
if(data145 < 0 || isNaN(data145)){
const err394 = {instancePath:instancePath+"/compiled/source/source/document/change_format",schemaPath:"#/oneOf/4/properties/compiled/properties/source/properties/source/oneOf/2/properties/document/properties/change_format/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err394];
}
else {
vErrors.push(err394);
}
errors++;
}
}
}
}
var valid56 = _errs367 === errors;
}
else {
var valid56 = true;
}
if(valid56){
if(data138.expand !== undefined){
let data146 = data138.expand;
const _errs369 = errors;
const _errs370 = errors;
let valid58 = false;
const _errs371 = errors;
if(errors === _errs371){
if(Array.isArray(data146)){
if(data146.length > 8){
const err395 = {instancePath:instancePath+"/compiled/source/source/document/expand",schemaPath:"#/oneOf/4/properties/compiled/properties/source/properties/source/oneOf/2/properties/document/properties/expand/anyOf/0/maxItems",keyword:"maxItems",params:{limit: 8},message:"must NOT have more than 8 items"};
if(vErrors === null){
vErrors = [err395];
}
else {
vErrors.push(err395);
}
errors++;
}
else {
var valid59 = true;
const len10 = data146.length;
for(let i10=0; i10<len10; i10++){
let data147 = data146[i10];
const _errs373 = errors;
if(errors === _errs373){
if(typeof data147 === "string"){
if(func1(data147) > 131072){
const err396 = {instancePath:instancePath+"/compiled/source/source/document/expand/" + i10,schemaPath:"#/oneOf/4/properties/compiled/properties/source/properties/source/oneOf/2/properties/document/properties/expand/anyOf/0/items/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err396];
}
else {
vErrors.push(err396);
}
errors++;
}
}
else {
const err397 = {instancePath:instancePath+"/compiled/source/source/document/expand/" + i10,schemaPath:"#/oneOf/4/properties/compiled/properties/source/properties/source/oneOf/2/properties/document/properties/expand/anyOf/0/items/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err397];
}
else {
vErrors.push(err397);
}
errors++;
}
}
var valid59 = _errs373 === errors;
if(!valid59){
break;
}
}
}
}
else {
const err398 = {instancePath:instancePath+"/compiled/source/source/document/expand",schemaPath:"#/oneOf/4/properties/compiled/properties/source/properties/source/oneOf/2/properties/document/properties/expand/anyOf/0/type",keyword:"type",params:{type: "array"},message:"must be array"};
if(vErrors === null){
vErrors = [err398];
}
else {
vErrors.push(err398);
}
errors++;
}
}
var _valid6 = _errs371 === errors;
valid58 = valid58 || _valid6;
const _errs375 = errors;
if(data146 !== null){
const err399 = {instancePath:instancePath+"/compiled/source/source/document/expand",schemaPath:"#/oneOf/4/properties/compiled/properties/source/properties/source/oneOf/2/properties/document/properties/expand/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err399];
}
else {
vErrors.push(err399);
}
errors++;
}
var _valid6 = _errs375 === errors;
valid58 = valid58 || _valid6;
if(!valid58){
const err400 = {instancePath:instancePath+"/compiled/source/source/document/expand",schemaPath:"#/oneOf/4/properties/compiled/properties/source/properties/source/oneOf/2/properties/document/properties/expand/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err400];
}
else {
vErrors.push(err400);
}
errors++;
}
else {
errors = _errs370;
if(vErrors !== null){
if(_errs370){
vErrors.length = _errs370;
}
else {
vErrors = null;
}
}
}
var valid56 = _errs369 === errors;
}
else {
var valid56 = true;
}
if(valid56){
if(data138.projections !== undefined){
let data148 = data138.projections;
const _errs377 = errors;
if(errors === _errs377){
if(Array.isArray(data148)){
if(data148.length > 8){
const err401 = {instancePath:instancePath+"/compiled/source/source/document/projections",schemaPath:"#/oneOf/4/properties/compiled/properties/source/properties/source/oneOf/2/properties/document/properties/projections/maxItems",keyword:"maxItems",params:{limit: 8},message:"must NOT have more than 8 items"};
if(vErrors === null){
vErrors = [err401];
}
else {
vErrors.push(err401);
}
errors++;
}
else {
var valid60 = true;
const len11 = data148.length;
for(let i11=0; i11<len11; i11++){
let data149 = data148[i11];
const _errs379 = errors;
if(errors === _errs379){
if(data149 && typeof data149 == "object" && !Array.isArray(data149)){
let missing42;
if(((((((data149.column === undefined) && (missing42 = "column")) || ((data149.path === undefined) && (missing42 = "path"))) || ((data149.relative === undefined) && (missing42 = "relative"))) || ((data149.mode === undefined) && (missing42 = "mode"))) || ((data149.text_bytes === undefined) && (missing42 = "text_bytes"))) || ((data149.text_steps === undefined) && (missing42 = "text_steps"))){
const err402 = {instancePath:instancePath+"/compiled/source/source/document/projections/" + i11,schemaPath:"#/oneOf/4/properties/compiled/properties/source/properties/source/oneOf/2/properties/document/properties/projections/items/required",keyword:"required",params:{missingProperty: missing42},message:"must have required property '"+missing42+"'"};
if(vErrors === null){
vErrors = [err402];
}
else {
vErrors.push(err402);
}
errors++;
}
else {
const _errs381 = errors;
for(const key42 in data149){
if(!((((((key42 === "column") || (key42 === "path")) || (key42 === "relative")) || (key42 === "mode")) || (key42 === "text_bytes")) || (key42 === "text_steps"))){
const err403 = {instancePath:instancePath+"/compiled/source/source/document/projections/" + i11,schemaPath:"#/oneOf/4/properties/compiled/properties/source/properties/source/oneOf/2/properties/document/properties/projections/items/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key42},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err403];
}
else {
vErrors.push(err403);
}
errors++;
break;
}
}
if(_errs381 === errors){
if(data149.column !== undefined){
let data150 = data149.column;
const _errs382 = errors;
if(errors === _errs382){
if(data150 && typeof data150 == "object" && !Array.isArray(data150)){
let missing43;
if(((data150.name === undefined) && (missing43 = "name")) || ((data150.type === undefined) && (missing43 = "type"))){
const err404 = {instancePath:instancePath+"/compiled/source/source/document/projections/" + i11+"/column",schemaPath:"#/oneOf/4/properties/compiled/properties/source/properties/source/oneOf/2/properties/document/properties/projections/items/properties/column/required",keyword:"required",params:{missingProperty: missing43},message:"must have required property '"+missing43+"'"};
if(vErrors === null){
vErrors = [err404];
}
else {
vErrors.push(err404);
}
errors++;
}
else {
const _errs384 = errors;
for(const key43 in data150){
if(!((key43 === "name") || (key43 === "type"))){
const err405 = {instancePath:instancePath+"/compiled/source/source/document/projections/" + i11+"/column",schemaPath:"#/oneOf/4/properties/compiled/properties/source/properties/source/oneOf/2/properties/document/properties/projections/items/properties/column/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key43},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err405];
}
else {
vErrors.push(err405);
}
errors++;
break;
}
}
if(_errs384 === errors){
if(data150.name !== undefined){
let data151 = data150.name;
const _errs385 = errors;
if(errors === _errs385){
if(typeof data151 === "string"){
if(func1(data151) > 131072){
const err406 = {instancePath:instancePath+"/compiled/source/source/document/projections/" + i11+"/column/name",schemaPath:"#/oneOf/4/properties/compiled/properties/source/properties/source/oneOf/2/properties/document/properties/projections/items/properties/column/properties/name/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err406];
}
else {
vErrors.push(err406);
}
errors++;
}
}
else {
const err407 = {instancePath:instancePath+"/compiled/source/source/document/projections/" + i11+"/column/name",schemaPath:"#/oneOf/4/properties/compiled/properties/source/properties/source/oneOf/2/properties/document/properties/projections/items/properties/column/properties/name/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err407];
}
else {
vErrors.push(err407);
}
errors++;
}
}
var valid62 = _errs385 === errors;
}
else {
var valid62 = true;
}
if(valid62){
if(data150.type !== undefined){
let data152 = data150.type;
const _errs387 = errors;
if(typeof data152 !== "string"){
const err408 = {instancePath:instancePath+"/compiled/source/source/document/projections/" + i11+"/column/type",schemaPath:"#/oneOf/4/properties/compiled/properties/source/properties/source/oneOf/2/properties/document/properties/projections/items/properties/column/properties/type/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err408];
}
else {
vErrors.push(err408);
}
errors++;
}
if(!((((((data152 === "int64") || (data152 === "uint64")) || (data152 === "float64")) || (data152 === "boolean")) || (data152 === "utf8")) || (data152 === "binary"))){
const err409 = {instancePath:instancePath+"/compiled/source/source/document/projections/" + i11+"/column/type",schemaPath:"#/oneOf/4/properties/compiled/properties/source/properties/source/oneOf/2/properties/document/properties/projections/items/properties/column/properties/type/enum",keyword:"enum",params:{allowedValues: schema33.oneOf[4].properties.compiled.properties.source.properties.source.oneOf[2].properties.document.properties.projections.items.properties.column.properties.type.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err409];
}
else {
vErrors.push(err409);
}
errors++;
}
var valid62 = _errs387 === errors;
}
else {
var valid62 = true;
}
}
}
}
}
else {
const err410 = {instancePath:instancePath+"/compiled/source/source/document/projections/" + i11+"/column",schemaPath:"#/oneOf/4/properties/compiled/properties/source/properties/source/oneOf/2/properties/document/properties/projections/items/properties/column/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err410];
}
else {
vErrors.push(err410);
}
errors++;
}
}
var valid61 = _errs382 === errors;
}
else {
var valid61 = true;
}
if(valid61){
if(data149.path !== undefined){
let data153 = data149.path;
const _errs389 = errors;
if(errors === _errs389){
if(Array.isArray(data153)){
if(data153.length > 8){
const err411 = {instancePath:instancePath+"/compiled/source/source/document/projections/" + i11+"/path",schemaPath:"#/oneOf/4/properties/compiled/properties/source/properties/source/oneOf/2/properties/document/properties/projections/items/properties/path/maxItems",keyword:"maxItems",params:{limit: 8},message:"must NOT have more than 8 items"};
if(vErrors === null){
vErrors = [err411];
}
else {
vErrors.push(err411);
}
errors++;
}
else {
var valid63 = true;
const len12 = data153.length;
for(let i12=0; i12<len12; i12++){
let data154 = data153[i12];
const _errs391 = errors;
if(errors === _errs391){
if(typeof data154 === "string"){
if(func1(data154) > 131072){
const err412 = {instancePath:instancePath+"/compiled/source/source/document/projections/" + i11+"/path/" + i12,schemaPath:"#/oneOf/4/properties/compiled/properties/source/properties/source/oneOf/2/properties/document/properties/projections/items/properties/path/items/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err412];
}
else {
vErrors.push(err412);
}
errors++;
}
}
else {
const err413 = {instancePath:instancePath+"/compiled/source/source/document/projections/" + i11+"/path/" + i12,schemaPath:"#/oneOf/4/properties/compiled/properties/source/properties/source/oneOf/2/properties/document/properties/projections/items/properties/path/items/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err413];
}
else {
vErrors.push(err413);
}
errors++;
}
}
var valid63 = _errs391 === errors;
if(!valid63){
break;
}
}
}
}
else {
const err414 = {instancePath:instancePath+"/compiled/source/source/document/projections/" + i11+"/path",schemaPath:"#/oneOf/4/properties/compiled/properties/source/properties/source/oneOf/2/properties/document/properties/projections/items/properties/path/type",keyword:"type",params:{type: "array"},message:"must be array"};
if(vErrors === null){
vErrors = [err414];
}
else {
vErrors.push(err414);
}
errors++;
}
}
var valid61 = _errs389 === errors;
}
else {
var valid61 = true;
}
if(valid61){
if(data149.relative !== undefined){
const _errs393 = errors;
if(typeof data149.relative !== "boolean"){
const err415 = {instancePath:instancePath+"/compiled/source/source/document/projections/" + i11+"/relative",schemaPath:"#/oneOf/4/properties/compiled/properties/source/properties/source/oneOf/2/properties/document/properties/projections/items/properties/relative/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"};
if(vErrors === null){
vErrors = [err415];
}
else {
vErrors.push(err415);
}
errors++;
}
var valid61 = _errs393 === errors;
}
else {
var valid61 = true;
}
if(valid61){
if(data149.mode !== undefined){
let data156 = data149.mode;
const _errs395 = errors;
if(typeof data156 !== "string"){
const err416 = {instancePath:instancePath+"/compiled/source/source/document/projections/" + i11+"/mode",schemaPath:"#/oneOf/4/properties/compiled/properties/source/properties/source/oneOf/2/properties/document/properties/projections/items/properties/mode/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err416];
}
else {
vErrors.push(err416);
}
errors++;
}
if(!((((data156 === "scalar") || (data156 === "text")) || (data156 === "element_counter")) || (data156 === "element_replica"))){
const err417 = {instancePath:instancePath+"/compiled/source/source/document/projections/" + i11+"/mode",schemaPath:"#/oneOf/4/properties/compiled/properties/source/properties/source/oneOf/2/properties/document/properties/projections/items/properties/mode/enum",keyword:"enum",params:{allowedValues: schema33.oneOf[4].properties.compiled.properties.source.properties.source.oneOf[2].properties.document.properties.projections.items.properties.mode.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err417];
}
else {
vErrors.push(err417);
}
errors++;
}
var valid61 = _errs395 === errors;
}
else {
var valid61 = true;
}
if(valid61){
if(data149.text_bytes !== undefined){
let data157 = data149.text_bytes;
const _errs397 = errors;
if(!(((typeof data157 == "number") && (!(data157 % 1) && !isNaN(data157))) && (isFinite(data157)))){
const err418 = {instancePath:instancePath+"/compiled/source/source/document/projections/" + i11+"/text_bytes",schemaPath:"#/oneOf/4/properties/compiled/properties/source/properties/source/oneOf/2/properties/document/properties/projections/items/properties/text_bytes/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err418];
}
else {
vErrors.push(err418);
}
errors++;
}
if(errors === _errs397){
if((typeof data157 == "number") && (isFinite(data157))){
if(data157 > 65535 || isNaN(data157)){
const err419 = {instancePath:instancePath+"/compiled/source/source/document/projections/" + i11+"/text_bytes",schemaPath:"#/oneOf/4/properties/compiled/properties/source/properties/source/oneOf/2/properties/document/properties/projections/items/properties/text_bytes/maximum",keyword:"maximum",params:{comparison: "<=", limit: 65535},message:"must be <= 65535"};
if(vErrors === null){
vErrors = [err419];
}
else {
vErrors.push(err419);
}
errors++;
}
else {
if(data157 < 0 || isNaN(data157)){
const err420 = {instancePath:instancePath+"/compiled/source/source/document/projections/" + i11+"/text_bytes",schemaPath:"#/oneOf/4/properties/compiled/properties/source/properties/source/oneOf/2/properties/document/properties/projections/items/properties/text_bytes/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err420];
}
else {
vErrors.push(err420);
}
errors++;
}
}
}
}
var valid61 = _errs397 === errors;
}
else {
var valid61 = true;
}
if(valid61){
if(data149.text_steps !== undefined){
let data158 = data149.text_steps;
const _errs399 = errors;
if(!(((typeof data158 == "number") && (!(data158 % 1) && !isNaN(data158))) && (isFinite(data158)))){
const err421 = {instancePath:instancePath+"/compiled/source/source/document/projections/" + i11+"/text_steps",schemaPath:"#/oneOf/4/properties/compiled/properties/source/properties/source/oneOf/2/properties/document/properties/projections/items/properties/text_steps/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err421];
}
else {
vErrors.push(err421);
}
errors++;
}
if(errors === _errs399){
if((typeof data158 == "number") && (isFinite(data158))){
if(data158 > 65535 || isNaN(data158)){
const err422 = {instancePath:instancePath+"/compiled/source/source/document/projections/" + i11+"/text_steps",schemaPath:"#/oneOf/4/properties/compiled/properties/source/properties/source/oneOf/2/properties/document/properties/projections/items/properties/text_steps/maximum",keyword:"maximum",params:{comparison: "<=", limit: 65535},message:"must be <= 65535"};
if(vErrors === null){
vErrors = [err422];
}
else {
vErrors.push(err422);
}
errors++;
}
else {
if(data158 < 0 || isNaN(data158)){
const err423 = {instancePath:instancePath+"/compiled/source/source/document/projections/" + i11+"/text_steps",schemaPath:"#/oneOf/4/properties/compiled/properties/source/properties/source/oneOf/2/properties/document/properties/projections/items/properties/text_steps/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err423];
}
else {
vErrors.push(err423);
}
errors++;
}
}
}
}
var valid61 = _errs399 === errors;
}
else {
var valid61 = true;
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
const err424 = {instancePath:instancePath+"/compiled/source/source/document/projections/" + i11,schemaPath:"#/oneOf/4/properties/compiled/properties/source/properties/source/oneOf/2/properties/document/properties/projections/items/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err424];
}
else {
vErrors.push(err424);
}
errors++;
}
}
var valid60 = _errs379 === errors;
if(!valid60){
break;
}
}
}
}
else {
const err425 = {instancePath:instancePath+"/compiled/source/source/document/projections",schemaPath:"#/oneOf/4/properties/compiled/properties/source/properties/source/oneOf/2/properties/document/properties/projections/type",keyword:"type",params:{type: "array"},message:"must be array"};
if(vErrors === null){
vErrors = [err425];
}
else {
vErrors.push(err425);
}
errors++;
}
}
var valid56 = _errs377 === errors;
}
else {
var valid56 = true;
}
}
}
}
}
}
}
else {
const err426 = {instancePath:instancePath+"/compiled/source/source/document",schemaPath:"#/oneOf/4/properties/compiled/properties/source/properties/source/oneOf/2/properties/document/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err426];
}
else {
vErrors.push(err426);
}
errors++;
}
}
}
}
}
}
else {
const err427 = {instancePath:instancePath+"/compiled/source/source",schemaPath:"#/oneOf/4/properties/compiled/properties/source/properties/source/oneOf/2/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err427];
}
else {
vErrors.push(err427);
}
errors++;
}
}
var _valid5 = _errs348 === errors;
if(_valid5 && valid47){
valid47 = false;
passing2 = [passing2, 2];
}
else {
if(_valid5){
valid47 = true;
passing2 = 2;
if(props3 !== true){
props3 = true;
}
}
}
}
if(!valid47){
const err428 = {instancePath:instancePath+"/compiled/source/source",schemaPath:"#/oneOf/4/properties/compiled/properties/source/properties/source/oneOf",keyword:"oneOf",params:{passingSchemas: passing2},message:"must match exactly one schema in oneOf"};
if(vErrors === null){
vErrors = [err428];
}
else {
vErrors.push(err428);
}
errors++;
}
else {
errors = _errs311;
if(vErrors !== null){
if(_errs311){
vErrors.length = _errs311;
}
else {
vErrors = null;
}
}
}
var valid46 = _errs310 === errors;
}
else {
var valid46 = true;
}
}
}
}
}
}
else {
const err429 = {instancePath:instancePath+"/compiled/source",schemaPath:"#/oneOf/4/properties/compiled/properties/source/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err429];
}
else {
vErrors.push(err429);
}
errors++;
}
}
var valid45 = _errs303 === errors;
}
else {
var valid45 = true;
}
if(valid45){
if(data119.plan !== undefined){
let data159 = data119.plan;
const _errs401 = errors;
if(errors === _errs401){
if(data159 && typeof data159 == "object" && !Array.isArray(data159)){
let missing44;
if(((((((data159.version === undefined) && (missing44 = "version")) || ((data159.projection === undefined) && (missing44 = "projection"))) || ((data159.output_names === undefined) && (missing44 = "output_names"))) || ((data159.limit === undefined) && (missing44 = "limit"))) || ((data159.aggregate === undefined) && (missing44 = "aggregate"))) || ((data159.predicate === undefined) && (missing44 = "predicate"))){
const err430 = {instancePath:instancePath+"/compiled/plan",schemaPath:"#/oneOf/4/properties/compiled/properties/plan/required",keyword:"required",params:{missingProperty: missing44},message:"must have required property '"+missing44+"'"};
if(vErrors === null){
vErrors = [err430];
}
else {
vErrors.push(err430);
}
errors++;
}
else {
const _errs403 = errors;
for(const key44 in data159){
if(!((((((key44 === "version") || (key44 === "projection")) || (key44 === "output_names")) || (key44 === "limit")) || (key44 === "aggregate")) || (key44 === "predicate"))){
const err431 = {instancePath:instancePath+"/compiled/plan",schemaPath:"#/oneOf/4/properties/compiled/properties/plan/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key44},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err431];
}
else {
vErrors.push(err431);
}
errors++;
break;
}
}
if(_errs403 === errors){
if(data159.version !== undefined){
let data160 = data159.version;
const _errs404 = errors;
if(!(((typeof data160 == "number") && (!(data160 % 1) && !isNaN(data160))) && (isFinite(data160)))){
const err432 = {instancePath:instancePath+"/compiled/plan/version",schemaPath:"#/oneOf/4/properties/compiled/properties/plan/properties/version/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err432];
}
else {
vErrors.push(err432);
}
errors++;
}
if(errors === _errs404){
if((typeof data160 == "number") && (isFinite(data160))){
if(data160 > 255 || isNaN(data160)){
const err433 = {instancePath:instancePath+"/compiled/plan/version",schemaPath:"#/oneOf/4/properties/compiled/properties/plan/properties/version/maximum",keyword:"maximum",params:{comparison: "<=", limit: 255},message:"must be <= 255"};
if(vErrors === null){
vErrors = [err433];
}
else {
vErrors.push(err433);
}
errors++;
}
else {
if(data160 < 0 || isNaN(data160)){
const err434 = {instancePath:instancePath+"/compiled/plan/version",schemaPath:"#/oneOf/4/properties/compiled/properties/plan/properties/version/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err434];
}
else {
vErrors.push(err434);
}
errors++;
}
}
}
}
var valid64 = _errs404 === errors;
}
else {
var valid64 = true;
}
if(valid64){
if(data159.projection !== undefined){
let data161 = data159.projection;
const _errs406 = errors;
if(errors === _errs406){
if(Array.isArray(data161)){
if(data161.length > 8){
const err435 = {instancePath:instancePath+"/compiled/plan/projection",schemaPath:"#/oneOf/4/properties/compiled/properties/plan/properties/projection/maxItems",keyword:"maxItems",params:{limit: 8},message:"must NOT have more than 8 items"};
if(vErrors === null){
vErrors = [err435];
}
else {
vErrors.push(err435);
}
errors++;
}
else {
var valid65 = true;
const len13 = data161.length;
for(let i13=0; i13<len13; i13++){
let data162 = data161[i13];
const _errs408 = errors;
if(!(((typeof data162 == "number") && (!(data162 % 1) && !isNaN(data162))) && (isFinite(data162)))){
const err436 = {instancePath:instancePath+"/compiled/plan/projection/" + i13,schemaPath:"#/oneOf/4/properties/compiled/properties/plan/properties/projection/items/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err436];
}
else {
vErrors.push(err436);
}
errors++;
}
if(errors === _errs408){
if((typeof data162 == "number") && (isFinite(data162))){
if(data162 > 4294967295 || isNaN(data162)){
const err437 = {instancePath:instancePath+"/compiled/plan/projection/" + i13,schemaPath:"#/oneOf/4/properties/compiled/properties/plan/properties/projection/items/maximum",keyword:"maximum",params:{comparison: "<=", limit: 4294967295},message:"must be <= 4294967295"};
if(vErrors === null){
vErrors = [err437];
}
else {
vErrors.push(err437);
}
errors++;
}
else {
if(data162 < 0 || isNaN(data162)){
const err438 = {instancePath:instancePath+"/compiled/plan/projection/" + i13,schemaPath:"#/oneOf/4/properties/compiled/properties/plan/properties/projection/items/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err438];
}
else {
vErrors.push(err438);
}
errors++;
}
}
}
}
var valid65 = _errs408 === errors;
if(!valid65){
break;
}
}
}
}
else {
const err439 = {instancePath:instancePath+"/compiled/plan/projection",schemaPath:"#/oneOf/4/properties/compiled/properties/plan/properties/projection/type",keyword:"type",params:{type: "array"},message:"must be array"};
if(vErrors === null){
vErrors = [err439];
}
else {
vErrors.push(err439);
}
errors++;
}
}
var valid64 = _errs406 === errors;
}
else {
var valid64 = true;
}
if(valid64){
if(data159.output_names !== undefined){
let data163 = data159.output_names;
const _errs410 = errors;
const _errs411 = errors;
let valid66 = false;
const _errs412 = errors;
if(errors === _errs412){
if(Array.isArray(data163)){
if(data163.length > 8){
const err440 = {instancePath:instancePath+"/compiled/plan/output_names",schemaPath:"#/oneOf/4/properties/compiled/properties/plan/properties/output_names/anyOf/0/maxItems",keyword:"maxItems",params:{limit: 8},message:"must NOT have more than 8 items"};
if(vErrors === null){
vErrors = [err440];
}
else {
vErrors.push(err440);
}
errors++;
}
else {
var valid67 = true;
const len14 = data163.length;
for(let i14=0; i14<len14; i14++){
let data164 = data163[i14];
const _errs414 = errors;
const _errs415 = errors;
let valid68 = false;
const _errs416 = errors;
if(errors === _errs416){
if(typeof data164 === "string"){
if(func1(data164) > 131072){
const err441 = {instancePath:instancePath+"/compiled/plan/output_names/" + i14,schemaPath:"#/oneOf/4/properties/compiled/properties/plan/properties/output_names/anyOf/0/items/anyOf/0/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err441];
}
else {
vErrors.push(err441);
}
errors++;
}
}
else {
const err442 = {instancePath:instancePath+"/compiled/plan/output_names/" + i14,schemaPath:"#/oneOf/4/properties/compiled/properties/plan/properties/output_names/anyOf/0/items/anyOf/0/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err442];
}
else {
vErrors.push(err442);
}
errors++;
}
}
var _valid8 = _errs416 === errors;
valid68 = valid68 || _valid8;
const _errs418 = errors;
if(data164 !== null){
const err443 = {instancePath:instancePath+"/compiled/plan/output_names/" + i14,schemaPath:"#/oneOf/4/properties/compiled/properties/plan/properties/output_names/anyOf/0/items/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err443];
}
else {
vErrors.push(err443);
}
errors++;
}
var _valid8 = _errs418 === errors;
valid68 = valid68 || _valid8;
if(!valid68){
const err444 = {instancePath:instancePath+"/compiled/plan/output_names/" + i14,schemaPath:"#/oneOf/4/properties/compiled/properties/plan/properties/output_names/anyOf/0/items/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err444];
}
else {
vErrors.push(err444);
}
errors++;
}
else {
errors = _errs415;
if(vErrors !== null){
if(_errs415){
vErrors.length = _errs415;
}
else {
vErrors = null;
}
}
}
var valid67 = _errs414 === errors;
if(!valid67){
break;
}
}
}
}
else {
const err445 = {instancePath:instancePath+"/compiled/plan/output_names",schemaPath:"#/oneOf/4/properties/compiled/properties/plan/properties/output_names/anyOf/0/type",keyword:"type",params:{type: "array"},message:"must be array"};
if(vErrors === null){
vErrors = [err445];
}
else {
vErrors.push(err445);
}
errors++;
}
}
var _valid7 = _errs412 === errors;
valid66 = valid66 || _valid7;
const _errs420 = errors;
if(data163 !== null){
const err446 = {instancePath:instancePath+"/compiled/plan/output_names",schemaPath:"#/oneOf/4/properties/compiled/properties/plan/properties/output_names/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err446];
}
else {
vErrors.push(err446);
}
errors++;
}
var _valid7 = _errs420 === errors;
valid66 = valid66 || _valid7;
if(!valid66){
const err447 = {instancePath:instancePath+"/compiled/plan/output_names",schemaPath:"#/oneOf/4/properties/compiled/properties/plan/properties/output_names/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err447];
}
else {
vErrors.push(err447);
}
errors++;
}
else {
errors = _errs411;
if(vErrors !== null){
if(_errs411){
vErrors.length = _errs411;
}
else {
vErrors = null;
}
}
}
var valid64 = _errs410 === errors;
}
else {
var valid64 = true;
}
if(valid64){
if(data159.limit !== undefined){
let data165 = data159.limit;
const _errs422 = errors;
const _errs423 = errors;
let valid69 = false;
const _errs424 = errors;
if(errors === _errs424){
if(typeof data165 === "string"){
if(func1(data165) > 131072){
const err448 = {instancePath:instancePath+"/compiled/plan/limit",schemaPath:"#/oneOf/4/properties/compiled/properties/plan/properties/limit/anyOf/0/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err448];
}
else {
vErrors.push(err448);
}
errors++;
}
}
else {
const err449 = {instancePath:instancePath+"/compiled/plan/limit",schemaPath:"#/oneOf/4/properties/compiled/properties/plan/properties/limit/anyOf/0/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err449];
}
else {
vErrors.push(err449);
}
errors++;
}
}
var _valid9 = _errs424 === errors;
valid69 = valid69 || _valid9;
const _errs426 = errors;
if(data165 !== null){
const err450 = {instancePath:instancePath+"/compiled/plan/limit",schemaPath:"#/oneOf/4/properties/compiled/properties/plan/properties/limit/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err450];
}
else {
vErrors.push(err450);
}
errors++;
}
var _valid9 = _errs426 === errors;
valid69 = valid69 || _valid9;
if(!valid69){
const err451 = {instancePath:instancePath+"/compiled/plan/limit",schemaPath:"#/oneOf/4/properties/compiled/properties/plan/properties/limit/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err451];
}
else {
vErrors.push(err451);
}
errors++;
}
else {
errors = _errs423;
if(vErrors !== null){
if(_errs423){
vErrors.length = _errs423;
}
else {
vErrors = null;
}
}
}
var valid64 = _errs422 === errors;
}
else {
var valid64 = true;
}
if(valid64){
if(data159.aggregate !== undefined){
let data166 = data159.aggregate;
const _errs428 = errors;
if(typeof data166 !== "string"){
const err452 = {instancePath:instancePath+"/compiled/plan/aggregate",schemaPath:"#/oneOf/4/properties/compiled/properties/plan/properties/aggregate/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err452];
}
else {
vErrors.push(err452);
}
errors++;
}
if(!((((data166 === "rows") || (data166 === "count")) || (data166 === "sum")) || (data166 === "count_values"))){
const err453 = {instancePath:instancePath+"/compiled/plan/aggregate",schemaPath:"#/oneOf/4/properties/compiled/properties/plan/properties/aggregate/enum",keyword:"enum",params:{allowedValues: schema33.oneOf[4].properties.compiled.properties.plan.properties.aggregate.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err453];
}
else {
vErrors.push(err453);
}
errors++;
}
var valid64 = _errs428 === errors;
}
else {
var valid64 = true;
}
if(valid64){
if(data159.predicate !== undefined){
let data167 = data159.predicate;
const _errs430 = errors;
const _errs431 = errors;
let valid70 = false;
let passing3 = null;
const _errs432 = errors;
if(errors === _errs432){
if(data167 && typeof data167 == "object" && !Array.isArray(data167)){
let missing45;
if((data167.all === undefined) && (missing45 = "all")){
const err454 = {instancePath:instancePath+"/compiled/plan/predicate",schemaPath:"#/oneOf/4/properties/compiled/properties/plan/properties/predicate/oneOf/0/required",keyword:"required",params:{missingProperty: missing45},message:"must have required property '"+missing45+"'"};
if(vErrors === null){
vErrors = [err454];
}
else {
vErrors.push(err454);
}
errors++;
}
else {
const _errs434 = errors;
for(const key45 in data167){
if(!(key45 === "all")){
const err455 = {instancePath:instancePath+"/compiled/plan/predicate",schemaPath:"#/oneOf/4/properties/compiled/properties/plan/properties/predicate/oneOf/0/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key45},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err455];
}
else {
vErrors.push(err455);
}
errors++;
break;
}
}
if(_errs434 === errors){
if(data167.all !== undefined){
let data168 = data167.all;
const _errs435 = errors;
if(errors === _errs435){
if(data168 && typeof data168 == "object" && !Array.isArray(data168)){
if(Object.keys(data168).length > 0){
const err456 = {instancePath:instancePath+"/compiled/plan/predicate/all",schemaPath:"#/oneOf/4/properties/compiled/properties/plan/properties/predicate/oneOf/0/properties/all/maxProperties",keyword:"maxProperties",params:{limit: 0},message:"must NOT have more than 0 properties"};
if(vErrors === null){
vErrors = [err456];
}
else {
vErrors.push(err456);
}
errors++;
}
}
else {
const err457 = {instancePath:instancePath+"/compiled/plan/predicate/all",schemaPath:"#/oneOf/4/properties/compiled/properties/plan/properties/predicate/oneOf/0/properties/all/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err457];
}
else {
vErrors.push(err457);
}
errors++;
}
}
}
}
}
}
else {
const err458 = {instancePath:instancePath+"/compiled/plan/predicate",schemaPath:"#/oneOf/4/properties/compiled/properties/plan/properties/predicate/oneOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err458];
}
else {
vErrors.push(err458);
}
errors++;
}
}
var _valid10 = _errs432 === errors;
if(_valid10){
valid70 = true;
passing3 = 0;
var props4 = true;
}
const _errs437 = errors;
if(errors === _errs437){
if(data167 && typeof data167 == "object" && !Array.isArray(data167)){
let missing46;
if((data167.state === undefined) && (missing46 = "state")){
const err459 = {instancePath:instancePath+"/compiled/plan/predicate",schemaPath:"#/oneOf/4/properties/compiled/properties/plan/properties/predicate/oneOf/1/required",keyword:"required",params:{missingProperty: missing46},message:"must have required property '"+missing46+"'"};
if(vErrors === null){
vErrors = [err459];
}
else {
vErrors.push(err459);
}
errors++;
}
else {
const _errs439 = errors;
for(const key46 in data167){
if(!(key46 === "state")){
const err460 = {instancePath:instancePath+"/compiled/plan/predicate",schemaPath:"#/oneOf/4/properties/compiled/properties/plan/properties/predicate/oneOf/1/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key46},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err460];
}
else {
vErrors.push(err460);
}
errors++;
break;
}
}
if(_errs439 === errors){
if(data167.state !== undefined){
let data169 = data167.state;
const _errs440 = errors;
if(errors === _errs440){
if(data169 && typeof data169 == "object" && !Array.isArray(data169)){
let missing47;
if(((data169.column === undefined) && (missing47 = "column")) || ((data169.value === undefined) && (missing47 = "value"))){
const err461 = {instancePath:instancePath+"/compiled/plan/predicate/state",schemaPath:"#/oneOf/4/properties/compiled/properties/plan/properties/predicate/oneOf/1/properties/state/required",keyword:"required",params:{missingProperty: missing47},message:"must have required property '"+missing47+"'"};
if(vErrors === null){
vErrors = [err461];
}
else {
vErrors.push(err461);
}
errors++;
}
else {
const _errs442 = errors;
for(const key47 in data169){
if(!((key47 === "column") || (key47 === "value"))){
const err462 = {instancePath:instancePath+"/compiled/plan/predicate/state",schemaPath:"#/oneOf/4/properties/compiled/properties/plan/properties/predicate/oneOf/1/properties/state/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key47},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err462];
}
else {
vErrors.push(err462);
}
errors++;
break;
}
}
if(_errs442 === errors){
if(data169.column !== undefined){
let data170 = data169.column;
const _errs443 = errors;
if(!(((typeof data170 == "number") && (!(data170 % 1) && !isNaN(data170))) && (isFinite(data170)))){
const err463 = {instancePath:instancePath+"/compiled/plan/predicate/state/column",schemaPath:"#/oneOf/4/properties/compiled/properties/plan/properties/predicate/oneOf/1/properties/state/properties/column/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err463];
}
else {
vErrors.push(err463);
}
errors++;
}
if(errors === _errs443){
if((typeof data170 == "number") && (isFinite(data170))){
if(data170 > 255 || isNaN(data170)){
const err464 = {instancePath:instancePath+"/compiled/plan/predicate/state/column",schemaPath:"#/oneOf/4/properties/compiled/properties/plan/properties/predicate/oneOf/1/properties/state/properties/column/maximum",keyword:"maximum",params:{comparison: "<=", limit: 255},message:"must be <= 255"};
if(vErrors === null){
vErrors = [err464];
}
else {
vErrors.push(err464);
}
errors++;
}
else {
if(data170 < 0 || isNaN(data170)){
const err465 = {instancePath:instancePath+"/compiled/plan/predicate/state/column",schemaPath:"#/oneOf/4/properties/compiled/properties/plan/properties/predicate/oneOf/1/properties/state/properties/column/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err465];
}
else {
vErrors.push(err465);
}
errors++;
}
}
}
}
var valid73 = _errs443 === errors;
}
else {
var valid73 = true;
}
if(valid73){
if(data169.value !== undefined){
let data171 = data169.value;
const _errs445 = errors;
if(typeof data171 !== "string"){
const err466 = {instancePath:instancePath+"/compiled/plan/predicate/state/value",schemaPath:"#/oneOf/4/properties/compiled/properties/plan/properties/predicate/oneOf/1/properties/state/properties/value/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err466];
}
else {
vErrors.push(err466);
}
errors++;
}
if(!(((((data171 === "missing") || (data171 === "null")) || (data171 === "type_error")) || (data171 === "value")) || (data171 === "conflict"))){
const err467 = {instancePath:instancePath+"/compiled/plan/predicate/state/value",schemaPath:"#/oneOf/4/properties/compiled/properties/plan/properties/predicate/oneOf/1/properties/state/properties/value/enum",keyword:"enum",params:{allowedValues: schema33.oneOf[4].properties.compiled.properties.plan.properties.predicate.oneOf[1].properties.state.properties.value.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err467];
}
else {
vErrors.push(err467);
}
errors++;
}
var valid73 = _errs445 === errors;
}
else {
var valid73 = true;
}
}
}
}
}
else {
const err468 = {instancePath:instancePath+"/compiled/plan/predicate/state",schemaPath:"#/oneOf/4/properties/compiled/properties/plan/properties/predicate/oneOf/1/properties/state/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err468];
}
else {
vErrors.push(err468);
}
errors++;
}
}
}
}
}
}
else {
const err469 = {instancePath:instancePath+"/compiled/plan/predicate",schemaPath:"#/oneOf/4/properties/compiled/properties/plan/properties/predicate/oneOf/1/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err469];
}
else {
vErrors.push(err469);
}
errors++;
}
}
var _valid10 = _errs437 === errors;
if(_valid10 && valid70){
valid70 = false;
passing3 = [passing3, 1];
}
else {
if(_valid10){
valid70 = true;
passing3 = 1;
if(props4 !== true){
props4 = true;
}
}
const _errs447 = errors;
if(errors === _errs447){
if(data167 && typeof data167 == "object" && !Array.isArray(data167)){
let missing48;
if((data167.compare === undefined) && (missing48 = "compare")){
const err470 = {instancePath:instancePath+"/compiled/plan/predicate",schemaPath:"#/oneOf/4/properties/compiled/properties/plan/properties/predicate/oneOf/2/required",keyword:"required",params:{missingProperty: missing48},message:"must have required property '"+missing48+"'"};
if(vErrors === null){
vErrors = [err470];
}
else {
vErrors.push(err470);
}
errors++;
}
else {
const _errs449 = errors;
for(const key48 in data167){
if(!(key48 === "compare")){
const err471 = {instancePath:instancePath+"/compiled/plan/predicate",schemaPath:"#/oneOf/4/properties/compiled/properties/plan/properties/predicate/oneOf/2/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key48},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err471];
}
else {
vErrors.push(err471);
}
errors++;
break;
}
}
if(_errs449 === errors){
if(data167.compare !== undefined){
let data172 = data167.compare;
const _errs450 = errors;
if(errors === _errs450){
if(data172 && typeof data172 == "object" && !Array.isArray(data172)){
let missing49;
if((((data172.column === undefined) && (missing49 = "column")) || ((data172.op === undefined) && (missing49 = "op"))) || ((data172.value === undefined) && (missing49 = "value"))){
const err472 = {instancePath:instancePath+"/compiled/plan/predicate/compare",schemaPath:"#/oneOf/4/properties/compiled/properties/plan/properties/predicate/oneOf/2/properties/compare/required",keyword:"required",params:{missingProperty: missing49},message:"must have required property '"+missing49+"'"};
if(vErrors === null){
vErrors = [err472];
}
else {
vErrors.push(err472);
}
errors++;
}
else {
const _errs452 = errors;
for(const key49 in data172){
if(!(((key49 === "column") || (key49 === "op")) || (key49 === "value"))){
const err473 = {instancePath:instancePath+"/compiled/plan/predicate/compare",schemaPath:"#/oneOf/4/properties/compiled/properties/plan/properties/predicate/oneOf/2/properties/compare/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key49},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err473];
}
else {
vErrors.push(err473);
}
errors++;
break;
}
}
if(_errs452 === errors){
if(data172.column !== undefined){
let data173 = data172.column;
const _errs453 = errors;
if(!(((typeof data173 == "number") && (!(data173 % 1) && !isNaN(data173))) && (isFinite(data173)))){
const err474 = {instancePath:instancePath+"/compiled/plan/predicate/compare/column",schemaPath:"#/oneOf/4/properties/compiled/properties/plan/properties/predicate/oneOf/2/properties/compare/properties/column/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err474];
}
else {
vErrors.push(err474);
}
errors++;
}
if(errors === _errs453){
if((typeof data173 == "number") && (isFinite(data173))){
if(data173 > 255 || isNaN(data173)){
const err475 = {instancePath:instancePath+"/compiled/plan/predicate/compare/column",schemaPath:"#/oneOf/4/properties/compiled/properties/plan/properties/predicate/oneOf/2/properties/compare/properties/column/maximum",keyword:"maximum",params:{comparison: "<=", limit: 255},message:"must be <= 255"};
if(vErrors === null){
vErrors = [err475];
}
else {
vErrors.push(err475);
}
errors++;
}
else {
if(data173 < 0 || isNaN(data173)){
const err476 = {instancePath:instancePath+"/compiled/plan/predicate/compare/column",schemaPath:"#/oneOf/4/properties/compiled/properties/plan/properties/predicate/oneOf/2/properties/compare/properties/column/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err476];
}
else {
vErrors.push(err476);
}
errors++;
}
}
}
}
var valid75 = _errs453 === errors;
}
else {
var valid75 = true;
}
if(valid75){
if(data172.op !== undefined){
let data174 = data172.op;
const _errs455 = errors;
if(typeof data174 !== "string"){
const err477 = {instancePath:instancePath+"/compiled/plan/predicate/compare/op",schemaPath:"#/oneOf/4/properties/compiled/properties/plan/properties/predicate/oneOf/2/properties/compare/properties/op/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err477];
}
else {
vErrors.push(err477);
}
errors++;
}
if(!((((((data174 === "eq") || (data174 === "ne")) || (data174 === "lt")) || (data174 === "le")) || (data174 === "gt")) || (data174 === "ge"))){
const err478 = {instancePath:instancePath+"/compiled/plan/predicate/compare/op",schemaPath:"#/oneOf/4/properties/compiled/properties/plan/properties/predicate/oneOf/2/properties/compare/properties/op/enum",keyword:"enum",params:{allowedValues: schema33.oneOf[4].properties.compiled.properties.plan.properties.predicate.oneOf[2].properties.compare.properties.op.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err478];
}
else {
vErrors.push(err478);
}
errors++;
}
var valid75 = _errs455 === errors;
}
else {
var valid75 = true;
}
if(valid75){
if(data172.value !== undefined){
let data175 = data172.value;
const _errs457 = errors;
const _errs458 = errors;
let valid76 = false;
let passing4 = null;
const _errs459 = errors;
if(errors === _errs459){
if(data175 && typeof data175 == "object" && !Array.isArray(data175)){
let missing50;
if((data175.int64 === undefined) && (missing50 = "int64")){
const err479 = {instancePath:instancePath+"/compiled/plan/predicate/compare/value",schemaPath:"#/oneOf/4/properties/compiled/properties/plan/properties/predicate/oneOf/2/properties/compare/properties/value/oneOf/0/required",keyword:"required",params:{missingProperty: missing50},message:"must have required property '"+missing50+"'"};
if(vErrors === null){
vErrors = [err479];
}
else {
vErrors.push(err479);
}
errors++;
}
else {
const _errs461 = errors;
for(const key50 in data175){
if(!(key50 === "int64")){
const err480 = {instancePath:instancePath+"/compiled/plan/predicate/compare/value",schemaPath:"#/oneOf/4/properties/compiled/properties/plan/properties/predicate/oneOf/2/properties/compare/properties/value/oneOf/0/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key50},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err480];
}
else {
vErrors.push(err480);
}
errors++;
break;
}
}
if(_errs461 === errors){
if(data175.int64 !== undefined){
let data176 = data175.int64;
const _errs462 = errors;
if(errors === _errs462){
if(typeof data176 === "string"){
if(func1(data176) > 131072){
const err481 = {instancePath:instancePath+"/compiled/plan/predicate/compare/value/int64",schemaPath:"#/oneOf/4/properties/compiled/properties/plan/properties/predicate/oneOf/2/properties/compare/properties/value/oneOf/0/properties/int64/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err481];
}
else {
vErrors.push(err481);
}
errors++;
}
}
else {
const err482 = {instancePath:instancePath+"/compiled/plan/predicate/compare/value/int64",schemaPath:"#/oneOf/4/properties/compiled/properties/plan/properties/predicate/oneOf/2/properties/compare/properties/value/oneOf/0/properties/int64/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err482];
}
else {
vErrors.push(err482);
}
errors++;
}
}
}
}
}
}
else {
const err483 = {instancePath:instancePath+"/compiled/plan/predicate/compare/value",schemaPath:"#/oneOf/4/properties/compiled/properties/plan/properties/predicate/oneOf/2/properties/compare/properties/value/oneOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err483];
}
else {
vErrors.push(err483);
}
errors++;
}
}
var _valid11 = _errs459 === errors;
if(_valid11){
valid76 = true;
passing4 = 0;
var props5 = true;
}
const _errs464 = errors;
if(errors === _errs464){
if(data175 && typeof data175 == "object" && !Array.isArray(data175)){
let missing51;
if((data175.uint64 === undefined) && (missing51 = "uint64")){
const err484 = {instancePath:instancePath+"/compiled/plan/predicate/compare/value",schemaPath:"#/oneOf/4/properties/compiled/properties/plan/properties/predicate/oneOf/2/properties/compare/properties/value/oneOf/1/required",keyword:"required",params:{missingProperty: missing51},message:"must have required property '"+missing51+"'"};
if(vErrors === null){
vErrors = [err484];
}
else {
vErrors.push(err484);
}
errors++;
}
else {
const _errs466 = errors;
for(const key51 in data175){
if(!(key51 === "uint64")){
const err485 = {instancePath:instancePath+"/compiled/plan/predicate/compare/value",schemaPath:"#/oneOf/4/properties/compiled/properties/plan/properties/predicate/oneOf/2/properties/compare/properties/value/oneOf/1/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key51},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err485];
}
else {
vErrors.push(err485);
}
errors++;
break;
}
}
if(_errs466 === errors){
if(data175.uint64 !== undefined){
let data177 = data175.uint64;
const _errs467 = errors;
if(errors === _errs467){
if(typeof data177 === "string"){
if(func1(data177) > 131072){
const err486 = {instancePath:instancePath+"/compiled/plan/predicate/compare/value/uint64",schemaPath:"#/oneOf/4/properties/compiled/properties/plan/properties/predicate/oneOf/2/properties/compare/properties/value/oneOf/1/properties/uint64/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err486];
}
else {
vErrors.push(err486);
}
errors++;
}
}
else {
const err487 = {instancePath:instancePath+"/compiled/plan/predicate/compare/value/uint64",schemaPath:"#/oneOf/4/properties/compiled/properties/plan/properties/predicate/oneOf/2/properties/compare/properties/value/oneOf/1/properties/uint64/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err487];
}
else {
vErrors.push(err487);
}
errors++;
}
}
}
}
}
}
else {
const err488 = {instancePath:instancePath+"/compiled/plan/predicate/compare/value",schemaPath:"#/oneOf/4/properties/compiled/properties/plan/properties/predicate/oneOf/2/properties/compare/properties/value/oneOf/1/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err488];
}
else {
vErrors.push(err488);
}
errors++;
}
}
var _valid11 = _errs464 === errors;
if(_valid11 && valid76){
valid76 = false;
passing4 = [passing4, 1];
}
else {
if(_valid11){
valid76 = true;
passing4 = 1;
if(props5 !== true){
props5 = true;
}
}
const _errs469 = errors;
if(errors === _errs469){
if(data175 && typeof data175 == "object" && !Array.isArray(data175)){
let missing52;
if((data175.float_bits === undefined) && (missing52 = "float_bits")){
const err489 = {instancePath:instancePath+"/compiled/plan/predicate/compare/value",schemaPath:"#/oneOf/4/properties/compiled/properties/plan/properties/predicate/oneOf/2/properties/compare/properties/value/oneOf/2/required",keyword:"required",params:{missingProperty: missing52},message:"must have required property '"+missing52+"'"};
if(vErrors === null){
vErrors = [err489];
}
else {
vErrors.push(err489);
}
errors++;
}
else {
const _errs471 = errors;
for(const key52 in data175){
if(!(key52 === "float_bits")){
const err490 = {instancePath:instancePath+"/compiled/plan/predicate/compare/value",schemaPath:"#/oneOf/4/properties/compiled/properties/plan/properties/predicate/oneOf/2/properties/compare/properties/value/oneOf/2/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key52},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err490];
}
else {
vErrors.push(err490);
}
errors++;
break;
}
}
if(_errs471 === errors){
if(data175.float_bits !== undefined){
let data178 = data175.float_bits;
const _errs472 = errors;
if(errors === _errs472){
if(typeof data178 === "string"){
if(func1(data178) > 131072){
const err491 = {instancePath:instancePath+"/compiled/plan/predicate/compare/value/float_bits",schemaPath:"#/oneOf/4/properties/compiled/properties/plan/properties/predicate/oneOf/2/properties/compare/properties/value/oneOf/2/properties/float_bits/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err491];
}
else {
vErrors.push(err491);
}
errors++;
}
}
else {
const err492 = {instancePath:instancePath+"/compiled/plan/predicate/compare/value/float_bits",schemaPath:"#/oneOf/4/properties/compiled/properties/plan/properties/predicate/oneOf/2/properties/compare/properties/value/oneOf/2/properties/float_bits/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err492];
}
else {
vErrors.push(err492);
}
errors++;
}
}
}
}
}
}
else {
const err493 = {instancePath:instancePath+"/compiled/plan/predicate/compare/value",schemaPath:"#/oneOf/4/properties/compiled/properties/plan/properties/predicate/oneOf/2/properties/compare/properties/value/oneOf/2/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err493];
}
else {
vErrors.push(err493);
}
errors++;
}
}
var _valid11 = _errs469 === errors;
if(_valid11 && valid76){
valid76 = false;
passing4 = [passing4, 2];
}
else {
if(_valid11){
valid76 = true;
passing4 = 2;
if(props5 !== true){
props5 = true;
}
}
const _errs474 = errors;
if(errors === _errs474){
if(data175 && typeof data175 == "object" && !Array.isArray(data175)){
let missing53;
if((data175.boolean === undefined) && (missing53 = "boolean")){
const err494 = {instancePath:instancePath+"/compiled/plan/predicate/compare/value",schemaPath:"#/oneOf/4/properties/compiled/properties/plan/properties/predicate/oneOf/2/properties/compare/properties/value/oneOf/3/required",keyword:"required",params:{missingProperty: missing53},message:"must have required property '"+missing53+"'"};
if(vErrors === null){
vErrors = [err494];
}
else {
vErrors.push(err494);
}
errors++;
}
else {
const _errs476 = errors;
for(const key53 in data175){
if(!(key53 === "boolean")){
const err495 = {instancePath:instancePath+"/compiled/plan/predicate/compare/value",schemaPath:"#/oneOf/4/properties/compiled/properties/plan/properties/predicate/oneOf/2/properties/compare/properties/value/oneOf/3/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key53},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err495];
}
else {
vErrors.push(err495);
}
errors++;
break;
}
}
if(_errs476 === errors){
if(data175.boolean !== undefined){
if(typeof data175.boolean !== "boolean"){
const err496 = {instancePath:instancePath+"/compiled/plan/predicate/compare/value/boolean",schemaPath:"#/oneOf/4/properties/compiled/properties/plan/properties/predicate/oneOf/2/properties/compare/properties/value/oneOf/3/properties/boolean/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"};
if(vErrors === null){
vErrors = [err496];
}
else {
vErrors.push(err496);
}
errors++;
}
}
}
}
}
else {
const err497 = {instancePath:instancePath+"/compiled/plan/predicate/compare/value",schemaPath:"#/oneOf/4/properties/compiled/properties/plan/properties/predicate/oneOf/2/properties/compare/properties/value/oneOf/3/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err497];
}
else {
vErrors.push(err497);
}
errors++;
}
}
var _valid11 = _errs474 === errors;
if(_valid11 && valid76){
valid76 = false;
passing4 = [passing4, 3];
}
else {
if(_valid11){
valid76 = true;
passing4 = 3;
if(props5 !== true){
props5 = true;
}
}
const _errs479 = errors;
if(errors === _errs479){
if(data175 && typeof data175 == "object" && !Array.isArray(data175)){
let missing54;
if((data175.utf8 === undefined) && (missing54 = "utf8")){
const err498 = {instancePath:instancePath+"/compiled/plan/predicate/compare/value",schemaPath:"#/oneOf/4/properties/compiled/properties/plan/properties/predicate/oneOf/2/properties/compare/properties/value/oneOf/4/required",keyword:"required",params:{missingProperty: missing54},message:"must have required property '"+missing54+"'"};
if(vErrors === null){
vErrors = [err498];
}
else {
vErrors.push(err498);
}
errors++;
}
else {
const _errs481 = errors;
for(const key54 in data175){
if(!(key54 === "utf8")){
const err499 = {instancePath:instancePath+"/compiled/plan/predicate/compare/value",schemaPath:"#/oneOf/4/properties/compiled/properties/plan/properties/predicate/oneOf/2/properties/compare/properties/value/oneOf/4/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key54},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err499];
}
else {
vErrors.push(err499);
}
errors++;
break;
}
}
if(_errs481 === errors){
if(data175.utf8 !== undefined){
let data180 = data175.utf8;
const _errs482 = errors;
if(errors === _errs482){
if(typeof data180 === "string"){
if(func1(data180) > 131072){
const err500 = {instancePath:instancePath+"/compiled/plan/predicate/compare/value/utf8",schemaPath:"#/oneOf/4/properties/compiled/properties/plan/properties/predicate/oneOf/2/properties/compare/properties/value/oneOf/4/properties/utf8/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err500];
}
else {
vErrors.push(err500);
}
errors++;
}
}
else {
const err501 = {instancePath:instancePath+"/compiled/plan/predicate/compare/value/utf8",schemaPath:"#/oneOf/4/properties/compiled/properties/plan/properties/predicate/oneOf/2/properties/compare/properties/value/oneOf/4/properties/utf8/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err501];
}
else {
vErrors.push(err501);
}
errors++;
}
}
}
}
}
}
else {
const err502 = {instancePath:instancePath+"/compiled/plan/predicate/compare/value",schemaPath:"#/oneOf/4/properties/compiled/properties/plan/properties/predicate/oneOf/2/properties/compare/properties/value/oneOf/4/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err502];
}
else {
vErrors.push(err502);
}
errors++;
}
}
var _valid11 = _errs479 === errors;
if(_valid11 && valid76){
valid76 = false;
passing4 = [passing4, 4];
}
else {
if(_valid11){
valid76 = true;
passing4 = 4;
if(props5 !== true){
props5 = true;
}
}
const _errs484 = errors;
if(errors === _errs484){
if(data175 && typeof data175 == "object" && !Array.isArray(data175)){
let missing55;
if((data175.binary === undefined) && (missing55 = "binary")){
const err503 = {instancePath:instancePath+"/compiled/plan/predicate/compare/value",schemaPath:"#/oneOf/4/properties/compiled/properties/plan/properties/predicate/oneOf/2/properties/compare/properties/value/oneOf/5/required",keyword:"required",params:{missingProperty: missing55},message:"must have required property '"+missing55+"'"};
if(vErrors === null){
vErrors = [err503];
}
else {
vErrors.push(err503);
}
errors++;
}
else {
const _errs486 = errors;
for(const key55 in data175){
if(!(key55 === "binary")){
const err504 = {instancePath:instancePath+"/compiled/plan/predicate/compare/value",schemaPath:"#/oneOf/4/properties/compiled/properties/plan/properties/predicate/oneOf/2/properties/compare/properties/value/oneOf/5/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key55},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err504];
}
else {
vErrors.push(err504);
}
errors++;
break;
}
}
if(_errs486 === errors){
if(data175.binary !== undefined){
let data181 = data175.binary;
const _errs487 = errors;
if(errors === _errs487){
if(typeof data181 === "string"){
if(func1(data181) > 131072){
const err505 = {instancePath:instancePath+"/compiled/plan/predicate/compare/value/binary",schemaPath:"#/oneOf/4/properties/compiled/properties/plan/properties/predicate/oneOf/2/properties/compare/properties/value/oneOf/5/properties/binary/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err505];
}
else {
vErrors.push(err505);
}
errors++;
}
}
else {
const err506 = {instancePath:instancePath+"/compiled/plan/predicate/compare/value/binary",schemaPath:"#/oneOf/4/properties/compiled/properties/plan/properties/predicate/oneOf/2/properties/compare/properties/value/oneOf/5/properties/binary/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err506];
}
else {
vErrors.push(err506);
}
errors++;
}
}
}
}
}
}
else {
const err507 = {instancePath:instancePath+"/compiled/plan/predicate/compare/value",schemaPath:"#/oneOf/4/properties/compiled/properties/plan/properties/predicate/oneOf/2/properties/compare/properties/value/oneOf/5/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err507];
}
else {
vErrors.push(err507);
}
errors++;
}
}
var _valid11 = _errs484 === errors;
if(_valid11 && valid76){
valid76 = false;
passing4 = [passing4, 5];
}
else {
if(_valid11){
valid76 = true;
passing4 = 5;
if(props5 !== true){
props5 = true;
}
}
}
}
}
}
}
if(!valid76){
const err508 = {instancePath:instancePath+"/compiled/plan/predicate/compare/value",schemaPath:"#/oneOf/4/properties/compiled/properties/plan/properties/predicate/oneOf/2/properties/compare/properties/value/oneOf",keyword:"oneOf",params:{passingSchemas: passing4},message:"must match exactly one schema in oneOf"};
if(vErrors === null){
vErrors = [err508];
}
else {
vErrors.push(err508);
}
errors++;
}
else {
errors = _errs458;
if(vErrors !== null){
if(_errs458){
vErrors.length = _errs458;
}
else {
vErrors = null;
}
}
}
var valid75 = _errs457 === errors;
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
const err509 = {instancePath:instancePath+"/compiled/plan/predicate/compare",schemaPath:"#/oneOf/4/properties/compiled/properties/plan/properties/predicate/oneOf/2/properties/compare/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err509];
}
else {
vErrors.push(err509);
}
errors++;
}
}
}
}
}
}
else {
const err510 = {instancePath:instancePath+"/compiled/plan/predicate",schemaPath:"#/oneOf/4/properties/compiled/properties/plan/properties/predicate/oneOf/2/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err510];
}
else {
vErrors.push(err510);
}
errors++;
}
}
var _valid10 = _errs447 === errors;
if(_valid10 && valid70){
valid70 = false;
passing3 = [passing3, 2];
}
else {
if(_valid10){
valid70 = true;
passing3 = 2;
if(props4 !== true){
props4 = true;
}
}
const _errs489 = errors;
if(errors === _errs489){
if(data167 && typeof data167 == "object" && !Array.isArray(data167)){
let missing56;
if((data167.program === undefined) && (missing56 = "program")){
const err511 = {instancePath:instancePath+"/compiled/plan/predicate",schemaPath:"#/oneOf/4/properties/compiled/properties/plan/properties/predicate/oneOf/3/required",keyword:"required",params:{missingProperty: missing56},message:"must have required property '"+missing56+"'"};
if(vErrors === null){
vErrors = [err511];
}
else {
vErrors.push(err511);
}
errors++;
}
else {
const _errs491 = errors;
for(const key56 in data167){
if(!(key56 === "program")){
const err512 = {instancePath:instancePath+"/compiled/plan/predicate",schemaPath:"#/oneOf/4/properties/compiled/properties/plan/properties/predicate/oneOf/3/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key56},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err512];
}
else {
vErrors.push(err512);
}
errors++;
break;
}
}
if(_errs491 === errors){
if(data167.program !== undefined){
let data182 = data167.program;
const _errs492 = errors;
if(errors === _errs492){
if(Array.isArray(data182)){
if(data182.length > 64){
const err513 = {instancePath:instancePath+"/compiled/plan/predicate/program",schemaPath:"#/oneOf/4/properties/compiled/properties/plan/properties/predicate/oneOf/3/properties/program/maxItems",keyword:"maxItems",params:{limit: 64},message:"must NOT have more than 64 items"};
if(vErrors === null){
vErrors = [err513];
}
else {
vErrors.push(err513);
}
errors++;
}
else {
var valid84 = true;
const len15 = data182.length;
for(let i15=0; i15<len15; i15++){
let data183 = data182[i15];
const _errs494 = errors;
const _errs495 = errors;
let valid85 = false;
let passing5 = null;
const _errs496 = errors;
if(errors === _errs496){
if(data183 && typeof data183 == "object" && !Array.isArray(data183)){
let missing57;
if((data183.atom === undefined) && (missing57 = "atom")){
const err514 = {instancePath:instancePath+"/compiled/plan/predicate/program/" + i15,schemaPath:"#/oneOf/4/properties/compiled/properties/plan/properties/predicate/oneOf/3/properties/program/items/oneOf/0/required",keyword:"required",params:{missingProperty: missing57},message:"must have required property '"+missing57+"'"};
if(vErrors === null){
vErrors = [err514];
}
else {
vErrors.push(err514);
}
errors++;
}
else {
const _errs498 = errors;
for(const key57 in data183){
if(!(key57 === "atom")){
const err515 = {instancePath:instancePath+"/compiled/plan/predicate/program/" + i15,schemaPath:"#/oneOf/4/properties/compiled/properties/plan/properties/predicate/oneOf/3/properties/program/items/oneOf/0/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key57},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err515];
}
else {
vErrors.push(err515);
}
errors++;
break;
}
}
if(_errs498 === errors){
if(data183.atom !== undefined){
let data184 = data183.atom;
const _errs500 = errors;
let valid87 = false;
let passing6 = null;
const _errs501 = errors;
if(errors === _errs501){
if(data184 && typeof data184 == "object" && !Array.isArray(data184)){
let missing58;
if((data184.all === undefined) && (missing58 = "all")){
const err516 = {instancePath:instancePath+"/compiled/plan/predicate/program/" + i15+"/atom",schemaPath:"#/oneOf/4/properties/compiled/properties/plan/properties/predicate/oneOf/3/properties/program/items/oneOf/0/properties/atom/oneOf/0/required",keyword:"required",params:{missingProperty: missing58},message:"must have required property '"+missing58+"'"};
if(vErrors === null){
vErrors = [err516];
}
else {
vErrors.push(err516);
}
errors++;
}
else {
const _errs503 = errors;
for(const key58 in data184){
if(!(key58 === "all")){
const err517 = {instancePath:instancePath+"/compiled/plan/predicate/program/" + i15+"/atom",schemaPath:"#/oneOf/4/properties/compiled/properties/plan/properties/predicate/oneOf/3/properties/program/items/oneOf/0/properties/atom/oneOf/0/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key58},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err517];
}
else {
vErrors.push(err517);
}
errors++;
break;
}
}
if(_errs503 === errors){
if(data184.all !== undefined){
let data185 = data184.all;
const _errs504 = errors;
if(errors === _errs504){
if(data185 && typeof data185 == "object" && !Array.isArray(data185)){
if(Object.keys(data185).length > 0){
const err518 = {instancePath:instancePath+"/compiled/plan/predicate/program/" + i15+"/atom/all",schemaPath:"#/oneOf/4/properties/compiled/properties/plan/properties/predicate/oneOf/3/properties/program/items/oneOf/0/properties/atom/oneOf/0/properties/all/maxProperties",keyword:"maxProperties",params:{limit: 0},message:"must NOT have more than 0 properties"};
if(vErrors === null){
vErrors = [err518];
}
else {
vErrors.push(err518);
}
errors++;
}
}
else {
const err519 = {instancePath:instancePath+"/compiled/plan/predicate/program/" + i15+"/atom/all",schemaPath:"#/oneOf/4/properties/compiled/properties/plan/properties/predicate/oneOf/3/properties/program/items/oneOf/0/properties/atom/oneOf/0/properties/all/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err519];
}
else {
vErrors.push(err519);
}
errors++;
}
}
}
}
}
}
else {
const err520 = {instancePath:instancePath+"/compiled/plan/predicate/program/" + i15+"/atom",schemaPath:"#/oneOf/4/properties/compiled/properties/plan/properties/predicate/oneOf/3/properties/program/items/oneOf/0/properties/atom/oneOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err520];
}
else {
vErrors.push(err520);
}
errors++;
}
}
var _valid13 = _errs501 === errors;
if(_valid13){
valid87 = true;
passing6 = 0;
var props6 = true;
}
const _errs506 = errors;
if(errors === _errs506){
if(data184 && typeof data184 == "object" && !Array.isArray(data184)){
let missing59;
if((data184.state === undefined) && (missing59 = "state")){
const err521 = {instancePath:instancePath+"/compiled/plan/predicate/program/" + i15+"/atom",schemaPath:"#/oneOf/4/properties/compiled/properties/plan/properties/predicate/oneOf/3/properties/program/items/oneOf/0/properties/atom/oneOf/1/required",keyword:"required",params:{missingProperty: missing59},message:"must have required property '"+missing59+"'"};
if(vErrors === null){
vErrors = [err521];
}
else {
vErrors.push(err521);
}
errors++;
}
else {
const _errs508 = errors;
for(const key59 in data184){
if(!(key59 === "state")){
const err522 = {instancePath:instancePath+"/compiled/plan/predicate/program/" + i15+"/atom",schemaPath:"#/oneOf/4/properties/compiled/properties/plan/properties/predicate/oneOf/3/properties/program/items/oneOf/0/properties/atom/oneOf/1/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key59},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err522];
}
else {
vErrors.push(err522);
}
errors++;
break;
}
}
if(_errs508 === errors){
if(data184.state !== undefined){
let data186 = data184.state;
const _errs509 = errors;
if(errors === _errs509){
if(data186 && typeof data186 == "object" && !Array.isArray(data186)){
let missing60;
if(((data186.column === undefined) && (missing60 = "column")) || ((data186.value === undefined) && (missing60 = "value"))){
const err523 = {instancePath:instancePath+"/compiled/plan/predicate/program/" + i15+"/atom/state",schemaPath:"#/oneOf/4/properties/compiled/properties/plan/properties/predicate/oneOf/3/properties/program/items/oneOf/0/properties/atom/oneOf/1/properties/state/required",keyword:"required",params:{missingProperty: missing60},message:"must have required property '"+missing60+"'"};
if(vErrors === null){
vErrors = [err523];
}
else {
vErrors.push(err523);
}
errors++;
}
else {
const _errs511 = errors;
for(const key60 in data186){
if(!((key60 === "column") || (key60 === "value"))){
const err524 = {instancePath:instancePath+"/compiled/plan/predicate/program/" + i15+"/atom/state",schemaPath:"#/oneOf/4/properties/compiled/properties/plan/properties/predicate/oneOf/3/properties/program/items/oneOf/0/properties/atom/oneOf/1/properties/state/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key60},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err524];
}
else {
vErrors.push(err524);
}
errors++;
break;
}
}
if(_errs511 === errors){
if(data186.column !== undefined){
let data187 = data186.column;
const _errs512 = errors;
if(!(((typeof data187 == "number") && (!(data187 % 1) && !isNaN(data187))) && (isFinite(data187)))){
const err525 = {instancePath:instancePath+"/compiled/plan/predicate/program/" + i15+"/atom/state/column",schemaPath:"#/oneOf/4/properties/compiled/properties/plan/properties/predicate/oneOf/3/properties/program/items/oneOf/0/properties/atom/oneOf/1/properties/state/properties/column/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err525];
}
else {
vErrors.push(err525);
}
errors++;
}
if(errors === _errs512){
if((typeof data187 == "number") && (isFinite(data187))){
if(data187 > 255 || isNaN(data187)){
const err526 = {instancePath:instancePath+"/compiled/plan/predicate/program/" + i15+"/atom/state/column",schemaPath:"#/oneOf/4/properties/compiled/properties/plan/properties/predicate/oneOf/3/properties/program/items/oneOf/0/properties/atom/oneOf/1/properties/state/properties/column/maximum",keyword:"maximum",params:{comparison: "<=", limit: 255},message:"must be <= 255"};
if(vErrors === null){
vErrors = [err526];
}
else {
vErrors.push(err526);
}
errors++;
}
else {
if(data187 < 0 || isNaN(data187)){
const err527 = {instancePath:instancePath+"/compiled/plan/predicate/program/" + i15+"/atom/state/column",schemaPath:"#/oneOf/4/properties/compiled/properties/plan/properties/predicate/oneOf/3/properties/program/items/oneOf/0/properties/atom/oneOf/1/properties/state/properties/column/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err527];
}
else {
vErrors.push(err527);
}
errors++;
}
}
}
}
var valid90 = _errs512 === errors;
}
else {
var valid90 = true;
}
if(valid90){
if(data186.value !== undefined){
let data188 = data186.value;
const _errs514 = errors;
if(typeof data188 !== "string"){
const err528 = {instancePath:instancePath+"/compiled/plan/predicate/program/" + i15+"/atom/state/value",schemaPath:"#/oneOf/4/properties/compiled/properties/plan/properties/predicate/oneOf/3/properties/program/items/oneOf/0/properties/atom/oneOf/1/properties/state/properties/value/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err528];
}
else {
vErrors.push(err528);
}
errors++;
}
if(!(((((data188 === "missing") || (data188 === "null")) || (data188 === "type_error")) || (data188 === "value")) || (data188 === "conflict"))){
const err529 = {instancePath:instancePath+"/compiled/plan/predicate/program/" + i15+"/atom/state/value",schemaPath:"#/oneOf/4/properties/compiled/properties/plan/properties/predicate/oneOf/3/properties/program/items/oneOf/0/properties/atom/oneOf/1/properties/state/properties/value/enum",keyword:"enum",params:{allowedValues: schema33.oneOf[4].properties.compiled.properties.plan.properties.predicate.oneOf[3].properties.program.items.oneOf[0].properties.atom.oneOf[1].properties.state.properties.value.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err529];
}
else {
vErrors.push(err529);
}
errors++;
}
var valid90 = _errs514 === errors;
}
else {
var valid90 = true;
}
}
}
}
}
else {
const err530 = {instancePath:instancePath+"/compiled/plan/predicate/program/" + i15+"/atom/state",schemaPath:"#/oneOf/4/properties/compiled/properties/plan/properties/predicate/oneOf/3/properties/program/items/oneOf/0/properties/atom/oneOf/1/properties/state/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err530];
}
else {
vErrors.push(err530);
}
errors++;
}
}
}
}
}
}
else {
const err531 = {instancePath:instancePath+"/compiled/plan/predicate/program/" + i15+"/atom",schemaPath:"#/oneOf/4/properties/compiled/properties/plan/properties/predicate/oneOf/3/properties/program/items/oneOf/0/properties/atom/oneOf/1/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err531];
}
else {
vErrors.push(err531);
}
errors++;
}
}
var _valid13 = _errs506 === errors;
if(_valid13 && valid87){
valid87 = false;
passing6 = [passing6, 1];
}
else {
if(_valid13){
valid87 = true;
passing6 = 1;
if(props6 !== true){
props6 = true;
}
}
const _errs516 = errors;
if(errors === _errs516){
if(data184 && typeof data184 == "object" && !Array.isArray(data184)){
let missing61;
if((data184.compare === undefined) && (missing61 = "compare")){
const err532 = {instancePath:instancePath+"/compiled/plan/predicate/program/" + i15+"/atom",schemaPath:"#/oneOf/4/properties/compiled/properties/plan/properties/predicate/oneOf/3/properties/program/items/oneOf/0/properties/atom/oneOf/2/required",keyword:"required",params:{missingProperty: missing61},message:"must have required property '"+missing61+"'"};
if(vErrors === null){
vErrors = [err532];
}
else {
vErrors.push(err532);
}
errors++;
}
else {
const _errs518 = errors;
for(const key61 in data184){
if(!(key61 === "compare")){
const err533 = {instancePath:instancePath+"/compiled/plan/predicate/program/" + i15+"/atom",schemaPath:"#/oneOf/4/properties/compiled/properties/plan/properties/predicate/oneOf/3/properties/program/items/oneOf/0/properties/atom/oneOf/2/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key61},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err533];
}
else {
vErrors.push(err533);
}
errors++;
break;
}
}
if(_errs518 === errors){
if(data184.compare !== undefined){
let data189 = data184.compare;
const _errs519 = errors;
if(errors === _errs519){
if(data189 && typeof data189 == "object" && !Array.isArray(data189)){
let missing62;
if((((data189.column === undefined) && (missing62 = "column")) || ((data189.op === undefined) && (missing62 = "op"))) || ((data189.value === undefined) && (missing62 = "value"))){
const err534 = {instancePath:instancePath+"/compiled/plan/predicate/program/" + i15+"/atom/compare",schemaPath:"#/oneOf/4/properties/compiled/properties/plan/properties/predicate/oneOf/3/properties/program/items/oneOf/0/properties/atom/oneOf/2/properties/compare/required",keyword:"required",params:{missingProperty: missing62},message:"must have required property '"+missing62+"'"};
if(vErrors === null){
vErrors = [err534];
}
else {
vErrors.push(err534);
}
errors++;
}
else {
const _errs521 = errors;
for(const key62 in data189){
if(!(((key62 === "column") || (key62 === "op")) || (key62 === "value"))){
const err535 = {instancePath:instancePath+"/compiled/plan/predicate/program/" + i15+"/atom/compare",schemaPath:"#/oneOf/4/properties/compiled/properties/plan/properties/predicate/oneOf/3/properties/program/items/oneOf/0/properties/atom/oneOf/2/properties/compare/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key62},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err535];
}
else {
vErrors.push(err535);
}
errors++;
break;
}
}
if(_errs521 === errors){
if(data189.column !== undefined){
let data190 = data189.column;
const _errs522 = errors;
if(!(((typeof data190 == "number") && (!(data190 % 1) && !isNaN(data190))) && (isFinite(data190)))){
const err536 = {instancePath:instancePath+"/compiled/plan/predicate/program/" + i15+"/atom/compare/column",schemaPath:"#/oneOf/4/properties/compiled/properties/plan/properties/predicate/oneOf/3/properties/program/items/oneOf/0/properties/atom/oneOf/2/properties/compare/properties/column/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err536];
}
else {
vErrors.push(err536);
}
errors++;
}
if(errors === _errs522){
if((typeof data190 == "number") && (isFinite(data190))){
if(data190 > 255 || isNaN(data190)){
const err537 = {instancePath:instancePath+"/compiled/plan/predicate/program/" + i15+"/atom/compare/column",schemaPath:"#/oneOf/4/properties/compiled/properties/plan/properties/predicate/oneOf/3/properties/program/items/oneOf/0/properties/atom/oneOf/2/properties/compare/properties/column/maximum",keyword:"maximum",params:{comparison: "<=", limit: 255},message:"must be <= 255"};
if(vErrors === null){
vErrors = [err537];
}
else {
vErrors.push(err537);
}
errors++;
}
else {
if(data190 < 0 || isNaN(data190)){
const err538 = {instancePath:instancePath+"/compiled/plan/predicate/program/" + i15+"/atom/compare/column",schemaPath:"#/oneOf/4/properties/compiled/properties/plan/properties/predicate/oneOf/3/properties/program/items/oneOf/0/properties/atom/oneOf/2/properties/compare/properties/column/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err538];
}
else {
vErrors.push(err538);
}
errors++;
}
}
}
}
var valid92 = _errs522 === errors;
}
else {
var valid92 = true;
}
if(valid92){
if(data189.op !== undefined){
let data191 = data189.op;
const _errs524 = errors;
if(typeof data191 !== "string"){
const err539 = {instancePath:instancePath+"/compiled/plan/predicate/program/" + i15+"/atom/compare/op",schemaPath:"#/oneOf/4/properties/compiled/properties/plan/properties/predicate/oneOf/3/properties/program/items/oneOf/0/properties/atom/oneOf/2/properties/compare/properties/op/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err539];
}
else {
vErrors.push(err539);
}
errors++;
}
if(!((((((data191 === "eq") || (data191 === "ne")) || (data191 === "lt")) || (data191 === "le")) || (data191 === "gt")) || (data191 === "ge"))){
const err540 = {instancePath:instancePath+"/compiled/plan/predicate/program/" + i15+"/atom/compare/op",schemaPath:"#/oneOf/4/properties/compiled/properties/plan/properties/predicate/oneOf/3/properties/program/items/oneOf/0/properties/atom/oneOf/2/properties/compare/properties/op/enum",keyword:"enum",params:{allowedValues: schema33.oneOf[4].properties.compiled.properties.plan.properties.predicate.oneOf[3].properties.program.items.oneOf[0].properties.atom.oneOf[2].properties.compare.properties.op.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err540];
}
else {
vErrors.push(err540);
}
errors++;
}
var valid92 = _errs524 === errors;
}
else {
var valid92 = true;
}
if(valid92){
if(data189.value !== undefined){
let data192 = data189.value;
const _errs526 = errors;
const _errs527 = errors;
let valid93 = false;
let passing7 = null;
const _errs528 = errors;
if(errors === _errs528){
if(data192 && typeof data192 == "object" && !Array.isArray(data192)){
let missing63;
if((data192.int64 === undefined) && (missing63 = "int64")){
const err541 = {instancePath:instancePath+"/compiled/plan/predicate/program/" + i15+"/atom/compare/value",schemaPath:"#/oneOf/4/properties/compiled/properties/plan/properties/predicate/oneOf/3/properties/program/items/oneOf/0/properties/atom/oneOf/2/properties/compare/properties/value/oneOf/0/required",keyword:"required",params:{missingProperty: missing63},message:"must have required property '"+missing63+"'"};
if(vErrors === null){
vErrors = [err541];
}
else {
vErrors.push(err541);
}
errors++;
}
else {
const _errs530 = errors;
for(const key63 in data192){
if(!(key63 === "int64")){
const err542 = {instancePath:instancePath+"/compiled/plan/predicate/program/" + i15+"/atom/compare/value",schemaPath:"#/oneOf/4/properties/compiled/properties/plan/properties/predicate/oneOf/3/properties/program/items/oneOf/0/properties/atom/oneOf/2/properties/compare/properties/value/oneOf/0/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key63},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err542];
}
else {
vErrors.push(err542);
}
errors++;
break;
}
}
if(_errs530 === errors){
if(data192.int64 !== undefined){
let data193 = data192.int64;
const _errs531 = errors;
if(errors === _errs531){
if(typeof data193 === "string"){
if(func1(data193) > 131072){
const err543 = {instancePath:instancePath+"/compiled/plan/predicate/program/" + i15+"/atom/compare/value/int64",schemaPath:"#/oneOf/4/properties/compiled/properties/plan/properties/predicate/oneOf/3/properties/program/items/oneOf/0/properties/atom/oneOf/2/properties/compare/properties/value/oneOf/0/properties/int64/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err543];
}
else {
vErrors.push(err543);
}
errors++;
}
}
else {
const err544 = {instancePath:instancePath+"/compiled/plan/predicate/program/" + i15+"/atom/compare/value/int64",schemaPath:"#/oneOf/4/properties/compiled/properties/plan/properties/predicate/oneOf/3/properties/program/items/oneOf/0/properties/atom/oneOf/2/properties/compare/properties/value/oneOf/0/properties/int64/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err544];
}
else {
vErrors.push(err544);
}
errors++;
}
}
}
}
}
}
else {
const err545 = {instancePath:instancePath+"/compiled/plan/predicate/program/" + i15+"/atom/compare/value",schemaPath:"#/oneOf/4/properties/compiled/properties/plan/properties/predicate/oneOf/3/properties/program/items/oneOf/0/properties/atom/oneOf/2/properties/compare/properties/value/oneOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err545];
}
else {
vErrors.push(err545);
}
errors++;
}
}
var _valid14 = _errs528 === errors;
if(_valid14){
valid93 = true;
passing7 = 0;
var props7 = true;
}
const _errs533 = errors;
if(errors === _errs533){
if(data192 && typeof data192 == "object" && !Array.isArray(data192)){
let missing64;
if((data192.uint64 === undefined) && (missing64 = "uint64")){
const err546 = {instancePath:instancePath+"/compiled/plan/predicate/program/" + i15+"/atom/compare/value",schemaPath:"#/oneOf/4/properties/compiled/properties/plan/properties/predicate/oneOf/3/properties/program/items/oneOf/0/properties/atom/oneOf/2/properties/compare/properties/value/oneOf/1/required",keyword:"required",params:{missingProperty: missing64},message:"must have required property '"+missing64+"'"};
if(vErrors === null){
vErrors = [err546];
}
else {
vErrors.push(err546);
}
errors++;
}
else {
const _errs535 = errors;
for(const key64 in data192){
if(!(key64 === "uint64")){
const err547 = {instancePath:instancePath+"/compiled/plan/predicate/program/" + i15+"/atom/compare/value",schemaPath:"#/oneOf/4/properties/compiled/properties/plan/properties/predicate/oneOf/3/properties/program/items/oneOf/0/properties/atom/oneOf/2/properties/compare/properties/value/oneOf/1/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key64},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err547];
}
else {
vErrors.push(err547);
}
errors++;
break;
}
}
if(_errs535 === errors){
if(data192.uint64 !== undefined){
let data194 = data192.uint64;
const _errs536 = errors;
if(errors === _errs536){
if(typeof data194 === "string"){
if(func1(data194) > 131072){
const err548 = {instancePath:instancePath+"/compiled/plan/predicate/program/" + i15+"/atom/compare/value/uint64",schemaPath:"#/oneOf/4/properties/compiled/properties/plan/properties/predicate/oneOf/3/properties/program/items/oneOf/0/properties/atom/oneOf/2/properties/compare/properties/value/oneOf/1/properties/uint64/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err548];
}
else {
vErrors.push(err548);
}
errors++;
}
}
else {
const err549 = {instancePath:instancePath+"/compiled/plan/predicate/program/" + i15+"/atom/compare/value/uint64",schemaPath:"#/oneOf/4/properties/compiled/properties/plan/properties/predicate/oneOf/3/properties/program/items/oneOf/0/properties/atom/oneOf/2/properties/compare/properties/value/oneOf/1/properties/uint64/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err549];
}
else {
vErrors.push(err549);
}
errors++;
}
}
}
}
}
}
else {
const err550 = {instancePath:instancePath+"/compiled/plan/predicate/program/" + i15+"/atom/compare/value",schemaPath:"#/oneOf/4/properties/compiled/properties/plan/properties/predicate/oneOf/3/properties/program/items/oneOf/0/properties/atom/oneOf/2/properties/compare/properties/value/oneOf/1/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err550];
}
else {
vErrors.push(err550);
}
errors++;
}
}
var _valid14 = _errs533 === errors;
if(_valid14 && valid93){
valid93 = false;
passing7 = [passing7, 1];
}
else {
if(_valid14){
valid93 = true;
passing7 = 1;
if(props7 !== true){
props7 = true;
}
}
const _errs538 = errors;
if(errors === _errs538){
if(data192 && typeof data192 == "object" && !Array.isArray(data192)){
let missing65;
if((data192.float_bits === undefined) && (missing65 = "float_bits")){
const err551 = {instancePath:instancePath+"/compiled/plan/predicate/program/" + i15+"/atom/compare/value",schemaPath:"#/oneOf/4/properties/compiled/properties/plan/properties/predicate/oneOf/3/properties/program/items/oneOf/0/properties/atom/oneOf/2/properties/compare/properties/value/oneOf/2/required",keyword:"required",params:{missingProperty: missing65},message:"must have required property '"+missing65+"'"};
if(vErrors === null){
vErrors = [err551];
}
else {
vErrors.push(err551);
}
errors++;
}
else {
const _errs540 = errors;
for(const key65 in data192){
if(!(key65 === "float_bits")){
const err552 = {instancePath:instancePath+"/compiled/plan/predicate/program/" + i15+"/atom/compare/value",schemaPath:"#/oneOf/4/properties/compiled/properties/plan/properties/predicate/oneOf/3/properties/program/items/oneOf/0/properties/atom/oneOf/2/properties/compare/properties/value/oneOf/2/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key65},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err552];
}
else {
vErrors.push(err552);
}
errors++;
break;
}
}
if(_errs540 === errors){
if(data192.float_bits !== undefined){
let data195 = data192.float_bits;
const _errs541 = errors;
if(errors === _errs541){
if(typeof data195 === "string"){
if(func1(data195) > 131072){
const err553 = {instancePath:instancePath+"/compiled/plan/predicate/program/" + i15+"/atom/compare/value/float_bits",schemaPath:"#/oneOf/4/properties/compiled/properties/plan/properties/predicate/oneOf/3/properties/program/items/oneOf/0/properties/atom/oneOf/2/properties/compare/properties/value/oneOf/2/properties/float_bits/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err553];
}
else {
vErrors.push(err553);
}
errors++;
}
}
else {
const err554 = {instancePath:instancePath+"/compiled/plan/predicate/program/" + i15+"/atom/compare/value/float_bits",schemaPath:"#/oneOf/4/properties/compiled/properties/plan/properties/predicate/oneOf/3/properties/program/items/oneOf/0/properties/atom/oneOf/2/properties/compare/properties/value/oneOf/2/properties/float_bits/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err554];
}
else {
vErrors.push(err554);
}
errors++;
}
}
}
}
}
}
else {
const err555 = {instancePath:instancePath+"/compiled/plan/predicate/program/" + i15+"/atom/compare/value",schemaPath:"#/oneOf/4/properties/compiled/properties/plan/properties/predicate/oneOf/3/properties/program/items/oneOf/0/properties/atom/oneOf/2/properties/compare/properties/value/oneOf/2/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err555];
}
else {
vErrors.push(err555);
}
errors++;
}
}
var _valid14 = _errs538 === errors;
if(_valid14 && valid93){
valid93 = false;
passing7 = [passing7, 2];
}
else {
if(_valid14){
valid93 = true;
passing7 = 2;
if(props7 !== true){
props7 = true;
}
}
const _errs543 = errors;
if(errors === _errs543){
if(data192 && typeof data192 == "object" && !Array.isArray(data192)){
let missing66;
if((data192.boolean === undefined) && (missing66 = "boolean")){
const err556 = {instancePath:instancePath+"/compiled/plan/predicate/program/" + i15+"/atom/compare/value",schemaPath:"#/oneOf/4/properties/compiled/properties/plan/properties/predicate/oneOf/3/properties/program/items/oneOf/0/properties/atom/oneOf/2/properties/compare/properties/value/oneOf/3/required",keyword:"required",params:{missingProperty: missing66},message:"must have required property '"+missing66+"'"};
if(vErrors === null){
vErrors = [err556];
}
else {
vErrors.push(err556);
}
errors++;
}
else {
const _errs545 = errors;
for(const key66 in data192){
if(!(key66 === "boolean")){
const err557 = {instancePath:instancePath+"/compiled/plan/predicate/program/" + i15+"/atom/compare/value",schemaPath:"#/oneOf/4/properties/compiled/properties/plan/properties/predicate/oneOf/3/properties/program/items/oneOf/0/properties/atom/oneOf/2/properties/compare/properties/value/oneOf/3/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key66},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err557];
}
else {
vErrors.push(err557);
}
errors++;
break;
}
}
if(_errs545 === errors){
if(data192.boolean !== undefined){
if(typeof data192.boolean !== "boolean"){
const err558 = {instancePath:instancePath+"/compiled/plan/predicate/program/" + i15+"/atom/compare/value/boolean",schemaPath:"#/oneOf/4/properties/compiled/properties/plan/properties/predicate/oneOf/3/properties/program/items/oneOf/0/properties/atom/oneOf/2/properties/compare/properties/value/oneOf/3/properties/boolean/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"};
if(vErrors === null){
vErrors = [err558];
}
else {
vErrors.push(err558);
}
errors++;
}
}
}
}
}
else {
const err559 = {instancePath:instancePath+"/compiled/plan/predicate/program/" + i15+"/atom/compare/value",schemaPath:"#/oneOf/4/properties/compiled/properties/plan/properties/predicate/oneOf/3/properties/program/items/oneOf/0/properties/atom/oneOf/2/properties/compare/properties/value/oneOf/3/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err559];
}
else {
vErrors.push(err559);
}
errors++;
}
}
var _valid14 = _errs543 === errors;
if(_valid14 && valid93){
valid93 = false;
passing7 = [passing7, 3];
}
else {
if(_valid14){
valid93 = true;
passing7 = 3;
if(props7 !== true){
props7 = true;
}
}
const _errs548 = errors;
if(errors === _errs548){
if(data192 && typeof data192 == "object" && !Array.isArray(data192)){
let missing67;
if((data192.utf8 === undefined) && (missing67 = "utf8")){
const err560 = {instancePath:instancePath+"/compiled/plan/predicate/program/" + i15+"/atom/compare/value",schemaPath:"#/oneOf/4/properties/compiled/properties/plan/properties/predicate/oneOf/3/properties/program/items/oneOf/0/properties/atom/oneOf/2/properties/compare/properties/value/oneOf/4/required",keyword:"required",params:{missingProperty: missing67},message:"must have required property '"+missing67+"'"};
if(vErrors === null){
vErrors = [err560];
}
else {
vErrors.push(err560);
}
errors++;
}
else {
const _errs550 = errors;
for(const key67 in data192){
if(!(key67 === "utf8")){
const err561 = {instancePath:instancePath+"/compiled/plan/predicate/program/" + i15+"/atom/compare/value",schemaPath:"#/oneOf/4/properties/compiled/properties/plan/properties/predicate/oneOf/3/properties/program/items/oneOf/0/properties/atom/oneOf/2/properties/compare/properties/value/oneOf/4/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key67},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err561];
}
else {
vErrors.push(err561);
}
errors++;
break;
}
}
if(_errs550 === errors){
if(data192.utf8 !== undefined){
let data197 = data192.utf8;
const _errs551 = errors;
if(errors === _errs551){
if(typeof data197 === "string"){
if(func1(data197) > 131072){
const err562 = {instancePath:instancePath+"/compiled/plan/predicate/program/" + i15+"/atom/compare/value/utf8",schemaPath:"#/oneOf/4/properties/compiled/properties/plan/properties/predicate/oneOf/3/properties/program/items/oneOf/0/properties/atom/oneOf/2/properties/compare/properties/value/oneOf/4/properties/utf8/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err562];
}
else {
vErrors.push(err562);
}
errors++;
}
}
else {
const err563 = {instancePath:instancePath+"/compiled/plan/predicate/program/" + i15+"/atom/compare/value/utf8",schemaPath:"#/oneOf/4/properties/compiled/properties/plan/properties/predicate/oneOf/3/properties/program/items/oneOf/0/properties/atom/oneOf/2/properties/compare/properties/value/oneOf/4/properties/utf8/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err563];
}
else {
vErrors.push(err563);
}
errors++;
}
}
}
}
}
}
else {
const err564 = {instancePath:instancePath+"/compiled/plan/predicate/program/" + i15+"/atom/compare/value",schemaPath:"#/oneOf/4/properties/compiled/properties/plan/properties/predicate/oneOf/3/properties/program/items/oneOf/0/properties/atom/oneOf/2/properties/compare/properties/value/oneOf/4/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err564];
}
else {
vErrors.push(err564);
}
errors++;
}
}
var _valid14 = _errs548 === errors;
if(_valid14 && valid93){
valid93 = false;
passing7 = [passing7, 4];
}
else {
if(_valid14){
valid93 = true;
passing7 = 4;
if(props7 !== true){
props7 = true;
}
}
const _errs553 = errors;
if(errors === _errs553){
if(data192 && typeof data192 == "object" && !Array.isArray(data192)){
let missing68;
if((data192.binary === undefined) && (missing68 = "binary")){
const err565 = {instancePath:instancePath+"/compiled/plan/predicate/program/" + i15+"/atom/compare/value",schemaPath:"#/oneOf/4/properties/compiled/properties/plan/properties/predicate/oneOf/3/properties/program/items/oneOf/0/properties/atom/oneOf/2/properties/compare/properties/value/oneOf/5/required",keyword:"required",params:{missingProperty: missing68},message:"must have required property '"+missing68+"'"};
if(vErrors === null){
vErrors = [err565];
}
else {
vErrors.push(err565);
}
errors++;
}
else {
const _errs555 = errors;
for(const key68 in data192){
if(!(key68 === "binary")){
const err566 = {instancePath:instancePath+"/compiled/plan/predicate/program/" + i15+"/atom/compare/value",schemaPath:"#/oneOf/4/properties/compiled/properties/plan/properties/predicate/oneOf/3/properties/program/items/oneOf/0/properties/atom/oneOf/2/properties/compare/properties/value/oneOf/5/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key68},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err566];
}
else {
vErrors.push(err566);
}
errors++;
break;
}
}
if(_errs555 === errors){
if(data192.binary !== undefined){
let data198 = data192.binary;
const _errs556 = errors;
if(errors === _errs556){
if(typeof data198 === "string"){
if(func1(data198) > 131072){
const err567 = {instancePath:instancePath+"/compiled/plan/predicate/program/" + i15+"/atom/compare/value/binary",schemaPath:"#/oneOf/4/properties/compiled/properties/plan/properties/predicate/oneOf/3/properties/program/items/oneOf/0/properties/atom/oneOf/2/properties/compare/properties/value/oneOf/5/properties/binary/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err567];
}
else {
vErrors.push(err567);
}
errors++;
}
}
else {
const err568 = {instancePath:instancePath+"/compiled/plan/predicate/program/" + i15+"/atom/compare/value/binary",schemaPath:"#/oneOf/4/properties/compiled/properties/plan/properties/predicate/oneOf/3/properties/program/items/oneOf/0/properties/atom/oneOf/2/properties/compare/properties/value/oneOf/5/properties/binary/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err568];
}
else {
vErrors.push(err568);
}
errors++;
}
}
}
}
}
}
else {
const err569 = {instancePath:instancePath+"/compiled/plan/predicate/program/" + i15+"/atom/compare/value",schemaPath:"#/oneOf/4/properties/compiled/properties/plan/properties/predicate/oneOf/3/properties/program/items/oneOf/0/properties/atom/oneOf/2/properties/compare/properties/value/oneOf/5/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err569];
}
else {
vErrors.push(err569);
}
errors++;
}
}
var _valid14 = _errs553 === errors;
if(_valid14 && valid93){
valid93 = false;
passing7 = [passing7, 5];
}
else {
if(_valid14){
valid93 = true;
passing7 = 5;
if(props7 !== true){
props7 = true;
}
}
}
}
}
}
}
if(!valid93){
const err570 = {instancePath:instancePath+"/compiled/plan/predicate/program/" + i15+"/atom/compare/value",schemaPath:"#/oneOf/4/properties/compiled/properties/plan/properties/predicate/oneOf/3/properties/program/items/oneOf/0/properties/atom/oneOf/2/properties/compare/properties/value/oneOf",keyword:"oneOf",params:{passingSchemas: passing7},message:"must match exactly one schema in oneOf"};
if(vErrors === null){
vErrors = [err570];
}
else {
vErrors.push(err570);
}
errors++;
}
else {
errors = _errs527;
if(vErrors !== null){
if(_errs527){
vErrors.length = _errs527;
}
else {
vErrors = null;
}
}
}
var valid92 = _errs526 === errors;
}
else {
var valid92 = true;
}
}
}
}
}
}
else {
const err571 = {instancePath:instancePath+"/compiled/plan/predicate/program/" + i15+"/atom/compare",schemaPath:"#/oneOf/4/properties/compiled/properties/plan/properties/predicate/oneOf/3/properties/program/items/oneOf/0/properties/atom/oneOf/2/properties/compare/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err571];
}
else {
vErrors.push(err571);
}
errors++;
}
}
}
}
}
}
else {
const err572 = {instancePath:instancePath+"/compiled/plan/predicate/program/" + i15+"/atom",schemaPath:"#/oneOf/4/properties/compiled/properties/plan/properties/predicate/oneOf/3/properties/program/items/oneOf/0/properties/atom/oneOf/2/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err572];
}
else {
vErrors.push(err572);
}
errors++;
}
}
var _valid13 = _errs516 === errors;
if(_valid13 && valid87){
valid87 = false;
passing6 = [passing6, 2];
}
else {
if(_valid13){
valid87 = true;
passing6 = 2;
if(props6 !== true){
props6 = true;
}
}
}
}
if(!valid87){
const err573 = {instancePath:instancePath+"/compiled/plan/predicate/program/" + i15+"/atom",schemaPath:"#/oneOf/4/properties/compiled/properties/plan/properties/predicate/oneOf/3/properties/program/items/oneOf/0/properties/atom/oneOf",keyword:"oneOf",params:{passingSchemas: passing6},message:"must match exactly one schema in oneOf"};
if(vErrors === null){
vErrors = [err573];
}
else {
vErrors.push(err573);
}
errors++;
}
else {
errors = _errs500;
if(vErrors !== null){
if(_errs500){
vErrors.length = _errs500;
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
const err574 = {instancePath:instancePath+"/compiled/plan/predicate/program/" + i15,schemaPath:"#/oneOf/4/properties/compiled/properties/plan/properties/predicate/oneOf/3/properties/program/items/oneOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err574];
}
else {
vErrors.push(err574);
}
errors++;
}
}
var _valid12 = _errs496 === errors;
if(_valid12){
valid85 = true;
passing5 = 0;
var props8 = true;
}
const _errs558 = errors;
if(errors === _errs558){
if(data183 && typeof data183 == "object" && !Array.isArray(data183)){
let missing69;
if((data183.negate === undefined) && (missing69 = "negate")){
const err575 = {instancePath:instancePath+"/compiled/plan/predicate/program/" + i15,schemaPath:"#/oneOf/4/properties/compiled/properties/plan/properties/predicate/oneOf/3/properties/program/items/oneOf/1/required",keyword:"required",params:{missingProperty: missing69},message:"must have required property '"+missing69+"'"};
if(vErrors === null){
vErrors = [err575];
}
else {
vErrors.push(err575);
}
errors++;
}
else {
const _errs560 = errors;
for(const key69 in data183){
if(!(key69 === "negate")){
const err576 = {instancePath:instancePath+"/compiled/plan/predicate/program/" + i15,schemaPath:"#/oneOf/4/properties/compiled/properties/plan/properties/predicate/oneOf/3/properties/program/items/oneOf/1/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key69},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err576];
}
else {
vErrors.push(err576);
}
errors++;
break;
}
}
if(_errs560 === errors){
if(data183.negate !== undefined){
let data199 = data183.negate;
const _errs561 = errors;
if(errors === _errs561){
if(data199 && typeof data199 == "object" && !Array.isArray(data199)){
if(Object.keys(data199).length > 0){
const err577 = {instancePath:instancePath+"/compiled/plan/predicate/program/" + i15+"/negate",schemaPath:"#/oneOf/4/properties/compiled/properties/plan/properties/predicate/oneOf/3/properties/program/items/oneOf/1/properties/negate/maxProperties",keyword:"maxProperties",params:{limit: 0},message:"must NOT have more than 0 properties"};
if(vErrors === null){
vErrors = [err577];
}
else {
vErrors.push(err577);
}
errors++;
}
}
else {
const err578 = {instancePath:instancePath+"/compiled/plan/predicate/program/" + i15+"/negate",schemaPath:"#/oneOf/4/properties/compiled/properties/plan/properties/predicate/oneOf/3/properties/program/items/oneOf/1/properties/negate/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err578];
}
else {
vErrors.push(err578);
}
errors++;
}
}
}
}
}
}
else {
const err579 = {instancePath:instancePath+"/compiled/plan/predicate/program/" + i15,schemaPath:"#/oneOf/4/properties/compiled/properties/plan/properties/predicate/oneOf/3/properties/program/items/oneOf/1/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err579];
}
else {
vErrors.push(err579);
}
errors++;
}
}
var _valid12 = _errs558 === errors;
if(_valid12 && valid85){
valid85 = false;
passing5 = [passing5, 1];
}
else {
if(_valid12){
valid85 = true;
passing5 = 1;
if(props8 !== true){
props8 = true;
}
}
const _errs563 = errors;
if(errors === _errs563){
if(data183 && typeof data183 == "object" && !Array.isArray(data183)){
let missing70;
if((data183.conjunction === undefined) && (missing70 = "conjunction")){
const err580 = {instancePath:instancePath+"/compiled/plan/predicate/program/" + i15,schemaPath:"#/oneOf/4/properties/compiled/properties/plan/properties/predicate/oneOf/3/properties/program/items/oneOf/2/required",keyword:"required",params:{missingProperty: missing70},message:"must have required property '"+missing70+"'"};
if(vErrors === null){
vErrors = [err580];
}
else {
vErrors.push(err580);
}
errors++;
}
else {
const _errs565 = errors;
for(const key70 in data183){
if(!(key70 === "conjunction")){
const err581 = {instancePath:instancePath+"/compiled/plan/predicate/program/" + i15,schemaPath:"#/oneOf/4/properties/compiled/properties/plan/properties/predicate/oneOf/3/properties/program/items/oneOf/2/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key70},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err581];
}
else {
vErrors.push(err581);
}
errors++;
break;
}
}
if(_errs565 === errors){
if(data183.conjunction !== undefined){
let data200 = data183.conjunction;
const _errs566 = errors;
if(errors === _errs566){
if(data200 && typeof data200 == "object" && !Array.isArray(data200)){
if(Object.keys(data200).length > 0){
const err582 = {instancePath:instancePath+"/compiled/plan/predicate/program/" + i15+"/conjunction",schemaPath:"#/oneOf/4/properties/compiled/properties/plan/properties/predicate/oneOf/3/properties/program/items/oneOf/2/properties/conjunction/maxProperties",keyword:"maxProperties",params:{limit: 0},message:"must NOT have more than 0 properties"};
if(vErrors === null){
vErrors = [err582];
}
else {
vErrors.push(err582);
}
errors++;
}
}
else {
const err583 = {instancePath:instancePath+"/compiled/plan/predicate/program/" + i15+"/conjunction",schemaPath:"#/oneOf/4/properties/compiled/properties/plan/properties/predicate/oneOf/3/properties/program/items/oneOf/2/properties/conjunction/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err583];
}
else {
vErrors.push(err583);
}
errors++;
}
}
}
}
}
}
else {
const err584 = {instancePath:instancePath+"/compiled/plan/predicate/program/" + i15,schemaPath:"#/oneOf/4/properties/compiled/properties/plan/properties/predicate/oneOf/3/properties/program/items/oneOf/2/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err584];
}
else {
vErrors.push(err584);
}
errors++;
}
}
var _valid12 = _errs563 === errors;
if(_valid12 && valid85){
valid85 = false;
passing5 = [passing5, 2];
}
else {
if(_valid12){
valid85 = true;
passing5 = 2;
if(props8 !== true){
props8 = true;
}
}
const _errs568 = errors;
if(errors === _errs568){
if(data183 && typeof data183 == "object" && !Array.isArray(data183)){
let missing71;
if((data183.disjunction === undefined) && (missing71 = "disjunction")){
const err585 = {instancePath:instancePath+"/compiled/plan/predicate/program/" + i15,schemaPath:"#/oneOf/4/properties/compiled/properties/plan/properties/predicate/oneOf/3/properties/program/items/oneOf/3/required",keyword:"required",params:{missingProperty: missing71},message:"must have required property '"+missing71+"'"};
if(vErrors === null){
vErrors = [err585];
}
else {
vErrors.push(err585);
}
errors++;
}
else {
const _errs570 = errors;
for(const key71 in data183){
if(!(key71 === "disjunction")){
const err586 = {instancePath:instancePath+"/compiled/plan/predicate/program/" + i15,schemaPath:"#/oneOf/4/properties/compiled/properties/plan/properties/predicate/oneOf/3/properties/program/items/oneOf/3/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key71},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err586];
}
else {
vErrors.push(err586);
}
errors++;
break;
}
}
if(_errs570 === errors){
if(data183.disjunction !== undefined){
let data201 = data183.disjunction;
const _errs571 = errors;
if(errors === _errs571){
if(data201 && typeof data201 == "object" && !Array.isArray(data201)){
if(Object.keys(data201).length > 0){
const err587 = {instancePath:instancePath+"/compiled/plan/predicate/program/" + i15+"/disjunction",schemaPath:"#/oneOf/4/properties/compiled/properties/plan/properties/predicate/oneOf/3/properties/program/items/oneOf/3/properties/disjunction/maxProperties",keyword:"maxProperties",params:{limit: 0},message:"must NOT have more than 0 properties"};
if(vErrors === null){
vErrors = [err587];
}
else {
vErrors.push(err587);
}
errors++;
}
}
else {
const err588 = {instancePath:instancePath+"/compiled/plan/predicate/program/" + i15+"/disjunction",schemaPath:"#/oneOf/4/properties/compiled/properties/plan/properties/predicate/oneOf/3/properties/program/items/oneOf/3/properties/disjunction/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err588];
}
else {
vErrors.push(err588);
}
errors++;
}
}
}
}
}
}
else {
const err589 = {instancePath:instancePath+"/compiled/plan/predicate/program/" + i15,schemaPath:"#/oneOf/4/properties/compiled/properties/plan/properties/predicate/oneOf/3/properties/program/items/oneOf/3/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err589];
}
else {
vErrors.push(err589);
}
errors++;
}
}
var _valid12 = _errs568 === errors;
if(_valid12 && valid85){
valid85 = false;
passing5 = [passing5, 3];
}
else {
if(_valid12){
valid85 = true;
passing5 = 3;
if(props8 !== true){
props8 = true;
}
}
}
}
}
if(!valid85){
const err590 = {instancePath:instancePath+"/compiled/plan/predicate/program/" + i15,schemaPath:"#/oneOf/4/properties/compiled/properties/plan/properties/predicate/oneOf/3/properties/program/items/oneOf",keyword:"oneOf",params:{passingSchemas: passing5},message:"must match exactly one schema in oneOf"};
if(vErrors === null){
vErrors = [err590];
}
else {
vErrors.push(err590);
}
errors++;
}
else {
errors = _errs495;
if(vErrors !== null){
if(_errs495){
vErrors.length = _errs495;
}
else {
vErrors = null;
}
}
}
var valid84 = _errs494 === errors;
if(!valid84){
break;
}
}
}
}
else {
const err591 = {instancePath:instancePath+"/compiled/plan/predicate/program",schemaPath:"#/oneOf/4/properties/compiled/properties/plan/properties/predicate/oneOf/3/properties/program/type",keyword:"type",params:{type: "array"},message:"must be array"};
if(vErrors === null){
vErrors = [err591];
}
else {
vErrors.push(err591);
}
errors++;
}
}
}
}
}
}
else {
const err592 = {instancePath:instancePath+"/compiled/plan/predicate",schemaPath:"#/oneOf/4/properties/compiled/properties/plan/properties/predicate/oneOf/3/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err592];
}
else {
vErrors.push(err592);
}
errors++;
}
}
var _valid10 = _errs489 === errors;
if(_valid10 && valid70){
valid70 = false;
passing3 = [passing3, 3];
}
else {
if(_valid10){
valid70 = true;
passing3 = 3;
if(props4 !== true){
props4 = true;
}
}
}
}
}
if(!valid70){
const err593 = {instancePath:instancePath+"/compiled/plan/predicate",schemaPath:"#/oneOf/4/properties/compiled/properties/plan/properties/predicate/oneOf",keyword:"oneOf",params:{passingSchemas: passing3},message:"must match exactly one schema in oneOf"};
if(vErrors === null){
vErrors = [err593];
}
else {
vErrors.push(err593);
}
errors++;
}
else {
errors = _errs431;
if(vErrors !== null){
if(_errs431){
vErrors.length = _errs431;
}
else {
vErrors = null;
}
}
}
var valid64 = _errs430 === errors;
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
const err594 = {instancePath:instancePath+"/compiled/plan",schemaPath:"#/oneOf/4/properties/compiled/properties/plan/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err594];
}
else {
vErrors.push(err594);
}
errors++;
}
}
var valid45 = _errs401 === errors;
}
else {
var valid45 = true;
}
if(valid45){
if(data119.limits !== undefined){
let data202 = data119.limits;
const _errs573 = errors;
if(errors === _errs573){
if(data202 && typeof data202 == "object" && !Array.isArray(data202)){
let missing72;
if((((data202.pages === undefined) && (missing72 = "pages")) || ((data202.segments === undefined) && (missing72 = "segments"))) || ((data202.result_bytes === undefined) && (missing72 = "result_bytes"))){
const err595 = {instancePath:instancePath+"/compiled/limits",schemaPath:"#/oneOf/4/properties/compiled/properties/limits/required",keyword:"required",params:{missingProperty: missing72},message:"must have required property '"+missing72+"'"};
if(vErrors === null){
vErrors = [err595];
}
else {
vErrors.push(err595);
}
errors++;
}
else {
const _errs575 = errors;
for(const key72 in data202){
if(!(((key72 === "pages") || (key72 === "segments")) || (key72 === "result_bytes"))){
const err596 = {instancePath:instancePath+"/compiled/limits",schemaPath:"#/oneOf/4/properties/compiled/properties/limits/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key72},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err596];
}
else {
vErrors.push(err596);
}
errors++;
break;
}
}
if(_errs575 === errors){
if(data202.pages !== undefined){
let data203 = data202.pages;
const _errs576 = errors;
if(errors === _errs576){
if(typeof data203 === "string"){
if(func1(data203) > 131072){
const err597 = {instancePath:instancePath+"/compiled/limits/pages",schemaPath:"#/oneOf/4/properties/compiled/properties/limits/properties/pages/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err597];
}
else {
vErrors.push(err597);
}
errors++;
}
}
else {
const err598 = {instancePath:instancePath+"/compiled/limits/pages",schemaPath:"#/oneOf/4/properties/compiled/properties/limits/properties/pages/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err598];
}
else {
vErrors.push(err598);
}
errors++;
}
}
var valid103 = _errs576 === errors;
}
else {
var valid103 = true;
}
if(valid103){
if(data202.segments !== undefined){
let data204 = data202.segments;
const _errs578 = errors;
if(errors === _errs578){
if(typeof data204 === "string"){
if(func1(data204) > 131072){
const err599 = {instancePath:instancePath+"/compiled/limits/segments",schemaPath:"#/oneOf/4/properties/compiled/properties/limits/properties/segments/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err599];
}
else {
vErrors.push(err599);
}
errors++;
}
}
else {
const err600 = {instancePath:instancePath+"/compiled/limits/segments",schemaPath:"#/oneOf/4/properties/compiled/properties/limits/properties/segments/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err600];
}
else {
vErrors.push(err600);
}
errors++;
}
}
var valid103 = _errs578 === errors;
}
else {
var valid103 = true;
}
if(valid103){
if(data202.result_bytes !== undefined){
let data205 = data202.result_bytes;
const _errs580 = errors;
if(errors === _errs580){
if(typeof data205 === "string"){
if(func1(data205) > 131072){
const err601 = {instancePath:instancePath+"/compiled/limits/result_bytes",schemaPath:"#/oneOf/4/properties/compiled/properties/limits/properties/result_bytes/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err601];
}
else {
vErrors.push(err601);
}
errors++;
}
}
else {
const err602 = {instancePath:instancePath+"/compiled/limits/result_bytes",schemaPath:"#/oneOf/4/properties/compiled/properties/limits/properties/result_bytes/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err602];
}
else {
vErrors.push(err602);
}
errors++;
}
}
var valid103 = _errs580 === errors;
}
else {
var valid103 = true;
}
}
}
}
}
}
else {
const err603 = {instancePath:instancePath+"/compiled/limits",schemaPath:"#/oneOf/4/properties/compiled/properties/limits/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err603];
}
else {
vErrors.push(err603);
}
errors++;
}
}
var valid45 = _errs573 === errors;
}
else {
var valid45 = true;
}
if(valid45){
if(data119.contract !== undefined){
let data206 = data119.contract;
const _errs582 = errors;
if(errors === _errs582){
if(Array.isArray(data206)){
if(data206.length > 32){
const err604 = {instancePath:instancePath+"/compiled/contract",schemaPath:"#/oneOf/4/properties/compiled/properties/contract/maxItems",keyword:"maxItems",params:{limit: 32},message:"must NOT have more than 32 items"};
if(vErrors === null){
vErrors = [err604];
}
else {
vErrors.push(err604);
}
errors++;
}
else {
if(data206.length < 32){
const err605 = {instancePath:instancePath+"/compiled/contract",schemaPath:"#/oneOf/4/properties/compiled/properties/contract/minItems",keyword:"minItems",params:{limit: 32},message:"must NOT have fewer than 32 items"};
if(vErrors === null){
vErrors = [err605];
}
else {
vErrors.push(err605);
}
errors++;
}
else {
var valid104 = true;
const len16 = data206.length;
for(let i16=0; i16<len16; i16++){
let data207 = data206[i16];
const _errs584 = errors;
if(!(((typeof data207 == "number") && (!(data207 % 1) && !isNaN(data207))) && (isFinite(data207)))){
const err606 = {instancePath:instancePath+"/compiled/contract/" + i16,schemaPath:"#/oneOf/4/properties/compiled/properties/contract/items/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err606];
}
else {
vErrors.push(err606);
}
errors++;
}
if(errors === _errs584){
if((typeof data207 == "number") && (isFinite(data207))){
if(data207 > 255 || isNaN(data207)){
const err607 = {instancePath:instancePath+"/compiled/contract/" + i16,schemaPath:"#/oneOf/4/properties/compiled/properties/contract/items/maximum",keyword:"maximum",params:{comparison: "<=", limit: 255},message:"must be <= 255"};
if(vErrors === null){
vErrors = [err607];
}
else {
vErrors.push(err607);
}
errors++;
}
else {
if(data207 < 0 || isNaN(data207)){
const err608 = {instancePath:instancePath+"/compiled/contract/" + i16,schemaPath:"#/oneOf/4/properties/compiled/properties/contract/items/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err608];
}
else {
vErrors.push(err608);
}
errors++;
}
}
}
}
var valid104 = _errs584 === errors;
if(!valid104){
break;
}
}
}
}
}
else {
const err609 = {instancePath:instancePath+"/compiled/contract",schemaPath:"#/oneOf/4/properties/compiled/properties/contract/type",keyword:"type",params:{type: "array"},message:"must be array"};
if(vErrors === null){
vErrors = [err609];
}
else {
vErrors.push(err609);
}
errors++;
}
}
var valid45 = _errs582 === errors;
}
else {
var valid45 = true;
}
if(valid45){
if(data119.schema !== undefined){
let data208 = data119.schema;
const _errs586 = errors;
if(errors === _errs586){
if(Array.isArray(data208)){
if(data208.length > 32){
const err610 = {instancePath:instancePath+"/compiled/schema",schemaPath:"#/oneOf/4/properties/compiled/properties/schema/maxItems",keyword:"maxItems",params:{limit: 32},message:"must NOT have more than 32 items"};
if(vErrors === null){
vErrors = [err610];
}
else {
vErrors.push(err610);
}
errors++;
}
else {
if(data208.length < 32){
const err611 = {instancePath:instancePath+"/compiled/schema",schemaPath:"#/oneOf/4/properties/compiled/properties/schema/minItems",keyword:"minItems",params:{limit: 32},message:"must NOT have fewer than 32 items"};
if(vErrors === null){
vErrors = [err611];
}
else {
vErrors.push(err611);
}
errors++;
}
else {
var valid105 = true;
const len17 = data208.length;
for(let i17=0; i17<len17; i17++){
let data209 = data208[i17];
const _errs588 = errors;
if(!(((typeof data209 == "number") && (!(data209 % 1) && !isNaN(data209))) && (isFinite(data209)))){
const err612 = {instancePath:instancePath+"/compiled/schema/" + i17,schemaPath:"#/oneOf/4/properties/compiled/properties/schema/items/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err612];
}
else {
vErrors.push(err612);
}
errors++;
}
if(errors === _errs588){
if((typeof data209 == "number") && (isFinite(data209))){
if(data209 > 255 || isNaN(data209)){
const err613 = {instancePath:instancePath+"/compiled/schema/" + i17,schemaPath:"#/oneOf/4/properties/compiled/properties/schema/items/maximum",keyword:"maximum",params:{comparison: "<=", limit: 255},message:"must be <= 255"};
if(vErrors === null){
vErrors = [err613];
}
else {
vErrors.push(err613);
}
errors++;
}
else {
if(data209 < 0 || isNaN(data209)){
const err614 = {instancePath:instancePath+"/compiled/schema/" + i17,schemaPath:"#/oneOf/4/properties/compiled/properties/schema/items/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err614];
}
else {
vErrors.push(err614);
}
errors++;
}
}
}
}
var valid105 = _errs588 === errors;
if(!valid105){
break;
}
}
}
}
}
else {
const err615 = {instancePath:instancePath+"/compiled/schema",schemaPath:"#/oneOf/4/properties/compiled/properties/schema/type",keyword:"type",params:{type: "array"},message:"must be array"};
if(vErrors === null){
vErrors = [err615];
}
else {
vErrors.push(err615);
}
errors++;
}
}
var valid45 = _errs586 === errors;
}
else {
var valid45 = true;
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
const err616 = {instancePath:instancePath+"/compiled",schemaPath:"#/oneOf/4/properties/compiled/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err616];
}
else {
vErrors.push(err616);
}
errors++;
}
}
}
}
}
}
else {
const err617 = {instancePath,schemaPath:"#/oneOf/4/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err617];
}
else {
vErrors.push(err617);
}
errors++;
}
}
var _valid0 = _errs295 === errors;
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
const _errs590 = errors;
if(errors === _errs590){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing73;
if((data.inspection === undefined) && (missing73 = "inspection")){
const err618 = {instancePath,schemaPath:"#/oneOf/5/required",keyword:"required",params:{missingProperty: missing73},message:"must have required property '"+missing73+"'"};
if(vErrors === null){
vErrors = [err618];
}
else {
vErrors.push(err618);
}
errors++;
}
else {
const _errs592 = errors;
for(const key73 in data){
if(!(key73 === "inspection")){
const err619 = {instancePath,schemaPath:"#/oneOf/5/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key73},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err619];
}
else {
vErrors.push(err619);
}
errors++;
break;
}
}
if(_errs592 === errors){
if(data.inspection !== undefined){
let data210 = data.inspection;
const _errs593 = errors;
if(errors === _errs593){
if(data210 && typeof data210 == "object" && !Array.isArray(data210)){
let missing74;
if(((((((((((data210.version === undefined) && (missing74 = "version")) || ((data210.scope === undefined) && (missing74 = "scope"))) || ((data210.name === undefined) && (missing74 = "name"))) || ((data210.resource === undefined) && (missing74 = "resource"))) || ((data210.source_kind === undefined) && (missing74 = "source_kind"))) || ((data210.contract === undefined) && (missing74 = "contract"))) || ((data210.schema === undefined) && (missing74 = "schema"))) || ((data210.resource_revision === undefined) && (missing74 = "resource_revision"))) || ((data210.policy_revision === undefined) && (missing74 = "policy_revision"))) || ((data210.details === undefined) && (missing74 = "details"))){
const err620 = {instancePath:instancePath+"/inspection",schemaPath:"#/oneOf/5/properties/inspection/required",keyword:"required",params:{missingProperty: missing74},message:"must have required property '"+missing74+"'"};
if(vErrors === null){
vErrors = [err620];
}
else {
vErrors.push(err620);
}
errors++;
}
else {
const _errs595 = errors;
for(const key74 in data210){
if(!(func24.call(schema33.oneOf[5].properties.inspection.properties, key74))){
const err621 = {instancePath:instancePath+"/inspection",schemaPath:"#/oneOf/5/properties/inspection/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key74},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err621];
}
else {
vErrors.push(err621);
}
errors++;
break;
}
}
if(_errs595 === errors){
if(data210.version !== undefined){
let data211 = data210.version;
const _errs596 = errors;
if(!(((typeof data211 == "number") && (!(data211 % 1) && !isNaN(data211))) && (isFinite(data211)))){
const err622 = {instancePath:instancePath+"/inspection/version",schemaPath:"#/oneOf/5/properties/inspection/properties/version/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err622];
}
else {
vErrors.push(err622);
}
errors++;
}
if(errors === _errs596){
if((typeof data211 == "number") && (isFinite(data211))){
if(data211 > 255 || isNaN(data211)){
const err623 = {instancePath:instancePath+"/inspection/version",schemaPath:"#/oneOf/5/properties/inspection/properties/version/maximum",keyword:"maximum",params:{comparison: "<=", limit: 255},message:"must be <= 255"};
if(vErrors === null){
vErrors = [err623];
}
else {
vErrors.push(err623);
}
errors++;
}
else {
if(data211 < 0 || isNaN(data211)){
const err624 = {instancePath:instancePath+"/inspection/version",schemaPath:"#/oneOf/5/properties/inspection/properties/version/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err624];
}
else {
vErrors.push(err624);
}
errors++;
}
}
}
}
var valid107 = _errs596 === errors;
}
else {
var valid107 = true;
}
if(valid107){
if(data210.scope !== undefined){
let data212 = data210.scope;
const _errs598 = errors;
if(typeof data212 !== "string"){
const err625 = {instancePath:instancePath+"/inspection/scope",schemaPath:"#/oneOf/5/properties/inspection/properties/scope/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err625];
}
else {
vErrors.push(err625);
}
errors++;
}
if(!(data212 === "configured_source")){
const err626 = {instancePath:instancePath+"/inspection/scope",schemaPath:"#/oneOf/5/properties/inspection/properties/scope/enum",keyword:"enum",params:{allowedValues: schema33.oneOf[5].properties.inspection.properties.scope.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err626];
}
else {
vErrors.push(err626);
}
errors++;
}
var valid107 = _errs598 === errors;
}
else {
var valid107 = true;
}
if(valid107){
if(data210.name !== undefined){
let data213 = data210.name;
const _errs600 = errors;
if(errors === _errs600){
if(typeof data213 === "string"){
if(func1(data213) > 131072){
const err627 = {instancePath:instancePath+"/inspection/name",schemaPath:"#/oneOf/5/properties/inspection/properties/name/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err627];
}
else {
vErrors.push(err627);
}
errors++;
}
}
else {
const err628 = {instancePath:instancePath+"/inspection/name",schemaPath:"#/oneOf/5/properties/inspection/properties/name/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err628];
}
else {
vErrors.push(err628);
}
errors++;
}
}
var valid107 = _errs600 === errors;
}
else {
var valid107 = true;
}
if(valid107){
if(data210.resource !== undefined){
let data214 = data210.resource;
const _errs602 = errors;
if(!(((typeof data214 == "number") && (!(data214 % 1) && !isNaN(data214))) && (isFinite(data214)))){
const err629 = {instancePath:instancePath+"/inspection/resource",schemaPath:"#/oneOf/5/properties/inspection/properties/resource/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err629];
}
else {
vErrors.push(err629);
}
errors++;
}
if(errors === _errs602){
if((typeof data214 == "number") && (isFinite(data214))){
if(data214 > 9007199254740991 || isNaN(data214)){
const err630 = {instancePath:instancePath+"/inspection/resource",schemaPath:"#/oneOf/5/properties/inspection/properties/resource/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"};
if(vErrors === null){
vErrors = [err630];
}
else {
vErrors.push(err630);
}
errors++;
}
else {
if(data214 < 0 || isNaN(data214)){
const err631 = {instancePath:instancePath+"/inspection/resource",schemaPath:"#/oneOf/5/properties/inspection/properties/resource/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err631];
}
else {
vErrors.push(err631);
}
errors++;
}
}
}
}
var valid107 = _errs602 === errors;
}
else {
var valid107 = true;
}
if(valid107){
if(data210.source_kind !== undefined){
let data215 = data210.source_kind;
const _errs604 = errors;
if(typeof data215 !== "string"){
const err632 = {instancePath:instancePath+"/inspection/source_kind",schemaPath:"#/oneOf/5/properties/inspection/properties/source_kind/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err632];
}
else {
vErrors.push(err632);
}
errors++;
}
if(!(((data215 === "kv") || (data215 === "table")) || (data215 === "document"))){
const err633 = {instancePath:instancePath+"/inspection/source_kind",schemaPath:"#/oneOf/5/properties/inspection/properties/source_kind/enum",keyword:"enum",params:{allowedValues: schema33.oneOf[5].properties.inspection.properties.source_kind.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err633];
}
else {
vErrors.push(err633);
}
errors++;
}
var valid107 = _errs604 === errors;
}
else {
var valid107 = true;
}
if(valid107){
if(data210.contract !== undefined){
let data216 = data210.contract;
const _errs606 = errors;
if(errors === _errs606){
if(Array.isArray(data216)){
if(data216.length > 32){
const err634 = {instancePath:instancePath+"/inspection/contract",schemaPath:"#/oneOf/5/properties/inspection/properties/contract/maxItems",keyword:"maxItems",params:{limit: 32},message:"must NOT have more than 32 items"};
if(vErrors === null){
vErrors = [err634];
}
else {
vErrors.push(err634);
}
errors++;
}
else {
if(data216.length < 32){
const err635 = {instancePath:instancePath+"/inspection/contract",schemaPath:"#/oneOf/5/properties/inspection/properties/contract/minItems",keyword:"minItems",params:{limit: 32},message:"must NOT have fewer than 32 items"};
if(vErrors === null){
vErrors = [err635];
}
else {
vErrors.push(err635);
}
errors++;
}
else {
var valid108 = true;
const len18 = data216.length;
for(let i18=0; i18<len18; i18++){
let data217 = data216[i18];
const _errs608 = errors;
if(!(((typeof data217 == "number") && (!(data217 % 1) && !isNaN(data217))) && (isFinite(data217)))){
const err636 = {instancePath:instancePath+"/inspection/contract/" + i18,schemaPath:"#/oneOf/5/properties/inspection/properties/contract/items/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err636];
}
else {
vErrors.push(err636);
}
errors++;
}
if(errors === _errs608){
if((typeof data217 == "number") && (isFinite(data217))){
if(data217 > 255 || isNaN(data217)){
const err637 = {instancePath:instancePath+"/inspection/contract/" + i18,schemaPath:"#/oneOf/5/properties/inspection/properties/contract/items/maximum",keyword:"maximum",params:{comparison: "<=", limit: 255},message:"must be <= 255"};
if(vErrors === null){
vErrors = [err637];
}
else {
vErrors.push(err637);
}
errors++;
}
else {
if(data217 < 0 || isNaN(data217)){
const err638 = {instancePath:instancePath+"/inspection/contract/" + i18,schemaPath:"#/oneOf/5/properties/inspection/properties/contract/items/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err638];
}
else {
vErrors.push(err638);
}
errors++;
}
}
}
}
var valid108 = _errs608 === errors;
if(!valid108){
break;
}
}
}
}
}
else {
const err639 = {instancePath:instancePath+"/inspection/contract",schemaPath:"#/oneOf/5/properties/inspection/properties/contract/type",keyword:"type",params:{type: "array"},message:"must be array"};
if(vErrors === null){
vErrors = [err639];
}
else {
vErrors.push(err639);
}
errors++;
}
}
var valid107 = _errs606 === errors;
}
else {
var valid107 = true;
}
if(valid107){
if(data210.schema !== undefined){
let data218 = data210.schema;
const _errs610 = errors;
if(errors === _errs610){
if(Array.isArray(data218)){
if(data218.length > 32){
const err640 = {instancePath:instancePath+"/inspection/schema",schemaPath:"#/oneOf/5/properties/inspection/properties/schema/maxItems",keyword:"maxItems",params:{limit: 32},message:"must NOT have more than 32 items"};
if(vErrors === null){
vErrors = [err640];
}
else {
vErrors.push(err640);
}
errors++;
}
else {
if(data218.length < 32){
const err641 = {instancePath:instancePath+"/inspection/schema",schemaPath:"#/oneOf/5/properties/inspection/properties/schema/minItems",keyword:"minItems",params:{limit: 32},message:"must NOT have fewer than 32 items"};
if(vErrors === null){
vErrors = [err641];
}
else {
vErrors.push(err641);
}
errors++;
}
else {
var valid109 = true;
const len19 = data218.length;
for(let i19=0; i19<len19; i19++){
let data219 = data218[i19];
const _errs612 = errors;
if(!(((typeof data219 == "number") && (!(data219 % 1) && !isNaN(data219))) && (isFinite(data219)))){
const err642 = {instancePath:instancePath+"/inspection/schema/" + i19,schemaPath:"#/oneOf/5/properties/inspection/properties/schema/items/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err642];
}
else {
vErrors.push(err642);
}
errors++;
}
if(errors === _errs612){
if((typeof data219 == "number") && (isFinite(data219))){
if(data219 > 255 || isNaN(data219)){
const err643 = {instancePath:instancePath+"/inspection/schema/" + i19,schemaPath:"#/oneOf/5/properties/inspection/properties/schema/items/maximum",keyword:"maximum",params:{comparison: "<=", limit: 255},message:"must be <= 255"};
if(vErrors === null){
vErrors = [err643];
}
else {
vErrors.push(err643);
}
errors++;
}
else {
if(data219 < 0 || isNaN(data219)){
const err644 = {instancePath:instancePath+"/inspection/schema/" + i19,schemaPath:"#/oneOf/5/properties/inspection/properties/schema/items/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err644];
}
else {
vErrors.push(err644);
}
errors++;
}
}
}
}
var valid109 = _errs612 === errors;
if(!valid109){
break;
}
}
}
}
}
else {
const err645 = {instancePath:instancePath+"/inspection/schema",schemaPath:"#/oneOf/5/properties/inspection/properties/schema/type",keyword:"type",params:{type: "array"},message:"must be array"};
if(vErrors === null){
vErrors = [err645];
}
else {
vErrors.push(err645);
}
errors++;
}
}
var valid107 = _errs610 === errors;
}
else {
var valid107 = true;
}
if(valid107){
if(data210.resource_revision !== undefined){
let data220 = data210.resource_revision;
const _errs614 = errors;
if(!(((typeof data220 == "number") && (!(data220 % 1) && !isNaN(data220))) && (isFinite(data220)))){
const err646 = {instancePath:instancePath+"/inspection/resource_revision",schemaPath:"#/oneOf/5/properties/inspection/properties/resource_revision/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err646];
}
else {
vErrors.push(err646);
}
errors++;
}
if(errors === _errs614){
if((typeof data220 == "number") && (isFinite(data220))){
if(data220 > 9007199254740991 || isNaN(data220)){
const err647 = {instancePath:instancePath+"/inspection/resource_revision",schemaPath:"#/oneOf/5/properties/inspection/properties/resource_revision/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"};
if(vErrors === null){
vErrors = [err647];
}
else {
vErrors.push(err647);
}
errors++;
}
else {
if(data220 < 0 || isNaN(data220)){
const err648 = {instancePath:instancePath+"/inspection/resource_revision",schemaPath:"#/oneOf/5/properties/inspection/properties/resource_revision/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err648];
}
else {
vErrors.push(err648);
}
errors++;
}
}
}
}
var valid107 = _errs614 === errors;
}
else {
var valid107 = true;
}
if(valid107){
if(data210.policy_revision !== undefined){
let data221 = data210.policy_revision;
const _errs616 = errors;
if(errors === _errs616){
if(typeof data221 === "string"){
if(func1(data221) > 131072){
const err649 = {instancePath:instancePath+"/inspection/policy_revision",schemaPath:"#/oneOf/5/properties/inspection/properties/policy_revision/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err649];
}
else {
vErrors.push(err649);
}
errors++;
}
}
else {
const err650 = {instancePath:instancePath+"/inspection/policy_revision",schemaPath:"#/oneOf/5/properties/inspection/properties/policy_revision/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err650];
}
else {
vErrors.push(err650);
}
errors++;
}
}
var valid107 = _errs616 === errors;
}
else {
var valid107 = true;
}
if(valid107){
if(data210.details !== undefined){
let data222 = data210.details;
const _errs618 = errors;
const _errs619 = errors;
let valid110 = false;
let passing8 = null;
const _errs620 = errors;
if(errors === _errs620){
if(data222 && typeof data222 == "object" && !Array.isArray(data222)){
let missing75;
if((data222.description === undefined) && (missing75 = "description")){
const err651 = {instancePath:instancePath+"/inspection/details",schemaPath:"#/oneOf/5/properties/inspection/properties/details/oneOf/0/required",keyword:"required",params:{missingProperty: missing75},message:"must have required property '"+missing75+"'"};
if(vErrors === null){
vErrors = [err651];
}
else {
vErrors.push(err651);
}
errors++;
}
else {
const _errs622 = errors;
for(const key75 in data222){
if(!(key75 === "description")){
const err652 = {instancePath:instancePath+"/inspection/details",schemaPath:"#/oneOf/5/properties/inspection/properties/details/oneOf/0/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key75},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err652];
}
else {
vErrors.push(err652);
}
errors++;
break;
}
}
if(_errs622 === errors){
if(data222.description !== undefined){
let data223 = data222.description;
const _errs623 = errors;
if(errors === _errs623){
if(data223 && typeof data223 == "object" && !Array.isArray(data223)){
let missing76;
if((data223.columns === undefined) && (missing76 = "columns")){
const err653 = {instancePath:instancePath+"/inspection/details/description",schemaPath:"#/oneOf/5/properties/inspection/properties/details/oneOf/0/properties/description/required",keyword:"required",params:{missingProperty: missing76},message:"must have required property '"+missing76+"'"};
if(vErrors === null){
vErrors = [err653];
}
else {
vErrors.push(err653);
}
errors++;
}
else {
const _errs625 = errors;
for(const key76 in data223){
if(!(key76 === "columns")){
const err654 = {instancePath:instancePath+"/inspection/details/description",schemaPath:"#/oneOf/5/properties/inspection/properties/details/oneOf/0/properties/description/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key76},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err654];
}
else {
vErrors.push(err654);
}
errors++;
break;
}
}
if(_errs625 === errors){
if(data223.columns !== undefined){
let data224 = data223.columns;
const _errs626 = errors;
if(errors === _errs626){
if(Array.isArray(data224)){
if(data224.length > 8){
const err655 = {instancePath:instancePath+"/inspection/details/description/columns",schemaPath:"#/oneOf/5/properties/inspection/properties/details/oneOf/0/properties/description/properties/columns/maxItems",keyword:"maxItems",params:{limit: 8},message:"must NOT have more than 8 items"};
if(vErrors === null){
vErrors = [err655];
}
else {
vErrors.push(err655);
}
errors++;
}
else {
var valid113 = true;
const len20 = data224.length;
for(let i20=0; i20<len20; i20++){
let data225 = data224[i20];
const _errs628 = errors;
if(errors === _errs628){
if(data225 && typeof data225 == "object" && !Array.isArray(data225)){
let missing77;
if(((data225.name === undefined) && (missing77 = "name")) || ((data225.type === undefined) && (missing77 = "type"))){
const err656 = {instancePath:instancePath+"/inspection/details/description/columns/" + i20,schemaPath:"#/oneOf/5/properties/inspection/properties/details/oneOf/0/properties/description/properties/columns/items/required",keyword:"required",params:{missingProperty: missing77},message:"must have required property '"+missing77+"'"};
if(vErrors === null){
vErrors = [err656];
}
else {
vErrors.push(err656);
}
errors++;
}
else {
const _errs630 = errors;
for(const key77 in data225){
if(!((key77 === "name") || (key77 === "type"))){
const err657 = {instancePath:instancePath+"/inspection/details/description/columns/" + i20,schemaPath:"#/oneOf/5/properties/inspection/properties/details/oneOf/0/properties/description/properties/columns/items/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key77},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err657];
}
else {
vErrors.push(err657);
}
errors++;
break;
}
}
if(_errs630 === errors){
if(data225.name !== undefined){
let data226 = data225.name;
const _errs631 = errors;
if(errors === _errs631){
if(typeof data226 === "string"){
if(func1(data226) > 131072){
const err658 = {instancePath:instancePath+"/inspection/details/description/columns/" + i20+"/name",schemaPath:"#/oneOf/5/properties/inspection/properties/details/oneOf/0/properties/description/properties/columns/items/properties/name/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err658];
}
else {
vErrors.push(err658);
}
errors++;
}
}
else {
const err659 = {instancePath:instancePath+"/inspection/details/description/columns/" + i20+"/name",schemaPath:"#/oneOf/5/properties/inspection/properties/details/oneOf/0/properties/description/properties/columns/items/properties/name/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err659];
}
else {
vErrors.push(err659);
}
errors++;
}
}
var valid114 = _errs631 === errors;
}
else {
var valid114 = true;
}
if(valid114){
if(data225.type !== undefined){
let data227 = data225.type;
const _errs633 = errors;
if(typeof data227 !== "string"){
const err660 = {instancePath:instancePath+"/inspection/details/description/columns/" + i20+"/type",schemaPath:"#/oneOf/5/properties/inspection/properties/details/oneOf/0/properties/description/properties/columns/items/properties/type/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err660];
}
else {
vErrors.push(err660);
}
errors++;
}
if(!((((((data227 === "int64") || (data227 === "uint64")) || (data227 === "float64")) || (data227 === "boolean")) || (data227 === "utf8")) || (data227 === "binary"))){
const err661 = {instancePath:instancePath+"/inspection/details/description/columns/" + i20+"/type",schemaPath:"#/oneOf/5/properties/inspection/properties/details/oneOf/0/properties/description/properties/columns/items/properties/type/enum",keyword:"enum",params:{allowedValues: schema33.oneOf[5].properties.inspection.properties.details.oneOf[0].properties.description.properties.columns.items.properties.type.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err661];
}
else {
vErrors.push(err661);
}
errors++;
}
var valid114 = _errs633 === errors;
}
else {
var valid114 = true;
}
}
}
}
}
else {
const err662 = {instancePath:instancePath+"/inspection/details/description/columns/" + i20,schemaPath:"#/oneOf/5/properties/inspection/properties/details/oneOf/0/properties/description/properties/columns/items/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err662];
}
else {
vErrors.push(err662);
}
errors++;
}
}
var valid113 = _errs628 === errors;
if(!valid113){
break;
}
}
}
}
else {
const err663 = {instancePath:instancePath+"/inspection/details/description/columns",schemaPath:"#/oneOf/5/properties/inspection/properties/details/oneOf/0/properties/description/properties/columns/type",keyword:"type",params:{type: "array"},message:"must be array"};
if(vErrors === null){
vErrors = [err663];
}
else {
vErrors.push(err663);
}
errors++;
}
}
}
}
}
}
else {
const err664 = {instancePath:instancePath+"/inspection/details/description",schemaPath:"#/oneOf/5/properties/inspection/properties/details/oneOf/0/properties/description/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err664];
}
else {
vErrors.push(err664);
}
errors++;
}
}
}
}
}
}
else {
const err665 = {instancePath:instancePath+"/inspection/details",schemaPath:"#/oneOf/5/properties/inspection/properties/details/oneOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err665];
}
else {
vErrors.push(err665);
}
errors++;
}
}
var _valid15 = _errs620 === errors;
if(_valid15){
valid110 = true;
passing8 = 0;
var props9 = true;
}
const _errs635 = errors;
if(errors === _errs635){
if(data222 && typeof data222 == "object" && !Array.isArray(data222)){
let missing78;
if((data222.tables === undefined) && (missing78 = "tables")){
const err666 = {instancePath:instancePath+"/inspection/details",schemaPath:"#/oneOf/5/properties/inspection/properties/details/oneOf/1/required",keyword:"required",params:{missingProperty: missing78},message:"must have required property '"+missing78+"'"};
if(vErrors === null){
vErrors = [err666];
}
else {
vErrors.push(err666);
}
errors++;
}
else {
const _errs637 = errors;
for(const key78 in data222){
if(!(key78 === "tables")){
const err667 = {instancePath:instancePath+"/inspection/details",schemaPath:"#/oneOf/5/properties/inspection/properties/details/oneOf/1/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key78},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err667];
}
else {
vErrors.push(err667);
}
errors++;
break;
}
}
if(_errs637 === errors){
if(data222.tables !== undefined){
let data228 = data222.tables;
const _errs638 = errors;
if(errors === _errs638){
if(Array.isArray(data228)){
if(data228.length > 8){
const err668 = {instancePath:instancePath+"/inspection/details/tables",schemaPath:"#/oneOf/5/properties/inspection/properties/details/oneOf/1/properties/tables/maxItems",keyword:"maxItems",params:{limit: 8},message:"must NOT have more than 8 items"};
if(vErrors === null){
vErrors = [err668];
}
else {
vErrors.push(err668);
}
errors++;
}
else {
var valid116 = true;
const len21 = data228.length;
for(let i21=0; i21<len21; i21++){
let data229 = data228[i21];
const _errs640 = errors;
if(errors === _errs640){
if(typeof data229 === "string"){
if(func1(data229) > 131072){
const err669 = {instancePath:instancePath+"/inspection/details/tables/" + i21,schemaPath:"#/oneOf/5/properties/inspection/properties/details/oneOf/1/properties/tables/items/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err669];
}
else {
vErrors.push(err669);
}
errors++;
}
}
else {
const err670 = {instancePath:instancePath+"/inspection/details/tables/" + i21,schemaPath:"#/oneOf/5/properties/inspection/properties/details/oneOf/1/properties/tables/items/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err670];
}
else {
vErrors.push(err670);
}
errors++;
}
}
var valid116 = _errs640 === errors;
if(!valid116){
break;
}
}
}
}
else {
const err671 = {instancePath:instancePath+"/inspection/details/tables",schemaPath:"#/oneOf/5/properties/inspection/properties/details/oneOf/1/properties/tables/type",keyword:"type",params:{type: "array"},message:"must be array"};
if(vErrors === null){
vErrors = [err671];
}
else {
vErrors.push(err671);
}
errors++;
}
}
}
}
}
}
else {
const err672 = {instancePath:instancePath+"/inspection/details",schemaPath:"#/oneOf/5/properties/inspection/properties/details/oneOf/1/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err672];
}
else {
vErrors.push(err672);
}
errors++;
}
}
var _valid15 = _errs635 === errors;
if(_valid15 && valid110){
valid110 = false;
passing8 = [passing8, 1];
}
else {
if(_valid15){
valid110 = true;
passing8 = 1;
if(props9 !== true){
props9 = true;
}
}
const _errs642 = errors;
if(errors === _errs642){
if(data222 && typeof data222 == "object" && !Array.isArray(data222)){
let missing79;
if((data222.explanation === undefined) && (missing79 = "explanation")){
const err673 = {instancePath:instancePath+"/inspection/details",schemaPath:"#/oneOf/5/properties/inspection/properties/details/oneOf/2/required",keyword:"required",params:{missingProperty: missing79},message:"must have required property '"+missing79+"'"};
if(vErrors === null){
vErrors = [err673];
}
else {
vErrors.push(err673);
}
errors++;
}
else {
const _errs644 = errors;
for(const key79 in data222){
if(!(key79 === "explanation")){
const err674 = {instancePath:instancePath+"/inspection/details",schemaPath:"#/oneOf/5/properties/inspection/properties/details/oneOf/2/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key79},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err674];
}
else {
vErrors.push(err674);
}
errors++;
break;
}
}
if(_errs644 === errors){
if(data222.explanation !== undefined){
let data230 = data222.explanation;
const _errs645 = errors;
if(errors === _errs645){
if(data230 && typeof data230 == "object" && !Array.isArray(data230)){
let missing80;
if((((((((data230.operators === undefined) && (missing80 = "operators")) || ((data230.predicate === undefined) && (missing80 = "predicate"))) || ((data230.projection === undefined) && (missing80 = "projection"))) || ((data230.limit === undefined) && (missing80 = "limit"))) || ((data230.aggregate === undefined) && (missing80 = "aggregate"))) || ((data230.columns === undefined) && (missing80 = "columns"))) || ((data230.budgets === undefined) && (missing80 = "budgets"))){
const err675 = {instancePath:instancePath+"/inspection/details/explanation",schemaPath:"#/oneOf/5/properties/inspection/properties/details/oneOf/2/properties/explanation/required",keyword:"required",params:{missingProperty: missing80},message:"must have required property '"+missing80+"'"};
if(vErrors === null){
vErrors = [err675];
}
else {
vErrors.push(err675);
}
errors++;
}
else {
const _errs647 = errors;
for(const key80 in data230){
if(!(((((((key80 === "operators") || (key80 === "predicate")) || (key80 === "projection")) || (key80 === "limit")) || (key80 === "aggregate")) || (key80 === "columns")) || (key80 === "budgets"))){
const err676 = {instancePath:instancePath+"/inspection/details/explanation",schemaPath:"#/oneOf/5/properties/inspection/properties/details/oneOf/2/properties/explanation/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key80},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err676];
}
else {
vErrors.push(err676);
}
errors++;
break;
}
}
if(_errs647 === errors){
if(data230.operators !== undefined){
let data231 = data230.operators;
const _errs648 = errors;
if(errors === _errs648){
if(Array.isArray(data231)){
if(data231.length > 8){
const err677 = {instancePath:instancePath+"/inspection/details/explanation/operators",schemaPath:"#/oneOf/5/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/operators/maxItems",keyword:"maxItems",params:{limit: 8},message:"must NOT have more than 8 items"};
if(vErrors === null){
vErrors = [err677];
}
else {
vErrors.push(err677);
}
errors++;
}
else {
var valid119 = true;
const len22 = data231.length;
for(let i22=0; i22<len22; i22++){
let data232 = data231[i22];
const _errs650 = errors;
if(typeof data232 !== "string"){
const err678 = {instancePath:instancePath+"/inspection/details/explanation/operators/" + i22,schemaPath:"#/oneOf/5/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/operators/items/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err678];
}
else {
vErrors.push(err678);
}
errors++;
}
if(!(((((((data232 === "scan") || (data232 === "filter")) || (data232 === "limit")) || (data232 === "project")) || (data232 === "count")) || (data232 === "sum")) || (data232 === "count_values"))){
const err679 = {instancePath:instancePath+"/inspection/details/explanation/operators/" + i22,schemaPath:"#/oneOf/5/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/operators/items/enum",keyword:"enum",params:{allowedValues: schema33.oneOf[5].properties.inspection.properties.details.oneOf[2].properties.explanation.properties.operators.items.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err679];
}
else {
vErrors.push(err679);
}
errors++;
}
var valid119 = _errs650 === errors;
if(!valid119){
break;
}
}
}
}
else {
const err680 = {instancePath:instancePath+"/inspection/details/explanation/operators",schemaPath:"#/oneOf/5/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/operators/type",keyword:"type",params:{type: "array"},message:"must be array"};
if(vErrors === null){
vErrors = [err680];
}
else {
vErrors.push(err680);
}
errors++;
}
}
var valid118 = _errs648 === errors;
}
else {
var valid118 = true;
}
if(valid118){
if(data230.predicate !== undefined){
let data233 = data230.predicate;
const _errs652 = errors;
const _errs653 = errors;
let valid120 = false;
let passing9 = null;
const _errs654 = errors;
if(errors === _errs654){
if(data233 && typeof data233 == "object" && !Array.isArray(data233)){
let missing81;
if((data233.all === undefined) && (missing81 = "all")){
const err681 = {instancePath:instancePath+"/inspection/details/explanation/predicate",schemaPath:"#/oneOf/5/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/predicate/oneOf/0/required",keyword:"required",params:{missingProperty: missing81},message:"must have required property '"+missing81+"'"};
if(vErrors === null){
vErrors = [err681];
}
else {
vErrors.push(err681);
}
errors++;
}
else {
const _errs656 = errors;
for(const key81 in data233){
if(!(key81 === "all")){
const err682 = {instancePath:instancePath+"/inspection/details/explanation/predicate",schemaPath:"#/oneOf/5/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/predicate/oneOf/0/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key81},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err682];
}
else {
vErrors.push(err682);
}
errors++;
break;
}
}
if(_errs656 === errors){
if(data233.all !== undefined){
let data234 = data233.all;
const _errs657 = errors;
if(errors === _errs657){
if(data234 && typeof data234 == "object" && !Array.isArray(data234)){
if(Object.keys(data234).length > 0){
const err683 = {instancePath:instancePath+"/inspection/details/explanation/predicate/all",schemaPath:"#/oneOf/5/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/predicate/oneOf/0/properties/all/maxProperties",keyword:"maxProperties",params:{limit: 0},message:"must NOT have more than 0 properties"};
if(vErrors === null){
vErrors = [err683];
}
else {
vErrors.push(err683);
}
errors++;
}
}
else {
const err684 = {instancePath:instancePath+"/inspection/details/explanation/predicate/all",schemaPath:"#/oneOf/5/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/predicate/oneOf/0/properties/all/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err684];
}
else {
vErrors.push(err684);
}
errors++;
}
}
}
}
}
}
else {
const err685 = {instancePath:instancePath+"/inspection/details/explanation/predicate",schemaPath:"#/oneOf/5/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/predicate/oneOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err685];
}
else {
vErrors.push(err685);
}
errors++;
}
}
var _valid16 = _errs654 === errors;
if(_valid16){
valid120 = true;
passing9 = 0;
var props10 = true;
}
const _errs659 = errors;
if(errors === _errs659){
if(data233 && typeof data233 == "object" && !Array.isArray(data233)){
let missing82;
if((data233.state === undefined) && (missing82 = "state")){
const err686 = {instancePath:instancePath+"/inspection/details/explanation/predicate",schemaPath:"#/oneOf/5/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/predicate/oneOf/1/required",keyword:"required",params:{missingProperty: missing82},message:"must have required property '"+missing82+"'"};
if(vErrors === null){
vErrors = [err686];
}
else {
vErrors.push(err686);
}
errors++;
}
else {
const _errs661 = errors;
for(const key82 in data233){
if(!(key82 === "state")){
const err687 = {instancePath:instancePath+"/inspection/details/explanation/predicate",schemaPath:"#/oneOf/5/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/predicate/oneOf/1/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key82},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err687];
}
else {
vErrors.push(err687);
}
errors++;
break;
}
}
if(_errs661 === errors){
if(data233.state !== undefined){
let data235 = data233.state;
const _errs662 = errors;
if(errors === _errs662){
if(data235 && typeof data235 == "object" && !Array.isArray(data235)){
let missing83;
if(((data235.column === undefined) && (missing83 = "column")) || ((data235.value === undefined) && (missing83 = "value"))){
const err688 = {instancePath:instancePath+"/inspection/details/explanation/predicate/state",schemaPath:"#/oneOf/5/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/predicate/oneOf/1/properties/state/required",keyword:"required",params:{missingProperty: missing83},message:"must have required property '"+missing83+"'"};
if(vErrors === null){
vErrors = [err688];
}
else {
vErrors.push(err688);
}
errors++;
}
else {
const _errs664 = errors;
for(const key83 in data235){
if(!((key83 === "column") || (key83 === "value"))){
const err689 = {instancePath:instancePath+"/inspection/details/explanation/predicate/state",schemaPath:"#/oneOf/5/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/predicate/oneOf/1/properties/state/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key83},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err689];
}
else {
vErrors.push(err689);
}
errors++;
break;
}
}
if(_errs664 === errors){
if(data235.column !== undefined){
let data236 = data235.column;
const _errs665 = errors;
if(errors === _errs665){
if(typeof data236 === "string"){
if(func1(data236) > 131072){
const err690 = {instancePath:instancePath+"/inspection/details/explanation/predicate/state/column",schemaPath:"#/oneOf/5/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/predicate/oneOf/1/properties/state/properties/column/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err690];
}
else {
vErrors.push(err690);
}
errors++;
}
}
else {
const err691 = {instancePath:instancePath+"/inspection/details/explanation/predicate/state/column",schemaPath:"#/oneOf/5/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/predicate/oneOf/1/properties/state/properties/column/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err691];
}
else {
vErrors.push(err691);
}
errors++;
}
}
var valid123 = _errs665 === errors;
}
else {
var valid123 = true;
}
if(valid123){
if(data235.value !== undefined){
let data237 = data235.value;
const _errs667 = errors;
if(typeof data237 !== "string"){
const err692 = {instancePath:instancePath+"/inspection/details/explanation/predicate/state/value",schemaPath:"#/oneOf/5/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/predicate/oneOf/1/properties/state/properties/value/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err692];
}
else {
vErrors.push(err692);
}
errors++;
}
if(!(((((data237 === "missing") || (data237 === "null")) || (data237 === "type_error")) || (data237 === "value")) || (data237 === "conflict"))){
const err693 = {instancePath:instancePath+"/inspection/details/explanation/predicate/state/value",schemaPath:"#/oneOf/5/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/predicate/oneOf/1/properties/state/properties/value/enum",keyword:"enum",params:{allowedValues: schema33.oneOf[5].properties.inspection.properties.details.oneOf[2].properties.explanation.properties.predicate.oneOf[1].properties.state.properties.value.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err693];
}
else {
vErrors.push(err693);
}
errors++;
}
var valid123 = _errs667 === errors;
}
else {
var valid123 = true;
}
}
}
}
}
else {
const err694 = {instancePath:instancePath+"/inspection/details/explanation/predicate/state",schemaPath:"#/oneOf/5/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/predicate/oneOf/1/properties/state/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err694];
}
else {
vErrors.push(err694);
}
errors++;
}
}
}
}
}
}
else {
const err695 = {instancePath:instancePath+"/inspection/details/explanation/predicate",schemaPath:"#/oneOf/5/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/predicate/oneOf/1/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err695];
}
else {
vErrors.push(err695);
}
errors++;
}
}
var _valid16 = _errs659 === errors;
if(_valid16 && valid120){
valid120 = false;
passing9 = [passing9, 1];
}
else {
if(_valid16){
valid120 = true;
passing9 = 1;
if(props10 !== true){
props10 = true;
}
}
const _errs669 = errors;
if(errors === _errs669){
if(data233 && typeof data233 == "object" && !Array.isArray(data233)){
let missing84;
if((data233.compare === undefined) && (missing84 = "compare")){
const err696 = {instancePath:instancePath+"/inspection/details/explanation/predicate",schemaPath:"#/oneOf/5/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/predicate/oneOf/2/required",keyword:"required",params:{missingProperty: missing84},message:"must have required property '"+missing84+"'"};
if(vErrors === null){
vErrors = [err696];
}
else {
vErrors.push(err696);
}
errors++;
}
else {
const _errs671 = errors;
for(const key84 in data233){
if(!(key84 === "compare")){
const err697 = {instancePath:instancePath+"/inspection/details/explanation/predicate",schemaPath:"#/oneOf/5/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/predicate/oneOf/2/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key84},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err697];
}
else {
vErrors.push(err697);
}
errors++;
break;
}
}
if(_errs671 === errors){
if(data233.compare !== undefined){
let data238 = data233.compare;
const _errs672 = errors;
if(errors === _errs672){
if(data238 && typeof data238 == "object" && !Array.isArray(data238)){
let missing85;
if((((data238.column === undefined) && (missing85 = "column")) || ((data238.op === undefined) && (missing85 = "op"))) || ((data238.type === undefined) && (missing85 = "type"))){
const err698 = {instancePath:instancePath+"/inspection/details/explanation/predicate/compare",schemaPath:"#/oneOf/5/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/predicate/oneOf/2/properties/compare/required",keyword:"required",params:{missingProperty: missing85},message:"must have required property '"+missing85+"'"};
if(vErrors === null){
vErrors = [err698];
}
else {
vErrors.push(err698);
}
errors++;
}
else {
const _errs674 = errors;
for(const key85 in data238){
if(!(((key85 === "column") || (key85 === "op")) || (key85 === "type"))){
const err699 = {instancePath:instancePath+"/inspection/details/explanation/predicate/compare",schemaPath:"#/oneOf/5/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/predicate/oneOf/2/properties/compare/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key85},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err699];
}
else {
vErrors.push(err699);
}
errors++;
break;
}
}
if(_errs674 === errors){
if(data238.column !== undefined){
let data239 = data238.column;
const _errs675 = errors;
if(errors === _errs675){
if(typeof data239 === "string"){
if(func1(data239) > 131072){
const err700 = {instancePath:instancePath+"/inspection/details/explanation/predicate/compare/column",schemaPath:"#/oneOf/5/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/predicate/oneOf/2/properties/compare/properties/column/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err700];
}
else {
vErrors.push(err700);
}
errors++;
}
}
else {
const err701 = {instancePath:instancePath+"/inspection/details/explanation/predicate/compare/column",schemaPath:"#/oneOf/5/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/predicate/oneOf/2/properties/compare/properties/column/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err701];
}
else {
vErrors.push(err701);
}
errors++;
}
}
var valid125 = _errs675 === errors;
}
else {
var valid125 = true;
}
if(valid125){
if(data238.op !== undefined){
let data240 = data238.op;
const _errs677 = errors;
if(typeof data240 !== "string"){
const err702 = {instancePath:instancePath+"/inspection/details/explanation/predicate/compare/op",schemaPath:"#/oneOf/5/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/predicate/oneOf/2/properties/compare/properties/op/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err702];
}
else {
vErrors.push(err702);
}
errors++;
}
if(!((((((data240 === "eq") || (data240 === "ne")) || (data240 === "lt")) || (data240 === "le")) || (data240 === "gt")) || (data240 === "ge"))){
const err703 = {instancePath:instancePath+"/inspection/details/explanation/predicate/compare/op",schemaPath:"#/oneOf/5/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/predicate/oneOf/2/properties/compare/properties/op/enum",keyword:"enum",params:{allowedValues: schema33.oneOf[5].properties.inspection.properties.details.oneOf[2].properties.explanation.properties.predicate.oneOf[2].properties.compare.properties.op.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err703];
}
else {
vErrors.push(err703);
}
errors++;
}
var valid125 = _errs677 === errors;
}
else {
var valid125 = true;
}
if(valid125){
if(data238.type !== undefined){
let data241 = data238.type;
const _errs679 = errors;
if(typeof data241 !== "string"){
const err704 = {instancePath:instancePath+"/inspection/details/explanation/predicate/compare/type",schemaPath:"#/oneOf/5/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/predicate/oneOf/2/properties/compare/properties/type/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err704];
}
else {
vErrors.push(err704);
}
errors++;
}
if(!((((((data241 === "int64") || (data241 === "uint64")) || (data241 === "float64")) || (data241 === "boolean")) || (data241 === "utf8")) || (data241 === "binary"))){
const err705 = {instancePath:instancePath+"/inspection/details/explanation/predicate/compare/type",schemaPath:"#/oneOf/5/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/predicate/oneOf/2/properties/compare/properties/type/enum",keyword:"enum",params:{allowedValues: schema33.oneOf[5].properties.inspection.properties.details.oneOf[2].properties.explanation.properties.predicate.oneOf[2].properties.compare.properties.type.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err705];
}
else {
vErrors.push(err705);
}
errors++;
}
var valid125 = _errs679 === errors;
}
else {
var valid125 = true;
}
}
}
}
}
}
else {
const err706 = {instancePath:instancePath+"/inspection/details/explanation/predicate/compare",schemaPath:"#/oneOf/5/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/predicate/oneOf/2/properties/compare/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err706];
}
else {
vErrors.push(err706);
}
errors++;
}
}
}
}
}
}
else {
const err707 = {instancePath:instancePath+"/inspection/details/explanation/predicate",schemaPath:"#/oneOf/5/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/predicate/oneOf/2/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err707];
}
else {
vErrors.push(err707);
}
errors++;
}
}
var _valid16 = _errs669 === errors;
if(_valid16 && valid120){
valid120 = false;
passing9 = [passing9, 2];
}
else {
if(_valid16){
valid120 = true;
passing9 = 2;
if(props10 !== true){
props10 = true;
}
}
const _errs681 = errors;
if(errors === _errs681){
if(data233 && typeof data233 == "object" && !Array.isArray(data233)){
let missing86;
if((data233.program === undefined) && (missing86 = "program")){
const err708 = {instancePath:instancePath+"/inspection/details/explanation/predicate",schemaPath:"#/oneOf/5/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/predicate/oneOf/3/required",keyword:"required",params:{missingProperty: missing86},message:"must have required property '"+missing86+"'"};
if(vErrors === null){
vErrors = [err708];
}
else {
vErrors.push(err708);
}
errors++;
}
else {
const _errs683 = errors;
for(const key86 in data233){
if(!(key86 === "program")){
const err709 = {instancePath:instancePath+"/inspection/details/explanation/predicate",schemaPath:"#/oneOf/5/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/predicate/oneOf/3/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key86},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err709];
}
else {
vErrors.push(err709);
}
errors++;
break;
}
}
if(_errs683 === errors){
if(data233.program !== undefined){
let data242 = data233.program;
const _errs684 = errors;
if(errors === _errs684){
if(Array.isArray(data242)){
if(data242.length > 64){
const err710 = {instancePath:instancePath+"/inspection/details/explanation/predicate/program",schemaPath:"#/oneOf/5/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/predicate/oneOf/3/properties/program/maxItems",keyword:"maxItems",params:{limit: 64},message:"must NOT have more than 64 items"};
if(vErrors === null){
vErrors = [err710];
}
else {
vErrors.push(err710);
}
errors++;
}
else {
var valid127 = true;
const len23 = data242.length;
for(let i23=0; i23<len23; i23++){
let data243 = data242[i23];
const _errs686 = errors;
const _errs687 = errors;
let valid128 = false;
let passing10 = null;
const _errs688 = errors;
if(errors === _errs688){
if(data243 && typeof data243 == "object" && !Array.isArray(data243)){
let missing87;
if((data243.atom === undefined) && (missing87 = "atom")){
const err711 = {instancePath:instancePath+"/inspection/details/explanation/predicate/program/" + i23,schemaPath:"#/oneOf/5/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/predicate/oneOf/3/properties/program/items/oneOf/0/required",keyword:"required",params:{missingProperty: missing87},message:"must have required property '"+missing87+"'"};
if(vErrors === null){
vErrors = [err711];
}
else {
vErrors.push(err711);
}
errors++;
}
else {
const _errs690 = errors;
for(const key87 in data243){
if(!(key87 === "atom")){
const err712 = {instancePath:instancePath+"/inspection/details/explanation/predicate/program/" + i23,schemaPath:"#/oneOf/5/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/predicate/oneOf/3/properties/program/items/oneOf/0/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key87},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err712];
}
else {
vErrors.push(err712);
}
errors++;
break;
}
}
if(_errs690 === errors){
if(data243.atom !== undefined){
let data244 = data243.atom;
const _errs692 = errors;
let valid130 = false;
let passing11 = null;
const _errs693 = errors;
if(errors === _errs693){
if(data244 && typeof data244 == "object" && !Array.isArray(data244)){
let missing88;
if((data244.all === undefined) && (missing88 = "all")){
const err713 = {instancePath:instancePath+"/inspection/details/explanation/predicate/program/" + i23+"/atom",schemaPath:"#/oneOf/5/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/predicate/oneOf/3/properties/program/items/oneOf/0/properties/atom/oneOf/0/required",keyword:"required",params:{missingProperty: missing88},message:"must have required property '"+missing88+"'"};
if(vErrors === null){
vErrors = [err713];
}
else {
vErrors.push(err713);
}
errors++;
}
else {
const _errs695 = errors;
for(const key88 in data244){
if(!(key88 === "all")){
const err714 = {instancePath:instancePath+"/inspection/details/explanation/predicate/program/" + i23+"/atom",schemaPath:"#/oneOf/5/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/predicate/oneOf/3/properties/program/items/oneOf/0/properties/atom/oneOf/0/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key88},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err714];
}
else {
vErrors.push(err714);
}
errors++;
break;
}
}
if(_errs695 === errors){
if(data244.all !== undefined){
let data245 = data244.all;
const _errs696 = errors;
if(errors === _errs696){
if(data245 && typeof data245 == "object" && !Array.isArray(data245)){
if(Object.keys(data245).length > 0){
const err715 = {instancePath:instancePath+"/inspection/details/explanation/predicate/program/" + i23+"/atom/all",schemaPath:"#/oneOf/5/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/predicate/oneOf/3/properties/program/items/oneOf/0/properties/atom/oneOf/0/properties/all/maxProperties",keyword:"maxProperties",params:{limit: 0},message:"must NOT have more than 0 properties"};
if(vErrors === null){
vErrors = [err715];
}
else {
vErrors.push(err715);
}
errors++;
}
}
else {
const err716 = {instancePath:instancePath+"/inspection/details/explanation/predicate/program/" + i23+"/atom/all",schemaPath:"#/oneOf/5/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/predicate/oneOf/3/properties/program/items/oneOf/0/properties/atom/oneOf/0/properties/all/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err716];
}
else {
vErrors.push(err716);
}
errors++;
}
}
}
}
}
}
else {
const err717 = {instancePath:instancePath+"/inspection/details/explanation/predicate/program/" + i23+"/atom",schemaPath:"#/oneOf/5/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/predicate/oneOf/3/properties/program/items/oneOf/0/properties/atom/oneOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err717];
}
else {
vErrors.push(err717);
}
errors++;
}
}
var _valid18 = _errs693 === errors;
if(_valid18){
valid130 = true;
passing11 = 0;
var props11 = true;
}
const _errs698 = errors;
if(errors === _errs698){
if(data244 && typeof data244 == "object" && !Array.isArray(data244)){
let missing89;
if((data244.state === undefined) && (missing89 = "state")){
const err718 = {instancePath:instancePath+"/inspection/details/explanation/predicate/program/" + i23+"/atom",schemaPath:"#/oneOf/5/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/predicate/oneOf/3/properties/program/items/oneOf/0/properties/atom/oneOf/1/required",keyword:"required",params:{missingProperty: missing89},message:"must have required property '"+missing89+"'"};
if(vErrors === null){
vErrors = [err718];
}
else {
vErrors.push(err718);
}
errors++;
}
else {
const _errs700 = errors;
for(const key89 in data244){
if(!(key89 === "state")){
const err719 = {instancePath:instancePath+"/inspection/details/explanation/predicate/program/" + i23+"/atom",schemaPath:"#/oneOf/5/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/predicate/oneOf/3/properties/program/items/oneOf/0/properties/atom/oneOf/1/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key89},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err719];
}
else {
vErrors.push(err719);
}
errors++;
break;
}
}
if(_errs700 === errors){
if(data244.state !== undefined){
let data246 = data244.state;
const _errs701 = errors;
if(errors === _errs701){
if(data246 && typeof data246 == "object" && !Array.isArray(data246)){
let missing90;
if(((data246.column === undefined) && (missing90 = "column")) || ((data246.value === undefined) && (missing90 = "value"))){
const err720 = {instancePath:instancePath+"/inspection/details/explanation/predicate/program/" + i23+"/atom/state",schemaPath:"#/oneOf/5/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/predicate/oneOf/3/properties/program/items/oneOf/0/properties/atom/oneOf/1/properties/state/required",keyword:"required",params:{missingProperty: missing90},message:"must have required property '"+missing90+"'"};
if(vErrors === null){
vErrors = [err720];
}
else {
vErrors.push(err720);
}
errors++;
}
else {
const _errs703 = errors;
for(const key90 in data246){
if(!((key90 === "column") || (key90 === "value"))){
const err721 = {instancePath:instancePath+"/inspection/details/explanation/predicate/program/" + i23+"/atom/state",schemaPath:"#/oneOf/5/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/predicate/oneOf/3/properties/program/items/oneOf/0/properties/atom/oneOf/1/properties/state/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key90},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err721];
}
else {
vErrors.push(err721);
}
errors++;
break;
}
}
if(_errs703 === errors){
if(data246.column !== undefined){
let data247 = data246.column;
const _errs704 = errors;
if(errors === _errs704){
if(typeof data247 === "string"){
if(func1(data247) > 131072){
const err722 = {instancePath:instancePath+"/inspection/details/explanation/predicate/program/" + i23+"/atom/state/column",schemaPath:"#/oneOf/5/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/predicate/oneOf/3/properties/program/items/oneOf/0/properties/atom/oneOf/1/properties/state/properties/column/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err722];
}
else {
vErrors.push(err722);
}
errors++;
}
}
else {
const err723 = {instancePath:instancePath+"/inspection/details/explanation/predicate/program/" + i23+"/atom/state/column",schemaPath:"#/oneOf/5/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/predicate/oneOf/3/properties/program/items/oneOf/0/properties/atom/oneOf/1/properties/state/properties/column/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err723];
}
else {
vErrors.push(err723);
}
errors++;
}
}
var valid133 = _errs704 === errors;
}
else {
var valid133 = true;
}
if(valid133){
if(data246.value !== undefined){
let data248 = data246.value;
const _errs706 = errors;
if(typeof data248 !== "string"){
const err724 = {instancePath:instancePath+"/inspection/details/explanation/predicate/program/" + i23+"/atom/state/value",schemaPath:"#/oneOf/5/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/predicate/oneOf/3/properties/program/items/oneOf/0/properties/atom/oneOf/1/properties/state/properties/value/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err724];
}
else {
vErrors.push(err724);
}
errors++;
}
if(!(((((data248 === "missing") || (data248 === "null")) || (data248 === "type_error")) || (data248 === "value")) || (data248 === "conflict"))){
const err725 = {instancePath:instancePath+"/inspection/details/explanation/predicate/program/" + i23+"/atom/state/value",schemaPath:"#/oneOf/5/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/predicate/oneOf/3/properties/program/items/oneOf/0/properties/atom/oneOf/1/properties/state/properties/value/enum",keyword:"enum",params:{allowedValues: schema33.oneOf[5].properties.inspection.properties.details.oneOf[2].properties.explanation.properties.predicate.oneOf[3].properties.program.items.oneOf[0].properties.atom.oneOf[1].properties.state.properties.value.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err725];
}
else {
vErrors.push(err725);
}
errors++;
}
var valid133 = _errs706 === errors;
}
else {
var valid133 = true;
}
}
}
}
}
else {
const err726 = {instancePath:instancePath+"/inspection/details/explanation/predicate/program/" + i23+"/atom/state",schemaPath:"#/oneOf/5/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/predicate/oneOf/3/properties/program/items/oneOf/0/properties/atom/oneOf/1/properties/state/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err726];
}
else {
vErrors.push(err726);
}
errors++;
}
}
}
}
}
}
else {
const err727 = {instancePath:instancePath+"/inspection/details/explanation/predicate/program/" + i23+"/atom",schemaPath:"#/oneOf/5/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/predicate/oneOf/3/properties/program/items/oneOf/0/properties/atom/oneOf/1/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err727];
}
else {
vErrors.push(err727);
}
errors++;
}
}
var _valid18 = _errs698 === errors;
if(_valid18 && valid130){
valid130 = false;
passing11 = [passing11, 1];
}
else {
if(_valid18){
valid130 = true;
passing11 = 1;
if(props11 !== true){
props11 = true;
}
}
const _errs708 = errors;
if(errors === _errs708){
if(data244 && typeof data244 == "object" && !Array.isArray(data244)){
let missing91;
if((data244.compare === undefined) && (missing91 = "compare")){
const err728 = {instancePath:instancePath+"/inspection/details/explanation/predicate/program/" + i23+"/atom",schemaPath:"#/oneOf/5/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/predicate/oneOf/3/properties/program/items/oneOf/0/properties/atom/oneOf/2/required",keyword:"required",params:{missingProperty: missing91},message:"must have required property '"+missing91+"'"};
if(vErrors === null){
vErrors = [err728];
}
else {
vErrors.push(err728);
}
errors++;
}
else {
const _errs710 = errors;
for(const key91 in data244){
if(!(key91 === "compare")){
const err729 = {instancePath:instancePath+"/inspection/details/explanation/predicate/program/" + i23+"/atom",schemaPath:"#/oneOf/5/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/predicate/oneOf/3/properties/program/items/oneOf/0/properties/atom/oneOf/2/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key91},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err729];
}
else {
vErrors.push(err729);
}
errors++;
break;
}
}
if(_errs710 === errors){
if(data244.compare !== undefined){
let data249 = data244.compare;
const _errs711 = errors;
if(errors === _errs711){
if(data249 && typeof data249 == "object" && !Array.isArray(data249)){
let missing92;
if((((data249.column === undefined) && (missing92 = "column")) || ((data249.op === undefined) && (missing92 = "op"))) || ((data249.type === undefined) && (missing92 = "type"))){
const err730 = {instancePath:instancePath+"/inspection/details/explanation/predicate/program/" + i23+"/atom/compare",schemaPath:"#/oneOf/5/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/predicate/oneOf/3/properties/program/items/oneOf/0/properties/atom/oneOf/2/properties/compare/required",keyword:"required",params:{missingProperty: missing92},message:"must have required property '"+missing92+"'"};
if(vErrors === null){
vErrors = [err730];
}
else {
vErrors.push(err730);
}
errors++;
}
else {
const _errs713 = errors;
for(const key92 in data249){
if(!(((key92 === "column") || (key92 === "op")) || (key92 === "type"))){
const err731 = {instancePath:instancePath+"/inspection/details/explanation/predicate/program/" + i23+"/atom/compare",schemaPath:"#/oneOf/5/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/predicate/oneOf/3/properties/program/items/oneOf/0/properties/atom/oneOf/2/properties/compare/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key92},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err731];
}
else {
vErrors.push(err731);
}
errors++;
break;
}
}
if(_errs713 === errors){
if(data249.column !== undefined){
let data250 = data249.column;
const _errs714 = errors;
if(errors === _errs714){
if(typeof data250 === "string"){
if(func1(data250) > 131072){
const err732 = {instancePath:instancePath+"/inspection/details/explanation/predicate/program/" + i23+"/atom/compare/column",schemaPath:"#/oneOf/5/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/predicate/oneOf/3/properties/program/items/oneOf/0/properties/atom/oneOf/2/properties/compare/properties/column/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err732];
}
else {
vErrors.push(err732);
}
errors++;
}
}
else {
const err733 = {instancePath:instancePath+"/inspection/details/explanation/predicate/program/" + i23+"/atom/compare/column",schemaPath:"#/oneOf/5/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/predicate/oneOf/3/properties/program/items/oneOf/0/properties/atom/oneOf/2/properties/compare/properties/column/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err733];
}
else {
vErrors.push(err733);
}
errors++;
}
}
var valid135 = _errs714 === errors;
}
else {
var valid135 = true;
}
if(valid135){
if(data249.op !== undefined){
let data251 = data249.op;
const _errs716 = errors;
if(typeof data251 !== "string"){
const err734 = {instancePath:instancePath+"/inspection/details/explanation/predicate/program/" + i23+"/atom/compare/op",schemaPath:"#/oneOf/5/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/predicate/oneOf/3/properties/program/items/oneOf/0/properties/atom/oneOf/2/properties/compare/properties/op/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err734];
}
else {
vErrors.push(err734);
}
errors++;
}
if(!((((((data251 === "eq") || (data251 === "ne")) || (data251 === "lt")) || (data251 === "le")) || (data251 === "gt")) || (data251 === "ge"))){
const err735 = {instancePath:instancePath+"/inspection/details/explanation/predicate/program/" + i23+"/atom/compare/op",schemaPath:"#/oneOf/5/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/predicate/oneOf/3/properties/program/items/oneOf/0/properties/atom/oneOf/2/properties/compare/properties/op/enum",keyword:"enum",params:{allowedValues: schema33.oneOf[5].properties.inspection.properties.details.oneOf[2].properties.explanation.properties.predicate.oneOf[3].properties.program.items.oneOf[0].properties.atom.oneOf[2].properties.compare.properties.op.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err735];
}
else {
vErrors.push(err735);
}
errors++;
}
var valid135 = _errs716 === errors;
}
else {
var valid135 = true;
}
if(valid135){
if(data249.type !== undefined){
let data252 = data249.type;
const _errs718 = errors;
if(typeof data252 !== "string"){
const err736 = {instancePath:instancePath+"/inspection/details/explanation/predicate/program/" + i23+"/atom/compare/type",schemaPath:"#/oneOf/5/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/predicate/oneOf/3/properties/program/items/oneOf/0/properties/atom/oneOf/2/properties/compare/properties/type/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err736];
}
else {
vErrors.push(err736);
}
errors++;
}
if(!((((((data252 === "int64") || (data252 === "uint64")) || (data252 === "float64")) || (data252 === "boolean")) || (data252 === "utf8")) || (data252 === "binary"))){
const err737 = {instancePath:instancePath+"/inspection/details/explanation/predicate/program/" + i23+"/atom/compare/type",schemaPath:"#/oneOf/5/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/predicate/oneOf/3/properties/program/items/oneOf/0/properties/atom/oneOf/2/properties/compare/properties/type/enum",keyword:"enum",params:{allowedValues: schema33.oneOf[5].properties.inspection.properties.details.oneOf[2].properties.explanation.properties.predicate.oneOf[3].properties.program.items.oneOf[0].properties.atom.oneOf[2].properties.compare.properties.type.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err737];
}
else {
vErrors.push(err737);
}
errors++;
}
var valid135 = _errs718 === errors;
}
else {
var valid135 = true;
}
}
}
}
}
}
else {
const err738 = {instancePath:instancePath+"/inspection/details/explanation/predicate/program/" + i23+"/atom/compare",schemaPath:"#/oneOf/5/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/predicate/oneOf/3/properties/program/items/oneOf/0/properties/atom/oneOf/2/properties/compare/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err738];
}
else {
vErrors.push(err738);
}
errors++;
}
}
}
}
}
}
else {
const err739 = {instancePath:instancePath+"/inspection/details/explanation/predicate/program/" + i23+"/atom",schemaPath:"#/oneOf/5/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/predicate/oneOf/3/properties/program/items/oneOf/0/properties/atom/oneOf/2/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err739];
}
else {
vErrors.push(err739);
}
errors++;
}
}
var _valid18 = _errs708 === errors;
if(_valid18 && valid130){
valid130 = false;
passing11 = [passing11, 2];
}
else {
if(_valid18){
valid130 = true;
passing11 = 2;
if(props11 !== true){
props11 = true;
}
}
}
}
if(!valid130){
const err740 = {instancePath:instancePath+"/inspection/details/explanation/predicate/program/" + i23+"/atom",schemaPath:"#/oneOf/5/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/predicate/oneOf/3/properties/program/items/oneOf/0/properties/atom/oneOf",keyword:"oneOf",params:{passingSchemas: passing11},message:"must match exactly one schema in oneOf"};
if(vErrors === null){
vErrors = [err740];
}
else {
vErrors.push(err740);
}
errors++;
}
else {
errors = _errs692;
if(vErrors !== null){
if(_errs692){
vErrors.length = _errs692;
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
const err741 = {instancePath:instancePath+"/inspection/details/explanation/predicate/program/" + i23,schemaPath:"#/oneOf/5/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/predicate/oneOf/3/properties/program/items/oneOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err741];
}
else {
vErrors.push(err741);
}
errors++;
}
}
var _valid17 = _errs688 === errors;
if(_valid17){
valid128 = true;
passing10 = 0;
var props12 = true;
}
const _errs720 = errors;
if(errors === _errs720){
if(data243 && typeof data243 == "object" && !Array.isArray(data243)){
let missing93;
if((data243.negate === undefined) && (missing93 = "negate")){
const err742 = {instancePath:instancePath+"/inspection/details/explanation/predicate/program/" + i23,schemaPath:"#/oneOf/5/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/predicate/oneOf/3/properties/program/items/oneOf/1/required",keyword:"required",params:{missingProperty: missing93},message:"must have required property '"+missing93+"'"};
if(vErrors === null){
vErrors = [err742];
}
else {
vErrors.push(err742);
}
errors++;
}
else {
const _errs722 = errors;
for(const key93 in data243){
if(!(key93 === "negate")){
const err743 = {instancePath:instancePath+"/inspection/details/explanation/predicate/program/" + i23,schemaPath:"#/oneOf/5/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/predicate/oneOf/3/properties/program/items/oneOf/1/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key93},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err743];
}
else {
vErrors.push(err743);
}
errors++;
break;
}
}
if(_errs722 === errors){
if(data243.negate !== undefined){
let data253 = data243.negate;
const _errs723 = errors;
if(errors === _errs723){
if(data253 && typeof data253 == "object" && !Array.isArray(data253)){
if(Object.keys(data253).length > 0){
const err744 = {instancePath:instancePath+"/inspection/details/explanation/predicate/program/" + i23+"/negate",schemaPath:"#/oneOf/5/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/predicate/oneOf/3/properties/program/items/oneOf/1/properties/negate/maxProperties",keyword:"maxProperties",params:{limit: 0},message:"must NOT have more than 0 properties"};
if(vErrors === null){
vErrors = [err744];
}
else {
vErrors.push(err744);
}
errors++;
}
}
else {
const err745 = {instancePath:instancePath+"/inspection/details/explanation/predicate/program/" + i23+"/negate",schemaPath:"#/oneOf/5/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/predicate/oneOf/3/properties/program/items/oneOf/1/properties/negate/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err745];
}
else {
vErrors.push(err745);
}
errors++;
}
}
}
}
}
}
else {
const err746 = {instancePath:instancePath+"/inspection/details/explanation/predicate/program/" + i23,schemaPath:"#/oneOf/5/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/predicate/oneOf/3/properties/program/items/oneOf/1/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err746];
}
else {
vErrors.push(err746);
}
errors++;
}
}
var _valid17 = _errs720 === errors;
if(_valid17 && valid128){
valid128 = false;
passing10 = [passing10, 1];
}
else {
if(_valid17){
valid128 = true;
passing10 = 1;
if(props12 !== true){
props12 = true;
}
}
const _errs725 = errors;
if(errors === _errs725){
if(data243 && typeof data243 == "object" && !Array.isArray(data243)){
let missing94;
if((data243.conjunction === undefined) && (missing94 = "conjunction")){
const err747 = {instancePath:instancePath+"/inspection/details/explanation/predicate/program/" + i23,schemaPath:"#/oneOf/5/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/predicate/oneOf/3/properties/program/items/oneOf/2/required",keyword:"required",params:{missingProperty: missing94},message:"must have required property '"+missing94+"'"};
if(vErrors === null){
vErrors = [err747];
}
else {
vErrors.push(err747);
}
errors++;
}
else {
const _errs727 = errors;
for(const key94 in data243){
if(!(key94 === "conjunction")){
const err748 = {instancePath:instancePath+"/inspection/details/explanation/predicate/program/" + i23,schemaPath:"#/oneOf/5/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/predicate/oneOf/3/properties/program/items/oneOf/2/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key94},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err748];
}
else {
vErrors.push(err748);
}
errors++;
break;
}
}
if(_errs727 === errors){
if(data243.conjunction !== undefined){
let data254 = data243.conjunction;
const _errs728 = errors;
if(errors === _errs728){
if(data254 && typeof data254 == "object" && !Array.isArray(data254)){
if(Object.keys(data254).length > 0){
const err749 = {instancePath:instancePath+"/inspection/details/explanation/predicate/program/" + i23+"/conjunction",schemaPath:"#/oneOf/5/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/predicate/oneOf/3/properties/program/items/oneOf/2/properties/conjunction/maxProperties",keyword:"maxProperties",params:{limit: 0},message:"must NOT have more than 0 properties"};
if(vErrors === null){
vErrors = [err749];
}
else {
vErrors.push(err749);
}
errors++;
}
}
else {
const err750 = {instancePath:instancePath+"/inspection/details/explanation/predicate/program/" + i23+"/conjunction",schemaPath:"#/oneOf/5/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/predicate/oneOf/3/properties/program/items/oneOf/2/properties/conjunction/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err750];
}
else {
vErrors.push(err750);
}
errors++;
}
}
}
}
}
}
else {
const err751 = {instancePath:instancePath+"/inspection/details/explanation/predicate/program/" + i23,schemaPath:"#/oneOf/5/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/predicate/oneOf/3/properties/program/items/oneOf/2/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err751];
}
else {
vErrors.push(err751);
}
errors++;
}
}
var _valid17 = _errs725 === errors;
if(_valid17 && valid128){
valid128 = false;
passing10 = [passing10, 2];
}
else {
if(_valid17){
valid128 = true;
passing10 = 2;
if(props12 !== true){
props12 = true;
}
}
const _errs730 = errors;
if(errors === _errs730){
if(data243 && typeof data243 == "object" && !Array.isArray(data243)){
let missing95;
if((data243.disjunction === undefined) && (missing95 = "disjunction")){
const err752 = {instancePath:instancePath+"/inspection/details/explanation/predicate/program/" + i23,schemaPath:"#/oneOf/5/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/predicate/oneOf/3/properties/program/items/oneOf/3/required",keyword:"required",params:{missingProperty: missing95},message:"must have required property '"+missing95+"'"};
if(vErrors === null){
vErrors = [err752];
}
else {
vErrors.push(err752);
}
errors++;
}
else {
const _errs732 = errors;
for(const key95 in data243){
if(!(key95 === "disjunction")){
const err753 = {instancePath:instancePath+"/inspection/details/explanation/predicate/program/" + i23,schemaPath:"#/oneOf/5/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/predicate/oneOf/3/properties/program/items/oneOf/3/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key95},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err753];
}
else {
vErrors.push(err753);
}
errors++;
break;
}
}
if(_errs732 === errors){
if(data243.disjunction !== undefined){
let data255 = data243.disjunction;
const _errs733 = errors;
if(errors === _errs733){
if(data255 && typeof data255 == "object" && !Array.isArray(data255)){
if(Object.keys(data255).length > 0){
const err754 = {instancePath:instancePath+"/inspection/details/explanation/predicate/program/" + i23+"/disjunction",schemaPath:"#/oneOf/5/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/predicate/oneOf/3/properties/program/items/oneOf/3/properties/disjunction/maxProperties",keyword:"maxProperties",params:{limit: 0},message:"must NOT have more than 0 properties"};
if(vErrors === null){
vErrors = [err754];
}
else {
vErrors.push(err754);
}
errors++;
}
}
else {
const err755 = {instancePath:instancePath+"/inspection/details/explanation/predicate/program/" + i23+"/disjunction",schemaPath:"#/oneOf/5/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/predicate/oneOf/3/properties/program/items/oneOf/3/properties/disjunction/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err755];
}
else {
vErrors.push(err755);
}
errors++;
}
}
}
}
}
}
else {
const err756 = {instancePath:instancePath+"/inspection/details/explanation/predicate/program/" + i23,schemaPath:"#/oneOf/5/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/predicate/oneOf/3/properties/program/items/oneOf/3/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err756];
}
else {
vErrors.push(err756);
}
errors++;
}
}
var _valid17 = _errs730 === errors;
if(_valid17 && valid128){
valid128 = false;
passing10 = [passing10, 3];
}
else {
if(_valid17){
valid128 = true;
passing10 = 3;
if(props12 !== true){
props12 = true;
}
}
}
}
}
if(!valid128){
const err757 = {instancePath:instancePath+"/inspection/details/explanation/predicate/program/" + i23,schemaPath:"#/oneOf/5/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/predicate/oneOf/3/properties/program/items/oneOf",keyword:"oneOf",params:{passingSchemas: passing10},message:"must match exactly one schema in oneOf"};
if(vErrors === null){
vErrors = [err757];
}
else {
vErrors.push(err757);
}
errors++;
}
else {
errors = _errs687;
if(vErrors !== null){
if(_errs687){
vErrors.length = _errs687;
}
else {
vErrors = null;
}
}
}
var valid127 = _errs686 === errors;
if(!valid127){
break;
}
}
}
}
else {
const err758 = {instancePath:instancePath+"/inspection/details/explanation/predicate/program",schemaPath:"#/oneOf/5/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/predicate/oneOf/3/properties/program/type",keyword:"type",params:{type: "array"},message:"must be array"};
if(vErrors === null){
vErrors = [err758];
}
else {
vErrors.push(err758);
}
errors++;
}
}
}
}
}
}
else {
const err759 = {instancePath:instancePath+"/inspection/details/explanation/predicate",schemaPath:"#/oneOf/5/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/predicate/oneOf/3/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err759];
}
else {
vErrors.push(err759);
}
errors++;
}
}
var _valid16 = _errs681 === errors;
if(_valid16 && valid120){
valid120 = false;
passing9 = [passing9, 3];
}
else {
if(_valid16){
valid120 = true;
passing9 = 3;
if(props10 !== true){
props10 = true;
}
}
}
}
}
if(!valid120){
const err760 = {instancePath:instancePath+"/inspection/details/explanation/predicate",schemaPath:"#/oneOf/5/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/predicate/oneOf",keyword:"oneOf",params:{passingSchemas: passing9},message:"must match exactly one schema in oneOf"};
if(vErrors === null){
vErrors = [err760];
}
else {
vErrors.push(err760);
}
errors++;
}
else {
errors = _errs653;
if(vErrors !== null){
if(_errs653){
vErrors.length = _errs653;
}
else {
vErrors = null;
}
}
}
var valid118 = _errs652 === errors;
}
else {
var valid118 = true;
}
if(valid118){
if(data230.projection !== undefined){
let data256 = data230.projection;
const _errs735 = errors;
if(errors === _errs735){
if(Array.isArray(data256)){
if(data256.length > 8){
const err761 = {instancePath:instancePath+"/inspection/details/explanation/projection",schemaPath:"#/oneOf/5/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/projection/maxItems",keyword:"maxItems",params:{limit: 8},message:"must NOT have more than 8 items"};
if(vErrors === null){
vErrors = [err761];
}
else {
vErrors.push(err761);
}
errors++;
}
else {
var valid139 = true;
const len24 = data256.length;
for(let i24=0; i24<len24; i24++){
let data257 = data256[i24];
const _errs737 = errors;
if(errors === _errs737){
if(typeof data257 === "string"){
if(func1(data257) > 131072){
const err762 = {instancePath:instancePath+"/inspection/details/explanation/projection/" + i24,schemaPath:"#/oneOf/5/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/projection/items/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err762];
}
else {
vErrors.push(err762);
}
errors++;
}
}
else {
const err763 = {instancePath:instancePath+"/inspection/details/explanation/projection/" + i24,schemaPath:"#/oneOf/5/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/projection/items/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err763];
}
else {
vErrors.push(err763);
}
errors++;
}
}
var valid139 = _errs737 === errors;
if(!valid139){
break;
}
}
}
}
else {
const err764 = {instancePath:instancePath+"/inspection/details/explanation/projection",schemaPath:"#/oneOf/5/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/projection/type",keyword:"type",params:{type: "array"},message:"must be array"};
if(vErrors === null){
vErrors = [err764];
}
else {
vErrors.push(err764);
}
errors++;
}
}
var valid118 = _errs735 === errors;
}
else {
var valid118 = true;
}
if(valid118){
if(data230.limit !== undefined){
let data258 = data230.limit;
const _errs739 = errors;
const _errs740 = errors;
let valid140 = false;
const _errs741 = errors;
if(errors === _errs741){
if(typeof data258 === "string"){
if(func1(data258) > 131072){
const err765 = {instancePath:instancePath+"/inspection/details/explanation/limit",schemaPath:"#/oneOf/5/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/limit/anyOf/0/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err765];
}
else {
vErrors.push(err765);
}
errors++;
}
}
else {
const err766 = {instancePath:instancePath+"/inspection/details/explanation/limit",schemaPath:"#/oneOf/5/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/limit/anyOf/0/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err766];
}
else {
vErrors.push(err766);
}
errors++;
}
}
var _valid19 = _errs741 === errors;
valid140 = valid140 || _valid19;
const _errs743 = errors;
if(data258 !== null){
const err767 = {instancePath:instancePath+"/inspection/details/explanation/limit",schemaPath:"#/oneOf/5/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/limit/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err767];
}
else {
vErrors.push(err767);
}
errors++;
}
var _valid19 = _errs743 === errors;
valid140 = valid140 || _valid19;
if(!valid140){
const err768 = {instancePath:instancePath+"/inspection/details/explanation/limit",schemaPath:"#/oneOf/5/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/limit/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err768];
}
else {
vErrors.push(err768);
}
errors++;
}
else {
errors = _errs740;
if(vErrors !== null){
if(_errs740){
vErrors.length = _errs740;
}
else {
vErrors = null;
}
}
}
var valid118 = _errs739 === errors;
}
else {
var valid118 = true;
}
if(valid118){
if(data230.aggregate !== undefined){
let data259 = data230.aggregate;
const _errs745 = errors;
if(typeof data259 !== "string"){
const err769 = {instancePath:instancePath+"/inspection/details/explanation/aggregate",schemaPath:"#/oneOf/5/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/aggregate/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err769];
}
else {
vErrors.push(err769);
}
errors++;
}
if(!((((data259 === "rows") || (data259 === "count")) || (data259 === "sum")) || (data259 === "count_values"))){
const err770 = {instancePath:instancePath+"/inspection/details/explanation/aggregate",schemaPath:"#/oneOf/5/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/aggregate/enum",keyword:"enum",params:{allowedValues: schema33.oneOf[5].properties.inspection.properties.details.oneOf[2].properties.explanation.properties.aggregate.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err770];
}
else {
vErrors.push(err770);
}
errors++;
}
var valid118 = _errs745 === errors;
}
else {
var valid118 = true;
}
if(valid118){
if(data230.columns !== undefined){
let data260 = data230.columns;
const _errs747 = errors;
if(errors === _errs747){
if(Array.isArray(data260)){
if(data260.length > 8){
const err771 = {instancePath:instancePath+"/inspection/details/explanation/columns",schemaPath:"#/oneOf/5/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/columns/maxItems",keyword:"maxItems",params:{limit: 8},message:"must NOT have more than 8 items"};
if(vErrors === null){
vErrors = [err771];
}
else {
vErrors.push(err771);
}
errors++;
}
else {
var valid141 = true;
const len25 = data260.length;
for(let i25=0; i25<len25; i25++){
let data261 = data260[i25];
const _errs749 = errors;
if(errors === _errs749){
if(data261 && typeof data261 == "object" && !Array.isArray(data261)){
let missing96;
if(((data261.name === undefined) && (missing96 = "name")) || ((data261.type === undefined) && (missing96 = "type"))){
const err772 = {instancePath:instancePath+"/inspection/details/explanation/columns/" + i25,schemaPath:"#/oneOf/5/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/columns/items/required",keyword:"required",params:{missingProperty: missing96},message:"must have required property '"+missing96+"'"};
if(vErrors === null){
vErrors = [err772];
}
else {
vErrors.push(err772);
}
errors++;
}
else {
const _errs751 = errors;
for(const key96 in data261){
if(!((key96 === "name") || (key96 === "type"))){
const err773 = {instancePath:instancePath+"/inspection/details/explanation/columns/" + i25,schemaPath:"#/oneOf/5/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/columns/items/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key96},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err773];
}
else {
vErrors.push(err773);
}
errors++;
break;
}
}
if(_errs751 === errors){
if(data261.name !== undefined){
let data262 = data261.name;
const _errs752 = errors;
if(errors === _errs752){
if(typeof data262 === "string"){
if(func1(data262) > 131072){
const err774 = {instancePath:instancePath+"/inspection/details/explanation/columns/" + i25+"/name",schemaPath:"#/oneOf/5/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/columns/items/properties/name/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err774];
}
else {
vErrors.push(err774);
}
errors++;
}
}
else {
const err775 = {instancePath:instancePath+"/inspection/details/explanation/columns/" + i25+"/name",schemaPath:"#/oneOf/5/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/columns/items/properties/name/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err775];
}
else {
vErrors.push(err775);
}
errors++;
}
}
var valid142 = _errs752 === errors;
}
else {
var valid142 = true;
}
if(valid142){
if(data261.type !== undefined){
let data263 = data261.type;
const _errs754 = errors;
if(typeof data263 !== "string"){
const err776 = {instancePath:instancePath+"/inspection/details/explanation/columns/" + i25+"/type",schemaPath:"#/oneOf/5/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/columns/items/properties/type/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err776];
}
else {
vErrors.push(err776);
}
errors++;
}
if(!((((((data263 === "int64") || (data263 === "uint64")) || (data263 === "float64")) || (data263 === "boolean")) || (data263 === "utf8")) || (data263 === "binary"))){
const err777 = {instancePath:instancePath+"/inspection/details/explanation/columns/" + i25+"/type",schemaPath:"#/oneOf/5/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/columns/items/properties/type/enum",keyword:"enum",params:{allowedValues: schema33.oneOf[5].properties.inspection.properties.details.oneOf[2].properties.explanation.properties.columns.items.properties.type.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err777];
}
else {
vErrors.push(err777);
}
errors++;
}
var valid142 = _errs754 === errors;
}
else {
var valid142 = true;
}
}
}
}
}
else {
const err778 = {instancePath:instancePath+"/inspection/details/explanation/columns/" + i25,schemaPath:"#/oneOf/5/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/columns/items/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err778];
}
else {
vErrors.push(err778);
}
errors++;
}
}
var valid141 = _errs749 === errors;
if(!valid141){
break;
}
}
}
}
else {
const err779 = {instancePath:instancePath+"/inspection/details/explanation/columns",schemaPath:"#/oneOf/5/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/columns/type",keyword:"type",params:{type: "array"},message:"must be array"};
if(vErrors === null){
vErrors = [err779];
}
else {
vErrors.push(err779);
}
errors++;
}
}
var valid118 = _errs747 === errors;
}
else {
var valid118 = true;
}
if(valid118){
if(data230.budgets !== undefined){
let data264 = data230.budgets;
const _errs756 = errors;
if(errors === _errs756){
if(data264 && typeof data264 == "object" && !Array.isArray(data264)){
let missing97;
if((((data264.pages === undefined) && (missing97 = "pages")) || ((data264.segments === undefined) && (missing97 = "segments"))) || ((data264.result_bytes === undefined) && (missing97 = "result_bytes"))){
const err780 = {instancePath:instancePath+"/inspection/details/explanation/budgets",schemaPath:"#/oneOf/5/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/budgets/required",keyword:"required",params:{missingProperty: missing97},message:"must have required property '"+missing97+"'"};
if(vErrors === null){
vErrors = [err780];
}
else {
vErrors.push(err780);
}
errors++;
}
else {
const _errs758 = errors;
for(const key97 in data264){
if(!(((key97 === "pages") || (key97 === "segments")) || (key97 === "result_bytes"))){
const err781 = {instancePath:instancePath+"/inspection/details/explanation/budgets",schemaPath:"#/oneOf/5/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/budgets/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key97},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err781];
}
else {
vErrors.push(err781);
}
errors++;
break;
}
}
if(_errs758 === errors){
if(data264.pages !== undefined){
let data265 = data264.pages;
const _errs759 = errors;
if(errors === _errs759){
if(typeof data265 === "string"){
if(func1(data265) > 131072){
const err782 = {instancePath:instancePath+"/inspection/details/explanation/budgets/pages",schemaPath:"#/oneOf/5/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/budgets/properties/pages/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err782];
}
else {
vErrors.push(err782);
}
errors++;
}
}
else {
const err783 = {instancePath:instancePath+"/inspection/details/explanation/budgets/pages",schemaPath:"#/oneOf/5/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/budgets/properties/pages/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err783];
}
else {
vErrors.push(err783);
}
errors++;
}
}
var valid143 = _errs759 === errors;
}
else {
var valid143 = true;
}
if(valid143){
if(data264.segments !== undefined){
let data266 = data264.segments;
const _errs761 = errors;
if(errors === _errs761){
if(typeof data266 === "string"){
if(func1(data266) > 131072){
const err784 = {instancePath:instancePath+"/inspection/details/explanation/budgets/segments",schemaPath:"#/oneOf/5/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/budgets/properties/segments/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err784];
}
else {
vErrors.push(err784);
}
errors++;
}
}
else {
const err785 = {instancePath:instancePath+"/inspection/details/explanation/budgets/segments",schemaPath:"#/oneOf/5/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/budgets/properties/segments/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err785];
}
else {
vErrors.push(err785);
}
errors++;
}
}
var valid143 = _errs761 === errors;
}
else {
var valid143 = true;
}
if(valid143){
if(data264.result_bytes !== undefined){
let data267 = data264.result_bytes;
const _errs763 = errors;
if(errors === _errs763){
if(typeof data267 === "string"){
if(func1(data267) > 131072){
const err786 = {instancePath:instancePath+"/inspection/details/explanation/budgets/result_bytes",schemaPath:"#/oneOf/5/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/budgets/properties/result_bytes/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err786];
}
else {
vErrors.push(err786);
}
errors++;
}
}
else {
const err787 = {instancePath:instancePath+"/inspection/details/explanation/budgets/result_bytes",schemaPath:"#/oneOf/5/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/budgets/properties/result_bytes/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err787];
}
else {
vErrors.push(err787);
}
errors++;
}
}
var valid143 = _errs763 === errors;
}
else {
var valid143 = true;
}
}
}
}
}
}
else {
const err788 = {instancePath:instancePath+"/inspection/details/explanation/budgets",schemaPath:"#/oneOf/5/properties/inspection/properties/details/oneOf/2/properties/explanation/properties/budgets/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err788];
}
else {
vErrors.push(err788);
}
errors++;
}
}
var valid118 = _errs756 === errors;
}
else {
var valid118 = true;
}
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
const err789 = {instancePath:instancePath+"/inspection/details/explanation",schemaPath:"#/oneOf/5/properties/inspection/properties/details/oneOf/2/properties/explanation/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err789];
}
else {
vErrors.push(err789);
}
errors++;
}
}
}
}
}
}
else {
const err790 = {instancePath:instancePath+"/inspection/details",schemaPath:"#/oneOf/5/properties/inspection/properties/details/oneOf/2/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err790];
}
else {
vErrors.push(err790);
}
errors++;
}
}
var _valid15 = _errs642 === errors;
if(_valid15 && valid110){
valid110 = false;
passing8 = [passing8, 2];
}
else {
if(_valid15){
valid110 = true;
passing8 = 2;
if(props9 !== true){
props9 = true;
}
}
}
}
if(!valid110){
const err791 = {instancePath:instancePath+"/inspection/details",schemaPath:"#/oneOf/5/properties/inspection/properties/details/oneOf",keyword:"oneOf",params:{passingSchemas: passing8},message:"must match exactly one schema in oneOf"};
if(vErrors === null){
vErrors = [err791];
}
else {
vErrors.push(err791);
}
errors++;
}
else {
errors = _errs619;
if(vErrors !== null){
if(_errs619){
vErrors.length = _errs619;
}
else {
vErrors = null;
}
}
}
var valid107 = _errs618 === errors;
}
else {
var valid107 = true;
}
}
}
}
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
const err792 = {instancePath:instancePath+"/inspection",schemaPath:"#/oneOf/5/properties/inspection/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err792];
}
else {
vErrors.push(err792);
}
errors++;
}
}
}
}
}
}
else {
const err793 = {instancePath,schemaPath:"#/oneOf/5/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err793];
}
else {
vErrors.push(err793);
}
errors++;
}
}
var _valid0 = _errs590 === errors;
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
const _errs765 = errors;
if(errors === _errs765){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing98;
if((data.prepared === undefined) && (missing98 = "prepared")){
const err794 = {instancePath,schemaPath:"#/oneOf/6/required",keyword:"required",params:{missingProperty: missing98},message:"must have required property '"+missing98+"'"};
if(vErrors === null){
vErrors = [err794];
}
else {
vErrors.push(err794);
}
errors++;
}
else {
const _errs767 = errors;
for(const key98 in data){
if(!(key98 === "prepared")){
const err795 = {instancePath,schemaPath:"#/oneOf/6/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key98},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err795];
}
else {
vErrors.push(err795);
}
errors++;
break;
}
}
if(_errs767 === errors){
if(data.prepared !== undefined){
let data268 = data.prepared;
const _errs769 = errors;
let valid145 = false;
const _errs770 = errors;
if(errors === _errs770){
if(data268 && typeof data268 == "object" && !Array.isArray(data268)){
let missing99;
if((data268.token === undefined) && (missing99 = "token")){
const err796 = {instancePath:instancePath+"/prepared",schemaPath:"#/oneOf/6/properties/prepared/anyOf/0/required",keyword:"required",params:{missingProperty: missing99},message:"must have required property '"+missing99+"'"};
if(vErrors === null){
vErrors = [err796];
}
else {
vErrors.push(err796);
}
errors++;
}
else {
const _errs772 = errors;
for(const key99 in data268){
if(!(key99 === "token")){
const err797 = {instancePath:instancePath+"/prepared",schemaPath:"#/oneOf/6/properties/prepared/anyOf/0/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key99},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err797];
}
else {
vErrors.push(err797);
}
errors++;
break;
}
}
if(_errs772 === errors){
if(data268.token !== undefined){
let data269 = data268.token;
const _errs773 = errors;
if(errors === _errs773){
if(typeof data269 === "string"){
if(func1(data269) > 131072){
const err798 = {instancePath:instancePath+"/prepared/token",schemaPath:"#/oneOf/6/properties/prepared/anyOf/0/properties/token/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err798];
}
else {
vErrors.push(err798);
}
errors++;
}
}
else {
const err799 = {instancePath:instancePath+"/prepared/token",schemaPath:"#/oneOf/6/properties/prepared/anyOf/0/properties/token/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err799];
}
else {
vErrors.push(err799);
}
errors++;
}
}
}
}
}
}
else {
const err800 = {instancePath:instancePath+"/prepared",schemaPath:"#/oneOf/6/properties/prepared/anyOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err800];
}
else {
vErrors.push(err800);
}
errors++;
}
}
var _valid20 = _errs770 === errors;
valid145 = valid145 || _valid20;
const _errs775 = errors;
if(data268 !== null){
const err801 = {instancePath:instancePath+"/prepared",schemaPath:"#/oneOf/6/properties/prepared/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err801];
}
else {
vErrors.push(err801);
}
errors++;
}
var _valid20 = _errs775 === errors;
valid145 = valid145 || _valid20;
if(!valid145){
const err802 = {instancePath:instancePath+"/prepared",schemaPath:"#/oneOf/6/properties/prepared/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err802];
}
else {
vErrors.push(err802);
}
errors++;
}
else {
errors = _errs769;
if(vErrors !== null){
if(_errs769){
vErrors.length = _errs769;
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
const err803 = {instancePath,schemaPath:"#/oneOf/6/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err803];
}
else {
vErrors.push(err803);
}
errors++;
}
}
var _valid0 = _errs765 === errors;
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
const _errs777 = errors;
if(errors === _errs777){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing100;
if((data.receipt === undefined) && (missing100 = "receipt")){
const err804 = {instancePath,schemaPath:"#/oneOf/7/required",keyword:"required",params:{missingProperty: missing100},message:"must have required property '"+missing100+"'"};
if(vErrors === null){
vErrors = [err804];
}
else {
vErrors.push(err804);
}
errors++;
}
else {
const _errs779 = errors;
for(const key100 in data){
if(!(key100 === "receipt")){
const err805 = {instancePath,schemaPath:"#/oneOf/7/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key100},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err805];
}
else {
vErrors.push(err805);
}
errors++;
break;
}
}
if(_errs779 === errors){
if(data.receipt !== undefined){
let data270 = data.receipt;
const _errs780 = errors;
if(errors === _errs780){
if(data270 && typeof data270 == "object" && !Array.isArray(data270)){
let missing101;
if((data270.position === undefined) && (missing101 = "position")){
const err806 = {instancePath:instancePath+"/receipt",schemaPath:"#/oneOf/7/properties/receipt/required",keyword:"required",params:{missingProperty: missing101},message:"must have required property '"+missing101+"'"};
if(vErrors === null){
vErrors = [err806];
}
else {
vErrors.push(err806);
}
errors++;
}
else {
const _errs782 = errors;
for(const key101 in data270){
if(!(key101 === "position")){
const err807 = {instancePath:instancePath+"/receipt",schemaPath:"#/oneOf/7/properties/receipt/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key101},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err807];
}
else {
vErrors.push(err807);
}
errors++;
break;
}
}
if(_errs782 === errors){
if(data270.position !== undefined){
let data271 = data270.position;
const _errs783 = errors;
if(!(((typeof data271 == "number") && (!(data271 % 1) && !isNaN(data271))) && (isFinite(data271)))){
const err808 = {instancePath:instancePath+"/receipt/position",schemaPath:"#/oneOf/7/properties/receipt/properties/position/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err808];
}
else {
vErrors.push(err808);
}
errors++;
}
if(errors === _errs783){
if((typeof data271 == "number") && (isFinite(data271))){
if(data271 > 9007199254740991 || isNaN(data271)){
const err809 = {instancePath:instancePath+"/receipt/position",schemaPath:"#/oneOf/7/properties/receipt/properties/position/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"};
if(vErrors === null){
vErrors = [err809];
}
else {
vErrors.push(err809);
}
errors++;
}
else {
if(data271 < 0 || isNaN(data271)){
const err810 = {instancePath:instancePath+"/receipt/position",schemaPath:"#/oneOf/7/properties/receipt/properties/position/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err810];
}
else {
vErrors.push(err810);
}
errors++;
}
}
}
}
}
}
}
}
else {
const err811 = {instancePath:instancePath+"/receipt",schemaPath:"#/oneOf/7/properties/receipt/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err811];
}
else {
vErrors.push(err811);
}
errors++;
}
}
}
}
}
}
else {
const err812 = {instancePath,schemaPath:"#/oneOf/7/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err812];
}
else {
vErrors.push(err812);
}
errors++;
}
}
var _valid0 = _errs777 === errors;
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
const _errs785 = errors;
if(errors === _errs785){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing102;
if((data.observation === undefined) && (missing102 = "observation")){
const err813 = {instancePath,schemaPath:"#/oneOf/8/required",keyword:"required",params:{missingProperty: missing102},message:"must have required property '"+missing102+"'"};
if(vErrors === null){
vErrors = [err813];
}
else {
vErrors.push(err813);
}
errors++;
}
else {
const _errs787 = errors;
for(const key102 in data){
if(!(key102 === "observation")){
const err814 = {instancePath,schemaPath:"#/oneOf/8/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key102},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err814];
}
else {
vErrors.push(err814);
}
errors++;
break;
}
}
if(_errs787 === errors){
if(data.observation !== undefined){
let data272 = data.observation;
const _errs789 = errors;
let valid150 = false;
let passing12 = null;
const _errs790 = errors;
if(errors === _errs790){
if(data272 && typeof data272 == "object" && !Array.isArray(data272)){
let missing103;
if((data272.pending === undefined) && (missing103 = "pending")){
const err815 = {instancePath:instancePath+"/observation",schemaPath:"#/oneOf/8/properties/observation/oneOf/0/required",keyword:"required",params:{missingProperty: missing103},message:"must have required property '"+missing103+"'"};
if(vErrors === null){
vErrors = [err815];
}
else {
vErrors.push(err815);
}
errors++;
}
else {
const _errs792 = errors;
for(const key103 in data272){
if(!(key103 === "pending")){
const err816 = {instancePath:instancePath+"/observation",schemaPath:"#/oneOf/8/properties/observation/oneOf/0/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key103},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err816];
}
else {
vErrors.push(err816);
}
errors++;
break;
}
}
if(_errs792 === errors){
if(data272.pending !== undefined){
let data273 = data272.pending;
const _errs793 = errors;
if(errors === _errs793){
if(data273 && typeof data273 == "object" && !Array.isArray(data273)){
if(Object.keys(data273).length > 0){
const err817 = {instancePath:instancePath+"/observation/pending",schemaPath:"#/oneOf/8/properties/observation/oneOf/0/properties/pending/maxProperties",keyword:"maxProperties",params:{limit: 0},message:"must NOT have more than 0 properties"};
if(vErrors === null){
vErrors = [err817];
}
else {
vErrors.push(err817);
}
errors++;
}
}
else {
const err818 = {instancePath:instancePath+"/observation/pending",schemaPath:"#/oneOf/8/properties/observation/oneOf/0/properties/pending/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err818];
}
else {
vErrors.push(err818);
}
errors++;
}
}
}
}
}
}
else {
const err819 = {instancePath:instancePath+"/observation",schemaPath:"#/oneOf/8/properties/observation/oneOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err819];
}
else {
vErrors.push(err819);
}
errors++;
}
}
var _valid21 = _errs790 === errors;
if(_valid21){
valid150 = true;
passing12 = 0;
var props14 = true;
}
const _errs795 = errors;
if(errors === _errs795){
if(data272 && typeof data272 == "object" && !Array.isArray(data272)){
let missing104;
if((data272.committed === undefined) && (missing104 = "committed")){
const err820 = {instancePath:instancePath+"/observation",schemaPath:"#/oneOf/8/properties/observation/oneOf/1/required",keyword:"required",params:{missingProperty: missing104},message:"must have required property '"+missing104+"'"};
if(vErrors === null){
vErrors = [err820];
}
else {
vErrors.push(err820);
}
errors++;
}
else {
const _errs797 = errors;
for(const key104 in data272){
if(!(key104 === "committed")){
const err821 = {instancePath:instancePath+"/observation",schemaPath:"#/oneOf/8/properties/observation/oneOf/1/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key104},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err821];
}
else {
vErrors.push(err821);
}
errors++;
break;
}
}
if(_errs797 === errors){
if(data272.committed !== undefined){
let data274 = data272.committed;
const _errs798 = errors;
if(errors === _errs798){
if(data274 && typeof data274 == "object" && !Array.isArray(data274)){
if(Object.keys(data274).length > 0){
const err822 = {instancePath:instancePath+"/observation/committed",schemaPath:"#/oneOf/8/properties/observation/oneOf/1/properties/committed/maxProperties",keyword:"maxProperties",params:{limit: 0},message:"must NOT have more than 0 properties"};
if(vErrors === null){
vErrors = [err822];
}
else {
vErrors.push(err822);
}
errors++;
}
}
else {
const err823 = {instancePath:instancePath+"/observation/committed",schemaPath:"#/oneOf/8/properties/observation/oneOf/1/properties/committed/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err823];
}
else {
vErrors.push(err823);
}
errors++;
}
}
}
}
}
}
else {
const err824 = {instancePath:instancePath+"/observation",schemaPath:"#/oneOf/8/properties/observation/oneOf/1/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err824];
}
else {
vErrors.push(err824);
}
errors++;
}
}
var _valid21 = _errs795 === errors;
if(_valid21 && valid150){
valid150 = false;
passing12 = [passing12, 1];
}
else {
if(_valid21){
valid150 = true;
passing12 = 1;
if(props14 !== true){
props14 = true;
}
}
const _errs800 = errors;
if(errors === _errs800){
if(data272 && typeof data272 == "object" && !Array.isArray(data272)){
let missing105;
if((data272.rejected === undefined) && (missing105 = "rejected")){
const err825 = {instancePath:instancePath+"/observation",schemaPath:"#/oneOf/8/properties/observation/oneOf/2/required",keyword:"required",params:{missingProperty: missing105},message:"must have required property '"+missing105+"'"};
if(vErrors === null){
vErrors = [err825];
}
else {
vErrors.push(err825);
}
errors++;
}
else {
const _errs802 = errors;
for(const key105 in data272){
if(!(key105 === "rejected")){
const err826 = {instancePath:instancePath+"/observation",schemaPath:"#/oneOf/8/properties/observation/oneOf/2/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key105},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err826];
}
else {
vErrors.push(err826);
}
errors++;
break;
}
}
if(_errs802 === errors){
if(data272.rejected !== undefined){
let data275 = data272.rejected;
const _errs803 = errors;
if(errors === _errs803){
if(typeof data275 === "string"){
if(func1(data275) > 512){
const err827 = {instancePath:instancePath+"/observation/rejected",schemaPath:"#/oneOf/8/properties/observation/oneOf/2/properties/rejected/maxLength",keyword:"maxLength",params:{limit: 512},message:"must NOT have more than 512 characters"};
if(vErrors === null){
vErrors = [err827];
}
else {
vErrors.push(err827);
}
errors++;
}
else {
if(!pattern4.test(data275)){
const err828 = {instancePath:instancePath+"/observation/rejected",schemaPath:"#/oneOf/8/properties/observation/oneOf/2/properties/rejected/pattern",keyword:"pattern",params:{pattern: "^(?:[0-9a-f]{2})*$"},message:"must match pattern \""+"^(?:[0-9a-f]{2})*$"+"\""};
if(vErrors === null){
vErrors = [err828];
}
else {
vErrors.push(err828);
}
errors++;
}
}
}
else {
const err829 = {instancePath:instancePath+"/observation/rejected",schemaPath:"#/oneOf/8/properties/observation/oneOf/2/properties/rejected/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err829];
}
else {
vErrors.push(err829);
}
errors++;
}
}
}
}
}
}
else {
const err830 = {instancePath:instancePath+"/observation",schemaPath:"#/oneOf/8/properties/observation/oneOf/2/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err830];
}
else {
vErrors.push(err830);
}
errors++;
}
}
var _valid21 = _errs800 === errors;
if(_valid21 && valid150){
valid150 = false;
passing12 = [passing12, 2];
}
else {
if(_valid21){
valid150 = true;
passing12 = 2;
if(props14 !== true){
props14 = true;
}
}
}
}
if(!valid150){
const err831 = {instancePath:instancePath+"/observation",schemaPath:"#/oneOf/8/properties/observation/oneOf",keyword:"oneOf",params:{passingSchemas: passing12},message:"must match exactly one schema in oneOf"};
if(vErrors === null){
vErrors = [err831];
}
else {
vErrors.push(err831);
}
errors++;
}
else {
errors = _errs789;
if(vErrors !== null){
if(_errs789){
vErrors.length = _errs789;
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
const err832 = {instancePath,schemaPath:"#/oneOf/8/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err832];
}
else {
vErrors.push(err832);
}
errors++;
}
}
var _valid0 = _errs785 === errors;
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
const _errs805 = errors;
if(errors === _errs805){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing106;
if((data.status === undefined) && (missing106 = "status")){
const err833 = {instancePath,schemaPath:"#/oneOf/9/required",keyword:"required",params:{missingProperty: missing106},message:"must have required property '"+missing106+"'"};
if(vErrors === null){
vErrors = [err833];
}
else {
vErrors.push(err833);
}
errors++;
}
else {
const _errs807 = errors;
for(const key106 in data){
if(!(key106 === "status")){
const err834 = {instancePath,schemaPath:"#/oneOf/9/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key106},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err834];
}
else {
vErrors.push(err834);
}
errors++;
break;
}
}
if(_errs807 === errors){
if(data.status !== undefined){
let data276 = data.status;
const _errs809 = errors;
let valid155 = false;
const _errs810 = errors;
if(errors === _errs810){
if(data276 && typeof data276 == "object" && !Array.isArray(data276)){
let missing107;
if((((((((data276.reference === undefined) && (missing107 = "reference")) || ((data276.phase === undefined) && (missing107 = "phase"))) || ((data276.correlation === undefined) && (missing107 = "correlation"))) || ((data276.manifest === undefined) && (missing107 = "manifest"))) || ((data276.collected === undefined) && (missing107 = "collected"))) || ((data276.failure === undefined) && (missing107 = "failure"))) || ((data276.diagnostic === undefined) && (missing107 = "diagnostic"))){
const err835 = {instancePath:instancePath+"/status",schemaPath:"#/oneOf/9/properties/status/anyOf/0/required",keyword:"required",params:{missingProperty: missing107},message:"must have required property '"+missing107+"'"};
if(vErrors === null){
vErrors = [err835];
}
else {
vErrors.push(err835);
}
errors++;
}
else {
const _errs812 = errors;
for(const key107 in data276){
if(!(((((((key107 === "reference") || (key107 === "phase")) || (key107 === "correlation")) || (key107 === "manifest")) || (key107 === "collected")) || (key107 === "failure")) || (key107 === "diagnostic"))){
const err836 = {instancePath:instancePath+"/status",schemaPath:"#/oneOf/9/properties/status/anyOf/0/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key107},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err836];
}
else {
vErrors.push(err836);
}
errors++;
break;
}
}
if(_errs812 === errors){
if(data276.reference !== undefined){
let data277 = data276.reference;
const _errs813 = errors;
if(errors === _errs813){
if(typeof data277 === "string"){
if(func1(data277) > 512){
const err837 = {instancePath:instancePath+"/status/reference",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/reference/maxLength",keyword:"maxLength",params:{limit: 512},message:"must NOT have more than 512 characters"};
if(vErrors === null){
vErrors = [err837];
}
else {
vErrors.push(err837);
}
errors++;
}
else {
if(!pattern4.test(data277)){
const err838 = {instancePath:instancePath+"/status/reference",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/reference/pattern",keyword:"pattern",params:{pattern: "^(?:[0-9a-f]{2})*$"},message:"must match pattern \""+"^(?:[0-9a-f]{2})*$"+"\""};
if(vErrors === null){
vErrors = [err838];
}
else {
vErrors.push(err838);
}
errors++;
}
}
}
else {
const err839 = {instancePath:instancePath+"/status/reference",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/reference/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err839];
}
else {
vErrors.push(err839);
}
errors++;
}
}
var valid156 = _errs813 === errors;
}
else {
var valid156 = true;
}
if(valid156){
if(data276.phase !== undefined){
let data278 = data276.phase;
const _errs815 = errors;
if(typeof data278 !== "string"){
const err840 = {instancePath:instancePath+"/status/phase",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/phase/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err840];
}
else {
vErrors.push(err840);
}
errors++;
}
if(!((((((((data278 === "uploading") || (data278 === "sealed")) || (data278 === "admitted")) || (data278 === "complete")) || (data278 === "cancelled")) || (data278 === "denied")) || (data278 === "rejected")) || (data278 === "retired"))){
const err841 = {instancePath:instancePath+"/status/phase",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/phase/enum",keyword:"enum",params:{allowedValues: schema33.oneOf[9].properties.status.anyOf[0].properties.phase.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err841];
}
else {
vErrors.push(err841);
}
errors++;
}
var valid156 = _errs815 === errors;
}
else {
var valid156 = true;
}
if(valid156){
if(data276.correlation !== undefined){
let data279 = data276.correlation;
const _errs817 = errors;
if(errors === _errs817){
if(typeof data279 === "string"){
if(func1(data279) > 131072){
const err842 = {instancePath:instancePath+"/status/correlation",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/correlation/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err842];
}
else {
vErrors.push(err842);
}
errors++;
}
}
else {
const err843 = {instancePath:instancePath+"/status/correlation",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/correlation/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err843];
}
else {
vErrors.push(err843);
}
errors++;
}
}
var valid156 = _errs817 === errors;
}
else {
var valid156 = true;
}
if(valid156){
if(data276.manifest !== undefined){
let data280 = data276.manifest;
const _errs819 = errors;
const _errs820 = errors;
let valid157 = false;
const _errs821 = errors;
if(errors === _errs821){
if(typeof data280 === "string"){
if(func1(data280) > 512){
const err844 = {instancePath:instancePath+"/status/manifest",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/manifest/anyOf/0/maxLength",keyword:"maxLength",params:{limit: 512},message:"must NOT have more than 512 characters"};
if(vErrors === null){
vErrors = [err844];
}
else {
vErrors.push(err844);
}
errors++;
}
else {
if(!pattern4.test(data280)){
const err845 = {instancePath:instancePath+"/status/manifest",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/manifest/anyOf/0/pattern",keyword:"pattern",params:{pattern: "^(?:[0-9a-f]{2})*$"},message:"must match pattern \""+"^(?:[0-9a-f]{2})*$"+"\""};
if(vErrors === null){
vErrors = [err845];
}
else {
vErrors.push(err845);
}
errors++;
}
}
}
else {
const err846 = {instancePath:instancePath+"/status/manifest",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/manifest/anyOf/0/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err846];
}
else {
vErrors.push(err846);
}
errors++;
}
}
var _valid23 = _errs821 === errors;
valid157 = valid157 || _valid23;
const _errs823 = errors;
if(data280 !== null){
const err847 = {instancePath:instancePath+"/status/manifest",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/manifest/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err847];
}
else {
vErrors.push(err847);
}
errors++;
}
var _valid23 = _errs823 === errors;
valid157 = valid157 || _valid23;
if(!valid157){
const err848 = {instancePath:instancePath+"/status/manifest",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/manifest/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err848];
}
else {
vErrors.push(err848);
}
errors++;
}
else {
errors = _errs820;
if(vErrors !== null){
if(_errs820){
vErrors.length = _errs820;
}
else {
vErrors = null;
}
}
}
var valid156 = _errs819 === errors;
}
else {
var valid156 = true;
}
if(valid156){
if(data276.collected !== undefined){
const _errs825 = errors;
if(typeof data276.collected !== "boolean"){
const err849 = {instancePath:instancePath+"/status/collected",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/collected/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"};
if(vErrors === null){
vErrors = [err849];
}
else {
vErrors.push(err849);
}
errors++;
}
var valid156 = _errs825 === errors;
}
else {
var valid156 = true;
}
if(valid156){
if(data276.failure !== undefined){
let data282 = data276.failure;
const _errs827 = errors;
const _errs828 = errors;
let valid158 = false;
const _errs829 = errors;
if(errors === _errs829){
if(data282 && typeof data282 == "object" && !Array.isArray(data282)){
let missing108;
if((((((data282.code === undefined) && (missing108 = "code")) || ((data282.stage === undefined) && (missing108 = "stage"))) || ((data282.dimension === undefined) && (missing108 = "dimension"))) || ((data282.limit === undefined) && (missing108 = "limit"))) || ((data282.observed === undefined) && (missing108 = "observed"))){
const err850 = {instancePath:instancePath+"/status/failure",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/failure/anyOf/0/required",keyword:"required",params:{missingProperty: missing108},message:"must have required property '"+missing108+"'"};
if(vErrors === null){
vErrors = [err850];
}
else {
vErrors.push(err850);
}
errors++;
}
else {
const _errs831 = errors;
for(const key108 in data282){
if(!(((((key108 === "code") || (key108 === "stage")) || (key108 === "dimension")) || (key108 === "limit")) || (key108 === "observed"))){
const err851 = {instancePath:instancePath+"/status/failure",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/failure/anyOf/0/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key108},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err851];
}
else {
vErrors.push(err851);
}
errors++;
break;
}
}
if(_errs831 === errors){
if(data282.code !== undefined){
let data283 = data282.code;
const _errs832 = errors;
if(typeof data283 !== "string"){
const err852 = {instancePath:instancePath+"/status/failure/code",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/failure/anyOf/0/properties/code/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err852];
}
else {
vErrors.push(err852);
}
errors++;
}
if(!((((((((((((((((((((((((((((((((((((((((((((((((((((((((((data283 === "policy_denied") || (data283 === "access_denied")) || (data283 === "resource_unavailable")) || (data283 === "request_unpublished")) || (data283 === "publisher_mismatch")) || (data283 === "document_history_gap")) || (data283 === "document_retired")) || (data283 === "document_resync_required")) || (data283 === "budget_exceeded")) || (data283 === "projection_budget")) || (data283 === "expansion_missing")) || (data283 === "expansion_null")) || (data283 === "expansion_conflict")) || (data283 === "expansion_type_error")) || (data283 === "cell_type_error")) || (data283 === "cell_conflict")) || (data283 === "arithmetic_overflow")) || (data283 === "segment_byte_limit")) || (data283 === "type_mismatch")) || (data283 === "unsupported_aggregate")) || (data283 === "unknown_column")) || (data283 === "invalid_projection")) || (data283 === "duplicate_projection")) || (data283 === "invalid_bundle")) || (data283 === "invalid_source")) || (data283 === "invalid_prefix")) || (data283 === "invalid_path")) || (data283 === "invalid_projection_budget")) || (data283 === "invalid_text_projection")) || (data283 === "invalid_element_projection")) || (data283 === "unsupported_source")) || (data283 === "unsupported_decoder")) || (data283 === "unsupported_document_source")) || (data283 === "invalid_source_encoding")) || (data283 === "invalid_plan_encoding")) || (data283 === "plan_definition_mismatch")) || (data283 === "invalid_output_names")) || (data283 === "unsupported_plan")) || (data283 === "plan_too_large")) || (data283 === "bundle_too_large")) || (data283 === "truncated_input")) || (data283 === "source_changed")) || (data283 === "table_schema_changed")) || (data283 === "invalid_budget")) || (data283 === "namespace_in_use")) || (data283 === "query_after_mutation")) || (data283 === "nonfinite_value")) || (data283 === "invalid_utf8")) || (data283 === "cell_too_large")) || (data283 === "invalid_column_name")) || (data283 === "invalid_column_count")) || (data283 === "duplicate_column")) || (data283 === "unsupported_schema")) || (data283 === "peer_mismatch")) || (data283 === "invalid_request_reference")) || (data283 === "writer_not_ready")) || (data283 === "request_resource_expired")) || (data283 === "request_resource_missing"))){
const err853 = {instancePath:instancePath+"/status/failure/code",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/failure/anyOf/0/properties/code/enum",keyword:"enum",params:{allowedValues: schema33.oneOf[9].properties.status.anyOf[0].properties.failure.anyOf[0].properties.code.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err853];
}
else {
vErrors.push(err853);
}
errors++;
}
var valid159 = _errs832 === errors;
}
else {
var valid159 = true;
}
if(valid159){
if(data282.stage !== undefined){
let data284 = data282.stage;
const _errs834 = errors;
if(typeof data284 !== "string"){
const err854 = {instancePath:instancePath+"/status/failure/stage",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/failure/anyOf/0/properties/stage/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err854];
}
else {
vErrors.push(err854);
}
errors++;
}
if(!((data284 === "admission") || (data284 === "execution"))){
const err855 = {instancePath:instancePath+"/status/failure/stage",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/failure/anyOf/0/properties/stage/enum",keyword:"enum",params:{allowedValues: schema33.oneOf[9].properties.status.anyOf[0].properties.failure.anyOf[0].properties.stage.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err855];
}
else {
vErrors.push(err855);
}
errors++;
}
var valid159 = _errs834 === errors;
}
else {
var valid159 = true;
}
if(valid159){
if(data282.dimension !== undefined){
let data285 = data282.dimension;
const _errs836 = errors;
if(typeof data285 !== "string"){
const err856 = {instancePath:instancePath+"/status/failure/dimension",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/failure/anyOf/0/properties/dimension/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err856];
}
else {
vErrors.push(err856);
}
errors++;
}
if(!((((data285 === "none") || (data285 === "pages")) || (data285 === "segments")) || (data285 === "result_bytes"))){
const err857 = {instancePath:instancePath+"/status/failure/dimension",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/failure/anyOf/0/properties/dimension/enum",keyword:"enum",params:{allowedValues: schema33.oneOf[9].properties.status.anyOf[0].properties.failure.anyOf[0].properties.dimension.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err857];
}
else {
vErrors.push(err857);
}
errors++;
}
var valid159 = _errs836 === errors;
}
else {
var valid159 = true;
}
if(valid159){
if(data282.limit !== undefined){
let data286 = data282.limit;
const _errs838 = errors;
if(errors === _errs838){
if(typeof data286 === "string"){
if(func1(data286) > 131072){
const err858 = {instancePath:instancePath+"/status/failure/limit",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/failure/anyOf/0/properties/limit/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err858];
}
else {
vErrors.push(err858);
}
errors++;
}
}
else {
const err859 = {instancePath:instancePath+"/status/failure/limit",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/failure/anyOf/0/properties/limit/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err859];
}
else {
vErrors.push(err859);
}
errors++;
}
}
var valid159 = _errs838 === errors;
}
else {
var valid159 = true;
}
if(valid159){
if(data282.observed !== undefined){
let data287 = data282.observed;
const _errs840 = errors;
if(errors === _errs840){
if(typeof data287 === "string"){
if(func1(data287) > 131072){
const err860 = {instancePath:instancePath+"/status/failure/observed",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/failure/anyOf/0/properties/observed/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err860];
}
else {
vErrors.push(err860);
}
errors++;
}
}
else {
const err861 = {instancePath:instancePath+"/status/failure/observed",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/failure/anyOf/0/properties/observed/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err861];
}
else {
vErrors.push(err861);
}
errors++;
}
}
var valid159 = _errs840 === errors;
}
else {
var valid159 = true;
}
}
}
}
}
}
}
}
else {
const err862 = {instancePath:instancePath+"/status/failure",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/failure/anyOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err862];
}
else {
vErrors.push(err862);
}
errors++;
}
}
var _valid24 = _errs829 === errors;
valid158 = valid158 || _valid24;
const _errs842 = errors;
if(data282 !== null){
const err863 = {instancePath:instancePath+"/status/failure",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/failure/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err863];
}
else {
vErrors.push(err863);
}
errors++;
}
var _valid24 = _errs842 === errors;
valid158 = valid158 || _valid24;
if(!valid158){
const err864 = {instancePath:instancePath+"/status/failure",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/failure/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err864];
}
else {
vErrors.push(err864);
}
errors++;
}
else {
errors = _errs828;
if(vErrors !== null){
if(_errs828){
vErrors.length = _errs828;
}
else {
vErrors = null;
}
}
}
var valid156 = _errs827 === errors;
}
else {
var valid156 = true;
}
if(valid156){
if(data276.diagnostic !== undefined){
let data288 = data276.diagnostic;
const _errs844 = errors;
const _errs845 = errors;
let valid160 = false;
const _errs846 = errors;
if(errors === _errs846){
if(data288 && typeof data288 == "object" && !Array.isArray(data288)){
let missing109;
if((((((((((((((data288.version === undefined) && (missing109 = "version")) || ((data288.definition === undefined) && (missing109 = "definition"))) || ((data288.code === undefined) && (missing109 = "code"))) || ((data288.category === undefined) && (missing109 = "category"))) || ((data288.stage === undefined) && (missing109 = "stage"))) || ((data288.outcome === undefined) && (missing109 = "outcome"))) || ((data288.evidence === undefined) && (missing109 = "evidence"))) || ((data288.message === undefined) && (missing109 = "message"))) || ((data288.cause === undefined) && (missing109 = "cause"))) || ((data288.identity === undefined) && (missing109 = "identity"))) || ((data288.location === undefined) && (missing109 = "location"))) || ((data288.facts === undefined) && (missing109 = "facts"))) || ((data288.actions === undefined) && (missing109 = "actions"))){
const err865 = {instancePath:instancePath+"/status/diagnostic",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/diagnostic/anyOf/0/required",keyword:"required",params:{missingProperty: missing109},message:"must have required property '"+missing109+"'"};
if(vErrors === null){
vErrors = [err865];
}
else {
vErrors.push(err865);
}
errors++;
}
else {
const _errs848 = errors;
for(const key109 in data288){
if(!(func24.call(schema33.oneOf[9].properties.status.anyOf[0].properties.diagnostic.anyOf[0].properties, key109))){
const err866 = {instancePath:instancePath+"/status/diagnostic",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/diagnostic/anyOf/0/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key109},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err866];
}
else {
vErrors.push(err866);
}
errors++;
break;
}
}
if(_errs848 === errors){
if(data288.version !== undefined){
const _errs849 = errors;
if(1 !== data288.version){
const err867 = {instancePath:instancePath+"/status/diagnostic/version",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/diagnostic/anyOf/0/properties/version/const",keyword:"const",params:{allowedValue: 1},message:"must be equal to constant"};
if(vErrors === null){
vErrors = [err867];
}
else {
vErrors.push(err867);
}
errors++;
}
var valid161 = _errs849 === errors;
}
else {
var valid161 = true;
}
if(valid161){
if(data288.definition !== undefined){
let data290 = data288.definition;
const _errs850 = errors;
if(typeof data290 !== "string"){
const err868 = {instancePath:instancePath+"/status/diagnostic/definition",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/diagnostic/anyOf/0/properties/definition/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err868];
}
else {
vErrors.push(err868);
}
errors++;
}
if(!(data290 === "c750e7034f20d2446bfe44c7ad19a3ca45b415a0a02754523dc280cf74e20d15")){
const err869 = {instancePath:instancePath+"/status/diagnostic/definition",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/diagnostic/anyOf/0/properties/definition/enum",keyword:"enum",params:{allowedValues: schema33.oneOf[9].properties.status.anyOf[0].properties.diagnostic.anyOf[0].properties.definition.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err869];
}
else {
vErrors.push(err869);
}
errors++;
}
var valid161 = _errs850 === errors;
}
else {
var valid161 = true;
}
if(valid161){
if(data288.code !== undefined){
let data291 = data288.code;
const _errs852 = errors;
if(errors === _errs852){
if(typeof data291 === "string"){
if(func1(data291) > 96){
const err870 = {instancePath:instancePath+"/status/diagnostic/code",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/diagnostic/anyOf/0/properties/code/maxLength",keyword:"maxLength",params:{limit: 96},message:"must NOT have more than 96 characters"};
if(vErrors === null){
vErrors = [err870];
}
else {
vErrors.push(err870);
}
errors++;
}
}
else {
const err871 = {instancePath:instancePath+"/status/diagnostic/code",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/diagnostic/anyOf/0/properties/code/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err871];
}
else {
vErrors.push(err871);
}
errors++;
}
}
var valid161 = _errs852 === errors;
}
else {
var valid161 = true;
}
if(valid161){
if(data288.category !== undefined){
let data292 = data288.category;
const _errs854 = errors;
if(typeof data292 !== "string"){
const err872 = {instancePath:instancePath+"/status/diagnostic/category",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/diagnostic/anyOf/0/properties/category/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err872];
}
else {
vErrors.push(err872);
}
errors++;
}
if(!(((((((((((data292 === "syntax") || (data292 === "binding")) || (data292 === "unsupported")) || (data292 === "constraint")) || (data292 === "access")) || (data292 === "conflict")) || (data292 === "limit")) || (data292 === "lifecycle")) || (data292 === "integrity")) || (data292 === "unavailable")) || (data292 === "internal"))){
const err873 = {instancePath:instancePath+"/status/diagnostic/category",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/diagnostic/anyOf/0/properties/category/enum",keyword:"enum",params:{allowedValues: schema33.oneOf[9].properties.status.anyOf[0].properties.diagnostic.anyOf[0].properties.category.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err873];
}
else {
vErrors.push(err873);
}
errors++;
}
var valid161 = _errs854 === errors;
}
else {
var valid161 = true;
}
if(valid161){
if(data288.stage !== undefined){
let data293 = data288.stage;
const _errs856 = errors;
if(typeof data293 !== "string"){
const err874 = {instancePath:instancePath+"/status/diagnostic/stage",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/diagnostic/anyOf/0/properties/stage/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err874];
}
else {
vErrors.push(err874);
}
errors++;
}
if(!((((((((((((((data293 === "input") || (data293 === "parse")) || (data293 === "compile")) || (data293 === "bind")) || (data293 === "prepare")) || (data293 === "submit")) || (data293 === "admission")) || (data293 === "execute")) || (data293 === "read")) || (data293 === "decode")) || (data293 === "output")) || (data293 === "reconcile")) || (data293 === "cleanup")) || (data293 === "control"))){
const err875 = {instancePath:instancePath+"/status/diagnostic/stage",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/diagnostic/anyOf/0/properties/stage/enum",keyword:"enum",params:{allowedValues: schema33.oneOf[9].properties.status.anyOf[0].properties.diagnostic.anyOf[0].properties.stage.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err875];
}
else {
vErrors.push(err875);
}
errors++;
}
var valid161 = _errs856 === errors;
}
else {
var valid161 = true;
}
if(valid161){
if(data288.outcome !== undefined){
let data294 = data288.outcome;
const _errs858 = errors;
if(typeof data294 !== "string"){
const err876 = {instancePath:instancePath+"/status/diagnostic/outcome",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/diagnostic/anyOf/0/properties/outcome/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err876];
}
else {
vErrors.push(err876);
}
errors++;
}
if(!(((((((((((data294 === "not_applicable") || (data294 === "not_submitted")) || (data294 === "prepared")) || (data294 === "unknown")) || (data294 === "pending")) || (data294 === "input_rejected")) || (data294 === "rejected")) || (data294 === "applied")) || (data294 === "cancelled")) || (data294 === "retired")) || (data294 === "closed_unknown"))){
const err877 = {instancePath:instancePath+"/status/diagnostic/outcome",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/diagnostic/anyOf/0/properties/outcome/enum",keyword:"enum",params:{allowedValues: schema33.oneOf[9].properties.status.anyOf[0].properties.diagnostic.anyOf[0].properties.outcome.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err877];
}
else {
vErrors.push(err877);
}
errors++;
}
var valid161 = _errs858 === errors;
}
else {
var valid161 = true;
}
if(valid161){
if(data288.evidence !== undefined){
let data295 = data288.evidence;
const _errs860 = errors;
if(typeof data295 !== "string"){
const err878 = {instancePath:instancePath+"/status/diagnostic/evidence",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/diagnostic/anyOf/0/properties/evidence/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err878];
}
else {
vErrors.push(err878);
}
errors++;
}
if(!(((((data295 === "none") || (data295 === "local_before_dispatch")) || (data295 === "saved_intent")) || (data295 === "native_receipt")) || (data295 === "domain_status"))){
const err879 = {instancePath:instancePath+"/status/diagnostic/evidence",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/diagnostic/anyOf/0/properties/evidence/enum",keyword:"enum",params:{allowedValues: schema33.oneOf[9].properties.status.anyOf[0].properties.diagnostic.anyOf[0].properties.evidence.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err879];
}
else {
vErrors.push(err879);
}
errors++;
}
var valid161 = _errs860 === errors;
}
else {
var valid161 = true;
}
if(valid161){
if(data288.message !== undefined){
let data296 = data288.message;
const _errs862 = errors;
if(errors === _errs862){
if(typeof data296 === "string"){
if(func1(data296) > 384){
const err880 = {instancePath:instancePath+"/status/diagnostic/message",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/diagnostic/anyOf/0/properties/message/maxLength",keyword:"maxLength",params:{limit: 384},message:"must NOT have more than 384 characters"};
if(vErrors === null){
vErrors = [err880];
}
else {
vErrors.push(err880);
}
errors++;
}
}
else {
const err881 = {instancePath:instancePath+"/status/diagnostic/message",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/diagnostic/anyOf/0/properties/message/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err881];
}
else {
vErrors.push(err881);
}
errors++;
}
}
var valid161 = _errs862 === errors;
}
else {
var valid161 = true;
}
if(valid161){
if(data288.cause !== undefined){
let data297 = data288.cause;
const _errs864 = errors;
const _errs865 = errors;
let valid162 = false;
const _errs866 = errors;
if(errors === _errs866){
if(typeof data297 === "string"){
if(func1(data297) > 96){
const err882 = {instancePath:instancePath+"/status/diagnostic/cause",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/diagnostic/anyOf/0/properties/cause/anyOf/0/maxLength",keyword:"maxLength",params:{limit: 96},message:"must NOT have more than 96 characters"};
if(vErrors === null){
vErrors = [err882];
}
else {
vErrors.push(err882);
}
errors++;
}
}
else {
const err883 = {instancePath:instancePath+"/status/diagnostic/cause",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/diagnostic/anyOf/0/properties/cause/anyOf/0/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err883];
}
else {
vErrors.push(err883);
}
errors++;
}
}
var _valid26 = _errs866 === errors;
valid162 = valid162 || _valid26;
const _errs868 = errors;
if(data297 !== null){
const err884 = {instancePath:instancePath+"/status/diagnostic/cause",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/diagnostic/anyOf/0/properties/cause/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err884];
}
else {
vErrors.push(err884);
}
errors++;
}
var _valid26 = _errs868 === errors;
valid162 = valid162 || _valid26;
if(!valid162){
const err885 = {instancePath:instancePath+"/status/diagnostic/cause",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/diagnostic/anyOf/0/properties/cause/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err885];
}
else {
vErrors.push(err885);
}
errors++;
}
else {
errors = _errs865;
if(vErrors !== null){
if(_errs865){
vErrors.length = _errs865;
}
else {
vErrors = null;
}
}
}
var valid161 = _errs864 === errors;
}
else {
var valid161 = true;
}
if(valid161){
if(data288.identity !== undefined){
let data298 = data288.identity;
const _errs870 = errors;
const _errs871 = errors;
let valid163 = false;
const _errs872 = errors;
if(errors === _errs872){
if(data298 && typeof data298 == "object" && !Array.isArray(data298)){
let missing110;
if((((((data298.domain === undefined) && (missing110 = "domain")) || ((data298.id === undefined) && (missing110 = "id"))) || ((data298.realm === undefined) && (missing110 = "realm"))) || ((data298.resource === undefined) && (missing110 = "resource"))) || ((data298.sequence === undefined) && (missing110 = "sequence"))){
const err886 = {instancePath:instancePath+"/status/diagnostic/identity",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/diagnostic/anyOf/0/properties/identity/anyOf/0/required",keyword:"required",params:{missingProperty: missing110},message:"must have required property '"+missing110+"'"};
if(vErrors === null){
vErrors = [err886];
}
else {
vErrors.push(err886);
}
errors++;
}
else {
const _errs874 = errors;
for(const key110 in data298){
if(!(((((key110 === "domain") || (key110 === "id")) || (key110 === "realm")) || (key110 === "resource")) || (key110 === "sequence"))){
const err887 = {instancePath:instancePath+"/status/diagnostic/identity",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/diagnostic/anyOf/0/properties/identity/anyOf/0/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key110},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err887];
}
else {
vErrors.push(err887);
}
errors++;
break;
}
}
if(_errs874 === errors){
if(data298.domain !== undefined){
let data299 = data298.domain;
const _errs875 = errors;
if(typeof data299 !== "string"){
const err888 = {instancePath:instancePath+"/status/diagnostic/identity/domain",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/diagnostic/anyOf/0/properties/identity/anyOf/0/properties/domain/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err888];
}
else {
vErrors.push(err888);
}
errors++;
}
if(!(((((((((((data299 === "sql") || (data299 === "query")) || (data299 === "mutation")) || (data299 === "catalog")) || (data299 === "application")) || (data299 === "publication")) || (data299 === "migration")) || (data299 === "reactive")) || (data299 === "effect")) || (data299 === "transport")) || (data299 === "internal"))){
const err889 = {instancePath:instancePath+"/status/diagnostic/identity/domain",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/diagnostic/anyOf/0/properties/identity/anyOf/0/properties/domain/enum",keyword:"enum",params:{allowedValues: schema33.oneOf[9].properties.status.anyOf[0].properties.diagnostic.anyOf[0].properties.identity.anyOf[0].properties.domain.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err889];
}
else {
vErrors.push(err889);
}
errors++;
}
var valid164 = _errs875 === errors;
}
else {
var valid164 = true;
}
if(valid164){
if(data298.id !== undefined){
let data300 = data298.id;
const _errs877 = errors;
if(errors === _errs877){
if(typeof data300 === "string"){
if(func1(data300) > 20){
const err890 = {instancePath:instancePath+"/status/diagnostic/identity/id",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/diagnostic/anyOf/0/properties/identity/anyOf/0/properties/id/maxLength",keyword:"maxLength",params:{limit: 20},message:"must NOT have more than 20 characters"};
if(vErrors === null){
vErrors = [err890];
}
else {
vErrors.push(err890);
}
errors++;
}
else {
if(!pattern7.test(data300)){
const err891 = {instancePath:instancePath+"/status/diagnostic/identity/id",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/diagnostic/anyOf/0/properties/identity/anyOf/0/properties/id/pattern",keyword:"pattern",params:{pattern: "^(0|[1-9][0-9]*)$"},message:"must match pattern \""+"^(0|[1-9][0-9]*)$"+"\""};
if(vErrors === null){
vErrors = [err891];
}
else {
vErrors.push(err891);
}
errors++;
}
}
}
else {
const err892 = {instancePath:instancePath+"/status/diagnostic/identity/id",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/diagnostic/anyOf/0/properties/identity/anyOf/0/properties/id/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err892];
}
else {
vErrors.push(err892);
}
errors++;
}
}
var valid164 = _errs877 === errors;
}
else {
var valid164 = true;
}
if(valid164){
if(data298.realm !== undefined){
let data301 = data298.realm;
const _errs879 = errors;
const _errs880 = errors;
let valid165 = false;
const _errs881 = errors;
if(errors === _errs881){
if(typeof data301 === "string"){
if(func1(data301) > 20){
const err893 = {instancePath:instancePath+"/status/diagnostic/identity/realm",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/diagnostic/anyOf/0/properties/identity/anyOf/0/properties/realm/anyOf/0/maxLength",keyword:"maxLength",params:{limit: 20},message:"must NOT have more than 20 characters"};
if(vErrors === null){
vErrors = [err893];
}
else {
vErrors.push(err893);
}
errors++;
}
else {
if(!pattern7.test(data301)){
const err894 = {instancePath:instancePath+"/status/diagnostic/identity/realm",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/diagnostic/anyOf/0/properties/identity/anyOf/0/properties/realm/anyOf/0/pattern",keyword:"pattern",params:{pattern: "^(0|[1-9][0-9]*)$"},message:"must match pattern \""+"^(0|[1-9][0-9]*)$"+"\""};
if(vErrors === null){
vErrors = [err894];
}
else {
vErrors.push(err894);
}
errors++;
}
}
}
else {
const err895 = {instancePath:instancePath+"/status/diagnostic/identity/realm",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/diagnostic/anyOf/0/properties/identity/anyOf/0/properties/realm/anyOf/0/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err895];
}
else {
vErrors.push(err895);
}
errors++;
}
}
var _valid28 = _errs881 === errors;
valid165 = valid165 || _valid28;
const _errs883 = errors;
if(data301 !== null){
const err896 = {instancePath:instancePath+"/status/diagnostic/identity/realm",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/diagnostic/anyOf/0/properties/identity/anyOf/0/properties/realm/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err896];
}
else {
vErrors.push(err896);
}
errors++;
}
var _valid28 = _errs883 === errors;
valid165 = valid165 || _valid28;
if(!valid165){
const err897 = {instancePath:instancePath+"/status/diagnostic/identity/realm",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/diagnostic/anyOf/0/properties/identity/anyOf/0/properties/realm/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err897];
}
else {
vErrors.push(err897);
}
errors++;
}
else {
errors = _errs880;
if(vErrors !== null){
if(_errs880){
vErrors.length = _errs880;
}
else {
vErrors = null;
}
}
}
var valid164 = _errs879 === errors;
}
else {
var valid164 = true;
}
if(valid164){
if(data298.resource !== undefined){
let data302 = data298.resource;
const _errs885 = errors;
const _errs886 = errors;
let valid166 = false;
const _errs887 = errors;
if(errors === _errs887){
if(typeof data302 === "string"){
if(func1(data302) > 20){
const err898 = {instancePath:instancePath+"/status/diagnostic/identity/resource",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/diagnostic/anyOf/0/properties/identity/anyOf/0/properties/resource/anyOf/0/maxLength",keyword:"maxLength",params:{limit: 20},message:"must NOT have more than 20 characters"};
if(vErrors === null){
vErrors = [err898];
}
else {
vErrors.push(err898);
}
errors++;
}
else {
if(!pattern7.test(data302)){
const err899 = {instancePath:instancePath+"/status/diagnostic/identity/resource",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/diagnostic/anyOf/0/properties/identity/anyOf/0/properties/resource/anyOf/0/pattern",keyword:"pattern",params:{pattern: "^(0|[1-9][0-9]*)$"},message:"must match pattern \""+"^(0|[1-9][0-9]*)$"+"\""};
if(vErrors === null){
vErrors = [err899];
}
else {
vErrors.push(err899);
}
errors++;
}
}
}
else {
const err900 = {instancePath:instancePath+"/status/diagnostic/identity/resource",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/diagnostic/anyOf/0/properties/identity/anyOf/0/properties/resource/anyOf/0/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err900];
}
else {
vErrors.push(err900);
}
errors++;
}
}
var _valid29 = _errs887 === errors;
valid166 = valid166 || _valid29;
const _errs889 = errors;
if(data302 !== null){
const err901 = {instancePath:instancePath+"/status/diagnostic/identity/resource",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/diagnostic/anyOf/0/properties/identity/anyOf/0/properties/resource/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err901];
}
else {
vErrors.push(err901);
}
errors++;
}
var _valid29 = _errs889 === errors;
valid166 = valid166 || _valid29;
if(!valid166){
const err902 = {instancePath:instancePath+"/status/diagnostic/identity/resource",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/diagnostic/anyOf/0/properties/identity/anyOf/0/properties/resource/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err902];
}
else {
vErrors.push(err902);
}
errors++;
}
else {
errors = _errs886;
if(vErrors !== null){
if(_errs886){
vErrors.length = _errs886;
}
else {
vErrors = null;
}
}
}
var valid164 = _errs885 === errors;
}
else {
var valid164 = true;
}
if(valid164){
if(data298.sequence !== undefined){
let data303 = data298.sequence;
const _errs891 = errors;
const _errs892 = errors;
let valid167 = false;
const _errs893 = errors;
if(errors === _errs893){
if(typeof data303 === "string"){
if(func1(data303) > 20){
const err903 = {instancePath:instancePath+"/status/diagnostic/identity/sequence",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/diagnostic/anyOf/0/properties/identity/anyOf/0/properties/sequence/anyOf/0/maxLength",keyword:"maxLength",params:{limit: 20},message:"must NOT have more than 20 characters"};
if(vErrors === null){
vErrors = [err903];
}
else {
vErrors.push(err903);
}
errors++;
}
else {
if(!pattern7.test(data303)){
const err904 = {instancePath:instancePath+"/status/diagnostic/identity/sequence",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/diagnostic/anyOf/0/properties/identity/anyOf/0/properties/sequence/anyOf/0/pattern",keyword:"pattern",params:{pattern: "^(0|[1-9][0-9]*)$"},message:"must match pattern \""+"^(0|[1-9][0-9]*)$"+"\""};
if(vErrors === null){
vErrors = [err904];
}
else {
vErrors.push(err904);
}
errors++;
}
}
}
else {
const err905 = {instancePath:instancePath+"/status/diagnostic/identity/sequence",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/diagnostic/anyOf/0/properties/identity/anyOf/0/properties/sequence/anyOf/0/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err905];
}
else {
vErrors.push(err905);
}
errors++;
}
}
var _valid30 = _errs893 === errors;
valid167 = valid167 || _valid30;
const _errs895 = errors;
if(data303 !== null){
const err906 = {instancePath:instancePath+"/status/diagnostic/identity/sequence",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/diagnostic/anyOf/0/properties/identity/anyOf/0/properties/sequence/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err906];
}
else {
vErrors.push(err906);
}
errors++;
}
var _valid30 = _errs895 === errors;
valid167 = valid167 || _valid30;
if(!valid167){
const err907 = {instancePath:instancePath+"/status/diagnostic/identity/sequence",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/diagnostic/anyOf/0/properties/identity/anyOf/0/properties/sequence/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err907];
}
else {
vErrors.push(err907);
}
errors++;
}
else {
errors = _errs892;
if(vErrors !== null){
if(_errs892){
vErrors.length = _errs892;
}
else {
vErrors = null;
}
}
}
var valid164 = _errs891 === errors;
}
else {
var valid164 = true;
}
}
}
}
}
}
}
}
else {
const err908 = {instancePath:instancePath+"/status/diagnostic/identity",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/diagnostic/anyOf/0/properties/identity/anyOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err908];
}
else {
vErrors.push(err908);
}
errors++;
}
}
var _valid27 = _errs872 === errors;
valid163 = valid163 || _valid27;
const _errs897 = errors;
if(data298 !== null){
const err909 = {instancePath:instancePath+"/status/diagnostic/identity",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/diagnostic/anyOf/0/properties/identity/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err909];
}
else {
vErrors.push(err909);
}
errors++;
}
var _valid27 = _errs897 === errors;
valid163 = valid163 || _valid27;
if(!valid163){
const err910 = {instancePath:instancePath+"/status/diagnostic/identity",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/diagnostic/anyOf/0/properties/identity/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err910];
}
else {
vErrors.push(err910);
}
errors++;
}
else {
errors = _errs871;
if(vErrors !== null){
if(_errs871){
vErrors.length = _errs871;
}
else {
vErrors = null;
}
}
}
var valid161 = _errs870 === errors;
}
else {
var valid161 = true;
}
if(valid161){
if(data288.location !== undefined){
let data304 = data288.location;
const _errs899 = errors;
const _errs900 = errors;
let valid168 = false;
const _errs901 = errors;
if(errors === _errs901){
if(data304 && typeof data304 == "object" && !Array.isArray(data304)){
let missing111;
if(((((((((data304.source === undefined) && (missing111 = "source")) || ((data304.source_encoding === undefined) && (missing111 = "source_encoding"))) || ((data304.source_truncated === undefined) && (missing111 = "source_truncated"))) || ((data304.statement === undefined) && (missing111 = "statement"))) || ((data304.offset === undefined) && (missing111 = "offset"))) || ((data304.length === undefined) && (missing111 = "length"))) || ((data304.line === undefined) && (missing111 = "line"))) || ((data304.byte_column === undefined) && (missing111 = "byte_column"))){
const err911 = {instancePath:instancePath+"/status/diagnostic/location",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/diagnostic/anyOf/0/properties/location/anyOf/0/required",keyword:"required",params:{missingProperty: missing111},message:"must have required property '"+missing111+"'"};
if(vErrors === null){
vErrors = [err911];
}
else {
vErrors.push(err911);
}
errors++;
}
else {
const _errs903 = errors;
for(const key111 in data304){
if(!((((((((key111 === "source") || (key111 === "source_encoding")) || (key111 === "source_truncated")) || (key111 === "statement")) || (key111 === "offset")) || (key111 === "length")) || (key111 === "line")) || (key111 === "byte_column"))){
const err912 = {instancePath:instancePath+"/status/diagnostic/location",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/diagnostic/anyOf/0/properties/location/anyOf/0/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key111},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err912];
}
else {
vErrors.push(err912);
}
errors++;
break;
}
}
if(_errs903 === errors){
if(data304.source !== undefined){
let data305 = data304.source;
const _errs904 = errors;
const _errs905 = errors;
let valid170 = false;
const _errs906 = errors;
if(errors === _errs906){
if(typeof data305 === "string"){
if(func1(data305) > 512){
const err913 = {instancePath:instancePath+"/status/diagnostic/location/source",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/diagnostic/anyOf/0/properties/location/anyOf/0/properties/source/anyOf/0/maxLength",keyword:"maxLength",params:{limit: 512},message:"must NOT have more than 512 characters"};
if(vErrors === null){
vErrors = [err913];
}
else {
vErrors.push(err913);
}
errors++;
}
}
else {
const err914 = {instancePath:instancePath+"/status/diagnostic/location/source",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/diagnostic/anyOf/0/properties/location/anyOf/0/properties/source/anyOf/0/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err914];
}
else {
vErrors.push(err914);
}
errors++;
}
}
var _valid32 = _errs906 === errors;
valid170 = valid170 || _valid32;
const _errs908 = errors;
if(data305 !== null){
const err915 = {instancePath:instancePath+"/status/diagnostic/location/source",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/diagnostic/anyOf/0/properties/location/anyOf/0/properties/source/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err915];
}
else {
vErrors.push(err915);
}
errors++;
}
var _valid32 = _errs908 === errors;
valid170 = valid170 || _valid32;
if(!valid170){
const err916 = {instancePath:instancePath+"/status/diagnostic/location/source",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/diagnostic/anyOf/0/properties/location/anyOf/0/properties/source/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err916];
}
else {
vErrors.push(err916);
}
errors++;
}
else {
errors = _errs905;
if(vErrors !== null){
if(_errs905){
vErrors.length = _errs905;
}
else {
vErrors = null;
}
}
}
var valid169 = _errs904 === errors;
}
else {
var valid169 = true;
}
if(valid169){
if(data304.source_encoding !== undefined){
let data306 = data304.source_encoding;
const _errs910 = errors;
if(typeof data306 !== "string"){
const err917 = {instancePath:instancePath+"/status/diagnostic/location/source_encoding",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/diagnostic/anyOf/0/properties/location/anyOf/0/properties/source_encoding/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err917];
}
else {
vErrors.push(err917);
}
errors++;
}
if(!((data306 === "utf8") || (data306 === "escaped_bytes"))){
const err918 = {instancePath:instancePath+"/status/diagnostic/location/source_encoding",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/diagnostic/anyOf/0/properties/location/anyOf/0/properties/source_encoding/enum",keyword:"enum",params:{allowedValues: schema33.oneOf[9].properties.status.anyOf[0].properties.diagnostic.anyOf[0].properties.location.anyOf[0].properties.source_encoding.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err918];
}
else {
vErrors.push(err918);
}
errors++;
}
var valid169 = _errs910 === errors;
}
else {
var valid169 = true;
}
if(valid169){
if(data304.source_truncated !== undefined){
const _errs912 = errors;
if(typeof data304.source_truncated !== "boolean"){
const err919 = {instancePath:instancePath+"/status/diagnostic/location/source_truncated",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/diagnostic/anyOf/0/properties/location/anyOf/0/properties/source_truncated/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"};
if(vErrors === null){
vErrors = [err919];
}
else {
vErrors.push(err919);
}
errors++;
}
var valid169 = _errs912 === errors;
}
else {
var valid169 = true;
}
if(valid169){
if(data304.statement !== undefined){
let data308 = data304.statement;
const _errs914 = errors;
const _errs915 = errors;
let valid171 = false;
const _errs916 = errors;
if(errors === _errs916){
if(typeof data308 === "string"){
if(func1(data308) > 20){
const err920 = {instancePath:instancePath+"/status/diagnostic/location/statement",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/diagnostic/anyOf/0/properties/location/anyOf/0/properties/statement/anyOf/0/maxLength",keyword:"maxLength",params:{limit: 20},message:"must NOT have more than 20 characters"};
if(vErrors === null){
vErrors = [err920];
}
else {
vErrors.push(err920);
}
errors++;
}
else {
if(!pattern7.test(data308)){
const err921 = {instancePath:instancePath+"/status/diagnostic/location/statement",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/diagnostic/anyOf/0/properties/location/anyOf/0/properties/statement/anyOf/0/pattern",keyword:"pattern",params:{pattern: "^(0|[1-9][0-9]*)$"},message:"must match pattern \""+"^(0|[1-9][0-9]*)$"+"\""};
if(vErrors === null){
vErrors = [err921];
}
else {
vErrors.push(err921);
}
errors++;
}
}
}
else {
const err922 = {instancePath:instancePath+"/status/diagnostic/location/statement",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/diagnostic/anyOf/0/properties/location/anyOf/0/properties/statement/anyOf/0/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err922];
}
else {
vErrors.push(err922);
}
errors++;
}
}
var _valid33 = _errs916 === errors;
valid171 = valid171 || _valid33;
const _errs918 = errors;
if(data308 !== null){
const err923 = {instancePath:instancePath+"/status/diagnostic/location/statement",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/diagnostic/anyOf/0/properties/location/anyOf/0/properties/statement/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err923];
}
else {
vErrors.push(err923);
}
errors++;
}
var _valid33 = _errs918 === errors;
valid171 = valid171 || _valid33;
if(!valid171){
const err924 = {instancePath:instancePath+"/status/diagnostic/location/statement",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/diagnostic/anyOf/0/properties/location/anyOf/0/properties/statement/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err924];
}
else {
vErrors.push(err924);
}
errors++;
}
else {
errors = _errs915;
if(vErrors !== null){
if(_errs915){
vErrors.length = _errs915;
}
else {
vErrors = null;
}
}
}
var valid169 = _errs914 === errors;
}
else {
var valid169 = true;
}
if(valid169){
if(data304.offset !== undefined){
let data309 = data304.offset;
const _errs920 = errors;
if(errors === _errs920){
if(typeof data309 === "string"){
if(func1(data309) > 20){
const err925 = {instancePath:instancePath+"/status/diagnostic/location/offset",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/diagnostic/anyOf/0/properties/location/anyOf/0/properties/offset/maxLength",keyword:"maxLength",params:{limit: 20},message:"must NOT have more than 20 characters"};
if(vErrors === null){
vErrors = [err925];
}
else {
vErrors.push(err925);
}
errors++;
}
else {
if(!pattern7.test(data309)){
const err926 = {instancePath:instancePath+"/status/diagnostic/location/offset",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/diagnostic/anyOf/0/properties/location/anyOf/0/properties/offset/pattern",keyword:"pattern",params:{pattern: "^(0|[1-9][0-9]*)$"},message:"must match pattern \""+"^(0|[1-9][0-9]*)$"+"\""};
if(vErrors === null){
vErrors = [err926];
}
else {
vErrors.push(err926);
}
errors++;
}
}
}
else {
const err927 = {instancePath:instancePath+"/status/diagnostic/location/offset",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/diagnostic/anyOf/0/properties/location/anyOf/0/properties/offset/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err927];
}
else {
vErrors.push(err927);
}
errors++;
}
}
var valid169 = _errs920 === errors;
}
else {
var valid169 = true;
}
if(valid169){
if(data304.length !== undefined){
let data310 = data304.length;
const _errs922 = errors;
if(errors === _errs922){
if(typeof data310 === "string"){
if(func1(data310) > 20){
const err928 = {instancePath:instancePath+"/status/diagnostic/location/length",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/diagnostic/anyOf/0/properties/location/anyOf/0/properties/length/maxLength",keyword:"maxLength",params:{limit: 20},message:"must NOT have more than 20 characters"};
if(vErrors === null){
vErrors = [err928];
}
else {
vErrors.push(err928);
}
errors++;
}
else {
if(!pattern7.test(data310)){
const err929 = {instancePath:instancePath+"/status/diagnostic/location/length",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/diagnostic/anyOf/0/properties/location/anyOf/0/properties/length/pattern",keyword:"pattern",params:{pattern: "^(0|[1-9][0-9]*)$"},message:"must match pattern \""+"^(0|[1-9][0-9]*)$"+"\""};
if(vErrors === null){
vErrors = [err929];
}
else {
vErrors.push(err929);
}
errors++;
}
}
}
else {
const err930 = {instancePath:instancePath+"/status/diagnostic/location/length",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/diagnostic/anyOf/0/properties/location/anyOf/0/properties/length/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err930];
}
else {
vErrors.push(err930);
}
errors++;
}
}
var valid169 = _errs922 === errors;
}
else {
var valid169 = true;
}
if(valid169){
if(data304.line !== undefined){
let data311 = data304.line;
const _errs924 = errors;
if(errors === _errs924){
if(typeof data311 === "string"){
if(func1(data311) > 20){
const err931 = {instancePath:instancePath+"/status/diagnostic/location/line",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/diagnostic/anyOf/0/properties/location/anyOf/0/properties/line/maxLength",keyword:"maxLength",params:{limit: 20},message:"must NOT have more than 20 characters"};
if(vErrors === null){
vErrors = [err931];
}
else {
vErrors.push(err931);
}
errors++;
}
else {
if(!pattern7.test(data311)){
const err932 = {instancePath:instancePath+"/status/diagnostic/location/line",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/diagnostic/anyOf/0/properties/location/anyOf/0/properties/line/pattern",keyword:"pattern",params:{pattern: "^(0|[1-9][0-9]*)$"},message:"must match pattern \""+"^(0|[1-9][0-9]*)$"+"\""};
if(vErrors === null){
vErrors = [err932];
}
else {
vErrors.push(err932);
}
errors++;
}
}
}
else {
const err933 = {instancePath:instancePath+"/status/diagnostic/location/line",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/diagnostic/anyOf/0/properties/location/anyOf/0/properties/line/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err933];
}
else {
vErrors.push(err933);
}
errors++;
}
}
var valid169 = _errs924 === errors;
}
else {
var valid169 = true;
}
if(valid169){
if(data304.byte_column !== undefined){
let data312 = data304.byte_column;
const _errs926 = errors;
if(errors === _errs926){
if(typeof data312 === "string"){
if(func1(data312) > 20){
const err934 = {instancePath:instancePath+"/status/diagnostic/location/byte_column",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/diagnostic/anyOf/0/properties/location/anyOf/0/properties/byte_column/maxLength",keyword:"maxLength",params:{limit: 20},message:"must NOT have more than 20 characters"};
if(vErrors === null){
vErrors = [err934];
}
else {
vErrors.push(err934);
}
errors++;
}
else {
if(!pattern7.test(data312)){
const err935 = {instancePath:instancePath+"/status/diagnostic/location/byte_column",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/diagnostic/anyOf/0/properties/location/anyOf/0/properties/byte_column/pattern",keyword:"pattern",params:{pattern: "^(0|[1-9][0-9]*)$"},message:"must match pattern \""+"^(0|[1-9][0-9]*)$"+"\""};
if(vErrors === null){
vErrors = [err935];
}
else {
vErrors.push(err935);
}
errors++;
}
}
}
else {
const err936 = {instancePath:instancePath+"/status/diagnostic/location/byte_column",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/diagnostic/anyOf/0/properties/location/anyOf/0/properties/byte_column/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err936];
}
else {
vErrors.push(err936);
}
errors++;
}
}
var valid169 = _errs926 === errors;
}
else {
var valid169 = true;
}
}
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
const err937 = {instancePath:instancePath+"/status/diagnostic/location",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/diagnostic/anyOf/0/properties/location/anyOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err937];
}
else {
vErrors.push(err937);
}
errors++;
}
}
var _valid31 = _errs901 === errors;
valid168 = valid168 || _valid31;
const _errs928 = errors;
if(data304 !== null){
const err938 = {instancePath:instancePath+"/status/diagnostic/location",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/diagnostic/anyOf/0/properties/location/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err938];
}
else {
vErrors.push(err938);
}
errors++;
}
var _valid31 = _errs928 === errors;
valid168 = valid168 || _valid31;
if(!valid168){
const err939 = {instancePath:instancePath+"/status/diagnostic/location",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/diagnostic/anyOf/0/properties/location/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err939];
}
else {
vErrors.push(err939);
}
errors++;
}
else {
errors = _errs900;
if(vErrors !== null){
if(_errs900){
vErrors.length = _errs900;
}
else {
vErrors = null;
}
}
}
var valid161 = _errs899 === errors;
}
else {
var valid161 = true;
}
if(valid161){
if(data288.facts !== undefined){
let data313 = data288.facts;
const _errs930 = errors;
if(errors === _errs930){
if(Array.isArray(data313)){
if(data313.length > 16){
const err940 = {instancePath:instancePath+"/status/diagnostic/facts",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/diagnostic/anyOf/0/properties/facts/maxItems",keyword:"maxItems",params:{limit: 16},message:"must NOT have more than 16 items"};
if(vErrors === null){
vErrors = [err940];
}
else {
vErrors.push(err940);
}
errors++;
}
else {
if(data313.length < 16){
const err941 = {instancePath:instancePath+"/status/diagnostic/facts",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/diagnostic/anyOf/0/properties/facts/minItems",keyword:"minItems",params:{limit: 16},message:"must NOT have fewer than 16 items"};
if(vErrors === null){
vErrors = [err941];
}
else {
vErrors.push(err941);
}
errors++;
}
else {
var valid172 = true;
const len26 = data313.length;
for(let i26=0; i26<len26; i26++){
let data314 = data313[i26];
const _errs932 = errors;
const _errs933 = errors;
let valid173 = false;
const _errs934 = errors;
if(errors === _errs934){
if(data314 && typeof data314 == "object" && !Array.isArray(data314)){
let missing112;
if(((((data314.field === undefined) && (missing112 = "field")) || ((data314.origin === undefined) && (missing112 = "origin"))) || ((data314.availability === undefined) && (missing112 = "availability"))) || ((data314.value === undefined) && (missing112 = "value"))){
const err942 = {instancePath:instancePath+"/status/diagnostic/facts/" + i26,schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/diagnostic/anyOf/0/properties/facts/items/anyOf/0/required",keyword:"required",params:{missingProperty: missing112},message:"must have required property '"+missing112+"'"};
if(vErrors === null){
vErrors = [err942];
}
else {
vErrors.push(err942);
}
errors++;
}
else {
const _errs936 = errors;
for(const key112 in data314){
if(!((((key112 === "field") || (key112 === "origin")) || (key112 === "availability")) || (key112 === "value"))){
const err943 = {instancePath:instancePath+"/status/diagnostic/facts/" + i26,schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/diagnostic/anyOf/0/properties/facts/items/anyOf/0/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key112},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err943];
}
else {
vErrors.push(err943);
}
errors++;
break;
}
}
if(_errs936 === errors){
if(data314.field !== undefined){
let data315 = data314.field;
const _errs937 = errors;
if(typeof data315 !== "string"){
const err944 = {instancePath:instancePath+"/status/diagnostic/facts/" + i26+"/field",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/diagnostic/anyOf/0/properties/facts/items/anyOf/0/properties/field/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err944];
}
else {
vErrors.push(err944);
}
errors++;
}
if(!(((((((((((((((((((((((((((((((((((((((((((((((((((((((((data315 === "object") || (data315 === "name")) || (data315 === "table")) || (data315 === "native_input")) || (data315 === "affected_rows")) || (data315 === "argument")) || (data315 === "option")) || (data315 === "permissions")) || (data315 === "scope")) || (data315 === "column")) || (data315 === "qualifier")) || (data315 === "constraint")) || (data315 === "key")) || (data315 === "input_row")) || (data315 === "first_occurrence")) || (data315 === "parameter")) || (data315 === "parameter_use")) || (data315 === "expected_count")) || (data315 === "actual_count")) || (data315 === "expected_type")) || (data315 === "actual_type")) || (data315 === "supplied_value")) || (data315 === "expression")) || (data315 === "source_kind")) || (data315 === "source_basis")) || (data315 === "source_key")) || (data315 === "source_row")) || (data315 === "field_path")) || (data315 === "byte_offset")) || (data315 === "expected_resource")) || (data315 === "actual_resource")) || (data315 === "expected_source")) || (data315 === "actual_source")) || (data315 === "expected_revision")) || (data315 === "actual_revision")) || (data315 === "expected_schema")) || (data315 === "actual_schema")) || (data315 === "expected_policy")) || (data315 === "actual_policy")) || (data315 === "budget")) || (data315 === "limit")) || (data315 === "required")) || (data315 === "unit")) || (data315 === "completed_statements")) || (data315 === "emitted_rows")) || (data315 === "emitted_segments")) || (data315 === "completion")) || (data315 === "proposal")) || (data315 === "step")) || (data315 === "generation")) || (data315 === "attachment")) || (data315 === "lease")) || (data315 === "schema_origin")) || (data315 === "sampling_records")) || (data315 === "operation")) || (data315 === "native_cause")) || (data315 === "expected_bytes"))){
const err945 = {instancePath:instancePath+"/status/diagnostic/facts/" + i26+"/field",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/diagnostic/anyOf/0/properties/facts/items/anyOf/0/properties/field/enum",keyword:"enum",params:{allowedValues: schema33.oneOf[9].properties.status.anyOf[0].properties.diagnostic.anyOf[0].properties.facts.items.anyOf[0].properties.field.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err945];
}
else {
vErrors.push(err945);
}
errors++;
}
var valid174 = _errs937 === errors;
}
else {
var valid174 = true;
}
if(valid174){
if(data314.origin !== undefined){
let data316 = data314.origin;
const _errs939 = errors;
if(typeof data316 !== "string"){
const err946 = {instancePath:instancePath+"/status/diagnostic/facts/" + i26+"/origin",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/diagnostic/anyOf/0/properties/facts/items/anyOf/0/properties/origin/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err946];
}
else {
vErrors.push(err946);
}
errors++;
}
if(!(((((data316 === "caller") || (data316 === "execution")) || (data316 === "schema")) || (data316 === "authority")) || (data316 === "owner"))){
const err947 = {instancePath:instancePath+"/status/diagnostic/facts/" + i26+"/origin",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/diagnostic/anyOf/0/properties/facts/items/anyOf/0/properties/origin/enum",keyword:"enum",params:{allowedValues: schema33.oneOf[9].properties.status.anyOf[0].properties.diagnostic.anyOf[0].properties.facts.items.anyOf[0].properties.origin.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err947];
}
else {
vErrors.push(err947);
}
errors++;
}
var valid174 = _errs939 === errors;
}
else {
var valid174 = true;
}
if(valid174){
if(data314.availability !== undefined){
let data317 = data314.availability;
const _errs941 = errors;
if(typeof data317 !== "string"){
const err948 = {instancePath:instancePath+"/status/diagnostic/facts/" + i26+"/availability",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/diagnostic/anyOf/0/properties/facts/items/anyOf/0/properties/availability/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err948];
}
else {
vErrors.push(err948);
}
errors++;
}
if(!((((((data317 === "provided") || (data317 === "truncated")) || (data317 === "unrecorded")) || (data317 === "unavailable")) || (data317 === "withheld")) || (data317 === "inapplicable"))){
const err949 = {instancePath:instancePath+"/status/diagnostic/facts/" + i26+"/availability",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/diagnostic/anyOf/0/properties/facts/items/anyOf/0/properties/availability/enum",keyword:"enum",params:{allowedValues: schema33.oneOf[9].properties.status.anyOf[0].properties.diagnostic.anyOf[0].properties.facts.items.anyOf[0].properties.availability.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err949];
}
else {
vErrors.push(err949);
}
errors++;
}
var valid174 = _errs941 === errors;
}
else {
var valid174 = true;
}
if(valid174){
if(data314.value !== undefined){
let data318 = data314.value;
const _errs943 = errors;
const _errs944 = errors;
let valid175 = false;
const _errs945 = errors;
const _errs946 = errors;
let valid176 = false;
let passing13 = null;
const _errs947 = errors;
if(errors === _errs947){
if(data318 && typeof data318 == "object" && !Array.isArray(data318)){
let missing113;
if((data318.text === undefined) && (missing113 = "text")){
const err950 = {instancePath:instancePath+"/status/diagnostic/facts/" + i26+"/value",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/diagnostic/anyOf/0/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/0/required",keyword:"required",params:{missingProperty: missing113},message:"must have required property '"+missing113+"'"};
if(vErrors === null){
vErrors = [err950];
}
else {
vErrors.push(err950);
}
errors++;
}
else {
const _errs949 = errors;
for(const key113 in data318){
if(!(key113 === "text")){
const err951 = {instancePath:instancePath+"/status/diagnostic/facts/" + i26+"/value",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/diagnostic/anyOf/0/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/0/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key113},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err951];
}
else {
vErrors.push(err951);
}
errors++;
break;
}
}
if(_errs949 === errors){
if(data318.text !== undefined){
let data319 = data318.text;
const _errs950 = errors;
if(errors === _errs950){
if(typeof data319 === "string"){
if(func1(data319) > 256){
const err952 = {instancePath:instancePath+"/status/diagnostic/facts/" + i26+"/value/text",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/diagnostic/anyOf/0/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/0/properties/text/maxLength",keyword:"maxLength",params:{limit: 256},message:"must NOT have more than 256 characters"};
if(vErrors === null){
vErrors = [err952];
}
else {
vErrors.push(err952);
}
errors++;
}
}
else {
const err953 = {instancePath:instancePath+"/status/diagnostic/facts/" + i26+"/value/text",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/diagnostic/anyOf/0/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/0/properties/text/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err953];
}
else {
vErrors.push(err953);
}
errors++;
}
}
}
}
}
}
else {
const err954 = {instancePath:instancePath+"/status/diagnostic/facts/" + i26+"/value",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/diagnostic/anyOf/0/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err954];
}
else {
vErrors.push(err954);
}
errors++;
}
}
var _valid36 = _errs947 === errors;
if(_valid36){
valid176 = true;
passing13 = 0;
var props18 = true;
}
const _errs952 = errors;
if(errors === _errs952){
if(data318 && typeof data318 == "object" && !Array.isArray(data318)){
let missing114;
if((data318.signed === undefined) && (missing114 = "signed")){
const err955 = {instancePath:instancePath+"/status/diagnostic/facts/" + i26+"/value",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/diagnostic/anyOf/0/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/1/required",keyword:"required",params:{missingProperty: missing114},message:"must have required property '"+missing114+"'"};
if(vErrors === null){
vErrors = [err955];
}
else {
vErrors.push(err955);
}
errors++;
}
else {
const _errs954 = errors;
for(const key114 in data318){
if(!(key114 === "signed")){
const err956 = {instancePath:instancePath+"/status/diagnostic/facts/" + i26+"/value",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/diagnostic/anyOf/0/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/1/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key114},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err956];
}
else {
vErrors.push(err956);
}
errors++;
break;
}
}
if(_errs954 === errors){
if(data318.signed !== undefined){
let data320 = data318.signed;
const _errs955 = errors;
if(errors === _errs955){
if(typeof data320 === "string"){
if(func1(data320) > 20){
const err957 = {instancePath:instancePath+"/status/diagnostic/facts/" + i26+"/value/signed",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/diagnostic/anyOf/0/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/1/properties/signed/maxLength",keyword:"maxLength",params:{limit: 20},message:"must NOT have more than 20 characters"};
if(vErrors === null){
vErrors = [err957];
}
else {
vErrors.push(err957);
}
errors++;
}
else {
if(!pattern16.test(data320)){
const err958 = {instancePath:instancePath+"/status/diagnostic/facts/" + i26+"/value/signed",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/diagnostic/anyOf/0/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/1/properties/signed/pattern",keyword:"pattern",params:{pattern: "^(0|-?[1-9][0-9]*)$"},message:"must match pattern \""+"^(0|-?[1-9][0-9]*)$"+"\""};
if(vErrors === null){
vErrors = [err958];
}
else {
vErrors.push(err958);
}
errors++;
}
}
}
else {
const err959 = {instancePath:instancePath+"/status/diagnostic/facts/" + i26+"/value/signed",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/diagnostic/anyOf/0/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/1/properties/signed/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err959];
}
else {
vErrors.push(err959);
}
errors++;
}
}
}
}
}
}
else {
const err960 = {instancePath:instancePath+"/status/diagnostic/facts/" + i26+"/value",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/diagnostic/anyOf/0/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/1/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err960];
}
else {
vErrors.push(err960);
}
errors++;
}
}
var _valid36 = _errs952 === errors;
if(_valid36 && valid176){
valid176 = false;
passing13 = [passing13, 1];
}
else {
if(_valid36){
valid176 = true;
passing13 = 1;
if(props18 !== true){
props18 = true;
}
}
const _errs957 = errors;
if(errors === _errs957){
if(data318 && typeof data318 == "object" && !Array.isArray(data318)){
let missing115;
if((data318.unsigned === undefined) && (missing115 = "unsigned")){
const err961 = {instancePath:instancePath+"/status/diagnostic/facts/" + i26+"/value",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/diagnostic/anyOf/0/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/2/required",keyword:"required",params:{missingProperty: missing115},message:"must have required property '"+missing115+"'"};
if(vErrors === null){
vErrors = [err961];
}
else {
vErrors.push(err961);
}
errors++;
}
else {
const _errs959 = errors;
for(const key115 in data318){
if(!(key115 === "unsigned")){
const err962 = {instancePath:instancePath+"/status/diagnostic/facts/" + i26+"/value",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/diagnostic/anyOf/0/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/2/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key115},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err962];
}
else {
vErrors.push(err962);
}
errors++;
break;
}
}
if(_errs959 === errors){
if(data318.unsigned !== undefined){
let data321 = data318.unsigned;
const _errs960 = errors;
if(errors === _errs960){
if(typeof data321 === "string"){
if(func1(data321) > 20){
const err963 = {instancePath:instancePath+"/status/diagnostic/facts/" + i26+"/value/unsigned",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/diagnostic/anyOf/0/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/2/properties/unsigned/maxLength",keyword:"maxLength",params:{limit: 20},message:"must NOT have more than 20 characters"};
if(vErrors === null){
vErrors = [err963];
}
else {
vErrors.push(err963);
}
errors++;
}
else {
if(!pattern7.test(data321)){
const err964 = {instancePath:instancePath+"/status/diagnostic/facts/" + i26+"/value/unsigned",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/diagnostic/anyOf/0/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/2/properties/unsigned/pattern",keyword:"pattern",params:{pattern: "^(0|[1-9][0-9]*)$"},message:"must match pattern \""+"^(0|[1-9][0-9]*)$"+"\""};
if(vErrors === null){
vErrors = [err964];
}
else {
vErrors.push(err964);
}
errors++;
}
}
}
else {
const err965 = {instancePath:instancePath+"/status/diagnostic/facts/" + i26+"/value/unsigned",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/diagnostic/anyOf/0/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/2/properties/unsigned/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err965];
}
else {
vErrors.push(err965);
}
errors++;
}
}
}
}
}
}
else {
const err966 = {instancePath:instancePath+"/status/diagnostic/facts/" + i26+"/value",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/diagnostic/anyOf/0/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/2/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err966];
}
else {
vErrors.push(err966);
}
errors++;
}
}
var _valid36 = _errs957 === errors;
if(_valid36 && valid176){
valid176 = false;
passing13 = [passing13, 2];
}
else {
if(_valid36){
valid176 = true;
passing13 = 2;
if(props18 !== true){
props18 = true;
}
}
const _errs962 = errors;
if(errors === _errs962){
if(data318 && typeof data318 == "object" && !Array.isArray(data318)){
let missing116;
if((data318.boolean === undefined) && (missing116 = "boolean")){
const err967 = {instancePath:instancePath+"/status/diagnostic/facts/" + i26+"/value",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/diagnostic/anyOf/0/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/3/required",keyword:"required",params:{missingProperty: missing116},message:"must have required property '"+missing116+"'"};
if(vErrors === null){
vErrors = [err967];
}
else {
vErrors.push(err967);
}
errors++;
}
else {
const _errs964 = errors;
for(const key116 in data318){
if(!(key116 === "boolean")){
const err968 = {instancePath:instancePath+"/status/diagnostic/facts/" + i26+"/value",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/diagnostic/anyOf/0/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/3/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key116},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err968];
}
else {
vErrors.push(err968);
}
errors++;
break;
}
}
if(_errs964 === errors){
if(data318.boolean !== undefined){
if(typeof data318.boolean !== "boolean"){
const err969 = {instancePath:instancePath+"/status/diagnostic/facts/" + i26+"/value/boolean",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/diagnostic/anyOf/0/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/3/properties/boolean/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"};
if(vErrors === null){
vErrors = [err969];
}
else {
vErrors.push(err969);
}
errors++;
}
}
}
}
}
else {
const err970 = {instancePath:instancePath+"/status/diagnostic/facts/" + i26+"/value",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/diagnostic/anyOf/0/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/3/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err970];
}
else {
vErrors.push(err970);
}
errors++;
}
}
var _valid36 = _errs962 === errors;
if(_valid36 && valid176){
valid176 = false;
passing13 = [passing13, 3];
}
else {
if(_valid36){
valid176 = true;
passing13 = 3;
if(props18 !== true){
props18 = true;
}
}
const _errs967 = errors;
if(errors === _errs967){
if(data318 && typeof data318 == "object" && !Array.isArray(data318)){
let missing117;
if((data318.digest === undefined) && (missing117 = "digest")){
const err971 = {instancePath:instancePath+"/status/diagnostic/facts/" + i26+"/value",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/diagnostic/anyOf/0/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/4/required",keyword:"required",params:{missingProperty: missing117},message:"must have required property '"+missing117+"'"};
if(vErrors === null){
vErrors = [err971];
}
else {
vErrors.push(err971);
}
errors++;
}
else {
const _errs969 = errors;
for(const key117 in data318){
if(!(key117 === "digest")){
const err972 = {instancePath:instancePath+"/status/diagnostic/facts/" + i26+"/value",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/diagnostic/anyOf/0/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/4/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key117},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err972];
}
else {
vErrors.push(err972);
}
errors++;
break;
}
}
if(_errs969 === errors){
if(data318.digest !== undefined){
let data323 = data318.digest;
const _errs970 = errors;
if(errors === _errs970){
if(Array.isArray(data323)){
if(data323.length > 32){
const err973 = {instancePath:instancePath+"/status/diagnostic/facts/" + i26+"/value/digest",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/diagnostic/anyOf/0/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/4/properties/digest/maxItems",keyword:"maxItems",params:{limit: 32},message:"must NOT have more than 32 items"};
if(vErrors === null){
vErrors = [err973];
}
else {
vErrors.push(err973);
}
errors++;
}
else {
if(data323.length < 32){
const err974 = {instancePath:instancePath+"/status/diagnostic/facts/" + i26+"/value/digest",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/diagnostic/anyOf/0/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/4/properties/digest/minItems",keyword:"minItems",params:{limit: 32},message:"must NOT have fewer than 32 items"};
if(vErrors === null){
vErrors = [err974];
}
else {
vErrors.push(err974);
}
errors++;
}
else {
var valid182 = true;
const len27 = data323.length;
for(let i27=0; i27<len27; i27++){
let data324 = data323[i27];
const _errs972 = errors;
if(!(((typeof data324 == "number") && (!(data324 % 1) && !isNaN(data324))) && (isFinite(data324)))){
const err975 = {instancePath:instancePath+"/status/diagnostic/facts/" + i26+"/value/digest/" + i27,schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/diagnostic/anyOf/0/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/4/properties/digest/items/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err975];
}
else {
vErrors.push(err975);
}
errors++;
}
if(errors === _errs972){
if((typeof data324 == "number") && (isFinite(data324))){
if(data324 > 255 || isNaN(data324)){
const err976 = {instancePath:instancePath+"/status/diagnostic/facts/" + i26+"/value/digest/" + i27,schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/diagnostic/anyOf/0/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/4/properties/digest/items/maximum",keyword:"maximum",params:{comparison: "<=", limit: 255},message:"must be <= 255"};
if(vErrors === null){
vErrors = [err976];
}
else {
vErrors.push(err976);
}
errors++;
}
else {
if(data324 < 0 || isNaN(data324)){
const err977 = {instancePath:instancePath+"/status/diagnostic/facts/" + i26+"/value/digest/" + i27,schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/diagnostic/anyOf/0/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/4/properties/digest/items/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err977];
}
else {
vErrors.push(err977);
}
errors++;
}
}
}
}
var valid182 = _errs972 === errors;
if(!valid182){
break;
}
}
}
}
}
else {
const err978 = {instancePath:instancePath+"/status/diagnostic/facts/" + i26+"/value/digest",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/diagnostic/anyOf/0/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/4/properties/digest/type",keyword:"type",params:{type: "array"},message:"must be array"};
if(vErrors === null){
vErrors = [err978];
}
else {
vErrors.push(err978);
}
errors++;
}
}
}
}
}
}
else {
const err979 = {instancePath:instancePath+"/status/diagnostic/facts/" + i26+"/value",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/diagnostic/anyOf/0/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/4/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err979];
}
else {
vErrors.push(err979);
}
errors++;
}
}
var _valid36 = _errs967 === errors;
if(_valid36 && valid176){
valid176 = false;
passing13 = [passing13, 4];
}
else {
if(_valid36){
valid176 = true;
passing13 = 4;
if(props18 !== true){
props18 = true;
}
}
const _errs974 = errors;
if(errors === _errs974){
if(data318 && typeof data318 == "object" && !Array.isArray(data318)){
let missing118;
if((data318.location === undefined) && (missing118 = "location")){
const err980 = {instancePath:instancePath+"/status/diagnostic/facts/" + i26+"/value",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/diagnostic/anyOf/0/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/5/required",keyword:"required",params:{missingProperty: missing118},message:"must have required property '"+missing118+"'"};
if(vErrors === null){
vErrors = [err980];
}
else {
vErrors.push(err980);
}
errors++;
}
else {
const _errs976 = errors;
for(const key118 in data318){
if(!(key118 === "location")){
const err981 = {instancePath:instancePath+"/status/diagnostic/facts/" + i26+"/value",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/diagnostic/anyOf/0/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/5/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key118},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err981];
}
else {
vErrors.push(err981);
}
errors++;
break;
}
}
if(_errs976 === errors){
if(data318.location !== undefined){
let data325 = data318.location;
const _errs977 = errors;
if(errors === _errs977){
if(data325 && typeof data325 == "object" && !Array.isArray(data325)){
let missing119;
if(((((((((data325.source === undefined) && (missing119 = "source")) || ((data325.source_encoding === undefined) && (missing119 = "source_encoding"))) || ((data325.source_truncated === undefined) && (missing119 = "source_truncated"))) || ((data325.statement === undefined) && (missing119 = "statement"))) || ((data325.offset === undefined) && (missing119 = "offset"))) || ((data325.length === undefined) && (missing119 = "length"))) || ((data325.line === undefined) && (missing119 = "line"))) || ((data325.byte_column === undefined) && (missing119 = "byte_column"))){
const err982 = {instancePath:instancePath+"/status/diagnostic/facts/" + i26+"/value/location",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/diagnostic/anyOf/0/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/5/properties/location/required",keyword:"required",params:{missingProperty: missing119},message:"must have required property '"+missing119+"'"};
if(vErrors === null){
vErrors = [err982];
}
else {
vErrors.push(err982);
}
errors++;
}
else {
const _errs979 = errors;
for(const key119 in data325){
if(!((((((((key119 === "source") || (key119 === "source_encoding")) || (key119 === "source_truncated")) || (key119 === "statement")) || (key119 === "offset")) || (key119 === "length")) || (key119 === "line")) || (key119 === "byte_column"))){
const err983 = {instancePath:instancePath+"/status/diagnostic/facts/" + i26+"/value/location",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/diagnostic/anyOf/0/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/5/properties/location/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key119},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err983];
}
else {
vErrors.push(err983);
}
errors++;
break;
}
}
if(_errs979 === errors){
if(data325.source !== undefined){
let data326 = data325.source;
const _errs980 = errors;
const _errs981 = errors;
let valid185 = false;
const _errs982 = errors;
if(errors === _errs982){
if(typeof data326 === "string"){
if(func1(data326) > 512){
const err984 = {instancePath:instancePath+"/status/diagnostic/facts/" + i26+"/value/location/source",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/diagnostic/anyOf/0/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/5/properties/location/properties/source/anyOf/0/maxLength",keyword:"maxLength",params:{limit: 512},message:"must NOT have more than 512 characters"};
if(vErrors === null){
vErrors = [err984];
}
else {
vErrors.push(err984);
}
errors++;
}
}
else {
const err985 = {instancePath:instancePath+"/status/diagnostic/facts/" + i26+"/value/location/source",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/diagnostic/anyOf/0/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/5/properties/location/properties/source/anyOf/0/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err985];
}
else {
vErrors.push(err985);
}
errors++;
}
}
var _valid37 = _errs982 === errors;
valid185 = valid185 || _valid37;
const _errs984 = errors;
if(data326 !== null){
const err986 = {instancePath:instancePath+"/status/diagnostic/facts/" + i26+"/value/location/source",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/diagnostic/anyOf/0/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/5/properties/location/properties/source/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err986];
}
else {
vErrors.push(err986);
}
errors++;
}
var _valid37 = _errs984 === errors;
valid185 = valid185 || _valid37;
if(!valid185){
const err987 = {instancePath:instancePath+"/status/diagnostic/facts/" + i26+"/value/location/source",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/diagnostic/anyOf/0/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/5/properties/location/properties/source/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err987];
}
else {
vErrors.push(err987);
}
errors++;
}
else {
errors = _errs981;
if(vErrors !== null){
if(_errs981){
vErrors.length = _errs981;
}
else {
vErrors = null;
}
}
}
var valid184 = _errs980 === errors;
}
else {
var valid184 = true;
}
if(valid184){
if(data325.source_encoding !== undefined){
let data327 = data325.source_encoding;
const _errs986 = errors;
if(typeof data327 !== "string"){
const err988 = {instancePath:instancePath+"/status/diagnostic/facts/" + i26+"/value/location/source_encoding",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/diagnostic/anyOf/0/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/5/properties/location/properties/source_encoding/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err988];
}
else {
vErrors.push(err988);
}
errors++;
}
if(!((data327 === "utf8") || (data327 === "escaped_bytes"))){
const err989 = {instancePath:instancePath+"/status/diagnostic/facts/" + i26+"/value/location/source_encoding",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/diagnostic/anyOf/0/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/5/properties/location/properties/source_encoding/enum",keyword:"enum",params:{allowedValues: schema33.oneOf[9].properties.status.anyOf[0].properties.diagnostic.anyOf[0].properties.facts.items.anyOf[0].properties.value.anyOf[0].oneOf[5].properties.location.properties.source_encoding.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err989];
}
else {
vErrors.push(err989);
}
errors++;
}
var valid184 = _errs986 === errors;
}
else {
var valid184 = true;
}
if(valid184){
if(data325.source_truncated !== undefined){
const _errs988 = errors;
if(typeof data325.source_truncated !== "boolean"){
const err990 = {instancePath:instancePath+"/status/diagnostic/facts/" + i26+"/value/location/source_truncated",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/diagnostic/anyOf/0/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/5/properties/location/properties/source_truncated/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"};
if(vErrors === null){
vErrors = [err990];
}
else {
vErrors.push(err990);
}
errors++;
}
var valid184 = _errs988 === errors;
}
else {
var valid184 = true;
}
if(valid184){
if(data325.statement !== undefined){
let data329 = data325.statement;
const _errs990 = errors;
const _errs991 = errors;
let valid186 = false;
const _errs992 = errors;
if(errors === _errs992){
if(typeof data329 === "string"){
if(func1(data329) > 20){
const err991 = {instancePath:instancePath+"/status/diagnostic/facts/" + i26+"/value/location/statement",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/diagnostic/anyOf/0/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/5/properties/location/properties/statement/anyOf/0/maxLength",keyword:"maxLength",params:{limit: 20},message:"must NOT have more than 20 characters"};
if(vErrors === null){
vErrors = [err991];
}
else {
vErrors.push(err991);
}
errors++;
}
else {
if(!pattern7.test(data329)){
const err992 = {instancePath:instancePath+"/status/diagnostic/facts/" + i26+"/value/location/statement",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/diagnostic/anyOf/0/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/5/properties/location/properties/statement/anyOf/0/pattern",keyword:"pattern",params:{pattern: "^(0|[1-9][0-9]*)$"},message:"must match pattern \""+"^(0|[1-9][0-9]*)$"+"\""};
if(vErrors === null){
vErrors = [err992];
}
else {
vErrors.push(err992);
}
errors++;
}
}
}
else {
const err993 = {instancePath:instancePath+"/status/diagnostic/facts/" + i26+"/value/location/statement",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/diagnostic/anyOf/0/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/5/properties/location/properties/statement/anyOf/0/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err993];
}
else {
vErrors.push(err993);
}
errors++;
}
}
var _valid38 = _errs992 === errors;
valid186 = valid186 || _valid38;
const _errs994 = errors;
if(data329 !== null){
const err994 = {instancePath:instancePath+"/status/diagnostic/facts/" + i26+"/value/location/statement",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/diagnostic/anyOf/0/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/5/properties/location/properties/statement/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err994];
}
else {
vErrors.push(err994);
}
errors++;
}
var _valid38 = _errs994 === errors;
valid186 = valid186 || _valid38;
if(!valid186){
const err995 = {instancePath:instancePath+"/status/diagnostic/facts/" + i26+"/value/location/statement",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/diagnostic/anyOf/0/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/5/properties/location/properties/statement/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err995];
}
else {
vErrors.push(err995);
}
errors++;
}
else {
errors = _errs991;
if(vErrors !== null){
if(_errs991){
vErrors.length = _errs991;
}
else {
vErrors = null;
}
}
}
var valid184 = _errs990 === errors;
}
else {
var valid184 = true;
}
if(valid184){
if(data325.offset !== undefined){
let data330 = data325.offset;
const _errs996 = errors;
if(errors === _errs996){
if(typeof data330 === "string"){
if(func1(data330) > 20){
const err996 = {instancePath:instancePath+"/status/diagnostic/facts/" + i26+"/value/location/offset",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/diagnostic/anyOf/0/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/5/properties/location/properties/offset/maxLength",keyword:"maxLength",params:{limit: 20},message:"must NOT have more than 20 characters"};
if(vErrors === null){
vErrors = [err996];
}
else {
vErrors.push(err996);
}
errors++;
}
else {
if(!pattern7.test(data330)){
const err997 = {instancePath:instancePath+"/status/diagnostic/facts/" + i26+"/value/location/offset",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/diagnostic/anyOf/0/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/5/properties/location/properties/offset/pattern",keyword:"pattern",params:{pattern: "^(0|[1-9][0-9]*)$"},message:"must match pattern \""+"^(0|[1-9][0-9]*)$"+"\""};
if(vErrors === null){
vErrors = [err997];
}
else {
vErrors.push(err997);
}
errors++;
}
}
}
else {
const err998 = {instancePath:instancePath+"/status/diagnostic/facts/" + i26+"/value/location/offset",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/diagnostic/anyOf/0/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/5/properties/location/properties/offset/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err998];
}
else {
vErrors.push(err998);
}
errors++;
}
}
var valid184 = _errs996 === errors;
}
else {
var valid184 = true;
}
if(valid184){
if(data325.length !== undefined){
let data331 = data325.length;
const _errs998 = errors;
if(errors === _errs998){
if(typeof data331 === "string"){
if(func1(data331) > 20){
const err999 = {instancePath:instancePath+"/status/diagnostic/facts/" + i26+"/value/location/length",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/diagnostic/anyOf/0/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/5/properties/location/properties/length/maxLength",keyword:"maxLength",params:{limit: 20},message:"must NOT have more than 20 characters"};
if(vErrors === null){
vErrors = [err999];
}
else {
vErrors.push(err999);
}
errors++;
}
else {
if(!pattern7.test(data331)){
const err1000 = {instancePath:instancePath+"/status/diagnostic/facts/" + i26+"/value/location/length",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/diagnostic/anyOf/0/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/5/properties/location/properties/length/pattern",keyword:"pattern",params:{pattern: "^(0|[1-9][0-9]*)$"},message:"must match pattern \""+"^(0|[1-9][0-9]*)$"+"\""};
if(vErrors === null){
vErrors = [err1000];
}
else {
vErrors.push(err1000);
}
errors++;
}
}
}
else {
const err1001 = {instancePath:instancePath+"/status/diagnostic/facts/" + i26+"/value/location/length",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/diagnostic/anyOf/0/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/5/properties/location/properties/length/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err1001];
}
else {
vErrors.push(err1001);
}
errors++;
}
}
var valid184 = _errs998 === errors;
}
else {
var valid184 = true;
}
if(valid184){
if(data325.line !== undefined){
let data332 = data325.line;
const _errs1000 = errors;
if(errors === _errs1000){
if(typeof data332 === "string"){
if(func1(data332) > 20){
const err1002 = {instancePath:instancePath+"/status/diagnostic/facts/" + i26+"/value/location/line",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/diagnostic/anyOf/0/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/5/properties/location/properties/line/maxLength",keyword:"maxLength",params:{limit: 20},message:"must NOT have more than 20 characters"};
if(vErrors === null){
vErrors = [err1002];
}
else {
vErrors.push(err1002);
}
errors++;
}
else {
if(!pattern7.test(data332)){
const err1003 = {instancePath:instancePath+"/status/diagnostic/facts/" + i26+"/value/location/line",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/diagnostic/anyOf/0/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/5/properties/location/properties/line/pattern",keyword:"pattern",params:{pattern: "^(0|[1-9][0-9]*)$"},message:"must match pattern \""+"^(0|[1-9][0-9]*)$"+"\""};
if(vErrors === null){
vErrors = [err1003];
}
else {
vErrors.push(err1003);
}
errors++;
}
}
}
else {
const err1004 = {instancePath:instancePath+"/status/diagnostic/facts/" + i26+"/value/location/line",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/diagnostic/anyOf/0/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/5/properties/location/properties/line/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err1004];
}
else {
vErrors.push(err1004);
}
errors++;
}
}
var valid184 = _errs1000 === errors;
}
else {
var valid184 = true;
}
if(valid184){
if(data325.byte_column !== undefined){
let data333 = data325.byte_column;
const _errs1002 = errors;
if(errors === _errs1002){
if(typeof data333 === "string"){
if(func1(data333) > 20){
const err1005 = {instancePath:instancePath+"/status/diagnostic/facts/" + i26+"/value/location/byte_column",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/diagnostic/anyOf/0/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/5/properties/location/properties/byte_column/maxLength",keyword:"maxLength",params:{limit: 20},message:"must NOT have more than 20 characters"};
if(vErrors === null){
vErrors = [err1005];
}
else {
vErrors.push(err1005);
}
errors++;
}
else {
if(!pattern7.test(data333)){
const err1006 = {instancePath:instancePath+"/status/diagnostic/facts/" + i26+"/value/location/byte_column",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/diagnostic/anyOf/0/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/5/properties/location/properties/byte_column/pattern",keyword:"pattern",params:{pattern: "^(0|[1-9][0-9]*)$"},message:"must match pattern \""+"^(0|[1-9][0-9]*)$"+"\""};
if(vErrors === null){
vErrors = [err1006];
}
else {
vErrors.push(err1006);
}
errors++;
}
}
}
else {
const err1007 = {instancePath:instancePath+"/status/diagnostic/facts/" + i26+"/value/location/byte_column",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/diagnostic/anyOf/0/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/5/properties/location/properties/byte_column/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err1007];
}
else {
vErrors.push(err1007);
}
errors++;
}
}
var valid184 = _errs1002 === errors;
}
else {
var valid184 = true;
}
}
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
const err1008 = {instancePath:instancePath+"/status/diagnostic/facts/" + i26+"/value/location",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/diagnostic/anyOf/0/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/5/properties/location/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err1008];
}
else {
vErrors.push(err1008);
}
errors++;
}
}
}
}
}
}
else {
const err1009 = {instancePath:instancePath+"/status/diagnostic/facts/" + i26+"/value",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/diagnostic/anyOf/0/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/5/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err1009];
}
else {
vErrors.push(err1009);
}
errors++;
}
}
var _valid36 = _errs974 === errors;
if(_valid36 && valid176){
valid176 = false;
passing13 = [passing13, 5];
}
else {
if(_valid36){
valid176 = true;
passing13 = 5;
if(props18 !== true){
props18 = true;
}
}
}
}
}
}
}
if(!valid176){
const err1010 = {instancePath:instancePath+"/status/diagnostic/facts/" + i26+"/value",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/diagnostic/anyOf/0/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf",keyword:"oneOf",params:{passingSchemas: passing13},message:"must match exactly one schema in oneOf"};
if(vErrors === null){
vErrors = [err1010];
}
else {
vErrors.push(err1010);
}
errors++;
}
else {
errors = _errs946;
if(vErrors !== null){
if(_errs946){
vErrors.length = _errs946;
}
else {
vErrors = null;
}
}
}
var _valid35 = _errs945 === errors;
valid175 = valid175 || _valid35;
const _errs1004 = errors;
if(data318 !== null){
const err1011 = {instancePath:instancePath+"/status/diagnostic/facts/" + i26+"/value",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/diagnostic/anyOf/0/properties/facts/items/anyOf/0/properties/value/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err1011];
}
else {
vErrors.push(err1011);
}
errors++;
}
var _valid35 = _errs1004 === errors;
valid175 = valid175 || _valid35;
if(!valid175){
const err1012 = {instancePath:instancePath+"/status/diagnostic/facts/" + i26+"/value",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/diagnostic/anyOf/0/properties/facts/items/anyOf/0/properties/value/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err1012];
}
else {
vErrors.push(err1012);
}
errors++;
}
else {
errors = _errs944;
if(vErrors !== null){
if(_errs944){
vErrors.length = _errs944;
}
else {
vErrors = null;
}
}
}
var valid174 = _errs943 === errors;
}
else {
var valid174 = true;
}
}
}
}
}
}
}
else {
const err1013 = {instancePath:instancePath+"/status/diagnostic/facts/" + i26,schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/diagnostic/anyOf/0/properties/facts/items/anyOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err1013];
}
else {
vErrors.push(err1013);
}
errors++;
}
}
var _valid34 = _errs934 === errors;
valid173 = valid173 || _valid34;
const _errs1006 = errors;
if(data314 !== null){
const err1014 = {instancePath:instancePath+"/status/diagnostic/facts/" + i26,schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/diagnostic/anyOf/0/properties/facts/items/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err1014];
}
else {
vErrors.push(err1014);
}
errors++;
}
var _valid34 = _errs1006 === errors;
valid173 = valid173 || _valid34;
if(!valid173){
const err1015 = {instancePath:instancePath+"/status/diagnostic/facts/" + i26,schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/diagnostic/anyOf/0/properties/facts/items/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err1015];
}
else {
vErrors.push(err1015);
}
errors++;
}
else {
errors = _errs933;
if(vErrors !== null){
if(_errs933){
vErrors.length = _errs933;
}
else {
vErrors = null;
}
}
}
var valid172 = _errs932 === errors;
if(!valid172){
break;
}
}
}
}
}
else {
const err1016 = {instancePath:instancePath+"/status/diagnostic/facts",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/diagnostic/anyOf/0/properties/facts/type",keyword:"type",params:{type: "array"},message:"must be array"};
if(vErrors === null){
vErrors = [err1016];
}
else {
vErrors.push(err1016);
}
errors++;
}
}
var valid161 = _errs930 === errors;
}
else {
var valid161 = true;
}
if(valid161){
if(data288.actions !== undefined){
let data334 = data288.actions;
const _errs1008 = errors;
if(errors === _errs1008){
if(Array.isArray(data334)){
if(data334.length > 4){
const err1017 = {instancePath:instancePath+"/status/diagnostic/actions",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/diagnostic/anyOf/0/properties/actions/maxItems",keyword:"maxItems",params:{limit: 4},message:"must NOT have more than 4 items"};
if(vErrors === null){
vErrors = [err1017];
}
else {
vErrors.push(err1017);
}
errors++;
}
else {
if(data334.length < 4){
const err1018 = {instancePath:instancePath+"/status/diagnostic/actions",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/diagnostic/anyOf/0/properties/actions/minItems",keyword:"minItems",params:{limit: 4},message:"must NOT have fewer than 4 items"};
if(vErrors === null){
vErrors = [err1018];
}
else {
vErrors.push(err1018);
}
errors++;
}
else {
var valid187 = true;
const len28 = data334.length;
for(let i28=0; i28<len28; i28++){
let data335 = data334[i28];
const _errs1010 = errors;
const _errs1011 = errors;
let valid188 = false;
const _errs1012 = errors;
if(errors === _errs1012){
if(data335 && typeof data335 == "object" && !Array.isArray(data335)){
let missing120;
if(((data335.kind === undefined) && (missing120 = "kind")) || ((data335.target === undefined) && (missing120 = "target"))){
const err1019 = {instancePath:instancePath+"/status/diagnostic/actions/" + i28,schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/diagnostic/anyOf/0/properties/actions/items/anyOf/0/required",keyword:"required",params:{missingProperty: missing120},message:"must have required property '"+missing120+"'"};
if(vErrors === null){
vErrors = [err1019];
}
else {
vErrors.push(err1019);
}
errors++;
}
else {
const _errs1014 = errors;
for(const key120 in data335){
if(!((key120 === "kind") || (key120 === "target"))){
const err1020 = {instancePath:instancePath+"/status/diagnostic/actions/" + i28,schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/diagnostic/anyOf/0/properties/actions/items/anyOf/0/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key120},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err1020];
}
else {
vErrors.push(err1020);
}
errors++;
break;
}
}
if(_errs1014 === errors){
if(data335.kind !== undefined){
let data336 = data335.kind;
const _errs1015 = errors;
if(typeof data336 !== "string"){
const err1021 = {instancePath:instancePath+"/status/diagnostic/actions/" + i28+"/kind",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/diagnostic/anyOf/0/properties/actions/items/anyOf/0/properties/kind/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err1021];
}
else {
vErrors.push(err1021);
}
errors++;
}
if(!(((((((((((data336 === "correct_input") || (data336 === "inspect_status")) || (data336 === "resume_exact")) || (data336 === "cancel_wait")) || (data336 === "cancel_mutation")) || (data336 === "refresh")) || (data336 === "recompile")) || (data336 === "retry_read")) || (data336 === "inspect_scope")) || (data336 === "reconcile_effect")) || (data336 === "contact_operator"))){
const err1022 = {instancePath:instancePath+"/status/diagnostic/actions/" + i28+"/kind",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/diagnostic/anyOf/0/properties/actions/items/anyOf/0/properties/kind/enum",keyword:"enum",params:{allowedValues: schema33.oneOf[9].properties.status.anyOf[0].properties.diagnostic.anyOf[0].properties.actions.items.anyOf[0].properties.kind.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err1022];
}
else {
vErrors.push(err1022);
}
errors++;
}
var valid189 = _errs1015 === errors;
}
else {
var valid189 = true;
}
if(valid189){
if(data335.target !== undefined){
let data337 = data335.target;
const _errs1017 = errors;
const _errs1018 = errors;
let valid190 = false;
const _errs1019 = errors;
if(errors === _errs1019){
if(data337 && typeof data337 == "object" && !Array.isArray(data337)){
let missing121;
if((((((data337.domain === undefined) && (missing121 = "domain")) || ((data337.id === undefined) && (missing121 = "id"))) || ((data337.realm === undefined) && (missing121 = "realm"))) || ((data337.resource === undefined) && (missing121 = "resource"))) || ((data337.sequence === undefined) && (missing121 = "sequence"))){
const err1023 = {instancePath:instancePath+"/status/diagnostic/actions/" + i28+"/target",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/diagnostic/anyOf/0/properties/actions/items/anyOf/0/properties/target/anyOf/0/required",keyword:"required",params:{missingProperty: missing121},message:"must have required property '"+missing121+"'"};
if(vErrors === null){
vErrors = [err1023];
}
else {
vErrors.push(err1023);
}
errors++;
}
else {
const _errs1021 = errors;
for(const key121 in data337){
if(!(((((key121 === "domain") || (key121 === "id")) || (key121 === "realm")) || (key121 === "resource")) || (key121 === "sequence"))){
const err1024 = {instancePath:instancePath+"/status/diagnostic/actions/" + i28+"/target",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/diagnostic/anyOf/0/properties/actions/items/anyOf/0/properties/target/anyOf/0/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key121},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err1024];
}
else {
vErrors.push(err1024);
}
errors++;
break;
}
}
if(_errs1021 === errors){
if(data337.domain !== undefined){
let data338 = data337.domain;
const _errs1022 = errors;
if(typeof data338 !== "string"){
const err1025 = {instancePath:instancePath+"/status/diagnostic/actions/" + i28+"/target/domain",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/diagnostic/anyOf/0/properties/actions/items/anyOf/0/properties/target/anyOf/0/properties/domain/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err1025];
}
else {
vErrors.push(err1025);
}
errors++;
}
if(!(((((((((((data338 === "sql") || (data338 === "query")) || (data338 === "mutation")) || (data338 === "catalog")) || (data338 === "application")) || (data338 === "publication")) || (data338 === "migration")) || (data338 === "reactive")) || (data338 === "effect")) || (data338 === "transport")) || (data338 === "internal"))){
const err1026 = {instancePath:instancePath+"/status/diagnostic/actions/" + i28+"/target/domain",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/diagnostic/anyOf/0/properties/actions/items/anyOf/0/properties/target/anyOf/0/properties/domain/enum",keyword:"enum",params:{allowedValues: schema33.oneOf[9].properties.status.anyOf[0].properties.diagnostic.anyOf[0].properties.actions.items.anyOf[0].properties.target.anyOf[0].properties.domain.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err1026];
}
else {
vErrors.push(err1026);
}
errors++;
}
var valid191 = _errs1022 === errors;
}
else {
var valid191 = true;
}
if(valid191){
if(data337.id !== undefined){
let data339 = data337.id;
const _errs1024 = errors;
if(errors === _errs1024){
if(typeof data339 === "string"){
if(func1(data339) > 20){
const err1027 = {instancePath:instancePath+"/status/diagnostic/actions/" + i28+"/target/id",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/diagnostic/anyOf/0/properties/actions/items/anyOf/0/properties/target/anyOf/0/properties/id/maxLength",keyword:"maxLength",params:{limit: 20},message:"must NOT have more than 20 characters"};
if(vErrors === null){
vErrors = [err1027];
}
else {
vErrors.push(err1027);
}
errors++;
}
else {
if(!pattern7.test(data339)){
const err1028 = {instancePath:instancePath+"/status/diagnostic/actions/" + i28+"/target/id",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/diagnostic/anyOf/0/properties/actions/items/anyOf/0/properties/target/anyOf/0/properties/id/pattern",keyword:"pattern",params:{pattern: "^(0|[1-9][0-9]*)$"},message:"must match pattern \""+"^(0|[1-9][0-9]*)$"+"\""};
if(vErrors === null){
vErrors = [err1028];
}
else {
vErrors.push(err1028);
}
errors++;
}
}
}
else {
const err1029 = {instancePath:instancePath+"/status/diagnostic/actions/" + i28+"/target/id",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/diagnostic/anyOf/0/properties/actions/items/anyOf/0/properties/target/anyOf/0/properties/id/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err1029];
}
else {
vErrors.push(err1029);
}
errors++;
}
}
var valid191 = _errs1024 === errors;
}
else {
var valid191 = true;
}
if(valid191){
if(data337.realm !== undefined){
let data340 = data337.realm;
const _errs1026 = errors;
const _errs1027 = errors;
let valid192 = false;
const _errs1028 = errors;
if(errors === _errs1028){
if(typeof data340 === "string"){
if(func1(data340) > 20){
const err1030 = {instancePath:instancePath+"/status/diagnostic/actions/" + i28+"/target/realm",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/diagnostic/anyOf/0/properties/actions/items/anyOf/0/properties/target/anyOf/0/properties/realm/anyOf/0/maxLength",keyword:"maxLength",params:{limit: 20},message:"must NOT have more than 20 characters"};
if(vErrors === null){
vErrors = [err1030];
}
else {
vErrors.push(err1030);
}
errors++;
}
else {
if(!pattern7.test(data340)){
const err1031 = {instancePath:instancePath+"/status/diagnostic/actions/" + i28+"/target/realm",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/diagnostic/anyOf/0/properties/actions/items/anyOf/0/properties/target/anyOf/0/properties/realm/anyOf/0/pattern",keyword:"pattern",params:{pattern: "^(0|[1-9][0-9]*)$"},message:"must match pattern \""+"^(0|[1-9][0-9]*)$"+"\""};
if(vErrors === null){
vErrors = [err1031];
}
else {
vErrors.push(err1031);
}
errors++;
}
}
}
else {
const err1032 = {instancePath:instancePath+"/status/diagnostic/actions/" + i28+"/target/realm",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/diagnostic/anyOf/0/properties/actions/items/anyOf/0/properties/target/anyOf/0/properties/realm/anyOf/0/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err1032];
}
else {
vErrors.push(err1032);
}
errors++;
}
}
var _valid41 = _errs1028 === errors;
valid192 = valid192 || _valid41;
const _errs1030 = errors;
if(data340 !== null){
const err1033 = {instancePath:instancePath+"/status/diagnostic/actions/" + i28+"/target/realm",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/diagnostic/anyOf/0/properties/actions/items/anyOf/0/properties/target/anyOf/0/properties/realm/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err1033];
}
else {
vErrors.push(err1033);
}
errors++;
}
var _valid41 = _errs1030 === errors;
valid192 = valid192 || _valid41;
if(!valid192){
const err1034 = {instancePath:instancePath+"/status/diagnostic/actions/" + i28+"/target/realm",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/diagnostic/anyOf/0/properties/actions/items/anyOf/0/properties/target/anyOf/0/properties/realm/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err1034];
}
else {
vErrors.push(err1034);
}
errors++;
}
else {
errors = _errs1027;
if(vErrors !== null){
if(_errs1027){
vErrors.length = _errs1027;
}
else {
vErrors = null;
}
}
}
var valid191 = _errs1026 === errors;
}
else {
var valid191 = true;
}
if(valid191){
if(data337.resource !== undefined){
let data341 = data337.resource;
const _errs1032 = errors;
const _errs1033 = errors;
let valid193 = false;
const _errs1034 = errors;
if(errors === _errs1034){
if(typeof data341 === "string"){
if(func1(data341) > 20){
const err1035 = {instancePath:instancePath+"/status/diagnostic/actions/" + i28+"/target/resource",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/diagnostic/anyOf/0/properties/actions/items/anyOf/0/properties/target/anyOf/0/properties/resource/anyOf/0/maxLength",keyword:"maxLength",params:{limit: 20},message:"must NOT have more than 20 characters"};
if(vErrors === null){
vErrors = [err1035];
}
else {
vErrors.push(err1035);
}
errors++;
}
else {
if(!pattern7.test(data341)){
const err1036 = {instancePath:instancePath+"/status/diagnostic/actions/" + i28+"/target/resource",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/diagnostic/anyOf/0/properties/actions/items/anyOf/0/properties/target/anyOf/0/properties/resource/anyOf/0/pattern",keyword:"pattern",params:{pattern: "^(0|[1-9][0-9]*)$"},message:"must match pattern \""+"^(0|[1-9][0-9]*)$"+"\""};
if(vErrors === null){
vErrors = [err1036];
}
else {
vErrors.push(err1036);
}
errors++;
}
}
}
else {
const err1037 = {instancePath:instancePath+"/status/diagnostic/actions/" + i28+"/target/resource",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/diagnostic/anyOf/0/properties/actions/items/anyOf/0/properties/target/anyOf/0/properties/resource/anyOf/0/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err1037];
}
else {
vErrors.push(err1037);
}
errors++;
}
}
var _valid42 = _errs1034 === errors;
valid193 = valid193 || _valid42;
const _errs1036 = errors;
if(data341 !== null){
const err1038 = {instancePath:instancePath+"/status/diagnostic/actions/" + i28+"/target/resource",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/diagnostic/anyOf/0/properties/actions/items/anyOf/0/properties/target/anyOf/0/properties/resource/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err1038];
}
else {
vErrors.push(err1038);
}
errors++;
}
var _valid42 = _errs1036 === errors;
valid193 = valid193 || _valid42;
if(!valid193){
const err1039 = {instancePath:instancePath+"/status/diagnostic/actions/" + i28+"/target/resource",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/diagnostic/anyOf/0/properties/actions/items/anyOf/0/properties/target/anyOf/0/properties/resource/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err1039];
}
else {
vErrors.push(err1039);
}
errors++;
}
else {
errors = _errs1033;
if(vErrors !== null){
if(_errs1033){
vErrors.length = _errs1033;
}
else {
vErrors = null;
}
}
}
var valid191 = _errs1032 === errors;
}
else {
var valid191 = true;
}
if(valid191){
if(data337.sequence !== undefined){
let data342 = data337.sequence;
const _errs1038 = errors;
const _errs1039 = errors;
let valid194 = false;
const _errs1040 = errors;
if(errors === _errs1040){
if(typeof data342 === "string"){
if(func1(data342) > 20){
const err1040 = {instancePath:instancePath+"/status/diagnostic/actions/" + i28+"/target/sequence",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/diagnostic/anyOf/0/properties/actions/items/anyOf/0/properties/target/anyOf/0/properties/sequence/anyOf/0/maxLength",keyword:"maxLength",params:{limit: 20},message:"must NOT have more than 20 characters"};
if(vErrors === null){
vErrors = [err1040];
}
else {
vErrors.push(err1040);
}
errors++;
}
else {
if(!pattern7.test(data342)){
const err1041 = {instancePath:instancePath+"/status/diagnostic/actions/" + i28+"/target/sequence",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/diagnostic/anyOf/0/properties/actions/items/anyOf/0/properties/target/anyOf/0/properties/sequence/anyOf/0/pattern",keyword:"pattern",params:{pattern: "^(0|[1-9][0-9]*)$"},message:"must match pattern \""+"^(0|[1-9][0-9]*)$"+"\""};
if(vErrors === null){
vErrors = [err1041];
}
else {
vErrors.push(err1041);
}
errors++;
}
}
}
else {
const err1042 = {instancePath:instancePath+"/status/diagnostic/actions/" + i28+"/target/sequence",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/diagnostic/anyOf/0/properties/actions/items/anyOf/0/properties/target/anyOf/0/properties/sequence/anyOf/0/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err1042];
}
else {
vErrors.push(err1042);
}
errors++;
}
}
var _valid43 = _errs1040 === errors;
valid194 = valid194 || _valid43;
const _errs1042 = errors;
if(data342 !== null){
const err1043 = {instancePath:instancePath+"/status/diagnostic/actions/" + i28+"/target/sequence",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/diagnostic/anyOf/0/properties/actions/items/anyOf/0/properties/target/anyOf/0/properties/sequence/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err1043];
}
else {
vErrors.push(err1043);
}
errors++;
}
var _valid43 = _errs1042 === errors;
valid194 = valid194 || _valid43;
if(!valid194){
const err1044 = {instancePath:instancePath+"/status/diagnostic/actions/" + i28+"/target/sequence",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/diagnostic/anyOf/0/properties/actions/items/anyOf/0/properties/target/anyOf/0/properties/sequence/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err1044];
}
else {
vErrors.push(err1044);
}
errors++;
}
else {
errors = _errs1039;
if(vErrors !== null){
if(_errs1039){
vErrors.length = _errs1039;
}
else {
vErrors = null;
}
}
}
var valid191 = _errs1038 === errors;
}
else {
var valid191 = true;
}
}
}
}
}
}
}
}
else {
const err1045 = {instancePath:instancePath+"/status/diagnostic/actions/" + i28+"/target",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/diagnostic/anyOf/0/properties/actions/items/anyOf/0/properties/target/anyOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err1045];
}
else {
vErrors.push(err1045);
}
errors++;
}
}
var _valid40 = _errs1019 === errors;
valid190 = valid190 || _valid40;
const _errs1044 = errors;
if(data337 !== null){
const err1046 = {instancePath:instancePath+"/status/diagnostic/actions/" + i28+"/target",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/diagnostic/anyOf/0/properties/actions/items/anyOf/0/properties/target/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err1046];
}
else {
vErrors.push(err1046);
}
errors++;
}
var _valid40 = _errs1044 === errors;
valid190 = valid190 || _valid40;
if(!valid190){
const err1047 = {instancePath:instancePath+"/status/diagnostic/actions/" + i28+"/target",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/diagnostic/anyOf/0/properties/actions/items/anyOf/0/properties/target/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err1047];
}
else {
vErrors.push(err1047);
}
errors++;
}
else {
errors = _errs1018;
if(vErrors !== null){
if(_errs1018){
vErrors.length = _errs1018;
}
else {
vErrors = null;
}
}
}
var valid189 = _errs1017 === errors;
}
else {
var valid189 = true;
}
}
}
}
}
else {
const err1048 = {instancePath:instancePath+"/status/diagnostic/actions/" + i28,schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/diagnostic/anyOf/0/properties/actions/items/anyOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err1048];
}
else {
vErrors.push(err1048);
}
errors++;
}
}
var _valid39 = _errs1012 === errors;
valid188 = valid188 || _valid39;
const _errs1046 = errors;
if(data335 !== null){
const err1049 = {instancePath:instancePath+"/status/diagnostic/actions/" + i28,schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/diagnostic/anyOf/0/properties/actions/items/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err1049];
}
else {
vErrors.push(err1049);
}
errors++;
}
var _valid39 = _errs1046 === errors;
valid188 = valid188 || _valid39;
if(!valid188){
const err1050 = {instancePath:instancePath+"/status/diagnostic/actions/" + i28,schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/diagnostic/anyOf/0/properties/actions/items/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err1050];
}
else {
vErrors.push(err1050);
}
errors++;
}
else {
errors = _errs1011;
if(vErrors !== null){
if(_errs1011){
vErrors.length = _errs1011;
}
else {
vErrors = null;
}
}
}
var valid187 = _errs1010 === errors;
if(!valid187){
break;
}
}
}
}
}
else {
const err1051 = {instancePath:instancePath+"/status/diagnostic/actions",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/diagnostic/anyOf/0/properties/actions/type",keyword:"type",params:{type: "array"},message:"must be array"};
if(vErrors === null){
vErrors = [err1051];
}
else {
vErrors.push(err1051);
}
errors++;
}
}
var valid161 = _errs1008 === errors;
}
else {
var valid161 = true;
}
}
}
}
}
}
}
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
const err1052 = {instancePath:instancePath+"/status/diagnostic",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/diagnostic/anyOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err1052];
}
else {
vErrors.push(err1052);
}
errors++;
}
}
var _valid25 = _errs846 === errors;
valid160 = valid160 || _valid25;
const _errs1048 = errors;
if(data288 !== null){
const err1053 = {instancePath:instancePath+"/status/diagnostic",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/diagnostic/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err1053];
}
else {
vErrors.push(err1053);
}
errors++;
}
var _valid25 = _errs1048 === errors;
valid160 = valid160 || _valid25;
if(!valid160){
const err1054 = {instancePath:instancePath+"/status/diagnostic",schemaPath:"#/oneOf/9/properties/status/anyOf/0/properties/diagnostic/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err1054];
}
else {
vErrors.push(err1054);
}
errors++;
}
else {
errors = _errs845;
if(vErrors !== null){
if(_errs845){
vErrors.length = _errs845;
}
else {
vErrors = null;
}
}
}
var valid156 = _errs844 === errors;
}
else {
var valid156 = true;
}
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
const err1055 = {instancePath:instancePath+"/status",schemaPath:"#/oneOf/9/properties/status/anyOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err1055];
}
else {
vErrors.push(err1055);
}
errors++;
}
}
var _valid22 = _errs810 === errors;
valid155 = valid155 || _valid22;
const _errs1050 = errors;
if(data276 !== null){
const err1056 = {instancePath:instancePath+"/status",schemaPath:"#/oneOf/9/properties/status/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err1056];
}
else {
vErrors.push(err1056);
}
errors++;
}
var _valid22 = _errs1050 === errors;
valid155 = valid155 || _valid22;
if(!valid155){
const err1057 = {instancePath:instancePath+"/status",schemaPath:"#/oneOf/9/properties/status/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err1057];
}
else {
vErrors.push(err1057);
}
errors++;
}
else {
errors = _errs809;
if(vErrors !== null){
if(_errs809){
vErrors.length = _errs809;
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
const err1058 = {instancePath,schemaPath:"#/oneOf/9/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err1058];
}
else {
vErrors.push(err1058);
}
errors++;
}
}
var _valid0 = _errs805 === errors;
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
const _errs1052 = errors;
if(errors === _errs1052){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing122;
if((data.page === undefined) && (missing122 = "page")){
const err1059 = {instancePath,schemaPath:"#/oneOf/10/required",keyword:"required",params:{missingProperty: missing122},message:"must have required property '"+missing122+"'"};
if(vErrors === null){
vErrors = [err1059];
}
else {
vErrors.push(err1059);
}
errors++;
}
else {
const _errs1054 = errors;
for(const key122 in data){
if(!(key122 === "page")){
const err1060 = {instancePath,schemaPath:"#/oneOf/10/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key122},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err1060];
}
else {
vErrors.push(err1060);
}
errors++;
break;
}
}
if(_errs1054 === errors){
if(data.page !== undefined){
let data343 = data.page;
const _errs1055 = errors;
if(errors === _errs1055){
if(data343 && typeof data343 == "object" && !Array.isArray(data343)){
let missing123;
if(((data343.evidence === undefined) && (missing123 = "evidence")) || ((data343.cells === undefined) && (missing123 = "cells"))){
const err1061 = {instancePath:instancePath+"/page",schemaPath:"#/oneOf/10/properties/page/required",keyword:"required",params:{missingProperty: missing123},message:"must have required property '"+missing123+"'"};
if(vErrors === null){
vErrors = [err1061];
}
else {
vErrors.push(err1061);
}
errors++;
}
else {
const _errs1057 = errors;
for(const key123 in data343){
if(!((key123 === "evidence") || (key123 === "cells"))){
const err1062 = {instancePath:instancePath+"/page",schemaPath:"#/oneOf/10/properties/page/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key123},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err1062];
}
else {
vErrors.push(err1062);
}
errors++;
break;
}
}
if(_errs1057 === errors){
if(data343.evidence !== undefined){
let data344 = data343.evidence;
const _errs1058 = errors;
if(errors === _errs1058){
if(data344 && typeof data344 == "object" && !Array.isArray(data344)){
let missing124;
if(((((((data344.manifest === undefined) && (missing124 = "manifest")) || ((data344.columns === undefined) && (missing124 = "columns"))) || ((data344.ordinal === undefined) && (missing124 = "ordinal"))) || ((data344.rows === undefined) && (missing124 = "rows"))) || ((data344.ipc === undefined) && (missing124 = "ipc"))) || ((data344.next === undefined) && (missing124 = "next"))){
const err1063 = {instancePath:instancePath+"/page/evidence",schemaPath:"#/oneOf/10/properties/page/properties/evidence/required",keyword:"required",params:{missingProperty: missing124},message:"must have required property '"+missing124+"'"};
if(vErrors === null){
vErrors = [err1063];
}
else {
vErrors.push(err1063);
}
errors++;
}
else {
const _errs1060 = errors;
for(const key124 in data344){
if(!((((((key124 === "manifest") || (key124 === "columns")) || (key124 === "ordinal")) || (key124 === "rows")) || (key124 === "ipc")) || (key124 === "next"))){
const err1064 = {instancePath:instancePath+"/page/evidence",schemaPath:"#/oneOf/10/properties/page/properties/evidence/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key124},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err1064];
}
else {
vErrors.push(err1064);
}
errors++;
break;
}
}
if(_errs1060 === errors){
if(data344.manifest !== undefined){
let data345 = data344.manifest;
const _errs1061 = errors;
if(errors === _errs1061){
if(data345 && typeof data345 == "object" && !Array.isArray(data345)){
let missing125;
if(((((((((((((((((((data345.job === undefined) && (missing125 = "job")) || ((data345.source === undefined) && (missing125 = "source"))) || ((data345.requester === undefined) && (missing125 = "requester"))) || ((data345.correlation === undefined) && (missing125 = "correlation"))) || ((data345.policy_revision === undefined) && (missing125 = "policy_revision"))) || ((data345.request === undefined) && (missing125 = "request"))) || ((data345.basis === undefined) && (missing125 = "basis"))) || ((data345.plan === undefined) && (missing125 = "plan"))) || ((data345.pages === undefined) && (missing125 = "pages"))) || ((data345.scanned === undefined) && (missing125 = "scanned"))) || ((data345.selected === undefined) && (missing125 = "selected"))) || ((data345.value_count === undefined) && (missing125 = "value_count"))) || ((data345.segments === undefined) && (missing125 = "segments"))) || ((data345.rows === undefined) && (missing125 = "rows"))) || ((data345.bytes === undefined) && (missing125 = "bytes"))) || ((data345.sum === undefined) && (missing125 = "sum"))) || ((data345.finished === undefined) && (missing125 = "finished"))) || ((data345.chain === undefined) && (missing125 = "chain"))){
const err1065 = {instancePath:instancePath+"/page/evidence/manifest",schemaPath:"#/oneOf/10/properties/page/properties/evidence/properties/manifest/required",keyword:"required",params:{missingProperty: missing125},message:"must have required property '"+missing125+"'"};
if(vErrors === null){
vErrors = [err1065];
}
else {
vErrors.push(err1065);
}
errors++;
}
else {
const _errs1063 = errors;
for(const key125 in data345){
if(!(func24.call(schema33.oneOf[10].properties.page.properties.evidence.properties.manifest.properties, key125))){
const err1066 = {instancePath:instancePath+"/page/evidence/manifest",schemaPath:"#/oneOf/10/properties/page/properties/evidence/properties/manifest/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key125},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err1066];
}
else {
vErrors.push(err1066);
}
errors++;
break;
}
}
if(_errs1063 === errors){
if(data345.job !== undefined){
let data346 = data345.job;
const _errs1064 = errors;
if(!(((typeof data346 == "number") && (!(data346 % 1) && !isNaN(data346))) && (isFinite(data346)))){
const err1067 = {instancePath:instancePath+"/page/evidence/manifest/job",schemaPath:"#/oneOf/10/properties/page/properties/evidence/properties/manifest/properties/job/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err1067];
}
else {
vErrors.push(err1067);
}
errors++;
}
if(errors === _errs1064){
if((typeof data346 == "number") && (isFinite(data346))){
if(data346 > 9007199254740991 || isNaN(data346)){
const err1068 = {instancePath:instancePath+"/page/evidence/manifest/job",schemaPath:"#/oneOf/10/properties/page/properties/evidence/properties/manifest/properties/job/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"};
if(vErrors === null){
vErrors = [err1068];
}
else {
vErrors.push(err1068);
}
errors++;
}
else {
if(data346 < 0 || isNaN(data346)){
const err1069 = {instancePath:instancePath+"/page/evidence/manifest/job",schemaPath:"#/oneOf/10/properties/page/properties/evidence/properties/manifest/properties/job/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err1069];
}
else {
vErrors.push(err1069);
}
errors++;
}
}
}
}
var valid198 = _errs1064 === errors;
}
else {
var valid198 = true;
}
if(valid198){
if(data345.source !== undefined){
let data347 = data345.source;
const _errs1066 = errors;
if(errors === _errs1066){
if(data347 && typeof data347 == "object" && !Array.isArray(data347)){
let missing126;
if((((data347.pid === undefined) && (missing126 = "pid")) || ((data347.input === undefined) && (missing126 = "input"))) || ((data347.index === undefined) && (missing126 = "index"))){
const err1070 = {instancePath:instancePath+"/page/evidence/manifest/source",schemaPath:"#/oneOf/10/properties/page/properties/evidence/properties/manifest/properties/source/required",keyword:"required",params:{missingProperty: missing126},message:"must have required property '"+missing126+"'"};
if(vErrors === null){
vErrors = [err1070];
}
else {
vErrors.push(err1070);
}
errors++;
}
else {
const _errs1068 = errors;
for(const key126 in data347){
if(!(((key126 === "pid") || (key126 === "input")) || (key126 === "index"))){
const err1071 = {instancePath:instancePath+"/page/evidence/manifest/source",schemaPath:"#/oneOf/10/properties/page/properties/evidence/properties/manifest/properties/source/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key126},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err1071];
}
else {
vErrors.push(err1071);
}
errors++;
break;
}
}
if(_errs1068 === errors){
if(data347.pid !== undefined){
let data348 = data347.pid;
const _errs1069 = errors;
if(!(((typeof data348 == "number") && (!(data348 % 1) && !isNaN(data348))) && (isFinite(data348)))){
const err1072 = {instancePath:instancePath+"/page/evidence/manifest/source/pid",schemaPath:"#/oneOf/10/properties/page/properties/evidence/properties/manifest/properties/source/properties/pid/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err1072];
}
else {
vErrors.push(err1072);
}
errors++;
}
if(errors === _errs1069){
if((typeof data348 == "number") && (isFinite(data348))){
if(data348 > 9007199254740991 || isNaN(data348)){
const err1073 = {instancePath:instancePath+"/page/evidence/manifest/source/pid",schemaPath:"#/oneOf/10/properties/page/properties/evidence/properties/manifest/properties/source/properties/pid/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"};
if(vErrors === null){
vErrors = [err1073];
}
else {
vErrors.push(err1073);
}
errors++;
}
else {
if(data348 < 0 || isNaN(data348)){
const err1074 = {instancePath:instancePath+"/page/evidence/manifest/source/pid",schemaPath:"#/oneOf/10/properties/page/properties/evidence/properties/manifest/properties/source/properties/pid/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err1074];
}
else {
vErrors.push(err1074);
}
errors++;
}
}
}
}
var valid199 = _errs1069 === errors;
}
else {
var valid199 = true;
}
if(valid199){
if(data347.input !== undefined){
let data349 = data347.input;
const _errs1071 = errors;
if(!(((typeof data349 == "number") && (!(data349 % 1) && !isNaN(data349))) && (isFinite(data349)))){
const err1075 = {instancePath:instancePath+"/page/evidence/manifest/source/input",schemaPath:"#/oneOf/10/properties/page/properties/evidence/properties/manifest/properties/source/properties/input/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err1075];
}
else {
vErrors.push(err1075);
}
errors++;
}
if(errors === _errs1071){
if((typeof data349 == "number") && (isFinite(data349))){
if(data349 > 9007199254740991 || isNaN(data349)){
const err1076 = {instancePath:instancePath+"/page/evidence/manifest/source/input",schemaPath:"#/oneOf/10/properties/page/properties/evidence/properties/manifest/properties/source/properties/input/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"};
if(vErrors === null){
vErrors = [err1076];
}
else {
vErrors.push(err1076);
}
errors++;
}
else {
if(data349 < 0 || isNaN(data349)){
const err1077 = {instancePath:instancePath+"/page/evidence/manifest/source/input",schemaPath:"#/oneOf/10/properties/page/properties/evidence/properties/manifest/properties/source/properties/input/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err1077];
}
else {
vErrors.push(err1077);
}
errors++;
}
}
}
}
var valid199 = _errs1071 === errors;
}
else {
var valid199 = true;
}
if(valid199){
if(data347.index !== undefined){
let data350 = data347.index;
const _errs1073 = errors;
if(!(((typeof data350 == "number") && (!(data350 % 1) && !isNaN(data350))) && (isFinite(data350)))){
const err1078 = {instancePath:instancePath+"/page/evidence/manifest/source/index",schemaPath:"#/oneOf/10/properties/page/properties/evidence/properties/manifest/properties/source/properties/index/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err1078];
}
else {
vErrors.push(err1078);
}
errors++;
}
if(errors === _errs1073){
if((typeof data350 == "number") && (isFinite(data350))){
if(data350 > 255 || isNaN(data350)){
const err1079 = {instancePath:instancePath+"/page/evidence/manifest/source/index",schemaPath:"#/oneOf/10/properties/page/properties/evidence/properties/manifest/properties/source/properties/index/maximum",keyword:"maximum",params:{comparison: "<=", limit: 255},message:"must be <= 255"};
if(vErrors === null){
vErrors = [err1079];
}
else {
vErrors.push(err1079);
}
errors++;
}
else {
if(data350 < 0 || isNaN(data350)){
const err1080 = {instancePath:instancePath+"/page/evidence/manifest/source/index",schemaPath:"#/oneOf/10/properties/page/properties/evidence/properties/manifest/properties/source/properties/index/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err1080];
}
else {
vErrors.push(err1080);
}
errors++;
}
}
}
}
var valid199 = _errs1073 === errors;
}
else {
var valid199 = true;
}
}
}
}
}
}
else {
const err1081 = {instancePath:instancePath+"/page/evidence/manifest/source",schemaPath:"#/oneOf/10/properties/page/properties/evidence/properties/manifest/properties/source/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err1081];
}
else {
vErrors.push(err1081);
}
errors++;
}
}
var valid198 = _errs1066 === errors;
}
else {
var valid198 = true;
}
if(valid198){
if(data345.requester !== undefined){
let data351 = data345.requester;
const _errs1075 = errors;
if(!(((typeof data351 == "number") && (!(data351 % 1) && !isNaN(data351))) && (isFinite(data351)))){
const err1082 = {instancePath:instancePath+"/page/evidence/manifest/requester",schemaPath:"#/oneOf/10/properties/page/properties/evidence/properties/manifest/properties/requester/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err1082];
}
else {
vErrors.push(err1082);
}
errors++;
}
if(errors === _errs1075){
if((typeof data351 == "number") && (isFinite(data351))){
if(data351 > 9007199254740991 || isNaN(data351)){
const err1083 = {instancePath:instancePath+"/page/evidence/manifest/requester",schemaPath:"#/oneOf/10/properties/page/properties/evidence/properties/manifest/properties/requester/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"};
if(vErrors === null){
vErrors = [err1083];
}
else {
vErrors.push(err1083);
}
errors++;
}
else {
if(data351 < 0 || isNaN(data351)){
const err1084 = {instancePath:instancePath+"/page/evidence/manifest/requester",schemaPath:"#/oneOf/10/properties/page/properties/evidence/properties/manifest/properties/requester/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err1084];
}
else {
vErrors.push(err1084);
}
errors++;
}
}
}
}
var valid198 = _errs1075 === errors;
}
else {
var valid198 = true;
}
if(valid198){
if(data345.correlation !== undefined){
let data352 = data345.correlation;
const _errs1077 = errors;
if(errors === _errs1077){
if(typeof data352 === "string"){
if(func1(data352) > 131072){
const err1085 = {instancePath:instancePath+"/page/evidence/manifest/correlation",schemaPath:"#/oneOf/10/properties/page/properties/evidence/properties/manifest/properties/correlation/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err1085];
}
else {
vErrors.push(err1085);
}
errors++;
}
}
else {
const err1086 = {instancePath:instancePath+"/page/evidence/manifest/correlation",schemaPath:"#/oneOf/10/properties/page/properties/evidence/properties/manifest/properties/correlation/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err1086];
}
else {
vErrors.push(err1086);
}
errors++;
}
}
var valid198 = _errs1077 === errors;
}
else {
var valid198 = true;
}
if(valid198){
if(data345.policy_revision !== undefined){
let data353 = data345.policy_revision;
const _errs1079 = errors;
if(errors === _errs1079){
if(typeof data353 === "string"){
if(func1(data353) > 131072){
const err1087 = {instancePath:instancePath+"/page/evidence/manifest/policy_revision",schemaPath:"#/oneOf/10/properties/page/properties/evidence/properties/manifest/properties/policy_revision/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err1087];
}
else {
vErrors.push(err1087);
}
errors++;
}
}
else {
const err1088 = {instancePath:instancePath+"/page/evidence/manifest/policy_revision",schemaPath:"#/oneOf/10/properties/page/properties/evidence/properties/manifest/properties/policy_revision/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err1088];
}
else {
vErrors.push(err1088);
}
errors++;
}
}
var valid198 = _errs1079 === errors;
}
else {
var valid198 = true;
}
if(valid198){
if(data345.request !== undefined){
let data354 = data345.request;
const _errs1081 = errors;
if(errors === _errs1081){
if(typeof data354 === "string"){
if(func1(data354) > 512){
const err1089 = {instancePath:instancePath+"/page/evidence/manifest/request",schemaPath:"#/oneOf/10/properties/page/properties/evidence/properties/manifest/properties/request/maxLength",keyword:"maxLength",params:{limit: 512},message:"must NOT have more than 512 characters"};
if(vErrors === null){
vErrors = [err1089];
}
else {
vErrors.push(err1089);
}
errors++;
}
else {
if(!pattern4.test(data354)){
const err1090 = {instancePath:instancePath+"/page/evidence/manifest/request",schemaPath:"#/oneOf/10/properties/page/properties/evidence/properties/manifest/properties/request/pattern",keyword:"pattern",params:{pattern: "^(?:[0-9a-f]{2})*$"},message:"must match pattern \""+"^(?:[0-9a-f]{2})*$"+"\""};
if(vErrors === null){
vErrors = [err1090];
}
else {
vErrors.push(err1090);
}
errors++;
}
}
}
else {
const err1091 = {instancePath:instancePath+"/page/evidence/manifest/request",schemaPath:"#/oneOf/10/properties/page/properties/evidence/properties/manifest/properties/request/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err1091];
}
else {
vErrors.push(err1091);
}
errors++;
}
}
var valid198 = _errs1081 === errors;
}
else {
var valid198 = true;
}
if(valid198){
if(data345.basis !== undefined){
let data355 = data345.basis;
const _errs1083 = errors;
if(errors === _errs1083){
if(data355 && typeof data355 == "object" && !Array.isArray(data355)){
let missing127;
if((((((data355.kind === undefined) && (missing127 = "kind")) || ((data355.resource === undefined) && (missing127 = "resource"))) || ((data355.revision === undefined) && (missing127 = "revision"))) || ((data355.contract === undefined) && (missing127 = "contract"))) || ((data355.schema === undefined) && (missing127 = "schema"))){
const err1092 = {instancePath:instancePath+"/page/evidence/manifest/basis",schemaPath:"#/oneOf/10/properties/page/properties/evidence/properties/manifest/properties/basis/required",keyword:"required",params:{missingProperty: missing127},message:"must have required property '"+missing127+"'"};
if(vErrors === null){
vErrors = [err1092];
}
else {
vErrors.push(err1092);
}
errors++;
}
else {
const _errs1085 = errors;
for(const key127 in data355){
if(!(((((key127 === "kind") || (key127 === "resource")) || (key127 === "revision")) || (key127 === "contract")) || (key127 === "schema"))){
const err1093 = {instancePath:instancePath+"/page/evidence/manifest/basis",schemaPath:"#/oneOf/10/properties/page/properties/evidence/properties/manifest/properties/basis/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key127},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err1093];
}
else {
vErrors.push(err1093);
}
errors++;
break;
}
}
if(_errs1085 === errors){
if(data355.kind !== undefined){
let data356 = data355.kind;
const _errs1086 = errors;
if(typeof data356 !== "string"){
const err1094 = {instancePath:instancePath+"/page/evidence/manifest/basis/kind",schemaPath:"#/oneOf/10/properties/page/properties/evidence/properties/manifest/properties/basis/properties/kind/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err1094];
}
else {
vErrors.push(err1094);
}
errors++;
}
if(!(((data356 === "kv") || (data356 === "table")) || (data356 === "document"))){
const err1095 = {instancePath:instancePath+"/page/evidence/manifest/basis/kind",schemaPath:"#/oneOf/10/properties/page/properties/evidence/properties/manifest/properties/basis/properties/kind/enum",keyword:"enum",params:{allowedValues: schema33.oneOf[10].properties.page.properties.evidence.properties.manifest.properties.basis.properties.kind.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err1095];
}
else {
vErrors.push(err1095);
}
errors++;
}
var valid200 = _errs1086 === errors;
}
else {
var valid200 = true;
}
if(valid200){
if(data355.resource !== undefined){
let data357 = data355.resource;
const _errs1088 = errors;
if(!(((typeof data357 == "number") && (!(data357 % 1) && !isNaN(data357))) && (isFinite(data357)))){
const err1096 = {instancePath:instancePath+"/page/evidence/manifest/basis/resource",schemaPath:"#/oneOf/10/properties/page/properties/evidence/properties/manifest/properties/basis/properties/resource/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err1096];
}
else {
vErrors.push(err1096);
}
errors++;
}
if(errors === _errs1088){
if((typeof data357 == "number") && (isFinite(data357))){
if(data357 > 9007199254740991 || isNaN(data357)){
const err1097 = {instancePath:instancePath+"/page/evidence/manifest/basis/resource",schemaPath:"#/oneOf/10/properties/page/properties/evidence/properties/manifest/properties/basis/properties/resource/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"};
if(vErrors === null){
vErrors = [err1097];
}
else {
vErrors.push(err1097);
}
errors++;
}
else {
if(data357 < 0 || isNaN(data357)){
const err1098 = {instancePath:instancePath+"/page/evidence/manifest/basis/resource",schemaPath:"#/oneOf/10/properties/page/properties/evidence/properties/manifest/properties/basis/properties/resource/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err1098];
}
else {
vErrors.push(err1098);
}
errors++;
}
}
}
}
var valid200 = _errs1088 === errors;
}
else {
var valid200 = true;
}
if(valid200){
if(data355.revision !== undefined){
let data358 = data355.revision;
const _errs1090 = errors;
if(!(((typeof data358 == "number") && (!(data358 % 1) && !isNaN(data358))) && (isFinite(data358)))){
const err1099 = {instancePath:instancePath+"/page/evidence/manifest/basis/revision",schemaPath:"#/oneOf/10/properties/page/properties/evidence/properties/manifest/properties/basis/properties/revision/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err1099];
}
else {
vErrors.push(err1099);
}
errors++;
}
if(errors === _errs1090){
if((typeof data358 == "number") && (isFinite(data358))){
if(data358 > 9007199254740991 || isNaN(data358)){
const err1100 = {instancePath:instancePath+"/page/evidence/manifest/basis/revision",schemaPath:"#/oneOf/10/properties/page/properties/evidence/properties/manifest/properties/basis/properties/revision/maximum",keyword:"maximum",params:{comparison: "<=", limit: 9007199254740991},message:"must be <= 9007199254740991"};
if(vErrors === null){
vErrors = [err1100];
}
else {
vErrors.push(err1100);
}
errors++;
}
else {
if(data358 < 0 || isNaN(data358)){
const err1101 = {instancePath:instancePath+"/page/evidence/manifest/basis/revision",schemaPath:"#/oneOf/10/properties/page/properties/evidence/properties/manifest/properties/basis/properties/revision/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err1101];
}
else {
vErrors.push(err1101);
}
errors++;
}
}
}
}
var valid200 = _errs1090 === errors;
}
else {
var valid200 = true;
}
if(valid200){
if(data355.contract !== undefined){
let data359 = data355.contract;
const _errs1092 = errors;
if(errors === _errs1092){
if(Array.isArray(data359)){
if(data359.length > 32){
const err1102 = {instancePath:instancePath+"/page/evidence/manifest/basis/contract",schemaPath:"#/oneOf/10/properties/page/properties/evidence/properties/manifest/properties/basis/properties/contract/maxItems",keyword:"maxItems",params:{limit: 32},message:"must NOT have more than 32 items"};
if(vErrors === null){
vErrors = [err1102];
}
else {
vErrors.push(err1102);
}
errors++;
}
else {
if(data359.length < 32){
const err1103 = {instancePath:instancePath+"/page/evidence/manifest/basis/contract",schemaPath:"#/oneOf/10/properties/page/properties/evidence/properties/manifest/properties/basis/properties/contract/minItems",keyword:"minItems",params:{limit: 32},message:"must NOT have fewer than 32 items"};
if(vErrors === null){
vErrors = [err1103];
}
else {
vErrors.push(err1103);
}
errors++;
}
else {
var valid201 = true;
const len29 = data359.length;
for(let i29=0; i29<len29; i29++){
let data360 = data359[i29];
const _errs1094 = errors;
if(!(((typeof data360 == "number") && (!(data360 % 1) && !isNaN(data360))) && (isFinite(data360)))){
const err1104 = {instancePath:instancePath+"/page/evidence/manifest/basis/contract/" + i29,schemaPath:"#/oneOf/10/properties/page/properties/evidence/properties/manifest/properties/basis/properties/contract/items/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err1104];
}
else {
vErrors.push(err1104);
}
errors++;
}
if(errors === _errs1094){
if((typeof data360 == "number") && (isFinite(data360))){
if(data360 > 255 || isNaN(data360)){
const err1105 = {instancePath:instancePath+"/page/evidence/manifest/basis/contract/" + i29,schemaPath:"#/oneOf/10/properties/page/properties/evidence/properties/manifest/properties/basis/properties/contract/items/maximum",keyword:"maximum",params:{comparison: "<=", limit: 255},message:"must be <= 255"};
if(vErrors === null){
vErrors = [err1105];
}
else {
vErrors.push(err1105);
}
errors++;
}
else {
if(data360 < 0 || isNaN(data360)){
const err1106 = {instancePath:instancePath+"/page/evidence/manifest/basis/contract/" + i29,schemaPath:"#/oneOf/10/properties/page/properties/evidence/properties/manifest/properties/basis/properties/contract/items/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err1106];
}
else {
vErrors.push(err1106);
}
errors++;
}
}
}
}
var valid201 = _errs1094 === errors;
if(!valid201){
break;
}
}
}
}
}
else {
const err1107 = {instancePath:instancePath+"/page/evidence/manifest/basis/contract",schemaPath:"#/oneOf/10/properties/page/properties/evidence/properties/manifest/properties/basis/properties/contract/type",keyword:"type",params:{type: "array"},message:"must be array"};
if(vErrors === null){
vErrors = [err1107];
}
else {
vErrors.push(err1107);
}
errors++;
}
}
var valid200 = _errs1092 === errors;
}
else {
var valid200 = true;
}
if(valid200){
if(data355.schema !== undefined){
let data361 = data355.schema;
const _errs1096 = errors;
if(errors === _errs1096){
if(Array.isArray(data361)){
if(data361.length > 32){
const err1108 = {instancePath:instancePath+"/page/evidence/manifest/basis/schema",schemaPath:"#/oneOf/10/properties/page/properties/evidence/properties/manifest/properties/basis/properties/schema/maxItems",keyword:"maxItems",params:{limit: 32},message:"must NOT have more than 32 items"};
if(vErrors === null){
vErrors = [err1108];
}
else {
vErrors.push(err1108);
}
errors++;
}
else {
if(data361.length < 32){
const err1109 = {instancePath:instancePath+"/page/evidence/manifest/basis/schema",schemaPath:"#/oneOf/10/properties/page/properties/evidence/properties/manifest/properties/basis/properties/schema/minItems",keyword:"minItems",params:{limit: 32},message:"must NOT have fewer than 32 items"};
if(vErrors === null){
vErrors = [err1109];
}
else {
vErrors.push(err1109);
}
errors++;
}
else {
var valid202 = true;
const len30 = data361.length;
for(let i30=0; i30<len30; i30++){
let data362 = data361[i30];
const _errs1098 = errors;
if(!(((typeof data362 == "number") && (!(data362 % 1) && !isNaN(data362))) && (isFinite(data362)))){
const err1110 = {instancePath:instancePath+"/page/evidence/manifest/basis/schema/" + i30,schemaPath:"#/oneOf/10/properties/page/properties/evidence/properties/manifest/properties/basis/properties/schema/items/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err1110];
}
else {
vErrors.push(err1110);
}
errors++;
}
if(errors === _errs1098){
if((typeof data362 == "number") && (isFinite(data362))){
if(data362 > 255 || isNaN(data362)){
const err1111 = {instancePath:instancePath+"/page/evidence/manifest/basis/schema/" + i30,schemaPath:"#/oneOf/10/properties/page/properties/evidence/properties/manifest/properties/basis/properties/schema/items/maximum",keyword:"maximum",params:{comparison: "<=", limit: 255},message:"must be <= 255"};
if(vErrors === null){
vErrors = [err1111];
}
else {
vErrors.push(err1111);
}
errors++;
}
else {
if(data362 < 0 || isNaN(data362)){
const err1112 = {instancePath:instancePath+"/page/evidence/manifest/basis/schema/" + i30,schemaPath:"#/oneOf/10/properties/page/properties/evidence/properties/manifest/properties/basis/properties/schema/items/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err1112];
}
else {
vErrors.push(err1112);
}
errors++;
}
}
}
}
var valid202 = _errs1098 === errors;
if(!valid202){
break;
}
}
}
}
}
else {
const err1113 = {instancePath:instancePath+"/page/evidence/manifest/basis/schema",schemaPath:"#/oneOf/10/properties/page/properties/evidence/properties/manifest/properties/basis/properties/schema/type",keyword:"type",params:{type: "array"},message:"must be array"};
if(vErrors === null){
vErrors = [err1113];
}
else {
vErrors.push(err1113);
}
errors++;
}
}
var valid200 = _errs1096 === errors;
}
else {
var valid200 = true;
}
}
}
}
}
}
}
}
else {
const err1114 = {instancePath:instancePath+"/page/evidence/manifest/basis",schemaPath:"#/oneOf/10/properties/page/properties/evidence/properties/manifest/properties/basis/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err1114];
}
else {
vErrors.push(err1114);
}
errors++;
}
}
var valid198 = _errs1083 === errors;
}
else {
var valid198 = true;
}
if(valid198){
if(data345.plan !== undefined){
let data363 = data345.plan;
const _errs1100 = errors;
if(errors === _errs1100){
if(Array.isArray(data363)){
if(data363.length > 32){
const err1115 = {instancePath:instancePath+"/page/evidence/manifest/plan",schemaPath:"#/oneOf/10/properties/page/properties/evidence/properties/manifest/properties/plan/maxItems",keyword:"maxItems",params:{limit: 32},message:"must NOT have more than 32 items"};
if(vErrors === null){
vErrors = [err1115];
}
else {
vErrors.push(err1115);
}
errors++;
}
else {
if(data363.length < 32){
const err1116 = {instancePath:instancePath+"/page/evidence/manifest/plan",schemaPath:"#/oneOf/10/properties/page/properties/evidence/properties/manifest/properties/plan/minItems",keyword:"minItems",params:{limit: 32},message:"must NOT have fewer than 32 items"};
if(vErrors === null){
vErrors = [err1116];
}
else {
vErrors.push(err1116);
}
errors++;
}
else {
var valid203 = true;
const len31 = data363.length;
for(let i31=0; i31<len31; i31++){
let data364 = data363[i31];
const _errs1102 = errors;
if(!(((typeof data364 == "number") && (!(data364 % 1) && !isNaN(data364))) && (isFinite(data364)))){
const err1117 = {instancePath:instancePath+"/page/evidence/manifest/plan/" + i31,schemaPath:"#/oneOf/10/properties/page/properties/evidence/properties/manifest/properties/plan/items/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err1117];
}
else {
vErrors.push(err1117);
}
errors++;
}
if(errors === _errs1102){
if((typeof data364 == "number") && (isFinite(data364))){
if(data364 > 255 || isNaN(data364)){
const err1118 = {instancePath:instancePath+"/page/evidence/manifest/plan/" + i31,schemaPath:"#/oneOf/10/properties/page/properties/evidence/properties/manifest/properties/plan/items/maximum",keyword:"maximum",params:{comparison: "<=", limit: 255},message:"must be <= 255"};
if(vErrors === null){
vErrors = [err1118];
}
else {
vErrors.push(err1118);
}
errors++;
}
else {
if(data364 < 0 || isNaN(data364)){
const err1119 = {instancePath:instancePath+"/page/evidence/manifest/plan/" + i31,schemaPath:"#/oneOf/10/properties/page/properties/evidence/properties/manifest/properties/plan/items/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err1119];
}
else {
vErrors.push(err1119);
}
errors++;
}
}
}
}
var valid203 = _errs1102 === errors;
if(!valid203){
break;
}
}
}
}
}
else {
const err1120 = {instancePath:instancePath+"/page/evidence/manifest/plan",schemaPath:"#/oneOf/10/properties/page/properties/evidence/properties/manifest/properties/plan/type",keyword:"type",params:{type: "array"},message:"must be array"};
if(vErrors === null){
vErrors = [err1120];
}
else {
vErrors.push(err1120);
}
errors++;
}
}
var valid198 = _errs1100 === errors;
}
else {
var valid198 = true;
}
if(valid198){
if(data345.pages !== undefined){
let data365 = data345.pages;
const _errs1104 = errors;
if(errors === _errs1104){
if(typeof data365 === "string"){
if(func1(data365) > 131072){
const err1121 = {instancePath:instancePath+"/page/evidence/manifest/pages",schemaPath:"#/oneOf/10/properties/page/properties/evidence/properties/manifest/properties/pages/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err1121];
}
else {
vErrors.push(err1121);
}
errors++;
}
}
else {
const err1122 = {instancePath:instancePath+"/page/evidence/manifest/pages",schemaPath:"#/oneOf/10/properties/page/properties/evidence/properties/manifest/properties/pages/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err1122];
}
else {
vErrors.push(err1122);
}
errors++;
}
}
var valid198 = _errs1104 === errors;
}
else {
var valid198 = true;
}
if(valid198){
if(data345.scanned !== undefined){
let data366 = data345.scanned;
const _errs1106 = errors;
if(errors === _errs1106){
if(typeof data366 === "string"){
if(func1(data366) > 131072){
const err1123 = {instancePath:instancePath+"/page/evidence/manifest/scanned",schemaPath:"#/oneOf/10/properties/page/properties/evidence/properties/manifest/properties/scanned/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err1123];
}
else {
vErrors.push(err1123);
}
errors++;
}
}
else {
const err1124 = {instancePath:instancePath+"/page/evidence/manifest/scanned",schemaPath:"#/oneOf/10/properties/page/properties/evidence/properties/manifest/properties/scanned/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err1124];
}
else {
vErrors.push(err1124);
}
errors++;
}
}
var valid198 = _errs1106 === errors;
}
else {
var valid198 = true;
}
if(valid198){
if(data345.selected !== undefined){
let data367 = data345.selected;
const _errs1108 = errors;
if(errors === _errs1108){
if(typeof data367 === "string"){
if(func1(data367) > 131072){
const err1125 = {instancePath:instancePath+"/page/evidence/manifest/selected",schemaPath:"#/oneOf/10/properties/page/properties/evidence/properties/manifest/properties/selected/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err1125];
}
else {
vErrors.push(err1125);
}
errors++;
}
}
else {
const err1126 = {instancePath:instancePath+"/page/evidence/manifest/selected",schemaPath:"#/oneOf/10/properties/page/properties/evidence/properties/manifest/properties/selected/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err1126];
}
else {
vErrors.push(err1126);
}
errors++;
}
}
var valid198 = _errs1108 === errors;
}
else {
var valid198 = true;
}
if(valid198){
if(data345.value_count !== undefined){
let data368 = data345.value_count;
const _errs1110 = errors;
if(errors === _errs1110){
if(typeof data368 === "string"){
if(func1(data368) > 131072){
const err1127 = {instancePath:instancePath+"/page/evidence/manifest/value_count",schemaPath:"#/oneOf/10/properties/page/properties/evidence/properties/manifest/properties/value_count/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err1127];
}
else {
vErrors.push(err1127);
}
errors++;
}
}
else {
const err1128 = {instancePath:instancePath+"/page/evidence/manifest/value_count",schemaPath:"#/oneOf/10/properties/page/properties/evidence/properties/manifest/properties/value_count/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err1128];
}
else {
vErrors.push(err1128);
}
errors++;
}
}
var valid198 = _errs1110 === errors;
}
else {
var valid198 = true;
}
if(valid198){
if(data345.segments !== undefined){
let data369 = data345.segments;
const _errs1112 = errors;
if(errors === _errs1112){
if(typeof data369 === "string"){
if(func1(data369) > 131072){
const err1129 = {instancePath:instancePath+"/page/evidence/manifest/segments",schemaPath:"#/oneOf/10/properties/page/properties/evidence/properties/manifest/properties/segments/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err1129];
}
else {
vErrors.push(err1129);
}
errors++;
}
}
else {
const err1130 = {instancePath:instancePath+"/page/evidence/manifest/segments",schemaPath:"#/oneOf/10/properties/page/properties/evidence/properties/manifest/properties/segments/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err1130];
}
else {
vErrors.push(err1130);
}
errors++;
}
}
var valid198 = _errs1112 === errors;
}
else {
var valid198 = true;
}
if(valid198){
if(data345.rows !== undefined){
let data370 = data345.rows;
const _errs1114 = errors;
if(errors === _errs1114){
if(typeof data370 === "string"){
if(func1(data370) > 131072){
const err1131 = {instancePath:instancePath+"/page/evidence/manifest/rows",schemaPath:"#/oneOf/10/properties/page/properties/evidence/properties/manifest/properties/rows/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err1131];
}
else {
vErrors.push(err1131);
}
errors++;
}
}
else {
const err1132 = {instancePath:instancePath+"/page/evidence/manifest/rows",schemaPath:"#/oneOf/10/properties/page/properties/evidence/properties/manifest/properties/rows/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err1132];
}
else {
vErrors.push(err1132);
}
errors++;
}
}
var valid198 = _errs1114 === errors;
}
else {
var valid198 = true;
}
if(valid198){
if(data345.bytes !== undefined){
let data371 = data345.bytes;
const _errs1116 = errors;
if(errors === _errs1116){
if(typeof data371 === "string"){
if(func1(data371) > 131072){
const err1133 = {instancePath:instancePath+"/page/evidence/manifest/bytes",schemaPath:"#/oneOf/10/properties/page/properties/evidence/properties/manifest/properties/bytes/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err1133];
}
else {
vErrors.push(err1133);
}
errors++;
}
}
else {
const err1134 = {instancePath:instancePath+"/page/evidence/manifest/bytes",schemaPath:"#/oneOf/10/properties/page/properties/evidence/properties/manifest/properties/bytes/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err1134];
}
else {
vErrors.push(err1134);
}
errors++;
}
}
var valid198 = _errs1116 === errors;
}
else {
var valid198 = true;
}
if(valid198){
if(data345.sum !== undefined){
let data372 = data345.sum;
const _errs1118 = errors;
const _errs1119 = errors;
let valid204 = false;
const _errs1120 = errors;
if(errors === _errs1120){
if(typeof data372 === "string"){
if(func1(data372) > 131072){
const err1135 = {instancePath:instancePath+"/page/evidence/manifest/sum",schemaPath:"#/oneOf/10/properties/page/properties/evidence/properties/manifest/properties/sum/anyOf/0/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err1135];
}
else {
vErrors.push(err1135);
}
errors++;
}
}
else {
const err1136 = {instancePath:instancePath+"/page/evidence/manifest/sum",schemaPath:"#/oneOf/10/properties/page/properties/evidence/properties/manifest/properties/sum/anyOf/0/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err1136];
}
else {
vErrors.push(err1136);
}
errors++;
}
}
var _valid44 = _errs1120 === errors;
valid204 = valid204 || _valid44;
const _errs1122 = errors;
if(data372 !== null){
const err1137 = {instancePath:instancePath+"/page/evidence/manifest/sum",schemaPath:"#/oneOf/10/properties/page/properties/evidence/properties/manifest/properties/sum/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err1137];
}
else {
vErrors.push(err1137);
}
errors++;
}
var _valid44 = _errs1122 === errors;
valid204 = valid204 || _valid44;
if(!valid204){
const err1138 = {instancePath:instancePath+"/page/evidence/manifest/sum",schemaPath:"#/oneOf/10/properties/page/properties/evidence/properties/manifest/properties/sum/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err1138];
}
else {
vErrors.push(err1138);
}
errors++;
}
else {
errors = _errs1119;
if(vErrors !== null){
if(_errs1119){
vErrors.length = _errs1119;
}
else {
vErrors = null;
}
}
}
var valid198 = _errs1118 === errors;
}
else {
var valid198 = true;
}
if(valid198){
if(data345.finished !== undefined){
let data373 = data345.finished;
const _errs1124 = errors;
const _errs1125 = errors;
let valid205 = false;
const _errs1126 = errors;
if(typeof data373 !== "string"){
const err1139 = {instancePath:instancePath+"/page/evidence/manifest/finished",schemaPath:"#/oneOf/10/properties/page/properties/evidence/properties/manifest/properties/finished/anyOf/0/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err1139];
}
else {
vErrors.push(err1139);
}
errors++;
}
if(!((data373 === "source_end") || (data373 === "limit"))){
const err1140 = {instancePath:instancePath+"/page/evidence/manifest/finished",schemaPath:"#/oneOf/10/properties/page/properties/evidence/properties/manifest/properties/finished/anyOf/0/enum",keyword:"enum",params:{allowedValues: schema33.oneOf[10].properties.page.properties.evidence.properties.manifest.properties.finished.anyOf[0].enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err1140];
}
else {
vErrors.push(err1140);
}
errors++;
}
var _valid45 = _errs1126 === errors;
valid205 = valid205 || _valid45;
const _errs1128 = errors;
if(data373 !== null){
const err1141 = {instancePath:instancePath+"/page/evidence/manifest/finished",schemaPath:"#/oneOf/10/properties/page/properties/evidence/properties/manifest/properties/finished/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err1141];
}
else {
vErrors.push(err1141);
}
errors++;
}
var _valid45 = _errs1128 === errors;
valid205 = valid205 || _valid45;
if(!valid205){
const err1142 = {instancePath:instancePath+"/page/evidence/manifest/finished",schemaPath:"#/oneOf/10/properties/page/properties/evidence/properties/manifest/properties/finished/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err1142];
}
else {
vErrors.push(err1142);
}
errors++;
}
else {
errors = _errs1125;
if(vErrors !== null){
if(_errs1125){
vErrors.length = _errs1125;
}
else {
vErrors = null;
}
}
}
var valid198 = _errs1124 === errors;
}
else {
var valid198 = true;
}
if(valid198){
if(data345.chain !== undefined){
let data374 = data345.chain;
const _errs1130 = errors;
if(errors === _errs1130){
if(Array.isArray(data374)){
if(data374.length > 32){
const err1143 = {instancePath:instancePath+"/page/evidence/manifest/chain",schemaPath:"#/oneOf/10/properties/page/properties/evidence/properties/manifest/properties/chain/maxItems",keyword:"maxItems",params:{limit: 32},message:"must NOT have more than 32 items"};
if(vErrors === null){
vErrors = [err1143];
}
else {
vErrors.push(err1143);
}
errors++;
}
else {
if(data374.length < 32){
const err1144 = {instancePath:instancePath+"/page/evidence/manifest/chain",schemaPath:"#/oneOf/10/properties/page/properties/evidence/properties/manifest/properties/chain/minItems",keyword:"minItems",params:{limit: 32},message:"must NOT have fewer than 32 items"};
if(vErrors === null){
vErrors = [err1144];
}
else {
vErrors.push(err1144);
}
errors++;
}
else {
var valid206 = true;
const len32 = data374.length;
for(let i32=0; i32<len32; i32++){
let data375 = data374[i32];
const _errs1132 = errors;
if(!(((typeof data375 == "number") && (!(data375 % 1) && !isNaN(data375))) && (isFinite(data375)))){
const err1145 = {instancePath:instancePath+"/page/evidence/manifest/chain/" + i32,schemaPath:"#/oneOf/10/properties/page/properties/evidence/properties/manifest/properties/chain/items/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err1145];
}
else {
vErrors.push(err1145);
}
errors++;
}
if(errors === _errs1132){
if((typeof data375 == "number") && (isFinite(data375))){
if(data375 > 255 || isNaN(data375)){
const err1146 = {instancePath:instancePath+"/page/evidence/manifest/chain/" + i32,schemaPath:"#/oneOf/10/properties/page/properties/evidence/properties/manifest/properties/chain/items/maximum",keyword:"maximum",params:{comparison: "<=", limit: 255},message:"must be <= 255"};
if(vErrors === null){
vErrors = [err1146];
}
else {
vErrors.push(err1146);
}
errors++;
}
else {
if(data375 < 0 || isNaN(data375)){
const err1147 = {instancePath:instancePath+"/page/evidence/manifest/chain/" + i32,schemaPath:"#/oneOf/10/properties/page/properties/evidence/properties/manifest/properties/chain/items/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err1147];
}
else {
vErrors.push(err1147);
}
errors++;
}
}
}
}
var valid206 = _errs1132 === errors;
if(!valid206){
break;
}
}
}
}
}
else {
const err1148 = {instancePath:instancePath+"/page/evidence/manifest/chain",schemaPath:"#/oneOf/10/properties/page/properties/evidence/properties/manifest/properties/chain/type",keyword:"type",params:{type: "array"},message:"must be array"};
if(vErrors === null){
vErrors = [err1148];
}
else {
vErrors.push(err1148);
}
errors++;
}
}
var valid198 = _errs1130 === errors;
}
else {
var valid198 = true;
}
}
}
}
}
}
}
}
}
}
}
}
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
const err1149 = {instancePath:instancePath+"/page/evidence/manifest",schemaPath:"#/oneOf/10/properties/page/properties/evidence/properties/manifest/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err1149];
}
else {
vErrors.push(err1149);
}
errors++;
}
}
var valid197 = _errs1061 === errors;
}
else {
var valid197 = true;
}
if(valid197){
if(data344.columns !== undefined){
let data376 = data344.columns;
const _errs1134 = errors;
if(errors === _errs1134){
if(Array.isArray(data376)){
if(data376.length > 8){
const err1150 = {instancePath:instancePath+"/page/evidence/columns",schemaPath:"#/oneOf/10/properties/page/properties/evidence/properties/columns/maxItems",keyword:"maxItems",params:{limit: 8},message:"must NOT have more than 8 items"};
if(vErrors === null){
vErrors = [err1150];
}
else {
vErrors.push(err1150);
}
errors++;
}
else {
var valid207 = true;
const len33 = data376.length;
for(let i33=0; i33<len33; i33++){
let data377 = data376[i33];
const _errs1136 = errors;
if(errors === _errs1136){
if(data377 && typeof data377 == "object" && !Array.isArray(data377)){
let missing128;
if(((data377.name === undefined) && (missing128 = "name")) || ((data377.type === undefined) && (missing128 = "type"))){
const err1151 = {instancePath:instancePath+"/page/evidence/columns/" + i33,schemaPath:"#/oneOf/10/properties/page/properties/evidence/properties/columns/items/required",keyword:"required",params:{missingProperty: missing128},message:"must have required property '"+missing128+"'"};
if(vErrors === null){
vErrors = [err1151];
}
else {
vErrors.push(err1151);
}
errors++;
}
else {
const _errs1138 = errors;
for(const key128 in data377){
if(!((key128 === "name") || (key128 === "type"))){
const err1152 = {instancePath:instancePath+"/page/evidence/columns/" + i33,schemaPath:"#/oneOf/10/properties/page/properties/evidence/properties/columns/items/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key128},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err1152];
}
else {
vErrors.push(err1152);
}
errors++;
break;
}
}
if(_errs1138 === errors){
if(data377.name !== undefined){
let data378 = data377.name;
const _errs1139 = errors;
if(errors === _errs1139){
if(typeof data378 === "string"){
if(func1(data378) > 131072){
const err1153 = {instancePath:instancePath+"/page/evidence/columns/" + i33+"/name",schemaPath:"#/oneOf/10/properties/page/properties/evidence/properties/columns/items/properties/name/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err1153];
}
else {
vErrors.push(err1153);
}
errors++;
}
}
else {
const err1154 = {instancePath:instancePath+"/page/evidence/columns/" + i33+"/name",schemaPath:"#/oneOf/10/properties/page/properties/evidence/properties/columns/items/properties/name/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err1154];
}
else {
vErrors.push(err1154);
}
errors++;
}
}
var valid208 = _errs1139 === errors;
}
else {
var valid208 = true;
}
if(valid208){
if(data377.type !== undefined){
let data379 = data377.type;
const _errs1141 = errors;
if(typeof data379 !== "string"){
const err1155 = {instancePath:instancePath+"/page/evidence/columns/" + i33+"/type",schemaPath:"#/oneOf/10/properties/page/properties/evidence/properties/columns/items/properties/type/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err1155];
}
else {
vErrors.push(err1155);
}
errors++;
}
if(!((((((data379 === "int64") || (data379 === "uint64")) || (data379 === "float64")) || (data379 === "boolean")) || (data379 === "utf8")) || (data379 === "binary"))){
const err1156 = {instancePath:instancePath+"/page/evidence/columns/" + i33+"/type",schemaPath:"#/oneOf/10/properties/page/properties/evidence/properties/columns/items/properties/type/enum",keyword:"enum",params:{allowedValues: schema33.oneOf[10].properties.page.properties.evidence.properties.columns.items.properties.type.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err1156];
}
else {
vErrors.push(err1156);
}
errors++;
}
var valid208 = _errs1141 === errors;
}
else {
var valid208 = true;
}
}
}
}
}
else {
const err1157 = {instancePath:instancePath+"/page/evidence/columns/" + i33,schemaPath:"#/oneOf/10/properties/page/properties/evidence/properties/columns/items/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err1157];
}
else {
vErrors.push(err1157);
}
errors++;
}
}
var valid207 = _errs1136 === errors;
if(!valid207){
break;
}
}
}
}
else {
const err1158 = {instancePath:instancePath+"/page/evidence/columns",schemaPath:"#/oneOf/10/properties/page/properties/evidence/properties/columns/type",keyword:"type",params:{type: "array"},message:"must be array"};
if(vErrors === null){
vErrors = [err1158];
}
else {
vErrors.push(err1158);
}
errors++;
}
}
var valid197 = _errs1134 === errors;
}
else {
var valid197 = true;
}
if(valid197){
if(data344.ordinal !== undefined){
let data380 = data344.ordinal;
const _errs1143 = errors;
if(errors === _errs1143){
if(typeof data380 === "string"){
if(func1(data380) > 131072){
const err1159 = {instancePath:instancePath+"/page/evidence/ordinal",schemaPath:"#/oneOf/10/properties/page/properties/evidence/properties/ordinal/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err1159];
}
else {
vErrors.push(err1159);
}
errors++;
}
}
else {
const err1160 = {instancePath:instancePath+"/page/evidence/ordinal",schemaPath:"#/oneOf/10/properties/page/properties/evidence/properties/ordinal/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err1160];
}
else {
vErrors.push(err1160);
}
errors++;
}
}
var valid197 = _errs1143 === errors;
}
else {
var valid197 = true;
}
if(valid197){
if(data344.rows !== undefined){
let data381 = data344.rows;
const _errs1145 = errors;
if(!(((typeof data381 == "number") && (!(data381 % 1) && !isNaN(data381))) && (isFinite(data381)))){
const err1161 = {instancePath:instancePath+"/page/evidence/rows",schemaPath:"#/oneOf/10/properties/page/properties/evidence/properties/rows/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err1161];
}
else {
vErrors.push(err1161);
}
errors++;
}
if(errors === _errs1145){
if((typeof data381 == "number") && (isFinite(data381))){
if(data381 > 255 || isNaN(data381)){
const err1162 = {instancePath:instancePath+"/page/evidence/rows",schemaPath:"#/oneOf/10/properties/page/properties/evidence/properties/rows/maximum",keyword:"maximum",params:{comparison: "<=", limit: 255},message:"must be <= 255"};
if(vErrors === null){
vErrors = [err1162];
}
else {
vErrors.push(err1162);
}
errors++;
}
else {
if(data381 < 0 || isNaN(data381)){
const err1163 = {instancePath:instancePath+"/page/evidence/rows",schemaPath:"#/oneOf/10/properties/page/properties/evidence/properties/rows/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err1163];
}
else {
vErrors.push(err1163);
}
errors++;
}
}
}
}
var valid197 = _errs1145 === errors;
}
else {
var valid197 = true;
}
if(valid197){
if(data344.ipc !== undefined){
let data382 = data344.ipc;
const _errs1147 = errors;
if(errors === _errs1147){
if(typeof data382 === "string"){
if(func1(data382) > 131072){
const err1164 = {instancePath:instancePath+"/page/evidence/ipc",schemaPath:"#/oneOf/10/properties/page/properties/evidence/properties/ipc/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err1164];
}
else {
vErrors.push(err1164);
}
errors++;
}
}
else {
const err1165 = {instancePath:instancePath+"/page/evidence/ipc",schemaPath:"#/oneOf/10/properties/page/properties/evidence/properties/ipc/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err1165];
}
else {
vErrors.push(err1165);
}
errors++;
}
}
var valid197 = _errs1147 === errors;
}
else {
var valid197 = true;
}
if(valid197){
if(data344.next !== undefined){
let data383 = data344.next;
const _errs1149 = errors;
const _errs1150 = errors;
let valid209 = false;
const _errs1151 = errors;
if(errors === _errs1151){
if(typeof data383 === "string"){
if(func1(data383) > 131072){
const err1166 = {instancePath:instancePath+"/page/evidence/next",schemaPath:"#/oneOf/10/properties/page/properties/evidence/properties/next/anyOf/0/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err1166];
}
else {
vErrors.push(err1166);
}
errors++;
}
}
else {
const err1167 = {instancePath:instancePath+"/page/evidence/next",schemaPath:"#/oneOf/10/properties/page/properties/evidence/properties/next/anyOf/0/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err1167];
}
else {
vErrors.push(err1167);
}
errors++;
}
}
var _valid46 = _errs1151 === errors;
valid209 = valid209 || _valid46;
const _errs1153 = errors;
if(data383 !== null){
const err1168 = {instancePath:instancePath+"/page/evidence/next",schemaPath:"#/oneOf/10/properties/page/properties/evidence/properties/next/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err1168];
}
else {
vErrors.push(err1168);
}
errors++;
}
var _valid46 = _errs1153 === errors;
valid209 = valid209 || _valid46;
if(!valid209){
const err1169 = {instancePath:instancePath+"/page/evidence/next",schemaPath:"#/oneOf/10/properties/page/properties/evidence/properties/next/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err1169];
}
else {
vErrors.push(err1169);
}
errors++;
}
else {
errors = _errs1150;
if(vErrors !== null){
if(_errs1150){
vErrors.length = _errs1150;
}
else {
vErrors = null;
}
}
}
var valid197 = _errs1149 === errors;
}
else {
var valid197 = true;
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
const err1170 = {instancePath:instancePath+"/page/evidence",schemaPath:"#/oneOf/10/properties/page/properties/evidence/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err1170];
}
else {
vErrors.push(err1170);
}
errors++;
}
}
var valid196 = _errs1058 === errors;
}
else {
var valid196 = true;
}
if(valid196){
if(data343.cells !== undefined){
let data384 = data343.cells;
const _errs1155 = errors;
if(errors === _errs1155){
if(Array.isArray(data384)){
if(data384.length > 8){
const err1171 = {instancePath:instancePath+"/page/cells",schemaPath:"#/oneOf/10/properties/page/properties/cells/maxItems",keyword:"maxItems",params:{limit: 8},message:"must NOT have more than 8 items"};
if(vErrors === null){
vErrors = [err1171];
}
else {
vErrors.push(err1171);
}
errors++;
}
else {
var valid210 = true;
const len34 = data384.length;
for(let i34=0; i34<len34; i34++){
let data385 = data384[i34];
const _errs1157 = errors;
if(errors === _errs1157){
if(Array.isArray(data385)){
if(data385.length > 8){
const err1172 = {instancePath:instancePath+"/page/cells/" + i34,schemaPath:"#/oneOf/10/properties/page/properties/cells/items/maxItems",keyword:"maxItems",params:{limit: 8},message:"must NOT have more than 8 items"};
if(vErrors === null){
vErrors = [err1172];
}
else {
vErrors.push(err1172);
}
errors++;
}
else {
var valid211 = true;
const len35 = data385.length;
for(let i35=0; i35<len35; i35++){
let data386 = data385[i35];
const _errs1159 = errors;
const _errs1160 = errors;
let valid212 = false;
let passing14 = null;
const _errs1161 = errors;
if(errors === _errs1161){
if(data386 && typeof data386 == "object" && !Array.isArray(data386)){
let missing129;
if((data386.missing === undefined) && (missing129 = "missing")){
const err1173 = {instancePath:instancePath+"/page/cells/" + i34+"/" + i35,schemaPath:"#/oneOf/10/properties/page/properties/cells/items/items/oneOf/0/required",keyword:"required",params:{missingProperty: missing129},message:"must have required property '"+missing129+"'"};
if(vErrors === null){
vErrors = [err1173];
}
else {
vErrors.push(err1173);
}
errors++;
}
else {
const _errs1163 = errors;
for(const key129 in data386){
if(!(key129 === "missing")){
const err1174 = {instancePath:instancePath+"/page/cells/" + i34+"/" + i35,schemaPath:"#/oneOf/10/properties/page/properties/cells/items/items/oneOf/0/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key129},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err1174];
}
else {
vErrors.push(err1174);
}
errors++;
break;
}
}
if(_errs1163 === errors){
if(data386.missing !== undefined){
let data387 = data386.missing;
const _errs1164 = errors;
if(errors === _errs1164){
if(data387 && typeof data387 == "object" && !Array.isArray(data387)){
if(Object.keys(data387).length > 0){
const err1175 = {instancePath:instancePath+"/page/cells/" + i34+"/" + i35+"/missing",schemaPath:"#/oneOf/10/properties/page/properties/cells/items/items/oneOf/0/properties/missing/maxProperties",keyword:"maxProperties",params:{limit: 0},message:"must NOT have more than 0 properties"};
if(vErrors === null){
vErrors = [err1175];
}
else {
vErrors.push(err1175);
}
errors++;
}
}
else {
const err1176 = {instancePath:instancePath+"/page/cells/" + i34+"/" + i35+"/missing",schemaPath:"#/oneOf/10/properties/page/properties/cells/items/items/oneOf/0/properties/missing/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err1176];
}
else {
vErrors.push(err1176);
}
errors++;
}
}
}
}
}
}
else {
const err1177 = {instancePath:instancePath+"/page/cells/" + i34+"/" + i35,schemaPath:"#/oneOf/10/properties/page/properties/cells/items/items/oneOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err1177];
}
else {
vErrors.push(err1177);
}
errors++;
}
}
var _valid47 = _errs1161 === errors;
if(_valid47){
valid212 = true;
passing14 = 0;
var props24 = true;
}
const _errs1166 = errors;
if(errors === _errs1166){
if(data386 && typeof data386 == "object" && !Array.isArray(data386)){
let missing130;
if((data386.null === undefined) && (missing130 = "null")){
const err1178 = {instancePath:instancePath+"/page/cells/" + i34+"/" + i35,schemaPath:"#/oneOf/10/properties/page/properties/cells/items/items/oneOf/1/required",keyword:"required",params:{missingProperty: missing130},message:"must have required property '"+missing130+"'"};
if(vErrors === null){
vErrors = [err1178];
}
else {
vErrors.push(err1178);
}
errors++;
}
else {
const _errs1168 = errors;
for(const key130 in data386){
if(!(key130 === "null")){
const err1179 = {instancePath:instancePath+"/page/cells/" + i34+"/" + i35,schemaPath:"#/oneOf/10/properties/page/properties/cells/items/items/oneOf/1/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key130},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err1179];
}
else {
vErrors.push(err1179);
}
errors++;
break;
}
}
if(_errs1168 === errors){
if(data386.null !== undefined){
let data388 = data386.null;
const _errs1169 = errors;
if(errors === _errs1169){
if(data388 && typeof data388 == "object" && !Array.isArray(data388)){
if(Object.keys(data388).length > 0){
const err1180 = {instancePath:instancePath+"/page/cells/" + i34+"/" + i35+"/null",schemaPath:"#/oneOf/10/properties/page/properties/cells/items/items/oneOf/1/properties/null/maxProperties",keyword:"maxProperties",params:{limit: 0},message:"must NOT have more than 0 properties"};
if(vErrors === null){
vErrors = [err1180];
}
else {
vErrors.push(err1180);
}
errors++;
}
}
else {
const err1181 = {instancePath:instancePath+"/page/cells/" + i34+"/" + i35+"/null",schemaPath:"#/oneOf/10/properties/page/properties/cells/items/items/oneOf/1/properties/null/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err1181];
}
else {
vErrors.push(err1181);
}
errors++;
}
}
}
}
}
}
else {
const err1182 = {instancePath:instancePath+"/page/cells/" + i34+"/" + i35,schemaPath:"#/oneOf/10/properties/page/properties/cells/items/items/oneOf/1/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err1182];
}
else {
vErrors.push(err1182);
}
errors++;
}
}
var _valid47 = _errs1166 === errors;
if(_valid47 && valid212){
valid212 = false;
passing14 = [passing14, 1];
}
else {
if(_valid47){
valid212 = true;
passing14 = 1;
if(props24 !== true){
props24 = true;
}
}
const _errs1171 = errors;
if(errors === _errs1171){
if(data386 && typeof data386 == "object" && !Array.isArray(data386)){
let missing131;
if((data386.type_error === undefined) && (missing131 = "type_error")){
const err1183 = {instancePath:instancePath+"/page/cells/" + i34+"/" + i35,schemaPath:"#/oneOf/10/properties/page/properties/cells/items/items/oneOf/2/required",keyword:"required",params:{missingProperty: missing131},message:"must have required property '"+missing131+"'"};
if(vErrors === null){
vErrors = [err1183];
}
else {
vErrors.push(err1183);
}
errors++;
}
else {
const _errs1173 = errors;
for(const key131 in data386){
if(!(key131 === "type_error")){
const err1184 = {instancePath:instancePath+"/page/cells/" + i34+"/" + i35,schemaPath:"#/oneOf/10/properties/page/properties/cells/items/items/oneOf/2/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key131},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err1184];
}
else {
vErrors.push(err1184);
}
errors++;
break;
}
}
if(_errs1173 === errors){
if(data386.type_error !== undefined){
let data389 = data386.type_error;
if(typeof data389 !== "string"){
const err1185 = {instancePath:instancePath+"/page/cells/" + i34+"/" + i35+"/type_error",schemaPath:"#/oneOf/10/properties/page/properties/cells/items/items/oneOf/2/properties/type_error/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err1185];
}
else {
vErrors.push(err1185);
}
errors++;
}
if(!((((((((((((data389 === "unknown") || (data389 === "int64")) || (data389 === "uint64")) || (data389 === "float64")) || (data389 === "boolean")) || (data389 === "utf8")) || (data389 === "binary")) || (data389 === "null_value")) || (data389 === "map")) || (data389 === "list")) || (data389 === "text")) || (data389 === "character"))){
const err1186 = {instancePath:instancePath+"/page/cells/" + i34+"/" + i35+"/type_error",schemaPath:"#/oneOf/10/properties/page/properties/cells/items/items/oneOf/2/properties/type_error/enum",keyword:"enum",params:{allowedValues: schema33.oneOf[10].properties.page.properties.cells.items.items.oneOf[2].properties.type_error.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err1186];
}
else {
vErrors.push(err1186);
}
errors++;
}
}
}
}
}
else {
const err1187 = {instancePath:instancePath+"/page/cells/" + i34+"/" + i35,schemaPath:"#/oneOf/10/properties/page/properties/cells/items/items/oneOf/2/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err1187];
}
else {
vErrors.push(err1187);
}
errors++;
}
}
var _valid47 = _errs1171 === errors;
if(_valid47 && valid212){
valid212 = false;
passing14 = [passing14, 2];
}
else {
if(_valid47){
valid212 = true;
passing14 = 2;
if(props24 !== true){
props24 = true;
}
}
const _errs1176 = errors;
if(errors === _errs1176){
if(data386 && typeof data386 == "object" && !Array.isArray(data386)){
let missing132;
if((data386.value === undefined) && (missing132 = "value")){
const err1188 = {instancePath:instancePath+"/page/cells/" + i34+"/" + i35,schemaPath:"#/oneOf/10/properties/page/properties/cells/items/items/oneOf/3/required",keyword:"required",params:{missingProperty: missing132},message:"must have required property '"+missing132+"'"};
if(vErrors === null){
vErrors = [err1188];
}
else {
vErrors.push(err1188);
}
errors++;
}
else {
const _errs1178 = errors;
for(const key132 in data386){
if(!(key132 === "value")){
const err1189 = {instancePath:instancePath+"/page/cells/" + i34+"/" + i35,schemaPath:"#/oneOf/10/properties/page/properties/cells/items/items/oneOf/3/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key132},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err1189];
}
else {
vErrors.push(err1189);
}
errors++;
break;
}
}
if(_errs1178 === errors){
if(data386.value !== undefined){
let data390 = data386.value;
const _errs1180 = errors;
let valid217 = false;
let passing15 = null;
const _errs1181 = errors;
if(errors === _errs1181){
if(data390 && typeof data390 == "object" && !Array.isArray(data390)){
let missing133;
if((data390.int64 === undefined) && (missing133 = "int64")){
const err1190 = {instancePath:instancePath+"/page/cells/" + i34+"/" + i35+"/value",schemaPath:"#/oneOf/10/properties/page/properties/cells/items/items/oneOf/3/properties/value/oneOf/0/required",keyword:"required",params:{missingProperty: missing133},message:"must have required property '"+missing133+"'"};
if(vErrors === null){
vErrors = [err1190];
}
else {
vErrors.push(err1190);
}
errors++;
}
else {
const _errs1183 = errors;
for(const key133 in data390){
if(!(key133 === "int64")){
const err1191 = {instancePath:instancePath+"/page/cells/" + i34+"/" + i35+"/value",schemaPath:"#/oneOf/10/properties/page/properties/cells/items/items/oneOf/3/properties/value/oneOf/0/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key133},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err1191];
}
else {
vErrors.push(err1191);
}
errors++;
break;
}
}
if(_errs1183 === errors){
if(data390.int64 !== undefined){
let data391 = data390.int64;
const _errs1184 = errors;
if(errors === _errs1184){
if(typeof data391 === "string"){
if(func1(data391) > 131072){
const err1192 = {instancePath:instancePath+"/page/cells/" + i34+"/" + i35+"/value/int64",schemaPath:"#/oneOf/10/properties/page/properties/cells/items/items/oneOf/3/properties/value/oneOf/0/properties/int64/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err1192];
}
else {
vErrors.push(err1192);
}
errors++;
}
}
else {
const err1193 = {instancePath:instancePath+"/page/cells/" + i34+"/" + i35+"/value/int64",schemaPath:"#/oneOf/10/properties/page/properties/cells/items/items/oneOf/3/properties/value/oneOf/0/properties/int64/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err1193];
}
else {
vErrors.push(err1193);
}
errors++;
}
}
}
}
}
}
else {
const err1194 = {instancePath:instancePath+"/page/cells/" + i34+"/" + i35+"/value",schemaPath:"#/oneOf/10/properties/page/properties/cells/items/items/oneOf/3/properties/value/oneOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err1194];
}
else {
vErrors.push(err1194);
}
errors++;
}
}
var _valid48 = _errs1181 === errors;
if(_valid48){
valid217 = true;
passing15 = 0;
var props25 = true;
}
const _errs1186 = errors;
if(errors === _errs1186){
if(data390 && typeof data390 == "object" && !Array.isArray(data390)){
let missing134;
if((data390.uint64 === undefined) && (missing134 = "uint64")){
const err1195 = {instancePath:instancePath+"/page/cells/" + i34+"/" + i35+"/value",schemaPath:"#/oneOf/10/properties/page/properties/cells/items/items/oneOf/3/properties/value/oneOf/1/required",keyword:"required",params:{missingProperty: missing134},message:"must have required property '"+missing134+"'"};
if(vErrors === null){
vErrors = [err1195];
}
else {
vErrors.push(err1195);
}
errors++;
}
else {
const _errs1188 = errors;
for(const key134 in data390){
if(!(key134 === "uint64")){
const err1196 = {instancePath:instancePath+"/page/cells/" + i34+"/" + i35+"/value",schemaPath:"#/oneOf/10/properties/page/properties/cells/items/items/oneOf/3/properties/value/oneOf/1/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key134},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err1196];
}
else {
vErrors.push(err1196);
}
errors++;
break;
}
}
if(_errs1188 === errors){
if(data390.uint64 !== undefined){
let data392 = data390.uint64;
const _errs1189 = errors;
if(errors === _errs1189){
if(typeof data392 === "string"){
if(func1(data392) > 131072){
const err1197 = {instancePath:instancePath+"/page/cells/" + i34+"/" + i35+"/value/uint64",schemaPath:"#/oneOf/10/properties/page/properties/cells/items/items/oneOf/3/properties/value/oneOf/1/properties/uint64/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err1197];
}
else {
vErrors.push(err1197);
}
errors++;
}
}
else {
const err1198 = {instancePath:instancePath+"/page/cells/" + i34+"/" + i35+"/value/uint64",schemaPath:"#/oneOf/10/properties/page/properties/cells/items/items/oneOf/3/properties/value/oneOf/1/properties/uint64/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err1198];
}
else {
vErrors.push(err1198);
}
errors++;
}
}
}
}
}
}
else {
const err1199 = {instancePath:instancePath+"/page/cells/" + i34+"/" + i35+"/value",schemaPath:"#/oneOf/10/properties/page/properties/cells/items/items/oneOf/3/properties/value/oneOf/1/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err1199];
}
else {
vErrors.push(err1199);
}
errors++;
}
}
var _valid48 = _errs1186 === errors;
if(_valid48 && valid217){
valid217 = false;
passing15 = [passing15, 1];
}
else {
if(_valid48){
valid217 = true;
passing15 = 1;
if(props25 !== true){
props25 = true;
}
}
const _errs1191 = errors;
if(errors === _errs1191){
if(data390 && typeof data390 == "object" && !Array.isArray(data390)){
let missing135;
if((data390.float_bits === undefined) && (missing135 = "float_bits")){
const err1200 = {instancePath:instancePath+"/page/cells/" + i34+"/" + i35+"/value",schemaPath:"#/oneOf/10/properties/page/properties/cells/items/items/oneOf/3/properties/value/oneOf/2/required",keyword:"required",params:{missingProperty: missing135},message:"must have required property '"+missing135+"'"};
if(vErrors === null){
vErrors = [err1200];
}
else {
vErrors.push(err1200);
}
errors++;
}
else {
const _errs1193 = errors;
for(const key135 in data390){
if(!(key135 === "float_bits")){
const err1201 = {instancePath:instancePath+"/page/cells/" + i34+"/" + i35+"/value",schemaPath:"#/oneOf/10/properties/page/properties/cells/items/items/oneOf/3/properties/value/oneOf/2/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key135},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err1201];
}
else {
vErrors.push(err1201);
}
errors++;
break;
}
}
if(_errs1193 === errors){
if(data390.float_bits !== undefined){
let data393 = data390.float_bits;
const _errs1194 = errors;
if(errors === _errs1194){
if(typeof data393 === "string"){
if(func1(data393) > 131072){
const err1202 = {instancePath:instancePath+"/page/cells/" + i34+"/" + i35+"/value/float_bits",schemaPath:"#/oneOf/10/properties/page/properties/cells/items/items/oneOf/3/properties/value/oneOf/2/properties/float_bits/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err1202];
}
else {
vErrors.push(err1202);
}
errors++;
}
}
else {
const err1203 = {instancePath:instancePath+"/page/cells/" + i34+"/" + i35+"/value/float_bits",schemaPath:"#/oneOf/10/properties/page/properties/cells/items/items/oneOf/3/properties/value/oneOf/2/properties/float_bits/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err1203];
}
else {
vErrors.push(err1203);
}
errors++;
}
}
}
}
}
}
else {
const err1204 = {instancePath:instancePath+"/page/cells/" + i34+"/" + i35+"/value",schemaPath:"#/oneOf/10/properties/page/properties/cells/items/items/oneOf/3/properties/value/oneOf/2/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err1204];
}
else {
vErrors.push(err1204);
}
errors++;
}
}
var _valid48 = _errs1191 === errors;
if(_valid48 && valid217){
valid217 = false;
passing15 = [passing15, 2];
}
else {
if(_valid48){
valid217 = true;
passing15 = 2;
if(props25 !== true){
props25 = true;
}
}
const _errs1196 = errors;
if(errors === _errs1196){
if(data390 && typeof data390 == "object" && !Array.isArray(data390)){
let missing136;
if((data390.boolean === undefined) && (missing136 = "boolean")){
const err1205 = {instancePath:instancePath+"/page/cells/" + i34+"/" + i35+"/value",schemaPath:"#/oneOf/10/properties/page/properties/cells/items/items/oneOf/3/properties/value/oneOf/3/required",keyword:"required",params:{missingProperty: missing136},message:"must have required property '"+missing136+"'"};
if(vErrors === null){
vErrors = [err1205];
}
else {
vErrors.push(err1205);
}
errors++;
}
else {
const _errs1198 = errors;
for(const key136 in data390){
if(!(key136 === "boolean")){
const err1206 = {instancePath:instancePath+"/page/cells/" + i34+"/" + i35+"/value",schemaPath:"#/oneOf/10/properties/page/properties/cells/items/items/oneOf/3/properties/value/oneOf/3/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key136},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err1206];
}
else {
vErrors.push(err1206);
}
errors++;
break;
}
}
if(_errs1198 === errors){
if(data390.boolean !== undefined){
if(typeof data390.boolean !== "boolean"){
const err1207 = {instancePath:instancePath+"/page/cells/" + i34+"/" + i35+"/value/boolean",schemaPath:"#/oneOf/10/properties/page/properties/cells/items/items/oneOf/3/properties/value/oneOf/3/properties/boolean/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"};
if(vErrors === null){
vErrors = [err1207];
}
else {
vErrors.push(err1207);
}
errors++;
}
}
}
}
}
else {
const err1208 = {instancePath:instancePath+"/page/cells/" + i34+"/" + i35+"/value",schemaPath:"#/oneOf/10/properties/page/properties/cells/items/items/oneOf/3/properties/value/oneOf/3/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err1208];
}
else {
vErrors.push(err1208);
}
errors++;
}
}
var _valid48 = _errs1196 === errors;
if(_valid48 && valid217){
valid217 = false;
passing15 = [passing15, 3];
}
else {
if(_valid48){
valid217 = true;
passing15 = 3;
if(props25 !== true){
props25 = true;
}
}
const _errs1201 = errors;
if(errors === _errs1201){
if(data390 && typeof data390 == "object" && !Array.isArray(data390)){
let missing137;
if((data390.utf8 === undefined) && (missing137 = "utf8")){
const err1209 = {instancePath:instancePath+"/page/cells/" + i34+"/" + i35+"/value",schemaPath:"#/oneOf/10/properties/page/properties/cells/items/items/oneOf/3/properties/value/oneOf/4/required",keyword:"required",params:{missingProperty: missing137},message:"must have required property '"+missing137+"'"};
if(vErrors === null){
vErrors = [err1209];
}
else {
vErrors.push(err1209);
}
errors++;
}
else {
const _errs1203 = errors;
for(const key137 in data390){
if(!(key137 === "utf8")){
const err1210 = {instancePath:instancePath+"/page/cells/" + i34+"/" + i35+"/value",schemaPath:"#/oneOf/10/properties/page/properties/cells/items/items/oneOf/3/properties/value/oneOf/4/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key137},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err1210];
}
else {
vErrors.push(err1210);
}
errors++;
break;
}
}
if(_errs1203 === errors){
if(data390.utf8 !== undefined){
let data395 = data390.utf8;
const _errs1204 = errors;
if(errors === _errs1204){
if(typeof data395 === "string"){
if(func1(data395) > 131072){
const err1211 = {instancePath:instancePath+"/page/cells/" + i34+"/" + i35+"/value/utf8",schemaPath:"#/oneOf/10/properties/page/properties/cells/items/items/oneOf/3/properties/value/oneOf/4/properties/utf8/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err1211];
}
else {
vErrors.push(err1211);
}
errors++;
}
}
else {
const err1212 = {instancePath:instancePath+"/page/cells/" + i34+"/" + i35+"/value/utf8",schemaPath:"#/oneOf/10/properties/page/properties/cells/items/items/oneOf/3/properties/value/oneOf/4/properties/utf8/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err1212];
}
else {
vErrors.push(err1212);
}
errors++;
}
}
}
}
}
}
else {
const err1213 = {instancePath:instancePath+"/page/cells/" + i34+"/" + i35+"/value",schemaPath:"#/oneOf/10/properties/page/properties/cells/items/items/oneOf/3/properties/value/oneOf/4/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err1213];
}
else {
vErrors.push(err1213);
}
errors++;
}
}
var _valid48 = _errs1201 === errors;
if(_valid48 && valid217){
valid217 = false;
passing15 = [passing15, 4];
}
else {
if(_valid48){
valid217 = true;
passing15 = 4;
if(props25 !== true){
props25 = true;
}
}
const _errs1206 = errors;
if(errors === _errs1206){
if(data390 && typeof data390 == "object" && !Array.isArray(data390)){
let missing138;
if((data390.binary === undefined) && (missing138 = "binary")){
const err1214 = {instancePath:instancePath+"/page/cells/" + i34+"/" + i35+"/value",schemaPath:"#/oneOf/10/properties/page/properties/cells/items/items/oneOf/3/properties/value/oneOf/5/required",keyword:"required",params:{missingProperty: missing138},message:"must have required property '"+missing138+"'"};
if(vErrors === null){
vErrors = [err1214];
}
else {
vErrors.push(err1214);
}
errors++;
}
else {
const _errs1208 = errors;
for(const key138 in data390){
if(!(key138 === "binary")){
const err1215 = {instancePath:instancePath+"/page/cells/" + i34+"/" + i35+"/value",schemaPath:"#/oneOf/10/properties/page/properties/cells/items/items/oneOf/3/properties/value/oneOf/5/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key138},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err1215];
}
else {
vErrors.push(err1215);
}
errors++;
break;
}
}
if(_errs1208 === errors){
if(data390.binary !== undefined){
let data396 = data390.binary;
const _errs1209 = errors;
if(errors === _errs1209){
if(typeof data396 === "string"){
if(func1(data396) > 131072){
const err1216 = {instancePath:instancePath+"/page/cells/" + i34+"/" + i35+"/value/binary",schemaPath:"#/oneOf/10/properties/page/properties/cells/items/items/oneOf/3/properties/value/oneOf/5/properties/binary/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err1216];
}
else {
vErrors.push(err1216);
}
errors++;
}
}
else {
const err1217 = {instancePath:instancePath+"/page/cells/" + i34+"/" + i35+"/value/binary",schemaPath:"#/oneOf/10/properties/page/properties/cells/items/items/oneOf/3/properties/value/oneOf/5/properties/binary/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err1217];
}
else {
vErrors.push(err1217);
}
errors++;
}
}
}
}
}
}
else {
const err1218 = {instancePath:instancePath+"/page/cells/" + i34+"/" + i35+"/value",schemaPath:"#/oneOf/10/properties/page/properties/cells/items/items/oneOf/3/properties/value/oneOf/5/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err1218];
}
else {
vErrors.push(err1218);
}
errors++;
}
}
var _valid48 = _errs1206 === errors;
if(_valid48 && valid217){
valid217 = false;
passing15 = [passing15, 5];
}
else {
if(_valid48){
valid217 = true;
passing15 = 5;
if(props25 !== true){
props25 = true;
}
}
}
}
}
}
}
if(!valid217){
const err1219 = {instancePath:instancePath+"/page/cells/" + i34+"/" + i35+"/value",schemaPath:"#/oneOf/10/properties/page/properties/cells/items/items/oneOf/3/properties/value/oneOf",keyword:"oneOf",params:{passingSchemas: passing15},message:"must match exactly one schema in oneOf"};
if(vErrors === null){
vErrors = [err1219];
}
else {
vErrors.push(err1219);
}
errors++;
}
else {
errors = _errs1180;
if(vErrors !== null){
if(_errs1180){
vErrors.length = _errs1180;
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
const err1220 = {instancePath:instancePath+"/page/cells/" + i34+"/" + i35,schemaPath:"#/oneOf/10/properties/page/properties/cells/items/items/oneOf/3/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err1220];
}
else {
vErrors.push(err1220);
}
errors++;
}
}
var _valid47 = _errs1176 === errors;
if(_valid47 && valid212){
valid212 = false;
passing14 = [passing14, 3];
}
else {
if(_valid47){
valid212 = true;
passing14 = 3;
if(props24 !== true){
props24 = true;
}
}
const _errs1211 = errors;
if(errors === _errs1211){
if(data386 && typeof data386 == "object" && !Array.isArray(data386)){
let missing139;
if((data386.conflict === undefined) && (missing139 = "conflict")){
const err1221 = {instancePath:instancePath+"/page/cells/" + i34+"/" + i35,schemaPath:"#/oneOf/10/properties/page/properties/cells/items/items/oneOf/4/required",keyword:"required",params:{missingProperty: missing139},message:"must have required property '"+missing139+"'"};
if(vErrors === null){
vErrors = [err1221];
}
else {
vErrors.push(err1221);
}
errors++;
}
else {
const _errs1213 = errors;
for(const key139 in data386){
if(!(key139 === "conflict")){
const err1222 = {instancePath:instancePath+"/page/cells/" + i34+"/" + i35,schemaPath:"#/oneOf/10/properties/page/properties/cells/items/items/oneOf/4/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key139},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err1222];
}
else {
vErrors.push(err1222);
}
errors++;
break;
}
}
if(_errs1213 === errors){
if(data386.conflict !== undefined){
let data397 = data386.conflict;
const _errs1214 = errors;
if(errors === _errs1214){
if(Array.isArray(data397)){
if(data397.length > 8){
const err1223 = {instancePath:instancePath+"/page/cells/" + i34+"/" + i35+"/conflict",schemaPath:"#/oneOf/10/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/maxItems",keyword:"maxItems",params:{limit: 8},message:"must NOT have more than 8 items"};
if(vErrors === null){
vErrors = [err1223];
}
else {
vErrors.push(err1223);
}
errors++;
}
else {
var valid225 = true;
const len36 = data397.length;
for(let i36=0; i36<len36; i36++){
let data398 = data397[i36];
const _errs1216 = errors;
if(errors === _errs1216){
if(data398 && typeof data398 == "object" && !Array.isArray(data398)){
let missing140;
if((((data398.counter === undefined) && (missing140 = "counter")) || ((data398.replica === undefined) && (missing140 = "replica"))) || ((data398.value === undefined) && (missing140 = "value"))){
const err1224 = {instancePath:instancePath+"/page/cells/" + i34+"/" + i35+"/conflict/" + i36,schemaPath:"#/oneOf/10/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/required",keyword:"required",params:{missingProperty: missing140},message:"must have required property '"+missing140+"'"};
if(vErrors === null){
vErrors = [err1224];
}
else {
vErrors.push(err1224);
}
errors++;
}
else {
const _errs1218 = errors;
for(const key140 in data398){
if(!(((key140 === "counter") || (key140 === "replica")) || (key140 === "value"))){
const err1225 = {instancePath:instancePath+"/page/cells/" + i34+"/" + i35+"/conflict/" + i36,schemaPath:"#/oneOf/10/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key140},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err1225];
}
else {
vErrors.push(err1225);
}
errors++;
break;
}
}
if(_errs1218 === errors){
if(data398.counter !== undefined){
let data399 = data398.counter;
const _errs1219 = errors;
if(errors === _errs1219){
if(typeof data399 === "string"){
if(func1(data399) > 131072){
const err1226 = {instancePath:instancePath+"/page/cells/" + i34+"/" + i35+"/conflict/" + i36+"/counter",schemaPath:"#/oneOf/10/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/properties/counter/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err1226];
}
else {
vErrors.push(err1226);
}
errors++;
}
}
else {
const err1227 = {instancePath:instancePath+"/page/cells/" + i34+"/" + i35+"/conflict/" + i36+"/counter",schemaPath:"#/oneOf/10/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/properties/counter/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err1227];
}
else {
vErrors.push(err1227);
}
errors++;
}
}
var valid226 = _errs1219 === errors;
}
else {
var valid226 = true;
}
if(valid226){
if(data398.replica !== undefined){
let data400 = data398.replica;
const _errs1221 = errors;
if(errors === _errs1221){
if(typeof data400 === "string"){
if(func1(data400) > 131072){
const err1228 = {instancePath:instancePath+"/page/cells/" + i34+"/" + i35+"/conflict/" + i36+"/replica",schemaPath:"#/oneOf/10/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/properties/replica/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err1228];
}
else {
vErrors.push(err1228);
}
errors++;
}
}
else {
const err1229 = {instancePath:instancePath+"/page/cells/" + i34+"/" + i35+"/conflict/" + i36+"/replica",schemaPath:"#/oneOf/10/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/properties/replica/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err1229];
}
else {
vErrors.push(err1229);
}
errors++;
}
}
var valid226 = _errs1221 === errors;
}
else {
var valid226 = true;
}
if(valid226){
if(data398.value !== undefined){
let data401 = data398.value;
const _errs1223 = errors;
const _errs1224 = errors;
let valid227 = false;
let passing16 = null;
const _errs1225 = errors;
if(errors === _errs1225){
if(data401 && typeof data401 == "object" && !Array.isArray(data401)){
let missing141;
if((data401.null === undefined) && (missing141 = "null")){
const err1230 = {instancePath:instancePath+"/page/cells/" + i34+"/" + i35+"/conflict/" + i36+"/value",schemaPath:"#/oneOf/10/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/properties/value/oneOf/0/required",keyword:"required",params:{missingProperty: missing141},message:"must have required property '"+missing141+"'"};
if(vErrors === null){
vErrors = [err1230];
}
else {
vErrors.push(err1230);
}
errors++;
}
else {
const _errs1227 = errors;
for(const key141 in data401){
if(!(key141 === "null")){
const err1231 = {instancePath:instancePath+"/page/cells/" + i34+"/" + i35+"/conflict/" + i36+"/value",schemaPath:"#/oneOf/10/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/properties/value/oneOf/0/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key141},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err1231];
}
else {
vErrors.push(err1231);
}
errors++;
break;
}
}
if(_errs1227 === errors){
if(data401.null !== undefined){
let data402 = data401.null;
const _errs1228 = errors;
if(errors === _errs1228){
if(data402 && typeof data402 == "object" && !Array.isArray(data402)){
if(Object.keys(data402).length > 0){
const err1232 = {instancePath:instancePath+"/page/cells/" + i34+"/" + i35+"/conflict/" + i36+"/value/null",schemaPath:"#/oneOf/10/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/properties/value/oneOf/0/properties/null/maxProperties",keyword:"maxProperties",params:{limit: 0},message:"must NOT have more than 0 properties"};
if(vErrors === null){
vErrors = [err1232];
}
else {
vErrors.push(err1232);
}
errors++;
}
}
else {
const err1233 = {instancePath:instancePath+"/page/cells/" + i34+"/" + i35+"/conflict/" + i36+"/value/null",schemaPath:"#/oneOf/10/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/properties/value/oneOf/0/properties/null/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err1233];
}
else {
vErrors.push(err1233);
}
errors++;
}
}
}
}
}
}
else {
const err1234 = {instancePath:instancePath+"/page/cells/" + i34+"/" + i35+"/conflict/" + i36+"/value",schemaPath:"#/oneOf/10/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/properties/value/oneOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err1234];
}
else {
vErrors.push(err1234);
}
errors++;
}
}
var _valid49 = _errs1225 === errors;
if(_valid49){
valid227 = true;
passing16 = 0;
var props26 = true;
}
const _errs1230 = errors;
if(errors === _errs1230){
if(data401 && typeof data401 == "object" && !Array.isArray(data401)){
let missing142;
if((data401.type_error === undefined) && (missing142 = "type_error")){
const err1235 = {instancePath:instancePath+"/page/cells/" + i34+"/" + i35+"/conflict/" + i36+"/value",schemaPath:"#/oneOf/10/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/properties/value/oneOf/1/required",keyword:"required",params:{missingProperty: missing142},message:"must have required property '"+missing142+"'"};
if(vErrors === null){
vErrors = [err1235];
}
else {
vErrors.push(err1235);
}
errors++;
}
else {
const _errs1232 = errors;
for(const key142 in data401){
if(!(key142 === "type_error")){
const err1236 = {instancePath:instancePath+"/page/cells/" + i34+"/" + i35+"/conflict/" + i36+"/value",schemaPath:"#/oneOf/10/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/properties/value/oneOf/1/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key142},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err1236];
}
else {
vErrors.push(err1236);
}
errors++;
break;
}
}
if(_errs1232 === errors){
if(data401.type_error !== undefined){
let data403 = data401.type_error;
if(typeof data403 !== "string"){
const err1237 = {instancePath:instancePath+"/page/cells/" + i34+"/" + i35+"/conflict/" + i36+"/value/type_error",schemaPath:"#/oneOf/10/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/properties/value/oneOf/1/properties/type_error/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err1237];
}
else {
vErrors.push(err1237);
}
errors++;
}
if(!((((((((((((data403 === "unknown") || (data403 === "int64")) || (data403 === "uint64")) || (data403 === "float64")) || (data403 === "boolean")) || (data403 === "utf8")) || (data403 === "binary")) || (data403 === "null_value")) || (data403 === "map")) || (data403 === "list")) || (data403 === "text")) || (data403 === "character"))){
const err1238 = {instancePath:instancePath+"/page/cells/" + i34+"/" + i35+"/conflict/" + i36+"/value/type_error",schemaPath:"#/oneOf/10/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/properties/value/oneOf/1/properties/type_error/enum",keyword:"enum",params:{allowedValues: schema33.oneOf[10].properties.page.properties.cells.items.items.oneOf[4].properties.conflict.items.properties.value.oneOf[1].properties.type_error.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err1238];
}
else {
vErrors.push(err1238);
}
errors++;
}
}
}
}
}
else {
const err1239 = {instancePath:instancePath+"/page/cells/" + i34+"/" + i35+"/conflict/" + i36+"/value",schemaPath:"#/oneOf/10/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/properties/value/oneOf/1/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err1239];
}
else {
vErrors.push(err1239);
}
errors++;
}
}
var _valid49 = _errs1230 === errors;
if(_valid49 && valid227){
valid227 = false;
passing16 = [passing16, 1];
}
else {
if(_valid49){
valid227 = true;
passing16 = 1;
if(props26 !== true){
props26 = true;
}
}
const _errs1235 = errors;
if(errors === _errs1235){
if(data401 && typeof data401 == "object" && !Array.isArray(data401)){
let missing143;
if((data401.value === undefined) && (missing143 = "value")){
const err1240 = {instancePath:instancePath+"/page/cells/" + i34+"/" + i35+"/conflict/" + i36+"/value",schemaPath:"#/oneOf/10/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/properties/value/oneOf/2/required",keyword:"required",params:{missingProperty: missing143},message:"must have required property '"+missing143+"'"};
if(vErrors === null){
vErrors = [err1240];
}
else {
vErrors.push(err1240);
}
errors++;
}
else {
const _errs1237 = errors;
for(const key143 in data401){
if(!(key143 === "value")){
const err1241 = {instancePath:instancePath+"/page/cells/" + i34+"/" + i35+"/conflict/" + i36+"/value",schemaPath:"#/oneOf/10/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/properties/value/oneOf/2/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key143},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err1241];
}
else {
vErrors.push(err1241);
}
errors++;
break;
}
}
if(_errs1237 === errors){
if(data401.value !== undefined){
let data404 = data401.value;
const _errs1239 = errors;
let valid231 = false;
let passing17 = null;
const _errs1240 = errors;
if(errors === _errs1240){
if(data404 && typeof data404 == "object" && !Array.isArray(data404)){
let missing144;
if((data404.int64 === undefined) && (missing144 = "int64")){
const err1242 = {instancePath:instancePath+"/page/cells/" + i34+"/" + i35+"/conflict/" + i36+"/value/value",schemaPath:"#/oneOf/10/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/properties/value/oneOf/2/properties/value/oneOf/0/required",keyword:"required",params:{missingProperty: missing144},message:"must have required property '"+missing144+"'"};
if(vErrors === null){
vErrors = [err1242];
}
else {
vErrors.push(err1242);
}
errors++;
}
else {
const _errs1242 = errors;
for(const key144 in data404){
if(!(key144 === "int64")){
const err1243 = {instancePath:instancePath+"/page/cells/" + i34+"/" + i35+"/conflict/" + i36+"/value/value",schemaPath:"#/oneOf/10/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/properties/value/oneOf/2/properties/value/oneOf/0/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key144},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err1243];
}
else {
vErrors.push(err1243);
}
errors++;
break;
}
}
if(_errs1242 === errors){
if(data404.int64 !== undefined){
let data405 = data404.int64;
const _errs1243 = errors;
if(errors === _errs1243){
if(typeof data405 === "string"){
if(func1(data405) > 131072){
const err1244 = {instancePath:instancePath+"/page/cells/" + i34+"/" + i35+"/conflict/" + i36+"/value/value/int64",schemaPath:"#/oneOf/10/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/properties/value/oneOf/2/properties/value/oneOf/0/properties/int64/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err1244];
}
else {
vErrors.push(err1244);
}
errors++;
}
}
else {
const err1245 = {instancePath:instancePath+"/page/cells/" + i34+"/" + i35+"/conflict/" + i36+"/value/value/int64",schemaPath:"#/oneOf/10/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/properties/value/oneOf/2/properties/value/oneOf/0/properties/int64/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err1245];
}
else {
vErrors.push(err1245);
}
errors++;
}
}
}
}
}
}
else {
const err1246 = {instancePath:instancePath+"/page/cells/" + i34+"/" + i35+"/conflict/" + i36+"/value/value",schemaPath:"#/oneOf/10/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/properties/value/oneOf/2/properties/value/oneOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err1246];
}
else {
vErrors.push(err1246);
}
errors++;
}
}
var _valid50 = _errs1240 === errors;
if(_valid50){
valid231 = true;
passing17 = 0;
var props27 = true;
}
const _errs1245 = errors;
if(errors === _errs1245){
if(data404 && typeof data404 == "object" && !Array.isArray(data404)){
let missing145;
if((data404.uint64 === undefined) && (missing145 = "uint64")){
const err1247 = {instancePath:instancePath+"/page/cells/" + i34+"/" + i35+"/conflict/" + i36+"/value/value",schemaPath:"#/oneOf/10/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/properties/value/oneOf/2/properties/value/oneOf/1/required",keyword:"required",params:{missingProperty: missing145},message:"must have required property '"+missing145+"'"};
if(vErrors === null){
vErrors = [err1247];
}
else {
vErrors.push(err1247);
}
errors++;
}
else {
const _errs1247 = errors;
for(const key145 in data404){
if(!(key145 === "uint64")){
const err1248 = {instancePath:instancePath+"/page/cells/" + i34+"/" + i35+"/conflict/" + i36+"/value/value",schemaPath:"#/oneOf/10/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/properties/value/oneOf/2/properties/value/oneOf/1/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key145},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err1248];
}
else {
vErrors.push(err1248);
}
errors++;
break;
}
}
if(_errs1247 === errors){
if(data404.uint64 !== undefined){
let data406 = data404.uint64;
const _errs1248 = errors;
if(errors === _errs1248){
if(typeof data406 === "string"){
if(func1(data406) > 131072){
const err1249 = {instancePath:instancePath+"/page/cells/" + i34+"/" + i35+"/conflict/" + i36+"/value/value/uint64",schemaPath:"#/oneOf/10/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/properties/value/oneOf/2/properties/value/oneOf/1/properties/uint64/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err1249];
}
else {
vErrors.push(err1249);
}
errors++;
}
}
else {
const err1250 = {instancePath:instancePath+"/page/cells/" + i34+"/" + i35+"/conflict/" + i36+"/value/value/uint64",schemaPath:"#/oneOf/10/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/properties/value/oneOf/2/properties/value/oneOf/1/properties/uint64/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err1250];
}
else {
vErrors.push(err1250);
}
errors++;
}
}
}
}
}
}
else {
const err1251 = {instancePath:instancePath+"/page/cells/" + i34+"/" + i35+"/conflict/" + i36+"/value/value",schemaPath:"#/oneOf/10/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/properties/value/oneOf/2/properties/value/oneOf/1/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err1251];
}
else {
vErrors.push(err1251);
}
errors++;
}
}
var _valid50 = _errs1245 === errors;
if(_valid50 && valid231){
valid231 = false;
passing17 = [passing17, 1];
}
else {
if(_valid50){
valid231 = true;
passing17 = 1;
if(props27 !== true){
props27 = true;
}
}
const _errs1250 = errors;
if(errors === _errs1250){
if(data404 && typeof data404 == "object" && !Array.isArray(data404)){
let missing146;
if((data404.float_bits === undefined) && (missing146 = "float_bits")){
const err1252 = {instancePath:instancePath+"/page/cells/" + i34+"/" + i35+"/conflict/" + i36+"/value/value",schemaPath:"#/oneOf/10/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/properties/value/oneOf/2/properties/value/oneOf/2/required",keyword:"required",params:{missingProperty: missing146},message:"must have required property '"+missing146+"'"};
if(vErrors === null){
vErrors = [err1252];
}
else {
vErrors.push(err1252);
}
errors++;
}
else {
const _errs1252 = errors;
for(const key146 in data404){
if(!(key146 === "float_bits")){
const err1253 = {instancePath:instancePath+"/page/cells/" + i34+"/" + i35+"/conflict/" + i36+"/value/value",schemaPath:"#/oneOf/10/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/properties/value/oneOf/2/properties/value/oneOf/2/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key146},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err1253];
}
else {
vErrors.push(err1253);
}
errors++;
break;
}
}
if(_errs1252 === errors){
if(data404.float_bits !== undefined){
let data407 = data404.float_bits;
const _errs1253 = errors;
if(errors === _errs1253){
if(typeof data407 === "string"){
if(func1(data407) > 131072){
const err1254 = {instancePath:instancePath+"/page/cells/" + i34+"/" + i35+"/conflict/" + i36+"/value/value/float_bits",schemaPath:"#/oneOf/10/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/properties/value/oneOf/2/properties/value/oneOf/2/properties/float_bits/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err1254];
}
else {
vErrors.push(err1254);
}
errors++;
}
}
else {
const err1255 = {instancePath:instancePath+"/page/cells/" + i34+"/" + i35+"/conflict/" + i36+"/value/value/float_bits",schemaPath:"#/oneOf/10/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/properties/value/oneOf/2/properties/value/oneOf/2/properties/float_bits/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err1255];
}
else {
vErrors.push(err1255);
}
errors++;
}
}
}
}
}
}
else {
const err1256 = {instancePath:instancePath+"/page/cells/" + i34+"/" + i35+"/conflict/" + i36+"/value/value",schemaPath:"#/oneOf/10/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/properties/value/oneOf/2/properties/value/oneOf/2/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err1256];
}
else {
vErrors.push(err1256);
}
errors++;
}
}
var _valid50 = _errs1250 === errors;
if(_valid50 && valid231){
valid231 = false;
passing17 = [passing17, 2];
}
else {
if(_valid50){
valid231 = true;
passing17 = 2;
if(props27 !== true){
props27 = true;
}
}
const _errs1255 = errors;
if(errors === _errs1255){
if(data404 && typeof data404 == "object" && !Array.isArray(data404)){
let missing147;
if((data404.boolean === undefined) && (missing147 = "boolean")){
const err1257 = {instancePath:instancePath+"/page/cells/" + i34+"/" + i35+"/conflict/" + i36+"/value/value",schemaPath:"#/oneOf/10/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/properties/value/oneOf/2/properties/value/oneOf/3/required",keyword:"required",params:{missingProperty: missing147},message:"must have required property '"+missing147+"'"};
if(vErrors === null){
vErrors = [err1257];
}
else {
vErrors.push(err1257);
}
errors++;
}
else {
const _errs1257 = errors;
for(const key147 in data404){
if(!(key147 === "boolean")){
const err1258 = {instancePath:instancePath+"/page/cells/" + i34+"/" + i35+"/conflict/" + i36+"/value/value",schemaPath:"#/oneOf/10/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/properties/value/oneOf/2/properties/value/oneOf/3/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key147},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err1258];
}
else {
vErrors.push(err1258);
}
errors++;
break;
}
}
if(_errs1257 === errors){
if(data404.boolean !== undefined){
if(typeof data404.boolean !== "boolean"){
const err1259 = {instancePath:instancePath+"/page/cells/" + i34+"/" + i35+"/conflict/" + i36+"/value/value/boolean",schemaPath:"#/oneOf/10/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/properties/value/oneOf/2/properties/value/oneOf/3/properties/boolean/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"};
if(vErrors === null){
vErrors = [err1259];
}
else {
vErrors.push(err1259);
}
errors++;
}
}
}
}
}
else {
const err1260 = {instancePath:instancePath+"/page/cells/" + i34+"/" + i35+"/conflict/" + i36+"/value/value",schemaPath:"#/oneOf/10/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/properties/value/oneOf/2/properties/value/oneOf/3/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err1260];
}
else {
vErrors.push(err1260);
}
errors++;
}
}
var _valid50 = _errs1255 === errors;
if(_valid50 && valid231){
valid231 = false;
passing17 = [passing17, 3];
}
else {
if(_valid50){
valid231 = true;
passing17 = 3;
if(props27 !== true){
props27 = true;
}
}
const _errs1260 = errors;
if(errors === _errs1260){
if(data404 && typeof data404 == "object" && !Array.isArray(data404)){
let missing148;
if((data404.utf8 === undefined) && (missing148 = "utf8")){
const err1261 = {instancePath:instancePath+"/page/cells/" + i34+"/" + i35+"/conflict/" + i36+"/value/value",schemaPath:"#/oneOf/10/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/properties/value/oneOf/2/properties/value/oneOf/4/required",keyword:"required",params:{missingProperty: missing148},message:"must have required property '"+missing148+"'"};
if(vErrors === null){
vErrors = [err1261];
}
else {
vErrors.push(err1261);
}
errors++;
}
else {
const _errs1262 = errors;
for(const key148 in data404){
if(!(key148 === "utf8")){
const err1262 = {instancePath:instancePath+"/page/cells/" + i34+"/" + i35+"/conflict/" + i36+"/value/value",schemaPath:"#/oneOf/10/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/properties/value/oneOf/2/properties/value/oneOf/4/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key148},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err1262];
}
else {
vErrors.push(err1262);
}
errors++;
break;
}
}
if(_errs1262 === errors){
if(data404.utf8 !== undefined){
let data409 = data404.utf8;
const _errs1263 = errors;
if(errors === _errs1263){
if(typeof data409 === "string"){
if(func1(data409) > 131072){
const err1263 = {instancePath:instancePath+"/page/cells/" + i34+"/" + i35+"/conflict/" + i36+"/value/value/utf8",schemaPath:"#/oneOf/10/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/properties/value/oneOf/2/properties/value/oneOf/4/properties/utf8/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err1263];
}
else {
vErrors.push(err1263);
}
errors++;
}
}
else {
const err1264 = {instancePath:instancePath+"/page/cells/" + i34+"/" + i35+"/conflict/" + i36+"/value/value/utf8",schemaPath:"#/oneOf/10/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/properties/value/oneOf/2/properties/value/oneOf/4/properties/utf8/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err1264];
}
else {
vErrors.push(err1264);
}
errors++;
}
}
}
}
}
}
else {
const err1265 = {instancePath:instancePath+"/page/cells/" + i34+"/" + i35+"/conflict/" + i36+"/value/value",schemaPath:"#/oneOf/10/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/properties/value/oneOf/2/properties/value/oneOf/4/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err1265];
}
else {
vErrors.push(err1265);
}
errors++;
}
}
var _valid50 = _errs1260 === errors;
if(_valid50 && valid231){
valid231 = false;
passing17 = [passing17, 4];
}
else {
if(_valid50){
valid231 = true;
passing17 = 4;
if(props27 !== true){
props27 = true;
}
}
const _errs1265 = errors;
if(errors === _errs1265){
if(data404 && typeof data404 == "object" && !Array.isArray(data404)){
let missing149;
if((data404.binary === undefined) && (missing149 = "binary")){
const err1266 = {instancePath:instancePath+"/page/cells/" + i34+"/" + i35+"/conflict/" + i36+"/value/value",schemaPath:"#/oneOf/10/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/properties/value/oneOf/2/properties/value/oneOf/5/required",keyword:"required",params:{missingProperty: missing149},message:"must have required property '"+missing149+"'"};
if(vErrors === null){
vErrors = [err1266];
}
else {
vErrors.push(err1266);
}
errors++;
}
else {
const _errs1267 = errors;
for(const key149 in data404){
if(!(key149 === "binary")){
const err1267 = {instancePath:instancePath+"/page/cells/" + i34+"/" + i35+"/conflict/" + i36+"/value/value",schemaPath:"#/oneOf/10/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/properties/value/oneOf/2/properties/value/oneOf/5/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key149},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err1267];
}
else {
vErrors.push(err1267);
}
errors++;
break;
}
}
if(_errs1267 === errors){
if(data404.binary !== undefined){
let data410 = data404.binary;
const _errs1268 = errors;
if(errors === _errs1268){
if(typeof data410 === "string"){
if(func1(data410) > 131072){
const err1268 = {instancePath:instancePath+"/page/cells/" + i34+"/" + i35+"/conflict/" + i36+"/value/value/binary",schemaPath:"#/oneOf/10/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/properties/value/oneOf/2/properties/value/oneOf/5/properties/binary/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err1268];
}
else {
vErrors.push(err1268);
}
errors++;
}
}
else {
const err1269 = {instancePath:instancePath+"/page/cells/" + i34+"/" + i35+"/conflict/" + i36+"/value/value/binary",schemaPath:"#/oneOf/10/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/properties/value/oneOf/2/properties/value/oneOf/5/properties/binary/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err1269];
}
else {
vErrors.push(err1269);
}
errors++;
}
}
}
}
}
}
else {
const err1270 = {instancePath:instancePath+"/page/cells/" + i34+"/" + i35+"/conflict/" + i36+"/value/value",schemaPath:"#/oneOf/10/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/properties/value/oneOf/2/properties/value/oneOf/5/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err1270];
}
else {
vErrors.push(err1270);
}
errors++;
}
}
var _valid50 = _errs1265 === errors;
if(_valid50 && valid231){
valid231 = false;
passing17 = [passing17, 5];
}
else {
if(_valid50){
valid231 = true;
passing17 = 5;
if(props27 !== true){
props27 = true;
}
}
}
}
}
}
}
if(!valid231){
const err1271 = {instancePath:instancePath+"/page/cells/" + i34+"/" + i35+"/conflict/" + i36+"/value/value",schemaPath:"#/oneOf/10/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/properties/value/oneOf/2/properties/value/oneOf",keyword:"oneOf",params:{passingSchemas: passing17},message:"must match exactly one schema in oneOf"};
if(vErrors === null){
vErrors = [err1271];
}
else {
vErrors.push(err1271);
}
errors++;
}
else {
errors = _errs1239;
if(vErrors !== null){
if(_errs1239){
vErrors.length = _errs1239;
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
const err1272 = {instancePath:instancePath+"/page/cells/" + i34+"/" + i35+"/conflict/" + i36+"/value",schemaPath:"#/oneOf/10/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/properties/value/oneOf/2/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err1272];
}
else {
vErrors.push(err1272);
}
errors++;
}
}
var _valid49 = _errs1235 === errors;
if(_valid49 && valid227){
valid227 = false;
passing16 = [passing16, 2];
}
else {
if(_valid49){
valid227 = true;
passing16 = 2;
if(props26 !== true){
props26 = true;
}
}
}
}
if(!valid227){
const err1273 = {instancePath:instancePath+"/page/cells/" + i34+"/" + i35+"/conflict/" + i36+"/value",schemaPath:"#/oneOf/10/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/properties/value/oneOf",keyword:"oneOf",params:{passingSchemas: passing16},message:"must match exactly one schema in oneOf"};
if(vErrors === null){
vErrors = [err1273];
}
else {
vErrors.push(err1273);
}
errors++;
}
else {
errors = _errs1224;
if(vErrors !== null){
if(_errs1224){
vErrors.length = _errs1224;
}
else {
vErrors = null;
}
}
}
var valid226 = _errs1223 === errors;
}
else {
var valid226 = true;
}
}
}
}
}
}
else {
const err1274 = {instancePath:instancePath+"/page/cells/" + i34+"/" + i35+"/conflict/" + i36,schemaPath:"#/oneOf/10/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/items/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err1274];
}
else {
vErrors.push(err1274);
}
errors++;
}
}
var valid225 = _errs1216 === errors;
if(!valid225){
break;
}
}
}
}
else {
const err1275 = {instancePath:instancePath+"/page/cells/" + i34+"/" + i35+"/conflict",schemaPath:"#/oneOf/10/properties/page/properties/cells/items/items/oneOf/4/properties/conflict/type",keyword:"type",params:{type: "array"},message:"must be array"};
if(vErrors === null){
vErrors = [err1275];
}
else {
vErrors.push(err1275);
}
errors++;
}
}
}
}
}
}
else {
const err1276 = {instancePath:instancePath+"/page/cells/" + i34+"/" + i35,schemaPath:"#/oneOf/10/properties/page/properties/cells/items/items/oneOf/4/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err1276];
}
else {
vErrors.push(err1276);
}
errors++;
}
}
var _valid47 = _errs1211 === errors;
if(_valid47 && valid212){
valid212 = false;
passing14 = [passing14, 4];
}
else {
if(_valid47){
valid212 = true;
passing14 = 4;
if(props24 !== true){
props24 = true;
}
}
}
}
}
}
if(!valid212){
const err1277 = {instancePath:instancePath+"/page/cells/" + i34+"/" + i35,schemaPath:"#/oneOf/10/properties/page/properties/cells/items/items/oneOf",keyword:"oneOf",params:{passingSchemas: passing14},message:"must match exactly one schema in oneOf"};
if(vErrors === null){
vErrors = [err1277];
}
else {
vErrors.push(err1277);
}
errors++;
}
else {
errors = _errs1160;
if(vErrors !== null){
if(_errs1160){
vErrors.length = _errs1160;
}
else {
vErrors = null;
}
}
}
var valid211 = _errs1159 === errors;
if(!valid211){
break;
}
}
}
}
else {
const err1278 = {instancePath:instancePath+"/page/cells/" + i34,schemaPath:"#/oneOf/10/properties/page/properties/cells/items/type",keyword:"type",params:{type: "array"},message:"must be array"};
if(vErrors === null){
vErrors = [err1278];
}
else {
vErrors.push(err1278);
}
errors++;
}
}
var valid210 = _errs1157 === errors;
if(!valid210){
break;
}
}
}
}
else {
const err1279 = {instancePath:instancePath+"/page/cells",schemaPath:"#/oneOf/10/properties/page/properties/cells/type",keyword:"type",params:{type: "array"},message:"must be array"};
if(vErrors === null){
vErrors = [err1279];
}
else {
vErrors.push(err1279);
}
errors++;
}
}
var valid196 = _errs1155 === errors;
}
else {
var valid196 = true;
}
}
}
}
}
else {
const err1280 = {instancePath:instancePath+"/page",schemaPath:"#/oneOf/10/properties/page/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err1280];
}
else {
vErrors.push(err1280);
}
errors++;
}
}
}
}
}
}
else {
const err1281 = {instancePath,schemaPath:"#/oneOf/10/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err1281];
}
else {
vErrors.push(err1281);
}
errors++;
}
}
var _valid0 = _errs1052 === errors;
if(_valid0 && valid0){
valid0 = false;
passing0 = [passing0, 10];
}
else {
if(_valid0){
valid0 = true;
passing0 = 10;
if(props1 !== true){
props1 = true;
}
}
const _errs1270 = errors;
if(errors === _errs1270){
if(data && typeof data == "object" && !Array.isArray(data)){
let missing150;
if((data.draft === undefined) && (missing150 = "draft")){
const err1282 = {instancePath,schemaPath:"#/oneOf/11/required",keyword:"required",params:{missingProperty: missing150},message:"must have required property '"+missing150+"'"};
if(vErrors === null){
vErrors = [err1282];
}
else {
vErrors.push(err1282);
}
errors++;
}
else {
const _errs1272 = errors;
for(const key150 in data){
if(!(key150 === "draft")){
const err1283 = {instancePath,schemaPath:"#/oneOf/11/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key150},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err1283];
}
else {
vErrors.push(err1283);
}
errors++;
break;
}
}
if(_errs1272 === errors){
if(data.draft !== undefined){
let data411 = data.draft;
const _errs1274 = errors;
let valid239 = false;
const _errs1275 = errors;
if(errors === _errs1275){
if(data411 && typeof data411 == "object" && !Array.isArray(data411)){
let missing151;
if((((((((data411.generation === undefined) && (missing151 = "generation")) || ((data411.limit === undefined) && (missing151 = "limit"))) || ((data411.starts === undefined) && (missing151 = "starts"))) || ((data411.enabled === undefined) && (missing151 = "enabled"))) || ((data411.contract === undefined) && (missing151 = "contract"))) || ((data411.budgets === undefined) && (missing151 = "budgets"))) || ((data411.namespaces === undefined) && (missing151 = "namespaces"))){
const err1284 = {instancePath:instancePath+"/draft",schemaPath:"#/oneOf/11/properties/draft/anyOf/0/required",keyword:"required",params:{missingProperty: missing151},message:"must have required property '"+missing151+"'"};
if(vErrors === null){
vErrors = [err1284];
}
else {
vErrors.push(err1284);
}
errors++;
}
else {
const _errs1277 = errors;
for(const key151 in data411){
if(!(((((((key151 === "generation") || (key151 === "limit")) || (key151 === "starts")) || (key151 === "enabled")) || (key151 === "contract")) || (key151 === "budgets")) || (key151 === "namespaces"))){
const err1285 = {instancePath:instancePath+"/draft",schemaPath:"#/oneOf/11/properties/draft/anyOf/0/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key151},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err1285];
}
else {
vErrors.push(err1285);
}
errors++;
break;
}
}
if(_errs1277 === errors){
if(data411.generation !== undefined){
let data412 = data411.generation;
const _errs1278 = errors;
if(errors === _errs1278){
if(typeof data412 === "string"){
if(func1(data412) > 131072){
const err1286 = {instancePath:instancePath+"/draft/generation",schemaPath:"#/oneOf/11/properties/draft/anyOf/0/properties/generation/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err1286];
}
else {
vErrors.push(err1286);
}
errors++;
}
}
else {
const err1287 = {instancePath:instancePath+"/draft/generation",schemaPath:"#/oneOf/11/properties/draft/anyOf/0/properties/generation/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err1287];
}
else {
vErrors.push(err1287);
}
errors++;
}
}
var valid240 = _errs1278 === errors;
}
else {
var valid240 = true;
}
if(valid240){
if(data411.limit !== undefined){
let data413 = data411.limit;
const _errs1280 = errors;
if(!(((typeof data413 == "number") && (!(data413 % 1) && !isNaN(data413))) && (isFinite(data413)))){
const err1288 = {instancePath:instancePath+"/draft/limit",schemaPath:"#/oneOf/11/properties/draft/anyOf/0/properties/limit/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err1288];
}
else {
vErrors.push(err1288);
}
errors++;
}
if(errors === _errs1280){
if((typeof data413 == "number") && (isFinite(data413))){
if(data413 > 255 || isNaN(data413)){
const err1289 = {instancePath:instancePath+"/draft/limit",schemaPath:"#/oneOf/11/properties/draft/anyOf/0/properties/limit/maximum",keyword:"maximum",params:{comparison: "<=", limit: 255},message:"must be <= 255"};
if(vErrors === null){
vErrors = [err1289];
}
else {
vErrors.push(err1289);
}
errors++;
}
else {
if(data413 < 0 || isNaN(data413)){
const err1290 = {instancePath:instancePath+"/draft/limit",schemaPath:"#/oneOf/11/properties/draft/anyOf/0/properties/limit/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err1290];
}
else {
vErrors.push(err1290);
}
errors++;
}
}
}
}
var valid240 = _errs1280 === errors;
}
else {
var valid240 = true;
}
if(valid240){
if(data411.starts !== undefined){
let data414 = data411.starts;
const _errs1282 = errors;
if(!(((typeof data414 == "number") && (!(data414 % 1) && !isNaN(data414))) && (isFinite(data414)))){
const err1291 = {instancePath:instancePath+"/draft/starts",schemaPath:"#/oneOf/11/properties/draft/anyOf/0/properties/starts/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err1291];
}
else {
vErrors.push(err1291);
}
errors++;
}
if(errors === _errs1282){
if((typeof data414 == "number") && (isFinite(data414))){
if(data414 > 255 || isNaN(data414)){
const err1292 = {instancePath:instancePath+"/draft/starts",schemaPath:"#/oneOf/11/properties/draft/anyOf/0/properties/starts/maximum",keyword:"maximum",params:{comparison: "<=", limit: 255},message:"must be <= 255"};
if(vErrors === null){
vErrors = [err1292];
}
else {
vErrors.push(err1292);
}
errors++;
}
else {
if(data414 < 0 || isNaN(data414)){
const err1293 = {instancePath:instancePath+"/draft/starts",schemaPath:"#/oneOf/11/properties/draft/anyOf/0/properties/starts/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err1293];
}
else {
vErrors.push(err1293);
}
errors++;
}
}
}
}
var valid240 = _errs1282 === errors;
}
else {
var valid240 = true;
}
if(valid240){
if(data411.enabled !== undefined){
const _errs1284 = errors;
if(typeof data411.enabled !== "boolean"){
const err1294 = {instancePath:instancePath+"/draft/enabled",schemaPath:"#/oneOf/11/properties/draft/anyOf/0/properties/enabled/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"};
if(vErrors === null){
vErrors = [err1294];
}
else {
vErrors.push(err1294);
}
errors++;
}
var valid240 = _errs1284 === errors;
}
else {
var valid240 = true;
}
if(valid240){
if(data411.contract !== undefined){
let data416 = data411.contract;
const _errs1286 = errors;
if(errors === _errs1286){
if(Array.isArray(data416)){
if(data416.length > 32){
const err1295 = {instancePath:instancePath+"/draft/contract",schemaPath:"#/oneOf/11/properties/draft/anyOf/0/properties/contract/maxItems",keyword:"maxItems",params:{limit: 32},message:"must NOT have more than 32 items"};
if(vErrors === null){
vErrors = [err1295];
}
else {
vErrors.push(err1295);
}
errors++;
}
else {
if(data416.length < 32){
const err1296 = {instancePath:instancePath+"/draft/contract",schemaPath:"#/oneOf/11/properties/draft/anyOf/0/properties/contract/minItems",keyword:"minItems",params:{limit: 32},message:"must NOT have fewer than 32 items"};
if(vErrors === null){
vErrors = [err1296];
}
else {
vErrors.push(err1296);
}
errors++;
}
else {
var valid241 = true;
const len37 = data416.length;
for(let i37=0; i37<len37; i37++){
let data417 = data416[i37];
const _errs1288 = errors;
if(!(((typeof data417 == "number") && (!(data417 % 1) && !isNaN(data417))) && (isFinite(data417)))){
const err1297 = {instancePath:instancePath+"/draft/contract/" + i37,schemaPath:"#/oneOf/11/properties/draft/anyOf/0/properties/contract/items/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err1297];
}
else {
vErrors.push(err1297);
}
errors++;
}
if(errors === _errs1288){
if((typeof data417 == "number") && (isFinite(data417))){
if(data417 > 255 || isNaN(data417)){
const err1298 = {instancePath:instancePath+"/draft/contract/" + i37,schemaPath:"#/oneOf/11/properties/draft/anyOf/0/properties/contract/items/maximum",keyword:"maximum",params:{comparison: "<=", limit: 255},message:"must be <= 255"};
if(vErrors === null){
vErrors = [err1298];
}
else {
vErrors.push(err1298);
}
errors++;
}
else {
if(data417 < 0 || isNaN(data417)){
const err1299 = {instancePath:instancePath+"/draft/contract/" + i37,schemaPath:"#/oneOf/11/properties/draft/anyOf/0/properties/contract/items/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err1299];
}
else {
vErrors.push(err1299);
}
errors++;
}
}
}
}
var valid241 = _errs1288 === errors;
if(!valid241){
break;
}
}
}
}
}
else {
const err1300 = {instancePath:instancePath+"/draft/contract",schemaPath:"#/oneOf/11/properties/draft/anyOf/0/properties/contract/type",keyword:"type",params:{type: "array"},message:"must be array"};
if(vErrors === null){
vErrors = [err1300];
}
else {
vErrors.push(err1300);
}
errors++;
}
}
var valid240 = _errs1286 === errors;
}
else {
var valid240 = true;
}
if(valid240){
if(data411.budgets !== undefined){
let data418 = data411.budgets;
const _errs1290 = errors;
if(errors === _errs1290){
if(data418 && typeof data418 == "object" && !Array.isArray(data418)){
let missing152;
if((((data418.pages === undefined) && (missing152 = "pages")) || ((data418.segments === undefined) && (missing152 = "segments"))) || ((data418.result_bytes === undefined) && (missing152 = "result_bytes"))){
const err1301 = {instancePath:instancePath+"/draft/budgets",schemaPath:"#/oneOf/11/properties/draft/anyOf/0/properties/budgets/required",keyword:"required",params:{missingProperty: missing152},message:"must have required property '"+missing152+"'"};
if(vErrors === null){
vErrors = [err1301];
}
else {
vErrors.push(err1301);
}
errors++;
}
else {
const _errs1292 = errors;
for(const key152 in data418){
if(!(((key152 === "pages") || (key152 === "segments")) || (key152 === "result_bytes"))){
const err1302 = {instancePath:instancePath+"/draft/budgets",schemaPath:"#/oneOf/11/properties/draft/anyOf/0/properties/budgets/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key152},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err1302];
}
else {
vErrors.push(err1302);
}
errors++;
break;
}
}
if(_errs1292 === errors){
if(data418.pages !== undefined){
let data419 = data418.pages;
const _errs1293 = errors;
if(errors === _errs1293){
if(typeof data419 === "string"){
if(func1(data419) > 131072){
const err1303 = {instancePath:instancePath+"/draft/budgets/pages",schemaPath:"#/oneOf/11/properties/draft/anyOf/0/properties/budgets/properties/pages/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err1303];
}
else {
vErrors.push(err1303);
}
errors++;
}
}
else {
const err1304 = {instancePath:instancePath+"/draft/budgets/pages",schemaPath:"#/oneOf/11/properties/draft/anyOf/0/properties/budgets/properties/pages/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err1304];
}
else {
vErrors.push(err1304);
}
errors++;
}
}
var valid242 = _errs1293 === errors;
}
else {
var valid242 = true;
}
if(valid242){
if(data418.segments !== undefined){
let data420 = data418.segments;
const _errs1295 = errors;
if(errors === _errs1295){
if(typeof data420 === "string"){
if(func1(data420) > 131072){
const err1305 = {instancePath:instancePath+"/draft/budgets/segments",schemaPath:"#/oneOf/11/properties/draft/anyOf/0/properties/budgets/properties/segments/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err1305];
}
else {
vErrors.push(err1305);
}
errors++;
}
}
else {
const err1306 = {instancePath:instancePath+"/draft/budgets/segments",schemaPath:"#/oneOf/11/properties/draft/anyOf/0/properties/budgets/properties/segments/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err1306];
}
else {
vErrors.push(err1306);
}
errors++;
}
}
var valid242 = _errs1295 === errors;
}
else {
var valid242 = true;
}
if(valid242){
if(data418.result_bytes !== undefined){
let data421 = data418.result_bytes;
const _errs1297 = errors;
if(errors === _errs1297){
if(typeof data421 === "string"){
if(func1(data421) > 131072){
const err1307 = {instancePath:instancePath+"/draft/budgets/result_bytes",schemaPath:"#/oneOf/11/properties/draft/anyOf/0/properties/budgets/properties/result_bytes/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err1307];
}
else {
vErrors.push(err1307);
}
errors++;
}
}
else {
const err1308 = {instancePath:instancePath+"/draft/budgets/result_bytes",schemaPath:"#/oneOf/11/properties/draft/anyOf/0/properties/budgets/properties/result_bytes/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err1308];
}
else {
vErrors.push(err1308);
}
errors++;
}
}
var valid242 = _errs1297 === errors;
}
else {
var valid242 = true;
}
}
}
}
}
}
else {
const err1309 = {instancePath:instancePath+"/draft/budgets",schemaPath:"#/oneOf/11/properties/draft/anyOf/0/properties/budgets/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err1309];
}
else {
vErrors.push(err1309);
}
errors++;
}
}
var valid240 = _errs1290 === errors;
}
else {
var valid240 = true;
}
if(valid240){
if(data411.namespaces !== undefined){
let data422 = data411.namespaces;
const _errs1299 = errors;
if(errors === _errs1299){
if(Array.isArray(data422)){
if(data422.length > 8){
const err1310 = {instancePath:instancePath+"/draft/namespaces",schemaPath:"#/oneOf/11/properties/draft/anyOf/0/properties/namespaces/maxItems",keyword:"maxItems",params:{limit: 8},message:"must NOT have more than 8 items"};
if(vErrors === null){
vErrors = [err1310];
}
else {
vErrors.push(err1310);
}
errors++;
}
else {
if(data422.length < 8){
const err1311 = {instancePath:instancePath+"/draft/namespaces",schemaPath:"#/oneOf/11/properties/draft/anyOf/0/properties/namespaces/minItems",keyword:"minItems",params:{limit: 8},message:"must NOT have fewer than 8 items"};
if(vErrors === null){
vErrors = [err1311];
}
else {
vErrors.push(err1311);
}
errors++;
}
else {
var valid243 = true;
const len38 = data422.length;
for(let i38=0; i38<len38; i38++){
let data423 = data422[i38];
const _errs1301 = errors;
if(errors === _errs1301){
if(typeof data423 === "string"){
if(func1(data423) > 131072){
const err1312 = {instancePath:instancePath+"/draft/namespaces/" + i38,schemaPath:"#/oneOf/11/properties/draft/anyOf/0/properties/namespaces/items/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"};
if(vErrors === null){
vErrors = [err1312];
}
else {
vErrors.push(err1312);
}
errors++;
}
}
else {
const err1313 = {instancePath:instancePath+"/draft/namespaces/" + i38,schemaPath:"#/oneOf/11/properties/draft/anyOf/0/properties/namespaces/items/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err1313];
}
else {
vErrors.push(err1313);
}
errors++;
}
}
var valid243 = _errs1301 === errors;
if(!valid243){
break;
}
}
}
}
}
else {
const err1314 = {instancePath:instancePath+"/draft/namespaces",schemaPath:"#/oneOf/11/properties/draft/anyOf/0/properties/namespaces/type",keyword:"type",params:{type: "array"},message:"must be array"};
if(vErrors === null){
vErrors = [err1314];
}
else {
vErrors.push(err1314);
}
errors++;
}
}
var valid240 = _errs1299 === errors;
}
else {
var valid240 = true;
}
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
const err1315 = {instancePath:instancePath+"/draft",schemaPath:"#/oneOf/11/properties/draft/anyOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err1315];
}
else {
vErrors.push(err1315);
}
errors++;
}
}
var _valid51 = _errs1275 === errors;
valid239 = valid239 || _valid51;
const _errs1303 = errors;
if(data411 !== null){
const err1316 = {instancePath:instancePath+"/draft",schemaPath:"#/oneOf/11/properties/draft/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err1316];
}
else {
vErrors.push(err1316);
}
errors++;
}
var _valid51 = _errs1303 === errors;
valid239 = valid239 || _valid51;
if(!valid239){
const err1317 = {instancePath:instancePath+"/draft",schemaPath:"#/oneOf/11/properties/draft/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err1317];
}
else {
vErrors.push(err1317);
}
errors++;
}
else {
errors = _errs1274;
if(vErrors !== null){
if(_errs1274){
vErrors.length = _errs1274;
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
const err1318 = {instancePath,schemaPath:"#/oneOf/11/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err1318];
}
else {
vErrors.push(err1318);
}
errors++;
}
}
var _valid0 = _errs1270 === errors;
if(_valid0 && valid0){
valid0 = false;
passing0 = [passing0, 11];
}
else {
if(_valid0){
valid0 = true;
passing0 = 11;
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
}
}
if(!valid0){
const err1319 = {instancePath,schemaPath:"#/oneOf",keyword:"oneOf",params:{passingSchemas: passing0},message:"must match exactly one schema in oneOf"};
if(vErrors === null){
vErrors = [err1319];
}
else {
vErrors.push(err1319);
}
errors++;
validate22.errors = vErrors;
return false;
}
else {
errors = _errs0;
if(vErrors !== null){
if(_errs0){
vErrors.length = _errs0;
}
else {
vErrors = null;
}
}
}
validate22.errors = vErrors;
evaluated0.props = props1;
return errors === 0;
}
validate22.evaluated = {"dynamicProps":true,"dynamicItems":false};

export const Draft = validate23;
const schema34 = {"type":"object","additionalProperties":false,"properties":{"generation":{"type":"string","maxLength":131072},"limit":{"type":"integer","minimum":0,"maximum":255},"starts":{"type":"integer","minimum":0,"maximum":255},"enabled":{"type":"boolean"},"contract":{"type":"array","minItems":32,"maxItems":32,"items":{"type":"integer","minimum":0,"maximum":255}},"budgets":{"type":"object","additionalProperties":false,"properties":{"pages":{"type":"string","maxLength":131072},"segments":{"type":"string","maxLength":131072},"result_bytes":{"type":"string","maxLength":131072}},"required":["pages","segments","result_bytes"]},"namespaces":{"type":"array","minItems":8,"maxItems":8,"items":{"type":"string","maxLength":131072}}},"required":["generation","limit","starts","enabled","contract","budgets","namespaces"]};

function validate23(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate23.evaluated;
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
validate23.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(((((((key0 === "generation") || (key0 === "limit")) || (key0 === "starts")) || (key0 === "enabled")) || (key0 === "contract")) || (key0 === "budgets")) || (key0 === "namespaces"))){
validate23.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
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
validate23.errors = [{instancePath:instancePath+"/generation",schemaPath:"#/properties/generation/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"}];
return false;
}
}
else {
validate23.errors = [{instancePath:instancePath+"/generation",schemaPath:"#/properties/generation/type",keyword:"type",params:{type: "string"},message:"must be string"}];
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
let data1 = data.limit;
const _errs4 = errors;
if(!(((typeof data1 == "number") && (!(data1 % 1) && !isNaN(data1))) && (isFinite(data1)))){
validate23.errors = [{instancePath:instancePath+"/limit",schemaPath:"#/properties/limit/type",keyword:"type",params:{type: "integer"},message:"must be integer"}];
return false;
}
if(errors === _errs4){
if((typeof data1 == "number") && (isFinite(data1))){
if(data1 > 255 || isNaN(data1)){
validate23.errors = [{instancePath:instancePath+"/limit",schemaPath:"#/properties/limit/maximum",keyword:"maximum",params:{comparison: "<=", limit: 255},message:"must be <= 255"}];
return false;
}
else {
if(data1 < 0 || isNaN(data1)){
validate23.errors = [{instancePath:instancePath+"/limit",schemaPath:"#/properties/limit/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"}];
return false;
}
}
}
}
var valid0 = _errs4 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.starts !== undefined){
let data2 = data.starts;
const _errs6 = errors;
if(!(((typeof data2 == "number") && (!(data2 % 1) && !isNaN(data2))) && (isFinite(data2)))){
validate23.errors = [{instancePath:instancePath+"/starts",schemaPath:"#/properties/starts/type",keyword:"type",params:{type: "integer"},message:"must be integer"}];
return false;
}
if(errors === _errs6){
if((typeof data2 == "number") && (isFinite(data2))){
if(data2 > 255 || isNaN(data2)){
validate23.errors = [{instancePath:instancePath+"/starts",schemaPath:"#/properties/starts/maximum",keyword:"maximum",params:{comparison: "<=", limit: 255},message:"must be <= 255"}];
return false;
}
else {
if(data2 < 0 || isNaN(data2)){
validate23.errors = [{instancePath:instancePath+"/starts",schemaPath:"#/properties/starts/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"}];
return false;
}
}
}
}
var valid0 = _errs6 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.enabled !== undefined){
const _errs8 = errors;
if(typeof data.enabled !== "boolean"){
validate23.errors = [{instancePath:instancePath+"/enabled",schemaPath:"#/properties/enabled/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"}];
return false;
}
var valid0 = _errs8 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.contract !== undefined){
let data4 = data.contract;
const _errs10 = errors;
if(errors === _errs10){
if(Array.isArray(data4)){
if(data4.length > 32){
validate23.errors = [{instancePath:instancePath+"/contract",schemaPath:"#/properties/contract/maxItems",keyword:"maxItems",params:{limit: 32},message:"must NOT have more than 32 items"}];
return false;
}
else {
if(data4.length < 32){
validate23.errors = [{instancePath:instancePath+"/contract",schemaPath:"#/properties/contract/minItems",keyword:"minItems",params:{limit: 32},message:"must NOT have fewer than 32 items"}];
return false;
}
else {
var valid1 = true;
const len0 = data4.length;
for(let i0=0; i0<len0; i0++){
let data5 = data4[i0];
const _errs12 = errors;
if(!(((typeof data5 == "number") && (!(data5 % 1) && !isNaN(data5))) && (isFinite(data5)))){
validate23.errors = [{instancePath:instancePath+"/contract/" + i0,schemaPath:"#/properties/contract/items/type",keyword:"type",params:{type: "integer"},message:"must be integer"}];
return false;
}
if(errors === _errs12){
if((typeof data5 == "number") && (isFinite(data5))){
if(data5 > 255 || isNaN(data5)){
validate23.errors = [{instancePath:instancePath+"/contract/" + i0,schemaPath:"#/properties/contract/items/maximum",keyword:"maximum",params:{comparison: "<=", limit: 255},message:"must be <= 255"}];
return false;
}
else {
if(data5 < 0 || isNaN(data5)){
validate23.errors = [{instancePath:instancePath+"/contract/" + i0,schemaPath:"#/properties/contract/items/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"}];
return false;
}
}
}
}
var valid1 = _errs12 === errors;
if(!valid1){
break;
}
}
}
}
}
else {
validate23.errors = [{instancePath:instancePath+"/contract",schemaPath:"#/properties/contract/type",keyword:"type",params:{type: "array"},message:"must be array"}];
return false;
}
}
var valid0 = _errs10 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.budgets !== undefined){
let data6 = data.budgets;
const _errs14 = errors;
if(errors === _errs14){
if(data6 && typeof data6 == "object" && !Array.isArray(data6)){
let missing1;
if((((data6.pages === undefined) && (missing1 = "pages")) || ((data6.segments === undefined) && (missing1 = "segments"))) || ((data6.result_bytes === undefined) && (missing1 = "result_bytes"))){
validate23.errors = [{instancePath:instancePath+"/budgets",schemaPath:"#/properties/budgets/required",keyword:"required",params:{missingProperty: missing1},message:"must have required property '"+missing1+"'"}];
return false;
}
else {
const _errs16 = errors;
for(const key1 in data6){
if(!(((key1 === "pages") || (key1 === "segments")) || (key1 === "result_bytes"))){
validate23.errors = [{instancePath:instancePath+"/budgets",schemaPath:"#/properties/budgets/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key1},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs16 === errors){
if(data6.pages !== undefined){
let data7 = data6.pages;
const _errs17 = errors;
if(errors === _errs17){
if(typeof data7 === "string"){
if(func1(data7) > 131072){
validate23.errors = [{instancePath:instancePath+"/budgets/pages",schemaPath:"#/properties/budgets/properties/pages/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"}];
return false;
}
}
else {
validate23.errors = [{instancePath:instancePath+"/budgets/pages",schemaPath:"#/properties/budgets/properties/pages/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
}
var valid2 = _errs17 === errors;
}
else {
var valid2 = true;
}
if(valid2){
if(data6.segments !== undefined){
let data8 = data6.segments;
const _errs19 = errors;
if(errors === _errs19){
if(typeof data8 === "string"){
if(func1(data8) > 131072){
validate23.errors = [{instancePath:instancePath+"/budgets/segments",schemaPath:"#/properties/budgets/properties/segments/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"}];
return false;
}
}
else {
validate23.errors = [{instancePath:instancePath+"/budgets/segments",schemaPath:"#/properties/budgets/properties/segments/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
}
var valid2 = _errs19 === errors;
}
else {
var valid2 = true;
}
if(valid2){
if(data6.result_bytes !== undefined){
let data9 = data6.result_bytes;
const _errs21 = errors;
if(errors === _errs21){
if(typeof data9 === "string"){
if(func1(data9) > 131072){
validate23.errors = [{instancePath:instancePath+"/budgets/result_bytes",schemaPath:"#/properties/budgets/properties/result_bytes/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"}];
return false;
}
}
else {
validate23.errors = [{instancePath:instancePath+"/budgets/result_bytes",schemaPath:"#/properties/budgets/properties/result_bytes/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
}
var valid2 = _errs21 === errors;
}
else {
var valid2 = true;
}
}
}
}
}
}
else {
validate23.errors = [{instancePath:instancePath+"/budgets",schemaPath:"#/properties/budgets/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
var valid0 = _errs14 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.namespaces !== undefined){
let data10 = data.namespaces;
const _errs23 = errors;
if(errors === _errs23){
if(Array.isArray(data10)){
if(data10.length > 8){
validate23.errors = [{instancePath:instancePath+"/namespaces",schemaPath:"#/properties/namespaces/maxItems",keyword:"maxItems",params:{limit: 8},message:"must NOT have more than 8 items"}];
return false;
}
else {
if(data10.length < 8){
validate23.errors = [{instancePath:instancePath+"/namespaces",schemaPath:"#/properties/namespaces/minItems",keyword:"minItems",params:{limit: 8},message:"must NOT have fewer than 8 items"}];
return false;
}
else {
var valid3 = true;
const len1 = data10.length;
for(let i1=0; i1<len1; i1++){
let data11 = data10[i1];
const _errs25 = errors;
if(errors === _errs25){
if(typeof data11 === "string"){
if(func1(data11) > 131072){
validate23.errors = [{instancePath:instancePath+"/namespaces/" + i1,schemaPath:"#/properties/namespaces/items/maxLength",keyword:"maxLength",params:{limit: 131072},message:"must NOT have more than 131072 characters"}];
return false;
}
}
else {
validate23.errors = [{instancePath:instancePath+"/namespaces/" + i1,schemaPath:"#/properties/namespaces/items/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
}
var valid3 = _errs25 === errors;
if(!valid3){
break;
}
}
}
}
}
else {
validate23.errors = [{instancePath:instancePath+"/namespaces",schemaPath:"#/properties/namespaces/type",keyword:"type",params:{type: "array"},message:"must be array"}];
return false;
}
}
var valid0 = _errs23 === errors;
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
validate23.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate23.errors = vErrors;
return errors === 0;
}
validate23.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};

export const Diagnostic = validate24;
const schema35 = {"type":"object","additionalProperties":false,"properties":{"version":{"const":1},"definition":{"type":"string","enum":["c750e7034f20d2446bfe44c7ad19a3ca45b415a0a02754523dc280cf74e20d15"]},"code":{"type":"string","maxLength":96},"category":{"type":"string","enum":["syntax","binding","unsupported","constraint","access","conflict","limit","lifecycle","integrity","unavailable","internal"]},"stage":{"type":"string","enum":["input","parse","compile","bind","prepare","submit","admission","execute","read","decode","output","reconcile","cleanup","control"]},"outcome":{"type":"string","enum":["not_applicable","not_submitted","prepared","unknown","pending","input_rejected","rejected","applied","cancelled","retired","closed_unknown"]},"evidence":{"type":"string","enum":["none","local_before_dispatch","saved_intent","native_receipt","domain_status"]},"message":{"type":"string","maxLength":384},"cause":{"anyOf":[{"type":"string","maxLength":96},{"type":"null"}]},"identity":{"anyOf":[{"type":"object","additionalProperties":false,"properties":{"domain":{"type":"string","enum":["sql","query","mutation","catalog","application","publication","migration","reactive","effect","transport","internal"]},"id":{"type":"string","maxLength":20,"pattern":"^(0|[1-9][0-9]*)$"},"realm":{"anyOf":[{"type":"string","maxLength":20,"pattern":"^(0|[1-9][0-9]*)$"},{"type":"null"}]},"resource":{"anyOf":[{"type":"string","maxLength":20,"pattern":"^(0|[1-9][0-9]*)$"},{"type":"null"}]},"sequence":{"anyOf":[{"type":"string","maxLength":20,"pattern":"^(0|[1-9][0-9]*)$"},{"type":"null"}]}},"required":["domain","id","realm","resource","sequence"]},{"type":"null"}]},"location":{"anyOf":[{"type":"object","additionalProperties":false,"properties":{"source":{"anyOf":[{"type":"string","maxLength":512},{"type":"null"}]},"source_encoding":{"type":"string","enum":["utf8","escaped_bytes"]},"source_truncated":{"type":"boolean"},"statement":{"anyOf":[{"type":"string","maxLength":20,"pattern":"^(0|[1-9][0-9]*)$"},{"type":"null"}]},"offset":{"type":"string","maxLength":20,"pattern":"^(0|[1-9][0-9]*)$"},"length":{"type":"string","maxLength":20,"pattern":"^(0|[1-9][0-9]*)$"},"line":{"type":"string","maxLength":20,"pattern":"^(0|[1-9][0-9]*)$"},"byte_column":{"type":"string","maxLength":20,"pattern":"^(0|[1-9][0-9]*)$"}},"required":["source","source_encoding","source_truncated","statement","offset","length","line","byte_column"]},{"type":"null"}]},"facts":{"type":"array","minItems":16,"maxItems":16,"items":{"anyOf":[{"type":"object","additionalProperties":false,"properties":{"field":{"type":"string","enum":["object","name","table","native_input","affected_rows","argument","option","permissions","scope","column","qualifier","constraint","key","input_row","first_occurrence","parameter","parameter_use","expected_count","actual_count","expected_type","actual_type","supplied_value","expression","source_kind","source_basis","source_key","source_row","field_path","byte_offset","expected_resource","actual_resource","expected_source","actual_source","expected_revision","actual_revision","expected_schema","actual_schema","expected_policy","actual_policy","budget","limit","required","unit","completed_statements","emitted_rows","emitted_segments","completion","proposal","step","generation","attachment","lease","schema_origin","sampling_records","operation","native_cause","expected_bytes"]},"origin":{"type":"string","enum":["caller","execution","schema","authority","owner"]},"availability":{"type":"string","enum":["provided","truncated","unrecorded","unavailable","withheld","inapplicable"]},"value":{"anyOf":[{"oneOf":[{"type":"object","additionalProperties":false,"required":["text"],"properties":{"text":{"type":"string","maxLength":256}}},{"type":"object","additionalProperties":false,"required":["signed"],"properties":{"signed":{"type":"string","maxLength":20,"pattern":"^(0|-?[1-9][0-9]*)$"}}},{"type":"object","additionalProperties":false,"required":["unsigned"],"properties":{"unsigned":{"type":"string","maxLength":20,"pattern":"^(0|[1-9][0-9]*)$"}}},{"type":"object","additionalProperties":false,"required":["boolean"],"properties":{"boolean":{"type":"boolean"}}},{"type":"object","additionalProperties":false,"required":["digest"],"properties":{"digest":{"type":"array","minItems":32,"maxItems":32,"items":{"type":"integer","minimum":0,"maximum":255}}}},{"type":"object","additionalProperties":false,"required":["location"],"properties":{"location":{"type":"object","additionalProperties":false,"properties":{"source":{"anyOf":[{"type":"string","maxLength":512},{"type":"null"}]},"source_encoding":{"type":"string","enum":["utf8","escaped_bytes"]},"source_truncated":{"type":"boolean"},"statement":{"anyOf":[{"type":"string","maxLength":20,"pattern":"^(0|[1-9][0-9]*)$"},{"type":"null"}]},"offset":{"type":"string","maxLength":20,"pattern":"^(0|[1-9][0-9]*)$"},"length":{"type":"string","maxLength":20,"pattern":"^(0|[1-9][0-9]*)$"},"line":{"type":"string","maxLength":20,"pattern":"^(0|[1-9][0-9]*)$"},"byte_column":{"type":"string","maxLength":20,"pattern":"^(0|[1-9][0-9]*)$"}},"required":["source","source_encoding","source_truncated","statement","offset","length","line","byte_column"]}}}]},{"type":"null"}]}},"required":["field","origin","availability","value"]},{"type":"null"}]}},"actions":{"type":"array","minItems":4,"maxItems":4,"items":{"anyOf":[{"type":"object","additionalProperties":false,"properties":{"kind":{"type":"string","enum":["correct_input","inspect_status","resume_exact","cancel_wait","cancel_mutation","refresh","recompile","retry_read","inspect_scope","reconcile_effect","contact_operator"]},"target":{"anyOf":[{"type":"object","additionalProperties":false,"properties":{"domain":{"type":"string","enum":["sql","query","mutation","catalog","application","publication","migration","reactive","effect","transport","internal"]},"id":{"type":"string","maxLength":20,"pattern":"^(0|[1-9][0-9]*)$"},"realm":{"anyOf":[{"type":"string","maxLength":20,"pattern":"^(0|[1-9][0-9]*)$"},{"type":"null"}]},"resource":{"anyOf":[{"type":"string","maxLength":20,"pattern":"^(0|[1-9][0-9]*)$"},{"type":"null"}]},"sequence":{"anyOf":[{"type":"string","maxLength":20,"pattern":"^(0|[1-9][0-9]*)$"},{"type":"null"}]}},"required":["domain","id","realm","resource","sequence"]},{"type":"null"}]}},"required":["kind","target"]},{"type":"null"}]}}},"required":["version","definition","code","category","stage","outcome","evidence","message","cause","identity","location","facts","actions"]};

function validate24(data, {instancePath="", parentData, parentDataProperty, rootData=data, dynamicAnchors={}}={}){
let vErrors = null;
let errors = 0;
const evaluated0 = validate24.evaluated;
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
validate24.errors = [{instancePath,schemaPath:"#/required",keyword:"required",params:{missingProperty: missing0},message:"must have required property '"+missing0+"'"}];
return false;
}
else {
const _errs1 = errors;
for(const key0 in data){
if(!(func24.call(schema35.properties, key0))){
validate24.errors = [{instancePath,schemaPath:"#/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key0},message:"must NOT have additional properties"}];
return false;
break;
}
}
if(_errs1 === errors){
if(data.version !== undefined){
const _errs2 = errors;
if(1 !== data.version){
validate24.errors = [{instancePath:instancePath+"/version",schemaPath:"#/properties/version/const",keyword:"const",params:{allowedValue: 1},message:"must be equal to constant"}];
return false;
}
var valid0 = _errs2 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.definition !== undefined){
let data1 = data.definition;
const _errs3 = errors;
if(typeof data1 !== "string"){
validate24.errors = [{instancePath:instancePath+"/definition",schemaPath:"#/properties/definition/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
if(!(data1 === "c750e7034f20d2446bfe44c7ad19a3ca45b415a0a02754523dc280cf74e20d15")){
validate24.errors = [{instancePath:instancePath+"/definition",schemaPath:"#/properties/definition/enum",keyword:"enum",params:{allowedValues: schema35.properties.definition.enum},message:"must be equal to one of the allowed values"}];
return false;
}
var valid0 = _errs3 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.code !== undefined){
let data2 = data.code;
const _errs5 = errors;
if(errors === _errs5){
if(typeof data2 === "string"){
if(func1(data2) > 96){
validate24.errors = [{instancePath:instancePath+"/code",schemaPath:"#/properties/code/maxLength",keyword:"maxLength",params:{limit: 96},message:"must NOT have more than 96 characters"}];
return false;
}
}
else {
validate24.errors = [{instancePath:instancePath+"/code",schemaPath:"#/properties/code/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
}
var valid0 = _errs5 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.category !== undefined){
let data3 = data.category;
const _errs7 = errors;
if(typeof data3 !== "string"){
validate24.errors = [{instancePath:instancePath+"/category",schemaPath:"#/properties/category/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
if(!(((((((((((data3 === "syntax") || (data3 === "binding")) || (data3 === "unsupported")) || (data3 === "constraint")) || (data3 === "access")) || (data3 === "conflict")) || (data3 === "limit")) || (data3 === "lifecycle")) || (data3 === "integrity")) || (data3 === "unavailable")) || (data3 === "internal"))){
validate24.errors = [{instancePath:instancePath+"/category",schemaPath:"#/properties/category/enum",keyword:"enum",params:{allowedValues: schema35.properties.category.enum},message:"must be equal to one of the allowed values"}];
return false;
}
var valid0 = _errs7 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.stage !== undefined){
let data4 = data.stage;
const _errs9 = errors;
if(typeof data4 !== "string"){
validate24.errors = [{instancePath:instancePath+"/stage",schemaPath:"#/properties/stage/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
if(!((((((((((((((data4 === "input") || (data4 === "parse")) || (data4 === "compile")) || (data4 === "bind")) || (data4 === "prepare")) || (data4 === "submit")) || (data4 === "admission")) || (data4 === "execute")) || (data4 === "read")) || (data4 === "decode")) || (data4 === "output")) || (data4 === "reconcile")) || (data4 === "cleanup")) || (data4 === "control"))){
validate24.errors = [{instancePath:instancePath+"/stage",schemaPath:"#/properties/stage/enum",keyword:"enum",params:{allowedValues: schema35.properties.stage.enum},message:"must be equal to one of the allowed values"}];
return false;
}
var valid0 = _errs9 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.outcome !== undefined){
let data5 = data.outcome;
const _errs11 = errors;
if(typeof data5 !== "string"){
validate24.errors = [{instancePath:instancePath+"/outcome",schemaPath:"#/properties/outcome/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
if(!(((((((((((data5 === "not_applicable") || (data5 === "not_submitted")) || (data5 === "prepared")) || (data5 === "unknown")) || (data5 === "pending")) || (data5 === "input_rejected")) || (data5 === "rejected")) || (data5 === "applied")) || (data5 === "cancelled")) || (data5 === "retired")) || (data5 === "closed_unknown"))){
validate24.errors = [{instancePath:instancePath+"/outcome",schemaPath:"#/properties/outcome/enum",keyword:"enum",params:{allowedValues: schema35.properties.outcome.enum},message:"must be equal to one of the allowed values"}];
return false;
}
var valid0 = _errs11 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.evidence !== undefined){
let data6 = data.evidence;
const _errs13 = errors;
if(typeof data6 !== "string"){
validate24.errors = [{instancePath:instancePath+"/evidence",schemaPath:"#/properties/evidence/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
if(!(((((data6 === "none") || (data6 === "local_before_dispatch")) || (data6 === "saved_intent")) || (data6 === "native_receipt")) || (data6 === "domain_status"))){
validate24.errors = [{instancePath:instancePath+"/evidence",schemaPath:"#/properties/evidence/enum",keyword:"enum",params:{allowedValues: schema35.properties.evidence.enum},message:"must be equal to one of the allowed values"}];
return false;
}
var valid0 = _errs13 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.message !== undefined){
let data7 = data.message;
const _errs15 = errors;
if(errors === _errs15){
if(typeof data7 === "string"){
if(func1(data7) > 384){
validate24.errors = [{instancePath:instancePath+"/message",schemaPath:"#/properties/message/maxLength",keyword:"maxLength",params:{limit: 384},message:"must NOT have more than 384 characters"}];
return false;
}
}
else {
validate24.errors = [{instancePath:instancePath+"/message",schemaPath:"#/properties/message/type",keyword:"type",params:{type: "string"},message:"must be string"}];
return false;
}
}
var valid0 = _errs15 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.cause !== undefined){
let data8 = data.cause;
const _errs17 = errors;
const _errs18 = errors;
let valid1 = false;
const _errs19 = errors;
if(errors === _errs19){
if(typeof data8 === "string"){
if(func1(data8) > 96){
const err0 = {instancePath:instancePath+"/cause",schemaPath:"#/properties/cause/anyOf/0/maxLength",keyword:"maxLength",params:{limit: 96},message:"must NOT have more than 96 characters"};
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
const err1 = {instancePath:instancePath+"/cause",schemaPath:"#/properties/cause/anyOf/0/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err1];
}
else {
vErrors.push(err1);
}
errors++;
}
}
var _valid0 = _errs19 === errors;
valid1 = valid1 || _valid0;
const _errs21 = errors;
if(data8 !== null){
const err2 = {instancePath:instancePath+"/cause",schemaPath:"#/properties/cause/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err2];
}
else {
vErrors.push(err2);
}
errors++;
}
var _valid0 = _errs21 === errors;
valid1 = valid1 || _valid0;
if(!valid1){
const err3 = {instancePath:instancePath+"/cause",schemaPath:"#/properties/cause/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err3];
}
else {
vErrors.push(err3);
}
errors++;
validate24.errors = vErrors;
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
if(valid0){
if(data.identity !== undefined){
let data9 = data.identity;
const _errs23 = errors;
const _errs24 = errors;
let valid2 = false;
const _errs25 = errors;
if(errors === _errs25){
if(data9 && typeof data9 == "object" && !Array.isArray(data9)){
let missing1;
if((((((data9.domain === undefined) && (missing1 = "domain")) || ((data9.id === undefined) && (missing1 = "id"))) || ((data9.realm === undefined) && (missing1 = "realm"))) || ((data9.resource === undefined) && (missing1 = "resource"))) || ((data9.sequence === undefined) && (missing1 = "sequence"))){
const err4 = {instancePath:instancePath+"/identity",schemaPath:"#/properties/identity/anyOf/0/required",keyword:"required",params:{missingProperty: missing1},message:"must have required property '"+missing1+"'"};
if(vErrors === null){
vErrors = [err4];
}
else {
vErrors.push(err4);
}
errors++;
}
else {
const _errs27 = errors;
for(const key1 in data9){
if(!(((((key1 === "domain") || (key1 === "id")) || (key1 === "realm")) || (key1 === "resource")) || (key1 === "sequence"))){
const err5 = {instancePath:instancePath+"/identity",schemaPath:"#/properties/identity/anyOf/0/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key1},message:"must NOT have additional properties"};
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
if(_errs27 === errors){
if(data9.domain !== undefined){
let data10 = data9.domain;
const _errs28 = errors;
if(typeof data10 !== "string"){
const err6 = {instancePath:instancePath+"/identity/domain",schemaPath:"#/properties/identity/anyOf/0/properties/domain/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err6];
}
else {
vErrors.push(err6);
}
errors++;
}
if(!(((((((((((data10 === "sql") || (data10 === "query")) || (data10 === "mutation")) || (data10 === "catalog")) || (data10 === "application")) || (data10 === "publication")) || (data10 === "migration")) || (data10 === "reactive")) || (data10 === "effect")) || (data10 === "transport")) || (data10 === "internal"))){
const err7 = {instancePath:instancePath+"/identity/domain",schemaPath:"#/properties/identity/anyOf/0/properties/domain/enum",keyword:"enum",params:{allowedValues: schema35.properties.identity.anyOf[0].properties.domain.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err7];
}
else {
vErrors.push(err7);
}
errors++;
}
var valid3 = _errs28 === errors;
}
else {
var valid3 = true;
}
if(valid3){
if(data9.id !== undefined){
let data11 = data9.id;
const _errs30 = errors;
if(errors === _errs30){
if(typeof data11 === "string"){
if(func1(data11) > 20){
const err8 = {instancePath:instancePath+"/identity/id",schemaPath:"#/properties/identity/anyOf/0/properties/id/maxLength",keyword:"maxLength",params:{limit: 20},message:"must NOT have more than 20 characters"};
if(vErrors === null){
vErrors = [err8];
}
else {
vErrors.push(err8);
}
errors++;
}
else {
if(!pattern7.test(data11)){
const err9 = {instancePath:instancePath+"/identity/id",schemaPath:"#/properties/identity/anyOf/0/properties/id/pattern",keyword:"pattern",params:{pattern: "^(0|[1-9][0-9]*)$"},message:"must match pattern \""+"^(0|[1-9][0-9]*)$"+"\""};
if(vErrors === null){
vErrors = [err9];
}
else {
vErrors.push(err9);
}
errors++;
}
}
}
else {
const err10 = {instancePath:instancePath+"/identity/id",schemaPath:"#/properties/identity/anyOf/0/properties/id/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err10];
}
else {
vErrors.push(err10);
}
errors++;
}
}
var valid3 = _errs30 === errors;
}
else {
var valid3 = true;
}
if(valid3){
if(data9.realm !== undefined){
let data12 = data9.realm;
const _errs32 = errors;
const _errs33 = errors;
let valid4 = false;
const _errs34 = errors;
if(errors === _errs34){
if(typeof data12 === "string"){
if(func1(data12) > 20){
const err11 = {instancePath:instancePath+"/identity/realm",schemaPath:"#/properties/identity/anyOf/0/properties/realm/anyOf/0/maxLength",keyword:"maxLength",params:{limit: 20},message:"must NOT have more than 20 characters"};
if(vErrors === null){
vErrors = [err11];
}
else {
vErrors.push(err11);
}
errors++;
}
else {
if(!pattern7.test(data12)){
const err12 = {instancePath:instancePath+"/identity/realm",schemaPath:"#/properties/identity/anyOf/0/properties/realm/anyOf/0/pattern",keyword:"pattern",params:{pattern: "^(0|[1-9][0-9]*)$"},message:"must match pattern \""+"^(0|[1-9][0-9]*)$"+"\""};
if(vErrors === null){
vErrors = [err12];
}
else {
vErrors.push(err12);
}
errors++;
}
}
}
else {
const err13 = {instancePath:instancePath+"/identity/realm",schemaPath:"#/properties/identity/anyOf/0/properties/realm/anyOf/0/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err13];
}
else {
vErrors.push(err13);
}
errors++;
}
}
var _valid2 = _errs34 === errors;
valid4 = valid4 || _valid2;
const _errs36 = errors;
if(data12 !== null){
const err14 = {instancePath:instancePath+"/identity/realm",schemaPath:"#/properties/identity/anyOf/0/properties/realm/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err14];
}
else {
vErrors.push(err14);
}
errors++;
}
var _valid2 = _errs36 === errors;
valid4 = valid4 || _valid2;
if(!valid4){
const err15 = {instancePath:instancePath+"/identity/realm",schemaPath:"#/properties/identity/anyOf/0/properties/realm/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err15];
}
else {
vErrors.push(err15);
}
errors++;
}
else {
errors = _errs33;
if(vErrors !== null){
if(_errs33){
vErrors.length = _errs33;
}
else {
vErrors = null;
}
}
}
var valid3 = _errs32 === errors;
}
else {
var valid3 = true;
}
if(valid3){
if(data9.resource !== undefined){
let data13 = data9.resource;
const _errs38 = errors;
const _errs39 = errors;
let valid5 = false;
const _errs40 = errors;
if(errors === _errs40){
if(typeof data13 === "string"){
if(func1(data13) > 20){
const err16 = {instancePath:instancePath+"/identity/resource",schemaPath:"#/properties/identity/anyOf/0/properties/resource/anyOf/0/maxLength",keyword:"maxLength",params:{limit: 20},message:"must NOT have more than 20 characters"};
if(vErrors === null){
vErrors = [err16];
}
else {
vErrors.push(err16);
}
errors++;
}
else {
if(!pattern7.test(data13)){
const err17 = {instancePath:instancePath+"/identity/resource",schemaPath:"#/properties/identity/anyOf/0/properties/resource/anyOf/0/pattern",keyword:"pattern",params:{pattern: "^(0|[1-9][0-9]*)$"},message:"must match pattern \""+"^(0|[1-9][0-9]*)$"+"\""};
if(vErrors === null){
vErrors = [err17];
}
else {
vErrors.push(err17);
}
errors++;
}
}
}
else {
const err18 = {instancePath:instancePath+"/identity/resource",schemaPath:"#/properties/identity/anyOf/0/properties/resource/anyOf/0/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err18];
}
else {
vErrors.push(err18);
}
errors++;
}
}
var _valid3 = _errs40 === errors;
valid5 = valid5 || _valid3;
const _errs42 = errors;
if(data13 !== null){
const err19 = {instancePath:instancePath+"/identity/resource",schemaPath:"#/properties/identity/anyOf/0/properties/resource/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err19];
}
else {
vErrors.push(err19);
}
errors++;
}
var _valid3 = _errs42 === errors;
valid5 = valid5 || _valid3;
if(!valid5){
const err20 = {instancePath:instancePath+"/identity/resource",schemaPath:"#/properties/identity/anyOf/0/properties/resource/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err20];
}
else {
vErrors.push(err20);
}
errors++;
}
else {
errors = _errs39;
if(vErrors !== null){
if(_errs39){
vErrors.length = _errs39;
}
else {
vErrors = null;
}
}
}
var valid3 = _errs38 === errors;
}
else {
var valid3 = true;
}
if(valid3){
if(data9.sequence !== undefined){
let data14 = data9.sequence;
const _errs44 = errors;
const _errs45 = errors;
let valid6 = false;
const _errs46 = errors;
if(errors === _errs46){
if(typeof data14 === "string"){
if(func1(data14) > 20){
const err21 = {instancePath:instancePath+"/identity/sequence",schemaPath:"#/properties/identity/anyOf/0/properties/sequence/anyOf/0/maxLength",keyword:"maxLength",params:{limit: 20},message:"must NOT have more than 20 characters"};
if(vErrors === null){
vErrors = [err21];
}
else {
vErrors.push(err21);
}
errors++;
}
else {
if(!pattern7.test(data14)){
const err22 = {instancePath:instancePath+"/identity/sequence",schemaPath:"#/properties/identity/anyOf/0/properties/sequence/anyOf/0/pattern",keyword:"pattern",params:{pattern: "^(0|[1-9][0-9]*)$"},message:"must match pattern \""+"^(0|[1-9][0-9]*)$"+"\""};
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
else {
const err23 = {instancePath:instancePath+"/identity/sequence",schemaPath:"#/properties/identity/anyOf/0/properties/sequence/anyOf/0/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err23];
}
else {
vErrors.push(err23);
}
errors++;
}
}
var _valid4 = _errs46 === errors;
valid6 = valid6 || _valid4;
const _errs48 = errors;
if(data14 !== null){
const err24 = {instancePath:instancePath+"/identity/sequence",schemaPath:"#/properties/identity/anyOf/0/properties/sequence/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err24];
}
else {
vErrors.push(err24);
}
errors++;
}
var _valid4 = _errs48 === errors;
valid6 = valid6 || _valid4;
if(!valid6){
const err25 = {instancePath:instancePath+"/identity/sequence",schemaPath:"#/properties/identity/anyOf/0/properties/sequence/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err25];
}
else {
vErrors.push(err25);
}
errors++;
}
else {
errors = _errs45;
if(vErrors !== null){
if(_errs45){
vErrors.length = _errs45;
}
else {
vErrors = null;
}
}
}
var valid3 = _errs44 === errors;
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
else {
const err26 = {instancePath:instancePath+"/identity",schemaPath:"#/properties/identity/anyOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err26];
}
else {
vErrors.push(err26);
}
errors++;
}
}
var _valid1 = _errs25 === errors;
valid2 = valid2 || _valid1;
const _errs50 = errors;
if(data9 !== null){
const err27 = {instancePath:instancePath+"/identity",schemaPath:"#/properties/identity/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err27];
}
else {
vErrors.push(err27);
}
errors++;
}
var _valid1 = _errs50 === errors;
valid2 = valid2 || _valid1;
if(!valid2){
const err28 = {instancePath:instancePath+"/identity",schemaPath:"#/properties/identity/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err28];
}
else {
vErrors.push(err28);
}
errors++;
validate24.errors = vErrors;
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
var valid0 = _errs23 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.location !== undefined){
let data15 = data.location;
const _errs52 = errors;
const _errs53 = errors;
let valid7 = false;
const _errs54 = errors;
if(errors === _errs54){
if(data15 && typeof data15 == "object" && !Array.isArray(data15)){
let missing2;
if(((((((((data15.source === undefined) && (missing2 = "source")) || ((data15.source_encoding === undefined) && (missing2 = "source_encoding"))) || ((data15.source_truncated === undefined) && (missing2 = "source_truncated"))) || ((data15.statement === undefined) && (missing2 = "statement"))) || ((data15.offset === undefined) && (missing2 = "offset"))) || ((data15.length === undefined) && (missing2 = "length"))) || ((data15.line === undefined) && (missing2 = "line"))) || ((data15.byte_column === undefined) && (missing2 = "byte_column"))){
const err29 = {instancePath:instancePath+"/location",schemaPath:"#/properties/location/anyOf/0/required",keyword:"required",params:{missingProperty: missing2},message:"must have required property '"+missing2+"'"};
if(vErrors === null){
vErrors = [err29];
}
else {
vErrors.push(err29);
}
errors++;
}
else {
const _errs56 = errors;
for(const key2 in data15){
if(!((((((((key2 === "source") || (key2 === "source_encoding")) || (key2 === "source_truncated")) || (key2 === "statement")) || (key2 === "offset")) || (key2 === "length")) || (key2 === "line")) || (key2 === "byte_column"))){
const err30 = {instancePath:instancePath+"/location",schemaPath:"#/properties/location/anyOf/0/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key2},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err30];
}
else {
vErrors.push(err30);
}
errors++;
break;
}
}
if(_errs56 === errors){
if(data15.source !== undefined){
let data16 = data15.source;
const _errs57 = errors;
const _errs58 = errors;
let valid9 = false;
const _errs59 = errors;
if(errors === _errs59){
if(typeof data16 === "string"){
if(func1(data16) > 512){
const err31 = {instancePath:instancePath+"/location/source",schemaPath:"#/properties/location/anyOf/0/properties/source/anyOf/0/maxLength",keyword:"maxLength",params:{limit: 512},message:"must NOT have more than 512 characters"};
if(vErrors === null){
vErrors = [err31];
}
else {
vErrors.push(err31);
}
errors++;
}
}
else {
const err32 = {instancePath:instancePath+"/location/source",schemaPath:"#/properties/location/anyOf/0/properties/source/anyOf/0/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err32];
}
else {
vErrors.push(err32);
}
errors++;
}
}
var _valid6 = _errs59 === errors;
valid9 = valid9 || _valid6;
const _errs61 = errors;
if(data16 !== null){
const err33 = {instancePath:instancePath+"/location/source",schemaPath:"#/properties/location/anyOf/0/properties/source/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err33];
}
else {
vErrors.push(err33);
}
errors++;
}
var _valid6 = _errs61 === errors;
valid9 = valid9 || _valid6;
if(!valid9){
const err34 = {instancePath:instancePath+"/location/source",schemaPath:"#/properties/location/anyOf/0/properties/source/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err34];
}
else {
vErrors.push(err34);
}
errors++;
}
else {
errors = _errs58;
if(vErrors !== null){
if(_errs58){
vErrors.length = _errs58;
}
else {
vErrors = null;
}
}
}
var valid8 = _errs57 === errors;
}
else {
var valid8 = true;
}
if(valid8){
if(data15.source_encoding !== undefined){
let data17 = data15.source_encoding;
const _errs63 = errors;
if(typeof data17 !== "string"){
const err35 = {instancePath:instancePath+"/location/source_encoding",schemaPath:"#/properties/location/anyOf/0/properties/source_encoding/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err35];
}
else {
vErrors.push(err35);
}
errors++;
}
if(!((data17 === "utf8") || (data17 === "escaped_bytes"))){
const err36 = {instancePath:instancePath+"/location/source_encoding",schemaPath:"#/properties/location/anyOf/0/properties/source_encoding/enum",keyword:"enum",params:{allowedValues: schema35.properties.location.anyOf[0].properties.source_encoding.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err36];
}
else {
vErrors.push(err36);
}
errors++;
}
var valid8 = _errs63 === errors;
}
else {
var valid8 = true;
}
if(valid8){
if(data15.source_truncated !== undefined){
const _errs65 = errors;
if(typeof data15.source_truncated !== "boolean"){
const err37 = {instancePath:instancePath+"/location/source_truncated",schemaPath:"#/properties/location/anyOf/0/properties/source_truncated/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"};
if(vErrors === null){
vErrors = [err37];
}
else {
vErrors.push(err37);
}
errors++;
}
var valid8 = _errs65 === errors;
}
else {
var valid8 = true;
}
if(valid8){
if(data15.statement !== undefined){
let data19 = data15.statement;
const _errs67 = errors;
const _errs68 = errors;
let valid10 = false;
const _errs69 = errors;
if(errors === _errs69){
if(typeof data19 === "string"){
if(func1(data19) > 20){
const err38 = {instancePath:instancePath+"/location/statement",schemaPath:"#/properties/location/anyOf/0/properties/statement/anyOf/0/maxLength",keyword:"maxLength",params:{limit: 20},message:"must NOT have more than 20 characters"};
if(vErrors === null){
vErrors = [err38];
}
else {
vErrors.push(err38);
}
errors++;
}
else {
if(!pattern7.test(data19)){
const err39 = {instancePath:instancePath+"/location/statement",schemaPath:"#/properties/location/anyOf/0/properties/statement/anyOf/0/pattern",keyword:"pattern",params:{pattern: "^(0|[1-9][0-9]*)$"},message:"must match pattern \""+"^(0|[1-9][0-9]*)$"+"\""};
if(vErrors === null){
vErrors = [err39];
}
else {
vErrors.push(err39);
}
errors++;
}
}
}
else {
const err40 = {instancePath:instancePath+"/location/statement",schemaPath:"#/properties/location/anyOf/0/properties/statement/anyOf/0/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err40];
}
else {
vErrors.push(err40);
}
errors++;
}
}
var _valid7 = _errs69 === errors;
valid10 = valid10 || _valid7;
const _errs71 = errors;
if(data19 !== null){
const err41 = {instancePath:instancePath+"/location/statement",schemaPath:"#/properties/location/anyOf/0/properties/statement/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err41];
}
else {
vErrors.push(err41);
}
errors++;
}
var _valid7 = _errs71 === errors;
valid10 = valid10 || _valid7;
if(!valid10){
const err42 = {instancePath:instancePath+"/location/statement",schemaPath:"#/properties/location/anyOf/0/properties/statement/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err42];
}
else {
vErrors.push(err42);
}
errors++;
}
else {
errors = _errs68;
if(vErrors !== null){
if(_errs68){
vErrors.length = _errs68;
}
else {
vErrors = null;
}
}
}
var valid8 = _errs67 === errors;
}
else {
var valid8 = true;
}
if(valid8){
if(data15.offset !== undefined){
let data20 = data15.offset;
const _errs73 = errors;
if(errors === _errs73){
if(typeof data20 === "string"){
if(func1(data20) > 20){
const err43 = {instancePath:instancePath+"/location/offset",schemaPath:"#/properties/location/anyOf/0/properties/offset/maxLength",keyword:"maxLength",params:{limit: 20},message:"must NOT have more than 20 characters"};
if(vErrors === null){
vErrors = [err43];
}
else {
vErrors.push(err43);
}
errors++;
}
else {
if(!pattern7.test(data20)){
const err44 = {instancePath:instancePath+"/location/offset",schemaPath:"#/properties/location/anyOf/0/properties/offset/pattern",keyword:"pattern",params:{pattern: "^(0|[1-9][0-9]*)$"},message:"must match pattern \""+"^(0|[1-9][0-9]*)$"+"\""};
if(vErrors === null){
vErrors = [err44];
}
else {
vErrors.push(err44);
}
errors++;
}
}
}
else {
const err45 = {instancePath:instancePath+"/location/offset",schemaPath:"#/properties/location/anyOf/0/properties/offset/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err45];
}
else {
vErrors.push(err45);
}
errors++;
}
}
var valid8 = _errs73 === errors;
}
else {
var valid8 = true;
}
if(valid8){
if(data15.length !== undefined){
let data21 = data15.length;
const _errs75 = errors;
if(errors === _errs75){
if(typeof data21 === "string"){
if(func1(data21) > 20){
const err46 = {instancePath:instancePath+"/location/length",schemaPath:"#/properties/location/anyOf/0/properties/length/maxLength",keyword:"maxLength",params:{limit: 20},message:"must NOT have more than 20 characters"};
if(vErrors === null){
vErrors = [err46];
}
else {
vErrors.push(err46);
}
errors++;
}
else {
if(!pattern7.test(data21)){
const err47 = {instancePath:instancePath+"/location/length",schemaPath:"#/properties/location/anyOf/0/properties/length/pattern",keyword:"pattern",params:{pattern: "^(0|[1-9][0-9]*)$"},message:"must match pattern \""+"^(0|[1-9][0-9]*)$"+"\""};
if(vErrors === null){
vErrors = [err47];
}
else {
vErrors.push(err47);
}
errors++;
}
}
}
else {
const err48 = {instancePath:instancePath+"/location/length",schemaPath:"#/properties/location/anyOf/0/properties/length/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err48];
}
else {
vErrors.push(err48);
}
errors++;
}
}
var valid8 = _errs75 === errors;
}
else {
var valid8 = true;
}
if(valid8){
if(data15.line !== undefined){
let data22 = data15.line;
const _errs77 = errors;
if(errors === _errs77){
if(typeof data22 === "string"){
if(func1(data22) > 20){
const err49 = {instancePath:instancePath+"/location/line",schemaPath:"#/properties/location/anyOf/0/properties/line/maxLength",keyword:"maxLength",params:{limit: 20},message:"must NOT have more than 20 characters"};
if(vErrors === null){
vErrors = [err49];
}
else {
vErrors.push(err49);
}
errors++;
}
else {
if(!pattern7.test(data22)){
const err50 = {instancePath:instancePath+"/location/line",schemaPath:"#/properties/location/anyOf/0/properties/line/pattern",keyword:"pattern",params:{pattern: "^(0|[1-9][0-9]*)$"},message:"must match pattern \""+"^(0|[1-9][0-9]*)$"+"\""};
if(vErrors === null){
vErrors = [err50];
}
else {
vErrors.push(err50);
}
errors++;
}
}
}
else {
const err51 = {instancePath:instancePath+"/location/line",schemaPath:"#/properties/location/anyOf/0/properties/line/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err51];
}
else {
vErrors.push(err51);
}
errors++;
}
}
var valid8 = _errs77 === errors;
}
else {
var valid8 = true;
}
if(valid8){
if(data15.byte_column !== undefined){
let data23 = data15.byte_column;
const _errs79 = errors;
if(errors === _errs79){
if(typeof data23 === "string"){
if(func1(data23) > 20){
const err52 = {instancePath:instancePath+"/location/byte_column",schemaPath:"#/properties/location/anyOf/0/properties/byte_column/maxLength",keyword:"maxLength",params:{limit: 20},message:"must NOT have more than 20 characters"};
if(vErrors === null){
vErrors = [err52];
}
else {
vErrors.push(err52);
}
errors++;
}
else {
if(!pattern7.test(data23)){
const err53 = {instancePath:instancePath+"/location/byte_column",schemaPath:"#/properties/location/anyOf/0/properties/byte_column/pattern",keyword:"pattern",params:{pattern: "^(0|[1-9][0-9]*)$"},message:"must match pattern \""+"^(0|[1-9][0-9]*)$"+"\""};
if(vErrors === null){
vErrors = [err53];
}
else {
vErrors.push(err53);
}
errors++;
}
}
}
else {
const err54 = {instancePath:instancePath+"/location/byte_column",schemaPath:"#/properties/location/anyOf/0/properties/byte_column/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err54];
}
else {
vErrors.push(err54);
}
errors++;
}
}
var valid8 = _errs79 === errors;
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
}
}
else {
const err55 = {instancePath:instancePath+"/location",schemaPath:"#/properties/location/anyOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err55];
}
else {
vErrors.push(err55);
}
errors++;
}
}
var _valid5 = _errs54 === errors;
valid7 = valid7 || _valid5;
const _errs81 = errors;
if(data15 !== null){
const err56 = {instancePath:instancePath+"/location",schemaPath:"#/properties/location/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err56];
}
else {
vErrors.push(err56);
}
errors++;
}
var _valid5 = _errs81 === errors;
valid7 = valid7 || _valid5;
if(!valid7){
const err57 = {instancePath:instancePath+"/location",schemaPath:"#/properties/location/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err57];
}
else {
vErrors.push(err57);
}
errors++;
validate24.errors = vErrors;
return false;
}
else {
errors = _errs53;
if(vErrors !== null){
if(_errs53){
vErrors.length = _errs53;
}
else {
vErrors = null;
}
}
}
var valid0 = _errs52 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.facts !== undefined){
let data24 = data.facts;
const _errs83 = errors;
if(errors === _errs83){
if(Array.isArray(data24)){
if(data24.length > 16){
validate24.errors = [{instancePath:instancePath+"/facts",schemaPath:"#/properties/facts/maxItems",keyword:"maxItems",params:{limit: 16},message:"must NOT have more than 16 items"}];
return false;
}
else {
if(data24.length < 16){
validate24.errors = [{instancePath:instancePath+"/facts",schemaPath:"#/properties/facts/minItems",keyword:"minItems",params:{limit: 16},message:"must NOT have fewer than 16 items"}];
return false;
}
else {
var valid11 = true;
const len0 = data24.length;
for(let i0=0; i0<len0; i0++){
let data25 = data24[i0];
const _errs85 = errors;
const _errs86 = errors;
let valid12 = false;
const _errs87 = errors;
if(errors === _errs87){
if(data25 && typeof data25 == "object" && !Array.isArray(data25)){
let missing3;
if(((((data25.field === undefined) && (missing3 = "field")) || ((data25.origin === undefined) && (missing3 = "origin"))) || ((data25.availability === undefined) && (missing3 = "availability"))) || ((data25.value === undefined) && (missing3 = "value"))){
const err58 = {instancePath:instancePath+"/facts/" + i0,schemaPath:"#/properties/facts/items/anyOf/0/required",keyword:"required",params:{missingProperty: missing3},message:"must have required property '"+missing3+"'"};
if(vErrors === null){
vErrors = [err58];
}
else {
vErrors.push(err58);
}
errors++;
}
else {
const _errs89 = errors;
for(const key3 in data25){
if(!((((key3 === "field") || (key3 === "origin")) || (key3 === "availability")) || (key3 === "value"))){
const err59 = {instancePath:instancePath+"/facts/" + i0,schemaPath:"#/properties/facts/items/anyOf/0/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key3},message:"must NOT have additional properties"};
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
if(_errs89 === errors){
if(data25.field !== undefined){
let data26 = data25.field;
const _errs90 = errors;
if(typeof data26 !== "string"){
const err60 = {instancePath:instancePath+"/facts/" + i0+"/field",schemaPath:"#/properties/facts/items/anyOf/0/properties/field/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err60];
}
else {
vErrors.push(err60);
}
errors++;
}
if(!(((((((((((((((((((((((((((((((((((((((((((((((((((((((((data26 === "object") || (data26 === "name")) || (data26 === "table")) || (data26 === "native_input")) || (data26 === "affected_rows")) || (data26 === "argument")) || (data26 === "option")) || (data26 === "permissions")) || (data26 === "scope")) || (data26 === "column")) || (data26 === "qualifier")) || (data26 === "constraint")) || (data26 === "key")) || (data26 === "input_row")) || (data26 === "first_occurrence")) || (data26 === "parameter")) || (data26 === "parameter_use")) || (data26 === "expected_count")) || (data26 === "actual_count")) || (data26 === "expected_type")) || (data26 === "actual_type")) || (data26 === "supplied_value")) || (data26 === "expression")) || (data26 === "source_kind")) || (data26 === "source_basis")) || (data26 === "source_key")) || (data26 === "source_row")) || (data26 === "field_path")) || (data26 === "byte_offset")) || (data26 === "expected_resource")) || (data26 === "actual_resource")) || (data26 === "expected_source")) || (data26 === "actual_source")) || (data26 === "expected_revision")) || (data26 === "actual_revision")) || (data26 === "expected_schema")) || (data26 === "actual_schema")) || (data26 === "expected_policy")) || (data26 === "actual_policy")) || (data26 === "budget")) || (data26 === "limit")) || (data26 === "required")) || (data26 === "unit")) || (data26 === "completed_statements")) || (data26 === "emitted_rows")) || (data26 === "emitted_segments")) || (data26 === "completion")) || (data26 === "proposal")) || (data26 === "step")) || (data26 === "generation")) || (data26 === "attachment")) || (data26 === "lease")) || (data26 === "schema_origin")) || (data26 === "sampling_records")) || (data26 === "operation")) || (data26 === "native_cause")) || (data26 === "expected_bytes"))){
const err61 = {instancePath:instancePath+"/facts/" + i0+"/field",schemaPath:"#/properties/facts/items/anyOf/0/properties/field/enum",keyword:"enum",params:{allowedValues: schema35.properties.facts.items.anyOf[0].properties.field.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err61];
}
else {
vErrors.push(err61);
}
errors++;
}
var valid13 = _errs90 === errors;
}
else {
var valid13 = true;
}
if(valid13){
if(data25.origin !== undefined){
let data27 = data25.origin;
const _errs92 = errors;
if(typeof data27 !== "string"){
const err62 = {instancePath:instancePath+"/facts/" + i0+"/origin",schemaPath:"#/properties/facts/items/anyOf/0/properties/origin/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err62];
}
else {
vErrors.push(err62);
}
errors++;
}
if(!(((((data27 === "caller") || (data27 === "execution")) || (data27 === "schema")) || (data27 === "authority")) || (data27 === "owner"))){
const err63 = {instancePath:instancePath+"/facts/" + i0+"/origin",schemaPath:"#/properties/facts/items/anyOf/0/properties/origin/enum",keyword:"enum",params:{allowedValues: schema35.properties.facts.items.anyOf[0].properties.origin.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err63];
}
else {
vErrors.push(err63);
}
errors++;
}
var valid13 = _errs92 === errors;
}
else {
var valid13 = true;
}
if(valid13){
if(data25.availability !== undefined){
let data28 = data25.availability;
const _errs94 = errors;
if(typeof data28 !== "string"){
const err64 = {instancePath:instancePath+"/facts/" + i0+"/availability",schemaPath:"#/properties/facts/items/anyOf/0/properties/availability/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err64];
}
else {
vErrors.push(err64);
}
errors++;
}
if(!((((((data28 === "provided") || (data28 === "truncated")) || (data28 === "unrecorded")) || (data28 === "unavailable")) || (data28 === "withheld")) || (data28 === "inapplicable"))){
const err65 = {instancePath:instancePath+"/facts/" + i0+"/availability",schemaPath:"#/properties/facts/items/anyOf/0/properties/availability/enum",keyword:"enum",params:{allowedValues: schema35.properties.facts.items.anyOf[0].properties.availability.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err65];
}
else {
vErrors.push(err65);
}
errors++;
}
var valid13 = _errs94 === errors;
}
else {
var valid13 = true;
}
if(valid13){
if(data25.value !== undefined){
let data29 = data25.value;
const _errs96 = errors;
const _errs97 = errors;
let valid14 = false;
const _errs98 = errors;
const _errs99 = errors;
let valid15 = false;
let passing0 = null;
const _errs100 = errors;
if(errors === _errs100){
if(data29 && typeof data29 == "object" && !Array.isArray(data29)){
let missing4;
if((data29.text === undefined) && (missing4 = "text")){
const err66 = {instancePath:instancePath+"/facts/" + i0+"/value",schemaPath:"#/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/0/required",keyword:"required",params:{missingProperty: missing4},message:"must have required property '"+missing4+"'"};
if(vErrors === null){
vErrors = [err66];
}
else {
vErrors.push(err66);
}
errors++;
}
else {
const _errs102 = errors;
for(const key4 in data29){
if(!(key4 === "text")){
const err67 = {instancePath:instancePath+"/facts/" + i0+"/value",schemaPath:"#/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/0/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key4},message:"must NOT have additional properties"};
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
if(_errs102 === errors){
if(data29.text !== undefined){
let data30 = data29.text;
const _errs103 = errors;
if(errors === _errs103){
if(typeof data30 === "string"){
if(func1(data30) > 256){
const err68 = {instancePath:instancePath+"/facts/" + i0+"/value/text",schemaPath:"#/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/0/properties/text/maxLength",keyword:"maxLength",params:{limit: 256},message:"must NOT have more than 256 characters"};
if(vErrors === null){
vErrors = [err68];
}
else {
vErrors.push(err68);
}
errors++;
}
}
else {
const err69 = {instancePath:instancePath+"/facts/" + i0+"/value/text",schemaPath:"#/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/0/properties/text/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err69];
}
else {
vErrors.push(err69);
}
errors++;
}
}
}
}
}
}
else {
const err70 = {instancePath:instancePath+"/facts/" + i0+"/value",schemaPath:"#/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err70];
}
else {
vErrors.push(err70);
}
errors++;
}
}
var _valid10 = _errs100 === errors;
if(_valid10){
valid15 = true;
passing0 = 0;
var props2 = true;
}
const _errs105 = errors;
if(errors === _errs105){
if(data29 && typeof data29 == "object" && !Array.isArray(data29)){
let missing5;
if((data29.signed === undefined) && (missing5 = "signed")){
const err71 = {instancePath:instancePath+"/facts/" + i0+"/value",schemaPath:"#/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/1/required",keyword:"required",params:{missingProperty: missing5},message:"must have required property '"+missing5+"'"};
if(vErrors === null){
vErrors = [err71];
}
else {
vErrors.push(err71);
}
errors++;
}
else {
const _errs107 = errors;
for(const key5 in data29){
if(!(key5 === "signed")){
const err72 = {instancePath:instancePath+"/facts/" + i0+"/value",schemaPath:"#/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/1/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key5},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err72];
}
else {
vErrors.push(err72);
}
errors++;
break;
}
}
if(_errs107 === errors){
if(data29.signed !== undefined){
let data31 = data29.signed;
const _errs108 = errors;
if(errors === _errs108){
if(typeof data31 === "string"){
if(func1(data31) > 20){
const err73 = {instancePath:instancePath+"/facts/" + i0+"/value/signed",schemaPath:"#/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/1/properties/signed/maxLength",keyword:"maxLength",params:{limit: 20},message:"must NOT have more than 20 characters"};
if(vErrors === null){
vErrors = [err73];
}
else {
vErrors.push(err73);
}
errors++;
}
else {
if(!pattern16.test(data31)){
const err74 = {instancePath:instancePath+"/facts/" + i0+"/value/signed",schemaPath:"#/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/1/properties/signed/pattern",keyword:"pattern",params:{pattern: "^(0|-?[1-9][0-9]*)$"},message:"must match pattern \""+"^(0|-?[1-9][0-9]*)$"+"\""};
if(vErrors === null){
vErrors = [err74];
}
else {
vErrors.push(err74);
}
errors++;
}
}
}
else {
const err75 = {instancePath:instancePath+"/facts/" + i0+"/value/signed",schemaPath:"#/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/1/properties/signed/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err75];
}
else {
vErrors.push(err75);
}
errors++;
}
}
}
}
}
}
else {
const err76 = {instancePath:instancePath+"/facts/" + i0+"/value",schemaPath:"#/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/1/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err76];
}
else {
vErrors.push(err76);
}
errors++;
}
}
var _valid10 = _errs105 === errors;
if(_valid10 && valid15){
valid15 = false;
passing0 = [passing0, 1];
}
else {
if(_valid10){
valid15 = true;
passing0 = 1;
if(props2 !== true){
props2 = true;
}
}
const _errs110 = errors;
if(errors === _errs110){
if(data29 && typeof data29 == "object" && !Array.isArray(data29)){
let missing6;
if((data29.unsigned === undefined) && (missing6 = "unsigned")){
const err77 = {instancePath:instancePath+"/facts/" + i0+"/value",schemaPath:"#/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/2/required",keyword:"required",params:{missingProperty: missing6},message:"must have required property '"+missing6+"'"};
if(vErrors === null){
vErrors = [err77];
}
else {
vErrors.push(err77);
}
errors++;
}
else {
const _errs112 = errors;
for(const key6 in data29){
if(!(key6 === "unsigned")){
const err78 = {instancePath:instancePath+"/facts/" + i0+"/value",schemaPath:"#/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/2/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key6},message:"must NOT have additional properties"};
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
if(_errs112 === errors){
if(data29.unsigned !== undefined){
let data32 = data29.unsigned;
const _errs113 = errors;
if(errors === _errs113){
if(typeof data32 === "string"){
if(func1(data32) > 20){
const err79 = {instancePath:instancePath+"/facts/" + i0+"/value/unsigned",schemaPath:"#/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/2/properties/unsigned/maxLength",keyword:"maxLength",params:{limit: 20},message:"must NOT have more than 20 characters"};
if(vErrors === null){
vErrors = [err79];
}
else {
vErrors.push(err79);
}
errors++;
}
else {
if(!pattern7.test(data32)){
const err80 = {instancePath:instancePath+"/facts/" + i0+"/value/unsigned",schemaPath:"#/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/2/properties/unsigned/pattern",keyword:"pattern",params:{pattern: "^(0|[1-9][0-9]*)$"},message:"must match pattern \""+"^(0|[1-9][0-9]*)$"+"\""};
if(vErrors === null){
vErrors = [err80];
}
else {
vErrors.push(err80);
}
errors++;
}
}
}
else {
const err81 = {instancePath:instancePath+"/facts/" + i0+"/value/unsigned",schemaPath:"#/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/2/properties/unsigned/type",keyword:"type",params:{type: "string"},message:"must be string"};
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
const err82 = {instancePath:instancePath+"/facts/" + i0+"/value",schemaPath:"#/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/2/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err82];
}
else {
vErrors.push(err82);
}
errors++;
}
}
var _valid10 = _errs110 === errors;
if(_valid10 && valid15){
valid15 = false;
passing0 = [passing0, 2];
}
else {
if(_valid10){
valid15 = true;
passing0 = 2;
if(props2 !== true){
props2 = true;
}
}
const _errs115 = errors;
if(errors === _errs115){
if(data29 && typeof data29 == "object" && !Array.isArray(data29)){
let missing7;
if((data29.boolean === undefined) && (missing7 = "boolean")){
const err83 = {instancePath:instancePath+"/facts/" + i0+"/value",schemaPath:"#/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/3/required",keyword:"required",params:{missingProperty: missing7},message:"must have required property '"+missing7+"'"};
if(vErrors === null){
vErrors = [err83];
}
else {
vErrors.push(err83);
}
errors++;
}
else {
const _errs117 = errors;
for(const key7 in data29){
if(!(key7 === "boolean")){
const err84 = {instancePath:instancePath+"/facts/" + i0+"/value",schemaPath:"#/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/3/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key7},message:"must NOT have additional properties"};
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
if(_errs117 === errors){
if(data29.boolean !== undefined){
if(typeof data29.boolean !== "boolean"){
const err85 = {instancePath:instancePath+"/facts/" + i0+"/value/boolean",schemaPath:"#/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/3/properties/boolean/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"};
if(vErrors === null){
vErrors = [err85];
}
else {
vErrors.push(err85);
}
errors++;
}
}
}
}
}
else {
const err86 = {instancePath:instancePath+"/facts/" + i0+"/value",schemaPath:"#/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/3/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err86];
}
else {
vErrors.push(err86);
}
errors++;
}
}
var _valid10 = _errs115 === errors;
if(_valid10 && valid15){
valid15 = false;
passing0 = [passing0, 3];
}
else {
if(_valid10){
valid15 = true;
passing0 = 3;
if(props2 !== true){
props2 = true;
}
}
const _errs120 = errors;
if(errors === _errs120){
if(data29 && typeof data29 == "object" && !Array.isArray(data29)){
let missing8;
if((data29.digest === undefined) && (missing8 = "digest")){
const err87 = {instancePath:instancePath+"/facts/" + i0+"/value",schemaPath:"#/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/4/required",keyword:"required",params:{missingProperty: missing8},message:"must have required property '"+missing8+"'"};
if(vErrors === null){
vErrors = [err87];
}
else {
vErrors.push(err87);
}
errors++;
}
else {
const _errs122 = errors;
for(const key8 in data29){
if(!(key8 === "digest")){
const err88 = {instancePath:instancePath+"/facts/" + i0+"/value",schemaPath:"#/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/4/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key8},message:"must NOT have additional properties"};
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
if(_errs122 === errors){
if(data29.digest !== undefined){
let data34 = data29.digest;
const _errs123 = errors;
if(errors === _errs123){
if(Array.isArray(data34)){
if(data34.length > 32){
const err89 = {instancePath:instancePath+"/facts/" + i0+"/value/digest",schemaPath:"#/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/4/properties/digest/maxItems",keyword:"maxItems",params:{limit: 32},message:"must NOT have more than 32 items"};
if(vErrors === null){
vErrors = [err89];
}
else {
vErrors.push(err89);
}
errors++;
}
else {
if(data34.length < 32){
const err90 = {instancePath:instancePath+"/facts/" + i0+"/value/digest",schemaPath:"#/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/4/properties/digest/minItems",keyword:"minItems",params:{limit: 32},message:"must NOT have fewer than 32 items"};
if(vErrors === null){
vErrors = [err90];
}
else {
vErrors.push(err90);
}
errors++;
}
else {
var valid21 = true;
const len1 = data34.length;
for(let i1=0; i1<len1; i1++){
let data35 = data34[i1];
const _errs125 = errors;
if(!(((typeof data35 == "number") && (!(data35 % 1) && !isNaN(data35))) && (isFinite(data35)))){
const err91 = {instancePath:instancePath+"/facts/" + i0+"/value/digest/" + i1,schemaPath:"#/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/4/properties/digest/items/type",keyword:"type",params:{type: "integer"},message:"must be integer"};
if(vErrors === null){
vErrors = [err91];
}
else {
vErrors.push(err91);
}
errors++;
}
if(errors === _errs125){
if((typeof data35 == "number") && (isFinite(data35))){
if(data35 > 255 || isNaN(data35)){
const err92 = {instancePath:instancePath+"/facts/" + i0+"/value/digest/" + i1,schemaPath:"#/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/4/properties/digest/items/maximum",keyword:"maximum",params:{comparison: "<=", limit: 255},message:"must be <= 255"};
if(vErrors === null){
vErrors = [err92];
}
else {
vErrors.push(err92);
}
errors++;
}
else {
if(data35 < 0 || isNaN(data35)){
const err93 = {instancePath:instancePath+"/facts/" + i0+"/value/digest/" + i1,schemaPath:"#/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/4/properties/digest/items/minimum",keyword:"minimum",params:{comparison: ">=", limit: 0},message:"must be >= 0"};
if(vErrors === null){
vErrors = [err93];
}
else {
vErrors.push(err93);
}
errors++;
}
}
}
}
var valid21 = _errs125 === errors;
if(!valid21){
break;
}
}
}
}
}
else {
const err94 = {instancePath:instancePath+"/facts/" + i0+"/value/digest",schemaPath:"#/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/4/properties/digest/type",keyword:"type",params:{type: "array"},message:"must be array"};
if(vErrors === null){
vErrors = [err94];
}
else {
vErrors.push(err94);
}
errors++;
}
}
}
}
}
}
else {
const err95 = {instancePath:instancePath+"/facts/" + i0+"/value",schemaPath:"#/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/4/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err95];
}
else {
vErrors.push(err95);
}
errors++;
}
}
var _valid10 = _errs120 === errors;
if(_valid10 && valid15){
valid15 = false;
passing0 = [passing0, 4];
}
else {
if(_valid10){
valid15 = true;
passing0 = 4;
if(props2 !== true){
props2 = true;
}
}
const _errs127 = errors;
if(errors === _errs127){
if(data29 && typeof data29 == "object" && !Array.isArray(data29)){
let missing9;
if((data29.location === undefined) && (missing9 = "location")){
const err96 = {instancePath:instancePath+"/facts/" + i0+"/value",schemaPath:"#/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/5/required",keyword:"required",params:{missingProperty: missing9},message:"must have required property '"+missing9+"'"};
if(vErrors === null){
vErrors = [err96];
}
else {
vErrors.push(err96);
}
errors++;
}
else {
const _errs129 = errors;
for(const key9 in data29){
if(!(key9 === "location")){
const err97 = {instancePath:instancePath+"/facts/" + i0+"/value",schemaPath:"#/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/5/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key9},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err97];
}
else {
vErrors.push(err97);
}
errors++;
break;
}
}
if(_errs129 === errors){
if(data29.location !== undefined){
let data36 = data29.location;
const _errs130 = errors;
if(errors === _errs130){
if(data36 && typeof data36 == "object" && !Array.isArray(data36)){
let missing10;
if(((((((((data36.source === undefined) && (missing10 = "source")) || ((data36.source_encoding === undefined) && (missing10 = "source_encoding"))) || ((data36.source_truncated === undefined) && (missing10 = "source_truncated"))) || ((data36.statement === undefined) && (missing10 = "statement"))) || ((data36.offset === undefined) && (missing10 = "offset"))) || ((data36.length === undefined) && (missing10 = "length"))) || ((data36.line === undefined) && (missing10 = "line"))) || ((data36.byte_column === undefined) && (missing10 = "byte_column"))){
const err98 = {instancePath:instancePath+"/facts/" + i0+"/value/location",schemaPath:"#/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/5/properties/location/required",keyword:"required",params:{missingProperty: missing10},message:"must have required property '"+missing10+"'"};
if(vErrors === null){
vErrors = [err98];
}
else {
vErrors.push(err98);
}
errors++;
}
else {
const _errs132 = errors;
for(const key10 in data36){
if(!((((((((key10 === "source") || (key10 === "source_encoding")) || (key10 === "source_truncated")) || (key10 === "statement")) || (key10 === "offset")) || (key10 === "length")) || (key10 === "line")) || (key10 === "byte_column"))){
const err99 = {instancePath:instancePath+"/facts/" + i0+"/value/location",schemaPath:"#/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/5/properties/location/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key10},message:"must NOT have additional properties"};
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
if(_errs132 === errors){
if(data36.source !== undefined){
let data37 = data36.source;
const _errs133 = errors;
const _errs134 = errors;
let valid24 = false;
const _errs135 = errors;
if(errors === _errs135){
if(typeof data37 === "string"){
if(func1(data37) > 512){
const err100 = {instancePath:instancePath+"/facts/" + i0+"/value/location/source",schemaPath:"#/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/5/properties/location/properties/source/anyOf/0/maxLength",keyword:"maxLength",params:{limit: 512},message:"must NOT have more than 512 characters"};
if(vErrors === null){
vErrors = [err100];
}
else {
vErrors.push(err100);
}
errors++;
}
}
else {
const err101 = {instancePath:instancePath+"/facts/" + i0+"/value/location/source",schemaPath:"#/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/5/properties/location/properties/source/anyOf/0/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err101];
}
else {
vErrors.push(err101);
}
errors++;
}
}
var _valid11 = _errs135 === errors;
valid24 = valid24 || _valid11;
const _errs137 = errors;
if(data37 !== null){
const err102 = {instancePath:instancePath+"/facts/" + i0+"/value/location/source",schemaPath:"#/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/5/properties/location/properties/source/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err102];
}
else {
vErrors.push(err102);
}
errors++;
}
var _valid11 = _errs137 === errors;
valid24 = valid24 || _valid11;
if(!valid24){
const err103 = {instancePath:instancePath+"/facts/" + i0+"/value/location/source",schemaPath:"#/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/5/properties/location/properties/source/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err103];
}
else {
vErrors.push(err103);
}
errors++;
}
else {
errors = _errs134;
if(vErrors !== null){
if(_errs134){
vErrors.length = _errs134;
}
else {
vErrors = null;
}
}
}
var valid23 = _errs133 === errors;
}
else {
var valid23 = true;
}
if(valid23){
if(data36.source_encoding !== undefined){
let data38 = data36.source_encoding;
const _errs139 = errors;
if(typeof data38 !== "string"){
const err104 = {instancePath:instancePath+"/facts/" + i0+"/value/location/source_encoding",schemaPath:"#/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/5/properties/location/properties/source_encoding/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err104];
}
else {
vErrors.push(err104);
}
errors++;
}
if(!((data38 === "utf8") || (data38 === "escaped_bytes"))){
const err105 = {instancePath:instancePath+"/facts/" + i0+"/value/location/source_encoding",schemaPath:"#/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/5/properties/location/properties/source_encoding/enum",keyword:"enum",params:{allowedValues: schema35.properties.facts.items.anyOf[0].properties.value.anyOf[0].oneOf[5].properties.location.properties.source_encoding.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err105];
}
else {
vErrors.push(err105);
}
errors++;
}
var valid23 = _errs139 === errors;
}
else {
var valid23 = true;
}
if(valid23){
if(data36.source_truncated !== undefined){
const _errs141 = errors;
if(typeof data36.source_truncated !== "boolean"){
const err106 = {instancePath:instancePath+"/facts/" + i0+"/value/location/source_truncated",schemaPath:"#/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/5/properties/location/properties/source_truncated/type",keyword:"type",params:{type: "boolean"},message:"must be boolean"};
if(vErrors === null){
vErrors = [err106];
}
else {
vErrors.push(err106);
}
errors++;
}
var valid23 = _errs141 === errors;
}
else {
var valid23 = true;
}
if(valid23){
if(data36.statement !== undefined){
let data40 = data36.statement;
const _errs143 = errors;
const _errs144 = errors;
let valid25 = false;
const _errs145 = errors;
if(errors === _errs145){
if(typeof data40 === "string"){
if(func1(data40) > 20){
const err107 = {instancePath:instancePath+"/facts/" + i0+"/value/location/statement",schemaPath:"#/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/5/properties/location/properties/statement/anyOf/0/maxLength",keyword:"maxLength",params:{limit: 20},message:"must NOT have more than 20 characters"};
if(vErrors === null){
vErrors = [err107];
}
else {
vErrors.push(err107);
}
errors++;
}
else {
if(!pattern7.test(data40)){
const err108 = {instancePath:instancePath+"/facts/" + i0+"/value/location/statement",schemaPath:"#/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/5/properties/location/properties/statement/anyOf/0/pattern",keyword:"pattern",params:{pattern: "^(0|[1-9][0-9]*)$"},message:"must match pattern \""+"^(0|[1-9][0-9]*)$"+"\""};
if(vErrors === null){
vErrors = [err108];
}
else {
vErrors.push(err108);
}
errors++;
}
}
}
else {
const err109 = {instancePath:instancePath+"/facts/" + i0+"/value/location/statement",schemaPath:"#/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/5/properties/location/properties/statement/anyOf/0/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err109];
}
else {
vErrors.push(err109);
}
errors++;
}
}
var _valid12 = _errs145 === errors;
valid25 = valid25 || _valid12;
const _errs147 = errors;
if(data40 !== null){
const err110 = {instancePath:instancePath+"/facts/" + i0+"/value/location/statement",schemaPath:"#/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/5/properties/location/properties/statement/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err110];
}
else {
vErrors.push(err110);
}
errors++;
}
var _valid12 = _errs147 === errors;
valid25 = valid25 || _valid12;
if(!valid25){
const err111 = {instancePath:instancePath+"/facts/" + i0+"/value/location/statement",schemaPath:"#/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/5/properties/location/properties/statement/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err111];
}
else {
vErrors.push(err111);
}
errors++;
}
else {
errors = _errs144;
if(vErrors !== null){
if(_errs144){
vErrors.length = _errs144;
}
else {
vErrors = null;
}
}
}
var valid23 = _errs143 === errors;
}
else {
var valid23 = true;
}
if(valid23){
if(data36.offset !== undefined){
let data41 = data36.offset;
const _errs149 = errors;
if(errors === _errs149){
if(typeof data41 === "string"){
if(func1(data41) > 20){
const err112 = {instancePath:instancePath+"/facts/" + i0+"/value/location/offset",schemaPath:"#/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/5/properties/location/properties/offset/maxLength",keyword:"maxLength",params:{limit: 20},message:"must NOT have more than 20 characters"};
if(vErrors === null){
vErrors = [err112];
}
else {
vErrors.push(err112);
}
errors++;
}
else {
if(!pattern7.test(data41)){
const err113 = {instancePath:instancePath+"/facts/" + i0+"/value/location/offset",schemaPath:"#/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/5/properties/location/properties/offset/pattern",keyword:"pattern",params:{pattern: "^(0|[1-9][0-9]*)$"},message:"must match pattern \""+"^(0|[1-9][0-9]*)$"+"\""};
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
else {
const err114 = {instancePath:instancePath+"/facts/" + i0+"/value/location/offset",schemaPath:"#/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/5/properties/location/properties/offset/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err114];
}
else {
vErrors.push(err114);
}
errors++;
}
}
var valid23 = _errs149 === errors;
}
else {
var valid23 = true;
}
if(valid23){
if(data36.length !== undefined){
let data42 = data36.length;
const _errs151 = errors;
if(errors === _errs151){
if(typeof data42 === "string"){
if(func1(data42) > 20){
const err115 = {instancePath:instancePath+"/facts/" + i0+"/value/location/length",schemaPath:"#/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/5/properties/location/properties/length/maxLength",keyword:"maxLength",params:{limit: 20},message:"must NOT have more than 20 characters"};
if(vErrors === null){
vErrors = [err115];
}
else {
vErrors.push(err115);
}
errors++;
}
else {
if(!pattern7.test(data42)){
const err116 = {instancePath:instancePath+"/facts/" + i0+"/value/location/length",schemaPath:"#/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/5/properties/location/properties/length/pattern",keyword:"pattern",params:{pattern: "^(0|[1-9][0-9]*)$"},message:"must match pattern \""+"^(0|[1-9][0-9]*)$"+"\""};
if(vErrors === null){
vErrors = [err116];
}
else {
vErrors.push(err116);
}
errors++;
}
}
}
else {
const err117 = {instancePath:instancePath+"/facts/" + i0+"/value/location/length",schemaPath:"#/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/5/properties/location/properties/length/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err117];
}
else {
vErrors.push(err117);
}
errors++;
}
}
var valid23 = _errs151 === errors;
}
else {
var valid23 = true;
}
if(valid23){
if(data36.line !== undefined){
let data43 = data36.line;
const _errs153 = errors;
if(errors === _errs153){
if(typeof data43 === "string"){
if(func1(data43) > 20){
const err118 = {instancePath:instancePath+"/facts/" + i0+"/value/location/line",schemaPath:"#/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/5/properties/location/properties/line/maxLength",keyword:"maxLength",params:{limit: 20},message:"must NOT have more than 20 characters"};
if(vErrors === null){
vErrors = [err118];
}
else {
vErrors.push(err118);
}
errors++;
}
else {
if(!pattern7.test(data43)){
const err119 = {instancePath:instancePath+"/facts/" + i0+"/value/location/line",schemaPath:"#/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/5/properties/location/properties/line/pattern",keyword:"pattern",params:{pattern: "^(0|[1-9][0-9]*)$"},message:"must match pattern \""+"^(0|[1-9][0-9]*)$"+"\""};
if(vErrors === null){
vErrors = [err119];
}
else {
vErrors.push(err119);
}
errors++;
}
}
}
else {
const err120 = {instancePath:instancePath+"/facts/" + i0+"/value/location/line",schemaPath:"#/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/5/properties/location/properties/line/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err120];
}
else {
vErrors.push(err120);
}
errors++;
}
}
var valid23 = _errs153 === errors;
}
else {
var valid23 = true;
}
if(valid23){
if(data36.byte_column !== undefined){
let data44 = data36.byte_column;
const _errs155 = errors;
if(errors === _errs155){
if(typeof data44 === "string"){
if(func1(data44) > 20){
const err121 = {instancePath:instancePath+"/facts/" + i0+"/value/location/byte_column",schemaPath:"#/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/5/properties/location/properties/byte_column/maxLength",keyword:"maxLength",params:{limit: 20},message:"must NOT have more than 20 characters"};
if(vErrors === null){
vErrors = [err121];
}
else {
vErrors.push(err121);
}
errors++;
}
else {
if(!pattern7.test(data44)){
const err122 = {instancePath:instancePath+"/facts/" + i0+"/value/location/byte_column",schemaPath:"#/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/5/properties/location/properties/byte_column/pattern",keyword:"pattern",params:{pattern: "^(0|[1-9][0-9]*)$"},message:"must match pattern \""+"^(0|[1-9][0-9]*)$"+"\""};
if(vErrors === null){
vErrors = [err122];
}
else {
vErrors.push(err122);
}
errors++;
}
}
}
else {
const err123 = {instancePath:instancePath+"/facts/" + i0+"/value/location/byte_column",schemaPath:"#/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/5/properties/location/properties/byte_column/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err123];
}
else {
vErrors.push(err123);
}
errors++;
}
}
var valid23 = _errs155 === errors;
}
else {
var valid23 = true;
}
}
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
const err124 = {instancePath:instancePath+"/facts/" + i0+"/value/location",schemaPath:"#/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/5/properties/location/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err124];
}
else {
vErrors.push(err124);
}
errors++;
}
}
}
}
}
}
else {
const err125 = {instancePath:instancePath+"/facts/" + i0+"/value",schemaPath:"#/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf/5/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err125];
}
else {
vErrors.push(err125);
}
errors++;
}
}
var _valid10 = _errs127 === errors;
if(_valid10 && valid15){
valid15 = false;
passing0 = [passing0, 5];
}
else {
if(_valid10){
valid15 = true;
passing0 = 5;
if(props2 !== true){
props2 = true;
}
}
}
}
}
}
}
if(!valid15){
const err126 = {instancePath:instancePath+"/facts/" + i0+"/value",schemaPath:"#/properties/facts/items/anyOf/0/properties/value/anyOf/0/oneOf",keyword:"oneOf",params:{passingSchemas: passing0},message:"must match exactly one schema in oneOf"};
if(vErrors === null){
vErrors = [err126];
}
else {
vErrors.push(err126);
}
errors++;
}
else {
errors = _errs99;
if(vErrors !== null){
if(_errs99){
vErrors.length = _errs99;
}
else {
vErrors = null;
}
}
}
var _valid9 = _errs98 === errors;
valid14 = valid14 || _valid9;
const _errs157 = errors;
if(data29 !== null){
const err127 = {instancePath:instancePath+"/facts/" + i0+"/value",schemaPath:"#/properties/facts/items/anyOf/0/properties/value/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err127];
}
else {
vErrors.push(err127);
}
errors++;
}
var _valid9 = _errs157 === errors;
valid14 = valid14 || _valid9;
if(!valid14){
const err128 = {instancePath:instancePath+"/facts/" + i0+"/value",schemaPath:"#/properties/facts/items/anyOf/0/properties/value/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err128];
}
else {
vErrors.push(err128);
}
errors++;
}
else {
errors = _errs97;
if(vErrors !== null){
if(_errs97){
vErrors.length = _errs97;
}
else {
vErrors = null;
}
}
}
var valid13 = _errs96 === errors;
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
else {
const err129 = {instancePath:instancePath+"/facts/" + i0,schemaPath:"#/properties/facts/items/anyOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err129];
}
else {
vErrors.push(err129);
}
errors++;
}
}
var _valid8 = _errs87 === errors;
valid12 = valid12 || _valid8;
const _errs159 = errors;
if(data25 !== null){
const err130 = {instancePath:instancePath+"/facts/" + i0,schemaPath:"#/properties/facts/items/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err130];
}
else {
vErrors.push(err130);
}
errors++;
}
var _valid8 = _errs159 === errors;
valid12 = valid12 || _valid8;
if(!valid12){
const err131 = {instancePath:instancePath+"/facts/" + i0,schemaPath:"#/properties/facts/items/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err131];
}
else {
vErrors.push(err131);
}
errors++;
validate24.errors = vErrors;
return false;
}
else {
errors = _errs86;
if(vErrors !== null){
if(_errs86){
vErrors.length = _errs86;
}
else {
vErrors = null;
}
}
}
var valid11 = _errs85 === errors;
if(!valid11){
break;
}
}
}
}
}
else {
validate24.errors = [{instancePath:instancePath+"/facts",schemaPath:"#/properties/facts/type",keyword:"type",params:{type: "array"},message:"must be array"}];
return false;
}
}
var valid0 = _errs83 === errors;
}
else {
var valid0 = true;
}
if(valid0){
if(data.actions !== undefined){
let data45 = data.actions;
const _errs161 = errors;
if(errors === _errs161){
if(Array.isArray(data45)){
if(data45.length > 4){
validate24.errors = [{instancePath:instancePath+"/actions",schemaPath:"#/properties/actions/maxItems",keyword:"maxItems",params:{limit: 4},message:"must NOT have more than 4 items"}];
return false;
}
else {
if(data45.length < 4){
validate24.errors = [{instancePath:instancePath+"/actions",schemaPath:"#/properties/actions/minItems",keyword:"minItems",params:{limit: 4},message:"must NOT have fewer than 4 items"}];
return false;
}
else {
var valid26 = true;
const len2 = data45.length;
for(let i2=0; i2<len2; i2++){
let data46 = data45[i2];
const _errs163 = errors;
const _errs164 = errors;
let valid27 = false;
const _errs165 = errors;
if(errors === _errs165){
if(data46 && typeof data46 == "object" && !Array.isArray(data46)){
let missing11;
if(((data46.kind === undefined) && (missing11 = "kind")) || ((data46.target === undefined) && (missing11 = "target"))){
const err132 = {instancePath:instancePath+"/actions/" + i2,schemaPath:"#/properties/actions/items/anyOf/0/required",keyword:"required",params:{missingProperty: missing11},message:"must have required property '"+missing11+"'"};
if(vErrors === null){
vErrors = [err132];
}
else {
vErrors.push(err132);
}
errors++;
}
else {
const _errs167 = errors;
for(const key11 in data46){
if(!((key11 === "kind") || (key11 === "target"))){
const err133 = {instancePath:instancePath+"/actions/" + i2,schemaPath:"#/properties/actions/items/anyOf/0/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key11},message:"must NOT have additional properties"};
if(vErrors === null){
vErrors = [err133];
}
else {
vErrors.push(err133);
}
errors++;
break;
}
}
if(_errs167 === errors){
if(data46.kind !== undefined){
let data47 = data46.kind;
const _errs168 = errors;
if(typeof data47 !== "string"){
const err134 = {instancePath:instancePath+"/actions/" + i2+"/kind",schemaPath:"#/properties/actions/items/anyOf/0/properties/kind/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err134];
}
else {
vErrors.push(err134);
}
errors++;
}
if(!(((((((((((data47 === "correct_input") || (data47 === "inspect_status")) || (data47 === "resume_exact")) || (data47 === "cancel_wait")) || (data47 === "cancel_mutation")) || (data47 === "refresh")) || (data47 === "recompile")) || (data47 === "retry_read")) || (data47 === "inspect_scope")) || (data47 === "reconcile_effect")) || (data47 === "contact_operator"))){
const err135 = {instancePath:instancePath+"/actions/" + i2+"/kind",schemaPath:"#/properties/actions/items/anyOf/0/properties/kind/enum",keyword:"enum",params:{allowedValues: schema35.properties.actions.items.anyOf[0].properties.kind.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err135];
}
else {
vErrors.push(err135);
}
errors++;
}
var valid28 = _errs168 === errors;
}
else {
var valid28 = true;
}
if(valid28){
if(data46.target !== undefined){
let data48 = data46.target;
const _errs170 = errors;
const _errs171 = errors;
let valid29 = false;
const _errs172 = errors;
if(errors === _errs172){
if(data48 && typeof data48 == "object" && !Array.isArray(data48)){
let missing12;
if((((((data48.domain === undefined) && (missing12 = "domain")) || ((data48.id === undefined) && (missing12 = "id"))) || ((data48.realm === undefined) && (missing12 = "realm"))) || ((data48.resource === undefined) && (missing12 = "resource"))) || ((data48.sequence === undefined) && (missing12 = "sequence"))){
const err136 = {instancePath:instancePath+"/actions/" + i2+"/target",schemaPath:"#/properties/actions/items/anyOf/0/properties/target/anyOf/0/required",keyword:"required",params:{missingProperty: missing12},message:"must have required property '"+missing12+"'"};
if(vErrors === null){
vErrors = [err136];
}
else {
vErrors.push(err136);
}
errors++;
}
else {
const _errs174 = errors;
for(const key12 in data48){
if(!(((((key12 === "domain") || (key12 === "id")) || (key12 === "realm")) || (key12 === "resource")) || (key12 === "sequence"))){
const err137 = {instancePath:instancePath+"/actions/" + i2+"/target",schemaPath:"#/properties/actions/items/anyOf/0/properties/target/anyOf/0/additionalProperties",keyword:"additionalProperties",params:{additionalProperty: key12},message:"must NOT have additional properties"};
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
if(_errs174 === errors){
if(data48.domain !== undefined){
let data49 = data48.domain;
const _errs175 = errors;
if(typeof data49 !== "string"){
const err138 = {instancePath:instancePath+"/actions/" + i2+"/target/domain",schemaPath:"#/properties/actions/items/anyOf/0/properties/target/anyOf/0/properties/domain/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err138];
}
else {
vErrors.push(err138);
}
errors++;
}
if(!(((((((((((data49 === "sql") || (data49 === "query")) || (data49 === "mutation")) || (data49 === "catalog")) || (data49 === "application")) || (data49 === "publication")) || (data49 === "migration")) || (data49 === "reactive")) || (data49 === "effect")) || (data49 === "transport")) || (data49 === "internal"))){
const err139 = {instancePath:instancePath+"/actions/" + i2+"/target/domain",schemaPath:"#/properties/actions/items/anyOf/0/properties/target/anyOf/0/properties/domain/enum",keyword:"enum",params:{allowedValues: schema35.properties.actions.items.anyOf[0].properties.target.anyOf[0].properties.domain.enum},message:"must be equal to one of the allowed values"};
if(vErrors === null){
vErrors = [err139];
}
else {
vErrors.push(err139);
}
errors++;
}
var valid30 = _errs175 === errors;
}
else {
var valid30 = true;
}
if(valid30){
if(data48.id !== undefined){
let data50 = data48.id;
const _errs177 = errors;
if(errors === _errs177){
if(typeof data50 === "string"){
if(func1(data50) > 20){
const err140 = {instancePath:instancePath+"/actions/" + i2+"/target/id",schemaPath:"#/properties/actions/items/anyOf/0/properties/target/anyOf/0/properties/id/maxLength",keyword:"maxLength",params:{limit: 20},message:"must NOT have more than 20 characters"};
if(vErrors === null){
vErrors = [err140];
}
else {
vErrors.push(err140);
}
errors++;
}
else {
if(!pattern7.test(data50)){
const err141 = {instancePath:instancePath+"/actions/" + i2+"/target/id",schemaPath:"#/properties/actions/items/anyOf/0/properties/target/anyOf/0/properties/id/pattern",keyword:"pattern",params:{pattern: "^(0|[1-9][0-9]*)$"},message:"must match pattern \""+"^(0|[1-9][0-9]*)$"+"\""};
if(vErrors === null){
vErrors = [err141];
}
else {
vErrors.push(err141);
}
errors++;
}
}
}
else {
const err142 = {instancePath:instancePath+"/actions/" + i2+"/target/id",schemaPath:"#/properties/actions/items/anyOf/0/properties/target/anyOf/0/properties/id/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err142];
}
else {
vErrors.push(err142);
}
errors++;
}
}
var valid30 = _errs177 === errors;
}
else {
var valid30 = true;
}
if(valid30){
if(data48.realm !== undefined){
let data51 = data48.realm;
const _errs179 = errors;
const _errs180 = errors;
let valid31 = false;
const _errs181 = errors;
if(errors === _errs181){
if(typeof data51 === "string"){
if(func1(data51) > 20){
const err143 = {instancePath:instancePath+"/actions/" + i2+"/target/realm",schemaPath:"#/properties/actions/items/anyOf/0/properties/target/anyOf/0/properties/realm/anyOf/0/maxLength",keyword:"maxLength",params:{limit: 20},message:"must NOT have more than 20 characters"};
if(vErrors === null){
vErrors = [err143];
}
else {
vErrors.push(err143);
}
errors++;
}
else {
if(!pattern7.test(data51)){
const err144 = {instancePath:instancePath+"/actions/" + i2+"/target/realm",schemaPath:"#/properties/actions/items/anyOf/0/properties/target/anyOf/0/properties/realm/anyOf/0/pattern",keyword:"pattern",params:{pattern: "^(0|[1-9][0-9]*)$"},message:"must match pattern \""+"^(0|[1-9][0-9]*)$"+"\""};
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
else {
const err145 = {instancePath:instancePath+"/actions/" + i2+"/target/realm",schemaPath:"#/properties/actions/items/anyOf/0/properties/target/anyOf/0/properties/realm/anyOf/0/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err145];
}
else {
vErrors.push(err145);
}
errors++;
}
}
var _valid15 = _errs181 === errors;
valid31 = valid31 || _valid15;
const _errs183 = errors;
if(data51 !== null){
const err146 = {instancePath:instancePath+"/actions/" + i2+"/target/realm",schemaPath:"#/properties/actions/items/anyOf/0/properties/target/anyOf/0/properties/realm/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err146];
}
else {
vErrors.push(err146);
}
errors++;
}
var _valid15 = _errs183 === errors;
valid31 = valid31 || _valid15;
if(!valid31){
const err147 = {instancePath:instancePath+"/actions/" + i2+"/target/realm",schemaPath:"#/properties/actions/items/anyOf/0/properties/target/anyOf/0/properties/realm/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err147];
}
else {
vErrors.push(err147);
}
errors++;
}
else {
errors = _errs180;
if(vErrors !== null){
if(_errs180){
vErrors.length = _errs180;
}
else {
vErrors = null;
}
}
}
var valid30 = _errs179 === errors;
}
else {
var valid30 = true;
}
if(valid30){
if(data48.resource !== undefined){
let data52 = data48.resource;
const _errs185 = errors;
const _errs186 = errors;
let valid32 = false;
const _errs187 = errors;
if(errors === _errs187){
if(typeof data52 === "string"){
if(func1(data52) > 20){
const err148 = {instancePath:instancePath+"/actions/" + i2+"/target/resource",schemaPath:"#/properties/actions/items/anyOf/0/properties/target/anyOf/0/properties/resource/anyOf/0/maxLength",keyword:"maxLength",params:{limit: 20},message:"must NOT have more than 20 characters"};
if(vErrors === null){
vErrors = [err148];
}
else {
vErrors.push(err148);
}
errors++;
}
else {
if(!pattern7.test(data52)){
const err149 = {instancePath:instancePath+"/actions/" + i2+"/target/resource",schemaPath:"#/properties/actions/items/anyOf/0/properties/target/anyOf/0/properties/resource/anyOf/0/pattern",keyword:"pattern",params:{pattern: "^(0|[1-9][0-9]*)$"},message:"must match pattern \""+"^(0|[1-9][0-9]*)$"+"\""};
if(vErrors === null){
vErrors = [err149];
}
else {
vErrors.push(err149);
}
errors++;
}
}
}
else {
const err150 = {instancePath:instancePath+"/actions/" + i2+"/target/resource",schemaPath:"#/properties/actions/items/anyOf/0/properties/target/anyOf/0/properties/resource/anyOf/0/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err150];
}
else {
vErrors.push(err150);
}
errors++;
}
}
var _valid16 = _errs187 === errors;
valid32 = valid32 || _valid16;
const _errs189 = errors;
if(data52 !== null){
const err151 = {instancePath:instancePath+"/actions/" + i2+"/target/resource",schemaPath:"#/properties/actions/items/anyOf/0/properties/target/anyOf/0/properties/resource/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err151];
}
else {
vErrors.push(err151);
}
errors++;
}
var _valid16 = _errs189 === errors;
valid32 = valid32 || _valid16;
if(!valid32){
const err152 = {instancePath:instancePath+"/actions/" + i2+"/target/resource",schemaPath:"#/properties/actions/items/anyOf/0/properties/target/anyOf/0/properties/resource/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err152];
}
else {
vErrors.push(err152);
}
errors++;
}
else {
errors = _errs186;
if(vErrors !== null){
if(_errs186){
vErrors.length = _errs186;
}
else {
vErrors = null;
}
}
}
var valid30 = _errs185 === errors;
}
else {
var valid30 = true;
}
if(valid30){
if(data48.sequence !== undefined){
let data53 = data48.sequence;
const _errs191 = errors;
const _errs192 = errors;
let valid33 = false;
const _errs193 = errors;
if(errors === _errs193){
if(typeof data53 === "string"){
if(func1(data53) > 20){
const err153 = {instancePath:instancePath+"/actions/" + i2+"/target/sequence",schemaPath:"#/properties/actions/items/anyOf/0/properties/target/anyOf/0/properties/sequence/anyOf/0/maxLength",keyword:"maxLength",params:{limit: 20},message:"must NOT have more than 20 characters"};
if(vErrors === null){
vErrors = [err153];
}
else {
vErrors.push(err153);
}
errors++;
}
else {
if(!pattern7.test(data53)){
const err154 = {instancePath:instancePath+"/actions/" + i2+"/target/sequence",schemaPath:"#/properties/actions/items/anyOf/0/properties/target/anyOf/0/properties/sequence/anyOf/0/pattern",keyword:"pattern",params:{pattern: "^(0|[1-9][0-9]*)$"},message:"must match pattern \""+"^(0|[1-9][0-9]*)$"+"\""};
if(vErrors === null){
vErrors = [err154];
}
else {
vErrors.push(err154);
}
errors++;
}
}
}
else {
const err155 = {instancePath:instancePath+"/actions/" + i2+"/target/sequence",schemaPath:"#/properties/actions/items/anyOf/0/properties/target/anyOf/0/properties/sequence/anyOf/0/type",keyword:"type",params:{type: "string"},message:"must be string"};
if(vErrors === null){
vErrors = [err155];
}
else {
vErrors.push(err155);
}
errors++;
}
}
var _valid17 = _errs193 === errors;
valid33 = valid33 || _valid17;
const _errs195 = errors;
if(data53 !== null){
const err156 = {instancePath:instancePath+"/actions/" + i2+"/target/sequence",schemaPath:"#/properties/actions/items/anyOf/0/properties/target/anyOf/0/properties/sequence/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err156];
}
else {
vErrors.push(err156);
}
errors++;
}
var _valid17 = _errs195 === errors;
valid33 = valid33 || _valid17;
if(!valid33){
const err157 = {instancePath:instancePath+"/actions/" + i2+"/target/sequence",schemaPath:"#/properties/actions/items/anyOf/0/properties/target/anyOf/0/properties/sequence/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err157];
}
else {
vErrors.push(err157);
}
errors++;
}
else {
errors = _errs192;
if(vErrors !== null){
if(_errs192){
vErrors.length = _errs192;
}
else {
vErrors = null;
}
}
}
var valid30 = _errs191 === errors;
}
else {
var valid30 = true;
}
}
}
}
}
}
}
}
else {
const err158 = {instancePath:instancePath+"/actions/" + i2+"/target",schemaPath:"#/properties/actions/items/anyOf/0/properties/target/anyOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err158];
}
else {
vErrors.push(err158);
}
errors++;
}
}
var _valid14 = _errs172 === errors;
valid29 = valid29 || _valid14;
const _errs197 = errors;
if(data48 !== null){
const err159 = {instancePath:instancePath+"/actions/" + i2+"/target",schemaPath:"#/properties/actions/items/anyOf/0/properties/target/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err159];
}
else {
vErrors.push(err159);
}
errors++;
}
var _valid14 = _errs197 === errors;
valid29 = valid29 || _valid14;
if(!valid29){
const err160 = {instancePath:instancePath+"/actions/" + i2+"/target",schemaPath:"#/properties/actions/items/anyOf/0/properties/target/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err160];
}
else {
vErrors.push(err160);
}
errors++;
}
else {
errors = _errs171;
if(vErrors !== null){
if(_errs171){
vErrors.length = _errs171;
}
else {
vErrors = null;
}
}
}
var valid28 = _errs170 === errors;
}
else {
var valid28 = true;
}
}
}
}
}
else {
const err161 = {instancePath:instancePath+"/actions/" + i2,schemaPath:"#/properties/actions/items/anyOf/0/type",keyword:"type",params:{type: "object"},message:"must be object"};
if(vErrors === null){
vErrors = [err161];
}
else {
vErrors.push(err161);
}
errors++;
}
}
var _valid13 = _errs165 === errors;
valid27 = valid27 || _valid13;
const _errs199 = errors;
if(data46 !== null){
const err162 = {instancePath:instancePath+"/actions/" + i2,schemaPath:"#/properties/actions/items/anyOf/1/type",keyword:"type",params:{type: "null"},message:"must be null"};
if(vErrors === null){
vErrors = [err162];
}
else {
vErrors.push(err162);
}
errors++;
}
var _valid13 = _errs199 === errors;
valid27 = valid27 || _valid13;
if(!valid27){
const err163 = {instancePath:instancePath+"/actions/" + i2,schemaPath:"#/properties/actions/items/anyOf",keyword:"anyOf",params:{},message:"must match a schema in anyOf"};
if(vErrors === null){
vErrors = [err163];
}
else {
vErrors.push(err163);
}
errors++;
validate24.errors = vErrors;
return false;
}
else {
errors = _errs164;
if(vErrors !== null){
if(_errs164){
vErrors.length = _errs164;
}
else {
vErrors = null;
}
}
}
var valid26 = _errs163 === errors;
if(!valid26){
break;
}
}
}
}
}
else {
validate24.errors = [{instancePath:instancePath+"/actions",schemaPath:"#/properties/actions/type",keyword:"type",params:{type: "array"},message:"must be array"}];
return false;
}
}
var valid0 = _errs161 === errors;
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
validate24.errors = [{instancePath,schemaPath:"#/type",keyword:"type",params:{type: "object"},message:"must be object"}];
return false;
}
}
validate24.errors = vErrors;
return errors === 0;
}
validate24.evaluated = {"props":true,"dynamicProps":false,"dynamicItems":false};
